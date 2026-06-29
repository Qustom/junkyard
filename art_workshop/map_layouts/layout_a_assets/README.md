# Layout A — Placeholder Assets (PixelLab-generated)

Placeholder pixel art for **Layout A (Vertical Spine)**, generated from
[`../staging_area_layout_a_dressed.md`](../staging_area_layout_a_dressed.md) via the PixelLab API.
**Exploratory placeholders, not shippable art** — consistent with the rest of `art_workshop/`.

- **Style:** 16-bit SNES pixel art, warm rust-brown / oily-gray Band 0 palette, golden hour.
- **Scale baseline:** **1 ground tile = 32×32 px.** Objects are sized in 32px multiples relative to
  that baseline (a 64×64 prop ≈ a 2×2 footprint, a 128×96 vehicle ≈ 4×3, etc.).
- **Views:** ground = flat `top-down` (so tiles seam cleanly); objects = `high top-down`.
- Contact sheets: [`_preview_ground.png`](_preview_ground.png), [`_preview_objects.png`](_preview_objects.png).

---

## 1 · Ground tiles — `ground/` (all 32×32 px)

One `create_tiles_pro` sheet (square_topdown, 32px) produced **16 variations** covering the 5 Layout-A
ground materials. Map each glyph in the layout to its tile(s):

| Layout glyph | Material | Tile files |
|---|---|---|
| `=` | cracked **asphalt** + faded yellow paint | `ground_tile_00`, `ground_tile_08` |
| `.` | packed **dirt** / hardpan | `ground_tile_05`, `ground_tile_13` |
| `░` | dirt **+ loose litter** (cans, offcuts) | `ground_tile_14`, `ground_tile_15` |
| `~` | impassable **scrap-metal wall** | `ground_tile_02`, `ground_tile_06`, `ground_tile_10` |
| `▓` | worn **plank floor** (shack interior) | `ground_tile_01`, `ground_tile_03`, `ground_tile_07`, `ground_tile_09`, `ground_tile_11` |
| — | bonus **concrete / gravel** (apron, optional) | `ground_tile_04`, `ground_tile_12` |

> The extra variations are usable as natural-noise alternates so a tiled floor doesn't visibly repeat.

## 2 · Objects — `objects/` (transparent PNG, size = footprint guide)

### Functional (interactable)
| File | Size px | Layout glyph / role |
|---|---|---|
| `shack_door` | 64×64 | `D` — Bellweather office (rendered as the lit shack) |
| `workbench` | 64×48 | `T` — repair/recipes bench |
| `sort_table` | 64×48 | `T` — sort / sell table |
| `dive_gate` | 128×96 | `╬╬` — fenced junkyard dive gate + keep-out sign |
| `portal_glow` | 64×64 | `P` — cold-violet portal bloom (FX, past the gate) |

### Dressing (`o` scatter pool)
| File | Size px | | File | Size px |
|---|---|---|---|---|
| `tire_stack` | 48×48 | | `bathtub` | 64×48 |
| `oil_drums` | 48×48 | | `signpost` | 48×64 |
| `car_on_blocks` | 128×96 | | `wheelbarrow` | 64×48 |
| `truck_cab` | 96×96 | | `cable_spool` | 48×48 |
| `freezer` | 48×64 | | `pallet_cans` | 48×48 |
| `propane_tank` | 32×48 | | `potted_plant` | 32×48 |
| `folding_chair` | 32×48 | | `chalkboard` | 48×48 |
| `dog_bowl` | 32×32 | | | |

---

## Regenerating / notes

- Generated 2026-06-28. PixelLab map objects auto-delete server-side after 8 hours; these PNGs are the
  saved copies.
- Objects were generated standalone (transparent bg) with a shared palette prompt for cohesion. For
  tighter style-matching to a final scene, re-run `create_map_object` with a `background_image` +
  inpainting against an assembled map.
- `_preview_*.png` are local contact sheets (scaled-up, NEAREST) — not game assets.
