class_name Portal
extends Area2D
## Mirror fragment. Step in to travel to target_scene. Hidden until activate().

var target_scene := ""
var final := false
var active := false
var _spr: Sprite2D
var _t := 0.0
var _used := false
var _light: PointLight2D
var _aura: AnimatedSprite2D
var _motes: CPUParticles2D


func _ready() -> void:
	add_to_group("portal")
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(44, 80)
	shape.shape = r
	add_child(shape)
	_spr = Sprite2D.new()
	_spr.texture = load("res://assets/props/prop_portal_final.png" if final else "res://assets/props/prop_portal.png")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(1.4, 1.4)
	add_child(_spr)
	var col := Color(1.0, 0.3, 0.4) if final else Color(0.5, 0.95, 1.0)
	_aura = AnimatedSprite2D.new()
	_aura.sprite_frames = Sheet.fx("aura", true)
	_aura.play("default")
	_aura.scale = Vector2(5, 5)
	_aura.position = Vector2(0, 30)
	_aura.modulate = Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, 0.8)
	_aura.z_index = -1
	add_child(_aura)
	_light = Sheet.make_light(col, 1.6, 3.0)
	add_child(_light)
	_motes = CPUParticles2D.new()
	_motes.amount = 30
	_motes.lifetime = 1.6
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = Vector2(40, 50)
	_motes.direction = Vector2.UP
	_motes.gravity = Vector2(0, -50)
	_motes.initial_velocity_min = 10.0
	_motes.initial_velocity_max = 40.0
	_motes.scale_amount_min = 2.0
	_motes.scale_amount_max = 4.0
	_motes.color = Color(col.r * 1.8, col.g * 1.8, col.b * 1.8, 0.9)
	add_child(_motes)
	visible = active
	monitoring = active
	body_entered.connect(_on_body)


func activate() -> void:
	if active:
		return
	active = true
	visible = true
	set_deferred("monitoring", true)
	_spr.scale = Vector2(0.1, 0.1)
	var t := create_tween()
	t.tween_property(_spr, "scale", Vector2(1.4, 1.4), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.sfx("sfx_portal", 0.0, -4.0)
	Juice.burst(global_position, Color(1, 0.4, 0.5) if final else Color(0.6, 0.95, 1.0), 30, 220.0, 3.5)


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	_spr.position.y = sin(_t * 2.5) * 5.0
	var g := 1.2 + 0.4 * sin(_t * 4.0)
	_spr.modulate = Color(g, g, g)
	_light.energy = 1.4 + 0.4 * sin(_t * 4.0)


func _on_body(body: Node) -> void:
	if _used or not active or not body.is_in_group("player"):
		return
	_used = true
	Audio.sfx("sfx_portal", 0.0, 0.0)
	Juice.flash(Color(1, 1, 1, 0.6), 0.4)
	GameManager.go_to_scene(target_scene)
