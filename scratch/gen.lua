local spec = require("scratch.spec")
local codegen = require("compiler.codegen").new()
local parser = require("lib.parser")
local serpent = require("lib.serpent")



local gen = {}

local CORE_OPS = {
    [spec.GET_VAR] = true,
    [spec.SET_VAR] = true,
    [spec.CHANGE_VAR] = true,
    [spec.GET_LIST] = true,
    [spec.CALL] = true,
    [spec.PROCEDURE_DEF] = true,
    [spec.GET_PARAM] = true
}

local CORE_ARITY = {
    [spec.GET_VAR] = 1,
    [spec.SET_VAR] = 2,
    [spec.CHANGE_VAR] = 2,
    [spec.GET_LIST] = 1
}

local CORE_ENTRIES = {
    [spec.GET_VAR] = {text = spec.GET_VAR, shape = "r", category = 0, opcode = spec.GET_VAR, defaults = {}, argc = 1},
    [spec.GET_LIST] = {text = spec.GET_LIST, shape = "r", category = 0, opcode = spec.GET_LIST, defaults = {}, argc = 1},
    [spec.CALL] = {text = spec.CALL, shape = " ", category = 0, opcode = spec.CALL, defaults = {}, argc = 1},
    [spec.PROCEDURE_DEF] = {text = spec.PROCEDURE_DEF, shape = " ", category = 0, opcode = spec.PROCEDURE_DEF, defaults = {}, argc = 4},
    [spec.GET_PARAM] = {text = spec.GET_PARAM, shape = "r", category = 0, opcode = spec.GET_PARAM, defaults = {}, argc = 1}
}

local function shallow_copy(source)
    local out = {}
    for k, v in pairs(source) do
        out[k] = v
    end
    return out
end

local function array_copy(source)
    local out = {}
    for i = 1, #source do
        out[i] = source[i]
    end
    return out
end

local function build_signature(name, argc)
    return name .. string.rep(" %n", argc)
end

local function normalize_spec_entry(row)
    local defaults = {}
    for i = 5, #row do
        defaults[#defaults + 1] = row[i]
    end

    local input_count = 0
    local pattern = row[1] or ""
    for _ in pattern:gmatch("%%[nbsdc%m]") do
        input_count = input_count + 1
    end

    local argc = #defaults
    if input_count > argc then
        argc = input_count
    end

    return {
        text = row[1],
        shape = row[2],
        category = row[3],
        opcode = row[4],
        defaults = defaults,
        argc = argc
    }
end

local function is_separator_row(row)
    return row[1] == "-" or row[1] == "--"
end

local function choose_default_candidate(candidates)
    if #candidates == 1 then
        return candidates[1]
    end

    for i = 1, #candidates do
        if candidates[i].category < 100 then
            return candidates[i]
        end
    end

    return candidates[1]
end

local function choose_candidate(candidates, shape)
    if shape == nil then
        return choose_default_candidate(candidates)
    end

    for i = 1, #candidates do
        if candidates[i].shape == shape then
            return candidates[i]
        end
    end
end

local function build_spec_index()
    local by_opcode = {}
    local by_text = {}

    for i = 1, #spec.commands do
        local row = spec.commands[i]
        if not is_separator_row(row) then
            local entry = normalize_spec_entry(row)

            by_opcode[entry.opcode] = by_opcode[entry.opcode] or {}
            by_opcode[entry.opcode][#by_opcode[entry.opcode] + 1] = entry

            by_text[entry.text] = by_text[entry.text] or {}
            by_text[entry.text][#by_text[entry.text] + 1] = entry
        end
    end

    return by_opcode, by_text
end

local SPEC_BY_OPCODE, SPEC_BY_TEXT = build_spec_index()

local function copy_entry(entry)
    local out = shallow_copy(entry)
    out.defaults = array_copy(entry.defaults)
    return out
end

local function resolve_entry(name, shape)
    if type(name) ~= "string" then
        error(string.format("Scratch block name must be a string, got `%s`", type(name)))
    end

    local matches = SPEC_BY_OPCODE[name]
    if matches == nil then
        matches = SPEC_BY_TEXT[name]
    end
    if matches == nil then
        local core_entry = CORE_ENTRIES[name]
        if core_entry ~= nil then
            return copy_entry(core_entry)
        end
        error(string.format("Unknown Scratch opcode or command `%s`", name))
    end

    local selected = choose_candidate(matches, shape)
    if selected == nil then
        if shape == "e" and name == "doIf" then
            return resolve_entry("doIfElse", shape)
        end
        error(string.format("Scratch command `%s` has no `%s` block shape", name, shape))
    end

    return copy_entry(selected)
end

local function validate_known_block(opcode, args, strict)
    local candidates = SPEC_BY_OPCODE[opcode]
    if not candidates then
        local expected = CORE_ARITY[opcode]
        if expected ~= nil then
            if #args ~= expected then
                error(string.format("Opcode `%s` expects exactly %d args, got %d", opcode, expected, #args))
            end
            return args
        end
        if strict then
            error(string.format("Unknown opcode `%s`", tostring(opcode)))
        end
        return args
    end

    local selected = choose_default_candidate(candidates)
    local argc = selected.argc
    if #args > argc then
        error(string.format("Opcode `%s` expects at most %d args, got %d", opcode, argc, #args))
    end

    if #args < argc then
        local padded = array_copy(args)
        for i = #args + 1, argc do
            local default = selected.defaults[i]
            if default == nil then
                error(string.format("Opcode `%s` expects exactly %d args, got %d", opcode, argc, #args))
            end
            padded[i] = default
        end
        return padded
    end

    return args
end

local function ensure_table(value, name)
    if type(value) ~= "table" then
        error(string.format("Expected table for `%s`", name))
    end
end

function gen.lookup_opcode(opcode)
    local matches = SPEC_BY_OPCODE[opcode]
    if not matches then
        return {}
    end

    local out = {}
    for i = 1, #matches do
        out[i] = copy_entry(matches[i])
    end
    return out
end

function gen.lookup_text(text)
    local matches = SPEC_BY_TEXT[text]
    if not matches then
        return {}
    end

    local out = {}
    for i = 1, #matches do
        out[i] = copy_entry(matches[i])
    end
    return out
end

function gen.resolve(name, shape)
    return resolve_entry(name, shape)
end

function gen.has_opcode(opcode)
    return CORE_OPS[opcode] == true or SPEC_BY_OPCODE[opcode] ~= nil
end

function gen.block(opcode, ...)
    local args = {...}

    if opcode == spec.CALL then
        if #args < 1 then
            error("`call` requires a procedure signature argument")
        end
        return {spec.CALL, unpack(args)}
    end

    if opcode == spec.PROCEDURE_DEF then
        if #args ~= 4 then
            error("`procDef` requires exactly 4 args: signature, argNames, argTypes, noRefresh")
        end
        ensure_table(args[2], "argNames")
        ensure_table(args[3], "argTypes")
        return {spec.PROCEDURE_DEF, args[1], args[2], args[3], args[4]}
    end

    if opcode == spec.GET_PARAM then
        if #args < 1 then
            error("`getParam` requires parameter name")
        end
        return {spec.GET_PARAM, args[1], args[2] or "r"}
    end

    local validated = validate_known_block(opcode, args, true)
    local block = {opcode}
    for i = 1, #validated do
        block[#block + 1] = validated[i]
    end
    return block
end

function gen.command(text, ...)
    local matches = SPEC_BY_TEXT[text]
    if not matches then
        error(string.format("Unknown command text `%s`", tostring(text)))
    end
    local entry = choose_default_candidate(matches)
    return gen.block(entry.opcode, ...)
end

function gen.signature(name, argc)
    return build_signature(name, argc or 0)
end

function gen.proc_def(name, arg_names, no_refresh, arg_types)
    arg_names = arg_names or {}
    ensure_table(arg_names, "arg_names")
    arg_types = arg_types or {}
    ensure_table(arg_types, "arg_types")

    if #arg_types == 0 then
        for i = 1, #arg_names do
            arg_types[i] = 1
        end
    end

    if #arg_names ~= #arg_types then
        error("`arg_names` and `arg_types` lengths must match")
    end

    return gen.block(spec.PROCEDURE_DEF, build_signature(name, #arg_names), arg_names, arg_types, no_refresh == true)
end

function gen.call(name_or_signature, ...)
    local args = {...}
    local signature = name_or_signature
    if type(signature) ~= "string" then
        error("`call` requires string signature or procedure name")
    end
    if not signature:find("%%n", 1, false) then
        signature = build_signature(signature, #args)
    end
    return gen.block(spec.CALL, signature, unpack(args))
end

function gen.get_param(name, kind)
    return gen.block(spec.GET_PARAM, name, kind or "r")
end

function gen.get_var(name)
    return {"readVariable", name}
end

function gen.set_var(name, value)
    return gen.block(spec.SET_VAR, name, value)
end

function gen.change_var(name, value)
    return gen.block(spec.CHANGE_VAR, name, value)
end

function gen.get_list(name)
    return gen.block(spec.GET_LIST, name)
end

function gen.script(x, y, blocks)
    blocks = blocks or {}
    ensure_table(blocks, "blocks")
    return {x or 100, y or 100, blocks}
end

function gen.proc_script(name, arg_names, body, options)
    options = options or {}
    body = body or {}
    ensure_table(body, "body")

    local blocks = {
        gen.proc_def(name, arg_names or {}, options.no_refresh == true, options.arg_types)
    }
    for i = 1, #body do
        blocks[#blocks + 1] = body[i]
    end
    return gen.script(options.x or 100, options.y or 100, blocks)
end

function gen.expr(src, scope)
    local ast = parser.parse(src)
    local c = codegen:generate(ast, scope or {
        globals = {
            vars = {},
            lists = {}
        }
    })
    return unpack(c)
end

function gen.code(src, scope)
    return gen.script(100, 100, {gen.expr(src, scope or {
        globals = {
            vars = {},
            lists = {}
        }
    })})
end


local function upgrade(func)
    return function(src)
        local _,lex,env = parser.parse("")
        lex.Source = src
        lex.Pos = 1
        lex.Line = 1
        lex.Tokens = {}
        lex:collect()

        -- print(serpent.block(expr()))

        local scope = {args = {setmetatable({}, {})}}

        local c = codegen:generate(env[func](), scope)
        return c
    end
end

gen.get_generator = upgrade

-- gen.expr = upgrade("expr")
-- gen.statement = upgrade("statement")

local ScriptWriter = {}
ScriptWriter.__index = ScriptWriter

function ScriptWriter:add(block)
    ensure_table(block, "block")
    self.blocks[#self.blocks + 1] = block
    return self
end

function ScriptWriter:raw(block)
    return self:add(block)
end

function ScriptWriter:emit(opcode, ...)
    self.blocks[#self.blocks + 1] = gen.block(opcode, ...)
    return self
end

function ScriptWriter:call(name_or_signature, ...)
    self.blocks[#self.blocks + 1] = gen.call(name_or_signature, ...)
    return self
end

function ScriptWriter:build()
    return gen.script(self.x, self.y, self.blocks)
end

function gen.new_script(x, y)
    return setmetatable({
        x = x or 100,
        y = y or 100,
        blocks = {}
    }, ScriptWriter)
end

gen.spec = spec
gen.spec_by_opcode = SPEC_BY_OPCODE
gen.spec_by_text = SPEC_BY_TEXT

return gen
