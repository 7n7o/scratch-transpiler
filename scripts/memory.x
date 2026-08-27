#include std string math

list memory
list free_blocks

var undefined
var free_marker

proc allocate_new_block(size) {
    var ptr = #memory - 1
    array_push(memory, size)
    for i = 1, size, 1 {
        array_push(memory, undefined)
    }
    return ptr
}

proc memget(location) {
    return memory[location]
}

proc refresh main() {
    memory = {}
    undefined = "__UD__" .. random(1000, 9999)
    free_marker = "__FM__" .. random(1000, 9999)

    print_global()
}