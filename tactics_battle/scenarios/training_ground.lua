local ipairs = ipairs

local function createUnit(id, name, faction, params)
    params.id = id
    params.name = name
    params.faction = faction
    return params
end

local function evaluatePrimaryObjective(context)
    if context:countFactionUnits("enemies") == 0 then
        return "completed", "All enemy forces have been defeated."
    end
    return "in_progress"
end

local function evaluateProtectAllies(context)
    local totalAllies = context.scenarioState.initialAllies or 0
    local currentAllies = context:countFactionUnits("allies")
    if totalAllies > 0 and currentAllies < totalAllies then
        return "failed", "An allied unit was defeated."
    end
    if context:countFactionUnits("enemies") == 0 then
        return "completed", "All allies survived the encounter."
    end
    return "in_progress"
end

local scenario = {
    id = "training_ground",
    name = "Training Ground Skirmish",
    description = "Allied recruits practice formation tactics against a small enemy squad.",
    grid = { width = 10, height = 8, tileSize = 64 },
    units = {
        createUnit("ally_knight", "Knight", "allies", { speed = 8, hp = 120, move = 3, attackPower = 35, col = 2, row = 5 }),
        createUnit("ally_archer", "Archer", "allies", { speed = 12, hp = 80, move = 4, attackRange = 3, attackPower = 28, col = 3, row = 6 }),
        createUnit("enemy_soldier", "Soldier", "enemies", { speed = 7, hp = 100, move = 3, attackPower = 32, col = 8, row = 3 }),
        createUnit("enemy_mage", "Mage", "enemies", { speed = 10, hp = 70, move = 4, attackRange = 3, attackPower = 40, col = 7, row = 2 })
    },
    scriptedEvents = {
        { trigger = "battle_start", message = "Keep formation and eliminate the opposing squad." }
    },
    objectives = {
        {
            id = "defeat_all_enemies",
            type = "primary",
            description = "Defeat every enemy unit.",
            evaluate = evaluatePrimaryObjective
        },
        {
            id = "protect_allies",
            type = "bonus",
            description = "Keep all allied units alive.",
            evaluate = evaluateProtectAllies
        }
    },
    hooks = {
        onTurnStart = function(context)
            context.scenarioState.turnsTaken = (context.scenarioState.turnsTaken or 0) + 1
        end,
        onObjectivesUpdated = function(context)
            local snapshot = {}
            for _, objective in ipairs(context.objectives or {}) do
                snapshot[objective.id] = objective.status
            end
            context.scenarioState.lastObjectiveSnapshot = snapshot
        end
    },
    victoryConditions = {
        function(context)
            if context:countFactionUnits("enemies") == 0 then
                return { winner = "allies", draw = false, reason = "All enemies defeated." }
            end
        end
    },
    defeatConditions = {
        function(context)
            if context:countFactionUnits("allies") == 0 then
                return { winner = "enemies", draw = false, reason = "All allied units were defeated." }
            end
        end
    }
}

return scenario
