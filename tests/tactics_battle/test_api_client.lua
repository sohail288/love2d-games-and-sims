describe("ApiClient", function()

    it("delegates synchronous requests through the HTTP client", function()
        local captured_request
        local http_client = {
            uses_fetch = function()
                return false
            end,
            update = function() end,
            fetch = function(self, url, options)
                captured_request = { url = url, options = options }
                return true, { status = 200, body = "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}" }
            end
        }

        local ApiClient = require("lib.api_client")
        local client = ApiClient.new(http_client)
        local response = client:generate_text("prompt", { type = "object" }, "Step")

        assertTrue(response ~= nil, "expected response table")
        assertTrue(response.choices ~= nil, "expected choices in response")
        assertEquals(captured_request.options.method, "POST")
        assertEquals(captured_request.options.headers["Content-Type"], "application/json")
    end)

    it("requires a callback when the transport is asynchronous", function()
        local http_client = {
            uses_fetch = function()
                return true
            end,
            update = function() end,
            fetch = function() end
        }

        local ApiClient = require("lib.api_client")
        local client = ApiClient.new(http_client)

        local ok, err = pcall(function()
            client:generate_text("prompt", { type = "object" }, "Step")
        end)

        assertTrue(not ok, "expected generate_text to raise without callback")
        assertTrue(err:match("generate_text requires a callback"), "expected helpful error message")
    end)

    it("normalizes asynchronous responses", function()
        local requests = {}
        local updates = {}
        local http_client = {
            uses_fetch = function()
                return true
            end,
            update = function(_, dt)
                updates[#updates + 1] = dt
            end,
            fetch = function(_, url, options, callback)
                requests[#requests + 1] = { url = url, options = options }
                callback(nil, { status = 200, body = "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}" })
            end
        }

        local ApiClient = require("lib.api_client")
        local client = ApiClient.new(http_client)
        local resolved

        client:generate_text("prompt", { type = "object" }, "Step", function(payload)
            resolved = payload
        end)

        client:update(0.016)

        assertEquals(#requests, 1)
        assertEquals(requests[1].options.method, "POST")
        assertEquals(#updates, 1)
        assertTrue(resolved ~= nil, "expected callback to resolve")
        assertTrue(resolved.choices ~= nil, "expected choices in response")
    end)
end)
