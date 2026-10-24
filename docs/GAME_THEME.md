# ECHO BREACH

**Theme:** Reversal
**Genre:** 2D top-down action RPG arena game (Brotato-style structure, League-style presentation)
**Engine:** Godot
**Dev time:** 10 hours | **Team:** Krish, Nischal, Azad
**Target play length:** ~10 minutes

---

## 1. Concept

You wake up with amnesia. A stranger gives you a VR helmet, and inside it you learn to fight with a **Divine Sword** and a **Mirror Shield** that reverses damage. Through **mirror fragments** you travel across three timelines, each one reversing the rules of the fight: damage, hunter and prey, and finally your own reflection.

You start weak and grow into something powerful. The last enemy is **yourself, reversed into evil**, and the only way to win is to stop fighting it and **kill yourself**. The game ends there.

**Reversal is everywhere:** damage is reversed by the shield, enemies are reversed by Hypno Reverse, hunters become hunted, the world mirrors your moves, and the final boss is you.

---

## 2. Story

- **Surface story:** Aliens are invading modern Earth. Timelines are breaking, and the mirror fragments are the only way to reach the weapons and answers scattered through time.
- **Hidden twist:** The aliens are refugees from a future you helped create. You were the invader all along.
- **Ending:** The evil version of you is the cost of that truth. Ending it means ending yourself.

---

## 3. Player Flow (~10 minutes)

| Time | Section | What happens |
|---|---|---|
| 0:00-1:00 | **Amnesia Room** | You wake with no memory. An NPC gives a 4-5 line lore drop and hands you a VR helmet. |
| 1:00-2:30 | **Tutorial (VR box world)** | A tiny room. You receive the Divine Sword and Mirror Shield and learn attack, block, reflect, and entering a large mirror fragment. Stepping into the fragment starts the game. |
| 2:30-5:30 | **World 1: Modern City** | Alien drone waves, then the Hypnotic mini boss (unlocks Hypno Reverse), then the Timeline 1 boss. |
| 5:30-7:30 | **World 2: Prehistoric Jungle** | Hunt the herd, then the pack hunts you. Timeline 2 boss. |
| 7:30-9:00 | **World 3: Far-Future Alien Core** | Mirrored arena, enemies copy your moves. Timeline 3 boss. |
| 9:00-10:00 | **Final Mirror Fragment** | After the third boss you can keep fighting or enter the final fragment. Short cutscene, then the final boss, then the ending. |

---

## 4. Core Kit

| Ability | Description |
|---|---|
| **Divine Sword** | Short-range arc attack, the base of all damage. |
| **Mirror Shield** | Hold to block. A block in the first ~0.3s is a **perfect reflect** that sends the damage back to the attacker. A late block only reduces damage. |
| **Hypno Reverse** | Unlocked by killing the Hypnotic mini boss. A cone ability that flips enemies for ~5s so they attack each other. Cooldown ~12s. |
| **Dash** | Short dash for movement and dodging. |
| **Mirror Fragments** | Large portals that move you between worlds. |

---

## 5. The Three Worlds

### World 1: Modern City (aliens attack)
- **Palette:** blue / grey
- **Enemies:** alien drones that swarm the player
- **Reversal:** damage reversal (shield reflect) and enemy reversal (Hypno Reverse)
- **Mini boss:** the Hypnotic alien, who tries to flip the player. Killing it unlocks Hypno Reverse.
- **Boss:** alien commander who opens the time portal

### World 2: Prehistoric Jungle (you are the intruder)
- **Palette:** green / brown
- **Enemies:** raptors and mammoth-type brutes
- **Reversal:** hunter becomes hunted. Chasing fleeing animals fills the **hunt meter**. When full, the whole pack flips and hunts the player for ~10s. Surviving gives a reward.
- **Boss:** giant predator that swaps between chasing and fleeing

### World 3: Far-Future Alien Core (the truth)
- **Palette:** purple / neon
- **Enemies:** mirror constructs
- **Reversal:** mirror arena. The room is split down the middle and enemies copy your movement mirrored across the center line. Win by baiting them into hitting themselves.
- **Boss:** Timeline 3 boss. One line in this world hints at the story twist.

---

## 6. Progression

- **Enemy loot:** small drops from enemies, plus chests placed in each world.
- **Artifacts:** the main upgrade system. Each gives a stat boost, and some have reversal twists. About 6 to 10 total.
  - Examples: +damage, +speed, +max health, "damage you take heals you a little," "reflected damage hits twice," "Hypno Reverse lasts longer."
- **Stats (shared names):** `health`, `max_health`, `damage`, `speed`, `reflect_power`, `luck`
- **Power curve:** fragile in World 1, competent in World 2, dominant in World 3.

---

## 7. Final Boss: Yourself, Reversed

- The evil you has your sword, your shield, and **every artifact you collected**.
- It reflects your attacks and grows stronger the more you hit it, so fighting normally cannot work.
- **Solution:** the player turns the sword on themselves. The mirror shatters, the evil reversal dies with you, and the game ends with a short, quiet ending text.
- The stronger you built yourself, the more hopeless fighting it is, which makes the self-kill the payoff of the progression system.

---

## 8. Presentation

- **View:** 2D top-down, clean ground plane, round readable characters
- **League-like touches:** health bars above heads, glowing ground circles to telegraph attacks, ability icons with cooldown sweeps along the bottom
- **Palettes:** modern blue/grey, jungle green/brown, future purple/neon, tutorial white/soft cyan, final room black/silver/red
- **Art style:** simple shapes with strong silhouettes. The evil you is a red/black palette swap of the player.
- **Juice:** screen shake, 50ms hit-stop, hit particles, a flash on reflect, a dramatic slowdown on the final self-kill

---

## 9. Technical Agreements (all three)

- **Damage:** one function, `take_damage(amount, source)`. Shield reflection calls it back on the source.
- **Scene switching:** one global function, `go_to_scene(name)`, owned by Krish.
- **Scene names:** `amnesia_room`, `tutorial`, `world1`, `world2`, `world3`, `final`, `ending`
- **Enemy states:** `chase`, `flee`, `flipped`. World 2 reversal is mostly swapping these states.
- **Workflow:** everyone edits only their own scenes. Only Azad merges into main.
- **Placeholder art from minute one** so Krish is never blocked.

---

## 10. Team Roles

### Krish: Gameplay Programmer
- Player movement, dash, Divine Sword, Mirror Shield block and reflect
- Hypno Reverse
- Enemy AI and the shared health/damage system
- Wave spawners and boss logic for all worlds, including the Hypnotic mini boss
- Mirror fragment portals and scene switching
- World 2 hunt meter and World 3 mirror logic
- Artifact pickup and stat application
- Final boss and the self-kill ending

### Nischal: Artist / UI / Level
- Sprites: player, NPC, enemies, mini boss, 3 bosses, evil you
- Backgrounds for the amnesia room, tutorial box world, three worlds, and final mirror room
- Mirror fragments, chests, loot drops, artifact icons
- UI: health bars, ability icons with cooldowns, hunt meter, artifact popup, dialogue box, game over and ending screens, telegraph circles
- Final cutscene panels (3 to 4 static) and the ending image

### Azad: Designer / Audio / Story / Integration
- Lore text, NPC dialogue, tutorial prompts, boss intro lines, cutscene script, ending text
- Balance spreadsheet: enemy stats, wave timing, boss health, artifact values, chest and loot tables
- Sound effects, music per era, and the juice pass
- Scene flow, merging all work into main, playtests at hours 5, 8, and 9
- 10-minute pacing check, build, and export

---

## 11. Pacing Targets

| Section | Target |
|---|---|
| Amnesia room + tutorial | 2:30 |
| World 1 | ~3:00 |
| World 2 | ~2:00 |
| World 3 | ~1:30 |
| Finale | ~1:00 |

---

## 12. Schedule

| Hours | Krish | Nischal | Azad |
|---|---|---|---|
| 0-1 | Project setup, player movement | Placeholder shapes, palettes | Lock interfaces, version control, spreadsheet |
| 1-3 | Sword, shield, reflect, tutorial logic | Amnesia room, tutorial world, player and NPC sprites | Dialogue and tutorial text, first sounds |
| 3-5 | World 1 waves, mini boss, Hypno Reverse | World 1 enemies, mini boss, background, UI bars | Enemy stats, merge World 1, playtest 1 |
| 5-7 | Worlds 2 and 3 mechanics | World 2 and 3 art, bosses | Loot tables, music, merge |
| 7-8.5 | Artifacts, chests, final boss, ending | Artifact icons, cutscene panels, end screen | Cutscene script, integration |
| 8.5-10 | Bug fixes | UI polish | Juice, balance, pacing, export |

---

## 13. Scope Rules

**Cut in this order if behind:**
1. Artifacts beyond about 6
2. The "keep farming" option after boss 3
3. Cutscene animation (use static panels)
4. Chests (keep enemy loot only)
5. Music variety (one track plus sound effects)

**Never cut:** the Divine Sword and Mirror Shield, one reversal mechanic per world, the three bosses, and the self-kill ending.

**Out of scope:** a scrolling world or map, multiple playable characters, pathfinding-heavy AI, detailed animation, and reversed controls (unless time remains).

---

## 14. Design Pillars

1. **Everything reverses.** Every system should have a reversal twist.
2. **Start weak, end powerful.** The player must feel growth every few minutes.
3. **Short and punchy.** Instant feedback, big hit feel, no dead time.
4. **One strong ending.** The self-kill is the signature moment, so protect it.
