class_name MirrorDomain
extends Node2D
## Hypno Reverse's domain: for a split second a circular mirror opens around you and everything
## inside shows its inverted soul (drawn by the screen effect shader), then it cracks and shatters.
## Enemies inside come out as allies.

signal opened

var radius := 250.0
var _r := 0.0
var _on := 0.0
var _crack := 0.0
var _cracks: Array[Line2D] = []


static func open_at(parent: Node, pos: Vector2, r: float) -> MirrorDomain:
	var d := MirrorDomain.new()
	d.radius = r
	d.global_position = pos
	parent.add_child(d)
	return d


func _ready() -> void:
	z_index = 45
	_run()


func _process(_delta: float) -> void:
	Juice.domain(global_position, _r, _on, _crack)


func _exit_tree() -> void:
	Juice.domain(global_position, 0.0, 0.0, 0.0)


func _run() -> void:
	# Expand (real time; the world is almost frozen)
	_on = 1.0
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(self, "_r", radius, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await t.finished
	opened.emit()
	await get_tree().create_timer(0.32, true, false, true).timeout
	# Crack and shatter
	Audio.sfx("sfx_mirror_shatter", 0.05, -4.0, 1.2)
	for i in 9:
		var l := Line2D.new()
		var a := randf() * TAU
		var pts := PackedVector2Array([Vector2.ZERO])
		var pos := Vector2.ZERO
		for k in 4:
			a += randf_range(-0.4, 0.4)
			pos += Vector2(cos(a), sin(a)) * radius * 0.26
			pts.append(pos)
		l.points = pts
		l.width = 3.0
		l.default_color = Color(0.9, 1.0, 1.0, 0.9)
		add_child(l)
		_cracks.append(l)
	var t2 := create_tween()
	t2.set_ignore_time_scale(true)
	t2.tween_property(self, "_crack", 1.0, 0.28)
	t2.parallel().tween_property(self, "_r", radius * 1.05, 0.28)
	for l in _cracks:
		t2.parallel().tween_property(l, "modulate:a", 0.0, 0.28)
	await t2.finished
	_on = 0.0
	Juice.debris(global_position, "res://assets/ninja/fx/particle_rockgray.png", 6, 26, Color(1.0, 1.2, 1.3))
	queue_free()
