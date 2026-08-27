# SCRATCH 2 TRANSPILER
THIS PROJECT IS FOR SCRATCH 2!!!!. THE OUTPUT WILL NOT WORK IN SCRATCH 3

the vast majority of the `compiler/` folder is ai generated, it is based off of `compiler.lua` which was hand written

this project is intended to be ran in luajit
i will not be providing documentation as i have no idea how this thing really works

run `luajit main.lua` for usage
run `luajit compile_libs.lua` to compile libraries found in scratch/lib

this project outputs a sprite that contains the script you transpiled

## Scratch block literals

Use `scratch { ... }` inside a procedure to write Scratch 2 blocks directly.
Each entry is a quoted Scratch opcode or a friendly command string from
`scratch/spec.lua`, followed by parenthesized inputs. A control block may have
an embedded block sequence, and `else` is supported for conditional stacks:

```text
proc main() {
    scratch {
        "setVar:to:"("score", 10)
        "doIf"(score > 0) {
            "say:"("ready")
        } else {
            "say %s"("not ready")
        }
    }
}
```

Exact opcodes such as `"say:"` and friendly spec entries such as
`"say %s"` are both valid. Inputs are normal language expressions, so
procedure calls and expressions can be used directly. Quoted strings passed
to menu inputs are emitted literally; identifiers are compiled as language
expressions. Unknown opcodes and malformed control stacks fail at compile
time.

The focused regression test can be run with `luajit test/scratch_blocks.lua`.
