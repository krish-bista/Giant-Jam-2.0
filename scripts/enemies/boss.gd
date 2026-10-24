class_name Boss
extends Enemy
## Boss: name banner + intro, red telegraphed attack patterns, phase 2 at 50% health.

var boss_id := ""
var boss_name := ""
var active := false
var _busy := false
var _pattern_i := 0
var _pattern_cd := 1.5
var _phase2 := false
var _contact_cd := 0.0
var _charging := false
var _charge_hit := false
var _flee_mode := false
var _swap_t := 6.0
var _told_flee := false
var minions: Array = []


func setup_boss(id: String) -> Boss:
	boss_id = id
	cfg = EnemyData.BOSSES[id].duplicate()
	cfg["state"] = "chase"
	_apply_cfg()
	boss_name = cfg.name
	drops = false
	return self


func _ready() -> void:
	super._ready()
	add_to_group("boss")
	sprite.position.y = -8
	_intro()


func _intro() -> void:
	Events.boss_intro.emit(boss_name, cfg.intro)
	Events.boss_health_changed.emit(boss_name, health, max_health)
	Audio.sfx("sfx_boss_roar", 0.05, -2.0)
	Juice.shake(8.0, 0.7)
	var t := Telegraph.circle(get_parent(), global_position, radius + 40.0, 1.6, Color(1, 0.3, 0.3))
	await t.fired
	active = true


func flip(_duration: float) -> void:
	pass  # Bosses can't be hypnotized.


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_contact_cd = maxf(0.0, _contact_cd - delta)
	var p := player()
	if not active or p == null or (p.has_method("is_dead") and p.is_dead()):
		velocity = _knock
		_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		_update_visual()
		queue_redraw()
		return

	if cfg.get("swap_flee", false) and not _busy:
		_swap_t -= delta
		if _swap_t <= 0.0:
			_flee_mode = not _flee_mode
			_swap_t = 4.0 if _flee_mode else 6.0
			if _flee_mode and not _told_flee:
				_told_flee = true
				Events.subtitle.emit("It's running. Strike now!", Color(1, 0.9, 0.5))

	var move := Vector2.ZERO
	if not _busy:
		var to_p := p.global_position - global_position
		if _flee_mode:
			move = -to_p.normalized() * speed * 1.1
			var c := arena.get_center() - global_position
			if c.length() > 380.0:
				move = (move.normalized() + c.normalized() * 1.5).normalized() * speed
		elif to_p.length() > radius + 30.0:
			move = to_p.normalized() * speed * (1.2 if _phase2 else 1.0)
		_pattern_cd -= delta
		if _pattern_cd <= 0.0 and not _flee_mode:
			_run_next_pattern()

	if not _charging:
		velocity = move + _knock
		move_and_slide()
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	global_position = global_position.clamp(arena.position, arena.end)

	# Contact damage
	# Contact damage only when it actually runs into you (overlap) or while charging.
	var touch := radius + (24.0 if _charging else 6.0)
	if _contact_cd <= 0.0 and global_position.distance_to(p.global_position) < touch:
		_contact_cd = 1.2
		p.take_damage(damage * (1.4 if _charging else 1.0), self)
	_update_visual()
	queue_redraw()


func _run_next_pattern() -> void:
	var patterns: Array = cfg.patterns
	var pattern: String = patterns[_pattern_i % patterns.size()]
	_pattern_i += 1
	_busy = true
	match pattern:
		"hypno_pulse": await _p_hypno_pulse()
		"volley": await _p_volley()
		"line": await _p_line()
		"charge": await _p_charge()
		"tail": await _p_tail()
		"circle_player": await _p_circle_player()
		"ring": await _p_ring()
	_busy = false
	_pattern_cd = cfg.cd * (0.75 if _phase2 else 1.0)


func _aim() -> Vector2:
	var p := player()
	return (p.global_position - global_position).normalized() if p else Vector2.RIGHT


func _hit_player_if(t: Telegraph, dmg: float) -> void:
	var p := player()
	if p and is_instance_valid(t) and t.contains(p.global_position):
		p.take_damage(dmg, self)


func _p_hypno_pulse() -> void:
	var t := Telegraph.circle(get_parent(), global_position, 190.0, 1.0, Color(1.0, 0.3, 0.9))
	await t.fired
	var p := player()
	Juice.flash(Color(1, 0.3, 0.9, 0.3), 0.25)
	Audio.sfx("sfx_glitch")
	if p and t.contains(p.global_position) and p.has_method("reverse_controls"):
		p.reverse_controls(3.0)
		Events.announce.emit("CONTROLS REVERSED")


func _p_volley() -> void:
	for i in (5 if _phase2 else 3):
		if _dead:
			return
		Projectile.fire(get_parent(), global_position, _aim().rotated(randf_range(-0.08, 0.08)), 280.0, 8.0, self)
		Audio.sfx("sfx_laser", 0.1, -6.0)
		await get_tree().create_timer(0.18, false).timeout
		if _dead:
			return


func _p_line() -> void:
	var dir := _aim()
	var t := Telegraph.line(get_parent(), global_position, dir, 1000.0, 48.0, 1.0)
	await t.fired
	Audio.sfx("sfx_boss_attack", 0.05, -2.0)
	Juice.shake(6.0, 0.4)
	_hit_player_if(t, 15.0)


func _p_charge() -> void:
	var dir := _aim()
	var dist := 560.0
	var t := Telegraph.line(get_parent(), global_position, dir, dist, radius * 2.0, 0.8)
	await t.fired
	if _dead:
		return
	_charging = true
	Audio.sfx("sfx_boss_attack", 0.1, -4.0)
	var travelled := 0.0
	while travelled < dist and not _dead:
		var step := 820.0 * get_physics_process_delta_time()
		velocity = dir * 820.0
		move_and_slide()
		global_position = global_position.clamp(arena.position, arena.end)
		travelled += step
		if get_slide_collision_count() > 0:
			break
		await get_tree().physics_frame
	_charging = false
	Juice.shake(5.0, 0.3)


func _p_tail() -> void:
	var t := Telegraph.circle(get_parent(), global_position, radius + 70.0, 0.6)
	await t.fired
	Juice.shake(5.0, 0.3)
	_hit_player_if(t, 12.0)


func _p_circle_player() -> void:
	var p := player()
	if p == null:
		return
	var shots := 2 if _phase2 else 1
	var ts: Array[Telegraph] = []
	for i in shots:
		ts.append(Telegraph.circle(get_parent(), p.global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60)) * i, 80.0, 1.0))
	await ts[0].fired
	Audio.sfx("sfx_boss_attack", 0.1, -4.0)
	for t in ts:
		_hit_player_if(t, 18.0)


func _p_ring() -> void:
	for wave in (2 if _phase2 else 1):
		var offset := randf() * TAU
		for i in 12:
			var dir := Vector2.RIGHT.rotated(offset + i * TAU / 12.0)
			Projectile.fire(get_parent(), global_position + dir * radius, dir, 210.0, 10.0, self)
		Audio.sfx("sfx_laser", 0.05, -4.0)
		await get_tree().create_timer(0.5, false).timeout


func take_damage(amount: float, source: Node = null) -> void:
	if _dead or amount <= 0.0:
		return
	if _flee_mode:
		amount *= 1.5
	damaged.emit(amount, source)
	_hurt_flash = 0.08
	Juice.number(global_position + Vector2(0, -radius), amount, Color(1, 1, 0.6))
	Juice.burst(global_position, Color(1, 0.9, 0.7), 10, 160.0, 3.0)
	Audio.sfx("sfx_hit", 0.15, -3.0)
	if source is Node2D and is_instance_valid(source) and source.is_in_group("player"):
		Juice.hitstop(0.05)
		Juice.shake(3.0, 0.25)
		_knock = (global_position - source.global_position).normalized() * 60.0
	health -= amount
	Events.boss_health_changed.emit(boss_name, maxf(health, 0.0), max_health)
	if not _phase2 and health <= max_health * 0.5:
		_phase2 = true
		_enter_phase2.call_deferred()
	if health <= 0.0:
		die(source)


func _enter_phase2() -> void:
	if _dead:
		return
	Juice.flash(Color(1, 0.2, 0.2, 0.25), 0.3)
	Audio.sfx("sfx_boss_roar", 0.05, -4.0)
	var summons: Array = cfg.get("summon", [])
	for i in summons.size():
		var id: String = summons[i]
		var e := Enemy.new()
		if id == "raptor_hunter":
			e.setup("raptor", {"state": "hunter", "tex": EnemyData.TYPES.raptor.hunter_tex})
		else:
			e.setup(id)
		e.drops = false
		e.arena = arena
		e.mirror_offset = Vector2(0, (i - 0.5) * 120.0)
		e.global_position = global_position + Vector2.RIGHT.rotated(i * TAU / summons.size()) * (radius + 50.0)
		get_parent().add_child(e)
		minions.append(e)


func die(_source: Node = null) -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("enemies")
	Events.boss_health_changed.emit(boss_name, 0.0, 0.0)
	if cfg.death != "":
		Events.subtitle.emit(cfg.death, Color(1, 0.75, 0.75))
	Audio.sfx("sfx_boss_die", 0.0, 0.0)
	Juice.shake(12.0, 1.0)
	Juice.flash(Color(1, 1, 1, 0.5), 0.3)
	Juice.burst(global_position, Color(1, 0.8, 0.5), 40, 320.0, 5.0)
	for m in minions:
		if is_instance_valid(m) and m.has_method("die"):
			m.drops = false
			m.die()
	var parent := get_parent()
	Pickup.spawn_heal(parent, global_position + Vector2(-20, 0), 25.0)
	var id: String = cfg.get("fixed_drop", "")
	if id == "" or id in GameManager.artifacts:
		id = GameManager.roll_artifact("boss")
	if id != "":
		Pickup.spawn_artifact(parent, global_position + Vector2(20, 0), id)
	died.emit(self)
	Events.enemy_killed.emit(self)
	# Hide now, free later, so attack coroutines that are mid-await finish cleanly.
	visible = false
	collision_layer = 0
	set_physics_process(false)
	get_tree().create_timer(3.0).timeout.connect(queue_free)


func _draw() -> void:
	if _flee_mode:
		draw_arc(Vector2.ZERO, radius + 10.0, 0, TAU, 32, Color(1, 0.9, 0.4, 0.8), 3.0, true)
