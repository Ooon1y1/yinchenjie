# boss_xuanfeng.gd — 三层守关 BOSS（策划案 5.4）
# 第一层玄风剑主：居合斩 / 远程剑气 / 格挡；二阶段攻速+30%、剑气三连发、突进斩。
# 第二层碧毒尊者：中距离毒瘴弹幕（一阶段 3 发 / 二阶段 5 发）。
# 第三层赤霄魔君：二阶段远距离天火剑气五连扇射。
# 格挡破解：玩家满蓄重击（破甲）命中 → 击破格挡并硬直 1s。
class_name BossXuanfeng
extends EnemyBase

@export var boss_id := "boss_xuanfeng"

var phase2 := false
var guard_active := false
var guard_cd_left := 0.0
var base_windup := {"iai": 0.6, "boss_qi": 0.4, "thrust": 0.3, "guard": 0.25}
var attack_cd := 1.5
var _max_hp := 300


func _ready() -> void:
	enemy_id = boss_id
	super._ready()
	cfg = EntriesData.boss_cfg(boss_id)
	_max_hp = cfg.hp
	hp = cfg.hp
	dmg = cfg.dmg
	speed = cfg.speed
	poise = 999   # BOSS 不被普通伤害打断硬直（弹反/破甲除外）
	# 进场亮相后显示 BOSS 血条
	get_tree().create_timer(0.6).timeout.connect(func():
		if not dead:
			EventBus.boss_spawned.emit(cfg.name, _max_hp)
			EventBus.boss_hp_changed.emit(hp, _max_hp))


func _windup_time() -> float:
	var t: float = base_windup.get(pattern, cfg.get("windup", 0.4))
	match pattern:
		"venom":
			t = cfg.get("venom_windup", 0.5)
		"blaze":
			t = cfg.get("blaze_windup", 0.45)
	return t / (1.3 if phase2 else 1.0)


func _chase(delta: float, player: Node2D) -> void:
	guard_cd_left = maxf(0.0, guard_cd_left - delta)
	var dx := absf(player.global_position.x - global_position.x)
	if cd_left > 0.0:
		# 攻击间隔：缓慢逼近
		velocity.x = signf(player.global_position.x - global_position.x) * speed * 0.5
		return
	if dx < 170.0 and guard_cd_left <= 0.0 and randf() < 0.35:
		_enter_windup("guard")
		return
	# 第二层碧毒尊者：毒瘴弹幕为中距离主力招式
	if boss_id == "boss_bilv":
		if dx <= 130.0:
			_enter_windup("iai")
		elif dx <= 340.0:
			_enter_windup("venom")
		else:
			_enter_windup("boss_qi")
		return
	# 第三层赤霄魔君：二阶段远距离改为天火剑气扇射
	if boss_id == "boss_chixiao" and phase2 and dx > 300.0:
		_enter_windup("blaze")
		return
	if dx <= 130.0:
		_enter_windup("iai")
	elif phase2 and dx <= 300.0:
		# 突进斩为二阶段新增招式（策划案第五节：血量 ≤ 50% 后新增突进斩）
		_enter_windup("thrust")
	else:
		_enter_windup("boss_qi")


func _act(delta: float, player: Node2D) -> void:
	match pattern:
		"iai":
			if strike_done == 0:
				strike_done = 1
				_strike_at(player, 48.0, Vector2(64, 40), false)
				EventBus.shake_requested.emit(3.0, 0.1)
			if state_time >= 0.6:
				_end_act(attack_cd / (1.3 if phase2 else 1.0))
		"boss_qi":
			if strike_done == 0:
				strike_done = 1
				_shoot_qi(player, 1 if not phase2 else 3)
			if state_time >= 0.5:
				_end_act(attack_cd / (1.3 if phase2 else 1.0))
		"thrust":
			var dir := signf(player.global_position.x - global_position.x)
			velocity.x = dir * 480.0
			act_moved += absf(velocity.x) * delta
			if act_moved >= cfg.thrust_distance or is_on_wall():
				_strike_at(player, 56.0, Vector2(56, 34), false)
				_end_act(attack_cd / (1.3 if phase2 else 1.0))
		"guard":
			guard_active = true
			velocity.x = 0.0
			if state_time >= cfg.guard_time:
				guard_active = false
				_end_act(1.0)
				guard_cd_left = cfg.guard_cd
		"venom":
			# 毒瘴弹幕：向玩家方向扇形发射毒弹（二阶段增至 5 发）
			if strike_done == 0:
				strike_done = 1
				var shots: int = cfg.get("venom_shots_phase2", 5) if phase2 \
					else cfg.get("venom_shots", 3)
				_shoot_fan(player, "orb", shots, cfg.get("venom_spread", 0.22),
					cfg.get("venom_dmg", 10), cfg.get("venom_speed", 240.0),
					Color(0.55, 1.0, 0.52))
			if state_time >= 0.55:
				_end_act(attack_cd / (1.3 if phase2 else 1.0))
		"blaze":
			# 天火剑气：向玩家方向扇形发射 5 道赤色剑气
			if strike_done == 0:
				strike_done = 1
				_shoot_fan(player, "qi", cfg.get("blaze_shots", 5), cfg.get("blaze_spread", 0.18),
					cfg.get("blaze_dmg", 16), cfg.get("blaze_speed", 360.0),
					Color(1.0, 0.55, 0.32))
			if state_time >= 0.55:
				_end_act(attack_cd / (1.3 if phase2 else 1.0))
		_:
			_end_act(0.5)


func _shoot_qi(player: Node2D, shots: int) -> void:
	var base_dir: Vector2 = (player.global_position + Vector2(0, -16) - global_position + Vector2(0, -16)).normalized()
	for i in shots:
		var spread := (i - (shots - 1) / 2.0) * 0.3
		var dir := base_dir.rotated(spread)
		var p := PoolManager.spawn("projectile")
		if p:
			p.setup({
				"dmg": dmg, "speed": cfg.qi_speed, "range": 520.0,
				"dir": dir, "friendly": false, "kind": "qi",
			})
			p.global_position = global_position + Vector2(dir.x * 14.0, -16)
	AudioManager.play_sfx("qi_shot")


# 扇形弹幕：kind = "orb"（毒弹）/ "qi"（剑气），tint 用于区分 BOSS 属性
func _shoot_fan(player: Node2D, kind: String, shots: int, spread: float,
		shot_dmg: int, shot_speed: float, tint: Color) -> void:
	var base_dir: Vector2 = (player.global_position - global_position).normalized()
	for i in shots:
		var a := (i - (shots - 1) / 2.0) * spread
		var dir := base_dir.rotated(a)
		var p := PoolManager.spawn("projectile")
		if p:
			p.setup({
				"dmg": shot_dmg, "speed": shot_speed, "range": 520.0,
				"dir": dir, "friendly": false, "kind": kind, "tint": tint,
			})
			p.global_position = global_position + Vector2(dir.x * 14.0, -16)
	AudioManager.play_sfx("poison_shot" if kind == "orb" else "qi_shot")


func take_hit(atk_dmg: int, from_x: float, opts: Dictionary = {}) -> bool:
	if dead:
		return false
	# 破甲禁格挡：命中后一段时间内无法重新举盾
	var guard_ban: float = opts.get("guard_ban", 0.0)
	if guard_ban > 0.0:
		guard_cd_left = maxf(guard_cd_left, guard_ban)
	if guard_active:
		if opts.get("armor_break", false):
			# 破甲：击破格挡并硬直 1s；禁格挡期间无法重新举盾
			guard_active = false
			var ban: float = opts.get("guard_ban", 0.0)
			if ban > 0.0:
				guard_cd_left = maxf(guard_cd_left, ban)
			hp -= atk_dmg
			stagger_time = cfg.guard_break_stagger
			state = EState.HURT
			state_time = 0.0
			velocity.x = signf(global_position.x - from_x) * 300.0
			combat.flash()
			AudioManager.play_sfx("block_break")
			EventBus.fx_requested.emit("shock", global_position + Vector2(0, -16), false, 1.2)
			EventBus.shake_requested.emit(5.0, 0.2)
		else:
			# 格挡：减免 80% 伤害，不产生硬直
			hp -= int(ceil(atk_dmg * (1.0 - cfg.guard_reduce)))
			anim.sprite.modulate = Color(1.4, 1.4, 1.4)
			combat.tick_flash(0.03)
			AudioManager.play_sfx("block_ok", -4.0)
			EventBus.fx_requested.emit("spark", global_position + Vector2(10 * signf(from_x - global_position.x) * -1.0, -16), false, 0.8)
		if hp <= 0:
			die()
			return true
		_check_phase()
		EventBus.boss_hp_changed.emit(hp, _max_hp)
		return true
	var result := super.take_hit(atk_dmg, from_x, opts)
	if not dead:
		_check_phase()
	EventBus.boss_hp_changed.emit(hp, _max_hp)
	return result


func _check_phase() -> void:
	if not phase2 and hp <= _max_hp * cfg.phase2_hp:
		phase2 = true
		EventBus.shake_requested.emit(EntriesData.SHAKE.boss_phase.x, EntriesData.SHAKE.boss_phase.y)
		AudioManager.play_sfx("block_break", -4.0)
		EventBus.fx_requested.emit("shock", global_position + Vector2(0, -16), false, 2.0)


func die() -> void:
	EventBus.boss_defeated.emit()
	super.die()
