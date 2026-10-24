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


## The one scene switch everybody uses.
func go_to_scene(scene_name: String) -> void:
	if _switching or not SCENES.has(scene_name):
		if not SCENES.has(scene_name):
			push_error("Unknown scene: " + scene_name)
		return
	_switching = true
	input_locked = true
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
	var t2 := create_tween()
	t2.tween_property(_fade, "modulate:a", 0.0, 0.35)


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
