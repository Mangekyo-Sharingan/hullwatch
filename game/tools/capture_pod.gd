## Captures a standing pod with machines fitted, for review evidence (M13.3/M13.5).
## Must run WINDOWED (rendering required):
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --path game --resolution 1600x900 --script res://tools/capture_pod.gd
extends SceneTree

const OUTPUT_DIR: String = "user://captures"
const OUTPUT_NAME: String = "shot_pod_machines.png"
const HARDPOINT: StringName = &"hp_life_support"
const MODULE: StringName = &"workshop"
const MACHINES: Array[StringName] = [&"work_bench", &"grow_rack", &"battery_cabinet"]

var _main: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	await process_frame
	var cargo: Node = _main.get_node("Systems/CargoSystem")
	var modules: Node = _main.get_node("Systems/ModuleSystem")
	for kind: StringName in [&"metal", &"ice", &"ore", &"exotic"]:
		cargo.call("add_material", kind, 25.0)
	var plate: Node = _main.get_node_or_null("ShipGeometry/HullExterior/DockPlate_life_support")
	if plate == null:
		print("FAIL: no mount plate")
		quit(1)
		return
	plate.call("get_actions")
	if not bool(plate.call("select_action", StringName("build:" + String(MODULE)))):
		print("FAIL: could not start the build")
		quit(1)
		return
	modules.call("sim_tick", 48.0)
	await process_frame
	for index: int in MACHINES.size():
		var socket_id: StringName = StringName("%s:%d" % [String(HARDPOINT), index])
		if not bool(modules.call("fit_machine", MACHINES[index], socket_id)):
			print("FAIL: could not fit ", MACHINES[index])
	modules.call("sim_tick", 48.0)
	await process_frame
	var pod: Node = _main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_life_support")
	if pod == null:
		print("FAIL: the pod is not standing")
		quit(1)
		return
	var player: Node3D = _main.get_node("Player")
	if player.has_method("release_tether"):
		player.call("release_tether")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var pod_z: float = -11.05
	player.global_position = Vector3(-4.4, 0.1, pod_z)
	player.look_at(Vector3(-7.0, 0.9, pod_z), Vector3.UP)
	var work_light: OmniLight3D = OmniLight3D.new()
	work_light.light_energy = 4.0
	work_light.omni_range = 12.0
	work_light.position = Vector3(0.8, -0.3, -0.8)
	player.add_child(work_light)
	for i: int in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var error: Error = image.save_png(OUTPUT_DIR + "/" + OUTPUT_NAME)
	if error != OK:
		print("FAIL: could not save the capture (", error, ")")
		quit(1)
		return
	print("PASS: capture_pod -> ", ProjectSettings.globalize_path(OUTPUT_DIR + "/" + OUTPUT_NAME))
	quit(0)
