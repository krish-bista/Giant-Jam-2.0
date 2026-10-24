class_name TimeRift
extends Node2D
## The world clock. Time runs backwards here: as it drains, the world's edges revert into a
## see-through mirror that closes in, and nobody (player, ally, enemies, bosses) can cross it.
## Beat the world in time and the edges pull back and the mirror opens in the center.
## Run out and the light breaks through, the world cracks and shatters, and you are thrown
## into the next fragment.

signal expired

const MARGIN := 22.0          # how far inside the mirror seam bodies are kept

var level: Level
var duration := 90.0
var left := 90.0
var running := false
var cleared := false
var collapsed := false
## Rectangle mode (worlds): the boundary shrinks from full_rect toward end_size.
var full_rect := Rect2()
var end_size := Vector2(1240, 700)
var bounds := Rect2()
## Circle mode (the final mirror platform).
var circle := false
var center := Vector2.ZERO
var full_radius := 380.0
var end_radius := 230.0
var radius := 380.0
var outer_radius := 400.0

var _on := 0.0
var _restore := 0.0           # 0..1: edges pulling back after a clear
var _surge := 0.0             # extra squeeze during the collapse
var _warned := {}
var _hud: ClockHud
var _last_sec := -1


func _ready() -> void:
	process_physics_priority = 100   # clamp after everyone has moved
	left = duration
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_hud = ClockHud.new()
	_hud.rift = self
	layer.add_child(_hud)


func setup_rect(rect: Rect2, end: Vector2 = Vector2.ZERO) -> void:
	circle = false
	full_rect = rect
	if end != Vector2.ZERO:
		end_size = end
	end_size = Vector2(minf(end_size.x, rect.size.x), minf(end_size.y, rect.size.y))
	bounds = rect


func setup_circle(c: Vector2, r_full: float, r_end: float) -> void:
	circle = true
	center = c
	full_radius = r_full
	end_radius = r_end
	radius = r_full
	outer_radius = r_full + 24.0


func start() -> void:
	running = true
	_hud.appear()


## How much of the clock has drained (0 = full, 1 = none left).
func progress() -> float:
	return clampf(1.0 - left / maxf(duration, 0.01), 0.0, 1.0)


func _ticking() -> bool:
	if not running or cleared or collapsed or get_tree().paused:
		return false
	if not is_instance_valid(level) or not is_instance_valid(level.ui):
		return false
	# Dialogue and cutscenes stop the clock.
	return not (level.ui._dlg_active or level.ui._cut_active)


func _process(delta: float) -> void:
	if _ticking():
		left = maxf(0.0, left - delta)
		_on = minf(1.0, _on + delta * 1.5)
		_tick_sounds()
		_milestones()
		if left <= 0.0:
			_expire()
	_update_bounds()
	_push_screen()


func _update_bounds() -> void:
	var s := pow(progress(), 1.3) * (1.0 - _restore) + _surge
	s = clampf(s, 0.0, 1.25)
	if circle:
		radius = lerpf(full_radius, end_radius, s)
	else:
		var size := full_rect.size.lerp(end_size, minf(s, 1.0))
		if s > 1.0:
			size *= 1.0 - (s - 1.0) * 0.6
		bounds = Rect2(full_rect.get_center() - size * 0.5, size)


func _push_screen() -> void:
	var warn := clampf((15.0 - left) / 15.0, 0.0, 1.0) if not cleared else 0.0
	if collapsed:
		warn = 1.0
	var on := _on * (1.0 - _restore)
	if circle:
		Juice.mirror_edge_circle(center, radius, outer_radius, on, warn)
	else:
		Juice.mirror_edge(bounds, on, warn)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(level):
		return
	var inner := bounds.grow(-MARGIN)
	if circle:
		inner = Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	level.ARENA = inner
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not ("arena" in e):
			continue
		e.arena = inner
		if circle:
			_clamp_circle(e, float(e.get("radius")) if e.get("radius") != null else 16.0)
	var keep: Array = []
	if is_instance_valid(level.player):
		keep.append(level.player)
	keep.append_array(get_tree().get_nodes_in_group("ally"))
	for n in keep:
		if not is_instance_valid(n):
			continue
		if circle:
			_clamp_circle(n, 14.0)
		else:
			n.global_position = n.global_position.clamp(inner.position, inner.end)
	if circle:
		return
	# Loot the mirror reaches slides inward so it never gets lost in the glass.
	var safe := bounds.grow(-70.0)
	for group in ["pickup", "weapon_pickup"]:
		for p in get_tree().get_nodes_in_group(group):
			if p is Node2D and is_instance_valid(p) and not safe.has_point(p.global_position):
				p.global_position = p.global_position.move_toward(p.global_position.clamp(safe.position, safe.end), 260.0 * delta)
	# Signs and chests swallowed by the mirror go dark (and wake up again if it pulls back).
	var reach := bounds.grow(-10.0)
	for it in get_tree().get_nodes_in_group("interactable"):
		if not (it is Interactable) or not is_instance_valid(it):
			continue
		var inside := reach.has_point(it.global_position)
		if not inside and it.enabled:
			it.enabled = false
			it.set_meta("rift_off", true)
			it.modulate = Color(0.6, 0.75, 0.9, 0.55)
		elif inside and it.has_meta("rift_off"):
			it.remove_meta("rift_off")
			it.enabled = true
			it.modulate = Color.WHITE


func _clamp_circle(n: Node2D, r: float) -> void:
	var d := n.global_position - center
	var lim := maxf(radius - MARGIN - r * 0.5, 20.0)
	if d.length() > lim:
		n.global_position = center + d.normalized() * lim


func _tick_sounds() -> void:
	var sec := int(ceil(left))
	if sec == _last_sec:
		return
	_last_sec = sec
	var low := left <= 10.0
	var vol := -24.0 if left > 30.0 else (-15.0 if not low else -6.0)
	Audio.sfx("sfx_clock_tock" if sec % 2 == 0 else "sfx_clock_tick", 0.0, vol, 1.0 if not low else 1.1)
	if low:
		_hud.pulse()
		Juice.chroma(0.006)
		if sec <= 5:
			Audio.sfx("sfx_heartbeat", 0.0, -8.0)


func _milestones() -> void:
	var p := progress()
	if p >= 0.5 and not _warned.has("half"):
		_warned["half"] = true
		_warn("TIME IS REVERSING")
	if left <= 30.0 and duration > 40.0 and not _warned.has("30"):
		_warned["30"] = true
		_warn("30 SECONDS")
	if left <= 10.0 and not _warned.has("10"):
		_warned["10"] = true
		_warn("THE TIMELINE IS BREAKING")


func _warn(text: String) -> void:
	Events.announce.emit(text)
	Audio.sfx("sfx_time_warn", 0.0, -4.0)
	Juice.chroma(0.02)
	Juice.shake(3.0, 0.3)
	_hud.pulse()


## The world was beaten in time: the clock stops, the edges pull back, time is restored.
func clear(quiet := false) -> void:
	if cleared or collapsed:
		return
	cleared = true
	running = false
	_hud.set_state("cleared")
	_bot_log("cleared with %.1fs left" % left)
	if quiet:
		return
	Audio.sfx("sfx_time_restore", 0.0, -2.0)
	Juice.flash(Color(0.6, 0.95, 1.0, 0.35), 0.5)
	Juice.invert(0.12)
	var t := create_tween()
	t.tween_property(self, "_restore", 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _expire() -> void:
	if collapsed:
		return
	collapsed = true
	running = false
	_bot_log("TIME UP")
	expired.emit()


## Time ran out: light breaks through the seams, the world cracks, then shatters (the scene
## change itself is GameManager's "shatter" transition).
func collapse() -> void:
	collapsed = true
	running = false
	_hud.set_state("expired")
	GameManager.input_locked = true
	if is_instance_valid(level):
		level.revives_here = false
	Events.announce.emit("THE TIMELINE SHATTERS")
	Audio.music("", 0.4)
	Voice.stop()
	Juice.slowmo(0.2)
	Audio.sfx("sfx_crack", 0.0, 0.0, 0.9)
	Audio.sfx("sfx_time_warn", 0.0, 0.0, 0.7)
	Juice.shake(9.0, 0.9)
	Juice.chroma(0.035)
	var cam_pos: Vector2 = level.camera.get_screen_center_position() if is_instance_valid(level) and is_instance_valid(level.camera) else global_position
	var light := Sheet.make_light(Color(1.0, 1.0, 1.0), 0.0, 3.0)
	light.global_position = cam_pos
	light.z_index = 60
	get_tree().current_scene.add_child(light)
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(light, "energy", 3.5, 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(light, "texture_scale", 14.0, 0.8)
	t.parallel().tween_property(self, "_surge", 0.35, 0.8)
	Juice.whiteout(0.28, 0.8)
	await get_tree().create_timer(0.3, true, false, true).timeout
	Audio.sfx("sfx_crack", 0.0, 2.0, 1.15)
	await get_tree().create_timer(0.25, true, false, true).timeout
	Audio.sfx("sfx_crack", 0.0, 3.0, 0.75)
	await get_tree().create_timer(0.3, true, false, true).timeout
	Juice.slowmo(1.0)   # back to normal speed; keep the screen effects for the shatter snapshot


func _exit_tree() -> void:
	Juice.mirror_edge_off()


func _bot_log(msg: String) -> void:
	if OS.get_environment("ECHO_BOT") == "1":
		print("[BOT] clock %s: %s" % [GameManager.current_scene, msg])
