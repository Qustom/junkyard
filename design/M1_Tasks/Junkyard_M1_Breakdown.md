# THE FAR YARD — M1 Milestone Breakdown

**Companion to:** `Junkyard_Technical_Design.md` (v0.4) §7
**Milestone:** M1 — Greybox Core Loop (Playable Prototype)
**Status:** planning
**Purpose:** Expand the one-line M1 scope from the TDD into the concrete, ordered steps needed to ship the prototype and pass the M1 feedback gate.

---

## 1. Milestone goal (from TDD §7)

> **M1 — Greybox Core Loop (Playable Prototype)**
> Top-down movement, one greybox band, slot inventory, pick-up junk, a single gate, extract-and-bank, death-drops-haul. Push/cash-out gate working; placeholder sell screen converts junk → Money.
> **Feedback gate:** internal playtest — *Is the push/cash-out tension fun in 30 seconds of decision-making?* This is the **first critical "is the game fun" check.** Kill/pivot risk lives here.

The single thing M1 must prove: **the push-your-luck tension of "dive deeper for more junk vs. extract and keep what I have" is fun.** Everything below exists to make that question answerable in a playtest. If it isn't fun here, we pivot before building breadth (M2+).

### Scope guardrails — what M1 is NOT
To protect the kill/pivot check, the following are explicitly **out of scope** for M1 (deferred to M2+): real art, multiple bands, recipe crafting/repair, enemy AI/combat, exposure system, day cycle, NPCs/dialogue, upgrade tracks, the full economy workbook, save/load polish. M1 uses greybox shapes, one band, and one placeholder currency (Money). Resist adding anything not on the task list — scope creep here is the top risk (TDD §8).

### Prerequisite
M0 must be complete: repo, Git LFS, project skeleton, headless CI build, and the architecture spike (autoloads incl. `Telemetry`, `EventBus`, Resource-based data, seeded `RNG`, save stub). M1 builds directly on those autoloads.

---

## 2. Workstreams overview

M1 splits into seven workstreams, roughly in dependency order:

A. Player & movement
B. Greybox band & procedural assembly
C. Junk as data + pickup
D. Slot inventory
E. The gate: extraction, banking & death-drop
F. Placeholder sell screen (junk → Money)
G. Telemetry, playtest build & the feedback gate

A and B can proceed in parallel after the M0 foundation. C depends on A+B. D depends on C. E depends on C+D. F depends on E. G wraps everything for the playtest.

---

## 3. Detailed task breakdown

Each task lists its dependency and an acceptance criterion (the observable condition that means "done").

### Workstream A — Player & movement

**A1. Player scene with top-down movement**
Build `Player` as a `CharacterBody2D` (TDD §3) with 8-direction movement, acceleration/friction tuning, and a greybox sprite (a colored capsule/rect is fine). Wire input through the built-in Input Map using named actions (`move_up/down/left/right`, `interact`) — lock action names now, they're expensive to retrofit (TDD §5).
- *Depends on:* M0.
- *Acceptance:* player moves smoothly in all directions on a test scene; movement reads from named input actions; controller and keyboard both work.

**A2. Interaction component**
Add a reusable `Interactable` detection on the player (area-based) so the player can "use" the nearest interactable (junk, gate). Surface a prompt when something is in range. Favor composition (TDD §2) so the same component serves junk pickup and the gate.
- *Depends on:* A1.
- *Acceptance:* walking near an interactable shows a prompt; pressing `interact` fires a signal on `EventBus` naming the target.

**A3. In-dive clock (light/stamina) — minimal**
A single depleting in-dive resource that creates time pressure (TDD §3 "time-as-resource"). For M1 this can be a simple countdown or draining light meter; reaching zero forces a timeout (handled in E3). Keep it minimal — it exists only to give the push/cash-out decision a clock.
- *Depends on:* A1.
- *Acceptance:* a visible meter depletes over a run; hitting zero raises a `timeout` event on `EventBus`.

### Workstream B — Greybox band & procedural assembly

**B1. Zone-piece authoring format**
Define the atomic zone-piece as a hand-authored `PackedScene` built on `TileMapLayer` with tagged sockets/exits (TDD §3 modular room-graph stitching). Author 4–6 greybox pieces (boxes, corridors, a room) using the built-in TileSet — no real tiles, just blockout collision shapes.
- *Depends on:* M0.
- *Acceptance:* 4–6 zone-piece scenes exist with consistently tagged entry/exit sockets; each loads and is walkable.

**B2. Modular room-graph generator (M1 prototype)**
Stand up the **modular room-graph stitching** generator from TDD §3 / §10: instance zone-piece `PackedScene`s and stitch them via socket-adjacency matching, driven by the seeded `RNG` autoload so layouts are reproducible. Cyclic-loop backbone and full WFC seam-matching can be stubbed/minimal for M1 — goal is a coherent, traversable single band.
- *Depends on:* B1, M0 (seeded RNG).
- *Acceptance:* given a seed, the generator produces a connected, walkable band from zone-pieces; same seed → identical layout (determinism verified by test).

**B3. Band depth / "push deeper" structure**
Make the band express depth so "push deeper" is a real choice — e.g., sequential sub-sections or increasing distance from the entry gate, with junk value/density rising with depth. No instability scaling math yet (that's M3); a simple "deeper = more/better junk, farther from safety" is enough.
- *Depends on:* B2, C1.
- *Acceptance:* moving deeper into the band visibly increases junk reward and distance back to the gate.

### Workstream C — Junk as data + pickup

**C1. Junk as Resource**
Define `JunkItem` as a custom `Resource` (`.tres`) (TDD §2 "data as Resources") with fields: id, display name, slot size/containment flags, base sell value, greybox color/shape. Author ~6–10 greybox junk items spanning a value range.
- *Depends on:* M0.
- *Acceptance:* junk items are authorable as `.tres` with no code change; a range of values exists to make "what's worth carrying" a decision.

**C2. Junk pickup in the band**
Place junk pickups in the generated band (driven by B2/B3 with seeded RNG). Picking up junk (via A2 interaction) adds it to the run inventory and fires a telemetry-able `EventBus` event.
- *Depends on:* A2, B2, C1, D1.
- *Acceptance:* junk visibly spawns in the band; interacting picks it up, removes it from the world, and adds it to run inventory; a pickup event fires on `EventBus`.

### Workstream D — Slot inventory

**D1. Slot inventory data model**
Implement the data-driven slot inventory in `GameState` run-state (TDD §2 run vs. meta split; §3 slot inventory). Items occupy slots by size/containment flags. Enforce capacity so the player must choose what to carry — this is core to the push/cash-out tension.
- *Depends on:* C1, M0.
- *Acceptance:* inventory accepts/rejects items by size and capacity; full inventory blocks further pickup; state lives in run-state, not meta.

**D2. Inventory UI (greybox)**
A `Control`-based grid showing carried junk and remaining capacity (TDD §3). Greybox styling is fine; readability matters because the player makes the keep/drop decision here.
- *Depends on:* D1.
- *Acceptance:* the grid reflects current inventory in real time; capacity/fullness is legible at a glance.

### Workstream E — The gate: extraction, banking & death-drop

**E1. Gate node + extract-and-bank**
A single gate node in the band. Interacting with it ends the run successfully and **banks** the run inventory: commits the haul from run-state to meta-save (TDD §3 extraction & banking). This is the "cash out" half of the core tension.
- *Depends on:* A2, D1.
- *Acceptance:* reaching and using the gate ends the run and transfers carried junk to the banked/meta total; a `run_end{cause: extract}` event fires.

**E2. Push/cash-out decision surface**
Make the push-vs-extract choice explicit and felt: show the player what they're holding (value) and the cost of pushing deeper (clock from A3, distance from B3). This is the literal thing the feedback gate measures — invest in making the decision legible and tense within ~30 seconds.
- *Depends on:* E1, B3, D2, A3.
- *Acceptance:* at/near the gate the player can clearly weigh "extract now with X" vs. "push for more"; the tension is presented within a ~30-second decision window.

**E3. Death / timeout drops haul**
On death or clock timeout (A3), drop the unbanked haul minus a "pockets" fraction (TDD §3) — the player keeps a small portion, loses the rest. This is the downside that gives "push deeper" its weight.
- *Depends on:* E1, A3.
- *Acceptance:* dying or timing out ends the run, retains only the pockets fraction, discards the rest; a `run_end{cause: death|timeout}` event fires with the amount lost.

### Workstream F — Placeholder sell screen (junk → Money)

**F1. Single placeholder currency: Money**
Add a `Money` ledger to meta-state in `GameState` (TDD §3; full three-currency system is M3). Banked junk converts to Money at each item's base sell value.
- *Depends on:* E1.
- *Acceptance:* banked junk increases a persistent Money total by the sum of item values.

**F2. Placeholder sell screen**
A minimal screen after extraction listing banked junk and converting it to Money (TDD §7 "placeholder sell screen converts junk → Money"). Greybox UI; shows the payoff so the push/cash-out loop closes with a visible reward.
- *Depends on:* F1, D2.
- *Acceptance:* after a successful extract, the player sees their junk tallied into Money; running total persists across runs.

### Workstream G — Telemetry, playtest build & the feedback gate

**G1. Wire M1 telemetry events**
Hook the `Telemetry` autoload (built in M0) to log the M1-relevant `EventBus` events to local JSONL (TDD §2): run start/end + duration + cause, junk picked up, junk banked vs. lost, band depth reached. This feeds the run-length validation (TDD §9, `11_run_length_tuning.md`).
- *Depends on:* E1, E3, C2.
- *Acceptance:* a completed run produces a structured JSONL log with run duration, end cause, depth, and haul banked/lost; opt-in toggle respected.

**G2. Determinism & logic tests (GdUnit4)**
Add GdUnit4 tests (TDD §4) for the pure-logic pieces: proc-gen determinism (same seed → same layout), inventory capacity rules, banking math, and death-drop pockets math. Wire into the headless CI smoke test.
- *Depends on:* B2, D1, E1, E3, F1.
- *Acceptance:* tests pass in CI headless; determinism and economy/inventory math are covered.

**G3. Greybox playtest build**
Produce a runnable build (itch.io/Butler nightly per TDD §4) of the full loop: spawn → dive → pick up junk → decide push/extract → bank/lose → sell → repeat. Verify the whole loop runs start to finish.
- *Depends on:* all of A–F, G1.
- *Acceptance:* a fresh build runs the complete loop without blockers; multiple runs possible in one session.

**G4. Run the M1 feedback gate (internal playtest)**
Run the internal playtest. Question: *Is the push/cash-out tension fun in 30 seconds of decision-making?* Combine direct feedback with telemetry (G1): run-length histograms vs. the 15-min tier, mid-run abandonment, runs-per-session > 1.5 (TDD §9). Record a go / iterate / pivot decision.
- *Depends on:* G3.
- *Acceptance:* playtest run with ≥ a few testers; written verdict on whether the loop is fun, backed by telemetry; explicit go/iterate/pivot call recorded.

---

## 4. Dependency map (build order)

```
M0 foundation
   │
   ├── A1 ─ A2 ─ A3
   │
   ├── B1 ─ B2 ───────────┐
   │                       │
   ├── C1 ─────────────────┤
   │                       │
   └── D1 ─ D2             │
            │              │
   C2 ◄── (A2, B2, C1, D1) │
            │              │
   B3 ◄── (B2, C1) ────────┘
            │
   E1 ◄── (A2, D1)
   E2 ◄── (E1, B3, D2, A3)
   E3 ◄── (E1, A3)
            │
   F1 ─ F2 ◄── (E1, D2)
            │
   G1, G2 (tests) ─ G3 (build) ─ G4 (playtest gate)
```

Critical path to a playable loop: **M0 → A1/A2 + B1/B2 + C1 + D1 → C2 → E1 → E2/E3 → F1/F2 → G3 → G4.**

---

## 5. Definition of done for M1

M1 is complete when:

1. A player can move through a procedurally assembled greybox band, pick up junk into a capacity-limited slot inventory, and feel time/distance pressure.
2. The player can choose to push deeper (more/better junk, farther from safety) or extract at the gate.
3. Extracting banks the haul and converts it to Money on a placeholder sell screen; dying or timing out drops everything but a pockets fraction.
4. The loop is repeatable and produces telemetry (run length, cause, depth, haul banked/lost).
5. GdUnit4 tests cover proc-gen determinism and economy/inventory math, passing in headless CI.
6. The internal playtest has run and produced a recorded **go / iterate / pivot** verdict on the central question — *is the push/cash-out tension fun?*

The deliverable of M1 is not just code — it's an **answer** to that question.

---

*Living document. Update alongside `Junkyard_Technical_Design.md` as M1 tasks resolve.*
