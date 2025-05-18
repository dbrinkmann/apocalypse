-- main.lua
local socket = require("socket")
local GameWorld = require("game_world")
local Parser = require("parser")
local Logger = require("logger")

-- Game window config
local gameWin = {
    width = 1200,
    height = 800,
    title = "Apocalypse",
    background = nil,
    camera = {
        x = 0,
        y = 0,
        scale = 1
    }
}

-- UI Window management
local uiWindows = {}
local activeWindow = nil
local windowZOrder = {}

-- Each connection represents one MUD session
local connections = {}
local inputBuffer = ""
local messages = {}
local font, fontHeight
local roomNameFont = nil  -- New font for room name
local scrollOffset = 0
local maxLines = 30
local cursorTimer = 0
local cursorVisible = true
local splashImage = nil
local showSplash = true

-- ANSI color map (basic)
local ansi_color_map = {
    [30] = {0,0,0},        -- Black
    [31] = {1,0,0},        -- Red
    [32] = {0,1,0},        -- Green
    [33] = {1,1,0},        -- Yellow
    [34] = {0,0,1},        -- Blue
    [35] = {1,0,1},        -- Magenta
    [36] = {0,1,1},        -- Cyan
    [37] = {1,1,1},        -- White
    [90] = {0.5,0.5,0.5},  -- Bright Black (Gray)
    [91] = {1,0.3,0.3},    -- Bright Red
    [92] = {0.3,1,0.3},    -- Bright Green
    [93] = {1,1,0.5},      -- Bright Yellow
    [94] = {0.3,0.3,1},    -- Bright Blue
    [95] = {1,0.3,1},      -- Bright Magenta
    [96] = {0.3,1,1},      -- Bright Cyan
    [97] = {1,1,1},        -- Bright White
}

-- UI Window class
local UIWindow = {
    width = 900,
    height = 600,
    barHeight = 36,
    x = 0,
    y = 0,
    dragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,
    resizing = false,
    resizeOffsetX = 0,
    resizeOffsetY = 0,
    minWidth = 300,
    minHeight = 200,
    title = "",
    visible = true,
    zIndex = 0
}

function UIWindow:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function UIWindow:isPointInside(x, y)
    return x >= self.x and x <= self.x + self.width and
           y >= self.y and y <= self.y + self.height
end

function UIWindow:isTitleBar(x, y)
    return x >= self.x and x <= self.x + self.width and
           y >= self.y and y <= self.y + self.barHeight
end

function UIWindow:isResizeHandle(x, y)
    local handleSize = 20
    return x >= self.x + self.width - handleSize and x <= self.x + self.width and
           y >= self.y + self.height - handleSize and y <= self.y + self.height
end

function UIWindow:draw()
    if not self.visible then return end
    
    -- Draw window background
    love.graphics.setColor(0.08, 0.09, 0.12, 0.98)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 16, 16)
    
    -- Draw title bar
    love.graphics.setColor(0.18, 0.19, 0.25, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.barHeight, 16, 16)
    
    -- Draw title text
    love.graphics.setColor(1,1,1,1)
    love.graphics.setFont(font)
    love.graphics.print(self.title, self.x + 16, self.y + 8)
    
    -- Draw border
    love.graphics.setColor(0.3,0.3,0.4,1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 16, 16)
    love.graphics.setLineWidth(1)
    
    -- Draw resize handle (bottom-right corner)
    local handleSize = 20
    love.graphics.setColor(0.7,0.7,1,1)
    love.graphics.rectangle("fill", self.x + self.width - handleSize, self.y + self.height - handleSize, handleSize, handleSize, 4, 4)
    love.graphics.setColor(1,1,1,1)
end

-- Create terminal window
local termWin = UIWindow:new({
    title = "Terminal",
    x = 50,
    y = 50
})
table.insert(uiWindows, termWin)

-- Game world state
local gameWorld = {
    background = nil,
    entities = {},
    items = {}
}

-- Center window on screen
local function centerWindow()
    local winW, winH = love.graphics.getWidth(), love.graphics.getHeight()
    termWin.x = (winW - termWin.width) / 2
    termWin.y = (winH - termWin.height) / 2
end

local function getWindowPos()
    return termWin.x, termWin.y
end

-- Parse ANSI color codes and return a table of {text, color} segments
local function parse_ansi(str)
    local segments = {}
    local last_end = 1
    local cur_color = {1,1,1}
    for start_idx, sgr, end_idx in str:gmatch '()(\27%[[^m]*m)()' do
        if start_idx > last_end then
            table.insert(segments, {text = str:sub(last_end, start_idx-1), color = cur_color})
        end
        -- Parse SGR codes (e.g., \27[1;31m)
        local codes = {}
        for code in sgr:gmatch('%d+') do
            table.insert(codes, tonumber(code))
        end
        for _, code in ipairs(codes) do
            if code == 0 or code == 39 then
                cur_color = {1,1,1}
            elseif ansi_color_map[code] then
                cur_color = ansi_color_map[code]
            end
        end
        last_end = end_idx
    end
    if last_end <= #str then
        table.insert(segments, {text = str:sub(last_end), color = cur_color})
    end
    return segments
end

-- Function to sanitize UTF-8 string
local function sanitize_utf8(str)
    if not str then return "[Empty data]" end
    if type(str) ~= "string" then return "[Non-string data]" end
    
    -- Replace invalid UTF-8 sequences with replacement character
    local result = ""
    local i = 1
    while i <= #str do
        local byte = string.byte(str, i)
        if byte < 0x80 then
            -- ASCII character
            result = result .. string.char(byte)
            i = i + 1
        elseif byte < 0xC2 then
            -- Invalid start byte
            result = result .. ""
            i = i + 1
        elseif byte < 0xE0 then
            -- 2-byte sequence
            if i + 1 <= #str then
                local byte2 = string.byte(str, i + 1)
                if byte2 and byte2 >= 0x80 and byte2 < 0xC0 then
                    result = result .. string.sub(str, i, i + 1)
                    i = i + 2
                else
                    result = result .. ""
                    i = i + 1
                end
            else
                result = result .. ""
                i = i + 1
            end
        elseif byte < 0xF0 then
            -- 3-byte sequence
            if i + 2 <= #str then
                local byte2 = string.byte(str, i + 1)
                local byte3 = string.byte(str, i + 2)
                if byte2 and byte3 and 
                   byte2 >= 0x80 and byte2 < 0xC0 and
                   byte3 >= 0x80 and byte3 < 0xC0 then
                    result = result .. string.sub(str, i, i + 2)
                    i = i + 3
                else
                    result = result .. ""
                    i = i + 1
                end
            else
                result = result .. ""
                i = i + 1
            end
        elseif byte < 0xF5 then
            -- 4-byte sequence
            if i + 3 <= #str then
                local byte2 = string.byte(str, i + 1)
                local byte3 = string.byte(str, i + 2)
                local byte4 = string.byte(str, i + 3)
                if byte2 and byte3 and byte4 and
                   byte2 >= 0x80 and byte2 < 0xC0 and
                   byte3 >= 0x80 and byte3 < 0xC0 and
                   byte4 >= 0x80 and byte4 < 0xC0 then
                    result = result .. string.sub(str, i, i + 3)
                    i = i + 4
                else
                    result = result .. ""
                    i = i + 1
                end
            else
                result = result .. ""
                i = i + 1
            end
        else
            -- Invalid start byte
            result = result .. ""
            i = i + 1
        end
    end
    return result
end

-- Create a coroutine for each connection
local function createConnection(host, port)
    local conn = {
        host = host,
        port = port,
        tcp = assert(socket.tcp()),
        coroutine = nil,
        incoming = {},
        outgoing = {},
        status = "connecting",
        lastAttempt = 0,
        retryDelay = 5  -- seconds between retry attempts
    }
    conn.tcp:settimeout(5)  -- 5 second timeout for connection attempts
    
    -- Try to connect and handle errors
    local success, err = conn.tcp:connect(host, port)
    if not success then
        conn.status = "failed to connect: " .. tostring(err)
        Logger.debug("Connection failed to " .. host .. ":" .. port .. ": " .. tostring(err))
        conn.tcp:close()
        return conn
    end
    
    conn.status = "connected"
    Logger.debug("Successfully connected to " .. host .. ":" .. port)
    conn.tcp:settimeout(0)  -- Set back to non-blocking for normal operation

    conn.coroutine = coroutine.create(function()
        while true do
            -- Send outgoing messages
            if #conn.outgoing > 0 then
                local msg = table.remove(conn.outgoing, 1)
                local success, err = conn.tcp:send(msg .. "\n")
                if not success then
                    table.insert(conn.incoming, "[ERROR] Failed to send message: " .. tostring(err))
                    conn.status = "error: " .. tostring(err)
                    break
                end
            end
            -- Receive all available lines and handle partials
            while true do
                local line, err, partial = conn.tcp:receive("*l")
                if line then
                    Logger.debug("RECEIVED: " .. tostring(line))
                    -- Sanitize the received line before storing it
                    local sanitized = sanitize_utf8(line)
                    table.insert(conn.incoming, sanitized)
                elseif partial and partial ~= "" then
                    Logger.debug("RECEIVED (partial): " .. tostring(partial))
                    -- Sanitize the partial line before storing it
                    local sanitized = sanitize_utf8(partial)
                    table.insert(conn.incoming, sanitized)
                    break
                elseif err == "timeout" then
                    break
                else
                    break
                end
            end
            coroutine.yield()
        end
    end)

    return conn
end

-- Function to load room background
local function loadRoomBackground(roomName)
    if not roomName then return end
    
    -- Clean the room name for filename use
    local cleanName = roomName:gsub("[^%w%s]", ""):gsub("%s+", "_")
    local imagePath = "images/rooms/" .. cleanName .. ".jpg"
    
    -- Try to load the room-specific image
    local success, image = pcall(function() return love.graphics.newImage(imagePath) end)
    if success and image then
        gameWin.background = image
    else
        -- Fallback to default city image
        local defaultPath = "images/rooms/City of Midgaard.jpg"
        local success, image = pcall(function() return love.graphics.newImage(defaultPath) end)
        if success and image then
            gameWin.background = image
        else
            gameWin.background = nil
        end
    end
end

function love.load()
    love.keyboard.setKeyRepeat(true)
    -- Load monospace font for terminal
    font = love.graphics.newFont("fonts/DejaVuSansMono.ttf", 16)
    love.graphics.setFont(font)
    fontHeight = font:getHeight()
    
    -- Load fantasy font for room name
    roomNameFont = love.graphics.newFont("fonts/MedievalSharp-Regular.ttf", 48)
    
    -- Load splash image
    splashImage = love.graphics.newImage("images/splash.png")
    
    -- Load game world
    GameWorld:load()
    
    -- Initialize parser
    Parser:init()
    
    -- Initialize logger
    Logger.init()
    
    -- Try to connect to the MUD server
    local conn = createConnection("apocalypse6.com", 6000)
    table.insert(connections, conn)
    Logger.debug("Attempting to connect to apocalypse6.com:6000")
    -- Center terminal window
    centerWindow()
end

function love.update(dt)
    cursorTimer = cursorTimer + dt
    if cursorTimer >= 0.5 then
        cursorVisible = not cursorVisible
        cursorTimer = 0
    end
    
    -- Update game world
    GameWorld:update(dt)
    
    -- Update connections
    for _, conn in ipairs(connections) do
        -- Handle connection retry
        if conn.status:match("^failed to connect") or conn.status:match("^disconnected") then
            conn.lastAttempt = conn.lastAttempt + dt
            if conn.lastAttempt >= conn.retryDelay then
                Logger.debug("Retrying connection to " .. conn.host .. ":" .. conn.port)
                conn.status = "connecting"
                conn.lastAttempt = 0
                conn.tcp = assert(socket.tcp())
                conn.tcp:settimeout(5)
                local success, err = conn.tcp:connect(conn.host, conn.port)
                if success then
                    conn.status = "connected"
                    conn.tcp:settimeout(0)
                    Logger.debug("Reconnected successfully")
                    conn.coroutine = coroutine.create(function()
                        while true do
                            if #conn.outgoing > 0 then
                                local msg = table.remove(conn.outgoing, 1)
                                local success, err = conn.tcp:send(msg .. "\n")
                                if not success then
                                    table.insert(conn.incoming, "[ERROR] Failed to send message: " .. tostring(err))
                                    conn.status = "error: " .. tostring(err)
                                    break
                                end
                            end
                            local line, err = conn.tcp:receive("*l")
                            if line then
                                table.insert(conn.incoming, "" .. line)
                            elseif err ~= "timeout" and err ~= nil then
                                table.insert(conn.incoming, "[DISCONNECTED] " .. tostring(err))
                                conn.status = "disconnected: " .. tostring(err)
                                break
                            end
                            coroutine.yield()
                        end
                    end)
                else
                    conn.status = "failed to connect: " .. tostring(err)
                    Logger.debug("Retry failed: " .. tostring(err))
                    conn.tcp:close()
                end
            end
        end
        
        -- Process connection if it has a coroutine
        if conn.coroutine and coroutine.status(conn.coroutine) ~= "dead" then
            coroutine.resume(conn.coroutine)
        end
        
        -- Move incoming to global messages list
        for _, msg in ipairs(conn.incoming) do
            if type(msg) ~= "string" then
                msg = "[Non-string data]"
            end
            -- Parse the message before adding it to the display
            if Parser:parse(msg) then
                -- If we parsed a new room name, update the background
                loadRoomBackground(Parser:getCurrentRoom())
            end
            --Logger.debug("MESSAGES: " .. tostring(msg))
            table.insert(messages, msg)
            Logger.raw(msg)
        end
        conn.incoming = {}
    end
    
    -- Update terminal window title based on connection status
    local disconnected = false
    for _, conn in ipairs(connections) do
        if conn.status:match("^failed to connect") or conn.status:match("^disconnected") then
            disconnected = true
            break
        end
    end
    if disconnected then
        termWin.title = "Terminal [DISCONNECTED]"
    else
        termWin.title = "Terminal"
    end
end

function love.textinput(t)
    inputBuffer = inputBuffer .. t
end

function love.keypressed(key)
    if showSplash then
        showSplash = false
        return
    end
    if key == "return" then
        for _, conn in ipairs(connections) do
            if conn.status == "connected" then
                table.insert(conn.outgoing, inputBuffer)
            else
                table.insert(messages, "Cannot send message - " .. conn.status)
                Logger.debug("Cannot send message - " .. conn.status)
            end
        end
        local msg = "> " .. inputBuffer
        table.insert(messages, msg)
        Logger.raw(msg)
        inputBuffer = ""
        scrollOffset = 0 -- auto-scroll to bottom on input
    elseif key == "backspace" then
        inputBuffer = inputBuffer:sub(1, -2)
    elseif key == "up" then
        scrollOffset = math.min(scrollOffset + 1, math.max(0, #messages - maxLines))
    elseif key == "down" then
        scrollOffset = math.max(scrollOffset - 1, 0)
    end
end

function love.wheelmoved(x, y)
    if y > 0 then
        scrollOffset = math.min(scrollOffset + 1, math.max(0, #messages - maxLines))
    elseif y < 0 then
        scrollOffset = math.max(scrollOffset - 1, 0)
    end
end

function love.mousepressed(x, y, button)
    if showSplash then
        showSplash = false
        return
    end
    if button == 1 then
        -- Check if clicking on any window resize handle or title bar
        for _, window in ipairs(uiWindows) do
            if window:isResizeHandle(x, y) then
                window.resizing = true
                window.resizeOffsetX = x - (window.x + window.width)
                window.resizeOffsetY = y - (window.y + window.height)
                -- Bring window to front
                for i, w in ipairs(uiWindows) do
                    if w == window then
                        table.remove(uiWindows, i)
                        table.insert(uiWindows, window)
                        break
                    end
                end
                break
            elseif window:isTitleBar(x, y) then
                window.dragging = true
                window.dragOffsetX = x - window.x
                window.dragOffsetY = y - window.y
                -- Bring window to front
                for i, w in ipairs(uiWindows) do
                    if w == window then
                        table.remove(uiWindows, i)
                        table.insert(uiWindows, window)
                        break
                    end
                end
                break
            end
        end
    end
end

function love.mousemoved(x, y, dx, dy)
    for _, window in ipairs(uiWindows) do
        if window.dragging then
            window.x = x - window.dragOffsetX
            window.y = y - window.dragOffsetY
        elseif window.resizing then
            local newWidth = x - window.x - window.resizeOffsetX
            local newHeight = y - window.y - window.resizeOffsetY
            window.width = math.max(window.minWidth, newWidth)
            window.height = math.max(window.minHeight, newHeight)
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        for _, window in ipairs(uiWindows) do
            window.dragging = false
            window.resizing = false
        end
    end
end

function love.resize(w, h)
    gameWin.width = w
    gameWin.height = h
    centerWindow()
end

-- Defensive print function
local function safe_print(str, x, y)
    if type(str) ~= "string" then str = "[Non-string data]" end
    local ok, err = pcall(function() love.graphics.print(str, x, y) end)
    if not ok then Logger.debug("DRAW ERROR: " .. tostring(err)) end
end

local function safe_printf(str, x, y, limit, align)
    if type(str) ~= "string" then str = "[Non-string data]" end
    local ok, err = pcall(function() love.graphics.printf(str, x, y, limit, align) end)
    if not ok then Logger.debug("DRAW ERROR: " .. tostring(err)) end
end

function love.draw()
    if showSplash and splashImage then
        love.graphics.setColor(0,0,0,1)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        local winW, winH = love.graphics.getWidth(), love.graphics.getHeight()
        local imgW, imgH = splashImage:getWidth(), splashImage:getHeight()
        local scale = math.min(winW/imgW, winH/imgH)
        local drawW, drawH = imgW*scale, imgH*scale
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(splashImage, (winW-drawW)/2, (winH-drawH)/2, 0, scale, scale)
        return
    end
    
    -- Draw background if available
    if gameWin.background then
        love.graphics.setColor(1, 1, 1, 1)
        local winW, winH = love.graphics.getWidth(), love.graphics.getHeight()
        local imgW, imgH = gameWin.background:getWidth(), gameWin.background:getHeight()
        local scale = math.max(winW/imgW, winH/imgH)  -- Cover the entire window
        local drawW, drawH = imgW*scale, imgH*scale
        love.graphics.draw(gameWin.background, (winW-drawW)/2, (winH-drawH)/2, 0, scale, scale)
    end
    
    -- Draw game world
    GameWorld:draw()
    
    -- Draw room name at the top of the main window
    local currentRoom = Parser:getCurrentRoom()
    if currentRoom then
        -- Set up the fantasy font for room name
        love.graphics.setFont(roomNameFont)
        
        -- Draw a semi-transparent background for better readability
        local winW = love.graphics.getWidth()
        local textWidth = roomNameFont:getWidth(currentRoom)
        local textHeight = roomNameFont:getHeight()
        local padding = 20
        
        -- Draw background rectangle
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 
            (winW - textWidth)/2 - padding, 
            20 - padding/2, 
            textWidth + padding*2, 
            textHeight + padding, 
            10, 10)
        
        -- Draw room name with a fantasy style
        love.graphics.setColor(0.8, 0.8, 1, 1)  -- Slightly purple tint
        safe_print(currentRoom, (winW - textWidth) / 2, 20)
        
        -- Reset font for rest of the UI
        love.graphics.setFont(font)
        --Logger.debug("DISPLAYING ROOM: " .. currentRoom)
    end
    
    -- Draw UI windows
    for _, window in ipairs(uiWindows) do
        window:draw()
    end
    
    -- Draw terminal content
    local contentX = termWin.x + 16
    local contentY = termWin.y + termWin.barHeight + 8
    
    -- Draw current room name if available
    --local currentRoom = Parser:getCurrentRoom()
    --if currentRoom then
    --    love.graphics.setColor(0.3, 0.3, 1, 1)  -- Bright blue color
    --    safe_print("Current Room: " .. currentRoom, contentX, contentY)
    --    contentY = contentY + fontHeight + 8  -- Add some spacing after room name
    --end
    
    -- Calculate available width for input
    local availableWidth = termWin.width - 32
    local inputText = inputBuffer .. (cursorVisible and "_" or " ")
    local wrappedText, wrappedLines = font:getWrap(inputText, availableWidth)
    local inputHeight = #wrappedLines * fontHeight
    -- Position input at the bottom of the window
    local inputY = termWin.y + termWin.height - inputHeight - 16
    safe_printf(inputText, contentX, inputY, availableWidth, "left")
    -- Calculate the area above the input for status and messages
    local belowInputY = inputY
    -- Draw messages with ANSI color parsing
    local y = termWin.y + termWin.barHeight + 8
    local maxLinesInWin = math.floor((belowInputY - y - 24) / fontHeight)
    local startIdx = math.max(1, #messages - maxLinesInWin - scrollOffset + 1)
    local endIdx = math.max(1, #messages - scrollOffset)
    for i = startIdx, endIdx do
        local msg = messages[i]
        if msg then
            local x = contentX
            love.graphics.setColor(1, 1, 1, 1)
            for _, seg in ipairs(parse_ansi(msg)) do
                love.graphics.setColor(seg.color)
                safe_print(seg.text, x, y)
                x = x + font:getWidth(seg.text)
            end
            y = y + fontHeight
        end
    end
    love.graphics.setColor(1,1,1,1)
end

-- Clean up when the game closes
function love.quit()
    Logger.close()
    -- Close all connections
    for _, conn in ipairs(connections) do
        if conn.tcp then
            conn.tcp:close()
        end
    end
end
