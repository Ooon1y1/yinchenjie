# panel_shop.gd — 云游商铺：消耗品立即生效 + 词条售卖，A/D 选择、J 购买、Esc 关闭
extends CanvasLayer

signal closed

var items: Array[Dictionary] = []   # {type, id, name, desc, price, icon}
var sel := 0
var row_nodes: Array[Control] = []
var gold_label: Label
var list_root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 34
	_build()
	_stock_up()


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.theme = UIKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_style())
	panel.position = Vector2(160, 60)
	panel.size = Vector2(320, 240)
	root.add_child(panel)
	var title := UIKit.center("云 游 商 铺", 14, Color(0.8, 0.95, 0.88))
	title.position = Vector2(160, 66)
	title.size = Vector2(320, 18)
	root.add_child(title)
	gold_label = UIKit.center("", 12, Color(0.78, 0.95, 0.88))
	gold_label.position = Vector2(160, 270)
	gold_label.size = Vector2(320, 16)
	root.add_child(gold_label)
	var hint := UIKit.center("A/D 选择 · J 购买 · Esc 关闭", 9, Color(0.5, 0.6, 0.58))
	hint.position = Vector2(160, 286)
	hint.size = Vector2(320, 12)
	root.add_child(hint)
	list_root = Control.new()
	list_root.position = Vector2(0, 90)
	list_root.size = Vector2(640, 180)
	root.add_child(list_root)
	_update_gold()


func _stock_up() -> void:
	items.clear()
	# 消耗品 ×3（可重复购买，立即生效）
	for id in EntriesData.CONSUMABLES:
		var c: Dictionary = EntriesData.CONSUMABLES[id]
		items.append({"type": "consumable", "id": id, "name": c.name, "desc": c.desc,
			"price": c.price, "icon": c.icon})
	# 武器 ×1（80 尘珠，未持有武器随机上架一把，策划案 4.6）
	for wid in _weapon_offers():
		var w: Dictionary = ComboData.weapon(wid)
		items.append({"type": "weapon", "id": wid, "name": w.name, "desc": "切换流派 · Q 键切换武器",
			"price": EntriesData.WEAPON_PRICE, "icon": w.icon})
	# 词条 ×2（50 尘珠，从可用池随机，买完即下架）
	for id in BuffManager.random_choices(2):
		var e: Dictionary = EntriesData.ENTRIES[id]
		items.append({"type": "entry", "id": id, "name": e.name + "（词条）", "desc": e.desc,
			"price": EntriesData.ENTRY_PRICE, "icon": EntriesData.SCHOOL_ICONS[e.school]})
	sel = 0
	_render()


# 未持有武器候选（随机上架 1 把，策划案 4.6：随机陈列 1 把未持有武器）
func _weapon_offers() -> Array:
	var pool: Array = []
	for wid in ComboData.WEAPONS:
		if not GameManager.has_weapon(wid):
			pool.append(wid)
	pool.shuffle()
	return pool.slice(0, 1)


func _render() -> void:
	for r in row_nodes:
		r.queue_free()
	row_nodes.clear()
	for i in items.size():
		var it: Dictionary = items[i]
		var row := Panel.new()
		row.position = Vector2(176, 88 + i * 26.0)
		row.size = Vector2(288, 24)
		row.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.12, 0.15, 0.15, 0.9),
			Color(0.38, 0.71, 0.66, 0.9) if i == sel else Color(0.2, 0.3, 0.3, 0.5)))
		list_root.add_child(row)
		row_nodes.append(row)
		var icon := TextureRect.new()
		icon.texture = load(it.icon)
		icon.position = Vector2(6, 5)
		row.add_child(icon)
		var name_l := UIKit.label("%d. %s" % [i + 1, it.name], 10, Color(0.9, 0.96, 0.93))
		name_l.position = Vector2(28, 1)
		row.add_child(name_l)
		var desc_l := UIKit.label(it.desc, 8, Color(0.55, 0.64, 0.62))
		desc_l.position = Vector2(28, 12)
		row.add_child(desc_l)
		var price_l := UIKit.label("%d 珠" % it.price, 10,
			Color(0.78, 0.95, 0.88) if GameManager.gold >= it.price else Color(0.7, 0.35, 0.3))
		price_l.position = Vector2(224, 5)
		row.add_child(price_l)


func _update_gold() -> void:
	gold_label.text = "尘珠：%d" % GameManager.gold


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right") \
			or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		if not items.is_empty():
			sel = (sel + 1) % items.size()
			AudioManager.play_sfx("ui_click")
			_render()
	elif event.is_action_pressed("light_attack") or event.is_action_pressed("ui_accept"):
		_buy()
	elif event.is_action_pressed("pause"):
		_close()


func _buy() -> void:
	if items.is_empty():
		return
	var it: Dictionary = items[sel]
	if GameManager.gold < it.price:
		EventBus.toast.emit("尘珠不足")
		AudioManager.play_sfx("ui_click")
		return
	GameManager.add_gold(-it.price)
	if it.type == "consumable":
		GameManager.apply_consumable(it.id)
		EventBus.toast.emit("服下 %s" % it.name)
	elif it.type == "weapon":
		GameManager.own_weapon(it.id)
		EventBus.toast.emit("获得武器 · %s（Q 切换）" % it.name)
		items.remove_at(sel)
		if sel >= items.size():
			sel = items.size() - 1
	else:
		BuffManager.add_entry(it.id)
		EventBus.toast.emit("参悟 %s" % it.name)
		items.remove_at(sel)
		if sel >= items.size():
			sel = items.size() - 1
	AudioManager.play_sfx("buy")
	_update_gold()
	_render()


func _close() -> void:
	# 阻断本次事件继续传播，避免 main 收到同一 Esc 又打开暂停菜单
	get_viewport().set_input_as_handled()
	AudioManager.play_sfx("ui_click")
	closed.emit()
	queue_free()
