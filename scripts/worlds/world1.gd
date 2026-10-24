extends Level
## Modern city: 3 alien waves -> Hypnotic mini boss (unlocks Hypno Reverse) -> the Warden.

const WAVES := [
	{"drone": 4, "gunner": 0},
	{"drone": 5, "gunner": 2},
	{"drone": 4, "gunner": 3},
]


func configure() -> void:
	background = "res://assets/tiles/city_bg.png"
	music = "music_city"
	spawn_point = Vector2(640, 420)


func run() -> void:
	add_chest(Vector2(150, 150))
	ui.show_subtitle("The city. Before it fell. Or after.", Color(0.8, 0.9, 1.0))
	await wait(2.5)

	for i in WAVES.size():
		Events.announce.emit("Wave %d" % (i + 1))
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
			await wait(0.5)
		await wait_clear()
		await wait(2.0)

	# Mini boss
	var hypno := spawn_boss("hypnotic", Vector2(640, 220))
	await hypno.died
	GameManager.hypno_unlocked = true
	Events.ability_unlocked.emit("hypno")
	await wait(1.2)
	Events.announce.emit("HYPNO REVERSE UNLOCKED")
	prompt("[Q] Turn them on each other.")
	await wait(3.0)

	# Practice Hypno on a small group, then the Warden.
	for i in 4:
		spawn("drone", edge_point())
	await wait(5.0)
	prompt("")
	var warden := spawn_boss("warden", Vector2(640, 200))
	await warden.died
	await wait_clear()
	await wait(1.5)
	var portal := add_portal("world2", Vector2(640, 360))
	portal.activate()
	ui.show_subtitle("The portal holds. Go.", Color(0.8, 0.9, 1.0))
