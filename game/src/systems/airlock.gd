## Single airlock: pressure-cycle state machine, door interlock, and the EVA suit in its locker.
## The pump moves gas between the lock and the habitable interior (conserving it) or vents
## it to space. The outer door only opens on vacuum, the inner only on pressure.
class_name AirlockSystem
extends ShipSystem

enum State { IDLE, PRESSURIZING, DEPRESSURIZING, VENTING }

const O2_MOLES_PER_HOUR: float = 0.035 / 0.032
const INNER_OPEN_MIN_KPA: float = 60.0
const INTERIOR_SUPPLY_FLOOR_KPA: float = 30.0
const TARGET_REACHED_FRACTION: float = 0.99
const VENT_HOURS: float = 0.02

@export var airlock_id: StringName = &"airlock_main"
@export var compartment_id: StringName = &"airlock"
@export var interior_compartment_id: StringName = &"storage"
@export var circuit_id: StringName = &"airlock"
@export var pump_moles_per_hour: float = 2200.0
@export var target_pressure_kpa: float = 101.325
@export var suit_o2_capacity_hours: float = 4.0
@export var suit_refill_draw_moles: float = 6.0

var state: int = State.IDLE
var inner_open: bool = false
var outer_open: bool = false
var suit_stored: bool = true
var suit_worn: bool = false
var suit_o2_hours: float = 0.0

var _vent_remaining_hours: float = 0.0
var _stalled: bool = false
var _suit_depleted_emitted: bool = false


func _ready() -> void:
	system_id = &"airlock"
	add_to_group(&"airlock_system")
	super._ready()


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		return
	match state:
		State.DEPRESSURIZING:
			_tick_depressurize(delta_hours)
		State.PRESSURIZING:
			_tick_pressurize(delta_hours)
		State.VENTING:
			_vent_remaining_hours = maxf(_vent_remaining_hours - delta_hours, 0.0)
			if _vent_remaining_hours <= 0.0:
				_set_state(State.IDLE)
	if state == State.IDLE and outer_open and _pressure() > AtmosphereSystem.VACUUM_PRESSURE_KPA:
		var atmosphere: Node = _atmosphere_system()
		if atmosphere != null and atmosphere.has_method(&"vent_gas"):
			atmosphere.call("vent_gas", compartment_id)


func get_state_name() -> StringName:
	match state:
		State.PRESSURIZING:
			return &"pressurizing"
		State.DEPRESSURIZING:
			return &"depressurizing"
		State.VENTING:
			return &"venting"
		_:
			return &"idle"


func request_door(side: StringName, open: bool) -> bool:
	if not open:
		if side == &"inner":
			inner_open = false
		elif side == &"outer":
			outer_open = false
		else:
			return false
		_emit_state_changed()
		return true
	if state != State.IDLE:
		return false
	if side == &"inner":
		if outer_open or _pressure() < INNER_OPEN_MIN_KPA:
			return false
		inner_open = true
		_emit_state_changed()
		return true
	if side == &"outer":
		if inner_open or _pressure() > AtmosphereSystem.VACUUM_PRESSURE_KPA:
			return false
		outer_open = true
		_emit_state_changed()
		return true
	return false


func get_door_refusal(side: StringName, open: bool) -> StringName:
	if not open:
		return &""
	if state != State.IDLE:
		return &"airlock_cycling"
	if side == &"inner":
		if outer_open:
			return &"airlock_interlock"
		if _pressure() < INNER_OPEN_MIN_KPA:
			return &"airlock_depressurized"
	elif side == &"outer":
		if inner_open:
			return &"airlock_interlock"
		if _pressure() > AtmosphereSystem.VACUUM_PRESSURE_KPA:
			return &"airlock_pressurized"
	return &""


## Restores door state from a loaded save without running the interlock.
func force_door_state(side: StringName, open: bool) -> void:
	if side == &"inner":
		inner_open = open
	elif side == &"outer":
		outer_open = open
	_emit_state_changed()


func request_cycle(mode: StringName) -> bool:
	if state != State.IDLE:
		return false
	match mode:
		&"depressurize":
			if inner_open or _pressure() <= AtmosphereSystem.VACUUM_PRESSURE_KPA:
				return false
			_set_state(State.DEPRESSURIZING)
			emit_sim_event(&"airlock_cycle_started", {"airlock_id": airlock_id, "mode": mode})
			return true
		&"pressurize":
			if outer_open or _pressure() >= target_pressure_kpa * TARGET_REACHED_FRACTION:
				return false
			_set_state(State.PRESSURIZING)
			emit_sim_event(&"airlock_cycle_started", {"airlock_id": airlock_id, "mode": mode})
			return true
		&"vent":
			if inner_open or _pressure() <= AtmosphereSystem.VACUUM_PRESSURE_KPA:
				return false
			var lost: float = _vent()
			_vent_remaining_hours = VENT_HOURS
			_set_state(State.VENTING)
			emit_sim_event(&"airlock_cycle_started", {"airlock_id": airlock_id, "mode": mode})
			emit_sim_event(&"airlock_vented", {"airlock_id": airlock_id, "moles_lost": lost})
			return true
	return false


func equip_suit() -> bool:
	if not suit_stored or suit_worn:
		return false
	suit_stored = false
	suit_worn = true
	emit_sim_event(&"suit_equipped", {"airlock_id": airlock_id, "o2_hours": suit_o2_hours})
	return true


func store_suit() -> bool:
	if not suit_worn:
		return false
	suit_worn = false
	suit_stored = true
	emit_sim_event(&"suit_stored", {"airlock_id": airlock_id, "o2_hours": suit_o2_hours})
	return true


func refill_suit() -> float:
	if not suit_stored or suit_o2_hours >= suit_o2_capacity_hours:
		return 0.0
	var atmosphere: Node = _atmosphere_system()
	if atmosphere == null or not atmosphere.has_method(&"remove_gas_moles"):
		return 0.0
	var needed_hours: float = suit_o2_capacity_hours - suit_o2_hours
	var needed_moles: float = minf(needed_hours * O2_MOLES_PER_HOUR, suit_refill_draw_moles)
	var removed: Variant = atmosphere.call("remove_gas_moles", interior_compartment_id, needed_moles, 0.0, 0.0)
	if not (removed is Dictionary):
		return 0.0
	var drawn: float = float((removed as Dictionary).get("o2", 0.0))
	if drawn <= 0.0:
		return 0.0
	suit_o2_hours = minf(suit_o2_hours + drawn / O2_MOLES_PER_HOUR, suit_o2_capacity_hours)
	_suit_depleted_emitted = false
	emit_sim_event(&"suit_refilled", {"airlock_id": airlock_id, "o2_hours": suit_o2_hours})
	return drawn


## Vitals calls this while the operator stands in vacuum; false means unprotected.
func consume_suit_o2(hours: float) -> bool:
	if not suit_worn or hours <= 0.0:
		return false
	if suit_o2_hours <= 0.0:
		_emit_suit_depleted_once()
		return false
	suit_o2_hours = maxf(suit_o2_hours - hours, 0.0)
	if suit_o2_hours <= 0.0:
		_emit_suit_depleted_once()
		return false
	return true


func is_suit_worn() -> bool:
	return suit_worn


func get_status() -> Dictionary:
	return {
		"system_id": system_id,
		"airlock_id": airlock_id,
		"state": get_state_name(),
		"pressure_kpa": _pressure(),
		"inner_open": inner_open,
		"outer_open": outer_open,
		"suit_stored": suit_stored,
		"suit_worn": suit_worn,
		"suit_o2_hours": suit_o2_hours,
	}


func save_state() -> Dictionary:
	return {
		"system_id": String(system_id),
		"state_version": 1,
		"state": state,
		"inner_open": inner_open,
		"outer_open": outer_open,
		"suit_stored": suit_stored,
		"suit_worn": suit_worn,
		"suit_o2_hours": suit_o2_hours,
	}


func load_state(state_dict: Dictionary) -> void:
	state = clampi(int(state_dict.get("state", state)), State.IDLE, State.VENTING)
	if state == State.VENTING:
		state = State.IDLE
	inner_open = bool(state_dict.get("inner_open", inner_open))
	outer_open = bool(state_dict.get("outer_open", outer_open))
	suit_stored = bool(state_dict.get("suit_stored", suit_stored))
	suit_worn = bool(state_dict.get("suit_worn", suit_worn))
	suit_o2_hours = maxf(float(state_dict.get("suit_o2_hours", suit_o2_hours)), 0.0)
	_vent_remaining_hours = 0.0
	_stalled = false
	_suit_depleted_emitted = suit_o2_hours <= 0.0 and suit_worn


func _tick_depressurize(hours: float) -> void:
	var atmosphere: Node = _atmosphere_system()
	if atmosphere == null or not atmosphere.has_method(&"transfer_gas"):
		return
	if not _pump_powered():
		_emit_stall_once()
		return
	_stalled = false
	atmosphere.call("transfer_gas", compartment_id, interior_compartment_id, pump_moles_per_hour * hours)
	if _pressure() <= AtmosphereSystem.VACUUM_PRESSURE_KPA:
		atmosphere.call("transfer_gas", compartment_id, interior_compartment_id, _moles())
		_set_state(State.IDLE)
		emit_sim_event(&"airlock_depressurized", {"airlock_id": airlock_id})


func _tick_pressurize(hours: float) -> void:
	var atmosphere: Node = _atmosphere_system()
	if atmosphere == null or not atmosphere.has_method(&"transfer_gas"):
		return
	if not _pump_powered():
		_emit_stall_once()
		return
	_stalled = false
	var needed: float = _moles_needed_for(target_pressure_kpa)
	var interior_pressure: float = _pressure_of(interior_compartment_id)
	if needed <= 0.0 or interior_pressure <= INTERIOR_SUPPLY_FLOOR_KPA:
		_finish_pressurize()
		return
	atmosphere.call("transfer_gas", interior_compartment_id, compartment_id, minf(pump_moles_per_hour * hours, needed))
	if _pressure() >= target_pressure_kpa * TARGET_REACHED_FRACTION:
		_finish_pressurize()


func _finish_pressurize() -> void:
	_set_state(State.IDLE)
	emit_sim_event(&"airlock_pressurized", {"airlock_id": airlock_id, "pressure_kpa": _pressure()})


func _vent() -> float:
	var atmosphere: Node = _atmosphere_system()
	if atmosphere == null or not atmosphere.has_method(&"vent_gas"):
		return 0.0
	return float(atmosphere.call("vent_gas", compartment_id))


func _pump_powered() -> bool:
	var power: Node = _first_node_in_group(&"power_system")
	if power == null:
		return true
	if power.has_method(&"is_breaker_on") and not bool(power.call("is_breaker_on", circuit_id)):
		return false
	if power.has_method(&"is_circuit_shed") and bool(power.call("is_circuit_shed", circuit_id)):
		return false
	return true


func _emit_stall_once() -> void:
	if _stalled:
		return
	_stalled = true
	var reason: StringName = &"airlock_pump_stalled"
	emit_sim_event(&"procedure_error", {"reason": reason, "airlock_id": airlock_id})


func _emit_suit_depleted_once() -> void:
	if _suit_depleted_emitted:
		return
	_suit_depleted_emitted = true
	emit_sim_event(&"suit_o2_depleted", {"airlock_id": airlock_id})


func _set_state(new_state: int) -> void:
	if new_state == state:
		return
	state = new_state
	_emit_state_changed()


func _emit_state_changed() -> void:
	var state_name: StringName = get_state_name()
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"airlock_state_changed", airlock_id, state_name)
	emit_sim_event(&"airlock_state_changed", {"airlock_id": airlock_id, "state": state_name})


func _pressure() -> float:
	return _pressure_of(compartment_id)


func _pressure_of(id: StringName) -> float:
	var atmosphere: Node = _atmosphere_system()
	if atmosphere == null or not atmosphere.has_method(&"get_compartment_status"):
		return 0.0
	var status: Variant = atmosphere.call("get_compartment_status", id)
	if not (status is Dictionary):
		return 0.0
	return float((status as Dictionary).get("pressure_kpa", 0.0))


func _moles() -> float:
	var atmosphere: Node = _atmosphere_system()
	if atmosphere == null or not atmosphere.has_method(&"get_gas_moles"):
		return 0.0
	var moles: Variant = atmosphere.call("get_gas_moles", compartment_id)
	if not (moles is Dictionary):
		return 0.0
	var total: float = 0.0
	for key: String in ["o2", "co2", "n2"]:
		total += float((moles as Dictionary).get(key, 0.0))
	return total


func _moles_needed_for(pressure_kpa: float) -> float:
	var atmosphere: Node = _atmosphere_system()
	if atmosphere == null or not atmosphere.has_method(&"moles_for_pressure"):
		return 0.0
	return maxf(float(atmosphere.call("moles_for_pressure", compartment_id, pressure_kpa)) - _moles(), 0.0)


func _atmosphere_system() -> Node:
	return _first_node_in_group(&"atmosphere_system")


func _first_node_in_group(group_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		var main_loop: MainLoop = Engine.get_main_loop()
		if main_loop is SceneTree:
			tree = main_loop as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(group_name)
