-- FleetWar/WarDisplay.lua
-- Bulletin Board integration: ongoing battle info, concluded battle news, war zone contracts.
-- No event registration here; called from FleetWar.lua's onCreateBB handler.

local Game       = require 'Game'
local Engine     = require 'Engine'
local Comms      = require 'Comms'
local BattleManager = require 'modules.FleetWar.BattleManager'
local WarFactions   = require 'modules.FleetWar.WarFactions'
local MissionUtils  = require 'modules.MissionUtils'

local WarDisplay = {}

-- Helper: safe string format that never raises
local function fmt(s, ...) return string.format(s, ...) end

-- ── War Zone Contract onChat callback ─────────────────────────────────────────
-- When player clicks an active battle advert, they get info and can choose a side.
local function onBattleChat(form, ref, option)
    local battle = BattleManager.GetActiveBattle()

    if not battle or battle.state ~= "ACTIVE" then
        form:SetMessage("The battle has concluded. No contracts available.")
        form:RemoveAdvertOnClose()
        return
    end

    if option == 0 or option == -1 then
        -- Initial view
        form:SetTitle("[CONFLICT ZONE] " .. battle.conflict.description)
        form:SetMessage(fmt(
            "An active fleet engagement is in progress near %s.\n\n"..
            "  %s — %d ships active, %d casualties\n"..
            "  %s — %d ships active, %d casualties\n\n"..
            "Combat payment: 3,000 cr per confirmed kill.\n"..
            "Payment issued if your side wins.\n\n"..
            "Engage enemy ships to join a side automatically,\nor accept a war zone contract below.",
            battle.battle_body_name or "this system",
            battle.conflict.label_a, #battle.fleet_a, battle.casualties_a,
            battle.conflict.label_b, #battle.fleet_b, battle.casualties_b))

        form:AddOption("Accept contract — fight for " .. battle.conflict.label_a, "SIDE_A")
        form:AddOption("Accept contract — fight for " .. battle.conflict.label_b, "SIDE_B")
        form:AddOption("Decline — just viewing", "DECLINE")

    elseif option == "SIDE_A" then
        battle.player_side = "A"
        form:SetMessage(fmt(
            "Contract accepted. You are now fighting for %s.\n\n"..
            "Engage %s ships to earn combat payment.\n"..
            "Head to the battle zone near %s.",
            battle.conflict.label_a, battle.conflict.label_b,
            battle.battle_body_name or "the system"))
        Comms.ImportantMessage(
            fmt("War zone contract: fight for %s. Proceed to %s.",
                battle.conflict.label_a, battle.battle_body_name or "conflict zone"),
            "Battle Network")
        form:RemoveAdvertOnClose()

    elseif option == "SIDE_B" then
        battle.player_side = "B"
        form:SetMessage(fmt(
            "Contract accepted. You are now fighting for %s.\n\n"..
            "Engage %s ships to earn combat payment.\n"..
            "Head to the battle zone near %s.",
            battle.conflict.label_b, battle.conflict.label_a,
            battle.battle_body_name or "the system"))
        Comms.ImportantMessage(
            fmt("War zone contract: fight for %s. Proceed to %s.",
                battle.conflict.label_b, battle.battle_body_name or "conflict zone"),
            "Battle Network")
        form:RemoveAdvertOnClose()

    elseif option == "DECLINE" then
        form:SetMessage("Understood. Fly safe, commander.")
        form:RemoveAdvertOnClose()
    end
end

-- ── War Zone Contract trigger ─────────────────────────────────────────────────
-- When player accepts a contract in a system with no battle, force-spawn one.
local function onWarContractChat(form, ref, option)
    if option == 0 or option == -1 then
        form:SetTitle("[WAR ZONE CONTRACT] Combat Opportunity")
        form:SetMessage(
            "Intelligence reports indicate faction tensions in this system.\n\n"..
            "A fleet engagement can be triggered by accepting this contract.\n"..
            "You will be paid 3,000 cr per confirmed kill if your side wins.\n\n"..
            "WARNING: This will spawn hostile ships in the system.")
        form:AddOption("Accept contract — trigger engagement", "TRIGGER")
        form:AddOption("Decline", "DECLINE")

    elseif option == "TRIGGER" then
        -- Force spawn a battle
        local battle = BattleManager.GetActiveBattle()
        if battle then
            form:SetMessage("A battle is already in progress. Head to the conflict zone.")
            form:RemoveAdvertOnClose()
            return
        end

        local conflict = WarFactions.GetSystemConflict(Game.system)
        if not conflict then
            -- Force a generic conflict even if lawlessness is low
            local faction_name = (Game.system.faction and Game.system.faction.name) or "Independent"
            conflict = {
                faction_name = faction_name,
                label_a = faction_name .. " Security",
                label_b = "Insurgent Wing",
                description = faction_name .. " Security vs. Insurgent Wing",
            }
        end

        local fleet_size = 3 + Engine.rand:Integer(0, 3)  -- 3-6 ships per side
        local threat = math.floor(30 + Engine.rand:Number(30))

        local new_battle = BattleManager.SpawnBattle(conflict, fleet_size, threat)
        if new_battle then
            form:SetMessage(fmt(
                "Engagement triggered!\n\n"..
                "%s vs %s — %d ships per side near %s.\n\n"..
                "Engage enemy ships to earn combat payment.",
                conflict.label_a, conflict.label_b, fleet_size,
                new_battle.battle_body_name or "the system"))
            Comms.ImportantMessage(
                fmt("ALERT: Fleet battle initiated near %s. %d ships per side.",
                    new_battle.battle_body_name or "target", fleet_size),
                "Battle Network")

            -- Return info to FleetWar.lua for timer setup
            WarDisplay._last_triggered_battle = new_battle
        else
            form:SetMessage("Unable to deploy fleets in this system. Try another location.")
        end
        form:RemoveAdvertOnClose()

    elseif option == "DECLINE" then
        form:SetMessage("Contract declined. Fly safe, commander.")
        form:RemoveAdvertOnClose()
    end
end

-- Add an ongoing-battle advert and concluded-battle news to a station BB.
function WarDisplay.AddAdverts(station)
    -- 1. Active battle in THIS system — with interactive onChat
    local battle = BattleManager.GetActiveBattle()
    if battle and battle.state == "ACTIVE" then
        local desc = fmt(
            "An active fleet engagement is ongoing near %s.\n\n"..
            "  %s — %d ships active, %d casualties, %d retreated\n"..
            "  %s — %d ships active, %d casualties, %d retreated\n\n"..
            "Click to view details and accept a combat contract.",
            battle.battle_body_name or "this system",
            battle.conflict.label_a,
            #battle.fleet_a, battle.casualties_a, battle.retreated_a,
            battle.conflict.label_b,
            #battle.fleet_b, battle.casualties_b, battle.retreated_b)

        station:AddAdvert({
            title       = fmt("[CONFLICT] %s", battle.conflict.description),
            description = desc,
            icon        = "combat",
            due         = Game.time + 7200,
            reward      = 0,
            onChat      = onBattleChat,
        })
    end

    -- 2. War zone contract — available in inhabited systems even without active battle
    if not battle and Game.system and (Game.system.population or 0) > 0 then
        station:AddAdvert({
            title       = "[WAR ZONE] Combat Contract Available",
            description = "Faction intelligence reports tensions in this system.\n"..
                          "Accept to trigger a fleet engagement and earn combat pay.\n"..
                          "Payment: 3,000 cr per confirmed kill.",
            icon        = "combat",
            due         = Game.time + 86400,
            reward      = 0,
            onChat      = onWarContractChat,
        })
    end

    -- 3. Historical battle reports (most recent first, max 4)
    local history = BattleManager.GetHistory()
    for i, result in ipairs(history) do
        if i > 4 then break end

        local title, body
        local c = result.conflict

        if result.winner == "DRAW" then
            title = fmt("BATTLE REPORT — Mutual Destruction: %s", result.system_name)
            body  = fmt(
                "Both fleets were annihilated in %s.\n\n"..
                "%s: %d killed, %d retreated\n"..
                "%s: %d killed, %d retreated\n\nNo victor declared.",
                result.system_name,
                c.label_a, result.casualties_a, result.retreated_a,
                c.label_b, result.casualties_b, result.retreated_b)

        elseif result.winner == "A" then
            title = fmt("VICTORY — %s secures %s", c.label_a, result.system_name)
            body  = fmt(
                "%s has defeated %s in %s.\n\n"..
                "Winner (%s): %d losses, %d retreated\n"..
                "Defeated (%s): %d losses, %d retreated",
                c.label_a, c.label_b, result.system_name,
                c.label_a, result.casualties_a, result.retreated_a,
                c.label_b, result.casualties_b, result.retreated_b)

        else   -- winner == "B"
            title = fmt("VICTORY — %s secures %s", c.label_b, result.system_name)
            body  = fmt(
                "%s has defeated %s in %s.\n\n"..
                "Winner (%s): %d losses, %d retreated\n"..
                "Defeated (%s): %d losses, %d retreated",
                c.label_b, c.label_a, result.system_name,
                c.label_b, result.casualties_b, result.retreated_b,
                c.label_a, result.casualties_a, result.retreated_a)
        end

        if result.player_kills and result.player_kills > 0 then
            body = body .. fmt("\n\nYour contribution: %d kills (side %s).",
                result.player_kills, result.player_side or "?")
        end

        station:AddAdvert({
            title       = title,
            description = body,
            icon        = "news",
            due         = Game.time + 86400 * 3,
            reward      = 0,
        })
    end
end

return WarDisplay
