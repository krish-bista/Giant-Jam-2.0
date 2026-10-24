class_name DragonSegment
extends Node2D
## One body piece of the Core Sentinel. You can hit any segment; damage goes to the boss.

var boss: Node
var radius := 30.0
var scale_factor := 2.6
var _spr: Sprite2D


func setup(tex: Texture2D, s: float) -> void:
	scale_factor = s
	_spr = Sprite2D.new()
	_spr.texture = tex
	_spr.scale = Vector2(s, s)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	radius = tex.get_width() * s * 0.4


func _ready() -> void:
	add_to_group("enemies")


func take_damage(amount: float, source: Node = null) -> void:
	if is_instance_valid(boss) and boss.has_method("take_damage"):
		boss.take_damage(amount * 0.7, source)
		_spr.modulate = Color(3, 3, 3)
		var t := create_tween()
		t.tween_property(_spr, "modulate", Color.WHITE, 0.12)


func flip(_d: float) -> void:
	pass
