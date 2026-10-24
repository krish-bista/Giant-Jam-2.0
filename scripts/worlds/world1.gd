extends Level
## THE FALLEN CITY - the present day, three days after the sky cracked.
## Alien waves -> the Hypnotic (unlocks Hypno Reverse) -> the Warden. World weapon: Flare Bow.

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
	ambient_color = Color(0.46, 0.5, 0.72)
	particles = "rain"
	spawn_point = Vector2(380, 720)


func build_world() -> void:
	keepout(PLAZA, 300.0)
	keepout(Vector2(spawn_point.x + 200, 720), 120.0)
	place_weapon("flare_bow", Vector2(2250, 1150))
	# The street: lamps on both sides of the road
	for x in range(260, 2500, 330):
		prop("lamp_post", Vector2(x, 620), {"light": Color(1.0, 0.75, 0.45), "energy": 1.4, "light_scale": 2.6})
		prop("lamp_post", Vector2(x + 165, 860), {"light": Color(1.0, 0.75, 0.45), "energy": 1.4, "light_scale": 2.6})
	# A town: intact houses on the north street, ruins where the aliens hit
	prop("town_house_a", Vector2(420, 380))
	prop("town_shop", Vector2(760, 380))
	prop("town_house_b", Vector2(1880, 380))
	prop("town_red", Vector2(2220, 380))
	prop("ruin_house_big", Vector2(1100, 400))
	prop("ruin_a", Vector2(1560, 360))
	prop("town_house_c", Vector2(560, 1250))
	prop("ruin_b", Vector2(900, 1250))
	prop("ruin_c", Vector2(1500, 1260))
	prop("statue_lion", PLAZA + Vector2(0, -260))
	# Where they came through: crashed alien pods, still glowing
	for pos in [Vector2(1720, 980), Vector2(820, 560), Vector2(2050, 620)]:
		prop("alien_pod", pos, {"light": Color(0.4, 1.0, 0.5), "energy": 1.4, "light_scale": 2.2})
		Juice.fx("smoke", pos + Vector2(0, -30), 2.0)
	# Barricades the people built
	for pos in [Vector2(640, 720), Vector2(1960, 720), Vector2(1300, 1040)]:
		prop("barricade", pos)
	# Refugee tents (they were running too)
	prop("tent", Vector2(2180, 1060))
	prop("firepit", Vector2(2050, 1080), {"collide": false, "light": Color(1.0, 0.55, 0.25), "energy": 1.6, "light_scale": 2.4})
	border(["moss_tree", "pillar", "ruin_rubble", "moss_trees", "pillar_broken", "ruin_wall"], 170.0, 1)
	scatter(["pillar_broken", "rock_grey_small", "ruin_rubble", "moss_tree", "pillar"], 14, Rect2(150, 150, 2290, 1140))
	scatter(["bush_a", "bush_b", "fern", "rock_grey_small"], 26, Rect2(150, 150, 2290, 1140), {"collide": false}, 4.0)
	for c in [Vector2(950, 560), Vector2(1700, 560), Vector2(560, 950), Vector2(1550, 1080), Vector2(2000, 860), Vector2(900, 1060)]:
		crate_cluster(c, ["crate", "barrel", "crate_b", "sack"], 5, 0.25)
	lore(Vector2(560, 560), "Evacuation notice: the creatures are not attacking. They are running.")
	lore(Vector2(2120, 1180), "Day three. The lights in the sky look like campfires.")
	add_chest(Vector2(2420, 250))


func run() -> void:
	title_card("THE FALLEN CITY", "The present day. Three days after the sky cracked.", "The Fallen City. The present day, three days after the sky cracked.")
	await wait(4.2)
	summon_ally(true)
	await wait(4.5)
	say_line("They came through the cracks. Hold the line.")
	await wait(2.0)

	for i in WAVES.size():
		set_objective("Survive the alien waves (%d / %d)" % [i + 1, WAVES.size()])
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

	set_objective("Go to the plaza")
	objective = _marker(PLAZA)
	while is_instance_valid(player) and player.global_position.distance_to(PLAZA) > 380.0:
		await wait(0.3)
	objective = null
	set_objective("Defeat the Hypnotic")
	var hypno := spawn_boss("hypnotic", PLAZA + Vector2(0, -120))
	await hypno.died
	GameManager.hypno_unlocked = true
	Events.ability_unlocked.emit("hypno")
	await wait(1.2)
	Events.announce.emit("HYPNO REVERSE UNLOCKED")
	Voice.say("HYPNO REVERSE UNLOCKED", "system")
	await wait(2.0)
	prompt("[Q] Hypno Reverse: their attacks become yours.")
	set_objective("Try Hypno Reverse [Q] on the swarm")
	await wait(1.5)

	for i in 5:
		spawn("drone", edge_point(320.0))
	spawn("gunner", edge_point(360.0))
	await wait(6.0)
	Events.tutorial_prompt.emit("")
	set_objective("Defeat the Warden")
	var warden := spawn_boss("warden", PLAZA + Vector2(0, -160))
	await warden.died
	await wait_clear()
	await wait(2.0)
	var portal := add_portal("world2", PLAZA)
	portal.activate()
	set_objective("Step into the mirror")
	say_line("The portal holds. Go.")


func _marker(pos: Vector2) -> Node2D:
	var m := Node2D.new()
	m.position = pos
	add_child(m)
	return m
