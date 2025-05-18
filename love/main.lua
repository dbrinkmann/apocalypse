-- main.lua
local socket = require("socket")
local GameWorld = require("game_world")
local Parser = require("parser")
local Logger = require("logger")

-- Login states
local LOGIN_STATE = {
    INITIAL = 0,
    SENT_NAME = 1,
    SENT_PASSWORD = 2,
    SENT_EMPTY = 3,
    WAITING_RECONNECT = 4,
    SENT_RECONNECT = 5,
    WAITING_WELCOME = 6,
    SENT_MENU_CHOICE = 7,
    COMPLETE = 8
}

-- Game window config
local gameWin = {
    width = 1200,
    height = 800,
    title = "Apocalypse",
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
local inputBuffers = {}  -- Changed to table to store input buffer per connection
local messages = {}  -- Changed to table to store messages per connection
local loginStates = {}  -- Track login state for each connection
local loginConfig = {}  -- Store login credentials from config
local font, fontHeight
local roomNameFont = nil  -- New font for room name
local scrollOffsets = {}  -- Changed to table to store scroll offset per connection
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
    zIndex = 0,
    id = nil  -- Added id field
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

-- Center window on screen
local function centerWindow()
    local winW, winH = love.graphics.getWidth(), love.graphics.getHeight()
    for _, window in ipairs(uiWindows) do
        window.x = (winW - window.width) / 2
        window.y = (winH - window.height) / 2
    end
end

local function getWindowPos()
    if #uiWindows > 0 then
        return uiWindows[1].x, uiWindows[1].y
    end
    return 0, 0
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

-- Function to load login config
local function loadLoginConfig()
    local file = io.open("config.txt", "r")
    if not file then
        Logger.debug("Failed to open config.txt")
        return
    end
    
    for line in file:lines() do
        local key, value = line:match("([^=]+)=(.+)")
        if key and value then
            loginConfig[key] = value
        end
    end
    file:close()
end

-- Initialize connection-specific data
local function initConnectionData(connId)
    inputBuffers[connId] = ""
    messages[connId] = {}
    scrollOffsets[connId] = 0
    loginStates[connId] = LOGIN_STATE.INITIAL
end

-- Function to handle login process
local function handleLogin(conn, msg)
    if loginStates[conn.id] == LOGIN_STATE.INITIAL then
        -- Send character name
        table.insert(conn.outgoing, loginConfig["conn" .. conn.id .. "_character"])
        loginStates[conn.id] = LOGIN_STATE.SENT_NAME
        --Logger.debug("[LOGIN]["..conn.id.."] SENDING NAME")
    elseif loginStates[conn.id] == LOGIN_STATE.SENT_NAME then
        -- Send password
        table.insert(conn.outgoing, loginConfig["conn" .. conn.id .. "_password"])
        loginStates[conn.id] = LOGIN_STATE.SENT_PASSWORD
        --Logger.debug("[LOGIN]["..conn.id.."] SENDING PASSWORD")
    elseif loginStates[conn.id] == LOGIN_STATE.SENT_PASSWORD then
        -- Send empty line
        table.insert(conn.outgoing, "")
        loginStates[conn.id] = LOGIN_STATE.SENT_EMPTY
        --Logger.debug("[LOGIN]["..conn.id.."] SENDING EMPTY LINE")
    elseif loginStates[conn.id] == LOGIN_STATE.SENT_EMPTY then
        if msg:match("Reconnecting.") or msg:match("You take over your own body, already in use!") then
            loginStates[conn.id] = LOGIN_STATE.WAITING_RECONNECT
        elseif msg:match("Welcome to Apocalypse VI!") then
            table.insert(conn.outgoing, "")
            loginStates[conn.id] = LOGIN_STATE.WAITING_WELCOME
        end
    elseif loginStates[conn.id] == LOGIN_STATE.WAITING_RECONNECT then
        -- Send 'l' for reconnect
        table.insert(conn.outgoing, "l")
        loginStates[conn.id] = LOGIN_STATE.COMPLETE
    elseif loginStates[conn.id] == LOGIN_STATE.WAITING_WELCOME then
        -- Send menu choice '1'
        --Logger.debug("[LOGIN]["..conn.id.."] SENDING MENU CHOICE 1")
        table.insert(conn.outgoing, "1")
        loginStates[conn.id] = LOGIN_STATE.SENT_MENU_CHOICE
    elseif loginStates[conn.id] == LOGIN_STATE.SENT_MENU_CHOICE then
        -- Login complete
        --Logger.debug("[LOGIN]["..conn.id.."] LOGIN COMPLETE")
        loginStates[conn.id] = LOGIN_STATE.COMPLETE
    end
end

-- Create a coroutine for each connection
local function createConnection(host, port, connId)
    local conn = {
        host = host,
        port = port,
        tcp = assert(socket.tcp()),
        coroutine = nil,
        incoming = {},
        outgoing = {},
        status = "connecting",
        lastAttempt = 0,
        retryDelay = 5,  -- seconds between retry attempts
        id = connId
    }
    
    -- Initialize connection-specific data
    initConnectionData(connId)
    
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
                    -- Handle login process
                    if loginStates[conn.id] < LOGIN_STATE.COMPLETE then
                        --Logger.debug("[LOGIN]["..conn.id.."] HANDLING LOGIN")
                        handleLogin(conn, line)
                    end
                    -- Sanitize the received line before storing it
                    local sanitized = sanitize_utf8(line)
                    table.insert(conn.incoming, sanitized)
                elseif partial and partial ~= "" then
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

-- Game world state
local gameWorld = {
    background = nil,
    entities = {},
    items = {},
    currentRoom = nil
}

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
    
    -- Load login config
    loadLoginConfig()
    
    -- Create terminal windows and connections based on config
    local conn1 = createConnection("apocalypse6.com", 6000, 1)
    table.insert(connections, conn1)
    
    -- Create terminal window for connection 1
    local termWin1 = UIWindow:new({
        title = "Terminal 1",
        x = 50,
        y = 50,
        id = 1
    })
    table.insert(uiWindows, termWin1)
    
    -- Only create second terminal if config exists
    if loginConfig["conn2_character"] and loginConfig["conn2_password"] then
        local conn2 = createConnection("apocalypse6.com", 6000, 2)
        table.insert(connections, conn2)
        
        local termWin2 = UIWindow:new({
            title = "Terminal 2",
            x = 500,
            y = 50,
            id = 2
        })
        table.insert(uiWindows, termWin2)
    end
    
    -- Set initial active window
    activeWindow = termWin1
    
    -- Center terminal windows
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
                GameWorld:loadRoomBackground(Parser:getCurrentRoom())
                if Parser:getCurrentRoom() then
                    gameWorld.currentRoom = { name = Parser:getCurrentRoom() }
                end
            end
            table.insert(messages[conn.id], msg)
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
    for _, window in ipairs(uiWindows) do
        if disconnected then
            window.title = "Terminal " .. window.id .. " [DISCONNECTED]"
        else
            window.title = "Terminal " .. window.id
        end
    end
end

function love.textinput(t)
    inputBuffers[activeWindow.id] = inputBuffers[activeWindow.id] .. t
end

function love.keypressed(key)
    if showSplash then
        showSplash = false
        return
    end
    
    if key == "return" then
        if inputBuffers[activeWindow.id] ~= "" then
            for _, conn in ipairs(connections) do
                if conn.id == activeWindow.id and conn.status == "connected" then
                    table.insert(conn.outgoing, inputBuffers[activeWindow.id])
                else
                    table.insert(messages[activeWindow.id], "Cannot send message - " .. conn.status)
                    Logger.debug("Cannot send message - " .. conn.status)
                end
            end
            local msg = "> " .. inputBuffers[activeWindow.id]
            table.insert(messages[activeWindow.id], msg)
            Logger.raw(msg)
            inputBuffers[activeWindow.id] = ""
            scrollOffsets[activeWindow.id] = 0 -- auto-scroll to bottom on input
        else
            -- Send empty line when enter is pressed with empty input
            for _, conn in ipairs(connections) do
                if conn.id == activeWindow.id and conn.status == "connected" then
                    table.insert(conn.outgoing, "")
                end
            end
            local msg = "> "
            table.insert(messages[activeWindow.id], msg)
            Logger.raw(msg)
            scrollOffsets[activeWindow.id] = 0 -- auto-scroll to bottom on input
        end
    elseif key == "backspace" then
        inputBuffers[activeWindow.id] = inputBuffers[activeWindow.id]:sub(1, -2)
    elseif key == "up" then
        scrollOffsets[activeWindow.id] = math.min(scrollOffsets[activeWindow.id] + 1, math.max(0, #messages[activeWindow.id] - maxLines))
    elseif key == "down" then
        scrollOffsets[activeWindow.id] = math.max(scrollOffsets[activeWindow.id] - 1, 0)
    elseif key == "tab" then
        -- Switch between windows
        local currentIndex = 1
        for i, window in ipairs(uiWindows) do
            if window == activeWindow then
                currentIndex = i
                break
            end
        end
        local nextIndex = (currentIndex % #uiWindows) + 1
        activeWindow = uiWindows[nextIndex]
    end
end

function love.wheelmoved(x, y)
    if y > 0 then
        scrollOffsets[activeWindow.id] = math.min(scrollOffsets[activeWindow.id] + 1, math.max(0, #messages[activeWindow.id] - maxLines))
    elseif y < 0 then
        scrollOffsets[activeWindow.id] = math.max(scrollOffsets[activeWindow.id] - 1, 0)
    end
end

function love.mousepressed(x, y, button)
    if showSplash then
        showSplash = false
        return
    end
    
    if button == 1 then  -- Left mouse button
        -- Check if any window was clicked
        for _, window in ipairs(uiWindows) do
            if window:isPointInside(x, y) then
                -- Bring window to front
                for i, w in ipairs(uiWindows) do
                    if w == window then
                        table.remove(uiWindows, i)
                        table.insert(uiWindows, window)
                        break
                    end
                end
                activeWindow = window
                if window:isTitleBar(x, y) then
                    window.dragging = true
                    window.dragOffsetX = x - window.x
                    window.dragOffsetY = y - window.y
                elseif window:isResizeHandle(x, y) then
                    window.resizing = true
                    window.resizeOffsetX = x - window.width
                    window.resizeOffsetY = y - window.height
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
            window.width = math.max(window.minWidth, x - window.x + window.resizeOffsetX)
            window.height = math.max(window.minHeight, y - window.y + window.resizeOffsetY)
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then  -- Left mouse button
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
    -- Draw splash screen if enabled
    if showSplash then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(splashImage, 0, 0, 0, gameWin.width / splashImage:getWidth(), gameWin.height / splashImage:getHeight())
        return
    end
    
    -- Draw game world (background, room name, items, entities)
    local roomName = (gameWorld.currentRoom and gameWorld.currentRoom.name) or "Unknown Room"
    GameWorld:draw(roomName, roomNameFont, font)
    
    -- Draw all UI windows on top of the game world and room name
    for _, window in ipairs(uiWindows) do
        window:draw()
        -- Draw terminal content for each window
        local contentX = window.x + 16
        local contentY = window.y + window.barHeight + 8
        -- Calculate available width for input
        local availableWidth = window.width - 32
        local inputText = (inputBuffers[window.id] or "") .. (cursorVisible and "_" or " ")
        local wrappedText, wrappedLines = font:getWrap(inputText, availableWidth)
        local inputHeight = #wrappedLines * fontHeight
        -- Position input at the bottom of the window
        local inputY = window.y + window.height - inputHeight - 16
        safe_printf(inputText, contentX, inputY, availableWidth, "left")
        -- Calculate the area above the input for status and messages
        local belowInputY = inputY
        -- Draw messages with ANSI color parsing
        local y = window.y + window.barHeight + 8
        local maxLinesInWin = math.floor((belowInputY - y - 24) / fontHeight)
        local startIdx = math.max(1, #(messages[window.id] or {}) - maxLinesInWin - (scrollOffsets[window.id] or 0) + 1)
        local endIdx = math.max(1, #(messages[window.id] or {}) - (scrollOffsets[window.id] or 0))
        for i = startIdx, endIdx do
            local msg = messages[window.id] and messages[window.id][i]
            if msg then
                local x = contentX
                local segments = parse_ansi(msg)
                for _, segment in ipairs(segments) do
                    love.graphics.setColor(segment.color)
                    love.graphics.print(segment.text, x, y)
                    x = x + font:getWidth(segment.text)
                end
                y = y + fontHeight
            end
        end
    end
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
