local function commandSucceeded(result)
    if type(result) == "number" then
        return result == 0
    end

    if type(result) == "boolean" then
        return result
    end

    if type(result) == "string" then
        return result == "exit"
    end

    return false
end

local function runCommand(command)
    local handle = assert(io.popen(command, "r"), "failed to spawn command")
    local output = handle:read("*a")
    local ok, reason, code = handle:close()
    assert(ok, string.format("command exited with %s (%s)", tostring(code), tostring(reason)))
    return output
end

local function ensureDirectoryAbsent(path)
    os.execute(string.format("rm -rf %q", path))
end

describe("lint command", function()
    it("skips directories named .lua", function()
        ensureDirectoryAbsent(".lua")
        local mkdirResult = os.execute("mkdir -p ./.lua")
        assertTrue(commandSucceeded(mkdirResult), "failed to create temporary .lua directory")

        local output = runCommand("find . -type f -name '*.lua' -not -path './vendor/*'")
        assertTrue(not output:find("./.lua"), string.format("expected lint target discovery to skip ./.lua directory, output was: %s", output))

        local cleanupResult = os.execute("rm -rf ./.lua")
        assertTrue(commandSucceeded(cleanupResult), "failed to clean up temporary .lua directory")
    end)
end)
