describe("ci_preview.html_template", function()
    local template = require("ci_preview.html_template")

    it("renders the tactical battle preview html", function()
        local html = template.renderPreviewHtml({
            title = "Preview Title",
            loadingMessage = "Loading...",
            gameArchive = "battle.love",
            loveJsPath = "runtime/love.js",
            canvasId = "preview-canvas"
        })

        assertTrue(html:find("<title>Preview Title</title>") ~= nil, "title tag missing")
        assertTrue(html:find("Loading...", 1, true) ~= nil, "loading message missing")
        assertTrue(html:find("battle%.love") ~= nil, "game archive reference missing")
        assertTrue(html:find("runtime/love%.js") ~= nil, "love.js path missing")
        assertTrue(html:find("id=\"preview%-canvas\"") ~= nil, "canvas id missing")
    end)

    it("escapes html sensitive values", function()
        local html = template.renderPreviewHtml({
            title = "<Tactics>",
            loadingMessage = "Rock & Roll",
            gameArchive = 'game"data',
            loveJsPath = "path>love.js"
        })

        assertTrue(html:find("&lt;Tactics&gt;") ~= nil, "title should be escaped")
        assertTrue(html:find("Rock &amp; Roll") ~= nil, "loading message should escape ampersand")
        assertTrue(html:find('game&quot;data', 1, true) ~= nil, "game archive should escape quotes")
        assertTrue(html:find("path&gt;love.js") ~= nil, "love.js path should escape angle bracket")
    end)
end)
