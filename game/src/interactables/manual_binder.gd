## Wall-mounted operator's manual. Interact to open, interact again to turn pages, close after the last page.
class_name ManualBinder
extends Interactable

@export var book: ManualBook

var _page_index: int = -1
var _ui: CanvasLayer
var _label: Label


func get_interaction_prompt() -> String:
	if _page_index < 0:
		return "Read manual"
	if _page_index >= get_page_count() - 1:
		return "Close manual"
	return "Next page"


func _handle_interact(_player: Node) -> void:
	if _page_index < 0:
		_page_index = 0
	elif _page_index >= get_page_count() - 1:
		_page_index = -1
	else:
		_page_index += 1
	_ensure_ui()
	if _ui != null:
		_ui.visible = _page_index >= 0
	if _page_index >= 0:
		_refresh()


func is_open() -> bool:
	return _page_index >= 0


func get_page_count() -> int:
	if book == null:
		return 0
	return book.pages.size()


func get_current_page_title() -> String:
	if book == null or _page_index < 0 or _page_index >= book.pages.size():
		return ""
	var page: ManualPage = book.pages[_page_index]
	if page == null:
		return ""
	return page.title


func build_readout() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if book == null or _page_index < 0 or _page_index >= book.pages.size():
		return lines
	var page: ManualPage = book.pages[_page_index]
	if page == null:
		return lines
	lines.append("%s  [%d/%d]" % [page.title, _page_index + 1, book.pages.size()])
	lines.append("")
	for body_line: String in page.body.split("\n"):
		lines.append(body_line)
	return lines


func _refresh() -> void:
	if _label != null:
		_label.text = "\n".join(build_readout())


func _ensure_ui() -> void:
	if _ui != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "ManualPages"
	layer.layer = 12
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.085, 0.07, 0.95)
	style.border_color = Color(0.62, 0.5, 0.25, 1.0)
	style.set_border_width_all(2)
	style.set_content_margin_all(22.0)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.88, 0.83, 0.68, 1.0))
	panel.add_child(_label)
	layer.visible = false
	_ui = layer
