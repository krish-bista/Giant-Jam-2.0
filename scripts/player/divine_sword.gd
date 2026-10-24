extends Node2D

@export var attack_range: float = 65.0
@export_range(0.0, 360.0) var arc_angle: float = 100.0
@export var cooldown: float = 0.4
@export var slash_duration: float = 0.15

# The future shield can disable new attacks while blocking.
var attacks_enabled: bool = true
## The game draws its own slash effects; the simple arc is kept for the test arena.
var show_arc: bool = true
## Hits landed by the last swing (the player uses it for combos).
var last_hits: int = 0

var _cooldown_left: float = 0.0
var _slash_time_left: float = 0.0
var _slash_direction: float = 0.0

func _process(delta: float) -> void:
    _cooldown_left = maxf(0.0, _cooldown_left - delta)
    if _slash_time_left > 0.0:
        _slash_time_left = maxf(0.0, _slash_time_left - delta)
        queue_redraw()

func try_attack(direction: Vector2, amount: float, attacker: Node2D, arc_override: float = -1.0, range_bonus: float = 0.0, cooldown_scale: float = 1.0) -> bool:
    if not attacks_enabled or _cooldown_left > 0.0 or direction.is_zero_approx():
        return false

    var facing := direction.normalized()
    var arc := arc_angle if arc_override < 0.0 else arc_override
    var reach := attack_range + range_bonus
    last_hits = 0
    _cooldown_left = cooldown * cooldown_scale
    _slash_time_left = slash_duration
    _slash_direction = facing.angle()
    queue_redraw()

    # One snapshot per click: each enemy root is visited once, independent of sprites.
    var minimum_dot := cos(deg_to_rad(arc * 0.5))
    var targets: Array = get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("breakable")
    for target in targets:
        if not is_instance_valid(target) or not target is Node2D:
            continue
        if target == attacker or attacker.is_ancestor_of(target) or target.is_in_group("player"):
            continue
        if not target.has_method("take_damage"):
            continue
        var offset: Vector2 = target.global_position - global_position
        # Reach is measured to the target's edge, so big bosses can be hit from outside their body.
        var target_radius: float = target.get("radius") if target.get("radius") != null else 0.0
        if offset.length() - target_radius > reach:
            continue
        if arc < 359.0 and not offset.is_zero_approx() and facing.dot(offset.normalized()) < minimum_dot:
            continue
        if target.is_in_group("enemies"):
            last_hits += 1
        target.take_damage(amount, attacker)
    return true

func _draw() -> void:
    if not show_arc:
        return
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