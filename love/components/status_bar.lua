local StatusBar = {
    width = 250,  -- Default width
    height = 150, -- Default height
    barHeight = 20, -- Height of each stat bar
    xpBarHeight = 10, -- Height of XP bar (skinnier)
    padding = 5,  -- Padding between elements
    titleBarHeight = 36, -- Height of title bar
    dragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,
    colors = {
        health = {0.8, 0.2, 0.2},    -- Red
        mana = {0.2, 0.2, 0.8},      -- Blue
        moves = {0.8, 0.8, 0.2},     -- Yellow
        xp = {0.2, 0.8, 0.2},        -- Green
        background = {0.08, 0.09, 0.12, 0.98}, -- Dark background
        titleBar = {0.18, 0.19, 0.25, 1},      -- Title bar color
        border = {0.3, 0.3, 0.4, 1}            -- Border color
    }
}

function StatusBar:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function StatusBar:isPointInside(x, y)
    return x >= self.x and x <= self.x + self.width and
           y >= self.y and y <= self.y + self.height
end

function StatusBar:isTitleBar(x, y)
    return x >= self.x and x <= self.x + self.width and
           y >= self.y and y <= self.y + self.titleBarHeight
end

function StatusBar:draw(x, y, characterStats)
    self.x = x
    self.y = y
    
    -- Draw window background
    love.graphics.setColor(self.colors.background)
    love.graphics.rectangle("fill", x, y, self.width, self.height, 16, 16)
    
    -- Draw title bar
    love.graphics.setColor(self.colors.titleBar)
    love.graphics.rectangle("fill", x, y, self.width, self.titleBarHeight, 16, 16)
    
    -- Draw title text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(characterStats.character or "Unknown", x + 12, y + 8)
    
    -- Draw border
    love.graphics.setColor(self.colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, self.width, self.height, 16, 16)
    love.graphics.setLineWidth(1)
    
    -- Draw health bar
    local barY = y + self.titleBarHeight + self.padding
    self:drawBar(x + self.padding, barY, self.width - self.padding * 2, self.barHeight,
        characterStats.hp.current or 0, characterStats.hp.max or 100,
        self.colors.health)
    
    -- Draw mana bar
    barY = barY + self.barHeight + self.padding
    self:drawBar(x + self.padding, barY, self.width - self.padding * 2, self.barHeight,
        characterStats.mana.current or 0, characterStats.mana.max or 100,
        self.colors.mana)
    
    -- Draw moves bar
    barY = barY + self.barHeight + self.padding
    self:drawBar(x + self.padding, barY, self.width - self.padding * 2, self.barHeight,
        characterStats.vitality.current or 0, characterStats.vitality.max or 100,
        self.colors.moves)
    
    -- Draw XP remaing label
    barY = barY + self.barHeight + self.padding
    love.graphics.setColor(1, 1, 1)
    local text = characterStats.xp.current .. " XP to Level"
    local textWidth = love.graphics.getFont():getWidth(text)
    love.graphics.print(text, x + (self.width - textWidth) / 2, barY)
end

function StatusBar:drawBar(x, y, width, height, current, max, color)
    -- Draw background
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", x, y, width, height, 4, 4)
    
    -- Draw filled portion
    local fillWidth = (current / max) * width
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, fillWidth, height, 4, 4)
    
    -- Draw border
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("line", x, y, width, height, 4, 4)
    
    -- Draw label and values
    love.graphics.setColor(1, 1, 1)
    local text = string.format("%d/%d", current, max)
    local textWidth = love.graphics.getFont():getWidth(text)
    love.graphics.print(text, x + (width - textWidth) / 2, y + (height - 12) / 2)
end

return StatusBar 