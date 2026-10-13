## Shared dismissal rule for open diegetic panels: interact (E) or pause (Esc) closes
## from anywhere, so an open readout can never strand the player with no way back.
class_name PanelDismiss
extends RefCounted


static func should_dismiss(event: InputEvent, is_open: bool) -> bool:
	if not is_open:
		return false
	return event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause")


static func scroll_readout(event: InputEvent, scroll: ScrollContainer) -> bool:
	if scroll == null or not (event is InputEventKey) or not event.pressed:
		return false
	if event.keycode == KEY_PAGEDOWN:
		scroll.scroll_vertical += 220
	elif event.keycode == KEY_PAGEUP:
		scroll.scroll_vertical -= 220
	else:
		return false
	return true
