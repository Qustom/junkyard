# RG3 — The Re-Gate Verdict: Is the Tension Fun Now? (M1.1)

**Task:** RG3 (M1.1 breakdown §4, workstream (c)) · **Type:** DESIGN / PLAN — not implementation
**Assignee:** `qa-playtest-coordinator` (assembles evidence + recommends) → **Director** (decides)
**DependsOn:** RG2 (telemetry analysis + M1.0 comparison)
**Produces:** `design/M1_Tasks/G4_findings_M1.1.md` — the recorded verdict, mirroring `design/M1_Tasks/G4_findings.md`
**Mirrors:** `design/M1_Tasks/G4_findings.md` (M1.0's ITERATE finding) · `design/M1_Tasks/G4_feedback_gate.md` (original gate definition)

> This is the **re-run of the M1 feedback gate** against the M1.1 "cost axis" build. M1.0's gate (G4) returned
> **ITERATE** — the loop was engaging but had no cost axis, so "push vs. extract" was always "push." M1.1 added
> four configurable depth-scaled opposition systems (R1–R4) to create that cost axis. RG3 asks the **same
> question** again, backed by RG2's config-marked, M1.0-comparable telemetry, and records a fresh
> **go / iterate / pivot** verdict.

---

## 1. Goal & design intent

**Goal:** Record an explicit **go / iterate / pivot** verdict on the one thing M1.1 set out to prove —

> *Does a depth-scaled cost/risk axis turn "one more room?" into a real, felt, **fun** gamble?*

The design intent (M1.1 Breakdown §1) is that with a cost axis live, runs should **stop being uniform**
"push-to-the-end → fill inventory → walk back → extract" and start showing a **spread of outcomes and
end-causes** — some extract early/safe, some push-and-die, some time out, some get lost — driven by player risk
appetite rather than a single dominant strategy. The verdict answers whether that happened, and whether the
gamble *feels* fun to the Director, not merely whether the systems function.

**RG3 does not decide.** Per CLAUDE.md ("Milestone iteration loop" + "Surface judgment"), the **Director
dispositions the verdict**; the QA agent **assembles the evidence packet, attaches a recommendation, and presents
it**. This doc defines *how* that packet is built and *how* the verdict doc is laid out — it pre-decides nothing.

---

## 2. Gate question & decision criteria

### The question (unchanged from G4 — this is the point of re-gating against the same yardstick)

> **Is the push/cash-out tension fun in ~30 seconds of decision-making?**

M1.0 answered "no, because there is no cost axis." M1.1 added the cost axis. RG3 re-asks the identical question so
the two verdicts line up and the iteration is **measurable against its predecessor**, not against memory.

### What's *new* in the M1.1 re-gate vs. M1.0

M1.0 already proved **engagement** (11.3 runs/session, ~18s median run, the carry/capacity decision works). RG3
**does not need to re-prove engagement** — it needs to prove **risk**. So the decisive M1.1 signal is the
**outcome distribution**: a real spread of end-causes (extract / death / timeout / lost) **per config**, and the
Director "feeling the gamble." Engagement metrics (runs/session, abandonment, run-length cluster) remain as
**guardrails** — they must not collapse when risk is introduced (a cost axis that makes the loop tense but
un-fun-to-replay is a failure too).

### Decision criteria (the rubric the verdict cites)

These are tied to **RG2's outcome-distribution evidence** plus the Director's subjective playtest read. They
mirror G4's GO / ITERATE / PIVOT three-way split.

**GO — the cost axis works; advance to M2.**
- **Objective (RG2) — committed spread bar (§8.2):** The end-cause distribution shows a **real spread**, defined as
  **extract share below ~70% AND at least two non-extract end-causes (death / timeout / lost-proxy) each firing in a
  meaningful fraction (≳10%) of runs** under a tunable config. The "push-to-end-then-extract" dominant strategy is
  **broken** — and per §8.3 broken across a **tunable band of configs, not a single knife-edge setting** (a fun
  *region*, not one fun knob position). Max-depth and run-length distributions **widen** vs. the M1.0 all-off
  baseline (players make different depth choices, not all bottoming out the band).
- **Objective guardrail (hard floor, §8.6):** Engagement holds — runs/session stays > 1.5 and abandonment < ~25%
  under the tense config. These are **gating floors, not soft notes**: a config that creates great tension but
  breaches either floor tips the verdict to ITERATE (tune it back), never GO.
- **Subjective (Director):** The Director rates "one more room?" as a **genuinely tense gamble** (not obvious),
  reports real should-I-push-or-cash-out moments on the order of tens of seconds, and the gamble reads as
  **fun**, not merely punishing.
- → Verdict **GO**: the cost-axis premise is validated; M2 builds the real versions of the oppositions that
  carried the tension.

**ITERATE — the axis exists but the tension is flat or single-config; bump to M1.2.**
- **Objective (RG2):** The distribution shifted but a **single strategy still dominates** (e.g. extract stays at or
  above the ~70% bar of §8.2), OR the only spread comes from **one knife-edge config** rather than the tunable fun
  *region* GO requires (§8.3), OR only one opposition did any work and the others are inert, OR the tense configs
  breached an engagement floor (abandonment ≥ ~25% or runs/session ≤ 1.5 — tense but not fun-to-replay, §8.6).
- **Subjective (Director):** The gamble is "somewhat" tense — present but flat, punishing-not-fun, or fun only at
  one un-tunable setting.
- → Verdict **ITERATE**: name the **1–2 specific oppositions to swap / cut / re-tune** and **spawn M1.2** using
  this breakdown as the template (see §5).

**PIVOT — the cost-axis premise itself is wrong; Director-level rework.**
- **Objective (RG2):** No config produced a fun spread — either nothing shifted the distribution (the
  oppositions don't bite at any setting) **or** every setting that creates risk also destroys the loop
  (engagement collapses across the board, no tunable middle exists).
- **Subjective (Director):** Adding cost to depth does not make the choice fun in *any* form — the problem is the
  premise ("depth-scaled cost makes push-vs-extract fun"), not the specific oppositions.
- → Verdict **PIVOT**: escalate to a **Director-level design rework** of how tension is created in the loop
  (the four-opposition approach is not the answer; reconsider the loop's core risk model).

> **Tie-break / weighting** (Director-ratified 2026-06-19, §8.1): with a tiny N, the **subjective Director read
> leads** and the RG2 distribution is the **guard against a polite "felt tense"** and the corroborator. A
> mismatch (e.g. Director says fun but distribution is still extract-dominated, or distribution spreads but
> Director doesn't feel it) defaults to **ITERATE** and is flagged explicitly for the Director. This weighting is a
> committed gate rule, not a default to confirm — but it governs *how the verdict is weighed*, not *what the verdict
> is*; the Director still makes the go/iterate/pivot call per §6.

---

## 3. Evidence packet structure (what RG3 assembles for the Director)

RG3 is an **assembly + framing** task. It does not generate new numbers — RG2 owns the analysis. RG3 lays out
RG2's output plus the Director's notes into a single decision-ready packet. The packet has three parts:

### 3a. The objective core — RG2's distributions, framed against the criteria

Pulled directly from RG2's analysis artifact, arranged so the Director can read each criterion against a number:

- **End-cause distribution, per config** — extract / death / timeout / lost-proxy counts and shares, one row per
  config sweep, with the **M1.0 all-off baseline** row first as the in-build control. This is the headline: did
  the spread appear, and under which configs.
- **Side-by-side vs. M1.0** — the same metrics G4 reported (run-length histogram, max-depth distribution,
  runs/session, abandonment) for the all-off config (≈ M1.0) next to the risk-on configs, so the *delta* is
  explicit. The all-off column should reproduce M1.0's numbers (~18s median, ~11 runs/session,
  30 extract / 2 death / 0 timeout shape) — if it doesn't, the comparison is suspect and that's a finding.
- **Per-opposition contribution** — which of R1–R4 (alone or stacked) actually moved the distribution, from
  RG2's per-opposition event frequencies. Identifies the carriers vs. the inert systems (feeds an ITERATE
  swap/cut list).
- **Engagement guardrails** — runs/session and abandonment under the tense configs, flagged against the
  > 1.5 / < 25% thresholds, so a "tense but un-fun" outcome is visible.

### 3b. The subjective core — the Director's playtest notes

Mirrors G4's "Director's read" — the decisive qualitative finding, captured **after** the Director plays the
risk-on build. Structured by the G4 survey's decision-focused questions (adapted):

- How often did a real "should I push or cash out?" tension fire per run? (none / once-twice / most decisions)
- Did the decision feel like a **meaningful gamble or an obvious choice**? (obvious / somewhat / genuinely
  tense) — **the core gate signal.**
- Which opposition(s) created the tension, and which felt inert or un-fun?
- What made you extract when you extracted; what made you push when you pushed — under risk?
- One change that would make the push/extract choice more fun (feeds an ITERATE lever list).

Captured as the Director's own words where possible (G4's verdict was carried by a direct quote — preserve that).

### 3c. Layout for the Director

The two cores are laid **side by side against the §2 rubric**: each criterion (spread present? dominant strategy
broken? engagement held? Director felt the gamble?) gets the objective number and the subjective read next to it,
with the resulting branch (GO / ITERATE / PIVOT) it points to. Disagreements between objective and subjective are
**called out, not smoothed**. The packet ends with the QA agent's **recommendation + confidence**, explicitly
marked as a recommendation for the Director to disposition — never a decision.

---

## 4. The `G4_findings_M1.1.md` template (annotated outline)

The verdict doc RG3 produces. It **mirrors `G4_findings.md`'s shape** so the M1.0 and M1.1 verdicts line up
section-for-section. Placeholders in `<...>`; fill from RG2 + the Director's session.

```markdown
# G4_M1.1 — M1.1 Re-Gate: Findings & Verdict (Cost Axis)

**Date:** <date> · **Build:** <m1.1-build-sha, the RG1 build> · **Tester(s):** <N> (<Director + ...>), <sessions> / <runs> runs
**The question (unchanged from M1.0's G4):** *Is the push/cash-out tension fun in ~30 seconds of decision-making?*
**Compares against:** G4_findings.md (M1.0 ITERATE) — same metrics, all-off config = M1.0 control.

> ## VERDICT: **<GO | ITERATE | PIVOT>** — <one-line summary of why>
> <2–3 lines: did the cost axis make push-vs-extract a real, fun gamble? Mirror G4's verdict callout.>

---

## Telemetry evidence (<runs> runs, build <sha>, config-marked, opt-in log)

**Outcome distribution — the M1.1 headline (per config)**
- End-cause spread, per config, baseline first:
  - all-off (≈ M1.0 control): <extract / death / timeout / lost>  ← should match G4
  - <config A>: <extract / death / timeout / lost>
  - <config B (stacked)>: <...>
- Read: <is the dominant "push-to-end-then-extract" strategy broken? under which configs?>

**Side-by-side vs. M1.0 baseline**
- Run-length: M1.0 median <17.9s> vs. risk-on median <...>; distribution <widened / unchanged>.
- Max within-band depth (BUG2 now real): M1.0 <...> vs. risk-on <...>.
- Runs/session: M1.0 <11.3> vs. risk-on <...> (guardrail: > 1.5 <held / broke>).
- Abandonment: <...> (guardrail: < 25% <held / broke>).

**Per-opposition contribution**
- R1 pursuing hazard: <moved the distribution? how much?>
- R2 costlier return: <...>
- R3 exposure meter: <...>
- R4 maze / navigation: <...>
- Carriers: <which opposition(s) did the work> · Inert: <which did nothing>.

## The Director's read (the decisive finding)

> "<verbatim Director quote on whether the gamble is now real and fun, mirroring G4's quote block>"

<2–4 lines interpreting it: is this a structural win, a flat-tension iterate, or a premise failure?>

## What M1.1 proved / didn't

<What the cost axis demonstrated; which oppositions earned a place in M2; what stayed unproven.>

## Defects found (filed: <BUG#…> or "none")
- <any new bugs surfaced during the re-gate playtest>

## Recommendation (Director decides — scope/roadmap call)
<The QA agent's recommendation among GO / ITERATE / PIVOT, with the evidence that backs it and the caveats
(N=<small?>). For ITERATE, name the specific oppositions to swap/cut/re-tune and the M1.2 shape. Explicitly a
recommendation, not a decision.>

---

*Recorded per M1.1 breakdown §7 DoD #7 ("a recorded go/iterate/pivot verdict"). Mirrors G4_findings.md.*
```

> Note: the M1.0 file is named `G4_findings.md`; the M1.1 verdict file the breakdown specifies is
> `G4_findings_M1.1.md` (both in `design/M1_Tasks/` so the two verdicts sit together). RG3 writes that file.

---

## 5. Branch outcomes (what each verdict triggers downstream)

The verdict drives the kill/iterate loop (M1.1 Breakdown §8). Each branch's next step is explicit:

### GO → advance to M2
- The cost-axis premise is **validated**. Per the ratified §8.5 rule, **every** opposition RG2's per-opposition
  contribution shows did real work graduates to M2 to be built **for real** (the throwaway greybox prototypes →
  the M2 enemy-AI slice / M3 exposure system / real WFC-cyclic generation per the TDD roadmap); **inert oppositions
  are cut at the gate, not carried forward**.
- **Next step:** Producer opens the M2 milestone; M1.1's `RunConfig` + config-marked telemetry stay in the build
  as a permanent control + comparison harness for M2's own gate. Record the GO in `G4_findings_M1.1.md` and close
  the M1 iterate loop.

### ITERATE → spawn M1.2
- The axis is there but flat / single-config / un-fun. **Bump the sub-version** (M1.1 → M1.2).
- **Next step:** Author `design/M1_2_Tasks/M1.2_Breakdown.md` **from the M1.1 breakdown as a template** (per §8
  of that doc), changing only **which oppositions are swapped / cut / re-tuned** based on the per-opposition
  contribution finding:
  - **Cut** the inert oppositions (those RG2 showed moved nothing at any setting).
  - **Re-tune** the carriers whose tension was flat (new default curves / thresholds — still configurable).
  - **Swap in** a new opposition if the verdict names a missing kind of risk.
  - Keep the foundations (`RunConfig`, Config menu, config-marked telemetry, all-off control) — they carry
    forward unchanged so M1.2 stays comparable to M1.0 / M1.1.
- M1.2 then runs its own build → re-gate → `G4_findings_M1.2.md`, same template.

### PIVOT → Director-level design rework
- The premise (depth-scaled cost makes push-vs-extract fun) is wrong. This is **not** a task to dispatch — it's a
  recommendation escalated to the Director.
- **Next step:** RG3 surfaces the evidence that no config produced a fun spread and frames the design question
  for the Director (e.g. is the risk model wrong — should tension come from a different axis than depth-cost?).
  The Director runs the rework; new tasks only after a new direction is set.

---

## 6. Process note — the agent recommends, the Director decides

Per CLAUDE.md ("Milestone iteration loop" and "Surface judgment"): **any vision / fun / scope call is the
Director's.** This doc and the `G4_findings_M1.1.md` it specifies must:

- **Assemble** the objective (RG2) + subjective (Director notes) evidence into a decision-ready packet.
- **Attach a recommendation** (GO / ITERATE / PIVOT) with the evidence and caveats behind it.
- **Present** it for the Director's disposition — and **stop there.**

RG3 must **not pre-decide** the verdict, treat the obvious-looking call as settled, or write a verdict into
`G4_findings_M1.1.md` without the Director's explicit call. The `VERDICT:` line in the template is filled **only**
after the Director decides. (G4 is the canonical example: the agent recommended "A — iterate," the Director
dispositioned ITERATE; the recorded verdict reflects the Director's call, not the agent's.)

---

## 7. Acceptance criteria (restated from M1.1 Breakdown §4, RG3)

- A **recorded go / iterate / pivot verdict** exists in a `G4_findings_M1.1.md`-style doc (in `design/M1_Tasks/`).
- The verdict is **backed by config-marked telemetry** (RG2's analysis: per-config end-cause / run-length / depth
  distributions).
- The doc is **comparable to the M1.0 G4 finding** — same question, same metric shape, with the all-off config as
  the explicit M1.0 baseline column.
- The verdict is the **Director's recorded call**; the agent's contribution is the assembled evidence packet + a
  recommendation, not the decision.

---

## 8. Resolved Decisions (Director-ratified 2026-06-19 — apply-all-recommendations)

> The Director ruled on 2026-06-19 to **adopt every recommendation in this section as a ratified decision**. These
> decisions fix the **gate process and its bar up front** (the G4 lesson — commit the criteria before the playtest
> so the verdict isn't argued after the fact). They settle *how the gate is judged*; they do **not** pre-decide the
> eventual **go / iterate / pivot** verdict, which the Director still makes after the re-gate playtest per §6.

1. **Subjective vs. objective weight.**
   **Decision: with the tiny N of the re-gate, the Director's subjective "it felt like a real gamble" read leads,
   and the RG2 distribution data is the corroborating guard against a polite "felt tense"; on any subjective↔objective
   mismatch (felt fun but extract-dominated, or spread present but didn't feel it) the verdict defaults to ITERATE
   and the mismatch is flagged explicitly in the packet.**
   *Rationale:* fun is a felt quality at N≈1, but unanchored subjectivity is unreliable — the telemetry keeps the
   "felt tense" read honest, and a default-to-ITERATE on disagreement refuses to bank a GO neither core fully supports.

2. **Minimum outcome-spread bar for GO.**
   **Decision: "real spread" means extract share drops below ~70% AND at least two non-extract end-causes (death /
   timeout / lost-proxy) each fire in a meaningful fraction (≳10% of runs) under a tunable config — the
   committed numeric bar for the objective half of GO.**
   *Rationale:* a concrete pre-committed threshold prevents post-hoc argument over what counts as "broken dominant
   strategy," while staying loose enough not to demand a balanced game out of a configurable prototype.

3. **Single best-config vs. a fun range.**
   **Decision: GO requires the tension to be fun across a tunable range/band of settings, not a single knife-edge
   config — "we found a fun region we can tune within," not "we found the one fun setting."**
   *Rationale:* M1.1 shipped "configurable, not balanced" on purpose; a fun region that survives tuning is a real
   validated axis M2 can build on, whereas a lone knife-edge setting is a fragile artifact that points to ITERATE.

4. **How many testers / sessions.**
   **Decision: N=1 (Director) is acceptable for the re-gate, but a "fun" GO call carries an explicit small-N caveat
   in the packet; the Director may, at their discretion, widen to a 4–6 internal cohort to confirm a borderline or
   subjective "fun" read before banking GO.**
   *Rationale:* the M1.1 question is more subjective ("is it fun") than M1.0's near-objective "is there any risk,"
   so N=1 suffices to recommend but the caveat (and the cohort escape hatch) protects a GO that rides on feel.

5. **Which oppositions are "M2 graduates" on a GO.**
   **Decision: on GO, M2 graduates every opposition RG2's per-opposition contribution shows did real work; inert
   oppositions are cut at the gate, not carried into M2.**
   *Rationale:* the gate is the moment to shed what didn't earn its place — graduating the proven carriers keeps M2
   rich without paying to build for real the systems the telemetry showed never bit.

6. **Engagement-guardrail floor.**
   **Decision: the guardrail floor is runs/session > 1.5 and abandonment < ~25% under the tense config; a config that
   creates great tension but breaches either floor tips the verdict to ITERATE (tune it back), not GO — tension that
   loses players is not yet shippable.**
   *Rationale:* the cost axis must make the loop tense *and* keep the replay pull; banking GO on tension that bleeds
   players would validate a hollow win, so the engagement guardrails are hard gating floors, not soft notes.

---

*Living plan for RG3. The verdict it produces (`design/M1_Tasks/G4_findings_M1.1.md`) is the deliverable; this
doc defines how that verdict is assembled and recorded. The **gate criteria/process are now Director-ratified
(2026-06-19, §8)** — committed up front so the bar isn't argued after the playtest. The Director still
**dispositions the go/iterate/pivot verdict itself** per §6; that this plan does not, and cannot, pre-decide.*
