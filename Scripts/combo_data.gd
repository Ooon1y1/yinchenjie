# combo_data.gd — 武器与连招配表（策划案 v2.0 第三节 ComboData，全部硬性数值的唯一来源）
# 三层结构：基础普攻链 + 分支派生 + 终结技。段/派生字段与策划案 ComboData 表一一对应。
class_name ComboData

# ---------------- 通用常量（策划案第二节 取消机制） ----------------
const INPUT_BUFFER := 0.2          # 输入缓存（秒）
const DASH_CANCEL_COST := 15.0     # 连招内闪避取消半价（非连招轻功仍 30）
const JUMP_CANCEL_CD := 0.2         # 跳跃取消冷却
const K_TAP_TIME := 0.15            # K 短按 / 按住判定阈值

# ---------------- 敌人受击状态（策划案第五节新增） ----------------
const LAUNCH := {
	"rise_vel": 380.0,      # 垂直位移 40px 的初速度
	"refresh_vel": 250.0,   # 空中追击刷新滞空
	"land_stagger": 1.0,    # 落地硬直
	"max_refresh": 3,       # 单次浮空最多刷新 3 次
}
const SLOW := {"per": 0.10, "max_stacks": 3, "time": 2.0}   # 霜寒
const STUN_FX_TIME := 0.4

# ---------------- 武器定义 ----------------
# 段字段：id / dmg / windup / recovery / size / offset / kb / kb_time / unlock(词条) / anim
# 派生字段：seg(挂载普攻段) / trigger(dir|block|jump|hold) / dir(up|down|fwd|back|any) /
#           unlock / dmg / cost / windup / recovery / size / offset / 特效标记
const WEAPONS := {
	# ---------- 武器 1：长剑・平衡型（连招流畅，派生全面） ----------
	"changjian": {
		"name": "长剑", "price": 0, "cancel_window": 0.10,
		"icon": "res://Assets/Art/Icons/icon_weapon_changjian.png",
		"tagline": "均衡之刃",
		"desc": "剑走轻灵，连招流畅，是踏入江湖最稳妥的选择。",
		"passive": "派生招式全面，连段衔接从容",
		"chain": [
			{"id": "changjian_1", "dmg": 8, "windup": 0.06, "recovery": 0.12,
				"size": Vector2(24, 20), "offset": 16.0, "kb": 150.0, "kb_time": 0.15,
				"anim": "light_attack_1"},
			{"id": "changjian_2", "dmg": 10, "windup": 0.06, "recovery": 0.12,
				"size": Vector2(24, 24), "offset": 16.0, "kb": 150.0, "kb_time": 0.15,
				"anim": "light_attack_2"},
			{"id": "changjian_3", "dmg": 15, "windup": 0.08, "recovery": 0.15,
				"size": Vector2(28, 24), "offset": 18.0, "kb": 150.0, "kb_time": 0.15,
				"anim": "light_attack_3"},
			{"id": "changjian_4", "dmg": 20, "windup": 0.08, "recovery": 0.18,
				"size": Vector2(36, 20), "offset": 20.0, "kb": 150.0, "kb_time": 0.15,
				"unlock": "cs_4th", "anim": "light_attack_4"},
		],
		"derives": [
			{"id": "changjian_derive_up", "seg": 1, "trigger": "dir", "dir": "up",
				"unlock": "cs_shang_tiao", "dmg": 12, "cost": 0, "windup": 0.08, "recovery": 0.18,
				"size": Vector2(20, 36), "offset": 14.0, "kb": 120.0, "kb_time": 0.15,
				"launch": true, "anim": "derive_up", "sfx": "derive_release"},
			{"id": "changjian_derive_qi", "seg": 2, "trigger": "dir", "dir": "fwd",
				"unlock": "cs_jian_qi_zhan", "dmg": 18, "cost": 20, "windup": 0.10, "recovery": 0.20,
				"size": Vector2(16, 8), "offset": 0.0, "kb": 150.0, "kb_time": 0.15,
				"projectile": {"speed": 400.0, "range": 300.0, "pierce": true, "kind": "qi"},
				"anim": "derive_qi", "sfx": "derive_release"},
		],
		"finisher": {"id": "changjian_finisher", "name": "青云斩", "dmg": 35, "cost": 25,
			"windup": 0.12, "recovery": 0.25, "size": Vector2(44, 30), "offset": 22.0,
			"kb": 300.0, "kb_time": 0.20, "anim": "finisher"},
	},
	# ---------- 武器 2：重剑・破甲型（段少伤高，取消窗口窄） ----------
	"zhongjian": {
		"name": "重剑", "price": 80, "cancel_window": 0.05,
		"icon": "res://Assets/Art/Icons/icon_weapon_zhongjian.png",
		"tagline": "破甲重剑",
		"desc": "出招迟缓，胜在一击破甲；蓄势既满，山岳可裂。",
		"passive": "普攻后摇可蓄力，满蓄伤害 +50%",
		"chain": [
			{"id": "zhongjian_1", "dmg": 18, "windup": 0.10, "recovery": 0.20,
				"size": Vector2(36, 26), "offset": 20.0, "kb": 200.0, "kb_time": 0.18,
				"anim": "light_attack_1"},
			{"id": "zhongjian_2", "dmg": 28, "windup": 0.12, "recovery": 0.25,
				"size": Vector2(30, 34), "offset": 16.0, "kb": 300.0, "kb_time": 0.20,
				"anim": "light_attack_2"},
			{"id": "zhongjian_3", "dmg": 40, "windup": 0.15, "recovery": 0.30,
				"size": Vector2(40, 34), "offset": 18.0, "kb": 300.0, "kb_time": 0.20,
				"unlock": "zj_3rd", "armor_break": true, "guard_ban": 3.0,
				"anim": "combo_3"},
		],
		"derives": [
			{"id": "zhongjian_derive_ground", "seg": 1, "trigger": "dir", "dir": "down",
				"unlock": "zj_zhen_di", "dmg": 22, "cost": 0, "windup": 0.15, "recovery": 0.30,
				"size": Vector2(48, 20), "offset": 36.0, "kb": 150.0, "kb_time": 0.15,
				"ground_fx": true, "stun": 0.4, "anim": "derive_ground", "sfx": "derive_release"},
			{"id": "zhongjian_derive_parry", "seg": 2, "trigger": "block",
				"unlock": "zj_jia_zhao", "anim": "block"},
			# 蓄力派生：普攻后摇中按住 K 蓄力（最长 0.8s），伤害最高 +50%
			{"id": "zhongjian_derive_charge", "seg": 0, "trigger": "hold",
				"dmg": 28, "max_charge": 0.8, "charge_mult": 0.5,
				"size": Vector2(30, 34), "offset": 16.0, "kb": 300.0, "kb_time": 0.20,
				"anim": "heavy_release"},
		],
		"finisher": {"id": "zhongjian_finisher", "name": "裂岳斩", "dmg": 60, "cost": 35,
			"windup": 0.18, "recovery": 0.35, "size": Vector2(52, 40), "offset": 24.0,
			"kb": 350.0, "kb_time": 0.22, "anim": "finisher"},
	},
	# ---------- 武器 3：短刃・高速型（段多快打，取消窗口宽） ----------
	"duanren": {
		"name": "短刃", "price": 80, "cancel_window": 0.15,
		"icon": "res://Assets/Art/Icons/icon_weapon_duanren.png",
		"tagline": "疾影短刃",
		"desc": "出手极快、连段绵长，最宜贴身处游走取命。",
		"passive": "背刺伤害 ×2",
		"backstab_mult": 2.0,   # 背刺被动：身处敌后伤害翻倍
		"chain": [
			{"id": "duanren_1", "dmg": 5, "windup": 0.04, "recovery": 0.08,
				"size": Vector2(18, 14), "offset": 12.0, "kb": 100.0, "kb_time": 0.12,
				"anim": "light_attack_1"},
			{"id": "duanren_2", "dmg": 6, "windup": 0.04, "recovery": 0.08,
				"size": Vector2(18, 14), "offset": 12.0, "kb": 100.0, "kb_time": 0.12,
				"anim": "light_attack_2"},
			{"id": "duanren_3", "dmg": 7, "windup": 0.04, "recovery": 0.08,
				"size": Vector2(18, 14), "offset": 12.0, "kb": 100.0, "kb_time": 0.12,
				"anim": "light_attack_3"},
			{"id": "duanren_4", "dmg": 12, "windup": 0.06, "recovery": 0.12,
				"size": Vector2(22, 16), "offset": 14.0, "kb": 120.0, "kb_time": 0.12,
				"anim": "light_attack_4"},
			{"id": "duanren_5", "dmg": 10, "windup": 0.04, "recovery": 0.08,
				"size": Vector2(18, 14), "offset": 12.0, "kb": 100.0, "kb_time": 0.12,
				"unlock": "dr_56", "anim": "light_attack_5"},
			{"id": "duanren_6", "dmg": 14, "windup": 0.06, "recovery": 0.12,
				"size": Vector2(22, 16), "offset": 14.0, "kb": 150.0, "kb_time": 0.15,
				"unlock": "dr_56", "anim": "light_attack_6"},
		],
		"derives": [
			{"id": "duanren_derive_flash", "seg": 2, "trigger": "dir", "dir": "any",
				"unlock": "dr_shan_ci", "dmg": 16, "cost": 0, "windup": 0.05, "recovery": 0.15,
				"size": Vector2(16, 12), "offset": 12.0, "kb": 150.0, "kb_time": 0.15,
				"dash_strike": 120.0, "anim": "derive_flash", "sfx": "derive_release"},
			# 空中连斩：3 段普攻中按跳跃，自动起跳接空中 3 段斩（不消耗二段跳）
			{"id": "duanren_derive_air", "seg": 3, "trigger": "jump",
				"unlock": "dr_kong_zhong",
				"air_chain": [
					{"dmg": 8, "windup": 0.05, "recovery": 0.10, "size": Vector2(20, 14),
						"offset": 12.0, "kb": 100.0, "kb_time": 0.12, "anim": "light_attack_1"},
					{"dmg": 8, "windup": 0.05, "recovery": 0.10, "size": Vector2(20, 14),
						"offset": 12.0, "kb": 100.0, "kb_time": 0.12, "anim": "light_attack_2"},
					{"dmg": 10, "windup": 0.06, "recovery": 0.14, "size": Vector2(20, 14),
						"offset": 12.0, "kb": 150.0, "kb_time": 0.15, "anim": "light_attack_4"},
				]},
		],
		"finisher": {"id": "duanren_finisher", "name": "影袭", "dmg": 28, "cost": 20,
			"windup": 0.08, "recovery": 0.20, "size": Vector2(22, 18), "offset": 12.0,
			"kb": 200.0, "kb_time": 0.15, "teleport_range": 150.0, "anim": "finisher"},
	},
	# ---------- 武器 4：长戈・控场型（距离远，范围大） ----------
	"changge": {
		"name": "长戈", "price": 80, "cancel_window": 0.10,
		"icon": "res://Assets/Art/Icons/icon_weapon_changge.png",
		"tagline": "控场长戈",
		"desc": "兵刃最长，横扫成片，能在乱局中牢牢占住身位。",
		"passive": "派生攻击穿透至多 3 名敌人",
		"derive_pierce": 3,   # 穿刺穿透（被动）：持长戈时派生攻击沿攻击方向穿透至多 3 个敌人
		"chain": [
			{"id": "changge_1", "dmg": 12, "windup": 0.10, "recovery": 0.18,
				"size": Vector2(44, 22), "offset": 24.0, "kb": 200.0, "kb_time": 0.15,
				"anim": "light_attack_1"},
			{"id": "changge_2", "dmg": 18, "windup": 0.10, "recovery": 0.20,
				"size": Vector2(56, 12), "offset": 28.0, "kb": 250.0, "kb_time": 0.18,
				"anim": "light_attack_2"},
			{"id": "changge_3", "dmg": 25, "windup": 0.12, "recovery": 0.25,
				"size": Vector2(80, 16), "offset": 0.0, "kb": 250.0, "kb_time": 0.18,
				"unlock": "cg_3rd", "anim": "combo_3"},
		],
		"derives": [
			{"id": "changge_derive_back", "seg": 1, "trigger": "dir", "dir": "back",
				"unlock": "cg_hui_ma", "dmg": 20, "cost": 0, "windup": 0.08, "recovery": 0.20,
				"size": Vector2(48, 12), "offset": -28.0, "kb": 300.0, "kb_time": 0.20,
				"anim": "derive_back", "sfx": "derive_release"},
			{"id": "changge_derive_uplift", "seg": 2, "trigger": "dir", "dir": "up",
				"unlock": "cg_tiao_fei", "dmg": 16, "cost": 0, "windup": 0.12, "recovery": 0.25,
				"size": Vector2(48, 36), "offset": 20.0, "kb": 120.0, "kb_time": 0.15,
				"launch": true, "anim": "derive_up", "sfx": "derive_release"},
		],
		"finisher": {"id": "changge_finisher", "name": "穿云刺", "dmg": 42, "cost": 28,
			"windup": 0.15, "recovery": 0.30, "size": Vector2(88, 10), "offset": 84.0,
			"kb": 300.0, "kb_time": 0.20, "anim": "finisher"},
	},
}

# 空中普攻链段数（空武解锁，使用武器前 3 段）
const AIR_CHAIN_SEGMENTS := 3


# ---------------- 查询接口 ----------------
# 纯数据层：不引用任何 AutoLoad（避免与 BuffManager 循环依赖）；
# 解锁过滤统一在 ComboManager 中处理。

static func weapon(wid: String) -> Dictionary:
	return WEAPONS.get(wid, WEAPONS.changjian)


# 完整普攻链（不裁剪锁定段，遇锁即止的语义由 ComboManager 实现）
static func chain_segments(wid: String) -> Array:
	var out: Array = []
	for seg in weapon(wid).chain:
		out.append(seg)
	return out


# 指定段的全部方向派生（不含 block/jump/hold 触发类）
static func derives_for(wid: String, seg_index: int) -> Array:
	var out: Array = []
	for d in weapon(wid).derives:
		if d.get("trigger", "dir") == "block" or d.get("trigger") == "jump" or d.get("trigger") == "hold":
			continue
		if d.seg != seg_index:
			continue
		out.append(d)
	return out


static func derive_by_trigger(wid: String, seg_index: int, trigger: String) -> Dictionary:
	for d in weapon(wid).derives:
		if d.get("trigger", "dir") != trigger or d.seg != seg_index:
			continue
		return d
	return {}
