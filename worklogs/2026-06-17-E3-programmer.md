# Worklog — E3 Death / Timeout Drops Haul

- **Date:** 2026-06-17
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1
- **Branch:** programmer/E3
- **Commit:** 9f238519b117d958181f06eb0124097869897d75 (implementation; this worklog-SHA fix is a trivial follow-up commit on the same branch)

## What changed
On death or clock timeout, the run now ends UNSUCCESSFULLY: the player keeps only a
"pockets" subset of the carried haul (whole items up to a value budget) and loses the
rest. Built `fail_run(cause)` + `_resolve_pockets()` on `GameState` as the failure
counterpart to E1's `extract_and_end_run()`, sharing the same run-state → meta-state
transfer, atomic `save_meta(0)`, `haul_banked` parity emit, and the single
`run_ended(cause, …)` lifecycle signal. The two old code paths (the value-fraction
`_on_player_died` and the new fail path) were collapsed into ONE drop code path:
`_on_player_died` and the new clock-timeout handler both call `fail_run`. Pockets
tuning is data-driven via a new `RunRules` resource. Added a debug-only `debug_kill`
input (key K) as the M1 "death" stand-in and a single `_run_ended` idempotency guard.

## Files touched
- `data/economy/run_rules.gd` — NEW `RunRules` Resource (`pockets_fraction`, `pockets_policy` enum).
- `data/economy/run_rules.tres` — NEW authored config: `pockets_fraction = 0.20`, `pockets_policy = HIGHEST_VALUE`.
- `systems/game_state.gd` — added `fail_run()`, `_resolve_pockets()`, `_sum_values()`; `_on_dive_clock_timeout()` + `dive_clock_timeout` connect; replaced `_on_player_died` body to route through `fail_run(&"death")`; removed stale `POCKETS_FRACTION` const; added `_run_ended` idempotency guard (set in `extract_and_end_run`/`fail_run`, reset in `start_run`); `_unhandled_input` debug-kill hook; load `run_rules` in `_ready`.
- `project.godot` — added `debug_kill` input action (key K), testing-only.
- `tests/test_death_drop.gd` (+ `.uid`) — NEW headless SceneTree test (6 cases).

## Checks run
- [x] `godot --headless --import` clean (no parse/script errors from E3 code; only a
      pre-existing unrelated missing `inventory_strings.en.translation`, which is
      gitignored/generated and untouched by this task). `RunRules` registers as a global class.
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy`
- [x] `godot --headless --script res://tests/test_death_drop.gd` → `DEATH DROP OK` (exit 0). Output lines:
      - `E3 fail_run cause=death pre_value=165 kept_value=30 lost_value=135 items_kept=1 depth=0`
      - `E3 fail_run cause=timeout pre_value=90 kept_value=0 lost_value=90 items_kept=0 depth=0`
      - `E3 fail_run cause=death pre_value=0 kept_value=0 lost_value=0 items_kept=0 depth=0`
      - `E3 fail_run cause=death pre_value=110 kept_value=10 lost_value=100 items_kept=1 depth=0`
- [x] Regression: `tests/test_extract_bank.gd` → `EXTRACT OK`; `tests/test_dive_clock.gd` → `DIVE CLOCK OK`.
- [x] Definition of done met: "Dying (debug_kill) or timing out ends the run, keeps only
      the pockets fraction (whole items, highest_value, 0.20 budget), discards the rest,
      persists meta, and fires exactly one `run_ended(&\"death\"|&\"timeout\", …)`." Verified
      by Cases 1–5: budget math, empty-bag valid, cheapest-exceeds-budget edge, double-fail
      and extract-then-fail idempotency (extract wins the tie), kept items in `banked_junk`.

## Design deviations

1. **Pockets fraction & model: GDD §6 `0.15` value-fraction → spec `0.20` whole-item.**
   - **Old (on `main`):** `GameState.POCKETS_FRACTION = 0.15`; `_on_player_died` kept
     `round(unbanked_value * 0.15)` and credited it **directly to Money**, banking no items.
   - **New (this task, per E3 spec recommendation):** keep **whole items** up to
     `floor(pre_value * 0.20)` (HIGHEST_VALUE), append the kept *items* to `banked_junk`
     (NOT Money — F2 owns the sell, matching E1), discard the rest.
   - **Why:** the E3 spec + its Open-questions recommendations call for 0.20 whole-item so
     F2 can itemize what survived (symmetric to the extract beat) and forward-compat with
     per-item sell rules. The old 0.15/value-fraction predates that.
   - **Needs Director disposition at wave-4 close-out:** the headline downside knob (0.15 vs
     0.20) and the Money-credit-vs-bank-items change are economy/feel calls. Recommendation:
     ratify 0.20 whole-item; it is the playtest-sensitive dial and now lives in `run_rules.tres`
     for fast iteration (sweep 0.15–0.25 at the G4 fun gate).

2. **Idempotency guard choice.** Added an explicit `bool _run_ended` rather than relying on
   `run_active`. Rationale: `extract_and_end_run()` did not early-return on `not run_active`,
   so a same-frame extract+timeout could both resolve. `_run_ended` is the minimal correct
   guard: first run-end wins, set at the top of both `extract_and_end_run()` and `fail_run()`,
   reset in `start_run()`. Extract wins a literal tie because it is wired/called first. Not a
   design departure — it implements the E3 Open-questions recommendation (#122).

3. **"Death" stand-in.** No enemies in M1, so `debug_kill` (key K) → `EventBus.player_died(&"death")`
   → `_on_player_died` → `fail_run(&"death")`. Reuses the existing `player_died` signal and the
   pre-existing `_on_player_died` connection (no new EventBus signal). Timeout is the only
   player-facing failure; `debug_kill` is testing/demo only. Matches the spec recommendation.

4. **Telemetry seam (no contract change).** `run_ended(reason, duration_s, depth)` is fixed-arity,
   so `value_lost`/`items_kept` can't ride on it. Kept value is reported via `haul_banked(kept_value)`
   (parity with extract); the full drop math (pre/kept/lost/items) is `print`ed by `fail_run` for now.
   **Follow-up seam for G1 telemetry:** if lost-value needs structured surfacing, add a dedicated
   telemetry signal/row — do NOT widen `run_ended`'s locked signature.

## Handoffs / follow-ups
- **Greybox "RUN LOST — kept N" toast (spec, optional):** SKIPPED — D2/E2 own `ui/` this wave and
  the contract forbids editing `ui/` files. Recommend folding it into F2's sell screen (the spec's
  own recommendation: route failed runs through the same sell screen titled "RUN LOST — kept N").
- **Deviation #1 (0.15→0.20 + Money→items) needs explicit Director disposition** at the wave-4
  close-out deviation sweep.
- **G1 telemetry seam** for `value_lost` noted above.
