-- DIAGNÓSTICO AVANZADO
-- En consola: require('modules.Diagnostico').Run()

local Diagnostico = {}

function Diagnostico.Run()
    print("\n" .. string.rep("=", 70))
    print("DIAGNÓSTICO DETALLADO - ECONOMY ENHANCEMENTS")
    print(string.rep("=", 70) .. "\n")

    local paso = 1
    
    -- PASO 1: Verificar que los archivos existen intentando cargarlos individualmente
    print("[PASO " .. paso .. "] Verificando carga de cada módulo:\n")
    paso = paso + 1
    
    local modulos = {
        'DynamicSystemEvents',
        'PersistentNPCTrade',
        'SupplyChainNetwork',
        'EconomyEnhancements'
    }
    
    local modulos_cargados = {}
    
    for i, mod_name in ipairs(modulos) do
        local ok, resultado = pcall(function()
            return require('modules.' .. mod_name)
        end)
        
        if ok then
            print("  [" .. i .. "] ✓ " .. mod_name .. " CARGADO OK")
            modulos_cargados[mod_name] = resultado
        else
            print("  [" .. i .. "] ✗ " .. mod_name .. " ERROR:")
            print("      " .. tostring(resultado))
            modulos_cargados[mod_name] = nil
        end
    end
    
    print()
    
    -- PASO 2: Si EconomyEnhcements cargó, intentar usar sus funciones
    print("[PASO " .. paso .. "] Probando funciones de EconomyEnhancements:\n")
    paso = paso + 1
    
    if modulos_cargados['EconomyEnhancements'] then
        local E = modulos_cargados['EconomyEnhancements']
        
        -- Probar cada función
        local funciones = {
            { nombre = 'IsEnabled', fn = function() return E.IsEnabled() end },
            { nombre = 'GetVersion', fn = function() return E.GetVersion() end },
            { nombre = 'GetSystemEvents', fn = function() return E.GetSystemEvents() end },
            { nombre = 'GetChainOpportunities', fn = function() return E.GetChainOpportunities() end },
        }
        
        for i, func_test in ipairs(funciones) do
            local ok, resultado = pcall(func_test.fn)
            if ok then
                print("  ✓ " .. func_test.nombre .. "() = " .. tostring(resultado))
            else
                print("  ✗ " .. func_test.nombre .. "() ERROR: " .. tostring(resultado))
            end
        end
    else
        print("  ⚠ EconomyEnhancements no cargó, saltando pruebas de función\n")
    end
    
    print()
    
    -- PASO 3: Información del sistema
    print("[PASO " .. paso .. "] Información del sistema:\n")
    paso = paso + 1
    
    if Game and Game.system then
        print("  ✓ Estás en sistema: " .. (Game.system.name or "Desconocido"))
        print("  ✓ Tiempo de juego: " .. (Game.time or "N/A"))
    else
        print("  ⚠ No estás en un sistema (estás en menú o espacio vacío)")
    end
    
    print()
    
    -- RESUMEN FINAL
    print(string.rep("=", 70))
    print("RESUMEN:")
    print(string.rep("=", 70) .. "\n")
    
    local todo_bien = true
    for _, mod_name in ipairs(modulos) do
        if modulos_cargados[mod_name] then
            print("✓ " .. mod_name)
        else
            print("✗ " .. mod_name)
            todo_bien = false
        end
    end
    
    print()
    
    if todo_bien then
        print("✓✓✓ TODOS LOS MÓDULOS CARGAN CORRECTAMENTE ✓✓✓\n")
        
        if modulos_cargados['EconomyEnhancements'] then
            local E = modulos_cargados['EconomyEnhancements']
            if E.IsEnabled() then
                print("✓✓✓ SISTEMA ACTIVO Y FUNCIONANDO ✓✓✓\n")
            else
                print("⚠⚠⚠ Módulos cargan pero el sistema NO está activo\n")
            end
        end
    else
        print("✗✗✗ HAY ERRORES EN LA CARGA ✗✗✗\n")
        print("POSIBLES SOLUCIONES:")
        print("1. Verifica que los archivos estén en pioneer/data/modules/")
        print("2. Revisa el nombre exacto de los archivos")
        print("3. Busca errores de sintaxis en los módulos\n")
    end
    
    print(string.rep("=", 70) .. "\n")
    
    return todo_bien
end

-- Función para ver el estado en tiempo real
function Diagnostico.Estado()
    print("\n[ESTADO EN VIVO]\n")
    
    -- Intentar cargar
    local ok, E = pcall(function()
        return require('modules.EconomyEnhancements')
    end)
    
    if not ok then
        print("❌ Error al cargar EconomyEnhancements: " .. tostring(E) .. "\n")
        return
    end
    
    print("✓ Módulo cargado correctamente\n")
    
    if not Game.system then
        print("⚠ No estás en un sistema\n")
        return
    end
    
    print("Sistema: " .. Game.system.name)
    print("Hora: " .. Game.time .. "\n")
    
    -- Eventos
    local events = E.GetSystemEvents()
    local evento_count = 0
    for _ in pairs(events) do evento_count = evento_count + 1 end
    print("Eventos activos: " .. evento_count)
    for id, event in pairs(events) do
        print("  - " .. E.GetEventDescription(event))
    end
    
    print()
    
    -- Cadenas
    local chains = E.GetChainOpportunities()
    print("Oportunidades de cadena: " .. #chains)
    for i, chain in ipairs(chains) do
        print(string.format("  %d. %s (%.1f%% completada)", i, chain.chain, chain.completion_percent))
    end
    
    print()
    
    -- Trade
    local trade = E.GetNPCTradeStatus()
    print("Comercio NPC:")
    print("  Activos: " .. trade.active_shipments)
    print("  Destruidos: " .. trade.destroyed_shipments)
    print("  Entregados: " .. trade.delivered_shipments)
    print()
end

return Diagnostico
