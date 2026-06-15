# TASKS — THE FAR YARD

The orchestrator's task queue (mirror of GitHub Projects). The orchestrator consumes the
top *unblocked* task, dispatches the assigned subagent, and moves it through `STATUS.md`.
Each task carries: **id · milestone · assignee subagent · definition of done · blockedBy**.

Format:
```
### <ID> — <title>
- Milestone: M<n>   Assignee: <subagent>   BlockedBy: <ids|none>
- Goal: <one sentence>
- Done when: <verifiable acceptance criteria>
```

---

## M1 — Greybox Core Loop (first "is it fun?" gate)

Prove the push/cash-out tension in 30 seconds of decision-making. Greybox only — placeholders, no real art.

### M1-01 — Top-down player movement
- Milestone: M1   Assignee: character-animator   BlockedBy: none
- Goal: `CharacterBody2D` player moving 8-way on a greybox `TileMapLayer`, camera follow.
- Done when: player moves at a tuned speed; smoke test still green; worklog + commit.

### M1-02 — One greybox band + seeded room-graph stub
- Milestone: M1   Assignee: game-director-designer   BlockedBy: none
- Goal: a single band assembled from a few hand-authored zone-piece `PackedScene`s via the `RNG` autoload (modular room-graph stitching, TDD §3).
- Done when: same seed → identical layout (assert in a GdUnit4/headless test); worklog + commit.

### M1-03 — Slot inventory (data-driven) + HUD stub
- Milestone: M1   Assignee: ui-ux-designer   BlockedBy: none
- Goal: `Control`-based slot grid bound to `GameState`; pick up junk `.tres` into slots; HUD shows Money + slots-used, driven by `EventBus` (no polling).
- Done when: HTML mockup approved → grid works in-engine; strings externalized; worklog + commit.

### M1-04 — Junk pickups + sample content set
- Milestone: M1   Assignee: game-director-designer   BlockedBy: none
- Goal: ~10 junk `Item` `.tres` across surface/near bands with base values; a data linter that checks cross-refs/ranges/naming.
- Done when: all items load; linter passes; worklog + commit.

### M1-05 — Extraction gate + bank-or-push decision
- Milestone: M1   Assignee: game-director-designer   BlockedBy: M1-03
- Goal: a gate node that banks the unbanked haul to `GameState.money`; one-zone-deeper option that raises instability/risk.
- Done when: banking commits haul and clears unbanked; death drops unbanked minus pockets (already in `GameState`); worklog + commit.

### M1-06 — Placeholder sell screen (junk → Money)
- Milestone: M1   Assignee: ui-ux-designer   BlockedBy: M1-03, M1-04
- Goal: minimal post-run screen converting banked junk to Money via base values.
- Done when: values match the item data; worklog + commit.

### M1-07 — M1 test plan + run-length telemetry analysis
- Milestone: M1   Assignee: qa-playtest-coordinator   BlockedBy: M1-05
- Goal: the M1 test plan (objective vs. subjective), enable `Telemetry`, and the run-length histogram script to validate the 15/30/60-min targets.
- Done when: plan written; smoke+unit tests green in CI; analysis script runs on a sample log; worklog + commit.

### M1-08 — M1 gate readiness checklist + GitHub Projects mirror
- Milestone: M1   Assignee: producer   BlockedBy: M1-01..M1-07
- Goal: break M1 into the tracker, keep the risk register current, and assemble the "is it fun?" gate checklist.
- Done when: Projects board reflects M1; checklist captured; worklog + commit.

---

## Backlog (M2+)
Pulled forward when M1 passes its gate. See TDD §7 for M2 (vertical slice: full day loop, recipe repair, first enemy, real art for one band), M3 (bands 1–3, currencies/tracks, exposure crises), M4 (Act 3 + endings), M5 (polish/ship). The **economy workbook** `design/economy_model.xlsx` (game-director-designer) is due **before M3**.
