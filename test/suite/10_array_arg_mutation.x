proc bump(*arr, i) {
    arr[i] = arr[i] + 1
}

proc main() {
    var xs = {0, 0, 0}
    bump(xs, 1)
    bump(xs, 2)
    bump(xs, 2)
    bump(xs, 3)

    print(xs[1])
    print(xs[2])
    print(xs[3])
}
