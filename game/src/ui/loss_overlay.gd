## Loss-state overlay: a black screen shown on incapacitation with a one-press mercy recovery.
## The overlay owns no sim state — it resuscitates the vitals system and reports the mercy event.
extends CanvasLayer

const VITALS_GROUP: StringName = &"vitals_system"
const UNKNOWN_CAUSE: String = "UNKNOWN"
const BASE_FONT_SIZE: int = 30

var _label: Label
var _cause: StringName = &""
var _cause_text: String = ""
var _shown: bool = false


func _ready() -> void:
	layer = 18
	_build_ui()
	_apply_ui_scale()
	UiScale.connect_settings(self, _on_ui_scale_changed)
	_connect_event_bus()


func is_visible_overlay() -> bool:
	return _shown


func get_cause_text() -> String:
	return _cause_text


func _on_operator_incapacitated(cause: StringName) -> void:
	_cause = cause
	_cause_text = _format_cause(cause)
	_label.text = InputHints.expand("INCAPACITATED — %s\nPRESS {interact} TO SIGNAL FOR RECOVERY" % _cause_text)
	_shown = true
	visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not _shown:
		return
	if not event.is_action_pressed(&"interact"):
		return
	if not _recover():
		return
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _recover() -> bool:
	var vitals: Node = _find_vitals()
	if vitals == null or not vitals.has_method(&"resuscitate"):
		return false
	var cause: StringName = _cause
	vitals.call("resuscitate")
	_shown = false
	visible = false
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"mercy_recovery_used", cause)
		event_bus.call("emit_event", &"mercy_recovery_used", {"cause": cause})
	return true


func _format_cause(cause: StringName) -> String:
	if cause == &"":
		return UNKNOWN_CAUSE
	return String(cause).to_upper().replace("_", " ")


func _find_vitals() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(VITALS_GROUP)


func _build_ui() -> void:
	visible = false
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.0, 0.0, 1.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_label = Label.new()
	_label.name = "Status"
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))
	_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.8, 1.0))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _apply_ui_scale() -> void:
	if _label != null:
		_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))


func _on_ui_scale_changed(key: StringName, _value: Variant) -> void:
	if key == &"ui_scale":
		_apply_ui_scale()


func _connect_event_bus() -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus == null:
		return
	if not event_bus.is_connected(&"operator_incapacitated", _on_operator_incapacitated):
		event_bus.connect(&"operator_incapacitated", _on_operator_incapacitated)


## Root children fallback exists because --script SceneTree tests run before the root is in the active tree.
func _get_autoload(autoload_name: StringName) -> Node:
	if is_inside_tree():
		return get_node_or_null(NodePath("/root/" + String(autoload_name)))
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_root: Window = (main_loop as SceneTree).root
		if scene_root != null:
			for child: Node in scene_root.get_children():
				if child.name == autoload_name:
					return child
	return null
