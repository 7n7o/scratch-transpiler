local gen = require("scratch.gen")

local function p(name)
    return gen.get_param(name)
end

local function cmd(text, ...)
    return gen.command(text, ...)
end

local get_gen = gen.get_generator

local expr, stat = get_gen("expr"), get_gen("statement")

local function keyify(tbl)
    for i, v in ipairs(tbl) do
        tbl[v] = v
        tbl[i] = nil
    end
    return tbl
end

local mathOps = keyify {
   "abs", "floor", "sqrt", "sin", "cos", "tan", "asin", "acos", "atan", "ln", "log",
   ceiling = "ceil"
}

local mathFuncs = {}

for mOp, fName in pairs(mathOps) do
    local script = gen.proc_script(fName, {"x"}, {
        gen.call("return", cmd("%m.mathOp of %n", mOp, p("x")))
    }, {no_refresh = true})
    table.insert(mathFuncs, script)
end

function merge(...)
    local new = {}
    for _, tbl in ipairs({...}) do
        for _, v in ipairs(tbl) do
            table.insert(new, v)
        end
    end
    
    return new
end

local aux = {
    gen.proc_script("random", {"x", "y"}, {
        gen.call("return", cmd("pick random %n to %n", p("x"), p("y")))
    }, {no_refresh = true}),

    -- pow(x, y) without loops:
    -- x > 0   => e^(y * ln(x))
    -- x == 0  => 0 (except 0^0, handled as 1)
    -- x < 0 and y integer => +/- e^(y * ln(abs(x))) based on parity of y
    -- x < 0 and y non-integer => 0 (no real result in Scratch number model)
    gen.proc_script("pow", {"x", "y"}, {
        {"doIfElse", {"=", p("y"), 0}, {
            gen.call("return", 1)
        }, {
            {"doIfElse", {"=", p("x"), 0}, {
                gen.call("return", 0)
            }, {
                {"doIfElse", {">", p("x"), 0}, {
                    gen.call("return", cmd("%m.mathOp of %n", "e ^", {"*", p("y"), cmd("%m.mathOp of %n", "ln", p("x"))}))
                }, {
                    {"doIfElse", {"=", p("y"), cmd("round %n", p("y"))}, {
                        {"doIfElse", {"=", {"%", p("y"), 2}, 0}, {
                            gen.call("return", cmd("%m.mathOp of %n", "e ^", {"*", p("y"), cmd("%m.mathOp of %n", "ln", cmd("%m.mathOp of %n", "abs", p("x")))}))
                        }, {
                            gen.call("return", {"-", 0, cmd("%m.mathOp of %n", "e ^", {"*", p("y"), cmd("%m.mathOp of %n", "ln", cmd("%m.mathOp of %n", "abs", p("x")))})})
                        }}
                    }, {
                        gen.call("return", 0)
                    }}
                }}
            }}
        }}
    }, {no_refresh = true}),
}



return merge(mathFuncs, aux)
