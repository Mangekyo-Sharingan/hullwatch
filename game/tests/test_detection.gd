## Detection tests: nearest-contact API, scanner ping from the player, HUD toast text and
## the status panel contact list.
extends SceneTree

var _failures: int = 0
var _pings: Array[Dictionary] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var event_bus: Node = root.get_node_or_null(^"EventBus")
	if event_bus == null:
		event_bus = load("res://src/autoload/event_bus.gd").new()
		event_bus.name = &"EventBus"
		root.add_child(event_bus)
	event_bus.connect(&"sim_event", _on_sim_event)

	var sector: SectorSystem = SectorSystem.new()
	sector.field_seed = 20260918
	sector.drift_axis = Vector3.FORWARD
	sector.drift_speed_m_per_hour = 1500.0
	root.add_child(sector)
	for i: int in 48:
		sector.sim_tick(1.0)
		if not sector.get_contacts().is_empty():
			break
	var contacts: Array[Dictionary] = sector.get_contacts()
	_check(not contacts.is_empty(), "contacts exist for detection")
	if not contacts.is_empty():
		var nearest: Dictionary = sector.get_nearest_contact()
		_check(String(nearest.get("id", "")) == String(contacts[0]["id"]), "nearest contact matches the sorted list")

	var player: CharacterBody3D = (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	var scanner: Carriable = Carriable.new()
	scanner.item_id = &"scanner"
	scanner.item_name = "Wear scanner"
	root.add_child(scanner)
	_check(bool(player.call("take_carriable", scanner)), "scanner equips")
	_pings.clear()
	var action: InputEventAction = InputEventAction.new()
	action.action = &"primary"
	action.pressed = true
	player._unhandled_input(action)
	await process_frame
	_check(_pings.size() == 1, "ping emits one scanner_ping event")
	if _pings.size() == 1:
		_check(float(_pings[0].get("distance_m", -1.0)) > 0.0, "ping carries a live distance")

	var hud: CanvasLayer = load("res://src/ui/hud.gd").new() as CanvasLayer
	root.add_child(hud)
	await process_frame
	hud.call("set_message_hold", 30.0)
	event_bus.call("emit_event", &"scanner_ping", {"kind": "asteroid", "distance_m": 417.0})
	_check(String(hud.call("get_message_text")).contains("417"), "HUD toast shows the ping distance")
	event_bus.call("emit_event", &"scanner_ping", {"kind": "", "distance_m": -1.0})
	_check(String(hud.call("get_message_text")).contains("NO CONTACTS"), "HUD toast reports an empty ping")

	var panel_script: Script = load("res://src/ui/status_panel.gd") as Script
	_check(panel_script != null, "status panel script loads")
	if panel_script == null:
		_cleanup(player, hud, null, sector, event_bus)
		return
	var panel: Node = panel_script.new()
	root.add_child(panel)
	await process_frame
	var readout: String = "\n".join(panel.call("build_readout"))
	_check(readout.contains("CONTACTS"), "status panel lists contacts")

	_cleanup(player, hud, panel, sector, event_bus)


func _cleanup(player: Node, hud: Node, panel: Node, sector: Node, event_bus: Node) -> void:
	player.free()
	hud.free()
	if panel != null:
		panel.free()
	sector.free()
	event_bus.disconnect(&"sim_event", _on_sim_event)
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_detection")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"scanner_ping":
		_pings.append(payload)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
