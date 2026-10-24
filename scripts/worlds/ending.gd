extends Node2D
## Quiet ending text over a whole sky. No music.

const LINES := [
	"The mirror is quiet.",
	"Somewhere ahead, a sky stays whole.",
	"No one will remember you.",
	"That was the point.",
]

var _can_restart := false


func _ready() -> void:
	Juice.reset_time()
	Audio.music("", 1.0)
	var cam := Camera2D.new()
	cam.position = Vector2(640, 360)
	add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(1280, 720)
	layer.add_child(black)
	var img := TextureRect.new()
	img.texture = load("res://assets/cutscenes/cut_ending.png")
	img.size = Vector2(1280, 720)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.modulate.a = 0.0
	layer.add_child(img)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.size = Vector2(1280, 720)
	layer.add_child(shade)
	var box := VBoxContainer.new()
	box.position = Vector2(0, 170)
	box.size = Vector2(1280, 400)
	box.add_theme_constant_override("separation", 22)
	layer.add_child(box)
	var labels: Array[Label] = []
	for line in LINES:
		labels.append(_line(box, line, 28, Color(0.95, 0.95, 1.0)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	box.add_child(spacer)
	var title := _line(box, "ECHO BREACH", 54, Color(1, 1, 1))
	var credits := _line(box, "Krish · Nischal · Azad", 20, Color(0.8, 0.85, 0.95))
	var assets := _line(box, "Art & sound: Kenney (CC0) · Music: Juhani Junkala, isaiah658, HaelDB via OpenGameArt (CC0)", 13, Color(0.6, 0.65, 0.75))
	var again := _line(box, "[E] Play again", 18, Color(0.7, 0.9, 1.0))

	var t := create_tween()
	t.tween_interval(1.0)
	t.tween_property(img, "modulate:a", 1.0, 3.0)
	for l in labels:
		t.tween_property(l, "modulate:a", 1.0, 1.2)
		t.tween_interval(1.3)
	t.tween_interval(3.0)
	t.tween_property(title, "modulate:a", 1.0, 1.5)
	t.tween_property(credits, "modulate:a", 1.0, 1.0)
	t.parallel().tween_property(assets, "modulate:a", 1.0, 1.0)
	t.tween_interval(1.5)
	t.tween_property(again, "modulate:a", 1.0, 0.8)
	t.tween_callback(func(): _can_restart = true)


func _line(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.modulate.a = 0.0
	parent.add_child(l)
	return l


func _process(_delta: float) -> void:
	if _can_restart and Input.is_action_just_pressed("interact"):
		_can_restart = false
		GameManager.reset_run()
		GameManager.go_to_scene("amnesia_room")
