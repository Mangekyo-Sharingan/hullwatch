## Authored machine that can be fitted into a pod socket. Machines are what actually do the
## work inside a pod: a bare pod is just a room, and every contribution comes from the machines
## bolted into its sockets. Nanites fit them over `build_hours`, and any machine that is not
## `portable` (the ship's vital life-support machinery) refuses to be taken back out.
class_name ShipMachine
extends Resource

@export var machine_id: StringName = &""
@export var display_name: String = ""
## What the machine contributes once fitted, same channels as modules: `rations` (per day),
## `fabrication` (fraction of bench time saved), `cargo` (extra hold units), `power` (extra
## battery Wh), `recovery` (extra condition per hour).
@export var effect: StringName = &""
@export var effect_amount: float = 0.0
@export var power_load_w: float = 0.0
@export var circuit_id: StringName = &""
@export var build_hours: float = 4.0
## Material kind (as in CargoSystem) -> units.
@export var cost: Dictionary = {}
@export var portable: bool = true
## Hint for the socket prop's size, in metres (width, height, depth).
@export var size_m: Vector3 = Vector3(0.8, 1.1, 0.8)
