extends Level
## The Simulation: inside the Reverser. A holographic copy of the Elder's village where he trains you.
## He offers to train you (move, sword, combo, breakables, shield, block, reflect) or let you skip.

const P := "res://assets/ninja/"
const HOLO := Color(0.78, 0.98, 1.0, 0.85)

var elder: Interactable
var elder_sprite: AnimatedSprite2D
var dummy: Enemy
var _hits := 0
var _blocks := 0
var _reflects := 0
var _moved := false
var _dashed := false
var _spins := 0
var _cubes: Array[Node2D] = []


func configure() -> void:
	world_size = Vector2(1920, 1152)
	ground = P + "ground/sim.png"
	music = "music_tutorial"
	surface = "stone"
	ambient_color = Color(0.9, 0.97, 1.0)
	particles = "data"
	scanlines = 0.14
	vignette = 0.35
	glow = true
	spawn_point = Vector2(700, 640)


func build_world() -> void:
	keepout(Vector2(960, 600), 280.0)
	keepout(spawn_point, 160.0)
	var holo := {"tint": HOLO}
	# The village the simulation is copying
	prop("holo_house_a", Vector2(400, 330), holo)
	prop("holo_house_b", Vector2(720, 330), holo)
	prop("holo_house_c", Vector2(1200, 330), holo)
	prop("holo_house_a", Vector2(1520, 330), holo)
	prop("holo_torii", Vector2(960, 420), {"tint": HOLO, "collide": false})
	prop("holo_statue", Vector2(960, 860), holo)
	for x in [300, 380, 1540, 1620]:
		prop("holo_fence", Vector2(x, 820), holo)
	var trees := [[Vector2(220, 480), true], [Vector2(240, 880), false], [Vector2(1700, 480), false], [Vector2(1690, 880), true],
		[Vector2(560, 1010), false], [Vector2(1380, 1010), false], [Vector2(1760, 300), true], [Vector2(170, 300), true]]
	for t in trees:
		prop("holo_tree_big" if t[1] else "holo_tree", t[0], {"tint": HOLO, "sway": true})
	for pos in [Vector2(1240, 760), Vector2(1310, 700), Vector2(1380, 780)]:
		prop("holo_scarecrow", pos, {"tint": HOLO})
	for pos in [Vector2(300, 200), Vector2(1600, 200), Vector2(200, 1000), Vector2(1720, 1020)]:
		prop("crystal_tower_1", pos, {"light": Color(0.4, 0.95, 1.0), "energy": 0.35, "light_scale": 1.4, "tint": Color(0.7, 1.0, 1.0)})
	# Floating data cubes
	# Floating data cubes mark the corners of the plaza and the paths out of it
	for pos in [Vector2(600, 360), Vector2(1320, 360), Vector2(600, 800), Vector2(1320, 800), Vector2(300, 600), Vector2(1620, 600),
			Vector2(860, 200), Vector2(1060, 200), Vector2(860, 1000), Vector2(1060, 1000)]:
		var c := Prop.make("gem_block_blue", pos, {"collide": false, "light": Color(0.4, 1.0, 1.0), "energy": 0.4, "light_scale": 0.6, "tint": Color(0.85, 1.0, 1.0, 0.85)})
		add_child(c)
		_cubes.append(c)
	# Training props
	for i in 6:
		breakable("holo_crate" if i % 2 == 0 else "holo_barrel", Vector2(520 + (i % 3) * 60, 860 + (i / 3) * 60))
	breakable("explosive", Vector2(740, 880))
	breakable("holo_crate", Vector2(780, 840))
	# The Wise Elder
	elder = add_interactable("", Vector2(880, 600), "[E] Talk", 100.0)
	elder_sprite = AnimatedSprite2D.new()
	elder_sprite.sprite_frames = Sheet.character(P + "chars/elder")
	elder_sprite.play("idle_down")
	elder_sprite.scale = Vector2(3, 3)
	elder_sprite.position = Vector2(0, -12)
	elder_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	elder_sprite.modulate = Color(0.8, 1.05, 1.15, 0.92)   # he is a projection in here too
	elder.add_child(elder_sprite)
	var halo := Sheet.make_light(Color(1.0, 0.9, 0.6), 0.9, 1.6)
	halo.position = Vector2(0, -20)
	elder.add_child(halo)
	var sh := Sprite2D.new()
	sh.texture = load(P + "fx/shadow.png")
	sh.scale = Vector2(3, 3)
	sh.position = Vector2(0, 12)
	sh.modulate = Color(0, 0, 0, 0.35)
	sh.z_index = -1
	elder.add_child(sh)
	elder.enabled = false


func _process(delta: float) -> void:
	super._process(delta)
	var t := Time.get_ticks_msec() * 0.001
	for i in _cubes.size():
		if is_instance_valid(_cubes[i]):
			_cubes[i].sprite.position.y = sin(t * 1.5 + i) * 8.0 - 30.0
			_cubes[i].sprite.rotation = sin(t + i) * 0.2
	if is_instance_valid(elder_sprite) and is_instance_valid(player):
		var d := Sheet.dir_of(player.global_position - elder.global_position)
		if elder_sprite.animation != "idle_" + d:
			elder_sprite.play("idle_" + d)


func _elder(lines: Array) -> void:
	await ui.say(lines, "Elder", "elder", P + "chars/elder_face.png")


func run() -> void:
	player.dash_started.connect(func(_d): _dashed = true)
	player.blocked.connect(_on_blocked)
	ui.title_card("THE SIMULATION", "Inside the Reverser. Nothing here is real.", "REVERSAL: What you block returns to its sender.")
	await wait(4.2)
	set_objective("Listen to the Elder")
	await _elder([
		"Welcome inside the Reverser. This village is only a memory, rebuilt in light.",
		"Out there, every world's clock runs down. Close the crack before it hits zero, or that timeline shatters.",
		"I can train you, or send you straight through.",
	])
	Voice.say("Will you train with me?", "elder")
	var pick := 0
	if OS.get_environment("ECHO_BOT_SKIP") == "1":
		await wait(0.5)
		pick = 1
	else:
		pick = await ui.choose("Will you train with me?", ["Train with me", "Skip training"])
	if pick == 1:
		await _skip()
	else:
		await _train()
	await _elder(["Remember this. A mirror returns what it is given. Strike your reflection, and you strike yourself."])
	var portal := add_portal("world1", Vector2(1100, 640))
	portal.activate()
	set_objective("Step into the mirror")
	await _elder(["Go. The first crack is waiting."])


func _skip() -> void:
	await _elder(["Very well. Take the Divine Sword and the Mirror Shield."])
	GameManager.has_sword = true
	GameManager.has_shield = true
	Events.ability_unlocked.emit("sword")
	Events.ability_unlocked.emit("shield")
	Audio.sfx("sfx_pickup")
	Juice.fx("circle_spark", player.global_position, 3.0, 0.0, Color(1.4, 2.0, 2.4))
	player.rig.draw_sword()


func _train() -> void:
	await _elder(["Good. Patience is a blade too."])
	set_objective("Move and dash")
	prompt("WASD to move. Space to dash.")
	while not (_moved and _dashed):
		if player.velocity.length() > 10.0:
			_moved = true
		await get_tree().physics_frame
	await _good()

	set_objective("Take the Divine Sword")
	var sword := add_interactable(P + "weapons/divine_sword.png", Vector2(960, 720), "[E] Take the Divine Sword", 80.0, 3.0)
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
	Juice.fx("circle_spark", Vector2(960, 720), 3.0, 0.0, Color(1.4, 2.0, 2.4))
	player.rig.draw_sword()

	dummy = spawn("dummy", Vector2(1260, 600))
	dummy.attack_range = 0.0   # harmless until the shield is in hand
	dummy.damaged.connect(func(_a, _s): _hits += 1)
	player.swung.connect(func(): if player._chain == 2: _spins += 1)
	set_objective("Strike the hologram")
	objective = dummy
	prompt("Left click to strike. Aim with the mouse.")
	while _hits < 3:
		await get_tree().physics_frame
	await _good()
	set_objective("Break the crates")
	prompt("Break the crates. Red barrels explode.")
	var t0 := GameManager.run_time
	while get_tree().get_nodes_in_group("breakable").size() > 5 and GameManager.run_time - t0 < 10.0:
		objective = get_tree().get_first_node_in_group("breakable")
		await wait(0.3)
	objective = null
	await _good()

	set_objective("Take the Mirror Shield")
	var shield := add_interactable(P + "weapons/mirror_shield.png", Vector2(1080, 820), "[E] Take the Mirror Shield", 80.0, 3.0)
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
	set_objective("Block the hologram's strike")
	prompt("Stand close to the dummy. Hold right click to block.")
	_blocks = 0
	while _blocks < 1:
		await get_tree().physics_frame
	await _good()

	set_objective("Reflect 2 strikes")
	Events.tutorial_prompt.emit("Block just as it lands. The mirror sends it back.  (0 / 2)")
	Voice.say("Block just as it lands. The mirror sends it back.", "system")
	_reflects = 0
	while _reflects < 2:
		await get_tree().physics_frame
	objective = null
	await _good()
	dummy.die()


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
