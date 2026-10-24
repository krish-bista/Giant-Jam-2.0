extends Level
## The fallen city at night: 3 alien waves -> Hypnotic mini boss (unlocks Hypno Reverse) -> the Warden.

const PLAZA := Vector2(1300, 720)
const WAVES := [
	{"drone": 4, "gunner": 0},
	{"drone": 5, "gunner": 2},
	{"drone": 4, "gunner": 3},
]


func configure() -> void:
	world_size = Vector2(2592, 1440)
	ground = "res://assets/ninja/ground/city.png"
	music = "music_city"
	boss_music = "music_city_boss"
	ambient = "amb_rain"
	surface = "stone"
	ambient_color = Color(0.42, 0.47, 0.7)
	particles = "rain"
	spawn_point = Vector2(380, 720)


func build_world() -> void:
	keepout(PLAZA, 300.0)
	keepout(Vector2(spawn_point.x + 200, 720), 120.0)
	# Street lamps along the road
	for x in range(260, 2500, 330):
		prop("lamp_post", Vector2(x, 620), {"light": Color(1.0, 0.75, 0.45), "energy": 1.3, "light_scale": 2.6})
		prop("lamp_post", Vector2(x + 165, 860), {"light": Color(1.0, 0.75, 0.45), "energy": 1.3, "light_scale": 2.6})
	# Landmark ruins
	prop("ruin_house_big", Vector2(780, 420))
	prop("ruin_a", Vector2(1650, 360))
	prop("ruin_b", Vector2(2150, 430))
	prop("ruin_c", Vector2(640, 1230))
	prop("ruin_d", Vector2(1180, 1260))
	prop("shrine_ruin", Vector2(1900, 1220))
	prop("statue_lion", PLAZA + Vector2(0, -260))
	# Refugee camp (they were running too)
	prop("tent", Vector2(2180, 1080))
	prop("tent_torn", Vector2(2380, 1180))
	prop("firepit", Vector2(2280, 1060), {"collide": false, "light": Color(1.0, 0.55, 0.25), "energy": 1.6, "light_scale": 2.4})
	# Edges and clutter
	border(["moss_tree", "pillar", "ruin_rubble", "moss_trees", "pillar_broken", "ruin_wall"], 170.0, 1)
	scatter(["pillar_broken", "rock_grey_small", "ruin_rubble", "moss_tree", "grave", "pillar"], 22, Rect2(150, 150, 2290, 1140))
	scatter(["bush_a", "bush_b", "fern", "rock_grey_small"], 30, Rect2(150, 150, 2290, 1140), {"collide": false}, 4.0)
	for c in [Vector2(950, 560), Vector2(1700, 560), Vector2(560, 950), Vector2(1550, 1080), Vector2(2000, 760), Vector2(900, 1060)]:
		crate_cluster(c, ["crate", "barrel", "crate_b", "sack"], 5, 0.25)
	lore(Vector2(560, 300), "Day three. The lights in the sky look like campfires.")
	lore(Vector2(2060, 1150), "Nobody remembers who fired first.")
	add_chest(Vector2(2420, 250))


func run() -> void:
	say_line("The city. Before it fell. Or after.")
	await wait(3.0)

	for i in WAVES.size():
		Events.announce.emit("WAVE %d" % (i + 1))
		await wait(1.0)
		var wave: Dictionary = WAVES[i]
		var list: Array[String] = []
		for k in wave.drone:
			list.append("drone")
		for k in wave.gunner:
			list.append("gunner")
		list.shuffle()
		for id in list:
			spawn(id, edge_point())
			await wait(0.45)
		await wait_clear()
		await wait(2.0)

	# Mini boss in the plaza
	Events.tutorial_prompt.emit("Something waits in the plaza.")
	objective = _marker(PLAZA)
	while is_instance_valid(player) and player.global_position.distance_to(PLAZA) > 380.0:
		await wait(0.3)
	Events.tutorial_prompt.emit("")
	objective = null
	var hypno := spawn_boss("hypnotic", PLAZA + Vector2(0, -120))
	await hypno.died
	GameManager.hypno_unlocked = true
	Events.ability_unlocked.emit("hypno")
	await wait(1.2)
	Events.announce.emit("HYPNO REVERSE UNLOCKED")
	Voice.say("HYPNO REVERSE UNLOCKED", "system")
	await wait(2.0)
	prompt("[Q] Turn them on each other.")
	await wait(1.5)

	for i in 5:
		spawn("drone", edge_point(320.0))
	await wait(6.0)
	Events.tutorial_prompt.emit("")
	var warden := spawn_boss("warden", PLAZA + Vector2(0, -160))
	await warden.died
	await wait_clear()
	await wait(2.0)
	var portal := add_portal("world2", PLAZA)
	portal.activate()
	say_line("The portal holds. Go.")


func _marker(pos: Vector2) -> Node2D:
	var m := Node2D.new()
	m.position = pos
	add_child(m)
	return m
