# menu_pause.gd — 暂停菜单：继续 / 重新开始 / 返回主菜单（暂停时保持响应）
extends CanvasLayer

signal closed
signal restart_requested
signal quit_requested

var options := ["继续", "重新开始", "返回主菜单"]
var sel := 0
var labels: Array[Label] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	var root := Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var title := UIKit.center("暂 停", 20, Color(0.85, 0.95, 0.92))
	title.position = Vector2(240, 110)
	title.size = Vector2(160, 26)
	root.add_child(title)
	var box := VBoxContainer.new()
	box.position = Vector2(264, 150)
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	for i in options.size():
		var l := UIKit.center("", 13)
		l.custom_minimum_size = Vector2(112, 18)
		box.add_child(l)
		labels.append(l)
	_render()


func _render() -> void:
	for i in labels.size():
		labels[i].text = ("▸ " if i == sel else "  ") + options[i]
		labels[i].add_theme_color_override("font_color",
			Color(0.9, 0.98, 0.95) if i == sel else Color(0.55, 0.65, 0.63))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right") \
			or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		sel = (sel + 1) % options.size()
		AudioManager.play_sfx("ui_click")
		_render()
	elif event.is_action_pressed("pause"):
		_resume()
	elif event.is_action_pressed("light_attack") or event.is_action_pressed("ui_accept"):
		AudioManager.play_sfx("ui_click")
		match sel:
			0:
				_resume()
			1:
				closed.emit.call_deferred()
				restart_requested.emit()
			2:
				closed.emit.call_deferred()
				quit_requested.emit()


func _resume() -> void:
	# 阻断本次事件继续传播，避免 main 收到同一 Esc 又立刻重开暂停菜单
	get_viewport().set_input_as_handled()
	AudioManager.play_sfx("ui_click")
	closed.emit()
	queue_free()
