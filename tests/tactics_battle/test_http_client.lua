local function reset_module(name)
    package.loaded[name] = nil
    package.preload[name] = nil
end

describe("HttpClient", function()
    it("performs synchronous requests via https when available", function()
        reset_module("lib.http_client")
        package.loaded["https"] = {
            request = function(url, params)
                return 200, "{}", { method = params.method }
            end
        }

        local HttpClient = require("lib.http_client")
        local client = HttpClient.new()
        assertTrue(not client:uses_fetch(), "expected https path")

        local ok, response = client:fetch("https://example.com", { method = "POST", body = "{}" })
        assertTrue(ok, "expected synchronous request to succeed")
        assertEquals(response.status, 200)
        assertEquals(response.headers.method, "POST")

        reset_module("lib.http_client")
        reset_module("https")
    end)

    it("delegates to fetch on the web platform", function()
        reset_module("lib.http_client")
        reset_module("https")
        reset_module("fetch")

        local updates = {}
        local requests = {}
        local fetch_stub = {
            request = function(url, options, on_success)
                requests[#requests + 1] = { url = url, options = options }
                on_success(200, "{}", { method = options.method })
            end,
            update = function(dt)
                updates[#updates + 1] = dt
            end
        }

        love = love or {}
        love.system = { getOS = function() return "Web" end }
        love.fetch = fetch_stub
        package.loaded["fetch"] = fetch_stub

        local HttpClient = require("lib.http_client")
        local client = HttpClient.new()
        assertTrue(client:uses_fetch(), "expected fetch path")

        local resolved
        client:fetch("https://example.com", { method = "POST", body = "{}" }, function(err, response)
            resolved = { err = err, response = response }
        end)

        client:update(0.016)

        assertEquals(#requests, 1)
        assertEquals(requests[1].options.method, "POST")
        assertEquals(#updates, 1)
        assertTrue(resolved ~= nil, "expected callback to be invoked")
        assertTrue(resolved.err == nil, "expected no error")
        assertEquals(resolved.response.status, 200)

        love.fetch = nil
        love.system = nil
        love = nil
        reset_module("lib.http_client")
        reset_module("fetch")
    end)

    it("errors when fetch is required but no callback is supplied", function()
        reset_module("lib.http_client")
        reset_module("https")
        reset_module("fetch")

        local fetch_stub = {
            request = function() end,
            update = function() end
        }

        love = love or {}
        love.system = { getOS = function() return "Web" end }
        love.fetch = fetch_stub
        package.loaded["fetch"] = fetch_stub

        local HttpClient = require("lib.http_client")
        local client = HttpClient.new()

        local ok, err = pcall(function()
            client:fetch("https://example.com", { method = "GET" })
        end)

        assertTrue(not ok, "expected fetch without callback to raise")
        local message = tostring(err)
        assertTrue(message:match("requires a callback"), "expected helpful error message")

        love.fetch = nil
        love.system = nil
        love = nil
        reset_module("lib.http_client")
        reset_module("fetch")
    end)
end)
