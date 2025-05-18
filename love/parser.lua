-- parser.lua
local Logger = require("logger")
local Helpers = require("helpers")

local Parser = {
    -- ANSI color codes
    BRIGHT_BLUE = 96,  -- \27[96m
    RESET = 0,        -- \27[0m
    
    -- connectionStateTable.localView = {
    --        currentRoom = nil,
    --        characterStats = {},
    --},
    
    -- Initialize the parser
    init = function(self)

    end,
    
    -- Parse a line of text and update state
    -- Returns true if the line should be displayed
    parse = function(self, line, connId, connectionStateTable)
        -- Log the raw line for debugging
        --Logger.debug("PARSING LINE: " .. line:gsub("\27", "ESC"))

        -- THESE STATES PARSE THEIR OWN LOGIC
        if(connectionStateTable.state.name == "Login") then
            return false
        end
        
        -- COMMON PARSING LOGIC

        -- Look for bright blue text (room name)
        -- Match the exact pattern we see in the raw log
        local start = line:find("\27%[1m\27%[36m")
        if start then
            local end_pos = line:find("\27%[0m", start)
            if end_pos then
                -- Extract the room name (text between the color codes)
                -- Skip the ANSI sequence which is 10 characters
                local roomName = line:sub(start + 9, end_pos - 1)
                --Logger.debug("Found room name between positions " .. (start + 9) .. " and " .. (end_pos - 1))
                Logger.debug("[Parser] Extracted room name: '" .. roomName .. "'")
                connectionStateTable.localView.currentRoom = roomName
                return true  -- Indicates we found and parsed a room name
            end
        end

        -- Parse stat bar using our helper function
        if is_stat_pattern(line, connectionStateTable) then
            return false  -- Don't display the stat bar
        end
        
        return true  -- No room name or stats found in this line
    end,
}

return Parser 