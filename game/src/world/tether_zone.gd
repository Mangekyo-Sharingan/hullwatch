## Area outside the airlock: stepping onto the hull auto-clips the tether to the nearest anchor.
extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body == null or not body.has_method(&"attach_tether"):
		return
	if body.has_method(&"is_tethered") and bool(body.call(&"is_tethered")):
		return
	var anchor: Node3D = _nearest_anchor(body.global_position)
	if anchor != null:
		body.call("attach_tether", anchor)


func _nearest_anchor(from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"tether_anchor"):
		var anchor: Node3D = node as Node3D
		if anchor == null:
			continue
		var distance: float = anchor.global_position.distance_to(from)
		if distance < best_distance:
			best_distance = distance
			best = anchor
	return best
