## Wall-mounted operator's manual. Interact to open; the scroll menu browses pages, a wheel click reads one.
class_name ManualBinder
extends Interactable

const BASE_FONT_SIZE: int = 15

@export var book: ManualBook

var _menu: ScrollMenu
var _content: Label
var _root: HBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	_apply_ui_scale()
	UiScale.connect_settings(self, _on_ui_scale_changed)


func get_interaction_prompt() -> String:
	return "Close manual" if is_open() else "Read manual"


func is_open() -> bool:
	return _menu != null and _menu.is_open()


func close() -> void:
	if _menu != null:
		_menu.close()
	if _root != null:
		_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if PanelDismiss.should_dismiss(event, is_open()):
		close()
		get_viewport().set_input_as_handled()
	elif is_open() and event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		var direction: int = 1 if event.keycode == KEY_PAGEDOWN else -1
		_scroll.scroll_vertical += direction * int(_scroll.size.y * 0.8)
		get_viewport().set_input_as_handled()


func get_page_count() -> int:
	if book == null:
		return 0
	return book.pages.size()


func get_current_page_title() -> String:
	var page: ManualPage = _current_page()
	return page.title if page != null else ""


func get_menu() -> ScrollMenu:
	return _menu


func build_readout() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if not is_open():
		return lines
	var page: ManualPage = _current_page()
	if page == null:
		return lines
	lines.append("%s  [%d/%d]" % [page.title, _menu.get_highlighted_index() + 1, get_page_count()])
	lines.append("")
	for body_line: String in page.body.split("\n"):
		lines.append(body_line)
	return lines


func _handle_interact(_player: Node) -> void:
	if is_open():
		close()
		return
	_ensure_ui()
	if _menu == null:
		return
	_menu.setup("OPERATOR'S MANUAL", _page_titles())
	_menu.open()
	_menu.set_hint("WHEEL/ARROWS: PAGES\nPGUP/PGDN: TEXT    E/ESC: CLOSE")
	if _root != null:
		_root.visible = true
	_refresh_content()
	_emit_sim_event(&"manual_opened", {})


func _current_page() -> ManualPage:
	if book == null or _menu == null:
		return null
	var index: int = _menu.get_highlighted_index()
	if index < 0 or index >= book.pages.size():
		return null
	return book.pages[index]


func _page_titles() -> PackedStringArray:
	var titles: PackedStringArray = PackedStringArray()
	if book == null:
		return titles
	for page: ManualPage in book.pages:
		titles.append(page.title if page != null else "-")
	return titles


func _on_page_highlighted(_index: int) -> void:
	if _scroll != null:
		_scroll.scroll_vertical = 0
	_refresh_content()


func _on_page_selected(index: int) -> void:
	_refresh_content()
	_emit_sim_event(&"manual_page_read", {"page_index": index, "title": get_current_page_title()})


func _refresh_content() -> void:
	if _content != null:
		_content.text = "\n".join(build_readout())


func _apply_ui_scale() -> void:
	if _content != null:
		_content.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))
	if _menu != null:
		_menu._apply_ui_scale()


func _on_ui_scale_changed(key: StringName, _value: Variant) -> void:
	if key == &"ui_scale":
		_apply_ui_scale()


func _ensure_ui() -> void:
	if _root != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "ManualPages"
	layer.layer = 12
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var row := HBoxContainer.new()
	row.name = "Pages"
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	_menu = ScrollMenu.new()
	_menu.name = "PageList"
	row.add_child(_menu)
	if not _menu.option_highlighted.is_connected(_on_page_highlighted):
		_menu.option_highlighted.connect(_on_page_highlighted)
	if not _menu.option_selected.is_connected(_on_page_selected):
		_menu.option_selected.connect(_on_page_selected)
	var content_panel := PanelContainer.new()
	content_panel.custom_minimum_size = Vector2(570.0, 560.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.085, 0.07, 0.62)
	style.border_color = Color(0.62, 0.5, 0.25, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(18.0)
	content_panel.add_theme_stylebox_override("panel", style)
	row.add_child(content_panel)
	_scroll = ScrollContainer.new()
	_scroll.name = "PageScroll"
	_scroll.custom_minimum_size = Vector2(534.0, 524.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_panel.add_child(_scroll)
	_content = Label.new()
	_content.name = "PageContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))
	CrtPanel.style_label(_content, CrtPanel.PHOSPHOR_AMBER)
	_scroll.add_child(_content)
	CrtPanel.add_overlay(content_panel)
	_root = row
