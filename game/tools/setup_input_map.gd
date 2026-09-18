## Regenerates the Input Map actions in project.godot. Re-run after editing the tables below:
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/setup_input_map.gd
extends SceneTree

const DEADZONE: float = 0.2

const KEY_BINDINGS: Dictionary = {
	&"move_forward": [KEY_W],
	&"move_back": [KEY_S],
	&"move_left": [KEY_A],
	&"move_right": [KEY_D],
	&"jump": [KEY_SPACE],
	&"crouch": [KEY_CTRL],
	&"interact": [KEY_E],
	&"flashlight": [KEY_F],
	&"toggle_boots": [KEY_Q],
	&"pause": [KEY_ESCAPE],
}

const MOUSE_BINDINGS: Dictionary = {
	&"primary": [MOUSE_BUTTON_LEFT],
	&"secondary": [MOUSE_BUTTON_RIGHT],
}


func _initialize() -> void:
	for action: StringName in KEY_BINDINGS:
		_write_action(action, _key_events(KEY_BINDINGS[action]))
	for action: StringName in MOUSE_BINDINGS:
		_write_action(action, _mouse_events(MOUSE_BINDINGS[action]))
	ProjectSettings.save()
	_verify()


func _key_events(keys: Array) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for key: int in keys:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key as Key
		events.append(event)
	return events


func _mouse_events(buttons: Array) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for button: int in buttons:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = button as MouseButton
		events.append(event)
	return events


func _write_action(action: StringName, events: Array[InputEvent]) -> void:
	ProjectSettings.set_setting("input/" + String(action), {"deadzone": DEADZONE, "events": events})


func _verify() -> void:
	var failures: int = 0
	var all_actions: Array = KEY_BINDINGS.keys() + MOUSE_BINDINGS.keys()
	for action: Variant in all_actions:
		var setting_name: String = "input/" + String(action)
		if not ProjectSettings.has_setting(setting_name):
			print("FAIL: missing action ", action)
			failures += 1
			continue
		var setting: Dictionary = ProjectSettings.get_setting(setting_name)
		var events: Array = setting.get("events", [])
		if events.is_empty():
			print("FAIL: no events for ", action)
			failures += 1
	if failures == 0:
		print("PASS: setup_input_map (%d actions)" % all_actions.size())
		quit(0)
	else:
		print("FAILURES: ", failures)
		quit(1)
