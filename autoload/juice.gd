extends Node
## Game feel: screen shake, hit-stop, flashes, slow motion, shockwaves, chromatic aberration,
## one-shot FX animations, light flashes, afterimages, debris and floating text.

const FONT := preload("res://assets/ninja/ui/font.tres")

var _trauma := 0.0
var _shake_power := 0.0
var _flash: ColorRect
var _screen: ColorRect
var _screen_mat: ShaderMaterial
var _base_time_scale := 1.0
var _stopping := false
var _zoom_punch := 0.0
var _wave_t := -1.0
var _wave_dur := 0.45
var _wave_strength := 0.0
var _chroma := 0.0
var _chroma_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 2
	add_child(fx_layer)
	_screen = ColorRect.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = preload("res://assets/shaders/screen_fx.gdshader")
	_screen.material = _screen_mat
	fx_layer.add_child(_screen)
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	layer.add_child(_flash)


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	var cam := get_viewport().get_camera_2d()
	if cam:
		if _trauma > 0.0:
			_trauma = maxf(0.0, _trauma - real * 2.2)
			var amount := _shake_power * _trauma * _trauma
			cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount
		else:
			cam.offset = Vector2.ZERO
		if _zoom_punch > 0.0:
			_zoom_punch = maxf(0.0, _zoom_punch - real * 0.6)
		var base_zoom: float = cam.get_meta("base_zoom", 1.0)
		cam.zoom = Vector2.ONE * (base_zoom + _zoom_punch)
	if _wave_t >= 0.0:
		_wave_t += real
		var p := _wave_t / _wave_dur
		_screen_mat.set_shader_parameter("wave_radius", p * 0.8)
		_screen_mat.set_shader_parameter("wave_strength", _wave_strength * (1.0 - p))
		if p >= 1.0:
			_wave_t = -1.0
			_screen_mat.set_shader_parameter("wave_strength", 0.0)
	if _chroma_t > 0.0:
		_chroma_t = maxf(0.0, _chroma_t - real)
		_screen_mat.set_shader_parameter("chroma", _chroma * _chroma_t / 0.3)


# ---------------- camera / time ----------------
func shake(power := 6.0, trauma := 0.6) -> void:
	_shake_power = maxf(power, _shake_power if _trauma > 0.0 else 0.0)
	_trauma = clampf(_trauma + trauma, 0.0, 1.0)


func zoom_punch(amount := 0.08) -> void:
	_zoom_punch = maxf(_zoom_punch, amount)


## Freeze the game for a few frames so hits land hard (default 50 ms).
func hitstop(seconds := 0.05) -> void:
	if _stopping or get_tree().paused:
		return
	_stopping = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = _base_time_scale
	_stopping = false


## Brief slow motion (real-time duration), e.g. after a perfect deflect.
func slow_pulse(scale := 0.3, real_seconds := 0.18) -> void:
	if _base_time_scale < 1.0:
		return
	Engine.time_scale = scale
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	Engine.time_scale = _base_time_scale


func slowmo(scale: float) -> void:
	_base_time_scale = scale
	Engine.time_scale = scale


func reset_time() -> void:
	_base_time_scale = 1.0
	Engine.time_scale = 1.0
	set_screen(0.35, 0.0, 0.0, Color.WHITE)


# ---------------- screen ----------------
func flash(color := Color(1, 1, 1, 0.5), duration := 0.15) -> void:
	_flash.color = color
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(_flash, "color:a", 0.0, duration)


func shockwave(world_pos: Vector2, strength := 0.04, duration := 0.45) -> void:
	var vp := get_viewport()
	var screen_pos := vp.get_canvas_transform() * world_pos
	var size := vp.get_visible_rect().size
	_screen_mat.set_shader_parameter("wave_center", screen_pos / size)
	_wave_strength = strength
	_wave_dur = duration
	_wave_t = 0.0


## Mirror Domain overlay (driven by MirrorDomain): world position, radius in pixels, crack 0..1.
func domain(world_pos: Vector2, radius_px: float, on: float, crack := 0.0) -> void:
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var cam := vp.get_camera_2d()
	var zoom: float = cam.zoom.x if cam else 1.0
	_screen_mat.set_shader_parameter("dom_center", (vp.get_canvas_transform() * world_pos) / size)
	_screen_mat.set_shader_parameter("dom_radius", radius_px * zoom / size.y)
	_screen_mat.set_shader_parameter("dom_on", on)
	_screen_mat.set_shader_parameter("dom_crack", crack)


## Negative-image flash (the world reversed for an instant).
func invert(duration := 0.2) -> void:
	_screen_mat.set_shader_parameter("invert", 1.0)
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_method(func(v): _screen_mat.set_shader_parameter("invert", v), 1.0, 0.0, duration)


func chroma(amount := 0.012) -> void:
	_chroma = amount
	_chroma_t = 0.3


func set_screen(vignette := 0.35, scanlines := 0.0, desaturate := 0.0, tint := Color.WHITE) -> void:
	_screen_mat.set_shader_parameter("vignette", vignette)
	_screen_mat.set_shader_parameter("scanlines", scanlines)
	_screen_mat.set_shader_parameter("desaturate", desaturate)
	_screen_mat.set_shader_parameter("tint", tint)


# ---------------- world FX ----------------
func _scene() -> Node:
	return get_tree().current_scene


func fx(name: String, pos: Vector2, scale := 3.0, rot := 0.0, modulate := Color.WHITE, z := 20) -> AnimatedSprite2D:
	var scene := _scene()
	if scene == null:
		return null
	var s := AnimatedSprite2D.new()
	s.sprite_frames = Sheet.fx(name)
	s.global_position = pos
	s.rotation = rot
	s.scale = Vector2(scale, scale)
	s.modulate = modulate
	s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene.add_child(s)
	s.play("default")
	s.animation_finished.connect(s.queue_free)
	return s


func light_flash(pos: Vector2, color: Color, energy := 1.6, scale := 2.0, duration := 0.3) -> void:
	var scene := _scene()
	if scene == null:
		return
	var l := Sheet.make_light(color, energy, scale)
	l.global_position = pos
	scene.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "energy", 0.0, duration)
	t.tween_callback(l.queue_free)


func afterimage(source: AnimatedSprite2D, color := Color(0.5, 0.9, 1.0, 0.6), life := 0.25) -> void:
	var scene := _scene()
	if scene == null or source == null or source.sprite_frames == null:
		return
	var tex := source.sprite_frames.get_frame_texture(source.animation, source.frame)
	var g := Sprite2D.new()
	g.texture = tex
	g.global_transform = source.global_transform
	g.flip_h = source.flip_h
	g.modulate = color
	g.z_index = source.z_index - 1
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene.add_child(g)
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, life)
	t.tween_callback(g.queue_free)


func burst(pos: Vector2, color: Color, amount := 14, speed := 160.0, size := 3.0) -> void:
	var scene := _scene()
	if scene == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.45
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = 120.0
	p.damping_max = 220.0
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.3
	p.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.global_position = pos
	p.z_index = 20
	scene.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Chunky debris using a particle sheet (wood, vase, rock...): random frames, gravity bounce feel.
func debris(pos: Vector2, sheet: String, frames: int, amount := 10, color := Color.WHITE) -> void:
	var scene := _scene()
	if scene == null:
		return
	var p := CPUParticles2D.new()
	p.texture = load(sheet)
	var mat := CanvasItemMaterial.new()
	mat.particles_animation = true
	mat.particles_anim_h_frames = frames
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = false
	p.material = mat
	p.anim_offset_max = 1.0
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.7
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2(0, 520)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 2.4
	p.scale_amount_max = 3.2
	p.color = color
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.global_position = pos
	p.z_index = 15
	scene.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func number(pos: Vector2, value: float, color := Color.WHITE, big := false) -> void:
	text_pop(pos, str(roundi(value)), color, 24 if big else 16)


func text_pop(pos: Vector2, text: String, color := Color.WHITE, size := 16, rise := 34.0, life := 0.7) -> void:
	var scene := _scene()
	if scene == null:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 60
	label.position = pos + Vector2(randf_range(-10, 10) - 16, -46)
	label.scale = Vector2(1.5, 1.5)
	scene.add_child(label)
	var t := label.create_tween()
	t.set_parallel(true)
	t.tween_property(label, "scale", Vector2.ONE, 0.12)
	t.tween_property(label, "position:y", label.position.y - rise, life)
	t.tween_property(label, "modulate:a", 0.0, life * 0.6).set_delay(life * 0.4)
	t.chain().tween_callback(label.queue_free)
