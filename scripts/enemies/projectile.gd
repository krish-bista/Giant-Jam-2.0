class_name Projectile
extends Area2D
## Simple bolt. Enemy bolts hit the player (and can be reflected by a perfect block).
## Bolts fired by flipped enemies hit other enemies instead.

const TEX := preload("res://assets/props/fx_bolt.png")

var velocity := Vector2.ZERO
var damage := 10.0
var source: Node = null
var hits_enemies := false
var _life := 3.5


static func fire(parent: Node, pos: Vector2, dir: Vector2, spd: float, dmg: float, from: Node, at_enemies := false) -> Projectile:
	var p := Projectile.new()
	p.velocity = dir.normalized() * spd
	p.damage = dmg
	p.source = from
	p.hits_enemies = at_enemies
	p.global_position = pos
	parent.add_child(p)
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | (4 if hits_enemies else 2)   # world + (enemy or player)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	var spr := Sprite2D.new()
	spr.texture = TEX
	spr.scale = Vector2(2, 2)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if hits_enemies:
		spr.modulate = Color(1.0, 0.5, 1.0)
	add_child(spr)
	rotation = velocity.angle()
	z_index = 5
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body(body: Node) -> void:
	if body == source:
		return
	if body.has_method("take_damage"):
		if hits_enemies and body.is_in_group("player"):
			return
		if hits_enemies and body.is_in_group("flipped"):
			return
		body.take_damage(damage, source if is_instance_valid(source) else self)
	Juice.burst(global_position, Color(1.0, 0.7, 0.4), 6, 100.0, 2.0)
	queue_free()
