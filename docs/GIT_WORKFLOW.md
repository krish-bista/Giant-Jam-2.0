# Echo Breach — Git Workflow (3 people, 10 hours)

## Branches
| Branch | Who | Rule |
|---|---|---|
| `main` | Azad only | Always runs. Only Azad merges here. |
| `krish` | Krish | Gameplay code and scenes |
| `nischal` | Nischal | Art, levels, UI |
| `azad` | Azad | Audio, docs, `project.godot`, export settings |

One personal branch each. No force-push and no rebasing of shared branches.

## First-time setup (everyone, once)
```bash
git clone https://github.com/krish-bista/Giant-Jam-2.0.git
cd Giant-Jam-2.0
git checkout -b <yourname>
git push -u origin <yourname>
```
Open the project in **Godot 4.7.2** only.

## Every time you start working
```bash
git checkout <yourname>
git pull origin main        # get everyone's merged work
```

## Every time you finish something (aim for every 30–60 min)
```bash
git status                  # check what changed
git add scripts/player/ scenes/player/     # ONLY your own folders, never "git add ."
git commit -m "Player dash + cooldown"
git push
```
Then post in chat: "pushed `<branch>`: <what changed>".

## The Godot traps (read this)
1. **Godot re-saves files you only opened.** Before committing, run `git status`. If you see a `.tscn` or `project.godot` you didn't mean to change, undo it with `git restore <file>`.
2. **Never edit someone else's `.tscn`.** If you need something changed in a scene you don't own, ask that person.
3. **`project.godot` is Azad's.** Need a new input action, autoload or setting? Message Azad. (Krish: send the autoload name and path, and Azad registers it.)
4. **Commit the `.import` and `.uid` files** next to your assets and scripts. Godot uses them to link files. Don't commit `.godot/`.
5. **Rename or move files inside Godot's FileSystem panel only**, never in Explorer. Otherwise references break.
6. **Placeholders keep their final names.** Swapping art = replacing the PNG with the same name. No scene edits needed.

## Merge schedule (Azad)
| Hour | Merge | Then |
|---|---|---|
| 1:00 | everyone: interfaces, placeholders, movement | Team pulls `main` |
| 3:00 | player combat + tutorial + amnesia room | Quick run |
| 5:00 | World 1 | **Playtest 1** |
| 7:00 | Worlds 2 + 3 | Run full flow |
| 8:00 | artifacts, final boss, ending | **Playtest 2** |
| 9:00 | polish | **Playtest 3**, feature freeze |
| 9:30 | bug fixes only | Export |

## How Azad merges
```bash
git checkout main
git pull origin main
git fetch origin
git merge --no-ff origin/krish   -m "Merge krish: <summary>"
git merge --no-ff origin/nischal -m "Merge nischal: <summary>"
git merge --no-ff origin/azad    -m "Merge azad: <summary>"
# open Godot, press F5, run the full flow quickly
git push origin main
```
Then tell the team: "main updated, pull now."

**If a merge conflicts:**
- `.tscn` / `.tres`: don't hand-merge. Keep the owner's version: `git checkout --theirs <file>` (when merging the owner's branch), then `git add <file>`.
- `project.godot`: keep `main`'s version (`git checkout --ours project.godot`), then re-add the requested setting in the editor.
- Stuck? `git merge --abort`, then talk to the person.

## Safety nets
- Before each playtest: `git tag playtest-1` (then `playtest-2`, ...) and `git push --tags`. If something breaks later, you can always go back.
- Optional: on GitHub, protect `main` (Settings → Branches) so only Azad can push to it.
