extends CharacterBody2D
## Player: WASD + dash, Divine Sword, Mirror Shield (perfect reflect), Hypno Reverse.
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

const HYPNO_RANGE := 150.0
const HYPNO_ARC := 70.0
const HYPNO_COOLDOWN := 12.0

var health: float = 100.0
var facing_direction: Vector2 = Vector2.RIGHT
var controls_reversed: bool = false

## Game rules (off by default; levels switch them on)
var in_game := false
var hurt_iframes := 0.0

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
## Test hook for the playtest bot (aims without a mouse). Zero = use the mouse.
var aim_override := Vector2.ZERO

@onready var _visual: Node2D = $Visual
@onready var _sword = $DivineSword
@onready var _shield = $MirrorShield


func _ready() -> void:
	health = max_health
	_update_facing()


## Called by every level: load the run's stats and switch on game rules.
func setup_for_level() -> void:
	in_game = true
	hurt_iframes = 0.5
	sync_stats()
	health = clampf(GameManager.health, 1.0, max_health)
	_emit_health()


func sync_stats() -> void:
	var s: Dictionary = GameManager.stats
	max_health = int(s.max_health)
	damage = int(s.damage)
	speed = s.speed
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_node_ready():
		_set_shield_held(false)


func _set_shield_held(held: bool) -> void:
	held = held and not _dead
	_shield.set_held(held)
	_sword.attacks_enabled = not held and not _dead
	if held:
		_attack_requested = false


func _physics_process(delta: float) -> void:
	_update_facing()
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_iframes_left = maxf(0.0, _iframes_left - delta)
	_hypno_cooldown_left = maxf(0.0, _hypno_cooldown_left - delta)
	if _reverse_left > 0.0:
		_reverse_left -= delta
		if _reverse_left <= 0.0:
			controls_reversed = false
	_update_blink()

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
			dash_ended.emit()
		return

	var move_speed := speed * (0.5 if _shield.is_held and in_game else 1.0)
	velocity = movement_input * move_speed
	move_and_slide()


func _swing() -> void:
	var amount: float = damage
	if in_game and GameManager.has_flag("echo_blade"):
		_swing_count += 1
		if _swing_count % 4 == 0:
			amount *= 2.0
	if _sword.try_attack(facing_direction, amount, self):
		swung.emit()
		if in_game:
			Audio.sfx("sfx_sword_swing", 0.12, -4.0)
			Events.ability_cooldown.emit("sword", _sword.cooldown, _sword.cooldown)


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
				Audio.sfx("sfx_reflect", 0.05, -2.0)
				Juice.flash(Color(0.8, 1.0, 1.0, 0.35), 0.12)
				Juice.hitstop(0.06)
				Juice.burst(global_position + facing_direction * 24.0, Color(0.7, 1.0, 1.0), 16, 220.0)
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
			Audio.sfx("sfx_shield_block")

	hurt.emit(damage_taken, source)
	var previous_health := health
	health = maxf(0.0, health - damage_taken)
	if health != previous_health:
		_emit_health()
	if in_game:
		_iframes_left = hurt_iframes
		Audio.sfx("sfx_player_hurt", 0.1, -3.0)
		Juice.shake(7.0, 0.5)
		Juice.flash(Color(1, 0.1, 0.15, 0.22), 0.18)
		Juice.number(global_position, damage_taken, Color(1, 0.4, 0.4))
		if GameManager.has_flag("heal_on_hurt") and health > 0.0:
			var back := damage_taken * 0.25
			get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(self): heal(back, false))

	if health == 0.0:
		_dead = true
		_set_shield_held(false)
		died.emit(source)
		if in_game:
			Juice.burst(global_position, Color(0.75, 0.95, 1.0), 30, 260.0, 4.0)
			_visual.visible = false
			Events.player_died.emit()


func heal(amount: float, with_effects := true) -> void:
	if _dead:
		return
	health = minf(max_health, health + amount)
	_emit_health()
	if with_effects and in_game:
		Audio.sfx("sfx_heal", 0.05, -6.0)
		Juice.number(global_position, amount, Color(0.5, 1, 0.6))


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


func _try_hypno() -> void:
	if not GameManager.hypno_unlocked or _hypno_cooldown_left > 0.0 or _dead:
		return
	_hypno_cooldown_left = HYPNO_COOLDOWN
	Events.ability_cooldown.emit("hypno", HYPNO_COOLDOWN, HYPNO_COOLDOWN)
	Audio.sfx("sfx_hypno", 0.05)
	var duration := 8.0 if GameManager.has_flag("long_hypno") else 5.0
	var min_dot := cos(deg_to_rad(HYPNO_ARC * 0.5))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.has_method("flip"):
			continue
		var offset: Vector2 = e.global_position - global_position
		if offset.length() <= HYPNO_RANGE and (offset.is_zero_approx() or facing_direction.dot(offset.normalized()) >= min_dot):
			e.flip(duration)
	_show_hypno_cone()


func _show_hypno_cone() -> void:
	var cone := Polygon2D.new()
	var pts := PackedVector2Array([Vector2.ZERO])
	var half := deg_to_rad(HYPNO_ARC * 0.5)
	for i in 13:
		var a := -half + (2.0 * half) * i / 12.0
		pts.append(Vector2.RIGHT.rotated(a) * HYPNO_RANGE)
	cone.polygon = pts
	cone.color = Color(1.0, 0.3, 0.85, 0.45)
	cone.rotation = facing_direction.angle()
	cone.z_index = -1
	add_child(cone)
	var t := cone.create_tween()
	t.tween_property(cone, "modulate:a", 0.0, 0.4)
	t.tween_callback(cone.queue_free)


func _start_dash(movement_input: Vector2) -> void:
	if _locked():
		return
	_dash_direction = movement_input.normalized() if not movement_input.is_zero_approx() else facing_direction
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown
	dash_started.emit(_dash_direction)
	if in_game:
		Audio.sfx("sfx_dash", 0.1, -8.0)


func _update_blink() -> void:
	if not is_instance_valid(_visual):
		return
	if _iframes_left > 0.0:
		_visual.modulate.a = 0.35 if int(_iframes_left * 20.0) % 2 == 0 else 1.0
	else:
		_visual.modulate.a = 1.0
	_visual.modulate = Color(1.0, 0.6, 1.0, _visual.modulate.a) if controls_reversed else Color(1, 1, 1, _visual.modulate.a)


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
