extends SceneTree

const CONFIG_PATH: String = "res://src/data/propulsion/drive_pair.tres"
const SERVICE_SCRIPT: Script = preload("res://src/interactables/drive_service.gd")

class Operator extends Node:
	var tool: StringName = &"scanner"

	func get_carried_item_id() -> StringName:
		return tool

var _failures: int = 0
var _spawned: Array[Node] = []
var _tool_events: Dictionary = {}


func _initialize() -> void:
	await process_frame
	# Plotting and servicing normally fast-forward the clock; only explicit ticks belong in these scenarios.
	var clock: Node = root.get_node_or_null(^"SimClock")
	if clock != null:
		clock.free()
	_test_route_costs()
	_test_uv_bus()
	_test_system_replacement()
	_test_seed_reserve()
	_test_coarse_ticks()
	_test_faults_and_service()
	_test_live_tools()
	_test_isolation_and_heat()
	_test_seeded_wear_and_json()
	_test_legacy_reset()
	await _test_generated_endpoints()
	_clear()
	await process_frame
	if _failures == 0:
		print("PASS: test_propulsion")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _test_route_costs() -> void:
	var pair: NavSystem = _nav()
	var single: NavSystem = _nav()
	_check(single.force_failure(&"port_grid", &"grid_fouled"), "single: port grid fails")
	_start(pair)
	_start(single)
	var initial_mass: float = pair.xenonite_mass_kg
	for step: int in 384:
		if pair.transit_active:
			pair.sim_tick(0.25)
		if single.transit_active:
			single.sim_tick(0.25)
	_check(pair.current_destination_id == &"arden_ii" and single.current_destination_id == &"arden_ii", "both routes arrive")
	_check(is_equal_approx(pair.transit_actual_hours, 48.0), "pair: nominal route takes 48 hours")
	_check(is_equal_approx(single.transit_actual_hours, 96.0), "single: half speed takes 96 hours")
	_check(is_equal_approx(pair.fuel_mass_kg, 1015.0) and is_equal_approx(single.fuel_mass_kg, pair.fuel_mass_kg), "single: same 185 kg xenon including plotting")
	_check(is_equal_approx(pair.xenonite_consumed_kg, 9.6), "pair: gross Xenonite burn is 9.6 kg")
	_check(is_equal_approx(single.xenonite_consumed_kg, 14.4), "single: gross Xenonite burn is 14.4 kg")
	_check(is_equal_approx(initial_mass - pair.xenonite_mass_kg, 7.2), "pair: net Xenonite use is 7.2 kg after regeneration")
	_check(is_equal_approx(initial_mass - single.xenonite_mass_kg, 9.6), "single: net Xenonite use is higher at 9.6 kg")
	_clear()


func _test_uv_bus() -> void:
	var power: PowerSystem = _power()
	var nav: NavSystem = _nav()
	_check(is_equal_approx(power.get_total_demand_w(), 740.0), "UV: nominal bus demand with twelve fixtures is 740 W")
	power.battery_charge_wh = 0.0
	power.sim_tick(0.01)
	_check(is_equal_approx(power.get_total_load_w(), 440.0), "empty battery: lighting shedding leaves 440 W")
	_check(power.is_circuit_shed(&"lighting"), "empty battery: lighting is shed")
	for circuit: StringName in [&"life_support", &"scrubber", &"xenonite_uv"]:
		_check(not power.is_circuit_shed(circuit) and power.is_breaker_on(circuit), "empty battery: %s stays served" % circuit)
	var mass: float = nav.xenonite_mass_kg
	nav.sim_tick(0.25)
	_check(is_equal_approx(nav.xenonite_mass_kg - mass, nav.propulsion.replication_kg_per_hour * 0.25), "served UV: tank regenerates")
	_check(power.set_breaker(&"xenonite_uv", false), "UV breaker opens")
	mass = nav.xenonite_mass_kg
	nav.sim_tick(1.0)
	_check(nav.xenonite_mass_kg == mass and not bool(nav.get_status()["uv_active"]), "open UV breaker: no replication")
	_check(power.set_breaker(&"xenonite_uv", true), "UV breaker closes")
	nav.sim_tick(0.25)
	_check(nav.xenonite_mass_kg > mass, "closed UV breaker: replication resumes")
	power.set_generation(&"rtg_main", 0.0)
	power.battery_charge_wh = 0.0
	power.sim_tick(0.01)
	mass = nav.xenonite_mass_kg
	nav.sim_tick(1.0)
	_check(power.is_circuit_shed(&"xenonite_uv") and nav.xenonite_mass_kg == mass, "zero generation and empty battery: no UV replication")
	_clear()


func _test_seed_reserve() -> void:
	var power: PowerSystem = _power()
	var nav: NavSystem = _nav()
	power.set_breaker(&"xenonite_uv", false)
	nav.xenonite_mass_kg = nav.propulsion.seed_mass_kg + 0.01
	_start(nav)
	nav.sim_tick(1.0)
	_check(is_equal_approx(nav.xenonite_mass_kg, nav.propulsion.seed_mass_kg), "depletion: protected seed is never burned")
	_check(is_equal_approx(nav.xenonite_consumed_kg, 0.01), "depletion: only available mass is consumed")
	_hold(nav, &"tank_recovering", "depleted tank")
	power.set_breaker(&"xenonite_uv", true)
	power.sim_tick(0.01)
	var progress: float = nav.transit_elapsed_hours
	nav.sim_tick(0.25)
	_check(nav.transit_elapsed_hours == progress, "tank restart: waits for protected restart margin")
	nav.sim_tick(2.0)
	_check(nav.transit_active and nav.plotted_destination_id == &"arden_ii" and nav.transit_elapsed_hours > progress, "tank regeneration: held route resumes")
	_check(nav.xenonite_mass_kg >= nav.propulsion.seed_mass_kg, "restart burn preserves the seed")
	_clear()


func _test_system_replacement() -> void:
	var power: PowerSystem = _power()
	var nav: NavSystem = _nav()
	power.free()
	power = _power()
	power.set_breaker(&"xenonite_uv", false)
	var mass: float = nav.xenonite_mass_kg
	nav.sim_tick(NavSystem.MAX_STEP_HOURS)
	_check(nav.xenonite_mass_kg == mass, "replacement power system controls UV after cached node is freed")
	power.set_breaker(&"xenonite_uv", true)
	nav.sim_tick(NavSystem.MAX_STEP_HOURS)
	_check(nav.xenonite_mass_kg > mass, "replacement power system restores UV replication")
	_clear()


func _test_coarse_ticks() -> void:
	for recovery: bool in [true, false]:
		var coarse: NavSystem = _nav()
		var fixed: NavSystem = _nav()
		var mass: float = coarse.propulsion.seed_mass_kg if recovery else coarse.propulsion.tank_capacity_kg
		var state: Dictionary = {"plotted_destination_id": "arden_ii", "transit_active": true,
			"propulsion": {"mass_kg": mass, "tank_recovering": recovery}}
		coarse.load_state(state)
		fixed.load_state(state)
		var steps: int = 1200 if recovery else 28800
		var remainder: float = 0.0 if recovery else NavSystem.MAX_STEP_HOURS * 0.5
		coarse.sim_tick(float(steps) * NavSystem.MAX_STEP_HOURS + remainder)
		for step: int in steps:
			fixed.sim_tick(NavSystem.MAX_STEP_HOURS)
		if remainder > 0.0:
			fixed.sim_tick(remainder)
		var label: String = "seed recovery" if recovery else "full tank and fractional tick"
		_check(coarse.save_state() == fixed.save_state(), "%s: coarse and fixed ticks preserve identical mass, consumption, progress, wear and RNG" % label)
		if recovery:
			_check(coarse.transit_elapsed_hours < 0.01, "recovery time cannot also be spent burning")
		else:
			_check(coarse.current_destination_id == &"arden_ii" and coarse.xenonite_mass_kg > 32.7, "full tank continues regenerating during the burn")
		_clear()


func _test_faults_and_service() -> void:
	var nav: NavSystem = _nav()
	_start(nav)
	_check(nav.force_failure(&"port_grid", &"grid_fouled"), "port grid fault injected")
	_check(nav.force_failure(&"starboard_cathode", &"cathode_lead_open"), "starboard cathode fault injected")
	_hold(nav, &"cassette_offline", "both cassettes failed")
	var panel: Interactable = SERVICE_SCRIPT.new() as Interactable
	_spawn(panel)
	var hidden: String = "\n".join(panel.call("build_readout"))
	_check(not hidden.contains("GRID_FOULED") and not hidden.contains("CONDITION: 100%"), "service readout conceals unmeasured wear and undiagnosed mode")
	_service(nav, &"port", &"port_grid")
	_check("\n".join(panel.call("build_readout")).contains("CONDITION: 100%"), "service readout shows scanned wear after repair")
	var progress: float = nav.transit_elapsed_hours
	nav.sim_tick(0.25)
	_check(nav.transit_elapsed_hours > progress and int(nav.get_status()["functional_cassettes"]) == 1, "one repaired cassette resumes held route at degraded speed")
	_service(nav, &"starboard", &"starboard_cathode")
	_check(int(nav.get_status()["functional_cassettes"]) == 2, "grid and cathode service restore the pair")
	_check(nav.force_failure(&"tank_uv", &"uv_connector_open"), "tank UV fault injected")
	var mass: float = nav.xenonite_mass_kg
	# Stop the burn so replication is measured independently of consumption.
	nav.service_action(&"port", &"isolate", &"")
	nav.service_action(&"starboard", &"isolate", &"")
	nav.sim_tick(0.25)
	_check(nav.xenonite_mass_kg == mass and not bool(nav.get_status()["uv_active"]), "failed tank UV stops replication")
	_service(nav, &"tank", &"tank_uv")
	nav.sim_tick(0.25)
	_check(nav.xenonite_mass_kg > mass and bool(nav.get_status()["uv_active"]), "tank UV service restores regeneration")
	_clear()


func _test_live_tools() -> void:
	var nav: NavSystem = _nav()
	nav.force_failure(&"port_grid", &"grid_fouled")
	var panel: Interactable = SERVICE_SCRIPT.new() as Interactable
	_spawn(panel)
	var operator: Operator = Operator.new()
	_spawn(operator)
	var bus: Node = root.get_node(^"EventBus")
	_tool_events.clear()
	bus.connect(&"sim_event", _on_tool_event)
	panel.interact(operator)
	_check(bool(panel.call("select_action", &"isolate")), "live tools: isolation needs no tool")
	_check(not bool(panel.call("select_action", &"open")), "live tools: carried scanner cannot open cover")
	operator.tool = &"wrench"
	_check(bool(panel.call("select_action", &"open")), "live tools: carried wrench opens cover")
	_check(not bool(panel.call("select_action", &"scan")), "live tools: carried wrench cannot scan")
	operator.tool = &"scanner"
	_check(bool(panel.call("select_action", &"scan")), "live tools: carried scanner records wear")
	var readout: String = "\n".join(panel.call("build_readout"))
	_check(readout.contains("CONDITION: 100%") and not readout.contains("GRID_FOULED"), "live scanner reveals condition without fault mode")
	operator.tool = &"multimeter"
	_check(bool(panel.call("select_action", &"diagnose")), "live tools: carried multimeter diagnoses")
	_check("\n".join(panel.call("build_readout")).contains("GRID_FOULED"), "live diagnosis reveals measured failure mode")
	_check(bool((nav.get_service_status(&"port")["components"] as Dictionary)["port_cathode"]["diagnosed"]), "healthy cathode diagnostic is recorded")
	_check(int(_tool_events.get(&"probe_scanned", 0)) == 1 and int(_tool_events.get(&"probe_diagnosis", 0)) == 1, "interactable emits one scan and diagnosis feedback event")
	_check(not bool(panel.call("select_action", &"service:port_grid")), "live tools: multimeter cannot repair")
	operator.tool = &"wrench"
	_check(bool(panel.call("select_action", &"service:port_grid")), "live tools: changing carried tool allows repair")
	bus.disconnect(&"sim_event", _on_tool_event)
	panel.call("close")
	_clear()


func _on_tool_event(event_name: StringName, _payload: Dictionary) -> void:
	if event_name in [&"probe_scanned", &"probe_diagnosis"]:
		_tool_events[event_name] = int(_tool_events.get(event_name, 0)) + 1


func _service(nav: NavSystem, target: StringName, component_id: StringName) -> void:
	var action: StringName = StringName("service:" + String(component_id))
	_check(not nav.service_action(target, &"open", &"wrench"), "%s: live housing cannot open" % target)
	_check(not nav.service_action(target, &"diagnose", &"multimeter"), "%s: live fault cannot be diagnosed" % target)
	_check(nav.service_action(target, &"isolate", &""), "%s: isolates without a tool" % target)
	_check(not nav.service_action(target, &"open", &"scanner"), "%s: wrong opening tool refused" % target)
	_check(nav.service_action(target, &"open", &"wrench"), "%s: wrench opens isolated housing" % target)
	_check(not nav.service_action(target, action, &"wrench"), "%s: repair requires diagnosis" % target)
	_check(not nav.service_action(target, &"scan", &"wrench"), "%s: wrong scan tool refused" % target)
	_check(nav.service_action(target, &"scan", &"scanner"), "%s: scanner records wear" % target)
	_check(not nav.service_action(target, &"diagnose", &"scanner"), "%s: wrong diagnosis tool refused" % target)
	_check(nav.service_action(target, &"diagnose", &"multimeter"), "%s: multimeter diagnoses fault" % target)
	var components: Dictionary = nav.get_service_status(target)["components"]
	_check(bool(components[String(component_id)]["diagnosed"]) and bool(components[String(component_id)]["scanned"]), "%s: diagnostic flags belong to NavSystem" % target)
	_check(not nav.service_action(target, action, &"multimeter"), "%s: wrong repair tool refused" % target)
	_check(nav.service_action(target, &"close", &"wrench"), "%s: closes before verification" % target)
	_check(not nav.service_action(target, &"restore", &"multimeter"), "%s: failed assembly cannot restore" % target)
	_check(nav.service_action(target, &"open", &"wrench"), "%s: reopens for repair" % target)
	_check(nav.service_action(target, action, &"wrench"), "%s: wrench services diagnosed component" % target)
	_check(not nav.service_action(target, &"restore", &"multimeter"), "%s: open housing cannot restore" % target)
	_check(not nav.service_action(target, &"close", &"multimeter"), "%s: wrong closing tool refused" % target)
	_check(nav.service_action(target, &"close", &"wrench"), "%s: cover closes" % target)
	_check(not nav.service_action(target, &"restore", &"wrench"), "%s: wrong verification tool refused" % target)
	_check(nav.service_action(target, &"restore", &"multimeter"), "%s: closed healthy assembly restores" % target)
	_check(bool(nav.get_service_status(target)["functional"]), "%s: functional after service" % target)


func _test_isolation_and_heat() -> void:
	var thermal: ThermalSystem = ThermalSystem.new()
	var cabin: CompartmentConfig = CompartmentConfig.new()
	cabin.compartment_id = &"engine_bay"
	thermal.compartment_defs = [cabin]
	_spawn(thermal)
	var nav: NavSystem = _nav()
	_start(nav)
	_check(is_equal_approx(float(thermal.get_compartment_status(&"engine_bay")["heat_input_w"]), nav.propulsion.pair_output_w * nav.propulsion.heat_fraction + nav.propulsion.uv_watts), "drive and UV heat enter existing engine-bay model")
	for target: StringName in [&"port", &"starboard"]:
		_check(nav.service_action(target, &"isolate", &""), "%s: isolates in transit" % target)
	_hold(nav, &"cassette_offline", "both cassettes isolated")
	for target: StringName in [&"port", &"starboard"]:
		_check(nav.service_action(target, &"restore", &"multimeter"), "%s: restores healthy closed cassette" % target)
	var progress: float = nav.transit_elapsed_hours
	nav.sim_tick(0.25)
	_check(nav.transit_elapsed_hours > progress, "restored cassettes resume original route")
	thermal.load_state({"compartments": {"engine_bay": {"temperature_c": nav.propulsion.overheat_c}}})
	_hold(nav, &"thermal_hold", "overheated engine bay")
	thermal.load_state({"compartments": {"engine_bay": {"temperature_c": nav.propulsion.resume_c + 0.1}}})
	_hold(nav, &"thermal_hold", "thermal hysteresis above resume threshold")
	thermal.load_state({"compartments": {"engine_bay": {"temperature_c": nav.propulsion.resume_c}}})
	progress = nav.transit_elapsed_hours
	nav.sim_tick(0.25)
	_check(nav.transit_elapsed_hours > progress and nav.get_status()["drive_hold_reason"] == &"", "cooled engine bay resumes original route")
	_clear()


func _hold(nav: NavSystem, reason: StringName, label: String) -> void:
	var progress: float = nav.transit_elapsed_hours
	var fuel: float = nav.fuel_mass_kg
	var actual: float = nav.transit_actual_hours
	nav.sim_tick(0.25)
	_check(nav.get_status()["drive_hold_reason"] == reason, "%s: reports hold" % label)
	_check(nav.transit_elapsed_hours == progress and nav.fuel_mass_kg == fuel, "%s: no progress or xenon use" % label)
	_check(nav.transit_active and nav.plotted_destination_id == &"arden_ii", "%s: retains active route" % label)
	_check(is_equal_approx(nav.transit_actual_hours - actual, 0.25), "%s: held time still counted" % label)


func _test_seeded_wear_and_json() -> void:
	var config: PropulsionConfig = load(CONFIG_PATH).duplicate(true) as PropulsionConfig
	for component: WearComponent in config.components:
		if component.component_id in [&"port_grid", &"starboard_grid"]:
			component.condition = 0.59 if component.component_id == &"port_grid" else 0.62
			component.wear_rate_per_hour = 0.05
			for mode: FailureMode in component.failure_modes:
				mode.base_mtbf_hours = 0.01
	var first: NavSystem = _nav(config)
	var duplicate: NavSystem = _nav(config)
	_start(first)
	_start(duplicate)
	first.sim_tick(0.25)
	duplicate.sim_tick(0.25)
	_check(bool(first.get_wear_status()["port_grid"]["failed"]), "seeded worn grid naturally fails during burn")
	_check(not bool(first.get_wear_status()["port_grid"]["diagnosed"]), "natural failure begins undiagnosed")
	_check(not bool(first.get_wear_status()["starboard_grid"]["failed"]), "healthy-threshold grid survives first tick")
	_check(JSON.stringify(first.save_state()) == JSON.stringify(duplicate.save_state()), "duplicate Nav seed and inputs produce exact state")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(first.save_state())) as Dictionary
	_check((saved["propulsion"] as Dictionary)["rng_state"] is String, "JSON preserves 64-bit wear RNG as text")
	var restored: NavSystem = _nav(config)
	restored.load_state(saved)
	_check(JSON.stringify(first.save_state()) == JSON.stringify(restored.save_state()), "in-flight propulsion state round-trips through JSON exactly")
	for step: int in 8:
		first.sim_tick(0.25)
		restored.sim_tick(0.25)
		_check(_same_propulsion_state(first, restored), "JSON continuation tick %d preserves counters, faults and RNG" % step)
	_check(bool(restored.get_wear_status()["starboard_grid"]["failed"]), "restored RNG triggers subsequent natural failure")
	_check(restored.get_status()["drive_hold_reason"] == &"cassette_offline", "natural dual failure holds route after restoration")
	_clear()


func _same_propulsion_state(first: NavSystem, restored: NavSystem) -> bool:
	var left: Dictionary = first.save_state()
	var right: Dictionary = restored.save_state()
	# JSON rounds floats; tiny counter drift must not hide a changed fault or RNG state.
	for key: String in ["fuel_mass_kg", "course_error", "transit_elapsed_hours"]:
		if absf(float(left[key]) - float(right[key])) > 1e-9:
			return false
		right[key] = left[key]
	var left_drive: Dictionary = left["propulsion"]
	var right_drive: Dictionary = right["propulsion"]
	for key: String in ["mass_kg", "consumed_kg", "actual_hours"]:
		if absf(float(left_drive[key]) - float(right_drive[key])) > 1e-9:
			return false
		right_drive[key] = left_drive[key]
	for index: int in (left_drive["wear"] as Array).size():
		for key: String in ["condition", "hours_operated", "load"]:
			if absf(float(left_drive["wear"][index][key]) - float(right_drive["wear"][index][key])) > 1e-9:
				return false
			right_drive["wear"][index][key] = left_drive["wear"][index][key]
	return left == right


func _test_legacy_reset() -> void:
	var nav: NavSystem = _nav()
	nav.force_failure(&"port_grid", &"grid_fouled")
	nav.service_action(&"port", &"isolate", &"")
	nav.service_action(&"port", &"open", &"wrench")
	nav.xenonite_mass_kg = nav.propulsion.seed_mass_kg
	nav.xenonite_consumed_kg = 5.0
	nav.load_state({"state_version": 2, "fuel_mass_kg": 1100.0, "plotted_destination_id": "arden_ii", "transit_active": true, "transit_elapsed_hours": 12.0})
	_check(nav.xenonite_mass_kg == nav.propulsion.initial_mass_kg and nav.xenonite_consumed_kg == 0.0, "legacy nav resets tank to configured defaults")
	_check(int(nav.get_status()["functional_cassettes"]) == 2 and not bool(nav.get_service_status(&"port")["housing_open"]), "legacy nav clears stale failures and open covers")
	_check(nav.transit_active and nav.transit_elapsed_hours == 12.0 and nav.fuel_mass_kg == 1100.0, "legacy nav preserves route, progress and xenon")
	_check(JSON.stringify(nav.get_wear_status()) == JSON.stringify(_nav().get_wear_status()), "legacy wear resets to fresh configured components")
	_clear()


func _test_generated_endpoints() -> void:
	var nav: NavSystem = _nav()
	var packed: PackedScene = load("res://scenes/ship_geometry.tscn") as PackedScene
	_check(packed != null, "generated hull loads")
	if packed == null:
		return
	var hull: Node = packed.instantiate()
	_spawn(hull)
	await physics_frame
	await physics_frame
	for entry: Array in [["IonDrivePort", &"port"], ["IonDriveStarboard", &"starboard"], ["XenoniteTank", &"tank"]]:
		var assembly: Node = hull.find_child(String(entry[0]), true, false)
		var service: Interactable = assembly.get_node_or_null(^"DriveService") as Interactable if assembly != null else null
		_check(service != null and service.get_script() == SERVICE_SCRIPT, "%s: generated service endpoint" % entry[0])
		if service != null:
			_check(service.get("cassette_id") == entry[1], "%s: endpoint targets correct assembly" % entry[0])
			var shape: CollisionShape3D = service.get_node_or_null(^"ServiceShape") as CollisionShape3D
			_check(shape != null and shape.shape != null and not shape.disabled, "%s: EVA service has collision" % entry[0])
			var outward: float = -1.0 if entry[1] == &"port" else 1.0
			var offsets: Array[Vector3] = [Vector3(outward * 1.2, 0.0, 0.6), Vector3(outward * 0.4, 0.0, 1.2)]
			if entry[1] == &"tank":
				offsets = [Vector3(-0.6, 0.0, 1.2), Vector3(0.6, 0.0, 1.2)]
			for offset: Vector3 in offsets:
				var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(service.global_position + offset, service.global_position, 3)
				var hit: Dictionary = root.world_3d.direct_space_state.intersect_ray(query)
				_check(hit.get("collider") == service, "%s: EVA interaction ray reaches cover from %s" % [entry[0], offset])
			await _test_cover_restore(nav, assembly, service, StringName(entry[1]))
	var port: IonDriveFx = hull.find_child("IonDrivePort", true, false) as IonDriveFx
	var starboard: IonDriveFx = hull.find_child("IonDriveStarboard", true, false) as IonDriveFx
	_check(port != null and starboard != null, "generated pair has live drive effects")
	if port == null or starboard == null:
		return
	var port_plume: MeshInstance3D = port.find_child("IonPlume", true, false) as MeshInstance3D
	var starboard_plume: MeshInstance3D = starboard.find_child("IonPlume", true, false) as MeshInstance3D
	_check(port_plume != null and starboard_plume != null, "generated pair has plume meshes")
	if port_plume == null or starboard_plume == null:
		return
	_check(not port_plume.visible and not starboard_plume.visible, "initial pair plumes are idle")
	_start(nav)
	_check(port_plume.visible and starboard_plume.visible, "nominal transit fires both plumes")
	nav.force_failure(&"port_grid", &"grid_fouled")
	_check(not port_plume.visible and starboard_plume.visible, "port fault extinguishes only port plume")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(nav.save_state())) as Dictionary
	nav.service_action(&"starboard", &"isolate", &"")
	_check(not port_plume.visible and not starboard_plume.visible, "isolated surviving cassette extinguishes both plumes")
	nav.load_state(saved)
	_check(not port_plume.visible and starboard_plume.visible, "in-flight load restores per-cassette plume state")
	_clear()


func _test_cover_restore(nav: NavSystem, assembly: Node, service: Interactable, target: StringName) -> void:
	var animator: AnimationPlayer = assembly.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check(animator != null and animator.has_animation(&"open_service") and animator.has_animation(&"close_service"), "%s: authored cover clips exist" % target)
	if animator == null or not animator.has_animation(&"open_service") or not animator.has_animation(&"close_service"):
		return
	_check(nav.service_action(target, &"isolate", &""), "%s: isolates for saved cover pose" % target)
	_check(nav.service_action(target, &"open", &"wrench"), "%s: opens for saved cover pose" % target)
	var clip: Animation = animator.get_animation(&"open_service")
	animator.advance(clip.length)
	var pose: Dictionary = _animation_pose(animator, clip)
	_check(not pose.is_empty(), "%s: opening animates actual model transforms" % target)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(nav.save_state())) as Dictionary
	nav.service_action(target, &"close", &"wrench")
	animator.advance(animator.get_animation(&"close_service").length)
	_check(_animation_pose(animator, clip) != pose, "%s: closing changes cover pose" % target)
	nav.load_state(saved)
	service.load_state(service.save_state())
	await process_frame
	_check(animator.assigned_animation == &"open_service" and not animator.is_playing(), "%s: loaded open cover settles at authored pose" % target)
	_check(is_equal_approx(animator.current_animation_position, clip.length), "%s: loaded open clip seeks to end" % target)
	_check(_animation_pose(animator, clip) == pose, "%s: loaded open cover restores exact model transforms" % target)
	nav.service_action(target, &"close", &"wrench")
	nav.service_action(target, &"restore", &"multimeter")


func _animation_pose(animator: AnimationPlayer, clip: Animation) -> Dictionary:
	var pose: Dictionary = {}
	var animation_root: Node = animator.get_node(animator.root_node)
	for track: int in clip.get_track_count():
		var path: NodePath = clip.track_get_path(track)
		var target: Node3D = animation_root.get_node_or_null(NodePath(String(path).get_slice(":", 0))) as Node3D
		if target != null:
			pose[String(path)] = target.transform
	return pose


func _start(nav: NavSystem) -> void:
	_check(nav.plot_course(&"arden_ii"), "route plots")
	_check(nav.begin_transit(), "route begins")


func _nav(config: PropulsionConfig = null) -> NavSystem:
	var nav: NavSystem = NavSystem.new()
	nav.propulsion = config.duplicate(true) as PropulsionConfig if config != null else load(CONFIG_PATH).duplicate(true) as PropulsionConfig
	nav.destinations = [load("res://src/data/destinations/destination_arden_ii.tres") as VoyageDestination]
	_spawn(nav)
	return nav


func _power() -> PowerSystem:
	var power: PowerSystem = PowerSystem.new()
	power.generators = {&"rtg_main": 500.0}
	for name: String in ["life_support", "scrubber", "lighting", "airlock", "fabricator", "xenonite_uv"]:
		power.circuit_defs.append(load("res://src/data/power/circuit_%s.tres" % name) as PowerCircuit)
	_spawn(power)
	for fixture: int in 12:
		power.register_light(StringName("fixture_%d" % fixture), "Fixture", (load("res://src/data/power/cabin_fixture.tres") as PowerCircuit).nominal_load_w)
	return power


func _spawn(node: Node) -> void:
	root.add_child(node)
	_spawned.append(node)


func _clear() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
