extends "res://tools/capture_interior_gate.gd"

var _label: String = ""
var _states: Dictionary = {}

func _run() -> void:
	await process_frame
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_folder = argument.trim_prefix("--output=")
		elif argument.begins_with("--label="):
			_label = argument.trim_prefix("--label=")
	if not _folder.is_absolute_path() or _label not in ["before", "after"]:
		_fail("Required: -- --output=/absolute/path --label=before|after")
		return
	if DisplayServer.get_name() == "headless":
		_fail("Native rendering required")
		return
	if FileAccess.file_exists(_folder.path_join(_label + "_manifest.json")):
		_fail("Capture label already exists; preserve evidence or choose a fresh directory")
		return
	if DirAccess.make_dir_recursive_absolute(_folder) != OK:
		_fail("Cannot create capture directory")
		return
	root.get_node("SimClock").call("set_paused", true)
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	await physics_frame
	root.get_node("SimClock").call("set_paused", true)
	_main.get_node("Player").set_physics_process(false)
	for layer: Node in _main.find_children("*", "CanvasLayer", true, false):
		if layer.name != &"AnalogueFilter":
			(layer as CanvasLayer).visible = false
	var bus: Node = root.get_node("EventBus")
	var callback: Callable = Callable(_main.get_node("UI/GuideOverlay"), "_on_sim_event")
	if bus.is_connected(&"sim_event", callback):
		bus.disconnect(&"sim_event", callback)
	_camera = Camera3D.new()
	_camera.near = 0.05
	_camera.fov = 80.0
	_main.add_child(_camera)
	_camera.make_current()
	_torch = _main.get_node("Player/Head/Camera3D/Flashlight") as SpotLight3D
	_torch.visible = false
	for door: Node in get_nodes_in_group(&"ship_door"):
		if door is Door and (door as Door).airlock_side != &"outer":
			if not (door as Door).request_open(true):
				_fail("Interior door refused opening: " + String(door.name))
				return
	for frame: int in 45:
		await physics_frame
	var power: Node = _main.get_node("Systems/PowerSystem")
	var has_registry: bool = power.has_method("get_lighting_status") and power.has_method("set_light_enabled")
	if _label == "after" and not has_registry:
		_fail("After capture requires lighting registry API")
		return
	if has_registry:
		if not _set_lights(power, false):
			return
	await _capture_state(power, "all_on", has_registry)
	if _label == "after":
		if not _set_lights(power, true):
			return
		await _capture_state(power, "selective_off", true)
		await _capture_installed_pod(power)
	if _failed:
		return
	var file: FileAccess = FileAccess.open(_folder.path_join(_label + "_manifest.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write lighting manifest")
		return
	var settings: Node = root.get_node("GameSettings")
	file.store_string(JSON.stringify({"label": _label, "views": _views, "states": _states, "fov": 80.0, "near": 0.05, "resolution": [root.size.x, root.size.y], "display_driver": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(), "lighting": "Native game fixtures; no lighting override; flashlight off", "simulation": "Paused fresh main scene; after pod inspection advances module construction only; no power ticks or save writes", "filter": {"enabled": settings.get("analogue_filter_enabled"), "intensity": settings.get("analogue_filter_intensity")}}, "\t") + "\n")
	print("PASS: capture_lighting_pass (", _label, ", ", _views.size(), " views)")
	_main.free()
	await process_frame
	await process_frame
	quit(0)

func _set_lights(power: Node, selective: bool) -> bool:
	var registry: Dictionary = power.call("get_lighting_status")
	if registry.is_empty():
		_fail("Lighting registry is empty")
		return false
	for fixture_id: Variant in registry:
		var id: String = String(fixture_id)
		var enabled: bool = not selective or id.contains("cockpit") or id.contains("life_support")
		if not bool(power.call("set_light_enabled", StringName(id), enabled)):
			_fail("Cannot switch lighting fixture " + id)
			return false
	return true

func _capture_state(power: Node, state: String, has_registry: bool) -> void:
	await process_frame
	await process_frame
	_states[state] = {"power": power.call("get_status"), "source_state": power.call("save_state"), "source_loads": power.get("_source_loads"), "fixtures": power.call("get_lighting_status") if has_registry else {}, "registry_available": has_registry}
	print("POWER: ", _label, " ", state, " ", JSON.stringify(_states[state]["power"]))
	for section_name: String in ["cockpit", "galley", "life_support", "engine_bay_b"]:
		var bounds: Vector2 = TubeLayout.span(TubeLayout.index_of(section_name))
		var eye: Vector3 = Vector3(0.0, 1.55, (bounds.x + bounds.y) * 0.5)
		for facing: String in ["bow", "stern", "port", "starboard", "ceiling", "deck"]:
			var direction: Vector3 = {"bow": Vector3.FORWARD, "stern": Vector3.BACK, "port": Vector3.LEFT, "starboard": Vector3.RIGHT, "ceiling": Vector3.UP, "deck": Vector3.DOWN}[facing]
			await _capture(_label + "_" + state + "_cabin_" + section_name, facing, eye, eye + direction, false)
	for bay: Dictionary in TubeLayout.service_bays():
		var center_z: float = float(bay["center_z"])
		await _capture(_label + "_" + state + "_bay_" + String(bay["name"]), "entry", Vector3(0.0, 1.55, center_z), Vector3(float(bay["outer_x"]), 1.2, center_z), false)
	if _label == "after":
		for fixture: int in 2:
			var beam: Node3D = _main.get_node("ShipGeometry/HullExterior/Floodlight%d/WorkLight" % fixture) as Node3D
			var target: Vector3 = beam.global_position - beam.global_basis.z * 4.0
			await _capture("after_" + state + "_exterior_work_%d" % fixture, "beam", beam.global_position + Vector3(0.0, 1.2, 1.0), target, false)


func _capture_installed_pod(power: Node) -> void:
	var modules: ModuleSystem = _main.get_node("Systems/ModuleSystem") as ModuleSystem
	var cargo: CargoSystem = _main.get_node("Systems/CargoSystem") as CargoSystem
	cargo.add_material(&"metal", 20.0)
	cargo.add_material(&"ore", 10.0)
	if not modules.start_build(&"utility_pod"):
		_fail("Cannot build lighting inspection pod")
		return
	modules.sim_tick(8.1)
	await process_frame
	await process_frame
	var pod: Node3D = _main.get_node("ShipGeometry/HullExterior/Pod_hp_quarters") as Node3D
	var id: StringName = &"Pod_hp_quarters/PodLight"
	for enabled: bool in [true, false]:
		if not bool(power.call("set_light_enabled", id, enabled)):
			_fail("Cannot toggle pod inspection light")
			return
		var state: String = "pod_on" if enabled else "pod_off"
		await process_frame
		_states[state] = {"power": power.call("get_status"), "fixtures": power.call("get_lighting_status")}
		await _capture("after_" + state, "entry", pod.to_global(Vector3(0.5, 1.55, 0.0)), pod.to_global(Vector3(3.5, 1.1, 0.0)), false)
		await _capture("after_" + state, "panel", pod.to_global(Vector3(2.3, 1.55, 0.0)), pod.to_global(Vector3(2.0, 1.3, 1.4)), false)
