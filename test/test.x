#include std string

proc refresh main() {
    var t = {1,2,3}
    for i = 1, #t, 1 {
        print(t[i])
    }
    print(format("%s %s %s", t))
}