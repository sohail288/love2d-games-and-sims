local function reset_module(name)
    package.loaded[name] = nil
    package.preload[name] = nil
end

if not newproxy then
    function newproxy()
        return {}
    end
end

describe("ApiClient", function()

    it("falls back to https synchronously when available", function()
        local captured_request
        reset_module("lib.api_client")
        reset_module("fetch")
        package.loaded["https"] = {
            request = function(url, params)
                captured_request = { url = url, params = params }
                return 200, "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}"
            end
        }
        local ApiClient = require("lib.api_client")
        local client = ApiClient.new()
        local response = client:generate_text("prompt", { type = "object" }, "Step")

        assertEquals(captured_request.params.method, "POST")
        assertTrue(response ~= nil, "expected response table")
        assertTrue(response.choices ~= nil, "expected choices in response")

        reset_module("lib.api_client")
        reset_module("https")
    end)

    it("uses fetch when running on the web", function()
        reset_module("lib.api_client")
        reset_module("https")
        reset_module("fetch")
        local updates = {}
        local requests = {}
        local fetch_stub = {
            request = function(url, options, on_success, _)
                table.insert(requests, { url = url, options = options })
                on_success(200, "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}")
            end,
            update = function(dt)
                table.insert(updates, dt)
            end
        }
        love = love or {}
        love.system = { getOS = function() return "Web" end }
        love.fetch = fetch_stub

        package.loaded["fetch"] = fetch_stub
        local ApiClient = require("lib.api_client")
        local client = ApiClient.new()
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

        reset_module("lib.api_client")
        reset_module("fetch")
        if love then
            love.fetch = nil
            love.system = nil
        end
    end)
end)
