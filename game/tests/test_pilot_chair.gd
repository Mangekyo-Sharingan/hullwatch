## Pilot chair folds between a wall stowed pose and a usable seat, and restores its saved pose.
extends SceneTree

const CHAIR_SCENE: String = "res://assets/models/hullwatch/cockpit/hw_pilot_chair.glb"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var chair: PilotChair = PilotChair.new()
	var model_scene: PackedScene = load(CHAIR_SCENE) as PackedScene
	_check(model_scene != null, "authored pilot chair model loads")
	if model_scene == null:
		_finish()
		return
	chair.add_child(model_scene.instantiate())
	root.add_child(chair)
	await process_frame

	var animator: AnimationPlayer = chair.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var frame: CollisionShape3D = chair.get_node_or_null(^"FrameShape") as CollisionShape3D
	var seat: CollisionShape3D = chair.get_node_or_null(^"SeatShape") as CollisionShape3D
	_check(animator != null and animator.has_animation(&"deploy") and animator.has_animation(&"stow"), "chair imports deploy and stow clips")
	_check(frame != null and not frame.disabled, "wall frame remains solid while stowed")
	_check(seat != null and seat.disabled, "seat collision stays clear while stowed")
	_check(chair.get_interaction_prompt() == "Deploy pilot chair", "stowed chair offers deployment")

	chair.interact(null)
	_check(chair.is_deployed(), "interaction requests deployment")
	_check(animator != null and animator.current_animation == &"deploy", "deployment plays the authored clip")
	if animator != null:
		animator.advance(animator.get_current_animation_length() + 0.1)
	_check(seat != null and not seat.disabled, "seat collider enables after deployment")
	_check(chair.get_interaction_prompt() == "Stow pilot chair", "deployed chair offers stowing")
	var deployed_state: Dictionary = chair.save_state()

	chair.interact(null)
	_check(not chair.is_deployed(), "interaction requests stowing")
	_check(animator != null and animator.current_animation == &"stow", "stowing plays its authored clip")
	if animator != null:
		animator.advance(animator.get_current_animation_length() + 0.1)
	_check(seat != null and seat.disabled, "seat collider clears after stowing")

	chair.load_state(deployed_state)
	_check(chair.is_deployed(), "save restore recovers deployed state")
	_check(seat != null and not seat.disabled, "restored deployed pose has its seat collider")
	var restored_at_endpoint: bool = animator != null and is_equal_approx(
		animator.current_animation_position,
		animator.get_animation(&"deploy").length
	)
	_check(restored_at_endpoint, "restored pose seeks to the clip endpoint")

	chair.free()
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_pilot_chair")
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
