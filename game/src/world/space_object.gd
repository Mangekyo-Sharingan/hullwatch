## A streamed field object the operator can work: mining needs a hull cutter and an empty
## sample canister. Extraction is recorded in the sector sim, so yields persist while the
## object is out of the stream window.
class_name SpaceObject
extends Interactable

const CANISTER_CAPACITY_FALLBACK: float = 6.0
const CUTTER_ITEM_ID: StringName = &"cutter"
const SCANNER_ITEM_ID: StringName = &"scanner"
const ANOMALY_STUDY_CHUNK: float = 2.0

@export var object_id: String = ""
@export var kind: StringName = &"asteroid"
@export var resource: StringName = &"ore"


func setup(entry: Dictionary) -> void:
	object_id = String(entry.get("id", ""))
	kind = entry.get("kind", &"asteroid")
	resource = entry.get("resource", &"ore")


func get_interaction_prompt() -> String:
	if _remaining() <= 0.0:
		return "Depleted %s" % String(kind)
	match kind:
		&"anomaly":
			return "Study anomaly (needs scanner)"
		&"debris":
			return "Cut debris (needs cutter + canister)"
		_:
			return "Mine %s (needs cutter + canister)" % String(resource).to_upper()


func get_remaining() -> float:
	return _remaining()


func _handle_interact(player: Node) -> void:
	var remaining: float = _remaining()
	if remaining <= 0.0:
		_emit_sim_event(&"procedure_error", {"reason": &"depleted", "object_id": object_id})
		return
	if player == null or not player.has_method(&"get_carried_item_id"):
		return
	if kind == &"anomaly":
		_study_anomaly(player, remaining)
		return
	if not _has_cutter(player):
		_emit_sim_event(&"procedure_error", {"reason": &"no_cutter", "object_id": object_id})
		return
	var canister: Node = _carried_canister(player)
	if canister == null:
		_emit_sim_event(&"procedure_error", {"reason": &"no_canister", "object_id": object_id})
		return
	var sector: Node = _sector()
	if sector == null:
		return
	var capacity: float = CANISTER_CAPACITY_FALLBACK
	if canister.has_method(&"get_capacity"):
		capacity = float(canister.call("get_capacity"))
	var wanted: float = minf(capacity, remaining)
	var removed: float = float(sector.call("record_mined", object_id, wanted))
	if removed <= 0.0:
		_emit_sim_event(&"procedure_error", {"reason": &"depleted", "object_id": object_id})
		return
	var taken: float = float(canister.call("load_amount", resource, removed))
	_emit_sim_event(&"sample_taken", {
		"object_id": object_id,
		"resource": String(resource),
		"units": taken,
		"remaining": _remaining(),
	})


## Anomalies are read, not cut: the field scanner in hand pulls a survey chunk of
## exotic material straight into the cargo hold and logs the reading.
func _study_anomaly(player: Node, remaining: float) -> void:
	if StringName(player.call("get_carried_item_id")) != SCANNER_ITEM_ID:
		_emit_sim_event(&"procedure_error", {"reason": &"no_scanner", "object_id": object_id})
		return
	var sector: Node = _sector()
	if sector == null:
		return
	var cargo: Node = _cargo()
	if cargo == null or not cargo.has_method(&"add_material"):
		return
	var free: float = INF
	if cargo.has_method(&"get_free_units"):
		free = float(cargo.call("get_free_units"))
	var wanted: float = minf(ANOMALY_STUDY_CHUNK, minf(remaining, free))
	if wanted <= 0.0:
		_emit_sim_event(&"procedure_error", {"reason": &"cargo_full", "object_id": object_id})
		return
	var removed: float = float(sector.call("record_mined", object_id, wanted))
	if removed <= 0.0:
		_emit_sim_event(&"procedure_error", {"reason": &"depleted", "object_id": object_id})
		return
	var added: float = float(cargo.call("add_material", resource, removed))
	_emit_sim_event(&"anomaly_logged", {
		"object_id": object_id,
		"resource": String(resource),
		"units": added,
		"remaining": _remaining(),
	})


func _has_cutter(player: Node) -> bool:
	if player == null:
		return false
	if player.has_method(&"has_suit_cutter"):
		return bool(player.call("has_suit_cutter"))
	if player.has_method(&"get_carried_item_id"):
		return StringName(player.call("get_carried_item_id")) == CUTTER_ITEM_ID
	return false


func _carried_canister(player: Node) -> Node:
	if not player.has_method(&"get_carried"):
		return null
	var item: Node = player.call("get_carried") as Node
	if item == null or not item.has_method(&"is_empty"):
		return null
	if not bool(item.call("is_empty")):
		return null
	return item


func _remaining() -> float:
	var sector: Node = _sector()
	if sector == null or not sector.has_method(&"get_remaining_yield"):
		return 0.0
	return float(sector.call("get_remaining_yield", object_id))


func _sector() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"sector_system")


func _cargo() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"cargo_system")
