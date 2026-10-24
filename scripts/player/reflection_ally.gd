class_name ReflectionAlly
extends CharacterBody2D
## Your reflection, stepped out of the mirror to fight beside you: a translucent warrior.
## It can't be hurt (it's only light). It follows you, strikes the nearest enemy, and leaves
## if you lose your sanity.

const SPEED := 260.0
const ATTACK_CD := 0.8

var rig: PlayerRig
var _body: AnimatedSprite2D
var _cd := 0.6
var _player: Node2D
var _target: Node2D
var _side := -1.0
var _leaving := false


func _ready() -> void:
	add_to_group("ally")
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 12.0
	shape.shape = c
	add_child(shape)
	_body = AnimatedSprite2D.new()
	add_child(_body)
	rig = PlayerRig.new()
	add_child(rig)
	rig.setup(self, _body, "ally")
	rig.draw_sword()
	Juice.fx("circle_white", global_position, 3.0, 0.0, Color(1.2, 2.0, 2.4))
	Juice.light_flash(global_position, Color(0.5, 1.0, 1.0), 1.6, 2.0, 0.5)
	Audio.sfx("sfx_revive", 0.05, -6.0, 1.3)


func _physics_process(delta: float) -> void:
	if _leaving:
		return
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	if _player.get("rabid"):
		leave()
		return
	_cd -= delta
	if _target == null or not is_instance_valid(_target) or (_target is Enemy and _target._dead) or _target.global_position.distance_to(_player.global_position) > 420.0:
		_target = _nearest_enemy()
	var goal: Vector2
	var face: Vector2 = _player.global_position - global_position
	if _target:
		var to_t := _target.global_position - global_position
		face = to_t
		var reach: float = 46.0 + (_target.radius if "radius" in _target else 14.0)
		goal = _target.global_position - to_t.normalized() * (reach - 8.0)
		if to_t.length() <= reach + 6.0 and _cd <= 0.0:
			_strike(to_t)
	else:
		goal = _player.global_position + Vector2(_side * 56.0, 18.0)
		face = _player.get("facing_direction") if _player.get("facing_direction") else face
	var to_goal := goal - global_position
	velocity = to_goal.normalized() * minf(SPEED, to_goal.length() * 6.0) if to_goal.length() > 6.0 else Vector2.ZERO
	move_and_slide()
	if global_position.distance_to(_player.global_position) > 520.0:
		_blink_to(_player.global_position + Vector2(_side * 56.0, 18.0))
	rig.update(face, velocity, delta)


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := 380.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.is_in_group("flipped") or (e is Enemy and (e._dead or e.immortal)):
			continue
		var d: float = e.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _strike(dir: Vector2) -> void:
	_cd = ATTACK_CD
	rig.swing(dir, randi() % 2)
	var dmg: float = GameManager.stats.damage * 0.7
	# Hits count as yours (they build your combo).
	_target.take_damage(dmg, _player)


func _blink_to(pos: Vector2) -> void:
	Juice.fx("circle_white", global_position, 2.0, 0.0, Color(1.2, 2.0, 2.4, 0.7))
	global_position = pos
	Juice.fx("circle_white", pos, 2.0, 0.0, Color(1.2, 2.0, 2.4, 0.7))


## Shatters back into light.
func leave(line := true) -> void:
	if _leaving:
		return
	_leaving = true
	if line:
		Events.subtitle.emit("I can't follow you anymore. You're becoming the other one.", Color(0.6, 0.95, 1.0))
		Voice.say("I can't follow you anymore. You're becoming the other one.", "reflection")
	Audio.sfx("sfx_mirror_shatter", 0.1, -8.0)
	Juice.debris(global_position, "res://assets/ninja/fx/particle_rockgray.png", 6, 16, Color(1.4, 2.0, 2.4))
	var t := create_tween()
	t.tween_property(rig, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)
