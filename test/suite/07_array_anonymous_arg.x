proc sum_first3(*arr) {
    return arr[1] + arr[2] + arr[3]
}

proc main() {
    print(sum_first3({3, 6, 9}))
}
