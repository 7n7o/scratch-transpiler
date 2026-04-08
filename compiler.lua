local serpent = require("lib.serpent")
local logger = require("lib.logger")
local visitors = require("visitors")
local file = require("lib.file")
local json = require("lib.json")

local log = logger.new("COMPILE")

local function deepcopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[deepcopy(k, seen)] = deepcopy(v, seen)
    end
    return copy
end

local function try_load_library(name)
    local lua_module = "scratch.lib." .. name
    local ok, loaded = pcall(require, lua_module)
    if ok then
        return loaded
    end

    local json_path = string.format("scratch/lib/%s.json", name)
    local handle = io.open(json_path, "rb")
    if handle ~= nil then
        handle:close()
        return json.decode(file.read(json_path))
    end

    error(string.format("Unable to load include library `%s` from scratch/lib (%s.lua or %s.json)", name, name, name))
end

local function collect_includes(top_tree)
    local include_names = {}
    local include_seen = {}

    if top_tree.Type ~= "StatList" then
        return include_names
    end

    for _, stat in ipairs(top_tree.Statements) do
        if stat.Type == "PrepStat" and stat.Base and stat.Base.Value == "include" then
            for i = 1, #(stat.Data or {}) do
                local lib = stat.Data[i]
                if type(lib) == "string" and lib ~= "" and not include_seen[lib] then
                    include_seen[lib] = true
                    include_names[#include_names + 1] = lib
                end
            end
        end
    end

    if #include_names == 0 then
        include_names[1] = "std"
    end

    return include_names
end

local function handle_call_exprs(expr, scope)

    local function new_scope(fields)
        local sc = {}
        for k, v in pairs(scope) do
            sc[k] = v
        end
        for k, v in pairs(fields) do
            sc[k] = v
        end
        sc.for_stats = 0
        return sc
    end

    local calls, refs = {}, {}


    visitors.generic(expr, {
        CallExpr = function(call_expr)
            local args = {}
            for i, arg in ipairs(call_expr.Arguments.ArgList) do
                -- local val = gen_stat(arg, scope)
          
                local val, atomic = gen_stat(arg, new_scope {
                    refs = refs
                })
                assert(atomic, string.format("Argument %d of CallExpr `%s` is not atomic", i, call_expr.Base.Name))
                args[i] = val
            end

            calls[#calls+1] = {"call", call_expr.Base.Name..string.rep(" %n", #args), unpack(args)}
            refs[call_expr] = #calls
        end
    })


    for k, v in pairs(refs) do
        refs[k] = #calls - v + 1
    end

    return {calls = calls, refs = refs}
end

local OP_MAP = {
    ["=="] = "="
}

function gen_stat(statement, scope)
    local stat_type = statement.Type

    local output = {}
    local atomic = false

    local function write_atomic(...)
        for _, v in ipairs({...}) do
            output[#output+1] = v
        end
        atomic = true
    end

    local function new_scope(fields)
        local sc = {}
        for k, v in pairs(scope) do
            sc[k] = v
        end
        for k, v in pairs(fields) do
            sc[k] = v
        end
        sc.for_stats = 0
        return sc
    end

    local function is_arg(name)
        if scope.args then
            for _,v in ipairs(scope.args) do
                if v.Name == name then return true end
            end
        end
        return false
    end

    if stat_type == "Procedure" then

        local args = statement.ArgList.Args

        local name = statement.Name .. string.rep(" %n", #args)

        local argNames, argTypes = {}, {}
        for i = 1, #args do
            argNames[i] = args[i].Name
            argTypes[i] = 1
        end

        output[#output+1] = {"procDef", name, argNames, argTypes, statement.NoRefresh}

        local body = gen_stat(statement.Body, new_scope {
            proc = statement.Name,
            args = args
        })
        for _, v in ipairs(body) do
            output[#output+1] = v
        end

    elseif stat_type == "StatList" then
        for _, stat in pairs(statement.Statements) do
             local st = gen_stat(stat, scope)
            for _, ln in ipairs(st) do
                output[#output+1] = ln
            end
        end
    elseif stat_type == "ExprList" then
        return gen_stat(statement.List[1], scope)
    elseif stat_type == "BinaryExpr" then
        local lhs = gen_stat(statement.Lhs, scope)
        local rhs = gen_stat(statement.Rhs, scope)
        local op = statement.Op

        write_atomic({OP_MAP[op] or op, lhs, rhs})
    elseif stat_type == "CallExpr" then
        if scope.refs then
            for k,v in pairs(scope.refs) do
                print(k.Base.Name, v, statement.Base.Name)
            end
            if scope.refs[statement] then
                write_atomic({"getLine:ofList:", scope.refs[statement], "@RETURN"})
            else
                log:drop("Unknown ref for CallExpr")
            end
        end

    elseif stat_type == "ParanExpr" then
        return gen_stat(statement.Expression, scope)
    
    elseif stat_type == "IndexExpr" then

        local base, value_expr = statement.Base, gen_stat(statement.Value, scope)

        assert(base.Type == "Ident", "Invalid Base of IndexExpr, must be Ident.")

        local var_name = base.Name
        if scope.proc ~= nil then
            var_name = scope.proc .. "." .. var_name
        end

        write_atomic({"getLine:ofList:", value_expr, var_name})

    elseif stat_type == "Ident" then
        local var_name = statement.Name

        if is_arg(statement.Name) then
            write_atomic({"getParam", var_name, "r"})
        else
            if scope.proc ~= nil then
                var_name = scope.proc .. "." .. var_name
            end
            write_atomic({"readVariable", var_name})
        end
    elseif stat_type == "RetStat" then
        local calls = handle_call_exprs(statement.List.List[1], scope)
        for _, d in ipairs(calls.calls) do
            output[#output+1] = d
        end
        local val = gen_stat(statement.List, new_scope {
            refs = calls.refs
        })
        output[#output+1] = {"insert:at:ofList:", val, 1, "@RETURN"}
        output[#output+1] = {"doReturn"}
    elseif stat_type == "NumberLit" or stat_type == "StringLit" then
        write_atomic(statement.Value)
    elseif stat_type == "CallStat" then
        local args = {}
        local calls = handle_call_exprs(statement.Expression.Arguments, scope)
        for _, d in ipairs(calls.calls) do
            output[#output+1] = d
        end
        
        for k,v in pairs(calls.refs) do
                print(k.Base.Name, v)
            end

        for i, arg in ipairs(statement.Expression.Arguments.ArgList) do
            -- local val = gen_stat(arg, scope)

            
            local val = gen_stat(arg, new_scope {
                refs = calls.refs
            })

            args[i] = val
        end

        output[#output+1] = {"call", statement.Expression.Base.Name..string.rep(" %n", #args), unpack(args)}

    elseif stat_type == "VarStat" then
        local var_name = statement.Vars.List[1].Name
        if scope.proc ~= nil then
            var_name = scope.proc .. "." .. var_name
        end

        local calls = handle_call_exprs(statement.Init.List[1], scope)
        for _, d in ipairs(calls.calls) do
            output[#output+1] = d
        end
        local val = gen_stat(statement.Init, new_scope {
            refs = calls.refs
        })
        


        output[#output+1] = {"setVar:to:", var_name, val}

    elseif stat_type == "AssignStat" then
        local lhs, rhs = statement.Lhs[1], statement.Rhs[1]

        assert(lhs.Type == "Ident" or lhs.Type == "IndexExpr", "Invalid Lhs of AssignStat, must be Ident or IndexExpr.")

        local var_name = lhs.Type == "Ident" and lhs.Name or lhs.Base.Name
        if scope.proc ~= nil then
            var_name = scope.proc .. "." .. var_name
        end

        local calls = handle_call_exprs(statement.Rhs[1], scope)
        for _, d in ipairs(calls.calls) do
            output[#output+1] = d
        end
        local val = gen_stat(rhs, new_scope {
            refs = calls.refs
        })
        
        if lhs.Type == "Ident" then
            output[#output+1] = {"setVar:to:", var_name, val}
        else
            local value = gen_stat(lhs.Value, scope)
            output[#output+1] = {"setLine:ofList:to:", value, var_name, val}
        end


    elseif stat_type == "IfStat" then
        local cond = statement.Condition
        local body = statement.Body
        local elses = statement.Elses

        local top_block = "doIf"

        local else_stat = {}
        local last_stat = nil

        for i, el in ipairs(elses) do
            top_block = "doIfElse"

            local el_cond = el.Condition
            local body = gen_stat(el.Body, scope)

            if el_cond ~= nil then
                local expr = gen_stat(el_cond, scope)
                
                local bl = elses[i+1] ~= nil and "doIfElse" or "doIf"
                if last_stat == nil then
                    local next_stat = bl == "doIfElse" and {} or nil
                    else_stat = {bl, expr, body, next_stat}
                    last_stat = next_stat
                else
                    local next_stat = bl == "doIfElse" and {} or nil
                    last_stat[1] = {bl, expr, body, next_stat}
                    -- last_stat[2] = expr
                    -- last_stat[3] = body
                    -- last_stat[4] = next_stat
                    last_stat = next_stat
                end
            else
                if last_stat ~= nil then
                    for k, v in pairs(body) do
                        last_stat[k] = v
                    end
                else
                    
                
                    else_stat = body
                end
            end

            
        end

        if last_stat ~= nil then
            else_stat = {else_stat}
        end

        local cond_expr = gen_stat(cond, scope)
        local body_stat = gen_stat(body, scope)


        output[#output+1] = {top_block, cond_expr, body_stat, #else_stat > 0 and else_stat or nil}

    elseif stat_type == "WhileStat" then
        local body, cond = statement.Body, statement.Condition

        local cond_expr = gen_stat(cond, scope)
        local body_stat = gen_stat(body, scope)

        output[#output+1] = {"doUntil", {"not", cond_expr}, body_stat}
    elseif stat_type == "ForStat" then
        local name, start, limit, step = statement.Name, statement.Start, statement.Limit, statement.Step
        local body = statement.Body

        assert(name.Type == "Ident", "Invalid var of ForStat, must be Ident.")

        local var_name = name.Name
        local ID = string.format("%X", scope.for_stats)
        scope.for_stats = scope.for_stats + 1
        local proc = string.format("%sForStat%s", scope.proc or "" , ID)
        if scope.proc ~= nil then
            var_name = proc .. "." .. var_name
        end

        
        local start_expr = gen_stat(start, scope)
        local limit_expr = gen_stat(limit, scope)
        local step_expr = gen_stat(step, scope)

        output[#output+1] = {"setVar:to:", var_name, start_expr}

        local body_stat = gen_stat(body, new_scope {
            proc = proc
        })
        
        body_stat[#body_stat+1] = {"changeVar:by:", var_name, step_expr}

        output[#output+1] = {"doUntil", {"=", {"readVariable", var_name}, {"+", limit_expr, step_expr}}, body_stat}
    else
        print("Unhandled statement of type: "..(stat_type or "unknown"))
    end
    if atomic then output = output[1] end
    return output, atomic
    
end

local function compile_tree(top_tree)
    local procs = {{0, 0, {
        {"whenGreenFlag"},
        {"call", "main"}
    }}}

    if top_tree.Type == "StatList" then
       for _, stat in pairs(top_tree.Statements) do
          if stat.Type == "Procedure" then
            local st = gen_stat(stat, {
                    for_stats = 0
                })
                table.insert(procs, {100, 100, st})
          end
       end 
    end

    local include_names = collect_includes(top_tree)
    for _, lib_name in ipairs(include_names) do
        local library = try_load_library(lib_name)
        for _, proc in ipairs(library) do
            table.insert(procs, deepcopy(proc))
        end
    end

    return procs
end

return {
    compile_tree = compile_tree
}
