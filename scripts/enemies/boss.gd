class_name Boss
extends Enemy
## Bosses: animated multi-part rigs, name banner + voiced intro, red telegraphed attack patterns,
## phase 2 at 50% health.
##   hypnotic  - squid with orbiting hypno-eyes; pulse reverses your controls
##   warden    - alien cyclops with two turret orbs and an eye laser
##   alpha_rex - giant beast: charges, tail sweeps, leaps and slams down
##   sentinel  - segmented neon dragon that coils around you and swoops

const N := "res://assets/ninja/"

var boss_id := ""
var boss_name := ""
var active := false
var parts: Array[Node2D] = []        # orbiting extras (eyes, turrets)
var segments: Array[Node2D] = []     # dragon body
var wings: Array[Sprite2D] = []
var head: Sprite2D
var laser: Line2D
var _busy := false
var _pattern_i := 0
var _pattern_cd := 1.5
var _phase2 := false
var _contact_cd := 0.0
var _charging := false
var _flee_mode := false
var _swap_t := 6.0
var _told_flee := false
var _orbit := 0.0
var _airborne := false
var minions: Array = []
var _hit_frame := -1
var _hit_source: Node = null


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
	if boss_id == "sentinel":
		collision_mask = 0
	_intro()


func _build_visuals() -> void:
	shadow = Sprite2D.new()
	shadow.texture = load(N + "fx/shadow.png")
	shadow.scale = Vector2(radius / 5.0, radius / 7.0)
	shadow.position = Vector2(0, radius * 0.75)
	shadow.modulate = Color(0, 0, 0, 0.45)
	shadow.z_index = -1
	add_child(shadow)
	sprite = AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = Sheet.sprite_material()
	sprite.material = _mat
	add_child(sprite)
	match boss_id:
		"hypnotic":
			sprite.sprite_frames = Sheet.boss(N + "bosses/squid", {"idle": [4, 6], "walk": [4, 8], "attack": [6, 10, false], "shoot": [5, 10, false], "hit": [4, 12, false]})
			sprite.scale = Vector2(2.4, 2.4)
			sprite.position.y = -50
			for i in 3:
				var eye := AnimatedSprite2D.new()
				eye.sprite_frames = Sheet.monster(N + "enemies/eye.png")
				eye.play("idle_down")
				eye.scale = Vector2(2.4, 2.4)
				eye.modulate = Color(1.6, 0.7, 1.6)
				eye.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				add_child(eye)
				parts.append(eye)
			light = Sheet.make_light(Color(1.0, 0.3, 0.9), 1.3, 2.6)
		"warden":
			sprite.sprite_frames = Sheet.boss(N + "bosses/cyclops", {"idle": [5, 6], "walk": [6, 8], "hit": [3, 12, false]})
			sprite.scale = Vector2(3.2, 3.2)
			sprite.position.y = -52
			for side in [-1, 1]:
				var orb := AnimatedSprite2D.new()
				orb.sprite_frames = Sheet.monster(N + "enemies/cyclope.png")
				orb.play("walk_down")
				orb.scale = Vector2(2.4, 2.4)
				orb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				orb.set_meta("side", side)
				add_child(orb)
				parts.append(orb)
			laser = Line2D.new()
			laser.width = 0.0
			laser.default_color = Color(1.4, 2.4, 2.6)
			laser.z_index = 30
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			laser.material = add
			add_child(laser)
			light = Sheet.make_light(Color(0.3, 0.9, 1.0), 1.1, 2.6)
		"alpha_rex":
			sprite.sprite_frames = Sheet.boss(N + "bosses/beast", {"idle": [6, 6], "attack": [4, 10, false], "charge": [2, 10], "jump": [5, 10, false]})
			sprite.scale = Vector2(3.0, 3.0)
			sprite.position.y = -60
			light = Sheet.make_light(Color(1.0, 0.7, 0.4), 0.6, 2.2)
		"sentinel":
			_build_dragon()
			light = Sheet.make_light(Color(0.8, 0.3, 1.0), 1.4, 2.8)
	if sprite.sprite_frames:
		sprite.play("idle")
	if light:
		add_child(light)


func _build_dragon() -> void:
	sprite.visible = false
	head = Sprite2D.new()
	head.texture = load(N + "bosses/dragon_head.png")
	head.scale = Vector2(2.8, 2.8)
	head.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.material = _mat
	head.z_index = 3
	add_child(head)
	for i in 10:
		var seg := DragonSegment.new()
		seg.boss = self
		var tex := "dragon_bodyend" if i == 9 else ("dragon_body1" if i % 2 == 0 else "dragon_body2")
		seg.setup(load(N + "bosses/%s.png" % tex), 2.6 - i * 0.07)
		seg.top_level = true
		add_child(seg)
		seg.global_position = global_position + Vector2(0, (i + 1) * 30)
		segments.append(seg)
	for side in [-1, 1]:
		var w := Sprite2D.new()
		w.texture = load(N + "bosses/dragon_wing.png")
		w.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		w.scale = Vector2(2.6 * side, 2.6)
		w.offset = Vector2(20, -10)
		w.z_index = -1
		segments[0].add_child(w)
		wings.append(w)


func _intro() -> void:
	Events.boss_intro.emit(boss_name, cfg.intro)
	Events.boss_health_changed.emit(boss_name, health, max_health)
	if cfg.get("voice", "") != "":
		Voice.say(cfg.intro, cfg.voice)
	Audio.sfx("sfx_boss_roar", 0.05, -1.0)
	Juice.shake(9.0, 0.8)
	Juice.zoom_punch(0.12)
	var t := Telegraph.circle(get_parent(), global_position, radius + 50.0, 1.8, Color(1, 0.3, 0.3))
	await t.fired
	active = true


func flip(_duration: float) -> void:
	Juice.text_pop(global_position + Vector2(0, -radius), "IMMUNE", Color(1, 0.6, 1.0), 16)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_update_parts(delta)
	var p := player()
	if not active or p == null or (p.has_method("is_dead") and p.is_dead()):
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
				Voice.say("It's running. Strike now!", "you")

	var move := Vector2.ZERO
	if not _busy:
		if boss_id == "sentinel":
			move = _dragon_steer(p, delta)
		else:
			var to_p := p.global_position - global_position
			if _flee_mode:
				move = -to_p.normalized() * speed * 1.1
				var c := arena.get_center() - global_position
				if c.length() > 500.0:
					move = (move.normalized() + c.normalized() * 1.5).normalized() * speed
			elif to_p.length() > radius + 40.0:
				move = to_p.normalized() * speed * (1.2 if _phase2 else 1.0)
		_pattern_cd -= delta
		if _pattern_cd <= 0.0 and not _flee_mode:
			_run_next_pattern()

	if not _charging and not _airborne:
		velocity = move + _knock
		move_and_slide()
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	global_position = global_position.clamp(arena.position, arena.end)
	if move.length() > 5.0:
		_face = move

	# Contact damage only when it actually runs into you (overlap) or while charging.
	if not _airborne and _contact_cd <= 0.0:
		var touch := radius + (24.0 if _charging else 4.0)
		var hit := global_position.distance_to(p.global_position) < touch
		for seg in segments:
			if is_instance_valid(seg) and seg.global_position.distance_to(p.global_position) < seg.radius + 6.0:
				hit = true
		if hit:
			_contact_cd = 1.2
			p.take_damage(damage * (1.4 if _charging else 1.0), self)
	_update_visual()
	queue_redraw()


func _dragon_steer(p: Node2D, delta: float) -> Vector2:
	_orbit += delta * (0.9 if not _phase2 else 1.3)
	var ring := 250.0 + sin(_t * 0.7) * 70.0
	var goal := p.global_position + Vector2(cos(_orbit), sin(_orbit) * 0.7) * ring
	var to_goal := goal - global_position
	return to_goal.limit_length(speed * (1.25 if _phase2 else 1.0)) if to_goal.length() > 10.0 else Vector2.ZERO


func _update_parts(_delta: float) -> void:
	var bob := sin(_t * 3.0)
	match boss_id:
		"hypnotic":
			for i in parts.size():
				var a := _t * 1.6 + i * TAU / parts.size()
				parts[i].position = Vector2(cos(a) * 110.0, sin(a) * 60.0 - 40.0)
				parts[i].z_index = 1 if sin(a) > 0 else -1
		"warden":
			for orb in parts:
				var side: int = orb.get_meta("side")
				orb.position = Vector2(side * 110.0, -70.0 + sin(_t * 2.5 + side) * 12.0)
		"sentinel":
			head.position = Vector2(0, -20 + bob * 6.0)
			head.flip_h = velocity.x < -10.0
			var prev := global_position + head.position
			for i in segments.size():
				var seg: DragonSegment = segments[i]
				if not is_instance_valid(seg):
					continue
				var gap := 34.0 * seg.scale_factor / 2.6
				var dvec := seg.global_position - prev
				if dvec.length() > gap:
					seg.global_position = prev + dvec.normalized() * gap
				seg.z_index = 2 - i
				prev = seg.global_position
			for w in wings:
				var flap := 0.55 + 0.45 * sin(_t * 9.0)
				w.scale.y = 2.6 * flap
			shadow.visible = false
	if light:
		light.position = Vector2(0, -radius * 0.6)


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
		"swoop": await _p_charge()
		"tail": await _p_tail()
		"circle_player": await _p_circle_player()
		"ring": await _p_ring()
		"jump_slam": await _p_jump_slam()
	_busy = false
	_pattern_cd = cfg.cd * (0.75 if _phase2 else 1.0)


func _aim(from := Vector2.INF) -> Vector2:
	var p := player()
	var origin := global_position if from == Vector2.INF else from
	return (p.global_position - origin).normalized() if p else Vector2.RIGHT


func _hit_player_if(t: Telegraph, dmg: float) -> void:
	var p := player()
	if p and is_instance_valid(t) and t.contains(p.global_position):
		p.take_damage(dmg, self)


func _anim(anim_name: String) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)


func _shot_origin() -> Vector2:
	if boss_id == "sentinel":
		return head.global_position
	return global_position + Vector2(0, -radius * 0.6)


func _p_hypno_pulse() -> void:
	_anim("attack")
	var t := Telegraph.circle(get_parent(), global_position, 210.0, 1.0, Color(1.0, 0.3, 0.9))
	await t.fired
	if _dead:
		return
	for i in 3:
		var ring := Line2D.new()
		ring.width = 6.0
		ring.default_color = Color(2.0, 0.5, 1.9, 0.9)
		var pts := PackedVector2Array()
		for k in 33:
			pts.append(Vector2.RIGHT.rotated(k * TAU / 32.0) * 30.0)
		ring.points = pts
		ring.global_position = global_position
		ring.z_index = 20
		get_parent().add_child(ring)
		var tw := ring.create_tween()
		tw.tween_interval(i * 0.12)
		tw.tween_property(ring, "scale", Vector2(7.5, 7.5), 0.5)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
		tw.tween_callback(ring.queue_free)
	var p := player()
	Juice.flash(Color(1, 0.3, 0.9, 0.3), 0.25)
	Juice.chroma(0.02)
	Audio.sfx("sfx_glitch")
	if p and t.contains(p.global_position) and p.has_method("reverse_controls"):
		p.reverse_controls(3.0)
		Events.announce.emit("CONTROLS REVERSED")
		Voice.say("CONTROLS REVERSED", "system")
	_anim("idle")


func _p_volley() -> void:
	_anim("shoot")
	for i in (5 if _phase2 else 3):
		if _dead:
			return
		var origins: Array[Vector2] = [_shot_origin()]
		if boss_id == "warden":
			origins = [parts[0].global_position, parts[1].global_position]
		elif boss_id == "hypnotic":
			origins = [parts[i % parts.size()].global_position]
		for o in origins:
			Projectile.fire(get_parent(), o, _aim(o).rotated(randf_range(-0.08, 0.08)), 280.0, 8.0, self, false,
				"energy_ball_pink" if boss_id == "hypnotic" else ("big_energy_ball_purple" if boss_id == "sentinel" else "energy_ball"))
		Audio.sfx("sfx_laser", 0.1, -6.0)
		await get_tree().create_timer(0.2, false).timeout
		if _dead:
			return
	_anim("idle")


func _p_line() -> void:
	var dir := _aim()
	var origin := _shot_origin()
	var t := Telegraph.line(get_parent(), origin, dir, 1100.0, 48.0, 1.0)
	await t.fired
	if _dead:
		return
	Audio.sfx("sfx_boss_attack", 0.05, -1.0)
	Juice.shake(7.0, 0.45)
	Juice.chroma(0.01)
	if laser:
		laser.points = PackedVector2Array([to_local(origin), to_local(origin + dir * 1100.0)])
		laser.width = 40.0
		var tw := laser.create_tween()
		tw.tween_property(laser, "width", 0.0, 0.35)
		Juice.light_flash(origin + dir * 200.0, Color(0.4, 1.0, 1.0), 2.5, 4.0, 0.35)
	_hit_player_if(t, 15.0)


func _p_charge() -> void:
	var dir := _aim()
	var dist := 620.0
	_anim("charge")
	var t := Telegraph.line(get_parent(), global_position, dir, dist, radius * 2.0, 0.8)
	await t.fired
	if _dead:
		return
	_charging = true
	Audio.sfx("sfx_boss_attack", 0.1, -4.0)
	var travelled := 0.0
	var dust_t := 0.0
	while travelled < dist and not _dead:
		var step := 860.0 * get_physics_process_delta_time()
		velocity = dir * 860.0
		move_and_slide()
		global_position = global_position.clamp(arena.position, arena.end)
		travelled += step
		dust_t -= get_physics_process_delta_time()
		if dust_t <= 0.0:
			dust_t = 0.05
			Juice.fx("smoke", global_position + Vector2(0, radius * 0.6), 2.2, 0.0, Color(1, 1, 1, 0.6), -1)
		if boss_id != "sentinel" and get_slide_collision_count() > 0:
			break
		await get_tree().physics_frame
	_charging = false
	Juice.shake(6.0, 0.35)
	_anim("idle")


func _p_tail() -> void:
	_anim("attack")
	var t := Telegraph.circle(get_parent(), global_position, radius + 80.0, 0.6)
	await t.fired
	if _dead:
		return
	Juice.shake(6.0, 0.35)
	Juice.fx("slash_circular", global_position, 5.0, 0.0, Color(1.4, 1.1, 0.8))
	Audio.sfx("sfx_spin", 0.05, -2.0, 0.7)
	_hit_player_if(t, 12.0)
	_anim("idle")


func _p_jump_slam() -> void:
	var p := player()
	if p == null:
		return
	_anim("jump")
	Audio.sfx("sfx_jump", 0.05, -2.0, 0.6)
	var target := p.global_position
	var t := Telegraph.circle(get_parent(), target, 120.0, 1.0)
	_airborne = true
	var base_scale := shadow.scale
	var tw := create_tween()
	tw.tween_property(sprite, "position:y", -60.0 - 220.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(shadow, "scale", base_scale * 0.5, 0.45)
	tw.parallel().tween_property(self, "global_position", target, 0.9)
	tw.tween_property(sprite, "position:y", -60.0, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(shadow, "scale", base_scale, 0.4)
	await t.fired
	if _dead:
		return
	_airborne = false
	Audio.sfx("sfx_slam", 0.0, 0.0)
	Audio.sfx("sfx_explosion", 0.1, -6.0, 0.7)
	Juice.shake(13.0, 0.9)
	Juice.shockwave(global_position, 0.06, 0.6)
	Juice.fx("smoke_circular", global_position, 6.0, 0.0, Color(1, 0.95, 0.85))
	Juice.debris(global_position, "res://assets/ninja/fx/particle_rock.png", 6, 16)
	_hit_player_if(t, 18.0)
	for b in get_tree().get_nodes_in_group("breakable"):
		if is_instance_valid(b) and b.global_position.distance_to(global_position) < 130.0:
			b.take_damage(99.0, self)
	_anim("idle")


func _p_circle_player() -> void:
	var p := player()
	if p == null:
		return
	var shots := 3 if _phase2 else 2
	var ts: Array[Telegraph] = []
	for i in shots:
		var off := Vector2.ZERO if i == 0 else Vector2(randf_range(-110, 110), randf_range(-80, 80))
		ts.append(Telegraph.circle(get_parent(), p.global_position + off, 80.0, 1.0, Color(0.9, 0.3, 1.0)))
	await ts[0].fired
	if _dead:
		return
	Audio.sfx("sfx_boss_attack", 0.1, -4.0)
	for t in ts:
		Juice.fx("thunder", t.global_position + Vector2(0, -20), 4.0, 0.0, Color(1.6, 0.8, 2.2))
		_hit_player_if(t, 18.0)


func _p_ring() -> void:
	for wave in (2 if _phase2 else 1):
		var offset := randf() * TAU
		var o := _shot_origin()
		for i in 14:
			var dir := Vector2.RIGHT.rotated(offset + i * TAU / 14.0)
			Projectile.fire(get_parent(), o + dir * 30.0, dir, 210.0, 10.0, self, false, "big_energy_ball_purple" if boss_id == "sentinel" else "energy_ball")
		Audio.sfx("sfx_laser", 0.05, -4.0)
		Juice.light_flash(o, Color(0.8, 0.3, 1.0), 2.0, 2.5, 0.3)
		await get_tree().create_timer(0.5, false).timeout
		if _dead:
			return


func take_damage(amount: float, source: Node = null) -> void:
	if _dead or amount <= 0.0 or not active:
		return
	# One swing hitting several body parts in the same frame only counts once.
	var frame := Engine.get_physics_frames()
	if frame == _hit_frame and source == _hit_source:
		return
	_hit_frame = frame
	_hit_source = source
	if _flee_mode:
		amount *= 1.5
	damaged.emit(amount, source)
	_hurt_flash = 0.08
	var from_player: bool = source is Node2D and is_instance_valid(source) and source.is_in_group("player")
	Juice.number(global_position + Vector2(randf_range(-20, 20), -radius), amount, Color(1, 1, 0.6), true)
	Juice.fx("cut_x", global_position + Vector2(randf_range(-20, 20), -radius * 0.5), 2.4, randf() * TAU, Color(1.8, 1.6, 1.2))
	Audio.sfx("sfx_hit_heavy", 0.15, -4.0)
	if from_player:
		GameManager.add_combo(1)
		Juice.hitstop(0.05)
		Juice.shake(3.0, 0.25)
		_knock = (global_position - source.global_position).normalized() * 50.0
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
	Juice.shake(8.0, 0.6)
	Audio.sfx("sfx_boss_roar", 0.05, -3.0)
	Juice.text_pop(global_position + Vector2(0, -radius * 2), "ENRAGED", Color(1, 0.4, 0.4), 24)
	var summons: Array = cfg.get("summon", [])
	for i in summons.size():
		var id: String = summons[i]
		var e := Enemy.new()
		if id == "raptor_hunter":
			e.setup("raptor", {"state": "hunter", "sheet": EnemyData.TYPES.raptor.hunter_sheet})
		else:
			e.setup(id)
		e.drops = false
		e.arena = arena
		e.mirror_center_x = arena.get_center().x
		e.mirror_offset = Vector2(0, (i - 0.5) * 120.0)
		e.global_position = global_position + Vector2.RIGHT.rotated(i * TAU / summons.size()) * (radius + 60.0)
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
		if cfg.get("voice", "") != "":
			Voice.say(cfg.death, cfg.voice)
	Audio.sfx("sfx_boss_die", 0.0, 0.0)
	Audio.sfx("sfx_explosion_big", 0.0, -4.0)
	Juice.shake(14.0, 1.0)
	Juice.flash(Color(1, 1, 1, 0.6), 0.35)
	Juice.slow_pulse(0.25, 0.6)
	Juice.shockwave(global_position, 0.07, 0.7)
	for i in 6:
		Juice.fx("explosion", global_position + Vector2(randf_range(-radius, radius), randf_range(-radius * 1.5, radius * 0.3)), 3.5, 0.0, Color(1.4, 1.2, 1.2))
	for seg in segments:
		if is_instance_valid(seg):
			Juice.fx("explosion", seg.global_position, 3.0)
			seg.queue_free()
	for m in minions:
		if is_instance_valid(m) and m.has_method("die"):
			m.drops = false
			m.die()
	var parent := get_parent()
	Pickup.spawn_heal(parent, global_position + Vector2(-24, 0), 25.0)
	var id: String = cfg.get("fixed_drop", "")
	if id == "" or id in GameManager.artifacts:
		id = GameManager.roll_artifact("boss")
	if id != "":
		Pickup.spawn_artifact(parent, global_position + Vector2(24, 0), id)
	died.emit(self)
	Events.enemy_killed.emit(self)
	# Hide now, free later, so attack coroutines that are mid-await finish cleanly.
	visible = false
	collision_layer = 0
	set_physics_process(false)
	get_tree().create_timer(3.0).timeout.connect(queue_free)


func _update_visual() -> void:
	var f := 0.0
	if _hurt_flash > 0.0:
		f = 1.0
	_mat.set_shader_parameter("flash", f)
	_mat.set_shader_parameter("flash_color", Color.WHITE)
	if sprite.visible and sprite.sprite_frames:
		sprite.flip_h = _face.x < 0.0 if boss_id != "hypnotic" else false
		if not _busy and not _airborne:
			var want := "walk" if velocity.length() > 20.0 and sprite.sprite_frames.has_animation("walk") else "idle"
			if sprite.animation != want and sprite.animation in ["idle", "walk", "hit", "attack", "shoot", "charge", "jump"]:
				sprite.play(want)
		if _flee_mode:
			sprite.modulate = Color(1.3, 1.2, 0.7)
		else:
			sprite.modulate = Color(1.15, 1.15, 1.15) if _phase2 else Color.WHITE


func _draw() -> void:
	if _flee_mode:
		draw_arc(Vector2(0, -radius * 0.4), radius + 10.0, 0, TAU, 32, Color(1, 0.9, 0.4, 0.8), 3.0, true)
