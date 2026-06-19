# Worklog — R2 Costlier Return Trip

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.1 (Wave 2)
- **Branch:** general-purpose/R2
- **Commit:** 5e597bd72f082029c7d5b18ff1bdde6d7810c1ba   ← required

## What changed
Built `ReturnCost` (R2 — costlier return trip), a run-state opposition node that
puts a depth-scaled price on the retreat. On each `EventBus.depth_changed` it reads
the live return distance `GameState.current_dist_to_gate`; when that distance drops
(a retreat) it charges a marginal-per-hop toll (`r2_cost_per_depth` per taxed hop
above `r2_depth_threshold`, plus `r2_cost_magnitude` once on the first taxed retreat
— §9 D6, no lump-at-gate). The toll is routed by `r2_toll_resource` through existing
public surfaces only: `clock` → `DiveClock.modify_light(-cost)` (may trigger the
existing `dive_clock_timeout` → `fail_run(&"timeout")`); `meter` → R2's own run-state
debt meter (cap → `GameState.fail_run(&"timeout")`); `exposure` → R3's run-state meter
only if R3 is present/enabled (no meta `add_exposure`). `lengthen` (mech 0) aliases
into the egress-toll path with a distance multiplier; `decay_behind` (mech 1) is
guarded by a mandatory reachability check that self-downgrades to a toll on the
linear M1.0 spine (never severs the sole path home) and is otherwise R4-dependent
(runtime graph hooks left as no-ops until R4 branching lands). Emits the pre-declared
`return_cost_incurred(depth, cost_kind, magnitude)`. All-off (`r2_enabled=false`)
charges nothing and emits no rows = M1.0 baseline.

## Files touched
- `systems/oppositions/return_cost.gd` — NEW. The `ReturnCost` run-state node (§5 logic). First creator of `systems/oppositions/`.
- `systems/oppositions/return_cost.tscn` — NEW. Optional trivial scene wrapper (NOT wired into `main_game.gd`; RG1 instantiates + injects `dive_clock`).
- `tests/test_return_cost.gd` / `.tscn` — NEW. Headless scene test (autoloads live), drives `start_run` + a descend/retreat `set_current_depth` sequence.

## Checks run
- [x] `godot --headless --import` clean (no parse errors) — exit 0
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `godot --headless res://tests/test_return_cost.tscn` → RETURN COST OK
- [x] `bash tools/run_gdunit.sh` → GdUnit4 run PASSED (30/30 test cases, 0 failures)
- [x] definition of done met: "the knob exists and takes effect" — deep retreat (d=8)
      charges 12.5 light, shallow (d=1, thr=1) charges 0, high threshold (10>maxdepth)
      charges 0, all-off charges 0 and emits no rows; `return_cost_incurred` fires with
      `cost_kind=&"clock"`/`&"meter"` and the marginal magnitude; the clock drains by
      the charged amount.

## Confirmed: edited NO autoload/scene source
NOT touched: `systems/event_bus.gd`, `systems/game_state.gd`,
`scenes/game/main_game.gd`, `systems/dive_clock.gd`. R2 routes everything through
existing public surfaces (`DiveClock.modify_light`, `GameState.fail_run(&"timeout")`,
`EventBus.return_cost_incurred`) and reads `GameState.current_dist_to_gate` /
`GameState.active_run_config` read-only.

## Design deviations
**As-built name corrections applied (spec predates the BUG2/TEL merge; corrections
were supplied in the brief and match `M1_As_Built.md`, so these are spec-sketch
fixes, not design departures):**
- Live return distance read from `GameState.current_dist_to_gate` (BUG2 surface),
  not a per-piece `PlacedPiece.dist_to_gate` read; trigger is
  `EventBus.depth_changed(depth_index, max_depth)`.
- `RunConfig` enums are plain `@export_enum` ints — no `RunConfig.R2_*` named
  constants exist. Defined local `const` ints (`MECH_*`, `TOLL_*`) for readability.

**Other notes (not deviations):**
- `decay_behind` ships as the linear-spine self-downgrade-to-toll path per §9 D2 /
  §7: the runtime link-collapse hooks (`_link_player_just_crossed`,
  `_gate_reachable_without`, `_collapse_link`) are no-ops until R4 supplies a
  branching walkable graph. This is the spec-sanctioned greybox state (secondary,
  R4-dependent mechanism), explicitly flagged in §7 — not a departure.
- `exposure` toll resolves R3's meter loosely by node group `&"r3_exposure_meter"`
  (R3 is a wave-2 sibling that may not exist yet); charges nothing when R3 is
  absent/disabled per §9 D4 (no meta fallback).

→ **DESIGN_DEVIATIONS.md: none** (the corrections above are pre-ratified as-built
API fixes from the brief, not new departures).

## Handoffs / follow-ups
- **RG1** wires the dive scene: instantiate `ReturnCost` (or its `.tscn`) and inject
  the live `DiveClock` reference into `dive_clock`. This task built + unit-tested the
  node only and deliberately did NOT touch `main_game.gd` (§7).
- `decay_behind` real link-collapse needs **R4** branching (multiple routes home) +
  B2/B3 graph cooperation before it is more than a toll — sequence after R4.
