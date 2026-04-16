-- Copyright © 2008-2026 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

--
-- Module: DynamicSystemEvents
--
-- Creates multi-commodity systemic events that affect local economies.
-- Events are driven by system characteristics (lawlessness, population)
-- and apply REAL price/stock effects via Pioneer's Economy APIs.
-- Complements (does not replace) the built-in NewsEventCommodity module.
--

local Engine      = require 'Engine'
local Event       = require 'Event'
local Game        = require 'Game'
local Timer       = require 'Timer'
local Serializer  = require 'Serializer'
local Economy     = require 'Economy'
local Commodities = require 'Commodities'

---@class DynamicSystemEvents
local DynamicSystemEvents = {}

-- ============================================================================
-- EVENT TYPE DEFINITIONS
-- Each event affects multiple commodities simultaneously.
-- price_mult: multiplier for price (>1 = more expensive, <1 = cheaper)
-- stock_mult: multiplier for stock (>1 = more available, <1 = scarce)
-- ============================================================================

local EventTypes = {
	CIVIL_WAR = {
		name = "Civil War",
		duration_range = { 48, 96 },
		severity_range = { 0.5, 1.0 },
		base_prob = 0.06,
		condition = function(sys)
			return sys.lawlessness > 0.3 and sys.population > 0.01
		end,
		effects = {
			{ cargo = "battle_weapons",  price_mult = 2.4, stock_mult = 0.3 },
			{ cargo = "hand_weapons",    price_mult = 2.0, stock_mult = 0.4 },
			{ cargo = "military_fuel",   price_mult = 1.7, stock_mult = 0.5 },
			{ cargo = "medicines",       price_mult = 1.5, stock_mult = 0.6 },
			{ cargo = "consumer_goods",  price_mult = 0.7, stock_mult = 1.4 },
		},
		headline = "Civil War in %s",
		body = "Armed conflict has erupted. Military goods are in extreme demand while civilian trade is disrupted. Weapons, fuel and medical supplies command premium prices.",
	},
	FAMINE = {
		name = "Famine",
		duration_range = { 36, 72 },
		severity_range = { 0.6, 1.0 },
		base_prob = 0.05,
		condition = function(sys)
			return sys.population > 0.001
		end,
		effects = {
			{ cargo = "grain",           price_mult = 2.8, stock_mult = 0.2 },
			{ cargo = "fruit_and_veg",   price_mult = 2.5, stock_mult = 0.3 },
			{ cargo = "animal_meat",     price_mult = 2.2, stock_mult = 0.3 },
			{ cargo = "live_animals",    price_mult = 1.8, stock_mult = 0.5 },
			{ cargo = "fertilizer",      price_mult = 1.6, stock_mult = 0.6 },
			{ cargo = "farm_machinery",  price_mult = 1.4, stock_mult = 0.7 },
		},
		headline = "Famine in %s",
		body = "Severe food shortages are devastating the population. All agricultural commodities are in critical demand. Traders carrying food supplies can expect exceptional prices.",
	},
	ECONOMIC_BOOM = {
		name = "Economic Boom",
		duration_range = { 60, 120 },
		severity_range = { 0.3, 0.8 },
		base_prob = 0.04,
		condition = function(sys)
			return sys.population > 0.1
		end,
		effects = {
			{ cargo = "consumer_goods",  price_mult = 1.5, stock_mult = 0.6 },
			{ cargo = "liquor",          price_mult = 1.4, stock_mult = 0.7 },
			{ cargo = "computers",       price_mult = 1.3, stock_mult = 0.7 },
			{ cargo = "robots",          price_mult = 1.3, stock_mult = 0.8 },
			{ cargo = "textiles",        price_mult = 1.2, stock_mult = 0.8 },
		},
		headline = "Economic Boom in %s",
		body = "A period of rapid economic expansion is driving demand for consumer goods and luxury items. Profits are up across the board.",
	},
	NATURAL_DISASTER = {
		name = "Natural Disaster",
		duration_range = { 24, 60 },
		severity_range = { 0.7, 1.0 },
		base_prob = 0.04,
		condition = function(sys)
			return sys.population > 0.0001
		end,
		effects = {
			{ cargo = "air_processors",        price_mult = 2.2, stock_mult = 0.3 },
			{ cargo = "water",                 price_mult = 2.0, stock_mult = 0.4 },
			{ cargo = "medicines",             price_mult = 1.8, stock_mult = 0.5 },
			{ cargo = "industrial_machinery",  price_mult = 1.6, stock_mult = 0.6 },
			{ cargo = "plastics",              price_mult = 1.4, stock_mult = 0.7 },
		},
		headline = "Natural Disaster in %s",
		body = "A catastrophic natural event has damaged critical infrastructure. Emergency supplies including air processors, water and medical aid are urgently needed.",
	},
	PLAGUE = {
		name = "Plague",
		duration_range = { 36, 84 },
		severity_range = { 0.6, 1.0 },
		base_prob = 0.03,
		condition = function(sys)
			return sys.population > 0.01
		end,
		effects = {
			{ cargo = "medicines",    price_mult = 3.0, stock_mult = 0.2 },
			{ cargo = "chemicals",    price_mult = 2.0, stock_mult = 0.4 },
			{ cargo = "narcotics",    price_mult = 1.6, stock_mult = 0.5 },
			{ cargo = "live_animals", price_mult = 0.5, stock_mult = 2.0 },
		},
		headline = "Plague Outbreak in %s",
		body = "A virulent disease is spreading rapidly. Medical supplies and chemicals are desperately needed. Livestock quarantines have crashed animal prices.",
	},
	PIRATE_RAIDS = {
		name = "Pirate Raids",
		duration_range = { 24, 48 },
		severity_range = { 0.5, 1.0 },
		base_prob = 0.07,
		condition = function(sys)
			return sys.lawlessness > 0.4
		end,
		effects = {
			{ cargo = "precious_metals", price_mult = 1.8, stock_mult = 0.4 },
			{ cargo = "hand_weapons",    price_mult = 1.6, stock_mult = 0.5 },
			{ cargo = "narcotics",       price_mult = 1.5, stock_mult = 0.6 },
			{ cargo = "slaves",          price_mult = 1.4, stock_mult = 0.7 },
		},
		headline = "Pirate Raids near %s",
		body = "Organised pirate activity is disrupting trade routes. High-value cargo is being intercepted. Weapons demand has risen sharply for self-defence.",
	},
	MINING_BOOM = {
		name = "Mining Boom",
		duration_range = { 48, 96 },
		severity_range = { 0.4, 0.9 },
		base_prob = 0.04,
		condition = function(sys)
			-- Systems that export ores (negative alteration = surplus)
			if not sys or not sys.GetCommodityBasePriceAlterations then return false end
			local alt = sys:GetCommodityBasePriceAlterations("metal_ore")
			return alt and alt < -5
		end,
		effects = {
			{ cargo = "metal_ore",         price_mult = 0.5, stock_mult = 2.5 },
			{ cargo = "carbon_ore",        price_mult = 0.6, stock_mult = 2.0 },
			{ cargo = "precious_metals",   price_mult = 0.7, stock_mult = 1.8 },
			{ cargo = "mining_machinery",  price_mult = 1.6, stock_mult = 0.5 },
		},
		headline = "Mining Boom in %s",
		body = "A major mineral discovery has flooded local markets with raw materials. Ore prices have plummeted while mining equipment demand has surged.",
	},
	TECH_REVOLUTION = {
		name = "Tech Revolution",
		duration_range = { 60, 120 },
		severity_range = { 0.3, 0.7 },
		base_prob = 0.03,
		condition = function(sys)
			return sys.population > 0.5
		end,
		effects = {
			{ cargo = "computers",  price_mult = 1.8, stock_mult = 0.4 },
			{ cargo = "robots",     price_mult = 1.7, stock_mult = 0.5 },
			{ cargo = "chemicals",  price_mult = 1.3, stock_mult = 0.7 },
		},
		headline = "Tech Revolution in %s",
		body = "A technological breakthrough has created massive demand for computing and robotic systems. Prices for high-tech goods have soared.",
	},
}

-- Maximum simultaneous events per system
local MAX_EVENTS_PER_SYSTEM = 2

-- ============================================================================
-- STATE
-- ============================================================================

-- {system_key_string -> { event_id -> event_data }}
local active_events = {}
local event_id_counter = 0

-- {station_path_string -> {commodity_name -> {price, stock, supply, demand}}}
-- Temporary cache of original values while docked (not serialized)
local price_cache = {}

-- BB advert references for cleanup
local bb_ads = {}

-- Convert SystemPath to stable string key for serialization
local function PathKey(path)
	if type(path) == "string" then return path end
	if not path then return "?" end
	return string.format("%d,%d,%d:%d", path.sectorX, path.sectorY, path.sectorZ, path.systemIndex)
end

-- ============================================================================
-- HELPERS
-- ============================================================================

local function SafeGetCommodity(name)
	if not Commodities[name] then return nil end
	return Commodities[name]
end

-- Interpolate severity into effect multipliers
-- severity 0 = half effect, severity 1 = full effect
local function ApplySeverity(base_mult, severity)
	if base_mult >= 1.0 then
		return 1.0 + (base_mult - 1.0) * (0.5 + 0.5 * severity)
	else
		return 1.0 - (1.0 - base_mult) * (0.5 + 0.5 * severity)
	end
end

-- Count events for a system
local function CountSystemEvents(sys_key)
	if not active_events[sys_key] then return 0 end
	local n = 0
	for _ in pairs(active_events[sys_key]) do n = n + 1 end
	return n
end

-- ============================================================================
-- EVENT GENERATION
-- ============================================================================

local function GenerateEvents()
	if not Game.system then return end

	local sys = Game.system
	local sys_key = PathKey(sys.path)

	if not active_events[sys_key] then
		active_events[sys_key] = {}
	end

	-- Remove expired events
	local to_remove = {}
	for eid, ev in pairs(active_events[sys_key]) do
		if ev.end_time <= Game.time then
			table.insert(to_remove, eid)
		end
	end
	for _, eid in ipairs(to_remove) do
		active_events[sys_key][eid] = nil
	end

	-- Don't exceed maximum
	if CountSystemEvents(sys_key) >= MAX_EVENTS_PER_SYSTEM then return end

	-- Roll for each event type
	for type_key, etype in pairs(EventTypes) do
		if CountSystemEvents(sys_key) >= MAX_EVENTS_PER_SYSTEM then break end

		-- Check conditions
		local cond_ok = true
		if etype.condition then
			local ok, result = pcall(etype.condition, sys)
			cond_ok = ok and result
		end
		if not cond_ok then goto continue end

		-- Check if this event type is already active
		local already_active = false
		for _, ev in pairs(active_events[sys_key]) do
			if ev.type_key == type_key then already_active = true; break end
		end
		if already_active then goto continue end

		-- Roll probability
		if Engine.rand:Number() < etype.base_prob then
			event_id_counter = event_id_counter + 1
			local sev = Engine.rand:Number(etype.severity_range[1], etype.severity_range[2])
			local dur = Engine.rand:Number(etype.duration_range[1], etype.duration_range[2])

			active_events[sys_key][event_id_counter] = {
				id = event_id_counter,
				type_key = type_key,
				name = etype.name,
				headline = string.format(etype.headline, sys.name),
				body = etype.body,
				start_time = Game.time,
				end_time = Game.time + dur * 3600,
				severity = sev,
				system_key = sys_key,
			}
		end

		::continue::
	end
end

-- ============================================================================
-- PRICE EFFECTS: Apply on dock, restore on undock
-- Same pattern as the built-in NewsEventCommodity module.
-- ============================================================================

local function ApplyEffectsAtStation(station)
	if not Game.system then return end
	local sys_key = PathKey(Game.system.path)
	local events = active_events[sys_key]
	if not events then return end

	local sta_key = PathKey(station.path)
	price_cache[sta_key] = price_cache[sta_key] or {}

	for _, ev in pairs(events) do
		local etype = EventTypes[ev.type_key]
		if not etype then goto next_event end

		for _, eff in ipairs(etype.effects) do
			local commodity = SafeGetCommodity(eff.cargo)
			if not commodity then goto next_effect end

			-- Only save original once per commodity per dock session
			if not price_cache[sta_key][eff.cargo] then
				local ok1, price = pcall(function() return station:GetCommodityPrice(commodity) end)
				local ok2, market = pcall(function() return station:GetCommodityMarket() end)
				if ok1 and ok2 and market then
					local id = commodity.name
					price_cache[sta_key][eff.cargo] = {
						price  = price,
						stock  = market.stock[id] or 0,
						supply = market.supply[id] or 0,
						demand = market.demand[id] or 0,
					}
				end
			end

			-- Apply severity-scaled effects
			local cached = price_cache[sta_key][eff.cargo]
			if cached then
				local pm = ApplySeverity(eff.price_mult, ev.severity)
				local sm = ApplySeverity(eff.stock_mult, ev.severity)
				local newPrice = math.max(1, math.floor(cached.price * pm))
				local newStock = math.max(0, math.floor(cached.stock * sm))
				local newSupply = cached.supply
				local newDemand = cached.demand

				if pm > 1.0 then
					newDemand = math.ceil(cached.demand * pm)
					newSupply = math.floor(cached.supply * sm)
				else
					newSupply = math.ceil(cached.supply * (2.0 - pm))
					newDemand = math.floor(cached.demand * pm)
				end

				pcall(function() station:SetCommodityPrice(commodity, newPrice) end)
				pcall(function() station:SetCommodityStock(commodity, newStock, newSupply, newDemand) end)
			end

			::next_effect::
		end
		::next_event::
	end
end

local function RestoreEffectsAtStation(station)
	local sta_key = PathKey(station.path)
	local cached = price_cache[sta_key]
	if not cached then return end

	for cargo_name, orig in pairs(cached) do
		local commodity = SafeGetCommodity(cargo_name)
		if commodity then
			pcall(function() station:SetCommodityPrice(commodity, orig.price) end)
			pcall(function() station:SetCommodityStock(commodity, orig.stock, orig.supply, orig.demand) end)
		end
	end

	price_cache[sta_key] = nil
end

-- ============================================================================
-- BULLETIN BOARD INTEGRATION
-- ============================================================================

local function AddEventAdverts(station)
	if not Game.system then return end
	local events = active_events[PathKey(Game.system.path)]
	if not events then return end

	for eid, ev in pairs(events) do
		local ref = station:AddAdvert({
			title       = ev.headline,
			description = ev.body,
			icon        = "news",
			onChat      = function(form, ref, option)
				form:Clear()
				form:SetTitle(ev.headline)

				local remaining = math.max(0, ev.end_time - Game.time)
				local hours_left = math.floor(remaining / 3600)
				local severity_pct = math.floor(ev.severity * 100)

				local msg = ev.body .. "\n\n"
				msg = msg .. string.format("Severity: %d%%\n", severity_pct)
				msg = msg .. string.format("Estimated duration: %d hours remaining\n", hours_left)

				-- List affected commodities
				local etype = EventTypes[ev.type_key]
				if etype then
					msg = msg .. "\nAffected commodities:\n"
					for _, eff in ipairs(etype.effects) do
						local c = SafeGetCommodity(eff.cargo)
						if c then
							local direction = eff.price_mult > 1.0 and "UP" or "DOWN"
							local pct = math.floor(math.abs(eff.price_mult - 1.0) * ev.severity * 100)
							msg = msg .. string.format("  %s: prices %s ~%d%%\n", c:GetName(), direction, pct)
						end
					end
				end

				form:SetMessage(msg)
			end,
			onDelete = function(ref)
				bb_ads[ref] = nil
			end,
		})
		if ref then
			bb_ads[ref] = { station = station, event_id = eid }
		end
	end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

Event.Register("onEnterSystem", function(ship)
	if not ship:IsPlayer() then return end
	GenerateEvents()
end)

Event.Register("onGameStart", function()
	active_events = active_events or {}
	price_cache = {}
	bb_ads = {}
	GenerateEvents()
	Timer:CallEvery(10 * 60, function()
		if Game.system then GenerateEvents() end
	end)
end)

Event.Register("onCreateBB", function(station)
	AddEventAdverts(station)
end)

Event.Register("onPlayerDocked", function(player, station)
	ApplyEffectsAtStation(station)
end)

Event.Register("onPlayerUndocked", function(player, station)
	RestoreEffectsAtStation(station)
end)

Event.Register("onGameEnd", function()
	active_events = {}
	price_cache = {}
	bb_ads = {}
end)

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

Serializer:Register("DynamicSystemEvents",
	function()
		return {
			events = active_events,
			counter = event_id_counter,
		}
	end,
	function(data)
		if not data then return end
		active_events = data.events or {}
		event_id_counter = data.counter or 0
	end
)

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function DynamicSystemEvents.GetSystemEvents()
	if not Game.system then return {} end
	return active_events[PathKey(Game.system.path)] or {}
end

function DynamicSystemEvents.GetAllEvents()
	return active_events
end

function DynamicSystemEvents.GetEventDescription(ev)
	if not ev then return "Unknown event" end
	local remaining = math.max(0, (ev.end_time or 0) - (Game.time or 0))
	local hours = math.floor(remaining / 3600)
	return string.format("%s (Severity: %d%%, %dh remaining)",
		ev.name or "Unknown", math.floor((ev.severity or 0) * 100), hours)
end

function DynamicSystemEvents.GetEventTypes()
	return EventTypes
end

return DynamicSystemEvents
