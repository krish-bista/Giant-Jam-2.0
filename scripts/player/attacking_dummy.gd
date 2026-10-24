extends "res://scripts/player/training_dummy.gd"

# Stationary test fixture: a visible countdown, then one nearby simulated hit.
@export var attack_damage: int = 20
@export var attack_interval: float = 2.0
@export var attack_range: float = 130.0
var _attack_left: float = 2.0

@onready var _attack_label: Label = $AttackLabel

func _physics_process(delta: float) -> void:
    if health <= 0.0:
        _attack_label.text = ""
        return
    var player = get_tree().get_first_node_in_group("player")
    if not is_instance_valid(player) or global_position.distance_to(player.global_position) > attack_range:
        _attack_left = attack_interval
        _attack_label.text = "Approach to test shield"
        return
    _attack_left -= delta
    if _attack_left <= 0.0:
        player.take_damage(attack_damage, self)
        _attack_left = attack_interval
    _attack_label.text = "Hit in %.1fs" % _attack_left
