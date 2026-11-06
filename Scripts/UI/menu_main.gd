# menu_main.gd — 主菜单：标题 + 开始闯荡 / 退出（策划案第六节 UI 布局）
extends Control

var options := ["开始闯荡", "退出"]
var sel := 0
var labels: Array[Label] = []


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.085)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# 远山背景
	var mtn := TextureRect.new()
	mtn.texture = load("res://Assets/Art/Environments/bg_mountains.png")
	mtn.position = Vector2(0, 200)
	mtn.modulate = Color(1, 1, 1, 0.5)
	add_child(mtn)
	var title := UIKit.center("隐 尘 劫", 42, Color(0.82, 0.93, 0.9))
	title.position = Vector2(120, 60)
	title.size = Vector2(400, 50)
	add_child(title)
	var sub := UIKit.center("尘雾秘境 · 卷土重来", 11, Color(0.5, 0.65, 0.62))
	sub.position = Vector2(160, 118)
	sub.size = Vector2(320, 16)
	add_child(sub)
	var box := VBoxContainer.new()
	box.position = Vector2(280, 190)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	for i in options.size():
		var l := UIKit.center("", 15, Color(0.6, 0.7, 0.68))
		l.custom_minimum_size = Vector2(80, 20)
		box.add_child(l)
		labels.append(l)
	_render()
	AudioManager.play_bgm("bgm_menu")


func _render() -> void:
	for i in labels.size():
		if i == sel:
			labels[i].text = "▸ " + options[i]
			labels[i].add_theme_color_override("font_color", Color(0.9, 0.98, 0.95))
		else:
			labels[i].text = "  " + options[i]
			labels[i].add_theme_color_override("font_color", Color(0.55, 0.65, 0.63))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right") \
			or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		sel = (sel + 1) % options.size()
		AudioManager.play_sfx("ui_click")
		_render()
	elif event.is_action_pressed("light_attack") or event.is_action_pressed("ui_accept"):
		AudioManager.play_sfx("ui_click")
		if sel == 0:
			GameManager.to_weapon_select()
		else:
			get_tree().quit()
