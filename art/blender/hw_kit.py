"""Shared helpers for the hands-on model pass (build_hands_on_*.py).

Every model is authored Z-up, floor/back-centre origin, front toward Blender -Y (which the glTF
export maps to Godot +Z). Geometry is faceted: chamfered boxes, low-sided cylinders, extruded
polygons. Parts are merged per (part name, material) so each model stays at a handful of nodes.

The layout generator fits colliders and wall/floor placement to each model's bounds, so a
replacement MUST keep the footprint of the model it replaces: `check_bounds` fails the build
when it drifts.
"""

import json
import math
import os
import struct

import bmesh
import bpy
from mathutils import Euler, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELS = os.environ.get("HW_MODELS_DIR") or os.path.join(ROOT, "game", "assets", "models", "hullwatch")
SOURCES = os.environ.get("HW_SOURCES_DIR") or os.path.join(ROOT, "art", "blender")

# name: (linear base colour, metallic, roughness, emission colour, emission strength)
PALETTE = {
    "hw_beige": ((0.72, 0.68, 0.58), 0.05, 0.65, None, 0.0),
    "hw_dark": ((0.07, 0.07, 0.08), 0.1, 0.5, None, 0.0),
    "hw_metal": ((0.33, 0.35, 0.39), 0.7, 0.35, None, 0.0),
    "hw_steel": ((0.52, 0.54, 0.57), 0.85, 0.3, None, 0.0),
    "hw_rubber": ((0.025, 0.025, 0.028), 0.0, 0.88, None, 0.0),
    "hw_hazard_amber": ((0.62, 0.36, 0.05), 0.0, 0.55, None, 0.0),
    "hw_hazard_red": ((0.06, 0.02, 0.02), 0.0, 0.45, (1.0, 0.22, 0.16), 2.0),
    "hw_teal": ((0.38, 0.52, 0.54), 0.0, 0.7, None, 0.0),
    "hw_phosphor_green": ((0.02, 0.06, 0.03), 0.0, 0.45, (0.32, 1.0, 0.47), 1.9),
    "hw_phosphor_amber": ((0.07, 0.05, 0.02), 0.0, 0.4, (1.0, 0.65, 0.22), 2.0),
}

# Footprints (Blender axes, metres) of the shipped models these replace; see check_bounds.
REFERENCE_BOUNDS = {
    "hw_scanner": ((-0.0366, -0.0896, 0.0), (0.036, 0.1231, 0.138)),
    "hw_multimeter": ((-0.058, -0.0432, -0.0002), (0.058, 0.0283, 0.1702)),
    "hw_wrench": ((-0.0159, -0.1601, -0.003), (0.0168, 0.1151, 0.08)),
    "hw_sealant": ((-0.044, -0.1459, -0.002), (0.044, 0.1586, 0.086)),
    "hw_cutter": ((-0.031, -0.0691, 0.0), (0.0313, 0.1959, 0.182)),
    "hw_canister": ((-0.076, -0.078, 0.0006), (0.076, 0.076, 0.2466)),
    "hw_probe": ((-0.11, -0.065, -0.01), (0.11, 0.0, 0.28)),
    "hw_manual_stand": ((-0.275, -0.25, 0.0), (0.275, 0.25, 1.1577)),
    "hw_breaker_cabinet": ((-0.35, -0.1975, 0.0), (0.35, 0.0, 1.0)),
    "hw_bunk": ((-0.5, -1.0, 0.0), (0.5, 1.0, 0.7)),
    "hw_galley_unit": ((-0.6, -0.3, 0.0), (0.6, 0.3, 0.9)),
    "hw_wall_computer": ((-0.32, -0.11, -0.37), (0.32, 0.05, 0.37)),
}

_materials: dict = {}


def material(name: str) -> bpy.types.Material:
    if name in _materials:
        return _materials[name]
    base, metallic, roughness, emit, strength = PALETTE[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*base, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emit is not None:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    _materials[name] = mat
    return mat


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


AXIS_TILT = {"z": None, "x": (0.0, 90.0, 0.0), "y": (90.0, 0.0, 0.0)}


def _rotation(degrees) -> "Matrix":
    return Euler(tuple(math.radians(a) for a in degrees), "XYZ").to_matrix().to_4x4()


class Builder:
    """Collects faceted geometry into per-(part, material) meshes under one root empty."""

    def __init__(self, root_name: str) -> None:
        self.root_name = root_name
        self._bms: dict = {}
        self._pivots: dict = {}

    def pivot(self, part: str, point) -> None:
        """Make `part` a movable node: an empty at `point` whose mesh children keep world position.
        The empty carries the part's name, so animations (and the game) address it by that name."""
        self._pivots[part] = Vector(point)

    # -- plumbing -------------------------------------------------------------------------
    def add_mesh(self, src: bmesh.types.BMesh, part: str, mat: str, rot, center) -> None:
        """Move a finished bmesh into this model's (part, material) bucket; `rot` is an Euler in
        degrees or None. Use for geometry the primitives below cannot express."""
        if rot is not None:
            bmesh.ops.transform(src, matrix=_rotation(rot), verts=src.verts)
        bmesh.ops.translate(src, vec=Vector(center), verts=src.verts)
        key = (part, mat)
        if key not in self._bms:
            self._bms[key] = bmesh.new()
        dst = self._bms[key]
        mapping = {v: dst.verts.new(v.co) for v in src.verts}
        for f in src.faces:
            dst.faces.new([mapping[v] for v in f.verts])
        src.free()

    @staticmethod
    def chamfer(bm: bmesh.types.BMesh, amount: float) -> None:
        if amount > 0.0:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=amount, offset_type="OFFSET", segments=1, affect="EDGES")

    # -- primitives -----------------------------------------------------------------------
    def box(self, size, center, mat, bevel=0.0, part="", rot=None, taper=None) -> None:
        """Chamfered box. taper=(sx, sy) scales the top (+z) face in x/y for a tapered body."""
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
        if taper is not None:
            for v in bm.verts:
                if v.co.z > 0:
                    v.co.x *= taper[0]
                    v.co.y *= taper[1]
        self.chamfer(bm, min(bevel, min(size) * 0.45))
        self.add_mesh(bm, part, mat, rot, center)

    def cyl(self, radius, length, center, mat, axis="z", sides=12, bevel=0.0, radius2=None, part="", rot=None) -> None:
        """Faceted cylinder or frustum along `axis` (x, y or z); radius2 sets the +axis end."""
        bm = bmesh.new()
        r2 = radius if radius2 is None else radius2
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=sides, radius1=radius, radius2=r2, depth=length)
        self.chamfer(bm, min(bevel, min(radius, r2) * 0.45, length * 0.45))
        if AXIS_TILT[axis] is not None:
            bmesh.ops.transform(bm, matrix=_rotation(AXIS_TILT[axis]), verts=bm.verts)
        self.add_mesh(bm, part, mat, rot, center)

    def fluted(self, radius, length, center, mat, flutes=14, depth=0.0012, axis="z", part="", rot=None) -> None:
        """Knurled grip: a cylinder whose rim alternates between two radii."""
        bm = bmesh.new()
        ring = []
        for i in range(flutes * 2):
            a = math.pi * i / flutes
            r = radius if i % 2 == 0 else radius - depth
            ring.append((math.cos(a) * r, math.sin(a) * r))
        bottom = [bm.verts.new((x, y, -length / 2)) for x, y in ring]
        top = [bm.verts.new((x, y, length / 2)) for x, y in ring]
        n = len(ring)
        for i in range(n):
            bm.faces.new([bottom[i], bottom[(i + 1) % n], top[(i + 1) % n], top[i]])
        bm.faces.new(list(reversed(bottom)))
        bm.faces.new(top)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        if AXIS_TILT[axis] is not None:
            bmesh.ops.transform(bm, matrix=_rotation(AXIS_TILT[axis]), verts=bm.verts)
        self.add_mesh(bm, part, mat, rot, center)

    def prism(self, outline, depth, center, mat, plane="xz", bevel=0.0, part="", rot=None) -> None:
        """Extrude a 2D outline. plane xz extrudes along Y, xy along Z, yz along X; the outline
        is in the plane's two axes in that order and `center` is the middle of the extrusion."""
        bm = bmesh.new()
        axes = {"xz": (0, 2, 1), "xy": (0, 1, 2), "yz": (1, 2, 0)}[plane]

        def pt(p, d):
            v = [0.0, 0.0, 0.0]
            v[axes[0]], v[axes[1]], v[axes[2]] = p[0], p[1], d
            return v

        near = [bm.verts.new(pt(p, -depth / 2)) for p in outline]
        far = [bm.verts.new(pt(p, depth / 2)) for p in outline]
        n = len(outline)
        for i in range(n):
            bm.faces.new([near[i], near[(i + 1) % n], far[(i + 1) % n], far[i]])
        bm.faces.new(list(reversed(near)))
        bm.faces.new(far)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        self.chamfer(bm, min(bevel, depth * 0.45))
        self.add_mesh(bm, part, mat, rot, center)

    def bolt(self, center, mat, axis="y", radius=0.003, height=0.0016, part="") -> None:
        """Hex bolt head sitting on a face; `axis` is the outward normal (+/-x, +/-y, +/-z)."""
        sign = -1.0 if axis.startswith("-") else 1.0
        name = axis.lstrip("-")
        offset = Vector({"x": (1, 0, 0), "y": (0, 1, 0), "z": (0, 0, 1)}[name]) * (sign * height / 2)
        self.cyl(radius, height, Vector(center) + offset, mat, axis=name, sides=6, part=part)

    def vents(self, count, slot, start, step, mat, part="") -> None:
        """A run of thin slots; slot=(sx, sy, sz), start is the first centre, step the delta."""
        for i in range(count):
            self.box(slot, Vector(start) + Vector(step) * i, mat, bevel=min(slot) * 0.2, part=part)

    # -- output ---------------------------------------------------------------------------
    def build(self) -> bpy.types.Object:
        scene = bpy.context.scene
        root = bpy.data.objects.new(self.root_name, None)
        scene.collection.objects.link(root)
        holders: dict = {}
        for (part, mat), bm in self._bms.items():
            parent = root
            name = f"{self.root_name}_{part or mat.removeprefix('hw_')}"
            if part in self._pivots:
                if part not in holders:
                    holder = bpy.data.objects.new(name, None)
                    scene.collection.objects.link(holder)
                    holder.parent = root
                    holder.location = self._pivots[part]
                    holders[part] = holder
                parent = holders[part]
                name = f"{name}_{mat.removeprefix('hw_')}"
                bmesh.ops.translate(bm, vec=-self._pivots[part], verts=bm.verts)
            mesh = bpy.data.meshes.new(name)
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            bm.to_mesh(mesh)
            bm.free()
            for p in mesh.polygons:
                p.use_smooth = False
            mesh.materials.append(material(mat))
            obj = bpy.data.objects.new(name, mesh)
            scene.collection.objects.link(obj)
            obj.parent = parent
        self._bms.clear()
        self.holders = holders
        return root


def bounds(root: bpy.types.Object):
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for o in root.children_recursive:
        if o.type != "MESH":
            continue
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            mn = Vector(min(mn[i], w[i]) for i in range(3))
            mx = Vector(max(mx[i], w[i]) for i in range(3))
    return mn, mx


def triangles(root: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for o in root.children_recursive if o.type == "MESH" for p in o.data.polygons)


def check_bounds(root: bpy.types.Object, ref_min, ref_max, tol: float = 0.002) -> None:
    """Fail the build if the model's footprint drifts from the one it replaces."""
    bpy.context.view_layer.update()
    mn, mx = bounds(root)
    bad = [f"{ax} {lab}: {got:.4f} vs {want:.4f}" for ax, i in (("x", 0), ("y", 1), ("z", 2))
           for lab, got, want in (("min", mn[i], ref_min[i]), ("max", mx[i], ref_max[i])) if abs(got - want) > tol]
    if bad:
        raise SystemExit(f"{root.name}: footprint drifted beyond {tol * 1000:.0f} mm: " + "; ".join(bad))


def animate(obj: bpy.types.Object, action: str, keys: list) -> None:
    """keys: [(frame, {"location": (...), "rotation": (deg...), "scale": (...)})] at 24 fps; the
    exported action name is what the game plays (`use_*` for tools, `toggle_*`, `unfold`, ...)."""
    obj.rotation_mode = "XYZ"
    for frame, pose in keys:
        if "location" in pose:
            obj.location = pose["location"]
            obj.keyframe_insert("location", frame=frame)
        if "rotation" in pose:
            obj.rotation_euler = tuple(math.radians(a) for a in pose["rotation"])
            obj.keyframe_insert("rotation_euler", frame=frame)
        if "scale" in pose:
            obj.scale = pose["scale"]
            obj.keyframe_insert("scale", frame=frame)
    obj.animation_data.action.name = action


def export(root: bpy.types.Object, glb_relpath: str, blend_name: str | None = None) -> None:
    """Write the glTF (and optionally a .blend source) for a built model."""
    path = os.path.join(MODELS, glb_relpath)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if blend_name:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCES, blend_name))
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_yup=True,
        export_apply=True,
    )
    merge_animations(path)


def merge_animations(path: str) -> None:
    """Blender exports one glTF animation per action ("use_x", "use_x.001", ...), one per moving
    node; the game plays every `use*` animation it finds, so the last would win. Fold each family
    into a single animation holding all of its channels."""
    data = bytearray(open(path, "rb").read())
    json_len = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + json_len])
    rest = bytes(data[20 + json_len:])
    families: dict = {}
    for anim in doc.get("animations", []):
        families.setdefault(anim["name"].split(".")[0], []).append(anim)
    merged = []
    for name, group in families.items():
        channels, samplers = [], []
        for anim in group:
            base = len(samplers)
            samplers += anim["samplers"]
            channels += [{**c, "sampler": c["sampler"] + base} for c in anim["channels"]]
        merged.append({"name": name, "channels": channels, "samplers": samplers})
    if merged:
        doc["animations"] = merged
    blob = json.dumps(doc, separators=(",", ":")).encode()
    blob += b" " * (-len(blob) % 4)
    out = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(blob) + len(rest)) + struct.pack("<I4s", len(blob), b"JSON") + blob + rest
    open(path, "wb").write(out)
