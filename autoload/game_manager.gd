extends Node
## Scene flow + run state that survives scene changes (stats, artifacts, unlocks).

const SCENES := {
	"amnesia_room": "res://scenes/levels/amnesia_room.tscn",
	"tutorial": "res://scenes/levels/tutorial.tscn",
	"world1": "res://scenes/levels/world1.tscn",
	"world2": "res://scenes/levels/world2.tscn",
	"world3": "res://scenes/levels/world3.tscn",
	"final": "res://scenes/levels/final.tscn",
	"ending": "res://scenes/levels/ending.tscn",
}
const BASE_STATS := {"max_health": 100.0, "damage": 10.0, "speed": 220.0, "reflect_power": 1.0, "luck": 0.0}

var stats := {}
var health := 100.0
var artifacts: Array[String] = []
var flags := {}
var has_sword := false
var has_shield := false
var hypno_unlocked := false
var input_locked := false
var current_scene := ""
var run_time := 0.0
var combo := 0
var best_combo := 0
var _combo_timer := 0.0
const COMBO_WINDOW := 2.5
## Deaths: you leave a grave and revive. 3 deaths = the Reflection (evil) ending; 4+ = rabid.
const EVIL_AT := 3
const RABID_AT := 4
var deaths := 0
## The current world's special weapon ("" = none). It changes when you enter another world.
var weapon := ""
var weapon_world := ""
var _flip: ColorRect
var _flip_mat: ShaderMaterial

var _snapshot := {}
var _switching := false
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_run()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.modulate.a = 0.0
	layer.add_child(_fade)
	var flip_layer := CanvasLayer.new()
	flip_layer.layer = 99
	add_child(flip_layer)
	_flip = ColorRect.new()
	_flip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flip_mat = ShaderMaterial.new()
	_flip_mat.shader = preload("res://assets/shaders/mirror_flip.gdshader")
	_flip.material = _flip_mat
	_flip.visible = false
	flip_layer.add_child(_flip)
	_detect_start_scene.call_deferred()
	if OS.get_environment("ECHO_BOT") == "1":
		var bot: Node = load("res://tools/playtest_bot.gd").new()
		add_child(bot)


func _process(delta: float) -> void:
	if not get_tree().paused:
		run_time += delta / maxf(Engine.time_scale, 0.01)
		if combo > 0:
			_combo_timer -= delta
			if _combo_timer <= 0.0:
				break_combo()


## Combo: every hit you land adds to it; it decays after a short pause and breaks when you get hit.
func add_combo(amount := 1) -> void:
	var before := combo
	combo += amount
	best_combo = maxi(best_combo, combo)
	_combo_timer = COMBO_WINDOW
	Events.combo_changed.emit(combo)
	for tier in [10, 25, 50]:
		if before < tier and combo >= tier:
			Audio.sfx("sfx_combo_3", 0.0, -2.0)
			return
	Audio.sfx("sfx_combo_%d" % (1 + mini(combo / 10, 1)), 0.05, -12.0)


func break_combo() -> void:
	if combo == 0:
		return
	combo = 0
	Events.combo_changed.emit(0)


## Damage multiplier from the current combo (+1% per hit, up to +50%).
func combo_bonus() -> float:
	return 1.0 + minf(combo, 50) * 0.01


func _detect_start_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for key in SCENES:
		if SCENES[key] == scene.scene_file_path:
			current_scene = key
	_take_snapshot()


func reset_run() -> void:
	stats = BASE_STATS.duplicate()
	health = stats.max_health
	artifacts.clear()
	flags.clear()
	has_sword = false
	has_shield = false
	hypno_unlocked = false
	input_locked = false
	run_time = 0.0
	combo = 0
	best_combo = 0
	deaths = 0
	weapon = ""
	weapon_world = ""


func sanity() -> int:
	return maxi(0, EVIL_AT - deaths)


func is_rabid() -> bool:
	return deaths >= RABID_AT


func ending_type() -> String:
	# Dying too often, or letting time run out at the last mirror, lets the reflection win.
	return "evil" if deaths >= EVIL_AT or has_flag("reflection_won") else "divine"


## The one scene switch everybody uses. transition: "fade", "mirror" (the reversal flip) or
## "shatter" (time ran out: the screen cracks, light breaks through and it falls apart).
func go_to_scene(scene_name: String, transition := "fade") -> void:
	if _switching or not SCENES.has(scene_name):
		if not SCENES.has(scene_name):
			push_error("Unknown scene: " + scene_name)
		return
	_switching = true
	input_locked = true
	if transition == "mirror":
		await _mirror_out()
	elif transition == "shatter":
		await _shatter_out()
	else:
		var t := create_tween()
		t.tween_property(_fade, "modulate:a", 1.0, 0.35)
		await t.finished
	Engine.time_scale = 1.0
	Juice.reset_time()
	Voice.stop()
	get_tree().paused = false
	combo = 0
	current_scene = scene_name
	get_tree().change_scene_to_file(SCENES[scene_name])
	await get_tree().process_frame
	await get_tree().process_frame
	_take_snapshot()
	input_locked = false
	_switching = false
	if transition == "mirror":
		_mirror_in()
	elif transition == "shatter":
		_shatter_in()
	else:
		var t2 := create_tween()
		t2.tween_property(_fade, "modulate:a", 0.0, 0.35)


## The world flips into its own reflection, collapses to a bright seam, and goes white.
func _mirror_out() -> void:
	Audio.sfx("sfx_hypno_reverse", 0.0, -2.0)
	Audio.sfx("sfx_portal", 0.0, -4.0)
	_flip_mat.set_shader_parameter("progress", 0.0)
	_flip.visible = true
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_method(func(v): _flip_mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	_fade.color = Color(0.85, 0.97, 1.0)
	var t2 := create_tween()
	t2.set_ignore_time_scale(true)
	t2.tween_property(_fade, "modulate:a", 1.0, 0.15)
	await t2.finished


## The new world starts mirrored and turns the right way round.
func _mirror_in() -> void:
	_flip_mat.set_shader_parameter("progress", 1.0)
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(_fade, "modulate:a", 0.0, 0.2)
	t.tween_method(func(v): _flip_mat.set_shader_parameter("progress", v), 1.0, 0.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func():
		_flip.visible = false
		_fade.color = Color.BLACK)


## Time ran out: freeze the frame, crack it from the center (white light leaks through the
## seams), then the pieces burst apart and fall away into white.
func _shatter_out() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var tex := ImageTexture.create_from_image(img)
	var vs := get_viewport().get_visible_rect().size
	var k := Vector2(img.get_width(), img.get_height()) / vs
	var layer := CanvasLayer.new()
	layer.layer = 98
	add_child(layer)
	var light := ColorRect.new()
	light.color = Color(1.0, 1.0, 1.0)
	light.size = vs
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(light)
	var root := Node2D.new()
	layer.add_child(root)
	# Crack pattern: rays from the center crossed by jagged rings; neighbours share corners.
	var c := vs * 0.5
	var rays := 15
	var radii := [55.0, 140.0, 270.0, 440.0, 700.0, 1100.0]
	var base := randf() * TAU
	var angs: Array[float] = []
	for j in rays:
		angs.append(base + (j + randf_range(-0.3, 0.3)) * TAU / rays)
	var grid: Array = []
	for ri in radii.size():
		var row: Array[Vector2] = []
		for j in rays:
			row.append(c + Vector2.from_angle(angs[j] + randf_range(-0.1, 0.1)) * radii[ri] * randf_range(0.85, 1.15))
		grid.append(row)
	var polys: Array = []
	for j in rays:
		var j2 := (j + 1) % rays
		polys.append([c, grid[0][j], grid[0][j2]])
		for ri in radii.size() - 1:
			polys.append([grid[ri][j], grid[ri][j2], grid[ri + 1][j2], grid[ri + 1][j]])
	var shards: Array[Polygon2D] = []
	var segs: Array = []
	for pts in polys:
		var cen := Vector2.ZERO
		for p in pts:
			cen += p
		cen /= pts.size()
		var local := PackedVector2Array()
		var uv := PackedVector2Array()
		for p in pts:
			local.append(p - cen)
			uv.append(p * k)
		var s := Polygon2D.new()
		s.texture = tex
		s.polygon = local
		s.uv = uv
		s.position = cen
		s.set_meta("dir", (cen - c).normalized() if cen.distance_to(c) > 1.0 else Vector2.UP)
		root.add_child(s)
		shards.append(s)
		for i in pts.size():
			segs.append([pts[i], pts[(i + 1) % pts.size()]])
	var cracks := Node2D.new()
	cracks.set_meta("grow", 0.0)
	cracks.draw.connect(func():
		var g: float = cracks.get_meta("grow")
		for sg in segs:
			if sg[0].distance_to(c) < g and sg[1].distance_to(c) < g + 80.0:
				cracks.draw_line(sg[0], sg[1], Color(1, 1, 1, 0.95), 2.5, true))
	layer.add_child(cracks)
	# 1) cracks run out from the center
	Audio.sfx("sfx_crack", 0.0, 2.0, 1.0)
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_method(func(v: float):
		cracks.set_meta("grow", v)
		cracks.queue_redraw(), 0.0, 1300.0, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await t.finished
	# 2) the pieces separate: light leaks through every seam
	Audio.sfx("sfx_crack", 0.0, 2.0, 0.7)
	var t2 := create_tween()
	t2.set_ignore_time_scale(true)
	t2.set_parallel(true)
	for s in shards:
		t2.tween_property(s, "position", s.position + s.get_meta("dir") * randf_range(4.0, 12.0), 0.22)
	t2.tween_property(cracks, "modulate:a", 0.0, 0.22)
	await t2.finished
	# 3) shatter: everything flies apart and falls into the light
	Audio.sfx("sfx_shatter_big", 0.0, 2.0)
	Audio.sfx("sfx_mirror_shatter", 0.05, 0.0, 0.8)
	var t3 := create_tween()
	t3.set_ignore_time_scale(true)
	t3.set_parallel(true)
	for s in shards:
		var d: Vector2 = s.get_meta("dir")
		var dist := s.position.distance_to(c)
		var dur := randf_range(0.6, 1.0) + dist * 0.0003
		t3.tween_property(s, "position", s.position + d * randf_range(220.0, 620.0) + Vector2(0, randf_range(160.0, 520.0)), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t3.tween_property(s, "rotation", randf_range(-2.6, 2.6), dur)
		t3.tween_property(s, "scale", Vector2.ONE * randf_range(0.5, 0.8), dur)
		t3.tween_property(s, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await t3.finished
	_fade.color = Color(1, 1, 1)
	_fade.modulate.a = 1.0
	layer.queue_free()


## The next world comes back out of the white.
func _shatter_in() -> void:
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_interval(0.15)
	t.tween_property(_fade, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): _fade.color = Color.BLACK)


## Game over -> restart the current scene with the state you entered it with.
func retry_scene() -> void:
	if _snapshot.is_empty():
		return
	stats = _snapshot.stats.duplicate()
	health = stats.max_health
	artifacts = _snapshot.artifacts.duplicate()
	flags = _snapshot.flags.duplicate()
	has_sword = _snapshot.has_sword
	has_shield = _snapshot.has_shield
	hypno_unlocked = _snapshot.hypno_unlocked
	var target := current_scene
	current_scene = ""
	go_to_scene(target)


func _take_snapshot() -> void:
	_snapshot = {
		"stats": stats.duplicate(), "artifacts": artifacts.duplicate(), "flags": flags.duplicate(),
		"has_sword": has_sword, "has_shield": has_shield, "hypno_unlocked": hypno_unlocked,
	}


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func apply_artifact(id: String) -> void:
	if not ArtifactData.ALL.has(id) or id in artifacts:
		return
	var data: Dictionary = ArtifactData.ALL[id]
	artifacts.append(id)
	for stat in data.mods:
		stats[stat] = stats[stat] + data.mods[stat]
		if stat == "max_health":
			stats.max_health = maxf(stats.max_health, 20.0)
			health = clampf(health + maxf(data.mods[stat], 0.0), 1.0, stats.max_health)
	if data.flag != "":
		flags[data.flag] = true
	var info := data.duplicate()
	info["id"] = id
	Events.artifact_picked.emit(info)
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("sync_stats"):
		player.sync_stats()


## Picks an artifact the player doesn't own yet. Returns "" when none are left.
func roll_artifact(source: String) -> String:
	var weights: Array = ArtifactData.WEIGHTS.get(source, ArtifactData.WEIGHTS.enemy).duplicate()
	var luck: float = stats.luck
	if source == "enemy" or source == "chest":
		weights[0] = maxf(weights[0] - luck, 0.0)
		weights[1] += luck * 0.5
		weights[2] += luck * 0.5
	var pools := {"common": [], "rare": [], "epic": []}
	for id in ArtifactData.ALL:
		if id in artifacts:
			continue
		if id == "hypno_lens" and not hypno_unlocked:
			continue
		if id == "double_reflection" and source != "boss":
			continue
		pools[ArtifactData.ALL[id].rarity].append(id)
	var rarities := ["common", "rare", "epic"]
	for _attempt in 3:
		var total := 0.0
		for i in 3:
			if not pools[rarities[i]].is_empty():
				total += weights[i]
		if total <= 0.0:
			break
		var roll := randf() * total
		for i in 3:
			if pools[rarities[i]].is_empty():
				continue
			roll -= weights[i]
			if roll <= 0.0:
				return pools[rarities[i]].pick_random()
	# Fallback: anything left.
	for r in rarities:
		if not pools[r].is_empty():
			return pools[r].pick_random()
	return ""
