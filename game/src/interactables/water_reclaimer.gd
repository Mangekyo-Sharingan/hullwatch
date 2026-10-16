## Water reclaimer service procedure: drain the loop, swap the filter cartridge, prime, run inspection.
class_name WaterReclaimer
extends Interactable

enum Stage { IDLE, DRAIN, CARTRIDGE, PRIME }

const CLEAN_CONTAMINATION: float = 0.05
const ANIMATION_DRAIN: StringName = &"drain"
const ANIMATION_REPLACE: StringName = &"replace_cartridge"
const ANIMATION_PRIME: StringName = &"prime"
const ANIMATION_INSPECT: StringName = &"run_inspection"

@export var cartridge_part_id: StringName = &"water_filter"

var _stage: Stage = Stage.IDLE
var _menu: ScrollMenu
var _content: Label
var _root: HBoxContainer


func get_interaction_prompt() -> String:
	return "Close water reclaimer" if is_open() else "Use water reclaimer"


func _service_prompt() -> String:
	match _stage:
		Stage.IDLE:
			return "Drain loop"
		Stage.DRAIN:
			return "Replace cartridge"
		Stage.CARTRIDGE:
			return "Prime loop"
		Stage.PRIME:
			return "Run inspection"
	return "Drain loop"


func is_open() -> bool:
	return _menu != null and _menu.is_open()


func close() -> void:
	if _menu != null:
		_menu.close()
	if _root != null:
		_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if PanelDismiss.should_dismiss(event, is_open()):
		close()
		get_viewport().set_input_as_handled()


func get_menu() -> ScrollMenu:
	return _menu


func get_actions() -> Array[StringName]:
	return [&"service", &"refill"]


func select_action(action_id: StringName) -> bool:
	if action_id == &"refill":
		var water: Node = _get_system(&"water_system")
		if _stage != Stage.IDLE or water == null or float(water.call("refill_from_stores", water.get("water_charge_part_id"))) <= 0.0:
			_emit_sim_event(&"procedure_error", {"reason": &"water_refill_refused"})
			return false
	elif action_id == &"service":
		var before: Stage = _stage
		_advance_service()
		if before == _stage:
			return false
	else:
		return false
	_refresh_menu()
	return true


func _handle_interact(_player: Node) -> void:
	if is_open():
		close()
		return
	_ensure_ui()
	_refresh_menu()
	_menu.open()
	_root.visible = true


func _on_selected(index: int) -> void:
	if index >= 0 and index < get_actions().size():
		select_action(get_actions()[index])


func _refresh_menu() -> void:
	if _menu == null:
		return
	var water: Node = _get_system(&"water_system")
	var stores: Node = _get_system(&"stores_system")
	var liters: float = float(water.get("water_charge_liters")) if water != null else 0.0
	var charges: int = int(stores.call("get_count", water.get("water_charge_part_id"))) if stores != null and water != null else 0
	_menu.set_items(PackedStringArray([_service_prompt(), "Transfer water charge (+%.0f L; %d stored)" % [liters, charges]]))
	if _content != null and water != null:
		var status: Dictionary = water.call("get_status")
		_content.text = "POTABLE %.1f / %.1f L\nGREYWATER %.1f L\nCONTAMINATION %.0f%%\n\nFilters treat the loop.\nWater charges fill the tank." % [float(status["potable_l"]), float(status["potable_capacity_l"]), float(status["greywater_l"]), float(status["contamination"]) * 100.0]


func _advance_service() -> void:
	match _stage:
		Stage.IDLE:
			_drain_loop()
		Stage.DRAIN:
			_replace_cartridge()
		Stage.CARTRIDGE:
			_prime_loop()
		Stage.PRIME:
			_run_inspection()


func _drain_loop() -> void:
	var water: Node = _get_system(&"water_system")
	if water != null and water.has_method(&"get_status"):
		var status: Variant = water.call("get_status")
		if status is Dictionary and float((status as Dictionary).get("contamination", 0.0)) <= CLEAN_CONTAMINATION:
			_emit_sim_event(&"procedure_error", {"reason": &"clean_loop"})
			return
	_stage = Stage.DRAIN
	if water != null:
		water.set("reclaimer_servicing", true)
	_play_animation(ANIMATION_DRAIN)


func _replace_cartridge() -> void:
	var stores: Node = _get_system(&"stores_system")
	if stores == null or not bool(stores.call("consume_part", cartridge_part_id, 1)):
		_emit_sim_event(&"procedure_error", {"reason": &"no_cartridge", "part_id": cartridge_part_id})
		return
	_stage = Stage.CARTRIDGE
	_play_animation(ANIMATION_REPLACE)


func _prime_loop() -> void:
	_stage = Stage.PRIME
	_play_animation(ANIMATION_PRIME)


func _run_inspection() -> void:
	var water: Node = _get_system(&"water_system")
	if water != null:
		if water.has_method(&"install_cartridge"):
			water.call("install_cartridge")
		if water.has_method(&"purge"):
			water.call("purge")
		water.set("reclaimer_servicing", false)
	_stage = Stage.IDLE
	_play_animation(ANIMATION_INSPECT)
	_emit_sim_event(&"reclaimer_serviced", {"part_id": cartridge_part_id})


func save_state() -> Dictionary:
	var state: Dictionary = super.save_state()
	state["system_id"] = "water_reclaimer"
	state["state_version"] = 1
	state["stage"] = int(_stage)
	return state


func load_state(state: Dictionary) -> void:
	super.load_state(state)
	_stage = clampi(int(state.get("stage", int(_stage))), int(Stage.IDLE), int(Stage.PRIME))
	var water: Node = _get_system(&"water_system")
	if water != null:
		water.set("reclaimer_servicing", _stage != Stage.IDLE)
	_restore_visual_state()
	_refresh_menu()


func _restore_visual_state() -> void:
	var animator: AnimationPlayer = _get_animator()
	if animator == null:
		return
	_seek_animation_start(animator, ANIMATION_DRAIN)
	_seek_animation_end(animator, ANIMATION_REPLACE)
	_seek_animation_start(animator, ANIMATION_PRIME)
	_seek_animation_end(animator, ANIMATION_INSPECT)
	if _stage >= Stage.CARTRIDGE:
		_seek_animation_end(animator, ANIMATION_REPLACE)
	if _stage == Stage.DRAIN:
		animator.play(ANIMATION_DRAIN)
	elif _stage == Stage.PRIME:
		animator.play(ANIMATION_PRIME)


func _play_animation(animation_name: StringName) -> void:
	var animator: AnimationPlayer = _get_animator()
	if animator != null and animator.has_animation(animation_name):
		animator.play(animation_name)


func _seek_animation_end(animator: AnimationPlayer, animation_name: StringName) -> void:
	if not animator.has_animation(animation_name):
		return
	animator.play(animation_name)
	var animation: Animation = animator.get_animation(animation_name)
	animator.seek(animation.length, true)
	animator.pause()


func _seek_animation_start(animator: AnimationPlayer, animation_name: StringName) -> void:
	if not animator.has_animation(animation_name):
		return
	animator.play(animation_name)
	animator.seek(0.0, true)
	animator.pause()


func _get_animator() -> AnimationPlayer:
	return find_child("AnimationPlayer", true, false) as AnimationPlayer


func _ensure_ui() -> void:
	if _root != null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	_root = HBoxContainer.new()
	_root.add_theme_constant_override("separation", 12)
	center.add_child(_root)
	_menu = ScrollMenu.new()
	_root.add_child(_menu)
	_menu.setup("WATER RECLAIMER", PackedStringArray())
	_menu.option_selected.connect(_on_selected)
	_content = Label.new()
	_content.add_theme_font_size_override("font_size", 14)
	CrtPanel.style_label(_content, CrtPanel.PHOSPHOR_AMBER)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.02, 0.85)
	style.border_color = Color(0.65, 0.5, 0.25, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	panel.add_child(_content)
	CrtPanel.add_overlay(panel)
	_root.visible = false
