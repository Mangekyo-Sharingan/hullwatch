## Workshop fabricator: one job at a time, consuming cargo material into stores parts.
## Powered through its own breaker circuit; refuses politely when it can't work.
class_name FabricatorSystem
extends ShipSystem

@export var recipes: Array[FabricatorRecipe] = []
@export var circuit_id: StringName = &"fabricator"

var _job_terms: Dictionary = {}
var _job_remaining_hours: float = 0.0
## Set by ModuleSystem: a workshop pod speeds the bench up (0.7 = 30 percent faster).
var job_hours_multiplier: float = 1.0


func _ready() -> void:
	system_id = &"fabricator"
	add_to_group(&"fabricator_system")
	super._ready()


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		return
	if _job_terms.is_empty():
		return
	if not _power_available():
		return
	_job_remaining_hours = maxf(_job_remaining_hours - delta_hours, 0.0)
	if _job_remaining_hours > 0.0:
		return
	var stores: Node = _first_node_in_group(&"stores_system")
	if stores == null or not stores.has_method(&"add_part"):
		return
	var terms: Dictionary = _job_terms
	_job_terms = {}
	stores.call("add_part", StringName(terms["output_part_id"]), int(terms["output_count"]))
	emit_sim_event(&"fabrication_completed", {
		"recipe_id": terms["recipe_id"],
		"part_id": terms["output_part_id"],
		"count": terms["output_count"],
	})


func is_busy() -> bool:
	return not _job_terms.is_empty()


func get_job_recipe_id() -> StringName:
	if _job_terms.is_empty():
		return &""
	return StringName(_job_terms.get("recipe_id", ""))


func get_job_remaining_hours() -> float:
	return _job_remaining_hours


func get_recipe(recipe_id: StringName) -> FabricatorRecipe:
	for recipe: FabricatorRecipe in recipes:
		if recipe != null and recipe.recipe_id == recipe_id:
			return recipe
	return null


## Starts a job: power, then materials (consumed up front), then the queue.
func start(recipe_id: StringName) -> StringName:
	if not _job_terms.is_empty():
		return &"fabricator_busy"
	var recipe: FabricatorRecipe = get_recipe(recipe_id)
	if recipe == null:
		return &"unknown_recipe"
	if recipe.recipe_id == &"" or recipe.material_kind not in CargoSystem.KNOWN_KINDS or not is_finite(recipe.material_units) or recipe.material_units <= 0.0 or recipe.output_part_id == &"" or recipe.output_count <= 0 or not is_finite(recipe.hours) or recipe.hours <= 0.0 or not is_finite(job_hours_multiplier):
		return &"invalid_recipe"
	if not _power_available():
		return &"no_power"
	var cargo: Node = _first_node_in_group(&"cargo_system")
	if cargo == null or not cargo.has_method(&"consume_material"):
		return &"no_materials"
	var hours: float = recipe.hours * clampf(job_hours_multiplier, 0.1, 1.0)
	var terms: Dictionary = _recipe_terms(recipe, hours)
	if not bool(cargo.call("consume_material", recipe.material_kind, recipe.material_units)):
		return &"no_materials"
	_job_terms = terms
	_job_remaining_hours = hours
	emit_sim_event(&"fabrication_started", {
		"recipe_id": String(recipe.recipe_id),
		"material_kind": String(recipe.material_kind),
		"material_units": recipe.material_units,
	})
	return &""


func get_status() -> Dictionary:
	return {
		"system_id": system_id,
		"busy": is_busy(),
		"job_recipe_id": String(get_job_recipe_id()),
		"job_remaining_hours": _job_remaining_hours,
		"powered": _power_available(),
	}


func save_state() -> Dictionary:
	return {
		"system_id": String(system_id),
		"state_version": 2,
		"job_recipe_id": String(get_job_recipe_id()),
		"job_remaining_hours": _job_remaining_hours,
		"job_terms": _job_terms.duplicate(true),
	}


func load_state(state: Dictionary) -> void:
	_job_terms = _canonicalize_terms(state.get("job_terms", {}))
	_job_remaining_hours = maxf(float(state.get("job_remaining_hours", 0.0)), 0.0)
	if int(state.get("state_version", 1)) < 2:
		var recipe: FabricatorRecipe = get_recipe(StringName(String(state.get("job_recipe_id", ""))))
		if recipe != null:
			_job_terms = _recipe_terms(recipe, maxf(recipe.hours, _job_remaining_hours))
	if _job_terms.is_empty():
		_job_remaining_hours = 0.0
	emit_sim_event(&"fabricator_state_restored", {"busy": is_busy()})


# The owner owns its payload shape: JSON restores every number as float, so the
# count is rebuilt as int and hours/units as float to keep round trips exact.
func _canonicalize_terms(raw: Variant) -> Dictionary:
	var canonical: Dictionary = {}
	if not raw is Dictionary:
		return canonical
	var source: Dictionary = raw as Dictionary
	for key: String in ["recipe_id", "material_kind", "output_part_id"]:
		var value: Variant = source.get(key)
		if value is String:
			canonical[key] = String(value)
	for key: String in ["material_units", "total_hours"]:
		var value: Variant = source.get(key)
		if value is int or value is float:
			canonical[key] = float(value)
	var count: Variant = source.get("output_count")
	if count is int or count is float:
		canonical["output_count"] = int(count)
	return canonical


func _recipe_terms(recipe: FabricatorRecipe, hours: float) -> Dictionary:
	return {
		"recipe_id": String(recipe.recipe_id),
		"material_kind": String(recipe.material_kind),
		"material_units": recipe.material_units,
		"output_part_id": String(recipe.output_part_id),
		"output_count": recipe.output_count,
		"total_hours": hours,
	}


func _power_available() -> bool:
	var power: Node = _first_node_in_group(&"power_system")
	if power == null:
		return true
	if power.has_method(&"is_breaker_on") and not bool(power.call("is_breaker_on", circuit_id)):
		return false
	if power.has_method(&"is_circuit_shed") and bool(power.call("is_circuit_shed", circuit_id)):
		return false
	return true


func _first_node_in_group(group_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		var main_loop: MainLoop = Engine.get_main_loop()
		if main_loop is SceneTree:
			tree = main_loop as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(group_name)
