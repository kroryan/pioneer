-- CrewInteractions.lua - Economy Enhancement Suite v2.0
-- Periodic crew dialogue, skill-check events, and context-sensitive comments
-- by kroryan - GPL-3.0

local Engine = require 'Engine'
local Game = require 'Game'
local Event = require 'Event'
local Timer = require 'Timer'
local Comms = require 'Comms'
local Character = require 'Character'
local Serializer = require 'Serializer'

local CrewInteractions = {}

-- Configuration
local CHECK_INTERVAL = 900           -- 15 minutes between interaction checks
local INTERACTION_CHANCE = 0.35      -- 35% chance per check
local DANGER_COMMENT_CHANCE = 0.6    -- 60% chance of danger comment in lawless systems

-- Dialogue templates
local IDLE_COMMENTS = {
	"All systems nominal, Commander.",
	"Running routine diagnostics... everything checks out.",
	"Sensors are clear. Quiet out here.",
	"I've been reviewing the star charts. Some interesting systems nearby.",
	"Fuel reserves look stable. Good flying, Commander.",
	"Just calibrated the nav computer. We're on course.",
	"Any thoughts on our next port of call?",
	"I've been cross-referencing trade data. Could be some opportunities ahead.",
}

local DANGER_COMMENTS = {
	"Commander, sensors show high lawlessness in this system. Stay sharp.",
	"I don't like the look of this system. Pirates could be anywhere.",
	"Weapons check complete. Given the neighborhood, we might need them.",
	"I'm tracking several unidentified contacts. Could be trouble.",
	"The crime rate here is off the charts. Let's not stay long.",
}

local DOCKED_COMMENTS = {
	"Good to be docked. I'll run some maintenance while we're here.",
	"Station looks busy. Should be good for trade.",
	"I'll check the bulletin board for anything interesting.",
	"Fuel's being topped off. We'll be ready when you are.",
	"I hear the food here isn't bad. For a space station, anyway.",
}

local TRADE_SUGGESTIONS = {
	{ commodity = "hydrogen",           context = "low_fuel",  msg = "Commander, hydrogen prices look good here. Might want to stock up." },
	{ commodity = "medicines",          context = "any",       msg = "Medical supplies always sell well in frontier systems." },
	{ commodity = "consumer_goods",     context = "populated", msg = "Populated systems eat up consumer goods. Worth considering." },
	{ commodity = "metal_ore",          context = "any",       msg = "I've seen decent demand for metal ore at industrial stations." },
	{ commodity = "computers",          context = "high_tech", msg = "High-tech stations always need computers. Just saying." },
	{ commodity = "grain",              context = "any",       msg = "Agricultural goods are always in demand somewhere." },
	{ commodity = "precious_metals",    context = "any",       msg = "Precious metals can fetch a good price at the right station." },
	{ commodity = "military_fuel",      context = "lawless",   msg = "Military fuel sells well in rough neighborhoods. Risk and reward." },
}

local ENGINEERING_EVENTS = {
	{
		msg_success = "{name} spots a minor power coupling issue and fixes it before it becomes a problem. Good catch!",
		msg_fail    = "{name} reports some unusual readings from the power grid but can't track down the source.",
		skill       = "engineering",
		difficulty  = 0,
	},
	{
		msg_success = "{name} optimizes the fuel injection system. We might get slightly better fuel efficiency for a while.",
		msg_fail    = "{name} tried tweaking the fuel injectors but decided to leave them as they are.",
		skill       = "engineering",
		difficulty  = 5,
	},
	{
		msg_success = "{name} recalibrates the navigation sensors. Star readings are crisper now.",
		msg_fail    = "{name} notices the nav sensors could use recalibration but it's a bit beyond their expertise.",
		skill       = "sensors",
		difficulty  = 0,
	},
}

local CONFLICT_EVENTS = {
	{
		msg = "{name1} and {name2} are having a disagreement about duty rotations. They'll sort it out.",
		resolution = "The crew worked it out amongst themselves. No harm done.",
	},
	{
		msg = "{name1} thinks we should head to a safer system. {name2} disagrees.",
		resolution = "After some debate, the crew deferred to your judgment, Commander.",
	},
}

-- State
local state = {
	last_interaction_time = 0,
	interaction_count = 0,
	crew_morale = 100,   -- 0-100
}

local timer_started = false

local function getCrewMembers()
	local crew = {}
	if not Game.player then return crew end
	local ok, _ = pcall(function()
		Game.player:EachCrewMember(function(member)
			if member and not member.player then
				table.insert(crew, member)
			end
		end)
	end)
	return crew
end

-- Ship computer comments for solo pilots
local COMPUTER_COMMENTS = {
	"All systems nominal, Commander. Ship computer standing by.",
	"Running automated diagnostics... all within parameters.",
	"Sensors clear. No contacts detected.",
	"Fuel reserves stable. Route calculations up to date.",
	"Navigation beacon sync complete. Star charts updated.",
	"Automated maintenance cycle complete. Hull integrity nominal.",
	"Monitoring local comms. Nothing of note, Commander.",
}

local COMPUTER_DANGER = {
	"WARNING: High lawlessness detected in this system. Recommend caution.",
	"ALERT: System threat level elevated. Shields recommended.",
	"NOTICE: Crime index above normal. Monitoring for hostiles.",
}

local COMPUTER_DOCKED = {
	"Docking complete. Running post-flight diagnostics.",
	"Station services available. Refuelling in progress.",
	"Secure dock confirmed. Systems in standby mode.",
}

local function doComputerComment()
	if Game.system and Game.system.lawlessness > 0.4 and Engine.rand:Number(1.0) < 0.4 then
		local msg = COMPUTER_DANGER[Engine.rand:Integer(1, #COMPUTER_DANGER)]
		Comms.Message(msg, "Ship Computer")
	else
		local msg = COMPUTER_COMMENTS[Engine.rand:Integer(1, #COMPUTER_COMMENTS)]
		Comms.Message(msg, "Ship Computer")
	end
end

local function interpolateMsg(msg, vars)
	return (msg:gsub("{(%w+)}", function(key) return vars[key] or key end))
end

local function doIdleComment(crew)
	if #crew == 0 then return end
	local member = crew[Engine.rand:Integer(1, #crew)]
	local msg = IDLE_COMMENTS[Engine.rand:Integer(1, #IDLE_COMMENTS)]
	Comms.Message(msg, member.name)
end

local function doDangerComment(crew)
	if #crew == 0 then return end
	local member = crew[Engine.rand:Integer(1, #crew)]
	local msg = DANGER_COMMENTS[Engine.rand:Integer(1, #DANGER_COMMENTS)]
	Comms.Message(msg, member.name)
end

local function doTradeSuggestion(crew)
	if #crew == 0 then return end
	local member = crew[Engine.rand:Integer(1, #crew)]

	local system = Game.system
	if not system then return end

	local validSuggestions = {}
	for _, sug in ipairs(TRADE_SUGGESTIONS) do
		if sug.context == "any" then
			table.insert(validSuggestions, sug)
		elseif sug.context == "populated" and system.population > 0.3 then
			table.insert(validSuggestions, sug)
		elseif sug.context == "high_tech" and system.population > 0.5 then
			table.insert(validSuggestions, sug)
		elseif sug.context == "lawless" and system.lawlessness > 0.5 then
			table.insert(validSuggestions, sug)
		end
	end

	if #validSuggestions > 0 then
		local sug = validSuggestions[Engine.rand:Integer(1, #validSuggestions)]
		Comms.Message(sug.msg, member.name)
	end
end

local function doEngineeringEvent(crew)
	if #crew == 0 then return end
	local member = crew[Engine.rand:Integer(1, #crew)]

	local evt = ENGINEERING_EVENTS[Engine.rand:Integer(1, #ENGINEERING_EVENTS)]
	local vars = { name = member.name }

	local roll = member:TestRoll(evt.skill, evt.difficulty)
	if roll then
		Comms.Message(interpolateMsg(evt.msg_success, vars), "Ship Systems")
	else
		Comms.Message(interpolateMsg(evt.msg_fail, vars), "Ship Systems")
	end
end

local function doInteraction()
	if not Game.player then return end
	if Game.player.flightState == "HYPERSPACE" then return end

	local crew = getCrewMembers()
	-- Solo pilot gets ship computer interactions
	if #crew == 0 then
		doComputerComment()
		state.interaction_count = state.interaction_count + 1
		state.last_interaction_time = Game.time
		return
	end

	local roll = Engine.rand:Number(1.0)

	if roll < 0.30 then
		-- Idle comment
		doIdleComment(crew)
	elseif roll < 0.50 then
		-- Trade suggestion
		doTradeSuggestion(crew)
	elseif roll < 0.65 then
		-- Engineering event
		doEngineeringEvent(crew)
	elseif roll < 0.80 then
		-- Context-sensitive comment (danger)
		local system = Game.system
		if system and system.lawlessness > 0.4 then
			doDangerComment(crew)
		else
			doIdleComment(crew)
		end
	else
		-- Conflict mini-event (rare)
		if #crew >= 2 then
			local evt = CONFLICT_EVENTS[Engine.rand:Integer(1, #CONFLICT_EVENTS)]
			local vars = {
				name1 = crew[1].name,
				name2 = crew[math.min(2, #crew)].name,
			}
			Comms.Message(interpolateMsg(evt.msg, vars), "Crew")
		else
			doIdleComment(crew)
		end
	end

	state.interaction_count = state.interaction_count + 1
	state.last_interaction_time = Game.time
end

local function startTimer()
	if timer_started then return end
	timer_started = true

	Timer:CallEvery(CHECK_INTERVAL, function()
		if not Game.player then return end
		if Engine.rand:Number(1.0) < INTERACTION_CHANCE then
			doInteraction()
		end
	end)
end

-- Events
Event.Register("onGameStart", function()
	timer_started = false
	startTimer()
end)

Event.Register("onPlayerDocked", function(ship, station)
	-- Docked comment
	local crew = getCrewMembers()
	if Engine.rand:Number(1.0) < 0.5 then
		if #crew > 0 then
			local member = crew[Engine.rand:Integer(1, #crew)]
			local msg = DOCKED_COMMENTS[Engine.rand:Integer(1, #DOCKED_COMMENTS)]
			Comms.Message(msg, member.name)
		else
			local msg = COMPUTER_DOCKED[Engine.rand:Integer(1, #COMPUTER_DOCKED)]
			Comms.Message(msg, "Ship Computer")
		end
	end
end)

Event.Register("onEnterSystem", function(ship)
	if not ship or not ship:isa("Ship") or not ship.IsPlayer or not ship:IsPlayer() then return end

	local system = Game.system
	if not system then return end

	-- Comment on entering a dangerous system
	if system.lawlessness > 0.6 and Engine.rand:Number(1.0) < DANGER_COMMENT_CHANCE then
		local crew = getCrewMembers()
		if #crew > 0 then
			local member = crew[Engine.rand:Integer(1, #crew)]
			Comms.ImportantMessage(
				string.format("Heads up, Commander. %s has a reputation. Keep weapons hot.", system.name),
				member.name
			)
		else
			Comms.ImportantMessage(
				string.format("WARNING: %s has elevated threat level. Recommend caution.", system.name),
				"Ship Computer"
			)
		end
	end
end)

Event.Register("onShipHit", function(ship, attacker)
	if not ship or not ship:IsPlayer() then return end
	local crew = getCrewMembers()
	if #crew > 0 and Engine.rand:Number(1.0) < 0.3 then
		local member = crew[Engine.rand:Integer(1, #crew)]
		local msgs = {
			"Shields holding! Return fire!",
			"We're hit! Checking for damage...",
			"Contact! We're under attack!",
			"Damage report coming in... nothing critical yet.",
		}
		Comms.ImportantMessage(msgs[Engine.rand:Integer(1, #msgs)], member.name)
	end
end)

Event.Register("onGameEnd", function()
	state = { last_interaction_time = 0, interaction_count = 0, crew_morale = 100 }
	timer_started = false
end)

-- Serialization
Serializer:Register("CrewInteractions",
	function()
		return state
	end,
	function(data)
		if data then
			state = data
			if not state.crew_morale then state.crew_morale = 100 end
			if not state.interaction_count then state.interaction_count = 0 end
		end
		timer_started = false
		startTimer()
	end
)

-- Public API
CrewInteractions.GetMorale = function() return state.crew_morale end
CrewInteractions.GetInteractionCount = function() return state.interaction_count end
CrewInteractions.GetCrewCount = function()
	local crew = getCrewMembers()
	return #crew + 1  -- +1 for the player (Commander)
end

print("[CrewInteractions] Module loaded - Crew dialogue system active")

return CrewInteractions
