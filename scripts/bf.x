#include std string

proc stk_push(*stk, value) {
    array_insert(stk, value)
}

proc stk_pop(*stk) {
    return array_remove(stk, 1)
}

proc stk_top(*stk) {
    return stk[1]
}

proc gen_tape(*tpe, tpe_sz) {
    var i = 1
    while (i < tpe_sz + 1) {
        array_insert(tpe, 0)
        i = i + 1
    }
}

proc refresh run_bf(code, input) {
    var tpe_sz = 256
    var tpe = {}
    gen_tape(tpe, tpe_sz)

    var ip = 1
    var ptr = 1
    var code_len = strlen(code)
    var in_len = strlen(input)
    var in_ptr = 1
    var loop_stack = {}
    var output = ""

    while (ip < code_len + 1) {
        var inst = index(code,ip)

        if (inst == ">") {
            ptr = ptr + 1
            if (ptr > tpe_sz) {
                ptr = 1
            }
        } else if (inst == "<") {
            ptr = ptr - 1
            if (ptr < 1) {
                ptr = tpe_sz
            }
        } else if (inst == "+") {
            tpe[ptr] = (tpe[ptr] + 1) % 256
        } else if (inst == "-") {
            tpe[ptr] = (tpe[ptr] - 1) % 256
        } else if (inst == ".") {
            output = output .. (to_ascii(tpe[ptr]))
        } else if (inst == ",") {
            if (in_ptr < in_len + 1) {
                tpe[ptr] = from_ascii(index(input, in_ptr))
                in_ptr = in_ptr + 1
            } else {
                tpe[ptr] = 0
            }
        } else if (inst == "[") {
            if (tpe[ptr] == 0) {
                var depth = 1
                while (depth > 0) {
                    ip = ip + 1
                    var nxt = index(code, ip)
                    if (nxt == "[") {
                        depth = depth + 1
                    } else if (nxt == "]") {
                        depth = depth - 1
                    }
                }
            } else {
                stk_push(loop_stack, ip)
            }
        } else if (inst == "]") {
            if (tpe[ptr] == 0) {
                stk_pop(loop_stack)
            } else {
                ip = stk_top(loop_stack)
            }
        }
        ip = ip + 1
    }
    print(output)
}

proc refresh main() {
    var code = ask("Brainfuck code")
    var input = ask("Input stream")
    run_bf(code, input)
}
