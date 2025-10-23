describe("dkjson", function()
    local dkjson = require("tactics_battle.lib.dkjson")

    it("decodes escaped characters in strings", function()
        local payload = '{"text": "Line1\\nLine2", "quote": "He said \\"hi\\"", "slash": "\\/"}'
        local decoded, err = dkjson.decode(payload)

        assertTrue(err == nil, "expected decode to succeed, got: " .. tostring(err))
        assertEquals(decoded.text, "Line1\nLine2")
        assertEquals(decoded.quote, 'He said "hi"')
        assertEquals(decoded.slash, "/")
    end)
end)
