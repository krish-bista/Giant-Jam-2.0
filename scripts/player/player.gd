extends CharacterBody2D
## Player: WASD + dash, Divine Sword (3-hit combo, spin finisher, dash lunge, riposte crit),
## Mirror Shield (perfect reflect bounces attacks back), Hypno Reverse.
## Levels call setup_for_level() to turn on game rules (item gating, i-frames, saved stats).
## Without it the player behaves exactly like Krish's original (his tests rely on that).

signal health_changed(current_health: float, max_health: int)
signal dash_started(direction: Vector2)
signal dash_ended
signal died(source: Variant)
signal blocked(perfect: bool)
signal swung
signal hurt(amount: float, source: Variant)

@export var max_health: int = 100
@export var damage: int = 20
@export var speed: float = 220.0
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.75
@export var reflect_power: float = 1.0
@export var luck: float = 0.0

const HYPNO_RANGE := 250.0
const HYPNO_COOLDOWN := 12.0
const CHAIN_WINDOW := 0.6
const RIPOSTE_WINDOW := 1.2
const LUNGE_WINDOW := 0.25

var health: float = 100.0
var facing_direction: Vector2 = Vector2.RIGHT
var controls_reversed: bool = false
var in_game := false
var hurt_iframes := 0.0
## Test hook for the playtest bot (aims without a mouse). Zero = use the mouse.
var aim_override := Vector2.ZERO
var rig: PlayerRig

var _dash_direction: Vector2 = Vector2.RIGHT
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_requested: bool = false
var _dead: bool = false
var _attack_requested: bool = false
var _reflecting: bool = false
var _iframes_left := 0.0
var _hypno_cooldown_left := 0.0
var _swing_count := 0
var _reverse_left := 0.0
var _chain := 0
var _last_swing := -10.0
var _last_dash_end := -10.0
var _riposte_until := -10.0
var _now := 0.0
var _special_cd := 0.0
var rabid := false

@onready var _visual: Node2D = $Visual
@onready var _sword = $DivineSword
@onready var _shield = $MirrorShield


func _ready() -> void:
	health = max_health
	if _visual is AnimatedSprite2D:
		rig = PlayerRig.new()
		add_child(rig)
		rig.setup(self, _visual, "player")
	_update_facing()


## Called by every level: load the run's stats and switch on game rules.
func setup_for_level() -> void:
	in_game = true
	hurt_iframes = 0.5
	_sword.show_arc = false
	sync_stats()
	health = clampf(GameManager.health, 1.0, max_health)
	_emit_health()
	if GameManager.is_rabid():
		set_rabid(true)


func sync_stats() -> void:
	var s: Dictionary = GameManager.stats
	max_health = int(s.max_health)
	damage = int(s.damage)
	speed = s.speed * (1.12 if rabid else 1.0)
	reflect_power = s.reflect_power
	luck = s.luck
	health = minf(maxf(health, GameManager.health), max_health)
	_emit_health()


func _can_sword() -> bool:
	return not in_game or GameManager.has_sword


func _can_shield() -> bool:
	return not in_game or GameManager.has_shield


func _locked() -> bool:
	return in_game and GameManager.input_locked


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_SPACE and event.pressed and not event.echo:
		_dash_requested = true


func _input(event: InputEvent) -> void:
	# A UI-consumed release must not leave the shield stuck up.
	if event.is_action_released("block"):
		_set_shield_held(false)


func _unhandled_input(event: InputEvent) -> void:
	if _locked():
		return
	if event.is_action_pressed("dash"):
		_dash_requested = true
	if event.is_action_pressed("block") and _can_shield():
		_set_shield_held(true)
	elif event.is_action_pressed("attack") and not _shield.is_held and _can_sword():
		_attack_requested = true
	elif event.is_action_pressed("hypno") and in_game:
		_try_hypno()
	elif event.is_action_pressed("special") and in_game:
		_try_special()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_node_ready():
		_set_shield_held(false)


func _set_shield_held(held: bool) -> void:
	held = held and not _dead
	_shield.set_held(held)
	_sword.attacks_enabled = not held and not _dead
	if held:
		_attack_requested = false
	if rig:
		rig.set_blocking(held, _shield.is_perfect())


func _physics_process(delta: float) -> void:
	_now += delta
	_update_facing()
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_iframes_left = maxf(0.0, _iframes_left - delta)
	_hypno_cooldown_left = maxf(0.0, _hypno_cooldown_left - delta)
	_special_cd = maxf(0.0, _special_cd - delta)
	if _reverse_left > 0.0:
		_reverse_left -= delta
		if _reverse_left <= 0.0:
			controls_reversed = false
	_update_blink()
	if rig:
		rig.set_blocking(_shield.is_held, _shield.is_perfect())
		rig.dashing = _dash_time_left > 0.0
		rig.update(facing_direction, velocity, delta)

	if _attack_requested:
		_attack_requested = false
		if not _dead:
			_swing()

	if _dead or _locked():
		velocity = Vector2.ZERO
		if _locked():
			_dash_requested = false
			if _shield.is_held:
				_set_shield_held(false)
		return

	var movement_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if controls_reversed:
		movement_input = -movement_input

	var dash_requested := _dash_requested
	_dash_requested = false
	if dash_requested and _dash_cooldown_left == 0.0 and _dash_time_left == 0.0:
		_start_dash(movement_input)

	if _dash_time_left > 0.0:
		velocity = _dash_direction * dash_speed
		move_and_slide()
		_dash_time_left = maxf(0.0, _dash_time_left - delta)
		if _dash_time_left == 0.0:
			_last_dash_end = _now
			dash_ended.emit()
		return

	var move_speed := speed * (0.5 if _shield.is_held and in_game else 1.0)
	velocity = movement_input * move_speed
	move_and_slide()


func _swing() -> void:
	if not in_game:
		if _sword.try_attack(facing_direction, damage, self):
			swung.emit()
		return
	# Pull the sword out first if it's on the back (fast, then the swing follows).
	if rig and rig.sheathed:
		var t := rig.draw_sword()
		await get_tree().create_timer(t, false).timeout
	var kind := 0
	if _now - _last_dash_end < LUNGE_WINDOW:
		kind = 3
	else:
		_chain = (_chain + 1) % 3 if _now - _last_swing < CHAIN_WINDOW else 0
		kind = _chain
	var crit := _now < _riposte_until
	var amount: float = damage * GameManager.combo_bonus() * (1.4 if rabid else 1.0)
	if GameManager.has_flag("echo_blade"):
		_swing_count += 1
		if _swing_count % 4 == 0:
			amount *= 2.0
	var arc := -1.0
	var bonus := 0.0
	match kind:
		2:
			amount *= 1.6
			arc = 360.0
			bonus = 20.0
		3:
			amount *= 1.3
			bonus = 25.0
			velocity = facing_direction * 520.0
			move_and_slide()
	if crit:
		amount *= 2.0
	if _sword.try_attack(facing_direction, amount, self, arc, bonus, 0.75 if kind < 2 else 1.1):
		_last_swing = _now
		swung.emit()
		if rig:
			rig.swing(facing_direction, kind, crit)
		Events.ability_cooldown.emit("sword", _sword.cooldown, _sword.cooldown)
		if crit and _sword.last_hits > 0:
			_riposte_until = -10.0
			Audio.sfx("sfx_crit", 0.0, -2.0)
			Juice.text_pop(global_position + facing_direction * 40.0, "CRIT!", Color(1, 0.85, 0.3), 24)
			Juice.hitstop(0.08)
		if kind == 2 and _sword.last_hits > 0:
			Juice.shake(5.0, 0.35)


## Called by projectiles before they hurt the player. Returns true if bounced back.
func try_deflect_projectile(projectile: Node2D) -> bool:
	if _dead or not _shield.is_held or not _shield.is_perfect():
		return false
	if not _shield.blocks_source(projectile, facing_direction):
		return false
	blocked.emit(true)
	_perfect_deflect_fx(projectile.global_position)
	return true


func take_damage(amount: float, source: Variant = null) -> void:
	if _dead or amount <= 0 or _reflecting:
		return
	if in_game and (_iframes_left > 0.0 or _dash_time_left > 0.0):
		return

	var damage_taken: float = amount
	if _shield.blocks_source(source, facing_direction):
		if _shield.is_perfect():
			_shield.flash_perfect()
			blocked.emit(true)
			if in_game:
				_perfect_deflect_fx((source as Node2D).global_position if source is Node2D else global_position)
			# Cooperate with the team metadata contract, and also stop reentrant
			# hits from reflectors that do not implement that contract themselves.
			if source.has_method("take_damage") and not source.get_meta("reflecting", false):
				var had_marker := has_meta("reflecting")
				var previous_marker = get_meta("reflecting", false)
				_reflecting = true
				set_meta("reflecting", true)
				var times := 2 if in_game and GameManager.has_flag("double_reflect") else 1
				for i in times:
					if is_instance_valid(source):
						source.take_damage(amount * reflect_power, self)
				if had_marker:
					set_meta("reflecting", previous_marker)
				else:
					remove_meta("reflecting")
				_reflecting = false
			return
		damage_taken *= _shield.damage_multiplier
		blocked.emit(false)
		if in_game:
			Audio.sfx("sfx_block", 0.08, -2.0)
			if rig:
				rig.block_fx()

	if rabid:
		damage_taken *= 1.25
	hurt.emit(damage_taken, source)
	var previous_health := health
	health = maxf(0.0, health - damage_taken)
	if health != previous_health:
		_emit_health()
	if in_game:
		_iframes_left = hurt_iframes
		GameManager.break_combo()
		Audio.sfx("sfx_player_hurt", 0.1, -2.0)
		Juice.shake(7.0, 0.5)
		Juice.flash(Color(1, 0.1, 0.15, 0.22), 0.18)
		Juice.number(global_position, damage_taken, Color(1, 0.4, 0.4), true)
		if rig:
			rig.hurt_flash()
		if source is Node2D and is_instance_valid(source):
			velocity = (global_position - (source as Node2D).global_position).normalized() * 300.0
			move_and_slide()
		if GameManager.has_flag("heal_on_hurt") and health > 0.0:
			var back := damage_taken * 0.25
			get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(self): heal(back, false))

	if health == 0.0:
		_dead = true
		_set_shield_held(false)
		died.emit(source)
		if in_game:
			Juice.burst(global_position, Color(0.75, 0.95, 1.0), 30, 260.0, 4.0)
			Juice.fx("smoke_circular", global_position, 4.0)
			_visual.visible = false
			if rig:
				rig.visible = false
			Events.player_died.emit()


func _perfect_deflect_fx(at: Vector2) -> void:
	_riposte_until = _now + RIPOSTE_WINDOW
	GameManager.add_combo(3)
	Audio.sfx("sfx_deflect", 0.04, 1.0)
	Audio.sfx("sfx_reflect", 0.05, -10.0, 1.3)
	Juice.hitstop(0.07)
	Juice.slow_pulse(0.3, 0.2)
	Juice.shockwave(global_position + facing_direction * 20.0, 0.05, 0.5)
	Juice.chroma(0.014)
	Juice.zoom_punch(0.06)
	Juice.flash(Color(0.7, 1.0, 1.0, 0.25), 0.15)
	Juice.text_pop(global_position + Vector2(0, -20), "REFLECT!", Color(0.6, 1.0, 1.0), 24, 46.0, 0.8)
	if rig:
		rig.deflect_fx(at)


func heal(amount: float, with_effects := true) -> void:
	if _dead:
		return
	health = minf(max_health, health + amount)
	_emit_health()
	if with_effects and in_game:
		Audio.sfx("sfx_heal", 0.05, -6.0)
		Juice.number(global_position, amount, Color(0.5, 1, 0.6))
		Juice.fx("circle_white", global_position, 2.5, 0.0, Color(0.6, 1.6, 0.8))


func reverse_controls(seconds: float) -> void:
	controls_reversed = true
	_reverse_left = seconds


func is_dead() -> bool:
	return _dead


func _emit_health() -> void:
	health_changed.emit(health, max_health)
	if in_game:
		GameManager.health = health
		Events.player_health_changed.emit(health, max_health)


## Hypno Reverse: a mirror wave rolls out from you. Everything inside is reversed:
## enemies turn on each other, enemy bolts fly back at their shooters, bosses reel.
## Their aggression becomes your strength: you heal a little for every enemy turned.
func _try_hypno() -> void:
	if not GameManager.hypno_unlocked or _hypno_cooldown_left > 0.0 or _dead:
		return
	_hypno_cooldown_left = HYPNO_COOLDOWN
	Events.ability_cooldown.emit("hypno", HYPNO_COOLDOWN, HYPNO_COOLDOWN)
	Audio.sfx("sfx_hypno_reverse", 0.03, 0.0)
	Audio.sfx("sfx_hypno", 0.05, -6.0)
	var duration := 8.0 if GameManager.has_flag("long_hypno") else 6.0
	var turned := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.has_method("flip"):
			continue
		if e.global_position.distance_to(global_position) <= HYPNO_RANGE + (60.0 if e.is_in_group("boss") else 0.0):
			e.flip(duration)
			if not e.is_in_group("boss"):
				turned += 1
	var reversed := 0
	for n in get_tree().current_scene.get_children():
		if n is Projectile and not n.hits_enemies and n.global_position.distance_to(global_position) <= HYPNO_RANGE * 1.6:
			n.reflect()
			reversed += 1
	if turned > 0:
		heal(3.0 * turned, false)
		Juice.text_pop(global_position + Vector2(0, -30), "%d REVERSED" % turned, Color(1, 0.6, 1.0), 24)
	if reversed > 0:
		GameManager.add_combo(reversed)
	_show_hypno_wave()


func _show_hypno_wave() -> void:
	Juice.invert(0.22)
	Juice.chroma(0.025)
	Juice.slow_pulse(0.35, 0.18)
	Juice.shockwave(global_position, 0.07, 0.6)
	Juice.zoom_punch(0.08)
	for i in 2:
		var ring := Line2D.new()
		ring.width = 8.0 - i * 3.0
		ring.default_color = Color(2.2, 0.7, 2.2, 0.9) if i == 0 else Color(0.7, 2.2, 2.4, 0.9)
		var pts := PackedVector2Array()
		for k in 49:
			pts.append(Vector2.RIGHT.rotated(k * TAU / 48.0) * 20.0)
		ring.points = pts
		ring.z_index = 20
		add_child(ring)
		var t := ring.create_tween()
		t.tween_interval(i * 0.08)
		t.tween_property(ring, "scale", Vector2.ONE * (HYPNO_RANGE / 20.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.parallel().tween_property(ring, "modulate:a", 0.0, 0.45)
		t.tween_callback(ring.queue_free)
	Juice.fx("aura", global_position, 7.0, 0.0, Color(2.0, 0.6, 1.8))
	Juice.light_flash(global_position, Color(1, 0.4, 1.0), 2.0, 4.0, 0.45)


## [F] The current world's special weapon.
func _try_special() -> void:
	var id: String = GameManager.weapon
	if id == "" or _special_cd > 0.0 or _dead:
		return
	var w: Dictionary = WeaponData.ALL[id]
	_special_cd = w.cooldown
	Events.ability_cooldown.emit("special", w.cooldown, w.cooldown)
	var dmg: float = damage * GameManager.combo_bonus() * (1.4 if rabid else 1.0)
	var parent := get_tree().current_scene
	if rig:
		rig.show_special(load(w.sprite), id)
	match id:
		"flare_bow":
			Audio.sfx("sfx_bow", 0.08, -2.0)
			for spread in [-0.12, 0.0, 0.12]:
				Projectile.player_shot(parent, global_position + facing_direction * 24.0, facing_direction.rotated(spread), 760.0, dmg * 1.1, self,
					{"tex": "res://assets/ninja/weapons/arrow.png", "tint": Color(1.8, 1.5, 0.8), "pierce": 3})
			Juice.light_flash(global_position + facing_direction * 30.0, Color(1, 0.85, 0.4), 1.4, 1.2, 0.2)
		"hunter_axe":
			Audio.sfx("sfx_axe", 0.05, 0.0)
			Juice.fx("slash_circular", global_position + facing_direction * 20.0, 5.0, facing_direction.angle(), Color(1.8, 1.1, 0.6))
			Juice.shake(8.0, 0.45)
			Juice.debris(global_position + facing_direction * 60.0, "res://assets/ninja/fx/particle_rock.png", 6, 10)
			var hit := 0
			for e in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("breakable"):
				if not is_instance_valid(e):
					continue
				var off: Vector2 = e.global_position - global_position
				if off.length() <= 120.0 and (off.length() < 20.0 or facing_direction.dot(off.normalized()) > -0.3):
					e.take_damage(dmg * 2.2, self)
					if e.has_method("stun"):
						e.stun(1.4)
					if e is Enemy:
						e._knock = off.normalized() * 520.0
					hit += 1
			if hit > 0:
				Juice.hitstop(0.09)
		"echo_wand":
			Audio.sfx("sfx_wand", 0.05, -2.0)
			for k in 3:
				Projectile.player_shot(parent, global_position + facing_direction * 20.0, facing_direction.rotated((k - 1) * 0.5), 420.0, dmg * 0.9, self,
					{"look": "big_energy_ball_purple", "tint": Color(1.1, 0.7, 1.3), "homing": 6.0})
			Juice.light_flash(global_position, Color(0.8, 0.4, 1.0), 1.6, 1.6, 0.25)


## Revive at your grave: an echo can't die, it only repeats.
func revive(pos: Vector2, hp_fraction := 0.6) -> void:
	_dead = false
	global_position = pos
	health = maxf(1.0, max_health * hp_fraction)
	_emit_health()
	_visual.visible = true
	if rig:
		rig.visible = true
	_iframes_left = 2.5
	controls_reversed = false
	velocity = Vector2.ZERO
	Audio.sfx("sfx_revive", 0.0, -2.0)
	Juice.fx("circle_white", pos, 4.0, 0.0, Color(1.2, 1.8, 2.2))
	Juice.light_flash(pos, Color(0.6, 0.9, 1.0), 2.0, 3.0, 0.6)
	Juice.shockwave(pos, 0.05, 0.5)
	# Push enemies away so you don't die again instantly.
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e is Enemy and e.global_position.distance_to(pos) < 240.0:
			e._knock = (e.global_position - pos).normalized() * 500.0
			e.stun(1.5)


## Rabid: you lost your sanity. Stronger and faster, but you take more damage and your mind frays.
func set_rabid(on: bool) -> void:
	rabid = on
	if rig:
		rig.set_rabid(on)
	sync_stats()


func _start_dash(movement_input: Vector2) -> void:
	if _locked():
		return
	_dash_direction = movement_input.normalized() if not movement_input.is_zero_approx() else facing_direction
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown
	dash_started.emit(_dash_direction)
	if in_game:
		Audio.sfx("sfx_dash", 0.1, -6.0)
		Juice.fx("smoke", global_position + Vector2(0, 10), 1.8, 0.0, Color(1, 1, 1, 0.6), -1)


func _update_blink() -> void:
	if not is_instance_valid(_visual):
		return
	var a := 1.0
	if _iframes_left > 0.0:
		a = 0.35 if int(_iframes_left * 20.0) % 2 == 0 else 1.0
	var base: Color = rig.base_tint if rig else Color.WHITE
	_visual.modulate = Color(1.0, 0.6, 1.0, a) if controls_reversed else Color(base.r, base.g, base.b, a * base.a)


func _update_facing() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if aim_override != Vector2.ZERO:
		to_mouse = aim_override
	if not to_mouse.is_zero_approx():
		facing_direction = to_mouse.normalized()
	if is_instance_valid(_visual) and _visual is Sprite2D:
		_visual.flip_h = facing_direction.x < 0.0
	if is_instance_valid(_shield):
		_shield.rotation = facing_direction.angle()
