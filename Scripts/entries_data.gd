# entries_data.gd — 全局配置表（策划案所有硬性数值的唯一来源）
# 类型: class_name 静态访问，供所有脚本与 smoke test 直接引用。
class_name EntriesData

# ---------------- 物理碰撞层 ----------------
const LAYER_PLAYER := 1
const LAYER_ENEMY := 2
const LAYER_WORLD := 3
const LAYER_PLAYER_HURT := 4
const LAYER_ENEMY_HURT := 5

static func mask(layers: Array) -> int:
	var v := 0
	for l in layers:
		v |= 1 << (l - 1)
	return v

# ---------------- 玩家基础属性（策划案第二节） ----------------
const PLAYER := {
	"max_hp": 100,
	"max_qi": 100,
	"move_speed": 420.0,
	"gravity": 1800.0,
	"jump_vel": -650.0,
	"dash_cd": 1.2,
	"dash_distance": 180.0,
	"dash_duration": 0.25,
	"dash_qi_cost": 30.0,
	"qi_regen": 12.0,
	"parry_window": 0.2,
	"hurtbox_size": Vector2(16, 28),
	"regen_enemy_radius": 300.0,   # 非战斗判定：附近无存活敌人
}

# ---------------- 招式参数（策划案第二节） ----------------
const LIGHT_ATTACKS := [
	{"dmg": 8, "windup": 0.06, "recovery": 0.12, "size": Vector2(24, 20), "offset": 16.0, "kb": 150.0, "kb_time": 0.15},
	{"dmg": 10, "windup": 0.06, "recovery": 0.12, "size": Vector2(24, 24), "offset": 16.0, "kb": 150.0, "kb_time": 0.15},
	{"dmg": 15, "windup": 0.08, "recovery": 0.15, "size": Vector2(28, 24), "offset": 18.0, "kb": 150.0, "kb_time": 0.15},
]
const COMBO_WINDOW := 0.3
const HEAVY := {
	"max_charge": 0.6,
	"dmg": 35,
	"qi_cost": 20.0,
	"windup": 0.10,
	"recovery": 0.20,
	"size": Vector2(36, 28),
	"offset": 20.0,
	"kb": 300.0,
	"kb_time": 0.20,
	"guard_ban": 1.5,   # 满蓄破甲：击破格挡后禁格挡时长（策划案第二节破甲定义）
}
const BLOCK := {
	"drain": 5.0,        # 内息/秒
	"reduce": 0.70,      # 减免比例
}
const PARRY := {
	"enemy_stagger": 1.0,
	"invuln": 0.3,
	"counter_qi_dmg": 20,
	"counter_qi_speed": 400.0,
	"counter_qi_range": 300.0,
}

# ---------------- 打击感（策划案第二节新增数值） ----------------
const HITSTOP := {"light": 0.04, "heavy": 0.08, "parry": 0.10}
const SHAKE := {
	"heavy_hit": Vector2(4.0, 0.12),
	"player_hurt": Vector2(3.0, 0.10),
	"boss_phase": Vector2(6.0, 0.30),
}
const KNOCKBACK_TO_PLAYER := 200.0
const FLASH_TIME := 0.06
const DEATH_SLOWMO := 0.3     # time_scale
const DEATH_SLOWMO_TIME := 0.5

# ---------------- 词条（v2.0：原 14 个 + 连招升级 22 个，共 46 个） ----------------
# category: unlock(解锁类) / buff(强化类) / mechanic(机制增益) / effect(特效追加)
# weapon_id: 武器专属词条归属；unlock_combo_id 为空则用 unlock_flag
const ENTRIES := {
	# ---- 快剑流（v1.1） ----
	"xun_ci": {"name": "迅刺", "school": "swift", "category": "buff", "desc": "轻击攻速 +15%，连招窗口 +0.1s", "price": 50},
	"zhui_ying": {"name": "追影", "school": "swift", "category": "mechanic", "desc": "轻功结束后可立即释放轻击", "price": 50},
	"jian_feng": {"name": "剑风", "school": "swift", "category": "effect", "desc": "轻击附带小型剑气（伤害 5）", "price": 50},
	"lian_feng": {"name": "连锋", "school": "swift", "category": "buff", "desc": "第三段轻击范围 +30%", "price": 50},
	# ---- 重破流（v1.1） ----
	"chen_feng": {"name": "沉锋", "school": "heavy", "category": "buff", "desc": "重击伤害 +25%", "price": 50},
	"zhen_yue": {"name": "震岳", "school": "heavy", "category": "effect", "desc": "重击命中产生范围冲击波（伤害 10）", "price": 50},
	"xu_shi": {"name": "蓄势", "school": "heavy", "category": "buff", "desc": "重击蓄力时间缩短 30%", "price": 50},
	"tie_ji": {"name": "铁脊", "school": "heavy", "category": "buff", "desc": "格挡伤害减免提升至 90%", "price": 50},
	# ---- 御剑流（v1.1） ----
	"yu_ling": {"name": "御灵", "school": "guard", "category": "effect", "desc": "攻击命中 20% 概率召唤飞剑自动索敌（伤害 12）", "price": 50},
	"jian_lian": {"name": "剑链", "school": "guard", "category": "buff", "desc": "飞剑可穿透 2 个敌人", "price": 50},
	"xing_gui": {"name": "星归", "school": "guard", "category": "mechanic", "desc": "飞剑命中回复 5 点内息", "price": 50},
	# ---- 玄劲流（v1.1） ----
	"jing_qi": {"name": "静气", "school": "mystic", "category": "mechanic", "desc": "内息恢复速度 +20%", "price": 50},
	"jin_bo": {"name": "劲波", "school": "mystic", "category": "effect", "desc": "完美弹反触发范围震波（伤害 15）", "price": 50},
	"gu_yuan": {"name": "固元", "school": "mystic", "category": "mechanic", "desc": "生命上限 +20", "price": 50},
	# ---- 解锁类・通用（v2.0） ----
	"xing_yun": {"name": "行云", "school": "combo", "category": "unlock", "unlock_flag": "jump_cancel", "desc": "解锁跳跃取消：攻击后摇可跳跃中断", "price": 50},
	"ji_ying": {"name": "疾影", "school": "combo", "category": "unlock", "unlock_flag": "dash_cancel_fast", "desc": "闪避取消内息减半（15→7），取消窗口 +0.1s", "price": 50},
	"kong_wu": {"name": "空武", "school": "combo", "category": "unlock", "unlock_flag": "air_combo", "desc": "解锁空中普攻链，可在空中触发连招", "price": 50},
	"shun_shi": {"name": "顺势", "school": "combo", "category": "unlock", "unlock_flag": "preswing_derive", "desc": "派生取消扩展至普攻前摇后半段", "price": 50},
	# ---- 解锁类・长剑（v2.0） ----
	"cs_shang_tiao": {"name": "长剑・上挑", "school": "combo", "category": "unlock", "weapon_id": "changjian", "unlock_combo_id": "changjian_derive_up", "unlock_flag": "air_combo", "desc": "1 段普攻中 W+K：上挑浮空（伤害 12），解锁空中追击", "price": 50},
	"cs_jian_qi_zhan": {"name": "长剑・剑气斩", "school": "combo", "category": "unlock", "weapon_id": "changjian", "unlock_combo_id": "changjian_derive_qi", "desc": "2 段普攻中 D+K：穿透剑气（伤害 18）", "price": 50},
	"cs_4th": {"name": "长剑・回身斩", "school": "combo", "category": "unlock", "weapon_id": "changjian", "unlock_combo_id": "changjian_4", "desc": "解锁普攻第 4 段（伤害 20）", "price": 50},
	# ---- 解锁类・重剑（v2.0） ----
	"zj_zhen_di": {"name": "重剑・震地砸", "school": "combo", "category": "unlock", "weapon_id": "zhongjian", "unlock_combo_id": "zhongjian_derive_ground", "desc": "1 段普攻中 S+K：砸地冲击波 + 眩晕 0.4s", "price": 50},
	"zj_jia_zhao": {"name": "重剑・架招反击", "school": "combo", "category": "unlock", "weapon_id": "zhongjian", "unlock_combo_id": "zhongjian_derive_parry", "desc": "2 段普攻中按 L：直入完美弹反预备（窗口 0.25s）", "price": 50},
	"zj_3rd": {"name": "重剑・崩山劈", "school": "combo", "category": "unlock", "weapon_id": "zhongjian", "unlock_combo_id": "zhongjian_3", "desc": "解锁普攻第 3 段（伤害 40，破甲禁格挡 3s）", "price": 50},
	# ---- 解锁类・短刃（v2.0） ----
	"dr_shan_ci": {"name": "短刃・闪刺", "school": "combo", "category": "unlock", "weapon_id": "duanren", "unlock_combo_id": "duanren_derive_flash", "desc": "2 段普攻中方向+K：突进穿刺（伤害 16）", "price": 50},
	"dr_kong_zhong": {"name": "短刃・空中连斩", "school": "combo", "category": "unlock", "weapon_id": "duanren", "unlock_combo_id": "duanren_derive_air", "unlock_flag": "air_combo", "desc": "3 段普攻中按跳跃：自动起跳接空中 3 段斩（解锁空中连招）", "price": 50},
	"dr_56": {"name": "短刃・疾风连刺", "school": "combo", "category": "unlock", "weapon_id": "duanren", "unlock_combo_id": "duanren_5", "desc": "解锁普攻第 5、6 段（伤害 10/14）", "price": 50},
	# ---- 解锁类・长戈（v2.0） ----
	"cg_hui_ma": {"name": "长戈・回马枪", "school": "combo", "category": "unlock", "weapon_id": "changge", "unlock_combo_id": "changge_derive_back", "desc": "1 段普攻中 A+K：回身反刺（伤害 20，大击退）", "price": 50},
	"cg_tiao_fei": {"name": "长戈・挑飞", "school": "combo", "category": "unlock", "weapon_id": "changge", "unlock_combo_id": "changge_derive_uplift", "unlock_flag": "air_combo", "desc": "2 段普攻中 W+K：大范围群体浮空（伤害 16），解锁空中追击", "price": 50},
	"cg_3rd": {"name": "长戈・横扫千军", "school": "combo", "category": "unlock", "weapon_id": "changge", "unlock_combo_id": "changge_3", "desc": "解锁普攻第 3 段：360° 横扫（伤害 25）", "price": 50},
	# ---- 强化类（v2.0 新增） ----
	"lian_ren": {"name": "连刃", "school": "swift", "category": "buff", "desc": "普攻每段伤害 +15%", "price": 50},
	"po_shi": {"name": "破势", "school": "swift", "category": "buff", "desc": "派生技伤害 +25%", "price": 50},
	"zhong_shi": {"name": "终势", "school": "swift", "category": "buff", "desc": "终结技伤害 +30%", "price": 50},
	"yan_zhi": {"name": "延滞", "school": "swift", "category": "buff", "desc": "攻击命中敌人硬直延长 0.15s", "price": 50},
	"guang_yu": {"name": "广域", "school": "swift", "category": "buff", "desc": "所有攻击范围 +20%", "price": 50},
	"kuai_ren": {"name": "快刃", "school": "swift", "category": "buff", "desc": "普攻连招衔接窗口 +0.1s", "price": 50},
	# ---- 机制增益类（v2.0 新增） ----
	"lian_ji_tong": {"name": "连击精通", "school": "mystic", "category": "mechanic", "desc": "连击增伤上限升至 50%，每 10 连击 +5%", "price": 50},
	"xi_lian": {"name": "息连", "school": "mystic", "category": "mechanic", "desc": "每命中 10 连击，恢复 8 点内息", "price": 50},
	"xue_lian": {"name": "血连", "school": "mystic", "category": "mechanic", "desc": "每命中 20 连击，恢复 5 点生命", "price": 50},
	"rou_hua": {"name": "柔化", "school": "mystic", "category": "mechanic", "desc": "所有攻击后摇缩短 20%，取消更轻松", "price": 50},
	"bu_duan": {"name": "不断", "school": "mystic", "category": "mechanic", "desc": "受击后连击不清零，仅减半", "price": 50},
	# ---- 特效追加类（v2.0 新增） ----
	"jian_qi_yu_yun": {"name": "剑气余韵", "school": "guard", "category": "effect", "desc": "每段普攻附带剑气，伤害为该段的 30%", "price": 50},
	"shuang_han": {"name": "霜寒", "school": "guard", "category": "effect", "desc": "连招命中叠加减速，3 层合计 30%，持续 2s", "price": 50},
	"bao_lie": {"name": "爆裂", "school": "guard", "category": "effect", "desc": "终结技命中产生范围爆炸（50% 伤害）", "price": 50},
	"xi_xing": {"name": "吸星", "school": "guard", "category": "effect", "desc": "连招连续命中 5 次，吸血 3 点生命", "price": 50},
	"po_jia_ci": {"name": "破甲", "school": "guard", "category": "effect", "desc": "派生攻击附带破甲：击破格挡 + 禁格挡 1.5s", "price": 50},
}
const SCHOOL_NAMES := {"swift": "快剑流", "heavy": "重破流", "guard": "御剑流", "mystic": "玄劲流", "combo": "招式"}
const SCHOOL_ICONS := {
	"swift": "res://Assets/Art/Icons/icon_swift.png",
	"heavy": "res://Assets/Art/Icons/icon_heavy.png",
	"guard": "res://Assets/Art/Icons/icon_guard.png",
	"mystic": "res://Assets/Art/Icons/icon_mystic.png",
	"combo": "res://Assets/Art/Icons/icon_unlock.png",
}
const CATEGORY_NAMES := {"unlock": "解锁", "buff": "强化", "mechanic": "增益", "effect": "特效"}

# 词条效果数值
const ENTRY_VALUES := {
	"sword_qi_dmg": 5,          # 剑风
	"heavy_shock_dmg": 10,      # 震岳
	"heavy_shock_radius": 48.0,
	"flying_sword_dmg": 12,     # 御灵
	"flying_sword_chance": 0.2,
	"flying_sword_pierce": 2,   # 剑链
	"flying_sword_qi_return": 5,  # 星归
	"parry_wave_dmg": 15,       # 劲波
	"parry_wave_radius": 40.0,
	"max_hp_bonus": 20,         # 固元
	# ---- v2.0 连击 / 取消 ----
	"combo_timer": 1.5,         # 连击计时器
	"combo_bonus_per_10": 0.03, # 每 10 连击 +3%
	"combo_bonus_cap": 0.30,    # 增伤上限 30%
	"combo_master_per_10": 0.05,  # 连击精通：每 10 连击 +5%
	"combo_master_cap": 0.50,   # 连击精通：上限 50%
	"xi_lian_qi": 8,            # 息连
	"xue_lian_hp": 5,           # 血连
	"xi_xing_heal": 3,          # 吸星
	"xi_xing_interval": 5,      # 吸星触发间隔（连续命中次数）
	"qi_echo_ratio": 0.3,       # 剑气余韵
	"explode_ratio": 0.5,      # 爆裂
	"explode_radius": 48.0,
	"stagger_add": 0.15,        # 延滞
	"range_mult": 1.2,          # 广域
	"normal_dmg_mult": 1.15,    # 连刃
	"derive_dmg_mult": 1.25,    # 破势
	"finisher_dmg_mult": 1.30,  # 终势
	"recovery_mult": 0.8,       # 柔化
	"guard_ban_derive": 1.5,    # 破甲词条禁格挡时长
	"ji_ying_cancel_cost": 7.0,  # 疾影闪避取消内息
}
const WEAPON_PRICE := 80

# ---------------- 消耗品（商店购买后立即生效） ----------------
const CONSUMABLES := {
	"hui_yuan_dan": {"name": "回元丹", "desc": "立即回复 40 生命值", "price": 30, "icon": "res://Assets/Art/Icons/icon_pill.png"},
	"ning_shen_san": {"name": "凝神散", "desc": "回满内息，8 秒内内息消耗减半", "price": 25, "icon": "res://Assets/Art/Icons/icon_sachet.png"},
	"ba_ti_fu": {"name": "霸体符", "desc": "5 秒霸体（受击不僵直）", "price": 40, "icon": "res://Assets/Art/Icons/icon_talisman.png"},
}
const ENTRY_PRICE := 50

# ---------------- 敌人（策划案第四节） ----------------
const ENEMIES := {
	"sword_disciple": {
		"name": "叛门剑徒", "hp": 40, "dmg": 10, "speed": 200.0, "cd": 1.2,
		"gold": 5, "kind": "melee", "windup": 0.4, "strikes": 3, "strike_gap": 0.2,
		"reach": 44.0, "unblockable": false, "parryable": true, "parry_window": 0.2,
		"scene": "res://Scenes/Characters/enemy_sword_disciple.tscn",
	},
	"shan_xiao": {
		"name": "山魈妖物", "hp": 25, "dmg": 8, "speed": 280.0, "cd": 0.8,
		"gold": 5, "kind": "pounce", "windup": 0.25, "strikes": 1, "strike_gap": 0.0,
		"reach": 40.0, "unblockable": true, "parryable": false, "parry_window": 0.0,
		"pounce_range": 160.0, "scene": "res://Scenes/Characters/enemy_shan_xiao.tscn",
	},
	"gu_daoist": {
		"name": "蛊毒道童", "hp": 30, "dmg": 7, "speed": 150.0, "cd": 2.0,
		"gold": 5, "kind": "ranged", "windup": 0.5, "strikes": 1, "strike_gap": 0.0,
		"reach": 40.0, "unblockable": false, "parryable": true, "parry_window": 0.2,
		"keep_min": 150.0, "keep_max": 250.0, "shot_range": 400.0, "shot_speed": 250.0,
		"scene": "res://Scenes/Characters/enemy_gu_daoist.tscn",
	},
	"dual_blade": {
		"name": "双刀狂徒", "hp": 120, "dmg": 12, "speed": 260.0, "cd": 0.6,
		"gold": 30, "kind": "elite", "windup": 0.35, "strikes": 5, "strike_gap": 0.12,
		"reach": 48.0, "unblockable": false, "parryable": true, "parry_window": 0.15,
		"thrust_windup": 0.2, "thrust_trigger_range": 180.0, "thrust_speed": 520.0,
		"scene": "res://Scenes/Characters/enemy_dual_blade.tscn",
	},
}
# ---------------- 三层秘境与 BOSS（策划案 5.4 / 6.3） ----------------
# 连续三层推进：每层 10 房，层末 BOSS + 休憩点；第三层休憩点后触发通关。
const LAYERS := [
	{"id": "yunjian", "name": "第一层 · 云涧松径", "boss_id": "boss_xuanfeng",
		"tint": Color(1.0, 1.0, 1.0)},
	{"id": "youhuang", "name": "第二层 · 幽篁毒泽", "boss_id": "boss_bilv",
		"tint": Color(0.80, 1.0, 0.84)},
	{"id": "chixiao", "name": "第三层 · 赤霄魔窟", "boss_id": "boss_chixiao",
		"tint": Color(1.0, 0.80, 0.74)},
]

static func layer_cfg(index: int) -> Dictionary:
	return LAYERS[clampi(index, 0, LAYERS.size() - 1)]


static func boss_cfg(boss_id: String) -> Dictionary:
	match boss_id:
		"boss_bilv":
			return BOSS_BILV
		"boss_chixiao":
			return BOSS_CHIXIAO
		_:
			return BOSS


static func boss_cfg_for_layer(index: int) -> Dictionary:
	return boss_cfg(layer_cfg(index).boss_id)


# 第一层守关：玄风剑主
const BOSS := {
	"id": "boss_xuanfeng", "name": "玄风剑主", "hp": 300, "dmg": 18, "speed": 220.0,
	"gold": 50,
	"iai_windup": 0.6, "iai_reach": 48.0,
	"qi_windup": 0.4, "qi_speed": 350.0, "qi_size": Vector2(16, 8),
	"guard_time": 1.5, "guard_cd": 5.0, "guard_reduce": 0.8, "guard_break_stagger": 1.0,
	"thrust_windup": 0.3, "thrust_distance": 200.0,
	"phase2_hp": 0.5, "phase2_speed_mult": 1.3,
	"parryable": true, "parry_window": 0.2,
	"scene": "res://Scenes/Characters/boss_xuanfeng.tscn",
}

# 第二层守关：碧毒尊者（毒瘴弹幕：一阶段 3 发 / 二阶段 5 发）
const BOSS_BILV := {
	"id": "boss_bilv", "name": "碧毒尊者", "hp": 420, "dmg": 20, "speed": 210.0,
	"gold": 70,
	"iai_windup": 0.55, "iai_reach": 48.0,
	"qi_windup": 0.4, "qi_speed": 330.0, "qi_size": Vector2(16, 8),
	"guard_time": 1.5, "guard_cd": 5.0, "guard_reduce": 0.8, "guard_break_stagger": 1.0,
	"thrust_windup": 0.3, "thrust_distance": 200.0,
	"venom_windup": 0.5, "venom_shots": 3, "venom_shots_phase2": 5,
	"venom_dmg": 10, "venom_speed": 240.0, "venom_spread": 0.22,
	"phase2_hp": 0.5, "phase2_speed_mult": 1.25,
	"parryable": true, "parry_window": 0.2,
	"scene": "res://Scenes/Characters/boss_bilv.tscn",
}

# 第三层守关：赤霄魔君（天火剑气：二阶段远距离五连扇射）
const BOSS_CHIXIAO := {
	"id": "boss_chixiao", "name": "赤霄魔君", "hp": 560, "dmg": 24, "speed": 240.0,
	"gold": 100,
	"iai_windup": 0.55, "iai_reach": 52.0,
	"qi_windup": 0.36, "qi_speed": 380.0, "qi_size": Vector2(16, 8),
	"guard_time": 1.4, "guard_cd": 4.5, "guard_reduce": 0.8, "guard_break_stagger": 1.0,
	"thrust_windup": 0.28, "thrust_distance": 240.0,
	"blaze_windup": 0.45, "blaze_shots": 5, "blaze_dmg": 16, "blaze_speed": 360.0,
	"blaze_spread": 0.18,
	"phase2_hp": 0.5, "phase2_speed_mult": 1.3,
	"parryable": true, "parry_window": 0.2,
	"scene": "res://Scenes/Characters/boss_chixiao.tscn",
}

# ---------------- 关卡（策划案第五节） ----------------
# BOSS 房后追加休息点：通关前补满血瓶，随后触发破境结算
const ROOM_SEQUENCE := [
	"combat", "combat", "combat", "elite", "combat", "combat", "shop", "trial", "boss", "rest",
]
const ECONOMY := {"start_gold": 30, "max_gold": 999, "trial_bonus": 20}
const TRIAL_TIME := 30.0
const TRIAL_ENEMIES := ["sword_disciple", "sword_disciple", "shan_xiao", "gu_daoist"]
const REST_HEAL := 2.0  # 每秒

# ---------------- 分支舆图（每层一套 DAG，见 run_map.gd） ----------------
const MAP_TYPE_NAMES := {
	"start": "起点", "combat": "战斗", "elite": "精英", "event": "事件",
	"shop": "商铺", "trial": "试炼", "boss": "首领",
}

# ---------------- 奇遇事件（事件房三选一） ----------------
# effect 支持逗号分隔多条：heal:N / gold:N / flask:N / qi_full / entry
const EVENTS := {
	"shan_quan": {
		"title": "山中清泉",
		"desc": "岩壁裂隙间渗出一泓清泉，寒气里裹着草木清香。",
		"options": [
			{"text": "掬水而饮 · 回复 35 生命", "effect": "heal:35"},
			{"text": "装瓶备用 · 血瓶 +1", "effect": "flask:1"},
			{"text": "凝神调息 · 内息回满", "effect": "qi_full"},
		],
	},
	"can_jian": {
		"title": "残剑遗冢",
		"desc": "乱石间插满断剑，剑柄上刻着前人未竟的招式。",
		"options": [
			{"text": "掘取剑穗 · 尘珠 +45", "effect": "gold:45"},
			{"text": "临碑悟招 · 随机词条", "effect": "entry"},
			{"text": "拂去尘土 · 回复 20 生命", "effect": "heal:20"},
		],
	},
	"yun_you": {
		"title": "云游道人",
		"desc": "道人倚松煮茶，笑问你可愿听一段旧事。",
		"options": [
			{"text": "以茶换讯 · 尘珠 +30", "effect": "gold:30"},
			{"text": "求一道符 · 血瓶 +1", "effect": "flask:1"},
			{"text": "听其论道 · 回复 25 生命", "effect": "heal:25"},
		],
	},
}

# ---------------- 血瓶（R 键使用，休息点补满） ----------------
const FLASK := {"max_uses": 3, "heal": 40.0}

const ROOM_SCENES := {
	"combat": "res://Scenes/Rooms/room_combat.tscn",
	"elite": "res://Scenes/Rooms/room_elite.tscn",
	"event": "res://Scenes/Rooms/room_event.tscn",
	"rest": "res://Scenes/Rooms/room_rest.tscn",
	"shop": "res://Scenes/Rooms/room_shop.tscn",
	"trial": "res://Scenes/Rooms/room_trial.tscn",
	"boss": "res://Scenes/Rooms/room_boss.tscn",
}

# 房间几何: 宽度 / 地面高度 / 平台 / 敌人刷新点 / 装饰
const LAYOUTS := {
	"combat": {
		"width": 960, "floor_y": 320,
		"platforms": [Rect2(200, 240, 160, 8), Rect2(560, 200, 128, 8)],
		"spawn": [Vector2(380, 320), Vector2(620, 320), Vector2(760, 320)],
		"deco": ["pine", "stele", "pine"],
	},
	"elite": {
		"width": 960, "floor_y": 320,
		"platforms": [Rect2(320, 240, 160, 8)],
		"spawn": [Vector2(640, 320), Vector2(820, 320)],
		"deco": ["pine", "stele"],
	},
	"event": {
		"width": 640, "floor_y": 320,
		"platforms": [],
		"spawn": [Vector2(400, 320)],
		"deco": ["pine", "mist", "stele"],
	},
	"rest": {
		"width": 640, "floor_y": 320,
		"platforms": [],
		"spawn": [],
		"deco": ["pine", "stele", "pine", "mist"],
	},
	"shop": {
		"width": 640, "floor_y": 320,
		"platforms": [],
		"spawn": [],
		"deco": ["pine", "mist"],
	},
	"trial": {
		"width": 960, "floor_y": 320,
		"platforms": [Rect2(300, 240, 128, 8), Rect2(560, 240, 128, 8)],
		"spawn": [Vector2(360, 320), Vector2(520, 320), Vector2(680, 320), Vector2(820, 320)],
		"deco": ["stele", "pine"],
	},
	"boss": {
		"width": 1280, "floor_y": 320,
		"platforms": [Rect2(280, 240, 128, 8), Rect2(840, 240, 128, 8)],
		"spawn": [],
		"deco": ["pine", "stele", "pine"],
	},
}
const PLATFORM_TOP_COLOR := Color(0.8, 0.9, 0.88)

# ---------------- 路径 ----------------
const PLAYER_SCENE := "res://Scenes/Characters/player.tscn"
const PORTAL_SCENE := "res://Scenes/Rooms/portal.tscn"
const MERCHANT_SCENE := "res://Scenes/Rooms/merchant.tscn"
const EVENT_SHRINE_SCENE := "res://Scenes/Rooms/event_shrine.tscn"
const MAP_SCENE := "res://Scenes/UI/map_screen.tscn"
const WEAPON_SELECT_SCENE := "res://Scenes/UI/menu_weapon_select.tscn"
const EVENT_PANEL_SCENE := "res://Scenes/UI/panel_event.tscn"
const PROJECTILE_SCENE := "res://Scenes/projectile.tscn"
const MAIN_SCENE := "res://Scenes/Main.tscn"
const MENU_MAIN_SCENE := "res://Scenes/UI/menu_main.tscn"
