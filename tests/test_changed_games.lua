describe("ci_preview.changed_games", function()
    local changedGames = require("ci_preview.changed_games")
    local manifest = require("ci_preview.game_manifest")

    local function ids(games)
        local values = {}
        for _, game in ipairs(games) do
            table.insert(values, game.id)
        end
        return table.concat(values, ",")
    end

    it("returns all games when no files changed", function()
        local games = changedGames.collect({})
        assertEquals(#games, #manifest.getGames())
        assertEquals(ids(games), "tactics_battle,homing_rocket,path_finding")
    end)

    it("selects a single game when only its sources change", function()
        local games = changedGames.collect({ "homing_rocket/main.lua" })
        assertEquals(#games, 1)
        assertEquals(games[1].id, "homing_rocket")
    end)

    it("rebuilds all games when preview tooling changes", function()
        local games = changedGames.collect({ "ci_preview/generate_preview_html.lua" })
        assertEquals(ids(games), "tactics_battle,homing_rocket,path_finding")
    end)

    it("aggregates multiple affected games", function()
        local games = changedGames.collect({
            "tactics_battle/main.lua",
            "path_finding/main.lua",
        })
        assertEquals(ids(games), "tactics_battle,path_finding")
    end)

    it("falls back to all games when changes do not map to a manifest entry", function()
        local games = changedGames.collect({ "docs/README.md" })
        assertEquals(ids(games), "tactics_battle,homing_rocket,path_finding")
    end)
end)
