# portal.gd — 传送门：清怪后激活，按 E 进入下一间
extends Area2D

var active := false
var room: RoomBase = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = EntriesData.mask([EntriesData.LAYER_PLAYER])
	monitoring = true
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 52)
	shape.shape = rect
	shape.position = Vector2(0, -26)
	add_child(shape)

	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.texture = load("res://Assets/Art/Effects/fx_portal.png")
	sprite.scale = Vector2(2.0, 2.0)
	sprite.z_index = 5
	add_child(sprite)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_active(false)


func set_active(v: bool) -> void:
	active = v
	var sprite: Sprite2D = get_node("Visual")
	if sprite:
		sprite.modulate = Color(1.4, 1.6, 1.5, 0.95) if v else Color(0.4, 0.45, 0.45, 0.5)
	_refresh_prompt()


func _prompt_text() -> String:
	return "按 E 进入下一间" if active else "封印未解…（清除房内敌人）"


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.set_interactable(self, _prompt_text())


# 玩家一直站在触发圈内时不会再收到 body_entered；清完怪激活后要主动刷新提示
func _refresh_prompt() -> void:
	var player := GameManager.player
	if is_instance_valid(player) and player.near_interact == self:
		player.set_interactable(self, _prompt_text())


func _on_body_exited(body: Node2D) -> void:
	# 防御：同帧跨多个交互 Area 时，只有自己仍是当前交互目标才清除
	if body.is_in_group("player") and body.near_interact == self:
		body.set_interactable(null, "")


func interact() -> void:
	if active and room:
		AudioManager.play_sfx("portal")
		room.on_portal_interacted()
