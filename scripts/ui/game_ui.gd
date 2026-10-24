class_name GameUI
extends CanvasLayer
## Everything on screen that isn't the HUD: voiced dialogue with portraits, subtitles, boss banner,
## announcements, combo counter, artifact popup, objective arrow, letterbox, cutscene panels,
## game over and pause. Built in code; one per level.

signal _advance

const FONT := preload("res://assets/ninja/ui/font.tres")
const N := "res://assets/ninja/"

var hud: CanvasLayer
var prompt_ui: CanvasLayer

var _dlg: PanelContainer
var _dlg_face: TextureRect
var _dlg_name: Label
var _dlg_text: Label
var _dlg_active := false
var _typing: Tween
var _subtitle: Label
var _sub_tween: Tween
var _announce: Label
var _ann_tween: Tween
var _banner: Label
var _banner_line: Label
var _popup: PanelContainer
var _popup_icon: TextureRect
var _popup_name: Label
var _popup_desc: Label
var _popup_tween: Tween
var _cut_root: Control
var _cut_img: TextureRect
var _cut_text: Label
var _cut_active := false
var _cut_index := 0
var _over: Control
var _over_ready := false
var _pause: Control
var _combo_root: Control
var _combo_num: Label
var _combo_word: Label
var _combo_bar: ColorRect
var _combo_shown := 0
var _bars: Array[ColorRect] = []
var _arrow: Polygon2D


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud = load("res://scenes/ui/hud.tscn").instantiate()
	hud.layer = 10
	add_sibling.call_deferred(hud)
	prompt_ui = load("res://scenes/ui/tutorial_prompt.tscn").instantiate()
	prompt_ui.layer = 11
	add_sibling.call_deferred(prompt_ui)
	_build()
	Events.subtitle.connect(show_subtitle)
	Events.announce.connect(announce)
	Events.boss_intro.connect(_on_boss_intro)
	Events.artifact_picked.connect(_on_artifact)
	Events.player_died.connect(_on_player_died)
	Events.combo_changed.connect(_on_combo)
	Events.ability_unlocked.connect(func(a): if is_instance_valid(hud): hud.unlock_ability(a))
	Events.dialogue_requested.connect(func(lines): say(lines))
	_setup_hud.call_deferred()


func _setup_hud() -> void:
	await get_tree().process_frame
	if not is_instance_valid(hud):
		return
	var slots: HBoxContainer = hud.get_node("Abilities")
	slots.get_node("Sword").visible = GameManager.has_sword
	slots.get_node("Shield").visible = GameManager.has_shield
	slots.get_node("Hypno").visible = GameManager.hypno_unlocked
	hud.set_player_health(GameManager.health, GameManager.stats.max_health, true)


func _label(size: int, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel_style(border: Color, alpha := 0.88) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.03, 0.04, 0.08, alpha)
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(8)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 8
	s.content_margin_left = 16
	s.content_margin_right = 20
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


func _build() -> void:
	# Letterbox bars
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.size = Vector2(1280, 0)
		bar.position = Vector2(0, 0 if i == 0 else 720)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		_bars.append(bar)

	# Dialogue box with portrait
	_dlg = PanelContainer.new()
	_dlg.add_theme_stylebox_override("panel", _panel_style(Color(0.7, 0.92, 1.0)))
	_dlg.position = Vector2(170, 520)
	_dlg.custom_minimum_size = Vector2(940, 150)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	_dlg.add_child(h)
	var face_frame := PanelContainer.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.12, 0.14, 0.22)
	fs.border_color = Color(0.9, 0.8, 0.5)
	fs.set_border_width_all(3)
	fs.set_corner_radius_all(6)
	face_frame.add_theme_stylebox_override("panel", fs)
	_dlg_face = TextureRect.new()
	_dlg_face.custom_minimum_size = Vector2(114, 114)
	_dlg_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dlg_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dlg_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face_frame.add_child(_dlg_face)
	h.add_child(face_frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	_dlg_name = _label(20, Color(0.6, 0.95, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	v.add_child(_dlg_name)
	_dlg_text = _label(24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_text.custom_minimum_size = Vector2(760, 70)
	_dlg_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	v.add_child(_dlg_text)
	var hint := _label(14, Color(0.6, 0.65, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)
	hint.text = "[E] next"
	v.add_child(hint)
	_dlg.visible = false
	add_child(_dlg)

	_subtitle = _label(24, Color(1, 0.8, 0.8))
	_subtitle.position = Vector2(90, 150)
	_subtitle.size = Vector2(1100, 44)
	_subtitle.modulate.a = 0.0
	add_child(_subtitle)

	_announce = _label(48, Color(1, 1, 1))
	_announce.position = Vector2(0, 250)
	_announce.size = Vector2(1280, 80)
	_announce.pivot_offset = Vector2(640, 40)
	_announce.modulate.a = 0.0
	add_child(_announce)

	_banner = _label(72, Color(1, 0.35, 0.4))
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.position = Vector2(0, 190)
	_banner.size = Vector2(1280, 100)
	_banner.pivot_offset = Vector2(640, 50)
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner_line = _label(26, Color(1, 0.88, 0.88))
	_banner_line.position = Vector2(0, 292)
	_banner_line.size = Vector2(1280, 40)
	_banner_line.modulate.a = 0.0
	add_child(_banner_line)

	# Combo counter (right side)
	_combo_root = Control.new()
	_combo_root.position = Vector2(1080, 250)
	_combo_root.modulate.a = 0.0
	add_child(_combo_root)
	_combo_num = _label(56, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_combo_num.size = Vector2(170, 60)
	_combo_num.pivot_offset = Vector2(150, 30)
	_combo_root.add_child(_combo_num)
	_combo_word = _label(18, Color(0.85, 0.9, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	_combo_word.position = Vector2(0, 58)
	_combo_word.size = Vector2(170, 24)
	_combo_word.text = "COMBO"
	_combo_root.add_child(_combo_word)
	_combo_bar = ColorRect.new()
	_combo_bar.position = Vector2(30, 86)
	_combo_bar.size = Vector2(140, 5)
	_combo_root.add_child(_combo_bar)

	# Objective arrow
	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([Vector2(18, 0), Vector2(-10, -12), Vector2(-4, 0), Vector2(-10, 12)])
	_arrow.color = Color(1.0, 0.95, 0.6)
	_arrow.visible = false
	add_child(_arrow)

	# Artifact popup (top right)
	_popup = PanelContainer.new()
	_popup.add_theme_stylebox_override("panel", _panel_style(Color(1, 0.85, 0.4)))
	_popup.position = Vector2(1290, 70)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 12)
	_popup.add_child(ph)
	_popup_icon = TextureRect.new()
	_popup_icon.custom_minimum_size = Vector2(56, 56)
	_popup_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_popup_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ph.add_child(_popup_icon)
	var pv := VBoxContainer.new()
	ph.add_child(pv)
	_popup_name = _label(20, Color(1, 0.9, 0.5), HORIZONTAL_ALIGNMENT_LEFT)
	pv.add_child(_popup_name)
	_popup_desc = _label(16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	pv.add_child(_popup_desc)
	add_child(_popup)

	# Cutscene panels
	_cut_root = Control.new()
	_cut_root.size = Vector2(1280, 720)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(1280, 720)
	_cut_root.add_child(black)
	_cut_img = TextureRect.new()
	_cut_img.size = Vector2(1280, 720)
	_cut_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cut_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cut_root.add_child(_cut_img)
	_cut_text = _label(32, Color(0.95, 0.95, 1.0))
	_cut_text.position = Vector2(0, 640)
	_cut_text.size = Vector2(1280, 50)
	_cut_root.add_child(_cut_text)
	_cut_root.visible = false
	add_child(_cut_root)

	# Game over
	_over = Control.new()
	_over.size = Vector2(1280, 720)
	var dark := ColorRect.new()
	dark.color = Color(0.05, 0, 0.02, 0.8)
	dark.size = Vector2(1280, 720)
	_over.add_child(dark)
	var t1 := _label(64, Color(1, 0.4, 0.45))
	t1.text = "The echo fades."
	t1.position = Vector2(0, 270)
	t1.size = Vector2(1280, 80)
	_over.add_child(t1)
	var t2 := _label(22, Color(0.85, 0.85, 0.9))
	t2.text = "[E] Try again"
	t2.position = Vector2(0, 370)
	t2.size = Vector2(1280, 40)
	_over.add_child(t2)
	_over.visible = false
	add_child(_over)

	# Pause
	_pause = Control.new()
	_pause.size = Vector2(1280, 720)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.size = Vector2(1280, 720)
	_pause.add_child(dim)
	var pt := _label(56)
	pt.text = "PAUSED"
	pt.position = Vector2(0, 250)
	pt.size = Vector2(1280, 70)
	_pause.add_child(pt)
	var pk := _label(20, Color(0.8, 0.85, 0.95))
	pk.text = "[Esc] Resume\n\nWASD move   Space dash   Left click sword (x3 = spin)\nHold right click: Mirror Shield. Block right as a hit lands to REFLECT it.\nQ Hypno Reverse   E interact"
	pk.position = Vector2(0, 340)
	pk.size = Vector2(1280, 160)
	_pause.add_child(pk)
	_pause.visible = false
	add_child(_pause)


func _process(_delta: float) -> void:
	if GameManager.combo > 0:
		_combo_bar.size.x = 140.0 * clampf(GameManager._combo_timer / GameManager.COMBO_WINDOW, 0.0, 1.0)
	_update_arrow()


func _update_arrow() -> void:
	var level := get_parent() as Level
	if level == null or not is_instance_valid(level.objective) or not level.objective.visible:
		_arrow.visible = false
		return
	var vp := get_viewport()
	var screen := vp.get_canvas_transform() * level.objective.global_position
	var rect := Rect2(Vector2(60, 60), Vector2(1160, 600))
	if rect.has_point(screen):
		_arrow.visible = false
		return
	var center := Vector2(640, 360)
	var dir := (screen - center).normalized()
	var t := INF
	if dir.x != 0.0:
		t = minf(t, ((rect.end.x if dir.x > 0 else rect.position.x) - center.x) / dir.x)
	if dir.y != 0.0:
		t = minf(t, ((rect.end.y if dir.y > 0 else rect.position.y) - center.y) / dir.y)
	_arrow.position = center + dir * t
	_arrow.rotation = dir.angle()
	_arrow.scale = Vector2.ONE * (1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.008))
	_arrow.visible = true


func _unhandled_input(event: InputEvent) -> void:
	var advance := event.is_action_pressed("interact") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept")
	if (_dlg_active or _cut_active) and advance:
		get_viewport().set_input_as_handled()
		_advance.emit()
		return
	if _over.visible and _over_ready and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_over_ready = false
		GameManager.retry_scene()
		return
	if event.is_action_pressed("pause") and not _over.visible and not _cut_active:
		get_tree().paused = not get_tree().paused
		_pause.visible = get_tree().paused


func letterbox(on: bool) -> void:
	for i in 2:
		var bar := _bars[i]
		var t := create_tween()
		t.tween_property(bar, "size:y", 70.0 if on else 0.0, 0.35)
		if i == 1:
			t.parallel().tween_property(bar, "position:y", 650.0 if on else 720.0, 0.35)


## Voiced dialogue. Usage: await ui.say(["Hello.", "Put this on."], "Stranger", "stranger", face_path)
## Each line plays its recording; it moves on by itself after the voice ends, or on [E].
func say(lines: Array, speaker := "", voice := "", face := "") -> void:
	GameManager.input_locked = true
	_dlg_active = true
	_dlg.visible = true
	_dlg_name.text = speaker
	_dlg_name.visible = speaker != ""
	_dlg_face.get_parent().visible = face != ""
	if face != "":
		_dlg_face.texture = load(face)
	_dlg.modulate.a = 0.0
	create_tween().tween_property(_dlg, "modulate:a", 1.0, 0.15)
	for line in lines:
		var text := str(line)
		_dlg_text.text = text
		_dlg_text.visible_ratio = 0.0
		if is_instance_valid(_typing):
			_typing.kill()
		_typing = create_tween()
		_typing.tween_property(_dlg_text, "visible_ratio", 1.0, 0.025 * text.length())
		var length := Voice.say(text, voice) if voice != "" else 0.0
		if length <= 0.0:
			Audio.sfx("sfx_dialogue", 0.1, -10.0)
		var auto := maxf(length + 0.9, 0.025 * text.length() + 1.6)
		_cut_index += 1
		var idx := _cut_index
		get_tree().create_timer(auto).timeout.connect(func(): if _dlg_active and _cut_index == idx: _advance.emit())
		await _advance
		if _dlg_text.visible_ratio < 1.0:
			_typing.kill()
			_dlg_text.visible_ratio = 1.0
			await _advance
	Voice.stop()
	_dlg.visible = false
	_dlg_active = false
	await get_tree().create_timer(0.2).timeout
	GameManager.input_locked = false


## Full-screen static panels with a narrated caption.
func show_panels(panels: Array) -> void:
	GameManager.input_locked = true
	_cut_active = true
	_cut_root.visible = true
	letterbox(true)
	for entry in panels:
		_cut_img.texture = load(entry[0])
		_cut_text.text = entry[1]
		_cut_root.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(_cut_root, "modulate:a", 1.0, 0.4)
		var length := Voice.say(entry[1], "narrator")
		_cut_index += 1
		var idx := _cut_index
		get_tree().create_timer(maxf(3.5, length + 1.0)).timeout.connect(func(): if _cut_active and _cut_index == idx: _advance.emit())
		await _advance
		await get_tree().create_timer(0.15).timeout
	var out := create_tween()
	out.tween_property(_cut_root, "modulate:a", 0.0, 0.4)
	await out.finished
	_cut_root.visible = false
	_cut_active = false
	letterbox(false)
	GameManager.input_locked = false


func show_subtitle(text: String, color := Color(1, 0.8, 0.8)) -> void:
	_subtitle.text = text
	_subtitle.add_theme_color_override("font_color", color)
	if is_instance_valid(_sub_tween):
		_sub_tween.kill()
	_sub_tween = create_tween()
	_sub_tween.tween_property(_subtitle, "modulate:a", 1.0, 0.2)
	_sub_tween.tween_interval(maxf(2.4, text.length() * 0.07))
	_sub_tween.tween_property(_subtitle, "modulate:a", 0.0, 0.5)


func announce(text: String) -> void:
	_announce.text = text
	if is_instance_valid(_ann_tween):
		_ann_tween.kill()
	_announce.scale = Vector2(1.5, 1.5)
	_announce.modulate.a = 0.0
	_ann_tween = create_tween()
	_ann_tween.set_parallel(true)
	_ann_tween.tween_property(_announce, "modulate:a", 1.0, 0.15)
	_ann_tween.tween_property(_announce, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	_ann_tween.chain().tween_interval(1.4)
	_ann_tween.chain().tween_property(_announce, "modulate:a", 0.0, 0.4)


func _on_combo(count: int) -> void:
	if count <= 0:
		if _combo_shown > 0:
			var t := create_tween()
			t.tween_property(_combo_root, "modulate:a", 0.0, 0.3)
		_combo_shown = 0
		return
	_combo_shown = count
	_combo_num.text = "%d" % count
	var col := Color.WHITE
	var word := "COMBO"
	if count >= 50:
		col = Color(1, 0.85, 0.3)
		word = "REVERSAL!"
	elif count >= 25:
		col = Color(1, 0.4, 0.9)
		word = "BRUTAL"
	elif count >= 10:
		col = Color(0.5, 1, 1)
		word = "NICE"
	_combo_num.add_theme_color_override("font_color", col)
	_combo_bar.color = col
	_combo_word.text = word
	_combo_root.modulate.a = 1.0
	_combo_num.scale = Vector2(1.35, 1.35)
	create_tween().tween_property(_combo_num, "scale", Vector2.ONE, 0.15)


func _on_boss_intro(boss_name: String, line: String) -> void:
	_banner.text = boss_name
	_banner_line.text = line
	_banner.scale = Vector2(1.6, 1.6)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_banner, "modulate:a", 1.0, 0.25)
	t.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_banner_line, "modulate:a", 1.0, 0.3).set_delay(0.3)
	t.chain().tween_interval(2.2)
	t.chain().tween_property(_banner, "modulate:a", 0.0, 0.5)
	t.parallel().tween_property(_banner_line, "modulate:a", 0.0, 0.5)


func _on_artifact(info: Dictionary) -> void:
	_popup_icon.texture = load(ArtifactData.icon_path(info.id))
	_popup_name.text = info.name
	_popup_desc.text = info.desc
	Audio.sfx("sfx_artifact", 0.0, -3.0)
	if is_instance_valid(_popup_tween):
		_popup_tween.kill()
	_popup.position.x = 1290
	_popup_tween = create_tween()
	_popup_tween.tween_property(_popup, "position:x", 1280 - _popup.size.x - 20, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_popup_tween.tween_interval(2.8)
	_popup_tween.tween_property(_popup, "position:x", 1290, 0.3)


func _on_player_died() -> void:
	Audio.music("", 1.0)
	Juice.set_screen(0.6, 0.0, 0.8, Color(1, 0.85, 0.85))
	await get_tree().create_timer(1.2).timeout
	_over.visible = true
	_over.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_over, "modulate:a", 1.0, 0.5)
	await t.finished
	_over_ready = true
