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
## Displayed on the dock mount as the build estimate. Nanites assemble the pod over this many
## hours of ship time; the trickier the machine inside, the longer it takes.
@export var build_hours: float = 8.0
## What the pod contributes once it stands: `rations` (per day), `fabrication` (fraction of
## bench time saved), `cargo` (extra hold units), `power` (extra battery Wh), `recovery`
## (extra condition per hour). Empty for a bare pod.
@export var effect: StringName = &""
@export var effect_amount: float = 0.0
## Draw the module puts on a circuit while it runs, and which circuit that is (empty = none).
@export var power_load_w: float = 0.0
@export var circuit_id: StringName = &""
