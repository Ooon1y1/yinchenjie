# pixel_animator.gd — 精灵表帧动画驱动（10 FPS，每动作一张 PNG 横排帧）
class_name PixelAnim
extends RefCounted

const FPS := 10.0
const CHARS_DIR := "res://Assets/Art/Characters"

static var _cache: Dictionary = {}

var sprite: Sprite2D
var char_id: String
var actions: Dictionary = {}   # action -> {"frames": int, "loop": bool}
var current := ""
var time := 0.0
var finished := false


func _init(p_sprite: Sprite2D, p_char: String) -> void:
	sprite = p_sprite
	char_id = p_char


static func tex(p_char: String, action: String) -> Texture2D:
	var path := "%s/%s_%s.png" % [CHARS_DIR, p_char, action]
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


func register(action: String, frames: int, loop: bool) -> void:
	actions[action] = {"frames": frames, "loop": loop}


func play(action: String, restart := false) -> void:
	if action == current and not restart and not finished:
		return
	current = action
	time = 0.0
	finished = false
	var t: Texture2D = tex(char_id, action)
	if t:
		sprite.texture = t
		sprite.hframes = actions.get(action, {}).get("frames", 1)
	sprite.frame = 0


func advance(delta: float, speed_scale := 1.0) -> void:
	var info: Dictionary = actions.get(current, {})
	var frames: int = info.get("frames", 1)
	var loop: bool = info.get("loop", false)
	time += delta * FPS * speed_scale
	var f := int(time)
	if loop:
		sprite.frame = f % frames if frames > 0 else 0
	else:
		if f >= frames:
			f = frames - 1
			finished = true
		sprite.frame = maxi(f, 0)


func progress() -> float:
	var frames: int = actions.get(current, {}).get("frames", 1)
	return clampf(time / maxi(frames, 1), 0.0, 1.0)
