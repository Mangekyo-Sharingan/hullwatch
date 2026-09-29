## Unit tests for the M13.2 tube-layout tables: the room-to-section chain, its deck areas against
## the flat rooms it replaces, the dock ports, the hatch rules and the headroom checks. Pure
## functions, no scene tree.
extends SceneTree

const TOLERANCE: float = 0.0001

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	for problem: String in TubeLayout.validate():
		_check(false, "tube table: " + problem)
	_check(TubeLayout.validate().is_empty(), "the tube-layout tables validate cleanly")

	_check(TubeLayout.sections().size() == 11, "the chain has eleven sections")
	_check(TubeLayout.total_length() > 28.0 and TubeLayout.total_length() < 34.0, "the chain fits the ship's length")
	var previous_end: float = TubeLayout.BOW_Z
	for index: int in TubeLayout.sections().size():
		var bounds: Vector2 = TubeLayout.span(index)
		_check(absf(bounds.x - previous_end) < TOLERANCE, "section %d starts where the last ended" % index)
		_check(bounds.y > bounds.x, "section %d has a positive span" % index)
		previous_end = bounds.y + TubeLayout.BULKHEAD
	_check(TubeLayout.span(0).x == TubeLayout.BOW_Z, "the chain starts at the bow")
	_check(TubeLayout.section_at(-21.5).is_empty(), "nothing exists forward of the chain")
	_check(TubeLayout.section_at(30.0).is_empty(), "nothing exists aft of the chain")
	_check(String(TubeLayout.section_at(-19.0)["name"]) == "cupola", "the cupola head resolves forward")
	_check(String(TubeLayout.section_at(-13.5)["name"]) == "quarters", "quarters resolves inside its span")

	_check(String(TubeLayout.section_at(TubeLayout.span(2).x + 0.1)["name"]) == "quarters", "a section resolves inside its own span")
	_check(TubeLayout.section_at(TubeLayout.span(2).y + 0.2).is_empty(), "the bulkhead gap belongs to no section")

	var rooms: Dictionary = {}
	for index: int in TubeLayout.sections().size():
		var room: StringName = StringName(TubeLayout.sections()[index].get("room", &""))
		if room != &"":
			rooms[room] = int(rooms.get(room, 0)) + 1
	for room: Variant in TubeLayout.ROOM_COMPARTMENTS:
		_check(rooms.has(room), "every room has sections: " + String(room))
	_check(int(rooms.get(&"engine_bay", 0)) == 2, "the engine bay spans two sections")
	_check(TubeLayout.sections_for_room(&"engine_bay") == ([8, 9] as Array[int]), "engine sections are adjacent")
	var expected_mezzanine_sections: Array[StringName] = [&"quarters", &"storage", &"engine_bay_a", &"engine_bay_b"]
	var mezzanine_sections: Array[StringName] = []
	for section: Dictionary in TubeLayout.sections():
		var name: StringName = StringName(section["name"])
		if SectionHull.section_mezzanine_y(section) > 0.0:
			mezzanine_sections.append(name)
			_check(is_equal_approx(float(section["wall_top"]), 3.4), "double-height wall top: " + String(name))
			_check(is_equal_approx(float(section["ceiling"]), 4.4), "double-height ceiling: " + String(name))
			_check(is_equal_approx(SectionHull.section_mezzanine_y(section), 2.2), "mezzanine height: " + String(name))
			_check(SectionHull.section_mezzanine_y(section) - TubeLayout.MEZZANINE_THICKNESS >= 1.85, "lower deck has standing clearance: " + String(name))
			_check(float(section["ceiling"]) - SectionHull.section_mezzanine_y(section) >= 1.85, "upper deck has standing clearance: " + String(name))
		else:
			_check(is_equal_approx(float(section.get("ceiling", SectionHull.TUBE_CEILING)), SectionHull.TUBE_CEILING), "standard section ceiling stays unchanged: " + String(name))
	_check(mezzanine_sections == expected_mezzanine_sections, "only quarters, storage, and both engine-bay sections receive ring decks")

	_check(TubeLayout.deck_area(0) > 14.0 and TubeLayout.deck_area(0) < 18.0, "a 2.3 m section decks about 16 m2")
	_check(TubeLayout.room_deck_area(&"cockpit") >= 31.3, "the cockpit keeps its floor area across its sections")
	_check(TubeLayout.room_deck_area(&"quarters") >= 19.8, "quarters keeps its floor area")
	_check(TubeLayout.room_deck_area(&"life_support") >= 9.1, "life support keeps its floor area")
	_check(TubeLayout.room_deck_area(&"galley") >= 14.4, "the galley keeps its floor area")
	_check(TubeLayout.room_deck_area(&"water_closet") >= 5.7, "the head keeps its floor area")
	_check(TubeLayout.room_deck_area(&"storage") >= 13.3, "storage keeps its floor area")
	_check(TubeLayout.room_deck_area(&"airlock") >= 4.0, "the airlock keeps its floor area")
	_check(TubeLayout.room_deck_area(&"engine_bay") >= 44.6, "the engine bay keeps its floor area")

	var ports: Array[StringName] = []
	for index: int in TubeLayout.sections().size():
		var port: StringName = TubeLayout.port_of(index)
		if port != &"":
			ports.append(port)
	_check(ports.size() == 4, "the chain carries four dock ports")
	for dock: StringName in TubeLayout.DOCK_PORTS:
		var index: int = -1
		for candidate: int in TubeLayout.sections().size():
			if TubeLayout.port_of(candidate) == dock:
				index = candidate
		_check(index >= 0, "dock has a port: " + String(dock))
		if index < 0:
			continue
		var room: StringName = StringName(TubeLayout.sections()[index].get("room", &""))
		_check(TubeLayout.ROOM_COMPARTMENTS.has(room), "a dock's section belongs to a room: " + String(dock))

	_check(TubeLayout.is_walkable(0) and TubeLayout.is_walkable(1), "the cupola head is part of the cockpit suite")
	_check(TubeLayout.has_hatch(0), "the cupola head connects to the cockpit")
	_check(not TubeLayout.is_walkable(10), "the stern tank is not walkable")
	_check(not TubeLayout.has_hatch(9), "no hatch opens into the tank")
	_check(TubeLayout.has_hatch(1), "living sections are chained by hatches")
	_check(TubeLayout.has_hatch(7), "the airlock still connects to the chain")
	var airlock: int = TubeLayout.index_of("airlock")
	_check(airlock >= 0 and bool(TubeLayout.sections()[airlock].get("outer_hatch", false)), "the airlock carries the outer hatch")
	_check(TubeLayout.HATCH_HALF_WIDTH * 2.0 <= 1.2, "hatches stay in the module door class")

	var usable: float = TubeLayout.deck_area(5)
	_check(usable < TubeLayout.deck_area(6), "the head is smaller than storage")

	if _failures == 0:
		print("PASS: test_tube_layout")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
