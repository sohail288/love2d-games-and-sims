local Unit = {}
Unit.__index = Unit

function Unit.new(args)
    assert(type(args) == "table", "args table required")
    assert(args.id, "unit id required")

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
        row = args.row or 1
    }

    return setmetatable(unit, Unit)
end

function Unit:setPosition(col, row)
    self.col = col
    self.row = row
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

return Unit
