-- FleetWar.lua — Fleet War Mod for Pioneer Space Simulator (kroryan build)
--
-- Spawns faction fleet battles in conflict zones based on system lawlessness.
-- Ships fight autonomously using Pioneer's built-in AI (AIKill).
-- Complements DynamicSystemEvents: Civil War events → larger battles.
-- Player can participate by destroying enemy ships → receives automatic payment.
--
-- DESIGN PRINCIPLES — no interference with existing systems:
--   • Serializer key "FleetWar" (unique; Pirates="Pirates", DSE="DynamicSystemEvents")
--   • No global variable names shared with any other module
--   • Only tracks ships we spawned (ship_set membership test before any action)
--   • Reads DSE state but never modifies it
--   • onShipDestroyed / onShipHit only act on our tracked ships
--   • All cleanup happens in onLeaveSystem / onGameEnd
--
-- Public API (for QuickTest and inter-module use):
--   FleetWar.GetVersion()       → string
--   FleetWar.GetActiveBattle()  → battle table or nil
--   FleetWar.GetBattleHistory() → array of result tables
--   FleetWar.GetStats()         → aggregate statistics table

local Event      = require 'Event'
local Timer      = require 'Timer'
local Serializer = require 'Serializer'
local Game       = require 'Game'

local WarFactions   = require 'modules.FleetWar.WarFactions'
local BattleManager = require 'modules.FleetWar.BattleManager'
local WarDisplay    = require 'modules.FleetWar.WarDisplay'

local FleetWar = {}
FleetWar.VERSION = "1.0.0"

-- ── internal state ────────────────────────────────────────────────────────────

-- Key of the system for which our update timer was created.
-- Used to stop the timer if the player jumps away.
local fw_timer_system_key = nil

-- ── helpers ───────────────────────────────────────────────────────────────────

local function systemKey(sys)
    if not sys then return nil end
    local p = sys.path
    return string.format("%d,%d,%d:%d", p.sectorX, p.sectorY, p.sectorZ, p.systemIndex)
end

-- Check if DynamicSystemEvents has an active CIVIL_WAR in the current system.
-- Returns false safely if DSE is not loaded.
local function hasCivilWar()
    local ok, DSE = pcall(require, 'modules.DynamicSystemEvents')
    if not ok or not DSE then return false end
    local ok2, events = pcall(function() return DSE.GetSystemEvents() end)
    if not ok2 or not events then return false end
    for _, ev in pairs(events) do
        if ev.type_key == "CIVIL_WAR" then return true end
    end
    return false
end

-- Attempt to spawn a battle for the current system.
local function trySpawnBattle()
    if not Game.system then return end

    local conflict = WarFactions.GetSystemConflict(Game.system)
    if not conflict then return end

    -- Random chance filter
    if math.random() > WarFactions.SPAWN_CHANCE then return end

    local civil_war  = hasCivilWar()
    local fleet_size = WarFactions.GetFleetSize(Game.system, civil_war)
    local threat     = WarFactions.GetThreat(Game.system)

    local battle = BattleManager.SpawnBattle(conflict, fleet_size, threat)
    if not battle then return end

    -- Capture system key at spawn time for the update timer
    local spawn_key = systemKey(Game.system)
    fw_timer_system_key = spawn_key

    -- Periodic update: reassign AI targets, check battle end
    Timer:CallEvery(45, function()
        -- Stop if player has left this system
        if not Game.system then return true end
        if systemKey(Game.system) ~= spawn_key then return true end
        -- Stop if battle concluded
        if not BattleManager.active[spawn_key] then return true end

        BattleManager.UpdateBattle(spawn_key)
        return false   -- keep firing
    end)

    -- Announce battle to player
    local ok, Comms = pcall(require, 'Comms')
    if ok and Comms then
        local intensity = civil_war and "MAJOR" or "MINOR"
        Comms.ImportantMessage(
            string.format(
                "Navigation alert: %s fleet engagement detected.\n"..
                "%s vs. %s — %d ships per side.\n"..
                "Engage enemy ships to earn combat payment.",
                intensity, conflict.label_a, conflict.label_b, fleet_size),
            "Navigation System")
    end
end

-- ── event handlers ─────────────────────────────────────────────────────────────

Event.Register("onEnterSystem", function(ship)
    if not ship:IsPlayer() then return end
    -- Small delay: let the system finish loading before spawning
    Timer:CallAt(Game.time + 5, trySpawnBattle)
end)

Event.Register("onLeaveSystem", function(ship)
    if not ship:IsPlayer() then return end
    BattleManager.ClearCurrentSystem()
    fw_timer_system_key = nil
end)

-- Only acts on ships we are tracking (O(1) set membership check inside)
Event.Register("onShipDestroyed", function(ship, attacker)
    BattleManager.HandleShipDestroyed(ship, attacker)
end)

-- Hull retreat check — only runs when ship is in our battle
Event.Register("onShipHit", function(ship, attacker)
    BattleManager.HandleShipHit(ship, attacker)
end)

-- BB adverts: battle status + history news
Event.Register("onCreateBB", function(station)
    WarDisplay.AddAdverts(station)
end)

Event.Register("onGameStart", function()
    BattleManager.Reset()
    fw_timer_system_key = nil
end)

Event.Register("onGameEnd", function()
    BattleManager.Reset()
    fw_timer_system_key = nil
end)

-- ── serialization ──────────────────────────────────────────────────────────────
-- We persist battle history across saves.
-- Active battle ships are NOT serialized (like Pirates.lua) — they are ephemeral
-- game objects that cease to exist when the game ends.

Serializer:Register("FleetWar",
    function()
        return {
            version = FleetWar.VERSION,
            history = BattleManager.history,
        }
    end,
    function(data)
        if data then
            BattleManager.history = data.history or {}
        end
    end
)

-- ── public API (used by QuickTest) ────────────────────────────────────────────

function FleetWar.GetVersion()
    return FleetWar.VERSION
end

function FleetWar.GetActiveBattle()
    return BattleManager.GetActiveBattle()
end

function FleetWar.GetBattleHistory()
    return BattleManager.GetHistory()
end

function FleetWar.GetStats()
    local battle  = BattleManager.GetActiveBattle()
    local history = BattleManager.GetHistory()
    local gov_wins, rebel_wins, draws = 0, 0, 0
    for _, r in ipairs(history) do
        if     r.winner == "A"    then gov_wins   = gov_wins + 1
        elseif r.winner == "B"    then rebel_wins = rebel_wins + 1
        else                           draws       = draws + 1
        end
    end
    return {
        active          = battle ~= nil,
        active_fleet_a  = battle and #battle.fleet_a or 0,
        active_fleet_b  = battle and #battle.fleet_b or 0,
        active_casualties_a = battle and battle.casualties_a or 0,
        active_casualties_b = battle and battle.casualties_b or 0,
        total_battles   = #history,
        government_wins = gov_wins,
        rebel_wins      = rebel_wins,
        draws           = draws,
    }
end

function FleetWar.IsEnabled()
    return true
end

return FleetWar
