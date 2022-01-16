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
  self.isSourceNode = false
  self.isDestinationNode = false
  self._nodeMap = nil
end

function Node:setNodeMap(nm)
  self._nodeMap = nm
end

function Node:getNodeMap()
  return self._nodeMap
end

function Node:getWidth()
  return self.size
end

function Node:getHeight()
  return self.size
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

function Node:getCenterCoordinates()
  local cx = self.x + self:getWidth() / 2
  local cy = self.y + self:getHeight() / 2
  return cx, cy
end

function Node:render()
  local filltype = (self.selected or self.isSourceNode or self.isDestinationNode) and "fill" or "line"
  local r, g, b, a = love.graphics.getColor()
  local fillColor = {1, 1, 1, 1}
  if self.isSourceNode then
    fillColor = {0, 0.7, 0.7, 0.7}
  end

  if self.isDestinationNode then
    fillColor = {1, 0.1, 0.1, 0.7}
  end

  -- abstract this out?
  love.graphics.setColor(unpack(fillColor))
  love.graphics.rectangle(filltype, self.x, self.y, self.size, self.size)
  love.graphics.setColor(r, g, b, a)

  if self.highlighted then
    love.graphics.setColor(100, 0, 100, 255)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", self.x + 1, self.y + 1, self.size - 2, self.size - 2)  -- draw the rectangle within the actual rectangle
    love.graphics.setColor(r, g, b, a)
  end
end

return Node
