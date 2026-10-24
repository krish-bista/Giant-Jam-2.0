extends Node2D

@export var attack_range: float = 65.0
@export_range(0.0, 360.0) var arc_angle: float = 100.0
@export var cooldown: float = 0.4
@export var slash_duration: float = 0.15

# The future shield can disable new attacks while blocking.
var attacks_enabled: bool = true

var _cooldown_left: float = 0.0
var _slash_time_left: float = 0.0
var _slash_direction: float = 0.0

func _process(delta: float) -> void:
    _cooldown_left = maxf(0.0, _cooldown_left - delta)
    if _slash_time_left > 0.0:
        _slash_time_left = maxf(0.0, _slash_time_left - delta)
        queue_redraw()

func try_attack(direction: Vector2, amount: float, attacker: Node2D) -> bool:
    if not attacks_enabled or _cooldown_left > 0.0 or direction.is_zero_approx():
        return false

    var facing := direction.normalized()
    _cooldown_left = cooldown
    _slash_time_left = slash_duration
    _slash_direction = facing.angle()
    queue_redraw()

    # One snapshot per click: each enemy root is visited once, independent of sprites.
    var minimum_dot := cos(deg_to_rad(arc_angle * 0.5))
    for target in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(target) or not target is Node2D:
            continue
        if target == attacker or attacker.is_ancestor_of(target) or target.is_in_group("player"):
            continue
        if not target.has_method("take_damage"):
            continue
        var offset: Vector2 = target.global_position - global_position
        if offset.length_squared() > attack_range * attack_range:
            continue
        if not offset.is_zero_approx() and facing.dot(offset.normalized()) < minimum_dot:
            continue
        target.take_damage(amount, attacker)
    return true

func _draw() -> void:
    if _slash_time_left <= 0.0 or slash_duration <= 0.0:
        return
    var remaining := clampf(_slash_time_left / slash_duration, 0.0, 1.0)
    var opacity := smoothstep(0.0, 1.0, remaining)
    var half_arc := deg_to_rad(arc_angle * 0.5)
    var radius := attack_range * lerpf(0.7, 1.0, 1.0 - remaining)
    draw_arc(Vector2.ZERO, radius, _slash_direction - half_arc, _slash_direction + half_arc,
        40, Color(0.1, 0.9, 1.0, opacity), 9.0, true)
    draw_arc(Vector2.ZERO, radius, _slash_direction - half_arc, _slash_direction + half_arc,
        40, Color(0.9, 1.0, 1.0, opacity), 3.0, true)