## Minimal diegetic HUD: crosshair plus the current interaction prompt, read from the player's interact ray.
extends CanvasLayer

const PLAYER_GROUP: StringName = &"player"
const INTERACT_RAY_PATH: NodePath = ^"Head/Camera3D/InteractRay"
const EVENT_BUS_PATH: NodePath = ^"/root/EventBus"
const BASE_FONT_SIZE: int = 18
const BASE_MESSAGE_FONT_SIZE: int = 17
const MESSAGE_HOLD_SECONDS: float = 4.0
const SEATED_MARKER_HEIGHT: float = 0.60
const SEATED_STATIONS: Dictionary = {
	"LogTerminal": "LOG",
	"ContactConsole": "CONTACTS",
	"NavConsole": "NAVIGATION",
	"CommsTerminal": "COMMS",
	"ArchiveTerminal": "ARCHIVE",
	"WallComputer": "SHIP COMPUTER",
}
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
	&"no_cutter": "A HULL CUTTER IS REQUIRED",
	&"no_canister": "AN EMPTY SAMPLE CANISTER IS REQUIRED",
	&"no_scanner": "A FIELD SCANNER IS REQUIRED",
	&"depleted": "NOTHING LEFT TO EXTRACT",
	&"no_sample": "NO SAMPLE TO STOW",
	&"cargo_full": "CARGO HOLD IS FULL",
	&"no_materials": "NOT ENOUGH MATERIALS",
	&"fabricator_busy": "FABRICATOR IS ALREADY RUNNING",
	&"no_power": "NO POWER TO THAT CIRCUIT",
	&"unknown_recipe": "UNKNOWN RECIPE",
	&"already_building": "NANITES ALREADY BUILDING HERE",
	&"hardpoint_occupied": "DOCK MOUNT IS OCCUPIED",
	&"missing_materials": "NOT ENOUGH MATERIALS",
	&"no_build_job": "NO BUILD TO CANCEL",
	&"unknown_module": "NO SUCH MODULE",
	&"already_installed": "THAT MODULE ALREADY STANDS",
	&"module_not_installed": "NOTHING TO TEAR DOWN",
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
	_update_seated_overlay()


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
var _seat_overlay: Control
var _seat_hint: Label
var _seat_labels: Dictionary = {}
var _seat_stations: Dictionary = {}


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
		&"anomaly_logged":
			return "ANOMALY SURVEY LOGGED: %d EXOTIC" % int(payload.get("units", 0.0))
		&"procedure_error":
			return _procedure_error_text(StringName(payload.get("reason", &"")))
		&"construction_started":
			return "NANITE BUILD STARTED: %s  (%.0f h)" % [
				String(payload.get("module_id", &"")).to_upper(),
				float(payload.get("hours", 0.0)),
			]
		&"construction_completed":
			return "POD ONLINE: %s" % String(payload.get("module_id", &"")).to_upper()
		&"construction_cancelled":
			return "BUILD CANCELLED: MATERIALS RETURNED"
		&"machine_fitted":
			return "MACHINE FITTED: %s" % String(payload.get("machine_id", &"")).to_upper()
		&"machine_removed":
			return "MACHINE REMOVED: MATERIALS RETURNED"
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
	if player != null and player.has_method(&"is_boots_engaged") and not bool(player.call(&"is_pilot_seated")):
		if bool(player.call(&"is_boots_engaged")):
			parts.append("MAG BOOTS  [Q: RELEASE / SPACE: PUSH]")
		else:
			parts.append("DRIFT %.1f m/s  [Q: LAND  SPACE/CTRL: UP/DOWN  SHIFT: BRAKE  Z/C: ROLL]" % (player as CharacterBody3D).velocity.length())
	if player != null and player.has_method(&"is_tethered") and bool(player.call(&"is_tethered")):
		var tether_label: String = "TETHER %.1f m  [T: RELEASE]" % float(player.call(&"get_tether_distance"))
		if player.has_method(&"get_tether_extension_ratio") and float(player.call(&"get_tether_extension_ratio")) >= 0.9:
			tether_label = "TETHER STRAIN %.1f m  [T: RELEASE]" % float(player.call(&"get_tether_distance"))
		parts.append(tether_label)
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


func _update_seated_overlay() -> void:
	var player: Node = _find_player()
	var seated: bool = player != null and player.has_method(&"is_pilot_seated") and bool(player.call(&"is_pilot_seated"))
	if seated and not _seat_overlay.visible:
		for station_name: String in SEATED_STATIONS:
			_seat_stations[station_name] = player.get_parent().get_node_or_null(NodePath("WorldLayout/Props/" + station_name)) as Node3D
	_seat_overlay.visible = seated
	if not seated:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	var target: CollisionObject3D = player.call(&"get_seated_target") as CollisionObject3D
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	for station_name: String in SEATED_STATIONS:
		var label: Label = _seat_labels[station_name]
		var station: Node3D = _seat_stations.get(station_name) as Node3D
		if camera == null or not is_instance_valid(station):
			label.visible = false
			continue
		var marker_position: Vector3 = station.global_position + Vector3.UP * SEATED_MARKER_HEIGHT
		if camera.is_position_behind(marker_position):
			label.visible = false
			continue
		var screen: Vector2 = camera.unproject_position(marker_position)
		label.visible = screen.x >= 24.0 and screen.x <= viewport_size.x - 24.0 and screen.y >= 24.0 and screen.y <= viewport_size.y - 24.0
		if not label.visible:
			continue
		var focused: bool = station == target
		label.text = ("[E] " if focused else "[ ") + String(SEATED_STATIONS[station_name]) + (" ]" if not focused else "")
		label.add_theme_color_override(&"font_color", Color(0.95, 0.87, 0.57) if focused else Color(0.54, 0.78, 0.72, 0.82))
		label.position = screen + Vector2(-label.size.x * 0.5, -24.0)


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
	_seat_overlay = Control.new()
	_seat_overlay.name = "PilotVisor"
	_seat_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_seat_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seat_overlay.visible = false
	add_child(_seat_overlay)
	_seat_hint = Label.new()
	_seat_hint.name = "SeatHint"
	_seat_hint.text = "PILOT STATION    [X] LEAVE SEAT"
	_seat_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_seat_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_seat_hint.offset_top = -166.0
	_seat_hint.offset_bottom = -136.0
	_seat_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seat_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seat_hint.add_theme_color_override(&"font_color", Color(0.54, 0.78, 0.72))
	_seat_hint.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_seat_hint.add_theme_constant_override(&"outline_size", 4)
	_seat_overlay.add_child(_seat_hint)
	for station_name: String in SEATED_STATIONS:
		var label: Label = Label.new()
		label.name = "SeatMarker_" + station_name
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override(&"font_outline_color", Color.BLACK)
		label.add_theme_constant_override(&"outline_size", 4)
		_seat_overlay.add_child(label)
		_seat_labels[station_name] = label
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
	if _seat_hint != null:
		_seat_hint.add_theme_font_size_override("font_size", UiScale.size(self, BASE_MESSAGE_FONT_SIZE))
	for label: Label in _seat_labels.values():
		label.add_theme_font_size_override("font_size", UiScale.size(self, 14))


func _on_ui_scale_changed(key: StringName, _value: Variant) -> void:
	if key == &"ui_scale":
		_apply_ui_scale()
