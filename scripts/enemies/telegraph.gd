class_name Telegraph
extends Node2D
## Red warning shape that fills up, then "fires". Bosses check contains() when it fires.

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
	z_index = -1


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
		tw.tween_property(self, "modulate:a", 0.0, 0.18)
		tw.tween_callback(queue_free)


func _draw() -> void:
	var p := clampf(_t / maxf(duration, 0.01), 0.0, 1.0)
	var fill := Color(color.r, color.g, color.b, 0.12 + 0.25 * p)
	var edge := Color(color.r, color.g, color.b, 0.5 + 0.5 * p)
	if _done:
		fill = Color(1, 1, 1, 0.55)
	if shape == "circle":
		draw_circle(Vector2.ZERO, radius * (p if not _done else 1.0), fill)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, edge, 3.0, true)
	else:
		draw_rect(Rect2(0, -width * 0.5, length * (p if not _done else 1.0), width), fill)
		draw_rect(Rect2(0, -width * 0.5, length, width), edge, false, 2.0)
