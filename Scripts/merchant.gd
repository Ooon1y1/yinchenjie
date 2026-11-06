# merchant.gd — 云游商人：靠近按 E 打开商铺
extends Area2D

signal opened

var _idle_t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = EntriesData.mask([EntriesData.LAYER_PLAYER])
	monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 56)
	shape.shape = rect
	shape.position = Vector2(0, -28)
	add_child(shape)

	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.position = Vector2(0, -16)
	sprite.texture = load("res://Assets/Art/Characters/npc_merchant.png")
	sprite.hframes = 2
	add_child(sprite)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_idle_t += delta
	var sprite: Sprite2D = get_node_or_null("Visual")
	if sprite:
		sprite.frame = 1 if int(_idle_t * 2.0) % 2 == 0 else 0


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.set_interactable(self, "按 E 打开商铺")


func _on_body_exited(body: Node2D) -> void:
	# 防御：同帧跨多个交互 Area 时，只有自己仍是当前交互目标才清除
	if body.is_in_group("player") and body.near_interact == self:
		body.set_interactable(null, "")


func interact() -> void:
	opened.emit()
