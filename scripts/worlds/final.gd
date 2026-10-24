extends Level
## The heart of the breach. Your reflection explains what it is, then fights you.
## You can't win by fighting: it grows with every hit. The crack closes only when its maker is gone.
## Divine ending: you turn the blade on yourself. Reflection ending (3+ deaths): it stops your hand.
## The floor is a mirror: everyone has a reflection underneath them.

const P := "res://assets/ninja/"

var evil: EvilSelf
var _can_end := false
var _ending := false
var _reflections := {}
var _heart_t := 0.0


func configure() -> void:
	world_size = Vector2(1632, 912)
	ground = P + "ground/final.png"
	music = ""
	surface = "stone"
	ambient_color = Color(0.74, 0.66, 0.72)
	particles = "dust"
	spawn_point = Vector2(500, 520)
	vignette = 0.5


func build_world() -> void:
	# The last mirror, huge, on the north wall
	var mirror := Sprite2D.new()
	mirror.texture = load(P + "props/mirror_portal_final.png")
	mirror.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mirror.scale = Vector2(4.0, 3.0)
	mirror.position = Vector2(816, 230)
	mirror.z_index = -15
	var mm := ShaderMaterial.new()
	mm.shader = preload("res://assets/shaders/mirror_shield.gdshader")
	mirror.material = mm
	add_child(mirror)
	for x in [120, 400, 1232, 1512]:
		prop("pillar_silver", Vector2(x, 200))
		prop("pillar_broken_silver", Vector2(x, 840))
	for i in 6:
		var l := Sheet.make_light(Color(1.0, 0.15, 0.25), 0.9, 2.2)
		l.position = Vector2(140 + i * 270, 120 + (i % 2) * 650)
		add_child(l)
	var center := Sheet.make_light(Color(0.9, 0.9, 1.0), 0.9, 6.0)
	center.position = Vector2(816, 456)
	add_child(center)


func run() -> void:
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
	evil = EvilSelf.new()
	evil.setup_evil()
	evil.arena = ARENA
	evil.global_position = Vector2(1130, 456)
	add_child(evil)
	_add_reflection(player)
	_add_reflection(evil)
	focus_camera(evil.global_position, 1.2)
	await wait(0.6)
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


func _add_reflection(node: Node2D) -> void:
	var r := Sprite2D.new()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.modulate = Color(1, 1, 1, 0.22)
	r.z_index = -5
	add_child(r)
	_reflections[node] = r


func _offer_ending() -> void:
	_can_end = true
	Audio.sfx("sfx_glitch", 0.0, -4.0)
	ui.show_subtitle("The crack closes only when the one who made it is gone.", Color(0.9, 0.9, 1.0))
	var l := Voice.say("The crack closes only when the one who made it is gone.", "stranger")
	await wait(maxf(l, 2.0) + 0.3)
	set_objective("End the reversal")
	Events.tutorial_prompt.emit("[E] Turn the blade on yourself.")
	Voice.say("[E] Turn the blade on yourself.", "narrator")


func _process(delta: float) -> void:
	super._process(delta)
	for node in _reflections:
		var r: Sprite2D = _reflections[node]
		if not is_instance_valid(node) or not node.visible:
			r.visible = false
			continue
		var body: AnimatedSprite2D = node.get("_visual") if node.get("_visual") is AnimatedSprite2D else node.get("sprite")
		if body == null or body.sprite_frames == null:
			continue
		r.visible = true
		r.texture = body.sprite_frames.get_frame_texture(body.animation, body.frame)
		r.global_position = node.global_position + Vector2(0, 38)
		r.scale = Vector2(3, -3)
		r.flip_h = body.flip_h
	if _can_end and not _ending:
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
	Juice.debris(Vector2(816, 456), P + "fx/particle_rockgray.png", 6, 40, Color(1.6, 1.6, 1.9))
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
	walk.tween_property(evil, "global_position", Vector2(816, 220), 2.0)
	await wait(2.2)
	GameManager.go_to_scene("ending")
