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
## The room the dock pod's doorway opens into (atmosphere link target).
@export var dock_compartment_id: StringName = &""
## Displayed on the dock mount as the build estimate. The sim does not stand the pod up
## over the clock yet (M10.4 wiring lands first); the mount is instant once paid for.
@export var build_hours: float = 8.0
