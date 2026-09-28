## Unit tests for the faceted-hull polygon math: outlines, CCW handling, mitered
## offsets/insets, profile rings, and the M13 section-hull tables. Pure functions, no
## scene tree.
extends SceneTree

const TOLERANCE: float = 0.0001

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_test_rectangle_outline()
	_test_ccw_handling()
	_test_offset_and_inset()
	_test_chamfer_vertices_stay_parallel()
	_test_profile_rings()
	_test_degenerate_inputs()
	_test_section_hull()
	if _failures == 0:
		print("PASS: test_hull_profile")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _test_section_hull() -> void:
	for problem: String in SectionHull.validate():
		_check(false, "section table: " + problem)
	_check(SectionHull.validate().is_empty(), "the section-hull tables validate cleanly")

	var body: Dictionary = SectionHull.section_at(0.0)
	_check(String(body["name"]) == "Body", "the body section contains midship")
	_check(String(SectionHull.section_at(-19.2)["name"]) == "BowWindow", "the bow window section sits forward")
	_check(String(SectionHull.section_at(8.2)["name"]) == "SternBand", "the stern band section sits aft")
	_check(SectionHull.section_at(-25.0).is_empty(), "nothing exists forward of the stack")
	_check(SectionHull.section_at(20.0).is_empty(), "nothing exists aft of the stack")
	_check(SectionHull.outline_at(0.0).size() == 8, "the body ring is an eight-vertex chamfered rectangle")
	_check(float(body["cut"]) >= 0.9, "the wide hull keeps a broad octagonal shoulder")
	_check(SectionHull.outline_at(0.0) == SectionHull.outline_at(5.0), "the ring is constant inside the body")
	_check(SectionHull.encloses_cabin(SectionHull.outline_at(0.0)), "the body ring encloses the cabin envelope")
	var tube_drums: Array[Dictionary] = SectionHull.tube_drums()
	_check(tube_drums.size() == TubeLayout.sections().size(), "every tube section gets one hull drum")
	var meets: bool = true
	for i2: int in tube_drums.size():
		if i2 > 0 and absf(float(tube_drums[i2 - 1]["z1"]) - float(tube_drums[i2]["z0"])) > 0.001:
			meets = false
		var tube_section: Dictionary = TubeLayout.sections()[i2]
		if absf(float(tube_drums[i2]["radius"]) - float(tube_section["radius"])) > 0.001:
			meets = false
	_check(meets, "tube drums meet at every joint and follow their sections")
	_check(absf(float(tube_drums[0]["z0"]) - TubeLayout.span(0).x) < 0.001 and absf(float(tube_drums[-1]["z1"]) - TubeLayout.span(TubeLayout.sections().size() - 1).y) < 0.001, "the drum chain spans the interior exactly")
	_check(SectionHull.tube_joints().size() > 0, "the varying radii leave step joints for the collars")
	_check(SectionHull.validate_tube().is_empty(), "the tube drum tables validate cleanly")
	var outer_ring: PackedVector2Array = SectionHull.tube_drum_section(float(tube_drums[0]["radius"]))
	_check(outer_ring.size() == 8, "the outer tube drum is an octagonal cross-section")
	_check(outer_ring[3].y > SectionHull.TUBE_WALL_TOP and outer_ring[3].x > outer_ring[4].x, "the outer drum has a broad, angled roof shoulder")
	_check(SectionHull.tube_collar_section(float(tube_drums[0]["radius"])).size() == 8, "joint collars follow the octagonal drum profile")
	_check(SectionHull.encloses_cabin(SectionHull.outline_at(-19.2)), "the bow window ring encloses the cabin envelope")
	_check(not SectionHull.encloses_cabin(HullProfile.rectangle_outline(Vector2(-4.0, -0.5), Vector2(4.0, 3.0), 0.4)), "a slimmed ring admits it clips the cabin")

	var bow: PackedVector2Array = SectionHull.outline(SectionHull.sections()[0])
	var nose: PackedVector2Array = SectionHull.outline(SectionHull.PROW_RINGS[2])
	_check(SectionHull.contains_point(bow, SectionHull.BOW_WINDOW_MIN), "the bow face contains the window's lower corner")
	_check(SectionHull.contains_point(bow, SectionHull.BOW_WINDOW_MAX), "the bow face contains the window's upper corner")
	_check(SectionHull.contains_point(nose, SectionHull.BOW_WINDOW_MIN) and SectionHull.contains_point(nose, SectionHull.BOW_WINDOW_MAX), "the nose viewport clears the windshield's view shaft")
	var nose_window: Dictionary = SectionHull.PROW_RINGS[2]
	_check(
		(nose_window["window_min"] as Vector2).x <= SectionHull.BOW_WINDOW_MIN.x
			and (nose_window["window_max"] as Vector2).x >= SectionHull.BOW_WINDOW_MAX.x,
		"the nose viewport is wider than the windshield"
	)

	var ring_a: PackedVector2Array = SectionHull.outline(SectionHull.PROW_RINGS[0])
	var ring_b: PackedVector2Array = SectionHull.outline(SectionHull.PROW_RINGS[1])
	_check(SectionHull.taper_ring(ring_a, ring_b, 0.0) == ring_a, "taper t=0 returns the aft ring")
	_check(SectionHull.taper_ring(ring_a, ring_b, 1.0) == ring_b, "taper t=1 returns the forward ring")
	var mid: PackedVector2Array = SectionHull.taper_ring(ring_a, ring_b, 0.5)
	_check(mid.size() == ring_a.size() and absf(mid[0].distance_to(ring_a[0].lerp(ring_b[0], 0.5))) < TOLERANCE, "taper t=0.5 lerps exactly")
	_check(SectionHull.taper_ring(ring_a, PackedVector2Array(), 0.5).is_empty(), "taper refuses mismatched rings")

	var collar: PackedVector2Array = SectionHull.collar_outline(SectionHull.sections()[1], SectionHull.FLANGE_OFFSET)
	_check(collar.size() == 8, "the collar keeps the eight-vertex structure")
	_check(absf(HullProfile.signed_area(collar) - HullProfile.signed_area(bow)) > 0.1, "the collar is strictly larger than its section")
	_check(absf(collar[4].y - bow[4].y) < TOLERANCE and absf(collar[5].y - bow[5].y) < TOLERANCE, "the collar top stays flush with the roof walk")
	for point: Vector2 in bow:
		_check(SectionHull.contains_point(collar, point), "the collar encloses its section")

	_check(float(SectionHull.TANK_A["max"].x) < 1.2 and float(SectionHull.TANK_B["max"].x) < 1.2, "the tank cluster stays clear of the roof ramp channel")
	_check(float(SectionHull.TANK_A["z0"]) > 9.45, "the tank cluster clears the catwalk's aft leg")
	_check(float(SectionHull.TANK_B["min"].y) >= float(SectionHull.TANK_A["max"].y) - TOLERANCE, "the upper tank rests on the lower drum")


func _test_rectangle_outline() -> void:
	var plain: PackedVector2Array = HullProfile.rectangle_outline(Vector2(0, 0), Vector2(2, 1))
	_check(plain.size() == 4, "plain rectangle has four corners")
	_check(absf(HullProfile.signed_area(plain) - 2.0) < TOLERANCE, "plain rectangle area is 2.0")
	var chamfered: PackedVector2Array = HullProfile.rectangle_outline(Vector2(0, 0), Vector2(2, 1), 0.25)
	_check(chamfered.size() == 8, "chamfered rectangle has eight corners")
	_check(absf(HullProfile.signed_area(chamfered) - 1.875) < TOLERANCE, "chamfered rectangle loses two corner triangles")
	var clamped: PackedVector2Array = HullProfile.rectangle_outline(Vector2(0, 0), Vector2(0.4, 0.4), 10.0)
	_check(clamped.size() == 8, "oversized chamfer clamps instead of collapsing")
	_check(HullProfile.signed_area(clamped) > 0.0, "clamped chamfer keeps a positive area")


func _test_ccw_handling() -> void:
	var outline: PackedVector2Array = HullProfile.rectangle_outline(Vector2(0, 0), Vector2(2, 1), 0.25)
	_check(HullProfile.signed_area(outline) > 0.0, "outlines are generated counter-clockwise")
	var reversed: PackedVector2Array = PackedVector2Array()
	for i: int in range(outline.size() - 1, -1, -1):
		reversed.append(outline[i])
	_check(HullProfile.signed_area(reversed) < 0.0, "reversed copy is clockwise")
	var fixed: PackedVector2Array = HullProfile.ensure_ccw(reversed)
	_check(HullProfile.signed_area(fixed) > 0.0, "ensure_ccw flips clockwise input")
	_check(fixed.size() == outline.size(), "ensure_ccw preserves vertex count")


func _test_offset_and_inset() -> void:
	var outline: PackedVector2Array = HullProfile.rectangle_outline(Vector2(0, 0), Vector2(2, 1))
	var grown: PackedVector2Array = HullProfile.offset_polygon(outline, 0.2)
	_check(grown.size() == 4, "offset keeps corner count")
	_check(grown[0].distance_to(Vector2(-0.2, -0.2)) < TOLERANCE, "offset corner 0 lands at the mitre point")
	_check(grown[2].distance_to(Vector2(2.2, 1.2)) < TOLERANCE, "offset corner 2 lands at the mitre point")
	_check(absf(HullProfile.signed_area(grown) - 3.36) < TOLERANCE, "offset rectangle area grows by the band")
	var shrunk: PackedVector2Array = HullProfile.inset_polygon(outline, 0.2)
	_check(shrunk[0].distance_to(Vector2(0.2, 0.2)) < TOLERANCE, "inset corner 0 lands at the mitre point")
	_check(absf(HullProfile.signed_area(shrunk) - 0.96) < TOLERANCE, "inset rectangle area shrinks by the band")
	_check(absf(HullProfile.signed_area(HullProfile.offset_polygon(outline, 0.0)) - 2.0) < TOLERANCE, "zero offset is a no-op")


func _test_chamfer_vertices_stay_parallel() -> void:
	var outline: PackedVector2Array = HullProfile.rectangle_outline(Vector2(0, 0), Vector2(4, 3), 0.9)
	for distance: float in [0.2, 0.25, 0.3, -0.2]:
		var offset: PackedVector2Array = HullProfile.offset_polygon(outline, distance)
		var worst: float = 0.0
		for point: Vector2 in offset:
			var closest: float = _min_line_distance(point, outline)
			worst = maxf(worst, absf(closest - absf(distance)))
		_check(worst < TOLERANCE, "every vertex sits %.2f from the outline edges" % distance)
	_check(HullProfile.signed_area(HullProfile.offset_polygon(outline, 0.25)) > HullProfile.signed_area(outline), "outward offset grows the polygon")
	_check(HullProfile.signed_area(HullProfile.inset_polygon(outline, 0.25)) < HullProfile.signed_area(outline), "inward offset shrinks the polygon")


func _test_profile_rings() -> void:
	var outline: PackedVector2Array = HullProfile.rectangle_outline(Vector2(0, 0), Vector2(1.4, 10.0), 0.3)
	var profile: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.9, 0.25), Vector2(3.0, 0.25)]
	var rings: Array[PackedVector2Array] = HullProfile.profile_rings(outline, profile)
	_check(rings.size() == 3, "profile makes one ring per entry")
	_check(rings[0] == outline, "floor ring is the outline itself")
	_check(rings[1].size() == rings[0].size(), "canted ring keeps the corner count")
	var capped: bool = true
	for point: Vector2 in rings[1]:
		if absf(_min_line_distance(point, outline) - 0.25) > TOLERANCE:
			capped = false
	_check(capped, "every canted vertex is the inset distance from the outline")
	_check(rings[2] == rings[1], "equal insets produce identical rings")
	_check(HullProfile.signed_area(rings[1]) < HullProfile.signed_area(rings[0]), "inset rings are smaller than the floor")


func _test_degenerate_inputs() -> void:
	var too_small: PackedVector2Array = HullProfile.rectangle_outline(Vector2(0, 0), Vector2(0.0, 1.0))
	_check(too_small.is_empty(), "degenerate rectangle returns no outline")
	var pair: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(1, 0)])
	_check(HullProfile.offset_polygon(pair, 0.2).size() == 2, "offset of a non-polygon returns it unchanged")
	var cut: float = 0.4 * 0.499
	_check(absf(HullProfile.signed_area(HullProfile.rectangle_outline(Vector2(0, 0), Vector2(0.4, 0.4), 10.0)) - (0.4 * 0.4 - 2.0 * cut * cut)) < TOLERANCE, "clamped chamfer area matches the cut")


func _min_line_distance(point: Vector2, polygon: PackedVector2Array) -> float:
	var closest: float = INF
	for i: int in polygon.size():
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		var direction: Vector2 = b - a
		if direction.length() < 0.000001:
			continue
		closest = minf(closest, absf(direction.cross(point - a)) / direction.length())
	return closest


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
