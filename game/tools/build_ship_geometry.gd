## Generates the faceted polygonal ship: plan outlines (chamfered rectangles) extruded
## through profile rings into mitered wall bands, floor/ceiling caps and doorway cutouts.
## Geometry is built in memory and packed, so it is reproducible from the tables below.
## Re-run after changing the layout:
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/build_ship_geometry.gd
extends SceneTree

const OUTPUT_PATH: String = "res://scenes/ship_geometry.tscn"

const MATERIAL_FLOOR: String = "res://src/data/materials/mat_floor_grate.tres"
const MATERIAL_XENON: String = "res://src/data/materials/mat_xenon_metal.tres"
const MATERIAL_STRIP: String = "res://src/data/materials/mat_light_strip.tres"
const MATERIAL_CONDUIT: String = "res://src/data/materials/mat_metal_rusted.tres"
const SCRIPT_TETHER_ANCHOR: String = "res://src/world/tether_anchor.gd"
const SCRIPT_TETHER_ZONE: String = "res://src/world/tether_zone.gd"

const WALL_THICKNESS: float = 0.2
const DOOR_TOP: float = 2.2
const FLOOR_BOTTOM: float = -0.2
const CEILING_BOTTOM: float = 3.0
const CEILING_TOP: float = 3.2
const EPSILON: float = 0.000001

## Vertical profile as (height, inset) rings: flat floor, lower cant, vertical band,
## upper cove, flat ceiling. Flat-bottom hexagon section; insets must stay < wall thickness.
const PROFILE: Array[Vector2] = [
	Vector2(FLOOR_BOTTOM, 0.0),
	Vector2(0.0, 0.0),
	Vector2(0.7, 0.14),
	Vector2(2.3, 0.14),
	Vector2(CEILING_BOTTOM, 0.0),
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

## Spaces: interior plan bounds, corner chamfer, wall edges, open edges and doorway gaps.
## Gaps name the varying world axis coordinate; `top` defaults to the door head height and
## uses CEILING_TOP for a full-height junction opening.
const SPACES: Array[Dictionary] = [
	{
		"name": "Cockpit",
		"min": Vector2(-3.4, -18.8),
		"max": Vector2(3.4, -14.2),
		"chamfer": 0.9,
		"walls": [0, 1, 2, 3, 4, 5, 6, 7],
		"open": [],
		"gaps": [{"edge": 4, "from": -0.7, "to": 0.7, "top": CEILING_TOP}],
	},
	{
		"name": "Corridor",
		"min": Vector2(-0.7, -14.0),
		"max": Vector2(0.7, 1.4),
		"chamfer": 0.0,
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
		"min": Vector2(-5.4, -12.6),
		"max": Vector2(-0.9, -8.2),
		"chamfer": 0.9,
		"walls": [0, 1, 3, 4, 5, 6, 7],
		"open": [2],
		"gaps": [],
	},
	{
		"name": "LifeSupport",
		"min": Vector2(-4.4, -7.6),
		"max": Vector2(-0.9, -5.0),
		"chamfer": 0.9,
		"walls": [0, 1, 3, 4, 5, 6, 7],
		"open": [2],
		"gaps": [],
	},
	{
		"name": "Galley",
		"min": Vector2(0.9, -7.6),
		"max": Vector2(4.9, -4.0),
		"chamfer": 0.9,
		"walls": [0, 1, 2, 3, 4, 5, 7],
		"open": [6],
		"gaps": [],
	},
	{
		"name": "WaterCloset",
		"min": Vector2(0.9, -3.0),
		"max": Vector2(3.5, -0.8),
		"chamfer": 0.25,
		"walls": [0, 1, 2, 3, 4, 5, 7],
		"open": [6],
		"gaps": [],
	},
	{
		"name": "Storage",
		"min": Vector2(-4.6, -3.0),
		"max": Vector2(-0.9, 0.6),
		"chamfer": 0.9,
		"walls": [0, 1, 3, 4, 5, 6, 7],
		"open": [2],
		"gaps": [{"edge": 6, "from": -1.6, "to": -0.4}],
	},
	{
		"name": "EngineBay",
		"min": Vector2(-3.6, 1.6),
		"max": Vector2(3.6, 7.8),
		"chamfer": 0.9,
		"walls": [0, 1, 2, 3, 4, 5, 6, 7],
		"open": [],
		"gaps": [{"edge": 0, "from": -0.7, "to": 0.7, "top": CEILING_TOP}],
	},
	{
		"name": "Airlock",
		"min": Vector2(-6.8, -2.2),
		"max": Vector2(-4.8, -0.2),
		"chamfer": 0.25,
		"walls": [0, 1, 3, 4, 5, 6, 7],
		"open": [2],
		"gaps": [{"edge": 6, "from": -1.7, "to": -0.7}],
	},
]

const HULL_PLAN_MIN: Vector2 = Vector2(-7.0, -19.0)
const HULL_PLAN_MAX: Vector2 = Vector2(5.1, 8.0)
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

var _root: Node3D
var _materials: Dictionary = {}
var _failures: int = 0


func _initialize() -> void:
	_load_materials()
	if _failures == 0:
		_build()
	_save()


func _load_materials() -> void:
	for path: String in [MATERIAL_FLOOR, MATERIAL_XENON, MATERIAL_STRIP, MATERIAL_CONDUIT]:
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
	_build_hull_exterior()
	_build_dressing()


func _make_space(space_name: String) -> StaticBody3D:
	var space: StaticBody3D = StaticBody3D.new()
	space.name = space_name
	_root.add_child(space)
	return space


func _build_space(spec: Dictionary) -> void:
	var space: StaticBody3D = _make_space(String(spec["name"]))
	var outline: PackedVector2Array = HullProfile.rectangle_outline(spec["min"], spec["max"], spec["chamfer"])
	if outline.is_empty():
		_failures += 1
		print("FAIL: empty outline for ", spec["name"])
		return
	var outer: PackedVector2Array = HullProfile.offset_polygon(outline, WALL_THICKNESS)
	var walls: Dictionary = _surface()
	var floors: Dictionary = _surface()
	var ceilings: Dictionary = _surface()
	var collision: Array[Vector3] = []
	var open_edges: Array = spec["open"]
	for edge_index: int in spec["walls"]:
		_add_wall_edge(walls, outline, outer, edge_index, _gaps_for(spec, edge_index), collision)
	for edge_index: int in open_edges:
		_add_threshold(floors, outline, outer, edge_index, 0.0, 1.0, collision)
	for gap: Dictionary in spec["gaps"]:
		var span: Vector2 = _gap_span(outline, int(gap["edge"]), float(gap["from"]), float(gap["to"]))
		_add_threshold(floors, outline, outer, int(gap["edge"]), span.x, span.y, collision)
	for edge_index: int in spec["walls"]:
		var previous: int = (edge_index - 1 + outline.size()) % outline.size()
		var following: int = (edge_index + 1) % outline.size()
		if open_edges.has(previous):
			_add_end_cap(walls, outline, outer, edge_index, 1.0, collision)
		if open_edges.has(following):
			_add_end_cap(walls, outline, outer, edge_index, 0.0, collision)
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


## One wall edge: swept inner surface split around doorway gaps, a straight outer face,
## top and bottom rims, jamb faces and lintels at every gap.
func _add_wall_edge(surface: Dictionary, outline: PackedVector2Array, outer: PackedVector2Array, edge_index: int, gaps: Array, collision: Array[Vector3]) -> void:
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
	for band: int in PROFILE.size() - 1:
		var y0: float = PROFILE[band].x
		var y1: float = PROFILE[band + 1].x
		for slice: Array in _band_slices(y0, y1, gaps):
			var sy0: float = slice[0]
			var sy1: float = slice[1]
			var active_spans: Array = spans if bool(slice[2]) else [Vector2(0.0, 1.0)]
			for span: Vector2 in active_spans:
				_add_quad(
					surface,
					_profile_point(a, b, outward, span.x, sy0),
					_profile_point(a, b, outward, span.y, sy0),
					_profile_point(a, b, outward, span.y, sy1),
					_profile_point(a, b, outward, span.x, sy1),
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
		_add_jamb(surface, outline, outer, edge_index, span.x, FLOOR_BOTTOM, top, direction_3d, collision)
		_add_jamb(surface, outline, outer, edge_index, span.y, FLOOR_BOTTOM, top, -direction_3d, collision)
		if top < CEILING_TOP - EPSILON:
			var inner_a: Vector3 = _profile_point(a, b, outward, span.x, top)
			var inner_b: Vector3 = _profile_point(a, b, outward, span.y, top)
			var outer_a2: Vector2 = oa.lerp(ob, span.x)
			var outer_b2: Vector2 = oa.lerp(ob, span.y)
			_add_quad(
				surface,
				inner_a, inner_b,
				Vector3(outer_b2.x, top, outer_b2.y), Vector3(outer_a2.x, top, outer_a2.y),
				Vector3.DOWN, collision
			)


func _add_cap(surface: Dictionary, outline: PackedVector2Array, y_low: float, y_high: float, collision: Array[Vector3]) -> void:
	for i: int in range(1, outline.size() - 1):
		var a: Vector2 = outline[0]
		var b: Vector2 = outline[i]
		var c: Vector2 = outline[i + 1]
		_add_tri(surface, Vector3(a.x, y_high, a.y), Vector3(b.x, y_high, b.y), Vector3(c.x, y_high, c.y), Vector3.UP, collision)
		_add_tri(surface, Vector3(a.x, y_low, a.y), Vector3(b.x, y_low, b.y), Vector3(c.x, y_low, c.y), Vector3.DOWN, collision)


func _add_threshold(surface: Dictionary, outline: PackedVector2Array, outer: PackedVector2Array, edge_index: int, t0: float, t1: float, collision: Array[Vector3]) -> void:
	var count: int = outline.size()
	var a: Vector2 = outline[edge_index]
	var b: Vector2 = outline[(edge_index + 1) % count]
	var oa: Vector2 = outer[edge_index]
	var ob: Vector2 = outer[(edge_index + 1) % count]
	var inner0: Vector2 = a.lerp(b, t0)
	var inner1: Vector2 = a.lerp(b, t1)
	var outer0: Vector2 = oa.lerp(ob, t0)
	var outer1: Vector2 = oa.lerp(ob, t1)
	_add_quad(
		surface,
		Vector3(inner0.x, 0.0, inner0.y), Vector3(inner1.x, 0.0, inner1.y),
		Vector3(outer1.x, 0.0, outer1.y), Vector3(outer0.x, 0.0, outer0.y),
		Vector3.UP, collision
	)
	_add_quad(
		surface,
		Vector3(inner0.x, FLOOR_BOTTOM, inner0.y), Vector3(inner1.x, FLOOR_BOTTOM, inner1.y),
		Vector3(outer1.x, FLOOR_BOTTOM, outer1.y), Vector3(outer0.x, FLOOR_BOTTOM, outer0.y),
		Vector3.DOWN, collision
	)


## Vertical face from the inner profile line at parameter t to the outer wall line,
## spanning y0..y1. Used for jambs at doorway boundaries and caps at open-edge ends.
func _add_jamb(surface: Dictionary, outline: PackedVector2Array, outer: PackedVector2Array, edge_index: int, t: float, y0: float, y1: float, normal_hint: Vector3, collision: Array[Vector3]) -> void:
	var count: int = outline.size()
	var a: Vector2 = outline[edge_index]
	var b: Vector2 = outline[(edge_index + 1) % count]
	var oa: Vector2 = outer[edge_index]
	var ob: Vector2 = outer[(edge_index + 1) % count]
	var outward: Vector2 = _outward(a, b)
	var outer_point: Vector2 = oa.lerp(ob, t)
	var heights: Array[float] = [y0]
	for ring: Vector2 in PROFILE:
		if ring.x > y0 + EPSILON and ring.x < y1 - EPSILON:
			heights.append(ring.x)
	heights.append(y1)
	for i: int in heights.size() - 1:
		var low: float = heights[i]
		var high: float = heights[i + 1]
		if high - low <= EPSILON:
			continue
		var inner_low: Vector3 = _profile_point(a, b, outward, t, low)
		var inner_high: Vector3 = _profile_point(a, b, outward, t, high)
		var outer_low: Vector3 = Vector3(outer_point.x, low, outer_point.y)
		var outer_high: Vector3 = Vector3(outer_point.x, high, outer_point.y)
		_add_quad(surface, inner_low, inner_high, outer_high, outer_low, normal_hint, collision)


func _add_end_cap(surface: Dictionary, outline: PackedVector2Array, outer: PackedVector2Array, edge_index: int, t: float, collision: Array[Vector3]) -> void:
	var a: Vector2 = outline[edge_index]
	var b: Vector2 = outline[(edge_index + 1) % outline.size()]
	var direction_3d: Vector3 = Vector3(b.x - a.x, 0.0, b.y - a.y).normalized()
	var hint: Vector3 = -direction_3d if t <= 0.0 else direction_3d
	_add_jamb(surface, outline, outer, edge_index, t, FLOOR_BOTTOM, CEILING_TOP, hint, collision)


func _profile_point(a: Vector2, b: Vector2, outward: Vector2, t: float, y: float) -> Vector3:
	var inset: float = _inset_at(y)
	var point: Vector2 = a.lerp(b, t) - outward * inset
	return Vector3(point.x, y, point.y)


func _inset_at(y: float) -> float:
	if y <= PROFILE[0].x:
		return PROFILE[0].y
	for i: int in PROFILE.size() - 1:
		var low: Vector2 = PROFILE[i]
		var high: Vector2 = PROFILE[i + 1]
		if y <= high.x:
			var span: float = high.x - low.x
			if span <= EPSILON:
				return high.y
			return lerpf(low.y, high.y, (y - low.x) / span)
	return PROFILE[PROFILE.size() - 1].y


## Sub-bands of a profile band clipped by the door head: [y0, y1, gap_active].
func _band_slices(y0: float, y1: float, gaps: Array) -> Array:
	var slices: Array = []
	if gaps.is_empty():
		slices.append([y0, y1, false])
		return slices
	var cut: float = 0.0
	for gap: Dictionary in gaps:
		cut = maxf(cut, float(gap.get("top", DOOR_TOP)))
	if cut <= y0 + EPSILON:
		slices.append([y0, y1, false])
	elif cut >= y1 - EPSILON:
		slices.append([y0, y1, true])
	else:
		slices.append([y0, cut, true])
		slices.append([cut, y1, false])
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
	indices.append(base + 1)
	indices.append(base + 2)
	if collision != null:
		collision.append(a)
		collision.append(b)
		collision.append(c)


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
	_add_hardpoints(hull)
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
	if edge_index == 6:
		spans = _spans_without_gaps(plan, edge_index, [{"edge": 6, "from": AIRLOCK_GAP_FROM, "to": AIRLOCK_GAP_TO}])
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
	if edge_index == 6:
		var gap_span: Vector2 = _gap_span(plan, edge_index, AIRLOCK_GAP_FROM, AIRLOCK_GAP_TO)
		_add_jamb(surface, plan, outer, edge_index, gap_span.x, HULL_BOTTOM, DOOR_TOP, direction_3d, collision)
		_add_jamb(surface, plan, outer, edge_index, gap_span.y, HULL_BOTTOM, DOOR_TOP, -direction_3d, collision)
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
		[Vector3(-8.83, 1.0, -5.5), Vector3(0.06, 0.08, 30.8)],
		[Vector3(6.93, 1.0, -5.5), Vector3(0.06, 0.08, 30.8)],
		[Vector3(-0.95, 1.0, -20.83), Vector3(15.9, 0.08, 0.06)],
		[Vector3(-0.95, 1.0, 9.83), Vector3(15.9, 0.08, 0.06)],
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


func _add_hardpoints(hull: StaticBody3D) -> void:
	var points: Array[Vector3] = [
		Vector3(-3.6, DECK_TOP, -13.5),
		Vector3(3.6, DECK_TOP, -13.5),
		Vector3(-3.6, DECK_TOP, 3.0),
		Vector3(3.6, DECK_TOP, 3.0),
	]
	for i: int in points.size():
		var marker: Node3D = Node3D.new()
		marker.name = "Hardpoint%s" % String.chr(65 + i)
		marker.position = points[i]
		marker.add_to_group(&"hardpoint")
		hull.add_child(marker)


func _add_eva_anchors(hull: StaticBody3D) -> void:
	var anchor_positions: Array[Vector3] = [
		Vector3(-8.1, 0.25, -1.2),
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
	zone.position = Vector3(-8.1, 1.2, -1.2)
	zone.set_script(load(SCRIPT_TETHER_ZONE) as Script)
	hull.add_child(zone)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.8, 2.4, 2.6)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = box
	zone.add_child(shape)


## Visual greeble only (no collision): ceiling light strips, corridor ribs, conduit runs.
func _build_dressing() -> void:
	_add_dressing("Corridor", "Strip", Vector3(0, 2.94, -6.3), Vector3(0.22, 0.04, 14.2), MATERIAL_STRIP)
	_add_dressing("Cockpit", "Strip", Vector3(0, 2.94, -16.5), Vector3(0.22, 0.04, 4.0), MATERIAL_STRIP)
	_add_dressing("Quarters", "Strip", Vector3(-3.15, 2.94, -10.4), Vector3(0.22, 0.04, 3.8), MATERIAL_STRIP)
	_add_dressing("LifeSupport", "Strip", Vector3(-2.65, 2.94, -6.3), Vector3(2.9, 0.04, 0.22), MATERIAL_STRIP)
	_add_dressing("Galley", "Strip", Vector3(2.9, 2.94, -5.8), Vector3(0.22, 0.04, 3.0), MATERIAL_STRIP)
	_add_dressing("WaterCloset", "Strip", Vector3(2.2, 2.94, -1.9), Vector3(0.22, 0.04, 1.6), MATERIAL_STRIP)
	_add_dressing("Storage", "Strip", Vector3(-2.75, 2.94, -1.2), Vector3(0.22, 0.04, 3.0), MATERIAL_STRIP)
	_add_dressing("EngineBay", "Strip", Vector3(0, 2.94, 4.7), Vector3(6.6, 0.04, 0.22), MATERIAL_STRIP)
	_add_dressing("Airlock", "Strip", Vector3(-5.8, 2.94, -1.2), Vector3(0.22, 0.04, 1.6), MATERIAL_STRIP)
	var spine_z: Array[float] = [-13.0, -10.6, -8.2, -5.8, -3.4, -1.0, 1.2]
	for i: int in spine_z.size():
		_add_dressing("Corridor", "RibW%d" % i, Vector3(-0.55, 1.2, spine_z[i]), Vector3(0.08, 1.0, 0.12), MATERIAL_XENON)
		_add_dressing("Corridor", "RibE%d" % i, Vector3(0.55, 1.2, spine_z[i]), Vector3(0.08, 1.0, 0.12), MATERIAL_XENON)
	_add_dressing("Corridor", "ConduitW", Vector3(-0.6, 2.62, -6.3), Vector3(0.07, 0.07, 15.0), MATERIAL_CONDUIT)
	_add_dressing("Corridor", "ConduitE", Vector3(0.6, 2.62, -6.3), Vector3(0.07, 0.07, 15.0), MATERIAL_CONDUIT)


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
	_assign_owners(_root, _root)
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(_root)
	if pack_error != OK:
		print("FAIL: pack error ", pack_error)
		quit(1)
		return
	var save_error: Error = ResourceSaver.save(packed, OUTPUT_PATH)
	if save_error != OK:
		print("FAIL: save error ", save_error)
		quit(1)
		return
	_root.free()
	_root = null
	if not _normalize_output():
		print("FAILURES: ", _failures)
		quit(1)
		return
	if not _verify():
		print("FAILURES: ", _failures)
		quit(1)
		return
	print("PASS: build_ship_geometry")
	quit(0)


## PackedScene.pack() assigns random per-run node unique_ids; strip them so regenerating is byte-stable.
func _normalize_output() -> bool:
	var output_path: String = ProjectSettings.globalize_path(OUTPUT_PATH)
	var file: FileAccess = FileAccess.open(output_path, FileAccess.READ)
	if file == null:
		_failures += 1
		print("FAIL: cannot reopen ", OUTPUT_PATH)
		return false
	var text: String = file.get_as_text()
	file.close()
	var regex: RegEx = RegEx.new()
	regex.compile(" unique_id=\\d+")
	var write_file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if write_file == null:
		_failures += 1
		print("FAIL: cannot rewrite ", OUTPUT_PATH)
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
		var hardpoint_count: int = 0
		for child: Node in hull.get_children():
			if String(child.name).begins_with("Hardpoint"):
				hardpoint_count += 1
		if hardpoint_count < 4:
			_failures += 1
			print("FAIL: expected four hardpoint markers, found ", hardpoint_count, " among ", hull.get_child_count(), " hull children")
	print("OK: spaces=", SPACE_NAMES.size(), " parts=", parts)
	instance.free()
	return _failures == 0


func _count_parts(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			count += 1
		count += _count_parts(child)
	return count
