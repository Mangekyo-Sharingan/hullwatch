class_name CompartmentConfig
extends Resource

@export var compartment_id: StringName = &""
@export var display_name: String = ""
@export var volume_m3: float = 40.0
@export var initial_pressure_kpa: float = 101.325
@export var initial_o2_fraction: float = 0.21
@export var initial_co2_ppm: float = 400.0
@export var initial_occupants: int = 0
@export var leak_rate_per_hour: float = 0.0
@export var scrubber_capacity_kg_per_hour: float = 0.055
@export var filter_wear_rate_per_hour: float = 0.004
@export var initial_filter_condition: float = 1.0
@export var o2_candles_stocked: int = 0
@export var o2_candle_kg: float = 1.0
@export var o2_candle_burn_hours: float = 2.0
@export var initial_temperature_c: float = 21.0
@export var thermal_capacity_j_per_k: float = 90000.0
@export var hull_conductance_w_per_k: float = 3.0
@export var heater_watts: float = 400.0
@export var heater_target_c: float = 21.0
@export var heater_deadband_c: float = 1.0
@export var occupant_heat_w: float = 100.0
@export var freeze_threshold_c: float = 1.0
@export var puncture_mtbf_hours: float = 6000.0
@export var puncture_leak_per_hour: float = 0.004
@export var initial_heat_gain_w: float = 0.0
