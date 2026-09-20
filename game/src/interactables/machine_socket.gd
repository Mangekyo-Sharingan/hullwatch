## Machine socket inside a pod: the bare room is just a room, and everything a pod does comes
## from the machines fitted into its sockets. Nanites fit a machine over its build hours; a
## fitted machine can be pulled out for a full refund unless it is not portable (vital
## machinery). Slot ids are wired when the pod is stood up: "<hardpoint>:<index>".
class_name MachineSocket
extends Interactable

const ACTION_FIT_PREFIX: String = "fit:"
const ACTION_CANCEL: StringName = &"cancel_fit"
const ACTION_REMOVE: StringName = &"remove"

@export var slot_id: StringName = &""

var _menu: ScrollMenu
var _content: Label
var _root: HBoxContainer
var _actions: Array[StringName] = []
var _prop: MeshInstance3D
var _light: OmniLight3D


func get_interaction_prompt() -> String:
	var machine_id: StringName = _fitted()
	if machine_id != &"":
		return "Socket (%s)" % _machine_name(machine_id)
	if not _job().is_empty():
		return "Socket (fitting)"
	return "Machine socket"


func get_actions() -> Array[StringName]:
	_collect_actions()
	return _actions


## Re-reads the sim (used when the pod wires this socket after the scene loads).
func refresh() -> void:
	_sync()
	if is_open():
		_refresh_menu()
		_refresh_content()


func get_slot_id() -> StringName:
	return slot_id


func _ready() -> void:
	var bus: Node = _get_autoload(&"EventBus")
	if bus != null:
		bus.connect(&"machine_fitted", _on_machine_changed)
		bus.connect(&"machine_removed", _on_machine_changed)
	_sync()


func _handle_interact(_player: Node) -> void:
	if _menu != null and _menu.is_open():
		close()
		return
	_ensure_ui()
	if _menu == null:
		return
	_refresh_menu()
	_menu.open()
	if _root != null:
		_root.visible = true
	_refresh_content()


func close() -> void:
	if _menu != null:
		_menu.close()
	if _root != null:
		_root.visible = false


func is_open() -> bool:
	return _menu != null and _menu.is_open()


func _unhandled_input(event: InputEvent) -> void:
	if PanelDismiss.should_dismiss(event, is_open()):
		close()
		get_viewport().set_input_as_handled()


func select_action(action: StringName) -> bool:
	var modules: Node = _get_system(&"module_system")
	if modules == null or slot_id == &"":
		return false
	var performed: bool = false
	match action:
		ACTION_CANCEL:
			performed = bool(modules.call(&"cancel_machine_fit", slot_id))
		ACTION_REMOVE:
			performed = bool(modules.call(&"remove_machine", slot_id))
		_:
			performed = bool(modules.call(&"fit_machine", StringName(String(action).trim_prefix(ACTION_FIT_PREFIX)), slot_id))
	_refresh_menu()
	_refresh_content()
	_sync()
	return performed


func build_readout() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("SOCKET %s" % String(slot_id).to_upper())
	lines.append("")
	var job: Dictionary = _job()
	if not job.is_empty():
		lines.append("FITTING: %s" % _machine_name(StringName(job.get("machine_id", &""))).to_upper())
		lines.append("%.1f / %.1f h" % [float(job.get("total", 0.0)) - float(job.get("remaining", 0.0)), float(job.get("total", 0.0))])
		lines.append("Cancelling returns the material.")
		return lines
	var fitted: StringName = _fitted()
	if fitted != &"":
		var machine: ShipMachine = _machine(fitted)
		lines.append("FITTED: %s" % _machine_name(fitted).to_upper())
		if machine != null:
			lines.append(_effect_text(machine.effect, machine.effect_amount))
			if machine.power_load_w > 0.0:
				lines.append("draws %.0f W on %s" % [machine.power_load_w, String(machine.circuit_id).to_upper()])
			if not machine.portable:
				lines.append("")
				lines.append("Fixed machinery. It stays where it is bolted.")
				return lines
		lines.append("")
		lines.append("Removing returns the full material cost.")
		return lines
	var cargo: Node = _get_system(&"cargo_system")
	for machine: Variant in _catalog():
		var ship_machine: ShipMachine = machine as ShipMachine
		lines.append("%s - %.0f h" % [ship_machine.display_name, ship_machine.build_hours])
		lines.append("  %s" % _effect_text(ship_machine.effect, ship_machine.effect_amount))
		for kind: Variant in ship_machine.cost:
			var have: float = 0.0
			if cargo != null and cargo.has_method(&"get_units"):
				have = float(cargo.call(&"get_units", StringName(String(kind))))
			lines.append("  %s %.0f / %.0f" % [String(kind), have, float(ship_machine.cost[kind])])
	return lines


func _on_machine_changed(_machine_id: StringName, socket_id: StringName) -> void:
	if socket_id == slot_id:
		_sync()
	if is_open():
		_refresh_menu()
		_refresh_content()


## Keeps the socket's placeholder prop in step with the sim (real machine meshes are M12 art).
func _sync() -> void:
	var machine: ShipMachine = _machine(_fitted())
	if _prop == null:
		_prop = MeshInstance3D.new()
		_prop.name = "MachineProp"
		_prop.material_override = load("res://src/data/materials/mat_machine_teal.tres") as Material
		add_child(_prop)
	if _light == null:
		_light = OmniLight3D.new()
		_light.name = "MachineLight"
		_light.light_energy = 0.9
		_light.omni_range = 4.0
		_light.light_color = Color(0.85, 0.88, 0.95)
		_light.position = Vector3(0.0, 1.6, 0.0)
		add_child(_light)
	if machine == null:
		_prop.visible = false
		_light.visible = false
		return
	var box: BoxMesh = BoxMesh.new()
	box.size = machine.size_m
	_prop.mesh = box
	_prop.visible = true
	_prop.position = Vector3(0.0, machine.size_m.y * 0.5, 0.0)
	_light.visible = true


func _collect_actions() -> void:
	_actions.clear()
	var modules: Node = _get_system(&"module_system")
	if modules == null or slot_id == &"":
		return
	if not _job().is_empty():
		_actions.append(ACTION_CANCEL)
		return
	var fitted: StringName = _fitted()
	if fitted != &"":
		var machine: ShipMachine = _machine(fitted)
		if machine != null and machine.portable:
			_actions.append(ACTION_REMOVE)
		return
	for machine: Variant in _catalog():
		_actions.append(StringName(ACTION_FIT_PREFIX + String((machine as ShipMachine).machine_id)))


func _refresh_menu() -> void:
	if _menu == null:
		return
	_collect_actions()
	var items: PackedStringArray = PackedStringArray()
	for action: StringName in _actions:
		match action:
			ACTION_REMOVE:
				items.append("Remove %s (refund)" % _machine_name(_fitted()))
			ACTION_CANCEL:
				items.append("Cancel fitting (refund)")
			_:
				var machine_id: StringName = StringName(String(action).trim_prefix(ACTION_FIT_PREFIX))
				var machine: ShipMachine = _machine(machine_id)
				if machine != null:
					items.append("Fit %s (%.0f h)" % [machine.display_name, machine.build_hours])
	if items.is_empty():
		items.append("(nothing to fit)")
	_menu.set_items(items)


func _refresh_content() -> void:
	if _content != null:
		_content.text = "\n".join(build_readout())


func _effect_text(effect: StringName, amount: float) -> String:
	match effect:
		&"rations":
			return "greens: +%.0f rations/day" % amount
		&"fabrication":
			return "bench: -%.0f%% job time" % (amount * 100.0)
		&"cargo":
			return "hold: +%.0f units" % amount
		&"power":
			return "battery: +%.0f Wh" % amount
		&"recovery":
			return "recovery: +%.2f/h" % amount
	return "no function"


func _fitted() -> StringName:
	var modules: Node = _get_system(&"module_system")
	if modules == null or not modules.has_method(&"get_machine_at"):
		return &""
	return StringName(modules.call(&"get_machine_at", slot_id))


func _job() -> Dictionary:
	var modules: Node = _get_system(&"module_system")
	if modules == null or not modules.has_method(&"get_machine_job"):
		return {}
	return modules.call(&"get_machine_job", slot_id) as Dictionary


func _machine(machine_id: StringName) -> ShipMachine:
	var modules: Node = _get_system(&"module_system")
	if modules == null or machine_id == &"" or not modules.has_method(&"get_machine"):
		return null
	return modules.call(&"get_machine", machine_id) as ShipMachine


func _machine_name(machine_id: StringName) -> String:
	var machine: ShipMachine = _machine(machine_id)
	return machine.display_name if machine != null else String(machine_id)


func _catalog() -> Array:
	var modules: Node = _get_system(&"module_system")
	if modules == null or not modules.has_method(&"get_machine_catalog"):
		return []
	return modules.call(&"get_machine_catalog") as Array


func _ensure_ui() -> void:
	if _root != null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "SocketView"
	layer.layer = 12
	add_child(layer)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Socket"
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	_menu = ScrollMenu.new()
	_menu.name = "Actions"
	row.add_child(_menu)
	_menu.setup("MACHINE SOCKET", PackedStringArray(["(nothing to fit)"]))
	if not _menu.option_selected.is_connected(_on_selected):
		_menu.option_selected.connect(_on_selected)
	var content_panel: PanelContainer = PanelContainer.new()
	content_panel.custom_minimum_size = Vector2(360.0, 0.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.02, 0.62)
	style.border_color = Color(0.65, 0.55, 0.3, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(18.0)
	content_panel.add_theme_stylebox_override("panel", style)
	row.add_child(content_panel)
	_content = Label.new()
	_content.name = "SocketReadout"
	_content.add_theme_font_size_override("font_size", 14)
	_content.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 1.0))
	content_panel.add_child(_content)
	_root = row


func _on_selected(index: int) -> void:
	if index < 0 or index >= _actions.size():
		return
	select_action(_actions[index])
