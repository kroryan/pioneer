--------------------------------------------------------
-- Cool Events Log / init.lua
--------------------------------------------------------

local Event      = require 'Event'
local Game       = require 'Game'
local FileSystem = require 'FileSystem'

local LOG_DIR  = "user://mods/eventlog"
local LOG_PATH = "user://mods/eventlog/event_log.txt"

-- Ensure the directory exists on first load
local dir_ok, dir_err = pcall(function() FileSystem.MakeDirectory(LOG_DIR) end)
if not dir_ok then
    print("[eventlog] Could not create log directory: " .. tostring(dir_err))
end

local function log(msg)
    local ok, f_or_err = pcall(io.open, LOG_PATH, "a")
    if ok and f_or_err then
        f_or_err:write(msg .. "\n")
        f_or_err:close()
    else
        print("[eventlog] " .. tostring(msg))
    end
end

------------
-- COOL EVENTS
------------

Event.Register("onGameStart", function()
    log("Welcome back, pilot")
end)

Event.Register("onShipLanded", function(ship, body)
    if ship:IsPlayer() and body then
        log("Landed on " .. body.label)
    end
end)

Event.Register("onShipTakeoff", function(ship, body)
    if ship:IsPlayer() and body then
        log("Taking off from " .. body.label)
    end
end)

Event.Register("onShipDocked", function(ship, station)
    if ship:IsPlayer() and station then
        log("Welcome to " .. station.label)
    end
end)

Event.Register("onShipUndocked", function(ship, station)
    if ship:IsPlayer() and station then
        log("Undocked from " .. station.label)
    end
end)

Event.Register("onEnterHyperspace", function(ship, target)
    if ship:IsPlayer() and target then
        log("Hyperspace to " .. target.path:GetStarSystem().name)
    end
end)

Event.Register("onEnterSystem", function(ship)
    if ship:IsPlayer() and Game.system then
        log("Entered " .. Game.system.name)
    end
end)

Event.Register("onShipCollided", function(ship, other)
    if ship:IsPlayer() then
        log("HIT!")
    end
end)

Event.Register("onJettison", function(ship, cargo)
    if ship:IsPlayer() and cargo then
        log("Jettisoned " .. cargo:GetName())
    end
end)
