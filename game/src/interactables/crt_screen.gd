## Binds an authored CRT screen mesh to a static, low-resolution readout texture.
class_name CrtScreen
extends Node

const VIEWPORT_SIZE: Vector2i = Vector2i(320, 240)
const SCREEN_OFFSET: float = 0.002
const DEFAULT_PHOSPHOR: Color = Color(0.45, 1.0, 0.55, 1.0)

@export var phosphor_material: Material

var _screen: MeshInstance3D
var _screen_display: MeshInstance3D
var _display_viewport: SubViewport
var _screen_material: StandardMaterial3D
var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _content: Label
var _overlay: ColorRect
var _presented_lines: PackedStringArray = PackedStringArray()
var _last_tint: Color = DEFAULT_PHOSPHOR
var _has_readout: bool = false


func _ready() -> void:
	_screen = get_parent().find_child("Screen", true, false) as MeshInstance3D
	if _screen == null or _screen.mesh == null:
		return
	if phosphor_material != null:
		_screen.material_override = phosphor_material
	var parent_script: Script = get_parent().get_script() as Script
	if parent_script != null and parent_script.resource_path == "res://src/interactables/wall_computer.gd":
		return
	_bind_display()


## Replaces the physical screen contents without taking ownership of simulator state.
func present_readout(lines: PackedStringArray, tint: Color) -> void:
	if _display_viewport == null or _panel == null or _content == null:
		return
	if _has_readout and lines == _presented_lines and tint.is_equal_approx(_last_tint):
		return
	_presented_lines = lines.duplicate()
	_last_tint = tint
	_has_readout = true
	_panel_style.bg_color = Color(0.008, 0.018, 0.012, 1.0)
	_panel_style.border_color = Color(tint.r * 0.20, tint.g * 0.28, tint.b * 0.20, 1.0)
	_panel.add_theme_stylebox_override("panel", _panel_style)
	_content.text = "\n".join(_presented_lines)
	CrtPanel.style_label(_content, tint)
	_overlay.visible = true
	_display_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func is_bound() -> bool:
	return (
		_screen != null
		and is_instance_valid(_screen)
		and _display_viewport != null
		and is_instance_valid(_display_viewport)
		and _screen_display != null
		and is_instance_valid(_screen_display)
		and _screen_material != null
		and _screen_display.mesh is QuadMesh
		and _screen_display.material_override == _screen_material
		and _screen_material.albedo_texture == _display_viewport.get_texture()
	)


func get_presented_lines() -> PackedStringArray:
	return _presented_lines.duplicate()


func _bind_display() -> void:
	_display_viewport = SubViewport.new()
	_display_viewport.name = "DisplayViewport"
	_display_viewport.size = VIEWPORT_SIZE
	_display_viewport.transparent_bg = false
	_display_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_display_viewport)
	_build_view()
	var bounds: AABB = _screen.mesh.get_aabb()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(bounds.size.x, bounds.size.y)
	_screen_display = MeshInstance3D.new()
	_screen_display.name = "ScreenDisplay"
	_screen_display.mesh = quad
	_screen_display.position = bounds.get_center() + Vector3(0.0, 0.0, bounds.size.z * 0.5 + SCREEN_OFFSET)
	_screen.add_child(_screen_display)
	_screen_material = _make_screen_material()
	_screen_display.material_override = _screen_material
	_display_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _build_view() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DisplayPanel"
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color.WHITE
	_panel_style.set_content_margin_all(9.0)
	_panel.add_theme_stylebox_override("panel", _panel_style)
	_display_viewport.add_child(_panel)
	_content = Label.new()
	_content.name = "Readout"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_content.clip_text = true
	_content.add_theme_font_size_override("font_size", 13)
	var mono_font := SystemFont.new()
	mono_font.font_names = PackedStringArray(["monospace"])
	_content.add_theme_font_override("font", mono_font)
	CrtPanel.style_label(_content, DEFAULT_PHOSPHOR)
	_panel.add_child(_content)
	_overlay = CrtPanel.add_overlay(_panel)
	_overlay.visible = false


func _make_screen_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _display_viewport.get_texture()
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_texture = _display_viewport.get_texture()
	material.emission_energy_multiplier = 1.2
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_screen_material = material
	return material
