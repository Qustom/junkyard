# RG2 — Telemetry Analysis + M1.0 Comparison (Design / Plan)

**Task:** RG2 (M1.1 workstream (c), wave 3) · **Assignee:** qa-playtest-coordinator
**dependsOn:** RG1 (playtest build) + playtest data captured · **feeds:** RG3 (the re-gate verdict)
**Status:** DESIGN ONLY — this document plans the analysis. **No analysis code is written by this task yet.** Implementation happens after RG1 lands and playtest JSONL exists.

**Companion docs:** `M1.1_Breakdown.md` (§1 goal, §4 RG2, §6 wave-3), `G4_findings.md` (the M1.0 ITERATE numbers RG2 compares against), `M1_As_Built.md` §Telemetry (the JSONL row schema), `systems/telemetry/telemetry_schema.gd` (the canonical `EventType` constants + envelope).

---

## 1. Goal & design intent

M1.0's gate (G4) returned **ITERATE** for one structural reason: the loop has a **reward axis** (deeper = better junk) and **no cost axis**, so "push vs. extract" collapses into a single dominant strategy — *push to the end, fill the bag, walk back, extract.* The telemetry showed it bluntly: **30 extract / 2 death / 0 timeout** across 34 runs (the 2 deaths were debug-key, not gameplay).

M1.1 layers four configurable opposition systems (R1 pursuing hazard, R2 costlier return, R3 exposure meter, R4 maze/nav) — a depth-scaled cost axis — onto that same loop.

**The one question RG2 answers with data:**

> **Did adding a cost axis change the outcome distribution off "push-to-end-then-extract"?**

Concretely, RG2 must show — per opposition config, and side-by-side against the M1.0 baseline — whether runs now exhibit a **real spread of end-causes** (extract / death / timeout), a **spread of run-lengths and max-depths** (not all bottoming out at the same "push to the end" depth), and **opposition events actually firing**, OR whether a single strategy still dominates despite the new systems.

RG2 does **not** decide "is it fun." It produces the **evidence packet** that RG3 (Director decides) reads. RG2's product is *distributions and a read*; RG3's product is the *go/iterate/pivot verdict*.

**Design intent guardrail:** M1.1 is *configurable, not balanced* (Breakdown §2). RG2 therefore must NOT report "the numbers are wrong, re-tune knob X to value Y." It reports **whether the cost axis is capable of producing an outcome spread at all**, and **which oppositions/configs move the needle**, so the Director can sweep toward the tension. A flat distribution under a given config is a finding about that config, not a balance verdict.

---

## 2. Metrics design — what to compute, grouped BY config

Every metric is computed **per config bucket** (see §3 for bucketing), then **the all-off bucket is compared directly against G4's M1.0 numbers** as an in-build control. BUG1 (`duration_s`) and BUG2 (`depth_reached`) make the two headline distributions trustworthy for the first time — before M1.1 they were recoverable only from raw `t_ms` / stuck at 1.

### 2.1 End-cause distribution (the headline)
Per config bucket, the count and fraction of `run_ended.data.cause` over `{extract, death, timeout, quit}`.
- `extract` = banked successfully. `death` = caught by R1 hazard (or debug-K). `timeout` = clock expired OR R3 max-exposure forced loss. `quit` = abandoned — excluded from outcome ratios and folded into the abandonment rate together with inferred mid-run `partial[]` abandonments (§9.4).
- **M1.0 baseline (G4):** 30 extract / 2 death / 0 timeout → ~94% extract. The signal of a working cost axis is the **all-off bucket reproducing ~that** while **opposition-on buckets show materially more death/timeout** and a lower extract share.

### 2.2 Run-length distribution (real via BUG1)
Per config bucket: `run_ended.data.duration_s` → median, mean, min/max, and a **histogram** on fixed bins so it overlays M1.0's. Reuse G4's bins for a like-for-like overlay: `<10 · 10–20 · 20–30 · 30–45 · 45–60 · >60` seconds.
- **M1.0 baseline (G4):** median 17.9s, mean 22.1s, range 2.4–53.7s.
- Cross-check `duration_s` against the run's `t_ms` span (first→last row) as a BUG1 sanity gate; flag any run where they diverge > 1 frame.

### 2.3 Max-depth distribution (real via BUG2)
Per config bucket: `run_ended.data.depth_reached` (max within-band `depth_index` reached) → median, mean, max, and a **histogram** over integer depth.
- **M1.0 baseline:** effectively a single value (depth was stuck at 1 / always pushed to the end) — so the *shape* matters most. A working cost axis should turn a near-degenerate "everyone reaches max depth" into a **spread** (some bail shallow, some push deep and pay).
- Pair with end-cause: **depth-at-death** and **depth-at-extract** distributions (where do people die vs. where do they choose to cash out) are the clearest "felt the gamble" signal.

### 2.4 Per-opposition event frequencies
Per config bucket, counts (and per-run rates) of each new M1.1 opposition row (the `EventType`s TEL adds — see §3.1):
- R1: `hazard_awoke`, `hazard_caught` — awakenings/run, catch rate, **depth at awaken** and **depth at catch**.
- R2: `return_cost_incurred` — events/run, total/mean magnitude, **cost vs. depth** correlation.
- R3: `exposure_crossed`, `exposure_penalty` — crossings/run, **depth at each crossing**, penalty fire count, max-exposure→timeout count.
- R4: `nav_branch_taken`, `nav_lost_proxy` — branches taken/run, lost-proxy value distribution (backtracking / no-depth-progress time / revisited cells).
- **Sanity gate:** an opposition's rows appear **iff** that opposition's `enabled` is true in the run's config snapshot. Rows present with the opposition off (or absent with it on) is a TEL/wiring bug RG2 must flag before trusting any read.

### 2.5 Runs/session
Per config bucket and overall: runs per `session_id`, plus an **abandonment rate** and total session count. Per the ratified semantics (§9.4), the **abandonment numerator = explicit `run_ended.cause == "quit"` rows + inferred mid-run abandonments (`partial[]`, started-never-ended)**; both are excluded from end-cause outcome ratios but counted together as abandonment, over all run-attempts.
- **M1.0 baseline (G4):** 10/11/13 → mean 11.3 runs/session (the "go again" pull). Targets: runs/session > 1.5, abandonment < ~25%.
- Watch for a *regression*: if a cost axis makes the loop frustrating rather than tense, runs/session drops and abandonment climbs — a signal the Director needs alongside the spread.

### 2.6 The M1.0-baseline comparison (the spine of the artifact)
A single side-by-side table: **column A = M1.0 (from G4)**, **column B = M1.1 all-off bucket** (must match A within noise — this validates the control), **columns C…= each opposition-on config bucket**. Rows = the metrics above (end-cause %, run-length median, depth median, runs/session). Each column also carries the **Director's per-config subjective note as an annotation** (which config "felt tense") set alongside — but never weighting — the objective rows, per the ratified separation (§9.3). Sub-threshold buckets (`n < 8`, §9.1) are shown but tagged "no read." This table is the heart of the evidence packet for RG3.

---

## 3. Analysis approach

### 3.0 Parsing the JSONL
The log is `user://telemetry/run_log.jsonl` — one JSON object per line, envelope `{v, ts, t_ms, run_id, session_id, type, data}` (`telemetry_schema.gd`). Approach:

1. **Read line-by-line**, `JSON.parse_string` each line; skip blank lines; collect parse failures into a `malformed[]` list (report the count, don't crash).
2. **Check `v`** (schema version) per row. M1.0 logs are `v=1`; M1.1 adds opposition rows + the `run_config` snapshot **without a version bump** (config rides `run_started.data`, like the existing `build` tag — Breakdown §4 TEL, `M1_As_Built.md` §Telemetry). If TEL *did* bump `SCHEMA_VERSION`, branch read logic per version. The analyzer must **parse** both M1.0-era and M1.1-era rows in one rolling/append-only file without crashing, but per the ratified hygiene decision (§9.6) it **filters the comparison to runs carrying the M1.1 build tag / `run_config` snapshot**: snapshot-less M1.0-era runs are excluded from all buckets (reported as an excluded-legacy count), and the M1.0 baseline is taken solely from the fixed G4 numbers, never re-derived from legacy rows.
3. **Group rows by `run_id`** into a per-run record. A run is well-formed if it has exactly one `run_started` and one `run_ended`; bucket incomplete runs (started-never-ended = crash/quit-mid-run, or orphan ends) into a `partial[]` set, reported but excluded from outcome ratios.

### 3.1 Joining config to each run
Each run's config comes from its **`run_started.data.run_config`** flat dict (the snapshot TEL adds — Breakdown §4 TEL acceptance). For each `run_id`, read that dict once and attach it to the per-run record. **A run's bucket IS its `run_config` snapshot** — this is ratified (§9.5): per R4's resolution the active `RunConfig` is part of the determinism/seed key, so the snapshot is the authoritative identity of a run's conditions and RG2 groups on it directly. The all-off baseline run is identified by **every opposition `enabled = false`** in that snapshot.

> **Implementer coordination checkpoint (ratified §9.5):** the exact flat-dict key names come from R0's `RunConfig.to_flat_dict()` (the serialization R0 owns) and TEL's snapshot. RG2's analyzer reads keys like `r1_enabled`, `r2_enabled`, `r3_enabled`, `r4_enabled` plus the per-knob keys — **confirm the actual key spelling against the landed R0 + TEL code before coding the join.** Do NOT hardcode key names from this design doc; read them verbatim from the landed schema/R0 resource. Because the `RunConfig` is part of the seed key, the snapshot RG2 reads is exactly the config that determined the run.

### 3.2 Bucketing by config
The bucket key is **which oppositions are enabled** (the on/off vector), NOT the full knob values — knob *values* are a sweep dimension reported *within* a bucket, not a separate bucket (else every run is its own bucket and nothing aggregates).

- **Primary bucket key:** the sorted set of enabled oppositions, e.g. `{}` (all-off control), `{R1}`, `{R3}`, `{R1,R3}`, `{R1,R2,R3,R4}` (all-on).
- **Within a bucket**, if the Director swept a knob (e.g. R1 chase speed) across runs, report the metric *and* note the knob spread (so a flat distribution from a too-weak setting isn't misread as "the system doesn't work"). Surface the knob values present in each bucket in a small sub-table.
- **Combinatorial caution:** four on/off oppositions = 16 possible buckets; with knob sweeps the space is large and per-bucket `n` will be small. RG2 reports only **buckets the Director actually ran** and flags any bucket with `n` below the **ratified minimum-for-a-read threshold of 8 runs/bucket** (§9.1): such a bucket is shown with raw counts but tagged "insufficient data, no read" and excluded from the §6 success/dominance read. The **priority buckets are the ratified isolation + full-stack set** — `{}`, `{R1}`, `{R2}`, `{R3}`, `{R4}`, `{R1,R2,R3,R4}` (§9.2); these are required if the Director captured them, and any other partial-stack bucket is reported opportunistically with no required stacking order.

### 3.3 Presenting the side-by-side
- The §2.6 master comparison table (M1.0 | all-off | each run bucket).
- Per-metric distributions as **text histograms** (greybox-appropriate; no plotting dependency) — ASCII bar rows of `bin: ##### (count)`, mirroring how G4 reported its run-length histogram inline.
- Each opposition's event-frequency block.
- A short prose "read" per the §6 success test.

### 3.4 GDScript headless analyzer vs. external script — RECOMMENDATION

**Recommend: a GDScript headless analyzer at `tools/analyze_telemetry.gd`, run via `godot --headless --script`.** Rationale (consistent with repo norms):
- The repo's entire tooling layer is GDScript-under-`tools/` run headless (`ci_smoke_test.gd`, `check_junk_catalog.gd`, `gen_*` scripts, `zone_piece_check.gd`). An external Python/JS analyzer would introduce a second toolchain the project deliberately avoids.
- It can reuse `TelemetrySchema` constants (`class_name TelemetrySchema`) so the analyzer and the writer share ONE source of truth for `EventType` strings and `RUN_END_CAUSES` — no drift, exactly the reuse the schema doc anticipates ("reused by … G4 analysis").
- It can read `user://telemetry/run_log.jsonl` directly via `FileAccess` and resolve `RunConfig` key names against the landed resource if needed.
- Determinism + CI friendliness: it runs in the same `godot --headless` lane the smoke test already uses; the analyzer itself is pure (file in → report out), so it's trivially repeatable.

The analyzer takes an optional input-path arg (default the `user://` log) and an optional output-path for the artifact, and **prints a human-readable report to stdout** while writing the artifact file (see §5). No autoload dependency at runtime (it parses a file, it doesn't touch `GameState`/`EventBus`), so it sidesteps the headless-autoload constraint in `M1_As_Built.md` §"Testing constraints."

---

## 4. Pseudocode (parse → group-by-config → distributions)

```gdscript
# tools/analyze_telemetry.gd  (DESIGN SKETCH — not implemented by this task)
extends SceneTree   # or a plain RefCounted invoked from _initialize

const LOG := TelemetrySchema.LOG_PATH   # "user://telemetry/run_log.jsonl"

func analyze(path: String) -> void:
    var rows := _read_jsonl(path)                  # [{v,ts,t_ms,run_id,session_id,type,data}], malformed skipped+counted
    var runs := _group_by_run(rows)                # { run_id: { started:Row, ended:Row, events:[Row] } }
    var buckets := {}                              # { bucket_key:String -> RunGroup[] }

    for run_id in runs:
        var r = runs[run_id]
        if r.started == null or r.ended == null:
            _partial.append(run_id); continue       # incomplete run -> abandonment (§9.4), excluded from ratios
        var cfg := r.started.data.get("run_config", {})   # the snapshot TEL added = the bucket identity (§9.5)
        if cfg.is_empty():
            _legacy.append(run_id); continue        # snapshot-less M1.0-era run -> filtered out (§9.6)
        var key := _bucket_key(cfg)                 # sorted set of enabled oppositions, e.g. "{}", "{R1,R3}"
        buckets.get_or_add(key, []).append(r)

    var report := {}
    for key in buckets:
        report[key] = _summarize(buckets[key])      # one row of all §2 metrics for this bucket

    _emit_comparison(report)                        # §2.6 table: M1.0(G4 consts) | "{}" | each bucket
    _emit_histograms(report)                        # run-length, depth, depth-at-death/extract
    _emit_opposition_events(buckets)                # §2.4 per-opposition counts/rates
    _emit_read(report)                              # §6 success test prose

func _bucket_key(cfg: Dictionary) -> String:
    var on := []
    for opp in ["r1","r2","r3","r4"]:
        if cfg.get(opp + "_enabled", false): on.append(opp.to_upper())
    on.sort()
    return "{" + ",".join(on) + "}"                 # "{}" == all-off control

func _summarize(group: Array) -> Dictionary:
    var causes := {"extract":0,"death":0,"timeout":0,"quit":0}
    var durations := []; var depths := []
    var depth_at_death := []; var depth_at_extract := []
    var opp_events := {}                             # EventType -> count
    for r in group:
        var cause = r.ended.data.get("cause", "?")
        causes[cause] = causes.get(cause, 0) + 1
        var dur = r.ended.data.get("duration_s", 0.0)      # BUG1: now real
        var dep = r.ended.data.get("depth_reached", 0)     # BUG2: now real (not stuck at 1)
        durations.append(dur); depths.append(dep)
        if cause == "death":   depth_at_death.append(dep)
        if cause == "extract": depth_at_extract.append(dep)
        # BUG1 cross-check: compare dur vs (last t_ms - first t_ms) for this run; flag >1 frame drift
        for e in r.events:
            opp_events[e.type] = opp_events.get(e.type, 0) + 1
    return {
        "n": group.size(),
        "cause_counts": causes,
        "cause_pct": _to_pct(causes),
        "dur": _stats(durations),  "dur_hist": _hist(durations, G4_BINS),
        "depth": _stats(depths),   "depth_hist": _hist(depths),
        "depth_at_death": _stats(depth_at_death),
        "depth_at_extract": _stats(depth_at_extract),
        "opp_events": opp_events,
        "runs_per_session": _runs_per_session(group),
        "knob_spread": _knob_values_seen(group),    # within-bucket sweep note (§3.2)
    }

# M1.0 baseline as named constants, sourced from G4_findings.md (the in-build control reference):
const M1_0 := {
    "runs":34, "extract":30, "death":2, "timeout":0,
    "dur_median":17.9, "dur_mean":22.1, "dur_min":2.4, "dur_max":53.7,
    "runs_per_session_mean":11.3,
}
const G4_BINS := [10.0, 20.0, 30.0, 45.0, 60.0]   # same bins G4 used → overlayable
const MIN_RUNS_FOR_READ := 8                       # ratified floor (§9.1): below this -> "no read"
const PRIORITY_BUCKETS := ["{}", "{R1}", "{R2}", "{R3}", "{R4}", "{R1,R2,R3,R4}"]  # ratified (§9.2)
```

`_read_jsonl`, `_group_by_run`, `_stats`, `_hist`, `_to_pct` are small pure helpers. The whole thing is file-in → report-out, no engine state.

---

## 5. Output artifact (what RG2 produces, and its format)

RG2 produces **two coupled outputs**:

1. **The analyzer script** (the reusable tool) — `tools/analyze_telemetry.gd`. Re-runnable on any future M1.x log; this is the lasting infrastructure that makes every iteration comparable on the same metrics (Breakdown §8).
2. **The analysis artifact** (the evidence packet) — `design/M1_1_Tasks/RG2_analysis_results.md`, generated/filled from the analyzer's stdout after the real playtest. Format mirrors `G4_findings.md`'s evidence section so RG3 can drop it straight into `G4_findings_M1.1.md`:
   - Header: build tag(s) present, total runs, sessions, date, config buckets observed, `n` per bucket (with sub-8 buckets flagged "no read", §9.1), malformed/partial counts, and the excluded-legacy (snapshot-less M1.0-era) run count (§9.6).
   - The Director's per-config subjective notes, annotated against each bucket — not weighted into the metrics (§9.3).
   - **The §2.6 master comparison table** (M1.0 | all-off | each bucket) — the centerpiece.
   - Per-metric: end-cause table, run-length histogram (G4 bins, overlaid on M1.0), max-depth histogram, depth-at-death vs depth-at-extract.
   - Per-opposition event-frequency blocks.
   - Data-integrity flags (BUG1 cross-check failures, opposition-rows-without-enabled mismatches, sub-threshold buckets).
   - **The "did the cost axis work?" read** (§6) — RG2's recommendation, clearly marked as input to the Director's RG3 call, never a verdict itself.

The artifact is **descriptive evidence + a recommendation**, not a decision. RG3 (`G4_findings_M1.1.md`, Director decides) is where go/iterate/pivot is recorded.

---

## 6. "Did the cost axis work?" — the success read

RG2 must state an explicit, observable success signal. Define it as the **contrast against M1.0's uniformity**:

**Signal of SUCCESS (cost axis created real tension):**
- **End-cause variety:** opposition-on buckets show a materially lower extract share than M1.0's ~94% and a **non-trivial death and/or timeout share** — i.e., the downside actually fires from *gameplay* (R1 catches, R3 max-exposure, clock+R2), not debug keys. A rough, non-binding orientation: extract share visibly off the ~90%+ ceiling with death+timeout no longer ~0.
- **Outcome spread, not a new single peak:** the run-length and (especially) **max-depth distributions widen** — some runs bail shallow-and-safe, some push deep-and-pay. The clearest evidence is a **separation between depth-at-extract (where players choose to cash out) and depth-at-death (where the gamble failed)**: if players are now extracting at a *range* of depths rather than all at max depth, the "one more room?" decision became live.
- **Control holds:** the **all-off bucket reproduces M1.0** (validates the experiment — if it doesn't, the comparison is untrustworthy and that's the first finding).
- **No engagement collapse:** runs/session stays well above 1.5 and abandonment below ~25% (tension, not frustration).

**Signal of a STILL-DOMINANT strategy (cost axis did NOT bite):**
- An opposition-on bucket whose end-cause and depth distributions are **statistically indistinguishable from the all-off control** — the system is on but not changing behavior (too-weak knobs, or players routing around it). Detect by comparing each on-bucket's cause%/depth-median against the `{}` bucket; near-identical = no effect.
- **Max-depth still pinned to the ceiling** with extract still dominant: players still push-to-end-then-extract, just now with the opposition as decoration. This is the M1.0 failure recurring and must be called out explicitly per opposition.
- Opposition events firing but **not correlated with end-cause** (e.g. `exposure_crossed` fires constantly but never converts to a `timeout` or an earlier extract) — the cost is present but toothless.

RG2's read is stated **only for buckets at or above the ratified 8-run floor (§9.1)**; sub-threshold buckets are shown with their raw numbers but explicitly given "no read." RG2's read names, **per opposition and for the stack** (the ratified priority set `{}`, `{R1}`, `{R2}`, `{R3}`, `{R4}`, `{R1,R2,R3,R4}` — §9.2), which of these two it sees, with the distributions as proof. It does NOT prescribe knob re-tuning (configurable-not-balanced) — it says *whether each cost axis is capable of shifting the distribution, on the configs the Director actually ran.*

---

## 7. Files to create (when RG2 is implemented — not now)

- `tools/analyze_telemetry.gd` — the headless GDScript analyzer (reusable across M1.x). Reuses `TelemetrySchema` constants. `.uid` companion generated by the editor on first import.
- `design/M1_1_Tasks/RG2_analysis_results.md` — the generated evidence artifact (filled from analyzer stdout post-playtest), feeding RG3.
- *(No change to `systems/telemetry/`)* — RG2 is a pure consumer; it does not touch the writer or the schema. New `EventType`s for the oppositions are TEL's deliverable, not RG2's; RG2 only reads them.

This design doc itself: `design/M1_1_Tasks/RG2_telemetry_analysis.md` (this file).

---

## 8. Acceptance criteria (from Breakdown §4 RG2)

> An **analysis artifact** comparing **end-cause / run-length / depth distributions across configs and against M1.0**, with a **clear read on whether the cost axis created a real outcome spread.**

Decomposed for verification:
1. The analyzer parses the playtest JSONL, groups by `run_id`, joins `run_started.data.run_config` (the ratified bucket identity, §9.5), filters out snapshot-less M1.0-era runs (§9.6), and buckets by enabled-opposition set (incl. the all-off control). [§3]
2. It computes, **per config bucket**: end-cause distribution, run-length distribution (real `duration_s`, BUG1), max-depth distribution (real `depth_reached`, BUG2), per-opposition event frequencies, and runs/session. [§2]
3. It emits a **side-by-side artifact** with the M1.0 baseline (G4 numbers) as an in-build control next to the M1.1 all-off bucket and each opposition config. [§2.6, §5]
4. It states a **clear read** on whether the cost axis produced a real outcome spread vs. a still-dominant strategy, per opposition and for the stack — but **only for buckets at/above the 8-run floor** (§9.1); sub-threshold buckets get "no read." [§6]
5. Data-integrity flags surfaced (BUG1 cross-check, opposition-rows↔enabled consistency, sub-threshold buckets `n < 8`, excluded-legacy count). [§2.4, §3, §9]
6. The artifact is in the `G4_findings`-comparable format so RG3 can consume it directly. [§5]

(Objective checks #1–#3, #5–#6 are mechanical/automatable; the **read** #4 is the analytical judgment RG2 hands to the Director — kept separate from the mechanical computation per QA "objective vs. subjective" discipline.)

---

## 9. Resolved Decisions (Director-ratified 2026-06-19 — apply-all-recommendations)

The Director ratified **adopting every recommendation in this section as a committed decision**. Each item below is now binding on the RG2 implementation; the analysis plan in §1–§8 has been propagated to match.

1. **Minimum runs-per-config for a meaningful read.**
   **Decision: a soft floor of 8 runs/bucket — buckets with `n < 8` are reported with their raw counts but carry an explicit "insufficient data, no read" flag and are excluded from any success/dominance read.** Rationale: G4's whole signal came from 34 runs in effectively one bucket; spread across 16 possible buckets, anything thinner than ~8 invites over-interpreting noise, so RG2 surfaces the numbers but withholds a verdict below the floor.
2. **Combinatorial scope — which combos to prioritize.**
   **Decision: RG2 requires the isolation + full-stack buckets — `{}`, `{R1}`, `{R2}`, `{R3}`, `{R4}`, `{R1,R2,R3,R4}` — as the priority set; any other (partial-stack) bucket is reported opportunistically if the Director ran it, with no required stacking order.** Rationale: matches the Breakdown's isolation-then-stack intent, gives a clean per-opposition read plus the combined-pressure read, and tells the human exactly which configs to capture during playtest.
3. **Weighting by the Director's subjective "felt the gamble" notes.**
   **Decision: RG2 ingests the Director's per-config qualitative notes and annotates the matching bucket with them, but never weights or scores the objective metrics by them — the objective spread and the subjective feel sit side-by-side, and the actual join/verdict stays with RG3.** Rationale: preserves the QA objective/subjective separation while letting the evidence packet show feel next to numbers.
4. **`quit`/abandonment semantics.**
   **Decision: the abandonment rate counts BOTH explicit `run_ended.cause == "quit"` rows AND inferred mid-run abandonments (started-never-ended `partial[]` runs); both are excluded from end-cause outcome ratios and reported together as the abandonment numerator.** Rationale: a player who closes the game mid-run is abandoning just as much as one who hits an explicit quit, so the engagement-regression check (§2.5) must see both — but neither should pollute the extract/death/timeout outcome spread.
5. **Config-key contract confirmation (cross-cutting — now part of the determinism/seed key).**
   **Decision: the active `RunConfig` is a ratified part of the determinism/seed key per R4's resolution; a run's analysis bucket is therefore its `run_started.data.run_config` snapshot, read verbatim from the landed R0 `to_flat_dict()` + TEL snapshot — never from key names hardcoded in this design doc.** Rationale: because R4 folds the `RunConfig` into the seed key, the config snapshot is the authoritative identity of a run's conditions, so bucketing on that exact snapshot keeps RG2's grouping aligned with how runs are actually determined/seeded. The implementer confirms the exact flat-dict key spelling against the landed R0 + TEL code as a coordination checkpoint before coding the join.
6. **Cross-version log hygiene.**
   **Decision: RG2 filters the comparison to runs carrying the M1.1 build tag / `run_config` snapshot; snapshot-less M1.0-era runs in the rolling log are excluded, and the M1.0 baseline is taken solely from the fixed G4 numbers.** Rationale: avoids conflating un-snapshotted legacy runs with the explicit M1.1 all-off control, keeping the baseline a single fixed reference and every M1.1 bucket cleanly attributable to a known config.
