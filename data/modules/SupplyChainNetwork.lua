-- Copyright © 2008-2026 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

--
-- Module: SupplyChainNetwork
--
-- This module defines complex, multi-level supply chains that create profitable
-- long-distance trading opportunities. By connecting different nodes of a supply chain
-- (mining -> refining -> manufacturing -> finished goods), players can unlock
-- bonuses and special trading opportunities.
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

print("[LOAD] SupplyChainNetwork: Initializing...")

---@class SupplyChainNetwork
local SupplyChainNetwork = {}

-- ============================================================================
-- SUPPLY CHAIN DEFINITIONS
-- ============================================================================

-- Define multi-level supply chains
-- Each chain has nodes (stages) that must be connected to unlock bonuses
local SupplyChains = {
	MINING_TO_SPACECRAFT = {
		name = "Mining to Spacecraft",
		description = "Raw ore → Metal → Components → Spacecraft parts",
		nodes = {
			{ stage = 1, commodity = "metal_ore", desc = "Metal Ore Extraction" },
			{ stage = 2, commodity = "metals", desc = "Refined Metals" },
			{ stage = 3, commodity = "industrial_machinery", desc = "Manufacturing" },
			{ stage = 4, commodity = "spacecraft_parts", desc = "Spacecraft Components" },
		},
		base_bonus = 1.15, -- 15% price bonus when complete
		chain_bonus = 0.08, -- 8% additional bonus per connected node
	},

	AGRICULTURE_TO_LUXURY = {
		name = "Agriculture to Luxury",
		description = "Raw food → Processed food → Beverages → Luxury goods",
		nodes = {
			{ stage = 1, commodity = "food", desc = "Raw Agricultural Products" },
			{ stage = 2, commodity = "food_products", desc = "Processed Food" },
			{ stage = 3, commodity = "drinks", desc = "Beverages" },
			{ stage = 4, commodity = "luxury_goods", desc = "Luxury Products" },
		},
		base_bonus = 1.12,
		chain_bonus = 0.06,
	},

	ELECTRONICS_PRODUCTION = {
		name = "Electronics Production",
		description = "Raw materials → Components → Electronics → Advanced Systems",
		nodes = {
			{ stage = 1, commodity = "metals", desc = "Refined Metals" },
			{ stage = 2, commodity = "electronics_components", desc = "Electronic Components" },
			{ stage = 3, commodity = "electronics", desc = "Electronic Goods" },
			{ stage = 4, commodity = "advanced_electronics", desc = "Advanced Electronics" },
		},
		base_bonus = 1.18,
		chain_bonus = 0.09,
	},

	MEDICAL_SUPPLY = {
		name = "Medical Supply Chain",
		description = "Chemicals → Medicines → Medical supplies → Advanced treatment",
		nodes = {
			{ stage = 1, commodity = "chemicals", desc = "Raw Chemicals" },
			{ stage = 2, commodity = "medicines", desc = "Pharmaceuticals" },
			{ stage = 3, commodity = "medical_supplies", desc = "Medical Equipment" },
			{ stage = 4, commodity = "vaccines", desc = "Advanced Vaccines" },
		},
		base_bonus = 1.14,
		chain_bonus = 0.07,
	},

	INDUSTRIAL_BASE = {
		name = "Industrial Base Development",
		description = "Minerals → Machinery → Industrial equipment → Factories",
		nodes = {
			{ stage = 1, commodity = "metal_ore", desc = "Mineral Extraction" },
			{ stage = 2, commodity = "industrial_machinery", desc = "Heavy Machinery" },
			{ stage = 3, commodity = "machinery", desc = "Manufacturing Equipment" },
			{ stage = 4, commodity = "construction_materials", desc = "Construction Materials" },
		},
		base_bonus = 1.16,
		chain_bonus = 0.08,
	},
}

local ChainList = utils.to_array(SupplyChains)

-- ============================================================================
-- STATE TRACKING
-- ============================================================================

-- Track player progress through supply chains
-- Format: { player -> { chain_name -> { system_path -> stage_reached } } }
local player_chain_progress = {}

-- Track active supply chain routes
-- Format: { route_id -> { chain, origin, destination, nodes_connected, value } }
local active_routes = {}

-- Track supply chain efficiency bonuses per system
-- Format: { system_path -> { chain_name -> efficiency_factor } }
local chain_efficiency = {}

-- Counter for route IDs
local route_id_counter = 0

-- Minimum distance for long-distance bonus (light-years)
local MIN_DISTANCE_FOR_BONUS = 5.0

-- ============================================================================
-- CHAIN ANALYSIS
-- ============================================================================

--
-- Function: AnalyzeSupplyChain
--
-- Analyze if a supply chain is partially or fully complete in a region
-- Returns the stage completion percentage
--
local function AnalyzeSupplyChain(chain_name, system_paths)
	if not system_paths or #system_paths == 0 then
		return 0
	end

	local chain = SupplyChains[chain_name]
	if not chain then
		return 0
	end

	local nodes_found = {}
	for _, node in ipairs(chain.nodes) do
		nodes_found[node.stage] = false
	end

	-- Check which nodes are available in the region
	for _, system_path in ipairs(system_paths) do
		local system = system_path:GetStarSystem()
		if system then
			-- In a real implementation, check station economies
			-- For now, simulate with randomness based on system characteristics
			for _, node in ipairs(chain.nodes) do
				if Engine.rand:Number() > 0.4 then
					nodes_found[node.stage] = true
				end
			end
		end
	end

	-- Count found nodes
	local found_count = 0
	for _, found in pairs(nodes_found) do
		if found then
			found_count = found_count + 1
		end
	end

	return found_count / #chain.nodes
end

--
-- Function: CalculateChainBonus
--
-- Calculate the trading bonus for a connected supply chain
--
local function CalculateChainBonus(chain_name, nodes_connected)
	local chain = SupplyChains[chain_name]
	if not chain then
		return 1.0
	end

	-- Base bonus
	local bonus = chain.base_bonus

	-- Additional bonus per connected node
	bonus = bonus + (nodes_connected * chain.chain_bonus)

	-- Cap the bonus at 50% markup
	return math.min(bonus, 1.5)
end

--
-- Function: FindChainOpportunities
--
-- Identify supply chain opportunities in the current region
-- Returns a list of partially-connected chains and recommended routes
--
local function FindChainOpportunities()
	if not Game.system then
		return {}
	end

	local opportunities = {}

	-- Analyze each supply chain
	for chain_name, chain_def in pairs(SupplyChains) do
		-- Get nearby systems (simplified - in production use actual neighbor calculation)
		local nearby_systems = { Game.system.path }
		-- (In production, add actual nearby systems)

		local completion = AnalyzeSupplyChain(chain_name, nearby_systems)
		if completion > 0 and completion < 1.0 then
			-- This chain is partially complete
			table.insert(opportunities, {
				chain = chain_name,
				completion_percent = completion * 100,
				bonus_potential = CalculateChainBonus(chain_name, math.ceil(completion * #chain_def.nodes)) - 1,
				description = chain_def.description,
			})
		end
	end

	-- Sort by profit potential
	table.sort(opportunities, function(a, b)
		return a.bonus_potential > b.bonus_potential
	end)

	return opportunities
end

-- ============================================================================
-- ROUTE CREATION
-- ============================================================================

--
-- Function: CreateSupplyChainRoute
--
-- Create a route connecting multiple nodes of a supply chain
--
local function CreateSupplyChainRoute(chain_name, origin_system, destination_system)
	local chain = SupplyChains[chain_name]
	if not chain then
		return nil
	end

	route_id_counter = route_id_counter + 1

	local route = {
		id = route_id_counter,
		chain = chain_name,
		origin = origin_system,
		destination = destination_system,
		created_time = Game.time,
		deliveries_completed = 0,
		total_profit = 0,
		status = "active",
	}

	active_routes[route.id] = route

	-- Record efficiency improvement for the chain in this system
	local dest_path = destination_system
	if not chain_efficiency[dest_path] then
		chain_efficiency[dest_path] = {}
	end
	chain_efficiency[dest_path][chain_name] = (chain_efficiency[dest_path][chain_name] or 1.0) + 0.02

	return route
end

--
-- Function: ProcessSupplyChainDelivery
--
-- Process a successful delivery along a supply chain route
-- Apply bonuses to prices and update chain efficiency
--
local function ProcessSupplyChainDelivery(route_id, profit)
	local route = active_routes[route_id]
	if not route then
		return
	end

	route.deliveries_completed = route.deliveries_completed + 1
	route.total_profit = route.total_profit + profit

	-- Improve chain efficiency in destination
	local chain = SupplyChains[route.chain]
	if chain then
		local efficiency_gain = (profit / 10000) * chain.chain_bonus -- Scale profit impact
		if not chain_efficiency[route.destination] then
			chain_efficiency[route.destination] = {}
		end
		chain_efficiency[route.destination][route.chain] = math.min(
			(chain_efficiency[route.destination][route.chain] or 1.0) + efficiency_gain,
			1.5 -- Cap at 50% bonus
		)
	end
end

--
-- Function: GetChainBonusForCommodity
--
-- Calculate if a commodity benefits from chain bonuses in the current system
-- Returns multiplier (1.0 = no bonus)
--
local function GetChainBonusForCommodity(commodity_name)
	if not Game.system then
		return 1.0
	end

	local system_path = Game.system.path
	if not chain_efficiency[system_path] then
		return 1.0
	end

	-- Check if this commodity is part of any active chain
	local max_bonus = 1.0
	for chain_name, efficiency in pairs(chain_efficiency[system_path]) do
		local chain = SupplyChains[chain_name]
		if chain then
			for _, node in ipairs(chain.nodes) do
				if node.commodity == commodity_name then
					max_bonus = math.max(max_bonus, efficiency)
				end
			end
		end
	end

	return max_bonus
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

--
-- Monitor player trades for supply chain progress
--
Event.Register("onShipDocked", function(ship, station)
	if not ship:IsPlayer() then
		return
	end

	if Game.system and station then
		-- Track which supply chains have nodes available at this station
		-- (In production, integrate with station economy data)
	end
end)

--
-- Initialize supply chain tracking
--
Event.Register("onGameStart", function()
	player_chain_progress = {}
	active_routes = {}
	chain_efficiency = {}
	route_id_counter = 0

	-- Periodic evaluation of supply chains
	Timer:CallEvery(120 * 60, function()
		local opportunities = FindChainOpportunities()
		-- (Would update UI or trigger events with opportunities)
	end)
end)

--
-- Clean up on system exit
--
Event.Register("onLeaveSystem", function(ship)
	if not ship:IsPlayer() then
		return
	end

	-- Optional: Update efficiency based on player activity
end)

Event.Register("onGameEnd", function()
	player_chain_progress = {}
	active_routes = {}
	chain_efficiency = {}
end)

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

local function _serialize()
	return {
		player_progress = player_chain_progress,
		active_routes = active_routes,
		chain_efficiency = chain_efficiency,
		route_id_counter = route_id_counter,
	}
end

local function _deserialize(data)
	if not data then
		return
	end

	player_chain_progress = data.player_progress or {}
	active_routes = data.active_routes or {}
	chain_efficiency = data.chain_efficiency or {}
	route_id_counter = data.route_id_counter or 0
end

Serializer:Register("SupplyChainNetwork", _serialize, _deserialize)

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--
-- Function: GetSupplyChains
--
-- Return all available supply chains
--
function SupplyChainNetwork.GetSupplyChains()
	-- Convert to array for easier iteration
	local chains_array = {}
	for chain_key, chain_data in pairs(SupplyChains) do
		table.insert(chains_array, chain_data)
	end
	return chains_array
end

--
-- Function: GetChainDescription
--
-- Return detailed information about a supply chain
--
function SupplyChainNetwork.GetChainDescription(chain_name)
	local chain = SupplyChains[chain_name]
	if not chain then
		return nil
	end

	return {
		name = chain.name,
		description = chain.description,
		nodes = chain.nodes,
		base_bonus = chain.base_bonus,
	}
end

--
-- Function: GetChainOpportunities
--
-- Return trading opportunities based on supply chains
--
function SupplyChainNetwork.GetChainOpportunities()
	return FindChainOpportunities()
end

--
-- Function: GetChainEfficiency
--
-- Return current chain efficiency in a system
--
function SupplyChainNetwork.GetChainEfficiency(system_path)
	if not system_path then
		if not Game.system then
			return {}
		end
		system_path = Game.system.path
	end
	return chain_efficiency[system_path] or {}
end

--
-- Function: CreateRoute
--
-- Create a new supply chain route for tracking
--
function SupplyChainNetwork.CreateRoute(chain_name, origin_system, destination_system)
	return CreateSupplyChainRoute(chain_name, origin_system, destination_system)
end

--
-- Function: RecordDelivery
--
-- Record a successful supply chain delivery with profit
--
function SupplyChainNetwork.RecordDelivery(route_id, profit)
	ProcessSupplyChainDelivery(route_id, profit)
end

--
-- Function: GetCommodityBonus
--
-- Get the price bonus multiplier for a commodity due to supply chain efficiency
--
function SupplyChainNetwork.GetCommodityBonus(commodity_name)
	return GetChainBonusForCommodity(commodity_name)
end

--
-- Function: GetRouteStatistics
--
-- Return statistics about active supply chain routes
--
function SupplyChainNetwork.GetRouteStatistics()
	local stats = {
		active_routes = 0,
		total_deliveries = 0,
		total_profit = 0,
	}

	for _, route in pairs(active_routes) do
		if route.status == "active" then
			stats.active_routes = stats.active_routes + 1
		end
		stats.total_deliveries = stats.total_deliveries + route.deliveries_completed
		stats.total_profit = stats.total_profit + route.total_profit
	end

	return stats
end

print("[LOAD] SupplyChainNetwork: Module loaded successfully and exported")
return SupplyChainNetwork
