local scope = {}
local logger = require("lib.logger")
local log = logger.new("COMPILER.SCOPE")

function scope.new(parent, fields)
    local next_scope = {}
    if parent then
        for key, value in pairs(parent) do
            next_scope[key] = value
        end
        next_scope._state = parent._state
    else
        next_scope._state = {for_stats = 0, array_stats = 0}
    end

    if fields then
        for key, value in pairs(fields) do
            next_scope[key] = value
        end
    end

    log:debug("scope.new", "Created scope", {
        has_parent = parent ~= nil,
        proc = next_scope.proc or "nil",
        has_args = next_scope.args ~= nil
    })
    return next_scope
end

function scope.is_arg(current_scope, name)
    if not current_scope.args then
        return false
    end

    for _, arg in ipairs(current_scope.args) do
        print(debug.getmetatable(arg))
        if arg.Name == name or getmetatable(arg) ~= nil then
            return true
        end
    end

    return false
end

function scope.qualify_name(current_scope, name)
    if current_scope.proc ~= nil then
        return current_scope.proc .. "." .. name
    end
    return name
end

function scope.next_for_id(current_scope)
    local id = current_scope._state.for_stats
    current_scope._state.for_stats = id + 1
    log:debug("scope.id.for", "Allocated for-loop id", {id = id})
    return id
end

function scope.next_array_id(current_scope)
    local id = current_scope._state.array_stats
    current_scope._state.array_stats = id + 1
    log:debug("scope.id.array", "Allocated array id", {id = id})
    return id
end

return scope
