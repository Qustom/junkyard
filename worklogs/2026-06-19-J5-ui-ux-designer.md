# Worklog — J5 Depth-counter HUD fix

- **Date:** 2026-06-19
- **Subagent:** ui-ux-designer
- **Milestone:** M1.3
- **Branch:** worktree-agent-a8bf8db5217a2f20e (worktree off `main`)
- **Commit:** <full SHA>

## What changed
The bottom-left DecisionHUD depth readout was showing the **band counter**
(`GameState.current_depth`, pinned at 1 inside a band) instead of the **room depth**
the run actually traverses. Repointed `_refresh_depth()` to
`GameState.current_depth_index` + `max_depth_reached`, subscribed the HUD to the
already-emitted `EventBus.depth_changed` signal (edge-triggered in
`set_current_depth`), and dropped depth refreshes off the coincidental
inventory/band edges. The readout now reads `Depth {depth} / {max}` (live room depth
/ deepest reached = the gate metric), matching the Director disposition. The
`run_started`/`run_ended` boundary paint is retained — it produces the "Depth 0 / 0"
at entry that `depth_changed` cannot emit (`set_current_depth(0,…)` early-returns).
Stale "(no depth_changed signal exists in M1)" comments corrected.

HUD-only: no game-state change, no new EventBus signal, no `.tscn` change. The
readout is display-only and emits nothing → determinism (fp `e943ac9c8bc1`) untouched.

## Files touched
- `ui/hud/decision_hud.gd` — `_refresh_depth()` repointed to room depth fields; new
  `_on_depth_changed` handler + `depth_changed` subscription; depth dropped from
  `_on_run_inventory_changed` and `_on_band_entered`; header + inline stale comments
  corrected; `run_started`/`run_ended` boundary paint retained (Depth 0/0 at entry).
- `ui/hud/hud_strings.csv` — `HUD_DEPTH` → `Depth {depth} / {max}` (two-number format,
  Director-accepted). String stays behind `tr()`.
- `tests/test_decision_hud.gd` — depth assertion rewritten to drive `set_current_depth()`
  (emits `depth_changed`) and assert the readout tracks `current_depth_index` /
  `max_depth_reached`, with a band-entry regression guard; docstring + success print updated.

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `godot --headless --script res://tests/test_decision_hud.gd` → DECISION HUD OK
      (assertion drives `set_current_depth()`/`depth_changed`; band-entry regression guard passes)
- [x] definition of done met: `_refresh_depth()` reads `current_depth_index`+`max_depth_reached`;
      HUD subscribes `depth_changed`; depth no longer refreshed off `run_inventory_changed`;
      stale comments fixed; CSV updated to two-number form; test rewritten; no new signal,
      no game-state mutation, no `.tscn` change; determinism untouched.

## Design deviations
None — built exactly to the LOCKED spec + Director Disposition (FINAL): two-number
`Depth {depth} / {max}`, keep "Depth" wording, drop the band counter from the HUD
(field `current_depth` retained in GameState for end-path prints).

## Handoffs / follow-ups
A "Band N · Depth M" multi-band readout is an M2+ task, not a J5 concern (the
`GameState.current_depth` field is preserved for it). Per work-product contract:
NOT merged, NOT pushed — left on the worktree branch for the orchestrator.
