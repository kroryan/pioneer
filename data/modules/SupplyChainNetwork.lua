-- Copyright © 2008-2026 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

--
-- Module: SupplyChainNetwork
--
-- Tracks player trading along multi-level supply chains using real
-- commodity names. Compares cargo on dock vs undock to detect trades.
-- Completed chain nodes earn cumulative price bonuses.
-- Shows chain progress and opportunities on the BulletinBoard.
--

local Engine      = require 'Engine'
local Event       = require 'Event'
local Game        = require 'Game'
local Timer       = require 'Timer'
local Serializer  = require 'Serializer'
local Commodities = require 'Commodities'
local Economy     = require 'Economy'

---@class SupplyChainNetwork
local SupplyChainNetwork = {}

-- ============================================================================
-- SUPPLY CHAIN DEFINITIONS (real commodity names)
-- ============================================================================

local SupplyChains = {
	MINING_TO_SPACECRAFT = {
		name = "Mining to Manufacturing",
		description = "Metal Ore -> Metal Alloys -> Industrial Machinery -> Robots",
		nodes = {
			{ stage = 1, commodity = "metal_ore",            desc = "Metal Ore Extraction" },
			{ stage = 2, commodity = "metal_alloys",         desc = "Metal Refining" },
			{ stage = 3, commodity = "industrial_machinery", desc = "Heavy Manufacturing" },
			{ stage = 4, commodity = "robots",               desc = "Robotics Assembly" },
		},
		base_bonus = 0.15,
		per_node_bonus = 0.08,
	},
	AGRICULTURE_TO_LUXURY = {
		name = "Agriculture to Luxury",
		description = "Grain -> Animal Meat -> Liquor -> Consumer Goods",
		nodes = {
			{ stage = 1, commodity = "grain",           desc = "Grain Farming" },
			{ stage = 2, commodity = "animal_meat",     desc = "Livestock Processing" },
			{ stage = 3, commodity = "liquor",          desc = "Distillery" },
			{ stage = 4, commodity = "consumer_goods",  desc = "Luxury Production" },
		},
		base_bonus = 0.12,
		per_node_bonus = 0.06,
	},
	ELECTRONICS_PRODUCTION = {
		name = "Electronics Production",
		description = "Metal Alloys -> Plastics -> Computers -> Robots",
		nodes = {
			{ stage = 1, commodity = "metal_alloys", desc = "Raw Materials" },
			{ stage = 2, commodity = "plastics",     desc = "Component Fabrication" },
			{ stage = 3, commodity = "computers",    desc = "Computer Assembly" },
			{ stage = 4, commodity = "robots",        desc = "Advanced Systems" },
		},
		base_bonus = 0.18,
		per_node_bonus = 0.09,
	},
	MEDICAL_SUPPLY = {
		name = "Medical Supply Chain",
		description = "Chemicals -> Medicines -> Air Processors -> Fertilizer",
		nodes = {
			{ stage = 1, commodity = "chemicals",       desc = "Chemical Production" },
			{ stage = 2, commodity = "medicines",       desc = "Pharmaceuticals" },
			{ stage = 3, commodity = "air_processors",  desc = "Life Support Systems" },
			{ stage = 4, commodity = "fertilizer",      desc = "Biotech Applications" },
		},
		base_bonus = 0.14,
		per_node_bonus = 0.07,
	},
	INDUSTRIAL_BASE = {
		name = "Industrial Base",
		description = "Carbon Ore -> Plastics -> Industrial Machinery -> Mining Machinery",
		nodes = {
			{ stage = 1, commodity = "carbon_ore",           desc = "Carbon Mining" },
			{ stage = 2, commodity = "plastics",             desc = "Polymer Production" },
			{ stage = 3, commodity = "industrial_machinery", desc = "Machine Tools" },
			{ stage = 4, commodity = "mining_machinery",     desc = "Mining Equipment" },
		},
		base_bonus = 0.16,
		per_node_bonus = 0.08,
	},
}

-- Maximum bonus from chains (50% cap)
local MAX_CHAIN_BONUS = 0.50

-- ============================================================================
-- STATE
-- ============================================================================

-- Player cargo snapshot taken on dock
local cargo_on_dock = {}

-- Chain progress: {chain_key -> {commodity_name -> total_tonnes_traded}}
local chain_progress = {}

-- Chain completion bonuses earned: {chain_key -> bonus_multiplier}
local chain_bonuses = {}

-- BB advert refs
local bb_ads = {}

-- ============================================================================
-- CARGO SNAPSHOT (detect what player bought/sold)
-- ============================================================================

local function SnapshotPlayerCargo()
	cargo_on_dock = {}
	local player = Game.player
	if not player then return end

	local ok, cargoMgr = pcall(function() return player:GetComponent('CargoManager') end)
	if not ok or not cargoMgr then return end

	for name, commodity in pairs(Commodities) do
		local count_ok, count = pcall(function() return cargoMgr:CountCommodity(commodity) end)
		if count_ok and count then
			cargo_on_dock[name] = count
		end
	end
end

local function DetectTrades(station)
	local player = Game.player
	if not player then return end

	local ok, cargoMgr = pcall(function() return player:GetComponent('CargoManager') end)
	if not ok or not cargoMgr then return end

	for name, commodity in pairs(Commodities) do
		local count_ok, current = pcall(function() return cargoMgr:CountCommodity(commodity) end)
		if not count_ok then current = 0 end

		local previous = cargo_on_dock[name] or 0
		local diff = (current or 0) - previous

		-- Player BOUGHT if current > previous, SOLD if current < previous
		local traded = math.abs(diff)
		if traded > 0 then
			RecordChainTrade(name, traded)
		end
	end
end

-- ============================================================================
-- CHAIN TRACKING
-- ============================================================================

function RecordChainTrade(commodity_name, amount)
	for chain_key, chain in pairs(SupplyChains) do
		for _, node in ipairs(chain.nodes) do
			if node.commodity == commodity_name then
				if not chain_progress[chain_key] then
					chain_progress[chain_key] = {}
				end
				chain_progress[chain_key][commodity_name] =
					(chain_progress[chain_key][commodity_name] or 0) + amount

				-- Recalculate bonus for this chain
				UpdateChainBonus(chain_key)
				break
			end
		end
	end
end

function UpdateChainBonus(chain_key)
	local chain = SupplyChains[chain_key]
	if not chain then return end

	local progress = chain_progress[chain_key] or {}
	local nodes_active = 0

	for _, node in ipairs(chain.nodes) do
		local traded = progress[node.commodity] or 0
		-- Need at least 10 tonnes traded to count as "active" node
		if traded >= 10 then
			nodes_active = nodes_active + 1
		end
	end

	local total_nodes = #chain.nodes
	if nodes_active == 0 then
		chain_bonuses[chain_key] = 0
		return
	end

	-- Bonus scales with completion: partial chains give partial bonus
	local completion = nodes_active / total_nodes
	local bonus = chain.base_bonus * completion + chain.per_node_bonus * nodes_active

	chain_bonuses[chain_key] = math.min(bonus, MAX_CHAIN_BONUS)
end

-- ============================================================================
-- PRICE BONUS APPLICATION
-- ============================================================================

-- Get the total chain bonus for a specific commodity
local function GetCommodityChainBonus(commodity_name)
	local max_bonus = 0

	for chain_key, chain in pairs(SupplyChains) do
		for _, node in ipairs(chain.nodes) do
			if node.commodity == commodity_name then
				local bonus = chain_bonuses[chain_key] or 0
				if bonus > max_bonus then
					max_bonus = bonus
				end
			end
		end
	end

	return 1.0 + max_bonus
end

-- ============================================================================
-- BULLETIN BOARD INTEGRATION
-- ============================================================================

local function GetChainStatus(chain_key)
	local chain = SupplyChains[chain_key]
	if not chain then return nil end

	local progress = chain_progress[chain_key] or {}
	local nodes_status = {}
	local active_count = 0

	for _, node in ipairs(chain.nodes) do
		local traded = progress[node.commodity] or 0
		local is_active = traded >= 10
		if is_active then active_count = active_count + 1 end
		table.insert(nodes_status, {
			desc = node.desc,
			commodity = node.commodity,
			traded = traded,
			active = is_active,
		})
	end

	return {
		name = chain.name,
		description = chain.description,
		nodes = nodes_status,
		active_count = active_count,
		total_nodes = #chain.nodes,
		bonus = chain_bonuses[chain_key] or 0,
	}
end

local function AddChainAdverts(station)
	-- Show a "Supply Chain Opportunities" advert
	local any_progress = false
	for _, bonus in pairs(chain_bonuses) do
		if bonus > 0 then any_progress = true; break end
	end

	local desc = any_progress
		and "View your supply chain progress and trading bonuses"
		or "Learn about profitable multi-commodity supply chains"

	local ref = station:AddAdvert({
		title = "Supply Chain Trading Network",
		description = desc,
		icon = "trade",
		onChat = function(form, ref, option)
			form:Clear()
			form:SetTitle("Supply Chain Trading Network")

			local msg = "Complete multi-step supply chains to earn cumulative trading bonuses.\n"
			msg = msg .. "Trade at least 10 tonnes of each commodity in a chain to activate that node.\n\n"

			for chain_key, chain in pairs(SupplyChains) do
				local status = GetChainStatus(chain_key)
				if status then
					local pct = math.floor(status.active_count / status.total_nodes * 100)
					local bonus_pct = math.floor(status.bonus * 100)
					msg = msg .. string.format("--- %s [%d%% | +%d%% bonus] ---\n", status.name, pct, bonus_pct)
					msg = msg .. status.description .. "\n"

					for _, ns in ipairs(status.nodes) do
						local c = Commodities[ns.commodity]
						local cname = c and c:GetName() or ns.commodity
						local mark = ns.active and "[OK]" or "[  ]"
						msg = msg .. string.format("  %s %s: %s (%d t traded)\n",
							mark, ns.desc, cname, ns.traded)
					end
					msg = msg .. "\n"
				end
			end

			form:SetMessage(msg)
		end,
		onDelete = function(ref)
			bb_ads[ref] = nil
		end,
	})
	if ref then
		bb_ads[ref] = { station = station }
	end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

Event.Register("onPlayerDocked", function(player, station)
	SnapshotPlayerCargo()
end)

Event.Register("onPlayerUndocked", function(player, station)
	DetectTrades(station)
end)

Event.Register("onCreateBB", function(station)
	AddChainAdverts(station)
end)

Event.Register("onGameStart", function()
	chain_progress = chain_progress or {}
	chain_bonuses = chain_bonuses or {}
	cargo_on_dock = {}
	bb_ads = {}

	-- Recalculate all bonuses from progress
	for chain_key, _ in pairs(SupplyChains) do
		UpdateChainBonus(chain_key)
	end
end)

Event.Register("onGameEnd", function()
	chain_progress = {}
	chain_bonuses = {}
	cargo_on_dock = {}
	bb_ads = {}
end)

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

Serializer:Register("SupplyChainNetwork",
	function()
		return {
			progress = chain_progress,
			bonuses = chain_bonuses,
		}
	end,
	function(data)
		if not data then return end
		chain_progress = data.progress or {}
		chain_bonuses = data.bonuses or {}
	end
)

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function SupplyChainNetwork.GetSupplyChains()
	local result = {}
	for key, chain in pairs(SupplyChains) do
		table.insert(result, {
			key = key,
			name = chain.name,
			description = chain.description,
			nodes = chain.nodes,
			base_bonus = chain.base_bonus,
			per_node_bonus = chain.per_node_bonus,
		})
	end
	return result
end

function SupplyChainNetwork.GetChainOpportunities()
	local opps = {}
	for chain_key, chain in pairs(SupplyChains) do
		local status = GetChainStatus(chain_key)
		if status then
			table.insert(opps, {
				chain = status.name,
				chain_key = chain_key,
				completion_percent = math.floor(status.active_count / status.total_nodes * 100),
				bonus_potential = chain.base_bonus + chain.per_node_bonus * status.total_nodes,
				current_bonus = status.bonus,
				active_nodes = status.active_count,
				total_nodes = status.total_nodes,
			})
		end
	end
	table.sort(opps, function(a, b) return a.bonus_potential > b.bonus_potential end)
	return opps
end

function SupplyChainNetwork.GetChainEfficiency(system_path)
	-- Return bonuses relevant to any system
	return chain_bonuses
end

function SupplyChainNetwork.GetCommodityBonus(commodity_name)
	return GetCommodityChainBonus(commodity_name)
end

function SupplyChainNetwork.GetRouteStatistics()
	local active = 0
	local total_bonus = 0
	for _, bonus in pairs(chain_bonuses) do
		if bonus > 0 then active = active + 1 end
		total_bonus = total_bonus + bonus
	end
	return {
		active_routes = active,
		total_deliveries = 0,
		total_profit = math.floor(total_bonus * 100),
	}
end

function SupplyChainNetwork.GetChainProgress()
	return chain_progress
end

return SupplyChainNetwork
