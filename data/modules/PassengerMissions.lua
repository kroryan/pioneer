-- PassengerMissions.lua - Economy Enhancement Suite v2.0
-- VIP and group passenger transport with time bonuses and special requests
-- by kroryan - GPL-3.0

local Engine = require 'Engine'
local Game = require 'Game'
local Comms = require 'Comms'
local Event = require 'Event'
local Mission = require 'Mission'
local Format = require 'Format'
local Serializer = require 'Serializer'
local Character = require 'Character'
local Passengers = require 'Passengers'
local utils = require 'utils'
local PlayerState = require 'PlayerState'

local MissionUtils = require 'modules.MissionUtils'

local PassengerMissions = {}

-- Configuration
local MAX_DIST = 25
local BASE_PAY_PER_PASSENGER = 200
local VIP_MULTIPLIER = 3.0
local EARLY_BONUS_RATE = 0.15     -- 15% bonus per day early
local MAX_PASSENGERS = 6

-- Mission flavours
local FLAVOURS = {
	{
		id = "BUSINESS",
		title = "BUSINESS TRANSPORT: {count} passenger{s} to {system}",
		desc = "Corporate executive{s} require{r} transport to {station}, {system} system. Professional service expected. Payment: {cash}.",
		intro = "I'm {client}. I need reliable transport to {station} for a business meeting. Time is money - {cash} for on-time delivery, with a bonus for early arrival.",
		success = "Right on time. Here's your payment: {cash}. I may use your services again.",
		fail = "You missed the deadline. This is unacceptable.",
		vip = false,
		urgency = 0.3,
		passengers = {1, 3},
	},
	{
		id = "VIP",
		title = "VIP CHARTER: Distinguished guest to {system}",
		desc = "A VIP requires discrete, first-class transport to {station} in {system}. Premium rates apply. Payment: {cash}.",
		intro = "My name is {client}. I require private transport to {station}. I expect comfort, speed, and above all, discretion. You'll be well compensated: {cash}.",
		success = "An acceptable journey. Your payment of {cash} has been authorized, plus a little extra for your... professionalism.",
		fail = "This delay is inexcusable. You'll be hearing from my attorneys.",
		vip = true,
		urgency = 0.5,
		passengers = {1, 1},
	},
	{
		id = "FAMILY",
		title = "FAMILY TRANSPORT: {count} passengers to {system}",
		desc = "A family of {count} needs transport to {station}, {system}. Safe passage is the priority. Payment: {cash}.",
		intro = "Hi, I'm {client}. My family and I need to get to {station}. We've heard you're reliable. The pay is {cash} - please get us there safely.",
		success = "Thank you so much! We made it safe and sound. Here's {cash} as promised.",
		fail = "We're too late... this has caused us a lot of problems.",
		vip = false,
		urgency = 0.1,
		passengers = {3, 6},
	},
	{
		id = "SCIENTIST",
		title = "RESEARCH EXPEDITION: {count} scientist{s} to {system}",
		desc = "Research team requires transport to {station}, {system} for field study. Equipment included. Payment: {cash}.",
		intro = "Dr. {client}, Galactic Research Institute. We need transport to {station} for our research expedition. We're on a grant budget: {cash}. Time-sensitive data collection.",
		success = "Excellent! We've arrived with time to spare. Payment of {cash} confirmed. Science thanks you!",
		fail = "The observation window has closed. Our research is set back months.",
		vip = false,
		urgency = 0.4,
		passengers = {2, 4},
	},
	{
		id = "REFUGEE",
		title = "URGENT: {count} refugee{s} need evacuation",
		desc = "Desperate individuals seek passage away from {source}. Any safe system within range. Humanitarian mission. Payment: {cash}.",
		intro = "Please, we need to leave this system. Things are bad here. We can pay {cash} - it's everything we have. Just get us somewhere safe.",
		success = "Thank you... you've saved our lives. Please, take {cash}. You've earned it.",
		fail = "We're stranded... we trusted you.",
		vip = false,
		urgency = 0.7,
		passengers = {2, 5},
	},
}

local ads = {}
local missions = {}

local function findDestination(flavour)
	local nearbySystems = Game.system:GetNearbySystems(MAX_DIST, function(s)
		return #s:GetStationPaths() > 0 and s.population > 0
	end)

	if #nearbySystems == 0 then return nil end

	-- Refugees go to low-lawlessness systems
	if flavour.id == "REFUGEE" then
		local safe = {}
		for _, s in ipairs(nearbySystems) do
			if s.lawlessness < 0.3 then table.insert(safe, s) end
		end
		if #safe > 0 then nearbySystems = safe end
	end

	local system = nearbySystems[Engine.rand:Integer(1, #nearbySystems)]
	local stations = system:GetStationPaths()
	if #stations == 0 then return nil end

	local stationPath = stations[Engine.rand:Integer(1, #stations)]
	local dist = system:DistanceTo(Game.system)

	return {
		path = stationPath,
		system = system,
		systemName = system.name,
		stationName = stationPath:GetSystemBody().name,
		dist = dist,
	}
end

local function makeAdvert(station)
	local count = 0
	for _, ad in pairs(ads) do
		if ad.station == station then count = count + 1 end
	end
	if count >= 3 then return end

	local flavour = FLAVOURS[Engine.rand:Integer(1, #FLAVOURS)]

	-- Refugees only in lawless systems
	if flavour.id == "REFUGEE" and Game.system.lawlessness < 0.4 then
		flavour = FLAVOURS[1]  -- fall back to business
	end

	local dest = findDestination(flavour)
	if not dest then return end

	local numPassengers = Engine.rand:Integer(flavour.passengers[1], flavour.passengers[2])
	numPassengers = math.min(numPassengers, MAX_PASSENGERS)

	-- Calculate reward
	local payPerPax = BASE_PAY_PER_PASSENGER * (1 + dest.dist * 0.1)
	if flavour.vip then payPerPax = payPerPax * VIP_MULTIPLIER end
	payPerPax = payPerPax * (1 + flavour.urgency)
	local reward = utils.round(math.floor(numPassengers * payPerPax * Engine.rand:Number(0.85, 1.25)), 50)

	-- Due: based on distance and urgency
	local travelDays = math.max(3, math.floor(dest.dist * 2 * (1.5 - flavour.urgency)))
	local due = Game.time + travelDays * 24 * 60 * 60

	local client = Character.New()

	local vars = {
		client = client.name,
		system = dest.systemName,
		station = dest.stationName,
		source = Game.system.name,
		count = tostring(numPassengers),
		cash = Format.Money(reward, false),
		s = numPassengers > 1 and "s" or "",
		r = numPassengers > 1 and "" or "s",
	}

	local function interp(str)
		return (str:gsub("{(%w+)}", function(k) return vars[k] or k end))
	end

	local ad = {
		station     = station,
		client      = client,
		flavour     = flavour,
		dest        = dest,
		numPax      = numPassengers,
		reward      = reward,
		due         = due,
		introtext   = interp(flavour.intro),
		successtext = interp(flavour.success),
		failtext    = interp(flavour.fail),
	}

	local ref = station:AddAdvert({
		title       = interp(flavour.title),
		description = interp(flavour.desc),
		icon        = "personal",
		due         = due,
		reward      = reward,
		location    = dest.path,
		onChat      = function(form, ref, option)
			local a = ads[ref]
			if not a then return end

			form:Clear()
			form:SetFace(a.client)
			form:AddNavButton(a.dest.path)

			if option == -1 then
				form:Close()
				return
			end

			if option == 0 then
				form:SetMessage(a.introtext)
				form:AddOption("How many passengers?", 1)
				form:AddOption("When do you need to arrive?", 2)
				form:AddOption("I'll take the job", 4)

			elseif option == 1 then
				local cabinInfo = string.format(
					"%d passenger%s. Make sure you have enough cabin space.",
					a.numPax, a.numPax > 1 and "s" or ""
				)
				if a.flavour.vip then
					cabinInfo = cabinInfo .. " As a VIP client, I expect premium accommodations."
				end
				form:SetMessage(cabinInfo)
				form:AddOption("Tell me more", 0)
				form:AddOption("I'll take the job", 4)

			elseif option == 2 then
				form:SetMessage(string.format("I need to be at %s by %s. That gives you %s.",
					a.dest.stationName, Format.Date(a.due),
					Format.Duration(a.due - Game.time, 2)))
				form:AddOption("Tell me more", 0)
				form:AddOption("I'll take the job", 4)

			elseif option == 4 then
				-- Check cabin capacity
				local freeBerths = Passengers.CountFreeBerths(Game.player)
				if freeBerths < a.numPax then
					form:SetMessage("You don't have enough cabin space for " .. a.numPax .. " passenger" ..
						(a.numPax > 1 and "s" or "") .. ". You only have " .. freeBerths ..
						" free berth" .. (freeBerths ~= 1 and "s" or "") ..
						". Upgrade your ship or free some cabins.")
					form:AddOption("Back", 0)
					return
				end

				-- Create passenger characters and embark them
				local passengerGroup = {}
				for i = 1, a.numPax do
					local pax = Character.New()
					table.insert(passengerGroup, pax)
					Passengers.EmbarkPassenger(Game.player, pax)
				end

				form:RemoveAdvertOnClose()
				ads[ref] = nil

				local mission = {
					type        = "PassengerTransport",
					client      = a.client,
					flavour     = a.flavour,
					destination = a.dest.path,
					dest        = a.dest,
					numPax      = a.numPax,
					passengers  = passengerGroup,
					reward      = a.reward,
					due         = a.due,
					status      = "ACTIVE",
					introtext   = a.introtext,
					successtext = a.successtext,
					failtext    = a.failtext,
				}
				mission = Mission.New(mission)
				table.insert(missions, mission)

				form:SetMessage(string.format(
					"%d passenger%s boarding. Destination: %s, %s system. Safe travels, Captain.",
					a.numPax, a.numPax > 1 and "s" or "", a.dest.stationName, a.dest.systemName
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
Mission.RegisterType("PassengerTransport", "Passenger Transport", function(mission)
	local timeLeft = mission.due - Game.time
	return {
		description = mission.introtext or "Transport passengers to destination.",
		details = {
			{ "Passengers", tostring(mission.numPax) },
			{ "Type", mission.flavour and mission.flavour.id or "Standard" },
			{ "Destination", mission.dest.stationName .. ", " .. mission.dest.systemName },
			{ "Distance", string.format("%.1f ly", mission.dest.dist) },
			{ "Reward", Format.Money(mission.reward, false) },
			{ "Deadline", Format.Date(mission.due) },
			{ "Time Left", Format.Duration(timeLeft, 2) },
		},
		location = mission.destination,
		client = mission.client,
	}
end)

-- Events
Event.Register("onCreateBB", function(station)
	local pop = Game.system.population or 0
	local num = Engine.rand:Integer(0, math.ceil(pop * 2) + 1)
	num = math.min(num, 4)
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
	if Engine.rand:Integer(1, 4) == 1 then
		makeAdvert(station)
	end
end)

Event.Register("onPlayerDocked", function(player, station)
	for ref, mission in pairs(missions) do
		if mission.destination and station.path == mission.destination then
			-- Disembark passengers
			if mission.passengers then
				for _, pax in ipairs(mission.passengers) do
					pcall(function() Passengers.DisembarkPassenger(player, pax) end)
				end
			end

			if Game.time > mission.due then
				-- Late delivery - reduced payment
				local latePay = math.floor(mission.reward * 0.5)
				PlayerState.AddMoney(latePay)
				Comms.ImportantMessage(
					string.format("Late arrival. Reduced payment: %s.", Format.Money(latePay, false)),
					mission.client.name
				)
				Character.persistent.player.reputation = (Character.persistent.player.reputation or 0) - 0.5
			else
				-- On time - check for early bonus
				local timeLeft = mission.due - Game.time
				local daysEarly = timeLeft / (24 * 60 * 60)
				local bonus = 0
				if daysEarly > 1 then
					bonus = math.floor(mission.reward * EARLY_BONUS_RATE * math.min(daysEarly, 5))
				end

				local total = mission.reward + bonus
				PlayerState.AddMoney(total)

				if bonus > 0 then
					Comms.ImportantMessage(
						string.format("Arrived %.1f days early! Payment: %s + %s early bonus.",
							daysEarly, Format.Money(mission.reward, false), Format.Money(bonus, false)),
						mission.client.name
					)
				else
					Comms.ImportantMessage(
						string.format("Passengers delivered. Payment: %s. Thank you, Captain.",
							Format.Money(mission.reward, false)),
						mission.client.name
					)
				end

				Character.persistent.player.reputation = (Character.persistent.player.reputation or 0) + 1.0
			end

			mission:Remove()
			missions[ref] = nil
		elseif mission.due < Game.time then
			-- Expired at wrong station - disembark passengers
			if mission.passengers then
				for _, pax in ipairs(mission.passengers) do
					pcall(function() Passengers.DisembarkPassenger(player, pax) end)
				end
			end
			Comms.ImportantMessage(
				mission.failtext or "The deadline has passed. Mission failed.",
				mission.client.name
			)
			Character.persistent.player.reputation = (Character.persistent.player.reputation or 0) - 1.5
			mission:Remove()
			missions[ref] = nil
		end
	end
end)

Event.Register("onGameEnd", function()
	ads = {}
	missions = {}
end)

-- Serialization
Serializer:Register("PassengerMissions",
	function()
		local save = {}
		for k, v in pairs(missions) do save[k] = v end
		return { missions = save }
	end,
	function(data)
		if data and data.missions then
			missions = data.missions
		end
		ads = {}
	end
)

-- Public API
PassengerMissions.GetActiveTransports = function()
	local active = {}
	for _, m in pairs(missions) do
		table.insert(active, {
			passengers = m.numPax,
			destination = m.dest and m.dest.systemName or "Unknown",
			reward = m.reward,
			due = m.due,
			type = m.flavour and m.flavour.id or "Standard",
		})
	end
	return active
end

print("[PassengerMissions] Module loaded - Passenger transport active")

return PassengerMissions
