local function command_path(name)
    local handle = io.popen(string.format("command -v %s 2>/dev/null", name))
    if not handle then
        return nil
    end

    local path = handle:read("*l")
    handle:close()

    if path and #path > 0 then
        return path
    end

    return nil
end

local candidates = { "luac", "luac5.1", "luac-5.1" }

for _, candidate in ipairs(candidates) do
    local path = command_path(candidate)
    if path then
        print(path)
        os.exit(0)
    end
end

io.stderr:write("luac executable not found. Install Lua 5.1 development tools to provide luac.\n")
os.exit(1)
