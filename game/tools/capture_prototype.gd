## Captures the prototype station grey-block from three angles for design review.
## WINDOWED run (rendering required):
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --path game --resolution 1600x900 --script res://tools/capture_prototype.gd
extends SceneTree

const OUTPUT_DIR: String = "user://captures"
const SCENE_PATH: String = "res://scenes/hull_study.tscn"
const LOOK_AT: Vector3 = Vector3(0.0, 0.0, -4.0)
const VIEWS: Array[Dictionary] = [
	{"name": "study_hull_three_quarter.png", "position": Vector3(17.0, 9.0, 16.0)},
	{"name": "study_hull_broadside.png", "position": Vector3(26.0, 1.0, -3.0)},
	{"name": "study_hull_bow.png", "position": Vector3(5.0, 3.0, -32.0)},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		print("FAIL: prototype scene missing: ", SCENE_PATH)
		quit(1)
		return
	var station: Node3D = packed.instantiate() as Node3D
	root.add_child(station)
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
	print("PASS: capture_prototype -> ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _add_lighting() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.01, 0.012, 0.02)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.38, 0.45)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = environment
	root.add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_energy = 1.6
	sun.rotation_degrees = Vector3(-32.0, 128.0, 0.0)
	root.add_child(sun)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.light_energy = 0.5
	fill.rotation_degrees = Vector3(24.0, -50.0, 0.0)
	root.add_child(fill)
