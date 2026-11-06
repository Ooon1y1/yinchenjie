# enemy_base.gd — 敌人通用状态机：巡逻→察觉→追击→攻击→受击僵直（策划案第四节）
# 攻击方式按 cfg.kind 分支：melee(叛门剑徒) / pounce(山魈) / ranged(蛊毒道童) / elite(双刀狂徒)
class_name EnemyBase
extends CharacterBody2D

@export var enemy_id := "sword_disciple"

enum EState {PATROL, CHASE, WINDUP, ACT, RECOVER, HURT, LAUNCHED, DEAD}

const PATROL_RANGE := 60.0
const ALERT_RANGE := 300.0

var cfg: Dictionary
var hp := 1
var dmg := 1
var speed := 200.0
var dead := false
var aggro := false

var state: EState = EState.PATROL
var state_time := 0.0
var spawn_pos := Vector2.ZERO
var patrol_dir := 1
var cd_left := 0.0
var pattern := ""
var strike_done := 0
var act_moved := 0.0
var poise := 0            # 硬直韧性：普通敌人 0（每击必僵直），精英/BOSS 高
var stagger_time := 0.25
# ---- v2.0 受击状态（策划案第五节：浮空 / 眩晕 / 减速） ----
var committed_facing := 1   # 出招朝向（出招瞬间锁定，短刃背刺判定用）
var stun_left := 0.0       # 眩晕剩余（被任意命中清除后重新施加）
var slow_stacks := 0       # 霜寒减速层数（每层 -10%，上限 3 层）
var slow_left := 0.0
var launch_refresh := 0    # 浮空追击已刷新次数（上限 3）
var _stun_fx_tick := 0.0

var anim: PixelAnim
var combat: CombatComponent


func _ready() -> void:
	cfg = EntriesData.ENEMIES.get(enemy_id, {})
	hp = cfg.get("hp", 1)
	dmg = cfg.get("dmg", 1)
	speed = cfg.get("speed", 200.0)
	poise = 20 if cfg.get("kind", "melee") == "elite" else 0
	spawn_pos = global_position
	add_to_group("enemies")

	collision_layer = EntriesData.mask([EntriesData.LAYER_ENEMY])
	collision_mask = EntriesData.mask([EntriesData.LAYER_WORLD, EntriesData.LAYER_ENEMY])
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 28)
	shape.shape = rect
	shape.position = Vector2(0, -14)
	add_child(shape)

	var sprite := Sprite2D.new()
	sprite.position = Vector2(0, -16)
	add_child(sprite)
	var char_id := "enemy_" + enemy_id
	if enemy_id.begins_with("boss"):
		char_id = enemy_id
	anim = PixelAnim.new(sprite, char_id)
	for a in [["idle", 4, true], ["walk", 6, true], ["attack", 4, false], ["hurt", 2, false],
			["launched", 2, false], ["stunned", 2, true], ["death", 6, false]]:
		anim.register(a[0], a[1], a[2])
	anim.play("idle")

	combat = CombatComponent.new()
	add_child(combat)
	combat.setup(self, sprite, Vector2(18, 28), EntriesData.LAYER_ENEMY_HURT)


func _physics_process(delta: float) -> void:
	if dead:
		anim.advance(delta)
		return
	state_time += delta
	cd_left = maxf(0.0, cd_left - delta)
	combat.tick_flash(delta)
	# 眩晕：头顶眩晕特效，期间持续僵直
	if stun_left > 0.0:
		stun_left -= delta
		_stun_fx_tick -= delta
		if _stun_fx_tick <= 0.0:
			_stun_fx_tick = 0.5
			EventBus.fx_requested.emit("stun", global_position + Vector2(0, -36), false, 1.0)
	# 减速：到期清层
	if slow_left > 0.0:
		slow_left -= delta
		if slow_left <= 0.0:
			slow_stacks = 0

	var player = GameManager.player
	if player == null or not is_instance_valid(player) or player.dead:
		_tick_no_player(delta)
		return

	if state != EState.HURT and state != EState.DEAD:
		if not aggro and global_position.distance_to(player.global_position) <= ALERT_RANGE:
			aggro = true

	match state:
		EState.PATROL:
			_patrol(delta)
		EState.CHASE:
			_chase(delta, player)
		EState.WINDUP:
			_windup(delta, player)
		EState.ACT:
			_act(delta, player)
		EState.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
			if state_time >= 0.3:
				state = EState.CHASE
		EState.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if state_time >= stagger_time:
				if stun_left > 0.0:
					state_time = 0.0   # 眩晕未解除：维持僵直
				else:
					state = EState.CHASE
		EState.LAUNCHED:
			# 浮空：被挑空后短暂滞空，落地硬直 1s
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			if is_on_floor() and velocity.y >= -1.0:
				state = EState.HURT
				stagger_time = ComboData.LAUNCH.land_stagger
				state_time = 0.0
				EventBus.fx_requested.emit("shock", global_position + Vector2(0, -4), false, 0.7)

	# 空中一律受重力（此前 ACT 例外导致山魈扑跃起跳后恒速飞天、永不落地）
	if not is_on_floor():
		velocity.y += EntriesData.PLAYER.gravity * delta
	move_and_slide()
	_anim_tick(delta)


func _tick_no_player(delta: float) -> void:
	velocity.x = 0.0
	if not is_on_floor():
		velocity.y += EntriesData.PLAYER.gravity * delta
	move_and_slide()
	anim.advance(delta)


func _patrol(delta: float) -> void:
	if aggro:
		state = EState.CHASE
		return
	if absf(global_position.x - spawn_pos.x) >= PATROL_RANGE:
		patrol_dir = -signf(global_position.x - spawn_pos.x)
	velocity.x = patrol_dir * eff_speed() * 0.4


# 霜寒减速后的实际移动速度
func eff_speed() -> float:
	return speed * (1.0 - ComboData.SLOW.per * slow_stacks)


func _chase(delta: float, player: Node2D) -> void:
	var dx := player.global_position.x - global_position.x
	var kind: String = cfg.get("kind", "melee")
	# 蛊毒道童：保持距离风筝
	if kind == "ranged":
		var ad := absf(dx)
		if ad < cfg.keep_min:
			velocity.x = -signf(dx) * eff_speed()
		elif ad > cfg.keep_max:
			velocity.x = signf(dx) * eff_speed()
		else:
			velocity.x = 0.0
		if cd_left <= 0.0 and ad <= cfg.shot_range:
			_enter_windup("shoot")
		return
	# 双刀狂徒：远距离突进
	if kind == "elite" and cd_left <= 0.0 and absf(dx) > cfg.thrust_trigger_range:
		_enter_windup("thrust")
		return
	if kind == "pounce" and cd_left <= 0.0 and absf(dx) <= cfg.pounce_range:
		_enter_windup("pounce")
		return
	if cd_left <= 0.0 and absf(dx) <= cfg.get("reach", 44.0) + 6.0:
		_enter_windup("melee")
		return
	velocity.x = signf(dx) * eff_speed() * (0.6 if kind == "elite" else 1.0)


func _enter_windup(p_pattern: String) -> void:
	pattern = p_pattern
	state = EState.WINDUP
	state_time = 0.0
	strike_done = 0
	act_moved = 0.0
	velocity.x = 0.0
	# 出招朝向：出招瞬间锁定（短刃背刺判定依据）
	var p = GameManager.player
	if p != null and is_instance_valid(p):
		committed_facing = 1 if p.global_position.x >= global_position.x else -1


func _windup_time() -> float:
	match pattern:
		"thrust":
			return cfg.get("thrust_windup", 0.2)
		"pounce", "shoot":
			return cfg.windup
	return cfg.windup


func _windup(delta: float, player: Node2D) -> void:
	# 可视前摇提示：泛红脉动
	var t := _windup_time()
	anim.sprite.modulate = Color(1.0 + 0.6 * absf(sin(state_time * 20.0)), 0.7, 0.7)
	velocity.x = 0.0
	if state_time >= t:
		anim.sprite.modulate = Color.WHITE
		state = EState.ACT
		state_time = 0.0
		if pattern == "pounce":
			# 扑跃：弹道飞行 0.55s 落到玩家当前位置
			# （vy = -g·t/2 使滞空恰为 0.55s，与水平速度 dx/0.55 配套，落点即目标）
			var dx := player.global_position.x - global_position.x
			velocity = Vector2(dx / 0.55, -EntriesData.PLAYER.gravity * 0.55 / 2.0)
			AudioManager.play_sfx("dash", -6.0)


func _act(delta: float, player: Node2D) -> void:
	match pattern:
		"melee":
			_flurry(delta, player, cfg.strikes, cfg.strike_gap, false)
		"pounce":
			if is_on_floor():
				_strike_at(player, 44.0, Vector2(44, 32), cfg.get("unblockable", false))
				_end_act(0.5)
			elif state_time >= 1.0:
				# 兜底：扑出平台边缘等未落地时结束扑击态，交回常规下落
				_end_act(0.5)
		"shoot":
			if strike_done == 0:
				strike_done = 1
				var to := (player.global_position + Vector2(0, -16)) - (global_position + Vector2(0, -16))
				_spawn_projectile({
					"dmg": dmg, "speed": cfg.shot_speed, "range": cfg.shot_range,
					"dir": to.normalized(), "friendly": false, "kind": "orb",
				})
				AudioManager.play_sfx("poison_shot")
			_end_act(0.35)
		"thrust":
			var dir := signf(player.global_position.x - global_position.x)
			velocity.x = dir * cfg.thrust_speed
			act_moved += absf(velocity.x) * delta
			if act_moved >= 200.0 or is_on_wall():
				_strike_at(player, 52.0, Vector2(52, 30), false)
				_end_act(0.4)
		"flurry":
			_flurry(delta, player, cfg.strikes, cfg.strike_gap, false)
		_:
			_end_act(0.3)


func _flurry(delta: float, player: Node2D, strikes: int, gap: float, unblockable: bool) -> void:
	var idx := int(state_time / gap)
	if strike_done < mini(idx + 1, strikes):
		strike_done = mini(idx + 1, strikes)
		_strike_at(player, cfg.get("reach", 44.0), Vector2(cfg.get("reach", 44.0), 32),
			cfg.get("unblockable", unblockable))
	if strike_done >= strikes and state_time >= strikes * gap:
		_end_act(0.5)


func _strike_at(player: Node2D, reach: float, size: Vector2, unblockable: bool) -> void:
	var facing := 1 if player.global_position.x >= global_position.x else -1
	var center := global_position + Vector2(reach * 0.6 * facing, -16.0)
	var hits := combat.query_hosts(center, size, [EntriesData.LAYER_PLAYER_HURT])
	anim.sprite.flip_h = facing < 0
	for h in hits:
		h.take_hit(dmg, global_position.x, {
			"parryable": cfg.get("parryable", true),
			"parry_window": cfg.get("parry_window", 0.2),
			"unblockable": unblockable,
			"attacker": self,
		})
		EventBus.fx_requested.emit("spark", h.global_position + Vector2(0, -16), facing < 0, 1.0)


func _end_act(cd: float) -> void:
	state = EState.RECOVER
	state_time = 0.0
	# 小怪用各自 cfg.cd；BOSS 配置无 cd 键，采用出招处传入的冷却（含二阶段攻速加成）
	cd_left = float(cfg.get("cd", cd))


func _spawn_projectile(pcfg: Dictionary) -> void:
	var p := PoolManager.spawn("projectile")
	if p:
		p.setup(pcfg)
		p.global_position = global_position + Vector2(10 * signf(pcfg.dir.x), -16)


# ---------------- 受击 / 被弹反 / 死亡 ----------------

func take_hit(atk_dmg: int, from_x: float, opts: Dictionary = {}) -> bool:
	if dead:
		return false
	hp -= atk_dmg
	combat.flash()
	var kb: float = opts.get("kb", 150.0)
	velocity.x = signf(global_position.x - from_x) * kb
	if hp <= 0:
		die()
		return true
	# BOSS（韧性 ≥999）免疫浮空 / 眩晕 / 减速
	var boss_grade := poise >= 999
	# 霜寒：命中叠加减速（最多 3 层，每层 -10%，持续 2s）
	if opts.get("slow", false) and not boss_grade:
		slow_stacks = mini(ComboData.SLOW.max_stacks, slow_stacks + 1)
		slow_left = ComboData.SLOW.time
	# 浮空：空中追击可刷新滞空（上限 3 次）
	if opts.get("launch", false) and not boss_grade:
		if state == EState.LAUNCHED:
			if launch_refresh < ComboData.LAUNCH.max_refresh:
				launch_refresh += 1
				velocity.y = -ComboData.LAUNCH.refresh_vel
		else:
			state = EState.LAUNCHED
			state_time = 0.0
			launch_refresh = 0
			velocity.y = -ComboData.LAUNCH.rise_vel
		return true
	# 浮空中被普通命中：维持浮空连段（浮空伤害判空）
	if state == EState.LAUNCHED:
		return true
	# 眩晕：被任意命中清除，再由本次命中重新施加
	stun_left = 0.0
	var stun: float = opts.get("stun", 0.0)
	if stun > 0.0 and not boss_grade:
		stun_left = stun
	# 韧性：小于阈值的伤害不产生硬直（精英/BOSS 防止被轻击无限连）；眩晕强制僵直
	if atk_dmg >= poise or stun_left > 0.0:
		stagger_time = 0.25 + opts.get("stagger_add", 0.0)
		state = EState.HURT
		state_time = 0.0
	return true


func take_parry(stagger: float) -> void:
	# 被完美弹反：僵直 1s
	if dead:
		return
	stagger_time = stagger
	state = EState.HURT
	state_time = 0.0
	velocity.x = 0.0
	combat.flash(2.0)


func die() -> void:
	dead = true
	state = EState.DEAD
	velocity = Vector2.ZERO
	collision_layer = 0
	AudioManager.play_sfx("enemy_death")
	GameManager.register_kill(enemy_id, cfg.get("gold", 0))
	EventBus.enemy_killed.emit(enemy_id, cfg.get("gold", 0))
	anim.sprite.modulate = Color.WHITE
	anim.play("death", true)
	await get_tree().create_timer(0.8).timeout
	queue_free()


func _anim_tick(delta: float) -> void:
	anim.sprite.flip_h = (GameManager.player and
		GameManager.player.global_position.x < global_position.x)
	if stun_left > 0.0:
		anim.play("stunned")   # 眩晕：膝地摇晃 + 头顶螺旋特效
	else:
		match state:
			EState.PATROL, EState.CHASE, EState.RECOVER:
				if absf(velocity.x) > 10.0:
					anim.play("walk")
				else:
					anim.play("idle")
			EState.WINDUP, EState.ACT:
				anim.play("attack")
			EState.HURT:
				anim.play("hurt")
			EState.LAUNCHED:
				anim.play("launched")   # 浮空：空中瘫软
			EState.DEAD:
				pass
	anim.advance(delta)
