class_name EvilSelf
extends Enemy
## The final boss: you, reversed. Copies your stats and artifacts, blocks and reflects,
## and gets stronger every time you hit it. You can't win by fighting.

signal ready_for_ending

const TAUNTS := ["Again.", "Stronger. Thank you.", "You can't outfight yourself.", "Every hit feeds me.", "There's only one way this ends."]

var active := false
var hits_taken := 0
var fight_time := 0.0
var prompt_shown := false
var frozen := false
var _blocking := false
var _block_t := 1.5
var _attack_t := 1.2
var _slash := 0.0
var _slash_dir := Vector2.RIGHT


func setup_evil() -> EvilSelf:
	cfg = {"tex": "res://assets/characters/mirror_evil_player.png", "hp": 9999.0, "radius": 14.0, "state": "chase"}
	_apply_cfg()
	var s: Dictionary = GameManager.stats
	max_health = s.max_health
	health = max_health
	damage = s.damage
	speed = s.speed * 0.8
	drops = false
	return self


func _ready() -> void:
	super._ready()
	add_to_group("boss")
	Events.boss_intro.emit("YOU", "You built me. Every artifact. Every kill.")
	Events.boss_health_changed.emit("YOU", health, max_health)
	Audio.sfx("sfx_boss_roar", 0.0, -6.0)
	await get_tree().create_timer(1.6, false).timeout
	active = true


func flip(_duration: float) -> void:
	Events.subtitle.emit("I know that trick. I am that trick.", Color(1, 0.5, 0.5))


func _physics_process(delta: float) -> void:
	var p := player()
	if frozen or not active or p == null:
		_update_visual()
		queue_redraw()
		return
	fight_time += delta
	_slash = maxf(0.0, _slash - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_check_prompt(p)

	_block_t -= delta
	if _block_t <= 0.0:
		_blocking = not _blocking
		_block_t = randf_range(0.8, 1.6)

	var to_p := p.global_position - global_position
	var move := Vector2.ZERO
	if _winding:
		_wind_left -= delta
		if _wind_left <= 0.0:
			_winding = false
			_slash = 0.15
			_slash_dir = to_p.normalized()
			Audio.sfx("sfx_sword_swing", 0.1, -4.0)
			if to_p.length() <= 70.0:
				p.take_damage(damage, self)
	else:
		_attack_t -= delta
		if to_p.length() > 50.0:
			move = to_p.normalized() * speed
		if _attack_t <= 0.0 and to_p.length() < 90.0:
			_attack_t = maxf(0.6, 1.3 - hits_taken * 0.05)
			_winding = true
			_wind_left = 0.35
	velocity = move + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	global_position = global_position.clamp(arena.position, arena.end)
	_update_visual()
	queue_redraw()


func _check_prompt(p: Node2D) -> void:
	if prompt_shown:
		return
	var low: bool = p.health < p.max_health * 0.3
	if fight_time >= 20.0 or hits_taken >= 5 or low:
		prompt_shown = true
		ready_for_ending.emit()


func take_damage(amount: float, source: Node = null) -> void:
	if not active or frozen or amount <= 0.0:
		return
	var from_front := true
	if source is Node2D and is_instance_valid(source):
		from_front = true
	# Blocks and reflects, like you.
	if _blocking and from_front and source != null and source.has_method("take_damage") and not source.get_meta("reflecting", false) and not _winding:
		Audio.sfx("sfx_reflect", 0.05, -4.0)
		Juice.burst(global_position, Color(1, 0.3, 0.3), 14, 200.0)
		set_meta("reflecting", true)
		source.take_damage(amount * GameManager.stats.reflect_power, self)
		set_meta("reflecting", false)
		Events.subtitle.emit("Mirror.", Color(1, 0.5, 0.5))
		return
	# Gets stronger every hit, and the damage doesn't stick.
	hits_taken += 1
	_hurt_flash = 0.1
	Audio.sfx("sfx_hit", 0.1, -3.0)
	Juice.number(global_position, amount, Color(1, 0.4, 0.4))
	Juice.burst(global_position, Color(1, 0.2, 0.25), 10, 160.0)
	health = maxf(1.0, health - amount)
	Events.boss_health_changed.emit("YOU", health, max_health)
	damage *= 1.15
	speed *= 1.05
	Events.subtitle.emit(TAUNTS[(hits_taken - 1) % TAUNTS.size()], Color(1, 0.5, 0.5))
	var heal_tween := create_tween()
	heal_tween.tween_interval(0.6)
	heal_tween.tween_method(func(v: float):
		health = v
		Events.boss_health_changed.emit("YOU", health, max_health), health, max_health, 0.8)


func _update_visual() -> void:
	if sprite == null:
		return
	var c := Color.WHITE
	if _winding:
		c = Color(1.8, 0.6, 0.6)
	if _hurt_flash > 0.0:
		c = Color(3, 3, 3)
	sprite.modulate = c
	var p := player()
	if p:
		sprite.flip_h = p.global_position.x < global_position.x


func _draw() -> void:
	if _blocking and active and not frozen:
		var p := player()
		var a := (p.global_position - global_position).angle() if p else 0.0
		draw_arc(Vector2.ZERO, 26.0, a - 1.2, a + 1.2, 24, Color(1, 0.3, 0.35, 0.7), 6.0, true)
	if _slash > 0.0:
		var a2 := _slash_dir.angle()
		draw_arc(Vector2.ZERO, 50.0, a2 - 0.9, a2 + 0.9, 24, Color(1, 0.3, 0.3, _slash / 0.15), 8.0, true)
