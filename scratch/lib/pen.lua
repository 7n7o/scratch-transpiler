local gen = require("scratch.gen")

local function p(name)
    return gen.get_param(name)
end

local function cmd(text, ...)
    return gen.command(text, ...)
end

local function to_param_values(arg_names)
    local values = {}
    for i = 1, #arg_names do
        values[i] = p(arg_names[i])
    end
    return values
end

local function make_proc(def)
    local values = to_param_values(def.args)
    local block = cmd(def.text, unpack(values))
    local body

    if def.reporter then
        body = {gen.call("return", block)}
    else
        body = {block}
    end

    return gen.proc_script(def.name, def.args, body, {
        no_refresh = def.no_refresh == true
    })
end

local defs = {
    {name = "clear_pen_trails", text = "clear", args = {}},
    {name = "stamp", text = "stamp", args = {}},
    {name = "pen_down", text = "pen down", args = {}},
    {name = "pen_up", text = "pen up", args = {}},
    {name = "set_pen_color", text = "set pen color to %c", args = {"color"}},
    {name = "change_pen_color_by", text = "change pen color by %n", args = {"amount"}},
    {name = "set_pen_hue", text = "set pen color to %n", args = {"hue"}},
    {name = "change_pen_shade_by", text = "change pen shade by %n", args = {"amount"}},
    {name = "set_pen_shade", text = "set pen shade to %n", args = {"shade"}},
    {name = "change_pen_size_by", text = "change pen size by %n", args = {"amount"}},
    {name = "set_pen_size", text = "set pen size to %n", args = {"size"}}
}

local procs = {}
for i = 1, #defs do
    procs[i] = make_proc(defs[i])
end

return procs
