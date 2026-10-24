class_name WeaponPickup
extends Area2D
## A world weapon on a glowing pedestal under a pillar of light you can see from far away.
## As you get close you "sense" it: "I sense something nearby..." then "I smell something good!"

var weapon_id := ""
var _spr: Sprite2D
var _beam: Sprite2D
var _t := 0.0
var _taken := false
var _said_far := false
var _said_near := false
var _light: PointLight2D


func _ready() -> void:
	add_to_group("weapon_pickup")
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 34.0
	shape.shape = c
	add_child(shape)
	var w: Dictionary = WeaponData.ALL[weapon_id]
	var col: Color = w.color
	# Pedestal
	var ped := Sprite2D.new()
	ped.texture = load("res://assets/ninja/props/pillar_broken.png")
	ped.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ped.scale = Vector2(2.6, 1.4)
	ped.offset = Vector2(0, -ped.texture.get_height() * 0.5)
	add_child(ped)
	# Pillar of light
	_beam = Sprite2D.new()
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 256
	tex.fill_from = Vector2(0, 1)
	tex.fill_to = Vector2(0, 0)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, 0.7), Color(col.r, col.g, col.b, 0.0)])
	tex.gradient = g
	_beam.texture = tex
	_beam.scale = Vector2(1.6, 2.6)
	_beam.offset = Vector2(0, -128)
	_beam.position = Vector2(0, -20)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam.material = add
	_beam.z_index = 30
	add_child(_beam)
	# The weapon, floating and turning
	_spr = Sprite2D.new()
	_spr.texture = load(w.sprite)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(4, 4)
	_spr.z_index = 31
	add_child(_spr)
	var ring := AnimatedSprite2D.new()
	ring.sprite_frames = Sheet.fx("circle_white", true)
	ring.play("default")
	ring.scale = Vector2(4, 2.4)
	ring.position = Vector2(0, 2)
	ring.modulate = Color(col.r * 1.8, col.g * 1.8, col.b * 1.8, 0.8)
	ring.z_index = -1
	add_child(ring)
	_light = Sheet.make_light(col, 1.8, 2.6)
	_light.position = Vector2(0, -40)
	add_child(_light)
	var motes := CPUParticles2D.new()
	motes.amount = 30
	motes.lifetime = 1.6
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 26.0
	motes.gravity = Vector2(0, -60)
	motes.initial_velocity_min = 10.0
	motes.initial_velocity_max = 30.0
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 4.0
	motes.color = Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, 0.9)
	motes.position = Vector2(0, -40)
	add_child(motes)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	_spr.position = Vector2(0, -62 + sin(_t * 2.6) * 6.0)
	_spr.rotation = sin(_t * 1.6) * 0.35
	_beam.modulate.a = 0.75 + 0.25 * sin(_t * 4.0)
	_light.energy = 1.6 + 0.4 * sin(_t * 4.0)
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var d := global_position.distance_to(p.global_position)
	# The sensor: you can feel it before you see it.
	if not _said_far and d < 720.0:
		_said_far = true
		_think(p, "I sense something nearby...")
	if not _said_near and d < 300.0:
		_said_near = true
		_think(p, "I smell something good!")


func _think(p: Node2D, text: String) -> void:
	Juice.text_pop(p.global_position + Vector2(0, -24), text, Color(1, 0.95, 0.6), 16, 30.0, 2.2)
	Voice.say(text, "you")


func _on_body(body: Node) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	var w: Dictionary = WeaponData.ALL[weapon_id]
	GameManager.weapon = weapon_id
	GameManager.weapon_world = GameManager.current_scene
	Events.weapon_changed.emit(weapon_id)
	Audio.sfx("sfx_pickup", 0.0, 0.0)
	Audio.sfx("sfx_sword_draw", 0.0, -4.0)
	Juice.fx("circle_spark", global_position + Vector2(0, -40), 4.0, 0.0, Color(2.0, 1.8, 1.0))
	Juice.light_flash(global_position, w.color, 2.4, 3.0, 0.5)
	Juice.zoom_punch(0.06)
	Events.announce.emit(w.name.to_upper())
	Events.subtitle.emit(w.line, Color(1, 0.92, 0.6))
	Voice.say(w.line, "you")
	Events.tutorial_prompt.emit("[F] Use your world weapon.")
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	t.tween_callback(queue_free)
	var level := get_tree().current_scene
	if level and level.has_method("_clear_prompt_later"):
		level._clear_prompt_later(4.0)
