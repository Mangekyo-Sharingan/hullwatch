## Thirty-day conservation fixture, not balance acceptance: large sealed cabin, healthy
## equipment and a funded starter pod; all later raw stock comes from finite seeded deposits.
extends SceneTree

const WATCH_HOURS: float = 720.0
const FIELD_SEED: int = 20260918
const BOOTSTRAP_RAW: Dictionary = {"ice": 5.0, "metal": 11.0, "ore": 4.0}
const BOOTSTRAP_PARTS: Dictionary = {&"food_ration": 2}

var _failures: int = 0
var _spawned: Array[Node] = []
var _harness: SimHarness
var _power: PowerSystem
var _stores: Stores
var _cargo: CargoSystem
var _water: WaterSystem
var _vitals: VitalsSystem
var _sector: SectorSystem
var _fabricator: FabricatorSystem
var _modules: ModuleSystem
var _hull: HullSystem
var _reclaimer: WaterReclaimer
var _scrubber: ScrubberUnit
var _patch: HullPatch
var _shell: SealantCartridge
var _bench: FabricatorUnit
var _player: Node
var _canister: SampleCanister
var _port: CargoPort
var _save_manager: Node
var _gathered: Dictionary = {}
var _spent: Dictionary = {}
var _added: Dictionary = {}
var _consumed: Dictionary = {}
var _deposits: Dictionary = {}
var _water_added: float = 0.0
var _water_lost: float = 0.0
var _refills: int = 0
var _seals: int = 0
var _restores: int = 0
var _max_contacts: int = 0
var _registrations: int = 0
var _samples: int = 0
var _proc_errors: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_harness = SimHarness.new(self)
	_harness.setup_clock()
	root.get_node("SimClock").call("set_paused", true)
	_save_manager = root.get_node("SaveManager")
	_setup_world()
	await process_frame
	_check(bool(_player.call("equip_suit_cutter")), "bootstrap cutter equipped")
	root.get_node("EventBus").connect(&"sim_event", _audit_event)
	_check(_craft(&"water_charge"), "explicit starter ice processes into first water package")
	_check(_reclaimer.select_action(&"refill"), "low starter reserve receives actual paid water")
	_check(_modules.start_build(&"utility_pod"), "bootstrap cargo pays bare pod")
	_advance(8.01)
	_check(_modules.is_installed(&"utility_pod"), "funded pod completes through shared clock")
	_check(_modules.fit_machine(&"grow_rack", &"hp_quarters:0"), "bootstrap cargo pays grow equipment")
	_round_trip("paid grow fitting")
	_advance(5.01)
	_check(_modules.get_machine_at(&"hp_quarters:0") == &"grow_rack", "actual grow rack fitted")
	_check(_cargo.get_used_units() < 0.001, "starter construction and first water use all bootstrap raw stock")

	for day: int in 30:
		if day > 0 and day % 7 == 0:
			_weekly_maintenance(day)
		var target: float = float(day + 1) * 24.0
		while _harness.hours() < target - 0.0001:
			_mine_available()
			if _water.potable_l < 5.0 and _craft(&"water_charge"):
				_check(_reclaimer.select_action(&"refill"), "day%d mined water replenishes reserve" % (day + 1))
			_advance(minf(1.0, target - _harness.hours()))
		_round_trip("day%d fractional food and water" % (day + 1))
		_check(_water.potable_l > 0.0 and _stores.get_count(&"food_ration") > 0, "day%d retains real water and food" % (day + 1))
		_harness.clear_events()

	_assert_conservation()
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	if _failures == 0:
		print("PASS: test_resource_continuity")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _setup_world() -> void:
	_power = _harness.add_power([_harness.make_circuit(&"life_support", 120.0, 0), _harness.make_circuit(&"scrubber", 60.0, 1), _harness.make_circuit(&"fabricator", 80.0, 2)], 4000.0, {&"fixture_rtg": 500.0})
	_spawned.append(_power)
	_stores = _harness.add_stores(BOOTSTRAP_PARTS)
	_spawned.append(_stores)
	_cargo = CargoSystem.new()
	_spawn(_cargo)
	for kind: String in BOOTSTRAP_RAW:
		_cargo.add_material(StringName(kind), float(BOOTSTRAP_RAW[kind]))
	var cabin: CompartmentConfig = _harness.make_compartment(&"quarters", 1000.0)
	cabin.initial_occupants = 1
	cabin.puncture_mtbf_hours = 1.0e12
	cabin.hull_conductance_w_per_k = 0.0
	cabin.occupant_heat_w = 0.0
	_spawned.append(_harness.add_atmosphere([cabin]))
	_spawned.append(_harness.add_thermal([cabin]))
	_hull = HullSystem.new()
	_hull.compartment_defs.assign([cabin])
	_spawn(_hull)
	_water = WaterSystem.new()
	_water.potable_l = 2.0
	_water.greywater_l = 0.0
	_spawn(_water)
	_vitals = VitalsSystem.new()
	_spawn(_vitals)
	_sector = SectorSystem.new()
	_sector.field_seed = FIELD_SEED
	_spawn(_sector)
	_fabricator = FabricatorSystem.new()
	for recipe: String in ["water_charge", "sealant_charge", "water_filter", "co2_filter"]:
		_fabricator.recipes.append(load("res://src/data/fabrication/recipe_%s.tres" % recipe) as FabricatorRecipe)
	_spawn(_fabricator)
	_modules = ModuleSystem.new()
	var pod: ShipModule = (load("res://src/data/modules/module_utility_pod.tres") as ShipModule).duplicate(true) as ShipModule
	# Isolate consumable continuity from random leaks and temperature balancing.
	pod.compartment_config.leak_rate_per_hour = 0.0
	pod.compartment_config.puncture_mtbf_hours = 1.0e12
	pod.compartment_config.hull_conductance_w_per_k = 0.0
	pod.compartment_config.occupant_heat_w = 0.0
	_modules.catalog.assign([pod])
	_modules.machine_catalog.assign([load("res://src/data/machines/machine_grow_rack.tres")])
	_spawn(_modules)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_spawn(_player)
	_player.set_physics_process(false)
	_canister = SampleCanister.new()
	_canister.item_id = &"sample_canister"
	_spawn(_canister)
	_port = CargoPort.new()
	_spawn(_port)
	_shell = SealantCartridge.new()
	_spawn(_shell)
	_reclaimer = WaterReclaimer.new()
	_spawn(_reclaimer)
	_scrubber = ScrubberUnit.new()
	_scrubber.compartment_id = &"quarters"
	_spawn(_scrubber)
	_patch = HullPatch.new()
	_patch.compartment_id = &"quarters"
	_spawn(_patch)
	_bench = FabricatorUnit.new()
	_spawn(_bench)


func _advance(hours: float) -> void:
	var step: float = minf(hours, WATCH_HOURS - _harness.hours())
	if step <= 0.0:
		return
	var before: float = _water.potable_l + _water.greywater_l
	_harness.advance(step)
	var after: float = _water.potable_l + _water.greywater_l
	if after > before + 0.00001:
		_check(false, "consumption/reclamation cannot create liquid")
	_water_lost += before - after


func _mine_available() -> void:
	_player.call("take_carriable", _canister)
	if not bool(_player.call("has_suit_cutter")):
		_player.call("equip_suit_cutter")
	var contacts_now: Array[Dictionary] = _sector.get_contacts()
	_max_contacts = maxi(_max_contacts, contacts_now.size())
	for entry: Dictionary in contacts_now:
		_registrations += 1 if String(entry.get("resource", "")) in ["ice", "metal", "ore"] else 0
		var kind: StringName = StringName(entry.get("resource", ""))
		if kind not in [&"ice", &"metal", &"ore"] or _cargo.get_units(kind) >= (40.0 if kind == &"ice" else 20.0):
			continue
		var id: String = String(entry["id"])
		var before: float = _sector.get_remaining_yield(id)
		if before <= 0.0 or not _canister.is_empty():
			continue
		if not _deposits.has(id):
			_deposits[id] = {"initial": before, "taken": 0.0}
		var object: SpaceObject = SpaceObject.new()
		object.setup(entry)
		root.add_child(object)
		object.interact(_player)
		var sampled: float = _canister.get_load_units()
		if sampled > 0.0:
			_samples += 1
		var cargo_before: float = _cargo.get_units(kind)
		_port.interact(_player)
		var accepted: float = _cargo.get_units(kind) - cargo_before
		if absf(before - _sector.get_remaining_yield(id) - sampled) > 0.00001 or absf(accepted - sampled) > 0.00001:
			_check(false, "mining and cargo transfer conserve sampled material")
		_gathered[String(kind)] = float(_gathered.get(String(kind), 0.0)) + accepted
		_deposits[id]["taken"] = float(_deposits[id]["taken"]) + sampled
		object.free()


func _craft(recipe_id: StringName, pause: bool = false) -> bool:
	var recipe: FabricatorRecipe = _fabricator.get_recipe(recipe_id)
	if recipe == null or _fabricator.is_busy() or _cargo.get_units(recipe.material_kind) < recipe.material_units:
		return false
	var before: int = _stores.get_count(recipe.output_part_id)
	var refusal: StringName = _fabricator.start(recipe_id)
	if refusal != &"":
		_check(false, "available powered recipe starts: %s" % recipe_id)
		return false
	_advance(0.25)
	_round_trip("paid %s job" % recipe_id)
	if pause:
		_power.set_breaker(&"fabricator", false)
		var remaining: float = _fabricator.get_job_remaining_hours()
		_advance(1.0)
		_check(_fabricator.get_job_remaining_hours() == remaining and _stores.get_count(recipe.output_part_id) == before, "unpowered processing retains paid job and produces no free output")
		_round_trip("paused %s job" % recipe_id)
		_power.set_breaker(&"fabricator", true)
	_advance(_fabricator.get_job_remaining_hours() + 0.002)
	_check(not _fabricator.is_busy() and _stores.get_count(recipe.output_part_id) == before + recipe.output_count, "restored job outputs once: %s" % recipe_id)
	return not _fabricator.is_busy()


func _weekly_maintenance(day: int) -> void:
	_mine_available()
	if _craft(&"water_filter", true):
		var liters: float = _water.potable_l
		for action: int in 4:
			_check(_reclaimer.select_action(&"service"), "week%d water service step%d" % [day / 7, action])
		_check(_water.potable_l == liters and _water.contamination == 0.0, "filter servicing creates no potable reserve")
	else:
		_check(false, "finite mined ice funds weekly filter")
	if _craft(&"co2_filter"):
		for action: int in 7:
			_scrubber.interact(null)
		_check(_scrubber.is_powered() and not _scrubber.is_housing_open(), "paid CO2 filter installed through complete maintenance procedure")
	else:
		_check(false, "finite mined ore funds weekly CO2 filter")
	_player.call("take_carriable", _shell)
	if _shell.get_charge_count() == 0:
		_check(_craft(&"sealant_charge"), "finite mined metal funds reusable cartridge")
		# The round trip inside _craft leaves the operator empty-handed by design; the operator re-clips the shell.
		_player.call("take_carriable", _shell)
		_check(_bench.select_action(&"refill_sealant"), "paid sealant reaches actual held shell")
	_check(_hull.add_puncture(&"quarters", 1.0), "controlled fixture puncture seeded")
	for action: int in 3:
		_patch.interact(_player)
	_round_trip("sealed weekly patch")
	_patch.interact(_player)
	_check(_hull.get_puncture_count(&"quarters") == 0 and _shell.get_charge_count() == 0, "saved sealed repair completes without second charge")
	var fraction: float = float(_modules.save_state()["ration_hours"])
	var grown: int = int(_added.get("food_ration", 0))
	_power.set_breaker(&"life_support", false)
	_advance(2.0)
	_check(float(_modules.save_state()["ration_hours"]) == fraction and int(_added.get("food_ration", 0)) == grown, "unpowered fitted grow rack preserves fractional progress and adds no food")
	_power.set_breaker(&"life_support", true)
	_revisit_field()


func _deep_equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		var left: Dictionary = a as Dictionary
		var right: Dictionary = b as Dictionary
		if left.size() != right.size():
			return false
		for key: Variant in left:
			if not right.has(key) or not _deep_equal(left[key], right[key]):
				return false
		return true
	if a is Array and b is Array:
		var left_list: Array = a as Array
		var right_list: Array = b as Array
		if left_list.size() != right_list.size():
			return false
		for index: int in left_list.size():
			if not _deep_equal(left_list[index], right_list[index]):
				return false
		return true
	if a is int or a is float:
		if not (b is int or b is float):
			return false
		if is_finite(float(a)) and is_finite(float(b)):
			return absf(float(a) - float(b)) < 0.0000001
		return a == b
	return a == b


func _round_trip(label: String) -> void:
	var before: Dictionary = _save_manager.call("save_to_dict")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(before)) as Dictionary
	_check(bool(_save_manager.call("load_from_dict", saved)), "JSON restore: %s" % label)
	var after: Dictionary = _save_manager.call("save_to_dict")
	var old: Dictionary = before["systems"]
	var restored: Dictionary = after["systems"]
	var equal_stock: bool = _deep_equal(old["stores"], restored["stores"]) and _deep_equal(old["cargo"], restored["cargo"]) and _deep_equal(old["sector"], restored["sector"])
	for key: String in ["potable_l", "greywater_l", "contamination"]:
		equal_stock = equal_stock and absf(float(old["water"][key]) - float(restored["water"][key])) < 0.0000001
	equal_stock = equal_stock and absf(float(old["modules"]["ration_hours"]) - float(restored["modules"]["ration_hours"])) < 0.0000001
	equal_stock = equal_stock and absf(float(old["vitals"]["ration_accumulator"]) - float(restored["vitals"]["ration_accumulator"])) < 0.0000001
	equal_stock = equal_stock and _deep_equal(old["fabricator"], restored["fabricator"])
	if not equal_stock:
		var differing: PackedStringArray = []
		for key: String in ["stores", "cargo", "sector", "fabricator"]:
			if old[key] != restored[key]:
				differing.append(key)
				for field: String in old[key].keys():
					if str(old[key][field]) != str(restored[key].get(field, "<missing>")):
						differing.append("%s.%s=%s->%s" % [key, field, str(old[key][field]), str(restored[key].get(field, "<missing>"))])
				for field: String in restored[key].keys():
					if not old[key].has(field):
						differing.append("%s.+%s=%s" % [key, field, str(restored[key][field])])
		for key: String in ["potable_l", "greywater_l", "contamination"]:
			if absf(float(old["water"][key]) - float(restored["water"][key])) >= 0.0000001:
				differing.append("water.%s=%s->%s" % [key, str(old["water"][key]), str(restored["water"][key])])
		if absf(float(old["modules"]["ration_hours"]) - float(restored["modules"]["ration_hours"])) >= 0.0000001:
			differing.append("modules.ration_hours=%s->%s" % [str(old["modules"]["ration_hours"]), str(restored["modules"]["ration_hours"])])
		if absf(float(old["vitals"]["ration_accumulator"]) - float(restored["vitals"]["ration_accumulator"])) >= 0.0000001:
			differing.append("vitals.ration_accumulator=%s->%s" % [str(old["vitals"]["ration_accumulator"]), str(restored["vitals"]["ration_accumulator"])])
		print("RESTORE_DIFF:", differing)
	_check(equal_stock, "restore preserves material, charges, reserves and fractional/paid output: %s" % label)
	_restores += 1


func _revisit_field() -> void:
	var field: Dictionary = _sector.save_state()
	var bus: Node = root.get_node("EventBus")
	# A field-transition fixture, excluding navigation/fuel and arrival cache economics.
	bus.emit_signal(&"destination_arrived", &"fixture_other", &"deep_field", FIELD_SEED + 1, &"", 0.0, {})
	_round_trip("other field")
	bus.emit_signal(&"destination_arrived", &"fixture_home", &"deep_field", FIELD_SEED, &"", 0.0, {})
	var conserved: bool = true
	for id: String in _deposits:
		conserved = conserved and absf(_sector.get_remaining_yield(id) - (float(_deposits[id]["initial"]) - float(_deposits[id]["taken"]))) < 0.00001
	_check(conserved, "field revisit retains every partial and depleted finite source")
	_sector.load_state(field)


func _audit_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"procedure_error":
		var reason: String = String(payload.get("reason", ""))
		_proc_errors[reason] = int(_proc_errors.get(reason, 0)) + 1
		if int(_proc_errors.get(reason, 0)) <= 1:
			print("PROC_ERROR_FIRST:", reason, " payload=", str(payload))
		return
	if event_name == &"cargo_consumed":
		var kind: String = String(payload["kind"])
		_spent[kind] = float(_spent.get(kind, 0.0)) + float(payload["units"])
	elif event_name in [&"part_added", &"part_consumed"]:
		var part: String = String(payload["part_id"])
		var ledger: Dictionary = _added if event_name == &"part_added" else _consumed
		ledger[part] = int(ledger.get(part, 0)) + int(payload["count"])
	elif event_name == &"water_refilled":
		_water_added += float(payload["liters"])
	elif event_name == &"sealant_cartridge_refilled":
		_refills += 1
	elif event_name == &"sealant_charge_consumed":
		_seals += 1


func _assert_conservation() -> void:
	_check(absf(_harness.hours() - WATCH_HOURS) < 0.01, "watch advances thirty actual shared-clock days")
	for kind: String in BOOTSTRAP_RAW:
		_check(absf(_cargo.get_units(StringName(kind)) - (float(BOOTSTRAP_RAW[kind]) + float(_gathered.get(kind, 0.0)) - float(_spent.get(kind, 0.0)))) < 0.00001, "raw ledger conserved over thirty days: %s" % kind)
	for part: String in ["food_ration", "water_charge", "sealant_charge", "water_filter", "filter_co2"]:
		var initial: int = int(BOOTSTRAP_PARTS.get(StringName(part), 0))
		_check(_stores.get_count(StringName(part)) == initial + int(_added.get(part, 0)) - int(_consumed.get(part, 0)), "packaged/food ledger conserved: %s" % part)
	_check(absf(_water.potable_l + _water.greywater_l - (2.0 + _water_added - _water_lost)) < 0.00001, "liquid ledger preserves every transfer and processing/draw loss")
	_check(_water_added == float(_consumed.get("water_charge", 0)) * _water.water_charge_liters and _water_added >= 20.0, "multiple paid packages connect finite ice to actual potable water")
	_check(_shell.get_charge_count() == 1 + _refills - _seals and _seals == 4 and _refills == 3, "four repairs use one starter charge and three paid reusable refills")
	_check(int(_added.get("food_ration", 0)) >= 55 and int(_consumed.get("food_ration", 0)) >= 29, "powered fitted equipment supplies the actual month-long ration demand")
	_check(_restores >= 40 and not _deposits.is_empty(), "repeated real JSON boundaries and seeded extraction exercised")
	_check(not bool(_vitals.get_status()["incapacitated"]), "controlled water/food fixture remains viable through the watch")
	print("CONTINUITY: days=30 restores=%d mined=%s spent=%s water_added=%.1fL remaining=%.3fL food=%d seals=%d; controlled fixture excludes xenon resupply and accepted balance" % [_restores, _gathered, _spent, _water_added, _water.potable_l, _stores.get_count(&"food_ration"), _seals])
	print("MINE_STATS: contacts_max=%d registrations=%d samples=%d proc_errors=%s deposits_count=%d" % [_max_contacts, _registrations, _samples, str(_proc_errors), _deposits.size()])


func _spawn(node: Node) -> void:
	root.add_child(node)
	_spawned.append(node)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
