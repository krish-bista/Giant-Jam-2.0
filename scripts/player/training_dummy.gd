extends Node2D

var max_health: float = 100.0
var health: float = 100.0
var _flash: Tween

@onready var _visual: Polygon2D = $Visual
@onready var _label: Label = $HealthLabel

func take_damage(amount: float, source: Node = null) -> void:
    if health <= 0.0 or amount <= 0.0:
        return
    health = maxf(0.0, health - amount)
    if is_instance_valid(_flash):
        _flash.kill()
    if health == 0.0:
        _label.text = "Defeated"
        _visual.modulate = Color(0.3, 0.3, 0.3)
        remove_from_group("enemies")
        remove_from_group("enemy")
        remove_from_group("damageable")
        return
    _label.text = "%d / 100" % ceili(health)
    _visual.modulate = Color(1.0, 0.15, 0.15)
    _flash = create_tween()
    _flash.tween_property(_visual, "modulate", Color.WHITE, 0.12)