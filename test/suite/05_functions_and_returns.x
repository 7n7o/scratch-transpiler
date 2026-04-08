proc square(n) {
    return n * n
}

proc add3(a, b, c) {
    return a + b + c
}

proc main() {
    var x = square(7)
    var y = add3(x, square(2), 5)
    print(join("result=", y))
}
