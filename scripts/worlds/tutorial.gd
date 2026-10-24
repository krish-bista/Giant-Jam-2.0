extends Level
## VR box world: move, take sword, attack, take shield, block, reflect, enter the fragment.

var dummy: Enemy
var _hits := 0
var _blocks := 0
var _reflects := 0
var _moved := false
var _dashed := false


func configure() -> void:
	background = "res://assets/tiles/tut_bg.png"
	music = "music_room"
	spawn_point = Vector2(300, 360)


func run() -> void:
	player.dash_started.connect(func(_d): _dashed = true)
	player.blocked.connect(_on_blocked)
	prompt("Calibrating... Nothing here can hurt you. Yet.")
	await wait(2.5)

	prompt("WASD to move. Space to dash.")
	while not (_moved and _dashed):
		if player.velocity.length() > 10.0:
			_moved = true
		await get_tree().physics_frame
	await _good()

	# Sword
	var sword := add_interactable("res://assets/props/prop_sword.png", Vector2(560, 360), "[E] Take the Divine Sword", 70.0, 1.3)
	sword.glow = true
	sword.one_shot = true
	prompt("[E] Take the Divine Sword")
	await sword.used
	sword.queue_free()
	GameManager.has_sword = true
	Events.ability_unlocked.emit("sword")
	Audio.sfx("sfx_pickup")
	Juice.burst(Vector2(560, 360), Color(0.8, 1, 1), 20, 180.0)

	dummy = spawn("dummy", Vector2(860, 360))
	dummy.attack_range = 0.0   # harmless until the shield is in hand
	dummy.damaged.connect(func(_a, _s): _hits += 1)
	prompt("Left click to strike. Aim with the mouse.")
	while _hits < 3:
		await get_tree().physics_frame
	await _good()

	# Shield
	var shield := add_interactable("res://assets/props/prop_shield.png", Vector2(560, 470), "[E] Take the Mirror Shield", 70.0, 1.3)
	shield.glow = true
	shield.one_shot = true
	prompt("[E] Take the Mirror Shield")
	await shield.used
	shield.queue_free()
	GameManager.has_shield = true
	Events.ability_unlocked.emit("shield")
	Audio.sfx("sfx_pickup")

	dummy.attack_range = 120.0
	prompt("Stand close to the dummy. Hold right click to block.")
	_blocks = 0
	while _blocks < 1:
		await get_tree().physics_frame
	await _good()

	prompt("Block just as it lands. The mirror sends it back.  (0 / 2)")
	_reflects = 0
	while _reflects < 2:
		await get_tree().physics_frame
	await _good()

	dummy.die()
	var portal := add_portal("world1", Vector2(1080, 360))
	portal.activate()
	prompt("A shard of a broken timeline. Step through.")


func _on_blocked(perfect: bool) -> void:
	_blocks += 1
	if perfect:
		_reflects += 1
		if _reflects <= 2:
			prompt("Block just as it lands. The mirror sends it back.  (%d / 2)" % _reflects)


func _good() -> void:
	prompt("")
	Events.announce.emit("Good.")
	Audio.sfx("sfx_ui_confirm", 0.0, -2.0)
	await wait(1.0)
