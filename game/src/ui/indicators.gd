## Cognition vignette: a full-screen radial darkening whose strength tracks the sim's cognition level.
## Level 0 is clear; levels 1-3 darken the edges. Built entirely in code, no scene files.
extends CanvasLayer

const VIGNETTE_SHADER: String = """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float distance_from_center = length(centered) * 1.41421356;
	float edge = smoothstep(1.0 - intensity * 0.75, 1.0, distance_from_center);
	COLOR = vec4(0.0, 0.0, 0.0, edge * intensity);
}
"""

const LEVEL_INTENSITIES: Array[float] = [0.0, 0.25, 0.5, 0.8]

var _vignette: ColorRect
var _material: ShaderMaterial
var _intensity: float = 0.0


func _ready() -> void:
	layer = 15
	_build_ui()
	_connect_event_bus()


func get_vignette_intensity() -> float:
	return _intensity


func _on_cognition_effect_changed(level: int) -> void:
	_set_level(level)


func _set_level(level: int) -> void:
	var clamped_level: int = clampi(level, 0, LEVEL_INTENSITIES.size() - 1)
	_intensity = LEVEL_INTENSITIES[clamped_level]
	if _material != null:
		_material.set_shader_parameter(&"intensity", _intensity)


func _build_ui() -> void:
	_vignette = ColorRect.new()
	_vignette.name = "CognitionVignette"
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter(&"intensity", _intensity)
	_vignette.material = _material
	add_child(_vignette)


func _connect_event_bus() -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus == null:
		return
	if not event_bus.is_connected(&"cognition_effect_changed", _on_cognition_effect_changed):
		event_bus.connect(&"cognition_effect_changed", _on_cognition_effect_changed)


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
