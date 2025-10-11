local template = require("ci_preview.html_template")

local function parseArgs(rawArgs)
    local options = {}
    local index = 1
    while index <= #rawArgs do
        local argValue = rawArgs[index]
        if argValue == "--output" then
            index = index + 1
            options.output = rawArgs[index]
        elseif argValue == "--title" then
            index = index + 1
            options.title = rawArgs[index]
        elseif argValue == "--loading-message" then
            index = index + 1
            options.loadingMessage = rawArgs[index]
        elseif argValue == "--game-archive" then
            index = index + 1
            options.gameArchive = rawArgs[index]
        elseif argValue == "--lovejs-path" then
            index = index + 1
            options.loveJsPath = rawArgs[index]
        else
            error("unknown option: " .. tostring(argValue))
        end
        index = index + 1
    end
    return options
end

local function writeFile(path, contents)
    local file, err = io.open(path, "w")
    if not file then
        error("unable to open file for writing: " .. tostring(err))
    end
    file:write(contents)
    file:close()
end

local options = parseArgs(arg)
local outputPath = options.output or "preview/index.html"
local html = template.renderPreviewHtml({
    title = options.title or "Tactics Battle - CI Preview",
    loadingMessage = options.loadingMessage or "This build downloads the love.js runtime before launching the tactical battle prototype.",
    gameArchive = options.gameArchive or "game.love",
    loveJsPath = options.loveJsPath or "love.js",
})

writeFile(outputPath, html)
print("Generated love.js preview HTML at " .. outputPath)
