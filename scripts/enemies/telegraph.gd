class_name Telegraph
extends Node2D
## Red warning shape that charges up, then "fires". Bosses check contains() when it fires.
## Lines are drawn as a glowing red laser sight; circles as a glowing red ring that fills in.

signal fired

var shape := "circle"   # "circle" or "line"
var radius := 80.0
var length := 600.0
var width := 50.0
var duration := 1.0
var color := Color(1.0, 0.15, 0.2)
var _t := 0.0
var _done := false


static func circle(parent: Node, pos: Vector2, r: float, time: float, col := Color(1.0, 0.15, 0.2)) -> Telegraph:
	var t := Telegraph.new()
	t.shape = "circle"
	t.radius = r
	t.duration = time
	t.color = col
	t.global_position = pos
	parent.add_child(t)
	return t


static func line(parent: Node, from: Vector2, dir: Vector2, len: float, w: float, time: float, col := Color(1.0, 0.15, 0.2)) -> Telegraph:
	var t := Telegraph.new()
	t.shape = "line"
	t.length = len
	t.width = w
	t.duration = time
	t.color = col
	t.global_position = from
	t.rotation = dir.angle()
	parent.add_child(t)
	return t


func _ready() -> void:
	z_index = -1 if shape == "circle" else 18


func contains(point: Vector2) -> bool:
	var local := to_local(point)
	if shape == "circle":
		return local.length() <= radius
	return local.x >= 0.0 and local.x <= length and absf(local.y) <= width * 0.5


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not _done and _t >= duration:
		_done = true
		fired.emit()
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.2)
		tw.tween_callback(queue_free)


func _draw() -> void:
	var p := clampf(_t / maxf(duration, 0.01), 0.0, 1.0)
	var flicker := 0.75 + 0.25 * sin(_t * 40.0)
	var hot := Color(color.r * 2.6, color.g * 1.6, color.b * 1.6, 1.0)   # HDR so it glows
	if shape == "circle":
		var fill := Color(color.r, color.g, color.b, 0.10 + 0.22 * p)
		if _done:
			fill = Color(1.6, 1.2, 1.2, 0.5)
		draw_circle(Vector2.ZERO, radius * (p if not _done else 1.0), fill)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 56, Color(hot.r, hot.g, hot.b, 0.5 + 0.5 * p * flicker), 2.5 + 2.0 * p, true)
		draw_arc(Vector2.ZERO, radius * p, 0, TAU, 40, Color(hot.r, hot.g, hot.b, 0.6), 1.5, true)
		return
	# Laser sight: soft glow band + bright core that thickens as it charges, edges pulse.
	var half := width * 0.5
	if _done:
		draw_rect(Rect2(0, -half, length, width), Color(2.4, 1.6, 1.6, 0.85))
		draw_line(Vector2.ZERO, Vector2(length, 0), Color(3, 3, 3, 1), 6.0)
		return
	draw_rect(Rect2(0, -half, length, width), Color(color.r, color.g, color.b, 0.05 + 0.12 * p))
	for side in [-1.0, 1.0]:
		draw_line(Vector2(0, side * half), Vector2(length, side * half), Color(hot.r, hot.g, hot.b, 0.25 + 0.4 * p * flicker), 1.5)
	draw_line(Vector2.ZERO, Vector2(length, 0), Color(hot.r, hot.g, hot.b, 0.35 * flicker), 2.0 + 10.0 * p)
	draw_line(Vector2.ZERO, Vector2(length, 0), Color(3.0, 1.4, 1.4, 0.9 * flicker), 1.5 + 2.5 * p)
	draw_circle(Vector2.ZERO, 4.0 + 4.0 * p, hot)
