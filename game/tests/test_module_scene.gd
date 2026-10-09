## Scene integration (M10.3): a dock mount builds a module through the sim, the pod stands at
## its hardpoint with its compartment and link wired, teardown reverses it, and a save/load
## round trip rebuilds the pod from sim state alone.
extends SceneTree

const MODULE_ID: StringName = &"utility_pod"
const HARDPOINT_ID: StringName = &"hp_quarters"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var modules: Node = main.get_node("Systems/ModuleSystem")
	var cargo: Node = main.get_node("Systems/CargoSystem")
	var atmosphere: Node = main.get_node("Systems/AtmosphereSystem")
	var player: CharacterBody3D = main.get_node("Player") as CharacterBody3D
	var plate: ModuleMount = main.get_node("ShipGeometry/HullExterior/DockPlate_quarters") as ModuleMount
	var life_support_plate: ModuleMount = main.get_node("ShipGeometry/HullExterior/DockPlate_life_support") as ModuleMount
	_check(modules != null and cargo != null and atmosphere != null and plate != null and life_support_plate != null, "module system, cargo and dock plates are wired")
	if plate == null or life_support_plate == null:
		main.free()
		_finish()
		return
	_check(plate.hardpoint_id == HARDPOINT_ID, "plate carries its hardpoint id")
	_check(plate is ModuleMount and plate.spawns, "hull plate is the dock mount")
	_check(plate.get_interaction_prompt() == "Dock mount", "empty mount prompt")
	_check(plate.get_actions().has(StringName("build:" + String(MODULE_ID))), "mount lists the catalog module for this dock")
	_check(not plate.get_actions().has(&"teardown"), "nothing to tear down yet")

	cargo.call("add_material", &"metal", 20.0)
	cargo.call("add_material", &"ore", 10.0)
	_check(plate.select_action(&"build:utility_pod"), "mount starts the nanite build")
	await process_frame
	_check(not bool(modules.call("is_installed", MODULE_ID)), "nothing stands while the nanites work")
	_check(StringName(modules.call("can_install", &"workshop")) == ModuleSystem.REFUSAL_HARDPOINT_CLEARANCE, "an active build reserves its port pod clearance")
	_check(plate.get_actions().has(&"cancel_build"), "the mount offers to cancel a running build")
	_check(main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_quarters") == null, "no pod on the hull yet")
	modules.call("sim_tick", 8.1)
	await process_frame
	_check(modules.call("get_installed_at", HARDPOINT_ID) == MODULE_ID, "the build lands after its hours")
	_check(bool(atmosphere.call("has_compartment", &"module_utility")), "pod compartment registered")
	_check(StringName(modules.call("can_install", &"workshop")) == ModuleSystem.REFUSAL_HARDPOINT_CLEARANCE, "adjacent port pod clearance blocks an overlapping build")
	var hud: Node = main.get_node("UI/HUD")
	_check(String(hud.call("_procedure_error_text", ModuleSystem.REFUSAL_HARDPOINT_CLEARANCE)).contains("ADJACENT PORT POD"), "the refusal explains why the dock cannot build")
	_check(not life_support_plate.select_action(&"build:workshop"), "the mount refuses the overlapping workshop pod")
	_check((modules.call("get_job", &"hp_life_support") as Dictionary).is_empty(), "a refused adjacent build does not create a construction job")
	var pod: Node3D = main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_quarters") as Node3D
	_check(pod != null, "pod stands in the world")
	if pod == null:
		main.free()
		_finish()
		return
	var hull_face: float = plate.global_position.x - 0.075
	_check(absf(pod.global_position.x - hull_face) < 0.01, "pod origin sits on the hull's outer face")
	_check(absf(pod.global_position.z - plate.global_position.z) < 2.5, "pod lines up with its dock")
	_check(is_equal_approx(pod.rotation_degrees.y, 180.0), "west dock pod faces outward")
	_check(not (plate.get_node(^"Mesh") as MeshInstance3D).visible, "plate hides while the pod stands")
	_check((plate.get_node(^"Shape") as CollisionShape3D).disabled, "plate stops colliding so the doorway is open")
	var zone: Node = pod.find_child("Zone", true, false)
	var link: Node = pod.find_child("Link", true, false)
	_check(zone != null and StringName(zone.get(&"compartment_id")) == &"module_utility", "pod zone carries the module compartment")
	_check(link != null and StringName(link.get(&"compartment_a")) == &"module_utility" and StringName(link.get(&"compartment_b")) == &"quarters", "pod link bridges into the parent room")
	var room: ModuleMount = pod.get_node_or_null(^"PodRoom") as ModuleMount
	_check(room != null and not room.spawns and room.hardpoint_id == HARDPOINT_ID, "pod room is the teardown mount")
	if room == null:
		main.free()
		_finish()
		return
	_check(room.get_actions().has(&"teardown"), "standing pod offers teardown")
	var sockets: Array[MachineSocket] = []
	for child: Node in pod.get_children():
		if child is MachineSocket:
			sockets.append(child as MachineSocket)
	_check(sockets.size() == 3, "the pod carries three machine sockets")
	_check(sockets[0].slot_id == &"hp_quarters:0" and sockets[2].slot_id == &"hp_quarters:2", "sockets are wired to their dock and index")
	_check(sockets[0].get_actions().size() > 0, "an empty socket offers machines to fit")
	cargo.call("add_material", &"ice", 4.0)
	_check(bool(modules.call("fit_machine", &"grow_rack", &"hp_quarters:0")), "a machine fits into the pod socket")
	modules.call("sim_tick", 6.0)
	var prop: Node3D = sockets[0].get_node_or_null(^"MachineProp") as Node3D
	_check(prop != null and prop.visible, "the socket shows the fitted machine")
	var model_name: StringName = prop.get_child(0).name if prop != null and prop.get_child_count() > 0 else &""
	_check(String(model_name).begins_with("hw_"), "the fitted machine shows its authored model (%s)" % model_name)

	# M13.3 exit: with the pod standing, the walk from its room through the throat and the
	# pod's doorway is clear - the operator enters on foot.
	var quarters: int = TubeLayout.index_of("quarters")
	var quarters_z: float = (TubeLayout.span(quarters).x + TubeLayout.span(quarters).y) * 0.5
	var doorway: float = plate.global_position.x - 0.075 - 0.2
	_check(
		not _ray_hits(Vector3(0.0, 1.0, quarters_z), Vector3(doorway, 1.0, quarters_z)),
		"the pod is walkable from its room (build -> enter on foot)"
	)
	_check(
		_has_capsule_route(player, Vector2(0.0, quarters_z), doorway),
		"a standing operator capsule can reach the installed pod"
	)
	var life_support: int = TubeLayout.index_of("life_support")
	var life_support_z: float = (TubeLayout.span(life_support).x + TubeLayout.span(life_support).y) * 0.5
	_check(
		_has_capsule_route(player, Vector2(0.0, life_support_z), -1.55),
		"a standing operator capsule can reach the life-support dock mouth"
	)
	var engine_bay: int = TubeLayout.index_of("engine_bay_b")
	var engine_bay_z: float = (TubeLayout.span(engine_bay).x + TubeLayout.span(engine_bay).y) * 0.5
	_check(
		_has_capsule_route(player, Vector2(0.0, engine_bay_z), 2.2),
		"a standing operator capsule can reach the engine-bay dock mouth"
	)
	var atmosphere_probe: CollisionShape3D = main.get_node("WorldLayout/Props/ProbeAtmosphere/Shape") as CollisionShape3D
	var o2_rack: CollisionShape3D = main.get_node("WorldLayout/Props/O2CandleRack/Shape") as CollisionShape3D
	var filter_rack: CollisionShape3D = main.get_node("WorldLayout/Props/FilterRack/Shape") as CollisionShape3D
	_check(_ray_hits_target(Vector3(0.0, 1.7, life_support_z), atmosphere_probe.global_position, atmosphere_probe.get_parent()), "atmosphere probe is reachable from a standing lane")
	_check(_ray_hits_target(Vector3(0.0, 1.7, o2_rack.global_position.z), o2_rack.global_position, o2_rack.get_parent()), "O2 candle rack is reachable from a standing lane")
	_check(_ray_hits_target(Vector3(0.0, 1.7, filter_rack.global_position.z), filter_rack.global_position, filter_rack.get_parent()), "filter rack is reachable from a standing lane")
	var thermal_probe: CollisionShape3D = main.get_node("WorldLayout/Props/ProbeThermal/Shape") as CollisionShape3D
	var hull_probe: CollisionShape3D = main.get_node("WorldLayout/Props/ProbeHull/Shape") as CollisionShape3D
	var fabricator: CollisionShape3D = main.get_node("WorldLayout/Props/Fabricator/Shape") as CollisionShape3D
	_check(_ray_hits_target(Vector3(0.0, 1.7, thermal_probe.global_position.z), thermal_probe.global_position, thermal_probe.get_parent()), "thermal probe is reachable from the engine-bay lane")
	_check(_ray_hits_target(Vector3(0.0, 1.7, hull_probe.global_position.z), hull_probe.global_position, hull_probe.get_parent()), "hull probe is reachable from the engine-bay lane")
	_check(_ray_hits_target(Vector3(0.0, 1.3, fabricator.global_position.z), fabricator.global_position, fabricator.get_parent()), "fabricator is reachable from the engine-bay lane")
	var storage_index: int = TubeLayout.index_of("storage")
	var storage_span: Vector2 = TubeLayout.span(storage_index)
	var storage_center: float = (storage_span.x + storage_span.y) * 0.5
	_check(_capsule_segment_clear(player, Vector2(0.0, storage_center), Vector2(0.0, storage_span.x + 0.1)), "standing capsule clears storage-to-quarters hatch lane")
	_check(_capsule_segment_clear(player, Vector2(0.0, storage_center), Vector2(0.0, storage_span.y - 0.55)), "standing capsule clears the storage lane to the inner airlock hatch approach")
	var galley_index: int = TubeLayout.index_of("galley")
	var galley_span: Vector2 = TubeLayout.span(galley_index)
	var galley_center: float = (galley_span.x + galley_span.y) * 0.5
	_check(_has_capsule_route(player, Vector2(0.0, galley_center), 1.8), "a standing operator capsule can reach the galley dock mouth")
	var water_closet_index: int = TubeLayout.index_of("water_closet")
	var water_span: Vector2 = TubeLayout.span(water_closet_index)
	var water_center: float = (water_span.x + water_span.y) * 0.5
	_check(_capsule_segment_clear(player, Vector2(0.0, water_center), Vector2(0.0, water_span.x + 0.1)), "standing capsule clears the water-closet-to-galley hatch lane")
	_check(_capsule_segment_clear(player, Vector2(0.0, water_center), Vector2(0.0, water_span.y - 0.55)), "standing capsule clears the water-closet-to-storage hatch lane")
	var water_reclaimer: CollisionShape3D = main.get_node("WorldLayout/Props/WaterReclaimer/Shape") as CollisionShape3D
	var water_probe: CollisionShape3D = main.get_node("WorldLayout/Props/ProbeWater/Shape") as CollisionShape3D
	var service_x: float = float(TubeLayout.service_bays()[0]["inner_x"]) + 0.55
	_check(_capsule_segment_clear(player, Vector2(0.0, life_support_z), Vector2(service_x, life_support_z)), "standing capsule enters life-support service bay")
	_check(_capsule_segment_clear(player, Vector2(service_x, life_support_z), Vector2(service_x, water_reclaimer.global_position.z)), "standing capsule reaches water-reclaimer service apron")
	var service_eye: Vector3 = Vector3(service_x, 1.55, water_reclaimer.global_position.z)
	_check(service_eye.distance_to(water_reclaimer.global_position) <= 2.5, "water reclaimer stays within normal interaction reach")
	_check(_ray_hits_target(service_eye, water_reclaimer.global_position, water_reclaimer.get_parent()), "water reclaimer is reachable from the standing service apron")
	_check(_ray_hits_target(Vector3(0.0, 1.7, water_probe.global_position.z), water_probe.global_position, water_probe.get_parent()), "water probe is reachable from the standing service lane")

	var saved: Dictionary = modules.call("save_state") as Dictionary
	_check(room.select_action(&"teardown"), "teardown uninstalls the module")
	await process_frame
	_check(is_equal_approx(float(cargo.call("get_units", &"metal")), 20.0), "teardown returns the metal")
	_check(is_equal_approx(float(cargo.call("get_units", &"ore")), 10.0), "teardown returns the ore")
	_check(main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_quarters") == null, "pod leaves the world")
	_check((plate.get_node(^"Mesh") as MeshInstance3D).visible, "plate comes back")
	_check(not (plate.get_node(^"Shape") as CollisionShape3D).disabled, "plate seals the dock again")
	_check(not bool(atmosphere.call("has_compartment", &"module_utility")), "pod compartment leaves with it")
	_check(life_support_plate.select_action(&"build:workshop"), "the Life Support pod can be built after the adjacent Quarters pod is removed")
	modules.call("sim_tick", 18.1)
	await process_frame
	var life_support_pod: Node3D = main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_life_support") as Node3D
	_check(life_support_pod != null and modules.call("get_installed_at", &"hp_life_support") == &"workshop", "the Life Support pod stands without intersecting its neighbor")
	var life_support_room: ModuleMount = life_support_pod.get_node_or_null(^"PodRoom") as ModuleMount if life_support_pod != null else null
	if life_support_room != null:
		_check(life_support_room.select_action(&"teardown"), "the Life Support pod remains removable")
		await process_frame

	var engine_plate: ModuleMount = main.get_node("ShipGeometry/HullExterior/DockPlate_engine_bay") as ModuleMount
	_check(engine_plate.select_action(&"build:aux_battery"), "engine-bay mount starts its auxiliary-battery pod build")
	modules.call("sim_tick", 14.1)
	await process_frame
	var engine_pod: Node3D = main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_engine_bay") as Node3D
	var engine_room: ModuleMount = engine_pod.get_node_or_null(^"PodRoom") as ModuleMount if engine_pod != null else null
	_check(engine_room != null, "engine-bay battery pod stands with its service doorway")
	_check(_has_capsule_route(player, Vector2(0.0, engine_bay_z), 2.2), "a standing capsule can enter the installed engine-bay pod")
	if engine_room != null:
		_check(engine_room.select_action(&"teardown"), "engine-bay battery pod can be removed through its service mount")
		await process_frame
		_check(is_equal_approx(float(cargo.call("get_units", &"metal")), 20.0), "engine-bay pod removal refunds metal")
		_check(is_equal_approx(float(cargo.call("get_units", &"ore")), 10.0), "engine-bay pod removal refunds ore")

	var galley_plate: ModuleMount = main.get_node("ShipGeometry/HullExterior/DockPlate_galley") as ModuleMount
	var galley_metal_before: float = float(cargo.call("get_units", &"metal"))
	var galley_ice_before: float = float(cargo.call("get_units", &"ice"))
	cargo.call("add_material", &"metal", 6.0)
	cargo.call("add_material", &"ice", 2.0)
	_check(galley_plate.select_action(&"build:storage_pod"), "galley mount starts its storage-pod build")
	modules.call("sim_tick", 6.1)
	await process_frame
	var galley_pod: Node3D = main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_galley") as Node3D
	var galley_room: ModuleMount = galley_pod.get_node_or_null(^"PodRoom") as ModuleMount if galley_pod != null else null
	_check(galley_room != null, "storage pod stands at the galley mount")
	_check(_has_capsule_route(player, Vector2(0.0, galley_center), 1.8), "a standing capsule can enter the installed galley pod")
	if galley_room != null:
		_check(galley_room.select_action(&"teardown"), "galley storage pod can be removed through its service mount")
		await process_frame
		_check(is_equal_approx(float(cargo.call("get_units", &"metal")), galley_metal_before + 6.0), "galley pod removal refunds metal")
		_check(is_equal_approx(float(cargo.call("get_units", &"ice")), galley_ice_before + 2.0), "galley pod removal refunds ice")

	modules.call("load_state", saved)
	await process_frame
	_check(main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_quarters") != null, "loaded save rebuilds the pod")
	_check(bool(atmosphere.call("has_compartment", &"module_utility")), "loaded save restores the pod compartment")

	main.free()
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
		return
	_failures += 1
	print("FAIL: ", label)


func _ray_hits(from: Vector3, to: Vector3) -> bool:
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return not root.world_3d.direct_space_state.intersect_ray(params).is_empty()


func _ray_hits_target(from: Vector3, to: Vector3, target: Node) -> bool:
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return root.world_3d.direct_space_state.intersect_ray(params).get("collider") == target


func _has_capsule_route(player: CharacterBody3D, start: Vector2, target_x: float) -> bool:
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.75
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var step: float = 0.12
	var direction: float = signf(target_x - start.x)
	var max_x: int = ceili(absf(start.x - target_x) / step)
	var max_z: int = floori(1.2 / step)
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var visited: Dictionary = {Vector2i.ZERO: true}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		var x: float = start.x + direction * float(cell.x) * step
		var z: float = start.y + float(cell.y) * step
		if direction * (x - target_x) >= 0.0 and absf(z - start.y) <= 0.3:
			return true
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if next.x < 0 or next.x > max_x or absi(next.y) > max_z or visited.has(next):
				continue
			query.transform = Transform3D(Basis(), Vector3(start.x + direction * float(next.x) * step, 0.925, start.y + float(next.y) * step))
			if not space.intersect_shape(query, 1).is_empty():
				continue
			visited[next] = true
			queue.append(next)
	return false


func _capsule_segment_clear(player: CharacterBody3D, start: Vector2, finish: Vector2) -> bool:
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.75
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var steps: int = ceili(start.distance_to(finish) / 0.12)
	for step: int in steps + 1:
		var point: Vector2 = start.lerp(finish, float(step) / float(maxi(steps, 1)))
		query.transform = Transform3D(Basis(), Vector3(point.x, 0.925, point.y))
		if not space.intersect_shape(query, 1).is_empty():
			return false
	return true


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_module_scene")
	else:
		print("FAILURES: ", _failures, " in test_module_scene")
	quit(0 if _failures == 0 else 1)
