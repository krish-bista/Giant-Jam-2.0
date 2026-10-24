extends Level
## Far-future alien core: constructs mirror your movement across the center line.
## The twist is on a terminal by the entrance. Core Sentinel. Then: keep fighting, or the final fragment.

var _offsets := [Vector2(0, -90), Vector2(0, 90), Vector2(0, 0), Vector2(0, -180), Vector2(0, 180)]
var center_x := 1296.0


func configure() -> void:
	world_size = Vector2(2592, 1440)
	ground = "res://assets/ninja/ground/core.png"
	music = "music_core"
	boss_music = "music_core_boss"
	ambient = "amb_hum"
	surface = "stone"
	ambient_color = Color(0.66, 0.6, 0.86)
	particles = "sparks"
	spawn_point = Vector2(980, 720)


func build_world() -> void:
	center_x = world_size.x * 0.5
	keepout(Vector2(center_x, 720), 420.0)
	# The mirror line glows
	var seam := Line2D.new()
	seam.points = PackedVector2Array([Vector2(center_x, 0), Vector2(center_x, world_size.y)])
	seam.width = 3.0
	seam.default_color = Color(1.5, 0.5, 1.5)
	seam.z_index = -10
	add_child(seam)
	for y in range(120, int(world_size.y), 260):
		var l := Sheet.make_light(Color(1.0, 0.35, 0.95), 0.5, 1.6)
		l.position = Vector2(center_x, y)
		add_child(l)
	# Crystal towers and alien stone
	for p in [Vector2(300, 260), Vector2(700, 200), Vector2(1900, 230), Vector2(2300, 300), Vector2(320, 1200), Vector2(760, 1250), Vector2(1850, 1230), Vector2(2280, 1180)]:
		prop("crystal_tower_%d" % (randi() % 3), p, {"light": Color(0.75, 0.35, 1.0), "energy": 1.3, "light_scale": 2.6})
	prop("arch_core", Vector2(700, 760))
	border(["pillar_core", "gem_rock_core", "statue_orb_core", "pillar_broken_core"], 170.0, 1)
	scatter(["gem_rock_core", "pillar_broken_core", "pillar_core", "statue_orb_core"], 14, Rect2(160, 160, 2270, 1120))
	scatter(["crystal_purple", "crystal_blue"], 40, Rect2(160, 160, 2270, 1120), {"collide": false, "light": Color(0.7, 0.4, 1.0), "energy": 0.5, "light_scale": 0.7}, 4.0)
	for c in [Vector2(480, 520), Vector2(2100, 560), Vector2(500, 980), Vector2(2080, 980)]:
		for i in 4:
			breakable("crystal" if i % 2 == 0 else "crystal_blue", c + Vector2(randf_range(-60, 60), randf_range(-40, 40)))
	var terminal := add_interactable("res://assets/ninja/props/head_statue_core.png", Vector2(760, 600), "[E] Read", 90.0, 3.0)
	terminal.glow = true
	terminal.light_color = Color(0.8, 0.4, 1.0)
	terminal.used.connect(_read_terminal)
	lore(Vector2(1700, 420), "Every mirror here faces the past.")


func run() -> void:
	say_line("They move as you move.", "you", Color(0.9, 0.75, 1.0))
	await wait(2.5)
	await _mirror_wave(3)
	await wait(1.5)
	await _mirror_wave(4)
	await wait(1.5)

	var sentinel := spawn_boss("sentinel", Vector2(center_x + 300, 500))
	await sentinel.died
	await wait_clear()
	await wait(2.0)
	say_line("The last fragment is waiting.", "you", Color(1, 0.75, 0.8))
	var portal := add_portal("final", Vector2(center_x, 640), true)
	portal.activate()
	var keep := add_interactable("res://assets/ninja/props/statue_orb_core.png", Vector2(center_x, 900), "[E] Keep fighting", 80.0, 3.0)
	keep.light_color = Color(0.8, 0.3, 1.0)
	keep.used.connect(func():
		keep.enabled = false
		await _mirror_wave(4)
		keep.enabled = true)


func _mirror_wave(count: int) -> void:
	for i in count:
		var off: Vector2 = _offsets[i % _offsets.size()]
		var p := Vector2(2.0 * center_x - player.global_position.x, player.global_position.y) + off
		var e := spawn("construct", p.clamp(ARENA.position, ARENA.end))
		e.mirror_offset = off
		await wait(0.25)
	await wait(3.0)
	if not alive.is_empty():
		say_line("Make them strike each other.", "you", Color(0.9, 0.75, 1.0))
	await wait_clear()


func _read_terminal() -> void:
	await ui.say(["REFUGEE LOG 0417", "We crossed time to escape the future he made."], "Terminal", "terminal", "res://assets/ninja/enemies/robot_face.png")
