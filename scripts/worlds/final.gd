extends Level
## Final mirror room: 4 cutscene panels -> Evil You (can't be beaten) -> turn the blade on yourself.

var evil: EvilSelf
var _can_end := false
var _ending := false


func configure() -> void:
	background = "res://assets/tiles/mirror_bg.png"
	music = ""
	spawn_point = Vector2(400, 360)


func run() -> void:
	if not GameManager.has_flag("seen_final_cutscene"):
		GameManager.flags["seen_final_cutscene"] = true
		await ui.show_panels([
			["res://assets/cutscenes/cut_final_01.png", "The last fragment shows only you."],
			["res://assets/cutscenes/cut_final_02.png", "It moves first."],
			["res://assets/cutscenes/cut_final_03.png", "Everything you took, it took too."],
			["res://assets/cutscenes/cut_final_04.png", "Only one of you leaves. Neither of you can win."],
		])
	Audio.music("music_final")
	evil = EvilSelf.new()
	evil.setup_evil()
	evil.arena = ARENA
	evil.global_position = Vector2(880, 360)
	add_child(evil)
	evil.ready_for_ending.connect(_offer_ending)


func _offer_ending() -> void:
	_can_end = true
	Audio.sfx("sfx_glitch", 0.0, -4.0)
	prompt("[E] Turn the blade on yourself.")


func _process(_delta: float) -> void:
	if _can_end and not _ending and player_alive() and Input.is_action_just_pressed("interact"):
		_self_kill()


func _self_kill() -> void:
	_ending = true
	prompt("")
	GameManager.input_locked = true
	evil.frozen = true
	Audio.music("", 0.3)
	Juice.slowmo(0.25)
	# The blade turns inward: a slow arc around the player.
	var arc := Line2D.new()
	arc.width = 6.0
	arc.default_color = Color(0.85, 1.0, 1.0)
	arc.z_index = 30
	player.add_child(arc)
	var start: float = player.facing_direction.angle()
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_method(func(t: float):
		arc.clear_points()
		for i in 12:
			var a: float = start + PI * t * float(i) / 11.0
			arc.add_point(Vector2.RIGHT.rotated(a) * (30.0 - 26.0 * t * float(i) / 11.0)), 0.0, 1.0, 1.4)
	await tw.finished
	Juice.reset_time()
	Audio.sfx("sfx_mirror_shatter", 0.0, 2.0)
	Juice.flash(Color(1, 1, 1, 1.0), 1.6)
	Juice.shake(14.0, 1.0)
	Juice.burst(player.global_position, Color(0.8, 1, 1), 40, 300.0, 4.0)
	Juice.burst(evil.global_position, Color(1, 0.25, 0.3), 60, 380.0, 5.0)
	Juice.burst(Vector2(640, 360), Color(0.85, 0.85, 0.95), 80, 500.0, 3.0)
	player.visible = false
	evil.visible = false
	Events.boss_health_changed.emit("YOU", 0.0, 0.0)
	await get_tree().create_timer(2.5, true, false, true).timeout
	GameManager.go_to_scene("ending")
