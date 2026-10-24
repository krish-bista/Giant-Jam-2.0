class_name Level
extends Node2D
## Base for every level: textured ground, world bounds, follow camera, lighting + glow,
## ambient particles and sound, the player, HUD/UI, music (explore + boss), and helpers.
## Each level script extends this and writes its flow in run().

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const S := 3.0   # pixel-art scale

var world_size := Vector2(2592, 1440)
var ground := ""
var music := ""
var boss_music := ""
var ambient := ""
var surface := "stone"
var ambient_color := Color(1, 1, 1)
var particles := ""          # rain, leaves, fireflies, sparks, dust, snow
var spawn_point := Vector2(640, 520)
var camera_follow := true
var scanlines := 0.0
var vignette := 0.4
var glow := true
var desaturate := 0.0
var screen_tint := Color.WHITE

var ARENA := Rect2(64, 64, 1152, 592)
var player: CharacterBody2D
var ui: GameUI
var camera: Camera2D
var alive: Array = []
var objective: Node2D = null
var weapon_pickup: Node2D = null
var ally: ReflectionAlly = null
var revives_here := true
var _keepout: Array = []     # [pos, radius] areas where scatter won't place props
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	y_sort_enabled = true
	_rng.seed = hash(scene_file_path)
	configure()
	ARENA = Rect2(Vector2(70, 90), world_size - Vector2(140, 150))
	Juice.reset_time()
	Juice.set_screen(vignette, scanlines, desaturate, screen_tint)
	_build_ground()
	_build_walls()
	_build_lighting()
	camera = Camera2D.new()
	camera.position = spawn_point if camera_follow else world_size * 0.5
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world_size.x)
	camera.limit_bottom = int(world_size.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.set_meta("base_zoom", 1.0)
	camera.top_level = true
	add_child(camera)
	camera.make_current()
	player = PLAYER_SCENE.instantiate()
	player.position = spawn_point
	add_child(player)
	player.get_node("Camera2D").enabled = false
	player.setup_for_level()
	if player.rig:
		player.rig.surface = surface
	keepout(spawn_point, 140.0)
	ui = GameUI.new()
	add_child(ui)
	Audio.music(music)
	Audio.ambient(ambient)
	_build_particles()
	Events.player_died.connect(_on_player_died)
	# World weapons belong to their world.
	if GameManager.weapon != "" and GameManager.weapon_world != GameManager.current_scene:
		GameManager.weapon = ""
		Events.weapon_changed.emit("")
	await get_tree().process_frame
	build_world()
	await get_tree().process_frame
	run()


## Override: set world_size, ground, music, lighting, spawn_point...
func configure() -> void:
	pass


## Override: place props and breakables (before run()).
func build_world() -> void:
	pass


## Override: the level's flow (can use await).
func run() -> void:
	pass


func _process(_delta: float) -> void:
	if camera_follow and is_instance_valid(player) and is_instance_valid(camera):
		if camera.has_meta("focus"):
			camera.position = camera.get_meta("focus")
		else:
			camera.position = player.global_position + player.facing_direction * 60.0


func _build_ground() -> void:
	if ground == "":
		return
	var bg := Sprite2D.new()
	bg.texture = load(ground)
	bg.centered = false
	bg.scale = Vector2(S, S)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.z_index = -20
	add_child(bg)


func _build_walls() -> void:
	var t := 400.0
	var r0 := Rect2(Vector2.ZERO, world_size)
	var rects := [
		Rect2(-t, -t, world_size.x + 2 * t, t + 60), Rect2(-t, world_size.y - 50, world_size.x + 2 * t, t),
		Rect2(-t, -t, t + 50, world_size.y + 2 * t), Rect2(world_size.x - 50, -t, t, world_size.y + 2 * t),
	]
	for r in rects:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)
		add_child(body)


func _build_lighting() -> void:
	var cm := CanvasModulate.new()
	cm.color = ambient_color
	add_child(cm)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = glow
	e.glow_intensity = 0.9
	e.glow_strength = 1.0
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 1.1
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	e.set_glow_level(1, 1.0)
	e.set_glow_level(2, 0.8)
	e.set_glow_level(3, 0.6)
	e.set_glow_level(4, 0.4)
	env.environment = e
	add_child(env)


func _build_particles() -> void:
	if particles == "":
		return
	var p := CPUParticles2D.new()
	p.amount = 140
	p.lifetime = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(760, 460)
	p.local_coords = false
	p.z_index = 40
	match particles:
		"rain":
			p.amount = 260
			p.lifetime = 0.7
			p.direction = Vector2(-0.25, 1)
			p.spread = 2.0
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 700.0
			p.initial_velocity_max = 900.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 1.5
			p.color = Color(0.6, 0.7, 1.0, 0.45)
			var tex := GradientTexture2D.new()
			tex.width = 2
			tex.height = 14
			var g := Gradient.new()
			g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1)])
			tex.gradient = g
			tex.fill_to = Vector2(0, 1)
			p.texture = tex
		"leaves":
			p.texture = load("res://assets/ninja/fx/particle_leaf.png")
			var m := CanvasItemMaterial.new()
			m.particles_animation = true
			m.particles_anim_h_frames = 6
			m.particles_anim_v_frames = 1
			p.material = m
			p.anim_offset_max = 1.0
			p.amount = 50
			p.lifetime = 6.0
			p.direction = Vector2(1, 0.4)
			p.gravity = Vector2(10, 25)
			p.initial_velocity_min = 20.0
			p.initial_velocity_max = 60.0
			p.angular_velocity_min = -90.0
			p.angular_velocity_max = 90.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 3.0
		"fireflies":
			p.amount = 60
			p.lifetime = 5.0
			p.gravity = Vector2.ZERO
			p.direction = Vector2.UP
			p.spread = 180.0
			p.initial_velocity_min = 6.0
			p.initial_velocity_max = 20.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 3.5
			p.color = Color(2.2, 2.4, 0.9, 0.9)
		"sparks":
			p.amount = 90
			p.lifetime = 3.0
			p.gravity = Vector2(0, -30)
			p.direction = Vector2.UP
			p.spread = 40.0
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 40.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.0
			p.color = Color(2.0, 0.8, 2.4, 0.8)
		"data":
			p.amount = 120
			p.lifetime = 2.4
			p.direction = Vector2(0, 1)
			p.spread = 0.0
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 120.0
			p.initial_velocity_max = 260.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
			p.color = Color(0.6, 1.8, 2.0, 0.55)
		"ash":
			p.amount = 120
			p.lifetime = 6.0
			p.direction = Vector2(0.3, 1)
			p.spread = 30.0
			p.gravity = Vector2(6, 14)
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 30.0
			p.angular_velocity_min = -60.0
			p.angular_velocity_max = 60.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.5
			p.color = Color(0.7, 0.66, 0.72, 0.6)
		"dust", "snow":
			p.amount = 70
			p.lifetime = 6.0
			p.gravity = Vector2(4, 6)
			p.direction = Vector2(1, 0.2)
			p.spread = 60.0
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 14.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.0
			p.color = Color(1.4, 1.3, 1.1, 0.5) if particles == "dust" else Color(1.6, 1.8, 2.0, 0.7)
	var holder := Node2D.new()
	holder.z_index = 40
	holder.top_level = true
	add_child(holder)
	holder.add_child(p)
	p.emitting = true
	set_meta("ambient_particles", p)


var flicker_lights: Array = []


func _physics_process(_delta: float) -> void:
	for l in flicker_lights:
		if is_instance_valid(l):
			l.energy = l.get_meta("base", 1.0) * (0.35 if randf() < 0.06 else randf_range(0.8, 1.1))
	if has_meta("ambient_particles") and is_instance_valid(camera):
		var p: CPUParticles2D = get_meta("ambient_particles")
		p.global_position = camera.get_screen_center_position() + Vector2(0, -80 if particles == "rain" else 0)


# ---------------- helpers for level scripts ----------------
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


## Shows a hint at the bottom of the screen and speaks it if a voice line exists.
func prompt(text: String) -> void:
	Events.tutorial_prompt.emit(text)
	if text != "":
		Voice.say(text, "system")


func say_line(text: String, speaker := "you", color := Color(0.9, 0.95, 1.0)) -> void:
	ui.show_subtitle(text, color)
	Voice.say(text, speaker)


func keepout(pos: Vector2, r: float) -> void:
	_keepout.append([pos, r])


func _free_at(pos: Vector2, r: float, placed: Array) -> bool:
	for k in _keepout:
		if pos.distance_to(k[0]) < k[1] + r:
			return false
	for q in placed:
		if pos.distance_to(q[0]) < q[1] + r:
			return false
	return true


## Scatter props of the given names inside rect, keeping clear of keep-out zones.
func scatter(names: Array, count: int, rect: Rect2, opts := {}, min_gap := 20.0) -> Array:
	var placed: Array = get_meta("placed", [])
	var made: Array = []
	for i in count:
		for _try in 25:
			var n: String = names[_rng.randi() % names.size()]
			var pos := Vector2(_rng.randf_range(rect.position.x, rect.end.x), _rng.randf_range(rect.position.y, rect.end.y))
			var tex: Texture2D = load("res://assets/ninja/props/%s.png" % n)
			var r: float = tex.get_width() * S * 0.45 + min_gap
			if not _free_at(pos, r, placed):
				continue
			var p := Prop.make(n, pos, opts)
			add_child(p)
			placed.append([pos, r])
			made.append(p)
			break
	set_meta("placed", placed)
	return made


## A thick border of props around the world edge (forest wall, ruins...).
func border(names: Array, spacing := 90.0, depth := 1, opts := {}) -> void:
	var placed: Array = get_meta("placed", [])
	for row in depth:
		var inset := 40.0 + row * 70.0
		var x := 0.0
		while x < world_size.x:
			for y in [inset, world_size.y - inset + 30.0]:
				var n: String = names[_rng.randi() % names.size()]
				var p := Prop.make(n, Vector2(x + _rng.randf_range(-20, 20), y + _rng.randf_range(-10, 10)), opts)
				add_child(p)
			x += spacing + _rng.randf_range(-15, 15)
		var y2 := inset + 60.0
		while y2 < world_size.y - 60.0:
			for xx in [inset - 10.0, world_size.x - inset + 10.0]:
				var n2: String = names[_rng.randi() % names.size()]
				var p2 := Prop.make(n2, Vector2(xx + _rng.randf_range(-10, 10), y2 + _rng.randf_range(-20, 20)), opts)
				add_child(p2)
			y2 += spacing * 0.8 + _rng.randf_range(-10, 10)
	set_meta("placed", placed)


func prop(name: String, pos: Vector2, opts := {}) -> Prop:
	var p := Prop.make(name, pos, opts)
	add_child(p)
	var placed: Array = get_meta("placed", [])
	var tex: Texture2D = load("res://assets/ninja/props/%s.png" % name)
	placed.append([pos, tex.get_width() * S * 0.45])
	set_meta("placed", placed)
	return p


func breakable(kind: String, pos: Vector2) -> Breakable:
	var b := Breakable.make(kind, pos)
	add_child(b)
	return b


## A small cluster of breakables (with the odd explosive barrel).
func crate_cluster(center: Vector2, kinds: Array, n := 5, explosive_chance := 0.25) -> void:
	for i in n:
		var k: String = kinds[_rng.randi() % kinds.size()]
		if _rng.randf() < explosive_chance:
			k = "explosive"
		breakable(k, center + Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-40, 40)))


func spawn(type_id: String, pos: Vector2, overrides := {}) -> Enemy:
	var e := Enemy.new()
	e.setup(type_id, overrides)
	e.arena = ARENA
	e.mirror_center_x = world_size.x * 0.5
	e.global_position = pos
	add_child(e)
	alive.append(e)
	e.died.connect(func(x): alive.erase(x))
	Juice.fx("smoke_circular", pos, 2.5, 0.0, Color(1.2, 1.2, 1.4, 0.8))
	return e


func spawn_boss(boss_id: String, pos: Vector2) -> Boss:
	if boss_music != "":
		Audio.music(boss_music, 0.5)
	focus_camera(pos, 2.0)
	ui.letterbox(true)
	var b := Boss.new()
	b.setup_boss(boss_id)
	b.arena = ARENA
	b.global_position = pos
	add_child(b)
	get_tree().create_timer(2.0, false).timeout.connect(func(): if is_instance_valid(ui): ui.letterbox(false))
	b.died.connect(func(_x): if music != "": Audio.music(music, 1.5))
	return b


func focus_camera(pos: Vector2, seconds: float) -> void:
	camera.set_meta("focus", pos)
	Juice.zoom_punch(0.1)
	get_tree().create_timer(seconds, false).timeout.connect(func():
		if is_instance_valid(camera):
			camera.remove_meta("focus"))


## Spawn point near the player but off-screen-ish, inside the world.
func edge_point(min_dist := 420.0) -> Vector2:
	var center: Vector2 = player.global_position if is_instance_valid(player) else world_size * 0.5
	for i in 30:
		var p := center + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(min_dist, min_dist + 220.0)
		if ARENA.has_point(p):
			return p
	return ARENA.get_center()


func wait_clear() -> void:
	while true:
		alive = alive.filter(func(e): return is_instance_valid(e) and not e._dead)
		if alive.is_empty():
			return
		await get_tree().create_timer(0.25, false).timeout


func add_portal(target: String, pos: Vector2, is_final := false) -> Portal:
	var p := Portal.new()
	p.target_scene = target
	p.final = is_final
	p.position = pos
	add_child(p)
	objective = p
	return p


func add_interactable(tex_path: String, pos: Vector2, text: String, reach := 70.0, scale := 3.0) -> Interactable:
	var it := Interactable.new()
	if tex_path != "":
		it.texture = load(tex_path)
	it.prompt = text
	it.reach = reach
	it.position = pos
	it.sprite_scale = scale
	add_child(it)
	return it


## A lore stone you can read (voiced as an echo).
func lore(pos: Vector2, text: String) -> Interactable:
	var it := add_interactable("res://assets/ninja/props/sign.png", pos, "[E] Read", 70.0, 3.0)
	it.glow = true
	it.used.connect(func():
		ui.show_subtitle(text, Color(0.85, 0.85, 1.0))
		Voice.say(text, "echo"))
	return it


func add_chest(pos: Vector2) -> Interactable:
	var c := add_interactable("res://assets/ninja/props/chest_closed.png", pos, "[E] Open", 64.0, 3.0)
	c.one_shot = true
	c.glow = true
	keepout(pos, 60.0)
	c.used.connect(func():
		c.sprite.texture = load("res://assets/ninja/props/chest_open.png")
		c.glow = false
		Audio.sfx("sfx_chest_open")
		Audio.sfx("sfx_coin", 0.05, -4.0)
		Juice.fx("circle_spark", pos, 3.0, 0.0, Color(2.0, 1.7, 0.8))
		Juice.light_flash(pos, Color(1, 0.85, 0.4), 2.0, 2.0, 0.5)
		var id := GameManager.roll_artifact("chest")
		if id != "":
			Pickup.spawn_artifact(self, pos + Vector2(0, 40), id)
		else:
			Pickup.spawn_heal(self, pos + Vector2(0, 40), 25.0))
	return c


# ---------------- death, graves, revives ----------------
func _on_player_died() -> void:
	if not revives_here:
		return
	var pos := player.global_position
	GameManager.deaths += 1
	GameManager.break_combo()
	var grave := Prop.make("grave_mound", pos, {"collide": false, "light": Color(0.6, 0.8, 1.0), "energy": 0.6, "light_scale": 0.8})
	add_child(grave)
	grave.scale = Vector2(1, 0.1)
	create_tween().tween_property(grave, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	Audio.sfx("sfx_grave", 0.0, -2.0)
	Juice.set_screen(0.7, 0.0, 0.85, Color(0.9, 0.9, 1.0))
	ui.show_death(GameManager.deaths)
	await get_tree().create_timer(2.4, false).timeout
	if not is_instance_valid(player):
		return
	Juice.set_screen(vignette, scanlines, desaturate, screen_tint)
	player.revive(pos + Vector2(0, 44), 0.6)
	Events.player_revived.emit(GameManager.deaths)
	if GameManager.deaths == 1:
		ui.show_subtitle("An echo can't die. It only repeats.", Color(0.9, 0.9, 1.0))
		var l := Voice.say("An echo can't die. It only repeats.", "stranger")
		await wait(maxf(l, 1.5) + 0.3)
		ui.show_subtitle("But every return leaves less of you, and more of your reflection.", Color(0.9, 0.9, 1.0))
		Voice.say("But every return leaves less of you, and more of your reflection.", "stranger")
	elif GameManager.deaths == GameManager.EVIL_AT:
		ui.show_subtitle("Careful. There's more reflection in you than you now.", Color(1, 0.6, 0.6))
		Voice.say("Careful. There's more reflection in you than you now.", "stranger")
	elif GameManager.deaths == GameManager.RABID_AT:
		_go_rabid()
	if GameManager.is_rabid():
		Juice.set_screen(0.6, scanlines, 0.25, Color(1.1, 0.85, 0.85))


func _go_rabid() -> void:
	Events.announce.emit("SANITY LOST")
	Voice.say("SANITY LOST", "system")
	Audio.sfx("sfx_heartbeat", 0.0, 2.0)
	Juice.flash(Color(1, 0, 0, 0.5), 0.6)
	Juice.chroma(0.03)
	player.set_rabid(true)
	await wait(1.6)
	say_line("Something's wrong with me... I can't stop.", "you", Color(1, 0.5, 0.5))


# ---------------- ally, weapons, titles, objectives ----------------
## Your reflection steps out of a mirror to fight beside you (not while rabid).
func summon_ally(first_line := false) -> void:
	if GameManager.is_rabid() or is_instance_valid(ally):
		return
	ally = ReflectionAlly.new()
	ally.global_position = player.global_position + Vector2(-60, 10)
	add_child(ally)
	var line := "I'm your reflection. The part of you that still wants to save them. Let's go." if first_line else "I'm still with you."
	ui.show_subtitle(line, Color(0.6, 0.95, 1.0))
	Voice.say(line, "reflection")


func place_weapon(id: String, pos: Vector2) -> void:
	if GameManager.weapon == id:
		return
	var w := WeaponPickup.new()
	w.weapon_id = id
	w.position = pos
	add_child(w)
	weapon_pickup = w
	keepout(pos, 90.0)


func title_card(title: String, subtitle: String, narration: String) -> void:
	ui.title_card(title, subtitle)
	Voice.say(narration, "narrator")


func set_objective(text: String) -> void:
	Events.objective_changed.emit(text)


func _clear_prompt_later(seconds: float) -> void:
	await wait(seconds)
	Events.tutorial_prompt.emit("")


func player_alive() -> bool:
	return is_instance_valid(player) and not player.is_dead()
