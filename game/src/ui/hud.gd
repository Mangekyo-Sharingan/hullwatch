## Minimal diegetic HUD: crosshair plus the current interaction prompt, read from the player's interact ray.
extends CanvasLayer

const PLAYER_GROUP: StringName = &"player"
const INTERACT_RAY_PATH: NodePath = ^"Head/Camera3D/InteractRay"
const BASE_FONT_SIZE: int = 18


func _ready() -> void:
	layer = 5
	_build_ui()
	_apply_ui_scale()
	UiScale.connect_settings(self, _on_ui_scale_changed)


func _process(_delta: float) -> void:
	var ray: RayCast3D = _find_interact_ray()
	if ray == null or not ray.is_colliding():
		_prompt.text = ""
		return
	var collider: Object = ray.get_collider()
	if collider != null and collider.has_method(&"get_interaction_prompt"):
		_prompt.text = String(collider.call("get_interaction_prompt"))
	else:
		_prompt.text = ""


func get_prompt_text() -> String:
	if _prompt == null:
		return ""
	return _prompt.text


func get_prompt_font_size() -> int:
	if _prompt == null:
		return 0
	return _prompt.get_theme_font_size(&"font_size")


var _crosshair: Control
var _prompt: Label


func _find_interact_ray() -> RayCast3D:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var player: Node = tree.get_first_node_in_group(PLAYER_GROUP)
	if player == null:
		return null
	return player.get_node_or_null(INTERACT_RAY_PATH) as RayCast3D


func _build_ui() -> void:
	_crosshair = ColorRect.new()
	_crosshair.name = "Crosshair"
	_crosshair.color = Color(0.75, 0.85, 0.8, 0.6)
	_crosshair.size = Vector2(4.0, 4.0)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.offset_top = -96.0
	_prompt.offset_bottom = -62.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))
	_prompt.add_theme_color_override("font_color", Color(0.85, 0.9, 0.86, 1.0))
	_prompt.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)


func _apply_ui_scale() -> void:
	if _prompt != null:
		_prompt.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))


func _on_ui_scale_changed(key: StringName, _value: Variant) -> void:
	if key == &"ui_scale":
		_apply_ui_scale()
