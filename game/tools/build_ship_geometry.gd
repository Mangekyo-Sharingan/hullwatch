## Generates the faceted polygonal ship: plan outlines (chamfered rectangles) extruded
## through profile rings into mitered wall bands, floor/ceiling caps and doorway cutouts.
## Geometry is built in memory and packed, so it is reproducible from the tables below.
## Re-run after changing the layout:
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/build_ship_geometry.gd
extends SceneTree

const OUTPUT_PATH: String = "res://scenes/ship_geometry.tscn"
const OUTPUT_POD_PATH: String = "res://scenes/dock_pod.tscn"

const MATERIAL_FLOOR: String = "res://src/data/materials/mat_floor_grate.tres"
const MATERIAL_XENON: String = "res://src/data/materials/mat_xenon_metal.tres"
const MATERIAL_STRIP: String = "res://src/data/materials/mat_light_strip.tres"
const MATERIAL_CONDUIT: String = "res://src/data/materials/mat_metal_rusted.tres"
const MATERIAL_WINDOW: String = "res://src/data/materials/mat_space_window.tres"
const SCRIPT_TETHER_ANCHOR: String = "res://src/world/tether_anchor.gd"
const SCRIPT_TETHER_ZONE: String = "res://src/world/tether_zone.gd"
const SCRIPT_ZONE: String = "res://src/world/compartment_zone.gd"
const SCRIPT_LINK: String = "res://src/world/compartment_link.gd"

const WALL_THICKNESS: float = 0.2
const DOOR_TOP: float = 2.2
const FLOOR_BOTTOM: float = -0.2
const CEILING_BOTTOM: float = 3.0
const CEILING_TOP: float = 3.2
const EPSILON: float = 0.000001

## Vertical profiles as (height, inset) rings: flat floor, lower cant, vertical band,
## upper cove, flat ceiling. The inset is measured from each space's plan outline via a
## mitered offset, so every corner stays a true mitre joint. Rooms get big slanted coves;
## the spine corridor is a regular hexagon: 60-degree cants, 3.5 m waist at 1.5 m,
## floor and ceiling 1.75 m wide, no vertical band anywhere.
const PROFILE_CORRIDOR: Array[Vector2] = [
	Vector2(FLOOR_BOTTOM, 0.875),
	Vector2(0.0, 0.875),
	Vector2(1.50, 0.0),
	Vector2(CEILING_BOTTOM, 0.875),
	Vector2(CEILING_TOP, 0.875),
]
const PROFILE_ROOM_L: Array[Vector2] = [
	Vector2(FLOOR_BOTTOM, 0.0),
	Vector2(0.0, 0.0),
	Vector2(0.50, 0.20),
	Vector2(2.15, 0.20),
	Vector2(CEILING_BOTTOM, 0.85),
	Vector2(CEILING_TOP, 0.0),
]
const PROFILE_ROOM_M: Array[Vector2] = [
	Vector2(FLOOR_BOTTOM, 0.0),
	Vector2(0.0, 0.0),
	Vector2(0.50, 0.20),
	Vector2(2.15, 0.20),
	Vector2(CEILING_BOTTOM, 0.65),
	Vector2(CEILING_TOP, 0.0),
]
const PROFILE_ROOM_S: Array[Vector2] = [
	Vector2(FLOOR_BOTTOM, 0.0),
	Vector2(0.0, 0.0),
	Vector2(0.35, 0.12),
	Vector2(2.10, 0.12),
	Vector2(CEILING_BOTTOM, 0.40),
	Vector2(CEILING_TOP, 0.0),
]
const PROFILE_COCKPIT: Array[Vector2] = [
	Vector2(FLOOR_BOTTOM, 0.0),
	Vector2(0.0, 0.0),
	Vector2(0.50, 0.20),
	Vector2(2.45, 0.20),
	Vector2(CEILING_BOTTOM, 0.60),
	Vector2(CEILING_TOP, 0.0),
]
## Dock throats: straight walls up to the door head, then a small cove. The wall inset is
## zero so the throat bore matches the hull aperture exactly (no ledge at the threshold).
const PROFILE_THROAT: Array[Vector2] = [
	Vector2(FLOOR_BOTTOM, 0.0),
	Vector2(0.0, 0.0),
	Vector2(DOOR_TOP, 0.0),
	Vector2(CEILING_BOTTOM, 0.34),
	Vector2(CEILING_TOP, 0.0),
]

const SPACE_NAMES: Array[String] = [
	"Cockpit",
	"Corridor",
	"Quarters",
	"LifeSupport",
	"Galley",
	"WaterCloset",
	"Storage",
	"EngineBay",
	"Airlock",
]

## Spaces: interior plan bounds, corner chamfer, wall profile, wall edges, open edges and
## doorway gaps. Gaps name the varying world axis coordinate; `top` defaults to the door
## head height, `bottom` raises the opening into a window band, and `top` uses CEILING_TOP
## for a full-height junction opening.
const SPACES: Array[Dictionary] = [
	{
		"name": "Cockpit",
		"min": Vector2(-3.4, -18.8),
		"max": Vector2(3.4, -14.2),
		"chamfer": 1.2,
		"profile": "cockpit",
		"walls": [0, 1, 2, 3, 4, 5, 6, 7],
		"open": [],
		"gaps": [
			{"edge": 4, "from": -0.88, "to": 0.88, "top": CEILING_TOP},
			{"edge": 0, "from": -2.0, "to": 2.0, "bottom": 1.2, "top": 2.3},
		],
	},
	{
		"name": "Corridor",
		"min": Vector2(-1.75, -14.0),
		"max": Vector2(1.75, 1.4),
		"chamfer": 0.0,
		"profile": "corridor",
		"walls": [1, 3],
		"open": [0, 2],
		"gaps": [
			{"edge": 1, "from": -6.2, "to": -5.0},
			{"edge": 1, "from": -2.2, "to": -1.0},
			{"edge": 3, "from": -10.6, "to": -9.4},
			{"edge": 3, "from": -6.6, "to": -5.4},
			{"edge": 3, "from": -1.8, "to": -0.6},
		],
	},
	{
		"name": "Quarters",
		"min": Vector2(-6.45, -12.6),
		"max": Vector2(-1.95, -8.2),
		"chamfer": 1.4,
		"profile": "room_m",
		"walls": [0, 1, 3, 4, 5, 6, 7],
		"open": [2],
		"gaps": [{"edge": 6, "from": -10.9, "to": -9.9}],
	},
	{
		"name": "LifeSupport",
		"min": Vector2(-5.45, -7.6),
		"max": Vector2(-1.95, -5.0),
		"chamfer": 0.5,
		"profile": "room_m",
		"walls": [0, 1, 3, 4, 5, 6, 7],
		"open": [2],
		"gaps": [{"edge": 6, "from": -6.8, "to": -5.8}],
	},
	{
		"name": "Galley",
		"min": Vector2(1.95, -7.6),
		"max": Vector2(5.95, -4.0),
		"chamfer": 1.0,
		"profile": "room_l",
		"walls": [0, 1, 2, 3, 4, 5, 7],
		"open": [6],
		"gaps": [{"edge": 2, "from": -6.3, "to": -5.3}],
	},
	{
		"name": "WaterCloset",
		"min": Vector2(1.95, -3.0),
		"max": Vector2(4.55, -0.8),
		"chamfer": 0.45,
		"profile": "room_s",
		"walls": [0, 1, 2, 3, 4, 5, 7],
		"open": [6],
		"gaps": [],
	},
	{
		"name": "Storage",
		"min": Vector2(-5.65, -3.0),
		"max": Vector2(-1.95, 0.6),
		"chamfer": 1.0,
		"profile": "room_m",
		"walls": [0, 1, 3, 4, 5, 6, 7],
		"open": [2],
		"gaps": [{"edge": 6, "from": -1.6, "to": -0.4}],
	},
	{
		"name": "EngineBay",
		"min": Vector2(-3.6, 1.6),
		"max": Vector2(3.6, 7.8),
		"chamfer": 1.8,
		"profile": "room_l",
		"walls": [0, 1, 2, 3, 4, 5, 6, 7],
		"open": [],
		"gaps": [
			{"edge": 0, "from": -0.88, "to": 0.88, "top": CEILING_TOP},
			{"edge": 2, "from": 4.2, "to": 5.2},
		],
	},
	{
		"name": "Airlock",
		"min": Vector2(-7.85, -2.2),
		"max": Vector2(-5.85, -0.2),
		"chamfer": 0.4,
		"profile": "room_s",
		"walls": [0, 1, 3, 4, 5, 6, 7],
		"open": [2],
		"gaps": [{"edge": 6, "from": -1.7, "to": -0.7}],
	},
]

const HULL_PLAN_MIN: Vector2 = Vector2(-8.05, -19.0)
const HULL_PLAN_MAX: Vector2 = Vector2(6.15, 8.0)
const HULL_CHAMFER: float = 1.8
const HULL_BAND: float = 0.45
const HULL_BOTTOM: float = -0.4
const DECK_BOTTOM: float = 3.2
const DECK_TOP: float = 3.6
const CATWALK_MARGIN: float = 1.45
const CATWALK_TOP: float = 0.0
const CATWALK_BOTTOM: float = -0.15
const AIRLOCK_GAP_FROM: float = -1.7
const AIRLOCK_GAP_TO: float = -0.7

## M10 dock mounts: a doorway in a parent room's outer wall, a throat across the void to the
## hull band, and a 1 m aperture in the hull band sealed by a flush mount plate until a pod
## is built. `room_face` is that room wall's outer face; the hull face comes from the plan.
## Pinned ids per EXPANSION_SPEC §M10. `outward` is the hull side (-1 west, +1 east).
const DOCKS: Array[Dictionary] = [
	{"id": "quarters", "room": "Quarters", "hull_edge": 6, "z": -10.4, "room_face": -6.65, "outward": -1.0},
	{"id": "life_support", "room": "LifeSupport", "hull_edge": 6, "z": -6.3, "room_face": -5.65, "outward": -1.0},
	{"id": "galley", "room": "Galley", "hull_edge": 2, "z": -5.8, "room_face": 6.15, "outward": 1.0},
	{"id": "engine_bay", "room": "EngineBay", "hull_edge": 2, "z": 4.7, "room_face": 3.8, "outward": 1.0},
]
const DOCK_DOOR_HALF: float = 0.5
const DOCK_PLATE_THICKNESS: float = 0.15
## The generated pod scene's mating convention: origin on the hull's outer face at the
## doorway centre, floor at y=0, doorway through the local -X wall (0.2 m flange), the pod
## extending toward +X. Place west docks yawed 180 degrees, east docks unrotated (M10.3).
const POD_DOOR_HALF: float = 0.5
const POD_MIN: Vector2 = Vector2(0.2, -1.6)
const POD_MAX: Vector2 = Vector2(4.4, 1.6)
const POD_CHAMFER: float = 0.8

var _root: Node3D
var _materials: Dictionary = {}
var _failures: int = 0


func _initialize() -> void:
	_load_materials()
	if _failures == 0:
		_build()
	_save()


func _load_materials() -> void:
	for path: String in [MATERIAL_FLOOR, MATERIAL_XENON, MATERIAL_STRIP, MATERIAL_CONDUIT, MATERIAL_WINDOW]:
		var material: Material = load(path) as Material
		if material == null:
			_failures += 1
			print("FAIL: missing material ", path)
		else:
			_materials[path] = material


func _build() -> void:
	_root = Node3D.new()
	_root.name = "ShipGeometry"
	for spec: Dictionary in SPACES:
		_build_space(spec)
	_build_cockpit_dash()
	_build_hull_exterior()
	_build_dock_throats()
	_build_dressing()


## The generated dock pod: a placeable module room in the same faceted language, origin at
## its mating doorway on the hull's outer face (see POD_* constants). Spawned by M10.3.
func _build_dock_pod() -> Node3D:
	var pod: Node3D = Node3D.new()
	pod.name = "DockPod"
	_build_prism_space(pod, "PodRoom", {
		"name": "PodRoom",
		"min": POD_MIN,
		"max": POD_MAX,
		"chamfer": POD_CHAMFER,
		"profile": "room_l",
		"walls": [0, 1, 2, 3, 4, 5, 6, 7],
		"open": [],
		"gaps": [{"edge": 6, "from": -POD_DOOR_HALF, "to": POD_DOOR_HALF}],
	})
	var zone: Area3D = Area3D.new()
	zone.name = "Zone"
	zone.position = Vector3((POD_MIN.x + POD_MAX.x) * 0.5, 1.5, 0.0)
	zone.set_script(load(SCRIPT_ZONE) as Script)
	zone.set(&"compartment_id", &"module")
	pod.add_child(zone)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(POD_MAX.x - POD_MIN.x - 0.6, 3.0, POD_MAX.y - POD_MIN.y - 0.6)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = box
	zone.add_child(shape)
	var link: Node = Node.new()
	link.name = "Link"
	link.set_script(load(SCRIPT_LINK) as Script)
	link.set(&"compartment_a", &"module")
	link.set(&"compartment_b", &"")
	pod.add_child(link)
	return pod


func _profile_for(profile_name: StringName) -> Array[Vector2]:
	match profile_name:
		&"corridor":
			return PROFILE_CORRIDOR
		&"room_l":
			return PROFILE_ROOM_L
		&"room_m":
			return PROFILE_ROOM_M
		&"room_s":
			return PROFILE_ROOM_S
		&"cockpit":
			return PROFILE_COCKPIT
		&"throat":
			return PROFILE_THROAT
	_failures += 1
	print("FAIL: unknown profile ", profile_name)
	return PROFILE_ROOM_M


func _build_space(spec: Dictionary) -> void:
	_build_prism_space(_root, String(spec["name"]), spec)


## One prismatic space: a plan polygon swept through profile rings, with wall bands (and
## their jambs/lintels/sills), thresholds under every opening, and floor/ceiling caps.
## `naked_edges` open edges get no threshold (used by dock throats, which meet the hull
## band's own aperture floor exactly).
func _build_prism_space(parent: Node3D, space_name: String, spec: Dictionary) -> void:
	var space: StaticBody3D = StaticBody3D.new()
	space.name = space_name
	parent.add_child(space)
	var outline: PackedVector2Array = HullProfile.rectangle_outline(spec["min"], spec["max"], spec["chamfer"])
	if outline.is_empty():
		_failures += 1
		print("FAIL: empty outline for ", space_name)
		return
	var profile: Array[Vector2] = _profile_for(StringName(spec["profile"]))
	var rings: Array[PackedVector2Array] = HullProfile.profile_rings(outline, profile)
	var outer: PackedVector2Array = HullProfile.offset_polygon(outline, WALL_THICKNESS)
	var walls: Dictionary = _surface()
	var floors: Dictionary = _surface()
	var ceilings: Dictionary = _surface()
	var collision: Array[Vector3] = []
	var open_edges: Array = spec["open"]
	var naked_edges: Array = spec.get("naked_edges", [])
	for edge_index: int in spec["walls"]:
		_add_wall_edge(walls, outline, outer, profile, rings, edge_index, _gaps_for(spec, edge_index), collision)
	for edge_index: int in open_edges:
		if naked_edges.has(edge_index):
			continue
		_add_threshold(floors, outline, outer, profile, rings, edge_index, 0.0, 1.0, collision)
	for gap: Dictionary in spec["gaps"]:
		if float(gap.get("bottom", FLOOR_BOTTOM)) > FLOOR_BOTTOM + EPSILON:
			continue
		var span: Vector2 = _gap_span(outline, int(gap["edge"]), float(gap["from"]), float(gap["to"]))
		_add_threshold(floors, outline, outer, profile, rings, int(gap["edge"]), span.x, span.y, collision)
	for edge_index: int in spec["walls"]:
		var previous: int = (edge_index - 1 + outline.size()) % outline.size()
		var following: int = (edge_index + 1) % outline.size()
		if open_edges.has(previous):
			_add_end_cap(walls, outer, profile, rings, edge_index, 1.0, collision)
		if open_edges.has(following):
			_add_end_cap(walls, outer, profile, rings, edge_index, 0.0, collision)
	_add_cap(floors, outline, FLOOR_BOTTOM, 0.0, collision)
	_add_cap(ceilings, outline, CEILING_BOTTOM, CEILING_TOP, collision)

	space.add_child(_make_surface_node("Walls", walls, MATERIAL_XENON, collision))
	space.add_child(_make_surface_node("Floor", floors, MATERIAL_FLOOR, collision))
	space.add_child(_make_surface_node("Ceiling", ceilings, MATERIAL_XENON, collision))
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array(collision))
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "ShellShape"
	shape_node.shape = shape
	space.add_child(shape_node)


## One wall edge: the inner surface swept between mitered profile rings (split around
## doorway/window gaps), a straight outer face, top and bottom rims, and jamb, lintel
## and sill faces at every opening.
func _add_wall_edge(surface: Dictionary, outline: PackedVector2Array, outer: PackedVector2Array, profile: Array[Vector2], rings: Array[PackedVector2Array], edge_index: int, gaps: Array, collision: Array[Vector3]) -> void:
	var count: int = outline.size()
	var a: Vector2 = outline[edge_index]
	var b: Vector2 = outline[(edge_index + 1) % count]
	var oa: Vector2 = outer[edge_index]
	var ob: Vector2 = outer[(edge_index + 1) % count]
	var outward: Vector2 = _outward(a, b)
	var outward_3d: Vector3 = Vector3(outward.x, 0.0, outward.y)
	var inward_3d: Vector3 = -outward_3d
	var direction_3d: Vector3 = Vector3(b.x - a.x, 0.0, b.y - a.y).normalized()
	var spans: Array = _spans_without_gaps(outline, edge_index, gaps)
	for band: int in profile.size() - 1:
		var y0: float = profile[band].x
		var y1: float = profile[band + 1].x
		for slice: Array in _band_slices(y0, y1, gaps):
			var sy0: float = slice[0]
			var sy1: float = slice[1]
			var ring_low: PackedVector2Array = _ring_at(rings, profile, sy0)
			var ring_high: PackedVector2Array = _ring_at(rings, profile, sy1)
			var active_spans: Array = spans if bool(slice[2]) else [Vector2(0.0, 1.0)]
			for span: Vector2 in active_spans:
				_add_quad(
					surface,
					_ring_point(ring_low, edge_index, span.x, sy0),
					_ring_point(ring_low, edge_index, span.y, sy0),
					_ring_point(ring_high, edge_index, span.y, sy1),
					_ring_point(ring_high, edge_index, span.x, sy1),
					inward_3d, collision
				)
	for span: Vector2 in spans:
		var out_a: Vector2 = oa.lerp(ob, span.x)
		var out_b: Vector2 = oa.lerp(ob, span.y)
		_add_quad(
			surface,
			Vector3(out_a.x, FLOOR_BOTTOM, out_a.y),
			Vector3(out_b.x, FLOOR_BOTTOM, out_b.y),
			Vector3(out_b.x, CEILING_TOP, out_b.y),
			Vector3(out_a.x, CEILING_TOP, out_a.y),
			outward_3d, collision
		)
	var i0: Vector3 = Vector3(a.x, FLOOR_BOTTOM, a.y)
	var i1: Vector3 = Vector3(b.x, FLOOR_BOTTOM, b.y)
	var i2: Vector3 = Vector3(b.x, CEILING_TOP, b.y)
	var i3: Vector3 = Vector3(a.x, CEILING_TOP, a.y)
	_add_quad(surface, i0, i1, Vector3(ob.x, FLOOR_BOTTOM, ob.y), Vector3(oa.x, FLOOR_BOTTOM, oa.y), Vector3.DOWN, collision)
	_add_quad(surface, i3, Vector3(oa.x, CEILING_TOP, oa.y), Vector3(ob.x, CEILING_TOP, ob.y), i2, Vector3.UP, collision)
	for gap: Dictionary in gaps:
		var span: Vector2 = _gap_span(outline, edge_index, float(gap["from"]), float(gap["to"]))
		var top: float = float(gap.get("top", DOOR_TOP))
		var bottom: float = float(gap.get("bottom", FLOOR_BOTTOM))
		_add_jamb(surface, outer, profile, rings, edge_index, span.x, bottom, top, direction_3d, collision)
		_add_jamb(surface, outer, profile, rings, edge_index, span.y, bottom, top, -direction_3d, collision)
		if bottom > FLOOR_BOTTOM + EPSILON:
			var ring_bottom: PackedVector2Array = _ring_at(rings, profile, bottom)
			_add_quad(
				surface,
				_ring_point(ring_bottom, edge_index, span.x, bottom), _ring_point(ring_bottom, edge_index, span.y, bottom),
				Vector3(oa.lerp(ob, span.y).x, bottom, oa.lerp(ob, span.y).y),
				Vector3(oa.lerp(ob, span.x).x, bottom, oa.lerp(ob, span.x).y),
				Vector3.UP, collision
			)
		if top < CEILING_TOP - EPSILON:
			var ring_top: PackedVector2Array = _ring_at(rings, profile, top)
			_add_quad(
				surface,
				_ring_point(ring_top, edge_index, span.x, top), _ring_point(ring_top, edge_index, span.y, top),
				Vector3(oa.lerp(ob, span.y).x, top, oa.lerp(ob, span.y).y),
				Vector3(oa.lerp(ob, span.x).x, top, oa.lerp(ob, span.x).y),
				Vector3.DOWN, collision
			)


func _add_cap(surface: Dictionary, outline: PackedVector2Array, y_low: float, y_high: float, collision: Array[Vector3]) -> void:
	for i: int in range(1, outline.size() - 1):
		var a: Vector2 = outline[0]
		var b: Vector2 = outline[i]
		var c: Vector2 = outline[i + 1]
		_add_tri(surface, Vector3(a.x, y_high, a.y), Vector3(b.x, y_high, b.y), Vector3(c.x, y_high, c.y), Vector3.UP, collision)
		_add_tri(surface, Vector3(a.x, y_low, a.y), Vector3(b.x, y_low, b.y), Vector3(c.x, y_low, c.y), Vector3.DOWN, collision)


func _add_threshold(surface: Dictionary, outline: PackedVector2Array, outer: PackedVector2Array, profile: Array[Vector2], rings: Array[PackedVector2Array], edge_index: int, t0: float, t1: float, collision: Array[Vector3]) -> void:
	var count: int = outline.size()
	var a: Vector2 = outline[edge_index]
	var b: Vector2 = outline[(edge_index + 1) % count]
	var oa: Vector2 = outer[edge_index]
	var ob: Vector2 = outer[(edge_index + 1) % count]
	var ring_floor: PackedVector2Array = _ring_at(rings, profile, 0.0)
	var inner0: Vector3 = _ring_point(ring_floor, edge_index, t0, 0.0)
	var inner1: Vector3 = _ring_point(ring_floor, edge_index, t1, 0.0)
	var outer0: Vector2 = oa.lerp(ob, t0)
	var outer1: Vector2 = oa.lerp(ob, t1)
	_add_quad(
		surface,
		inner0, inner1,
		Vector3(outer1.x, 0.0, outer1.y), Vector3(outer0.x, 0.0, outer0.y),
		Vector3.UP, collision
	)
	_add_quad(
		surface,
		Vector3(inner0.x, FLOOR_BOTTOM, inner0.z), Vector3(inner1.x, FLOOR_BOTTOM, inner1.z),
		Vector3(outer1.x, FLOOR_BOTTOM, outer1.y), Vector3(outer0.x, FLOOR_BOTTOM, outer0.y),
		Vector3.DOWN, collision
	)


## Vertical face from the inner profile line at parameter t to the outer wall line,
## spanning y0..y1 and segmented at profile ring heights. Used for jambs at opening
## boundaries and caps at open-edge ends.
func _add_jamb(surface: Dictionary, outer: PackedVector2Array, profile: Array[Vector2], rings: Array[PackedVector2Array], edge_index: int, t: float, y0: float, y1: float, normal_hint: Vector3, collision: Array[Vector3]) -> void:
	var oa: Vector2 = outer[edge_index]
	var ob: Vector2 = outer[(edge_index + 1) % outer.size()]
	var outer_point: Vector2 = oa.lerp(ob, t)
	var heights: Array[float] = [y0]
	for ring: Vector2 in profile:
		if ring.x > y0 + EPSILON and ring.x < y1 - EPSILON:
			heights.append(ring.x)
	heights.append(y1)
	for i: int in heights.size() - 1:
		var low: float = heights[i]
		var high: float = heights[i + 1]
		if high - low <= EPSILON:
			continue
		var ring_low: PackedVector2Array = _ring_at(rings, profile, low)
		var ring_high: PackedVector2Array = _ring_at(rings, profile, high)
		var inner_low: Vector3 = _ring_point(ring_low, edge_index, t, low)
		var inner_high: Vector3 = _ring_point(ring_high, edge_index, t, high)
		var outer_low: Vector3 = Vector3(outer_point.x, low, outer_point.y)
		var outer_high: Vector3 = Vector3(outer_point.x, high, outer_point.y)
		_add_quad(surface, inner_low, inner_high, outer_high, outer_low, normal_hint, collision)


func _add_end_cap(surface: Dictionary, outer: PackedVector2Array, profile: Array[Vector2], rings: Array[PackedVector2Array], edge_index: int, t: float, collision: Array[Vector3]) -> void:
	var count: int = outer.size()
	var a: Vector2 = outer[edge_index]
	var b: Vector2 = outer[(edge_index + 1) % count]
	var direction_3d: Vector3 = Vector3(b.x - a.x, 0.0, b.y - a.y).normalized()
	var hint: Vector3 = -direction_3d if t <= 0.0 else direction_3d
	_add_jamb(surface, outer, profile, rings, edge_index, t, FLOOR_BOTTOM, CEILING_TOP, hint, collision)


## Vertical jamb face without profile rings, for the exterior hull band openings.
func _add_flat_jamb(surface: Dictionary, inner: PackedVector2Array, outer: PackedVector2Array, edge_index: int, t: float, y0: float, y1: float, normal_hint: Vector3, collision: Array[Vector3]) -> void:
	var oa: Vector2 = outer[edge_index]
	var ob: Vector2 = outer[(edge_index + 1) % outer.size()]
	var ia: Vector2 = inner[edge_index]
	var ib: Vector2 = inner[(edge_index + 1) % inner.size()]
	var outer_point: Vector2 = oa.lerp(ob, t)
	var inner_point: Vector2 = ia.lerp(ib, t)
	_add_quad(
		surface,
		Vector3(inner_point.x, y0, inner_point.y),
		Vector3(inner_point.x, y1, inner_point.y),
		Vector3(outer_point.x, y1, outer_point.y),
		Vector3(outer_point.x, y0, outer_point.y),
		normal_hint, collision
	)


## The mitered inner polygon at height y, interpolated between the two profile rings
## that bracket it. Ring polygons share their vertex count, so the lerp is exact.
func _ring_at(rings: Array[PackedVector2Array], profile: Array[Vector2], y: float) -> PackedVector2Array:
	if y <= profile[0].x:
		return rings[0]
	var last: int = profile.size() - 1
	if y >= profile[last].x:
		return rings[last]
	for i: int in last:
		var low: Vector2 = profile[i]
		var high: Vector2 = profile[i + 1]
		if y <= high.x:
			var span: float = high.x - low.x
			var t: float = 0.0 if span <= EPSILON else (y - low.x) / span
			var result: PackedVector2Array = PackedVector2Array()
			for j: int in rings[i].size():
				result.append(rings[i][j].lerp(rings[i + 1][j], t))
			return result
	return rings[last]


func _ring_point(ring: PackedVector2Array, edge_index: int, t: float, y: float) -> Vector3:
	var a: Vector2 = ring[edge_index]
	var b: Vector2 = ring[(edge_index + 1) % ring.size()]
	var point: Vector2 = a.lerp(b, t)
	return Vector3(point.x, y, point.y)


## Sub-bands of a profile band clipped by opening sills and heads: [y0, y1, gap_active].
func _band_slices(y0: float, y1: float, gaps: Array) -> Array:
	if gaps.is_empty():
		return [[y0, y1, false]]
	var cuts: Array[float] = [y0, y1]
	for gap: Dictionary in gaps:
		var bottom: float = float(gap.get("bottom", FLOOR_BOTTOM))
		var top: float = float(gap.get("top", DOOR_TOP))
		if bottom > y0 + EPSILON and bottom < y1 - EPSILON:
			cuts.append(bottom)
		if top > y0 + EPSILON and top < y1 - EPSILON:
			cuts.append(top)
	cuts.sort()
	var slices: Array = []
	for i: int in cuts.size() - 1:
		var low: float = cuts[i]
		var high: float = cuts[i + 1]
		if high - low <= EPSILON:
			continue
		var mid: float = (low + high) * 0.5
		var active: bool = false
		for gap: Dictionary in gaps:
			var bottom: float = float(gap.get("bottom", FLOOR_BOTTOM))
			var top: float = float(gap.get("top", DOOR_TOP))
			if mid > bottom + EPSILON and mid < top - EPSILON:
				active = true
				break
		slices.append([low, high, active])
	return slices


func _spans_without_gaps(outline: PackedVector2Array, edge_index: int, gaps: Array) -> Array:
	var spans: Array = [Vector2(0.0, 1.0)]
	for gap: Dictionary in gaps:
		var span: Vector2 = _gap_span(outline, edge_index, float(gap["from"]), float(gap["to"]))
		var result: Array = []
		for existing: Vector2 in spans:
			if span.y <= existing.x + EPSILON or span.x >= existing.y - EPSILON:
				result.append(existing)
				continue
			if span.x > existing.x + EPSILON:
				result.append(Vector2(existing.x, span.x))
			if span.y < existing.y - EPSILON:
				result.append(Vector2(span.y, existing.y))
		spans = result
	return spans


func _gap_span(outline: PackedVector2Array, edge_index: int, from_value: float, to_value: float) -> Vector2:
	var a: Vector2 = outline[edge_index]
	var b: Vector2 = outline[(edge_index + 1) % outline.size()]
	var t0: float = _param_along(a, b, from_value)
	var t1: float = _param_along(a, b, to_value)
	return Vector2(minf(t0, t1), maxf(t0, t1))


func _param_along(a: Vector2, b: Vector2, value: float) -> float:
	if absf(b.x - a.x) >= absf(b.y - a.y):
		if absf(b.x - a.x) <= EPSILON:
			return 0.0
		return (value - a.x) / (b.x - a.x)
	if absf(b.y - a.y) <= EPSILON:
		return 0.0
	return (value - a.y) / (b.y - a.y)


func _gaps_for(spec: Dictionary, edge_index: int) -> Array:
	var matched: Array = []
	for gap: Dictionary in spec["gaps"]:
		if int(gap["edge"]) == edge_index:
			matched.append(gap)
	return matched


func _outward(a: Vector2, b: Vector2) -> Vector2:
	var direction: Vector2 = b - a
	if direction.length() <= EPSILON:
		return Vector2.ZERO
	return Vector2(direction.y, -direction.x).normalized()


func _surface() -> Dictionary:
	return {"vertices": [] as Array[Vector3], "normals": [] as Array[Vector3], "indices": [] as Array[int]}


## Emits a quad, auto-orienting the winding to agree with `normal_hint`, and feeds the
## same triangles to the collision builder.
func _add_quad(surface: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal_hint: Vector3, collision: Array[Vector3]) -> void:
	var normal: Vector3 = (b - a).cross(c - a)
	if normal.length_squared() <= EPSILON or normal.normalized().dot(normal_hint) < 0.0:
		_add_tri(surface, a, c, b, normal_hint, collision)
		_add_tri(surface, a, d, c, normal_hint, collision)
		return
	_add_tri(surface, a, b, c, normal_hint, collision)
	_add_tri(surface, a, c, d, normal_hint, collision)


## Emits a triangle whose CCW normal agrees with `normal_hint` (so the normal attribute
## points at the visible side), then reverses the winding for the mesh and collision:
## Godot treats clockwise-wound triangles as front faces.
func _add_tri(surface: Dictionary, a: Vector3, b: Vector3, c: Vector3, normal_hint: Vector3, collision: Array[Vector3]) -> void:
	var normal: Vector3 = (b - a).cross(c - a)
	var hint: Vector3 = normal_hint.normalized() if normal_hint.length_squared() > EPSILON else Vector3.UP
	if normal.length_squared() <= EPSILON:
		normal = hint
	elif normal.normalized().dot(hint) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	else:
		normal = normal.normalized()
	var vertices: Array = surface["vertices"]
	var normals: Array = surface["normals"]
	var indices: Array = surface["indices"]
	var base: int = vertices.size()
	for point: Vector3 in [a, b, c]:
		vertices.append(point)
		normals.append(normal)
	indices.append(base + 0)
	indices.append(base + 2)
	indices.append(base + 1)
	if collision != null:
		collision.append(a)
		collision.append(c)
		collision.append(b)


func _make_surface_node(node_name: String, surface: Dictionary, material_path: String, collision: Array[Vector3]) -> MeshInstance3D:
	var vertices: Array = surface["vertices"]
	var normals: Array = surface["normals"]
	var indices: Array = surface["indices"]
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)
	var mesh: ArrayMesh = ArrayMesh.new()
	if indices.size() >= 3:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name + "Mesh"
	node.mesh = mesh
	node.material_override = _materials[material_path] as Material
	return node


## Wraparound cockpit console bank: faceted angled dash panels along the front and sides
## with inset phosphor screens, light strips and a centre pedestal. Geometry only.
func _build_cockpit_dash() -> void:
	var space: Node = _root.get_node_or_null(^"Cockpit")
	if space == null or not (space is Node3D):
		_failures += 1
		print("FAIL: cockpit missing for dash")
		return
	var cockpit: Node3D = space as Node3D
	var panel_tilt: float = -24.0
	var front_x: Array[float] = [-2.4, -1.2, 0.0, 1.2, 2.4]
	for i: int in front_x.size():
		var panel_x: float = front_x[i]
		_add_dash_panel(cockpit, "DashN%d" % i, Vector3(panel_x, 0.92, -18.42), Vector3(1.16, 0.2, 0.5), Vector3(panel_tilt, 0, 0))
		_add_dressing("Cockpit", "DashScreenN%d" % i, Vector3(panel_x, 1.03, -18.28), Vector3(0.46, 0.02, 0.22), MATERIAL_STRIP)
	var side_x: Array[float] = [3.2, -3.2]
	var side_z: Array[float] = [-18.0, -16.8, -15.6]
	for side_index: int in side_x.size():
		var panel_x2: float = side_x[side_index]
		var side_label: String = "E" if panel_x2 > 0.0 else "W"
		var tilt: float = panel_tilt * (1.0 if panel_x2 > 0.0 else -1.0)
		for j: int in side_z.size():
			var panel_z: float = side_z[j]
			_add_dash_panel(cockpit, "Dash%s%d" % [side_label, j], Vector3(panel_x2, 0.92, panel_z), Vector3(0.5, 0.2, 1.16), Vector3(0, 0, tilt))
			_add_dressing("Cockpit", "DashScreen%s%d" % [side_label, j], Vector3(panel_x2 - 0.14 * signf(panel_x2), 1.03, panel_z), Vector3(0.22, 0.02, 0.46), MATERIAL_STRIP)
	_add_dash_panel(cockpit, "DashPedestal", Vector3(0.0, 0.45, -17.5), Vector3(0.8, 0.9, 0.5), Vector3.ZERO)
	_add_dressing("Cockpit", "DashPedestalScreen", Vector3(0.0, 0.92, -17.24), Vector3(0.4, 0.02, 0.24), MATERIAL_STRIP)
	_add_dressing("Cockpit", "DashStripN", Vector3(0.0, 1.04, -18.6), Vector3(6.8, 0.03, 0.05), MATERIAL_STRIP)
	_build_cockpit_window(cockpit)


## Forward windshield: the wall band carries a real opening (SPACES cockpit gap with a
## bottom), lined with sill, header and jamb parts and closed by the space pane.
func _build_cockpit_window(space: Node3D) -> void:
	var pane: MeshInstance3D = MeshInstance3D.new()
	pane.name = "DressingWindowPane"
	var pane_mesh: BoxMesh = BoxMesh.new()
	pane_mesh.size = Vector3(3.8, 1.06, 0.04)
	pane.mesh = pane_mesh
	pane.material_override = _materials[MATERIAL_WINDOW] as Material
	pane.position = Vector3(0.0, 1.75, -18.72)
	space.add_child(pane)
	_add_dash_panel(space, "WindowSill", Vector3(0.0, 1.19, -18.72), Vector3(4.0, 0.14, 0.22), Vector3.ZERO)
	_add_dash_panel(space, "WindowHeader", Vector3(0.0, 2.31, -18.72), Vector3(4.0, 0.14, 0.22), Vector3.ZERO)
	_add_dash_panel(space, "WindowJambW", Vector3(-1.97, 1.75, -18.72), Vector3(0.14, 1.06, 0.22), Vector3.ZERO)
	_add_dash_panel(space, "WindowJambE", Vector3(1.97, 1.75, -18.72), Vector3(0.14, 1.06, 0.22), Vector3.ZERO)
	_add_dressing("Cockpit", "WindowStrip", Vector3(0.0, 2.4, -18.62), Vector3(3.8, 0.03, 0.06), MATERIAL_STRIP)


## A dash panel: box mesh + its own collision shape inside the cockpit body.
func _add_dash_panel(space: Node3D, part_name: String, center: Vector3, size: Vector3, rotation_degrees: Vector3) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = part_name + "Shape"
	shape_node.shape = shape
	shape_node.position = center
	shape_node.rotation_degrees = rotation_degrees
	space.add_child(shape_node)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = part_name + "Mesh"
	mesh_node.mesh = mesh
	mesh_node.material_override = _materials[MATERIAL_XENON] as Material
	mesh_node.position = center
	mesh_node.rotation_degrees = rotation_degrees
	space.add_child(mesh_node)


## Faceted outer hull: chamfered plan band with the airlock doorway, keel and deck caps,
## the perimeter catwalk, an aft deck with a roof ramp, railings and hardpoint markers.
func _build_hull_exterior() -> void:
	var hull: StaticBody3D = StaticBody3D.new()
	hull.name = "HullExterior"
	_root.add_child(hull)
	var shell: Dictionary = _surface()
	var decks: Dictionary = _surface()
	var collision: Array[Vector3] = []
	var plan: PackedVector2Array = HullProfile.rectangle_outline(HULL_PLAN_MIN, HULL_PLAN_MAX, HULL_CHAMFER)
	var outer: PackedVector2Array = HullProfile.offset_polygon(plan, HULL_BAND)
	for edge_index: int in plan.size():
		_add_hull_band(shell, plan, outer, edge_index, collision)
	_add_prism(decks, shell, plan, -0.85, HULL_BOTTOM, collision)
	_add_prism(decks, shell, outer, DECK_BOTTOM, DECK_TOP, collision)
	_add_catwalk(decks, shell, collision)
	_add_aft_deck(decks, shell, collision)
	_add_ramp(decks, shell, collision)
	_add_railings(hull)
	_add_dock_plates(hull)
	_add_eva_anchors(hull)
	hull.add_child(_make_surface_node("Hull", shell, MATERIAL_XENON, collision))
	hull.add_child(_make_surface_node("Deck", decks, MATERIAL_FLOOR, collision))
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array(collision))
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "ShellShape"
	shape_node.shape = shape
	hull.add_child(shape_node)


func _add_hull_band(surface: Dictionary, plan: PackedVector2Array, outer: PackedVector2Array, edge_index: int, collision: Array[Vector3]) -> void:
	var count: int = plan.size()
	var a: Vector2 = plan[edge_index]
	var b: Vector2 = plan[(edge_index + 1) % count]
	var oa: Vector2 = outer[edge_index]
	var ob: Vector2 = outer[(edge_index + 1) % count]
	var outward: Vector2 = _outward(a, b)
	var outward_3d: Vector3 = Vector3(outward.x, 0.0, outward.y)
	var direction_3d: Vector3 = Vector3(b.x - a.x, 0.0, b.y - a.y).normalized()
	var spans: Array = [Vector2(0.0, 1.0)]
	var gaps: Array = _hull_gaps_for_edge(edge_index)
	if not gaps.is_empty():
		spans = _spans_without_gaps(plan, edge_index, gaps)
	for span: Vector2 in spans:
		var in_a: Vector3 = Vector3(a.lerp(b, span.x).x, HULL_BOTTOM, a.lerp(b, span.x).y)
		var in_b: Vector3 = Vector3(a.lerp(b, span.y).x, HULL_BOTTOM, a.lerp(b, span.y).y)
		var in_a2: Vector3 = Vector3(in_a.x, DECK_BOTTOM, in_a.z)
		var in_b2: Vector3 = Vector3(in_b.x, DECK_BOTTOM, in_b.z)
		var out_a: Vector3 = Vector3(oa.lerp(ob, span.x).x, HULL_BOTTOM, oa.lerp(ob, span.x).y)
		var out_b: Vector3 = Vector3(oa.lerp(ob, span.y).x, HULL_BOTTOM, oa.lerp(ob, span.y).y)
		var out_a2: Vector3 = Vector3(out_a.x, DECK_BOTTOM, out_a.z)
		var out_b2: Vector3 = Vector3(out_b.x, DECK_BOTTOM, out_b.z)
		_add_quad(surface, in_a, in_b, in_b2, in_a2, -outward_3d, collision)
		_add_quad(surface, out_a, out_b, out_b2, out_a2, outward_3d, collision)
		_add_quad(surface, in_a, in_b, out_b, out_a, Vector3.DOWN, collision)
		_add_quad(surface, in_a2, in_b2, out_b2, out_a2, Vector3.UP, collision)
	for gap: Dictionary in gaps:
		var gap_span: Vector2 = _gap_span(plan, edge_index, float(gap["from"]), float(gap["to"]))
		_add_flat_jamb(surface, plan, outer, edge_index, gap_span.x, HULL_BOTTOM, DOOR_TOP, direction_3d, collision)
		_add_flat_jamb(surface, plan, outer, edge_index, gap_span.y, HULL_BOTTOM, DOOR_TOP, -direction_3d, collision)
		var inner_gap_a: Vector2 = a.lerp(b, gap_span.x)
		var inner_gap_b: Vector2 = a.lerp(b, gap_span.y)
		var outer_gap_a: Vector2 = oa.lerp(ob, gap_span.x)
		var outer_gap_b: Vector2 = oa.lerp(ob, gap_span.y)
		_add_quad(
			surface,
			Vector3(inner_gap_a.x, DOOR_TOP, inner_gap_a.y), Vector3(inner_gap_b.x, DOOR_TOP, inner_gap_b.y),
			Vector3(outer_gap_b.x, DOOR_TOP, outer_gap_b.y), Vector3(outer_gap_a.x, DOOR_TOP, outer_gap_a.y),
			Vector3.DOWN, collision
		)
		_add_quad(
			surface,
			Vector3(inner_gap_a.x, CATWALK_TOP, inner_gap_a.y), Vector3(inner_gap_b.x, CATWALK_TOP, inner_gap_b.y),
			Vector3(outer_gap_b.x, CATWALK_TOP, outer_gap_b.y), Vector3(outer_gap_a.x, CATWALK_TOP, outer_gap_a.y),
			Vector3.UP, collision
		)
		_add_quad(
			surface,
			Vector3(inner_gap_a.x, CATWALK_BOTTOM, inner_gap_a.y), Vector3(inner_gap_b.x, CATWALK_BOTTOM, inner_gap_b.y),
			Vector3(outer_gap_b.x, CATWALK_BOTTOM, outer_gap_b.y), Vector3(outer_gap_a.x, CATWALK_BOTTOM, outer_gap_a.y),
			Vector3.DOWN, collision
		)


## Prism between a plan polygon and its outward offset: caps go to `caps`, sides to `sides`.
func _add_prism(caps: Dictionary, sides: Dictionary, polygon: PackedVector2Array, y_bottom: float, y_top: float, collision: Array[Vector3]) -> void:
	_add_cap(caps, polygon, y_bottom, y_top, collision)
	for edge_index: int in polygon.size():
		var a: Vector2 = polygon[edge_index]
		var b: Vector2 = polygon[(edge_index + 1) % polygon.size()]
		var outward_3d: Vector3 = Vector3(_outward(a, b).x, 0.0, _outward(a, b).y)
		_add_quad(
			sides,
			Vector3(a.x, y_bottom, a.y), Vector3(b.x, y_bottom, b.y),
			Vector3(b.x, y_top, b.y), Vector3(a.x, y_top, a.y),
			outward_3d, collision
		)


func _add_catwalk(decks: Dictionary, sides: Dictionary, collision: Array[Vector3]) -> void:
	var outer_min: Vector2 = HULL_PLAN_MIN - Vector2(CATWALK_MARGIN, CATWALK_MARGIN)
	var outer_max: Vector2 = HULL_PLAN_MAX + Vector2(CATWALK_MARGIN, CATWALK_MARGIN)
	var inner_min: Vector2 = HULL_PLAN_MIN - Vector2(HULL_BAND, HULL_BAND)
	var inner_max: Vector2 = HULL_PLAN_MAX + Vector2(HULL_BAND, HULL_BAND)
	_add_slab(decks, sides, Vector2(outer_min.x, outer_min.y), Vector2(outer_max.x, inner_min.y), collision)
	_add_slab(decks, sides, Vector2(outer_min.x, inner_max.y), Vector2(outer_max.x, outer_max.y), collision)
	_add_slab(decks, sides, Vector2(outer_min.x, inner_min.y), Vector2(inner_min.x, inner_max.y), collision)
	_add_slab(decks, sides, Vector2(inner_max.x, inner_min.y), Vector2(outer_max.x, inner_max.y), collision)


func _add_aft_deck(decks: Dictionary, sides: Dictionary, collision: Array[Vector3]) -> void:
	_add_slab(decks, sides, Vector2(-4.0, 9.9), Vector2(2.4, 15.0), collision)
	_add_slab(sides, sides, Vector2(-4.0, 9.9), Vector2(2.4, 15.0), collision, -1.0, CATWALK_BOTTOM)


func _add_ramp(decks: Dictionary, sides: Dictionary, collision: Array[Vector3]) -> void:
	var corners: Array[Vector3] = [
		Vector3(1.2, -0.16, 14.5), Vector3(2.4, -0.16, 14.5), Vector3(2.4, 3.42, 8.45), Vector3(1.2, 3.42, 8.45),
		Vector3(1.2, 0.0, 14.5), Vector3(2.4, 0.0, 14.5), Vector3(2.4, 3.58, 8.45), Vector3(1.2, 3.58, 8.45),
	]
	_add_hexahedron(decks, corners, collision)


func _add_slab(caps: Dictionary, sides: Dictionary, min_xz: Vector2, max_xz: Vector2, collision: Array[Vector3], y_bottom: float = CATWALK_BOTTOM, y_top: float = CATWALK_TOP) -> void:
	var rect: PackedVector2Array = HullProfile.rectangle_outline(min_xz, max_xz, 0.0)
	_add_prism(caps, sides, rect, y_bottom, y_top, collision)


func _add_hexahedron(surface: Dictionary, corners: Array[Vector3], collision: Array[Vector3]) -> void:
	var centroid: Vector3 = Vector3.ZERO
	for corner: Vector3 in corners:
		centroid += corner
	centroid /= float(corners.size())
	var faces: Array = [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
	for face: Array in faces:
		var points: Array[Vector3] = [corners[face[0]], corners[face[1]], corners[face[2]], corners[face[3]]]
		var center: Vector3 = (points[0] + points[1] + points[2] + points[3]) / 4.0
		var hint: Vector3 = (center - centroid).normalized()
		_add_quad(surface, points[0], points[1], points[2], points[3], hint, collision)


func _add_railings(hull: StaticBody3D) -> void:
	var bars: Array[Array] = [
		[Vector3(-9.88, 1.0, -5.5), Vector3(0.06, 0.08, 30.8)],
		[Vector3(7.98, 1.0, -5.5), Vector3(0.06, 0.08, 30.8)],
		[Vector3(-0.95, 1.0, -20.83), Vector3(17.9, 0.08, 0.06)],
		[Vector3(-0.95, 1.0, 9.83), Vector3(17.9, 0.08, 0.06)],
		[Vector3(-3.93, 1.0, 12.45), Vector3(0.06, 0.08, 5.1)],
		[Vector3(2.33, 1.0, 12.45), Vector3(0.06, 0.08, 5.1)],
		[Vector3(-0.8, 1.0, 14.93), Vector3(6.4, 0.08, 0.06)],
	]
	for i: int in bars.size():
		var entry: Array = bars[i]
		var bar: MeshInstance3D = MeshInstance3D.new()
		bar.name = "Railing%d" % i
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = entry[1]
		bar.mesh = mesh
		bar.material_override = _materials[MATERIAL_CONDUIT] as Material
		bar.position = entry[0]
		hull.add_child(bar)


## M10 dock mounts: a throat from each parent room's outer wall to the hull band, and a
## flush mount plate sealing the hull aperture until a pod is built there.
func _build_dock_throats() -> void:
	for dock: Dictionary in DOCKS:
		_build_dock_throat(dock)


func _build_dock_throat(dock: Dictionary) -> void:
	var hull_face: float = _hull_face_for(float(dock["outward"]))
	var room_face: float = float(dock["room_face"])
	if absf(room_face - hull_face) <= EPSILON:
		return
	var z: float = float(dock["z"])
	var min_x: float = minf(room_face, hull_face)
	var max_x: float = maxf(room_face, hull_face)
	var hull_end_is_west: bool = hull_face < room_face
	_build_prism_space(_root, "DockThroat_" + String(dock["id"]), {
		"name": "DockThroat_" + String(dock["id"]),
		"min": Vector2(min_x, z - DOCK_DOOR_HALF),
		"max": Vector2(max_x, z + DOCK_DOOR_HALF),
		"chamfer": 0.0,
		"profile": "throat",
		"walls": [0, 2],
		"open": [1, 3],
		"naked_edges": [3 if hull_end_is_west else 1],
		"gaps": [],
	})


## Flush mount plate + hardpoint marker per dock, children of the hull shell. The plate
## spans the hull band's full height so it seals the aperture (M10.3 swaps it for the pod).
func _add_dock_plates(hull: StaticBody3D) -> void:
	for dock: Dictionary in DOCKS:
		var id: String = String(dock["id"])
		var outward: float = float(dock["outward"])
		var band_outer: float = _hull_face_for(outward) + outward * HULL_BAND
		var plate: StaticBody3D = StaticBody3D.new()
		plate.name = "DockPlate_" + id
		plate.position = Vector3(band_outer - outward * DOCK_PLATE_THICKNESS * 0.5, (HULL_BOTTOM + DECK_BOTTOM) * 0.5, float(dock["z"]))
		_join_group(plate, &"dock_plate")
		plate.set_meta(&"hardpoint_id", StringName(id))
		hull.add_child(plate)
		var size: Vector3 = Vector3(DOCK_PLATE_THICKNESS, DECK_BOTTOM - HULL_BOTTOM, DOCK_DOOR_HALF * 2.0)
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = size
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.name = "Shape"
		shape.shape = box_shape
		plate.add_child(shape)
		var box_mesh: BoxMesh = BoxMesh.new()
		box_mesh.size = size
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = "Mesh"
		mesh.mesh = box_mesh
		mesh.material_override = _materials[MATERIAL_CONDUIT] as Material
		plate.add_child(mesh)
		var marker: Node3D = Node3D.new()
		marker.name = "Hardpoint_" + id
		marker.position = Vector3(band_outer + outward * 0.1, 1.4, float(dock["z"]))
		_join_group(marker, &"hardpoint")
		marker.set_meta(&"hardpoint_id", StringName(id))
		hull.add_child(marker)


## Group membership must be marked persistent to reach the packed scene; do it while the
## node is inside the tree so the assignment is legal.
func _join_group(node: Node, group: StringName) -> void:
	root.add_child(node)
	node.add_to_group(group, true)
	root.remove_child(node)


func _hull_face_for(outward: float) -> float:
	return HULL_PLAN_MIN.x if outward < 0.0 else HULL_PLAN_MAX.x


func _hull_gaps_for_edge(edge_index: int) -> Array:
	var gaps: Array = []
	if edge_index == 6:
		gaps.append({"from": AIRLOCK_GAP_FROM, "to": AIRLOCK_GAP_TO})
	for dock: Dictionary in DOCKS:
		if int(dock["hull_edge"]) == edge_index:
			gaps.append({"from": float(dock["z"]) - DOCK_DOOR_HALF, "to": float(dock["z"]) + DOCK_DOOR_HALF})
	return gaps


func _add_eva_anchors(hull: StaticBody3D) -> void:
	var anchor_positions: Array[Vector3] = [
		Vector3(-9.0, 0.25, -1.2),
		Vector3(0.0, 3.85, -14.0),
		Vector3(0.0, 3.85, 4.0),
		Vector3(-1.0, 0.25, 12.0),
	]
	for i: int in anchor_positions.size():
		var anchor: Node3D = Node3D.new()
		anchor.name = "TetherAnchor%d" % i
		anchor.position = anchor_positions[i]
		anchor.set_script(load(SCRIPT_TETHER_ANCHOR) as Script)
		hull.add_child(anchor)
	var zone: Area3D = Area3D.new()
	zone.name = "TetherZone"
	zone.position = Vector3(-9.0, 1.2, -1.2)
	zone.set_script(load(SCRIPT_TETHER_ZONE) as Script)
	hull.add_child(zone)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.8, 2.4, 2.6)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = box
	zone.add_child(shape)


## Visual greeble only (no collision): ceiling light strips tucked into the flat ceiling
## centre of each space, clear of the canted coves.
func _build_dressing() -> void:
	_add_dressing("Corridor", "Strip", Vector3(0, 2.96, -6.3), Vector3(0.24, 0.04, 12.0), MATERIAL_STRIP)
	_add_dressing("Cockpit", "Strip", Vector3(0, 2.96, -16.6), Vector3(4.6, 0.04, 0.24), MATERIAL_STRIP)
	_add_dressing("Quarters", "Strip", Vector3(-3.15, 2.96, -10.4), Vector3(0.24, 0.04, 3.2), MATERIAL_STRIP)
	_add_dressing("LifeSupport", "Strip", Vector3(-2.65, 2.96, -6.3), Vector3(2.4, 0.04, 0.24), MATERIAL_STRIP)
	_add_dressing("Galley", "Strip", Vector3(2.9, 2.96, -5.8), Vector3(0.24, 0.04, 2.2), MATERIAL_STRIP)
	_add_dressing("WaterCloset", "Strip", Vector3(2.2, 2.96, -1.9), Vector3(0.24, 0.04, 1.2), MATERIAL_STRIP)
	_add_dressing("Storage", "Strip", Vector3(-2.75, 2.96, -1.2), Vector3(0.24, 0.04, 2.4), MATERIAL_STRIP)
	_add_dressing("EngineBay", "Strip", Vector3(0, 2.96, 4.7), Vector3(4.8, 0.04, 0.24), MATERIAL_STRIP)
	_add_dressing("Airlock", "Strip", Vector3(-5.8, 2.96, -1.2), Vector3(0.24, 0.04, 1.0), MATERIAL_STRIP)


func _add_dressing(space_name: String, part_name: String, center: Vector3, size: Vector3, material_path: String) -> void:
	var space: Node = _root.get_node_or_null(NodePath(space_name))
	if space == null:
		_failures += 1
		print("FAIL: dressing target missing ", space_name)
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = "Dressing" + part_name
	node.mesh = mesh
	node.material_override = _materials[material_path] as Material
	node.position = center
	space.add_child(node)


func _save() -> void:
	if _failures > 0 or _root == null:
		print("FAILURES: ", _failures)
		quit(1)
		return
	if not _write_scene(_root, OUTPUT_PATH):
		print("FAILURES: ", _failures)
		quit(1)
		return
	_root.free()
	_root = null
	var pod: Node3D = _build_dock_pod()
	var pod_ok: bool = _failures == 0 and _write_scene(pod, OUTPUT_POD_PATH)
	pod.free()
	if not pod_ok:
		print("FAILURES: ", _failures)
		quit(1)
		return
	if not _verify():
		print("FAILURES: ", _failures)
		quit(1)
		return
	print("PASS: build_ship_geometry")
	quit(0)


func _write_scene(scene_root: Node3D, path: String) -> bool:
	_assign_owners(scene_root, scene_root)
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(scene_root)
	if pack_error != OK:
		_failures += 1
		print("FAIL: pack error ", pack_error, " for ", path)
		return false
	var save_error: Error = ResourceSaver.save(packed, path)
	if save_error != OK:
		_failures += 1
		print("FAIL: save error ", save_error, " for ", path)
		return false
	return _normalize_output(path)


## PackedScene.pack() assigns random per-run node unique_ids; strip them so regenerating is byte-stable.
func _normalize_output(output_path: String) -> bool:
	var file: FileAccess = FileAccess.open(output_path, FileAccess.READ)
	if file == null:
		_failures += 1
		print("FAIL: cannot reopen ", output_path)
		return false
	var text: String = file.get_as_text()
	file.close()
	var regex: RegEx = RegEx.new()
	regex.compile(" unique_id=\\d+")
	var write_file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if write_file == null:
		_failures += 1
		print("FAIL: cannot rewrite ", output_path)
		return false
	write_file.store_string(regex.sub(text, "", true))
	write_file.close()
	return true


func _assign_owners(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		_assign_owners(child, owner)


func _verify() -> bool:
	var loaded: PackedScene = load(OUTPUT_PATH) as PackedScene
	if loaded == null:
		_failures += 1
		print("FAIL: generated scene did not load")
		return false
	var instance: Node = loaded.instantiate()
	var parts: int = 0
	for space_name: String in SPACE_NAMES:
		var space: Node = instance.get_node_or_null(NodePath(space_name))
		if space == null:
			_failures += 1
			print("FAIL: missing space ", space_name)
			continue
		if not (space is StaticBody3D):
			_failures += 1
			print("FAIL: space is not a StaticBody3D: ", space_name)
			continue
		var shape_node: CollisionShape3D = space.get_node_or_null(^"ShellShape") as CollisionShape3D
		if shape_node == null or not (shape_node.shape is ConcavePolygonShape3D):
			_failures += 1
			print("FAIL: no shell collision in ", space_name)
		var floor_mesh: MeshInstance3D = space.get_node_or_null(^"FloorMesh") as MeshInstance3D
		if floor_mesh == null or floor_mesh.mesh == null:
			_failures += 1
			print("FAIL: no floor mesh in ", space_name)
		parts += _count_parts(space)
	var hull: Node = instance.get_node_or_null(^"HullExterior")
	if hull == null:
		_failures += 1
		print("FAIL: missing HullExterior")
	else:
		var hull_shape: CollisionShape3D = hull.get_node_or_null(^"ShellShape") as CollisionShape3D
		if hull_shape == null or not (hull_shape.shape is ConcavePolygonShape3D):
			_failures += 1
			print("FAIL: HullExterior has no shell collision")
		_verify_docks(hull)
	print("OK: spaces=", SPACE_NAMES.size(), " parts=", parts, " docks=", DOCKS.size())
	instance.free()
	_verify_dock_table()
	var pod: PackedScene = load(OUTPUT_POD_PATH) as PackedScene
	if pod == null:
		_failures += 1
		print("FAIL: generated pod scene did not load")
		return _failures == 0
	var pod_instance: Node = pod.instantiate()
	_verify_pod(pod_instance)
	pod_instance.free()
	return _failures == 0


## Every pinned dock must exist as a plate + marker on the hull, with one doorway in its
## parent room and one hull-band aperture, all sharing the pinned hardpoint id.
func _verify_docks(hull: Node) -> void:
	var plates: int = 0
	var markers: int = 0
	for dock: Dictionary in DOCKS:
		var id: String = String(dock["id"])
		var plate: Node = hull.get_node_or_null(NodePath("DockPlate_" + id))
		if plate == null or not plate.get_groups().has(&"dock_plate"):
			_failures += 1
			print("FAIL: missing dock plate ", id)
			continue
		plates += 1
		if plate.get_meta(&"hardpoint_id", &"") != StringName(id):
			_failures += 1
			print("FAIL: dock plate id mismatch: ", id)
		var shape: CollisionShape3D = plate.get_node_or_null(^"Shape") as CollisionShape3D
		var mesh: MeshInstance3D = plate.get_node_or_null(^"Mesh") as MeshInstance3D
		if shape == null or not (shape.shape is BoxShape3D) or mesh == null or mesh.mesh == null:
			_failures += 1
			print("FAIL: dock plate is incomplete: ", id)
		var marker: Node = hull.get_node_or_null(NodePath("Hardpoint_" + id))
		if marker == null or not marker.get_groups().has(&"hardpoint"):
			_failures += 1
			print("FAIL: missing hardpoint marker ", id)
			continue
		markers += 1
	if plates != DOCKS.size() or markers != DOCKS.size():
		_failures += 1
		print("FAIL: expected ", DOCKS.size(), " dock plates and markers, found ", plates, " and ", markers)


## Guards the pinned dock table against drift: each entry must match its room's plan bounds
## and carry the doorway gap it claims, on the hull side it claims.
func _verify_dock_table() -> void:
	for dock: Dictionary in DOCKS:
		var spec: Dictionary = {}
		for candidate: Dictionary in SPACES:
			if String(candidate["name"]) == String(dock["room"]):
				spec = candidate
				break
		if spec.is_empty():
			_failures += 1
			print("FAIL: dock room missing: ", dock["room"])
			continue
		var outward: float = float(dock["outward"])
		var expected_face: float = float(spec["min"].x) - WALL_THICKNESS if outward < 0.0 else float(spec["max"].x) + WALL_THICKNESS
		if not is_equal_approx(expected_face, float(dock["room_face"])):
			_failures += 1
			print("FAIL: dock ", dock["id"], " room_face ", dock["room_face"], " != ", expected_face)
		var gaps: Array = spec["gaps"]
		var found: bool = false
		for gap: Dictionary in gaps:
			if is_equal_approx(float(gap["from"]), float(dock["z"]) - DOCK_DOOR_HALF) and is_equal_approx(float(gap["to"]), float(dock["z"]) + DOCK_DOOR_HALF):
				found = true
		if not found:
			_failures += 1
			print("FAIL: dock ", dock["id"], " has no matching doorway gap in ", dock["room"])


func _verify_pod(pod: Node) -> void:
	var room: Node = pod.get_node_or_null(^"PodRoom")
	if room == null:
		_failures += 1
		print("FAIL: pod has no PodRoom")
	else:
		var shape_node: CollisionShape3D = room.get_node_or_null(^"ShellShape") as CollisionShape3D
		if shape_node == null or not (shape_node.shape is ConcavePolygonShape3D):
			_failures += 1
			print("FAIL: pod room has no shell collision")
		var floor_mesh: MeshInstance3D = room.get_node_or_null(^"FloorMesh") as MeshInstance3D
		if floor_mesh == null or floor_mesh.mesh == null:
			_failures += 1
			print("FAIL: pod room has no floor mesh")
	var zone: Node = pod.get_node_or_null(^"Zone")
	if zone == null or zone.get(&"compartment_id") != &"module":
		_failures += 1
		print("FAIL: pod zone missing or has no module compartment id")
	elif not (zone.get_node_or_null(^"Shape") as CollisionShape3D).shape is BoxShape3D:
		_failures += 1
		print("FAIL: pod zone has no box shape")
	var link: Node = pod.get_node_or_null(^"Link")
	if link == null or link.get(&"compartment_a") != &"module":
		_failures += 1
		print("FAIL: pod link missing or not wired to the module compartment")


func _count_parts(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			count += 1
		count += _count_parts(child)
	return count
