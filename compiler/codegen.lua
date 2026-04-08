local logger = require("lib.logger")
local visitors = require("visitors")
local scope_lib = require("compiler.scope")

local log = logger.new("COMPILER.CODEGEN")

local OP_MAP = {
    ["=="] = "=",
    ["&&"] = "&",
    ["||"] = "|"
}

local NODE_GENERATORS = {}

local codegen = {}
codegen.__index = codegen

local function append_sequence(target, source)
    for i = 1, #source do
        target[#target + 1] = source[i]
    end
end

local function append_node_output(target, value, atomic)
    if atomic then
        target[#target + 1] = value
    else
        append_sequence(target, value)
    end
end

local function build_call_signature(name, argc)
    return name .. string.rep(" %n", argc)
end

local function shallow_copy_map(source)
    if source == nil then
        return {}
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

function codegen.new()
    local instance = setmetatable({
        array_vars = {},
        array_ref_vars = {},
        array_return_procs = {}
    }, codegen)
    log:debug("codegen.new", "Created codegen instance")
    return instance
end

function codegen:allocate_temp_var_name(current_scope, prefix)
    local id = scope_lib.next_array_id(current_scope)
    local name = scope_lib.qualify_name(current_scope, string.format("%s_%X", prefix or "__tmp", id))
    log:debug("temp.var.alloc", "Allocated temporary scalar variable", {name = name, prefix = prefix or "__tmp"})
    return name
end

function codegen:emit_copy_list(output, source_list_ref, target_list_ref, current_scope)
    log:info("array.copy.emit", "Emitting list copy routine", {
        source = source_list_ref,
        target = target_list_ref
    })
    local len_var = self:allocate_temp_var_name(current_scope, "__copy_len")
    local idx_var = self:allocate_temp_var_name(current_scope, "__copy_i")

    output[#output + 1] = {"deleteLine:ofList:", "all", target_list_ref}
    output[#output + 1] = {"setVar:to:", len_var, {"lineCountOfList:", source_list_ref}}
    output[#output + 1] = {"setVar:to:", idx_var, 1}
    output[#output + 1] = {"doRepeat", {"readVariable", len_var}, {
        {"append:toList:", {"getLine:ofList:", {"readVariable", idx_var}, source_list_ref}, target_list_ref},
        {"changeVar:by:", idx_var, 1}
    }}
end

function codegen:register_array_variable(current_scope, name, qualified_name)
    local resolved = qualified_name or scope_lib.qualify_name(current_scope, name)
    self.array_vars[resolved] = true
    log:debug("array.var.register", "Registered array variable", {name = name, resolved = resolved})
end

function codegen:register_array_reference_variable(current_scope, name, qualified_name)
    local resolved = qualified_name or scope_lib.qualify_name(current_scope, name)
    self.array_ref_vars[resolved] = true
    self.array_vars[resolved] = true
    log:debug("array.ref.register", "Registered array reference variable", {name = name, resolved = resolved})
end

function codegen:register_array_parameter(current_scope, name)
    current_scope.array_args = current_scope.array_args or {}
    current_scope.array_args[name] = true
    log:debug("array.arg.register", "Registered array parameter", {name = name})
end

function codegen:is_array_parameter(current_scope, name)
    return current_scope.array_args and current_scope.array_args[name] == true
end

function codegen:is_array_variable(current_scope, name)
    local resolved = self:resolve_identifier_name(current_scope, name)
    return self.array_vars[resolved] == true or self.array_vars[scope_lib.qualify_name(current_scope, name)] == true
end

function codegen:is_array_reference_variable(current_scope, name)
    local resolved = self:resolve_identifier_name(current_scope, name)
    return self.array_ref_vars[resolved] == true or self.array_ref_vars[scope_lib.qualify_name(current_scope, name)] == true
end

function codegen:allocate_array_temp_name(current_scope)
    local array_id = scope_lib.next_array_id(current_scope)
    local name = scope_lib.qualify_name(current_scope, string.format("__array_%X", array_id))
    log:debug("temp.array.alloc", "Allocated temporary array reference", {name = name})
    return name
end

function codegen:resolve_identifier_name(current_scope, name)
    if current_scope.var_bindings and current_scope.var_bindings[name] then
        return current_scope.var_bindings[name]
    end
    return scope_lib.qualify_name(current_scope, name)
end

function codegen:resolve_list_reference(expr, current_scope)
    if expr.Type == "Ident" then
        if scope_lib.is_arg(current_scope, expr.Name) then
            return {"getParam", expr.Name, "r"}
        end
        if self:is_array_reference_variable(current_scope, expr.Name) then
            return {"readVariable", self:resolve_identifier_name(current_scope, expr.Name)}
        end
        return self:resolve_identifier_name(current_scope, expr.Name)
    end

    local value, atomic = self:generate(expr, current_scope)
    assert(atomic, "Invalid list expression, must be atomic.")
    return value
end

function codegen:is_array_index_base(expr, current_scope)
    if expr.Type == "Ident" then
        if scope_lib.is_arg(current_scope, expr.Name) then
            return self:is_array_parameter(current_scope, expr.Name)
        end
        return self:is_array_variable(current_scope, expr.Name)
    end

    if expr.Type == "ArrayExpr" then
        return current_scope.array_refs and current_scope.array_refs[expr] ~= nil
    end

    return false
end

function codegen:infer_array_kind_from_call(call_expr, current_scope)
    local base = call_expr.Base
    local args = call_expr.Arguments and call_expr.Arguments.ArgList
    if not (base and base.Type == "Ident" and args and #args > 0) then
        return
    end

    local name = base.Name
    if name ~= "array_len" and name ~= "array_insert" and name ~= "array_remove" then
        return
    end

    local target = args[1]
    if target.Type ~= "Ident" then
        return
    end

    if scope_lib.is_arg(current_scope, target.Name) then
        return
    end

    self:register_array_variable(current_scope, target.Name, self:resolve_identifier_name(current_scope, target.Name))
    log:debug("array.infer.var", "Inferred array variable from call", {call = name, target = target.Name})
end

function codegen:emit_array_literal_to_list(output, array_expr, current_scope, list_ref)
    log:info("array.literal.emit", "Emitting array literal into list", {
        target = list_ref,
        values = #(array_expr.Inside and array_expr.Inside.Values or {})
    })
    output[#output + 1] = {"deleteLine:ofList:", "all", list_ref}

    local values = array_expr.Inside and array_expr.Inside.Values or {}
    local emitted_values = {}
    for i = 1, #values do
        local value = self:emit_expression_value(values[i], current_scope, output)
        emitted_values[#emitted_values + 1] = value
        output[#output + 1] = {"append:toList:", value, list_ref}
    end
    return emitted_values
end

function codegen:collect_nested_calls(expr, current_scope)
    log:debug("calls.collect.start", "Collecting nested call expressions", {expr_type = expr and expr.Type or "nil"})
    local calls = {}
    local refs = {}
    local array_refs = {}

    visitors.generic(expr, {
        ArrayExpr = function(array_expr)
            if array_refs[array_expr] ~= nil then
                return
            end

            local list_name = self:allocate_array_temp_name(current_scope)
            array_refs[array_expr] = list_name
            self:emit_array_literal_to_list(calls, array_expr, current_scope, list_name)
            log:debug("calls.collect.array", "Materialized inline array expression", {target = list_name})
        end,

        CallExpr = function(call_expr)
            self:infer_array_kind_from_call(call_expr, current_scope)
            local args = {}
            local arg_list = call_expr.Arguments.ArgList

            for i = 1, #arg_list do
                local value, atomic = self:generate(arg_list[i], scope_lib.new(current_scope, {
                    refs = refs,
                    array_refs = array_refs
                }))
                assert(atomic, string.format("Argument %d of CallExpr `%s` is not atomic", i, call_expr.Base.Name))
                args[i] = value
            end

            calls[#calls + 1] = {"call", build_call_signature(call_expr.Base.Name, #args), unpack(args)}
            refs[call_expr] = #calls
            log:debug("calls.collect.call", "Lowered nested call", {name = call_expr.Base.Name, argc = #args})
        end
    })

    for expression, index in pairs(refs) do
        refs[expression] = #calls - index + 1
    end

    local result = {
        calls = calls,
        refs = refs,
        array_refs = array_refs
    }
    log:debug("calls.collect.done", "Collected nested calls", {count = #calls})
    return result
end

function codegen:emit_expression_value(expr, current_scope, output)
    if expr.Type == "ArrayExpr" then
        local list_name = self:allocate_array_temp_name(current_scope)
        self:emit_array_literal_to_list(output, expr, current_scope, list_name)
        return list_name
    end

    local calls = self:collect_nested_calls(expr, current_scope)
    append_sequence(output, calls.calls)
    local value = self:generate(expr, scope_lib.new(current_scope, {
        refs = calls.refs,
        array_refs = calls.array_refs
    }))
    log:debug("expr.emit", "Emitted expression value", {expr_type = expr and expr.Type or "nil"})
    return value
end

function codegen:compile_else_chain(elses, current_scope)
    log:debug("if.else_chain.start", "Compiling else-chain", {branches = #elses})
    local top_block = nil
    local last_stat = nil
    local else_stat = {}

    for i = 1, #elses do
        local branch = elses[i]
        local body = self:generate(branch.Body, current_scope)
        top_block = "doIfElse"

        if branch.Condition ~= nil then
            local expr = self:generate(branch.Condition, current_scope)
            local block_name = elses[i + 1] ~= nil and "doIfElse" or "doIf"
            local next_branch = block_name == "doIfElse" and {} or nil
            local compiled = {block_name, expr, body, next_branch}

            if last_stat == nil then
                else_stat = compiled
            else
                last_stat[1] = compiled
            end

            last_stat = {next_branch}
        else
            if last_stat ~= nil then
                append_sequence(last_stat[1], body)
            else
                else_stat = body
            end
        end
    end

    if last_stat ~= nil then
        else_stat = {else_stat}
    end

    log:debug("if.else_chain.done", "Compiled else-chain", {top = top_block or "none"})
    return top_block, else_stat
end

function NODE_GENERATORS.Procedure(self, statement, current_scope)
    log:info("node.procedure.start", "Compiling procedure", {name = statement.Name})
    local args = statement.ArgList.Args
    local arg_names = {}
    local arg_types = {}

    for i = 1, #args do
        arg_names[i] = args[i].Name
        arg_types[i] = 1
    end

    local output = {
        {"procDef", build_call_signature(statement.Name, #args), arg_names, arg_types, statement.NoRefresh}
    }

    local array_args = {}
    for i = 1, #args do
        if args[i].PointerToken ~= nil then
            array_args[args[i].Name] = true
        end
    end

    local body, body_atomic = self:generate(statement.Body, scope_lib.new(current_scope, {
        proc = statement.Name,
        args = args,
        var_bindings = {},
        array_args = array_args
    }))
    append_node_output(output, body, body_atomic)

    log:info("node.procedure.done", "Compiled procedure", {name = statement.Name, argc = #args})
    return output, false
end

function NODE_GENERATORS.StatList(self, statement, current_scope)
    local output = {}
    local stats = statement.Statements

    for i = 1, #stats do
        local value, atomic = self:generate(stats[i], current_scope)
        append_node_output(output, value, atomic)
    end

    return output, false
end

function NODE_GENERATORS.ExprList(self, statement, current_scope)
    return self:generate(statement.List[1], current_scope)
end

function NODE_GENERATORS.BinaryExpr(self, statement, current_scope)
    log:debug("node.binary", "Compiling binary expression", {op = statement.Op})
    local lhs = self:generate(statement.Lhs, current_scope)
    local rhs = self:generate(statement.Rhs, current_scope)
    local op = statement.Op

    if op == "!=" then
        return {"not", {"=", lhs, rhs}}, true
    end

    if op == ">=" then
        return {"not", {"<", lhs, rhs}}, true
    end

    if op == "<=" then
        return {"not", {">", lhs, rhs}}, true
    end

    if op == ".." then
        return {"concatenate:with:", lhs, rhs}
    end

    return {OP_MAP[op] or op, lhs, rhs}, true
end

function NODE_GENERATORS.UnopExpr(self, statement, current_scope)
    log:debug("node.unary", "Compiling unary expression", {op = statement.Op})
    local rhs = self:generate(statement.Rhs, current_scope)
    local op = statement.Op

    if op == "!" then
        return {"not", rhs}, true
    end

    if op == "-" then
        return {"-", 0, rhs}, true
    end

    if op == "#" then
        local rhs_expr = statement.Rhs
        if rhs_expr.Type == "Ident" then
            if scope_lib.is_arg(current_scope, rhs_expr.Name) and self:is_array_parameter(current_scope, rhs_expr.Name) then
                return {"lineCountOfList:", {"getParam", rhs_expr.Name, "r"}}, true
            end

            if self:is_array_variable(current_scope, rhs_expr.Name) then
                if self:is_array_reference_variable(current_scope, rhs_expr.Name) then
                    return {"lineCountOfList:", {"readVariable", self:resolve_identifier_name(current_scope, rhs_expr.Name)}}, true
                end
                return {"lineCountOfList:", self:resolve_identifier_name(current_scope, rhs_expr.Name)}, true
            end
        elseif rhs_expr.Type == "ArrayExpr" then
            local list_ref = current_scope.array_refs and current_scope.array_refs[rhs_expr]
            if list_ref ~= nil then
                return {"lineCountOfList:", list_ref}, true
            end
        end

        return {"stringLength:", rhs}, true
    end

    log:error("node.unary.unsupported", "Unsupported unary operator", {op = tostring(op)})
    log:drop(string.format("Unsupported unary operator `%s`", tostring(op)))
    return nil, true
end

function NODE_GENERATORS.CallExpr(_, statement, current_scope)
    if current_scope.refs and current_scope.refs[statement] then
        return {"getLine:ofList:", current_scope.refs[statement], "@RETURN"}, true
    end

    log:error("node.call.ref_missing", "Call expression missing return reference")
    log:drop("Unknown ref for CallExpr")
    return nil, true
end

function NODE_GENERATORS.ParanExpr(self, statement, current_scope)
    return self:generate(statement.Expression, current_scope)
end

function NODE_GENERATORS.IndexExpr(self, statement, current_scope)
    log:debug("node.index", "Compiling index expression", {base_type = statement.Base.Type})
    local value_expr = self:generate(statement.Value, current_scope)
    if self:is_array_index_base(statement.Base, current_scope) then
        local list_ref = self:resolve_list_reference(statement.Base, current_scope)
        return {"getLine:ofList:", value_expr, list_ref}, true
    end

    local base_expr, atomic = self:generate(statement.Base, current_scope)
    assert(atomic, "IndexExpr base must be atomic.")
    return {"letter:of:", value_expr, base_expr}, true
end

function NODE_GENERATORS.Ident(self, statement, current_scope)
    log:debug("node.ident", "Resolving identifier", {name = statement.Name})
    if scope_lib.is_arg(current_scope, statement.Name) then
        return {"getParam", statement.Name, "r"}, true
    end

    if self:is_array_variable(current_scope, statement.Name) then
        if self:is_array_reference_variable(current_scope, statement.Name) then
            return {"readVariable", self:resolve_identifier_name(current_scope, statement.Name)}, true
        end
        return self:resolve_identifier_name(current_scope, statement.Name), true
    end

    return {"readVariable", self:resolve_identifier_name(current_scope, statement.Name)}, true
end

function NODE_GENERATORS.RetStat(self, statement, current_scope)
    log:debug("node.return.start", "Compiling return statement", {proc = current_scope.proc or "main"})
    local output = {}
    local value_expr = statement.List.List[1]

    if current_scope.proc and value_expr and value_expr.Type == "Ident" and self:is_array_variable(current_scope, value_expr.Name) then
        self.array_return_procs[current_scope.proc] = self:resolve_identifier_name(current_scope, value_expr.Name)
        log:info("return.array.track", "Tracked procedure array return", {
            proc = current_scope.proc,
            source = value_expr.Name
        })
    end

    local calls = self:collect_nested_calls(value_expr, current_scope)
    append_sequence(output, calls.calls)

    local value = self:generate(statement.List, scope_lib.new(current_scope, {
        refs = calls.refs,
        array_refs = calls.array_refs
    }))
    output[#output + 1] = {"insert:at:ofList:", value, 1, "@RETURN"}
    output[#output + 1] = {"doReturn"}

    log:debug("node.return.done", "Compiled return statement", {proc = current_scope.proc or "main"})
    return output, false
end

function NODE_GENERATORS.NumberLit(_, statement)
    return statement.Value, true
end

function NODE_GENERATORS.StringLit(_, statement)
    return statement.Value, true
end

function NODE_GENERATORS.BoolExpr(_, statement)
    return statement.Value, true
end

function NODE_GENERATORS.ArrayExpr(_, statement, current_scope)
    if current_scope.array_refs and current_scope.array_refs[statement] then
        return current_scope.array_refs[statement], true
    end

    log:error("node.arrayexpr.invalid_atomic", "ArrayExpr cannot be used directly as atomic expression")
    log:drop("ArrayExpr cannot be used directly as an atomic expression")
    return nil, true
end

function NODE_GENERATORS.CallStat(self, statement, current_scope)
    log:debug("node.callstat.start", "Compiling call statement", {name = statement.Expression.Base.Name})
    local output = {}
    local expr = statement.Expression
    local arg_list = expr.Arguments.ArgList
    local args = {}

    self:infer_array_kind_from_call(expr, current_scope)

    local calls = self:collect_nested_calls(expr.Arguments, current_scope)
    append_sequence(output, calls.calls)

    local arg_scope = scope_lib.new(current_scope, {
        refs = calls.refs,
        array_refs = calls.array_refs
    })
    for i = 1, #arg_list do
        args[i] = self:generate(arg_list[i], arg_scope)
    end

    output[#output + 1] = {"call", build_call_signature(expr.Base.Name, #args), unpack(args)}
    log:debug("node.callstat.done", "Compiled call statement", {name = expr.Base.Name, argc = #args})
    return output, false
end

function NODE_GENERATORS.VarStat(self, statement, current_scope)
    local decl = statement.Vars.List[1]
    log:debug("node.var.start", "Compiling variable declaration", {name = decl.Name})
    local output = {}
    local var_name = scope_lib.qualify_name(current_scope, decl.Name)
    local init_expr = statement.Init and statement.Init.List and statement.Init.List[1]

    if current_scope.var_bindings then
        current_scope.var_bindings[decl.Name] = var_name
    end

    if decl.PointerToken == true then
        self:register_array_variable(current_scope, decl.Name, var_name)
    end

    if init_expr and init_expr.Type == "ArrayExpr" then
        self:register_array_variable(current_scope, decl.Name, var_name)
        local emitted_values = self:emit_array_literal_to_list(output, init_expr, current_scope, var_name)
        current_scope.array_literal_elements = current_scope.array_literal_elements or {}
        current_scope.array_literal_elements[var_name] = emitted_values
        log:info("node.var.array_init", "Initialized array variable from literal", {name = var_name})
        return output, false
    end

    if decl.PointerToken == true and init_expr and init_expr.Type == "IndexExpr" and init_expr.Base.Type == "Ident" then
        self:register_array_reference_variable(current_scope, decl.Name, var_name)
        local value = self:emit_expression_value(init_expr, current_scope, output)
        output[#output + 1] = {"setVar:to:", var_name, value}
        log:info("node.var.array_ref_init", "Initialized array reference variable from index expression", {
            target = var_name
        })
        return output, false
    end

    if init_expr and init_expr.Type == "CallExpr" and init_expr.Base and init_expr.Base.Type == "Ident" then
        local return_array_ref = self.array_return_procs[init_expr.Base.Name]
        if return_array_ref ~= nil then
            self:register_array_variable(current_scope, decl.Name, var_name)
            self:emit_expression_value(init_expr, current_scope, output)
            self:emit_copy_list(output, return_array_ref, var_name, current_scope)
            log:info("node.var.array_copy_init", "Initialized array variable from procedure return", {
                target = var_name,
                source = return_array_ref
            })
            return output, false
        end
    end

    if init_expr == nil then
        if self:is_array_variable(current_scope, decl.Name) then
            output[#output + 1] = {"deleteLine:ofList:", "all", var_name}
            log:debug("node.var.default_array", "Initialized array variable to empty list", {name = var_name})
        else
            output[#output + 1] = {"setVar:to:", var_name, 0}
            log:debug("node.var.default_scalar", "Initialized scalar variable to zero", {name = var_name})
        end
        return output, false
    end

    local value = self:emit_expression_value(init_expr, current_scope, output)
    output[#output + 1] = {"setVar:to:", var_name, value}
    log:debug("node.var.done", "Initialized variable from expression", {name = var_name})
    return output, false
end

function NODE_GENERATORS.AssignStat(self, statement, current_scope)
    log:debug("node.assign.start", "Compiling assignment statement")
    local output = {}
    local lhs = statement.Lhs[1]
    local rhs = statement.Rhs[1]

    assert(lhs.Type == "Ident" or lhs.Type == "IndexExpr", "Invalid Lhs of AssignStat, must be Ident or IndexExpr.")

    if lhs.Type == "Ident" and self:is_array_variable(current_scope, lhs.Name) then
        local list_ref = self:resolve_identifier_name(current_scope, lhs.Name)
        if rhs.Type == "ArrayExpr" then
            self:emit_array_literal_to_list(output, rhs, current_scope, list_ref)
            log:info("node.assign.array_literal", "Assigned array literal to list variable", {name = lhs.Name})
        else
            log:error("node.assign.array_unsupported", "Unsupported array assignment form", {name = lhs.Name, rhs = rhs.Type})
            log:drop(string.format("Unsupported assignment to array variable `%s` (expected array literal)", lhs.Name))
        end
        return output, false
    end

    if lhs.Type == "IndexExpr" and lhs.Base.Type == "Ident" then
        if not scope_lib.is_arg(current_scope, lhs.Base.Name) then
            self:register_array_variable(current_scope, lhs.Base.Name, self:resolve_identifier_name(current_scope, lhs.Base.Name))
        end
    end

    local target_name = lhs.Type == "Ident" and lhs.Name or lhs.Base.Name
    target_name = self:resolve_identifier_name(current_scope, target_name)
    local value = self:emit_expression_value(rhs, current_scope, output)

    if lhs.Type == "Ident" then
        output[#output + 1] = {"setVar:to:", target_name, value}
    else
        local index_value = self:generate(lhs.Value, current_scope)
        local list_ref = self:resolve_list_reference(lhs.Base, current_scope)
        output[#output + 1] = {"setLine:ofList:to:", index_value, list_ref, value}
    end

    log:debug("node.assign.done", "Compiled assignment", {lhs_type = lhs.Type})
    return output, false
end

function NODE_GENERATORS.IfStat(self, statement, current_scope)
    log:debug("node.if.start", "Compiling if statement", {else_branches = #(statement.Elses or {})})
    local top_block, else_stat = self:compile_else_chain(statement.Elses, current_scope)
    local condition = self:generate(statement.Condition, current_scope)
    local body = self:generate(statement.Body, current_scope)

    local is_else = #else_stat > 0

    local output = {
        {top_block or "doIf", condition, body, is_else and else_stat or nil}
    }
    log:debug("node.if.done", "Compiled if statement")
    return output, false
end

function NODE_GENERATORS.WhileStat(self, statement, current_scope)
    log:debug("node.while.start", "Compiling while statement")
    local condition = self:generate(statement.Condition, current_scope)
    local body = self:generate(statement.Body, current_scope)

    local output = {
        {"doUntil", {"not", condition}, body}
    }
    log:debug("node.while.done", "Compiled while statement")
    return output, false
end

function NODE_GENERATORS.ForStat(self, statement, current_scope)
    assert(statement.Name.Type == "Ident", "Invalid var of ForStat, must be Ident.")
    log:debug("node.for.start", "Compiling for-loop", {var = statement.Name.Name})

    local id = string.format("%X", scope_lib.next_for_id(current_scope))
    local nested_proc = string.format("%sForStat%s", current_scope.proc or "", id)

    local var_name = statement.Name.Name
    if current_scope.proc ~= nil then
        var_name = nested_proc .. "." .. var_name
    end

    local start_expr = self:generate(statement.Start, current_scope)
    local limit_expr = self:generate(statement.Limit, current_scope)
    local step_expr = self:generate(statement.Step, current_scope)

    local output = {
        {"setVar:to:", var_name, start_expr}
    }

    local var_bindings = shallow_copy_map(current_scope.var_bindings)
    var_bindings[statement.Name.Name] = var_name

    local body = self:generate(statement.Body, scope_lib.new(current_scope, {
        proc = nested_proc,
        var_bindings = var_bindings
    }))
    body[#body + 1] = {"changeVar:by:", var_name, step_expr}

    output[#output + 1] = {"doUntil", {"=", {"readVariable", var_name}, {"+", limit_expr, step_expr}}, body}
    log:debug("node.for.done", "Compiled for-loop", {var = statement.Name.Name, nested_proc = nested_proc})
    return output, false
end

function codegen:generate(statement, current_scope)
    local node_type = statement.Type
    local generator = NODE_GENERATORS[node_type]

    if generator then
        log:debug("generate.node", "Dispatching node generator", {type = node_type})
        return generator(self, statement, current_scope)
    end

    log:error("generate.unhandled", "Unhandled statement type", {type = node_type or "unknown"})
    print("Unhandled statement of type: " .. (node_type or "unknown"))
    return {}, false
end

return codegen
