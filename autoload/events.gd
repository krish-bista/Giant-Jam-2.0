extends Node
## Global signal bus. No logic lives here: gameplay emits, UI listens.

# Contract signals (see docs/INTERFACES.md)
signal player_health_changed(current: float, max: float)
signal boss_health_changed(boss_name: String, current: float, max: float)  # max <= 0 hides the bar
signal ability_cooldown(ability: String, remaining: float, total: float)
signal hunt_meter_changed(value: float)
signal artifact_picked(artifact: Dictionary)
signal dialogue_requested(lines: Array)
signal tutorial_prompt(text: String)
signal player_died()

# Extra UI signals
signal ability_unlocked(ability: String)
signal boss_intro(boss_name: String, line: String)
signal subtitle(text: String, color: Color)
signal announce(text: String)
signal enemy_killed(enemy: Node)
signal combo_changed(count: int)
signal popup_text(text: String, world_pos: Vector2, color: Color)
signal player_revived(deaths: int)
signal weapon_changed(weapon_id: String)
signal objective_changed(text: String)
