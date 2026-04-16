-- BountyBoard.lua - Economy Enhancement Suite v2.0
-- Bounty hunting contracts: find and destroy specific targets
-- by kroryan - GPL-3.0

local Engine = require 'Engine'
local Lang = require 'Lang'
local Game = require 'Game'
local Space = require 'Space'
local Comms = require 'Comms'
local Event = require 'Event'
local Timer = require 'Timer'
local Mission = require 'Mission'
local Format = require 'Format'
local Serializer = require 'Serializer'
local Character = require 'Character'
local NameGen = require 'NameGen'
local utils = require 'utils'
local PlayerState = require 'PlayerState'

local MissionUtils = require 'modules.MissionUtils'
local ShipBuilder = require 'modules.MissionUtils.ShipBuilder'

local BountyBoard = {}

-- Configuration
local MAX_BOUNTY_DIST = 15           -- max distance in ly for bounty targets
local BASE_REWARD = 2000             -- base reward per bounty
local MAX_BOUNTIES_PER_STATION = 3

-- Bounty flavours
local FLAVOURS = {
	{
		id = "PIRATE_LORD",
		title = "WANTED: {target} - Piracy",
		desc = "Bounty issued for the capture or destruction of {target}, wanted for multiple acts of piracy in the {system} system. Reward: {cash}. Last seen near {location}.",
		intro = "I'm {client}, representing {faction} security. We need {target} eliminated. This pirate has been raiding convoys for months. The bounty is {cash}.",
		success = "Excellent work! {target} won't be terrorizing anyone else. Here's your {cash}.",
		fail = "The deadline has passed. {target} has escaped our net.",
		min_lawlessness = 0.3,
		threat = 20,
	},
	{
		id = "SMUGGLER",
		title = "WANTED: {target} - Smuggling",
		desc = "Known smuggler {target} is wanted by {faction} authorities. Suspect armed and dangerous. Reward: {cash}. Frequents the {system} area.",
		intro = "Agent {client} here. {target} has been running illegal goods through our space. We want them stopped permanently. The reward is {cash}.",
		success = "That smuggler won't be moving contraband anymore. Payment of {cash} authorized.",
		fail = "We've lost track of {target}. Mission expired.",
		min_lawlessness = 0.1,
		threat = 15,
	},
	{
		id = "MURDERER",
		title = "WANTED: {target} - Murder",
		desc = "Fugitive {target} is wanted for multiple counts of murder. Armed and extremely dangerous. {faction} offers {cash} for elimination.",
		intro = "Detective {client}, homicide division. {target} killed three people at a station in {system}. We need a skilled pilot to bring them down. We're offering {cash}.",
		success = "Justice served. {target} has been dealt with. Your reward of {cash} is well earned.",
		fail = "{target} has fled the region. Bounty expired.",
		min_lawlessness = 0.0,
		threat = 25,
	},
	{
		id = "DESERTER",
		title = "WANTED: {target} - Military Desertion",
		desc = "Military deserter {target} has stolen classified equipment and fled. {faction} military command offers {cash}. Approach with extreme caution.",
		intro = "Commander {client}, {faction} military. One of our officers has gone rogue with sensitive equipment. Track and destroy. Budget: {cash}.",
		success = "The deserter is neutralized and the stolen equipment destroyed. {cash} transferred to your account.",
		fail = "The deserter has left the sector. Mission terminated.",
		min_lawlessness = 0.0,
		threat = 30,
	},
}

local ads = {}
local missions = {}

local function findTargetLocation(station)
	local validPlanets = {}
	local nearbySystems = Game.system:GetNearbySystems(MAX_BOUNTY_DIST, function(s)
		return #s:GetBodyPaths() > 0
	end)

	-- Also include current system
	for _, p in ipairs(Game.system:GetBodyPaths()) do
		local sbody = p:GetSystemBody()
		if sbody and (sbody.type == "PLANET_TERRESTRIAL" or sbody.type == "PLANET_GAS_GIANT") then
			table.insert(validPlanets, { path = p, system = Game.system, dist = 0 })
		end
	end

	for _, s in pairs(nearbySystems) do
		local dist = s:DistanceTo(Game.system)
		for _, p in ipairs(s:GetBodyPaths()) do
			local sbody = p:GetSystemBody()
			if sbody and (sbody.type == "PLANET_TERRESTRIAL" or sbody.type == "PLANET_GAS_GIANT") then
				table.insert(validPlanets, { path = p, system = s, dist = dist })
			end
		end
	end

	if #validPlanets == 0 then return nil end
	return validPlanets[Engine.rand:Integer(1, #validPlanets)]
end

local function makeAdvert(station)
	-- Count existing bounty ads at this station
	local count = 0
	for _, ad in pairs(ads) do
		if ad.station == station then count = count + 1 end
	end
	if count >= MAX_BOUNTIES_PER_STATION then return end

	-- Pick a flavour based on system lawlessness
	local lawlessness = Game.system.lawlessness or 0
	local validFlavours = {}
	for _, f in ipairs(FLAVOURS) do
		if lawlessness >= f.min_lawlessness then
			table.insert(validFlavours, f)
		end
	end
	if #validFlavours == 0 then return end

	local flavour = validFlavours[Engine.rand:Integer(1, #validFlavours)]

	-- Find target location
	local targetInfo = findTargetLocation(station)
	if not targetInfo then return end

	-- Generate target and client
	local target = Character.New()
	local client = Character.New({ title = "Agent" })

	local factionName = "Authorities"
	local ok, fac = pcall(function() return Game.system.faction end)
	if ok and fac and fac.name then factionName = fac.name end

	-- Calculate reward based on distance, threat, and risk
	local dist = targetInfo.dist
	local reward = math.floor(BASE_REWARD * (1 + dist * 0.3) * (flavour.threat / 15) * Engine.rand:Number(0.8, 1.4))
	reward = utils.round(reward, 100)

	-- Due date: 14-28 days
	local due = Game.time + Engine.rand:Number(14, 28) * 24 * 60 * 60

	local vars = {
		target = target.name,
		client = client.name,
		system = targetInfo.path:GetStarSystem().name,
		location = targetInfo.path:GetSystemBody().name,
		faction = factionName,
		cash = Format.Money(reward, false),
	}

	local function interp(str)
		return (str:gsub("{(%w+)}", function(k) return vars[k] or k end))
	end

	local ad = {
		station     = station,
		flavour     = flavour,
		client      = client,
		target      = target,
		targetName  = target.name,
		location    = targetInfo.path,
		dist        = dist,
		reward      = reward,
		due         = due,
		faction     = factionName,
		introtext   = interp(flavour.intro),
		successtext = interp(flavour.success),
		failtext    = interp(flavour.fail),
	}

	local ref = station:AddAdvert({
		title       = interp(flavour.title),
		description = interp(flavour.desc),
		icon        = "combat",
		due         = due,
		reward      = reward,
		location    = targetInfo.path,
		onChat      = function(form, ref, option)
			local a = ads[ref]
			if not a then return end

			form:Clear()
			form:SetFace(a.client)
			form:AddNavButton(a.location)

			if option == -1 then
				form:Close()
				return
			end

			local reputation = Character.persistent.player.reputation or 0
			local killcount = Character.persistent.player.killcount or 0

			if reputation < 4 or killcount < 2 then
				form:SetMessage("Sorry, we need someone with more combat experience for this job. Come back when you've proven yourself.")
				return
			end

			if option == 0 then
				form:SetMessage(a.introtext)
				form:AddOption("What's the target's ship?", 1)
				form:AddOption("Where exactly?", 2)
				form:AddOption("Is there a deadline?", 3)
				form:AddOption("I'll take the job", 4)

			elseif option == 1 then
				form:SetMessage("Intel suggests a well-armed vessel. Threat level: " ..
					(a.flavour.threat >= 25 and "HIGH" or a.flavour.threat >= 18 and "MEDIUM" or "LOW") ..
					". Don't underestimate them.")
				form:AddOption("Tell me more", 0)
				form:AddOption("I'll take the job", 4)

			elseif option == 2 then
				form:SetMessage(string.format("Last known location: orbiting %s in the %s system. %.1f light years from here.",
					a.location:GetSystemBody().name,
					a.location:GetStarSystem().name,
					a.dist))
				form:AddOption("Tell me more", 0)
				form:AddOption("I'll take the job", 4)

			elseif option == 3 then
				form:SetMessage("This bounty expires on " .. Format.Date(a.due) .. ". Don't miss the deadline.")
				form:AddOption("Tell me more", 0)
				form:AddOption("I'll take the job", 4)

			elseif option == 4 then
				form:RemoveAdvertOnClose()
				ads[ref] = nil

				local mission = {
					type        = "BountyHunt",
					client      = a.client,
					target      = a.target,
					targetName  = a.targetName,
					location    = a.location,
					destination = a.location,
					faction     = a.faction,
					flavour     = a.flavour,
					reward      = a.reward,
					due         = a.due,
					introtext   = a.introtext,
					successtext = a.successtext,
					failtext    = a.failtext,
					target_spawned = false,
					target_ship = nil,
					complete    = false,
				}
				mission = Mission.New(mission)
				table.insert(missions, mission)

				form:SetMessage("Good hunting, pilot. Eliminate " .. a.targetName .. " and return here for payment.")
			end
		end,
		onDelete    = function(ref) ads[ref] = nil end,
		isEnabled   = function(ref)
			return ads[ref] ~= nil and
				(Character.persistent.player.reputation or 0) >= 4 and
				(Character.persistent.player.killcount or 0) >= 2
		end,
	})

	if ref then
		ads[ref] = ad
	end
end

-- Register mission type for the missions panel
Mission.RegisterType("BountyHunt", "Bounty Hunt", function(mission)
	if mission.complete then
		return {
			description = "Return to collect bounty on " .. mission.targetName .. ".",
			details = {
				{ "Target", mission.targetName },
				{ "Status", "ELIMINATED" },
				{ "Reward", Format.Money(mission.reward, false) },
				{ "Deadline", Format.Date(mission.due) },
			},
			location = mission.destination,
			client = mission.client,
		}
	else
		return {
			description = mission.introtext or ("Hunt down " .. mission.targetName),
			details = {
				{ "Target", mission.targetName },
				{ "Last Seen", mission.location:GetSystemBody().name .. ", " .. mission.location:GetStarSystem().name },
				{ "Threat", mission.flavour.threat >= 25 and "HIGH" or mission.flavour.threat >= 18 and "MEDIUM" or "LOW" },
				{ "Reward", Format.Money(mission.reward, false) },
				{ "Deadline", Format.Date(mission.due) },
			},
			location = mission.location,
			client = mission.client,
		}
	end
end)

-- Events
Event.Register("onCreateBB", function(station)
	local num = Engine.rand:Integer(0, math.ceil(Game.system.lawlessness * 3) + 1)
	for i = 1, num do
		makeAdvert(station)
	end
end)

Event.Register("onUpdateBB", function(station)
	-- Clean up expired ads
	for ref, ad in pairs(ads) do
		if ad.due < Game.time then
			pcall(function() ad.station:RemoveAdvert(ref) end)
			ads[ref] = nil
		end
	end
	-- Maybe add new bounties
	if Engine.rand:Integer(1, 8) == 1 then
		makeAdvert(station)
	end
end)

Event.Register("onFrameChanged", function(player)
	if not player:isa("Ship") or not player:IsPlayer() then return end

	for ref, mission in pairs(missions) do
		if not mission.target_spawned and not mission.complete
			and player.frameBody
			and player.frameBody.path == mission.location then

			mission.target_spawned = true

			local threat = mission.flavour.threat or 20
			local planet_radius = player.frameBody:GetPhysicalRadius()

			local template = MissionUtils.ShipTemplates.GenericMercenary:clone {
				role = "pirate",
				label = mission.targetName,
			}

			local ship = ShipBuilder.MakeShipOrbit(player.frameBody, template, threat,
				1.5 * planet_radius, 4.0 * planet_radius)

			if ship then
				ship:SetLabel(mission.targetName)
				mission.target_ship = ship

				Comms.ImportantMessage("Target detected: " .. mission.targetName .. ". Engage with caution.", "Bounty Scanner")

				-- Target attacks player after a delay
				Timer:CallAt(Game.time + 8, function()
					if mission.target_ship and mission.target_ship:exists() then
						mission.target_ship:AIKill(Game.player)
					end
				end)
			end
		end
	end
end)

Event.Register("onShipDestroyed", function(ship, attacker)
	if ship:IsPlayer() then return end

	for ref, mission in pairs(missions) do
		if mission.target_ship == ship then
			mission.complete = true
			mission.target_ship = nil

			-- Set return destination (original station/faction)
			mission.status = "COMPLETED"
			if mission.client then
				Comms.ImportantMessage("Target " .. mission.targetName .. " eliminated! Return to collect your bounty of " ..
					Format.Money(mission.reward, false) .. ".", "Bounty Board")
			end
			break
		end
	end
end)

Event.Register("onPlayerDocked", function(player, station)
	for ref, mission in pairs(missions) do
		if mission.complete then
			PlayerState.AddMoney(mission.reward)
			Comms.ImportantMessage(
				string.format("Bounty collected: %s for the elimination of %s.",
					Format.Money(mission.reward, false), mission.targetName),
				mission.client.name
			)

			local oldRep = Character.persistent.player.reputation
			Character.persistent.player.reputation = (Character.persistent.player.reputation or 0) + 1.5
			Event.Queue("onReputationChanged", oldRep, Character.persistent.player.killcount,
				Character.persistent.player.reputation, Character.persistent.player.killcount)

			mission:Remove()
			missions[ref] = nil
		elseif mission.due < Game.time then
			Comms.ImportantMessage(mission.failtext or "Bounty expired.", mission.client.name)
			local oldRep = Character.persistent.player.reputation
			Character.persistent.player.reputation = (Character.persistent.player.reputation or 0) - 1.0
			Event.Queue("onReputationChanged", oldRep, Character.persistent.player.killcount,
				Character.persistent.player.reputation, Character.persistent.player.killcount)
			mission:Remove()
			missions[ref] = nil
		end
	end
end)

Event.Register("onEnterSystem", function(player)
	if not player:isa("Ship") or not player:IsPlayer() then return end

	for ref, mission in pairs(missions) do
		-- Reset spawn flag when entering the target system
		if mission.location and mission.location:IsSameSystem(Game.system.path) then
			if not mission.complete and not mission.target_spawned then
				Comms.Message("Bounty target " .. mission.targetName ..
					" may be in this system. Proceed to " .. mission.location:GetSystemBody().name .. ".",
					"Bounty Scanner")
			end
		end
	end
end)

Event.Register("onLeaveSystem", function(player)
	for ref, mission in pairs(missions) do
		mission.target_spawned = false
		mission.target_ship = nil
	end
end)

Event.Register("onGameEnd", function()
	ads = {}
	missions = {}
end)

-- Serialization
Serializer:Register("BountyBoard",
	function()
		local save_missions = {}
		for k, v in pairs(missions) do
			local m = {}
			for key, val in pairs(v) do
				if key ~= "target_ship" then
					m[key] = val
				end
			end
			m.target_spawned = false
			save_missions[k] = m
		end
		return { missions = save_missions }
	end,
	function(data)
		if data and data.missions then
			missions = data.missions
			for _, m in pairs(missions) do
				m.target_ship = nil
				m.target_spawned = false
			end
		end
		ads = {}
	end
)

-- Public API
BountyBoard.GetActiveBounties = function()
	local active = {}
	for _, m in pairs(missions) do
		table.insert(active, {
			target = m.targetName,
			location = m.location,
			reward = m.reward,
			due = m.due,
			complete = m.complete,
		})
	end
	return active
end

print("[BountyBoard] Module loaded - Bounty hunting system active")

return BountyBoard
