#include std string math

proc env_set(*names, *values, key, value) {
    var pos = get_pos_in_list(names, key)
    if (pos == 0) {
        array_insert(names, key)
        array_insert(values, value)
    } else {
        values[pos] = value
    }
}

proc env_get(*names, *values, key) {
    var pos = get_pos_in_list(names, key)
    if (pos == 0) {
        return 0
    }
    return values[pos]
}

proc make_inst(op, a, b, c) {
    return {op, a, b, c}
}

proc make_proto(max_stack, *constants, *code) {
    return {max_stack, constants, code}
}

proc reg_get(*regs, idx) {
    return regs[idx + 1]
}

proc reg_set(*regs, idx, value) {
    regs[idx + 1] = value
}

proc native_call(name, *regs, a, b, c) {
    if (name == "print") {
        var argc = b - 1
        var i = 1
        while (i < argc + 1) {
            print(reg_get(regs, a + i))
            i = i + 1
        }
        if (c > 1) {
            reg_set(regs, a, 0)
        }
    } else if (name == "pow") {
        if (c > 1) {
            reg_set(regs, a, pow(reg_get(regs, a + 1), reg_get(regs, a + 2)))
        }
    } else {
        print(join("unknown native: ", name))
    }
}

proc refresh vm_run(*proto) {
    var max_stack = proto[1]
    var *constants = proto[2]
    var *code = proto[3]

    var *regs = {}
    var i = 1
    while (i < max_stack + 1) {
        array_insert(regs, 0)
        i = i + 1
    }

    var env_names = {}
    var env_values = {}
    env_set(env_names, env_values, "print", "print")
    env_set(env_names, env_values, "pow", "pow")

    var pc = 1
    while (pc < #code + 1) {
        
        var *ins = code[pc]
        var op = ins[1]
        var a = ins[2]
        var b = ins[3]
        var c = ins[4]
        var next_pc = pc + 1
        print("OP: "..op.." A: "..a.." B: "..b.." C: "..c)
        if (op == "MOVE") {
            reg_set(regs, a, reg_get(regs, b))
        } else if (op == "LOADK") {
            reg_set(regs, a, constants[b])
        } else if (op == "LOADBOOL") {
            reg_set(regs, a, b)
            if (c != 0) {
                next_pc = next_pc + 1
            }
        } else if (op == "LOADNIL") {
            var r = a
            while (r < b + 1) {
                reg_set(regs, r, 0)
                r = r + 1
            }
        } else if (op == "GETGLOBAL") {
            reg_set(regs, a, env_get(env_names, env_values, constants[b]))
        } else if (op == "SETGLOBAL") {
            env_set(env_names, env_values, constants[b], reg_get(regs, a))
        } else if (op == "ADD") {
            reg_set(regs, a, reg_get(regs, b) + reg_get(regs, c))
        } else if (op == "SUB") {
            reg_set(regs, a, reg_get(regs, b) - reg_get(regs, c))
        } else if (op == "MUL") {
            reg_set(regs, a, reg_get(regs, b) * reg_get(regs, c))
        } else if (op == "DIV") {
            reg_set(regs, a, reg_get(regs, b) / reg_get(regs, c))
        } else if (op == "MOD") {
            reg_set(regs, a, reg_get(regs, b) % reg_get(regs, c))
        } else if (op == "POW") {
            reg_set(regs, a, pow(reg_get(regs, b), reg_get(regs, c)))
        } else if (op == "UNM") {
            reg_set(regs, a, 0 - reg_get(regs, b))
        } else if (op == "LEN") {
            reg_set(regs, a, #reg_get(regs, b))
        } else if (op == "CONCAT") {
            var out = ""
            var ri = b
            while (ri < c + 1) {
                out = join(out, reg_get(regs, ri))
                ri = ri + 1
            }
            reg_set(regs, a, out)
        } else if (op == "JMP") {
            next_pc = pc + a
        } else if (op == "EQ") {
            var cond = 0
            if (reg_get(regs, b) == reg_get(regs, c)) {
                cond = 1
            }
            if (cond != a) {
                next_pc = next_pc + 1
            }
        } else if (op == "LT") {
            var cond = 0
            if (reg_get(regs, b) < reg_get(regs, c)) {
                cond = 1
            }
            if (cond != a) {
                next_pc = next_pc + 1
            }
        } else if (op == "LE") {
            var cond = 0
            var bx = reg_get(regs, b)
            var cx = reg_get(regs, c)

            

            if (bx <= cx) {
                cond = 1
            }

            
            
            if (cond != a) {
                next_pc = next_pc + 1
            }
        } else if (op == "CALL") {
            var fn_name = reg_get(regs, a)
            print(fn_name)
            if (fn_name == "print" || fn_name == "pow") {
                native_call(fn_name, regs, a, b, c)
            } else {
                print("CALL only supports native functions in this non-recursive VM")
                return 0
            }
        } else if (op == "RETURN") {
            if (b == 1) {
                return 0
            }
            if (b == 2) {
                return reg_get(regs, a)
            }
            return 0
        } else {
            print(join("unknown opcode: ", op))
            return 0
        }

        pc = next_pc
    }

    return 0
}

proc demo_iter_product_proto(*proto_out) {
    var constants = {
        "print",
        1,
        5,
        "iter_product(1..5) ="
    }

    var code = {
        {"GETGLOBAL", 0, 1, 0},
        {"LOADK", 1, 2, 0},
        {"LOADK", 2, 3, 0},
        {"LOADK", 3, 2, 0},
        {"LE", 1, 2, 3},
        {"JMP", 4, 0, 0},
        {"MUL", 1, 1, 2},
        {"SUB", 2, 2, 3},
        {"JMP", -4, 0, 0},
        {"MOVE", 5, 1, 0},
        {"LOADK", 1, 4, 0},
        {"MOVE", 2, 5, 0},
        {"CALL", 0, 3, 1},
        {"RETURN", 0, 1, 0}
    }

    proto_out[1] = make_proto(8, constants, code)
}

proc refresh main() {
    var proto_slot = {0}
    demo_iter_product_proto(proto_slot)
    vm_run(proto_slot[1])
}
