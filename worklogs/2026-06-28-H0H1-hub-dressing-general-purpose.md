# Worklog — H0 + H1 Hub Art Dressing (M1.8 Wave 1)

- **Date:** 2026-06-28
- **Subagent:** general-purpose (programmer + environment-artist hat)
- **Milestone:** M1.8
- **Branch:** m1.8/hub-dressing
- **Commits:**
  - **H0:** `33f67d5b03b477166456169f669b42d89b6872fb` — hub asset import + ground TileSet
  - **H1:** `7cdf47fd0a7c2de6bfc14dd2acc4ce3e68271c0d` — dress hub.tscn (Layout-A vertical spine)

## What changed

Re-skinned the greybox surface Hub to the dressed Layout-A vertical spine using the
PixelLab placeholder art, with **zero behaviour change** — every functional contract
(portal/shop Interactable ids + collision, hub.gd node paths, wall-bounding) is intact;
the loop is byte-identical. Two tasks on one branch:

- **H0** — copied 16 Layout-A ground tiles + 20 object PNGs from `art_workshop/` into
  `Game/art/hub/{ground,objects}/` (COPY, originals intact), imported (filter OFF inherited
  from project default), and built `Game/data/tilesets/hub_ground.tres` (32px-cell TileSet,
  16 atlas sources, no physics layers — walls own collision).
- **H1** — replaced the `Room/Floor` ColorRect with a `TileMapLayer` painted by a new
  RNG-FREE `hub_ground.gd` (3-band south→north spine: asphalt street edge → packed dirt
  yard → dirt-litter north fringe, scrap-wall border ring, central lane kept clean dirt);
  swapped the portal/shop greybox ColorRects for sprites (`dive_gate` + `portal_glow`;
  `shack_door` + `workbench`/`sort_table`); scattered 15 `o`-pool dressing sprites under a
  y-sorted `Props` node; enabled `y_sort_enabled` on the root so the player sorts among
  props/portal/shop correctly. Tightened `HubCamera.zoom` to 1.05 to frame the spine.

## Files touched

- `Game/art/hub/ground/*.png` (+`.import`) — 16 copied ground tiles (H0)
- `Game/art/hub/objects/*.png` (+`.import`) — 20 copied object PNGs (H0)
- `Game/data/tilesets/hub_ground.tres` — new 32px ground TileSet, 16 sources (H0)
- `Game/scenes/hub/hub_ground.gd` (+`.uid`) — new RNG-free deterministic floor paint (H1)
- `Game/scenes/hub/hub.tscn` — Floor→TileMapLayer, wall visuals re-tinted (colliders kept),
  Props scatter node, root y-sort, camera zoom (H1)
- `Game/scenes/hub/departure_portal.tscn` — Body/BodyInner ColorRects → dive_gate +
  portal_glow Sprite2Ds (Interactable/collision untouched) (H1)
- `Game/scenes/hub/shop.tscn` — Body/BodyInner ColorRects → shack_door + workbench +
  sort_table Sprite2Ds (Interactable/ShopUI untouched) (H1)

## Checks run

- [x] `godot --headless --path Game --import` → clean (no script/parse/import errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → `SMOKE OK`, exit 0
- [x] **Determinism gate — fingerprint:** `res://tests/test_run_config.tscn` → `R0 OK … all
      89 knobs … all-off baseline verified`, exit 0. All-off fp **`e943ac9c8bc1` unmoved**
      (hub is meta-only; touched no RunConfig/RNG/generator code).
- [x] **Determinism gate — knob count:** `res://tests/test_config_menu.tscn` → `CONFIG MENU
      OK — 89/89 knobs bound + reachable`, exit 0. **89/89 held** (M1.8 adds no knob).
- [x] **H0 TileSet load check:** throwaway `SceneTree` script → `tile_size=(32,32)
      source_count=16 usable_tiles=16`, exit 0.
- [x] **H1 hub contract check:** instantiated `hub.tscn` headless → `$Player`,
      `$PlayerSpawn`, `$HudLayer/QuotaNotice`/`HubLabel`/`ControlsLabel`, `$HubCamera` all
      resolve; portal Interactable id == `&"portal"`; shop Interactable id == `&"shop"`;
      4 wall collision shapes intact; ground painted 384 cells. Reported `H1 HUB CONTRACT
      OK`. (The two `Identifier not found: EventBus` lines are an artifact of the bare
      `--script SceneTree` harness not loading autoloads — NOT a scene error; the scene
      instantiated and every contract resolved. Autoload-dependent scripts compile fine when
      the hub runs in the real tree, as the smoke/verify SCENE tests above confirm.)
- [x] Assets present under `Game/art/hub/` AND still present in `art_workshop/` (16 ground +
      20 objects each side — copy, not move, verified).

## RENDER-TIME — Director manual-confirm (CANNOT be verified headless)

The on-screen *look* is untestable headless and is a Director manual-confirm item for the
HG2/HG3 gate:
- The spine reads south→north (asphalt street → dirt yard → litter/scrap north).
- The central spawn→shack→gate lane reads clear (highest floor/prop contrast).
- Functional props read as gate (`dive_gate`+glow) and shack (`shack_door`+benches) vs.
  the dressing scatter.
- Golden-hour read holds; framerate unaffected by the ~15-prop count.

## Design deviations

- **Shack open-question resolved to DOORWAY-ONLY** (the breakdown's Phase-2 recommendation):
  `shack_door` sprite + `workbench`/`sort_table` props beside it, NO visible plank-floor
  (`▓`) interior room. The Shop is a separate UI scene already, so an open-roof interior
  adds dressing work for no behaviour gain on the first pass. *Director confirm.* The
  plank-floor tiles (01/03/07/09/11) are imported and in `hub_ground.tres`, so an open-roof
  follow-up is cheap if the Director wants it. — logged to DESIGN_DEVIATIONS.md.
- **Camera zoom 1.2 → 1.05** to frame the full vertical spine (street edge → north gate) in
  view. Not a knob — just the hub camera. *Director confirm framing.* — logged.
- **Wall visual ColorRects kept (re-tinted deep rust), not replaced by scrap-wall sprites.**
  The scrap-wall *ground* tiles form the border ring; the dark wall ColorRects sit on top of
  it as the impassable mass. This keeps the four `StaticBody2D` colliders + visuals exactly
  paired (lowest risk to bounding) while still reading as scrap. — logged.
- **~15 dressing props placed** (breakdown said ~10–12). Within the layout's "scatter without
  obvious repeats" intent; trivially trimmable if the Director finds it busy. — logged.
- **README/breakdown say "24 object PNGs"; the directory has 20** (16 ground + 20 objects).
  Copied all 20 actual objects; no asset is missing for the dressing pass (the spec's own gap
  table says "19 present", consistent with ~20). — noted, not blocking.

## Handoffs / follow-ups

- Wave 2 (HG1 build+publish, HG2 readability, HG3 verdict) is unblocked once the Director
  plays the dressed hub.
- H3 (street-exit threshold PixelLab prop) stays Director-gated/deferred — the south edge
  currently uses asphalt tiles + a `signpost`; no functional street exit exists yet.
- Open for HG3: does placeholder-art fidelity help or distract vs. greybox; is an open-roof
  shack interior worth a follow-up (assets are already imported).
