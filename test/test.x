#include std3 memory string

proc create_person() {
    return malloc(4)
}

proc set_name(person, name) {
    memset(person, name)
}

proc get_name(person) {
    return memget(person)
}

proc set_age(person, age) {
    memset(person + 1, age)
}

proc get_age(person) {
    return memget(person + 1)
}

proc set_mom(person, mom) {
    memset(person + 2, mom)
} 

proc get_mom(person) {
    return memget(person + 2)
}

proc set_dad(person, dad) {
    memset(person + 3, dad)
}

proc get_dad(person) {
    return memget(person + 3)
}


proc format_person(person) {
    if person == undefined {
        return "undefined"
    }
    var d = get_dad(person)
    var m = get_mom(person)
    var name = join("name=", get_name(person))
    var age =  join(", age=", get_age(person))
    var dad =  ""
    if (d != undefined) {
        dad = join(", dad=", d)
    }
    var mom =  ""
    if (m != "undefined") {
        mom = join(", mom=", m)
    }
    var s = join(join(name, age), mom)
    return join(join("Person { ", join(s, dad)), " }")
}


proc refresh main() {
    var person = create_person()
    set_age(person, 19)
    set_name(person, "person")
    
    var dad = create_person()
    set_age(dad, 48)
    set_name(dad, "dad")

    var mom = create_person()
    set_age(mom, 37)
    set_name(mom, "mom")

    set_dad(person, dad)
    set_mom(person, mom)

    print(format_person(person))
}