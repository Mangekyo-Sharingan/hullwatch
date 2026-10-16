## ScrollMenu component: browsing, wrapping, selection signals, item refresh.
extends SceneTree

var _failures: int = 0
var _selected: Array[int] = []
var _highlighted: Array[int] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_test_flow()
	_test_wrap_and_clamp()
	_test_set_items()
	_test_empty_items()
	_test_dismiss_rule()
	_test_gamepad_dismiss_and_triggers()
	_test_hints_follow_the_device()
	await _test_row_click()
	await _test_selection_detaches_menu()
	_finish()


func _test_flow() -> void:
	var menu := ScrollMenu.new()
	root.add_child(menu)
	menu.option_selected.connect(_on_selected)
	menu.option_highlighted.connect(_on_highlighted)
	var items: PackedStringArray = PackedStringArray(["ALPHA", "BETA", "GAMMA"])
	menu.setup("TEST", items)

	_check(not menu.is_open(), "menu starts closed")
	_check(menu.get_items().size() == 3, "menu holds the items")
	_check(menu.get_highlighted_index() == 0, "first item is highlighted")
	_check(menu.get_selected_index() == -1, "nothing is selected yet")

	menu.open()
	_check(menu.is_open(), "menu opens")
	menu.move_selection(1)
	_check(menu.get_highlighted_index() == 1 and menu.get_highlighted_text() == "BETA", "browsing moves the highlight")
	_check(_highlighted == [1], "highlight signal reports the new index")

	menu.confirm()
	_check(menu.get_selected_index() == 1, "confirm records the selection")
	_check(_selected == [1], "select signal reports the index")

	menu.close()
	_check(not menu.is_open(), "menu closes")
	menu.free()


func _test_wrap_and_clamp() -> void:
	var items: PackedStringArray = PackedStringArray(["ONE", "TWO", "THREE"])
	var menu := ScrollMenu.new()
	root.add_child(menu)
	menu.setup("WRAP", items, true)
	menu.move_selection(-1)
	_check(menu.get_highlighted_index() == 2, "wrapping menu wraps backwards")
	menu.move_selection(1)
	_check(menu.get_highlighted_index() == 0, "wrapping menu wraps forwards")

	var clamped := ScrollMenu.new()
	root.add_child(clamped)
	clamped.setup("CLAMP", items, false)
	clamped.move_selection(-1)
	_check(clamped.get_highlighted_index() == 0, "clamped menu holds the first item")
	clamped.move_selection(9)
	_check(clamped.get_highlighted_index() == 2, "clamped menu holds the last item")
	menu.free()
	clamped.free()


func _test_set_items() -> void:
	var menu := ScrollMenu.new()
	root.add_child(menu)
	var items: PackedStringArray = PackedStringArray(["A", "B", "C", "D"])
	menu.setup("ITEMS", items)
	menu.move_selection(2)
	var refreshed: PackedStringArray = PackedStringArray(["A", "B", "C", "D"])
	menu.set_items(refreshed)
	_check(menu.get_highlighted_index() == 2, "refreshing items preserves the highlight")

	menu.setup("SHORTER", PackedStringArray(["ONLY"]))
	_check(menu.get_highlighted_index() == 0, "setup resets the highlight")
	menu.free()


func _test_empty_items() -> void:
	var menu := ScrollMenu.new()
	root.add_child(menu)
	menu.setup("EMPTY", PackedStringArray())
	menu.move_selection(1)
	menu.confirm()
	_check(menu.get_highlighted_index() == -1, "empty menu reports no highlight")
	menu.free()


func _test_dismiss_rule() -> void:
	var press_interact := InputEventAction.new()
	press_interact.action = &"interact"
	press_interact.pressed = true
	var press_pause := InputEventAction.new()
	press_pause.action = &"pause"
	press_pause.pressed = true
	var release := InputEventAction.new()
	release.action = &"interact"
	release.pressed = false

	_check(not PanelDismiss.should_dismiss(press_interact, false), "dismiss: closed panels ignore interact")
	_check(PanelDismiss.should_dismiss(press_interact, true), "dismiss: interact closes an open panel")
	_check(PanelDismiss.should_dismiss(press_pause, true), "dismiss: pause closes an open panel")
	_check(not PanelDismiss.should_dismiss(release, true), "dismiss: releases do not close")


func _pad_button(index: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event


func _trigger(value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = value
	return event


## A both confirms a menu row and is "interact"; B both closes a readout and drops a tool.
## A readout must close on B or Menu but never on A, and one trigger squeeze is one press.
func _test_gamepad_dismiss_and_triggers() -> void:
	_check(not PanelDismiss.should_dismiss(_pad_button(JOY_BUTTON_A), true), "gamepad: A confirms a row instead of closing the readout")
	_check(PanelDismiss.should_dismiss(_pad_button(JOY_BUTTON_B), true), "gamepad: B closes an open readout")
	_check(PanelDismiss.should_dismiss(_pad_button(JOY_BUTTON_START), true), "gamepad: Menu closes an open readout")
	InputEdge.reset()
	var presses: int = 0
	for value: float in [0.2, 0.4, 0.6, 0.8, 1.0, 1.0, 0.7, 0.3, 0.0, 0.9]:
		if InputEdge.fresh(_trigger(value), &"primary"):
			presses += 1
	_check(presses == 2, "gamepad: a squeeze is one press, so release and squeeze again makes two (got %d)" % presses)
	_check(InputEdge.fresh(_pad_button(JOY_BUTTON_A), &"interact"), "gamepad: buttons pass straight through edge detection")


func _test_hints_follow_the_device() -> void:
	InputHints.set_gamepad_active(false)
	var keyboard: String = InputHints.expand("{interact} / {toggle_boots} / {jump} / {secondary}")
	InputHints.note_event(_pad_button(JOY_BUTTON_A))
	_check(InputHints.gamepad_active, "hints: a gamepad press switches prompts to gamepad names")
	var pad: String = InputHints.expand("{interact} / {toggle_boots} / {jump} / {secondary}")
	_check(keyboard == "E / Q / SPACE / RIGHT CLICK" and pad == "A / Y / RB / B", "hints: the same text names keys, then buttons (%s | %s)" % [keyboard, pad])
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	InputHints.note_event(key)
	_check(not InputHints.gamepad_active, "hints: a key press switches prompts back to the keyboard")
	for action: StringName in [&"interact", &"jump", &"crouch", &"flashlight", &"toggle_boots", &"toggle_tether", &"pause", &"primary", &"secondary", &"leave_seat", &"brake", &"move_forward", &"look_left", &"readout_scroll_down"]:
		var has_pad: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			has_pad = has_pad or event is InputEventJoypadButton or event is InputEventJoypadMotion
		_check(has_pad, "gamepad: %s is reachable without a keyboard" % action)


func _test_row_click() -> void:
	var menu: ScrollMenu = ScrollMenu.new()
	root.add_child(menu)
	menu.option_selected.connect(_on_selected)
	menu.option_highlighted.connect(_on_highlighted)
	menu.setup("CLICK", PackedStringArray(["FIRST", "SECOND", "THIRD"]))
	menu.open()
	await process_frame
	await process_frame
	var previous_mode: Input.MouseMode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var row: Label = menu.get_node(^"Column/Options/Option2") as Label
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = menu.get_global_transform_with_canvas().affine_inverse() * row.get_global_rect().get_center()
	_selected.clear()
	_highlighted.clear()
	menu.call("_gui_input", click)
	_check(_selected == [2] and _highlighted == [2], "visible cursor selects clicked row, including highlight signal")
	click.pressed = false
	menu.call("_gui_input", click)
	_check(_selected == [2], "left button release does not select again")
	click.pressed = true
	click.position = Vector2(2, 2)
	menu.call("_gui_input", click)
	_check(_selected == [2], "menu border click does not select")
	menu.close()
	click.position = menu.get_global_transform_with_canvas().affine_inverse() * row.get_global_rect().get_center()
	menu.call("_gui_input", click)
	_check(_selected == [2], "closed menu ignores row clicks")
	menu.open()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	menu.call("_unhandled_input", click)
	_check(_selected == [2], "captured mouse ignores primary clicks")
	var select: InputEventAction = InputEventAction.new()
	select.action = &"menu_select"
	select.pressed = true
	menu.move_selection(-1)
	menu.call("_unhandled_input", select)
	_check(_selected == [2, 1], "captured mouse keeps wheel selection")
	Input.mouse_mode = previous_mode
	menu.free()


func _test_selection_detaches_menu() -> void:
	var menu: ScrollMenu = ScrollMenu.new()
	root.add_child(menu)
	menu.setup("LEAVE SCENE", PackedStringArray(["NEW WATCH"]))
	menu.open()
	menu.option_selected.connect(func(_index: int) -> void: root.remove_child(menu))
	await process_frame
	await process_frame
	var select: InputEventKey = InputEventKey.new()
	select.keycode = KEY_ENTER
	select.physical_keycode = KEY_ENTER
	select.pressed = true
	root.push_input(select)
	_check(not menu.is_inside_tree() and root.is_input_handled(), "scene-changing selection consumes Enter after menu detaches")
	select.pressed = false
	root.push_input(select)
	menu.free()


func _on_selected(index: int) -> void:
	_selected.append(index)


func _on_highlighted(index: int) -> void:
	_highlighted.append(index)


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_scroll_menu")
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
