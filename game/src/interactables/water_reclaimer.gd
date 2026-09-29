## Water reclaimer service procedure: drain the loop, swap the filter cartridge, prime, run inspection.
class_name WaterReclaimer
extends Interactable

enum Stage { IDLE, DRAIN, CARTRIDGE, PRIME }

const CLEAN_CONTAMINATION: float = 0.05
const ANIMATION_DRAIN: StringName = &"drain"
const ANIMATION_REPLACE: StringName = &"replace_cartridge"
const ANIMATION_PRIME: StringName = &"prime"
const ANIMATION_INSPECT: StringName = &"run_inspection"

@export var cartridge_part_id: StringName = &"water_filter"

var _stage: Stage = Stage.IDLE


func get_interaction_prompt() -> String:
	match _stage:
		Stage.IDLE:
			return "Drain loop"
		Stage.DRAIN:
			return "Replace cartridge"
		Stage.CARTRIDGE:
			return "Prime loop"
		Stage.PRIME:
			return "Run inspection"
	return "Drain loop"


func _handle_interact(_player: Node) -> void:
	match _stage:
		Stage.IDLE:
			_drain_loop()
		Stage.DRAIN:
			_replace_cartridge()
		Stage.CARTRIDGE:
			_prime_loop()
		Stage.PRIME:
			_run_inspection()


func _drain_loop() -> void:
	var water: Node = _get_system(&"water_system")
	if water != null and water.has_method(&"get_status"):
		var status: Variant = water.call("get_status")
		if status is Dictionary and float((status as Dictionary).get("contamination", 0.0)) <= CLEAN_CONTAMINATION:
			_emit_sim_event(&"procedure_error", {"reason": &"clean_loop"})
			return
	_stage = Stage.DRAIN
	_play_animation(ANIMATION_DRAIN)


func _replace_cartridge() -> void:
	var stores: Node = _get_system(&"stores_system")
	if stores == null or not bool(stores.call("consume_part", cartridge_part_id, 1)):
		_emit_sim_event(&"procedure_error", {"reason": &"no_cartridge", "part_id": cartridge_part_id})
		return
	_stage = Stage.CARTRIDGE
	_play_animation(ANIMATION_REPLACE)


func _prime_loop() -> void:
	_stage = Stage.PRIME
	_play_animation(ANIMATION_PRIME)


func _run_inspection() -> void:
	var water: Node = _get_system(&"water_system")
	if water != null:
		if water.has_method(&"install_cartridge"):
			water.call("install_cartridge")
		if water.has_method(&"purge"):
			water.call("purge")
	_stage = Stage.IDLE
	_play_animation(ANIMATION_INSPECT)
	_emit_sim_event(&"reclaimer_serviced", {"part_id": cartridge_part_id})


func save_state() -> Dictionary:
	var state: Dictionary = super.save_state()
	state["system_id"] = "water_reclaimer"
	state["state_version"] = 1
	state["stage"] = int(_stage)
	return state


func load_state(state: Dictionary) -> void:
	super.load_state(state)
	_stage = clampi(int(state.get("stage", int(_stage))), int(Stage.IDLE), int(Stage.PRIME))
	_restore_visual_state()


func _restore_visual_state() -> void:
	var animator: AnimationPlayer = _get_animator()
	if animator == null:
		return
	_seek_animation_start(animator, ANIMATION_DRAIN)
	_seek_animation_end(animator, ANIMATION_REPLACE)
	_seek_animation_start(animator, ANIMATION_PRIME)
	_seek_animation_end(animator, ANIMATION_INSPECT)
	if _stage >= Stage.CARTRIDGE:
		_seek_animation_end(animator, ANIMATION_REPLACE)
	if _stage == Stage.DRAIN:
		animator.play(ANIMATION_DRAIN)
	elif _stage == Stage.PRIME:
		animator.play(ANIMATION_PRIME)


func _play_animation(animation_name: StringName) -> void:
	var animator: AnimationPlayer = _get_animator()
	if animator != null and animator.has_animation(animation_name):
		animator.play(animation_name)


func _seek_animation_end(animator: AnimationPlayer, animation_name: StringName) -> void:
	if not animator.has_animation(animation_name):
		return
	animator.play(animation_name)
	var animation: Animation = animator.get_animation(animation_name)
	animator.seek(animation.length, true)
	animator.pause()


func _seek_animation_start(animator: AnimationPlayer, animation_name: StringName) -> void:
	if not animator.has_animation(animation_name):
		return
	animator.play(animation_name)
	animator.seek(0.0, true)
	animator.pause()


func _get_animator() -> AnimationPlayer:
	return find_child("AnimationPlayer", true, false) as AnimationPlayer
