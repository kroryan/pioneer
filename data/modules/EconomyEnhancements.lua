-- Copyright © 2008-2026 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

--
-- Module: EconomyEnhancements
--
-- Master integration module for all economy improvement modules.
-- This module loads and coordinates the three main economy enhancement systems:
-- - DynamicSystemEvents: Creates reactive economy events
-- - PersistentNPCTrade: Tracks trade shipments and regional dependencies
-- - SupplyChainNetwork: Manages multi-level supply chains
--
-- This is a self-contained enhancement suite that can be disabled/enabled as needed.
--

local Event         = require 'Event'
local Game          = require 'Game'
local Serializer    = require 'Serializer'

print("[LOAD] EconomyEnhancements: Master module starting...")

---@class EconomyEnhancements
local EconomyEnhancements = {}

-- Load all sub-modules (con manejo de errores robusto)
local DynamicSystemEvents = nil
local PersistentNPCTrade = nil
local SupplyChainNetwork = nil

local function LoadSubmodules()
	print("[LOAD] EconomyEnhancements: Attempting to load sub-modules...")
	
	local ok1, mod1 = pcall(function() return require 'modules.DynamicSystemEvents' end)
	if ok1 then 
		DynamicSystemEvents = mod1
		print("[LOAD] EconomyEnhancements: DynamicSystemEvents loaded OK")
	else
		print("[ERROR] EconomyEnhancements: Failed to load DynamicSystemEvents - " .. tostring(mod1))
	end
	
	local ok2, mod2 = pcall(function() return require 'modules.PersistentNPCTrade' end)
	if ok2 then 
		PersistentNPCTrade = mod2
		print("[LOAD] EconomyEnhancements: PersistentNPCTrade loaded OK")
	else
		print("[ERROR] EconomyEnhancements: Failed to load PersistentNPCTrade - " .. tostring(mod2))
	end
	
	local ok3, mod3 = pcall(function() return require 'modules.SupplyChainNetwork' end)
	if ok3 then 
		SupplyChainNetwork = mod3
		print("[LOAD] EconomyEnhancements: SupplyChainNetwork loaded OK")
	else
		print("[ERROR] EconomyEnhancements: Failed to load SupplyChainNetwork - " .. tostring(mod3))
	end
	
	print("[LOAD] EconomyEnhancements: Sub-module loading complete. Status: DSE=" .. tostring(ok1) .. " PNPT=" .. tostring(ok2) .. " SCN=" .. tostring(ok3))
	
	return (ok1 and ok2 and ok3)
end

-- Load sub-modules immediately when this module is required
print("[LOAD] EconomyEnhancements: Calling LoadSubmodules immediately...")
LoadSubmodules()

-- Module status
local module_enabled = true
local module_version = "1.0.0"

-- ============================================================================
-- INTEGRATION HELPERS
-- ============================================================================

--
-- Log an enhancement event (optional logging system)
--
local function LogEnhancementEvent(message, level)
	level = level or "INFO"
	-- Use Game.time for timestamp instead of os.date (os not available in Pioneer Lua)
	-- In production, could write to file or UI log
	-- print(string.format("[%s] [%s] %s", level, Game.time, message))
end

--
-- Function: GetModuleStatus
--
-- Return the current status of all enhancement modules
--
local function GetModuleStatus()
	return {
		enabled = module_enabled,
		version = module_version,
		system_events = DynamicSystemEvents,
		npc_trade = PersistentNPCTrade,
		supply_chains = SupplyChainNetwork,
	}
end

-- ============================================================================
-- CROSS-MODULE INTEGRATION
-- ============================================================================

--
-- Integrate effects between modules:
-- When a system event occurs, it may impact NPC trade routes
-- When supply chains are complete, they provide pricing bonuses
--

--
-- Function: OnSystemEventOccurred
--
-- Called when DynamicSystemEvents triggers an event
-- This can be used to notify other modules
--
local function OnSystemEventOccurred(event_data)
	-- NPCs would react to events (reduced shipments during wars, for example)
	-- Log for potential UI notifications
	LogEnhancementEvent(
		string.format("System Event: %s in %s (Severity: %.1f%%)",
			event_data.description,
			event_data.system_path:GetStarSystem().name,
			event_data.severity * 100),
		"EVENT"
	)
end

--
-- Function: OnSupplyChainCompleted
--
-- Called when a supply chain reaches full completion
-- Provides benefits across multiple systems
--
local function OnSupplyChainCompleted(chain_name, system_path)
	LogEnhancementEvent(
		string.format("Supply Chain Complete: %s at %s",
			chain_name,
			system_path:GetStarSystem().name),
		"ACHIEVEMENT"
	)
end

--
-- Function: OnNPCShipmentDestroyed
--
-- Called when an NPC trade ship is destroyed
-- This affects local economy and creates supply deficits
--
local function OnNPCShipmentDestroyed(shipment_info)
	LogEnhancementEvent(
		string.format("Trade Shipment Destroyed: Value loss %.0f credits",
			shipment_info.value),
		"WARNING"
	)
end

-- ============================================================================
-- PERIODIC COORDINATION
-- ============================================================================

--
-- Coordinate between modules at regular intervals
--
local function CoordinateModules()
	if not module_enabled then
		return
	end

	-- Check for system events and apply their effects
	local system_events = DynamicSystemEvents.GetSystemEvents()
	for event_id, event_data in pairs(system_events) do
		OnSystemEventOccurred(event_data)
	end

	-- Get supply chain statistics
	local chain_stats = SupplyChainNetwork.GetRouteStatistics()
	if chain_stats.active_routes > 0 then
		-- Coordinate with NPC trade module
		local trade_status = PersistentNPCTrade.GetShipmentStatus()
		LogEnhancementEvent(
			string.format("Economy Snapshot - Supply Chains: %d, Trade Shipments: %d",
				chain_stats.active_routes,
				trade_status.active_shipments),
			"DEBUG"
		)
	end
end

-- ============================================================================
-- GLOBAL API
-- ============================================================================

--
-- Function: Enable
--
-- Enable all economy enhancement modules
--
function EconomyEnhancements.Enable()
	module_enabled = true
	LogEnhancementEvent("Economy Enhancement Suite Enabled", "INFO")
end

--
-- Function: Disable
--
-- Disable all economy enhancement modules (they remain loaded for save compatibility)
--
function EconomyEnhancements.Disable()
	module_enabled = false
	LogEnhancementEvent("Economy Enhancement Suite Disabled", "INFO")
end

--
-- Function: IsEnabled
--
-- Check if enhancement suite is active
--
function EconomyEnhancements.IsEnabled()
	return module_enabled
end

--
-- Function: GetVersion
--
-- Return version information
--
function EconomyEnhancements.GetVersion()
	return module_version
end

--
-- Function: GetStatus
--
-- Return detailed status of all modules
--
function EconomyEnhancements.GetStatus()
	return GetModuleStatus()
end

--
-- Function: GetSystemEvents
--
-- Direct access to system events module
--
function EconomyEnhancements.GetSystemEvents()
	if not DynamicSystemEvents then return {} end
	return DynamicSystemEvents.GetSystemEvents()
end

--
-- Function: GetSystemEventDescription
--
-- Get description of a system event
--
function EconomyEnhancements.GetSystemEventDescription(event_data)
	return DynamicSystemEvents.GetEventDescription(event_data)
end

--
-- Function: GetNPCTradeStatus
--
-- Direct access to NPC trade status
--
function EconomyEnhancements.GetNPCTradeStatus()
	if not PersistentNPCTrade then return {active_shipments=0, destroyed_shipments=0, delivered_shipments=0, total_value=0} end
	return PersistentNPCTrade.GetShipmentStatus()
end

--
-- Function: GetRegionalDependencies
--
-- Get trade dependencies for current system
--
function EconomyEnhancements.GetRegionalDependencies()
	return PersistentNPCTrade.GetRegionalDependencies()
end

--
-- Function: GetDamagedCargo
--
-- Get statistics on destroyed cargo affecting prices
--
function EconomyEnhancements.GetDamagedCargo()
	return PersistentNPCTrade.GetDamagedCargoStatistics()
end

--
-- Function: GetSupplyChains
--
-- Get list of all supply chains
--
function EconomyEnhancements.GetSupplyChains()
	return SupplyChainNetwork.GetSupplyChains()
end

--
-- Function: GetChainOpportunities
--
-- Get current supply chain trading opportunities
--
function EconomyEnhancements.GetChainOpportunities()
	if not SupplyChainNetwork then return {} end
	return SupplyChainNetwork.GetChainOpportunities()
end

--
-- Function: GetChainEfficiency
--
-- Get efficiency bonuses for supply chains in a system
--
function EconomyEnhancements.GetChainEfficiency(system_path)
	return SupplyChainNetwork.GetChainEfficiency(system_path)
end

--
-- Function: GetCommodityBonus
--
-- Get supply chain pricing bonus for a commodity
--
function EconomyEnhancements.GetCommodityBonus(commodity_name)
	return SupplyChainNetwork.GetCommodityBonus(commodity_name)
end

-- ============================================================================
-- EVENT INITIALIZATION
-- ============================================================================

Event.Register("onGameStart", function()
	LoadSubmodules()
	if module_enabled then
		LogEnhancementEvent("Economy Enhancement Suite Initialized", "INFO")
		-- Start coordination timer (every 5 game minutes)
		local Timer = require 'Timer'
		if DynamicSystemEvents or PersistentNPCTrade or SupplyChainNetwork then
			Timer:CallEvery(5 * 60, CoordinateModules)
		end
	end
end)

Event.Register("onGameEnd", function()
	LogEnhancementEvent("Economy Enhancement Suite Shutdown", "INFO")
end)

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

local function _serialize()
	return {
		enabled = module_enabled,
		version = module_version,
	}
end

local function _deserialize(data)
	if not data then
		return
	end
	module_enabled = data.enabled ~= false -- Default to enabled for backward compatibility
	-- version stays current
end

Serializer:Register("EconomyEnhancements", _serialize, _deserialize)

-- ============================================================================
-- DOCUMENTATION
-- ============================================================================

--[[

=== ECONOMY ENHANCEMENTS SUITE ===

This suite consists of three integrated modules:

1. DynamicSystemEvents
   - Generates random events (wars, famines, booms, disasters, plagues)
   - Events affect commodity supply and demand
   - Economic opportunities arise from events
   - Player intervention (protecting caravans, trading) can influence outcomes

2. PersistentNPCTrade
   - Tracks NPC trade shipments between stations
   - Destroyed/delayed shipments affect destination economy
   - Creates regional supply dependencies
   - Player can protect or raid caravans to influence prices

3. SupplyChainNetwork
   - Defines multi-level supply chains (e.g., Mining → Metal → Manufacturing)
   - Provides bonuses for connecting chain nodes
   - Incentivizes long-distance trading
   - Creates profitable arbitrage opportunities

=== USAGE ===

-- Check status
local status = EconomyEnhancements.GetStatus()

-- Get system events
local events = EconomyEnhancements.GetSystemEvents()
for id, event in pairs(events) do
	print(EconomyEnhancements.GetSystemEventDescription(event))
end

-- Get trading opportunities
local opportunities = EconomyEnhancements.GetChainOpportunities()

-- Get NPC trade info
local trade_status = EconomyEnhancements.GetNPCTradeStatus()

-- Get commodity pricing bonus
local bonus = EconomyEnhancements.GetCommodityBonus("metals")

=== CONFIGURATION ===

Enable/disable via:
- EconomyEnhancements.Enable()
- EconomyEnhancements.Disable()

All modules are fully serializable and will save/load with the game.

]]

print("[LOAD] EconomyEnhancements: Master module loaded successfully and exported")
return EconomyEnhancements
