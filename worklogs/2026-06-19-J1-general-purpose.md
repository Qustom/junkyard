# Worklog — J1 Default play-preset + size-slider re-range

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.3 (Wave 1)
- **Branch:** worktree-agent-afa450d4d2b2f8f5b (isolated worktree off `main`, post-BUG6/J5)
- **Commit:** 0e00564d2749f59022ba7be1d8c0375b5f15903c

## What changed
J1 introduces the **named default play-preset** the game/CFG boots into (the Director's
most-fun M1.2 stack), **re-ranges** the `lvl_size_mult` slider to `[4.0, 40.0]`, and folds
**BUG6's config-trap guard** into the CFG rail as a non-blocking warn line. The code-level
all-off `RunConfig.new()` / `run_config.tres` is **untouched** — it stays the permanent
baseline control (determinism fp `e943ac9c8bc1`), so the preset is a separate artifact built
on top of a fresh all-off instance and Reset still returns the control.

## Files touched
- `data/run_config/run_config.gd` — added `static func make_default_play_preset() -> RunConfig`
  (additive, after BUG6's appended `inert_enabled_oppositions()`). Builds on a fresh
  `RunConfig.new()`, never mutates the all-off default; asserts the preset is trap-free.
- `ui/config/config_menu.gd` — `RANGE_MULT` → `Vector2(4.0, 40.0)`; `_ready()` now seeds the
  working config from `_make_boot_config()` (= the preset) instead of `_load_default()`;
  `_load_default()` + Reset left wired to the all-off control (single Reset = all-off, Phase-3 E);
  added a WARN-ONLY trap label (`_trap_label`) + `_refresh_trap_warning()` surfacing
  `RunConfig.inert_enabled_oppositions()` (never blocks Start; hidden when clean).
- `ui/config/config_strings.csv` — added `CFG_TRAP_WARN` + the five `CFG_TRAP_<id>` strings.
- `scenes/game/main_game.gd` — the `:178` no-CFG fallback flips from the all-off `.tres` to
  `RunConfig.make_default_play_preset()` so a CFG-less launch boots the same stack (minimal edit).
- `tests/test_run_config.gd` — new Case 7: the preset is the F1 stack (LVL/R1/R4 on, R2/R3 off,
  19 rooms, size 4.0), trap-free, and does NOT leak into `RunConfig.new()`.

## The exact preset values + provenance
Provenance: R1/R4 magnitudes lifted from the **most-fun M1.2 cell** — the dominant
`m1-20260619-ba745e1` `run_started.data.run_config` snapshot (7 runs) in
`playtest_data/M1.2/run_log_2026-06-19.jsonl` with `lvl_room_count=19, lvl_size_mult=4.0,
r1_enabled, r1_catch_radius=23.3, r1_spawn_count=3, r4_enabled`.

| knob | preset value | source |
|---|---|---|
| `lvl_enabled` | `true` | F1 |
| `lvl_room_count` | `19` | disposition B (sweepable) |
| `lvl_size_mult` | `4.0` | new slider floor / most-fun cell |
| `r1_enabled` | `true` | F1 |
| `r1_depth_threshold` | `1` | log verbatim |
| `r1_linger_seconds` | `8.1` | log verbatim |
| `r1_chase_speed` | `56.0` | log verbatim |
| `r1_speed_per_depth` | `18.9` | log verbatim |
| `r1_catch_radius` | `24.0` | log was `23.3`; **floored to clear the 24px collision floor** (see deviations) |
| `r1_catch_radius_per_depth` | `10.5` | log verbatim |
| `r1_catch_kills` | `true` | log verbatim |
| `r1_spawn_count` | `3` | log verbatim |
| `r4_enabled` | `true` | F1 |
| `r4_branch_chance_base` | `0.43` | log verbatim |
| `r4_branch_per_depth` | `43.8` | log verbatim |
| `r4_max_branch_depth` | `5` | log verbatim |
| `r4_vision_radius` | `64.0` | log was `0.0` (trapped); **set non-inert** (Director-played value from the vision-on ba745e1 variant) |
| `r4_vision_tighten_per_depth` | `0.0` | log verbatim |
| `r4_fog_enabled` | `true` | log was `false`; **F1 "vision/maze ON"** (matches the vision-on variant) |
| `r4_lost_proxy_threshold` | `0.5` | log was `0.0` (trapped); **disposition D** override |
| `r2_enabled` / `r3_enabled` | `false` | F1: "R2 and R3 OFF by default" |

## The mult-40 smoke result (OQ-C / disposition C)
Ran a throwaway headless smoke (`tools/j1_mult40_smoke.gd`, deleted after) that staged the
preset at `lvl_size_mult = 40.0` through the real `MainGame.start_new_run()`:
- `effective_cell_size_px(16) == 640` (exact integer — no fractional seam by construction).
- BandContainer materialised **67 children** (19 big rooms + pickups + gate) with no error.
- Player `Camera2D` present and `current == true`; run `run_active == true` after start.
- **Verdict: playable at mult 40 headlessly — band materialises, camera reads, run starts.**
  No lower cap recommended; ship `RANGE_MULT = Vector2(4.0, 40.0)` as the Director asked.
  *Caveat:* a live human window pass at mult 40 still belongs on the M1.3 playtest checklist —
  at 640 px/cell the player sees ~1–2 cells of one room, which is the intended R4 fog/disorientation
  but should be eyeballed for "lost in a void" feel; the headless viewport (64×64) can't judge that.

## CFG coverage count
**36 knobs**, unchanged. J1 added **no new `@export` field** (the preset needs none beyond the
existing schema). `has_full_coverage()` + `to_flat_dict()` are value-blind, so coverage and the
36-knob count are unaffected. J2/J3's spawn knobs were **NOT** pre-declared here (Wave 2 owns them).

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK**
- [x] `test_run_config.tscn` → **R0 OK** (36 knobs; new Case 7 preset assertions pass)
- [x] `test_config_menu.tscn` → **CONFIG MENU OK** (36/36 bound, Reset returns all-off)
- [x] `test_level_scale_determinism.tscn` → **LVL OK** (all-off byte-matches baseline)
- [x] `test_rg1_m12_verify.tscn` → **RG1 M1.2 VERIFY OK** (all-off fp byte-identical to `e943ac9c8bc1`)
- [x] regression: `test_main_game_loop.tscn` OK + `test_rg1_loop_verify.tscn` OK (boot-seed / fallback
      change causes no regression — both loop tests grab `%ConfigMenu` and overwrite every field
      before each run, so the fallback is never hit and the boot-seed never leaks)
- [x] CFG warn-line end-to-end: hidden at boot (preset trap-free); shows the amber
      "⚠ enabled but inert (won't fire): R3 (no threshold levels)" when a trap is introduced; never blocks Start

## Definition of done
Game boots into the preset (19 rooms, size 4.0, R1+R4 on, R2/R3 off, trap-free); size 4–40
settable on the slider; Reset returns the all-off baseline; all-off fp byte-identical
(`e943ac9c8bc1`); CFG warn-line shows inert oppositions without blocking Start; coverage +
determinism + smoke green. **Met.**

## Design deviations
Three values DIVERGE from the literal most-fun-cell snapshot (all flagged in the factory
docstring, all to honour locked intent, all sweepable in the first M1.3 re-gate):
1. **`r4_vision_radius` 0.0 → 64.0** and **`r4_fog_enabled` false → true.** The dominant
   most-fun cell ran R4 vision *config-trapped* (radius 0). F1 explicitly says the preset has
   "R4 **vision/maze** ON," and the disposition wants the preset to *actually exercise* R4
   (BUG6 pairing) — so vision must be non-inert. 64.0 + fog-on is a value the Director actually
   played (the vision-on ba745e1 variant). Without this the preset would trip BUG6's `r4_no_vision`
   trap, contradicting "trap-free." **Recommend Director confirm vision-on in the boot preset is
   wanted** (it follows F1's wording; flagged because the *dominant* fun cell had vision off).
2. **`r1_catch_radius` 23.3 → 24.0.** The most-fun cell sat 0.7px under the documented
   physical-collision floor (player_r 14 + hazard_r 10 = 24px), which BUG6 flags as
   `r1_catch_radius_too_small`. Floored to 24.0 (minimal change preserving the feel) so the
   catch test can trip and the preset is trap-free. No Director call needed (it's the documented floor).

These pair with the disposition-mandated `r4_lost_proxy_threshold 0.0 → 0.5`. Appended to
`design/DESIGN_DEVIATIONS.md` for the wave close-out.

## Handoffs / follow-ups
- **Wave-2 collision note:** J2/J4 also edit `main_game.gd`; J1 landed first (the `:178` fallback
  line only). They add their own `r1_*`/spawn knobs + wire them into the preset.
- **Director review (surfaced, not decided):** preset vision-on (deviation 1) follows F1's wording
  but differs from the dominant fun cell — confirm at the first M1.3 sweep. Live human mult-40
  window pass still on the playtest checklist (headless can't judge the "void" feel).
