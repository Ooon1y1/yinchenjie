# combat_component.gd — 战斗通用组件：受击盒、即时判定查询、闪白（策划案第二节判定规范）
# 挂在玩家/敌人节点下；攻击判定使用 direct_space_state 即时查询，攻击帧单次生效。
class_name CombatComponent
extends Node

var host: CharacterBody2D
var sprite: Sprite2D
var hurtbox: Area2D
var flash_timer: float = 0.0


func setup(p_host: CharacterBody2D, p_sprite: Sprite2D, hurt_size: Vector2, hurt_layer: int) -> void:
	host = p_host
	sprite = p_sprite
	hurtbox = Area2D.new()
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 0
	# Hurtbox 自身所在层（供攻击方查询）
	hurtbox.set_collision_layer_value(hurt_layer, true)
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = hurt_size
	shape.shape = rect
	# 底部对齐角色脚点
	shape.position = Vector2(0, -hurt_size.y / 2.0)
	hurtbox.add_child(shape)
	hurtbox.set_meta("host", host)
	host.add_child(hurtbox)


# ---- 即时矩形判定（返回被命中的宿主数组，去重） ----

func query_hosts(center: Vector2, size: Vector2, mask_layers: Array, max_results := 16) -> Array:
	var shape := RectangleShape2D.new()
	shape.size = size
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, center)
	params.collision_mask = EntriesData.mask(mask_layers)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var results: Array = host.get_world_2d().direct_space_state.intersect_shape(params, max_results)
	var hosts: Array = []
	for r in results:
		var collider: Object = r.get("collider")
		if collider and collider.has_meta("host"):
			var h: Object = collider.get_meta("host")
			if h != host and not hosts.has(h):
				hosts.append(h)
	return hosts


# ---- 半径判定（震波/冲击波） ----

func query_hosts_radius(center: Vector2, radius: float, mask_layers: Array) -> Array:
	var hosts := query_hosts(center, Vector2(radius * 2.0, radius * 2.0), mask_layers, 24)
	return hosts


# ---- 受击闪白（0.06s modulate 置白） ----

func flash(strength := 4.0) -> void:
	flash_timer = EntriesData.FLASH_TIME
	if sprite:
		sprite.modulate = Color(strength, strength, strength)


func tick_flash(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0 and sprite:
			sprite.modulate = Color.WHITE
