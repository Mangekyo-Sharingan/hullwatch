extends SceneTree

var _main: Node3D
var _camera: Camera3D
var _torch: SpotLight3D
var _folder: String
var _views: Array[Dictionary] = []
var _failed: bool = false

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	_folder = "user://interior_gate"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_folder = argument.trim_prefix("--output=")
	if DirAccess.make_dir_recursive_absolute(_folder) != OK:
		_fail("Cannot create capture directory")
		return
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	await physics_frame
	root.get_node("SimClock").call("set_paused", true)
	_main.get_node("Player").set_physics_process(false)
	for layer: Node in _main.find_children("*", "CanvasLayer", true, false):
		if layer.name != &"AnalogueFilter":
			(layer as CanvasLayer).visible = false
	_camera = Camera3D.new()
	_camera.near = 0.05
	_camera.fov = 80.0
	_main.add_child(_camera)
	_camera.make_current()
	_torch = _main.get_node("Player/Head/Camera3D/Flashlight").duplicate() as SpotLight3D
	_camera.add_child(_torch)
	_torch.visible = false
	for door: Node in get_nodes_in_group(&"ship_door"):
		if door is Door and (door as Door).airlock_side != &"outer":
			if not (door as Door).request_open(true):
				_fail("Interior door refused opening: " + String(door.name))
	for frame: int in 45:
		await physics_frame
	for index: int in TubeLayout.sections().size():
		if not TubeLayout.is_walkable(index):
			continue
		var section: Dictionary = TubeLayout.sections()[index]
		var bounds: Vector2 = TubeLayout.span(index)
		var eye: Vector3 = Vector3(1.05 if String(section["name"]) == "cupola" else 0.0, 1.55, (bounds.x + bounds.y) * 0.5)
		var area: String = "cabin_" + String(section["name"])
		for facing: String in ["bow", "stern", "port", "starboard", "ceiling", "deck"]:
			var direction: Vector3 = {"bow": Vector3.FORWARD, "stern": Vector3.BACK, "port": Vector3.LEFT, "starboard": Vector3.RIGHT, "ceiling": Vector3.UP, "deck": Vector3.DOWN}[facing]
			await _capture(area, facing, eye, eye + direction, false)
	for index: int in TubeLayout.sections().size() - 1:
		if not TubeLayout.has_hatch(index) or not TubeLayout.is_walkable(index + 1):
			continue
		var middle: float = (TubeLayout.span(index).y + TubeLayout.span(index + 1).x) * 0.5
		var area: String = "joint_" + String(TubeLayout.sections()[index]["name"])
		for side: float in [-1.0, 1.0]:
			await _capture(area, "bow" if side < 0.0 else "stern", Vector3(0.65 * side, 1.55, middle + side * 0.7), Vector3(0.0, 1.1, middle), false)
		var leaf: Door
		for node: Node in get_nodes_in_group(&"ship_door"):
			if node is Door and absf((node as Door).global_position.z - middle) < 0.05 and (node as Door).airlock_side != &"outer":
				leaf = node as Door
				break
		if leaf == null or not leaf.request_open(false):
			_fail("Cannot close joint door for review: " + area)
			return
		for frame: int in 45:
			await physics_frame
		for side: float in [-1.0, 1.0]:
			await _capture(area, "bow_closed" if side < 0.0 else "stern_closed", Vector3(0.65 * side, 1.55, middle + side * 0.7), Vector3(0.0, 1.1, middle), false)
		if not leaf.request_open(true):
			_fail("Cannot restore joint door after review: " + area)
			return
		for frame: int in 45:
			await physics_frame
	for bay: Dictionary in TubeLayout.service_bays():
		var center_z: float = float(bay["center_z"])
		var apron_x: float = float(bay["inner_x"]) + float(bay["side"]) * 0.5
		var area: String = "bay_" + String(bay["name"])
		await _capture(area, "entry", Vector3(0.0, 1.55, center_z), Vector3(float(bay["outer_x"]), 1.2, center_z), false)
		await _capture(area, "service", Vector3(apron_x, 1.55, center_z), Vector3(float(bay["outer_x"]), 1.0, center_z), false)
		await _capture(area, "return", Vector3(apron_x, 1.55, center_z), Vector3(0.0, 1.2, center_z), false)
	for plate: Node in get_nodes_in_group(&"dock_plate"):
		if plate is ModuleMount:
			var mount: ModuleMount = plate as ModuleMount
			await _capture("dock_" + String(mount.hardpoint_id), "entry", Vector3(0.0, 1.55, mount.global_position.z), Vector3(mount.global_position.x, 1.2, mount.global_position.z), false)
	await _capture_pods()
	if _failed:
		return
	var file: FileAccess = FileAccess.open(_folder.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write capture manifest")
		return
	file.store_string(JSON.stringify({"views": _views, "fov": 80.0, "resolution": [root.size.x, root.size.y], "lighting": "Normal game lighting; existing player flashlight for pod inspection", "simulation": "Paused fresh scene, fixture materials only; no save writes"}, "\t"))
	print("PASS: capture_interior_gate (", _views.size(), " views)")
	quit(0)

func _capture_pods() -> void:
	var modules: ModuleSystem = _main.get_node("Systems/ModuleSystem") as ModuleSystem
	var cargo: CargoSystem = _main.get_node("Systems/CargoSystem") as CargoSystem
	cargo.set_capacity_source(&"interior_gate_fixture", 1000.0)
	for module: ShipModule in modules.get_catalog():
		for kind: Variant in module.cost:
			cargo.add_material(StringName(kind), maxf(float(module.cost[kind]) - cargo.get_units(StringName(kind)), 0.0))
		if not modules.start_build(module.module_id):
			_fail("Capture fixture cannot build " + String(module.module_id))
			return
		modules.sim_tick(module.build_hours + 0.1)
		await process_frame
		await physics_frame
		var pod: Node3D = _main.get_node_or_null("ShipGeometry/HullExterior/Pod_" + String(module.hardpoint_id)) as Node3D
		if pod == null:
			_fail("Missing built pod " + String(module.module_id))
			return
		var area: String = "pod_" + String(module.module_id)
		await _capture(area, "entry", pod.to_global(Vector3(0.5, 1.55, 0.0)), pod.to_global(Vector3(3.5, 1.1, 0.0)), true)
		await _capture(area, "return", pod.to_global(Vector3(2.3, 1.55, 0.0)), pod.to_global(Vector3(0.0, 1.1, 0.0)), true)
		await _capture(area, "panel", pod.to_global(Vector3(2.3, 1.55, 0.0)), pod.to_global(Vector3(2.0, 1.3, 1.58)), true)
		if module.module_id == &"utility_pod":
			await _capture_loadouts(modules, cargo, pod, module.hardpoint_id)
		if not modules.uninstall(module.module_id):
			_fail("Capture fixture cannot remove " + String(module.module_id))
			return
		await process_frame
		await physics_frame

func _capture_loadouts(modules: ModuleSystem, cargo: CargoSystem, pod: Node3D, hardpoint: StringName) -> void:
	var machines: Array[ShipMachine] = modules.get_machine_catalog()
	machines.sort_custom(func(a: ShipMachine, b: ShipMachine) -> bool: return a.portable and not b.portable)
	for machine: ShipMachine in machines:
		for slot: int in 3:
			for kind: Variant in machine.cost:
				cargo.add_material(StringName(kind), maxf(float(machine.cost[kind]) - cargo.get_units(StringName(kind)), 0.0))
			if not modules.fit_machine(machine.machine_id, StringName("%s:%d" % [hardpoint, slot])):
				_fail("Cannot fit inspection loadout " + String(machine.machine_id))
				return
		modules.sim_tick(machine.build_hours + 0.1)
		await process_frame
		await physics_frame
		var area: String = "fitted_" + String(machine.machine_id)
		await _capture(area, "entry", pod.to_global(Vector3(0.5, 1.55, 0.0)), pod.to_global(Vector3(3.55, 1.0, 0.0)), true)
		await _capture(area, "service", pod.to_global(Vector3(2.3, 1.55, -0.5)), pod.to_global(Vector3(3.55, 0.8, 0.0)), true)
		if not machine.portable:
			# ponytail: one bolted catalog machine; rebuild the pod per case if more are added.
			if machine != machines[-1]:
				_fail("Multiple bolted loadouts require separate pod fixtures")
			return
		for slot: int in 3:
			if not modules.remove_machine(StringName("%s:%d" % [hardpoint, slot])):
				_fail("Cannot remove inspection loadout " + String(machine.machine_id))
				return
		await process_frame
		await physics_frame

func _capture(area: String, view: String, eye: Vector3, target: Vector3, flashlight: bool) -> void:
	if _failed:
		return
	_camera.position = eye
	_camera.look_at(target, Vector3.FORWARD if absf((target - eye).normalized().y) > 0.99 else Vector3.UP)
	_torch.visible = flashlight
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var filename: String = area + "_" + view + ".png"
	if root.get_texture().get_image().save_png(_folder.path_join(filename)) != OK:
		_fail("Cannot capture " + filename)
		return
	_views.append({"area": area, "view": view, "file": filename, "eye": [eye.x, eye.y, eye.z], "target": [target.x, target.y, target.z], "flashlight": flashlight})
	print("CAPTURE: ", filename)

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
