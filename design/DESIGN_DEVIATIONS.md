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

*Waves 1 & 2 evaluated by the Director and archived to `DESIGN_DEVIATIONS_HISTORY.md` on 2026-06-17.*

**Wave 3a integrated 2026-06-17 (C1b `202fb65`, E1 `9b18d83`, D2 `0681894`). The entries below await Director evaluation at the wave-3 close-out (after 3b: B3, C2). Claude recommends only — no self-disposition.**

### C1b — Junk schema consolidation
- `[2026-06-17] C1b/schema` — `Item`'s useful fields folded into `JunkItem` (`description`, `origin_band` carried over; `base_value`→`base_sell_value`, `slot_size`→`slot_size`, `needs_containment`→`containment_flags` per brief; `Item` retired). · On-spec; executes ratified human decision #1 (`Item`→`JunkItem` merge). · **Rec: Reviewed.**
- `[2026-06-17] C1b/data` — `data/items/sample_junk.tres` deleted, not converted to a `JunkItem`. · The curated `junk_catalog.tres` is the real content; a one-off sample adds nothing (brief preferred deletion). · **Rec: Reviewed.**
- `[2026-06-17] C1b/ci` — M0 smoke test's "Resource loads as data" step repointed from the deleted `sample_junk.tres` to a real catalog `JunkItem` (`junk_copper_pipe.tres`, asserts `base_sell_value==15` and new `tier==2`). · Keeps the load-as-data CI guarantee intact rather than dropping it. · **Rec: Reviewed.**

### E1 — Extract gate + bank
- `[2026-06-17] E1/signals` — Reused existing `run_ended` + `haul_banked` instead of the spec skeleton's new `run_end(cause, payload)` signal. · Orchestrator-directed; one run-end path so A3's clock + Telemetry react to a single `run_ended`. Tracks ratified decision #6. · **Rec: Reviewed.**
- `[2026-06-17] E1/save` — `banked_junk` persists as junk `id` strings, rehydrated from `junk_catalog.tres` on load (unknown ids skipped with a warning). · Save model is objects-OFF (`store_var(.., false)`), so storing Resource refs is not viable; matches the brief's preferred "store ids, rehydrate" option. · **Rec: Reviewed.**
- `[2026-06-17] E1/api` — Spec referenced `SaveManager.save_meta()`; real signature is `save_meta(slot: int)`. `extract_and_end_run()` hardcodes slot 0 (M1 has no slot-selection UI). · API adaptation; follow-up to route the active slot when a save/slot layer lands. · **Rec: Reviewed (note follow-up).**
- `[2026-06-17] E1/schema` — Meta `schema_version` bumped 1→2 with a v1→v2 migration (defaults `banked_junk` to `[]`); **no QA fixture exists yet** for the meta migration (smoke test exercises `_migrate_meta` inline only). · Schema change per TDD save rules, but TDD also requires a QA fixture per schema change. · **Rec: Addressed — plan a small QA task to add a v1→v2 meta save-migration fixture (`qa-playtest-coordinator`).**

### D2 — Inventory UI (greybox)
- `[2026-06-17] D2/signals` — Panel also connects to `run_started`/`run_ended`, not only `run_inventory_changed`. · `start_run()` builds a fresh bag and `end_run()` clears it without an `run_inventory_changed` emission at that instant; without this the HUD panel lags a whole run. Still pure-projection / EventBus-only. · **Rec: Reviewed.**
- `[2026-06-17] D2/ux` — Drop gesture is right-click only (spec allowed right-click *or* hold-to-drop). · Shipped the simpler deliberate gesture; hold-to-drop deferrable to playtest. · **Rec: Reviewed.**
- `[2026-06-17] D2/impl` — Cell rebuild uses `queue_free()` + immediate hide rather than synchronous `free()`. · A rebuild can fire from inside a cell's own `drop_requested` emission (locked node); engine-correctness detail, not a design change. · **Rec: Reviewed.**
- `[2026-06-17] D2/ux` — Added a "No active dive" idle state for `run_inventory == null` (spec just returned). · Required for an always-on HUD panel. Additive. · **Rec: Reviewed.**
- `[2026-06-17] D2/assets` — No `theme.tres` authored (spec marked it optional). · Per-cell overrides sufficed for greybox; deferred to the human visual pass. · **Rec: Reviewed.**
- `[2026-06-17] D2/repo` — Generated `inventory_strings.en.translation` committed (referenced by `project.godot` so `tr()` resolves on a fresh clone; the `.csv` remains the editable source). · Departs from the `.gitattributes` norm of committing plain-text sources only; the binary `.translation` is a build product. · **Rec: Director call — keep committed (works on fresh clone) vs. gitignore + generate on import.**

### B3 — Band depth / push-deeper (integrated `2026-06-17`, impl `ffbe875`)
- `[2026-06-17] B3/rng` — Used a **local `RandomNumberGenerator`** seeded from `band.resolved_seed` + a fixed salt for the junk sub-stream, instead of the spec skeleton's nonexistent `RNG.fork("junk")`. · The `RNG` autoload exposes no fork/stream/set_seed; a local generator gives a reproducible sub-stream and provably never perturbs the layout RNG (verified: `band.fingerprint()` unchanged after planning). On-spec *intent* (decoupled, reproducible). · **Rec: Reviewed (reapply the real RNG sub-stream pattern to `M1_As_Built.md`).**
- `[2026-06-17] B3/schema` — Consumed `JunkItem`/`base_sell_value` from `junk_catalog.tres` (filtered by `tier`), not the spec's `Junk`/`base_value`/`junk_pool.tres`. · Executes the ratified C1b merge; no `junk_pool.tres` exists. · **Rec: Reviewed.**
- `[2026-06-17] B3/seam` — B3 produces a deterministic **placement plan** (`JunkPlacer.plan() -> Array[{world_pos, item, depth}]`) + debug overlay only; the interactive `JunkPickup` entity, A2 wiring, inventory add, and `junk_picked_up` were left to **C2**. B3 added only `junk_spawned(item_id, depth)` to EventBus. · Orchestrator-decided seam to prevent B3/C2 collision on the shared pickup/spawn path. · **Rec: Reviewed (record the B3↔C2 seam in `M1_As_Built.md`).**
- `[2026-06-17] B3/test` — The B3 acceptance test runs as a **`.tscn`** (`godot --headless res://tests/test_band_depth.tscn`), not `--script`, because `BandGenerator` needs the `EventBus`/`RNG` autoloads (unavailable under `--script`). · Harness mechanics; mirrors the existing B2 determinism harness. Contradicts the literal DoD wording. · **Rec: Reviewed (fold the autoload-needing tests' run command into `M1_As_Built.md`).**
- `[2026-06-17] B3/depth` — `compute_return_distance` implemented as a real reverse BFS (not the `= depth_index` shortcut); `DepthCurve` authored near-linear value (1.0→1.8), stepped tier threshold, ~flat density. · Pre-authorized in the brief; matches the resolved recommendations. · **Rec: Reviewed.**
