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
	_check(ScrollMenu.HINT_TEXT.contains("CLOSE"), "menu hint names the close key")


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
