# Worklog — TUNE2 RG1 preset tuning (Feedback #1 camera, #3 rotating spikes)

- **Date:** 2026-06-21
- **Subagent:** general-purpose
- **Milestone:** M1.4 (Wave 5)
- **Branch:** worktree-agent-ab0a5763932b81220
- **Commit:** 7854ddd9d72361402a74c19e67ae41c34f83f1b9 (TUNE2 work) + a trailing worklog-SHA fixup

## What changed
Director-requested RG1 re-gate tuning of the fun preset (`make_default_play_preset()`) — NOT a
code-behaviour change. Two preset deltas:
- **Feedback #1 (camera):** `cam_visible_world_width` 576.0 → **1000.0** (Director set 1000 px
  visible-world-width; the old 576 framed too tight). `cam_enabled`/`cam_zoom_policy` unchanged.
- **Feedback #3 (rotating spikes never appeared):** the preset shipped `hspike_base_count = 0` +
  `hspike_count_per_depth = 0.15` (brief said 0.1 — the file had 0.15), so `floor(per_depth*depth)`
  stayed 0 until ~depth 7–10 and spikes effectively never spawned in a normal run. Raised to
  `hspike_base_count = 1`, `hspike_count_per_depth = 0.1`, `hspike_per_room_cap = 1` so at least one
  spike RELIABLY spawns from the first eligible (shallow) room. Per-type rotation/arm knobs unchanged.

Updated the K3 camera comment and the K5c spike comment + the shared-budget NOTE block to reflect
the new rationale (spikes now appear at shallow depth; BUG7 keeps the entry room safe so base>=1 is
no longer a spawn-kill risk).

The RG1 verify test required one edit: it drives the default preset through a depth-stepping loop and
ends with `extract`. With a shallow spike now spawning, the spike killed the player before the chosen
end-cause ("run not active after start_new_run"). Unlike R1 (which has the `r1_catch_kills` knob), the
new K5 hazards have no per-hazard kill toggle — a fatal contact always routes through
`fail_run(&"death")`. Added a `_driven_default_preset()` factory that disables the three K5 hazards
ONLY for the driven end-cause matrix (mirroring the existing `r1_catch_kills=false` intent). The
preset-shape assertions (`_verify_default_preset_shape`) and the real spawn checks
(`_verify_new_hazards_spawn_assembled` / `_verify_new_hazard_spawn_plan`) still exercise the FULL
preset with all three hazards ON, so coverage is unchanged.

## Budget check (stays under the 48 ceiling without starving spikes)
NEW_HAZARD_BAND_CEILING=48, starvation order pingpong→bomb→spike (spikes placed LAST). On the default
~19-room/~15-depth band:
- pingpong: base 0, per_depth 0.15, cap 2 ⇒ ~9 total
- bomb:     base 0, per_depth 0.15, cap 2 ⇒ ~9 total
- spike:    base 1, per_depth 0.1, cap 1 ⇒ exactly 1 per eligible room ⇒ ~19 total
Combined ≈ 37 < 48. Keeping pingpong/bomb at base 0 is what protects the spike budget; spike cap 1
clamps each room to one spike regardless of the depth ramp, so the spike total tracks the eligible-room
count and never blows the ceiling.

## Files touched
- `data/run_config/run_config.gd` — `make_default_play_preset()` only: cam_visible_world_width 576→1000,
  hspike base 0→1 / per_depth 0.15→0.1 / per_room_cap 2→1, with updated K3/K5c/shared-budget comments.
  No code defaults, no `fingerprint()` inputs touched.
- `tests/test_rg1_m14_verify.gd` — added `_driven_default_preset()` (K5 hazards off for the driven
  matrix only) and pointed the M1-default-preset driven run at it. No assertion weakened; the all-off
  fingerprint assertion (e943ac9c8bc1) is untouched.

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK, exit 0
- [x] `godot --headless res://tests/test_rg1_m14_verify.tscn` → **RG1 M1.4 VERIFY OK, fp e943ac9c8bc1, exit 0**
- [x] `godot --headless res://tests/test_run_config.tscn` → R0 OK, exit 0
- [x] `godot --headless res://tests/test_new_hazard_spawn.tscn` → K5i OK, exit 0
- [x] `godot --headless res://tests/test_spike_hazard.tscn` → K5c OK, exit 0
- [x] All-off fingerprint stays byte-identical e943ac9c8bc1 (cam_*/hspike_* are run-state, never feed fingerprint())

## Design deviations
none — this is a Director-requested fun-preset tuning (RG1 Feedback #1 camera, #3 spikes), not a
code-behaviour change. The all-off control (`RunConfig.new()`) is untouched and stays byte-identical.
The only contract subtlety: the verify driver now disables the K5 hazards for its driven end-cause
matrix run (a test-harness accommodation, not a design change) because the now-shallow spike would
otherwise pre-empt the chosen extract end-cause; the full preset is still verified for shape + real
spawn elsewhere in the same test.

## Handoffs / follow-ups
- Worktree was branched BEFORE BUG7 (spawn-room/entry-cell exclusion). The orchestrator must re-verify
  the combined wave after merging both — `hspike_base_count=1` relies on BUG7 to keep the entry room
  safe so a shallow spike does not spawn-kill the player at the band entry.
