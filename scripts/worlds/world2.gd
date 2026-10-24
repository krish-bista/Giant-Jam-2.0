extends Level
## THE FIRST HUNT - ten thousand years ago. You are the intruder: hunt the herd, then the pack
## turns and hunts you for 7 seconds -> reward -> the Alpha, against a 1:25 clock.
## World weapon: Hunter's Axe.

const SURVIVE := 9
var meter := 0.0
var _flipped := false
const CLEARING := Vector2(1296, 720)   # the center: the mirror opens here
const CLOCK := 85.0


func configure() -> void:
	world_size = Vector2(2592, 1440)
	arena_override = Rect2(250, 300, 2092, 960)
	ground = "res://assets/ninja/ground/jungle.png"
	music = "music_jungle"
	boss_music = "music_jungle_boss"
	ambient = "amb_wind"
	surface = "grass"
	ambient_color = Color(0.88, 0.94, 0.82)
	particles = "leaves"
	spawn_point = Vector2(1300, 1010)


func build_world() -> void:
	keepout(CLEARING, 300.0)
	keepout(spawn_point, 120.0)
	var sway := {"sway": true}
	# The forest wall: two staggered rows of canopy on every side (you can't leave the hunt)
	_forest_wall()
	# The hunters' camp, south-west of where you arrive
	prop("tent", Vector2(860, 1150))
	prop("firepit", Vector2(960, 1150), {"collide": false, "light": Color(1.0, 0.55, 0.25), "energy": 1.5, "light_scale": 2.4})
	prop("stump", Vector2(1020, 1200), {"collide": false})
	prop("stump", Vector2(900, 1225), {"collide": false})
	prop("bones_ribs", Vector2(760, 1210), {"collide": false})
	for b in [["pot", Vector2(780, 1100)], ["vase", Vector2(740, 1130)], ["sack", Vector2(800, 1140)], ["pot", Vector2(1080, 1110)]]:
		breakable(b[0], b[1])
	place_weapon("hunter_axe", Vector2(1010, 1090))
	# The hunting ground: standing stones ring the clearing, the first hunter's totem watches it
	for i in 10:
		var a := TAU * i / 10.0 + 0.3
		var pos := CLEARING + Vector2(cos(a) * 360.0, sin(a) * 270.0)
		if absf(pos.x - CLEARING.x) < 80.0 and pos.y > CLEARING.y:
			continue    # leave the south entrance (the trail from camp) open
		prop("rock_grey" if i % 2 == 0 else "rock_grey_small", pos)
	prop("frog_statue", CLEARING + Vector2(0, -292))
	lore(CLEARING + Vector2(-120, -250), "The first hunter was afraid too.")
	prop("dino_skull", CLEARING + Vector2(190, 150), {"collide": false})
	# North-west: a bamboo grove where the trail ends
	for pos in [Vector2(470, 380), Vector2(520, 420), Vector2(430, 450), Vector2(580, 370), Vector2(560, 480), Vector2(390, 400), Vector2(640, 430)]:
		prop("bamboo", pos, sway)
	# North-east: a rock outcrop with the cache hidden in it
	prop("boulder_brown", Vector2(2110, 420))
	prop("rocks_brown", Vector2(1960, 380))
	prop("rock_brown", Vector2(2220, 510))
	prop("rock_brown_small", Vector2(1890, 470))
	add_chest(Vector2(2040, 500))
	# Groves that break up the open ground
	for t in [["tree_big", Vector2(470, 760)], ["tree_green", Vector2(380, 860)], ["tree_roots", Vector2(560, 880)], ["tree_bush", Vector2(470, 960)],
			["tree_pine", Vector2(2160, 860)], ["tree_pine", Vector2(2250, 980)], ["tree_green", Vector2(2120, 1120)],
			["tree_big", Vector2(1640, 1220)], ["tree_roots", Vector2(1490, 1240)],
			["tree_green", Vector2(820, 560)], ["tree_bush", Vector2(1760, 560)], ["tree_pine", Vector2(1080, 420)], ["tree_green", Vector2(1530, 400)]]:
		prop(t[0], t[1], sway)
	prop("stump", Vector2(640, 640))
	prop("stump", Vector2(1880, 760))
	prop("rocks_brown", Vector2(300, 1150))
	# Undergrowth: bushes where trees meet the open grass, flowers in the sunny glade (east)
	var bushes := ["bush_a", "bush_b", "bush_c", "bush_d", "fern"]
	var k := 0
	for c in [Vector2(470, 760), Vector2(2160, 860), Vector2(1640, 1220), Vector2(820, 560), Vector2(1760, 560), Vector2(470, 420), Vector2(2110, 420), Vector2(1080, 420), Vector2(1530, 400)]:
		for off in [Vector2(-70, 24), Vector2(64, 30), Vector2(10, 52)]:
			k += 1
			prop(bushes[k % bushes.size()], c + off, {"collide": false, "sway": true})
	for pos in [Vector2(1820, 980), Vector2(1860, 1010), Vector2(1900, 990), Vector2(1950, 1030), Vector2(1880, 1060), Vector2(1990, 1000),
			Vector2(700, 1060), Vector2(660, 1090), Vector2(1150, 1250), Vector2(1190, 1270)]:
		k += 1
		prop("flower_red" if k % 2 == 0 else "flower_sun", pos, {"collide": false, "sway": true})


func _forest_wall() -> void:
	var trees := ["tree_cluster", "tree_cluster_olive", "pine_cluster"]
	var sway := {"sway": true}
	var i := 0
	for row in 2:
		var x := 40.0 + row * 75.0
		while x < world_size.x + 60.0:
			i += 1
			prop(trees[i % 3], Vector2(x, 150.0 + row * 95.0), sway)
			prop(trees[(i + 1) % 3], Vector2(x + 30.0, 1430.0 - row * 85.0), sway)
			x += 150.0
	for row in 2:
		var y := 330.0 + row * 55.0
		while y < 1300.0:
			i += 1
			prop(trees[i % 3], Vector2(70.0 + row * 110.0, y), sway)
			prop(trees[(i + 2) % 3], Vector2(world_size.x - 70.0 - row * 110.0, y + 30.0), sway)
			y += 110.0
	block(Rect2(0, 0, world_size.x, 262))
	block(Rect2(0, 1300, world_size.x, 140))
	block(Rect2(0, 0, 236, world_size.y))
	block(Rect2(world_size.x - 236, 0, 236, world_size.y))


func run() -> void:
	next_scene = "world3"
	var nl := title_card("THE FIRST HUNT", "Ten thousand years ago.", "The First Hunt. Ten thousand years ago. Here, the hunter becomes the hunted.", "REVERSAL: The hunter becomes the hunted.")
	await wait(maxf(2.6, nl + 0.2))
	start_clock(CLOCK)
	if GameManager.has_flag("hypno_late"):
		GameManager.flags.erase("hypno_late")
		Events.ability_unlocked.emit("hypno")
		Events.announce.emit("HYPNO REVERSE UNLOCKED")
		Voice.say("HYPNO REVERSE UNLOCKED", "system")
	summon_ally()
	await wait(1.4)
	say_line("Here, I'm the stranger. Everything runs from me.", "you", Color(0.85, 1.0, 0.75))
	set_objective("Hunt the herd: hits fill the hunt meter")
	Events.tutorial_prompt.emit("Chase the animals. Hits fill the hunt meter.")
	Events.hunt_meter_changed.emit(0.0)
	var herd: Array = []
	for i in 5:
		herd.append(spawn("raptor", edge_point(240.0)))
	herd.append(spawn("brute", edge_point(240.0)))
	for e in herd:
		e.damaged.connect(func(_a, s): if is_instance_valid(s) and s.is_in_group("player"): _add(8.0))
		e.died.connect(func(_x): _add(22.0))

	while meter < 100.0:
		await wait(0.2)
		var near: Node2D = null
		for e in alive:
			if is_instance_valid(e):
				near = e
				break
		objective = near
		if _alive_count() == 0 and meter < 100.0:
			_add(100.0)
	objective = null
	Events.tutorial_prompt.emit("")

	# The reversal: the hunter becomes the hunted
	_flipped = true
	Audio.sfx("sfx_boss_roar", 0.1, -4.0)
	Juice.shake(7.0, 0.6)
	Juice.flash(Color(1, 0.3, 0.2, 0.3), 0.3)
	Juice.chroma(0.02)
	Events.announce.emit("THE PACK HAS TURNED")
	Voice.say("THE PACK HAS TURNED", "system")
	set_objective("You are the prey now: survive")
	for e in alive:
		if is_instance_valid(e):
			e.set_state("hunter")
			if e.type_id == "raptor":
				e.set_look({"sheet": EnemyData.TYPES.raptor.hunter_sheet})
	for i in 4:
		spawn("raptor", edge_point(), {"state": "hunter", "sheet": EnemyData.TYPES.raptor.hunter_sheet})
	await wait(1.0)
	say_line("Wait... now I'm the prey!", "you", Color(1, 0.7, 0.6))
	for s in range(SURVIVE, 0, -1):
		Events.tutorial_prompt.emit("SURVIVE: %d" % s)
		await wait(1.0)
	Events.tutorial_prompt.emit("")
	for e in alive.duplicate():
		if is_instance_valid(e):
			e.drops = false
			e.die()
	Events.hunt_meter_changed.emit(100.0)
	say_line("It's over. I made it.", "you", Color(0.85, 1.0, 0.75))
	player.heal(30.0)
	var id := GameManager.roll_artifact("hunt")
	if id != "":
		Pickup.spawn_artifact(self, player.global_position + Vector2(0, -70), id)
	await wait(1.5)

	set_objective("Something big is coming: go to the clearing")
	objective = _marker(CLEARING)
	while is_instance_valid(player) and player.global_position.distance_to(CLEARING) > 420.0:
		await wait(0.3)
	objective = null
	set_objective("Defeat the Alpha")
	var rex := spawn_boss("alpha_rex", CLEARING + Vector2(0, -200))
	await rex.died
	world_cleared()
	await wait(1.2)
	var portal := add_portal(next_scene, CLEARING)
	portal.activate()
	set_objective("Step into the mirror")
	say_line("Go, before they remember me.", "you", Color(0.85, 1.0, 0.75))


func _marker(pos: Vector2) -> Node2D:
	var m := Node2D.new()
	m.position = pos
	add_child(m)
	return m


func _alive_count() -> int:
	return alive.filter(func(e): return is_instance_valid(e)).size()


func _add(amount: float) -> void:
	if _flipped:
		return
	meter = minf(100.0, meter + amount)
	Events.hunt_meter_changed.emit(meter)
