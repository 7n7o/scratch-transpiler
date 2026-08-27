local parser = require("lib.parser")
local compiler = require("compiler.compiler")

local function compile(source)
    local tree = parser.varinfo(parser.parse(source))
    local scripts = compiler.compile_tree(tree)
    return scripts[#scripts][3]
end

local function assert_equal(actual, expected, message)
    assert(actual == expected, string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

local function expect_error(source, pattern)
    local ok, err = pcall(compile, source)
    assert(not ok, "expected compilation to fail")
    assert(string.find(tostring(err), pattern, 1, true), string.format("expected error containing `%s`, got `%s`", pattern, tostring(err)))
end

local body = compile([=[
proc main() {
    scratch {
        "say:"("hello")
        "setVar:to:"("score", 10)
        "doRepeat"(2) {
            "changeVar:by:"("score", 1)
        }
        "doIf"(1 == 1) {
            "say %s"("friendly")
        } else {
            "say:"("fallback")
        }
    }
}
]=])

assert_equal(body[2][1], "say:", "exact opcode")
assert_equal(body[3][1], "setVar:to:", "second block")
assert_equal(body[4][1], "doRepeat", "repeat opcode")
assert_equal(body[4][3][1][1], "changeVar:by:", "nested body")
assert_equal(body[5][1], "doIfElse", "if with else promotion")
assert_equal(body[5][3][1][1], "say:", "if body")
assert_equal(body[5][4][1][1], "say:", "else body")

local expression_body = compile([=[
proc value() {
    return 7
}

proc main() {
    scratch {
        "say:"(value())
        "setVar:to:"("total", "+"(1, 2))
        "say:"("sum=" .. "+"(3, 4))
    }
}
]=])

assert_equal(expression_body[2][1], "call", "nested procedure call is emitted first")
assert_equal(expression_body[3][1], "say:", "procedure result input block")
assert_equal(expression_body[4][3][1], "+", "nested reporter block")
assert_equal(expression_body[5][2][1], "concatenate:with:", "reporter block in language expression")

local core_body = compile([=[proc main() { scratch { "say:"("readVariable"("score")) } }]=])
assert_equal(core_body[2][2][1], "readVariable", "core reporter opcode")

local value_body = compile([=[
proc main() {
    var a = scratch {
        "getLine:ofList:"(i, "free_blocks")
    }
    print(a)
}
]=])
assert_equal(value_body[2][1], "setVar:to:", "Scratch reporter expression assignment")
assert_equal(value_body[2][3][1], "getLine:ofList:", "Scratch reporter is assigned as the value")
assert_equal(value_body[3][1], "call", "following statement remains after assignment")

local return_body = compile([=[
proc main() {
    return scratch {
        "getLine:ofList:"(1, "free_blocks")
    }
}
]=])
assert_equal(return_body[2][1], "call", "Scratch reporter return")
assert_equal(return_body[2][3][1], "getLine:ofList:", "Scratch reporter is returned as the value")

local empty_body = compile([=[proc main() { scratch { "doRepeat"(1) {} } }]=])
assert_equal(#empty_body[2][3], 0, "empty control body")

expect_error([=[proc main() { scratch { "notAnOpcode"() } }]=], "Unknown Scratch")
expect_error([=[proc main() { scratch { "setVar:to:"("score") } }]=], "expects exactly")
expect_error([=[proc main() { scratch { "say:"("hello") {} } }]=], "only control blocks")
expect_error([=[proc main() { scratch { "doIfElse"(1) { "say:"("one") } } }]=], "requires both")
expect_error([=[proc main() { scratch { "say:" } }]=], "quoted opcode or command followed by arguments")
expect_error([=[proc main() { scratch { "say:"("hello") else {} } }]=], "no `e` block shape")

print("scratch block tests passed")
