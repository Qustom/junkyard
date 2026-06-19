# Worklog — I3 R2/R3 visual cues

- **Date:** 2026-06-19
- **Subagent:** ui-ux-designer
- **Milestone:** M1.2 (Wave 2)
- **Branch:** ui/I3
- **Commit:** b9c8e71ac3a2fc17be339f46f5764f8d94235424   ← required

## What changed
Made R2 (egress toll) and R3 (exposure) legible on the HUD by projecting four
already-emitted EventBus signals — no new signal, no new game state. R3: the
exposure bar now colour-ramps green→amber→red as it climbs, draws read-only
threshold ticks from `r3_threshold_levels` that switch to a spent shape/state on
each crossing, punches a flash on `exposure_crossed`, and fades a `tr()`'d penalty
banner keyed on the `penalty_kind` StringName (`speed`/`vision`/`clock`; `none` →
no banner). R2: `return_cost_incurred` pulses the clock bar (clock toll only) and
spawns a floating "−N {unit}" indicator near the clock. A small, brief, optional
HUD-space screen-shake (driven from the DecisionHUD's own `Root`, never the game
camera) fires on a non-`none` R3 penalty (Q5 accepted). Every cue is gated on its
opposition, so an all-off run renders the M1.0 HUD; every colour cue carries a
redundant non-colour channel (number/shape/text/motion) per the E2 readability rule.

## Files touched
- `ui/hud/exposure_readout.gd` — added `exposure_crossed`/`exposure_penalty`
  subscriptions; colour ramp, threshold ticks (build + spend), flash punch, penalty
  banner (latest-wins with a floor + a `xN` stack count); per-run reset/rebuild on
  run boundaries. Projection only; reads `r3_threshold_levels` read-only.
- `ui/hud/decision_hud.gd` — added `return_cost_incurred` + `exposure_penalty`
  subscriptions; clock-toll pulse on `%ClockBar`, floating cost indicator spawned
  under a new `CostIndicatorAnchor`, and the optional HUD-space `Root` shake. Added
  `_r2_enabled()`/`_r3_enabled()` read-only config gates.
- `ui/hud/decision_hud.tscn` — added greybox nodes under `ExposureReadout`
  (`ExposureTicks`, `ExposureFlash`, `ExposurePenaltyBanner`) and a `CostIndicatorAnchor`
  under `Root`; bumped the exposure bar's prominence (220×24, label font 16→18,
  readout repositioned). All pre-existing node paths preserved (the E2 test reads them
  by direct path).
- `ui/hud/hud_strings.csv` — added 8 externalized keys: `HUD_PENALTY_SPEED/VISION/CLOCK`,
  `HUD_RETREAT_COST`, `HUD_COST_LIGHT/EXPOSURE/METER/DECAY`.

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `godot --headless --script res://tests/test_decision_hud.gd` → DECISION HUD OK
      (E2 projection contract intact: clock bar/label/tint, Holding, Depth, extract prompt)
- [x] Definition of done met (quote): "The player sees exposure climbing + each
      penalty (banner keyed by kind) + each retreat toll (clock pulse + floating −N);
      off = M1.0 HUD (no cues); honours E2 readability (non-colour channel for every
      cue); no new EventBus signal; smoke green." Headless cannot render the visuals;
      the cue logic, signal wiring, opposition gating, and externalized strings are
      verified; visual confirmation is the human playtest (behaviour described below).

## Design deviations
None. Built to the LOCKED spec + Director disposition: extend in place; colour-ramped
bar + read-only ticks + penalty banner on the four StringName kinds; clock pulse +
floating −N on `return_cost_incurred`; optional small screen-shake (Q5 accepted),
implemented HUD-space so it needs no `main_game.gd`/camera edit; no new EventBus signal;
gated off = M1.0 HUD. The Resolved-F2 rule is honoured (flash + tick-spend ride
`exposure_crossed`; banner rides `exposure_penalty` — no double-punch).

## Handoffs / follow-ups
- **Visual polish + final palette/positioning** is a human art pass (greybox only here):
  exposure-bar `StyleBox` fill colours, tick glyphs, banner/indicator typography, the
  two-zone "pressure stack" layout, and whether the shake amplitude (`penalty_shake_pixels`,
  default 5 px) feels right vs. jank. Salience budget (Q3) and shake feel (Q5) are the
  Director's playtest calls — tunables exposed as `@export`s (`banner_hold_seconds`,
  `flash_seconds`, `clock_pulse_seconds`, `cost_indicator_seconds`, `penalty_shake_pixels`,
  `penalty_shake_seconds`).
- **No `main_game.gd`/camera edit required** — the optional shake runs on the HUD's own
  `Root` (a HUD-space shake), so it stayed inside HUD ownership. If the Director later
  wants a true world-camera shake, that's a separate task for the `main_game.gd`/camera owner.
- **Not an I3 bug (flagged per spec §"Out-of-scope note"):** `return_cost.gd` charges
  nothing into R3's meter for an `exposure` toll (`exposure_meter.gd` exposes no `add()`),
  so the exposure bar won't move on an `&"exposure"` toll even though the "−exposure"
  indicator fires. That's an R2/R3 integration gap owned by those systems, not the HUD.
