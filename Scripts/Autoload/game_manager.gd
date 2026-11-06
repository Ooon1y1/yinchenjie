# game_manager.gd — 全局管理（AutoLoad）：运行状态、经济、输入映射、场景流转
extends Node

var gold: int = 0
var kills: int = 0
var run_time: float = 0.0
var room_index: int = 0
var layer: int = 0        # 当前层（0-2），三层秘境连续推进
var in_run: bool = false
var player: Node = null   # 当前局内玩家引用
var weapons: Array[String] = ["changjian"]   # 本局已持有武器
var selected_weapon: String = "changjian"    # 开局择兵记录（重开一局沿用）
var max_combo: int = 0    # 本局最高连击
var flasks: int = EntriesData.FLASK.max_uses   # 本局剩余血瓶次数（R 键使用）
var run_map: RunMap = null   # 当前层的分支舆图

var _last_scene: String = ""


func _init() -> void:
	_register_inputs()


func _register_inputs() -> void:
	var defs := {
		"move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE,
		"light_attack": KEY_J, "heavy_attack": KEY_K, "block": KEY_L,
		"dash": KEY_SHIFT, "pause": KEY_ESCAPE, "interact": KEY_E,
		"dir_up": KEY_W, "dir_down": KEY_S, "switch_weapon": KEY_Q,
		"use_flask": KEY_R,
	}
	for action in defs:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = defs[action]
		InputMap.action_add_event(action, ev)


func _ready() -> void:
	# 顿帧：全局 time_scale 瞬时归零后恢复（真实时间计时，不受 time_scale 影响）
	EventBus.hitstop_requested.connect(func(duration: float) -> void:
		if Engine.time_scale == 1.0:
			Engine.time_scale = 0.0
			await get_tree().create_timer(duration, true, false, true).timeout
			Engine.time_scale = 1.0)


func _process(delta: float) -> void:
	if in_run and not get_tree().paused and Engine.time_scale >= 0.99:
		run_time += delta


# ---- 局内流转 ----

func start_run(weapon_id: String = "") -> void:
	# weapon_id 为空时沿用上次择兵结果（暂停菜单“重新开始”即走此路径）
	if not weapon_id.is_empty() and ComboData.WEAPONS.has(weapon_id):
		selected_weapon = weapon_id
	gold = EntriesData.ECONOMY.start_gold
	kills = 0
	run_time = 0.0
	room_index = 0
	layer = 0
	in_run = true
	weapons = [selected_weapon]
	max_combo = 0
	flasks = EntriesData.FLASK.max_uses
	BuffManager.reset()
	PoolManager.clear_all()
	run_map = null
	build_map()
	Engine.time_scale = 1.0
	get_tree().paused = false
	EventBus.gold_changed.emit(gold)
	EventBus.flasks_changed.emit(flasks, EntriesData.FLASK.max_uses)
	EventBus.layer_changed.emit(layer, layer_name())
	get_tree().change_scene_to_file(EntriesData.MAIN_SCENE)


func to_main_menu() -> void:
	in_run = false
	player = null
	PoolManager.clear_all()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(EntriesData.MENU_MAIN_SCENE)


func to_weapon_select() -> void:
	# 每次全新开局（主菜单 / 死亡重来 / 通关再闯）都先择兵，再进入第一间房
	in_run = false
	player = null
	PoolManager.clear_all()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(EntriesData.WEAPON_SELECT_SCENE)


func next_room_index() -> int:
	return room_index + 1


func is_final_room() -> bool:
	return room_index >= EntriesData.ROOM_SEQUENCE.size() - 1


# ---- 分支舆图 ----

func build_map() -> void:
	run_map = RunMap.new()
	run_map.generate()


func enter_map_node(id: int) -> Dictionary:
	if run_map == null:
		return {}
	var nd: Dictionary = run_map.node(id)
	if nd.is_empty():
		return {}
	run_map.current_id = id
	if id not in run_map.visited:
		run_map.visited.append(id)
	return nd


func apply_event_effect(effect: String) -> String:
	var msgs: Array[String] = []
	for part in effect.split(","):
		var kv := part.split(":")
		var key := kv[0]
		var val := int(kv[1]) if kv.size() > 1 else 0
		match key:
			"heal":
				if player and is_instance_valid(player):
					player.heal(val)
					msgs.append("生命 +%d" % val)
			"gold":
				add_gold(val)
				msgs.append("尘珠 +%d" % val)
			"flask":
				flasks = clampi(flasks + val, 0, EntriesData.FLASK.max_uses)
				EventBus.flasks_changed.emit(flasks, EntriesData.FLASK.max_uses)
				msgs.append("血瓶 +%d" % val)
			"qi_full":
				if player and is_instance_valid(player):
					player.refill_qi()
					msgs.append("内息回满")
			"entry":
				var pool := BuffManager.random_choices(1)
				if not pool.is_empty():
					BuffManager.add_entry(pool[0])
					msgs.append("顿悟 · " + String(EntriesData.ENTRIES[pool[0]].name))
	return "，".join(msgs)


# ---- 三层推进 ----

func layer_name() -> String:
	return EntriesData.layer_cfg(layer).name


func is_final_layer() -> bool:
	return layer >= EntriesData.LAYERS.size() - 1


func advance_layer() -> bool:
	if is_final_layer():
		return false
	layer += 1
	room_index = 0
	build_map()
	EventBus.layer_changed.emit(layer, layer_name())
	return true


# ---- 经济 ----

func add_gold(amount: int) -> void:
	gold = clampi(gold + amount, 0, EntriesData.ECONOMY.max_gold)
	EventBus.gold_changed.emit(gold)


func register_kill(enemy_id: String, gold_drop: int) -> void:
	kills += 1
	if gold_drop > 0:
		add_gold(gold_drop)


# ---- 武器（商铺购买解锁，Q 键切换） ----

func own_weapon(weapon_id: String) -> bool:
	if weapon_id in weapons:
		return false
	weapons.append(weapon_id)
	return true


func has_weapon(weapon_id: String) -> bool:
	return weapon_id in weapons


# ---- 血瓶（R 键，休息点补满） ----

func use_flask() -> bool:
	if player == null or not is_instance_valid(player) or player.dead:
		return false
	if flasks <= 0:
		EventBus.toast.emit("血瓶已用尽")
		return false
	if player.hp >= player.max_hp:
		EventBus.toast.emit("生命已满")
		return false
	flasks -= 1
	player.heal(EntriesData.FLASK.heal)
	EventBus.flasks_changed.emit(flasks, EntriesData.FLASK.max_uses)
	EventBus.toast.emit("血瓶 · 回复 %d 生命（剩 %d）" % [int(EntriesData.FLASK.heal), flasks])
	return true


func refill_flasks() -> void:
	flasks = EntriesData.FLASK.max_uses
	EventBus.flasks_changed.emit(flasks, EntriesData.FLASK.max_uses)


# ---- 消耗品（购买后立即生效） ----

func apply_consumable(id: String) -> bool:
	if player == null:
		return false
	match id:
		"hui_yuan_dan":
			player.heal(40)
		"ning_shen_san":
			player.refill_qi()
			player.start_qi_half(8.0)
		"ba_ti_fu":
			player.start_super_armor(5.0)
		_:
			return false
	return true


func format_time() -> String:
	var m := int(run_time) / 60
	var s := int(run_time) % 60
	return "%d:%02d" % [m, s]
