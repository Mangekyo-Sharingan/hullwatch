## Localization table invariants: strings.csv exists, parses as keys,en, and holds unique non-empty keys.
extends SceneTree

const CSV_PATH: String = "res://assets/locale/strings.csv"
const MIN_DATA_ROWS: int = 10

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	_check(FileAccess.file_exists(CSV_PATH), "strings.csv exists")
	if not FileAccess.file_exists(CSV_PATH):
		_finish()
		return
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	_check(file != null, "strings.csv opens")
	if file == null:
		_finish()
		return
	var text: String = file.get_as_text()
	file.close()

	var lines: PackedStringArray = text.split("\n")
	while not lines.is_empty():
		var last: String = lines[lines.size() - 1]
		if not last.strip_edges().is_empty():
			break
		lines.remove_at(lines.size() - 1)

	_check(lines.size() > 0 and lines[0] == "keys,en", "first line is the keys,en header")
	var data_rows: int = maxi(lines.size() - 1, 0)
	_check(data_rows >= MIN_DATA_ROWS, "csv has at least %d data rows" % MIN_DATA_ROWS)

	var seen: Dictionary = {}
	var empty_keys: int = 0
	var malformed_rows: int = 0
	for index: int in range(1, lines.size()):
		var fields: PackedStringArray = lines[index].split(",", true, 1)
		if fields.size() != 2:
			malformed_rows += 1
			continue
		var key: String = fields[0]
		if key.is_empty():
			empty_keys += 1
			continue
		seen[key] = true
	_check(empty_keys == 0, "every row has a non-empty key")
	_check(malformed_rows == 0, "every row has a key and a value")
	_check(seen.size() == data_rows, "every key is unique")

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_localization")
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
