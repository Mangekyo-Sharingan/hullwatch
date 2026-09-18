## Comms system scenario tests: day-scheduled arrivals, one-sided sends, reply latency, save/load.
extends SceneTree

const MESSAGE_PATHS: Array = [
	"res://src/data/comms/msg_control_ack.tres",
	"res://src/data/comms/msg_control_manifest.tres",
	"res://src/data/comms/msg_control_ping.tres",
	"res://src/data/comms/out_status_report.tres",
	"res://src/data/comms/out_rotation_query.tres",
	"res://src/data/comms/msg_reply_rotation.tres",
]

var _failures: int = 0
var _received_signals: Array[Dictionary] = []
var _sent_signals: Array[StringName] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	_test_without_clock()
	_test_data()
	_test_scripted_arrivals()
	_test_mark_read()
	_test_send_rules()
	_test_terminal_dismissal()
	_test_reply_chain()
	_test_save_load()
	_test_status()

	_finish()


func _test_without_clock() -> void:
	_remove_root_child(&"SimClock")
	_remove_root_child(&"EventBus")
	var system := CommsSystem.new()
	system.messages = _load_messages()
	root.add_child(system)
	system.sim_tick(1.0)
	_check(system.get_inbox().is_empty(), "null clock: no arrivals without SimClock")
	_check(system.get_unread_count() == 0, "null clock: unread stays zero")
	system.free()


func _test_data() -> void:
	var ack: CommsMessage = load("res://src/data/comms/msg_control_ack.tres")
	_check(ack != null, "data: wake acknowledgement loads")
	if ack != null:
		_check(ack.id == &"msg_control_ack", "data: ack id")
		_check(ack.direction == &"in" and ack.arrival_day == 1, "data: ack is inbound on day 1")
		_check(ack.sender == "MISSION CONTROL", "data: ack sender")
	var manifest: CommsMessage = load("res://src/data/comms/msg_control_manifest.tres")
	_check(manifest != null, "data: rotation manifest loads")
	if manifest != null:
		_check(manifest.direction == &"in" and manifest.arrival_day == 2, "data: manifest is inbound on day 2")
	var ping: CommsMessage = load("res://src/data/comms/msg_control_ping.tres")
	_check(ping != null, "data: relay ping loads")
	if ping != null:
		_check(ping.direction == &"in" and ping.arrival_day == 3, "data: ping is inbound on day 3")
	var status_report: CommsMessage = load("res://src/data/comms/out_status_report.tres")
	_check(status_report != null, "data: status report loads")
	if status_report != null:
		_check(status_report.direction == &"out", "data: status report is outbound")
		_check(status_report.reply_id == &"", "data: status report is never answered")
	var query: CommsMessage = load("res://src/data/comms/out_rotation_query.tres")
	_check(query != null, "data: rotation query loads")
	if query != null:
		_check(query.direction == &"out", "data: rotation query is outbound")
		_check(query.reply_id == &"msg_reply_rotation", "data: query chains to the rotation reply")
		_check(is_equal_approx(query.reply_delay_days, 8.0), "data: query delay is eight days")
	var reply: CommsMessage = load("res://src/data/comms/msg_reply_rotation.tres")
	_check(reply != null, "data: rotation reply loads")
	if reply != null:
		_check(reply.arrival_day == 0, "data: reply only arrives through the chain")
		_check(reply.date_text == "DAY 0011 04:40", "data: reply date text")


func _test_scripted_arrivals() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	_capture_signals()
	var system: CommsSystem = _spawn_system()
	_check(system.get_inbox().is_empty(), "arrivals: inbox empty before the first tick")
	_advance_steps(harness, 23.5)
	_check(system.get_inbox().size() == 1, "arrivals: only the wake ack has arrived during day 1")
	_advance_steps(harness, 0.5)
	_check(system.get_inbox().size() == 2, "arrivals: manifest arrives when day 2 begins")
	_advance_steps(harness, 24.0)
	_check(system.get_inbox().size() == 3, "arrivals: relay ping arrives when day 3 begins")
	_advance_steps(harness, 48.0)
	_check(system.get_inbox().size() == 3, "arrivals: no further scripted traffic over two more days")
	var inbox: Array[Dictionary] = system.get_inbox()
	_check(StringName(String(inbox[0]["id"])) == &"msg_control_ping", "arrivals: inbox lists newest first")
	_check(int(inbox[0]["day"]) == 3 and int(inbox[1]["day"]) == 2 and int(inbox[2]["day"]) == 1, "arrivals: arrival day recorded per message")
	_check(String(inbox[2]["date_text"]) == "DAY 0001 06:00", "arrivals: date text carried through")
	_check(system.get_unread_count() == 3, "arrivals: all three arrivals unread")
	_check(_count_events(harness, &"msg_control_ack") == 1, "arrivals: ack event fires once across four days")
	_check(_count_events(harness, &"msg_control_manifest") == 1, "arrivals: manifest event fires once across four days")
	_check(_count_events(harness, &"msg_control_ping") == 1, "arrivals: ping event fires once across four days")
	_check(_count_typed_received(&"msg_control_ack") == 1, "arrivals: typed ack signal fires once")
	_check(_count_typed_received(&"msg_control_ping") == 1, "arrivals: typed ping signal fires once")
	_check(_typed_received_count() == 3, "arrivals: exactly three typed message_received signals")
	system.free()


func _test_mark_read() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	_capture_signals()
	var system: CommsSystem = _spawn_system()
	_advance_steps(harness, 60.0)
	_check(system.get_unread_count() == 3, "read: three unread after arrival")
	_check(system.mark_read(&"msg_control_ack"), "read: mark_read returns true for an unread arrival")
	_check(system.get_unread_count() == 2, "read: unread count drops")
	_check(not system.mark_read(&"msg_control_ack"), "read: second mark_read returns false")
	_check(not system.mark_read(&"msg_reply_rotation"), "read: not-yet-arrived message returns false")
	_check(not system.mark_read(&"nope"), "read: unknown message returns false")
	var read_flags: Dictionary = {}
	for entry: Dictionary in system.get_inbox():
		read_flags[StringName(String(entry["id"]))] = bool(entry["unread"])
	_check(not bool(read_flags[&"msg_control_ack"]), "read: ack flagged read in the inbox")
	_check(bool(read_flags[&"msg_control_ping"]), "read: untouched traffic stays unread")
	system.free()


func _test_send_rules() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	_capture_signals()
	var system: CommsSystem = _spawn_system()
	_advance_steps(harness, 60.0)
	var outbound: Array[Dictionary] = system.get_outbound()
	_check(outbound.size() == 2, "send: two outbound drafts")
	_check(StringName(String(outbound[0]["id"])) == &"out_status_report", "send: outbound keeps resource order (status first)")
	_check(StringName(String(outbound[1]["id"])) == &"out_rotation_query", "send: outbound keeps resource order (query second)")
	_check(String(outbound[0]["sender"]) == "OPERATOR", "send: outbound sender is the operator")
	_check(not system.send_message(&"msg_control_ack"), "send: scripted inbound id is not sendable")
	_check(not system.send_message(&"msg_control_manifest"), "send: second scripted inbound id is not sendable")
	_check(system.send_message(&"out_status_report"), "send: status report sends")
	_check(not system.send_message(&"out_status_report"), "send: a sent message cannot send twice")
	_check(_sent_signals.size() == 1 and _sent_signals[0] == &"out_status_report", "send: message_sent typed signal fires")
	var sent_events: Array[Dictionary] = harness.events_named(&"message_sent")
	_check(sent_events.size() == 1, "send: message_sent sim event fires once")
	if not sent_events.is_empty():
		var payload: Dictionary = sent_events[0]["payload"]
		_check(StringName(payload.get("message_id", &"")) == &"out_status_report", "send: sim event carries the message id")
	_check(system.get_status()["outbound"] == 1, "send: status counts the sent message")
	system.free()


func _test_terminal_dismissal() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var system: CommsSystem = _spawn_system()
	var terminal := CommsTerminal.new()
	root.add_child(terminal)
	terminal.interact(null)
	_check(terminal.is_open(), "terminal: opens on interact")
	terminal._unhandled_input(_press(&"pause"))
	_check(not terminal.is_open(), "terminal: closes on Esc from anywhere")
	terminal.interact(null)
	terminal._unhandled_input(_press(&"interact"))
	_check(not terminal.is_open(), "terminal: closes on E from anywhere")
	terminal.free()
	system.free()


func _press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _test_reply_chain() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	_capture_signals()
	var system: CommsSystem = _spawn_system()
	_advance_steps(harness, 60.0)
	_check(_count_events(harness, &"msg_reply_rotation") == 0, "reply: rotation reply is absent before the chain")
	_check(system.send_message(&"out_rotation_query"), "reply: rotation query sends")
	_check(not system.send_message(&"out_rotation_query"), "reply: query cannot send twice")
	_check(not system.send_message(&"msg_reply_rotation"), "reply: scripted reply is not itself sendable")
	harness.clear_events()
	_received_signals.clear()
	_advance_steps(harness, 191.5)
	_check(_count_events(harness, &"msg_reply_rotation") == 1, "reply: rotation reply arrives after eight days")
	_check(_count_typed_received(&"msg_reply_rotation") == 1, "reply: typed signal fires for the reply")
	_advance_steps(harness, 24.0)
	_check(_count_events(harness, &"msg_reply_rotation") == 1, "reply: rotation reply arrives exactly once")
	var reply_day: int = 0
	for entry: Dictionary in system.get_inbox():
		if StringName(String(entry["id"])) == &"msg_reply_rotation":
			reply_day = int(entry["day"])
	_check(reply_day == 11, "reply: reply is stamped with its arrival day")
	_check(system.get_unread_count() == 4, "reply: reply lands unread")
	system.free()


func _test_save_load() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	_capture_signals()
	var system_a: CommsSystem = _spawn_system()
	_advance_steps(harness, 60.0)
	_check(system_a.mark_read(&"msg_control_ack"), "save: ack read before saving")
	_check(system_a.send_message(&"out_rotation_query"), "save: query sent before saving")
	var saved: Dictionary = system_a.save_state()
	var json_text: String = JSON.stringify(saved)
	var parsed: Variant = JSON.parse_string(json_text)
	_check(parsed is Dictionary, "save: JSON round trip parses to Dictionary")
	var parsed_dict: Dictionary = {}
	if parsed is Dictionary:
		parsed_dict = parsed
	_check(parsed_dict.has("arrived") and parsed_dict.has("pending"), "save: JSON carries arrived and pending")
	var pending: Variant = parsed_dict.get("pending", [])
	_check(pending is Array and (pending as Array).size() == 1, "save: pending reply captured in JSON")
	if pending is Array and (pending as Array).size() == 1:
		_check(String((pending as Array)[0].get("id", "")) == "msg_reply_rotation", "save: pending entry names the reply")
	system_a.free()

	var system_b: CommsSystem = _spawn_system()
	system_b.load_state(parsed_dict)
	_check(system_b.get_inbox().size() == 3, "load: three arrivals restored")
	_check(system_b.get_unread_count() == 2, "load: unread restored")
	_check(not system_b.mark_read(&"msg_control_ack"), "load: read state restored")
	_check(not system_b.send_message(&"out_rotation_query"), "load: sent state restored")
	_check(int(system_b.get_status()["outbound"]) == 1, "load: sent count restored")
	harness.clear_events()
	_received_signals.clear()
	_advance_steps(harness, 192.0)
	_check(_count_events(harness, &"msg_reply_rotation") == 1, "load: pending reply still arrives exactly once")
	_check(_count_events(harness, &"msg_control_ack") == 0, "load: scripted ack is not re-arrived")
	_check(_count_events(harness, &"msg_control_manifest") == 0, "load: scripted manifest is not re-arrived")
	_check(_count_events(harness, &"msg_control_ping") == 0, "load: scripted ping is not re-arrived")
	_check(system_b.get_inbox().size() == 4, "load: inbox holds the three originals plus the reply")
	system_b.free()


func _test_status() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	_capture_signals()
	var system: CommsSystem = _spawn_system()
	var initial: Dictionary = system.get_status()
	_check(initial["system_id"] == &"comms", "status: system_id is comms")
	_check(int(initial["unread"]) == 0 and int(initial["arrived"]) == 0 and int(initial["outbound"]) == 0, "status: starts empty")
	_advance_steps(harness, 60.0)
	var arrived_status: Dictionary = system.get_status()
	_check(int(arrived_status["arrived"]) == 3 and int(arrived_status["unread"]) == 3, "status: arrivals counted")
	_check(system.send_message(&"out_status_report") and system.send_message(&"out_rotation_query"), "status: both drafts send")
	_check(int(system.get_status()["outbound"]) == 2, "status: outbound counts sent messages")
	_check(system.mark_read(&"msg_control_ping"), "status: ping marked read")
	_check(int(system.get_status()["unread"]) == 2, "status: unread count follows mark_read")
	system.free()


func _load_messages() -> Array[CommsMessage]:
	var messages: Array[CommsMessage] = []
	for path: String in MESSAGE_PATHS:
		var message: CommsMessage = load(path)
		if message != null:
			messages.append(message)
	return messages


func _spawn_system() -> CommsSystem:
	var system := CommsSystem.new()
	system.messages = _load_messages()
	root.add_child(system)
	return system


func _capture_signals() -> void:
	_received_signals.clear()
	_sent_signals.clear()
	var event_bus: Node = _find_root_child(&"EventBus")
	if event_bus == null:
		_check(false, "signals: EventBus present for capture")
		return
	event_bus.connect(&"message_received", _on_message_received)
	event_bus.connect(&"message_sent", _on_message_sent)


func _on_message_received(message_id: StringName, sender: String) -> void:
	_received_signals.append({"id": message_id, "sender": sender})


func _on_message_sent(message_id: StringName) -> void:
	_sent_signals.append(message_id)


func _count_events(harness: SimHarness, message_id: StringName) -> int:
	var count: int = 0
	for event: Dictionary in harness.events_named(&"message_received"):
		var payload: Dictionary = event["payload"]
		if StringName(payload.get("message_id", &"")) == message_id:
			count += 1
	return count


func _count_typed_received(message_id: StringName) -> int:
	var count: int = 0
	for entry: Dictionary in _received_signals:
		if StringName(entry.get("id", &"")) == message_id:
			count += 1
	return count


func _typed_received_count() -> int:
	return _received_signals.size()


func _advance_steps(harness: SimHarness, hours: float, step_hours: float = 0.5) -> void:
	var remaining: float = hours
	while remaining > 0.0:
		var chunk: float = minf(step_hours, remaining)
		harness.advance(chunk)
		remaining -= chunk


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _remove_root_child(node_name: StringName) -> void:
	for child: Node in root.get_children():
		if child.name == node_name:
			root.remove_child(child)
			child.free()
			return


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_comms")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
