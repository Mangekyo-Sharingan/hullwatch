## CO2 scrubber unit with a stepwise filter-swap procedure:
## power off -> open housing -> remove filter -> install from stores -> seat seal -> close -> power on.
class_name ScrubberUnit
extends Interactable

enum Stage { CLOSED, FILTER_IN, FILTER_OUT, SEAT, READY }

@export var compartment_id: StringName = &"main"
@export var part_id: StringName = &"filter_co2"
@export var circuit_id: StringName = &"scrubber"

var _stage: Stage = Stage.CLOSED
var _powered: bool = true
var _seal_seated: bool = true
var _ready_to_power: bool = false


func _ready() -> void:
	var atmosphere: Node = _get_system(&"atmosphere_system")
	if atmosphere != null:
		atmosphere.call("set_filter_installed", compartment_id, true)
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.connect(&"sim_event", _on_sim_event)
	_push_power()


func is_powered() -> bool:
	return _powered


func is_housing_open() -> bool:
	return _stage != Stage.CLOSED


func has_filter() -> bool:
	return _stage != Stage.FILTER_OUT


func is_seal_seated() -> bool:
	return _seal_seated


func get_interaction_prompt() -> String:
	match _stage:
		Stage.FILTER_IN:
			return "Remove filter"
		Stage.FILTER_OUT:
			return "Install filter"
		Stage.SEAT:
			return "Seat seal"
		Stage.READY:
			return "Close housing"
	if _powered:
		return "Power down"
	if _ready_to_power:
		return "Power up"
	return "Open housing"


func _handle_interact(_player: Node) -> void:
	match _stage:
		Stage.FILTER_IN:
			_remove_filter()
		Stage.FILTER_OUT:
			_install_filter()
		Stage.SEAT:
			_seat_seal()
		Stage.READY:
			_close_housing()
		_:
			if _powered:
				_set_powered(false)
			elif _ready_to_power:
				_power_up()
			else:
				_open_housing()


func is_circuit_available() -> bool:
	var power: Node = _get_system(&"power_system")
	if power == null:
		return true
	return bool(power.call("is_breaker_on", circuit_id)) and not bool(power.call("is_circuit_shed", circuit_id))


func _set_powered(powered: bool) -> void:
	_powered = powered
	_push_power()
	_emit_sim_event(&"scrubber_power_changed", {
		"compartment_id": compartment_id,
		"powered": powered,
		"effective": powered and is_circuit_available(),
	})


func _push_power() -> void:
	var atmosphere: Node = _get_system(&"atmosphere_system")
	if atmosphere != null:
		atmosphere.call("set_scrubber_powered", compartment_id, _powered and is_circuit_available())


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	match event_name:
		&"circuit_shed", &"circuit_restored", &"breaker_toggled":
			if StringName(payload.get("circuit_id", &"")) == circuit_id:
				_push_power()


func _open_housing() -> void:
	_stage = Stage.FILTER_IN
	_ready_to_power = false
	_emit_sim_event(&"scrubber_housing_opened", {"compartment_id": compartment_id})


func _close_housing() -> void:
	_stage = Stage.CLOSED
	_ready_to_power = true
	_emit_sim_event(&"scrubber_housing_closed", {"compartment_id": compartment_id})


func _remove_filter() -> void:
	_stage = Stage.FILTER_OUT
	_seal_seated = false
	var atmosphere: Node = _get_system(&"atmosphere_system")
	if atmosphere != null:
		atmosphere.call("set_filter_installed", compartment_id, false)
	_emit_sim_event(&"filter_removed", {"compartment_id": compartment_id})


func _install_filter() -> void:
	var stores: Node = _get_system(&"stores_system")
	if stores == null or not bool(stores.call("consume_part", part_id, 1)):
		_emit_sim_event(&"procedure_error", {"reason": &"no_filter_stock", "part_id": part_id})
		return
	_stage = Stage.SEAT
	var atmosphere: Node = _get_system(&"atmosphere_system")
	if atmosphere != null:
		atmosphere.call("set_filter_condition", compartment_id, 1.0)
		atmosphere.call("set_filter_installed", compartment_id, true)
	_emit_sim_event(&"filter_installed", {"compartment_id": compartment_id, "part_id": part_id})


func _seat_seal() -> void:
	_stage = Stage.READY
	_seal_seated = true
	_emit_sim_event(&"seal_seated", {"compartment_id": compartment_id})


func _power_up() -> void:
	_set_powered(true)
	_ready_to_power = false


func save_state() -> Dictionary:
	var state: Dictionary = super.save_state()
	state["system_id"] = "scrubber_unit"
	state["state_version"] = 1
	state["stage"] = int(_stage)
	state["powered"] = _powered
	state["seal_seated"] = _seal_seated
	state["ready_to_power"] = _ready_to_power
	return state


func load_state(state: Dictionary) -> void:
	super.load_state(state)
	_stage = int(state.get("stage", int(_stage)))
	_powered = bool(state.get("powered", _powered))
	_seal_seated = bool(state.get("seal_seated", _seal_seated))
	_ready_to_power = bool(state.get("ready_to_power", _ready_to_power))
	_push_power()
	var atmosphere: Node = _get_system(&"atmosphere_system")
	if atmosphere != null:
		atmosphere.call("set_filter_installed", compartment_id, _stage != Stage.FILTER_OUT)
