local Class = require('vendor/class')

local globals = require('globals')

local uiElements = require('menu/MenuOption')

local MainMenu = Class{}


local menuOptions = {
  title = "Algorithms",
  layout = "column",
  menuElements = {
    uiElements.Button{
      label="Clear All",
      padding=10,
      onClick=function()
        gNodeMap:clear()
      end
    },
    uiElements.Button{
      label="Select All",
      padding=10,
      onClick=function()
        for node in gNodeMap:iterator() do
          node:reset()
          node:toggleSelect()
        end
      end
    },
    uiElements.Button{
      label="Start",
      padding=10,
      onClick=function()
        gSimulator:start()
      end
    },
    uiElements.Button{
      label="Stop",
      padding=10,
      onClick=function()
        gSimulator:stop()
      end
    },
    uiElements.Button{
      label="Pause",
      padding=10,
      onClick=function()
        gSimulator:pause()
      end
    },
  }
}

local marginBottom = 10
local marginRight = 10

function MainMenu:init(opts)
  opts = opts or {}
  self.x = opts.x or VIRTUAL_WIDTH * 0.7
  self.y = opts.y or VIRTUAL_HEIGHT * 0.1
  self.height = opts.height or (VIRTUAL_HEIGHT - self.y - marginBottom)
  self.width = opts.width or (VIRTUAL_WIDTH - self.x - marginRight)
  self.selectedElement = nil

  self.menuElements = {}
  self.title = ""
  self:createLayout(menuOptions)
end

function MainMenu:createLayout(opts)
  self.title = opts.title
  local titleText = love.graphics.newText(love.graphics.getFont(), opts.title)
  local titleWidth, titleHeight = titleText:getDimensions()
  local layoutMode = "spaced-evenly"
  local alignmentMode = "center"
  local titleMarginBottom = 50
  local elementMargin = 20
  local currentX = self.x
  local currentY = self.y + titleHeight + titleMarginBottom
  local layoutOrientation = "column"
  local currentRow = 1
  local currentColumn = 1

  for _, element in ipairs(opts.menuElements) do
    element:setCoordinates(currentX, currentY)

    -- what to do with X? Maybe something to do with rows?
    currentY = currentY + element:getHeight() + (element.marginBottom or elementMargin)
    table.insert(self.menuElements, element)
  end
end

function MainMenu:centerX()
  return self.x + self.width / 2
end

function MainMenu:handleMouseOver(x, y)
  local selectedElement = nil
  for _, element in ipairs(self.menuElements) do
    -- is x, y within the bounds of the element?
    if x >= element.x and x <= element.x + element:getWidth() and y >= element.y and y <= element.y + element:getHeight() then
      selectedElement = element
    end
  end

  if selectedElement ~= self.selectedElement and self.selectedElement ~= nil then
    self.selectedElement:onMouseExit(x, y)
    self.selectedElement = nil
  end

  if selectedElement ~= nil then
    selectedElement:onMouseEnter(x, y)
    self.selectedElement = selectedElement
  end
end

function MainMenu:handleMouseClick()
  if self.selectedElement ~= nil then
    self.selectedElement:handleClick()
  end
end

function MainMenu:render()
  love.graphics.printf(self.title, self.x, self.y, self.width, "center") 
  for _, element in ipairs(self.menuElements) do
    element:render()
  end
end

return MainMenu
