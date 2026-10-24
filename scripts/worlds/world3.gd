extends Level
## THE HOLLOW FUTURE - the world you made. The only grim world: ash, bones, dead light.
## Normal enemies (husks, wraiths, seers, brutes). The terminal tells you the truth.
## Core Sentinel, then: keep fighting, or the final mirror. World weapon: Echo Wand.

const HEART := Vector2(1296, 640)
const WAVES := [
	["husk", "husk", "wraith", "husk"],
	["husk", "wraith", "wraith", "seer", "husk"],
	["hollow_brute", "seer", "seer", "wraith", "husk", "husk"],
]


func configure() -> void:
	world_size = Vector2(2592, 1440)
	ground = "res://assets/ninja/ground/grim.png"
	music = "music_grim"
	boss_music = "music_core_boss"
	ambient = "amb_wind"
	surface = "stone"
	ambient_color = Color(0.82, 0.72, 0.86)
	particles = "ash"
	vignette = 0.55
	desaturate = 0.25
	screen_tint = Color(1.05, 0.92, 0.95)
	spawn_point = Vector2(700, 760)


func build_world() -> void:
	keepout(HEART, 340.0)
	place_weapon("echo_wand", Vector2(2260, 1160))
	border(["grim_tree_dead", "grim_pillar", "grim_rocks_grey", "grim_boulder_grey", "grim_ruin_wall"], 160.0, 1)
	scatter(["grim_tree_dead", "grim_pillar_broken", "grim_statue_orb", "grim_head_statue", "grim_gem_rock"], 22, Rect2(160, 160, 2270, 1120), {}, 24.0)
	scatter(["grim_grave", "grim_crystal_purple"], 40, Rect2(160, 160, 2270, 1120), {"collide": false}, 6.0)
	# Sickly, flickering lights
	for pos in [Vector2(420, 380), Vector2(900, 1180), Vector2(1700, 320), Vector2(2150, 900), Vector2(1300, 260), Vector2(500, 1120), Vector2(1950, 1260)]:
		var l := Sheet.make_light(Color(1.0, 0.25, 0.3) if randf() < 0.5 else Color(0.6, 0.3, 0.9), 1.4, 3.0)
		l.position = pos
		l.set_meta("base", 1.4)
		add_child(l)
		flicker_lights.append(l)
	for c in [Vector2(520, 520), Vector2(2080, 560), Vector2(560, 1000), Vector2(1900, 1020)]:
		crate_cluster(c, ["barrel", "crate", "sack"], 4, 0.3)
	var terminal := add_interactable("res://assets/ninja/props/grim_head_statue.png", Vector2(560, 640), "[E] Read the log", 90.0, 3.0)
	terminal.glow = true
	terminal.light_color = Color(1.0, 0.3, 0.35)
	terminal.used.connect(_read_terminal)
	lore(Vector2(1700, 1100), "They crossed time to escape this. In your story, they became the invaders.")
	lore(Vector2(1000, 300), "Every mirror here faces the past.")


func run() -> void:
	title_card("THE HOLLOW FUTURE", "The world you made.", "The Hollow Future. The world you made.")
	await wait(4.2)
	summon_ally()
	await wait(2.0)
	say_line("This is what's left. This is what I did.", "you", Color(0.9, 0.75, 0.8))
	set_objective("Read the refugee log (the stone head)")
	await wait(3.0)

	for i in WAVES.size():
		set_objective("Survive the hollow (%d / %d)" % [i + 1, WAVES.size()])
		Events.announce.emit("WAVE %d" % (i + 1))
		await wait(1.0)
		for id in WAVES[i]:
			spawn(id, edge_point())
			await wait(0.5)
		await wait_clear()
		await wait(2.0)

	say_line("Something waits at the heart of this place.", "you", Color(0.9, 0.75, 0.8))
	set_objective("Go to the heart of the breach")
	objective = _marker(HEART)
	while is_instance_valid(player) and player.global_position.distance_to(HEART) > 400.0:
		await wait(0.3)
	objective = null
	set_objective("Defeat the Core Sentinel")
	var sentinel := spawn_boss("sentinel", HEART + Vector2(260, -160))
	await sentinel.died
	await wait_clear()
	await wait(2.0)
	say_line("The last fragment is waiting.", "you", Color(1, 0.75, 0.8))
	var portal := add_portal("final", HEART, true)
	portal.activate()
	set_objective("Step into the last mirror")
	var keep := add_interactable("res://assets/ninja/props/grim_statue_orb.png", HEART + Vector2(0, 260), "[E] Keep fighting", 80.0, 3.0)
	keep.light_color = Color(1.0, 0.3, 0.35)
	keep.used.connect(func():
		keep.enabled = false
		for id in WAVES[1]:
			spawn(id, edge_point())
		await wait_clear()
		keep.enabled = true)


func _read_terminal() -> void:
	await ui.say([
		"REFUGEE LOG 0417",
		"The breach opened here. The one who made it carried a mirror.",
		"We fled into the past. To them, we look like invaders.",
		"His reflection never left. It waits at the heart of the breach.",
	], "Refugee Log", "terminal", "res://assets/ninja/enemies/robot_face.png")


func _marker(pos: Vector2) -> Node2D:
	var m := Node2D.new()
	m.position = pos
	add_child(m)
	return m
