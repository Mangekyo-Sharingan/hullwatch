extends SceneTree

const CHECKER: Script = preload("res://src/autoload/update_checker.gd")
const OLD: String = "v0.12.0-playtest.20261013.4"
const NEW: String = "v0.12.0-playtest.20261013.5"
var _bytes: PackedByteArray = PackedByteArray([65, 66, 67, 68])

class Fixture extends "res://src/autoload/update_checker.gd":
	var executable: String = ""
	var requests: Array[Dictionary] = []
	var handoffs: int = 0
	var menu_allowed: bool = true

	func _executable_path() -> String:
		return executable

	func _runtime_install_allowed() -> bool:
		return not executable.is_empty()

	func _may_restart() -> bool:
		return menu_allowed

	func _begin_request(url: String, kind: StringName, limit: int, timeout: float, file: String = "") -> void:
		_kind = kind
		requests.append({"url": url, "kind": kind, "limit": limit, "timeout": timeout, "file": file, "generation": _job})

	func _handoff_installation() -> bool:
		handoffs += 1
		return true

var _failures: int = 0
var _counter: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_schema()
	_test_redirects()
	await _test_pipeline()
	await _test_payload_failures()
	await _test_cancellation_and_locks()
	print("PASS: test_manifest_updater" if _failures == 0 else "FAILURES: %d" % _failures)
	quit(0 if _failures == 0 else 1)


func _definition() -> Dictionary:
	return {"schema_version": 1, "minimum_updater": 1, "release_tag": NEW, "channel": "windows", "source_commit": "a".repeat(40), "payload": {"name": "Hullwatch.exe", "url": CHECKER.DOWNLOAD_BASE + NEW + "/Hullwatch.exe", "size": _bytes.size(), "sha256": CHECKER.sha256_bytes(_bytes)}}


func _test_schema() -> void:
	var valid: Dictionary = _definition()
	_check(not CHECKER.validate_manifest(valid, NEW, "windows").is_empty(), "exact platform/release manifest accepted")
	for key: String in ["schema_version", "minimum_updater", "release_tag", "channel", "source_commit", "payload"]:
		var bad: Dictionary = valid.duplicate(true)
		bad[key] = null
		_check(CHECKER.validate_manifest(bad, NEW, "windows").is_empty(), "missing/invalid manifest field rejected: " + key)
	for size: Variant in [0, -1, 1.5, "4", true, CHECKER.MAX_PAYLOAD + 1]:
		var bad: Dictionary = valid.duplicate(true)
		bad["payload"]["size"] = size
		_check(CHECKER.validate_manifest(bad, NEW, "windows").is_empty(), "invalid payload byte count rejected")
	for url: String in ["http://github.com/a", "https://github.com.evil/a", "file:///tmp/payload", CHECKER.DOWNLOAD_BASE + OLD + "/Hullwatch.exe"]:
		var bad: Dictionary = valid.duplicate(true)
		bad["payload"]["url"] = url
		_check(CHECKER.validate_manifest(bad, NEW, "windows").is_empty(), "untrusted or wrong-version payload URL rejected")
	_check(CHECKER.validate_manifest(valid, NEW, "steamdeck").is_empty(), "cross-platform manifest refused")
	valid["schema_version"] = true
	_check(CHECKER.validate_manifest(valid, NEW, "windows").is_empty(), "boolean protocol version refused")


func _test_redirects() -> void:
	_check(CHECKER.allowed_asset_redirect("https://release-assets.githubusercontent.com/path?token=x"), "GitHub asset CDN allowed")
	for url: String in ["http://release-assets.githubusercontent.com/x", "https://release-assets.githubusercontent.com.evil/x", "https://user@github.com/x", "https://github.com:444/x", "https://evil/x", "/relative", "https://github.com/\n"]:
		_check(not CHECKER.allowed_asset_redirect(url), "unsafe redirect rejected")


func _fixture() -> Fixture:
	_counter += 1
	var node: Fixture = Fixture.new()
	var folder: String = ProjectSettings.globalize_path("user://updater_fixture/%d" % _counter)
	DirAccess.make_dir_recursive_absolute(folder)
	node.executable = folder.path_join("Hullwatch.exe")
	var file: FileAccess = FileAccess.open(node.executable, FileAccess.WRITE)
	file.store_string("old build")
	file.close()
	root.add_child(node)
	node.installed_tag = OLD
	node.channel = "windows"
	node.latest_tag = NEW
	node._checked = false
	return node


func _test_pipeline() -> void:
	var node: Fixture = _fixture()
	var bytes: PackedByteArray = JSON.stringify(_definition()).to_utf8_buffer()
	var assets: Array = [{"name": "Hullwatch.exe", "size": _bytes.size(), "state": "uploaded", "digest": "sha256:" + CHECKER.sha256_bytes(_bytes)}, {"name": "UPDATE_WINDOWS.json", "size": bytes.size(), "state": "uploaded", "digest": "sha256:" + CHECKER.sha256_bytes(bytes)}]
	node.check_updates()
	node._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify([{"tag_name": NEW, "draft": false, "prerelease": true, "assets": assets}]).to_utf8_buffer())
	_check(node.status == &"checking_manifest" and node.requests.back()["url"] == CHECKER.DOWNLOAD_BASE + NEW + "/UPDATE_WINDOWS.json", "new compatible release fetches platform manifest")
	node._on_request_completed(HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED, 302, PackedStringArray(["Location: https://release-assets.githubusercontent.com/manifest"]), PackedByteArray())
	_check(node.requests.back()["url"] == "https://release-assets.githubusercontent.com/manifest", "redirect limit result handled before success guard")
	node._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), bytes)
	_check(node.can_download(), "authenticated manifest enables client update")
	node.start_update()
	_check(node.status == &"downloading" and node.requests.back()["timeout"] > 8.0 and String(node.requests.back()["file"]).ends_with("download.part"), "download streams into staging with separate timeout")
	var file: FileAccess = FileAccess.open(node._stage_dir().path_join("download.part"), FileAccess.WRITE)
	file.store_buffer(_bytes)
	file.close()
	node._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
	await process_frame
	await process_frame
	_check(node.handoffs == 1 and node.status == &"installing", "verified payload hands off exactly once")
	_check(FileAccess.get_file_as_string(node.executable) == "old build", "download/verifier never replaces running executable")
	_check(FileAccess.get_file_as_bytes(node._stage_dir().path_join("payload")) == _bytes, "complete verified payload staged")
	node.free()


func _test_payload_failures() -> void:
	for wrong: PackedByteArray in [PackedByteArray([65]), PackedByteArray([65, 66, 67, 99])]:
		var node: Fixture = _fixture()
		node.manifest = _definition()
		node.status = &"available"
		node.start_update()
		var file: FileAccess = FileAccess.open(node._stage_dir().path_join("download.part"), FileAccess.WRITE)
		file.store_buffer(wrong)
		file.close()
		node._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
		await process_frame
		await process_frame
		_check(node.status == &"failed" and node.handoffs == 0 and FileAccess.get_file_as_string(node.executable) == "old build", "short/corrupted payload preserves old installation")
		node.free()


func _test_cancellation_and_locks() -> void:
	var node: Fixture = _fixture()
	node.manifest = _definition()
	node.status = &"available"
	node.start_update()
	var generation: int = node._job
	node.cancel_update()
	node._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray(), generation)
	_check(node.status == &"available" and node.handoffs == 0, "late callback after cancellation cannot install")
	DirAccess.make_dir_recursive_absolute(node._stage_dir().path_join("download.lock"))
	CHECKER._write_text(node._stage_dir().path_join("download.lock/owner_pid"), str(OS.get_process_id()))
	node.start_update()
	_check(node.status == &"failed" and node.handoffs == 0, "another live update lock cannot be overwritten")
	node.free()


func _check(passed: bool, message: String) -> void:
	if passed:
		print("PASS: ", message)
	else:
		_failures += 1
		print("FAIL: ", message)
