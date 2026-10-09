class_name SalvageWreck
extends SpaceObject

var _unit_id: String = ""
var _equipment: MeshInstance3D


func build(entry: Dictionary) -> void:
	setup(entry)
	var salvage: Node = _get_system(&"salvage_system")
	var sector: Node = _get_system(&"sector_system")
	if salvage == null or sector == null:
		return
	_unit_id = String(salvage.call("register_unit", object_id, int(sector.get("field_seed"))))
	var paint: Material = load("res://src/data/materials/mat_machine_teal.tres") as Material
	var frame: Material = load("res://src/data/materials/mat_machined_metal.tres") as Material
	_piece(self, Vector3(3.2, 0.15, 5.0), Vector3(0, -0.15, 0), frame)
	_piece(self, Vector3(0.15, 2.7, 5.0), Vector3(-1.6, 1.2, 0), frame)
	_piece(self, Vector3(0.15, 2.7, 2.0), Vector3(1.6, 1.2, 1.5), frame)
	for z: float in [-2.4, 0.0, 2.4]:
		_piece(self, Vector3(3.2, 0.18, 0.18), Vector3(0, 2.5, z), paint)
		_piece(self, Vector3(0.18, 2.7, 0.18), Vector3(-1.4, 1.2, z), paint)
		_piece(self, Vector3(0.18, 2.7, 0.18), Vector3(1.4, 1.2, z), paint)
	var control: SalvageMount = SalvageMount.new()
	control.name = "IsolationControl"
	control.unit_id = _unit_id
	control.action = &"isolate"
	control.position = Vector3(1.1, 1.4, 1.0)
	add_child(control)
	_piece(control, Vector3(0.25, 0.3, 0.2), Vector3.ZERO, paint)
	var label: Label3D = Label3D.new()
	label.text = "RECOVERY SUPPLY / ISOLATE"
	label.position = Vector3(-0.12, 0.28, 0.0)
	label.rotation_degrees.y = -90.0
	label.font_size = 32
	label.pixel_size = 0.003
	control.add_child(label)
	var mount: SalvageMount = SalvageMount.new()
	mount.name = "RecoveryMount"
	mount.unit_id = _unit_id
	mount.position = Vector3(1.0, 0.8, 0.0)
	add_child(mount)
	_equipment = _piece(mount, Vector3(0.48, 0.36, 0.32), Vector3.ZERO, paint)
	var bus: Node = _get_autoload(&"EventBus")
	if bus != null:
		bus.connect(&"salvage_changed", _on_changed)
	_on_changed(_unit_id)


func _on_changed(_changed_id: String) -> void:
	var salvage: Node = _get_system(&"salvage_system")
	if salvage != null and _equipment != null:
		if (salvage.call("get_unit", _unit_id) as Dictionary).is_empty():
			var sector: Node = _get_system(&"sector_system")
			if sector != null:
				_unit_id = String(salvage.call("register_unit", object_id, int(sector.get("field_seed"))))
				(get_node("IsolationControl") as SalvageMount).unit_id = _unit_id
				(get_node("RecoveryMount") as SalvageMount).unit_id = _unit_id
		_equipment.visible = String((salvage.call("get_unit", _unit_id) as Dictionary).get("location", "")) == "mounted"


func _piece(body: StaticBody3D, size: Vector3, offset: Vector3, material: Material) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = offset
	body.add_child(mesh)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var collision: BoxShape3D = BoxShape3D.new()
	collision.size = size
	shape.shape = collision
	shape.position = offset
	body.add_child(shape)
	return mesh
