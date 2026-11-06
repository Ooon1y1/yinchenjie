# buff_manager.gd — 词条管理（AutoLoad）：词条增删、属性叠加计算（策划案第三节）
extends Node

var owned: Array[String] = []


func reset() -> void:
	owned.clear()


func has_entry(id: String) -> bool:
	return id in owned


func add_entry(id: String) -> void:
	if has_entry(id):
		return
	owned.append(id)
	EventBus.entry_added.emit(id)


func add_entries(ids: Array) -> void:
	for id in ids:
		add_entry(id)


# ---- 修改器查询（玩家脚本直接调用） ----

# 迅刺：轻击攻速 +15%
func light_attack_speed_mult() -> float:
	return 1.15 if has_entry("xun_ci") else 1.0


# 连锋：第三段轻击范围 +30%
func light3_range_mult() -> float:
	return 1.3 if has_entry("lian_feng") else 1.0


# 剑风：轻击附带剑气伤害
func light_qi_dmg() -> int:
	return EntriesData.ENTRY_VALUES.sword_qi_dmg if has_entry("jian_feng") else 0


# 沉锋：重击伤害 +25%
func heavy_dmg_mult() -> float:
	return 1.25 if has_entry("chen_feng") else 1.0


# 蓄势：重击蓄力时间缩短 30%
func heavy_charge_mult() -> float:
	return 0.7 if has_entry("xu_shi") else 1.0


# 震岳：重击命中冲击波（伤害 10 / 半径 48）
func heavy_shockwave() -> Dictionary:
	if has_entry("zhen_yue"):
		return {"dmg": EntriesData.ENTRY_VALUES.heavy_shock_dmg,
			"radius": EntriesData.ENTRY_VALUES.heavy_shock_radius}
	return {}


# 铁脊：格挡减免 90%
func block_reduce() -> float:
	return 0.90 if has_entry("tie_ji") else EntriesData.BLOCK.reduce


# 御灵：命中概率召唤飞剑
func flying_sword_cfg() -> Dictionary:
	if has_entry("yu_ling"):
		return {
			"chance": EntriesData.ENTRY_VALUES.flying_sword_chance,
			"dmg": EntriesData.ENTRY_VALUES.flying_sword_dmg,
			"pierce": EntriesData.ENTRY_VALUES.flying_sword_pierce if has_entry("jian_lian") else 0,
			"qi_return": EntriesData.ENTRY_VALUES.flying_sword_qi_return if has_entry("xing_gui") else 0,
		}
	return {}


# 静气：内息恢复 +20%
func qi_regen_mult() -> float:
	return 1.2 if has_entry("jing_qi") else 1.0


# 劲波：完美弹反震波
func parry_wave() -> Dictionary:
	if has_entry("jin_bo"):
		return {"dmg": EntriesData.ENTRY_VALUES.parry_wave_dmg,
			"radius": EntriesData.ENTRY_VALUES.parry_wave_radius}
	return {}


# 固元：生命上限 +20
func max_hp_bonus() -> int:
	return EntriesData.ENTRY_VALUES.max_hp_bonus if has_entry("gu_yuan") else 0


# 追影：轻功后可立即轻击
func can_dash_cancel_attack() -> bool:
	return has_entry("zhui_ying")


# ---- v2.0 连招系统修改器 ----

# 快刃 + 迅刺：连招衔接窗口
func combo_window() -> float:
	var bonus := 0.0
	if has_entry("xun_ci"):
		bonus += 0.1
	if has_entry("kuai_ren"):
		bonus += 0.1
	return EntriesData.COMBO_WINDOW + bonus


# 解锁类：功能开关
func unlock_flag(flag: String) -> bool:
	for id in owned:
		var e: Dictionary = EntriesData.ENTRIES.get(id, {})
		if e.get("unlock_flag", "") == flag:
			return true
	return false


func jump_cancel_unlocked() -> bool:
	return unlock_flag("jump_cancel")


func air_combo_unlocked() -> bool:
	return unlock_flag("air_combo")


func preswing_derive_unlocked() -> bool:
	return unlock_flag("preswing_derive")


# 疾影：闪避取消内息（15 → 7）
func dash_cancel_cost() -> float:
	if has_entry("ji_ying"):
		return EntriesData.ENTRY_VALUES.ji_ying_cancel_cost
	return ComboData.DASH_CANCEL_COST


# 疾影：取消窗口 +0.1s
func cancel_window_bonus() -> float:
	return 0.1 if has_entry("ji_ying") else 0.0


# 分招式类型伤害倍率：normal / derive / finisher
func dmg_mult_for(kind: String) -> float:
	match kind:
		"normal":
			return EntriesData.ENTRY_VALUES.normal_dmg_mult if has_entry("lian_ren") else 1.0
		"derive":
			return EntriesData.ENTRY_VALUES.derive_dmg_mult if has_entry("po_shi") else 1.0
		"finisher":
			return EntriesData.ENTRY_VALUES.finisher_dmg_mult if has_entry("zhong_shi") else 1.0
	return 1.0


# 广域：所有攻击范围 +20%
func range_mult() -> float:
	return EntriesData.ENTRY_VALUES.range_mult if has_entry("guang_yu") else 1.0


# 柔化：所有攻击后摇 -20%
func recovery_mult() -> float:
	return EntriesData.ENTRY_VALUES.recovery_mult if has_entry("rou_hua") else 1.0


# 延滞：命中硬直 +0.15s
func stagger_add() -> float:
	return EntriesData.ENTRY_VALUES.stagger_add if has_entry("yan_zhi") else 0.0


# 霜寒：命中减速
func apply_slow() -> bool:
	return has_entry("shuang_han")


# 剑气余韵：普攻附带 30% 剑气
func qi_echo_dmg(base_dmg: int) -> int:
	if has_entry("jian_qi_yu_yun"):
		return maxi(int(base_dmg * EntriesData.ENTRY_VALUES.qi_echo_ratio), 1)
	return 0


# 爆裂：终结技范围爆炸
func finisher_explode() -> Dictionary:
	if has_entry("bao_lie"):
		return {"radius": EntriesData.ENTRY_VALUES.explode_radius,
			"ratio": EntriesData.ENTRY_VALUES.explode_ratio}
	return {}


# 吸星：连续命中吸血
func lifesteal_cfg() -> Dictionary:
	if has_entry("xi_xing"):
		return {"heal": EntriesData.ENTRY_VALUES.xi_xing_heal,
			"interval": EntriesData.ENTRY_VALUES.xi_xing_interval}
	return {}


# 破甲：派生附带破甲（击破格挡 + 禁格挡 1.5s）
func derive_armor_break() -> bool:
	return has_entry("po_jia_ci")


# ---- 随机三选一 ----

func offer_pool() -> Array[String]:
	var pool: Array[String] = []
	for id in EntriesData.ENTRIES.keys():
		if has_entry(id):
			continue
		var e: Dictionary = EntriesData.ENTRIES[id]
		# 武器专属词条：仅持有对应武器时进入卡池
		var wid: String = e.get("weapon_id", "")
		if not wid.is_empty() and not GameManager.has_weapon(wid):
			continue
		pool.append(id)
	return pool


func random_choices(count: int) -> Array[String]:
	var pool := offer_pool()
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))
