-- Copyright © 2008-2026 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

--
-- Module: PersistentNPCTrade
--
-- Tracks NPC ship destruction and lost cargo to create realistic supply
-- deficits. When trade ships are destroyed, their cargo is lost and the
-- local economy reflects the shortage. Uses real CargoManager API.
-- Posts trade disruption warnings on the BulletinBoard.
--

local Engine      = require 'Engine'
local Event       = require 'Event'
local Game        = require 'Game'
local Timer       = require 'Timer'
local Serializer  = require 'Serializer'
local Commodities = require 'Commodities'

---@class PersistentNPCTrade
local PersistentNPCTrade = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- How much destroyed cargo affects stock (0.0 - 1.0)
local DEFICIT_IMPACT = 0.6

-- How fast deficits decay (per hour, fraction removed)
local DEFICIT_DECAY_RATE = 0.02

-- Maximum deficit per commodity per system
local MAX_DEFICIT = 200

-- Minimum cargo value to track destruction
local MIN_CARGO_VALUE = 50

-- ============================================================================
-- STATE
-- ============================================================================

-- {system_path_str -> {commodity_name -> deficit_amount}}
local supply_deficits = {}

-- Recent destruction log for BB display
-- {system_path_str -> {{commodity, amount, time}, ...}}
local destruction_log = {}

-- Statistics
local stats = {
	ships_destroyed = 0,
	total_cargo_lost = 0,
	total_value_lost = 0,
}

-- BB advert refs
local bb_ads = {}

-- ============================================================================
-- CARGO TRACKING
-- ============================================================================

local function GetSystemKey()
	if not Game.system then return nil end
	return tostring(Game.system.path)
end

local function RecordCargoDestruction(commodity_name, amount)
	local key = GetSystemKey()
	if not key then return end

	-- Update deficit
	if not supply_deficits[key] then supply_deficits[key] = {} end
	local current = supply_deficits[key][commodity_name] or 0
	supply_deficits[key][commodity_name] = math.min(current + amount * DEFICIT_IMPACT, MAX_DEFICIT)

	-- Log for BB display
	if not destruction_log[key] then destruction_log[key] = {} end
	table.insert(destruction_log[key], {
		commodity = commodity_name,
		amount = amount,
		time = Game.time,
	})

	-- Keep log manageable (last 20 events)
	while #destruction_log[key] > 20 do
		table.remove(destruction_log[key], 1)
	end
end

local function OnShipDestroyed(ship, attacker)
	if not ship or not ship:exists() then return end
	if ship:IsPlayer() then return end

	-- Try to read cargo from the destroyed ship
	local ok, cargoMgr = pcall(function() return ship:GetComponent('CargoManager') end)
	if not ok or not cargoMgr then return end

	local found_cargo = false
	for name, commodity in pairs(Commodities) do
		local count_ok, count = pcall(function() return cargoMgr:CountCommodity(commodity) end)
		if count_ok and count and count > 0 then
			RecordCargoDestruction(name, count)
			stats.total_cargo_lost = stats.total_cargo_lost + count
			stats.total_value_lost = stats.total_value_lost + count * (commodity.price or 0)
			found_cargo = true
		end
	end

	if found_cargo then
		stats.ships_destroyed = stats.ships_destroyed + 1
	end
end

-- Also track when jettisoned cargo is destroyed
local function OnCargoDestroyed(cargoBody, attacker)
	if not cargoBody then return end
	-- CargoBody has a commodity type
	local ok, commodity = pcall(function() return cargoBody.commodity end)
	if ok and commodity then
		local name = commodity.name or tostring(commodity)
		RecordCargoDestruction(name, 1)
		stats.total_cargo_lost = stats.total_cargo_lost + 1
	end
end

-- ============================================================================
-- DEFICIT APPLICATION
-- ============================================================================

-- Apply supply deficits to station stock when player docks
local function ApplyDeficitsAtStation(station)
	local key = GetSystemKey()
	if not key or not supply_deficits[key] then return end

	for commodity_name, deficit in pairs(supply_deficits[key]) do
		if deficit > 0.5 then
			local commodity = Commodities[commodity_name]
			if commodity then
				local ok, stock = pcall(function() return station:GetCommodityStock(commodity) end)
				if ok and stock then
					local reduction = math.min(math.floor(deficit), stock)
					if reduction > 0 then
						pcall(function() station:AddCommodityStock(commodity, -reduction) end)
					end
				end
			end
		end
	end
end

-- Decay deficits over time
local function DecayDeficits()
	for key, commodities in pairs(supply_deficits) do
		local to_remove = {}
		for name, deficit in pairs(commodities) do
			commodities[name] = deficit * (1.0 - DEFICIT_DECAY_RATE)
			if commodities[name] < 0.5 then
				table.insert(to_remove, name)
			end
		end
		for _, name in ipairs(to_remove) do
			commodities[name] = nil
		end
	end

	-- Clean old destruction logs (older than 7 game days)
	local cutoff = Game.time - 7 * 86400
	for key, logs in pairs(destruction_log) do
		local i = 1
		while i <= #logs do
			if logs[i].time < cutoff then
				table.remove(logs, i)
			else
				i = i + 1
			end
		end
	end
end

-- ============================================================================
-- BULLETIN BOARD INTEGRATION
-- ============================================================================

local function AddTradeWarnings(station)
	local key = GetSystemKey()
	if not key then return end

	local deficits = supply_deficits[key]
	if not deficits then return end

	-- Collect significant deficits
	local warnings = {}
	for name, deficit in pairs(deficits) do
		if deficit > 5 then
			local c = Commodities[name]
			if c then
				table.insert(warnings, {
					name = c:GetName(),
					deficit = math.floor(deficit),
				})
			end
		end
	end

	if #warnings == 0 then return end

	table.sort(warnings, function(a, b) return a.deficit > b.deficit end)

	local title = "Trade Route Disruption Warning"
	local desc = string.format("%d commodities affected by recent ship losses", #warnings)

	local ref = station:AddAdvert({
		title       = title,
		description = desc,
		icon        = "news",
		onChat      = function(form, ref, option)
			form:Clear()
			form:SetTitle("Trade Route Security Report")

			local msg = "Recent pirate attacks and ship losses have disrupted supply lines in this system.\n\n"
			msg = msg .. "Supply shortages detected:\n"
			for _, w in ipairs(warnings) do
				msg = msg .. string.format("  %s: deficit of ~%d units\n", w.name, w.deficit)
			end
			msg = msg .. string.format("\nTotal ships lost: %d\n", stats.ships_destroyed)
			msg = msg .. string.format("Total cargo destroyed: %d tonnes\n", stats.total_cargo_lost)
			msg = msg .. "\nTraders who can supply these commodities may find premium prices."

			form:SetMessage(msg)
		end,
		onDelete = function(ref)
			bb_ads[ref] = nil
		end,
	})
	if ref then
		bb_ads[ref] = { station = station }
	end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

Event.Register("onShipDestroyed", OnShipDestroyed)

Event.Register("onCargoDestroyed", OnCargoDestroyed)

Event.Register("onPlayerDocked", function(player, station)
	ApplyDeficitsAtStation(station)
end)

Event.Register("onCreateBB", function(station)
	AddTradeWarnings(station)
end)

Event.Register("onGameStart", function()
	supply_deficits = supply_deficits or {}
	destruction_log = destruction_log or {}
	bb_ads = {}
	stats.ships_destroyed = stats.ships_destroyed or 0
	stats.total_cargo_lost = stats.total_cargo_lost or 0
	stats.total_value_lost = stats.total_value_lost or 0

	-- Decay deficits every game hour
	Timer:CallEvery(3600, DecayDeficits)
end)

Event.Register("onGameEnd", function()
	supply_deficits = {}
	destruction_log = {}
	bb_ads = {}
	stats = { ships_destroyed = 0, total_cargo_lost = 0, total_value_lost = 0 }
end)

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

Serializer:Register("PersistentNPCTrade",
	function()
		return {
			deficits = supply_deficits,
			log = destruction_log,
			stats = stats,
		}
	end,
	function(data)
		if not data then return end
		supply_deficits = data.deficits or {}
		destruction_log = data.log or {}
		stats = data.stats or { ships_destroyed = 0, total_cargo_lost = 0, total_value_lost = 0 }
	end
)

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function PersistentNPCTrade.GetShipmentStatus()
	return {
		active_shipments = 0,
		destroyed_shipments = stats.ships_destroyed,
		delivered_shipments = 0,
		total_value = stats.total_value_lost,
		total_cargo_lost = stats.total_cargo_lost,
	}
end

function PersistentNPCTrade.GetSupplyDeficits()
	local key = GetSystemKey()
	if not key then return {} end
	return supply_deficits[key] or {}
end

function PersistentNPCTrade.GetDestructionLog()
	local key = GetSystemKey()
	if not key then return {} end
	return destruction_log[key] or {}
end

function PersistentNPCTrade.GetRegionalDependencies()
	return PersistentNPCTrade.GetSupplyDeficits()
end

function PersistentNPCTrade.GetDamagedCargoStatistics()
	return stats
end

function PersistentNPCTrade.GetStats()
	return stats
end

return PersistentNPCTrade
