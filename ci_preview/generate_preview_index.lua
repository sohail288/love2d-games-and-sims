local indexTemplate = require("ci_preview.index_template")
local manifest = require("ci_preview.game_manifest")

local function parseArgs(rawArgs)
    local options = {
        planPath = "build/preview_plan.lua",
        outputPath = "build/lovejs/index.html",
        title = "Love2D Preview Launcher",
    }

    local index = 1
    while index <= #rawArgs do
        local value = rawArgs[index]
        if value == "--plan" then
            index = index + 1
            options.planPath = rawArgs[index]
        elseif value == "--output" then
            index = index + 1
            options.outputPath = rawArgs[index]
        elseif value == "--title" then
            index = index + 1
            options.title = rawArgs[index]
        else
            error("unknown option: " .. tostring(value))
        end
        index = index + 1
    end

    return options
end

local function ensureDirectory(path)
    local lastSlash = path:match("^.*()/")
    if not lastSlash then
        return
    end

    local dirPath = path:sub(1, lastSlash - 1)
    if dirPath ~= "" then
        os.execute(string.format("mkdir -p %q", dirPath))
    end
end

local function buildIndexGames(plan)
    local games = {}
    local planGames = plan.games or {}
    for _, entry in ipairs(planGames) do
        local manifestGame = manifest.getGameById(entry.id)
        local description = entry.description or (manifestGame and manifestGame.description) or ""
        table.insert(games, {
            id = entry.id,
            name = entry.name,
            description = description,
            previewPath = string.format("./%s/index.html", entry.id),
        })
    end
    return games
end

local function writeFile(path, contents)
    ensureDirectory(path)
    local file, err = io.open(path, "w")
    if not file then
        error("unable to write preview index: " .. tostring(err))
    end
    file:write(contents)
    file:close()
end

local function main()
    local options = parseArgs(arg)
    local plan = dofile(options.planPath)
    local games = buildIndexGames(plan)

    local html = indexTemplate.render({
        title = options.title,
        heading = "Love2D Browser Previews",
        instructions = "Select a game to stream its love.js build.",
        games = games,
    })

    writeFile(options.outputPath, html)
    print(string.format("Generated preview index with %d game(s)", #games))
end

main()
