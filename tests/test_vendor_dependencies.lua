describe("game vendor dependencies", function()
    it("ships the knife timer module with homing rocket", function()
        local originalPath = package.path
        package.path = table.concat({
            "homing_rocket/?.lua",
            "homing_rocket/?/?.lua",
            originalPath
        }, ";")

        local ok, moduleOrErr = pcall(require, "vendor/knife/timer")
        package.path = originalPath

        assertTrue(ok, "expected to require homing rocket vendor timer module")
        assertTrue(type(moduleOrErr) == "table", "timer module should return a table")
    end)
end)
