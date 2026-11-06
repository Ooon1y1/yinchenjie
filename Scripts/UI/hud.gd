# hud.gd — 战斗 HUD：血条/内息条/尘珠/词条栏/BOSS 血条/试炼倒计时/交互提示（策划案第六节 UI 布局）
extends CanvasLayer

var hp_bar: Dictionary
var qi_bar: Dictionary
var boss_bar: Dictionary
var boss_label: Label
var gold_label: Label
var trial_label: Label
var hint_label: Label
var toast_label: Label
var entry_box: VBoxContainer
# ---- v2.0 连击 / 武器 ----
var combo_label: Label
var combo_bar: Dictionary
var weapon_icon: TextureRect
var weapon_label: Label
var flask_icon: TextureRect
var flask_label: Label
var layer_label: Label
var _combo_fade: Tween = null
var _weapon_flash: Tween = null


func _ready() -> void:
	layer = 8
	var root := Control.new()
	root.name = "Root"
	root.theme = UIKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# 玩家血条：左上 (16,16) 200×16
	hp_bar = UIKit.bar(root, "hp", Vector2(16, 16), Vector2(200, 16), Color(0, 0, 0, 0), Color(0.72, 0.26, 0.24))
	# 内息条：血条正下方 200×10
	qi_bar = UIKit.bar(root, "qi", Vector2(16, 36), Vector2(200, 10), Color(0, 0, 0, 0), Color(0.35, 0.72, 0.66))
	var hp_text := UIKit.label("生命", 9, Color(0.7, 0.76, 0.75))
	hp_text.position = Vector2(220, 18)
	root.add_child(hp_text)
	var qi_text := UIKit.label("内息", 9, Color(0.7, 0.76, 0.75))
	qi_text.position = Vector2(220, 36)
	root.add_child(qi_text)

	# 尘珠：右上角
	var gold_icon := TextureRect.new()
	gold_icon.texture = load("res://Assets/Art/Icons/icon_gold.png")
	gold_icon.position = Vector2(578, 14)
	gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gold_icon)
	gold_label = UIKit.label("30", 12, Color(0.75, 0.95, 0.9))
	gold_label.position = Vector2(596, 16)
	root.add_child(gold_label)

	# 已获词条栏：屏幕右缘竖排
	entry_box = VBoxContainer.new()
	entry_box.position = Vector2(616, 40)
	entry_box.add_theme_constant_override("separation", 4)
	entry_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(entry_box)

	# BOSS 血条：顶部居中 480×12
	boss_bar = UIKit.bar(root, "boss", Vector2(80, 6), Vector2(480, 12), Color(0, 0, 0, 0), Color(0.55, 0.18, 0.16))
	boss_label = UIKit.center("玄风剑主", 10, Color(0.9, 0.8, 0.76))
	boss_label.position = Vector2(240, 20)
	boss_label.size = Vector2(160, 12)
	root.add_child(boss_label)
	hide_boss_bar()

	# 试炼倒计时：顶部居中
	trial_label = UIKit.center("", 16, Color(0.9, 0.75, 0.35))
	trial_label.position = Vector2(240, 30)
	trial_label.size = Vector2(160, 18)
	root.add_child(trial_label)

	# 交互提示：底部居中
	hint_label = UIKit.center("", 10, Color(0.85, 0.95, 0.9))
	hint_label.position = Vector2(160, 330)
	hint_label.size = Vector2(320, 14)
	root.add_child(hint_label)

	# 通用提示（toast）
	toast_label = UIKit.center("", 11, Color(0.95, 0.85, 0.4))
	toast_label.position = Vector2(120, 150)
	toast_label.size = Vector2(400, 14)
	root.add_child(toast_label)

	# 连击计数：屏幕中上（策划案第二节 连击系统）
	combo_label = UIKit.center("", 18, Color(0.95, 0.85, 0.45))
	combo_label.position = Vector2(440, 112)
	combo_label.size = Vector2(200, 22)
	root.add_child(combo_label)
	combo_bar = UIKit.bar(root, "combo", Vector2(480, 138), Vector2(60, 4),
		Color(0, 0, 0, 0), Color(0.95, 0.85, 0.45))
	combo_bar.bg.visible = false
	combo_bar.fg.visible = false

	# 当前武器：血条下方
	weapon_icon = TextureRect.new()
	weapon_icon.position = Vector2(16, 52)
	weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(weapon_icon)
	weapon_label = UIKit.label("长剑", 10, Color(0.8, 0.88, 0.86))
	weapon_label.position = Vector2(36, 56)
	root.add_child(weapon_label)

	# 当前层名：武器下方
	layer_label = UIKit.label("", 9, Color(0.62, 0.82, 0.78))
	layer_label.position = Vector2(16, 74)
	root.add_child(layer_label)

	# 血瓶：左下角（R 使用，休息点补满）
	flask_icon = TextureRect.new()
	flask_icon.texture = load("res://Assets/Art/Icons/icon_flask.png")
	flask_icon.position = Vector2(16, 300)
	flask_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flask_icon)
	flask_label = UIKit.label("", 10, Color(0.85, 0.62, 0.58))
	flask_label.position = Vector2(36, 302)
	root.add_child(flask_label)
	var flask_hint := UIKit.label("R 血瓶", 8, Color(0.5, 0.6, 0.58))
	flask_hint.position = Vector2(36, 313)
	root.add_child(flask_hint)

	# 信号
	EventBus.player_hp_changed.connect(_on_hp)
	EventBus.player_qi_changed.connect(_on_qi)
	EventBus.gold_changed.connect(_on_gold)
	EventBus.entry_added.connect(_on_entry)
	EventBus.boss_spawned.connect(_on_boss_spawn)
	EventBus.boss_hp_changed.connect(_on_boss_hp)
	EventBus.boss_defeated.connect(hide_boss_bar)
	EventBus.trial_time_changed.connect(_on_trial)
	EventBus.interact_changed.connect(_on_interact)
	EventBus.toast.connect(_on_toast)
	EventBus.combo_tick.connect(_on_combo_tick)
	EventBus.combo_milestone.connect(_on_combo_milestone)
	EventBus.weapon_changed.connect(_on_weapon_changed)
	EventBus.flasks_changed.connect(_on_flasks)
	_on_flasks(GameManager.flasks, EntriesData.FLASK.max_uses)
	EventBus.layer_changed.connect(_on_layer_changed)
	_on_layer_changed(GameManager.layer, GameManager.layer_name())
	# 初始武器：开局择兵结果（player 先于 HUD 生成，可取本局武器表第一把）
	var start_wid := "changjian"
	if not GameManager.weapons.is_empty():
		start_wid = GameManager.weapons[0]
	var start_w: Dictionary = ComboData.weapon(start_wid)
	weapon_icon.texture = load(start_w.icon)
	weapon_label.text = start_w.name


func _on_hp(hp: int, max_hp: int) -> void:
	UIKit.set_bar(hp_bar, float(hp) / maxf(1.0, max_hp))


func _on_qi(qi: int, max_qi: int) -> void:
	UIKit.set_bar(qi_bar, float(qi) / maxf(1.0, max_qi))


func _on_gold(gold: int) -> void:
	gold_label.text = str(gold)


func _on_entry(entry_id: String) -> void:
	var info: Dictionary = EntriesData.ENTRIES[entry_id]
	var icon := TextureRect.new()
	icon.texture = load(EntriesData.SCHOOL_ICONS[info.school])
	icon.tooltip_text = info.name
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_box.add_child(icon)
	EventBus.toast.emit("获得词条 · " + info.name)


func _on_boss_spawn(boss_name: String, max_hp: int) -> void:
	boss_label.text = boss_name
	boss_label.visible = true
	boss_bar.bg.visible = true
	boss_bar.fg.visible = true
	UIKit.set_bar(boss_bar, 1.0)
	_on_boss_hp(max_hp, max_hp)


func _on_boss_hp(hp: int, max_hp: int) -> void:
	UIKit.set_bar(boss_bar, float(hp) / maxf(1.0, max_hp))


func hide_boss_bar() -> void:
	boss_bar.bg.visible = false
	boss_bar.fg.visible = false
	boss_label.visible = false


func _on_trial(remain: float) -> void:
	if remain < 0.0:
		trial_label.text = ""
	else:
		trial_label.text = "试炼 · %d" % int(ceil(remain))


func _on_interact(text: String) -> void:
	hint_label.text = text


func _on_toast(text: String) -> void:
	toast_label.text = text
	var t := get_tree().create_timer(1.2, true, false, true)
	t.timeout.connect(func():
		toast_label.text = "")


# ---- v2.0 连击 / 武器 ----

func _on_combo_tick(count: int, ratio: float) -> void:
	if count >= 3:
		if _combo_fade:
			_combo_fade.kill()
			_combo_fade = null
		combo_label.modulate.a = 1.0
		combo_label.text = "%d 连击" % count
		combo_bar.bg.visible = true
		combo_bar.fg.visible = true
		UIKit.set_bar(combo_bar, ratio)
	elif not combo_label.text.is_empty():
		# 断档：连击数字淡出 0.3s（策划案第七节连击计数器规范）
		if _combo_fade:
			_combo_fade.kill()
		_combo_fade = create_tween()
		_combo_fade.tween_property(combo_label, "modulate:a", 0.0, 0.3)
		_combo_fade.tween_callback(_hide_combo)


func _hide_combo() -> void:
	combo_label.text = ""
	combo_label.modulate.a = 1.0
	combo_bar.bg.visible = false
	combo_bar.fg.visible = false
	_combo_fade = null


func _on_combo_milestone(count: int) -> void:
	# 每 10 连击：计数脉冲放大
	var t := create_tween()
	t.tween_property(combo_label, "scale", Vector2(1.4, 1.4), 0.08)
	t.tween_property(combo_label, "scale", Vector2.ONE, 0.15)


func _on_flasks(current: int, max_uses: int) -> void:
	flask_label.text = "×%d" % current
	flask_label.add_theme_color_override("font_color",
		Color(0.85, 0.62, 0.58) if current > 0 else Color(0.45, 0.42, 0.4))
	flask_icon.modulate = Color(1, 1, 1, 1) if current > 0 else Color(1, 1, 1, 0.35)


func _on_layer_changed(_layer: int, layer_name: String) -> void:
	layer_label.text = layer_name


func _on_weapon_changed(weapon_id: String) -> void:
	var w: Dictionary = ComboData.weapon(weapon_id)
	weapon_icon.texture = load(w.icon)
	weapon_label.text = w.name
	# Q 切换时武器图标闪烁 0.2s（策划案第七节 UI 布局规范）
	if _weapon_flash:
		_weapon_flash.kill()
	weapon_icon.modulate.a = 1.0
	_weapon_flash = create_tween()
	for i in 4:
		_weapon_flash.tween_property(weapon_icon, "modulate:a",
			0.15 if i % 2 == 0 else 1.0, 0.05)
