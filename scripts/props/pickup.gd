class_name Pickup
extends Area2D
## Heal orbs and artifacts. Float toward the player when close.

var kind := "heal"
var amount := 15.0
var artifact_id := ""
var _t := 0.0
var _spr: Sprite2D
var _magnet := false


static func spawn_heal(parent: Node, pos: Vector2, heal_amount := 15.0) -> Pickup:
	var p := Pickup.new()
	p.kind = "heal"
	p.amount = heal_amount
	p.global_position = pos
	parent.call_deferred("add_child", p)
	return p


static func spawn_artifact(parent: Node, pos: Vector2, id: String) -> Pickup:
	var p := Pickup.new()
	p.kind = "artifact"
	p.artifact_id = id
	p.global_position = pos
	parent.call_deferred("add_child", p)
	return p


func _ready() -> void:
	add_to_group("pickup")
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 16.0
	shape.shape = c
	add_child(shape)
	_spr = Sprite2D.new()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if kind == "heal":
		_spr.texture = load("res://assets/props/prop_heal_orb.png")
	else:
		_spr.texture = load(ArtifactData.icon_path(artifact_id))
		_spr.scale = Vector2(1.3, 1.3)
	add_child(_spr)
	z_index = 3
	body_entered.connect(_on_body)
	if kind == "artifact":
		Juice.burst(global_position, Color(1, 0.9, 0.4), 16, 140.0)


func _process(delta: float) -> void:
	_t += delta
	_spr.position.y = sin(_t * 4.0) * 3.0
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var d := global_position.distance_to(p.global_position)
	if d < 90.0 or _magnet:
		_magnet = true
		global_position = global_position.move_toward(p.global_position, 360.0 * delta)


func _on_body(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if kind == "heal":
		if body.has_method("heal"):
			body.heal(amount)
	else:
		Audio.sfx("sfx_pickup", 0.05, -2.0)
		GameManager.apply_artifact(artifact_id)
		Juice.flash(Color(1, 0.9, 0.5, 0.18), 0.2)
	Juice.burst(global_position, Color(0.6, 1, 0.7) if kind == "heal" else Color(1, 0.9, 0.4), 12, 120.0)
	queue_free()
