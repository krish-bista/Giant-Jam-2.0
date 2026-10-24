class_name Level
extends Node2D
## Base for every level: background, arena walls, fixed camera, player, HUD/UI, music.
## Each level script extends this and writes its flow in run().

const ARENA := Rect2(64, 64, 1152, 592)   # where characters can stand
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var background := ""
var music := ""
var spawn_point := Vector2(640, 520)

var player: CharacterBody2D
var ui: GameUI
var camera: Camera2D
var alive: Array = []


func _ready() -> void:
	configure()
	Juice.reset_time()
	if background != "":
		var bg := Sprite2D.new()
		bg.texture = load(background)
		bg.centered = false
		bg.z_index = -20
		add_child(bg)
	_build_walls()
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	add_child(camera)
	camera.make_current()
	player = PLAYER_SCENE.instantiate()
	player.position = spawn_point
	add_child(player)
	player.get_node("Camera2D").enabled = false
	player.setup_for_level()
	ui = GameUI.new()
	add_child(ui)
	Audio.music(music)
	await get_tree().process_frame
	run()


## Override: set background, music, spawn_point.
func configure() -> void:
	pass


## Override: the level's flow (can use await).
func run() -> void:
	pass


func _build_walls() -> void:
	var t := 200.0
	var rects := [
		Rect2(ARENA.position.x - t, ARENA.position.y - t - 16, ARENA.size.x + 2 * t, t),
		Rect2(ARENA.position.x - t, ARENA.end.y + 16, ARENA.size.x + 2 * t, t),
		Rect2(ARENA.position.x - t - 16, ARENA.position.y - t, t, ARENA.size.y + 2 * t),
		Rect2(ARENA.end.x + 16, ARENA.position.y - t, t, ARENA.size.y + 2 * t),
	]
	for r in rects:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)
		add_child(body)


# ---------------- helpers for level scripts ----------------
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func prompt(text: String) -> void:
	Events.tutorial_prompt.emit(text)


func spawn(type_id: String, pos: Vector2, overrides := {}) -> Enemy:
	var e := Enemy.new()
	e.setup(type_id, overrides)
	e.arena = ARENA
	e.global_position = pos
	add_child(e)
	alive.append(e)
	e.died.connect(func(x): alive.erase(x))
	Juice.burst(pos, Color(1, 1, 1, 0.8), 10, 100.0)
	return e


func spawn_boss(boss_id: String, pos: Vector2) -> Boss:
	var b := Boss.new()
	b.setup_boss(boss_id)
	b.arena = ARENA
	b.global_position = pos
	add_child(b)
	return b


func edge_point(min_dist_from_player := 260.0) -> Vector2:
	for i in 20:
		var side := randi() % 4
		var p := Vector2.ZERO
		match side:
			0: p = Vector2(randf_range(ARENA.position.x + 40, ARENA.end.x - 40), ARENA.position.y + 30)
			1: p = Vector2(randf_range(ARENA.position.x + 40, ARENA.end.x - 40), ARENA.end.y - 30)
			2: p = Vector2(ARENA.position.x + 30, randf_range(ARENA.position.y + 40, ARENA.end.y - 40))
			_: p = Vector2(ARENA.end.x - 30, randf_range(ARENA.position.y + 40, ARENA.end.y - 40))
		if player == null or p.distance_to(player.global_position) >= min_dist_from_player:
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
	return p


func add_interactable(tex_path: String, pos: Vector2, text: String, reach := 70.0, scale := 1.0) -> Interactable:
	var it := Interactable.new()
	if tex_path != "":
		it.texture = load(tex_path)
	it.prompt = text
	it.reach = reach
	it.position = pos
	it.scale = Vector2(scale, scale)
	add_child(it)
	return it


func add_chest(pos: Vector2) -> Interactable:
	var c := add_interactable("res://assets/props/prop_chest_closed.png", pos, "[E] Open", 64.0)
	c.one_shot = true
	c.glow = true
	c.used.connect(func():
		c.sprite.texture = load("res://assets/props/prop_chest_open.png")
		c.glow = false
		Audio.sfx("sfx_chest_open")
		Juice.burst(pos, Color(1, 0.85, 0.4), 18, 160.0)
		var id := GameManager.roll_artifact("chest")
		if id != "":
			Pickup.spawn_artifact(self, pos + Vector2(0, 40), id)
		else:
			Pickup.spawn_heal(self, pos + Vector2(0, 40), 25.0))
	return c


func player_alive() -> bool:
	return is_instance_valid(player) and not player.is_dead()
