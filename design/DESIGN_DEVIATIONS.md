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

## ⏳ Pending Director evaluation

*M1 waves 1 & 2, wave 3, and **wave 4** (E2, E3, D3, G5, F1, F2 — 11 deviations, Director-evaluated 2026-06-18: 1 Addressed / 10 Reviewed) have all been dispositioned and moved to `DESIGN_DEVIATIONS_HISTORY.md`.*

*Wave-5 (G1, G2, G3, G4) deviations land here as those tasks integrate, then get evaluated at the wave-5 close-out.*

### Wave 5 — G1 (telemetry JSONL)

All five below are spec-sketch-vs-as-built reconciliations (the `G1_telemetry_events.md` sketch is idealized; `M1_As_Built.md` is canonical). None changes gameplay; none touched `event_bus.gd` or `game_state.gd`; no new EventBus signals.

1. `[2026-06-18] G1 / Settings architecture` — **No `Settings` autoload and no `telemetry_toggled` signal** (the sketch assumes both). Instead opt-in is a static `Settings` (RefCounted) helper over a `ConfigFile`; the toggle applies via `Telemetry.set_enabled()`. · *Why:* avoid adding an autoload mid-wave; avoid a signal that would need pre-declaring on `event_bus.gd`. · *Recommendation:* **Reviewed** — minimal surface, on-architecture for a single preference.
2. `[2026-06-18] G1 / opt-in persistence` — **Opt-in flag persisted in `user://settings.cfg`, NOT via the SaveManager meta schema** (acceptance criterion says "persisted via SaveManager"). · *Why:* a meta-schema home needs a v2→v3 bump + migration + binary fixture + an edit to `game_state.gd` (a G2-contention file the brief says to avoid); a UI consent preference is arguably profile config, not gameplay meta-state. · *Recommendation:* **Reviewed** (keep ConfigFile). If the Director wants it in `meta.sav`, that's a follow-up task (schema bump + fixture).
3. `[2026-06-18] G1 / run_started payload` — **`run_started` row logs `band_id`+`seed`, not `tier_label`** (sketch field). · *Why:* the real `run_started(band_id, seed)` has no tier label and M1 run-state has no run-length-target field; `tier_label` (15/30/60-min bucket) is a G4 analysis-time classification from `run_ended.duration_s`. · *Recommendation:* **Reviewed**.
4. `[2026-06-18] G1 / run_id source` — **`run_id` derived inside Telemetry as `r_<hex(seed)>`, not owned by GameState** (sketch recommendation). · *Why:* the brief forbids touching `game_state.gd` this wave; the brief itself permits Telemetry-derived ids when GameState edits risk conflict. Stable per run; not unique if a seed is reused (rows also carry `session_id`+`t_ms`). · *Recommendation:* **Reviewed** for M1; revisit at G4 if seed-reuse collisions matter.
5. `[2026-06-18] G1 / log path` — **Log path is `user://telemetry/run_log.jsonl`** (G1 spec + As-Built), superseding the old `events.jsonl`. The old autoload + the QA playbook prose used `events.jsonl`. · *Why:* match the canonical contract. · *Recommendation:* **Reviewed** + reapply doc: update playbook 07 prose `events.jsonl` → `run_log.jsonl` at close-out.

### Wave 5 — G2 (GdUnit4 vendored + logic tests)

All four below are spec-sketch-vs-as-built reconciliations / runner facts; none changes gameplay. No edits to `event_bus.gd` or `game_state.gd`.

1. `[2026-06-18] G2 / invented test APIs` — The `G2_tests_gdunit4.md` sketch references APIs that **do not exist** (`LayoutGen.generate`, `Inventory.new(cap)` with dict items, `Economy.bank/sell/CURRENCY_RATE`, `DeathDrop.resolve` scalar). Tests were written against the **real** as-built surface (B2/B3 `Band`/`JunkPlacer`, D1 `RunInventory`, E1/E3/F1 `GameState` methods). · *Why:* `M1_As_Built.md` is canonical and already wins over spec sketches. · *Recommendation:* **Reviewed**.
2. `[2026-06-18] G2 / pockets fraction` — Spec open-question recommends `POCKET_FRACTION = 0.0`; tests instead assert ratified **decision #13's `0.20` whole-item `HIGHEST_VALUE`** pockets. · *Why:* as-built decision #13 supersedes the stale spec open-question. · *Recommendation:* **Reviewed**.
3. `[2026-06-18] G2 / test_jsonl_writer deferred` — The spec's `test_jsonl_writer` suite was **not authored** (G1's `JsonlWriter` was on a parallel branch, absent from G2's worktree). G1 shipped its own lightweight writer check. · *Why:* parallel-wave file availability. · *Recommendation:* **Reviewed** — fold a GdUnit4 `test_jsonl_writer` in post-merge (now that both branches are on `main`) as a small G3-adjacent follow-up.
4. `[2026-06-18] G2 / GdUnit4 CLI flags` — The headless runner requires `--ignoreHeadlessMode` (documented in `tools/run_gdunit.sh` + CI). GdUnit4 vendored at **v6.1.3** (v6.x targets Godot 4.5+, matching our 4.6.3; v5.x only 4.3/4.4). · *Why:* runner reality. · *Recommendation:* **Reviewed**.
5. `[2026-06-18] G2 / economy-math test seam` — Economy suites snapshot/restore global meta (`money`/`banked_junk`/`run_rules`) around each test rather than calling a pure helper, because lifting `_resolve_pockets`/`_sum_values`/`run_haul_value` into a static `EconomyMath` would edit `game_state.gd` (a G1-contention file this wave). · *Why:* avoid parallel-wave contention. · *Recommendation:* **Reviewed** — optional future `EconomyMath` static helper for autoload-free economy math; not required for M1.

### Wave 5 — G3 (greybox playtest build)

None of these change gameplay rules or touch the locked `event_bus.gd` arity / `game_state.gd` method signatures. The full loop runs start→finish, multiple runs per session (verified: `LOOP OK`, `MAIN GAME OK`).

1. `[2026-06-18] G3 / telemetry consent prompt deferred` — The G3 spec recommends an explicit **in-build first-run "enable telemetry" consent prompt**; G3 shipped the README opt-in instruction + the existing G1 settings toggle instead (no new in-build prompt). · *Why:* the prompt is a UI/UX task (better fit for `ui-ux-designer`) and the opt-in settings panel already exists from G1; defaulting OFF is preserved. · *Recommendation:* **Reviewed for the build pipeline**, but flag to the Director: if empty G4 telemetry is a real risk, **plan a small follow-up task** to add the in-build prompt before the G4 cohort runs (the spec's own concern).
2. `[2026-06-18] G3 / per-run seed policy` — MainGame mints each run's seed locally as `time*31 + run_count*const`. · *Why:* M1 has no meta seed/run-counter system; this varies layout per run while staying reproducible within a process. · *Recommendation:* **Reviewed** — a real meta layer owns seed policy post-M1.
3. `[2026-06-18] G3 / enter_band on dive start` — MainGame calls `enter_band(BAND_ID)` once right after `start_run` so the HUD reads "Depth 1" in M1's single band rather than 0 at the gate. · *Why:* M1 ships one band; multi-band descent is post-M1. · *Recommendation:* **Reviewed**.
4. `[2026-06-18] G3 / build-id field on run_started` — Telemetry's `run_started` data dict gained a `build` field (`m1-<date>-<sha>` via new `systems/version.gd`). The G1 schema envelope (`SCHEMA_VERSION`, `ENVELOPE_KEYS`) and all other rows are **unchanged**; this is an additive payload field, not a schema bump. · *Why:* tie a feedback report + its JSONL to one exact build (G3 spec "build identity"). · *Recommendation:* **Reviewed** — reapply note: optionally document the `build` field in the G1 schema doc at close-out.
5. `[2026-06-18] G3 / publish pipeline human-gated (not a deviation, a flag)` — `nightly.yml` scaffolds the Butler/itch publish but **cannot run** until a human provisions `BUTLER_API_KEY` + a studio itch project/slug; export needs Win64 templates. No secret/slug invented; publish steps skip when the secret is absent. · *Recommendation:* **Reviewed** (correctly human-gated per the brief) — producer/human action item, not a design change.

### Wave 5 — G6 (in-build first-run telemetry consent prompt)

G6 is itself the resolution of wave-5 deviation **G3 #1** (Director disposition: **Addressed** — add the in-build prompt before the G4 cohort runs). It changes no gameplay rules and does not touch `event_bus.gd` or `game_state.gd`; no new EventBus signals.

1. `[2026-06-18] G6 / consent preference persistence` — The new consent "asked" flag (and the existing telemetry opt-in it gates) persists in **`user://settings.cfg` via `Settings`, NOT the SaveManager meta schema**. · *Why:* the brief explicitly fixes `settings.cfg` as canonical for this preference and forbids a meta-schema bump; this is consistent with the already-ratified G1 #2 disposition (a UI consent preference is profile config, not gameplay meta-state — a meta home would need a v2→v3 migration + fixture + a `game_state.gd` edit). · *Recommendation:* **Reviewed** — matches the brief and the prior G1 #2 ruling; no further design change needed.
