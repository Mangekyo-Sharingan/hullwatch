## Hull breach sealant-patch procedure: clean the breach -> fit the patch -> apply sealant -> verify the seal.
class_name HullPatch
extends Interactable

enum Stage { CLEAN, PATCH, SEAL, VERIFY }

@export var compartment_id: StringName = &"main"
@export var sealant_part_id: StringName = &"sealant"
@export var patch_quality: float = 0.85

var _stage: Stage = Stage.CLEAN


func get_interaction_prompt() -> String:
	match _stage:
		Stage.PATCH:
			return "Fit the patch"
		Stage.SEAL:
			return "Apply sealant"
		Stage.VERIFY:
			return "Verify seal"
		_:
			return "Clean the breach" if _puncture_count() > 0 else "Inspect patch"


func _handle_interact(player: Node) -> void:
	match _stage:
		Stage.PATCH:
			_stage = Stage.SEAL
			_emit_sim_event(&"hull_patch_fitted", {"compartment_id": compartment_id})
		Stage.SEAL:
			_apply_sealant(player)
		Stage.VERIFY:
			_verify_seal()
		_:
			_clean_breach()


func _clean_breach() -> void:
	if _puncture_count() <= 0:
		_emit_sim_event(&"procedure_error", {"reason": &"no_puncture", "compartment_id": compartment_id})
		return
	_stage = Stage.PATCH
	_emit_sim_event(&"hull_patch_cleaned", {"compartment_id": compartment_id})


func _apply_sealant(player: Node) -> void:
	var carried: Node = player.call("get_carried") as Node if player != null and player.has_method(&"get_carried") else null
	var consumed: bool = carried is SealantCartridge and StringName(carried.call("get_item_id")) == sealant_part_id and bool(carried.call("consume_charge"))
	if not consumed:
		_emit_sim_event(&"procedure_error", {"reason": &"no_sealant", "part_id": sealant_part_id})
		return
	_stage = Stage.VERIFY
	_emit_sim_event(&"hull_sealant_applied", {"compartment_id": compartment_id, "part_id": sealant_part_id})


func _verify_seal() -> void:
	var hull: Node = _get_system(&"hull_system")
	var patched: bool = false
	if hull != null and hull.has_method(&"patch_puncture"):
		patched = bool(hull.call("patch_puncture", compartment_id, patch_quality))
	if not patched:
		_stage = Stage.CLEAN
		_emit_sim_event(&"procedure_error", {"reason": &"no_puncture", "compartment_id": compartment_id})
		return
	_stage = Stage.CLEAN
	_emit_sim_event(&"hull_patch_completed", {"compartment_id": compartment_id, "quality": patch_quality})


func _puncture_count() -> int:
	var hull: Node = _get_system(&"hull_system")
	if hull == null or not hull.has_method(&"get_puncture_count"):
		return 0
	return int(hull.call("get_puncture_count", compartment_id))


func save_state() -> Dictionary:
	var state: Dictionary = super.save_state()
	state["system_id"] = "hull_patch"
	state["state_version"] = 1
	state["stage"] = int(_stage)
	return state


func load_state(state: Dictionary) -> void:
	super.load_state(state)
	_stage = int(state.get("stage", int(_stage)))
