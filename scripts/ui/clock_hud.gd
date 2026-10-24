class_name ClockHud
extends Control
## The world clock at the top center: a mirror dial whose ring of light drains backwards
## (counter-clockwise), a spark that orbits the wrong way, and the time left in the middle.
## Cyan -> amber -> red as it runs out. Cracks when time is up; glows when you beat it.

const FONT := preload("res://assets/ninja/ui/font.tres")
const R := 34.0

var rift: TimeRift
var _state := "run"
var _spin := 0.0
var _pulse := 0.0
var _flash := 0.0
var _show := 0.0
var _cracks: Array = []
var _crack_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(540, 4)
	size = Vector2(200, 110)
	pivot_offset = Vector2(100, 44)
	modulate.a = 0.0
	for i in 7:
		var pts := PackedVector2Array([Vector2(100, 44)])
		var a := randf() * TAU
		var p := Vector2(100, 44)
		for k in 4:
			a += randf_range(-0.6, 0.6)
			p += Vector2.from_angle(a) * randf_range(8.0, 14.0)
			pts.append(p)
		_cracks.append(pts)


func appear() -> void:
	scale = Vector2(0.4, 0.4)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.3)
	t.parallel().tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.sfx("sfx_time_warn", 0.0, -8.0, 1.3)


func pulse() -> void:
	_pulse = 1.0


func set_state(s: String) -> void:
	_state = s
	_flash = 1.0
	if s == "cleared":
		var t := create_tween()
		t.tween_interval(3.0)
		t.tween_property(self, "modulate:a", 0.35, 1.0)


func _process(delta: float) -> void:
	if rift == null:
		return
	var real := delta / maxf(Engine.time_scale, 0.01)
	var p := rift.progress()
	match _state:
		"run":
			_spin -= real * TAU * (0.25 + 0.75 * p)        # backwards, faster as it drains
		"cleared":
			_spin += real * TAU * 2.0 * maxf(_flash, 0.15)   # time runs forward again
		"expired":
			_crack_t = minf(1.0, _crack_t + real * 2.5)
	_pulse = maxf(0.0, _pulse - real * 2.5)
	_flash = maxf(0.0, _flash - real * 0.8)
	var s := 1.0 + _pulse * 0.12
	if _state == "run" and modulate.a > 0.9:
		scale = Vector2(s, s)
	if _state == "expired":
		position = Vector2(540, 4) + Vector2(randf_range(-3, 3), randf_range(-3, 3))
	queue_redraw()


func _color() -> Color:
	var frac := rift.left / maxf(rift.duration, 0.01)
	if _state == "cleared":
		return Color(0.55, 1.0, 0.85)
	if _state == "expired":
		return Color(1.0, 0.3, 0.35)
	var cyan := Color(0.55, 0.95, 1.0)
	var amber := Color(1.0, 0.82, 0.4)
	var red := Color(1.0, 0.35, 0.35)
	if frac > 0.5:
		return cyan
	if frac > 0.2:
		return cyan.lerp(amber, (0.5 - frac) / 0.3)
	return amber.lerp(red, (0.2 - frac) / 0.2)


func _draw() -> void:
	if rift == null:
		return
	var c := Vector2(100, 44)
	var col := _color()
	var frac := clampf(rift.left / maxf(rift.duration, 0.01), 0.0, 1.0)
	# glass body and silver bezel
	draw_circle(c, R + 8.0, Color(0.03, 0.05, 0.1, 0.82))
	draw_circle(c, R - 6.0, Color(0.08, 0.12, 0.2, 0.9))
	draw_arc(c, R + 8.0, 0, TAU, 64, Color(0.78, 0.88, 1.0, 0.95), 2.0, true)
	draw_arc(c, R + 4.5, 0, TAU, 64, Color(0.4, 0.5, 0.65, 0.6), 1.0, true)
	# drained part of the ring (dim) and what's left (bright), anchored at 12 o'clock
	draw_arc(c, R, 0, TAU, 64, Color(col.r, col.g, col.b, 0.15), 5.0, true)
	if frac > 0.001:
		draw_arc(c, R, -PI * 0.5 - TAU * frac, -PI * 0.5, 72, col, 5.0, true)
	# tick marks
	for i in 12:
		var a := TAU * i / 12.0 - PI * 0.5
		var r0 := R - (9.0 if i % 3 == 0 else 6.0)
		draw_line(c + Vector2.from_angle(a) * r0, c + Vector2.from_angle(a) * (R - 3.0), Color(0.85, 0.92, 1.0, 0.7 if i % 3 == 0 else 0.4), 2.0 if i % 3 == 0 else 1.0, true)
	# the spark orbiting the wrong way
	var sp := c + Vector2.from_angle(_spin - PI * 0.5) * R
	draw_circle(sp, 4.0, Color(1, 1, 1, 0.95))
	draw_circle(sp, 7.0, Color(col.r, col.g, col.b, 0.35))
	# time left
	var secs := int(ceil(rift.left))
	var txt := "%d:%02d" % [secs / 60, secs % 60]
	var tcol := Color(1, 1, 1) if _state == "run" and rift.left > 10.0 else col
	var fs := 20
	draw_string_outline(FONT, Vector2(c.x - 40, c.y + 8), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, 5, Color(0.02, 0.03, 0.08))
	draw_string(FONT, Vector2(c.x - 40, c.y + 8), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, tcol)
	# caption
	var cap := "REVERSING"
	var ccol := Color(0.7, 0.85, 1.0, 0.75)
	if _state == "cleared":
		cap = "TIMELINE HELD"
		ccol = Color(0.6, 1.0, 0.85)
	elif _state == "expired":
		cap = "SHATTERED"
		ccol = Color(1.0, 0.4, 0.4)
	elif rift.left <= 10.0:
		ccol = Color(1.0, 0.45, 0.45, 0.6 + 0.4 * _pulse)
	draw_string_outline(FONT, Vector2(0, c.y + R + 26), cap, HORIZONTAL_ALIGNMENT_CENTER, 200, 12, 4, Color(0.02, 0.03, 0.08))
	draw_string(FONT, Vector2(0, c.y + R + 26), cap, HORIZONTAL_ALIGNMENT_CENTER, 200, 12, ccol)
	# flash ring on state changes / warnings
	var fl := maxf(_flash, _pulse * 0.6)
	if fl > 0.0:
		draw_arc(c, R + 8.0 + (1.0 - fl) * 16.0, 0, TAU, 64, Color(col.r, col.g, col.b, fl * 0.8), 3.0, true)
	# cracks when time is up
	if _crack_t > 0.0:
		for pts in _cracks:
			var n := maxi(2, int(pts.size() * _crack_t))
			draw_polyline(pts.slice(0, n), Color(1, 1, 1, 0.95), 2.0, true)
