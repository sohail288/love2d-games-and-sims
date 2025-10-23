local manifestModule = require("ci_preview.game_manifest")

local changed_games = {}

local ALWAYS_REBUILD_PREFIXES = {
    "ci_preview/",
    ".github/workflows/lovejs-preview.yml",
}

local function pathStartsWith(path, prefix)
    return path:sub(1, #prefix) == prefix
end

local function normalizeFiles(changedFiles)
    if type(changedFiles) ~= "table" then
        return {}
    end
    local normalized = {}
    for _, value in ipairs(changedFiles) do
        if type(value) == "string" and value ~= "" then
            table.insert(normalized, value)
        end
    end
    return normalized
end

local function collectGameMatches(games, changedFiles)
    local matchedIds = {}
    for _, filePath in ipairs(changedFiles) do
        for _, game in ipairs(games) do
            for _, prefix in ipairs(game.changePaths or {}) do
                if pathStartsWith(filePath, prefix) then
                    matchedIds[game.id] = true
                    break
                end
            end
        end
    end
    return matchedIds
end

---Identify which games should be rebuilt for the preview based on changed files.
---@param changedFiles string[]
---@param options table|nil
---@return table games
function changed_games.collect(changedFiles, options)
    options = options or {}
    local manifest = options.manifest or manifestModule
    local games = manifest.getGames()
    local normalizedFiles = normalizeFiles(changedFiles)
    local rebuildAll = #normalizedFiles == 0

    if not rebuildAll then
        for _, filePath in ipairs(normalizedFiles) do
            for _, prefix in ipairs(ALWAYS_REBUILD_PREFIXES) do
                if pathStartsWith(filePath, prefix) then
                    rebuildAll = true
                    break
                end
            end
            if rebuildAll then
                break
            end
        end
    end

    local selected = {}
    if rebuildAll then
        for _, game in ipairs(games) do
            table.insert(selected, game)
        end
        return selected
    end

    local matchedIds = collectGameMatches(games, normalizedFiles)
    for _, game in ipairs(games) do
        if matchedIds[game.id] then
            table.insert(selected, game)
        end
    end

    if #selected == 0 and options.fallbackToAll ~= false then
        for _, game in ipairs(games) do
            table.insert(selected, game)
        end
    end

    return selected
end

return changed_games
