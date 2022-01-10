-- this demonstrates how to do path finding in a grid based game
--
local push = require('vendor/push')
local Timer = require 'vendor/knife/timer'

local globals = require('globals')

local NodeMap= require('NodeMap')
local MainMenu = require("menu/MainMenu")
local ContextMenu = require("menu/ContextMenu")

function love.load()
  love.graphics.setDefaultFilter('nearest', 'nearest')
  love.window.setTitle("Path Finding")
  gNodeMap = NodeMap()
  hoveredNode = nil

  gContextMenu = ContextMenu()
  gMainMenu = MainMenu()

  push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
      fullscreen = false,
      resizable = true,
      vsync = true
    })
end

function love.mousepressed(x, y, button, istouch)
  if button == 1 and gNodeMap:nodeIsHighlighted() then
    gNodeMap:handleSelectNode()
  end
  
  if button == 2 and gNodeMap:nodeIsHighlighted() then

  end

  -- handle menu inputs
  if button == 1 then
    gMainMenu:handleMouseClick()
  end
end

function love.update(dt)
  local mouseX, mouseY = love.mouse.getPosition()
  gNodeMap:handleNodeHighlight(mouseX, mouseY)
  gMainMenu:handleMouseOver(mouseX, mouseY)
  Timer.update(dt)
end

function love.draw()
  gNodeMap:render()
  gMainMenu:render()
  local mouseX, mouseY = love.mouse.getPosition()
  love.graphics.circle("line", mouseX, mouseY, 5)
end

function love.keypressed(key)
  if key == 'escape' then
    love.event.quit()
  end
end
