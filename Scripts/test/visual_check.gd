# visual_check.gd — 实机渲染检查：真实窗口下截图主菜单 / 战斗画面并保存，供人工核对
# 运行方式: "$GODOT" --path D:/game res://Scenes/test/visual_check.tscn（不要加 --headless）
# 注意：本节点手动挂载/卸载被检场景，不走 change_scene（否则本节点会被释放，await 悬空）
extends Node

const OUT_DIR := "user://visual_check"

var _host: Node = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	# 本节点 _ready 期间 root 仍在挂载子节点，直接 add_child 会失败，先等一帧
	await get_tree().process_frame
	# ---- 1) 主菜单 ----
	await _mount(EntriesData.MENU_MAIN_SCENE)
	await _timer(1.0)
	_shot("01_menu")
	await _unmount()
	# ---- 2) 战斗房（玩家 + 敌人 + HUD）----
	GameManager.gold = EntriesData.ECONOMY.start_gold
	GameManager.kills = 0
	GameManager.run_time = 0.0
	GameManager.room_index = 0
	GameManager.in_run = true
	BuffManager.reset()
	await _mount(EntriesData.MAIN_SCENE)
	await _timer(1.2)
	_shot("02_game_idle")
	# ---- 3) 连招：右移 + 普攻两段 ----
	Input.action_press("move_right")
	await _timer(0.4)
	Input.action_press("light_attack")
	await _timer(0.18)
	_shot("03_combo_1")
	Input.action_release("light_attack")
	await _timer(0.12)
	Input.action_press("light_attack")
	Input.action_release("light_attack")
	await _timer(0.15)
	_shot("04_combo_2")
	Input.action_release("move_right")
	# ---- 4) 重击蓄力 ----
	Input.action_press("heavy_attack")
	await _timer(0.4)
	_shot("05_heavy_charge")
	Input.action_release("heavy_attack")
	await _timer(0.5)
	# ---- 5) 格挡 ----
	Input.action_press("block")
	await _timer(0.2)
	_shot("06_block")
	Input.action_release("block")
	# ---- 6) 第二层 BOSS：碧毒尊者 ----
	GameManager.layer = 1
	GameManager.room_index = 8
	EventBus.layer_changed.emit(GameManager.layer, GameManager.layer_name())
	_host.room_mgr.load_room(8)
	await _timer(0.4)
	await _focus_boss()
	_shot("07_boss_bilv")
	# ---- 7) 第三层 BOSS：赤霄魔君 ----
	GameManager.layer = 2
	GameManager.room_index = 8
	EventBus.layer_changed.emit(GameManager.layer, GameManager.layer_name())
	_host.room_mgr.load_room(8)
	await _timer(0.4)
	await _focus_boss()
	_shot("08_boss_chixiao")
	print("VISUAL CHECK DONE -> %s" % OUT_DIR)
	get_tree().quit()


func _mount(scene_path: String) -> void:
	_host = load(scene_path).instantiate()
	get_tree().root.add_child.call_deferred(_host)
	await get_tree().process_frame
	await get_tree().process_frame


# BOSS 房宽 1280、BOSS 刷新在 x≈1040，相机跟玩家时在 640 视口外；
# 把玩家挪到 BOSS 前方 150px，等相机平滑跟上后再截图。
func _focus_boss() -> void:
	var room: RoomBase = _host.room_mgr.current
	var boss: Node2D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			boss = e
			break
	if boss == null:
		push_warning("visual_check: BOSS 未生成")
		return
	_host.player.global_position = Vector2(boss.global_position.x - 150.0, room.layout.floor_y - 1.0)
	_host.player.velocity = Vector2.ZERO
	await _timer(1.2)


func _unmount() -> void:
	if _host:
		_host.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_host = null


func _timer(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(tag: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, tag])
	print("  shot: ", tag)
