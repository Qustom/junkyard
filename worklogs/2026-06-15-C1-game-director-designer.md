# Worklog — C1 Junk as Resource

- **Date:** 2026-06-15
- **Subagent:** game-director-designer
- **Milestone:** M1
- **Branch:** game-director-designer/C1-junk-resource
- **Commit:** e32e286e195d93071209fdd666219d2f711f68f8

## What changed
Built the content-data backbone for M1 junk: a `JunkItem` Resource class (pure
data container + `value_per_slot()` helper), a `JunkCatalog` Resource (authored
spawn pool with index-aligned weights), 8 authored junk `.tres` spanning a 40x
value curve, the `junk_catalog.tres` instance referencing all 8, and a headless
data check that asserts the catalog loads with 8 items and the required value
spread. New junk is now authorable as a `.tres` with no code change.

## Files touched
- `data/junk/junk_item.gd` — `class_name JunkItem`; typed/`@export`ed schema (id, display_name, slot_size 1..9, grid_footprint, containment_flags, base_sell_value, greybox_color, greybox_shape) + `value_per_slot()`. GreyboxShape + ContainmentFlag enums.
- `data/junk/junk_catalog.gd` — `class_name JunkCatalog`; `items: Array[JunkItem]` + index-aligned `spawn_weights: PackedFloat32Array`.
- `data/junk/items/junk_scrap_bolt.tres` — floor item, val 3.
- `data/junk/items/junk_cable_coil.tres` — val 8.
- `data/junk/items/junk_copper_pipe.tres` — val 15.
- `data/junk/items/junk_hubcap.tres` — val 20.
- `data/junk/items/junk_circuit_board.tres` — val 45, tiny (1 slot) = greedy value-per-slot pick (45/slot).
- `data/junk/items/junk_car_battery.tres` — val 55.
- `data/junk/items/junk_radiator.tres` — val 80.
- `data/junk/items/junk_engine_block.tres` — ceiling, val 120, bulky (6 slots).
- `data/junk/junk_catalog.tres` — JunkCatalog referencing all 8, weights `(40,30,18,14,4,8,5,2)`.
- `tools/check_junk_catalog.gd` — headless validation gate (asserts 8 items, aligned weights, unique non-empty ids, positive values, >=30x spread).

## Value spread (authored set)
| id | base_sell_value | slot_size | value_per_slot |
|---|---|---|---|
| junk_scrap_bolt | 3 | 1 | 3.00 |
| junk_cable_coil | 8 | 1 | 8.00 |
| junk_copper_pipe | 15 | 2 | 7.50 |
| junk_hubcap | 20 | 2 | 10.00 |
| junk_circuit_board | 45 | 1 | **45.00** (greedy pick) |
| junk_car_battery | 55 | 3 | 18.33 |
| junk_radiator | 80 | 4 | 20.00 |
| junk_engine_block | 120 | 6 | 20.00 (bulky ceiling) |

Floor 3 → ceiling 120 = **40x** spread. The value-per-slot tension is deliberate:
circuit_board (45/slot, 1 slot) vs engine_block (120 total but only 20/slot, 6 slots).

## Checks run
- [x] `godot --headless --import` clean (no parse errors; all 8 `.tres` + catalog parse and validate)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy`
- [x] `godot --headless --script res://tools/check_junk_catalog.gd` → `JUNK CATALOG OK` (8 items, aligned weights, 40x spread)
- [x] definition of done met: "New junk is authorable as a `.tres` with no code change; a meaningful range of sell values exists across the authored set (~40x floor-to-ceiling)." — confirmed: adding junk = duplicate a `.tres`, edit fields, add to catalog; spread is exactly 40x.

## Design deviations
On-spec overall. Notes:
- **id convention chosen:** `junk_`-prefixed flat snake_case where the id matches the
  filename stem (file `junk_engine_block.tres`, id `&"junk_engine_block"`). Picked the
  prefixed form (not bare `engine_block`) per the spec's recommendation to reserve a
  one-word category namespace now, avoiding a save-breaking migration later. Ids are
  unique and must never be renamed (saves/telemetry key off them).
- **slot_size for engine_block:** authored as 6 (spec sketch showed 4). 6 makes the
  bulky-ceiling carry choice bite harder and pins value_per_slot at 20 (equal to
  radiator), sharpening the "is the engine block ever worth it vs two radiators"
  decision. grid_footprint 3x3 matches. Minor tuning call, easily reverted in playtest.
- **grid_footprint** authored on every item as advisory forward-compat metadata
  (D1 lands simple-count for M1, so `slot_size` is the live field). Per spec recommendation.
- **Catalog references items by path, not uid:** the authored `.tres` files have no
  embedded `uid=`, so the catalog uses path-based `ext_resource` (valid + stable in
  Godot 4). Functionally equivalent; if uids are wanted later, open each `.tres` in the
  editor once to let Godot stamp a uid and update the catalog refs.
- **Greybox encoded in data** (greybox_color + greybox_shape per item), not as art
  assets — so NO art-agent / PixelLab dispatch was needed. On-spec (C2 pickup + D2 UI
  draw the colored shape from these fields).

## Handoffs / follow-ups
- **`Item` vs `JunkItem` overlap (reconcile post-M1):** `data/item.gd` (`class_name Item`)
  is the pre-existing generic content schema and overlaps JunkItem (id, display_name,
  slot_size, base_value vs base_sell_value, needs_containment vs containment_flags,
  origin_band). Per the C1 brief I deliberately did NOT modify or reuse `Item`; JunkItem
  is the M1 junk-specific Resource. The sample `data/items/sample_junk.tres` is an `Item`
  and is unrelated to this catalog. Recommend a post-M1 task to decide whether JunkItem
  becomes the canonical junk schema (and Item is retired / repurposed for non-junk
  content) or the two merge. Flagged for the human Director.
- **D1 (inventory)** consumes `slot_size`; **C2 (pickup)** + **D2 (UI)** consume
  `greybox_color`/`greybox_shape`/`base_sell_value`/`value_per_slot()`; **B2 (generator)**
  consumes `junk_catalog.tres` `items` + `spawn_weights`.
- **Spawn weights** are placeholder rarity (commoner cheap junk, rarer rich junk) and
  should be tuned against the economy model before M3.
