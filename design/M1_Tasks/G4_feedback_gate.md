# G4 — Run the M1 Feedback Gate (Internal Playtest)

**Summary:** Run the internal playtest, combine direct tester feedback with telemetry-derived metrics, and record an explicit go / iterate / pivot decision answering: *is the push/cash-out tension fun in ~30 seconds of decision-making?*

- **Parent task:** G4 (M1 breakdown)
- **Dependencies:** G3 (a working playtest build)
- **Acceptance criterion:** Playtest with at least a few testers; a written verdict backed by telemetry; an explicit go/iterate/pivot call recorded.

This is the first critical "is the game fun" check. Kill/pivot risk lives here — the verdict has real teeth.

---

## Assets needed

For G4, "assets" includes the protocol/survey and the telemetry analysis tooling.

- **Playtest protocol:** `/tools/playtest/protocol.md` — session structure: build version under test, think-aloud instructions, minimum runs per tester, what the facilitator does and does *not* say (don't coach the push/extract decision), how to collect the JSONL afterward.
- **Survey template:** `/tools/playtest/survey.md` (or a shared form) — short, decision-focused questions tied to the gate (see below).
- **Telemetry intake:** `/tools/playtest/sessions/` — drop folder where each tester's `run_log.jsonl` lands, named `tester<N>_<buildsha>.jsonl`.
- **Analysis script:** `/tools/analysis/analyze_runs.py` — reads all JSONL in the intake folder and emits the metrics below (histogram, abandonment rate, runs/session, drop-off funnel) as console output + a small CSV/markdown summary. Python chosen for quick pandas-style aggregation off-engine; no engine dependency.
- **Dashboard:** for M1, a generated `/tools/analysis/out/summary.md` plus a couple of PNG/ASCII histograms is enough — a real dashboard is deferred (see open questions).
- **Decision record:** `/tools/playtest/M1_gate_verdict.md` — the written verdict with the go/iterate/pivot call, the metrics that backed it, and the top qualitative themes.

---

## Code to generate

**Survey (decision-focused, kept short):**

```
1. In one run, how often did you feel a real "should I push or cash out?" tension?
   (none / once or twice / most decisions)
2. When you decided, did it feel like a meaningful gamble or an obvious choice?
   (obvious / somewhat / genuinely tense)   <- the core gate signal
3. After a run ended (banked or lost), did you want to immediately start another?
   (no / maybe / yes)
4. What made you decide to extract the time you extracted?  (free text)
5. What made you push deeper the time you pushed?  (free text)
6. One thing that would make the push/extract choice more fun:  (free text)
```

**Metrics computed from JSONL** (each run = one `run_started`..`run_ended` pair, keyed by `run_id`):

- **Run-length histogram** — distribution of `run_ended.duration_s`; for M1 we want mass near the ~15-min tier (and, per the gate, evidence that individual decisions land in the ~30s window — measured as inter-decision gaps, see below).
- **Decision cadence** — gaps between consecutive `band_depth_reached` / extract-or-die events as a proxy for "30 seconds of decision-making." If players go many minutes with no push/extract decision, the tension is too sparse.
- **Mid-run abandonment** — fraction of runs ending with `cause="quit"` before any extract or death; target < ~25%.
- **Runs per session** — distinct `run_id` per `session_id`; target > 1.5.
- **Drop-off funnel** — share of runs reaching each band depth, and share that ever banked anything vs. died with a haul.

**Analysis pseudocode (Python-ish):**

```python
rows = [json.loads(l) for f in glob("sessions/*.jsonl") for l in open(f)]

runs = {}                      # run_id -> {start, end, events:[...], session}
for r in rows:
    rid = r["run_id"]
    runs.setdefault(rid, {"events": [], "session": r["session_id"]})
    runs[rid]["events"].append(r)
    if r["type"] == "run_started": runs[rid]["start"] = r
    if r["type"] == "run_ended":   runs[rid]["end"]   = r

completed = [x for x in runs.values() if "end" in x]

# run-length histogram (minutes)
durations_min = [x["end"]["data"]["duration_s"] / 60 for x in completed]
histogram(durations_min, bins=[0,5,10,15,20,30,60])

# decision cadence: gaps between depth-change / decision events (seconds)
def decision_gaps(x):
    ts = [e["t_ms"] for e in x["events"]
          if e["type"] in ("band_depth_reached","junk_banked","junk_lost")]
    return [ (ts[i+1]-ts[i]) / 1000 for i in range(len(ts)-1) ]
median_gap = median([g for x in completed for g in decision_gaps(x)])

# mid-run abandonment
quit_rate = mean(1 for x in completed if x["end"]["data"]["cause"] == "quit"
                 and x["end"]["data"]["banked_total"] == 0) / max(len(completed),1)

# runs per session
from collections import Counter
per_session = Counter(x["session"] for x in completed)
runs_per_session = mean(per_session.values())

# funnel: share reaching each depth
max_depths = [x["end"]["data"]["max_depth"] for x in completed]
funnel = {d: mean(1 for m in max_depths if m >= d) for d in range(0, max(max_depths)+1)}
```

**Decision rubric (recorded in the verdict doc):**

The gate question is qualitative-first, telemetry-corroborated. Both axes matter; telemetry guards against a polite "it was fun."

- **GO** — Majority of testers rate the choice "genuinely tense" (survey Q2) AND want another run (Q3 mostly "yes") AND telemetry corroborates: runs-per-session > 1.5, abandonment < ~25%, decision cadence in a tight enough window that pushes/extracts happen on the order of tens of seconds, and a recognizable run-length cluster (not all runs ending in seconds or dragging unbounded).
- **ITERATE** — The tension is *there but flat*: testers say "somewhat," abandonment elevated, or runs-per-session near/just below 1.5. Identify the 1–2 specific levers (extract friction, reward curve, death stakes) and re-test. This is the expected modal outcome for a greybox.
- **PIVOT/KILL** — The core choice reads as "obvious" to most testers AND telemetry shows the loop isn't holding people (runs-per-session ~1, high quit-before-anything, no decision tension). The push/luck premise is not landing; escalate the kill/pivot conversation.

The verdict doc states which branch was taken, the actual numbers, the strongest qualitative quotes for and against, and — if ITERATE — the named changes and the next re-test date/build.

---

## Open questions

- **What number = "fun"?** The rubric uses "genuinely tense" majority + the quantitative gates, but the exact pass bar (e.g. >= 60% of testers? all telemetry gates or most?) needs the team to commit before the playtest so the call isn't argued after the fact.
  - **Recommendation:** Commit to this bar before the playtest: GO requires >= 60% of testers rating Q2 "genuinely tense" AND a majority "yes" on Q3 (want another run) AND at least 3 of the 4 telemetry gates met (runs/session > 1.5, abandonment < 25%, decision cadence in the tens-of-seconds band, a recognizable run-length cluster). All-tense-but-telemetry-flat, or strong-telemetry-but-obvious-choice, falls to ITERATE; failing both qualitative majority and most telemetry gates is PIVOT/KILL. With a small N the qualitative signal leads and telemetry is the tie-breaker/guard against politeness — but writing the threshold down now is what prevents post-hoc rationalization.
- **How many testers?** Acceptance says "a few." Define the real minimum (e.g. 4–6 internal) and whether any external testers count for M1.
  - **Recommendation:** Set the minimum at 5 testers (hard floor 4), all internal, each completing at least 3 runs with think-aloud — 5 is the well-established sweet spot for qualitative usability/feel testing where you reach thematic saturation fast and the goal is finding whether the tension lands, not statistical precision. Keep M1 internal-only to move quickly and avoid build/NDA logistics; reserve external testers for a later milestone once the loop has survived this gate. ([source](https://gamesuserresearch.com/how-many-players-do-i-need-for-a-playtest/))
- **What counts as abandonment in M1?** A `cause="quit"` mid-run is the proxy, but a tester quitting because the *session* ended (not the game) is noise. Do we distinguish "quit run" from "closed app," and is the < 25% threshold against all runs or only intentional in-loop quits?
  - **Recommendation:** Distinguish the two at the source: reserve `cause="quit"` for a deliberate in-loop abandon (player chose to bail on the run), and emit `cause="app_close"` (or treat a missing `run_ended` followed by process exit as such) when the tester just closes the game/ends the session. Compute the abandonment rate as in-loop `quit` runs divided by all *started* runs, and exclude `app_close` as noise. The < 25% threshold is the metric that signals "the loop isn't holding people mid-run," so it must measure intentional bailing, not housekeeping exits.
- **30-second window, measured how?** "30s of decision-making" is the gate's phrasing — is the operational metric the inter-decision cadence above, time-to-first-extract-decision, or something tester-reported? Pick the primary metric.
  - **Recommendation:** Make the primary metric the median inter-decision cadence — the gap between consecutive push/extract decision points (`band_depth_reached` / `junk_banked` / `junk_lost`) — with a target median roughly in the 20–45s band so a "should I push or cash out?" beat recurs on the order of tens of seconds. Use Q1/Q2 (tester-reported tension frequency and feel) as the corroborating signal and time-to-first-extract-decision as a secondary diagnostic. Cadence is the metric that most directly operationalizes the gate's "30s of decision-making" phrasing; the survey guards against a number that looks right but does not feel tense.
- **Dashboard tooling:** Is a generated markdown/CSV summary enough for M1, or do we want something interactive (notebook, simple web view) given the data volume is tiny?
  - **Recommendation:** Generated markdown/CSV + a couple of static histograms (matplotlib PNG or even ASCII) is enough for M1 — with ~5 testers and a few dozen runs the data volume does not justify an interactive dashboard, and a checked-in script producing `out/summary.md` is reproducible and diffable across re-tests. If you want light interactivity for free, run the same `analyze_runs.py` as a Jupyter notebook, but treat the markdown summary as the canonical artifact the verdict cites. Defer any real/web dashboard well past M1. ([source](https://chartio.com/learn/product-analytics/what-is-session-length/))
- **Collection logistics:** Manual JSONL drop-folder is fine for a few testers. If opt-in upload (the optional path noted in the architecture) isn't built yet, confirm everyone returns logs manually and that build SHAs match across testers.
  - **Recommendation:** Manual return is the M1 plan — do not build opt-in upload yet. Lock every tester to the same nightly build before the session (everyone reports the same `m1-<date>-<sha>` stamp), have each send `telemetry/run_log.jsonl` + the `logs/` folder using the in-build "open log folder" button, and the facilitator files them into `/tools/playtest/sessions/` as `tester<N>_<buildsha>.jsonl`. Have `analyze_runs.py` assert all rows carry the same build stamp and warn on any mismatch so stragglers on an old build are caught before they pollute the verdict.
