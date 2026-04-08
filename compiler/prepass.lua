local logger = require("lib.logger")

local log = logger.new("COMPILER.PREPASS")

local ARRAY_CALL_HINTS = {
    array_len = true,
    array_insert = true,
    array_remove = true
}

local prepass = {}

local function shallow_copy_map(source)
    local copy = {}
    if source == nil then
        return copy
    end

    for key, value in pairs(source) do
        copy[key] = value
    end

    return copy
end

local function qualify_name(current_scope, name)
    if current_scope.proc ~= nil then
        return current_scope.proc .. "." .. name
    end
    return name
end

local function resolve_identifier_name(current_scope, name)
    if current_scope.var_bindings and current_scope.var_bindings[name] then
        return current_scope.var_bindings[name]
    end
    return qualify_name(current_scope, name)
end

local function is_arg(current_scope, name)
    if not current_scope.args then
        return false
    end

    for i = 1, #current_scope.args do
        if current_scope.args[i].Name == name then
            return true
        end
    end

    return false
end

local function is_array_arg(current_scope, name)
    return current_scope.array_args and current_scope.array_args[name] == true
end

local function register_array_var(state, current_scope, name, qualified_name)
    local resolved = qualified_name or qualify_name(current_scope, name)
    state.array_vars[resolved] = true
end

local function is_array_var(state, current_scope, name)
    local resolved = resolve_identifier_name(current_scope, name)
    return state.array_vars[resolved] == true or state.array_vars[qualify_name(current_scope, name)] == true
end

local function maybe_mark_array_from_call_hint(state, call_expr, current_scope)
    local base = call_expr.Base
    local args = call_expr.Arguments and call_expr.Arguments.ArgList

    if not (base and base.Type == "Ident" and args and #args > 0) then
        return
    end

    if not ARRAY_CALL_HINTS[base.Name] then
        return
    end

    local target = args[1]
    if target == nil or target.Type ~= "Ident" then
        return
    end

    if not is_arg(current_scope, target.Name) then
        register_array_var(state, current_scope, target.Name, resolve_identifier_name(current_scope, target.Name))
        log:debug("prepass.hint.var", "Inferred array variable from array API call", {name = target.Name, call = base.Name})
    end
end

local function scan_expr_for_hints(state, node, current_scope)
    if type(node) ~= "table" then
        return
    end

    if node.Type == "CallExpr" then
        maybe_mark_array_from_call_hint(state, node, current_scope)
    end

    for _, value in pairs(node) do
        if type(value) == "table" then
            scan_expr_for_hints(state, value, current_scope)
        end
    end
end

local scan_stat_for_array_returns

scan_stat_for_array_returns = function(state, stat, current_scope)
    if stat == nil then
        return
    end

    if stat.Type == "StatList" then
        for i = 1, #(stat.Statements or {}) do
            scan_stat_for_array_returns(state, stat.Statements[i], current_scope)
        end
        return
    end

    if stat.Type == "VarStat" then
        local decl = stat.Vars and stat.Vars.List and stat.Vars.List[1]
        local init_expr = stat.Init and stat.Init.List and stat.Init.List[1]

        if decl ~= nil then
            local var_name = qualify_name(current_scope, decl.Name)
            current_scope.var_bindings = current_scope.var_bindings or {}
            current_scope.var_bindings[decl.Name] = var_name

            if decl.PointerToken == true then
                register_array_var(state, current_scope, decl.Name, var_name)
            end

            if init_expr and init_expr.Type == "ArrayExpr" then
                register_array_var(state, current_scope, decl.Name, var_name)
            elseif init_expr and init_expr.Type == "CallExpr" and init_expr.Base and init_expr.Base.Type == "Ident" then
                if state.array_return_procs[init_expr.Base.Name] ~= nil then
                    register_array_var(state, current_scope, decl.Name, var_name)
                end
            end
        end

        scan_expr_for_hints(state, init_expr, current_scope)
        return
    end

    if stat.Type == "AssignStat" then
        local lhs = stat.Lhs and stat.Lhs[1]
        local rhs = stat.Rhs and stat.Rhs[1]

        if lhs and lhs.Type == "IndexExpr" and lhs.Base and lhs.Base.Type == "Ident" then
            if not is_arg(current_scope, lhs.Base.Name) then
                register_array_var(state, current_scope, lhs.Base.Name, resolve_identifier_name(current_scope, lhs.Base.Name))
            end
        end

        scan_expr_for_hints(state, lhs, current_scope)
        scan_expr_for_hints(state, rhs, current_scope)
        return
    end

    if stat.Type == "CallStat" then
        scan_expr_for_hints(state, stat.Expression, current_scope)
        return
    end

    if stat.Type == "RetStat" then
        local value_expr = stat.List and stat.List.List and stat.List.List[1]
        if value_expr and value_expr.Type == "Ident" and current_scope.proc ~= nil then
            if is_array_arg(current_scope, value_expr.Name) or is_array_var(state, current_scope, value_expr.Name) then
                state.array_return_procs[current_scope.proc] = resolve_identifier_name(current_scope, value_expr.Name)
                log:debug("prepass.return.array", "Detected array-returning procedure", {proc = current_scope.proc})
            end
        end
        scan_expr_for_hints(state, value_expr, current_scope)
        return
    end

    if stat.Type == "IfStat" then
        scan_expr_for_hints(state, stat.Condition, current_scope)
        scan_stat_for_array_returns(state, stat.Body, current_scope)
        for i = 1, #(stat.Elses or {}) do
            scan_expr_for_hints(state, stat.Elses[i].Condition, current_scope)
            scan_stat_for_array_returns(state, stat.Elses[i].Body, current_scope)
        end
        return
    end

    if stat.Type == "WhileStat" then
        scan_expr_for_hints(state, stat.Condition, current_scope)
        scan_stat_for_array_returns(state, stat.Body, current_scope)
        return
    end

    if stat.Type == "ForStat" then
        local id = string.format("%X", state.next_for_id)
        state.next_for_id = state.next_for_id + 1
        local nested_proc = string.format("%sForStat%s", current_scope.proc or "", id)

        local var_bindings = shallow_copy_map(current_scope.var_bindings)
        if stat.Name and stat.Name.Type == "Ident" then
            local for_name = stat.Name.Name
            local resolved = current_scope.proc ~= nil and (nested_proc .. "." .. for_name) or for_name
            var_bindings[for_name] = resolved
        end

        local nested_scope = {
            proc = nested_proc,
            args = current_scope.args,
            array_args = current_scope.array_args,
            var_bindings = var_bindings
        }

        scan_expr_for_hints(state, stat.Start, current_scope)
        scan_expr_for_hints(state, stat.Limit, current_scope)
        scan_expr_for_hints(state, stat.Step, current_scope)
        scan_stat_for_array_returns(state, stat.Body, nested_scope)
    end
end

function prepass.collect_array_return_procs(top_tree)
    local array_return_procs = {}
    if top_tree.Type ~= "StatList" then
        return array_return_procs
    end

    for i = 1, #(top_tree.Statements or {}) do
        local stat = top_tree.Statements[i]
        if stat.Type == "Procedure" then
            local state = {
                array_vars = {},
                array_return_procs = array_return_procs,
                next_for_id = 0
            }

            local args = stat.ArgList and stat.ArgList.Args or {}
            local array_args = {}
            for j = 1, #args do
                if args[j].PointerToken ~= nil then
                    array_args[args[j].Name] = true
                end
            end

            local proc_scope = {
                proc = stat.Name,
                args = args,
                array_args = array_args,
                var_bindings = {}
            }

            scan_stat_for_array_returns(state, stat.Body, proc_scope)
        end
    end

    return array_return_procs
end

return prepass