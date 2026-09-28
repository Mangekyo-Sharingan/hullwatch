## Analogue-horror post-processing layer: a full-screen shader pass that sits above the 3D world
## (layer 1) and below the HUD (layer 5). Reads the analogue filter keys from GameSettings
## null-safely; disabling it hides the rect and pins the shader intensity to 0.0.
extends CanvasLayer

const SETTINGS_PATH: NodePath = ^"/root/GameSettings"
const SHADER_PATH: String = "res://src/shaders/analogue_filter.gdshader"
const DEFAULT_ENABLED: bool = true
const DEFAULT_INTENSITY: float = 1.0

const SHADER_DEFAULTS: Dictionary = {
	&"grain_amount": 0.02,
	&"aberration": 0.0008,
	&"scanline_amount": 0.02,
	&"vignette_amount": 0.18,
	&"desaturation": 0.08,
	&"warp_amount": 0.005,
	&"flicker_amount": 0.008,
	&"scratch_amount": 0.0,
	&"dust_amount": 0.0,
	&"warm_tint": Vector3(1.03, 0.985, 0.93),
}

var _rect: ColorRect
var _material: ShaderMaterial
var _enabled: bool = DEFAULT_ENABLED
var _intensity: float = DEFAULT_INTENSITY


func _ready() -> void:
	layer = 1
	_build_ui()
	_connect_settings()
	_apply_filter()


func get_filter_rect() -> ColorRect:
	return _rect


func is_filter_active() -> bool:
	return _enabled and _intensity > 0.0


func get_intensity() -> float:
	return _intensity


func get_shader_parameter(name: StringName) -> Variant:
	if _material == null:
		return null
	return _material.get_shader_parameter(name)


func _build_ui() -> void:
	_rect = ColorRect.new()
	_rect.name = "AnalogueFilterRect"
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	var shader: Shader = load(SHADER_PATH)
	if shader != null:
		_material.shader = shader
	for parameter: StringName in SHADER_DEFAULTS:
		_material.set_shader_parameter(parameter, SHADER_DEFAULTS[parameter])
	_rect.material = _material
	add_child(_rect)


func _connect_settings() -> void:
	var settings: Node = _settings()
	if settings == null or not settings.has_signal(&"settings_changed"):
		return
	if not settings.is_connected(&"settings_changed", _on_settings_changed):
		settings.connect(&"settings_changed", _on_settings_changed)


func _on_settings_changed(key: StringName, _value: Variant) -> void:
	if key == &"analogue_filter_enabled" or key == &"analogue_filter_intensity":
		_apply_filter()


func _apply_filter() -> void:
	var settings: Node = _settings()
	_enabled = _setting_bool(settings, &"analogue_filter_enabled", DEFAULT_ENABLED)
	_intensity = clampf(_setting_float(settings, &"analogue_filter_intensity", DEFAULT_INTENSITY), 0.0, 1.0)
	if _material != null:
		_material.set_shader_parameter(&"intensity", _intensity if _enabled else 0.0)
	if _rect != null:
		_rect.visible = _enabled


## Root children fallback exists because --script SceneTree tests run before the root is in the active tree.
func _settings() -> Node:
	if is_inside_tree():
		return get_node_or_null(SETTINGS_PATH)
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_root: Window = (main_loop as SceneTree).root
		if scene_root != null:
			for child: Node in scene_root.get_children():
				if child.name == &"GameSettings":
					return child
	return null


func _setting_float(settings: Node, key: StringName, fallback: float) -> float:
	if settings == null or not settings.has_method(&"get_value"):
		return fallback
	var value: Variant = settings.call(&"get_value", key)
	if not (value is float or value is int):
		return fallback
	return float(value)


func _setting_bool(settings: Node, key: StringName, fallback: bool) -> bool:
	if settings == null or not settings.has_method(&"get_value"):
		return fallback
	var value: Variant = settings.call(&"get_value", key)
	if not (value is bool):
		return fallback
	return bool(value)
