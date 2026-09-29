## M13.2 layout tables: the ship's rooms re-laid as a chain of pressurised tube sections in the
## reference's module language (train layout - you walk from section to section through bulkhead
## hatches the way ISS modules connect). Section decks are circles, so a section's floor area is
## pi * r^2; each section carries one room (or part of one), and the four dock mounts become
## radial ports on their own sections. Pure data + functions, no scene tree - unit-testable
## headless, like HullProfile and SectionHull.
##
## This is the dial M13.2 turns: `build_ship_geometry.gd` keeps sweeping whatever these tables
## say, so converting the interior is replacing the flat room plan with this chain, and slimming
## `SectionHull.SECTIONS` to the same radii follows from it.
class_name TubeLayout
extends RefCounted

const EPSILON: float = 0.0001
## Default clear height for sections without a per-section ceiling override.
const DECK_HEIGHT: float = 2.5
const MEZZANINE_FRACTION: float = 0.5
const MEZZANINE_THICKNESS: float = 0.12
## Pressure wall thickness used when sizing a section's usable radius.
const WALL: float = 0.12
## Flange length between two sections; a hatch sits in every one.
const BULKHEAD: float = 0.35
## Sections are twelve-sided (a 3r^2-gon: the flat bow and stern edges must clear a hatch).
const SEGMENTS: int = 12
const HATCH_HALF_WIDTH: float = 0.45
const HATCH_HEIGHT: float = 1.85
## The chain starts here (bow) and runs aft; the shell's current span is z -21.3..12.7.
const BOW_Z: float = -21.0

## Bow to stern. `room` names the interior room the section serves ("" for the stern tank; the
## cupola head is part of the cockpit suite, with the forward viewport in its nose) and
## the stern tank, which are not living space); `replaces_area_m2` is the floor area of the flat
## room this section (or section group) stands in for, so the conversion can be checked against
## the ship that exists today.
const SECTIONS: Array[Dictionary] = [
	{"name": "cupola", "room": "cockpit", "radius": 2.4, "length": 2.2, "kind": "dome"},
	{"name": "cockpit", "room": "cockpit", "radius": 2.4, "length": 2.8, "kind": "drum", "replaces_area_m2": 31.3},
	{"name": "quarters", "room": "quarters", "radius": 2.7, "length": 2.8, "kind": "drum", "port": "hp_quarters", "wall_top": 3.4, "ceiling": 4.4, "mezzanine_y": 2.2, "replaces_area_m2": 19.8},
	{"name": "life_support", "room": "life_support", "radius": 2.1, "length": 2.2, "kind": "drum", "port": "hp_life_support", "replaces_area_m2": 9.1},
	{"name": "galley", "room": "galley", "radius": 2.3, "length": 2.6, "kind": "drum", "port": "hp_galley", "replaces_area_m2": 14.4},
	{"name": "water_closet", "room": "water_closet", "radius": 2.0, "length": 1.8, "kind": "drum", "replaces_area_m2": 5.7},
	{"name": "storage", "room": "storage", "radius": 2.3, "length": 2.6, "kind": "drum", "wall_top": 3.4, "ceiling": 4.4, "mezzanine_y": 2.2, "replaces_area_m2": 13.3},
	{"name": "airlock", "room": "airlock", "radius": 2.0, "length": 1.8, "kind": "drum", "outer_hatch": true, "replaces_area_m2": 4.0},
	{"name": "engine_bay_a", "room": "engine_bay", "radius": 2.8, "length": 2.8, "kind": "drum", "wall_top": 3.4, "ceiling": 4.4, "mezzanine_y": 2.2, "replaces_area_m2": 22.3},
	{"name": "engine_bay_b", "room": "engine_bay", "radius": 2.8, "length": 2.8, "kind": "drum", "port": "hp_engine_bay", "wall_top": 3.4, "ceiling": 4.4, "mezzanine_y": 2.2, "replaces_area_m2": 22.3},
	{"name": "tank", "room": "", "radius": 2.6, "length": 3.0, "kind": "tank"},
]

## Rooms the chain must serve, and the compartment each one belongs to (the sim ids). The
## corridor is deliberately absent: its 54 m2 dissolves into the chain, which is what makes the
## engine bay and cockpit fit as two sections each.
const ROOM_COMPARTMENTS: Dictionary = {
	&"cockpit": &"cockpit",
	&"quarters": &"quarters",
	&"life_support": &"main",
	&"galley": &"galley",
	&"water_closet": &"water_closet",
	&"storage": &"storage",
	&"airlock": &"airlock",
	&"engine_bay": &"engine_bay",
}

const DOCK_PORTS: Array[StringName] = [&"hp_quarters", &"hp_life_support", &"hp_galley", &"hp_engine_bay"]
## Two sections or more for these rooms; one section each for everything else.
const MIN_SECTIONS_PER_ROOM: Dictionary = {&"cockpit": 1, &"engine_bay": 2}


static func sections() -> Array[Dictionary]:
	return SECTIONS


## The z span of a section, including the bulkhead aft of it (the last section has none).
static func span(index: int) -> Vector2:
	var z0: float = BOW_Z
	for i: int in index:
		z0 += float(SECTIONS[i]["length"]) + BULKHEAD
	return Vector2(z0, z0 + float(SECTIONS[index]["length"]))


static func total_length() -> float:
	var total: float = 0.0
	for section: Dictionary in SECTIONS:
		total += float(section["length"])
	return total + BULKHEAD * float(maxi(SECTIONS.size() - 1, 0))


static func section_at(z: float) -> Dictionary:
	for index: int in SECTIONS.size():
		var bounds: Vector2 = span(index)
		if z >= bounds.x - EPSILON and z <= bounds.y + EPSILON:
			return SECTIONS[index]
	return {}


static func index_of(section_name: String) -> int:
	for index: int in SECTIONS.size():
		if String(SECTIONS[index]["name"]) == section_name:
			return index
	return -1


## Floor area of a section's deck: the inner boundary is the section's polygon itself (the
## pressure wall is offset outside it), so a SEGMENTS-gon of radius r decks area = 1/2 n r^2 sin(2pi/n).
static func deck_area(index: int) -> float:
	var radius: float = maxf(float(SECTIONS[index]["radius"]), 0.0)
	return 0.5 * float(SEGMENTS) * radius * radius * sin(TAU / float(SEGMENTS))


static func room_deck_area(room: StringName) -> float:
	var total: float = 0.0
	for index: int in SECTIONS.size():
		if StringName(SECTIONS[index].get("room", &"")) == room:
			total += deck_area(index)
	return total


## Sections a room occupies, bow to stern.
static func sections_for_room(room: StringName) -> Array[int]:
	var found: Array[int] = []
	for index: int in SECTIONS.size():
		if StringName(SECTIONS[index].get("room", &"")) == room:
			found.append(index)
	return found


## The dock port on a section, empty when it carries none.
static func port_of(index: int) -> StringName:
	return StringName(SECTIONS[index].get("port", &""))


## True when the section is living space (the cupola head and the tank are not).
static func is_walkable(index: int) -> bool:
	return String(SECTIONS[index].get("room", "")) != ""


## A hatch sits in the bulkhead between two walkable sections; a hatch to the tank is not a
## door, and the airlock's outer hatch is radial, not part of the chain.
static func has_hatch(index: int) -> bool:
	return index >= 0 and index < SECTIONS.size() - 1 and is_walkable(index) and is_walkable(index + 1)


## Everything the conversion must keep true. Empty array means the tables are sound.
static func validate() -> Array[String]:
	var problems: Array[String] = []
	var seen: Dictionary = {}
	for index: int in SECTIONS.size():
		var section: Dictionary = SECTIONS[index]
		var name: String = String(section.get("name", ""))
		if name.is_empty():
			problems.append("section %d has no name" % index)
		elif seen.has(name):
			problems.append("section name repeats: " + name)
		seen[name] = true
		if float(section.get("radius", 0.0)) <= WALL:
			problems.append("section radius must clear the wall: " + name)
		if float(section.get("length", 0.0)) <= 0.0:
			problems.append("section length must be positive: " + name)
		var radius: float = float(section.get("radius", 0.0))
		if radius * 2.0 < HATCH_HEIGHT * 0.75:
			problems.append("section is too narrow for its hatch: " + name)
		var end_edge: float = 2.0 * radius * sin(PI / float(SEGMENTS))
		if end_edge < HATCH_HALF_WIDTH * 2.0 + 0.05:
			problems.append("section end edge is too narrow for a hatch: " + name)
		var room: StringName = StringName(section.get("room", &""))
		if room != &"" and not ROOM_COMPARTMENTS.has(room):
			problems.append("section serves an unknown room: " + name + " / " + String(room))
	for room: Variant in ROOM_COMPARTMENTS:
		var count: int = sections_for_room(StringName(room)).size()
		var needed: int = int(MIN_SECTIONS_PER_ROOM.get(room, 1))
		if count < needed:
			problems.append("room has too few sections: %s (%d of %d)" % [String(room), count, needed])
		if room != &"cockpit" and room_deck_area(StringName(room)) + 0.5 < _replaces_area(StringName(room)):
			problems.append("room loses floor area: %s (%.1f < %.1f)" % [String(room), room_deck_area(StringName(room)), _replaces_area(StringName(room))])
	var ports: Dictionary = {}
	for index: int in SECTIONS.size():
		var port: StringName = port_of(index)
		if port == &"":
			continue
		if ports.has(port):
			problems.append("dock port appears twice: " + String(port))
		ports[port] = true
		var room: StringName = StringName(SECTIONS[index].get("room", &""))
		if room == &"":
			problems.append("dock port sits on a section with no room: " + String(port))
	for dock: StringName in DOCK_PORTS:
		if not ports.has(dock):
			problems.append("dock has no port in the chain: " + String(dock))
	for index: int in maxi(SECTIONS.size() - 1, 0):
		if has_hatch(index) and float(SECTIONS[index]["radius"]) * 2.0 < HATCH_HALF_WIDTH * 2.0 + WALL * 2.0:
			problems.append("hatch is wider than the section: " + String(SECTIONS[index].get("name", "")))
	var airlock: int = index_of("airlock")
	if airlock < 0 or not bool(SECTIONS[airlock].get("outer_hatch", false)):
		problems.append("the airlock section must carry the outer hatch")
	var walkable: int = 0
	for index: int in SECTIONS.size():
		if is_walkable(index):
			walkable += 1
	if walkable < 8:
		problems.append("the chain must serve every room")
	return problems


static func _replaces_area(room: StringName) -> float:
	var total: float = 0.0
	for section: Dictionary in SECTIONS:
		if StringName(section.get("room", &"")) == room:
			total += float(section.get("replaces_area_m2", 0.0))
	return total
