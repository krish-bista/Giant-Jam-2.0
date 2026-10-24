class_name Prop
extends StaticBody2D
## Static scenery: trees (sway in the wind), rocks, ruins, statues, lamp posts, crystals...
## The node's origin is the prop's base, so y-sorting puts you in front of / behind it correctly.

const N := "res://assets/ninja/"
static var _sizes := {}

var tex_name := ""
var collide := true
var sway := false
var light_color := Color(0, 0, 0, 0)
var light_energy := 1.0
var light_scale := 1.5
var tint := Color.WHITE
## "solid": furniture seen from above - the collision covers most of the sprite, so you can't
## walk into a bed or a table. "decal": lies flat on the floor (carpets) and is walked over.
var solid := false
var decal := false
var flip := false
var sprite: Sprite2D


static func make(name: String, pos: Vector2, opts := {}) -> Prop:
	var p := Prop.new()
	p.tex_name = name
	p.position = pos
	p.collide = opts.get("collide", true)
	p.sway = opts.get("sway", false)
	p.light_color = opts.get("light", Color(0, 0, 0, 0))
	p.light_energy = opts.get("energy", 1.0)
	p.light_scale = opts.get("light_scale", 1.5)
	p.tint = opts.get("tint", Color.WHITE)
	p.solid = opts.get("solid", false)
	p.decal = opts.get("decal", false)
	p.flip = opts.get("flip", false)
	if p.decal:
		p.collide = false
	return p


func _ready() -> void:
	collision_layer = 1 if collide else 0
	collision_mask = 0
	sprite = Sprite2D.new()
	sprite.texture = load(N + "props/%s.png" % tex_name)
	sprite.scale = Vector2(3, 3)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var h := sprite.texture.get_height()
	var w := sprite.texture.get_width()
	sprite.offset = Vector2(0, -h * 0.5 + 3)
	sprite.modulate = tint
	sprite.flip_h = flip
	if decal:
		z_index = -15
		sprite.offset = Vector2.ZERO
	if sway:
		var m := ShaderMaterial.new()
		m.shader = preload("res://assets/shaders/sway.gdshader")
		m.set_shader_parameter("strength", 1.2 + randf() * 0.8)
		sprite.material = m
	add_child(sprite)
	if collide:
		var shape := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		if solid:
			r.size = Vector2(w * 3 * 0.92, h * 3 * 0.8)
		else:
			r.size = Vector2(w * 3 * 0.7, maxf(18.0, h * 3 * 0.22))
		shape.shape = r
		shape.position = Vector2(0, -r.size.y * 0.5 + 4)
		add_child(shape)
	if light_color.a > 0.0:
		var l := Sheet.make_light(light_color, light_energy, light_scale)
		l.position = Vector2(0, -h * 3 * 0.6)
		add_child(l)


func footprint() -> float:
	var t: Texture2D = load(N + "props/%s.png" % tex_name)
	return t.get_width() * 3 * 0.5
