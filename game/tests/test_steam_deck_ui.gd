extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var settings: Node = root.get_node("GameSettings")
	settings.call("set_value", &"ui_scale", 1.0)
	var binder: ManualBinder = ManualBinder.new()
	binder.book = load("res://src/data/manual/manual_book.tres") as ManualBook
	root.add_child(binder)
	binder.interact(null)
	for page: int in binder.get_page_count():
		binder.get_menu().set_highlighted_index(page)
		await process_frame
		await process_frame
		var panel: Control = binder.get("_root") as Control
		_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(panel.get_global_rect()), "manual page %d fits 1280x800" % page)
	var scroll: ScrollContainer = binder.get("_content_scroll") as ScrollContainer
	binder.get_menu().set_highlighted_index(0)
	await process_frame
	await process_frame
	var down: InputEventKey = InputEventKey.new()
	down.keycode = KEY_PAGEDOWN
	down.pressed = true
	binder._unhandled_input(down)
	await process_frame
	_check(scroll.scroll_vertical > 0, "PageDown scrolls manual body")
	down.keycode = KEY_PAGEUP
	binder._unhandled_input(down)
	_check(scroll.scroll_vertical == 0, "PageUp returns to top")
	down.keycode = KEY_ENTER
	_check(not PanelDismiss.scroll_readout(down, scroll), "Enter stays available to menus")
	var dismiss: InputEventAction = InputEventAction.new()
	dismiss.action = &"interact"
	dismiss.pressed = true
	binder._unhandled_input(dismiss)
	_check(not binder.is_open(), "E closes the manual")
	binder.free()
	var guide: GuideOverlay = GuideOverlay.new()
	root.add_child(guide)
	_check(guide.layer < 12, "diegetic readouts draw above orientation overlay")
	guide.free()
	var terminal: ComputerTerminal = ComputerTerminal.new()
	root.add_child(terminal)
	terminal.interact(null)
	var content: Label = terminal.get("_content") as Label
	content.text = "long readout\n".repeat(100)
	await process_frame
	await process_frame
	down.keycode = KEY_PAGEDOWN
	terminal._unhandled_input(down)
	await process_frame
	scroll = terminal.get("_content_scroll") as ScrollContainer
	_check(scroll.scroll_vertical > 0, "PageDown scrolls ordinary terminal body")
	terminal.free()
	print("%s: test_steam_deck_ui" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		print("FAIL: ", label)
		_failures += 1
