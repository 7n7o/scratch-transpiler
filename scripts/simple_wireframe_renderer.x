#include std math motion pen looks

proc draw_line(x1, y1, x2, y2) {
    go_to_xy(x1, y1)
    pen_down()
    go_to_xy(x2, y2)
    pen_up()
}

proc draw(angle, *vx, *vy, *vz, *ea, *eb, *sx, *sy, *sv) {
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

proc refresh main() {
    set_rotation_style("left-right")
    show_sprite()
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

    while (1 == 1) {
        draw(angle, vx, vy, vz, ea, eb, sx, sy, sv)
        angle = angle + 2
    }
}
