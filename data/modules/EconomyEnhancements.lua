-- Copyright © 2008-2026 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

--
-- Module: EconomyEnhancements
--
-- Master coordinator for the Economy Enhancement Suite.
-- Loads and coordinates three sub-modules:
--   DynamicSystemEvents  - Multi-commodity systemic events with real price effects
--   PersistentNPCTrade   - NPC cargo destruction tracking and supply deficits
--   SupplyChainNetwork   - Player trade tracking along supply chains
--

local Event         = require 'Event'
local Game          = require 'Game'
local Serializer    = require 'Serializer'

---@class EconomyEnhancements
local EconomyEnhancements = {}

-- ============================================================================
-- SUB-MODULE LOADING
-- ============================================================================

local DynamicSystemEvents = nil
local PersistentNPCTrade  = nil
local SupplyChainNetwork  = nil

local function LoadSubmodules()
	local ok1, mod1 = pcall(function() return require 'modules.DynamicSystemEvents' end)
	if ok1 then
		DynamicSystemEvents = mod1
	else
		print("[EconomyEnhancements] DynamicSystemEvents: " .. tostring(mod1))
	end

	local ok2, mod2 = pcall(function() return require 'modules.PersistentNPCTrade' end)
	if ok2 then
		PersistentNPCTrade = mod2
	else
		print("[EconomyEnhancements] PersistentNPCTrade: " .. tostring(mod2))
	end

	local ok3, mod3 = pcall(function() return require 'modules.SupplyChainNetwork' end)
	if ok3 then
		SupplyChainNetwork = mod3
	else
		print("[EconomyEnhancements] SupplyChainNetwork: " .. tostring(mod3))
	end

	return ok1 and ok2 and ok3
end

LoadSubmodules()

-- ============================================================================
-- STATE
-- ============================================================================

local module_enabled = true
local module_version = "2.0.0"

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function EconomyEnhancements.Enable()
	module_enabled = true
end

function EconomyEnhancements.Disable()
	module_enabled = false
end

function EconomyEnhancements.IsEnabled()
	return module_enabled
end

function EconomyEnhancements.GetVersion()
	return module_version
end

function EconomyEnhancements.GetStatus()
	return {
		enabled = module_enabled,
		version = module_version,
		system_events = DynamicSystemEvents ~= nil,
		npc_trade     = PersistentNPCTrade ~= nil,
		supply_chains = SupplyChainNetwork ~= nil,
	}
end

-- DynamicSystemEvents pass-through
function EconomyEnhancements.GetSystemEvents()
	if not DynamicSystemEvents then return {} end
	return DynamicSystemEvents.GetSystemEvents()
end

function EconomyEnhancements.GetSystemEventDescription(ev)
	if not DynamicSystemEvents then return "N/A" end
	return DynamicSystemEvents.GetEventDescription(ev)
end

function EconomyEnhancements.GetEventTypes()
	if not DynamicSystemEvents then return {} end
	return DynamicSystemEvents.GetEventTypes()
end

-- PersistentNPCTrade pass-through
function EconomyEnhancements.GetNPCTradeStatus()
	if not PersistentNPCTrade then
		return { active_shipments = 0, destroyed_shipments = 0, delivered_shipments = 0, total_value = 0 }
	end
	return PersistentNPCTrade.GetShipmentStatus()
end

function EconomyEnhancements.GetSupplyDeficits()
	if not PersistentNPCTrade then return {} end
	return PersistentNPCTrade.GetSupplyDeficits()
end

function EconomyEnhancements.GetRegionalDependencies()
	if not PersistentNPCTrade then return {} end
	return PersistentNPCTrade.GetRegionalDependencies()
end

function EconomyEnhancements.GetDamagedCargo()
	if not PersistentNPCTrade then return {} end
	return PersistentNPCTrade.GetDamagedCargoStatistics()
end

-- SupplyChainNetwork pass-through
function EconomyEnhancements.GetSupplyChains()
	if not SupplyChainNetwork then return {} end
	return SupplyChainNetwork.GetSupplyChains()
end

function EconomyEnhancements.GetChainOpportunities()
	if not SupplyChainNetwork then return {} end
	return SupplyChainNetwork.GetChainOpportunities()
end

function EconomyEnhancements.GetChainEfficiency(system_path)
	if not SupplyChainNetwork then return {} end
	return SupplyChainNetwork.GetChainEfficiency(system_path)
end

function EconomyEnhancements.GetCommodityBonus(commodity_name)
	if not SupplyChainNetwork then return 1.0 end
	return SupplyChainNetwork.GetCommodityBonus(commodity_name)
end

function EconomyEnhancements.GetChainProgress()
	if not SupplyChainNetwork then return {} end
	return SupplyChainNetwork.GetChainProgress()
end

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

Serializer:Register("EconomyEnhancements",
	function()
		return {
			enabled = module_enabled,
			version = module_version,
		}
	end,
	function(data)
		if not data then return end
		module_enabled = data.enabled ~= false
	end
)

-- ============================================================================
-- EVENT COORDINATION
-- ============================================================================

Event.Register("onGameStart", function()
	LoadSubmodules()
end)

return EconomyEnhancements
