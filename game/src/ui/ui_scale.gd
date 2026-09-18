## Shared UI-scale helper for the accessibility setting. Reads GameSettings.ui_scale and
## converts base font sizes so every code-built widget can follow the setting.
class_name UiScale
extends RefCounted


## Current ui_scale from /root/GameSettings, or 1.0 when the autoload is absent or unknown.
static func factor(context: Node) -> float:
	var settings: Node = _settings(context)
	if settings == null or not settings.has_method(&"get_value"):
		return 1.0
	var value: Variant = settings.call(&"get_value", &"ui_scale")
	if value is float or value is int:
		return float(value)
	return 1.0


## A base font size multiplied by the current ui_scale, clamped to at least 1.
static func size(context: Node, base: int) -> int:
	return maxi(1, int(roundf(float(base) * factor(context))))


## Connects callback to GameSettings.settings_changed. Null-safe and idempotent.
## Named connect_settings because "connect" would override Object.connect.
static func connect_settings(context: Node, callback: Callable) -> void:
	var settings: Node = _settings(context)
	if settings == null or not settings.has_signal(&"settings_changed"):
		return
	if settings.is_connected(&"settings_changed", callback):
		return
	settings.connect(&"settings_changed", callback)


## Root children fallback exists because --script SceneTree tests run before the root is in the active tree.
static func _settings(context: Node) -> Node:
	if context != null and context.is_inside_tree():
		return context.get_node_or_null(^"/root/GameSettings")
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_root: Window = (main_loop as SceneTree).root
		if scene_root != null:
			for child: Node in scene_root.get_children():
				if child.name == &"GameSettings":
					return child
	return null
