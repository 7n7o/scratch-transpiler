proc main() {
    for i = 1, 5, 1 {
        var line = join(i, ":")
        for j = 1, 5, 1 {
            line = join(line, join(" ", i * j))
        }
        print(line)
    }
}
