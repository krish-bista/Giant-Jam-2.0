extends CanvasLayer
## Bottom-of-screen hint box. Krish's logic shows hints with:
##   Events.tutorial_prompt.emit("Left click to swing the Divine Sword")   # "" hides it
## If the Events autoload does not exist yet, call show_text() directly.

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Label

var _tween: Tween


func _ready() -> void:
	_panel.visible = false
	var events := get_node_or_null("/root/Events")
	if events != null and events.has_signal("tutorial_prompt"):
		events.tutorial_prompt.connect(show_text)


func show_text(text: String) -> void:
	if text.is_empty():
		hide_prompt()
		return
	_label.text = text
	_panel.visible = true
	if is_instance_valid(_tween):
		_tween.kill()
	_panel.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.2)


func hide_prompt() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	_panel.visible = false
