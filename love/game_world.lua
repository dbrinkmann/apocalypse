-- game_world.lua
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

-- GameWorld methods
function GameWorld:load()
    -- Load background
    self.background = love.graphics.newImage("images/rooms/The Temple of Midgaard.jpg")
    
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

function GameWorld:draw()
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