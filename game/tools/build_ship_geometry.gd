## Generates the ship: faceted prism interiors (plan outlines extruded through profile
## rings) inside the M13 lathed section shell (SectionHull). Geometry is built in memory
## and packed, so it is reproducible from the tables. Re-run after changing the layout:
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/build_ship_geometry.gd
extends SceneTree

const OUTPUT_PATH: String = "res://scenes/ship_geometry.tscn"
const OUTPUT_POD_PATH: String = "res://scenes/dock_pod.tscn"

const MATERIAL_FLOOR: String = "res://src/data/materials/mat_deck_plate.tres"
const MATERIAL_XENON: String = "res://src/data/materials/mat_xenon_metal.tres"
const MATERIAL_STRIP: String = "res://src/data/materials/mat_light_strip.tres"
const MATERIAL_CONDUIT: String = "res://src/data/materials/mat_machined_metal.tres"
const MATERIAL_WINDOW: String = "res://src/data/materials/mat_space_window.tres"
const SCRIPT_TETHER_ANCHOR: String = "res://src/world/tether_anchor.gd"
const SCRIPT_TETHER_ZONE: String = "res://src/world/tether_zone.gd"
const SCRIPT_ZONE: String = "res://src/world/compartment_zone.gd"
const SCRIPT_LINK: String = "res://src/world/compartment_link.gd"
const SCRIPT_MODULE_MOUNT: String = "res://src/interactables/module_mount.gd"
## Interior style. "flat" is the shipped layout (wide rooms off the hexagon corridor); "tube"
## is the M13.2 chain of TubeLayout sections (train layout). Both are generated from tables, so
## flipping this is the conversion; `--interior-style=tube` previews it without touching the
## committed scene.
const INTERIOR_STYLE: String = "tube"
const SCRIPT_MACHINE_SOCKET: String = "res://src/interactables/machine_socket.gd"
## Socket pad z positions along the pod's far wall.
const MACHINE_SOCKETS: Array[float] = [-1.0, 0.0, 1.0]

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

## M13.1 section shell: SectionHull (src/world) owns the shape tables — the sweep
## constants below are the tool-side dressing only. The catwalk ring hugs the shell's
## side faces, the doorway openings start at deck level, and the dock plates sit proud
## of the shell (their outward face is the pod's mating plane).
const CATWALK_WIDTH: float = 1.0
const CATWALK_TOP: float = 0.0
const CATWALK_BOTTOM: float = -0.15
const AIRLOCK_GAP_FROM: float = -1.7
const AIRLOCK_GAP_TO: float = -0.7
const SHELL_WEST_EDGE: int = 6
const SHELL_EAST_EDGE: int = 2
const DOCK_PLATE_Y_MIN: float = -0.4
const DOCK_PLATE_Y_MAX: float = 3.2
const DOCK_SILL_DEPTH: float = 0.34

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
	if _interior_style() == "tube":
		_build_tube_interior()
		_build_tube_cockpit_dash()
		_build_tube_cockpit_window()
	else:
		for spec: Dictionary in SPACES:
			_build_space(spec)
		_build_cockpit_dash()
		_build_dressing()
	_build_hull_exterior()
	if _interior_style() != "tube":
		_build_dock_throats()


## The tube cockpit's dash: a console bank across the cupola's forward face, below the
## viewport, in the same faceted language as the flat cockpit's wrap (which the tube bow is
## too small to hold).
## The tube cockpit window: the pane at the cowl's mouth with its frame trim, so the bow is
## a shader view of space rather than a raw hole in the hull.
func _build_tube_cockpit_window() -> void:
	if TubeLayout.index_of("cupola") < 0:
		return
	var cupola: Node3D = _root.get_node_or_null(^"Section_cupola") as Node3D
	if cupola == null:
		return
	var first: Dictionary = SectionHull.tube_drums()[0]
	var pane_z: float = float(first["z0"]) - SectionHull.PROW_DEPTH + 0.05
	var center: Vector2 = (SectionHull.TUBE_WINDOW_MIN + SectionHull.TUBE_WINDOW_MAX) * 0.5
	var size: Vector2 = SectionHull.TUBE_WINDOW_MAX - SectionHull.TUBE_WINDOW_MIN
	var pane: MeshInstance3D = MeshInstance3D.new()
	pane.name = "DressingWindowPane"
	var pane_mesh: BoxMesh = BoxMesh.new()
	pane_mesh.size = Vector3(size.x, size.y, 0.05)
	pane.mesh = pane_mesh
	pane.material_override = _materials[MATERIAL_WINDOW] as Material
	pane.position = Vector3(0.0, center.y, pane_z)
	cupola.add_child(pane)
	var trim_z: float = pane_z + 0.25
	_add_dash_panel(cupola, "WindowSill", Vector3(0.0, SectionHull.TUBE_WINDOW_MIN.y - 0.08, trim_z), Vector3(size.x + 0.32, 0.16, 0.55), Vector3.ZERO)
	_add_dash_panel(cupola, "WindowHeader", Vector3(0.0, SectionHull.TUBE_WINDOW_MAX.y + 0.08, trim_z), Vector3(size.x + 0.32, 0.16, 0.55), Vector3.ZERO)
	for side: int in [-1, 1]:
		_add_dash_panel(cupola, "WindowJamb%d" % side, Vector3(float(side) * (size.x * 0.5 + 0.08), center.y, trim_z), Vector3(0.16, size.y + 0.32, 0.55), Vector3.ZERO)

func _build_tube_cockpit_dash() -> void:
	if TubeLayout.index_of("cupola") < 0:
		return
	var cupola: Node3D = _root.get_node_or_null(^"Section_cupola") as Node3D
	if cupola == null:
		return
	var bounds: Vector2 = TubeLayout.span(TubeLayout.index_of("cupola"))
	var radius: float = float(TubeLayout.sections()[TubeLayout.index_of("cupola")]["radius"])
	var face_z: float = bounds.x + 0.28
	var tilt: float = -22.0
	var panel_x: Array[float] = [-1.05, 0.0, 1.05]
	for i: int in panel_x.size():
		_add_dash_panel(cupola, "DashN%d" % i, Vector3(panel_x[i], 0.9, face_z), Vector3(0.94, 0.18, 0.46), Vector3(tilt, 0, 0))
		_add_dressing("Section_cupola", "DashScreenN%d" % i, Vector3(panel_x[i], 0.99, face_z + 0.13), Vector3(0.4, 0.02, 0.2), MATERIAL_STRIP)
	var half: float = SectionHull.tube_half_width(radius, 0.9) - 0.35
	for side: int in [-1, 1]:
		_add_dash_panel(cupola, "DashSide%d" % side, Vector3(half * float(side), 0.9, face_z + 0.9), Vector3(0.46, 0.18, 1.0), Vector3(0, 0, tilt * float(side)))
		_add_dressing("Section_cupola", "DashScreenSide%d" % side, Vector3(half * float(side) - 0.12 * float(side), 0.99, face_z + 0.9), Vector3(0.2, 0.02, 0.42), MATERIAL_STRIP)
	_add_dash_panel(cupola, "DashPedestal", Vector3(0.0, 0.44, face_z + 1.3), Vector3(0.7, 0.88, 0.46), Vector3.ZERO)
	_add_dressing("Section_cupola", "DashPedestalScreen", Vector3(0.0, 0.9, face_z + 1.55), Vector3(0.36, 0.02, 0.22), MATERIAL_STRIP)


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
	var room: StaticBody3D = pod.get_node_or_null(^"PodRoom") as StaticBody3D
	if room != null:
		# The pod's own dock mount: same menu as the hull plate (teardown), but it never
		# spawns a pod itself. `hardpoint_id` is wired in when the pod is stood up.
		room.set_script(load(SCRIPT_MODULE_MOUNT) as Script)
		room.set(&"spawns", false)
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
	_add_machine_sockets(pod, room)
	return pod


## Three machine sockets along the pod's far wall: the pads the operator fits machines into.
## Slot ids are wired when the pod is stood up ("<hardpoint>:<index>").
func _add_machine_sockets(pod: Node3D, room: StaticBody3D) -> void:
	for index: int in MACHINE_SOCKETS.size():
		var socket_z: float = float(MACHINE_SOCKETS[index])
		var socket: StaticBody3D = StaticBody3D.new()
		socket.name = "Socket_%d" % index
		socket.position = Vector3(POD_MAX.x - 0.85, 0.0, socket_z)
		socket.collision_layer = 2
		socket.collision_mask = 0
		socket.set_script(load(SCRIPT_MACHINE_SOCKET) as Script)
		pod.add_child(socket)
		var pad_mesh: BoxMesh = BoxMesh.new()
		pad_mesh.size = Vector3(0.9, 0.12, 0.9)
		var pad: MeshInstance3D = MeshInstance3D.new()
		pad.name = "Pad"
		pad.mesh = pad_mesh
		pad.position = Vector3(0.0, 0.06, 0.0)
		pad.material_override = _materials[MATERIAL_CONDUIT] as Material
		socket.add_child(pad)
		var pad_shape: BoxShape3D = BoxShape3D.new()
		pad_shape.size = Vector3(0.9, 0.3, 0.9)
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.name = "PadShape"
		shape.shape = pad_shape
		shape.position = Vector3(0.0, 0.18, 0.0)
		socket.add_child(shape)
	if room != null:
		room.set_meta(&"machine_sockets", MACHINE_SOCKETS.size())


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
	var outline: PackedVector2Array = spec.get("outline", HullProfile.rectangle_outline(spec["min"], spec["max"], spec["chamfer"]))
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


## Which interior the run generates: the constant above, or `--interior-style=<name>`.
func _interior_style() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--interior-style="):
			var override: String = arg.trim_prefix("--interior-style=")
			if override in ["flat", "tube"]:
				return override
			print("WARN: unknown interior style, keeping ", INTERIOR_STYLE, ": ", override)
	return INTERIOR_STYLE


## The M13.2 interior: one pressurised tunnel section per TubeLayout room, bow to stern, built
## as the shared cross-section swept along each section's span, so the chain is a train of
## chambers joined by short necks. Radii, lengths and hatch sizes come from TubeLayout, which
## stays the single dial; the cupola face carries the forward viewport, the airlock section
## carries the outer hatch, and the last walkable section closes the tunnel with a bulkhead.
func _build_tube_interior() -> void:
	var count: int = TubeLayout.sections().size()
	var last_walkable: int = -1
	for index: int in count:
		if TubeLayout.is_walkable(index):
			last_walkable = index
	for index: int in count:
		if not TubeLayout.is_walkable(index):
			continue
		var section: Dictionary = TubeLayout.sections()[index]
		var bounds: Vector2 = TubeLayout.span(index)
		var radius: float = float(section["radius"])
		var center_z: float = (bounds.x + bounds.y) * 0.5
		var ring: PackedVector2Array = SectionHull.tube_section(radius)
		var walls: Dictionary = _surface()
		var floors: Dictionary = _surface()
		var collision: Array[Vector3] = []
		var gaps: Array = []
		if TubeLayout.port_of(index) != &"":
			gaps.append({"edge": _tube_port_edge(index), "from": center_z - 0.5, "to": center_z + 0.5, "top": 2.1})
		if bool(section.get("outer_hatch", false)):
			gaps.append({"edge": SectionHull.TUBE_EDGE_PORT, "from": center_z - 0.5, "to": center_z + 0.5, "top": 2.0})
		_add_tunnel_band(walls, ring, bounds.x, bounds.y, gaps, collision, true, false)
		_add_tunnel_band(walls, ring, bounds.x, bounds.y, gaps, collision, false, false)
		_add_tunnel_deck(floors, ring, bounds.x, bounds.y, collision)
		if index == 0:
			for facing: Vector3 in [Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0)]:
				_add_tube_face(walls, ring, bounds.x, SectionHull.TUBE_WINDOW_MIN, SectionHull.TUBE_WINDOW_MAX, facing, collision, bounds.x)
		if index == last_walkable and index + 1 < count and not TubeLayout.is_walkable(index + 1):
			for facing: Vector3 in [Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0)]:
				_add_tube_face(walls, ring, bounds.y, Vector2.ZERO, Vector2.ZERO, facing, collision, bounds.y)
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Section_" + String(section["name"])
		for pipe_side: int in [-1, 1]:
			var pipe: MeshInstance3D = MeshInstance3D.new()
			pipe.name = "CeilingPipe%d" % pipe_side
			var pipe_mesh: BoxMesh = BoxMesh.new()
			pipe_mesh.size = Vector3(0.12, 0.12, maxf(bounds.y - bounds.x - 0.4, 0.4))
			pipe.mesh = pipe_mesh
			pipe.material_override = _materials[MATERIAL_CONDUIT] as Material
			pipe.position = Vector3(0.34 * float(pipe_side), SectionHull.TUBE_CEILING - 0.12, center_z)
			body.add_child(pipe)
		_root.add_child(body)
		body.add_child(_make_surface_node("Walls", walls, MATERIAL_XENON, collision))
		body.add_child(_make_surface_node("Floor", floors, MATERIAL_FLOOR, collision))
		body.add_child(_make_collision_node(collision))
	for index: int in count - 1:
		if not TubeLayout.has_hatch(index):
			continue
		if not TubeLayout.is_walkable(index) or not TubeLayout.is_walkable(index + 1):
			continue
		var z0: float = TubeLayout.span(index).y
		var z1: float = TubeLayout.span(index + 1).x
		var radius_a: float = float(TubeLayout.sections()[index]["radius"])
		var radius_b: float = float(TubeLayout.sections()[index + 1]["radius"])
		var neck_radius: float = minf(radius_a, radius_b)
		var ring_min: PackedVector2Array = SectionHull.tube_section(neck_radius)
		var walls: Dictionary = _surface()
		var floors: Dictionary = _surface()
		var collision: Array[Vector3] = []
		_add_tunnel_band(walls, ring_min, z0, z1, [], collision, true, false)
		_add_tunnel_band(walls, ring_min, z0, z1, [], collision, false, false)
		_add_tunnel_deck(floors, ring_min, z0, z1, collision)
		var mid: float = (z0 + z1) * 0.5
		var hatch_min: Vector2 = Vector2(-TubeLayout.HATCH_HALF_WIDTH, 0.0)
		var hatch_max: Vector2 = Vector2(TubeLayout.HATCH_HALF_WIDTH, TubeLayout.HATCH_HEIGHT)
		for facing: Vector3 in [Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0)]:
			_add_tube_face(walls, ring_min, mid, hatch_min, hatch_max, facing, collision, mid + TubeLayout.BULKHEAD * signf(facing.z))
		if neck_radius < radius_a - EPSILON:
			_add_washer(walls, SectionHull.tube_section(radius_a), ring_min, z0, Vector3(0.0, 0.0, -1.0), collision)
		if neck_radius < radius_b - EPSILON:
			_add_washer(walls, SectionHull.tube_section(radius_b), ring_min, z1, Vector3(0.0, 0.0, 1.0), collision)
		var joint: StaticBody3D = StaticBody3D.new()
		joint.name = "Joint_%s_%s" % [String(TubeLayout.sections()[index]["name"]), String(TubeLayout.sections()[index + 1]["name"])]
		_root.add_child(joint)
		joint.add_child(_make_surface_node("Walls", walls, MATERIAL_XENON, collision))
		joint.add_child(_make_surface_node("Floor", floors, MATERIAL_FLOOR, collision))
		joint.add_child(_make_collision_node(collision))


## One tunnel band swept along z at constant radius: the inner (or outer) surface of every
## facet of the cross-section, the canted facets sliced around side openings, and the wall
## rims closing both ends so the shell reads as a wall with thickness from any angle.
func _add_tunnel_band(surface: Dictionary, ring: PackedVector2Array, z0: float, z1: float, gaps: Array, collision: Array[Vector3], inward: bool, deck: bool = true) -> void:
	for edge_index: int in ring.size():
		if not deck and edge_index == 0:
			continue
		var a: Vector2 = ring[edge_index]
		var b: Vector2 = ring[(edge_index + 1) % ring.size()]
		var outward: Vector2 = _outward(a, b)
		var hint: Vector3 = Vector3(outward.x, outward.y, 0.0) * (-1.0 if inward else 1.0)
		var edge_gaps: Array = []
		for gap: Dictionary in gaps:
			if int(gap["edge"]) == edge_index:
				edge_gaps.append(gap)
		if edge_gaps.is_empty():
			_add_quad(surface, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1), hint, collision)
			_add_tunnel_rim(surface, a, b, z0, z1, outward, -1.0, collision)
			_add_tunnel_rim(surface, a, b, z1, z0, outward, 1.0, collision)
			continue
		var y_lo: float = minf(a.y, b.y)
		var y_hi: float = maxf(a.y, b.y)
		var cuts: Array[float] = [y_lo, y_hi]
		for gap: Dictionary in edge_gaps:
			for value: float in [float(gap.get("bottom", y_lo)), float(gap.get("top", y_hi))]:
				var cut: float = clampf(value, y_lo, y_hi)
				if cut > y_lo + EPSILON and cut < y_hi - EPSILON:
					cuts.append(cut)
		cuts.sort()
		for i: int in range(cuts.size() - 1):
			var band_lo: float = cuts[i]
			var band_hi: float = cuts[i + 1]
			if band_hi - band_lo <= EPSILON:
				continue
			var sliced: bool = false
			for gap: Dictionary in edge_gaps:
				var g_lo: float = clampf(float(gap.get("bottom", y_lo)), y_lo, y_hi)
				var g_hi: float = clampf(float(gap.get("top", y_hi)), y_lo, y_hi)
				if band_lo >= g_lo - EPSILON and band_hi <= g_hi + EPSILON:
					sliced = true
			var spans: Array = _z_spans(z0, z1, edge_gaps) if sliced else [Vector2(z0, z1)]
			var x_lo: float = _facet_x_at(a, b, band_lo)
			var x_hi: float = _facet_x_at(a, b, band_hi)
			for span: Vector2 in spans:
				_add_quad(
					surface,
					Vector3(x_lo, band_lo, span.x), Vector3(x_hi, band_hi, span.x),
					Vector3(x_hi, band_hi, span.y), Vector3(x_lo, band_lo, span.y),
					hint, collision
				)


## The facet's x at height y: a canted facet cuts between its two endpoints.
func _facet_x_at(a: Vector2, b: Vector2, y: float) -> float:
	if absf(b.y - a.y) <= EPSILON:
		return a.x
	return lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))


func _add_tunnel_rim(surface: Dictionary, a: Vector2, b: Vector2, z_near: float, z_far: float, outward: Vector2, facing: float, collision: Array[Vector3]) -> void:
	var hint: Vector3 = Vector3(0.0, 0.0, facing)
	_add_quad(
		surface,
		Vector3(a.x, a.y, z_near), Vector3(a.x + outward.x * WALL_THICKNESS, a.y + outward.y * WALL_THICKNESS, z_near),
		Vector3(b.x + outward.x * WALL_THICKNESS, b.y + outward.y * WALL_THICKNESS, z_near), Vector3(b.x, b.y, z_near),
		hint, collision
	)


func _add_tunnel_deck(surface: Dictionary, ring: PackedVector2Array, z0: float, z1: float, collision: Array[Vector3]) -> void:
	var half: float = maxf(ring[0].x * -1.0, ring[1].x)
	_add_quad(surface, Vector3(-half, 0.0, z0), Vector3(half, 0.0, z0), Vector3(half, 0.0, z1), Vector3(-half, 0.0, z1), Vector3.UP, collision)


## A cross-section face at constant z, closed except for a rectangular opening (the hatch in a
## bulkhead, the viewport in the cupola), with the opening's bore lining the wall's depth.
func _add_tube_face(surface: Dictionary, ring: PackedVector2Array, z: float, hole_min: Vector2, hole_max: Vector2, facing: Vector3, collision: Array[Vector3], z_bore: float) -> void:
	var deck: float = ring[1].x
	var wall_y: float = ring[2].y
	var wall: float = ring[2].x
	var ceiling: float = ring[3].x
	var ceiling_y: float = ring[3].y
	if hole_max.x - hole_min.x <= EPSILON or hole_max.y - hole_min.y <= EPSILON:
		_add_quad(surface, _xy(Vector2(-deck, 0.0), z), _xy(Vector2(deck, 0.0), z), _xy(Vector2(wall, wall_y), z), _xy(Vector2(-wall, wall_y), z), facing, collision)
		_add_quad(surface, _xy(Vector2(-wall, wall_y), z), _xy(Vector2(wall, wall_y), z), _xy(Vector2(ceiling, ceiling_y), z), _xy(Vector2(-ceiling, ceiling_y), z), facing, collision)
		return
	var lo: float = clampf(hole_min.y, 0.0, ceiling_y)
	var hi: float = clampf(hole_max.y, 0.0, ceiling_y)
	var w_lo: float = _ring_x_at(ring, lo)
	var w_hi: float = _ring_x_at(ring, hi)
	var hx0: float = clampf(hole_min.x, -w_lo, w_lo)
	var hx1: float = clampf(hole_max.x, -w_lo, w_lo)
	var levels: Array[float] = [lo]
	for point: Vector2 in ring:
		if point.y > lo + EPSILON and point.y < hi - EPSILON:
			levels.append(point.y)
	levels.append(hi)
	_add_quad(surface, _xy(Vector2(-deck, 0.0), z), _xy(Vector2(deck, 0.0), z), _xy(Vector2(w_lo, lo), z), _xy(Vector2(-w_lo, lo), z), facing, collision)
	_add_quad(surface, _xy(Vector2(-w_hi, hi), z), _xy(Vector2(w_hi, hi), z), _xy(Vector2(ceiling, ceiling_y), z), _xy(Vector2(-ceiling, ceiling_y), z), facing, collision)
	for i: int in levels.size() - 1:
		var y_a: float = levels[i]
		var y_b: float = levels[i + 1]
		var w_a: float = _ring_x_at(ring, y_a)
		var w_b: float = _ring_x_at(ring, y_b)
		_add_quad(surface, _xy(Vector2(-w_a, y_a), z), _xy(Vector2(hx0, y_a), z), _xy(Vector2(hx0, y_b), z), _xy(Vector2(-w_b, y_b), z), facing, collision)
		_add_quad(surface, _xy(Vector2(hx1, y_a), z), _xy(Vector2(w_a, y_a), z), _xy(Vector2(w_b, y_b), z), _xy(Vector2(hx1, y_b), z), facing, collision)
	if absf(z_bore - z) <= EPSILON:
		return
	_add_quad(surface, _xy(hole_min, z), _xy(Vector2(hole_max.x, hole_min.y), z), _xy(Vector2(hole_max.x, hole_min.y), z_bore), _xy(hole_min, z_bore), Vector3.UP, collision)
	_add_quad(surface, _xy(Vector2(hole_min.x, hole_max.y), z), _xy(hole_max, z), _xy(hole_max, z_bore), _xy(Vector2(hole_min.x, hole_max.y), z_bore), Vector3.DOWN, collision)
	_add_quad(surface, _xy(hole_min, z), _xy(hole_min, z_bore), _xy(Vector2(hole_min.x, hole_max.y), z_bore), _xy(Vector2(hole_min.x, hole_max.y), z), Vector3(-1.0, 0.0, 0.0), collision)
	_add_quad(surface, _xy(Vector2(hole_max.x, hole_min.y), z), _xy(hole_max, z), _xy(hole_max, z_bore), _xy(Vector2(hole_max.x, hole_min.y), z_bore), Vector3(1.0, 0.0, 0.0), collision)


## The cross-section's own wall half-width at height y, interpolated along the ring's canted
## facet - the face helpers must follow whatever ring they are handed.
func _ring_x_at(ring: PackedVector2Array, y: float) -> float:
	if y <= ring[2].y:
		return lerpf(ring[1].x, ring[2].x, clampf(y / maxf(ring[2].y, EPSILON), 0.0, 1.0))
	return lerpf(ring[2].x, ring[3].x, clampf((y - ring[2].y) / maxf(ring[3].y - ring[2].y, EPSILON), 0.0, 1.0))


## The annulus between two cross-sections at a joint, so a smaller neck never leaves the
## larger drum's end open.
func _add_washer(surface: Dictionary, outer: PackedVector2Array, inner: PackedVector2Array, z: float, facing: Vector3, collision: Array[Vector3]) -> void:
	for i: int in outer.size():
		var j: int = (i + 1) % outer.size()
		_add_quad(surface, _xy(outer[i], z), _xy(outer[j], z), _xy(inner[j], z), _xy(inner[i], z), facing, collision)


func _make_collision_node(faces: Array[Vector3]) -> CollisionShape3D:
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array(faces))
	var node: CollisionShape3D = CollisionShape3D.new()
	node.name = "ShellShape"
	node.shape = shape
	return node


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


## M13.1 lathed section shell (SectionHull owns the tables): one continuous chamfered-
## rectangle sweep from the bow window face to the stern band face, the airlock and dock
## doorways cut from its west/east facets, the framed prow over the cockpit window, flange
## collars at the interior joints, rib rings, the stern tank cluster and solar arrays.
## Collision is generated from the same triangles.
func _build_hull_exterior() -> void:
	var hull: StaticBody3D = StaticBody3D.new()
	hull.name = "HullExterior"
	_root.add_child(hull)
	var shell: Dictionary = _surface()
	var decks: Dictionary = _surface()
	var collision: Array[Vector3] = []
	if _interior_style() == "tube":
		_build_tube_hull(hull, shell, decks, collision)
	else:
		_build_flat_hull(hull, shell, decks, collision)
	hull.add_child(_make_surface_node("Hull", shell, MATERIAL_XENON, collision))
	hull.add_child(_make_surface_node("Deck", decks, MATERIAL_FLOOR, collision))
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array(collision))
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "ShellShape"
	shape_node.shape = shape
	hull.add_child(shape_node)


## The flat hull (M13.1): the wide chamfered-rectangle sweep with its airlock sleeve, prow,
## flange and rib collars, stern tanks, arrays and the EVA fittings.
func _build_flat_hull(hull: StaticBody3D, shell: Dictionary, decks: Dictionary, collision: Array[Vector3]) -> void:
	var sections: Array[Dictionary] = SectionHull.sections()
	var outline: PackedVector2Array = SectionHull.outline(sections[0])
	var z_bow: float = float(sections[0]["z0"])
	var z_stern: float = float(sections[2]["z1"])
	_add_shell_sweep(shell, outline, z_bow, z_stern, _shell_openings(), collision)
	_add_framed_face(shell, sections[0], SectionHull.BOW_WINDOW_MIN, SectionHull.BOW_WINDOW_MAX, z_bow, float(sections[1]["z0"]), collision)
	_add_airlock_sleeve(shell, collision)
	_add_prow(shell, collision)
	_add_xy_fan(shell, outline, z_stern, Vector3(0.0, 0.0, 1.0), collision)
	for z: float in SectionHull.FLANGES_Z:
		_add_collar(shell, SectionHull.collar_outline(sections[1], SectionHull.FLANGE_OFFSET), outline, z - SectionHull.FLANGE_HALF, z + SectionHull.FLANGE_HALF, collision)
	for z: float in SectionHull.RIBS_Z:
		_add_collar(shell, SectionHull.collar_outline(sections[1], SectionHull.RIB_OFFSET), outline, z - SectionHull.RIB_HALF, z + SectionHull.RIB_HALF, collision)
	_add_tank_cluster(shell, decks, collision)
	_add_arrays(hull)
	_add_catwalk(decks, shell, collision)
	_add_aft_deck(decks, shell, collision)
	_add_ramp(decks, shell, collision)
	_add_railings(hull)
	_add_dock_plates(hull, decks, collision)
	_add_eva_anchors(hull)


## The tube hull (M13.2): one drum per TubeLayout section. A drum is the interior's own
## cross-section swept at radius plus TUBE_BAND, so the shell wraps the rooms; the joints are
## necks at the narrower radius, each closed by a washer where the radius steps and girdled
## by a flange collar over the step. The bow is a cowl face with the viewport bore, the stern
## a solid cap, and the dock doorways and airlock hatch open through the drum walls. The tank
## cluster and arrays keep their M13.1 mounts aft of the last drum.
func _build_tube_hull(hull: StaticBody3D, shell: Dictionary, decks: Dictionary, collision: Array[Vector3]) -> void:
	var drums: Array[Dictionary] = SectionHull.tube_drums()
	var joints: Array[Dictionary] = SectionHull.tube_joints()
	for index: int in drums.size():
		var drum: Dictionary = drums[index]
		var radius: float = float(drum["radius"])
		var center_z: float = (float(drum["z0"]) + float(drum["z1"])) * 0.5
		var z0: float = float(drum["z0"])
		var z1: float = float(drum["z1"])
		for joint: Dictionary in joints:
			if absf(float(joint["z"]) - z0) <= SectionHull.TUBE_STEP:
				z0 += SectionHull.TUBE_STEP * 0.5
			elif absf(float(joint["z"]) - z1) <= SectionHull.TUBE_STEP:
				z1 -= SectionHull.TUBE_STEP * 0.5
		var gaps: Array = []
		if TubeLayout.port_of(index) != &"":
			gaps.append({"edge": _tube_port_edge(index), "from": center_z - 0.5, "to": center_z + 0.5, "top": 2.1})
		if bool(TubeLayout.sections()[index].get("outer_hatch", false)):
			gaps.append({"edge": SectionHull.TUBE_EDGE_PORT, "from": center_z - 0.5, "to": center_z + 0.5, "top": 2.0})
		_add_tunnel_band(shell, SectionHull.tube_drum_section(radius), z0, z1, gaps, collision, false)
		_add_tunnel_band(shell, SectionHull.tube_drum_section(radius), z0, z1, gaps, collision, true)
	if drums.is_empty():
		return
	var first: Dictionary = drums[0]
	var last: Dictionary = drums[drums.size() - 1]
	for facing: Vector3 in [Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0)]:
		_add_tube_face(shell, SectionHull.tube_drum_section(float(last["radius"])), float(last["z1"]), Vector2.ZERO, Vector2.ZERO, facing, collision, float(last["z1"]))
		_add_tube_face(shell, SectionHull.tube_drum_section(float(first["radius"])), float(first["z0"]) - SectionHull.PROW_DEPTH, SectionHull.TUBE_WINDOW_MIN, SectionHull.TUBE_WINDOW_MAX, facing, collision, float(first["z0"]))
	for index: int in drums.size() - 1:
		if not TubeLayout.has_hatch(index) or not TubeLayout.is_walkable(index) or not TubeLayout.is_walkable(index + 1):
			continue
		var z0: float = TubeLayout.span(index).y
		var z1: float = TubeLayout.span(index + 1).x
		_add_tunnel_band(shell, SectionHull.tube_drum_section(_tube_neck_radius(index)), z0, z1, [], collision, false)
		_add_tunnel_band(shell, SectionHull.tube_drum_section(_tube_neck_radius(index)), z0, z1, [], collision, true)
		if _tube_neck_radius(index) < float(drums[index]["radius"]) - EPSILON:
			_add_washer(shell, SectionHull.tube_drum_section(float(drums[index]["radius"])), SectionHull.tube_drum_section(_tube_neck_radius(index)), z0, Vector3(0.0, 0.0, 1.0), collision)
		if _tube_neck_radius(index) < float(drums[index + 1]["radius"]) - EPSILON:
			_add_washer(shell, SectionHull.tube_drum_section(float(drums[index + 1]["radius"])), SectionHull.tube_drum_section(_tube_neck_radius(index)), z1, Vector3(0.0, 0.0, -1.0), collision)
	for joint: Dictionary in joints:
		var joint_z: float = float(joint["z"])
		var collar_radius: float = maxf(float(joint["radius_a"]), float(joint["radius_b"]))
		var half_step: float = SectionHull.TUBE_STEP * 0.5
		_add_tunnel_band(shell, SectionHull.tube_collar_section(collar_radius), joint_z - half_step, joint_z + half_step, [], collision, false)
		_add_tunnel_band(shell, SectionHull.tube_collar_section(collar_radius), joint_z - half_step, joint_z + half_step, [], collision, true)
		_add_washer(shell, SectionHull.tube_collar_section(collar_radius), SectionHull.tube_drum_section(float(joint["radius_a"])), joint_z - half_step, Vector3(0.0, 0.0, -1.0), collision)
		_add_washer(shell, SectionHull.tube_collar_section(collar_radius), SectionHull.tube_drum_section(float(joint["radius_b"])), joint_z + half_step, Vector3(0.0, 0.0, 1.0), collision)
	_add_tank_cluster(shell, decks, collision)
	_add_tube_arrays(hull)
	_build_tube_fittings(hull, decks, collision)


## The hull radius of the neck bridging joint `index`: the interior's narrower section plus
## the band.
func _tube_neck_radius(index: int) -> float:
	return minf(
		float(TubeLayout.sections()[index]["radius"]),
		float(TubeLayout.sections()[index + 1]["radius"])
	)


## The tube hull's fittings: a mount plate, hardpoint marker and sill on every docked
## section, the EVA platform with its railings and tether hardware outside the airlock, and
## a cabin light in every room so the chain is lit without main.tscn's flat-layout lights.
func _build_tube_fittings(hull: StaticBody3D, decks: Dictionary, collision: Array[Vector3]) -> void:
	for index: int in TubeLayout.sections().size():
		var center_z: float = (TubeLayout.span(index).x + TubeLayout.span(index).y) * 0.5
		if TubeLayout.is_walkable(index):
			_add_tube_cabin_light(hull, center_z)
		if TubeLayout.port_of(index) == &"":
			continue
		var id: String = String(TubeLayout.port_of(index)).trim_prefix("hp_")
		var outward: float = 1.0
		for dock: Dictionary in DOCKS:
			if String(dock["id"]) == id:
				outward = float(dock["outward"])
		var radius: float = float(TubeLayout.sections()[index]["radius"]) + SectionHull.TUBE_BAND
		_add_tube_dock_mount(hull, decks, collision, id, outward, radius * outward, center_z)
	if TubeLayout.index_of("airlock") >= 0:
		_add_tube_eva_deck(hull, decks, collision)
	_add_tube_throats(hull)


## Every opening through the inner shell gets a sleeve out to whatever closes it - the dock
## plate's inner face, or the EVA hatch leaf - so a port is a tunnel through the shell void
## instead of a wall hole looking onto it, and the pod passage keeps a floor.
func _add_tube_throats(hull: StaticBody3D) -> void:
	var walls: Dictionary = _surface()
	var floors: Dictionary = _surface()
	var collision: Array[Vector3] = []
	for index: int in TubeLayout.sections().size():
		if not TubeLayout.is_walkable(index):
			continue
		var port: StringName = TubeLayout.port_of(index)
		var hatched: bool = bool(TubeLayout.sections()[index].get("outer_hatch", false))
		if port == &"" and not hatched:
			continue
		var radius: float = float(TubeLayout.sections()[index]["radius"])
		var center_z: float = (TubeLayout.span(index).x + TubeLayout.span(index).y) * 0.5
		if port != &"":
			var id: String = String(port).trim_prefix("hp_")
			for dock: Dictionary in DOCKS:
				if String(dock["id"]) == id:
					var outward: float = float(dock["outward"])
					_add_tube_throat(walls, floors, collision, radius, center_z, outward, outward * (radius + SectionHull.TUBE_BAND))
		if hatched:
			_add_tube_throat(walls, floors, collision, radius, center_z, -1.0, -radius)
	hull.add_child(_make_surface_node("ThroatWalls", walls, MATERIAL_XENON, collision))
	hull.add_child(_make_surface_node("ThroatFloors", floors, MATERIAL_FLOOR, []))
	hull.add_child(_make_collision_node(collision))


## One throat: floor at deck level, lid under the canted facet's top rim, side walls in the
## opening's own z planes, all spanning from the inner facet out to the closing face (the
## drum face for a dock plate, the hatch leaf's inner face for the airlock).
func _add_tube_throat(walls: Dictionary, floors: Dictionary, collision: Array[Vector3], radius: float, center_z: float, outward: float, out_x: float) -> void:
	var foot: float = outward * SectionHull.TUBE_DECK_HALF * radius
	var top: float = outward * SectionHull.TUBE_WALL_HALF * radius
	var lid: float = SectionHull.TUBE_WALL_TOP
	var z_lo: float = center_z - DOCK_DOOR_HALF
	var z_hi: float = center_z + DOCK_DOOR_HALF
	for hint: Vector3 in [Vector3.UP, Vector3.DOWN]:
		_add_quad(floors, Vector3(foot, 0.0, z_lo), Vector3(foot, 0.0, z_hi), Vector3(out_x, 0.0, z_hi), Vector3(out_x, 0.0, z_lo), hint, collision)
	for hint: Vector3 in [Vector3.DOWN, Vector3.UP]:
		_add_quad(walls, Vector3(top, lid, z_lo), Vector3(top, lid, z_hi), Vector3(out_x, lid, z_hi), Vector3(out_x, lid, z_lo), hint, collision)
	for z_side: float in [z_lo, z_hi]:
		for hint: Vector3 in [Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0)]:
			_add_quad(walls, Vector3(foot, 0.0, z_side), Vector3(top, lid, z_side), Vector3(out_x, lid, z_side), Vector3(out_x, 0.0, z_side), hint, collision)


func _add_tube_cabin_light(hull: StaticBody3D, center_z: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "CabinLight%.1f" % center_z
	light.position = Vector3(0.0, 2.15, center_z)
	light.light_color = Color(1.0, 0.85, 0.65, 1.0)
	light.light_energy = 1.2
	light.omni_range = 5.5
	light.shadow_enabled = true
	hull.add_child(light)


## A dock mount on its drum, under the same contract as the flat hull's: the plate is the
## EVA mount the build menu stands pods on, the marker is the hardpoint, and the sill floors
## the slot between the drum face and the standing pod's near wall.
func _add_tube_dock_mount(hull: StaticBody3D, decks: Dictionary, collision: Array[Vector3], id: String, outward: float, face: float, z: float) -> void:
	var y_min: float = -0.25
	var y_max: float = 2.15
	var plate: StaticBody3D = StaticBody3D.new()
	plate.name = "DockPlate_" + id
	plate.position = Vector3(face + outward * DOCK_PLATE_THICKNESS * 0.5, (y_min + y_max) * 0.5, z)
	_join_group(plate, &"dock_plate")
	plate.set_meta(&"hardpoint_id", StringName("hp_" + id))
	plate.set_script(load(SCRIPT_MODULE_MOUNT) as Script)
	plate.set(&"hardpoint_id", StringName("hp_" + id))
	hull.add_child(plate)
	var size: Vector3 = Vector3(DOCK_PLATE_THICKNESS, y_max - y_min, DOCK_DOOR_HALF * 2.0)
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
	marker.position = Vector3(face + outward * (DOCK_PLATE_THICKNESS + 0.1), 1.4, z)
	_join_group(marker, &"hardpoint")
	marker.set_meta(&"hardpoint_id", StringName("hp_" + id))
	hull.add_child(marker)
	var x_in: float = face
	var x_out: float = face - outward * DOCK_SILL_DEPTH
	_add_hexahedron(decks, [
		Vector3(x_in, CATWALK_BOTTOM, z - DOCK_DOOR_HALF),
		Vector3(x_out, CATWALK_BOTTOM, z - DOCK_DOOR_HALF),
		Vector3(x_out, CATWALK_BOTTOM, z + DOCK_DOOR_HALF),
		Vector3(x_in, CATWALK_BOTTOM, z + DOCK_DOOR_HALF),
		Vector3(x_in, CATWALK_TOP, z - DOCK_DOOR_HALF),
		Vector3(x_out, CATWALK_TOP, z - DOCK_DOOR_HALF),
		Vector3(x_out, CATWALK_TOP, z + DOCK_DOOR_HALF),
		Vector3(x_in, CATWALK_TOP, z + DOCK_DOOR_HALF),
	], collision)


## The EVA platform outside the airlock's outer hatch: a deck at cabin level, railings on
## three sides, the tether anchors and zone, so EVA works off the slim hull the same way it
## worked off the flat one.
func _add_tube_eva_deck(hull: StaticBody3D, decks: Dictionary, collision: Array[Vector3]) -> void:
	var airlock: int = TubeLayout.index_of("airlock")
	var bounds: Vector2 = TubeLayout.span(airlock)
	var center_z: float = (bounds.x + bounds.y) * 0.5
	var face: float = -(float(TubeLayout.sections()[airlock]["radius"]) + SectionHull.TUBE_BAND)
	var outer_x: float = face - 3.0
	var half_z: float = 1.7
	_add_hexahedron(decks, [
		Vector3(face, CATWALK_BOTTOM, center_z - half_z),
		Vector3(outer_x, CATWALK_BOTTOM, center_z - half_z),
		Vector3(outer_x, CATWALK_BOTTOM, center_z + half_z),
		Vector3(face, CATWALK_BOTTOM, center_z + half_z),
		Vector3(face, CATWALK_TOP, center_z - half_z),
		Vector3(outer_x, CATWALK_TOP, center_z - half_z),
		Vector3(outer_x, CATWALK_TOP, center_z + half_z),
		Vector3(face, CATWALK_TOP, center_z + half_z),
	], collision)
	var bars: Array[Array] = [
		[Vector3(outer_x, 0.95, center_z), Vector3(0.08, 0.08, half_z * 2.0)],
		[Vector3((face + outer_x) * 0.5, 0.95, center_z - half_z), Vector3(face - outer_x, 0.08, 0.08)],
		[Vector3((face + outer_x) * 0.5, 0.95, center_z + half_z), Vector3(face - outer_x, 0.08, 0.08)],
	]
	for i: int in bars.size():
		var bar: Array = bars[i]
		var rail: MeshInstance3D = MeshInstance3D.new()
		rail.name = "TubeRailing%d" % i
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = bar[1]
		rail.mesh = mesh
		rail.material_override = _materials[MATERIAL_CONDUIT] as Material
		rail.position = bar[0]
		hull.add_child(rail)
	var anchor_positions: Array[Vector3] = [
		Vector3(outer_x + 0.5, 0.25, center_z - half_z + 0.3),
		Vector3(outer_x + 0.5, 0.25, center_z + half_z - 0.3),
		Vector3(-1.0, 0.25, 8.6),
		Vector3(2.7, 0.25, -19.6),
	]
	for i: int in anchor_positions.size():
		var anchor: Node3D = Node3D.new()
		anchor.name = "TetherAnchor%d" % i
		anchor.position = anchor_positions[i]
		anchor.set_script(load(SCRIPT_TETHER_ANCHOR) as Script)
		hull.add_child(anchor)
	var zone: Area3D = Area3D.new()
	zone.name = "TetherZone"
	zone.position = Vector3((face + outer_x) * 0.5, 1.2, center_z)
	zone.set_script(load(SCRIPT_TETHER_ZONE) as Script)
	hull.add_child(zone)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(absf(face - outer_x), 2.4, half_z * 2.0)
	var zone_shape: CollisionShape3D = CollisionShape3D.new()
	zone_shape.name = "Shape"
	zone_shape.shape = box
	zone.add_child(zone_shape)


## The cross-section facet a section's dock port opens through: starboard for an east dock,
## portside for a west one, matching the flat docks' sides.
func _tube_port_edge(index: int) -> int:
	var id: String = String(TubeLayout.port_of(index)).trim_prefix("hp_")
	for dock: Dictionary in DOCKS:
		if String(dock["id"]) == id:
			return SectionHull.TUBE_EDGE_STARBOARD if float(dock["outward"]) > 0.0 else SectionHull.TUBE_EDGE_PORT
	return SectionHull.TUBE_EDGE_STARBOARD


## Doorway openings in the shell's west/east facets: the airlock's outer door plus every
## dock, each spanning deck level to the door head.
func _shell_openings() -> Array:
	var openings: Array = [{"edge": SHELL_WEST_EDGE, "from": AIRLOCK_GAP_FROM, "to": AIRLOCK_GAP_TO}]
	for dock: Dictionary in DOCKS:
		openings.append({
			"edge": int(dock["hull_edge"]),
			"from": float(dock["z"]) - DOCK_DOOR_HALF,
			"to": float(dock["z"]) + DOCK_DOOR_HALF,
		})
	return openings


## The continuous shell surface: each facet of the cross-section swept bow..stern, the
## vertical facets sliced around the doorway openings.
func _add_shell_sweep(surface: Dictionary, ring: PackedVector2Array, z0: float, z1: float, openings: Array, collision: Array[Vector3]) -> void:
	for edge_index: int in ring.size():
		var a: Vector2 = ring[edge_index]
		var b: Vector2 = ring[(edge_index + 1) % ring.size()]
		var outward: Vector2 = _outward(a, b)
		var hint: Vector3 = Vector3(outward.x, outward.y, 0.0)
		var edge_openings: Array = []
		for opening: Dictionary in openings:
			if int(opening["edge"]) == edge_index:
				edge_openings.append(opening)
		if edge_openings.is_empty():
			_add_quad(surface, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1), hint, collision)
			continue
		var y_lo: float = minf(a.y, b.y)
		var y_hi: float = maxf(a.y, b.y)
		var bands: Array = [[y_lo, 0.0, false], [0.0, DOOR_TOP, true], [DOOR_TOP, y_hi, false]]
		for band: Array in bands:
			var band_lo: float = float(band[0])
			var band_hi: float = float(band[1])
			if band_hi - band_lo <= EPSILON:
				continue
			var spans: Array = [Vector2(z0, z1)] if not bool(band[2]) else _z_spans(z0, z1, edge_openings)
			for span: Vector2 in spans:
				_add_quad(
					surface,
					Vector3(a.x, band_lo, span.x), Vector3(a.x, band_hi, span.x),
					Vector3(a.x, band_hi, span.y), Vector3(a.x, band_lo, span.y),
					hint, collision
				)


func _z_spans(z0: float, z1: float, openings: Array) -> Array:
	var spans: Array = [Vector2(z0, z1)]
	for opening: Dictionary in openings:
		var cut: Vector2 = Vector2(
			minf(float(opening["from"]), float(opening["to"])),
			maxf(float(opening["from"]), float(opening["to"]))
		)
		var result: Array = []
		for span: Vector2 in spans:
			if cut.y <= span.x + EPSILON or cut.x >= span.y - EPSILON:
				result.append(span)
				continue
			if cut.x > span.x + EPSILON:
				result.append(Vector2(span.x, cut.x))
			if cut.y < span.y - EPSILON:
				result.append(Vector2(cut.y, span.y))
		spans = result
	return spans


## The airlock's outer doorway crosses the void between the lock's wall and the shell:
## floor, side walls and a lintel keep the passage solid and closed to sightlines.
func _add_airlock_sleeve(surface: Dictionary, collision: Array[Vector3]) -> void:
	var x_inner: float = SectionHull.CABIN_MIN.x
	var x_outer: float = _shell_face_for(-1.0)
	_add_quad(surface, Vector3(x_inner, 0.0, AIRLOCK_GAP_FROM), Vector3(x_outer, 0.0, AIRLOCK_GAP_FROM), Vector3(x_outer, 0.0, AIRLOCK_GAP_TO), Vector3(x_inner, 0.0, AIRLOCK_GAP_TO), Vector3.UP, collision)
	_add_quad(surface, Vector3(x_inner, 0.0, AIRLOCK_GAP_FROM), Vector3(x_inner, DOOR_TOP, AIRLOCK_GAP_FROM), Vector3(x_outer, DOOR_TOP, AIRLOCK_GAP_FROM), Vector3(x_outer, 0.0, AIRLOCK_GAP_FROM), Vector3(0.0, 0.0, 1.0), collision)
	_add_quad(surface, Vector3(x_inner, 0.0, AIRLOCK_GAP_TO), Vector3(x_outer, 0.0, AIRLOCK_GAP_TO), Vector3(x_outer, DOOR_TOP, AIRLOCK_GAP_TO), Vector3(x_inner, DOOR_TOP, AIRLOCK_GAP_TO), Vector3(0.0, 0.0, -1.0), collision)
	_add_quad(surface, Vector3(x_inner, DOOR_TOP, AIRLOCK_GAP_FROM), Vector3(x_inner, DOOR_TOP, AIRLOCK_GAP_TO), Vector3(x_outer, DOOR_TOP, AIRLOCK_GAP_TO), Vector3(x_outer, DOOR_TOP, AIRLOCK_GAP_FROM), Vector3.DOWN, collision)


## The faceted prow: taper rings from the bow face to the framed nose viewport,
## double-walled so the cockpit window looks into a closed cowl, never through culled
## backfaces.
func _add_prow(surface: Dictionary, collision: Array[Vector3]) -> void:
	var rings: Array[PackedVector2Array] = []
	var z_s: Array[float] = []
	for ring: Dictionary in SectionHull.PROW_RINGS:
		rings.append(SectionHull.outline(ring))
		z_s.append(float(ring["z"]))
	for i: int in rings.size() - 1:
		_add_loft_band(surface, rings[i], rings[i + 1], z_s[i], z_s[i + 1], collision)
	var nose: Dictionary = SectionHull.PROW_RINGS[rings.size() - 1]
	_add_framed_face(surface, nose, nose["window_min"], nose["window_max"], z_s[z_s.size() - 1], z_s[z_s.size() - 2], collision)


func _add_loft_band(surface: Dictionary, ring_a: PackedVector2Array, ring_b: PackedVector2Array, z_a: float, z_b: float, collision: Array[Vector3]) -> void:
	var inward: Array[Vector3] = []
	for edge_index: int in ring_a.size():
		var a0: Vector2 = ring_a[edge_index]
		var b0: Vector2 = ring_a[(edge_index + 1) % ring_a.size()]
		var a1: Vector2 = ring_b[edge_index]
		var b1: Vector2 = ring_b[(edge_index + 1) % ring_b.size()]
		var hint: Vector3 = _ring_edge_hint(ring_a, ring_b, edge_index, z_a, z_b)
		_add_quad(surface, Vector3(a0.x, a0.y, z_a), Vector3(b0.x, b0.y, z_a), Vector3(b1.x, b1.y, z_b), Vector3(a1.x, a1.y, z_b), hint, collision)
		_add_quad(surface, Vector3(a0.x, a0.y, z_a), Vector3(a1.x, a1.y, z_b), Vector3(b1.x, b1.y, z_b), Vector3(b0.x, b0.y, z_a), -hint, inward)


func _ring_edge_hint(ring_a: PackedVector2Array, ring_b: PackedVector2Array, edge_index: int, z_a: float, z_b: float) -> Vector3:
	var a0: Vector2 = ring_a[edge_index]
	var b0: Vector2 = ring_a[(edge_index + 1) % ring_a.size()]
	var a1: Vector2 = ring_b[edge_index]
	var b1: Vector2 = ring_b[(edge_index + 1) % ring_b.size()]
	var mid: Vector2 = (a0 + b0 + a1 + b1) * 0.25
	var center_a: Vector2 = Vector2.ZERO
	var center_b: Vector2 = Vector2.ZERO
	for i: int in ring_a.size():
		center_a += ring_a[i]
		center_b += ring_b[i]
	center_a /= float(ring_a.size())
	center_b /= float(ring_b.size())
	var hint: Vector2 = mid - center_a.lerp(center_b, 0.5)
	if hint.length() <= EPSILON:
		return Vector3(1.0, 0.0, 0.0)
	return Vector3(hint.x, hint.y, 0.0).normalized()


## A chamfered ring closed by a framed window: four bands and four corner regions leave
## the window rect open. Emitted facing both ways (the cowl interior stays visible
## through the cockpit window), with sill/lintel/jamb faces lining the bore back to
## `z_bore`.
func _add_framed_face(surface: Dictionary, ring: Dictionary, window_min: Vector2, window_max: Vector2, z: float, z_bore: float, collision: Array[Vector3]) -> void:
	var ring_min: Vector2 = ring["min"]
	var ring_max: Vector2 = ring["max"]
	var cut: float = float(ring.get("cut", 0.0))
	var inward: Array[Vector3] = []
	for region: Array in _framed_face_regions(ring_min, ring_max, cut, window_min, window_max):
		var points: Array = region
		if points.size() == 4:
			_add_quad(surface, _xy(points[0], z), _xy(points[1], z), _xy(points[2], z), _xy(points[3], z), Vector3(0.0, 0.0, -1.0), collision)
			_add_quad(surface, _xy(points[0], z), _xy(points[3], z), _xy(points[2], z), _xy(points[1], z), Vector3(0.0, 0.0, 1.0), inward)
		else:
			_add_tri(surface, _xy(points[0], z), _xy(points[1], z), _xy(points[2], z), Vector3(0.0, 0.0, -1.0), collision)
			_add_tri(surface, _xy(points[0], z), _xy(points[2], z), _xy(points[1], z), Vector3(0.0, 0.0, 1.0), inward)
	_add_quad(surface, _xy(window_min, z), _xy(Vector2(window_max.x, window_min.y), z), _xy(Vector2(window_max.x, window_min.y), z_bore), _xy(window_min, z_bore), Vector3.UP, collision)
	_add_quad(surface, _xy(Vector2(window_min.x, window_max.y), z), _xy(window_max, z), _xy(window_max, z_bore), _xy(Vector2(window_min.x, window_max.y), z_bore), Vector3.DOWN, collision)
	_add_quad(surface, _xy(window_min, z), _xy(window_min, z_bore), _xy(Vector2(window_min.x, window_max.y), z_bore), _xy(Vector2(window_min.x, window_max.y), z), Vector3(-1.0, 0.0, 0.0), collision)
	_add_quad(surface, _xy(Vector2(window_max.x, window_min.y), z), _xy(Vector2(window_max.x, window_max.y), z), _xy(Vector2(window_max.x, window_max.y), z_bore), _xy(Vector2(window_max.x, window_min.y), z_bore), Vector3(1.0, 0.0, 0.0), collision)


func _xy(point: Vector2, z: float) -> Vector3:
	return Vector3(point.x, point.y, z)


## The closed regions of a chamfered ring minus a window rect: four bands whose outer
## edges land exactly on the ring's straight edges, plus corner regions (quads, or
## triangles where the window edge meets the chamfer junction).
func _framed_face_regions(ring_min: Vector2, ring_max: Vector2, cut: float, window_min: Vector2, window_max: Vector2) -> Array:
	var regions: Array = []
	regions.append([Vector2(ring_min.x + cut, window_max.y), Vector2(ring_max.x - cut, window_max.y), Vector2(ring_max.x - cut, ring_max.y), Vector2(ring_min.x + cut, ring_max.y)])
	regions.append([Vector2(ring_min.x + cut, ring_min.y), Vector2(ring_max.x - cut, ring_min.y), Vector2(ring_max.x - cut, window_min.y), Vector2(ring_min.x + cut, window_min.y)])
	regions.append([Vector2(ring_min.x, window_min.y), Vector2(window_min.x, window_min.y), Vector2(window_min.x, window_max.y), Vector2(ring_min.x, window_max.y)])
	regions.append([Vector2(window_max.x, window_min.y), Vector2(ring_max.x, window_min.y), Vector2(ring_max.x, window_max.y), Vector2(window_max.x, window_max.y)])
	if absf(window_max.y - (ring_max.y - cut)) <= EPSILON:
		regions.append([Vector2(ring_min.x, window_max.y), Vector2(ring_min.x + cut, ring_max.y), Vector2(ring_min.x + cut, window_max.y)])
		regions.append([Vector2(ring_max.x - cut, ring_max.y), Vector2(ring_max.x, window_max.y), Vector2(ring_max.x - cut, window_max.y)])
	else:
		regions.append([Vector2(ring_min.x, window_max.y), Vector2(ring_min.x, ring_max.y - cut), Vector2(ring_min.x + cut, ring_max.y), Vector2(ring_min.x + cut, window_max.y)])
		regions.append([Vector2(ring_max.x - cut, ring_max.y), Vector2(ring_max.x, ring_max.y - cut), Vector2(ring_max.x, window_max.y), Vector2(ring_max.x - cut, window_max.y)])
	if absf(window_min.y - (ring_min.y + cut)) <= EPSILON:
		regions.append([Vector2(ring_min.x, window_min.y), Vector2(ring_min.x + cut, ring_min.y), Vector2(ring_min.x + cut, window_min.y)])
		regions.append([Vector2(ring_max.x, window_min.y), Vector2(ring_max.x - cut, window_min.y), Vector2(ring_max.x - cut, ring_min.y)])
	else:
		regions.append([Vector2(ring_min.x, window_min.y), Vector2(ring_min.x, ring_min.y + cut), Vector2(ring_min.x + cut, ring_min.y), Vector2(ring_min.x + cut, window_min.y)])
		regions.append([Vector2(ring_max.x - cut, ring_min.y), Vector2(ring_max.x, ring_min.y + cut), Vector2(ring_max.x, window_min.y), Vector2(ring_max.x - cut, window_min.y)])
	return regions


## A fan cap over a chamfered ring in the XY plane at constant z.
func _add_xy_fan(surface: Dictionary, ring: PackedVector2Array, z: float, facing: Vector3, collision: Array[Vector3]) -> void:
	for i: int in range(1, ring.size() - 1):
		_add_tri(surface, _xy(ring[0], z), _xy(ring[i], z), _xy(ring[i + 1], z), facing, collision)


## A ring collar girdling the shell (flanges, ribs, tank ribs): outer facets plus closing
## annuli at its ends. The top facet is skipped where the collar is flush with the roof
## walk so it never z-fights the shell's own roof.
func _add_collar(surface: Dictionary, collar: PackedVector2Array, section: PackedVector2Array, z0: float, z1: float, collision: Array[Vector3]) -> void:
	var top_y: float = section[4].y
	for edge_index: int in collar.size():
		var a: Vector2 = collar[edge_index]
		var b: Vector2 = collar[(edge_index + 1) % collar.size()]
		if absf(a.y - top_y) <= EPSILON and absf(b.y - top_y) <= EPSILON:
			continue
		var outward: Vector2 = _outward(a, b)
		_add_quad(surface, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1), Vector3(outward.x, outward.y, 0.0), collision)
	for edge_index: int in section.size():
		var i0: Vector2 = section[edge_index]
		var i1: Vector2 = section[(edge_index + 1) % section.size()]
		var o0: Vector2 = collar[edge_index]
		var o1: Vector2 = collar[(edge_index + 1) % collar.size()]
		_add_quad(surface, _xy(i0, z0), _xy(i1, z0), _xy(o1, z0), _xy(o0, z0), Vector3(0.0, 0.0, -1.0), collision)
		_add_quad(surface, _xy(i0, z1), _xy(i1, z1), _xy(o1, z1), _xy(o0, z1), Vector3(0.0, 0.0, 1.0), collision)


## The stern propellant cluster: two ribbed drums on pylons over the aft deck, clear of
## the roof ramp channel.
func _add_tank_cluster(shell: Dictionary, decks: Dictionary, collision: Array[Vector3]) -> void:
	_add_drum(shell, SectionHull.TANK_A, collision)
	_add_drum(shell, SectionHull.TANK_B, collision)
	var drum: PackedVector2Array = SectionHull.outline(SectionHull.TANK_A)
	for z: float in SectionHull.TANK_RIBS_Z:
		var rib: PackedVector2Array = SectionHull.collar_outline(SectionHull.TANK_A, SectionHull.TANK_RIB_OFFSET)
		_add_collar(shell, rib, drum, z - SectionHull.TANK_RIB_HALF, z + SectionHull.TANK_RIB_HALF, collision)
	for pylon: Dictionary in SectionHull.TANK_PYLONS:
		var x0: float = float(pylon["x0"])
		var x1: float = float(pylon["x1"])
		var y0: float = float(pylon["y0"])
		var y1: float = float(pylon["y1"])
		var z0: float = float(pylon["z0"])
		var z1: float = float(pylon["z1"])
		_add_hexahedron(decks, [
			Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1),
			Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1),
		], collision)


func _add_drum(surface: Dictionary, tank: Dictionary, collision: Array[Vector3]) -> void:
	var ring: PackedVector2Array = SectionHull.outline(tank)
	var z0: float = float(tank["z0"])
	var z1: float = float(tank["z1"])
	for edge_index: int in ring.size():
		var a: Vector2 = ring[edge_index]
		var b: Vector2 = ring[(edge_index + 1) % ring.size()]
		var outward: Vector2 = _outward(a, b)
		_add_quad(surface, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1), Vector3(outward.x, outward.y, 0.0), collision)
	_add_xy_fan(surface, ring, z0, Vector3(0.0, 0.0, -1.0), collision)
	_add_xy_fan(surface, ring, z1, Vector3(0.0, 0.0, 1.0), collision)


## Solar arrays on booms off the stern band's aft face — visual furniture only, no
## collision (nothing walks there; the tether is the recovery).
func _add_arrays(hull: StaticBody3D) -> void:
	var panel_material: StandardMaterial3D = StandardMaterial3D.new()
	panel_material.albedo_color = Color(0.05, 0.07, 0.18)
	panel_material.metallic = 0.25
	panel_material.roughness = 0.35
	for array: Dictionary in SectionHull.ARRAYS:
		var boom_x: float = float(array["boom_x"])
		var boom: MeshInstance3D = MeshInstance3D.new()
		boom.name = "ArrayBoom"
		var boom_mesh: BoxMesh = BoxMesh.new()
		boom_mesh.size = Vector3(0.24, 0.24, SectionHull.ARRAY_PANEL_Z0 - SectionHull.ARRAY_BOOM_Z0)
		boom.mesh = boom_mesh
		boom.material_override = _materials[MATERIAL_CONDUIT] as Material
		boom.position = Vector3(boom_x, SectionHull.ARRAY_BOOM_Y, (SectionHull.ARRAY_BOOM_Z0 + SectionHull.ARRAY_PANEL_Z0) * 0.5)
		hull.add_child(boom)
		var panel_min: Vector2 = array["panel_min"]
		var panel_max: Vector2 = array["panel_max"]
		var panel: MeshInstance3D = MeshInstance3D.new()
		panel.name = "ArrayPanel"
		var panel_mesh: BoxMesh = BoxMesh.new()
		panel_mesh.size = Vector3(panel_max.x - panel_min.x, panel_max.y - panel_min.y, SectionHull.ARRAY_PANEL_Z1 - SectionHull.ARRAY_PANEL_Z0)
		panel.mesh = panel_mesh
		panel.material_override = panel_material
		panel.position = Vector3((panel_min.x + panel_max.x) * 0.5, (panel_min.y + panel_max.y) * 0.5, (SectionHull.ARRAY_PANEL_Z0 + SectionHull.ARRAY_PANEL_Z1) * 0.5)
		hull.add_child(panel)


## The tube stern's arrays: a boom and a panel off each shoulder of the tank drum. The flat
## table's coordinates do not exist in tube mode, where they left panels floating in space.
func _add_tube_arrays(hull: StaticBody3D) -> void:
	var drums: Array[Dictionary] = SectionHull.tube_drums()
	if drums.is_empty():
		return
	var tank: Dictionary = drums[drums.size() - 1]
	var radius: float = float(tank["radius"]) + SectionHull.TUBE_BAND
	var center_z: float = (float(tank["z0"]) + float(tank["z1"])) * 0.5
	var panel_material: StandardMaterial3D = StandardMaterial3D.new()
	panel_material.albedo_color = Color(0.05, 0.07, 0.18)
	panel_material.metallic = 0.25
	panel_material.roughness = 0.35
	for side: float in [-1.0, 1.0]:
		var shoulder: float = SectionHull.tube_half_width(radius, SectionHull.ARRAY_BOOM_Y)
		var boom: MeshInstance3D = MeshInstance3D.new()
		boom.name = "ArrayBoom%.0f" % side
		var boom_mesh: BoxMesh = BoxMesh.new()
		boom_mesh.size = Vector3(1.6, 0.24, 0.24)
		boom.mesh = boom_mesh
		boom.material_override = _materials[MATERIAL_CONDUIT] as Material
		boom.position = Vector3(side * (shoulder + 0.75), SectionHull.ARRAY_BOOM_Y, center_z)
		hull.add_child(boom)
		var panel: MeshInstance3D = MeshInstance3D.new()
		panel.name = "ArrayPanel%.0f" % side
		var panel_mesh: BoxMesh = BoxMesh.new()
		panel_mesh.size = Vector3(0.08, 1.2, 2.4)
		panel.mesh = panel_mesh
		panel.material_override = panel_material
		panel.position = Vector3(side * (shoulder + 1.6), SectionHull.ARRAY_BOOM_Y, center_z)
		hull.add_child(panel)


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
	var shell: Dictionary = SectionHull.sections()[0]
	var shell_min: Vector2 = Vector2(float(shell["min"].x), float(shell["z0"]))
	var shell_max: Vector2 = Vector2(float(shell["max"].x), float(SectionHull.sections()[2]["z1"]))
	var outer_min: Vector2 = shell_min - Vector2(CATWALK_WIDTH, CATWALK_WIDTH)
	var outer_max: Vector2 = shell_max + Vector2(CATWALK_WIDTH, CATWALK_WIDTH)
	_add_slab(decks, sides, Vector2(outer_min.x, outer_min.y), Vector2(outer_max.x, shell_min.y), collision)
	_add_slab(decks, sides, Vector2(outer_min.x, shell_max.y), Vector2(outer_max.x, outer_max.y), collision)
	_add_slab(decks, sides, Vector2(outer_min.x, shell_min.y), Vector2(shell_min.x, shell_max.y), collision)
	_add_slab(decks, sides, Vector2(shell_max.x, shell_min.y), Vector2(outer_max.x, shell_max.y), collision)


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
		[Vector3(-7.5, 1.0, -20.83), Vector3(4.8, 0.08, 0.06)],
		[Vector3(5.8, 1.0, -20.83), Vector3(4.2, 0.08, 0.06)],
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
	var hull_face: float = _shell_face_for(float(dock["outward"]))
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


## M10/M13 dock mounts: a proud collar plate sealing each shell doorway (its outward face
## is the pod's mating plane), the hardpoint marker just off it, and a sill slab flooring
## the slot between the shell face and the standing pod's near wall.
func _add_dock_plates(hull: StaticBody3D, decks: Dictionary, collision: Array[Vector3]) -> void:
	for dock: Dictionary in DOCKS:
		var id: String = String(dock["id"])
		var outward: float = float(dock["outward"])
		var shell_face: float = _shell_face_for(outward)
		var plate: StaticBody3D = StaticBody3D.new()
		plate.name = "DockPlate_" + id
		plate.position = Vector3(shell_face + outward * DOCK_PLATE_THICKNESS * 0.5, (DOCK_PLATE_Y_MIN + DOCK_PLATE_Y_MAX) * 0.5, float(dock["z"]))
		_join_group(plate, &"dock_plate")
		plate.set_meta(&"hardpoint_id", StringName("hp_" + id))
		# The plate is the dock mount the operator builds from EVA; it hides and stops
		# colliding while a pod stands so the doorway into the pod opens.
		plate.set_script(load(SCRIPT_MODULE_MOUNT) as Script)
		plate.set(&"hardpoint_id", StringName("hp_" + id))
		hull.add_child(plate)
		var size: Vector3 = Vector3(DOCK_PLATE_THICKNESS, DOCK_PLATE_Y_MAX - DOCK_PLATE_Y_MIN, DOCK_DOOR_HALF * 2.0)
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
		marker.position = Vector3(shell_face + outward * (DOCK_PLATE_THICKNESS + 0.1), 1.4, float(dock["z"]))
		_join_group(marker, &"hardpoint")
		marker.set_meta(&"hardpoint_id", StringName("hp_" + id))
		hull.add_child(marker)
		var x_in: float = shell_face
		var x_out: float = shell_face + outward * DOCK_SILL_DEPTH
		_add_hexahedron(decks, [
			Vector3(minf(x_in, x_out), CATWALK_BOTTOM, float(dock["z"]) - DOCK_DOOR_HALF),
			Vector3(maxf(x_in, x_out), CATWALK_BOTTOM, float(dock["z"]) - DOCK_DOOR_HALF),
			Vector3(maxf(x_in, x_out), CATWALK_BOTTOM, float(dock["z"]) + DOCK_DOOR_HALF),
			Vector3(minf(x_in, x_out), CATWALK_BOTTOM, float(dock["z"]) + DOCK_DOOR_HALF),
			Vector3(minf(x_in, x_out), CATWALK_TOP, float(dock["z"]) - DOCK_DOOR_HALF),
			Vector3(maxf(x_in, x_out), CATWALK_TOP, float(dock["z"]) - DOCK_DOOR_HALF),
			Vector3(maxf(x_in, x_out), CATWALK_TOP, float(dock["z"]) + DOCK_DOOR_HALF),
			Vector3(minf(x_in, x_out), CATWALK_TOP, float(dock["z"]) + DOCK_DOOR_HALF),
		], collision)


## Group membership must be marked persistent to reach the packed scene; do it while the
## node is inside the tree so the assignment is legal.
func _join_group(node: Node, group: StringName) -> void:
	root.add_child(node)
	node.add_to_group(group, true)
	root.remove_child(node)


func _shell_face_for(outward: float) -> float:
	var shell: Dictionary = SectionHull.sections()[0]
	return float(shell["min"].x) if outward < 0.0 else float(shell["max"].x)


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
	if _interior_style() != "flat":
		# Preview run: the flat rooms are gone by design, so only the hull-side checks apply.
		print("PASS: build_ship_geometry (", _interior_style(), " preview)")
		instance.free()
		return true
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
		if plate.get_meta(&"hardpoint_id", &"") != StringName("hp_" + id):
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
