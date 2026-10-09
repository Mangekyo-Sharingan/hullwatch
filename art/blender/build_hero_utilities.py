"""Original wall utility fitting; rebuild with Blender --background --python this_file.

Blender Z up / -Y front; origin is the mounting back plane center.
Exports one static mesh, four palette materials, no collision or animation.
"""

import json
import math
from pathlib import Path
import struct

import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
BLEND = ROOT / "art/blender/hero_utilities.blend"
GLB = ROOT / "game/assets/models/hullwatch/interior/hw_utility_spine.glb"


def material(name: str, color: tuple, metallic: float, roughness: float) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    vertex_color = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    vertex_color.layer_name = "Color"
    mat.node_tree.links.new(vertex_color.outputs["Color"], shader.inputs["Base Color"])
    return mat


def finish(obj: bpy.types.Object, name: str, mat: bpy.types.Material,
           bevel: float = 0.0, tint: tuple = (1.0, 1.0, 1.0, 1.0)) -> bpy.types.Object:
    obj.name = name
    obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("machined_edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    colors = obj.data.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
    for polygon in obj.data.polygons:
        for index in polygon.loop_indices:
            point = obj.matrix_world @ obj.data.vertices[obj.data.loops[index].vertex_index].co
            shade = 0.93 + 0.05 * math.sin(point.z * 37.0 + point.x * 19.0)
            colors.data[index].color = tuple(mat.diffuse_color[i] * tint[i] * shade for i in range(3)) + (1.0,)
    return obj


def box(name: str, size: tuple, location: tuple, mat: bpy.types.Material,
        bevel: float = 0.002) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.dimensions = size
    return finish(obj, name, mat, bevel)


def cylinder(name: str, start: tuple, end: tuple, radius: float,
             mat: bpy.types.Material, tint: tuple = (1.0, 1.0, 1.0, 1.0),
             sides: int = 12) -> bpy.types.Object:
    a, b = Vector(start), Vector(end)
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius,
                                       depth=(b - a).length, location=(a + b) / 2)
    obj = bpy.context.object
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return finish(obj, name, mat, 0.0007, tint)


def route(name: str, points: list, radius: float, mat: bpy.types.Material, tint: tuple) -> None:
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 3
    curve.bevel_depth = radius
    curve.bevel_resolution = 1
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, location in zip(spline.bezier_points, points):
        point.co = location
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    finish(bpy.context.object, name, mat, tint=tint)


def report_glb() -> None:
    """Measure exported positions through the actual glTF node transforms."""
    raw = GLB.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    binary = raw[28 + length:]
    low, high = Vector((math.inf,) * 3), Vector((-math.inf,) * 3)
    triangles = 0

    def visit(index: int, parent: Matrix) -> None:
        nonlocal triangles
        node = doc["nodes"][index]
        if "matrix" in node:
            local = Matrix([node["matrix"][i:i + 4] for i in range(0, 16, 4)]).transposed()
        else:
            q = node.get("rotation", (0, 0, 0, 1))
            local = Matrix.LocRotScale(Vector(node.get("translation", (0, 0, 0))),
                                       Quaternion((q[3], *q[:3])), Vector(node.get("scale", (1, 1, 1))))
        world = parent @ local
        if "mesh" in node:
            for primitive in doc["meshes"][node["mesh"]]["primitives"]:
                assert primitive.get("mode", 4) == 4
                accessor = doc["accessors"][primitive["attributes"]["POSITION"]]
                view = doc["bufferViews"][accessor["bufferView"]]
                offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
                assert accessor["componentType"] == 5126
                for vertex in range(accessor["count"]):
                    point = world @ Vector(struct.unpack_from("<3f", binary, offset + vertex * view.get("byteStride", 12)))
                    for axis in range(3):
                        low[axis] = min(low[axis], point[axis])
                        high[axis] = max(high[axis], point[axis])
                triangles += doc["accessors"][primitive["indices"]]["count"] // 3
        for child in node.get("children", []):
            visit(child, world)

    roots = doc["scenes"][doc.get("scene", 0)]["nodes"]
    assert len(roots) == 1 and doc["nodes"][roots[0]]["name"] == "hw_utility_spine"
    assert "animations" not in doc
    for index in roots:
        visit(index, Matrix.Identity(4))
    for axis, (minimum, maximum) in enumerate(((-0.25, 0.25), (-0.55, 0.55), (0.0, 0.16))):
        assert low[axis] >= minimum - 1e-6 and high[axis] <= maximum + 1e-6, (low, high)
        assert abs(low[axis] - minimum) < 1e-6 and abs(high[axis] - maximum) < 1e-6, (low, high)
    print(f"PASS: hw_utility_spine glTF bounds {tuple(low)} .. {tuple(high)}; {triangles} triangles")


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    beige = material("hw_beige", (0.68, 0.64, 0.55, 1.0), 0.0, 0.82)
    dark = material("hw_dark", (0.045, 0.043, 0.04, 1.0), 0.0, 0.9)
    metal = material("hw_metal", (0.47, 0.45, 0.41, 1.0), 0.52, 0.48)
    amber = material("hw_hazard_amber", (0.64, 0.30, 0.045, 1.0), 0.0, 0.72)
    copper = (1.0, 0.48, 0.20, 1.0)
    for x in (-0.225, 0.225):
        box("mount_channel", (0.05, 0.055, 1.1), (x, -0.0275, 0), beige)
    for z in (-0.523, 0.523):
        box("end_crossmember", (0.4, 0.055, 0.054), (0, -0.0275, z), beige)
    box("recessed_backpan", (0.4, 0.012, 0.99), (0, -0.018, 0), dark)
    for z in (-0.34, 0.01, 0.34):
        box("junction_housing", (0.22, 0.065, 0.21), (-0.028, -0.053, z), dark, 0.006)
        box("cover_gasket", (0.202, 0.008, 0.189), (-0.028, -0.087, z), metal)
        box("service_cover", (0.19, 0.016, 0.177), (-0.028, -0.098, z), beige, 0.004)
        for x in (-0.103, 0.047):
            for height in (z - 0.067, z + 0.067):
                cylinder("cover_fastener", (x, -0.106, height), (x, -0.11, height), 0.006, metal, sides=6)
                box("screw_slot", (0.006, 0.0008, 0.0012), (x, -0.1104, height), dark, 0)
    route("copper_feed", [(0.125, -0.08, -0.50), (0.15, -0.11, -0.43),
                           (0.15, -0.11, 0.42), (0.08, -0.08, 0.48)], 0.011, metal, copper)
    route("return_conduit", [(-0.165, -0.07, -0.48), (-0.174, -0.094, -0.40),
                              (-0.174, -0.094, 0.40), (-0.13, -0.07, 0.48)], 0.014, metal, (0.38, 0.4, 0.44, 1.0))
    for z in (-0.43, -0.19, 0.19, 0.43):
        for x, depth, radius in ((0.15, -0.11, 0.016), (-0.174, -0.094, 0.02)):
            cylinder("pipe_collar", (x, depth, z - 0.012), (x, depth, z + 0.012), radius, metal)
            box("clamp_foot", (0.042, 0.033, 0.04), (x, -0.04, z), beige)
            box("clamp_bridge", (0.046, 0.012, 0.016), (x, depth - radius, z), metal)
    for z in (-0.34, 0.01, 0.34):
        route("covered_branch", [(0.145, -0.11, z + 0.052), (0.10, -0.13, z + 0.052),
                                  (0.08, -0.147, z + 0.005), (0.054, -0.147, z - 0.035)], 0.013, dark, (1, 1, 1, 1))
        cylinder("branch_gland", (0.073, -0.147, z - 0.035), (0.055, -0.147, z - 0.035), 0.012, metal)
        box("branch_keeper", (0.024, 0.026, 0.018), (0.08, -0.147, z + 0.005), metal, 0.001)
    box("amber_safety_strip", (0.125, 0.0015, 0.012), (-0.028, -0.1069, 0.015), amber, 0.0004)
    for x in (-0.225, 0.225):
        for z in (-0.51, 0.51):
            cylinder("mount_bolt", (x, -0.055, z), (x, -0.061, z), 0.01, metal, sides=6)
        for z, width in ((-0.38, 0.014), (0.15, 0.018), (0.46, 0.011)):
            box("paint_scuff", (width, 0.0006, 0.003), (x + 0.014, -0.0552, z), metal, 0)

    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = "hw_utility_spine"
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.name = "hw_utility_spine_mesh"
    print(f"Authored mesh: {len(obj.data.polygons)} polygons")
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    GLB.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(GLB), export_format="GLB", use_selection=True,
                              export_animations=False, export_yup=True, export_apply=True)
    report_glb()


if __name__ == "__main__":
    main()
