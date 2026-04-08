proc main() {
    var data = {}
    var i = 1

    while (i < 6) {
        array_insert(data, i * i)
        i = i + 1
    }

    for j = 1, #data, 1 {
        print(join("sq=", data[j]))
    }
}
