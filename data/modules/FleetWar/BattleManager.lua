-- FleetWar/BattleManager.lua
-- Spawning, tracking, AI management, and conclusion logic for fleet battles.
-- Zero global state pollution. Unique Serializer key handled in FleetWar.lua.
--
-- Battle lifecycle:
--   SpawnBattle() → ACTIVE → (timer) UpdateBattle() → ConcludeBattle() → history

local Engine     = require 'Engine'
local Game       = require 'Game'
local ShipBuilder = require 'modules.MissionUtils.ShipBuilder'
local MissionUtils = require 'modules.MissionUtils'

local BattleManager = {}

-- active[path_key] = battle table
BattleManager.active  = {}
-- Concluded battle results, newest first
BattleManager.history = {}
BattleManager.MAX_HISTORY = 10

-- ── helpers ─────────────────────────────────────────────────────────────────

local function pathKey(path)
    return string.format("%d,%d,%d:%d",
        path.sectorX, path.sectorY, path.sectorZ, path.systemIndex)
end

local function pickRandom(t)
    if #t == 0 then return nil end
    return t[Engine.rand:Integer(1, #t)]
end

-- Find a suitable planet or body to spawn the battle near.
-- Prefers populated rocky planets (like Pirates.lua does), falls back to any planet, then star.
local function findBattleBody()
    if not Game.system then return nil, 0 end

    local bodies = Game.system:GetBodyPaths()
    local populated = {}
    local rocky = {}

    for _, p in ipairs(bodies) do
        local sb = p:GetSystemBody()
        if sb then
            if sb.superType == 'ROCKY_PLANET' then
                if sb.population and sb.population > 0 then
                    table.insert(populated, sb)
                else
                    table.insert(rocky, sb)
                end
            end
        end
    end

    -- Prefer populated planets, then any rocky planet
    local candidates = #populated > 0 and populated or rocky
    if #candidates > 0 then
        local sb = candidates[Engine.rand:Integer(1, #candidates)]
        return sb.body, sb.radius
    end

    -- Fallback: spawn around the primary star (like TradeShips does)
    local ok_star, stars = pcall(function() return Game.system:GetStars() end)
    if ok_star and stars and #stars > 0 then
        local star_body = stars[1].body
        local star_radius = stars[1].radius or 1e8
        return star_body, star_radius
    end

    return nil, 0
end

-- Issue AIKill orders: every ship in src attacks a random live ship in dst.
local function assignTargets(src, dst)
    if #dst == 0 then return end
    for _, ship in ipairs(src) do
        if ship:exists() then
            local target = pickRandom(dst)
            if target and target:exists() then
                ship:AIKill(target)
            end
        end
    end
end

-- Spawn `count` ships orbiting a body, with error logging.
local function spawnFleet(body, radius, template, count, threat, label_prefix, ship_set, side)
    local fleet = {}
    local near = radius * 1.5
    local far  = radius * 4.0
    for i = 1, count do
        local ok, ship = pcall(function()
            return ShipBuilder.MakeShipOrbit(body, template, threat, near, far)
        end)
        if ok and ship and ship:exists() then
            ship:SetLabel(label_prefix .. " " .. i)
            table.insert(fleet, ship)
            ship_set[ship] = side
        else
            local err_msg = not ok and tostring(ship) or "ship nil or not exists"
            print(string.format("[FleetWar] spawnFleet ERROR: side=%s i=%d threat=%d err=%s",
                side, i, threat, err_msg))
        end
    end
    return fleet
end

-- Remove a specific ship from a fleet array (linear, fleets are small).
local function removeFromFleet(fleet, ship)
    for i, s in ipairs(fleet) do
        if s == ship then
            table.remove(fleet, i)
            return true
        end
    end
    return false
end

-- ── public API ───────────────────────────────────────────────────────────────

-- Spawn a battle for the current system.  Returns the battle table or nil.
function BattleManager.SpawnBattle(conflict, fleet_size, threat)
    if not Game.system then return nil end
    local key = pathKey(Game.system.path)
    if BattleManager.active[key] then return nil end   -- already one here

    -- Find a body to spawn near (populated planet > rocky planet > star)
    local body, radius = findBattleBody()
    if not body then
        print("[FleetWar] SpawnBattle: no suitable body found in system")
        return nil
    end

    local body_name = "unknown"
    pcall(function() body_name = body:GetLabel() or body:GetSystemBody().name or "unknown" end)
    print(string.format("[FleetWar] SpawnBattle: spawning %d vs %d near %s (radius=%d, threat=%d)",
        fleet_size, fleet_size, body_name, radius, threat))

    local ship_set = {}   -- ship → "A"|"B" for O(1) membership test

    local fleet_a = spawnFleet(
        body, radius,
        MissionUtils.ShipTemplates.GenericPolice,
        fleet_size, threat,
        conflict.label_a, ship_set, "A")

    local fleet_b = spawnFleet(
        body, radius,
        MissionUtils.ShipTemplates.StrongPirate,
        fleet_size, threat + 10,
        conflict.label_b, ship_set, "B")

    print(string.format("[FleetWar] SpawnBattle result: fleet_a=%d, fleet_b=%d", #fleet_a, #fleet_b))

    -- Abort if no ships were created (ShipBuilder found no suitable hulls)
    if #fleet_a == 0 and #fleet_b == 0 then
        print("[FleetWar] SpawnBattle: ABORTED — no ships spawned (hull selection failed)")
        return nil
    end

    local battle = {
        key          = key,
        system_name  = Game.system.name,
        system_path  = Game.system.path,
        conflict     = conflict,
        fleet_a      = fleet_a,
        fleet_b      = fleet_b,
        ship_set     = ship_set,
        casualties_a = 0,
        casualties_b = 0,
        retreated_a  = 0,
        retreated_b  = 0,
        player_side  = nil,
        player_kills = 0,
        start_time   = Game.time,
        state        = "ACTIVE",
        winner       = nil,
        battle_body_name = body_name,
    }

    assignTargets(fleet_a, fleet_b)
    assignTargets(fleet_b, fleet_a)

    BattleManager.active[key] = battle
    return battle
end

-- Periodic update: re-prune fleets and reassign stale targets.
-- Called every 45 s by FleetWar.lua's timer.
function BattleManager.UpdateBattle(key)
    local battle = BattleManager.active[key]
    if not battle or battle.state ~= "ACTIVE" then return end

    -- Prune ship arrays (engine silently removes ships in some edge cases)
    local function pruneFleet(fleet)
        local alive = {}
        for _, ship in ipairs(fleet) do
            if ship:exists() then
                table.insert(alive, ship)
            else
                battle.ship_set[ship] = nil
            end
        end
        return alive
    end

    battle.fleet_a = pruneFleet(battle.fleet_a)
    battle.fleet_b = pruneFleet(battle.fleet_b)

    if #battle.fleet_a == 0 and #battle.fleet_b == 0 then
        BattleManager.ConcludeBattle(key, "DRAW"); return
    elseif #battle.fleet_a == 0 then
        BattleManager.ConcludeBattle(key, "B"); return
    elseif #battle.fleet_b == 0 then
        BattleManager.ConcludeBattle(key, "A"); return
    end

    -- Reassign targets in case the previous target died
    assignTargets(battle.fleet_a, battle.fleet_b)
    assignTargets(battle.fleet_b, battle.fleet_a)
end

-- Called from onShipDestroyed.  Only acts on ships we are tracking.
function BattleManager.HandleShipDestroyed(ship, attacker)
    for key, battle in pairs(BattleManager.active) do
        if battle.state == "ACTIVE" then
            local side = battle.ship_set[ship]
            if side then
                battle.ship_set[ship] = nil

                local fleet_own, cas_field, conclude_winner
                if side == "A" then
                    fleet_own       = battle.fleet_a
                    cas_field       = "casualties_a"
                    conclude_winner = "B"
                    if attacker and attacker:IsPlayer() then
                        battle.player_side  = "B"
                        battle.player_kills = battle.player_kills + 1
                    end
                else
                    fleet_own       = battle.fleet_b
                    cas_field       = "casualties_b"
                    conclude_winner = "A"
                    if attacker and attacker:IsPlayer() then
                        battle.player_side  = "A"
                        battle.player_kills = battle.player_kills + 1
                    end
                end

                battle[cas_field] = battle[cas_field] + 1
                removeFromFleet(fleet_own, ship)

                if #fleet_own == 0 then
                    BattleManager.ConcludeBattle(key, conclude_winner)
                end
                return   -- ship found in this battle; stop searching
            end
        end
    end
end

-- Called from onShipHit.  Triggers retreat when hull drops below 20%.
function BattleManager.HandleShipHit(ship, attacker)
    for key, battle in pairs(BattleManager.active) do
        if battle.state == "ACTIVE" and battle.ship_set[ship] and ship:exists() then
            local ok, hp = pcall(function() return ship.hullPercent or ship:GetHullPercent() end)
            if ok and hp and hp < 20 then
                local retreating_side = battle.ship_set[ship]
                battle.ship_set[ship] = nil   -- stop tracking; ship retreats

                if retreating_side == "A" then
                    if removeFromFleet(battle.fleet_a, ship) then
                        battle.retreated_a = battle.retreated_a + 1
                    end
                else
                    if removeFromFleet(battle.fleet_b, ship) then
                        battle.retreated_b = battle.retreated_b + 1
                    end
                end
                ship:CancelAI()   -- ship drifts; no longer fights or is targeted

                -- Re-check conclusion after retreat
                if #battle.fleet_a == 0 and #battle.fleet_b == 0 then
                    BattleManager.ConcludeBattle(key, "DRAW")
                elseif #battle.fleet_a == 0 then
                    BattleManager.ConcludeBattle(key, "B")
                elseif #battle.fleet_b == 0 then
                    BattleManager.ConcludeBattle(key, "A")
                end
            end
            return   -- found our ship; stop iterating battles
        end
    end
end

-- Conclude a battle: record result, notify player, remove from active.
function BattleManager.ConcludeBattle(key, winner)
    local battle = BattleManager.active[key]
    if not battle then return end

    battle.state    = "CONCLUDED"
    battle.winner   = winner
    battle.end_time = Game.time

    local result = {
        system_name  = battle.system_name,
        conflict     = battle.conflict,
        winner       = winner,
        casualties_a = battle.casualties_a,
        casualties_b = battle.casualties_b,
        retreated_a  = battle.retreated_a,
        retreated_b  = battle.retreated_b,
        player_side  = battle.player_side,
        player_kills = battle.player_kills,
        end_time     = Game.time,
    }
    table.insert(BattleManager.history, 1, result)
    while #BattleManager.history > BattleManager.MAX_HISTORY do
        table.remove(BattleManager.history)
    end

    -- Player notification
    local ok, Comms = pcall(require, 'Comms')
    if ok and Comms then
        local msg
        if winner == "DRAW" then
            msg = string.format("Both fleets destroyed. %s vs %s — no victor.",
                battle.conflict.label_a, battle.conflict.label_b)
        elseif winner == "A" then
            msg = string.format("%s has defeated %s. Sector secured.",
                battle.conflict.label_a, battle.conflict.label_b)
        else
            msg = string.format("%s has defeated %s. Sector falls.",
                battle.conflict.label_b, battle.conflict.label_a)
        end
        Comms.ImportantMessage(msg, "Battle Network")

        -- Player combat payment
        if battle.player_side and battle.player_side == winner and battle.player_kills > 0 then
            local reward = battle.player_kills * 3000
            local paid, pay_err = pcall(function() Game.player:AddMoney(reward) end)
            if paid then
                Comms.ImportantMessage(
                    string.format("Combat payment: %d cr (%d kills).",
                        reward, battle.player_kills),
                    "Battle Network")
            else
                print("[FleetWar] AddMoney error: " .. tostring(pay_err))
                Comms.ImportantMessage(
                    string.format("Combat contract fulfilled (%d kills). Collect %d cr at any station.",
                        battle.player_kills, reward),
                    "Battle Network")
            end
        end
    end

    BattleManager.active[key] = nil
end

-- ── query helpers ─────────────────────────────────────────────────────────────

function BattleManager.GetActiveBattle()
    if not Game.system then return nil end
    return BattleManager.active[pathKey(Game.system.path)]
end

function BattleManager.GetHistory()
    return BattleManager.history
end

function BattleManager.ClearCurrentSystem()
    if not Game.system then return end
    BattleManager.active[pathKey(Game.system.path)] = nil
end

function BattleManager.Reset()
    BattleManager.active  = {}
    BattleManager.history = {}
end

return BattleManager
