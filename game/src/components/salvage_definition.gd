class_name SalvageDefinition
extends Resource

@export var salvage_id: StringName = &""
@export var machine: ShipMachine
@export var initial_condition: float = 0.35
@export var repaired_condition: float = 1.0
@export var repair_material: StringName = &"metal"
@export var repair_units: float = 1.0
@export var cargo_units: float = 6.0
@export var scrap_material: StringName = &"metal"
@export var scrap_units: float = 2.0
@export var case_size: Vector3 = Vector3(0.48, 0.36, 0.32)
