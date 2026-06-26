# Explorations — 2026-06-25: Player Game Mechanics

Player-side verbs and systems — the things the player *does* that multiply against the [oppositions](../hazards/README.md) and play out across the [bands](../procgen-bands/README.md). Each file covers: **the mechanic** (and the decision it creates), **what exists today** (grounded in the real as-built player code), **how to fit it in** (core verbs, dive clock, oppositions, control mapping, a RunConfig A/B knob), **research** (cited prior art), a **graybox sketch**, and **open questions** (vision/fun/scope calls flagged for the Director).

All grounded in the real build: `entities/player/player.gd` + `data/player/player_movement_stats.gd` (movement), `entities/thrown_item/thrown_item.gd` + L1/L6 specs (throw), `systems/inventory/run_inventory.gd` + D1/D2 (slot inventory), `systems/dive_clock.gd` (~300s countdown), `systems/oppositions/exposure_meter.gd`, and the `data/run_config/run_config.gd` knob pattern (default-off = baseline parity, config-marked telemetry for A/B).

## M — Movement verbs *(multiply against every hazard)*
- [Dash / dodge](m1-dash-dodge.md) — **fork:** i-frames (competes with throw) vs pure reposition (complements it)
- [Sprint with a cost](m2-sprint-cost.md) — noise-based vs meter-based cost; "do I run?"
- [Sneak / crouch](m3-sneak-crouch.md) — slow/quiet, smaller footprint past cones
- [Vault / slide](m4-vault-slide.md) — geometry as escape; one-way moves

## I — Inventory as an active system *(the richest mechanic — push on it)*
- [Rotate items](i1-rotate-items.md) — packing as skill *(gated on a spatial-grid model swap)*
- [Rearrange / repack](i2-rearrange-repack.md) — **the pause-vs-real-time question**; management under chase
- [Deliberate drop](i3-deliberate-drop.md) — greed triage *(~90% already plumbed)*
- [Swap-in-place](i4-swap-in-place.md) — trade floor↔bag, no free slot
- [Combine / craft](i5-combine-craft.md) — ingredients vs finished goods; in-dive vs surface
- [Container items](i6-container-items.md) — empty-for-flexibility vs pre-packed nesting

## T — Deepening the throw *(the signature verb)*
- [Charged throw](t1-charged-throw.md) — vulnerability for distance/force; skill ceiling
- [Arc vs. straight](t2-arc-vs-straight.md) — weight drives trajectory *(needs a fake-Z model)*
- [Trajectory preview](t3-trajectory-preview.md) — gamble → plan; off/partial/full knob
- [Bounce / wall-throw](t4-bounce-wall-throw.md) — geometry as throwing puzzle *(cheap reflection)*
- [Throw-to-place vs. hit](t5-throw-to-place-vs-hit.md) — one button, two intents by charge
- [Recall / retrieve](t6-recall-retrieve.md) — the throw-spends-loot pressure valve *(passive already ships)*

## U — Other item verbs *(besides throwing)*
- [Use / consume](u1-use-consume.md) — "throw this or use this" *(heal gated on M2 HP pool)*
- [Deploy / place](u2-deploy-place.md) — persistent decoy/trap/light *(reuses the hazard system)*

## E — Interaction & environment verbs
- [Search containers](e1-search-containers.md) — timed open vs instant pickup; ties loot to the clock
- [Levers, doors, switches](e2-levers-doors-switches.md) — shortcuts, close-door-on-pursuer, trigger traps *(doors ≈ toggleable sockets)*
- [Hide](e3-hide.md) — break LoS *(needs enemy perception; clock is the anti-camp)*
- [Push / pull objects](e4-push-pull-objects.md) — build chokepoints, weigh down plates

## X — Tradeoff systems *(bind it all to extraction — where the game lives)*
- [**Carry load → speed**](x1-carry-load-speed.md) — **DIRECTOR-PRIORITIZED**: the greed tax made physical; can ship today as a slot-fill curve
- [Noise → aggro](x2-noise-aggro.md) — **shared substrate**: unblocks sprint-cost, sneak, and sound-aggro zones
- [Loadout vs. cargo](x3-loadout-vs-cargo.md) — quick-access throwables vs protected deep storage

---
**Recurring Director-decision flags across these docs:**
- **Spatial inventory model swap** — rotate (`i1`) and real-time repack (`i2`) need the dormant grid/footprint model; today's inventory is *count-based*, which conveniently makes swap-in-place (`i4`), deliberate-drop (`i3`), and carry-load (`x1`) cheap.
- **Real-time vs pausing inventory** (`i2`) — `DiveClock` is `PROCESS_MODE_PAUSABLE`, so any menu-pause freezes the dive; the pause-vs-diegetic call defines whether inventory is a tense skill or a safe puzzle.
- **Noise→aggro is foundational** (`x2`) — schedule it *before* sprint-cost (`m2`), sneak (`m3`), and the sound-aggro zone; they all plug into it.
- **Enemy perception doesn't exist yet** — sneak (`m3`), hide (`e3`), and vision-cone tactics depend on the patroller opposition landing first.
- **HP pool is an M2 prerequisite** — heal (`u1`) and damage-taking tradeoffs wait on it (same flag as the opposition architecture).
- **Fake-Z** — arc-throw "over walls" (`t2`) and verticality need a height model; bounce (`t4`) does *not* (pure 2D reflection — a cheap win).
- **Cheapest wins:** deliberate-drop, swap-in-place, deploy/place (reuses hazards), bounce-throw, trajectory-preview, and carry-load→speed all ride existing machinery.

*25 explorations across 6 groups. Authored by the `game-director-designer` role as a parallel fan-out; not yet dispositioned by the Director.*
