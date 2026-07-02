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

*Last close-out: **M1.6 Wave 2** (2026-06-26) — 3 items all **Reviewed**: W2-F1 (m13 stale/pre-existing → FU3), W2-F2
(quota-MISS banner deferred to M3), L6-F1 (keyboard-only aim → FU4) — archived to `DESIGN_DEVIATIONS_HISTORY.md`.*
*Prior close-outs: **M1.5 Wave 2** (1 Reviewed), **M1.5 Wave 1** (1 Reviewed), **M1.4 Wave 5** (3 items), **Wave 3**
(1 Addressed), **Wave 2** (0), **Wave 1** (2 Reviewed + 1 Addressed) — all in `DESIGN_DEVIATIONS_HISTORY.md`.*

---

- **[2026-06-28] PLAYERTAB / player_visual.gd timing model** — N1's ratified shared lock knobs `lock_duration_cap_s` (0.4)
  + `fixed_lock_s` (0.18) were REPLACED by per-action `pickup_lock_s` (0.25) + `throw_lock_s` (0.30), so the new debug "Player"
  tab can tune pickup and throw timing separately. **Director-directed** ("make the pick / throw timing configurable" +
  "separate pickup & throw"). CLIP_DRIVEN (the shipped default) is byte-for-byte unchanged (caps ≥ clip lengths → non-binding);
  only non-default FIXED-mode durations differ (0.18 → 0.25/0.30). fp `e943ac9c8bc1` unmoved; 89-knob count held (controls are
  debug-only, outside MANIFEST). **Claude's recommendation: Addressed** (this IS the Director's directive — reapply to the N1
  as-built/design doc at close-out). · _Awaiting Director disposition at the next wave close-out._

- **[2026-06-28] M1.8 H1 / hub.tscn — shack rendered DOORWAY-ONLY (no open-roof interior).** The dressed-layout doc
  carried an open question "shack: open-roof room vs. lit-doorway only." H1 ships doorway-only: `shack_door` sprite +
  `workbench`/`sort_table` props beside it, NO visible plank-floor (`▓`) interior room (the Shop is already a separate UI
  scene, so an interior adds dressing for no behaviour gain on the first pass). Plank-floor tiles (01/03/07/09/11) are imported
  and in `hub_ground.tres`, so an open-roof follow-up is cheap. **Claude's recommendation: Reviewed** (matches the breakdown's
  Phase-2 recommendation; the HG3 gate can revisit). · _Awaiting Director disposition at the M1.8 wave close-out._
- **[2026-06-28] M1.8 H1 / hub.tscn — HubCamera.zoom 1.2 → 1.05** to frame the full vertical spine (street edge → north gate).
  Not a knob, just the hub camera (no RunConfig change; fp `e943ac9c8bc1` unmoved, 89/89 held). **Claude's recommendation:
  Reviewed** (render-time framing is a Director manual-confirm). · _Awaiting Director disposition._
- **[2026-06-28] M1.8 H1 / hub.tscn — wall visuals kept as re-tinted ColorRects (deep rust), not replaced by scrap-wall
  sprites.** The scrap-wall *ground* ring forms the border read; the dark wall ColorRects sit on it as the impassable mass,
  keeping each `StaticBody2D` collider + visual exactly paired (lowest bounding risk). **Claude's recommendation: Reviewed.**
  · _Awaiting Director disposition._
- **[2026-06-28] M1.8 H1 / hub.tscn — ~15 dressing props placed (breakdown said ~10–12).** Within the layout's "scatter
  without obvious repeats" intent; trivially trimmable if the Director finds it busy at the readability gate. Pure decoration,
  no new collision. **Claude's recommendation: Reviewed.** · _Awaiting Director disposition._
- **[2026-06-28] M1.8 H0 / asset count — README/breakdown say "24 object PNGs"; directory has 20** (16 ground + 20 objects).
  Copied all 20 actual objects; no asset missing for the dressing pass (the breakdown gap table's own "19 present" is
  consistent with ~20). Documentation count is stale, not a build gap. **Claude's recommendation: Reviewed** (fix the README
  count at close-out). · _Awaiting Director disposition._

- **[2026-07-01] M1.8 H2 / ground re-authored — 16 framed variant tiles → 3 PixelLab corner-Wang transition tilesets**
  (`asphalt↔dirt`, `dirt↔litter`, `dirt↔scrap`, chained off one shared dirt base tile). Director-directed ("black border in
  each tile / tiles not aligned"): the H0 tiles had baked-in vignette rings and clashing per-tile texture; the Wang sets give
  organic seamless seams. `hub_ground.gd` now paints a deterministic RNG-free **vertex map** (terrain at cell corners → Wang
  tile lookup), and the painted grid grew 24×16 → 36×20 (720 cells) so the 1152×648 camera view is filled with scrap/street
  instead of black backdrop. fp `e943ac9c8bc1` + 89/89 unmoved. **Claude's recommendation: Reviewed** (reapply to the layout
  doc + M1_As_Built at close-out). · _Awaiting Director disposition._
- **[2026-07-01] M1.8 H2 / tile palette — PixelLab output gradient-map retoned to Band-0.** Generated dirt ran hot
  red-orange and litter came out green-cyan; all three sheets were post-processed (warm hues → rust-brown/dusty-ochre ramp,
  cool litter hues → gray-rust) per the research-02 §6 grayscale+gradient-map pipeline. Retone script kept with the archived
  sources in `art_workshop/game_art/hub_redress/`. **Claude's recommendation: Reviewed.** · _Awaiting Director disposition._
- **[2026-07-01] M1.8 H2 / litter fringe — continuous north litter band → sparse hash-scattered patches.** The dressed
  layout wants the ground "grubbier and busier" toward the north; the generated litter texture reads as dark shrubbery in
  large contiguous masses, so H2 ships isolated 1-vertex patches (~2-cell organic blobs, never in the central lane). The
  "danger gradient" cue is carried by the scrap-wall junk rim instead. **Claude's recommendation: Reviewed** (revisit with
  litter *props* or a lighter debris texture if the HG3 gate wants the gradient stronger). · _Awaiting Director disposition._
- **[2026-07-01] M1.8 H2 / wall visuals — ColorRect wall masses REMOVED (supersedes the 2026-06-28 "wall visuals kept"
  entry above).** The dirt↔scrap Wang border now IS the wall visual (organic junk-pile rim). All four `StaticBody2D`
  colliders untouched — visuals and bounding are no longer paired 1:1, but the scrap band fully covers every collider
  footprint. **Claude's recommendation: Reviewed** (disposition together with the superseded entry). · _Awaiting Director
  disposition._
- **[2026-07-01] M1.8 H2 / shack — doorway-only → full front-facing building sprite, 176×144 (supersedes the 2026-06-28
  "doorway-only" entry above).** Director-directed ("objects don't look the proper angles"): the 64×64 corner-iso
  `shack_door` was smaller than the player; the new straight-on facade (warm windows, sign) restores building scale. Shop
  remains a separate UI scene — still no open-roof interior. Sign text garbled ("SALANGE") — placeholder-grade, cheap regen
  later. **Claude's recommendation: Addressed** (fold the front-facade shack into the dressed-layout doc; retire the
  open-roof open question or re-open it explicitly). · _Awaiting Director disposition._
- **[2026-07-01] M1.8 H2 / south street edge — NEW low chain-link fence line (5 `fence_strip` sprites) on the S wall
  collider.** Not in the H1 dressing; makes the invisible south bound read as the yard perimeter (the layout's "low
  fence/curb"). The `SS` street-exit gap stays unbuilt (H3 deferred, unchanged). **Claude's recommendation: Reviewed.**
  · _Awaiting Director disposition._
- **[2026-07-01] M1.8 H2 / object angles — 6 props regenerated for camera-angle consistency** (`dive_gate` front-on into
  the wall + glow beyond, `car_on_blocks`/`truck_cab` side-view, `freezer`, `cable_spool`, `signpost`); y-sort re-anchored
  to sprite BASE (position=feet + `offset`), fixing sort-by-center artifacts. 12 props kept as-is where the old angle
  already read fine. Old `ground_tile_*.png` left on disk (unreferenced; plank tiles reusable). **Claude's recommendation:
  Reviewed.** · _Awaiting Director disposition._

- **[2026-07-02] M1.8 H4 / hub ground — 45° ISOMETRIC pivot (supersedes the H2 top-down Wang ground for the playtest).**
  Director-directed (`/goal`): the floor is now a DIAMOND_DOWN iso TileMapLayer (`hub_ground_iso.tres`, 48 PixelLab 45°
  tiles — grass/dirt families, scrap variants, grass↔dirt edge transitions) painted by a rewritten RNG-free zone painter
  (963 cells, fills the camera view). H2's top-down tileset + atlases remain in-repo (one tile_set swap to revert).
  fp `e943ac9c8bc1` + 89/89 unmoved. **Claude's recommendation: the HG3 gate dispositions iso vs top-down as one call.**
  · _Awaiting Director disposition._
- **[2026-07-02] M1.8 H4 / props — ALL dressing props removed** (cars, freezer, drums, tire stack, fences, signpost,
  pride-spot set). Director-directed ("removing other objects, keeping the shop and the dive portal"). The kept
  shack/gate/bench sprites are H2 front-facing art on an iso ground — acknowledged placeholder mismatch pending the iso
  verdict. **Claude's recommendation: Reviewed** (iso prop re-dress is a follow-up task if iso wins). · _Awaiting
  Director disposition._
- **[2026-07-02] M1.8 H4 / layout — grass surround replaces BOTH the scrap-wall border ring and the south asphalt
  street.** The Layout-A "street edge" spawn band is gone in this pass (the brief's tile list was grass/dirt/scrap only).
  Wall colliders are unchanged but the bounds now read as a dirt→grass seam, not walls/fence. **Claude's recommendation:
  needs Director review** — does the iso look need a street/entrance cue and a harder "wall" read at the bounds?
  · _Awaiting Director disposition._
- **[2026-07-02] M1.8 H4 / tooling — the brief's "edit image API" transitions were unachievable as specified:** (a) the
  inpaint mode (`create_map_object` + mask) regenerates whole objects, discarding frozen context (4 attempts; evidence
  `art_workshop/game_art/hub_iso/inpaint_attempt_results.png`); (b) `create_tiles_pro` style mode matched palette but
  ignored the isometric shape (returned 32×32 squares). Shipped transitions are a shape-mode batch with per-edge prompts —
  same intent (AI-generated blends between our tile materials), different endpoint. **Claude's recommendation: Reviewed.**
  · _Awaiting Director disposition._
