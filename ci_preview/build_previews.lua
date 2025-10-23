local htmlTemplate = require("ci_preview.html_template")

local function parseArgs(rawArgs)
    local options = {
        planPath = "build/preview_plan.lua",
        buildRoot = "build",
        outputRoot = "build/lovejs",
    }
    local index = 1
    while index <= #rawArgs do
        local value = rawArgs[index]
        if value == "--plan" then
            index = index + 1
            options.planPath = rawArgs[index]
        elseif value == "--build-root" then
            index = index + 1
            options.buildRoot = rawArgs[index]
        elseif value == "--output-root" then
            index = index + 1
            options.outputRoot = rawArgs[index]
        else
            error("unknown option: " .. tostring(value))
        end
        index = index + 1
    end
    return options
end

local function run(command)
    local exitCode = os.execute(command)
    if exitCode ~= 0 then
        error(string.format("command failed (%d): %s", exitCode or -1, command))
    end
end

local function ensureDirectory(path)
    if not path or path == "" then
        return
    end
    run(string.format("mkdir -p %q", path))
end

local function removePath(path)
    run(string.format("rm -rf %q", path))
end

local function writeFile(path, contents)
    local file, err = io.open(path, "w")
    if not file then
        error("unable to write file: " .. tostring(err))
    end
    file:write(contents)
    file:close()
end

local function buildGame(plan, options)
    local buildRoot = options.buildRoot
    local outputRoot = options.outputRoot

    local archivePath = string.format("%s/%s", buildRoot, plan.loveArchive)
    local outputDir = string.format("%s/%s", outputRoot, plan.id)
    ensureDirectory(buildRoot)
    ensureDirectory(outputRoot)

    -- package .love archive
    removePath(archivePath)
    local zipCommand = string.format("cd %q && zip -9 -r %q .", plan.root, "../" .. archivePath)
    run(zipCommand)

    -- build love.js runtime
    removePath(outputDir)
    run(string.format("npx --yes love.js -c %q %q --title %q", archivePath, outputDir, plan.previewTitle))

    -- copy archive alongside runtime
    run(string.format("cp %q %q", archivePath, outputDir .. "/game.love"))

    -- generate preview html shell
    local loadingMessage = string.format("Downloading love.js runtime for %s...", plan.name)
    local html = htmlTemplate.renderPreviewHtml({
        title = plan.previewTitle,
        loadingMessage = loadingMessage,
        startButtonLabel = plan.startButtonLabel,
        gameArchive = "game.love",
        loveJsPath = "love.js",
        gameScriptPath = "game.js",
    })
    writeFile(outputDir .. "/index.html", html)
end

local function main()
    local options = parseArgs(arg)
    local plan = dofile(options.planPath)
    if type(plan) ~= "table" or type(plan.games) ~= "table" then
        error("preview plan must expose a games table")
    end

    for _, game in ipairs(plan.games) do
        buildGame(game, options)
    end
end

main()
