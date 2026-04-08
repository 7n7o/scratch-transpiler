local traverse = {}

local function visit(node, visitors)
    local traverse_function = traverse[node.Type]
    if type(traverse_function) == "function" then
        traverse_function(node, function(n) visit(n, visitors) end)
    end
    if visitors[node.Type] then
        visitors[node.Type](node)
    end
end

local visit_base = function(expr, visit)
    visit(expr.Base, visit)
end

local function visit_list(list, visit)
    for _, node in ipairs(list) do
        visit(node)
    end
end

local expressions = {
    ParanExpr = function(expr, visit)
        visit(expr.Expression)
    end,
    ArrayExpr = function(expr, visit)
        visit(expr.Inside)
    end,

    ---------------

    FieldExpr = function(expr, visit)
        visit(expr.Field)
        visit_base(expr, visit)
    end,

    IndexExpr = function(expr, visit)
        visit(expr.Value)
        visit_base(expr, visit)
    end,

    CallExpr = function(expr, visit)
        visit(expr.Arguments, visit)
        visit_base(expr, visit)
    end,


    ---------------

    UnopExpr = function(expr, visit)
        visit(expr.Rhs)
    end,

    BinaryExpr = function(expr, visit)
        visit(expr.Lhs)
        visit(expr.Rhs)
    end
}

local statements = {
    CallStat = function(stat, visit)
        visit(stat.Expression)
    end,

    AssignStat = function(stat, visit)
        visit_list(stat.Lhs, visit)
        visit_list(stat.Rhs, visit)
    end,

    VarStat = function(stat, visit)
        visit(stat.Init)
        visit(stat.Vars)
    end,

    RetStat = function(stat, visit)
        visit(stat.List)
    end,

    IfStat = function(stat, visit)
        visit(stat.Condition)
        visit(stat.Body)
        for _, el in ipairs(stat.Elses) do
            visit(el.Condition)
            visit(el.Body)
        end
    end,

    ForStat = function(stat, visit)
        visit(stat.Start)
        visit(stat.Limit)
        visit(stat.Step)
        visit(stat.Body)
    end,

    WhileStat = function(stat, visit)
        visit(stat.Condition)
        visit(stat.Body)
    end,

    Procedure = function(proc, visit)
        visit(proc.Body)
    end,
}

local lists = {
    ArgList = function(list, visit)
        visit_list(list.Args, visit)
    end,
    VarList = function(list, visit)
        visit_list(list.List, visit)
    end,
    ExprList = function(list, visit)
        visit_list(list.List, visit)
    end,
    StatList = function(list, visit)
        visit_list(list.Statements, visit)
    end,
}

local special = {
    Arguments = function(arguments, visit)
        visit_list(arguments.ArgList, visit)
    end
}

for _, l in ipairs {expressions, statements, lists, special} do
    for k, v in pairs(l) do
        traverse[k] = v
    end
end

local brute_cache = {}
local function visit_brute(node, visitors)
    if type(node) ~= "table" then return false end
    if type(node.Type) == "string" then

        if visitors[node.Type] then
            visitors[node.Type](node)
        end

        if brute_cache[node.Type] then
            for _, v in ipairs(brute_cache[node.Type]) do
                visit_brute(node[v], visitors)
            end
        else
            local cache = {}
            for k, v in pairs(node) do
                if visit_brute(v, visitors) == true then
                    table.insert(cache, k)
                end
            end
            brute_cache[node.Type] = cache
        end
        return true
    else
        local a = false
        for _, v in ipairs(node) do
            if visit_brute(v, visitors) then a = true end
        end
        return a
    end
end

return {
    generic = visit,
    brute = visit_brute,
    brute_cache = brute_cache
}