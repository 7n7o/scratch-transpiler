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
    set_pen_hue(30)
    set_pen_shade(60)

    var yaw_s = sin(angle)
    var yaw_c = cos(angle)
    var pitch_s = sin(angle * 0.7)
    var pitch_c = cos(angle * 0.7)
    var roll_s = sin(angle * 0.3)
    var roll_c = cos(angle * 0.3)

    var i = 1
    while (i < #vx + 1) {
        var x = vx[i]
        var y = vy[i]
        var z = vz[i]

        var rx = x * yaw_c - z * yaw_s
        var rz = x * yaw_s + z * yaw_c

        var ry = y * pitch_c - rz * pitch_s
        var rz2 = y * pitch_s + rz * pitch_c

        var rxx = rx * roll_c - ry * roll_s
        var ryy = rx * roll_s + ry * roll_c

        var depth = rz2 + 220

        if (depth > 8) {
            sv[i] = 1
            sx[i] = rxx * 220 / depth
            sy[i] = ryy * 220 / depth
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

    var major_r = 80
    var minor_r = 30
    var u_count = 18
    var v_count = 12

    var vx = {}
    var vy = {}
    var vz = {}
    var sx = {}
    var sy = {}
    var sv = {}
    var ea = {}
    var eb = {}

    var u = 1
    while (u < u_count + 1) {
        var u_angle = (u - 1) * 360 / u_count
        var u_s = sin(u_angle)
        var u_c = cos(u_angle)

        var v = 1
        while (v < v_count + 1) {
            var v_angle = (v - 1) * 360 / v_count
            var v_c = cos(v_angle)
            var v_s = sin(v_angle)

            var x = (major_r + minor_r * v_c) * u_c
            var y = (major_r + minor_r * v_c) * u_s
            var z = minor_r * v_s

            array_insert(vx, x, array_len(vx) + 1)
            array_insert(vy, y, array_len(vy) + 1)
            array_insert(vz, z, array_len(vz) + 1)
            array_insert(sx, 0, array_len(sx) + 1)
            array_insert(sy, 0, array_len(sy) + 1)
            array_insert(sv, 0, array_len(sv) + 1)

            v = v + 1
        }

        u = u + 1
    }

    var uu = 1
    while (uu < u_count + 1) {
        var vv = 1
        while (vv < v_count + 1) {
            var idx = (uu - 1) * v_count + vv
            var v_next = vv + 1
            if (v_next > v_count) { v_next = 1 }
            var u_next = uu + 1
            if (u_next > u_count) { u_next = 1 }

            var idx_v = (uu - 1) * v_count + v_next
            var idx_u = (u_next - 1) * v_count + vv

            array_insert(ea, idx, array_len(ea) + 1)
            array_insert(eb, idx_v, array_len(eb) + 1)
            array_insert(ea, idx, array_len(ea) + 1)
            array_insert(eb, idx_u, array_len(eb) + 1)

            vv = vv + 1
        }
        uu = uu + 1
    }

    var angle = 0
    while (1 == 1) {
        draw(angle, vx, vy, vz, ea, eb, sx, sy, sv)
        angle = angle + 2
    }
}
