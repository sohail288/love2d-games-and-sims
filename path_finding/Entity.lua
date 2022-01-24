local Class = require('vendor/class')
local Vector = require('Vector')

local Entity = Class{}
local DEFAULT_POSITION_X = 100
local DEFAULT_POSITION_Y = 100

function Entity:init(opts)
  opts = opts or {}
  self.speed = 100
  self.rotationSpeedRads = 0.05  -- keep low to avoid glitching
  self.position = Vector.fromTable{opts.x or DEFAULT_POSITION_X, opts.y or DEFAULT_POSITION_Y}
  self.velocity = Vector.fromTable{1, 1}
  self.direction = Vector.fromTable{1, 1} -- this is derived from velocity?
end

function Entity:orientTowardsNode(node)
  if self.targetNode ~= node then
    self.node = node
  end

  if self.node == nil then
    return
  end
  local targetCx, targetCy = self.node:getCenterCoordinates()

  -- our future orientation
  local targetVector = Vector.fromTable{
    targetCx - self.position:get(1),
    targetCy - self.position:get(2),
  }

  -- can we do a direct comparison? would always be between {0, pi}
  local targetAngleFromBasis = targetVector:getBasisAngle()
  local myRotationFromBasis = self.velocity:getBasisAngle()
  local angleBetween = targetAngleFromBasis - myRotationFromBasis
  
  -- this calculates the short way around if our angle is less than -pi or greater than pi
  -- we just add a circle to get the complimentary angle
  if angleBetween > math.pi then
    angleBetween = angleBetween - 2 * math.pi
  elseif angleBetween < -math.pi then
    angleBetween = angleBetween + 2 * math.pi
  end 

  if angleBetween > self.rotationSpeedRads then
    rotationAngle = self.rotationSpeedRads
  elseif angleBetween < -self.rotationSpeedRads then
    rotationAngle = -self.rotationSpeedRads
  else
    rotationAngle = 0
  end


  -- my rotation calculated from a basis? do i need this
  -- https://en.wikipedia.org/wiki/Rotation_matrix
  local v = self.velocity
  -- print(v, angleBetween, rotationAngle)
  local nextVelocity = Vector.fromTable{
    v:get(1) * math.cos(rotationAngle) - v:get(2) * math.sin(rotationAngle),
    v:get(1) * math.sin(rotationAngle) + v:get(2) * math.cos(rotationAngle)
  }
  -- self.velocity = self.velocity:getNormalizedVector() * self.speed
  self.velocity = nextVelocity
end

function Entity:update(dt)
  self:orientTowardsNode()
  self.position:iadd(self.velocity *  dt * self.speed)
end

function Entity:render()
  local r, g, b, a = love.graphics.getColor()
  love.graphics.setColor(0, 0.3, 0.8, 0.9)
  love.graphics.circle("fill", self.position:get(1), self.position:get(2), 5)
  love.graphics.push()
  love.graphics.translate(self.position:get(1), self.position:get(2))
  love.graphics.setColor(1, 0, 0, 0.3)
  love.graphics.line(
    0, 0, self.velocity:get(1) * self.speed, self.velocity:get(2) * self.speed
  )
  love.graphics.pop()
  love.graphics.setColor(r, g, b, a)
end

return Entity
