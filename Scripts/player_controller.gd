# player_controller.gd — 玩家状态机、输入处理、招式逻辑（策划案 v2.0 第二/三节全参数）
# 三层连招：普攻链(combo_1~n) / 分支派生(derive) / 终结技(finisher)；
# 取消机制：闪避取消 / 跳跃取消(行云) / 派生取消；Q 切换武器（连击与连段重置）。
extends CharacterBody2D

const P := EntriesData.PLAYER
const HV := EntriesData.HEAVY
const PR := EntriesData.PARRY
const SHAKE := EntriesData.SHAKE

enum State {IDLE, WALK, JUMP, FALL, COMBO, DERIVE, FINISHER,
	HEAVY_CHARGE, HEAVY_RELEASE, BLOCK, PARRY, DASH, HURT, DEATH}

var state: State = State.IDLE
var hp: float
var max_hp: int
var qi: float
var facing := 1
var state_time := 0.0
var dead := false

# 武器
var weapon_id := "changjian"

# 连招（数据与计数在 ComboManager）
var cm: ComboManager

# 当前攻击段（普攻段 / 派生 / 终结技共用 windup→strike→recovery）
var atk_cfg: Dictionary = {}
var atk_kind := "normal"      # normal / derive / finisher
var attack_phase := ""
var attack_speed := 1.0

# 重击蓄力
var charge_time := 0.0
var max_charge_time := 0.6
var full_charge := false
var charge_from_combo := false   # 重剑蓄力派生

# 格挡 / 弹反
var parry_elapsed := -1.0
var parry_window_override := -1.0   # 架招反击：弹反窗口 0.25s

# 计时器
var dash_cd_left := 0.0
var dash_dir := 1
var invuln_left := 0.0
var iframes_left := 0.0
var super_armor_left := 0.0
var qi_half_left := 0.0
var coyote := 0.0
var air_jumps := 1
var jump_cancel_cd := 0.0

# 输入缓冲（输入缓存 0.2s）
var buf_attack := 0.0
var buf_jump := 0.0
var buf_dash := 0.0
var buf_derive := 0.0

var anim: PixelAnim
var combat: CombatComponent
var near_interact: Node = null
var _ghost_tick := 0.0
var _last_qi_emitted := -1

# 动画注册表（帧数与 gen_art 生成的精灵表一致）
const ANIMS := [["idle", 4, true], ["walk", 6, true], ["jump", 1, false], ["fall", 1, false],
	["light_attack_1", 3, false], ["light_attack_2", 3, false], ["light_attack_3", 3, false],
	["light_attack_4", 3, false], ["light_attack_5", 2, false], ["light_attack_6", 3, false],
	["combo_3", 4, false], ["derive_up", 3, false], ["derive_qi", 3, false],
	["derive_ground", 4, false], ["derive_flash", 3, false], ["derive_back", 3, false],
	["finisher", 4, false], ["air_attack_1", 3, false], ["air_attack_2", 3, false],
	["air_attack_3", 3, false], ["heavy_charge", 2, true], ["heavy_release", 3, false],
	["block", 1, false], ["parry", 2, false], ["dash", 4, false], ["hurt", 2, false],
	["death", 6, false]]


func _ready() -> void:
	add_to_group("player")
	GameManager.player = self
	# 开局择兵：优先沿用本局武器表第一把
	if GameManager.in_run and not GameManager.weapons.is_empty():
		weapon_id = String(GameManager.weapons[0])
	collision_layer = EntriesData.mask([EntriesData.LAYER_PLAYER])
	collision_mask = EntriesData.mask([EntriesData.LAYER_WORLD])
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = P.hurtbox_size
	shape.shape = rect
	shape.position = Vector2(0, -P.hurtbox_size.y / 2.0)
	add_child(shape)

	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.position = Vector2(0, -16)
	add_child(sprite)

	anim = PixelAnim.new(sprite, "player_" + weapon_id)
	for a in ANIMS:
		anim.register(a[0], a[1], a[2])
	anim.play("idle")

	var cm_node := ComboManager.new()
	cm_node.name = "ComboManager"
	add_child(cm_node)
	cm = cm_node
	cm.weapon_id = weapon_id

	combat = CombatComponent.new()
	add_child(combat)
	combat.setup(self, sprite, P.hurtbox_size, EntriesData.LAYER_PLAYER_HURT)

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.position = Vector2(0, -18)
	add_child(cam)
	cam.make_current()

	max_hp = P.max_hp + BuffManager.max_hp_bonus()
	hp = max_hp
	qi = P.max_qi
	EventBus.entry_added.connect(_on_entry_added)
	EventBus.player_spawned.emit(self)
	_emit_stats()


func set_camera_limits(l: int, t: int, r: int, b: int) -> void:
	var cam: Camera2D = get_node("Camera2D")
	cam.limit_left = l
	cam.limit_top = t
	cam.limit_right = r
	cam.limit_bottom = b


func _on_entry_added(entry_id: String) -> void:
	if entry_id == "gu_yuan":
		# 固元：生命上限 +20，当前生命同步 +20
		max_hp = P.max_hp + BuffManager.max_hp_bonus()
		hp = minf(hp + EntriesData.ENTRY_VALUES.max_hp_bonus, max_hp)
		_emit_stats()


# ---------------- 主循环 ----------------

func _physics_process(delta: float) -> void:
	if dead:
		anim.advance(delta)
		return

	state_time += delta
	combat.tick_flash(delta)
	dash_cd_left = maxf(0.0, dash_cd_left - delta)
	invuln_left = maxf(0.0, invuln_left - delta)
	iframes_left = maxf(0.0, iframes_left - delta)
	super_armor_left = maxf(0.0, super_armor_left - delta)
	qi_half_left = maxf(0.0, qi_half_left - delta)
	coyote = maxf(0.0, coyote - delta)
	jump_cancel_cd = maxf(0.0, jump_cancel_cd - delta)
	buf_attack = maxf(0.0, buf_attack - delta)
	buf_jump = maxf(0.0, buf_jump - delta)
	buf_dash = maxf(0.0, buf_dash - delta)
	buf_derive = maxf(0.0, buf_derive - delta)
	if parry_elapsed >= 0.0:
		parry_elapsed += delta

	# 采集输入（输入缓存 0.2s）
	var axis := Input.get_axis("move_left", "move_right")
	if Input.is_action_just_pressed("light_attack"):
		buf_attack = ComboData.INPUT_BUFFER
	if Input.is_action_just_pressed("jump"):
		buf_jump = ComboData.INPUT_BUFFER
	if Input.is_action_just_pressed("dash"):
		buf_dash = ComboData.INPUT_BUFFER
	if Input.is_action_just_pressed("heavy_attack"):
		buf_derive = ComboData.INPUT_BUFFER
	if Input.is_action_just_pressed("interact") and near_interact:
		near_interact.interact()
	if Input.is_action_just_pressed("use_flask"):
		GameManager.use_flask()

	# 内息恢复（非战斗、非格挡：附近 300px 无敌人）
	if state in [State.IDLE, State.WALK, State.JUMP, State.FALL] and not _enemy_nearby():
		qi = minf(P.max_qi, qi + P.qi_regen * BuffManager.qi_regen_mult() * delta)
		_emit_stats()

	_state_tick(delta, axis)
	if not is_on_floor():
		# 空中连招缓降 50%
		var g: float = P.gravity * (0.5 if (state == State.COMBO and cm.air_combo) else 1.0)
		velocity.y += g * delta
	else:
		coyote = 0.08
		air_jumps = 1
	move_and_slide()
	_anim_tick(delta, axis)


func _enemy_nearby() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) <= P.regen_enemy_radius:
			return true
	return false


func _state_tick(delta: float, axis: float) -> void:
	match state:
		State.IDLE, State.WALK:
			_move(delta, axis)
			if buf_jump > 0.0 and (is_on_floor() or coyote > 0.0):
				_jump()
			_try_dash(axis)
			_try_block()
			_try_light()
			_try_heavy()
			_try_switch_weapon()
			if not is_on_floor():
				state = State.JUMP if velocity.y < 0 else State.FALL
		State.JUMP, State.FALL:
			_move(delta, axis)
			if buf_jump > 0.0 and air_jumps > 0:  # 二段跳
				air_jumps -= 1
				_jump()
			_try_dash(axis)
			_try_block()
			_try_light()
			_try_heavy()
			_try_switch_weapon()
		State.COMBO:
			_combo_state(delta, axis)
		State.DERIVE, State.FINISHER:
			# 突进派生（闪刺）：前摇中前冲
			if attack_phase == "windup" and atk_cfg.has("dash_strike"):
				velocity.x = facing * atk_cfg.dash_strike / maxf(atk_cfg.windup, 0.02)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
			_attack_phase(delta, axis)
		State.HEAVY_CHARGE:
			velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
			if Input.is_action_pressed("heavy_attack"):
				charge_time += delta
				if charge_time >= max_charge_time:
					charge_time = max_charge_time
			else:
				# K 键语义裁决（策划案第二节）：按住 ≥ 0.15s 才算蓄力重击；短按直接收势不出招
				if charge_time < ComboData.K_TAP_TIME:
					charge_from_combo = false
					_to_ground_state()
				elif charge_from_combo:
					_release_combo_charge()
				else:
					_release_heavy()
		State.HEAVY_RELEASE:
			if _try_block_cancel():
				return
			if _try_dash(axis, BuffManager.dash_cancel_cost()):
				return
			velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
			_heavy_phase(delta)
		State.BLOCK:
			if _try_dash(axis):
				return
			velocity.x = move_toward(velocity.x, axis * P.move_speed * 0.35, 2000.0 * delta)
			if axis != 0.0:
				facing = 1 if axis > 0 else -1
			# 格挡持续消耗内息
			var drain: float = EntriesData.BLOCK.drain * (0.5 if qi_half_left > 0.0 else 1.0)
			qi = maxf(0.0, qi - drain * delta)
			_emit_stats()
			if not Input.is_action_pressed("block") or qi <= 0.0:
				_exit_block()
			else:
				_try_light()
		State.PARRY:
			velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
			if state_time >= 0.25:
				if Input.is_action_pressed("block") and qi > 0.0:
					state = State.BLOCK
					parry_elapsed = 0.0
				else:
					_exit_block()
		State.DASH:
			velocity.x = dash_dir * P.dash_distance / P.dash_duration
			velocity.y = 0.0
			_ghost_tick -= delta
			if _ghost_tick <= 0.0:
				_ghost_tick = 0.06
				_spawn_ghost()
			if state_time >= P.dash_duration:
				dash_cd_left = P.dash_cd
				# 追影：轻功后可立即释放轻击
				if BuffManager.can_dash_cancel_attack() and buf_attack > 0.0:
					buf_attack = 0.0
					_start_combo_segment(1, false)
				else:
					_to_ground_state()
		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if state_time >= 0.18:
				_to_ground_state()
		State.DEATH:
			velocity.x = 0.0


func _move(delta: float, axis: float) -> void:
	velocity.x = move_toward(velocity.x, axis * P.move_speed, 4000.0 * delta)
	if axis != 0.0:
		facing = 1 if axis > 0 else -1


func _to_ground_state() -> void:
	state = State.JUMP if not is_on_floor() and velocity.y < 0 else (State.FALL if not is_on_floor() else State.IDLE)


func _jump() -> void:
	buf_jump = 0.0
	coyote = 0.0
	velocity.y = P.jump_vel
	state = State.JUMP


# ---------------- 普攻连段（基础普攻链） ----------------

func _try_light() -> void:
	if buf_attack <= 0.0:
		return
	var in_air := not is_on_floor()
	if in_air and not BuffManager.air_combo_unlocked():
		return
	if state in [State.IDLE, State.WALK, State.JUMP, State.FALL, State.BLOCK] \
			or (state == State.COMBO and attack_phase == "recovery"):
		# 衔接窗口内（combo_index > 0，含 IDLE 等待）按 J 续接下一段；
		# 窗口超时后段数已重置为 0，从头起手（策划案第二节：命中后允许继续连段）
		var idx := cm.combo_index + 1 if cm.combo_index > 0 else 1
		_start_combo_segment(idx, in_air)


func _start_combo_segment(idx: int, air: bool) -> void:
	cm.air_combo = air
	var segs := cm.chain_segments()
	if segs.is_empty():
		return
	idx = ((idx - 1) % segs.size()) + 1
	cm.combo_index = idx
	atk_cfg = segs[idx - 1]
	atk_kind = "normal"
	attack_phase = "windup"
	state_time = 0.0
	buf_attack = 0.0
	attack_speed = BuffManager.light_attack_speed_mult()
	state = State.COMBO
	AudioManager.play_sfx("swing_light")


func _combo_state(delta: float, axis: float) -> void:
	# 空中连招：缓降（重力在主循环处理），落地即收招
	if cm.air_combo:
		if is_on_floor():
			cm.reset_combo()
			state = State.IDLE
			return
		velocity.x = move_toward(velocity.x, facing * 120.0, 2400.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, facing * 60.0, 1200.0 * delta)
	# 特殊触发派生（架招反击 / 空中连斩）：任意阶段
	_try_trigger_derive()
	if state != State.COMBO:
		return
	var atk: Dictionary = atk_cfg
	if attack_phase == "windup":
		# 顺势：派生取消扩展至前摇后半段
		if BuffManager.preswing_derive_unlocked() and state_time >= atk.windup / attack_speed * 0.5:
			_try_derive_from_buffer()
			if state != State.COMBO:
				return
		if state_time >= atk.windup / attack_speed:
			attack_phase = "strike"
			state_time = 0.0
			_execute_strike(atk, "normal")
	elif attack_phase == "strike":
		if state_time >= 0.02:
			attack_phase = "recovery"
			state_time = 0.0
	else:
		var rec: float = atk.recovery / attack_speed * BuffManager.recovery_mult()
		# 派生取消窗口（命中瞬间起）
		if state_time <= cm.cancel_window():
			_try_derive_from_buffer()
			if state != State.COMBO:
				return
			# 重剑蓄力派生：后摇中按住 K
			if weapon_id == "zhongjian" and Input.is_action_pressed("heavy_attack"):
				_start_charge_from_combo()
				return
		# 后摇前半段：弹反 / 闪避 / 跳跃取消（策划案第二节：dash 与 perfect_parry 可打断普攻链后摇）
		if state_time <= rec * 0.5:
			if _try_block_cancel():
				return
			if _try_dash(axis, BuffManager.dash_cancel_cost()):
				return
			if _try_jump_cancel(rec):
				return
		if state_time >= rec:
			cm.combo_timer = BuffManager.combo_window()
			if buf_attack > 0.0 or (cm.auto_chain and cm.combo_index < cm.chain_size()):
				_start_combo_segment(cm.combo_index + 1, cm.air_combo)
			elif cm.air_combo:
				cm.reset_combo()
				state = State.JUMP if velocity.y < 0 else State.FALL
			else:
				state = State.IDLE


# ---------------- 派生技 / 终结技 ----------------

func _derive_dir_input() -> String:
	if Input.is_action_pressed("dir_up"):
		return "up"
	if Input.is_action_pressed("dir_down"):
		return "down"
	var axis := Input.get_axis("move_left", "move_right")
	if axis * facing < -0.3:
		return "back"
	if axis * facing > 0.3:
		return "fwd"
	return "none"


func _try_derive_from_buffer() -> void:
	if buf_derive <= 0.0:
		return
	var dir := _derive_dir_input()
	for d in cm.derives_for(cm.combo_index):
		if d.dir != "any" and d.dir != dir:
			continue
		buf_derive = 0.0
		_start_derive(d)
		return
	# 终结技：普攻链最后一段中按 K（空中链不可终结）
	if cm.combo_index >= cm.chain_size() and not cm.air_combo:
		buf_derive = 0.0
		_start_finisher()


func _try_trigger_derive() -> void:
	# 架招反击：普攻段中按 L
	if Input.is_action_just_pressed("block"):
		var d := cm.derive_by_trigger(cm.combo_index, "block")
		if not d.is_empty():
			_start_derive(d)
			return
	# 空中连斩：普攻段中按跳跃
	if buf_jump > 0.0:
		var d := cm.derive_by_trigger(cm.combo_index, "jump")
		if not d.is_empty():
			buf_jump = 0.0
			_start_derive(d)


func _start_derive(d: Dictionary) -> void:
	match d.get("trigger", "dir"):
		"block":
			# 架招反击：直入完美弹反预备（窗口 0.25s）
			parry_window_override = 0.25
			state = State.BLOCK
			parry_elapsed = 0.0
			state_time = 0.0
		"jump":
			# 空中连斩：自动起跳接空中 3 段斩（不消耗二段跳）
			cm.air_chain_override = d.air_chain
			cm.auto_chain = true
			cm.combo_index = 0
			velocity.y = P.jump_vel
			_start_combo_segment(1, true)
		_:
			var cost: float = d.get("cost", 0) * (0.5 if qi_half_left > 0.0 else 1.0)
			if cost > 0.0:
				if qi < cost:
					return
				qi -= cost
				_emit_stats()
			atk_cfg = d
			atk_kind = "derive"
			attack_phase = "windup"
			state_time = 0.0
			cm.combo_index = 0
			state = State.DERIVE
			AudioManager.play_sfx(d.get("sfx", "derive_release"))


func _start_finisher() -> void:
	var f: Dictionary = cm.weapon().finisher
	var cost: float = f.cost * (0.5 if qi_half_left > 0.0 else 1.0)
	if qi < cost:
		return
	qi -= cost
	_emit_stats()
	atk_cfg = f
	atk_kind = "finisher"
	attack_phase = "windup"
	state_time = 0.0
	cm.combo_index = 0
	state = State.FINISHER
	AudioManager.play_sfx("finisher_release")


# 派生 / 终结技共用：windup → strike → recovery
func _attack_phase(delta: float, axis: float) -> void:
	var atk: Dictionary = atk_cfg
	if attack_phase == "windup":
		if state_time >= atk.windup:
			attack_phase = "strike"
			state_time = 0.0
			_execute_strike(atk, atk_kind)
	elif attack_phase == "strike":
		if state_time >= 0.02:
			attack_phase = "recovery"
			state_time = 0.0
	else:
		var rec: float = atk.recovery * BuffManager.recovery_mult()
		# 后摇前半段：弹反 / 闪避 / 跳跃取消
		if state_time <= rec * 0.5:
			if _try_block_cancel():
				return
			if _try_dash(axis, BuffManager.dash_cancel_cost()):
				return
			if _try_jump_cancel(rec):
				return
		if state_time >= rec:
			_to_ground_state()


# ---------------- 统一打击结算 ----------------

func _strike_damage(atk: Dictionary, kind: String, enemy: Node = null) -> int:
	var dmg: float = atk.dmg
	dmg *= BuffManager.dmg_mult_for(kind)
	dmg *= cm.hit_damage_mult()
	# 短刃背刺被动：身处敌人出招方向的背后，伤害翻倍
	if enemy != null and weapon_id == "duanren" and enemy.get("committed_facing") != null:
		if signf(global_position.x - enemy.global_position.x) * enemy.committed_facing < 0.0:
			dmg *= ComboData.weapon("duanren").get("backstab_mult", 2.0)
	return maxi(1, int(round(dmg)))


func _hit_opts(atk: Dictionary, kind: String) -> Dictionary:
	var armor_break: bool = atk.get("armor_break", false)
	var guard_ban: float = atk.get("guard_ban", 0.0)
	if kind == "derive" and BuffManager.derive_armor_break():
		armor_break = true
		guard_ban = maxf(guard_ban, EntriesData.ENTRY_VALUES.guard_ban_derive)
	return {
		"kb": atk.get("kb", 150.0), "kb_time": atk.get("kb_time", 0.15), "attacker": self,
		"launch": atk.get("launch", false), "stun": atk.get("stun", 0.0),
		"slow": BuffManager.apply_slow(), "stagger_add": BuffManager.stagger_add(),
		"armor_break": armor_break, "guard_ban": guard_ban,
	}


func _execute_strike(atk: Dictionary, kind: String) -> void:
	# 影袭：瞬移到敌人身后
	if atk.has("teleport_range"):
		_teleport_behind(atk.teleport_range)
	# 剑气派生：发射穿透剑气
	if atk.has("projectile"):
		var pcfg: Dictionary = atk.projectile
		_spawn_projectile({
			"dmg": _strike_damage(atk, kind), "speed": pcfg.speed, "range": pcfg.range,
			"dir": Vector2(facing, 0), "friendly": true,
			"kind": pcfg.get("kind", "qi"), "pierce": pcfg.get("pierce", false),
		})
		EventBus.fx_requested.emit("slash", global_position + Vector2(18 * facing, -14), facing < 0, 1.1)
		return
	var range_mult := BuffManager.range_mult()
	# 连锋（v1.1）：长剑第三段范围 +30%
	if kind == "normal" and weapon_id == "changjian" and cm.combo_index == 3:
		range_mult *= BuffManager.light3_range_mult()
	var size: Vector2 = atk.size * range_mult
	var center := global_position + Vector2(atk.offset * range_mult * facing, -14.0)
	var hits: Array = combat.query_hosts(center, size, [EntriesData.LAYER_ENEMY_HURT])
	# 长戈「穿刺穿透」被动：派生攻击沿攻击方向延伸判定，穿透至多 3 个敌人（策划案第三节长戈派生表）
	var pierce_n: int = cm.weapon().get("derive_pierce", 0)
	if kind == "derive" and pierce_n > 0:
		var atk_dir: float = signf(atk.offset) * facing if atk.offset != 0.0 else float(facing)
		var seen := {}
		for h in hits:
			seen[h] = true
		for i in pierce_n:
			var c2 := center + Vector2(size.x * atk_dir * (i + 1), 0.0)
			for h in combat.query_hosts(c2, size, [EntriesData.LAYER_ENEMY_HURT]):
				if not seen.has(h):
					seen[h] = true
					hits.append(h)
	for h in hits:
		h.take_hit(_strike_damage(atk, kind, h), global_position.x, _hit_opts(atk, kind))
		cm.register_hit(self)
		EventBus.fx_requested.emit("spark", h.global_position + Vector2(0, -16), facing < 0, 1.0)
		_flying_sword_proc()
	# 剑气余韵 / 剑风：普攻附带剑气
	if kind == "normal":
		var qi_dmg: int = maxi(BuffManager.light_qi_dmg(), BuffManager.qi_echo_dmg(atk.dmg))
		if qi_dmg > 0:
			_spawn_projectile({
				"dmg": qi_dmg, "speed": 400.0, "range": 300.0, "dir": Vector2(facing, 0),
				"friendly": true, "kind": "qi",
			})
	# 爆裂：终结技命中产生范围爆炸
	if kind == "finisher" and not hits.is_empty():
		var ex := BuffManager.finisher_explode()
		if not ex.is_empty():
			for h in combat.query_hosts_radius(global_position, ex.radius, [EntriesData.LAYER_ENEMY_HURT]):
				h.take_hit(maxi(1, int(atk.dmg * ex.ratio)), global_position.x, _hit_opts(atk, kind))
				cm.register_hit(self)
			EventBus.fx_requested.emit("shock", global_position + Vector2(16 * facing, -14), false, 1.2)
	# 命中反馈
	if not hits.is_empty():
		match kind:
			"finisher":
				EventBus.hitstop_requested.emit(0.10)
				EventBus.shake_requested.emit(5.0, 0.20)
				AudioManager.play_sfx("finisher_hit")
			"derive":
				EventBus.hitstop_requested.emit(EntriesData.HITSTOP.light)
				AudioManager.play_sfx("hit_light")
			_:
				EventBus.hitstop_requested.emit(EntriesData.HITSTOP.light)
				AudioManager.play_sfx("hit_light")
	if atk.get("launch", false):
		AudioManager.play_sfx("launch")
	# 震地砸：地面冲击波特效
	if atk.get("ground_fx", false):
		EventBus.shake_requested.emit(SHAKE.heavy_hit.x, SHAKE.heavy_hit.y)
		EventBus.fx_requested.emit("shock",
			global_position + Vector2(atk.offset * facing, -8.0), facing < 0, 1.1)
	var slash_scale := 1.0
	if kind == "finisher":
		slash_scale = 1.6
	elif kind == "derive":
		slash_scale = 1.2
	EventBus.fx_requested.emit("slash",
		global_position + Vector2((16.0 + size.x * 0.25) * facing, -14.0), facing < 0, slash_scale)


func _flying_sword_proc() -> void:
	# 御灵：命中概率召唤飞剑
	var fcfg := BuffManager.flying_sword_cfg()
	if not fcfg.is_empty() and randf() < fcfg.chance:
		_spawn_projectile({
			"dmg": fcfg.dmg, "speed": 320.0, "range": 260.0, "dir": Vector2(facing, 0),
			"friendly": true, "homing": true, "pierce": fcfg.pierce,
			"qi_return": fcfg.qi_return, "kind": "flying",
		})


func _teleport_behind(range_px: float) -> void:
	var nearest: Node2D = null
	var best := range_px
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			var d := global_position.distance_to(e.global_position)
			if d <= best:
				best = d
				nearest = e
	if nearest:
		var behind: float = -nearest.committed_facing if nearest.get("committed_facing") != null else facing
		global_position.x = nearest.global_position.x + behind * 20.0
		facing = signf(nearest.global_position.x - global_position.x) if behind < 0.0 else -1
		facing = 1 if facing >= 0 else -1
		EventBus.fx_requested.emit("parry", global_position + Vector2(0, -16), facing < 0, 0.7)


# ---------------- 重击（蓄力重击 / 重剑蓄力派生） ----------------

func _try_heavy() -> void:
	if not Input.is_action_pressed("heavy_attack") or state == State.HEAVY_CHARGE:
		return
	var cost := HV.qi_cost * (0.5 if qi_half_left > 0.0 else 1.0)
	if qi < cost:
		return
	max_charge_time = HV.max_charge * BuffManager.heavy_charge_mult()
	charge_time = 0.0
	full_charge = false
	charge_from_combo = false
	state = State.HEAVY_CHARGE
	state_time = 0.0
	velocity.x = 0.0
	AudioManager.play_sfx("heavy_charge")


func _start_charge_from_combo() -> void:
	# 重剑蓄力派生：普攻后摇中按住 K（伤害最高 +50%）
	buf_derive = 0.0
	var d := cm.derive_by_trigger(0, "hold")
	if d.is_empty():
		return
	max_charge_time = d.max_charge
	charge_time = 0.0
	full_charge = false
	charge_from_combo = true
	atk_cfg = d
	state = State.HEAVY_CHARGE
	state_time = 0.0
	velocity.x = 0.0
	cm.combo_index = 0
	AudioManager.play_sfx("heavy_charge")


func _release_combo_charge() -> void:
	var cfg: Dictionary = atk_cfg
	var ratio := clampf(charge_time / max_charge_time, 0.0, 1.0)
	charge_from_combo = false
	atk_cfg = {
		"dmg": int(cfg.dmg * (1.0 + cfg.charge_mult * ratio)),
		"windup": 0.08, "recovery": 0.25,
		"size": cfg.size, "offset": cfg.offset, "kb": cfg.kb, "kb_time": cfg.kb_time,
		"armor_break": ratio >= 1.0, "guard_ban": 3.0 if ratio >= 1.0 else 0.0,
		"anim": cfg.anim,
	}
	atk_kind = "derive"
	attack_phase = "windup"
	state_time = 0.0
	state = State.DERIVE
	AudioManager.play_sfx("heavy_release")


func _release_heavy() -> void:
	var cost := HV.qi_cost * (0.5 if qi_half_left > 0.0 else 1.0)
	if qi < cost:
		state = State.IDLE
		return
	qi -= cost
	_emit_stats()
	full_charge = charge_time >= max_charge_time
	state = State.HEAVY_RELEASE
	attack_phase = "windup"
	state_time = 0.0
	AudioManager.play_sfx("heavy_release")


func _heavy_phase(delta: float) -> void:
	if attack_phase == "windup" and state_time >= HV.windup:
		attack_phase = "strike"
		state_time = 0.0
		_do_heavy_strike()
	elif attack_phase == "strike" and state_time >= 0.02:
		attack_phase = "recovery"
		state_time = 0.0
	elif attack_phase == "recovery" and state_time >= HV.recovery * BuffManager.recovery_mult():
		state = State.IDLE


func _do_heavy_strike() -> void:
	var ratio := clampf(charge_time / max_charge_time, 0.5, 1.0) if not full_charge else 1.0
	var dmg := int(HV.dmg * ratio * BuffManager.heavy_dmg_mult())
	var center := global_position + Vector2(HV.offset * BuffManager.range_mult() * facing, -14.0)
	var hits := combat.query_hosts(center, HV.size * BuffManager.range_mult(), [EntriesData.LAYER_ENEMY_HURT])
	for h in hits:
		# 满蓄重击破甲：击破格挡并禁格挡 1.5s，造成全额伤害（策划案第二节破甲定义）
		h.take_hit(dmg, global_position.x, {"kb": HV.kb, "kb_time": HV.kb_time, "attacker": self,
			"armor_break": full_charge, "guard_ban": HV.guard_ban if full_charge else 0.0,
			"slow": BuffManager.apply_slow(), "stagger_add": BuffManager.stagger_add()})
		cm.register_hit(self)
		EventBus.fx_requested.emit("spark", h.global_position + Vector2(0, -16), facing < 0, 1.2)
		_flying_sword_proc()
	# 震岳：重击命中产生范围冲击波
	var shock := BuffManager.heavy_shockwave()
	if not shock.is_empty() and not hits.is_empty():
		var wave_hits := combat.query_hosts_radius(global_position, shock.radius, [EntriesData.LAYER_ENEMY_HURT])
		for h in wave_hits:
			h.take_hit(shock.dmg, global_position.x, {"kb": 100.0, "kb_time": 0.1, "attacker": self})
			cm.register_hit(self)
		EventBus.fx_requested.emit("shock", global_position + Vector2(HV.offset * facing, -14), false, 1.0)
	EventBus.hitstop_requested.emit(EntriesData.HITSTOP.heavy)
	EventBus.shake_requested.emit(SHAKE.heavy_hit.x, SHAKE.heavy_hit.y)
	AudioManager.play_sfx("heavy_hit")
	EventBus.fx_requested.emit("slash", global_position + Vector2(22 * facing, -14), facing < 0, 1.4)


# ---------------- 取消机制 ----------------

func _try_block_cancel() -> bool:
	# 完美弹反可打断攻击后摇（策划案第二节 取消机制・优先级）：
	# 后摇中按 L 直接举格挡，弹反窗口从取消瞬间起算（0.2s 内被命中即触发完美弹反）
	if not Input.is_action_just_pressed("block") or qi <= 0.0:
		return false
	buf_derive = 0.0
	cm.combo_index = 0
	cm.auto_chain = false
	state = State.BLOCK
	parry_elapsed = 0.0
	state_time = 0.0
	return true


func _try_jump_cancel(rec: float) -> bool:
	# 行云：攻击后摇前半段可跳跃中断（0.2s 冷却，无内息消耗）
	if not BuffManager.jump_cancel_unlocked() or jump_cancel_cd > 0.0:
		return false
	if buf_jump <= 0.0 or state_time > rec * 0.5:
		return false
	buf_jump = 0.0
	jump_cancel_cd = ComboData.JUMP_CANCEL_CD
	cm.combo_index = 0
	cm.auto_chain = false
	_jump()
	return true


# ---------------- 格挡 / 完美弹反 ----------------

func _try_block() -> void:
	if not Input.is_action_pressed("block") or qi <= 0.0:
		return
	state = State.BLOCK
	parry_elapsed = 0.0
	state_time = 0.0


func _exit_block() -> void:
	parry_elapsed = -1.0
	parry_window_override = -1.0
	_to_ground_state()


func _try_dash(axis: float, cost_override := -1.0) -> bool:
	if buf_dash <= 0.0 or dash_cd_left > 0.0:
		return false
	var cost: float = cost_override if cost_override > 0.0 else P.dash_qi_cost
	cost *= 0.5 if qi_half_left > 0.0 else 1.0
	if qi < cost:
		return false
	buf_dash = 0.0
	qi -= cost
	_emit_stats()
	dash_dir = 1 if axis > 0 else (-1 if axis < 0 else facing)
	if axis != 0.0:
		facing = 1 if axis > 0 else -1
	state = State.DASH
	state_time = 0.0
	_ghost_tick = 0.0
	cm.combo_index = 0
	cm.auto_chain = false
	AudioManager.play_sfx("dash")
	return true


# ---------------- 武器切换 ----------------

func _try_switch_weapon() -> void:
	if not Input.is_action_just_pressed("switch_weapon"):
		return
	if GameManager.weapons.size() <= 1:
		return
	var idx := GameManager.weapons.find(weapon_id)
	weapon_id = GameManager.weapons[(idx + 1) % GameManager.weapons.size()]
	cm.weapon_id = weapon_id
	cm.reset_combo()
	cm.reset_hits(false)   # 切换武器连击清零
	anim.char_id = "player_" + weapon_id
	anim.play(anim.current, true)
	AudioManager.play_sfx("weapon_switch")
	EventBus.weapon_changed.emit(weapon_id)


func _spawn_ghost() -> void:
	var ghost := PoolManager.spawn("fx")
	if ghost:
		ghost.play_ghost(anim.sprite.texture, anim.sprite.hframes, anim.sprite.frame, anim.sprite.flip_h,
			global_position + Vector2(0, -16))


# ---------------- 受击 ----------------

func take_hit(dmg: int, from_x: float, opts: Dictionary = {}) -> bool:
	if dead:
		return false
	if invuln_left > 0.0 or state == State.DASH:
		return false
	# 格挡状态处理
	if state in [State.BLOCK, State.PARRY] and not opts.get("unblockable", false):
		var pw: float = opts.get("parry_window", P.parry_window)
		if parry_window_override > 0.0:
			pw = maxf(pw, parry_window_override)   # 架招反击：窗口加宽至 0.25s
		var parryable: bool = opts.get("parryable", true)
		if parryable and state == State.BLOCK and parry_elapsed >= 0.0 and parry_elapsed <= pw:
			_perfect_parry(opts)
			return true
		# 普通格挡：减免伤害
		var blocked := int(ceil(dmg * (1.0 - BuffManager.block_reduce())))
		hp = maxf(0.0, hp - blocked)
		_emit_stats()
		AudioManager.play_sfx("block_ok")
		EventBus.fx_requested.emit("spark", global_position + Vector2(10 * facing, -16), false, 0.8)
		velocity.x = signf(global_position.x - from_x) * 60.0
		if hp <= 0:
			die()
		return true
	# 全额受击：连击断档（不断则减半）
	hp = maxf(0.0, hp - dmg)
	cm.reset_hits(true)
	combat.flash()
	_emit_stats()
	AudioManager.play_sfx("player_hurt")
	EventBus.shake_requested.emit(SHAKE.player_hurt.x, SHAKE.player_hurt.y)
	iframes_left = 0.2
	if super_armor_left <= 0.0:
		state = State.HURT
		state_time = 0.0
		velocity.x = signf(global_position.x - from_x) * EntriesData.KNOCKBACK_TO_PLAYER
		velocity.y = -60.0
	if hp <= 0:
		die()
	return true


func _perfect_parry(opts: Dictionary) -> void:
	# 完美弹反：敌人僵直 1s，玩家无敌 0.3s，自动反击剑气
	invuln_left = PR.invuln
	state = State.PARRY
	state_time = 0.0
	var attacker = opts.get("attacker", null)
	if attacker and is_instance_valid(attacker):
		attacker.take_parry(PR.enemy_stagger)
		_spawn_projectile({
			"dmg": PR.counter_qi_dmg, "speed": PR.counter_qi_speed, "range": PR.counter_qi_range,
			"dir": Vector2(signf(attacker.global_position.x - global_position.x), 0),
			"friendly": true, "kind": "qi",
		})
	# 劲波：完美弹反触发范围震波
	var wave := BuffManager.parry_wave()
	if not wave.is_empty():
		for h in combat.query_hosts_radius(global_position, wave.radius, [EntriesData.LAYER_ENEMY_HURT]):
			h.take_hit(wave.dmg, global_position.x, {"kb": 120.0, "kb_time": 0.1, "attacker": self})
			cm.register_hit(self)
		EventBus.fx_requested.emit("shock", global_position, false, 0.8)
	EventBus.hitstop_requested.emit(EntriesData.HITSTOP.parry)
	EventBus.shake_requested.emit(SHAKE.heavy_hit.x, SHAKE.heavy_hit.y)
	AudioManager.play_sfx("parry")
	EventBus.fx_requested.emit("parry", global_position + Vector2(0, -16), facing < 0, 1.0)


func die() -> void:
	dead = true
	state = State.DEATH
	state_time = 0.0
	velocity = Vector2.ZERO
	AudioManager.play_sfx("player_death")
	Engine.time_scale = EntriesData.DEATH_SLOWMO
	anim.play("death", true)
	# 真实时间 0.5s 慢动作后弹出结算
	get_tree().create_timer(EntriesData.DEATH_SLOWMO_TIME + 0.6, true, false, true).timeout.connect(_on_death_end)


func _on_death_end() -> void:
	Engine.time_scale = 1.0
	EventBus.player_died.emit()


# ---------------- 消耗品 / 恢复接口 ----------------

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	_emit_stats()


func regen_hp(amount: float) -> void:
	if hp < max_hp:
		hp = minf(max_hp, hp + amount)
		_emit_stats()


func refill_qi() -> void:
	qi = P.max_qi
	_emit_stats()


func refund_qi(amount: float) -> void:
	qi = minf(P.max_qi, qi + amount)
	_emit_stats()


func start_qi_half(duration: float) -> void:
	qi_half_left = duration


func start_super_armor(duration: float) -> void:
	super_armor_left = duration


func set_interactable(node: Node, text: String) -> void:
	near_interact = node
	EventBus.interact_changed.emit(text if node != null else "")


func _spawn_projectile(cfg: Dictionary) -> void:
	var p := PoolManager.spawn("projectile")
	if p:
		p.setup(cfg)
		p.global_position = global_position + Vector2(10 * facing, -16)


func _emit_stats() -> void:
	var qi_int := int(qi)
	if qi_int != _last_qi_emitted:
		_last_qi_emitted = qi_int
		EventBus.player_qi_changed.emit(qi_int, P.max_qi)
	EventBus.player_hp_changed.emit(int(hp), max_hp)


# ---------------- 动画 ----------------

func _anim_tick(delta: float, axis: float) -> void:
	var speed_scale := 1.0
	match state:
		State.IDLE:
			anim.play("idle")
		State.WALK:
			anim.play("walk")
		State.JUMP:
			anim.play("jump")
		State.FALL:
			anim.play("fall")
		State.COMBO:
			anim.play(atk_cfg.get("anim", "light_attack_1"))
			speed_scale = attack_speed
		State.DERIVE, State.FINISHER:
			anim.play(atk_cfg.get("anim", "finisher"))
		State.HEAVY_CHARGE:
			anim.play("heavy_charge")
		State.HEAVY_RELEASE:
			anim.play("heavy_release")
		State.BLOCK:
			anim.play("block")
		State.PARRY:
			anim.play("parry")
		State.DASH:
			anim.play("dash")
			speed_scale = 3.0
		State.HURT:
			anim.play("hurt")
		State.DEATH:
			pass
	anim.sprite.flip_h = facing < 0
	anim.advance(delta, speed_scale)
