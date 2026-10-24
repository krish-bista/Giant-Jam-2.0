extends Level
## The heart of the breach: a round mirror floating in the void, where everyone stands on their
## own reflection. Your reflection rises out of the floor, explains what it is, then fights you.
## You can't win by fighting: it grows with every hit. The crack closes only when its maker is gone.
## Divine ending: you turn the blade on yourself. Reflection ending (3+ deaths, or the clock
## running out): it takes your place. The platform's edge reverts to glass as the clock drains.

const P := "res://assets/ninja/"
const CENTER := Vector2(816, 456)
const PLATFORM_R := 330.0
const CLOCK := 70.0
const EVIL_POS := Vector2(1000, 456)

var evil: EvilSelf
var _can_end := false
var _ending := false
var _reflections := {}
var _heart_t := 0.0
var _platform_mat: ShaderMaterial
var _rim: Line2D
var _shards: Array[Polygon2D] = []
var _t := 0.0


func configure() -> void:
	world_size = Vector2(1632, 912)
	ground = ""
	music = ""
	surface = "stone"
	ambient_color = Color(0.86, 0.82, 0.92)
	particles = ""
	spawn_point = Vector2(640, 470)
	camera_follow = false
	vignette = 0.5


func build_world() -> void:
	camera.set_meta("base_zoom", 0.95)
	camera.position = CENTER
	# The void
	var void_bg := ColorRect.new()
	void_bg.color = Color(0.025, 0.02, 0.05)
	void_bg.position = Vector2(-400, -400)
	void_bg.size = world_size + Vector2(800, 800)
	void_bg.z_index = -30
	void_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(void_bg)
	var stars := CPUParticles2D.new()
	stars.amount = 160
	stars.lifetime = 9.0
	stars.preprocess = 9.0
	stars.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	stars.emission_rect_extents = world_size * 0.6
	stars.position = CENTER
	stars.direction = Vector2.UP          # time runs backwards: the dust falls upward
	stars.spread = 10.0
	stars.gravity = Vector2.ZERO
	stars.initial_velocity_min = 6.0
	stars.initial_velocity_max = 22.0
	stars.scale_amount_min = 1.5
	stars.scale_amount_max = 3.5
	stars.color = Color(0.75, 0.85, 1.0, 0.7)
	stars.z_index = -29
	add_child(stars)
	# The platform: a round mirror
	var plat := Sprite2D.new()
	var gt := GradientTexture2D.new()
	gt.width = 256
	gt.height = 256
	gt.gradient = Gradient.new()
	plat.texture = gt
	plat.scale = Vector2.ONE * (PLATFORM_R * 2.0 / 256.0)
	plat.position = CENTER
	plat.z_index = -18
	_platform_mat = ShaderMaterial.new()
	_platform_mat.shader = preload("res://assets/shaders/mirror_floor.gdshader")
	plat.material = _platform_mat
	add_child(plat)
	_rim = Line2D.new()
	var pts := PackedVector2Array()
	for i in 97:
		pts.append(CENTER + Vector2.from_angle(TAU * i / 96.0) * (PLATFORM_R + 2.0))
	_rim.points = pts
	_rim.width = 3.0
	_rim.default_color = Color(0.65, 0.95, 1.0, 0.9)
	_rim.z_index = -17
	add_child(_rim)
	var under := Sheet.make_light(Color(0.6, 0.85, 1.0), 0.8, 7.0)
	under.position = CENTER
	add_child(under)
	# Broken mirror shards drifting around the platform
	for i in 12:
		var sh := Polygon2D.new()
		var sz := randf_range(14.0, 40.0)
		sh.polygon = PackedVector2Array([Vector2(0, -sz), Vector2(sz * randf_range(0.4, 0.9), sz * randf_range(0.2, 0.7)), Vector2(-sz * randf_range(0.4, 0.9), sz * randf_range(0.3, 0.8))])
		sh.color = Color(0.7, 0.86, 1.0, randf_range(0.45, 0.8))
		var a := TAU * i / 12.0 + randf_range(-0.2, 0.2)
		var home := CENTER + Vector2(cos(a) * randf_range(400.0, 600.0), sin(a) * randf_range(370.0, 420.0))
		sh.position = home
		sh.set_meta("home", home)
		sh.set_meta("phase", randf() * TAU)
		sh.rotation = randf() * TAU
		sh.z_index = -26
		add_child(sh)
		_shards.append(sh)
	var red := Sheet.make_light(Color(1.0, 0.2, 0.3), 0.7, 3.0)
	red.position = EVIL_POS
	add_child(red)


func setup_clock_bounds(c: TimeRift) -> void:
	c.setup_circle(CENTER, PLATFORM_R, 205.0)


func run() -> void:
	next_scene = "ending"
	set_objective("")
	if not GameManager.has_flag("seen_final_cutscene"):
		GameManager.flags["seen_final_cutscene"] = true
		await ui.show_panels([
			[P + "cutscenes/final_01.png", "The last fragment shows only you."],
			[P + "cutscenes/final_02.png", "It moves first."],
			[P + "cutscenes/final_03.png", "Everything you took, it took too."],
			[P + "cutscenes/final_04.png", "Only one of you leaves. Neither of you can win."],
		])
	Audio.music("music_final")
	_add_reflection(player)
	evil = EvilSelf.new()
	evil.setup_evil()
	evil.arena = Rect2(CENTER - Vector2.ONE * PLATFORM_R, Vector2.ONE * PLATFORM_R * 2.0)
	evil.global_position = EVIL_POS
	evil.visible = false
	add_child(evil)
	await _rise_from_reflection()
	_add_reflection(evil)
	await wait(0.4)
	if not GameManager.has_flag("heard_reflection"):
		GameManager.flags["heard_reflection"] = true
		await ui.say([
			"Finally. You walked all the way back to me.",
			"I am your reflection. Every enemy you cut down, every artifact you took. I am made of all of it.",
			"You broke time trying to win. The breach feeds on that. It feeds me.",
			"As long as you fight, I grow. You can't outfight yourself.",
		], "Your Reflection", "evil", P + "chars/evil_face.png")
	set_objective("Your reflection grows with every hit...")
	evil.ready_for_ending.connect(_offer_ending)
	evil.begin()
	await wait(1.6)
	if not _ending:
		start_clock(CLOCK)


## Your reflection in the floor peels up out of the glass and stands: Evil You.
func _rise_from_reflection() -> void:
	var ghost := Sprite2D.new()
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var body := _body_of(player)
	if body and body.sprite_frames:
		ghost.texture = body.sprite_frames.get_frame_texture(body.animation, body.frame)
	ghost.flip_h = true
	ghost.global_position = EVIL_POS + Vector2(0, 38)
	ghost.scale = Vector2(3, -3)
	ghost.modulate = Color(1.0, 0.5, 0.55, 0.0)
	ghost.z_index = 5
	add_child(ghost)
	focus_camera(EVIL_POS, 1.6)
	Audio.sfx("sfx_glitch", 0.0, -4.0, 0.7)
	var t := create_tween()
	t.tween_property(ghost, "modulate:a", 0.85, 0.5)
	t.tween_property(ghost, "scale", Vector2(3, 3), 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ghost, "global_position", EVIL_POS, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
	Audio.sfx("sfx_mirror_shatter", 0.0, -4.0, 1.3)
	Juice.flash(Color(1, 0.3, 0.35, 0.4), 0.3)
	Juice.shockwave(EVIL_POS, 0.04, 0.5)
	Juice.fx("circle_spark", EVIL_POS, 3.0, 0.0, Color(2.0, 0.5, 0.6))
	ghost.queue_free()
	evil.visible = true


func _body_of(node: Node) -> AnimatedSprite2D:
	if node == null:
		return null
	var v = node.get("_visual")
	if v is AnimatedSprite2D:
		return v
	var s = node.get("sprite")
	return s if s is AnimatedSprite2D else null


func _add_reflection(node: Node2D) -> void:
	var r := Sprite2D.new()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/mirror_reflection.gdshader")
	m.set_shader_parameter("center", CENTER)
	m.set_shader_parameter("radius", PLATFORM_R)
	m.set_shader_parameter("tint", Color(1.0, 0.55, 0.6) if node is EvilSelf else Color(0.7, 0.92, 1.0))
	r.material = m
	r.z_index = -16
	r.z_as_relative = false
	add_child(r)
	_reflections[node] = r


## Time ran out at the last mirror: the reflection takes your place.
func on_time_up() -> void:
	GameManager.flags["reflection_won"] = true
	_ending = true
	if is_instance_valid(evil):
		evil.frozen = true


func _offer_ending() -> void:
	_can_end = true
	Audio.sfx("sfx_glitch", 0.0, -4.0)
	ui.show_subtitle("The crack closes only when the one who made it is gone.", Color(0.9, 0.9, 1.0))
	var l := Voice.say("The crack closes only when the one who made it is gone.", "stranger")
	await wait(maxf(l, 2.0) + 0.3)
	if _ending:
		return
	set_objective("End the reversal")
	Events.tutorial_prompt.emit("[E] Turn the blade on yourself.")
	Voice.say("[E] Turn the blade on yourself.", "narrator")


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	var lim := PLATFORM_R
	if is_instance_valid(clock):
		lim = clock.radius
		_platform_mat.set_shader_parameter("crack", clock.progress())
		_rim.default_color.a = 0.9 * (1.0 - clock.progress() * 0.7)
	for sh in _shards:
		var home: Vector2 = sh.get_meta("home")
		var ph: float = sh.get_meta("phase")
		sh.position = home + Vector2(0, sin(_t * 0.8 + ph) * 10.0)
		sh.rotation += delta * 0.2 * sin(ph)
	for node in _reflections:
		var r: Sprite2D = _reflections[node]
		if not is_instance_valid(node) or not node.visible:
			r.visible = false
			continue
		var body := _body_of(node)
		if body == null or body.sprite_frames == null:
			continue
		r.visible = true
		r.texture = body.sprite_frames.get_frame_texture(body.animation, body.frame)
		r.global_position = node.global_position + Vector2(0, 38)
		r.scale = Vector2(3, -3)
		r.flip_h = body.flip_h
		(r.material as ShaderMaterial).set_shader_parameter("radius", lim)
	if _can_end and not _ending and not time_is_up():
		_heart_t -= delta
		if _heart_t <= 0.0:
			_heart_t = 1.1
			Audio.sfx("sfx_heartbeat", 0.0, -4.0)
		if player_alive() and Input.is_action_just_pressed("interact"):
			if GameManager.ending_type() == "evil":
				_reflection_wins()
			else:
				_self_kill()


func _begin_end() -> void:
	_ending = true
	if is_instance_valid(clock):
		clock.clear(true)
	Events.tutorial_prompt.emit("")
	set_objective("")
	GameManager.input_locked = true
	revives_here = false
	evil.frozen = true
	Audio.music("", 0.3)
	ui.letterbox(true)
	camera.set_meta("focus", player.global_position)
	Juice.zoom_punch(0.35)


## Divine ending: the blade turns inward. The reflection dies with you.
func _self_kill() -> void:
	_begin_end()
	Juice.slowmo(0.25)
	Juice.set_screen(0.75, 0.0, 0.6, Color(1, 0.8, 0.8))
	Audio.sfx("sfx_heartbeat", 0.0, 0.0, 0.8)
	var rig: PlayerRig = player.rig
	rig.swinging = true
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(rig.sword_pivot, "position", Vector2(0, -40), 0.6)
	tw.parallel().tween_property(rig.sword_pivot, "rotation", PI, 0.9)
	tw.tween_interval(0.5)
	tw.tween_property(rig.sword_pivot, "position", Vector2(0, -6), 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await tw.finished
	Juice.reset_time()
	Audio.sfx("sfx_mirror_shatter", 0.0, 3.0)
	Audio.sfx("sfx_deflect", 0.0, 0.0, 0.5)
	Juice.flash(Color(1, 1, 1, 1.0), 2.0)
	Juice.shake(15.0, 1.0)
	Juice.shockwave(player.global_position, 0.09, 0.9)
	Juice.chroma(0.04)
	Juice.fx("explosion", player.global_position, 4.0, 0.0, Color(2, 2, 2.4))
	Juice.debris(evil.global_position, P + "fx/particle_rockgray.png", 6, 30, Color(1.6, 1.6, 1.9))
	Juice.debris(CENTER, P + "fx/particle_rockgray.png", 6, 40, Color(1.6, 1.6, 1.9))
	player.visible = false
	evil.visible = false
	Events.boss_health_changed.emit("YOUR REFLECTION", 0.0, 0.0)
	await get_tree().create_timer(1.6, true, false, true).timeout
	ui.show_subtitle("A mirror returns what it is given. You gave it everything.", Color(0.95, 0.95, 1.0))
	var l := Voice.say("A mirror returns what it is given. You gave it everything.", "narrator")
	await get_tree().create_timer(maxf(l, 2.5) + 0.8, true, false, true).timeout
	GameManager.go_to_scene("ending")


## Reflection ending: you died too often. It catches your hand and takes your place.
func _reflection_wins() -> void:
	_begin_end()
	Juice.set_screen(0.8, 0.0, 0.5, Color(1.2, 0.7, 0.7))
	var rig: PlayerRig = player.rig
	rig.swinging = true
	var tw := create_tween()
	tw.tween_property(rig.sword_pivot, "rotation", PI * 0.6, 0.5)
	await tw.finished
	evil.frozen = false
	evil.active = false
	var close := create_tween()
	close.tween_property(evil, "global_position", player.global_position + Vector2(48, 0), 0.35)
	await close.finished
	Audio.sfx("sfx_glitch", 0.0, 0.0)
	Juice.chroma(0.03)
	ui.show_subtitle("Too late. You died too many times. There's more of me in you than you.", Color(1, 0.4, 0.4))
	var l := Voice.say("Too late. You died too many times. There's more of me in you than you.", "evil")
	await wait(maxf(l, 3.0) + 0.3)
	evil.rig.swing(player.global_position - evil.global_position, 0)
	Audio.sfx("sfx_hit_heavy", 0.0, 2.0)
	Audio.sfx("sfx_mirror_shatter", 0.0, 0.0, 0.7)
	Juice.flash(Color(1, 0, 0, 0.9), 1.4)
	Juice.shake(14.0, 1.0)
	Juice.fx("explosion", player.global_position, 4.0, 0.0, Color(2.4, 0.6, 0.6))
	player.visible = false
	await wait(1.4)
	var walk := create_tween()
	walk.tween_property(evil, "global_position", CENTER + Vector2(0, -PLATFORM_R + 60.0), 2.0)
	await wait(2.2)
	GameManager.go_to_scene("ending")
