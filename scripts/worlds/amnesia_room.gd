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

	var solid := {"solid": true}
	prop("bed", Vector2(200, 310), solid)
	prop("bookshelf", Vector2(860, 210), solid)
	prop("shelf", Vector2(1010, 210), solid)
	prop("dresser", Vector2(420, 210), solid)
	prop("plant", Vector2(1210, 210), solid)
	prop("plant", Vector2(90, 640), solid)
	prop("drawer", Vector2(1140, 210), solid)
	prop("mat", Vector2(648, 470), {"decal": true})
	prop("table", Vector2(648, 330), solid)
	prop("stool", Vector2(560, 380), solid)
	prop("candle", Vector2(420, 150), {"collide": false, "light": Color(1.0, 0.7, 0.4), "energy": 1.4, "light_scale": 2.6})
	prop("candle", Vector2(760, 296), {"collide": false, "light": Color(1.0, 0.7, 0.4), "energy": 1.2, "light_scale": 2.2})
	prop("candle", Vector2(1010, 150), {"collide": false, "light": Color(1.0, 0.7, 0.4), "energy": 1.2, "light_scale": 2.2})
	var moon := Sheet.make_light(Color(0.5, 0.6, 1.0), 0.6, 5.0)
	moon.position = Vector2(150, 160)
	add_child(moon)

	# The VR helmet rests on the table (drawn above it; the table blocks you).
	helmet = add_interactable(P + "props/vr_helmet.png", Vector2(648, 300), "[E] Put on the helmet", 110.0, 3.0)
	helmet.z_index = 2
	helmet.enabled = false
	helmet.light_color = Color(0.4, 0.95, 1.0)
	helmet.used.connect(_on_helmet)
	_build_helmet_fx()

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


var _helmet_ring: Line2D
var _helmet_scan: Line2D


## High-tech touches: a holographic ring spinning over the helmet and a scan line sweeping it.
func _build_helmet_fx() -> void:
	_helmet_ring = Line2D.new()
	var pts := PackedVector2Array()
	for k in 33:
		var a := k * TAU / 32.0
		pts.append(Vector2(cos(a) * 34.0, sin(a) * 10.0))
	_helmet_ring.points = pts
	_helmet_ring.width = 2.0
	_helmet_ring.default_color = Color(0.4, 0.95, 1.0, 0.7)
	_helmet_ring.position = Vector2(0, -58)
	helmet.add_child(_helmet_ring)
	_helmet_scan = Line2D.new()
	_helmet_scan.points = PackedVector2Array([Vector2(-26, 0), Vector2(26, 0)])
	_helmet_scan.width = 2.0
	_helmet_scan.default_color = Color(0.6, 1.0, 1.0, 0.8)
	helmet.add_child(_helmet_scan)
	var motes := CPUParticles2D.new()
	motes.amount = 14
	motes.lifetime = 1.4
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(22, 4)
	motes.position = Vector2(0, -20)
	motes.direction = Vector2.UP
	motes.gravity = Vector2(0, -30)
	motes.initial_velocity_min = 6.0
	motes.initial_velocity_max = 18.0
	motes.scale_amount_min = 1.5
	motes.scale_amount_max = 2.5
	motes.color = Color(0.5, 1.0, 1.0, 0.8)
	helmet.add_child(motes)


func run() -> void:
	GameManager.reset_run()
	player.setup_for_level()
	GameManager.input_locked = true
	await wait(1.2)
	GameManager.input_locked = false
	await ui.say(["...", "Where am I?"], "You", "you", P + "chars/player_face.png")
	Events.tutorial_prompt.emit("WASD to move. [E] to talk.")
	set_objective("Talk to the stranger")
	objective = npc


func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(_helmet_ring):
		var t := Time.get_ticks_msec() * 0.001
		_helmet_ring.rotation = 0.0
		_helmet_ring.scale = Vector2(1.0 + 0.08 * sin(t * 3.0), 1.0)
		_helmet_ring.position.y = -58 + sin(t * 2.0) * 3.0
		_helmet_ring.default_color.a = 0.45 + 0.3 * sin(t * 4.0)
		_helmet_scan.position.y = -10 - 40.0 * fposmod(t * 0.8, 1.0)
		_helmet_scan.default_color.a = 0.8 * (1.0 - fposmod(t * 0.8, 1.0))
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
		"Something broke time. Now it runs backwards, like a reflection in a mirror.",
		"In a reversed world the hunter becomes the hunted, and every blow comes back to the one who struck it.",
		"This helmet lets you walk the broken timelines, back to the moment it all cracked.",
		"Find the crack. Close it. Whatever it costs.",
		"Put this on.",
	], "Stranger", "stranger", P + "chars/npc_face.png")
	helmet.enabled = true
	helmet.glow = true
	objective = helmet
	set_objective("Put on the helmet")
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
	GameManager.go_to_scene("tutorial", "mirror")
