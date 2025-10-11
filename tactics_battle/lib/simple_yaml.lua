-- simple_yaml.lua
-- A very simple Lua table to YAML encoder.

local SimpleYaml = {}

function SimpleYaml.encode(data, ordered_keys)
    local yaml_lines = {}
    for _, key in ipairs(ordered_keys) do
        local value = data[key]
        if value and type(value) == "string" then
            if value:find("\n") then
                -- Handle multi-line strings using the literal block scalar style
                local indented_value = "  " .. value:gsub("\n", "\n  ")
                table.insert(yaml_lines, string.format("%s: |\n%s", key, indented_value))
            else
                -- Simple string values are just output as `key: value`
                table.insert(yaml_lines, string.format("%s: %s", key, value))
            end
        end
    end
    return table.concat(yaml_lines, "\n")
end

return SimpleYaml
