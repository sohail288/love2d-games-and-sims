local function vectorToString(vector)
  local vectorString = "<"
  if vector.n == nil then
    return tostring(getmetatable(vector))
  end
  for i = 1, vector.n do
    if i == 1 then
      vectorString = vectorString .. tostring(vector:get(i))
    else
      vectorString = vectorString .. ", " .. tostring(vector:get(i))
    end
  end
  vectorString = vectorString .. ">"
  return vectorString
end

local VectorMeta = {}

function VectorMeta.__call(t, ...)
  local newObj = {}
  return VectorMeta:new(newObj, ...)
end

function VectorMeta:new(o, ...)
  local o = o or {}
  setmetatable(o, VectorMeta)
  self.__index = self
  self.__tostring = vectorToString
  o:init(...)
  return o
end

function VectorMeta.fromTable(t)
  local n = #t
  local new_vector = VectorMeta:new(nil, n)
  for i, v in ipairs(t) do
    new_vector:set(i, v)
  end
  return new_vector
end

function VectorMeta:init(n)
  -- create a zeroed vector
  self._table = {}
  self.n = n
  for i = 1, n do
    self._table[i] = 0
  end
end

function VectorMeta:get(i)
  return self._table[i]
end

function VectorMeta:set(i, v)
  self._table[i] = v
end

function VectorMeta:iadd(other_vector)
  if other_vector.n ~= self.n then
    error("other vector has size " .. tostring(other_vector.n) .. " : but should be " .. tostring(self.n))
  end
  for i, self_value in ipairs(self._table) do
    self._table[i] = self_value + other_vector:get(i)
  end
end

function VectorMeta:isubstract(other_vector)
  if other_vector.n ~= self.n then
    error("other vector has size " .. tostring(other_vector.n) .. " : but should be " .. tostring(self.n))
  end
  for i, self_value in ipairs(self._table) do
    self._table[i] = self_value - other_vector:get(i)
  end
end

function VectorMeta:iscale(scaling_factor)
  for i, self_value in ipairs(self._table) do
    self._table[i] = scaling_factor * self_value
  end
end

function VectorMeta:dot(other_vector)
  if other_vector.n ~= self.n then
    error("other vector has size " .. tostring(other_vector.n) .. " : but should be " .. tostring(self.n))
  end
  local sum = 0
  for i, v in ipairs(self._table) do
    sum = sum + v * other_vector:get(i)
  end
  return sum
end

function VectorMeta:angleBetween(other_vector)
  -- return angle in degrees between two vectors in radians
  local self_magnitude = self:magnitude()
  local other_magnitude = other_vector:magnitude()
  return math.acos(self:dot(other_vector) / (self_magnitude * other_magnitude))
end

function VectorMeta:magnitude()
  local square_sums = 0
  for _, v in ipairs(self._table) do
    square_sums = square_sums + v * v
  end
  return math.sqrt(square_sums)
end

function VectorMeta:getNormalizedVector()
  local result = VectorMeta:new(nil, self.n)
  local magnitude = self:magnitude()
  for i = 1, self.n do
    result:set(i, self:get(i) / magnitude)
  end
  return result
end

function VectorMeta:getBasisAngle()
  -- it's because angleBetween will only return values between 0 and pi
  -- this gives the compliment angle
  -- this then returns a value between 0 and 2 * pi
  local angle = self:angleBetween(self._BASIS_VECTOR)
  if self:get(2) < 0 then
    return 2 * math.pi - angle
  end
  return angle
end

function VectorMeta:__mul(alpha)
  local result = VectorMeta:new(nil, self.n)
  for i, v in ipairs(self._table) do
    result:set(i, v * alpha)
  end
  return result
end

function VectorMeta:__add(other_vector)
  if other_vector.n ~= self.n then
    error("other vector has size " .. tostring(other_vector.n) .. " : but should be " .. tostring(self.n))
  end
  local result = VectorMeta:new(nil, self.n)
  for i, v in ipairs(self._table) do
    result:set(i, v + other_vector:get(i))
  end
  return result
end

function VectorMeta:__sub(other_vector)
  if other_vector.n ~= self.n then
    error("other vector has size " .. tostring(other_vector.n) .. " : but should be " .. tostring(self.n))
  end
  local result = VectorMeta:new(nil, self.n)
  for i, v in ipairs(self._table) do
    result:set(i, v - other_vector:get(i))
  end
  return result
end

function VectorMeta:__pow(exponent)
  local result = VectorMeta:new(nil, self.n)
  for i, v in ipairs(self._table) do
    result:set(i, v ^ exponent)
  end
  return result
end

local Vector = setmetatable({ __index = VectorMeta, fromTable = VectorMeta.fromTable }, VectorMeta)

VectorMeta._BASIS_VECTOR = Vector.fromTable { 1, 0 }

return Vector
