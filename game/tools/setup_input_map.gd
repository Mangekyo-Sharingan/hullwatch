## Regenerates the Input Map actions in project.godot. Re-run after editing the tables below:
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/setup_input_map.gd
##
## Gamepad layout (Xbox naming; Steam Deck's controller reports the same buttons):
##   left stick move/thrust, right stick look, A interact/confirm, B back/drop, X flashlight,
##   Y magnetic boots, LB crouch/down, RB jump/up, LT drop, RT primary, L3 brake/leave seat,
##   View tether, Menu pause, D-pad up/down menu rows, D-pad left/right roll or readout text.
extends SceneTree

const DEADZONE: float = 0.25
const TRIGGER_DEADZONE: float = 0.5
const TRIGGER_ACTIONS: Array[StringName] = [&"primary", &"secondary"]
const ALL_DEVICES: int = -1

const KEY_BINDINGS: Dictionary = {
	&"move_forward": [KEY_W],
	&"move_back": [KEY_S],
	&"move_left": [KEY_A],
	&"move_right": [KEY_D],
	&"jump": [KEY_SPACE],
	&"crouch": [KEY_CTRL],
	&"brake": [KEY_SHIFT],
	&"roll_left": [KEY_Z],
	&"roll_right": [KEY_C],
	&"interact": [KEY_E],
	&"leave_seat": [KEY_X],
	&"flashlight": [KEY_F],
	&"toggle_boots": [KEY_Q],
	&"toggle_tether": [KEY_T],
	&"pause": [KEY_ESCAPE],
	&"readout_scroll_up": [KEY_PAGEUP],
	&"readout_scroll_down": [KEY_PAGEDOWN],
}

const MOUSE_BINDINGS: Dictionary = {
	&"primary": [MOUSE_BUTTON_LEFT],
	&"secondary": [MOUSE_BUTTON_RIGHT],
	&"menu_prev": [MOUSE_BUTTON_WHEEL_UP],
	&"menu_next": [MOUSE_BUTTON_WHEEL_DOWN],
	&"menu_select": [MOUSE_BUTTON_MIDDLE],
}

const JOY_BUTTON_BINDINGS: Dictionary = {
	&"interact": [JOY_BUTTON_A],
	&"menu_select": [JOY_BUTTON_A],
	&"secondary": [JOY_BUTTON_B],
	&"dismiss": [JOY_BUTTON_B],
	&"flashlight": [JOY_BUTTON_X],
	&"toggle_boots": [JOY_BUTTON_Y],
	&"crouch": [JOY_BUTTON_LEFT_SHOULDER],
	&"jump": [JOY_BUTTON_RIGHT_SHOULDER],
	&"brake": [JOY_BUTTON_LEFT_STICK],
	&"leave_seat": [JOY_BUTTON_LEFT_STICK],
	&"toggle_tether": [JOY_BUTTON_BACK],
	&"pause": [JOY_BUTTON_START],
	&"roll_left": [JOY_BUTTON_DPAD_LEFT],
	&"roll_right": [JOY_BUTTON_DPAD_RIGHT],
	&"readout_scroll_up": [JOY_BUTTON_DPAD_LEFT],
	&"readout_scroll_down": [JOY_BUTTON_DPAD_RIGHT],
}

## Each entry is [axis, direction]; the action fires while the axis is pushed that way.
const JOY_AXIS_BINDINGS: Dictionary = {
	&"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
	&"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
	&"move_forward": [[JOY_AXIS_LEFT_Y, -1.0]],
	&"move_back": [[JOY_AXIS_LEFT_Y, 1.0]],
	&"look_left": [[JOY_AXIS_RIGHT_X, -1.0]],
	&"look_right": [[JOY_AXIS_RIGHT_X, 1.0]],
	&"look_up": [[JOY_AXIS_RIGHT_Y, -1.0]],
	&"look_down": [[JOY_AXIS_RIGHT_Y, 1.0]],
	&"primary": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	&"secondary": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
}


func _initialize() -> void:
	var events_by_action: Dictionary = {}
	_collect(events_by_action, KEY_BINDINGS, _key_event)
	_collect(events_by_action, MOUSE_BINDINGS, _mouse_event)
	_collect(events_by_action, JOY_BUTTON_BINDINGS, _joy_button_event)
	_collect(events_by_action, JOY_AXIS_BINDINGS, _joy_axis_event)
	for action: StringName in events_by_action:
		var deadzone: float = TRIGGER_DEADZONE if action in TRIGGER_ACTIONS else DEADZONE
		ProjectSettings.set_setting("input/" + String(action), {"deadzone": deadzone, "events": events_by_action[action]})
	ProjectSettings.save()
	_verify(events_by_action)


func _collect(into: Dictionary, table: Dictionary, make: Callable) -> void:
	for action: StringName in table:
		if not into.has(action):
			into[action] = [] as Array[InputEvent]
		for spec: Variant in table[action]:
			(into[action] as Array).append(make.call(spec))


func _key_event(key: int) -> InputEvent:
	var event: InputEventKey = InputEventKey.new()
	event.device = ALL_DEVICES
	event.physical_keycode = key as Key
	return event


func _mouse_event(button: int) -> InputEvent:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.device = ALL_DEVICES
	event.button_index = button as MouseButton
	return event


func _joy_button_event(button: int) -> InputEvent:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = ALL_DEVICES
	event.button_index = button as JoyButton
	return event


func _joy_axis_event(spec: Array) -> InputEvent:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.device = ALL_DEVICES
	event.axis = int(spec[0]) as JoyAxis
	event.axis_value = float(spec[1])
	return event


func _verify(events_by_action: Dictionary) -> void:
	var failures: int = 0
	for action: Variant in events_by_action:
		var setting_name: String = "input/" + String(action)
		if not ProjectSettings.has_setting(setting_name):
			print("FAIL: missing action ", action)
			failures += 1
			continue
		var events: Array = (ProjectSettings.get_setting(setting_name) as Dictionary).get("events", [])
		if events.is_empty():
			print("FAIL: no events for ", action)
			failures += 1
	if failures == 0:
		print("PASS: setup_input_map (%d actions)" % events_by_action.size())
		quit(0)
	else:
		print("FAILURES: ", failures)
		quit(1)
