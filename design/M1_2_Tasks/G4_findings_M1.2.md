# G4 findings — M1.2 re-gate (RG2 analysis + RG3 recommendation)

**Date:** 2026-06-19 · **Build:** M1.2 (`ba745e1`, real HEAD SHA — I5 fix working) · **Tester:** Director (solo)
**Telemetry:** `playtest_data/M1.2/run_log_2026-06-19.jsonl` (11,410 rows, CUMULATIVE M1.0/M1.1/M1.2)
**Analysis helper:** `tools/playtest/analyze_m1_2.py`
**Mirrors:** `design/M1_1_Tasks/G4_findings_M1.1.md` (the M1.1 ITERATE verdict that spawned M1.2).

> **Verdict is the Director's.** This doc assembles the evidence + Claude's recommendation. The Director records the
> final go / iterate / pivot. **Claude's recommendation: ITERATE → M1.3** — the M1.2 fixes *landed in the data*
> (longer runs, real hazard deaths, real durations), and the Director's own feedback names concrete, scoped next
> steps (defaults, enemy spread, hallway length, per-room hazards, depth-counter bug). The build is now legible
> enough to take a real fun-read, but the Director's qualitative list is exactly an ITERATE list, not a "go" or a "pivot."

---

## 1. Cohort partition (RG2)

The log is cumulative; the Director did **not** set `build_tag` this round, so cohorts are segmented by **actual build
SHA** (`run_started.data.build`) and, within M1.2, by the **real `run_config` knob values** in the snapshot.

| Build SHA | Cohort | Runs (started) | Ended | Abandoned (no `run_ended`) |
|---|---|---|---|---|
| `m1-20260619-ba745e1` | **M1.2** (real HEAD; carries new `lvl_*` + `r1_catch_radius_per_depth` knobs) | 33 | 32 | 1 (**3%**) |
| `m1-20260619-852b6e2` | M1.1 (stale-SHA) | 60 | 57 | 3 (5%) |
| `m1-20260618-852b6e2` | M1.1 (stale-SHA, prior day) | 10 | 9 | 1 (10%) |
| — | **M1.0 control** (subset: `all_oppositions_disabled()` AND `lvl` default, any build) | 7 | 6 | 1 |

- **M1.2 = 33 runs, M1.1 = 70 runs** (matches the brief). Abandonment is low everywhere (3–10%), well under the
  ~25% gate ceiling — no abandonment problem in any cohort.
- The M1.2 cohort is cleanly identifiable **by config alone**: all 33 ba745e1 runs carry the new `lvl_enabled` /
  `lvl_size_mult` / `lvl_room_count` knobs (I1) and `r1_catch_radius_per_depth` (I2); no M1.1 run does.

### M1.2 config sweep (the distinct combinations the Director swept)

Grouped by the meaningful knobs (level size/count + which oppositions on):

| n | lvl | size_mult | room_count | oppositions on | median dur | depth (med/max) | end-cause mix |
|---|---|---|---|---|---|---|---|
| 7 | on | 4.0 | 25 | R1, R4 | 32.8 s | 5 / 9 | 4 death, 2 extract, 1 timeout |
| 6 | on | 4.0 | 19 | R1, R4 | 18.8 s | 1.5 / 5 | 3 extract, 3 death |
| 6 | on | 4.0 | 19 | R1, R2, R3, R4 | 20.0 s | 2.5 / 5 | 4 death, 2 extract |
| 4 | on | 4.0 | 19 | R4 | 12.9 s | 1 / 5 | 3 extract, 1 death |
| 3 | on | 10.0 | 25 | R1, R4 | 60.0 s | 4 / 6 | 2 timeout (+1 abandoned) |
| 2 | off | 1.0 | (def) | — (control) | 17.5 s | 11 / 11 | 2 extract |
| 2 | on | 4.0 | 19 | R1, R2, R4 | 25.8 s | 3 / 3 | 1 death, 1 extract |
| 1 | on | 2.0 | 12 | — | 37.5 s | 11 / 11 | 1 extract |
| 1 | on | 2.0 | 12 | R4 | 28.6 s | 7 / 7 | 1 extract |
| 1 | on | 4.0 | 25 | R1, R2, R3, R4 | 60.0 s | 17 / 17 | 1 timeout |

Good coverage of the new size/count axis (off/2×/4×/10×) crossed with opposition stacks. Note R4 is on in almost
every M1.2 run (30 of 33) — but inert (see §3, R4).

---

## 2. Distributions per config — side-by-side vs M1.0 / M1.1

**Aggregate, all configs pooled per cohort:**

| Cohort | n (ended) | extract | death | timeout | dur median (all) | dur median (nonzero) | dur=0 count | depth median | depth max |
|---|---|---|---|---|---|---|---|---|---|
| **M1.0 control** (all-off + lvl default) | 6 | 5 | 1\* | 0 | 16.9 s | 16.9 s | 0/6 | 11 | 11 |
| **M1.1** (852b6e2, all configs) | 66 | 51 | 10\* | 5 | **2.1 s** | 12.4 s | **32/66** | 1 | 11 |
| **M1.2** (ba745e1, all configs) | 32 | 15 | **13** | 4 | **26.4 s** | 26.4 s | **0/32** | 3 | 17 |

\* M1.0/M1.1 deaths are the **debug-kill key (K)**, not a hazard (per the M1.1 findings). M1.2 deaths are *real
hazard catches* — see §3 I2.

**Headline reads:**

- **Run length is up ~1.5×.** M1.2 median (nonzero) 26.4 s vs M1.1 nonzero 12.4 s and M1.0 control 16.9 s. The
  M1.1 "all-config" median collapsed to 2.1 s only because half its rows had `duration_s = 0` (the I5 defect); on a
  like-for-like nonzero basis M1.2 runs are roughly **2× longer** than M1.1.
- **End-cause spread is genuinely three-way for the first time.** M1.2 = 47% extract / 41% death / 12% timeout.
  M1.0 was 83% extract / 17% (debug) death / 0% timeout. The push/cash-out tension now has all three failure modes
  *and* a real death threat in the mix.
- **Depth distribution split widened** (max 17 vs 11) — but note the depth *counter* is reporting two different
  things (see §3, depth-counter bug).

---

## 3. Did the M1.2 fixes land in the data? (per-fix read)

Event counts by cohort (from the helper):

| event | M1.0 ctrl | M1.1 | M1.2 |
|---|---|---|---|
| hazard_awoke | 0 | 7 | **73** |
| hazard_caught | 0 | **0** | **9503** |
| return_cost_incurred | 0 | 14 | 8 |
| exposure_crossed | 0 | 4 | **0** |
| exposure_penalty | 0 | 4 | **0** |
| nav_branch_taken | 0 | 162 | 201 |
| nav_lost_proxy | 0 | 115 | **0** |
| junk_lost | 0 | 9 | 14 |

### I5 — telemetry hygiene / real `duration_s` · **LANDED (clean)**
**0 of 32** ended M1.2 runs have `duration_s = 0` (M1.1 had 32/66). Build SHA is the real HEAD (`ba745e1`),
distinct from the stale `852b6e2`, so cohorts now separate by SHA as intended. Durations across the cohort are
real and plausible (10.8 s – 60.0 s). This fix is fully verified in the data.

### I1 — level size / count → fixes the "feels like a sprint" defect · **LANDED**
The M1.1 defect was a ~17 s sprint with tiny pieces. M1.2 exposes `lvl_size_mult` / `lvl_room_count`, and run length
scales clearly with size:

| lvl_size_mult | n | median dur | median depth | cause mix |
|---|---|---|---|---|
| baseline (off) | 2 | 17.5 s | 11 | 2 extract |
| 2.0 | 2 | 33.1 s | 9 | 2 extract |
| 4.0 | 26 | 25.1 s | 3 | 11 extract / 13 death / 2 timeout |
| 10.0 | 3 | 60.0 s | 4 | 3 timeout |

Bigger levels → longer runs. At size **10×** every run **times out at 60 s** without finishing — the big-room
configs the Director found "most fun" are the ones that turn the sprint into a real expedition. This directly
corroborates Director feedback #1 (these configs should be the defaults) and #3a (huge rooms feel good).

**"Long hallways are boring" corroboration (#3a):** `nav_branch_taken` averages ~6–7 junctions/run regardless of
size (size 2×: 7.0/run, 4×: 6.6/run, 10×: 5.3/run). Because junction *count* per run is roughly flat while run
*duration* grows with size, the extra time at larger sizes is spent **traversing longer corridors between the same
number of junctions** — i.e. dead corridor time, not extra meaningful decisions. The data supports the Director's
read that the added length is hallway, not choice. (A precise time-in-corridor metric isn't emitted yet — flag for
M1.3 telemetry: timestamp corridor entry/exit so this is directly measurable, not inferred.)

### I2 — hazard now actually catches → real deaths · **LANDED (with a telemetry-noise defect)**
M1.1 had `hazard_awoke=7` but **`hazard_caught=0`** (it never closed distance). M1.2: **all 25 R1-on runs wake the
hazard, 14 of them produce `hazard_caught`, and death is now the dominant end-cause (13 of 32).** The visceral
opposition finally bites — this is the single biggest behavioural change in the build.

**New defect found in the data:** `hazard_caught` fires **per physics frame while the bodies overlap**, not once
per catch — per-run counts run 85 → 2,199 events (total 9,503). It's a logging/edge-trigger bug (one catch should
emit one event), not a gameplay bug, but it pollutes any "catches per run" metric and bloats the log. *Triage:
sev-low, system = hazard catch signal / Telemetry edge-trigger. Recommend M1.3 fix: emit `hazard_caught` once on the
overlap transition, then debounce.* Also note one run (`r_f936dc`) logged 2,122 catches yet ended in **extract** —
consistent with `r1_catch_kills` semantics where a "catch" can be non-lethal; worth confirming the catch→death
routing is what's intended when kills are off (all M1.2 R1 runs had `r1_catch_kills=true`, so the extract there
means the player escaped the overlap before the kill resolved — re-check the kill latency).

### R2 — return / egress cost · **LANDED (working, modest)**
M1.2 emits 8 `return_cost_incurred` events across 4 of 9 R2-on runs, all `cost_kind=clock`, magnitudes 1.4–2.8 at
depths 1–4. The egress toll fires and debits the clock as designed (consistent with M1.1's behaviour). It's a
small, working bite — not yet a dominant pressure, but mechanically alive.

### R3 / BUG5 — exposure threshold crossings + tolls moving the meter · **DID NOT FIRE (config gap, not code)**
**0 `exposure_crossed` and 0 `exposure_penalty` in the entire M1.2 cohort**, despite R3 being enabled on 7 runs.
Root cause is in the **config, not the code**: every R3-on M1.2 run has `r3_threshold_levels = []` (empty). With no
threshold levels defined, the meter climbs (`base_climb_rate=2.9`, `rate_per_depth=3.0`) but there is no level to
*cross*, so no crossing/penalty event ever emits and BUG5's "tolls move the meter" cannot be observed. **We cannot
confirm I3-R3 or BUG5 from this data** — the experiment wasn't actually run. *Recommend: re-test R3 with non-empty
`r3_threshold_levels` (M1.1 used populated thresholds and got 4 crossings + 4 penalties), and consider a guard that
warns/no-ops when R3 is enabled with empty thresholds so this config trap can't silently invalidate a gate again.*

### R4 — nav branching + lost-proxy + fog · **PARTIALLY FIRED (branching yes, lost-proxy config-disabled)**
R4 branching works: 201 `nav_branch_taken` events across all 30 R4-on M1.2 runs. But **0 `nav_lost_proxy`** because
every R4-on M1.2 run has `r4_lost_proxy_threshold = 0.0` (disabled); M1.1 (threshold set) produced 115. Fog was on
in only 3 of 30 R4 runs. So R4's *branching* is verified; its *disorientation* signals (lost-proxy, fog) were
config-disabled this round and remain unverified in the M1.2 build.

### Depth counter (Director feedback #4) — **CONFIRMED BUGGY in the data**
`band_depth_reached.depth` maxes at **1** for M1.2 runs while the same runs report `run_ended.max_depth` of
**5 / 7 / 11 / 17**. Two different depth concepts are live: the `band_depth` the bottom-left HUD shows (stuck ~1)
vs. the `depth_index` the run actually traverses (and that `run_config` thresholds key off). This is the exact data
signature of the Director's "the bottom-left depth counter looks buggy" report. *Triage: sev-med (misleads the
player on their core progress signal), system = HUD depth readout / band-depth vs depth_index. Recommend M1.3:
point the HUD at `depth_index` (the value config + extraction logic use), or reconcile the two.*

### Economy sanity
M1.2 `currency_in` total = 2,408 (all `source=extract`); banked 2,408 vs lost 1,481 across the cohort — a ~62/38
banked/lost split, i.e. real risk is now on the table (M1.1 lost almost nothing because nothing caught the player).
No currency anomalies.

---

## 4. Recommendation (RG3)

**ITERATE → M1.3.** The M1.2 build cleared the M1.1 blockers that prevented a fair fun-read:

- **The fixes landed where they could:** I5 (real durations, real SHA) is clean; I1 (size/count) measurably turns
  the 17 s sprint into 25–60 s expeditions; I2 (hazard catch) finally produces real deaths and makes death the
  co-dominant outcome — the cost axis is now *visceral*, not just attritional. R2 fires. The end-cause distribution
  is genuinely three-way for the first time.
- **Two fixes couldn't be evaluated because the swept config disabled them**, not because the code failed: R3/BUG5
  (`r3_threshold_levels=[]` → 0 crossings) and R4 lost-proxy/fog (`r4_lost_proxy_threshold=0.0`, fog off on 27/30).
  These need a re-test with the knobs actually populated before any "go" on the legibility workstream.
- **Two real bugs surfaced in the data:** the depth-counter mismatch (#4, confirmed: HUD shows band_depth≈1 while
  runs reach depth_index 17) and a `hazard_caught` per-frame logging storm (up to 2,199 events/run).

The Director's qualitative feedback is itself a well-formed ITERATE list, and the data backs each item:

| # | Director feedback | Data corroboration | M1.3 implication |
|---|---|---|---|
| 1 | The swept configs were most fun → make them defaults | size 2–4× = longest non-timeout runs (25–37 s) with real death/extract spread | promote the size-4×/rc-19/R1-on stack to the `RunConfig` default (all-off control stays as the permanent baseline) |
| 2 | Enemies should be spread through the level, not one at a threshold | `r1_spawn_count` + single `r1_depth_threshold`; hazard wakes at depth 0–1 then chases | spawn N hazards across depths instead of one gate |
| 3a | Huge rooms good, long hallways boring → configurable hallway length | run length grows with size while junctions/run stay flat (~6–7) → extra time = corridor traversal | add a hallway-length knob; emit corridor-time telemetry to measure it directly |
| 3b | Want a hazard per room to fill huge empty rooms | big rooms (size 10×) time out at 60 s, depth only ~4 → lots of empty traversal | per-room hazard/loot density knob |
| 4 | Bottom-left depth counter looks buggy | **confirmed**: band_depth=1 vs max_depth up to 17 | point HUD at depth_index; reconcile the two depth concepts |
| 5 | (infra) push builds to itch via butler | n/a | producer/infra task, not gameplay |

**Why not "go":** the most-fun configs aren't yet defaults, two oppositions went untested, and the depth readout the
player relies on is wrong. **Why not "pivot":** nothing about the core loop is broken — push/cash-out tension is now
demonstrably present (three-way outcomes, real deaths, longer expeditions). The remaining work is tuning + two bug
fixes + a fair re-test of R3/R4, which is exactly a sub-version iteration.

**Proposed M1.3 scope** (Director confirms/orders): defaults promotion (#1) → enemy spread (#2) → hallway-length
knob + corridor telemetry (#3a) → per-room density (#3b) → depth-counter fix (#4) → `hazard_caught` debounce +
R3/R4 config-trap guards (telemetry hygiene) → itch/butler delivery (#5, infra). Reuse the M1.1/M1.2 template:
same `RunConfig` + CFG + config-marked telemetry, all-off still = the permanent baseline control, re-gate the same
way.

*Director: record the verdict + the M1.3 scope/priority below.*

---

## 5. RG3 verdict — Director-recorded (2026-06-19): **ITERATE → M1.3**

The Director playtested the RG1 build (33 runs, `ba745e1`) and returned a concrete improvement list; RG2 corroborates
each item. **Verdict: ITERATE.** Bump to **M1.3 (Legibility & Density)**, authored via the four-phase process, then re-gate.

**Director decisions folded in (drive the M1.3 task set):**

- **F1 — defaults.** Ship a **default play-preset** (Director's choice: keep the code-level all-off `RunConfig` default as the
  permanent telemetry+determinism control; the *game/CFG boots into* a separate named default preset). The preset = the
  most-fun stack **but with R2 and R3 OFF by default** (R1 hazard + R4 vision/maze ON, level scale ON ~19–25 rooms).
  *"Everything else is fine."*
- **F1 — bigger size slider.** The room-size multiplier range is too small. **`lvl_size_mult` ≥ 4.0 is the new floor** (4.0 =
  smallest), **max ≈ 40.0** (the Director found 40.0 good). Re-range the CFG slider (`RANGE_MULT`); the all-off control still
  uses `lvl_enabled=false` (size inert) so the determinism baseline (fp=e943ac9c8bc1) is untouched.
- **F2 — enemy spread.** Spawn multiple hazards distributed across depths, not one at a single `r1_depth_threshold`.
- **F3a — hallway length.** Add a configurable corridor/hallway-length knob (data corroborates "extra time = corridor
  traversal"); emit corridor-time telemetry to measure it.
- **F3b — per-room density.** A hazard/density-per-room knob to fill the emptiness of huge rooms (pairs with F2).
- **F4 — depth counter.** Fix the HUD to show the room `depth_index` (subscribe to `depth_changed`), not the band counter.
- **F5 — delivery.** Push each playtest build to **itch.io via butler** as an **HTML5 web build** (Director's choice — the
  itch page is browser/password-gated). Target `qusto/the-far-yard` (personal account). Needs butler + 4.6.3 web export
  templates + a web preset (none exist yet) + a push task. Infra, not gameplay.

**New issues RG2 surfaced (added to M1.3 scope):**
- **BUG6 — `hazard_caught` per-frame logging storm** (up to 2,199 events/run): the catch emits every physics frame instead
  of edge-triggered once. Telemetry-hygiene bug (pollutes the very logs the re-gate reads); fix to one-shot.
- **Config-trap guards** — R3 (`r3_threshold_levels=[]`) and R4-lost (`r4_lost_proxy_threshold=0.0`) were silently inert
  during the playtest, so BUG5/R3 and I4's lost-cue went **untested**. M1.3 must ship sane defaults in the play-preset AND/OR
  warn when an enabled opposition is config-disabled, so the M1.3 re-gate actually exercises them.

**M1.3 scope (ratified order):** defaults play-preset + bigger size slider (F1) · enemy spread (F2) · hallway-length knob +
corridor telemetry (F3a) · per-room density (F3b) · depth-counter fix (F4) · BUG6 hazard debounce + config-trap guards ·
itch/butler HTML5 delivery (F5). Authored via the four-phase process (`design/M1_3_Tasks/`), re-gated the same way.
