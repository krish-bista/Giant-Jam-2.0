extends Level
## Prehistoric jungle: hunt the herd to fill the hunt meter -> the pack flips and hunts you
## for 10 seconds -> reward -> Alpha Rex.

var meter := 0.0
var _flipped := false


func configure() -> void:
	background = "res://assets/tiles/jungle_bg.png"
	music = "music_jungle"
	spawn_point = Vector2(640, 360)


func run() -> void:
	add_chest(Vector2(1130, 150))
	ui.show_subtitle("They run from you. Hunt them.", Color(0.85, 1.0, 0.75))
	prompt("Chase the animals. Hits fill the hunt meter.")
	Events.hunt_meter_changed.emit(0.0)
	var herd: Array = []
	for i in 5:
		herd.append(spawn("raptor", edge_point(200.0)))
	herd.append(spawn("brute", edge_point(200.0)))
	for e in herd:
		e.damaged.connect(func(_a, s): if s and s.is_in_group("player"): _add(10.0))
		e.died.connect(func(_x): _add(25.0))

	while meter < 100.0:
		await wait(0.2)
		if _alive_count() == 0 and meter < 100.0:
			_add(100.0)
	prompt("")

	# The flip
	_flipped = true
	Audio.sfx("sfx_boss_roar", 0.1, -6.0)
	Juice.shake(6.0, 0.6)
	Juice.flash(Color(1, 0.3, 0.2, 0.3), 0.3)
	Events.announce.emit("THE PACK HAS TURNED")
	ui.show_subtitle("Survive.", Color(1, 0.6, 0.5))
	for e in alive:
		if is_instance_valid(e):
			e.set_state("hunter")
			if e.type_id == "raptor":
				e.sprite.texture = load(EnemyData.TYPES.raptor.hunter_tex)
	for i in 3:
		spawn("raptor", edge_point(), {"state": "hunter", "tex": EnemyData.TYPES.raptor.hunter_tex})
	for s in range(10, 0, -1):
		prompt("Survive: %d" % s)
		await wait(1.0)
		if not player_alive():
			return
	prompt("")
	for e in alive.duplicate():
		if is_instance_valid(e):
			e.drops = false
			e.die()
	Events.hunt_meter_changed.emit(100.0)
	ui.show_subtitle("The hunt is over. Take what you earned.", Color(0.85, 1.0, 0.75))
	player.heal(30.0)
	var id := GameManager.roll_artifact("hunt")
	if id != "":
		Pickup.spawn_artifact(self, player.global_position + Vector2(0, -60), id)
	await wait(3.0)

	var rex := spawn_boss("alpha_rex", Vector2(640, 180))
	await rex.died
	await wait_clear()
	await wait(1.5)
	var portal := add_portal("world3", Vector2(640, 360))
	portal.activate()
	ui.show_subtitle("Go before they remember you.", Color(0.85, 1.0, 0.75))


func _alive_count() -> int:
	return alive.filter(func(e): return is_instance_valid(e)).size()


func _add(amount: float) -> void:
	if _flipped:
		return
	meter = minf(100.0, meter + amount)
	Events.hunt_meter_changed.emit(meter)
