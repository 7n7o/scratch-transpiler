local serpent = require("lib.serpent")

local function typeof(v)
    local t = type(v)
    if t ~= "table" or getmetatable(t) == nil then return t end
    return getmetatable(t).__type or t
end

local function symbol(name)
    local ID = math.random(0, 0xFFFFFF)

    local sym = newproxy(true)
    local mt = getmetatable(sym)

    local m = {__ID = string.format("%06X", ID), name = name,__type = "Symbol", __eq = function (t1, t2)
        if typeof(t1) == typeof(t2) then
            return getmetatable(t1).__ID == getmetatable(t2).__ID
        end
        return false
    end}

    for k, v in pairs(m) do mt[k] = v end
    return sym
end

local symbolVSet, symbolVGet = symbol "Class Setter", symbol "Class Getter"

local class = {
    get = symbolVGet,
    set = symbolVSet
}

class.__index = class

class.__call = function(self, classObj)

    assert(type(classObj.constructor) == "function", "Class needs constructor.")

    local getters, setters = {n = 0}, {n = 0}
    
    for k, v in pairs(classObj) do
    
        if typeof(v) == "table" then
            local getter, setter = v[symbolVGet], v[symbolVSet]
            
            if type(getter) == "function" then
                getters[k] = getter
                getters.n = getters.n + 1
            end

            if type(setter) == "function" then
                setters[k] = setter
                setters.n = setters.n + 1
            end
        end
    end
    
    classObj.new = function(...)
        local prototype = setmetatable({}, {__index = classObj})
        local obj = {}

        local mt = {__index = prototype, __type = "Class Instance"}
        if getters.n > 0 then
            mt.__index = function (self, key)
                if getters[key] then 
                    return getters[key](self, key) 
                end
                return prototype[key]
            end
        end

        if setters.n > 0 then
            mt.__newindex = function (self, key, value)
                if setters[key] then 

                    prototype[key] = setters[key](self, value) 
                    
                return end
                prototype[key] = value
            end
        end

        setmetatable(obj, mt)

        obj:constructor(...)

        return obj
    end

    return setmetatable(classObj, {__type = "Class"})
end


return setmetatable(class, class)