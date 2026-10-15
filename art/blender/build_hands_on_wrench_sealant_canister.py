"""Wrench, sealant cartridge and sample canister models (hands-on pass; see hw_kit.py).

Run headless from the repo root (writes tools/hw_wrench.glb, hw_sealant.glb, hw_canister.glb under
game/assets/models/hullwatch/):
    blender --background --factory-startup --python art/blender/build_hands_on_wrench_sealant_canister.py
    blender --background --factory-startup --python art/blender/build_hands_on_wrench_sealant_canister.py -- wrench
Set HW_MODELS_DIR to redirect output while iterating.

Each tool keeps the footprint of the model it replaces (hw_kit.REFERENCE_BOUNDS) and ships one
`use_<tool>` action (24 frames at 24 fps) that Carriable.play_use_animation() plays once.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import hw_kit as kit  # noqa: E402


# -- local helpers (hw_kit is shared and read-only) -------------------------------------------------
def lathe(b, profile, center, mat, axis="y", sides=16, part="", sx=1.0, sz=1.0, caps=False, shift=None) -> None:
    """Revolve a (position along axis, radius) polyline into a faceted solid. Rings with radius 0
    collapse to a pole, so a profile that starts and ends on the axis is a closed solid. `sx`/`sz`
    stretch the two radial axes (oval sections); `shift(ring, u, v)` offsets a vertex along the
    axis (slanted cuts)."""
    bm = bmesh.new()
    rings = []
    for i, (a, r) in enumerate(profile):
        if r < 1e-9:
            rings.append([bm.verts.new(_at(axis, a + (shift(i, 0.0, 0.0) if shift else 0.0), 0.0, 0.0))] * sides)
            continue
        ring = []
        for k in range(sides):
            t = 2.0 * math.pi * k / sides
            u, v = r * math.cos(t) * sx, r * math.sin(t) * sz
            ring.append(bm.verts.new(_at(axis, a + (shift(i, u, v) if shift else 0.0), u, v)))
        rings.append(ring)

    def face(vs):
        out = []
        for v in vs:
            if not out or out[-1] is not v:
                out.append(v)
        if len(out) > 1 and out[0] is out[-1]:
            out.pop()
        if len(set(out)) >= 3:
            bm.faces.new(out)

    for i in range(len(rings) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            face([rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]])
    if caps:
        face(list(reversed(rings[0])))
        face(rings[-1])
    b.add_mesh(bm, part, mat, None, center)


def _at(axis, a, u, v):
    return {"y": (u, a, v), "z": (u, v, a), "x": (a, u, v)}[axis]


def ring_prism(b, outer, inner, depth, center, mat, plane="yz", part="") -> None:
    """Extruded plate with a through hole; outer and inner outlines need the same point count."""
    bm = bmesh.new()
    axes = {"xz": (0, 2, 1), "xy": (0, 1, 2), "yz": (1, 2, 0)}[plane]

    def pt(p, d):
        v = [0.0, 0.0, 0.0]
        v[axes[0]], v[axes[1]], v[axes[2]] = p[0], p[1], d
        return v

    loops = {(n, s): [bm.verts.new(pt(p, s * depth / 2)) for p in pts] for n, pts in (("o", outer), ("i", inner)) for s in (-1, 1)}
    n = len(outer)
    for name in ("o", "i"):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new([loops[(name, -1)][i], loops[(name, -1)][j], loops[(name, 1)][j], loops[(name, 1)][i]])
    for s in (-1, 1):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new([loops[("o", s)][i], loops[("o", s)][j], loops[("i", s)][j], loops[("i", s)][i]])
    b.add_mesh(bm, part, mat, None, center)


def polygon(cx, cy, r, n, phase=0.0):
    return [(cx + r * math.cos(phase + 2 * math.pi * i / n), cy + r * math.sin(phase + 2 * math.pi * i / n)) for i in range(n)]


def decal(b, axis, phi, along, radius, size, mat, part="", tilt=0.0, zc=0.0, tan=0.0) -> None:
    """Thin box lying on a facet of a round body. `phi` (degrees) is the facet's angle around the
    axis, `radius` the facet's apothem plus half the decal thickness. size = (thickness, length
    along the axis, width around the axis); `tan` slides it sideways along the facet."""
    p = math.radians(phi)
    t, la, lt = size
    cx, cy = radius * math.cos(p) - tan * math.sin(p), radius * math.sin(p) + tan * math.cos(p)
    if axis == "y":
        b.box((t, la, lt), (cx, along, zc + cy), mat, part=part, rot=(tilt, -phi, 0.0))
    else:
        b.box((t, lt, la), (cx, cy, along), mat, part=part, rot=(tilt, 0.0, phi))


def decal_prism(b, axis, phi, along, radius, outline, thick, mat, part="", zc=0.0) -> None:
    """Flat outline (tangent, along-axis coordinates) printed on a facet; see decal()."""
    p = math.radians(phi)
    if axis == "y":
        b.prism([(u, t) for t, u in outline], thick, (radius * math.cos(p), along, zc + radius * math.sin(p)), mat, plane="yz", part=part, rot=(0.0, -phi, 0.0))
    else:
        b.prism([(t, u) for t, u in outline], thick, (radius * math.cos(p), radius * math.sin(p), along), mat, plane="yz", part=part, rot=(0.0, 0.0, phi))


# -- hw_wrench --------------------------------------------------------------------------------------
def build_wrench() -> bpy.types.Object:
    """Adjustable wrench lying with its flat faces toward +-X: handle along Y, jaws open toward +Y
    with the gap across Z. The sliding jaw rides in guide rails on the head and is driven by the
    thumb wheel hanging under the head."""
    b = kit.Builder("hw_wrench")
    zc = 0.025                                  # handle centre line
    hx = 0.0148                                 # head half-thickness
    slide_pivot = (0.0, 0.080, 0.0235)
    b.pivot("slide", slide_pivot)

    # Forged steel core of the handle: tapers toward the grip, flares into the head.
    b.prism([(-0.145, 0.006), (-0.030, 0.0035), (-0.010, 0.0), (0.010, 0.0), (0.010, 0.050), (-0.030, 0.046), (-0.145, 0.045)],
            0.023, (0, 0, 0), "hw_metal", plane="yz", bevel=0.0015)
    # Fuller grooves, maker plaque with printed bars.
    for s in (-1, 1):
        x = s * 0.0117
        b.box((0.0005, 0.024, 0.0075), (x, -0.0215, zc), "hw_dark")
        b.box((0.0005, 0.0150, 0.0130), (x, -0.0620, zc), "hw_beige")
        for i in range(3):
            b.box((0.0005, 0.0010 + (i % 2) * 0.0006, 0.0100), (x + s * 0.0003, -0.0665 + i * 0.0036, zc), "hw_dark")
    # Hazard-amber band and the grip sleeve ferrule.
    b.box((0.0268, 0.0120, 0.0480), (0.0, -0.0445, zc), "hw_hazard_amber", bevel=0.0030)
    lathe(b, [(-0.0745, 1.0), (-0.0735, 1.06), (-0.0700, 1.06), (-0.0690, 1.0)], (0, 0, zc), "hw_steel", sides=12, sx=0.0138, sz=0.0262)

    # Rubber grip sleeve (oval, with finger ribs) and the lanyard lug at the pommel.
    sleeve = [(-0.1365, 0.86), (-0.1350, 0.955), (-0.1315, 0.955)]
    for i in range(6):
        y0 = -0.1290 + i * 0.0100
        sleeve += [(y0, 0.955), (y0 + 0.0012, 1.0), (y0 + 0.0048, 1.0), (y0 + 0.0060, 0.955)]
    sleeve += [(-0.0745, 0.955), (-0.0735, 0.90)]
    lathe(b, sleeve, (0, 0, zc), "hw_rubber", sides=12, sx=0.0147, sz=0.0280)
    ring_prism(b, polygon(-0.1485, zc, 0.0115, 8), polygon(-0.1485, zc, 0.0046, 8), 0.019, (0, 0, 0), "hw_metal")
    for s in (-1, 1):  # lug bushing ring around the lanyard hole
        ring_prism(b, polygon(-0.1485, zc, 0.0068, 8), polygon(-0.1485, zc, 0.0046, 8), 0.0014, (s * 0.0097, 0, 0), "hw_steel")

    # Forged head: wrapped around the jaw column, fixed jaw on top, chamfered tip.
    head = [(-0.010, 0.0), (0.052, 0.0), (0.056, 0.004), (0.056, 0.056), (0.1010, 0.056), (0.1151, 0.0615),
            (0.1151, 0.0725), (0.1060, 0.080), (0.012, 0.080), (-0.002, 0.0665), (-0.010, 0.050)]
    b.prism(head, hx * 2, (0, 0, 0), "hw_metal", plane="yz", bevel=0.0028)
    # Guide rails that capture the sliding jaw.
    for s in (-1, 1):
        b.box((0.0036, 0.019, 0.052), (s * 0.0140, 0.0655, 0.030), "hw_metal", bevel=0.0010)
    # Serrations on the fixed jaw face and the sliding jaw face.
    for i in range(6):
        b.box((0.0200, 0.0017, 0.0012), (0.0, 0.0680 + i * 0.0065, 0.0556), "hw_steel")
    # Stamped size panel with scale ticks, pivot rivets and the screw heads, both faces.
    for s in (-1, 1):
        face = s * hx
        b.box((0.0006, 0.034, 0.014), (face + s * 0.0003, 0.022, 0.0605), "hw_dark")
        for i in range(7):
            h = 0.0075 if i % 3 == 0 else 0.0045
            b.box((0.0006, 0.0012, h), (face + s * 0.0006, 0.0090 + i * 0.0043, 0.0545 + h / 2 + 0.0005), "hw_beige")
        b.bolt((face, 0.0455, 0.0640), "hw_steel", axis="x" if s > 0 else "-x", radius=0.0042, height=0.0012)
        b.bolt((face, 0.0455, 0.0170), "hw_steel", axis="x" if s > 0 else "-x", radius=0.0042, height=0.0012)
        b.box((0.0006, 0.010, 0.0030), (face + s * 0.0003, 0.0390, 0.0075), "hw_hazard_amber")  # lock-off marker

    # Thumb wheel hanging under the head, knurled rim, hub bolts.
    b.fluted(0.0125, 0.0316, (0.0, 0.032, 0.0095), "hw_steel", flutes=16, depth=0.0017, axis="x")
    for s in (-1, 1):
        b.cyl(0.0085, 0.0010, (s * 0.0160, 0.032, 0.0095), "hw_metal", axis="x", sides=12)
        b.bolt((s * 0.0165, 0.032, 0.0095), "hw_dark", axis="x" if s > 0 else "-x", radius=0.0040, height=0.0008)

    # Sliding jaw (steel) with its rack shank, serrated face and side slots.
    b.prism([(0.056, 0.013), (0.1000, 0.013), (0.1040, 0.0175), (0.1040, 0.0295), (0.0995, 0.034), (0.056, 0.034)],
            0.0240, (0, 0, 0), "hw_steel", plane="yz", bevel=0.0010, part="slide")
    b.box((0.012, 0.0045, 0.016), (0.0, 0.0585, 0.042), "hw_steel", bevel=0.0005, part="slide")
    for i in range(5):
        b.box((0.0090, 0.0016, 0.0020), (0.0, 0.0614, 0.0360 + i * 0.0030), "hw_dark", part="slide")
    for i in range(6):
        b.box((0.0200, 0.0017, 0.0012), (0.0, 0.0647 + i * 0.0065, 0.0346), "hw_steel", part="slide")
    for s in (-1, 1):
        b.box((0.0005, 0.032, 0.0050), (s * 0.01225, 0.080, 0.0235), "hw_dark", part="slide")
        b.box((0.0005, 0.0040, 0.0100), (s * 0.01225, 0.0990, 0.0235), "hw_hazard_amber", part="slide")

    root = b.build()
    kit.animate(root, "use_wrench", [(0, {"rotation": (0, 0, 0)}), (12, {"rotation": (0, 10, 0)}), (24, {"rotation": (0, 0, 0)})])
    jaw = lambda dz: {"location": (slide_pivot[0], slide_pivot[1], slide_pivot[2] + dz)}
    kit.animate(b.holders["slide"], "use_wrench", [(0, jaw(0.0)), (9, jaw(0.013)), (15, jaw(0.013)), (24, jaw(0.0))])
    kit.check_bounds(root, *kit.REFERENCE_BOUNDS["hw_wrench"])
    return root


# -- hw_sealant -------------------------------------------------------------------------------------
def build_sealant() -> bpy.types.Object:
    """Cartridge along Y, nozzle toward +Y. The thumb disc and rod (`plunger`) push in on use."""
    b = kit.Builder("hw_sealant")
    zc = 0.042
    centre = (0.0, 0.0, zc)
    rod_pivot = (0.0, -0.1359, zc)
    b.pivot("plunger", rod_pivot)

    # Barrel: flanged rear, finger ribs, plain body, closed front.
    prof = [(-0.1194, 0.0), (-0.1194, 0.0400), (-0.1184, 0.0440), (-0.1124, 0.0440), (-0.1104, 0.0405)]
    for i in range(3):
        y0 = -0.1054 + i * 0.0145
        prof += [(y0, 0.0405), (y0 + 0.0010, 0.0420), (y0 + 0.0050, 0.0420), (y0 + 0.0060, 0.0405)]
    prof += [(0.0606, 0.0405), (0.0626, 0.0385), (0.0646, 0.0385), (0.0646, 0.0)]
    lathe(b, prof, centre, "hw_teal", sides=16)
    # Crimp ring, shoulder cone, threaded collar, nozzle.
    lathe(b, [(0.0546, 0.0395), (0.0556, 0.0418), (0.0616, 0.0418), (0.0626, 0.0395)], centre, "hw_steel", sides=16)
    lathe(b, [(0.0646, 0.0380), (0.0700, 0.0350), (0.0960, 0.0245), (0.0960, 0.0)], centre, "hw_metal", sides=16)
    thread = [(0.0960, 0.0), (0.0960, 0.0225)]
    for i in range(3):
        y0 = 0.1000 + i * 0.0072
        thread += [(y0, 0.0235), (y0 + 0.0007, 0.0258), (y0 + 0.0032, 0.0258), (y0 + 0.0039, 0.0235)]
    thread += [(0.1216, 0.0235), (0.1216, 0.0)]
    lathe(b, thread, centre, "hw_dark", sides=8)
    tip = 0.1586
    cut = 0.9
    nozzle = [(0.1216, 0.0), (0.1216, 0.0165), (0.1296, 0.0140), (0.1486, 0.0075), (tip, 0.0045)]
    lathe(b, nozzle, centre, "hw_beige", sides=16, caps=True, shift=lambda i, u, v: -cut * (v + 0.0045) if i == len(nozzle) - 1 else 0.0)
    orifice = [(tip - 0.0100, 0.0022), (tip, 0.0022)]
    lathe(b, orifice, centre, "hw_rubber", sides=8, caps=True, shift=lambda i, u, v: (-cut * (v + 0.0045) + 0.0003) if i == 1 else 0.0)

    # Label wrap with printed bars, hazard band with stripes, tear strip.
    apothem = 0.0430 * math.cos(math.radians(11.25))
    r_d = apothem + 0.0003
    lathe(b, [(-0.0444, 0.0415), (-0.0434, 0.0430), (0.0046, 0.0430), (0.0056, 0.0415)], centre, "hw_beige", sides=16)
    y = -0.0404
    for w in (0.0015, 0.0008, 0.0025, 0.0008, 0.0015, 0.0025):  # barcode, both flanks
        for phi in (11.25, 168.75):
            decal(b, "y", phi, y + w / 2, r_d, (0.0006, w, 0.0120), "hw_dark", zc=zc)
        y += w + 0.0014
    for n, t in ((0.034, -0.0055), (0.022, -0.0015), (0.027, 0.0025), (0.013, 0.0065)):  # text lines on top
        decal(b, "y", 101.25, -0.0194, r_d, (0.0006, n, 0.0018), "hw_dark", zc=zc, tan=t)
    decal(b, "y", 78.75, -0.0194, r_d, (0.0006, 0.0140, 0.0120), "hw_hazard_amber", zc=zc)
    decal(b, "y", 78.75, -0.0194, r_d + 0.0003, (0.0006, 0.0070, 0.0020), "hw_dark", zc=zc, tan=0.0020)
    decal(b, "y", 78.75, -0.0194, r_d + 0.0003, (0.0006, 0.0022, 0.0020), "hw_dark", zc=zc, tan=-0.0035)
    lathe(b, [(0.0126, 0.0412), (0.0136, 0.0430), (0.0336, 0.0430), (0.0346, 0.0412)], centre, "hw_hazard_amber", sides=16)
    for k in range(16):
        decal_prism(b, "y", 11.25 + 22.5 * k, 0.0236, r_d, [(-0.0080, -0.0085), (-0.0080, -0.0030), (0.0080, 0.0085), (0.0080, 0.0030)], 0.0006, "hw_dark", zc=zc)
    lathe(b, [(0.0436, 0.0402), (0.0441, 0.0418), (0.0451, 0.0418), (0.0456, 0.0402)], centre, "hw_dark", sides=16)
    b.box((0.0120, 0.0034, 0.0050), (0.0, 0.0446, zc + 0.0420), "hw_hazard_amber", bevel=0.0008)  # tear-strip pull tab

    # Rear gasket and plunger (rod, collar, ribbed thumb disc, steel boss).
    lathe(b, [(-0.1204, 0.0), (-0.1204, 0.0340), (-0.1194, 0.0340)], centre, "hw_rubber", sides=16, caps=True)
    lathe(b, [(-0.1360, 0.0), (-0.1360, 0.0072), (-0.1000, 0.0072), (-0.1000, 0.0)], centre, "hw_steel", sides=8, part="plunger")
    lathe(b, [(-0.1356, 0.0112), (-0.1342, 0.0122), (-0.1316, 0.0122), (-0.1302, 0.0112)], centre, "hw_metal", sides=8, part="plunger")
    disc = [(-0.1449, 0.0), (-0.1449, 0.0300), (-0.1459, 0.0320), (-0.1459, 0.0355), (-0.1445, 0.0380),
            (-0.1385, 0.0380), (-0.1359, 0.0355), (-0.1359, 0.0)]
    lathe(b, disc, centre, "hw_dark", sides=12, part="plunger")
    lathe(b, [(-0.1459, 0.0), (-0.1459, 0.0100), (-0.1449, 0.0115), (-0.1439, 0.0115)], centre, "hw_steel", sides=8, part="plunger")
    for k in range(8):
        a = math.radians(45.0 * k)
        b.box((0.0018, 0.0010, 0.0170), (math.sin(a) * 0.0205, -0.1454, zc + math.cos(a) * 0.0205), "hw_metal", part="plunger", rot=(0.0, math.degrees(a), 0.0))

    root = b.build()
    kit.animate(root, "use_sealant", [(0, {"location": (0, 0, 0)}), (5, {"location": (0, -0.011, 0)}), (24, {"location": (0, 0, 0)})])
    push = lambda dy: {"location": (rod_pivot[0], rod_pivot[1] + dy, rod_pivot[2])}
    kit.animate(b.holders["plunger"], "use_sealant", [(0, push(0.0)), (6, push(0.010)), (14, push(0.010)), (24, push(0.0))])
    kit.check_bounds(root, *kit.REFERENCE_BOUNDS["hw_sealant"])
    return root


# -- hw_canister ------------------------------------------------------------------------------------
def build_canister() -> bpy.types.Object:
    """Upright sample drum on a heavy base ring; carry bail on shoulder brackets; the knurled cap
    (`cap`) turns about Z when the sim says the sample was taken."""
    b = kit.Builder("hw_canister")
    cap_z = 0.2076
    b.pivot("cap", (0.0, 0.0, cap_z))
    R = 16  # sides: a multiple of 4 keeps vertices on the axes so the footprint is reached exactly
    half = 180.0 / R

    # Base ring with a groove, rubber feet.
    base = [(0.0066, 0.0), (0.0066, 0.0690), (0.0086, 0.0760), (0.0130, 0.0760), (0.0140, 0.0725), (0.0170, 0.0725),
            (0.0180, 0.0760), (0.0235, 0.0760), (0.0255, 0.0725), (0.0255, 0.0)]
    lathe(b, base, (0, 0, 0), "hw_dark", axis="z", sides=R)
    for sx_ in (-1, 1):
        for sy_ in (-1, 1):
            b.box((0.020, 0.020, 0.0066), (sx_ * 0.0414, sy_ * 0.0414, 0.0039), "hw_rubber", bevel=0.0018)

    # Drum body (vertical rib strips on the sides and back), sloped shoulder.
    body = [(0.0166, 0.0), (0.0166, 0.0640), (0.0190, 0.0720), (0.1580, 0.0720), (0.1650, 0.0705), (0.1806, 0.0545), (0.1806, 0.0)]
    lathe(b, body, (0, 0, 0), "hw_teal", axis="z", sides=R)
    for k in range(R):
        if k not in (2, 5, 9, 10, 11, 12, 13, 14):
            decal(b, "z", half + 2 * half * k, 0.0680, 0.0717, (0.0022, 0.0720, 0.0090), "hw_teal")
    # Stacking latch tabs just above the base.
    for k in (2, 5, 9, 14):
        decal(b, "z", half + 2 * half * k, 0.0385, 0.0728, (0.0045, 0.0300, 0.0160), "hw_metal")

    # Hazard band with diagonal stripes.
    lathe(b, [(0.1106, 0.0700), (0.1126, 0.0750), (0.1386, 0.0750), (0.1406, 0.0700)], (0, 0, 0), "hw_hazard_amber", axis="z", sides=R)
    r_band = 0.0750 * math.cos(math.radians(half)) + 0.0003
    for k in range(R):
        decal_prism(b, "z", half + 2 * half * k, 0.1256, r_band, [(-0.0135, -0.0150), (-0.0135, -0.0075), (0.0135, 0.0075), (0.0135, 0.0)], 0.0006, "hw_dark")

    # Label plate on the front (-Y) with printed lines, barcode and hazard chip; corner screws.
    b.box((0.067, 0.0094, 0.054), (0.0, -0.0727, 0.0756), "hw_metal", bevel=0.0012)
    b.box((0.060, 0.0006, 0.047), (0.0, -0.0777, 0.0756), "hw_beige")
    yf = -0.0781
    for i, (w, z) in enumerate([(0.034, 0.0925), (0.026, 0.0870), (0.030, 0.0815)]):
        b.box((w, 0.0006, 0.0034), (-0.0300 + w / 2 + 0.0035, yf, z), "hw_dark")
    b.box((0.012, 0.0006, 0.0120), (0.0225, yf, 0.0900), "hw_hazard_amber")
    b.box((0.0022, 0.0006, 0.0070), (0.0225, yf - 0.0006, 0.0915), "hw_dark")
    b.box((0.0022, 0.0006, 0.0022), (0.0225, yf - 0.0006, 0.0875), "hw_dark")
    x = -0.0260
    for w in (0.0015, 0.0008, 0.0025, 0.0008, 0.0015, 0.0025, 0.0008, 0.0015, 0.0025, 0.0008, 0.0015, 0.0025):
        b.box((w, 0.0006, 0.0100), (x + w / 2, yf, 0.0620), "hw_dark")
        x += w + 0.0013
    b.box((0.0120, 0.0006, 0.0100), (0.0215, yf, 0.0620), "hw_teal")
    for sx_ in (-1, 1):
        for z in (0.0516, 0.0996):
            b.bolt((sx_ * 0.0300, -0.0780, z), "hw_steel", axis="-y", radius=0.0026, height=0.0010)

    # Neck, threads, tick marks for the cap turn, shoulder brackets, gauge.
    thr = [(0.1806, 0.0), (0.1806, 0.0480), (0.1830, 0.0480)]
    for z0 in (0.1840, 0.1872):
        thr += [(z0, 0.0480), (z0 + 0.0004, 0.0516), (z0 + 0.0022, 0.0516), (z0 + 0.0026, 0.0480)]
    thr += [(0.1916, 0.0480), (0.1916, 0.0)]
    lathe(b, thr, (0, 0, 0), "hw_metal", axis="z", sides=12)
    for k in range(5):
        decal(b, "z", -90.0 + 8.0 * k, 0.1861, 0.0486, (0.0016, 0.0100 if k % 4 == 0 else 0.0060, 0.0010), "hw_dark")
    b.box((0.0016, 0.0120, 0.0012), (0.0, -0.0480, 0.1868), "hw_hazard_amber")
    for s in (-1, 1):
        b.box((0.0055, 0.0300, 0.0280), (s * 0.0618, 0.0, 0.1720), "hw_metal", bevel=0.0012)
        b.bolt((s * 0.0705, 0.0, 0.1720), "hw_steel", axis="x" if s > 0 else "-x", radius=0.0046, height=0.0014)
    # Pressure gauge: boss, bezel, face with ticks and needle.
    gz = 0.1680
    b.cyl(0.0205, 0.0170, (0.0, -0.0660, gz), "hw_metal", axis="y", sides=16)
    lathe(b, [(-0.0745, 0.0170), (-0.0755, 0.0185), (-0.0765, 0.0185), (-0.0765, 0.0150), (-0.0750, 0.0150)], (0, 0, gz), "hw_steel", sides=16)
    lathe(b, [(-0.0745, 0.0), (-0.0745, 0.0150), (-0.0750, 0.0150), (-0.0750, 0.0)], (0, 0, gz), "hw_beige", sides=16, caps=True)
    for i in range(9):
        a = math.radians(-120 + i * 30)
        r = 0.0124
        b.box((0.0014 if i % 4 else 0.0020, 0.0006, 0.0034 if i % 4 else 0.0046), (math.sin(a) * r, -0.0753, gz + math.cos(a) * r), "hw_dark", rot=(0, math.degrees(a), 0))
    b.box((0.0018, 0.0006, 0.0108), (math.sin(math.radians(35)) * 0.0045, -0.0757, gz + math.cos(math.radians(35)) * 0.0045), "hw_hazard_amber", rot=(0, 35, 0))
    b.cyl(0.0028, 0.0010, (0.0, -0.0762, gz), "hw_dark", axis="y", sides=8)

    # Carry bail (steel) with a ribbed rubber grip, fixed to the brackets.
    outer = [(-0.0705, 0.1630), (-0.0705, 0.2150), (-0.0420, 0.2446), (0.0420, 0.2446), (0.0705, 0.2150), (0.0705, 0.1630)]
    inner = [(0.0645, 0.1630), (0.0645, 0.2200), (0.0380, 0.2326), (-0.0380, 0.2326), (-0.0645, 0.2200), (-0.0645, 0.1630)]
    b.prism(outer + inner, 0.0100, (0.0, 0.0, 0.0), "hw_steel", plane="xz", bevel=0.0012)
    b.fluted(0.0080, 0.0600, (0.0, 0.0, 0.2386), "hw_rubber", flutes=8, depth=0.0014, axis="x")
    for s in (-1, 1):
        b.box((0.0035, 0.0178, 0.0170), (s * 0.0317, 0.0, 0.2386), "hw_steel", bevel=0.0008)

    # Cap (turns about Z): knurled skirt, lid, key bar, bolts, unscrew arrows, index mark.
    b.fluted(0.0580, 0.0200, (0.0, 0.0, 0.2016), "hw_dark", flutes=20, depth=0.0026, axis="z", part="cap")
    lathe(b, [(0.2116, 0.0), (0.2116, 0.0565), (0.2136, 0.0580), (0.2200, 0.0580), (0.2236, 0.0520), (0.2236, 0.0)], (0, 0, 0), "hw_metal", axis="z", sides=20, part="cap")
    b.box((0.0120, 0.1000, 0.0034), (0.0, 0.0, 0.2253), "hw_steel", bevel=0.0010, part="cap")
    for sy_ in (-1, 1):
        b.bolt((0.0, sy_ * 0.0400, 0.2270), "hw_dark", axis="z", radius=0.0040, height=0.0014, part="cap")
    for sx_ in (-1, 1):
        b.prism([(-0.0030, -0.0120), (0.0030, -0.0120), (0.0030, 0.0040), (0.0070, 0.0040), (0.0, 0.0140), (-0.0070, 0.0040), (-0.0030, 0.0040)],
                0.0008, (sx_ * 0.0300, -sx_ * 0.0240, 0.2240), "hw_hazard_amber", plane="xy", part="cap", rot=(0, 0, 0 if sx_ > 0 else 180))
    b.box((0.0012, 0.0100, 0.0120), (0.0, -0.0585, 0.1990), "hw_hazard_amber", part="cap")
    b.cyl(0.0545, 0.0016, (0.0, 0.0, 0.1924), "hw_rubber", axis="z", sides=20, part="cap")  # seal collar

    root = b.build()
    kit.animate(root, "use_canister", [(0, {"location": (0, 0, 0)}), (8, {"location": (0, 0, 0.010)}), (24, {"location": (0, 0, 0)})])
    pos = (0.0, 0.0, cap_z)
    kit.animate(b.holders["cap"], "use_canister", [(0, {"location": pos, "rotation": (0, 0, 0)}), (12, {"location": pos, "rotation": (0, 0, 32)}), (24, {"location": pos, "rotation": (0, 0, 0)})])
    kit.check_bounds(root, *kit.REFERENCE_BOUNDS["hw_canister"])
    return root


MODELS = {
    "wrench": (build_wrench, "tools/hw_wrench.glb"),
    "sealant": (build_sealant, "tools/hw_sealant.glb"),
    "canister": (build_canister, "tools/hw_canister.glb"),
}


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
