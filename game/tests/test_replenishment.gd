## Real extraction -> paid processing -> reserve transfer and reusable cartridge continuity.
extends SceneTree

var _failures: int = 0
var _spawned: Array[Node] = []
var _harness: SimHarness
var _sector: SectorSystem
var _cargo: CargoSystem
var _stores: Stores
var _power: PowerSystem
var _fabricator: FabricatorSystem
var _water: WaterSystem
var _player: Node
var _canister: SampleCanister
var _port: CargoPort


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_harness = SimHarness.new(self)
	_harness.setup_clock()
	root.get_node("SimClock").call("set_paused", true)
	_power = _harness.add_power([_harness.make_circuit(&"life_support", 120.0, 0), _harness.make_circuit(&"fabricator", 80.0, 2)], 4000.0, {&"rtg": 500.0})
	_spawned.append(_power)
	_stores = _harness.add_stores({&"water_filter": 1})
	_spawned.append(_stores)
	_cargo = CargoSystem.new()
	_spawn(_cargo)
	_sector = SectorSystem.new()
	_sector.field_seed = 20260918
	_spawn(_sector)
	_fabricator = FabricatorSystem.new()
	_fabricator.recipes.assign([load("res://src/data/fabrication/recipe_water_charge.tres"), load("res://src/data/fabrication/recipe_sealant_charge.tres")])
	_spawn(_fabricator)
	_water = WaterSystem.new()
	_water.greywater_l = 0.0
	_spawn(_water)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_spawn(_player)
	_player.set_physics_process(false)
	_canister = SampleCanister.new()
	_canister.item_id = &"sample_canister"
	_spawn(_canister)
	_port = CargoPort.new()
	_spawn(_port)
	await process_frame
	_check(bool(_player.call("equip_suit_cutter")), "cutter available for actual extraction")
	_check(bool(_player.call("take_carriable", _canister)), "canister taken for mining")
	if _mine_kind(&"ice"):
		_test_water_loop()
	if _mine_kind(&"metal"):
		_test_sealant_loop()
	await _test_exterior_water()
	_despawn_all()
	print("PASS: test_replenishment" if _failures == 0 else "FAILURES: %d" % _failures)
	quit(0 if _failures == 0 else 1)


func _mine_kind(kind: StringName) -> bool:
	if _player.call("get_carried") != _canister:
		_player.call("take_carriable", _canister)
	for step: int in 1000:
		_sector.sim_tick(1.0)
		for entry: Dictionary in _sector.get_contacts():
			if StringName(entry.get("resource", "")) != kind or _sector.get_remaining_yield(String(entry["id"])) < 2.0:
				continue
			var object: SpaceObject = SpaceObject.new()
			object.setup(entry)
			_spawn(object)
			var before: float = _sector.get_remaining_yield(String(entry["id"]))
			object.interact(_player)
			var sampled: float = _canister.get_load_units()
			_check(sampled > 0.0 and _canister.get_load_kind() == kind, "%s mined into carried canister" % kind)
			_check(is_equal_approx(_sector.get_remaining_yield(String(entry["id"])), before - sampled), "%s extraction debits its finite source" % kind)
			var held: float = _cargo.get_units(kind)
			_port.interact(_player)
			_check(_canister.is_empty() and is_equal_approx(_cargo.get_units(kind), held + sampled), "%s transferred through cargo port exactly once" % kind)
			var saved: Dictionary = _json(_sector.save_state())
			_sector.load_state(saved)
			_check(is_equal_approx(_sector.get_remaining_yield(String(entry["id"])), before - sampled), "%s depletion survives JSON" % kind)
			return sampled > 0.0
	_check(false, "seeded field supplies %s" % kind)
	return false


func _test_water_loop() -> void:
	var raw_before: float = _cargo.get_units(&"ice")
	_check(_fabricator.start(&"water_charge") == &"", "mined ice starts powered water packaging")
	_check(is_equal_approx(_cargo.get_units(&"ice"), raw_before - 4.0), "water packaging pays four ice once")
	_fabricator.sim_tick(0.5)
	var paid: Dictionary = _snapshot()
	_power.set_breaker(&"fabricator", false)
	_fabricator.sim_tick(10.0)
	_check(_stores.get_count(&"water_charge") == 0 and is_equal_approx(_fabricator.get_job_remaining_hours(), 0.5), "unpowered paid processing pauses")
	_power.set_breaker(&"fabricator", true)
	_restore(paid)
	_fabricator.sim_tick(0.5)
	_fabricator.sim_tick(10.0)
	_check(_stores.get_count(&"water_charge") == 1 and is_equal_approx(_cargo.get_units(&"ice"), raw_before - 4.0), "paid-job restore completes one package without charging twice")
	var packaged: Dictionary = _snapshot()
	var reclaimer: WaterReclaimer = WaterReclaimer.new()
	_spawn(reclaimer)
	reclaimer.interact(_player)
	_check(reclaimer.is_open() and reclaimer.get_menu().get_items().size() == 2, "reclaimer offers separate filter-service and transfer actions")
	_power.set_breaker(&"life_support", false)
	_check(not reclaimer.select_action(&"refill") and _stores.get_count(&"water_charge") == 1, "unpowered transfer preserves package")
	_power.set_breaker(&"life_support", true)
	_water.potable_capacity_l = 125.0
	_check(_water.refill_from_stores(&"water_charge") == 0.0 and _stores.get_count(&"water_charge") == 1 and _water.potable_l == 120.0, "insufficient whole-package headroom preserves stock")
	_water.potable_capacity_l = 150.0
	_check(_water.refill_from_stores(&"water_filter") == 0.0, "filter is never a water package")
	_water.contamination = 0.8
	_check(reclaimer.select_action(&"service"), "drain starts distinct maintenance procedure")
	_check(not reclaimer.select_action(&"refill") and _water.refill_from_stores(&"water_charge") == 0.0, "active service blocks both menu and simulator fills")
	var drain: Dictionary = _json(reclaimer.save_state())
	reclaimer.load_state(drain)
	_check(_water.reclaimer_servicing, "saved maintenance stage keeps fill blocked")
	for stage: int in 3:
		_check(reclaimer.select_action(&"service"), "service step %d completes" % stage)
	_check(_water.potable_l == 120.0 and _stores.get_count(&"water_filter") == 0 and not _water.reclaimer_servicing, "filter service treats contamination without adding liters")
	_check(reclaimer.select_action(&"refill") and _water.potable_l == 130.0 and _stores.get_count(&"water_charge") == 0, "real package raises potable by configured ten liters")
	var filled: Dictionary = _snapshot()
	_check(not reclaimer.select_action(&"refill") and _water.potable_l == 130.0, "empty-stock repeat cannot duplicate water")
	_restore(packaged)
	_check(_water.refill_from_stores(&"water_charge") == 10.0 and _stores.get_count(&"water_charge") == 0, "packaged-output restore fills exactly once")
	_restore(filled)
	_check(_water.refill_from_stores(&"water_charge") == 0.0 and _water.potable_l == 130.0, "post-transfer restore cannot recreate package")
	reclaimer.close()
	_check(not reclaimer.is_open(), "reclaimer menu closes")


func _test_sealant_loop() -> void:
	_check(_fabricator.start(&"sealant_charge") == &"", "mined metal starts sealant packaging")
	_fabricator.sim_tick(1.0)
	_check(_stores.get_count(&"sealant_charge") == 1, "paid sealant job creates one refill package")
	var shell: SealantCartridge = SealantCartridge.new()
	shell.name = "ReusableShell"
	_spawn(shell)
	var home_key: String = shell.get_save_key()
	_check(shell.get_charge_count() == 1, "new authored shell starts with one charge")
	_player.call("take_carriable", shell)
	_check(shell.get_save_key() == home_key, "carried shell retains home identity")
	var config: CompartmentConfig = _harness.make_compartment(&"main")
	config.puncture_mtbf_hours = 1.0e12
	var hull: HullSystem = HullSystem.new()
	hull.compartment_defs.assign([config])
	_spawn(hull)
	hull.add_puncture(&"main", 1.0)
	var patch: HullPatch = HullPatch.new()
	_spawn(patch)
	patch.interact(_player)
	patch.interact(_player)
	var before_seal: Dictionary = _json(_stores.save_state())
	patch.interact(_player)
	_check(_player.call("get_carried") == shell and shell.get_charge_count() == 0, "seal debits one charge and keeps physical shell")
	var sealed: Dictionary = _json(patch.save_state())
	var empty: Dictionary = _json(_stores.save_state())
	_stores.load_state(before_seal)
	_stores.load_state(empty)
	patch.load_state(sealed)
	patch.interact(_player)
	_check(hull.get_puncture_count(&"main") == 0 and shell.get_charge_count() == 0, "sealed-but-unverified restore patches without another debit or refund")
	hull.add_puncture(&"main", 1.0)
	patch.interact(_player)
	patch.interact(_player)
	patch.interact(_player)
	_check(patch.get_interaction_prompt() == "Apply sealant" and hull.get_puncture_count(&"main") == 1, "empty carried shell cannot seal a second puncture")
	var bench: FabricatorUnit = FabricatorUnit.new()
	_spawn(bench)
	bench.interact(_player)
	_check(bench.get_actions().has(&"refill_sealant"), "bench exposes carried-shell refill action")
	_power.set_breaker(&"fabricator", false)
	_check(not bench.select_action(&"refill_sealant") and _stores.get_count(&"sealant_charge") == 1 and shell.get_charge_count() == 0, "unpowered bench preserves both shell and package")
	_power.set_breaker(&"fabricator", true)
	_check(bench.select_action(&"refill_sealant") and shell.get_charge_count() == 1 and _stores.get_count(&"sealant_charge") == 0, "powered bench transfers one paid charge into held shell")
	_check(not bench.select_action(&"refill_sealant") and shell.get_charge_count() == 1, "full-shell retry cannot duplicate charges")
	var refilled: Dictionary = _json(_stores.save_state())
	patch.interact(_player)
	patch.interact(_player)
	_check(hull.get_puncture_count(&"main") == 0 and shell.get_charge_count() == 0, "refilled shell completes next repair")
	_stores.load_state(refilled)
	_check(shell.get_charge_count() == 1, "refilled shell charge survives Stores JSON load")
	shell.mark_consumed()
	shell.load_state({"enabled": false})
	_check(shell.get_charge_count() == 0 and _stores.get_cartridge_charges(StringName(home_key)) == 0, "legacy consumed tombstone never gains a reusable charge")
	_stores.load_state({"state_version": 1, "inventory": {}})
	shell.load_state({"enabled": true})
	_check(shell.get_charge_count() == 1, "legacy untouched shell restores its original charge in an already-used scene")
	shell.load_state({"enabled": false})
	_check(shell.get_charge_count() == 0, "legacy consumed shell restoration overrides initial charge")
	bench.close()


func _test_exterior_water() -> void:
	_water.set_reclaimer_powered(false)
	var before: float = _water.potable_l
	_water.sim_tick(1.0)
	_check(_water.potable_l == before, "no atmosphere or manned room does not invent an exterior operator")
	var config: CompartmentConfig = _harness.make_compartment(&"main")
	config.initial_occupants = 0
	var atmosphere: AtmosphereSystem = _harness.add_atmosphere([config])
	_spawned.append(atmosphere)
	await process_frame
	_water.sim_tick(1.0)
	_check(is_equal_approx(_water.potable_l, before - 0.06), "actual exterior operator still consumes water once")
	atmosphere.set_occupants(&"main", 1)
	_water.sim_tick(1.0)
	_check(is_equal_approx(_water.potable_l, before - 0.12), "returning operator consumes cabin water without doubled exterior draw")


func _snapshot() -> Dictionary:
	return _json({"stores": _stores.save_state(), "cargo": _cargo.save_state(), "fabricator": _fabricator.save_state(), "water": _water.save_state()})


func _restore(state: Dictionary) -> void:
	_stores.load_state(state["stores"])
	_cargo.load_state(state["cargo"])
	_fabricator.load_state(state["fabricator"])
	_water.load_state(state["water"])


func _json(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state)) as Dictionary


func _spawn(node: Node) -> void:
	root.add_child(node)
	_spawned.append(node)


func _despawn_all() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
