# Worklog — J2 Enemy Spread Across Depths

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.3 (Wave 2)
- **Branch:** general-purpose/J2-enemy-spread (built on the worktree branch `worktree-agent-a500753fc602d9f1b`)
- **Commit:** 9e5360b032ab4deb8bcd1e201e9ee4d4188fa3f7   ← the single J2 commit

## What changed
Replaced the M1.2 single-gate hazard spawn (all N `HazardEntity` at one
`r1_depth_threshold`) with N hazards **distributed across `depth_index`** — the F2 fix.
Three deterministic, RNG-free distribution modes selected by a new enum knob
`r1_spawn_distribution` (0 `single_gate` = M1.2-identical / all-off-equivalent,
1 `even_spread` = the F2 spread, 2 `curve` = built but preset-OFF), plus a new int knob
`r1_spread_min_depth` (shallowest depth that may receive a spread hazard). The booted
default play-preset opts into the spread (`even_spread`, count 5, min-depth 1 — Director
starting sweep points); the code-level all-off control default is untouched
(`single_gate`/0, reachable via CFG Reset). Placement is pure run-state on the
already-graded band and never feeds `fingerprint()`.

## Files touched
- `data/run_config/run_config.gd` — added `r1_spawn_distribution` (`@export_enum`) +
  `r1_spread_min_depth` (`int`) in the R1 `@export_group("R1 Pursuing Hazard", "r1_")`
  block, both defaulting to the M1.2-equivalent (0/0); added both to `to_flat_dict()` (R1
  block); wired the spread into `make_default_play_preset()` (`r1_spawn_count` 3→5,
  `r1_spawn_distribution = 1`, `r1_spread_min_depth = 1`).
- `scenes/game/main_game.gd` — refactored `_spawn_r1_hazards` into a two-step seam:
  STEP 1 `_hazard_spawn_depths(band, rc)` (new; the depth list, one per hazard,
  RNG-free, pure function of band topology + config), STEP 2 places one hazard per
  depth. Added `_band_max_depth(band)` returning `band.max_depth` (Phase-3 Q3). Renamed
  `_hazard_spawn_position` middle arg `depth_threshold → depth` (stable internal API J3
  reuses) and pointed its clamp at `_band_max_depth` (removed the duplicate local scan).
- `ui/config/config_menu.gd` — added both fields to the `r1_` `MANIFEST` and
  `r1_spread_min_depth` to `FIELD_RANGE` (the enum is auto-rendered as an OptionButton).
- `ui/config/config_strings.csv` — added `CFG_FIELD_R1_SPAWN_DISTRIBUTION` /
  `CFG_FIELD_R1_SPREAD_MIN_DEPTH` row labels.
- `tests/test_run_config.gd` — added the two keys to `expected_keys`; new Case 8 asserts
  all-off = single_gate/0 and the preset's even_spread/5/1.
- `tests/test_config_menu.gd` — knob count 36 → 38 (+ doc comment).
- `tests/test_hazard_spread.gd` + `.tscn` + `.uid` — NEW focused J2 acceptance test
  (drives the real `MainGame._hazard_spawn_depths` against a hand-built graded band).

## Checks run
- [x] `godot --headless --import` clean (no parse errors). (First pass shows benign
  "missing .translation" warnings — those are gitignored build products regenerated on
  the same import; second pass is clean.)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK** (exit 0).
- [x] Task-specific + related tests, all green:
  - `test_run_config` → **R0 OK** (all 38 knobs; preset + all-off J2 asserts pass).
  - `test_config_menu` → **CONFIG MENU OK** (38/38 knobs bound + reachable; Reset = all-off).
  - `test_hazard_spread` → **J2 OK** (single_gate == M1.2 single-threshold placement;
    even_spread scatters across [min..max] inclusive, monotonic, multi-depth;
    curve = locked `pow(t,1.6)` shape; RNG-free determinism; `spread_min_depth`
    respected/clamped; N == `r1_spawn_count` for every mode).
  - `test_pursuing_hazard` → **PURSUING HAZARD OK** (renamed helper still places + the
    hazard still awakens/chases/catches; all-off spawns nothing).
  - `test_level_scale_determinism` → **LVL OK** (layout-invariance precedent intact).
  - `test_telemetry_config_marking` → **TEL CONFIG MARKING OK** (new keys flow into the
    run_started snapshot via the dynamic `to_flat_dict()` comparison).
  - `test_rg1_m12_verify` → **RG1 M1.2 VERIFY OK** — explicitly confirms the **all-off
    control is byte-identical to the locked baseline fp=e943ac9c8bc1**.
  - `test_rg1_loop_verify` → **RG1 BUILD VERIFY OK**.
- [x] Definition of done met: "Replace the single-gate hazard spawn with N hazards
  distributed across `depth_index`"; three modes via `r1_spawn_distribution`; new
  `r1_spread_min_depth`; deterministic/no-RNG, no `fingerprint()` / `RNG.*` touch; no
  EventBus/GameState edit; `band.max_depth` used; helper signature
  `_hazard_spawn_position(band, depth, index)`; all-off & single_gate byte-identical.

## Design deviations
1. **`curve` mode (2) is mathematically SHALLOW-biased, not "deeper-biased" as the spec
   labels it — built to the LOCKED pseudocode regardless.** The locked J2 spec §B.2 / the
   Director Disposition call the curve mode "deeper-biased `pow(t,1.6)`" and the spec's
   pseudocode comment says `# >1 → clusters deep`. But `pow(t, 1.6)` for `t ∈ [0,1]` returns
   values `<= t`, so equally-indexed hazards map to SHALLOWER intermediate depths (the
   density actually clusters toward the *shallow* end mid-range, thinning before the deep
   end). I implemented the spec's literal formula (`pow(t, 1.6)`) exactly — it is the locked
   code and `curve` is preset-OFF, configurable-not-balanced — but flag that the **stated
   intent ("deeper = denser") and the formula disagree**. To actually bias deeper the
   exponent should be `< 1` (e.g. `pow(t, 0.6)`) or the curve applied as `1 - pow(1 - t, e)`.
   *Recommendation:* leave the formula as-specced for this gate (curve is not preset-selected,
   so it changes no booted experience), and let the Director decide the exponent/direction as
   an RG2 sweep when/if curve mode is flipped on. **Needs Director review** (fun/feel + a
   spec-text correction). The J2 test asserts the actual `pow(t,1.6) <= even` property so the
   build is locked to the real behaviour. → appended to `design/DESIGN_DEVIATIONS.md`.

(No other deviations: all-off/single_gate byte-identical, no RNG, no EventBus/GameState
edit, `band.max_depth` used, helper signature as specced.)

## Handoffs / follow-ups
- **J3 (per-room density)** reuses the stable `_hazard_spawn_position(band, depth, index)`
  helper and lands additively/sequentially on the same `main_game.gd` seam (Director
  Disposition build-structure note). J2 is on the branch, not merged — the orchestrator
  verifies topology + merges.
- The curve-exponent deviation above is the one Director-review item for the Wave-2
  close-out sweep.
- Per-task orchestration note: the early `git switch` happened in the shared checkout by
  mistake; it was reverted (shared checkout restored to `main`, stray branch deleted) and
  all J2 work lives only on the isolated worktree branch.
