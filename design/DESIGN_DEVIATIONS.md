# Design Deviations Log (active working set)

Append-only record of every place the build departed from `Junkyard_GDD.md`,
`Junkyard_Technical_Design.md`, the role playbooks, or the documented setup — with rationale.
The orchestrator and each dispatched subagent append here whenever a task departs from spec.

**Lifecycle (`CLAUDE.md` → "Wave close-out — deviation assessment"):** this file holds
deviations **awaiting the Director's evaluation**. After each wave, the Director dispositions every
entry **Reviewed** or **Addressed** (Claude only recommends — it never self-dispositions). Per the
verdict, Claude reapplies to the design (usually `design/M1_Tasks/M1_As_Built.md` or
`M1_Design_Decisions.md`), then **moves the entry to `DESIGN_DEVIATIONS_HISTORY.md`**. Between
fully-evaluated waves this file is ideally empty.

Format: `[date] <id/area> — what changed vs. the doc · why · Claude's recommendation`

---

*Current: **M1.12 Wave 3** (V4) — 1 entry (private `_evaluate_quota` facade delegate), rec Reviewed — awaiting Director disposition (non-blocking; batched to the Wave-4 boundary). **M1.12 Wave 2** (V2) — 1 entry (telemetry payload-field drop), **pre-dispositioned via D-RAT-7** — records the shape change; no new Director action. **M1.10 Wave 5** (TG1) — 1 entry (test-fixture), rec Reviewed — non-blocking.*
*Prior: **M1.11 Wave 3** (2026-07-08) — U3: 1 Reviewed (archived 2026-07-08).*
*Prior: **M1.11 Wave 2** (2026-07-07) — U1: 3 Reviewed (archived 2026-07-08).*
*Prior: **M1.11 Wave 1** (2026-07-06) — U0: 4 Reviewed (archived 2026-07-07), U2a/U2b: none.*
*Prior: **M1.10 Wave 4** (2026-07-05) — T4: 0 deviations — build complete (T0–T4); portal 3 for 1 bespoke line.*
*Prior: **Wave 3** T3: 0 dev (band 3 = 0 lines) · **Wave 2** T1: 0 dev · **Wave 1** T0: 3 Reviewed (archived), T2a/T2b: none.*
*Prior: **M1.9 Wave 5** (2026-07-03) — 1 entry (S8): 1 Reviewed — build phase S0–S9 fully swept.*
*Prior: **M1.9 Wave 4** (18: 13+5) · **Wave 3** (5: 4+1) · **Wave 2** (8: 7+1) · **Wave 1** (2: 1+1) ·
**M1.8** (17: 15+2, verdict `design/M1_8_Tasks/G4_findings_M1.8.md`) · M1.6/M1.5/M1.4 — all in `DESIGN_DEVIATIONS_HISTORY.md`.*

---

[2026-07-05] TG1/def-menu-coverage-test — `test_def_menu_coverage.gd` hard-coded the splitter IN-DECK
chip as `"IN DECK: band_two"` (an FBM19b-era expectation); T3's D-RAT-6 deck correctly added splitter to
band_three, so the chip now correctly reads `"band_three, band_two"`. TG1 updated the stale test
expectation to a per-id map (charger → band_two; splitter → band_three, band_two). · why: the PRODUCT
behavior is correct (the menu surfaces true deck membership); only the test's expectation was stale and
not updated in the T3 wave. Test-only change; no production `.gd`/`.tres` touched. · Rec: **Reviewed** —
test caught up to ratified product behavior; no design change.

---

[2026-07-10] M1.12 V2/telemetry-payload-drop — retiring the six dual-emit legacy opposition signals
drops three telemetry payload fields with no production/analysis consumer: `hazard_awoke.trigger`
(near-constant), `throw_killed_hazard.item_id` (orphan; still local in `killer_ctx`),
`hazard_pursuer_state.state` (patrol/chase; the generic `&"state"` mark preserves count/timing). These
are the only observable telemetry-shape changes in V2; the generic `opposition_event` family carries
every still-consumed field, and no `SCHEMA_VERSION` bump results (envelope untouched; no save change).
· why: the fields cannot be preserved without a forbidden `opposition_event` arity change, and nothing
reads them. · **Disposition: pre-ratified via D-RAT-7 (Director accepted at the 2026-07-10 design
lock)** — recorded for the trail; archive to `DESIGN_DEVIATIONS_HISTORY.md` at the M1.12 close (no new
Director action needed).

---

[2026-07-10] M1.12 V4/private-quota-delegate — the V4 GameState split moved quota eval into the new
`QuotaLadder` sub-object, but `test_quota_system` white-box-calls the *private* `GameState._evaluate_quota(sold_total)`
at 6 sites (the design's public-surface facade audit enumerated only the public API, not private methods a
test reaches into). To honor the zero-caller-edits contract, V4 kept a private `_evaluate_quota` delegate on
the GameState facade forwarding to `_quota.evaluate(...)` with byte-identical pre-V4 semantics — no test
edited, no behavior changed. · why: preserving the private method (vs editing the 6 test sites) keeps the
facade truly transparent and the test suite untouched. · Rec: **Reviewed** — behavior-preserving facade
delegate; the alternative (rewrite the test onto `QuotaLadder.evaluate`) is a fine future cleanup but not
required. Batched to the Wave-4 Director boundary.

---


---

[2026-07-10] M1.12 V3/K5-per-band-cap — the V3 design (step 4 / OQ-F) put the K5 per-room caps
(pingpong/bomb 2, spike 1) on the shared defs and relied on the `&"new_hazards"` cap-group ceiling (48)
alone to bound the combined total. On a deep (~30-room) greybox band this is insufficient: the deck's
authored draw-order (pingpong→bomb→spike) lets pingpong+bomb saturate the 48 ceiling and starve spike to
0 — a hazard-type COVERAGE failure vs the old fair-share machine, which explicitly split the ceiling
16/16/16. V3 added `per_band_cap = 16` (the fair-share slice, 48/3) to each K5 def, restoring per-type
balance. Result: the legacy→deck equivalence is now EXACT (0.0% Δ per type) on every fixture band, and all
three types always appear. Inert for band_two (its K5 cards are neutral → never spawn → the cap never
binds); layout fps unmoved. · why: without it, "exact type coverage" (D-RAT-3a) breaks on deep bands. ·
Rec: **Reviewed** — a faithful reproduction of the retired fair-share slice as data, not a design change.

---

[2026-07-10] M1.12 V3/param-overrides-cross-band-leak — the K5 play magnitudes ride the play preset's
`rc.param_overrides` (per the V3 design step 4 — required so an all-off run = neutral deck = zero hazards;
baking magnitudes into `band_greybox`'s deck entries would spawn K5 on an all-off greybox run and break the
"all-off = M1.0 loop" baseline). But `rc.param_overrides` is keyed by def id and applies GLOBALLY: any band
that decks pingpong/bomb/spike gets the override. `band_two`'s deck carries those three as neutral refs, so
under the play preset band_two's K5 cards ACTIVATE and (drawn before charger/splitter) can eat its budget.
Benign in M1 — band_two is never dived under the play preset (greybox is the only dived band) — and
band_two's PROFILE stays byte-identical (`test_band_two_profile` green). `test_def_menu_coverage` (which
artificially generates band_two under the menu's default preset to test charger/splitter staging) drops the
greybox-only K5 overrides to isolate its intent. · why: inherent to the design's `rc.param_overrides` choice
(the correct one for the all-off baseline). · Rec: **Reviewed** — surface to the Director; flag for V3b and
any future band that shares K5 def ids that the global lever is the intended re-tuning surface.

---
