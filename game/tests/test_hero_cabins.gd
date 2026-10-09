extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	var ship: Node3D = main.get_node(^"ShipGeometry") as Node3D
	for section_name: String in ["cupola", "cockpit", "quarters"]:
		var section: Node3D = main.get_node(NodePath("ShipGeometry/Section_" + section_name)) as Node3D
		var radius: float = float(TubeLayout.sections()[TubeLayout.index_of(section_name)]["radius"])
		var groups: Array[String] = ["DressingHeroRib_*", "DressingHeroShadow_*", "DressingHeroCableTray_*", "DressingHeroCableCap_*", "DressingHeroCableClip_*"]
		var counts: Array[int] = [10, 10, 2, 4, 6]
		var labels: Array[String] = ["rib frames", "rib shadow backers", "cable trays", "cable end caps", "cable clips"]
		for index: int in groups.size():
			var details: Array[Node] = section.find_children(groups[index], "MeshInstance3D", true, false)
			_check(details.size() == counts[index], section_name + " has " + str(counts[index]) + " " + labels[index])
			if index == 0 and not details.is_empty():
				var paint: StandardMaterial3D = (details[0] as MeshInstance3D).material_override as StandardMaterial3D
				_check(paint != null and paint.roughness >= 0.75 and paint.roughness_texture != null, section_name + " ribs use the restrained matte hero paint")
			var fits: bool = true
			var collision_free: bool = true
			for detail: Node in details:
				if not _mesh_fits_profile(detail as MeshInstance3D, ship, radius):
					fits = false
				if not detail.find_children("*", "CollisionShape3D", true, false).is_empty():
					collision_free = false
			_check(fits, section_name + " " + labels[index] + " stay inside the pressure cabin")
			_check(collision_free, section_name + " " + labels[index] + " add no passage collider")
	var hull: Node3D = main.get_node(^"ShipGeometry/HullExterior") as Node3D
	var utilities: Array[Node] = hull.find_children("HeroUtility_*", "Node3D", false, false)
	_check(utilities.size() == 4, "cockpit carries four authored wall utility fittings")
	var cockpit_radius: float = float(TubeLayout.sections()[TubeLayout.index_of("cockpit")]["radius"])
	for utility: Node in utilities:
		var mesh: MeshInstance3D = utility.get_node_or_null(^"Model/hw_utility_spine") as MeshInstance3D
		var live: bool = mesh != null and mesh.is_inside_tree() and mesh.mesh != null
		_check(live, "utility resolves to its live authored mesh")
		if not live:
			continue
		var bounds: AABB = mesh.get_aabb()
		_check(mesh.mesh.get_surface_count() > 0 and bounds.has_volume(), "utility has nonempty exported geometry")
		var side: float = signf(utility.position.x)
		var inward: Vector3 = Vector3(-side, 0.0, 0.0)
		_check(mesh.global_transform.basis.z.normalized().dot(inward) > 0.99, "utility faces into the cockpit")
		_check(_mesh_fits_profile(mesh, ship, cockpit_radius), "utility clears the cockpit wall and upper bevel")
		var ship_position: Vector3 = ship.to_local(utility.global_position)
		_check(String(TubeLayout.section_at(ship_position.z).get("name", "")) == "cockpit", "utility is mounted in the cockpit drum")
		_check(utility.find_children("*", "CollisionShape3D", true, false).is_empty(), "shallow wall fitting does not add a passage obstacle")
	var lights: Array[Node] = main.find_children("CabinLight*", "OmniLight3D", true, false)
	for node: Node in lights:
		var light: OmniLight3D = node as OmniLight3D
		var data: Dictionary = TubeLayout.section_at(light.position.z)
		if String(data.get("name", "")) in ["cupola", "cockpit", "quarters"]:
			_check(light.light_color.b < 0.55 and light.omni_range < 5.0, "hero lamp has warm localized practical light")
	main.free()
	if _failures == 0:
		print("PASS: test_hero_cabins")
		quit(0)
	else:
		quit(1)


func _mesh_fits_profile(mesh: MeshInstance3D, ship: Node3D, radius: float) -> bool:
	if mesh == null or not mesh.is_inside_tree() or mesh.mesh == null:
		return false
	var local_to_ship: Transform3D = ship.global_transform.affine_inverse() * mesh.global_transform
	var bounds: AABB = mesh.get_aabb()
	if not bounds.has_volume():
		return false
	for corner: int in 8:
		var point: Vector3 = local_to_ship * bounds.get_endpoint(corner)
		if point.y > SectionHull.TUBE_CEILING + 0.03 or absf(point.x) > SectionHull.tube_half_width(radius, point.y) + 0.03:
			return false
	return true


func _check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		_failures += 1
