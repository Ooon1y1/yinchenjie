# main.gd — 游戏主场景编排：房间流转、UI 挂载、震屏、菜单/商店/词条面板
extends Node2D

var player: Node2D
var room_mgr: Node
var hud: CanvasLayer
var fade_rect: ColorRect
var _overlay: CanvasLayer = null
var _shake_strength := 0.0
var _shake_time := 0.0
var _fade_tween: Tween


func _ready() -> void:
	player = load(EntriesData.PLAYER_SCENE).instantiate()
	add_child(player)
	room_mgr = $RoomManager
	room_mgr.setup(self, player)
	hud = load("res://Scenes/UI/hud.tscn").instantiate()
	add_child(hud)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 64
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.02, 0.03, 0.04, 0.0)
	fade_rect.size = Vector2(640, 360)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)
	add_child(fade_layer)

	if GameManager.run_map == null:
		GameManager.build_map()
	open_map()

	EventBus.shake_requested.connect(_on_shake)
	EventBus.player_died.connect(_on_player_died)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.room_cleared.connect(_on_room_cleared)


func _process(delta: float) -> void:
	# 屏幕震动（策划案第二节：随机偏移随时间衰减）
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam == null:
		return
	if _shake_time > 0.0:
		_shake_time -= delta
		var decay := maxf(0.0, _shake_time / 0.3)
		cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength * clampf(_shake_time * 8.0, 0.0, 1.0)
		if _shake_time <= 0.0:
			cam.offset = Vector2.ZERO
	else:
		cam.offset = Vector2.ZERO


func _on_shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_time = duration


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _overlay == null and not get_tree().paused \
			and is_instance_valid(player) and not player.dead:
		_open_pause_menu()


# ---------------- 转场 ----------------

func fade_out() -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "color:a", 1.0, 0.25)
	await _fade_tween.finished


func fade_in() -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "color:a", 0.0, 0.25)
	await _fade_tween.finished


# ---------------- 面板/菜单 ----------------

func _open_pause_menu() -> void:
	AudioManager.play_sfx("ui_click")
	_overlay = load("res://Scenes/UI/menu_pause.tscn").instantiate()
	add_child(_overlay)
	get_tree().paused = true
	_overlay.closed.connect(func():
		get_tree().paused = false
		_overlay = null)
	_overlay.quit_requested.connect(func():
		GameManager.to_main_menu())
	_overlay.restart_requested.connect(func():
		GameManager.start_run())


func open_shop() -> void:
	if _overlay != null:
		return
	AudioManager.play_sfx("ui_click")
	_overlay = load("res://Scenes/UI/panel_shop.tscn").instantiate()
	add_child(_overlay)
	get_tree().paused = true
	_overlay.closed.connect(func():
		get_tree().paused = false
		_overlay = null)


# ---------------- 分支舆图 ----------------

func open_map() -> void:
	if _overlay != null:
		return
	AudioManager.play_sfx("ui_click")
	_overlay = load(EntriesData.MAP_SCENE).instantiate()
	add_child(_overlay)
	get_tree().paused = true
	_overlay.node_chosen.connect(_on_map_node_chosen)


func _on_map_node_chosen(node_id: int) -> void:
	if _overlay == null:
		return
	var nd: Dictionary = GameManager.enter_map_node(node_id)
	if nd.is_empty():
		return
	var room_type := String(nd.get("type", "combat"))
	var overlay: CanvasLayer = _overlay
	_overlay = null
	get_tree().paused = false
	overlay.queue_free()
	await fade_out()
	room_mgr.load_room_type(room_type)
	GameManager.room_index = node_id
	await fade_in()


# ---------------- 奇遇事件 ----------------

func open_event(room: RoomBase) -> void:
	if _overlay != null:
		return
	AudioManager.play_sfx("ui_click")
	var panel: CanvasLayer = load(EntriesData.EVENT_PANEL_SCENE).instantiate()
	panel.event_id = room.event_id
	_overlay = panel
	add_child(panel)
	get_tree().paused = true
	panel.finished.connect(func(effect: String) -> void:
		var msg := GameManager.apply_event_effect(effect)
		if not msg.is_empty():
			EventBus.toast.emit("奇遇 · " + msg)
		get_tree().paused = false
		_overlay.queue_free()
		_overlay = null
		if is_instance_valid(room):
			room.finish_event())


func _show_entry_pick(rounds: int, on_done: Callable) -> void:
	if _overlay != null:
		return
	_overlay = load("res://Scenes/UI/panel_entry_pick.tscn").instantiate()
	add_child(_overlay)
	get_tree().paused = true
	_overlay.start_pick(rounds, func():
		get_tree().paused = false
		_overlay = null
		if on_done.is_valid():
			on_done.call())


func _on_room_cleared(room_id: String) -> void:
	match room_id:
		"elite":
			_show_entry_pick(1, Callable())
		"trial":
			if room_mgr.current and room_mgr.current.trial_success:
				_show_entry_pick(2, Callable())
		"rest":
			# 层末休憩点：补满血瓶后进入下一层舆图；第三层则触发破境通关
			await get_tree().create_timer(1.2).timeout
			if GameManager.is_final_layer():
				_show_victory()
			else:
				await fade_out()
				GameManager.advance_layer()
				open_map()
		_:
			pass


func _on_player_died() -> void:
	await get_tree().create_timer(0.6).timeout
	_overlay = load("res://Scenes/UI/menu_death.tscn").instantiate()
	add_child(_overlay)
	_overlay.closed.connect(func():
		_overlay = null)


func _on_boss_defeated() -> void:
	# BOSS 倒下后先选一次词条（策划案：BOSS 战后三选一），再开启传送门前往休息点
	await get_tree().create_timer(1.0).timeout
	_show_entry_pick(1, _open_rest_portal)


func _open_rest_portal() -> void:
	var room: RoomBase = room_mgr.current
	if room and not room.cleared:
		room._on_cleared()
	EventBus.toast.emit("BOSS 已破 · 前往休息点")


func _show_victory() -> void:
	if _overlay != null:
		return
	_overlay = load("res://Scenes/UI/menu_victory.tscn").instantiate()
	add_child(_overlay)
	_overlay.closed.connect(func():
		_overlay = null)
