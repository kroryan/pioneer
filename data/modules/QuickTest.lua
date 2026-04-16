-- QuickTest Module - Debug & Verification for Economy Enhancement Suite v2.0
-- Usage: require('modules.QuickTest').Run() or .Watch() or .Inspect() or .Stress()

local Game = require 'Game'

local QuickTest = {}

local function Log(section, message, level)
    level = level or "INFO"
    print(string.format("[%s] [%s] %s", level, section, tostring(message)))
end

-- ============================================================================
-- RUN: Comprehensive Verification
-- ============================================================================

function QuickTest.Run()
    print("\n" .. string.rep("=", 80))
    print("ECONOMY ENHANCEMENTS v2.0 - COMPREHENSIVE VERIFICATION")
    print(string.rep("=", 80) .. "\n")

    local all_ok = true
    local step = 0

    -- Load modules
    step = step + 1
    Log("STEP-" .. step, "Loading modules...")

    local mod_names = {
        'DynamicSystemEvents',
        'PersistentNPCTrade',
        'SupplyChainNetwork',
        'EconomyEnhancements',
    }
    local mods = {}
    for _, name in ipairs(mod_names) do
        local ok, m = pcall(function() return require('modules.' .. name) end)
        if ok and m then
            Log(name, "LOADED", "SUCCESS")
            mods[name] = m
        else
            Log(name, "FAILED: " .. tostring(m), "ERROR")
            all_ok = false
        end
    end
    print()

    local E = mods['EconomyEnhancements']
    if not E then
        Log("TEST", "EconomyEnhancements not loaded - aborting", "ERROR")
        return false
    end

    -- Core API
    step = step + 1
    Log("STEP-" .. step, "Testing core API...")

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
        for _, et in ipairs(etypes) do table.insert(names, et.name or et.type or "?") end
        Log("EventTypes", table.concat(names, ", "), "SUCCESS")
    else Log("GetEventTypes", tostring(etypes), "ERROR") end
    print()

    -- NPC Trade
    step = step + 1
    Log("STEP-" .. step, "Testing PersistentNPCTrade...")

    local ok5, ts = pcall(function() return E.GetNPCTradeStatus() end)
    if ok5 and ts then
        Log("ShipsDestroyed", ts.ships_destroyed or ts.destroyed_shipments or 0, "INFO")
        Log("CargoLost", ts.total_cargo_lost or 0, "INFO")
        Log("ValueLost", (ts.total_value_lost or ts.total_value or 0) .. " cr", "INFO")
        Log("GetNPCTradeStatus", "OK", "SUCCESS")
    else Log("GetNPCTradeStatus", tostring(ts), "ERROR"); all_ok = false end

    local ok5b, deficits = pcall(function() return E.GetSupplyDeficits() end)
    if ok5b and deficits then
        local sys_count = 0
        for _ in pairs(deficits) do sys_count = sys_count + 1 end
        Log("SupplyDeficits", sys_count .. " systems with deficits", "SUCCESS")
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

    -- Game context
    step = step + 1
    Log("STEP-" .. step, "Game context...")
    if Game and Game.system then
        Log("System", Game.system.name or "?", "SUCCESS")
        Log("GameTime", Game.time or "N/A", "INFO")
        Log("Lawlessness", Game.system.lawlessness or "?", "INFO")
        Log("Population", Game.system.population or "?", "INFO")
    else
        Log("GameContext", "Not in a system", "WARNING")
    end
    print()

    -- Summary
    print(string.rep("=", 80))
    for _, name in ipairs(mod_names) do
        print((mods[name] and "  [OK] " or "  [!!] ") .. name)
    end
    print()
    print(all_ok and "ALL CHECKS PASSED" or "SOME CHECKS FAILED")
    print(string.rep("=", 80) .. "\n")

    return all_ok
end

-- ============================================================================
-- WATCH: Live status snapshot
-- ============================================================================

function QuickTest.Watch()
    print("\n" .. string.rep("=", 80))
    print("ECONOMY ENHANCEMENTS v2.0 - LIVE STATUS")
    print(string.rep("=", 80) .. "\n")

    local ok, E = pcall(function() return require('modules.EconomyEnhancements') end)
    if not ok or not E then
        Log("WATCH", "Failed to load: " .. tostring(E), "ERROR")
        return
    end

    -- System info
    if Game and Game.system then
        Log("System", Game.system.name, "INFO")
        Log("Lawlessness", string.format("%.1f%%", (Game.system.lawlessness or 0) * 100), "INFO")
    else
        Log("System", "N/A (not in game)", "WARNING")
    end
    Log("Version", E.GetVersion(), "INFO")
    print()

    -- Events
    print("--- SYSTEM EVENTS ---")
    local events = E.GetSystemEvents()
    local ec = 0
    for id, ev in pairs(events) do
        ec = ec + 1
        local d = "?"
        pcall(function() d = E.GetSystemEventDescription(ev) end)
        Log("Event", d, "WARNING")
    end
    if ec == 0 then Log("Events", "None active", "INFO") end
    print()

    -- NPC Trade
    print("--- NPC TRADE IMPACT ---")
    local ts = E.GetNPCTradeStatus()
    Log("ShipsDestroyed", ts.ships_destroyed or ts.destroyed_shipments or 0, "INFO")
    Log("CargoLost", (ts.total_cargo_lost or 0) .. " t", "INFO")

    local deficits = E.GetSupplyDeficits()
    local deficit_count = 0
    for sys, commodities in pairs(deficits) do
        for _ in pairs(commodities) do deficit_count = deficit_count + 1 end
    end
    Log("ActiveDeficits", deficit_count .. " commodity shortages", deficit_count > 0 and "WARNING" or "INFO")
    print()

    -- Supply Chains
    print("--- SUPPLY CHAIN PROGRESS ---")
    local opps = E.GetChainOpportunities()
    for _, o in ipairs(opps) do
        Log(o.chain or "?", string.format("%d%% complete, +%.0f%% bonus",
            o.completion_percent or 0, (o.current_bonus or 0) * 100),
            (o.completion_percent or 0) >= 100 and "SUCCESS" or "INFO")
    end
    if #opps == 0 then Log("Chains", "No progress yet - trade to activate", "INFO") end
    print()

    print(string.rep("=", 80) .. "\n")
end

-- ============================================================================
-- INSPECT: Detailed data dump
-- ============================================================================

function QuickTest.Inspect()
    print("\n" .. string.rep("=", 80))
    print("DETAILED DATA INSPECTION")
    print(string.rep("=", 80) .. "\n")

    local ok, E = pcall(function() return require('modules.EconomyEnhancements') end)
    if not ok or not E then
        Log("INSPECT", "Failed to load", "ERROR")
        return
    end

    -- Events detail
    print("--- EVENTS ---")
    local events = E.GetSystemEvents()
    local ec = 0
    for id, ev in pairs(events) do
        ec = ec + 1
        if ec <= 10 then
            Log("Event", string.format("%s severity=%.0f%% duration=%s",
                ev.event_type or "?",
                (ev.severity or 0) * 100,
                tostring(ev.duration or "?")), "INFO")
        end
    end
    if ec == 0 then Log("Events", "None", "INFO") end
    print()

    -- Supply chains detail
    print("--- SUPPLY CHAINS ---")
    local chains = E.GetSupplyChains()
    for _, c in ipairs(chains) do
        Log("Chain", c.name .. ": " .. (c.description or ""), "INFO")
        if c.nodes then
            for _, n in ipairs(c.nodes) do
                Log("  Node", string.format("Stage %d: %s (%s)", n.stage, n.desc, n.commodity), "INFO")
            end
        end
    end
    print()

    -- Chain progress detail
    print("--- CHAIN PROGRESS ---")
    local progress = E.GetChainProgress()
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
    print()

    -- Deficits detail
    print("--- SUPPLY DEFICITS ---")
    local deficits = E.GetSupplyDeficits()
    local has_def = false
    for sys, commodities in pairs(deficits) do
        has_def = true
        local parts = {}
        for commodity, amount in pairs(commodities) do
            table.insert(parts, commodity .. "=" .. string.format("%.1f", amount))
        end
        Log(tostring(sys), table.concat(parts, ", "), "WARNING")
    end
    if not has_def then Log("Deficits", "None", "INFO") end
    print()

    -- Commodity bonuses
    print("--- COMMODITY CHAIN BONUSES ---")
    local test_commodities = {
        "metal_ore", "metal_alloys", "industrial_machinery", "robots",
        "grain", "liquor", "computers", "medicines", "plastics",
    }
    for _, name in ipairs(test_commodities) do
        local b = E.GetCommodityBonus(name)
        if b > 1.0 then
            Log(name, string.format("x%.2f (+%.0f%%)", b, (b - 1) * 100), "SUCCESS")
        end
    end
    print()

    print(string.rep("=", 80) .. "\n")
end

-- ============================================================================
-- STRESS: Stability test
-- ============================================================================

function QuickTest.Stress()
    print("\n" .. string.rep("=", 80))
    print("STRESS TEST - v2.0 API STABILITY")
    print(string.rep("=", 80) .. "\n")

    local ok, E = pcall(function() return require('modules.EconomyEnhancements') end)
    if not ok or not E then
        Log("STRESS", "Failed to load", "ERROR")
        return false
    end

    local iterations = 100
    local errors = 0

    local tests = {
        { name = "GetVersion",            fn = function() return E.GetVersion() end },
        { name = "IsEnabled",             fn = function() return E.IsEnabled() end },
        { name = "GetStatus",             fn = function() return E.GetStatus() end },
        { name = "GetSystemEvents",       fn = function() return E.GetSystemEvents() end },
        { name = "GetEventTypes",         fn = function() return E.GetEventTypes() end },
        { name = "GetNPCTradeStatus",     fn = function() return E.GetNPCTradeStatus() end },
        { name = "GetSupplyDeficits",     fn = function() return E.GetSupplyDeficits() end },
        { name = "GetSupplyChains",       fn = function() return E.GetSupplyChains() end },
        { name = "GetChainOpportunities", fn = function() return E.GetChainOpportunities() end },
        { name = "GetChainProgress",      fn = function() return E.GetChainProgress() end },
        { name = "GetCommodityBonus",     fn = function() return E.GetCommodityBonus("metal_alloys") end },
    }

    for _, t in ipairs(tests) do
        local errs = 0
        for i = 1, iterations do
            local ok2 = pcall(t.fn)
            if not ok2 then errs = errs + 1; errors = errors + 1 end
        end
        Log("Stress", string.format("%s: %d/%d OK", t.name, iterations - errs, iterations),
            errs == 0 and "SUCCESS" or "ERROR")
    end
    print()

    print(errors == 0 and "ALL STABLE" or (errors .. " ERRORS DETECTED"))
    print(string.rep("=", 80) .. "\n")
    return errors == 0
end

return QuickTest
