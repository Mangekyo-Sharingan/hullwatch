"""Galley counter and breaker cabinet models for the hands-on pass (see hw_kit.py).

Run headless from the repo root (writes props/hw_galley_unit.glb and machinery/hw_breaker_cabinet.glb):
    blender --background --factory-startup --python art/blender/build_hands_on_galley_breaker.py
    blender --background --factory-startup --python art/blender/build_hands_on_galley_breaker.py -- breaker
Set HW_MODELS_DIR to redirect output while iterating.

Both keep the footprint of the models they replace (hw_kit.REFERENCE_BOUNDS). The breaker cabinet
ships two actions on `breaker_main_lever`: `toggle_on` (0 -> 54 degrees about the glTF +Z axis, which is
Blender -54 degrees about Y) and `toggle_off` (the reverse); BreakerPanel plays one and seeks to its end,
so the end pose is the resting state. The lever mesh is authored in the OFF pose.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import hw_kit as kit  # noqa: E402

BEIGE, DARK, METAL, STEEL, RUBBER = "hw_beige", "hw_dark", "hw_metal", "hw_steel", "hw_rubber"
AMBER, RED, TEAL = "hw_hazard_amber", "hw_hazard_red", "hw_teal"
LAMP_GREEN, LAMP_AMBER = "hw_phosphor_green", "hw_phosphor_amber"


# -- local helpers ----------------------------------------------------------------------------
def ext(b, xr, yr, zr, mat, bevel=0.0, part="", rot=None) -> None:
    """Box from axis extents ((x0, x1), (y0, y1), (z0, z1))."""
    size = (abs(xr[1] - xr[0]), abs(yr[1] - yr[0]), abs(zr[1] - zr[0]))
    centre = ((xr[0] + xr[1]) / 2, (yr[0] + yr[1]) / 2, (zr[0] + zr[1]) / 2)
    b.box(size, centre, mat, bevel=bevel, part=part, rot=rot)


def ring_xz(b, xr, zr, yr, t, mat, bevel=0.0, part="") -> None:
    """Rectangular frame in the XZ plane (faces -Y) of border width t."""
    ext(b, xr, yr, (zr[1] - t, zr[1]), mat, bevel, part)
    ext(b, xr, yr, (zr[0], zr[0] + t), mat, bevel, part)
    ext(b, (xr[0], xr[0] + t), yr, (zr[0] + t, zr[1] - t), mat, bevel, part)
    ext(b, (xr[1] - t, xr[1]), yr, (zr[0] + t, zr[1] - t), mat, bevel, part)


def ring_xy(b, xr, yr, zr, t, mat, bevel=0.0, part="") -> None:
    """Rectangular frame in the XY plane (faces +Z) of border width t."""
    ext(b, xr, (yr[1] - t, yr[1]), zr, mat, bevel, part)
    ext(b, xr, (yr[0], yr[0] + t), zr, mat, bevel, part)
    ext(b, (xr[0], xr[0] + t), (yr[0] + t, yr[1] - t), zr, mat, bevel, part)
    ext(b, (xr[1] - t, xr[1]), (yr[0] + t, yr[1] - t), zr, mat, bevel, part)


def hex_bolt(b, centre, mat, axis="-y", radius=0.0042, height=0.003, part="") -> None:
    b.bolt(centre, mat, axis=axis, radius=radius, height=height, part=part)


# Stroke font on a 1 x 2 grid; each stroke is (x0, z0, x1, z1).
GLYPHS = {
    "A": [(0, 0, .5, 2), (.5, 2, 1, 0), (.2, .8, .8, .8)],
    "C": [(0, 0, 0, 2), (0, 2, 1, 2), (0, 0, 1, 0)],
    "E": [(0, 0, 0, 2), (0, 2, 1, 2), (0, 1, .8, 1), (0, 0, 1, 0)],
    "F": [(0, 0, 0, 2), (0, 2, 1, 2), (0, 1, .8, 1)],
    "G": [(0, 0, 0, 2), (0, 2, 1, 2), (0, 0, 1, 0), (1, 0, 1, 1), (.5, 1, 1, 1)],
    "H": [(0, 0, 0, 2), (1, 0, 1, 2), (0, 1, 1, 1)],
    "I": [(.5, 0, .5, 2), (.2, 0, .8, 0), (.2, 2, .8, 2)],
    "K": [(0, 0, 0, 2), (1, 2, 0, 1), (0, 1, 1, 0)],
    "L": [(0, 0, 0, 2), (0, 0, 1, 0)],
    "M": [(0, 0, 0, 2), (1, 0, 1, 2), (0, 2, .5, 1), (.5, 1, 1, 2)],
    "N": [(0, 0, 0, 2), (1, 0, 1, 2), (0, 2, 1, 0)],
    "O": [(0, 0, 0, 2), (1, 0, 1, 2), (0, 2, 1, 2), (0, 0, 1, 0)],
    "S": [(1, 2, 0, 2), (0, 2, 0, 1), (0, 1, 1, 1), (1, 1, 1, 0), (1, 0, 0, 0)],
    "T": [(0, 2, 1, 2), (.5, 0, .5, 2)],
    "U": [(0, 0, 0, 2), (1, 0, 1, 2), (0, 0, 1, 0)],
    "V": [(0, 2, .5, 0), (1, 2, .5, 0)],
    "Y": [(0, 2, .5, 1), (1, 2, .5, 1), (.5, 0, .5, 1)],
    "1": [(.5, 0, .5, 2), (.15, 1.6, .5, 2)],
    "2": [(0, 2, 1, 2), (1, 2, 1, 1), (1, 1, 0, 1), (0, 1, 0, 0), (0, 0, 1, 0)],
    "4": [(0, 2, 0, 1), (0, 1, 1, 1), (1, 0, 1, 2)],
}


def text_width(s: str, height: float) -> float:
    advance = height * 0.75
    return advance * len(s) - height * 0.25


def text(b, s: str, cx: float, cz: float, height: float, y: float, mat: str, depth=0.0012, part="") -> None:
    """Raised stroke lettering on a face looking toward -Y; `y` is the surface it sits on."""
    advance = height * 0.75
    sx, sz = height * 0.5, height / 2
    thick = height * 0.13
    left = cx - text_width(s, height) / 2
    for i, ch in enumerate(s):
        if ch == " ":
            continue
        ox = left + advance * i
        for x0, z0, x1, z1 in GLYPHS[ch]:
            ax, az = ox + x0 * sx, cz - height / 2 + z0 * sz
            bx, bz = ox + x1 * sx, cz - height / 2 + z1 * sz
            length = math.hypot(bx - ax, bz - az) + thick
            angle = -math.degrees(math.atan2(bz - az, bx - ax))
            b.box((length, depth, thick), ((ax + bx) / 2, y - depth / 2, (az + bz) / 2), mat, part=part, rot=(0, angle, 0))


def clip_x(poly, lo, hi):
    """Clip a polygon to lo <= x <= hi (Sutherland-Hodgman against two vertical lines)."""
    for edge, keep in ((lo, lambda p: p[0] >= lo), (hi, lambda p: p[0] <= hi)):
        out = []
        for i, cur in enumerate(poly):
            prev = poly[i - 1]
            if keep(cur) != keep(prev):
                t = (edge - prev[0]) / (cur[0] - prev[0])
                out.append((edge, prev[1] + t * (cur[1] - prev[1])))
            if keep(cur):
                out.append(cur)
        poly = out
        if not poly:
            break
    return poly


def hazard_stripes(b, xr, zr, y, thick, mat, pitch=0.034, width=0.017, part="") -> None:
    """Diagonal hazard stripes clipped to a rectangle on a -Y facing plate."""
    zb, zt = zr
    slope = (zt - zb)  # 45 degrees
    x = xr[0] - slope - pitch
    while x < xr[1]:
        poly = clip_x([(x, zb), (x + width, zb), (x + width + slope, zt), (x + slope, zt)], xr[0], xr[1])
        if len(poly) >= 3 and abs(max(p[0] for p in poly) - min(p[0] for p in poly)) > 0.002:
            b.prism(poly, thick, (0, y, 0), mat, plane="xz", part=part)
        x += pitch


def slots(b, count, size, start, step, mat, part="") -> None:
    """A run of unchamfered slots (cheaper than Builder.vents); start is the first centre."""
    for i in range(count):
        b.box(size, (start[0] + step[0] * i, start[1] + step[1] * i, start[2] + step[2] * i), mat, part=part)


# -- breaker cabinet ---------------------------------------------------------------------------
LEVER_PIVOT = (0.0, -0.1735, 0.445)
LEVER_OFF_ANGLE = 27.0  # degrees clockwise from straight up (toward +X) as seen from the front
LEVER_TOGGLE_DEG = 54.0


def lever_point(radius: float, angle_deg: float, y: float):
    a = math.radians(angle_deg)
    return (LEVER_PIVOT[0] + math.sin(a) * radius, y, LEVER_PIVOT[2] + math.cos(a) * radius)


def build_breaker() -> bpy.types.Object:
    b = kit.Builder("hw_breaker_cabinet")
    b.pivot("main_lever", LEVER_PIVOT)
    face = -0.152  # front of the door

    # Wall flange, enclosure, hinged door with a dark gap behind its edge.
    ext(b, (-0.35, 0.35), (-0.008, 0.0), (0.0, 1.0), METAL, 0.003)
    ext(b, (-0.325, 0.325), (-0.140, -0.008), (0.025, 0.975), BEIGE, 0.005)
    ext(b, (-0.321, 0.321), (-0.1415, -0.1395), (0.034, 0.966), DARK, 0.001)
    ext(b, (-0.318, 0.318), (face, -0.1415), (0.037, 0.963), BEIGE, 0.004)

    # Flange ears: slotted holes with bolts, plus keyholes and a stamped rib on the wall side.
    for side in (-1, 1):
        for z in (0.10, 0.50, 0.90):
            ext(b, (side * 0.3375 - 0.005, side * 0.3375 + 0.005), (-0.0085, -0.0075), (z - 0.011, z + 0.011), DARK)
            hex_bolt(b, (side * 0.3375, -0.008, z), STEEL, radius=0.0045, height=0.0025)
        ext(b, (side * 0.30 - 0.007, side * 0.30 + 0.007), (-0.0008, 0.0008), (0.105, 0.133), DARK)
        ext(b, (side * 0.30 - 0.007, side * 0.30 + 0.007), (-0.0008, 0.0008), (0.867, 0.895), DARK)
    ext(b, (-0.30, 0.30), (-0.001, 0.0015), (0.04, 0.052), STEEL, 0.0008)
    ext(b, (-0.30, 0.30), (-0.001, 0.0015), (0.948, 0.960), STEEL, 0.0008)
    for side in (-1, 1):
        ext(b, (side * 0.30 - 0.006, side * 0.30 + 0.006), (-0.001, 0.0015), (0.04, 0.96), STEEL, 0.0008)
    ext(b, (-0.07, 0.07), (-0.0006, 0.0008), (0.47, 0.53), BEIGE, 0.0005)
    for k, w in enumerate((0.11, 0.09, 0.10)):
        ext(b, (-w / 2, w / 2), (0.0007, 0.0013), (0.518 - k * 0.012 - 0.0015, 0.518 - k * 0.012 + 0.0015), DARK)

    # Side louvres, conduit nipples with lock nuts and cable boots through the top and bottom.
    for side in (-1, 1):
        slots(b, 6, (0.002, 0.07, 0.008), (side * 0.3255, -0.078, 0.62), (0, 0, 0.016), DARK)
    for x in (-0.20, 0.0, 0.20):
        b.cyl(0.0125, 0.030, (x, -0.07, 0.015), STEEL, sides=8)
        b.cyl(0.0165, 0.006, (x, -0.07, 0.027), METAL, sides=6)
    for x in (-0.08, 0.08):
        b.cyl(0.0125, 0.030, (x, -0.07, 0.985), STEEL, sides=8)
        b.cyl(0.0165, 0.006, (x, -0.07, 0.973), METAL, sides=6)
    b.cyl(0.0085, 0.014, (0.0, -0.07, 0.007), RUBBER, sides=8)

    # Hinge barrels on the left edge, quarter-turn latch on the right.
    for z in (0.16, 0.50, 0.84):
        b.cyl(0.0068, 0.075, (-0.3235, -0.1465, z), STEEL, sides=8)
        b.cyl(0.0035, 0.083, (-0.3235, -0.1465, z), METAL, sides=6)
    b.cyl(0.0145, 0.008, (0.298, face - 0.004, 0.50), STEEL, axis="y", sides=10)
    ext(b, (0.298 - 0.012, 0.298 + 0.012), (face - 0.0095, face - 0.0075), (0.4975, 0.5025), DARK, 0.0006)
    ext(b, (0.2965, 0.2995), (face - 0.0095, face - 0.0075), (0.4875, 0.5125), DARK, 0.0006)

    # Hazard header band with clipped stripes, corner bolts.
    ext(b, (-0.30, 0.30), (face, face + -0.0045), (0.872, 0.932), DARK, 0.001)
    hazard_stripes(b, (-0.297, 0.297), (0.875, 0.929), face - 0.0050, 0.0012, AMBER)
    for side in (-1, 1):
        for z in (0.052, 0.948):
            hex_bolt(b, (side * 0.3055, face, z), STEEL, radius=0.005, height=0.0028)

    # Lamp cluster: bezels, lit lenses, legends.
    for x, lamp, legend in ((-0.17, LAMP_AMBER, "LIVE"), (0.17, RED, "FAULT")):
        b.cyl(0.0225, 0.007, (x, face - 0.0025, 0.80), STEEL, axis="y", sides=10)
        b.cyl(0.0155, 0.009, (x, face - 0.0065, 0.80), lamp, axis="y", sides=10)
        text(b, legend, x, 0.7625, 0.0105, face, BEIGE)

    # Lockout block: dark housing, hinged hasp, staple and a hanging padlock.
    ext(b, (-0.09, 0.09), (face, -0.1675), (0.705, 0.845), DARK, 0.003)
    text(b, "LOCKOUT", 0.0, 0.7185, 0.0095, -0.1675, AMBER)
    b.cyl(0.0045, 0.12, (-0.072, -0.1715, 0.79), STEEL, sides=6)
    ext(b, (-0.072, 0.066), (-0.1745, -0.1685), (0.779, 0.801), STEEL, 0.0008)
    ext(b, (0.044, 0.066), (-0.1785, -0.1745), (0.775, 0.805), METAL, 0.0008)
    ext(b, (0.0535, 0.0565), (-0.1788, -0.1745), (0.7865, 0.7935), DARK)
    ext(b, (0.037, 0.073), (-0.1895, -0.1745), (0.728, 0.762), AMBER, 0.0025)
    ext(b, (0.049, 0.061), (-0.1900, -0.1895), (0.735, 0.741), DARK)
    for x in (0.0425, 0.0635):
        ext(b, (x - 0.0015, x + 0.0015), (-0.1805, -0.1775), (0.762, 0.795), STEEL, 0.0005)
    ext(b, (0.0425, 0.0635), (-0.1805, -0.1775), (0.7925, 0.7955), STEEL, 0.0005)
    for z in (0.715, 0.835):
        for x in (-0.078, 0.078):
            hex_bolt(b, (x, -0.1675, z), STEEL, radius=0.0035, height=0.0018)

    # Isolator escutcheon: dark plate, steel frame, scale ticks, ON/OFF legends, stops, hub boss.
    px, pz = LEVER_PIVOT[0], LEVER_PIVOT[2]
    ext(b, (-0.125, 0.125), (face, -0.1575), (0.355, 0.655), DARK, 0.002)
    ring_xz(b, (-0.131, 0.131), (0.349, 0.661), (face, -0.1625), 0.006, STEEL)
    for ang in (-27.0, -13.5, 0.0, 13.5, 27.0):
        tick = lever_point(0.172, ang, -0.1583)
        b.box((0.0045, 0.0016, 0.014), tick, BEIGE if ang else AMBER, rot=(0, ang, 0))
    text(b, "ON", px - 0.0945, 0.626, 0.014, -0.1575, AMBER)
    text(b, "OFF", px + 0.0945, 0.626, 0.014, -0.1575, BEIGE)
    for side, ang in ((-1, -37.0), (1, 37.0)):
        stop = lever_point(0.135, ang, -0.1608)
        b.box((0.014, 0.0066, 0.022), stop, RUBBER, bevel=0.0015, rot=(0, ang, 0))
    b.cyl(0.036, 0.007, (px, -0.161, pz), STEEL, axis="y", sides=12, bevel=0.0012)
    b.cyl(0.026, 0.002, (px, -0.1655, pz), DARK, axis="y", sides=12)
    for dx in (-0.1, 0.1):
        hex_bolt(b, (px + dx, -0.1575, 0.375), STEEL, radius=0.0035, height=0.002)

    # Main lever: authored in the OFF position (up and to the right), pivoting at the hub.
    ang = LEVER_OFF_ANGLE
    part = "main_lever"
    b.cyl(0.0235, 0.016, (px, -0.1735, pz), AMBER, axis="y", sides=10, bevel=0.0012, part=part)
    b.cyl(0.0115, 0.0035, (px, -0.1835, pz), STEEL, axis="y", sides=6, part=part)
    stem_a, stem_b = 0.020, 0.095
    b.box((0.016, 0.012, stem_b - stem_a), lever_point((stem_a + stem_b) / 2, ang, -0.1715), STEEL, bevel=0.0018, part=part, rot=(0, ang, 0))
    b.box((0.014, 0.010, 0.045), lever_point(-0.0225, ang, -0.1715), METAL, bevel=0.0015, part=part, rot=(0, ang, 0))
    b.box((0.020, 0.012, 0.012), lever_point(-0.047, ang, -0.1715), RUBBER, bevel=0.002, part=part, rot=(0, ang, 0))
    grip_a, grip_b = 0.088, 0.158
    b.box((0.034, 0.0285, grip_b - grip_a), lever_point((grip_a + grip_b) / 2, ang, -0.1822), BEIGE, bevel=0.0045, part=part, rot=(0, ang, 0))
    for i in range(5):  # rubber grip ribs across the front of the handle
        r = grip_a + 0.012 + i * 0.0145
        b.box((0.034, 0.0016, 0.0042), lever_point(r, ang, -0.1967), RUBBER, part=part, rot=(0, ang, 0))
    b.box((0.034, 0.0285, 0.003), lever_point(grip_b + 0.0008, ang, -0.1822), AMBER, part=part, rot=(0, ang, 0))

    # Status modules: two banks of six trip modules with toggles, meter strips between modules and edge.
    for side, states in ((-1, (1, 1, 1, 0, 1, 1)), (1, (1, 0, 1, 1, 1, 0))):
        cx = side * 0.195
        ext(b, (cx - 0.0405, cx + 0.0405), (face, -0.1555), (0.105, 0.652), DARK, 0.0012)
        ring_xz(b, (cx - 0.0445, cx + 0.0445), (0.101, 0.656), (face, -0.1565), 0.004, STEEL)
        for i, on in enumerate(states):
            zc = 0.150 + 0.0885 * i
            ext(b, (cx - 0.028, cx + 0.028), (-0.1775, -0.1555), (zc - 0.037, zc + 0.037), METAL, 0.003)
            ext(b, (cx - 0.020, cx + 0.020), (-0.1783, -0.1775), (zc - 0.034, zc - 0.026), TEAL)
            ext(b, (cx - 0.011, cx + 0.011), (-0.1780, -0.1775), (zc + 0.026, zc + 0.034), DARK)
            ext(b, (cx - 0.0045, cx + 0.0045), (-0.1785, -0.1775), (zc + 0.0285, zc + 0.0315), AMBER if not on else BEIGE)
            base = (cx, -0.1790, zc + 0.002)
            b.cyl(0.0105, 0.004, (base[0], base[1], base[2]), DARK, axis="y", sides=6)
            alpha = 25.0 if on else 155.0
            direction = (0.0, -math.sin(math.radians(alpha)), math.cos(math.radians(alpha)))
            mid = tuple(base[k] + direction[k] * 0.0135 for k in range(3))
            tip = tuple(base[k] + direction[k] * 0.0285 for k in range(3))
            b.box((0.008, 0.008, 0.027), mid, STEEL, part="", rot=(alpha, 0, 0))
            b.box((0.011, 0.011, 0.009), tip, BEIGE if on else AMBER, bevel=0.0015, rot=(alpha, 0, 0))
        edge = side * 0.268
        ring_xz(b, (edge - 0.013, edge + 0.013), (0.150, 0.626), (face, -0.1562), 0.003, STEEL)
        ext(b, (edge - 0.010, edge + 0.010), (face, -0.1545), (0.153, 0.623), DARK)
        for k in range(5):
            zt = 0.19 + k * 0.10
            ext(b, (edge - 0.0065, edge + 0.0065), (-0.1553, -0.1565), (zt - 0.003, zt + 0.003), BEIGE)

    # Data plate and ventilation louvres along the bottom.
    ext(b, (-0.085, 0.085), (face, -0.1545), (0.045, 0.095), STEEL, 0.0012)
    text(b, "MAIN", 0.0, 0.082, 0.0105, -0.1545, DARK)
    for k, w in enumerate((0.11, 0.09, 0.10)):
        ext(b, (-w / 2, w / 2), (-0.1545, -0.1553), (0.0565 - k * 0.0045 - 0.0015, 0.0565 - k * 0.0045 + 0.0015), DARK)
    for side in (-1, 1):
        slots(b, 4, (0.155, 0.002, 0.005), (side * 0.205, face - 0.0005, 0.050), (0, 0, 0.0085), DARK)

    root = b.build()
    holder = b.holders[part]
    for child in holder.children:
        child.name = child.name.replace("hw_breaker_cabinet_main_lever", "breaker_main_lever")
    holder.name = "breaker_main_lever"

    # Two separate actions on the lever, 12 frames (0.5 s at 24 fps). The OFF -> ON clip stays the
    # active action (so the exported rest pose is the OFF pose); ON -> OFF is parked on an NLA track,
    # which the glTF exporter also writes out as its own animation.
    on_deg = -LEVER_TOGGLE_DEG
    kit.animate(holder, "toggle_off", [(0, {"rotation": (0, on_deg, 0)}), (8, {"rotation": (0, 3.0, 0)}), (12, {"rotation": (0, 0, 0)})])
    track = holder.animation_data.nla_tracks.new()
    track.name = "toggle_off"
    strip = track.strips.new("toggle_off", 0, holder.animation_data.action)
    holder.animation_data.action = None
    holder.rotation_euler = (0.0, 0.0, 0.0)
    kit.animate(holder, "toggle_on", [(0, {"rotation": (0, 0, 0)}), (8, {"rotation": (0, on_deg - 3.0, 0)}), (12, {"rotation": (0, on_deg, 0)})])
    bpy.context.scene.frame_set(0)
    kit.check_bounds(root, *kit.REFERENCE_BOUNDS["hw_breaker_cabinet"])
    return root


# -- galley counter ----------------------------------------------------------------------------
def door_frame(b, xr, zr, y0, y1, t, inset_mat=TEAL, inset_depth=0.008, bevel=0.0025) -> None:
    """Framed door: chamfered top/bottom rails and plain stiles around a recessed panel."""
    ext(b, xr, (y0, y1), (zr[1] - t, zr[1]), BEIGE, bevel)
    ext(b, xr, (y0, y1), (zr[0], zr[0] + t), BEIGE, bevel)
    ext(b, (xr[0], xr[0] + t), (y0, y1), (zr[0] + t, zr[1] - t), BEIGE)
    ext(b, (xr[1] - t, xr[1]), (y0, y1), (zr[0] + t, zr[1] - t), BEIGE)
    ext(b, (xr[0] + t * 0.6, xr[1] - t * 0.6), (y0, y1 + inset_depth), (zr[0] + t * 0.6, zr[1] - t * 0.6), inset_mat)


def handle_vertical(b, x, z0, z1, y_face) -> None:
    for z in (z0 + 0.012, z1 - 0.012):
        ext(b, (x - 0.004, x + 0.004), (y_face, y_face - 0.006), (z - 0.005, z + 0.005), STEEL)
    b.cyl(0.0045, z1 - z0, (x, y_face - 0.0105, (z0 + z1) / 2), STEEL, sides=6)


def handle_horizontal(b, x0, x1, z, y_face) -> None:
    for x in (x0 + 0.012, x1 - 0.012):
        ext(b, (x - 0.005, x + 0.005), (y_face, y_face - 0.006), (z - 0.004, z + 0.004), STEEL)
    b.cyl(0.0045, x1 - x0, ((x0 + x1) / 2, y_face - 0.0105, z), STEEL, axis="x", sides=6)


def build_galley() -> bpy.types.Object:
    b = kit.Builder("hw_galley_unit")
    top = 0.70
    carcass_front = -0.268
    door_back = -0.2695
    door_front = -0.2845

    # Plinth with hazard marks, carcass, counter slab in welded sections.
    ext(b, (-0.57, 0.57), (-0.255, 0.27), (0.0, 0.08), DARK, 0.003)
    for side in (-1, 1):
        for i in range(5):
            b.box((0.011, 0.0012, 0.05), (side * (0.455 + i * 0.020), -0.2557, 0.040), AMBER, rot=(0, 32, 0))
    ext(b, (-0.585, -0.53), (carcass_front, 0.285), (0.08, 0.668), BEIGE, 0.004)
    ext(b, (-0.15, 0.585), (carcass_front, 0.285), (0.08, 0.668), BEIGE, 0.004)
    ext(b, (-0.53, -0.15), (carcass_front, 0.285), (0.08, 0.53), BEIGE)  # sink bay below the basin
    ext(b, (-0.53, -0.15), (carcass_front, -0.22), (0.53, 0.668), BEIGE)
    ext(b, (-0.53, -0.15), (0.055, 0.285), (0.53, 0.668), BEIGE)
    for x0, x1, y0, y1 in ((-0.6, -0.53, -0.3, 0.3), (-0.53, -0.15, -0.3, -0.22), (-0.53, -0.15, 0.055, 0.3), (-0.15, 0.5, -0.3, 0.3), (0.5, 0.6, -0.3, 0.3)):
        ext(b, (x0, x1), (y0, y1), (0.668, top), STEEL, 0.002)

    # Dark backing so door gaps read as shadow lines.
    for x0, x1, z0, z1 in ((-0.56, -0.011, 0.086, 0.560), (0.011, 0.56, 0.086, 0.560), (-0.56, 0.095, 0.563, 0.665), (0.098, 0.56, 0.563, 0.665)):
        ext(b, (x0, x1), (door_back - 0.0015, carcass_front), (z0, z1), DARK)

    # Sink bay: two framed doors with vertical handles, hinges, wear plates.
    for x0, x1, hinge_x, handle_x in ((-0.555, -0.2865, -0.5545, -0.3025), (-0.2805, -0.012, -0.0125, -0.2635)):
        door_frame(b, (x0, x1), (0.088, 0.558), door_back, door_front, 0.036)
        handle_vertical(b, handle_x, 0.26, 0.40, door_front)
        for z in (0.16, 0.48):
            b.cyl(0.0048, 0.045, (hinge_x, door_front + 0.0035, z), STEEL, sides=8)
        ext(b, (x0 + 0.02, x1 - 0.02), (door_front - 0.0015, door_front), (0.09, 0.114), STEEL)
        ext(b, (handle_x - 0.007, handle_x + 0.007), (door_front - 0.001, door_front), (0.5, 0.545), DARK)
    # Drawer bank under the hobs: three framed drawers with horizontal handles.
    for z0, z1 in ((0.088, 0.208), (0.214, 0.380), (0.386, 0.558)):
        door_frame(b, (0.012, 0.555), (z0, z1), door_back, door_front, 0.034)
        handle_horizontal(b, 0.20, 0.37, z1 - 0.050, door_front)
        ext(b, (0.03, 0.05), (door_front - 0.0015, door_front), (z0 + 0.026, z0 + 0.036), TEAL)
    ext(b, (0.43, 0.54), (door_front - 0.0015, door_front), (0.112, 0.118), AMBER)

    # Top band: drawer with amber GALLEY label, recessed hob control pocket.
    door_frame(b, (-0.555, 0.08), (0.567, 0.660), door_back, door_front, 0.016, inset_mat=BEIGE, inset_depth=0.004, bevel=0.002)
    handle_horizontal(b, -0.36, -0.12, 0.6135, door_front)
    ext(b, (-0.52, -0.39), (door_front + 0.005, door_front + 0.0035), (0.597, 0.630), AMBER)
    text(b, "GALLEY", -0.455, 0.6135, 0.014, door_front + 0.0035, DARK)
    ring_xz(b, (0.098, 0.558), (0.563, 0.665), (door_back, door_front - 0.002), 0.008, STEEL)
    ext(b, (0.106, 0.550), (door_back, -0.2745), (0.571, 0.657), DARK)
    for cx, label in ((0.19, "1"), (0.34, "2")):
        b.cyl(0.0225, 0.003, (cx, -0.2760, 0.6135), STEEL, axis="y", sides=12)
        b.fluted(0.0165, 0.0155, (cx, -0.2858, 0.6135), RUBBER, flutes=10, depth=0.0014, axis="y")
        b.cyl(0.0105, 0.001, (cx, -0.2938, 0.6135), METAL, axis="y", sides=10)
        ext(b, (cx - 0.0015, cx + 0.0015), (-0.2945, -0.2935), (0.6135, 0.627), AMBER)
        for k in range(7):
            a = math.radians(-135 + k * 45)
            b.box((0.0025, 0.0010, 0.0058), (cx + math.sin(a) * 0.0315, -0.2746, 0.6135 + math.cos(a) * 0.0315), BEIGE, rot=(0, math.degrees(a), 0))
        text(b, label, cx, 0.5825, 0.0085, -0.2745, BEIGE)
    for i, lamp in enumerate((LAMP_AMBER, LAMP_GREEN, DARK)):
        x = 0.425 + i * 0.042
        ext(b, (x - 0.013, x + 0.013), (-0.2745, -0.2805), (0.595, 0.619), STEEL)
        ext(b, (x - 0.008, x + 0.008), (-0.2805, -0.2815), (0.600, 0.614), DARK)
        b.cyl(0.0038, 0.003, (x, -0.2762, 0.640), lamp, axis="y", sides=8)
        ext(b, (x - 0.013, x + 0.013), (-0.2745, -0.2753), (0.578, 0.585), TEAL)

    # Corner guards.
    for side in (-1, 1):
        ext(b, (side * 0.558, side * 0.59), (door_front - 0.005, door_front), (0.086, 0.664), STEEL, 0.0015)
        ext(b, (side * 0.5855 - 0.0027, side * 0.5855 + 0.0027), (door_front - 0.005, -0.215), (0.086, 0.664), STEEL, 0.0015)

    # Left end: louvred ventilation grille.
    ext(b, (-0.5935, -0.585), (-0.13, 0.13), (0.30, 0.314), STEEL)
    ext(b, (-0.5935, -0.585), (-0.13, 0.13), (0.536, 0.55), STEEL)
    ext(b, (-0.5935, -0.585), (-0.13, -0.116), (0.314, 0.536), STEEL)
    ext(b, (-0.5935, -0.585), (0.116, 0.13), (0.314, 0.536), STEEL)
    ext(b, (-0.5875, -0.585), (-0.116, 0.116), (0.314, 0.536), DARK)
    for i in range(7):
        z = 0.329 + i * 0.0315
        b.box((0.0042, 0.230, 0.0105), (-0.5896, 0.0, z), METAL, rot=(0, 38, 0))

    # Right end: stowed fold-down shelf with hinge barrel, latch and pads.
    ext(b, (0.585, 0.5925), (-0.19, 0.19), (0.31, 0.62), STEEL, 0.002)
    for z in (0.38, 0.45, 0.52):
        ext(b, (0.5925, 0.5945), (-0.15, 0.15), (z - 0.006, z + 0.006), METAL)
    b.cyl(0.0058, 0.38, (0.5925, 0.0, 0.304), STEEL, axis="y", sides=8)
    for y in (-0.19, -0.10, 0.10, 0.19):
        ext(b, (0.585, 0.5925), (y - 0.008, y + 0.008), (0.298, 0.314), METAL)
    ext(b, (0.585, 0.597), (-0.035, 0.035), (0.624, 0.654), DARK)
    ext(b, (0.5925, 0.5985), (-0.022, 0.022), (0.605, 0.645), STEEL)
    ext(b, (0.5985, 0.6), (-0.012, 0.012), (0.615, 0.632), AMBER)
    for y in (-0.165, 0.165):
        for z in (0.335, 0.595):
            b.cyl(0.004, 0.0035, (0.5935, y, z), RUBBER, axis="x", sides=8)
    ext(b, (0.5935, 0.5985), (-0.03, 0.03), (0.50, 0.515), AMBER)

    # Backsplash with welded seam, rolled top lip, end returns.
    ext(b, (-0.49, 0.49), (0.272, 0.30), (top, 0.9), STEEL, 0.002)
    ext(b, (-0.495, 0.495), (0.262, 0.30), (0.888, 0.90), STEEL, 0.003)
    for side in (-1, 1):
        ext(b, (side * 0.485, side * 0.4975), (0.262, 0.30), (top, 0.90), STEEL, 0.002)
    ext(b, (-0.49, 0.49), (0.268, 0.276), (top, 0.7062), STEEL, 0.0015)
    ext(b, (-0.49, 0.49), (0.3, 0.3015), (0.80, 0.806), STEEL, 0.0015)
    for x in (-0.44, -0.22, 0.0, 0.22, 0.44):
        hex_bolt(b, (x, 0.30, 0.84), STEEL, axis="y", radius=0.005, height=0.0015)

    # Utensil rail with brackets, hooks, a lid, ladle, spatula and towel.
    rail_z, rail_y = 0.86, 0.252
    b.cyl(0.0060, 0.80, (0.0, rail_y, rail_z), STEEL, axis="x", sides=8)
    for x in (-0.40, 0.0, 0.40):
        ext(b, (x - 0.006, x + 0.006), (rail_y, 0.272), (rail_z - 0.010, rail_z + 0.010), STEEL)
    hooks = {"lid": 0.02, "ladle": -0.17, "spat": 0.20, "towel": 0.34}
    for x in hooks.values():
        b.cyl(0.0027, 0.024, (x, rail_y, rail_z - 0.012), STEEL, sides=6)
        ext(b, (x - 0.0027, x + 0.0027), (rail_y - 0.028, rail_y), (rail_z - 0.0245, rail_z - 0.0195), STEEL)
        ext(b, (x - 0.0027, x + 0.0027), (rail_y - 0.028, rail_y - 0.023), (rail_z - 0.0245, rail_z - 0.014), STEEL)
    hook_y = rail_y - 0.0255
    lx = hooks["lid"]
    b.cyl(0.056, 0.008, (lx, hook_y, 0.775), STEEL, axis="y", sides=12, bevel=0.0015)
    b.cyl(0.040, 0.003, (lx, hook_y - 0.0055, 0.775), METAL, axis="y", sides=12)
    b.cyl(0.0105, 0.016, (lx, hook_y - 0.014, 0.775), DARK, axis="y", sides=8)
    ext(b, (lx - 0.008, lx + 0.008), (hook_y - 0.002, hook_y + 0.002), (0.825, 0.842), STEEL)
    gx = hooks["ladle"]
    b.cyl(0.0035, 0.115, (gx, hook_y, 0.7905), STEEL, sides=6)
    b.cyl(0.0052, 0.055, (gx, hook_y, 0.8105), DARK, sides=8)
    b.cyl(0.028, 0.020, (gx, hook_y, 0.7335), STEEL, axis="y", sides=10)
    b.cyl(0.021, 0.004, (gx, hook_y - 0.0085, 0.7335), METAL, axis="y", sides=10)
    sx_ = hooks["spat"]
    ext(b, (sx_ - 0.022, sx_ + 0.022), (hook_y - 0.002, hook_y + 0.002), (0.724, 0.782), STEEL)
    for k in range(4):
        ext(b, (sx_ - 0.016 + k * 0.011, sx_ - 0.012 + k * 0.011), (hook_y - 0.0025, hook_y - 0.0015), (0.728, 0.768), DARK)
    b.cyl(0.0035, 0.045, (sx_, hook_y, 0.8035), STEEL, sides=6)
    b.cyl(0.0058, 0.045, (sx_, hook_y, 0.8225), DARK, sides=8)
    tx = hooks["towel"]
    ext(b, (tx - 0.04, tx + 0.04), (hook_y - 0.003, hook_y + 0.003), (0.715, 0.838), TEAL)
    ext(b, (tx - 0.04, tx + 0.04), (hook_y - 0.003, rail_y + 0.0095), (0.838, 0.850), TEAL)
    ext(b, (tx - 0.04, tx + 0.04), (hook_y - 0.0035, hook_y - 0.003), (0.72, 0.73), AMBER)

    # Backsplash socket and HOT legend.
    ext(b, (0.38, 0.45), (0.266, 0.272), (0.74, 0.81), DARK, 0.0025)
    for z in (0.760, 0.790):
        b.cyl(0.0105, 0.002, (0.415, 0.2655, z), METAL, axis="y", sides=10)
        ext(b, (0.409, 0.412), (0.2650, 0.2662), (z - 0.004, z + 0.004), STEEL)
        ext(b, (0.418, 0.421), (0.2650, 0.2662), (z - 0.004, z + 0.004), STEEL)
    ext(b, (0.09, 0.165), (0.2705, 0.272), (0.770, 0.800), AMBER)
    text(b, "HOT", 0.1275, 0.785, 0.013, 0.2705, DARK)

    # Sink: opening bordered by a steel bead, basin walls, floor, drain, overflow slot.
    sx0, sx1, sy0, sy1 = -0.53, -0.15, -0.22, 0.055
    ring_xy(b, (sx0 - 0.014, sx1 + 0.014), (sy0 - 0.014, sy1 + 0.014), (top, top + 0.003), 0.014, STEEL)
    ext(b, (sx0, sx0 + 0.004), (sy0, sy1), (0.535, top), METAL)
    ext(b, (sx1 - 0.004, sx1), (sy0, sy1), (0.535, top), METAL)
    ext(b, (sx0 + 0.004, sx1 - 0.004), (sy0, sy0 + 0.004), (0.535, top), METAL)
    ext(b, (sx0 + 0.004, sx1 - 0.004), (sy1 - 0.004, sy1), (0.535, top), METAL)
    ext(b, (sx0 + 0.004, sx1 - 0.004), (sy0 + 0.004, sy1 - 0.004), (0.531, 0.539), METAL, 0.0015)
    dx, dy = -0.34, -0.08
    b.cyl(0.034, 0.002, (dx, dy, 0.540), STEEL, sides=12)
    b.cyl(0.027, 0.0025, (dx, dy, 0.5405), DARK, sides=12)
    b.cyl(0.022, 0.004, (dx, dy, 0.5415), STEEL, sides=12)
    for k in range(3):
        b.box((0.032, 0.0032, 0.0006), (dx, dy, 0.5438), DARK, rot=(0, 0, k * 60))
    ext(b, (-0.46, -0.42), (sy1 - 0.0045, sy1 - 0.004), (0.64, 0.65), DARK)
    for k in range(7):  # drainboard grooves between sink and hobs
        ext(b, (-0.134 + k * 0.018, -0.130 + k * 0.018), (-0.20, 0.03), (top, top + 0.0007), DARK)

    # Tap: base, column, swivel spout with aerator, hot/cold levers.
    tx, ty = -0.34, 0.13
    b.cyl(0.027, 0.012, (tx, ty, top + 0.006), STEEL, sides=12, bevel=0.002)
    b.cyl(0.0145, 0.105, (tx, ty, top + 0.0645), STEEL, sides=10)
    b.cyl(0.0185, 0.014, (tx, ty, top + 0.122), METAL, sides=10)
    b.cyl(0.0085, 0.155, (tx, ty - 0.058, top + 0.122), STEEL, axis="y", sides=8)
    b.cyl(0.0105, 0.028, (tx, ty - 0.1225, top + 0.108), STEEL, sides=8)
    b.cyl(0.0125, 0.006, (tx, ty - 0.1225, top + 0.092), DARK, sides=8)
    for side, cap in ((-1, AMBER), (1, TEAL)):
        b.cyl(0.0042, 0.045, (tx + side * 0.032, ty, top + 0.075), STEEL, axis="x", sides=6)
        ext(b, (tx + side * 0.052, tx + side * 0.064), (ty - 0.008, ty + 0.008), (top + 0.069, top + 0.081), cap)

    # Hobs: steel trim, dark glass, concentric rings, hazard outline, heat indicator.
    for cx, cy in ((0.12, -0.05), (0.37, -0.05)):
        ring_xy(b, (cx - 0.12, cx + 0.12), (cy - 0.12, cy + 0.12), (top, top + 0.0006), 0.003, AMBER)
        ring_xy(b, (cx - 0.113, cx + 0.113), (cy - 0.113, cy + 0.113), (top, top + 0.0035), 0.006, STEEL)
        ext(b, (cx - 0.107, cx + 0.107), (cy - 0.107, cy + 0.107), (top, top + 0.0033), DARK)
        for r_outer, r_inner in ((0.082, 0.074), (0.050, 0.044)):
            b.cyl(r_outer, 0.0006, (cx, cy, top + 0.0036), METAL, sides=16)
            b.cyl(r_inner, 0.0008, (cx, cy, top + 0.0036), DARK, sides=16)
        b.cyl(0.0042, 0.002, (cx - 0.088, cy - 0.088, top + 0.0044), LAMP_AMBER, sides=8)

    # Rear: service hatch, supply pipes with colour bands, drain, power conduit and junction box.
    ext(b, (-0.43, -0.03), (0.285, 0.2895), (0.20, 0.55), METAL, 0.002)
    for x in (-0.41, -0.23, -0.05):
        for z in (0.22, 0.53):
            hex_bolt(b, (x, 0.2895, z), STEEL, axis="y", radius=0.0045, height=0.0018)
    ext(b, (-0.40, -0.34), (0.2895, 0.2905), (0.50, 0.52), AMBER)
    for z in (0.26, 0.49):
        b.cyl(0.0085, 0.004, (-0.065, 0.2915, z), STEEL, axis="y", sides=8)
        ext(b, (-0.0715, -0.0585), (0.2935, 0.2955), (z - 0.0015, z + 0.0015), DARK)
    for x, band in ((-0.372, AMBER), (-0.345, TEAL)):
        b.cyl(0.0068, 0.118, (x, 0.2915, 0.609), STEEL, sides=8)
        b.cyl(0.0085, 0.010, (x, 0.2915, 0.640), band, sides=8)
        ext(b, (x - 0.009, x + 0.009), (0.285, 0.2915), (0.585, 0.595), DARK)
    b.cyl(0.010, 0.54, (-0.465, 0.2905, 0.35), DARK, sides=8)
    b.cyl(0.0078, 0.45, (0.35, 0.2905, 0.34), RUBBER, sides=8)
    for z in (0.20, 0.36, 0.48):
        ext(b, (0.341, 0.359), (0.285, 0.2925), (z - 0.005, z + 0.005), DARK)
    ext(b, (0.31, 0.39), (0.285, 0.2975), (0.56, 0.62), METAL, 0.002)
    ext(b, (0.322, 0.378), (0.2975, 0.2985), (0.572, 0.608), STEEL)
    for x in (0.318, 0.382):
        for z in (0.565, 0.615):
            hex_bolt(b, (x, 0.2975, z), STEEL, axis="y", radius=0.0033, height=0.0015)

    root = b.build()
    kit.check_bounds(root, *kit.REFERENCE_BOUNDS["hw_galley_unit"])
    return root


def main() -> None:
    wanted = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, build, path in (("galley", build_galley, "props/hw_galley_unit.glb"), ("breaker", build_breaker, "machinery/hw_breaker_cabinet.glb")):
        if wanted and name not in wanted:
            continue
        kit.reset()
        root = build()
        low, high = kit.bounds(root)
        print(f"BUILT {root.name}: {kit.triangles(root)} tris, bounds {tuple(round(v, 4) for v in low)} .. {tuple(round(v, 4) for v in high)}")
        kit.export(root, path)


main()
