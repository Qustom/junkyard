# BUG5 — R2 `exposure` toll doesn't charge R3's meter (missing `add()` mutator)

**Milestone:** M1.2 · **Wave:** 2 close-out (Director-filed 2026-06-19) · **Workstream:** correctness / fairness
**Origin:** I3 (R2/R3 cues) surfaced it; confirmed against source at the Wave 2 close-out. **Builder:** `general-purpose`
**dependsOn:** I2/I3/I4 (all done) · **Knobs:** none new · **Telemetry:** none new
**Touch:** `systems/oppositions/exposure_meter.gd` (+ a regression test under `tests/`)

> Director disposition (2026-06-19): **Fix now as BUG5.** A whole R2 toll mechanism (the `exposure` toll resource)
> fires its cue + telemetry row but does nothing to the meter — a fairness/legibility gap squarely in M1.2's remit.
> Land it **before the Wave 3 re-gate** so the exposure-toll sweep is functional.

---

## 1. Root cause (confirmed at source)

R2's `ReturnCost._charge()` (`systems/oppositions/return_cost.gd`) for `TOLL_EXPOSURE` resolves R3's meter by group
(`r3_exposure_meter`) and calls it **only if the method exists**:

```gdscript
# return_cost.gd, _charge() → TOLL_EXPOSURE branch (as-built)
var meter: Node = _r3_meter()
if meter != null and meter.has_method(&"add"):
    meter.call(&"add", cost)
EventBus.return_cost_incurred.emit(d, &"exposure", cost)
```

But `systems/oppositions/exposure_meter.gd` exposes only **read-only getters** (`get_meter()`, `get_levels_crossed()`,
`is_active()`) — there is **no public `add(amount)` mutator**. So `has_method(&"add")` is `false`, the charge is skipped,
and the toll is a no-op on the meter. The telemetry row still emits and (after I3) the "−N exposure" indicator fires —
so the player sees a toll that does nothing. The gap has been latent since M1.1 (R2 and R3 were built in parallel).

`return_cost.gd` is **already correct** — it calls `meter.add(cost)`. The fix is entirely on the R3 side: give the
meter the `add()` mutator R2 already expects.

## 2. The fix (contract)

Add a public `func add(amount: float) -> void` to `exposure_meter.gd` that injects `amount` into the **same run-state
meter** the time-accrual path drives, and **routes through the identical threshold-crossing / penalty logic** — so an
R2 exposure toll that pushes the meter past a `r3_threshold_levels` boundary fires the same `exposure_crossed` /
`exposure_penalty` (and `exposure_meter_changed`) that natural accrual would. Do NOT add a second, divergent crossing
path: refactor so both `_process()` accrual and `add()` funnel the meter mutation + crossing-detection through one
shared internal helper (e.g. the existing `_emit_meter_changed()` + whatever `_process` uses to detect crossings).

**Guardrails:**
- **No meta write.** The exposure toll charges only R3's **run-state** meter (never `GameState` meta) — `return_cost.gd`
  §9 D4/D5 is explicit. `add()` mutates the run-state meter only; nothing persists.
- **Clamp** to the meter's valid range (`[0, cap]`) exactly as accrual does.
- **All-off / R3-off unchanged.** `add()` is only ever called when R3 is enabled (R2's `_r3_meter()` returns null if
  `not r3_enabled`). With R3 off, the meter node self-disables; `add()` is never invoked. The all-off baseline is
  byte-identical.
- **No new signal, no new knob, no telemetry schema change, no `run_ended` arity change.** Reuse the already-declared
  `exposure_meter_changed` / `exposure_crossed` / `exposure_penalty`.
- **Determinism:** R3 is time/exposure-driven gameplay state, not proc-gen — `band.fingerprint()` is untouched. Confirm
  the bandgen + level-scale determinism tests still pass.

## 3. Acceptance criteria

1. With R2 on + `r2_toll_resource = exposure` + R3 on, a retreat that incurs a toll **raises R3's meter by the toll
   amount** (was: no change); if that pushes past a threshold, the matching `exposure_crossed` + `exposure_penalty`
   fire exactly as accrual would (and I3's bar/banner respond).
2. R3 off (or R2 off) → `add()` never runs; all-off = M1.0 baseline byte-identical.
3. A regression test asserts: `exposure_meter.add(x)` raises `get_meter()` by `x` (clamped), emits
   `exposure_meter_changed`, and crossing a threshold emits `exposure_crossed`/`exposure_penalty`. Bonus: an integration
   assertion that R2's `TOLL_EXPOSURE` charge now moves the meter (drive `ReturnCost` with R3 present).
4. Smoke + existing determinism/HUD/exposure suites stay green.

## 4. Files to touch
- `systems/oppositions/exposure_meter.gd` — add `add(amount)` + funnel accrual/add through one shared mutate+cross helper.
- `tests/test_exposure_meter*.gd` (extend if it exists, else a new headless test) — the §3 assertions.
- **Do NOT touch** `return_cost.gd` (already calls `meter.add`), `event_bus.gd`, `game_state.gd`, or any Wave-2 file.
