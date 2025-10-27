describe("ci_preview.html_template", function()
    local template = require("ci_preview.html_template")

    it("renders the tactical battle preview html", function()
        local html = template.renderPreviewHtml({
            title = "Preview Title",
            loadingMessage = "Loading...",
            gameArchive = "battle.love",
            loveJsPath = "runtime/love.js"
        })

        assertTrue(html:find("<title>Preview Title</title>") ~= nil, "title tag missing")
        assertTrue(html:find("Loading...", 1, true) ~= nil, "loading message missing")
        assertTrue(html:find("id=\"loading%-text\"") ~= nil, "loading text element should have an id for runtime status updates")
        assertTrue(html:find("battle%.love") ~= nil, "game archive reference missing")
        assertTrue(html:find("runtime/love%.js") ~= nil, "love.js path missing")
        assertTrue(html:find("var gameScriptPath = 'game%.js';") ~= nil, "game script path should be embedded for dynamic loading")
        assertTrue(html:find("id=\"canvas\"") ~= nil, "canvas id missing")
        assertTrue(html:find("document.getElementById('canvas')", 1, true) ~= nil, "Module should bind to the standard canvas id")
        assertTrue(html:find("Love%(Module%)") ~= nil, "love.js runtime should be invoked once the script loads")
        assertTrue(html:find("Unable to load compiled game script", 1, true) ~= nil, "game script load errors should surface to reviewers")
        assertTrue(html:find("Downloading game bundle", 1, true) ~= nil, "loader should communicate when the compiled game is downloading")
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

    it("allows the start button label to be customized", function()
        local html = template.renderPreviewHtml({
            startButtonLabel = "Play Tactical Demo"
        })

        assertTrue(html:find(">Play Tactical Demo<", 1, true) ~= nil, "custom start button label should be present")
    end)

    it("allows the game script path to be customized", function()
        local html = template.renderPreviewHtml({
            gameScriptPath = "compat/game.js"
        })

        assertTrue(html:find("var gameScriptPath = 'compat/game%.js';") ~= nil, "custom game script path should be present")
    end)

    it("exposes runtime launch status messaging", function()
        local html = template.renderPreviewHtml({})

        assertTrue(html:find("Downloading love.js runtime", 1, true) ~= nil, "should surface runtime download status text")
        assertTrue(html:find("Launching...", 1, true) ~= nil, "start button should communicate launch progress")
    end)

    it("includes a touch-friendly virtual keyboard", function()
        local html = template.renderPreviewHtml({})

        assertTrue(html:find("id=\"virtual-keyboard\"", 1, true) ~= nil, "virtual keyboard container should be present")
        assertTrue(html:find("data-key=\"ArrowUp\"", 1, true) ~= nil, "virtual keyboard should expose directional keys")
        assertTrue(html:find("setupVirtualKeyboard", 1, true) ~= nil, "virtual keyboard setup logic should be embedded")
        assertTrue(html:find("new KeyboardEvent", 1, true) ~= nil, "virtual keyboard should synthesize keyboard events for the canvas")
        assertTrue(html:find("virtualKeyCodeMap", 1, true) ~= nil, "virtual keyboard should normalize keyCode values for compatibility")
        assertTrue(html:find("document, window", 1, true) ~= nil, "virtual keyboard should dispatch events to document and window listeners")
    end)
end)
