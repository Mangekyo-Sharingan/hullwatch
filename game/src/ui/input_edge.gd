## A gamepad trigger or stick reports many events while it is pushed past an action's threshold,
## and each one counts as "pressed". `fresh` is true only on the event that crosses the threshold,
## so one squeeze is one press. Buttons, keys and mouse buttons pass straight through.
class_name InputEdge
extends RefCounted

static var _held: Dictionary = {}


static func fresh(event: InputEvent, action: StringName) -> bool:
	if not event is InputEventJoypadMotion:
		return event.is_action_pressed(action)
	if not event.is_action(action):
		return false
	var down: bool = event.is_action_pressed(action)
	var was_down: bool = bool(_held.get(action, false))
	_held[action] = down
	return down and not was_down


static func reset() -> void:
	_held.clear()
