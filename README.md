# Inverted Soul

A 2D top-down action game about **reversal**, built in Godot 4.7.2 for a jam. About 6 to 7 minutes long.

You wake with no memory. An old man tells you the helmet on the table is **the Reverser**, a machine
you built to turn time backwards, and that using it cracked time like a mirror. Now every era runs in
reverse and every world's clock counts down. Inside the Reverser you learn the Divine Sword and the
Mirror Shield, then follow the cracks through three timelines, each with one rule turned upside down:
the present-day city where the "invaders" are refugees, a prehistoric jungle where the hunter becomes
the hunted, and the Hollow Future, the same city reflected and rotted, where the hero is the cause.
At the end you face your own reflection. You can't win by fighting. When you fall, the Reverser rewinds
you, but every rewind leaves more of your reflection in you.

## Play

Open the project in **Godot 4.7.2** and press **F5**.

| Key | Action |
|---|---|
| WASD | Move |
| Space | Dash (invulnerable while dashing) |
| Left click | Divine Sword (aim with the mouse). 3 hits in a row = spin finisher; attack right after a dash = lunge; attack right after a reflect = **crit** |
| Right click (hold) | Mirror Shield. Raise it just before a hit lands to **reflect** it (bolts fly back at the shooter) |
| Q | Hypno Reverse (unlocked in World 1): a mirror wave that turns nearby enemies on each other, sends their bolts back and staggers bosses |
| F | The current world's special weapon (Flare Bow / Hunter's Axe / Echo Wand) |
| E | Talk / interact / advance text |
| Esc | Pause |

## The story
Time broke and runs backwards like a reflection. You walk the broken timelines back to the crack, and learn you made it: the "aliens" are survivors of the future you caused. Your reflection fights beside you in every world, and waits for you at the end, made of everything you took. You can't outfight yourself. Full script: [docs/DIALOGUE.md](docs/DIALOGUE.md).

**Deaths:** you leave a grave and revive, but lose sanity. 3 deaths locks in the **Reflection** ending; a 4th makes you **rabid** (stronger, faster, fragile, and your ally leaves). Survive with fewer than 3 deaths for the **Divine** ending.

## What makes it feel good
- Animated pixel-art hero with walking legs, a sword drawn from the back with a "shing", glowing slash trails, and a shiny mirror shield.
- Perfect deflects: slow-motion pulse, screen shockwave, chromatic flash, shield burst, layered metallic sound, "REFLECT!" pop.
- Combo counter (+1% damage per hit, up to +50%; getting hit resets it), crits, spin finishers, hit-stop, screen shake, damage numbers.
- Destructible barrels, crates, pots and crystals; red barrels explode and chain.
- Multi-part animated bosses: an orbiting-eye squid, a cyclops with turret orbs and an eye laser, a leaping beast, a segmented neon dragon.
- Explorable worlds about 2x the screen with a follow camera, day/night lighting, glow, rain/leaves/sparks, swaying trees, objective arrow.
- Voiced dialogue with character portraits, voiced boss lines, narrated cutscene and ending.

## Flow

`amnesia_room → tutorial → world1 → world2 → world3 → final → ending`

| Scene | What happens |
|---|---|
| Amnesia room | Wake up; the Stranger explains the reversal; put on the helmet |
| The Simulation | A holographic village. The Wise Elder trains you, or lets you skip |
| World 1: The Fallen City | 3 alien waves, the Hypnotic mini boss (reverses your controls; unlocks Hypno Reverse), the Warden |
| World 2: The First Hunt | Hunt the herd to fill the hunt meter, the pack flips and hunts you for 10s, the Alpha (switches between chasing and fleeing, leaps and slams) |
| World 3: The Hollow Future | The grim world: husks, wraiths, seers and brutes, the refugee log, the bone wyrm Core Sentinel, then keep fighting or enter the last mirror |
| Final | 4 panels; your reflection explains what it is, then fights (blocks, reflects, grows when hit); turn the blade on yourself, or it stops your hand |
| Ending | DIVINE (dawn) or REFLECTION (blood sky), narrated, with run stats |

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
| `tools/` | The automated playtest bot, and the asset/audio/voice build scripts (`tools/asset_scripts/`) |

## Automated playtest

A bot can play the whole game by itself and report timings, deaths and errors:

```bash
ECHO_BOT=1 godot --headless --path . --fixed-fps 60
```

Optional: `ECHO_BOT_GOD=1` (bot can't die), `ECHO_BOT_SHOTS=<folder>` (save screenshots; run without `--headless`), `ECHO_BOT_LIMIT=<seconds>`.

## Rebuilding assets and voices
```bash
python tools/asset_scripts/build_ninja_assets.py "<Ninja Adventure - Asset Pack>" assets/ninja
python tools/asset_scripts/build_audio.py "<Ninja Adventure - Asset Pack>" "<kenney packs folder>" audio
powershell -File tools/asset_scripts/make_voices.ps1 -Lines tools/asset_scripts/voice_lines.json -OutDir <raw folder>
python tools/asset_scripts/process_voices.py <raw folder> audio/voice
```
Then open Godot (or run `godot --headless --path . --import`) so the new files are imported.
Krish's unit checks: `godot --headless --path . --script res://scripts/player/tests/sword_checks.gd` (and `shield_checks.gd`).

## Team

- **Krish**: gameplay programming
- **Nischal**: art, UI, levels
- **Azad**: design, writing, audio, integration

Asset credits: [docs/CREDITS.md](docs/CREDITS.md). Team rules: [docs/GIT_WORKFLOW.md](docs/GIT_WORKFLOW.md).
