extends Node

signal check_finished

const API_URL: String = "https://api.github.com/repos/Mangekyo-Sharingan/hullwatch/releases?per_page=100"
const RELEASE_BASE: String = "https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/"
const IDENTITY_PATH: String = "res://src/data/build_version.json"

var installed_tag: String = ""
var latest_tag: String = ""
var release_url: String = ""
var status: StringName = &"development"
var channel: String = "windows"
var _checked: bool = false
var _request: HTTPRequest


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	channel = "steamdeck" if OS.has_feature("steam_deck") else "windows"
	if FileAccess.file_exists(IDENTITY_PATH):
		var identity: Variant = JSON.parse_string(FileAccess.get_file_as_string(IDENTITY_PATH))
		if identity is Dictionary and identity.get("release_tag") is String:
			installed_tag = identity["release_tag"]
	if not parse_tag(installed_tag).is_empty():
		status = &"unchecked"
	if not OS.has_feature("editor") and DisplayServer.get_name() != "headless":
		check_updates()


func check_updates() -> void:
	if _checked:
		return
	_checked = true
	var version: Dictionary = parse_tag(installed_tag)
	if version.is_empty() or version["channel"] not in ["stable", channel]:
		_complete(&"development")
		return
	status = &"checking"
	_request = HTTPRequest.new()
	_request.timeout = 8.0
	_request.body_size_limit = 2 * 1024 * 1024
	_request.max_redirects = 0
	_request.use_threads = true
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)
	var error: Error = _request.request(API_URL, PackedStringArray([
		"Accept: application/vnd.github+json", "User-Agent: Hullwatch", "X-GitHub-Api-Version: 2022-11-28"
	]))
	if error != OK:
		_complete(&"unavailable")


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_complete(&"unavailable")
		return
	var decoded: JSON = JSON.new()
	if decoded.parse(body.get_string_from_utf8()) != OK or not decoded.data is Array:
		_complete(&"unavailable")
		return
	var release: Dictionary = select_release(decoded.data, installed_tag, channel)
	if release.is_empty():
		_complete(&"unavailable")
		return
	latest_tag = release["tag"]
	release_url = RELEASE_BASE + latest_tag
	_complete(&"available" if is_newer(latest_tag, installed_tag) else &"current")


func _complete(next_status: StringName) -> void:
	status = next_status
	if _request != null:
		_request.queue_free()
		_request = null
	check_finished.emit()


func get_status_text() -> String:
	match status:
		&"available":
			return "UPDATE AVAILABLE: %s" % latest_tag
		&"current":
			return "UP TO DATE"
		&"checking", &"unchecked":
			return "CHECKING FOR UPDATES..."
		&"unavailable":
			return "UPDATE CHECK UNAVAILABLE — YOU CAN STILL PLAY"
	return "DEVELOPMENT BUILD"


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
	return {"tag": best} if not best.is_empty() else {}


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
