class_name ParryCue
extends Node2D
## A timing ring around the player that shrinks toward the shield as an attack winds up.
## Red = wait. Cyan + "BLOCK!" = raise the shield now for a perfect reflect. It closes on the hit.

const WINDOW := 0.3   # same as the Mirror Shield's perfect window

var duration := 0.6
var _left := 0.6
var _in_window := false
var _target: Node2D


static func show_on(target: Node2D, time_to_hit: float) -> ParryCue:
	var c := ParryCue.new()
	c.duration = time_to_hit
	c._left = time_to_hit
	c._target = target
	target.get_tree().current_scene.add_child(c)
	c.global_position = target.global_position
	return c


func _ready() -> void:
	z_index = 55
	Audio.sfx("sfx_dialogue", 0.0, -6.0, 0.7)


func _process(delta: float) -> void:
	_left -= delta
	if is_instance_valid(_target):
		global_position = _target.global_position + Vector2(0, -8)
	if not _in_window and _left <= WINDOW:
		_in_window = true
		Audio.sfx("sfx_combo_3", 0.0, -4.0, 1.4)
	if _left <= -0.08:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var p := clampf(1.0 - _left / maxf(duration, 0.01), 0.0, 1.0)
	var r := lerpf(96.0, 26.0, p)
	var col := Color(1.0, 0.32, 0.28, 0.95) if not _in_window else Color(0.55, 1.0, 1.0, 1.0)
	var w := 2.5 if not _in_window else 4.0
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, col, w, true)
	draw_arc(Vector2.ZERO, 26.0, 0, TAU, 32, Color(col.r, col.g, col.b, 0.35), 2.0, true)
	if _in_window:
		var font: Font = preload("res://assets/ninja/ui/font.tres")
		draw_string(font, Vector2(-60, -r - 10), "BLOCK!", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(0.8, 1.0, 1.0))
