# Echo Breach — All Game Text

Tone: mysterious, short lines, no exposition dumps. Every line fits on one line of the dialogue box (≤ 60 characters).
Each block has an **id** so code can find it. Krish: copy the lines as `Array[String]` into `Events.dialogue_requested.emit([...])` or `Events.tutorial_prompt.emit("...")`.
`[E]`, `[Q]` etc. are the input actions from `INTERFACES.md`.

---

## 1. Amnesia room — `amnesia_room`

**`wake`** (player thought, shown when the scene starts)
- ...
- Where am I?

**`npc_lore`** (talk to the NPC with `[E]`)
1. You're awake. Good. Don't try to remember. Not yet.
2. Three days ago the sky cracked open. They came through.
3. Time is breaking. The pieces are scattered across it.
4. Only you can walk between them. Don't ask me why.
5. Put this on.

**`npc_repeat`** (talking to the NPC again)
- The helmet. Please.

**Prompts**
- `prompt_talk`: [E] Talk
- `prompt_helmet`: [E] Put on the helmet
- `door_locked`: The door doesn't open. Not from this side.

---

## 2. Tutorial (VR box world) — `tutorial`

Shown one at a time with `Events.tutorial_prompt`. Advance when the player does the action.

| id | Text | Advance when |
|---|---|---|
| `tut_enter` | Calibrating... Nothing here can hurt you. Yet. | 2.5s timer |
| `tut_move` | WASD to move. Space to dash. | Player moved + dashed once |
| `tut_take_sword` | [E] Take the Divine Sword | Sword picked up |
| `tut_attack` | Left click to strike. Aim with the mouse. | Dummy hit 3 times |
| `tut_take_shield` | [E] Take the Mirror Shield | Shield picked up |
| `tut_block` | Hold right click to block. | Blocked 1 dummy hit |
| `tut_reflect` | Block just as it lands. The mirror sends it back. | 2 perfect reflects |
| `tut_reflect_count` | Reflected %d / 2 | (counter under the prompt) |
| `tut_fragment` | A shard of a broken timeline. Step through. | Player enters the fragment |

`tut_good` (flash briefly after each step): **Good.**

---

## 3. World prompts

**World 1 — city**
- `w1_enter`: The city. Before it fell. Or after.
- `w1_wave`: Wave %d
- `hypno_unlock`: Hypno Reverse unlocked. [Q] Turn them on each other.
- `w1_portal`: The portal holds. Go.

**World 2 — jungle**
- `w2_enter`: They run from you. Hunt them.
- `w2_flip`: The pack has turned. Survive.
- `w2_survived`: The hunt is over. Take what you earned.
- `w2_portal`: Go before they remember you.

**World 3 — alien core**
- `w3_enter`: They move as you move.
- `w3_hint`: Make them strike each other.
- **`w3_twist`** (THE twist hint, scratched into a wall near the arena entrance, or a terminal the player walks past):
  - *We crossed time to escape the future he made.*

**After boss 3** — `final_choice`
- The last fragment is waiting.
- `[E] Enter the final fragment` / `Keep fighting`

---

## 4. Boss intros

Shown as a name banner + 1–2 lines while the boss's telegraph circle fades in. Keep each under 2 seconds to read.

| Boss | Banner | Intro lines | Death line |
|---|---|---|---|
| Hypnotic (mini) | THE HYPNOTIC | Look at me. Closer. / ...Which way is up now? | You'll see it too. Soon. |
| Warden (alien commander) | THE WARDEN | Hold the portal. Whatever it costs. | ...It's already too late for us. |
| Alpha Rex | ALPHA REX | *(no speech — a roar)* / The jungle remembers its first intruder. | *(roar fades)* |
| Core Sentinel | CORE SENTINEL | You again. You always come back. | We only wanted somewhere to run. |
| Evil You | **YOU** | You built me. Every artifact. Every kill. | *(none — see ending)* |

**Evil You taunts** (one shows each time the player hits it, cycle in order)
1. Again.
2. Stronger. Thank you.
3. You can't outfight yourself.
4. Every hit feeds me.
5. There's only one way this ends.

**Self-kill prompt** (appears after 20s, or 5 hits on Evil You, or player below 30% health)
- `final_prompt`: [E] Turn the blade on yourself.

---

## 5. Final cutscene — 4 static panels (before the final boss)

Each panel stays ~3s, text fades in at the bottom. Click/`[E]` skips to the next one.

| Panel (Nischal's file) | Image | Text |
|---|---|---|
| `cut_final_01.png` | The player stands in front of a huge cracked mirror. Black room, silver edges. | The last fragment shows only you. |
| `cut_final_02.png` | Close-up: the reflection smiles. The player does not. | It moves first. |
| `cut_final_03.png` | The reflection steps out, red and black, carrying every artifact. | Everything you took, it took too. |
| `cut_final_04.png` | Both stand face to face, swords raised. Red light between them. | Only one of you leaves. Neither of you can win. |

---

## 6. Ending — `ending`

After the self-kill: slowdown → mirror shatters → fade to white → black screen, `cut_ending.png` behind the text.
Lines fade in one at a time, 2.5s apart. No music, just the room tone.

1. The mirror is quiet.
2. Somewhere ahead, a sky stays whole.
3. No one will remember you.
4. That was the point.

*(pause 3s)*

**ECHO BREACH**
*Krish · Nischal · Azad*

---

## 7. Other screens

- `game_over`: The echo fades. / [E] Try again
- `pause`: Paused / [Esc] Resume
- `artifact_popup`: **{name}** — {desc} (names and descriptions in `balance/5_artifacts.tsv`)
- Ability icon tooltips (optional): Divine Sword · Mirror Shield · Hypno Reverse · Dash
