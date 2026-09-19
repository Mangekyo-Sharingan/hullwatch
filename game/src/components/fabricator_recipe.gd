## One fabrication recipe: consumes cargo material, produces a stores part after hours.
class_name FabricatorRecipe
extends Resource

@export var recipe_id: StringName = &""
@export var display_name: String = ""
@export var material_kind: StringName = &"ice"
@export var material_units: float = 4.0
@export var output_part_id: StringName = &"water_filter"
@export var output_count: int = 1
@export var hours: float = 1.5
