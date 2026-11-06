# gen_audio.gd — 占位音频生成器（无头运行）
# 用法: godot --headless --path D:/game -s res://tools/gen_audio.gd
# 合成 18 个音效 + 3 首五声音阶 BGM 循环（22050 Hz / mono / 16-bit PCM WAV）。
extends SceneTree

const RATE := 22050
const OUT_SFX := "res://Assets/Audio/SFX"
const OUT_BGM := "res://Assets/Audio/BGM"

# 五声音阶（A 商调式，武侠氛围）
const PENT := [220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33]

# ---------------- WAV 写出 ----------------

func write_wav(path: String, samples: PackedFloat32Array, gain := 1.0) -> void:
	var buf := StreamPeerBuffer.new()
	var data_len := samples.size() * 2
	buf.put_data("RIFF".to_ascii_buffer())
	buf.put_u32(36 + data_len)
	buf.put_data("WAVE".to_ascii_buffer())
	buf.put_data("fmt ".to_ascii_buffer())
	buf.put_u32(16)
	buf.put_u16(1)  # PCM
	buf.put_u16(1)  # mono
	buf.put_u32(RATE)
	buf.put_u32(RATE * 2)
	buf.put_u16(2)
	buf.put_u16(16)
	buf.put_data("data".to_ascii_buffer())
	buf.put_u32(data_len)
	var peak := 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	var norm := gain if peak < 0.001 else minf(gain, 0.95) / peak
	for s in samples:
		buf.put_16(int(clampf(s * norm, -1.0, 1.0) * 32767.0))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("无法写出: " + path)
		return
	f.store_buffer(buf.data_array)
	f.close()
	print("  ✓ ", path)


# ---------------- 合成基础件 ----------------

func osc(t: float, kind: String, freq: float) -> float:
	var ph := fmod(freq * t, 1.0)
	match kind:
		"sine": return sin(TAU * ph)
		"square": return 1.0 if ph < 0.5 else -1.0
		"tri": return 2.0 * absf(2.0 * ph - 1.0) - 1.0
		"saw": return 2.0 * ph - 1.0
	return 0.0


func sweep(t: float, f0: float, f1: float, dur: float) -> float:
	# 线性扫频的正弦（积分相位）
	var k := (f1 - f0) / dur
	var phase := f0 * t + 0.5 * k * t * t
	return sin(TAU * phase)


func nz(k: int) -> float:
	# 确定性伪噪声
	return fmod(sin(k * 12.9898 + 78.233) * 43758.5453, 1.0) * 2.0 - 1.0


func env_ar(t: float, attack: float, release: float) -> float:
	if t < attack:
		return t / attack
	return maxf(0.0, 1.0 - (t - attack) / release)


func gen(dur: float, fn: Callable) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for k in n:
		out[k] = fn.call(float(k) / RATE, k)
	return out


func add_note(buf: PackedFloat32Array, start: float, dur: float, freq: float, vol: float, kind := "sine", decay := 2.0) -> void:
	var s0 := int(start * RATE)
	var n := mini(int(dur * RATE), buf.size() - s0)
	for k in n:
		if k < 0:
			continue
		var t := float(k) / RATE
		var e := exp(-t * decay) * minf(1.0, t * 40.0)
		buf[s0 + k] += vol * e * osc(t, kind, freq)


# ---------------- 音效配方 ----------------

func make_sfx() -> Dictionary:
	var d := {}
	# 轻击挥空：噪声簌簌 + 高频下扫
	d["swing_light"] = gen(0.12, func(t, k):
		return nz(k) * 0.3 * env_ar(t, 0.005, 0.11) + 0.18 * sweep(t, 900.0, 300.0, 0.12) * env_ar(t, 0.01, 0.1))
	# 轻击命中：低频砰 + 噪声脆响
	d["hit_light"] = gen(0.14, func(t, k):
		var thump := 0.6 * osc(t, "sine", 180.0 * exp(-t * 18.0)) * exp(-t * 22.0)
		return thump + nz(k) * 0.4 * exp(-t * 60.0))
	# 重击蓄力：低频上升嗡鸣
	d["heavy_charge"] = gen(0.6, func(t, k):
		var f: float = 80.0 + 240.0 * t / 0.6
		return 0.4 * osc(t, "sine", f) * env_ar(t, 0.25, 0.4) * (0.7 + 0.3 * sin(TAU * 8.0 * t)))
	# 重击释放：呼啸 + 低沉
	d["heavy_release"] = gen(0.22, func(t, k):
		return nz(k) * 0.35 * env_ar(t, 0.01, 0.2) + 0.5 * osc(t, "sine", 90.0) * exp(-t * 16.0) + 0.2 * sweep(t, 400.0, 120.0, 0.2))
	# 重击命中：重锤
	d["heavy_hit"] = gen(0.3, func(t, k):
		return 0.8 * osc(t, "sine", 60.0 * exp(-t * 8.0)) * exp(-t * 10.0) + nz(k) * 0.35 * exp(-t * 25.0))
	# 格挡成功：金属叮
	d["block_ok"] = gen(0.12, func(t, k):
		var e := exp(-t * 30.0)
		return (0.5 * osc(t, "sine", 1200.0) + 0.3 * osc(t, "sine", 1800.0) + 0.15 * nz(k)) * e)
	# 格挡破碎
	d["block_break"] = gen(0.28, func(t, k):
		var e := env_ar(t, 0.005, 0.27)
		return (0.4 * sweep(t, 1400.0, 300.0, 0.28) + 0.45 * nz(k) * exp(-t * 14.0)) * e)
	# 完美弹反：亮铃上扬
	d["parry"] = gen(0.4, func(t, k):
		var e := exp(-t * 7.0)
		return (0.4 * sweep(t, 440.0, 1760.0, 0.35) + 0.35 * osc(t, "sine", 1318.0) + 0.2 * osc(t, "sine", 1975.0)) * e)
	# 轻功：风声嗖
	d["dash"] = gen(0.18, func(t, k):
		var band := 0.5 + 0.5 * sin(TAU * (1.0 + t * 12.0))
		return nz(k) * 0.5 * band * env_ar(t, 0.01, 0.17))
	# 玩家受击：闷哼
	d["player_hurt"] = gen(0.2, func(t, k):
		return 0.5 * sweep(t, 170.0, 100.0, 0.2) * exp(-t * 12.0) + nz(k) * 0.2 * exp(-t * 40.0))
	# 玩家死亡：坠落长音
	d["player_death"] = gen(0.7, func(t, k):
		return 0.5 * sweep(t, 400.0, 55.0, 0.7) * env_ar(t, 0.02, 0.6) + nz(k) * 0.15 * exp(-t * 5.0))
	# 敌人死亡：碎裂
	d["enemy_death"] = gen(0.3, func(t, k):
		return nz(k) * 0.45 * exp(-t * 12.0) + 0.4 * osc(t, "sine", 120.0) * exp(-t * 9.0))
	# 毒弹发射：气泡咕噜
	d["poison_shot"] = gen(0.25, func(t, k):
		var wob := 300.0 * (1.0 + 0.25 * sin(TAU * 36.0 * t))
		return 0.4 * osc(t, "sine", wob) * env_ar(t, 0.01, 0.24))
	# 剑气：锐利短啸
	d["qi_shot"] = gen(0.16, func(t, k):
		return 0.35 * sweep(t, 950.0, 650.0, 0.16) * env_ar(t, 0.01, 0.15) + nz(k) * 0.12 * exp(-t * 30.0))
	# 传送门：上行琶音
	d["portal"] = gen(0.45, func(t, k):
		var seg := int(t / 0.15)
		var notes := [523.25, 659.25, 783.99, 1046.5]
		var f: float = notes[seg] if seg < 4 else 1046.5
		return 0.4 * osc(t - seg * 0.15, "sine", f) * exp(-(t - seg * 0.15) * 12.0))
	# 购买：铜钱叮当
	d["buy"] = gen(0.18, func(t, k):
		var e := exp(-t * 22.0)
		return (0.5 * osc(t, "sine", 1318.5) + 0.35 * osc(t, "sine", 1760.0) * (1.0 if t < 0.08 else 0.6)) * e)
	# UI 点击
	d["ui_click"] = gen(0.05, func(t, k):
		return 0.5 * osc(t, "square", 2000.0) * env_ar(t, 0.002, 0.05))
	# 词条拾取：和弦涌起
	d["entry_pick"] = gen(0.5, func(t, k):
		var e := env_ar(t, 0.08, 0.42)
		return (0.3 * osc(t, "sine", 523.25) + 0.3 * osc(t, "sine", 659.25) + 0.3 * osc(t, "sine", 783.99) + 0.2 * osc(t, "sine", 1046.5)) * e)
	# 派生技释放：锐利挑斩上扬
	d["derive_release"] = gen(0.16, func(t, k):
		return 0.4 * sweep(t, 500.0, 1200.0, 0.16) * env_ar(t, 0.005, 0.15) + nz(k) * 0.15 * exp(-t * 35.0))
	# 终结技释放：蓄势长啸
	d["finisher_release"] = gen(0.3, func(t, k):
		return 0.45 * sweep(t, 300.0, 900.0, 0.3) * env_ar(t, 0.05, 0.25) + 0.2 * osc(t, "sine", 70.0) * exp(-t * 8.0))
	# 终结技命中：轰然重爆
	d["finisher_hit"] = gen(0.4, func(t, k):
		return 0.85 * osc(t, "sine", 55.0 * exp(-t * 6.0)) * exp(-t * 8.0) + nz(k) * 0.5 * exp(-t * 12.0) + 0.2 * sweep(t, 800.0, 100.0, 0.3))
	# 连击里程碑：升调铃鸣
	d["combo_milestone"] = gen(0.25, func(t, k):
		var e := exp(-t * 9.0)
		return (0.4 * osc(t, "sine", 1046.5) + 0.25 * osc(t, "sine", 1318.5) + 0.15 * osc(t, "sine", 1568.0)) * e)
	# 武器切换：铿锵交鸣
	d["weapon_switch"] = gen(0.15, func(t, k):
		var e := exp(-t * 25.0)
		return (0.45 * osc(t, "sine", 1500.0) + 0.3 * osc(t, "sine", 2200.0) + 0.2 * nz(k)) * e)
	# 挑空浮空：风卷上扬
	d["launch"] = gen(0.22, func(t, k):
		return 0.45 * sweep(t, 250.0, 800.0, 0.22) * env_ar(t, 0.01, 0.2) + nz(k) * 0.2 * exp(-t * 20.0))
	return d


# ---------------- BGM 配方 ----------------

func make_bgm_menu() -> PackedFloat32Array:
	var dur := 16.0
	var buf := PackedFloat32Array()
	buf.resize(int(dur * RATE))
	var chords := [[220.0, 329.63], [174.61, 261.63], [196.0, 293.66], [164.81, 246.94]]
	for bar in 4:
		var start := bar * 4.0
		var ch: Array = chords[bar]
		# 柔和长音铺底
		add_note(buf, start, 4.0, ch[0], 0.16, "sine", 0.35)
		add_note(buf, start, 4.0, ch[1], 0.12, "sine", 0.35)
		add_note(buf, start + 2.0, 2.0, ch[0] * 0.5, 0.10, "sine", 0.3)
		# 慢速五声琶音
		var pat := [4, 2, 3, 1]
		for beat in 4:
			add_note(buf, start + beat * 1.0 + 0.5, 1.2, PENT[pat[beat]] * 2.0, 0.10, "tri", 1.6)
	return buf


func make_bgm_explore() -> PackedFloat32Array:
	var dur := 16.0
	var buf := PackedFloat32Array()
	buf.resize(int(dur * RATE))
	var beat := 0.5  # 120bpm
	var bars := int(dur / (beat * 4.0))
	for bar in bars:
		var start := bar * beat * 4.0
		var roots := [220.0, 174.61, 196.0, 164.81]
		var root: float = roots[bar % 4]
		# 低音
		add_note(buf, start, 1.6, root * 0.5, 0.12, "sine", 1.2)
		add_note(buf, start + 2.0, 1.4, root * 0.5, 0.09, "sine", 1.4)
		# 琶音（古筝感）
		var pat := [2, 4, 3, 5, 2, 3, 4, 1]
		for k in 8:
			add_note(buf, start + float(k) * beat, 0.9, PENT[pat[k]], 0.11, "tri", 3.2)
			if bar % 2 == 1:
				add_note(buf, start + float(k) * beat + 0.25, 0.5, PENT[pat[(k + 3) % 8]] * 2.0, 0.045, "sine", 5.0)
		# 云雾氛围
		add_note(buf, start, 2.2, root, 0.05, "sine", 0.5)
	return buf


func make_bgm_boss() -> PackedFloat32Array:
	var dur := 15.0  # 128bpm × 32 拍
	var buf := PackedFloat32Array()
	buf.resize(int(dur * RATE))
	var beat := 0.46875
	for k in 32:
		var start := float(k) * beat
		# 战鼓底
		add_note(buf, start, 0.3, 55.0, 0.35, "sine", 9.0)
		if k % 2 == 1:
			add_note(buf, start, 0.15, 120.0, 0.12, "sine", 14.0)
		# 紧迫低音（A - E 交替）
		var bass := 110.0 if (k / 4) % 2 == 0 else 82.41
		add_note(buf, start, beat * 0.9, bass, 0.14, "saw", 4.5)
		# 快速高音琶音
		var pat := [5, 6, 7, 6, 5, 4, 5, 6]
		add_note(buf, start, beat * 0.5, PENT[pat[k % 8]] * 2.0, 0.05, "square", 6.0)
		if k % 8 == 7:
			add_note(buf, start, 0.8, 660.0, 0.10, "saw", 3.0)  # 每 8 拍刀光嘶鸣
	return buf


# ---------------- 主入口 ----------------

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(OUT_SFX)
	DirAccess.make_dir_recursive_absolute(OUT_BGM)

	print("[音效]")
	var sfx := make_sfx()
	for key in sfx:
		write_wav("%s/%s.wav" % [OUT_SFX, key], sfx[key], 0.8)

	print("[BGM]")
	write_wav(OUT_BGM + "/bgm_menu.wav", make_bgm_menu(), 0.55)
	write_wav(OUT_BGM + "/bgm_explore.wav", make_bgm_explore(), 0.5)
	write_wav(OUT_BGM + "/bgm_boss.wav", make_bgm_boss(), 0.6)

	print("音频生成完成，耗时 %d ms" % (Time.get_ticks_msec() - t0))
	quit()
