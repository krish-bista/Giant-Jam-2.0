# Echo Breach

A 2D top-down game jam project built with Godot 4.x and GDScript. Echo Breach is built around a **reversal** theme; the gameplay and story will be developed during the jam.

## Team roles and folder ownership

- **Krish** — `autoload/`, `scripts/player/`, `scripts/enemies/`, `scripts/worlds/`, `scenes/player/`, `scenes/enemies/`, `scenes/components/`. The global scene manager is reserved as `GameManager`; transitions are not implemented yet.
- **Nischal** — `assets/`, `scenes/levels/`, `scenes/ui/`, `scripts/ui/`.
- **Azad** — `audio/`, `docs/`, integration and merges.

## Reserved scene names

`amnesia_room`, `tutorial`, `world1`, `world2`, `world3`, `final`, and `ending`.

## Git collaboration rules

- Work on your owned folders and coordinate changes that cross ownership boundaries.
- Pull the latest `main` before starting and before opening a merge request.
- Use focused branches and commits; do not force-push or rewrite shared history.
- Review and integrate changes through merges into `main`, coordinated by Azad.
- Keep Godot source resources and UID files tracked. Generated `.godot/` editor data stays untracked.