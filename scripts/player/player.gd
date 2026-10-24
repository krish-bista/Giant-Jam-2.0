extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal dash_started(direction: Vector2)
signal dash_ended
signal died(source: Variant)

@export var max_health: int = 100
@export var damage: int = 20
@export var speed: float = 220.0
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.75
@export var reflect_power: float = 0.0
@export var luck: float = 0.0

var health: int = 100
var facing_direction: Vector2 = Vector2.RIGHT
var controls_reversed: bool = false

var _dash_direction: Vector2 = Vector2.RIGHT
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_requested: bool = false
var _dead: bool = false

@onready var _visual: Polygon2D = $Visual

func _ready() -> void:
    health = max_health
    _update_facing()

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.physical_keycode == KEY_SPACE and event.pressed and not event.echo:
        _dash_requested = true

func _physics_process(delta: float) -> void:
    _update_facing()
    _dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)

    if _dead:
        velocity = Vector2.ZERO
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

    velocity = movement_input * speed
    move_and_slide()

func take_damage(amount: int, source: Variant = null) -> void:
    if _dead or amount <= 0:
        return

    var previous_health := health
    health = maxi(0, health - amount)
    if health != previous_health:
        health_changed.emit(health, max_health)

    if health == 0:
        _dead = true
        died.emit(source)

func _start_dash(movement_input: Vector2) -> void:
    _dash_direction = movement_input.normalized() if not movement_input.is_zero_approx() else facing_direction
    _dash_time_left = dash_duration
    _dash_cooldown_left = dash_cooldown
    dash_started.emit(_dash_direction)

func _update_facing() -> void:
    var to_mouse := get_global_mouse_position() - global_position
    if not to_mouse.is_zero_approx():
        facing_direction = to_mouse.normalized()
    if is_instance_valid(_visual):
        _visual.rotation = facing_direction.angle()