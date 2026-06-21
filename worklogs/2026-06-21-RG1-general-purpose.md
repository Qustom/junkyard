# Worklog — RG1 M1.4 playtest build + verify

- **Date:** 2026-06-21
- **Subagent:** general-purpose (the programmer)
- **Milestone:** M1.4 (Stakes, Variety & Legibility) — Wave 4 re-gate
- **Branch:** general-purpose/RG1-m14
- **Commit:** 183d19f  (`RG1: set M1.4 fun preset + headless verify + verify doc + playtest docs`)

## What changed
RG1 is the M1.4 re-gate integration-verification + fun-preset-tune task (NOT new gameplay — K0–K7
were built across Waves 1–3). Three things:
1. **Set `make_default_play_preset()` to the full M1.4 fun stack** — added K4 dive timer (ON, 60s,
   ~10s near-end warning, visual_only) and all three K5 new hazards (ping-pong / bomb / spikes) ON
   at RG1 sweep-start magnitudes with a mandatory per-room cap; left K7 exits OFF (Director call).
2. **Authored `tests/test_rg1_m14_verify.gd`(+`.tscn`)** — the M1.4 headless verify driver, mirroring
   the M1.3 driver, asserting the preset shape, the unmoved all-off fingerprint, config-marked
   telemetry, and the new-hazard spawn path. Prints `RG1 M1.4 VERIFY OK`, exit 0.
3. **Authored the verify doc + updated the playtest docs** (`RG1_playtest_build.md`, the loop-smoke
   checklist, the tester readme) with the M1.4 matrix + sweep guidance.

## Files touched
- `data/run_config/run_config.gd` — `make_default_play_preset()`: added the K4 timer block + the
  K5a/b/c hazard blocks (sweep-start magnitudes, per-room cap 2 each); K7 left OFF. Updated the
  function docstring. The code-level all-off defaults are UNTOUCHED (preset built on a fresh
  `RunConfig.new()`).
- `tests/test_rg1_m14_verify.gd` + `.tscn` (+ `.gd.uid`) — the new M1.4 verify driver (scene-based
  so autoloads resolve, per the M1_As_Built headless-testing constraint).
- `design/M1_4_Tasks/RG1_playtest_build.md` — the verify/design doc (goal, what's-already-wired,
  the §4 verify matrix, §5 sweep guidance, §7 OQ-3 perf carry-forward, §9 Resolved-Decisions pointer).
- `tools/playtest/loop_smoke_checklist.md` — added the M1.4 manual matrix section + the m13/m14
  headless-drive entries.
- `tools/playtest/tester_readme.md` — added the "New in M1.4" section + the run_config-snapshot /
  `build_tag` ground-truth reminder.

## Preset values set (exact)
- **K4:** `timer_enabled=true`, `timer_length_s=60.0`, `timer_warning_threshold_s=10.0`,
  `timer_warning_channel=0` (visual_only).
- **K5a ping-pong:** `hpp_enabled=true`, `hpp_base_count=0`, `hpp_count_per_depth=0.15`,
  `hpp_speed=70.0`, `hpp_per_room_cap=2`.
- **K5b bomb:** `hbomb_enabled=true`, `hbomb_base_count=0`, `hbomb_count_per_depth=0.15`,
  `hbomb_proximity_radius=64.0`, `hbomb_pulse_seconds=2.0`, `hbomb_blast_radius=48.0`,
  `hbomb_per_room_cap=2`.
- **K5c spikes:** `hspike_enabled=true`, `hspike_base_count=0`, `hspike_count_per_depth=0.15`,
  `hspike_rotation_speed=90.0`, `hspike_arm_length=48.0`, `hspike_per_room_cap=2`.
- **K7:** `exit_enabled=false` (untouched — Director: ship exits OFF for a clean re-gate).
- (K2 quota + K3 camera were already in the M1.3-base preset; left unchanged.)

## Checks run
- [x] `godot --headless --import` clean (no parse errors).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK` (exit 0).
- [x] `godot --headless res://tests/test_rg1_m14_verify.tscn` → `RG1 M1.4 VERIFY OK` (exit 0); 11
      headless rows verified, 7 human-deferred.
- [x] `godot --headless res://tests/test_run_config.tscn` → `R0 OK` (all-off byte-identical baseline,
      preset trap-free `inert_enabled_oppositions()` empty, 81 knobs in `to_flat_dict()`).
- [x] `godot --headless res://tests/test_config_menu.tscn` → `CONFIG MENU OK` (81/81 knobs bound;
      Reset returns the all-off baseline).
- [x] All-off band fingerprint still `e943ac9c8bc1` (verified by both the run_config test and the
      m14 verify driver, incl. after building the preset).
- [x] Definition of done met (RG1 acceptance, breakdown §"Phase 3"): the build boots into the M1.4
      fun preset, each system takes effect (headless where possible + human-deferred for the
      felt/rendered), the all-off control reproduces the M1.0–M1.3 baseline exactly, telemetry
      carries all 81 knobs, the verify driver prints `RG1 M1.4 VERIFY OK`.

## Design deviations
**One RG1-authored tuning call (within the Director's "magnitudes are RG1 sweeps" mandate):**
The three new hazard types share a single 48-body band ceiling (`NEW_HAZARD_BAND_CEILING`) in the
intentional starvation order pingpong → bomb → spike. On the default deep band (19 rooms, ~15
depths), an aggressive sweep-start (e.g. base 1 / per_depth 0.5 / cap 2) lets **pingpong alone
saturate the 48 ceiling and starve spikes to ZERO** — so the Director could never evaluate spikes
in the shipped default. I therefore set MODEST sweep-starts (base 0 / per_depth 0.15 / cap 2),
which yield a balanced ≈9 / 9 / 9 (total ≈27, well under 48). This is a magnitude choice the
Director explicitly delegated to RG1 ("magnitudes are RG1 sweeps"); the design intent (every type
spawns in the default so all three are evaluable) is honoured. Documented in
`RG1_playtest_build.md` §3 and flagged here for the wave close-out deviation sweep. Not a contract
change — the all-off control, knob count, and fingerprint are all unchanged. **Recommend: Reviewed**
(the sweep-start values are RG1's to pick; the constraint "all three must spawn in the default" is
the load-bearing call and is satisfied).

Observed (not a deviation, no action): `inert_enabled_oppositions()` does NOT track the new K5
hazards (they are not R-oppositions). The preset's K5 values are provably non-inert anyway
(enabled + non-zero per_depth + cap>0), so the end-of-function `assert` stays clean. No helper
expansion was needed.

## Handoffs / follow-ups
- **itch publish (human-gated on network):** ran `bash tools/push_itch.sh` with
  `BUTLER=/mnt/c/wsl-libraries/butler/butler`. See the final report for the export/push outcome —
  the web export is the verifiable part; the real `butler push` to `broth.itch.ovh` needs network
  the sandbox cannot reach, so a network failure on the push step is EXPECTED and human-gated
  (documented in `tools/playtest/tester_readme.md` / `SETUP.md §1a`).
- **OQ-3 perf (carry-forward to Director playtest):** the worst-case ~112-body band (R1's 64 +
  the new 48) cannot be frame-timed headless (no render loop); recommend the Director run the
  `m14-all-on` cell at `lvl_size_mult 40` with maxed hazard magnitudes and confirm the frame rate
  holds. Both ceilings are independently enforced so the count is bounded by construction.
- Branch `general-purpose/RG1-m14` is ready for the orchestrator to integrate (do NOT self-merge).
  The pre-existing `STATUS.md` modification in the working tree was NOT touched/committed by RG1.
