## Extracts player-facing string literals into a CSV translation table for Godot's CSV importer.
## Re-run after changing UI prompts, manual pages, or log entries:
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/extract_strings.gd
## Keys are deterministic: <FILE_SLUG>_<SOURCE_INDEX>, where SOURCE_INDEX is the literal's 1-based
## position among the matched literals of that file. Values are CSV-quoted when needed and newlines
## are written as the two characters \n so each row stays on one line.
## Known limitations (see docs/LOCALIZATION.md): format strings containing % are skipped, so
## prompts like "Light O2 candle (%d left)" are not extracted yet; raw strings longer than 500
## characters are skipped; runtime-composed readouts (status panel, log terminal) are not extracted.
extends SceneTree

const OUTPUT_DIR: String = "res://assets/locale"
const OUTPUT_PATH: String = "res://assets/locale/strings.csv"
const MAX_LENGTH: int = 500
const SCAN_EXTENSIONS: Dictionary = {
	"res://src/ui": "gd",
	"res://src/interactables": "gd",
	"res://src/data/manual": "tres",
	"res://src/data/logs": "tres",
}
const TRES_KEYS: PackedStringArray = ["title", "body", "date_text"]
const TECHNICAL_MARKERS: PackedStringArray = ["res://", "user://", "/root/"]
const HEADER: String = "keys,en"

var _text_assignment_re: RegEx
var _literal_re: RegEx
var _tres_key_re: RegEx
var _identifier_re: RegEx
var _slug_re: RegEx


func _initialize() -> void:
	_compile_patterns()
	var files: Array[String] = _collect_files()
	if files.is_empty():
		print("FAIL: no source files found under the scan paths")
		quit(1)
		return
	var rows: Array[String] = [HEADER]
	var seen: Dictionary = {}
	for path: String in files:
		var slug: String = _slugify(path)
		var literals: Array[String] = _extract_literals(path)
		for index: int in range(literals.size()):
			var literal: String = literals[index]
			if not _is_extractable(literal) or seen.has(literal):
				continue
			seen[literal] = true
			rows.append("%s_%02d,%s" % [slug, index + 1, _csv_cell(_escape_newlines(literal))])
	if not _write_output("\n".join(rows) + "\n"):
		quit(1)
		return
	print("PASS: extract_strings (%d strings)" % (rows.size() - 1))
	quit(0)


func _compile_patterns() -> void:
	_text_assignment_re = RegEx.new()
	_text_assignment_re.compile("(?:^|[^A-Za-z0-9_])(?:_?text)\\s*=\\s*\"((?:\\\\.|[^\"\\\\])*)\"\\s*$")
	_literal_re = RegEx.new()
	_literal_re.compile("\"((?:\\\\.|[^\"\\\\])*)\"")
	_tres_key_re = RegEx.new()
	_tres_key_re.compile("^\\s*(?:" + "|".join(TRES_KEYS) + ")\\s*=\\s*\"")
	_identifier_re = RegEx.new()
	_identifier_re.compile("^[a-z_][a-z0-9_]*$")
	_slug_re = RegEx.new()
	_slug_re.compile("[^A-Z0-9]+")


func _collect_files() -> Array[String]:
	var files: Array[String] = []
	var dirs: Array[String] = []
	for key: Variant in SCAN_EXTENSIONS.keys():
		dirs.append(String(key))
	dirs.sort()
	for dir_path: String in dirs:
		_collect_dir(dir_path, String(SCAN_EXTENSIONS[dir_path]), files)
	files.sort()
	return files


func _collect_dir(dir_path: String, extension_filter: String, files: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(dir_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var entry_path: String = dir_path.path_join(entry)
			if directory.current_is_dir():
				_collect_dir(entry_path, extension_filter, files)
			elif entry.get_extension().to_lower() == extension_filter:
				files.append(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()


func _extract_literals(path: String) -> Array[String]:
	if path.get_extension().to_lower() == "tres":
		return _extract_from_tres(path)
	return _extract_from_gd(path)


func _extract_from_gd(path: String) -> Array[String]:
	var literals: Array[String] = []
	var in_prompt: bool = false
	for line: String in _read_text(path).split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("func "):
			in_prompt = stripped.begins_with("func get_interaction_prompt(")
			continue
		if in_prompt and stripped.begins_with("return"):
			literals.append_array(_literals_on_line(stripped))
			continue
		if stripped.begins_with("#"):
			continue
		var match: RegExMatch = _text_assignment_re.search(stripped)
		if match != null:
			literals.append(match.get_string(1))
	return literals


func _extract_from_tres(path: String) -> Array[String]:
	var literals: Array[String] = []
	var lines: PackedStringArray = _read_text(path).split("\n")
	var index: int = 0
	while index < lines.size():
		var match: RegExMatch = _tres_key_re.search(lines[index])
		if match == null:
			index += 1
			continue
		var remainder: String = lines[index].substr(match.get_end(0))
		var literal: String = ""
		var closed: bool = false
		while true:
			var closing: int = _find_closing_quote(remainder)
			if closing >= 0:
				literal += remainder.substr(0, closing)
				closed = true
				break
			literal += remainder + "\n"
			index += 1
			if index >= lines.size():
				break
			remainder = lines[index]
		if closed:
			literals.append(literal)
		index += 1
	return literals


func _literals_on_line(line: String) -> Array[String]:
	var literals: Array[String] = []
	for match: RegExMatch in _literal_re.search_all(line):
		var start: int = match.get_start(0)
		if start > 0 and line[start - 1] == "&":
			continue
		literals.append(match.get_string(1))
	return literals


func _find_closing_quote(text: String) -> int:
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\\":
			index += 2
			continue
		if character == "\"":
			return index
		index += 1
	return -1


func _is_extractable(literal: String) -> bool:
	if literal.length() < 2 or literal.length() > MAX_LENGTH:
		return false
	if literal.contains("%"):
		return false
	for marker: String in TECHNICAL_MARKERS:
		if literal.contains(marker):
			return false
	if _identifier_re.search(literal) != null:
		return false
	return true


func _escape_newlines(literal: String) -> String:
	return literal.replace("\n", "\\n")


func _csv_cell(value: String) -> String:
	var escaped: String = value.replace("\"", "\"\"")
	if escaped.contains(",") or escaped.contains("\"") or escaped.contains("\n") or escaped.contains("\r"):
		return "\"" + escaped + "\""
	return escaped


func _slugify(path: String) -> String:
	var relative: String = path.trim_prefix("res://").trim_prefix("src/").get_basename().to_upper()
	var slug: String = _slug_re.sub(relative, "_", true)
	while slug.begins_with("_"):
		slug = slug.substr(1)
	while slug.ends_with("_"):
		slug = slug.substr(0, slug.length() - 1)
	return slug


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text.replace("\r\n", "\n")


func _write_output(content: String) -> bool:
	var make_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if make_error != OK and make_error != ERR_ALREADY_EXISTS:
		print("FAIL: cannot create ", OUTPUT_DIR, " (error ", make_error, ")")
		return false
	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		print("FAIL: cannot write ", OUTPUT_PATH)
		return false
	file.store_string(content)
	file.close()
	return true
