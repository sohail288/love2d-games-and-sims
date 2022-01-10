local Class = require('vendor/class')
local Timer = require("vendor/knife/timer")

local globals = require('globals')

local MenuOption = Class{}

function MenuOption:init(opts)
  opts = opts or {}
  self.x = opts.x or 0
  self.y = opts.y or 0
  self.height = opts.height or 0
  self.width = opts.width or 0
  self.padding = opts.padding or 0
  self.hover = false
end

function MenuOption:handleClick()
  self._clicked = true
  self._clickedBackgroundOpacity = 1
  -- button animation
  Timer.tween(1.0, {
    [self] = {_clickedBackgroundOpacity = 0}
  }):finish(function() 
    print('done')
    self._clicked = false
  end)

  if self.onClick ~= nil then
    -- onClick expects the button itself as the arg
    self.onClick(self)
  end
end

function MenuOption:onMouseEnter(x, y)
  self.hover = true
end

function MenuOption:onMouseExit(x, y)
  self.hover = false
end

function MenuOption:getWidth()
  return 2 * self.padding + self.width
end

function MenuOption:getHeight()
  return 2 * self.padding + self.height
end

function MenuOption:setCoordinates(x, y)
  self.x = x
  self.y = y
end

function MenuOption:getDimensions()
  return self:getWidth(), self:getHeight()
end

local Button = Class{__includes = MenuOption}
local DEFAULT_RIPPLE_TIME_MS = 250

Button.defaultHandleClick = function(button)
  print("clicked " .. button.textContent)
end

function Button:init(opts)
  opts = opts or {}
  MenuOption.init(self, opts)
  self.textContent = opts.label or "click here" 
  self.onClick = opts.onClick or self.defaultHandleClick
  self._rippleTimeMs = DEFAULT_RIPPLE_TIME_MS
  self._clicked = false
  self._clickedBackgroundOpacity = 0

  -- set the width to be the max of the content or the given width
  local _self = self
  self.width, self.height = (function(textContent)
    local font = love.graphics.getFont() 
    local text = love.graphics.newText(font, textContent)
    local w, h = text:getDimensions()
    return math.max(w, _self.width), math.max(h, _self.height)
  end)(self.textContent)
end

function Button:render()
  -- see https://love2d.org/wiki/love.graphics.newText
  local r, g, b, a = love.graphics.getColor()

  if self._clicked then
    love.graphics.setColor(1, 0, 1, self._clickedBackgroundOpacity) 
    love.graphics.rectangle('fill', self.x + 1, self.y + 1, self:getWidth() - 1, self:getHeight() - 1)
    love.graphics.setColor(r, g, b, a)
  end

  if self.hover then
    love.graphics.setColor(1, 0, 1, 1)
  end

  love.graphics.rectangle('line', self.x, self.y, self:getWidth(), self:getHeight()) 
  love.graphics.printf(self.textContent, self.x + self.padding, self.y + self.padding, self.width, "center") 

  love.graphics.setColor(r, g, b, a)
end

return {
  Button = Button,
}
