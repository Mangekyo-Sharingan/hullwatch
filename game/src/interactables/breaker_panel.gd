## Wall breaker panel: toggles one power circuit's breaker.
class_name BreakerPanel
extends Interactable

const ANIMATION_ON: StringName = &"toggle_on"
const ANIMATION_OFF: StringName = &"toggle_off"

@export var circuit_id: StringName = &"lighting"

var _event_bus: Node
var _visual_on: bool = false


func _ready() -> void:
	_event_bus = _get_autoload(&"EventBus")
	if _event_bus != null and not _event_bus.is_connected(&"sim_event", _on_sim_event):
		_event_bus.connect(&"sim_event", _on_sim_event)
	call_deferred(&"_restore_visual_state")


func _exit_tree() -> void:
	if _event_bus != null and _event_bus.is_connected(&"sim_event", _on_sim_event):
		_event_bus.disconnect(&"sim_event", _on_sim_event)


func _handle_interact(_player: Node) -> void:
	var power: Node = _get_system(&"power_system")
	if power == null or not power.has_method(&"is_breaker_on") or not power.has_method(&"set_breaker"):
		return
	if power.has_method(&"has_circuit") and not bool(power.call("has_circuit", circuit_id)):
		return
	var new_state: bool = not bool(power.call("is_breaker_on", circuit_id))
	power.call("set_breaker", circuit_id, new_state)


func load_state(state: Dictionary) -> void:
	super.load_state(state)
	_restore_visual_state()


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name != &"breaker_toggled" or StringName(payload.get("circuit_id", &"")) != circuit_id:
		return
	if payload.has("on"):
		_set_visual_state(bool(payload["on"]))
	else:
		_restore_visual_state()


func _restore_visual_state() -> void:
	var breaker_state: Variant = _breaker_state()
	if breaker_state == null:
		return
	var on: bool = bool(breaker_state)
	_visual_on = on
	var animator: AnimationPlayer = _get_animator()
	var animation_name: StringName = ANIMATION_ON if on else ANIMATION_OFF
	if animator == null or not animator.has_animation(animation_name):
		return
	animator.play(animation_name)
	var animation: Animation = animator.get_animation(animation_name)
	animator.seek(animation.length, true)
	animator.pause()


func _set_visual_state(on: bool) -> void:
	if on == _visual_on:
		return
	_visual_on = on
	var animator: AnimationPlayer = _get_animator()
	var animation_name: StringName = ANIMATION_ON if on else ANIMATION_OFF
	if animator != null and animator.has_animation(animation_name):
		animator.play(animation_name)


func _breaker_state() -> Variant:
	var power: Node = _get_system(&"power_system")
	if power == null or not power.has_method(&"is_breaker_on"):
		return null
	if power.has_method(&"has_circuit") and not bool(power.call("has_circuit", circuit_id)):
		return null
	return bool(power.call("is_breaker_on", circuit_id))


func _get_animator() -> AnimationPlayer:
	return find_child("AnimationPlayer", true, false) as AnimationPlayer
