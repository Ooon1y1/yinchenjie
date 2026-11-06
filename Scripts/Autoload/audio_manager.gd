# audio_manager.gd — 音频管理（AutoLoad）：BGM 切换 / 音效播放（策划案第六节音频规范）
# WAV 素材由 tools/gen_audio.gd 生成，首次 --import 后以 AudioStreamWAV 资源加载。
extends Node

const SFX_DIR := "res://Assets/Audio/SFX"
const BGM_DIR := "res://Assets/Audio/BGM"
const SFX_POOL_SIZE := 8

var _sfx: Dictionary = {}          # name -> AudioStreamWAV
var _bgm: Dictionary = {}          # name -> AudioStreamWAV（已设循环）
var _players: Array[AudioStreamPlayer] = []
var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _current_bgm: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_sfx()
	_load_bgm()
	_bgm_a = AudioStreamPlayer.new()
	_bgm_b = AudioStreamPlayer.new()
	_bgm_a.bus = "Master"
	_bgm_b.bus = "Master"
	add_child(_bgm_a)
	add_child(_bgm_b)
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func _load_sfx() -> void:
	var names := ["swing_light", "hit_light", "heavy_charge", "heavy_release", "heavy_hit",
		"block_ok", "block_break", "parry", "dash", "player_hurt", "player_death",
		"enemy_death", "poison_shot", "qi_shot", "portal", "buy", "ui_click", "entry_pick",
		"derive_release", "finisher_release", "finisher_hit", "combo_milestone",
		"weapon_switch", "launch"]
	for n in names:
		var path := "%s/%s.wav" % [SFX_DIR, n]
		if ResourceLoader.exists(path):
			_sfx[n] = load(path)


func _load_bgm() -> void:
	var names := ["bgm_menu", "bgm_explore", "bgm_boss"]
	for n in names:
		var path := "%s/%s.wav" % [BGM_DIR, n]
		if not ResourceLoader.exists(path):
			continue
		var stream: AudioStreamWAV = load(path)
		# 循环首尾无缝（策划案：BGM 循环播放）
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2   # 16-bit mono
		_bgm[n] = stream


# ---- 音效 ----

func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch_var: float = 0.05) -> void:
	if not _sfx.has(sfx_name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _sfx[sfx_name]
			p.volume_db = volume_db
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return
	# 全忙则复用第一个
	var first: AudioStreamPlayer = _players[0]
	first.stream = _sfx[sfx_name]
	first.volume_db = volume_db
	first.play()


# ---- BGM ----

func play_bgm(bgm_name: String, fade: float = 0.5) -> void:
	if bgm_name == _current_bgm:
		return
	if not _bgm.has(bgm_name):
		return
	_current_bgm = bgm_name
	# 交叉淡入淡出
	var from := _bgm_a if _bgm_a.playing else _bgm_b
	var to := _bgm_b if from == _bgm_a else _bgm_a
	to.stream = _bgm[bgm_name]
	to.volume_db = -40.0
	to.play()
	var t := create_tween()
	t.tween_property(from, "volume_db", -40.0, fade)
	t.parallel().tween_property(to, "volume_db", 0.0, fade)
	t.tween_callback(from.stop)


func stop_bgm(fade: float = 0.4) -> void:
	_current_bgm = ""
	var t := create_tween()
	t.tween_property(_bgm_a, "volume_db", -40.0, fade)
	t.parallel().tween_property(_bgm_b, "volume_db", -40.0, fade)
	t.tween_callback(_bgm_a.stop)
	t.tween_callback(_bgm_b.stop)
