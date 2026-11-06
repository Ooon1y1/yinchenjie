# panel_entry_pick.gd — 词条三选一：卡片式选择，A/D 切换、J 确认，不可 Esc 关闭（策划案第六节）
# 试炼房为双词条：连续两轮三选一。
extends CanvasLayer

var rounds_left := 1
var choices: Array[String] = []
var sel := 0
var on_done: Callable
var cards: Array[Control] = []
var active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 32
	_build_static()


func _build_static() -> void:
	var root := Control.new()
	root.name = "Root"
	root.theme = UIKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var title := UIKit.center("悟 得 一 式", 16, Color(0.8, 0.95, 0.88))
	title.name = "Title"
	title.position = Vector2(160, 52)
	title.size = Vector2(320, 20)
	root.add_child(title)


func start_pick(rounds: int, cb: Callable) -> void:
	rounds_left = rounds
	on_done = cb
	active = true
	_new_round()


func _new_round() -> void:
	choices = BuffManager.random_choices(3)
	if choices.is_empty():
		_finish()
		return
	sel = 0
	_render()


func _clear_cards() -> void:
	for c in cards:
		c.queue_free()
	cards.clear()


func _render() -> void:
	_clear_cards()
	var root: Control = get_node("Root")
	var start_x := (640.0 - 3.0 * 160.0 - 2.0 * 16.0) / 2.0
	for i in choices.size():
		var info: Dictionary = EntriesData.ENTRIES[choices[i]]
		var card := Panel.new()
		card.position = Vector2(start_x + i * 176.0, 100)
		card.size = Vector2(160, 220)
		card.add_theme_stylebox_override("panel", UIKit.panel_style())
		root.add_child(card)
		cards.append(card)
		# 图标
		var icon := TextureRect.new()
		icon.texture = load(EntriesData.SCHOOL_ICONS[info.school])
		icon.position = Vector2(68, 14)
		icon.scale = Vector2(2, 2)
		card.add_child(icon)
		# 流派 + 名称
		var school := UIKit.center(EntriesData.SCHOOL_NAMES[info.school], 10, Color(0.45, 0.62, 0.58))
		school.position = Vector2(0, 56)
		school.size = Vector2(160, 12)
		card.add_child(school)
		var name_l := UIKit.center(info.name, 17, Color(0.9, 0.98, 0.94))
		name_l.position = Vector2(0, 72)
		name_l.size = Vector2(160, 22)
		card.add_child(name_l)
		# 描述（自动换行）
		var desc := Label.new()
		desc.text = info.desc
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.add_theme_font_size_override("font_size", 10)
		desc.add_theme_color_override("font_color", Color(0.68, 0.76, 0.74))
		desc.position = Vector2(12, 104)
		desc.size = Vector2(136, 90)
		card.add_child(desc)
	_highlight()


func _highlight() -> void:
	for i in cards.size():
		cards[i].modulate = Color(1.15, 1.25, 1.2) if i == sel else Color(0.75, 0.8, 0.78)
		cards[i].position.y = 100.0 + (-6.0 if i == sel else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		sel = (sel - 1 + cards.size()) % cards.size()
		AudioManager.play_sfx("ui_click")
		_highlight()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		sel = (sel + 1) % cards.size()
		AudioManager.play_sfx("ui_click")
		_highlight()
	elif event.is_action_pressed("light_attack") or event.is_action_pressed("ui_accept"):
		active = false
		AudioManager.play_sfx("entry_pick")
		BuffManager.add_entry(choices[sel])
		rounds_left -= 1
		if rounds_left > 0:
			active = true
			_new_round()
		else:
			_finish()


func _finish() -> void:
	var cb := on_done
	on_done = Callable()
	if cb.is_valid():
		cb.call_deferred()
	queue_free()
