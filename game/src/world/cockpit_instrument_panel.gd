## Drives authored cockpit needles, digits and lamps from simulator-owned state.
class_name CockpitInstrumentPanel
extends StaticBody3D

const CIRCUIT_IDS: Array[StringName] = [&"life_support", &"lighting", &"airlock"]
const DIGIT_SEGMENTS: Array[Array] = [
	[&"a", &"b", &"c", &"d", &"e", &"f"],
	[&"b", &"c"],
	[&"a", &"b", &"d", &"e", &"g"],
	[&"a", &"b", &"c", &"d", &"g"],
	[&"b", &"c", &"f", &"g"],
	[&"a", &"c", &"d", &"f", &"g"],
	[&"a", &"c", &"d", &"e", &"f", &"g"],
	[&"a", &"b", &"c"],
	[&"a", &"b", &"c", &"d", &"e", &"f", &"g"],
	[&"a", &"b", &"c", &"d", &"f", &"g"],
]
const DIAL_MIN_DEGREES: float = -130.0
const DIAL_MAX_DEGREES: float = 130.0
const DIAL_NORMAL: Vector3 = Vector3(0.0, 0.0, 1.0)
const DISPLAY_REFRESH_SECONDS: float = 0.25

@export var instrument_id: StringName = &""

var _model: Node3D
var _needles: Dictionary = {}
var _needle_rest: Dictionary = {}
var _needle_pivots: Dictionary = {}
var _segments: Dictionary = {}
var _lamps: Dictionary = {}
var _lamp_materials: Dictionary = {}
var _lamp_base: Dictionary = {}
var _refresh_accumulator: float = 0.0


func _ready() -> void:
	_model = get_node_or_null(^"Model") as Node3D
	_cache_instrument_nodes()
	refresh_from_systems()


## Reads simulator state for diegetic visual feedback; no authoritative state lives here.
func refresh_from_systems() -> void:
	if _model == null or not is_instance_valid(_model):
		_model = get_node_or_null(^"Model") as Node3D
		_cache_instrument_nodes()
	match instrument_id:
		&"gauge_cluster":
			_refresh_gauges()
		&"seven_segment":
			_refresh_seven_segment()
		&"switch_bank":
			_refresh_switch_bank()


func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator >= DISPLAY_REFRESH_SECONDS:
		_refresh_accumulator = 0.0
		refresh_from_systems()


func _cache_instrument_nodes() -> void:
	if _model == null:
		return
	match instrument_id:
		&"gauge_cluster":
			for index: int in 3:
				var suffix: String = str(index)
				var key: StringName = StringName("ndl" + suffix)
				var needle_name: String = "hw_gauge_cluster_ndl" + suffix
				var face_name: String = "hw_gauge_cluster_face" + suffix
				var needle: MeshInstance3D = _model.find_child(needle_name, true, false) as MeshInstance3D
				var face: MeshInstance3D = _model.find_child(face_name, true, false) as MeshInstance3D
				if needle == null or face == null or _needles.has(key):
					continue
				_needles[key] = needle
				_needle_rest[key] = needle.transform
				_needle_pivots[key] = face.get_aabb().get_center()
		&"seven_segment":
			for digit: int in 3:
				var digit_key: StringName = StringName("d" + str(digit))
				var digit_segments: Dictionary = {}
				for segment: StringName in [&"a", &"b", &"c", &"d", &"e", &"f", &"g"]:
					var node_name: String = "hw_seven_segment_%s_%s" % [String(digit_key), String(segment)]
					var mesh: MeshInstance3D = _model.find_child(node_name, true, false) as MeshInstance3D
					if mesh != null:
						digit_segments[segment] = mesh
				if not digit_segments.is_empty():
					_segments[digit_key] = digit_segments
		&"switch_bank":
			for index: int in CIRCUIT_IDS.size():
				var key: StringName = StringName("lamp" + str(index))
				var lamp_name: String = "hw_switch_bank_lamp%d_lamp" % index
				var lamp: MeshInstance3D = _model.find_child(lamp_name, true, false) as MeshInstance3D
				if lamp == null or _lamps.has(key):
					continue
				var source: BaseMaterial3D = lamp.get_active_material(0) as BaseMaterial3D
				var instance: StandardMaterial3D = source.duplicate() as StandardMaterial3D if source != null else null
				if instance == null:
					instance = StandardMaterial3D.new()
				_lamps[key] = lamp
				_lamp_materials[key] = instance
				_lamp_base[key] = {
					"albedo": instance.albedo_color,
					"emission": instance.emission,
					"emission_enabled": instance.emission_enabled,
					"energy": maxf(instance.emission_energy_multiplier, 1.0),
				}
				lamp.material_override = instance


func _refresh_gauges() -> void:
	var power: Node = _system(&"power_system")
	if power != null and power.has_method(&"get_status"):
		var power_status: Dictionary = power.call(&"get_status")
		if power_status.has("battery_fraction"):
			_set_needle_fraction(&"ndl0", float(power_status["battery_fraction"]))
	var atmosphere: Node = _system(&"atmosphere_system")
	if atmosphere != null and atmosphere.has_method(&"get_compartment_status"):
		var air_status: Dictionary = atmosphere.call(&"get_compartment_status", &"cockpit")
		if air_status.has("pressure_kpa"):
			_set_needle_fraction(&"ndl1", float(air_status["pressure_kpa"]) / 100.0)
	var thermal: Node = _system(&"thermal_system")
	if thermal != null and thermal.has_method(&"get_compartment_status"):
		var thermal_status: Dictionary = thermal.call(&"get_compartment_status", &"cockpit")
		if thermal_status.has("temperature_c"):
			_set_needle_fraction(&"ndl2", (float(thermal_status["temperature_c"]) + 30.0) / 70.0)


func _refresh_seven_segment() -> void:
	var atmosphere: Node = _system(&"atmosphere_system")
	if atmosphere == null or not atmosphere.has_method(&"get_compartment_status"):
		return
	var air_status: Dictionary = atmosphere.call(&"get_compartment_status", &"cockpit")
	if not air_status.has("co2_ppm"):
		return
	var co2_ppm: int = clampi(int(roundf(float(air_status["co2_ppm"]))), 0, 999)
	var digits: String = str(co2_ppm).pad_zeros(3)
	for index: int in 3:
		var key: StringName = StringName("d" + str(index))
		if not _segments.has(key):
			continue
		var digit: int = int(digits.substr(index, 1))
		var lit_segments: Array = DIGIT_SEGMENTS[digit]
		var digit_segments: Dictionary = _segments[key]
		for segment: StringName in digit_segments:
			(digit_segments[segment] as MeshInstance3D).visible = lit_segments.has(segment)


func _refresh_switch_bank() -> void:
	var power: Node = _system(&"power_system")
	if power == null or not power.has_method(&"get_status"):
		return
	var power_status: Dictionary = power.call(&"get_status")
	var circuits: Dictionary = power_status.get("circuits", {})
	for index: int in CIRCUIT_IDS.size():
		var key: StringName = StringName("lamp" + str(index))
		var circuit: Dictionary = circuits.get(CIRCUIT_IDS[index], {})
		if not circuit.is_empty() and _lamp_materials.has(key):
			_set_lamp_served(key, bool(circuit.get("served", false)))


func _set_needle_fraction(needle_id: StringName, value: float) -> void:
	if not _needles.has(needle_id) or not is_finite(value):
		return
	var needle: MeshInstance3D = _needles[needle_id] as MeshInstance3D
	var rest: Transform3D = _needle_rest[needle_id]
	var pivot: Vector3 = _needle_pivots[needle_id]
	var fraction: float = clampf(value, 0.0, 1.0)
	var angle: float = deg_to_rad(lerpf(DIAL_MIN_DEGREES, DIAL_MAX_DEGREES, fraction))
	var rotation: Basis = Basis(DIAL_NORMAL, angle)
	needle.transform = Transform3D(
		rotation * rest.basis,
		pivot + rotation * (rest.origin - pivot)
	)


func _set_lamp_served(lamp_id: StringName, served: bool) -> void:
	var material: StandardMaterial3D = _lamp_materials[lamp_id] as StandardMaterial3D
	var base: Dictionary = _lamp_base[lamp_id]
	var base_color: Color = base["albedo"]
	material.albedo_color = base_color if served else base_color.darkened(0.82)
	material.emission = base["emission"]
	material.emission_enabled = true
	material.emission_energy_multiplier = float(base["energy"]) if served else 0.0
	if served and not bool(base["emission_enabled"]):
		material.emission = base_color


func _system(group_name: StringName) -> Node:
	return get_tree().get_first_node_in_group(group_name)
