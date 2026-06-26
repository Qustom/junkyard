# Explorations — 2026-06-25: Money / Quota / Extraction Mechanics

> ← Part of the [2026-06-25 exploration set](../README.md) ([oppositions](../hazards/README.md) · [bands](../procgen-bands/README.md) · [player mechanics](../player-mechanics/README.md) · economy).

The meta-loop: the **money sink / investment** half the game is currently missing, plus depth on the **quota**, **extraction**, **persistence**, and **economy** systems that bind a run to the surface life. Each file covers: **the mechanic**, **what exists today** (grounded in the real as-built economy/extraction/meta code), **how to fit it in** (the money↔quota loop, the extraction decision, run-vs-meta persistence, a RunConfig A/B knob), **research** (cited prior art), and **open questions** (Director-flagged).

Grounded in the real build: `systems/game_state.gd` (run-vs-meta split, persistent money/salvage), `data/economy/run_rules.gd`, the **already-built quota system** (`design/M1_4_Tasks/K2_quota_system.md`), `entities/gate/extract_gate.gd` + E1–E3, `systems/oppositions/return_cost.gd` (existing return-cost), `systems/save_manager.gd` (typed save + migrations), and the `data/run_config/run_config.gd` knob pattern.

## S — Money sink / investment loop *(the missing half)*
- [**Gear & upgrades**](s1-gear-upgrades.md) — **THE MISSING LOOP**: spend meta-money on permanent power (the explored player verbs) vs owe quota
- [Consumable loadout](s2-consumable-loadout.md) — pre-run prep wager: survival kit vs hoard *(depends on use/deploy verbs)*
- [Extraction tools](s3-extraction-tools.md) — bought placeable beacon; sells the deep-dive fantasy *(reuses deploy)*
- [Map intel](s4-map-intel.md) — buy information to de-randomize risk *(seed is minted at dive-start — needs pinning)*
- [Debt / loans](s5-debt-loans.md) — borrow against future quota; opt-in risk ramp *(reframes the GDD's canonical Debt)*

## Q — Quota system depth *(pacing the pressure curve — extends K2)*
- [Quota tiers / soft vs. hard](q1-quota-tiers-soft-hard.md) — survival floor + bonus target rewards overperformance
- [Banking / rollover](q2-banking-rollover.md) — rollover *(already the default)* vs use-it-or-lose-it
- [Quota variety](q3-quota-variety.md) — money / item-type / rarity / quantity objectives *(carrot's stick-counterpart to m2)*
- [Grace / streak](q4-grace-streak.md) — soften the cliff: warning state + streak buffer
- [Escalation shape](q5-escalation-shape.md) — linear/accelerating/stepped *(today: flat +$50/run)*; the meta difficulty curve

## E — Extraction mechanic depth *(the signature risk valve)*
- [Extraction cost / tax](e1-extraction-cost-tax.md) — where you exit takes a cut / caps value *(beside the existing return-cost)*
- [Timed / arming extractions](e2-timed-arming.md) — channel to leave; pursuer can interrupt; exit-as-encounter
- [One-way commitment](e3-one-way-commitment.md) — entering deep seals the early exit *(reuses socket-sealer)*
- [Partial extraction](e4-partial-extraction.md) — ship some loot safe mid-run, keep diving with the rest
- [Extraction-as-objective](e5-extraction-as-objective.md) — the rare deep exit IS the reward *(set-piece + shortcut)*

## P — Run-to-run persistence *(how much survives a failure)*
- [Persistent stash / vault](p1-persistent-stash.md) — safe store above the grind *(money already persists; item-vault adds work)*
- [Soft meta-progression](p2-soft-meta-progression.md) — permanent small unlocks; losing = progress
- [Item familiarity](p3-item-familiarity.md) — sold-before items read faster; Knowledge as a resource
- [**Reset severity dial**](p4-reset-severity-dial.md) — **PIVOTAL**: roguelike (harsh) ↔ roguelite (forgiving); the identity choice

## M — The economy itself *(making value dynamic)*
- [Fluctuating prices](m1-fluctuating-prices.md) — per-type prices drift between runs; read the market
- [Demand / orders](m2-demand-orders.md) — a buyer wants N of item X for a premium; directs routing
- [Sell-location matters](m3-sell-location.md) — different exits pay differently for different goods *(needs multi-exit)*
- [Condition / fragility](m4-condition-fragility.md) — hazards & **throwing** damage items → lower value; costs the signature verb

## R — Risk/reward dials *(sharpening the core gradient)*
- [Optional modifiers](r1-optional-modifiers.md) — opt into a harder run for a value multiplier *(cheap win — exposes existing RunConfig knobs)*
- [Greed escalation](r2-greed-escalation.md) — value-per-room climbs with dwell, so does aggro *(mirrors the alarm-spawner)*
- [The full-bag liability](r3-full-bag-liability.md) — **synthesis**: fat haul = slow = jeopardy *(the economic framing of carry-load→speed)*

---
**Recurring Director-decision flags across these docs:**
- **Reset severity (`p4`) is the keystone** — it governs `s5` (debt-on-loss), `p1` (stash safety), `p2` (soft meta), `q4` (grace), and whether `s1` upgrades are permanent. The agents flagged a **live contradiction**: the GDD says "no total resets" but the built K2 quota does a full `wipe_meta()`. Which is canonical is the Director's pivotal call.
- **Gear & upgrades (`s1`) is the missing loop** — it's what makes money *want* spending; nearly everything here gains meaning once it exists. Cleanly buildable on the run/meta boundary.
- **Lots of this already half-exists** — money rollover (`q2`), a money stash (`p1`), and return-cost (`e1`) are partly built; the quota system (`K2`) is real and most `q*`/`s*` docs *extend* it rather than start fresh.
- **Cheap wins on existing tech:** optional modifiers (`r1`, exposes RunConfig knobs to the player), quota tiers (`q1`), extraction tax (`e1`), partial extraction (`e4`, reuses the gate's run→meta transfer), full-bag liability (`r3`, = carry-load→speed reframed).
- **Throw-verb tension:** condition/fragility (`m4`) deliberately costs the signature throw — flagged with the BotW "don't over-tax the core verb" caution.
- **Cross-cutting dependencies:** map intel (`s4`) needs the next-run seed pinned as meta-state; consumable loadout (`s2`) needs the use/deploy verbs built; sell-location (`m3`) needs multi-exit maps.

*26 explorations across 6 groups. Authored by the `game-director-designer` role as a parallel fan-out; not yet dispositioned by the Director.*
