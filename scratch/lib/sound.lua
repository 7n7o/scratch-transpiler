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
    {name = "play_sound", text = "play sound %m.sound", args = {"sound"}},
    {name = "play_sound_until_done", text = "play sound %m.sound until done", args = {"sound"}},
    {name = "stop_all_sounds", text = "stop all sounds", args = {}},
    {name = "play_drum_for_beats", text = "play drum %d.drum for %n beats", args = {"drum", "beats"}},
    {name = "rest_for_beats", text = "rest for %n beats", args = {"beats"}},
    {name = "play_note_for_beats", text = "play note %d.note for %n beats", args = {"note", "beats"}},
    {name = "set_instrument", text = "set instrument to %d.instrument", args = {"instrument"}},
    {name = "change_volume_by", text = "change volume by %n", args = {"amount"}},
    {name = "set_volume_percent", text = "set volume to %n%", args = {"percent"}},
    {name = "get_volume", text = "volume", args = {}, reporter = true, no_refresh = true},
    {name = "change_tempo_by", text = "change tempo by %n", args = {"amount"}},
    {name = "set_tempo_bpm", text = "set tempo to %n bpm", args = {"bpm"}},
    {name = "get_tempo", text = "tempo", args = {}, reporter = true, no_refresh = true}
}

local procs = {}
for i = 1, #defs do
    procs[i] = make_proc(defs[i])
end

return procs
