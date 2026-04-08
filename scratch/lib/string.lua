local gen = require("scratch.gen")

local function p(name)
    return gen.get_param(name)
end

local function cmd(text, ...)
    return gen.command(text, ...)
end

local function keyify(tbl)
    for i, v in ipairs(tbl) do
        tbl[v] = v
        tbl[i] = nil
    end
    return tbl
end
local get_gen = gen.get_generator

local expr, stat = get_gen("expr"), get_gen("statement")

function merge(...)
    local new = {}
    for _, tbl in ipairs({...}) do
        for _, v in ipairs(tbl) do
            table.insert(new, v)
        end
    end
    
    return new
end

local function costume(name)
    return {
        costumeName = name,
        baseLayerID = 0,
        baseLayerMD5 = "d36f6603ec293d2c2198d3ea05109fe0.png",
        bitmapResolution = 2,
        rotationCenterX = 0,
        rotationCenterY = 0
    }
end

local costumes = {
 costume("costume")   
}

for i = ("A"):byte(), ("Z"):byte() do
    costumes[#costumes+1] = costume(string.char(i))
end

local procs = {

    gen.proc_script("is_uppercase", {"char"}, {
        cmd("switch costume to %m.costume", "costume"),
        cmd("switch costume to %m.costume", p("char")),
        {"doIfElse", {"=", cmd("costume #"), 1}, {
            gen.call("return", "false")
        }, {
            gen.call("return", "true")
        }}
    }, {no_refresh = true}),

    gen.proc_script("to_ascii", {"byte"}, {
        gen.call("return", cmd("item %d.listItem of %m.list", {"-", p("byte"), 31}, "ascii"))
    }, {no_refresh = true}),

    gen.proc_script("from_ascii", {"char"}, {
        {"doIfElse", cmd("%m.list contains %s?", "ascii", p("char")),
            {},
            {
                gen.call("return", {})
            }
        }
    }, {no_refresh = true}),

    gen.proc_script("join", {"a", "b"}, {
        gen.call("return", cmd("join %s %s", p("a"), p("b")))
    }, {no_refresh = true}),

    gen.proc_script("index", {"str", "idx"}, {
        gen.call("return", cmd("letter %n of %s", p("idx"), p("str")))
    }, {no_refresh = true}),

    gen.proc_script("strlen", {"str"}, {
        gen.call("return", cmd("length of %s", p("str")))
    }, {no_refresh = false}),

    gen.code[[
        proc format(str, *args) {
            var out = ""
            var len = #str
            
            var i = 1
            var arg_ptr = 0;
            while (i <= len) {
                var char = str[i]
                if (char == "%") {
                    i = i + 1
                    if (str[i] == "%") {
                        out = out .. "%"
                    } else if (str[i] == "s") {
                        arg_ptr = arg_ptr + 1
                        out = out .. args[arg_ptr]
                    }
                } else {
                    out = out .. char
                }
                i = i + 1
            }
            return out
        } 
    ]],
}

local lists = {}

local function list(name, contents)
    return {
			listName = name,
			contents = contents,
			isPersistent = false,
			x = 0,
			y = 0,
			width = 102,
			height = 202,
			visible = false
		}
end

local ascii = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"

local chars = {string.byte(ascii, 1, #ascii)}
for i, v in ipairs(chars) do
    chars[i] = string.char(v)
end

lists[1] = list("ascii", chars)

return {
    procs = procs,
    costumes = costumes,
    lists = lists
}
