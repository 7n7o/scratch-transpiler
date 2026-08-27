#include std string math motion pen looks sound

proc draw_line(x1, y1, x2, y2) {
    go_to_xy(x1, y1)
    pen_down()
    go_to_xy(x2, y2)
    pen_up()
}

proc boot_banner() {
    print("TempleOS V5.03 (Tribute Build)")
    print("CPU: Scratch Virtual 16 Color")
    print("RAM: enough for joy")
    print("God said: code and create.")
    print("Commands: HELP ABOUT DIR TYPE EDIT STARS CUBE MUSIC RAND DEMO REBOOT HALT")
}

proc cmd_help() {
    print("HELP   : command list")
    print("ABOUT  : system note")
    print("DIR    : list files")
    print("TYPE   : show file")
    print("EDIT   : write file")
    print("STARS  : starfield demo")
    print("CUBE   : wireframe demo")
    print("MUSIC  : hymn fragment")
    print("RAND   : random stream")
    print("DEMO   : stars + cube + music")
    print("REBOOT : print boot banner")
    print("HALT   : stop shell")
}

proc cmd_about() {
    print("This is a TempleOS-style shell built in the scratch compiler language.")
    print("It keeps the spirit: immediate commands, art demos, and playful computing.")
    print("The full TempleOS kernel and HolyC compiler are outside this VM scope.")
    print("Use DEMO for the full tribute sequence.")
}

proc cmd_dir(*fs_names) {
    print("C:/")
    var i = 1
    while (i < #fs_names + 1) {
        print(fs_names[i])
        i = i + 1
    }
}

proc cmd_type(*fs_names, *fs_data) {
    var name = ask("TYPE file")
    var pos = get_pos_in_list(fs_names, name)
    if (pos == 0) {
        print("FILE NOT FOUND")
    } else {
        print(name)
        print(fs_data[pos])
    }
}

proc cmd_edit(*fs_names, *fs_data) {
    var name = ask("EDIT file")
    var text = ask("TEXT")
    var pos = get_pos_in_list(fs_names, name)
    if (pos == 0) {
        array_insert(fs_names, name)
        array_insert(fs_data, text)
        print("FILE CREATED")
    } else {
        fs_data[pos] = text
        print("FILE UPDATED")
    }
}

proc cmd_rand() {
    var i = 1
    while (i < 8 + 1) {
        print(random(0, 65535))
        i = i + 1
    }
}

proc cmd_music() {
    set_tempo_bpm(164)
    set_instrument(3)
    play_note_for_beats(67, 0.25)
    play_note_for_beats(71, 0.25)
    play_note_for_beats(74, 0.50)
    play_note_for_beats(79, 0.25)
    play_note_for_beats(74, 0.25)
    play_note_for_beats(71, 0.50)
    play_note_for_beats(67, 0.50)
    print("HYMN DONE")
}

proc refresh cmd_stars(points) {
    clear_pen_trails()
    set_pen_size(2)
    pen_up()

    var i = 1
    while (i < points + 1) {
        var x = random(-220, 220)
        var y = random(-160, 160)
        var hue = random(20, 90)
        set_pen_hue(hue)
        set_pen_shade(50)
        go_to_xy(x, y)
        pen_down()
        go_to_xy(x + random(-2, 2), y + random(-2, 2))
        pen_up()
        i = i + 1
    }

    print("STARS RENDERED")
}

proc draw_cube(angle, *vx, *vy, *vz, *ea, *eb, *sx, *sy, *sv) {
    clear_pen_trails()
    set_pen_size(2)
    set_pen_hue(110)
    set_pen_shade(45)

    var yaw_s = sin(angle)
    var yaw_c = cos(angle)
    var pitch_s = sin(angle * 0.7)
    var pitch_c = cos(angle * 0.7)

    var i = 1
    while (i < #vx + 1) {
        var x = vx[i]
        var y = vy[i]
        var z = vz[i]

        var rx = x * yaw_c - z * yaw_s
        var rz = x * yaw_s + z * yaw_c

        var ry = y * pitch_c - rz * pitch_s
        var rz2 = y * pitch_s + rz * pitch_c

        var depth = rz2 + 180

        if (depth > 8) {
            sv[i] = 1
            sx[i] = rx * 180 / depth
            sy[i] = ry * 180 / depth
        } else {
            sv[i] = 0
        }

        i = i + 1
    }

    var e = 1
    while (e < #ea + 1) {
        var a = ea[e]
        var b = eb[e]

        if (sv[a] == 1) {
            if (sv[b] == 1) {
                draw_line(sx[a], sy[a], sx[b], sy[b])
            }
        }

        e = e + 1
    }

    
}


proc refresh cmd_cube(frames) {
    pen_up()

    var vx = {-35, 35, 35, -35, -35, 35, 35, -35}
    var vy = {-35, -35, 35, 35, -35, -35, 35, 35}
    var vz = {-35, -35, -35, -35, 35, 35, 35, 35}

    var ea = {1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4}
    var eb = {2, 3, 4, 1, 6, 7, 8, 5, 5, 6, 7, 8}

    var sx = {0, 0, 0, 0, 0, 0, 0, 0}
    var sy = {0, 0, 0, 0, 0, 0, 0, 0}
    var sv = {0, 0, 0, 0, 0, 0, 0, 0}

    var angle = 0
    var frame = 1
    while (frame < frames + 1) {
        draw_cube(angle, vx, vy, vz, ea, eb, sx, sy, sv)
        angle = angle + 3
        frame = frame + 1
    }

    print("CUBE COMPLETE")
}

proc refresh cmd_demo() {
    cmd_stars(140)
    cmd_cube(80)
    cmd_music()
}

proc refresh shell(*fs_names, *fs_data) {
    var running = 1
    while (running == 1) {
        var cmd = ask("TOS>")

        if (cmd == "help" || cmd == "HELP") {
            cmd_help()
        } else if (cmd == "about" || cmd == "ABOUT") {
            cmd_about()
        } else if (cmd == "dir" || cmd == "DIR") {
            cmd_dir(fs_names)
        } else if (cmd == "type" || cmd == "TYPE") {
            cmd_type(fs_names, fs_data)
        } else if (cmd == "edit" || cmd == "EDIT") {
            cmd_edit(fs_names, fs_data)
        } else if (cmd == "stars" || cmd == "STARS") {
            cmd_stars(140)
        } else if (cmd == "cube" || cmd == "CUBE") {
            cmd_cube(80)
        } else if (cmd == "music" || cmd == "MUSIC") {
            cmd_music()
        } else if (cmd == "rand" || cmd == "RAND") {
            cmd_rand()
        } else if (cmd == "demo" || cmd == "DEMO") {
            cmd_demo()
        } else if (cmd == "reboot" || cmd == "REBOOT") {
            boot_banner()
        } else if (cmd == "cls" || cmd == "CLS") {
            clear_pen_trails()
            print("----------------")
        } else if (cmd == "halt" || cmd == "HALT") {
            running = 0
        } else {
            print("UNKNOWN COMMAND")
        }
    }

    print("SYSTEM HALTED")
}

proc refresh main() {
    set_rotation_style("left-right")
    show_sprite()
    pen_up()

    var fs_names = {"README.TXT", "PSALM.TXT", "HELLO.HC"}
    var fs_data = {
        "TempleOS tribute shell running in Scratch.",
        "Sing for God. Build with joy.",
        "U0 \"Hello, TempleOS Spirit!\";"
    }

    boot_banner()
    shell(fs_names, fs_data)
}
