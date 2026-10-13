extends Node

signal check_finished
signal download_progressed(received_bytes: int, total_bytes: int)

const API_URL: String = "https://api.github.com/repos/Mangekyo-Sharingan/hullwatch/releases?per_page=100"
const RELEASE_BASE: String = "https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/"
const DOWNLOAD_BASE: String = "https://github.com/Mangekyo-Sharingan/hullwatch/releases/download/"
const IDENTITY_PATH: String = "res://src/data/build_version.json"
const MAX_PAYLOAD: int = 1024 * 1024 * 1024
const MAX_MANIFEST: int = 65536
const UPDATE_EXIT_CODE: int = 42

var installed_tag: String = ""
var source_commit: String = ""
var latest_tag: String = ""
var release_url: String = ""
var status: StringName = &"development"
var channel: String = "windows"
var manifest: Dictionary = {}
var last_error: String = ""
var _checked: bool = false
var _request: HTTPRequest
var _kind: StringName = &"releases"
var _manifest_record: Dictionary = {}
var _redirects: int = 0
var _job: int = 0
var _received: int = 0
var _progress_timer: Timer
var _lock_owned: bool = false
var _handed_off: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	channel = "steamdeck" if OS.has_feature("steam_deck") else "windows"
	if FileAccess.file_exists(IDENTITY_PATH):
		var identity: JSON = JSON.new()
		if identity.parse(FileAccess.get_file_as_string(IDENTITY_PATH)) == OK and identity.data is Dictionary:
			if identity.data.get("release_tag") is String:
				installed_tag = identity.data["release_tag"]
			if identity.data.get("source_commit") is String:
				source_commit = identity.data["source_commit"]
	if not parse_tag(installed_tag).is_empty():
		status = &"unchecked"
	if _runtime_install_allowed():
		_register_instance()
		check_updates()


func _exit_tree() -> void:
	if _request != null:
		_request.cancel_request()
	if not _handed_off:
		_release_lock()
	var marker: String = _stage_dir().path_join("running/%d" % OS.get_process_id())
	if _safe_stage() and FileAccess.file_exists(marker):
		DirAccess.remove_absolute(marker)


func check_updates() -> void:
	if _checked:
		return
	_checked = true
	var version: Dictionary = parse_tag(installed_tag)
	if version.is_empty() or version["channel"] not in ["stable", channel]:
		_complete(&"development")
		return
	_job += 1
	status = &"checking"
	_begin_request(API_URL, &"releases", 2 * 1024 * 1024, 8.0)


func _begin_request(url: String, kind: StringName, limit: int, timeout: float, file: String = "") -> void:
	_dispose_request()
	_kind = kind
	_request = HTTPRequest.new()
	_request.timeout = timeout
	_request.body_size_limit = limit
	_request.max_redirects = 0
	_request.use_threads = true
	_request.accept_gzip = false
	_request.download_file = file
	add_child(_request)
	_request.request_completed.connect(_on_request_completed.bind(_job))
	var error: Error = _request.request(url, PackedStringArray([
		"Accept: application/vnd.github+json" if kind == &"releases" else "Accept: application/octet-stream",
		"Accept-Encoding: identity", "User-Agent: Hullwatch", "X-GitHub-Api-Version: 2022-11-28"
	]))
	if error != OK:
		_request_failed("connection_failed")


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, generation: int = -1) -> void:
	if generation >= 0 and generation != _job:
		return
	if _kind != &"releases" and response_code in [301, 302, 303, 307, 308]:
		var location: String = ""
		for header: String in headers:
			if header.to_lower().begins_with("location:"):
				location = header.substr(9).strip_edges()
		if _redirects >= 4 or not allowed_asset_redirect(location):
			_request_failed("redirect_refused")
			return
		_redirects += 1
		_begin_request(location, _kind, int(manifest["payload"]["size"]) if _kind == &"payload" else MAX_MANIFEST, 900.0 if _kind == &"payload" else 8.0, _stage_dir().path_join("download.part") if _kind == &"payload" else "")
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_request_failed("download_failed" if _kind == &"payload" else "check_unavailable")
		return
	if _kind == &"payload":
		_dispose_request()
		_stop_progress()
		status = &"verifying"
		check_finished.emit()
		await _verify_and_install(_job)
		return
	var decoded: JSON = JSON.new()
	if decoded.parse(body.get_string_from_utf8()) != OK:
		_request_failed("invalid_response")
		return
	if _kind == &"manifest":
		if body.size() != int(_manifest_record["manifest_size"]) or sha256_bytes(body) != _manifest_record["manifest_sha256"]:
			_request_failed("manifest_hash_mismatch")
			return
		manifest = validate_manifest(decoded.data, latest_tag, channel)
		if manifest.is_empty() or manifest["payload"]["sha256"] != _manifest_record["payload_sha256"] or int(manifest["payload"]["size"]) != int(_manifest_record["payload_size"]):
			manifest.clear()
			_request_failed("manifest_refused")
			return
		_complete(&"available")
		return
	if not decoded.data is Array:
		_complete(&"unavailable")
		return
	var release: Dictionary = select_release(decoded.data, installed_tag, channel)
	if release.is_empty():
		_complete(&"unavailable")
		return
	latest_tag = release["tag"]
	release_url = RELEASE_BASE + latest_tag
	if is_newer(latest_tag, installed_tag) and not String(release.get("manifest_url", "")).is_empty():
		_manifest_record = release
		_redirects = 0
		status = &"checking_manifest"
		_begin_request(release["manifest_url"], &"manifest", MAX_MANIFEST, 8.0)
		return
	_complete(&"available" if is_newer(latest_tag, installed_tag) else &"current")


func _dispose_request() -> void:
	if _request != null:
		_request.cancel_request()
		remove_child(_request)
		_request.queue_free()
		_request = null


func _complete(next_status: StringName) -> void:
	status = next_status
	_dispose_request()
	check_finished.emit()


func _request_failed(reason: String) -> void:
	last_error = reason
	if _kind == &"payload":
		_fail(reason)
	else:
		_complete(&"available" if _kind == &"manifest" else &"unavailable")


func can_download() -> bool:
	return not manifest.is_empty() and status in [&"available", &"failed"]


func start_update() -> void:
	if not can_download() or not _runtime_install_allowed() or not _may_restart():
		return
	last_error = ""
	var directory: DirAccess = DirAccess.open(_executable_path().get_base_dir())
	var current: FileAccess = FileAccess.open(_executable_path(), FileAccess.READ)
	if directory == null or current == null:
		_fail("installation_unavailable")
		return
	var required: int = int(manifest["payload"]["size"]) + current.get_length() + 16 * 1024 * 1024
	current.close()
	if directory.get_space_left() < required:
		_fail("not_enough_disk_space")
		return
	if not _acquire_lock():
		_fail("install_folder_unwritable_or_update_busy")
		return
	_job += 1
	_received = 0
	_redirects = 0
	status = &"downloading"
	check_finished.emit()
	_progress_timer = Timer.new()
	_progress_timer.wait_time = 0.2
	_progress_timer.timeout.connect(_emit_progress)
	add_child(_progress_timer)
	_progress_timer.start()
	# ponytail: interrupted transfers restart in full; add HTTP Range only if playtest bandwidth warrants it.
	_begin_request(manifest["payload"]["url"], &"payload", int(manifest["payload"]["size"]), 900.0, _stage_dir().path_join("download.part"))


func cancel_update() -> void:
	if status not in [&"downloading", &"verifying"]:
		return
	_job += 1
	_dispose_request()
	_stop_progress()
	_release_lock()
	_complete(&"available")


func _emit_progress() -> void:
	if _request != null and not manifest.is_empty():
		_received = _request.get_downloaded_bytes()
		download_progressed.emit(_received, int(manifest["payload"]["size"]))


func _stop_progress() -> void:
	if _progress_timer != null:
		_progress_timer.stop()
		_progress_timer.queue_free()
		_progress_timer = null


func _verify_and_install(generation: int) -> void:
	var file: FileAccess = FileAccess.open(_stage_dir().path_join("download.part"), FileAccess.READ)
	if file == null or file.get_length() != int(manifest["payload"]["size"]):
		_fail("size_mismatch")
		return
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		if generation != _job:
			file.close()
			return
		var bytes: PackedByteArray = file.get_buffer(mini(1024 * 1024, file.get_length() - file.get_position()))
		if bytes.is_empty() or hash.update(bytes) != OK:
			file.close()
			_fail("read_failed")
			return
		await get_tree().process_frame
	file.close()
	if generation != _job:
		return
	if hash.finish().hex_encode() != manifest["payload"]["sha256"]:
		_fail("checksum_mismatch")
		return
	var payload: String = _stage_dir().path_join("payload")
	if FileAccess.file_exists(payload):
		DirAccess.remove_absolute(payload)
	if DirAccess.rename_absolute(_stage_dir().path_join("download.part"), payload) != OK or not _may_restart():
		_fail("staging_failed")
		return
	status = &"installing"
	check_finished.emit()
	if not _handoff_installation():
		_fail("installer_start_failed")


func _handoff_installation() -> bool:
	var extension: String = "sh" if channel == "steamdeck" else "ps1"
	var helper: String = _stage_dir().path_join("apply_update." + extension)
	if not _write_text(helper, FileAccess.get_file_as_string("res://tools/updater/apply_update." + extension)):
		return false
	if not _write_text(_stage_dir().path_join("pending.json"), JSON.stringify(manifest)) or not _write_text(_stage_dir().path_join("handoff"), "ready\n"):
		return false
	var payload: String = _stage_dir().path_join("payload")
	var digest: String = manifest["payload"]["sha256"]
	var size: String = str(int(manifest["payload"]["size"]))
	if channel == "steamdeck" and OS.get_environment("HULLWATCH_LAUNCHER_ACTIVE") == "1":
		if not _write_text(_stage_dir().path_join("launcher-request"), digest + "\n" + size + "\n"):
			return false
		_handed_off = true
		get_tree().quit(UPDATE_EXIT_CODE)
		return true
	var pid: int = -1
	if channel == "windows":
		var args_path: String = _stage_dir().path_join("restart_args.json")
		if not _write_text(args_path, JSON.stringify(OS.get_cmdline_args())):
			return false
		var powershell: String = OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
		pid = OS.create_process(powershell, PackedStringArray(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", helper, "-Target", _executable_path(), "-Payload", payload, "-Sha256", digest, "-Size", size, "-WaitPid", str(OS.get_process_id()), "-RestartArgsJson", args_path]))
	else:
		var args: PackedStringArray = PackedStringArray([helper, _executable_path(), payload, digest, size, str(OS.get_process_id()), "--"])
		args.append_array(OS.get_cmdline_args())
		pid = OS.create_process("/bin/sh", args)
	if pid <= 0:
		return false
	_handed_off = true
	get_tree().quit()
	return true


func _fail(reason: String) -> void:
	last_error = reason
	_dispose_request()
	_stop_progress()
	_release_lock()
	_complete(&"failed")


func _executable_path() -> String:
	return OS.get_executable_path()


func _stage_dir() -> String:
	return _executable_path().get_base_dir().path_join(".hullwatch-update")


func _runtime_install_allowed() -> bool:
	return not OS.has_feature("editor") and DisplayServer.get_name() != "headless" and not installed_tag.is_empty()


func _may_restart() -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://scenes/main_menu.tscn"


func _safe_stage() -> bool:
	var parent: DirAccess = DirAccess.open(_executable_path().get_base_dir())
	return parent != null and not parent.is_link(_executable_path().get_file()) and not parent.is_link(".hullwatch-update")


func _acquire_lock() -> bool:
	if not _safe_stage() or DirAccess.make_dir_recursive_absolute(_stage_dir()) != OK:
		return false
	for name: String in ["download.part", "payload", "download.lock", "running", "apply_update.sh", "apply_update.ps1", "pending.json", "launcher-request", "handoff", "restart_args.json"]:
		if DirAccess.open(_stage_dir()).is_link(name):
			return false
	var running: DirAccess = DirAccess.open(_stage_dir().path_join("running"))
	if running != null:
		for name: String in running.get_files():
			if name.is_valid_int() and int(name) != OS.get_process_id() and _process_exists(int(name)):
				return false
	if FileAccess.file_exists(_stage_dir().path_join("handoff")):
		return false
	var lock: String = _stage_dir().path_join("download.lock")
	if DirAccess.dir_exists_absolute(lock):
		var owner: String = FileAccess.get_file_as_string(lock.path_join("owner_pid")).strip_edges() if FileAccess.file_exists(lock.path_join("owner_pid")) else ""
		if not owner.is_valid_int() or _process_exists(int(owner)):
			return false
		DirAccess.remove_absolute(lock.path_join("owner_pid"))
		DirAccess.remove_absolute(lock)
	if DirAccess.make_dir_absolute(lock) != OK:
		return false
	_lock_owned = _write_text(lock.path_join("owner_pid"), str(OS.get_process_id()))
	return _lock_owned


func _release_lock() -> void:
	if not _lock_owned or _handed_off:
		return
	var lock: String = _stage_dir().path_join("download.lock")
	DirAccess.remove_absolute(lock.path_join("owner_pid"))
	DirAccess.remove_absolute(_stage_dir().path_join("handoff"))
	DirAccess.remove_absolute(lock)
	_lock_owned = false


func _register_instance() -> void:
	if _safe_stage() and not DirAccess.open(_executable_path().get_base_dir()).is_link(".hullwatch-update/running") and DirAccess.make_dir_recursive_absolute(_stage_dir().path_join("running")) == OK:
		_write_text(_stage_dir().path_join("running/%d" % OS.get_process_id()), installed_tag)


static func _process_exists(pid: int) -> bool:
	if pid == OS.get_process_id():
		return true
	if pid <= 0:
		return false
	# Godot's is_process_running only accepts its own spawned children.
	if not OS.has_feature("windows"):
		return DirAccess.dir_exists_absolute("/proc/%d" % pid)
	var output: Array = []
	var result: int = OS.execute(OS.get_environment("SystemRoot").path_join("System32/tasklist.exe"), PackedStringArray(["/FI", "PID eq %d" % pid, "/FO", "CSV", "/NH"]), output, true)
	return result != 0 or (not output.is_empty() and String(output[0]).contains('"%d"' % pid))


func acknowledge_startup() -> void:
	if not _runtime_install_allowed() or not _safe_stage():
		return
	var path: String = _stage_dir().path_join("pending.json")
	if not FileAccess.file_exists(path):
		return
	var pending: JSON = JSON.new()
	if pending.parse(FileAccess.get_file_as_string(path)) == OK and pending.data is Dictionary and pending.data.get("release_tag") == installed_tag:
		_write_text(_stage_dir().path_join("startup-ok"), installed_tag)
		_write_text(_stage_dir().path_join("installed.json"), JSON.stringify(pending.data, "\t"))
		DirAccess.remove_absolute(_stage_dir().path_join("handoff"))
		DirAccess.remove_absolute(_stage_dir().path_join("pending"))


static func _write_text(path: String, text: String) -> bool:
	var directory: DirAccess = DirAccess.open(path.get_base_dir())
	if directory == null or directory.is_link(path.get_file()):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	return file.get_error() == OK


func get_status_text() -> String:
	match status:
		&"available":
			return "UPDATE AVAILABLE: %s" % latest_tag
		&"current":
			return "UP TO DATE"
		&"checking", &"unchecked", &"checking_manifest":
			return "CHECKING FOR UPDATES..."
		&"downloading":
			return "DOWNLOADING UPDATE: %d%%" % int(100.0 * _received / maxi(1, int(manifest["payload"]["size"])))
		&"verifying":
			return "VERIFYING UPDATE..."
		&"installing":
			return "RESTARTING TO INSTALL UPDATE..."
		&"failed":
			return "UPDATE FAILED — CURRENT BUILD KEPT\n" + last_error.replace("_", " ").to_upper()
		&"unavailable":
			return "UPDATE CHECK UNAVAILABLE — YOU CAN STILL PLAY"
	return "DEVELOPMENT BUILD"


static func sha256_bytes(bytes: PackedByteArray) -> String:
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()


static func allowed_asset_redirect(url: String) -> bool:
	var pattern: RegEx = RegEx.new()
	pattern.compile("^https://(github\\.com|release-assets\\.githubusercontent\\.com|objects\\.githubusercontent\\.com)/")
	return url.length() <= 8192 and not url.contains("\n") and not url.contains("\r") and pattern.search(url) != null


static func valid_digest(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	var pattern: RegEx = RegEx.new()
	pattern.compile("^[0-9a-f]{64}$")
	return pattern.search(value) != null


static func valid_size(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value > 0 and value <= maximum


static func validate_manifest(value: Variant, tag: String, platform_channel: String) -> Dictionary:
	if not value is Dictionary or not valid_size(value.get("schema_version"), 1) or not valid_size(value.get("minimum_updater"), 1) or value.get("release_tag") != tag or value.get("channel") != platform_channel:
		return {}
	var version: Dictionary = parse_tag(tag)
	if version.is_empty() or version["channel"] not in ["stable", platform_channel] or not value.get("source_commit") is String:
		return {}
	var commit: String = value["source_commit"]
	if commit.length() != 40 or not commit.is_valid_hex_number(false):
		return {}
	var payload: Variant = value.get("payload")
	var name: String = "Hullwatch.x86_64" if platform_channel == "steamdeck" else "Hullwatch.exe"
	if not payload is Dictionary or payload.get("name") != name or payload.get("url") != DOWNLOAD_BASE + tag + "/" + name or not valid_size(payload.get("size"), MAX_PAYLOAD) or not valid_digest(payload.get("sha256")):
		return {}
	return value.duplicate(true)


static func parse_tag(tag: String) -> Dictionary:
	var pattern: RegEx = RegEx.new()
	pattern.compile("^v([0-9]{1,6})\\.([0-9]{1,6})\\.([0-9]{1,6})(?:-(steamdeck-)?playtest\\.([0-9]{8})\\.([0-9]{1,6}))?$")
	var matched: RegExMatch = pattern.search(tag)
	if matched == null or matched.get_string(0) != tag:
		return {}
	var stable: bool = matched.get_string(5).is_empty()
	var rank: Array[int] = [int(matched.get_string(1)), int(matched.get_string(2)), int(matched.get_string(3)), 1 if stable else 0, int(matched.get_string(5)), int(matched.get_string(6))]
	return {"rank": rank, "channel": "stable" if stable else "steamdeck" if not matched.get_string(4).is_empty() else "windows"}


static func is_newer(candidate: String, installed: String) -> bool:
	var a: Dictionary = parse_tag(candidate)
	var b: Dictionary = parse_tag(installed)
	if a.is_empty() or b.is_empty():
		return false
	for index: int in 6:
		if a["rank"][index] != b["rank"][index]:
			return a["rank"][index] > b["rank"][index]
	return false


static func select_release(releases: Array, installed: String, platform_channel: String) -> Dictionary:
	var local: Dictionary = parse_tag(installed)
	if local.is_empty() or local["channel"] not in ["stable", platform_channel]:
		return {}
	var best: String = ""
	# ponytail: first 100 releases; paginate if a platform's newest package falls outside that window.
	for value: Variant in releases:
		if not value is Dictionary or not value.get("draft") is bool or value["draft"] or not value.get("tag_name") is String:
			continue
		var tag: String = value["tag_name"]
		var version: Dictionary = parse_tag(tag)
		if version.is_empty() or version["channel"] not in ["stable", platform_channel]:
			continue
		if not value.get("prerelease") is bool or value["prerelease"] != (version["channel"] != "stable"):
			continue
		if not _has_package(value.get("assets"), platform_channel):
			continue
		if best.is_empty() or is_newer(tag, best):
			best = tag
	if best.is_empty():
		return {}
	var selected: Dictionary = {"tag": best}
	for value: Variant in releases:
		if value is Dictionary and value.get("tag_name") == best and value.get("assets") is Array:
			var metadata: Dictionary = _asset_digest(value["assets"], "UPDATE_" + platform_channel.to_upper() + ".json", MAX_MANIFEST)
			var payload: Dictionary = _asset_digest(value["assets"], "Hullwatch.x86_64" if platform_channel == "steamdeck" else "Hullwatch.exe", MAX_PAYLOAD)
			if not metadata.is_empty() and not payload.is_empty():
				selected.merge({"manifest_url": DOWNLOAD_BASE + best + "/UPDATE_" + platform_channel.to_upper() + ".json", "manifest_size": metadata["size"], "manifest_sha256": metadata["sha256"], "payload_size": payload["size"], "payload_sha256": payload["sha256"]})
	return selected


static func _asset_digest(assets: Array, name: String, maximum: int) -> Dictionary:
	for value: Variant in assets:
		if not value is Dictionary or value.get("name") != name or value.get("state") != "uploaded" or not value.get("digest") is String or not valid_size(value.get("size"), maximum):
			continue
		var digest: String = value["digest"]
		if digest.begins_with("sha256:") and valid_digest(digest.substr(7)):
			return {"size": int(value["size"]), "sha256": digest.substr(7)}
	return {}


static func _has_package(assets: Variant, platform_channel: String) -> bool:
	if not assets is Array:
		return false
	var names: PackedStringArray = PackedStringArray(["Hullwatch-SteamDeck.tar.gz"] if platform_channel == "steamdeck" else ["Hullwatch.exe", "Hullwatch-Windows.zip"])
	for asset: Variant in assets:
		if not asset is Dictionary or not asset.get("name") is String or asset["name"] not in names or asset.get("state") != "uploaded":
			continue
		var size: Variant = asset.get("size")
		if (size is int or size is float) and size > 0:
			return true
	return false
