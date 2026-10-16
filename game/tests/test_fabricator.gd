## Fabricator tests: power and material gating, one job at a time, output into stores,
## and mid-job save/load.
extends SceneTree

const FABRICATOR_MODEL_PATH: String = "res://assets/models/hullwatch/machinery/hw_fabricator.glb"

var _failures: int = 0
var _completed: Array[Dictionary] = []
var _errors: Array[Dictionary] = []


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

	var cargo: CargoSystem = CargoSystem.new()
	root.add_child(cargo)
	var stores: Stores = Stores.new()
	root.add_child(stores)
	var power: PowerSystem = PowerSystem.new()
	var circuits: Array[PowerCircuit] = []
	var circuit: PowerCircuit = PowerCircuit.new()
	circuit.circuit_id = &"fabricator"
	circuit.nominal_load_w = 80.0
	circuits.append(circuit)
	power.circuit_defs = circuits
	root.add_child(power)
	var fabricator: FabricatorSystem = FabricatorSystem.new()
	fabricator.recipes = _recipes()
	root.add_child(fabricator)
	await process_frame
	var unit := FabricatorUnit.new()
	var model_scene: PackedScene = load(FABRICATOR_MODEL_PATH) as PackedScene
	_check(model_scene != null, "fabricator glTF model loads")
	if model_scene != null:
		unit.add_child(model_scene.instantiate())
	root.add_child(unit)
	await process_frame
	var animator: AnimationPlayer = _animation_player(unit)
	_check(animator != null and animator.has_animation(&"fabricate"), "fabricator glTF exposes the runtime fabricate clip")

	var water_filter: Resource = fabricator.get_recipe(&"water_filter")
	_check(water_filter != null, "water filter recipe is loaded")

	var refusal: StringName = StringName(String(fabricator.call("start", &"water_filter")))
	_check(refusal == &"no_materials", "starting without materials refuses")
	power.set_breaker(&"fabricator", false)
	cargo.add_material(&"ice", 10.0)
	refusal = StringName(String(fabricator.call("start", &"water_filter")))
	_check(refusal == &"no_power", "starting on a dead circuit refuses")
	power.set_breaker(&"fabricator", true)

	refusal = StringName(String(fabricator.call("start", &"water_filter")))
	_check(refusal == &"", "with power and ice the job starts")
	_check(is_equal_approx(cargo.get_units(&"ice"), 6.0), "materials are consumed up front")
	_check(bool(fabricator.call("is_busy")), "the fabricator reports busy")
	_check_animation(animator, &"fabricate", "powered fabrication runs its authored loop")
	refusal = StringName(String(fabricator.call("start", &"gasket")))
	_check(refusal == &"fabricator_busy", "a second job refuses while running")
	power.set_breaker(&"fabricator", false)
	_check(animator != null and not animator.is_playing(), "the fabrication animation stops when its circuit loses power")
	power.set_breaker(&"fabricator", true)
	_check_animation(animator, &"fabricate", "the fabrication animation resumes when power returns")
	fabricator.sim_tick(1.0)
	_check(int(stores.get_count(&"water_filter")) == 0, "output waits for the full duration")
	fabricator.sim_tick(1.0)
	_check(int(stores.get_count(&"water_filter")) == 1, "the finished part lands in stores")
	_check(_completed.size() == 1, "fabrication_completed fires once")
	_check(not bool(fabricator.call("is_busy")), "the fabricator is idle again")
	_check(animator != null and not animator.is_playing(), "the fabrication animation stops when the job completes")

	cargo.add_material(&"metal", 3.0)
	var gasket_start: StringName = StringName(String(fabricator.call("start", &"gasket")))
	_check(gasket_start == &"", "the gasket job starts with stowed metal")
	var saved: Dictionary = fabricator.save_state()
	var restored: FabricatorSystem = FabricatorSystem.new()
	restored.recipes = _recipes()
	root.add_child(restored)
	restored.load_state(saved)
	_check(bool(restored.call("is_busy")), "save/load keeps a running job")
	restored.sim_tick(2.0)
	_check(int(stores.get_count(&"gasket")) == 2, "the restored job finishes into stores")


	var fixed_recipe: FabricatorRecipe = FabricatorRecipe.new()
	fixed_recipe.recipe_id = &"paid_fixture"
	fixed_recipe.material_kind = &"ice"
	fixed_recipe.material_units = 2.0
	fixed_recipe.output_part_id = &"water_filter"
	fixed_recipe.output_count = 3
	fixed_recipe.hours = 2.0
	var paid: FabricatorSystem = FabricatorSystem.new()
	paid.recipes = [fixed_recipe]
	root.add_child(paid)
	var ice_before: float = cargo.get_units(&"ice")
	_check(paid.start(&"paid_fixture") == &"", "paid fixture starts")
	paid.sim_tick(0.5)
	var checkpoint: Dictionary = JSON.parse_string(JSON.stringify(paid.save_state())) as Dictionary
	_check(int(checkpoint["state_version"]) == 2 and checkpoint["job_terms"]["material_units"] == 2.0, "JSON preserves paid recipe terms")
	fixed_recipe.output_count = 50
	fixed_recipe.output_part_id = &"gasket"
	fixed_recipe.hours = 0.01
	paid.recipes.clear()
	paid.load_state(checkpoint)
	paid.load_state(checkpoint)
	_check(is_equal_approx(cargo.get_units(&"ice"), ice_before - 2.0), "repeated job restore never repays materials")
	root.remove_child(stores)
	var events_before: int = _completed.size()
	paid.sim_tick(5.0)
	_check(paid.is_busy() and paid.get_job_remaining_hours() == 0.0 and _completed.size() == events_before, "missing receiver retains zero-hour output without completion event")
	checkpoint = JSON.parse_string(JSON.stringify(paid.save_state())) as Dictionary
	paid.load_state(checkpoint)
	paid.sim_tick(1.0)
	_check(paid.is_busy(), "pending paid output survives load without catalog or receiver")
	root.add_child(stores)
	var filters_before: int = stores.get_count(&"water_filter")
	paid.sim_tick(0.1)
	paid.sim_tick(0.1)
	_check(stores.get_count(&"water_filter") == filters_before + 3 and stores.get_count(&"gasket") == 2, "changed and deleted recipe cannot change paid output")
	_check(not paid.is_busy() and _completed.size() == events_before + 1, "pending output delivers exactly once")
	paid.load_state({"state_version": 1, "job_recipe_id": "gasket", "job_remaining_hours": 0.5})
	_check(not paid.is_busy(), "missing legacy recipe is not invented by simulator (SaveManager rejects it)")
	paid.recipes = _recipes()
	paid.load_state({"state_version": 1, "job_recipe_id": "gasket", "job_remaining_hours": 0.5})
	_check(paid.is_busy() and paid.save_state()["job_terms"]["output_count"] == 2, "legacy paid job snapshots catalog terms once")
	paid.free()

	unit.free()
	cargo.free()
	stores.free()
	power.free()
	fabricator.free()
	restored.free()
	event_bus.disconnect(&"sim_event", _on_sim_event)
	_finish()


func _recipes() -> Array[FabricatorRecipe]:
	var recipes: Array[FabricatorRecipe] = []
	for path: String in [
		"res://src/data/fabrication/recipe_water_filter.tres",
		"res://src/data/fabrication/recipe_o2_candle.tres",
		"res://src/data/fabrication/recipe_co2_filter.tres",
		"res://src/data/fabrication/recipe_gasket.tres",
	]:
		var recipe: FabricatorRecipe = load(path) as FabricatorRecipe
		if recipe != null:
			recipes.append(recipe)
	return recipes


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"fabrication_completed":
		_completed.append(payload)
	elif event_name == &"procedure_error":
		_errors.append(payload)


func _animation_player(node: Node) -> AnimationPlayer:
	return node.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _check_animation(animator: AnimationPlayer, animation_name: StringName, label: String) -> void:
	_check(
		animator != null and animator.has_animation(animation_name)
			and animator.current_animation == animation_name and animator.is_playing(),
		label
	)


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_fabricator")
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
