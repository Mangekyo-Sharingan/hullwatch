## Settings + accessibility test: defaults, clamps, signals, persistence, player and menu integration.
extends SceneTree

const CONFIG_PATH: String = "user://settings.cfg"

var _failures: int = 0
var _events: Array[Dictionary] = []
var _spawned: Array[Node] = []
var _had_settings: bool = false
var _settings_backup: PackedByteArray = PackedByteArray()


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	_had_settings = FileAccess.file_exists(CONFIG_PATH)
	if _had_settings:
		var original: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if original == null:
			_check(false, "backup: existing settings can be read before test writes")
			_finish()
			return
		_settings_backup = original.get_buffer(original.get_length())
		original.close()
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

	_test_defaults(settings)
	_test_clamps_and_events(settings)
	_test_rejections(settings)
	_test_corrupt_file(settings)
	_test_persistence(settings)
	await _test_player_integration(settings)
	await _test_menu(settings)
	_test_final_save(settings)

	_despawn_all()
	_delete_settings_file()
	_check(not FileAccess.file_exists(CONFIG_PATH), "cleanup: settings.cfg removed after the test")
	if _had_settings:
		var restored: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
		_check(restored != null, "cleanup: original settings file can be restored")
		if restored != null:
			restored.store_buffer(_settings_backup)
			restored.close()
			_check(FileAccess.get_file_as_bytes(CONFIG_PATH) == _settings_backup, "cleanup: original settings restored byte for byte")

	_finish()


func _test_defaults(settings: Node) -> void:
	_check(not FileAccess.file_exists(CONFIG_PATH), "defaults: no settings file exists at test start")
	_check(settings.has_signal(&"settings_changed"), "defaults: settings_changed signal exists")
	_check(is_equal_approx(float(settings.call(&"get_value", &"mouse_sensitivity_multiplier")), 1.0), "defaults: sensitivity multiplier is 1.0")
	_check(not bool(settings.call(&"get_value", &"invert_y")), "defaults: invert_y is false")
	_check(is_equal_approx(float(settings.call(&"get_value", &"master_volume_db")), 0.0), "defaults: volume is 0 dB")
	_check(is_equal_approx(float(settings.call(&"get_value", &"ui_scale")), 1.0), "defaults: ui_scale is 1.0")
	_check(bool(settings.call(&"get_value", &"analogue_filter_enabled")), "defaults: analogue_filter_enabled is true")
	_check(is_equal_approx(float(settings.call(&"get_value", &"analogue_filter_intensity")), 1.0), "defaults: analogue_filter_intensity is 1.0")
	for key: StringName in [&"asteroid_frequency", &"anomaly_frequency", &"planet_frequency"]:
		_check(is_equal_approx(float(settings.call(&"get_value", key)), 1.0), "defaults: %s is 1.0" % key)


func _test_clamps_and_events(settings: Node) -> void:
	_events.clear()
	if not settings.is_connected(&"settings_changed", _on_settings_changed):
		settings.connect(&"settings_changed", _on_settings_changed)

	_check(bool(settings.call(&"set_value", &"mouse_sensitivity_multiplier", 99.0)), "clamp: sensitivity 99 is accepted")
	_check(is_equal_approx(float(settings.call(&"get_value", &"mouse_sensitivity_multiplier")), 3.0), "clamp: sensitivity 99 -> 3.0")
	_check(_has_event(&"mouse_sensitivity_multiplier", 3.0), "event: sensitivity emitted the applied value 3.0")

	_check(bool(settings.call(&"set_value", &"mouse_sensitivity_multiplier", 0.1)), "clamp: sensitivity 0.1 is accepted")
	_check(is_equal_approx(float(settings.call(&"get_value", &"mouse_sensitivity_multiplier")), 0.5), "clamp: sensitivity 0.1 -> 0.5")

	_check(bool(settings.call(&"set_value", &"ui_scale", 0.1)), "clamp: ui_scale 0.1 is accepted")
	_check(is_equal_approx(float(settings.call(&"get_value", &"ui_scale")), 0.85), "clamp: ui_scale 0.1 -> 0.85")
	_check(_has_event(&"ui_scale", 0.85), "event: ui_scale emitted the applied value 0.85")

	_check(bool(settings.call(&"set_value", &"master_volume_db", -100.0)), "clamp: volume -100 is accepted")
	_check(is_equal_approx(float(settings.call(&"get_value", &"master_volume_db")), -40.0), "clamp: volume -100 -> -40")
	_check(_has_event(&"master_volume_db", -40.0), "event: volume emitted the applied value -40")

	_check(bool(settings.call(&"set_value", &"master_volume_db", 12.0)), "clamp: volume 12 is accepted")
	_check(is_equal_approx(float(settings.call(&"get_value", &"master_volume_db")), 0.0), "clamp: volume 12 -> 0")

	_check(bool(settings.call(&"set_value", &"invert_y", true)), "event: invert_y accepted")
	_check(_has_event(&"invert_y", true), "event: invert_y emitted the applied value")

	_check(bool(settings.call(&"set_value", &"analogue_filter_intensity", 5.0)), "clamp: filter intensity 5.0 is accepted")
	_check(is_equal_approx(float(settings.call(&"get_value", &"analogue_filter_intensity")), 1.0), "clamp: filter intensity 5.0 -> 1.0")
	_check(_has_event(&"analogue_filter_intensity", 1.0), "event: filter intensity emitted the applied value 1.0")

	_check(bool(settings.call(&"set_value", &"analogue_filter_intensity", -1.0)), "clamp: filter intensity -1.0 is accepted")
	_check(is_equal_approx(float(settings.call(&"get_value", &"analogue_filter_intensity")), 0.0), "clamp: filter intensity -1.0 -> 0.0")
	_check(_has_event(&"analogue_filter_intensity", 0.0), "event: filter intensity emitted the applied value 0.0")

	_check(bool(settings.call(&"set_value", &"analogue_filter_enabled", false)), "event: filter toggle accepted")
	_check(_has_event(&"analogue_filter_enabled", false), "event: filter toggle emitted the applied value")
	settings.call(&"set_value", &"analogue_filter_enabled", true)
	for key: StringName in [&"asteroid_frequency", &"anomaly_frequency", &"planet_frequency"]:
		_check(bool(settings.call(&"set_value", key, 99.0)), "clamp: %s accepts numeric input" % key)
		_check(is_equal_approx(float(settings.call(&"get_value", key)), 3.0) and _has_event(key, 3.0), "clamp/event: %s maximum is 3.0" % key)
		settings.call(&"set_value", key, -1.0)
		_check(is_equal_approx(float(settings.call(&"get_value", key)), 0.0) and _has_event(key, 0.0), "clamp/event: %s can be disabled at zero" % key)

	settings.call(&"set_value", &"master_volume_db", -12.0)
	var bus_index: int = AudioServer.get_bus_index(&"Master")
	_check(bus_index >= 0, "audio: Master bus exists")
	if bus_index >= 0:
		_check(is_equal_approx(AudioServer.get_bus_volume_db(bus_index), -12.0), "audio: volume applied to the Master bus immediately")


func _test_rejections(settings: Node) -> void:
	var sensitivity_before: float = float(settings.call(&"get_value", &"mouse_sensitivity_multiplier"))
	_check(not bool(settings.call(&"set_value", &"mouse_sensitivity_multiplier", "fast")), "reject: string for a float returns false")
	_check(is_equal_approx(float(settings.call(&"get_value", &"mouse_sensitivity_multiplier")), sensitivity_before), "reject: wrong type leaves the value untouched")
	_check(not bool(settings.call(&"set_value", &"invert_y", "yes")), "reject: string for a bool returns false")
	_check(not bool(settings.call(&"set_value", &"ui_scale", "big")), "reject: string for ui_scale returns false")
	_check(not bool(settings.call(&"set_value", &"analogue_filter_enabled", "yes")), "reject: string for analogue_filter_enabled returns false")
	_check(not bool(settings.call(&"set_value", &"analogue_filter_intensity", "loud")), "reject: string for analogue_filter_intensity returns false")
	_check(not bool(settings.call(&"set_value", &"unknown_key", 1.0)), "reject: unknown key returns false")
	for key: StringName in [&"asteroid_frequency", &"anomaly_frequency", &"planet_frequency"]:
		var before: float = float(settings.call(&"get_value", key))
		_check(not bool(settings.call(&"set_value", key, "many")), "reject: %s rejects strings" % key)
		_check(is_equal_approx(float(settings.call(&"get_value", key)), before), "reject: %s unchanged" % key)


func _test_corrupt_file(settings: Node) -> void:
	settings.call(&"set_value", &"mouse_sensitivity_multiplier", 2.5)
	settings.call(&"set_value", &"master_volume_db", -20.0)
	settings.call(&"save_settings")
	_check(FileAccess.file_exists(CONFIG_PATH), "corrupt: setup file written")
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("not a config {{{")
		file.close()
	settings.call(&"load_settings")
	_check(is_equal_approx(float(settings.call(&"get_value", &"mouse_sensitivity_multiplier")), 1.0), "corrupt: sensitivity falls back to default")
	_check(not bool(settings.call(&"get_value", &"invert_y")), "corrupt: invert falls back to default")
	_check(is_equal_approx(float(settings.call(&"get_value", &"master_volume_db")), 0.0), "corrupt: volume falls back to default")
	_check(is_equal_approx(float(settings.call(&"get_value", &"ui_scale")), 1.0), "corrupt: ui_scale falls back to default")
	_check(bool(settings.call(&"get_value", &"analogue_filter_enabled")), "corrupt: filter enabled falls back to default")
	_check(is_equal_approx(float(settings.call(&"get_value", &"analogue_filter_intensity")), 1.0), "corrupt: filter intensity falls back to default")
	for key: StringName in [&"asteroid_frequency", &"anomaly_frequency", &"planet_frequency"]:
		_check(is_equal_approx(float(settings.call(&"get_value", key)), 1.0), "corrupt: %s falls back to default" % key)


func _test_persistence(settings: Node) -> void:
	settings.call(&"set_value", &"mouse_sensitivity_multiplier", 2.5)
	settings.call(&"set_value", &"invert_y", true)
	settings.call(&"set_value", &"master_volume_db", -15.0)
	settings.call(&"set_value", &"ui_scale", 1.2)
	settings.call(&"set_value", &"analogue_filter_enabled", false)
	settings.call(&"set_value", &"analogue_filter_intensity", 0.35)
	settings.call(&"set_value", &"asteroid_frequency", 2.25)
	settings.call(&"set_value", &"anomaly_frequency", 0.5)
	settings.call(&"set_value", &"planet_frequency", 2.5)
	settings.call(&"save_settings")
	_check(FileAccess.file_exists(CONFIG_PATH), "save: settings.cfg written")

	var config: ConfigFile = ConfigFile.new()
	_check(config.load(CONFIG_PATH) == OK, "save: written file parses as ConfigFile")
	var keys_present: bool = true
	for key: String in ["mouse_sensitivity_multiplier", "invert_y", "master_volume_db", "ui_scale", "analogue_filter_enabled", "analogue_filter_intensity", "asteroid_frequency", "anomaly_frequency", "planet_frequency"]:
		keys_present = keys_present and config.has_section_key("settings", key)
	_check(keys_present, "save: all nine keys persisted under [settings]")

	settings.call(&"reset_to_defaults")
	_check(is_equal_approx(float(settings.call(&"get_value", &"mouse_sensitivity_multiplier")), 1.0), "reset: sensitivity returns to default")
	_check(not bool(settings.call(&"get_value", &"invert_y")), "reset: invert returns to default")
	_check(is_equal_approx(float(settings.call(&"get_value", &"master_volume_db")), 0.0), "reset: volume returns to default")
	_check(is_equal_approx(float(settings.call(&"get_value", &"ui_scale")), 1.0), "reset: ui_scale returns to default")
	_check(bool(settings.call(&"get_value", &"analogue_filter_enabled")), "reset: filter enabled returns to default")
	_check(is_equal_approx(float(settings.call(&"get_value", &"analogue_filter_intensity")), 1.0), "reset: filter intensity returns to default")
	for key: StringName in [&"asteroid_frequency", &"anomaly_frequency", &"planet_frequency"]:
		_check(is_equal_approx(float(settings.call(&"get_value", key)), 1.0), "reset: %s returns to default" % key)
	_check(config.load(CONFIG_PATH) == OK and is_equal_approx(float(config.get_value("settings", "mouse_sensitivity_multiplier")), 2.5), "reset: in-memory defaults do not overwrite saved preferences")

	_events.clear()
	settings.call(&"load_settings")
	_check(_events.is_empty(), "load: no settings_changed events emitted during load")
	_check(is_equal_approx(float(settings.call(&"get_value", &"mouse_sensitivity_multiplier")), 2.5), "load: saved sensitivity restored")
	_check(bool(settings.call(&"get_value", &"invert_y")), "load: saved invert flag restored")
	_check(is_equal_approx(float(settings.call(&"get_value", &"master_volume_db")), -15.0), "load: saved volume restored")
	_check(is_equal_approx(float(settings.call(&"get_value", &"ui_scale")), 1.2), "load: saved ui_scale restored")
	_check(not bool(settings.call(&"get_value", &"analogue_filter_enabled")), "load: saved filter enabled flag restored")
	_check(is_equal_approx(float(settings.call(&"get_value", &"analogue_filter_intensity")), 0.35), "load: saved filter intensity restored")
	_check(is_equal_approx(float(settings.call(&"get_value", &"asteroid_frequency")), 2.25), "load: saved asteroid frequency restored")
	_check(is_equal_approx(float(settings.call(&"get_value", &"anomaly_frequency")), 0.5), "load: saved anomaly frequency restored")
	_check(is_equal_approx(float(settings.call(&"get_value", &"planet_frequency")), 2.5), "load: saved planet frequency restored")
	config.erase_section_key("settings", "asteroid_frequency")
	config.erase_section_key("settings", "anomaly_frequency")
	config.erase_section_key("settings", "planet_frequency")
	_check(config.save(CONFIG_PATH) == OK, "legacy: settings without encounter keys written")
	settings.call(&"load_settings")
	_check(is_equal_approx(float(settings.call(&"get_value", &"mouse_sensitivity_multiplier")), 2.5), "legacy: existing preferences survive missing encounter keys")
	for key: StringName in [&"asteroid_frequency", &"anomaly_frequency", &"planet_frequency"]:
		_check(is_equal_approx(float(settings.call(&"get_value", key)), 1.0), "legacy: %s defaults to 1.0" % key)


func _test_player_integration(settings: Node) -> void:
	settings.call(&"set_value", &"mouse_sensitivity_multiplier", 2.0)
	settings.call(&"set_value", &"invert_y", false)
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	_check(player_scene != null, "player: scene loads")
	if player_scene == null:
		return
	var player: CharacterBody3D = player_scene.instantiate()
	root.add_child(player)
	_spawned.append(player)
	await process_frame
	_check(absf(player.mouse_sensitivity - 0.004) <= 0.0005, "player: multiplier 2.0 gives 0.004 rad/px")

	settings.call(&"set_value", &"mouse_sensitivity_multiplier", 0.5)
	await process_frame
	_check(absf(player.mouse_sensitivity - 0.001) <= 0.0005, "player: multiplier 0.5 gives 0.001 rad/px")

	settings.call(&"set_value", &"invert_y", true)
	await process_frame
	_check(player.is_invert_y(), "player: invert_y cached from settings_changed")
	settings.call(&"set_value", &"invert_y", false)
	await process_frame
	_check(not player.is_invert_y(), "player: invert_y clears from settings_changed")


func _test_menu(settings: Node) -> void:
	settings.call(&"set_value", &"mouse_sensitivity_multiplier", 1.25)
	settings.call(&"set_value", &"invert_y", false)
	settings.call(&"set_value", &"master_volume_db", -10.0)
	settings.call(&"set_value", &"ui_scale", 1.05)
	settings.call(&"set_value", &"analogue_filter_enabled", true)
	settings.call(&"set_value", &"analogue_filter_intensity", 1.0)
	settings.call(&"set_value", &"asteroid_frequency", 1.0)
	settings.call(&"set_value", &"anomaly_frequency", 1.0)
	settings.call(&"set_value", &"planet_frequency", 1.0)
	var sector: SectorSystem = SectorSystem.new()
	root.add_child(sector)
	_spawned.append(sector)
	var menu: CanvasLayer = load("res://src/ui/settings_menu.gd").new()
	root.add_child(menu)
	_spawned.append(menu)
	await process_frame

	_check(not bool(menu.call(&"is_menu_open")), "menu: hidden by default")
	_check(not menu.visible, "menu: canvas hidden by default")
	menu.call(&"toggle")
	_check(bool(menu.call(&"is_menu_open")), "menu: toggle opens")
	_check(menu.visible, "menu: canvas visible while open")
	menu.call(&"toggle")
	_check(not bool(menu.call(&"is_menu_open")), "menu: toggle closes")
	_check(not menu.visible, "menu: canvas hidden while closed")

	_check(String(menu.call(&"get_row_value_text", &"mouse_sensitivity_multiplier")) == "1.25x", "menu: sensitivity row shows 1.25x")
	_check(String(menu.call(&"get_row_value_text", &"invert_y")) == "OFF", "menu: invert row shows OFF")
	_check(String(menu.call(&"get_row_value_text", &"master_volume_db")) == "-10 dB", "menu: volume row shows -10 dB")
	_check(String(menu.call(&"get_row_value_text", &"ui_scale")) == "105%", "menu: ui scale row shows 105%")
	_check(String(menu.call(&"get_row_value_text", &"analogue_filter_enabled")) == "ON", "menu: filter row shows ON")
	_check(String(menu.call(&"get_row_value_text", &"analogue_filter_intensity")) == "100%", "menu: filter intensity row shows 100%")
	_check(String(menu.call(&"get_row_value_text", &"unknown_key")) == "", "menu: unknown row text is empty")

	var scroll: ScrollMenu = menu.call(&"get_menu")
	_check(scroll != null and scroll.get_items().size() == 11, "menu: scroll menu lists eleven rows")
	_check(scroll.get_items()[0].contains("1.25x"), "menu: first row carries the sensitivity value")
	scroll.move_selection(2)
	_check(scroll.get_highlighted_index() == 2, "menu: browsing moves the highlight")
	scroll.confirm()
	_check(String(menu.call(&"get_row_value_text", &"master_volume_db")) == "-5 dB", "menu: wheel click steps the highlighted setting")

	scroll.move_selection(7)
	_check(scroll.get_highlighted_text() == "RESET DEFAULTS", "menu: reset row is reachable")
	scroll.confirm()
	_check(String(menu.call(&"get_row_value_text", &"ui_scale")) == "100%", "menu: wheel click on reset restores defaults")
	var saved_defaults: ConfigFile = ConfigFile.new()
	_check(saved_defaults.load(CONFIG_PATH) == OK and is_equal_approx(float(saved_defaults.get_value("settings", "ui_scale")), 1.0), "menu: reset saves defaults to disk")

	settings.call(&"set_value", &"analogue_filter_intensity", 0.5)
	scroll.move_selection(-5)
	_check(scroll.get_highlighted_index() == 4, "menu: filter row is reachable")
	scroll.confirm()
	_check(String(menu.call(&"get_row_value_text", &"analogue_filter_enabled")) == "OFF", "menu: wheel click toggles the filter off")
	scroll.move_selection(1)
	scroll.confirm()
	_check(String(menu.call(&"get_row_value_text", &"analogue_filter_intensity")) == "60%", "menu: wheel click steps the filter intensity")
	menu.call(&"_decrease_highlighted")
	_check(String(menu.call(&"get_row_value_text", &"analogue_filter_intensity")) == "50%", "menu: right click decreases the filter intensity")
	scroll.move_selection(1)
	scroll.confirm()
	_check(is_equal_approx(sector.get_encounter_frequency(&"asteroid_frequency"), 1.25), "menu: asteroid increment updates the live sector")
	_check(String(menu.call(&"get_row_value_text", &"asteroid_frequency")) == "x1.25", "menu: asteroid row reflects the live sector")
	menu.call(&"_decrease_highlighted")
	_check(is_equal_approx(sector.get_encounter_frequency(&"asteroid_frequency"), 1.0), "menu: asteroid decrement updates the live sector")
	scroll.confirm()
	scroll.move_selection(1)
	menu.call(&"_decrease_highlighted")
	_check(is_equal_approx(sector.get_encounter_frequency(&"anomaly_frequency"), 0.75), "menu: anomaly decrement updates the live sector")
	_check(String(menu.call(&"get_row_value_text", &"anomaly_frequency")) == "x0.75", "menu: anomaly row reflects the live sector")
	scroll.move_selection(1)
	scroll.confirm()
	_check(String(menu.call(&"get_row_value_text", &"planet_frequency")) == "x1.25", "menu: planet occurrence increment updates its setting")
	menu.call(&"_decrease_highlighted")
	_check(String(menu.call(&"get_row_value_text", &"planet_frequency")) == "x1.00", "menu: planet occurrence decrement updates its setting")
	var persisted: Node = load("res://src/autoload/settings.gd").new()
	persisted.call(&"load_settings")
	_check(is_equal_approx(float(persisted.call(&"get_value", &"asteroid_frequency")), 1.25), "menu: asteroid control persists across reload")
	_check(is_equal_approx(float(persisted.call(&"get_value", &"anomaly_frequency")), 0.75), "menu: anomaly control persists across reload")
	_check(is_equal_approx(float(persisted.call(&"get_value", &"planet_frequency")), 1.0), "menu: planet occurrence persists across reload")
	persisted.free()
	settings.call(&"set_value", &"analogue_filter_enabled", true)
	settings.call(&"set_value", &"analogue_filter_intensity", 1.0)

	settings.call(&"set_value", &"invert_y", true)
	_check(String(menu.call(&"get_row_value_text", &"invert_y")) == "ON", "menu: row refreshes from settings_changed")
	settings.call(&"set_value", &"invert_y", false)


func _test_final_save(settings: Node) -> void:
	settings.call(&"save_settings")
	_check(FileAccess.file_exists(CONFIG_PATH), "cleanup: final save writes the file")


func _on_settings_changed(key: StringName, value: Variant) -> void:
	_events.append({"key": key, "value": value})


func _has_event(key: StringName, expected: Variant) -> bool:
	for event: Dictionary in _events:
		if event["key"] != key:
			continue
		var value: Variant = event["value"]
		if value is bool or expected is bool:
			if value == expected:
				return true
		elif is_equal_approx(float(value), float(expected)):
			return true
	return false


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
		print("PASS: test_settings")
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
