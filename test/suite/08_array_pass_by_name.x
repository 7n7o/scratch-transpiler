proc build_row(*arr, base) {
    array_insert(arr, base)
    array_insert(arr, base + 1)
    array_insert(arr, base + 2)
}

proc main() {
    var out = {}
    build_row(out, 10)
    build_row(out, 20)

    var i = 1
    var len = #out
    while (i < len + 1) {
        print(out[i])
        i = i + 1
    }
}
