local DialogueSystem = {}
DialogueSystem.__index = DialogueSystem

local function validateEntry(entry)
    assert(type(entry) == "table", "dialogue entry must be a table")
    assert(type(entry.text) == "string" and entry.text ~= "", "dialogue entry requires non-empty text")
end

function DialogueSystem.new(script)
    local self = setmetatable({}, DialogueSystem)
    self:setScript(script or {})
    return self
end

function DialogueSystem:setScript(script)
    self._entries = {}
    self._index = 1
    if not script then
        return
    end
    for _, entry in ipairs(script) do
        validateEntry(entry)
        local stored = {
            text = entry.text,
            speaker = entry.speaker,
            metadata = entry.metadata
        }
        table.insert(self._entries, stored)
    end
end

function DialogueSystem:isFinished()
    return self._index > #self._entries or #self._entries == 0
end

function DialogueSystem:current()
    if self:isFinished() then
        return nil
    end
    return self._entries[self._index]
end

function DialogueSystem:advance()
    if not self:isFinished() then
        self._index = self._index + 1
    end
    return self:current()
end

function DialogueSystem:reset()
    self._index = 1
    return self:current()
end

function DialogueSystem:length()
    return #self._entries
end

return DialogueSystem
