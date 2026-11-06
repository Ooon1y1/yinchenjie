# projectile.gd — 投射物（池化）：剑气 / 毒弹 / 飞剑 / 反击剑气（策划案第二节参数）
extends Area2D

var dmg := 5
var speed := 400.0
var range_left := 300.0
var dir := Vector2.RIGHT
var friendly := true
var homing := false
var pierce := 0
var qi_return := 0
var kind := "qi"
var tint := Color.WHITE
var _traveled := 0.0
var _hit_hosts: Array = []
var _alive := false
var _sprite: Sprite2D


func _ready() -> void:
	monitoring = true
	monitorable = false
	_sprite = Sprite2D.new()
	add_child(_sprite)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(cfg: Dictionary) -> void:
	dmg = cfg.get("dmg", 5)
	speed = cfg.get("speed", 400.0)
	range_left = cfg.get("range", 300.0)
	dir = cfg.get("dir", Vector2.RIGHT).normalized()
	friendly = cfg.get("friendly", true)
	homing = cfg.get("homing", false)
	pierce = cfg.get("pierce", 0)
	qi_return = cfg.get("qi_return", 0)
	kind = cfg.get("kind", "qi")
	tint = cfg.get("tint", Color.WHITE)
	_traveled = 0.0
	_hit_hosts.clear()
	_alive = true
	# 碰撞层
	collision_layer = 0
	collision_mask = 0
	if friendly:
		set_collision_mask_value(EntriesData.LAYER_ENEMY_HURT, true)
		set_collision_mask_value(EntriesData.LAYER_WORLD, true)
	else:
		set_collision_mask_value(EntriesData.LAYER_PLAYER_HURT, true)
		set_collision_mask_value(EntriesData.LAYER_WORLD, true)
	# 视觉
	match kind:
		"orb":
			_sprite.texture = load("res://Assets/Art/Effects/fx_orb.png")
		"flying":
			_sprite.texture = load("res://Assets/Art/Effects/fx_fly_sword.png")
		_:
			_sprite.texture = load("res://Assets/Art/Effects/fx_qi.png")
	_sprite.hframes = 1
	_sprite.frame = 0
	visible = true
	modulate = tint


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	if homing:
		_target_nearest_enemy()
	position += dir * speed * delta
	_traveled += speed * delta
	if kind == "flying":
		rotation = dir.angle()
		_sprite.rotation = 0.0
	elif kind == "qi":
		_sprite.flip_h = dir.x < 0
	if _traveled >= range_left:
		despawn_self()


func _target_nearest_enemy() -> void:
	var best: Node2D = null
	var best_d := 320.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best:
		dir = (best.global_position - global_position).normalized()
		speed = maxf(speed, 320.0)


func _on_area_entered(area: Area2D) -> void:
	if not _alive or not area.has_meta("host"):
		return
	var target: Object = area.get_meta("host")
	if target in _hit_hosts:
		return
	if friendly and not target.is_in_group("enemies"):
		return
	if not friendly and not target.is_in_group("player"):
		return
	_hit_hosts.append(target)
	var opts := {"parryable": cfg_parryable, "unblockable": kind == "orb" and false, "from_projectile": true}
	var hit: bool = target.take_hit(dmg, global_position.x, opts)
	# 星归：飞剑命中回复内息
	if hit and qi_return > 0 and GameManager.player:
		GameManager.player.refund_qi(qi_return)
	if hit or true:
		if pierce > 0:
			pierce -= 1
		else:
			despawn_self()


# 毒弹可格挡（策划案：蛊毒道童 毒弹 可格挡/可弹反）
var cfg_parryable := true


func _on_body_entered(body: Node2D) -> void:
	# 撞墙即回收
	despawn_self()


func despawn_self() -> void:
	if not _alive:
		return
	_alive = false
	PoolManager.despawn("projectile", self)
