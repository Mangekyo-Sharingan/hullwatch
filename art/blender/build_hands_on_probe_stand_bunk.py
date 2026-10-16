"""Probe, manual stand and bunk models of the hands-on pass (see hw_kit.py).

Run headless from the repo root (writes game/assets/models/hullwatch/interior/hw_{probe,manual_stand,bunk}.glb):
    blender --background --factory-startup --python art/blender/build_hands_on_probe_stand_bunk.py
    blender --background --factory-startup --python art/blender/build_hands_on_probe_stand_bunk.py -- stand
(`probe`, `stand` and `bunk` select what to build.) Set HW_MODELS_DIR to redirect output while iterating.
None of the three models is animated.

Every model keeps the footprint of the one it replaces (hw_kit.REFERENCE_BOUNDS), including the
old orientation: the probe is a wall unit with its back at Y=0 and its face toward -Y, the manual
stand's sloped deck rises toward -Y (its pages face +Y) and the bunk's head end is at -Y.

Printed marks (lettering, ticks, seams, hazard slashes) are one-sided quads ("decals") a fraction of
a millimetre above their surface, so small graphics cost two triangles instead of twelve.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import hw_kit as kit  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

MIN_BEVEL = 0.0025   # chamfers smaller than this are invisible at arm's length and only cost triangles
LIFT = 0.0004        # decal height above the surface it is printed on


def span(b: kit.Builder, xr, yr, zr, mat: str, bevel: float = 0.0, part: str = "", rot=None) -> None:
    """Box from min/max extents on each axis."""
    size = (xr[1] - xr[0], yr[1] - yr[0], zr[1] - zr[0])
    centre = ((xr[0] + xr[1]) / 2, (yr[0] + yr[1]) / 2, (zr[0] + zr[1]) / 2)
    b.box(size, centre, mat, bevel=bevel if bevel >= MIN_BEVEL else 0.0, part=part, rot=rot)


def poly_decal(b: kit.Builder, mat: str, points, normal, part: str = "") -> None:
    """One-sided polygon wound so it faces `normal` (the builder keeps the winding of open faces)."""
    pts = [Vector(p) for p in points]
    area = Vector((0.0, 0.0, 0.0))
    for i in range(len(pts)):
        area += pts[i].cross(pts[(i + 1) % len(pts)])
    if area.dot(Vector(normal)) < 0:
        pts.reverse()
    bm = bmesh.new()
    bm.faces.new([bm.verts.new(p) for p in pts])
    b.add_mesh(bm, part, mat, None, (0.0, 0.0, 0.0))


def rect_decal(b: kit.Builder, mat: str, centre, ex, ey, hx: float, hy: float, normal, part: str = "") -> None:
    c, ex, ey = Vector(centre), Vector(ex), Vector(ey)
    poly_decal(b, mat, [c - ex * hx - ey * hy, c + ex * hx - ey * hy, c + ex * hx + ey * hy, c - ex * hx + ey * hy], normal, part)


def decal_xz(b: kit.Builder, mat: str, xr, zr, y: float, facing: int, part: str = "") -> None:
    """Axis-aligned decal on a plane of constant y; facing -1 shows toward -Y, +1 toward +Y."""
    rect_decal(b, mat, ((xr[0] + xr[1]) / 2, y, (zr[0] + zr[1]) / 2), (1, 0, 0), (0, 0, 1),
               (xr[1] - xr[0]) / 2, (zr[1] - zr[0]) / 2, (0, facing, 0), part)


def decal_xy(b: kit.Builder, mat: str, xr, yr, z: float, part: str = "") -> None:
    """Axis-aligned decal on a horizontal plane facing up."""
    rect_decal(b, mat, ((xr[0] + xr[1]) / 2, (yr[0] + yr[1]) / 2, z), (1, 0, 0), (0, 1, 0),
               (xr[1] - xr[0]) / 2, (yr[1] - yr[0]) / 2, (0, 0, 1), part)


# ====================================================================================== probe
def build_probe() -> bpy.types.Object:
    b = kit.Builder("hw_probe")
    pf = -0.0415   # front of the dark face panel
    pz = 0.060     # jack row height

    # Mounting flange, housing and dark face panel with corner screws.
    span(b, (-0.11, 0.11), (-0.012, 0.0), (0.0, 0.28), "hw_metal", 0.003)
    for sx in (-1, 1):
        for z in (0.03, 0.25):
            b.bolt((sx * 0.100, -0.012, z), "hw_steel", axis="-y", radius=0.0042, height=0.003)
    span(b, (-0.09, 0.09), (-0.040, -0.012), (0.012, 0.268), "hw_metal", 0.004)
    span(b, (-0.082, 0.082), (-0.0415, -0.0395), (0.02, 0.26), "hw_dark")
    for sx in (-1, 1):
        for z in (0.0275, 0.2525):
            b.bolt((sx * 0.0745, pf, z), "hw_steel", axis="-y", radius=0.0033, height=0.0016)

    # Label strip: beige plate with block lettering, and an amber warning plate.
    span(b, (-0.074, 0.030), (-0.0425, pf), (0.236, 0.254), "hw_beige")
    x = -0.068
    for w in (0.010, 0.004, 0.012, 0.004, 0.006, 0.006, 0.004, 0.014, 0.004, 0.010):
        decal_xz(b, "hw_dark", (x, x + w), (0.2405, 0.2495), -0.0425 - LIFT, -1)
        x += w + 0.0025
    span(b, (0.046, 0.074), (-0.0425, pf), (0.2345, 0.2545), "hw_hazard_amber")
    poly_decal(b, "hw_dark", [(0.0505, -0.0429, 0.2375), (0.0695, -0.0429, 0.2375), (0.0600, -0.0429, 0.2520)], (0, -1, 0))
    decal_xz(b, "hw_hazard_amber", (0.0591, 0.0609), (0.2420, 0.2485), -0.0429 - LIFT, -1)
    decal_xz(b, "hw_hazard_amber", (0.0591, 0.0609), (0.2392, 0.2410), -0.0429 - LIFT, -1)

    # Recessed bezel: four frame bars round a recessed lit display with a bar graph.
    for xr, zr in (((-0.075, 0.075), (0.219, 0.228)), ((-0.075, 0.075), (0.132, 0.144)),
                   ((-0.075, -0.066), (0.144, 0.219)), ((0.066, 0.075), (0.144, 0.219))):
        span(b, xr, (-0.052, pf), zr, "hw_steel")
    span(b, (-0.066, 0.066), (-0.0468, -0.0440), (0.144, 0.219), "hw_phosphor_green", part="screen")
    ys = -0.0468 - LIFT
    for i, h in enumerate((0.012, 0.020, 0.015, 0.030, 0.024, 0.040, 0.034, 0.028, 0.045, 0.022, 0.016)):
        x0 = -0.0565 + i * 0.0105
        decal_xz(b, "hw_dark", (x0, x0 + 0.0058), (0.1495, 0.1495 + h), ys, -1)
    for z in (0.1745, 0.1965):
        for i in range(9):
            decal_xz(b, "hw_dark", (-0.0585 + i * 0.0135, -0.0540 + i * 0.0135), (z, z + 0.0008), ys, -1)
    x = -0.059
    for w in (0.012, 0.007, 0.016, 0.005, 0.010):
        decal_xz(b, "hw_dark", (x, x + w), (0.2085, 0.2135), ys, -1)
        x += w + 0.003
    for i in range(13):
        tall = i % 3 == 0
        decal_xz(b, "hw_beige", (-0.0607 + i * 0.010, -0.0593 + i * 0.010), (0.1380 - (0.0032 if tall else 0.0019), 0.1380 + (0.0032 if tall else 0.0019)),
                 -0.052 - LIFT, -1)

    # Status lamps: one steady, one amber, one dark.
    for x, glass in ((-0.038, "hw_phosphor_green"), (0.0, "hw_phosphor_amber"), (0.038, "hw_dark")):
        b.cyl(0.0068, 0.002, (x, -0.0425, 0.108), "hw_steel", axis="y", sides=8)
        b.cyl(0.0045, 0.0034, (x, -0.0437, 0.108), glass, axis="y", sides=8)

    # Two armoured jacks (knurled colour collar, steel shroud, insulator, contact pin) plus caps on tethers.
    for sx, collar in ((-1, "hw_hazard_amber"), (1, "hw_teal")):
        x = sx * 0.050
        span(b, (x - 0.017, x + 0.017), (-0.0432, -0.0422), (0.0860, 0.0930), "hw_beige")
        for i in range(3):
            w = 0.007 if i != 1 else 0.004
            decal_xz(b, "hw_dark", (x - 0.009 + i * 0.009 - w / 2, x - 0.009 + i * 0.009 + w / 2), (0.0885, 0.0905), -0.0432 - LIFT, -1)
        b.cyl(0.0185, 0.003, (x, -0.043, pz), "hw_steel", axis="y", sides=8)
        b.fluted(0.0158, 0.0055, (x, -0.0485, pz), collar, flutes=9, depth=0.0013, axis="y")
        b.cyl(0.0125, 0.0113, (x, -0.0569, pz), "hw_steel", axis="y", sides=10)
        b.cyl(0.0090, 0.0020, (x, -0.0630, pz), "hw_dark", axis="y", sides=10)
        b.cyl(0.0032, 0.0020, (x, -0.0640, pz), "hw_steel", axis="y", sides=8)
        # Cap hanging from an eyelet screw beside the jack.
        cx = sx * 0.083
        b.cyl(0.0036, 0.0030, (cx, -0.0430, 0.094), "hw_steel", axis="y", sides=6)
        b.box((0.0025, 0.0015, 0.0235), (cx, -0.0437, 0.08225), "hw_rubber")
        b.fluted(0.0085, 0.0090, (cx, -0.0460, 0.062), "hw_rubber", flutes=7, depth=0.0014, axis="y")
        b.cyl(0.0062, 0.0014, (cx, -0.0513, 0.062), "hw_dark", axis="y", sides=8)

    # Vent plates either side of the toggle.
    for sx in (-1, 1):
        span(b, (sx * 0.0875 - 0.0135, sx * 0.0875 + 0.0135), (-0.0426, pf), (0.018, 0.040), "hw_metal")
        for i in range(6):
            x0 = sx * 0.0875 - 0.0116 + i * 0.0042
            decal_xz(b, "hw_rubber", (x0, x0 + 0.0022), (0.0205, 0.0375), -0.0426 - LIFT, -1)

    # Guarded toggle: steel lever with rubber tip under an amber bridge guard with hazard slashes.
    b.cyl(0.0085, 0.0035, (0.0, -0.0433, 0.030), "hw_steel", axis="y", sides=6)
    tilt = math.radians(12)
    d = Vector((0.0, -math.cos(tilt), math.sin(tilt)))
    base = Vector((0.0, -0.0450, 0.030))
    b.cyl(0.0033, 0.012, base + d * 0.006, "hw_steel", axis="y", sides=8, rot=(-12, 0, 0))
    b.cyl(0.0050, 0.0075, base + d * 0.0125, "hw_rubber", axis="y", sides=8, rot=(-12, 0, 0))
    for sx in (-1, 1):
        span(b, (sx * 0.0140 - 0.0015, sx * 0.0140 + 0.0015), (-0.0600, pf), (0.012, 0.047), "hw_hazard_amber")
        b.bolt((sx * 0.0155, -0.0485, 0.030), "hw_steel", axis="x" if sx > 0 else "-x", radius=0.0025, height=0.0012)
    span(b, (-0.0155, 0.0155), (-0.0600, pf), (0.0435, 0.0475), "hw_hazard_amber")
    c45, s45 = math.cos(math.radians(45)), math.sin(math.radians(45))
    for y in (-0.0470, -0.0535):
        rect_decal(b, "hw_dark", (0.0, y, 0.0475 + LIFT), (c45, s45, 0), (-s45, c45, 0), 0.0050, 0.0018, (0, 0, 1))

    # Cable gland on the housing underside and a conduit elbow running back into the wall.
    b.cyl(0.0075, 0.0105, (0.060, -0.026, 0.0065), "hw_steel", axis="z", sides=6)
    b.cyl(0.0058, 0.0070, (0.060, -0.026, -0.0023), "hw_rubber", axis="z", sides=8)
    b.cyl(0.0055, 0.0270, (0.060, -0.0165, -0.0045), "hw_rubber", axis="y", sides=8)
    b.cyl(0.0060, 0.0020, (0.060, -0.0035, -0.0045), "hw_steel", axis="y", sides=8)
    # Breather plug on the housing top.
    b.cyl(0.0065, 0.0050, (-0.055, -0.026, 0.2705), "hw_steel", axis="z", sides=6)
    b.cyl(0.0042, 0.0045, (-0.055, -0.026, 0.2755), "hw_rubber", axis="z", sides=8)

    root = b.build()
    kit.check_bounds(root, *kit.REFERENCE_BOUNDS["hw_probe"])
    return root


# ======================================================================================= stand
THETA = math.radians(26.0)          # deck slope: the surface rises toward -Y, pages face +Y
DECK_ORIGIN = (0.0, 0.03, 1.018)    # centre of the page-resting surface
DECK_UNDER = 0.026                  # thickness of the deck plates
LAMP_STEM = 0.033                   # book-light stem length; sets the model's highest point


def deck_under(y: float) -> float:
    """World height of the deck underside at world y."""
    s = (y - DECK_ORIGIN[1] + DECK_UNDER * math.sin(THETA)) / math.cos(THETA)
    return DECK_ORIGIN[2] - s * math.sin(THETA) - DECK_UNDER * math.cos(THETA)


class Deck:
    """Places primitives in deck coordinates: u across, s down the slope toward the reader,
    w along the surface normal (w=0 is the page-resting surface)."""

    def __init__(self, b: kit.Builder) -> None:
        self.b = b
        self.o = Vector(DECK_ORIGIN)
        self.r = Euler((-THETA, 0.0, 0.0)).to_matrix()

    def at(self, u, s, w) -> Vector:
        return self.o + self.r @ Vector((u, s, w))

    def _rot(self, rot):
        local = Euler(tuple(math.radians(a) for a in rot)).to_matrix() if rot else Matrix.Identity(3)
        return tuple(math.degrees(a) for a in (self.r @ local).to_euler("XYZ"))

    def box(self, size, centre, mat, bevel=0.0, part="", rot=None) -> None:
        self.b.box(size, self.at(*centre), mat, bevel=bevel if bevel >= MIN_BEVEL else 0.0, part=part, rot=self._rot(rot))

    def span(self, ur, sr, wr, mat, bevel=0.0, part="", rot=None) -> None:
        self.box((ur[1] - ur[0], sr[1] - sr[0], wr[1] - wr[0]),
                 ((ur[0] + ur[1]) / 2, (sr[0] + sr[1]) / 2, (wr[0] + wr[1]) / 2), mat, bevel, part, rot)

    def cyl(self, radius, length, centre, mat, axis="z", sides=12, radius2=None, part="", rot=None) -> None:
        self.b.cyl(radius, length, self.at(*centre), mat, axis=axis, sides=sides, radius2=radius2,
                   part=part, rot=self._rot(rot))

    def bolt(self, centre, mat, radius=0.005, height=0.003) -> None:
        self.cyl(radius, height, (centre[0], centre[1], centre[2] + height / 2), mat, sides=6)

    def decal(self, mat, ur, sr, w, angle=0.0, part="") -> None:
        """Printed rectangle on the surface at height w; `angle` rotates it about the normal (deg)."""
        a = math.radians(angle)
        ex = self.r @ Vector((math.cos(a), math.sin(a), 0.0))
        ey = self.r @ Vector((-math.sin(a), math.cos(a), 0.0))
        rect_decal(self.b, mat, self.at((ur[0] + ur[1]) / 2, (sr[0] + sr[1]) / 2, w + LIFT), ex, ey,
                   (ur[1] - ur[0]) / 2, (sr[1] - sr[0]) / 2, self.r @ Vector((0.0, 0.0, 1.0)), part)


LINES_L = (0.19, 0.185, 0.15, 0.19, 0.17, 0.185, 0.12, 0.19, 0.18)
LINES_R = (0.17, 0.15, 0.17, 0.12, 0.17, 0.15, 0.17, 0.13, 0.16)


def build_stand() -> bpy.types.Object:
    b = kit.Builder("hw_manual_stand")
    d = Deck(b)

    # Heavy base: lower plate, stepped ballast tier, levelling feet, bolts and hazard slashes on the rim.
    span(b, (-0.25, 0.25), (-0.25, 0.25), (0.014, 0.044), "hw_metal", 0.010)
    span(b, (-0.21, 0.21), (-0.21, 0.21), (0.044, 0.064), "hw_dark", 0.008)
    for sx in (-1, 1):
        for sy in (-1, 1):
            fx, fy = sx * 0.205, sy * 0.205
            b.cyl(0.024, 0.007, (fx, fy, 0.0035), "hw_rubber", sides=10)
            b.cyl(0.0085, 0.008, (fx, fy, 0.011), "hw_steel", sides=8)
    c45 = math.cos(math.radians(45))
    for k in range(7):
        t = -0.075 + k * 0.025
        for sgn in (-1, 1):
            rect_decal(b, "hw_hazard_amber", (t, sgn * 0.2275, 0.0444 + LIFT), (c45, c45, 0), (-c45, c45, 0), 0.0032, 0.0135, (0, 0, 1))
            rect_decal(b, "hw_hazard_amber", (sgn * 0.2275, t, 0.0444 + LIFT), (c45, c45, 0), (-c45, c45, 0), 0.0032, 0.0135, (0, 0, 1))
    for x, y in ((-0.17, -0.17), (0.17, -0.17), (-0.17, 0.17), (0.17, 0.17), (-0.17, 0.0), (0.17, 0.0)):
        b.bolt((x, y, 0.064), "hw_steel", axis="z", radius=0.0085, height=0.005)

    # Post collar with welded gussets, the square post, panels, cable channel, clips and label plate.
    span(b, (-0.085, 0.085), (-0.085, 0.085), (0.064, 0.078), "hw_metal", 0.004)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.bolt((sx * 0.0725, sy * 0.0725, 0.078), "hw_steel", axis="z", radius=0.0055, height=0.004)
    for s in (-1, 1):
        tri = [(s * 0.060, 0.078), (s * 0.115, 0.078), (s * 0.060, 0.170)]
        b.prism(tri, 0.014, (0.0, 0.0, 0.0), "hw_metal", plane="yz")
        b.prism(tri, 0.014, (0.0, 0.0, 0.0), "hw_metal", plane="xz")
    span(b, (-0.06, 0.06), (-0.06, 0.06), (0.078, 0.92), "hw_dark", 0.007)
    for sx in (-1, 1):   # long stiffener strips on the side faces
        span(b, (sx * 0.0592, sx * 0.0612) if sx > 0 else (sx * 0.0612, sx * 0.0592), (-0.014, 0.014), (0.12, 0.82), "hw_metal")
    # reader side (+Y): vent grille plate and an inspection panel with four bolts
    span(b, (-0.042, 0.042), (0.060, 0.0625), (0.13, 0.26), "hw_metal", 0.003)
    for i in range(6):
        z0 = 0.142 + i * 0.019
        decal_xz(b, "hw_rubber", (-0.032, 0.032), (z0, z0 + 0.008), 0.0625 + LIFT, 1)
    span(b, (-0.042, 0.042), (0.060, 0.0625), (0.40, 0.58), "hw_metal", 0.003)
    for sx in (-1, 1):
        for z in (0.415, 0.565):
            b.bolt((sx * 0.032, 0.0625, z), "hw_steel", axis="y", radius=0.0045, height=0.003)
    decal_xz(b, "hw_dark", (-0.026, 0.026), (0.476, 0.504), 0.0625 + LIFT, 1)
    # cable channel on the -Y face with clamp bands, entering the base through a gland
    span(b, (-0.05, -0.02), (-0.072, -0.06), (0.09, 0.90), "hw_metal", 0.003)
    decal_xz(b, "hw_dark", (-0.0365, -0.0335), (0.10, 0.89), -0.072 - LIFT, -1)
    for z in (0.18, 0.38, 0.58, 0.88):
        span(b, (-0.0535, -0.0165), (-0.0745, -0.0595), (z - 0.006, z + 0.006), "hw_steel", 0.003)
    b.cyl(0.012, 0.028, (-0.035, -0.066, 0.078), "hw_steel", sides=6)
    # amber label plate with lettering bars and hazard slashes
    span(b, (0.004, 0.054), (-0.0635, -0.06), (0.74, 0.85), "hw_hazard_amber")
    yl = -0.0635 - LIFT
    decal_xz(b, "hw_dark", (0.010, 0.046), (0.826, 0.834), yl, -1)
    decal_xz(b, "hw_dark", (0.010, 0.038), (0.811, 0.819), yl, -1)
    decal_xz(b, "hw_dark", (0.010, 0.030), (0.796, 0.804), yl, -1)
    for i in range(5):
        rect_decal(b, "hw_dark", (0.014 + i * 0.0095, yl, 0.764), (c45, 0, c45), (-c45, 0, c45), 0.0018, 0.0115, (0, -1, 0))

    # Tilt bracket: head block, two web plates up to the deck underside, pivot axle and lock knob.
    span(b, (-0.09, 0.09), (-0.07, 0.07), (0.92, 0.95), "hw_metal", 0.004)
    for sx in (-1, 1):
        web = [(-0.056, 0.949), (0.056, 0.949), (0.056, deck_under(0.056) + 0.002), (-0.056, deck_under(-0.056) + 0.002)]
        b.prism(web, 0.012, (sx * 0.052, 0.0, 0.0), "hw_metal", plane="yz")
    b.cyl(0.0095, 0.172, (0.0, 0.0, 0.985), "hw_steel", axis="x", sides=10)
    for sx in (-1, 1):
        b.cyl(0.0125, 0.005, (sx * 0.0875, 0.0, 0.985), "hw_steel", axis="x", sides=6)
    arc = [(0.052 * math.cos(math.radians(a)), 0.985 + 0.052 * math.sin(math.radians(a))) for a in (-42, -30, -18, -4)]
    arc += [(0.034 * math.cos(math.radians(a)), 0.985 + 0.034 * math.sin(math.radians(a))) for a in (-4, -18, -30, -42)]
    b.prism(arc, 0.004, (0.060, 0.0, 0.0), "hw_steel", plane="yz")
    b.cyl(0.0045, 0.022, (0.069, 0.0396, 0.968), "hw_steel", axis="x", sides=8)
    b.fluted(0.0145, 0.012, (0.0725, 0.0396, 0.968), "hw_rubber", flutes=8, depth=0.0018, axis="x")

    # Deck: beige top plate over a steel sub-plate, ribs below, lip rail with hazard slashes, back rail, side rails.
    d.span((-0.275, 0.275), (-0.21, 0.21), (-0.020, 0.0), "hw_beige", 0.006)
    d.span((-0.268, 0.268), (-0.203, 0.203), (-DECK_UNDER, -0.020), "hw_metal", 0.003)
    for u in (-0.20, -0.12, 0.12, 0.20):
        d.span((u - 0.006, u + 0.006), (-0.19, 0.19), (-0.042, -DECK_UNDER), "hw_metal")
    d.span((-0.262, 0.262), (0.09, 0.102), (-0.036, -DECK_UNDER), "hw_metal")
    d.span((-0.275, 0.275), (0.18, 0.21), (0.0, 0.026), "hw_metal", 0.004)
    d.span((-0.275, 0.275), (-0.21, -0.185), (0.0, 0.014), "hw_metal", 0.003)
    for sx in (-1, 1):
        d.span((min(sx * 0.263, sx * 0.275), max(sx * 0.263, sx * 0.275)), (-0.185, 0.18), (0.0, 0.012), "hw_metal", 0.003)
    for k in range(9):
        u = -0.20 + 0.05 * k
        d.decal("hw_hazard_amber", (u - 0.0032, u + 0.0032), (0.1945 - 0.0105, 0.1945 + 0.0105), 0.026, angle=45.0)

    # Open binder: covers, spine strip, ring mechanism, page stacks with text, ribbon and index tabs.
    p0 = 0.004
    d.span((-0.258, -0.012), (-0.178, 0.178), (0.0, p0), "hw_teal", 0.003)
    d.span((0.012, 0.258), (-0.178, 0.178), (0.0, p0), "hw_teal", 0.003)
    d.span((-0.012, 0.012), (-0.178, 0.178), (0.0, p0), "hw_dark")
    for i in range(3):
        d.span((-0.240 + 0.0015 * i, -0.024), (-0.160 + 0.0015 * i, 0.160 - 0.0015 * i), (p0 + 0.006 * i, p0 + 0.006 * (i + 1)), "hw_beige")
    for i in range(2):
        d.span((0.024, 0.240 - 0.0015 * i), (-0.160 + 0.0015 * i, 0.160 - 0.0015 * i), (p0 + 0.006 * i, p0 + 0.006 * (i + 1)), "hw_beige")
    topl, topr = p0 + 0.018, p0 + 0.012
    # The reader stands on the +Y side, so the u>0 page is on their left: text is left-aligned there at
    # the high-u edge of each page. Left (reader's right) page: heading, text lines, a small schematic.
    d.decal("hw_dark", (-0.154, -0.034), (-0.145, -0.136), topl)
    for i, ln in enumerate(LINES_L):
        s = -0.120 + i * 0.0205
        d.decal("hw_dark", (-0.034 - ln, -0.034), (s, s + 0.0030), topl)
    for u0, u1, s0, s1 in ((-0.224, -0.072, 0.072, 0.075), (-0.224, -0.072, 0.128, 0.131), (-0.224, -0.221, 0.072, 0.131), (-0.075, -0.072, 0.072, 0.131)):
        d.decal("hw_dark", (u0, u1), (s0, s1), topl)
    d.decal("hw_dark", (-0.208, -0.178), (0.086, 0.116), topl)
    d.decal("hw_dark", (-0.140, -0.100), (0.086, 0.116), topl)
    d.decal("hw_dark", (-0.178, -0.140), (0.0995, 0.1025), topl)
    # Right (reader's left) page: heading, bulleted lines and an amber caution box.
    d.decal("hw_dark", (0.108, 0.228), (-0.145, -0.136), topr)
    for i, ln in enumerate(LINES_R):
        s = -0.120 + i * 0.0205
        d.decal("hw_dark", (0.2325, 0.2365), (s - 0.0005, s + 0.0035), topr)
        d.decal("hw_dark", (0.228 - ln, 0.228), (s, s + 0.0030), topr)
    d.decal("hw_hazard_amber", (0.044, 0.226), (0.070, 0.132), topr)
    d.decal("hw_dark", (0.130, 0.214), (0.080, 0.085), topr + 0.0006)
    d.decal("hw_dark", (0.064, 0.214), (0.095, 0.098), topr + 0.0006)
    d.decal("hw_dark", (0.088, 0.214), (0.106, 0.109), topr + 0.0006)
    d.decal("hw_dark", (0.136, 0.214), (0.117, 0.120), topr + 0.0006)
    d.decal("hw_hazard_amber", (0.0275, 0.0335), (-0.130, 0.160), topr)   # ribbon marker
    for s, mat in ((-0.100, "hw_hazard_amber"), (-0.030, "hw_teal"), (0.040, "hw_metal")):
        d.span((-0.2535, -0.236), (s, s + 0.030), (p0 + 0.004, p0 + 0.0075), mat)
    d.span((-0.012, 0.012), (-0.150, 0.150), (p0, p0 + 0.005), "hw_steel")
    for s in (-0.115, -0.04, 0.04, 0.115):
        radius, n = 0.026, 4
        for k in range(n):
            phi = 180.0 * (k + 0.5) / n
            r = math.radians(phi)
            d.box((0.0185, 0.0034, 0.0034), (radius * math.cos(r), s, p0 + 0.002 + radius * math.sin(r)), "hw_steel", rot=(0, -(phi + 90.0), 0))
    # Page-hold bars on posts at the rail, pressing each page near its bottom margin.
    for sx, top in ((-1, topl), (1, topr)):
        post_u = sx * 0.2565
        d.span((post_u - 0.006, post_u + 0.006), (0.143, 0.157), (0.0, top + 0.009), "hw_steel")
        lo, hi = sorted((sx * 0.05, post_u))
        d.span((lo, hi), (0.146, 0.154), (top + 0.003, top + 0.007), "hw_steel")
        pad = sx * 0.056
        d.span((pad - 0.006, pad + 0.006), (0.145, 0.155), (top + 0.0015, top + 0.003), "hw_rubber")

    # Book light clipped on the back rail; its head defines the model's highest point.
    d.span((-0.215, -0.185), (-0.2145, -0.1805), (-0.002, 0.019), "hw_metal", 0.003)
    d.cyl(0.0045, LAMP_STEM, (-0.20, -0.198, 0.019 + LAMP_STEM / 2), "hw_steel", sides=8)
    top = 0.019 + LAMP_STEM
    d.cyl(0.0065, 0.016, (-0.20, -0.198, top), "hw_steel", axis="x", sides=8)
    d.box((0.066, 0.034, 0.012), (-0.20, -0.180, top + 0.001), "hw_dark", bevel=0.003, rot=(14, 0, 0))
    d.box((0.056, 0.024, 0.0016), (-0.20, -0.178, top - 0.0053), "hw_phosphor_amber", rot=(14, 0, 0))

    root = b.build()
    kit.check_bounds(root, *kit.REFERENCE_BOUNDS["hw_manual_stand"])
    return root


# ======================================================================================== bunk
def build_bunk() -> bpy.types.Object:
    b = kit.Builder("hw_bunk")
    hx, hy = 0.475, 0.975

    # Welded frame: four posts on rubber pads (headboard posts reach 0.70, footboard 0.60).
    for sx in (-1, 1):
        for sy in (-1, 1):
            top = 0.70 if sy < 0 else 0.60
            span(b, (sx * hx - 0.025, sx * hx + 0.025), (sy * hy - 0.025, sy * hy + 0.025), (0.008, top), "hw_metal", 0.006)
            b.cyl(0.022, 0.008, (sx * hx, sy * hy, 0.004), "hw_rubber", sides=10)
        lo, hi = sorted((sx * 0.46, sx * 0.494))
        span(b, (lo, hi), (-0.95, 0.95), (0.25, 0.34), "hw_metal", 0.005)
        lo, hi = sorted((sx * 0.44, sx * 0.46))
        span(b, (lo, hi), (-0.95, 0.95), (0.322, 0.34), "hw_metal")
        for sy in (-1, 1):   # gussets under the side rail, welded to the post
            tri = [(sy * 0.95, 0.25), (sy * 0.86, 0.25), (sy * 0.95, 0.15)]
            b.prism(tri, 0.012, (sx * hx, 0.0, 0.0), "hw_metal", plane="yz")
        b.cyl(0.011, 1.90, (sx * hx, 0.0, 0.14), "hw_steel", axis="y", sides=8)
        for k in range(7):   # stamped slots along the outside of the side rail
            rect_decal(b, "hw_rubber", (sx * (0.494 + LIFT), -0.60 + k * 0.20, 0.295), (0, 1, 0), (0, 0, 1), 0.060, 0.012, (sx, 0, 0))
    for k in range(9):
        yc = -0.80 + 0.2 * k
        span(b, (-0.44, 0.44), (yc - 0.03, yc + 0.03), (0.326, 0.340), "hw_metal")
    for sy in (-1, 1):
        b.cyl(0.011, 0.90, (0.0, sy * hy, 0.14), "hw_steel", axis="x", sides=8)
        tri = [(0.45, 0.25), (0.36, 0.25), (0.45, 0.15)]
        for sx in (-1, 1):
            b.prism([(sx * x, z) for x, z in tri], 0.012, (0.0, sy * 0.965, 0.0), "hw_metal", plane="xz")
    for k in range(10):   # under-bunk storage shelf slats between the low rails
        yc = -0.855 + 0.19 * k
        span(b, (-0.45, 0.45), (yc - 0.012, yc + 0.012), (0.134, 0.142), "hw_metal")

    # Headboard: end rail, tufted teal panel (steel back sheet), top rail with bolts, book net.
    span(b, (-0.45, 0.45), (-0.995, -0.955), (0.25, 0.34), "hw_metal", 0.006)
    span(b, (-0.45, 0.45), (-0.995, -0.955), (0.64, 0.70), "hw_metal", 0.006)
    span(b, (-0.44, 0.44), (-0.985, -0.958), (0.35, 0.635), "hw_teal", 0.010)
    span(b, (-0.445, 0.445), (-0.996, -0.985), (0.345, 0.64), "hw_metal", 0.003)
    for x in (-0.22, 0.0, 0.22):
        decal_xz(b, "hw_dark", (x - 0.0015, x + 0.0015), (0.36, 0.625), -0.958 + LIFT, 1)
        b.bolt((x, -0.958, 0.4925), "hw_metal", axis="y", radius=0.009, height=0.005)
    decal_xz(b, "hw_dark", (-0.43, 0.43), (0.4905, 0.4945), -0.958 + LIFT, 1)
    for x in (-0.40, -0.20, 0.0, 0.10, 0.40):
        b.bolt((x, -0.955, 0.67), "hw_steel", axis="y", radius=0.006, height=0.004)
    for x in (-0.40, -0.3333, -0.2667, -0.24):   # elastic book net on the left of the panel
        span(b, (x - 0.002, x + 0.002), (-0.9605, -0.9580), (0.385, 0.565), "hw_rubber")
    for z in (0.385, 0.475, 0.565):
        span(b, (-0.402, -0.238), (-0.9625, -0.9600), (z - 0.002, z + 0.002), "hw_rubber")
    for x in (-0.40, -0.24):
        for z in (0.385, 0.565):
            b.bolt((x, -0.9625, z), "hw_steel", axis="y", radius=0.005, height=0.003)

    # Footboard: end rail, top grab rail and a plain padded panel with a steel back sheet.
    span(b, (-0.45, 0.45), (0.955, 0.995), (0.25, 0.34), "hw_metal", 0.006)
    span(b, (-0.45, 0.45), (0.955, 0.995), (0.545, 0.60), "hw_metal", 0.006)
    span(b, (-0.44, 0.44), (0.958, 0.985), (0.35, 0.54), "hw_teal", 0.010)
    span(b, (-0.445, 0.445), (0.985, 0.996), (0.345, 0.545), "hw_metal", 0.003)
    for x in (-0.22, 0.0, 0.22):
        decal_xz(b, "hw_dark", (x - 0.0015, x + 0.0015), (0.36, 0.53), 0.958 - LIFT, -1)
        b.bolt((x, 0.958, 0.445), "hw_metal", axis="-y", radius=0.009, height=0.005)
    decal_xz(b, "hw_dark", (-0.43, 0.43), (0.4435, 0.4475), 0.958 - LIFT, -1)
    for x in (-0.40, -0.20, 0.0, 0.20, 0.40):
        b.bolt((x, 0.955, 0.572), "hw_steel", axis="-y", radius=0.006, height=0.004)

    # Reading light on the headboard rail, with its cable and clips.
    lx = 0.30
    span(b, (lx - 0.025, lx + 0.025), (-0.955, -0.947), (0.645, 0.695), "hw_metal", 0.003)
    b.cyl(0.007, 0.070, (lx, -0.912, 0.67), "hw_steel", axis="y", sides=8)
    b.cyl(0.011, 0.020, (lx, -0.877, 0.67), "hw_steel", axis="x", sides=6)
    axis = Vector((0.0, math.cos(math.radians(35)), -math.sin(math.radians(35))))
    head = Vector((lx, -0.857, 0.652))
    b.cyl(0.024, 0.040, head, "hw_dark", axis="y", sides=10, radius2=0.032, rot=(-35, 0, 0))
    b.cyl(0.027, 0.003, head + axis * 0.0205, "hw_phosphor_amber", axis="y", sides=10, rot=(-35, 0, 0))
    span(b, (lx - 0.0025, lx + 0.0025), (-0.9585, -0.9580), (0.37, 0.645), "hw_rubber")
    for z in (0.60, 0.50, 0.40):
        span(b, (lx - 0.007, lx + 0.007), (-0.9610, -0.9575), (z - 0.006, z + 0.006), "hw_steel")

    # Mattress: piping, belt seams and quilted puffs on top (none under the pillow).
    span(b, (-0.45, 0.45), (-0.945, 0.945), (0.34, 0.48), "hw_beige", 0.025)
    for sx in (-1, 1):
        b.box((0.008, 1.88, 0.008), (sx * 0.4391, 0.0, 0.4691), "hw_teal", rot=(0, sx * 45, 0))
        b.box((0.008, 1.88, 0.008), (sx * 0.4391, 0.0, 0.3509), "hw_teal", rot=(0, -sx * 45, 0))
        lo, hi = sorted((sx * 0.449, sx * 0.452))
        span(b, (lo, hi), (-0.93, 0.93), (0.405, 0.411), "hw_teal")
    for sy in (-1, 1):
        b.box((0.85, 0.008, 0.008), (0.0, sy * 0.9341, 0.4691), "hw_teal", rot=(-sy * 45, 0, 0))
        b.box((0.85, 0.008, 0.008), (0.0, sy * 0.9341, 0.3509), "hw_teal", rot=(sy * 45, 0, 0))
        lo, hi = sorted((sy * 0.944, sy * 0.947))
        span(b, (-0.43, 0.43), (lo, hi), (0.405, 0.411), "hw_teal")
    cell_x, cell_y = 0.85 / 6, 0.9 / 8
    for i in range(7):    # stitched seams in the grooves between the puffs
        x = -0.425 + cell_x * i
        decal_xy(b, "hw_teal", (x - 0.003, x + 0.003), (-0.935, -0.143), 0.48 + LIFT)
    for j in range(8):
        y = -0.935 + cell_y * j
        decal_xy(b, "hw_teal", (-0.425, 0.425), (y - 0.003, y + 0.003), 0.48 + LIFT)
    for i in range(6):
        for j in range(7):   # the eighth row is left bare under the restraint strap
            x = -0.425 + cell_x * (i + 0.5)
            y = -0.935 + cell_y * (j + 0.5)
            if abs(x) < 0.25 and -0.82 < y < -0.52:
                continue
            b.box((cell_x - 0.012, cell_y - 0.012, 0.016), (x, y, 0.486), "hw_beige", taper=(0.66, 0.66))

    # Pillow with two teal stripes and a button.
    b.box((0.60, 0.35, 0.11), (0.0, -0.68, 0.540), "hw_beige", bevel=0.03, taper=(0.90, 0.88))
    for y in (-0.62, -0.74):
        decal_xy(b, "hw_teal", (-0.22, 0.22), (y - 0.006, y + 0.006), 0.5955 + LIFT)
    b.bolt((0.0, -0.68, 0.595), "hw_teal", axis="z", radius=0.009, height=0.005)

    # Folded blanket with amber hem, drape over the sides and a few wrinkles.
    span(b, (-0.468, 0.468), (0.10, 0.875), (0.478, 0.505), "hw_teal", 0.008)
    span(b, (-0.468, 0.468), (-0.03, 0.10), (0.478, 0.522), "hw_teal", 0.008)
    decal_xy(b, "hw_hazard_amber", (-0.452, 0.452), (0.035, 0.060), 0.522 + LIFT)
    decal_xy(b, "hw_hazard_amber", (-0.452, 0.452), (0.835, 0.860), 0.505 + LIFT)
    for sx in (-1, 1):
        lo, hi = sorted((sx * 0.4525, sx * 0.4605))
        span(b, (lo, hi), (0.0, 0.87), (0.412, 0.49), "hw_teal")
        lo, hi = sorted((sx * 0.4520, sx * 0.4610))
        span(b, (lo, hi), (0.0, 0.87), (0.400, 0.412), "hw_hazard_amber")
    for x, y, ang in ((-0.2, 0.30, 12), (0.15, 0.55, -9), (-0.1, 0.75, 6)):
        b.box((0.30, 0.012, 0.006), (x, y, 0.5075), "hw_teal", bevel=0.003, rot=(0, 0, ang))

    # Restraint strap over the mattress above the blanket: webbing, buckle, tail, anchor clamps.
    sy0, sy1 = -0.135, -0.065
    span(b, (-0.425, 0.425), (sy0, sy1), (0.4800, 0.4845), "hw_hazard_amber")
    for sx in (-1, 1):
        b.box((0.0394, 0.070, 0.0045), (sx * 0.4391, -0.100, 0.4691), "hw_hazard_amber", rot=(0, sx * 45, 0))
        lo, hi = sorted((sx * 0.4505, sx * 0.4550))
        span(b, (lo, hi), (sy0, sy1), (0.362, 0.457), "hw_hazard_amber")
        lo, hi = sorted((sx * 0.4500, sx * 0.4645))
        span(b, (lo, hi), (sy0 - 0.003, sy1 + 0.003), (0.340, 0.362), "hw_steel")
        b.bolt((sx * 0.4575, -0.100, 0.362), "hw_steel", axis="z", radius=0.0045, height=0.003)
    span(b, (-0.2250, -0.2200), (-0.138, -0.062), (0.4835, 0.4905), "hw_steel")
    span(b, (-0.1800, -0.1750), (-0.138, -0.062), (0.4835, 0.4905), "hw_steel")
    for y in (-0.138, -0.062):
        span(b, (-0.225, -0.175), (y - 0.0025, y + 0.0025), (0.4835, 0.4905), "hw_steel")
    span(b, (-0.2025, -0.1975), (-0.138, -0.062), (0.4835, 0.4890), "hw_steel")
    span(b, (-0.175, -0.060), (sy0, sy1), (0.4845, 0.4870), "hw_hazard_amber")
    span(b, (-0.075, -0.052), (sy0, sy1), (0.4845, 0.4885), "hw_rubber")

    root = b.build()
    kit.check_bounds(root, *kit.REFERENCE_BOUNDS["hw_bunk"])
    return root


MODELS = {
    "probe": (build_probe, "interior/hw_probe.glb"),
    "stand": (build_stand, "interior/hw_manual_stand.glb"),
    "bunk": (build_bunk, "interior/hw_bunk.glb"),
}


def main() -> None:
    wanted = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for key in wanted or list(MODELS):
        build, path = MODELS[key]
        kit.reset()
        root = build()
        low, high = kit.bounds(root)
        print(f"BUILT {root.name}: {kit.triangles(root)} tris, bounds {tuple(round(v, 4) for v in low)} .. {tuple(round(v, 4) for v in high)}")
        kit.export(root, path)


main()
