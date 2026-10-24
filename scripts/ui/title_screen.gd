extends Node2D
## Start page: INVERTED SOUL.
## The title stands on a mirror line with its own upside-down reflection under it, a clock
## behind it runs backwards and the dust falls upward. One button: START GAME.

const FONT := preload("res://assets/ninja/ui/font.tres")
const WAVE_SHADER := """
shader_type canvas_item;
uniform float amp = 3.0;
void vertex() {
	VERTEX.x += sin(VERTEX.y * 0.08 + TIME * 2.4) * amp;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float band = 0.75 + 0.25 * sin(SCREEN_UV.y * 220.0 - TIME * 3.0);
	COLOR = vec4(c.rgb, c.a * band);
}
"""

const LINE_Y := 352.0

var _t := 0.0
var _started := false
var _dial: Control
var _title: Label
var _mirror: Label
var _button: Button
var _hint: Label


func _ready() -> void:
	GameManager.reset_run()
	GameManager.current_scene = "title"
	Juice.reset_time()
	Juice.set_screen(0.55, 0.0, 0.0, Color.WHITE)
	Audio.music("music_room", 1.5)
	Audio.ambient("")
	var cam := Camera2D.new()
	cam.position = Vector2(640, 360)
	add_child(cam)
	cam.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.07)
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)

	# The backwards clock and the mirror line
	_dial = Control.new()
	_dial.size = Vector2(1280, 720)
	_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dial.draw.connect(_draw_dial)
	layer.add_child(_dial)

	# Dust that falls up: time runs the wrong way here
	var dust := CPUParticles2D.new()
	dust.amount = 120
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(660, 10)
	dust.position = Vector2(640, 740)
	dust.direction = Vector2.UP
	dust.spread = 12.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 25.0
	dust.initial_velocity_max = 70.0
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.5
	dust.color = Color(0.7, 0.9, 1.0, 0.55)
	layer.add_child(dust)

	_title = _label("INVERTED SOUL", 92, Color(0.96, 0.98, 1.0))
	_title.add_theme_color_override("font_outline_color", Color(0.15, 0.55, 0.75))
	_title.add_theme_constant_override("outline_size", 14)
	_title.position = Vector2(0, LINE_Y - 116)
	_title.size = Vector2(1280, 110)
	layer.add_child(_title)

	# Its reflection: flipped upside down under the mirror line, rippling
	_mirror = _label("INVERTED SOUL", 92, Color(0.55, 0.85, 1.0, 0.32))
	_mirror.add_theme_color_override("font_outline_color", Color(0.1, 0.3, 0.45, 0.3))
	_mirror.add_theme_constant_override("outline_size", 14)
	_mirror.size = Vector2(1280, 110)
	_mirror.pivot_offset = Vector2(640, 0)
	_mirror.position = Vector2(0, LINE_Y + 114)
	_mirror.scale = Vector2(1, -1)
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WAVE_SHADER
	m.shader = sh
	_mirror.material = m
	layer.add_child(_mirror)

	var tag := _label("Time runs backwards. So will you.", 22, Color(0.78, 0.84, 0.95))
	tag.position = Vector2(0, LINE_Y + 128)
	tag.size = Vector2(1280, 30)
	layer.add_child(tag)

	_button = Button.new()
	_button.text = "START GAME"
	_button.add_theme_font_override("font", FONT)
	_button.add_theme_font_size_override("font_size", 30)
	_button.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	_button.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	for st in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.05, 0.12, 0.18, 0.85) if st == "normal" else Color(0.1, 0.3, 0.42, 0.95)
		box.border_color = Color(0.45, 0.9, 1.0, 0.9) if st != "normal" else Color(0.35, 0.65, 0.8, 0.7)
		box.set_border_width_all(3)
		box.set_corner_radius_all(4)
		box.content_margin_left = 36
		box.content_margin_right = 36
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		_button.add_theme_stylebox_override(st, box)
	_button.size = Vector2(300, 64)
	_button.position = Vector2(490, 548)
	_button.pressed.connect(_start)
	_button.mouse_entered.connect(func(): Audio.sfx("sfx_ui_confirm", 0.05, -14.0, 1.5))
	layer.add_child(_button)
	_button.grab_focus()

	_hint = _label("Click, or press E / Enter", 14, Color(0.55, 0.62, 0.75))
	_hint.position = Vector2(0, 622)
	_hint.size = Vector2(1280, 20)
	layer.add_child(_hint)

	var credits := _label("Krish  ·  Nischal  ·  Azad", 16, Color(0.6, 0.66, 0.8))
	credits.position = Vector2(0, 676)
	credits.size = Vector2(1280, 24)
	layer.add_child(credits)

	for n in [_title, _mirror, tag, _button, _hint, credits]:
		n.modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(0.3)
	t.tween_property(_title, "modulate:a", 1.0, 1.2)
	t.parallel().tween_property(_mirror, "modulate:a", 1.0, 1.6)
	t.tween_property(tag, "modulate:a", 1.0, 0.8)
	t.tween_property(_button, "modulate:a", 1.0, 0.5)
	t.parallel().tween_property(_hint, "modulate:a", 1.0, 0.5)
	t.parallel().tween_property(credits, "modulate:a", 1.0, 0.5)
	if OS.get_environment("ECHO_BOT") == "1":
		get_tree().create_timer(1.0).timeout.connect(_start)


func _process(delta: float) -> void:
	_t += delta
	_dial.queue_redraw()
	if is_instance_valid(_title):
		var p := 1.0 + 0.04 * sin(_t * 1.6)
		_title.self_modulate = Color(p, p, p)
	if not _started and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept")):
		_start()


func _draw_dial() -> void:
	var c := Vector2(640, LINE_Y - 40)
	var r := 250.0
	_dial.draw_arc(c, r, 0, TAU, 96, Color(0.35, 0.7, 0.9, 0.12), 3.0, true)
	_dial.draw_arc(c, r - 18.0, 0, TAU, 96, Color(0.35, 0.7, 0.9, 0.06), 2.0, true)
	for i in 12:
		var a := TAU * i / 12.0
		var d := Vector2.from_angle(a)
		_dial.draw_line(c + d * (r - 14.0), c + d * (r - 2.0), Color(0.5, 0.85, 1.0, 0.22), 3.0)
	# Both hands sweep counter-clockwise: the clock is rewinding.
	var big := -_t * 0.9 - PI * 0.5
	var small := -_t * 0.075 - PI * 0.5
	_dial.draw_line(c, c + Vector2.from_angle(big) * (r - 40.0), Color(0.55, 0.9, 1.0, 0.22), 3.0)
	_dial.draw_line(c, c + Vector2.from_angle(small) * (r - 110.0), Color(0.55, 0.9, 1.0, 0.18), 5.0)
	_dial.draw_circle(c, 6.0, Color(0.55, 0.9, 1.0, 0.3))
	# Mirror line, with a slow light sweeping across it
	_dial.draw_line(Vector2(80, LINE_Y), Vector2(1200, LINE_Y), Color(0.6, 0.95, 1.0, 0.55), 2.0)
	var sx := 80.0 + fposmod(_t * 260.0, 1400.0)
	_dial.draw_line(Vector2(sx - 90.0, LINE_Y), Vector2(minf(sx, 1200.0), LINE_Y), Color(1, 1, 1, 0.8), 3.0)


func _start() -> void:
	if _started:
		return
	_started = true
	Audio.sfx("sfx_ui_confirm", 0.0, -2.0)
	Audio.sfx("sfx_time_restore", 0.0, -4.0)
	_button.disabled = true
	var t := create_tween()
	t.tween_property(_mirror, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_BACK)
	t.parallel().tween_property(_mirror, "position:y", LINE_Y, 0.5)
	await t.finished
	GameManager.go_to_scene("amnesia_room", "mirror")


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
