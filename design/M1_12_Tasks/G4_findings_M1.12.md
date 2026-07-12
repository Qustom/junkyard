# M1.12 — Scaling Debt Paydown — Re-Gate Findings (VG2 analysis + VG3 verdict)

> **Gate type: REGRESSION gate** (D-RAT-1). M1.12 is a no-player-change version — its gate proves the
> game is *provably unchanged* and the debt is *provably down*, not "is it fun." The Director playtest
> was optional and (with CI/CD stopped for the LFS-bandwidth limit) the build was **not published** —
> so there is no new playtest telemetry or web build this cycle. VG2's usual telemetry/balance analysis
> therefore has no input; its role is subsumed by the VG1 regression matrix below. The verdict is the
> Director's (go / iterate / pivot); Claude assembles + recommends.

## The one thing this version had to prove — and did

*The scaling debt can be retired without moving the game.* **Proven.** Every recommendation R2–R10
landed as a behavior-preserving refactor or pure deletion; the four control layout fingerprints are
byte-identical to M1.11 and the full suite is green, with the single sanctioned behavioral change
(greybox hazard-spawn migration) proven equivalent within the Director-ratified ±15% bar.

## VG2 — Regression / equivalence analysis (the evidence)

**VG1 verify matrix (`main`@`2343bda`, local headless — CI is disabled): ALL GREEN — 67/67 scene tests
+ import + smoke + catalog, every run stderr-clean** (grepped for `SCRIPT ERROR|Invalid call|Nonexistent
function|Invalid access` — the silent-pass trap that VG1 caught on the first attempt).

- **Four control layout fps byte-identical to M1.0–M1.11:** all-off `e943ac9c8bc1` (`test_band_pipeline_parity`,
  `test_run_config` R0), `band_greybox` / `band_two` / `band_three` (profile tests). No layout fp moved
  anywhere in M1.12.
- **The sanctioned behavioral change (V3/V3b greybox hazard spawning), equivalence-proven + DR-3 signed
  off:** K5 (pingpong/bomb/spike) **exact 0.0% Δ** per type; R1 pursuer **within ±15%** (max +11.1% on
  the deep band — the licensed J3-density→even-spread fold). Both hazard frame-traces
  (`trace_pursuer_room`/`chase`) byte-identical; goldens re-pinned with the equivalence documented.
- **Save unchanged:** meta stays schema v4; v1/v2/v3→v4 migration fixtures green; V4's GameState split
  produced byte-identical meta bytes (sha256 match) with zero caller edits.
- **Determinism unchanged:** V6's `RNG.substream`/`substream_hashed` reproduces all 5 sub-streams
  byte-identically (incl. the new mandatory pockets golden).
- **Telemetry:** V2 left `opposition_event` as the single opposition source (the double-count risk is now
  structurally impossible); the 3 dropped payload fields were unconsumed (pre-ratified D-RAT-7). No new
  telemetry captured this cycle (no playtest) — nothing to balance-analyze.
- **Perf:** not measured — no web build was produced (no publish). V4's facade delegation + V5's helper
  indirection are trivial call-forwarding; no desktop-headless regression observed across the suite.

**Gate finding along the way (the gate working):** VG1's stderr-grep caught two tests
(`test_new_hazard_spawn`, `test_rg1_m13_verify`) that V3b left calling deleted APIs — they printed "OK"
and exited 0 while a `SCRIPT ERROR` silently aborted their assertions. Fixed test-only by VG1-fix
(`81f92b3`), audited for other stale refs (none live), both now verify for real. Logged + Addressed.

## The debt ledger (the version-defining measure — what came OUT)

| Task | R# | Debt retired |
|---|---|---|
| V1 | R2 | index-aligned `spawn_weights` array → by-id map; the silent-misalignment bug class eliminated; CI catalog check strengthened (id-coverage) + actually wired into CI |
| V2 | R3 | EventBus **60→54** signals; 6 dual-emit legacy signals + `_emit_family` (10-host fan-out) removed; ~60–75 LOC; telemetry double-count made structurally impossible |
| V3+V3b | R4 | **all 3 greybox spawn machines → the deck lane** (K5 fair-share + R1 pursuer machine both retired); config knobs **91→52**; ~−600 hazard-lane LOC; "exactly one way to add an opposition" delivered |
| V4 | R5 | GameState god-object **752→467** + `Economy` 251 + `QuotaLadder` 96; facade = zero caller edits; run/meta boundary now type-enforced |
| V5 | R6 | 4 verbatim interaction-owner copies → 1 `InteractionOwner` node |
| V6 | R7 | 5 hand-rolled salted sub-streams / 2 idioms → 1 discoverable `RNG` surface; boost-mix 2 copies → 1 |
| V7 | R8 | unbounded telemetry log → 2 MB size-cap rotation; `analyze_m1_2.py` argv |
| V8 | R9 | CI suite wall-clock now recorded (sharding follow-up filed) |
| V9 | R10 | 4 dead empty folders + the dead `run.sav` path removed |

**Headline: a net-negative LOC version** — hundreds of lines of duplication, god-object, dual-emit, and
bespoke spawn machinery removed, the game bit-identical where a fingerprint pins it. The seams are now
clean for M2 (crafting / upgrades / instability) to build on.

## Recommendation → **GO (advance to M2)**

The version's thesis is proven, the regression floor held, and the deferred R1 (CSV item catalog) is now
*unblocked and simpler* thanks to V1. No reason to iterate a no-player-change cleanup. **Rec: go → M2.**

## Watch-items / follow-ups to carry into M2

- **R1 — CSV-driven item catalog + importer** (the report's highest-leverage item, Director-deferred):
  now unblocked; V1's by-id map removed the fragile positional column the importer would have had to
  preserve. Schedule as the next content-authoring iteration.
- **Deferred test sharding** (V8/R9): CI records wall-clock now; file the sharding task when the curated
  CI subset exceeds ~5 min (fold logic-only scene tests into GdUnit4; job-level sharding, never
  concurrent headless processes against one project).
- **`rc.param_overrides` cross-band forward-flag** (V3): the def-id-keyed global lever applies to any
  band sharing K5/pursuer def ids — the intended re-tuning surface, but a landmine for any future band
  that decks those defs. Watch when adding bands in M2.
- **Knob-count terminology** (VG1 note): `test_run_config` (`to_flat_dict` → 51) vs `test_config_menu`
  (52/52) count differently; both pass. Add a reconciling comment (tiny hygiene, next touch).
- **CI/CD re-enable:** currently disabled for the LFS-bandwidth limit. Re-enable when bandwidth resets
  (`gh workflow enable "CI"` + `"nightly-playtest"`, uncomment the trigger blocks). Until then the gate
  is local headless verify (with the stderr-grep for `SCRIPT ERROR`).
- **QA verification lesson:** a `SCRIPT ERROR` can print OK + exit 0 — always grep stderr, not just the
  OK line, and scrub tests when deleting a production symbol.

## Verdict (Director)

**✅ GO → M2** — Director verdict, 2026-07-12. The scaling debt (R2–R10) is retired, the game is
provably unchanged (all control fps byte-identical, full suite green), the debt ledger is net-negative
LOC, and the seams are clean for M2 (crafting / upgrades / instability). M1.12 CLOSED. The deferred
**R1 (CSV item catalog + importer)** is now unblocked + simpler (V1's by-id map removed the fragile
positional column) — the natural next content-authoring iteration when M2 wants it.
