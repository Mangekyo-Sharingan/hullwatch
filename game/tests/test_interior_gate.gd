extends SceneTree

const OFFSETS: Array[float] = [-0.12, 0.0, 0.12]
const STEP: float = 0.12

var _failures: int = 0
var _checks: int = 0
var _fans: int = 0
var _passages: int = 0
var _throats: int = 0
var _machine_loadouts: int = 0
var _main: Node
var _player: CharacterBody3D
var _shape: CollisionShape3D
var _space: PhysicsDirectSpaceState3D
var _structure_exclude: Array[RID] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame
	root.get_node("SimClock").call("set_paused", true)
	_player = _main.get_node("Player") as CharacterBody3D
	_player.set_physics_process(false)
	_player.set_process(false)
	_player.transform = Transform3D.IDENTITY
	_player.velocity = Vector3.ZERO
	_shape = _player.get_node("CollisionShape3D") as CollisionShape3D
	_check(_shape.shape is CapsuleShape3D, "fixture real Player capsule", Vector3.ZERO)
	_space = _player.get_world_3d().direct_space_state
	await physics_frame
	await physics_frame
	_collect_exclusions(_main)
	for node: Node in get_nodes_in_group(&"ship_door"):
		await _door(node as Door, false)
	for index: int in TubeLayout.sections().size():
		if not TubeLayout.is_walkable(index):
			continue
		var bounds: Vector2 = TubeLayout.span(index)
		var label: String = String(TubeLayout.sections()[index]["name"])
		for fraction: float in [0.25, 0.5, 0.75]:
			var z: float = lerpf(bounds.x, bounds.y, fraction)
			var clear_lane: bool = false
			for x: float in [-0.6, 0.0, 0.6, -1.05, 1.05]:
				if absf(x) > float(TubeLayout.sections()[index]["radius"]) * SectionHull.TUBE_DECK_HALF - 0.05:
					continue
				var feet: Vector3 = Vector3(x, 0.02, z)
				_deck_headroom(label, feet)
				if _overlap(feet).is_empty():
					clear_lane = true
			_check(clear_lane, label + " standing lane", Vector3(0.0, 0.02, z))
		for x: float in [-0.6, 0.0, 0.6]:
			_fan(label, Vector3(x, 1.4, (bounds.x + bounds.y) * 0.5))
	for bay: Dictionary in TubeLayout.service_bays():
		var side: float = float(bay["side"])
		var z: float = float(bay["center_z"])
		var x: float = float(bay["inner_x"]) + side * 0.55
		_deck_headroom(String(bay["name"]), Vector3(x, 0.02, z))
		_fan(String(bay["name"]), Vector3(x, 1.4, z))
		_profile(String(bay["name"]), TubeLayout.index_of(String(bay["section"])), side, _main.get_node("ShipGeometry/ServiceBayThroat_" + String(bay["name"])) as CollisionObject3D)
		for offset: float in OFFSETS:
			_round_trip(String(bay["name"]), Vector3(side * 0.6, 0.02, z + offset), Vector3(x, 0.02, z + offset))
	for index: int in TubeLayout.sections().size():
		if TubeLayout.port_of(index) != &"":
			var id: String = String(TubeLayout.port_of(index)).trim_prefix("hp_")
			var plate: Node3D = _main.get_node("ShipGeometry/HullExterior/DockPlate_" + id) as Node3D
			_profile(id + " dock", index, signf(plate.position.x), _main.get_node("ShipGeometry/HullExterior") as CollisionObject3D)
		if bool(TubeLayout.sections()[index].get("outer_hatch", false)):
			_profile("airlock outer", index, -1.0, _main.get_node("ShipGeometry/HullExterior") as CollisionObject3D)
	_check(_throats == 7, "all seven shared throats", Vector3.ZERO)
	for node: Node in get_nodes_in_group(&"ship_door"):
		var door: Door = node as Door
		if door.airlock_side != &"outer":
			await _door(door, true)
	for index: int in TubeLayout.sections().size() - 1:
		if not TubeLayout.has_hatch(index):
			continue
		var label: String = "%s -> %s" % [TubeLayout.sections()[index]["name"], TubeLayout.sections()[index + 1]["name"]]
		for offset: float in OFFSETS:
			_round_trip(label, Vector3(offset, 0.02, TubeLayout.span(index).y - 0.3), Vector3(offset, 0.02, TubeLayout.span(index + 1).x + 0.3))
	await _dock_routes()
	# The outer-hatch fixture respects the interlock and vents only this disposable scene.
	for node: Node in get_nodes_in_group(&"ship_door"):
		var door: Door = node as Door
		if door.airlock_side == &"inner":
			await _door(door, false)
	var airlock: Node = _main.get_node("Systems/AirlockSystem")
	_check(bool(airlock.call("request_cycle", &"vent")), "outer fixture vent accepted", Vector3.ZERO)
	airlock.call("sim_tick", 0.03)
	var outer: Door = _main.get_node("WorldLayout/Props/DoorAirlockOuter") as Door
	await _door(outer, true)
	for offset: float in OFFSETS:
		_round_trip("airlock outer hatch", Vector3(outer.position.x + 0.4, 0.02, outer.position.z + offset), Vector3(outer.position.x - 0.4, 0.02, outer.position.z + offset), false)
	_main.free()
	await process_frame
	print("COVERAGE: checks=%d pressure_rays=%d bidirectional_passages=%d shared_throats=%d" % [_checks, _fans, _passages, _throats])
	print("MACHINE COVERAGE: catalog_loadouts=%d copies_per_loadout=3" % _machine_loadouts)
	print("SCOPE: sampled geometry and verified capsule routes; not a global no-sheets assertion")
	if _failures == 0:
		print("PASS: test_interior_gate")
	else:
		print("FAILURES: %d in test_interior_gate" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, label: String, pose: Vector3, hit: Node = null) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: %s pose=%s hit=%s" % [label, pose, String(hit.get_path()) if is_instance_valid(hit) else "<none>"])


func _collect_exclusions(node: Node) -> void:
	if node is CollisionObject3D:
		var body: CollisionObject3D = node as CollisionObject3D
		if not _main.get_node("ShipGeometry").is_ancestor_of(body) and not body is Door:
			_structure_exclude.append(body.get_rid())
	for child: Node in node.get_children():
		_collect_exclusions(child)


func _ray(from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = exclude
	query.hit_back_faces = true
	query.collide_with_areas = false
	return _space.intersect_ray(query)


func _deck_headroom(label: String, feet: Vector3) -> void:
	var down: Dictionary = _ray(feet + Vector3.UP * 0.2, feet - Vector3.UP * 0.3, _structure_exclude)
	_check(not down.is_empty() and absf((down.get("position", Vector3.INF) as Vector3).y) < 0.03, label + " floor", feet, down.get("collider") as Node)
	var up: Dictionary = _ray(feet + Vector3.UP * 0.1, feet + Vector3.UP * 4.0, _structure_exclude)
	var capsule: CapsuleShape3D = _shape.shape as CapsuleShape3D
	_check(not up.is_empty() and (up.get("position", Vector3.ZERO) as Vector3).y >= feet.y + capsule.height, label + " headroom", feet, up.get("collider") as Node)


func _fan(label: String, eye: Vector3) -> void:
	for i: int in 128:
		var y: float = 1.0 - 2.0 * (float(i) + 0.5) / 128.0
		var radial: float = sqrt(1.0 - y * y)
		var direction: Vector3 = Vector3(cos(float(i) * 2.399963) * radial, y, sin(float(i) * 2.399963) * radial)
		var hit: Dictionary = _ray(eye, eye + direction * 40.0, _structure_exclude)
		_check(not hit.is_empty(), "%s closed pressure fan ray=%d dir=%s" % [label, i, direction], eye, hit.get("collider") as Node)
		_fans += 1


func _profile(label: String, index: int, side: float, target: CollisionObject3D) -> void:
	var radius: float = float(TubeLayout.sections()[index]["radius"])
	var bounds: Vector2 = TubeLayout.span(index)
	var z: float = (bounds.x + bounds.y) * 0.5
	var exclude: Array[RID] = []
	var bay_face: CollisionObject3D = _main.get_node_or_null("ShipGeometry/ServiceBay_" + label) as CollisionObject3D
	for body: Node in _main.find_children("*", "CollisionObject3D", true, false):
		if body != target and body != bay_face:
			exclude.append((body as CollisionObject3D).get_rid())
	for y: float in [1.1, 1.4, 1.55, 1.7, 1.85]:
		for edge: float in [-1.0, 1.0]:
			for inset: float in [0.03, 0.15, 0.35]:
				var from: Vector3 = Vector3(side * (SectionHull.tube_half_width(radius, y) - inset), y, z + edge * 0.6 - 0.2)
				for direction: float in [-1.0, 1.0]:
					var start: Vector3 = from + Vector3(0.0, 0.0, 0.4 if direction < 0.0 else 0.0)
					var hit: Dictionary = _ray(start, start + Vector3(0.0, 0.0, direction * 0.4), exclude)
					_check(hit.is_empty(), label + " shoulder profile", start, hit.get("collider") as Node)
			var control: Vector3 = Vector3(side * (SectionHull.tube_half_width(radius, y) + 0.03), y, z + edge * 0.6 - 0.2)
			var control_end: Vector3 = control + Vector3(0.0, 0.0, 0.4)
			if bay_face != null:
				control = Vector3(side * (SectionHull.tube_half_width(radius, y) - 0.2), y, z + edge * 0.8)
				control_end = control + Vector3(side * 0.5, 0.0, 0.0)
			var hit: Dictionary = _ray(control, control_end, exclude)
			_check(not hit.is_empty(), label + " jamb positive control", control, hit.get("collider") as Node)
	_throats += 1


func _door(door: Door, open: bool) -> void:
	_check(door.request_open(open), "%s request open=%s" % [door.name, open], door.global_position, door)
	var slab: CollisionShape3D = door.get_node("SlabShape") as CollisionShape3D
	for frame: int in 90:
		await physics_frame
		if slab.disabled == open and door.get("_motion_tween") == null:
			break
	_check(door.is_open() == open and slab.disabled == open and door.get("_motion_tween") == null, "%s settled open=%s" % [door.name, open], door.global_position, door)


func _overlap(feet: Vector3) -> Array[Dictionary]:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _shape.shape
	query.transform = Transform3D(Basis.IDENTITY, feet) * _shape.transform
	query.collision_mask = _player.collision_mask
	query.exclude = [_player.get_rid()]
	return _space.intersect_shape(query, 1)


func _travel(label: String, finish: Vector3, floor_required: bool = true) -> bool:
	var start: Vector3 = _player.global_position
	var steps: int = maxi(1, ceili(start.distance_to(finish) / STEP))
	for i: int in steps:
		var target: Vector3 = start.lerp(finish, float(i + 1) / float(steps))
		var contact: KinematicCollision3D = _player.move_and_collide(target - _player.global_position)
		if contact != null:
			_check(false, "%s capsule travel target=%s %s" % [label, target, _contact_details(contact)], _player.global_position, contact.get_collider() as Node)
			return false
		# A capsule can bridge a short sill gap; its center ray alone is not foot support.
		var supported: bool = not floor_required
		var radius: float = (_shape.shape as CapsuleShape3D).radius
		for offset: Vector3 in [Vector3.ZERO, Vector3.RIGHT * radius, Vector3.LEFT * radius, Vector3.FORWARD * radius, Vector3.BACK * radius]:
			var foot: Vector3 = _player.global_position + offset
			if not _ray(foot + Vector3.UP * 0.2, foot - Vector3.UP * 0.3, [_player.get_rid()]).is_empty():
				supported = true
		if not supported:
			_check(false, label + " travel floor", _player.global_position)
			return false
	var reached: bool = _player.global_position.distance_to(finish) < 0.005
	_check(reached, label + " actual displacement from=" + str(start), _player.global_position)
	return reached


func _round_trip(label: String, start: Vector3, finish: Vector3, floor_required: bool = true) -> void:
	var hits: Array[Dictionary] = _overlap(start)
	_check(hits.is_empty(), label + " start capsule", start, hits[0].get("collider") as Node if not hits.is_empty() else null)
	var finish_hits: Array[Dictionary] = _overlap(finish)
	_check(finish_hits.is_empty(), label + " finish capsule", finish, finish_hits[0].get("collider") as Node if not finish_hits.is_empty() else null)
	if not hits.is_empty() or not finish_hits.is_empty():
		return
	_player.global_position = start
	if _travel(label + " forward", finish, floor_required) and _travel(label + " return", start, floor_required):
		_passages += 1


func _dock_routes() -> void:
	var cargo: Node = _main.get_node("Systems/CargoSystem")
	var modules: Node = _main.get_node("Systems/ModuleSystem")
	cargo.call("add_material", &"metal", 20.0)
	cargo.call("add_material", &"ore", 10.0)
	cargo.call("add_material", &"ice", 4.0)
	for id: String in ["quarters", "life_support", "galley", "engine_bay"]:
		var plate: ModuleMount = _main.get_node("ShipGeometry/HullExterior/DockPlate_" + id) as ModuleMount
		var module_id: StringName = {"quarters": &"utility_pod", "life_support": &"workshop", "galley": &"storage_pod", "engine_bay": &"aux_battery"}[id]
		_check(plate.select_action(StringName("build:" + String(module_id))), id + " fixture build", plate.position, plate)
		modules.call("sim_tick", 24.0)
		await process_frame
		await physics_frame
		await physics_frame
		var pod: Node3D = _main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_" + id) as Node3D
		_check(pod != null, id + " installed pod", plate.position, plate)
		if pod == null:
			continue
		var panel: Node3D = pod.get_node("ServicePanel") as Node3D
		var panel_eye: Vector3 = pod.to_global(Vector3(2.0, 1.3, 0.6))
		var panel_hit: Dictionary = _ray(panel_eye, panel.global_position, [_player.get_rid()])
		_check(panel_hit.get("collider") == panel, id + " pod panel is exposed inside the pressure wall", panel_eye, panel_hit.get("collider") as Node)
		var index: int = -1
		for candidate: int in TubeLayout.sections().size():
			if TubeLayout.port_of(candidate) == plate.hardpoint_id:
				index = candidate
		_check(index >= 0, id + " dock section", plate.global_position, plate)
		if index >= 0:
			var side: float = signf(plate.global_position.x)
			var radius: float = float(TubeLayout.sections()[index]["radius"])
			var bounds: Vector2 = TubeLayout.span(index)
			var center_z: float = (bounds.x + bounds.y) * 0.5
			for offset: float in OFFSETS:
				var start: Vector3 = Vector3(side * (SectionHull.tube_half_width(radius, 1.55) - 0.3), 0.02, center_z + offset)
				var finish: Vector3 = Vector3(plate.global_position.x + side * 0.45, 0.02, center_z + offset)
				_round_trip("%s fixed dock throat offset=%.2f" % [id, offset], start, finish)
		for offset: float in OFFSETS:
			_dock_walk(id, plate, offset)
		if id == "quarters":
			await _machine_clearance(pod, plate, modules, cargo)
			pod = _main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_" + id) as Node3D
			if pod == null:
				continue
		var room: ModuleMount = pod.get_node("PodRoom") as ModuleMount
		_check(room.select_action(&"teardown"), id + " fixture teardown", room.global_position, room)
		await process_frame
		await physics_frame
		await physics_frame


func _dock_walk(label: String, plate: ModuleMount, offset: float) -> void:
	var side: float = signf(plate.global_position.x)
	var start: Vector3 = Vector3(0.0, 0.02, plate.global_position.z + offset)
	var start_hits: Array[Dictionary] = _overlap(start)
	_check(start_hits.is_empty(), label + " dock start capsule", start, start_hits[0].get("collider") as Node if not start_hits.is_empty() else null)
	if not start_hits.is_empty():
		return
	var target_x: float = plate.global_position.x + side * 0.45
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var parents: Dictionary = {Vector2i.ZERO: Vector2i.ZERO}
	var end: Vector2i = Vector2i(-1, 0)
	var max_x: int = ceili(absf(target_x) / STEP)
	var max_z: int = floori(1.2 / STEP)
	var last_hit: Node = null
	var rejected: PackedStringArray = PackedStringArray()
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell.x >= max_x and cell.y == 0:
			end = cell
			break
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if next.x < 0 or next.x > max_x or absi(next.y) > max_z or parents.has(next):
				continue
			var feet: Vector3 = start + Vector3(side * next.x * STEP, 0.0, next.y * STEP)
			var hits: Array[Dictionary] = _overlap(feet)
			if not hits.is_empty():
				last_hit = hits[0].get("collider") as Node
				rejected.append("overlap pose=%s hit=%s shape_index=%s" % [feet, last_hit.get_path(), hits[0].get("shape")])
				continue
			var previous: Vector3 = start + Vector3(side * cell.x * STEP, 0.0, cell.y * STEP)
			var contact: KinematicCollision3D = KinematicCollision3D.new()
			if _player.test_move(Transform3D(Basis.IDENTITY, previous), feet - previous, contact):
				last_hit = contact.get_collider() as Node
				rejected.append("motion from=%s to=%s %s" % [previous, feet, _contact_details(contact)])
				continue
			if _player.test_move(Transform3D(Basis.IDENTITY, feet), previous - feet, contact):
				last_hit = contact.get_collider() as Node
				rejected.append("motion from=%s to=%s %s" % [feet, previous, _contact_details(contact)])
				continue
			parents[next] = cell
			queue.append(next)
	_check(end.x >= 0, label + " connected dock route offset=" + str(offset), start, last_hit)
	if end.x < 0:
		_print_rejected(label, offset, rejected)
		return
	var path: Array[Vector2i] = [end]
	while path[-1] != Vector2i.ZERO:
		path.append(parents[path[-1]])
	path.reverse()
	var poses: PackedVector3Array = PackedVector3Array()
	for cell: Vector2i in path:
		poses.append(start + Vector3(side * cell.x * STEP, 0.0, cell.y * STEP))
	print("ROUTE: room=%s offset=%.2f waypoints=%s" % [label, offset, poses])
	_player.global_position = start
	for cell: Vector2i in path:
		if not _travel(label + " dock forward", start + Vector3(side * cell.x * STEP, 0.0, cell.y * STEP)):
			_print_rejected(label, offset, rejected)
			return
	path.reverse()
	for cell: Vector2i in path:
		if not _travel(label + " dock return", start + Vector3(side * cell.x * STEP, 0.0, cell.y * STEP)):
			_print_rejected(label, offset, rejected)
			return
	_passages += 1


func _contact_details(contact: KinematicCollision3D) -> String:
	var body: CollisionObject3D = contact.get_collider() as CollisionObject3D
	var index: int = contact.get_collider_shape_index()
	var shape_node: Node = contact.get_collider_shape() as Node
	return "contact=%s normal=%s collider=%s shape_index=%d shape_node=%s" % [contact.get_position(), contact.get_normal(), body.get_path() if body != null else "<none>", index, shape_node.get_path() if shape_node != null else "<none>"]


func _print_rejected(label: String, offset: float, rejected: PackedStringArray) -> void:
	for detail: String in rejected:
		print("REJECTED: room=%s offset=%.2f %s" % [label, offset, detail])


func _machine_clearance(pod: Node3D, plate: ModuleMount, modules: Node, cargo: Node) -> void:
	var catalog: Array[ShipMachine] = modules.call("get_machine_catalog") as Array[ShipMachine]
	_check(not catalog.is_empty(), "machine catalog fixture", pod.global_position)
	var fixture_units: float = 0.0
	for machine: ShipMachine in catalog:
		for units: Variant in machine.cost.values():
			fixture_units += float(units) * 3.0
	cargo.call("set_capacity_source", &"interior_gate_fixture", fixture_units)
	var current: Node3D = pod
	for machine: ShipMachine in catalog:
		var label: String = "utility pod three " + String(machine.machine_id)
		for kind: Variant in machine.cost:
			var wanted: float = float(machine.cost[kind]) * 3.0
			var missing: float = maxf(0.0, wanted - float(cargo.call("get_units", StringName(String(kind)))))
			_check(is_equal_approx(float(cargo.call("add_material", StringName(String(kind)), missing)), missing), label + " fixture materials", current.global_position)
		for socket: int in 3:
			_check(bool(modules.call("fit_machine", machine.machine_id, StringName("hp_quarters:%d" % socket))), label + " fitting socket=%d" % socket, current.global_position)
		modules.call("sim_tick", machine.build_hours)
		await process_frame
		await physics_frame
		await physics_frame
		for socket: int in 3:
			var socket_id: StringName = StringName("hp_quarters:%d" % socket)
			_check(StringName(modules.call("get_machine_at", socket_id)) == machine.machine_id, label + " fitted socket=%d" % socket, current.global_position)
		var rendered: int = 0
		for child: Node in current.get_children():
			if not child is MachineSocket:
				continue
			var prop: Node3D = child.get_node_or_null("MachineProp") as Node3D
			var model: Node = prop.get_child(0) if prop != null and prop.get_child_count() > 0 else null
			_check(model != null and model.scene_file_path == machine.model_path, label + " authored model socket=" + String(child.name), (child as Node3D).global_position, model)
			if model != null and model.scene_file_path == machine.model_path:
				rendered += 1
		_check(rendered == 3, label + " three authored models", current.global_position)
		_round_trip(label + " entry lane", current.to_global(Vector3(0.5, 0.02, 0.0)), current.to_global(Vector3(2.3, 0.02, 0.0)))
		for side: float in [-1.0, 1.0]:
			_round_trip(label + " service apron side=" + str(side), current.to_global(Vector3(2.3, 0.02, 0.0)), current.to_global(Vector3(2.3, 0.02, side * 0.6)))
		_machine_loadouts += 1
		if machine.portable:
			for socket: int in 3:
				_check(bool(modules.call("remove_machine", StringName("hp_quarters:%d" % socket))), label + " remove socket=%d" % socket, current.global_position)
		else:
			# Bolted machinery leaves through pod teardown, preserving catalog portability.
			var room: ModuleMount = current.get_node("PodRoom") as ModuleMount
			_check(room.select_action(&"teardown"), label + " teardown clears bolted machines", current.global_position, room)
			await process_frame
			var module: ShipModule = modules.call("get_module", &"utility_pod") as ShipModule
			_check(plate.select_action(&"build:utility_pod"), label + " rebuild bare fixture", plate.global_position, plate)
			modules.call("sim_tick", module.build_hours)
			await process_frame
			current = _main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_quarters") as Node3D
			_check(current != null, label + " bare fixture restored", plate.global_position, plate)
			if current == null:
				return
		await physics_frame
		await physics_frame
		for socket: int in 3:
			_check(StringName(modules.call("get_machine_at", StringName("hp_quarters:%d" % socket))) == &"", label + " socket cleared=%d" % socket, current.global_position)
	cargo.call("set_capacity_source", &"interior_gate_fixture", 0.0)
