extends Node
## Game feel: screen shake, hit-stop, screen flash, particles, damage numbers, slow motion.

var _trauma := 0.0
var _shake_power := 0.0
var _flash: ColorRect
var _base_time_scale := 1.0
var _stopping := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	layer.add_child(_flash)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - real_delta * 2.2)
		var amount := _shake_power * _trauma * _trauma
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount
	else:
		cam.offset = Vector2.ZERO


func shake(power := 6.0, trauma := 0.6) -> void:
	_shake_power = maxf(power, _shake_power if _trauma > 0.0 else 0.0)
	_trauma = clampf(_trauma + trauma, 0.0, 1.0)


## Freeze the game for a few frames so hits land hard (default 50 ms).
func hitstop(seconds := 0.05) -> void:
	if _stopping or get_tree().paused:
		return
	_stopping = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = _base_time_scale
	_stopping = false


func flash(color := Color(1, 1, 1, 0.5), duration := 0.15) -> void:
	_flash.color = color
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(_flash, "color:a", 0.0, duration)


func slowmo(scale: float) -> void:
	_base_time_scale = scale
	Engine.time_scale = scale


func reset_time() -> void:
	_base_time_scale = 1.0
	Engine.time_scale = 1.0


func burst(pos: Vector2, color: Color, amount := 14, speed := 160.0, size := 3.0) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.45
	p.spread = 180.0
	p.direction = Vector2.UP
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


func number(pos: Vector2, value: float, color := Color.WHITE) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var label := Label.new()
	label.text = str(roundi(value))
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.z_index = 30
	label.position = pos + Vector2(randf_range(-10, 10) - 10, -40)
	scene.add_child(label)
	var t := label.create_tween()
	t.set_parallel(true)
	t.tween_property(label, "position:y", label.position.y - 30, 0.6)
	t.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	t.chain().tween_callback(label.queue_free)
