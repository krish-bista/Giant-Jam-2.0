extends Node2D

@export var perfect_window: float = 0.3
@export_range(0.0, 360.0) var block_arc: float = 160.0
@export_range(0.0, 1.0) var damage_multiplier: float = 0.3

var is_held: bool = false
var _perfect_timer: SceneTreeTimer
var _flash_left: float = 0.0

func set_held(held: bool) -> void:
    if held == is_held:
        return
    is_held = held
    # Only a rising edge opens a window. Releasing invalidates the old timer.
    _perfect_timer = get_tree().create_timer(perfect_window, false, true) if held else null
    queue_redraw()

func is_perfect() -> bool:
    return is_held and is_instance_valid(_perfect_timer) and _perfect_timer.time_left > 0.0

func blocks_source(source: Variant, facing: Vector2) -> bool:
    if not is_held or not is_instance_valid(source) or not source is Node2D:
        return false
    var offset: Vector2 = source.global_position - global_position
    # Unknown, invalid or coincident positions have no usable direction: bypass block.
    if not offset.is_finite() or offset.is_zero_approx() or facing.is_zero_approx():
        return false
    return facing.normalized().dot(offset.normalized()) >= cos(deg_to_rad(block_arc * 0.5)) - 0.000001

func flash_perfect() -> void:
    _flash_left = 0.12
    queue_redraw()

func _process(delta: float) -> void:
    if is_held or _flash_left > 0.0:
        _flash_left = maxf(0.0, _flash_left - delta)
        queue_redraw()

func _draw() -> void:
    if not is_held and _flash_left <= 0.0:
        return
    var half_arc := deg_to_rad(block_arc * 0.5)
    var color := Color(0.1, 0.85, 1.0, 0.45)
    if is_perfect():
        color = Color(0.45, 1.0, 1.0, 0.85)
    draw_arc(Vector2.ZERO, 26.0, -half_arc, half_arc, 48, color, 7.0, true)
    if _flash_left > 0.0:
        draw_arc(Vector2.ZERO, 29.0, -half_arc, half_arc, 48,
            Color(1.0, 1.0, 1.0, _flash_left / 0.12), 10.0, true)
