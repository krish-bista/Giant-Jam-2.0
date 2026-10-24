class_name Breakable
extends StaticBody2D
## Barrels, crates, pots, crystals... Hit them with anything. Explosive barrels blow up,
## hurt everything nearby (you too) and set off other barrels.

const N := "res://assets/ninja/"
const KINDS := {
	"barrel": {"tex": "props/barrel.png", "hp": 2, "debris": ["fx/particle_wood.png", 6], "sfx": "sfx_break_wood", "heal": 0.12},
	"crate": {"tex": "props/crate.png", "hp": 2, "debris": ["fx/particle_wood.png", 6], "sfx": "sfx_break_wood", "heal": 0.18},
	"crate_b": {"tex": "props/crate_b.png", "hp": 2, "debris": ["fx/particle_wood.png", 6], "sfx": "sfx_break_wood", "heal": 0.18},
	"pot": {"tex": "props/pot.png", "hp": 1, "debris": ["fx/particle_vase.png", 6], "sfx": "sfx_break_pot", "heal": 0.3},
	"vase": {"tex": "props/vase.png", "hp": 1, "debris": ["fx/particle_vase.png", 6], "sfx": "sfx_break_pot", "heal": 0.3},
	"sack": {"tex": "props/sack.png", "hp": 1, "debris": ["fx/particle_grass.png", 6], "sfx": "sfx_break_pot", "heal": 0.2},
	"explosive": {"tex": "props/barrel_explosive.png", "hp": 1, "debris": ["fx/particle_wood.png", 6], "sfx": "sfx_break_wood", "explode": true},
	"crystal": {"tex": "props/gem_block_purple.png", "hp": 2, "debris": ["fx/particle_rockgray.png", 6], "sfx": "sfx_break_crystal", "heal": 0.1,
		"light": Color(0.8, 0.3, 1.0), "tint": Color(1.3, 1.0, 1.5)},
	"crystal_blue": {"tex": "props/gem_block_blue.png", "hp": 2, "debris": ["fx/particle_rockgray.png", 6], "sfx": "sfx_break_crystal", "heal": 0.1,
		"light": Color(0.4, 0.8, 1.0)},
	"holo_crate": {"tex": "props/crate_holo.png", "hp": 1, "debris": ["fx/particle_wood.png", 6], "sfx": "sfx_break_crystal", "tint": Color(0.7, 1.4, 1.6)},
	"holo_barrel": {"tex": "props/barrel_holo.png", "hp": 1, "debris": ["fx/particle_wood.png", 6], "sfx": "sfx_break_crystal", "tint": Color(0.7, 1.4, 1.6)},
}

var kind := "barrel"
var hp := 2
var radius := 18.0
var _spr: Sprite2D
var _broken := false
var _wobble := 0.0


static func make(k: String, pos: Vector2) -> Breakable:
	var b := Breakable.new()
	b.kind = k
	b.position = pos
	return b


func _ready() -> void:
	var c: Dictionary = KINDS[kind]
	hp = c.hp
	add_to_group("breakable")
	add_to_group("damageable")
	collision_layer = 1
	collision_mask = 0
	_spr = Sprite2D.new()
	_spr.texture = load(N + c.tex)
	_spr.scale = Vector2(3, 3)
	_spr.offset = Vector2(0, -_spr.texture.get_height() * 0.5 + 2)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.modulate = c.get("tint", Color.WHITE)
	add_child(_spr)
	var shadow := Sprite2D.new()
	shadow.texture = load(N + "fx/shadow.png")
	shadow.scale = Vector2(2.6, 2.6)
	shadow.position = Vector2(0, 2)
	shadow.modulate = Color(0, 0, 0, 0.35)
	shadow.z_index = -1
	add_child(shadow)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	shape.position = Vector2(0, -6)
	add_child(shape)
	if c.has("light"):
		var l := Sheet.make_light(c.light, 0.9, 0.9)
		l.position = Vector2(0, -16)
		add_child(l)


func _process(delta: float) -> void:
	if _wobble > 0.0:
		_wobble = maxf(0.0, _wobble - delta)
		_spr.rotation = sin(_wobble * 60.0) * 0.18 * (_wobble / 0.25)


func take_damage(_amount: float, source: Node = null) -> void:
	if _broken:
		return
	hp -= 1
	_wobble = 0.25
	_spr.modulate = Color(3, 3, 3)
	var t := create_tween()
	t.tween_property(_spr, "modulate", KINDS[kind].get("tint", Color.WHITE), 0.12)
	Audio.sfx(KINDS[kind].sfx, 0.15, -8.0, 1.3)
	if source is Node2D and is_instance_valid(source) and source.is_in_group("player"):
		Juice.hitstop(0.03)
	if hp <= 0:
		smash(source)


func smash(_source: Node = null) -> void:
	if _broken:
		return
	_broken = true
	var c: Dictionary = KINDS[kind]
	Audio.sfx(c.sfx, 0.1, -2.0)
	Juice.debris(global_position + Vector2(0, -14), N + c.debris[0], c.debris[1], 12, c.get("tint", Color.WHITE))
	Juice.fx("smoke", global_position + Vector2(0, -10), 2.2, 0.0, Color(1, 1, 1, 0.7))
	if c.get("explode", false):
		_explode()
	elif randf() < c.get("heal", 0.0):
		Pickup.spawn_heal(get_parent(), global_position, 10.0)
	queue_free()


func _explode() -> void:
	var pos := global_position + Vector2(0, -12)
	Audio.sfx("sfx_explosion", 0.1, 0.0)
	Juice.fx("explosion", pos, 4.0, 0.0, Color(1.15, 1.05, 0.95))
	Juice.light_flash(pos, Color(1.0, 0.6, 0.3), 1.4, 2.4, 0.4)
	Juice.shake(9.0, 0.6)
	Juice.shockwave(pos, 0.04, 0.4)
	var player := get_tree().get_first_node_in_group("player")
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.global_position.distance_to(pos) < 120.0:
			e.take_damage(40.0, player if player else self)
	if player and player.global_position.distance_to(pos) < 100.0:
		player.take_damage(18.0, self)
	for b in get_tree().get_nodes_in_group("breakable"):
		if b != self and is_instance_valid(b) and b.global_position.distance_to(pos) < 130.0:
			var other: Breakable = b
			get_tree().create_timer(0.12).timeout.connect(func(): if is_instance_valid(other): other.smash(self))
