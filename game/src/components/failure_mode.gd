class_name FailureMode
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var base_mtbf_hours: float = 1000.0
@export var wear_multiplier: float = 1.0
@export var max_condition: float = 1.0
@export var environmental_factors: Dictionary = {}
@export var severity: int = 1
@export var symptoms: Array[StringName] = []
