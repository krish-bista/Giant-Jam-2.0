# From Azad: what's set up and what you need to know

## What I did
- **Interface contract**: [INTERFACES.md](INTERFACES.md). The shared rules everyone codes against: scene names, `go_to_scene`, the `Events` signals the UI listens for, `take_damage(amount, source)`, stat names, artifact format, groups, physics layers, input keys, art sizes, and folder ownership. **Please read this first.**
- **Balance sheet**: [balance/](balance/README.md). Numbers for the player, enemies, waves, bosses, artifacts, loot drops and pacing (target ~10 min run). Each `.tsv` pastes straight into Google Sheets.
- **Git workflow**: [GIT_WORKFLOW.md](GIT_WORKFLOW.md). Branch plan, daily commands, merge schedule, and the Godot traps that cause conflicts.
- **Project settings** (already in `main`):
  - Input actions: WASD move, `attack` left mouse, `block` right mouse, `dash` Space, `hypno` Q, `interact` E, `pause` Esc
  - Physics layers 1–8 named: world, player, enemy, player_attack, enemy_attack, pickup, portal, flipped_attack
- **Repo hygiene**: `.gitattributes` (same line endings on every machine) and an extended `.gitignore`.

## What I need from you
- **Everyone:** use **Godot 4.7.2 stable**. A different version re-saves files and creates conflicts.
- **Everyone:** only `git add` your own folders, never `git add .`. Run `git status` before committing and `git restore` any file Godot touched that isn't yours.
- **Everyone:** pull `main` before you start and after I announce a merge.
- **Krish:** when `GameManager` / `Events` exist, send me the paths and I'll register the autoloads in `project.godot`. Small mismatches with the doc in `player.gd`: default `damage` 20 (doc: 10), `reflect_power` 0.0 (doc: 1.0), and dash should use the `dash` input action instead of checking the Space key directly.
- **Nischal:** placeholders keep their final file names and sizes (32×32 base), so swapping art later needs no scene edits.
- **Need a setting, input or autoload changed?** Ask me. `project.godot` is mine, to avoid conflicts.

## Merge and playtest times
1:00 · 3:00 · **5:00 playtest 1** · 7:00 · **8:00 playtest 2** · **9:00 playtest 3 + feature freeze** · 9:30 export
