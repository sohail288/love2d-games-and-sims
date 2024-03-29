local Class = require('vendor/class')

require('globals')

local Obstacle = require('Obstacle')

local Node = Class {}

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
  self._obstacle = nil

  -- public fields?
  self.visited = false
  self.seen = false
  self.distanceToDest = math.huge
  self.nextNode = nil
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
  self.seen = false
  self.visited = false
  self.distanceToDest = math.huge
end

function Node:clearTraversalData()
  self.seen = false
  self.visited = false
  self.distanceToDest = math.huge
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

function Node:getBounds()
  return self.x, self.x + self:getWidth(), self.y, self.y + self:getHeight()
end

function Node:addObstacle(simulator)
  if self._obstacle ~= nil then
    return
  end

  self._obstacle = Obstacle(self, { simulator = simulator })
end

function Node:removeObstacle()
  self._obstacle = nil
end

function Node:update(dt)
  if self._obstacle ~= nil then
    self._obstacle:update(dt)
  end
end

function Node:render()
  local filltype = (self.selected or self.isSourceNode or self.isDestinationNode) and "fill" or "line"
  local r, g, b, a = love.graphics.getColor()
  local fillColor = { 1, 1, 1, 1 }
  if self.isSourceNode then
    fillColor = { 0, 0.7, 0.7, 0.7 }
  end

  if self.isDestinationNode then
    fillColor = { 1, 0.1, 0.1, 0.7 }
  end

  -- abstract this out?
  love.graphics.setColor(unpack(fillColor))
  love.graphics.rectangle(filltype, self.x, self.y, self.size, self.size)
  love.graphics.setColor(r, g, b, a)

  if self.highlighted then
    love.graphics.setColor(100, 0, 100, 255)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", self.x + 1, self.y + 1, self.size - 2, self.size - 2) -- draw the rectangle within the actual rectangle
    love.graphics.setColor(r, g, b, a)
  end

  if self.nextNode ~= nil then
    local nextCx, nextCy = self.nextNode:getCenterCoordinates()
    local cx, cy = self:getCenterCoordinates()
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(1, 0, 0, 0.6)
    love.graphics.line(
      cx, cy, nextCx, nextCy
    )
    love.graphics.setColor(r, g, b, a)
  end

  if self._obstacle ~= nil then
    self._obstacle:render()
  end
end

return Node
