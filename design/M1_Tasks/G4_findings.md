# G4 — M1 Feedback Gate: Findings & Verdict

**Date:** 2026-06-19 · **Build:** `m1-20260619-852b6e2` · **Tester(s):** 1 (Director), 3 sessions / 34 runs
**The question (M1's reason to exist):** *Is the push/cash-out tension fun in ~30 seconds of decision-making?*

> ## VERDICT: **ITERATE** — the core tension does not yet exist.
> The greybox loop is *mechanically* sound and engaging, but the **push-your-luck tension fails** because
> nothing opposes pushing deeper. This is exactly the risk the M1 kill/pivot gate was built to catch.

---

## Telemetry evidence (34 runs, build `852b6e2`, opt-in log)

**Engagement — strong**
- **Runs/session: 10, 11, 13** (mean **11.3**) — far above the >1.5 target. The "go again" pull is real.
- **Run length** (recovered from Telemetry `t_ms`; see BUG1): median **17.9s**, mean 22.1s, range 2.4–53.7s — squarely in the "~30s decision" target window. Histogram: 2×<10s · 18×10–20s · 7×20–30s · 2×30–45s · 3×45–60s.

**The carry/capacity decision — working**
- 11 pickups/run median (max 25); banked value far below picked value (players loot ~2–3× what they can carry, swapping up). The 12-slot cap bites — "what's worth carrying" is a live choice. Extract haul: median **322**, max 512.

**The push-your-luck *risk* — absent**
- **30 extract / 2 death / 0 timeout.** The downside almost never fired; the 60s clock never expired; the only deaths were the debug-K. Players cash out comfortably every time.

## The Director's read (the decisive finding)

> "No, there isn't any risk. The optimal strategy is to go as far as possible, fill up on items, and then run
> back. The clock doesn't even matter as it is too long. Even if the clock is shorter, that would remain the
> optimal strategy as there isn't anything preventing one from going deeper. The rooms are not complex to get
> lost in, there isn't any environmental dangers to navigate around, there isn't any enemies to stop you."

This is a **structural** finding, not a tuning miss: there is a single dominant strategy (push to the end → fill
inventory → walk back → extract) with no opposing force. M1 deliberately deferred **every** source of risk —
enemies, environmental hazards, exposure/instability, maze complexity — to M2/M3. So the loop has a reward axis
(deeper = better junk, built by B3) but **no cost axis**. Without a cost to depth, "push vs. extract" is not a
decision — it's always "push." A shorter clock alone won't fix it (the Director's point): you'd still push to the
end, just faster.

## What M1 *did* prove
Movement, interaction, seeded proc-gen, slot inventory + capacity pressure, pickup/drop-swap, the gate
extract→bank, death/timeout pockets, sell→Money, and a repeatable loop — all work, are deterministic, are
tested (GdUnit4 30/30 + 18 ad-hoc checks), and are **engaging enough to replay 11×/session**. The mechanical
substrate is solid. The missing ingredient is isolated and named: **a risk that scales with depth.**

## Defects found (filed: BUG1–3)
- **BUG1** — `run_ended.duration_s` always 0 (run-length only recoverable via `t_ms`). The core gate metric.
- **BUG2** — within-band depth never tracked in telemetry (`current_depth` is a band-entry counter; stuck at 1).
- **BUG3** — zone pieces have open sockets into off-map void; the player can walk off the playable area.

## Recommendation (Director decides — scope/roadmap call)
The gate did its job: **do not build M2 breadth on an unproven, known-degenerate core.** Two paths:

- **A (recommended) — a focused M1.5 iteration, then re-run G4.** Add the *minimum* greybox risk that scales
  with depth and re-test "is it tense now." Cheap candidates (pick 1–2, greybox): a pursuing/awakening hazard
  that gets worse deeper; a return trip that becomes costlier/longer the deeper you went; a rising
  instability/exposure meter (a baby version of the M3 system) that punishes lingering deep; the clock actually
  biting *combined* with a return cost. Goal: make "one more room?" a real gamble. Keep it greybox; re-run the
  gate before M2.
- **B — fold tension-validation into M2's vertical slice** (which already includes the first enemy + real
  systems) and proceed now, logging M1's gate as "loop mechanically sound; tension unproven pending risk
  systems." Faster to M2, but spends M2 effort before the core fun is validated — the opposite of what the gate
  is for.

**Recommend A.** The entire point of this gate is to de-risk the core cheaply before investing in breadth; a
small targeted iteration that introduces one risk axis and re-tests is the disciplined move. Caveat on both:
this was a **single tester** — but a dominant-strategy/no-risk finding is objective enough that more testers
would very likely concur; widen the cohort if the Director wants confirmation before iterating.

---

*Recorded per M1 breakdown §5 DoD #6 ("a recorded go/iterate/pivot verdict"). G4's deliverable is this answer.*
