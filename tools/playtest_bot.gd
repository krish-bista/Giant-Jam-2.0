extends Node
## Automated playtester. Plays the whole game start to finish and logs what happens.
## Run:  ECHO_BOT=1 godot --headless --path . --fixed-fps 60
## Only loaded when the ECHO_BOT environment variable is "1".

var deaths := 0
var scene_times := {}
var _last_scene := ""
var _scene_start := 0.0
var _attack_t := 0.0
var _tap_t := 0.0
var _block_left := 0.0
var _hypno_t := 0.0
var _dash_t := 0.0
var _log_t := 0.0
var _stuck_pos := Vector2.ZERO
var _stuck_t := 0.0
var _jitter := Vector2.ZERO
var _done := false
var _artifacts_logged := 0
var _used_once := {}
var _special_t := 0.0
var _event_t := 0.0
var _switch_t := 0.0
var _switch_shots := 0
var _clock_shot := false


## Screenshots during scene transitions (shatter / mirror) and of the clock running low.
func _process(delta: float) -> void:
	var shots := OS.get_environment("ECHO_BOT_SHOTS")
	if shots == "":
		return
	var real := delta / maxf(Engine.time_scale, 0.01)
	var lvl := get_tree().current_scene
	var collapsing: bool = lvl is Level and is_instance_valid(lvl.clock) and lvl.clock.collapsed
	if GameManager._switching or collapsing:
		_switch_t -= real
		if _switch_t <= 0.0 and _switch_shots < 30:
			_switch_t = 0.12
			_switch_shots += 1
			get_viewport().get_texture().get_image().save_png("%s/switch_%s_%02d.png" % [shots, GameManager.current_scene, _switch_shots])
	else:
		_switch_shots = 0
	if lvl is Level and is_instance_valid(lvl.clock) and not _clock_shot and lvl.clock.progress() > 0.8 and not lvl.clock.collapsed:
		_clock_shot = true
		get_viewport().get_texture().get_image().save_png("%s/clock_low_%s.png" % [shots, GameManager.current_scene])
var _shot_t := 3.0
var _shot_n := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[BOT] started")
	if OS.get_environment("ECHO_BOT_SET_DEATHS") != "":
		GameManager.deaths = int(OS.get_environment("ECHO_BOT_SET_DEATHS"))
	Events.player_died.connect(func():
		print("[BOT] damage so far: ", hurt_log)
		deaths += 1
		print("[BOT] DIED in %s at %.1fs (deaths: %d)" % [GameManager.current_scene, GameManager.run_time, deaths]))
	Events.boss_intro.connect(func(n, _l): print("[BOT] boss intro: %s at %.1fs" % [n, GameManager.run_time]))
	Events.weapon_changed.connect(func(w): if w != "": print("[BOT] weapon: %s" % w))
	Events.player_revived.connect(func(d): print("[BOT] revived (deaths %d) in %s" % [d, GameManager.current_scene]))
	Events.tutorial_prompt.connect(func(t): if t != "": print("[BOT] prompt: %s (t=%.1f)" % [t, GameManager.run_time]))
	Events.artifact_picked.connect(func(a): print("[BOT] artifact: %s" % a.name))
	Events.enemy_killed.connect(func(e): if e.is_in_group("boss"): print("[BOT] boss down: %s at %.1fs" % [e.boss_name, GameManager.run_time]))


func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	get_tree().create_timer(0.05, true, false, true).timeout.connect(func(): Input.parse_input_event(up))


func _hold(action: String, on: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = on
	Input.parse_input_event(ev)


func _move(dir: Vector2) -> void:
	dir = dir.limit_length(1.0)
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if dir.x < -0.2: Input.action_press("move_left", minf(1.0, -dir.x))
	if dir.x > 0.2: Input.action_press("move_right", minf(1.0, dir.x))
	if dir.y < -0.2: Input.action_press("move_up", minf(1.0, -dir.y))
	if dir.y > 0.2: Input.action_press("move_down", minf(1.0, dir.y))


func _physics_process(delta: float) -> void:
	var shots := OS.get_environment("ECHO_BOT_SHOTS")
	if shots != "":
		_shot_t -= delta
		if _shot_t <= 0.0:
			_shot_t = float(OS.get_environment("ECHO_BOT_SHOT_EVERY")) if OS.get_environment("ECHO_BOT_SHOT_EVERY") != "" else 9.0
			_shot_n += 1
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/shot_%03d_%s.png" % [shots, _shot_n, GameManager.current_scene])
	# Event screenshots: the moment a Mirror Domain opens / a parry ring turns cyan.
	if OS.get_environment("ECHO_BOT_SHOTS") != "" and get_tree().current_scene:
		_event_t -= delta
		if _event_t <= 0.0:
			for n in get_tree().current_scene.get_children():
				var tag := ""
				if n is MirrorDomain and n._r > 200.0:
					tag = "domain"
				elif n is ParryCue and n._in_window:
					tag = "parry"
				if n is ReflectionAlly and not has_meta("ally_shot") and GameManager.run_time - _scene_start > 8.0:
					set_meta("ally_shot", true)
					var sp: Vector2 = get_viewport().get_canvas_transform() * n.global_position
					var img := get_viewport().get_texture().get_image()
					var rect := Rect2i(Vector2i(clampi(int(sp.x) - 120, 0, 1040), clampi(int(sp.y) - 110, 0, 500)), Vector2i(240, 200))
					img.get_region(rect).save_png("%s/ally_crop.png" % OS.get_environment("ECHO_BOT_SHOTS"))
				if tag != "":
					_event_t = 4.0
					_shot_n += 1
					get_viewport().get_texture().get_image().save_png("%s/event_%03d_%s.png" % [OS.get_environment("ECHO_BOT_SHOTS"), _shot_n, tag])
					break
	if _done:
		return
	var scene := GameManager.current_scene
	if scene != _last_scene:
		if _last_scene != "":
			scene_times[_last_scene] = GameManager.run_time - _scene_start
			print("[BOT] %s took %.1fs" % [_last_scene, scene_times[_last_scene]])
		_last_scene = scene
		_scene_start = GameManager.run_time
		print("[BOT] entered %s at %.1fs" % [scene, GameManager.run_time])
		if scene == "ending":
			_finish_after_ending()
	if GameManager.run_time > float(OS.get_environment("ECHO_BOT_LIMIT") if OS.get_environment("ECHO_BOT_LIMIT") != "" else "1500"):
		print("[BOT] ===== GAVE UP: stuck in %s =====" % scene)
		_done = true
		get_tree().quit(1)
		return
	_special_t -= delta
	_tap_t -= delta
	_attack_t -= delta
	_hypno_t -= delta
	_dash_t -= delta

	var root := get_tree().current_scene
	var p: Node2D = get_tree().get_first_node_in_group("player")
	if root == null:
		return
	var ui := _find_ui(root)

	# Dialogue / cutscenes / game over: press E.
	if GameManager.input_locked or (ui and (ui._over.visible or ui._dlg_active or ui._cut_active)):
		_move(Vector2.ZERO)
		if _tap_t <= 0.0:
			_tap_t = 0.35
			_tap("interact")
		return
	# Test hook: open a Mirror Domain at the player every 3s (visual check).
	if p and OS.get_environment("ECHO_BOT_TEST_DOMAIN") == "1" and GameManager.run_time - _scene_start > 6.0 and fmod(GameManager.run_time, 3.0) < delta:
		MirrorDomain.open_at(root, p.global_position, 250.0)
	# Test hook: die N times in world1 (graves, revives, sanity, rabid, Reflection ending).
	var want_deaths := int(OS.get_environment("ECHO_BOT_DIE")) if OS.get_environment("ECHO_BOT_DIE") != "" else 0
	if p and scene == "world1" and GameManager.deaths < want_deaths and not p.is_dead() and p._iframes_left <= 0.0 and GameManager.run_time - _scene_start > 12.0:
		p.take_damage(9999.0, null)
	if p and OS.get_environment("ECHO_BOT_GOD") == "1" and not p.is_dead() and p.health < p.max_health * 0.5:
		p.heal(p.max_health, false)
	if p and not p.hurt.is_connected(_on_hurt):
		p.hurt.connect(_on_hurt)
	if p == null or not is_instance_valid(p) or p.is_dead():
		_move(Vector2.ZERO)
		return

	# Final: take the ending as soon as it's offered.
	if scene == "final" and root.get("_can_end") and not root.get("_ending") and OS.get_environment("ECHO_BOT_NO_END") != "1":
		if _tap_t <= 0.0:
			_tap_t = 0.3
			_tap("interact")
		return

	var goal := Vector2.ZERO
	var target: Node2D = null
	var want := 0.0

	# Danger: step out of telegraphs and projectiles.
	var dodge := Vector2.ZERO
	for t in get_tree().get_nodes_in_group("_none"):
		pass
	for n in root.get_children():
		if n is Telegraph and is_instance_valid(n) and n.contains(p.global_position):
			if n.shape == "circle":
				dodge += (p.global_position - n.global_position).normalized()
			else:
				dodge += Vector2.UP.rotated(n.rotation) * signf(n.to_local(p.global_position).y + 0.01)
	if dodge != Vector2.ZERO:
		_move(dodge.normalized())
		if _dash_t <= 0.0:
			_dash_t = 0.9
			_tap("dash")
		_handle_block(p, root)
		return

	# Portal open? Go.
	for n in root.get_children():
		if n is Portal and n.active:
			target = n
			want = 0.0
			break

	# Pickups
	if target == null:
		for n in root.get_children():
			if n is Pickup:
				target = n
				break

	# Tutorial items beat the unkillable dummy.
	if target == null:
		for n in root.get_children():
			if n is Interactable and n.enabled and ("Take" in n.prompt):
				target = n
				want = 30.0
				break

	# Enemies
	var enemy: Node2D = null
	if target == null:
		var best := INF
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.is_in_group("flipped"):
				continue
			var d := p.global_position.distance_to(e.global_position)
			if d < best:
				best = d
				enemy = e
		if enemy:
			target = enemy
			want = 30.0 + (enemy.radius if "radius" in enemy else 14.0)

	# World weapon pickups (when the area is clear)
	if target == null:
		for n in root.get_children():
			if n is WeaponPickup and not n._taken:
				target = n
				want = 0.0
				break

	# Interactables (skip the door, the table and "keep fighting").
	if target == null:
		for n in root.get_children():
			if n is Interactable and n.enabled and n.prompt != "" and not ("Door" in n.prompt) and not ("Keep" in n.prompt) and not _used_once.has(n.get_instance_id()):
				target = n
				want = 30.0
				break

	if target == null and root is Level and is_instance_valid(root.objective) and root.objective.visible:
		target = root.objective
		want = 40.0

	if target == null:
		# Nothing to do: walk in a circle and dash now and then (covers the tutorial's move step).
		var t := Time.get_ticks_msec() * 0.001
		_move(Vector2(cos(t), sin(t)) + ((root.world_size * 0.5 if root is Level else Vector2(640, 360)) - p.global_position) * 0.002)
		if _dash_t <= 0.0:
			_dash_t = 2.0
			_tap("dash")
		_handle_block(p, root)
		_periodic_log(p, scene, delta)
		return

	var to_t := target.global_position - p.global_position
	p.aim_override = to_t if enemy else Vector2.ZERO
	if enemy:
		p.aim_override = to_t
	goal = to_t
	if to_t.length() > want + 6.0:
		_move(goal.normalized() + _unstick(p, delta))
	elif enemy and to_t.length() < want - 14.0 and not enemy.is_in_group("boss"):
		_move(-goal.normalized() * 0.5)
	else:
		_move(Vector2.ZERO)

	if target is Interactable and to_t.length() <= target.reach - 5.0 and _tap_t <= 0.0:
		_tap_t = 0.4
		_tap("interact")
		if "Read" in target.prompt:
			_used_once[target.get_instance_id()] = true

	if enemy and to_t.length() < want + 30.0 and _attack_t <= 0.0 and _block_left <= 0.0:
		_attack_t = 0.2
		_tap("attack")

	# World weapon when enemies are close
	if GameManager.weapon != "" and enemy and to_t.length() < 260.0 and _special_t <= 0.0:
		_special_t = 1.0
		_tap("special")

	# Hypno when a few enemies are in front.
	if GameManager.hypno_unlocked and _hypno_t <= 0.0:
		var near := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.is_in_group("boss") and p.global_position.distance_to(e.global_position) < 140.0:
				near += 1
		if near >= 2:
			_hypno_t = 1.0
			_tap("hypno")
	_handle_block(p, root)
	_periodic_log(p, scene, delta)


func _periodic_log(p: Node2D, scene: String, delta: float) -> void:
	_log_t -= delta
	if _log_t <= 0.0:
		_log_t = 15.0
		print("[BOT] t=%.0fs (wall %.0fs) %s hp=%.0f/%d enemies=%d" % [GameManager.run_time, Time.get_ticks_msec() / 1000.0, scene, p.health, p.max_health, get_tree().get_nodes_in_group("enemies").size()])


var hurt_log := {}
func _on_hurt(amount: float, source: Variant) -> void:
	var key := "?"
	if is_instance_valid(source):
		key = source.boss_name if "boss_name" in source and source.boss_name != "" else (source.type_id if "type_id" in source and source.type_id != "" else source.get_class())
	var k := "%s/%s" % [GameManager.current_scene, key]
	hurt_log[k] = hurt_log.get(k, 0.0) + amount
	if Engine.get_process_frames() % 1 == 0 and GameManager.current_scene == OS.get_environment("ECHO_BOT_TRACE"):
		print("[BOT]   hit by %s for %.0f" % [key, amount])


func _handle_block(p: Node2D, _root: Node) -> void:
	_block_left -= get_physics_process_delta_time()
	if _block_left > 0.0:
		return
	if _block_left > -0.05:
		_hold("block", false)
	if not GameManager.has_shield:
		return
	# Raise the shield ~0.15s before a windup lands -> perfect reflect.
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Enemy) or e is Boss:
			continue
		if e._winding and e._wind_left < 0.18 and p.global_position.distance_to(e.global_position) < e.attack_range + 60.0:
			p.aim_override = e.global_position - p.global_position
			_hold("block", true)
			_block_left = 0.3
			return
	for n in get_tree().current_scene.get_children():
		if n is Projectile and not n.hits_enemies:
			var to_p: Vector2 = p.global_position - n.global_position
			if to_p.length() < 70.0 and n.velocity.dot(to_p) > 0.0:
				p.aim_override = -to_p
				_hold("block", true)
				_block_left = 0.3
				return


func _unstick(p: Node2D, delta: float) -> Vector2:
	if p.global_position.distance_to(_stuck_pos) < 2.0:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
		_stuck_pos = p.global_position
	if _stuck_t > 0.6:
		_stuck_t = 0.0
		_jitter = Vector2.RIGHT.rotated(randf() * TAU)
	_jitter = _jitter.move_toward(Vector2.ZERO, delta)
	return _jitter


func _find_ui(root: Node) -> GameUI:
	for n in root.get_children():
		if n is GameUI:
			return n
	return null


func _finish_after_ending() -> void:
	_done = true
	_move(Vector2.ZERO)
	await get_tree().create_timer(float(OS.get_environment("ECHO_BOT_ENDING_WAIT")) if OS.get_environment("ECHO_BOT_ENDING_WAIT") != "" else 4.0, true, false, true).timeout
	print("[BOT] ===== RUN COMPLETE =====")
	print("[BOT] total time %.1fs, deaths %d, ending %s, artifacts %s" % [GameManager.run_time, deaths, GameManager.ending_type(), str(GameManager.artifacts)])
	for k in scene_times:
		print("[BOT]   %-13s %.1fs" % [k, scene_times[k]])
	get_tree().quit(0)
