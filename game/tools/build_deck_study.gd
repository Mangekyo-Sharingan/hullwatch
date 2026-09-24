## Design study (design tool, not part of the game): the M13.4 ring-deck question. Three
## grey-block versions of the engine bay section (radius 2.8) side by side, cut open on the
## starboard side so the levels read:
##   A - as built: one 2.5 m level, no deck.
##   B - crawl loft: a deck at 1.9 m over the aft half; 1.9 m below, 0.6 m above (storage).
##   C - double height: the same radius with a taller profile (ceiling 4.4 m) and a mezzanine
##       at 2.2 m; 2.2 m clear both sides.
## Built by `build_deck_study.gd`, shot by `capture_deck_study.gd`; the numbers mirror
## `SectionHull.tube_section` and the Q8 options in `docs/OPEN_QUESTIONS.md`.
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/build_deck_study.gd
extends SceneTree

const OUTPUT_PATH: String = "res://scenes/deck_study.tscn"
const MATERIAL_WALL: String = "res://src/data/materials/mat_xenon_metal.tres"
const MATERIAL_DECK: String = "res://src/data/materials/mat_deck_plate.tres"
const MATERIAL_MEZZ: String = "res://src/data/materials/mat_panel_scratched.tres"
const MATERIAL_LADDER: String = "res://src/data/materials/mat_dark_plastic.tres"
const SECTION_LENGTH: float = 2.8
const DECK_HALF: float = 0.46
const WALL_HALF: float = 0.88
const CEIL_HALF: float = 0.60
const DECK_THICKNESS: float = 0.12
const RAIL: float = 1.0

var _root: Node3D
var _materials: Dictionary = {}
var _failures: int = 0


func _initialize() -> void:
	_load_materials()
	if _failures == 0:
		_build()
	_save()


func _load_materials() -> void:
	for path: String in [MATERIAL_WALL, MATERIAL_DECK, MATERIAL_MEZZ, MATERIAL_LADDER]:
		var material: Material = load(path) as Material
		if material == null:
			print("FAIL: missing material ", path)
			_failures += 1
		else:
			_materials[path] = material


func _build() -> void:
	_root = Node3D.new()
	_root.name = "DeckStudy"
	var spacing: float = 3.6
	for index: int in 3:
		var variant: Node3D = Node3D.new()
		variant.name = "Variant%d" % index
		variant.position = Vector3(spacing * (float(index) - 1.0), 0.0, 0.0)
		_root.add_child(variant)
		match index:
			0:
				_build_section(variant, 2.5, 1.9, 0.0)
				_label(variant, "A - as built\n2.5 m, no deck", Vector3(0.0, 3.1, SECTION_LENGTH * 0.5 + 0.6))
			1:
				_build_section(variant, 2.5, 1.9, 1.9)
				_label(variant, "B - crawl loft\n1.9 m below, 0.6 m above", Vector3(0.0, 3.1, SECTION_LENGTH * 0.5 + 0.6))
			2:
				_build_section(variant, 4.4, 3.4, 2.2)
				_label(variant, "C - double height\n2.2 m both levels", Vector3(0.0, 5.4, SECTION_LENGTH * 0.5 + 0.6))
	_save_scene()


## One cutaway section: floor, port wall bands, ceiling, and the variant's deck.
func _build_section(parent: Node3D, ceiling: float, wall_top: float, deck_y: float) -> void:
	var radius: float = 2.8
	var deck_half: float = radius * DECK_HALF
	var wall_half: float = radius * WALL_HALF
	var ceil_half: float = radius * CEIL_HALF
	var z0: float = -SECTION_LENGTH * 0.5
	var z1: float = SECTION_LENGTH * 0.5
	_slab(parent, Vector3(deck_half * 2.0, DECK_THICKNESS, SECTION_LENGTH), Vector3(0.0, -DECK_THICKNESS * 0.5, 0.0), MATERIAL_DECK)
	# Port wall: the deck-to-wall band, the wall band, and the cove to the ceiling.
	_band(parent, Vector2(-deck_half, 0.0), Vector2(-wall_half, wall_top), z0, z1, MATERIAL_WALL)
	_band(parent, Vector2(-wall_half, wall_top), Vector2(-ceil_half, ceiling), z0, z1, MATERIAL_WALL)
	_slab(parent, Vector3(ceil_half * 2.0, DECK_THICKNESS, SECTION_LENGTH), Vector3(0.0, ceiling, 0.0), MATERIAL_WALL)
	if deck_y > 0.0:
		# The mezzanine covers the aft half; its forward edge carries a rail and a ladder.
		var half_length: float = SECTION_LENGTH * 0.25
		_slab(parent, Vector3(deck_half * 2.0, DECK_THICKNESS, SECTION_LENGTH * 0.5), Vector3(0.0, deck_y, half_length), MATERIAL_MEZZ)
		_slab(parent, Vector3(0.06, 0.9, 0.06), Vector3(deck_half - 0.05, deck_y + 0.45, 0.0), MATERIAL_LADDER)
		_slab(parent, Vector3(0.06, 0.9, 0.06), Vector3(-deck_half + 0.05, deck_y + 0.45, 0.0), MATERIAL_LADDER)
		for rung: int in 4:
			_slab(parent, Vector3(deck_half * 2.0 - 0.1, 0.05, 0.06), Vector3(0.0, 0.2 + float(rung) * (deck_y - 0.2) / 3.0, 0.0), MATERIAL_LADDER)
		_slab(parent, Vector3(deck_half * 2.0, 0.06, 0.06), Vector3(0.0, deck_y + 0.95, 0.02), MATERIAL_MEZZ)


## A wall band swept between two profile points, as a thin slab (the study reads from outside).
func _band(parent: Node3D, from: Vector2, to: Vector2, z0: float, z1: float, material: String) -> void:
	var run: Vector2 = to - from
	var length: float = run.length()
	if length <= 0.001:
		return
	var angle: float = atan2(run.y, run.x)
	var center: Vector2 = (from + to) * 0.5
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(length, 0.08, z1 - z0)
	node.mesh = mesh
	node.material_override = _materials[material] as Material
	node.position = Vector3(center.x, center.y, (z0 + z1) * 0.5)
	node.rotation_degrees.z = rad_to_deg(angle)
	parent.add_child(node)


func _slab(parent: Node3D, size: Vector3, position: Vector3, material: String) -> void:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _materials[material] as Material
	node.position = position
	parent.add_child(node)


func _label(parent: Node3D, text: String, position: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.004
	label.modulate = Color(0.85, 0.88, 0.92, 1.0)
	label.position = position
	parent.add_child(label)


func _save_scene() -> void:
	_assign_owners(_root, _root)
	var packed: PackedScene = PackedScene.new()
	var error: Error = packed.pack(_root)
	if error != OK:
		print("FAIL: pack error ", error)
		_failures += 1
		return
	var save_error: Error = ResourceSaver.save(packed, OUTPUT_PATH)
	if save_error != OK:
		print("FAIL: save error ", save_error)
		_failures += 1


## Pack only serializes nodes owned by the scene root.
func _assign_owners(node: Node, root_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root_node
		_assign_owners(child, root_node)


func _save() -> void:
	if _failures == 0:
		print("PASS: build_deck_study")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)
