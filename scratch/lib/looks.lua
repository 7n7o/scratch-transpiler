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
    {name = "say_for_seconds", text = "say %s for %n secs", args = {"message", "seconds"}},
    {name = "say", text = "say %s", args = {"message"}},
    {name = "think_for_seconds", text = "think %s for %n secs", args = {"message", "seconds"}},
    {name = "think", text = "think %s", args = {"message"}},
    {name = "show_sprite", text = "show", args = {}},
    {name = "hide_sprite", text = "hide", args = {}},
    {name = "switch_costume", text = "switch costume to %m.costume", args = {"costume"}},
    {name = "next_costume", text = "next costume", args = {}},
    {name = "switch_backdrop", text = "switch backdrop to %m.backdrop", args = {"backdrop"}},
    {name = "switch_backdrop_and_wait", text = "switch backdrop to %m.backdrop and wait", args = {"backdrop"}},
    {name = "next_backdrop", text = "next backdrop", args = {}},
    {name = "change_graphic_effect", text = "change %m.effect effect by %n", args = {"effect", "amount"}},
    {name = "set_graphic_effect", text = "set %m.effect effect to %n", args = {"effect", "value"}},
    {name = "clear_graphic_effects", text = "clear graphic effects", args = {}},
    {name = "change_size_by", text = "change size by %n", args = {"amount"}},
    {name = "set_size_percent", text = "set size to %n%", args = {"percent"}},
    {name = "go_to_front", text = "go to front", args = {}},
    {name = "go_back_layers", text = "go back %n layers", args = {"layers"}},
    {name = "get_costume_number", text = "costume #", args = {}, reporter = true, no_refresh = true},
    {name = "get_backdrop_name", text = "backdrop name", args = {}, reporter = true, no_refresh = true},
    {name = "get_backdrop_number", text = "backdrop #", args = {}, reporter = true, no_refresh = true},
    {name = "get_size", text = "size", args = {}, reporter = true, no_refresh = true}
}

local procs = {}
for i = 1, #defs do
    procs[i] = make_proc(defs[i])
end

return procs
