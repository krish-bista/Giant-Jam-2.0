# Gameplay regression checks

Run from the repository root using Godot 4.7.2 (replace `godot` with your executable):

```text
godot --headless --path . --script res://scripts/player/tests/sword_checks.gd
godot --headless --path . --script res://scripts/player/tests/shield_checks.gd
```

The original 37 sword/movement/dash checks are preserved. Shield checks cover timed input, the 160-degree frontal arc, mitigation, reflection multipliers and recursion, malformed sources, sword interaction, death, and a stationary attacking dummy. Both runners exit nonzero on failed checks.

For manual play, open `scenes/player/player_test_arena.tscn` and press F6. Approach the dummy on the left; within 130 px it delivers 20 damage every two seconds with a visible countdown. Face it and raise RMB during the last 0.3 seconds to reflect, hold longer to take 6 damage, or face away to take 20. Release/repress to rearm; F6 restarts after defeat. The HUD shows player HP and shield state.

## Shield contract

- `take_damage(amount, source)` remains the sole damage entry point with its existing two parameters and types. Health is now a float so reduced integer hits retain fractional HP; `health_changed` carries float current health. Default `reflect_power` is 1.0.
- Source position is its Node2D global position. Null, freed, non-Node2D, non-finite and coincident positions have no usable direction: **shield mitigation is bypassed and full damage applies**. Direction is never assumed to be frontal.
- A positioned source without `take_damage` can still be blocked/absorbed; no return-damage call is attempted.
- Perfect frontal hits absorb all damage and call `source.take_damage(amount * reflect_power, player)`. Hits from a source marked `reflecting` are absorbed without another reflection. A local reentrancy guard absorbs immediate callbacks during outgoing reflection, even from attackers ignoring the shared marker. Existing marker state is restored afterward.
- Shield input sets the sword's existing `attacks_enabled` flag. Raising it discards queued new clicks but leaves an existing slash animation and cooldown intact.
- The perfect window uses a physics SceneTreeTimer that obeys game pause/time scale and is created only on the transition from released to held. Releasing drops the reference; holding cannot restart it.
- Shield, slash and test-dummy graphics use built-in nodes/drawing only. The attacking dummy is a stationary test fixture, not general enemy AI.
