# menu_weapon_select.gd — 开局择兵：进入第一间房前选择随身武器（A/D 选择，J 确认）
extends Control

const CARD_SIZE := Vector2(128, 168)
const CARD_GAP := 12.0
const CARD_TOP := 88.0
const CARD_LIFT := 4.0

var weapon_ids: Array[String] = []
var sel := 0
var _confirmed := false

var card_panels: Array[Panel] = []
var card_names: Array[Label] = []
var card_tags: Array[Label] = []
var detail_title: Label
var detail_desc: Label
var detail_stats: Label
var detail_passive: Label
var hint_label: Label


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for wid in ComboData.WEAPONS:
		weapon_ids.append(wid)
	_build()
	_render()
	AudioManager.play_bgm("bgm_menu")


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.085)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var mtn := TextureRect.new()
	mtn.texture = load("res://Assets/Art/Environments/bg_mountains.png")
	mtn.position = Vector2(0, 200)
	mtn.modulate = Color(1, 1, 1, 0.4)
	mtn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mtn)

	var title := UIKit.center("择 兵 入 劫", 26, Color(0.82, 0.93, 0.9))
	title.position = Vector2(120, 14)
	title.size = Vector2(400, 32)
	add_child(title)
	var sub := UIKit.center("踏入秘境之前，先择一件趁手的兵器", 10, Color(0.5, 0.65, 0.62))
	sub.position = Vector2(160, 50)
	sub.size = Vector2(320, 14)
	add_child(sub)

	var total_w := CARD_SIZE.x * weapon_ids.size() + CARD_GAP * (weapon_ids.size() - 1)
	var start_x := (640.0 - total_w) * 0.5
	for i in weapon_ids.size():
		_build_card(i, start_x + i * (CARD_SIZE.x + CARD_GAP))

	_build_detail(start_x, total_w)

	hint_label = UIKit.center("A/D 或 ←/→ 选择 · 1-4 直选 · J / Enter 确认 · Esc 返回", 9,
		Color(0.5, 0.6, 0.58))
	hint_label.position = Vector2(60, 336)
	hint_label.size = Vector2(520, 14)
	add_child(hint_label)


func _build_card(index: int, x: float) -> void:
	var wid := weapon_ids[index]
	var w: Dictionary = ComboData.weapon(wid)
	var segs := _available_segments(w)

	var card := Panel.new()
	card.position = Vector2(x, CARD_TOP)
	card.size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	card_panels.append(card)

	var icon := TextureRect.new()
	icon.texture = load(w.icon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(40, 12)
	icon.size = Vector2(48, 48)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)

	var name_l := UIKit.center(w.name, 15, Color(0.9, 0.97, 0.94))
	name_l.position = Vector2(0, 64)
	name_l.size = Vector2(CARD_SIZE.x, 20)
	card.add_child(name_l)
	card_names.append(name_l)

	var tag := UIKit.center(w.tagline, 9, Color(0.5, 0.66, 0.63))
	tag.position = Vector2(0, 84)
	tag.size = Vector2(CARD_SIZE.x, 14)
	card.add_child(tag)
	card_tags.append(tag)

	var line := ColorRect.new()
	line.color = Color(0.3, 0.45, 0.43, 0.45)
	line.position = Vector2(24, 104)
	line.size = Vector2(CARD_SIZE.x - 48, 1)
	card.add_child(line)

	var dmg_lo := 999
	var dmg_hi := 0
	for seg in segs:
		dmg_lo = mini(dmg_lo, int(seg.dmg))
		dmg_hi = maxi(dmg_hi, int(seg.dmg))
	var stats := [
		"普攻 %d 段" % segs.size(),
		"伤害 %d - %d" % [dmg_lo, dmg_hi],
		"取消 %.2fs" % float(w.cancel_window),
	]
	for i in stats.size():
		var l := UIKit.center(stats[i], 9, Color(0.62, 0.72, 0.69))
		l.position = Vector2(0, 112 + i * 16)
		l.size = Vector2(CARD_SIZE.x, 14)
		card.add_child(l)


func _build_detail(x: float, width: float) -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(
		Color(0.07, 0.1, 0.1, 0.92), Color(0.26, 0.4, 0.38, 0.55)))
	panel.position = Vector2(x, 266)
	panel.size = Vector2(width, 62)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	detail_title = UIKit.label("", 12, Color(0.78, 0.95, 0.88))
	detail_title.position = Vector2(12, 6)
	panel.add_child(detail_title)
	detail_desc = UIKit.label("", 9, Color(0.62, 0.71, 0.68))
	detail_desc.position = Vector2(12, 22)
	panel.add_child(detail_desc)
	detail_stats = UIKit.label("", 9, Color(0.55, 0.68, 0.64))
	detail_stats.position = Vector2(12, 36)
	panel.add_child(detail_stats)
	detail_passive = UIKit.label("", 9, Color(0.86, 0.76, 0.48))
	detail_passive.position = Vector2(12, 49)
	panel.add_child(detail_passive)


func _available_segments(w: Dictionary) -> Array:
	var out: Array = []
	for seg in w.chain:
		if String(seg.get("unlock", "")).is_empty():
			out.append(seg)
	return out


func _render() -> void:
	for i in card_panels.size():
		var on := i == sel
		card_panels[i].add_theme_stylebox_override("panel", UIKit.panel_style(
			Color(0.14, 0.19, 0.18, 0.96) if on else Color(0.08, 0.11, 0.11, 0.9),
			Color(0.5, 0.92, 0.82, 1.0) if on else Color(0.22, 0.33, 0.32, 0.6)))
		card_panels[i].position.y = CARD_TOP - (CARD_LIFT if on else 0.0)
		card_names[i].add_theme_color_override("font_color",
			Color(0.95, 1.0, 0.97) if on else Color(0.72, 0.8, 0.77))
		card_tags[i].add_theme_color_override("font_color",
			Color(0.6, 0.86, 0.8) if on else Color(0.45, 0.57, 0.54))
	_render_detail()


func _render_detail() -> void:
	var w: Dictionary = ComboData.weapon(weapon_ids[sel])
	var segs := _available_segments(w)
	var dmg_lo := 999
	var dmg_hi := 0
	for seg in segs:
		dmg_lo = mini(dmg_lo, int(seg.dmg))
		dmg_hi = maxi(dmg_hi, int(seg.dmg))
	var fin: Dictionary = w.finisher
	detail_title.text = "%s · %s" % [w.name, w.tagline]
	detail_desc.text = w.desc
	detail_stats.text = "普攻 %d 段（%d-%d 伤害） · 终结「%s」%d 伤害 · 取消窗口 %.2fs" % [
		segs.size(), dmg_lo, dmg_hi, fin.name, int(fin.dmg), float(w.cancel_window)]
	detail_passive.text = "特性：" + String(w.passive)


func _unhandled_input(event: InputEvent) -> void:
	if _confirmed:
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left") \
			or event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right") \
			or event.is_action_pressed("ui_down"):
		_move(1)
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode >= KEY_1 \
			and event.physical_keycode < KEY_1 + weapon_ids.size():
		_select(event.physical_keycode - KEY_1)
	elif event.is_action_pressed("light_attack") or event.is_action_pressed("ui_accept"):
		_confirm()
	elif event.is_action_pressed("pause"):
		_back()


func _move(step: int) -> void:
	_select((sel + step + weapon_ids.size()) % weapon_ids.size())


func _select(index: int) -> void:
	if index == sel:
		return
	sel = index
	AudioManager.play_sfx("ui_click")
	_render()


func _confirm() -> void:
	_confirmed = true
	AudioManager.play_sfx("ui_click")
	GameManager.start_run(weapon_ids[sel])


func _back() -> void:
	AudioManager.play_sfx("ui_click")
	GameManager.to_main_menu()
