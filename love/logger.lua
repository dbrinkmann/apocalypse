-- logger.lua
local Logger = {
    rawLogFile = nil,
    debugLogFile = nil
}

function Logger.init()
    -- Open raw log file for writing raw MUD output
    Logger.rawLogFile = io.open("raw.log", "w")
    if not Logger.rawLogFile then
        error("Could not open raw.log file for writing")
    end
    
    -- Open debug log file for writing debug messages
    Logger.debugLogFile = io.open("debug.log", "w")
    if not Logger.debugLogFile then
        error("Could not open debug.log file for writing")
    end
end

function Logger.raw(text)
    if Logger.rawLogFile then
        Logger.rawLogFile:write(text .. "\n")
        Logger.rawLogFile:flush()
    end
end

function Logger.debug(text)
    if Logger.debugLogFile then
        Logger.debugLogFile:write(text .. "\n")
        Logger.debugLogFile:flush()
    end
end

function Logger.close()
    if Logger.rawLogFile then
        Logger.rawLogFile:close()
        Logger.rawLogFile = nil
    end
    if Logger.debugLogFile then
        Logger.debugLogFile:close()
        Logger.debugLogFile = nil
    end
end

return Logger 