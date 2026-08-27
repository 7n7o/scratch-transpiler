#include std memory

proc main() {
    var memA = malloc(20)
    memset(memA, 1)

    var memB = malloc(16)
    memset(memB, 1)

    free(memA)
    
    memA = malloc(10)
    memset(memA, 1)
}