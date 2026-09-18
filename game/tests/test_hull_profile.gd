## Unit tests for the faceted-hull polygon math: outlines, CCW handling, mitered
## offsets/insets and profile rings. Pure functions, no scene tree.
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
	if _failures == 0:
		print("PASS: test_hull_profile")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


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
