local Class = require('vendor/class')

local globals = require('globals')

local ContextMenu = Class{}

local menuOptions = {
  {
    title = "Set as Source",
    onClick = function (contextMenu)
      local node = contextMenu:getContext()
      local nm = node:getNodeMap()
      nm:setSource(node)
    end
  },
  {
    title = "Set as Destination",
    onClick = function (contextMenu)
      local node = contextMenu:getContext()
      local nm = node:getNodeMap()
      nm:setDestination(node)
    end
  },
}

function ContextMenu:init(opts)
  opts = opts or {}
  self.isOpen = false
  self._context = nil
  self._selectedOption = nil
  self.menuOptions = opts.menuOptions or menuOptions

  self.width = opts.width or 150
  self._menuOptionHeight = 30
  self.height = #menuOptions * self._menuOptionHeight
end

function ContextMenu:openAt(node)
  self._context = node
  self.isOpen = true
end

function ContextMenu:close()
  self.isOpen = false
  self._context = nil
end

function ContextMenu:getContext()
  if self._context == nil then
    return nil
  end
  return self._context
end

function ContextMenu:handleMouseClick(button, node)
  if button == 1 then
    if self.selectedOption ~= nil then
      self.menuOptions[self.selectedOption].onClick(self)
    end
    self:close()
  elseif button == 2 then
    if node ~= nil then
      self:openAt(node)
    else
      self:close()
    end
  end
end

function ContextMenu:pointWithinBounds(x, y)
  if not (self.isOpen or self._context ~= nil) then
    return false
  end
  local menuX, menuY = self:getCoordinates()
  return x >= menuX and x <= menuX + self.width and y > menuY and y <= menuY + self.height
end

function ContextMenu:handleMouseOver(x, y)
  self.selectedOption = nil

  if not self.isOpen then
    return
  end

  if not self:pointWithinBounds(x, y) then
    return
  end

  -- one menu item per line so we can ignore the x axis since we know we are in the context menu
  local _, menuY = self:getCoordinates()
  
  local selectedOption = math.ceil(((y - menuY) / self._menuOptionHeight))
  if selectedOption < 1 or selectedOption > #self.menuOptions then
    print("invalid option selected? " .. tostring(selectedOption) .. " - " .. tostring(menuY) .. " - " .. tostring(y))
    return
  end
  
  self.selectedOption = selectedOption
end

function ContextMenu:getCoordinates()
  if self._context == nil then
    return nil
  end
  local x, y, height, width = self._context.x, self._context.y, self._context:getWidth(), self._context:getHeight()
  return x + width + 5, y - 5
end

function ContextMenu:render()
  if self.isOpen and self._context ~= nil then
    local x, y = self:getCoordinates()
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", x, y, self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", x - 1, y - 1, self.width + 2, self.height + 2)
    love.graphics.setColor(r, g, b, a)
    
    love.graphics.push()
    local startY = y
    local height = self._menuOptionHeight
    -- explicitly set font here?
    love.graphics.translate(x, startY)
    local currentY = 0
    for i, option in ipairs(menuOptions) do

      if i == self.selectedOption then
        love.graphics.setColor(1, 0, 1, .9)
        love.graphics.rectangle("fill", 0, currentY, self.width, height)
        love.graphics.setColor(r, g, b, a)
      end

      love.graphics.printf(option.title, 5, currentY + height / 3, self.width)

      currentY = currentY + height
    end
    love.graphics.pop()
  end
end

return ContextMenu
