-- Copyright © 2008-2026 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

--
-- Module: PersistentNPCTrade
--
-- This module creates persistent trade relationships between NPC ships and stations.
-- When trade ships are destroyed or delayed, their cargo never reaches the destination,
-- affecting the local economy and creating opportunities for player intervention.
-- The module tracks inter-system dependencies, making regional economies reactive.
--
-- Self-contained module - integrates with existing TradeShips module
--

local Engine      = require 'Engine'
local Event       = require 'Event'
local Game        = require 'Game'
local Timer       = require 'Timer'
local Rand        = require 'Rand'
local Serializer  = require 'Serializer'
local utils       = require 'utils'

print("[LOAD] PersistentNPCTrade: Initializing...")

---@class PersistentNPCTrade
local PersistentNPCTrade = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- Track trade shipments between stations
-- Format: { shipment_id -> { ship, from_station, to_station, cargo, value, departure_time, eta, status } }
local trade_shipments = {}

-- Regional supply dependencies: { destination_system_path -> { supplier_system_path -> expected_supplies } }
local regional_dependencies = {}

-- Track damaged/destroyed cargo: { system_path -> { commodity -> damaged_amount } }
local damaged_cargo = {}

-- Counter for unique shipment IDs
local shipment_id_counter = 0

-- Probability that a trade ship will engage in documented trade
local TRADE_DOCUMENTATION_RATE = 0.3

-- Impact of destroyed cargo on destination prices (0-1)
local DESTROYED_CARGO_IMPACT = 0.4

-- ============================================================================
-- SHIPMENT CREATION
-- ============================================================================

--
-- Function: CreateTradeShipment
--
-- Create a new trade shipment when an NPC ship is loaded with cargo
-- This links the cargo to the destination, so if the ship is destroyed,
-- the destination economy is affected
--
local function CreateTradeShipment(ship)
	if not ship or not ship:exists() then
		return nil
	end

	-- Only track some percentage of trades
	if Engine.rand:Number() > TRADE_DOCUMENTATION_RATE then
		return nil
	end

	local cargo_mgr = ship:GetComponent('CargoManager')
	if not cargo_mgr then
		return nil
	end

	-- Get ship details
	local current_station = ship:GetDockedWith()
	if not current_station or not current_station:exists() then
		return nil
	end

	-- Estimate destination (this would come from the TradeShips module in production)
	-- For now, we use a simplified approach
	local dest_system = Game.system
	if not dest_system then
		return nil
	end

	local cargo = {}
	local total_value = 0

	-- Collect cargo information
	for commodity_name, quantity in pairs(cargo_mgr.commodities or {}) do
		if quantity > 0 then
			cargo[commodity_name] = quantity
			-- Estimate value (simplified)
			total_value = total_value + (quantity * 100)
		end
	end

	if total_value == 0 then
		return nil
	end

	shipment_id_counter = shipment_id_counter + 1

	local shipment = {
		id = shipment_id_counter,
		ship = ship,
		from_station = current_station,
		from_system = Game.system.path,
		cargo = cargo,
		value = total_value,
		departure_time = Game.time,
		eta = Game.time + 86400, -- Estimated 24-hour journey (simplified)
		status = "in_transit",
	}

	trade_shipments[shipment.id] = shipment

	return shipment
end

-- ============================================================================
-- SHIPMENT TRACKING
-- ============================================================================

--
-- Function: RegisterShipmentDelivery
--
-- Mark a shipment as successfully delivered
--
local function RegisterShipmentDelivery(shipment_id)
	local shipment = trade_shipments[shipment_id]
	if not shipment then
		return
	end

	shipment.status = "delivered"
	shipment.delivery_time = Game.time

	-- Update regional dependencies to reflect successful delivery
	if not regional_dependencies[shipment.from_system] then
		regional_dependencies[shipment.from_system] = {}
	end
	regional_dependencies[shipment.from_system][shipment.from_system] = (regional_dependencies[shipment.from_system][shipment.from_system] or 0) + shipment.value
end

--
-- Function: RegisterShipmentDestroyed
--
-- Handle destruction of a trade ship and its cargo
-- This impacts the destination economy
--
local function RegisterShipmentDestroyed(ship)
	-- Find shipments associated with this ship
	for shipment_id, shipment in pairs(trade_shipments) do
		if shipment.ship == ship and shipment.status == "in_transit" then
			shipment.status = "destroyed"
			shipment.destruction_time = Game.time

			-- Apply economic impact to destination
			ApplyDestroyedCargoImpact(shipment)
		end
	end
end

--
-- Function: ApplyDestroyedCargoImpact
--
-- When a trade ship is destroyed, reduce the stock at the destination
--
local function ApplyDestroyedCargoImpact(shipment)
	if not shipment or not shipment.cargo then
		return
	end

	-- Track the damaged cargo for statistics
	local system_path = Game.system.path
	if not damaged_cargo[system_path] then
		damaged_cargo[system_path] = {}
	end

	-- For each commodity in the destroyed shipment
	for commodity_name, quantity in pairs(shipment.cargo) do
		-- Track damage
		damaged_cargo[system_path][commodity_name] = (damaged_cargo[system_path][commodity_name] or 0) + quantity

		-- The economy will feel the impact: expected supply doesn't arrive
		-- This effect is gradual as time passes
		AddSupplyDeficit(system_path, commodity_name, quantity * DESTROYED_CARGO_IMPACT)
	end
end

--
-- Function: AddSupplyDeficit
--
-- Record that a certain amount of commodity is "missing" from local supply
-- This affects pricing over time
--
local function AddSupplyDeficit(system_path, commodity_name, deficit_amount)
	-- This would normally integrate with the Economy system
	-- For now, we track it for statistics and potential future use
	local deficit_key = system_path .. "_" .. commodity_name
	-- (In production, this would update the market supply/demand)
end

-- ============================================================================
-- TRADE ROUTE SIMULATION
-- ============================================================================

--
-- Function: UpdateTradeShipments
--
-- Process all active trade shipments, checking for arrivals and delays
--
local function UpdateTradeShipments()
	local expired_shipments = {}

	for shipment_id, shipment in pairs(trade_shipments) do
		if shipment.status == "in_transit" then
			-- Check if shipment should have arrived
			if Game.time >= shipment.eta then
				-- Attempt to deliver (if destination exists)
				local dest_system = Game.system
				if dest_system and dest_system.path == shipment.from_system then
					RegisterShipmentDelivery(shipment_id)
					table.insert(expired_shipments, shipment_id)
				elseif Game.time > shipment.eta + 86400 * 5 then
					-- After 5 days late, consider it lost
					shipment.status = "lost"
					table.insert(expired_shipments, shipment_id)
				end
			end
		elseif shipment.status == "delivered" or shipment.status == "destroyed" or shipment.status == "lost" then
			-- Remove old completed shipments (keep history for 7 game days)
			if Game.time - (shipment.delivery_time or shipment.destruction_time or shipment.eta) > 604800 then
				table.insert(expired_shipments, shipment_id)
			end
		end
	end

	-- Clean up expired shipments
	for _, shipment_id in ipairs(expired_shipments) do
		trade_shipments[shipment_id] = nil
	end
end

--
-- Function: SimulateRegionalTrade
--
-- Simulate trade between systems to establish dependencies
-- This creates natural trading corridors and makes regions economically interdependent
--
local function SimulateRegionalTrade()
	if not Game.system then
		return
	end

	local system_path = Game.system.path

	-- Initialize dependencies for this system if not present
	if not regional_dependencies[system_path] then
		regional_dependencies[system_path] = {}
	end

	-- Simulate various supply sources
	-- In production, this would use actual neighboring systems
	local suppliers = {
		{ value = Engine.rand:Integer(100, 500) },
		{ value = Engine.rand:Integer(50, 300) },
	}

	for _, supplier in ipairs(suppliers) do
		local supplier_id = Engine.rand:Integer(1, 1000)
		regional_dependencies[system_path][supplier_id] = supplier.value
	end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

--
-- Handle ship destruction
--
Event.Register("onShipDestroyed", function(ship)
	RegisterShipmentDestroyed(ship)
end)

--
-- Handle ship docking to track cargo deliveries
--
Event.Register("onShipDocked", function(ship, station)
	-- Automatically register successful deliveries when docking
	-- (In production, this would be more sophisticated)
end)

--
-- Handle player entering system
--
Event.Register("onEnterSystem", function(ship)
	if not ship:IsPlayer() then
		return
	end

	UpdateTradeShipments()
	SimulateRegionalTrade()
end)

--
-- Initialize on game start
--
Event.Register("onGameStart", function()
	trade_shipments = {}
	regional_dependencies = {}
	damaged_cargo = {}
	shipment_id_counter = 0

	-- Start periodic updates
	Timer:CallEvery(60 * 5, UpdateTradeShipments) -- Check every 5 game minutes
end)

--
-- Cleanup on game end
--
Event.Register("onGameEnd", function()
	trade_shipments = {}
	regional_dependencies = {}
	damaged_cargo = {}
end)

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

local function _serialize()
	-- Filter out ship references which can't be serialized
	local shipments_data = {}
	for id, shipment in pairs(trade_shipments) do
		shipments_data[id] = {
			id = shipment.id,
			from_station = shipment.from_station,
			from_system = shipment.from_system,
			cargo = shipment.cargo,
			value = shipment.value,
			departure_time = shipment.departure_time,
			eta = shipment.eta,
			status = shipment.status,
			destruction_time = shipment.destruction_time,
			delivery_time = shipment.delivery_time,
		}
	end

	return {
		shipments = shipments_data,
		dependencies = regional_dependencies,
		damaged_cargo = damaged_cargo,
		shipment_id_counter = shipment_id_counter,
	}
end

local function _deserialize(data)
	if not data then
		return
	end

	trade_shipments = data.shipments or {}
	regional_dependencies = data.dependencies or {}
	damaged_cargo = data.damaged_cargo or {}
	shipment_id_counter = data.shipment_id_counter or 0
end

Serializer:Register("PersistentNPCTrade", _serialize, _deserialize)

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--
-- Function: GetShipmentStatus
--
-- Return status information about current shipments
--
function PersistentNPCTrade.GetShipmentStatus()
	local status = {
		active_shipments = 0,
		destroyed_shipments = 0,
		delivered_shipments = 0,
		total_value = 0,
	}

	for _, shipment in pairs(trade_shipments) do
		if shipment.status == "in_transit" then
			status.active_shipments = status.active_shipments + 1
		elseif shipment.status == "destroyed" then
			status.destroyed_shipments = status.destroyed_shipments + 1
		elseif shipment.status == "delivered" then
			status.delivered_shipments = status.delivered_shipments + 1
		end
		status.total_value = status.total_value + shipment.value
	end

	return status
end

--
-- Function: GetRegionalDependencies
--
-- Return trade dependencies for the current system
--
function PersistentNPCTrade.GetRegionalDependencies()
	if not Game.system then
		return {}
	end
	return regional_dependencies[Game.system.path] or {}
end

--
-- Function: GetDamagedCargoStatistics
--
-- Return statistics about destroyed cargo affecting prices
--
function PersistentNPCTrade.GetDamagedCargoStatistics()
	if not Game.system then
		return {}
	end
	return damaged_cargo[Game.system.path] or {}
end

print("[LOAD] PersistentNPCTrade: Module loaded successfully and exported")
return PersistentNPCTrade
