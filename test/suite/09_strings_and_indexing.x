proc main() {
    var words = {"a", "b", "c"}
    var s = ""
    var i = 1

    while (i < #words + 1) {
        s = join(s, words[i])
        i = i + 1
    }

    print(s)
}
