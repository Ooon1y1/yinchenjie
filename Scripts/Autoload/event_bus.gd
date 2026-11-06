# event_bus.gd — 全局信号总线（AutoLoad）
# 跨模块事件一律走此处信号，禁止节点间硬引用查找（策划案第七节技术约定）。
extends Node

# ---- 战斗反馈 ----
signal hitstop_requested(duration: float)
signal shake_requested(strength: float, duration: float)
signal fx_requested(fx_id: String, pos: Vector2, flip_x: bool, scale: float)

# ---- 玩家状态 ----
signal player_hp_changed(hp: int, max_hp: int)
signal player_qi_changed(qi: int, max_qi: int)
signal player_died
signal player_spawned(player: Node)
signal flasks_changed(current: int, max_uses: int)

# ---- 敌人 / 房间 ----
signal enemy_killed(enemy_id: String, gold: int)
signal room_cleared(room_id: String)
signal trial_time_changed(remain: float)
signal boss_spawned(boss_name: String, max_hp: int)
signal boss_hp_changed(hp: int, max_hp: int)
signal boss_defeated
signal layer_changed(layer: int, layer_name: String)

# ---- 经济 / 词条 ----
signal gold_changed(gold: int)
signal entry_added(entry_id: String)
signal interact_changed(text: String)

# ---- 连招系统（v2.0） ----
signal combo_tick(count: int, ratio: float)
signal combo_milestone(count: int)
signal weapon_changed(weapon_id: String)

# ---- 提示 ----
signal toast(text: String)
