# Worklog — C1b Junk schema consolidation (merge Item → JunkItem + add tier)

- **Date:** 2026-06-15
- **Subagent:** game-director-designer
- **Milestone:** M1
- **Branch:** game-director-designer/C1b-junk-schema
- **Commit:** feabf965e1407e1f57b6316f68c9454a5d589109

## What changed
Resolved human design decision #1 and unblocked B3. Merged the generic `Item`
Resource into the canonical `JunkItem` schema, folding `Item`'s genuinely useful
fields (`description`, `origin_band`) into `JunkItem` and retiring `data/item.gd`.
Added the NEW `tier: int` (1–5) field that B3's depth tier-threshold unlocks read,
and authored `tier` + `origin_band` + a one-line `description` across all 8 junk
`.tres`. Updated the M0 smoke test and the catalog checker so both still gate CI.

## Files touched
- `data/junk/junk_item.gd` — added `@export_multiline description`,
  `@export_enum(...) origin_band`, `@export_range(1,5) tier`; rewrote the header
  note to declare JunkItem the single canonical junk Resource (Item retired).
- `data/junk/items/*.tres` (all 8) — authored `tier`, `origin_band`, `description`.
- `data/item.gd` + `data/item.gd.uid` — **deleted** (Item retired).
- `data/items/sample_junk.tres` — **deleted** (was an `Item` instance; the curated
  `junk_catalog.tres` is the real content, so no JunkItem replacement was kept).
- `tools/ci_smoke_test.gd` — its "Resource loads as data" step loaded the deleted
  `sample_junk.tres`/`base_value`; repointed it to a real `JunkItem`
  (`junk_copper_pipe.tres`, asserts `base_sell_value == 15` and `tier == 2`).
- `tools/check_junk_catalog.gd` — added a per-item assert that `tier` is in 1–5.

## Tier mapping (tracks the value curve so "deeper unlocks higher tiers" reads honestly)
| item | base_sell_value | tier | origin_band |
|---|---|---|---|
| junk_scrap_bolt | 3 | 1 | surface |
| junk_cable_coil | 8 | 1 | surface |
| junk_copper_pipe | 15 | 2 | near |
| junk_hubcap | 20 | 2 | near |
| junk_circuit_board | 45 | 3 | temporal |
| junk_car_battery | 55 | 3 | temporal |
| junk_radiator | 80 | 4 | lateral |
| junk_engine_block | 120 | 5 | far |

Tiers are monotonic with value (ties at 1, 2, 3 grouped by value neighborhood),
matching the suggested mapping. `origin_band` was assigned to make the tier ladder
legible as a depth ladder (surface→far). The catalog's existing `spawn_weights`
were left untouched (out of this task's scope; still index-aligned, checker green).

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy`
- [x] `godot --headless --script res://tools/check_junk_catalog.gd` → `JUNK CATALOG OK`
- [x] grep confirms no live `class_name Item` / `res://data/item.gd` / `sample_junk` / `.base_value` references remain
- [x] grep confirms `tier = ` authored on all 8 items
- [x] Definition of done met: "Data loads in Godot and passes lint; Item is gone; tier authored on all 8 items."

## Design deviations
- **Item fields folded:** `description` and `origin_band` were carried into JunkItem
  as specified. `Item.base_value` is covered by `JunkItem.base_sell_value`;
  `Item.slot_size` by `JunkItem.slot_size`; `Item.needs_containment` by
  `JunkItem.containment_flags` (per brief, NOT re-added). No JunkItem field was
  removed and `value_per_slot()` is unchanged.
- **sample_junk.tres deleted (not converted):** per the brief's preference — the
  curated `junk_catalog.tres` is the real content; a one-off sample adds no value.
- **Smoke test repointed:** the M0 smoke test asserted on the deleted sample; it now
  loads a real catalog JunkItem and asserts `base_sell_value` + the new `tier`. This
  keeps the "Resource loads as data" guarantee intact rather than dropping it.
- Otherwise on-spec. Nothing here needs the Director's sign-off beyond decision #1,
  which is already ratified.

## Handoffs / follow-ups
- **B3** can now read `JunkItem.tier` (1–5) for depth tier-threshold unlocks and
  `origin_band` for flavor; the value↔tier ladder is honest and monotonic.
- If a future task needs a generic non-junk `Item` (recipes/upgrades/enemies were
  noted in the old `Item` docstring), it should be authored as its own purpose-built
  Resource — do not resurrect the merged `Item`.
- `spawn_weights` tuning remains C1/B-side content work, untouched here.
