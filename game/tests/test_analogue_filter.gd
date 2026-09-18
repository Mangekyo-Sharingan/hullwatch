## Analogue filter test: shader load, uniform defaults, and settings-driven enable/intensity.
extends SceneTree

const CONFIG_PATH: String = "user://settings.cfg"
const SETTINGS_SCRIPT: String = "res://src/autoload/settings.gd"
const FILTER_SCRIPT: String = "res://src/world/analogue_filter.gd"
const SHADER_PATH: String = "res://src/shaders/analogue_filter.gdshader"

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
	var settings: Node = load(SETTINGS_SCRIPT).new()
	settings.name = &"GameSettings"
	root.add_child(settings)
	_spawned.append(settings)
	await process_frame

	_test_shader_load()

	var filter: CanvasLayer = load(FILTER_SCRIPT).new()
	root.add_child(filter)
	_spawned.append(filter)
	await process_frame

	_test_defaults(filter)
	await _test_intensity_change(settings, filter)
	await _test_disable_enable(settings, filter)
	_test_shader_uniforms(settings, filter)

	_despawn_all()
	_delete_settings_file()
	_check(not FileAccess.file_exists(CONFIG_PATH), "cleanup: settings.cfg removed after the test")

	_finish()


func _test_shader_load() -> void:
	_check(load(SHADER_PATH) != null, "shader: analogue_filter.gdshader loads")


func _test_defaults(filter: CanvasLayer) -> void:
	_check(filter.call(&"get_filter_rect") != null, "filter: full-screen rect exists")
	_check(bool(filter.call(&"is_filter_active")), "filter: active by default")
	_check(is_equal_approx(float(filter.call(&"get_intensity")), 1.0), "filter: default intensity is 1.0")
	_check(is_equal_approx(float(filter.call(&"get_shader_parameter", &"intensity")), 1.0), "filter: material intensity defaults to 1.0")
	var rect: ColorRect = filter.call(&"get_filter_rect")
	_check(rect.visible, "filter: rect visible by default")


func _test_intensity_change(settings: Node, filter: CanvasLayer) -> void:
	settings.call(&"set_value", &"analogue_filter_intensity", 0.4)
	await process_frame
	await process_frame
	_check(is_equal_approx(float(filter.call(&"get_intensity")), 0.4), "intensity: getter follows 0.4")
	_check(is_equal_approx(float(filter.call(&"get_shader_parameter", &"intensity")), 0.4), "intensity: material uniform follows 0.4")
	_check(bool(filter.call(&"is_filter_active")), "intensity: filter stays active at 0.4")


func _test_disable_enable(settings: Node, filter: CanvasLayer) -> void:
	var rect: ColorRect = filter.call(&"get_filter_rect")

	settings.call(&"set_value", &"analogue_filter_enabled", false)
	await process_frame
	await process_frame
	_check(not rect.visible, "disable: rect hidden")
	_check(not bool(filter.call(&"is_filter_active")), "disable: filter reports inactive")
	_check(is_equal_approx(float(filter.call(&"get_shader_parameter", &"intensity")), 0.0), "disable: material intensity pinned to 0.0")
	_check(is_equal_approx(float(filter.call(&"get_intensity")), 0.4), "disable: prior intensity value preserved")

	settings.call(&"set_value", &"analogue_filter_enabled", true)
	await process_frame
	await process_frame
	_check(rect.visible, "enable: rect visible again")
	_check(bool(filter.call(&"is_filter_active")), "enable: filter reports active")
	_check(is_equal_approx(float(filter.call(&"get_intensity")), 0.4), "enable: prior intensity restored")
	_check(is_equal_approx(float(filter.call(&"get_shader_parameter", &"intensity")), 0.4), "enable: material intensity restored")


func _test_shader_uniforms(settings: Node, filter: CanvasLayer) -> void:
	settings.call(&"set_value", &"analogue_filter_intensity", 1.0)
	_check(is_equal_approx(float(filter.call(&"get_shader_parameter", &"intensity")), 1.0), "uniforms: master intensity is 1.0")
	_check_uniform_positive(filter, &"grain_amount")
	_check_uniform_positive(filter, &"aberration")
	_check_uniform_positive(filter, &"scanline_amount")
	_check_uniform_positive(filter, &"vignette_amount")


func _check_uniform_positive(filter: CanvasLayer, name: StringName) -> void:
	var value: Variant = filter.call(&"get_shader_parameter", name)
	_check(value != null, "uniforms: '%s' is present" % String(name))
	if value != null:
		_check(float(value) > 0.0, "uniforms: '%s' is positive" % String(name))


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
		print("PASS: test_analogue_filter")
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
