## Dock mount. Sits on the flush hull plate outside an unbuilt dock: opens the build list
## (catalog modules for this hardpoint, their cost and build hours), pays the cost through
## ModuleSystem and stands the pod up in the world. The pod's own room carries a second mount
## (spawns = false) so the same menu tears it down from inside. The plate hides and stops
## colliding while a pod stands, which is what opens the doorway into it.
class_name ModuleMount
extends Interactable

const POD_SCENE: String = "res://scenes/dock_pod.tscn"
const ACTION_BUILD_PREFIX: String = "build:"
const ACTION_TEARDOWN: StringName = &"teardown"

@export var hardpoint_id: StringName = &""
@export var spawns: bool = true

var _menu: ScrollMenu
var _content: Label
var _root: HBoxContainer
var _actions: Array[StringName] = []
var _pod: Node3D


func get_interaction_prompt() -> String:
	var installed: StringName = _installed_module()
	if installed != &"":
		return "Dock mount (%s)" % _module_name(installed)
	return "Dock mount"


func get_menu() -> ScrollMenu:
	return _menu


func get_actions() -> Array[StringName]:
	_collect_actions()
	return _actions


func get_pod() -> Node3D:
	return _pod


func _ready() -> void:
	var bus: Node = _get_autoload(&"EventBus")
	if bus != null:
		bus.connect(&"module_installed", _on_module_changed)
		bus.connect(&"module_uninstalled", _on_module_changed)
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
	if modules == null:
		return false
	var performed: bool = false
	if action == ACTION_TEARDOWN:
		performed = bool(modules.call(&"uninstall", _installed_module()))
	else:
		performed = bool(modules.call(&"install", StringName(String(action).trim_prefix(ACTION_BUILD_PREFIX))))
	if not performed:
		_emit_sim_event(&"procedure_error", {
			"reason": _refusal(action),
			"hardpoint_id": String(hardpoint_id),
		})
	_refresh_menu()
	_refresh_content()
	return performed


func build_readout() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var installed: StringName = _installed_module()
	if installed != &"":
		lines.append("STANDING: %s" % _module_name(installed).to_upper())
		lines.append("")
		lines.append("Tear it down from this panel to open the dock")
		lines.append("again. Materials are not recovered.")
		return lines
	var modules: Node = _get_system(&"module_system")
	if modules == null:
		lines.append("MOUNT OFFLINE")
		return lines
	lines.append("DOCK %s" % String(hardpoint_id).to_upper())
	lines.append("")
	var cargo: Node = _get_system(&"cargo_system")
	for module: Variant in modules.call(&"get_catalog"):
		var ship_module: ShipModule = module as ShipModule
		if ship_module == null or ship_module.hardpoint_id != hardpoint_id:
			continue
		lines.append("%s - %.0f h" % [ship_module.display_name, ship_module.build_hours])
		for kind: Variant in ship_module.cost:
			var have: float = 0.0
			if cargo != null and cargo.has_method(&"get_units"):
				have = float(cargo.call(&"get_units", StringName(String(kind))))
			lines.append("  %s %.0f / %.0f" % [String(kind), have, float(ship_module.cost[kind])])
	return lines


func _on_module_changed(_module_id: StringName, hardpoint_id: StringName) -> void:
	if hardpoint_id == self.hardpoint_id:
		_sync()
	if is_open():
		_refresh_menu()
		_refresh_content()


## Reconciles the world with ModuleSystem: stands the pod the sim says is installed here,
## or clears it. Called on ready (so a loaded save rebuilds the pod) and on every change.
func _sync() -> void:
	var installed: StringName = _installed_module()
	if installed == &"":
		_clear_pod()
		_set_plate_open(false)
		return
	if spawns:
		_spawn_pod()
	_set_plate_open(true)


func _spawn_pod() -> void:
	if _pod != null or not is_inside_tree():
		return
	var packed: PackedScene = load(POD_SCENE) as PackedScene
	if packed == null:
		return
	var marker: Node3D = _hardpoint_marker()
	var outward: float = -1.0 if hardpoint_id in [&"hp_quarters", &"hp_life_support"] else 1.0
	var pod: Node3D = packed.instantiate() as Node3D
	pod.name = "Pod_" + String(hardpoint_id)
	pod.rotation_degrees.y = 180.0 if outward < 0.0 else 0.0
	# Origin on the hull's outer face at the doorway centre: the band face is the plate's
	# outward face and the room doorway floor is y = 0.
	var x: float = global_position.x + outward * _plate_thickness() * 0.5
	var z: float = global_position.z
	if marker != null and spawns:
		z = marker.global_position.z
	pod.position = Vector3(x, 0.0, z)
	var parent: Node = get_parent()
	parent.add_child(pod)
	_wire_pod(pod)
	_pod = pod


## The pod's own mount panel needs the hardpoint and the room it opens into, and its
## doorway link must bridge the pod compartment with the parent room.
func _wire_pod(pod: Node3D) -> void:
	var modules: Node = _get_system(&"module_system")
	var module: ShipModule = null
	if modules != null and modules.has_method(&"get_module"):
		module = modules.call(&"get_module", _installed_module()) as ShipModule
	var compartment: StringName = &"module"
	var dock_compartment: StringName = &""
	if module != null and module.compartment_config != null:
		compartment = module.compartment_config.compartment_id
		dock_compartment = module.dock_compartment_id
	for mount: Variant in _mounts_in(pod):
		(mount as Node).set(&"hardpoint_id", hardpoint_id)
	var zone: Node = pod.find_child("Zone", true, false)
	if zone != null:
		zone.set(&"compartment_id", compartment)
	var link: Node = pod.find_child("Link", true, false)
	if link != null:
		link.set(&"compartment_a", compartment)
		link.set(&"compartment_b", dock_compartment)


func _clear_pod() -> void:
	if _pod != null and is_instance_valid(_pod):
		_pod.queue_free()
	_pod = null


func _mounts_in(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	if node is ModuleMount and node != self:
		found.append(node)
	for child: Node in node.get_children():
		found.append_array(_mounts_in(child))
	return found


## The plate (this node, when it is the flush mount) hides and stops colliding so the
## doorway is open; the pod carries its own collision from then on.
func _set_plate_open(open: bool) -> void:
	if not spawns:
		return
	var mesh: Node3D = get_node_or_null(^"Mesh") as Node3D
	if mesh != null:
		mesh.visible = not open
	var shape: CollisionShape3D = get_node_or_null(^"Shape") as CollisionShape3D
	if shape != null:
		shape.disabled = open


func _plate_thickness() -> float:
	var shape: CollisionShape3D = get_node_or_null(^"Shape") as CollisionShape3D
	if shape != null and shape.shape is BoxShape3D:
		return (shape.shape as BoxShape3D).size.x
	return 0.15


func _hardpoint_marker() -> Node3D:
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(&"hardpoint"):
		if StringName(node.get_meta(&"hardpoint_id", &"")) == hardpoint_id:
			return node as Node3D
	return null


func _installed_module() -> StringName:
	var modules: Node = _get_system(&"module_system")
	if modules == null or not modules.has_method(&"get_installed_at"):
		return &""
	return StringName(modules.call(&"get_installed_at", hardpoint_id))


func _module_name(module_id: StringName) -> String:
	var modules: Node = _get_system(&"module_system")
	if modules == null or not modules.has_method(&"get_module"):
		return String(module_id)
	var module: ShipModule = modules.call(&"get_module", module_id) as ShipModule
	if module == null:
		return String(module_id)
	return module.display_name


## What the menu offers for this dock right now: teardown when a module stands, else every
## catalog module that docks here.
func _collect_actions() -> void:
	_actions.clear()
	var modules: Node = _get_system(&"module_system")
	var installed: StringName = _installed_module()
	if installed != &"":
		_actions.append(ACTION_TEARDOWN)
		return
	if modules == null:
		return
	for module: Variant in modules.call(&"get_catalog"):
		var ship_module: ShipModule = module as ShipModule
		if ship_module == null or ship_module.hardpoint_id != hardpoint_id:
			continue
		_actions.append(StringName(ACTION_BUILD_PREFIX + String(ship_module.module_id)))


func _refresh_menu() -> void:
	if _menu == null:
		return
	var modules: Node = _get_system(&"module_system")
	var installed: StringName = _installed_module()
	_collect_actions()
	var items: PackedStringArray = PackedStringArray()
	for action: StringName in _actions:
		if action == ACTION_TEARDOWN:
			items.append("Tear down %s" % _module_name(installed))
		else:
			var module_id: StringName = StringName(String(action).trim_prefix(ACTION_BUILD_PREFIX))
			var ship_module: ShipModule = modules.call(&"get_module", module_id) as ShipModule
			if ship_module != null:
				items.append("Build %s (%.0f h)" % [ship_module.display_name, ship_module.build_hours])
	if items.is_empty():
		items.append("(no module for this dock)")
	_menu.set_items(items)


func _refresh_content() -> void:
	if _content != null:
		_content.text = "\n".join(build_readout())


func _refusal(action: StringName) -> StringName:
	var modules: Node = _get_system(&"module_system")
	if modules == null:
		return &"mount_offline"
	if action == ACTION_TEARDOWN:
		return &"module_not_installed"
	var module_id: StringName = StringName(String(action).trim_prefix(ACTION_BUILD_PREFIX))
	if modules.has_method(&"can_install"):
		return StringName(modules.call(&"can_install", module_id))
	return &"unknown_module"


func _ensure_ui() -> void:
	if _root != null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MountView"
	layer.layer = 12
	add_child(layer)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Mount"
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	_menu = ScrollMenu.new()
	_menu.name = "Actions"
	row.add_child(_menu)
	_menu.setup("DOCK MOUNT", PackedStringArray(["(no module for this dock)"]))
	if not _menu.option_selected.is_connected(_on_selected):
		_menu.option_selected.connect(_on_selected)
	var content_panel: PanelContainer = PanelContainer.new()
	content_panel.custom_minimum_size = Vector2(340.0, 0.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.02, 0.62)
	style.border_color = Color(0.65, 0.55, 0.3, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(18.0)
	content_panel.add_theme_stylebox_override("panel", style)
	row.add_child(content_panel)
	_content = Label.new()
	_content.name = "MountReadout"
	_content.add_theme_font_size_override("font_size", 14)
	_content.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 1.0))
	content_panel.add_child(_content)
	_root = row


func _on_selected(index: int) -> void:
	if index < 0 or index >= _actions.size():
		return
	select_action(_actions[index])
