class_name Projectile
extends Area2D
## Glowing energy bolt. Enemy bolts hit the player; a perfect block bounces them straight back
## at the shooter (faster, stronger, recolored). Bolts fired by flipped enemies hit other enemies.

var velocity := Vector2.ZERO
var damage := 10.0
var source: Node = null
var hits_enemies := false
var look := "energy_ball"
var tint := Color(1.6, 1.3, 2.0)
var _life := 4.0
var _spr: AnimatedSprite2D
var _light: PointLight2D
var _reflected := false


static func fire(parent: Node, pos: Vector2, dir: Vector2, spd: float, dmg: float, from: Node, at_enemies := false, kind := "energy_ball") -> Projectile:
	var p := Projectile.new()
	p.velocity = dir.normalized() * spd
	p.damage = dmg
	p.source = from
	p.hits_enemies = at_enemies
	p.look = kind
	p.global_position = pos
	parent.add_child(p)
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | (4 if hits_enemies else 2)   # world + (enemy or player)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = Sheet.fx(look, true)
	_spr.scale = Vector2(2.4, 2.4)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.modulate = Color(1.4, 0.7, 1.8) if hits_enemies else tint
	_spr.play("default")
	add_child(_spr)
	_light = Sheet.make_light(Color(0.9, 0.4, 1.0), 0.9, 0.7)
	add_child(_light)
	z_index = 5
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _reflect() -> void:
	_reflected = true
	hits_enemies = true
	collision_mask = 1 | 4
	var target: Node2D = source if is_instance_valid(source) and source is Node2D else null
	var dir := (target.global_position - global_position).normalized() if target else -velocity.normalized()
	velocity = dir * velocity.length() * 1.7
	var mult := 2.0 if GameManager.has_flag("double_reflect") else 1.0
	damage *= GameManager.stats.reflect_power * mult
	_life = 3.0
	_spr.modulate = Color(1.2, 2.2, 2.6)
	_light.color = Color(0.4, 1.0, 1.0)
	var player := get_tree().get_first_node_in_group("player")
	source = player


func _on_body(body: Node) -> void:
	if body == source and not _reflected:
		return
	if body.is_in_group("player") and not hits_enemies:
		if body.has_method("try_deflect_projectile") and body.try_deflect_projectile(self):
			_reflect()
			return
	if body.has_method("take_damage"):
		if hits_enemies and body.is_in_group("player"):
			return
		if hits_enemies and body.is_in_group("flipped") and not _reflected:
			return
		body.take_damage(damage, source if is_instance_valid(source) else self)
	Juice.fx("spark", global_position, 1.4, 0.0, _spr.modulate)
	queue_free()
