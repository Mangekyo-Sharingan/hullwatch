## Workshop fabricator unit: a menu of recipes with the material cost and the job status.
class_name FabricatorUnit
extends Interactable

var _menu: ScrollMenu
var _content: Label
var _root: HBoxContainer
var _actions: Array[StringName] = []


func get_interaction_prompt() -> String:
	return "Close fabricator" if is_open() else "Use fabricator"


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


func select_action(recipe_id: StringName) -> bool:
	var fabricator: Node = _get_system(&"fabricator_system")
	if fabricator == null or not fabricator.has_method(&"start"):
		return false
	var refusal: StringName = StringName(String(fabricator.call("start", recipe_id)))
	if refusal != &"":
		_emit_sim_event(&"procedure_error", {"reason": refusal, "recipe_id": String(recipe_id)})
		_refresh_menu()
		_refresh_content()
		return false
	_refresh_menu()
	_refresh_content()
	return true


func build_readout() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var fabricator: Node = _get_system(&"fabricator_system")
	if fabricator == null:
		lines.append("FABRICATOR OFFLINE")
		return lines
	var status: Dictionary = fabricator.call("get_status")
	if bool(status["busy"]):
		lines.append("RUNNING %s  %.1f H LEFT" % [
			String(status["job_recipe_id"]).to_upper(),
			float(status["job_remaining_hours"]),
		])
	else:
		lines.append("IDLE")
	var cargo: Node = _get_system(&"cargo_system")
	if cargo != null and cargo.has_method(&"get_materials"):
		var materials: Dictionary = cargo.call("get_materials")
		var parts: PackedStringArray = PackedStringArray()
		for kind: Variant in materials:
			parts.append("%s %.0f" % [String(kind).to_upper(), float(materials[kind])])
		lines.append("MATERIALS  %s" % ("  ".join(parts) if not parts.is_empty() else "NONE"))
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
	var fabricator: Node = _get_system(&"fabricator_system")
	_actions.clear()
	var items: PackedStringArray = PackedStringArray()
	if fabricator != null:
		var recipes: Array = fabricator.get(&"recipes")
		for recipe: Resource in recipes:
			if recipe == null:
				continue
			_actions.append(recipe.get(&"recipe_id"))
			items.append("%s  (%s %.0f -> %s x%d)" % [
				recipe.get(&"display_name"),
				String(recipe.get(&"material_kind")).to_upper(),
				float(recipe.get(&"material_units")),
				String(recipe.get(&"output_part_id")).to_upper(),
				int(recipe.get(&"output_count")),
			])
	if items.is_empty():
		items.append("(no recipes)")
	_menu.set_items(items)


func _refresh_content() -> void:
	if _content != null:
		_content.text = "\n".join(build_readout())


func _ensure_ui() -> void:
	if _root != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "FabricatorView"
	layer.layer = 12
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var row := HBoxContainer.new()
	row.name = "Fabricator"
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	_menu = ScrollMenu.new()
	_menu.name = "Recipes"
	row.add_child(_menu)
	_menu.setup("FABRICATOR", PackedStringArray(["(no recipes)"]))
	if not _menu.option_selected.is_connected(_on_selected):
		_menu.option_selected.connect(_on_selected)
	var content_panel := PanelContainer.new()
	content_panel.custom_minimum_size = Vector2(380.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.02, 0.62)
	style.border_color = Color(0.65, 0.5, 0.25, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(18.0)
	content_panel.add_theme_stylebox_override("panel", style)
	row.add_child(content_panel)
	_content = Label.new()
	_content.name = "FabricatorStatus"
	_content.add_theme_font_size_override("font_size", 14)
	CrtPanel.style_label(_content, CrtPanel.PHOSPHOR_AMBER)
	content_panel.add_child(_content)
	CrtPanel.add_overlay(content_panel)
	_root = row
