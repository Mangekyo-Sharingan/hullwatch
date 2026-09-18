extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	for autoload_name: StringName in [&"EventBus", &"SimClock"]:
		var existing: Node = _find_root_child(autoload_name)
		if existing != null:
			root.remove_child(existing)
			existing.free()
	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	root.add_child(event_bus)
	var sim_clock: Node = load("res://src/autoload/sim_clock.gd").new()
	sim_clock.name = &"SimClock"
	root.add_child(sim_clock)

	_test_manual_book()
	_test_binder()
	_test_board()
	_test_log_terminal()

	_finish()


func _test_manual_book() -> void:
	var book: ManualBook = load("res://src/data/manual/manual_book.tres")
	_check(book != null, "manual book loads")
	if book == null:
		return
	_check(book.pages.size() == 6, "manual has six pages")
	_check(book.pages[0].title == "OPERATIONS", "operations page is first")
	_check(book.pages[5].title == "SYMPTOMS", "symptoms page is last")
	var total_chars: int = 0
	for page: ManualPage in book.pages:
		_check(not page.title.is_empty() and page.body.length() > 80, "page '%s' has substance" % page.title)
		total_chars += page.body.length()
	_check(total_chars > 1200, "manual content is substantive overall")


func _test_binder() -> void:
	var book: ManualBook = load("res://src/data/manual/manual_book.tres")
	var binder := ManualBinder.new()
	binder.book = book
	root.add_child(binder)

	_check(binder.get_interaction_prompt() == "Read manual", "binder invites a read when closed")
	binder.interact(null)
	_check(binder.is_open() and binder.get_current_page_title() == "OPERATIONS", "binder opens on the first page")
	var menu: ScrollMenu = binder.get_menu()
	_check(menu != null and menu.get_items().size() == 6, "binder menu lists every page")

	menu.move_selection(1)
	_check(binder.get_current_page_title() == "POWER", "browsing moves the highlighted page")
	_check("\n".join(binder.build_readout()).contains("POWER"), "readout follows the highlight")

	menu.confirm()
	_check(menu.get_selected_index() == 1, "wheel click selects the page")
	_check(binder.get_current_page_title() == "POWER", "selected page stays displayed")

	menu.move_selection(-2)
	_check(binder.get_current_page_title() == "SYMPTOMS", "browsing wraps around the page list")
	_check(binder.get_interaction_prompt() == "Close manual", "prompt offers close while open")

	binder.interact(null)
	_check(not binder.is_open(), "interact closes the manual")
	_check("\n".join(binder.build_readout()).is_empty(), "closed binder builds no readout")
	binder.free()


func _test_board() -> void:
	var board := MaintenanceBoard.new()
	root.add_child(board)
	_check(board.build_readout()[0] == "MAINTENANCE BOARD", "board readout has a header")
	_check(not board.is_open(), "board starts closed")

	var event_bus: Node = _find_root_child(&"EventBus")
	event_bus.call("emit_event", &"component_failed", {"component_id": &"rtg_main", "failure_mode_id": &"rtg_degraded"})
	event_bus.call("emit_event", &"stores_low", {"part_id": &"filter_co2", "new_count": 1})
	event_bus.call("emit_event", &"ignored_event", {})
	_check(board.get_entries().size() == 2, "board accumulates watched events only")
	_check(StringName(board.get_entries()[0]["name"]) == &"stores_low", "newest entry is first")

	board.interact(null)
	_check(board.is_open(), "board opens on interact")
	var text: String = "\n".join(board.build_readout())
	_check(text.contains("COMPONENT_FAILED") and text.contains("rtg_main"), "board names the failed component")
	_check(text.contains("STORES_LOW"), "board names the low-stock event")
	board.interact(null)
	_check(not board.is_open(), "board closes on second interact")
	board.free()


func _test_log_terminal() -> void:
	var entry: LogEntry = load("res://src/data/logs/log_01.tres")
	_check(entry != null and not entry.title.is_empty() and entry.body.length() > 120, "log entry loads with content")
	var terminal := LogTerminal.new()
	terminal.log_entry = entry
	root.add_child(terminal)
	_check(terminal.get_interaction_prompt() == "Read log", "terminal invites a read")
	terminal.interact(null)
	_check(terminal.is_open(), "terminal opens")
	var text: String = "\n".join(terminal.build_readout())
	_check(text.contains("VOSS"), "terminal shows the operator's name")
	_check(text.contains("filter count"), "log references the filter count")
	terminal.interact(null)
	_check(not terminal.is_open(), "terminal closes on second interact")
	terminal.free()


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_manual")
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
