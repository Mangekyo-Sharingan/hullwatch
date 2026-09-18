## Shared CRT styling for diegetic screens: phosphor tints and the scanline/dust
## overlay. Keeps every code-built readout looking like the same glass terminal.
class_name CrtPanel
extends RefCounted

const PHOSPHOR_GREEN: Color = Color(0.45, 1.0, 0.55, 1.0)
const PHOSPHOR_AMBER: Color = Color(1.0, 0.78, 0.35, 1.0)

const SHADER_PATH: String = "res://src/shaders/crt_overlay.gdshader"
const OVERLAY_NAME: StringName = &"CrtOverlay"


## Tints label text with the phosphor colour and adds a dark outline for the glow feel.
static func style_label(label: Label, tint: Color) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 2)


## Adds a full-rect darkening overlay as the panel's last child and returns it.
## Falls back to a plain dark ColorRect when the shader cannot be loaded, so the
## panel keeps working either way. The overlay never eats mouse input.
static func add_overlay(panel: Control) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = String(OVERLAY_NAME)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(0.0, 0.0, 0.0, 0.35)
	var shader: Shader = load(SHADER_PATH) as Shader
	if shader != null:
		var material := ShaderMaterial.new()
		material.shader = shader
		overlay.material = material
	if panel != null:
		panel.add_child(overlay)
	return overlay


## Finds the overlay added by add_overlay, or null when the panel has none.
static func get_overlay(panel: Control) -> ColorRect:
	if panel == null:
		return null
	return panel.get_node_or_null(String(OVERLAY_NAME)) as ColorRect
