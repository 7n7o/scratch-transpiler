local gen = require("scratch.gen")
local scope = require("compiler.scope")

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

local function push(list, v)
    return cmd("add %s to %m.list", v, list)
end

local function len(list)
    return cmd("length of %m.list", list)
end

local function get(list, i)
    return cmd("item %d.listItem of %m.list", i, list)
end

local function set(list, i, v)
    return cmd("replace item %d.listItem of %m.list with %s", i, list, v)
end

local UNDEFINED = string.format("%03x__UNDEFINED__%03x", math.random(0, 0xFFF), math.random(0, 0xFFF))
local undefined = var("undefined")

local procs = {

    -- gen.proc_script("malloc", {"size"}, {
    --     gen.call("return", {"+", len("memory"), 1}),
    --     push("memory", p("size")),
    --     {"doRepeat", p("size"), {
    --         push("memory", undefined)
    --     }}
    -- }, {no_refresh = true}),

    gen.proc_script("memset", {"ptr", "value"}, {
        set("memory", {"+", p("ptr"), 1}, p("value"))
    }, {no_refresh = true}),
    
    gen.proc_script("memget", {"ptr"}, {
        gen.call("return", get("memory", {"+", p("ptr"), 1}))
    }, {no_refresh = true}),

    gen.code([[
        proc malloc(size) {
            var i = 1
            var c = 99999999999
            var f = 0
            for _ = 0, (#free_blocks / 2), 1 {
                var a = free_blocks[i]
                var b = free_blocks[i+1]
                if (b < c && b > size) {
                    c = b
                    f = i
                }
                if (b == size) {
                    return alloc_block(a,b,i)
                }
                i = i+2
            }

            if (f == 0) {
                return alloc_new(size)
            } else {
                return alloc_block(free_blocks[f], size, f)    
            }
        }
    ]], scope.new(nil, {
        globals = {
            vars = {},
            lists = {
                -- free_blocks = true
            },
            info = {}
        }
    })),

    gen.code([[
        proc alloc_block(ptr, size, block_index) {
            var a = free_blocks[block_index]
            var b = free_blocks[block_index + 1]
            var s = size
            
        }
    ]], scope.new(nil, {
        globals = {
            vars = {},
            lists = {
                -- free_blocks = true
            },
            info = {}
        }
    })),

    
    gen.code([[
        proc free(ptr) {
            var length = memget(ptr, -1) - 1
            for i = 0, length, 1 {
                memset(ptr - i - 1, undefined)
            }
        }
    ]], scope.new(nil, {
        globals = {
            vars = {},
            lists = {},
            info = {}
        },
    
    })),

    -- gen.new_script(0, 0)
    --     :add(cmd("when @greenFlag clicked"))
    --     :add(cmd("set %m.var to %s", "undefined", UNDEFINED))
    --     :build()
}


local lists = {
    {
        listName = "memory",
        contents = {},
        isPersistent = false,
        x = 0,
        y = 0,
        width = 240,
        height = 180,
        visible = false
    },
    {
        listName = "free_blocks",
        contents = {},
        isPersistent = false,
        x = 0,
        y = 0,
        width = 240,
        height = 180,
        visible = false
    }
}

local vars = {
    {
        name = "undefined",
        value = UNDEFINED,
        isPersistent = true,
    }
}

return {
    procs = procs,
    lists = lists,
    vars = vars
}
