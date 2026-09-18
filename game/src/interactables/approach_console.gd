## Contact board in the cockpit: lists nearby sensor contacts and commands approach or
## resume-drift. The maneuver belongs to SectorSystem, the fuel to NavSystem.
class_name ApproachConsole
extends Interactable

const MAX_ROWS: int = 5

var _menu: ScrollMenu
var _content: Label
var _root: HBoxContainer
var _actions: Array[StringName] = []


func get_interaction_prompt() -> String:
	return "Close board" if is_open() else "Sensor contacts"


func is_open() -> bool:
	return _menu != null and _menu.is_open()


func close() -> void:
	if _menu != null:
		_menu.close()
	if _root != null:
		_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if PanelDismiss.should_dismiss(event, is_open()):
		close()
		get_viewport().set_input_as_handled()


func get_menu() -> ScrollMenu:
	return _menu


func get_actions() -> Array[StringName]:
	return _actions


## Commands one board row: a contact id approaches it, "resume" releases station-keeping.
func select_action(action: StringName) -> bool:
	var sector: Node = _get_system(&"sector_system")
	if sector == null:
		return false
	if action == &"resume":
		sector.call("resume_drift")
		_refresh_menu()
		_refresh_content()
		return true
	var contacts: Array = sector.call("get_contacts")
	var found: bool = false
	for entry: Dictionary in contacts:
		if String(entry["id"]) == String(action):
			found = true
	if not found:
		return false
	var nav: Node = _get_system(&"nav_system")
	if nav == null:
		return false
	var cost: float = float(nav.get(&"approach_fuel_cost_kg"))
	if not bool(nav.call("spend_fuel", cost)):
		_emit_sim_event(&"procedure_error", {"reason": &"no_fuel"})
		return false
	var started: bool = bool(sector.call("begin_approach", String(action)))
	if not started:
		return false
	_refresh_menu()
	_refresh_content()
	return true


func build_readout() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var sector: Node = _get_system(&"sector_system")
	if sector == null:
		lines.append("SENSOR BOARD OFFLINE")
		return lines
	var nav: Node = _get_system(&"nav_system")
	if nav != null:
		lines.append("FUEL %d KG" % int(roundf(float(nav.call("get_status")["fuel_mass_kg"]))))
	if bool(sector.call("is_holding")):
		lines.append("HOLDING NEAR %s" % String(sector.call("get_approach_target_id")))
	else:
		lines.append("DRIFTING")
	var contacts: Array = sector.call("get_contacts")
	if contacts.is_empty():
		lines.append("NO CONTACTS IN RANGE")
	else:
		for i: int in mini(contacts.size(), MAX_ROWS):
			var contact: Dictionary = contacts[i]
			lines.append("%s  %s  %d M" % [
				String(contact.get("kind", "")).to_upper(),
				String(contact.get("id", "")),
				int(roundf(float(contact.get("distance_m", 0.0)))),
			])
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
	_refresh_content()


func _on_selected(index: int) -> void:
	if index < 0 or index >= _actions.size():
		return
	select_action(_actions[index])


func _refresh_menu() -> void:
	if _menu == null:
		return
	var sector: Node = _get_system(&"sector_system")
	_actions.clear()
	var items: PackedStringArray = PackedStringArray()
	if sector != null:
		var contacts: Array = sector.call("get_contacts")
		for i: int in mini(contacts.size(), MAX_ROWS):
			var contact: Dictionary = contacts[i]
			var id: String = String(contact.get("id", ""))
			_actions.append(StringName(id))
			items.append("APPROACH %s  %s  %d M" % [
				String(contact.get("kind", "")).to_upper(),
				id,
				int(roundf(float(contact.get("distance_m", 0.0)))),
			])
		if bool(sector.call("is_holding")):
			_actions.append(&"resume")
			items.append("RESUME DRIFT")
	if items.is_empty():
		items.append("(no contacts)")
	_menu.set_items(items)


func _refresh_content() -> void:
	if _content != null:
		_content.text = "\n".join(build_readout())


func _ensure_ui() -> void:
	if _root != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "ContactView"
	layer.layer = 12
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var row := HBoxContainer.new()
	row.name = "Contacts"
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	_menu = ScrollMenu.new()
	_menu.name = "Rows"
	row.add_child(_menu)
	_menu.setup("SENSOR CONTACTS", PackedStringArray(["(no contacts)"]))
	if not _menu.option_selected.is_connected(_on_selected):
		_menu.option_selected.connect(_on_selected)
	var content_panel := PanelContainer.new()
	content_panel.custom_minimum_size = Vector2(360.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.045, 0.05, 0.62)
	style.border_color = Color(0.3, 0.6, 0.7, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(18.0)
	content_panel.add_theme_stylebox_override("panel", style)
	row.add_child(content_panel)
	_content = Label.new()
	_content.name = "ContactStatus"
	_content.add_theme_font_size_override("font_size", 14)
	CrtPanel.style_label(_content, CrtPanel.PHOSPHOR_GREEN)
	content_panel.add_child(_content)
	CrtPanel.add_overlay(content_panel)
	_root = row
