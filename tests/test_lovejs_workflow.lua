local workflowPath = ".github/workflows/lovejs-preview.yml"

local function readFile(path)
    local file, err = io.open(path, "r")
    if not file then
        error("failed to read workflow: " .. tostring(err))
    end
    local contents = file:read("*a")
    file:close()
    return contents
end

describe("lovejs preview workflow", function()
    local workflowYaml = readFile(workflowPath)

    it("provisions node before running the bundler", function()
        assertTrue(workflowYaml:find("uses:%s+actions/setup%-node@v3") ~= nil, "expected workflow to install Node.js")
    end)

    it("detects changed games before building previews", function()
        assertTrue(workflowYaml:find("ci_preview/detect_changed_games.lua") ~= nil, "expected workflow to call the changed game detector")
    end)

    it("builds previews through the Lua orchestration script", function()
        assertTrue(workflowYaml:find("ci_preview/build_previews.lua") ~= nil, "expected workflow to invoke the preview builder script")
    end)

    it("generates an index page that links all previews", function()
        assertTrue(workflowYaml:find("ci_preview/generate_preview_index.lua") ~= nil, "expected workflow to emit a preview index page")
    end)

    it("publishes the preview bundle to GitHub Pages", function()
        assertTrue(workflowYaml:find("actions/upload%-pages%-artifact@v3") ~= nil, "expected workflow to upload a Pages artifact")
        assertTrue(workflowYaml:find("actions/deploy%-pages@v4") ~= nil, "expected workflow to deploy the Pages artifact")
    end)
end)
