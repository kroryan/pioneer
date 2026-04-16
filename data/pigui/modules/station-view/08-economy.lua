-- Economy Enhancement Suite - Station View Tab
-- Visible tab when docked at any station - shows economy data, active missions, events
-- by kroryan - GPL-3.0

local ui = require 'pigui'
local StationView = require 'pigui.views.station-view'
local Game = require 'Game'
local Format = require 'Format'
local PlayerState = require 'PlayerState'

local textTable = require 'pigui.libs.text-table'

local pionillium = ui.fonts.pionillium
local orbiteer = ui.fonts.orbiteer
local colors = ui.theme.colors
local icons = ui.theme.icons
local Vector2 = _G.Vector2

local itemSpacing = ui.rescaleUI(Vector2(6, 12), Vector2(1600, 900))

-- Lazy-load module references
local modules = {}
local function getModule(name)
	if not modules[name] then
		local ok, mod = pcall(require, 'modules.' .. name)
		if ok and mod then modules[name] = mod end
	end
	return modules[name]
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

local function drawEconomy()
	local contentRegion = ui.getContentRegion()
	local colWidth = contentRegion.x * 0.5 - 8

	ui.child("EconLeft", Vector2(colWidth, 0), function()

		-- === ECONOMY STATUS ===
		drawSection("ECONOMY STATUS", function()
			local EE = getModule('EconomyEnhancements')
			if EE then
				local version = "?"
				pcall(function() version = EE.GetVersion() end)
				local enabled = false
				pcall(function() enabled = EE.IsEnabled() end)

				textTable.drawTable(2, nil, {
					separated = true,
					{ "Module", "Status", font = orbiteer.body },
					{ "Economy Suite v" .. tostring(version), enabled and "ACTIVE" or "INACTIVE" },
					{ "Credits", ui.Format.Money(PlayerState.GetMoney(), false) },
				})
			else
				ui.text("Economy Enhancement Suite not loaded.")
			end
		end)

		-- === SYSTEM EVENTS ===
		drawSection("SYSTEM EVENTS", function()
			local EE = getModule('EconomyEnhancements')
			if not EE then ui.text("Module not loaded."); return end

			local ok, events = pcall(function() return EE.GetSystemEvents() end)
			if not ok or not events then ui.text("No data available."); return end

			local eventCount = 0
			local rows = {
				separated = true,
				{ "Event", "Severity", "Effect", font = orbiteer.body },
			}
			for _, evt in pairs(events) do
				eventCount = eventCount + 1
				local name = evt.event_type or evt.type or "Unknown"
				local severity = evt.severity and string.format("%.0f%%", evt.severity * 100) or "?"
				local desc = ""
				pcall(function() desc = EE.GetSystemEventDescription(evt) end)
				table.insert(rows, { name, severity, desc })
			end

			if eventCount > 0 then
				ui.withStyleVars({ItemSpacing = itemSpacing}, function()
					textTable.drawTable(3, nil, rows)
				end)
			else
				ui.text("No active events in this system.")
				ui.spacing()
				ui.textColored(colors.lightGrey or colors.white,
					"Events spawn based on system conditions (lawlessness, population).")
			end
		end)

		-- === SUPPLY CHAINS ===
		drawSection("SUPPLY CHAIN NETWORK", function()
			local EE = getModule('EconomyEnhancements')
			if not EE then ui.text("Module not loaded."); return end

			local ok, opps = pcall(function() return EE.GetChainOpportunities() end)
			if not ok or not opps then ui.text("No data."); return end

			if #opps > 0 then
				local rows = {
					separated = true,
					{ "Chain", "Progress", "Bonus", font = orbiteer.body },
				}
				for _, o in ipairs(opps) do
					local chain = o.chain or "?"
					local pct = string.format("%d%%", o.completion_percent or 0)
					local bonus = string.format("+%.0f%%", (o.current_bonus or 0) * 100)
					table.insert(rows, { chain, pct, bonus })
				end
				ui.withStyleVars({ItemSpacing = itemSpacing}, function()
					textTable.drawTable(3, nil, rows)
				end)
			else
				ui.text("No chain progress yet.")
				ui.spacing()
				ui.textColored(colors.lightGrey or colors.white,
					"Trade 10+ tonnes along a supply chain to activate bonuses.")
			end
		end)

		-- === NPC TRADE IMPACT ===
		drawSection("NPC TRADE IMPACT", function()
			local EE = getModule('EconomyEnhancements')
			if not EE then ui.text("Module not loaded."); return end

			local ok, ts = pcall(function() return EE.GetNPCTradeStatus() end)
			if ok and ts then
				local destroyed = ts.ships_destroyed or ts.destroyed_shipments or 0
				local cargo = ts.total_cargo_lost or 0
				local value = ts.total_value_lost or ts.total_value or 0
				textTable.drawTable(2, nil, {
					separated = true,
					{ "Metric", "Value", font = orbiteer.body },
					{ "Ships Destroyed", tostring(destroyed) },
					{ "Cargo Lost", tostring(cargo) .. " t" },
					{ "Value Lost", ui.Format.Money(value, false) },
				})
			else
				ui.text("No trade disruption data.")
			end
		end)

		-- === NEWS ===
		local NF = getModule('SystemNewsFeed')
		if NF then
			drawSection("GALNET NEWS", function()
				local ok, news = pcall(function() return NF.GetCurrentNews() end)
				if ok and news and #news > 0 then
					for i, article in ipairs(news) do
						if i <= 4 then
							ui.withFont(pionillium.body, function()
								ui.textColored(colors.alertYellow or colors.white,
									(article.title or "Unknown Article"))
								ui.textWrapped(article.body or "")
								ui.spacing()
							end)
						end
					end
				else
					ui.text("No news articles for this system.")
				end
			end)
		end

	end)

	ui.sameLine(0, 16)

	ui.child("EconRight", Vector2(colWidth, 0), function()

		-- === EXPLORATION ===
		drawSection("EXPLORATION", function()
			local ER = getModule('ExplorationRewards')
			if ER then
				local explored = 0
				pcall(function() explored = ER.GetExploredCount() or 0 end)
				local unsold = 0
				pcall(function() unsold = ER.GetUnsoldDataCount() or 0 end)

				textTable.drawTable(2, nil, {
					separated = true,
					{ "Stat", "Value", font = orbiteer.body },
					{ "Systems Explored", tostring(explored) },
					{ "Unsold Scan Data", tostring(unsold) },
				})

				if unsold > 0 then
					ui.spacing()
					ui.textColored(colors.alertYellow or colors.white,
						"Sell scan data at the Bulletin Board: EXPLORERS' GUILD")
				end
			else
				ui.text("ExplorationRewards not loaded.")
			end
		end)

		-- === ACTIVE BOUNTIES ===
		drawSection("BOUNTY BOARD", function()
			local BB = getModule('BountyBoard')
			if BB then
				local ok, bounties = pcall(function() return BB.GetActiveBounties() end)
				if ok and bounties and #bounties > 0 then
					local rows = {
						separated = true,
						{ "Target", "Reward", "Status", font = orbiteer.body },
					}
					for _, b in ipairs(bounties) do
						local status = b.complete and "ELIMINATED" or "HUNTING"
						table.insert(rows, {
							b.target or "?",
							ui.Format.Money(b.reward or 0, false),
							status
						})
					end
					ui.withStyleVars({ItemSpacing = itemSpacing}, function()
						textTable.drawTable(3, nil, rows)
					end)
				else
					ui.text("No active bounties.")
					ui.spacing()
					ui.textColored(colors.lightGrey or colors.white,
						"Check Bulletin Board for bounty contracts (needs rep >= 4).")
				end
			else
				ui.text("BountyBoard not loaded.")
			end
		end)

		-- === SMUGGLING ===
		drawSection("SMUGGLING CONTRACTS", function()
			local SC = getModule('SmugglingContracts')
			if SC then
				local ok, contracts = pcall(function() return SC.GetActiveContracts() end)
				if ok and contracts and #contracts > 0 then
					local rows = {
						separated = true,
						{ "Cargo", "Destination", "Reward", font = orbiteer.body },
					}
					for _, c in ipairs(contracts) do
						table.insert(rows, {
							string.format("%dt %s", c.amount or 0, c.commodity or "?"),
							c.destination or "?",
							ui.Format.Money(c.reward or 0, false),
						})
					end
					ui.withStyleVars({ItemSpacing = itemSpacing}, function()
						textTable.drawTable(3, nil, rows)
					end)
				else
					ui.text("No active smuggling runs.")
					local lawless = 0
					pcall(function() lawless = Game.system.lawlessness or 0 end)
					if lawless < 0.15 then
						ui.spacing()
						ui.textColored(colors.lightGrey or colors.white,
							"This system is too lawful for smuggling (need >15% lawlessness).")
					end
				end
			else
				ui.text("SmugglingContracts not loaded.")
			end
		end)

		-- === PASSENGERS ===
		drawSection("PASSENGER TRANSPORT", function()
			local PM = getModule('PassengerMissions')
			if PM then
				local ok, transports = pcall(function() return PM.GetActiveTransports() end)
				if ok and transports and #transports > 0 then
					local rows = {
						separated = true,
						{ "Type", "Pax", "Dest", "Reward", font = orbiteer.body },
					}
					for _, t in ipairs(transports) do
						table.insert(rows, {
							t.type or "?",
							tostring(t.passengers or 0),
							t.destination or "?",
							ui.Format.Money(t.reward or 0, false),
						})
					end
					ui.withStyleVars({ItemSpacing = itemSpacing}, function()
						textTable.drawTable(4, nil, rows)
					end)
				else
					ui.text("No active passenger jobs.")
					ui.spacing()
					ui.textColored(colors.lightGrey or colors.white,
						"Check Bulletin Board for passenger transport contracts.")
				end
			else
				ui.text("PassengerMissions not loaded.")
			end
		end)

		-- === STATION SERVICES ===
		drawSection("SHIP SERVICES", function()
			local SS = getModule('StationServices')
			if SS then
				local ok, effects = pcall(function() return SS.GetActiveEffects() end)
				local hasEffects = false
				if ok and effects then
					local rows = {
						separated = true,
						{ "Service", "Uses Left", font = orbiteer.body },
					}
					for effect, info in pairs(effects) do
						hasEffects = true
						table.insert(rows, {
							effect:gsub("_", " "):upper(),
							tostring(info.remaining or 0),
						})
					end
					if hasEffects then
						ui.withStyleVars({ItemSpacing = itemSpacing}, function()
							textTable.drawTable(2, nil, rows)
						end)
					end
				end

				if not hasEffects then
					ui.text("No active services.")
					ui.spacing()
					ui.textColored(colors.lightGrey or colors.white,
						"Check Bulletin Board for hull/engine/sensor upgrades.")
				end

				local ok2, used = pcall(function() return SS.GetServicesUsed() end)
				if ok2 and used and used > 0 then
					ui.spacing()
					ui.text("Total services purchased: " .. tostring(used))
				end
			else
				ui.text("StationServices not loaded.")
			end
		end)

		-- === CREW STATUS ===
		drawSection("CREW STATUS", function()
			local CI = getModule('CrewInteractions')
			local morale = 100
			local interactions = 0
			if CI then
				pcall(function() morale = CI.GetMorale() or 100 end)
				pcall(function() interactions = CI.GetInteractionCount() or 0 end)
			end

			local crewCount = 0
			pcall(function()
				Game.player:EachCrewMember(function(m)
					if m and not m.player then crewCount = crewCount + 1 end
				end)
			end)

			textTable.drawTable(2, nil, {
				separated = true,
				{ "Stat", "Value", font = orbiteer.body },
				{ "Crew Members", tostring(crewCount) },
				{ "Morale", tostring(morale) .. "%" },
				{ "Interactions", tostring(interactions) },
			})
		end)

	end)
end

StationView:registerView({
	id = "economy",
	name = "Economy",
	icon = icons.money or icons.market or icons.star,
	showView = true,
	draw = function()
		ui.withFont(pionillium.body, function()
			drawEconomy()
		end)
	end,
	refresh = function()
		modules = {}
	end,
	debugReload = function()
		package.reimport()
	end
})
