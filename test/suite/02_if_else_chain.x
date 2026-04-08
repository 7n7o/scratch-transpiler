proc classify(n) {
    if (n < 0) {
        return "neg"
    } else if (n == 0) {
        return "zero"
    } else if (n < 10) {
        return "small"
    } else {
        return "big"
    }
}

proc main() {
    print(classify(-2))
    print(classify(0))
    print(classify(7))
    print(classify(42))
}
