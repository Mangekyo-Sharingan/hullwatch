## One-sided comms: scripted inbound traffic on a day schedule and delayed replies to player traffic.
## Latency is the point — a reply may never come, and when it does it is not what the operator hoped for.
class_name CommsSystem
extends ShipSystem

@export var messages: Array[CommsMessage] = []

var _arrived: Array[StringName] = []
var _unread: Array[StringName] = []
var _sent: Array[StringName] = []
var _pending: Array[Dictionary] = []
var _arrived_days: Dictionary = {}


func _ready() -> void:
	system_id = &"comms"
	add_to_group(&"comms_system")
	super._ready()


func sim_tick(_delta_hours: float) -> void:
	var day: int = _current_day()
	if day <= 0:
		return
	for message: CommsMessage in messages:
		if message == null or message.id == &"":
			continue
		if message.direction == &"in" and message.arrival_day > 0 and day >= message.arrival_day:
			_arrive(message, day)
	if _pending.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for entry: Dictionary in _pending:
		if day < int(entry.get("day", 0)):
			remaining.append(entry)
			continue
		var reply: CommsMessage = _find_message(StringName(String(entry.get("id", &""))))
		if reply == null:
			push_error("CommsSystem.sim_tick: pending reply '%s' is not a known message." % String(entry.get("id", &"")))
			continue
		_arrive(reply, day)
	_pending = remaining


## Arrived messages only, newest first, with the sim day each one landed on.
func get_inbox() -> Array[Dictionary]:
	var inbox: Array[Dictionary] = []
	var index: int = _arrived.size() - 1
	while index >= 0:
		var message_id: StringName = _arrived[index]
		index -= 1
		var message: CommsMessage = _find_message(message_id)
		if message == null:
			continue
		inbox.append({
			"id": message_id,
			"sender": message.sender,
			"date_text": message.date_text,
			"body": message.body,
			"day": int(_arrived_days.get(String(message_id), 0)),
			"unread": _unread.has(message_id),
		})
	return inbox


## Player-sendable traffic in resource order.
func get_outbound() -> Array[Dictionary]:
	var outbound: Array[Dictionary] = []
	for message: CommsMessage in messages:
		if message == null or message.id == &"" or message.direction != &"out":
			continue
		outbound.append({"id": message.id, "sender": message.sender, "body": message.body})
	return outbound


func get_unread_count() -> int:
	return _unread.size()


func mark_read(message_id: StringName) -> bool:
	if not _arrived.has(message_id) or not _unread.has(message_id):
		return false
	_unread.erase(message_id)
	return true


func send_message(message_id: StringName) -> bool:
	var message: CommsMessage = _find_message(message_id)
	if message == null:
		push_error("CommsSystem.send_message: unknown message_id '%s'." % String(message_id))
		return false
	if message.direction != &"out" or _sent.has(message_id):
		return false
	_sent.append(message_id)
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"message_sent", message_id)
	emit_sim_event(&"message_sent", {"message_id": message_id})
	if message.reply_id != &"":
		_pending.append({"id": message.reply_id, "day": _current_day() + int(roundf(message.reply_delay_days))})
	return true


func get_status() -> Dictionary:
	return {
		"system_id": system_id,
		"unread": _unread.size(),
		"arrived": _arrived.size(),
		"outbound": _sent.size(),
	}


func save_state() -> Dictionary:
	var pending: Array = []
	for entry: Dictionary in _pending:
		pending.append({"id": String(entry.get("id", &"")), "day": int(entry.get("day", 0))})
	var arrived_days: Dictionary = {}
	for key: Variant in _arrived_days:
		arrived_days[String(key)] = int(_arrived_days[key])
	return {
		"system_id": "comms",
		"state_version": 1,
		"arrived": _string_ids(_arrived),
		"unread": _string_ids(_unread),
		"sent": _string_ids(_sent),
		"pending": pending,
		"arrived_days": arrived_days,
	}


func load_state(state: Dictionary) -> void:
	_arrived = _name_ids(state.get("arrived", []))
	_unread = _name_ids(state.get("unread", []))
	_sent = _name_ids(state.get("sent", []))
	_pending.clear()
	var pending: Variant = state.get("pending", [])
	if pending is Array:
		for entry: Variant in (pending as Array):
			if not (entry is Dictionary):
				continue
			var data: Dictionary = entry
			var pending_id: StringName = StringName(String(data.get("id", "")))
			if pending_id == &"":
				continue
			_pending.append({"id": pending_id, "day": int(data.get("day", 0))})
	_arrived_days.clear()
	var days: Variant = state.get("arrived_days", {})
	if days is Dictionary:
		for key: Variant in (days as Dictionary):
			_arrived_days[String(key)] = int((days as Dictionary)[key])


func _arrive(message: CommsMessage, day: int) -> void:
	if _arrived.has(message.id):
		return
	_arrived.append(message.id)
	_unread.append(message.id)
	_arrived_days[String(message.id)] = day
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"message_received", message.id, message.sender)
	emit_sim_event(&"message_received", {"message_id": message.id, "sender": message.sender})


func _find_message(message_id: StringName) -> CommsMessage:
	for message: CommsMessage in messages:
		if message != null and message.id == message_id:
			return message
	return null


func _current_day() -> int:
	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock == null or not sim_clock.has_method(&"get_day"):
		return 0
	return int(sim_clock.call("get_day"))


func _string_ids(ids: Array[StringName]) -> Array:
	var values: Array = []
	for id: StringName in ids:
		values.append(String(id))
	return values


func _name_ids(source: Variant) -> Array[StringName]:
	var ids: Array[StringName] = []
	if not (source is Array):
		return ids
	for value: Variant in (source as Array):
		var id: StringName = StringName(String(value))
		if id != &"":
			ids.append(id)
	return ids
