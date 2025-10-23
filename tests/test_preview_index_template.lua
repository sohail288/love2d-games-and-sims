describe("ci_preview.index_template", function()
    local template = require("ci_preview.index_template")

    it("renders selection controls for each preview", function()
        local html = template.render({
            games = {
                { id = "tactics_battle", name = "Tactics Battle", description = "Grid tactics" },
                { id = "homing_rocket", name = "Homing Rocket", description = "Projectile demo" },
            },
        })

        assertTrue(html:find("id=\"game-select\"", 1, true) ~= nil, "missing game selection dropdown")
        assertTrue(html:find("tactics_battle/index.html", 1, true) ~= nil, "expected tactics battle preview link")
        assertTrue(html:find("homing_rocket/index.html", 1, true) ~= nil, "expected homing rocket preview link")
        assertTrue(html:find("Load in page", 1, true) ~= nil, "missing inline launch button")
        assertTrue(html:find("Open in new tab", 1, true) ~= nil, "missing new tab link anchor")
    end)

    it("escapes html-sensitive game values", function()
        local html = template.render({
            games = {
                { id = 'alpha"', name = "Alpha & Beta", description = "Play <now>" },
            },
        })

        assertTrue(html:find("alpha&quot;", 1, true) ~= nil, "game id should escape quotes in attribute values")
        assertTrue(html:find("Alpha &amp; Beta", 1, true) ~= nil, "game name should escape ampersands")
        assertTrue(html:find("Play &lt;now&gt;", 1, true) ~= nil, "description should escape angle brackets")
    end)

    it("renders an empty state when no games are provided", function()
        local html = template.render({ games = {} })
        assertTrue(html:find("No preview builds were generated", 1, true) ~= nil, "empty state message missing")
    end)
end)
