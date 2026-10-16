## Wall computer: a blade-style terminal that slides out of its wall slot and folds down to
## face the operator when used, and stows flush again when the readout closes.
class_name WallComputer
extends ComputerTerminal

const DEPLOY_ANIMATION: StringName = &"unfold"
const DEPLOYED_SIZE: Vector3 = Vector3(0.45, 0.50, 0.60)
const DEPLOYED_CENTER_X: float = 0.145
const SCREEN_SIZE: Vector2 = Vector2(0.44, 0.38)
const VIEW_SIZE: Vector2i = Vector2i(640, 552)

var _animator: AnimationPlayer
var _deploy_shape: CollisionShape3D
var _deploy_requested: bool = false
var _screen_view: SubViewport
var _focus_camera: Camera3D
var _player_camera: Camera3D
var _operator: Node
var _operator_physics: bool = false
var _operator_input: bool = false
var _hidden_layers: Dictionary = {}


func _ready() -> void:
	terminal_title = "WALL TERMINAL"
	programs = [&"status", &"control", &"log", &"notices"]
	default_program = &"status"
	phosphor = CrtPanel.PHOSPHOR_GREEN
	base_font_size = 18
	super._ready()
	_ensure_deploy_shape()
	_ensure_ui()
	var animator: AnimationPlayer = _get_animator()
	if animator != null and not animator.animation_finished.is_connected(_on_animation_finished):
		animator.animation_finished.connect(_on_animation_finished)


func get_interaction_prompt() -> String:
	return "Close terminal" if is_open() else "Use terminal"


func close() -> void:
	super.close()
	if _player_camera != null and is_instance_valid(_player_camera):
		_player_camera.make_current()
	_player_camera = null
	if _operator != null and is_instance_valid(_operator):
		_operator.set_physics_process(_operator_physics)
		_operator.set_process_unhandled_input(_operator_input)
	_operator = null
	for node: Node in _hidden_layers:
		if is_instance_valid(node):
			node.set("visible", bool(_hidden_layers[node]))
	_hidden_layers.clear()


func _handle_interact(player: Node) -> void:
	super._handle_interact(player)
	if is_open() and player != null:
		_operator = player
		_operator_physics = player.is_physics_processing()
		_operator_input = player.is_processing_unhandled_input()
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if PanelDismiss.should_dismiss(event, true):
		close()
		get_viewport().set_input_as_handled()
		return
	if _readout_scroll != null:
		if event.is_action_pressed(&"readout_scroll_down"):
			_readout_scroll.scroll_vertical += 220
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"readout_scroll_up"):
			_readout_scroll.scroll_vertical -= 220
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"menu_next") or InputEdge.fresh(event, &"ui_down"):
		_menu.move_selection(1)
	elif event.is_action_pressed(&"menu_prev") or InputEdge.fresh(event, &"ui_up"):
		_menu.move_selection(-1)
	elif event.is_action_pressed(&"menu_select") or event.is_action_pressed(&"ui_accept"):
		_menu.confirm()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_terminal_opened() -> void:
	_set_deployed(true)
	if _focus_camera != null:
		_player_camera = get_viewport().get_camera_3d()
		_focus_camera.make_current()
		for node_name: String in ["HUD", "Messages", "Message", "Indicators"]:
			var node: Node = get_tree().root.find_child(node_name, true, false)
			if node is CanvasLayer or node is CanvasItem:
				_hidden_layers[node] = bool(node.get("visible"))
				node.set("visible", false)


func _on_terminal_closed() -> void:
	_set_deployed(false)
	if _root != null:
		_root.visible = true
	_refresh_stowed_readout()


func _refresh_physical_display() -> void:
	super._refresh_physical_display()
	if not is_open():
		_refresh_stowed_readout()


func _refresh_content() -> void:
	super._refresh_content()
	if _screen_view != null:
		_screen_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _refresh_stowed_readout() -> void:
	if _content == null:
		return
	var lines: PackedStringArray = build_readout()
	if not lines.is_empty():
		lines[lines.size() - 1] = InputHints.expand("{interact}: DEPLOY TERMINAL")
	_content.text = "\n".join(lines)
	_screen_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _set_deployed(deploy: bool) -> void:
	_deploy_requested = deploy
	var animator: AnimationPlayer = _get_animator()
	if animator != null and animator.has_animation(DEPLOY_ANIMATION):
		if deploy:
			animator.play(DEPLOY_ANIMATION)
		else:
			animator.play_backwards(DEPLOY_ANIMATION)
		return
	_apply_deployed_collision(deploy)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == DEPLOY_ANIMATION:
		_apply_deployed_collision(_deploy_requested)


func _apply_deployed_collision(deployed: bool) -> void:
	if _deploy_shape != null:
		_deploy_shape.disabled = not deployed


## The pulled-out tray is real geometry the operator can bump into; it only exists while
## the terminal is open. The prop's own slim wall box covers the stowed state.
func _ensure_deploy_shape() -> void:
	if _deploy_shape != null:
		return
	var box: BoxShape3D = BoxShape3D.new()
	box.size = DEPLOYED_SIZE
	_deploy_shape = CollisionShape3D.new()
	_deploy_shape.name = "DeployedShape"
	_deploy_shape.shape = box
	var side: float = 1.0 if position.x < 0.0 else -1.0
	_deploy_shape.position = Vector3(side * DEPLOYED_CENTER_X, 0.05, 0.0)
	_deploy_shape.disabled = true
	add_child(_deploy_shape)


func _get_animator() -> AnimationPlayer:
	if _animator == null or not is_instance_valid(_animator):
		_animator = find_child("AnimationPlayer", true, false) as AnimationPlayer
	return _animator


func _ensure_ui() -> void:
	if _screen_view != null:
		return
	_screen_view = SubViewport.new()
	_screen_view.name = "BladeDisplay"
	_screen_view.size = VIEW_SIZE
	_screen_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_screen_view)
	var screen := PanelContainer.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.015, 0.035, 0.025)
	glass.border_color = Color(0.12, 0.32, 0.21)
	glass.set_border_width_all(8)
	glass.set_content_margin_all(12)
	screen.add_theme_stylebox_override("panel", glass)
	_screen_view.add_child(screen)
	var row := HBoxContainer.new()
	row.name = "BladeOS"
	row.add_theme_constant_override("separation", 10)
	screen.add_child(row)
	_menu = ScrollMenu.new()
	_menu.name = "Programs"
	row.add_child(_menu)
	_menu.custom_minimum_size = Vector2(205, 0)
	_menu.setup("HULLWATCH / BAY 01", PackedStringArray(["BOOTING..."]))
	_menu.set_hint("{browse}: NAV  {confirm_enter}: OPEN\n{text_scroll_short}: READOUT")
	_menu.option_selected.connect(_on_selected)
	_menu.option_highlighted.connect(_on_highlighted)
	var readout := PanelContainer.new()
	readout.custom_minimum_size = Vector2(390, 510)
	readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inset := StyleBoxFlat.new()
	inset.bg_color = Color(0.0, 0.018, 0.009)
	inset.border_color = Color(0.22, 0.46, 0.27)
	inset.set_border_width_all(2)
	inset.set_content_margin_all(10)
	readout.add_theme_stylebox_override("panel", inset)
	row.add_child(readout)
	var scroll := ScrollContainer.new()
	scroll.name = "ReadoutScroll"
	scroll.custom_minimum_size = Vector2(365, 485)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	readout.add_child(scroll)
	_readout_scroll = scroll
	_content = Label.new()
	_content.name = "ComputerReadout"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_theme_font_size_override("font_size", 18)
	CrtPanel.style_label(_content, phosphor)
	scroll.add_child(_content)
	CrtPanel.add_overlay(screen)
	_root = row
	_root.visible = true
	_refresh_stowed_readout()
	var screen_mesh: MeshInstance3D = find_child("Screen", true, false) as MeshInstance3D
	if screen_mesh != null:
		var display := MeshInstance3D.new()
		display.name = "ScreenDisplay"
		var quad := QuadMesh.new()
		quad.size = SCREEN_SIZE
		display.mesh = quad
		display.position.z = 0.008
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_texture = _screen_view.get_texture()
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		display.material_override = material
		screen_mesh.add_child(display)
		_focus_camera = Camera3D.new()
		_focus_camera.name = "ScreenFocus"
		_focus_camera.position.z = 0.45
		_focus_camera.fov = 55.0
		screen_mesh.add_child(_focus_camera)
