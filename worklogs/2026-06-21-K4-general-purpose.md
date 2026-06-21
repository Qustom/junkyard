# Worklog — K4 Configurable timer + near-end warning

- **Date:** 2026-06-21
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.4
- **Branch:** worktree-agent-a133cf32ad390df51
- **Commit:** 0924be6cdbd1464da983824b0d9d85e1c603091f   ← required

## What changed
Wired the M1.4 K4 timer knobs (landed by K0) into the live dive clock and HUD, per the
locked Resolved Decisions in `design/M1_4_Tasks/K4_configurable_timer_warning.md`:
- **Length override:** at run start `DiveClock` resolves an `_effective_max` — `timer_length_s`
  when `timer_enabled` and `> 0`, else the authored `DiveClockConfig.max_light` — following the
  `effective_room_count()` precedent. The clock clamps/signals against `_effective_max` thereafter.
- **One-shot near-end warning:** inside the single guarded `modify_light()` mutator, when remaining
  light crosses `timer_warning_threshold_s` (absolute seconds-remaining), `EventBus.dive_clock_warning(seconds_remaining, maximum)`
  fires exactly once, latched with `_fired_warning` (mirrors `_fired_timeout`; reset at `_on_run_started`).
  Ordered before the timeout block; the "started already below threshold" edge pre-arms the latch
  so the warning never fires on frame 0.
- **HUD cue (`DecisionHUD`):** a visual N-blink alarm flash on the clock bar (`CLOCK_WARNING_PULSE`,
  distinct from the R2 toll colour) + a floating "Time almost up!" banner, gated on `_timer_enabled()`
  (the existing `_r2_enabled()/_r3_enabled()` idiom). New string `HUD_TIME_LOW`.
- **Audio (gated stub, `AudioDirector`):** subscribes to `dive_clock_warning` (the hook the removed
  `light_low()` used to feed); `_on_clock_warning` gates on `timer_warning_channel == visual_audio`
  and is a no-op TODO(M2) placeholder — audio is an M2 stub per the Director.

## How the override + latch work
- **Length override** is resolved once per dive at `_on_run_started` from `GameState.active_run_config`:
  `_effective_max = config.max_light`; if `cfg.timer_enabled and cfg.timer_length_s > 0.0` then
  `_effective_max = cfg.timer_length_s`. The `.tres` stays the authored default; the knob is the
  per-run override layered on top (telemetry-marked, Reset-able to the all-off control). `get_max_light()`
  reports `_effective_max` once a run has started (falls back to `config.max_light` pre-run).
- **Warning latch** flips `_fired_warning` true on the first frame `_current <= _warning_threshold` and
  resets only at the next `_on_run_started` — identical discipline to `_fired_timeout`, so per-frame
  drain below the threshold (1/60 s steps at `drain_per_second=1.0`) never re-fires it. A positive
  `modify_light` (future refuel) does not re-arm within a dive (matches the timeout's once-per-dive
  contract; re-arm-with-hysteresis is an explicit future follow-up). The warning check is ordered
  BEFORE the timeout block so a single mutation past the threshold straight to zero still emits the
  warning before the timeout ("almost → gone").

## All-off confirmation
With `timer_enabled = false` (the code-level default / `active_run_config == null`): `_effective_max`
stays `config.max_light`, `_warning_threshold` stays `0.0`, so the `_warning_threshold > 0.0` guard is
false every frame ⇒ **no `dive_clock_warning` ever emits** and the clock is byte-identical to M1.0/M1.3.
The DiveClock is post-generation run-state and never feeds `fingerprint()` — the bandgen determinism
test reports **`fp=e943ac9c8bc1`, unchanged**.

## Files touched
- `systems/dive_clock.gd` — `_effective_max`/`_warning_threshold`/`_fired_warning` state; length
  override + start-below pre-arm in `_on_run_started`; the one-shot warning emit in `modify_light`;
  `get_max_light()` reports the effective max.
- `ui/hud/decision_hud.gd` — `dive_clock_warning` subscription, `_on_dive_clock_warning`, `_flash_warning`,
  `_spawn_warning_banner`, `_timer_enabled()` gate, `CLOCK_WARNING_PULSE` + the two warning-flash knobs.
- `systems/audio_director.gd` — `dive_clock_warning` connect + the channel-gated `_on_clock_warning` no-op stub.
- `ui/hud/hud_strings.csv` — `HUD_TIME_LOW` ("Time almost up!"). (`.en.translation` is gitignored; regenerated on import.)
- `tests/test_dive_clock.gd` — extended: all-off fires no warning + reports authored length; length
  override applied; near-end warning latches exactly once (incl. fresh-run re-arm); start-below-threshold pre-arms the latch.

## Checks run
- [x] `godot --headless --import` clean (CSV reimported, all scripts compiled, no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy` (exit 0)
- [x] `godot --headless --script res://tests/test_dive_clock.gd` → `DIVE CLOCK OK — … K4: all-off fires no warning, timer_length_s override applied, near-end warning latches exactly once, start-below-threshold pre-arms the latch` (exit 0)
- [x] `godot --headless -d -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/test_bandgen_determinism.tscn` → `fp=e943ac9c8bc1` (unchanged — all-off fingerprint intact)
- [x] definition of done met: length override read from `GameState.active_run_config`; one-shot latched warning emitted from `modify_light`; HUD visual cue gated on `timer_enabled`; audio gated stub via AudioDirector; all-off = today's clock + fp unchanged.

## Design deviations
None. Implemented exactly per the K4 Phase-3 Resolved Decisions (RD-1 length override location,
RD-2 absolute-seconds threshold, RD-3 supersede `light_low` via the AudioDirector re-point [K0 already
removed the dead signal], RD-4 two-arg `(seconds_remaining, maximum)` payload, RD-5 HUD cue, RD-6
visual-always + audio config-gated no-op, RD-7 no re-arm within a dive, RD-8 all-off invariant + fp).

## Handoffs / follow-ups
- **Director feel-calls (already surfaced in the K4 design, not blocking K4):** the preset
  `timer_warning_threshold_s` value (recommended ~10 s of a 60 s dive) and whether RG1 ships a
  placeholder audio beep (recommended visual-only; audio path is a no-op TODO(M2)). The preset values
  live in `make_default_play_preset()`, owned by the preset/RG1 work — K4 only reads the knobs.
- Re-arm-on-refuel-within-a-dive (with hysteresis) is an explicit future follow-up if a later milestone
  adds meaningful mid-dive refuels; out of M1.4 scope.
- Threshold is in light-units; equals wall-clock seconds only while `drain_per_second == 1.0` (the
  authored default) — documented, knob name unchanged (K0-locked).
