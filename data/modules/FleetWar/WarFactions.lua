-- FleetWar/WarFactions.lua
-- Conflict condition logic and faction label generation.
-- Pure data + functions, no side effects, no event registration.

local Engine = require 'Engine'

local WarFactions = {}

-- Minimum lawlessness to trigger a battle (lowered from 0.25 for more frequent battles)
local MIN_LAWLESSNESS = 0.15
-- Probability that a qualifying system actually has a battle (checked in FleetWar.lua)
WarFactions.SPAWN_CHANCE = 0.55

-- Fleet size thresholds by lawlessness
local SIZE_THRESHOLDS = {
    { max = 0.35, size = 3 },
    { max = 0.55, size = 5 },
    { max = 0.75, size = 7 },
    { max = 1.00, size = 9 },
}

-- Returns a conflict descriptor for the given system, or nil if no battle should occur.
-- A conflict descriptor: { faction_name, label_a, label_b, description }
function WarFactions.GetSystemConflict(system)
    if not system then return nil end
    if (system.population or 0) == 0 then return nil end
    if (system.lawlessness or 0) < MIN_LAWLESSNESS then return nil end

    local faction_name = (system.faction and system.faction.name) or "Independent"

    -- Name the two sides based on faction identity
    local label_a, label_b
    if faction_name:find("Federation") then
        label_a = "Fed. Enforcement Wing"
        label_b = "Anti-Federation Front"
    elseif faction_name:find("Empire") then
        label_a = "Imperial Guard"
        label_b = "Republic Insurgency"
    elseif faction_name:find("Independent") or faction_name:find("Alliance") then
        label_a = "Planetary Defence Force"
        label_b = "Raider Coalition"
    else
        label_a = faction_name .. " Military"
        label_b = "Insurgent Wing"
    end

    return {
        faction_name = faction_name,
        label_a      = label_a,
        label_b      = label_b,
        description  = label_a .. " vs. " .. label_b,
    }
end

-- Returns how many ships each side should have.
-- has_civil_war: true when DynamicSystemEvents has an active CIVIL_WAR event.
function WarFactions.GetFleetSize(system, has_civil_war)
    local l = system.lawlessness or 0
    local size = SIZE_THRESHOLDS[#SIZE_THRESHOLDS].size
    for _, t in ipairs(SIZE_THRESHOLDS) do
        if l <= t.max then
            size = t.size
            break
        end
    end
    if has_civil_war then
        size = math.min(size + 2, 12)
    end
    return size
end

-- Returns a threat factor for ships in this system.
function WarFactions.GetThreat(system)
    local l = system.lawlessness or 0.3
    return math.floor(30 + Engine.rand:Number(l * 50))
end

return WarFactions
