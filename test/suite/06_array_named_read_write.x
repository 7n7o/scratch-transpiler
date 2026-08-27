#include std

proc main() {
    var nums = {2, 4, 6, 8}
    var i = 1
    var len = #nums

    while (i < len + 1) {
        nums[i] = nums[i] + 1
        i = i + 1
    }

    print(nums[1])
    print(nums[2])
    print(nums[3])
    print(nums[4])
}
