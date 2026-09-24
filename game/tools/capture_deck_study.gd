## Captures the M13.4 deck study grey-block from two angles for the design review.
## WINDOWED run (rendering required):
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --path game --resolution 1600x900 --script res://tools/capture_deck_study.gd
extends SceneTree

const OUTPUT_DIR: String = "user://captures"
const SCENE_PATH: String = "res://scenes/deck_study.tscn"
const LOOK_AT: Vector3 = Vector3(0.0, 1.9, 0.0)
const VIEWS: Array[Dictionary] = [
	{"name": "study_deck_three_quarter.png", "position": Vector3(8.5, 5.2, 9.0)},
	{"name": "study_deck_section.png", "position": Vector3(0.0, 2.4, 12.5)},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		print("FAIL: deck study scene missing: ", SCENE_PATH)
		quit(1)
		return
	var study: Node3D = packed.instantiate() as Node3D
	root.add_child(study)
	_add_lighting()
	await process_frame
	var camera: Camera3D = Camera3D.new()
	camera.fov = 55.0
	root.add_child(camera)
	camera.current = true
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	for view: Dictionary in VIEWS:
		camera.global_position = view["position"] as Vector3
		camera.look_at(LOOK_AT, Vector3.UP)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		image.save_png(OUTPUT_DIR + "/" + String(view["name"]))
	print("PASS: capture_deck_study -> ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _add_lighting() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.09, 0.1, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.55, 0.6, 1.0)
	environment.ambient_light_energy = 0.6
	world.environment = environment
	root.add_child(world)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, -35.0, 0.0)
	key.light_energy = 1.2
	root.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, 140.0, 0.0)
	fill.light_energy = 0.5
	root.add_child(fill)
