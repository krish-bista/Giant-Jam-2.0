extends Level
## VR box world: move, take sword, attack, combo spin, break things, take shield, block, reflect,
## enter the fragment.

const P := "res://assets/ninja/"

var dummy: Enemy
var _hits := 0
var _blocks := 0
var _reflects := 0
var _moved := false
var _dashed := false
var _spins := 0


func configure() -> void:
	world_size = Vector2(1632, 960)
	ground = P + "ground/tutorial.png"
	music = "music_tutorial"
	surface = "stone"
	ambient_color = Color(0.88, 0.93, 0.98)
	particles = "snow"
	scanlines = 0.18
	glow = false
	vignette = 0.3
	spawn_point = Vector2(330, 520)


func build_world() -> void:
	for p in [Vector2(160, 200), Vector2(1470, 200), Vector2(160, 820), Vector2(1470, 820)]:
		prop("crystal_tower_1", p, {"light": Color(0.4, 0.95, 1.0), "energy": 1.0, "light_scale": 2.0, "tint": Color(0.7, 1.3, 1.5)})
	for i in 6:
		var b := breakable("holo_crate" if i % 2 == 0 else "holo_barrel", Vector2(330 + (i % 3) * 60, 220 + (i / 3) * 60))
	breakable("explosive", Vector2(560, 250))
	breakable("holo_crate", Vector2(600, 210))
	breakable("holo_crate", Vector2(610, 300))


func run() -> void:
	player.dash_started.connect(func(_d): _dashed = true)
	player.blocked.connect(_on_blocked)
	prompt("Calibrating... Nothing here can hurt you. Yet.")
	await wait(3.0)

	prompt("WASD to move. Space to dash.")
	while not (_moved and _dashed):
		if player.velocity.length() > 10.0:
			_moved = true
		await get_tree().physics_frame
	await _good()

	# Sword
	var sword := add_interactable(P + "weapons/divine_sword.png", Vector2(760, 520), "[E] Take the Divine Sword", 80.0, 3.0)
	sword.glow = true
	sword.one_shot = true
	sword.light_color = Color(0.5, 0.9, 1.0)
	objective = sword
	prompt("[E] Take the Divine Sword")
	await sword.used
	objective = null
	sword.queue_free()
	GameManager.has_sword = true
	Events.ability_unlocked.emit("sword")
	Audio.sfx("sfx_pickup")
	Juice.fx("circle_spark", Vector2(760, 520), 3.0, 0.0, Color(1.4, 2.0, 2.4))
	player.rig.draw_sword()

	dummy = spawn("dummy", Vector2(1150, 520))
	dummy.attack_range = 0.0   # harmless until the shield is in hand
	dummy.damaged.connect(func(_a, _s): _hits += 1)
	player.swung.connect(func(): if player._chain == 2: _spins += 1)
	prompt("Left click to strike. Aim with the mouse.")
	while _hits < 3:
		await get_tree().physics_frame
	await _good()
	prompt("Strike three times in a row to finish with a spin.")
	var t0 := GameManager.run_time
	while _spins < 1 and GameManager.run_time - t0 < 14.0:
		await get_tree().physics_frame
	await _good()

	prompt("Break the crates. Red barrels explode.")
	objective = get_tree().get_first_node_in_group("breakable")
	t0 = GameManager.run_time
	while get_tree().get_nodes_in_group("breakable").size() > 5 and GameManager.run_time - t0 < 16.0:
		objective = get_tree().get_first_node_in_group("breakable")
		await wait(0.3)
	objective = null
	await _good()

	# Shield
	var shield := add_interactable(P + "weapons/mirror_shield.png", Vector2(900, 700), "[E] Take the Mirror Shield", 80.0, 3.0)
	shield.glow = true
	shield.one_shot = true
	shield.light_color = Color(0.6, 0.9, 1.0)
	objective = shield
	prompt("[E] Take the Mirror Shield")
	await shield.used
	objective = null
	shield.queue_free()
	GameManager.has_shield = true
	Events.ability_unlocked.emit("shield")
	Audio.sfx("sfx_pickup")

	dummy.attack_range = 120.0
	objective = dummy
	prompt("Stand close to the dummy. Hold right click to block.")
	_blocks = 0
	while _blocks < 1:
		await get_tree().physics_frame
	await _good()

	Events.tutorial_prompt.emit("Block just as it lands. The mirror sends it back.  (0 / 2)")
	Voice.say("Block just as it lands. The mirror sends it back.", "system")
	_reflects = 0
	while _reflects < 2:
		await get_tree().physics_frame
	objective = null
	await _good()

	dummy.die()
	var portal := add_portal("world1", Vector2(1420, 520))
	portal.activate()
	prompt("A shard of a broken timeline. Step through.")


func _on_blocked(perfect: bool) -> void:
	_blocks += 1
	if perfect:
		_reflects += 1
		if _reflects <= 2:
			Events.tutorial_prompt.emit("Block just as it lands. The mirror sends it back.  (%d / 2)" % _reflects)


func _good() -> void:
	Events.tutorial_prompt.emit("")
	Events.announce.emit("Good.")
	Voice.say("Good.", "system")
	Audio.sfx("sfx_ui_confirm", 0.0, -2.0)
	await wait(1.1)
