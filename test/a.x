#include memory

proc del(idx) {
    scratch {
        "deleteLine:ofList:"(idx, "free_blocks")
    }
}

proc refresh main() {
    del(1)
}