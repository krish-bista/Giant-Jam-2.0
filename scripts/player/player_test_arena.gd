extends Node2D

@onready var _player = $Player
@onready var _status: Label = $TestHUD/Status

func _process(_delta: float) -> void:
    var shield = _player.get_node("MirrorShield")
    var state := "DOWN"
    if shield.is_held:
        state = "PERFECT READY" if shield.is_perfect() else "BLOCK (30% damage)"
    _status.text = "HP: %.1f / %d | Shield: %s\nWASD: move | Space: dash | Left click: sword | Hold right click: shield\nApproach the left dummy. Face it and raise the shield just before its countdown ends.\nRelease/repress to rearm. Face away to test rear hits. F6 restarts the arena." % [
        _player.health, _player.max_health, state]
