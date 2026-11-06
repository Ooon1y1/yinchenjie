# pool_manager.gd — 对象池（AutoLoad）：剑气/飞剑/毒弹/特效统一池化（策划案第七节性能要求）
extends Node

var _pools: Dictionary = {}        # key -> Array[Node]
var _scenes: Dictionary = {}       # key -> PackedScene
var _active: Array[Node] = []


func _ready() -> void:
	_register("projectile", EntriesData.PROJECTILE_SCENE)
	_register("fx", "res://Scenes/fx.tscn")
	EventBus.fx_requested.connect(_on_fx_requested)


func _register(key: String, scene_path: String) -> void:
	_pools[key] = []
	if ResourceLoader.exists(scene_path):
		_scenes[key] = load(scene_path)
	else:
		push_error("对象池场景缺失: " + scene_path)


func _on_fx_requested(fx_id: String, pos: Vector2, flip_x: bool, scale_v: float) -> void:
	var fx := spawn("fx")
	if fx and fx.has_method("play"):
		fx.play(fx_id, pos, flip_x, scale_v)


func spawn(key: String) -> Node:
	var pool: Array = _pools.get(key, [])
	var node: Node = pool.pop_back() if not pool.is_empty() else _instantiate(key)
	if node == null:
		return null
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	if node.get_parent() != parent:
		parent.add_child(node)
	if node not in _active:
		_active.append(node)
	return node


func _instantiate(key: String) -> Node:
	if not _scenes.has(key):
		return null
	return _scenes[key].instantiate()


func despawn(key: String, node: Node) -> void:
	if node == null:
		return
	if is_instance_valid(node) and node.get_parent():
		node.get_parent().remove_child(node)
	_active.erase(node)
	if _pools.has(key):
		_pools[key].append(node)


func clear_all() -> void:
	for node in _active.duplicate():
		if is_instance_valid(node):
			if node.has_method("despawn_self"):
				node.despawn_self()
			else:
				node.queue_free()
	_active.clear()
	for key in _pools:
		for node in _pools[key]:
			if is_instance_valid(node):
				node.queue_free()
		_pools[key] = []
