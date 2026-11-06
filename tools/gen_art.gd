# gen_art.gd — 占位像素美术生成器（无头运行）
# 用法: godot --headless --path D:/game -s res://tools/gen_art.gd
# 输出全部 PNG 至 Assets/Art/**，均为 32px 精灵、青碧灰低饱和配色，符合策划案第六节规范。
extends SceneTree

const OUT := "res://Assets/Art"

# ---------------- 调色板（低饱和 青/碧/灰） ----------------
const INK := Color(0.13, 0.15, 0.17)
const ROBE := Color(0.38, 0.42, 0.44)
const ROBE_D := Color(0.24, 0.27, 0.29)
const TRIM := Color(0.38, 0.71, 0.66)
const SKIN := Color(0.83, 0.75, 0.63)
const HAIR := Color(0.14, 0.16, 0.18)
const STEEL := Color(0.79, 0.85, 0.86)
const STEEL_HI := Color(0.95, 0.98, 0.98)
const HILT := Color(0.28, 0.24, 0.20)
const LEG := Color(0.21, 0.23, 0.25)
const GLOW := Color(0.59, 0.95, 0.86)
const WHITE := Color(0.93, 0.96, 0.96)
const STONE := Color(0.37, 0.42, 0.42)
const STONE_D := Color(0.27, 0.31, 0.31)
const MOSS := Color(0.43, 0.55, 0.47)
const WOOD := Color(0.43, 0.36, 0.30)
const PINE := Color(0.23, 0.38, 0.33)
const MIST := Color(0.78, 0.84, 0.84, 0.24)
const MOUNT := Color(0.42, 0.52, 0.53, 0.85)
const MOUNT_D := Color(0.30, 0.40, 0.41, 0.9)
const ORB := Color(0.45, 0.85, 0.45)

# ---------------- 基础绘图 ----------------

func img(w: int, h: int) -> Image:
	if ClassDB.class_has_method("Image", "create_empty"):
		return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


func px(i: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < i.get_width() and y < i.get_height():
		i.set_pixel(x, y, c)


func rectf(i: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	i.fill_rect(Rect2i(x, y, w, h), c)


func line(i: Image, a: Vector2i, b: Vector2i, c: Color, t: int = 1) -> void:
	var dx := absi(b.x - a.x)
	var dy := absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx - dy
	var x := a.x
	var y := a.y
	while true:
		for o in t:
			px(i, x, y + o, c)
		if x == b.x and y == b.y:
			break
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy


func hline(i: Image, x0: int, x1: int, y: int, c: Color) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		px(i, x, y, c)


func vline(i: Image, y0: int, y1: int, x: int, c: Color) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		px(i, x, y, c)


func disc(i: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(-r, r + 1):
		var w := int(floor(sqrt(maxf(0.0, r * r - y * y))))
		hline(i, cx - w, cx + w, cy + y, c)


func ring(i: Image, cx: int, cy: int, r: int, c: Color) -> void:
	var steps := int(6.2832 * r) + 8
	for s in steps:
		var a := TAU * s / steps
		px(i, cx + int(round(cos(a) * r)), cy + int(round(sin(a) * r)), c)


func rng(seed_i: int) -> float:
	return fmod(absf(sin(seed_i * 127.1) * 43758.545), 1.0)


func save_png(i: Image, path: String) -> void:
	var err := i.save_png(path)
	if err != OK:
		push_error("保存失败: " + path)
	else:
		print("  ✓ ", path)


# ---------------- 人形渲染器 ----------------

func _draw_sword(i: Image, hand: Vector2i, deg: float, len: int, pal: Dictionary, glow: bool) -> void:
	var a := deg_to_rad(deg)
	var dir := Vector2(cos(a), sin(a))
	var tip := hand + Vector2i((dir * len).round())
	var mid := hand + Vector2i((dir * len * 0.5).round())
	if pal.get("pole", false):
		# 长柄武器（长戈）：木杆 65% + 枪头钢刃 35% + 红缨
		var shaft_end := hand + Vector2i((dir * len * 0.65).round())
		var blade_start := shaft_end - Vector2i((dir * 1.5).round())
		line(i, hand, shaft_end, WOOD, 2)
		line(i, blade_start, tip, pal.steel, 2)
		px(i, tip.x, tip.y, pal.steel_hi)
		var tassel := shaft_end + Vector2i((dir * 2.0).round())
		px(i, tassel.x, tassel.y - 1, Color(0.7, 0.28, 0.24))
		px(i, tassel.x, tassel.y, Color(0.7, 0.28, 0.24))
		if glow:
			px(i, mid.x, mid.y, GLOW)
		return
	line(i, hand, tip, pal.steel, 2)
	px(i, tip.x, tip.y, pal.steel_hi)
	# 护手 + 柄
	var guard := hand + Vector2i((dir * 1.0).round())
	px(i, guard.x, guard.y - 1, pal.hilt)
	px(i, guard.x, guard.y + 2, pal.hilt)
	line(i, hand, hand - Vector2i((dir * 2).round()), pal.hilt, 2)
	if glow:
		px(i, mid.x, mid.y, GLOW)
		px(i, int((mid.x + tip.x) * 0.5), int((mid.y + tip.y) * 0.5), GLOW)


func humanoid(i: Image, pal: Dictionary, pose: Dictionary) -> void:
	var crouch: int = pose.get("crouch", 0)
	var lean: int = pose.get("lean", 0)
	var legs: String = pose.get("legs", "stand")
	var phase: float = pose.get("leg_phase", 0.0)
	var foot_y := 31
	var hip_y := 23 + mini(crouch, 6)

	if pose.get("type", "normal") == "lie":
		# 倒地：水平躯干 + 头 + 掉落的剑
		rectf(i, 7, 26, 16, 4, pal.robe)
		rectf(i, 7, 29, 16, 1, pal.robe_d)
		rectf(i, 2, 25, 5, 5, pal.robe)
		rectf(i, 2, 25, 5, 2, pal.hair)
		rectf(i, 4, 28, 2, 2, pal.skin)
		rectf(i, 23, 25, 8, 3, pal.robe_d)
		hline(i, 4, 18, 31, pal.steel) if pal.get("has_sword", true) else null
		px(i, 3, 31, pal.steel_hi)
		return

	# 腿
	if legs == "stride":
		var sw := sin(phase * TAU)
		var fx := 16 + int(round(sw * 5.0))
		var bx := 16 - int(round(sw * 5.0))
		var fy := foot_y - int(round(absf(sw) * 1.5))
		line(i, Vector2i(14, hip_y - 1), Vector2i(fx, fy), pal.leg, 2)
		line(i, Vector2i(18, hip_y - 1), Vector2i(bx, foot_y), pal.leg, 2)
	elif legs == "air":
		line(i, Vector2i(14, hip_y - 1), Vector2i(11, hip_y + 3), pal.leg, 2)
		line(i, Vector2i(18, hip_y - 1), Vector2i(20, hip_y + 2), pal.leg, 2)
	elif legs == "spread":
		line(i, Vector2i(14, hip_y - 1), Vector2i(10, foot_y), pal.leg, 2)
		line(i, Vector2i(18, hip_y - 1), Vector2i(22, foot_y - 2), pal.leg, 2)
	elif legs == "trail":
		line(i, Vector2i(15, hip_y - 1), Vector2i(8, foot_y - 1), pal.leg, 2)
		line(i, Vector2i(17, hip_y - 1), Vector2i(11, foot_y), pal.leg, 2)
	elif legs == "kneel":
		rectf(i, 17, hip_y + 1, 3, foot_y - hip_y - 1, pal.leg)
		rectf(i, 10, foot_y - 1, 7, 2, pal.leg)
		rectf(i, 10, hip_y + 2, 3, 2, pal.leg)
	else:  # stand
		rectf(i, 13, hip_y - 1, 2, foot_y - hip_y + 1, pal.leg)
		rectf(i, 17, hip_y - 1, 2, foot_y - hip_y + 1, pal.leg)

	# 躯干（袍）+ 腰带
	var torso_top := hip_y - 11
	rectf(i, 12 + lean, torso_top, 7, hip_y - torso_top, pal.robe)
	rectf(i, 12 + lean, torso_top + 1, 1, 3, pal.robe_d)
	rectf(i, 12 + lean, hip_y - 4, 7, 2, pal.trim)
	vline(i, torso_top, hip_y - 1, 18 + lean, pal.robe_d)

	# 头 + 发 + 脸
	rectf(i, 13 + lean, torso_top - 6, 6, 6, pal.skin)
	rectf(i, 13 + lean, torso_top - 6, 6, 3, pal.hair)
	px(i, 17 + lean, torso_top - 2, pal.hair)
	px(i, 19 + lean, torso_top - 4, pal.skin)
	# 束发 / 斗笠
	if pal.get("hat", false):
		rectf(i, 10 + lean, torso_top - 8, 12, 2, pal.hat_c if pal.has("hat_c") else pal.hair)
		rectf(i, 13 + lean, torso_top - 9, 6, 1, pal.hat_c if pal.has("hat_c") else pal.hair)

	# 后手臂（持双刀者背后刀）
	var hand: Vector2i = pose.get("hand", Vector2i(20, 18))
	var shoulder := Vector2i(15 + lean, torso_top + 2)
	if pal.get("dual", false):
		var b_a: float = pose.get("sword2_a", -140.0)
		var back_sh := Vector2i(13 + lean, torso_top + 3)
		var b_hand := back_sh + Vector2i(2, -1)
		line(i, back_sh, b_hand, pal.robe_d, 2)
		_draw_sword(i, b_hand, b_a, pose.get("sword2_len", 10), pal, false)

	# 前臂
	line(i, shoulder, hand, pal.robe_d, 2)

	# 剑 / 珠
	if pose.get("orb", false):
		disc(i, hand.x, hand.y, 2, pal.orb_c if pal.has("orb_c") else ORB)
		px(i, hand.x - 1, hand.y - 1, WHITE)
		if pose.get("glow", false):
			ring(i, hand.x, hand.y, 4, Color(pal.orb_c.r, pal.orb_c.g, pal.orb_c.b, 0.5))
	elif pal.get("has_sword", true):
		_draw_sword(i, hand, pose.get("sword_a", 70.0), pose.get("sword_len", 10), pal, pose.get("glow", false))

	# 挥砍轨迹
	if pose.get("arc", false):
		var cx := 13
		var cy := 17
		for s in 10:
			var a := deg_to_rad(-40.0 + s * 12.0)
			px(i, cx + int(round(cos(a) * 11.0)), cy + int(round(sin(a) * 11.0)), WHITE)
			px(i, cx + int(round(cos(a) * 12.0)), cy + int(round(sin(a) * 12.0)), GLOW)

	# 蓄力光效
	if pose.get("aura", false):
		ring(i, 16, 18, 13, Color(GLOW.r, GLOW.g, GLOW.b, 0.35))


# ---------------- 猎兽渲染器（山魈） ----------------

func beast(i: Image, pal: Dictionary, pose: Dictionary) -> void:
	var bob: int = pose.get("bob", 0)
	var crouch: int = pose.get("crouch_b", 0)
	var stretch: bool = pose.get("stretch", false)
	var shift: int = pose.get("shift", 0)
	var lying: bool = pose.get("lying", false)

	if lying:
		rectf(i, 4 + shift, 27, 24, 4, pal.body)
		rectf(i, 4 + shift, 30, 24, 1, pal.dark)
		rectf(i, 26 + shift, 27, 4, 3, pal.body)
		px(i, 27 + shift, 28, Color(0.2, 0.2, 0.2))
		return

	if stretch:
		# 扑击：拉长的身躯
		rectf(i, 6, 20, 22, 7, pal.body)
		rectf(i, 6, 26, 22, 1, pal.dark)
		rectf(i, 24, 18, 6, 6, pal.body)
		rectf(i, 28, 21, 3, 2, pal.dark)  # 张口
		px(i, 26, 19, pal.eye)
		px(i, 24, 19, pal.eye)
		# 前爪伸展
		rectf(i, 28, 24, 3, 2, pal.dark)
		# 后腿拖尾
		line(i, Vector2i(8, 26), Vector2i(3, 30), pal.dark, 2)
		line(i, Vector2i(11, 26), Vector2i(5, 31), pal.dark, 2)
		return

	# 常态 / 蹲伏蓄势
	var top := 16 + bob + crouch * 2
	var bot := 26 + bob
	rectf(i, 9 + shift, top, 17, bot - top, pal.body)
	rectf(i, 9 + shift, bot, 17, 1, pal.dark)
	rectf(i, 21 + shift, top - 2, 6, 6, pal.body)  # 前肩
	# 耳
	px(i, 23 + shift, top - 3, pal.dark)
	px(i, 25 + shift, top - 3, pal.dark)
	# 眼（发光）
	px(i, 24 + shift, top + 1, pal.eye)
	px(i, 26 + shift, top + 1, pal.eye)
	if pose.get("mouth", false):
		rectf(i, 26 + shift, top + 3, 2, 2, Color(0.9, 0.85, 0.8))
	# 腿
	var phase: float = pose.get("leg_phase", 0.0)
	var lift := int(round(absf(sin(phase * TAU)) * 1.0))
	for k in 4:
		var lx := 10 + k * 4 + shift
		var ly := 31 - (lift if (k % 2 == 0 and phase > 0) else 0)
		vline(i, bot, ly, lx, pal.dark)
		vline(i, bot, ly, lx + 1, pal.dark)


# ---------------- 精灵表构建 ----------------

func sheet(frames: int, drawer: Callable, path: String) -> void:
	var s := img(frames * 32, 32)
	for f in frames:
		var frame_img := img(32, 32)
		drawer.call(frame_img, f)
		s.blit_rect(frame_img, Rect2i(0, 0, 32, 32), Vector2i(f * 32, 0))
	save_png(s, path)


func player_poses() -> Dictionary:
	return {
		"idle": {"frames": 4, "poses": [
			{"crouch": 0}, {"crouch": 1}, {"crouch": 1}, {"crouch": 0},
		]},
		"walk": {"frames": 6, "poses": [
			{"legs": "stride", "leg_phase": 0.0}, {"legs": "stride", "leg_phase": 0.17},
			{"legs": "stride", "leg_phase": 0.33}, {"legs": "stride", "leg_phase": 0.5},
			{"legs": "stride", "leg_phase": 0.67}, {"legs": "stride", "leg_phase": 0.83},
		]},
		"jump": {"frames": 1, "poses": [{"legs": "air", "hand": Vector2i(19, 12), "sword_a": -35.0, "sword_len": 11}]},
		"fall": {"frames": 1, "poses": [{"legs": "spread", "hand": Vector2i(20, 15), "sword_a": -10.0, "sword_len": 11}]},
		"light_attack_1": {"frames": 3, "poses": [
			{"hand": Vector2i(11, 10), "sword_a": -125.0, "sword_len": 11},
			{"hand": Vector2i(22, 17), "sword_a": -8.0, "sword_len": 13, "arc": true},
			{"hand": Vector2i(20, 21), "sword_a": 35.0, "sword_len": 11},
		]},
		"light_attack_2": {"frames": 3, "poses": [
			{"hand": Vector2i(13, 7), "sword_a": -95.0, "sword_len": 11},
			{"hand": Vector2i(21, 15), "sword_a": 45.0, "sword_len": 12, "arc": true},
			{"hand": Vector2i(17, 22), "sword_a": 80.0, "sword_len": 10},
		]},
		"light_attack_3": {"frames": 3, "poses": [
			{"hand": Vector2i(9, 12), "sword_a": -150.0, "sword_len": 12, "lean": -1},
			{"hand": Vector2i(24, 16), "sword_a": 0.0, "sword_len": 16, "lean": 1, "arc": true, "glow": true},
			{"hand": Vector2i(18, 22), "sword_a": 60.0, "sword_len": 11},
		]},
		# ---- v2.0 连招扩展动作 ----
		"light_attack_4": {"frames": 3, "poses": [
			{"hand": Vector2i(10, 15), "sword_a": 200.0, "sword_len": 12, "lean": -1},
			{"hand": Vector2i(23, 13), "sword_a": -15.0, "sword_len": 14, "lean": 1, "arc": true},
			{"hand": Vector2i(20, 20), "sword_a": 50.0, "sword_len": 11},
		]},
		"light_attack_5": {"frames": 2, "poses": [
			{"hand": Vector2i(21, 16), "sword_a": -5.0, "sword_len": 12},
			{"hand": Vector2i(23, 17), "sword_a": -2.0, "sword_len": 14, "glow": true},
		]},
		"light_attack_6": {"frames": 3, "poses": [
			{"hand": Vector2i(9, 9), "sword_a": -100.0, "sword_len": 12},
			{"hand": Vector2i(22, 18), "sword_a": 40.0, "sword_len": 15, "arc": true, "glow": true},
			{"hand": Vector2i(24, 10), "sword_a": -30.0, "sword_len": 14, "arc": true},
		]},
		"combo_3": {"frames": 4, "poses": [
			{"hand": Vector2i(9, 17), "sword_a": 185.0, "sword_len": 13, "crouch": 1},
			{"hand": Vector2i(9, 18), "sword_a": 188.0, "sword_len": 13, "crouch": 2, "glow": true},
			{"hand": Vector2i(25, 18), "sword_a": -8.0, "sword_len": 16, "arc": true, "lean": 1, "glow": true},
			{"hand": Vector2i(21, 20), "sword_a": 45.0, "sword_len": 12},
		]},
		"derive_up": {"frames": 3, "poses": [
			{"hand": Vector2i(15, 20), "sword_a": 100.0, "sword_len": 12, "crouch": 2},
			{"hand": Vector2i(17, 10), "sword_a": -75.0, "sword_len": 13, "legs": "air", "arc": true, "glow": true},
			{"hand": Vector2i(18, 6), "sword_a": -60.0, "sword_len": 12, "legs": "air"},
		]},
		"derive_qi": {"frames": 3, "poses": [
			{"hand": Vector2i(12, 12), "sword_a": -120.0, "sword_len": 12, "lean": -1},
			{"hand": Vector2i(24, 15), "sword_a": -5.0, "sword_len": 14, "lean": 1, "glow": true},
			{"hand": Vector2i(24, 16), "sword_a": -3.0, "sword_len": 14, "glow": true},
		]},
		"derive_ground": {"frames": 4, "poses": [
			{"hand": Vector2i(12, 4), "sword_a": -80.0, "sword_len": 13, "crouch": 1},
			{"hand": Vector2i(13, 3), "sword_a": -85.0, "sword_len": 13, "crouch": 1, "glow": true, "aura": true},
			{"hand": Vector2i(21, 22), "sword_a": 100.0, "sword_len": 11, "crouch": 2, "arc": true},
			{"hand": Vector2i(20, 25), "sword_a": 115.0, "sword_len": 10, "crouch": 3},
		]},
		"derive_flash": {"frames": 3, "poses": [
			{"hand": Vector2i(10, 15), "sword_a": 175.0, "sword_len": 11, "lean": 2, "legs": "trail"},
			{"hand": Vector2i(26, 16), "sword_a": -5.0, "sword_len": 14, "lean": 3, "legs": "spread", "arc": true, "glow": true},
			{"hand": Vector2i(24, 17), "sword_a": 10.0, "sword_len": 13, "lean": 2, "legs": "spread"},
		]},
		"derive_back": {"frames": 3, "poses": [
			{"hand": Vector2i(10, 14), "sword_a": 160.0, "sword_len": 12, "lean": -2},
			{"hand": Vector2i(4, 16), "sword_a": 195.0, "sword_len": 14, "lean": -3, "arc": true, "glow": true},
			{"hand": Vector2i(6, 18), "sword_a": 185.0, "sword_len": 12, "lean": -2},
		]},
		"finisher": {"frames": 4, "poses": [
			{"hand": Vector2i(14, 3), "sword_a": -75.0, "sword_len": 13, "crouch": 1, "glow": true},
			{"hand": Vector2i(14, 4), "sword_a": -78.0, "sword_len": 13, "crouch": 2, "glow": true, "aura": true},
			{"hand": Vector2i(24, 18), "sword_a": 30.0, "sword_len": 17, "arc": true, "lean": 2, "glow": true, "aura": true},
			{"hand": Vector2i(22, 22), "sword_a": 65.0, "sword_len": 13, "lean": 1},
		]},
		"air_attack_1": {"frames": 3, "poses": [
			{"legs": "air", "hand": Vector2i(12, 10), "sword_a": -110.0, "sword_len": 12},
			{"legs": "air", "hand": Vector2i(22, 16), "sword_a": 30.0, "sword_len": 13, "arc": true},
			{"legs": "air", "hand": Vector2i(20, 20), "sword_a": 60.0, "sword_len": 11},
		]},
		"air_attack_2": {"frames": 3, "poses": [
			{"legs": "air", "hand": Vector2i(22, 10), "sword_a": -60.0, "sword_len": 12},
			{"legs": "air", "hand": Vector2i(23, 17), "sword_a": 80.0, "sword_len": 13, "arc": true},
			{"legs": "air", "hand": Vector2i(19, 21), "sword_a": 110.0, "sword_len": 11},
		]},
		"air_attack_3": {"frames": 3, "poses": [
			{"legs": "air", "hand": Vector2i(10, 12), "sword_a": 170.0, "sword_len": 12},
			{"legs": "air", "hand": Vector2i(24, 14), "sword_a": -10.0, "sword_len": 15, "arc": true, "glow": true},
			{"legs": "air", "hand": Vector2i(22, 18), "sword_a": 20.0, "sword_len": 12, "glow": true},
		]},
		"heavy_charge": {"frames": 2, "poses": [
			{"hand": Vector2i(15, 4), "sword_a": -85.0, "sword_len": 12, "glow": true},
			{"hand": Vector2i(15, 5), "sword_a": -80.0, "sword_len": 12, "glow": true, "aura": true},
		]},
		"heavy_release": {"frames": 3, "poses": [
			{"hand": Vector2i(17, 6), "sword_a": -60.0, "sword_len": 13, "lean": -1, "glow": true},
			{"hand": Vector2i(22, 20), "sword_a": 30.0, "sword_len": 16, "arc": true, "lean": 1, "glow": true},
			{"hand": Vector2i(13, 23), "sword_a": 110.0, "sword_len": 11},
		]},
		"block": {"frames": 1, "poses": [{"crouch": 1, "hand": Vector2i(21, 12), "sword_a": -90.0, "sword_len": 12}]},
		"parry": {"frames": 2, "poses": [
			{"hand": Vector2i(20, 11), "sword_a": -90.0, "sword_len": 12, "glow": true, "aura": true},
			{"hand": Vector2i(24, 17), "sword_a": -20.0, "sword_len": 12, "glow": true},
		]},
		"dash": {"frames": 4, "poses": [
			{"lean": 2, "legs": "trail", "hand": Vector2i(11, 15), "sword_a": 160.0, "sword_len": 10},
			{"lean": 3, "legs": "trail", "hand": Vector2i(10, 16), "sword_a": 165.0, "sword_len": 10},
			{"lean": 3, "legs": "trail", "hand": Vector2i(10, 16), "sword_a": 165.0, "sword_len": 10},
			{"lean": 2, "legs": "spread", "hand": Vector2i(12, 17), "sword_a": 120.0, "sword_len": 10},
		]},
		"hurt": {"frames": 2, "poses": [
			{"lean": -2, "crouch": 1, "hand": Vector2i(12, 14), "sword_a": -140.0},
			{"lean": -3, "crouch": 2, "hand": Vector2i(11, 16), "sword_a": -150.0},
		]},
		"death": {"frames": 6, "poses": [
			{"lean": -2, "crouch": 2, "hand": Vector2i(10, 16), "sword_a": -160.0},
			{"type": "kneel", "hand": Vector2i(9, 14), "sword_a": -170.0},
			{"type": "kneel", "crouch": 2, "hand": Vector2i(9, 16), "sword_a": -175.0},
			{"type": "lie"},
			{"type": "lie"},
			{"type": "lie"},
		]},
	}


func humanoid_palette(over: Dictionary) -> Dictionary:
	var pal := {
		"robe": ROBE, "robe_d": ROBE_D, "trim": TRIM, "skin": SKIN, "hair": HAIR,
		"leg": LEG, "steel": STEEL, "steel_hi": STEEL_HI, "hilt": HILT,
		"has_sword": true, "hat": false, "dual": false, "orb": false, "pole": false,
	}
	for k in over:
		pal[k] = over[k]
	return pal


# 按武器整体缩放剑长（重剑 ×1.35 / 短刃 ×0.65 / 长戈 ×2.2 长杆）
func weapon_actions(base: Dictionary, scale: float) -> Dictionary:
	var out := {}
	for action in base:
		var info: Dictionary = base[action]
		var poses: Array = []
		for p in info["poses"]:
			var q: Dictionary = p.duplicate()
			if q.has("sword_len"):
				q["sword_len"] = maxi(4, int(round(q.sword_len * scale)))
			poses.append(q)
		out[action] = {"frames": info["frames"], "poses": poses}
	return out


func gen_humanoid_char(char_id: String, pal: Dictionary, actions: Dictionary, out_dir: String) -> void:
	for action in actions:
		var info: Dictionary = actions[action]
		var poses: Array = info["poses"]
		var drawer := func(f: Image, idx: int) -> void:
			var pose: Dictionary = poses[idx]
			if action.begins_with("light_attack"):
				pose = pose.duplicate()
				pose["legs"] = pose.get("legs", "stride")
			if pose.get("type", "normal") == "kneel":
				pose = pose.duplicate()
				pose["legs"] = "kneel"
			humanoid(f, pal, pose)
		sheet(info["frames"], drawer, "%s/%s_%s.png" % [out_dir, char_id, action])


# ---------------- 敌人动作表 ----------------

func attack_poses(kind: String) -> Dictionary:
	match kind:
		"sword_disciple":
			return {"frames": 4, "poses": [
				{"hand": Vector2i(10, 9), "sword_a": -120.0, "sword_len": 12, "crouch": 1},
				{"hand": Vector2i(10, 8), "sword_a": -125.0, "sword_len": 12, "crouch": 1, "glow": true},
				{"hand": Vector2i(22, 18), "sword_a": 25.0, "sword_len": 14, "arc": true, "lean": 1},
				{"hand": Vector2i(18, 22), "sword_a": 60.0, "sword_len": 11},
			]}
		"gu_daoist":
			return {"frames": 4, "poses": [
				{"hand": Vector2i(20, 10), "crouch": 1},
				{"hand": Vector2i(20, 9), "glow": true, "crouch": 1},
				{"hand": Vector2i(24, 15), "lean": 1, "glow": true},
				{"hand": Vector2i(21, 18)},
			]}
		"dual_blade":
			return {"frames": 4, "poses": [
				{"hand": Vector2i(12, 12), "sword_a": -110.0, "sword2_a": -135.0, "crouch": 1},
				{"hand": Vector2i(12, 11), "sword_a": -115.0, "sword2_a": -140.0, "crouch": 1, "glow": true},
				{"hand": Vector2i(23, 16), "sword_a": 15.0, "sword2_a": -25.0, "arc": true, "lean": 1},
				{"hand": Vector2i(19, 20), "sword_a": 55.0, "sword2_a": -60.0},
			]}
		"boss_xuanfeng":  # 居合斩
			return {"frames": 4, "poses": [
				{"crouch": 3, "hand": Vector2i(8, 16), "sword_a": -170.0, "sword_len": 14},
				{"crouch": 3, "hand": Vector2i(8, 16), "sword_a": -172.0, "sword_len": 14, "glow": true, "aura": true},
				{"hand": Vector2i(25, 15), "sword_a": 5.0, "sword_len": 17, "arc": true, "lean": 1, "glow": true},
				{"hand": Vector2i(19, 21), "sword_a": 55.0, "sword_len": 13},
			]}
	return {}


func generic_humanoid_actions(kind: String, idle_hand: Vector2i, idle_sword_a: float) -> Dictionary:
	var actions := {}
	actions["idle"] = {"frames": 4, "poses": [
		{"hand": idle_hand, "sword_a": idle_sword_a}, {"hand": idle_hand, "sword_a": idle_sword_a, "crouch": 1},
		{"hand": idle_hand, "sword_a": idle_sword_a, "crouch": 1}, {"hand": idle_hand, "sword_a": idle_sword_a},
	]}
	var walk_poses := []
	for k in 6:
		walk_poses.append({"legs": "stride", "leg_phase": k / 6.0, "hand": idle_hand, "sword_a": idle_sword_a})
	actions["walk"] = {"frames": 6, "poses": walk_poses}
	actions["attack"] = attack_poses(kind)
	actions["hurt"] = {"frames": 2, "poses": [
		{"lean": -2, "crouch": 1, "hand": Vector2i(12, 14), "sword_a": -140.0},
		{"lean": -3, "crouch": 2, "hand": Vector2i(11, 16), "sword_a": -150.0},
	]}
	# 浮空（被上挑/挑飞）：空中瘫软，双臂张开，武器垂落
	actions["launched"] = {"frames": 2, "poses": [
		{"legs": "air", "crouch": 2, "lean": -1, "hand": Vector2i(13, 8), "sword_a": -160.0, "sword_len": 10},
		{"legs": "air", "crouch": 3, "lean": 1, "hand": Vector2i(20, 7), "sword_a": -20.0, "sword_len": 10},
	]}
	# 眩晕：膝地摇晃，武器脱手下垂
	actions["stunned"] = {"frames": 2, "poses": [
		{"legs": "kneel", "crouch": 3, "lean": 2, "hand": Vector2i(21, 18), "sword_a": 90.0, "sword_len": 9},
		{"legs": "kneel", "crouch": 3, "lean": -2, "hand": Vector2i(12, 18), "sword_a": 100.0, "sword_len": 9},
	]}
	actions["death"] = {"frames": 6, "poses": [
		{"lean": -2, "crouch": 2, "hand": Vector2i(10, 16), "sword_a": -160.0},
		{"type": "kneel", "hand": Vector2i(9, 14), "sword_a": -170.0},
		{"type": "kneel", "crouch": 2, "hand": Vector2i(9, 16), "sword_a": -175.0},
		{"type": "lie"}, {"type": "lie"}, {"type": "lie"},
	]}
	return actions


func gen_beast(out_dir: String) -> void:
	var pal := {"body": Color(0.38, 0.26, 0.23), "dark": Color(0.27, 0.18, 0.16), "eye": Color(1.0, 0.35, 0.28)}
	var actions := {
		"idle": [
			{"bob": 0}, {"bob": 1}, {"bob": 1}, {"bob": 0},
		],
		"walk": [
			{"bob": 0, "leg_phase": 0.1}, {"bob": 1, "leg_phase": 0.3}, {"bob": 0, "leg_phase": 0.5},
			{"bob": 1, "leg_phase": 0.7}, {"bob": 0, "leg_phase": 0.9}, {"bob": 1, "leg_phase": 1.0},
		],
		"attack": [
			{"crouch_b": 1, "mouth": false},
			{"crouch_b": 2, "mouth": false, "glow": true},
			{"stretch": true},
			{"bob": 1, "mouth": false},
		],
		"hurt": [
			{"shift": -2, "crouch_b": 1}, {"shift": -3, "crouch_b": 2},
		],
		"launched": [
			{"stretch": true, "shift": -1},
			{"stretch": true, "shift": 2},
		],
		"stunned": [
			{"crouch_b": 2, "shift": 1},
			{"crouch_b": 2, "shift": -2},
		],
		"death": [
			{"crouch_b": 2}, {"shift": -1, "crouch_b": 2},
			{"lying": true}, {"lying": true}, {"lying": true}, {"lying": true},
		],
	}
	for action in actions:
		var poses: Array = actions[action]
		var drawer := func(f: Image, idx: int) -> void:
			beast(f, pal, poses[idx])
		sheet(poses.size(), drawer, "%s/enemy_shan_xiao_%s.png" % [out_dir, action])


# ---------------- 主入口 ----------------

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var dirs := [
		OUT + "/Characters", OUT + "/Environments/Tiles", OUT + "/Effects",
		OUT + "/UI", OUT + "/Icons", "res://tools",
	]
	for d in dirs:
		DirAccess.make_dir_recursive_absolute(d)

	# --- 主角（四武器各一套精灵表，共享动作集合） ---
	print("[主角精灵表 ×4 武器]")
	var base_actions := player_poses()
	var weapon_defs := [
		["changjian", {}, 1.0],
		["zhongjian", {"steel": Color(0.66, 0.70, 0.72), "steel_hi": Color(0.85, 0.88, 0.90),
			"trim": Color(0.62, 0.58, 0.42), "hilt": Color(0.22, 0.18, 0.15)}, 1.35],
		["duanren", {"steel": Color(0.82, 0.88, 0.90), "robe": Color(0.30, 0.33, 0.36),
			"robe_d": Color(0.19, 0.21, 0.23), "trim": Color(0.55, 0.85, 0.75)}, 0.65],
		["changge", {"steel": Color(0.75, 0.80, 0.80), "hilt": WOOD, "pole": true}, 2.2],
	]
	for wd in weapon_defs:
		var wid: String = wd[0]
		var pal := humanoid_palette(wd[1])
		gen_humanoid_char("player_" + wid, pal, weapon_actions(base_actions, wd[2]), OUT + "/Characters")

	# --- 人形敌人 ---
	print("[敌人精灵表]")
	var disciples := generic_humanoid_actions("sword_disciple", Vector2i(20, 20), 72.0)
	disciples["attack"] = attack_poses("sword_disciple")
	gen_humanoid_char("enemy_sword_disciple",
		humanoid_palette({"robe": Color(0.30, 0.38, 0.43), "robe_d": Color(0.20, 0.25, 0.28), "trim": Color(0.55, 0.63, 0.67)}),
		disciples, OUT + "/Characters")

	var daoist_actions := generic_humanoid_actions("gu_daoist", Vector2i(21, 17), 72.0)
	for p in daoist_actions.values():
		for q in p["poses"]:
			q["orb"] = true
	gen_humanoid_char("enemy_gu_daoist",
		humanoid_palette({"robe": Color(0.26, 0.36, 0.29), "robe_d": Color(0.17, 0.24, 0.19),
			"trim": Color(0.59, 0.78, 0.62), "orb_c": Color(0.45, 0.85, 0.45), "has_sword": false}),
		daoist_actions, OUT + "/Characters")

	var dual_actions := generic_humanoid_actions("dual_blade", Vector2i(20, 20), 72.0)
	dual_actions["attack"] = attack_poses("dual_blade")
	for p in dual_actions.values():
		for q in p["poses"]:
			q["dual"] = true
			q["sword2_a"] = q.get("sword2_a", -140.0)
			q["sword2_len"] = 10
	gen_humanoid_char("enemy_dual_blade",
		humanoid_palette({"robe": Color(0.42, 0.24, 0.24), "robe_d": Color(0.28, 0.15, 0.15),
			"trim": Color(0.78, 0.47, 0.39), "dual": true}),
		dual_actions, OUT + "/Characters")

	var boss_actions := generic_humanoid_actions("boss_xuanfeng", Vector2i(21, 20), 70.0)
	boss_actions["attack"] = attack_poses("boss_xuanfeng")
	var boss_pal := humanoid_palette({
		"robe": Color(0.66, 0.69, 0.70), "robe_d": Color(0.45, 0.49, 0.50),
		"trim": TRIM, "hat": true, "hat_c": Color(0.55, 0.47, 0.37),
	})
	for p in boss_actions.values():
		for q in p["poses"]:
			q["sword_len"] = q.get("sword_len", 13)
	gen_humanoid_char("boss_xuanfeng", boss_pal, boss_actions, OUT + "/Characters")

	# 第二层 BOSS：碧毒尊者（换皮：毒绿配色，复用玄风剑主动作骨架）
	var boss2_actions := generic_humanoid_actions("boss_bilv", Vector2i(21, 20), 70.0)
	boss2_actions["attack"] = attack_poses("boss_xuanfeng")
	for p in boss2_actions.values():
		for q in p["poses"]:
			q["sword_len"] = q.get("sword_len", 13)
	gen_humanoid_char("boss_bilv", humanoid_palette({
		"robe": Color(0.30, 0.46, 0.34), "robe_d": Color(0.18, 0.30, 0.22),
		"trim": Color(0.56, 0.92, 0.55), "hat": true, "hat_c": Color(0.26, 0.38, 0.28),
		"steel": Color(0.78, 0.88, 0.80),
	}), boss2_actions, OUT + "/Characters")

	# 第三层 BOSS：赤霄魔君（换皮：赤金配色，复用玄风剑主动作骨架）
	var boss3_actions := generic_humanoid_actions("boss_chixiao", Vector2i(21, 20), 70.0)
	boss3_actions["attack"] = attack_poses("boss_xuanfeng")
	for p in boss3_actions.values():
		for q in p["poses"]:
			q["sword_len"] = q.get("sword_len", 13)
	gen_humanoid_char("boss_chixiao", humanoid_palette({
		"robe": Color(0.58, 0.28, 0.24), "robe_d": Color(0.38, 0.15, 0.14),
		"trim": Color(0.95, 0.62, 0.30), "hat": true, "hat_c": Color(0.45, 0.30, 0.22),
		"steel": Color(0.86, 0.80, 0.72),
	}), boss3_actions, OUT + "/Characters")

	# --- 山魈（兽形）---
	print("[山魈精灵表]")
	gen_beast(OUT + "/Characters")

	# --- 瓦片 ---
	print("[瓦片集]")
	var t := img(16, 16)
	rectf(t, 0, 0, 16, 16, STONE)
	rectf(t, 0, 0, 16, 4, MOSS)
	for k in 14:
		px(t, 2 + int(rng(k) * 12.0), 6 + int(rng(k + 30) * 8.0), STONE_D)
	hline(t, 0, 15, 5, Color(0.31, 0.36, 0.36))
	hline(t, 0, 15, 15, STONE_D)
	save_png(t, OUT + "/Environments/Tiles/tile_ground.png")

	var w := img(16, 16)
	rectf(w, 0, 0, 16, 16, Color(0.27, 0.31, 0.31))
	rectf(w, 0, 0, 16, 1, Color(0.37, 0.42, 0.42))
	vline(w, 0, 15, 3, Color(0.22, 0.26, 0.26))
	vline(w, 0, 15, 8, Color(0.23, 0.27, 0.27))
	vline(w, 0, 15, 13, Color(0.22, 0.26, 0.26))
	save_png(w, OUT + "/Environments/Tiles/tile_wall.png")

	var pf := img(16, 16)
	rectf(pf, 0, 2, 16, 6, WOOD)
	rectf(pf, 0, 2, 16, 1, MOSS)
	hline(pf, 0, 15, 8, Color(0.33, 0.27, 0.22))
	rectf(pf, 0, 9, 16, 3, Color(0.23, 0.19, 0.17))
	vline(pf, 2, 7, 5, Color(0.35, 0.29, 0.24))
	vline(pf, 2, 7, 11, Color(0.35, 0.29, 0.24))
	save_png(pf, OUT + "/Environments/Tiles/tile_platform.png")

	# --- 装饰与背景 ---
	print("[装饰/背景]")
	var pine := img(40, 56)
	rectf(pine, 18, 42, 4, 14, WOOD)
	for layer in 4:
		var top := 2 + layer * 11
		var half := 5 + layer * 4
		for k in 10:
			var row_w := int(float(half) * float(k + 1) / 10.0)
			hline(pine, 20 - row_w, 20 + row_w, top + k, PINE if layer < 3 else Color(0.27, 0.44, 0.38))
	save_png(pine, OUT + "/Environments/deco_pine.png")

	var stele := img(16, 28)
	rectf(stele, 3, 3, 10, 24, Color(0.44, 0.47, 0.47))
	rectf(stele, 4, 2, 8, 2, Color(0.44, 0.47, 0.47))
	rectf(stele, 3, 3, 1, 24, Color(0.52, 0.55, 0.55))
	for row in 3:
		rectf(stele, 5, 8 + row * 5, 6, 2, Color(0.33, 0.36, 0.36))
	rectf(stele, 3, 24, 10, 3, MOSS)
	save_png(stele, OUT + "/Environments/deco_stele.png")

	var mist := img(64, 20)
	for k in 5:
		var cx := 6 + k * 12
		var cy := 6 + int(rng(k) * 6.0)
		disc(mist, cx, cy, 5 + int(rng(k + 9) * 3.0), MIST)
	save_png(mist, OUT + "/Environments/deco_mist.png")

	var mtn := img(320, 140)
	for x in 320:
		var h1 := 50 + 36 * sin(x * 0.021) + 22 * sin(x * 0.073 + 1.7) + 10 * sin(x * 0.031 + 0.5)
		for y in range(int(140 - h1), 140):
			px(mtn, x, y, MOUNT)
		var h2 := 26 + 26 * sin(x * 0.052 + 4.0) + 14 * sin(x * 0.11 + 2.2)
		for y in range(int(140 - h2), 140):
			px(mtn, x, y, MOUNT_D)
	save_png(mtn, OUT + "/Environments/bg_mountains.png")

	var clouds := img(256, 64)
	for k in 10:
		var cx := int(rng(k) * 246.0)
		var cy := 8 + int(rng(k + 40) * 44.0)
		var r := 6 + int(rng(k + 80) * 10.0)
		disc(clouds, cx, cy, r, Color(0.8, 0.86, 0.86, 0.18))
	save_png(clouds, OUT + "/Environments/bg_clouds.png")

	var pines_far := img(256, 100)
	for k in 9:
		var cx := 8 + k * 28 + int(rng(k) * 8.0)
		var base := 100 - int(rng(k + 20) * 14.0)
		var ph := 34 + int(rng(k + 50) * 18.0)
		for y in ph:
			var row_w := int(float(ph - y) * 0.22)
			hline(pines_far, cx - row_w, cx + row_w, base - ph + y, Color(0.33, 0.42, 0.40, 0.55))
	save_png(pines_far, OUT + "/Environments/bg_pines_far.png")

	# --- 特效 ---
	print("[特效]")
	var slash := img(24, 24)
	for s in 12:
		var a := deg_to_rad(-55.0 + s * 11.0)
		px(slash, 8 + int(round(cos(a) * 10.0)), 12 + int(round(sin(a) * 10.0)), WHITE)
		px(slash, 8 + int(round(cos(a) * 11.0)), 12 + int(round(sin(a) * 11.0)), GLOW)
	save_png(slash, OUT + "/Effects/fx_slash.png")

	var qi := img(16, 8)
	for x in 16:
		var hh := int(maxf(1.0, 4.0 * sin(PI * float(x) / 15.0)))
		for y in range(4 - hh, 4 + hh):
			px(qi, x, y, GLOW if y == 4 - hh or y == 4 + hh - 1 else Color(0.65, 0.9, 0.85))
	save_png(qi, OUT + "/Effects/fx_qi.png")

	var parry := img(32, 32)
	for k in 8:
		var a := TAU * k / 8.0
		line(parry, Vector2i(16, 16), Vector2i(16 + int(cos(a) * 14.0), 16 + int(sin(a) * 14.0)), WHITE if k % 2 == 0 else GLOW)
	ring(parry, 16, 16, 8, GLOW)
	save_png(parry, OUT + "/Effects/fx_parry.png")

	var spark := img(8, 8)
	hline(spark, 3, 4, 0, WHITE)
	hline(spark, 3, 4, 7, WHITE)
	vline(spark, 0, 7, 3, WHITE)
	vline(spark, 0, 7, 4, WHITE)
	px(spark, 1, 1, GLOW); px(spark, 6, 1, GLOW); px(spark, 1, 6, GLOW); px(spark, 6, 6, GLOW)
	save_png(spark, OUT + "/Effects/fx_spark.png")

	var shock := img(48, 48)
	ring(shock, 24, 24, 20, GLOW)
	ring(shock, 24, 24, 18, Color(0.8, 0.95, 0.92, 0.6))
	save_png(shock, OUT + "/Effects/fx_shock.png")

	var glow_fx := img(12, 12)
	disc(glow_fx, 6, 6, 4, Color(0.59, 0.95, 0.86, 0.5))
	disc(glow_fx, 6, 6, 2, WHITE)
	save_png(glow_fx, OUT + "/Effects/fx_charge.png")

	var orb := img(8, 8)
	disc(orb, 4, 4, 3, Color(0.45, 0.85, 0.45))
	px(orb, 3, 3, WHITE)
	save_png(orb, OUT + "/Effects/fx_orb.png")

	var fly_sword := img(16, 16)
	line(fly_sword, Vector2i(3, 13), Vector2i(13, 3), STEEL, 2)
	px(fly_sword, 12, 2, STEEL_HI)
	line(fly_sword, Vector2i(3, 13), Vector2i(5, 15), HILT, 2)
	px(fly_sword, 5, 11, HILT); px(fly_sword, 6, 12, HILT)
	save_png(fly_sword, OUT + "/Effects/fx_fly_sword.png")

	var portal_fx := img(16, 24)
	ring(portal_fx, 8, 12, 6, TRIM)
	ring(portal_fx, 8, 12, 4, Color(0.5, 0.85, 0.8, 0.6))
	disc(portal_fx, 8, 12, 3, Color(0.2, 0.3, 0.32, 0.8))
	save_png(portal_fx, OUT + "/Effects/fx_portal.png")

	# 眩晕螺旋（头顶）
	var stun_fx := img(16, 16)
	for s in 18:
		var a := TAU * s / 18.0
		var r := 1.0 + 5.0 * s / 18.0
		px(stun_fx, 8 + int(round(cos(a + r * 0.5) * r)), 5 + int(round(sin(a + r * 0.5) * r * 0.6)), Color(0.95, 0.85, 0.35))
		px(stun_fx, 8 + int(round(cos(a + r * 0.5) * (r - 1.0))), 5 + int(round(sin(a + r * 0.5) * (r - 1.0) * 0.6)), Color(0.8, 0.72, 0.3, 0.6))
	save_png(stun_fx, OUT + "/Effects/fx_stun.png")

	# --- 商人 NPC ---
	print("[NPC]")
	var merchant_pal := humanoid_palette({
		"robe": Color(0.5, 0.42, 0.33), "robe_d": Color(0.33, 0.27, 0.2),
		"trim": Color(0.72, 0.58, 0.4), "hat": true, "hat_c": Color(0.62, 0.5, 0.35),
		"has_sword": false,
	})
	var m_sheet := img(64, 32)
	for f in 2:
		var frame_img := img(32, 32)
		humanoid(frame_img, merchant_pal, {"crouch": f, "hand": Vector2i(22, 18)})
		m_sheet.blit_rect(frame_img, Rect2i(0, 0, 32, 32), Vector2i(f * 32, 0))
	save_png(m_sheet, OUT + "/Characters/npc_merchant.png")

	# --- 图标 ---
	print("[图标]")
	var pearl := img(16, 16)
	disc(pearl, 8, 8, 6, Color(0.36, 0.62, 0.6))
	disc(pearl, 8, 8, 4, Color(0.55, 0.85, 0.8))
	px(pearl, 6, 6, WHITE); px(pearl, 7, 5, WHITE)
	ring(pearl, 8, 8, 6, Color(0.28, 0.5, 0.5))
	save_png(pearl, OUT + "/Icons/icon_gold.png")

	# 流派图标
	var ic_swift := img(16, 16)
	line(ic_swift, Vector2i(3, 13), Vector2i(13, 3), TRIM, 2)
	px(ic_swift, 12, 2, WHITE)
	save_png(ic_swift, OUT + "/Icons/icon_swift.png")

	var ic_heavy := img(16, 16)
	rectf(ic_heavy, 4, 4, 8, 8, Color(0.5, 0.55, 0.58))
	rectf(ic_heavy, 4, 4, 8, 2, TRIM)
	save_png(ic_heavy, OUT + "/Icons/icon_heavy.png")

	var ic_guard := img(16, 16)
	line(ic_guard, Vector2i(8, 1), Vector2i(3, 4), TRIM, 1)
	line(ic_guard, Vector2i(8, 1), Vector2i(13, 4), TRIM, 1)
	line(ic_guard, Vector2i(3, 4), Vector2i(8, 14), TRIM, 1)
	line(ic_guard, Vector2i(13, 4), Vector2i(8, 14), TRIM, 1)
	hline(ic_guard, 5, 11, 6, Color(0.8, 0.95, 0.92))
	save_png(ic_guard, OUT + "/Icons/icon_guard.png")

	var ic_mystic := img(16, 16)
	for s in 20:
		var a := TAU * s / 20.0
		var r := 2.0 + 5.0 * s / 20.0
		px(ic_mystic, 8 + int(cos(a) * r), 8 + int(sin(a) * r), TRIM)
	save_png(ic_mystic, OUT + "/Icons/icon_mystic.png")

	# 招式图标（解锁类词条：卷轴）
	var ic_unlock := img(16, 16)
	rectf(ic_unlock, 3, 4, 10, 9, Color(0.72, 0.64, 0.44))
	rectf(ic_unlock, 4, 5, 8, 7, Color(0.55, 0.48, 0.32))
	hline(ic_unlock, 5, 10, 8, Color(0.9, 0.85, 0.7))
	hline(ic_unlock, 5, 10, 10, Color(0.9, 0.85, 0.7))
	rectf(ic_unlock, 5, 2, 6, 2, Color(0.55, 0.48, 0.32))
	save_png(ic_unlock, OUT + "/Icons/icon_unlock.png")

	# 武器图标（斜置 45°）
	var icon_defs := [
		["changjian", 1.0, false], ["zhongjian", 1.4, false],
		["duanren", 0.7, false], ["changge", 2.0, true],
	]
	var a45 := deg_to_rad(-45.0)
	var d45 := Vector2(cos(a45), sin(a45))
	for wd in icon_defs:
		var ic := img(16, 16)
		var hd := Vector2i(3, 13)
		var ln: int = int(11.0 * wd[1])
		var tp := hd + Vector2i((d45 * ln).round())
		if wd[2]:
			var sh := hd + Vector2i((d45 * ln * 0.65).round())
			line(ic, hd, sh, WOOD, 1)
			line(ic, sh, tp, STEEL, 1)
		else:
			line(ic, hd, tp, STEEL, 1)
		px(ic, tp.x, tp.y, STEEL_HI)
		px(ic, hd.x, hd.y, HILT)
		save_png(ic, "%s/Icons/icon_weapon_%s.png" % [OUT, wd[0]])

	var pill := img(16, 16)
	disc(pill, 8, 8, 5, Color(0.8, 0.3, 0.28))
	hline(pill, 4, 12, 8, Color(0.6, 0.2, 0.2))
	px(pill, 6, 6, WHITE)
	save_png(pill, OUT + "/Icons/icon_pill.png")

	# 血瓶（R 键使用，休息点补满）
	var flask := img(16, 16)
	rectf(flask, 6, 2, 4, 2, Color(0.5, 0.36, 0.28))
	rectf(flask, 6, 4, 4, 2, Color(0.62, 0.68, 0.68))
	rectf(flask, 4, 6, 8, 8, Color(0.7, 0.2, 0.18))
	rectf(flask, 5, 7, 6, 2, Color(0.88, 0.32, 0.28))
	px(flask, 6, 8, WHITE)
	px(flask, 5, 12, Color(0.5, 0.14, 0.14))
	save_png(flask, OUT + "/Icons/icon_flask.png")

	var sachet := img(16, 16)
	rectf(sachet, 4, 5, 8, 9, Color(0.28, 0.45, 0.62))
	rectf(sachet, 6, 3, 4, 3, Color(0.5, 0.36, 0.28))
	px(sachet, 7, 7, WHITE); px(sachet, 8, 9, WHITE)
	save_png(sachet, OUT + "/Icons/icon_sachet.png")

	var talis := img(16, 16)
	rectf(talis, 5, 2, 6, 12, Color(0.82, 0.76, 0.5))
	rectf(talis, 7, 5, 2, 6, Color(0.75, 0.25, 0.22))
	rectf(talis, 4, 13, 8, 2, Color(0.6, 0.55, 0.4))
	save_png(talis, OUT + "/Icons/icon_talisman.png")

	# --- UI 面板（九宫格）---
	print("[UI]")
	var panel := img(32, 32)
	rectf(panel, 0, 0, 32, 32, Color(0.17, 0.21, 0.22, 0.92))
	rectf(panel, 2, 2, 28, 28, Color(0.23, 0.29, 0.29, 0.92))
	for k in 32:
		px(panel, k, 0, Color(0.38, 0.71, 0.66, 0.6))
		px(panel, k, 31, Color(0.38, 0.71, 0.66, 0.6))
		px(panel, 0, k, Color(0.38, 0.71, 0.66, 0.6))
		px(panel, 31, k, Color(0.38, 0.71, 0.66, 0.6))
	save_png(panel, OUT + "/UI/panel.png")

	var btn := img(24, 12)
	rectf(btn, 0, 0, 24, 12, Color(0.24, 0.30, 0.31, 0.95))
	hline(btn, 0, 23, 0, Color(0.38, 0.71, 0.66, 0.7))
	hline(btn, 0, 23, 11, Color(0.15, 0.19, 0.19))
	save_png(btn, OUT + "/UI/button.png")

	print("美术生成完成，耗时 %d ms" % (Time.get_ticks_msec() - t0))
	quit()
