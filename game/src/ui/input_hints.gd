## Names the control a hint refers to on whichever device the player used last, so prompts read
## "A" on a gamepad and "E" on a keyboard. Hint text carries {action} or {phrase} tokens and
## `expand` fills them; `InputDeviceTracker` (autoload) keeps `gamepad_active` current.
class_name InputHints
extends RefCounted

const AXIS_ACTIVITY_THRESHOLD: float = 0.5
const MOUSE_ACTIVITY_PIXELS: float = 2.0

const BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "VIEW", JOY_BUTTON_START: "MENU",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-PAD UP", JOY_BUTTON_DPAD_DOWN: "D-PAD DOWN",
	JOY_BUTTON_DPAD_LEFT: "D-PAD LEFT", JOY_BUTTON_DPAD_RIGHT: "D-PAD RIGHT",
}
const AXIS_NAMES: Dictionary = {
	JOY_AXIS_LEFT_X: "LEFT STICK", JOY_AXIS_LEFT_Y: "LEFT STICK",
	JOY_AXIS_RIGHT_X: "RIGHT STICK", JOY_AXIS_RIGHT_Y: "RIGHT STICK",
	JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT",
}
const MOUSE_NAMES: Dictionary = {
	MOUSE_BUTTON_LEFT: "LEFT CLICK", MOUSE_BUTTON_RIGHT: "RIGHT CLICK", MOUSE_BUTTON_MIDDLE: "WHEEL CLICK",
	MOUSE_BUTTON_WHEEL_UP: "WHEEL UP", MOUSE_BUTTON_WHEEL_DOWN: "WHEEL DOWN",
}
const KEY_NAMES: Dictionary = {"ESCAPE": "ESC", "PAGE UP": "PGUP", "PAGE DOWN": "PGDN"}

## Descriptions of several controls at once: [keyboard and mouse text, gamepad text].
const PHRASES: Dictionary = {
	&"move": ["W A S D", "LEFT STICK"],
	&"look": ["MOUSE", "RIGHT STICK"],
	&"browse": ["WHEEL", "D-PAD"],
	&"browse_arrows": ["WHEEL / ARROWS", "D-PAD"],
	&"confirm": ["ROW CLICK / WHEEL CLICK / ENTER", "A"],
	&"browse_tight": ["WHEEL/ARROWS", "D-PAD"],
	&"confirm_menu": ["CLICK / WHEEL CLICK / ENTER", "A"],
	&"confirm_click": ["CLICK", "A"],
	&"confirm_enter": ["ENTER", "A"],
	&"close": ["E/ESC", "B/MENU"],
	&"close_spaced": ["E / ESC", "B / MENU"],
	&"back": ["ESC", "B/MENU"],
	&"close_only": ["ESC", "MENU"],
	&"text_scroll": ["PGUP/PGDN", "D-PAD LEFT/RIGHT"],
	&"text_scroll_short": ["PGUP/DN", "D-PAD LEFT/RIGHT"],
	&"roll": ["Z/C", "D-PAD LEFT/RIGHT"],
	&"decrease": ["RIGHT CLICK", "B"],
	&"up_down": ["SPACE/CTRL", "RB/LB"],
}

static var gamepad_active: bool = false
static var _token_pattern: RegEx = null


static func set_gamepad_active(active: bool) -> void:
	gamepad_active = active


## Updates the active device from a raw input event; never consumes it.
static func note_event(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			gamepad_active = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= AXIS_ACTIVITY_THRESHOLD:
			gamepad_active = true
	elif event is InputEventKey:
		if (event as InputEventKey).pressed:
			gamepad_active = false
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			gamepad_active = false
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() >= MOUSE_ACTIVITY_PIXELS:
			gamepad_active = false


## The text printed on the control bound to `action` for the device in use; falls back to the
## other device when the action has nothing bound to the active one.
static func label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return String(action).to_upper()
	var pad: String = ""
	var keyboard: String = ""
	for event: InputEvent in InputMap.action_get_events(action):
		if pad == "" and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			pad = _pad_name(event)
		elif keyboard == "" and (event is InputEventKey or event is InputEventMouseButton):
			keyboard = _keyboard_name(event)
	var preferred: String = pad if gamepad_active else keyboard
	if preferred != "":
		return preferred
	return keyboard if gamepad_active else pad


## Fills {action} and {phrase} tokens; unknown tokens are left as written.
static func expand(text: String) -> String:
	if text.find("{") < 0:
		return text
	if _token_pattern == null:
		_token_pattern = RegEx.create_from_string("\\{([a-z_]+)\\}")
	var out: String = ""
	var cursor: int = 0
	for found: RegExMatch in _token_pattern.search_all(text):
		out += text.substr(cursor, found.get_start() - cursor)
		var name: StringName = StringName(found.get_string(1))
		if PHRASES.has(name):
			out += String((PHRASES[name] as Array)[1 if gamepad_active else 0])
		elif InputMap.has_action(name):
			out += label(name)
		else:
			out += found.get_string()
		cursor = found.get_end()
	return out + text.substr(cursor)


static func _pad_name(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		return String(BUTTON_NAMES.get((event as InputEventJoypadButton).button_index, "BUTTON"))
	return String(AXIS_NAMES.get((event as InputEventJoypadMotion).axis, "STICK"))


static func _keyboard_name(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return String(MOUSE_NAMES.get((event as InputEventMouseButton).button_index, "MOUSE"))
	var name: String = (event as InputEventKey).as_text_physical_keycode().to_upper()
	return String(KEY_NAMES.get(name, name))
