## Ship computer terminal suite: the OS shell, the log station and its archive/history pages.
extends SceneTree

const LOG_01: String = "res://src/data/logs/log_01.tres"
const LOG_02: String = "res://src/data/logs/log_02.tres"

var _failures: int = 0
var _event_bus: Node
var _sim_clock: Node
var _computer: ComputerSystem


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
	_computer = ComputerSystem.new()
	var archive: Array[LogEntry] = [load(LOG_01) as LogEntry, load(LOG_02) as LogEntry]
	_computer.archive = archive
	root.add_child(_computer)

	await _test_log_station()
	await _test_history_and_marks()
	await _test_warning_board()
	_test_watch_baseline()
	await _test_control_program()
	_test_menu_relative()

	_finish()


func _test_log_station() -> void:
	var terminal := LogTerminal.new()
	terminal.log_entry = load(LOG_01)
	root.add_child(terminal)
	await process_frame

	_check(terminal.get_interaction_prompt() == "Read log", "archive terminal invites a read")
	_check(not terminal.is_open(), "archive terminal starts closed")
	terminal.interact(null)
	_check(terminal.is_open(), "archive terminal opens on interact")

	var items: PackedStringArray = terminal.get_menu().get_items()
	_check(items.size() == 4, "menu holds the program row and three log actions (got %d)" % items.size())
	_check(items[0] == "SHIP LOG", "menu row names the log program")
	_check(items[1] == "1 ONBOARD HISTORY", "first action is the onboard history")
	_check(items[2].contains("MAINTENANCE LOG"), "archive volumes are listed")
	_check(terminal.get_actions() == [&"history", &"log_01", &"log_02"], "actions expose history then the volumes")
	_check("\n".join(terminal.build_readout()).contains("VOSS"), "station opens on its own archived volume")

	var content: Label = _find_label(terminal)
	_check(content != null and content.text == "\n".join(terminal.build_readout()), "screen shows the live readout")
	_check(content != null and content.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "screen wraps long computer lines")
	_check(content != null and content.get_parent() is ScrollContainer, "long readouts stay inside a scrollable screen")
	var overlay: ColorRect = _find_overlay(terminal)
	_check(overlay != null and overlay.material is ShaderMaterial, "screen carries the CRT overlay")

	terminal._unhandled_input(_press(&"pause"))
	_check(not terminal.is_open(), "archive terminal closes on Esc")
	terminal.free()


func _test_history_and_marks() -> void:
	_event_bus.call("emit_event", &"component_failed", {"component_id": &"scrubber_blower", "failure_mode_id": &"blower_seized"})
	_computer.mark_all_read()
	_event_bus.call("emit_event", &"stores_low", {"part_id": &"filter_co2", "new_count": 1})
	_check(_computer.get_unread_count() == 1, "a fresh entry is unread before the log is opened")

	var terminal := LogTerminal.new()
	terminal.log_entry = load(LOG_01)
	root.add_child(terminal)
	await process_frame
	terminal.interact(null)
	_check(terminal.select_action(&"history"), "history action switches the log page")
	var readout: String = "\n".join(terminal.build_readout())
	_check(readout.contains("ONBOARD HISTORY"), "history page names itself")
	_check(readout.contains("STORES LOW: FILTER_CO2"), "history page lists the newest entry")
	_check(readout.contains("COMPONENT FAILED: SCRUBBER_BLOWER"), "history page keeps older entries")
	_check(_computer.get_unread_count() == 0, "viewing the history marks the board read")
	terminal.free()


func _test_warning_board() -> void:
	var board := MaintenanceBoard.new()
	root.add_child(board)
	await process_frame
	_check(board.get_entries().size() == 2, "board rows come from the ship computer")
	_check(StringName(board.get_entries()[0]["kind"]) == &"stores_low", "board rows are newest first")
	_check(board.get_interaction_prompt() == "Read board", "board invites a read")
	board.interact(null)
	_check(board.build_readout()[0] == "HULLWATCH SHIP COMPUTER", "board readout carries the computer header")
	_check("\n".join(board.build_readout()).contains("STORES LOW"), "board readout lists the entries")
	_check("\n".join(board.build_readout()).contains("PROGRAM: WATCH REPORT"), "board defaults to the watch report")
	var harness: SimHarness = SimHarness.new(self)
	var config: CompartmentConfig = harness.make_compartment(&"enginebay")
	config.initial_o2_fraction = 0.12
	config.initial_co2_ppm = 20000.0
	config.initial_temperature_c = 0.0
	var atmosphere: AtmosphereSystem = harness.add_atmosphere([config])
	var thermal: ThermalSystem = harness.add_thermal([config])
	var vitals: VitalsSystem = VitalsSystem.new()
	root.add_child(vitals)
	var nav: NavSystem = NavSystem.new()
	nav.destinations = [load("res://src/data/destinations/destination_arden_ii.tres") as VoyageDestination]
	root.add_child(nav)
	var component: WearComponent = nav.wear_components[0]
	component.condition = 0.123
	component.failed_mode = &"watch_test_fault"
	_computer.record("COMPONENT FAILED: HIDDEN_TEST MODE SECRET_MODE", &"component_failed")
	var unread: int = _computer.get_unread_count()
	var report: String = "\n".join(board.build_readout())
	_check(report.contains("LOW O2") and report.contains("HIGH CO2") and report.contains("COLD:"), "watch reports real atmosphere and thermal hazards")
	_check(report.contains("INSPECTION NOT LOGGED: PORT STERN EVA SERVICE PANEL") and report.contains("STARBOARD STERN EVA SERVICE PANEL") and report.contains("TANK STERN EVA SERVICE PANEL"), "watch directs unscanned external hardware inspection")
	_check(not report.contains("PORT_GRID") and not report.contains("WATCH_TEST_FAULT") and not report.contains("12%"), "watch hides uninspected external component identity, fault and condition")
	_check(not report.contains("HIDDEN_TEST") and not report.contains("SECRET_MODE"), "watch does not repeat omniscient automatic fault history")
	_check(not report.to_lower().contains("xenonite"), "watch conceals restricted feed technology")
	_check(_computer.get_unread_count() == unread, "watch reading preserves unread history marks")
	var power: PowerSystem = PowerSystem.new()
	var rtg: WearComponent = load("res://src/data/wear/rtg_main.tres").duplicate(true) as WearComponent
	rtg.failed_mode = &"rtg_degraded"
	power.wear_components = [rtg]
	root.add_child(power)
	_check(not "\n".join(board.build_readout()).contains("DIAGNOSED RTG_MAIN"), "watch does not infer a hidden power fault")
	power.diagnose_component(&"rtg_main")
	report = "\n".join(board.build_readout())
	_check(report.contains("DIAGNOSED RTG_MAIN") and report.contains("ALL BUS BREAKERS OFF") and report.contains("GASKET / 0.25 H"), "watch uses authoritative circuit, parts and time for diagnosed refit guidance")
	_check(nav.service_action(&"port", &"isolate", &""), "watch fixture isolates port service target")
	_check(nav.service_action(&"port", &"open", &"wrench"), "watch fixture opens external housing")
	_check(nav.service_action(&"port", &"scan", &"scanner"), "watch fixture records external inspection")
	_check(nav.service_action(&"port", &"diagnose", &"multimeter"), "watch fixture diagnoses external fault")
	report = "\n".join(board.build_readout())
	_check(report.contains("DIAGNOSED PORT_GRID") and report.contains("WATCH_TEST_FAULT") and report.contains("WRENCH SERVICE"), "watch turns diagnosed fault into located service guidance")
	_check(not report.contains("INSPECTION NOT LOGGED: PORT STERN EVA SERVICE PANEL"), "watch clears inspection reminder after the operator scans the housing")
	_check(nav.service_action(&"starboard", &"isolate", &""), "watch fixture isolates the remaining cassette")
	nav.transit_active = true
	nav.plotted_destination_id = nav.destinations[0].destination_id
	nav.sim_tick(0.001)
	report = "\n".join(board.build_readout())
	_check(report.contains("DRIVE HOLD  CASSETTES OFFLINE / ISOLATED") and report.contains("ETA  HELD"), "watch shows actual navigation holds and suspended ETA")
	_check(board.select_action(&"log"), "board retains the full log program")
	_check("\n".join(board.build_readout()).contains("ONBOARD HISTORY"), "board can switch to full history")
	nav.free()
	power.free()
	vitals.free()
	thermal.free()
	atmosphere.free()
	board.free()

func _test_watch_baseline() -> void:
	var harness: SimHarness = SimHarness.new(self)
	var main: CompartmentConfig = harness.make_compartment(&"main")
	var corridor: CompartmentConfig = harness.make_compartment(&"corridor")
	main.leak_rate_per_hour = 0.0002
	corridor.leak_rate_per_hour = 0.0004
	var atmosphere: AtmosphereSystem = AtmosphereSystem.new()
	atmosphere.compartment_defs = [main, corridor]
	var blower: WearComponent = load("res://src/data/wear/scrubber_blower_main.tres").duplicate(true) as WearComponent
	atmosphere.wear_components = [blower]
	root.add_child(atmosphere)
	var thermal: ThermalSystem = harness.add_thermal([main, corridor])
	var hull: HullSystem = HullSystem.new()
	hull.compartment_defs = [main, corridor]
	root.add_child(hull)
	var unit: ScrubberUnit = ScrubberUnit.new()
	root.add_child(unit)
	var board: MaintenanceBoard = MaintenanceBoard.new()
	root.add_child(board)
	var report: String = "\n".join(board.build_readout())
	_check(not report.contains("LEAK ABOVE BASELINE") and not report.contains("SCRUBBER UNAVAILABLE"), "watch baseline leaks and corridor mixing do not create false alarms")
	_check(report.contains("ROOMS: 2 CHECKED / 0 NEED ATTENTION") and not report.contains("CORRIDOR:"), "watch summarizes normal rooms and shows only current-room readings")
	atmosphere.set_filter_installed(&"main", false)
	_check("\n".join(board.build_readout()).contains("FILTER MISSING"), "watch reports a missing filter at the actual scrubber")
	atmosphere.set_filter_installed(&"main", true)
	atmosphere.set_scrubber_efficiency(&"main", 0.0)
	_check("\n".join(board.build_readout()).contains("SCRUBBER UNAVAILABLE"), "watch reports measured zero scrubber output at the actual unit")
	blower.failed_mode = &"blower_seize"
	atmosphere.diagnose_component(blower.component_id)
	_check("\n".join(board.build_readout()).contains("DIAGNOSED SCRUBBER_BLOWER_MAIN"), "watch reports diagnosed blower failure as actionable service")
	hull.add_puncture(&"main", 1.0)
	_check("\n".join(board.build_readout()).contains("LEAK ABOVE BASELINE"), "watch reports a real puncture above normal hull leakage")
	board.free()
	unit.free()
	hull.free()
	thermal.free()
	atmosphere.free()


## The CONTROL program drives the live sims: breakers, isolation, airlock hatches and doors.
func _test_control_program() -> void:
	var harness := SimHarness.new(self)
	var circuits: Array[PowerCircuit] = [harness.make_circuit(&"lighting", 200.0, 2)]
	var power: PowerSystem = harness.add_power(circuits)
	var storage: CompartmentConfig = harness.make_compartment(&"storage", 40.0)
	var lock_config: CompartmentConfig = harness.make_compartment(&"airlock", 8.0)
	var defs: Array[CompartmentConfig] = [storage, lock_config]
	var atmosphere: AtmosphereSystem = harness.add_atmosphere(defs)
	var airlock := AirlockSystem.new()
	root.add_child(airlock)

	var door := Door.new()
	door.name = &"StorageDoor"
	door.compartment_a = &"storage"
	door.compartment_b = &"airlock"
	root.add_child(door)
	var hatch := Door.new()
	hatch.name = &"InnerHatch"
	hatch.compartment_a = &"airlock"
	hatch.compartment_b = &"storage"
	hatch.airlock_id = &"airlock_main"
	hatch.airlock_side = &"inner"
	root.add_child(hatch)

	var station := ComputerTerminal.new()
	station.programs = [&"control"]
	station.default_program = &"control"
	root.add_child(station)
	await process_frame

	station.interact(null)
	_check(station.get_current_program() == &"control", "control station opens its program")
	var actions: Array[StringName] = station.get_actions()
	_check(actions.size() > 4, "control page lists the page switches and context actions")
	_check(actions[0] == &"page:power" and actions[1] == &"page:atmosphere", "control pages come first and in order")
	_check(actions.has(&"breaker:lighting"), "power page lists the circuit breaker")
	_check(_action_label(station, &"breaker:lighting").contains("LIGHTING"), "breaker rows are labelled by circuit")

	_check(power.is_breaker_on(&"lighting"), "breaker starts on")
	_check(station.select_action(&"breaker:lighting"), "breaker row toggles the circuit")
	_check(not power.is_breaker_on(&"lighting"), "breaker is off after the toggle")

	_check(station.select_action(&"page:atmosphere"), "atmosphere page switches")
	_check(station.get_actions().has(&"isolate:storage"), "atmosphere page lists the compartment valve")
	var isolated_before: bool = bool(atmosphere.get_compartment_status(&"storage")["isolated"])
	_check(station.select_action(&"isolate:storage"), "valve row toggles isolation")
	_check(bool(atmosphere.get_compartment_status(&"storage")["isolated"]) != isolated_before, "isolation state flipped")

	_check(station.select_action(&"page:airlock"), "airlock page switches")
	var airlock_actions: Array[StringName] = station.get_actions()
	_check(airlock_actions.has(&"airlock:depressurize") and airlock_actions.has(&"hatch:inner"), "airlock page offers the cycle and the hatches")
	_check(not hatch.is_open(), "inner hatch starts shut")
	_check(station.select_action(&"hatch:inner"), "hatch row opens the inner hatch")
	_check(hatch.is_open(), "inner hatch is open after the toggle")
	_check(airlock.inner_open, "the airlock interlock knows the inner hatch is open")

	_check(station.select_action(&"page:doors"), "doors page switches")
	var door_actions: Array[StringName] = station.get_actions()
	_check(door_actions.has(&"door:StorageDoor"), "doors page lists the pressure door")
	_check(not door_actions.has(&"door:InnerHatch"), "doors page leaves the airlock hatches to the airlock page")
	_check(not door.is_open(), "pressure door starts closed")
	_check(station.select_action(&"door:StorageDoor"), "door row opens the pressure door")
	_check(door.is_open(), "pressure door is open after the toggle")

	_check("\n".join(station.build_readout()).contains("CONTROL"), "control readout names the program")
	station.close()

	station.free()
	door.free()
	hatch.free()
	airlock.free()
	power.free()
	atmosphere.free()


func _test_menu_relative() -> void:
	var terminal := LogTerminal.new()
	terminal.log_entry = load(LOG_01)
	root.add_child(terminal)
	terminal.interact(null)
	terminal.get_menu().set_highlighted_index(2)
	_check("\n".join(terminal.build_readout()).contains("VOSS"), "highlighting a volume previews it")
	terminal.get_menu().set_highlighted_index(1)
	_check("\n".join(terminal.build_readout()).contains("ONBOARD HISTORY"), "highlighting history previews the board")
	terminal.free()


func _action_label(station: ComputerTerminal, action: StringName) -> String:
	var items: PackedStringArray = station.get_menu().get_items()
	var index: int = station.get_actions().find(action)
	if index < 0:
		return ""
	var item_index: int = items.size() - station.get_actions().size() + index
	if item_index < 0 or item_index >= items.size():
		return ""
	return items[item_index]

func _press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _find_label(station: Node) -> Label:
	for child: Node in station.get_children():
		var found: Label = _find_child_label(child)
		if found != null:
			return found
	return null


func _find_child_label(node: Node) -> Label:
	if node is Label and node.name == &"ComputerReadout":
		return node
	for child: Node in node.get_children():
		var found: Label = _find_child_label(child)
		if found != null:
			return found
	return null


func _find_overlay(node: Node) -> ColorRect:
	for child: Node in node.get_children():
		if child is ColorRect and child.name == &"CrtOverlay":
			return child
		var found: ColorRect = _find_overlay(child)
		if found != null:
			return found
	return null


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_computer_terminal")
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
