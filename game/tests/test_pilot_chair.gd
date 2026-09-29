## Center pilot station: floor support, proximity swivel, seat interaction, and legacy save load.
extends SceneTree

const CHAIR_SCENE: String = "res://assets/models/hullwatch/cockpit/hw_pilot_chair.glb"

class MockPlayer extends Node3D:
	var entered: bool = false

	func enter_pilot_seat(chair: PilotChair) -> bool:
		entered = chair != null
		return entered

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
	var model: Node3D = model_scene.instantiate() as Node3D
	model.name = "Model"
	chair.add_child(model)
	root.add_child(chair)
	await process_frame

	var animator: AnimationPlayer = chair.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var base: CollisionShape3D = chair.get_node_or_null(^"BaseShape") as CollisionShape3D
	var back: CollisionShape3D = chair.get_node_or_null(^"BackShape") as CollisionShape3D
	var seat: CollisionShape3D = chair.get_node_or_null(^"SeatShape") as CollisionShape3D
	_check(animator != null and animator.has_animation(&"deploy") and animator.has_animation(&"stow"), "chair keeps authored fold clips")
	_check(base != null and not base.disabled, "floor pedestal has collision")
	_check(back != null and not back.disabled and seat != null and seat.disabled, "folded seat clears its collision before the first turn")
	_check(chair.get_interaction_prompt() == "Take pilot seat", "chair invites boarding")
	_check(chair.is_deployed(), "pilot seat starts deployed")

	var player: MockPlayer = MockPlayer.new()
	player.add_to_group(&"player")
	player.position = Vector3(0.0, 0.0, 1.2)
	root.add_child(player)
	var saw_folded_turn: bool = false
	var timeout: SceneTreeTimer = create_timer(6.0)
	while timeout.time_left > 0.0 and not _chair_ready_at(chair, model, PI):
		await process_frame
		if bool(chair.get("_seat_stowed")) and absf(model.rotation.y) > 0.01:
			saw_folded_turn = true
	_check(saw_folded_turn, "seat stays withdrawn while the chair turns")
	_check(_chair_ready_at(chair, model, PI), "chair swivels and deploys toward nearby operator")
	_check(seat != null and seat.position.z < 0.0, "seat collider follows swivel")
	_check(seat != null and not seat.disabled, "deployed seat collider returns after the turn")
	chair.interact(player)
	_check(player.entered, "chair requests player seated mode")
	chair.set_occupied(true)
	timeout = create_timer(6.0)
	while timeout.time_left > 0.0 and not _chair_ready_at(chair, model, 0.0):
		await process_frame
	_check(chair.is_occupied() and _chair_ready_at(chair, model, 0.0), "occupied chair folds, returns forward, and deploys")
	chair.set_occupied(false)

	chair.load_state({"enabled": true, "deployed": false})
	_check(chair.is_deployed() and not chair.is_occupied(), "legacy folded save restores usable station")
	_check(bool(chair.save_state().get("deployed", false)), "new save keeps pilot station deployed")

	player.free()
	chair.free()
	_finish()


func _chair_ready_at(chair: PilotChair, model: Node3D, angle: float) -> bool:
	return (
		not bool(chair.get("_seat_animating"))
		and not bool(chair.get("_boarding"))
		and not bool(chair.get("_seat_stowed"))
		and absf(wrapf(angle - model.rotation.y, -PI, PI)) < 0.02
	)


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
