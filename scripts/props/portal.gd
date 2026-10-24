class_name Portal
extends Area2D
## The mirror fragment: a big standing mirror. Step into it to travel to target_scene
## (the screen flips into its own reflection). Hidden until activate().

var target_scene := ""
var final := false
var active := false
var _spr: Sprite2D
var _mat: ShaderMaterial
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
	r.size = Vector2(100, 120)
	shape.shape = r
	shape.position = Vector2(0, -60)
	add_child(shape)
	var col := Color(1.0, 0.3, 0.4) if final else Color(0.5, 0.95, 1.0)
	_aura = AnimatedSprite2D.new()
	_aura.sprite_frames = Sheet.fx("aura", true)
	_aura.play("default")
	_aura.scale = Vector2(7, 4)
	_aura.position = Vector2(0, -6)
	_aura.modulate = Color(col.r * 1.4, col.g * 1.4, col.b * 1.4, 0.7)
	_aura.z_index = -1
	add_child(_aura)
	_spr = Sprite2D.new()
	_spr.texture = load("res://assets/ninja/props/mirror_portal_final.png" if final else "res://assets/ninja/props/mirror_portal.png")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(3, 3)
	_spr.offset = Vector2(0, -_spr.texture.get_height() * 0.5)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://assets/shaders/mirror_shield.gdshader")
	_mat.set_shader_parameter("rim_color", col)
	_spr.material = _mat
	add_child(_spr)
	_light = Sheet.make_light(col, 1.6, 3.4)
	_light.position = Vector2(0, -100)
	add_child(_light)
	_motes = CPUParticles2D.new()
	_motes.amount = 40
	_motes.lifetime = 1.8
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = Vector2(60, 90)
	_motes.position = Vector2(0, -100)
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
	_spr.scale = Vector2(3, 0.1)
	var t := create_tween()
	t.tween_property(_spr, "scale", Vector2(3, 3), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.sfx("sfx_portal", 0.0, -4.0)
	Juice.burst(global_position + Vector2(0, -100), Color(1, 0.4, 0.5) if final else Color(0.6, 0.95, 1.0), 40, 260.0, 3.5)
	Juice.shockwave(global_position + Vector2(0, -100), 0.03, 0.5)


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	_spr.position.y = sin(_t * 2.0) * 4.0
	var g := 1.1 + 0.25 * sin(_t * 3.0)
	_spr.modulate = Color(g, g, g)
	_light.energy = 1.4 + 0.4 * sin(_t * 3.0)
	_mat.set_shader_parameter("ready", 0.5 + 0.5 * sin(_t * 2.0))


func _on_body(body: Node) -> void:
	if _used or not active or not body.is_in_group("player"):
		return
	_used = true
	_mat.set_shader_parameter("flash", 1.0)
	Juice.flash(Color(1, 1, 1, 0.5), 0.3)
	Juice.shockwave(global_position + Vector2(0, -100), 0.06, 0.6)
	GameManager.go_to_scene(target_scene, "mirror")
