extends Interactable

const ACTION_LABELS: Dictionary = {
	&"isolate": "Isolate assembly",
	&"open": "Open service cover [WRENCH]",
	&"scan": "Scan wear [SCANNER]",
	&"diagnose": "Trace faults [MULTIMETER]",
	&"close": "Close service cover [WRENCH]",
	&"restore": "Verify and restore [MULTIMETER]",
}

@export var cassette_id: StringName = &"port"

var _player: Node
var _menu: ScrollMenu
var _content: Label
var _root: HBoxContainer
var _actions: Array[StringName] = []


func _ready() -> void:
	var bus: Node = _get_autoload(&"EventBus")
	if bus != null:
		bus.connect(&"sim_event", _on_sim_event)
		if bus.has_signal(&"navigation_state_restored"):
			bus.connect(&"navigation_state_restored", _on_navigation_state_restored)
	UiScale.connect_settings(self, _on_ui_scale_changed)
	call_deferred("_refresh", true)


func get_interaction_prompt() -> String:
	return "Close service panel" if is_open() else "Service %s assembly" % String(cassette_id)


func get_menu() -> ScrollMenu:
	return _menu


func is_open() -> bool:
	return _menu != null and _menu.is_open()


func close() -> void:
	if _menu != null:
		_menu.close()
	if _root != null:
		_root.visible = false
	_player = null


func get_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	var status: Dictionary = _status()
	if status.is_empty():
		return actions
	if not bool(status.get("isolated", false)):
		actions.append(&"isolate")
		return actions
	var components: Dictionary = status.get("components", {})
	if bool(status.get("housing_open", false)):
		actions.append_array([&"scan", &"diagnose"])
		for component_id: Variant in components:
			actions.append(StringName("service:" + String(component_id)))
		actions.append(&"close")
	else:
		actions.append(&"open")
		var healthy: bool = not components.is_empty()
		for component_id: Variant in components:
			var component: Dictionary = components[component_id]
			if bool(component.get("failed", false)) or float(component.get("condition", 0.0)) <= 0.0:
				healthy = false
		if healthy:
			actions.append(&"restore")
	return actions


func select_action(action: StringName) -> bool:
	var nav: Node = _get_system(&"nav_system")
	if nav == null or not nav.has_method(&"service_action") or not get_actions().has(action):
		return false
	var tool: StringName = _required_tool(action)
	if _player != null and tool != &"":
		if not is_instance_valid(_player) or not _player.has_method(&"get_carried_item_id"):
			tool = &""
		else:
			tool = StringName(_player.call(&"get_carried_item_id"))
	var performed: bool = bool(nav.call(&"service_action", cassette_id, action, tool))
	if performed:
		_report_tool_result(action)
	else:
		_emit_sim_event(&"procedure_error", {"reason": &"no_tool" if tool != _required_tool(action) else &"drive_service_refused", "cassette_id": cassette_id})
	_refresh()
	return performed


func build_readout() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["%s SERVICE" % String(cassette_id).to_upper()])
	var status: Dictionary = _status()
	if status.is_empty():
		lines.append("SERVICE OFFLINE")
		return lines
	lines.append("FUNCTION: %s" % ("AVAILABLE" if bool(status.get("functional", false)) else "UNAVAILABLE"))
	lines.append("ISOLATION: %s" % ("ISOLATED" if bool(status.get("isolated", false)) else "LIVE"))
	lines.append("COVER: %s" % ("OPEN" if bool(status.get("housing_open", false)) else "CLOSED"))
	var components: Dictionary = status.get("components", {})
	for component_id: Variant in components:
		var component: Dictionary = components[component_id]
		lines.append("")
		lines.append(String(component_id).replace("_", " ").to_upper())
		if bool(component.get("scanned", false)):
			lines.append("CONDITION: %.0f%%" % (float(component.get("condition", 0.0)) * 100.0))
		else:
			lines.append("CONDITION: NOT SCANNED")
		if bool(component.get("diagnosed", false)):
			var mode: String = String(component.get("failed_mode", &""))
			lines.append("FAULT: %s" % (mode.to_upper() if not mode.is_empty() else "CLEAR"))
		else:
			lines.append("FAULT: NOT DIAGNOSED")
	return lines


func _handle_interact(player: Node) -> void:
	if is_open():
		close()
		return
	_player = player
	_ensure_ui()
	_refresh()
	_menu.open()
	_root.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if PanelDismiss.should_dismiss(event, is_open()):
		close()
		get_viewport().set_input_as_handled()


func _status() -> Dictionary:
	var nav: Node = _get_system(&"nav_system")
	if nav == null or not nav.has_method(&"get_service_status"):
		return {}
	return nav.call(&"get_service_status", cassette_id) as Dictionary


func _required_tool(action: StringName) -> StringName:
	if String(action).begins_with("service:") or action in [&"open", &"close"]:
		return &"wrench"
	if action == &"scan":
		return &"scanner"
	if action in [&"diagnose", &"restore"]:
		return &"multimeter"
	return &""


func _report_tool_result(action: StringName) -> void:
	var payload: Dictionary = {"system": &"nav_system", "cassette_id": cassette_id}
	if action == &"scan":
		_emit_sim_event(&"probe_scanned", payload)
	elif action in [&"diagnose", &"restore"]:
		var found: bool = false
		var components: Dictionary = _status().get("components", {})
		for component_id: Variant in components:
			var component: Dictionary = components[component_id]
			if bool(component.get("diagnosed", false)) and bool(component.get("failed", false)):
				found = true
				var result: Dictionary = payload.duplicate()
				result["component_id"] = component_id
				result["failure_mode_id"] = component.get("failed_mode", &"")
				_emit_sim_event(&"probe_diagnosis", result)
		if not found:
			_emit_sim_event(&"diagnosis_clear", payload)


func _on_sim_event(event_name: StringName, _payload: Dictionary) -> void:
	if event_name == &"drive_state_changed":
		_refresh()


func _on_navigation_state_restored(_in_transit: bool) -> void:
	_refresh(true)


func load_state(state: Dictionary) -> void:
	super.load_state(state)
	call_deferred("_refresh", true)


func _refresh(restore_pose: bool = false) -> void:
	if _menu != null:
		_actions = get_actions()
		var items: PackedStringArray = PackedStringArray()
		for action: StringName in _actions:
			items.append("Service %s [WRENCH]" % String(action).trim_prefix("service:").replace("_", " ") if String(action).begins_with("service:") else String(ACTION_LABELS.get(action, action)))
		if items.is_empty():
			items.append("(no service actions)")
		_menu.set_items(items)
	if _content != null:
		_content.text = "\n".join(build_readout())
	var status: Dictionary = _status()
	var model: Node = get_parent()
	if status.is_empty() or model == null:
		return
	var animator: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clip: StringName = &"open_service" if bool(status.get("housing_open", false)) else &"close_service"
	if animator == null or not animator.has_animation(clip):
		return
	if restore_pose or animator.assigned_animation != clip:
		animator.play(clip)
	if restore_pose:
		animator.seek(animator.get_animation(clip).length, true)
		animator.pause()


func _on_selected(index: int) -> void:
	if index >= 0 and index < _actions.size():
		select_action(_actions[index])


func _on_ui_scale_changed(key: StringName, _value: Variant) -> void:
	if key == &"ui_scale" and _content != null:
		_content.add_theme_font_size_override("font_size", UiScale.size(self, 14))


func _ensure_ui() -> void:
	if _root != null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "DriveServiceView"
	layer.layer = 12
	add_child(layer)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	_root = HBoxContainer.new()
	_root.add_theme_constant_override("separation", 12)
	center.add_child(_root)
	_menu = ScrollMenu.new()
	_root.add_child(_menu)
	_menu.setup("ASSEMBLY SERVICE", PackedStringArray())
	_menu.option_selected.connect(_on_selected)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360.0, 0.0)
	_root.add_child(panel)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.02, 0.72)
	style.border_color = CrtPanel.PHOSPHOR_AMBER
	style.set_border_width_all(2)
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", style)
	_content = Label.new()
	_content.add_theme_font_size_override("font_size", UiScale.size(self, 14))
	CrtPanel.style_label(_content, CrtPanel.PHOSPHOR_AMBER)
	panel.add_child(_content)
	CrtPanel.add_overlay(panel)
	_root.visible = false
