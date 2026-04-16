-- SmugglingContracts.lua - Economy Enhancement Suite v2.0
-- Black market transport missions for illegal commodities
-- by kroryan - GPL-3.0

local Engine = require 'Engine'
local Game = require 'Game'
local Space = require 'Space'
local Comms = require 'Comms'
local Event = require 'Event'
local Mission = require 'Mission'
local Format = require 'Format'
local Serializer = require 'Serializer'
local Character = require 'Character'
local NameGen = require 'NameGen'
local Commodities = require 'Commodities'
local CommodityType = require 'CommodityType'
local utils = require 'utils'
local PlayerState = require 'PlayerState'

local MissionUtils = require 'modules.MissionUtils'

local SmugglingContracts = {}

-- Configuration
local MAX_DIST = 20
local BASE_PAY_PER_TONNE = 150
local LAWFUL_BONUS_MULT = 3.0    -- multiplier for delivering to lawful systems
local POLICE_SCAN_CHANCE = 0.25  -- 25% chance of police scan on dock
local MAX_CONTRACTS = 2

-- Smuggleable commodities (illegal in many systems)
local CONTRABAND = {
	{ id = "narcotics",     name = "Narcotics",     base_mult = 2.0 },
	{ id = "slaves",        name = "Slaves",        base_mult = 3.0 },
	{ id = "hand_weapons",  name = "Hand Weapons",  base_mult = 1.5 },
	{ id = "battle_weapons",name = "Battle Weapons", base_mult = 2.5 },
	{ id = "nerve_gas",     name = "Nerve Gas",     base_mult = 4.0 },
}

local ads = {}
local missions = {}

local function findDeliveryStation()
	local nearbySystems = Game.system:GetNearbySystems(MAX_DIST, function(s)
		return #s:GetStationPaths() > 0 and s.population > 0
	end)

	if #nearbySystems == 0 then return nil end

	local system = nearbySystems[Engine.rand:Integer(1, #nearbySystems)]
	local stations = system:GetStationPaths()
	if #stations == 0 then return nil end

	local station = stations[Engine.rand:Integer(1, #stations)]
	local dist = system:DistanceTo(Game.system)
	local isLawful = system.lawlessness < 0.3

	return {
		path = station,
		system = system,
		dist = dist,
		isLawful = isLawful,
		stationName = station:GetSystemBody().name,
		systemName = system.name,
	}
end

local function makeAdvert(station)
	-- Only in systems with some lawlessness
	if Game.system.lawlessness < 0.15 then return end

	local count = 0
	for _, ad in pairs(ads) do
		if ad.station == station then count = count + 1 end
	end
	if count >= MAX_CONTRACTS then return end

	-- Pick contraband type
	local contraband = CONTRABAND[Engine.rand:Integer(1, #CONTRABAND)]
	local commodity = CommodityType.GetCommodity(contraband.id)
	if not commodity then return end

	-- Check if illegal somewhere
	local delivery = findDeliveryStation()
	if not delivery then return end

	-- Amount: 5-30 tonnes
	local amount = Engine.rand:Integer(5, 30)

	-- Calculate reward
	local payPerTonne = BASE_PAY_PER_TONNE * contraband.base_mult
	if delivery.isLawful then
		payPerTonne = payPerTonne * LAWFUL_BONUS_MULT  -- much more for lawful destinations
	end
	payPerTonne = payPerTonne * (1 + delivery.dist * 0.05)
	local reward = utils.round(math.floor(amount * payPerTonne * Engine.rand:Number(0.8, 1.3)), 100)

	-- Due in 7-21 days
	local due = Game.time + Engine.rand:Number(7, 21) * 24 * 60 * 60

	local client = Character.New()

	local riskLevel = delivery.isLawful and "HIGH" or "LOW"

	local ad = {
		station       = station,
		client        = client,
		contraband    = contraband,
		commodity     = commodity,
		commodityId   = contraband.id,
		commodityName = contraband.name,
		amount        = amount,
		delivery      = delivery,
		reward        = reward,
		due           = due,
		riskLevel     = riskLevel,
	}

	local title = string.format("DISCRETE TRANSPORT: %dt %s", amount, contraband.name)
	local desc = string.format(
		"Confidential transport needed. %d tonnes of %s to %s, %s system (%.1f ly). " ..
		"Payment: %s. Risk level: %s. Discretion is paramount.",
		amount, contraband.name,
		delivery.stationName, delivery.systemName, delivery.dist,
		Format.Money(reward, false), riskLevel
	)

	local ref = station:AddAdvert({
		title       = title,
		description = desc,
		icon        = "cargo_crate_illegal",
		due         = due,
		reward      = reward,
		location    = delivery.path,
		onChat      = function(form, ref, option)
			local a = ads[ref]
			if not a then return end

			form:Clear()
			form:SetFace(a.client)
			form:AddNavButton(a.delivery.path)

			if option == -1 then
				form:Close()
				return
			end

			if option == 0 then
				form:SetMessage(string.format(
					"I need %d tonnes of %s moved to %s in the %s system. " ..
					"You'll need to acquire the goods yourself - check the local market or other traders. " ..
					"Deliver before %s and you'll receive %s. " ..
					"No questions asked, no records kept.",
					a.amount, a.commodityName,
					a.delivery.stationName, a.delivery.systemName,
					Format.Date(a.due), Format.Money(a.reward, false)
				))
				form:AddOption("What's the risk?", 1)
				form:AddOption("I'll do it", 3)

			elseif option == 1 then
				local msg
				if a.delivery.isLawful then
					msg = string.format(
						"The destination is a lawful system. %s authorities run regular cargo scans. " ..
						"If caught, you'll face fines and criminal charges. " ..
						"That's why the pay is %s - it's not a milk run.",
						a.delivery.systemName, Format.Money(a.reward, false)
					)
				else
					msg = string.format(
						"The destination isn't exactly law-abiding. Minimal risk of police interference. " ..
						"Still, don't draw attention to yourself. Easy money, relatively speaking."
					)
				end
				form:SetMessage(msg)
				form:AddOption("Tell me more", 0)
				form:AddOption("I'll do it", 3)

			elseif option == 3 then
				form:RemoveAdvertOnClose()
				ads[ref] = nil

				local mission = {
					type          = "Smuggling",
					client        = a.client,
					commodityId   = a.commodityId,
					commodityName = a.commodityName,
					amount        = a.amount,
					delivery      = a.delivery,
					destination   = a.delivery.path,
					reward        = a.reward,
					due           = a.due,
					status        = "ACTIVE",
					delivered     = 0,
				}
				mission = Mission.New(mission)
				table.insert(missions, mission)

				form:SetMessage(string.format(
					"Good. Get %d tonnes of %s to %s before %s. Don't get caught.",
					a.amount, a.commodityName, a.delivery.stationName, Format.Date(a.due)
				))
			end
		end,
		onDelete    = function(ref) ads[ref] = nil end,
	})

	if ref then
		ads[ref] = ad
	end
end

-- Register mission type
Mission.RegisterType("Smuggling", "Smuggling Contract", function(mission)
	return {
		description = string.format("Transport %d tonnes of %s to %s.",
			mission.amount, mission.commodityName, mission.delivery.stationName),
		details = {
			{ "Cargo", string.format("%dt %s", mission.amount, mission.commodityName) },
			{ "Destination", mission.delivery.stationName .. ", " .. mission.delivery.systemName },
			{ "Distance", string.format("%.1f ly", mission.delivery.dist) },
			{ "Risk", mission.delivery.isLawful and "HIGH (lawful system)" or "LOW" },
			{ "Reward", Format.Money(mission.reward, false) },
			{ "Deadline", Format.Date(mission.due) },
		},
		location = mission.destination,
		client = mission.client,
	}
end)

-- Events
Event.Register("onCreateBB", function(station)
	local num = Engine.rand:Integer(0, math.ceil(Game.system.lawlessness * 3))
	for i = 1, num do
		makeAdvert(station)
	end
end)

Event.Register("onUpdateBB", function(station)
	for ref, ad in pairs(ads) do
		if ad.due < Game.time then
			pcall(function() ad.station:RemoveAdvert(ref) end)
			ads[ref] = nil
		end
	end
	if Game.system.lawlessness > 0.2 and Engine.rand:Integer(1, 6) == 1 then
		makeAdvert(station)
	end
end)

Event.Register("onPlayerDocked", function(player, station)
	for ref, mission in pairs(missions) do
		if mission.due < Game.time then
			-- Expired
			Comms.ImportantMessage("Smuggling contract expired. " .. mission.commodityName .. " delivery failed.", mission.client.name)
			Character.persistent.player.reputation = (Character.persistent.player.reputation or 0) - 1.0
			mission:Remove()
			missions[ref] = nil

		elseif mission.destination and station.path == mission.destination then
			-- Check cargo
			local cargoMgr = player:GetComponent('CargoManager')
			if not cargoMgr then return end

			local commodity = CommodityType.GetCommodity(mission.commodityId)
			if not commodity then return end

			local carried = cargoMgr:CountCommodity(commodity)

			if carried >= mission.amount then
				-- Remove cargo
				cargoMgr:RemoveCommodity(commodity, mission.amount)

				-- Police scan chance
				local scanned = false
				local system = Game.system
				if system and system.lawlessness < 0.3 then
					if Engine.rand:Number(1.0) < POLICE_SCAN_CHANCE then
						scanned = true
					end
				end

				if scanned then
					-- Caught! Fine but still get partial payment
					local fine = math.floor(mission.reward * 0.4)
					local net = mission.reward - fine
					PlayerState.AddMoney(net)
					PlayerState.AddCrime("TRADING_ILLEGAL_GOODS", fine)
					Comms.ImportantMessage(
						string.format("Delivery complete but police detected the cargo! Fine: %s. Net payment: %s.",
							Format.Money(fine, false), Format.Money(net, false)),
						"Black Market"
					)
				else
					-- Clean delivery
					PlayerState.AddMoney(mission.reward)
					Comms.ImportantMessage(
						string.format("Clean delivery. %s transferred. Pleasure doing business.",
							Format.Money(mission.reward, false)),
						mission.client.name
					)
				end

				Character.persistent.player.reputation = (Character.persistent.player.reputation or 0) + 0.5
				mission:Remove()
				missions[ref] = nil
			else
				Comms.Message(
					string.format("You need %d tonnes of %s. You have %d. Get the rest and come back.",
						mission.amount, mission.commodityName, carried),
					mission.client.name
				)
			end
		end
	end
end)

Event.Register("onGameEnd", function()
	ads = {}
	missions = {}
end)

-- Serialization
Serializer:Register("SmugglingContracts",
	function()
		local save_missions = {}
		for k, v in pairs(missions) do
			save_missions[k] = v
		end
		return { missions = save_missions }
	end,
	function(data)
		if data and data.missions then
			missions = data.missions
		end
		ads = {}
	end
)

-- Public API
SmugglingContracts.GetActiveContracts = function()
	local active = {}
	for _, m in pairs(missions) do
		table.insert(active, {
			commodity = m.commodityName,
			amount = m.amount,
			destination = m.delivery and m.delivery.systemName or "Unknown",
			reward = m.reward,
			due = m.due,
		})
	end
	return active
end

print("[SmugglingContracts] Module loaded - Black market transport active")

return SmugglingContracts
