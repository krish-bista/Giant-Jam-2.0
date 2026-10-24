class_name Interactable
extends Node2D
## Anything you press [E] next to: NPC, helmet, door, chest, terminal, lore stone, pedestal.

signal used

const FONT := preload("res://assets/ninja/ui/font.tres")

var prompt := "[E] Interact"
var reach := 70.0
var enabled := true
var texture: Texture2D
var sprite_scale := 3.0
var glow := false
var one_shot := false
var light_color := Color(0, 0, 0, 0)

var sprite: Sprite2D
var _label: Label
var _t := 0.0
var _light: PointLight2D


func _ready() -> void:
	if texture:
		sprite = Sprite2D.new()
		sprite.texture = texture
		sprite.scale = Vector2(sprite_scale, sprite_scale)
		sprite.offset = Vector2(0, -texture.get_height() * 0.5 + 2)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	if light_color.a > 0.0:
		_light = Sheet.make_light(light_color, 1.0, 1.2)
		_light.position = Vector2(0, -20)
		add_child(_light)
	_label = Label.new()
	_label.text = prompt
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(260, 24)
	var h := texture.get_height() * sprite_scale if texture else 30.0
	_label.position = Vector2(-130, -h - 30)
	_label.visible = false
	_label.z_index = 60
	add_child(_label)


func set_prompt(text: String) -> void:
	prompt = text
	if _label:
		_label.text = text


func _process(delta: float) -> void:
	_t += delta
	if sprite and glow and enabled:
		var g := 1.0 + 0.45 * (0.5 + 0.5 * sin(_t * 5.0))
		sprite.modulate = Color(g, g, g)
	elif sprite:
		sprite.modulate = Color.WHITE
	var p := get_tree().get_first_node_in_group("player")
	var near := enabled and p != null and global_position.distance_to(p.global_position) <= reach and not GameManager.input_locked
	_label.visible = near
	if near:
		_label.modulate.a = 0.75 + 0.25 * sin(_t * 6.0)
	if near and Input.is_action_just_pressed("interact"):
		if one_shot:
			enabled = false
			_label.visible = false
		Audio.sfx("sfx_ui_confirm", 0.05, -6.0)
		used.emit()
