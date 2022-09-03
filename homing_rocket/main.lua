-- sample program to test love's mouse following and
-- practice trig functions
-- TODO
-- -- generate explosions for the rockets
local GAME_STATE_TITLE = "Targetting"
local Vector = require('Vector')
local Timer = require("knife.timer")
WINDOW_WIDTH = 960
WINDOW_HEIGHT = 700
VIRTUAL_WIDTH = WINDOW_WIDTH
VIRTUAL_HEIGHT = WINDOW_HEIGHT

BASIS_VECTOR = Vector.fromTable({1, 0})

function createRect(color, width, height, x, y, speed, acceleration)
  local x = x or 0
  local y = y or 0
  local rect = {
    color = color,
    width = width,
    height = height,
    x = x,
    y = y,
    acceleration = acceleration,
    rotation = 0,
    velocity = Vector.fromTable({0, 1}),
    targetOrientation = Vector.fromTable({-10, 100}),
    speed = speed,
    isActive = true,
    state = "homing",
    particleSystem = nil,
  }

  function rect:setDx(dx) rect.velocity:set(1, dx) end
  function rect:setDy(dy) rect.velocity:set(2, dy) end
  function rect:getDx() return rect.velocity:get(1) end
  function rect:getDy() return rect.velocity:get(2) end

  function rect:orientTowardsPoint(x, y)
    local rectCenterX = self.x + self.width / 2
    local rectCenterY = self.y + self.height / 2

    -- why is rectCenterX and rectCenterY subtracted from x and y? need to leave these types of comments
    self.targetOrientation:set(1, x - rectCenterX)
    self.targetOrientation:set(2, y - rectCenterY)
  end

  function rect:getNormalizedAngle(vector)
    -- can't remmember why this was necessary, I think it was due to how lua coordinate system behaves vs mathematical way
    -- it's because angleBetween will only return values between 0 and pi
    -- this gives the compliment angle
    -- vector can have this method
    local angle = BASIS_VECTOR:angleBetween(vector)
    if vector:get(2) < 0 then
      angle = 2 * math.pi - angle
    end
    return angle
  end

  function rect:changeState(newState)
    if self.state == newState then
      return
    else
      if self.state == "homing" and newState == "exploding" then
        self.state = newState
        local _self = self
        gExplosionSound:play()
        Timer.after(5, function()
          self:getParticleSystem():stop()
        end)
      end
    end
  end

  function rect:calculateDiff(myRotation, targetAngle)
    -- now the diff may be larger than pi! if it is, we want to go the other way around
    local diff = targetAngle - myRotation
    if diff > math.pi then
      return diff - 2 * math.pi
    elseif diff < -math.pi then
      return diff + 2 * math.pi
    else
      return diff
    end
  end

  function rect:update(dt)
    if self.state == "homing" then
      local maxRotation = math.rad(self.acceleration)
      local myRotation = self:getNormalizedAngle(self.velocity)
      local targetAngle = self:getNormalizedAngle(self.targetOrientation)
      local diff = self:calculateDiff(myRotation, targetAngle)
      --rotation = math.atan2(self.targetOrientation:get(2), self.targetOrientation:get(1))
      local currentDx = self:getDx()
      local currentDy = self:getDy()

      -- why is it done this way ( -maxRotation, +maxRotation )
      if diff > maxRotation then
        self.rotation = myRotation  + maxRotation
      elseif diff < -maxRotation then
        self.rotation = myRotation - maxRotation
      else
        self.rotation = myRotation
      end

      -- at this point we set the rotation to be a normalized version... time to denormalize it again


      -- love2d rotations are clockwise, but we measure the angle to target counterclockwise, so  if the angle is less than pi, we just add it
      -- otherwise we find the complimentary angle
      self.x = self.x + math.cos(self:getRotation()) * self.speed * dt
      self.y = self.y + math.sin(self:getRotation()) * self.speed * dt

      -- this isnt't necessary but eventually i just want to use vectors
      self.velocity:set(1, math.cos(self:getRotation()) * self.speed )
      self.velocity:set(2, math.sin(self:getRotation()) * self.speed )
    elseif self.state == "exploding" then
      -- take care of explosion animation and then set active to false
      local ps = self:getParticleSystem()
      ps:update(dt)

      if ps:getCount() == 0 then
        -- set the state to inactive once we have 0 particles
        self.isActive = 0
      end
    end
  end

  function rect:getRotation()
    return self.rotation
  end

  function rect:closeToPoint(x, y, tolerance)
    -- check if the tip of the rocket is close to the point x, y
    tolerance = tolerance ~= nil and tolerance or 5
    local rectCenterX = self.x + self.width / 2
    local rectCenterY = self.y + self.height / 2
    local circleRadius = 7 * math.max(self.width, self.height) / 13
    local myRotation = self:getNormalizedAngle(self.velocity)

    local edgeX = rectCenterX + math.cos(myRotation) * circleRadius
    local edgeY = rectCenterY + math.sin(myRotation) * circleRadius
    if ((x - edgeX) ^ 2 + (y - edgeY) ^ 2) ^ 0.5 <= tolerance then
      return true
    end
    return false
  end

  function rect:getParticleSystem()
    -- lazy load the ps
    if self.particleSystem == nil then
        self.particleSystem = love.graphics.newParticleSystem(gParticleImage, 15)
      	self.particleSystem:setParticleLifetime(2, 5) -- Particles live at least 2s and at most 5s.
        self.particleSystem:setEmissionRate(5)
        self.particleSystem:setSizeVariation(1)
        self.particleSystem:setLinearAcceleration(-20, -20, 20, 20) -- Random movement in all directions.
        self.particleSystem:setSpin(1, 3)
        self.particleSystem:setColors(1, 1, 1, 1, 1, 1, 1, 0) -- Fade to transparency.
        end
    return self.particleSystem
  end

  function rect:draw()
    local rectCenterX = self.x + self.width / 2
    local rectCenterY = self.y + self.height / 2

    if self.state == "homing" then

      local circleRadius = self.width / 2
      -- experiment...
      local circleRadius = 7 * math.max(self.width, self.height) / 13
      local mouseX, mouseY = love.mouse.getPosition()
      local pr, pg, pb, po = love.graphics.getColor()
      local normalVelocityVector = self.velocity:getNormalizedVector()
      local normalTargetOrientationVector = self.targetOrientation:getNormalizedVector()
      normalVelocityVector:iscale(circleRadius)
      normalTargetOrientationVector:iscale(circleRadius)

      local maxRotation = math.rad(self.acceleration)
      local myRotation = self:getNormalizedAngle(self.velocity)
      local targetAngle = self:getNormalizedAngle(self.targetOrientation)
      local diff = self:calculateDiff(myRotation, targetAngle)

      -- will be needing to rotate the rectangle, push and pop allow us to change the reference point of drawing, so
      -- we're drawing relative to the center of the reactangle
      love.graphics.push()
      love.graphics.translate(rectCenterX, rectCenterY)
      love.graphics.rotate(self:getRotation())
      love.graphics.setColor(self.color.r, self.color.g, self.color.b)

      -- why -self.width / 2 -- we draw relative to center of rectangle so need to subtract out the centers
      love.graphics.rectangle("fill", -self.width / 2, -self.height / 2, self.width, self.height)

      -- draw the arrows
      love.graphics.polygon("fill", self.width/2, -self.height/2 - 5, self.width/2 + 10, 0, self.width/2, self.height/2 + 5)
      love.graphics.polygon("fill", -self.width/2, 0, -self.width/2 - 5, -self.height/2, -self.width/2, -self.height/2 - 3)
      love.graphics.polygon("fill", -self.width/2, 0, -self.width/2 - 5, self.height/2, -self.width/2, self.height/2 + 3)
      love.graphics.setColor(pr, pg, pb, po)
      love.graphics.pop()

      love.graphics.circle("line", rectCenterX, rectCenterY, circleRadius)
      love.graphics.line(rectCenterX, rectCenterY, rectCenterX + circleRadius, rectCenterY)
      love.graphics.line(rectCenterX, rectCenterY, rectCenterX + normalTargetOrientationVector:get(1), rectCenterY + normalTargetOrientationVector:get(2))


      -- debug print
      -- printDiagnostics("Velocity Vector: " .. tostring(self.velocity), 5, VIRTUAL_HEIGHT - 60)
      -- printDiagnostics("Target Orientation" .. tostring(self.targetOrientation), 5, VIRTUAL_HEIGHT - 100)
      -- printDiagnostics("Angle between: " .. tostring(math.deg(self.velocity:angleBetween(self.targetOrientation))) , 5, VIRTUAL_HEIGHT - 120)
      -- printDiagnostics("Rotation: " .. tostring(math.deg(self:getRotation())), 5, VIRTUAL_HEIGHT - 140)
      -- printDiagnostics("Diff: " .. tostring(math.deg(diff)), 5, VIRTUAL_HEIGHT - 160)
    elseif self.state == "exploding" then
      local ps = self:getParticleSystem()
      love.graphics.draw(ps, rectCenterX, rectCenterY)
    end
  end

  return rect
end

function moveRect(rect, x, y)
  rect.x = x
  rect.y = y
end

function checkCollision(rect1, rect2)
  if rect1.x + rect1.width < rect2.x then
    return false
  elseif rect2.x + rect2.width < rect1.x then
    return false
  elseif rect2.y + rect2.height < rect1.y then
    return false
  elseif rect1.y + rect1.height < rect2.y then
    return false
  else
    return true
  end
end



function love.load()
  love.graphics.setDefaultFilter('nearest', 'nearest')
  love.window.setTitle(GAME_STATE_TITLE)
  love.window.setMode( VIRTUAL_WIDTH, VIRTUAL_HEIGHT, flags )

  print('loading assets')
  gParticleImage = love.graphics.newImage('explosion.png')
  gExplosionSound = love.audio.newSource('explosion.wav', 'static')

  pause = false
  non_collision_color = {r=0, g=1, b=0}
  collision_color = {r=0, g=1, b=1}
  --rocket = createRect(non_collision_color, 100, 10, VIRTUAL_WIDTH / 2, VIRTUAL_HEIGHT / 2)
  --rocket2 = createRect(collision_color, 100, 10, VIRTUAL_WIDTH / 3, VIRTUAL_HEIGHT / 3)

  rockets = {}
  for i = 1, 3 do
    local color = {r=math.random(), g=math.random(), b=math.random()}
    table.insert(rockets, createRect(color, 50 * i , 1 * i, VIRTUAL_WIDTH / i, VIRTUAL_HEIGHT / (i + 1), 100 / i, 0.5 / i))
  end
end

function love.keypressed(key)
  if key == 'escape' then
    love.event.quit()
  elseif key == "space" then
    if pause then
      pause = false
    else
      pause = true
    end
  end
end

function love.update(dt)
  local mouseX, mouseY = love.mouse.getPosition()
  Timer.update(dt)
  if not pause then
    for _, rocket in ipairs(rockets) do
      if rocket.isActive then
        rocket:orientTowardsPoint(mouseX, mouseY)
        rocket:update(dt)

        -- collision detection
        if rocket:closeToPoint(mouseX, mouseY) then
          rocket:changeState("exploding")
        end
      end
    end
  end
end

function love.draw()
  for _, rocket in ipairs(rockets) do
    if rocket.isActive then
      rocket:draw()
    end
  end

  local mouseX, mouseY = love.mouse.getPosition()
  love.graphics.circle("line", mouseX, mouseY, 5)
  drawFPS()
end

function printDiagnostics(message, x, y)
  local pr, pg, pb, po = love.graphics.getColor()
  love.graphics.setColor(0, 1, 0, 1)
  love.graphics.print(message, x, y)
  love.graphics.setColor(pr, pg, pb, po)
end

function drawFPS()
  printDiagnostics("FPS: " .. tostring(love.timer.getFPS()), 5, VIRTUAL_HEIGHT - 20)
end

function love.mousepressed(x, y, button, istouch)
   if button == 1 then
     for _, rocket in ipairs(rockets) do
       if rocket.isActive then
         rocket:changeState("exploding")
       end
     end
   end
end
