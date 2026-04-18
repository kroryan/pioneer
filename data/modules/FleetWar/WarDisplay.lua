-- FleetWar/WarDisplay.lua
-- Bulletin Board integration: ongoing battle info + concluded battle news.
-- No event registration here; called from FleetWar.lua's onCreateBB handler.

local Game       = require 'Game'
local BattleManager = require 'modules.FleetWar.BattleManager'

local WarDisplay = {}

-- Helper: safe string format that never raises
local function fmt(s, ...) return string.format(s, ...) end

-- Add an ongoing-battle advert and concluded-battle news to a station BB.
function WarDisplay.AddAdverts(station)
    -- 1. Active battle in THIS system
    local battle = BattleManager.GetActiveBattle()
    if battle and battle.state == "ACTIVE" then
        local desc = fmt(
            "An active fleet engagement is ongoing in this system.\n\n"..
            "  %s — %d ships active, %d casualties, %d retreated\n"..
            "  %s — %d ships active, %d casualties, %d retreated\n\n"..
            "Pilots are advised to avoid the combat zone.\n"..
            "Combat contracts available; engage enemy ships to earn payment.",
            battle.conflict.label_a,
            #battle.fleet_a, battle.casualties_a, battle.retreated_a,
            battle.conflict.label_b,
            #battle.fleet_b, battle.casualties_b, battle.retreated_b)

        station:AddAdvert({
            title       = fmt("[CONFLICT] %s", battle.conflict.description),
            description = desc,
            icon        = "news",
            due         = Game.time + 7200,
            reward      = 0,
        })
    end

    -- 2. Historical battle reports (most recent first, max 4)
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
