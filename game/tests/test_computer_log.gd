## Ship computer log suite: sim events become dated history, unread flags, save/load.
extends SceneTree

const LOG_PATH: String = "res://src/data/logs/log_01.tres"

var _failures: int = 0
var _event_bus: Node
var _sim_clock: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	for autoload_name: StringName in [&"EventBus", &"SimClock"]:
		var existing: Node = _find_root_child(autoload_name)
		if existing != null:
			root.remove_child(existing)
			existing.free()
	_event_bus = load("res://src/autoload/event_bus.gd").new()
	_event_bus.name = &"EventBus"
	root.add_child(_event_bus)
	_sim_clock = load("res://src/autoload/sim_clock.gd").new()
	_sim_clock.name = &"SimClock"
	root.add_child(_sim_clock)

	_test_capture()
	_test_maintenance_events()
	_test_read_marks()
	_test_day_rollover()
	_test_save_load()
	_test_archive()

	_finish()


func _test_capture() -> void:
	var computer := ComputerSystem.new()
	root.add_child(computer)
	_check(computer.is_in_group(&"computer_system"), "system registers in the computer group")
	_check(computer.get_status()["system_id"] == &"computer", "status names the system")

	_event_bus.call("emit_event", &"component_failed", {"component_id": &"rtg_main", "failure_mode_id": &"rtg_degraded"})
	_event_bus.call("emit_event", &"stores_low", {"part_id": &"filter_co2", "new_count": 1})
	_event_bus.call("emit_event", &"breaker_toggled", {"circuit_id": &"lighting", "on": false})
	_event_bus.call("emit_event", &"weather_report", {})

	var entries: Array[Dictionary] = computer.get_entries()
	_check(entries.size() == 3, "watched events become entries and unknown ones are ignored")
	_check(StringName(entries[0]["kind"]) == &"breaker_toggled", "newest entry is first")
	_check(String(entries[0]["text"]) == "BREAKER OFF: LIGHTING", "breaker entries name state and circuit")
	_check(String(entries[1]["text"]).begins_with("STORES LOW: FILTER_CO2"), "low stock entries name the part")
	_check(String(entries[2]["text"]) == "COMPONENT FAILED: RTG_MAIN — DIAGNOSIS REQUIRED", "automatic failure logs preserve fault uncertainty")
	_event_bus.call("emit_event", &"component_diagnosed", {"component_id": &"rtg_main", "failure_mode_id": &"rtg_degraded"})
	_check(String(computer.get_entries()[0]["text"]).contains("RTG_DEGRADED"), "operator diagnosis reveals exact mode")
	_check(int(entries[0]["day"]) == 1 and int(entries[0]["hour"]) == 0, "entries are stamped with the ship clock")
	computer.free()


func _test_read_marks() -> void:
	var computer := ComputerSystem.new()
	root.add_child(computer)
	_event_bus.call("emit_event", &"hull_puncture", {"compartment_id": &"storage", "severity": 0.4})
	_event_bus.call("emit_event", &"hull_patched", {"compartment_id": &"storage"})
	_check(computer.get_unread_count() == 2, "fresh entries are unread")

	var entries: Array[Dictionary] = computer.get_entries()
	var newest_id: int = int(entries[0]["id"])
	_check(computer.mark_read(newest_id), "an entry can be marked read")
	_check(not computer.mark_read(newest_id), "marking a read entry again reports no change")
	_check(computer.get_unread_count() == 1, "unread count follows the marks")

	computer.mark_all_read()
	_check(computer.get_unread_count() == 0, "mark_all_read clears the board")
	_check(computer.get_entry(newest_id)["text"] == "HULL PATCHED: STORAGE", "entry lookup returns the record")
	computer.free()


func _test_maintenance_events() -> void:
	var computer := ComputerSystem.new()
	root.add_child(computer)
	_event_bus.call("emit_event", &"filter_installed", {"compartment_id": &"main", "part_id": &"filter_co2"})
	_event_bus.call("emit_event", &"reclaimer_serviced", {"part_id": &"water_cartridge"})
	_event_bus.call("emit_event", &"water_cartridge_installed", {"contamination": 0.12})
	var entries: Array[Dictionary] = computer.get_entries()
	_check(entries.size() == 3, "completed maintenance events are retained in ship history")
	_check(String(entries[0]["text"]) == "WATER CARTRIDGE INSTALLED: CONTAMINATION 12%", "water cartridge history includes remaining contamination")
	_check(String(entries[1]["text"]) == "WATER RECLAIMER SERVICED: WATER_CARTRIDGE", "reclaimer history names the serviced part")
	_check(String(entries[2]["text"]) == "FILTER INSTALLED: FILTER_CO2 / MAIN", "scrubber history names filter and compartment")
	computer.free()


func _test_day_rollover() -> void:
	var computer := ComputerSystem.new()
	root.add_child(computer)
	_sim_clock.call("fast_forward", 24.0)
	var entries: Array[Dictionary] = computer.get_entries()
	_check(entries.size() == 1, "the day boundary writes one scheduler entry")
	_check(String(entries[0]["text"]) == "SHIP DAY 0002 BEGINS", "the scheduler entry names the new day")
	_check(int(entries[0]["day"]) == 2, "the entry carries the new day stamp")
	computer.free()


func _test_save_load() -> void:
	var computer := ComputerSystem.new()
	root.add_child(computer)
	_event_bus.call("emit_event", &"water_low", {"potable_l": 18.0, "potable_fraction": 0.12})
	computer.mark_all_read()
	_event_bus.call("emit_event", &"water_depleted", {"potable_l": 0.0})
	var saved: Dictionary = computer.save_state()
	computer.free()

	var restored := ComputerSystem.new()
	root.add_child(restored)
	restored.load_state(saved)
	var entries: Array[Dictionary] = restored.get_entries()
	_check(entries.size() == 2, "load restores the entry history")
	_check(String(entries[0]["text"]) == "WATER DEPLETED", "load keeps entry order and text")
	_check(restored.get_unread_count() == 1, "load keeps unread flags")
	_event_bus.call("emit_event", &"water_purged", {})
	entries = restored.get_entries()
	_check(entries.size() == 3, "new entries append after a load")
	_check(int(entries[0]["id"]) > int(entries[1]["id"]), "entry ids keep counting after a load")
	restored.free()


func _test_archive() -> void:
	var computer := ComputerSystem.new()
	var archived: Array[LogEntry] = [load(LOG_PATH) as LogEntry]
	computer.archive = archived
	root.add_child(computer)
	var volumes: Array[LogEntry] = computer.get_archive()
	_check(volumes.size() == 1 and volumes[0].id == &"log_01", "archive carries the authored volumes")
	computer.free()


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_computer_log")
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
