local Class = require('vendor/class')

local globals = require('globals')

local Node = Class{}

function Node:init(x, y, opts)
  opts = opts or {}
  self.x = x
  self.y = y
  self.size = opts.size or TILE_SIZE
  self.highlighted = false
  self.selected = false
end

function Node:reset()
  self.selected = false
  self.highlighted = false
end

function Node:toggleSelect()
  if self.selected then
    self.selected = false
  else
    self.selected = true
  end
end

function Node:toggleHighlight()
  if self.highlighted then
    self.highlighted = false
  else
    self.highlighted = true
  end
end

function Node:render()
  local filltype = self.selected and "fill" or "line"
  love.graphics.rectangle(filltype, self.x, self.y, self.size, self.size)
  if self.highlighted then
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(100, 0, 100, 255)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", self.x + 1, self.y + 1, self.size - 2, self.size - 2)  -- draw the rectangle within the actual rectangle
    love.graphics.setColor(r, g, b, a)
  end
end

return Node
