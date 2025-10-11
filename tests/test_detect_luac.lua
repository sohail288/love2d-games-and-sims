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

local function runWithPath(path)
    local command = string.format("PATH=%s lua ci_preview/detect_luac.lua 2>&1", path)
    local handle = assert(io.popen(command, "r"), "failed to spawn detect_luac")
    local output = handle:read("*a")
    local ok, reason, code = handle:close()
    return ok, reason, code, output
end

local function makeTempDir()
    local handle = assert(io.popen("mktemp -d", "r"), "failed to create temp directory")
    local path = handle:read("*l")
    handle:close()
    assert(path and path ~= "", "temp directory path was empty")
    return path
end

local function writeExecutable(path, contents)
    local file = assert(io.open(path, "w"), string.format("failed to open %s", path))
    file:write(contents)
    file:close()

    local chmodResult = os.execute(string.format("chmod +x %q", path))
    assertTrue(commandSucceeded(chmodResult), string.format("failed to mark %s executable", path))
end

local function prependPath(newEntry)
    local current = os.getenv("PATH") or ""
    if current == "" then
        return newEntry
    end

    return string.format("%s:%s", newEntry, current)
end

local function cleanup(path)
    os.execute(string.format("rm -rf %q", path))
end

describe("detect_luac", function()
    it("prefers luac when available", function()
        local tmp = makeTempDir()
        writeExecutable(tmp .. "/luac", "#!/usr/bin/env sh\nexit 0\n")

        local pathEnv = prependPath(tmp)
        local ok, _, _, output = runWithPath(pathEnv)
        cleanup(tmp)

        assertTrue(ok, "expected detect_luac to succeed when luac is present")
        assertEquals(tmp .. "/luac\n", output)
    end)

    it("falls back to luac5.1 when luac is missing", function()
        local tmp = makeTempDir()
        writeExecutable(tmp .. "/luac5.1", "#!/usr/bin/env sh\nexit 0\n")

        local pathEnv = prependPath(tmp)
        local ok, _, _, output = runWithPath(pathEnv)
        cleanup(tmp)

        assertTrue(ok, "expected detect_luac to succeed when luac5.1 is present")
        assertEquals(tmp .. "/luac5.1\n", output)
    end)

    it("fails with a helpful error when no compiler is present", function()
        local tmp = makeTempDir()
        local pathEnv = prependPath(tmp)
        local ok, reason, code, output = runWithPath(pathEnv)
        cleanup(tmp)

        assertFalse(ok, "expected detect_luac to fail when no compiler exists")
        assertEquals("exit", reason)
        assertEquals(1, code)
        assertEquals("luac executable not found. Install Lua 5.1 development tools to provide luac.\n", output)
    end)
end)
