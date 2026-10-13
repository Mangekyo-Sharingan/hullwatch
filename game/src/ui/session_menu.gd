extends CanvasLayer

const SETTINGS_SCRIPT: Script = preload("res://src/ui/settings_menu.gd")
const SLOT_COUNT: int = 3

@export var pause_mode: bool = false

var _open: bool = false
var _busy: bool = false
var _page: StringName = &"root"
var _pending_slot: int = 0
var _actions: PackedStringArray = PackedStringArray()
var _ids: Array[StringName] = []
var _menu: ScrollMenu
var _settings: Node
var _view: Control
var _message: Label
var _wordmark: Label
var _subtitle: Label
var _version_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build_ui()
	_settings = get_parent().get_node_or_null(^"SettingsMenu")
	if _settings == null:
		_settings = SETTINGS_SCRIPT.new() as Node
		_settings.name = "SettingsMenu"
		_settings.set("managed_by_controller", true)
		_settings.set("capture_mouse_when_closed", false)
		add_child(_settings)
	else:
		_settings.set("managed_by_controller", true)
		_settings.set("capture_mouse_when_closed", false)
	_settings.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings.connect(&"closed", _on_settings_closed)
	_refresh()
	if pause_mode:
		_view.hide()
		_menu.close()
	else:
		open()
		var manager: Node = _manager()
		if manager != null and not String(manager.call("get_last_error")).is_empty():
			_show_error(manager)
		get_node(^"/root/UpdateChecker").connect(&"check_finished", _on_update_checked)
		_on_update_checked()


func get_menu() -> ScrollMenu:
	return _menu


func get_actions() -> PackedStringArray:
	return _actions.duplicate()


func is_menu_open() -> bool:
	return _open


func open() -> void:
	if _busy:
		return
	_open = true
	_page = &"root"
	_message.text = ""
	_refresh()
	_view.show()
	_menu.open()
	_pause_world(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if _busy:
		return
	_open = false
	if _settings != null and bool(_settings.call("is_menu_open")):
		_settings.call("close")
	_menu.close()
	_view.hide()
	if pause_mode:
		_pause_world(false)
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func select_action(index: int) -> void:
	if not _open or _busy or bool(_settings.call("is_menu_open")) or index < 0 or index >= _ids.size():
		return
	var action: StringName = _ids[index]
	_message.text = ""
	match action:
		&"resume":
			close()
		&"new", &"load":
			_page = action
			_refresh()
		&"delete":
			_page = &"delete"
			_refresh()
		&"confirm_delete":
			var manager: Node = _manager()
			if manager != null and bool(manager.call("delete_save", _pending_slot)):
				_page = &"delete"
				_message.text = "SLOT %d DELETED" % _pending_slot
				_refresh()
			else:
				_show_error(manager)
		&"back", &"cancel":
			_back()
		&"settings":
			_menu.close()
			_view.hide()
			_settings.call("open")
		&"continue":
			var manager: Node = _manager()
			var slot: int = int(manager.call("get_latest_valid_slot")) if manager != null else 0
			if slot > 0:
				await _transition(&"load_game_scene", slot)
			else:
				_message.text = "NO VALID WATCH TO CONTINUE"
		&"overwrite":
			await _transition(&"start_new_game", _pending_slot)
		&"save", &"save_quit":
			var manager: Node = _manager()
			_busy = true
			var saved: bool = manager != null and bool(manager.call("save_to_slot", int(manager.get("active_slot"))))
			_busy = false
			if not saved:
				_show_error(manager)
			elif action == &"save_quit":
				_quit_game()
			else:
				_message.text = "WATCH SAVED IN SLOT %d" % int(manager.get("active_slot"))
		&"save_menu":
			var manager: Node = _manager()
			_busy = true
			var returned: bool = manager != null and bool(await manager.call("return_to_menu"))
			_busy = false
			if not returned:
				_pause_world(true)
				_show_error(manager)
			elif is_inside_tree():
				close()
		&"quit":
			_quit_game()
		&"update":
			OS.shell_open(String(get_node(^"/root/UpdateChecker").get("release_url")))
		_:
			var slot: int = String(action).get_slice(":", 1).to_int()
			var summary: Dictionary = _slot_summary(slot)
			if _page == &"new":
				if bool(summary.get("exists", false)):
					_pending_slot = slot
					_page = &"overwrite"
					_message.text = "REPLACE %s? THIS WATCH WILL BE LOST." % _slot_label(summary)
					_refresh()
				else:
					await _transition(&"start_new_game", slot)
			elif _page == &"load":
				if bool(summary.get("valid", false)):
					await _transition(&"load_game_scene", slot)
				else:
					_message.text = "THIS SLOT HAS NO VALID WATCH"
			elif _page == &"delete":
				if bool(summary.get("exists", false)):
					_pending_slot = slot
					_page = &"delete_confirm"
					_message.text = "DELETE %s? THIS CANNOT BE UNDONE." % _slot_label(summary)
					_refresh()
				else:
					_message.text = "THIS SLOT IS EMPTY"


func _transition(method: StringName, slot: int) -> void:
	var manager: Node = _manager()
	if manager == null:
		_show_error(null)
		return
	_busy = true
	_message.text = "LOADING WATCH..."
	await manager.call(method, slot)
	if not is_inside_tree():
		return
	_busy = false
	if not String(manager.call("get_last_error")).is_empty():
		_pause_world(true)
		_show_error(manager)
	else:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		if _open:
			get_viewport().set_input_as_handled()
		return
	if _open and bool(_settings.call("is_menu_open")):
		if event.is_action_pressed(&"pause"):
			_settings.call("close")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"secondary"):
			_settings.call("_decrease_highlighted")
			get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(&"pause"):
		return
	if _open:
		_back()
	elif pause_mode:
		# UI nodes receive unhandled input before some world nodes; let an open physical readout consume Escape.
		for node: Node in get_tree().get_nodes_in_group(&"saveable"):
			if node.has_method(&"is_open") and node.has_method(&"close") and bool(node.call("is_open")):
				return
		open()
	else:
		return
	get_viewport().set_input_as_handled()


func _back() -> void:
	_message.text = ""
	if _page == &"overwrite":
		_page = &"new"
	elif _page == &"delete_confirm":
		_page = &"delete"
	elif _page != &"root":
		_page = &"root"
	elif pause_mode:
		close()
	_refresh()


func _on_settings_closed() -> void:
	if _open:
		_view.show()
		_menu.open()
		_refresh()


func _pause_world(paused: bool) -> void:
	get_tree().paused = paused if pause_mode else false
	var clock: Node = get_node_or_null(^"/root/SimClock")
	if clock != null:
		clock.call("set_paused", paused)


func _manager() -> Node:
	return get_node_or_null(^"/root/SaveManager")


func _slot_summary(slot: int) -> Dictionary:
	var manager: Node = _manager()
	return manager.call("get_slot_summary", slot) as Dictionary if manager != null else {"slot": slot, "exists": false, "valid": false}


func _slot_label(summary: Dictionary) -> String:
	var prefix: String = "SLOT %d" % int(summary.get("slot", 0))
	if not bool(summary.get("exists", false)):
		return prefix + "  EMPTY"
	if not bool(summary.get("valid", false)):
		return prefix + "  INVALID WATCH"
	var location: String = String(summary.get("destination_id", ""))
	location = "DRIFT CORRIDOR" if location.is_empty() else location.replace("_", " ").to_upper()
	return "%s  DAY %04d  %s" % [prefix, int(summary.get("day", 1)), location]


func _show_error(manager: Node) -> void:
	var reason: String = String(manager.call("get_last_error")) if manager != null else "save_manager_unavailable"
	_message.text = "WATCH ACTION FAILED: %s" % reason.replace("_", " ").to_upper()


func _refresh() -> void:
	_ids.clear()
	_actions.clear()
	if _page in [&"new", &"load", &"delete"]:
		for slot: int in range(1, SLOT_COUNT + 1):
			_add_action(StringName("slot:%d" % slot), _slot_label(_slot_summary(slot)))
		_add_action(&"back", "BACK")
	elif _page == &"overwrite":
		_add_action(&"overwrite", "OVERWRITE SLOT %d AND START NEW WATCH" % _pending_slot)
		_add_action(&"cancel", "CANCEL")
	elif _page == &"delete_confirm":
		_add_action(&"confirm_delete", "DELETE SLOT %d" % _pending_slot)
		_add_action(&"cancel", "CANCEL")
	elif pause_mode:
		_add_action(&"resume", "RESUME")
		_add_action(&"save", "SAVE WATCH (SLOT %d)" % (int(_manager().get("active_slot")) if _manager() != null else 1))
		_add_action(&"load", "LOAD WATCHES")
		_add_action(&"settings", "SETTINGS")
		_add_action(&"save_menu", "SAVE AND MAIN MENU")
		_add_action(&"save_quit", "SAVE AND QUIT")
	else:
		var manager: Node = _manager()
		var latest: int = int(manager.call("get_latest_valid_slot")) if manager != null else 0
		_add_action(&"continue", "CONTINUE  " + _slot_label(_slot_summary(latest)) if latest > 0 else "CONTINUE  (NO VALID WATCH)")
		_add_action(&"new", "NEW WATCH")
		_add_action(&"load", "LOAD WATCH")
		_add_action(&"settings", "SETTINGS")
		_add_action(&"delete", "DELETE WATCH")
		if get_node(^"/root/UpdateChecker").get("status") == &"available":
			_add_action(&"update", "VIEW UPDATE ON GITHUB")
		_add_action(&"quit", "QUIT")
	var title: String = "WATCH PAUSED" if pause_mode else "WATCH CONTROL"
	if _page == &"new":
		title = "NEW WATCH - CHOOSE SLOT"
	elif _page == &"load":
		title = "LOAD WATCH"
	elif _page == &"overwrite":
		title = "REPLACE WATCH"
	elif _page == &"delete":
		title = "DELETE WATCH"
	elif _page == &"delete_confirm":
		title = "CONFIRM DELETION"
	_menu.setup(title, _actions)
	_menu.set_hint("WHEEL / ARROWS: BROWSE\nCLICK / WHEEL CLICK / ENTER: SELECT    ESC: BACK")
	_style_rows()


func _add_action(action: StringName, label: String) -> void:
	_ids.append(action)
	_actions.append(label)


func _quit_game() -> void:
	get_tree().quit()


func _on_update_checked() -> void:
	var checker: Node = get_node(^"/root/UpdateChecker")
	var tag: String = String(checker.get("installed_tag"))
	_version_label.text = ("VERSION %s\n" % tag if not tag.is_empty() else "") + String(checker.call("get_status_text"))
	if _page == &"root":
		var index: int = _menu.get_highlighted_index()
		var selected: StringName = _ids[index] if index >= 0 and index < _ids.size() else &"continue"
		_refresh()
		_menu.set_highlighted_index(maxi(0, _ids.find(selected)))


func _build_ui() -> void:
	_view = Control.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.02, 0.92 if not pause_mode else 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	if not pause_mode:
		_wordmark = Label.new()
		_wordmark.name = "Wordmark"
		_wordmark.text = "HULLWATCH"
		CrtPanel.style_label(_wordmark, CrtPanel.PHOSPHOR_GREEN)
		column.add_child(_wordmark)
		_subtitle = Label.new()
		_subtitle.text = "LONG-HAUL SHIP MAINTENANCE"
		_subtitle.add_theme_color_override("font_color", Color(0.72, 0.76, 0.7))
		column.add_child(_subtitle)
		var rule: HSeparator = HSeparator.new()
		rule.modulate = Color(0.45, 0.65, 0.5, 0.65)
		column.add_child(rule)
	_menu = ScrollMenu.new()
	column.add_child(_menu)
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.025, 0.045, 0.035, 0.96)
	panel.border_color = Color(0.35, 0.55, 0.4)
	panel.set_border_width_all(1)
	panel.set_content_margin_all(22.0)
	_menu.add_theme_stylebox_override("panel", panel)
	var heading: Label = _menu.get_node(^"Column/MenuTitle") as Label
	CrtPanel.style_label(heading, CrtPanel.PHOSPHOR_AMBER)
	var hint: Label = _menu.get_node(^"Column/Hint") as Label
	hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.7))
	_menu.option_selected.connect(select_action)
	_message = Label.new()
	_message.custom_minimum_size = Vector2(420.0, 50.0)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_size_override("font_size", UiScale.size(self, 14))
	CrtPanel.style_label(_message, CrtPanel.PHOSPHOR_AMBER)
	column.add_child(_message)
	if not pause_mode:
		_version_label = Label.new()
		_version_label.name = "BuildVersion"
		_version_label.custom_minimum_size.x = 420.0
		_version_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_version_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.7))
		column.add_child(_version_label)
	CrtPanel.add_overlay(_menu)
	UiScale.connect_settings(self, _on_ui_scale_changed)
	_on_ui_scale_changed(&"ui_scale", null)


func _style_rows() -> void:
	for row: Node in _menu.get_node(^"Column/Options").get_children():
		if row is Label and not row.is_queued_for_deletion():
			(row as Label).custom_minimum_size.y = float(UiScale.size(self, 32))


func _on_ui_scale_changed(key: StringName, _value: Variant) -> void:
	if key == &"ui_scale":
		_message.add_theme_font_size_override("font_size", UiScale.size(self, 14))
		if _wordmark != null:
			_wordmark.add_theme_font_size_override("font_size", UiScale.size(self, 44))
			_subtitle.add_theme_font_size_override("font_size", UiScale.size(self, 14))
			_version_label.add_theme_font_size_override("font_size", UiScale.size(self, 12))
		_style_rows()
