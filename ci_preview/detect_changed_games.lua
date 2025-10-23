local changedGames = require("ci_preview.changed_games")
local manifest = require("ci_preview.game_manifest")

local function parseArgs(rawArgs)
    local options = {}
    local index = 1
    while index <= #rawArgs do
        local value = rawArgs[index]
        if value == "--changed-file-list" then
            index = index + 1
            options.changedFileList = rawArgs[index]
        elseif value == "--output" then
            index = index + 1
            options.outputPath = rawArgs[index]
        elseif value == "--summary-output" then
            index = index + 1
            options.summaryOutputPath = rawArgs[index]
        else
            error("unknown option: " .. tostring(value))
        end
        index = index + 1
    end
    return options
end

local function readLines(path)
    if not path then
        return {}
    end

    local file = io.open(path, "r")
    if not file then
        return {}
    end

    local lines = {}
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()
    return lines
end

local function ensureParentDirectories(path)
    local lastSlash = path:match("^.*()/")
    if not lastSlash then
        return
    end

    local dirPath = path:sub(1, lastSlash - 1)
    if dirPath ~= "" then
        os.execute(string.format("mkdir -p %q", dirPath))
    end
end

local function writeSummary(path, games)
    if not path then
        return
    end

    ensureParentDirectories(path)
    local file, err = io.open(path, "w")
    if not file then
        error("unable to write summary: " .. tostring(err))
    end

    for _, game in ipairs(games) do
        file:write(game.id, "\n")
    end
    file:close()
end

local function serializePlan(games)
    local buffer = {}
    table.insert(buffer, "return {\n    games = {\n")
    for _, game in ipairs(games) do
        table.insert(buffer, "        {\n")
        table.insert(buffer, string.format("            id = %q,\n", game.id))
        table.insert(buffer, string.format("            name = %q,\n", game.name))
        table.insert(buffer, string.format("            root = %q,\n", game.root))
        table.insert(buffer, string.format("            loveArchive = %q,\n", game.loveArchive))
        table.insert(buffer, string.format("            previewTitle = %q,\n", game.previewTitle))
        table.insert(buffer, string.format("            startButtonLabel = %q,\n", game.startButtonLabel))
        if game.description then
            table.insert(buffer, string.format("            description = %q,\n", game.description))
        end
        table.insert(buffer, "        },\n")
    end
    table.insert(buffer, "    },\n}\n")
    return table.concat(buffer)
end

local function writePlan(path, games)
    if not path then
        return
    end

    ensureParentDirectories(path)
    local file, err = io.open(path, "w")
    if not file then
        error("unable to write plan: " .. tostring(err))
    end

    file:write(serializePlan(games))
    file:close()
end

local function main()
    local options = parseArgs(arg)
    local changedFiles = readLines(options.changedFileList)
    local games = changedGames.collect(changedFiles, { manifest = manifest })

    if #games == 0 then
        error("no games available for preview")
    end

    writePlan(options.outputPath or "build/preview_plan.lua", games)
    writeSummary(options.summaryOutputPath, games)

    io.write(string.format("Detected %d preview game(s):\n", #games))
    for _, game in ipairs(games) do
        io.write(" - ", game.id, " (", game.name, ")\n")
    end
end

main()
