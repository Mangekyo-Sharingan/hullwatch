## Robustness: full-scene save/load round trip through the real main scene and SaveManager.
extends SceneTree

const SLOT: int = 3

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var sim_clock: Node = _find_root_child(&"SimClock")
	var save_manager: Node = _find_root_child(&"SaveManager")
	_check(sim_clock != null and save_manager != null, "scene: clock and save manager available")
	if sim_clock == null or save_manager == null:
		_finish()
		return
	save_manager.call("delete_save", SLOT)

	var power: PowerSystem = main.get_node("Systems/PowerSystem")
	var atmosphere: AtmosphereSystem = main.get_node("Systems/AtmosphereSystem")
	var stores: Stores = main.get_node("Systems/Stores")
	var breaker: BreakerPanel = main.get_node("WorldLayout/Props/BreakerPanel")

	sim_clock.call("fast_forward", 6.0)
	breaker.interact(null)
	power.call("force_failure", &"rtg_main", &"rtg_degraded")
	_check(not power.is_breaker_on(&"lighting"), "scene: lighting breaker toggled off")
	_check(power.get_generation_w() < 500.0, "scene: rtg derated by the failure")

	var hours_before: float = float(sim_clock.call("get_total_hours"))
	var co2_before: float = float(atmosphere.get_compartment_status(&"main")["co2_ppm"])
	var rations_before: int = stores.get_count(&"food_ration")
	_check(bool(save_manager.call("save_to_slot", SLOT)), "scene: save writes a slot")

	sim_clock.call("fast_forward", 4.0)
	breaker.interact(null)
	power.call("repair_component", &"rtg_main", 1.0)
	_check(power.is_breaker_on(&"lighting") and power.get_generation_w() > 400.0, "scene: state mutated after the save")

	_check(bool(save_manager.call("load_from_slot", SLOT)), "scene: load succeeds")
	await process_frame
	_check(absf(float(sim_clock.call("get_total_hours")) - hours_before) < 0.01, "scene: clock restored (%.2f h)" % hours_before)
	_check(not power.is_breaker_on(&"lighting"), "scene: breaker state restored")
	_check(power.get_generation_w() < 500.0, "scene: rtg failure effect restored (%.0f W)" % power.get_generation_w())
	var co2_after: float = float(atmosphere.get_compartment_status(&"main")["co2_ppm"])
	_check(absf(co2_after - co2_before) < 50.0, "scene: compartment CO2 restored")
	_check(stores.get_count(&"food_ration") == rations_before, "scene: ration stock restored")

	sim_clock.call("fast_forward", 1.0)
	_check(not atmosphere.get_compartment_status(&"main").is_empty(), "scene: simulation continues after load")

	# Persistence packet: physical items keep existence/possession/content across a fresh-scene load.
	var player: CharacterBody3D = main.get_node("Player")
	var cartridge: Carriable = main.find_child("SealantCartridge1", true, false) as Carriable
	var canister: SampleCanister = main.find_child("SampleCanister1", true, false) as SampleCanister
	_check(player != null and cartridge != null and canister != null, "scene: player and world items present")
	if player != null and cartridge != null and canister != null:
		var scanner: Carriable = main.find_child("ScannerTool", true, false) as Carriable
		var had_scanner: bool = scanner != null
		_check(had_scanner, "scene: dropped scanner available")
		var dropped_pose: Transform3D = Transform3D.IDENTITY
		if scanner != null:
			player.take_carriable(scanner)
			player.drop_carried()
			dropped_pose = scanner.global_transform
		var cutter: CutterTool = main.find_child("CutterTool", true, false) as CutterTool
		_check(cutter != null, "scene: clipped cutter available")
		if cutter != null:
			cutter.interact(player)
			_check(bool(player.call("has_suit_cutter")), "scene: cutter clips independently of carry slot")
		_check(player.take_carriable(cartridge), "scene: cartridge taken")
		_check(player.consume_carried(), "scene: cartridge consumed while carried")
		_check(not cartridge.enabled, "scene: consumed cartridge parks disabled")
		_check(canister.load_amount(&"ore", 3.0) > 0.0, "scene: canister loads a sample")
		_check(player.take_carriable(canister), "scene: loaded canister taken")
		_check(bool(save_manager.call("save_to_slot", SLOT)), "scene: save while holding a loaded canister")

		main.free()
		await process_frame
		var main2: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		root.add_child(main2)
		await process_frame
		await process_frame
		await process_frame
		_check(bool(save_manager.call("load_from_slot", SLOT)), "fresh scene: load succeeds")
		await process_frame
		var canister2: SampleCanister = main2.find_child("SampleCanister1", true, false) as SampleCanister
		var cartridge2: Carriable = main2.find_child("SealantCartridge1", true, false) as Carriable
		var player2: Node = main2.get_node("Player")
		_check(bool(player2.call("has_suit_cutter")), "fresh scene: cutter ability restores")
		var cutter2: CutterTool = main2.find_child("CutterTool", true, false) as CutterTool
		_check(cutter2 != null and cutter2.is_carried() and cutter2.get_parent() == player2.call("get_hold_anchor"), "fresh scene: restored cutter renders on the chest")
		if had_scanner:
			var scanner2: Carriable = main2.find_child("ScannerTool", true, false) as Carriable
			_check(scanner2 != null and scanner2.global_transform.is_equal_approx(dropped_pose), "fresh scene: dropped tool keeps its world placement")
		_check(canister2 != null and cartridge2 != null, "fresh scene: world items restored")
		if canister2 != null:
			_check(canister2.get_load_kind() == &"ore" and absf(canister2.get_load_units() - 3.0) < 0.001,
				"fresh scene: held canister contents survive the load")
			_check(not canister2.is_carried(), "fresh scene: canister rests at home, not carried")
			canister2.load_state({"enabled": true, "kind": "unknown", "units": 5.0})
			_check(canister2.is_empty(), "fresh scene: canister load rejects unknown kinds")
		if cartridge2 != null:
			_check(not cartridge2.enabled, "fresh scene: consumed cartridge does not respawn usable")
		var spare: Carriable = main2.find_child("SealantCartridge2", true, false) as Carriable
		_check(spare != null and spare.enabled, "fresh scene: untouched cartridge stays usable")
		main = main2

	save_manager.call("delete_save", SLOT)
	main.free()
	_finish()


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_scene_save_load")
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
