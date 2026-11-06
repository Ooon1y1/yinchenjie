# panel_event.gd — 奇遇事件面板：W/S 选择，J 确认（不可 Esc 关闭）
extends CanvasLayer

signal finished(effect: String)

var event_id := ""
var options: Array = []
var sel := 0
var active := false
var _rows: Array[Panel] = []
var _root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 33
	_build()
	active = true


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UIKit.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", UIKit.panel_style())
	panel.position = Vector2(100, 48)
	panel.size = Vector2(440, 264)
	_root.add_child(panel)

	var info: Dictionary = EntriesData.EVENTS.get(event_id, {})
	options = info.get("options", [])

	var title := UIKit.center(String(info.get("title", "奇遇")), 16, Color(0.86, 0.96, 0.9))
	title.position = Vector2(100, 60)
	title.size = Vector2(440, 22)
	_root.add_child(title)

	var desc := Label.new()
	desc.text = String(info.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.66, 0.78, 0.74))
	desc.position = Vector2(124, 90)
	desc.size = Vector2(392, 36)
	_root.add_child(desc)

	_rows.clear()
	for i in options.size():
		var row := Panel.new()
		row.position = Vector2(124, 134 + i * 42)
		row.size = Vector2(392, 34)
		row.add_theme_stylebox_override("panel", UIKit.panel_style(
			Color(0.07, 0.10, 0.10, 0.9), Color(0.3, 0.45, 0.42, 0.5)))
		_root.add_child(row)
		var l := UIKit.label(String(options[i].get("text", "")), 11, Color(0.82, 0.9, 0.86))
		l.position = Vector2(14, 9)
		row.add_child(l)
		_rows.append(row)

	var hint := UIKit.center("W/S 选择 · J 确认", 9, Color(0.5, 0.6, 0.58))
	hint.position = Vector2(100, 286)
	hint.size = Vector2(440, 12)
	_root.add_child(hint)

	_refresh()


func _refresh() -> void:
	for i in _rows.size():
		var on := i == sel
		_rows[i].modulate = Color(1.2, 1.32, 1.24) if on else Color(0.72, 0.78, 0.76)
		_rows[i].position.x = 124.0 + (-6.0 if on else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not active or _rows.is_empty():
		return
	if event.is_action_pressed("dir_up") or event.is_action_pressed("ui_up") \
			or event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		sel = (sel - 1 + _rows.size()) % _rows.size()
		AudioManager.play_sfx("ui_click")
		_refresh()
	elif event.is_action_pressed("dir_down") or event.is_action_pressed("ui_down") \
			or event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		sel = (sel + 1) % _rows.size()
		AudioManager.play_sfx("ui_click")
		_refresh()
	elif event.is_action_pressed("light_attack") or event.is_action_pressed("ui_accept"):
		active = false
		AudioManager.play_sfx("entry_pick")
		finished.emit(String(options[sel].get("effect", "")))
