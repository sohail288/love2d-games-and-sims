local tableInsert = table.insert
local pcall = pcall
local ipairs = ipairs
local pairs = pairs
local format = string.format

package.path = table.concat({
    "?.lua",
    "?/init.lua",
    "tactics_battle/?.lua",
    "tactics_battle/?/init.lua",
    "tactics_battle/?/?.lua",
    "tests/?.lua",
    "tests/?/?.lua",
    package.path
}, ";")

local suites = {}

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(message or format("expected %s but got %s", tostring(expected), tostring(actual)))
    end
end

local function assertTrue(value, message)
    if not value then
        error(message or "expected condition to be true")
    end
end

local function describe(name, fn)
    local suite = { name = name, tests = {} }
    local function it(testName, testFn)
        tableInsert(suite.tests, { name = testName, fn = testFn })
    end

    local previousIt = _G.it
    local previousAssertEquals = _G.assertEquals
    local previousAssertTrue = _G.assertTrue

    _G.it = it
    _G.assertEquals = assertEquals
    _G.assertTrue = assertTrue

    local ok, err = pcall(fn)
    _G.it = previousIt
    _G.assertEquals = previousAssertEquals
    _G.assertTrue = previousAssertTrue

    if not ok then
        error(format("Error defining suite '%s': %s", name, err))
    end

    tableInsert(suites, suite)
end

_G.describe = describe

local testFiles = {
    "tests.tactics_battle.test_grid",
    "tests.tactics_battle.test_battlefield",
    "tests.tactics_battle.test_battle_system",
    "tests.tactics_battle.test_battle_flow_state_machine",
    "tests.tactics_battle.test_turn_manager",
    "tests.tactics_battle.test_enemy_ai",
    "tests.tactics_battle.test_scenarios",
    "tests.tactics_battle.test_game",
    "tests.tactics_battle.test_narrative_states",
    "tests.test_lovejs_preview_template"
}

local total = 0
local passed = 0

for _, file in ipairs(testFiles) do
    require(file)
end

for _, suite in ipairs(suites) do
    for _, test in ipairs(suite.tests) do
        total = total + 1
        local previousAssertEquals = _G.assertEquals
        local previousAssertTrue = _G.assertTrue
        _G.assertEquals = assertEquals
        _G.assertTrue = assertTrue

        local ok, err = pcall(test.fn)

        _G.assertEquals = previousAssertEquals
        _G.assertTrue = previousAssertTrue

        if ok then
            passed = passed + 1
        else
            io.stderr:write(format("[FAIL] %s - %s: %s\n", suite.name, test.name, err))
        end
    end
end

if passed == total then
    print(format("All tests passed (%d/%d)", passed, total))
else
    error(format("Some tests failed (%d/%d)", passed, total))
end
