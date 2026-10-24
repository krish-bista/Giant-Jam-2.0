extends Level
## Wake up, talk to the Stranger, put on the helmet.

var npc: Interactable
var helmet: Interactable
var _talked := false


func configure() -> void:
	background = "res://assets/tiles/room_bg.png"
	music = "music_room"
	spawn_point = Vector2(360, 470)


func run() -> void:
	GameManager.reset_run()
	player.setup_for_level()
	add_interactable("res://assets/props/prop_table.png", Vector2(640, 300), "", 0.0, 1.4)
	helmet = add_interactable("res://assets/props/prop_helmet.png", Vector2(640, 268), "[E] Put on the helmet", 80.0)
	helmet.enabled = false
	npc = add_interactable("res://assets/characters/room_npc.png", Vector2(900, 330), "[E] Talk", 90.0, 1.2)
	npc.used.connect(_on_talk)
	var door := add_interactable("", Vector2(640, 92), "[E] Door", 80.0)
	door.used.connect(func(): ui.show_subtitle("The door doesn't open. Not from this side.", Color(0.9, 0.95, 1.0)))
	var door_rect := ColorRect.new()
	door_rect.color = Color(0.28, 0.4, 0.45)
	door_rect.size = Vector2(70, 24)
	door_rect.position = Vector2(605, 52)
	add_child(door_rect)
	helmet.used.connect(_on_helmet)

	await wait(0.8)
	await ui.say(["...", "Where am I?"])
	prompt("WASD to move. [E] to talk.")


func _on_talk() -> void:
	prompt("")
	if _talked:
		await ui.say(["The helmet. Please."], "Stranger")
		return
	_talked = true
	await ui.say([
		"You're awake. Good. Don't try to remember. Not yet.",
		"Three days ago the sky cracked open. They came through.",
		"Time is breaking. The pieces are scattered across it.",
		"Only you can walk between them. Don't ask me why.",
		"Put this on.",
	], "Stranger")
	helmet.enabled = true
	helmet.glow = true
	prompt("[E] Put on the helmet")


func _on_helmet() -> void:
	prompt("")
	helmet.enabled = false
	GameManager.input_locked = true
	Audio.sfx("sfx_glitch")
	Juice.flash(Color(0.8, 1, 1, 0.9), 0.8)
	Juice.shake(4.0, 0.5)
	await wait(0.6)
	GameManager.go_to_scene("tutorial")
