# room_base.gd — 房间基类：地形构建、敌人生成、传送门逻辑（策划案第五节）
class_name RoomBase
extends Node2D

signal portal_entered
signal shop_opened
signal event_opened

@export var room_id := "combat"

var layout: Dictionary
var enemies_alive := 0
var cleared := false
var trial_running := false
var trial_time_left := 0.0
var trial_success := false
var portal: Area2D = null
var event_id := ""


func _ready() -> void:
	layout = EntriesData.LAYOUTS.get(room_id, {})
	_build_parallax()
	_build_world()
	_place_deco()
	_spawn_enemies()
	EventBus.enemy_killed.connect(_on_enemy_killed)
	match room_id:
		"rest":
			GameManager.refill_flasks()
			EventBus.toast.emit("休息点 · 血瓶已补满")
			_on_cleared()
			AudioManager.play_bgm("bgm_menu")
		"shop":
			_on_cleared()
			AudioManager.play_bgm("bgm_explore")
		"trial":
			trial_running = true
			trial_time_left = EntriesData.TRIAL_TIME
			AudioManager.play_bgm("bgm_explore")
		"boss":
			AudioManager.play_bgm("bgm_boss")
		_:
			AudioManager.play_bgm("bgm_explore")


func _process(delta: float) -> void:
	# 休憩房：每秒回复 2 生命
	if room_id == "rest" and GameManager.player and is_instance_valid(GameManager.player):
		GameManager.player.regen_hp(EntriesData.REST_HEAL * delta)
	# 试炼房倒计时
	if trial_running:
		trial_time_left -= delta
		EventBus.trial_time_changed.emit(maxf(0.0, trial_time_left))
		if trial_time_left <= 0.0:
			trial_running = false
			EventBus.trial_time_changed.emit(-1.0)
			_on_cleared()   # 超时：无奖励，传送门照常开启


func _on_enemy_killed(_id: String, _gold: int) -> void:
	enemies_alive = maxi(0, enemies_alive - 1)
	if enemies_alive == 0 and not cleared and room_id in ["combat", "elite", "trial"]:
		if room_id == "trial":
			trial_success = trial_running
			trial_running = false
			EventBus.trial_time_changed.emit(-1.0)
			if trial_success:
				# 试炼完成奖励 20 尘珠（策划案第六节房间表）
				GameManager.add_gold(EntriesData.ECONOMY.trial_bonus)
				EventBus.toast.emit("试炼达成 · 尘珠 +20")
		_on_cleared()


func _on_cleared() -> void:
	if cleared:
		return
	cleared = true
	if portal:
		portal.set_active(true)
		AudioManager.play_sfx("portal", -6.0)
	EventBus.room_cleared.emit(room_id)


# ---------------- 地形构建 ----------------

func _static_rect(size: Vector2, pos: Vector2, one_way := false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = EntriesData.mask([EntriesData.LAYER_WORLD])
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = pos
	if one_way:
		shape.one_way_collision = true
	body.add_child(shape)
	return body


func _build_world() -> void:
	var width: int = layout.width
	var floor_y: int = layout.floor_y
	# 地面视觉（平铺瓦片）
	var visual := Sprite2D.new()
	visual.texture = load("res://Assets/Art/Environments/Tiles/tile_ground.png")
	visual.region_enabled = true
	visual.region_rect = Rect2(0, 0, width, 40)
	visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	visual.centered = false
	visual.position = Vector2(0, floor_y)
	visual.z_index = -5
	add_child(visual)
	add_child(_static_rect(Vector2(width, 40), Vector2(width / 2.0, floor_y + 20)))
	# 左右墙 + 顶
	add_child(_static_rect(Vector2(16, 720), Vector2(-8, 0)))
	add_child(_static_rect(Vector2(16, 720), Vector2(width + 8, 0)))
	add_child(_static_rect(Vector2(width + 32, 16), Vector2(width / 2.0, -8)))
	# 悬空平台（单向可穿越）
	for p in layout.get("platforms", []):
		var pr: Rect2 = p
		add_child(_static_rect(pr.size, pr.position + pr.size / 2.0, true))
		var pv := Sprite2D.new()
		pv.texture = load("res://Assets/Art/Environments/Tiles/tile_platform.png")
		pv.region_enabled = true
		pv.region_rect = Rect2(0, 0, pr.size.x, pr.size.y)
		pv.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		pv.centered = false
		pv.position = pr.position
		pv.z_index = -4
		add_child(pv)
	# 传送门（休息点无传送门，休整后结算；BOSS 房传送门在击败 BOSS 后开启）
	if room_id != "rest":
		portal = load(EntriesData.PORTAL_SCENE).instantiate()
		portal.position = Vector2(width - 48.0, floor_y - 26.0)
		add_child(portal)
		portal.room = self


func _build_parallax() -> void:
	# 各层背景色调：第一层青碧 / 第二层毒绿 / 第三层赤红
	var tint: Color = EntriesData.layer_cfg(GameManager.layer).get("tint", Color.WHITE)
	var layers := [
		["res://Assets/Art/Environments/bg_mountains.png", Vector2(0.12, 0.03), 60],
		["res://Assets/Art/Environments/bg_pines_far.png", Vector2(0.3, 0.06), 30],
		["res://Assets/Art/Environments/bg_clouds.png", Vector2(0.5, 0.1), 10],
	]
	for l in layers:
		var par := Parallax2D.new()
		par.scroll_scale = l[1]
		par.position = Vector2(160, l[2])
		par.z_index = -50
		var tex: Texture2D = load(l[0])
		par.repeat_size = tex.get_size()
		var s := Sprite2D.new()
		s.texture = tex
		s.modulate = tint
		par.add_child(s)
		add_child(par)


func _place_deco() -> void:
	var list: Array = layout.get("deco", [])
	for i in list.size():
		var x: float = (i + 1) * layout.width / float(list.size() + 1)
		var d: String = list[i]
		var s := Sprite2D.new()
		s.z_index = -3
		match d:
			"pine":
				s.texture = load("res://Assets/Art/Environments/deco_pine.png")
				s.position = Vector2(x + (40 if i % 2 == 0 else -30), layout.floor_y - 28)
			"stele":
				s.texture = load("res://Assets/Art/Environments/deco_stele.png")
				s.position = Vector2(x, layout.floor_y - 14)
			"mist":
				s.texture = load("res://Assets/Art/Environments/deco_mist.png")
				s.position = Vector2(x, layout.floor_y - 70)
		add_child(s)


# ---------------- 敌人生成 ----------------

func _spawn_enemy(id: String, pos: Vector2) -> void:
	var scene_path: String = EntriesData.ENEMIES[id].scene
	var e: Node2D = load(scene_path).instantiate()
	e.enemy_id = id
	e.global_position = pos
	add_child(e)
	enemies_alive += 1


func _spawn_enemies() -> void:
	var spawns: Array = layout.get("spawn", [])
	match room_id:
		"combat":
			var normals := ["sword_disciple", "shan_xiao", "gu_daoist"]
			var count := 2 + (randi() % 2)   # 2-3 只
			for i in count:
				var id: String = normals[randi() % normals.size()]
				_spawn_enemy(id, spawns[i % spawns.size()] + Vector2(randf_range(-40, 40), 0))
		"elite":
			_spawn_enemy("dual_blade", spawns[0])
			_spawn_enemy("sword_disciple", spawns[1])
		"trial":
			for i in EntriesData.TRIAL_ENEMIES.size():
				_spawn_enemy(EntriesData.TRIAL_ENEMIES[i], spawns[i % spawns.size()])
		"boss":
			var bcfg: Dictionary = EntriesData.boss_cfg_for_layer(GameManager.layer)
			var boss: Node2D = load(bcfg.scene).instantiate()
			boss.boss_id = bcfg.id
			boss.global_position = Vector2(layout.width - 240.0, layout.floor_y - 40.0)
			add_child(boss)
			enemies_alive += 1
		"shop":
			var merchant: Node2D = load(EntriesData.MERCHANT_SCENE).instantiate()
			merchant.position = Vector2(layout.width - 150.0, layout.floor_y - 16.0)
			add_child(merchant)
			merchant.opened.connect(func(): shop_opened.emit())
		"event":
			var keys := EntriesData.EVENTS.keys()
			event_id = String(keys[randi() % keys.size()])
			var shrine: Node2D = load(EntriesData.EVENT_SHRINE_SCENE).instantiate()
			shrine.position = spawns[0] if spawns.size() > 0 else Vector2(layout.width * 0.62, layout.floor_y)
			add_child(shrine)
			shrine.opened.connect(func(): event_opened.emit())
			EventBus.toast.emit("前方似有异象…")


# 事件选择完毕：房间清空，传送门开启
func finish_event() -> void:
	if cleared:
		return
	EventBus.toast.emit("奇遇已了 · 前路开启")
	_on_cleared()


# ---------------- 传送门 ----------------

func on_portal_interacted() -> void:
	if cleared:
		portal_entered.emit()
