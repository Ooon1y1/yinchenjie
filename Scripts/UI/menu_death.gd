# menu_death.gd — 死亡结算：击杀数 / 存活时长 / 卷土重来（策划案第八节验收 6）
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
	dim.color = Color(0.03, 0.02, 0.02, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var title := UIKit.center("尘 缘 已 尽", 26, Color(0.85, 0.35, 0.3))
	title.position = Vector2(160, 96)
	title.size = Vector2(320, 32)
	root.add_child(title)
	var stats := UIKit.center("击杀 %d · 最高连击 %d · 历时 %s" % [GameManager.kills, GameManager.max_combo, GameManager.format_time()], 12, Color(0.7, 0.72, 0.7))
	stats.position = Vector2(160, 140)
	stats.size = Vector2(320, 16)
	root.add_child(stats)
	var retry := UIKit.center("▸ 按 J 卷土重来", 13, Color(0.9, 0.95, 0.9))
	retry.position = Vector2(160, 200)
	retry.size = Vector2(320, 18)
	root.add_child(retry)
	var back := UIKit.center("按 Esc 返回主菜单", 10, Color(0.5, 0.58, 0.56))
	back.position = Vector2(160, 240)
	back.size = Vector2(320, 14)
	root.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("light_attack") or event.is_action_pressed("ui_accept"):
		AudioManager.play_sfx("ui_click")
		closed.emit()
		GameManager.to_weapon_select()
	elif event.is_action_pressed("pause"):
		AudioManager.play_sfx("ui_click")
		closed.emit()
		GameManager.to_main_menu()
