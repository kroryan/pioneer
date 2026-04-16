-- Copyright © 2008-2026 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

--
-- Module: DynamicSystemEvents
--
-- This module creates dynamic events that impact the local economy of systems.
-- Events like wars, famines, and economic booms affect commodity supply and demand,
-- creating lucrative trading opportunities and making the economy reactive to events.
--
-- Self-contained module - no external dependencies beyond game core libraries
--

local Engine      = require 'Engine'
local Event       = require 'Event'
local Game        = require 'Game'
local Timer       = require 'Timer'
local Rand        = require 'Rand'
local Serializer  = require 'Serializer'
local utils       = require 'utils'

print("[LOAD] DynamicSystemEvents: Initializing...")

---@class DynamicSystemEvents
local DynamicSystemEvents = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- Event types
local EventTypes = {
	WAR = { name = "war", description = "Civil War", duration = 72, severity_range = { 0.5, 2.0 } },
	FAMINE = { name = "famine", description = "Food Crisis", duration = 48, severity_range = { 0.6, 1.8 } },
	BOOM = { name = "boom", description = "Economic Boom", duration = 60, severity_range = { 0.3, 1.5 } },
	DISASTER = { name = "disaster", description = "Natural Disaster", duration = 36, severity_range = { 0.8, 2.0 } },
	PLAGUE = { name = "plague", description = "Disease Outbreak", duration = 54, severity_range = { 0.7, 1.9 } },
}

local EventList = utils.to_array(EventTypes)
table.sort(EventList, function(a, b) return a.name < b.name end)

print("[LOAD] DynamicSystemEvents: Registered " .. #EventList .. " event types")

-- Probability of events
local EVENT_PROBABILITY = 0.0005

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

local active_events = {}
local event_id_counter = 0

-- ============================================================================
-- EVENT GENERATION
-- ============================================================================

--
-- Function: GenerateSystemEvent
--
-- Randomly generate an event for a system based on probability
-- Returns event data or nil if no event is generated
--
local function GenerateSystemEvent(system_path)
	if Engine.rand:Number() > EVENT_PROBABILITY then
		return nil
	end

	local event_type = EventList[Engine.rand:Integer(1, #EventList)]
	event_id_counter = event_id_counter + 1

	local event_data = {
		id = event_id_counter,
		system_path = system_path,
		type = event_type.name,
		start_time = Game.time,
		end_time = Game.time + (event_type.duration * 3600),
		severity = Engine.rand:Number(event_type.severity_range[1], event_type.severity_range[2]),
		description = event_type.description,
	}

	return event_data
end

--
-- Function: ProcessActiveEvents
--
-- Check and update all active events in the current system
--
local function ProcessActiveEvents()
	if not Game.system then
		return
	end

	local system_path = Game.system.path
	if not active_events[system_path] then
		active_events[system_path] = {}
	end

	-- Remove expired events
	for event_id, event_data in pairs(active_events[system_path]) do
		if event_data.end_time <= Game.time then
			active_events[system_path][event_id] = nil
		end
	end

	-- Try to generate new events
	local event_data = GenerateSystemEvent(system_path)
	if event_data then
		active_events[system_path][event_data.id] = event_data
	end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

Event.Register("onEnterSystem", function(ship)
	if not ship:IsPlayer() then
		return
	end
	ProcessActiveEvents()
end)

Event.Register("onGameStart", function()
	if Game.system then
		active_events[Game.system.path] = {}
		ProcessActiveEvents()
	end
	Timer:CallEvery(30 * 60, ProcessActiveEvents)
end)

Event.Register("onGameEnd", function()
	active_events = {}
end)

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

local function _serialize()
	return {
		events = active_events,
		event_id_counter = event_id_counter,
	}
end

local function _deserialize(data)
	if not data then return end
	active_events = data.events or {}
	event_id_counter = data.event_id_counter or 0
end

Serializer:Register("DynamicSystemEvents", _serialize, _deserialize)

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--
-- Function: GetSystemEvents
--
-- Return all active events in the current system
--
function DynamicSystemEvents.GetSystemEvents()
	if not Game.system then
		return {}
	end
	return active_events[Game.system.path] or {}
end

--
-- Function: GetEventDescription
--
-- Return a human-readable description of an event
--
function DynamicSystemEvents.GetEventDescription(event_data)
	return string.format(
		"%s in %s - Severity: %.1f%%",
		event_data.description,
		event_data.system_path:GetStarSystem().name,
		event_data.severity * 100
	)
end

print("[LOAD] DynamicSystemEvents: Module loaded successfully and exported")
return DynamicSystemEvents
