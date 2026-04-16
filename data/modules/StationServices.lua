-- StationServices.lua - Economy Enhancement Suite v2.0
-- Special station services: ship upgrades, tuning, and maintenance
-- by kroryan - GPL-3.0

local Engine = require 'Engine'
local Game = require 'Game'
local Event = require 'Event'
local Comms = require 'Comms'
local Format = require 'Format'
local Serializer = require 'Serializer'
local Character = require 'Character'
local PlayerState = require 'PlayerState'
local utils = require 'utils'

local StationServices = {}

-- Service types
local SERVICES = {
	{
		id = "HULL_REINFORCEMENT",
		title = "Hull Reinforcement Treatment",
		desc = "Advanced nano-composite hull treatment. Strengthens existing armor plating without adding mass. Lasts for your next 20 dockings.",
		cost_mult = 0.08,   -- 8% of ship value
		min_tech = 5,
		skill = "engineering",
		difficulty = 5,
		success_msg = "Hull reinforcement applied successfully. Your armor integrity is now enhanced.",
		fail_msg = "The treatment didn't bond properly with your hull material. No charge - we can't deliver substandard work.",
		effect = "hull_reinforcement",
		duration = 20,  -- dockings
	},
	{
		id = "ENGINE_TUNING",
		title = "Drive System Optimization",
		desc = "Fine-tune your main drive for improved fuel efficiency. Professional calibration reduces fuel consumption by up to 5%. Lasts 30 hyperspace jumps.",
		cost_mult = 0.05,
		min_tech = 4,
		skill = "engineering",
		difficulty = 0,
		success_msg = "Drive optimization complete. You should notice improved fuel efficiency on your next few jumps.",
		fail_msg = "Your drive configuration is already near-optimal. We can't improve on it further. No charge.",
		effect = "engine_tuning",
		duration = 30,
	},
	{
		id = "SENSOR_CALIBRATION",
		title = "Sensor Array Calibration",
		desc = "Professional recalibration of all onboard sensors. Improves detection range and accuracy. Essential for exploration and combat.",
		cost_mult = 0.03,
		min_tech = 3,
		skill = "sensors",
		difficulty = 0,
		success_msg = "All sensors recalibrated. You should notice improved readings across the board.",
		fail_msg = "Your sensors are already well calibrated. No adjustment needed. No charge.",
		effect = "sensor_calibration",
		duration = 25,
	},
	{
		id = "CARGO_OPTIMIZATION",
		title = "Cargo Bay Optimization",
		desc = "Reorganize and optimize cargo bay layout. Improves loading speed and reduces damage to goods in transit.",
		cost_mult = 0.04,
		min_tech = 2,
		skill = "engineering",
		difficulty = -5,
		success_msg = "Cargo bay reorganized. Loading and unloading will be more efficient, and your goods are better protected.",
		fail_msg = "Your cargo bay is already optimally configured. Good maintenance, Captain!",
		effect = "cargo_optimization",
		duration = 40,
	},
	{
		id = "WEAPON_REFIT",
		title = "Weapons System Overhaul",
		desc = "Complete overhaul and recalibration of all mounted weapons. Improves targeting accuracy and power cycling. For the discerning combat pilot.",
		cost_mult = 0.10,
		min_tech = 6,
		skill = "engineering",
		difficulty = 10,
		success_msg = "Weapons overhauled and recalibrated. Your targeting systems are now razor-sharp.",
		fail_msg = "We ran into some compatibility issues with your weapon mounts. We'll need different parts. No charge for the inspection.",
		effect = "weapon_refit",
		duration = 15,
	},
	{
		id = "FULL_SERVICE",
		title = "Complete Ship Service",
		desc = "Comprehensive top-to-bottom ship service. Hull inspection, drive calibration, sensor check, and systems diagnostic. The works.",
		cost_mult = 0.15,
		min_tech = 7,
		skill = "engineering",
		difficulty = 5,
		success_msg = "Full service complete. Your ship is in peak condition. Every system has been inspected and optimized.",
		fail_msg = "Your ship is in remarkably good condition already. We found nothing that needs attention. No charge.",
		effect = "full_service",
		duration = 50,
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
end)

Event.Register("onGameEnd", function()
	state = { active_effects = {}, services_used = 0 }
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

print("[StationServices] Module loaded - Station services active")

return StationServices
