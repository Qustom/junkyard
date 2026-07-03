# G4 findings — M1.8 (Hub Art Dressing) — close-out record

**Date:** 2026-07-02 · **Verdict: CLOSE M1.8 → proceed to M1.9** (Director).

## How this gate ran

M1.8 was an art-only iteration (loop behaviour byte-identical throughout: all-off fp `e943ac9c8bc1` +
89/89 held at every step; no save change; portal/shop contracts invariant). The gate ran non-standard:
instead of one HG1 build → playtest → HG2 → HG3 pass, the Director reviewed successive published
builds/previews and directed two in-flight re-dress iterations:

- **Wave 1 (H0+H1)** — Layout-A vertical-spine dressing (16 framed tiles + 20 props). Published
  `m1-20260629-9d613ed` (HG1). Director flagged: per-tile black borders, misaligned tiles, wrong
  object angles.
- **H2 re-dress (2026-07-01)** — seamless PixelLab corner-Wang tilesets painted by a vertex-map
  `hub_ground.gd` (720 cells), 6 props regenerated angle-consistent, front-facade shack, south fence,
  y-sort by base. Republished `m1-20260702-2457bc2`.
- **H4 iso re-dress (2026-07-02)** — Director-directed 45° isometric pivot: `hub_ground_iso.tres`
  (48 PixelLab iso tiles, DIAMOND_DOWN 64×32), RNG-free zone painter (963 cells), dressing props
  removed (shop + dive portal kept). H2's top-down dressing kept in-repo as a one-swap revert path.
  Published `m1-20260702-3faeed0`.

**The formal HG2 readability/telemetry analysis was not run** — the Director short-circuited the gate
by direct review (2026-07-02, in-session) and closed the milestone. Recorded here in lieu of an HG2
artifact.

## Verdict detail (Director, 2026-07-02)

1. **M1.8 is closed.** The hub's current dressing is the **H4 45° isometric look**; the iso-vs-top-down
   question is settled *for now* by retention (H2 top-down stays as the revert path). A proper felt
   read of the iso hub arrives free with the M1.9 SG1 playtest build.
2. **All 17 deviations dispositioned** (Director reviewed 2026-07-02): **15 Reviewed, 2 Addressed**
   (PLAYERTAB per-action lock knobs; H2 front-facade shack). Reapplied + archived to
   `design/DESIGN_DEVIATIONS_HISTORY.md` §"M1.8 close-out". Reapply targets: the N1 as-built amendment
   (`design/M1_7_Tasks/N1_player_visual_state_machine.md`), the dressed-layout doc as-built block
   (`art_workshop/map_layouts/staging_area_layout_a_dressed.md`), the M1.8 breakdown object-count fix.
3. **Next version = M1.9** (already authored + locked, Director-directed — not an M1.8 art iterate).

## Watch-items carried forward (non-blocking, no tasks filed)

- **Iso prop re-dress:** the kept shack/gate/bench sprites are H2 front-facing art on an iso ground —
  acknowledged placeholder mismatch. Becomes a task only if the iso look survives the M1.9 gate.
- **Bounds read:** H4's grass surround replaced the scrap-wall ring + south street; colliders unchanged
  but the perimeter reads as a dirt→grass seam. Revisit a street/entrance cue + harder wall read with
  the next hub art pass (pairs with the S8 second portal, which ships in M1.9).
- **H3 street-threshold prop** stays deferred (Director-gated PixelLab credits; no functional street
  exit exists).
- **Board note:** M1.8's H/HG items were never created on GitHub Projects (same historical drift
  flagged 2026-06-21; back-fill remains a Director call). M1.9's S0–SG3 items exist (created
  2026-07-02).

## Provenance

Breakdown `design/M1_8_Tasks/M1.8_Breakdown.md` · HG1 verify doc `design/M1_8_Tasks/HG1_playtest_build.md` ·
worklogs `worklogs/2026-06-28-H0H1-*`, `…-HG1-*`, `2026-07-01-H2-hub-redress-orchestrator.md`,
`2026-07-02-H4-hub-iso-orchestrator.md` · builds `m1-20260629-9d613ed` → `m1-20260702-3faeed0` ·
task archive `TASKS_COMPLETED.md` §M1.8.
