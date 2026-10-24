# Echo Breach — Audio Plan

All audio lives in `audio/` (Azad owns it). Sound effects are in `audio/sfx/`, music in `audio/music/`.
**Replacing a sound = overwrite the file with the same name.** No code changes needed.

## Sound effects (in `audio/sfx/`, played with `Audio.sfx("name")`)

The code finds `.ogg` or `.wav` automatically, so you can swap formats freely. Sources are in [CREDITS.md](CREDITS.md).

| File | Plays when |
|---|---|
| `sfx_sword_swing` | Every sword swing |
| `sfx_hit` | Any enemy or boss takes damage |
| `sfx_shield_block` | Late block (damage reduced) |
| `sfx_reflect` | **Perfect** block / reflect |
| `sfx_player_hurt` | Player takes damage |
| `sfx_enemy_die` | Enemy dies |
| `sfx_dash` | Dash starts |
| `sfx_portal` | A mirror fragment appears / is entered |
| `sfx_pickup` | Artifact picked up |
| `sfx_heal` | Health orb picked up |
| `sfx_artifact` | (spare jingle) |
| `sfx_boss_roar` | Boss intro, phase 2, the pack flips |
| `sfx_boss_attack` | Boss laser / charge / ground slam |
| `sfx_boss_die` | Boss defeated |
| `sfx_laser` | Enemy and boss bolts |
| `sfx_hypno` | Hypno Reverse |
| `sfx_glitch` | Hypnotic pulse, helmet, ending prompt |
| `sfx_chest_open` | Chest opened |
| `sfx_mirror_shatter` | Final self-kill |
| `sfx_ui_confirm` / `sfx_dialogue` | Interact / dialogue text |

**Krish, the simplest way to play a sound:**
```gdscript
var sfx := AudioStreamPlayer.new()
sfx.stream = preload("res://audio/sfx/sfx_hit.wav")
sfx.bus = "SFX"
add_child(sfx)
sfx.play()
sfx.finished.connect(sfx.queue_free)
```
Add `sfx.pitch_scale = randf_range(0.9, 1.1)` for hits and swings so repeats don't sound robotic.

## Music (in `audio/music/`, played with `Audio.music("name")`, loops automatically)

| File | Scene(s) |
|---|---|
| `music_room.ogg` | amnesia_room, tutorial |
| `music_city.wav` | world1 |
| `music_jungle.wav` | world2 |
| `music_core.wav` | world3 |
| `music_final.ogg` | final (after the cutscene) |
| *(none)* | ending: silence |

## Tools and sources (all free)

| Tool / site | Use for | Licence to pick |
|---|---|---|
| **jsfxr** — sfxr.me | Retro SFX in seconds. Click a preset, Mutate, Export `.wav` | Your own creation |
| **ChipTone** — sfbgames.itch.io/chiptone | Slightly richer SFX than jsfxr | Your own creation |
| **Kenney** — kenney.nl/assets (Audio) | Impact, UI, RPG sound packs | CC0 |
| **Freesound** — freesound.org | Roars, glass, whooshes (filter: **Creative Commons 0**) | CC0 only |
| **OpenGameArt** — opengameart.org | Music loops (filter: **CC0**) | CC0 (CC-BY needs credits) |
| **Pixabay Music** — pixabay.com/music | Ambient tracks | Pixabay licence, no credit needed |
| **BeepBox** — beepbox.co | Make a simple looping track in the browser | Your own creation |
| **Audacity** | Trim silence, normalise, convert to `.ogg` | — |

Keep a list of anything that needs credit in the ending/credits screen.

## Mix rules

- Buses (already set up in `default_bus_layout.tres`): `Master` → `Music` (−8 dB) and `SFX` (0 dB). Always set `bus = "Music"` or `"SFX"` on players.
- Trim silence at the start of every SFX so hits feel instant.
- Reflect and boss roar are the loudest. Swings and footsteps are quiet.
- Final self-kill: cut the music to silence on the slowdown, play only `sfx_mirror_shatter`.
