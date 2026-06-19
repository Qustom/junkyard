# Worklog — RG1 Playtest Build (full loop with risk active)

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer + build-verifier)
- **Milestone:** M1.1 (Greybox Cost Axis), Wave 3
- **Branch:** general-purpose/RG1
- **Commit:** 6013c072c6c3d223fa6154c87cc46f1055ca8a7e   ← integration commit (worklog SHA finalized in the immediate follow-up)

## What changed

The M1.1 integration/verification capstone: stacked the four wave-2 oppositions into the
single assembled `main_game` scene and proved the full loop runs unbroken under every
opposition combination with config-marked telemetry.

- **R2 `ReturnCost` + R3 `ExposureMeter` wired as PERSISTENT children of `main_game`**
  (like `DiveClock`), self-gating per run via their own `_on_run_started` (read
  `active_run_config.rN_enabled`, go inert if off) — a single persistent instance is
  correct, no per-run spawn/free. They connect to `EventBus.run_started/run_ended` in their
  own `_ready()`, so once parented they react to the lifecycle automatically.
- **`DiveClock` injected into `ReturnCost.dive_clock`** in `main_game.gd:_ready()` (the
  `.tscn` NodePath form for the typed `DiveClock` export resolved to null, so the spec's
  alternative — assign in `_ready` — is used). R3 added to group `r3_exposure_meter` in the
  `.tscn` so R2's `exposure` toll can find it.
- **"Back to Config" button** added to the sell screen (ratified §8 Q2): a new
  `back_to_config_pressed` signal → `main_game` re-shows the menu, so the Director can switch
  configs mid-session. The existing `Continue → start_new_run` quick-re-run path is intact.
- **Headless verification driver** `tests/test_rg1_loop_verify.{gd,tscn}` exercises and
  asserts the §4 matrix objective half (V1–V18) against the real assembled scene + the
  written `run_log.jsonl`. Prints `RG1 BUILD VERIFY OK`. Stable across repeated runs.
- **Playtest docs** updated: `loop_smoke_checklist.md` (M1.1 §4 matrix manual pass) and
  `tester_readme.md` (set a config + `build_tag`; the `run_config` snapshot is ground truth;
  JSONL at `user://telemetry/run_log.jsonl`).

**Inherited, NOT redone (verified present):** CFG already replaced the hardcoded config load
(`start_new_run` stages `_config_menu.apply_and_get_config()`, shape a) so config
carry-forward across Continue already works; R1 (`_spawn_r1_hazards`) and R4
(`_spawn_r4_nodes` + generator branch threading) already self-wire their per-run spawns;
BUG2 depth driver + BUG3 socket seal are intact and untouched.

## Files touched
- `scenes/game/main_game.gd` — `@onready` refs for `DiveClock`/`ReturnCost`/`ExposureMeter`;
  inject `_return_cost.dive_clock = _dive_clock` in `_ready`; connect SellScreen
  `back_to_config_pressed` → `_on_back_to_config` (re-show menu).
- `scenes/game/main_game.tscn` — added persistent `ReturnCost` (R2) + `ExposureMeter` (R3,
  group `r3_exposure_meter`) nodes as children of the root.
- `ui/sell/sell_screen.gd` — `back_to_config_pressed` signal + button wiring; the new button
  shares the tally lock with Continue; handler unpauses + hides + emits (no restart).
- `ui/sell/sell_screen.tscn` — `BackToConfigButton`.
- `tests/test_rg1_loop_verify.gd` / `.tscn` — the V1–V18 headless verification driver.
- `tools/playtest/loop_smoke_checklist.md` — M1.1 cost-axis matrix manual pass.
- `tools/playtest/tester_readme.md` — config menu + `build_tag` + snapshot-as-ground-truth.

## V1–V18 verification matrix (objective half — RG1 owns)

| # | Row | Result |
|---|---|---|
| V1 | R1 only → hazard rows + death reachable | **PASS (headless)** — `hazard_awoke` row present under the R1-only config; `run_ended.reason="death"` reached. Visible chase deferred to checklist. |
| V2 | R2 only → return_cost rows | **PASS (headless)** — `return_cost_incurred` rows fire on taxed retreat. "Feels costlier" deferred. |
| V3 | R3 only → exposure rows + timeout reachable | **PASS (headless)** — `exposure_crossed`/`exposure_penalty` rows fire; meter climbs; `timeout` reached. Readout legibility deferred. |
| V4 | R4 only → nav rows, sealed band | **PASS (headless)** — `nav_branch_taken` fires on a real junction crossing (player scripted across the band's own `_cell_to_junction` cells; branch_chance 1.0 + pinned seed 42). BUG3 seal covered by `test_bandgen_determinism`. Fog visuals deferred. |
| V5 | All four stacked | **PASS (headless)** — loop runs, no crash; ≥1 row from each opposition family present in one dive. |
| V6 | All OFF == M1.0 | **PASS (headless)** — all-off run emits ZERO opposition rows of any family; baseline behaviour intact (also `test_main_game_loop` MAIN GAME OK). |
| V7 | Reset-to-baseline == V6 | **PASS (headless)** — CFG `_on_reset_pressed()` returns the working config to `all_oppositions_disabled()`. |
| V8 | extract end-cause | **PASS (headless)** — `run_ended.cause="extract"` observed; sell screen + Money. |
| V9 | death end-cause | **PASS (headless)** — `run_ended.cause="death"` observed (driven via the hazard's `fail_run(&"death")` API). |
| V10 | timeout end-cause | **PASS (headless)** — `run_ended.cause="timeout"` observed (R3 max / clock API). |
| V11 | lost → timeout (no own arity) | **PASS (headless)** — R4-on run ended via `timeout`; no widened arity; nav rows distinguish in analysis; run terminates (no soft-lock). |
| V12 | Multiple runs/session, no leak | **PASS (headless)** — 4 repeat runs; settled `BandContainer` child count stays in a tight band (no >2× growth) once `queue_free` flushes. |
| V13 | Config snapshot per run | **PASS (headless)** — every `run_started.data.run_config` carries the full flat dict (all `to_flat_dict` keys); every swept config's run_started present. |
| V14 | Opposition event gating | **PASS (headless)** — rows present when ON, ABSENT in the all-off run. |
| V15 | `run_ended` arity intact | **PASS (headless)** — M1.0 fields present; `duration_s` real & ≥0 (BUG1); `max_depth` ≥1 = the driven max (BUG2). |
| V16 | Config carry-forward | **PASS (headless)** — second `start_new_run` (Continue path, no menu re-stage) keeps R3 on. |
| V17 | Build identity + `build_tag` | **HUMAN-DEFERRED** — `run_started.data.build = m1-<date>-<sha>` and `run_config.build_tag` ride telemetry (snapshot verified in V13); the Director-typed sweep label is set in the menu at play time → checklist. |
| V18 | No blockers / soft-locks | **PARTIAL/PASS (headless)** — every driven run has an exit and the menu is reachable after the loop (no stuck `run_active`). Real-input screen navigation (menu/consent/sell) → checklist. |

**Human-deferred rows** (need rendering / a human; on the manual checklist): V1 visible chase,
V2 felt cost, V3 readout legibility, V4 fog tightening, V17 Director build_tag on a returned
log, V18 real-input screen navigation. Headless-verified: 16 of 18 fully; V17/V18 partially.

## Checks run
- [x] `godot --headless --import` clean (no script parse errors; exit 0)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK`
- [x] `godot --headless res://tests/test_rg1_loop_verify.tscn` → `RG1 BUILD VERIFY OK` (stable over 3 runs)
- [x] `godot --headless res://tests/test_main_game_loop.tscn` → `MAIN GAME OK`
- [x] `godot --headless res://tests/test_bandgen_determinism.tscn` → `R4 NAV OK` + `BUG3 SOCKET SEAL OK`
- [x] `godot --headless res://tests/test_pursuing_hazard.tscn` → `PURSUING HAZARD OK`
- [x] `godot --headless res://tests/test_return_cost.tscn` → `RETURN COST OK`
- [x] `godot --headless res://tests/test_exposure_meter.tscn` → `EXPOSURE METER OK` + `EXPOSURE HUD OK`
- [x] `godot --headless res://tests/test_telemetry_config_marking.tscn` → `TEL CONFIG MARKING OK`
- [x] `bash tools/run_gdunit.sh` → 30/30 PASSED, exit 0
- [x] Definition of done (RG1 §7): a fresh build runs the complete loop with oppositions on,
      each is per-run toggleable from the menu, telemetry logs config + opposition events,
      multiple runs/session work, all-off reproduces M1.0 and each opposition verifies in
      isolation + stacked with all four end-causes reachable — the §4 matrix (V1–V18) passes.

## Design deviations
- **DiveClock injected in `_ready()` rather than via the scene's NodePath export.** The
  `dive_clock = NodePath("../DiveClock")` form in `main_game.tscn` resolved to `null` at
  instantiation for the typed `DiveClock` export, so the ref is assigned in
  `main_game.gd:_ready()` (an alternative the RG1 spec §1 explicitly allows). Behaviour is
  identical; flagging as a minor as-built note, not a behavioural change.
- **No opposition script was modified.** R1–R4 scripts, `event_bus.gd`, and `game_state.gd`
  are untouched (RG1 wires their public surfaces only). The R3 `r3_exposure_meter` group
  membership is set on the node instance in the `.tscn`, not in the R3 script.
- Otherwise **on-spec** (persistent self-gating R2/R3, all-off == M1.0 preserved, RunConfig
  never written to SaveManager, typed GDScript, greybox).

## Handoffs / follow-ups
- The 6 human-deferred matrix rows (visible chase, felt cost, readout legibility, fog
  tightening, Director build_tag on a returned log, real-input navigation) are on the
  updated `loop_smoke_checklist.md` for the human playtest pass before the build is shared.
- `RunConfig.to_flat_dict()` returns 30 keys (not "32" as the spec prose says); the driver
  asserts the full key set generically rather than a magic count, so it stays correct if
  knobs are added. Noting the prose/count discrepancy for the spec, no action needed.
