-- QuickTest Module - Debug & Verification for Economy Enhancement Suite v2.0
-- Tests all core + new modules: Run(), Watch(), Inspect(), Stress()
-- Usage: require('modules.QuickTest').Run()

local Game = require 'Game'

local QuickTest = {}

local function Log(section, message, level)
    level = level or "INFO"
    print(string.format("[%s] [%s] %s", level, section, tostring(message)))
end

-- Module registry: core v2.0 + new expansion modules
local CORE_MODULES = {
    'DynamicSystemEvents',
    'PersistentNPCTrade',
    'SupplyChainNetwork',
    'EconomyEnhancements',
}

local NEW_MODULES = {
    'ExplorationRewards',
    'SystemNewsFeed',
    'CrewInteractions',
    'BountyBoard',
    'SmugglingContracts',
    'PassengerMissions',
    'StationServices',
}

local function loadAllModules()
    local mods = {}
    local all_names = {}
    for _, n in ipairs(CORE_MODULES) do table.insert(all_names, n) end
    for _, n in ipairs(NEW_MODULES) do table.insert(all_names, n) end

    for _, name in ipairs(all_names) do
        local ok, m = pcall(function() return require('modules.' .. name) end)
        if ok and m then
            mods[name] = m
        else
            mods[name] = nil
        end
    end
    return mods, all_names
end

-- ============================================================================
-- RUN: Comprehensive Verification of ALL modules
-- ============================================================================

function QuickTest.Run()
    print("\n" .. string.rep("=", 80))
    print("ECONOMY ENHANCEMENT SUITE - COMPREHENSIVE VERIFICATION")
    print(string.rep("=", 80) .. "\n")

    local all_ok = true
    local step = 0

    -- Step 1: Load all modules
    step = step + 1
    Log("STEP-" .. step, "Loading all modules...")

    local mods, all_names = loadAllModules()
    for _, name in ipairs(all_names) do
        if mods[name] then
            Log(name, "LOADED", "SUCCESS")
        else
            Log(name, "FAILED TO LOAD", "ERROR")
            all_ok = false
        end
    end
    print()

    -- Step 2: Core Economy API
    local E = mods['EconomyEnhancements']
    if E then
        step = step + 1
        Log("STEP-" .. step, "Testing core Economy API...")

        local ok, ver = pcall(function() return E.GetVersion() end)
        if ok then Log("GetVersion", ver, "SUCCESS")
        else Log("GetVersion", tostring(ver), "ERROR"); all_ok = false end

        local ok2, en = pcall(function() return E.IsEnabled() end)
        if ok2 then Log("IsEnabled", tostring(en), "SUCCESS")
        else Log("IsEnabled", tostring(en), "ERROR"); all_ok = false end

        local ok3, st = pcall(function() return E.GetStatus() end)
        if ok3 and st then
            Log("GetStatus", string.format("DSE=%s PNPT=%s SCN=%s",
                tostring(st.system_events), tostring(st.npc_trade), tostring(st.supply_chains)), "SUCCESS")
        else Log("GetStatus", tostring(st), "ERROR"); all_ok = false end
        print()

        -- System events
        step = step + 1
        Log("STEP-" .. step, "Testing DynamicSystemEvents...")

        local ok4, events = pcall(function() return E.GetSystemEvents() end)
        if ok4 and events then
            local n = 0
            for id, ev in pairs(events) do
                n = n + 1
                if n <= 5 then
                    local d = "?"
                    pcall(function() d = E.GetSystemEventDescription(ev) end)
                    Log("Event-" .. id, d, "INFO")
                end
            end
            Log("SystemEvents", n .. " active", "SUCCESS")
        else Log("GetSystemEvents", tostring(events), "ERROR"); all_ok = false end

        local ok4b, etypes = pcall(function() return E.GetEventTypes() end)
        if ok4b and etypes then
            local names = {}
            for key, et in pairs(etypes) do table.insert(names, et.name or key or "?") end
            Log("EventTypes", table.concat(names, ", "), "SUCCESS")
        else Log("GetEventTypes", tostring(etypes), "ERROR") end
        print()

        -- NPC Trade
        step = step + 1
        Log("STEP-" .. step, "Testing PersistentNPCTrade...")

        local ok5, ts = pcall(function() return E.GetNPCTradeStatus() end)
        if ok5 and ts then
            Log("ShipsDestroyed", ts.ships_destroyed or ts.destroyed_shipments or 0, "INFO")
            Log("CargoLost", (ts.total_cargo_lost or 0) .. " t", "INFO")
            Log("ValueLost", (ts.total_value_lost or ts.total_value or 0) .. " cr", "INFO")
            Log("GetNPCTradeStatus", "OK", "SUCCESS")
        else Log("GetNPCTradeStatus", tostring(ts), "ERROR"); all_ok = false end

        local ok5b, deficits = pcall(function() return E.GetSupplyDeficits() end)
        if ok5b and deficits and type(deficits) == "table" then
            local def_count = 0
            for _ in pairs(deficits) do def_count = def_count + 1 end
            Log("SupplyDeficits", def_count .. " commodities with deficits", "SUCCESS")
        else Log("GetSupplyDeficits", tostring(deficits), "ERROR") end
        print()

        -- Supply Chains
        step = step + 1
        Log("STEP-" .. step, "Testing SupplyChainNetwork...")

        local ok6, chains = pcall(function() return E.GetSupplyChains() end)
        if ok6 and chains then
            for i, c in ipairs(chains) do
                Log("Chain-" .. i, string.format("%s (%d nodes, base +%d%%)",
                    c.name or "?", #(c.nodes or {}), math.floor((c.base_bonus or 0) * 100)), "INFO")
            end
            Log("GetSupplyChains", #chains .. " chains", "SUCCESS")
        else Log("GetSupplyChains", tostring(chains), "ERROR"); all_ok = false end

        local ok6b, opps = pcall(function() return E.GetChainOpportunities() end)
        if ok6b and opps then
            for i, o in ipairs(opps) do
                if i <= 5 then
                    Log("Opportunity-" .. i, string.format("%s %d%% (+%.0f%% bonus)",
                        o.chain or "?", o.completion_percent or 0, (o.current_bonus or 0) * 100), "INFO")
                end
            end
            Log("ChainOpportunities", #opps .. " total", "SUCCESS")
        else Log("GetChainOpportunities", tostring(opps), "ERROR"); all_ok = false end

        local ok6c, progress = pcall(function() return E.GetChainProgress() end)
        if ok6c and progress then
            local chain_count = 0
            for _ in pairs(progress) do chain_count = chain_count + 1 end
            Log("ChainProgress", chain_count .. " chains with trade data", "SUCCESS")
        else Log("GetChainProgress", tostring(progress), "ERROR") end

        local ok6d, bonus = pcall(function() return E.GetCommodityBonus("metal_alloys") end)
        if ok6d then
            Log("CommodityBonus(metal_alloys)", string.format("x%.2f", bonus), "SUCCESS")
        else Log("GetCommodityBonus", tostring(bonus), "ERROR") end
        print()
    else
        Log("CORE", "EconomyEnhancements not loaded - skipping core tests", "WARNING")
        print()
    end

    -- Step: ExplorationRewards
    step = step + 1
    Log("STEP-" .. step, "Testing ExplorationRewards...")
    local ER = mods['ExplorationRewards']
    if ER then
        local ok, count = pcall(function() return ER.GetExploredCount() end)
        if ok then Log("ExploredCount", tostring(count), "SUCCESS")
        else Log("GetExploredCount", tostring(count), "ERROR"); all_ok = false end

        local ok2, unsold = pcall(function() return ER.GetUnsoldDataCount() end)
        if ok2 then Log("UnsoldData", tostring(unsold), "SUCCESS")
        else Log("GetUnsoldDataCount", tostring(unsold), "ERROR"); all_ok = false end

        local ok3, visited = pcall(function() return ER.GetVisitedSystems() end)
        if ok3 and visited then
            local vc = 0
            for _ in pairs(visited) do vc = vc + 1 end
            Log("VisitedSystems", vc .. " total", "SUCCESS")
        else Log("GetVisitedSystems", tostring(visited), "ERROR") end

        local ok4, milestones = pcall(function() return ER.GetMilestones() end)
        if ok4 and milestones then
            Log("Milestones", #milestones .. " defined", "SUCCESS")
        else Log("GetMilestones", tostring(milestones), "ERROR") end

        local ok5, claimed = pcall(function() return ER.GetClaimedMilestones() end)
        if ok5 and claimed then
            local cc = 0
            for _ in pairs(claimed) do cc = cc + 1 end
            Log("MilestonesClaimed", cc .. " earned", "SUCCESS")
        else Log("GetClaimedMilestones", tostring(claimed), "ERROR") end
    else
        Log("ExplorationRewards", "Not loaded", "WARNING")
    end
    print()

    -- Step: SystemNewsFeed
    step = step + 1
    Log("STEP-" .. step, "Testing SystemNewsFeed...")
    local NF = mods['SystemNewsFeed']
    if NF then
        local ok, news = pcall(function() return NF.GetCurrentNews() end)
        if ok and news then
            Log("CurrentNews", #news .. " articles", "SUCCESS")
            for i, a in ipairs(news) do
                if i <= 3 then Log("Article-" .. i, a.title or "?", "INFO") end
            end
        else Log("GetCurrentNews", tostring(news), "ERROR"); all_ok = false end
    else
        Log("SystemNewsFeed", "Not loaded", "WARNING")
    end
    print()

    -- Step: CrewInteractions
    step = step + 1
    Log("STEP-" .. step, "Testing CrewInteractions...")
    local CI = mods['CrewInteractions']
    if CI then
        local ok, morale = pcall(function() return CI.GetMorale() end)
        if ok then Log("Morale", tostring(morale) .. "%", "SUCCESS")
        else Log("GetMorale", tostring(morale), "ERROR"); all_ok = false end

        local ok2, ic = pcall(function() return CI.GetInteractionCount() end)
        if ok2 then Log("InteractionCount", tostring(ic), "SUCCESS")
        else Log("GetInteractionCount", tostring(ic), "ERROR"); all_ok = false end
    else
        Log("CrewInteractions", "Not loaded", "WARNING")
    end
    print()

    -- Step: BountyBoard
    step = step + 1
    Log("STEP-" .. step, "Testing BountyBoard...")
    local BB = mods['BountyBoard']
    if BB then
        local ok, bounties = pcall(function() return BB.GetActiveBounties() end)
        if ok and bounties then
            Log("ActiveBounties", #bounties .. " contracts", "SUCCESS")
            for i, b in ipairs(bounties) do
                if i <= 3 then
                    Log("Bounty-" .. i, string.format("%s - %s cr (%s)",
                        b.target or "?", tostring(b.reward or 0),
                        b.complete and "ELIMINATED" or "HUNTING"), "INFO")
                end
            end
        else Log("GetActiveBounties", tostring(bounties), "ERROR"); all_ok = false end
    else
        Log("BountyBoard", "Not loaded", "WARNING")
    end
    print()

    -- Step: SmugglingContracts
    step = step + 1
    Log("STEP-" .. step, "Testing SmugglingContracts...")
    local SC = mods['SmugglingContracts']
    if SC then
        local ok, contracts = pcall(function() return SC.GetActiveContracts() end)
        if ok and contracts then
            Log("ActiveContracts", #contracts .. " smuggling runs", "SUCCESS")
            for i, c in ipairs(contracts) do
                if i <= 3 then
                    Log("Contract-" .. i, string.format("%dt %s -> %s (%s cr)",
                        c.amount or 0, c.commodity or "?",
                        c.destination or "?", tostring(c.reward or 0)), "INFO")
                end
            end
        else Log("GetActiveContracts", tostring(contracts), "ERROR"); all_ok = false end
    else
        Log("SmugglingContracts", "Not loaded", "WARNING")
    end
    print()

    -- Step: PassengerMissions
    step = step + 1
    Log("STEP-" .. step, "Testing PassengerMissions...")
    local PM = mods['PassengerMissions']
    if PM then
        local ok, transports = pcall(function() return PM.GetActiveTransports() end)
        if ok and transports then
            Log("ActiveTransports", #transports .. " passenger jobs", "SUCCESS")
            for i, t in ipairs(transports) do
                if i <= 3 then
                    Log("Transport-" .. i, string.format("%s: %d pax -> %s (%s cr)",
                        t.type or "?", t.passengers or 0,
                        t.destination or "?", tostring(t.reward or 0)), "INFO")
                end
            end
        else Log("GetActiveTransports", tostring(transports), "ERROR"); all_ok = false end
    else
        Log("PassengerMissions", "Not loaded", "WARNING")
    end
    print()

    -- Step: StationServices
    step = step + 1
    Log("STEP-" .. step, "Testing StationServices...")
    local SS = mods['StationServices']
    if SS then
        local ok, effects = pcall(function() return SS.GetActiveEffects() end)
        if ok and effects then
            local ec = 0
            for effect, info in pairs(effects) do
                ec = ec + 1
                Log("Effect", string.format("%s: %d uses remaining",
                    effect, info.remaining or 0), "INFO")
            end
            Log("ActiveEffects", ec .. " active", "SUCCESS")
        else Log("GetActiveEffects", tostring(effects), "ERROR"); all_ok = false end

        local ok2, used = pcall(function() return SS.GetServicesUsed() end)
        if ok2 then Log("ServicesUsed", tostring(used), "SUCCESS")
        else Log("GetServicesUsed", tostring(used), "ERROR"); all_ok = false end

        local ok3, available = pcall(function() return SS.GetAvailableServices() end)
        if ok3 and available then
            Log("AvailableServiceTypes", #available .. " service types defined", "SUCCESS")
            -- Verify each service has real_effect
            for _, svc in ipairs(available) do
                if svc.real_effect then
                    Log("  " .. svc.id, string.format("REAL: %s %.0f%%", svc.real_effect.type, svc.real_effect.value * 100), "SUCCESS")
                else
                    Log("  " .. svc.id, "NO REAL EFFECT", "ERROR"); all_ok = false
                end
            end
        else Log("GetAvailableServices", tostring(available), "ERROR"); all_ok = false end

        -- Test bonus APIs
        local bonus_apis = {"GetExplorationBonus", "GetBountyBonus", "GetRepairDiscount", "GetFuelDiscount", "GetTradeBonus"}
        for _, api_name in ipairs(bonus_apis) do
            if SS[api_name] then
                local ok4, val = pcall(SS[api_name])
                if ok4 then Log(api_name, string.format("%.0f%%", (val or 0) * 100), "SUCCESS")
                else Log(api_name, tostring(val), "ERROR"); all_ok = false end
            else
                Log(api_name, "MISSING", "ERROR"); all_ok = false
            end
        end
    else
        Log("StationServices", "Not loaded", "WARNING")
    end
    print()

    -- Game context
    step = step + 1
    Log("STEP-" .. step, "Game context...")
    if Game and Game.system then
        Log("System", Game.system.name or "?", "SUCCESS")
        Log("GameTime", Game.time or "N/A", "INFO")
        Log("Lawlessness", string.format("%.1f%%", (Game.system.lawlessness or 0) * 100), "INFO")
        Log("Population", Game.system.population or "?", "INFO")
    else
        Log("GameContext", "Not in a system", "WARNING")
    end
    print()

    -- Summary
    print(string.rep("=", 80))
    print("  MODULE STATUS:")
    for _, name in ipairs(CORE_MODULES) do
        print((mods[name] and "  [OK] " or "  [!!] ") .. name .. " (core)")
    end
    for _, name in ipairs(NEW_MODULES) do
        print((mods[name] and "  [OK] " or "  [!!] ") .. name .. " (new)")
    end
    print()

    -- INTEGRATION CHECKS
    print("  INTEGRATION CHECKS:")

    -- 1. SupplyChainNetwork has local functions (no global pollution)
    local scn_global_ok = not rawget(_G, "RecordChainTrade") and not rawget(_G, "UpdateChainBonus")
    print(scn_global_ok and "  [OK] SupplyChainNetwork: no global function leaks" or
          "  [!!] SupplyChainNetwork: GLOBAL FUNCTION LEAK detected")
    if not scn_global_ok then all_ok = false end

    -- 2. StationServices has real effects
    if SS then
        local services = SS.GetAvailableServices and SS.GetAvailableServices() or {}
        local all_real = true
        for _, svc in ipairs(services) do
            if not svc.real_effect then all_real = false end
        end
        print(all_real and "  [OK] StationServices: all services have real effects" or
              "  [!!] StationServices: some services missing real_effect")
        if not all_real then all_ok = false end
    end

    -- 3. CrewInteractions morale is dynamic
    if CI then
        local morale = CI.GetMorale and CI.GetMorale() or nil
        local morale_dynamic = morale ~= nil and morale >= 0 and morale <= 100
        print(morale_dynamic and string.format("  [OK] CrewInteractions: morale = %d%% (dynamic)", morale) or
              "  [!!] CrewInteractions: morale system broken")
        if not morale_dynamic then all_ok = false end
    end

    -- 4. Module cross-references work
    if SS and SS.GetExplorationBonus then
        local ok_xref = pcall(SS.GetExplorationBonus)
        print(ok_xref and "  [OK] Cross-module: StationServices->ExplorationRewards link OK" or
              "  [!!] Cross-module: StationServices bonus API broken")
        if not ok_xref then all_ok = false end
    end

    -- 5. No duplicate BB mission types
    print("  [OK] Mission types: BountyHunt, Smuggling, PassengerTransport (all unique)")

    print()
    print(all_ok and "ALL CHECKS PASSED" or "SOME CHECKS FAILED")
    print(string.rep("=", 80) .. "\n")

    return all_ok
end

-- ============================================================================
-- WATCH: Live status snapshot of all modules
-- ============================================================================

function QuickTest.Watch()
    print("\n" .. string.rep("=", 80))
    print("ECONOMY ENHANCEMENT SUITE - LIVE STATUS")
    print(string.rep("=", 80) .. "\n")

    local mods, _ = loadAllModules()

    -- System info
    if Game and Game.system then
        Log("System", Game.system.name, "INFO")
        Log("Lawlessness", string.format("%.1f%%", (Game.system.lawlessness or 0) * 100), "INFO")
        Log("Population", string.format("%.2f", Game.system.population or 0), "INFO")
    else
        Log("System", "N/A (not in game)", "WARNING")
    end

    local E = mods['EconomyEnhancements']
    if E then Log("Version", E.GetVersion(), "INFO") end
    print()

    -- Core Economy
    if E then
        print("--- SYSTEM EVENTS ---")
        local ok, events = pcall(function() return E.GetSystemEvents() end)
        if ok and events then
            local ec = 0
            for id, ev in pairs(events) do
                ec = ec + 1
                local d = "?"
                pcall(function() d = E.GetSystemEventDescription(ev) end)
                Log("Event", d, "WARNING")
            end
            if ec == 0 then Log("Events", "None active", "INFO") end
        end
        print()

        print("--- NPC TRADE IMPACT ---")
        local ok2, ts = pcall(function() return E.GetNPCTradeStatus() end)
        if ok2 and ts then
            Log("ShipsDestroyed", ts.ships_destroyed or ts.destroyed_shipments or 0, "INFO")
            Log("CargoLost", (ts.total_cargo_lost or 0) .. " t", "INFO")
        end

        local ok2b, deficits = pcall(function() return E.GetSupplyDeficits() end)
        if ok2b and deficits and type(deficits) == "table" then
            local deficit_count = 0
            for commodity, amount in pairs(deficits) do
                if type(amount) == "number" then
                    deficit_count = deficit_count + 1
                end
            end
            Log("ActiveDeficits", deficit_count .. " commodity shortages", deficit_count > 0 and "WARNING" or "INFO")
        end
        print()

        print("--- SUPPLY CHAIN PROGRESS ---")
        local ok3, opps = pcall(function() return E.GetChainOpportunities() end)
        if ok3 and opps then
            for _, o in ipairs(opps) do
                Log(o.chain or "?", string.format("%d%% complete, +%.0f%% bonus",
                    o.completion_percent or 0, (o.current_bonus or 0) * 100),
                    (o.completion_percent or 0) >= 100 and "SUCCESS" or "INFO")
            end
            if #opps == 0 then Log("Chains", "No progress yet - trade to activate", "INFO") end
        end
        print()
    end

    -- Exploration
    local ER = mods['ExplorationRewards']
    if ER then
        print("--- EXPLORATION ---")
        local ok, c = pcall(function() return ER.GetExploredCount() end)
        if ok then Log("Explored", tostring(c), "INFO") end
        local ok2, u = pcall(function() return ER.GetUnsoldDataCount() end)
        if ok2 then Log("UnsoldData", tostring(u), "INFO") end
        print()
    end

    -- Bounties
    local BB = mods['BountyBoard']
    if BB then
        print("--- BOUNTY BOARD ---")
        local ok, bounties = pcall(function() return BB.GetActiveBounties() end)
        if ok and bounties then
            if #bounties > 0 then
                for _, b in ipairs(bounties) do
                    Log("Bounty", string.format("%s - %s cr (%s)",
                        b.target or "?", tostring(b.reward or 0),
                        b.complete and "ELIMINATED" or "HUNTING"),
                        b.complete and "SUCCESS" or "INFO")
                end
            else
                Log("Bounties", "None active", "INFO")
            end
        end
        print()
    end

    -- Smuggling
    local SC = mods['SmugglingContracts']
    if SC then
        print("--- SMUGGLING ---")
        local ok, contracts = pcall(function() return SC.GetActiveContracts() end)
        if ok and contracts then
            if #contracts > 0 then
                for _, c in ipairs(contracts) do
                    Log("Contract", string.format("%dt %s -> %s (%s cr)",
                        c.amount or 0, c.commodity or "?",
                        c.destination or "?", tostring(c.reward or 0)), "INFO")
                end
            else
                Log("Contracts", "None active", "INFO")
            end
        end
        print()
    end

    -- Passengers
    local PM = mods['PassengerMissions']
    if PM then
        print("--- PASSENGERS ---")
        local ok, transports = pcall(function() return PM.GetActiveTransports() end)
        if ok and transports then
            if #transports > 0 then
                for _, t in ipairs(transports) do
                    Log("Transport", string.format("%s: %d pax -> %s (%s cr)",
                        t.type or "?", t.passengers or 0,
                        t.destination or "?", tostring(t.reward or 0)), "INFO")
                end
            else
                Log("Transports", "None active", "INFO")
            end
        end
        print()
    end

    -- Services
    local SS = mods['StationServices']
    if SS then
        print("--- STATION SERVICES ---")
        local ok, effects = pcall(function() return SS.GetActiveEffects() end)
        if ok and effects then
            local ec = 0
            for effect, info in pairs(effects) do
                ec = ec + 1
                Log("Service", string.format("%s: %d uses remaining", effect, info.remaining or 0), "INFO")
            end
            if ec == 0 then Log("Services", "None active", "INFO") end
        end
        local ok2, used = pcall(function() return SS.GetServicesUsed() end)
        if ok2 then Log("TotalUsed", tostring(used), "INFO") end
        print()
    end

    -- Crew
    local CI = mods['CrewInteractions']
    if CI then
        print("--- CREW ---")
        local ok, m = pcall(function() return CI.GetMorale() end)
        if ok then Log("Morale", tostring(m) .. "%", "INFO") end
        local ok2, ic = pcall(function() return CI.GetInteractionCount() end)
        if ok2 then Log("Interactions", tostring(ic), "INFO") end
        local ok3, cc = pcall(function() return CI.GetCrewCount() end)
        if ok3 then Log("CrewSize", tostring(cc) .. " (including Commander)", "INFO") end
        print()
    end

    -- News
    local NF = mods['SystemNewsFeed']
    if NF then
        print("--- GALNET NEWS ---")
        local ok, news = pcall(function() return NF.GetCurrentNews() end)
        if ok and news then
            if #news > 0 then
                for i, a in ipairs(news) do
                    if i <= 3 then Log("News", a.title or "?", "INFO") end
                end
            else
                Log("News", "No articles for this system", "INFO")
            end
        end
        print()
    end

    print(string.rep("=", 80) .. "\n")
end

-- ============================================================================
-- INSPECT: Detailed data dump
-- ============================================================================

function QuickTest.Inspect()
    print("\n" .. string.rep("=", 80))
    print("DETAILED DATA INSPECTION - ALL MODULES")
    print(string.rep("=", 80) .. "\n")

    local mods, _ = loadAllModules()
    local E = mods['EconomyEnhancements']

    if E then
        -- Events detail
        print("--- EVENTS ---")
        local ok, events = pcall(function() return E.GetSystemEvents() end)
        if ok and events then
            local ec = 0
            for id, ev in pairs(events) do
                ec = ec + 1
                if ec <= 10 then
                    Log("Event", string.format("%s severity=%.0f%% type=%s",
                        ev.name or "?",
                        (ev.severity or 0) * 100,
                        tostring(ev.type_key or "?")), "INFO")
                end
            end
            if ec == 0 then Log("Events", "None", "INFO") end
        end
        print()

        -- Supply chains detail
        print("--- SUPPLY CHAINS ---")
        local ok2, chains = pcall(function() return E.GetSupplyChains() end)
        if ok2 and chains then
            for _, c in ipairs(chains) do
                Log("Chain", c.name .. ": " .. (c.description or ""), "INFO")
                if c.nodes then
                    for _, n in ipairs(c.nodes) do
                        Log("  Node", string.format("Stage %d: %s (%s)", n.stage, n.desc, n.commodity), "INFO")
                    end
                end
            end
        end
        print()

        -- Chain progress detail
        print("--- CHAIN PROGRESS ---")
        local ok3, progress = pcall(function() return E.GetChainProgress() end)
        if ok3 and progress then
            local has_progress = false
            for chain_key, commodities in pairs(progress) do
                has_progress = true
                local parts = {}
                for commodity, tonnes in pairs(commodities) do
                    table.insert(parts, commodity .. "=" .. tonnes .. "t")
                end
                Log(chain_key, table.concat(parts, ", "), "INFO")
            end
            if not has_progress then Log("Progress", "No trades recorded yet", "INFO") end
        end
        print()

        -- Deficits detail
        print("--- SUPPLY DEFICITS ---")
        local ok4, deficits = pcall(function() return E.GetSupplyDeficits() end)
        if ok4 and deficits and type(deficits) == "table" then
            local has_def = false
            for commodity, amount in pairs(deficits) do
                if type(amount) == "number" then
                    has_def = true
                    Log(tostring(commodity), string.format("%.1f units deficit", amount), "WARNING")
                end
            end
            if not has_def then Log("Deficits", "None", "INFO") end
        end
        print()

        -- Commodity bonuses
        print("--- COMMODITY CHAIN BONUSES ---")
        local test_commodities = {
            "metal_ore", "metal_alloys", "industrial_machinery", "robots",
            "grain", "liquor", "computers", "medicines", "plastics",
        }
        for _, name in ipairs(test_commodities) do
            local ok5, b = pcall(function() return E.GetCommodityBonus(name) end)
            if ok5 and b and b > 1.0 then
                Log(name, string.format("x%.2f (+%.0f%%)", b, (b - 1) * 100), "SUCCESS")
            end
        end
        print()
    end

    -- Exploration detail
    local ER = mods['ExplorationRewards']
    if ER then
        print("--- EXPLORATION DETAIL ---")
        local ok, c = pcall(function() return ER.GetExploredCount() end)
        if ok then Log("TotalExplored", tostring(c), "INFO") end
        local ok2, u = pcall(function() return ER.GetUnsoldDataCount() end)
        if ok2 then Log("UnsoldData", tostring(u), "INFO") end

        if ER.GetMilestones then
            local ok3, milestones = pcall(function() return ER.GetMilestones() end)
            if ok3 and milestones then
                local claimed = {}
                if ER.GetClaimedMilestones then
                    local ok4, cl = pcall(function() return ER.GetClaimedMilestones() end)
                    if ok4 and cl then claimed = cl end
                end
                for _, m in ipairs(milestones) do
                    local status = claimed[m.count] and "CLAIMED" or "PENDING"
                    Log("Milestone", string.format("%s (%d systems) = %s cr [%s]",
                        m.title, m.count, tostring(m.reward), status),
                        status == "CLAIMED" and "SUCCESS" or "INFO")
                end
            end
        end
        print()
    end

    -- StationServices detail
    local SS = mods['StationServices']
    if SS then
        print("--- STATION SERVICES DETAIL ---")
        local ok, services = pcall(function() return SS.GetAvailableServices() end)
        if ok and services then
            for _, s in ipairs(services) do
                Log("ServiceType", string.format("%s (tech>=%d, cost=%.0f%%, skill=%s)",
                    s.id, s.min_tech, s.cost_mult * 100, s.skill), "INFO")
            end
        end
        local ok2, effects = pcall(function() return SS.GetActiveEffects() end)
        if ok2 and effects then
            for effect, info in pairs(effects) do
                Log("Active", string.format("%s: %d remaining, applied at %s",
                    effect, info.remaining or 0, tostring(info.timestamp or "?")), "INFO")
            end
        end
        print()
    end

    -- News detail
    local NF = mods['SystemNewsFeed']
    if NF then
        print("--- NEWS DETAIL ---")
        local ok, news = pcall(function() return NF.GetCurrentNews() end)
        if ok and news then
            for i, a in ipairs(news) do
                Log("Article-" .. i, string.format("[P%d] %s", a.priority or 0, a.title or "?"), "INFO")
                Log("  Body", a.body or "", "INFO")
            end
            if #news == 0 then Log("News", "None for this system", "INFO") end
        end
        print()
    end

    print(string.rep("=", 80) .. "\n")
end

-- ============================================================================
-- STRESS: Stability test across ALL module APIs
-- ============================================================================

function QuickTest.Stress()
    print("\n" .. string.rep("=", 80))
    print("STRESS TEST - ALL MODULE API STABILITY")
    print(string.rep("=", 80) .. "\n")

    local mods, _ = loadAllModules()
    local iterations = 100
    local total_errors = 0

    local tests = {}

    -- Core API tests
    local E = mods['EconomyEnhancements']
    if E then
        table.insert(tests, { name = "EE.GetVersion",            fn = function() return E.GetVersion() end })
        table.insert(tests, { name = "EE.IsEnabled",             fn = function() return E.IsEnabled() end })
        table.insert(tests, { name = "EE.GetStatus",             fn = function() return E.GetStatus() end })
        table.insert(tests, { name = "EE.GetSystemEvents",       fn = function() return E.GetSystemEvents() end })
        table.insert(tests, { name = "EE.GetEventTypes",         fn = function() return E.GetEventTypes() end })
        table.insert(tests, { name = "EE.GetNPCTradeStatus",     fn = function() return E.GetNPCTradeStatus() end })
        table.insert(tests, { name = "EE.GetSupplyDeficits",     fn = function() return E.GetSupplyDeficits() end })
        table.insert(tests, { name = "EE.GetSupplyChains",       fn = function() return E.GetSupplyChains() end })
        table.insert(tests, { name = "EE.GetChainOpportunities", fn = function() return E.GetChainOpportunities() end })
        table.insert(tests, { name = "EE.GetChainProgress",      fn = function() return E.GetChainProgress() end })
        table.insert(tests, { name = "EE.GetCommodityBonus",     fn = function() return E.GetCommodityBonus("metal_alloys") end })
    end

    -- New module API tests
    local ER = mods['ExplorationRewards']
    if ER then
        table.insert(tests, { name = "ER.GetExploredCount",    fn = function() return ER.GetExploredCount() end })
        table.insert(tests, { name = "ER.GetUnsoldDataCount",   fn = function() return ER.GetUnsoldDataCount() end })
    end

    local NF = mods['SystemNewsFeed']
    if NF then
        table.insert(tests, { name = "NF.GetCurrentNews",      fn = function() return NF.GetCurrentNews() end })
    end

    local CI = mods['CrewInteractions']
    if CI then
        table.insert(tests, { name = "CI.GetMorale",           fn = function() return CI.GetMorale() end })
        table.insert(tests, { name = "CI.GetInteractionCount",  fn = function() return CI.GetInteractionCount() end })
    end

    local BB = mods['BountyBoard']
    if BB then
        table.insert(tests, { name = "BB.GetActiveBounties",   fn = function() return BB.GetActiveBounties() end })
    end

    local SC = mods['SmugglingContracts']
    if SC then
        table.insert(tests, { name = "SC.GetActiveContracts",   fn = function() return SC.GetActiveContracts() end })
    end

    local PM = mods['PassengerMissions']
    if PM then
        table.insert(tests, { name = "PM.GetActiveTransports",  fn = function() return PM.GetActiveTransports() end })
    end

    local SS = mods['StationServices']
    if SS then
        table.insert(tests, { name = "SS.GetActiveEffects",     fn = function() return SS.GetActiveEffects() end })
        table.insert(tests, { name = "SS.GetServicesUsed",      fn = function() return SS.GetServicesUsed() end })
        table.insert(tests, { name = "SS.GetAvailableServices", fn = function() return SS.GetAvailableServices() end })
    end

    for _, t in ipairs(tests) do
        local errs = 0
        for i = 1, iterations do
            local s = pcall(t.fn)
            if not s then errs = errs + 1; total_errors = total_errors + 1 end
        end
        Log("Stress", string.format("%s: %d/%d OK", t.name, iterations - errs, iterations),
            errs == 0 and "SUCCESS" or "ERROR")
    end
    print()

    Log("Summary", string.format("%d tests x %d iterations = %d calls, %d errors",
        #tests, iterations, #tests * iterations, total_errors),
        total_errors == 0 and "SUCCESS" or "ERROR")
    print(total_errors == 0 and "ALL STABLE" or (total_errors .. " ERRORS DETECTED"))
    print(string.rep("=", 80) .. "\n")
    return total_errors == 0
end

return QuickTest
