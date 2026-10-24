class_name PlayerRig
extends Node2D
## Everything you SEE on the hero (or on Evil You): animated body with legs, shadow,
## the Divine Sword (sheathed on the back, drawn with a "shing", swung with slash FX and a trail),
## and the Mirror Shield (shiny, raised in front while blocking, flashes on a perfect deflect).

const N := "res://assets/ninja/"
const SHEATHE_AFTER := 3.5

var skin := "player"
var body: AnimatedSprite2D
var owner_body: Node2D
var sword_pivot: Node2D
var sword: Sprite2D
var shield: Sprite2D
var shield_mat: ShaderMaterial
var shadow: Sprite2D
var light: PointLight2D
var trail: Line2D

var sheathed := true
var drawing := false
var swinging := false
var blocking := false
var dashing := false
var surface := "stone"
var facing := Vector2.DOWN
var slash_color := Color(1.5, 1.9, 2.3)
var trail_color := Color(0.6, 0.95, 1.0)

var _idle_t := 0.0
var _step_t := 0.0
var _ghost_t := 0.0
var _attack_pose_t := 0.0
var _swing_tween: Tween
var _trail_points: Array[Vector2] = []
var _flash_t := 0.0
var _special_spr: Sprite2D
var _rabid_aura: CPUParticles2D
var base_tint := Color.WHITE


func setup(owner_node: Node2D, body_sprite: AnimatedSprite2D, skin_name := "player") -> void:
	owner_body = owner_node
	body = body_sprite
	skin = skin_name
	var evil := skin == "evil"
	var ally := skin == "ally"
	body.sprite_frames = Sheet.character(N + ("chars/evil" if evil else ("chars/holo" if ally else "chars/player")))
	body.scale = Vector2(3, 3)
	body.position = Vector2(0, -10)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.material = Sheet.sprite_material()
	body.play("idle_down")

	shadow = Sprite2D.new()
	shadow.texture = load(N + "fx/shadow.png")
	shadow.scale = Vector2(3, 3)
	shadow.position = Vector2(0, 13)
	shadow.modulate = Color(0, 0, 0, 0.45)
	shadow.z_index = -1
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(shadow)

	sword_pivot = Node2D.new()
	add_child(sword_pivot)
	sword = Sprite2D.new()
	sword.texture = load(N + ("weapons/evil_sword.png" if evil else "weapons/divine_sword.png"))
	sword.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sword.offset = Vector2(0, -sword.texture.get_height() * 0.5 + 2)
	sword.scale = Vector2(3, 3)
	sword_pivot.add_child(sword)

	shield = Sprite2D.new()
	shield.texture = load(N + ("weapons/evil_shield.png" if evil else "weapons/mirror_shield.png"))
	shield.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shield_mat = ShaderMaterial.new()
	shield_mat.shader = preload("res://assets/shaders/mirror_shield.gdshader")
	if evil:
		shield_mat.set_shader_parameter("rim_color", Color(1, 0.3, 0.3))
	shield.material = shield_mat
	add_child(shield)

	trail = Line2D.new()
	trail.top_level = true
	trail.width = 14.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 1))
	trail.width_curve = curve
	var grad := Gradient.new()
	if evil:
		slash_color = Color(2.4, 0.5, 0.6)
		trail_color = Color(1, 0.3, 0.35)
	if ally:
		slash_color = Color(1.2, 2.2, 2.6)
		trail_color = Color(0.5, 1.0, 1.0)
	grad.colors = PackedColorArray([Color(trail_color, 0.0), Color(trail_color.r * 1.6, trail_color.g * 1.6, trail_color.b * 1.6, 0.9)])
	trail.gradient = grad
	trail.z_index = 25
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	trail.material = add
	add_child(trail)

	light = Sheet.make_light(Color(1, 0.35, 0.35) if evil else (Color(0.4, 1.0, 1.0) if ally else Color(0.75, 0.9, 1.0)), 0.7 if ally else 0.55, 2.0 if ally else 2.4)
	if ally:
		# A translucent warrior made of mirror light.
		base_tint = Color(1.3, 1.8, 2.0, 0.55)
		body.modulate = base_tint
		sword.modulate = Color(1.4, 2.0, 2.2, 0.75)
		shield.modulate = Color(1.4, 2.0, 2.2, 0.6)
		shadow.modulate = Color(0, 0, 0, 0.2)
	light.position = Vector2(0, -6)
	add_child(light)
	_place_sword_sheathed()
	_place_shield()


func update(dir: Vector2, velocity: Vector2, delta: float) -> void:
	if not is_instance_valid(body):
		return
	if dir.length_squared() > 0.0001:
		facing = dir.normalized()
	var d := Sheet.dir_of(facing)
	var moving := velocity.length() > 12.0
	_attack_pose_t = maxf(0.0, _attack_pose_t - delta)
	var anim := ("attack_" if _attack_pose_t > 0.0 else ("walk_" if moving else "idle_")) + d
	if body.animation != anim:
		body.play(anim)
	if moving and not dashing:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.3
			if skin == "player":
				Audio.step(surface)
			Juice.fx("smoke", global_position + Vector2(randf_range(-6, 6), 12), 1.0, 0.0, Color(1, 1, 1, 0.45), -1)
	if dashing:
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.03
			Juice.afterimage(body, Color(1, 0.3, 0.35, 0.6) if skin == "evil" else Color(0.5, 0.9, 1.0, 0.6))
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta)
		body.material.set_shader_parameter("flash", _flash_t / 0.12)

	# Sword: sheathe after a quiet moment
	if not sheathed and not swinging and not drawing:
		_idle_t += delta
		if _idle_t > SHEATHE_AFTER and not _enemies_near():
			sheathe()
		else:
			_place_sword_held(delta)
	elif sheathed:
		_place_sword_sheathed()
	_place_shield()
	_update_trail()


func _enemies_near() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e != owner_body and e.global_position.distance_to(global_position) < 420.0:
			return true
	return false


func _side() -> float:
	return -1.0 if facing.x < -0.2 else 1.0


func _place_sword_sheathed() -> void:
	var up := Sheet.dir_of(facing) == "up"
	sword_pivot.position = Vector2(-6 * _side(), -8)
	sword_pivot.rotation = (2.5 if _side() > 0 else -2.5)
	sword_pivot.scale = Vector2(0.8, 0.8)
	sword_pivot.z_index = 1 if up else -1


func _place_sword_held(delta: float) -> void:
	var target_pos := Vector2(13 * _side(), -6) + Vector2(0, sin(Time.get_ticks_msec() * 0.005) * 1.5)
	sword_pivot.position = sword_pivot.position.lerp(target_pos, minf(1.0, delta * 18.0))
	var target_rot := facing.angle() + PI * 0.5 - 0.5 * _side()
	sword_pivot.rotation = lerp_angle(sword_pivot.rotation, target_rot, minf(1.0, delta * 14.0))
	sword_pivot.scale = Vector2.ONE
	sword_pivot.z_index = -1 if Sheet.dir_of(facing) == "up" else 1


func _place_shield() -> void:
	var up := Sheet.dir_of(facing) == "up"
	if blocking:
		shield.position = facing * 20.0 + Vector2(0, -8)
		shield.rotation = facing.angle()
		shield.scale = shield.scale.lerp(Vector2(3.4, 3.4), 0.4)
		shield.z_index = -1 if up else 2
		shield_mat.set_shader_parameter("shine_speed", 1.4)
	else:
		shield.position = Vector2(-11 * _side(), -6)
		shield.rotation = 0.0
		shield.scale = shield.scale.lerp(Vector2(2.2, 2.2), 0.3)
		shield.z_index = 1 if up else -1
		shield_mat.set_shader_parameter("shine_speed", 0.5)
		shield_mat.set_shader_parameter("ready", 0.0)


## Pull the sword from the back. Returns the time it takes.
func draw_sword() -> float:
	if not sheathed or drawing:
		return 0.0
	drawing = true
	sheathed = false
	_idle_t = 0.0
	if skin == "player":
		Audio.sfx("sfx_sword_draw", 0.05, -4.0)
	var t := create_tween()
	t.tween_property(sword_pivot, "position", Vector2(4 * _side(), -26), 0.07)
	t.parallel().tween_property(sword_pivot, "rotation", 0.0, 0.07)
	t.parallel().tween_property(sword_pivot, "scale", Vector2.ONE, 0.07)
	t.tween_callback(func():
		var tip := sword_pivot.global_position + Vector2.UP.rotated(sword_pivot.rotation) * 48.0
		Juice.fx("spark", tip, 1.6, 0.0, slash_color)
		Juice.light_flash(tip, trail_color, 1.2, 0.8, 0.2))
	t.tween_property(sword_pivot, "position", Vector2(13 * _side(), -6), 0.06)
	t.tween_callback(func(): drawing = false)
	return 0.13


func sheathe() -> void:
	if sheathed:
		return
	sheathed = true
	_idle_t = 0.0
	if skin == "player":
		Audio.sfx("sfx_shield_block", 0.1, -20.0, 1.6)


## kind: 0 = slash, 1 = backslash, 2 = spin finisher, 3 = dash lunge. crit tints it gold.
func swing(dir: Vector2, kind: int, crit := false) -> void:
	_idle_t = 0.0
	facing = dir.normalized()
	swinging = true
	_attack_pose_t = 0.16
	_trail_points.clear()
	if is_instance_valid(_swing_tween):
		_swing_tween.kill()
	var a := facing.angle() + PI * 0.5
	var col := Color(2.6, 2.0, 0.7) if crit else slash_color
	sword_pivot.position = Vector2(0, -8)
	sword_pivot.z_index = 2
	_swing_tween = create_tween()
	match kind:
		2:
			sword_pivot.rotation = a
			_swing_tween.tween_property(sword_pivot, "rotation", a + TAU, 0.26)
			Juice.fx("slash_circular", global_position + Vector2(0, -6), 3.6, 0.0, col)
			Audio.sfx("sfx_spin", 0.05, -2.0)
		3:
			sword_pivot.rotation = a
			_swing_tween.tween_property(sword_pivot, "position", facing * 18.0 + Vector2(0, -8), 0.08)
			Juice.fx("slash_curved", global_position + facing * 40.0, 3.2, facing.angle(), col)
			Audio.sfx("sfx_swing_3", 0.05, -3.0)
		_:
			var from := a - 1.4 if kind == 0 else a + 1.4
			var to := a + 1.4 if kind == 0 else a - 1.4
			sword_pivot.rotation = from
			_swing_tween.tween_property(sword_pivot, "rotation", to, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			var fx := Juice.fx("slash_arc", global_position + facing * 34.0 + Vector2(0, -6), 3.0, facing.angle(), col)
			if fx and kind == 1:
				fx.scale.y = -3.0
			Audio.sfx("sfx_swing_%d" % (kind + 1), 0.08, -3.0)
	_swing_tween.tween_interval(0.05)
	_swing_tween.tween_callback(func(): swinging = false)


func set_blocking(on: bool, perfect_window: bool) -> void:
	blocking = on
	shield_mat.set_shader_parameter("ready", 1.0 if (on and perfect_window) else 0.0)


func deflect_fx(at: Vector2) -> void:
	shield_mat.set_shader_parameter("flash", 1.0)
	var t := create_tween()
	t.tween_method(func(v): shield_mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.3)
	var sp := shield.global_position
	Juice.fx("shield_blue" if skin == "player" else "shield_yellow", sp, 3.0, 0.0, Color(1.2, 1.45, 1.8))
	Juice.fx("circle_spark", at, 2.6, 0.0, Color(1.4, 1.7, 2.0))
	Juice.light_flash(sp, trail_color, 1.5, 1.6, 0.3)


## Briefly hold the world weapon (bow drawn, axe swung, wand raised).
func show_special(tex: Texture2D, kind: String) -> void:
	if _special_spr == null:
		_special_spr = Sprite2D.new()
		_special_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_special_spr.z_index = 3
		add_child(_special_spr)
	_special_spr.texture = tex
	_special_spr.visible = true
	_special_spr.modulate = Color(1.4, 1.4, 1.4)
	sword_pivot.visible = false
	_attack_pose_t = 0.25
	var t := create_tween()
	match kind:
		"flare_bow":
			_special_spr.position = facing * 18.0 + Vector2(0, -8)
			_special_spr.rotation = facing.angle() + PI * 0.5
			_special_spr.scale = Vector2(3.2, 3.2)
			t.tween_property(_special_spr, "scale", Vector2(3.6, 2.8), 0.06)
			t.tween_property(_special_spr, "scale", Vector2(3.2, 3.2), 0.12)
		"hunter_axe":
			_special_spr.position = Vector2(0, -8)
			_special_spr.offset = Vector2(0, -6)
			_special_spr.scale = Vector2(3.4, 3.4)
			var a := facing.angle() + PI * 0.5
			_special_spr.rotation = a - 2.0
			t.tween_property(_special_spr, "rotation", a + 2.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_:
			_special_spr.position = facing * 14.0 + Vector2(0, -14)
			_special_spr.rotation = facing.angle() + PI * 0.5
			_special_spr.scale = Vector2(3.0, 3.0)
			t.tween_property(_special_spr, "position", facing * 22.0 + Vector2(0, -20), 0.12)
	t.tween_interval(0.12)
	t.tween_callback(func():
		_special_spr.visible = false
		_special_spr.offset = Vector2.ZERO
		sword_pivot.visible = true)


func set_rabid(on: bool) -> void:
	if on:
		base_tint = Color(1.4, 0.7, 0.7)
		body.modulate = base_tint
		light.color = Color(1, 0.2, 0.2)
		slash_color = Color(2.6, 0.6, 0.5)
		if _rabid_aura == null:
			_rabid_aura = CPUParticles2D.new()
			_rabid_aura.amount = 30
			_rabid_aura.lifetime = 0.9
			_rabid_aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			_rabid_aura.emission_sphere_radius = 14.0
			_rabid_aura.gravity = Vector2(0, -70)
			_rabid_aura.initial_velocity_min = 5.0
			_rabid_aura.initial_velocity_max = 30.0
			_rabid_aura.scale_amount_min = 2.0
			_rabid_aura.scale_amount_max = 4.0
			_rabid_aura.color = Color(1.6, 0.1, 0.15, 0.7)
			_rabid_aura.position = Vector2(0, -6)
			_rabid_aura.z_index = -1
			add_child(_rabid_aura)
	else:
		base_tint = Color.WHITE
		body.modulate = base_tint
		if _rabid_aura:
			_rabid_aura.queue_free()
			_rabid_aura = null


func block_fx() -> void:
	Juice.fx("cut_x", shield.global_position, 1.6, 0.0, Color(1.2, 1.2, 1.2))


func hurt_flash() -> void:
	_flash_t = 0.12


func _update_trail() -> void:
	if swinging and not sheathed:
		var tip := sword_pivot.global_position + Vector2.UP.rotated(sword_pivot.rotation) * 46.0
		_trail_points.append(tip)
		if _trail_points.size() > 8:
			_trail_points.pop_front()
	elif not _trail_points.is_empty():
		_trail_points.pop_front()
	trail.points = PackedVector2Array(_trail_points)
