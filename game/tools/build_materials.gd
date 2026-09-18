## Rebuilds the shared StandardMaterial3D resources from the imported M3 PBR texture sets.
## Re-run after changing texture sets or the table below:
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/build_materials.gd
extends SceneTree

const OUTPUT_DIR: String = "res://src/data/materials"

const MATERIALS: Dictionary = {
	&"mat_floor_grate": {
		"albedo": "res://assets/textures/metal_grate_rusty/metal_grate_rusty_diff_2k.jpg",
		"normal": "res://assets/textures/metal_grate_rusty/metal_grate_rusty_nor_gl_2k.jpg",
		"roughness": "res://assets/textures/metal_grate_rusty/metal_grate_rusty_rough_2k.jpg",
		"metal": "res://assets/textures/metal_grate_rusty/metal_grate_rusty_metal_2k.jpg",
		"metallic": 1.0,
		"uv_scale": Vector2(4.0, 4.0),
	},
	&"mat_wall_painted": {
		"albedo": "res://assets/textures/painted_metal_shutter/painted_metal_shutter_diff_2k.jpg",
		"normal": "res://assets/textures/painted_metal_shutter/painted_metal_shutter_nor_gl_2k.jpg",
		"roughness": "res://assets/textures/painted_metal_shutter/painted_metal_shutter_rough_2k.jpg",
		"metal": "",
		"metallic": 0.2,
		"uv_scale": Vector2(4.0, 4.0),
	},
	&"mat_wall_container": {
		"albedo": "res://assets/textures/container_side/container_side_diff_2k.jpg",
		"normal": "res://assets/textures/container_side/container_side_nor_gl_2k.jpg",
		"roughness": "res://assets/textures/container_side/container_side_rough_2k.jpg",
		"metal": "",
		"metallic": 0.5,
		"uv_scale": Vector2(4.0, 4.0),
	},
	&"mat_panel_scratched": {
		"albedo": "res://assets/textures/metal_plate/metal_plate_diff_2k.jpg",
		"normal": "res://assets/textures/metal_plate/metal_plate_nor_gl_2k.jpg",
		"roughness": "res://assets/textures/metal_plate/metal_plate_rough_2k.jpg",
		"metal": "res://assets/textures/metal_plate/metal_plate_metal_2k.jpg",
		"metallic": 1.0,
		"uv_scale": Vector2(2.0, 2.0),
	},
	&"mat_metal_rusted": {
		"albedo": "res://assets/textures/rusty_metal/rusty_metal_diff_2k.jpg",
		"normal": "res://assets/textures/rusty_metal/rusty_metal_nor_gl_2k.jpg",
		"roughness": "res://assets/textures/rusty_metal/rusty_metal_rough_2k.jpg",
		"metal": "",
		"metallic": 0.8,
		"uv_scale": Vector2(2.0, 2.0),
	},
}


func _initialize() -> void:
	var failures: int = 0
	var output_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var make_error: Error = DirAccess.make_dir_recursive_absolute(output_path)
	if make_error != OK and make_error != ERR_ALREADY_EXISTS:
		print("FAIL: cannot create ", output_path, " (error ", make_error, ")")
		quit(1)
		return
	for material_name: StringName in MATERIALS:
		if not _write_material(material_name, MATERIALS[material_name]):
			failures += 1
	if failures == 0:
		print("PASS: build_materials (%d materials)" % MATERIALS.size())
		quit(0)
	else:
		print("FAILURES: ", failures)
		quit(1)


func _write_material(material_name: StringName, spec: Dictionary) -> bool:
	var material: StandardMaterial3D = _build_material(spec)
	if material == null:
		print("FAIL: ", material_name, " (missing texture)")
		return false
	var path: String = OUTPUT_DIR + "/" + String(material_name) + ".tres"
	var save_error: Error = ResourceSaver.save(material, path)
	if save_error != OK:
		print("FAIL: ", material_name, " (save error ", save_error, ")")
		return false
	return _verify_material(material_name, path)


func _build_material(spec: Dictionary) -> StandardMaterial3D:
	var albedo: Texture2D = load(spec["albedo"]) as Texture2D
	var normal: Texture2D = load(spec["normal"]) as Texture2D
	var roughness: Texture2D = load(spec["roughness"]) as Texture2D
	if albedo == null or normal == null or roughness == null:
		return null
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = albedo
	material.normal_enabled = true
	material.normal_texture = normal
	material.roughness_texture = roughness
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.roughness = 1.0
	material.metallic = spec["metallic"]
	var metal_path: String = spec["metal"]
	if metal_path != "":
		var metal: Texture2D = load(metal_path) as Texture2D
		if metal == null:
			return null
		material.metallic_texture = metal
		material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	var uv_scale: Vector2 = spec["uv_scale"]
	material.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	return material


func _verify_material(material_name: StringName, path: String) -> bool:
	if not ResourceLoader.exists(path):
		print("FAIL: ", material_name, " (not saved at ", path, ")")
		return false
	var loaded: StandardMaterial3D = load(path) as StandardMaterial3D
	if loaded == null or loaded.albedo_texture == null or loaded.normal_texture == null or loaded.roughness_texture == null:
		print("FAIL: ", material_name, " (saved resource incomplete)")
		return false
	print("OK: ", path, " (metallic=", loaded.metallic, " uv1_scale=", loaded.uv1_scale, ")")
	return true
