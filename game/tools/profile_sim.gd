## Sim-cost profiler: runs the full system stack for a long fast-forward and reports microseconds per tick.
## Run: & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/profile_sim.gd
extends SceneTree

const PROFILE_HOURS: float = 240.0
const USEC_PER_TICK_BUDGET: float = 200.0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var harness := SimHarness.new(self)
	harness.setup_clock()

	var life_support: PowerCircuit = load("res://src/data/power/circuit_life_support.tres")
	var scrubber_circuit: PowerCircuit = load("res://src/data/power/circuit_scrubber.tres")
	var lighting: PowerCircuit = load("res://src/data/power/circuit_lighting.tres")
	var circuits: Array[PowerCircuit] = [life_support, scrubber_circuit, lighting]
	harness.add_power(circuits, 4000.0, {&"rtg_main": 500.0})

	var main_config: CompartmentConfig = load("res://src/data/atmosphere/compartment_main.tres")
	var storage_config: CompartmentConfig = load("res://src/data/atmosphere/compartment_storage.tres")
	var defs: Array[CompartmentConfig] = [main_config, storage_config]
	harness.add_atmosphere(defs)
	harness.add_thermal(defs)
	harness.add_stores({&"food_ration": 12})

	var hull := HullSystem.new()
	hull.compartment_defs = defs
	root.add_child(hull)
	var water := WaterSystem.new()
	root.add_child(water)
	water.set_reclaimer_powered(true)
	var vitals := VitalsSystem.new()
	root.add_child(vitals)
	var scrubber := ScrubberUnit.new()
	scrubber.compartment_id = &"main"
	root.add_child(scrubber)
	await process_frame

	var start_usec: int = Time.get_ticks_usec()
	harness.advance(PROFILE_HOURS)
	var elapsed_usec: int = Time.get_ticks_usec() - start_usec
	var ticks: int = int(roundf(PROFILE_HOURS * 600.0))
	var usec_per_tick: float = float(elapsed_usec) / float(ticks)

	print("PROFILE: %d ticks in %.0f ms (%.1f us/tick average)" % [ticks, float(elapsed_usec) / 1000.0, usec_per_tick])
	var within_budget: bool = usec_per_tick < USEC_PER_TICK_BUDGET
	if within_budget:
		print("PASS: profile_sim")
		quit(0)
	else:
		print("FAIL: profile_sim (%.1f us/tick exceeds %.0f us budget)" % [usec_per_tick, USEC_PER_TICK_BUDGET])
		quit(1)
