## Minimal diegetic HUD: crosshair plus the current interaction prompt, read from the player's interact ray.
extends CanvasLayer

const PLAYER_GROUP: StringName = &"player"
const INTERACT_RAY_PATH: NodePath = ^"Head/Camera3D/InteractRay"
const EVENT_BUS_PATH: NodePath = ^"/root/EventBus"
const BASE_FONT_SIZE: int = 18
const BASE_MESSAGE_FONT_SIZE: int = 17
const MESSAGE_HOLD_SECONDS: float = 4.0
const PROCEDURE_ERROR_TEXT: Dictionary = {
	&"no_tool": "NO DIAGNOSTIC TOOL CARRIED",
	&"no_wrench": "A WRENCH IS REQUIRED",
	&"no_sealant": "NO HULL SEALANT CARRIED",
	&"no_filter_stock": "NO FILTER IN STORES",
	&"no_cartridge": "NO CARTRIDGE IN STORES",
	&"no_candles": "NO O2 CANDLES IN STORES",
	&"no_fuel": "NO FUEL FOR THE BURN",
	&"no_puncture": "NOTHING TO SEAL HERE",
	&"clean_loop": "GREYWATER IS CLEAN ENOUGH",
}


func _ready() -> void:
	layer = 5
	_build_ui()
	_apply_ui_scale()
	UiScale.connect_settings(self, _on_ui_scale_changed)
	var event_bus: Node = get_node_or_null(EVENT_BUS_PATH)
	if event_bus != null:
		event_bus.connect(&"sim_event", _on_sim_event)


func _process(delta: float) -> void:
	_update_prompt()
	_update_carry()
	_update_message(delta)
	_update_eva(delta)


func get_prompt_text() -> String:
	if _prompt == null:
		return ""
	return _prompt.text


func get_carry_text() -> String:
	if _carry == null:
		return ""
	return _carry.text


func get_prompt_font_size() -> int:
	if _prompt == null:
		return 0
	return _prompt.get_theme_font_size(&"font_size")


func get_message_text() -> String:
	if _message == null:
		return ""
	return _message.text


func get_eva_text() -> String:
	if _eva == null:
		return ""
	return _eva.text


func set_message_hold(seconds: float) -> void:
	_message_hold_seconds = maxf(seconds, 0.0)
	_message_remaining = minf(_message_remaining, _message_hold_seconds)


var _crosshair: Control
var _prompt: Label
var _carry: Label
var _message: Label
var _eva: Label
var _eva_accumulator: float = 0.0
var _message_hold_seconds: float = MESSAGE_HOLD_SECONDS
var _message_remaining: float = 0.0


func _update_message(delta: float) -> void:
	if _message_remaining <= 0.0:
		return
	_message_remaining = maxf(_message_remaining - delta, 0.0)
	if _message_remaining == 0.0 and _message != null:
		_message.text = ""


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	_show_message(_message_for(event_name, payload))


func _show_message(text: String) -> void:
	if _message == null or text.is_empty():
		return
	_message.text = text
	_message_remaining = _message_hold_seconds


func _message_for(event_name: StringName, payload: Dictionary) -> String:
	match event_name:
		&"probe_diagnosis":
			return "DIAGNOSED: %s  (%s)" % [
				String(payload.get("component_id", &"")).to_upper(),
				String(payload.get("failure_mode_id", &"")).to_upper(),
			]
		&"probe_scanned":
			return "WEAR LOGGED: %s" % _system_label(payload)
		&"diagnosis_clear":
			return "NO FAULTS: %s" % _system_label(payload)
		&"component_failed":
			return "COMPONENT FAILED: %s" % String(payload.get("component_id", &"")).to_upper()
		&"message_received":
			return "NEW TRAFFIC: %s" % String(payload.get("sender", "")).to_upper()
		&"scanner_ping":
			return _scanner_ping_text(payload)
		&"procedure_error":
			return _procedure_error_text(StringName(payload.get("reason", &"")))
	return ""


func _scanner_ping_text(payload: Dictionary) -> String:
	var kind: String = String(payload.get("kind", ""))
	if kind.is_empty():
		return "PING: NO CONTACTS IN RANGE"
	return "PING: %s  %.0f m" % [kind.to_upper(), float(payload.get("distance_m", 0.0))]


func _system_label(payload: Dictionary) -> String:
	return String(StringName(payload.get("system", &""))).trim_suffix("_system").to_upper()


func _procedure_error_text(reason: StringName) -> String:
	if PROCEDURE_ERROR_TEXT.has(reason):
		return PROCEDURE_ERROR_TEXT[reason]
	return "CANNOT DO THAT"


func _update_prompt() -> void:
	var ray: RayCast3D = _find_interact_ray()
	if ray == null or not ray.is_colliding():
		_prompt.text = ""
		return
	var collider: Object = ray.get_collider()
	if collider != null and collider.has_method(&"get_interaction_prompt"):
		_prompt.text = String(collider.call("get_interaction_prompt"))
	else:
		_prompt.text = ""


func _update_carry() -> void:
	var player: Node = _find_player()
	var item: Node = null
	if player != null and player.has_method(&"get_carried"):
		item = player.call(&"get_carried") as Node
	if item == null or not item.has_method(&"get_item_name"):
		_carry.text = ""
		return
	_carry.text = "%s  [RIGHT CLICK: DROP]" % String(item.call(&"get_item_name")).to_upper()


func _update_eva(delta: float) -> void:
	_eva_accumulator += delta
	if _eva_accumulator < 0.25:
		return
	_eva_accumulator = 0.0
	if _eva == null:
		return
	var parts: PackedStringArray = PackedStringArray()
	var player: Node = _find_player()
	if player != null and player.has_method(&"is_tethered") and bool(player.call(&"is_tethered")):
		parts.append("TETHER %.1f m  [T: RELEASE]" % float(player.call(&"get_tether_distance")))
	var suit: String = _eva_suit_text()
	if not suit.is_empty():
		parts.append(suit)
	_eva.text = "    ".join(parts)


func _eva_suit_text() -> String:
	var tree: SceneTree = get_tree()
	if tree == null:
		return ""
	var airlock: Node = tree.get_first_node_in_group(&"airlock_system")
	if airlock == null or not airlock.has_method(&"get_status"):
		return ""
	var status: Variant = airlock.call("get_status")
	if not (status is Dictionary):
		return ""
	var data: Dictionary = status
	if not bool(data.get("suit_worn", false)):
		return ""
	return "SUIT O2 %.2f h" % float(data.get("suit_o2_hours", 0.0))


func _find_player() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(PLAYER_GROUP)


func _find_interact_ray() -> RayCast3D:
	var player: Node = _find_player()
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
	_carry = Label.new()
	_carry.name = "Carry"
	_carry.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_carry.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_carry.offset_top = -58.0
	_carry.offset_bottom = -24.0
	_carry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_carry.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))
	_carry.add_theme_color_override("font_color", Color(0.85, 0.9, 0.86, 1.0))
	_carry.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_carry.add_theme_constant_override("outline_size", 4)
	_carry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_carry)
	_eva = Label.new()
	_eva.name = "Eva"
	_eva.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_eva.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_eva.offset_top = -130.0
	_eva.offset_bottom = -98.0
	_eva.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eva.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))
	_eva.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 1.0))
	_eva.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_eva.add_theme_constant_override("outline_size", 4)
	_eva.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_eva)
	var message_layer := CanvasLayer.new()
	message_layer.name = "Messages"
	message_layer.layer = 16
	add_child(message_layer)
	_message = Label.new()
	_message.name = "Message"
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.offset_top = 78.0
	_message.offset_bottom = 112.0
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", UiScale.size(self, BASE_MESSAGE_FONT_SIZE))
	_message.add_theme_color_override("font_color", Color(0.95, 0.88, 0.62, 1.0))
	_message.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_message.add_theme_constant_override("outline_size", 4)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_layer.add_child(_message)


func _apply_ui_scale() -> void:
	if _prompt != null:
		_prompt.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))
	if _carry != null:
		_carry.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))
	if _message != null:
		_message.add_theme_font_size_override("font_size", UiScale.size(self, BASE_MESSAGE_FONT_SIZE))
	if _eva != null:
		_eva.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))


func _on_ui_scale_changed(key: StringName, _value: Variant) -> void:
	if key == &"ui_scale":
		_apply_ui_scale()
