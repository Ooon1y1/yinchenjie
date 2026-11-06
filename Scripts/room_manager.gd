# room_manager.gd — 房间流转：按分支舆图节点加载房间、传送门切换、玩家落位
# load_room(idx) 保留为测试/兼容入口，按 ROOM_SEQUENCE 索引加载。
extends Node

var main: Node2D
var player: Node2D
var current: RoomBase = null
var transitioning := false


func setup(p_main: Node2D, p_player: Node2D) -> void:
	main = p_main
	player = p_player


func load_room(idx: int) -> void:
	idx = clampi(idx, 0, EntriesData.ROOM_SEQUENCE.size() - 1)
	GameManager.room_index = idx
	load_room_type(String(EntriesData.ROOM_SEQUENCE[idx]), idx)


func load_room_type(room_type: String, idx: int = -1) -> void:
	if current and is_instance_valid(current):
		current.queue_free()
		current = null
	PoolManager.clear_all()
	var scene_path: String = EntriesData.ROOM_SCENES.get(room_type, EntriesData.ROOM_SCENES["combat"])
	var room: RoomBase = load(scene_path).instantiate()
	room.room_id = room_type
	current = room
	main.add_child(room)
	room.portal_entered.connect(_on_portal_entered)
	room.shop_opened.connect(func(): main.open_shop())
	room.event_opened.connect(func(): main.open_event(room))
	# 玩家落位与镜头边界
	var layout: Dictionary = EntriesData.LAYOUTS.get(room_type, EntriesData.LAYOUTS["combat"])
	player.global_position = Vector2(48, layout.floor_y - 60.0)
	player.velocity = Vector2.ZERO
	player.set_camera_limits(0, 0, layout.width, 360)
	if idx >= 0:
		GameManager.room_index = idx


func _on_portal_entered() -> void:
	if transitioning:
		return
	transitioning = true
	await main.fade_out()
	# BOSS 房之后固定进入休憩点（层末结算），其余房间回到舆图选路
	if current and current.room_id == "boss":
		GameManager.room_index = EntriesData.ROOM_SEQUENCE.size() - 1
		load_room_type("rest")
		await main.fade_in()
	else:
		main.open_map()
	transitioning = false
