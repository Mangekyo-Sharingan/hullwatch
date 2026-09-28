## Applies the current route's distant-body palette to the WorldEnvironment sky.
extends WorldEnvironment


func _ready() -> void:
	var event_bus: Node = get_node_or_null(^"/root/EventBus")
	if event_bus != null:
		event_bus.connect(&"destination_arrived", _on_destination_arrived)
		event_bus.connect(&"destination_state_restored", _on_destination_state_restored)
	call_deferred("_apply_current_destination")


func _on_destination_arrived(destination_id: StringName, _kind: StringName, _sector_seed: int, _resource_id: StringName, _resource_units: float, _arrival_stores: Dictionary) -> void:
	_apply_destination(destination_id)


func _on_destination_state_restored(destination_id: StringName) -> void:
	_apply_destination(destination_id)


func _apply_current_destination() -> void:
	var nav: Node = get_tree().get_first_node_in_group(&"nav_system")
	if nav == null:
		return
	var status: Dictionary = nav.call("get_status")
	_apply_destination(status["current_destination_id"])


func _apply_destination(destination_id: StringName) -> void:
	var nav: Node = get_tree().get_first_node_in_group(&"nav_system")
	if nav == null:
		return
	var destination: VoyageDestination = nav.call("get_destination", destination_id)
	if destination == null:
		return
	if environment != null and environment.sky != null:
		var sky_material: ShaderMaterial = environment.sky.sky_material as ShaderMaterial
		if sky_material != null:
			sky_material.set_shader_parameter(&"sun_direction", destination.sun_direction.normalized())
			sky_material.set_shader_parameter(&"sun_color", destination.sun_color)
			sky_material.set_shader_parameter(&"sun_size", destination.sun_size)
			sky_material.set_shader_parameter(&"planet_direction", destination.planet_direction.normalized())
			sky_material.set_shader_parameter(&"planet_color", destination.planet_color)
			sky_material.set_shader_parameter(&"planet_band_color", destination.planet_band_color)
			sky_material.set_shader_parameter(&"planet_size", destination.planet_size)
