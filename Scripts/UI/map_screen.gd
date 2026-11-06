# map_screen.gd — 分支舆图：展示本层 DAG 节点与连线，选择可达节点进入下一间房
# 操作：A/D 或 W/S 切换，J 确认；也可鼠标点击可达节点
extends CanvasLayer

signal node_chosen(node_id: int)

const TYPE_CHARS := {
	"start": "始", "combat": "战", "elite": "精", "event": "事",
	"shop": "商", "trial": "试", "boss": "魔",
}
const TYPE_COLORS := {
	"start": Color(0.58, 0.64, 0.62),
	"combat": Color(0.80, 0.34, 0.30),
	"elite": Color(0.92, 0.58, 0.24),
	"event": Color(0.40, 0.62, 0.92),
	"shop": Color(0.92, 0.78, 0.34),
	"trial": Color(0.68, 0.46, 0.90),
	"boss": Color(0.88, 0.22, 0.22),
}

var reachable: Array[int] = []
var sel := 0
var active := false
var _map: RunMap
var _cards: Dictionary = {}
var _cursor: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_map = GameManager.run_map
	if _map == null:
		GameManager.build_map()
		_map = GameManager.run_map
	reachable = _map.reachable()
	_build()
	active = true


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.theme = UIKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.025, 0.032, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var title := UIKit.center("秘 境 舆 图", 16, Color(0.82, 0.96, 0.90))
	title.position = Vector2(180, 8)
	title.size = Vector2(280, 20)
	root.add_child(title)

	var layer_label := UIKit.center(GameManager.layer_name(), 9, Color(0.52, 0.72, 0.68))
	layer_label.position = Vector2(180, 28)
	layer_label.size = Vector2(280, 12)
	root.add_child(layer_label)

	# 连线（先画，位于节点之下）
	for n in _map.nodes:
		var a := Vector2(float(n["x"]), float(n["y"]))
		for nid in n["next"]:
			var nb: Dictionary = _map.nodes[nid]
			var b := Vector2(float(nb["x"]), float(nb["y"]))
			var line := Line2D.new()
			line.points = PackedVector2Array([a, b])
			line.width = 1.0
			var lit: bool = int(n["id"]) in _map.visited or int(n["id"]) == _map.current_id
			line.default_color = Color(0.30, 0.46, 0.43, 0.9) if lit else Color(0.16, 0.24, 0.25, 0.8)
			root.add_child(line)

	# 节点
	for n in _map.nodes:
		var id: int = int(n["id"])
		var type := String(n["type"])
		var is_boss := type == "boss"
		var sz := 44.0 if is_boss else 30.0
		var col: Color = TYPE_COLORS.get(type, Color.WHITE)
		var card := Panel.new()
		card.name = "Node%d" % id
		card.position = Vector2(float(n["x"]) - sz / 2.0, float(n["y"]) - sz / 2.0)
		card.size = Vector2(sz, sz)
		card.pivot_offset = card.size / 2.0
		card.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.055, 0.085, 0.085, 0.97), col))
		card.gui_input.connect(_on_card_input.bind(id))
		root.add_child(card)
		var l := UIKit.center(TYPE_CHARS.get(type, "?"), 16 if is_boss else 12, col)
		l.position = Vector2(0, sz / 2.0 - 10.0)
		l.size = Vector2(sz, 20)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(l)
		_cards[id] = card

	_cursor = UIKit.center("▼", 12, Color(0.95, 0.88, 0.45))
	_cursor.size = Vector2(20, 16)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_cursor)

	var legend := UIKit.center("战 战斗 · 精 精英 · 事 事件 · 商 商铺 · 试 试炼 · 魔 首领", 8,
		Color(0.52, 0.62, 0.58))
	legend.position = Vector2(80, 326)
	legend.size = Vector2(480, 12)
	root.add_child(legend)

	var hint := UIKit.center("A/D 或 W/S 选择 · J 前往 · 亦可点击节点", 9, Color(0.66, 0.78, 0.74))
	hint.position = Vector2(120, 342)
	hint.size = Vector2(400, 12)
	root.add_child(hint)

	_refresh()


func _refresh() -> void:
	for id in _cards:
		var card: Control = _cards[id]
		card.scale = Vector2.ONE
		if id == _map.current_id:
			card.modulate = Color(0.82, 0.88, 0.84)
		elif id in reachable:
			card.modulate = Color.WHITE
		elif id in _map.visited:
			card.modulate = Color(0.62, 0.68, 0.66)
		else:
			card.modulate = Color(0.30, 0.34, 0.33)
	if reachable.is_empty():
		_cursor.visible = false
		return
	_cursor.visible = true
	var chosen := reachable[clampi(sel, 0, reachable.size() - 1)]
	var card: Control = _cards[chosen]
	card.scale = Vector2(1.18, 1.18)
	card.modulate = Color(1.25, 1.35, 1.30)
	_cursor.position = Vector2(card.position.x + card.size.x / 2.0 - 10.0, card.position.y - 16.0)


func _unhandled_input(event: InputEvent) -> void:
	if not active or reachable.is_empty():
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left") \
			or event.is_action_pressed("dir_up") or event.is_action_pressed("ui_up"):
		sel = (sel - 1 + reachable.size()) % reachable.size()
		AudioManager.play_sfx("ui_click")
		_refresh()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right") \
			or event.is_action_pressed("dir_down") or event.is_action_pressed("ui_down"):
		sel = (sel + 1) % reachable.size()
		AudioManager.play_sfx("ui_click")
		_refresh()
	elif event.is_action_pressed("light_attack") or event.is_action_pressed("ui_accept"):
		_choose(reachable[sel])


func _on_card_input(event: InputEvent, id: int) -> void:
	if not active or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and id in reachable:
		sel = reachable.find(id)
		_refresh()
		_choose(id)


func _choose(id: int) -> void:
	if not active:
		return
	active = false
	AudioManager.play_sfx("ui_click")
	node_chosen.emit(id)
