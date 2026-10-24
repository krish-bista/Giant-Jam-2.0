extends Level
## THE HOLLOW FUTURE - the world you made. The only grim world: ash, bones, dead light.
## Normal enemies (husks, wraiths, seers, brutes). The terminal tells you the truth.
## Two waves -> Core Sentinel, against a 1:40 clock. Then: keep fighting, or the final mirror.
## World weapon: Echo Wand.

const HEART := CityLayout.PLAZA     # the center: the mirror opens here
const CLOCK := 100.0
var _terminal: Interactable
const WAVES := [
	["husk", "husk", "wraith", "seer", "husk"],
	["hollow_brute", "seer", "wraith", "husk", "seer", "wraith"],
]


func configure() -> void:
	world_size = Vector2(2592, 1440)
	arena_override = Rect2(70, 190, 2452, 1120)
	ground = "res://assets/ninja/ground/grim.png"
	music = "music_grim"
	boss_music = "music_core_boss"
	ambient = "amb_wind"
	surface = "stone"
	ambient_color = Color(0.86, 0.8, 0.82)
	particles = "ash"
	vignette = 0.55
	desaturate = 0.2
	screen_tint = Color(1.04, 0.95, 0.94)
	# The city reflected: you come in through the east gate this time.
	spawn_point = Vector2(2290, 720)


func build_world() -> void:
	keepout(Vector2(spawn_point.x - 200, 720), 120.0)
	CityLayout.build(self, true)
	# Where the refugee camp was, there are only graves now (mirrored to the south-east).
	for pos in [Vector2(2040, 1010), Vector2(2110, 1040), Vector2(2180, 1010), Vector2(2250, 1040), Vector2(2320, 1010),
			Vector2(2075, 1110), Vector2(2145, 1140), Vector2(2215, 1110), Vector2(2285, 1140)]:
		prop("grim_grave", pos, {"collide": false})
	prop("grim_tent_torn", Vector2(2180, 1196), {"flip": true})
	# The crack bleeds through the plaza: crystals grow out of it
	for off in [Vector2(-150, -40), Vector2(160, 30), Vector2(-60, 150), Vector2(90, -150), Vector2(200, 160), Vector2(-210, 120)]:
		prop("grim_crystal_purple", HEART + off, {"collide": false, "light": Color(1.0, 0.25, 0.3), "energy": 0.5, "light_scale": 0.8})
	# Dead red light where the street lamps were
	for pos in [Vector2(2392, 600), Vector2(1532, 520), Vector2(1060, 520), Vector2(532, 600), Vector2(697, 862), Vector2(1897, 862), Vector2(1296, 1000)]:
		var l := Sheet.make_light(Color(1.0, 0.28, 0.32), 1.2, 2.6)
		l.position = pos + Vector2(0, -60)
		l.set_meta("base", 1.2)
		add_child(l)
		flicker_lights.append(l)
	for c in [Vector2(1290, 1150), Vector2(210, 420)]:
		crate_cluster(c, ["barrel", "crate", "sack"], 3, 0.3)
	for pos in [Vector2(1010, 940), Vector2(830, 1220), Vector2(540, 1210)]:
		breakable("explosive", pos)
	_terminal = add_interactable("res://assets/ninja/props/grim_head_statue.png", Vector2(2150, 470), "[E] Read the log", 90.0, 3.0)
	_terminal.glow = true
	_terminal.light_color = Color(1.0, 0.3, 0.35)
	_terminal.used.connect(_read_terminal)
	lore(Vector2(2000, 1196), "They crossed time to escape this. In your story, they became the invaders.")
	lore(Vector2(2150, 362), "This street... it's the city. Reflected, and rotted.")
	place_weapon("echo_wand", Vector2(1482, 1110))


func run() -> void:
	next_scene = "final"
	var nl := title_card("THE HOLLOW FUTURE", "The world you made.", "The Hollow Future. The world you made. Here, the hero is the cause.", "REVERSAL: The hero is the cause.")
	await wait(maxf(2.6, nl + 0.2))
	start_clock(CLOCK)
	summon_ally()
	await wait(1.4)
	say_line("This is what's left... This is what I did.", "you", Color(0.9, 0.75, 0.8))
	set_objective("Read the refugee log (the stone head)")
	objective = _terminal
	await wait(2.0)

	for i in WAVES.size():
		set_objective("Survive the hollow (%d / %d)" % [i + 1, WAVES.size()])
		Events.announce.emit("WAVE %d" % (i + 1))
		await wait(0.6)
		for id in WAVES[i]:
			spawn(id, edge_point())
			await wait(0.35)
		await wait_clear()
		await wait(0.8)

	say_line("Something's waiting at the heart of this place.", "you", Color(0.9, 0.75, 0.8))
	set_objective("Go to the heart of the breach")
	objective = _marker(HEART)
	while is_instance_valid(player) and player.global_position.distance_to(HEART) > 420.0:
		await wait(0.3)
	objective = null
	set_objective("Defeat the Core Sentinel")
	var sentinel := spawn_boss("sentinel", HEART + Vector2(260, -160))
	await sentinel.died
	world_cleared()
	await wait(1.2)
	say_line("The last fragment... It's waiting for me.", "you", Color(1, 0.75, 0.8))
	var portal := add_portal(next_scene, HEART, true)
	portal.activate()
	set_objective("Step into the last mirror")
	var keep := add_interactable("res://assets/ninja/props/grim_statue_orb.png", HEART + Vector2(0, 230), "[E] Keep fighting", 80.0, 3.0)
	keep.light_color = Color(1.0, 0.3, 0.35)
	keep.used.connect(func():
		keep.enabled = false
		for id in WAVES[0]:
			spawn(id, edge_point())
		await wait_clear()
		keep.enabled = true)


func _read_terminal() -> void:
	await ui.say([
		"REFUGEE LOG 0417",
		"Someone tried to rewind the end of the world. Their helmet cracked time instead.",
		"We fled backwards through the cracks. To the past, we look like invaders.",
		"Their reflection never left. It waits at the heart of the crack.",
	], "Refugee Log", "terminal", "res://assets/ninja/enemies/robot_face.png")


func _marker(pos: Vector2) -> Node2D:
	var m := Node2D.new()
	m.position = pos
	add_child(m)
	return m
