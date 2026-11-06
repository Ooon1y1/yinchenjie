# fx.gd — 池化特效播放器：剑气、弹反闪光、轻功残影、击中火花、震波
extends Sprite2D

const FX := {
	"slash": {"path": "res://Assets/Art/Effects/fx_slash.png", "life": 0.15, "grow": 1.3},
	"qi": {"path": "res://Assets/Art/Effects/fx_qi.png", "life": 0.2, "grow": 1.0},
	"parry": {"path": "res://Assets/Art/Effects/fx_parry.png", "life": 0.25, "grow": 1.4},
	"spark": {"path": "res://Assets/Art/Effects/fx_spark.png", "life": 0.12, "grow": 1.2},
	"shock": {"path": "res://Assets/Art/Effects/fx_shock.png", "life": 0.3, "grow": 1.0},
	"charge": {"path": "res://Assets/Art/Effects/fx_charge.png", "life": 0.3, "grow": 1.2},
	"stun": {"path": "res://Assets/Art/Effects/fx_stun.png", "life": 0.45, "grow": 1.0},
}

var _tween: Tween


func _ready() -> void:
	centered = true
	z_index = 20


func play(fx_id: String, pos: Vector2, flip_x: bool, scale_v: float) -> void:
	var info: Dictionary = FX.get(fx_id, {})
	if info.is_empty():
		despawn_self()
		return
	global_position = pos
	texture = load(info["path"])
	hframes = 1
	frame = 0
	flip_h = flip_x
	rotation = 0.0
	if fx_id == "spark":
		rotation = randf_range(-0.8, 0.8)
	if fx_id == "shock":
		scale = Vector2(0.2, 0.2)
	else:
		scale = Vector2.ONE * scale_v
	modulate = Color(1.2, 1.2, 1.2)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, info["life"])
	_tween.parallel().tween_property(self, "scale", scale * info["grow"], info["life"])
	_tween.tween_callback(despawn_self)


# 轻功残影：复制玩家当前帧
func play_ghost(tex: Texture2D, p_hframes: int, p_frame: int, flip_x: bool, pos: Vector2) -> void:
	global_position = pos
	texture = tex
	hframes = p_hframes
	frame = p_frame
	flip_h = flip_x
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color(0.5, 1.0, 0.95, 0.55)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.22)
	_tween.tween_callback(despawn_self)


func despawn_self() -> void:
	if _tween:
		_tween.kill()
	PoolManager.despawn("fx", self)
