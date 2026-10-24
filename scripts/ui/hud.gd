extends CanvasLayer
## In-game HUD: player health, ability cooldown sweeps, boss bar, hunt meter.
## Everything is driven by the team contract signals on the Events autoload
## (player_health_changed, ability_cooldown, boss_health_changed, hunt_meter_changed).
## It also hooks the Player node directly (health + dash) so it works before Events exists.
## Add one instance of hud.tscn to every playable level.

const ABILITIES := ["sword", "shield", "hypno", "dash"]

@onready var _player_bar: ProgressBar = $PlayerBar
@onready var _player_label: Label = $PlayerBar/Value
@onready var _abilities: HBoxContainer = $Abilities
@onready var _boss_root: Control = $Boss
@onready var _boss_name: Label = $Boss/Name
@onready var _boss_bar: ProgressBar = $Boss/Bar
@onready var _hunt_root: Control = $Hunt
@onready var _hunt_bar: ProgressBar = $Hunt/Bar

var _slots := {}       # ability -> slot Control
var _cooldowns := {}   # ability -> {"remaining": float, "total": float}
var _bar_tweens := {}  # ProgressBar -> Tween


func _ready() -> void:
	for a in ABILITIES:
		_slots[a] = _abilities.get_node(a.capitalize())
		_set_sweep(a, 0.0, 1.0)
	_slots["hypno"].visible = false   # shown once Hypno Reverse is unlocked
	_boss_root.visible = false
	_hunt_root.visible = false

	var events := get_node_or_null("/root/Events")
	if events != null:
		_try_connect(events, "player_health_changed", set_player_health)
		_try_connect(events, "ability_cooldown", _on_ability_cooldown)
		_try_connect(events, "boss_health_changed", set_boss_health)
		_try_connect(events, "hunt_meter_changed", set_hunt)

	# Fallback/extra: read the Player directly (works without Events).
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		if player.has_signal("health_changed"):
			player.health_changed.connect(set_player_health)
		if player.has_signal("dash_started"):
			player.dash_started.connect(func(_dir): start_cooldown("dash", player.dash_cooldown))
		if "health" in player and "max_health" in player:
			set_player_health(player.health, player.max_health, true)


func _try_connect(obj: Object, sig: String, target: Callable) -> void:
	if obj.has_signal(sig):
		obj.connect(sig, target)


# ---------------- public API (also called by the signals) ----------------
func set_player_health(current: float, max_value: float, instant: bool = false) -> void:
	_player_bar.max_value = maxf(max_value, 1.0)
	_tween_bar(_player_bar, current, instant)
	_player_label.text = "%d / %d" % [ceili(current), ceili(max_value)]


func set_boss_health(boss_name: String, current: float, max_value: float) -> void:
	if max_value <= 0.0:
		_boss_root.visible = false
		return
	_boss_root.visible = true
	_boss_name.text = boss_name
	_boss_bar.max_value = max_value
	_tween_bar(_boss_bar, current, false)


func set_hunt(value: float) -> void:
	_hunt_root.visible = true
	_tween_bar(_hunt_bar, clampf(value, 0.0, 100.0), false)


## Starts (or refreshes) a cooldown sweep. Shows the Hypno slot the first time it is used.
func start_cooldown(ability: String, remaining: float, total: float = -1.0) -> void:
	if not _slots.has(ability):
		return
	if ability == "hypno":
		_slots["hypno"].visible = true
	_cooldowns[ability] = {"remaining": remaining, "total": total if total > 0.0 else remaining}
	_set_sweep(ability, remaining, _cooldowns[ability]["total"])


func unlock_ability(ability: String) -> void:
	if _slots.has(ability):
		_slots[ability].visible = true


# ---------------- internals ----------------
func _on_ability_cooldown(ability: String, remaining: float, total: float) -> void:
	start_cooldown(ability, remaining, total)


func _process(delta: float) -> void:
	for a in _cooldowns.keys():
		var cd: Dictionary = _cooldowns[a]
		cd["remaining"] = maxf(0.0, cd["remaining"] - delta)
		_set_sweep(a, cd["remaining"], cd["total"])
		if cd["remaining"] <= 0.0:
			_cooldowns.erase(a)
			_flash_ready(a)


func _set_sweep(ability: String, remaining: float, total: float) -> void:
	var slot: Control = _slots[ability]
	var sweep: TextureProgressBar = slot.get_node("Sweep")
	var time_label: Label = slot.get_node("Time")
	if remaining > 0.0:
		sweep.value = clampf(remaining / maxf(total, 0.001), 0.0, 1.0) * 100.0
		time_label.text = "%.1f" % remaining if remaining < 10.0 else "%d" % ceili(remaining)
		time_label.visible = true
	else:
		sweep.value = 0.0
		time_label.visible = false


func _flash_ready(ability: String) -> void:
	var icon: Control = _slots[ability].get_node("Icon")
	icon.modulate = Color(2.2, 2.2, 2.2)
	create_tween().tween_property(icon, "modulate", Color.WHITE, 0.25)


func _tween_bar(bar: ProgressBar, value: float, instant: bool) -> void:
	if _bar_tweens.has(bar) and is_instance_valid(_bar_tweens[bar]):
		_bar_tweens[bar].kill()
	if instant:
		bar.value = value
		return
	var t := create_tween()
	t.tween_property(bar, "value", value, 0.15)
	_bar_tweens[bar] = t
