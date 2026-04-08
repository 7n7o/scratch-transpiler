#include std string math motion pen looks sound

proc draw_line(x1, y1, x2, y2) {
    go_to_xy(x1, y1)
    pen_down()
    go_to_xy(x2, y2)
    pen_up()
}

proc draw_rect(x, y, w, h) {
    draw_line(x, y, x + w, y)
    draw_line(x + w, y, x + w, y + h)
    draw_line(x + w, y + h, x, y + h)
    draw_line(x, y + h, x, y)
}

proc fill_rect(x, y, w, h, step) {
    var yy = y
    while (yy < y + h + 1) {
        draw_line(x, yy, x + w, yy)
        yy = yy + step
    }
}

proc log_event(*events, text) {
    array_insert(events, text)
    if (#events > 15) {
        array_remove(events, 16)
    }
}

proc boot_banner() {
    print("TempleOS Real.x Tribute Build 1.0")
    print("CPU: Scratch Virtual 64-bit Joy Engine")
    print("Video: Pen Renderer + Window Compositor")
    print("Subsystems: TASKS WINDOWS HOME TEXT GODWORDS AUDIO DEMOS")
    print("Type HELP for command list.")
}

proc cmd_help() {
    print("HELP      : this command list")
    print("ABOUT     : system profile")
    print("HOME      : home dashboard")
    print("DESKTOP   : pen-rendered desktop")
    print("WINS      : list windows")
    print("WINNEW    : create window")
    print("WINMOVE   : move window")
    print("WINRESIZE : resize window")
    print("WINFOCUS  : bring window to front")
    print("WINCLOSE  : close window")
    print("TASKS     : task table")
    print("TASKNEW   : create task")
    print("TASKRUN   : set task RUN")
    print("TASKSLEEP : set task SLEEP")
    print("TASKKILL  : set task DEAD")
    print("RENICE    : set task priority")
    print("SCHED     : run scheduler ticks")
    print("DIR       : list files")
    print("TYPE      : view file")
    print("EDIT      : overwrite file")
    print("APPEND    : append to file")
    print("HOMEADD   : add home note")
    print("GODWORDS  : list holy dictionary")
    print("GODWORD   : lookup holy dictionary")
    print("PRAY      : random oracle line")
    print("LOG       : event log")
    print("STARS     : starfield")
    print("CUBE      : wireframe cube")
    print("MUSIC     : hymn")
    print("DEMO      : desktop + stars + cube + music")
    print("REBOOT    : print boot banner")
    print("CLS       : clear pen trails")
    print("HALT      : exit shell")
}

proc cmd_about() {
    print("TempleOS Real.x is a rich TempleOS-style simulation in Scratch Compiler X.")
    print("Features include:")
    print(" - multitask scheduler with process states and priority")
    print(" - window manager with move/resize/focus/close")
    print(" - home dashboard and note feed")
    print(" - text/file workspace in memory")
    print(" - godword oracle dictionary")
    print(" - pen-rendered desktop graphics + demo scenes")
}

proc draw_space_background(points) {
    set_pen_size(2)
    pen_up()

    var i = 1
    while (i < points + 1) {
        set_pen_hue(100 + random(-12, 12))
        set_pen_shade(random(40, 75))
        var x = random(-235, 235)
        var y = random(-175, 175)
        go_to_xy(x, y)
        pen_down()
        go_to_xy(x + random(-1, 1), y + random(-1, 1))
        pen_up()
        i = i + 1
    }
}

proc draw_grid(step) {
    set_pen_size(1)
    set_pen_hue(140)
    set_pen_shade(20)
    pen_up()

    var gx = -230
    while (gx < 231) {
        draw_line(gx, -170, gx, 170)
        gx = gx + step
    }

    var gy = -170
    while (gy < 171) {
        draw_line(-230, gy, 230, gy)
        gy = gy + step
    }
}

proc draw_taskbar() {
    set_pen_size(2)
    set_pen_hue(15)
    set_pen_shade(25)
    fill_rect(-238, -176, 476, 24, 2)
    set_pen_hue(0)
    set_pen_shade(100)
    draw_rect(-238, -176, 476, 24)
}

proc draw_window(x, y, w, h, hue, active) {
    var bar_hue = (hue + 16) % 200
    var border_hue = (hue + 6) % 200
    var body_shade = 30
    var bar_shade = 55

    if (active == 0) {
        body_shade = 20
        bar_shade = 40
    } else {}

    set_pen_size(2)
    set_pen_hue(hue)
    set_pen_shade(body_shade)
    fill_rect(x, y, w, h, 2)

    set_pen_hue(bar_hue)
    set_pen_shade(bar_shade)
    fill_rect(x, y + h - 16, w, 16, 2)

    set_pen_hue(border_hue)
    set_pen_shade(70)
    draw_rect(x, y, w, h)

    set_pen_hue(0)
    set_pen_shade(95)
    draw_rect(x + 4, y + 4, 8, 8)
}

proc render_desktop(*win_title, *win_x, *win_y, *win_w, *win_h, *win_hue, *win_visible) {
    clear_pen_trails()
    pen_up()

    set_pen_size(2)
    set_pen_hue(150)
    set_pen_shade(15)
    fill_rect(-240, -180, 480, 360, 3)

    draw_space_background(120)
    draw_grid(20)

    var i = #win_title
    while (i > 0) {
        if (win_visible[i] == 1) {
            var active = 0
            if (i == 1) {
                active = 1
            }
            draw_window(win_x[i], win_y[i], win_w[i], win_h[i], win_hue[i], active)
        } else {}
        i = i - 1
    }

    draw_taskbar()
}

proc scheduler_tick_once(*task_names, *task_state, *task_tick, *task_priority, *task_cpu, *events) {
    var i = 1
    while (i < #task_names + 1) {
        if (task_state[i] == "DEAD") {
        } else {
            task_tick[i] = task_tick[i] + 1
            var spend = random(0, task_priority[i] + 3)
            task_cpu[i] = (task_cpu[i] + spend) % 1000

            var flip = random(1, 100)
            if (flip < 8 && task_state[i] == "RUN") {
                task_state[i] = "SLEEP"
            } else if (flip > 92 && task_state[i] == "SLEEP") {
                task_state[i] = "RUN"
            } else {}
        }
        i = i + 1
    }
}

proc cmd_sched(*task_names, *task_state, *task_tick, *task_priority, *task_cpu, *events) {
    var cycles = ask("SCHED cycles")
    var i = 1
    while (i < cycles + 1) {
        scheduler_tick_once(task_names, task_state, task_tick, task_priority, task_cpu, events)
        i = i + 1
    }
    log_event(events, join("Scheduler advanced by ", cycles))
    print("SCHED DONE")
}

proc cmd_tasks(*task_names, *task_state, *task_tick, *task_priority, *task_cpu) {
    print("PID  STATE  PRIO  TICK  CPU  NAME")
    var i = 1
    while (i < #task_names + 1) {
        print(join(join(join(join(join(join(join(i, "  "), task_state[i]), "  "), task_priority[i]), "  "), task_tick[i]), join("  ", join(task_cpu[i], join("  ", task_names[i])))))
        i = i + 1
    }
}

proc cmd_task_new(*task_names, *task_state, *task_tick, *task_priority, *task_cpu, *events) {
    var name = ask("TASK name")
    var pos = get_pos_in_list(task_names, name)
    if (pos != 0) {
        print("TASK EXISTS")
        return
    }

    array_insert(task_names, name)
    array_insert(task_state, "RUN")
    array_insert(task_tick, 0)
    array_insert(task_priority, random(1, 10))
    array_insert(task_cpu, 0)
    log_event(events, join("Task created: ", name))
    print("TASK CREATED")
}

proc cmd_task_state(*task_names, *task_state, *events, state_name) {
    var name = ask("TASK name")
    var pos = get_pos_in_list(task_names, name)
    if (pos == 0) {
        print("TASK NOT FOUND")
        return
    }
    task_state[pos] = state_name
    log_event(events, join(join("Task state ", name), join(" -> ", state_name)))
    print("TASK UPDATED")
}

proc cmd_task_kill(*task_names, *task_state, *events) {
    var name = ask("TASK name")
    var pos = get_pos_in_list(task_names, name)
    if (pos == 0) {
        print("TASK NOT FOUND")
        return
    }
    task_state[pos] = "DEAD"
    log_event(events, join("Task killed: ", name))
    print("TASK DEAD")
}

proc cmd_renice(*task_names, *task_priority, *events) {
    var name = ask("TASK name")
    var pos = get_pos_in_list(task_names, name)
    if (pos == 0) {
        print("TASK NOT FOUND")
        return
    }

    var prio = ask("PRIORITY 1-15")
    task_priority[pos] = prio
    log_event(events, join(join("Task priority ", name), join(" -> ", prio)))
    print("PRIORITY UPDATED")
}

proc win_move_to_front(*win_title, *win_x, *win_y, *win_w, *win_h, *win_hue, *win_visible, idx) {
    var a = array_remove(win_title, idx)
    var b = array_remove(win_x, idx)
    var c = array_remove(win_y, idx)
    var d = array_remove(win_w, idx)
    var e = array_remove(win_h, idx)
    var f = array_remove(win_hue, idx)
    var g = array_remove(win_visible, idx)

    array_insert(win_title, a)
    array_insert(win_x, b)
    array_insert(win_y, c)
    array_insert(win_w, d)
    array_insert(win_h, e)
    array_insert(win_hue, f)
    array_insert(win_visible, g)
}

proc cmd_wins(*win_title, *win_x, *win_y, *win_w, *win_h, *win_hue, *win_visible) {
    print("WINDOWS:")
    var i = 1
    while (i < #win_title + 1) {
        print(join(join(join(join(join(join(join(join(win_title[i], "  X="), win_x[i]), " Y="), win_y[i]), " W="), win_w[i]), join(" H=", join(win_h[i], join(" V=", win_visible[i])))))
        i = i + 1
    }
}

proc cmd_win_new(*win_title, *win_x, *win_y, *win_w, *win_h, *win_hue, *win_visible, *events) {
    var title = ask("WIN title")
    var pos = get_pos_in_list(win_title, title)
    if (pos != 0) {
        print("WINDOW EXISTS")
        return
    }

    var x = ask("X")
    var y = ask("Y")
    var w = ask("W")
    var h = ask("H")

    array_insert(win_title, title)
    array_insert(win_x, x)
    array_insert(win_y, y)
    array_insert(win_w, w)
    array_insert(win_h, h)
    array_insert(win_hue, random(0, 190))
    array_insert(win_visible, 1)
    log_event(events, join("Window created: ", title))
    print("WINDOW CREATED")
}

proc cmd_win_move(*win_title, *win_x, *win_y, *events) {
    var title = ask("WIN title")
    var pos = get_pos_in_list(win_title, title)
    if (pos == 0) {
        print("WINDOW NOT FOUND")
        return
    }

    var x = ask("X")
    var y = ask("Y")
    win_x[pos] = x
    win_y[pos] = y
    log_event(events, join("Window moved: ", title))
    print("WINDOW MOVED")
}

proc cmd_win_resize(*win_title, *win_w, *win_h, *events) {
    var title = ask("WIN title")
    var pos = get_pos_in_list(win_title, title)
    if (pos == 0) {
        print("WINDOW NOT FOUND")
        return
    }

    var w = ask("W")
    var h = ask("H")
    win_w[pos] = w
    win_h[pos] = h
    log_event(events, join("Window resized: ", title))
    print("WINDOW RESIZED")
}

proc cmd_win_focus(*win_title, *win_x, *win_y, *win_w, *win_h, *win_hue, *win_visible, *events) {
    var title = ask("WIN title")
    var pos = get_pos_in_list(win_title, title)
    if (pos == 0) {
        print("WINDOW NOT FOUND")
        return
    }

    win_move_to_front(win_title, win_x, win_y, win_w, win_h, win_hue, win_visible, pos)
    log_event(events, join("Window focused: ", title))
    print("WINDOW FOCUSED")
}

proc cmd_win_close(*win_title, *win_x, *win_y, *win_w, *win_h, *win_hue, *win_visible, *events) {
    var title = ask("WIN title")
    var pos = get_pos_in_list(win_title, title)
    if (pos == 0) {
        print("WINDOW NOT FOUND")
        return
    }

    array_remove(win_title, pos)
    array_remove(win_x, pos)
    array_remove(win_y, pos)
    array_remove(win_w, pos)
    array_remove(win_h, pos)
    array_remove(win_hue, pos)
    array_remove(win_visible, pos)
    log_event(events, join("Window closed: ", title))
    print("WINDOW CLOSED")
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

proc cmd_edit(*fs_names, *fs_data, *events) {
    var name = ask("EDIT file")
    var text = ask("TEXT")
    var pos = get_pos_in_list(fs_names, name)
    if (pos == 0) {
        array_insert(fs_names, name)
        array_insert(fs_data, text)
        log_event(events, join("File created: ", name))
        print("FILE CREATED")
    } else {
        fs_data[pos] = text
        log_event(events, join("File updated: ", name))
        print("FILE UPDATED")
    }
}

proc cmd_append(*fs_names, *fs_data, *events) {
    var name = ask("APPEND file")
    var text = ask("TEXT")
    var pos = get_pos_in_list(fs_names, name)
    if (pos == 0) {
        array_insert(fs_names, name)
        array_insert(fs_data, text)
        log_event(events, join("File created by append: ", name))
        print("FILE CREATED")
    } else {
        fs_data[pos] = join(join(fs_data[pos], " | "), text)
        log_event(events, join("File appended: ", name))
        print("FILE APPENDED")
    }
}

proc cmd_home(*home_notes, *task_names, *task_state, *task_cpu, *win_title, *events) {
    print("HOME:")
    print("Welcome, builder.")
    print("SYSTEM HEALTH: ONLINE")
    print(join("TASK COUNT: ", #task_names))
    print(join("WINDOW COUNT: ", #win_title))
    print("TOP TASK SNAPSHOT:")

    var i = 1
    while (i < #task_names + 1 && i < 5) {
        print(join(join(join(task_names[i], " "), task_state[i]), join(" CPU=", task_cpu[i])))
        i = i + 1
    }

    print("NOTES:")
    i = 1
    while (i < #home_notes + 1 && i < 7) {
        print(join("- ", home_notes[i]))
        i = i + 1
    }

    log_event(events, "Opened HOME dashboard")
}

proc cmd_home_add(*home_notes, *events) {
    var note = ask("HOME note")
    array_insert(home_notes, note)
    if (#home_notes > 12) {
        array_remove(home_notes, 13)
    }
    log_event(events, "Home note added")
    print("NOTE ADDED")
}

proc cmd_godwords(*names, *texts) {
    print("GODWORDS:")
    var i = 1
    while (i < #names + 1) {
        print(names[i])
        i = i + 1
    }
}

proc cmd_godword(*names, *texts, *events) {
    var key = ask("GODWORD key")
    var pos = get_pos_in_list(names, key)
    if (pos == 0) {
        print("NO SUCH GODWORD")
        return
    }

    print(join(join(key, ": "), texts[pos]))
    log_event(events, join("Godword read: ", key))
}

proc cmd_pray(*names, *texts, *events) {
    var idx = random(1, #names)
    print(join(join(names[idx], ": "), texts[idx]))
    log_event(events, join("Oracle response: ", names[idx]))
}

proc cmd_log(*events) {
    print("EVENT LOG:")
    var i = 1
    while (i < #events + 1 && i < 12) {
        print(events[i])
        i = i + 1
    }
}

proc cmd_music() {
    set_tempo_bpm(160)
    set_instrument(19)
    play_note_for_beats(67, 0.25)
    play_note_for_beats(71, 0.25)
    play_note_for_beats(74, 0.50)
    play_note_for_beats(79, 0.25)
    play_note_for_beats(74, 0.25)
    play_note_for_beats(71, 0.50)
    play_note_for_beats(67, 0.50)
    play_note_for_beats(69, 0.25)
    play_note_for_beats(72, 0.25)
    play_note_for_beats(76, 0.75)
    print("HYMN COMPLETE")
}

proc cmd_stars(points, frames) {
    var f = 1
    while (f < frames + 1) {
        clear_pen_trails()
        draw_space_background(points)
        sleep(40)
        f = f + 1
    }
    print("STARFIELD COMPLETE")
}

proc cmd_cube(frames) {
    pen_up()

    var vx = {-42, 42, 42, -42, -42, 42, 42, -42}
    var vy = {-42, -42, 42, 42, -42, -42, 42, 42}
    var vz = {-42, -42, -42, -42, 42, 42, 42, 42}

    var ea = {1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4}
    var eb = {2, 3, 4, 1, 6, 7, 8, 5, 5, 6, 7, 8}

    var sx = {0, 0, 0, 0, 0, 0, 0, 0}
    var sy = {0, 0, 0, 0, 0, 0, 0, 0}
    var sv = {0, 0, 0, 0, 0, 0, 0, 0}

    var angle = 0
    var frame = 1
    while (frame < frames + 1) {
        clear_pen_trails()
        set_pen_size(2)
        set_pen_hue((100 + frame) % 200)
        set_pen_shade(48)

        var yaw_s = sin(angle)
        var yaw_c = cos(angle)
        var pitch_s = sin(angle * 0.7)
        var pitch_c = cos(angle * 0.7)
        var roll_s = sin(angle * 0.4)
        var roll_c = cos(angle * 0.4)

        var i = 1
        while (i < #vx + 1) {
            var x = vx[i]
            var y = vy[i]
            var z = vz[i]

            var x1 = x * yaw_c - z * yaw_s
            var z1 = x * yaw_s + z * yaw_c

            var y2 = y * pitch_c - z1 * pitch_s
            var z2 = y * pitch_s + z1 * pitch_c

            var x3 = x1 * roll_c - y2 * roll_s
            var y3 = x1 * roll_s + y2 * roll_c

            var depth = z2 + 220
            if (depth > 16) {
                sv[i] = 1
                sx[i] = x3 * 200 / depth
                sy[i] = y3 * 200 / depth
            } else {
                sv[i] = 0
            }

            i = i + 1
        }

        var e = 1
        while (e < #ea + 1) {
            var a = ea[e]
            var b = eb[e]
            if (sv[a] == 1 && sv[b] == 1) {
                draw_line(sx[a], sy[a], sx[b], sy[b])
            } else {}
            e = e + 1
        }

        angle = angle + 3
        frame = frame + 1
        sleep(30)
    }

    print("CUBE COMPLETE")
}

proc cmd_demo(*win_title, *win_x, *win_y, *win_w, *win_h, *win_hue, *win_visible) {
    render_desktop(win_title, win_x, win_y, win_w, win_h, win_hue, win_visible)
    sleep(200)
    cmd_stars(180, 16)
    cmd_cube(90)
    cmd_music()
}

proc refresh shell(
    *fs_names, *fs_data,
    *task_names, *task_state, *task_tick, *task_priority, *task_cpu,
    *win_title, *win_x, *win_y, *win_w, *win_h, *win_hue, *win_visible,
    *god_names, *god_text,
    *home_notes,
    *events
) {
    var running = 1
    while (running == 1) {
        var cmd = ask("TOS_REAL>")

        if (cmd == "HELP" || cmd == "help") {
            cmd_help()
        } else if (cmd == "ABOUT" || cmd == "about") {
            cmd_about()
        } else if (cmd == "HOME" || cmd == "home") {
            cmd_home(home_notes, task_names, task_state, task_cpu, win_title, events)
        } else if (cmd == "DESKTOP" || cmd == "desktop") {
            render_desktop(win_title, win_x, win_y, win_w, win_h, win_hue, win_visible)
            cmd_wins(win_title, win_x, win_y, win_w, win_h, win_hue, win_visible)
        } else if (cmd == "WINS" || cmd == "wins") {
            cmd_wins(win_title, win_x, win_y, win_w, win_h, win_hue, win_visible)
        } else if (cmd == "WINNEW" || cmd == "winnew") {
            cmd_win_new(win_title, win_x, win_y, win_w, win_h, win_hue, win_visible, events)
        } else if (cmd == "WINMOVE" || cmd == "winmove") {
            cmd_win_move(win_title, win_x, win_y, events)
        } else if (cmd == "WINRESIZE" || cmd == "winresize") {
            cmd_win_resize(win_title, win_w, win_h, events)
        } else if (cmd == "WINFOCUS" || cmd == "winfocus") {
            cmd_win_focus(win_title, win_x, win_y, win_w, win_h, win_hue, win_visible, events)
        } else if (cmd == "WINCLOSE" || cmd == "winclose") {
            cmd_win_close(win_title, win_x, win_y, win_w, win_h, win_hue, win_visible, events)
        } else if (cmd == "TASKS" || cmd == "tasks") {
            cmd_tasks(task_names, task_state, task_tick, task_priority, task_cpu)
        } else if (cmd == "TASKNEW" || cmd == "tasknew") {
            cmd_task_new(task_names, task_state, task_tick, task_priority, task_cpu, events)
        } else if (cmd == "TASKRUN" || cmd == "taskrun") {
            cmd_task_state(task_names, task_state, events, "RUN")
        } else if (cmd == "TASKSLEEP" || cmd == "tasksleep") {
            cmd_task_state(task_names, task_state, events, "SLEEP")
        } else if (cmd == "TASKKILL" || cmd == "taskkill") {
            cmd_task_kill(task_names, task_state, events)
        } else if (cmd == "RENICE" || cmd == "renice") {
            cmd_renice(task_names, task_priority, events)
        } else if (cmd == "SCHED" || cmd == "sched") {
            cmd_sched(task_names, task_state, task_tick, task_priority, task_cpu, events)
        } else if (cmd == "DIR" || cmd == "dir") {
            cmd_dir(fs_names)
        } else if (cmd == "TYPE" || cmd == "type") {
            cmd_type(fs_names, fs_data)
        } else if (cmd == "EDIT" || cmd == "edit") {
            cmd_edit(fs_names, fs_data, events)
        } else if (cmd == "APPEND" || cmd == "append") {
            cmd_append(fs_names, fs_data, events)
        } else if (cmd == "HOMEADD" || cmd == "homeadd") {
            cmd_home_add(home_notes, events)
        } else if (cmd == "GODWORDS" || cmd == "godwords") {
            cmd_godwords(god_names, god_text)
        } else if (cmd == "GODWORD" || cmd == "godword") {
            cmd_godword(god_names, god_text, events)
        } else if (cmd == "PRAY" || cmd == "pray") {
            cmd_pray(god_names, god_text, events)
        } else if (cmd == "LOG" || cmd == "log") {
            cmd_log(events)
        } else if (cmd == "STARS" || cmd == "stars") {
            cmd_stars(180, 18)
        } else if (cmd == "CUBE" || cmd == "cube") {
            cmd_cube(90)
        } else if (cmd == "MUSIC" || cmd == "music") {
            cmd_music()
        } else if (cmd == "DEMO" || cmd == "demo") {
            cmd_demo(win_title, win_x, win_y, win_w, win_h, win_hue, win_visible)
        } else if (cmd == "REBOOT" || cmd == "reboot") {
            boot_banner()
        } else if (cmd == "CLS" || cmd == "cls") {
            clear_pen_trails()
            print("----------------")
        } else if (cmd == "HALT" || cmd == "halt") {
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

    var fs_names = {
        "README.TXT",
        "HOME.TXT",
        "TASKS.TXT",
        "GODWORDS.TXT",
        "HELLO.HC"
    }
    var fs_data = {
        "TempleOS Real.x booted. Type HELP.",
        "HOME powers dashboard, notes, and mission feed.",
        "TASKS has scheduler state, priorities, and cpu counters.",
        "LIGHT,TRUTH,JOY,MERCY,WISDOM,BUILD,CREATE,SING",
        "U0 \"Hello from TempleOS Real.x\";"
    }

    var task_names = {"SHELL", "DRAW", "AUDIO", "TEXT", "IDLE"}
    var task_state = {"RUN", "RUN", "SLEEP", "RUN", "SLEEP"}
    var task_tick = {0, 0, 0, 0, 0}
    var task_priority = {12, 9, 7, 8, 1}
    var task_cpu = {0, 0, 0, 0, 0}

    var win_title = {"HOME", "CONSOLE", "TASKMON", "TEXTPAD"}
    var win_x = {-220, -40, 80, -10}
    var win_y = {-60, -100, -20, 40}
    var win_w = {160, 240, 130, 180}
    var win_h = {130, 120, 100, 110}
    var win_hue = {60, 12, 110, 170}
    var win_visible = {1, 1, 1, 1}

    var god_names = {"LIGHT", "TRUTH", "JOY", "MERCY", "WISDOM", "BUILD", "CREATE", "SING"}
    var god_text = {
        "Let there be light in code and in mind.",
        "Truth is what still stands after debugging.",
        "Joy is shipping useful things with love.",
        "Mercy is patience with beginners and self.",
        "Wisdom is knowing what not to optimize.",
        "Build with boldness and finish what you start.",
        "Create worlds, tools, and songs.",
        "Sing while compiling."
    }

    var home_notes = {
        "Ship one meaningful feature today.",
        "Keep interfaces simple and fast.",
        "Render beauty with deterministic logic.",
        "Pray, code, and test."
    }

    var events = {
        "Booted TempleOS Real.x",
        "Window compositor online",
        "Scheduler online",
        "Godword oracle online"
    }

    boot_banner()
    render_desktop(win_title, win_x, win_y, win_w, win_h, win_hue, win_visible)
    shell(
        fs_names, fs_data,
        task_names, task_state, task_tick, task_priority, task_cpu,
        win_title, win_x, win_y, win_w, win_h, win_hue, win_visible,
        god_names, god_text,
        home_notes,
        events
    )
}
