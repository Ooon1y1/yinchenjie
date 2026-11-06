# combo_manager.gd — 连招管理（挂载玩家节点，策划案 v2.0 第 8.2 节）
# 职责：普攻连段状态、连击计数、衔接窗口、输入缓存、取消窗口；数据全部读 ComboData 配表。
class_name ComboManager
extends Node

const V := EntriesData.ENTRY_VALUES

var weapon_id := "changjian"
var combo_index := 0        # 当前普攻段（0 = 未在连招中）
var combo_timer := 0.0       # 衔接窗口剩余（超时回 idle 并重置段数）
var air_combo := false       # 空中普攻链
var auto_chain := false      # 自动连段（短刃空中连斩）
var air_chain_override: Array = []   # 空中连斩专用段数据（伤害 8/8/10）

var hit_count := 0           # 连击数（每次命中 +1）
var hit_timer := 0.0         # 连击计时 1.5s
var _consecutive := 0        # 吸星连续命中计数


func _physics_process(delta: float) -> void:
	# 衔接窗口倒计时（攻击进行中暂停：窗口在每段后摇结束刷新为 0.3s；
	# 若攻击中途到期会把 combo_index 清零，缓冲续段会错位回第 1 段）
	var p := get_parent()
	if combo_index > 0 and p.state not in [p.State.COMBO, p.State.DERIVE, p.State.FINISHER]:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_index = 0
			auto_chain = false
			air_combo = false
			air_chain_override = []
	# 连击计时
	if hit_count > 0:
		hit_timer -= delta
		if hit_timer <= 0.0:
			reset_hits(false)
		else:
			EventBus.combo_tick.emit(hit_count, hit_timer / V.combo_timer)


# ---------------- 普攻链 ----------------

# 词条是否已解锁（空 unlock 字段 = 默认解锁）
func _unlocked(entry: Dictionary) -> bool:
	var unlock: String = entry.get("unlock", "")
	return unlock.is_empty() or BuffManager.has_entry(unlock)


# 当前武器已解锁的普攻段（空中链取前 3 段或连斩覆盖表；锁定段必在末尾，遇锁即止）
func chain_segments() -> Array:
	if air_combo and not air_chain_override.is_empty():
		return air_chain_override
	var out: Array = []
	for seg in ComboData.chain_segments(weapon_id):
		if not _unlocked(seg):
			break
		out.append(seg)
	if air_combo:
		out = out.slice(0, mini(ComboData.AIR_CHAIN_SEGMENTS, out.size()))
	return out


func chain_size() -> int:
	return chain_segments().size()


func weapon() -> Dictionary:
	return ComboData.weapon(weapon_id)


# 指定段已解锁的方向派生
func derives_for(seg_index: int) -> Array:
	var out: Array = []
	for d in ComboData.derives_for(weapon_id, seg_index):
		if _unlocked(d):
			out.append(d)
	return out


# 已解锁的触发类派生（架招反击 / 空中连斩 / 蓄力派生）
func derive_by_trigger(seg_index: int, trigger: String) -> Dictionary:
	var d := ComboData.derive_by_trigger(weapon_id, seg_index, trigger)
	if d.is_empty() or not _unlocked(d):
		return {}
	return d


# 派生取消窗口宽度（按武器 + 疾影加成）
func cancel_window() -> float:
	return ComboData.weapon(weapon_id).cancel_window + BuffManager.cancel_window_bonus()


func reset_combo() -> void:
	combo_index = 0
	combo_timer = 0.0
	auto_chain = false
	air_combo = false
	air_chain_override = []


# ---------------- 连击计数 ----------------

func register_hit(player: Node) -> void:
	hit_count += 1
	hit_timer = V.combo_timer
	if hit_count > GameManager.max_combo:
		GameManager.max_combo = hit_count
	# 每 10 连击：里程碑脉冲 + 息连回内息
	if hit_count % 10 == 0:
		EventBus.combo_milestone.emit(hit_count)
		AudioManager.play_sfx("combo_milestone")
		if BuffManager.has_entry("xi_lian"):
			player.refund_qi(V.xi_lian_qi)
	# 每 20 连击：血连回生命
	if hit_count % 20 == 0 and BuffManager.has_entry("xue_lian"):
		player.heal(V.xue_lian_hp)
	# 吸星：连续命中吸血
	var ls := BuffManager.lifesteal_cfg()
	if not ls.is_empty():
		_consecutive += 1
		if _consecutive >= ls.interval:
			_consecutive = 0
			player.heal(ls.heal)
	EventBus.combo_tick.emit(hit_count, 1.0)


func reset_hits(halve: bool) -> void:
	# 不断：受击后不清零仅减半
	if halve and BuffManager.has_entry("bu_duan"):
		hit_count = hit_count / 2
		hit_timer = V.combo_timer
		EventBus.combo_tick.emit(hit_count, 1.0)
		return
	hit_count = 0
	hit_timer = 0.0
	_consecutive = 0
	EventBus.combo_tick.emit(0, 0.0)


# 连击增伤：独立乘区（每 10 连击 +3%，封顶 30%；连击精通改为 +5% 封顶 50%）
func hit_damage_mult() -> float:
	if hit_count < 10:
		return 1.0
	if BuffManager.has_entry("lian_ji_tong"):
		return 1.0 + minf(V.combo_master_cap, (hit_count / 10) * V.combo_master_per_10)
	return 1.0 + minf(V.combo_bonus_cap, (hit_count / 10) * V.combo_bonus_per_10)
