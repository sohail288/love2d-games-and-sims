local validOrientations = {
    north = true,
    south = true,
    east = true,
    west = true
}

local Unit = {}
Unit.__index = Unit

function Unit.new(args)
    assert(type(args) == "table", "args table required")
    assert(args.id, "unit id required")

    local orientation = args.orientation or "south"
    if args.orientation then
        assert(validOrientations[orientation], "invalid orientation")
    end
    local unit = {
        id = args.id,
        name = args.name or "Unit",
        faction = args.faction or "allies",
        speed = args.speed or 5,
        maxHp = args.maxHp or args.hp or 100,
        hp = args.hp or args.maxHp or 100,
        move = args.move or 4,
        attackRange = args.attackRange or 1,
        attackPower = args.attackPower or 25,
        col = args.col or 1,
        row = args.row or 1,
        visualCol = args.col or 1,
        visualRow = args.row or 1,
        timeCosts = args.timeCosts,
        orientation = orientation
    }

    return setmetatable(unit, Unit)
end

function Unit:setPosition(col, row)
    self.col = col
    self.row = row
    self.visualCol = self.visualCol or col
    self.visualRow = self.visualRow or row
end

function Unit:setRenderPosition(col, row)
    self.visualCol = col
    self.visualRow = row
end

function Unit:getRenderPosition()
    return self.visualCol or self.col, self.visualRow or self.row
end

function Unit:isAlive()
    return self.hp > 0
end

function Unit:takeDamage(amount)
    self.hp = math.max(0, self.hp - amount)
end

function Unit:isEnemyOf(other)
    return other and self.faction ~= other.faction
end

function Unit:setOrientation(orientation)
    assert(validOrientations[orientation], "invalid orientation")
    self.orientation = orientation
end

function Unit:getOrientation()
    return self.orientation or "south"
end

return Unit
