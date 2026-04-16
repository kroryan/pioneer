-- ExplorationRewards.lua - Economy Enhancement Suite v2.0
-- Rewards players for exploring new systems and selling exploration data
-- by kroryan - GPL-3.0

local Engine = require 'Engine'
local Game = require 'Game'
local Event = require 'Event'
local Timer = require 'Timer'
local Comms = require 'Comms'
local Format = require 'Format'
local Serializer = require 'Serializer'
local Character = require 'Character'
local PlayerState = require 'PlayerState'

local ExplorationRewards = {}

-- Configuration
local FIRST_VISIT_BONUS = 250        -- credits for first system visit
local DATA_PRICE_PER_BODY = 50       -- credits per body in system
local DATA_PRICE_TECH_MULT = 1.5     -- multiplier for high-tech stations
local MILESTONE_REWARDS = {
	{ count = 10,  reward = 5000,   title = "Pathfinder" },
	{ count = 25,  reward = 15000,  title = "Scout" },
	{ count = 50,  reward = 40000,  title = "Explorer" },
	{ count = 100, reward = 100000, title = "Trailblazer" },
	{ count = 250, reward = 300000, title = "Vanguard" },
	{ count = 500, reward = 750000, title = "Pioneer" },
}

-- Persistent state
local state = {
	visited_systems = {},      -- {system_path_string = timestamp}
	total_explored = 0,
	data_sold_count = 0,
	milestones_claimed = {},   -- {milestone_count = true}
	unsold_data = {},          -- {system_path_string = {bodies=N, name=string, timestamp=time}}
}

local ads = {}

-- Helpers
local function systemKey(path)
	if not path then return nil end
	return string.format("%d,%d,%d", path.sectorX, path.sectorY, path.sectorZ) .. ":" .. tostring(path.systemIndex)
end

local function countBodies(system)
	local count = 0
	local ok, paths = pcall(function() return system:GetBodyPaths() end)
	if ok and paths then
		count = #paths
	end
	return math.max(count, 1)
end

local function getDataValue(system, station)
	local bodies = countBodies(system)
	local base = bodies * DATA_PRICE_PER_BODY
	-- high-tech stations pay more for data
	if station and station.techLevel then
		local techMult = 1.0 + (station.techLevel / 20) * (DATA_PRICE_TECH_MULT - 1.0)
		base = math.floor(base * techMult)
	end
	-- distant systems worth more
	local dist = 0
	local ok, d = pcall(function() return system:DistanceTo(Game.system) end)
	if ok and d then dist = d end
	base = base + math.floor(dist * 10)
	return math.max(base, 100)
end

local function checkMilestones()
	for _, m in ipairs(MILESTONE_REWARDS) do
		if state.total_explored >= m.count and not state.milestones_claimed[m.count] then
			state.milestones_claimed[m.count] = true
			PlayerState.AddMoney(m.reward)
			Comms.ImportantMessage(
				string.format("EXPLORATION MILESTONE: %s! %d systems explored. Reward: %s",
					m.title, m.count, Format.Money(m.reward, false)),
				"Explorers' Guild"
			)
		end
	end
end

-- BB advert for selling exploration data
local function onChat(form, ref, option)
	local ad = ads[ref]
	if not ad then return end

	local station = Game.player:GetDockedWith()
	if not station then return end

	form:Clear()
	form:SetFace(ad.client)

	if option == -1 then
		form:Close()
		return
	end

	-- Count unsold data
	local dataCount = 0
	local totalValue = 0
	for sysKey, data in pairs(state.unsold_data) do
		dataCount = dataCount + 1
		totalValue = totalValue + getDataValue(nil, station) -- approximate
	end

	if option == 0 then
		if dataCount == 0 then
			form:SetMessage("You don't have any unsold exploration data. Visit new systems to collect scan data automatically.")
		else
			local msg = string.format(
				"Welcome to the Explorers' Guild data office.\n\n" ..
				"You have scan data from %d system%s.\n" ..
				"Systems explored to date: %d\n\n" ..
				"Would you like to sell your exploration data?",
				dataCount, dataCount ~= 1 and "s" or "", state.total_explored
			)
			form:SetMessage(msg)
			form:AddOption("Sell all exploration data", 1)
			form:AddOption("Show exploration statistics", 2)
		end

	elseif option == 1 then
		-- Sell all data
		local sold = 0
		local earned = 0
		for sysKey, data in pairs(state.unsold_data) do
			local value = data.bodies * DATA_PRICE_PER_BODY
			if station.techLevel then
				value = math.floor(value * (1.0 + station.techLevel / 20 * 0.5))
			end
			value = math.max(value, 100)
			earned = earned + value
			sold = sold + 1
		end

		if sold > 0 then
			PlayerState.AddMoney(earned)
			state.data_sold_count = state.data_sold_count + sold
			state.unsold_data = {}

			form:SetMessage(string.format(
				"Excellent! Data from %d system%s sold for %s.\n\n" ..
				"Total systems catalogued: %d\nKeep exploring, Commander!",
				sold, sold ~= 1 and "s" or "", Format.Money(earned, false), state.data_sold_count
			))
		else
			form:SetMessage("No data to sell.")
		end

	elseif option == 2 then
		-- Statistics
		local nextMilestone = nil
		for _, m in ipairs(MILESTONE_REWARDS) do
			if state.total_explored < m.count then
				nextMilestone = m
				break
			end
		end

		local msg = string.format(
			"EXPLORATION STATISTICS\n\n" ..
			"Systems explored: %d\n" ..
			"Data sets sold: %d\n" ..
			"Unsold data: %d system%s\n",
			state.total_explored, state.data_sold_count,
			dataCount, dataCount ~= 1 and "s" or ""
		)
		if nextMilestone then
			msg = msg .. string.format(
				"\nNext milestone: %s (%d/%d systems)\nReward: %s",
				nextMilestone.title, state.total_explored, nextMilestone.count,
				Format.Money(nextMilestone.reward, false)
			)
		else
			msg = msg .. "\nAll milestones achieved! You are a true Pioneer."
		end
		form:SetMessage(msg)
		form:AddOption("Back", 0)
	end
end

local function onDelete(ref)
	ads[ref] = nil
end

local function placeAdvert(station)
	-- One exploration data buyer per station
	for _, ad in pairs(ads) do
		if ad.station == station then return end
	end

	local client = Character.New({ title = "Data Analyst" })
	local ad = {
		station = station,
		client = client,
	}

	local dataCount = 0
	for _ in pairs(state.unsold_data) do dataCount = dataCount + 1 end

	local desc = "The Explorers' Guild purchases navigation and survey data from independent pilots."
	if dataCount > 0 then
		desc = desc .. string.format(" You have %d unsold data set%s.", dataCount, dataCount ~= 1 and "s" or "")
	end

	local ref = station:AddAdvert({
		title       = "EXPLORERS' GUILD - Scan Data Purchase",
		description = desc,
		icon        = "scout",
		onChat      = onChat,
		onDelete    = onDelete,
	})
	if ref then
		ads[ref] = ad
	end
end

-- Events
Event.Register("onEnterSystem", function(ship)
	if not ship or not ship:isa("Ship") or not ship.IsPlayer or not ship:IsPlayer() then return end

	local system = Game.system
	if not system then return end

	local key = systemKey(system.path)
	if not key then return end

	if not state.visited_systems[key] then
		state.visited_systems[key] = Game.time
		state.total_explored = state.total_explored + 1

		-- Award first-visit bonus
		PlayerState.AddMoney(FIRST_VISIT_BONUS)

		local bodies = countBodies(system)
		state.unsold_data[key] = {
			bodies = bodies,
			name = system.name,
			timestamp = Game.time,
		}

		Comms.Message(
			string.format("New system catalogued: %s (%d bodies). Scan data recorded. First-visit bonus: %s",
				system.name, bodies, Format.Money(FIRST_VISIT_BONUS, false)),
			"Nav Computer"
		)

		checkMilestones()
	end
end)

Event.Register("onCreateBB", function(station)
	placeAdvert(station)
end)

Event.Register("onUpdateBB", function(station)
	placeAdvert(station)
end)

Event.Register("onGameStart", function()
	-- state is loaded from serializer or fresh
end)

Event.Register("onGameEnd", function()
	state = {
		visited_systems = {},
		total_explored = 0,
		data_sold_count = 0,
		milestones_claimed = {},
		unsold_data = {},
	}
	ads = {}
end)

-- Serialization
Serializer:Register("ExplorationRewards",
	function()
		return state
	end,
	function(data)
		if data then
			state = data
			if not state.visited_systems then state.visited_systems = {} end
			if not state.milestones_claimed then state.milestones_claimed = {} end
			if not state.unsold_data then state.unsold_data = {} end
			if not state.data_sold_count then state.data_sold_count = 0 end
			if not state.total_explored then state.total_explored = 0 end
		end
	end
)

-- Public API
ExplorationRewards.GetExploredCount = function() return state.total_explored end
ExplorationRewards.GetUnsoldDataCount = function()
	local c = 0
	for _ in pairs(state.unsold_data) do c = c + 1 end
	return c
end
ExplorationRewards.GetVisitedSystems = function() return state.visited_systems end
ExplorationRewards.GetMilestones = function() return MILESTONE_REWARDS end
ExplorationRewards.GetClaimedMilestones = function() return state.milestones_claimed end

print("[ExplorationRewards] Module loaded - Explorers' Guild active")

return ExplorationRewards
