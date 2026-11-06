# menu_victory.gd — 通关结算（第三层 BOSS + 休憩点后触发）
extends CanvasLayer

signal closed

var sel := 0
var labels: Array[Label] = []


func _ready() -> void:
	layer = 42
	var root := Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.04, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var title := UIKit.center("破 境 而 出", 28, Color(0.65, 0.95, 0.85))
	title.position = Vector2(160, 80)
	title.size = Vector2(320, 34)
	root.add_child(title)
	var sub := UIKit.center("三层秘境 · 尽数破境", 12, Color(0.6, 0.75, 0.7))
	sub.position = Vector2(160, 124)
	sub.size = Vector2(320, 16)
	root.add_child(sub)
	var stats := UIKit.center("击杀 %d · 历时 %s · 尘珠 %d" % [GameManager.kills, GameManager.format_time(), GameManager.gold], 12, Color(0.72, 0.76, 0.74))
	stats.position = Vector2(160, 156)
	stats.size = Vector2(320, 16)
	root.add_child(stats)
	var box := VBoxContainer.new()
	box.position = Vector2(264, 200)
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	for t in ["再闯一次", "返回主菜单"]:
		var l := UIKit.center("", 13)
		l.custom_minimum_size = Vector2(112, 18)
		box.add_child(l)
		labels.append(l)
	_render()


func _render() -> void:
	for i in labels.size():
		labels[i].text = ("▸ " if i == sel else "  ") + ("再闯一次" if i == 0 else "返回主菜单")
		labels[i].add_theme_color_override("font_color",
			Color(0.9, 0.98, 0.95) if i == sel else Color(0.55, 0.65, 0.63))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right") \
			or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		sel = 1 - sel
		AudioManager.play_sfx("ui_click")
		_render()
	elif event.is_action_pressed("light_attack") or event.is_action_pressed("ui_accept"):
		AudioManager.play_sfx("ui_click")
		closed.emit()
		if sel == 0:
			GameManager.to_weapon_select()
		else:
			GameManager.to_main_menu()
