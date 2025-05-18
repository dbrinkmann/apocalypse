-- game_world.lua
local Logger = require("logger")
local GameWorld = {
    background = nil,
    entities = {},
    items = {},
    camera = {
        x = 0,
        y = 0,
        scale = 1
    }
}

-- Entity class for NPCs, players, etc.
local Entity = {
    x = 0,
    y = 0,
    sprite = nil,
    name = "",
    type = "npc",
    visible = true
}

function Entity:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Entity:draw()
    if not self.visible or not self.sprite then return end
    
    -- Draw sprite
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(self.sprite, self.x, self.y)
    
    -- Draw name above entity
    love.graphics.setColor(1,1,1,1)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(self.name)
    love.graphics.print(self.name, self.x - textWidth/2, self.y - 20)
end

-- Item class for objects on the ground
local Item = {
    x = 0,
    y = 0,
    sprite = nil,
    name = "",
    type = "item",
    visible = true
}

function Item:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Item:draw()
    if not self.visible or not self.sprite then return end
    
    -- Draw item sprite
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(self.sprite, self.x, self.y)
end

-- Function to load room background
function GameWorld:loadRoomBackground(roomName)
    if not roomName then return end
    
    -- Clean the room name for filename use
    local cleanName = roomName:gsub("[^%w%s]", ""):gsub("%s+", "_")
    
    -- Try both .jpg and .png extensions
    local extensions = {".jpg", ".png"}
    local success = false
    local image = nil
    
    for _, ext in ipairs(extensions) do
        local imagePath = "images/rooms/" .. cleanName .. ext
        success, image = pcall(function() return love.graphics.newImage(imagePath) end)
        if success and image then
            self.background = image
            return
        end
    end
    
    -- Fallback to default city image
    local defaultPath = "images/rooms/City of Midgaard.png"
    success, image = pcall(function() return love.graphics.newImage(defaultPath) end)
    if success and image then
        self.background = image
    else
        self.background = nil
    end
end

-- GameWorld methods
function GameWorld:load()
    -- Load initial background
    self:loadRoomBackground("The Temple of Midgaard")
    
    -- Load entity sprites
    -- local npcSprite = love.graphics.newImage("images/npc.png")
    
    -- -- Create some test entities
    -- local npc = Entity:new({
    --     x = 400,
    --     y = 300,
    --     sprite = npcSprite,
    --     name = "Test NPC",
    --     type = "npc"
    -- })
    -- table.insert(self.entities, npc)
end

function GameWorld:update(dt)
    -- Update entities
    for _, entity in ipairs(self.entities) do
        -- Add entity update logic here
    end
end

function GameWorld:draw(roomName, roomNameFont, font)
    --Logger.debug("Room name: " .. tostring(roomName) .. " " .. tostring(roomNameFont) .. " " .. tostring(font))
    -- Draw background
    if self.background then
        local winW, winH = love.graphics.getWidth(), love.graphics.getHeight()
        local imgW, imgH = self.background:getWidth(), self.background:getHeight()
        local scale = winH / imgH
        local drawW = imgW * scale
        local offsetX = (winW - drawW) / 2
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(self.background, offsetX, 0, 0, scale, scale)
    end
    -- Draw room name (if provided)
    if roomName and roomNameFont then
        love.graphics.setFont(roomNameFont)
        love.graphics.setColor(1, 1, 1, 0.9)
        local textWidth = roomNameFont:getWidth(roomName)
        local textX = (love.graphics.getWidth() - textWidth) / 2
        local textY = 32
        love.graphics.print(roomName, textX, textY)
        love.graphics.setFont(font)
    end
    -- Draw items
    for _, item in ipairs(self.items) do
        item:draw()
    end
    -- Draw entities
    for _, entity in ipairs(self.entities) do
        entity:draw()
    end
end

return GameWorld 