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
