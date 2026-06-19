# Worklog — I2 Hazard fix (refuge: size, navigation, catch)

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer) + character-animator (greybox Tell shrink, folded in inline)
- **Milestone:** M1.2 (Wave 2)
- **Branch:** worktree-agent-a3f30fe900b8fd605 (isolated worktree off `main`)
- **Commit:** 2b68512f476d42fc3378b2c500026e79d8905622

## What changed
Made the M1.1 pursuing hazard (R1) actually catch — M1.1 logged `hazard_awoke=7` but
`hazard_caught=0` (two independent root causes: 32px body == 32px corridor floor → wall-grind
forever; and `r1_catch_radius` < combined body radii → distance test could never trip). Per the
LOCKED I2 spec + Director disposition (REFUGE — keep wall collision, do NOT ghost through walls):

1. **Shrank the hazard body** `CircleShape2D` radius 16 → **10** (20px dia, ~6px clearance each
   side of the 32px baseline corridor) and shrank the greybox `Tell` diamond ±18 → ±12 to match
   the new hitbox (character-animator contribution; colors + wake-flash Tween + groups/layer/mask
   unchanged). Body now fits the narrowest default hall I1 can produce.
2. **Anti-wall-stick steering** (§2.2 option (a), REFUGE): the hazard keeps `collision_mask = world`
   so walls remain a partial hiding place. Added a cheap de-pin — when it barely moves
   (`get_real_velocity().length() < speed * STALL_FRACTION`) while touching a wall
   (`get_slide_collision_count() > 0`), it arms a **next-frame** wall-tangent direction oriented
   toward the player (walk to the opening, not into the wall). Used the Phase-3-corrected
   next-frame approach (`_depin_dir`), NOT a second in-frame `move_and_slide` (no double-step,
   cleaner determinism). `STALL_FRACTION = 0.35` is a named greybox-internal feel const (not a
   RunConfig knob), Director-editable. No pathfinding/navmesh.
3. **Catch radius that can trip + depth-scaled knob** (§2.3, Q3 ACCEPTED): catch test now uses
   `effective = r1_catch_radius + r1_catch_radius_per_depth * depth`. Added the new
   `r1_catch_radius_per_depth: float = 0.0` `@export` to RunConfig (default 0.0 = flat = M1.0/M1.1
   baseline). Suggested first-sweep `r1_catch_radius ~32` (> player_r 14 + hazard_r 10 = 24 floor)
   is documented in the schema; the all-off default stays 0.0 so the control is byte-identical.
4. **Awaken threshold:** no spawn-code change needed — `_hazard_spawn_position` already
   `clampi`s an over-range threshold to the deepest piece (`main_game.gd:302`, confirmed). The
   threshold/linger/speed re-tunes are RunConfig *defaults* the Director sweeps, not hardcodes.

Schema knob count went 35 → **36**; wired the new knob through `config_menu.gd`
(MANIFEST r1_ list + FIELD_RANGE), `config_strings.csv` (field label), `to_flat_dict()`, and both
focused tests (count + expected-keys).

## Files touched
- `scenes/hazards/hazard_entity.tscn` — body radius 16→10; Tell polygon ±18→±12 (greybox tell).
- `scenes/hazards/hazard_entity.gd` — `STALL_FRACTION` const; `_depin_dir` field (reset in
  `setup`); AWAKE block de-pin steering + depth-scaled `catch_r`.
- `data/run_config/run_config.gd` — new `r1_catch_radius_per_depth` `@export` (default 0.0) +
  documented `r1_catch_radius` floor; added the knob to `to_flat_dict()`.
- `ui/config/config_menu.gd` — MANIFEST `r1_` list + FIELD_RANGE entry for the new knob (keeps
  `has_full_coverage()` passing at 36).
- `ui/config/config_strings.csv` — `CFG_FIELD_R1_CATCH_RADIUS_PER_DEPTH` label.
- `tests/test_run_config.gd` — added the knob to expected_keys (now asserts all 36).
- `tests/test_config_menu.gd` — knob count 35 → 36 (assertion + comments).

## Checks run
- [x] `godot --headless --import` clean (no parse errors).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK**.
- [x] `test_run_config.tscn` → **R0 OK** (to_flat_dict flat+JSON-safe with all **36** knobs).
- [x] `test_config_menu.tscn` → **CONFIG MENU OK** (36/36 knobs bound + reachable; reset = all-off).
- [x] `test_bandgen_determinism.tscn` → **BANDGEN OK** + BUG3/R4/BUG4 seals OK (fp unchanged).
- [x] `test_level_scale_determinism.tscn` → **LVL OK** (fp unchanged — hazard didn't perturb proc-gen).
- [x] Catch reachability: temp headless test drove an awake hazard at a stationary player —
      `hazard_caught` fired and routed to `run_ended(reason=death)` (M1.1 logged zero). Temp files
      removed after the run; no stray files committed.
- [x] **Definition of done:** "With R1 on, the hazard visibly closes in + catches → `death`; R1 off
      = M1.0 (no hazard); new knobs take effect; `hazard_caught` rows appear; determinism/seal
      intact; CFG coverage passes at 36; all-off = M1.0 baseline." — verified above.

## Design deviations
none. All changes are on the LOCKED I2 spec + Director disposition (REFUGE; depth-scaled knob
accepted; no re-sleep). `event_bus.gd` / `game_state.gd` / `main_game.gd` untouched; `run_ended`
arity unchanged; no new telemetry row.

## Handoffs / follow-ups
- **No `main_game.gd` change needed** (Q6 confirmed): the M1.1 spawn seam already gates on
  `r1_enabled`/`r1_spawn_count` and `clampi`s the over-range threshold. I2 contributes zero hunks
  to `main_game.gd`, so the I2/I4 single-writer split has no conflict from I2's side.
- The default `run_config.tres` carries no values, so the new field inherits the script default
  (0.0). If the Director wants the suggested first-sweep set (catch_radius 32, threshold ~⅓ max,
  etc.) baked into a labelled sweep `.tres`, that is a content-data task (game-director-designer),
  not a code change — the knobs are all live and swept from CFG today.
