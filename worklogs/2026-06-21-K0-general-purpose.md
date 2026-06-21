# Worklog — K0 Foundation: knob + signal pre-declare (+ K1 retune)

- **Date:** 2026-06-21
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.4 (Wave 1, lands first; blocks K2/K3/K4/K5a/K5b/K5c/K5i/K7)
- **Branch:** worktree-agent-a141f2be73e7e7181 (isolated worktree feature branch; NOT main)
- **Commit:** 74034bc23927d2733495380d97bc22e3ef25c000 (K0 foundation; worklog SHA-fix follow-up records this)

## What changed
K0 is the single-writer foundation pass over the two shared files + the CFG menu for M1.4. It
**declares only** — no behaviour. Added the 35 new `RunConfig` knobs (7 groups: quota/camera/
timer/3 hazards/exits) at off/neutral defaults, extended `to_flat_dict()` with all 35, declared
the 7 new `EventBus` signals (Phase-4-locked names), removed the dead `light_low()` signal + its
AudioDirector connect, applied the K1 preset retune, wired the CFG menu's structural rows
(SECTIONS/MANIFEST/FIELD_RANGE/FIELD_STEP + `_prefix_of` + CSV stubs) so the coverage assertion
stays green, and bumped the knob-count tests 46 → 81.

## Tie-breaker note (Breakdown Phase-4 Lock OVERRIDES the K0 doc's RD section)
The K0 design doc's `Resolved Decisions (Phase 3)` (RD-1) **dropped** `quota_check_timing`/
`quota_basis` (quota → 3 knobs, total 35→ would give 79). The **Breakdown's Phase-4 Lock (§"Phase 3
Dispositions & Phase 4 Lock", bullet 136) is the authoritative tie-breaker and KEEPS both enums**
("the Director wants quota configurable"), so quota = **5 knobs** and the milestone total is **35 new
→ 46+35 = 81** (which is exactly the Breakdown's stated "46 → 81"). The task prompt confirmed this.
Likewise the bomb signal is the locked `bomb_pulse_started(depth, run_t_ms)` (not the doc's
`bomb_armed`/`bomb_detonated`), and the quota signals are `quota_evaluated`/`quota_advanced`/
`meta_wiped(prev_run_number)`.

## Files touched
- `data/run_config/run_config.gd` — declared 35 new @export knobs in 7 groups (quota_/cam_/timer_/
  hpp_/hbomb_/hspike_/exit_), all off/neutral; appended all 35 to `to_flat_dict()`; applied the K1
  retune in `make_default_play_preset()` ONLY (`r1_speed_per_depth 18.9→3.0`,
  `r1_catch_radius_per_depth 10.5→1.0`, `r1_catch_radius` left at 24.0). Code-level all-off defaults
  and the `.tres` untouched.
- `systems/event_bus.gd` — removed dead `signal light_low()`; declared 7 M1.4 signals
  (`quota_evaluated`, `quota_advanced`, `meta_wiped(prev_run_number:int)`,
  `camera_view_set(visible_world_width:float, zoom:float)`,
  `dive_clock_warning(seconds_remaining:float, maximum:float)`,
  `new_hazard_killed(kind:StringName, depth:int, run_t_ms:int)`,
  `bomb_pulse_started(depth:int, run_t_ms:int)`, `exits_placed(count:int, depth:int)`).
- `systems/audio_director.gd` — dropped `EventBus.light_low.connect(_on_tension)` (coupled edit so
  the removed signal doesn't break load; the K4 doc assigned this to K4, but per the task prompt it
  rides K0's pass since the signal is removed here).
- `ui/config/config_menu.gd` — 6 new RANGE consts; 7 SECTIONS entries; 7 MANIFEST lists; FIELD_RANGE
  entries for every new numeric scalar; FIELD_STEP for quota_base/quota_step (10); 7 new prefixes in
  `_prefix_of()`. (No `_section_summary()` cases added — greybox-acceptable per RD-5; the per-knob UI
  tasks add those.)
- `ui/config/config_strings.csv` — stub CFG_SEC_*/CFG_GLOSS_* for the 7 sections + CFG_FIELD_* for
  the body-row knobs (masters/enums need none — derived/skipped).
- `tests/test_config_menu.gd` — `46 → 81` exact-count assertion + arithmetic comment.
- `tests/test_run_config.gd` — appended the 35 keys to `expected_keys` (now totals 81).

## Final knob count
**35 new knobs** = K2 quota 5 (`quota_enabled`/`quota_base`/`quota_step`/`quota_check_timing`/
`quota_basis`) + K3 cam 3 + K4 timer 4 + K5a hpp 5 + K5b hbomb 7 + K5c hspike 6 + K7 exit 5.
**Total exported RunConfig fields: 81** (46 prior + 35).

## New EventBus signals (7)
`quota_evaluated`, `quota_advanced`, `meta_wiped`, `camera_view_set`, `dive_clock_warning`,
`new_hazard_killed`, `bomb_pulse_started`, `exits_placed`. (Removed: dead `light_low()`.)

## Checks run
- [x] `godot --headless --import` → clean, no parse errors.
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy` (AudioDirector loads clean after the light_low removal).
- [x] `tests/test_run_config.tscn` → `R0 OK` (all-off control intact, `to_flat_dict()` flat+JSON-safe with all 81 knobs, BUG6 traps intact, preset still F1 stack + trap-free, no leak into RunConfig.new()).
- [x] `tests/test_config_menu.tscn` → `CONFIG MENU OK — 81/81 knobs bound + reachable`, master+knob+enum edits flow, Reset returns all-off.
- [x] `tests/test_bandgen_determinism.tscn` → `BANDGEN OK ... fp=e943ac9c8bc1` — **all-off fingerprint UNCHANGED**.
- [x] `tests/test_level_scale_determinism.tscn` → `LVL OK` (ext fp d7c249c3584b unchanged).
- [x] Definition of done: "K0 declares all M1.4 knobs/signals + CFG rows + the K1 preset retune at off/neutral defaults; all-off fp stays e943ac9c8bc1; knob-count tests pass at the new total; no behaviour." Met.

## Design deviations
- **Final count is 81, not the K0-doc-RD's implied 79 (or its §B.5 draft's 83).** Resolved by the
  Breakdown's Phase-4 Lock keeping `quota_check_timing`+`quota_basis` (Director verdict). On-spec
  with the authoritative tie-breaker; the K0 design doc's RD-1/RD-6 arithmetic (which dropped the two
  enums) is superseded by the Breakdown + the task prompt. Worth noting in the wave close-out so the
  K0 design doc's RD section is reconciled to "81 / enums kept."
- Knob-default neutrals: code-level defaults are off/neutral (bool false, int 0, float 0.0, enums 0);
  the quota enums' Director-FINAL defaults (`every_run_end` / `cumulative_money`) are documented to
  belong in the preset (K2's job), not the code default, preserving the all-off control. On-spec.
- Otherwise none.

## Handoffs / follow-ups
- **K4** no longer needs to drop the `audio_director.gd` light_low connect — done here. K4 still owns
  re-pointing AudioDirector to `dive_clock_warning` if/when it wants the tension hook live.
- **K2** reads `quota_enabled`/`quota_base`/`quota_step`/`quota_check_timing`/`quota_basis` and emits
  `quota_evaluated`/`quota_advanced`/`meta_wiped`; it must NOT re-edit `run_config.gd`/`event_bus.gd`.
- **K5b** emits `bomb_pulse_started` (locked name) — its design doc's `bomb_armed`/`bomb_detonated`
  draft names are NOT what K0 declared; K5b reads the locked set.
- The 7 CFG sections currently show "ON" with no value summary (no `_section_summary` match case) —
  greybox-acceptable; the per-knob UI tasks (K2/K3/K4 ui-ux) add the summary cases when they style.
- Orchestrator: at the M1.4 Wave-1 close-out, reconcile the K0 design doc's RD-1/RD-6 (which dropped
  the two quota enums → 79) to the as-built reality (enums kept → 81), per the Breakdown Phase-4 Lock.
