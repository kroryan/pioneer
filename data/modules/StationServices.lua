-- StationServices.lua - Economy Enhancement Suite v2.0
-- Special station services: ship upgrades, tuning, and maintenance
-- Provides REAL effects: price discounts on repairs, crew skill bonuses,
-- and enhanced service notifications. Complements base game BreakdownServicing.
-- by kroryan - GPL-3.0

local Engine = require 'Engine'
local Game = require 'Game'
local Event = require 'Event'
local Comms = require 'Comms'
local Format = require 'Format'
local Serializer = require 'Serializer'
local Character = require 'Character'
local PlayerState = require 'PlayerState'
local Commodities = require 'Commodities'
local utils = require 'utils'

local StationServices = {}

-- Service types with REAL mechanical effects:
-- Hull Reinforcement: Reduces hull repair cost at next station (via repair discount)
-- Engine Tuning: Gives hydrogen fuel discount (cheaper refueling)
-- Sensor Calibration: Improves exploration data value (ExplorationRewards integration)
-- Cargo Optimization: Gives commodity price bonus when selling (better trade prices)
-- Weapon Refit: Increases bounty mission rewards (BountyBoard integration)
-- Full Service: All of the above at reduced potency
local SERVICES = {
	{
		id = "HULL_REINFORCEMENT",
		title = "Hull Reinforcement Treatment",
		desc = "Advanced nano-composite hull treatment. Reduces repair costs at your next 20 stations by 30%.",
		cost_mult = 0.08,
		min_tech = 5,
		skill = "engineering",
		difficulty = 5,
		success_msg = "Hull reinforcement applied successfully. Repair costs will be reduced at your next stops.",
		fail_msg = "The treatment didn't bond properly with your hull material. No charge.",
		effect = "hull_reinforcement",
		duration = 20,
		-- Real effect: 30% discount on hull repair cost
		real_effect = { type = "repair_discount", value = 0.30 },
	},
	{
		id = "ENGINE_TUNING",
		title = "Drive System Optimization",
		desc = "Fine-tune your main drive for improved efficiency. Hydrogen fuel costs 25% less for your next 30 refueling stops.",
		cost_mult = 0.05,
		min_tech = 4,
		skill = "engineering",
		difficulty = 0,
		success_msg = "Drive optimization complete. Fuel purchases will be cheaper for a while.",
		fail_msg = "Your drive configuration is already near-optimal. No charge.",
		effect = "engine_tuning",
		duration = 30,
		-- Real effect: 25% discount on hydrogen purchase price
		real_effect = { type = "fuel_discount", value = 0.25 },
	},
	{
		id = "SENSOR_CALIBRATION",
		title = "Sensor Array Calibration",
		desc = "Professional recalibration of all onboard sensors. Exploration data sells for 20% more for 25 dockings.",
		cost_mult = 0.03,
		min_tech = 3,
		skill = "sensors",
		difficulty = 0,
		success_msg = "All sensors recalibrated. Your exploration data will be worth more.",
		fail_msg = "Your sensors are already well calibrated. No charge.",
		effect = "sensor_calibration",
		duration = 25,
		-- Real effect: 20% bonus to exploration data sale value
		real_effect = { type = "exploration_bonus", value = 0.20 },
	},
	{
		id = "CARGO_OPTIMIZATION",
		title = "Cargo Bay Optimization",
		desc = "Reorganize cargo bay layout. Get 15% better selling prices on traded goods for 40 dockings.",
		cost_mult = 0.04,
		min_tech = 2,
		skill = "engineering",
		difficulty = -5,
		success_msg = "Cargo bay reorganized. You'll get better prices when selling goods.",
		fail_msg = "Your cargo bay is already optimally configured. No charge.",
		effect = "cargo_optimization",
		duration = 40,
		-- Real effect: 15% bonus when selling commodities
		real_effect = { type = "trade_bonus", value = 0.15 },
	},
	{
		id = "WEAPON_REFIT",
		title = "Weapons System Overhaul",
		desc = "Complete overhaul of all weapons. Bounty rewards increased by 20% for 15 dockings.",
		cost_mult = 0.10,
		min_tech = 6,
		skill = "engineering",
		difficulty = 10,
		success_msg = "Weapons overhauled and recalibrated. Your combat effectiveness is recognized with higher bounty payouts.",
		fail_msg = "We ran into compatibility issues. No charge for the inspection.",
		effect = "weapon_refit",
		duration = 15,
		-- Real effect: 20% bonus to bounty mission rewards
		real_effect = { type = "bounty_bonus", value = 0.20 },
	},
	{
		id = "FULL_SERVICE",
		title = "Complete Ship Service",
		desc = "Comprehensive ship service. All bonuses (fuel, repair, trade, exploration, bounty) at 10% for 50 dockings.",
		cost_mult = 0.15,
		min_tech = 7,
		skill = "engineering",
		difficulty = 5,
		success_msg = "Full service complete. Your ship is in peak condition with all systems enhanced.",
		fail_msg = "Your ship is in remarkably good condition already. No charge.",
		effect = "full_service",
		duration = 50,
		-- Real effect: 10% to everything
		real_effect = { type = "all_bonus", value = 0.10 },
	},
}

-- State
local state = {
	active_effects = {},  -- {effect_id = {remaining = N, timestamp = time}}
	services_used = 0,
}

local ads = {}

local function getShipValue()
	local player = Game.player
	if not player then return 10000 end
	-- Approximate ship value from hull config
	local ok, def = pcall(function()
		local ShipDef = require 'ShipDef'
		return ShipDef[player.shipId]
	end)
	if ok and def and def.basePrice then
		return def.basePrice
	end
	return 50000  -- fallback
end

local function makeAdvert(station, service)
	-- Check tech level
	if station.techLevel and station.techLevel < service.min_tech then return end

	local shipValue = getShipValue()
	local cost = utils.round(math.floor(shipValue * service.cost_mult * Engine.rand:Number(0.8, 1.2)), 50)
	cost = math.max(cost, 500)

	local client = Character.New({ title = "Technician" })

	local ad = {
		station = station,
		service = service,
		client = client,
		cost = cost,
	}

	local desc = service.desc .. string.format(" Cost: %s.", Format.Money(cost, false))
	if state.active_effects[service.effect] then
		desc = desc .. " [ACTIVE - " .. state.active_effects[service.effect].remaining .. " remaining]"
	end

	local ref = station:AddAdvert({
		title       = service.title,
		description = desc,
		icon        = "repairs",
		onChat      = function(form, ref, option)
			local a = ads[ref]
			if not a then return end

			form:Clear()
			form:SetFace(a.client)

			if option == -1 then
				form:Close()
				return
			end

			if option == 0 then
				-- Check if already active
				if state.active_effects[a.service.effect] then
					local remaining = state.active_effects[a.service.effect].remaining
					form:SetMessage(string.format(
						"You already have %s active with %d uses remaining. Come back when it expires.",
						a.service.title, remaining
					))
					return
				end

				form:SetMessage(string.format(
					"Welcome to the service bay. I'm %s.\n\n%s\n\nCost: %s\nTech level required: %d\n\nShall I proceed?",
					a.client.name, a.service.desc, Format.Money(a.cost, false), a.service.min_tech
				))
				form:AddOption("Yes, do the work", 1)
				form:AddOption("What exactly will you do?", 2)

			elseif option == 1 then
				-- Check money
				local money = PlayerState.GetMoney()
				if money < a.cost then
					form:SetMessage(string.format(
						"You need %s for this service. You only have %s. Come back when you can afford it.",
						Format.Money(a.cost, false), Format.Money(money, false)
					))
					return
				end

				-- Check if already active
				if state.active_effects[a.service.effect] then
					form:SetMessage("This service is already active on your ship. No need for another application.")
					return
				end

				-- Skill check via crew
				local success = true
				local hasEngineer = false
				pcall(function()
					Game.player:EachCrewMember(function(member)
						if member and not member.player then
							local roll = member:TestRoll(a.service.skill, a.service.difficulty)
							if roll then
								hasEngineer = true
							end
						end
					end)
				end)

				-- Base success chance + crew bonus
				local baseChance = 0.7
				if hasEngineer then baseChance = 0.92 end
				success = Engine.rand:Number(1.0) < baseChance

				PlayerState.AddMoney(-a.cost)
				state.services_used = state.services_used + 1

				if success then
					state.active_effects[a.service.effect] = {
						remaining = a.service.duration,
						timestamp = Game.time,
					}
					form:SetMessage(a.service.success_msg ..
						string.format("\n\nService active for %d docking%s. Payment: %s.",
							a.service.duration, a.service.duration ~= 1 and "s" or "",
							Format.Money(a.cost, false)))
				else
					-- Refund on failure
					PlayerState.AddMoney(a.cost)
					form:SetMessage(a.service.fail_msg)
				end

			elseif option == 2 then
				local details = {
					hull_reinforcement = "We apply a nano-composite treatment to your hull plating. It bonds at the molecular level, reinforcing structural integrity without adding mass. The treatment gradually wears off with each dock/undock cycle.",
					engine_tuning = "We optimize your fuel injection timing, magnetic field geometry, and thrust vectoring parameters. It's like a tune-up for your hyperdrive. The calibration slowly drifts back to default over time.",
					sensor_calibration = "We recalibrate your passive and active sensors using our station's reference arrays. The improved calibration decays naturally with thermal cycling and vibration.",
					cargo_optimization = "We redesign the internal layout of your cargo bay for better volumetric efficiency and shock absorption. It stays optimized until enough loading/unloading cycles randomize the layout again.",
					weapon_refit = "We strip, inspect, and reassemble all weapon systems. New targeting data is loaded and power cycling is optimized. Combat use gradually degrades the calibration.",
					full_service = "The complete package: hull, drives, sensors, cargo bay, weapons, life support - everything gets a professional going-over. The gold standard of ship maintenance.",
				}
				form:SetMessage(details[a.service.effect] or "Professional ship service.")
				form:AddOption("Sounds good, let's do it", 1)
				form:AddOption("Back", 0)
			end
		end,
		onDelete    = function(ref) ads[ref] = nil end,
	})

	if ref then
		ads[ref] = ad
	end
end

-- ============================================================================
-- REAL EFFECTS: Apply price modifications based on active services
-- These complement the base game's BreakdownServicing/ShipRepairs
-- ============================================================================

local service_price_cache = {}

-- Get the bonus value for a specific effect type
local function GetEffectBonus(effect_type)
	local bonus = 0
	for effect_id, data in pairs(state.active_effects) do
		if data.remaining > 0 then
			-- Find the service definition for this effect
			for _, svc in ipairs(SERVICES) do
				if svc.effect == effect_id and svc.real_effect then
					local re = svc.real_effect
					if re.type == effect_type or re.type == "all_bonus" then
						bonus = bonus + re.value
					end
				end
			end
		end
	end
	return bonus
end

local function ApplyServiceEffectsAtStation(station)
	local sta_key = tostring(station.path)
	service_price_cache[sta_key] = {}

	-- Engine tuning: reduce hydrogen price
	local fuel_discount = GetEffectBonus("fuel_discount")
	if fuel_discount > 0 then
		local hydrogen = Commodities["hydrogen"]
		if hydrogen then
			local ok, price = pcall(function() return station:GetCommodityPrice(hydrogen) end)
			if ok and price then
				service_price_cache[sta_key]["hydrogen"] = price
				local newPrice = math.max(1, math.floor(price * (1.0 - fuel_discount)))
				pcall(function() station:SetCommodityPrice(hydrogen, newPrice) end)
				Comms.Message(string.format("Drive optimization active: hydrogen fuel %d%% cheaper here.", math.floor(fuel_discount * 100)), "Ship Systems")
			end
		end
		local milfuel = Commodities["military_fuel"]
		if milfuel then
			local ok, price = pcall(function() return station:GetCommodityPrice(milfuel) end)
			if ok and price then
				service_price_cache[sta_key]["military_fuel"] = price
				local newPrice = math.max(1, math.floor(price * (1.0 - fuel_discount)))
				pcall(function() station:SetCommodityPrice(milfuel, newPrice) end)
			end
		end
	end

	-- Cargo optimization: boost sell prices on common trade goods
	local trade_bonus = GetEffectBonus("trade_bonus")
	if trade_bonus > 0 then
		local trade_goods = {
			"metal_alloys", "industrial_machinery", "consumer_goods", "computers",
			"robots", "plastics", "textiles", "liquor", "precious_metals",
		}
		for _, name in ipairs(trade_goods) do
			local commodity = Commodities[name]
			if commodity then
				local ok, price = pcall(function() return station:GetCommodityPrice(commodity) end)
				if ok and price and not service_price_cache[sta_key][name] then
					service_price_cache[sta_key][name] = price
					local newPrice = math.floor(price * (1.0 + trade_bonus))
					pcall(function() station:SetCommodityPrice(commodity, newPrice) end)
				end
			end
		end
		Comms.Message(string.format("Cargo optimization active: trade goods sell for %d%% more.", math.floor(trade_bonus * 100)), "Ship Systems")
	end

	-- Sensor calibration + weapon refit + hull reinforcement:
	-- These are exposed via the public API for other modules to query
	local sensor_bonus = GetEffectBonus("exploration_bonus")
	if sensor_bonus > 0 then
		Comms.Message(string.format("Sensor calibration active: exploration data worth %d%% more.", math.floor(sensor_bonus * 100)), "Ship Systems")
	end
	local bounty_bonus = GetEffectBonus("bounty_bonus")
	if bounty_bonus > 0 then
		Comms.Message(string.format("Weapons overhaul active: bounty rewards increased %d%%.", math.floor(bounty_bonus * 100)), "Ship Systems")
	end
	local repair_discount = GetEffectBonus("repair_discount")
	if repair_discount > 0 then
		Comms.Message(string.format("Hull reinforcement active: repair costs reduced %d%%.", math.floor(repair_discount * 100)), "Ship Systems")
	end
end

local function RestoreServiceEffectsAtStation(station)
	local sta_key = tostring(station.path)
	local cached = service_price_cache[sta_key]
	if not cached then return end

	for commodity_name, orig_price in pairs(cached) do
		local commodity = Commodities[commodity_name]
		if commodity then
			pcall(function() station:SetCommodityPrice(commodity, orig_price) end)
		end
	end
	service_price_cache[sta_key] = nil
end

-- Events
Event.Register("onCreateBB", function(station)
	-- Offer 2-4 services based on tech level
	local available = {}
	for _, service in ipairs(SERVICES) do
		if not station.techLevel or station.techLevel >= service.min_tech then
			table.insert(available, service)
		end
	end

	-- Shuffle and pick subset
	local count = math.min(#available, Engine.rand:Integer(2, 4))
	for i = 1, count do
		local idx = Engine.rand:Integer(i, #available)
		available[i], available[idx] = available[idx], available[i]
		makeAdvert(station, available[i])
	end
end)

Event.Register("onPlayerDocked", function(player, station)
	-- Decrement duration counters for active effects
	for effect, data in pairs(state.active_effects) do
		data.remaining = data.remaining - 1
		if data.remaining <= 0 then
			state.active_effects[effect] = nil
			Comms.Message(
				"Ship service expired: " .. effect:gsub("_", " ") .. ". Visit a station to renew.",
				"Ship Systems"
			)
		end
	end

	-- Apply REAL price effects from active services
	ApplyServiceEffectsAtStation(station)
end)

Event.Register("onPlayerUndocked", function(player, station)
	-- Restore original prices modified by services
	RestoreServiceEffectsAtStation(station)
end)

Event.Register("onGameEnd", function()
	state = { active_effects = {}, services_used = 0 }
	service_price_cache = {}
	ads = {}
end)

-- Serialization
Serializer:Register("StationServices",
	function()
		return state
	end,
	function(data)
		if data then
			state = data
			if not state.active_effects then state.active_effects = {} end
			if not state.services_used then state.services_used = 0 end
		end
		ads = {}
	end
)

-- Public API
StationServices.GetActiveEffects = function() return state.active_effects end
StationServices.GetServicesUsed = function() return state.services_used end
StationServices.GetAvailableServices = function() return SERVICES end

-- Real effect bonus queries (used by other modules)
StationServices.GetExplorationBonus = function() return GetEffectBonus("exploration_bonus") end
StationServices.GetBountyBonus = function() return GetEffectBonus("bounty_bonus") end
StationServices.GetRepairDiscount = function() return GetEffectBonus("repair_discount") end
StationServices.GetFuelDiscount = function() return GetEffectBonus("fuel_discount") end
StationServices.GetTradeBonus = function() return GetEffectBonus("trade_bonus") end

print("[StationServices] Module loaded - Station services active")

return StationServices
