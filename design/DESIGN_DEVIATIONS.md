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

*Last close-out: **M1.9 Wave 2** (2026-07-03) — 8 entries (S2×4 + S5×4): **7 Reviewed + 1 Addressed**
(run-clock seam → typed injected Callable, fixed at close-out) — reapplied + archived to `DESIGN_DEVIATIONS_HISTORY.md`.*
*Prior: **M1.9 Wave 1** (2026-07-02) — 2 entries: 1 Reviewed + 1 Addressed. **M1.8** (2026-07-02) — 17 entries:
15 Reviewed + 2 Addressed (verdict record `design/M1_8_Tasks/G4_findings_M1.8.md`).*
*Prior close-outs: M1.6 Wave 2 (3 Reviewed), M1.5 (2), M1.4 Wave 5 (3), Wave 3 (1 Addressed), Wave 1 (2+1) — all in
`DESIGN_DEVIATIONS_HISTORY.md`.*

---

[2026-07-03] **S3 / bandgen surface** — S3 touched `systems/bandgen/band_pipeline.gd`,
`data/bands/band_profile.gd`, `data/bands/band_greybox.tres`, and `tests/test_band_pipeline_parity.gd`,
which the dispatch brief's must-not-touch line reserved. · The spec's **binding** §7.2 Q6(iv)
(orchestrator-adjudicated, superseding §2.4(ii)'s call-site fallback) directs exactly this: the
optional `piece_pool_ext: PieceCatalog` profile field + the pipeline's `rc.lvl_enabled` swap land
WITH S3's call-site switch — without it the preset (lvl-on) band would generate off the baseline
catalog (a layout/parity break `test_rg1_m13_verify` runs on). The parity test's P5 lvl case had to
follow (its direct-path comparison now generates against the ext catalog, since the swap is
pipeline-owned; P0 gains the piece_pool_ext same-object identity check). All-off fp e943ac9c8bc1
re-verified byte-identical; the swap is inert for null-`piece_pool_ext` profiles. ·
**Recommendation: Reviewed** (spec-over-brief conflict resolved in the spec's favor, as the brief
itself says "the spec is authoritative").

[2026-07-03] **S3 / test_run_config flatness pin** — `test_run_config.gd`'s "no nested Dictionary
values in `to_flat_dict()`" assertion gained ONE sanctioned exception: `"param_overrides"` (plus
coverage of the two new lever keys + neutrality/round-trip). · Breakdown amendment 10 makes the
nested `param_overrides` stamp (def_id → {param → value}, String keys, primitive leaves) canonical —
a def sweep is intrinsically two-dimensional; the `to_flat_dict()` docstring was amended in the same
change. Still JSON-safe; `{}` on every neutral config. · **Recommendation: Reviewed.**

[2026-07-03] **S3 / spec §3.5 case-7 expectation corrected** — `oppositions_enabled = [&"spike"]`
alone spawns ZERO instances (the spec sketch said "spawns via its authored card"). · S2 authored
every def's spawn card NEUTRAL (params mirror `RunConfig.new()` all-off defaults), so the enable-list
engages the deck machinery but n = base 0 + 0·depth = 0. `test_encounter_builder` case 7 asserts the
honest behavior: enable-list + `param_overrides` (e.g. `{"spike": {"base_count": 1}}`) spawns, and
the override is visible in the ctx merge. · **Recommendation: Reviewed** — and flag to S4: the
config-trap generalization should consider warning on "enabled def id with a fully-neutral card"
(the R-opposition BUG6 analogue).

[2026-07-03] **S3 / deck-lane ctx enrichment vs the §3.1 sketch** — the deck lane computes
cells/bounds once per PIECE (def-independent; the sketch recomputed per def) and its spawn ctx
carries, beyond the sketch's merged-params: the per-kind legacy ctx vocabulary (`initial_dir`/
`room_bounds`/`phase_salt`, keyed on a lane-local accumulator) plus the S0-reserved `room_key`. ·
Determinism-neutral (both are pure reorderings/additions with no RNG and no legacy-lane effect);
the kind ctx keeps known hazards authored into future decks (S7 authors existing hazards INTO
band_two) on their locked entity contract instead of a dead seam; `room_key` lets the service's
per-room cap tier actually bind for deck defs that author `per_room_cap > 0`. ·
**Recommendation: Reviewed** (S7 should confirm the deck-lane ctx suffices for band_two's deck).

[2026-07-03] **S3 / façade `is_inert()` pre-check (additive builder API)** — `_spawn_new_hazards`
asks `EncounterBuilder.is_inert(profile, rc)` before `_ensure_spawn_service()`. · Preserves S0's
all-off contract ("no def, no scene, NO service node") through the extraction: `populate()` alone
would arm the service before discovering the empty plan. Load-free on the all-off path (deck/extras
emptiness tests + the legacy adapter, which only loads defs for enabled+non-neutral types). ·
**Recommendation: Reviewed.**
