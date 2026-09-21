## Lathed section-hull math for the M13 modular stack: the shell is a sequence of
## chamfered-rectangle cross-sections (rings in the XY plane) swept along the ship's z
## axis, with taper rings for the prow, ring collars for flanges and ribs, framed window
## faces, and the stern tank cluster. Pure data + functions, no scene tree — unit-testable
## headless, like HullProfile. The tables are the single dial that slims when the interior
## converts to tubes (M13.2): rooms become per-section rings without touching the sweep.
class_name SectionHull
extends RefCounted

const EPSILON: float = 0.000001

## One entry per hull section, bow to stern. `min`/`max` are the cross-section bounds in
## the XY plane (x = east, y = up); every section shares the outline while the interior
## stays flat (the 14 m beam), so the stack reads as a wide multi-section hull.
const SECTIONS: Array[Dictionary] = [
	{"name": "BowWindow", "z0": -19.45, "z1": -19.0, "min": Vector2(-8.5, -0.75), "max": Vector2(6.6, 3.6), "cut": 0.55},
	{"name": "Body", "z0": -19.0, "z1": 8.0, "min": Vector2(-8.5, -0.75), "max": Vector2(6.6, 3.6), "cut": 0.55},
	{"name": "SternBand", "z0": 8.0, "z1": 8.45, "min": Vector2(-8.5, -0.75), "max": Vector2(6.6, 3.6), "cut": 0.55},
]

## The faceted prow over the cockpit window: taper rings bow-ward, ending in a framed
## viewport aligned with the windshield so the pane still sees space through the cowl.
## The first ring's bottom sits at the catwalk deck plane (-0.02); the nose carries the
## forward viewport.
const PROW_RINGS: Array[Dictionary] = [
	{"z": -19.45, "min": Vector2(-8.5, -0.02), "max": Vector2(6.6, 3.6), "cut": 0.55},
	{"z": -20.3, "min": Vector2(-5.6, 0.15), "max": Vector2(3.7, 3.0), "cut": 1.0},
	{
		"z": -21.3,
		"min": Vector2(-3.4, 0.75),
		"max": Vector2(2.8, 2.85),
		"cut": 0.15,
		"window_min": Vector2(-2.6, 0.9),
		"window_max": Vector2(2.6, 2.6),
	},
]

## The cockpit window opening in the bow face (matches the windshield gap in the cockpit
## wall: x -2.0..2.0, y 1.2..2.3).
const BOW_WINDOW_MIN: Vector2 = Vector2(-2.0, 1.2)
const BOW_WINDOW_MAX: Vector2 = Vector2(2.0, 2.3)

## Ring collars girdling the hull at the interior section joints (cockpit|corridor,
## corridor|engine bay), and rib rings along the body — the reference's flange-and-panel
## frame language. Tops stay flush with the roof walk (max.y is not offset).
const FLANGES_Z: Array[float] = [-14.0, 1.4]
const FLANGE_OFFSET: float = 0.35
const FLANGE_HALF: float = 0.15
const RIBS_Z: Array[float] = [-16.5, -12.2, -8.2, -3.5, 6.2]
const RIB_OFFSET: float = 0.22
const RIB_HALF: float = 0.09

## Stern tank cluster: two ribbed drums on pylons over the aft deck, clear of the roof
## ramp channel (x 1.2..2.4). Cross-sections in XY, swept along z.
const TANK_A: Dictionary = {"z0": 9.9, "z1": 12.7, "min": Vector2(-4.4, 2.1), "max": Vector2(-1.2, 4.6), "cut": 0.4}
const TANK_B: Dictionary = {"z0": 10.5, "z1": 12.3, "min": Vector2(-3.8, 4.6), "max": Vector2(-1.8, 6.6), "cut": 0.35}
const TANK_RIB_OFFSET: float = 0.15
const TANK_RIB_HALF: float = 0.06
const TANK_RIBS_Z: Array[float] = [10.7, 11.5]
const TANK_PYLONS: Array[Dictionary] = [
	{"x0": -3.6, "x1": -3.2, "y0": 0.0, "y1": 2.09, "z0": 10.0, "z1": 10.4},
	{"x0": -2.4, "x1": -2.0, "y0": 0.0, "y1": 2.09, "z0": 10.0, "z1": 10.4},
]

## Solar arrays on booms off the stern band's aft face (visual furniture, no collision).
const ARRAYS: Array[Dictionary] = [
	{"boom_x": 3.6, "panel_min": Vector2(2.7, 1.2), "panel_max": Vector2(4.5, 3.6)},
	{"boom_x": 5.8, "panel_min": Vector2(4.9, 1.2), "panel_max": Vector2(6.7, 3.6)},
]
const ARRAY_BOOM_Z0: float = 8.45
const ARRAY_PANEL_Z0: float = 10.45
const ARRAY_PANEL_Z1: float = 14.85
const ARRAY_BOOM_Y: float = 2.4

## The cabin envelope the shell must enclose (rooms' outer walls, not the shell): used
## by the containment tests.
const CABIN_MIN: Vector2 = Vector2(-8.05, -0.2)
const CABIN_MAX: Vector2 = Vector2(6.15, 3.2)
const CABIN_Z0: float = -19.0
const CABIN_Z1: float = 8.0


static func sections() -> Array[Dictionary]:
	return SECTIONS


## The chamfered cross-section outline of a section (or any ring table entry) in the XY
## plane, counter-clockwise.
static func outline(ring: Dictionary) -> PackedVector2Array:
	return HullProfile.rectangle_outline(ring["min"], ring["max"], ring.get("cut", 0.0))


## The tunnel cross-section (M13.2): the faceted corridor section every tube room shares,
## scaled by its radius. A flat deck at y = 0, canted walls, a cove, a flat ceiling - the
## six points run portside deck, starboard deck, up the starboard wall and cove, across the
## ceiling and back down. Edge 1 is the starboard (dock) wall, edge 5 the portside one.
const TUBE_DECK_HALF: float = 0.46
const TUBE_WALL_HALF: float = 0.88
const TUBE_CEIL_HALF: float = 0.60
const TUBE_WALL_TOP: float = 1.9
const TUBE_CEILING: float = 2.5

## The cross-section's facet indices the dock ports and the airlock hatch open through.
const TUBE_EDGE_STARBOARD: int = 1
const TUBE_EDGE_PORT: int = 5

## How far the hull's bow face sits forward of the interior's cupola face, the cowl depth
## the viewport looks through.
const PROW_DEPTH: float = 0.45

## The cockpit viewport on the cupola's forward face: smaller than the flat windshield,
## because the tunnel's bow is a section face rather than a four-metre wall.
const TUBE_WINDOW_MIN: Vector2 = Vector2(-1.05, 1.30)
const TUBE_WINDOW_MAX: Vector2 = Vector2(1.05, 2.15)

static func tube_section(radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-radius * TUBE_DECK_HALF, 0.0),
		Vector2(radius * TUBE_DECK_HALF, 0.0),
		Vector2(radius * TUBE_WALL_HALF, TUBE_WALL_TOP),
		Vector2(radius * TUBE_CEIL_HALF, TUBE_CEILING),
		Vector2(-radius * TUBE_CEIL_HALF, TUBE_CEILING),
		Vector2(-radius * TUBE_WALL_HALF, TUBE_WALL_TOP),
	])


## The section's half-width at height y, following the deck, the wall line and the cove.
## Used for placing faces and consoles against a canted wall.
static func tube_half_width(radius: float, y: float) -> float:
	var deck: float = radius * TUBE_DECK_HALF
	var wall: float = radius * TUBE_WALL_HALF
	var ceiling: float = radius * TUBE_CEIL_HALF
	if y <= 0.0:
		return deck
	if y <= TUBE_WALL_TOP:
		return lerpf(deck, wall, y / TUBE_WALL_TOP)
	return lerpf(wall, ceiling, clampf((y - TUBE_WALL_TOP) / (TUBE_CEILING - TUBE_WALL_TOP), 0.0, 1.0))

## Tube-mode shell (M13.2): the hull that wraps the tube interior is one constant-radius drum
## per TubeLayout section, since the section polygons already carry the shape. Drums meet at
## the joint centrelines so the shell is continuous; where the radii differ the joint gets a
## step band and a flange collar over it, which is what gives the converted ship its drum
## silhouette. Ring geometry (the twelve-gon itself) is built by the generator, which knows
## the section frames.
const TUBE_BAND: float = 0.3
const TUBE_STEP: float = 0.35
const TUBE_FLANGE_WIDTH: float = 0.22

## The drums of a tube-mode hull, bow to stern: the section name, the z span clipped to the
## joint centrelines, and the outer radius (the section's own radius plus the band).
static func tube_drums() -> Array[Dictionary]:
	var sections: Array[Dictionary] = TubeLayout.sections()
	var drums: Array[Dictionary] = []
	for index: int in sections.size():
		var bounds: Vector2 = TubeLayout.span(index)
		var z0: float = bounds.x
		var z1: float = bounds.y
		if index > 0:
			z0 = (TubeLayout.span(index - 1).y + bounds.x) * 0.5
		if index < sections.size() - 1:
			z1 = (bounds.y + TubeLayout.span(index + 1).x) * 0.5
		drums.append({
			"name": String(sections[index]["name"]),
			"z0": z0,
			"z1": z1,
			"radius": float(sections[index]["radius"]) + TUBE_BAND,
		})
	return drums


## The joints between drums whose radii differ: the z, and the two radii the step covers.
static func tube_joints() -> Array[Dictionary]:
	var drums: Array[Dictionary] = tube_drums()
	var joints: Array[Dictionary] = []
	for index: int in drums.size() - 1:
		if absf(float(drums[index]["radius"]) - float(drums[index + 1]["radius"])) <= EPSILON:
			continue
		joints.append({
			"z": (float(drums[index]["z1"]) + float(drums[index + 1]["z0"])) * 0.5,
			"radius_a": float(drums[index]["radius"]),
			"radius_b": float(drums[index + 1]["radius"]),
		})
	return joints


static func validate_tube() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var drums: Array[Dictionary] = tube_drums()
	if drums.size() != TubeLayout.sections().size():
		problems.append("every tube section needs a drum")
	for index: int in drums.size():
		var drum: Dictionary = drums[index]
		if float(drum["z1"]) <= float(drum["z0"]) + EPSILON:
			problems.append("drum %s has an empty z span" % String(drum["name"]))
		if index > 0 and absf(float(drums[index - 1]["z1"]) - float(drum["z0"])) > EPSILON:
			problems.append("drum %s does not meet its forward neighbour" % String(drum["name"]))
		var section: Dictionary = TubeLayout.sections()[index]
		if absf(float(drum["radius"]) - (float(section["radius"]) + TUBE_BAND)) > EPSILON:
			problems.append("drum %s radius does not follow its section" % String(drum["name"]))
	for joint: Dictionary in tube_joints():
		if float(joint["z"]) < float(drums[0]["z0"]) or float(joint["z"]) > float(drums[-1]["z1"]):
			problems.append("a step joint lands outside the chain")
	return problems

## The section whose z span contains z; empty dictionary when z is outside the stack.
static func section_at(z: float) -> Dictionary:
	for section: Dictionary in SECTIONS:
		if z >= float(section["z0"]) - EPSILON and z <= float(section["z1"]) + EPSILON:
			return section
	return {}


## The cross-section outline at z: constant inside a section, empty outside the stack.
static func outline_at(z: float) -> PackedVector2Array:
	var section: Dictionary = section_at(z)
	if section.is_empty():
		return PackedVector2Array()
	return outline(section)


## Vertex-to-vertex taper between two same-sized rings at parameter t in [0, 1].
static func taper_ring(from_ring: PackedVector2Array, to_ring: PackedVector2Array, t: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if from_ring.size() != to_ring.size():
		return result
	for i: int in from_ring.size():
		result.append(from_ring[i].lerp(to_ring[i], clampf(t, 0.0, 1.0)))
	return result


## A collar outline: the ring grown outward by `extra`, with the top held flush at the
## ring's max.y so collars never trip the roof walk.
static func collar_outline(ring: Dictionary, extra: float) -> PackedVector2Array:
	var ring_min: Vector2 = ring["min"]
	var ring_max: Vector2 = ring["max"]
	var cut: float = float(ring.get("cut", 0.0))
	return HullProfile.rectangle_outline(
		Vector2(ring_min.x - extra, ring_min.y - extra),
		Vector2(ring_max.x + extra, ring_max.y),
		cut + extra
	)


## Point-in-outline containment (convex chamfered rectangles).
static func contains_point(outline: PackedVector2Array, point: Vector2) -> bool:
	if outline.size() < 3:
		return false
	var previous: Vector2 = outline[outline.size() - 1]
	for current: Vector2 in outline:
		var edge: Vector2 = current - previous
		if edge.cross(point - previous) < -EPSILON:
			return false
		previous = current
	return true


## True when the outline encloses the cabin envelope's corners (the shell never clips a
## room's outer walls).
static func encloses_cabin(test_outline: PackedVector2Array) -> bool:
	for corner: Vector2 in [CABIN_MIN, Vector2(CABIN_MIN.x, CABIN_MAX.y), CABIN_MAX, Vector2(CABIN_MAX.x, CABIN_MIN.y)]:
		if not contains_point(test_outline, corner):
			return false
	return true


## Structural validation for the tables: sections are ordered and contiguous, prow rings
## shrink toward the nose, and every section encloses the cabin. Returns a list of
## human-readable problems; empty means the table is sound.
static func validate() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for i: int in SECTIONS.size():
		var section: Dictionary = SECTIONS[i]
		if float(section["z1"]) <= float(section["z0"]) + EPSILON:
			problems.append("section %s has an empty z span" % String(section["name"]))
		if i > 0 and absf(float(SECTIONS[i - 1]["z1"]) - float(section["z0"])) > EPSILON:
			problems.append("section %s does not continue the stack" % String(section["name"]))
		var section_outline: PackedVector2Array = outline(section)
		if section_outline.size() != 8:
			problems.append("section %s outline is not an eight-vertex chamfered rectangle" % String(section["name"]))
		elif not encloses_cabin(section_outline):
			problems.append("section %s clips the cabin envelope" % String(section["name"]))
	for i: int in PROW_RINGS.size():
		var ring: Dictionary = PROW_RINGS[i]
		if outline(ring).size() != 8:
			problems.append("prow ring %d is not an eight-vertex chamfered rectangle" % i)
		if i > 0:
			var previous: Dictionary = PROW_RINGS[i - 1]
			if float(ring["z"]) >= float(previous["z"]) - EPSILON:
				problems.append("prow ring %d does not advance bow-ward" % i)
			var ring_area: float = HullProfile.signed_area(outline(ring))
			if ring_area >= HullProfile.signed_area(outline(previous)) + EPSILON:
				problems.append("prow ring %d does not shrink toward the nose" % i)
			if float(ring["min"].y) < float(previous["min"].y) - EPSILON or float(ring["max"].y) > float(previous["max"].y) + EPSILON:
				problems.append("prow ring %d escapes the previous ring's height" % i)
		if ring.has("window_min"):
			var window_min: Vector2 = ring["window_min"]
			var window_max: Vector2 = ring["window_max"]
			var cut: float = float(ring["cut"])
			var ring_min: Vector2 = ring["min"]
			var ring_max: Vector2 = ring["max"]
			if not contains_point(outline(ring), window_min) or not contains_point(outline(ring), window_max) \
					or not contains_point(outline(ring), Vector2(window_min.x, window_max.y)) \
					or not contains_point(outline(ring), Vector2(window_max.x, window_min.y)):
				problems.append("prow window escapes its ring at %s" % String(ring["z"]))
			if window_min.y < ring_min.y + cut - EPSILON or window_max.y > ring_max.y - cut + EPSILON:
				problems.append("prow window edges must land on the ring's straight zones")
	if absf(float(PROW_RINGS[0]["z"]) - float(SECTIONS[0]["z0"])) > EPSILON:
		problems.append("the prow does not start at the bow face")
	for z: float in FLANGES_Z + RIBS_Z:
		if section_at(z).is_empty():
			problems.append("collar at z=%.2f is outside the shell stack" % z)
	for z: float in TANK_RIBS_Z:
		if z < float(TANK_A["z0"]) + TANK_RIB_HALF or z > float(TANK_A["z1"]) - TANK_RIB_HALF:
			problems.append("tank rib at z=%.2f hangs off the drum" % z)
	return problems
