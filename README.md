# Echo Breach

A 2D top-down action game about **reversal**, built in Godot 4.7.2 for a 10-hour jam. About 10 minutes long.

You wake with no memory. A stranger hands you a VR helmet. Inside, you learn the Divine Sword and the Mirror Shield, then travel through mirror fragments to three broken timelines: a modern city under alien attack, a prehistoric jungle where the hunt flips on you, and a far-future alien core where enemies mirror your every move. At the end you face yourself, reversed. You can't win by fighting.

## Play

Open the project in **Godot 4.7.2** and press **F5**.

| Key | Action |
|---|---|
| WASD | Move |
| Space | Dash (invulnerable while dashing) |
| Left click | Divine Sword (aim with the mouse) |
| Right click (hold) | Mirror Shield. Raise it just before a hit lands to **reflect** the damage back |
| Q | Hypno Reverse (unlocked in World 1): enemies in front fight each other for a few seconds |
| E | Talk / interact / advance text |
| Esc | Pause |

## Flow

`amnesia_room → tutorial → world1 → world2 → world3 → final → ending`

| Scene | What happens |
|---|---|
| Amnesia room | Wake up, the Stranger's lore drop, put on the helmet |
| Tutorial | Move, dash, take the sword, attack, take the shield, block, 2 perfect reflects, step through the fragment |
| World 1 (city) | 3 alien waves, the Hypnotic mini boss (reverses your controls; unlocks Hypno Reverse), the Warden |
| World 2 (jungle) | Hunt the herd to fill the hunt meter, the pack flips and hunts you for 10s, Alpha Rex (switches between chasing and fleeing) |
| World 3 (core) | Mirror constructs copy your movement across the center line, the twist on a terminal, Core Sentinel, then keep fighting or enter the final fragment |
| Final | 4 cutscene panels, Evil You (copies your stats, blocks and reflects, gets stronger when hit), turn the blade on yourself |
| Ending | Quiet text over a whole sky |

## Project layout

| Folder | What's in it |
|---|---|
| `autoload/` | `Events` (signals), `GameManager` (scene switching, stats, artifacts, retry), `Audio`, `Juice` (shake, hit-stop, flash, particles, slow-mo) |
| `scripts/player/` | Player, Divine Sword, Mirror Shield (+ Krish's tests in `tests/`) |
| `scripts/enemies/` | `Enemy` (all states), `Boss` (telegraphed patterns, phase 2), `EvilSelf`, projectiles, telegraphs |
| `scripts/worlds/` | `Level` base + one script per scene |
| `scripts/props/` | Pickups, chests/interactables, portals |
| `scripts/ui/` | `GameUI` (dialogue, banners, popup, cutscenes, game over, pause) + Nischal's HUD and prompt |
| `scripts/data/` | Enemy/boss stats and the artifact table |
| `docs/` | Design, interfaces, dialogue, balance, audio, Git workflow |
| `tools/` | The automated playtest bot |

## Automated playtest

A bot can play the whole game by itself and report timings, deaths and errors:

```bash
ECHO_BOT=1 godot --headless --path . --fixed-fps 60
```

Optional: `ECHO_BOT_GOD=1` (bot can't die), `ECHO_BOT_SHOTS=<folder>` (save screenshots; run without `--headless`).
Krish's unit checks: `godot --headless --path . --script res://scripts/player/tests/sword_checks.gd` (and `shield_checks.gd`).

## Team

- **Krish**: gameplay programming
- **Nischal**: art, UI, levels
- **Azad**: design, writing, audio, integration

Asset credits: [docs/CREDITS.md](docs/CREDITS.md). Team rules: [docs/GIT_WORKFLOW.md](docs/GIT_WORKFLOW.md).
