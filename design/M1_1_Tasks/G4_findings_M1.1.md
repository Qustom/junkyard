# G4 findings — M1.1 re-gate (RG2 analysis + RG3 recommendation)

**Date:** 2026-06-19 · **Build:** M1.1 (`c4c71b8` + CFG input fix `1ac32c2`) · **Tester:** Director (solo)
**Telemetry:** `playtest_data/M1.1/run_log_2026-06-19.jsonl` (1225 rows; 57 M1.1 runs after excluding 9 stale M1.0 rows + 4 unpaired)
**Mirrors:** `design/M1_Tasks/G4_findings.md` (the M1.0 ITERATE verdict that spawned M1.1).

> **Verdict is the Director's.** This doc assembles the evidence + Claude's recommendation. The Director records the
> final go / iterate / pivot. **Claude's recommendation: ITERATE → M1.2** (the build has fixable bugs + missing
> configurability that block a fair fun-read; the cost axis is *partially* working but not yet legible).

---

## 1. What the telemetry shows (RG2)

**Config coverage (57 M1.1 runs):** 38 baseline (all-off) · 8 R1 · 7 R3 · 3 R2 · 10 R4(±fog). Good per-opposition isolation.

**End-cause distribution (this is the headline — compare to M1.0's 30 extract / 2 death / 0 timeout):**

| Config | n | extract | death | timeout | run-len (median, nonzero) | max depth seen |
|---|---|---|---|---|---|---|
| baseline (all-off) | 38 | 35 | 3* | 0 | 16.9 s | 11 |
| R1 only | 8 | 4 | 4* | 0 | 9.1 s | 11 |
| R2 only | 3 | 1 | 0 | **2** | 11.5 s | 11 |
| R3 only | 7 | 4 | 0 | **3** | 5.2 s | 7 |
| R4 (±fog) | 10 | 7 | 3* | 0 | 14.5 s | 11 |

\* every `death` is from the **debug-kill key (K)**, NOT a hazard — see §2.

**The cost axis IS partially working:** R2 (egress toll) and R3 (exposure) **produced the `timeout` losses M1.0 never had** (5 timeouts total) and shortened runs (R3 median 5.2 s vs baseline 16.9 s). So the *mechanics* of R2/R3 bite. But the outcome spread is thin and **R1/R4 added no genuine deaths**, because of the bugs below.

**Depth works:** within-band depth reaches **up to 11** (BUG2 is fine) — the band is a ~12-piece spine, not "5–10 rooms"; the *perception* of fewer/smaller rooms comes from the tiny piece size (128×64 px) making the whole band feel cramped and fast to clear (median run 16.9 s baseline).

---

## 2. Issues found (Director feedback + telemetry, triaged)

| # | Issue (Director) | Telemetry / root cause | Recommended fix | Size |
|---|---|---|---|---|
| **I1** | **Levels too small / few rooms; want configurable room count + size** (most important) | Pieces are fixed 8×4-cell scenes (128×64 px); `target_piece_count` is hardcoded in the `BandGenConfig` `.tres` — neither is a knob. Depth reaches 11, so count≈12 but each room is tiny. | New `RunConfig` knobs: **room count** (expose `target_piece_count`) + **room size** (cell-scale multiplier and/or larger authored pieces). Surface in CFG. Generator + data work. | **L** |
| **I2** | **Enemy too large, gets stuck in halls, doesn't kill when kill enabled** | `hazard_awoke=7` but **`hazard_caught=0`** — it never reaches catch radius. Too big + `move_and_slide` wall-collision in narrow 4-cell halls → it can't close distance; wakes at depth 0–1 (instant, tiny levels). Kill *routing* is fine; the catch never fires. | Shrink the hazard; improve closing (e.g. ignore wall-stick / smaller body / larger or speed-scaled catch radius); re-tune awaken threshold for real depths. | **M** |
| **I3** | **Exposure (R3) + walkback (R2) have no visual cues** | Mechanically firing (5 timeouts) but invisible: R3's HUD bar isn't legible/telegraphed; R2's clock-toll has no dedicated cue (clock just drops). | R3: prominent exposure bar + threshold ticks + penalty flash. R2: a "toll" pulse on the clock + a retreat-cost indicator. UI work. | **M** |
| **I4** | **Vision still shows darkened areas; fog + lost_proxy unclear** | Greybox `CanvasModulate` + `PointLight2D` only *dims* (doesn't occlude); fog-of-war + `nav_lost_proxy` have no on-screen meaning. | Strengthen occlusion (hide, not dim, beyond radius); make fog memory + a "lost" cue visible; document/telegraph `lost_proxy_threshold`. | **M** |
| **I5** | *(found in data)* `duration_s = 0` on ~23 current-build runs (correlated with all-off/fast extract); build SHA frozen at `852b6e2` (BuildVersion not tracking HEAD) | BUG1 regressed on a run subset; `systems/version.gd` returns a stale SHA → can't separate builds by SHA (only by date). | Investigate the `duration_s=0` path; make BuildVersion read the real HEAD SHA. Telemetry hygiene for the next gate. | **S** |

---

## 3. Recommendation (RG3)

**ITERATE → M1.2.** The M1.1 build proved the cost axis *can* shift outcomes (R2/R3 timeouts — the missing M1.0 axis now exists), but **I1–I4 block a fair fun-read**: levels are too cramped to make depth feel like a journey, the most visceral opposition (R1 hazard) never actually catches, and the attritional oppositions (R2/R3/R4) fire invisibly. Fix the build, re-playtest, then take the fun verdict.

**Proposed M1.2 workstreams** (priority order, Director confirms): **I1 levels** (the headline) → **I2 hazard** → **I3/I4 legibility (cues + vision)** → **I5 telemetry hygiene**. This reuses the M1.1 template: same `RunConfig`+CFG+telemetry spine, all-off still = baseline control, re-gate the same way.

*Director: record the verdict + the M1.2 scope/priority below.*
