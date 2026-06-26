# Sell-Location Matters
**Category:** The economy itself

## The mechanic
Each extraction point is also a **buyer with its own taste**: a per-exit
goods→price multiplier table. Gate A pays a premium for *temporal* junk but
lowballs *lateral* scrap; Gate B is the opposite. Banking the same cargo through
different gates yields different Money. So **where you exit interacts with what
you're carrying** — a full inventory has a *best* buyer-exit, and getting there is
a routing problem layered on top of the dive.

Concretely each exit carries a table keyed by something the cargo already has —
`JunkItem.origin_band` (surface/near/temporal/lateral/far) and/or `tier` (1–5):
`{near: 1.2, temporal: 0.7, far: 1.4, …}`, default 1.0. Banked value =
`Σ base_sell_value × exit.multiplier[item.origin_band]`. A scrap-heavy haul wants
the bulk-buyer exit; a single deep relic wants the relic-buyer exit; a mixed bag
forces a compromise — which is the interesting case.

## What exists today
**Today there is exactly one buyer and it is taste-blind.** `extract_gate.gd` is
deliberately *dumb* — it owns zero value logic and hands off to
`GameState.extract_and_end_run()`; E1 places **one gate per band at a fixed spot**.
Value is a flat scalar: `JunkItem.base_sell_value` (with `value_per_slot()`),
banked 1:1. `F2_sell_screen` itemizes the haul but every item converts at face
value regardless of where you exited. `RunRules` only models the *failure* cut
(`pockets_fraction`). **Missing:** multiple gates, any per-gate price variation,
and any notion that an item is worth more *here* than *there*.

This needs the **asymmetric/multiple-exit** substrate from procgen `d4`: that
exploration already promotes exit placement to a seeded config axis with an
`ExtractPlacer` choosing CO_LOCATED / MID / FAR nodes from the graded band. Sell-
location is the **economic payload** on top of d4's geometry — d4 gives you
two-or-more reachable exits; m3 gives each one a reason to be the right one.

**Differentiate from `e1` (extraction-cost/tax):** e1 is a *cut* (a tax/cap on
total value at the gate, greed-scaling). m3 is *price variation per good* — the
same item is simply worth more at one exit. e1 changes *how much you keep*; m3
changes *which exit maximizes a specific cargo*. They compose cleanly (see below).

## How to fit it in
1. **Data on the exit.** Add a tiny `ExitMarket` resource: `price_by_band:
   Dictionary` (and/or `price_by_tier`), default empty → all 1.0 (reproduces
   today's flat bank, per the comparable-experiment rule). Attach one to each gate
   d4's `ExtractPlacer` emits.
2. **Apply at the dumb handoff.** `extract_and_end_run(active_gate)` looks up the
   gate's `ExitMarket` and scales each item's `base_sell_value` during the run→meta
   resolve. Run/meta boundary stays clean; F2 stays itemizable (show per-item the
   multiplier this exit applied).
3. **Couples routing + inventory + clock.** A better-paying exit is usually the
   *farther* one (d4 MID/FAR), so you pay the **dive clock (A3)** and exposure to
   reach it — a spatial-arbitrage tradeoff, not a free choice.
4. **Composes with siblings.** Stack m3 (per-good price) under e1 (the gate's cut)
   and `m1` (fluctuating prices drift the tables run-to-run) for a layered market:
   *which* good is worth most, *how big a cut* the gate takes, and *how today's
   prices moved.* Order: apply m3 multiplier → e1 cap/tax → bank.
5. **RunConfig knob + telemetry.** `sell_location_enabled` (default off). Emit
   `extract_market(gate_id, cargo_by_band, multiplier_applied, flat_value,
   market_value, delta)` so the gate compares **exit chosen vs. cargo composition**
   — did players actually route loot to its best buyer, or ignore it?

## Research (cited)
- **EVE Online arbitrage** — prices differ at every hub (Jita/Amarr/Dodixie…);
  profit is the *spread* between where a good is cheap and where it's demanded.
  Pure spatial arbitrage; the trip itself is the risk. ([EVE Uni wiki](https://wiki.eveuniversity.org/Using_external_tools_to_haul_profitably), [ISK Scout](https://iskscout.com/guide/arbitrage-simulation))
- **Sea of Thieves trade routes** — each outpost has **Surplus** (sells cheap,
  buys cheap) and **Sought-After** (sells dear) commodities; the dear buyers are
  *far away*, baking risk-reward straight into geography. The cleanest analogue:
  surplus-vs-sought-after = a per-exit good→price table. ([Game Rant](https://gamerant.com/sea-of-thieves-season-2-trade-routes/))
- **Tarkov trader specialization** — Ragman pays best for clothing/armor/rigs,
  Mechanic for weapons/mods, etc. A *typed-good → best-buyer* mapping; argues m3's
  table should key on a category the player can read at a glance (origin_band /
  tier), not opaque per-item prices. ([Games Finder](https://gameslikefinder.com/article/trader-order-tarkov/), [Tarkov wiki](https://escapefromtarkov.fandom.com/wiki/Trading))

## Open questions
- **Requires multi-exit maps.** Hard-depends on d4 shipping 2+ exits per band; with
  one gate, m3 is inert. Sequencing call — does d4 land first, or do m3 and d4
  co-ship? **Director / producer.**
- **Legibility.** How does the player know which exit pays best *before* committing
  the walk? Surface it on the HUD/map (a "buyer board"), telegraph it from the
  gate, or let it be discovered/learned (Knowledge track)? A hidden-best-exit is
  arbitrage-fun for veterans but opaque for new players. **Director (fun/tone).**
- **Overcomplication.** m3 + e1 + m1 stacked is three price modifiers at one
  moment — is that depth or noise? May want to **pick one or two**, not all three,
  for the M1-fun gate. **Director.**
- **Combine with e1?** Could fold into one `ExitMarket` resource (per-good prices
  *and* a tax/cap field) so each gate is a single legible "this is what this buyer
  is like." Cleaner data, but conflates two distinct ideas. **Recommendation:**
  keep separate resources, allow both on a gate.
- **Keying granularity.** Price by `origin_band` (5 buckets, legible, ties to the
  existing GDD gradient) vs. by `tier` vs. per-item. Recommend `origin_band` first.
- **Trap risk.** If one exit dominates for most cargo, routing collapses to "always
  exit B." Needs the economy sweep (starve/flood) so no exit is universally best.

---
*Summary: Per-exit goods→price tables (keyed on origin_band/tier) make WHERE you
bank interact with WHAT you carry — a spatial-arbitrage layer on d4's multi-exit
geometry, distinct from e1's value-cut, composable with e1+m1, gated behind a
`sell_location_enabled` knob whose off-default reproduces today's flat 1:1 bank.*
