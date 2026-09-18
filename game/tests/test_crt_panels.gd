## CRT overlay test: every diegetic screen carries the shared phosphor tint and scanline overlay.
extends SceneTree

const SHADER_PATH: String = "res://src/shaders/crt_overlay.gdshader"
const MANUAL_PATH: String = "res://src/data/manual/manual_book.tres"
const LOG_PATH: String = "res://src/data/logs/log_01.tres"
const EXPECTED_UNIFORMS: Array[StringName] = [
	&"intensity",
	&"scanline_amount",
	&"vignette_amount",
	&"flicker_amount",
	&"grain_amount",
	&"scratch_amount",
]

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	for autoload_name: StringName in [&"EventBus", &"SimClock"]:
		var existing: Node = _find_root_child(autoload_name)
		if existing != null:
			root.remove_child(existing)
			existing.free()
	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	root.add_child(event_bus)
	var sim_clock: Node = load("res://src/autoload/sim_clock.gd").new()
	sim_clock.name = &"SimClock"
	root.add_child(sim_clock)

	_test_shader()
	await _test_status_panel()
	await _test_log_terminal()
	await _test_manual_binder()
	await _test_maintenance_board()

	_finish()


func _test_shader() -> void:
	var shader: Shader = load(SHADER_PATH) as Shader
	_check(shader != null, "crt shader loads as a Shader")
	if shader == null:
		return
	var compiled: Array = shader.get_shader_uniform_list()
	_check(not compiled.is_empty(), "crt shader compiles")
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in compiled:
		names.append(String(entry["name"]))
	for uniform_name: StringName in EXPECTED_UNIFORMS:
		_check(names.has(String(uniform_name)), "crt shader exposes uniform %s" % uniform_name)


func _test_status_panel() -> void:
	var panel := StatusPanel.new()
	root.add_child(panel)
	await process_frame
	panel.interact(null)
	await process_frame
	var content: Label = _assert_overlay(panel, CrtPanel.PHOSPHOR_AMBER, "status panel")
	var readout: PackedStringArray = panel.build_readout()
	_check(readout.size() > 0, "status panel: build_readout still returns lines")
	_check(content != null and content.text == "\n".join(readout), "status panel: content label matches the joined readout")
	_check(panel.get_content_font_size() > 0, "status panel: content font size survives the overlay")
	panel.free()


func _test_log_terminal() -> void:
	var terminal := LogTerminal.new()
	terminal.log_entry = load(LOG_PATH)
	root.add_child(terminal)
	await process_frame
	terminal.interact(null)
	await process_frame
	var content: Label = _assert_overlay(terminal, CrtPanel.PHOSPHOR_GREEN, "log terminal")
	_check(content != null and content.text == "\n".join(terminal.build_readout()), "log terminal: content label matches the joined readout")
	terminal.free()


func _test_manual_binder() -> void:
	var binder := ManualBinder.new()
	binder.book = load(MANUAL_PATH)
	root.add_child(binder)
	await process_frame
	binder.interact(null)
	await process_frame
	var content: Label = _assert_overlay(binder, CrtPanel.PHOSPHOR_AMBER, "manual binder")
	_check(content != null and content.name == &"PageContent", "manual binder: styled label is the page content")
	_check(content != null and content.text == "\n".join(binder.build_readout()), "manual binder: content label matches the joined readout")
	binder.free()


func _test_maintenance_board() -> void:
	var board := MaintenanceBoard.new()
	root.add_child(board)
	await process_frame
	board.interact(null)
	await process_frame
	var content: Label = _assert_overlay(board, CrtPanel.PHOSPHOR_GREEN, "maintenance board")
	_check(content != null and content.text == "\n".join(board.build_readout()), "maintenance board: content label matches the joined readout")
	board.free()


func _assert_overlay(screen: Node, expected_tint: Color, label: String) -> Label:
	var overlay: ColorRect = _find_descendant(screen, &"CrtOverlay") as ColorRect
	_check(overlay != null, "%s: panel has a CrtOverlay" % label)
	if overlay == null:
		return null
	_check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: overlay ignores mouse input" % label)
	var panel: PanelContainer = overlay.get_parent() as PanelContainer
	_check(panel != null, "%s: overlay sits on the panel container" % label)
	var material: ShaderMaterial = overlay.material as ShaderMaterial
	_check(material != null, "%s: overlay has a ShaderMaterial" % label)
	if material != null:
		_check(material.shader == load(SHADER_PATH), "%s: overlay uses the crt shader" % label)
	var first_label: Label = _first_label(panel)
	_check(first_label != null, "%s: panel keeps its content label" % label)
	if first_label != null:
		_check(first_label.get_theme_color(&"font_color").is_equal_approx(expected_tint), "%s: content label uses the expected phosphor tint" % label)
	return first_label


func _first_label(panel: Control) -> Label:
	if panel == null:
		return null
	for child: Node in panel.get_children():
		if child is Label:
			return child
	return null


func _find_descendant(node: Node, node_name: StringName) -> Node:
	for child: Node in node.get_children():
		if child.name == node_name:
			return child
		var found: Node = _find_descendant(child, node_name)
		if found != null:
			return found
	return null


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_crt_panels")
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
