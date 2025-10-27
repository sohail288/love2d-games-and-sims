local manifest = {}

local function makeGame(options)
    return {
        id = options.id,
        name = options.name,
        root = options.root,
        loveArchive = options.loveArchive or (options.id .. ".love"),
        previewTitle = options.previewTitle or (options.name .. " Preview"),
        startButtonLabel = options.startButtonLabel or ("Launch " .. options.name),
        description = options.description,
        changePaths = options.changePaths or { options.root .. "/" },
    }
end

manifest.games = {
    makeGame({
        id = "tactics_battle",
        name = "Tactics Battle",
        root = "tactics_battle",
        loveArchive = "tactics_battle.love",
        previewTitle = "Tactics Battle Preview",
        startButtonLabel = "Launch Tactics Battle",
        description = "Overhead tactical combat prototype with initiative-based battles.",
        changePaths = {
            "tactics_battle/",
            "tests/tactics_battle/",
        },
        includeVirtualKeyboard = true,
    }),
    makeGame({
        id = "homing_rocket",
        name = "Homing Rocket",
        root = "homing_rocket",
        loveArchive = "homing_rocket.love",
        previewTitle = "Homing Rocket Preview",
        startButtonLabel = "Launch Homing Rocket",
        description = "Demonstrates steering behaviour for a guided projectile.",
        changePaths = {
            "homing_rocket/",
        },
    }),
    makeGame({
        id = "path_finding",
        name = "Path Finding Sandbox",
        root = "path_finding",
        loveArchive = "path_finding.love",
        previewTitle = "Path Finding Preview",
        startButtonLabel = "Launch Path Finding Sandbox",
        description = "Interactive visualiser for grid-based path finding heuristics.",
        changePaths = {
            "path_finding/",
        },
    }),
}

local idIndex = {}
for _, game in ipairs(manifest.games) do
    idIndex[game.id] = game
end

---Return the table describing all previewable games.
---@return table
function manifest.getGames()
    return manifest.games
end

---Return game metadata by identifier.
---@param id string
---@return table|nil
function manifest.getGameById(id)
    return idIndex[id]
end

return manifest
