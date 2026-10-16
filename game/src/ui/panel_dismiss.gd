## Shared dismissal rule for open diegetic panels: interact (E) or pause (Esc) closes from
## anywhere, so an open readout can never strand the player with no way back. On a gamepad
## B ("dismiss") and Menu close it; A confirms the highlighted row instead of closing.
class_name PanelDismiss
extends RefCounted


static func should_dismiss(event: InputEvent, is_open: bool) -> bool:
	if not is_open:
		return false
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"dismiss"):
		return true
	return event.is_action_pressed(&"interact") and not event is InputEventJoypadButton
