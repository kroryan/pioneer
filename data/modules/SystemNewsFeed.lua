-- SystemNewsFeed.lua - Economy Enhancement Suite v2.0
-- Generates procedural news articles based on system properties and active events
-- by kroryan - GPL-3.0

local Engine = require 'Engine'
local Game = require 'Game'
local Event = require 'Event'
local Serializer = require 'Serializer'
local Character = require 'Character'
local NameGen = require 'NameGen'

local SystemNewsFeed = {}

-- News templates by category
local TEMPLATES = {
	lawless = {
		{ title = "SECURITY ALERT: Pirate Activity in {system}",
		  body = "Authorities warn of increased pirate activity in the {system} system. Traders advised to travel armed. Lawlessness index: {lawlessness}%." },
		{ title = "CRIME WAVE: {system} Under Siege",
		  body = "Local law enforcement in {system} reports a surge in criminal activity. {faction} officials urge citizens to remain vigilant." },
		{ title = "SMUGGLING RING Busted in {system}",
		  body = "A major smuggling operation was disrupted by {faction} security forces. {name}, alleged ringleader, remains at large." },
	},
	peaceful = {
		{ title = "{system}: Model of Stability",
		  body = "The {system} system continues to enjoy low crime rates under {faction} governance. Trade routes remain secure." },
		{ title = "TRADE FLOURISHES in {system}",
		  body = "Commerce in {system} reaches new heights as {faction} policies attract merchants from across the sector." },
	},
	populated = {
		{ title = "{system} Population Milestone",
		  body = "Census data confirms {system} has crossed a major population threshold. Demand for consumer goods and housing continues to rise." },
		{ title = "ECONOMIC REPORT: {system} Markets Strong",
		  body = "Analysts report robust economic activity in {system}. {faction} economic policies receive praise from merchant guilds." },
		{ title = "INFRASTRUCTURE: {system} Expands Station Capacity",
		  body = "New docking bays and cargo facilities under construction across {system} stations. Trade volume expected to increase." },
	},
	frontier = {
		{ title = "FRONTIER DISPATCH: {system}",
		  body = "Settlers in the sparsely populated {system} system face challenges of isolation. Supply shipments are critical for survival." },
		{ title = "EXPLORATION: New Survey of {system}",
		  body = "Independent surveyors complete new mapping of {system}. Mineral resources detected in several asteroid belts." },
	},
	-- Event-reactive news (when DynamicSystemEvents is active)
	civil_war = {
		{ title = "BREAKING: Civil War Erupts in {system}",
		  body = "Armed conflict has broken out between factions in {system}. Weapons and medical supplies in high demand. Civilian casualties reported." },
	},
	famine = {
		{ title = "HUMANITARIAN CRISIS: Famine in {system}",
		  body = "Food shortages reach critical levels in {system}. Aid organizations appeal for grain and agricultural supplies. Prices soaring." },
	},
	economic_boom = {
		{ title = "BOOM TIMES: {system} Economy Surges",
		  body = "Consumer spending in {system} hits record levels. Electronics, luxury goods, and robotics sectors see explosive growth." },
	},
	plague = {
		{ title = "HEALTH EMERGENCY: Plague Outbreak in {system}",
		  body = "Medical authorities in {system} declare health emergency. Medicines and chemical supplies urgently needed. Quarantine measures in effect." },
	},
	natural_disaster = {
		{ title = "DISASTER: {system} Hit by Catastrophe",
		  body = "A major natural disaster has struck settlements in {system}. Industrial machinery and construction materials desperately needed." },
	},
	pirate_raids = {
		{ title = "PIRATE RAIDS Terrorize {system}",
		  body = "Coordinated pirate attacks disrupt trade in {system}. Military fuel and weapons stockpiles being depleted by defense forces." },
	},
	mining_boom = {
		{ title = "MINING RUSH: {system} Ore Deposits Discovered",
		  body = "Major mineral deposits found in {system}. Miners flock to the system as ore and precious metals prices spike." },
	},
	tech_revolution = {
		{ title = "TECH REVOLUTION Transforms {system}",
		  body = "A wave of technological innovation sweeps {system}. Computer and robotics industries report unprecedented demand." },
	},
}

local FILLER_NEWS = {
	{ title = "SPORTS: Zero-G League Finals Approach",
	  body = "The annual Zero-G Sports League finals are approaching. Teams from across the sector prepare for the championship." },
	{ title = "CULTURE: New Holodrama Tops Charts",
	  body = "The latest holodrama production from {faction} studios has topped entertainment charts across multiple systems." },
	{ title = "SCIENCE: New Stellar Phenomenon Observed",
	  body = "Astronomers report an unusual stellar phenomenon in a nearby system. Research teams are being dispatched." },
	{ title = "COMMERCE: Interstellar Trade Index Up 3%",
	  body = "The quarterly Interstellar Trade Index shows a 3% increase. Analysts cite improved supply chain efficiency." },
	{ title = "WEATHER: Solar Flare Advisory",
	  body = "Solar monitoring stations issue flare advisory. Ships in transit advised to check shield integrity." },
}

-- State
local state = {
	current_news = {},      -- {title, body, timestamp}
	news_per_system = {},   -- {system_key = {news items}}
}

local news_ads = {}

local function systemKey(path)
	if not path then return nil end
	return string.format("%d,%d,%d:%d", path.sectorX, path.sectorY, path.sectorZ, path.systemIndex)
end

local function interpolate(text, vars)
	return (text:gsub("{(%w+)}", function(key) return vars[key] or key end))
end

local function generateNews()
	if not Game.system then return {} end

	local system = Game.system
	local sysName = system.name or "Unknown"
	local factionName = "Authorities"
	local ok, fac = pcall(function() return system.faction end)
	if ok and fac and fac.name then factionName = fac.name end

	local lawlessness = system.lawlessness or 0
	local population = system.population or 0

	local vars = {
		system = sysName,
		faction = factionName,
		name = NameGen.FullName(nil, Engine.rand),
		lawlessness = tostring(math.floor(lawlessness * 100)),
		population = tostring(math.floor(population * 100)),
	}

	local news = {}

	-- DynamicSystemEvents integration — react to live events
	local dseOk, DSE = pcall(require, 'modules.DynamicSystemEvents')
	if dseOk and DSE and DSE.GetSystemEvents then
		local ok, events = pcall(function() return DSE.GetSystemEvents() end)
		if ok and events then
			for _, evt in pairs(events) do
				local evtType = evt.type_key and evt.type_key:lower() or nil
				if evtType and TEMPLATES[evtType] then
					local templates = TEMPLATES[evtType]
					local t = templates[Engine.rand:Integer(1, #templates)]
					local remaining = math.max(0, (evt.end_time or 0) - (Game.time or 0))
					local hours = math.floor(remaining / 3600)
					local severity_pct = math.floor((evt.severity or 0) * 100)
					local evtVars = {}
					for k, v in pairs(vars) do evtVars[k] = v end
					evtVars.severity = tostring(severity_pct)
					evtVars.hours = tostring(hours)
					table.insert(news, {
						title = interpolate(t.title, evtVars),
						body = interpolate(t.body, evtVars) ..
							string.format(" (Severity: %d%%, %dh remaining)", severity_pct, hours),
						priority = 3,
					})
				end
			end
		end
	end

	-- PersistentNPCTrade integration — report trade disruptions
	local npcOk, NPC = pcall(require, 'modules.PersistentNPCTrade')
	if npcOk and NPC then
		local ok, status = pcall(function() return NPC.GetShipmentStatus() end)
		if ok and status and (status.destroyed_shipments or 0) > 0 then
			local ok2, deficits = pcall(function() return NPC.GetSupplyDeficits() end)
			local deficit_count = 0
			if ok2 and deficits then
				for _ in pairs(deficits) do deficit_count = deficit_count + 1 end
			end
			if deficit_count > 0 then
				table.insert(news, {
					title = interpolate("TRADE ALERT: Supply Disruption in {system}", vars),
					body = interpolate(string.format(
						"Trade routes in {system} have been affected by pirate activity. " ..
						"%d ships destroyed, %d tonnes of cargo lost. %d commodities currently in shortage. " ..
						"Traders who can supply affected goods may find premium prices.",
						status.destroyed_shipments or 0, status.total_cargo_lost or 0, deficit_count), vars),
					priority = 2,
				})
			end
		end
	end

	-- ExplorationRewards integration — report milestones
	local erOk, ER = pcall(require, 'modules.ExplorationRewards')
	if erOk and ER then
		local ok, count = pcall(function() return ER.GetExploredCount() end)
		if ok and count and count > 5 then
			table.insert(news, {
				title = interpolate("EXPLORATION: Independent Pilot Maps {explored} Systems", vars),
				body = string.format(
					"An independent pilot operating from %s has catalogued %d star systems. " ..
					"The Explorers' Guild commends this contribution to galactic navigation.",
					sysName, count),
				priority = 0,
			})
		end
	end

	-- BountyBoard integration — report bounty activity
	local bbOk, BB = pcall(require, 'modules.BountyBoard')
	if bbOk and BB then
		local ok, bounties = pcall(function() return BB.GetActiveBounties() end)
		if ok and bounties and #bounties > 0 then
			local completed = 0
			for _, b in ipairs(bounties) do
				if b.complete then completed = completed + 1 end
			end
			if completed > 0 then
				table.insert(news, {
					title = interpolate("SECURITY: Bounty Hunters Active in {system}", vars),
					body = string.format(
						"Bounty hunter activity in %s has resulted in %d confirmed eliminations. " ..
						"%d active contracts remain. Local security forces express gratitude.",
						sysName, completed, #bounties - completed),
					priority = 1,
				})
			end
		end
	end

	-- System-condition news
	if lawlessness > 0.6 then
		local templates = TEMPLATES.lawless
		local t = templates[Engine.rand:Integer(1, #templates)]
		table.insert(news, {
			title = interpolate(t.title, vars),
			body = interpolate(t.body, vars),
			priority = 1,
		})
	elseif lawlessness < 0.2 then
		local templates = TEMPLATES.peaceful
		local t = templates[Engine.rand:Integer(1, #templates)]
		table.insert(news, {
			title = interpolate(t.title, vars),
			body = interpolate(t.body, vars),
			priority = 0,
		})
	end

	if population > 0.5 then
		local templates = TEMPLATES.populated
		local t = templates[Engine.rand:Integer(1, #templates)]
		table.insert(news, {
			title = interpolate(t.title, vars),
			body = interpolate(t.body, vars),
			priority = 0,
		})
	elseif population < 0.1 and population > 0 then
		local templates = TEMPLATES.frontier
		local t = templates[Engine.rand:Integer(1, #templates)]
		table.insert(news, {
			title = interpolate(t.title, vars),
			body = interpolate(t.body, vars),
			priority = 0,
		})
	end

	-- Always add 1-2 filler news
	local numFiller = Engine.rand:Integer(1, 2)
	for i = 1, numFiller do
		local t = FILLER_NEWS[Engine.rand:Integer(1, #FILLER_NEWS)]
		table.insert(news, {
			title = interpolate(t.title, vars),
			body = interpolate(t.body, vars),
			priority = -1,
		})
	end

	-- Sort by priority (highest first)
	table.sort(news, function(a, b) return a.priority > b.priority end)

	-- Limit to 5 articles max
	while #news > 5 do table.remove(news) end

	return news
end

local function postNewsAdverts(station)
	-- Remove old news ads for this station
	for ref, ad in pairs(news_ads) do
		if ad.station == station then
			pcall(function() station:RemoveAdvert(ref) end)
			news_ads[ref] = nil
		end
	end

	local key = systemKey(Game.system and Game.system.path)
	if not key then return end

	-- Generate news if not already done for this system
	if not state.news_per_system[key] then
		state.news_per_system[key] = generateNews()
	end

	local news = state.news_per_system[key]
	if not news then return end

	for _, article in ipairs(news) do
		local client = Character.New({ title = "Reporter" })
		local ref = station:AddAdvert({
			title       = article.title,
			description = article.body,
			icon        = "message",
			onChat      = function(form, ref, option)
				form:Clear()
				form:SetFace(client)
				form:SetMessage(article.body .. "\n\n-- GalNet News Service --")
				if option == -1 then
					form:Close()
				end
			end,
			onDelete    = function(ref) news_ads[ref] = nil end,
		})
		if ref then
			news_ads[ref] = { station = station }
		end
	end
end

-- Events
Event.Register("onCreateBB", function(station)
	postNewsAdverts(station)
end)

Event.Register("onUpdateBB", function(station)
	-- Always refresh news when BB updates (events may have changed)
	local key = systemKey(Game.system and Game.system.path)
	if key then
		state.news_per_system[key] = nil
		postNewsAdverts(station)
	end
end)

Event.Register("onEnterSystem", function(ship)
	if not ship or not ship:isa("Ship") or not ship.IsPlayer or not ship:IsPlayer() then return end
	-- Clear cached news so it regenerates with current DSE events when BB opens
	local key = systemKey(Game.system and Game.system.path)
	if key then
		state.news_per_system[key] = nil
	end
end)

Event.Register("onGameEnd", function()
	state = { current_news = {}, news_per_system = {} }
	news_ads = {}
end)

-- Serialization
Serializer:Register("SystemNewsFeed",
	function()
		return { news_per_system = state.news_per_system }
	end,
	function(data)
		if data and data.news_per_system then
			state.news_per_system = data.news_per_system
		end
	end
)

-- Public API
SystemNewsFeed.GetCurrentNews = function()
	local key = systemKey(Game.system and Game.system.path)
	return key and state.news_per_system[key] or {}
end

print("[SystemNewsFeed] Module loaded - GalNet News Service active")

return SystemNewsFeed
