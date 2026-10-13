## Cabin fixture powered by the ship's lighting circuit.
extends Light3D

const CIRCUIT_ID: StringName = &"lighting"

@export var fixture_id: StringName = &""
@export var fixture_label: String = ""
@export var fixture_config: PowerCircuit = preload("res://src/data/power/cabin_fixture.tres")
@export var fixture_model: NodePath

var _event_bus: Node
var _power: PowerSystem
var _registered: bool = false
var _emission_materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus != null:
		_event_bus.connect(&"sim_event", _on_sim_event)
	call_deferred(&"_register")


func _register() -> void:
	if not is_inside_tree() or _registered:
		return
	_power = get_tree().get_first_node_in_group(&"power_system") as PowerSystem
	if fixture_id == &"":
		fixture_id = StringName(String(get_parent().name) + "/" + String(name))
	if fixture_label.is_empty():
		fixture_label = String(get_parent().name).trim_prefix("Pod_hp_").replace("_", " ").to_upper() + " POD" if name == &"PodLight" else String(fixture_id).replace("_", " ").to_upper()
	if _power != null and fixture_config != null:
		_registered = _power.register_light(fixture_id, fixture_label, fixture_config.nominal_load_w)
	var model: Node = get_node_or_null(fixture_model) if not fixture_model.is_empty() else null
	if model != null:
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = node as MeshInstance3D
			for surface: int in mesh.mesh.get_surface_count():
				var material: StandardMaterial3D = mesh.get_active_material(surface) as StandardMaterial3D
				if material == null or not material.emission_enabled:
					continue
				var local: StandardMaterial3D = material.duplicate() as StandardMaterial3D
				mesh.set_surface_override_material(surface, local)
				_emission_materials.append(local)
	_sync_power()


func _exit_tree() -> void:
	if _registered and is_instance_valid(_power) and not _power.is_queued_for_deletion():
		_power.unregister_light(fixture_id)
	_registered = false
	if _event_bus != null and _event_bus.is_connected(&"sim_event", _on_sim_event):
		_event_bus.disconnect(&"sim_event", _on_sim_event)


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name in [&"power_state_restored", &"lighting_changed", &"component_failed", &"component_repaired"]:
		_sync_power()
		return
	if event_name not in [&"breaker_toggled", &"circuit_shed", &"circuit_restored"]:
		return
	if StringName(payload.get("circuit_id", &"")) != CIRCUIT_ID:
		return
	_sync_power()


func _sync_power() -> void:
	visible = _registered and is_instance_valid(_power) and _power.is_light_powered(fixture_id)
	for material: StandardMaterial3D in _emission_materials:
		material.emission_enabled = visible
