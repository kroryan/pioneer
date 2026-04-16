-- QuickTest Module - Heavy Debug & Verification Suite
-- Usage: require('modules.QuickTest').Run() or .Watch() or .Inspect()

local QuickTest = {}

-- ============================================================================
-- HEAVY DEBUG LOGGING
-- ============================================================================

local function DebugLog(section, message, level)
    level = level or "INFO"
    local prefix = string.format("[%s] [%s]", level, section)
    print(prefix .. " " .. tostring(message))
end

-- ============================================================================
-- RUN: Comprehensive Verification
-- ============================================================================

function QuickTest.Run()
    print("\n" .. string.rep("=", 80))
    print("COMPREHENSIVE VERIFICATION - ECONOMY ENHANCEMENTS")
    print(string.rep("=", 80) .. "\n")
    
    local step = 1
    local all_ok = true
    
    -- STEP 1: Load all modules
    DebugLog("STEP-" .. step, "Loading all economy modules...", "INFO")
    step = step + 1
    print()
    
    local modules_loaded = {}
    local modules_to_test = {
        'DynamicSystemEvents',
        'PersistentNPCTrade',
        'SupplyChainNetwork',
        'EconomyEnhancements'
    }
    
    for i, module_name in ipairs(modules_to_test) do
        local ok, module = pcall(function()
            return require('modules.' .. module_name)
        end)
        
        if ok and module then
            DebugLog(module_name, "LOADED OK", "SUCCESS")
            modules_loaded[module_name] = module
        else
            DebugLog(module_name, "FAILED: " .. tostring(module), "ERROR")
            modules_loaded[module_name] = nil
            all_ok = false
        end
    end
    
    print()
    
    -- STEP 2: Test EconomyEnhancements core functions
    if not modules_loaded['EconomyEnhancements'] then
        DebugLog("TEST", "EconomyEnhancements not loaded - aborting tests", "ERROR")
        print("\n" .. string.rep("=", 80) .. "\n")
        return false
    end
    
    local E = modules_loaded['EconomyEnhancements']
    
    DebugLog("STEP-" .. step, "Testing EconomyEnhancements API...", "INFO")
    step = step + 1
    print()
    
    -- Test version
    local ok, version = pcall(function() return E.GetVersion() end)
    if ok then
        DebugLog("GetVersion()", "Version: " .. tostring(version), "SUCCESS")
    else
        DebugLog("GetVersion()", "FAILED: " .. tostring(version), "ERROR")
        all_ok = false
    end
    
    -- Test enabled status
    local ok, enabled = pcall(function() return E.IsEnabled() end)
    if ok then
        DebugLog("IsEnabled()", "Enabled: " .. tostring(enabled), enabled and "SUCCESS" or "WARNING")
    else
        DebugLog("IsEnabled()", "FAILED: " .. tostring(enabled), "ERROR")
        all_ok = false
    end
    
    -- Test status
    local ok, status = pcall(function() return E.GetStatus() end)
    if ok and status then
        DebugLog("GetStatus()", "Module status retrieved: " .. tostring(type(status)), "SUCCESS")
    else
        DebugLog("GetStatus()", "FAILED: " .. tostring(status), "ERROR")
        all_ok = false
    end
    
    print()
    
    -- STEP 3: Test system events
    DebugLog("STEP-" .. step, "Testing System Events Module...", "INFO")
    step = step + 1
    print()
    
    local ok, events = pcall(function() return E.GetSystemEvents() end)
    if ok and events then
        local event_count = 0
        for id, event in pairs(events) do
            event_count = event_count + 1
            local desc = "Unknown"
            local ok2, desc2 = pcall(function()
                return E.GetSystemEventDescription(event)
            end)
            if ok2 then desc = desc2 end
            DebugLog("SystemEvent-" .. id, desc, "INFO")
        end
        DebugLog("GetSystemEvents()", "Total active events: " .. event_count, event_count > 0 and "SUCCESS" or "INFO")
    else
        DebugLog("GetSystemEvents()", "FAILED: " .. tostring(events), "ERROR")
        all_ok = false
    end
    
    print()
    
    -- STEP 4: Test NPC Trade
    DebugLog("STEP-" .. step, "Testing NPC Trade Module...", "INFO")
    step = step + 1
    print()
    
    local ok, trade_status = pcall(function() return E.GetNPCTradeStatus() end)
    if ok and trade_status then
        DebugLog("ActiveShipments", trade_status.active_shipments or 0, "INFO")
        DebugLog("DeliveredShipments", trade_status.delivered_shipments or 0, "INFO")
        DebugLog("DestroyedShipments", trade_status.destroyed_shipments or 0, trade_status.destroyed_shipments and trade_status.destroyed_shipments > 0 and "WARNING" or "INFO")
        DebugLog("TotalTradeValue", (trade_status.total_value or 0) .. " credits", "INFO")
        DebugLog("GetNPCTradeStatus()", "Trade status retrieved", "SUCCESS")
    else
        DebugLog("GetNPCTradeStatus()", "FAILED: " .. tostring(trade_status), "ERROR")
        all_ok = false
    end
    
    print()
    
    -- STEP 5: Test Supply Chains
    DebugLog("STEP-" .. step, "Testing Supply Chain Module...", "INFO")
    step = step + 1
    print()
    
    local ok, chains = pcall(function() return E.GetSupplyChains() end)
    if ok and chains then
        local chain_count = 0
        for i, chain in ipairs(chains) do
            chain_count = chain_count + 1
            DebugLog("Chain-" .. i, chain.name or "Unknown", "INFO")
        end
        DebugLog("GetSupplyChains()", "Total chains: " .. chain_count, "SUCCESS")
    else
        DebugLog("GetSupplyChains()", "FAILED: " .. tostring(chains), "ERROR")
        all_ok = false
    end
    
    print()
    
    -- STEP 6: Test opportunities
    local ok, opps = pcall(function() return E.GetChainOpportunities() end)
    if ok and opps then
        local opp_count = 0
        for i, opp in ipairs(opps) do
            opp_count = opp_count + 1
            if i <= 5 then  -- Show first 5
                DebugLog("Opportunity-" .. i, 
                    (opp.chain or "Unknown") .. " (" .. (opp.completion_percent or 0) .. "%)", 
                    "INFO")
            end
        end
        if opp_count > 5 then
            DebugLog("Opportunities", "... and " .. (opp_count - 5) .. " more", "INFO")
        end
        DebugLog("GetChainOpportunities()", "Total opportunities: " .. opp_count, opp_count > 0 and "SUCCESS" or "INFO")
    else
        DebugLog("GetChainOpportunities()", "FAILED: " .. tostring(opps), "ERROR")
        all_ok = false
    end
    
    print()
    
    -- STEP 7: Game context
    DebugLog("STEP-" .. step, "Checking Game Context...", "INFO")
    step = step + 1
    print()
    
    if Game and Game.system then
        DebugLog("CurrentSystem", Game.system.name or "Unknown", "SUCCESS")
        DebugLog("GameTime", Game.time or "N/A", "INFO")
    else
        DebugLog("GameContext", "Not in a system (in menu or space)", "WARNING")
    end
    
    print()
    
    -- FINAL SUMMARY
    print(string.rep("=", 80))
    print("SUMMARY")
    print(string.rep("=", 80))
    print()
    
    for _, module_name in ipairs(modules_to_test) do
        if modules_loaded[module_name] then
            print("✓ " .. module_name)
        else
            print("✗ " .. module_name)
        end
    end
    
    print()
    
    if all_ok then
        print("✓✓✓ VERIFICATION COMPLETED - ALL SYSTEMS OPERATIONAL ✓✓✓")
        print()
    else
        print("✗✗✗ SOME CHECKS FAILED - SEE ABOVE FOR DETAILS ✗✗✗")
        print()
    end
    
    print(string.rep("=", 80) .. "\n")
    
    return all_ok
end

-- ============================================================================
-- WATCH: Real-time monitoring
-- ============================================================================

function QuickTest.Watch()
    print("\n" .. string.rep("=", 80))
    print("LIVE MONITORING - ECONOMY ENHANCEMENTS STATUS")
    print(string.rep("=", 80) .. "\n")
    
    local ok, E = pcall(function() return require('modules.EconomyEnhancements') end)
    if not ok or not E then
        DebugLog("WATCH", "Failed to load EconomyEnhancements: " .. tostring(E), "ERROR")
        return
    end
    
    -- Try to get system info - different ways
    local system_name = "Unknown"
    local game_time = "N/A"
    
    if Game then
        if Game.time then
            game_time = tostring(Game.time)
        end
        
        if Game.system and Game.system.name then
            system_name = Game.system.name
        elseif Game.player and Game.player.location then
            -- Try alternate path
            if Game.player.location.system and Game.player.location.system.name then
                system_name = Game.player.location.system.name
            end
        end
    end
    
    DebugLog("CurrentSystem", system_name, "INFO")
    DebugLog("GameTime", game_time, "INFO")
    
    print()
    
    -- System Events
    print(string.rep("-", 80))
    print("SYSTEM EVENTS (Active in current system)")
    print(string.rep("-", 80))
    
    local events = E.GetSystemEvents()
    local event_count = 0
    for id, event in pairs(events) do
        event_count = event_count + 1
        local desc = "Unknown"
        local ok2, desc2 = pcall(function() return E.GetSystemEventDescription(event) end)
        if ok2 then desc = desc2 end
        DebugLog("Event-" .. id, desc, "WARNING")
    end
    
    if event_count == 0 then
        DebugLog("SystemEvents", "None active (this is normal - events are probabilistic, ~0.05% chance)", "INFO")
    else
        DebugLog("ActiveEvents", event_count, "SUCCESS")
    end
    
    print()
    
    -- NPC Trade
    print(string.rep("-", 80))
    print("NPC TRADE STATUS")
    print(string.rep("-", 80))
    
    local trade = E.GetNPCTradeStatus()
    DebugLog("ActiveShipments", trade.active_shipments or 0, "INFO")
    DebugLog("DeliveredShipments", trade.delivered_shipments or 0, "INFO")
    DebugLog("DestroyedShipments", trade.destroyed_shipments or 0, trade.destroyed_shipments and trade.destroyed_shipments > 0 and "WARNING" or "INFO")
    DebugLog("TotalTradeValue", (trade.total_value or 0) .. " credits", "INFO")
    
    if trade.destroyed_shipments > 0 then
        DebugLog("NOTE", "Destroyed shipments affect market prices locally!", "SUCCESS")
    end
    
    print()
    
    -- Supply Chain Opportunities
    print(string.rep("-", 80))
    print("SUPPLY CHAIN OPPORTUNITIES")
    print(string.rep("-", 80))
    
    local opps = E.GetChainOpportunities()
    if #opps == 0 then
        DebugLog("Opportunities", "None available yet", "INFO")
    else
        for i, opp in ipairs(opps) do
            if i <= 5 then
                local profit_msg = "Profit: " .. ((opp.base_profit or 0) * 100) .. "%"
                DebugLog("Chain-" .. i, 
                    (opp.chain or "Unknown") .. " (" .. (opp.completion_percent or 0) .. "%) - " .. profit_msg, 
                    "INFO")
            end
        end
        
        if #opps > 5 then
            DebugLog("TotalOpportunities", #opps .. " total (" .. (#opps - 5) .. " more not shown)", "SUCCESS")
        else
            DebugLog("TotalOpportunities", #opps, "SUCCESS")
        end
    end
    
    print()
    
    -- Module Status
    print(string.rep("-", 80))
    print("MODULE STATUS")
    print(string.rep("-", 80))
    
    DebugLog("Enabled", tostring(E.IsEnabled()), "SUCCESS")
    DebugLog("Version", E.GetVersion(), "INFO")
    
    print()
    print(string.rep("=", 80) .. "\n")
    
    print("TIPS:")
    print("- Run this command repeatedly to see changes in real-time")
    print("- Destroyed shipments will trigger economic effects")
    print("- Events appear rarely - travel to many systems to see them")
    print("- Supply chains show profit opportunities for trading\n")
end

-- ============================================================================
-- INSPECT: Detailed module introspection
-- ============================================================================

function QuickTest.Inspect()
    print("\n" .. string.rep("=", 80))
    print("DETAILED MODULE INSPECTION")
    print(string.rep("=", 80) .. "\n")
    
    local ok, E = pcall(function() return require('modules.EconomyEnhancements') end)
    if not ok or not E then
        DebugLog("INSPECT", "Failed to load module", "ERROR")
        return
    end
    
    -- Inspect DynamicSystemEvents
    print(string.rep("-", 80))
    print("DYNAMIC SYSTEM EVENTS - DETAILS")
    print(string.rep("-", 80))
    
    local events = E.GetSystemEvents()
    print("Event storage: " .. tostring(type(events)) .. " with elements")
    
    local event_count = 0
    for id, event in pairs(events) do
        event_count = event_count + 1
        if event_count <= 10 then
            DebugLog("Event", 
                (event.event_type or "Unknown") .. " - Severity: " .. 
                ((event.severity or 0) * 100) .. "%", 
                "INFO")
        end
    end
    
    if event_count > 10 then
        DebugLog("TotalEvents", "... and " .. (event_count - 10) .. " more", "INFO")
    end
    
    if event_count == 0 then
        DebugLog("Events", "None active", "INFO")
    end
    
    print()
    
    -- Inspect SupplyChainNetwork
    print(string.rep("-", 80))
    print("SUPPLY CHAIN NETWORK - DETAILS")
    print(string.rep("-", 80))
    
    local chains = E.GetSupplyChains()
    for i, chain in ipairs(chains) do
        DebugLog("Chain-" .. i, 
            (chain.name or "Unknown") .. " (Base Profit: " .. 
            ((chain.base_profit or 0) * 100) .. "%, Nodes: " .. 
            (#(chain.nodes or {})) .. ")", 
            "INFO")
    end
    
    print()
    
    -- Inspect trade dependencies
    print(string.rep("-", 80))
    print("NPC TRADE - DEPENDENCIES")
    print(string.rep("-", 80))
    
    local deps = E.GetRegionalDependencies()
    local dep_count = 0
    for system, dependency in pairs(deps) do
        dep_count = dep_count + 1
        if dep_count <= 10 then
            DebugLog("Dependency", 
                (system or "Unknown") .. " -> " .. (dependency.target or "Unknown"),
                "INFO")
        end
    end
    
    if dep_count > 10 then
        DebugLog("TotalDependencies", dep_count, "INFO")
    end
    
    if dep_count == 0 then
        DebugLog("Dependencies", "None recorded yet", "INFO")
    end
    
    print()
    
    -- Damaged cargo impact
    print(string.rep("-", 80))
    print("DAMAGED CARGO - ECONOMIC IMPACT")
    print(string.rep("-", 80))
    
    local damaged = E.GetDamagedCargo()
    local damage_count = 0
    for system, impact in pairs(damaged) do
        damage_count = damage_count + 1
        if damage_count <= 10 then
            DebugLog("DamagedSystem", 
                (system or "Unknown") .. ": " .. (impact.value_lost or 0) .. " credits lost",
                "WARNING")
        end
    end
    
    if damage_count > 10 then
        DebugLog("TotalDamaged", damage_count, "INFO")
    end
    
    if damage_count == 0 then
        DebugLog("DamageCargo", "None destroyed yet", "INFO")
    end
    
    print()
    print(string.rep("=", 80) .. "\n")
end

-- ============================================================================
-- STRESS: Automated stability test
-- ============================================================================

function QuickTest.Stress()
    print("\n" .. string.rep("=", 80))
    print("STRESS TEST - MODULE STABILITY CHECK")
    print(string.rep("=", 80) .. "\n")
    
    local ok, E = pcall(function() return require('modules.EconomyEnhancements') end)
    if not ok or not E then
        DebugLog("STRESS", "Failed to load module", "ERROR")
        return false
    end
    
    local iterations = 100
    local errors = 0
    
    print("Running " .. iterations .. " calls to each function...\n")
    
    local functions_to_test = {
        { name = "GetVersion", fn = function() return E.GetVersion() end },
        { name = "IsEnabled", fn = function() return E.IsEnabled() end },
        { name = "GetStatus", fn = function() return E.GetStatus() end },
        { name = "GetSystemEvents", fn = function() return E.GetSystemEvents() end },
        { name = "GetNPCTradeStatus", fn = function() return E.GetNPCTradeStatus() end },
        { name = "GetSupplyChains", fn = function() return E.GetSupplyChains() end },
        { name = "GetChainOpportunities", fn = function() return E.GetChainOpportunities() end },
    }
    
    for _, func_test in ipairs(functions_to_test) do
        local local_errors = 0
        for i = 1, iterations do
            local ok2, result = pcall(func_test.fn)
            if not ok2 then
                local_errors = local_errors + 1
                errors = errors + 1
            end
        end
        
        local status = local_errors == 0 and "SUCCESS" or "ERROR"
        local msg = string.format("%s: %d/%d OK", func_test.name, iterations - local_errors, iterations)
        DebugLog("StressTest", msg, status)
    end
    
    print()
    
    if errors == 0 then
        print("✓✓✓ STRESS TEST PASSED - ALL FUNCTIONS STABLE ✓✓✓")
    else
        print("✗✗✗ STRESS TEST FAILED - " .. errors .. " ERRORS DETECTED ✗✗✗")
    end
    
    print()
    print(string.rep("=", 80) .. "\n")
    
    return errors == 0
end

-- ============================================================================
-- DEBUG: Quick debug information
-- ============================================================================

function QuickTest.Debug()
    print("\n" .. string.rep("=", 80))
    print("QUICK DEBUG - GAME STATE")
    print(string.rep("=", 80) .. "\n")
    
    -- Load module
    local ok, E = pcall(function() return require('modules.EconomyEnhancements') end)
    if not ok or not E then
        print("[ERROR] Cannot load EconomyEnhancements")
        return
    end
    
    print("Module Status:")
    print("  Enabled: " .. tostring(E.IsEnabled()))
    print("  Version: " .. E.GetVersion())
    
    print("\nGame Context:")
    
    if Game then
        print("  Game object: AVAILABLE")
        
        if Game.time then
            print("  Game.time: " .. tostring(Game.time))
        else
            print("  Game.time: NIL")
        end
        
        if Game.system then
            print("  Game.system: AVAILABLE")
            print("    Name: " .. (Game.system.name or "Unknown"))
            print("    Path: " .. (Game.system.path or "Unknown"))
        else
            print("  Game.system: NIL (trying alternates...)")
        end
        
        if Game.player then
            print("  Game.player: AVAILABLE")
            if Game.player.location then
                print("    Location: AVAILABLE")
            end
        end
    else
        print("  Game object: NOT AVAILABLE")
    end
    
    print("\nData Summary:")
    
    local events = E.GetSystemEvents()
    local event_count = 0
    for _ in pairs(events) do event_count = event_count + 1 end
    print("  Active Events: " .. event_count)
    
    local trade = E.GetNPCTradeStatus()
    print("  Trade Shipments: " .. (trade.active_shipments or 0))
    print("  Destroyed Shipments: " .. (trade.destroyed_shipments or 0))
    
    local opps = E.GetChainOpportunities()
    print("  Chain Opportunities: " .. #opps)
    
    print("\nDEBUG TIPS:")
    print("- If Game.system is NIL, you may be in menu or transitioning")
    print("- Try moving to a different system")
    print("- Run Watch() again to refresh")
    
    print("\n" .. string.rep("=", 80) .. "\n")
end

return QuickTest
