## Design study (design tool, not part of the game): the ship re-laid as a slim modular stack
## in the reference's language - one pressurised drum per room, bulkhead hatches at the
## flanges, pods on radial ports, cupola forward, arrays on booms. The current interior is a
## wide flat layout (14 m beam, 3.6 m tall) which no slim stack can hold, so this study is the
## target layout for the tube conversion; the shells are translucent so the section
## assignment and deck discs read from outside.
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/build_hull_study.gd
extends SceneTree

const OUTPUT_PATH: String = "res://scenes/hull_study.tscn"
const MATERIAL_SHELL: String = "res://src/data/materials/mat_xenon_metal.tres"
const MATERIAL_DECK: String = "res://src/data/materials/mat_wall_painted.tres"
const MATERIAL_RING: String = "res://src/data/materials/mat_metal_rusted.tres"
const MATERIAL_DOCK: String = "res://src/data/materials/mat_machine_teal.tres"
const MATERIAL_GLASS: String = "res://src/data/materials/mat_phosphor_amber.tres"
const RING_LENGTH: float = 0.45
const DECK_THICKNESS: float = 0.12

## Bow (+z forward is negative here, same axis as the current ship) to stern. One section per
## room, sized so the deck area roughly matches the room it replaces; `pod` marks a radial
## dock port, `dome` caps the bow, `tank` is a ribbed stack section.
const SECTIONS: Array[Dictionary] = [
	{"name": "Cupola / cockpit head", "length": 2.2, "radius": 2.3, "kind": "dome"},
	{"name": "Cockpit", "length": 2.8, "radius": 2.3, "kind": "drum"},
	{"name": "Quarters", "length": 2.8, "radius": 2.3, "kind": "drum", "pod": "QUARTERS POD"},
	{"name": "Life support", "length": 2.2, "radius": 1.9, "kind": "drum", "pod": "LIFE SUPPORT POD"},
	{"name": "Galley", "length": 2.6, "radius": 2.3, "kind": "drum", "pod": "GALLEY POD"},
	{"name": "Water closet", "length": 1.8, "radius": 1.6, "kind": "drum"},
	{"name": "Storage", "length": 2.6, "radius": 2.3, "kind": "drum"},
	{"name": "Airlock", "length": 1.8, "radius": 1.6, "kind": "drum"},
	{"name": "Engine bay A", "length": 2.8, "radius": 2.6, "kind": "drum"},
	{"name": "Engine bay B", "length": 2.8, "radius": 2.6, "kind": "drum", "pod": "ENGINE BAY POD"},
	{"name": "Propellant tank", "length": 3.0, "radius": 2.6, "kind": "tank", "ribs": 16},
]
const BOW_Z: float = -21.0
const ARRAYS: Array[Dictionary] = [
	{"z": -3.0, "roll": 20.0, "base": 3.0, "span": 8.0, "chord": 2.8},
	{"z": -3.0, "roll": 200.0, "base": 3.0, "span": 8.0, "chord": 2.8},
	{"z": 8.0, "roll": 110.0, "base": 3.0, "span": 6.0, "chord": 2.4},
	{"z": 8.0, "roll": 290.0, "base": 3.0, "span": 6.0, "chord": 2.4},
]


func _initialize() -> void:
	_build()
	quit(0)


func _build() -> void:
	var station: Node3D = Node3D.new()
	station.name = "HullStudy"
	var shell: StandardMaterial3D = StandardMaterial3D.new()
	shell.albedo_color = Color(0.55, 0.58, 0.62, 0.3)
	shell.metallic = 0.4
	shell.roughness = 0.5
	shell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell.cull_mode = BaseMaterial3D.CULL_DISABLED
	var deck_material: Material = load(MATERIAL_DECK) as Material
	var ring_material: Material = load(MATERIAL_RING) as Material
	var dock_material: Material = load(MATERIAL_DOCK) as Material
	var glass: Material = load(MATERIAL_GLASS) as Material
	var cursor: float = BOW_Z
	var index: int = 0
	for section: Dictionary in SECTIONS:
		var length: float = float(section["length"])
		var radius: float = float(section["radius"])
		var center: float = cursor + length * 0.5
		match String(section["kind"]):
			"dome":
				_add_dome(station, center, radius, shell, glass)
			"tank":
				_add_tank(station, center, length, radius, shell, shell, int(section.get("ribs", 16)))
			_:
				_add_drum(station, center, length, radius, shell)
		_add_deck(station, cursor + length - DECK_THICKNESS * 0.5, radius, deck_material)
		_add_label(station, String(section["name"]), Vector3(0.0, 0.0, center), radius)
		if section.has("pod"):
			_add_pod(station, String(section["pod"]), center, radius, dock_material)
		cursor += length
		if index < SECTIONS.size() - 1:
			var next_radius: float = float(SECTIONS[index + 1]["radius"])
			_add_ring(station, cursor + RING_LENGTH * 0.5, maxf(radius, next_radius), ring_material)
			cursor += RING_LENGTH
		index += 1
	for array: Dictionary in ARRAYS:
		_add_array(station, float(array["z"]), deg_to_rad(float(array["roll"])), float(array["base"]), float(array["span"]), float(array["chord"]), ring_material)
	_set_owner(station, station)
	var packed: PackedScene = PackedScene.new()
	packed.pack(station)
	var code: int = ResourceSaver.save(packed, OUTPUT_PATH)
	if code != OK:
		print("FAIL: could not write ", OUTPUT_PATH, " (", code, ")")
		return
	print("PASS: build_hull_study -> ", OUTPUT_PATH, " sections=", SECTIONS.size(), " span=", cursor - BOW_Z)
	for section: Dictionary in SECTIONS:
		var area: float = PI * pow(float(section["radius"]), 2.0)
		print("  %-24s %5.1f m2 deck  %4.1f m long  r=%.1f" % [String(section["name"]), area, float(section["length"]), float(section["radius"])])


func _add_drum(parent: Node3D, z: float, length: float, radius: float, shell: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 32
	_add_mesh(parent, "Section", mesh, Vector3(0.0, 0.0, z), shell)


func _add_dome(parent: Node3D, z: float, radius: float, shell: Material, glass: Material) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.6
	mesh.is_hemisphere = true
	mesh.radial_segments = 32
	mesh.rings = 12
	var dome: MeshInstance3D = _add_mesh(parent, "Cupola", mesh, Vector3(0.0, 0.0, z), shell)
	dome.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	var pane: BoxMesh = BoxMesh.new()
	pane.size = Vector3(0.25, 0.9, 1.1)
	var window: MeshInstance3D = _add_mesh(parent, "Window", pane, Vector3(0.0, 0.0, z - 1.1), glass)
	window.rotation = Vector3(0.0, 0.0, PI * 0.5)


## Ribbed tank section: sphere inside meridian bands.
func _add_tank(parent: Node3D, z: float, length: float, radius: float, shell: Material, rib_material: Material, ribs: int) -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = length
	sphere.radial_segments = 32
	sphere.rings = 16
	_add_mesh(parent, "Tank", sphere, Vector3(0.0, 0.0, z), shell)
	for i: int in ribs:
		var rib: TorusMesh = TorusMesh.new()
		rib.inner_radius = radius * 0.99
		rib.outer_radius = 0.06
		rib.rings = 48
		var node: MeshInstance3D = _add_mesh(parent, "Rib", rib, Vector3(0.0, 0.0, z), rib_material)
		node.rotation = Vector3(PI * 0.5, 0.0, TAU * float(i) / float(maxi(ribs, 1)))


## The deck disc at a bulkhead: one room's floor, the ring-deck level later.
func _add_deck(parent: Node3D, z: float, radius: float, deck_material: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.95
	mesh.bottom_radius = radius * 0.95
	mesh.height = DECK_THICKNESS
	mesh.radial_segments = 32
	_add_mesh(parent, "Deck", mesh, Vector3(0.0, 0.0, z), deck_material)


func _add_ring(parent: Node3D, z: float, radius: float, ring_material: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius + 0.18
	mesh.bottom_radius = radius + 0.18
	mesh.height = RING_LENGTH
	mesh.radial_segments = 32
	_add_mesh(parent, "Flange", mesh, Vector3(0.0, 0.0, z), ring_material)


## A dock pod on a radial port, the way the reference hangs modules off its hull.
func _add_pod(parent: Node3D, label: String, z: float, radius: float, dock_material: Material) -> void:
	var roll: float = -PI * 0.5
	var radial: Vector3 = Vector3(cos(roll), sin(roll), 0.0)
	var length: float = 3.4
	var base: float = radius + 0.3
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 1.3
	mesh.bottom_radius = 1.3
	mesh.height = length
	mesh.radial_segments = 24
	var pod: MeshInstance3D = _add_mesh(parent, "Pod", mesh, Vector3(radial.x * (base + length * 0.5), radial.y * (base + length * 0.5), z), dock_material)
	pod.basis = Basis(Quaternion(Vector3.UP, radial))
	var neck: CylinderMesh = CylinderMesh.new()
	neck.top_radius = 0.7
	neck.bottom_radius = 0.7
	neck.height = base
	neck.radial_segments = 16
	var tunnel: MeshInstance3D = _add_mesh(parent, "Port", neck, Vector3(radial.x * base * 0.5, radial.y * base * 0.5, z), dock_material)
	tunnel.basis = Basis(Quaternion(Vector3.UP, radial))
	var offset: float = base + length * 0.5
	_add_label(parent, label, Vector3(radial.x * offset, radial.y * (offset + 2.2), z), 1.0, 44)


func _add_array(parent: Node3D, z: float, roll: float, base: float, span: float, chord: float, boom_material: Material) -> void:
	var radial: Vector3 = Vector3(cos(roll), sin(roll), 0.0)
	var axial: Vector3 = Vector3(0.0, 0.0, 1.0)
	var boom_length: float = 2.4
	var boom: CylinderMesh = CylinderMesh.new()
	boom.top_radius = 0.11
	boom.bottom_radius = 0.11
	boom.height = boom_length
	boom.radial_segments = 12
	var boom_node: MeshInstance3D = _add_mesh(parent, "Boom", boom, Vector3(0.0, 0.0, z), boom_material)
	boom_node.basis = Basis(Quaternion(Vector3.UP, radial))
	var boom_start: float = base * 0.55
	boom_node.position = Vector3(radial.x * (boom_start + boom_length * 0.5), radial.y * (boom_start + boom_length * 0.5), z)
	var panel: BoxMesh = BoxMesh.new()
	panel.size = Vector3(span, chord, 0.08)
	var panel_material: StandardMaterial3D = StandardMaterial3D.new()
	panel_material.albedo_color = Color(0.05, 0.07, 0.18)
	panel_material.metallic = 0.25
	panel_material.roughness = 0.35
	var panel_node: MeshInstance3D = _add_mesh(parent, "Array", panel, Vector3(0.0, 0.0, z), panel_material)
	var offset: float = boom_start + boom_length + span * 0.5
	panel_node.transform = Transform3D(Basis(radial, axial, radial.cross(axial)), Vector3(radial.x * offset, radial.y * offset, z))


func _add_label(parent: Node3D, text: String, position: Vector3, radius: float, size: int = 64) -> void:
	var label: Label3D = Label3D.new()
	label.name = "Label"
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = size
	label.outline_size = 8
	label.modulate = Color(1.0, 0.92, 0.7)
	label.position = position + Vector3(0.0, radius + 1.2, 0.0)
	parent.add_child(label)


func _add_mesh(parent: Node3D, name: String, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance


## Packed scenes only keep nodes owned by the root; assign it recursively.
func _set_owner(node: Node, root_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root_node
		_set_owner(child, root_node)
