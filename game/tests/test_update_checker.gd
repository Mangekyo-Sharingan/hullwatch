extends SceneTree

const CHECKER: Script = preload("res://src/autoload/update_checker.gd")
const WINDOWS: String = "v0.12.0-playtest.20261013.2"
const DECK: String = "v0.12.0-steamdeck-playtest.20261013.1"
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(CHECKER.is_newer("v0.12.0-playtest.20261013.10", WINDOWS), "sequence numbers compare numerically")
	_check(CHECKER.is_newer("v0.12.0-playtest.20261014.1", WINDOWS), "later dated playtest wins")
	_check(CHECKER.is_newer("v0.13.0-playtest.20260101.1", WINDOWS), "base version takes precedence over date")
	_check(CHECKER.is_newer("v0.12.0", WINDOWS), "stable release supersedes same-base playtest")
	_check(not CHECKER.is_newer("v0.11.0", WINDOWS), "older stable does not supersede playtest")
	_check(not CHECKER.is_newer(WINDOWS, WINDOWS), "identical build has no update")
	for invalid: String in ["", "vnext", "v0.12.0-beta.2", WINDOWS + "\n", "v999999999999999999999.0.0", WINDOWS + "/../bad"]:
		_check(CHECKER.parse_tag(invalid).is_empty(), "invalid identity rejected: " + invalid.strip_edges())
	var windows: Dictionary = _release(WINDOWS, "windows")
	var deck: Dictionary = _release(DECK, "steamdeck")
	var newer: Dictionary = _release("v0.12.0-playtest.20261013.10", "windows")
	var candidates: Array = [deck, newer, _release("v0.11.0", "windows"), windows]
	_check(CHECKER.select_release(candidates, WINDOWS, "windows")["tag"] == newer["tag_name"], "Windows includes prereleases and ignores Deck")
	_check(CHECKER.select_release(candidates, DECK, "steamdeck")["tag"] == DECK, "Deck ignores Windows and incompatible stable assets")
	_check(CHECKER.select_release(candidates, DECK, "windows").is_empty(), "mismatched installed channel is inconclusive")
	var stable: Dictionary = _release("v0.12.0", "windows")
	candidates.append(stable)
	_check(CHECKER.select_release(candidates, WINDOWS, "windows")["tag"] == "v0.12.0", "stable package wins over matching-base playtest")
	var invalids: Array = [null, {}, "bad", _release("vnext", "windows")]
	var draft: Dictionary = newer.duplicate(true)
	draft["draft"] = true
	invalids.append(draft)
	var wrong_flag: Dictionary = newer.duplicate(true)
	wrong_flag["prerelease"] = false
	invalids.append(wrong_flag)
	for bad_assets: Variant in [null, {}, [], [null, {}, {"name": null}, {"name": 32}], [{"name": "Hullwatch.exe", "state": "new", "size": 20}], [{"name": "Hullwatch.exe", "state": "uploaded", "size": 0}], [{"name": "Hullwatch.exe", "state": "uploaded", "size": "20"}]]:
		var candidate: Dictionary = newer.duplicate(true)
		candidate["assets"] = bad_assets
		invalids.append(candidate)
	_check(CHECKER.select_release(invalids, WINDOWS, "windows").is_empty(), "drafts, malformed metadata and incomplete packages are ignored")
	await _test_menu_and_failures(newer)
	print("PASS: test_update_checker" if _failures == 0 else "FAILURES: %d" % _failures)
	quit(0 if _failures == 0 else 1)


func _test_menu_and_failures(newer: Dictionary) -> void:
	var checker: Node = root.get_node(^"UpdateChecker")
	_check(checker.get("status") in [&"development", &"unchecked"] and checker.get_child_count() == 0, "development/headless startup does not request GitHub")
	checker.set("installed_tag", WINDOWS)
	checker.set("channel", "windows")
	checker.set("status", &"checking")
	var menu: Node = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	var list: ScrollMenu = menu.call("get_menu") as ScrollMenu
	list.set_highlighted_index(5)
	checker.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify([newer]).to_utf8_buffer())
	await process_frame
	_check(checker.get("status") == &"available", "successful response offers newer release")
	_check(checker.get("release_url") == CHECKER.RELEASE_BASE + newer["tag_name"], "release URL comes from fixed repository and validated tag")
	_check((menu.call("get_actions") as PackedStringArray).has("VIEW UPDATE ON GITHUB"), "update action is accessible in ordinary menu controls")
	_check(list.get_highlighted_text() == "QUIT", "async completion preserves highlighted action")
	var label: Label = menu.get("_version_label") as Label
	_check(label.text.contains(WINDOWS) and label.text.contains("UPDATE AVAILABLE"), "menu shows installed build and available update")
	menu.call("select_action", 1)
	var actions: PackedStringArray = menu.call("get_actions") as PackedStringArray
	checker.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify([newer]).to_utf8_buffer())
	_check(menu.call("get_actions") == actions, "update status does not interrupt slot chooser")
	for response: Array in [[HTTPRequest.RESULT_TIMEOUT, 0, ""], [HTTPRequest.RESULT_SUCCESS, 403, "{}"], [HTTPRequest.RESULT_SUCCESS, 404, "{}"], [HTTPRequest.RESULT_SUCCESS, 200, "{broken"], [HTTPRequest.RESULT_SUCCESS, 200, "{}"], [HTTPRequest.RESULT_SUCCESS, 200, "[]"]]:
		checker.call("_on_request_completed", response[0], response[1], PackedStringArray(), String(response[2]).to_utf8_buffer())
		_check(checker.get("status") == &"unavailable" and bool(menu.call("is_menu_open")), "offline/rate limit/malformed/no-candidate response leaves menu playable")
	checker.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify([_release(WINDOWS, "windows")]).to_utf8_buffer())
	_check(checker.get("status") == &"current", "current release reports up to date")
	menu.free()
	checker.set("installed_tag", "")
	checker.set("status", &"development")
	checker.call("check_updates")
	checker.call("check_updates")
	_check(checker.get_child_count() == 0, "unknown identity never makes repeated startup requests")


func _release(tag: String, platform_channel: String) -> Dictionary:
	return {"tag_name": tag, "draft": false, "prerelease": tag.contains("-playtest.") or tag.contains("-steamdeck-playtest."), "assets": [{"name": "Hullwatch-SteamDeck.tar.gz" if platform_channel == "steamdeck" else "Hullwatch.exe", "state": "uploaded", "size": 100}]}


func _check(passed: bool, message: String) -> void:
	if passed:
		print("PASS: ", message)
	else:
		_failures += 1
		print("FAIL: ", message)
