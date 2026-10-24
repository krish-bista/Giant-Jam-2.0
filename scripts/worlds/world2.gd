extends Level
## Prehistoric jungle: hunt the herd to fill the hunt meter -> the pack flips and hunts you
## for 10 seconds -> reward -> the Alpha.

var meter := 0.0
var _flipped := false
const CLEARING := Vector2(1300, 720)


func configure() -> void:
	world_size = Vector2(2592, 1440)
	ground = "res://assets/ninja/ground/jungle.png"
	music = "music_jungle"
	boss_music = "music_jungle_boss"
	ambient = "amb_wind"
	surface = "grass"
	ambient_color = Color(0.86, 0.92, 0.8)
	particles = "leaves"
	spawn_point = Vector2(1300, 1000)


func build_world() -> void:
	keepout(CLEARING, 320.0)
	var sway := {"sway": true}
	border(["tree_cluster", "tree_cluster_olive", "pine_cluster", "tree_big"], 160.0, 2, sway)
	prop("frog_statue", Vector2(620, 520))
	scatter(["tree_green", "tree_roots", "tree_bush", "tree_pine", "tree_big", "bamboo", "tree_thin"], 34, Rect2(250, 250, 2090, 940), sway, 30.0)
	scatter(["rock_brown", "rock_grey", "stump", "log", "rocks_brown"], 12, Rect2(250, 250, 2090, 940))
	scatter(["bush_a", "bush_b", "bush_c", "bush_d", "fern", "flower_sun", "flower_red"], 80, Rect2(200, 200, 2190, 1040), {"collide": false, "sway": true}, 2.0)
	for c in [Vector2(760, 600), Vector2(1900, 520), Vector2(2000, 1050), Vector2(500, 1050)]:
		crate_cluster(c, ["pot", "vase", "sack"], 5, 0.2)
	lore(Vector2(700, 600), "The first hunter was afraid too.")
	add_chest(Vector2(2300, 300))


func run() -> void:
	say_line("They run from you. Hunt them.", "you", Color(0.85, 1.0, 0.75))
	Events.tutorial_prompt.emit("Chase the animals. Hits fill the hunt meter.")
	Events.hunt_meter_changed.emit(0.0)
	var herd: Array = []
	for i in 5:
		herd.append(spawn("raptor", edge_point(260.0)))
	herd.append(spawn("brute", edge_point(260.0)))
	for e in herd:
		e.damaged.connect(func(_a, s): if is_instance_valid(s) and s.is_in_group("player"): _add(10.0))
		e.died.connect(func(_x): _add(25.0))

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

	# The flip
	_flipped = true
	Audio.sfx("sfx_boss_roar", 0.1, -4.0)
	Juice.shake(7.0, 0.6)
	Juice.flash(Color(1, 0.3, 0.2, 0.3), 0.3)
	Juice.chroma(0.02)
	Events.announce.emit("THE PACK HAS TURNED")
	Voice.say("THE PACK HAS TURNED", "system")
	for e in alive:
		if is_instance_valid(e):
			e.set_state("hunter")
			if e.type_id == "raptor":
				e.set_look({"sheet": EnemyData.TYPES.raptor.hunter_sheet})
	for i in 3:
		spawn("raptor", edge_point(), {"state": "hunter", "sheet": EnemyData.TYPES.raptor.hunter_sheet})
	await wait(1.6)
	Voice.say("Survive.", "system")
	for s in range(10, 0, -1):
		Events.tutorial_prompt.emit("SURVIVE: %d" % s)
		await wait(1.0)
		if not player_alive():
			return
	Events.tutorial_prompt.emit("")
	for e in alive.duplicate():
		if is_instance_valid(e):
			e.drops = false
			e.die()
	Events.hunt_meter_changed.emit(100.0)
	say_line("The hunt is over. Take what you earned.", "you", Color(0.85, 1.0, 0.75))
	player.heal(30.0)
	var id := GameManager.roll_artifact("hunt")
	if id != "":
		Pickup.spawn_artifact(self, player.global_position + Vector2(0, -70), id)
	await wait(3.5)

	Events.tutorial_prompt.emit("Something big is coming. Get to the clearing.")
	objective = _marker(CLEARING)
	while is_instance_valid(player) and player.global_position.distance_to(CLEARING) > 380.0:
		await wait(0.3)
	Events.tutorial_prompt.emit("")
	objective = null
	var rex := spawn_boss("alpha_rex", CLEARING + Vector2(0, -200))
	await rex.died
	await wait_clear()
	await wait(2.0)
	var portal := add_portal("world3", CLEARING)
	portal.activate()
	say_line("Go before they remember you.", "you", Color(0.85, 1.0, 0.75))


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
