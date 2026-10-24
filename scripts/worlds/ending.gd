extends Node2D
## Two endings.
##   DIVINE     - you kept your sanity and made the sacrifice: dawn, the breach closes.
##   REFLECTION - you died 3+ times: your reflection walks out into the world wearing your face.

const FONT := preload("res://assets/ninja/ui/font.tres")
const DIVINE := {
	"panel": "res://assets/ninja/cutscenes/ending_divine.png", "voice": "narrator", "music": "music_ending",
	"title": "ENDING: DIVINE", "title_color": Color(1, 0.92, 0.65), "text_color": Color(1, 0.97, 0.9),
	"lines": ["The mirror is quiet.", "Time turns forward again. Somewhere ahead, a sky stays whole.", "No one will remember you.", "That was the point."],
}
const EVIL := {
	"panel": "res://assets/ninja/cutscenes/ending_evil.png", "voice": "evil", "music": "music_final",
	"title": "ENDING: REFLECTION", "title_color": Color(1, 0.3, 0.35), "text_color": Color(1, 0.85, 0.85),
	"lines": ["The mirror smiles.", "Your reflection walks out into the world, wearing your face.", "The breach never closes. It only grows.", "Somewhere, someone is running from you."],
}

var _can_restart := false
var _img: TextureRect
var _t := 0.0
var _evil := false


func _ready() -> void:
	_evil = GameManager.ending_type() == "evil"
	var e: Dictionary = EVIL if _evil else DIVINE
	Juice.reset_time()
	Juice.set_screen(0.5, 0.0, 0.0, Color.WHITE)
	Audio.music("", 1.0)
	Audio.ambient("")
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
	_img = TextureRect.new()
	_img.texture = load(e.panel)
	_img.size = Vector2(1280, 720)
	_img.pivot_offset = Vector2(640, 360)
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_img.modulate.a = 0.0
	_img.scale = Vector2(1.12, 1.12)
	layer.add_child(_img)
	# Drifting particles: golden motes rising, or ash falling
	var parts := CPUParticles2D.new()
	parts.amount = 90
	parts.lifetime = 6.0
	parts.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	parts.emission_rect_extents = Vector2(660, 20)
	parts.position = Vector2(640, 740 if not _evil else -20)
	parts.direction = Vector2(0, -1 if not _evil else 1)
	parts.spread = 25.0
	parts.gravity = Vector2(0, -12 if not _evil else 18)
	parts.initial_velocity_min = 30.0
	parts.initial_velocity_max = 80.0
	parts.scale_amount_min = 2.0
	parts.scale_amount_max = 5.0
	parts.color = Color(1, 0.9, 0.6, 0.8) if not _evil else Color(0.25, 0.2, 0.22, 0.85)
	layer.add_child(parts)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.size = Vector2(1280, 720)
	layer.add_child(shade)
	var box := VBoxContainer.new()
	box.position = Vector2(0, 120)
	box.size = Vector2(1280, 480)
	box.add_theme_constant_override("separation", 18)
	layer.add_child(box)
	var labels: Array[Label] = []
	for line in e.lines:
		labels.append(_line(box, line, 30, e.text_color))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)
	var title := _line(box, e.title, 56, e.title_color)
	var game := _line(box, "ECHO BREACH", 24, Color(1, 1, 1))
	var stats := _line(box, "Deaths: %d    Best combo: %d    Time: %d:%02d" % [GameManager.deaths, GameManager.best_combo, int(GameManager.run_time) / 60, int(GameManager.run_time) % 60], 16, Color(0.85, 0.85, 0.95))
	var credits := _line(box, "Krish  ·  Nischal  ·  Azad", 20, Color(0.8, 0.85, 0.95))
	var assets := _line(box, "Art, music & sound: Pixel-boy (Ninja Adventure, CC0) · Kenney (CC0)", 14, Color(0.65, 0.7, 0.8))
	var again := _line(box, "[E] Play again" + ("   (die fewer than 3 times for the Divine ending)" if _evil else ""), 18, Color(0.7, 0.9, 1.0))
	_play(e, labels, [title, game, stats, credits, assets, again])


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_img):
		_img.scale = Vector2.ONE * lerpf(1.12, 1.0, clampf(_t / 18.0, 0.0, 1.0))
		if _evil:
			var p := 0.85 + 0.15 * sin(_t * 2.2)
			_img.self_modulate = Color(p, p * 0.9, p * 0.9)
	if _can_restart and Input.is_action_just_pressed("interact"):
		_can_restart = false
		GameManager.reset_run()
		GameManager.go_to_scene("amnesia_room")


func _play(e: Dictionary, labels: Array[Label], tail: Array) -> void:
	await get_tree().create_timer(1.0).timeout
	create_tween().tween_property(_img, "modulate:a", 1.0, 3.0)
	for l in labels:
		create_tween().tween_property(l, "modulate:a", 1.0, 1.2)
		var length := Voice.say(l.text, e.voice)
		await get_tree().create_timer(maxf(2.6, length + 0.6)).timeout
	await get_tree().create_timer(1.2).timeout
	Audio.music(e.music, 3.0)
	for i in tail.size():
		create_tween().tween_property(tail[i], "modulate:a", 1.0, 1.2 if i == 0 else 0.8)
		await get_tree().create_timer(0.9 if i == 0 else 0.4).timeout
	_can_restart = true


func _line(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.modulate.a = 0.0
	parent.add_child(l)
	return l
