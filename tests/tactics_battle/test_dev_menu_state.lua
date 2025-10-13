package.loaded["https"] = package.loaded["https"] or {
    request = function()
        return nil, "https module stub"
    end
}

if not newproxy then
    function newproxy()
        return {}
    end
end

local DevMenuState = require("tactics_battle.states.DevMenuState")

describe("DevMenuState", function()
    it("propagates API error messages", function()
        local state = DevMenuState.new()
        local step = state.generationSteps[state.selectedIndex]

        state.apiClient = {
            generate_text = function()
                return { error = { message = "Simulated API failure" } }
            end
        }

        state:keypressed({}, "return")

        local stored = state.generatedContent[step]
        assertTrue(type(stored) == "table", "expected error to be stored as a table")
        assertEquals(stored.error, "Simulated API failure")

        local previousLove = love
        local printed = {}
        love = {
            graphics = {
                clear = function() end,
                setColor = function() end,
                print = function(text)
                    table.insert(printed, text)
                end
            }
        }

        state:render({})
        love = previousLove

        local found = false
        for _, text in ipairs(printed) do
            if text:find("Error: Simulated API failure", 1, true) then
                found = true
                break
            end
        end

        assertTrue(found, "expected render to display the API error message")
    end)
end)
