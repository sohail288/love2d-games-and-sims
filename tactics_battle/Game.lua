local Game = {}
Game.__index = Game

function Game.new(context)
    local self = setmetatable({}, Game)
    self._states = {}
    self._currentName = nil
    self._current = nil
    self._context = context or {}
    return self
end

function Game:getContext()
    return self._context
end

function Game:registerState(name, state)
    assert(type(name) == "string" and name ~= "", "state name must be a non-empty string")
    assert(state, "state table is required")
    self._states[name] = state
end

function Game:getState(name)
    return self._states[name]
end

function Game:getCurrentState()
    return self._current, self._currentName
end

local function callIfExists(state, method, ...)
    local fn = state and state[method]
    if fn then
        return fn(state, ...)
    end
end

function Game:changeState(name, params)
    local nextState = self._states[name]
    assert(nextState, string.format("state '%s' is not registered", tostring(name)))

    if self._current and self._current.exit then
        self._current:exit(self)
    end

    self._current = nextState
    self._currentName = name
    callIfExists(self._current, "enter", self, params)
end

function Game:update(dt)
    callIfExists(self._current, "update", self, dt)
end

function Game:render()
    callIfExists(self._current, "render", self)
end

function Game:keypressed(key)
    callIfExists(self._current, "keypressed", self, key)
end

function Game:textinput(t)
    callIfExists(self._current, "textinput", self, t)
end

function Game:mousepressed(x, y, button)
    callIfExists(self._current, "mousepressed", self, x, y, button)
end

function Game:mousereleased(x, y, button)
    callIfExists(self._current, "mousereleased", self, x, y, button)
end

return Game
