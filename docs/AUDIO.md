# Echo Breach — Audio Plan

All audio lives in `audio/` (Azad owns it). Sound effects are `.wav` in `audio/sfx/`, music is `.ogg` in `audio/music/`.
**Replacing a sound = overwrite the file with the same name.** No code changes needed.

## Sound effects (placeholders already in `audio/sfx/`)

The current files are simple synth placeholders so Krish can wire them up now. Replace the important ones (★) with better versions when there's time.

| File | Plays when | Who triggers it | Replace with |
|---|---|---|---|
| ★ `sfx_sword_swing.wav` | Every sword swing | `divine_sword.gd` `try_attack` | Freesound "sword whoosh" CC0, or jsfxr **Blip/Select** with noise wave |
| ★ `sfx_hit.wav` | Any enemy takes damage | enemy `take_damage` | jsfxr **Hit/Hurt** |
| ★ `sfx_shield_block.wav` | Late block (damage reduced) | player shield | Kenney "Impact Sounds" (metal) |
| ★ `sfx_reflect.wav` | **Perfect** block / reflect | player shield | jsfxr **Powerup**, pitched up. Must feel amazing. |
| `sfx_player_hurt.wav` | Player takes damage | player `take_damage` | jsfxr **Hit/Hurt** (lower) |
| `sfx_enemy_die.wav` | Enemy dies | enemy | jsfxr **Explosion** (short) |
| `sfx_dash.wav` | Dash starts | player `dash_started` | jsfxr noise whoosh |
| ★ `sfx_portal.wav` | Entering a mirror fragment | portal before `go_to_scene` | Freesound "magic portal" CC0 |
| `sfx_pickup.wav` | Health orb / loot picked up | pickup | jsfxr **Pickup/Coin** |
| `sfx_artifact.wav` | Artifact picked up (with popup) | artifact pickup | jsfxr **Powerup** |
| ★ `sfx_boss_roar.wav` | Boss intro banner | each boss `_ready` / intro | Freesound "monster roar" CC0, pitch-shift per boss |
| `sfx_mirror_shatter.wav` | Final self-kill, the mirror breaks | final scene | Freesound "glass shatter" CC0 |
| `sfx_ui_confirm.wav` | Dialogue advance, menu click | UI | jsfxr **Blip/Select** |

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

## Music (to do, hours 5–7)

One track per era. If short on time: one track for everything + the SFX (that's on the cut list).

| File | Scene(s) | Mood | Where to get it fast |
|---|---|---|---|
| `music_room.ogg` | amnesia_room, tutorial | Quiet ambient pad, uneasy | Pixabay Music: search "ambient mystery" |
| `music_city.ogg` | world1 | Driving synth, tense | OpenGameArt (filter CC0): "synthwave battle" |
| `music_jungle.ogg` | world2 | Drums, tribal, chase | OpenGameArt CC0: "tribal drums loop" |
| `music_core.ogg` | world3 | Cold, pulsing, alien | OpenGameArt CC0: "sci-fi ambient loop" |
| `music_final.ogg` | final | Slow, heavy, one repeating motif | Make it in BeepBox (10 min) |
| *(none)* | ending | Silence. Only the shatter echo. | — |

In Godot: select the `.ogg` → Import tab → enable **Loop** → Reimport.

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
