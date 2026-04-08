local gen = require("scratch.gen")

local function p(name)
    return gen.get_param(name)
end

local function cmd(text, ...)
    return gen.command(text, ...)
end
local get_gen = gen.get_generator

local expr, stat = get_gen("expr"), get_gen("statement")

return {
    gen.proc_script("ask", {"question"}, {
        cmd("ask %s and wait", p("question")),
        gen.call("return", {"answer"})
    }, {no_refresh = false}),

    gen.proc_script("return", {"value"}, {
        cmd("insert %s at %d.listItem of %m.list", p("value"), 1, "@RETURN")
    }, {no_refresh = true}),

    gen.proc_script("print", {"x"}, {
        cmd("insert %s at %d.listItem of %m.list", p("x"), 1, "output")
    }, {no_refresh = true}),

    gen.proc_script("array_len", {"arr"}, {
        gen.call("return", cmd("length of %m.list", p("arr")))
    }, {no_refresh = true}),

    gen.proc_script("array_insert", {"arr", "value", "pos"}, {
        cmd("insert %s at %d.listItem of %m.list", p("value"), p("pos"), p("arr"))
    }, {no_refresh = true}),

    gen.proc_script("array_insert", {"arr", "value"}, {
        gen.call("array_insert", p("arr"), p("value"), 1)
    }, {no_refresh = true}),

    gen.proc_script("array_remove", {"arr", "idx"}, {
        gen.call("return", cmd("item %d.listItem of %m.list", p("idx"), p("arr"))),
        cmd("delete %d.listDeleteItem of %m.list", p("idx"), p("arr"))
    }, {no_refresh = true}),

    gen.proc_script("get_pos_in_list", {"list", "value"}, {
        cmd("set %m.var to %s", "__iter", 0),
        {"doIf", {"not", cmd("%m.list contains %s?", p("list"), p("value"))},
            {
                gen.call("return", 0),
                cmd("stop script")
            },
        },
        
        {"doRepeat", cmd("length of %m.list", p("list")), {
            cmd("change %m.var by %n", "__iter", 1),
            {"doIf", {"=", cmd("item %d.listItem of %m.list", gen.get_var("__iter"), p("list")), p("value")},
                {
                    gen.call("return", gen.get_var("__iter")),
                    cmd("stop script")
                }
            }
        }}

    }, {no_refresh = true}),

    gen.proc_script("sleep", {"ms"}, {
        cmd("wait %n secs", expr[[ms / 1000]])
    }, {no_refresh = true}),       

    gen.new_script(0, 0)
        :add(cmd("when @greenFlag clicked"))
        :add(cmd("show list %m.list", "output"))
        :build()
}
