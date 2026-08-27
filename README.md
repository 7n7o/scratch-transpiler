# SCRATCH 2 TRANSPILER
THIS PROJECT IS FOR SCRATCH 2!!!!. THE OUTPUT WILL NOT WORK IN SCRATCH 3

the vast majority of the `compiler/` folder is ai generated, it is based off of `compiler.lua` which was hand written

this project is intended to be ran in luajit
i will not be providing documentation as i have no idea how this thing really works

run `luajit main.lua` for usage
run `luajit compile_libs.lua` to compile libraries found in scratch/lib

this project outputs a sprite that contains the script you transpiled

## Scratch block literals

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
