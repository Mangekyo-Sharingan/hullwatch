## Cabin lights follow the live lighting breaker through EventBus events.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var lights: Array[Node] = main.find_children("CabinLight*", "OmniLight3D", true, false)
	lights.append_array(main.find_children("WorkLight", "SpotLight3D", true, false))
	var breaker: BreakerPanel = main.get_node("WorldLayout/Props/BreakerPanel") as BreakerPanel
	_check(not lights.is_empty(), "live scene has generated cabin lights")
	_check(_lights_visible(lights), "lights start on with the lighting circuit")
	breaker.interact(null)
	_check(not _lights_visible(lights), "lights turn off when the lighting breaker opens")
	breaker.interact(null)
	_check(_lights_visible(lights), "lights turn on when the lighting breaker closes")

	var power: PowerSystem = main.get_node("Systems/PowerSystem") as PowerSystem
	root.get_node("SimClock").call("set_paused", true)
	var fixtures: Dictionary = power.get_lighting_status()
	_check(fixtures.size() == 14, "ten cabins, two service bays and two exterior lights register separately")
	_check(is_equal_approx(power.get_circuit_load(&"lighting"), 320.0), "fourteen fixtures draw 320W with no duplicate base charge")
	_check(not power.register_light(&"cockpit", "Duplicate", 25.0), "duplicate fixture cannot double charge")
	await _test_duplicate_node(main, power, lights)
	_test_exterior_lights(main, power)
	_test_fixture_emitters(power, lights)
	_check(not power.register_light(&"invalid", "Invalid", NAN), "nonfinite fixture draw rejected")
	_check(not power.set_light_enabled(&"missing", false), "unknown fixture toggle rejected")
	var all_on_state: Dictionary = power.save_state()
	var all_on_demand: float = power.get_total_demand_w()
	power.sim_tick(1.0)
	_check(not power.is_brownout() and _lights_visible(lights), "healthy all-on bus serves every cabin for a full simulated hour")
	var all_on_charge: float = power.battery_charge_wh
	_check(is_equal_approx(float(all_on_state["battery_charge_wh"]) - all_on_charge, all_on_demand - power.get_generation_w()), "all-on battery drains by the actual net watts over one hour")
	power.load_state(all_on_state)
	power.set_light_enabled(&"quarters", false)
	power.set_light_enabled(&"storage", false)
	_check(is_equal_approx(all_on_demand - power.get_total_demand_w(), 50.0), "two unused cabin lights save 50W")
	_check(not bool(power.get_lighting_status()[&"quarters"]["powered"]), "off preference darkens its fixture")
	var selective_state: Dictionary = power.save_state()
	power.sim_tick(1.0)
	_check(is_equal_approx(power.battery_charge_wh - all_on_charge, 50.0), "two lights save 50Wh over one simulated hour")
	var selective_result: Dictionary = power.save_state()
	power.load_state(selective_state)
	power.sim_tick(1.0)
	_check(power.save_state() == selective_result, "same restored inputs produce identical lighting and battery state")
	var json_state: Dictionary = JSON.parse_string(JSON.stringify(selective_state))
	power.load_state(json_state)
	_check(not bool(power.get_lighting_status()[&"quarters"]["enabled"]), "light preferences survive JSON round trip")
	power.set_breaker(&"lighting", false)
	_check(is_zero_approx(power.get_circuit_load(&"lighting")), "master breaker removes selected lighting load")
	power.set_breaker(&"lighting", true)
	_check(not bool(power.get_lighting_status()[&"quarters"]["powered"]), "breaker restore preserves individual off preference")
	power.load_state(all_on_state)
	_check(power.force_failure(&"lighting_ballast", &"ballast_open"), "open ballast fixture forced")
	_check(is_zero_approx(power.get_circuit_load(&"lighting")) and not _lights_visible(lights), "open ballast cuts live fixture draw and light")
	power.repair_component(&"lighting_ballast", 1.0)
	_check(_lights_visible(lights), "ballast repair restores powered selected fixtures")
	power.force_failure(&"lighting_ballast", &"ballast_short")
	_check(is_equal_approx(power.get_circuit_load(&"lighting"), 480.0), "short scales actual fixture load by half")
	power.set_light_enabled(&"quarters", false)
	_check(is_equal_approx(power.get_circuit_load(&"lighting"), 442.5), "short still responds to individual load conservation")
	power.load_state(all_on_state)
	var legacy_state: Dictionary = all_on_state.duplicate(true)
	legacy_state["state_version"] = 1
	legacy_state.erase("light_enabled")
	power.set_light_enabled(&"quarters", false)
	power.load_state(legacy_state)
	_check(_lights_visible(lights), "legacy power state defaults all registered lights on")
	_test_legacy_ballast(power, lights)
	var pod_save: Dictionary = await _test_pod_lighting(main, power)
	var generation_before: Dictionary = power.generators.duplicate()
	var discharge_before: float = power.battery_max_discharge_w
	for generator_id: Variant in generation_before:
		power.set_generation(StringName(generator_id), 0.0)
	power.battery_max_discharge_w = 0.0
	power.sim_tick(0.001)
	_check(power.is_circuit_shed(&"lighting"), "brownout shedding marks the lighting circuit shed")
	_check(not _lights_visible(lights), "cabin fixtures turn off when the circuit is automatically shed")
	power.set_generation(&"rtg_main", 10000.0)
	power.battery_max_discharge_w = discharge_before
	power.sim_tick(0.001)
	_check(not power.is_circuit_shed(&"lighting"), "restored generation clears the lighting shed state")
	_check(_lights_visible(lights), "cabin fixtures return when power restores the circuit")
	for generator_id: Variant in generation_before:
		power.set_generation(StringName(generator_id), float(generation_before[generator_id]))

	breaker.interact(null)
	var saved_power_state: Dictionary = power.save_state()
	breaker.interact(null)
	power.load_state(saved_power_state)
	await process_frame
	_check(not power.is_breaker_on(&"lighting"), "loading restores the saved lighting breaker state")
	_check(not _lights_visible(lights), "fixture visibility follows a restored breaker state")

	main.free()
	await process_frame
	await _test_fresh_pod_load(pod_save)
	if _failures == 0:
		print("PASS: test_cabin_light")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _lights_visible(lights: Array[Node]) -> bool:
	for node: Node in lights:
		var light: Light3D = node as Light3D
		if not light.visible:
			return false
	return true


func _test_duplicate_node(main: Node, power: PowerSystem, lights: Array[Node]) -> void:
	var duplicate: OmniLight3D = OmniLight3D.new()
	duplicate.set_script(load("res://src/world/cabin_light.gd"))
	duplicate.set(&"fixture_id", &"cockpit")
	main.add_child(duplicate)
	await process_frame
	await process_frame
	_check(not duplicate.visible and power.get_lighting_status().size() == 14, "duplicate node is dark and cannot register another fixture")
	duplicate.free()
	_check(power.get_lighting_status().has(&"cockpit") and is_equal_approx(power.get_circuit_load(&"lighting"), 320.0), "deleting rejected duplicate preserves original registry and watts")
	power.set_light_enabled(&"cockpit", false)
	power.set_light_enabled(&"cockpit", true)
	_check(_lights_visible(lights), "original cockpit still responds to power events after duplicate deletion")


func _test_exterior_lights(main: Node, power: PowerSystem) -> void:
	var beams: Array[Node] = main.find_children("WorkLight", "SpotLight3D", true, false)
	_check(beams.size() == 2, "two exterior work beams exist")
	for index: int in 2:
		var id: StringName = StringName("exterior_work_%d" % index)
		var status: Dictionary = power.get_lighting_status().get(id, {})
		_check(is_equal_approx(float(status.get("watts", 0.0)), 10.0) and bool(status.get("powered", false)), "%s registers a powered 10W fixture" % id)
		power.set_light_enabled(id, false)
		_check(is_equal_approx(power.get_circuit_load(&"lighting"), 310.0), "%s alone saves 10W" % id)
		for beam: Node in beams:
			_check((beam as Light3D).visible == (beam.get(&"fixture_id") != id), "exterior work switches independently")
		power.set_light_enabled(id, true)
	power.set_breaker(&"lighting", false)
	_check(not _lights_visible(beams) and is_zero_approx(power.get_circuit_load(&"lighting")), "master breaker isolates exterior work lights too")
	power.set_breaker(&"lighting", true)
	_check(_lights_visible(beams), "master restore powers exterior work lights")


func _test_fixture_emitters(power: PowerSystem, lights: Array[Node]) -> void:
	var fixture_materials: Dictionary = {}
	for light: Node in lights:
		var id: StringName = light.get(&"fixture_id")
		var model_path: NodePath = light.get(&"fixture_model")
		var model: Node = light.get_node_or_null(model_path) if not model_path.is_empty() else null
		var materials: Array[StandardMaterial3D] = []
		if model != null:
			for node: Node in model.find_children("*", "MeshInstance3D", true, false):
				var mesh: MeshInstance3D = node as MeshInstance3D
				for surface: int in mesh.mesh.get_surface_count():
					var material: StandardMaterial3D = mesh.get_active_material(surface) as StandardMaterial3D
					if material != null and material.emission_enabled:
						materials.append(material)
		_check(not materials.is_empty(), "%s has a live authored emitter" % id)
		fixture_materials[id] = materials
	for light: Node in lights:
		var id: StringName = light.get(&"fixture_id")
		power.set_light_enabled(id, false)
		_check(not (light as Light3D).visible, "%s beam is dark when switched off" % id)
		var isolated: bool = true
		for other_id: StringName in fixture_materials:
			for material: StandardMaterial3D in fixture_materials[other_id]:
				isolated = isolated and material.emission_enabled == (other_id != id)
		_check(isolated, "%s off darkens its emitter without changing another fixture" % id)
		power.set_light_enabled(id, true)
		for material: StandardMaterial3D in fixture_materials[id]:
			_check(material.emission_enabled, "%s emitter returns when powered" % id)
	power.set_breaker(&"lighting", false)
	var dark: bool = true
	for materials: Array in fixture_materials.values():
		for material: StandardMaterial3D in materials:
			dark = dark and not material.emission_enabled
	_check(dark, "master breaker darkens fixture emitter materials")
	power.set_breaker(&"lighting", true)


func _test_legacy_ballast(power: PowerSystem, lights: Array[Node]) -> void:
	var save_manager: Node = root.get_node("SaveManager")
	var baseline: Dictionary = save_manager.call("save_to_dict")
	for mode: String in ["ballast_short", "ballast_open"]:
		var legacy: Dictionary = baseline.duplicate(true)
		legacy["save_version"] = 6
		var state: Dictionary = legacy["systems"]["power"]
		state["state_version"] = 1
		state.erase("light_enabled")
		state["load_overrides"] = {"lighting": 300.0 if mode == "ballast_short" else 0.0}
		state["failure_restore"] = {"lighting_ballast": {"kind": "load_override", "target": "lighting", "value": 200.0}}
		for entry: Dictionary in state["wear"]:
			if entry["component_id"] == "lighting_ballast":
				entry["failed_mode"] = mode
		_check(save_manager.call("load_from_dict", JSON.parse_string(JSON.stringify(legacy))), "v6 %s save migrates" % mode)
		_check(is_equal_approx(power.get_circuit_load(&"lighting"), 480.0 if mode == "ballast_short" else 0.0), "v6 %s uses live fixture watts instead of old override" % mode)
		_check(_lights_visible(lights) == (mode == "ballast_short"), "v6 %s restores fixture visibility" % mode)
		power.set_light_enabled(&"cockpit", false)
		_check(is_equal_approx(power.get_circuit_load(&"lighting"), 442.5 if mode == "ballast_short" else 0.0), "v6 %s responds to selection after load" % mode)
		var migrated: Dictionary = power.save_state()
		power.load_state(JSON.parse_string(JSON.stringify(migrated)))
		_check(is_equal_approx(power.get_circuit_load(&"lighting"), 442.5 if mode == "ballast_short" else 0.0), "migrated %s fault and selection round trip" % mode)
		_check(power.repair_component(&"lighting_ballast", 1.0), "v6 %s can be repaired after round trip" % mode)
		_check(is_equal_approx(power.get_circuit_load(&"lighting"), 295.0), "v6 %s repair restores selected fixture watts" % mode)
		power.set_light_enabled(&"cockpit", true)
		_check(is_equal_approx(power.get_circuit_load(&"lighting"), 320.0) and _lights_visible(lights), "v6 %s repair restores full live lighting" % mode)
	_check(save_manager.call("load_from_dict", baseline), "legacy checks restore the fresh scene state")


func _test_fresh_pod_load(saved: Dictionary) -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var power: PowerSystem = main.get_node("Systems/PowerSystem") as PowerSystem
	_check(power.get_lighting_status().size() == 14 and main.find_child("Pod_hp_quarters", true, false) == null, "fresh scene has only its fourteen base fixtures")
	_check(root.get_node("SaveManager").call("load_from_dict", JSON.parse_string(JSON.stringify(saved))), "fresh scene loads a saved installed pod")
	await process_frame
	await process_frame
	var id: StringName = &"Pod_hp_quarters/PodLight"
	var pod: Node = main.find_child("Pod_hp_quarters", true, false)
	_check(pod != null and power.get_lighting_status().size() == 15 and power.get_lighting_status().has(id), "fresh-scene load physically rebuilds and registers the saved pod")
	_check(not power.is_light_powered(id) and is_equal_approx(power.get_circuit_load(&"lighting"), 320.0), "freshly rebuilt pod preserves saved off preference without extra watts")
	if pod != null:
		var light: Light3D = pod.get_node("PodLight") as Light3D
		_check(not light.visible, "freshly rebuilt pod emitter starts dark")
		power.set_light_enabled(id, true)
		_check(light.visible and is_equal_approx(power.get_circuit_load(&"lighting"), 345.0), "freshly rebuilt pod switches on for precisely 25W")
		_test_fixture_emitters(power, [light])
	main.free()
	await process_frame


func _test_pod_lighting(main: Node, power: PowerSystem) -> Dictionary:
	var modules: ModuleSystem = main.get_node("Systems/ModuleSystem") as ModuleSystem
	var cargo: CargoSystem = main.get_node("Systems/CargoSystem") as CargoSystem
	var save_manager: Node = root.get_node("SaveManager")
	var no_pod: Dictionary = save_manager.call("save_to_dict")
	cargo.add_material(&"metal", 20.0)
	cargo.add_material(&"ore", 10.0)
	_check(modules.start_build(&"utility_pod"), "pod fixture starts real build")
	modules.sim_tick(8.1)
	await process_frame
	await process_frame
	var id: StringName = &"Pod_hp_quarters/PodLight"
	_check(power.get_lighting_status().has(id), "installed pod registers its light")
	_check(is_equal_approx(power.get_circuit_load(&"lighting"), 345.0), "pod adds precisely one fixture load")
	power.set_light_enabled(id, false)
	var saved: Dictionary = save_manager.call("save_to_dict")
	var old_pod: Node = main.find_child("Pod_hp_quarters", true, false)
	_check(save_manager.call("load_from_dict", JSON.parse_string(JSON.stringify(saved))), "scene save/load replaces pod and restores preferences")
	await process_frame
	await process_frame
	_check(power.get_lighting_status().has(id) and not bool(power.get_lighting_status()[id]["powered"]), "rebuilt pod keeps its saved off preference")
	_check(not is_instance_valid(old_pod), "same-scene load actually frees the previous pod")
	_check(is_equal_approx(power.get_circuit_load(&"lighting"), 320.0), "repeated rebuild does not double count pod light")
	_check(save_manager.call("load_from_dict", JSON.parse_string(JSON.stringify(no_pod))), "no-pod save loads over an installed pod")
	await process_frame
	await process_frame
	_check(modules.get_installed_modules().is_empty() and main.find_child("Pod_hp_quarters", true, false) == null, "no-pod load clears simulator installation and physical pod")
	_check(not power.get_lighting_status().has(id) and is_equal_approx(power.get_circuit_load(&"lighting"), 320.0), "no-pod load removes fixture registry and its watts")
	_check(save_manager.call("load_from_dict", JSON.parse_string(JSON.stringify(saved))), "pod save loads over the bare scene")
	_check(save_manager.call("load_from_dict", JSON.parse_string(JSON.stringify(saved))), "back-to-back restore can replace a pod before deferred registration")
	await process_frame
	await process_frame
	_check(power.get_lighting_status().has(id) and not bool(power.get_lighting_status()[id]["enabled"]), "newly spawned pod uses loaded off preference")
	power.set_light_enabled(id, true)
	_check(is_equal_approx(power.get_circuit_load(&"lighting"), 345.0), "restored pod contributes one 25W fixture when enabled")
	_check(modules.uninstall(&"utility_pod"), "pod teardown succeeds")
	await process_frame
	await process_frame
	_check(not power.get_lighting_status().has(id) and is_equal_approx(power.get_circuit_load(&"lighting"), 320.0), "teardown removes pod registry and its watts")
	return saved


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
