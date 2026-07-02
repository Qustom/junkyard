# Worklog — H2 Hub Art Re-dress (M1.8, Director-directed iteration)

- **Date:** 2026-07-01
- **Agent:** orchestrator (Claude, direct — Director `/goal`-directed interactive iteration; PixelLab MCP driven inline)
- **Milestone:** M1.8 (post-HG1 iteration on the Wave-1 dressing, pre-HG3)
- **Branch:** art/hub-redress
- **Commit:** 08c65cbc9e08e59102917a807d02da55700489f6

## Director's brief (the `/goal`)

> "Not all the tiles are oriented or properly aligned; there is a black border in each tile
> which makes it look bad; it doesn't look correct in terms of how the player and the
> objects look (not the proper angles). Iterate and show a better version."

Diagnosis against the H0/H1 build confirmed all three: (1) the 16 `ground_tile_NN` PNGs
each had a baked-in dark vignette ring (border avg RGB ~22/19/22 vs interior ~89/63/37) so
the floor read as a grid of framed squares; (2) variant tiles clashed (rut directions,
hues, one plank-floor look-alike) because they were independent generations, not a
tileable set; (3) several props were drawn at incompatible camera angles (dive gate flat
front-on, cars near-isometric, shack a tiny corner-iso building smaller than the player).

## What changed

**Ground — seamless corner-Wang tilesets (PixelLab `create_topdown_tileset`):**
- Three 16-tile Wang transition sets, chained off one shared dirt base tile so their dirt
  is pixel-identical: `asphalt↔dirt`, `dirt↔litter`, `dirt↔scrap-wall`. Lineless, 32px,
  high top-down. Generated palette ran hot orange (dirt) / green-cyan (litter), so all
  three sheets were post-processed with a gradient-map retone to the Band-0 rust-brown /
  dusty-ochre ramp (research 02 §6 pipeline) before atlas assembly.
- Atlases assembled 4×4 in Wang-index order (idx = NW·8+NE·4+SW·2+SE, bit = corner is the
  set's upper material) → `Game/art/hub/ground2/{asphalt_dirt,dirt_litter,dirt_scrap}.png`.
  Sources + retoned sheets + metadata archived to `art_workshop/game_art/hub_redress/`.
- `hub_ground.tres` rewritten: 3 atlas sources (ids 0/1/2), same resource path + uid.
- `hub_ground.gd` rewritten: terrain is now defined at cell **vertices** (deterministic,
  RNG-free, same hash discipline as before) and each cell picks the Wang tile matching its
  4 corners — every material seam gets an organic seamless transition. Painted grid grew
  24×16 → **36×20** (720 cells) so the camera view is filled with scrap wall / street
  instead of black backdrop. Material rules keep incompatible pairs (asphalt+scrap etc.)
  a cell apart so every cell maps to exactly one atlas.

**Objects — angle-consistent regenerations (PixelLab `create_map_object`):**
- `dive_gate.png` — chain-link double gate between drum pillars, hazard sign, now reads
  as a gate set INTO the north wall (base overlaps the scrap-wall tiles; portal glow
  peeks over it from beyond).
- `shack.png` (NEW, 176×144) — straight-on front facade("SALANGE" sign garble noted),
  warm lit windows; replaces the 64×64 corner-iso `shack_door.png` that was smaller than
  the player. `shop.tscn` now shows Shack + workbench/sort-table flanking the door.
- `car_on_blocks.png`, `truck_cab.png` — regenerated as straight side-view-from-above
  (old ones were ~45° isometric).
- `freezer.png`, `cable_spool.png`, `signpost.png` — regenerated to match (the old
  signpost had a green grass base).
- `fence_strip.png` (NEW, 152px, edge-to-edge) — 5 strips along the south street-edge
  collider so the invisible S wall reads as a low perimeter fence.
- Kept as-is (already read fine): tire_stack, oil_drums, pallet_cans, bathtub,
  propane_tank, wheelbarrow, potted_plant, folding_chair, dog_bowl, chalkboard,
  workbench, sort_table, portal_glow.

**Scene wiring (`hub.tscn`, `shop.tscn`, `departure_portal.tscn`):**
- All prop sprites re-anchored: node position = content **base** (bottom-center) with a
  computed `Sprite2D.offset`, so y-sort now sorts by feet, not sprite center.
- Props decluttered: big silhouettes line the W/E walls, life-sim "pride spot" (plant,
  bowl, chair, chalkboard) on the shack apron, central spawn→shack→gate lane kept clear.
- The four flat wall ColorRect visuals are REMOVED — the scrap-wall tile border is the
  wall visual now. **All four `StaticBody2D` colliders untouched** (same shapes/positions).
- Zero behaviour change: portal/shop `Interactable` ids, collision shapes, `hub.gd` node
  paths, spawn, camera zoom (1.05) all intact.

## Files touched

- `Game/art/hub/ground2/*.png` (+3 atlases, NEW) · `Game/art/hub/objects/{dive_gate,
  car_on_blocks,truck_cab,freezer,cable_spool,signpost}.png` (replaced) ·
  `{shack,fence_strip}.png` (NEW)
- `Game/data/tilesets/hub_ground.tres` — 16 single-tile sources → 3 Wang atlas sources
- `Game/scenes/hub/hub_ground.gd` — vertex-map Wang painter (RNG-free, deterministic)
- `Game/scenes/hub/hub.tscn` — props re-layout, base-anchored offsets, wall visuals
  removed, 5 fence sprites
- `Game/scenes/hub/departure_portal.tscn` — gate into wall, glow beyond
- `Game/scenes/hub/shop.tscn` — Shack sprite, benches flank the door (ShopUI intact)
- `art_workshop/game_art/hub_redress/` — archived sources (tilesets + objects + metadata)
- Old `Game/art/hub/ground/ground_tile_*.png` left in place (unreferenced by the tileset
  now; plank tiles still available for an open-roof shack follow-up)

## Checks run

- [x] `godot --headless --path Game --import` → clean
- [x] smoke test → `SMOKE OK`, exit 0 (re-run after final scene edits)
- [x] fingerprint gate → `R0 OK`, all-off fp **`e943ac9c8bc1` unmoved** (hub is meta-only)
- [x] knob gate → `CONFIG MENU OK — 89/89` (no knob added)
- [x] hub contract check (throwaway SceneTree script, frame-waited) → `HUB CONTRACT OK —
  cells=720 shapes=4`; portal/shop ids, wall colliders, ShopUI, all sprites resolve
- [x] preview composite rendered from the same vertex-map algorithm + final prop
  positions (`hub_after2.png`, shared with the Director)

## RENDER-TIME — Director manual-confirm

The on-screen look is the point of this task and is untestable headless: seam quality at
asphalt→dirt and wall bases, litter patch read (debris vs shrub), shack/gate scale vs the
player, fence line, golden-hour hold. Published to itch for the M1.8 playtest.

## Design deviations

Seven entries appended to `design/DESIGN_DEVIATIONS.md` (H2-D1 … H2-D7): Wang re-author +
grid overshoot, gradient-map retone, sparse-litter compromise, wall-visual removal,
full shack building (supersedes the Wave-1 "doorway-only" resolution), south fence line,
angle-consistency regenerations. All recommend **Reviewed** except the shack (recommend
**Addressed**: fold into the layout doc at close-out).

## Handoffs / follow-ups

- HG2/HG3 proceed against THIS build (fresh itch publish; changelog M1.8 block updated
  in place per the mid-version scope rule).
- Shack sign text garbled ("SALANGE") — cheap regen or a human-artist touch-up later.
- Scrap-wall interior repeats visibly on long runs; acceptable as dark mass, candidate
  for a variant pass if the Director flags it.
- Old ground tiles + H3 street exit unchanged/deferred as before.
