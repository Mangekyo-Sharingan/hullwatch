## Authored catalog entry for an installable dock module: what it costs, which hardpoint it
## docks at, and the compartment it contributes to the life-support sims once built.
class_name ShipModule
extends Resource

@export var module_id: StringName = &""
@export var display_name: String = ""
@export var hardpoint_id: StringName = &""
@export var pod_recipe: StringName = &"dock_pod"
## Material kind (as in CargoSystem) -> units.
@export var cost: Dictionary = {}
@export var compartment_config: CompartmentConfig
## The room the pod doorway opens into (atmosphere link target).
@export var dock_compartment_id: StringName = &""
