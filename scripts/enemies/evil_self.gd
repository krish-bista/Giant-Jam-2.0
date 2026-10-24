class_name EvilSelf
extends Enemy
## The final boss: you, reversed. Same rig as the hero (red/black), copies your stats and
## artifacts, blocks and reflects, and gets stronger every time you hit it. You can't win by fighting.

signal ready_for_ending

const TAUNTS := ["Again.", "Stronger. Thank you.", "You can't outfight yourself.", "Every hit feeds me.", "There's only one way this ends."]

var active := false
var hits_taken := 0
var fight_time := 0.0
var prompt_shown := false
var frozen := false
var rig: PlayerRig
var _blocking := false
var _block_t := 1.5
var _attack_t := 1.2
var _aura: CPUParticles2D


func setup_evil() -> EvilSelf:
	cfg = {"hp": 9999.0, "radius": 14.0, "state": "chase"}
	_apply_cfg()
	var s: Dictionary = GameManager.stats
	max_health = s.max_health
	health = max_health
	damage = s.damage
	speed = s.speed * 0.8
	drops = false
	return self


func _build_visuals() -> void:
	sprite = AnimatedSprite2D.new()
	_mat = Sheet.sprite_material()
	add_child(sprite)
	rig = PlayerRig.new()
	add_child(rig)
	rig.setup(self, sprite, "evil")
	rig.draw_sword()
	shadow = rig.shadow
	_aura = CPUParticles2D.new()
	_aura.amount = 24
	_aura.lifetime = 1.0
	_aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_aura.emission_sphere_radius = 16.0
	_aura.direction = Vector2.UP
	_aura.spread = 25.0
	_aura.gravity = Vector2(0, -60)
	_aura.initial_velocity_min = 10.0
	_aura.initial_velocity_max = 40.0
	_aura.scale_amount_min = 2.0
	_aura.scale_amount_max = 4.0
	_aura.color = Color(1.4, 0.1, 0.2, 0.7)
	_aura.z_index = -1
	add_child(_aura)


func _ready() -> void:
	super._ready()
	add_to_group("boss")
	Events.boss_intro.emit("YOU", "You built me. Every artifact. Every kill.")
	Events.boss_health_changed.emit("YOU", health, max_health)
	Voice.say("You built me. Every artifact. Every kill.", "evil")
	Audio.sfx("sfx_boss_roar", 0.0, -6.0, 0.8)
	await get_tree().create_timer(1.8, false).timeout
	active = true


func flip(_duration: float) -> void:
	Events.subtitle.emit("I know that trick. I am that trick.", Color(1, 0.5, 0.5))
	Voice.say("I know that trick. I am that trick.", "evil")


func _physics_process(delta: float) -> void:
	var p := player()
	var to_p := (p.global_position - global_position) if p else Vector2.DOWN
	if rig:
		rig.set_blocking(_blocking and active and not frozen, false)
		rig.update(to_p, velocity, delta)
	if frozen or not active or p == null:
		velocity = Vector2.ZERO
		return
	fight_time += delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_check_prompt(p)

	_block_t -= delta
	if _block_t <= 0.0:
		_blocking = not _blocking
		_block_t = randf_range(0.8, 1.6)

	var move := Vector2.ZERO
	if _winding:
		_wind_left -= delta
		if _wind_left <= 0.0:
			_winding = false
			rig.swing(to_p, randi() % 2)
			if to_p.length() <= 75.0:
				p.take_damage(damage, self)
	else:
		_attack_t -= delta
		if to_p.length() > 52.0:
			move = to_p.normalized() * speed
		if _attack_t <= 0.0 and to_p.length() < 95.0 and not _blocking:
			_attack_t = maxf(0.6, 1.3 - hits_taken * 0.05)
			_winding = true
			_wind_left = 0.35
	velocity = move + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	global_position = global_position.clamp(arena.position, arena.end)


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
	# Blocks and reflects, like you.
	if _blocking and source != null and source.has_method("take_damage") and not source.get_meta("reflecting", false) and not _winding:
		Audio.sfx("sfx_deflect", 0.05, -3.0, 0.85)
		rig.deflect_fx(global_position)
		Juice.chroma(0.01)
		set_meta("reflecting", true)
		source.take_damage(amount * GameManager.stats.reflect_power, self)
		set_meta("reflecting", false)
		Events.subtitle.emit("Mirror.", Color(1, 0.5, 0.5))
		Voice.say("Mirror.", "evil")
		return
	# Gets stronger every hit, and the damage doesn't stick.
	hits_taken += 1
	rig.hurt_flash()
	Audio.sfx("sfx_hit_heavy", 0.1, -3.0)
	Juice.number(global_position, amount, Color(1, 0.4, 0.4), true)
	Juice.fx("cut_x", global_position, 2.4, randf() * TAU, Color(2.0, 0.4, 0.5))
	_knock = (global_position - (source as Node2D).global_position).normalized() * 120.0 if source is Node2D else Vector2.ZERO
	health = maxf(1.0, health - amount)
	Events.boss_health_changed.emit("YOU", health, max_health)
	damage *= 1.15
	speed *= 1.05
	_aura.amount = mini(80, _aura.amount + 8)
	var taunt: String = TAUNTS[(hits_taken - 1) % TAUNTS.size()]
	Events.subtitle.emit(taunt, Color(1, 0.5, 0.5))
	Voice.say(taunt, "evil")
	var heal_tween := create_tween()
	heal_tween.tween_interval(0.6)
	heal_tween.tween_method(func(v: float):
		health = v
		Events.boss_health_changed.emit("YOU", health, max_health), health, max_health, 0.8)


func _update_visual() -> void:
	pass


func _draw() -> void:
	pass
