## Shared ship-computer terminal: an OS shell of programs over one CRT body.
## Stations subclass this, pin their program list and default page, and keep their own prompts.
class_name ComputerTerminal
extends Interactable

const BASE_FONT_SIZE: int = 14
const REFRESH_SECONDS: float = 0.25
const SYSTEM_TITLE: String = "HULLWATCH SHIP COMPUTER"
const PROGRAM_PATHS: Dictionary = {
	&"watch": "res://src/ui/computer/program_watch.gd",
	&"status": "res://src/ui/computer/program_status.gd",
	&"nav": "res://src/ui/computer/program_nav.gd",
	&"comms": "res://src/ui/computer/program_comms.gd",
	&"log": "res://src/ui/computer/program_log.gd",
	&"control": "res://src/ui/computer/program_control.gd",
	&"approach": "res://src/ui/computer/program_approach.gd",
}

@export var terminal_title: String = "SHIP COMPUTER"

var programs: Array[StringName] = [&"status", &"log"]
var default_program: StringName = &"status"
var phosphor: Color = CrtPanel.PHOSPHOR_GREEN
var ui_layer: int = 12
var base_font_size: int = BASE_FONT_SIZE

var _program_instances: Dictionary = {}
var _current: StringName = &""
var _preview: StringName = &""
var _actions: Array[StringName] = []
var _items: Array[Dictionary] = []
var _first_action: int = 0
var _menu: ScrollMenu
var _content: Label
var _root: HBoxContainer
var _ui: CanvasLayer
var _open: bool = false
var _refresh_accumulator: float = 0.0
var _physical_screen: CrtScreen


func _ready() -> void:
	_build_programs()
	if programs.is_empty():
		programs = [&"status"]
	if not _program_instances.has(default_program):
		default_program = programs[0]
	_current = default_program
	_physical_screen = find_child("ScreenTint", true, false) as CrtScreen
	call_deferred("_refresh_physical_display")
	UiScale.connect_settings(self, _on_ui_scale_changed)
	_apply_ui_scale()


func get_interaction_prompt() -> String:
	return "Close terminal" if is_open() else "Use computer"


func is_open() -> bool:
	return _open


func close() -> void:
	if not _open:
		return
	_open = false
	if _menu != null:
		_menu.close()
	if _root != null:
		_root.visible = false
	_on_terminal_closed()


func get_menu() -> ScrollMenu:
	return _menu


func get_current_program() -> StringName:
	return _current


## Actions of the current page only; the shell's program rows are not actions.
func get_actions() -> Array[StringName]:
	return _actions.duplicate()


func system(group_name: StringName) -> Node:
	return _get_system(group_name)


## Station's preferred archive volume; only the archive terminals return one.
func get_archive_hint() -> LogEntry:
	return null


## Which compartment the status program reports; StatusPanel overrides with its export.
func get_status_compartment_id() -> StringName:
	return &"main"


func get_content_font_size() -> int:
	if _content == null:
		return 0
	return _content.get_theme_font_size(&"font_size")


func select_action(action: StringName) -> bool:
	if action == &"":
		return false
	var changed: bool = false
	if _program_instances.has(action):
		changed = set_program(action)
	else:
		var program: ComputerProgram = _program(_current)
		if program != null:
			changed = program.select_action(self, action)
	_refresh_menu()
	_refresh_content()
	return changed


func set_program(program_id: StringName) -> bool:
	if not _program_instances.has(program_id):
		return false
	if program_id == _current:
		return true
	_current = program_id
	_preview = &""
	_refresh_menu()
	if _menu != null:
		_menu.set_highlighted_index(_first_action_index())
	_refresh_content()
	return true


func build_readout() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var stamp: String = "CLOCK OFFLINE"
	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock != null:
		stamp = "DAY %04d  %02d:00" % [int(sim_clock.call("get_day")), int(sim_clock.call("get_hour"))]
	lines.append(SYSTEM_TITLE)
	lines.append("%s  -  %s" % [terminal_title, stamp])
	var shown_id: StringName = _preview if _preview != &"" else _current
	var program: ComputerProgram = _program(shown_id)
	lines.append("PROGRAM: %s" % (program.title if program != null else "OFFLINE"))
	lines.append("")
	if program != null:
		lines.append_array(program.build_readout(self))
	else:
		lines.append("COMPUTER PROGRAM OFFLINE")
	return lines


func _handle_interact(_player: Node) -> void:
	if is_open():
		close()
		return
	_ensure_ui()
	if _menu == null:
		return
	_refresh_menu()
	_menu.open()
	if _root != null:
		_root.visible = true
	_open = true
	_refresh_accumulator = 0.0
	var program: ComputerProgram = _program(_current)
	if program != null:
		program.on_opened(self)
	_on_terminal_opened()
	_refresh_content()


func _unhandled_input(event: InputEvent) -> void:
	if PanelDismiss.should_dismiss(event, is_open()):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator < REFRESH_SECONDS:
		return
	_refresh_accumulator = 0.0
	if _open:
		_refresh_content()
	else:
		_refresh_physical_display()


func _on_terminal_opened() -> void:
	pass


func _on_terminal_closed() -> void:
	pass


func _build_programs() -> void:
	_program_instances.clear()
	for program_id: StringName in programs:
		var path: String = String(PROGRAM_PATHS.get(program_id, ""))
		if path.is_empty():
			push_warning("ComputerTerminal: no program registered for id %s" % program_id)
			continue
		var script: Script = load(path) as Script
		if script == null:
			push_warning("ComputerTerminal: missing program script for %s" % program_id)
			continue
		var instance: ComputerProgram = script.new() as ComputerProgram
		if instance != null:
			_program_instances[program_id] = instance


func _program(program_id: StringName) -> ComputerProgram:
	return _program_instances.get(program_id) as ComputerProgram


func _first_action_index() -> int:
	if _items.is_empty():
		return 0
	return clampi(_first_action, 0, _items.size() - 1)


func _refresh_menu() -> void:
	if _menu == null:
		return
	_items.clear()
	_actions.clear()
	var items: PackedStringArray = PackedStringArray()
	for program_id: StringName in programs:
		var program: ComputerProgram = _program(program_id)
		if program == null:
			continue
		var badge: String = program.get_badge(self)
		var label: String = program.title
		if not badge.is_empty():
			label = "%s [%s]" % [label, badge]
		_items.append({"kind": &"program", "id": program_id})
		items.append(label)
	_first_action = items.size()
	var current: ComputerProgram = _program(_current)
	if current != null:
		var actions: Array[StringName] = current.get_actions(self)
		for i: int in actions.size():
			var action: StringName = actions[i]
			_actions.append(action)
			_items.append({"kind": &"action", "id": action})
			items.append("%d %s" % [i + 1, current.get_action_label(self, action)])
	if items.is_empty():
		items.append("(NO PROGRAMS)")
	_menu.set_items(items)


func _on_selected(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	var item: Dictionary = _items[index]
	if StringName(item["kind"]) == &"program":
		set_program(item["id"])
	else:
		select_action(item["id"])


func _on_highlighted(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	var item: Dictionary = _items[index]
	var program: ComputerProgram = _program(_current)
	if StringName(item["kind"]) == &"program":
		_preview = item["id"]
		if program != null:
			program.set_highlighted_action(self, &"")
	else:
		_preview = &""
		if program != null:
			program.set_highlighted_action(self, item["id"])
	_refresh_content()


func _refresh_content() -> void:
	if _content != null:
		_content.text = "\n".join(build_readout())
	_refresh_physical_display()


func _refresh_physical_display() -> void:
	if _physical_screen != null and is_instance_valid(_physical_screen):
		_physical_screen.present_readout(build_readout(), phosphor)


func _apply_ui_scale() -> void:
	if _content != null:
		_content.add_theme_font_size_override("font_size", UiScale.size(self, base_font_size))


func _on_ui_scale_changed(key: StringName, _value: Variant) -> void:
	if key == &"ui_scale":
		_apply_ui_scale()


func _ensure_ui() -> void:
	if _root != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "ComputerView"
	layer.layer = ui_layer
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var row := HBoxContainer.new()
	row.name = "Terminal"
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	_menu = ScrollMenu.new()
	_menu.name = "Programs"
	row.add_child(_menu)
	_menu.setup(terminal_title, PackedStringArray(["(NO PROGRAMS)"]))
	_menu.set_hint("WHEEL: BROWSE    CLICK: SELECT    E/ESC: CLOSE")
	_menu.option_selected.connect(_on_selected)
	_menu.option_highlighted.connect(_on_highlighted)
	var panel := PanelContainer.new()
	panel.name = "Screen"
	panel.custom_minimum_size = Vector2(460.0, 440.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.03, 0.72)
	style.border_color = Color(0.2, 0.5, 0.35, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.name = "ReadoutScroll"
	scroll.custom_minimum_size = Vector2(420.0, 400.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_content = Label.new()
	_content.name = "ComputerReadout"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_theme_font_size_override("font_size", UiScale.size(self, base_font_size))
	CrtPanel.style_label(_content, phosphor)
	scroll.add_child(_content)
	CrtPanel.add_overlay(panel)
	_root = row
	_root.visible = false
	_ui = layer
