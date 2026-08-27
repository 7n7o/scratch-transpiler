#include std math motion pen looks

proc draw_line(x1, y1, x2, y2) {
    go_to_xy(x1, y1)
    pen_down()
    go_to_xy(x2, y2)
    pen_up()
}

proc clamp(x, lo, hi) {
    if (x < lo) { return lo }
    if (x > hi) { return hi }
    return x
}

proc vec3_len(x, y, z) {
    return sqrt(x * x + y * y + z * z)
}

proc vec3_normalize(x, y, z, *out) {
    var len = vec3_len(x, y, z)
    if (len < 0.0001) {
        out[1] = 0
        out[2] = 0
        out[3] = 0
        return 0
    }
    out[1] = x / len
    out[2] = y / len
    out[3] = z / len
    return 0
}

proc shade_from_normal(nx, ny, nz, base_shade, *renderer) {
    var len = vec3_len(nx, ny, nz)
    if (len < 0.0001) { return base_shade }
    var ndot = (nx * renderer[6] + ny * renderer[7] + nz * renderer[8]) / len
    if (ndot < 0) { ndot = 0 }
    var shade = base_shade + ndot * renderer[4]
    return clamp(shade, renderer[2], renderer[3])
}

proc rotate_model(x, y, z, yaw, pitch, roll, *out) {
    var yaw_s = sin(yaw)
    var yaw_c = cos(yaw)
    var pitch_s = sin(pitch)
    var pitch_c = cos(pitch)
    var roll_s = sin(roll)
    var roll_c = cos(roll)

    var x1 = x * yaw_c - z * yaw_s
    var z1 = x * yaw_s + z * yaw_c

    var y2 = y * pitch_c - z1 * pitch_s
    var z2 = y * pitch_s + z1 * pitch_c

    var x3 = x1 * roll_c - y2 * roll_s
    var y3 = x1 * roll_s + y2 * roll_c

    out[1] = x3
    out[2] = y3
    out[3] = z2
}

proc rotate_camera_inv(x, y, z, *cam_cache, *out) {
    var roll_s = cam_cache[5]
    var roll_c = cam_cache[6]
    var pitch_s = cam_cache[3]
    var pitch_c = cam_cache[4]
    var yaw_s = cam_cache[1]
    var yaw_c = cam_cache[2]

    var x1 = x * roll_c - y * roll_s
    var y1 = x * roll_s + y * roll_c
    var z1 = z

    var y2 = y1 * pitch_c - z1 * pitch_s
    var z2 = y1 * pitch_s + z1 * pitch_c

    var x3 = x1 * yaw_c - z2 * yaw_s
    var z3 = x1 * yaw_s + z2 * yaw_c

    out[1] = x3
    out[2] = y2
    out[3] = z3
}

proc camera_setup(*cam, x, y, z, pitch, yaw, roll, fov, near, far, viewport_w, viewport_h) {
    cam[1] = x
    cam[2] = y
    cam[3] = z
    cam[4] = pitch
    cam[5] = yaw
    cam[6] = roll
    cam[7] = near
    cam[8] = far
    cam[9] = fov

    var tan_half = tan(fov / 2)
    if (tan_half < 0.0001) { tan_half = 0.0001 }
    cam[10] = (viewport_w / 2) / tan_half
    cam[11] = (viewport_h / 2) / tan_half
}

proc camera_prepare_cache(*cam, *cache) {
    var yaw = cam[5]
    var pitch = cam[4]
    var roll = cam[6]

    cache[1] = sin(0 - yaw)
    cache[2] = cos(0 - yaw)
    cache[3] = sin(0 - pitch)
    cache[4] = cos(0 - pitch)
    cache[5] = sin(0 - roll)
    cache[6] = cos(0 - roll)
}

proc renderer_setup(*renderer, pen_size, shade_min, shade_max, shade_range, cull_backfaces) {
    renderer[1] = pen_size
    renderer[2] = shade_min
    renderer[3] = shade_max
    renderer[4] = shade_range
    renderer[5] = cull_backfaces
    renderer[6] = 0
    renderer[7] = 0
    renderer[8] = 1
}

proc renderer_set_light(*renderer, lx, ly, lz) {
    var norm = {0, 0, 0}
    vec3_normalize(lx, ly, lz, norm)
    renderer[6] = norm[1]
    renderer[7] = norm[2]
    renderer[8] = norm[3]
}

proc renderer_begin_frame(*renderer) {
    clear_pen_trails()
    set_pen_size(renderer[1])
    pen_up()
}

proc clip_line_near(x1, y1, z1, x2, y2, z2, near, *out) {
    var v1 = 0
    var v2 = 0
    if (z1 > near) { v1 = 1 }
    if (z2 > near) { v2 = 1 }

    if (v1 == 0 && v2 == 0) {
        out[1] = 0
        return 0
    }

    if (v1 == 1 && v2 == 1) {
        out[1] = 1
        out[2] = x1
        out[3] = y1
        out[4] = z1
        out[5] = x2
        out[6] = y2
        out[7] = z2
        return 0
    }

    var t = (near - z1) / (z2 - z1)
    var ix = x1 + (x2 - x1) * t
    var iy = y1 + (y2 - y1) * t
    var iz = near

    out[1] = 1
    if (v1 == 1) {
        out[2] = x1
        out[3] = y1
        out[4] = z1
        out[5] = ix
        out[6] = iy
        out[7] = iz
    } else {
        out[2] = ix
        out[3] = iy
        out[4] = iz
        out[5] = x2
        out[6] = y2
        out[7] = z2
    }
}

proc draw_edge(a, b, *cvx, *cvy, *cvz, *cam, *clip) {
    var x1 = cvx[a]
    var y1 = cvy[a]
    var z1 = cvz[a]
    var x2 = cvx[b]
    var y2 = cvy[b]
    var z2 = cvz[b]

    clip_line_near(x1, y1, z1, x2, y2, z2, cam[7], clip)
    if (clip[1] == 0) { return 0 }

    var sx1 = clip[2] * cam[10] / clip[4]
    var sy1 = clip[3] * cam[11] / clip[4]
    var sx2 = clip[5] * cam[10] / clip[7]
    var sy2 = clip[6] * cam[11] / clip[7]
    draw_line(sx1, sy1, sx2, sy2)
}

proc renderer_transform_mesh(
    *vx, *vy, *vz,
    *cvx, *cvy, *cvz,
    posx, posy, posz,
    rotx, roty, rotz,
    scale,
    *cam, *cam_cache
) {
    var yaw_s = sin(roty)
    var yaw_c = cos(roty)
    var pitch_s = sin(rotx)
    var pitch_c = cos(rotx)
    var roll_s = sin(rotz)
    var roll_c = cos(rotz)

    var cam_out = {0, 0, 0}
    var i = 1
    while (i < #vx + 1) {
        var x = vx[i] * scale
        var y = vy[i] * scale
        var z = vz[i] * scale

        var x1 = x * yaw_c - z * yaw_s
        var z1 = x * yaw_s + z * yaw_c
        var y2 = y * pitch_c - z1 * pitch_s
        var z2 = y * pitch_s + z1 * pitch_c
        var x3 = x1 * roll_c - y2 * roll_s
        var y3 = x1 * roll_s + y2 * roll_c

        var wx = x3 + posx
        var wy = y3 + posy
        var wz = z2 + posz

        var cx = wx - cam[1]
        var cy = wy - cam[2]
        var cz = wz - cam[3]

        rotate_camera_inv(cx, cy, cz, cam_cache, cam_out)
        cvx[i] = cam_out[1]
        cvy[i] = cam_out[2]
        cvz[i] = cam_out[3]

        i = i + 1
    }
}

proc renderer_draw_mesh(
    *vx, *vy, *vz,
    *ta, *tb, *tc,
    *cvx, *cvy, *cvz,
    posx, posy, posz,
    rotx, roty, rotz,
    scale,
    hue, shade,
    *cam, *renderer, *clip, *cam_cache
) {
    renderer_transform_mesh(vx, vy, vz, cvx, cvy, cvz, posx, posy, posz, rotx, roty, rotz, scale, cam, cam_cache)

    var t = 1
    while (t < #ta + 1) {
        var a = ta[t]
        var b = tb[t]
        var c = tc[t]

        var ax = cvx[a]
        var ay = cvy[a]
        var az = cvz[a]
        var bx = cvx[b]
        var by = cvy[b]
        var bz = cvz[b]
        var cx = cvx[c]
        var cy = cvy[c]
        var cz = cvz[c]

        var abx = bx - ax
        var aby = by - ay
        var abz = bz - az
        var acx = cx - ax
        var acy = cy - ay
        var acz = cz - az

        var nx = aby * acz - abz * acy
        var ny = abz * acx - abx * acz
        var nz = abx * acy - aby * acx

        if (renderer[5] == 1 && nz >= 0) {
        } else {
            var face_shade = shade_from_normal(nx, ny, nz, shade, renderer)
            set_pen_hue(hue)
            set_pen_shade(face_shade)
            draw_edge(a, b, cvx, cvy, cvz, cam, clip)
            draw_edge(b, c, cvx, cvy, cvz, cam, clip)
            draw_edge(c, a, cvx, cvy, cvz, cam, clip)
        }

        t = t + 1
    }
}

proc renderer_draw_scene(
    *scene_vx, *scene_vy, *scene_vz,
    *scene_ta, *scene_tb, *scene_tc,
    *scene_cvx, *scene_cvy, *scene_cvz,
    *scene_posx, *scene_posy, *scene_posz,
    *scene_rotx, *scene_roty, *scene_rotz,
    *scene_scale,
    *scene_hue, *scene_shade,
    *cam, *renderer, *clip, *cam_cache
) {
    camera_prepare_cache(cam, cam_cache)

    var i = 1
    while (i < #scene_vx + 1) {
        var *vx = scene_vx[i]
        var *vy = scene_vy[i]
        var *vz = scene_vz[i]
        var *ta = scene_ta[i]
        var *tb = scene_tb[i]
        var *tc = scene_tc[i]
        var *cvx = scene_cvx[i]
        var *cvy = scene_cvy[i]
        var *cvz = scene_cvz[i]

        renderer_draw_mesh(
            vx, vy, vz,
            ta, tb, tc,
            cvx, cvy, cvz,
            scene_posx[i], scene_posy[i], scene_posz[i],
            scene_rotx[i], scene_roty[i], scene_rotz[i],
            scene_scale[i],
            scene_hue[i], scene_shade[i],
            cam, renderer, clip, cam_cache
        )

        i = i + 1
    }
}

proc scene_add_mesh(
    *scene_vx, *scene_vy, *scene_vz,
    *scene_ta, *scene_tb, *scene_tc,
    *scene_cvx, *scene_cvy, *scene_cvz,
    *scene_posx, *scene_posy, *scene_posz,
    *scene_rotx, *scene_roty, *scene_rotz,
    *scene_scale,
    *scene_hue, *scene_shade,
    *scene_spin_x, *scene_spin_y, *scene_spin_z,
    *vx, *vy, *vz,
    *ta, *tb, *tc,
    posx, posy, posz,
    rotx, roty, rotz,
    scale,
    hue, shade,
    spin_x, spin_y, spin_z
) {
    var cvx = {}
    var cvy = {}
    var cvz = {}
    var i = 1
    while (i < #vx + 1) {
        array_insert(cvx, 0, #cvx + 1)
        array_insert(cvy, 0, #cvy + 1)
        array_insert(cvz, 0, #cvz + 1)
        i = i + 1
    }

    array_insert(scene_vx, vx, #scene_vx + 1)
    array_insert(scene_vy, vy, #scene_vy + 1)
    array_insert(scene_vz, vz, #scene_vz + 1)
    array_insert(scene_ta, ta, #scene_ta + 1)
    array_insert(scene_tb, tb, #scene_tb + 1)
    array_insert(scene_tc, tc, #scene_tc + 1)
    array_insert(scene_cvx, cvx, #scene_cvx + 1)
    array_insert(scene_cvy, cvy, #scene_cvy + 1)
    array_insert(scene_cvz, cvz, #scene_cvz + 1)

    array_insert(scene_posx, posx, #scene_posx + 1)
    array_insert(scene_posy, posy, #scene_posy + 1)
    array_insert(scene_posz, posz, #scene_posz + 1)
    array_insert(scene_rotx, rotx, #scene_rotx + 1)
    array_insert(scene_roty, roty, #scene_roty + 1)
    array_insert(scene_rotz, rotz, #scene_rotz + 1)
    array_insert(scene_scale, scale, #scene_scale + 1)
    array_insert(scene_hue, hue, #scene_hue + 1)
    array_insert(scene_shade, shade, #scene_shade + 1)

    array_insert(scene_spin_x, spin_x, #scene_spin_x + 1)
    array_insert(scene_spin_y, spin_y, #scene_spin_y + 1)
    array_insert(scene_spin_z, spin_z, #scene_spin_z + 1)
}

proc scene_update(*scene_rotx, *scene_roty, *scene_rotz, *scene_spin_x, *scene_spin_y, *scene_spin_z) {
    var i = 1
    while (i < #scene_rotx + 1) {
        var rx = scene_rotx[i] + scene_spin_x[i]
        var ry = scene_roty[i] + scene_spin_y[i]
        var rz = scene_rotz[i] + scene_spin_z[i]

        if (rx > 360) { rx = rx - 360 }
        if (ry > 360) { ry = ry - 360 }
        if (rz > 360) { rz = rz - 360 }
        if (rx < -360) { rx = rx + 360 }
        if (ry < -360) { ry = ry + 360 }
        if (rz < -360) { rz = rz + 360 }

        scene_rotx[i] = rx
        scene_roty[i] = ry
        scene_rotz[i] = rz

        i = i + 1
    }
}

proc mesh_make_cuboid(width, height, depth, *vx, *vy, *vz, *ta, *tb, *tc) {
    var hx = width / 2
    var hy = height / 2
    var hz = depth / 2

    var nx = 0 - hx
    var ny = 0 - hy
    var nz = 0 - hz

    array_insert(vx, nx, #vx + 1)
    array_insert(vy, ny, #vy + 1)
    array_insert(vz, nz, #vz + 1)

    array_insert(vx, hx, #vx + 1)
    array_insert(vy, ny, #vy + 1)
    array_insert(vz, nz, #vz + 1)

    array_insert(vx, hx, #vx + 1)
    array_insert(vy, hy, #vy + 1)
    array_insert(vz, nz, #vz + 1)

    array_insert(vx, nx, #vx + 1)
    array_insert(vy, hy, #vy + 1)
    array_insert(vz, nz, #vz + 1)

    array_insert(vx, nx, #vx + 1)
    array_insert(vy, ny, #vy + 1)
    array_insert(vz, hz, #vz + 1)

    array_insert(vx, hx, #vx + 1)
    array_insert(vy, ny, #vy + 1)
    array_insert(vz, hz, #vz + 1)

    array_insert(vx, hx, #vx + 1)
    array_insert(vy, hy, #vy + 1)
    array_insert(vz, hz, #vz + 1)

    array_insert(vx, nx, #vx + 1)
    array_insert(vy, hy, #vy + 1)
    array_insert(vz, hz, #vz + 1)

    var tri = {
        1, 4, 3, 1, 3, 2,
        5, 6, 7, 5, 7, 8,
        1, 5, 8, 1, 8, 4,
        2, 3, 7, 2, 7, 6,
        4, 8, 7, 4, 7, 3,
        1, 2, 6, 1, 6, 5
    }

    var i = 1
    while (i < #tri + 1) {
        array_insert(ta, tri[i], #ta + 1)
        array_insert(tb, tri[i + 1], #tb + 1)
        array_insert(tc, tri[i + 2], #tc + 1)
        i = i + 3
    }
}

proc mesh_make_cube(size, *vx, *vy, *vz, *ta, *tb, *tc) {
    var s = size / 2
    var ns = 0 - s

    array_insert(vx, ns, #vx + 1)
    array_insert(vy, ns, #vy + 1)
    array_insert(vz, ns, #vz + 1)

    array_insert(vx, s, #vx + 1)
    array_insert(vy, ns, #vy + 1)
    array_insert(vz, ns, #vz + 1)

    array_insert(vx, s, #vx + 1)
    array_insert(vy, s, #vy + 1)
    array_insert(vz, ns, #vz + 1)

    array_insert(vx, ns, #vx + 1)
    array_insert(vy, s, #vy + 1)
    array_insert(vz, ns, #vz + 1)

    array_insert(vx, ns, #vx + 1)
    array_insert(vy, ns, #vy + 1)
    array_insert(vz, s, #vz + 1)

    array_insert(vx, s, #vx + 1)
    array_insert(vy, ns, #vy + 1)
    array_insert(vz, s, #vz + 1)

    array_insert(vx, s, #vx + 1)
    array_insert(vy, s, #vy + 1)
    array_insert(vz, s, #vz + 1)

    array_insert(vx, ns, #vx + 1)
    array_insert(vy, s, #vy + 1)
    array_insert(vz, s, #vz + 1)

    var tri = {
        1, 4, 3, 1, 3, 2,
        5, 6, 7, 5, 7, 8,
        1, 5, 8, 1, 8, 4,
        2, 3, 7, 2, 7, 6,
        4, 8, 7, 4, 7, 3,
        1, 2, 6, 1, 6, 5
    }

    var i = 1
    while (i < #tri + 1) {
        array_insert(ta, tri[i], #ta + 1)
        array_insert(tb, tri[i + 1], #tb + 1)
        array_insert(tc, tri[i + 2], #tc + 1)
        i = i + 3
    }
}

proc mesh_make_torus(major_r, minor_r, u_count, v_count, *vx, *vy, *vz, *ta, *tb, *tc) {
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

            array_insert(vx, x, #vx + 1)
            array_insert(vy, y, #vy + 1)
            array_insert(vz, z, #vz + 1)

            v = v + 1
        }

        u = u + 1
    }

    var uu = 1
    while (uu < u_count + 1) {
        var vv = 1
        while (vv < v_count + 1) {
            var u_next = uu + 1
            if (u_next > u_count) { u_next = 1 }
            var v_next = vv + 1
            if (v_next > v_count) { v_next = 1 }

            var idx = (uu - 1) * v_count + vv
            var idx_u = (u_next - 1) * v_count + vv
            var idx_v = (uu - 1) * v_count + v_next
            var idx_uv = (u_next - 1) * v_count + v_next

            array_insert(ta, idx, #ta + 1)
            array_insert(tb, idx_u, #tb + 1)
            array_insert(tc, idx_uv, #tc + 1)

            array_insert(ta, idx, #ta + 1)
            array_insert(tb, idx_uv, #tb + 1)
            array_insert(tc, idx_v, #tc + 1)

            vv = vv + 1
        }
        uu = uu + 1
    }
}

proc refresh main() {
    set_rotation_style("left-right")
    show_sprite()
    pen_up()

    var camera = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    camera_setup(camera, 0, 0, -220, 0, 0, 0, 70, 20, 1200, 480, 360)

    var renderer = {0, 0, 0, 0, 0, 0, 0, 0}
    renderer_setup(renderer, 2, 12, 90, 30, 0)
    renderer_set_light(renderer, 0.3, 0.7, 1)

    var cam_cache = {0, 0, 0, 0, 0, 0}
    var clip = {0, 0, 0, 0, 0, 0, 0}

    var scene_vx = {}
    var scene_vy = {}
    var scene_vz = {}
    var scene_ta = {}
    var scene_tb = {}
    var scene_tc = {}
    var scene_cvx = {}
    var scene_cvy = {}
    var scene_cvz = {}
    var scene_posx = {}
    var scene_posy = {}
    var scene_posz = {}
    var scene_rotx = {}
    var scene_roty = {}
    var scene_rotz = {}
    var scene_scale = {}
    var scene_hue = {}
    var scene_shade = {}
    var scene_spin_x = {}
    var scene_spin_y = {}
    var scene_spin_z = {}

    var cube_vx = {}
    var cube_vy = {}
    var cube_vz = {}
    var cube_ta = {}
    var cube_tb = {}
    var cube_tc = {}
    mesh_make_cube(80, cube_vx, cube_vy, cube_vz, cube_ta, cube_tb, cube_tc)
    scene_add_mesh(
        scene_vx, scene_vy, scene_vz,
        scene_ta, scene_tb, scene_tc,
        scene_cvx, scene_cvy, scene_cvz,
        scene_posx, scene_posy, scene_posz,
        scene_rotx, scene_roty, scene_rotz,
        scene_scale,
        scene_hue, scene_shade,
        scene_spin_x, scene_spin_y, scene_spin_z,
        cube_vx, cube_vy, cube_vz,
        cube_ta, cube_tb, cube_tc,
        -90, -20, 260,
        0, 0, 0,
        1,
        140, 45,
        0.6, 1.1, 0.2
    )

    //     posx, posy, posz,
    // rotx, roty, rotz,
    // scale,
    // hue, shade,
    // spin_x, spin_y, spin_z

    var cam_yaw = 0
    var cam_pitch = 0

    while (1 == 1) {
        renderer_begin_frame(renderer)

        cam_yaw = cam_yaw + 0.2
        if (cam_yaw > 360) { cam_yaw = cam_yaw - 360 }
        cam_pitch = cam_pitch + 0.08
        if (cam_pitch > 360) { cam_pitch = cam_pitch - 360 }
        camera[5] = cam_yaw
        camera[4] = sin(cam_pitch) * 6

        scene_update(scene_rotx, scene_roty, scene_rotz, scene_spin_x, scene_spin_y, scene_spin_z)
        renderer_draw_scene(
            scene_vx, scene_vy, scene_vz,
            scene_ta, scene_tb, scene_tc,
            scene_cvx, scene_cvy, scene_cvz,
            scene_posx, scene_posy, scene_posz,
            scene_rotx, scene_roty, scene_rotz,
            scene_scale,
            scene_hue, scene_shade,
            camera, renderer, clip, cam_cache
        )
    }
}
