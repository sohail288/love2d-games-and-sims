local HttpClient = {}
HttpClient.__index = HttpClient

local function load_https()
    local ok, https_module = pcall(require, "https")
    if ok and https_module and type(https_module.request) == "function" then
        return https_module
    end
    return nil
end

local function load_fetch()
    if love and type(love.fetch) == "table" then
        return love.fetch
    end

    local ok, fetch_module = pcall(require, "fetch")
    if ok and type(fetch_module) == "table" then
        if love and love.fetch == nil then
            love.fetch = fetch_module
        end
        return fetch_module
    end

    return nil
end

local function is_web_platform()
    if not love or not love.system or type(love.system.getOS) ~= "function" then
        return false
    end

    local ok, platform = pcall(love.system.getOS)
    if not ok then
        return false
    end

    return platform == "Web"
end

local function invoke_fetch_request(fetch_module, url, options, on_success, on_error)
    if not fetch_module or type(fetch_module.request) ~= "function" then
        return false, "fetch.request is unavailable"
    end

    local errors = {}

    local function record_failure(err)
        if err then
            errors[#errors + 1] = tostring(err)
        end
    end

    local ok, result = pcall(fetch_module.request, url, options, on_success, on_error)
    if ok then
        return true
    end
    record_failure(result)

    local request_table = {}
    for key, value in pairs(options) do
        request_table[key] = value
    end
    request_table.url = url
    request_table.success = on_success
    request_table.callback = on_success
    request_table.onSuccess = on_success
    request_table.error = on_error
    request_table.failure = on_error
    request_table.onError = on_error

    ok, result = pcall(fetch_module.request, request_table)
    if ok then
        return true
    end
    record_failure(result)

    ok, result = pcall(fetch_module.request, url, on_success, on_error, options)
    if ok then
        return true
    end
    record_failure(result)

    local message = table.concat(errors, "; ")
    if message == "" then
        message = "fetch.request invocation failed"
    end
    return false, message
end

function HttpClient.new()
    local self = setmetatable({}, HttpClient)
    self._https = load_https()
    self._fetch = load_fetch()
    return self
end

function HttpClient:uses_fetch()
    if not self._fetch then
        return false
    end

    if not self._https then
        return true
    end

    return is_web_platform()
end

function HttpClient:update(dt)
    if self:uses_fetch() and self._fetch and type(self._fetch.update) == "function" then
        self._fetch.update(dt)
    end
end

function HttpClient:fetch(url, options, callback)
    options = options or {}

    if self:uses_fetch() then
        assert(type(callback) == "function", "HttpClient:fetch requires a callback when using fetch")

        local request_options = {
            method = options.method,
            headers = options.headers,
            data = options.body or options.data,
            body = options.body or options.data
        }

        local completed = false

        local function complete_with_error(err)
            if completed then
                return
            end
            completed = true
            callback(err or "HTTP request failed")
        end

        local ok, err = invoke_fetch_request(self._fetch, url, request_options, function(code, body, response_headers)
            if completed then
                return
            end
            completed = true
            callback(nil, {
                status = tonumber(code) or code,
                body = body,
                headers = response_headers
            })
        end, function(errmsg)
            complete_with_error(errmsg)
        end)

        if not ok then
            complete_with_error(err)
        end

        return nil
    end

    if not self._https then
        local err = "HTTPS module is unavailable"
        if callback then
            callback(err)
            return nil
        end
        return false, err
    end

    local code, body, response_headers = self._https.request(url, {
        method = options.method,
        headers = options.headers,
        data = options.body or options.data
    })

    if not code then
        local err = tostring(body or response_headers or "Unknown error")
        if callback then
            callback(err)
            return nil
        end
        return false, err
    end

    local response = {
        status = tonumber(code) or code,
        body = body,
        headers = response_headers
    }

    if callback then
        callback(nil, response)
        return nil
    end

    return true, response
end

return HttpClient
