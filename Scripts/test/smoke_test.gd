# smoke_test.gd — 端到端冒烟测试：跑完整 10 房流程（杀怪 / 词条三选一 / 商店 / 传送门 / BOSS / 休息点 / 死亡结算）
# 运行方式："$GODOT" --headless --path D:/game res://Scenes/test/smoke_test.tscn
extends Node

var failures: Array[String] = []
var _done := false   # 哨兵：_run 因脚本错误中途中止时保持 false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	if not _done:
		failures.append("测试中途异常中断（存在未捕获的脚本错误）")
	if failures.is_empty():
		print("SMOKE RESULT: OK")
	else:
		print("SMOKE RESULT: FAIL (%d)" % failures.size())
		for f in failures:
			print("  FAILED: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(msg: String, cond: bool) -> void:
	if cond:
		print("PASS  " + msg)
	else:
		failures.append(msg)
		print("FAIL  " + msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# 真实秒等待（headless 下帧率远高于 60fps，游戏内 tween/计时器按真实秒推进）
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


# 同时覆盖事件驱动（_unhandled_input）与轮询（is_action_just_pressed）两种输入读取方式
func _press(action: String) -> void:
	Input.action_press(action)
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(3)
	Input.action_release(action)
	var ev2 := InputEventAction.new()
	ev2.action = action
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await _frames(2)


func _live_enemies() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			out.append(e)
	return out


func _kill_all() -> void:
	for e in _live_enemies():
		e.take_hit(99999, e.global_position.x - 24.0, {})


func _use_portal(main: Node) -> void:
	# 走真实交互路径：瞬移到传送门 → 等 physics 帧拾取 Area 检测 → 按 E → 淡出换房
	# （headless 下 process 帧远快于 physics 帧，必须轮询等待 near_interact 指向传送门，
	#   否则按 E 会作用在旧交互目标上，例如重新打开商人商店）
	var room: RoomBase = main.room_mgr.current
	main.player.global_position = room.portal.global_position + Vector2(0, -6.0)
	main.player.velocity = Vector2.ZERO
	var waited := 0.0
	while main.player.near_interact != room.portal and waited < 1.0:
		await _wait(0.02)
		waited += 0.02
	_press("interact")
	await _wait(0.9)  # 0.25s 淡出 + 0.25s 淡入 + 余量（真实时间）


# 在舆图中选择指定类型（默认第一个）的可达节点；返回所选节点类型
func _choose_map_node(main: Node, want: String = "") -> String:
	var map: RunMap = GameManager.run_map
	var ids := map.reachable()
	var pick: int = int(ids[0])
	for id in ids:
		if want == "" or map.type_of(id) == want:
			pick = id
			break
	var chosen_type := map.type_of(pick)
	main._on_map_node_chosen(pick)
	await _wait(0.9)
	return chosen_type


func _await_room(main: Node, idx: int, clear: bool) -> void:
	GameManager.room_index = idx
	main.room_mgr.load_room(idx)
	await _frames(20)
	var room: RoomBase = main.room_mgr.current
	_check("房间 %d 加载：类型=%s" % [idx, EntriesData.ROOM_SEQUENCE[idx]], room.room_id == EntriesData.ROOM_SEQUENCE[idx])
	if clear:
		_kill_all()
		await _frames(15)
		_check("房间 %d 清怪完成（传送门激活）" % idx, room.cleared and room.portal.active)


# 直接装备武器（复刻 Q 切换逻辑，避免循环切换的不确定性）
func _equip(p: Node, wid: String) -> void:
	p.weapon_id = wid
	p.cm.weapon_id = wid
	p.cm.reset_combo()
	p.anim.char_id = "player_" + wid
	p.anim.play(p.anim.current, true)


# 直入普攻后摇状态（仍走 _combo_state 真实消费路径；recovery 可调以便测取消窗口边界）
func _combo_recovery(p: Node, recovery: float = 1.0) -> void:
	p.buf_attack = 0.0
	p.buf_jump = 0.0
	p.buf_dash = 0.0
	p.buf_derive = 0.0
	p.dash_cd_left = 0.0
	p.jump_cancel_cd = 0.0
	p.state = p.State.COMBO
	p.attack_phase = "recovery"
	p.attack_speed = 1.0
	p.atk_cfg = {"dmg": 8, "windup": 0.06, "recovery": recovery, "size": Vector2(24, 20),
		"offset": 16.0, "kb": 150.0, "kb_time": 0.15, "anim": "light_attack_1"}
	p.state_time = 0.0
	p.cm.combo_index = 1
	p.cm.air_combo = false
	p.cm.auto_chain = false


func _p1_weapons(p: Node, cm: ComboManager) -> void:
	# 防止测试招式误杀敌人，导致后续浮空/眩晕测试无目标
	for e in _live_enemies():
		e.hp = 999
	# 卡池过滤：未持有短刃时专属词条不入池（须在下方商店购买之前检查）
	_check("未持有短刃时专属词条不入池", not ("dr_shan_ci" in BuffManager.offer_pool()))
	# ===== 商店武器陈列与购买（策划案 4.6：随机 1 把，80 尘珠）=====
	# 此时持有 changjian/zhongjian/changge，商铺必陈列 duanren
	var shop: CanvasLayer = load("res://Scenes/UI/panel_shop.tscn").instantiate()
	get_tree().root.add_child(shop)
	await _frames(5)
	var weapon_items: Array = []
	for it in shop.items:
		if it.type == "weapon":
			weapon_items.append(it)
	_check("商铺陈列恰好 1 把未持有武器", weapon_items.size() == 1)
	if weapon_items.size() == 1:
		_check("武器售价 80 尘珠", weapon_items[0].price == EntriesData.WEAPON_PRICE)
		GameManager.add_gold(EntriesData.WEAPON_PRICE)
		shop.sel = shop.items.find(weapon_items[0])
		shop._buy()
		_check("商店购买武器入库 (%s)" % weapon_items[0].id, GameManager.has_weapon(weapon_items[0].id))
		_check("购买后武器下架", shop.items.filter(func(it): return it.type == "weapon").is_empty())
	shop.queue_free()
	await _frames(3)
	# ===== 重剑・破甲型 =====
	_equip(p, "zhongjian")
	_check("重剑取消窗口 0.05s（窄）", is_equal_approx(cm.cancel_window(), 0.05))
	_check("重剑默认 2 段", cm.chain_size() == 2)
	BuffManager.add_entry("zj_3rd")
	_check("解锁后重剑 3 段（崩山劈）", cm.chain_size() == 3)
	var zj3: Dictionary = cm.chain_segments()[2]
	_check("崩山劈附带破甲禁格挡 3s", zj3.armor_break and zj3.guard_ban == 3.0)
	# 震地砸：1 段中 S+K（判定盒 48×20，前方 12px 起 → 中心偏移 12+24=36）
	BuffManager.add_entry("zj_zhen_di")
	var zd: Dictionary = cm.derives_for(1)[0]
	_check("震地砸判定盒 48×20 前方 12px 起 + 眩晕 0.4s",
		zd.size == Vector2(48, 20) and zd.offset == 36.0 and zd.stun == 0.4)
	p._start_derive(zd)
	_check("震地砸进入 DERIVE", p.state == p.State.DERIVE)
	await _wait(0.6)
	# 架招反击：2 段中按 L → 直入弹反预备（窗口 0.25s）
	BuffManager.add_entry("zj_jia_zhao")
	var jz: Dictionary = cm.derive_by_trigger(2, "block")
	_check("架招反击派生可查询", not jz.is_empty())
	p._start_derive(jz)
	_check("架招反击进入 BLOCK 且窗口 0.25s", p.state == p.State.BLOCK and is_equal_approx(p.parry_window_override, 0.25))
	p._exit_block()
	# 蓄力派生：后摇中按住 K，满蓄伤害 +50% + 破甲
	var cd_cfg: Dictionary = cm.derive_by_trigger(0, "hold")
	_check("蓄力派生存在（最长 0.8s）", not cd_cfg.is_empty() and cd_cfg.max_charge == 0.8)
	p._start_charge_from_combo()
	_check("蓄力派生进入蓄力状态", p.state == p.State.HEAVY_CHARGE and p.charge_from_combo)
	p.charge_time = 0.8
	p._release_combo_charge()
	_check("满蓄派生破甲 + 伤害 +50%", p.atk_cfg.armor_break and p.atk_cfg.dmg == int(cd_cfg.dmg * 1.5))
	await _wait(0.6)
	# 裂岳斩：2 段中按 K
	p.qi = EntriesData.PLAYER.max_qi
	p.cm.combo_index = cm.chain_size()
	p._start_finisher()
	_check("裂岳斩进入 FINISHER", p.state == p.State.FINISHER)
	_check("裂岳斩消耗 35 内息", int(p.qi) == EntriesData.PLAYER.max_qi - 35)
	await _wait(0.8)

	# ===== 短刃・高速型 =====
	_check("持有短刃后专属词条入池", "dr_shan_ci" in BuffManager.offer_pool())
	_equip(p, "duanren")
	_check("短刃取消窗口 0.15s（宽）", is_equal_approx(cm.cancel_window(), 0.15))
	_check("短刃默认 4 段", cm.chain_size() == 4)
	BuffManager.add_entry("dr_56")
	_check("解锁后短刃 6 段", cm.chain_size() == 6)
	# 闪刺：2 段中方向+K，突进 120px
	BuffManager.add_entry("dr_shan_ci")
	var sc: Dictionary = cm.derives_for(2)[0]
	_check("闪刺突进 120px", sc.dash_strike == 120.0)
	p._start_derive(sc)
	_check("闪刺进入 DERIVE", p.state == p.State.DERIVE)
	await _wait(0.4)
	# 空中连斩：3 段中按跳跃，自动起跳接空中 3 段（不消耗二段跳）
	BuffManager.add_entry("dr_kong_zhong")
	var kj: Dictionary = cm.derive_by_trigger(3, "jump")
	_check("空中连斩派生可查询", not kj.is_empty() and kj.air_chain.size() == 3)
	var jumps_left: int = p.air_jumps
	p._start_derive(kj)
	_check("空中连斩进入空中 COMBO", p.state == p.State.COMBO and cm.auto_chain and cm.air_combo)
	_check("空中连斩不消耗二段跳", p.air_jumps == jumps_left)
	_check("空中链段数为 3", cm.chain_size() == 3)
	cm.reset_combo()
	await _wait(0.3)
	# 影袭：4 段中按 K，瞬移到敌人身后
	var foes := _live_enemies()
	if foes.size() > 0:
		# 挑状态稳定的最近敌人作目标：扑击/突进/浮空中的敌人带惯性飞行，
		# 可能把自身带出影袭 150px 索敌圈（超距原地释放为策划案正常机制，非 bug）。
		# 稳定敌人 0.12s 观察窗内最多走 ~30px（≤280px/s），必然留在索敌圈内。
		var stable := foes.filter(func(e): return e.state not in [
			EnemyBase.EState.ACT, EnemyBase.EState.WINDUP, EnemyBase.EState.LAUNCHED])
		if stable.is_empty():
			stable = foes
		var near_e: Node2D = stable[0]
		var near_d: float = p.global_position.distance_to(stable[0].global_position)
		for e in stable:
			var d: float = p.global_position.distance_to(e.global_position)
			if d < near_d:
				near_d = d
				near_e = e
		# 敌人可能恰好站在平台/悬空处（扑击落点、边缘坠落），若按其原位摆玩家，
		# 玩家会悬空下落，后续所有按玩家位置摆敌人的测试全部失真（曾致 pierce/影袭随机失败）。
		# → 先把目标敌人挪到地面空旷处，再在其左侧摆玩家，保证双方均站稳地面。
		var floor_y: float = p.get_parent().room_mgr.current.layout.floor_y
		var ground_x: float = clampf(near_e.global_position.x, 160.0, 800.0)
		near_e.global_position = Vector2(ground_x, floor_y - 1.0)
		near_e.velocity = Vector2.ZERO
		p.global_position = near_e.global_position + Vector2(-100.0, 0)
		p.velocity = Vector2.ZERO
		await _frames(2)
		var px0: float = p.global_position.x
		p.qi = EntriesData.PLAYER.max_qi
		p.cm.combo_index = 4
		p._start_finisher()
		_check("影袭进入 FINISHER", p.state == p.State.FINISHER)
		# 瞬移发生在前摇结束的攻击帧；攻击帧结束后立即检查，避免敌人移动干扰距离判定
		var guard := 0.0
		while guard < 0.5:
			await _wait(0.02)
			guard += 0.02
			if p.attack_phase == "recovery" or p.state != p.State.FINISHER:
				break
		var beside_enemy := false
		for e in _live_enemies():
			if absf(p.global_position.x - e.global_position.x) <= 40.0:
				beside_enemy = true
		_check("影袭瞬移至敌人身后", p.global_position.x != px0 and beside_enemy)
		await _wait(0.6)
		# 背刺被动：身处敌人出招方向背后伤害 ×2
		near_e.committed_facing = 1
		p.global_position = near_e.global_position + Vector2(-40.0, 0)
		var dmg_back: int = p._strike_damage({"dmg": 10}, "normal", near_e)
		p.global_position = near_e.global_position + Vector2(40.0, 0)
		var dmg_front: int = p._strike_damage({"dmg": 10}, "normal", near_e)
		_check("背刺伤害翻倍 (%d vs %d)" % [dmg_back, dmg_front], dmg_back == dmg_front * 2)
		p.global_position = near_e.global_position + Vector2(-60.0, 0)

	# ===== 长戈・控场型 =====
	_equip(p, "changge")
	_check("长戈默认 2 段", cm.chain_size() == 2)
	BuffManager.add_entry("cg_3rd")
	_check("解锁后长戈 3 段（横扫千军）", cm.chain_size() == 3)
	var cg3: Dictionary = cm.chain_segments()[2]
	_check("横扫千军 360°（居中 80×16）", cg3.size == Vector2(80, 16) and cg3.offset == 0.0)
	# 回马枪：1 段中 A+K（背向），判定盒在身后
	BuffManager.add_entry("cg_hui_ma")
	var hm: Dictionary = cm.derives_for(1)[0]
	_check("回马枪背向判定（offset=-28）", hm.dir == "back" and hm.offset == -28.0)
	p._start_derive(hm)
	_check("回马枪进入 DERIVE", p.state == p.State.DERIVE)
	await _wait(0.5)
	# 挑飞：2 段中 W+K，群体浮空
	BuffManager.add_entry("cg_tiao_fei")
	var tf: Dictionary = cm.derives_for(2)[0]
	_check("挑飞带浮空标记", tf.launch == true)
	# 穿刺穿透（被动）：持长戈时派生攻击沿攻击方向穿透至多 3 个敌人
	var pierce_foes := _live_enemies()
	if pierce_foes.size() >= 2:
		# 敌人定身（受击硬直态）便于摆位
		for e in pierce_foes:
			e.state = EnemyBase.EState.HURT
			e.stagger_time = 5.0
			e.state_time = 0.0
			e.velocity = Vector2.ZERO
		# 回马枪判定盒：身后 4~52px；穿透延伸段依次向身后再扫 48px
		pierce_foes[0].global_position = p.global_position + Vector2(-30.0, 0)
		pierce_foes[1].global_position = p.global_position + Vector2(-90.0, 0)
		p.facing = 1
		await _wait(0.05)  # 等 physics 同步摆位（敌人已定身）
		var far_hp: int = int(pierce_foes[1].hp)
		p._execute_strike(hm, "derive")
		_check("穿刺穿透：延伸判定命中判定盒外的敌人", int(pierce_foes[1].hp) < far_hp)
		for e in pierce_foes:
			e.stagger_time = 0.25
	# 穿云刺：2 段中按 K，超远穿刺 88×10
	p.qi = EntriesData.PLAYER.max_qi
	p.cm.combo_index = 2
	p._start_finisher()
	_check("穿云刺进入 FINISHER", p.state == p.State.FINISHER)
	_check("穿云刺消耗 28 内息", int(p.qi) == EntriesData.PLAYER.max_qi - 28)
	await _wait(0.7)
	_equip(p, "changjian")
	_check("四武器全部持有", ["changjian", "zhongjian", "duanren", "changge"].all(
		func(wid): return GameManager.has_weapon(wid)))


func _run() -> void:
	# ---- 启动一局（不经过主菜单，直接实例化 Main 场景）----
	GameManager.gold = EntriesData.ECONOMY.start_gold
	GameManager.kills = 0
	GameManager.run_time = 0.0
	GameManager.room_index = 0
	GameManager.in_run = true
	BuffManager.reset()
	var main: Node2D = load(EntriesData.MAIN_SCENE).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames(30)
	var p: Node2D = main.player
	_check("玩家已生成", p != null and is_instance_valid(p))
	_check("HUD 已挂载", main.hud != null)
	_check("HUD 血瓶图标已加载", main.hud.flask_icon != null and main.hud.flask_icon.texture != null)
	_check("玩家注册到 GameManager", GameManager.player == p)

	# ---- 分支舆图：开局弹出境界图，选择可达的战斗节点进入 ----
	_check("开局弹出秘境界图", get_tree().paused and main._overlay != null
		and main._overlay.name == "MapScreen")
	_check("舆图起点有分支可选", main._overlay != null and main._overlay.reachable.size() >= 2)
	var first_type: String = await _choose_map_node(main, "combat")
	var room: RoomBase = main.room_mgr.current
	_check("首间房为 combat（所选节点=%s）" % first_type, room.room_id == "combat")
	_check("战斗房 BGM 切换到探索曲", AudioManager._current_bgm == "bgm_explore")
	_check("combat 房已刷新敌人", room.enemies_alive >= 2)

	# ---- 玩家受击 ----
	var hp0: int = int(p.hp)
	p.take_hit(10, p.global_position.x + 24.0, {})
	await _frames(3)
	_check("玩家受击扣血 (%d → %d)" % [hp0, int(p.hp)], int(p.hp) == hp0 - 10)
	# 全程测试期间无敌，避免等待帧时被敌人围殴致死
	p.invuln_left = 9999.0

	# ---- 血瓶：初始 3 次，R 键回复 40，满血不消耗 ----
	_check("初始血瓶 3 次", GameManager.flasks == EntriesData.FLASK.max_uses)
	p.hp = 30.0
	Input.action_press("use_flask")
	await _wait(0.08)
	Input.action_release("use_flask")
	await _frames(2)
	_check("R 键血瓶回复 40 生命 (%d → %d)" % [30, int(p.hp)], int(p.hp) == 70)
	_check("使用后血瓶剩 2 次", GameManager.flasks == 2)
	_check("HUD 血瓶计数同步为 ×2", main.hud.flask_label.text == "×2")
	p.hp = p.max_hp
	Input.action_press("use_flask")
	await _wait(0.08)
	Input.action_release("use_flask")
	await _frames(2)
	_check("满血时不消耗血瓶", GameManager.flasks == 2)

	# 近满血使用：回复量按生命上限截断
	p.hp = 90.0
	Input.action_press("use_flask")
	await _wait(0.08)
	Input.action_release("use_flask")
	await _frames(2)
	_check("血瓶回复不超过生命上限 (90 → %d)" % int(p.hp), int(p.hp) == p.max_hp)
	_check("近满血使用消耗 1 次", GameManager.flasks == 1)

	# 最后一次：正常使用至 0，HUD 置灰
	p.hp = 20.0
	Input.action_press("use_flask")
	await _wait(0.08)
	Input.action_release("use_flask")
	await _frames(2)
	_check("最后一次血瓶正常消耗", GameManager.flasks == 0)
	_check("HUD 血瓶计数显示 ×0", main.hud.flask_label.text == "×0")
	_check("HUD 血瓶图标置灰", main.hud.flask_icon.modulate.a < 0.5)

	# 次数耗尽：不可使用
	var hp_no_flask: float = p.hp
	Input.action_press("use_flask")
	await _wait(0.08)
	Input.action_release("use_flask")
	await _frames(2)
	_check("次数为 0 时血瓶不可使用", GameManager.flasks == 0 and p.hp == hp_no_flask)

	GameManager.refill_flasks()
	p.hp = p.max_hp
	_check("补满后 HUD 图标恢复", main.hud.flask_icon.modulate.a > 0.9)

	# ---- 玩家近战命中敌人（真实 hitbox 查询）----
	var foes := _live_enemies()
	_check("房内存活敌人为空则异常", foes.size() > 0)
	if foes.size() > 0:
		var e0: Node2D = foes[0]
		var ehp: int = int(e0.hp)
		var hb: Dictionary = EntriesData.LIGHT_ATTACKS[0]
		var hits: Array = p.combat.query_hosts(
			e0.global_position + Vector2(0, -20), Vector2(64, 64),
			[EntriesData.LAYER_ENEMY_HURT])
		_check("战斗组件可查询到敌人 hurtbox", hits.size() > 0)
		e0.take_hit(int(hb.dmg), p.global_position.x, {})
		await _frames(2)
		_check("敌人受击掉血", int(e0.hp) < ehp)

	# ---- v2.0 连招系统：普攻链 / 派生 / 终结技 / 武器切换 / 连击 ----
	# 先等受击硬直（0.18s）恢复到 IDLE 再测试连招
	await _wait(0.4)

	# ---- K 键短按 / 按住阈值 0.15s（策划案第二节 K 键语义裁决）----
	# 注意：headless 下 process 帧远快于 physics 帧，须用真实时间等待保证物理帧消费输入
	# 重击 35 伤害会秒杀 25/30 血敌人，提前垫血防止后续测试（影袭/穿刺/浮空）无目标
	for e in _live_enemies():
		e.hp = 999
	p.cm.reset_hits(false)
	p.qi = EntriesData.PLAYER.max_qi
	var qi_t0: int = int(p.qi)
	Input.action_press("heavy_attack")
	var evh := InputEventAction.new()
	evh.action = "heavy_attack"
	evh.pressed = true
	Input.parse_input_event(evh)
	await _wait(0.05)
	_check("K 按下进入蓄力状态", p.state == p.State.HEAVY_CHARGE)
	Input.action_release("heavy_attack")
	var evh2 := InputEventAction.new()
	evh2.action = "heavy_attack"
	evh2.pressed = false
	Input.parse_input_event(evh2)
	await _wait(0.05)
	_check("K 短按（<0.15s）不出招不耗内息，直接收势",
		p.state != p.State.HEAVY_RELEASE and int(p.qi) == qi_t0)
	Input.action_press("heavy_attack")
	var evh3 := InputEventAction.new()
	evh3.action = "heavy_attack"
	evh3.pressed = true
	Input.parse_input_event(evh3)
	await _wait(0.25)
	Input.action_release("heavy_attack")
	var evh4 := InputEventAction.new()
	evh4.action = "heavy_attack"
	evh4.pressed = false
	Input.parse_input_event(evh4)
	await _wait(0.05)
	_check("K 按住 ≥0.15s 释放蓄力重击（消耗内息）",
		p.state == p.State.HEAVY_RELEASE and int(p.qi) < qi_t0)
	await _wait(0.6)  # 等重击后摇结束回 IDLE

	var cm: ComboManager = p.cm
	_check("默认长剑连段为 3 段（第 4 段锁定）", cm.chain_size() == 3)
	BuffManager.add_entry("cs_4th")
	_check("解锁词条后长剑 4 段", cm.chain_size() == 4)
	# 输入驱动：普攻缓冲进入连招状态（headless 下 is_action_just_pressed
	# 与物理帧时序不稳定，此处直接写输入缓存，仍走真实消费路径）
	p.buf_attack = ComboData.INPUT_BUFFER
	await _wait(0.12)
	_check("普攻进入 COMBO 状态", p.state == p.State.COMBO)
	await _wait(0.4)
	# 派生技：第 1 段中 W+K → 上挑（浮空标记）
	BuffManager.add_entry("cs_shang_tiao")
	p._start_combo_segment(1, false)
	p._start_derive(ComboData.derives_for("changjian", 1)[0])
	_check("派生技进入 DERIVE 状态", p.state == p.State.DERIVE)
	await _wait(0.5)
	# 终结技：普攻链最后一段中按 K
	cm.combo_index = cm.chain_size()
	p._start_finisher()
	_check("终结技进入 FINISHER 状态", p.state == p.State.FINISHER)
	await _wait(0.9)
	_check("终结技后摇结束回常态", p.state == p.State.IDLE or p.state == p.State.WALK)

	# ---- 弹反取消：普攻后摇中按 L 打断，进入格挡且弹反窗口从取消瞬间起算 ----
	# （策划案第二节取消机制优先级：dash 与 perfect_parry 可打断普攻链后摇）
	p.buf_attack = 0.0
	p.buf_jump = 0.0
	p.buf_dash = 0.0
	p.buf_derive = 0.0
	p.state = p.State.COMBO
	p.attack_phase = "recovery"
	p.attack_speed = 1.0
	p.atk_cfg = {"dmg": 8, "windup": 0.06, "recovery": 1.0, "size": Vector2(24, 20),
		"offset": 16.0, "kb": 150.0, "kb_time": 0.15, "anim": "light_attack_1"}
	p.state_time = 0.0
	p.cm.combo_index = 1
	p.qi = EntriesData.PLAYER.max_qi
	Input.action_press("block")
	var evb := InputEventAction.new()
	evb.action = "block"
	evb.pressed = true
	Input.parse_input_event(evb)
	await _wait(0.05)
	_check("弹反取消进入格挡（弹反窗口已重置）",
		p.state == p.State.BLOCK and p.parry_elapsed >= 0.0 and p.parry_elapsed <= 0.2)
	Input.action_release("block")
	var evb2 := InputEventAction.new()
	evb2.action = "block"
	evb2.pressed = false
	Input.parse_input_event(evb2)
	await _wait(0.05)
	_check("松开格挡退出格挡态", p.state != p.State.BLOCK)
	# 武器切换（Q 键循环）
	GameManager.own_weapon("zhongjian")
	await _press("switch_weapon")
	_check("Q 切换到重剑", p.weapon_id == "zhongjian" and p.anim.char_id == "player_zhongjian")
	_check("切换武器后连击清零", cm.hit_count == 0 and cm.combo_index == 0)
	await _press("switch_weapon")
	_check("Q 切回长剑", p.weapon_id == "changjian")

	# ---- P0.5 验收补全：连击规则 / 三种取消机制 / 衔接窗口 / 输入缓存 / 空武 ----
	# 连击增伤：独立乘区（每 10 连击 +3%，封顶 30%）
	cm.reset_hits(false)
	cm.hit_count = 10
	_check("连击增伤：10 连击 +3%", is_equal_approx(cm.hit_damage_mult(), 1.03))
	cm.hit_count = 100
	_check("连击增伤：100 连击封顶 +30%", is_equal_approx(cm.hit_damage_mult(), 1.30))
	cm.hit_count = 200
	_check("连击增伤不超 30% 上限", is_equal_approx(cm.hit_damage_mult(), 1.30))
	# 连击精通：上限升至 50%，每 10 连击 +5%
	BuffManager.owned.append("lian_ji_tong")
	cm.hit_count = 100
	_check("连击精通：100 连击 +50%", is_equal_approx(cm.hit_damage_mult(), 1.50))
	BuffManager.owned.erase("lian_ji_tong")
	cm.reset_hits(false)

	# 连击里程碑：每 10 连击脉冲（信号 + 音效）
	var milestones: Array = []
	var mh: Callable = func(c: int): milestones.append(c)
	EventBus.combo_milestone.connect(mh)
	cm.hit_count = 9
	cm.register_hit(p)
	EventBus.combo_milestone.disconnect(mh)
	_check("每 10 连击触发里程碑脉冲", milestones.size() == 1 and milestones[0] == 10)
	cm.reset_hits(false)

	# 断档规则：受击清零；「不断」词条仅减半
	cm.hit_count = 13
	cm.reset_hits(true)
	_check("受击断档连击清零", cm.hit_count == 0)
	cm.hit_count = 21
	BuffManager.owned.append("bu_duan")
	cm.reset_hits(true)
	_check("不断：受击连击减半 (21→10)", cm.hit_count == 10)
	BuffManager.owned.erase("bu_duan")
	cm.reset_hits(false)

	# 连击计时器 1.5s：超时自动清零
	cm.hit_count = 5
	cm.hit_timer = 0.1
	await _wait(0.3)
	_check("连击计时器超时自动清零", cm.hit_count == 0)

	# ---- 闪避取消：攻击后摇前半段 Shift 打断，连招内半价 15 内息 ----
	_combo_recovery(p, 1.0)
	p.qi = EntriesData.PLAYER.max_qi
	p.buf_dash = ComboData.INPUT_BUFFER
	await _wait(0.05)
	_check("闪避取消打断普攻后摇进入 DASH", p.state == p.State.DASH)
	_check("连招内闪避取消半价 15 内息", int(p.qi) == EntriesData.PLAYER.max_qi - 15)
	await _wait(0.4)  # 等 dash 结束回常态

	# 疾影：取消窗口 +0.1s，闪避取消内息降至 7
	BuffManager.owned.append("ji_ying")
	_check("疾影扩展取消窗口 (0.10+0.10)", is_equal_approx(cm.cancel_window(), 0.20))
	_combo_recovery(p, 1.0)
	p.qi = EntriesData.PLAYER.max_qi
	p.buf_dash = ComboData.INPUT_BUFFER
	await _wait(0.05)
	_check("疾影闪避取消仅耗 7 内息", p.state == p.State.DASH and int(p.qi) == EntriesData.PLAYER.max_qi - 7)
	BuffManager.owned.erase("ji_ying")
	await _wait(0.4)

	# 后摇后半段（>50%）不可再取消
	_combo_recovery(p, 1.0)
	p.state_time = 0.8
	p.buf_dash = ComboData.INPUT_BUFFER
	await _wait(0.1)
	_check("后摇后半段不可取消", p.state == p.State.COMBO)
	p.buf_dash = 0.0
	await _wait(0.6)

	# ---- 跳跃取消：默认锁定，「行云」解锁后可打断后摇（0.2s 冷却） ----
	_combo_recovery(p, 1.0)
	p.buf_jump = ComboData.INPUT_BUFFER
	await _wait(0.05)
	_check("未解锁行云时不可跳跃取消", p.state == p.State.COMBO)
	BuffManager.owned.append("xing_yun")
	p.buf_jump = ComboData.INPUT_BUFFER
	await _wait(0.05)
	_check("行云解锁跳跃取消后摇", p.state == p.State.JUMP)
	_check("跳跃取消进入 0.2s 冷却", p.jump_cancel_cd > 0.05 and p.jump_cancel_cd <= 0.201)
	BuffManager.owned.erase("xing_yun")
	await _wait(1.2)  # 等跳跃落地回常态

	# ---- 派生取消：命中瞬间起的窗口内 W+K 触发上挑（长剑窗口 0.10s） ----
	Input.action_press("dir_up")
	_combo_recovery(p, 1.0)
	p.buf_derive = ComboData.INPUT_BUFFER
	await _wait(0.05)
	Input.action_release("dir_up")
	_check("派生取消窗口内 W+K 触发上挑", p.state == p.State.DERIVE)
	await _wait(0.5)
	# 窗口过后缓冲失效
	_combo_recovery(p, 1.0)
	p.state_time = 0.2
	p.buf_derive = ComboData.INPUT_BUFFER
	await _wait(0.05)
	_check("派生取消窗口过后 K 不触发", p.state == p.State.COMBO)
	p.buf_derive = 0.0
	await _wait(0.9)

	# ---- 终结技：最后一段后摇中缓冲 K 直接触发青云斩 ----
	_combo_recovery(p, 1.0)
	p.cm.combo_index = cm.chain_size()
	p.qi = EntriesData.PLAYER.max_qi
	p.buf_derive = ComboData.INPUT_BUFFER
	await _wait(0.05)
	_check("最后一段按 K 触发终结技", p.state == p.State.FINISHER)
	_check("青云斩消耗 25 内息", int(p.qi) == EntriesData.PLAYER.max_qi - 25)
	await _wait(0.9)

	# ---- 衔接窗口 0.3s：窗口内续段，超时重置段数 ----
	_combo_recovery(p, 1.0)
	await _wait(1.05)
	_check("后摇结束段数保留待续", p.state != p.State.COMBO and cm.combo_index == 1)
	p.buf_attack = ComboData.INPUT_BUFFER
	await _wait(0.06)
	_check("衔接窗口内按 J 续接第 2 段", p.state == p.State.COMBO and cm.combo_index == 2)
	await _wait(0.8)
	_check("衔接窗口超时重置段数", cm.combo_index == 0)
	p.buf_attack = ComboData.INPUT_BUFFER
	await _wait(0.06)
	_check("超时后按 J 从第 1 段重新起手", p.state == p.State.COMBO and cm.combo_index == 1)
	await _wait(0.6)

	# ---- 输入缓存 0.2s：提前按下 J，到可衔接帧自动触发下一段 ----
	p._start_combo_segment(1, false)
	await _wait(0.09)
	p.buf_attack = ComboData.INPUT_BUFFER
	await _wait(0.15)
	_check("输入缓存：后摇末端提前按 J 自动衔接第 2 段", p.state == p.State.COMBO and cm.combo_index == 2)
	await _wait(0.6)

	# ---- 空武：未解锁时空中不可普攻；解锁后空中按 J 进入空中连招 ----
	# 摆到 x=480（房 0 平台 x 范围 [200,360] / [560,688] 之外），保证垂直落向主地面
	var floor_y: float = main.room_mgr.current.layout.floor_y
	BuffManager.owned.erase("cs_shang_tiao")
	p.global_position = Vector2(480.0, floor_y - 120.0)
	p.velocity = Vector2.ZERO
	p.state = p.State.FALL
	await _wait(0.05)
	p.buf_attack = ComboData.INPUT_BUFFER
	await _wait(0.05)
	_check("未解锁空武时空中不可普攻", p.state != p.State.COMBO)
	BuffManager.owned.append("cs_shang_tiao")
	p.state = p.State.FALL
	p.buf_attack = ComboData.INPUT_BUFFER
	await _wait(0.05)
	_check("空武：空中按 J 进入空中连招", p.state == p.State.COMBO and cm.air_combo == true)
	_check("空中连招段数锁定前 3 段", cm.chain_size() == ComboData.AIR_CHAIN_SEGMENTS)
	# 落地收招：清段退出空中连招
	var air_guard := 0.0
	while air_guard < 1.5 and not p.is_on_floor():
		await _wait(0.05)
		air_guard += 0.05
	_check("空中连招落地收招清段", p.is_on_floor() and not cm.air_combo and cm.combo_index == 0)
	cm.reset_hits(false)
	cm.reset_combo()
	await _wait(0.2)

	# ---- 山魈扑击回归：修复前扑跃起跳后 ACT 不受重力，恒速飞天永不落地 ----
	var pounce_foes := _live_enemies()
	if pounce_foes.size() > 0:
		var pk: Node2D = pounce_foes[0]
		pk.cfg = EntriesData.ENEMIES.shan_xiao
		pk.enemy_id = "shan_xiao"
		pk.aggro = true
		pk.state = EnemyBase.EState.CHASE
		pk.cd_left = 0.0
		pk.hp = 999
		pk.velocity = Vector2.ZERO
		# 其余敌人挪远并压住攻击 CD，避免阻挡扑跃弹道
		for e in pounce_foes:
			if e != pk:
				e.global_position = Vector2(880.0, floor_y - 1.0)
				e.cd_left = 5.0
		p.global_position = Vector2(420.0, floor_y - 1.0)
		p.velocity = Vector2.ZERO
		pk.global_position = Vector2(540.0, floor_y - 1.0)
		await _wait(0.05)
		var pk_y0: float = pk.global_position.y
		# 前摇 0.25s + 弹道 0.55s + 落地判定：1.2s 内应落地进入 RECOVER
		var pounce_guard := 0.0
		while pounce_guard < 1.2 and pk.state != EnemyBase.EState.RECOVER:
			await _wait(0.05)
			pounce_guard += 0.05
		_check("山魈扑击起跳后正常落地（不飞天）",
			pk.state == EnemyBase.EState.RECOVER and absf(pk.global_position.y - pk_y0) < 20.0)
		pk.cd_left = 99.0   # 压住后续扑击，避免干扰后续测试摆位
		await _wait(0.4)

	# ---- P1 四武器全量：重剑 / 短刃 / 长戈（派生 + 终结技 + 被动 + 商店购买）----
	GameManager.own_weapon("changge")
	await _p1_weapons(p, cm)

	# 连击计数与最高连击
	cm.reset_hits(false)
	for i in 12:
		cm.register_hit(p)
	_check("连击计数累计 12", cm.hit_count == 12)
	_check("最高连击已记录 (max=%d)" % GameManager.max_combo, GameManager.max_combo >= 12)
	cm.reset_hits(false)
	_check("连击清零", cm.hit_count == 0)

	# ---- 敌人浮空 / 眩晕 / 减速（v2.0 第五节）----
	# 上挑 / 挑飞 / 空中连斩词条须同步解锁空中连招（策划案：解锁空中追击）
	_check("上挑词条解锁空中追击", BuffManager.air_combo_unlocked())
	# 重新取存活敌人：早前捕获的 foes 可能已在连招测试中死亡释放
	var state_foes := _live_enemies()
	if state_foes.size() > 0:
		var e1: Node2D = state_foes[0]
		e1.take_hit(1, e1.global_position.x - 10.0, {"launch": true})
		_check("敌人被挑空进入 LAUNCHED", e1.state == e1.EState.LAUNCHED)
		await _wait(1.4)   # 滞空 + 落地硬直 1s
		e1.take_hit(1, e1.global_position.x - 10.0, {"stun": 0.4})
		_check("敌人眩晕生效 (stun_left=%.2f)" % e1.stun_left, e1.stun_left > 0.0)
		e1.take_hit(1, e1.global_position.x - 10.0, {"slow": true})
		e1.take_hit(1, e1.global_position.x - 10.0, {"slow": true})
		_check("敌人减速叠至 2 层", e1.slow_stacks == 2)
		_check("测试伤害未击杀敌人", not e1.dead)

	# ---- 房 0：站在传送门圈内清怪 → 提示文案须即时刷新（回归：清完怪仍显示「封印未解」）----
	p.global_position = room.portal.global_position + Vector2(0, -6.0)
	p.velocity = Vector2.ZERO
	var hint_wait := 0.0
	while p.near_interact != room.portal and hint_wait < 1.0:
		await _wait(0.02)
		hint_wait += 0.02
	_check("清怪前传送门提示为封印", main.hud.hint_label.text.contains("封印"))
	_kill_all()
	await _frames(15)
	_check("房 0 清怪后传送门激活", room.cleared and room.portal.active)
	_check("站在门内清怪后提示即时刷新", main.hud.hint_label.text == "按 E 进入下一间")
	_check("击杀数已累计 (kills=%d)" % GameManager.kills, GameManager.kills >= 2)  # combat 房 2-3 只

	# 暂停菜单冒烟
	_press("pause")
	await _frames(6)
	_check("暂停菜单已打开", get_tree().paused and main._overlay != null)
	_press("pause")  # Esc 恢复
	await _frames(6)
	_check("暂停菜单已关闭", not get_tree().paused and main._overlay == null)

	# ---- 传送门 → 分支舆图：走真实键盘路径选择分支 ----
	await _use_portal(main)
	_check("传送门后弹出分支舆图", get_tree().paused and main._overlay != null
		and main._overlay.name == "MapScreen")
	_check("舆图提供至少一个分支", main._overlay != null and main._overlay.reachable.size() >= 1)
	_press("light_attack")   # J 确认当前高亮分支
	await _wait(0.9)
	_check("键盘确认后进入所选房间", main.room_mgr.current != null and not get_tree().paused
		and main.room_mgr.current.room_id == GameManager.run_map.type_of(GameManager.run_map.current_id))

	# ---- 精英房：直接加载验证（词条三选一）----
	await _await_room(main, 3, true)
	var elite_room: RoomBase = main.room_mgr.current
	_check("精英房类型为 elite", elite_room.room_id == "elite")
	var elite_owned := BuffManager.owned.size()
	# 精英房通关 → 词条三选一（树暂停，按 J 选第一张）
	_check("精英房清怪后弹出词条三选一（树暂停+面板）", get_tree().paused and main._overlay != null)
	_press("light_attack")
	await _frames(8)
	_check("词条选择后恢复运行", not get_tree().paused)
	_check("已获得 1 条词条", BuffManager.owned.size() == elite_owned + 1)

	# ---- 商铺：直接加载验证商人交互 ----
	await _await_room(main, 6, false)
	var shop_room: RoomBase = main.room_mgr.current
	_check("商店房已自动清空（传送门激活）", shop_room.cleared and shop_room.portal.active)
	var merchant: Area2D = null
	for c in shop_room.get_children():
		if c is Area2D and c.has_signal("opened"):
			merchant = c
	_check("商人在场", merchant != null)
	if merchant:
		p.global_position = merchant.global_position + Vector2(-30.0, 0.0)
		p.velocity = Vector2.ZERO
		await _frames(6)
		_press("interact")  # 打开商铺
		await _frames(8)
		_check("商铺面板已打开", get_tree().paused and main._overlay != null)
		GameManager.add_gold(500)  # 保证买得起
		_press("light_attack")  # J 购买第 1 件
		await _frames(8)
		_press("pause")  # Esc 关闭商铺
		await _frames(8)
		_check("商铺关闭后恢复", not get_tree().paused)

	# ---- 试炼：直接加载验证（30s 内杀 4 只 → 双词条三选一）----
	await _await_room(main, 7, false)
	var trial_room: RoomBase = main.room_mgr.current
	_check("试炼房刷新 4 只敌人", trial_room.enemies_alive == 4)
	var gold_t0: int = GameManager.gold
	_kill_all()
	await _frames(15)
	_check("试炼房判定成功", trial_room.trial_success and trial_room.cleared)
	# 击杀 4 只（各掉 5）+ 完成奖励 20 = 40 尘珠（策划案第六节）
	_check("试炼完成奖励 20 尘珠（击杀 20 + 奖励 20）", GameManager.gold - gold_t0 == 40)
	var trial_owned := BuffManager.owned.size()
	_check("试炼达成后弹出双词条三选一（树暂停+面板）", get_tree().paused and main._overlay != null)
	_press("light_attack")
	await _frames(8)
	_check("第一轮选完，第二轮三选一仍在", main._overlay != null)
	_press("light_attack")
	await _frames(8)
	_check("双词条两轮选完", not get_tree().paused)
	_check("词条数增加 2 (owned=%d)" % BuffManager.owned.size(), BuffManager.owned.size() == trial_owned + 2)

	# ---- 事件房：直接加载验证石碑与奇遇面板 ----
	await _await_room(main, 0, false)   # 先回普通房腾出干净环境
	main.room_mgr.load_room_type("event")
	await _frames(20)
	var event_room: RoomBase = main.room_mgr.current
	_check("事件房已加载", event_room.room_id == "event" and not event_room.cleared)
	var shrine: Area2D = null
	for c in event_room.get_children():
		if c is Area2D and c.has_signal("opened"):
			shrine = c
	_check("事件房古碑已生成", shrine != null)
	if shrine:
		p.global_position = shrine.global_position + Vector2(-20.0, 0.0)
		p.velocity = Vector2.ZERO
		await _frames(6)
		_press("interact")
		await _frames(8)
		_check("奇遇面板已打开", get_tree().paused and main._overlay != null
			and main._overlay.name == "PanelEvent")
		_press("light_attack")   # 选第一项
		await _frames(8)
		_check("奇遇确认后恢复运行", not get_tree().paused)
		_check("奇遇完成后传送门开启", event_room.cleared and event_room.portal.active)

	# ---- BOSS 房：直接加载（层末固定节点）----
	await _await_room(main, 8, false)

	# ---- 房 8：BOSS 战 ----
	var boss_room: RoomBase = main.room_mgr.current
	_check("BOSS 房已加载", boss_room.room_id == "boss")
	_check("BOSS 房切换 BOSS 战曲", AudioManager._current_bgm == "bgm_boss")
	_check("BOSS 房传送门在击败 BOSS 前封印", boss_room.portal != null and not boss_room.portal.active)
	var boss_list := _live_enemies()
	_check("BOSS 已刷新", boss_list.size() == 1)
	# 进场 0.6s 后显示 BOSS 血条与名字（回归：hide_boss_bar 后未恢复标签可见性）
	await _wait(0.7)
	_check("BOSS 血条与名字已显示",
		main.hud.boss_label.visible and main.hud.boss_label.text == "玄风剑主")
	if boss_list.size() > 0:
		var boss: Node2D = boss_list[0]
		# 自然收招回归：BOSS 配置无 cd 键，须采用出招处传入的冷却（曾因 cfg.cd 报错卡死在 ACT）
		boss._end_act(1.5)
		_check("BOSS 出招结束正常收招并采用传入冷却",
			boss.state == EnemyBase.EState.RECOVER and is_equal_approx(boss.cd_left, 1.5))
		# 常规伤害 + 弹反路径冒烟
		var bhp0: int = int(boss.hp)
		boss.take_hit(50, boss.global_position.x - 30.0, {})
		await _frames(3)
		_check("BOSS 受击掉血", int(boss.hp) == bhp0 - 50)
		# ---- 突进斩为二阶段新增招式（策划案第五节）----
		boss.state = EnemyBase.EState.CHASE
		boss.cd_left = 5.0   # 抑制自然出招，改为显式驱动 _chase
		boss.guard_cd_left = 99.0
		p.global_position = boss.global_position + Vector2(200.0, 0)
		p.velocity = Vector2.ZERO
		await _wait(0.05)
		boss.cd_left = 0.0
		boss.state = EnemyBase.EState.CHASE
		boss._chase(0.016, p)
		_check("一阶段中距离（200px）不放突进斩", boss.pattern != "thrust")
		boss.state = EnemyBase.EState.CHASE
		boss.phase2 = true
		boss.cd_left = 0.0
		boss._chase(0.016, p)
		_check("二阶段中距离放突进斩", boss.pattern == "thrust")
		# ---- 满蓄重击破甲：击破格挡 + 禁格挡 1.5s（策划案第二节破甲定义）----
		boss.phase2 = false
		boss.pattern = ""
		boss.state = EnemyBase.EState.HURT   # 定身便于摆位
		boss.stagger_time = 5.0
		boss.state_time = 0.0
		boss.velocity = Vector2.ZERO
		boss.global_position = p.global_position + Vector2(30.0, 0)
		await _wait(0.05)  # 等 physics 同步摆位（BOSS 已定身）
		p.facing = 1
		p.charge_time = EntriesData.HEAVY.max_charge
		p.max_charge_time = EntriesData.HEAVY.max_charge
		p.full_charge = true
		# 期望伤害须计入震岳词条：重击命中后追加范围冲击波（BOSS 距离 30px < 半径 48px 必中）
		var shock_cfg := BuffManager.heavy_shockwave()
		var heavy_dmg: int = int(EntriesData.HEAVY.dmg * BuffManager.heavy_dmg_mult()) \
			+ int(shock_cfg.get("dmg", 0))
		var bhp_guard: int = int(boss.hp)
		boss.guard_active = true
		boss.guard_cd_left = 0.0
		p._do_heavy_strike()
		_check("满蓄重击击破 BOSS 格挡并造成全额伤害", int(boss.hp) == bhp_guard - heavy_dmg)
		_check("破甲后禁格挡 1.5s", boss.guard_cd_left >= EntriesData.HEAVY.guard_ban - 0.01)
		boss.take_hit(99999, boss.global_position.x - 30.0, {})
		await _wait(1.4)  # BOSS 倒下 1.0s 后弹出词条三选一（真实时间）
		_check("BOSS 战后词条选择出现", get_tree().paused and main._overlay != null)
		_press("light_attack")
		await _frames(10)
		_check("BOSS 战后传送门开启", boss_room.portal != null and boss_room.portal.active)

		# ---- 房 9：休憩点（血瓶补满 → 进入第二层）----
		GameManager.flasks = 0
		p.hp = 50.0
		var hp_rest0: int = int(p.hp)
		await _use_portal(main)
		_check("房 8 → 房 9（休憩点）", GameManager.room_index == 9)
		var rest_room: RoomBase = main.room_mgr.current
		_check("休憩点已加载且无传送门", rest_room.room_id == "rest" and rest_room.portal == null)
		_check("进入休憩点补满血瓶", GameManager.flasks == EntriesData.FLASK.max_uses)
		_check("HUD 血瓶计数同步为 ×3", main.hud.flask_label.text == "×3")
		await _wait(1.0)
		_check("休憩点每秒回复 2 生命 (%d → %d)" % [hp_rest0, int(p.hp)], int(p.hp) > hp_rest0)
		await _wait(1.4)  # 1.2s 结算计时 + 层间淡出 + 舆图弹出
		_check("第一层结束进入第二层", GameManager.layer == 1 and GameManager.room_index == 0)
		_check("第二层舆图已弹出", get_tree().paused and main._overlay != null
			and main._overlay.name == "MapScreen")
		_check("第二层不误触发通关", main._overlay != null and main._overlay.name != "MenuVictory")
		_check("HUD 层名切换为第二层", main.hud.layer_label.text == EntriesData.LAYERS[1].name)

		# ---- 第二层 BOSS：碧毒尊者（从第二层舆图进入一房后快进到 BOSS 房）----
		var l2_type: String = await _choose_map_node(main, "combat")
		_check("第二层舆图可进入节点（%s）" % l2_type, main.room_mgr.current.room_id == l2_type)
		GameManager.room_index = 8
		main.room_mgr.load_room(8)
		await _frames(12)
		var boss2_room: RoomBase = main.room_mgr.current
		var boss2_list := _live_enemies()
		_check("第二层 BOSS 已刷新", boss2_list.size() == 1)
		if boss2_list.size() == 1:
			var boss2: Node2D = boss2_list[0]
			_check("第二层 BOSS 为碧毒尊者", boss2.enemy_id == "boss_bilv" and boss2.cfg.name == "碧毒尊者")
			_check("第二层 BOSS 血量 420", int(boss2.hp) == 420)
			_check("第二层 BOSS 换皮精灵已加载", boss2.anim.sprite.texture != null)
			await _wait(0.7)
			_check("第二层 BOSS 名字标签显示",
				main.hud.boss_label.visible and main.hud.boss_label.text == "碧毒尊者")
			boss2.state = EnemyBase.EState.CHASE
			boss2.cd_left = 0.0
			boss2.guard_cd_left = 99.0
			p.global_position = boss2.global_position + Vector2(260.0, 0)
			boss2._chase(0.016, p)
			_check("碧毒尊者中距离施放毒瘴弹幕", boss2.pattern == "venom")
			boss2.state = EnemyBase.EState.ACT
			boss2.state_time = 0.0
			boss2.strike_done = 0
			var proj_before: int = PoolManager._active.size()
			boss2._act(0.016, p)
			_check("毒瘴弹幕已发射 3 发",
				boss2.strike_done == 1 and PoolManager._active.size() >= proj_before + 3)
			boss2.take_hit(99999, boss2.global_position.x - 30.0, {})
			await _wait(1.4)
			_check("第二层 BOSS 战后词条选择出现", get_tree().paused and main._overlay != null)
			_press("light_attack")
			await _frames(10)
			_check("第二层 BOSS 传送门开启", boss2_room.portal != null and boss2_room.portal.active)
			await _use_portal(main)
			_check("第二层休憩点已加载",
				GameManager.room_index == 9 and main.room_mgr.current.room_id == "rest")
			await _wait(2.2)
			_check("第二层结束进入第三层", GameManager.layer == 2 and GameManager.room_index == 0)
			_check("第三层舆图已弹出", get_tree().paused and main._overlay != null
				and main._overlay.name == "MapScreen")
			_check("HUD 层名切换为第三层", main.hud.layer_label.text == EntriesData.LAYERS[2].name)

			# ---- 第三层 BOSS：赤霄魔君 ----
			var l3_type: String = await _choose_map_node(main, "combat")
			_check("第三层舆图可进入节点（%s）" % l3_type, main.room_mgr.current.room_id == l3_type)
			GameManager.room_index = 8
			main.room_mgr.load_room(8)
			await _frames(12)
			var boss3_room: RoomBase = main.room_mgr.current
			var boss3_list := _live_enemies()
			_check("第三层 BOSS 已刷新", boss3_list.size() == 1)
			if boss3_list.size() == 1:
				var boss3: Node2D = boss3_list[0]
				_check("第三层 BOSS 为赤霄魔君",
					boss3.enemy_id == "boss_chixiao" and boss3.cfg.name == "赤霄魔君")
				_check("第三层 BOSS 血量 560", int(boss3.hp) == 560)
				_check("第三层 BOSS 换皮精灵已加载", boss3.anim.sprite.texture != null)
				await _wait(0.7)
				_check("第三层 BOSS 名字标签显示",
					main.hud.boss_label.visible and main.hud.boss_label.text == "赤霄魔君")
				boss3.state = EnemyBase.EState.CHASE
				boss3.phase2 = true
				boss3.cd_left = 0.0
				boss3.guard_cd_left = 99.0
				p.global_position = boss3.global_position + Vector2(400.0, 0)
				boss3._chase(0.016, p)
				_check("赤霄魔君二阶段远距离施放天火剑气", boss3.pattern == "blaze")
				boss3.state = EnemyBase.EState.ACT
				boss3.state_time = 0.0
				boss3.strike_done = 0
				proj_before = PoolManager._active.size()
				boss3._act(0.016, p)
				_check("天火剑气已发射 5 发",
					boss3.strike_done == 1 and PoolManager._active.size() >= proj_before + 5)
				boss3.take_hit(99999, boss3.global_position.x - 30.0, {})
				await _wait(1.4)
				_check("第三层 BOSS 战后词条选择出现", get_tree().paused and main._overlay != null)
				_press("light_attack")
				await _frames(10)
				_check("第三层 BOSS 传送门开启", boss3_room.portal != null and boss3_room.portal.active)
				await _use_portal(main)
				_check("第三层休憩点已加载",
					GameManager.room_index == 9 and main.room_mgr.current.room_id == "rest")
				await _wait(2.2)
				_check("三层通关结算画面出现",
					main._overlay != null and main._overlay.name == "MenuVictory")

	# ---- 玩家死亡 → 死亡结算 ----
	p.invuln_left = 0.0
	p.take_hit(99999, p.global_position.x + 30.0, {})
	await _wait(2.6)  # time_scale 0.3 下 0.6s 计时器 ≈ 2.0s 真实时间
	_check("死亡结算画面出现", main._overlay != null and main._overlay.name == "MenuDeath")

	# 玩家死亡时不可使用血瓶（策划§2.11「不消耗条件」）
	GameManager.flasks = 1
	var hp_dead: float = p.hp
	var used_when_dead: bool = GameManager.use_flask()
	_check("玩家死亡时不可使用血瓶", not used_when_dead and GameManager.flasks == 1 and p.hp == hp_dead)
	_done = true
