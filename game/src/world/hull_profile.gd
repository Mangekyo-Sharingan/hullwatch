## Planar polygon math for the faceted hull: chamfered outlines, mitered offsets and
## profile rings. Pure functions, no scene tree — unit-testable headless.
class_name HullProfile
extends RefCounted

const EPSILON: float = 0.000001
const MITER_LIMIT_FACTOR: float = 4.0


## Counter-clockwise chamfered rectangle outline in the XZ plane (x = east, y = z).
static func rectangle_outline(min_xz: Vector2, max_xz: Vector2, chamfer: float = 0.0) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var width: float = max_xz.x - min_xz.x
	var depth: float = max_xz.y - min_xz.y
	if width <= EPSILON or depth <= EPSILON:
		return points
	var cut: float = clampf(chamfer, 0.0, minf(width, depth) * 0.499)
	if cut <= EPSILON:
		points.append(Vector2(min_xz.x, min_xz.y))
		points.append(Vector2(max_xz.x, min_xz.y))
		points.append(Vector2(max_xz.x, max_xz.y))
		points.append(Vector2(min_xz.x, max_xz.y))
		return points
	points.append(Vector2(min_xz.x + cut, min_xz.y))
	points.append(Vector2(max_xz.x - cut, min_xz.y))
	points.append(Vector2(max_xz.x, min_xz.y + cut))
	points.append(Vector2(max_xz.x, max_xz.y - cut))
	points.append(Vector2(max_xz.x - cut, max_xz.y))
	points.append(Vector2(min_xz.x + cut, max_xz.y))
	points.append(Vector2(min_xz.x, max_xz.y - cut))
	points.append(Vector2(min_xz.x, min_xz.y + cut))
	return points


static func signed_area(polygon: PackedVector2Array) -> float:
	var total: float = 0.0
	var count: int = polygon.size()
	for i: int in count:
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % count]
		total += a.x * b.y - b.x * a.y
	return total * 0.5


static func ensure_ccw(polygon: PackedVector2Array) -> PackedVector2Array:
	if polygon.size() < 3 or signed_area(polygon) >= 0.0:
		return polygon
	var reversed: PackedVector2Array = PackedVector2Array()
	for i: int in range(polygon.size() - 1, -1, -1):
		reversed.append(polygon[i])
	return reversed


## Mitered offset: positive distance grows the polygon outward, negative shrinks it.
## For convex polygons with small offsets this preserves every corner as a mitre joint.
static func offset_polygon(polygon: PackedVector2Array, distance: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if polygon.size() < 3 or absf(distance) <= EPSILON:
		return polygon
	var source: PackedVector2Array = ensure_ccw(polygon)
	var count: int = source.size()
	for i: int in count:
		var previous: Vector2 = source[(i - 1 + count) % count]
		var current: Vector2 = source[i]
		var following: Vector2 = source[(i + 1) % count]
		var normal_in: Vector2 = _outward_normal(previous, current)
		var normal_out: Vector2 = _outward_normal(current, following)
		var bisector: Vector2 = normal_in + normal_out
		if bisector.length() <= EPSILON:
			result.append(current + normal_in * distance)
			continue
		bisector = bisector.normalized()
		var cos_half: float = bisector.dot(normal_in)
		if absf(cos_half) <= EPSILON:
			result.append(current + normal_in * distance)
			continue
		var miter_length: float = clampf(
			distance / cos_half,
			-absf(distance) * MITER_LIMIT_FACTOR,
			absf(distance) * MITER_LIMIT_FACTOR
		)
		result.append(current + bisector * miter_length)
	return result


static func inset_polygon(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	return offset_polygon(polygon, -absf(amount))


## Vertical profile rings: every entry is (height_y, inset) — the plan polygon inset at
## that height. Consecutive rings form the wall bands of the prism.
static func profile_rings(outline: PackedVector2Array, profile: Array[Vector2]) -> Array[PackedVector2Array]:
	var rings: Array[PackedVector2Array] = []
	for ring: Vector2 in profile:
		rings.append(inset_polygon(outline, ring.y))
	return rings


static func _outward_normal(from_point: Vector2, to_point: Vector2) -> Vector2:
	var direction: Vector2 = to_point - from_point
	if direction.length() <= EPSILON:
		return Vector2.ZERO
	return Vector2(direction.y, -direction.x).normalized()
