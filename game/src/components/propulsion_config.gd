class_name PropulsionConfig
extends Resource

@export var tank_capacity_kg: float
@export var initial_mass_kg: float
@export var seed_mass_kg: float
@export var restart_mass_kg: float
@export var replication_kg_per_hour: float
@export var output_wh_per_kg: float
@export var uv_watts: float
@export var uv_circuit: StringName = &"xenonite_uv"
@export var pair_output_w: float
@export var single_output_w: float
@export var single_progress_rate: float
@export var heat_fraction: float
@export var compartment_id: StringName = &"engine_bay"
@export var overheat_c: float
@export var resume_c: float
@export var repair_hours: float
@export var repair_quality: float
@export var wear_seed: int
@export var components: Array[WearComponent] = []
