## Wall computer: a blade-style terminal that slides out of its wall slot and folds down to
## face the operator when used, and stows flush again when the readout closes.
class_name WallComputer
extends ComputerTerminal

const DEPLOY_ANIMATION: StringName = &"unfold"
const DEPLOYED_SIZE: Vector3 = Vector3(0.45, 0.50, 0.60)
const DEPLOYED_CENTER_X: float = 0.145

var _animator: AnimationPlayer
var _deploy_shape: CollisionShape3D
var _deploy_requested: bool = false


func _ready() -> void:
	terminal_title = "WALL TERMINAL"
	programs = [&"status", &"control", &"log"]
	default_program = &"status"
	phosphor = CrtPanel.PHOSPHOR_GREEN
	ui_layer = 12
	super._ready()
	_ensure_deploy_shape()
	var animator: AnimationPlayer = _get_animator()
	if animator != null and not animator.animation_finished.is_connected(_on_animation_finished):
		animator.animation_finished.connect(_on_animation_finished)


func get_interaction_prompt() -> String:
	return "Close terminal" if is_open() else "Use terminal"


func _on_terminal_opened() -> void:
	_set_deployed(true)


func _on_terminal_closed() -> void:
	_set_deployed(false)


func _set_deployed(deploy: bool) -> void:
	_deploy_requested = deploy
	var animator: AnimationPlayer = _get_animator()
	if animator != null and animator.has_animation(DEPLOY_ANIMATION):
		if deploy:
			animator.play(DEPLOY_ANIMATION)
		else:
			animator.play_backwards(DEPLOY_ANIMATION)
		return
	_apply_deployed_collision(deploy)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == DEPLOY_ANIMATION:
		_apply_deployed_collision(_deploy_requested)


func _apply_deployed_collision(deployed: bool) -> void:
	if _deploy_shape != null:
		_deploy_shape.disabled = not deployed


## The pulled-out tray is real geometry the operator can bump into; it only exists while
## the terminal is open. The prop's own slim wall box covers the stowed state.
func _ensure_deploy_shape() -> void:
	if _deploy_shape != null:
		return
	var box: BoxShape3D = BoxShape3D.new()
	box.size = DEPLOYED_SIZE
	_deploy_shape = CollisionShape3D.new()
	_deploy_shape.name = "DeployedShape"
	_deploy_shape.shape = box
	var side: float = 1.0 if position.x < 0.0 else -1.0
	_deploy_shape.position = Vector3(side * DEPLOYED_CENTER_X, 0.05, 0.0)
	_deploy_shape.disabled = true
	add_child(_deploy_shape)


func _get_animator() -> AnimationPlayer:
	if _animator == null or not is_instance_valid(_animator):
		_animator = find_child("AnimationPlayer", true, false) as AnimationPlayer
	return _animator
