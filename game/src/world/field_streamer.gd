## Binds scene nodes to the sector sim's active stream objects: faceted asteroid meshes,
## debris clusters, glowing anomalies, collision and drift-relative positioning. Anything
## the sim drops is freed immediately, so the node set stays bounded while the ship drifts.
class_name FieldStreamer
extends Node3D

const SYNC_INTERVAL_SECONDS: float = 0.25
const GROUP_SECTOR: StringName = &"sector_system"
const META_KIND: StringName = &"kind"
const META_ID: StringName = &"object_id"

var _nodes: Dictionary = {}
var _accumulator: float = 0.0
var _rock_material: StandardMaterial3D
var _debris_material: StandardMaterial3D
var _anomaly_material: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	sync_now()


func _process(delta: float) -> void:
	for node: Node3D in _nodes.values():
		if is_instance_valid(node) and String(node.get_meta(META_KIND, "")) == "anomaly":
			node.rotate_y(delta * 0.15)
	_accumulator += delta
	if _accumulator < SYNC_INTERVAL_SECONDS:
		return
	_accumulator = 0.0
	sync_now()


func get_node_count() -> int:
	return _nodes.size()


func get_object_node(id: String) -> Node3D:
	return _nodes.get(id) as Node3D


## Reconciles the scene against the sim's active objects. Public so tests can drive it.
func sync_now() -> void:
	var sector: Node = _sector()
	if sector == null or not sector.has_method(&"get_active_objects"):
		return
	var active: Array = sector.call("get_active_objects")
	var ship: Vector3 = sector.call("get_ship_position")
	var seen: Dictionary = {}
	for entry: Dictionary in active:
		var id: String = String(entry["id"])
		seen[id] = true
		var node: Node3D = _nodes.get(id) as Node3D
		if node == null or not is_instance_valid(node):
			node = _spawn(entry)
			_nodes[id] = node
		node.position = (entry["position"] as Vector3) - ship
	for id: String in _nodes.keys():
		if seen.has(id):
			continue
		var node: Node3D = _nodes[id] as Node3D
		if node != null and is_instance_valid(node):
			node.free()
		_nodes.erase(id)


func _sector() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP_SECTOR)


func _spawn(entry: Dictionary) -> Node3D:
	var body: SpaceObject = SpaceObject.new()
	body.setup(entry)
	var id: String = String(entry["id"])
	body.name = "Object_" + id
	var kind: StringName = entry["kind"]
	var radius: float = float(entry["radius_m"])
	var object_seed: int = int(entry["seed"])
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "Shape"
	match kind:
		&"anomaly":
			mesh_instance.mesh = _make_anomaly_mesh(radius)
			mesh_instance.material_override = _anomaly_material
			var anomaly_shape: SphereShape3D = SphereShape3D.new()
			anomaly_shape.radius = radius
			shape.shape = anomaly_shape
		&"debris":
			mesh_instance.mesh = _make_debris_mesh(object_seed, radius)
			mesh_instance.material_override = _debris_material
			var debris_shape: SphereShape3D = SphereShape3D.new()
			debris_shape.radius = radius * 0.8
			shape.shape = debris_shape
		_:
			mesh_instance.mesh = _make_rock_mesh(object_seed, radius)
			mesh_instance.material_override = _rock_material
			var rock_shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
			rock_shape.points = _mesh_points(mesh_instance.mesh)
			shape.shape = rock_shape
	body.add_child(mesh_instance)
	body.add_child(shape)
	body.set_meta(META_KIND, String(kind))
	body.set_meta(META_ID, id)
	add_child(body)
	return body


func _build_materials() -> void:
	_rock_material = StandardMaterial3D.new()
	_rock_material.albedo_color = Color(0.34, 0.31, 0.28)
	_rock_material.roughness = 0.95
	_debris_material = StandardMaterial3D.new()
	_debris_material.albedo_color = Color(0.45, 0.42, 0.40)
	_debris_material.metallic = 0.6
	_debris_material.roughness = 0.5
	_anomaly_material = StandardMaterial3D.new()
	_anomaly_material.albedo_color = Color(0.05, 0.15, 0.22)
	_anomaly_material.emission_enabled = true
	_anomaly_material.emission = Color(0.35, 0.75, 1.0)
	_anomaly_material.emission_energy_multiplier = 1.8
	_anomaly_material.roughness = 0.3


## Faceted rock: a low-poly sphere with per-direction wobble, so duplicated seam vertices
## get identical offsets and the shell stays closed.
func _make_rock_mesh(object_seed: int, radius: float) -> Mesh:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 9
	sphere.rings = 5
	var arrays: Array = sphere.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in indices:
		var direction: Vector3 = vertices[index].normalized()
		var wobble: float = 1.0 + 0.28 * _wobble(direction, object_seed)
		tool.add_vertex(direction * radius * wobble)
	tool.generate_normals()
	return tool.commit()


func _make_debris_mesh(object_seed: int, radius: float) -> Mesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = object_seed
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pieces: int = 2 + absi(object_seed) % 3
	for piece: int in pieces:
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(
			rng.randf_range(radius * 0.3, radius * 0.8),
			rng.randf_range(radius * 0.2, radius * 0.6),
			rng.randf_range(radius * 0.3, radius * 0.8)
		)
		var offset: Vector3 = Vector3(
			rng.randf_range(-radius * 0.4, radius * 0.4),
			rng.randf_range(-radius * 0.4, radius * 0.4),
			rng.randf_range(-radius * 0.4, radius * 0.4)
		)
		var arrays: Array = box.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index: int in indices:
			tool.add_vertex(vertices[index] + offset)
	tool.generate_normals()
	return tool.commit()


func _make_anomaly_mesh(radius: float) -> Mesh:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 20
	sphere.rings = 12
	return sphere


func _mesh_points(mesh: Mesh) -> PackedVector3Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX]


func _wobble(direction: Vector3, object_seed: int) -> float:
	var value: float = direction.x * 12.9898 + direction.y * 78.233 + direction.z * 37.719 + float(object_seed % 997) * 0.137
	return sin(value) * 0.5 + sin(value * 2.17 + 1.3) * 0.5
