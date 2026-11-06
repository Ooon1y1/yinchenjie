# event_shrine.gd — 事件房中的古老石碑：靠近按 E 触发奇遇
extends Area2D

signal opened

var _triggered := false
var _idle_t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = EntriesData.mask([EntriesData.LAYER_PLAYER])
	monitoring = true
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(52, 64)
	shape.shape = rect
	shape.position = Vector2(0, -32)
	add_child(shape)

	var glow := Sprite2D.new()
	glow.name = "Glow"
	glow.texture = load("res://Assets/Art/Effects/fx_orb.png")
	glow.position = Vector2(0, -30)
	glow.scale = Vector2(2.2, 2.2)
	glow.modulate = Color(0.55, 0.85, 0.95, 0.35)
	glow.z_index = -1
	add_child(glow)

	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.texture = load("res://Assets/Art/Environments/deco_stele.png")
	sprite.position = Vector2(0, -20)
	sprite.scale = Vector2(1.6, 1.6)
	sprite.modulate = Color(0.85, 1.05, 1.1)
	add_child(sprite)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_idle_t += delta
	var glow: Sprite2D = get_node_or_null("Glow")
	if glow:
		glow.modulate.a = 0.25 + 0.15 * sin(_idle_t * 3.0)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.set_interactable(self, _prompt())


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.near_interact == self:
		body.set_interactable(null, "")


func _prompt() -> String:
	return "按 E 探查古碑" if not _triggered else "碑文已阅"


func interact() -> void:
	if _triggered:
		return
	_triggered = true
	opened.emit()
	if is_instance_valid(GameManager.player) and GameManager.player.near_interact == self:
		GameManager.player.set_interactable(self, _prompt())
