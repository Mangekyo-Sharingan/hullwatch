extends Node3D


func _enter_tree() -> void:
	if get_node_or_null(^"ShipGeometry/Section_storage") == null:
		return
	# Filter before system ready so retired flat rooms cannot develop unreachable faults.
	var active: Array = TubeLayout.ROOM_COMPARTMENTS.values()
	for path: NodePath in [^"Systems/AtmosphereSystem", ^"Systems/ThermalSystem", ^"Systems/HullSystem"]:
		var system: Node = get_node_or_null(path)
		if system == null:
			continue
		var definitions: Array = system.get("compartment_defs")
		var fitted: Array[CompartmentConfig] = []
		for config: CompartmentConfig in definitions:
			if active.has(config.compartment_id):
				fitted.append(config)
		system.set("compartment_defs", fitted)
