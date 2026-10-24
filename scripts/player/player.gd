extends CharacterBody2D

signal health_changed(current_health: float, max_health: int)
signal dash_started(direction: Vector2)
signal dash_ended
signal died(source: Variant)

@export var max_health: int = 100
@export var damage: int = 20
@export var speed: float = 220.0
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.75
@export var reflect_power: float = 1.0
@export var luck: float = 0.0

var health: float = 100.0
var facing_direction: Vector2 = Vector2.RIGHT
var controls_reversed: bool = false

var _dash_direction: Vector2 = Vector2.RIGHT
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_requested: bool = false
var _dead: bool = false
var _attack_requested: bool = false
var _reflecting: bool = false

@onready var _visual: Polygon2D = $Visual
@onready var _sword = $DivineSword
@onready var _shield = $MirrorShield

func _ready() -> void:
    health = max_health
    _update_facing()

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.physical_keycode == KEY_SPACE and event.pressed and not event.echo:
        _dash_requested = true

func _input(event: InputEvent) -> void:
    # A UI-consumed release must not leave the shield stuck up.
    if event.is_action_released("block"):
        _set_shield_held(false)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("block"):
        _set_shield_held(true)
    elif event.is_action_pressed("attack") and not _shield.is_held:
        _attack_requested = true

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

    if _attack_requested:
        _attack_requested = false
        if not _dead:
            _sword.try_attack(facing_direction, damage, self)

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
    if _dead or amount <= 0 or _reflecting:
        return

    var damage_taken: float = amount
    if _shield.blocks_source(source, facing_direction):
        if _shield.is_perfect():
            _shield.flash_perfect()
            # Cooperate with the team metadata contract, and also stop reentrant
            # hits from reflectors that do not implement that contract themselves.
            if source.has_method("take_damage") and not source.get_meta("reflecting", false):
                var had_marker := has_meta("reflecting")
                var previous_marker = get_meta("reflecting", false)
                _reflecting = true
                set_meta("reflecting", true)
                source.take_damage(amount * reflect_power, self)
                if had_marker:
                    set_meta("reflecting", previous_marker)
                else:
                    remove_meta("reflecting")
                _reflecting = false
            return
        damage_taken *= _shield.damage_multiplier

    var previous_health := health
    health = maxf(0.0, health - damage_taken)
    if health != previous_health:
        health_changed.emit(health, max_health)

    if health == 0.0:
        _dead = true
        _set_shield_held(false)
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
    if is_instance_valid(_shield):
        _shield.rotation = facing_direction.angle()