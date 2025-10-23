local pairs = pairs
local tableSort = table.sort

local trainingGround = require("scenarios.training_ground")

local scenarios = {
    [trainingGround.id] = trainingGround
}

local module = {}

function module.ids()
    local keys = {}
    local index = 1
    for id in pairs(scenarios) do
        keys[index] = id
        index = index + 1
    end
    tableSort(keys)
    return keys
end

function module.getScenario(id)
    return scenarios[id]
end

function module.getDefaultScenario()
    return trainingGround
end

return module
