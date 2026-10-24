class_name Projectile
extends Area2D
## Glowing bolt. Enemy bolts hit the player; a perfect block (or Hypno Reverse) turns them around
## and sends them back at the shooter. Player weapons use the same class: piercing arrows, homing shards.

var velocity := Vector2.ZERO
var damage := 10.0
var source: Node = null
var hits_enemies := false
var look := "energy_ball"
var tex_path := ""          # static sprite instead of an FX animation (arrows)
var tint := Color(1.6, 1.3, 2.0)
var pierce := 0             # extra enemies it can pass through
var homing := 0.0           # turn rate (rad/s) toward the nearest enemy
var _life := 4.0
var _spr: Node2D
var _light: PointLight2D
var _reflected := false
var _hit: Array = []


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


## Player shots: configure before adding to the tree.
static func player_shot(parent: Node, pos: Vector2, dir: Vector2, spd: float, dmg: float, from: Node, opts := {}) -> Projectile:
	var p := Projectile.new()
	p.velocity = dir.normalized() * spd
	p.damage = dmg
	p.source = from
	p.hits_enemies = true
	p.look = opts.get("look", "energy_ball")
	p.tex_path = opts.get("tex", "")
	p.tint = opts.get("tint", Color(1.4, 1.4, 1.4))
	p.pierce = opts.get("pierce", 0)
	p.homing = opts.get("homing", 0.0)
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
	if tex_path != "":
		var s := Sprite2D.new()
		s.texture = load(tex_path)
		s.scale = Vector2(3, 3)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.modulate = tint
		_spr = s
	else:
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Sheet.fx(look, true)
		a.scale = Vector2(2.4, 2.4)
		a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		a.modulate = tint if (hits_enemies or tint != Color(1.6, 1.3, 2.0)) else Color(1.6, 1.3, 2.0)
		if hits_enemies and source and not source.is_in_group("player"):
			a.modulate = Color(1.4, 0.7, 1.8)
		a.play("default")
		_spr = a
	add_child(_spr)
	_light = Sheet.make_light(Color(tint.r, tint.g, tint.b) if hits_enemies else Color(0.9, 0.4, 1.0), 0.9, 0.7)
	add_child(_light)
	z_index = 5
	rotation = velocity.angle()
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	if homing > 0.0:
		var best: Node2D = null
		var best_d := 600.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e in _hit:
				var dd := global_position.distance_to(e.global_position)
				if dd < best_d:
					best_d = dd
					best = e
		if best:
			var want := (best.global_position - global_position).angle()
			var ang := rotate_toward(velocity.angle(), want, homing * delta)
			velocity = Vector2.RIGHT.rotated(ang) * velocity.length()
	position += velocity * delta
	rotation = velocity.angle()
	_life -= delta
	if _life <= 0.0:
		queue_free()


## Turn around and fly back at whoever fired it (perfect block / Hypno Reverse).
func reflect(mult := 1.0) -> void:
	if _reflected:
		return
	_reflected = true
	var shooter := source
	hits_enemies = true
	collision_mask = 1 | 4
	var target: Node2D = shooter if is_instance_valid(shooter) and shooter is Node2D else null
	var dir := (target.global_position - global_position).normalized() if target else -velocity.normalized()
	velocity = dir * velocity.length() * 1.7
	var dbl := 2.0 if GameManager.has_flag("double_reflect") else 1.0
	damage *= GameManager.stats.reflect_power * dbl * mult
	_life = 3.0
	_spr.modulate = Color(1.2, 2.2, 2.6)
	_light.color = Color(0.4, 1.0, 1.0)
	source = get_tree().get_first_node_in_group("player")


func _on_body(body: Node) -> void:
	if body == source and not _reflected:
		return
	if body.is_in_group("player") and not hits_enemies:
		if body.has_method("try_deflect_projectile") and body.try_deflect_projectile(self):
			reflect()
			return
	if body in _hit:
		return
	if body.has_method("take_damage"):
		if hits_enemies and body.is_in_group("player"):
			return
		if hits_enemies and body.is_in_group("flipped") and not _reflected and not (source and source.is_in_group("player")):
			return
		body.take_damage(damage, source if is_instance_valid(source) else self)
		_hit.append(body)
		if pierce > 0 and body.is_in_group("enemies"):
			pierce -= 1
			Juice.fx("spark", global_position, 1.2, 0.0, _spr.modulate)
			return
	Juice.fx("spark", global_position, 1.4, 0.0, _spr.modulate)
	queue_free()
