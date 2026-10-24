class_name Enemy
extends CharacterBody2D
## One enemy script for every era. States:
##   chase   - walk to the player, attack in range (melee or ranged)
##   flee    - run away from the player (World 2 prey)
##   hunter  - fast chase (World 2 after the pack flips)
##   flipped - Hypno Reverse: attacks other enemies for a few seconds
##   mirror  - World 3: stands at the player's position mirrored across the center line
##   idle    - stands still; attacks the player if close (tutorial dummy)

signal damaged(amount: float, source: Node)
signal died(enemy: Enemy)

const FLIP_TINT := Color(1.0, 0.45, 1.0)

var type_id := ""
var cfg := {}
var max_health := 20.0
var health := 20.0
var damage := 8.0
var speed := 100.0
var flee_speed := 120.0
var attack_range := 34.0
var attack_cd := 1.2
var windup := 0.4
var radius := 14.0
var ranged := false
var keep_distance := 180.0
var immortal := false
var drops := true
var state := "chase"
var arena := Rect2(64, 64, 1152, 592)
var mirror_offset := Vector2.ZERO
var luck_bonus := 0.0

var _prev_state := "chase"
var _flip_left := 0.0
var _cd_left := 0.8
var _winding := false
var _wind_left := 0.0
var _knock := Vector2.ZERO
var _dead := false
var _hurt_flash := 0.0
var _swipe := 0.0
var _swipe_dir := Vector2.RIGHT
var _wander := Vector2.ZERO
var _wander_t := 0.0
var sprite: Sprite2D


func setup(id: String, overrides := {}) -> Enemy:
	type_id = id
	cfg = EnemyData.TYPES.get(id, {}).duplicate()
	cfg.merge(overrides, true)
	_apply_cfg()
	return self


func _apply_cfg() -> void:
	max_health = cfg.get("hp", 20.0)
	health = max_health
	damage = cfg.get("dmg", 8.0)
	speed = cfg.get("speed", 100.0)
	flee_speed = cfg.get("flee_speed", speed)
	attack_range = cfg.get("range", 34.0)
	attack_cd = cfg.get("cd", 1.2)
	windup = cfg.get("windup", 0.4)
	radius = cfg.get("radius", 14.0)
	ranged = cfg.get("ranged", false)
	keep_distance = cfg.get("keep", 180.0)
	immortal = cfg.get("immortal", false)
	drops = cfg.get("drops", true)
	state = cfg.get("state", "chase")
	_prev_state = state


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("enemy")
	add_to_group("damageable")
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if cfg.has("tex"):
		sprite.texture = load(cfg.tex)
	sprite.position.y = -4
	add_child(sprite)
	_cd_left = randf_range(0.6, 1.4)


func player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_cd_left -= delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_swipe = maxf(0.0, _swipe - delta)
	if _flip_left > 0.0:
		_flip_left -= delta
		if _flip_left <= 0.0:
			_unflip()

	var target := _current_target()
	var move := Vector2.ZERO
	if _winding:
		_wind_left -= delta
		if _wind_left <= 0.0:
			_winding = false
			_resolve_attack(target)
	else:
		move = _think(target, delta)

	velocity = move + _knock + _separation() * 60.0
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	global_position = global_position.clamp(arena.position, arena.end)
	_update_visual()
	queue_redraw()


func _current_target() -> Node2D:
	if state == "flipped":
		var best: Node2D = null
		var best_d := INF
		for e in get_tree().get_nodes_in_group("enemies"):
			if e == self or not is_instance_valid(e) or e.is_in_group("flipped") or (e is Enemy and e._dead):
				continue
			var d := global_position.distance_squared_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
		return best
	var p := player()
	if p and p.has_method("is_dead") and p.is_dead():
		return null
	return p


func _think(target: Node2D, delta: float) -> Vector2:
	match state:
		"idle":
			if target and global_position.distance_to(target.global_position) <= attack_range and _cd_left <= 0.0:
				_start_windup()
			return Vector2.ZERO
		"flee":
			if target == null:
				return Vector2.ZERO
			var away := (global_position - target.global_position)
			if away.length() > 340.0:
				return _wander_move(delta) * 0.5
			var dir := away.normalized()
			# Steer away from walls so prey doesn't get stuck in corners.
			var to_center := (arena.get_center() - global_position)
			if global_position.x < arena.position.x + 80 or global_position.x > arena.end.x - 80 or global_position.y < arena.position.y + 80 or global_position.y > arena.end.y - 80:
				dir = (dir + to_center.normalized() * 1.4).normalized()
			return dir * flee_speed
		"mirror":
			var p := player()
			if p == null:
				return Vector2.ZERO
			var c := arena.get_center()
			var goal := Vector2(2.0 * c.x - p.global_position.x, p.global_position.y) + mirror_offset
			goal = goal.clamp(arena.position, arena.end)
			var to_goal := goal - global_position
			if global_position.distance_to(p.global_position) <= attack_range and _cd_left <= 0.0:
				_start_windup()
			return (to_goal / maxf(delta, 0.001)).limit_length(speed) if to_goal.length() > 4.0 else Vector2.ZERO
		_:
			if target == null:
				return _wander_move(delta)
			var to_t := target.global_position - global_position
			var dist := to_t.length()
			if ranged and state != "flipped":
				if dist <= attack_range and _cd_left <= 0.0:
					_start_windup()
				if dist < keep_distance - 30.0:
					return -to_t.normalized() * speed
				elif dist > keep_distance + 30.0:
					return to_t.normalized() * speed
				return to_t.normalized().orthogonal() * speed * 0.4
			var reach: float = attack_range + (target.radius if target is Enemy else 14.0)
			if dist <= reach and _cd_left <= 0.0:
				_start_windup()
				return Vector2.ZERO
			if dist > reach * 0.7:
				return to_t.normalized() * speed
			return Vector2.ZERO


func _wander_move(delta: float) -> Vector2:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(0.8, 1.8)
		_wander = Vector2.RIGHT.rotated(randf() * TAU) * speed * 0.3
	return _wander


func _separation() -> Vector2:
	var push := Vector2.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e):
			continue
		var d: Vector2 = global_position - e.global_position
		var min_d: float = radius + (e.radius if e is Enemy else 14.0)
		if d.length() < min_d and d.length() > 0.01:
			push += d.normalized() * (min_d - d.length()) / min_d
	return push


func _start_windup() -> void:
	_winding = true
	_wind_left = windup
	_cd_left = attack_cd


func _resolve_attack(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var to_t := target.global_position - global_position
	if ranged and state != "flipped":
		Projectile.fire(get_parent(), global_position, to_t, 260.0, damage, self, false)
		Audio.sfx("sfx_laser", 0.1, -10.0)
		return
	_swipe = 0.15
	_swipe_dir = to_t.normalized()
	var reach: float = attack_range + 18.0 + (target.radius if target is Enemy else 14.0)
	if state == "mirror":
		# Mirror constructs strike everything around them, including each other.
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != self and is_instance_valid(e) and global_position.distance_to(e.global_position) <= reach:
				e.take_damage(damage, self)
	if to_t.length() <= reach:
		var dmg := damage * (1.5 if state == "flipped" else 1.0)
		target.take_damage(dmg, self)


func take_damage(amount: float, source: Node = null) -> void:
	if _dead or amount <= 0.0:
		return
	damaged.emit(amount, source)
	_hurt_flash = 0.1
	Juice.number(global_position, amount, Color(1, 1, 0.6))
	Juice.burst(global_position, Color(1, 0.9, 0.7), 8, 140.0, 2.5)
	Audio.sfx("sfx_hit", 0.15, -4.0)
	if source is Node2D and is_instance_valid(source):
		_knock = (global_position - source.global_position).normalized() * (260.0 if source.is_in_group("player") else 160.0)
		if source.is_in_group("player"):
			Juice.hitstop(0.05)
			Juice.shake(3.0, 0.25)
	if immortal:
		return
	health -= amount
	if health <= 0.0:
		die(source)


func die(_source: Node = null) -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("enemies")
	died.emit(self)
	Events.enemy_killed.emit(self)
	Audio.sfx("sfx_enemy_die", 0.15, -6.0)
	Juice.burst(global_position, sprite.modulate if sprite else Color.WHITE, 22, 220.0, 3.5)
	if drops:
		_drop_loot()
	queue_free()


func _drop_loot() -> void:
	var parent := get_parent()
	if randf() < 0.15:
		Pickup.spawn_heal(parent, global_position, 15.0)
	if randf() < (3.0 + GameManager.stats.luck) / 100.0:
		var id := GameManager.roll_artifact("enemy")
		if id != "":
			Pickup.spawn_artifact(parent, global_position + Vector2(12, 0), id)


func flip(duration: float) -> void:
	if _dead or immortal:
		return
	if state != "flipped":
		_prev_state = state
	state = "flipped"
	_flip_left = duration
	_winding = false
	add_to_group("flipped")
	Juice.burst(global_position, FLIP_TINT, 12, 120.0)


func _unflip() -> void:
	state = _prev_state
	remove_from_group("flipped")


func set_state(new_state: String) -> void:
	if state == "flipped":
		_prev_state = new_state
	else:
		state = new_state


func _update_visual() -> void:
	if sprite == null:
		return
	var base := Color.WHITE
	if state == "flipped":
		base = FLIP_TINT
	if _winding:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		base = base.lerp(Color(1.8, 0.5, 0.5), pulse)
	if _hurt_flash > 0.0:
		base = Color(3, 3, 3)
	sprite.modulate = base
	var p := player()
	if p and state != "flipped":
		sprite.flip_h = p.global_position.x < global_position.x


func _draw() -> void:
	if immortal and state == "idle" and _winding:
		var t := 1.0 - _wind_left / maxf(windup, 0.01)
		draw_circle(Vector2.ZERO, attack_range * t, Color(1, 0.2, 0.2, 0.18))
		draw_arc(Vector2.ZERO, attack_range, 0, TAU, 40, Color(1, 0.25, 0.25, 0.8), 2.0, true)
	if _swipe > 0.0:
		var a := _swipe_dir.angle()
		draw_arc(Vector2.ZERO, radius + 18.0, a - 0.9, a + 0.9, 16, Color(1, 0.4, 0.4, _swipe / 0.15), 5.0, true)
	if not immortal and health < max_health and health > 0.0:
		var w := maxf(radius * 2.4, 30.0)
		var y := -radius - 22.0
		draw_rect(Rect2(-w * 0.5 - 1, y - 1, w + 2, 6), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(-w * 0.5, y, w * health / max_health, 4), Color(1.0, 0.3, 0.3) if state != "flipped" else FLIP_TINT)
