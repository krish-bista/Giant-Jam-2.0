extends Level
## Far-future alien core: constructs mirror your movement across the center line.
## The twist line is on a terminal by the entrance. Core Sentinel. Then: keep fighting, or the final fragment.

var _offsets := [Vector2(0, -90), Vector2(0, 90), Vector2(0, 0), Vector2(0, -180), Vector2(0, 180)]


func configure() -> void:
	background = "res://assets/tiles/core_bg.png"
	music = "music_core"
	spawn_point = Vector2(300, 360)


func run() -> void:
	var terminal := add_interactable("res://assets/props/prop_terminal.png", Vector2(150, 140), "[E] Read", 80.0)
	terminal.glow = true
	terminal.used.connect(_read_terminal)
	ui.show_subtitle("They move as you move.", Color(0.9, 0.75, 1.0))
	await wait(2.0)

	await _mirror_wave(3)
	prompt("")
	await wait(1.5)
	await _mirror_wave(4)
	prompt("")
	await wait(1.5)

	var sentinel := spawn_boss("sentinel", Vector2(960, 360))
	await sentinel.died
	await wait_clear()
	await wait(1.5)
	ui.show_subtitle("The last fragment is waiting.", Color(1, 0.75, 0.8))
	var portal := add_portal("final", Vector2(640, 300), true)
	portal.activate()
	var keep := add_interactable("res://assets/enemies/core_construct.png", Vector2(640, 520), "[E] Keep fighting", 70.0)
	keep.used.connect(func():
		keep.enabled = false
		await _mirror_wave(4)
		keep.enabled = true)


func _mirror_wave(count: int) -> void:
	for i in count:
		var off: Vector2 = _offsets[i % _offsets.size()]
		var p := Vector2(2.0 * 640.0 - player.global_position.x, player.global_position.y) + off
		var e := spawn("construct", p.clamp(ARENA.position, ARENA.end))
		e.mirror_offset = off
		await wait(0.25)
	await wait(3.0)
	if not alive.is_empty():
		prompt("Make them strike each other.")
	await wait_clear()


func _read_terminal() -> void:
	await ui.say(["REFUGEE LOG 0417", "We crossed time to escape the future he made."], "Terminal")
