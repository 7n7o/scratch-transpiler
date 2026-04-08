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
    {name = "move_steps", text = "move %n steps", args = {"steps"}},
    {name = "turn_right", text = "turn @turnRight %n degrees", args = {"degrees"}},
    {name = "turn_left", text = "turn @turnLeft %n degrees", args = {"degrees"}},
    {name = "point_in_direction", text = "point in direction %d.direction", args = {"direction"}},
    {name = "point_towards", text = "point towards %m.spriteOrMouse", args = {"target"}},
    {name = "go_to_xy", text = "go to x:%n y:%n", args = {"x", "y"}},
    {name = "go_to_target", text = "go to %m.location", args = {"target"}},
    {name = "glide_to_xy", text = "glide %n secs to x:%n y:%n", args = {"seconds", "x", "y"}},
    {name = "change_x_by", text = "change x by %n", args = {"amount"}},
    {name = "set_x", text = "set x to %n", args = {"x"}},
    {name = "change_y_by", text = "change y by %n", args = {"amount"}},
    {name = "set_y", text = "set y to %n", args = {"y"}},
    {name = "bounce_on_edge", text = "if on edge, bounce", args = {}},
    {name = "set_rotation_style", text = "set rotation style %m.rotationStyle", args = {"style"}},
    {name = "get_x_position", text = "x position", args = {}, reporter = true, no_refresh = true},
    {name = "get_y_position", text = "y position", args = {}, reporter = true, no_refresh = true},
    {name = "get_direction", text = "direction", args = {}, reporter = true, no_refresh = true}
}

local procs = {}
for i = 1, #defs do
    procs[i] = make_proc(defs[i])
end

return procs
