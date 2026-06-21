# Worklog — K7 Exit placement rework

- **Date:** 2026-06-21
- **Subagent:** general-purpose
- **Milestone:** M1.4 (Wave 2)
- **Branch:** general-purpose/K7-exit-placement
- **Commit:** 9f0c531a41de8c7e180d1ed1a6bebbc984bab8de

## What changed
Replaced the single hand-offset extract gate with **one-to-many** gates placed across the
band's floor cells, count-scaled by within-band depth, with an optional toggle to pin one
gate at the legacy spawn offset. All driven by K0's pre-declared `exit_*` `RunConfig` group
(K7 only READS it). The **all-off control** (`exit_enabled=false`, or no active config) is
byte-identical to M1.3: exactly one gate at `spawn_pos + GATE_SPAWN_OFFSET`. The enabled path
uses **Strategy A** (DR-1): a LOCAL `RandomNumberGenerator` seeded `run_seed ^ EXITS_RNG_SALT`
(never the global RNG autoload), Fisher–Yates over the stable J3 candidate pool, take first
`n`. Placement is pure run-state at materialisation, downstream of generation, so the
determinism fingerprint is structurally unmoved.

## Files touched
- `systems/game_state.gd` — add `const EXITS_RNG_SALT := 0x45584954` ("EXIT") alongside
  `POCKETS_RNG_SALT` (the local sub-stream salt for K7 random placement).
- `scenes/game/main_game.gd` — `var _gate` → `var _gates: Array[ExtractGate]`; `_clear_band()`
  resets `_gates`; call site passes `band`; `_place_gate(band, spawn_pos)` reworked (all-off
  early-return + depth-scaled enabled path emitting `exits_placed`); new helpers
  `_spawn_gate_at`, `_exit_count_for_depth` (DR-2: re-floor at 1 after the cap),
  `_exit_placement_positions` (Strategy A), `_exit_candidate_cells`, `_world_to_cell`.
- `tests/test_exit_placement.gd` + `.tscn` (+ generated `.uid`) — K7 acceptance test:
  all-off identity, Strategy-A reproducibility, depth scaling, keep-at-spawn, multi-gate
  extract safety.

## Checks run
- [x] `godot --headless --import` — no parse/compile errors in K7 files (pre-existing
  `*.translation` load warnings are unrelated to K7).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy` (exit 0).
- [x] `godot --headless res://tests/test_exit_placement.tscn` → `K7 OK …` (exit 0): all-off
  single gate at `GATE_SPAWN_OFFSET`, count = `clamp(maxi(base,1)+floor(per_depth*depth),1,max)`
  re-floored at 1, Strategy-A reproducible per seed (varies across seeds), keep-at-spawn pins
  one gate at the offset with none on the entry cell, and N same-id gates end the run exactly
  once (node-identity guard + `_run_ended`).
- [x] `godot --headless res://tests/test_bandgen_determinism.tscn` → fingerprint **UNMOVED**:
  `BANDGEN OK — determinism + connectivity verified across 9 seeds (sample seed 12345 -> 12 pieces, fp=e943ac9c8bc1)`.
- [x] `godot --headless res://tests/test_run_config.tscn` → `R0 OK … all 81 knobs …` (K7 adds 0).
- [x] `godot --headless res://tests/test_config_menu.tscn` → `CONFIG MENU OK — … 81/81 knobs bound + reachable …`.
- [x] **Definition of done met**: "all-off (`exit_enabled=false`) = today's single fixed gate
  at `GATE_SPAWN_OFFSET`, byte-identical; fp `e943ac9c8bc1` UNMOVED; only `main_game.gd` +
  `game_state.gd` change (plus tests); no save/schema change; no `ExtractGate`/`run_config.gd`/
  `event_bus.gd` edits."

## Design deviations
**none.** Implemented exactly per the K7 doc's pseudocode and the locked DR-1…DR-7:
- DR-1 Strategy A (local sub-stream random), DR-2 count formula with the **post-cap re-floor
  at 1**, DR-6 shared `&"gate"` id kept on every gate. Per DR-6: **the shared `&"gate"` id is
  NOT a bug** — cross-fire is prevented by the node-identity guard at `extract_gate.gd:45`
  (`target.get_parent() != self`); do not introduce per-gate ids.
- No edits to `run_config.gd`, `event_bus.gd`, or `extract_gate.gd` (K0 owns the knobs/signal;
  DR-6 keeps the gate scene untouched). The preset ships exits OFF (DR-4) — code defaults are
  already all-off, so no preset lines were added.

## Handoffs / follow-ups
- **Worktree branch hygiene:** the initial `git switch -c general-purpose/K7-exit-placement`
  leaked a stray branch into the SHARED checkout (the known worktree leak). It was deleted and
  the shared checkout restored to `main`; the K7 branch was then created INSIDE the worktree.
  Verified the shared checkout is back on `main` with no stray K7 branch.
- Director flags from the K7 design remain open but are **preset/methodology calls that do not
  change K7 code** (DR-3 preset `exit_keep_one_at_spawn`, DR-4 preset `exit_enabled`, DR-7
  scope line). They set values in `make_default_play_preset()` / the RG1 sweep plan, not code.
