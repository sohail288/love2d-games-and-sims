describe("ci_preview.preview_builder", function()
    local builder = require("ci_preview.preview_builder")

    it("treats successful os.execute booleans as exit code zero", function()
        local exitCode = builder.runCommand("echo ok", function()
            return true, "exit", 0
        end)
        assertEquals(exitCode, 0)
    end)

    it("propagates non-zero exit codes from os.execute", function()
        local ok, err = pcall(function()
            builder.runCommand("false", function()
                return nil, "exit", 127
            end)
        end)
        assertTrue(ok == false, "expected runCommand to raise when os.execute fails")
        assertTrue(err:find("command failed %(127%)") ~= nil, "error message should include exit code")
    end)

    it("handles legacy numeric return codes", function()
        local exitCode = builder.runCommand("noop", function()
            return 0
        end)
        assertEquals(exitCode, 0)
    end)
end)
