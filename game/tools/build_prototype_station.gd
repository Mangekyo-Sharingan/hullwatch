## Design study (throwaway, not part of the game): builds a grey-block of the reference
## station from `Reference/station_design.jpg` - a stack of cylindrical pressurised drums and
## ribbed tanks along the ship's own axis, joined by flanges, with solar arrays on booms and a
## docking node forward. Everything is a Godot primitive so the study stays cheap; the point is
## to judge proportions at Hullwatch's scale, not to ship geometry.
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/build_prototype_station.gd
extends SceneTree

const OUTPUT_PATH: String = "res://scenes/prototype_station.tscn"
const MATERIAL_SHELL: String = "res://src/data/materials/mat_xenon_metal.tres"
const MATERIAL_RING: String = "res://src/data/materials/mat_metal_rusted.tres"
const PANEL_COLOR: Color = Color(0.05, 0.07, 0.18)
const MATERIAL_GLASS: String = "res://src/data/materials/mat_phosphor_amber.tres"
const MATERIAL_HATCH: String = "res://src/data/materials/mat_wall_painted.tres"
const RING_LENGTH: float = 0.55
const RING_GROWTH: float = 0.22

## Section stack, aft (+z) to bow (-z): the ship's own length, so the retrofit question is
## "does this read better than the faceted hull", not "does it still fit the world".
const SECTIONS: Array[Dictionary] = [
	{"kind": "drum", "length": 4.6, "radius": 3.2, "hatches": 4},
	{"kind": "tank", "length": 4.6, "radius": 4.0, "ribs": 18},
	{"kind": "drum", "length": 5.4, "radius": 3.5, "hatches": 4},
	{"kind": "tank", "length": 4.6, "radius": 4.2, "ribs": 18},
	{"kind": "drum", "length": 4.2, "radius": 3.4, "hatches": 4},
	{"kind": "node", "length": 2.6, "radius": 2.6},
]
const AFT_Z: float = 8.2
const ARRAYS: Array[Dictionary] = [
	{"z": -3.0, "roll": 25.0, "base": 3.7, "span": 9.0, "chord": 3.2},
	{"z": -3.0, "roll": 205.0, "base": 3.7, "span": 9.0, "chord": 3.2},
	{"z": -16.0, "roll": 115.0, "base": 3.6, "span": 7.0, "chord": 2.6},
	{"z": -16.0, "roll": 295.0, "base": 3.6, "span": 7.0, "chord": 2.6},
	{"z": 5.4, "roll": 90.0, "base": 3.4, "span": 5.5, "chord": 2.2},
	{"z": 5.4, "roll": 270.0, "base": 3.4, "span": 5.5, "chord": 2.2},
]


func _initialize() -> void:
	_build()
	quit(0)


func _build() -> void:
	var root_node: Node3D = Node3D.new()
	root_node.name = "PrototypeStation"
	var shell: Material = load(MATERIAL_SHELL) as Material
	var ring_material: Material = load(MATERIAL_RING) as Material
	var panel_material: StandardMaterial3D = StandardMaterial3D.new()
	panel_material.albedo_color = PANEL_COLOR
	panel_material.metallic = 0.25
	panel_material.roughness = 0.35
	var glass: Material = load(MATERIAL_GLASS) as Material
	var hatch_material: Material = load(MATERIAL_HATCH) as Material
	var cursor: float = AFT_Z
	var index: int = 0
	for section: Dictionary in SECTIONS:
		var length: float = float(section["length"])
		var radius: float = float(section["radius"])
		var center: float = cursor - length * 0.5
		match String(section["kind"]):
			"drum":
				_add_drum(root_node, center, length, radius, shell, hatch_material, int(section.get("hatches", 0)))
			"tank":
				_add_tank(root_node, center, length, radius, shell, shell, int(section.get("ribs", 16)))
			"node":
				_add_node(root_node, center, length, radius, shell, ring_material, glass)
		cursor -= length
		if index < SECTIONS.size() - 1:
			var next_radius: float = float(SECTIONS[index + 1]["radius"])
			_add_ring(root_node, cursor - RING_LENGTH * 0.5, RING_LENGTH, maxf(radius, next_radius), ring_material)
			cursor -= RING_LENGTH
		index += 1
	for array: Dictionary in ARRAYS:
		_add_array(root_node, float(array["z"]), deg_to_rad(float(array["roll"])), float(array["base"]), float(array["span"]), float(array["chord"]), panel_material, ring_material)
	var packed: PackedScene = PackedScene.new()
	_set_owner(root_node, root_node)
	packed.pack(root_node)
	var code: int = ResourceSaver.save(packed, OUTPUT_PATH)
	if code != OK:
		print("FAIL: could not write ", OUTPUT_PATH, " (", code, ")")
		return
	print("PASS: build_prototype_station -> ", OUTPUT_PATH, " sections=", SECTIONS.size(), " arrays=", ARRAYS.size(), " span_z=", AFT_Z - cursor)


func _add_drum(parent: Node3D, z: float, length: float, radius: float, shell: Material, ring: Material, hatches: int) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 32
	_add_mesh(parent, "Drum", mesh, Vector3(0.0, 0.0, z), shell)
	for i: int in hatches:
		var angle: float = TAU * (float(i) + 0.5) / float(maxi(hatches, 1))
		var hatch: BoxMesh = BoxMesh.new()
		hatch.size = Vector3(0.16, 1.1, 1.5)
		var node: MeshInstance3D = _add_mesh(parent, "Hatch", hatch, Vector3(0.0, 0.0, z), ring)
		node.position = Vector3(cos(angle) * (radius + 0.06), sin(angle) * (radius + 0.06), z)
		node.rotation = Vector3(0.0, 0.0, angle)


## A ribbed tank: a sphere inside meridian bands, which is the reference's onion read.
func _add_tank(parent: Node3D, z: float, length: float, radius: float, shell: Material, rib_material: Material, ribs: int) -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = length
	sphere.radial_segments = 32
	sphere.rings = 16
	_add_mesh(parent, "Tank", sphere, Vector3(0.0, 0.0, z), shell)
	for i: int in ribs:
		var rib: TorusMesh = TorusMesh.new()
		rib.inner_radius = radius * 0.995
		rib.outer_radius = 0.07
		var segments: int = 48
		rib.rings = segments
		var node: MeshInstance3D = _add_mesh(parent, "Rib", rib, Vector3(0.0, 0.0, z), rib_material)
		node.rotation = Vector3(PI * 0.5, 0.0, TAU * float(i) / float(maxi(ribs, 1)))


## Forward docking node: short drum, cupola windows and a docking cone - the reference's bow.
func _add_node(parent: Node3D, z: float, length: float, radius: float, shell: Material, ring: Material, glass: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 32
	_add_mesh(parent, "Node", mesh, Vector3(0.0, 0.0, z), shell)
	for i: int in 8:
		var angle: float = TAU * (float(i) + 0.5) / 8.0
		var pane: BoxMesh = BoxMesh.new()
		pane.size = Vector3(0.2, 0.7, 0.9)
		var node: MeshInstance3D = _add_mesh(parent, "Cupola", pane, Vector3(0.0, 0.0, z), glass)
		node.position = Vector3(cos(angle) * (radius + 0.04), sin(angle) * (radius + 0.04), z)
		node.rotation = Vector3(0.0, 0.0, angle)
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.55
	cone.bottom_radius = 0.95
	cone.height = 1.3
	_add_mesh(parent, "DockingCone", cone, Vector3(0.0, 0.0, z - length * 0.5 - 0.65), ring)
	var dish: SphereMesh = SphereMesh.new()
	dish.radius = 0.9
	dish.height = 0.5
	dish.is_hemisphere = true
	var dish_node: MeshInstance3D = _add_mesh(parent, "Dish", dish, Vector3(0.0, radius + 0.4, z), ring)
	dish_node.rotation = Vector3(PI * 0.5, 0.0, PI)


## The flange between two sections: a shallow, slightly wider drum.
func _add_ring(parent: Node3D, z: float, length: float, radius: float, ring: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius + RING_GROWTH
	mesh.bottom_radius = radius + RING_GROWTH
	mesh.height = length
	mesh.radial_segments = 32
	_add_mesh(parent, "Flange", mesh, Vector3(0.0, 0.0, z), ring)


## Boom plus panel, rolled around the hull axis like the reference's arrays. Built on an
## explicit basis so the span runs radially, the chord along the hull axis and the panel's
## broad face tangentially - the read the reference's arrays have from the side.
func _add_array(parent: Node3D, z: float, roll: float, base: float, span: float, chord: float, panel_material: Material, boom_material: Material) -> void:
	var radial: Vector3 = Vector3(cos(roll), sin(roll), 0.0)
	var axial: Vector3 = Vector3(0.0, 0.0, 1.0)
	var boom_length: float = 2.4
	var boom: CylinderMesh = CylinderMesh.new()
	boom.top_radius = 0.12
	boom.bottom_radius = 0.12
	boom.height = boom_length
	boom.radial_segments = 12
	var boom_node: MeshInstance3D = _add_mesh(parent, "Boom", boom, Vector3(0.0, 0.0, z), boom_material)
	boom_node.basis = Basis(Quaternion(Vector3.UP, radial))
	var boom_start: float = base * 0.55
	boom_node.position = Vector3(radial.x * (boom_start + boom_length * 0.5), radial.y * (boom_start + boom_length * 0.5), z)
	var panel: BoxMesh = BoxMesh.new()
	panel.size = Vector3(span, chord, 0.08)
	var panel_node: MeshInstance3D = _add_mesh(parent, "Array", panel, Vector3(0.0, 0.0, z), panel_material)
	var offset: float = boom_start + boom_length + span * 0.5
	panel_node.transform = Transform3D(Basis(radial, axial, radial.cross(axial)), Vector3(radial.x * offset, radial.y * offset, z))


func _add_mesh(parent: Node3D, name: String, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance


## Packed scenes only keep nodes that are owned by the root; assign it recursively.
func _set_owner(node: Node, root_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root_node
		_set_owner(child, root_node)
