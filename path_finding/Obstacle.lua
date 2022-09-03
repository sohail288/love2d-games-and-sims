local Class = require("vendor/class")
local Entity = require("Entity")
local Vector = require('Vector')


local function createProjectile(origin, velocity)
  local projectile = {
    speed = 200,
    size = 5,
    position = Vector.fromTable { origin:get(1), origin:get(2) },
    velocity = Vector.fromTable { velocity:get(1), origin:get(2) },
    active = true,
  }
  function projectile:render()
    love.graphics.circle("fill", self.position:get(1), self.position:get(2), self.size)
  end

  function projectile:update(dt)
    if self.active then
      self.velocity = velocity:getNormalizedVector() * self.speed
      self.position:iadd(self.velocity * dt)
    end
  end

  return projectile
end

local Obstacle = Class { __includes = Entity }

function Obstacle:init(node, opts)
  opts = opts or {}
  local cx, cy = node:getCenterCoordinates()
  opts.x = cx
  opts.y = cy
  Entity.init(self, opts)
  self.node = node
  self.rotationSpeedRads = 0.10
  self._simulator = opts.simulator

  self._projectiles = {}
  self._maxProjectiles = 10
  self._coolDownTimeSeconds = 0.250
  self._coolDownTimer = 0.0
end

local function rotationDelta(currentDirection, positionA, positionB)
  local targetVector = positionB - positionA

  -- can we do a direct comparison? would always be between {0, pi}
  local targetAngleFromBasis = targetVector:getBasisAngle()
  local myRotationFromBasis = currentDirection:getBasisAngle()
  local angleBetween = targetAngleFromBasis - myRotationFromBasis

  -- this calculates the short way around if our angle is less than -pi or greater than pi
  -- we just add a circle to get the complimentary angle
  if angleBetween > math.pi then
    angleBetween = angleBetween - 2 * math.pi
  elseif angleBetween < -math.pi then
    angleBetween = angleBetween + 2 * math.pi
  end
  return angleBetween
end

function Obstacle:orientTowardsLocation(position)
  if position == nil then
    return
  end

  local targetCx, targetCy = position:get(1), position:get(2)

  -- our future orientation
  local targetVector = Vector.fromTable {
    targetCx - self.position:get(1),
    targetCy - self.position:get(2),
  }

  -- can we do a direct comparison? would always be between {0, pi}
  local targetAngleFromBasis = targetVector:getBasisAngle()
  local myRotationFromBasis = self.direction:getBasisAngle()
  local angleBetween = targetAngleFromBasis - myRotationFromBasis

  -- this calculates the short way around if our angle is less than -pi or greater than pi
  -- we just add a circle to get the complimentary angle
  if angleBetween > math.pi then
    angleBetween = angleBetween - 2 * math.pi
  elseif angleBetween < -math.pi then
    angleBetween = angleBetween + 2 * math.pi
  end

  local rotationAngle = 0
  if angleBetween > self.rotationSpeedRads then
    rotationAngle = self.rotationSpeedRads
  elseif angleBetween < -self.rotationSpeedRads then
    rotationAngle = -self.rotationSpeedRads
  else
    rotationAngle = 0
  end


  -- my rotation calculated from a basis? do i need this
  -- https://en.wikipedia.org/wiki/Rotation_matrix
  local v = self.direction
  -- print(v, angleBetween, rotationAngle)
  local nextDirection = Vector.fromTable {
    v:get(1) * math.cos(rotationAngle) - v:get(2) * math.sin(rotationAngle),
    v:get(1) * math.sin(rotationAngle) + v:get(2) * math.cos(rotationAngle)
  }
  -- self.velocity = self.velocity:getNormalizedVector() * self.speed
  self.direction = nextDirection:getNormalizedVector()
end

function Obstacle:setTargetEntity(nodeMap, finder)
  -- score each node from this point
  -- local nodeMapDistances = finder(nodeMap)

  -- go through each entity
  local closestEntity
  for entity in self._simulator:entityIterator() do
    closestEntity = entity
  end

  if closestEntity == nil then
    return
  end

  self.targetedEntity = closestEntity
end

function Obstacle:fireTo(target)

end

function Obstacle:update(dt)
  if self._coolDownTimer > 0 then
    self._coolDownTimer = math.max(self._coolDownTimer - dt, 0)
  end
  -- let's find the target entity...
  -- how do we get to the nodeMap
  if self.targetedEntity ~= nil and self.targetedEntity.active then
    local predictedEntityPosition = self.targetedEntity.position + self.targetedEntity.velocity
    self:orientTowardsLocation(predictedEntityPosition)
    print(self, "angle diff", rotationDelta(self.direction, self.position, predictedEntityPosition))
    if math.abs(rotationDelta(self.direction, self.position, predictedEntityPosition)) < 0.05 and self._coolDownTimer <= 0 and #self._projectiles < self._maxProjectiles then
      local projectile = createProjectile(self.position, self.direction:getNormalizedVector())
      table.insert(self._projectiles, projectile)
      self._coolDownTimer = self._coolDownTimeSeconds
    end
  end
  -- in the node..., kill the entity...

  local nextProjectiles = {}
  for _, projectile in ipairs(self._projectiles) do
    if not (projectile.position:get(1) < VIEWPORT_START_X or projectile.position:get(2) < VIEWPORT_START_Y or projectile.position:get(1) > VIEWPORT_WIDTH or projectile.position:get(2) > VIEWPORT_HEIGHT) then
      projectile:update(dt)
      table.insert(nextProjectiles, projectile)
    end
  end

  self._projectiles = nextProjectiles

  if #self._projectiles > self._maxProjectiles then
    self._coolDownTimer = self._coolDownTimeSeconds
  end
end

function Obstacle:render()
  local r, g, b, a = love.graphics.getColor()
  local oLineWidth = love.graphics.getLineWidth()
  love.graphics.setColor(1, 0.3, 0.8, 0.9)
  love.graphics.circle("line", self.position:get(1), self.position:get(2), 10)

  -- missle ?
  love.graphics.push()
  love.graphics.translate(self.position:get(1), self.position:get(2))
  love.graphics.setColor(1, 0, 0, 0.3)
  love.graphics.setLineWidth(2)
  love.graphics.line(
    0, 0, 20 * self.direction:get(1), 20 * self.direction:get(2)
  )
  love.graphics.pop()
  love.graphics.setColor(r, g, b, a)
  love.graphics.setLineWidth(oLineWidth)

  for _, projectile in ipairs(self._projectiles) do
    if projectile.active then
      projectile:render()
    end
  end
end

return Obstacle
