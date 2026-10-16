"""Wear scanner and plasma cutter models (hands-on pass; see hw_kit.py and the multimeter script).

Run headless from the repo root (writes tools/hw_scanner.glb and tools/hw_cutter.glb):
    blender --background --factory-startup --python art/blender/build_hands_on_scanner_cutter.py
Append `-- scanner` or `-- cutter` to build only one. Set HW_MODELS_DIR to redirect output.

Both tools keep the footprint of the models they replace (hw_kit.REFERENCE_BOUNDS; working end
toward Blender +Y, exactly as before) and ship one action each (`use_scanner`, `use_cutter`;
24 frames at 24 fps) that Carriable.play_use_animation() plays once when the sim says the tool
did its job.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import hw_kit as kit  # noqa: E402
from mathutils import Vector  # noqa: E402


# -- local helpers (hw_kit is shared and not edited from here) -----------------------------------
def tube(b: kit.Builder, r_out, r_in, length, center, mat, axis="y", sides=12, part="") -> None:
    """Hollow faceted ring along `axis`: a collar you can see into."""
    bm = bmesh.new()
    h = length / 2

    def ring(r, z):
        return [bm.verts.new((math.cos(2 * math.pi * i / sides) * r, math.sin(2 * math.pi * i / sides) * r, z)) for i in range(sides)]

    ob, ib, ot, it = ring(r_out, -h), ring(r_in, -h), ring(r_out, h), ring(r_in, h)
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new([ob[i], ob[j], ot[j], ot[i]])
        bm.faces.new([ib[j], ib[i], it[i], it[j]])
        bm.faces.new([ot[i], ot[j], it[j], it[i]])
        bm.faces.new([ob[j], ob[i], ib[i], ib[j]])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    b.add_mesh(bm, part, mat, kit.AXIS_TILT[axis], center)


def seg(b: kit.Builder, p0, p1, r0, r1, mat, sides=8, part="", bevel=0.0) -> None:
    """Faceted frustum from p0 (radius r0) to p1 (radius r1) along any direction."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=sides, radius1=r0, radius2=r1, depth=d.length)
    b.chamfer(bm, min(bevel, min(r0, r1) * 0.45, d.length * 0.45))
    turn = Vector((0.0, 0.0, 1.0)).rotation_difference(d).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=turn, verts=bm.verts)
    b.add_mesh(bm, part, mat, None, (p0 + p1) / 2)


def hose(b: kit.Builder, points, radius, mat, sides=8) -> None:
    """Rubber run through `points`, with a joint block at each bend so corners stay closed."""
    pts = [Vector(p) for p in points]
    for a, c in zip(pts, pts[1:]):
        seg(b, a, c, radius, radius, mat, sides=sides)
    for i in range(1, len(pts) - 1):
        bis = ((pts[i] - pts[i - 1]).normalized() + (pts[i + 1] - pts[i]).normalized()).normalized()
        seg(b, pts[i] - bis * radius * 0.9, pts[i] + bis * radius * 0.9, radius * 1.02, radius * 1.02, mat, sides=sides)


def ring_points(cx, cz, radius, count, phase=0.0):
    """Points on a circle in the x/z plane (for fasteners around a round part)."""
    return [(cx + math.sin(math.radians(phase + 360.0 * i / count)) * radius,
             cz + math.cos(math.radians(phase + 360.0 * i / count)) * radius) for i in range(count)]


# -- scanner -----------------------------------------------------------------------------------
def build_scanner() -> bpy.types.Object:
    b = kit.Builder("hw_scanner")
    cx, cz = -0.0018, 0.095         # lens axis
    lens_y = 0.1131
    b.pivot("emitter", (cx, lens_y, cz))

    # Two-piece shell with a dark seam; the upper half is slightly wedge-shaped.
    bx, w, y0, y1 = -0.0003, 0.0726, -0.0606, 0.1006
    length, yc = y1 - y0, (y0 + y1) / 2
    b.box((w, length, 0.0385), (bx, yc, 0.07925), "hw_teal", bevel=0.003)
    b.box((w, length, 0.0285), (bx, yc, 0.11575), "hw_teal", bevel=0.0025, taper=(0.95, 0.975))
    b.box((w - 0.003, length - 0.003, 0.0040), (bx, yc, 0.1000), "hw_dark")
    for sx in (-1, 1):  # rubber feet under the front of the shell
        b.box((0.014, 0.022, 0.0030), (sx * 0.022, 0.082, 0.0585), "hw_rubber")

    # Display: sunken glass in a raised bezel frame, with a bar graph, reticle and status marks.
    sx0, sy0 = -0.0004, 0.035
    b.box((0.0610, 0.0620, 0.0060), (sx0, sy0, 0.1320), "hw_dark", bevel=0.0018)
    b.box((0.0025, 0.0620, 0.0030), (sx0 - 0.02925, sy0, 0.1365), "hw_dark")
    b.box((0.0025, 0.0620, 0.0030), (sx0 + 0.02925, sy0, 0.1365), "hw_dark")
    b.box((0.0560, 0.0055, 0.0030), (sx0, sy0 - 0.02825, 0.1365), "hw_dark")
    b.box((0.0560, 0.0055, 0.0030), (sx0, sy0 + 0.02825, 0.1365), "hw_dark")
    b.box((0.0560, 0.0510, 0.0014), (sx0, sy0, 0.1357), "hw_phosphor_green", part="screen")
    zl = 0.1369
    for i, h in enumerate((0.008, 0.013, 0.010, 0.018, 0.022, 0.015)):
        b.box((0.0038, h, 0.0006), (-0.0250 + i * 0.0060, 0.0140 + h / 2, zl), "hw_dark", part="graph")
    b.box((0.0330, 0.0009, 0.0006), (-0.0105, 0.0133, zl), "hw_dark", part="graph")
    for i in range(2):
        b.box((0.0030, 0.0030, 0.0006), (-0.0250 + i * 0.0060, 0.0548, zl), "hw_dark", part="graph")
    b.box((0.0090, 0.0036, 0.0006), (0.0150, 0.0548, zl), "hw_dark", part="graph")      # battery icon
    b.box((0.0016, 0.0016, 0.0006), (0.0200, 0.0548, zl), "hw_dark", part="graph")
    tube(b, 0.0090, 0.0074, 0.0006, (0.0160, 0.0290, zl), "hw_dark", axis="z", sides=10, part="graph")
    b.box((0.0200, 0.0008, 0.0006), (0.0160, 0.0290, zl), "hw_dark", part="graph")
    b.box((0.0008, 0.0200, 0.0006), (0.0160, 0.0290, zl), "hw_dark", part="graph")
    b.box((0.0035, 0.0035, 0.0008), (0.0230, 0.0148, zl), "hw_phosphor_amber", part="pip")

    # Top controls behind the display, hazard zone in front of it, corner screws.
    b.cyl(0.0072, 0.0012, (-0.0170, -0.0350, 0.1306), "hw_metal", sides=10)
    b.cyl(0.0055, 0.0030, (-0.0170, -0.0350, 0.1320), "hw_rubber", sides=10)
    b.box((0.0160, 0.0120, 0.0008), (0.0, -0.0350, 0.1304), "hw_dark")
    b.box((0.0130, 0.0090, 0.0030), (0.0, -0.0350, 0.1318), "hw_steel")
    b.cyl(0.0050, 0.0010, (0.0170, -0.0350, 0.1305), "hw_dark", sides=8)
    b.cyl(0.0032, 0.0022, (0.0170, -0.0350, 0.1316), "hw_hazard_red", sides=8, part="led")
    for x in (-0.0170, 0.0, 0.0170):
        b.box((0.0070, 0.0016, 0.0006), (x, -0.0470, 0.1303), "hw_beige")
    b.box((0.0500, 0.0260, 0.0010), (sx0, 0.0820, 0.1305), "hw_dark")
    for i in range(5):
        b.box((0.0052, 0.0200, 0.0008), (-0.0180 + i * 0.0090, 0.0820, 0.1313), "hw_hazard_amber", rot=(0, 0, 38))
    for x in (-0.0300, 0.0300):
        for y in (-0.0525, 0.0925):
            b.bolt((x, y, 0.1300), "hw_metal", axis="z", radius=0.0022)

    # Sides: sensor vents on the left, a label plate on the right.
    for i in range(5):
        b.box((0.0012, 0.0035, 0.0160), (-0.0362, 0.0360 + i * 0.0090, 0.0795), "hw_dark")
    b.box((0.0010, 0.0400, 0.0150), (0.0359, 0.0500, 0.0815), "hw_beige")
    for z, ln in ((0.0860, 0.030), (0.0815, 0.022), (0.0770, 0.026)):
        b.box((0.0006, ln, 0.0018), (0.03645, 0.0500 - (0.030 - ln) / 2, z), "hw_dark")

    # Nose block, lens collar with bolts, recessed floor, and the pulsing emitter.
    b.box((0.0603, 0.0210, 0.0600), (-0.00155, 0.0960, 0.0950), "hw_dark", bevel=0.008)
    tube(b, 0.0285, 0.0225, 0.0130, (cx, 0.1130, cz), "hw_metal", sides=12)
    b.cyl(0.0226, 0.0010, (cx, 0.1075, cz), "hw_dark", axis="y", sides=12)
    for px, pz in ring_points(cx, cz, 0.0257, 6, 30):
        b.bolt((px, 0.1195, pz), "hw_steel", axis="y", radius=0.0015, height=0.0012)
    seg(b, (cx, 0.1060, cz), (cx, 0.1195, cz), 0.0190, 0.0170, "hw_phosphor_green", sides=12, part="emitter")
    seg(b, (cx, 0.1195, cz), (cx, 0.1231, cz), 0.0128, 0.0110, "hw_phosphor_green", sides=12, part="emitter")
    b.cyl(0.0165, 0.0008, (cx, 0.1199, cz), "hw_dark", axis="y", sides=12, part="emitter")
    b.cyl(0.0045, 0.0004, (cx, 0.12315, cz), "hw_dark", axis="y", sides=8, part="emitter")

    # Raked grip: dark core, rubber finger ribs and palm strips, pommel, trigger and guard.
    b.prism([(-0.0829, 0.0), (-0.0500, 0.0), (-0.0271, 0.0680), (-0.0560, 0.0680)], 0.0444, (0, 0, 0), "hw_dark", plane="yz", bevel=0.003)
    b.box((0.0470, 0.0360, 0.0075), (0.0, -0.06645, 0.00375), "hw_rubber", bevel=0.0022)
    tilt = math.degrees(math.atan2(0.0229, 0.068))
    for z in (0.012, 0.026, 0.040, 0.054):
        fy = -0.0500 + 0.0229 * z / 0.068
        n = (0.0, math.cos(math.radians(tilt)), -math.sin(math.radians(tilt)))
        b.box((0.0400, 0.0036, 0.0070), (0.0, fy + n[1] * 0.0010, z + n[2] * 0.0010), "hw_rubber", rot=(-tilt, 0, 0))
    tilt_b = math.degrees(math.atan2(0.0269, 0.068))
    by = -0.0829 + 0.0269 * 0.034 / 0.068
    for i in range(4):
        b.box((0.0050, 0.0030, 0.0500), (-0.0105 + i * 0.0070, by - 0.0008, 0.034 + 0.0003), "hw_rubber", rot=(-tilt_b, 0, 0))
    for sx in (-1, 1):  # trigger guard loops
        b.box((0.0030, 0.0415, 0.0040), (sx * 0.0075, -0.0185, 0.0345), "hw_dark")
        b.box((0.0030, 0.0050, 0.0290), (sx * 0.0075, 0.0020, 0.0472), "hw_dark")
    b.box((0.0070, 0.0055, 0.0260), (0.0, -0.0160, 0.0470), "hw_steel", bevel=0.0008, rot=(12, 0, 0))

    # Ribbed battery pack on the back, hinged rubber antenna, strap lug.
    b.box((0.0400, 0.0170, 0.0500), (bx, -0.0685, 0.0970), "hw_dark", bevel=0.0018)
    for i in range(5):
        b.box((0.0340, 0.0020, 0.0040), (bx, -0.0780, 0.0800 + i * 0.0085), "hw_rubber")
    b.box((0.0200, 0.0012, 0.0030), (bx, -0.0772, 0.1190), "hw_hazard_amber")
    b.box((0.0160, 0.0030, 0.0060), (bx, -0.0780, 0.0745), "hw_steel")
    ax, az = 0.0290, 0.1150
    b.box((0.0140, 0.0050, 0.0140), (ax, -0.0632, az), "hw_steel", bevel=0.0012)
    b.cyl(0.0050, 0.0130, (ax, -0.0690, az), "hw_steel", sides=8)
    b.bolt((ax, -0.0690, az + 0.0065), "hw_dark", axis="z", radius=0.0022, height=0.0010)
    seg(b, (ax, -0.0690, az), (ax, -0.0866, az), 0.0044, 0.0030, "hw_rubber", sides=8)
    seg(b, (ax, -0.0866, az), (ax, -0.0896, az), 0.0030, 0.0014, "hw_rubber", sides=8)
    for y in (-0.0740, -0.0795):
        b.cyl(0.0050, 0.0012, (ax, y, az), "hw_rubber", axis="y", sides=8)
    for x in (-0.0335, -0.0245):
        b.box((0.0030, 0.0120, 0.0040), (x, -0.0660, 0.1130), "hw_steel")
    b.box((0.0120, 0.0030, 0.0040), (-0.0290, -0.0720, 0.1130), "hw_steel")
    b.box((0.0160, 0.0030, 0.0100), (-0.0290, -0.0620, 0.1130), "hw_steel")

    root = b.build()
    kit.animate(root, "use_scanner", [
        (0, {"location": (0, 0, 0), "rotation": (0, 0, 0)}),
        (6, {"location": (0, -0.003, 0), "rotation": (-4, 0, 1.5)}),
        (24, {"location": (0, 0, 0), "rotation": (0, 0, 0)}),
    ])
    kit.animate(b.holders["emitter"], "use_scanner", [
        (0, {"scale": (1, 1, 1)}), (10, {"scale": (1.4, 1.4, 1.4)}), (24, {"scale": (1, 1, 1)}),
    ])
    kit.check_bounds(root, *kit.REFERENCE_BOUNDS["hw_scanner"])
    return root


# -- cutter ------------------------------------------------------------------------------------
def build_cutter() -> bpy.types.Object:
    b = kit.Builder("hw_cutter")
    ny = 0.100                      # z of the nozzle axis
    tank_z = 0.160
    b.pivot("emitter", (0.0, 0.1945, ny))
    b.pivot("lamp", (0.0300, -0.0500, 0.1210))

    # Two-piece amber shell with a dark seam, front plate, rubber feet.
    y0, y1 = -0.0591, 0.1009
    length, yc = y1 - y0, (y0 + y1) / 2
    b.box((0.0600, length, 0.0385), (0.0, yc, 0.07925), "hw_hazard_amber", bevel=0.0035)
    b.box((0.0600, length, 0.0385), (0.0, yc, 0.12075), "hw_hazard_amber", bevel=0.0035)
    b.box((0.0570, length - 0.003, 0.0040), (0.0, yc, 0.1000), "hw_dark")
    for sx in (-1, 1):
        b.box((0.016, 0.022, 0.0030), (sx * 0.020, 0.080, 0.0585), "hw_rubber")
    b.box((0.0540, 0.0020, 0.0540), (0.0, 0.1019, ny), "hw_metal")
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.bolt((sx * 0.0215, 0.1029, ny + sz * 0.0215), "hw_steel", axis="y", radius=0.0022, height=0.0014)
            b.bolt((sx * 0.0215, y0, 0.1000 + sz * 0.0285), "hw_steel", axis="-y", radius=0.0022, height=0.0014)

    # Rear strain relief and cable stub.
    seg(b, (0.0, y0, 0.0850), (0.0, -0.0651, 0.0850), 0.0090, 0.0060, "hw_rubber", sides=8)
    seg(b, (0.0, -0.0651, 0.0850), (0.0, -0.0681, 0.0850), 0.0040, 0.0040, "hw_rubber", sides=6)

    # Side detail: vents both sides, safety slider and label plate on the left, status lamp on the right.
    for sx in (-1, 1):
        for i in range(5):
            b.box((0.0012, 0.0035, 0.0170), (sx * 0.0297, 0.0150 + i * 0.0110, 0.0795), "hw_dark")
    b.box((0.0014, 0.0075, 0.0220), (-0.0297, -0.0330, 0.0820), "hw_dark")
    b.box((0.0034, 0.0065, 0.0060), (-0.0293, -0.0330, 0.0885), "hw_steel")
    for dz in (0.0, 0.0030):
        b.box((0.0006, 0.0070, 0.0010), (-0.0299, -0.0330, 0.0925 + dz), "hw_beige")
    b.box((0.0010, 0.0500, 0.0140), (-0.0297, 0.0270, 0.1190), "hw_beige")
    for z, ln in ((0.1230, 0.036), (0.1190, 0.028), (0.1150, 0.032)):
        b.box((0.0006, ln, 0.0018), (-0.0302, 0.0270 - (0.036 - ln) / 2, z), "hw_dark")
    tube(b, 0.0075, 0.0052, 0.0022, (0.0301, -0.0500, 0.1210), "hw_dark", axis="x", sides=8)
    seg(b, (0.0290, -0.0500, 0.1210), (0.0313, -0.0500, 0.1210), 0.0052, 0.0042, "hw_phosphor_green", sides=8, part="lamp")

    # Hazard stripe band: dark slashes between two dark rails, both sides of the shell.
    for sx in (-1, 1):
        for z in (0.1095, 0.1305):
            b.box((0.0010, 0.0450, 0.0020), (sx * 0.0302, -0.0175, z), "hw_dark", part="stripe")
        for i in range(5):
            b.box((0.0007, 0.0036, 0.0200), (sx * 0.0301, -0.032 + i * 0.0072, 0.1200), "hw_dark", part="stripe", rot=(35 * sx, 0, 0))

    # Gas cylinder: saddles and straps, colour band, domed ends, drain plug.
    for y in (-0.0350, 0.0150):
        b.box((0.0440, 0.0120, 0.0075), (0.0, y, 0.14325), "hw_dark")
        b.cyl(0.0228, 0.0070, (0.0, y, tank_z), "hw_steel", axis="y", sides=12)
    b.cyl(0.0220, 0.0760, (0.0, -0.0071, tank_z), "hw_metal", axis="y", sides=12, part="tank")
    seg(b, (0.0, -0.0591, tank_z), (0.0, -0.0451, tank_z), 0.0150, 0.0220, "hw_metal", sides=12, part="tank")
    seg(b, (0.0, 0.0309, tank_z), (0.0, 0.0409, tank_z), 0.0220, 0.0120, "hw_metal", sides=12, part="tank")
    b.cyl(0.0090, 0.0090, (0.0, 0.0424, tank_z), "hw_steel", axis="y", sides=8)
    b.bolt((0.0, y0, tank_z), "hw_steel", axis="-y", radius=0.0045, height=0.0015)
    b.cyl(0.0225, 0.0150, (0.0, -0.0151, tank_z), "hw_teal", axis="y", sides=12)
    for dy in (-0.0100, 0.0100):
        b.cyl(0.0226, 0.0030, (0.0, -0.0151 + dy, tank_z), "hw_hazard_amber", axis="y", sides=12)

    # Regulator: block, side gauge, adjuster knob, relief valve, hose fitting.
    ry = 0.0569
    b.box((0.0300, 0.0200, 0.0260), (0.0, ry, tank_z), "hw_steel", bevel=0.0025)
    gz = tank_z + 0.002
    b.cyl(0.0105, 0.0070, (0.0185, ry, gz), "hw_steel", axis="x", sides=12)
    b.cyl(0.0086, 0.0007, (0.02235, ry, gz), "hw_dark", axis="x", sides=12)
    for k in range(5):
        a = -120 + 60 * k
        b.box((0.0006, 0.0010, 0.0026), (0.0226, ry + 0.0070 * math.sin(math.radians(a)), gz + 0.0070 * math.cos(math.radians(a))), "hw_beige", rot=(-a, 0, 0))
    na = 38
    b.box((0.0006, 0.0010, 0.0072), (0.0229, ry + 0.0036 * math.sin(math.radians(na)), gz + 0.0036 * math.cos(math.radians(na))), "hw_hazard_amber", rot=(-na, 0, 0))
    b.cyl(0.0014, 0.0010, (0.0231, ry, gz), "hw_steel", axis="x", sides=6)
    b.fluted(0.0075, 0.0090, (-0.0195, ry, gz), "hw_rubber", flutes=8, depth=0.0014, axis="x")
    b.cyl(0.0034, 0.0014, (-0.0247, ry, gz), "hw_steel", axis="x", sides=6)
    b.cyl(0.0035, 0.0050, (0.0, ry, 0.1755), "hw_steel", sides=6)
    b.cyl(0.0024, 0.0020, (0.0, ry, 0.1790), "hw_dark", sides=6)
    b.cyl(0.0070, 0.0050, (0.0, 0.0694, tank_z), "hw_steel", axis="y", sides=6)

    # Hose from the regulator down into the body, with clamps and a body-side fitting.
    path = [(0.0, 0.0719, tank_z), (0.0, 0.0800, 0.1595), (0.0, 0.0865, 0.1550), (0.0, 0.0900, 0.1480), (0.0, 0.0905, 0.1415)]
    hose(b, path, 0.0045, "hw_rubber", sides=6)
    seg(b, (0.0, 0.0735, tank_z), (0.0, 0.0765, tank_z), 0.0058, 0.0058, "hw_steel", sides=6)
    seg(b, (0.0, 0.0905, 0.1445), (0.0, 0.0905, 0.1475), 0.0058, 0.0058, "hw_steel", sides=6)
    b.cyl(0.0070, 0.0070, (0.0, 0.0905, 0.1435), "hw_steel", sides=6)

    # Nozzle: dark collar ring with bolts, heat-shield stack, knurled sleeve, cone with bands, glowing tip.
    b.cyl(0.0260, 0.0160, (0.0, 0.0989, ny), "hw_dark", axis="y", sides=12, bevel=0.0018, part="ring")
    b.cyl(0.0212, 0.0010, (0.0, 0.1074, ny), "hw_steel", axis="y", sides=12)
    for px, pz in ring_points(0.0, ny, 0.0236, 4, 45):
        b.bolt((px, 0.1069, pz), "hw_steel", axis="y", radius=0.0014, height=0.0012)
    b.cyl(0.0125, 0.0166, (0.0, 0.1152, ny), "hw_dark", axis="y", sides=10)
    for y, r in ((0.1100, 0.0205), (0.1150, 0.0193), (0.1200, 0.0181)):
        b.cyl(r, 0.0030, (0.0, y, ny), "hw_steel", axis="y", sides=12)
    b.fluted(0.0158, 0.0100, (0.0, 0.1285, ny), "hw_steel", flutes=8, depth=0.0016, axis="y")
    seg(b, (0.0, 0.1335, ny), (0.0, 0.1860, ny), 0.0150, 0.0072, "hw_metal", sides=10, part="nozzle")
    seg(b, (0.0, 0.1860, ny), (0.0, 0.1930, ny), 0.0072, 0.0064, "hw_steel", sides=10)
    tube(b, 0.0132, 0.0110, 0.0030, (0.0, 0.1500, ny), "hw_dark", axis="y", sides=10)
    tube(b, 0.0102, 0.0085, 0.0030, (0.0, 0.1700, ny), "hw_dark", axis="y", sides=10)
    seg(b, (0.0, 0.1930, ny), (0.0, 0.1959, ny), 0.0062, 0.0046, "hw_phosphor_amber", sides=10, part="emitter")

    # Pistol grip: raked dark core, rubber finger grooves, palm strips, side pads, pommel, guard and trigger.
    b.prism([(-0.0691, 0.0), (-0.0361, 0.0), (-0.0191, 0.0660), (-0.0591, 0.0660)], 0.0420, (0, 0, 0), "hw_dark", plane="yz", bevel=0.003)
    b.box((0.0445, 0.0345, 0.0075), (0.0, -0.0522, 0.00375), "hw_rubber", bevel=0.0022)
    tilt = math.degrees(math.atan2(0.0170, 0.066))
    for z in (0.016, 0.024, 0.032):
        fy = -0.0361 + 0.0170 * z / 0.066
        b.box((0.0370, 0.0036, 0.0050), (0.0, fy + math.cos(math.radians(tilt)) * 0.0009, z - math.sin(math.radians(tilt)) * 0.0009), "hw_rubber", rot=(-tilt, 0, 0))
    tilt_b = math.degrees(math.atan2(0.0100, 0.066))
    by = -0.0691 + 0.0100 * 0.032 / 0.066
    for i in range(4):
        b.box((0.0048, 0.0030, 0.0480), (-0.0105 + i * 0.0070, by - 0.0008, 0.032), "hw_rubber", rot=(-tilt_b, 0, 0))
    for sx in (-1, 1):
        b.box((0.0016, 0.0250, 0.0340), (sx * 0.0210, -0.0457, 0.0340), "hw_rubber", rot=(-11.6, 0, 0))
        b.box((0.0030, 0.0440, 0.0040), (sx * 0.0072, -0.0070, 0.0340), "hw_dark")
        b.box((0.0030, 0.0050, 0.0290), (sx * 0.0072, 0.0150, 0.0472), "hw_dark")
    b.box((0.0070, 0.0055, 0.0250), (0.0, -0.0070, 0.0470), "hw_steel", bevel=0.0008, rot=(12, 0, 0))

    root = b.build()
    kit.animate(root, "use_cutter", [
        (0, {"location": (0, 0, 0)}), (5, {"location": (0, -0.010, 0)}), (24, {"location": (0, 0, 0)}),
    ])
    kit.animate(b.holders["emitter"], "use_cutter", [
        (0, {"scale": (1, 1, 1)}), (8, {"scale": (1.5, 1.5, 1.5)}), (24, {"scale": (1, 1, 1)}),
    ])
    kit.animate(b.holders["lamp"], "use_cutter", [
        (0, {"scale": (1, 1, 1)}), (12, {"scale": (1.5, 1.5, 1.5)}), (24, {"scale": (1, 1, 1)}),
    ])
    kit.check_bounds(root, *kit.REFERENCE_BOUNDS["hw_cutter"])
    return root


MODELS = {"scanner": (build_scanner, "tools/hw_scanner.glb"), "cutter": (build_cutter, "tools/hw_cutter.glb")}


def main() -> None:
    wanted = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, (build, path) in MODELS.items():
        if wanted and name not in wanted:
            continue
        kit.reset()
        root = build()
        low, high = kit.bounds(root)
        print(f"BUILT {root.name}: {kit.triangles(root)} tris, bounds {tuple(round(v, 4) for v in low)} .. {tuple(round(v, 4) for v in high)}")
        kit.export(root, path)


main()
