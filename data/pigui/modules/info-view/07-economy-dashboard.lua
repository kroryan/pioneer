-- Economy Dashboard - piGui InfoView tab
-- Shows Economy Enhancement Suite data: events, supply chains, exploration, bounties
-- by kroryan - GPL-3.0

local ui = require 'pigui'
local InfoView = require 'pigui.views.info-view'
local Game = require 'Game'
local PlayerState = require 'PlayerState'

local textTable = require 'pigui.libs.text-table'

local pionillium = ui.fonts.pionillium
local orbiteer = ui.fonts.orbiteer
local icons = ui.theme.icons
local colors = ui.theme.colors
local Vector2 = _G.Vector2

local itemSpacing = ui.rescaleUI(Vector2(6, 12), Vector2(1600, 900))

-- Lazy-load module references (they may not be loaded yet when this file is first required)
local modules = {}
local function getModule(name)
	if not modules[name] then
		local ok, mod = pcall(require, 'modules.' .. name)
		if ok and mod then modules[name] = mod end
	end
	return modules[name]
end

-- Cache
local cachedData = nil
local lastRefreshTime = 0

local function refreshData()
	if Game.time and Game.time == lastRefreshTime then return cachedData end
	lastRefreshTime = Game.time or 0

	local data = {
		-- Economy Enhancement Suite
		version = "?",
		enabled = false,
		system_events = {},
		supply_chains = {},
		npc_trade = {},

		-- New modules
		exploration = { explored = 0, unsold = 0 },
		bounties = {},
		smuggling = {},
		passengers = {},
		services = {},
		crew_morale = 100,
		news = {},
	}

	-- Economy Enhancements
	local EE = getModule('EconomyEnhancements')
	if EE then
		data.enabled = EE.IsEnabled and EE.IsEnabled() or false
		data.version = EE.GetVersion and EE.GetVersion() or "?"

		if EE.GetSystemEvents then
			local ok, events = pcall(EE.GetSystemEvents)
			if ok and events then data.system_events = events end
		end

		if EE.GetSupplyChains then
			local ok, chains = pcall(EE.GetSupplyChains)
			if ok and chains then data.supply_chains = chains end
		end

		if EE.GetNPCTradeStatus then
			local ok, status = pcall(EE.GetNPCTradeStatus)
			if ok and status then data.npc_trade = status end
		end
	end

	-- Exploration
	local ER = getModule('ExplorationRewards')
	if ER then
		data.exploration.explored = ER.GetExploredCount and ER.GetExploredCount() or 0
		data.exploration.unsold = ER.GetUnsoldDataCount and ER.GetUnsoldDataCount() or 0
	end

	-- Bounties
	local BB = getModule('BountyBoard')
	if BB and BB.GetActiveBounties then
		local ok, b = pcall(BB.GetActiveBounties)
		if ok and b then data.bounties = b end
	end

	-- Smuggling
	local SC = getModule('SmugglingContracts')
	if SC and SC.GetActiveContracts then
		local ok, c = pcall(SC.GetActiveContracts)
		if ok and c then data.smuggling = c end
	end

	-- Passengers
	local PM = getModule('PassengerMissions')
	if PM and PM.GetActiveTransports then
		local ok, t = pcall(PM.GetActiveTransports)
		if ok and t then data.passengers = t end
	end

	-- Station Services
	local SS = getModule('StationServices')
	if SS and SS.GetActiveEffects then
		local ok, e = pcall(SS.GetActiveEffects)
		if ok and e then data.services = e end
	end

	-- Crew
	local CI = getModule('CrewInteractions')
	if CI and CI.GetMorale then
		data.crew_morale = CI.GetMorale() or 100
	end

	-- News
	local NF = getModule('SystemNewsFeed')
	if NF and NF.GetCurrentNews then
		local ok, n = pcall(NF.GetCurrentNews)
		if ok and n then data.news = n end
	end

	cachedData = data
	return data
end

local function drawSection(title, drawFn)
	ui.withFont(orbiteer.heading, function()
		ui.text(title)
	end)
	ui.separator()
	ui.spacing()
	local ok, err = pcall(drawFn)
	if not ok then
		ui.textColored(colors.alertRed or colors.white, "Error: " .. tostring(err))
	end
	ui.newLine()
end

local function drawDashboard()
	local data = refreshData()
	if not data then
		ui.text("No data available.")
		return
	end

	local contentRegion = ui.getContentRegion()

	-- Two-column layout
	local leftWidth = contentRegion.x * 0.5 - 8
	local rightWidth = contentRegion.x * 0.5 - 8

	ui.child("DashLeft", Vector2(leftWidth, 0), function()

		-- ECONOMY STATUS
		drawSection("ECONOMY STATUS", function()
			local rows = {
				separated = false,
				{ "Module", "Status", font = orbiteer.body },
			}
			table.insert(rows, { "Economy Suite v" .. data.version, data.enabled and "ACTIVE" or "INACTIVE" })
			table.insert(rows, { "Credits", ui.Format.Money(PlayerState.GetMoney(), false) })

			local eventCount = 0
			if data.system_events then
				for _ in pairs(data.system_events) do eventCount = eventCount + 1 end
			end
			table.insert(rows, { "System Events", tostring(eventCount) .. " active" })

			local npcInfo = "Idle"
			if data.npc_trade and data.npc_trade.ships_destroyed then
				npcInfo = data.npc_trade.ships_destroyed .. " ships, " ..
					(data.npc_trade.total_cargo_lost or 0) .. "t cargo lost"
			end
			table.insert(rows, { "NPC Trade Impact", npcInfo })

			ui.withStyleVars({ItemSpacing = itemSpacing}, function()
				textTable.drawTable(2, nil, rows)
			end)
		end)

		-- SYSTEM EVENTS
		if data.system_events then
			local hasEvents = false
			for _ in pairs(data.system_events) do hasEvents = true; break end
			if hasEvents then
				drawSection("ACTIVE SYSTEM EVENTS", function()
					local rows = {
						separated = false,
						{ "Event", "Severity", font = orbiteer.body },
					}
					for _, evt in pairs(data.system_events) do
						local name = evt.type or "Unknown"
						local severity = evt.severity and string.format("%.0f%%", evt.severity * 100) or "?"
						table.insert(rows, { name, severity })
					end
					ui.withStyleVars({ItemSpacing = itemSpacing}, function()
						textTable.drawTable(2, nil, rows)
					end)
				end)
			end
		end

		-- SUPPLY CHAINS
		if data.supply_chains then
			local hasChains = false
			for _ in pairs(data.supply_chains) do hasChains = true; break end
			if hasChains then
				drawSection("SUPPLY CHAINS", function()
					local rows = {
						separated = false,
						{ "Chain", "Nodes", "Bonus", font = orbiteer.body },
					}
					for _, chain in ipairs(data.supply_chains) do
						local cname = chain.name or "?"
						local nodes = chain.nodes and #chain.nodes or (chain.commodities and #chain.commodities or 0)
						local bonus = chain.base_bonus and string.format("+%d%%", math.floor(chain.base_bonus * 100)) or "?"
						table.insert(rows, { cname, tostring(nodes), bonus })
					end
					ui.withStyleVars({ItemSpacing = itemSpacing}, function()
						textTable.drawTable(3, nil, rows)
					end)
				end)
			end
		end

		-- NEWS
		if #data.news > 0 then
			drawSection("GALNET NEWS", function()
				for i, article in ipairs(data.news) do
					if i <= 3 then
						ui.withFont(pionillium.body, function()
							ui.textColored(colors.alertYellow or colors.white, article.title or "")
							ui.textWrapped(article.body or "")
							ui.spacing()
						end)
					end
				end
			end)
		end
	end)

	ui.sameLine(0, 16)

	ui.child("DashRight", Vector2(rightWidth, 0), function()

		-- EXPLORATION
		drawSection("EXPLORATION", function()
			local rows = {
				separated = false,
				{ "Stat", "Value", font = orbiteer.body },
				{ "Systems Explored", tostring(data.exploration.explored) },
				{ "Unsold Data Sets", tostring(data.exploration.unsold) },
			}
			ui.withStyleVars({ItemSpacing = itemSpacing}, function()
				textTable.drawTable(2, nil, rows)
			end)
		end)

		-- ACTIVE BOUNTIES
		if #data.bounties > 0 then
			drawSection("ACTIVE BOUNTIES", function()
				local rows = {
					separated = false,
					{ "Target", "Reward", "Status", font = orbiteer.body },
				}
				for _, b in ipairs(data.bounties) do
					local status = b.complete and "ELIMINATED" or "HUNTING"
					table.insert(rows, { b.target or "?", ui.Format.Money(b.reward or 0, false), status })
				end
				ui.withStyleVars({ItemSpacing = itemSpacing}, function()
					textTable.drawTable(3, nil, rows)
				end)
			end)
		end

		-- SMUGGLING CONTRACTS
		if #data.smuggling > 0 then
			drawSection("SMUGGLING CONTRACTS", function()
				local rows = {
					separated = false,
					{ "Cargo", "Destination", "Reward", font = orbiteer.body },
				}
				for _, c in ipairs(data.smuggling) do
					local cargo = string.format("%dt %s", c.amount or 0, c.commodity or "?")
					table.insert(rows, { cargo, c.destination or "?", ui.Format.Money(c.reward or 0, false) })
				end
				ui.withStyleVars({ItemSpacing = itemSpacing}, function()
					textTable.drawTable(3, nil, rows)
				end)
			end)
		end

		-- PASSENGER TRANSPORT
		if #data.passengers > 0 then
			drawSection("PASSENGER TRANSPORT", function()
				local rows = {
					separated = false,
					{ "Type", "Pax", "Dest", "Reward", font = orbiteer.body },
				}
				for _, p in ipairs(data.passengers) do
					table.insert(rows, {
						p.type or "?",
						tostring(p.passengers or 0),
						p.destination or "?",
						ui.Format.Money(p.reward or 0, false),
					})
				end
				ui.withStyleVars({ItemSpacing = itemSpacing}, function()
					textTable.drawTable(4, nil, rows)
				end)
			end)
		end

		-- SHIP SERVICES
		local hasServices = false
		for _ in pairs(data.services) do hasServices = true; break end
		if hasServices then
			drawSection("ACTIVE SERVICES", function()
				local rows = {
					separated = false,
					{ "Service", "Remaining", font = orbiteer.body },
				}
				for effect, info in pairs(data.services) do
					local name = effect:gsub("_", " "):upper()
					table.insert(rows, { name, tostring(info.remaining or 0) .. " uses" })
				end
				ui.withStyleVars({ItemSpacing = itemSpacing}, function()
					textTable.drawTable(2, nil, rows)
				end)
			end)
		end

		-- CREW STATUS
		drawSection("CREW STATUS", function()
			ui.text("Morale: " .. tostring(data.crew_morale) .. "%")
			local crewCount = 0
			pcall(function()
				Game.player:EachCrewMember(function(m)
					if m and not m.player then crewCount = crewCount + 1 end
				end)
			end)
			ui.text("Crew members: " .. tostring(crewCount))
		end)
	end)
end

-- Register the InfoView tab
InfoView:registerView({
	id = "economyDashboard",
	name = "Economy",
	icon = icons.market or icons.money or icons.star,
	showView = true,
	draw = function()
		ui.withFont(pionillium.body, function()
			drawDashboard()
		end)
	end,
	refresh = function()
		cachedData = nil
		lastRefreshTime = 0
		modules = {}
	end,
	debugReload = function()
		package.reimport()
	end
})
