extends SceneTree

const SETTINGS_SCRIPT: Script = preload("res://src/ui/settings_menu.gd")

class TestMenu extends "res://src/ui/session_menu.gd":
	var quit_requested: bool = false

	func _quit_game() -> void:
		quit_requested = true

class Clock extends Node:
	var is_paused: bool = false

	func set_paused(paused: bool) -> void:
		is_paused = paused

class Readout extends Node:
	var opened: bool = true

	func is_open() -> bool:
		return opened

	func close() -> void:
		opened = false

class Manager extends Node:
	signal transition_finished

	var active_slot: int = 2
	var latest_slot: int = 1
	var fail_transition: bool = false
	var save_success: bool = true
	var new_slots: Array[int] = []
	var load_slots: Array[int] = []
	var saved_slots: Array[int] = []
	var menu_returns: int = 0
	var error: String = ""

	func get_slot_summary(slot: int) -> Dictionary:
		if slot == 1:
			return {"slot": 1, "exists": true, "valid": true, "day": 7, "destination_id": "arden_ii"}
		if slot == 2:
			return {"slot": 2, "exists": true, "valid": false, "error": "parse_error"}
		return {"slot": slot, "exists": false, "valid": false}

	func get_latest_valid_slot() -> int:
		return latest_slot

	func get_last_error() -> String:
		return error

	func start_new_game(slot: int) -> void:
		new_slots.append(slot)
		await _transition()

	func load_game_scene(slot: int) -> void:
		load_slots.append(slot)
		await _transition()

	func _transition() -> void:
		error = ""
		get_tree().paused = false
		get_node(^"/root/SimClock").call("set_paused", false)
		await transition_finished
		if fail_transition:
			error = "read_failed"

	func save_to_slot(slot: int) -> bool:
		saved_slots.append(slot)
		error = "" if save_success else "write_failed"
		return save_success

	func return_to_menu() -> bool:
		menu_returns += 1
		var saved: bool = save_to_slot(active_slot)
		get_tree().paused = false
		get_node(^"/root/SimClock").call("set_paused", false)
		return saved

var _failures: int = 0
var _manager: Manager
var _clock: Clock
var _original_manager: Node
var _original_clock: Node


func _initialize() -> void:
	await process_frame
	# Replace autoloads in memory: this suite never opens or writes a real save slot.
	_original_manager = root.get_node(^"SaveManager")
	_original_clock = root.get_node(^"SimClock")
	root.remove_child(_original_manager)
	root.remove_child(_original_clock)
	_manager = Manager.new()
	_manager.name = "SaveManager"
	_manager.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_manager)
	_clock = Clock.new()
	_clock.name = "SimClock"
	_clock.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_clock)
	_test_main_scene()
	await _test_main_actions()
	await _test_pause_actions()
	paused = false
	_manager.free()
	_clock.free()
	root.add_child(_original_manager)
	root.add_child(_original_clock)
	if _failures == 0:
		print("PASS: test_session_menu")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _test_main_scene() -> void:
	var packed: PackedScene = load("res://scenes/main_menu.tscn") as PackedScene
	_check(packed != null, "main menu scene loads independently of project default scene")
	if packed == null:
		return
	var menu: Node = packed.instantiate()
	root.add_child(menu)
	_check(bool(menu.call("is_menu_open")), "main scene opens its session menu")
	_check(not bool(menu.get("pause_mode")), "main scene uses main mode")
	_check(_clock.is_paused and not paused, "main scene stops clock while UI tree runs")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "main scene returns visible cursor")
	_check(menu.call("get_menu") is ScrollMenu, "main scene reuses ScrollMenu")
	var wordmark: Label = menu.get("_wordmark") as Label
	_check(wordmark != null and wordmark.text == "HULLWATCH" and wordmark.get_theme_font_size(&"font_size") == UiScale.size(menu, 44), "main menu has a distinct scaled Hullwatch wordmark")
	var list: ScrollMenu = menu.call("get_menu") as ScrollMenu
	_check(CrtPanel.get_overlay(list) != null and CrtPanel.get_overlay(list).mouse_filter == Control.MOUSE_FILTER_IGNORE, "CRT overlay preserves menu mouse input")
	var hint: Label = list.get_node(^"Column/Hint") as Label
	_check(hint.text.contains("WHEEL CLICK") and hint.text.contains("ESC: BACK") and hint.text.contains("\n"), "menu hints explain selection and back in readable lines")
	for row: Node in list.get_node(^"Column/Options").get_children():
		if row is Label and not row.is_queued_for_deletion():
			_check((row as Label).custom_minimum_size.y == float(UiScale.size(menu, 32)), "menu rows have scaled click targets")
	menu.free()


func _test_main_actions() -> void:
	var menu: TestMenu = _make_menu(false)
	var actions: PackedStringArray = menu.get_actions()
	_check(actions.size() == 5 and actions[0].contains("DAY 0007") and actions[0].contains("ARDEN II"), "Continue displays latest watch day and location")
	menu.select_action(-1)
	menu.select_action(99)
	_check(_manager.load_slots.is_empty(), "out-of-range selections do nothing")
	menu.select_action(2)
	actions = menu.get_actions()
	_check(actions.size() == 4 and actions[1].contains("INVALID") and actions[2].contains("EMPTY"), "load chooser labels invalid and empty slots")
	menu.select_action(1)
	menu.select_action(2)
	_check(_manager.load_slots.is_empty() and _message(menu).contains("NO VALID WATCH"), "invalid and empty slots cannot load")
	_escape(menu)
	menu.select_action(1)
	menu.select_action(0)
	_check(menu.get_actions()[0].contains("OVERWRITE SLOT 1") and _manager.new_slots.is_empty(), "occupied new slot requires explicit overwrite confirmation")
	menu.select_action(1)
	_check(menu.get_actions()[0].contains("DAY 0007"), "cancel returns to new slot chooser")
	menu.select_action(1)
	_check(menu.get_actions()[0].contains("OVERWRITE SLOT 2"), "invalid occupied slot also requires confirmation")
	_escape(menu)
	_escape(menu)
	_check(menu.get_actions().size() == 5, "Escape backs out confirmation and slot chooser")
	menu.select_action(1)
	menu.select_action(0)
	menu.select_action(0)
	menu.select_action(0)
	_escape(menu)
	_check(_manager.new_slots == [1], "busy transition blocks repeated overwrite and Escape")
	_manager.transition_finished.emit()
	await process_frame
	_check(not menu.is_menu_open(), "completed new-watch transition closes menu")
	menu.open()
	menu.select_action(1)
	menu.select_action(2)
	_check(_manager.new_slots == [1, 3], "empty new slot starts directly")
	_manager.transition_finished.emit()
	await process_frame
	menu.open()
	menu.select_action(0)
	menu.select_action(0)
	_check(_manager.load_slots == [1], "Continue loads latest valid slot once")
	_manager.transition_finished.emit()
	await process_frame
	_manager.latest_slot = 0
	menu.open()
	menu.select_action(0)
	_check(menu.get_actions()[0].contains("NO VALID WATCH") and _manager.load_slots == [1], "Continue is unavailable without a valid slot")
	_manager.latest_slot = 1
	menu.open()
	menu.select_action(2)
	_manager.fail_transition = true
	menu.select_action(0)
	_manager.transition_finished.emit()
	await process_frame
	_check(menu.is_menu_open() and _clock.is_paused and _message(menu).contains("READ FAILED"), "failed load keeps main menu and stopped clock")
	_manager.fail_transition = false
	_manager.error = ""
	_escape(menu)
	menu.select_action(3)
	var settings: Node = menu.get("_settings") as Node
	_check(bool(settings.call("is_menu_open")) and not menu.get_menu().is_open(), "settings owns input while session list is hidden")
	_check(bool(settings.get("managed_by_controller")) and not bool(settings.get("capture_mouse_when_closed")), "settings is managed and does not capture mouse on close")
	_escape(menu)
	_check(not bool(settings.call("is_menu_open")) and menu.get_menu().is_open(), "Escape closes settings before backing out session")
	menu.select_action(4)
	_check(menu.quit_requested, "main Quit requests exit")
	menu.free()


func _test_pause_actions() -> void:
	_clock.set_paused(false)
	var parent: Node = Node.new()
	root.add_child(parent)
	var existing_settings: Node = SETTINGS_SCRIPT.new() as Node
	existing_settings.name = "SettingsMenu"
	parent.add_child(existing_settings)
	var menu: TestMenu = _make_menu(true, parent)
	_check(menu.get("_wordmark") == null, "pause menu keeps the compact watch layout")
	_check(not menu.is_menu_open() and not paused, "pause controller starts closed")
	_check(menu.get("_settings") == existing_settings, "pause controller reuses existing settings sibling")
	var readout: Readout = Readout.new()
	root.add_child(readout)
	readout.add_to_group(&"saveable")
	_escape(menu)
	_check(not menu.is_menu_open(), "physical readout gets Escape before pause menu")
	readout.opened = false
	_escape(menu)
	_check(menu.is_menu_open() and paused and _clock.is_paused, "Escape pauses both SceneTree and SimClock")
	_check(menu.process_mode == Node.PROCESS_MODE_ALWAYS and existing_settings.process_mode == Node.PROCESS_MODE_ALWAYS, "session and settings run while paused")
	_check(menu.get_actions().size() == 6 and menu.get_actions()[1].contains("SLOT 2"), "pause actions show active save slot")
	menu.select_action(1)
	_check(_manager.saved_slots == [2] and _message(menu).contains("WATCH SAVED"), "Save watch uses active slot and confirms success")
	_manager.save_success = false
	menu.select_action(4)
	_check(_manager.menu_returns == 1 and menu.is_menu_open() and paused and _clock.is_paused, "failed Save and main menu stays paused")
	_check(_message(menu).contains("WRITE FAILED"), "failed save displays error")
	menu.select_action(5)
	_check(not menu.quit_requested and menu.is_menu_open() and paused, "failed Save and quit keeps watch paused")
	menu.select_action(3)
	_escape(menu)
	_check(menu.is_menu_open() and paused and not bool(existing_settings.call("is_menu_open")), "Escape closes paused settings without resuming")
	menu.select_action(2)
	_escape(menu)
	_check(menu.is_menu_open() and menu.get_actions().size() == 6 and paused, "Escape backs out load submenu before resuming")
	_escape(menu)
	_check(not menu.is_menu_open() and not paused and not _clock.is_paused, "Escape at pause root resumes both clocks")
	menu.open()
	_manager.fail_transition = true
	menu.select_action(2)
	menu.select_action(0)
	_manager.transition_finished.emit()
	await process_frame
	_check(menu.is_menu_open() and paused and _clock.is_paused, "failed paused load restores both paused states")
	_manager.fail_transition = false
	_manager.save_success = true
	_escape(menu)
	menu.select_action(5)
	_check(menu.quit_requested and _manager.saved_slots.back() == 2, "Save and quit saves active watch before exit")
	menu.quit_requested = false
	menu.select_action(4)
	_check(not menu.is_menu_open() and not paused and _manager.menu_returns == 2, "successful Save and main menu delegates transition")
	readout.free()
	parent.free()


func _make_menu(pause_mode: bool, parent: Node = null) -> TestMenu:
	var menu: TestMenu = TestMenu.new()
	menu.pause_mode = pause_mode
	(parent if parent != null else root).add_child(menu)
	return menu


func _escape(menu: Node) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"pause"
	event.pressed = true
	menu.call("_unhandled_input", event)


func _message(menu: TestMenu) -> String:
	return (menu.get("_message") as Label).text


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
