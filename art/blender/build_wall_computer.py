"""Build the wall computer kit: wall_computer_kit.blend + the exported hw_wall_computer.glb.

Run headless from the repo root:
    blender --background --factory-startup --python art/blender/build_wall_computer.py

The piece is a wall-mounted ship computer: a chamfered case with a recessed slot the operator
reads through, and a blade module that slides out of the slot on guide rails and folds down 32
degrees on a barrel hinge to face them. The single "unfold" action runs stowed (frame 1) ->
slid out (frame 12) -> folded down (frame 24); Godot plays it forward to deploy and backwards
to stow. Authored Z-up with the wall at +Y and the front at -Y, which the glTF export maps to
Godot's +Z front.

Contracts the game depends on (see wall_computer.gd / crt_screen.gd): the animated empty is
named `module` (pivot (0, -0.06, 0.31)), it carries a single MESH named `Screen` whose origin
is the centre of the visible display (front toward -Y, phosphor-green material), and the
footprint matches hw_kit.REFERENCE_BOUNDS["hw_wall_computer"].

Authoring frames: the static shell is authored in root space; the module is authored in
module-local space (x as root, y/z offset from the pivot) and converted with M().
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hw_kit as kit  # noqa: E402

PIVOT = (0.0, -0.06, 0.31)
ACTION = "unfold"

# Module-local layout (y: front is negative; z: 0 at the hinge axis, hanging down)
W = 0.255  # module half width
Z_TOP, Z_BOT = -0.008, -0.630  # case top/bottom
Y_FRONT, Y_BACK = -0.020, 0.048  # case front/back faces
LIP_Y = -0.031  # front of the bezel lip
SCREEN_Z = -0.31  # display centre
SCREEN_HALF = (0.228, 0.198)  # glass half extents (x, z)


def M(x, y, z):
    """Module-local point -> root space (stowed pose)."""
    return (x, y + PIVOT[1], z + PIVOT[2])


# ------------------------------------------------------------------------------------------
# Local geometry helpers (the shared Builder has no hollow/octagonal sweeps or booleans)
# ------------------------------------------------------------------------------------------
def octa(a, b, c, y, zc=0.0):
    """Octagon ring (rectangle a x b half extents with corners cut by c) at height y."""
    return [
        (a, y, zc - (b - c)), (a, y, zc + (b - c)), (a - c, y, zc + b), (-(a - c), y, zc + b),
        (-a, y, zc + (b - c)), (-a, y, zc - (b - c)), (-(a - c), y, zc - b), (a - c, y, zc - b),
    ]


def sweep(secs, zc=0.0):
    """Sweep octagon rings along Y. secs: [(y, (a, b, c), (ia, ib, ic) | None)]. A None inner
    ring makes a solid with capped ends; two sections at the same y make a stepped face."""
    bm = bmesh.new()
    outer = [[bm.verts.new(p) for p in octa(*s[1], s[0], zc)] for s in secs]
    hollow = secs[0][2] is not None
    inner = [[bm.verts.new(p) for p in octa(*s[2], s[0], zc)] for s in secs] if hollow else None

    def band(r0, r1):
        for k in range(8):
            bm.faces.new([r0[k], r0[(k + 1) % 8], r1[(k + 1) % 8], r1[k]])

    for i in range(len(secs) - 1):
        band(outer[i], outer[i + 1])
        if hollow:
            band(inner[i], inner[i + 1])
    if hollow:
        band(outer[0], inner[0])
        band(outer[-1], inner[-1])
    else:
        bm.faces.new(outer[0])
        bm.faces.new(outer[-1])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def cut_box(bm, x0, x1, y0, y1, z0, z1):
    """Add a closed box to the cutter mesh `bm` (module-local extents)."""
    res = bmesh.ops.create_cube(bm, size=1.0)
    for v in res["verts"]:
        v.co = Vector(((x0 + x1) / 2 + v.co.x * (x1 - x0), (y0 + y1) / 2 + v.co.y * (y1 - y0), (z0 + z1) / 2 + v.co.z * (z1 - z0)))


def carve(solid, cutter):
    """solid minus cutter (both bmeshes), via an applied exact boolean; returns a triangulated bmesh."""
    scene = bpy.context.scene
    ms, mc = bpy.data.meshes.new("carve_solid"), bpy.data.meshes.new("carve_cutter")
    solid.to_mesh(ms)
    cutter.to_mesh(mc)
    os_, oc = bpy.data.objects.new("carve_solid", ms), bpy.data.objects.new("carve_cutter", mc)
    scene.collection.objects.link(os_)
    scene.collection.objects.link(oc)
    mod = os_.modifiers.new("carve", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.use_self = True
    mod.object = oc
    bpy.context.view_layer.update()
    evaluated = os_.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = bpy.data.meshes.new_from_object(evaluated)
    out = bmesh.new()
    out.from_mesh(mesh)
    bpy.data.objects.remove(os_)
    bpy.data.objects.remove(oc)
    for m in (ms, mc, mesh):
        bpy.data.meshes.remove(m)
    bmesh.ops.dissolve_limit(out, angle_limit=math.radians(0.5), verts=list(out.verts), edges=list(out.edges))
    bmesh.ops.triangulate(out, faces=list(out.faces))
    return out


def clip_x(poly, x0, x1):
    """Clip a 2D polygon [(x, z), ...] to x0 <= x <= x1 (Sutherland-Hodgman)."""
    for keep, edge in ((lambda p: p[0] >= x0, x0), (lambda p: p[0] <= x1, x1)):
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


class Model:
    def __init__(self) -> None:
        self.b = kit.Builder("hw_wall_computer")
        self.b.pivot("module", PIVOT)

    # static (root space) and module (local space) primitives -------------------------------
    def box(self, size, c, mat, bevel=0.0, mod=False):
        self.b.box(size, M(*c) if mod else c, mat, bevel=bevel, part="module" if mod else "")

    def cyl(self, r, length, c, mat, axis="z", sides=8, bevel=0.0, r2=None, mod=False):
        self.b.cyl(r, length, M(*c) if mod else c, mat, axis=axis, sides=sides, bevel=bevel, radius2=r2, part="module" if mod else "")

    def bolt(self, c, mat, axis, r=0.0035, h=0.0016, mod=False):
        self.b.bolt(M(*c) if mod else c, mat, axis=axis, radius=r, height=h, part="module" if mod else "")

    def put(self, bm, mat, mod=False):
        self.b.add_mesh(bm, "module" if mod else "", mat, None, PIVOT if mod else (0.0, 0.0, 0.0))

    def slab(self, mat, x0, x1, z0, z1, yf, thick, mod=False):
        """Thin plate facing -Y: front at yf, extending `thick` toward +Y."""
        self.box((x1 - x0, thick, z1 - z0), ((x0 + x1) / 2, yf + thick / 2, (z0 + z1) / 2), mat, mod=mod)

    def poly(self, mat, outline, yf, thick, mod=False):
        """Flat polygon (x, z points) facing -Y."""
        xs, zs = [p[0] for p in outline], [p[1] for p in outline]
        cx, cz = (min(xs) + max(xs)) / 2, (min(zs) + max(zs)) / 2
        rel = [(x - cx, z - cz) for x, z in outline]
        c = (cx, yf + thick / 2, cz)
        self.b.prism(rel, thick, M(*c) if mod else c, mat, plane="xz", part="module" if mod else "")

    def stripes(self, mat, x0, x1, z0, z1, pitch, width, yf, thick, mod=False):
        """Hazard band of 45 degree bars clipped to the rectangle."""
        slant = z1 - z0
        xs = x0 - slant
        while xs < x1:
            p = clip_x([(xs, z0), (xs + width, z0), (xs + width + slant, z1), (xs + slant, z1)], x0, x1)
            if len(p) >= 3:
                self.poly(mat, p, yf, thick, mod)
            xs += pitch

    def text(self, mat, x0, z, runs, yf, thick, h=0.0028, gap=0.003, mod=False):
        """Engraved-looking text line: runs are bar lengths laid left to right."""
        x = x0
        for n in runs:
            self.slab(mat, x, x + n, z - h / 2, z + h / 2, yf, thick, mod)
            x += n + gap

    def triangle(self, mat, cx, cz, size, yf, thick, mod=False):
        s = size
        self.poly(mat, [(cx - s / 2, cz - s * 0.43), (cx + s / 2, cz - s * 0.43), (cx, cz + s * 0.57)], yf, thick, mod)

    def triangle_down(self, mat, cx, cz, size, yf, thick, mod=False):
        s = size
        self.poly(mat, [(cx - s / 2, cz + s * 0.43), (cx, cz - s * 0.57), (cx + s / 2, cz + s * 0.43)], yf, thick, mod)


def build_shell(m: Model) -> None:
    """Chamfered case with a recessed slot, dark liner, floor connector, rails, backplate, cable."""
    # beige case: stepped flange, front-edge chamfer, rectangular slot with chamfered lip
    shell = sweep([
        (-0.108, (0.316, 0.366, 0.030), (0.292, 0.332, 0.006)),
        (-0.104, (0.320, 0.370, 0.030), (0.288, 0.328, 0.006)),
        (-0.090, (0.320, 0.370, 0.030), (0.288, 0.328, 0.006)),
        (-0.090, (0.312, 0.362, 0.030), (0.288, 0.328, 0.006)),
        (0.000, (0.312, 0.362, 0.030), (0.288, 0.328, 0.006)),
    ])
    m.put(shell, "hw_beige")

    # dark liner lining the slot (1 mm clear of the case so nothing z-fights) and the floor plate
    m.put(sweep([(-0.098, (0.287, 0.327, 0.006), (0.284, 0.324, 0.004)), (-0.004, (0.287, 0.327, 0.006), (0.284, 0.324, 0.004))]), "hw_dark")
    m.put(sweep([(-0.004, (0.287, 0.327, 0.006), None), (0.000, (0.287, 0.327, 0.006), None)]), "hw_dark")

    # backplate: chamfered dark plate behind the case, stiffening ribs and bolted pads on its wall face
    m.put(sweep([(0.000, (0.308, 0.358, 0.030), None), (0.040, (0.308, 0.358, 0.030), None), (0.046, (0.302, 0.352, 0.030), None)]), "hw_dark")
    m.put(sweep([(0.046, (0.290, 0.340, 0.024), (0.278, 0.328, 0.018)), (0.050, (0.290, 0.340, 0.024), (0.278, 0.328, 0.018))]), "hw_dark")
    for z in (-0.11, 0.11):
        m.box((0.560, 0.0036, 0.012), (0.0, 0.0482, z), "hw_dark")
    m.box((0.012, 0.0036, 0.660), (0.0, 0.0482, 0.0), "hw_dark")
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box((0.050, 0.0030, 0.050), (sx * 0.246, 0.0475, sz * 0.296), "hw_dark", bevel=0.003)
            m.bolt((sx * 0.246, 0.0490, sz * 0.296), "hw_metal", "y", r=0.0085, h=0.0010)
    m.slab("hw_hazard_amber", 0.030, 0.150, -0.075, -0.050, 0.0475, 0.0010)
    m.text("hw_dark", 0.038, -0.058, [0.040, 0.018, 0.026, 0.012], 0.0485, 0.0015)
    m.text("hw_dark", 0.038, -0.067, [0.020, 0.030, 0.014], 0.0485, 0.0015)

    # mounting bolts + hazard/label plates on the flange face (front at -0.108)
    face = -0.108
    for sx in (-1, 1):
        for z in (-0.350, -0.17, 0.0, 0.17, 0.350):
            m.bolt((sx * 0.304, face, z), "hw_metal", "-y", r=0.0055, h=0.0020)
    for x in (-0.25, -0.10):
        m.bolt((x, face, 0.349), "hw_metal", "-y", r=0.0055, h=0.0020)
    for x in (0.15, 0.25):
        m.bolt((x, face, -0.349), "hw_metal", "-y", r=0.0055, h=0.0020)
    # amber ID plate on the top flange with engraved text (plates sit proud of the face)
    plate, ink = 0.0012, 0.0008
    m.slab("hw_hazard_amber", 0.060, 0.260, 0.337, 0.361, face - plate, plate)
    m.text("hw_dark", 0.072, 0.352, [0.040, 0.016, 0.030, 0.012, 0.018], face - plate - ink, ink)
    m.text("hw_dark", 0.072, 0.344, [0.026, 0.050, 0.014, 0.030], face - plate - ink, ink)
    m.triangle("hw_dark", 0.240, 0.349, 0.018, face - plate - ink, ink)
    # hazard band on the bottom flange
    m.slab("hw_dark", -0.255, 0.075, -0.362, -0.336, face - plate, plate)
    m.stripes("hw_hazard_amber", -0.250, 0.070, -0.358, -0.340, 0.034, 0.017, face - plate - ink, ink)

    # guide rails: C-channels along Y on both slot walls, a pin rail up top and a shoe rail below
    for sx in (-1, 1):
        for zc in (0.31, -0.285):
            gap, flange = 0.0065, 0.0025
            m.box((0.0045, 0.090, 2 * (gap + flange)), (sx * 0.28175, -0.051, zc), "hw_metal")
            for sz in (-1, 1):
                z = zc + sz * (gap + flange / 2)
                m.box((0.0225, 0.090, flange), (sx * 0.2725, -0.051, z), "hw_metal")
            # dark stop block at the closed end of the channel
            m.box((0.0215, 0.004, 2 * gap), (sx * 0.2725, -0.008, zc), "hw_dark")

    # floor: blind-mate connector the module back pocket swallows, alignment pins, bolts, label
    m.box((0.090, 0.0105, 0.050), (0.0, -0.00925, 0.20), "hw_metal", bevel=0.0015)
    m.slab("hw_dark", -0.039, 0.039, 0.181, 0.219, -0.0150, 0.0010)
    for ix in (-1.5, -0.5, 0.5, 1.5):
        for dz in (-0.009, 0.009):
            m.cyl(0.0022, 0.004, (ix * 0.018, -0.017, 0.20 + dz), "hw_metal", axis="y", sides=6)
    for sx in (-1, 1):
        m.cyl(0.0075, 0.002, (sx * 0.12, -0.005, 0.20), "hw_metal", axis="y", sides=8)
        m.cyl(0.0035, 0.004, (sx * 0.12, -0.008, 0.20), "hw_metal", axis="y", sides=8)
        for z in (-0.15, 0.15):
            m.bolt((sx * 0.268, -0.004, z), "hw_metal", "-y", r=0.0045, h=0.0016)
    m.slab("hw_hazard_amber", -0.100, 0.100, -0.312, -0.292, -0.0052, 0.0012)
    m.stripes("hw_dark", -0.096, 0.096, -0.308, -0.296, 0.030, 0.012, -0.0058, 0.0007)

    # cable strain relief: gland nut, ribbed boot and clamped cable entering the top of the backplate
    gx, gy = -0.20, 0.022
    m.cyl(0.0165, 0.0045, (gx, gy, 0.36025), "hw_metal", axis="z", sides=6, bevel=0.0006)
    for i in range(3):
        m.cyl(0.0125 - 0.0007 * i, 0.0023, (gx, gy, 0.36375 + 0.0023 * i), "hw_dark", axis="z", sides=8, r2=0.0095 - 0.0004 * i)
    m.cyl(0.0055, 0.024, (gx, 0.038, 0.3635), "hw_dark", axis="y", sides=8)
    m.box((0.020, 0.007, 0.0118), (gx, 0.040, 0.36385), "hw_metal", bevel=0.0007)


def build_module(m: Model) -> None:
    """The blade: slim beige case, bezel + glass, label/LED strip, pull handle, vents, hinge."""
    # case solid (chamfered), carved with recessed pockets and slots
    case = sweep([
        (Y_FRONT, (W - 0.005, (Z_TOP - Z_BOT) / 2 - 0.005, 0.012), None),
        (Y_FRONT + 0.005, (W, (Z_TOP - Z_BOT) / 2, 0.012), None),
        (Y_BACK - 0.005, (W, (Z_TOP - Z_BOT) / 2, 0.012), None),
        (Y_BACK, (W - 0.005, (Z_TOP - Z_BOT) / 2 - 0.005, 0.012), None),
    ], zc=(Z_TOP + Z_BOT) / 2)
    pockets = bmesh.new()
    inserts = []  # (x0, x1, y0, y1, z0, z1): dark floors dropped into the pockets

    def pocket(x0, x1, y0, y1, z0, z1, floor=None, floor_axis="y"):
        cut_box(pockets, x0, x1, y0, y1, z0, z1)
        if floor is not None:
            inserts.append(floor)

    ff = Y_FRONT - 0.002  # cutters start outside the face
    # label + LED recesses in the top strip, handle finger pocket, chin groove
    pocket(-0.226, -0.034, ff, -0.017, -0.080, -0.030, (-0.2257, -0.0343, -0.0180, -0.0170, -0.0797, -0.0303))
    pocket(0.046, 0.236, ff, -0.014, -0.084, -0.030, (0.0463, 0.2357, -0.0150, -0.0140, -0.0837, -0.0303))
    pocket(-0.105, 0.105, ff, -0.006, -0.608, -0.552, (-0.1047, 0.1047, -0.0070, -0.0060, -0.6077, -0.5523))
    pocket(-0.249, 0.249, ff, -0.0185, -0.5365, -0.5353)
    # socket pocket and louvres in the back face
    bb = Y_BACK + 0.002
    pocket(-0.054, 0.054, 0.036, bb, -0.144, -0.076, (-0.0537, 0.0537, 0.0360, 0.0370, -0.1437, -0.0763))
    for i in range(8):
        z = -0.300 - 0.018 * i
        pocket(-0.150, 0.150, 0.043, bb, z - 0.0025, z + 0.0025, (-0.1497, 0.1497, 0.0430, 0.0440, z - 0.0022, z + 0.0022))
    # underside vent slots
    for i in range(9):
        x = -0.128 + 0.032 * i
        pocket(x - 0.003, x + 0.003, -0.006, 0.040, Z_BOT - 0.002, Z_BOT + 0.006, (x - 0.0027, x + 0.0027, -0.0057, 0.0397, Z_BOT + 0.0050, Z_BOT + 0.0060))
    m.put(carve(case, pockets), "hw_beige", mod=True)
    pockets.free()
    for x0, x1, y0, y1, z0, z1 in inserts:
        m.box((x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), "hw_dark", mod=True)

    # bezel: dark frame with a chamfered lip around the glass, bolted down
    bez_a, bez_b = 0.242, 0.214
    bezel = sweep([
        (LIP_Y, (bez_a - 0.003, bez_b - 0.003, 0.012), (SCREEN_HALF[0] - 0.0025, SCREEN_HALF[1] - 0.0025, 0.009)),
        (LIP_Y + 0.003, (bez_a, bez_b, 0.012), (SCREEN_HALF[0] - 0.0025, SCREEN_HALF[1] - 0.0025, 0.009)),
        (Y_FRONT + 0.002, (bez_a, bez_b, 0.012), (SCREEN_HALF[0] - 0.0025, SCREEN_HALF[1] - 0.0025, 0.009)),
    ], zc=SCREEN_Z)
    m.put(bezel, "hw_dark", mod=True)
    bx, bz = (bez_a + SCREEN_HALF[0] - 0.0025) / 2, (bez_b + SCREEN_HALF[1] - 0.0025) / 2
    for sx in (-1, 1):
        for dz in (-1, 0, 1):
            m.bolt((sx * bx, LIP_Y, SCREEN_Z + dz * (bez_b - 0.008) * (1 if dz else 0)), "hw_metal", "-y", r=0.0032, h=0.0016, mod=True)
    for dx in (-0.14, 0.0, 0.14):
        for sz in (-1, 1):
            m.bolt((dx, LIP_Y, SCREEN_Z + sz * bz), "hw_metal", "-y", r=0.0032, h=0.0016, mod=True)
    # case corner screws on the chin
    for sx in (-1, 1):
        for z in (-0.560, -0.610):
            m.bolt((sx * 0.234, Y_FRONT, z), "hw_metal", "-y", r=0.0040, h=0.0018, mod=True)

    # label recess contents: amber ID plate with engraved text, hazard band, warning triangle
    m.slab("hw_hazard_amber", -0.222, -0.118, -0.034, -0.052, -0.0192, 0.0012, mod=True)
    m.text("hw_dark", -0.216, -0.039, [0.030, 0.014, 0.022, 0.010], -0.0198, 0.0006, mod=True)
    m.text("hw_dark", -0.216, -0.047, [0.016, 0.034, 0.012, 0.016], -0.0198, 0.0006, mod=True)
    m.stripes("hw_hazard_amber", -0.222, -0.102, -0.074, -0.058, 0.026, 0.0130, -0.0192, 0.0012, mod=True)
    m.slab("hw_hazard_amber", -0.096, -0.040, -0.074, -0.058, -0.0192, 0.0012, mod=True)
    m.text("hw_dark", -0.092, -0.066, [0.014, 0.010, 0.020], -0.0198, 0.0006, mod=True)
    m.triangle("hw_hazard_amber", -0.066, -0.042, 0.020, -0.0192, 0.0012, mod=True)
    m.slab("hw_dark", -0.0675, -0.0645, -0.0455, -0.0385, -0.0198, 0.0006, mod=True)
    m.slab("hw_dark", -0.0675, -0.0645, -0.0345, -0.0325, -0.0198, 0.0006, mod=True)

    # barcode serial strip between the label and the LED cluster
    x = -0.018
    for n, gap in ((0.0020, 0.0030), (0.0040, 0.0025), (0.0015, 0.0035), (0.0035, 0.0025), (0.0020, 0.0030), (0.0045, 0.0025), (0.0020, 0.0)):
        m.slab("hw_dark", x, x + n, -0.074, -0.040, Y_FRONT - 0.0008, 0.0008, mod=True)
        x += n + gap

    # status LED cluster: collars + lamps in the recess, amber tick labels below
    lamps = [("hw_phosphor_green", 0.078), ("hw_phosphor_green", 0.118), ("hw_hazard_amber", 0.158), ("hw_hazard_amber", 0.198)]
    for mat, x in lamps:
        m.cyl(0.0074, 0.0035, (x, -0.0165, -0.046), "hw_metal", axis="y", sides=8, mod=True)
        m.cyl(0.0050, 0.0050, (x, -0.0190, -0.046), mat, axis="y", sides=8, bevel=0.0006, mod=True)
        m.slab("hw_hazard_amber", x - 0.007, x + 0.007, -0.0705, -0.0690, -0.0158, 0.0010, mod=True)
    m.text("hw_hazard_amber", 0.066, -0.0795, [0.012, 0.012, 0.008, 0.020, 0.010, 0.016], -0.0156, 0.0010, h=0.0020, mod=True)

    # pull handle: ribbed grip bar on two stand-off brackets over the finger pocket, amber arrows
    m.b.fluted(0.0105, 0.200, M(0.0, -0.034, -0.580), "hw_metal", flutes=14, depth=0.0016, axis="x", part="module")
    for sx in (-1, 1):
        m.box((0.014, 0.020, 0.024), (sx * 0.1135, -0.0300, -0.580), "hw_metal", bevel=0.0015, mod=True)
        m.cyl(0.0125, 0.004, (sx * 0.1135, -0.0415, -0.580), "hw_metal", axis="y", sides=8, mod=True)
        m.triangle_down("hw_hazard_amber", sx * 0.170, -0.580, 0.016, -0.0192, 0.0012, mod=True)

    # hinge: segmented barrel on the fold axis, dark pin in the gaps, end blocks, rail pins
    for xc in (-0.175, -0.0875, 0.0, 0.0875, 0.175):
        m.cyl(0.0105, 0.075, (xc, 0.0, 0.0), "hw_metal", axis="x", sides=8, mod=True)
    m.cyl(0.0052, 0.430, (0.0, 0.0, 0.0), "hw_dark", axis="x", sides=8, mod=True)
    for sx in (-1, 1):
        m.box((0.0425, 0.028, 0.025), (sx * 0.2338, 0.0, -0.002), "hw_metal", bevel=0.002, mod=True)
        m.cyl(0.0055, 0.034, (sx * 0.2570, 0.0, 0.0), "hw_metal", axis="x", sides=8, mod=True)
        m.bolt((sx * 0.2338, 0.0, 0.0105), "hw_dark", "z", r=0.0045, h=0.0016, mod=True)
        # runner shoes on the lower rail
        m.box((0.0185, 0.050, 0.010), (sx * 0.2635, 0.010, -0.595), "hw_metal", mod=True)


def build_screen(model: Model, root: bpy.types.Object) -> None:
    """The single `Screen` mesh: an octagonal glass slab whose origin is the display centre."""
    holder = model.b.holders["module"]
    a, b = SCREEN_HALF
    y_mid = (-0.022 + -0.0165) / 2
    bm = sweep([(-0.022, (a - 0.002, b - 0.002, 0.009), None), (-0.020, (a, b, 0.009), None), (-0.0165, (a, b, 0.009), None)], zc=0.0)
    bmesh.ops.translate(bm, vec=Vector((0.0, -y_mid, 0.0)), verts=bm.verts)
    mesh = bpy.data.meshes.new("Screen")
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = False
    mesh.materials.append(kit.material("hw_phosphor_green"))
    screen = bpy.data.objects.new("Screen", mesh)
    bpy.context.scene.collection.objects.link(screen)
    screen.parent = holder
    screen.location = (0.0, y_mid, SCREEN_Z)


def main() -> None:
    kit.reset()
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = 1, 24

    model = Model()
    build_shell(model)
    build_module(model)
    root = model.b.build()
    build_screen(model, root)
    model.b.holders["module"].name = "module"

    kit.check_bounds(root, *kit.REFERENCE_BOUNDS["hw_wall_computer"])

    module = bpy.data.objects["module"]
    kit.animate(module, ACTION, [
        (1, {"location": PIVOT, "rotation": (0.0, 0.0, 0.0)}),
        (12, {"location": (0.0, -0.18, 0.31), "rotation": (0.0, 0.0, 0.0)}),
        (24, {"location": (0.0, -0.18, 0.31), "rotation": (-32.0, 0.0, 0.0)}),
    ])
    scene.frame_set(1)
    print(f"hw_wall_computer: {kit.triangles(root)} tris, bounds {[tuple(round(c, 4) for c in v) for v in kit.bounds(root)]}")
    kit.export(root, "cockpit/hw_wall_computer.glb", "wall_computer_kit.blend")


main()
