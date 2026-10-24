extends Level
## THE FALLEN CITY - the present day, three days after the sky cracked.
## Two alien waves -> the Hypnotic (unlocks Hypno Reverse) -> the Warden, against a 1:45 clock.
## World weapon: Flare Bow.

const PLAZA := CityLayout.PLAZA     # the center: the mirror opens here
const CLOCK := 105.0                # seconds before this timeline shatters
const WAVES := [
	{"drone": 4, "gunner": 1},
	{"drone": 4, "gunner": 3},
]


func configure() -> void:
	world_size = Vector2(2592, 1440)
	arena_override = Rect2(70, 190, 2452, 1120)
	ground = "res://assets/ninja/ground/city.png"
	music = "music_city"
	boss_music = "music_city_boss"
	ambient = "amb_rain"
	surface = "stone"
	ambient_color = Color(0.5, 0.54, 0.74)
	particles = "rain"
	spawn_point = Vector2(300, 720)


func build_world() -> void:
	keepout(Vector2(spawn_point.x + 200, 720), 120.0)
	CityLayout.build(self, false)
	# The refugee camp in the south-west: people were sheltering here when it began.
	prop("tent", Vector2(410, 1112))
	prop("tent_torn", Vector2(650, 1130), {"flip": true})
	prop("firepit", Vector2(530, 1036), {"collide": false, "light": Color(1.0, 0.55, 0.25), "energy": 1.6, "light_scale": 2.6})
	prop("stump", Vector2(462, 1000), {"collide": false})
	prop("stump", Vector2(600, 996), {"collide": false})
	for b in [["sack", Vector2(260, 1060)], ["sack", Vector2(285, 1095)], ["crate", Vector2(250, 1140)], ["barrel", Vector2(760, 1090)], ["crate_b", Vector2(790, 1130)]]:
		breakable(b[0], b[1])
	add_chest(Vector2(330, 1018))
	lore(Vector2(560, 1186), "Day three. The lights in the sky look like campfires.")
	# The market by the shop: crates stacked under the awning
	for b in [["crate", Vector2(300, 420)], ["crate_b", Vector2(345, 440)], ["barrel", Vector2(395, 418)], ["crate", Vector2(250, 448)]]:
		breakable(b[0], b[1])
	lore(Vector2(440, 362), "Evacuation notice: the creatures aren't attacking. They're running from something.")
	# Sandbags at the barricades
	for pos in [Vector2(160, 620), Vector2(160, 820), Vector2(2430, 620), Vector2(2430, 820)]:
		breakable("sack", pos)
	# Red barrels the army left by the crash site: careful
	for pos in [Vector2(1580, 940), Vector2(1760, 1220), Vector2(2050, 1210), Vector2(2240, 1080), Vector2(860, 690)]:
		breakable("explosive", pos)
	for c in [Vector2(1300, 1150), Vector2(2380, 420)]:
		crate_cluster(c, ["crate", "barrel", "crate_b"], 3, 0.0)
	place_weapon("flare_bow", Vector2(1110, 1110))
	for pos in [Vector2(1900, 1060), Vector2(1660, 970), Vector2(2152, 990)]:
		Juice.fx("smoke", pos, 2.0)


func run() -> void:
	next_scene = "world2"
	var nl := title_card("THE FALLEN CITY", "The present day. Three days after the sky cracked.", "The Fallen City. The present day. Here, the invaders are the ones running.", "REVERSAL: The invaders are the ones running.")
	await wait(maxf(2.6, nl + 0.2))
	start_clock(CLOCK)
	var al := summon_ally(true)
	await wait(maxf(1.5, al + 0.2))
	say_line("They're pouring out of the cracks. Hold the line!")

	for i in WAVES.size():
		set_objective("Survive the alien waves (%d / %d)" % [i + 1, WAVES.size()])
		Events.announce.emit("WAVE %d" % (i + 1))
		await wait(0.6)
		var wave: Dictionary = WAVES[i]
		var list: Array[String] = []
		for k in wave.drone:
			list.append("drone")
		for k in wave.gunner:
			list.append("gunner")
		list.shuffle()
		for id in list:
			spawn(id, edge_point())
			await wait(0.3)
		await wait_clear()
		await wait(0.8)

	set_objective("Go to the plaza")
	objective = _marker(PLAZA)
	while is_instance_valid(player) and player.global_position.distance_to(PLAZA) > 420.0:
		await wait(0.3)
	objective = null
	set_objective("Defeat the Hypnotic")
	var hypno := spawn_boss("hypnotic", PLAZA + Vector2(0, -120))
	await hypno.died
	GameManager.hypno_unlocked = true
	Events.ability_unlocked.emit("hypno")
	Events.announce.emit("HYPNO REVERSE UNLOCKED")
	Voice.say("HYPNO REVERSE UNLOCKED", "system")
	await wait(1.2)
	prompt("[Q] Hypno Reverse: turn their attacks against them.")
	set_objective("Try Hypno Reverse [Q] on the swarm")
	for i in 4:
		spawn("drone", edge_point(300.0))
	spawn("gunner", edge_point(340.0))
	await wait(3.5)
	Events.tutorial_prompt.emit("")
	set_objective("Defeat the Warden")
	var warden := spawn_boss("warden", PLAZA + Vector2(0, -160))
	await warden.died
	world_cleared()
	await wait(1.2)
	var portal := add_portal(next_scene, PLAZA)
	portal.activate()
	set_objective("Step into the mirror")
	say_line("The mirror's open. Go!")


## Out of time before the Hypnotic fell: the shattering timeline still leaves its gift.
func on_time_up() -> void:
	if not GameManager.hypno_unlocked:
		GameManager.hypno_unlocked = true
		GameManager.flags["hypno_late"] = true


func _marker(pos: Vector2) -> Node2D:
	var m := Node2D.new()
	m.position = pos
	add_child(m)
	return m
