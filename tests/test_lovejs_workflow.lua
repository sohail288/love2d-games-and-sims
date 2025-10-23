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

    it("uses the maintained love.js bundler via npx", function()
        assertTrue(workflowYaml:find("npx%s+%-%-yes%s+love%.js%s+%-c") ~= nil, "expected workflow to invoke love.js with compatibility mode")
    end)

    it("provisions node before running the bundler", function()
        assertTrue(workflowYaml:find("uses:%s+actions/setup%-node@v3") ~= nil, "expected workflow to install Node.js")
    end)

    it("passes the game.js script to the preview generator", function()
        assertTrue(workflowYaml:find("%-%-game%-script%s+game%.js") ~= nil, "expected preview generator to register game.js")
    end)

    it("publishes the preview bundle to GitHub Pages", function()
        assertTrue(workflowYaml:find("actions/upload%-pages%-artifact@v3") ~= nil, "expected workflow to upload a Pages artifact")
        assertTrue(workflowYaml:find("actions/deploy%-pages@v4") ~= nil, "expected workflow to deploy the Pages artifact")
    end)
end)
