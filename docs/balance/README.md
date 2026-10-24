# Echo Breach — Balance Sheet

Each `.tsv` file in this folder is one Google Sheets tab. To paste one: open the file, select all, copy, then paste into cell A1.
Change numbers in the sheet first, then update this folder so the team sees the same values.

## Player

| Stat / ability | Value | Unit | Notes |
|---|---|---|---|
| max_health | 100 | hp | Artifacts can raise it |
| damage | 10 | per hit | Sword hit damage |
| speed | 220 | px/s | Move speed |
| reflect_power | 1.0 | x | Perfect block sends back amount * reflect_power |
| luck | 0 | points | Each point = +1% artifact drop chance and shifts rarity |
| Sword cooldown | 0.35 | s | ~2.8 swings/s |
| Sword arc | 100 | deg | Toward mouse |
| Sword range | 48 | px | 1.5 tiles |
| Sword knockback | 120 | px/s | Short shove so enemies don't stack on you |
| Dash speed | 520 | px/s |  |
| Dash duration | 0.15 | s | Invulnerable while dashing |
| Dash cooldown | 0.8 | s |  |
| Perfect block window | 0.3 | s | Hit lands within 0.3s of pressing block = reflect, take 0 |
| Late block damage taken | 0.4 | x | Holding block outside the window = take 40% |
| Move speed while blocking | 0.5 | x |  |
| Hurt invulnerability | 0.5 | s | After taking a hit |
| Hypno Reverse cone | 60 | deg | Unlocked after the Hypnotic mini boss |
| Hypno Reverse range | 140 | px |  |
| Hypno Reverse duration | 5 | s | Flipped enemies attack other enemies |
| Hypno Reverse cooldown | 12 | s |  |
| Health orb heal | 15 | hp |  |

## Enemies

| World | Enemy | health | damage | speed (px/s) | Attack range (px) | Attack cooldown (s) | Windup / telegraph (s) | Behaviour | Hits to kill (base dmg 10) |
|---|---|---|---|---|---|---|---|---|---|
| tutorial | Training Dummy | 30 | 5 | 0 | 40 | 2.0 | 0.6 | Stands still, swings slowly so the player practices blocking | 3 |
| world1 | Drone | 20 | 8 | 110 | 28 | 1.2 | 0.4 | Chases, melee bump | 2 |
| world1 | Alien Gunner | 25 | 10 | 90 | 260 | 2.0 | 0.5 | Keeps ~150px away, fires a 220px/s bolt (reflectable) | 3 |
| world2 | Raptor (prey) | 30 | 12 | 150 | 30 | 1.0 | 0.35 | Flees at 140 px/s while the hunt meter is filling; player catches it with dash | 3 |
| world2 | Raptor (hunter) | 30 | 10 | 200 | 30 | 0.9 | 0.3 | Pack flips for 10s: fast, chases the player | 3 |
| world3 | Mirror Construct | 35 | 12 | = player speed | 36 | 1.0 | 0.3 | Copies player movement mirrored across the center line; attacks when close | 4 |

## Waves

| World | Wave | Start time (s) | Enemies | Spawn interval (s) | Next wave trigger | Expected clear time (s) |
|---|---|---|---|---|---|---|
| world1 | 1 | 0 | 4 Drone | 0.6 | All dead + 3s | 15 |
| world1 | 2 | 18 | 5 Drone + 2 Gunner | 0.6 | All dead + 3s | 25 |
| world1 | 3 | 46 | 4 Drone + 3 Gunner | 0.5 | All dead + 3s | 25 |
| world1 | Mini boss | 74 | Hypnotic | - | Dead -> unlock Hypno Reverse, prompt | 30 |
| world1 | Boss | 110 | Warden | - | Dead -> portal opens | 60 |
| world2 | Hunt | 0 | 5 Raptor (prey) | all at once | Hunt meter hits 100 | 30 |
| world2 | Flip | 30 | same 5 Raptors become hunters | - | Survive 10s -> reward | 10 |
| world2 | Boss | 45 | Alpha Rex | - | Dead -> portal opens | 60 |
| world3 | Mirror 1 | 0 | 3 Mirror Construct | all at once | All dead | 20 |
| world3 | Mirror 2 | 22 | 4 Mirror Construct | all at once | All dead | 20 |
| world3 | Boss | 45 | Core Sentinel | - | Dead -> choice: keep fighting / final fragment | 45 |
| Hunt meter | Hit fleeing animal | +10 |  |  |  |  |
| Hunt meter | Kill fleeing animal | +25 |  |  |  |  |
| Hunt meter | Decay | 0 | No decay. Keep it simple. |  |  |  |
| Hunt meter | Survive the flip | Reward | Heal 30 + 1 guaranteed rare artifact |  |  |  |

## Bosses

| World | Boss | health | damage (contact) | speed (px/s) | Attack | Telegraph (s) | Attack damage | Cooldown (s) | Phase 2 (at 50% hp) | Target fight length (s) |
|---|---|---|---|---|---|---|---|---|---|---|
| world1 | Hypnotic (mini) | 150 | 10 | 90 | Hypno pulse: reverses player controls 3s | 1.0 | 0 | 10 | - | 30 |
| world1 | Hypnotic (mini) |  |  |  | Orb volley: 3 slow bolts | 0.5 | 10 | 3 |  |  |
| world1 | Warden | 400 | 12 | 100 | Laser sweep (red line) | 1.0 | 18 | 5 | Summons 3 Drones once; attacks 20% faster | 60 |
| world1 | Warden |  |  |  | Charge across arena | 0.8 | 15 | 6 |  |  |
| world2 | Alpha Rex | 500 | 14 | 130 | Charge (red line) | 0.8 | 20 | 5 | Roar summons 2 Raptors; charge twice in a row | 60 |
| world2 | Alpha Rex |  |  |  | Tail sweep (red circle r=80) | 0.6 | 15 | 4 |  |  |
| world3 | Core Sentinel | 550 | 15 | 80 | Bullet ring: 12 bolts (reflectable) | 0.7 | 12 | 4 | Ring fires 2x; spawns 1 mirror clone of itself (50 hp) | 45 |
| world3 | Core Sentinel |  |  |  | Ground circle (r=70) under player | 1.0 | 22 | 5 |  |  |
| final | Evil You | 9999 | copies player damage | copies player speed | Copies sword + shield + artifacts | - | player damage | - | Each hit on it: +15% damage, +5% speed. Blocks 50% of the time and reflects | ~60 |
| final | Evil You |  |  |  | Self-kill prompt appears | - | - | - | After 20s OR after 5 hits on it OR player below 30% hp |  |

## Artifacts

| Priority (cut after 6) | id | Name | Rarity | Effect | mods | flag | Available from |
|---|---|---|---|---|---|---|---|
| 1 | edge_shard | Edge Shard | common | +3 damage | damage:+3 |  | anywhere |
| 2 | heart_fragment | Heart Fragment | common | +25 max health (also heals 25) | max_health:+25 |  | anywhere |
| 3 | quick_sigil | Quick Sigil | common | +15% speed | speed:+33 |  | anywhere |
| 4 | mirror_polish | Mirror Polish | rare | Reflected damage +50% | reflect_power:+0.5 |  | anywhere |
| 5 | blood_echo | Blood Echo | rare | 25% of damage taken heals you back after 2s |  | heal_on_hurt | anywhere |
| 6 | double_reflection | Double Reflection | epic | Reflected damage hits twice |  | double_reflect | boss drop only |
| 7 | hypno_lens | Hypno Lens | rare | Hypno Reverse lasts +3s |  | long_hypno | after world1 |
| 8 | lucky_coin | Lucky Coin | common | +10 luck | luck:+10 |  | anywhere |
| 9 | echo_blade | Echo Blade | rare | Every 4th swing deals double damage |  | echo_blade | anywhere |
| 10 | glass_heart | Glass Heart | epic | +8 damage, -20 max health | damage:+8, max_health:-20 |  | anywhere |

## Loot

| Source | Artifact chance | Common | Rare | Epic | Health orb chance | Notes |
|---|---|---|---|---|---|---|
| Normal enemy | 3% + luck% | 70% | 25% | 5% | 15% | ~40 enemies total, so ~1 random artifact per run |
| World chest (1 per world) | 100% | 50% | 40% | 10% | - | Place near the arena edge |
| Hypnotic mini boss | 100% | 0% | 100% (hypno_lens) | 0% | 100% | Fixed drop: Hypno Lens |
| Hunt reward (world2) | 100% | 0% | 100% | 0% | - |  |
| Timeline boss | 100% | 0% | 60% | 40% | 100% | Double Reflection only drops here |
| Rule | Luck shifts rarity | -luck | +luck/2 | +luck/2 |  | e.g. luck 10 on a normal enemy -> 60/30/10 |
| Rule | No duplicates |  |  |  |  | Re-roll if already owned; if all owned, drop a health orb |
| Expected total | ~7 artifacts by the final |  |  |  |  | 3 chests + mini boss + hunt + 3 bosses = 8 guaranteed. Fine with 6 if cut. |

## Pacing

| Segment | Target time | Cumulative | What happens | Player power on entry (approx dmg / max hp) |
|---|---|---|---|---|
| amnesia_room | 0:30 | 0:30 | Wake, NPC lore drop, 'put this on' | 10 / 100 |
| tutorial | 2:30 | 3:00 | Get sword: attack dummy. Get shield: block, then reflect. Enter fragment. | 10 / 100 |
| world1 | 3:00 | 6:00 | 3 waves, Hypnotic, Warden | 10 / 100 |
| world2 | 2:00 | 8:00 | Hunt, flip, Alpha Rex | ~13 / 125 |
| world3 | 1:30 | 9:30 | Mirror constructs, Core Sentinel, twist line | ~16 / 125 |
| final | 1:00 | 10:30 | Evil You, self-kill | ~19 / 150 |
| ending | 0:20 | 10:50 | Quiet text, credits | - |
| Check | Boss TTK |  | Boss hp / (player dmg x ~1.5 hits/s). Warden 400/(10x1.5)=27s of hitting, ~60s with dodging |  |
| Check | If playtest runs long |  | Cut enemy hp by 20% first, then remove the last wave |  |
| Check | If playtest runs short |  | Add 1 enemy per wave; bosses +15% hp |  |
