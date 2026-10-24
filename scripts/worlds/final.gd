extends Level
## Final mirror room: 4 narrated panels -> Evil You (can't be beaten) -> turn the blade on yourself.
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
	# A huge cracked mirror on the north wall
	var glass := ColorRect.new()
	glass.color = Color(0.55, 0.6, 0.75)
	glass.position = Vector2(706, 40)
	glass.size = Vector2(220, 110)
	glass.z_index = -15
	add_child(glass)
	var shine := ColorRect.new()
	shine.color = Color(1.3, 1.3, 1.5, 0.5)
	shine.position = Vector2(730, 50)
	shine.size = Vector2(16, 90)
	shine.rotation = 0.3
	shine.z_index = -14
	add_child(shine)
	prop("arch_silver", Vector2(816, 170), {"collide": false})
	for x in [120, 400, 1232, 1512]:
		prop("pillar_silver", Vector2(x, 180))
		prop("pillar_broken_silver", Vector2(x, 840))
	for i in 6:
		var l := Sheet.make_light(Color(1.0, 0.15, 0.25), 0.9, 2.2)
		l.position = Vector2(140 + i * 270, 120 + (i % 2) * 650)
		add_child(l)
	var center := Sheet.make_light(Color(0.9, 0.9, 1.0), 0.9, 6.0)
	center.position = Vector2(816, 456)
	add_child(center)


func run() -> void:
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
	focus_camera(evil.global_position, 1.6)
	evil.ready_for_ending.connect(_offer_ending)
	_add_reflection(player)
	_add_reflection(evil)


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
			_self_kill()


func _self_kill() -> void:
	_ending = true
	Events.tutorial_prompt.emit("")
	GameManager.input_locked = true
	evil.frozen = true
	Audio.music("", 0.3)
	ui.letterbox(true)
	camera.set_meta("focus", player.global_position)
	Juice.zoom_punch(0.35)
	Juice.slowmo(0.25)
	Juice.set_screen(0.75, 0.0, 0.6, Color(1, 0.8, 0.8))
	Audio.sfx("sfx_heartbeat", 0.0, 0.0, 0.8)
	# The blade turns inward.
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
	Events.boss_health_changed.emit("YOU", 0.0, 0.0)
	await get_tree().create_timer(3.0, true, false, true).timeout
	GameManager.go_to_scene("ending")
