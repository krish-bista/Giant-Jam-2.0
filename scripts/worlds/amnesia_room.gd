extends Level
## Wake up, talk to the Stranger, put on the helmet.

const P := "res://assets/ninja/"

var npc: Interactable
var npc_sprite: AnimatedSprite2D
var helmet: Interactable
var _talked := false


func configure() -> void:
	world_size = Vector2(1296, 720)
	ground = P + "ground/room.png"
	music = "music_room"
	surface = "wood"
	ambient_color = Color(0.5, 0.46, 0.56)
	particles = "dust"
	spawn_point = Vector2(250, 380)
	vignette = 0.55


func build_world() -> void:
	# The top wall is tall in the art; block it.
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(1296, 150)
	shape.shape = r
	shape.position = Vector2(648, 75)
	wall.add_child(shape)
	add_child(wall)

	prop("bed", Vector2(200, 300))
	prop("bookshelf", Vector2(860, 200))
	prop("shelf", Vector2(1010, 200))
	prop("dresser", Vector2(420, 200))
	prop("plant", Vector2(1210, 210))
	prop("plant", Vector2(90, 640), {"collide": false})
	prop("drawer", Vector2(1140, 200))
	prop("mat", Vector2(648, 480), {"collide": false})
	prop("table", Vector2(648, 320))
	prop("stool", Vector2(560, 360))
	prop("candle", Vector2(420, 150), {"collide": false, "light": Color(1.0, 0.7, 0.4), "energy": 1.4, "light_scale": 2.6})
	prop("candle", Vector2(760, 296), {"collide": false, "light": Color(1.0, 0.7, 0.4), "energy": 1.2, "light_scale": 2.2})
	prop("candle", Vector2(1010, 150), {"collide": false, "light": Color(1.0, 0.7, 0.4), "energy": 1.2, "light_scale": 2.2})
	var moon := Sheet.make_light(Color(0.5, 0.6, 1.0), 0.6, 5.0)
	moon.position = Vector2(150, 160)
	add_child(moon)

	helmet = add_interactable(P + "props/helmet_glow.png" if ResourceLoader.exists(P + "props/helmet_glow.png") else "res://assets/props/prop_helmet.png", Vector2(648, 300), "[E] Put on the helmet", 90.0, 1.0)
	helmet.enabled = false
	helmet.light_color = Color(0.5, 0.95, 1.0)
	helmet.used.connect(_on_helmet)

	npc = add_interactable("", Vector2(980, 400), "[E] Talk", 100.0)
	npc_sprite = AnimatedSprite2D.new()
	npc_sprite.sprite_frames = Sheet.character(P + "chars/npc")
	npc_sprite.play("idle_left")
	npc_sprite.scale = Vector2(3, 3)
	npc_sprite.position = Vector2(0, -12)
	npc_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	npc.add_child(npc_sprite)
	var shadow := Sprite2D.new()
	shadow.texture = load(P + "fx/shadow.png")
	shadow.scale = Vector2(3, 3)
	shadow.position = Vector2(0, 12)
	shadow.modulate = Color(0, 0, 0, 0.4)
	shadow.z_index = -1
	npc.add_child(shadow)
	var npc_body := StaticBody2D.new()
	var npc_shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 14.0
	npc_shape.shape = c
	npc_body.add_child(npc_shape)
	npc.add_child(npc_body)
	npc.used.connect(_on_talk)

	var door := add_interactable(P + "props/door.png", Vector2(648, 150), "[E] Door", 90.0, 3.0)
	door.used.connect(func(): say_line("The door doesn't open. Not from this side."))


func run() -> void:
	GameManager.reset_run()
	player.setup_for_level()
	GameManager.input_locked = true
	await wait(1.2)
	GameManager.input_locked = false
	await ui.say(["...", "Where am I?"], "You", "you", P + "chars/player_face.png")
	prompt("WASD to move. [E] to talk.")
	objective = npc


func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(npc_sprite) and is_instance_valid(player):
		var d := Sheet.dir_of(player.global_position - npc.global_position)
		if npc_sprite.animation != "idle_" + d:
			npc_sprite.play("idle_" + d)


func _on_talk() -> void:
	prompt("")
	if _talked:
		await ui.say(["The helmet. Please."], "Stranger", "stranger", P + "chars/npc_face.png")
		return
	_talked = true
	await ui.say([
		"You're awake. Good. Don't try to remember. Not yet.",
		"Three days ago the sky cracked open. They came through.",
		"Time is breaking. The pieces are scattered across it.",
		"Only you can walk between them. Don't ask me why.",
		"Put this on.",
	], "Stranger", "stranger", P + "chars/npc_face.png")
	helmet.enabled = true
	helmet.glow = true
	objective = helmet
	Events.tutorial_prompt.emit("[E] Put on the helmet")


func _on_helmet() -> void:
	prompt("")
	objective = null
	helmet.enabled = false
	GameManager.input_locked = true
	Audio.sfx("sfx_glitch")
	Audio.sfx("sfx_portal", 0.0, -4.0)
	Juice.chroma(0.03)
	Juice.flash(Color(0.8, 1, 1, 0.9), 0.8)
	Juice.shake(4.0, 0.5)
	await wait(0.6)
	GameManager.go_to_scene("tutorial")
