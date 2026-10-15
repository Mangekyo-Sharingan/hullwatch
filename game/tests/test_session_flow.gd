extends SceneTree

const MENU_SCENE: String = "res://scenes/main_menu.tscn"
const GAME_SCENE: String = "res://scenes/main.tscn"

var _failures: int = 0
var _backups: Dictionary = {}
var _manager: Node
var _clock: Node
var _old_slot: int = 1


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_manager = root.get_node(^"SaveManager")
	_clock = root.get_node(^"SimClock")
	_old_slot = int(_manager.get("active_slot"))
	create_timer(30.0, true).timeout.connect(_timeout)
	if not _backup_slots():
		_finish()
		return
	_write_slot(2, "{bad json")
	_write_slot(3, JSON.stringify({"save_version": 4, "meta": [], "clock": {}, "systems": {}, "interactables": {}}))
	_check(not bool((_manager.call("get_slot_summary", 2) as Dictionary).get("valid")), "corrupt JSON excluded")
	_check(not bool((_manager.call("get_slot_summary", 3) as Dictionary).get("valid")), "corrupt metadata excluded")
	_check(int(_manager.call("get_latest_valid_slot")) == 0, "latest ignores invalid slots")
	change_scene_to_file(MENU_SCENE)
	if not await _wait_scene(MENU_SCENE):
		_finish()
		return
	var menu: Node = current_scene
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and bool(_clock.get("is_paused")), "main menu shows cursor and stops clock")
	_select(menu, "LOAD WATCH")
	_select(menu, "SLOT 2")
	_check(current_scene == menu and menu.get("_message").text.contains("NO VALID"), "corrupt slot rejected in load chooser")
	_select(menu, "SLOT 3")
	_check(current_scene == menu and bool(_clock.get("is_paused")), "malformed metadata keeps menu and clock paused")
	await _manager.call("load_game_scene", 3)
	_check(current_scene == menu and not String(_manager.call("get_last_error")).is_empty(), "actual manager rejects malformed slot without transition")
	_select(menu, "BACK")
	_select(menu, "NEW WATCH")
	_select(menu, "SLOT 1")
	if not await _wait_scene(GAME_SCENE):
		_finish()
		return
	_check(bool((_manager.call("get_slot_summary", 1) as Dictionary).get("valid")), "new watch creates valid slot through actual manager")
	_check(not paused and not bool(_clock.get("is_paused")), "new watch starts unpaused")
	var pause_menu: Node = current_scene.get_node(^"UI/PauseMenu")
	var panel: Node = current_scene.find_child("StatusPanel", true, false)
	_check(panel != null, "generated physical readout available")
	if panel != null:
		panel.call("interact", null)
		_check(bool(panel.call("is_open")), "physical readout opens")
		await _escape()
		_check(not bool(panel.call("is_open")) and not bool(pause_menu.call("is_menu_open")), "first physical Escape dismisses readout before pause")
	await _escape()
	_check(bool(pause_menu.call("is_menu_open")) and paused and bool(_clock.get("is_paused")), "next Escape pauses scene and clock")
	var frozen: Dictionary = _clock.call("save_state") as Dictionary
	await create_timer(0.25, true).timeout
	_check(_clock.call("save_state") == frozen, "paused clock does not tick during real elapsed time")
	var power: Node = current_scene.get_node(^"Systems/PowerSystem")
	power.call("set_breaker", &"lighting", false)
	_select(pause_menu, "SAVE WATCH")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://saves/slot_1.json")) as Dictionary
	_check(int(saved.get("save_version", 0)) == 10 and int(saved["clock"]["tick_index"]) == int(frozen["tick_index"]) and is_equal_approx(float(saved["clock"]["sim_seconds"]), float(frozen["sim_seconds"])), "pause save stores current version and frozen clock")
	_manager.set("active_slot", 0)
	_select(pause_menu, "SAVE AND MAIN MENU")
	_check(current_scene.scene_file_path == GAME_SCENE and paused and bool(pause_menu.call("is_menu_open")), "save failure keeps gameplay paused")
	_check(pause_menu.get("_message").text.contains("FAILED"), "save failure displays error")
	_select(pause_menu, "SAVE AND QUIT")
	_check(not String(_manager.call("get_last_error")).is_empty() and paused, "save-and-quit failure stays in paused game")
	_manager.set("active_slot", 1)
	_select(pause_menu, "SAVE AND MAIN MENU")
	if not await _wait_scene(MENU_SCENE):
		_finish()
		return
	menu = current_scene
	_check(not paused and bool(_clock.get("is_paused")), "returned main menu stops clock without pausing UI")
	_check(int(_manager.call("get_latest_valid_slot")) == 1, "continue selects only valid watch")
	var slot_bytes: PackedByteArray = FileAccess.get_file_as_bytes("user://saves/slot_1.json")
	_select(menu, "NEW WATCH")
	_select(menu, "SLOT 1")
	_check((menu.call("get_actions") as PackedStringArray)[0].begins_with("OVERWRITE"), "occupied New requires in-menu overwrite confirmation")
	_select(menu, "CANCEL")
	_check(FileAccess.get_file_as_bytes("user://saves/slot_1.json") == slot_bytes, "cancel leaves saved watch byte-for-byte intact")
	_select(menu, "BACK")
	_select(menu, "LOAD WATCH")
	var labels: PackedStringArray = menu.call("get_actions") as PackedStringArray
	_check(labels[0].contains("DAY") and labels[0].contains("DRIFT CORRIDOR") and labels[1].contains("INVALID"), "slot chooser presents live day/location and invalid state")
	_select(menu, "SLOT 1")
	if not await _wait_scene(GAME_SCENE):
		_finish()
		return
	pause_menu = current_scene.get_node(^"UI/PauseMenu")
	_check(not paused and not bool(_clock.get("is_paused")), "loading paused save resumes scene and clock")
	power = current_scene.get_node(^"Systems/PowerSystem")
	_check(not bool((power.call("save_state") as Dictionary)["breakers"]["lighting"]), "load restores saved machinery input")
	var tick_before: int = int(_clock.get("tick_index"))
	await create_timer(0.25, true).timeout
	_check(int(_clock.get("tick_index")) > tick_before, "loaded watch ticks after resume")
	await _escape()
	await _escape()
	_check(not bool(pause_menu.call("is_menu_open")) and not paused and not bool(_clock.get("is_paused")), "Escape resumes pause menu")
	await _escape()
	_select(pause_menu, "SAVE AND MAIN MENU")
	if not await _wait_scene(MENU_SCENE):
		_finish()
		return
	menu = current_scene
	var save_before_delete: PackedByteArray = FileAccess.get_file_as_bytes("user://saves/slot_1.json")
	_select(menu, "DELETE WATCH")
	_select(menu, "SLOT 1")
	_check((menu.call("get_actions") as PackedStringArray)[0].begins_with("DELETE SLOT 1"), "delete watch asks for confirmation")
	_select(menu, "CANCEL")
	_check(FileAccess.get_file_as_bytes("user://saves/slot_1.json") == save_before_delete, "cancelled deletion preserves the save byte-for-byte")
	_select(menu, "SLOT 1")
	_select(menu, "DELETE SLOT 1")
	_check(not FileAccess.file_exists("user://saves/slot_1.json"), "confirmed menu deletion removes the selected save")
	_check((menu.call("get_actions") as PackedStringArray)[0].contains("EMPTY"), "delete list refreshes the slot summary")
	_finish()


func _escape() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _select(menu: Node, prefix: String) -> void:
	var actions: PackedStringArray = menu.call("get_actions") as PackedStringArray
	for i: int in actions.size():
		if actions[i].begins_with(prefix):
			menu.call("select_action", i)
			return
	_check(false, "missing action " + prefix)


func _wait_scene(path: String) -> bool:
	for i: int in 120:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			await process_frame
			await process_frame
			return true
	_check(false, "transition reaches " + path)
	return false


func _backup_slots() -> bool:
	DirAccess.make_dir_recursive_absolute("user://saves")
	for slot: int in range(1, 4):
		for suffix: String in ["", ".tmp"]:
			var path: String = "user://saves/slot_%d.json%s" % [slot, suffix]
			var exists: bool = FileAccess.file_exists(path)
			var bytes: PackedByteArray = PackedByteArray()
			if exists:
				var file: FileAccess = FileAccess.open(path, FileAccess.READ)
				if file == null:
					_check(false, "backup readable: " + path)
					return false
				bytes = file.get_buffer(file.get_length())
				file.close()
			_backups[path] = {"exists": exists, "bytes": bytes}
	# Remove files only after every backup succeeded.
	for path: String in _backups:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	return true


func _write_slot(slot: int, contents: String) -> void:
	var file: FileAccess = FileAccess.open("user://saves/slot_%d.json" % slot, FileAccess.WRITE)
	if file == null:
		_check(false, "write fixture")
		return
	file.store_string(contents)
	file.close()


func _restore_slots() -> void:
	for path: String in _backups:
		var backup: Dictionary = _backups[path]
		if bool(backup["exists"]):
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				_check(false, "restore writable: " + path)
				continue
			file.store_buffer(backup["bytes"])
			file.close()
			_check(FileAccess.get_file_as_bytes(path) == backup["bytes"], "restore byte-for-byte: " + path)
		else:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
			_check(not FileAccess.file_exists(path), "restore absent: " + path)
	_backups.clear()


func _timeout() -> void:
	_check(false, "integration completed before watchdog")
	_finish()


func _finalize() -> void:
	_restore_slots()


func _finish() -> void:
	paused = false
	_clock.call("set_paused", true)
	_manager.set("active_slot", _old_slot)
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame
		await process_frame
	_restore_slots()
	print("PASS: test_session_flow" if _failures == 0 else "FAILURES: %d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
