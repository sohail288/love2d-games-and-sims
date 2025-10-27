local htmlTemplate = require("ci_preview.html_template")

local preview_builder = {}

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

local function interpretExecuteResult(ok, reason, status)
    if type(ok) == "number" then
        return ok
    end

    if ok == true then
        return 0
    end

    local code = tonumber(status) or -1

    if reason == "exit" or reason == "signal" then
        return code
    end

    return code
end

function preview_builder.runCommand(command, executor)
    local exec = executor or os.execute
    local ok, reason, status = exec(command)
    local exitCode = interpretExecuteResult(ok, reason, status)

    if exitCode ~= 0 then
        error(string.format("command failed (%d): %s", exitCode, command))
    end

    return exitCode
end

function preview_builder.ensureDirectory(path, executor)
    if not path or path == "" then
        return
    end

    preview_builder.runCommand(string.format("mkdir -p %q", path), executor)
end

function preview_builder.removePath(path, executor)
    if not path or path == "" then
        return
    end

    preview_builder.runCommand(string.format("rm -rf %q", path), executor)
end

function preview_builder.writeFile(path, contents)
    local file, err = io.open(path, "w")
    if not file then
        error("unable to write file: " .. tostring(err))
    end
    file:write(contents)
    file:close()
end

function preview_builder.buildGame(plan, options, executor)
    local buildRoot = options.buildRoot
    local outputRoot = options.outputRoot

    local archivePath = string.format("%s/%s", buildRoot, plan.loveArchive)
    local outputDir = string.format("%s/%s", outputRoot, plan.id)
    preview_builder.ensureDirectory(buildRoot, executor)
    preview_builder.ensureDirectory(outputRoot, executor)

    preview_builder.removePath(archivePath, executor)
    local zipCommand = string.format("cd %q && zip -9 -r %q .", plan.root, "../" .. archivePath)
    preview_builder.runCommand(zipCommand, executor)

    preview_builder.removePath(outputDir, executor)
    preview_builder.runCommand(string.format("npx --yes love.js -c %q %q --title %q", archivePath, outputDir, plan.previewTitle), executor)

    preview_builder.runCommand(string.format("cp %q %q", archivePath, outputDir .. "/game.love"), executor)

    local loadingMessage = string.format("Downloading love.js runtime for %s...", plan.name)
    local html = htmlTemplate.renderPreviewHtml({
        title = plan.previewTitle,
        loadingMessage = loadingMessage,
        startButtonLabel = plan.startButtonLabel,
        gameArchive = "game.love",
        loveJsPath = "love.js",
        gameScriptPath = "game.js",
        includeVirtualKeyboard = plan.includeVirtualKeyboard or false,
    })

    preview_builder.writeFile(outputDir .. "/index.html", html)
end

function preview_builder.parseArgs(rawArgs)
    return parseArgs(rawArgs or {})
end

function preview_builder.main(rawArgs, executor)
    local args = rawArgs or _G.arg or {}
    local options = parseArgs(args)
    local plan = dofile(options.planPath)
    if type(plan) ~= "table" or type(plan.games) ~= "table" then
        error("preview plan must expose a games table")
    end

    for _, game in ipairs(plan.games) do
        preview_builder.buildGame(game, options, executor)
    end
end

return preview_builder
