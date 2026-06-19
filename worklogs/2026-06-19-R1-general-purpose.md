# Worklog — R1 Pursuing / Awakening Hazard

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer) + inline character-animator greybox tell
- **Milestone:** M1.1 (Greybox Cost Axis), Wave 2 batch B
- **Branch:** general-purpose/R1
- **Commit:** 6d50a4d1d374245450536e36fd3bfac988106b87

## What changed
Built R1, the throwaway greybox "pursuing / awakening hazard": a `HazardEntity`
(`CharacterBody2D`) that sleeps until the player crosses `r1_depth_threshold` OR lingers
`r1_linger_seconds`, then latches awake (no re-sleep), chases the player by direct
toward-player steering via `move_and_slide()` (walls stop it; no pathfinding), and on a
distance-based catch within `r1_catch_radius` either calls the existing
`GameState.fail_run(&"death")` (fatal, `r1_catch_kills`) or applies a self-contained
non-fatal cost (knockback + brief stun + cooldown). It reads `GameState.active_run_config`
(snapshotted at `setup`) + `GameState.current_depth_index` (live), and EMITS the
pre-declared `EventBus.hazard_awoke` / `hazard_caught`. The greybox tell (inline
character-animator contribution) is a `Polygon2D` diamond that flips cool grey-blue →
alarm red on awaken with a one-shot wake-flash Tween. A spawn seam in
`MainGame.start_new_run()` instantiates `r1_spawn_count` hazards into `_band_container`
at/near the `r1_depth_threshold` piece (clamped to deepest), fully gated by
`r1_enabled && r1_spawn_count > 0` so all-off == M1.0 exactly.

## Files touched
- `scenes/hazards/hazard_entity.gd` — NEW. The `HazardEntity` state machine + chase +
  catch + non-fatal cost + greybox tell.
- `scenes/hazards/hazard_entity.tscn` — NEW. Greybox scene: `CharacterBody2D` on
  collision layer `hazard` (5), mask `world` (2) only; child `Polygon2D` tell +
  `CollisionShape2D`.
- `scenes/game/main_game.gd` — EDIT (one additive, clearly-marked `# R1 (M1.1)` block):
  `HAZARD_SCENE_PATH` const, a `_spawn_r1_hazards(rc, band)` call at the end of
  `start_new_run()`, and helpers `_spawn_r1_hazards` + `_hazard_spawn_position`. R4/BUG2/
  BUG3 code left intact.
- `tests/test_pursuing_hazard.gd` / `.tscn` — NEW. Headless scene test (frame-driven).

## Checks run
- [x] `godot --headless --import` clean (exit 0, no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK**
- [x] `godot --headless res://tests/test_pursuing_hazard.tscn` → **PURSUING HAZARD OK**
      (awaken-at-depth-threshold once with trigger=depth; awaken-on-linger with
      trigger=linger; chases toward player; fatal catch → hazard_caught + fail_run death;
      awake latches with no re-sleep on retreat; non-fatal catch does NOT end the run;
      all-off gate spawns nothing)
- [x] `godot --headless res://tests/test_main_game_loop.tscn` → **MAIN GAME OK**
      (spawn-seam edit didn't break the loop)
- [x] `godot --headless res://tests/test_bandgen_determinism.tscn` → **BANDGEN OK +
      R4 NAV OK + BUG3 SOCKET SEAL OK** (R4 not perturbed)
- [x] `bash tools/run_gdunit.sh` → green (30/30, exit 0)
- [x] Definition of done (§8): R1 on → hazard awakens per threshold, visibly chases,
      can end a run as `death`; R1 off → no node, no telemetry, M1.0 behaviour; every
      `r1_*` knob reachable from config; the two signals fire as config-marked rows.

## Design deviations
**none.** Built to the ratified §9 decisions (Q1 spawn at threshold piece clamped to
deepest; Q2 non-fatal = knockback+stun+cooldown self-contained; Q3 independent hazards,
mask world only, distance-test catch; Q4 latch awake no re-sleep; Q5 live
`current_depth_index` + self-timed `run_t_ms`).

### As-built name corrections vs. the spec (noted, not deviations)
- Live within-band depth is `GameState.current_depth_index` (spec pseudocode's
  `current_depth` predates the BUG2 merge). Used the real name throughout.
- `hazard_awoke(depth, trigger)` / `hazard_caught(depth, run_t_ms)` are pre-declared on
  `event_bus.gd` — emit-only, `event_bus.gd` untouched. `run_t_ms` is self-timed from
  spawn (BUG1's run clock isn't exposed read-only off GameState/Telemetry), per §9 Q5
  fallback.
- The player is **already** in the `"player"` group (`player.tscn` ships
  `groups=["player"]`), so the spec's "add the player to a group" step was unnecessary —
  `player.tscn`/`player.gd` untouched. The hazard receives the player via `setup()` from
  the spawn seam, which resolves it with `get_first_node_in_group(&"player")`.
- The non-fatal knockback sets the player's `velocity` (a standard `CharacterBody2D`
  engine field) — a read/write of an engine member, not an edit to `player.gd`.

### Contract confirmation
Did NOT edit `systems/event_bus.gd`, `systems/game_state.gd`, `entities/player/player.gd`,
or `player.tscn`. Only the `main_game.gd` spawn seam + new `scenes/hazards/*` + new test
files. The `main_game.gd` edit is a single separate `# R1 (M1.1)` block (+ two new
helpers) that left the R4 vision/fog + lost-proxy, BUG2 depth driver, and BUG3 socket-seal
code intact (verified by test_main_game_loop + test_bandgen_determinism still green).

## Handoffs / follow-ups
- The non-fatal-catch tuning (knockback speed / stun / cooldown) is hardcoded as
  self-contained consts in `hazard_entity.gd`; R0's schema has no non-fatal-cost knobs.
  Exposing them is an out-of-scope R0 follow-up (already flagged deferred in §9), not built
  here — `r1_catch_kills = true` is the first-gate value.
