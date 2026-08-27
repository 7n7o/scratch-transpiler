local gen = require("scratch.gen")

local function p(name)
    return gen.get_param(name)
end

local function cmd(text, ...)
    return gen.command(text, ...)
end

local function var(name)
    return gen.get_var(name)
end

local function join(a,b)
    return cmd("join %s %s", a, b)
end

local get_gen = gen.get_generator

local expr, stat = get_gen("expr"), get_gen("statement")

local print_max_args = 10

local procs = {
    gen.proc_script("ask", {"question"}, {
        cmd("ask %s and wait", p("question")),
        gen.call("return", {"answer"})
    }, {no_refresh = false}),

    gen.proc_script("return", {"value"}, {
        cmd("insert %s at %d.listItem of %m.list", p("value"), 1, "@RETURN")
    }, {no_refresh = true}),

    gen.proc_script("sleep", {"ms"}, {
        cmd("wait %n secs", expr[[ms / 1000]])
    }, {no_refresh = true}),      
    
    -- gen.proc_script("contains", {"array", "value"}, {
        
    -- }),

    gen.new_script(0, 0)
        :add(cmd("when @greenFlag clicked"))
        :add(cmd("show list %m.list", "output"))
        :build()
}

for i = 1, print_max_args do

    local args = {}
    local body = {
        gen.set_var("print.out", "")
    }

    for arg_count = 1, i do
        local arg_name = "i"..arg_count
        table.insert(args, arg_name)
        table.insert(body, gen.set_var("print.out", join(var("print.out"),
            arg_count == i and p(arg_name) or join(p(arg_name), " ")
        )))
    end

    table.insert(body, cmd(
        "insert %s at %d.listItem of %m.list",
         var("print.out"),
         "1", 
         "output"
        ))

    procs[#procs+1] = gen.proc_script("print", args, body, {no_refresh = true})
end

local lists = {
    {
        listName = "output",
        contents = {},
        isPersistent = false,
        x = 0,
        y = 0,
        width = 240,
        height = 180,
        visible = true
    },
}

return {
    procs = procs,
    lists = lists
}
