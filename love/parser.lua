-- parser.lua
local Logger = require("logger")

local Parser = {
    -- ANSI color codes
    BRIGHT_BLUE = 96,  -- \27[96m
    RESET = 0,        -- \27[0m
    
    -- Current state
    currentRoom = nil,
    
    -- Initialize the parser
    init = function(self)
        self.currentRoom = nil
    end,
    
    -- Parse a line of text and update state
    parse = function(self, line)
        -- Log the raw line for debugging
        Logger.debug("PARSING LINE: " .. line:gsub("\27", "ESC"))
        
        -- Look for bright blue text (room name)
        -- Match the exact pattern we see in the raw log
        local start = line:find("\27%[1m\27%[36m")
        if start then
            local end_pos = line:find("\27%[0m", start)
            if end_pos then
                -- Extract the room name (text between the color codes)
                -- Skip the ANSI sequence which is 10 characters
                local roomName = line:sub(start + 9, end_pos - 1)
                Logger.debug("Found room name between positions " .. (start + 9) .. " and " .. (end_pos - 1))
                Logger.debug("Extracted room name: '" .. roomName .. "'")
                self.currentRoom = roomName
                return true  -- Indicates we found and parsed a room name
            end
        end
        return false  -- No room name found in this line
    end,
    
    -- Get the current room name
    getCurrentRoom = function(self)
        return self.currentRoom
    end
}

return Parser 