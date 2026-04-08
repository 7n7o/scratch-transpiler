proc main() {
    var left = {1, 2}
    var right = {3, 4}
    var merged = {}

    array_insert(merged, left[1])
    array_insert(merged, left[2])
    array_insert(merged, right[1])
    array_insert(merged, right[2])

    print(join("len=", #merged))
    print(merged[1])
    print(merged[4])
}
