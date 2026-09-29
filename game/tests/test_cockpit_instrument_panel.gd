## Authored cockpit meters mirror simulator state and tolerate absent system groups.
extends SceneTree

const PANEL_SCRIPT: Script = preload("res://src/world/cockpit_instrument_panel.gd")
const GAUGE_MODEL: String = "res://assets/models/hullwatch/cockpit/hw_gauge_cluster.glb"
const DIGIT_MODEL: String = "res://assets/models/hullwatch/cockpit/hw_seven_segment.glb"
const SWITCH_MODEL: String = "res://assets/models/hullwatch/cockpit/hw_switch_bank.glb"

var _failures: int = 0
var _power: MockPowerSystem
var _atmosphere: MockAtmosphereSystem
var _thermal: MockThermalSystem


class MockPowerSystem extends Node:
	var battery_fraction: float = 0.25
	var circuits: Dictionary = {
		&"life_support": {"served": true},
		&"lighting": {"served": false},
		&"airlock": {"served": true},
	}

	func get_status() -> Dictionary:
		return {"battery_fraction": battery_fraction, "circuits": circuits}


class MockAtmosphereSystem extends Node:
	var pressure_kpa: float = 50.0
	var co2_ppm: float = 987.0

	func get_compartment_status(compartment_id: StringName) -> Dictionary:
		if compartment_id != &"cockpit":
			return {}
		return {"pressure_kpa": pressure_kpa, "co2_ppm": co2_ppm}


class MockThermalSystem extends Node:
	var temperature_c: float = 5.0

	func get_compartment_status(compartment_id: StringName) -> Dictionary:
		if compartment_id != &"cockpit":
			return {}
		return {"temperature_c": temperature_c}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_test_missing_groups()
	_install_mock_systems()
	_test_gauges()
	_test_seven_segment()
	_test_switch_bank()
	_finish()


func _test_missing_groups() -> void:
	var panel: StaticBody3D = _make_panel(&"gauge_cluster", GAUGE_MODEL)
	panel.call("refresh_from_systems")
	_check(panel.get_node_or_null(^"Model") != null, "panel discovers its authored Model child")
	panel.free()


func _install_mock_systems() -> void:
	_power = MockPowerSystem.new()
	_power.name = &"MockPower"
	_power.add_to_group(&"power_system")
	root.add_child(_power)
	_atmosphere = MockAtmosphereSystem.new()
	_atmosphere.name = &"MockAtmosphere"
	_atmosphere.add_to_group(&"atmosphere_system")
	root.add_child(_atmosphere)
	_thermal = MockThermalSystem.new()
	_thermal.name = &"MockThermal"
	_thermal.add_to_group(&"thermal_system")
	root.add_child(_thermal)


func _test_gauges() -> void:
	var panel: StaticBody3D = _make_panel(&"gauge_cluster", GAUGE_MODEL)
	panel.call("refresh_from_systems")
	var power_needle: MeshInstance3D = panel.find_child("hw_gauge_cluster_ndl0", true, false) as MeshInstance3D
	var pressure_needle: MeshInstance3D = panel.find_child("hw_gauge_cluster_ndl1", true, false) as MeshInstance3D
	var temperature_needle: MeshInstance3D = panel.find_child("hw_gauge_cluster_ndl2", true, false) as MeshInstance3D
	_check(power_needle != null and _angle_matches(power_needle, -65.0), "power needle maps battery fraction across the dial")
	_check(pressure_needle != null and _angle_matches(pressure_needle, 0.0), "pressure needle maps cockpit pressure")
	_check(temperature_needle != null and _angle_matches(temperature_needle, 0.0), "temperature needle maps the cockpit midpoint")
	_power.battery_fraction = 0.75
	_atmosphere.pressure_kpa = 90.0
	_thermal.temperature_c = 40.0
	panel.call("_process", 0.25)
	_check(_angle_matches(power_needle, 65.0), "display cadence refreshes battery needle")
	_check(_angle_matches(pressure_needle, 104.0), "display cadence refreshes pressure needle")
	_check(_angle_matches(temperature_needle, 130.0), "display cadence refreshes temperature needle")
	panel.free()


func _test_seven_segment() -> void:
	var panel: StaticBody3D = _make_panel(&"seven_segment", DIGIT_MODEL)
	panel.call("refresh_from_systems")
	_check(_segment_visible(panel, 0, &"a") and not _segment_visible(panel, 0, &"e"), "digit 9 lights the conventional segments")
	_check(_segment_visible(panel, 1, &"a") and _segment_visible(panel, 1, &"g") and _segment_visible(panel, 1, &"d"), "digit 8 lights all segments")
	_check(_segment_visible(panel, 2, &"a") and _segment_visible(panel, 2, &"c") and not _segment_visible(panel, 2, &"d"), "digit 7 lights its conventional segments")
	_atmosphere.co2_ppm = 42.0
	panel.call("_process", 0.25)
	_check(not _segment_visible(panel, 0, &"g"), "CO2 readout zero-pads the hundreds digit")
	_check(_segment_visible(panel, 1, &"f") and not _segment_visible(panel, 1, &"e"), "CO2 readout changes the tens digit")
	_check(_segment_visible(panel, 2, &"e") and _segment_visible(panel, 2, &"g"), "CO2 readout changes the units digit")
	_atmosphere.co2_ppm = 1200.0
	panel.call("refresh_from_systems")
	_check(not _segment_visible(panel, 0, &"e") and _segment_visible(panel, 2, &"g"), "CO2 readout clamps above 999")
	panel.free()


func _test_switch_bank() -> void:
	var panel: StaticBody3D = _make_panel(&"switch_bank", SWITCH_MODEL)
	panel.call("refresh_from_systems")
	var life_support: StandardMaterial3D = _lamp_material(panel, 0)
	var lighting: StandardMaterial3D = _lamp_material(panel, 1)
	var airlock: StandardMaterial3D = _lamp_material(panel, 2)
	_check(life_support != null and life_support.emission_energy_multiplier > 0.0, "served life support circuit lights lamp zero")
	_check(lighting != null and is_zero_approx(lighting.emission_energy_multiplier), "unserved lighting circuit darkens lamp one")
	_check(airlock != null and airlock.emission_energy_multiplier > 0.0, "served airlock circuit lights lamp two")
	_check(life_support != lighting and lighting != airlock, "each lamp uses its own material instance")
	_power.circuits[&"life_support"] = {"served": false}
	_power.circuits[&"lighting"] = {"served": true}
	panel.call("_process", 0.25)
	_check(is_zero_approx(life_support.emission_energy_multiplier), "display cadence darkens a shed circuit")
	_check(lighting.emission_energy_multiplier > 0.0, "display cadence lights a restored circuit")
	panel.free()


func _make_panel(id: StringName, model_path: String) -> StaticBody3D:
	var packed: PackedScene = load(model_path) as PackedScene
	_check(packed != null, "authored instrument model loads: " + model_path.get_file())
	var panel := StaticBody3D.new()
	panel.set_script(PANEL_SCRIPT)
	panel.set(&"instrument_id", id)
	var model: Node3D = packed.instantiate() as Node3D if packed != null else Node3D.new()
	model.name = &"Model"
	panel.add_child(model)
	root.add_child(panel)
	return panel


func _angle_matches(needle: MeshInstance3D, expected_degrees: float) -> bool:
	return needle != null and absf(rad_to_deg(needle.rotation.z) - expected_degrees) <= 0.1


func _segment_visible(panel: Node, digit: int, segment: StringName) -> bool:
	var name: String = "hw_seven_segment_d%d_%s" % [digit, String(segment)]
	var mesh: MeshInstance3D = panel.find_child(name, true, false) as MeshInstance3D
	return mesh != null and mesh.visible


func _lamp_material(panel: Node, index: int) -> StandardMaterial3D:
	var name: String = "hw_switch_bank_lamp%d_lamp" % index
	var lamp: MeshInstance3D = panel.find_child(name, true, false) as MeshInstance3D
	return lamp.material_override as StandardMaterial3D if lamp != null else null


func _remove_root_child(node_name: StringName) -> void:
	var existing: Node = root.get_node_or_null(NodePath(String(node_name)))
	if existing != null:
		root.remove_child(existing)
		existing.free()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_cockpit_instrument_panel")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
