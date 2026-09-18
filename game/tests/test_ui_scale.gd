## UI scale accessibility test: the UiScale helper drives font sizes across the code-built UI.
extends SceneTree

const CONFIG_PATH: String = "user://settings.cfg"

var _failures: int = 0
var _spawned: Array[Node] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	_delete_settings_file()

	var existing: Node = _find_root_child(&"GameSettings")
	if existing != null:
		root.remove_child(existing)
		existing.free()
	var settings: Node = load("res://src/autoload/settings.gd").new()
	settings.name = &"GameSettings"
	root.add_child(settings)
	_spawned.append(settings)
	await process_frame

	_test_helper(settings)
	await _test_hud(settings)
	await _test_status_panel(settings)
	await _test_manual_binder(settings)
	await _test_settings_menu(settings)

	_despawn_all()
	_delete_settings_file()
	_check(not FileAccess.file_exists(CONFIG_PATH), "cleanup: settings.cfg removed after the test")

	_finish()


func _test_helper(settings: Node) -> void:
	settings.call(&"set_value", &"ui_scale", 1.0)
	_check(is_equal_approx(UiScale.factor(root), 1.0), "helper: factor returns 1.0 by default")
	_check(UiScale.size(root, 20) == 20, "helper: size passes through at 1.0")

	settings.call(&"set_value", &"ui_scale", 1.4)
	_check(is_equal_approx(UiScale.factor(root), 1.4), "helper: factor follows ui_scale 1.4")
	_check(UiScale.size(root, 20) == 28, "helper: size scales a 20 base to 28 at 1.4")

	settings.call(&"set_value", &"ui_scale", 0.85)
	_check(UiScale.size(root, 20) == 17, "helper: size shrinks a 20 base to 17 at 0.85")

	settings.call(&"set_value", &"ui_scale", 1.0)
	_check(UiScale.size(root, 0) == 1, "helper: size never drops below 1")


func _test_hud(settings: Node) -> void:
	settings.call(&"set_value", &"ui_scale", 1.0)
	var hud: CanvasLayer = load("res://src/ui/hud.gd").new()
	root.add_child(hud)
	_spawned.append(hud)
	await process_frame

	var base_size: int = int(hud.call(&"get_prompt_font_size"))
	_check(base_size == 18, "hud: prompt font is the 18 base at 1.0")

	settings.call(&"set_value", &"ui_scale", 1.4)
	await process_frame
	await process_frame
	var large_size: int = int(hud.call(&"get_prompt_font_size"))
	_check(large_size > base_size, "hud: prompt font grows at 1.4")
	_check(large_size == 25, "hud: prompt font is 25 at 1.4")

	settings.call(&"set_value", &"ui_scale", 0.85)
	await process_frame
	await process_frame
	var small_size: int = int(hud.call(&"get_prompt_font_size"))
	_check(small_size < base_size, "hud: prompt font shrinks at 0.85")
	_check(small_size == 15, "hud: prompt font is 15 at 0.85")

	settings.call(&"set_value", &"ui_scale", 1.0)
	await process_frame


func _test_status_panel(settings: Node) -> void:
	settings.call(&"set_value", &"ui_scale", 1.0)
	var panel := StatusPanel.new()
	root.add_child(panel)
	_spawned.append(panel)
	await process_frame

	_check(panel.build_readout().size() > 0, "panel: build_readout still returns lines")
	panel.interact(null)
	_check(panel.is_open(), "panel: interact opens the panel")
	_check(int(panel.call(&"get_content_font_size")) == 18, "panel: content font is the 18 base at 1.0")

	settings.call(&"set_value", &"ui_scale", 1.4)
	await process_frame
	await process_frame
	_check(int(panel.call(&"get_content_font_size")) == 25, "panel: content font follows ui_scale 1.4")

	settings.call(&"set_value", &"ui_scale", 0.85)
	await process_frame
	await process_frame
	_check(int(panel.call(&"get_content_font_size")) == 15, "panel: content font follows ui_scale 0.85")

	settings.call(&"set_value", &"ui_scale", 1.0)
	await process_frame


func _test_manual_binder(settings: Node) -> void:
	settings.call(&"set_value", &"ui_scale", 1.0)
	var book: ManualBook = load("res://src/data/manual/manual_book.tres")
	var binder := ManualBinder.new()
	binder.book = book
	root.add_child(binder)
	_spawned.append(binder)
	await process_frame

	binder.interact(null)
	_check(binder.is_open(), "binder: interact opens the manual")
	_check(binder.get_current_page_title() == "OPERATIONS", "binder: current page title is unchanged")
	var menu: ScrollMenu = binder.get_menu()
	_check(menu != null, "binder: menu exists while open")
	_check(menu.get_row_font_size() == 14, "binder: menu row font is the 14 base at 1.0")

	settings.call(&"set_value", &"ui_scale", 1.4)
	await process_frame
	await process_frame
	_check(menu.get_row_font_size() == 20, "binder: menu row font follows ui_scale 1.4")
	_check(binder.get_current_page_title() == "OPERATIONS", "binder: page title survives rescaling")

	settings.call(&"set_value", &"ui_scale", 0.85)
	await process_frame
	await process_frame
	_check(menu.get_row_font_size() == 12, "binder: menu row font follows ui_scale 0.85")

	settings.call(&"set_value", &"ui_scale", 1.0)
	await process_frame


func _test_settings_menu(settings: Node) -> void:
	settings.call(&"set_value", &"ui_scale", 1.0)
	var menu: CanvasLayer = load("res://src/ui/settings_menu.gd").new()
	root.add_child(menu)
	_spawned.append(menu)
	await process_frame

	_check(String(menu.call(&"get_row_value_text", &"ui_scale")) == "100%", "settings: ui scale row text unchanged at 1.0")
	_check(String(menu.call(&"get_row_value_text", &"master_volume_db")) == "0 dB", "settings: volume row text unchanged")
	var scroll: ScrollMenu = menu.call(&"get_menu")
	_check(scroll != null, "settings: scroll menu exists")
	_check(scroll.get_row_font_size() == 14, "settings: menu row font is the 14 base at 1.0")

	settings.call(&"set_value", &"ui_scale", 1.4)
	await process_frame
	await process_frame
	_check(scroll.get_row_font_size() == 20, "settings: menu row font follows ui_scale 1.4")
	_check(String(menu.call(&"get_row_value_text", &"ui_scale")) == "140%", "settings: ui scale row text reflects 1.4")

	settings.call(&"set_value", &"ui_scale", 0.85)
	await process_frame
	await process_frame
	_check(scroll.get_row_font_size() == 12, "settings: menu row font follows ui_scale 0.85")

	settings.call(&"set_value", &"ui_scale", 1.0)
	await process_frame


func _delete_settings_file() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		DirAccess.remove_absolute(CONFIG_PATH)


func _despawn_all() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_ui_scale")
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
