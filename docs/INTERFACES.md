# Echo Breach — Team Interface Contract

**Locked at hour 1. Changing anything here requires telling Azad first.**
Engine: **Godot 4.7.2 stable** (everyone uses this exact version; a different version re-saves files and causes conflicts). 2D top-down, 1280×720, GDScript only.

## 1. Scenes and flow
`amnesia_room → tutorial → world1 → world2 → world3 → final → ending`

- Every scene lives at `res://scenes/levels/<name>.tscn` (Nischal owns the layout/art of these files).
- Gameplay logic for a level goes in a separate scene owned by Krish: `res://scenes/components/<name>_logic.tscn`.
  Nischal adds it **once** as a child instance named `Logic` in each level. After that, nobody edits the other person's file.
- Switching scenes: **only** `GameManager.go_to_scene("world1")`. Never call `get_tree().change_scene_*` directly.

## 2. Autoloads (Krish writes, Azad registers in `project.godot`)
| Name | File | Purpose |
|---|---|---|
| `GameManager` | `res://autoload/game_manager.gd` | `go_to_scene(name: String)`, holds the player stats and artifacts between scenes |
| `Events` | `res://autoload/events.gd` | Signals only (no logic). UI listens; gameplay emits. |

`Events` signals (UI depends on these exact names):
```gdscript
signal player_health_changed(current: float, max: float)
signal boss_health_changed(boss_name: String, current: float, max: float)  # max <= 0 hides the bar
signal ability_cooldown(ability: String, remaining: float, total: float)  # "sword", "shield", "hypno", "dash"
signal hunt_meter_changed(value: float)   # 0..100, World 2 only
signal artifact_picked(artifact: Dictionary)
signal dialogue_requested(lines: Array[String])
signal tutorial_prompt(text: String)      # "" hides the prompt
signal player_died()
```

## 3. Damage — one function, everywhere
```gdscript
func take_damage(amount: float, source: Node) -> void
```
- Anything that can be hurt is in group `"damageable"` and has `take_damage`.
- `source` is the attacker node (or `null` for hazards). Always check `is_instance_valid(source)` before using it.
- **Reflect** = `source.take_damage(amount * reflect_power, self)`.
- **No reflect ping-pong:** set `set_meta("reflecting", true)` on yourself while calling the reflect, then set it back to false. Never reflect damage whose source has `get_meta("reflecting", false) == true`.

## 4. Stats (exact names, plain `var`s on the node)
`health, max_health, damage, speed, reflect_power, luck`
Player defaults: `100, 100, 10, 220, 1.0, 0`. Enemy values come from `docs/balance/`.
Artifacts change these directly, then emit `Events.player_health_changed`.

## 5. Artifact format (a Dictionary, same everywhere)
```gdscript
{ "id": "mirror_polish", "name": "Mirror Polish", "rarity": "rare",
  "desc": "Reflected damage +50%", "mods": { "reflect_power": 0.5 }, "flag": "" }
```
`mods` are added to stats. `flag` is for special effects: `heal_on_hurt`, `double_reflect`, `long_hypno`, `echo_blade`.
The ids and values are in `docs/balance/5_artifacts.tsv`.

## 6. Groups
`player`, `enemy`, `boss`, `damageable`, `flipped` (enemies under Hypno Reverse), `portal`, `pickup`

## 7. Physics layers (Azad sets the names in `project.godot`)
| # | Name | # | Name |
|---|---|---|---|
| 1 | world | 5 | enemy_attack |
| 2 | player | 6 | pickup |
| 3 | enemy | 7 | portal |
| 4 | player_attack | 8 | flipped_attack (hits enemies) |

## 8. Input actions (Azad adds them to `project.godot`)
`move_up/down/left/right` WASD · `attack` left mouse · `block` right mouse (hold) · `dash` Space · `hypno` Q · `interact` E · `pause` Esc

## 9. Art contract (so code never waits on art)
- Base size 32×32 px for characters and tiles. Bosses 64–96 px. Pixel art uses Nearest filtering.
- File names: `snake_case`, `<era>_<thing>[_<variant>].png`, e.g. `city_drone.png`, `ui_health_bar_fill.png`.
- Placeholder shapes keep the **same file name and size** as the final art, so swapping them changes no code.
- Code never relies on a sprite's size for gameplay. Hitboxes are always separate `CollisionShape2D`s.

## 10. Who owns what (edit only your own files)
- **Krish:** `autoload/`, `scripts/player|enemies|worlds/`, `scenes/player|enemies|components/`
- **Nischal:** `assets/`, `scenes/levels/`, `scenes/ui/`, `scripts/ui/`
- **Azad:** `audio/`, `docs/`, `project.godot`, `.gitignore`, merges into `main`, the export build
