## Persistent user settings: mouse, audio, UI scaling, and the analogue filter. Autoload name: GameSettings.
## No class_name on purpose — it would conflict with the autoload.
extends Node

signal settings_changed(key: StringName, value: Variant)

const CONFIG_PATH: String = "user://settings.cfg"
const CONFIG_SECTION: String = "settings"
const SENSITIVITY_MIN: float = 0.5
const SENSITIVITY_MAX: float = 3.0
const UI_SCALE_MIN: float = 0.85
const UI_SCALE_MAX: float = 1.4
const VOLUME_MIN_DB: float = -40.0
const VOLUME_MAX_DB: float = 0.0
const FILTER_INTENSITY_MIN: float = 0.0
const FILTER_INTENSITY_MAX: float = 1.0
const ENCOUNTER_FREQUENCY_MIN: float = 0.0
const ENCOUNTER_FREQUENCY_MAX: float = 3.0
const MASTER_BUS_NAME: StringName = &"Master"
const SUPPORTED_KEYS: Array[StringName] = [
	&"mouse_sensitivity_multiplier",
	&"invert_y",
	&"master_volume_db",
	&"ui_scale",
	&"analogue_filter_enabled",
	&"analogue_filter_intensity",
	&"asteroid_frequency",
	&"anomaly_frequency",
	&"planet_frequency",
]

var mouse_sensitivity_multiplier: float = 1.0
var invert_y: bool = false
var master_volume_db: float = 0.0
var ui_scale: float = 1.0
var analogue_filter_enabled: bool = true
var analogue_filter_intensity: float = 1.0
var asteroid_frequency: float = 1.0
var anomaly_frequency: float = 1.0
var planet_frequency: float = 1.0


func _ready() -> void:
	load_settings()
	_apply_volume()


## Missing or corrupt files fall back to defaults.
## Deliberately silent: no settings_changed is emitted here, callers refresh after loading.
func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(CONFIG_PATH)
	if load_error != OK:
		mouse_sensitivity_multiplier = 1.0
		invert_y = false
		master_volume_db = 0.0
		ui_scale = 1.0
		analogue_filter_enabled = true
		analogue_filter_intensity = 1.0
		asteroid_frequency = 1.0
		anomaly_frequency = 1.0
		planet_frequency = 1.0
		_apply_volume()
		return
	mouse_sensitivity_multiplier = clampf(
		_read_float(config, &"mouse_sensitivity_multiplier", 1.0), SENSITIVITY_MIN, SENSITIVITY_MAX
	)
	invert_y = _read_bool(config, &"invert_y", false)
	master_volume_db = clampf(
		_read_float(config, &"master_volume_db", 0.0), VOLUME_MIN_DB, VOLUME_MAX_DB
	)
	ui_scale = clampf(_read_float(config, &"ui_scale", 1.0), UI_SCALE_MIN, UI_SCALE_MAX)
	analogue_filter_enabled = _read_bool(config, &"analogue_filter_enabled", true)
	analogue_filter_intensity = clampf(
		_read_float(config, &"analogue_filter_intensity", 1.0), FILTER_INTENSITY_MIN, FILTER_INTENSITY_MAX
	)
	asteroid_frequency = clampf(_read_float(config, &"asteroid_frequency", 1.0), ENCOUNTER_FREQUENCY_MIN, ENCOUNTER_FREQUENCY_MAX)
	anomaly_frequency = clampf(_read_float(config, &"anomaly_frequency", 1.0), ENCOUNTER_FREQUENCY_MIN, ENCOUNTER_FREQUENCY_MAX)
	planet_frequency = clampf(_read_float(config, &"planet_frequency", 1.0), ENCOUNTER_FREQUENCY_MIN, ENCOUNTER_FREQUENCY_MAX)
	_apply_volume()


func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(CONFIG_SECTION, "mouse_sensitivity_multiplier", mouse_sensitivity_multiplier)
	config.set_value(CONFIG_SECTION, "invert_y", invert_y)
	config.set_value(CONFIG_SECTION, "master_volume_db", master_volume_db)
	config.set_value(CONFIG_SECTION, "ui_scale", ui_scale)
	config.set_value(CONFIG_SECTION, "analogue_filter_enabled", analogue_filter_enabled)
	config.set_value(CONFIG_SECTION, "analogue_filter_intensity", analogue_filter_intensity)
	config.set_value(CONFIG_SECTION, "asteroid_frequency", asteroid_frequency)
	config.set_value(CONFIG_SECTION, "anomaly_frequency", anomaly_frequency)
	config.set_value(CONFIG_SECTION, "planet_frequency", planet_frequency)
	var save_error: Error = config.save(CONFIG_PATH)
	if save_error != OK:
		push_error("GameSettings.save_settings: failed to write '%s' (error %d)." % [CONFIG_PATH, save_error])


## Applies a validated value and reports the clamped value through settings_changed.
## Unknown keys and wrong types are rejected with an error and return false.
func set_value(key: StringName, value: Variant) -> bool:
	match key:
		&"mouse_sensitivity_multiplier":
			if not _is_number(value):
				push_error(_type_error(key, value, "a number"))
				return false
			mouse_sensitivity_multiplier = clampf(float(value), SENSITIVITY_MIN, SENSITIVITY_MAX)
			settings_changed.emit(key, mouse_sensitivity_multiplier)
			return true
		&"invert_y":
			if not (value is bool):
				push_error(_type_error(key, value, "a bool"))
				return false
			invert_y = bool(value)
			settings_changed.emit(key, invert_y)
			return true
		&"master_volume_db":
			if not _is_number(value):
				push_error(_type_error(key, value, "a number"))
				return false
			master_volume_db = clampf(float(value), VOLUME_MIN_DB, VOLUME_MAX_DB)
			_apply_volume()
			settings_changed.emit(key, master_volume_db)
			return true
		&"ui_scale":
			if not _is_number(value):
				push_error(_type_error(key, value, "a number"))
				return false
			ui_scale = clampf(float(value), UI_SCALE_MIN, UI_SCALE_MAX)
			settings_changed.emit(key, ui_scale)
			return true
		&"analogue_filter_enabled":
			if not (value is bool):
				push_error(_type_error(key, value, "a bool"))
				return false
			analogue_filter_enabled = bool(value)
			settings_changed.emit(key, analogue_filter_enabled)
			return true
		&"analogue_filter_intensity":
			if not _is_number(value):
				push_error(_type_error(key, value, "a number"))
				return false
			analogue_filter_intensity = clampf(float(value), FILTER_INTENSITY_MIN, FILTER_INTENSITY_MAX)
			settings_changed.emit(key, analogue_filter_intensity)
			return true
		&"asteroid_frequency":
			if not _is_number(value):
				push_error(_type_error(key, value, "a number"))
				return false
			asteroid_frequency = clampf(float(value), ENCOUNTER_FREQUENCY_MIN, ENCOUNTER_FREQUENCY_MAX)
			settings_changed.emit(key, asteroid_frequency)
			return true
		&"anomaly_frequency":
			if not _is_number(value):
				push_error(_type_error(key, value, "a number"))
				return false
			anomaly_frequency = clampf(float(value), ENCOUNTER_FREQUENCY_MIN, ENCOUNTER_FREQUENCY_MAX)
			settings_changed.emit(key, anomaly_frequency)
			return true
		&"planet_frequency":
			if not _is_number(value):
				push_error(_type_error(key, value, "a number"))
				return false
			planet_frequency = clampf(float(value), ENCOUNTER_FREQUENCY_MIN, ENCOUNTER_FREQUENCY_MAX)
			settings_changed.emit(key, planet_frequency)
			return true
		_:
			push_error("GameSettings.set_value: unknown key '%s'." % String(key))
			return false


func get_value(key: StringName) -> Variant:
	match key:
		&"mouse_sensitivity_multiplier":
			return mouse_sensitivity_multiplier
		&"invert_y":
			return invert_y
		&"master_volume_db":
			return master_volume_db
		&"ui_scale":
			return ui_scale
		&"analogue_filter_enabled":
			return analogue_filter_enabled
		&"analogue_filter_intensity":
			return analogue_filter_intensity
		&"asteroid_frequency":
			return asteroid_frequency
		&"anomaly_frequency":
			return anomaly_frequency
		&"planet_frequency":
			return planet_frequency
		_:
			push_error("GameSettings.get_value: unknown key '%s'." % String(key))
			return null


## Callers choose when to save so a temporary reset cannot overwrite stored preferences.
func reset_to_defaults() -> void:
	mouse_sensitivity_multiplier = 1.0
	invert_y = false
	master_volume_db = 0.0
	ui_scale = 1.0
	analogue_filter_enabled = true
	analogue_filter_intensity = 1.0
	asteroid_frequency = 1.0
	anomaly_frequency = 1.0
	planet_frequency = 1.0
	_apply_volume()
	for key: StringName in SUPPORTED_KEYS:
		settings_changed.emit(key, get_value(key))


func _apply_volume() -> void:
	var bus_index: int = AudioServer.get_bus_index(MASTER_BUS_NAME)
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, master_volume_db)


func _read_float(config: ConfigFile, key: StringName, fallback: float) -> float:
	if not config.has_section_key(CONFIG_SECTION, String(key)):
		return fallback
	var raw: Variant = config.get_value(CONFIG_SECTION, String(key))
	if not _is_number(raw):
		return fallback
	return float(raw)


func _read_bool(config: ConfigFile, key: StringName, fallback: bool) -> bool:
	if not config.has_section_key(CONFIG_SECTION, String(key)):
		return fallback
	var raw: Variant = config.get_value(CONFIG_SECTION, String(key))
	if not (raw is bool):
		return fallback
	return bool(raw)


func _is_number(value: Variant) -> bool:
	return value is float or value is int


func _type_error(key: StringName, value: Variant, expected: String) -> String:
	return "GameSettings.set_value: '%s' expects %s, got %s." % [
		String(key), expected, type_string(typeof(value))
	]
