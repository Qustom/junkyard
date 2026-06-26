# Fluctuating Prices
**Category:** The economy itself

## The mechanic
Every junk *type* has a per-run price multiplier that drifts up and down between
runs. Copper scrap that sold flat last run is hot this run (×1.6); the temporal
gizmos you hoarded have crashed (×0.7). The multiplier is shown at the sell/shop
screen *before* you dive, so the player can plan what to chase and what to leave
on the floor. It adds a "read the market" layer over the spatial "is it worth the
inventory slot?" decision the game already poses — and it makes value *dynamic*
without touching the world generator, since prices live entirely in meta-state.

## What exists today
Honest read: item value is a **fixed integer**. `JunkItem.base_sell_value`
(`data/junk/junk_item.gd:42`) is a flat number per type; the only derived figure
is `value_per_slot()` (`:50`). The downside economy (`RunRules`,
`data/economy/run_rules.gd`) only governs how much of a *failed* haul survives —
it never modulates per-type price. F2's sell screen itemizes the haul and pays
`base_sell_value` straight. So the whole price surface is static across the
entire campaign.

**What's missing:** a per-type, per-run **price modifier** that (a) drifts
between runs, (b) is seeded/deterministic (`systems/rng.gd` — never the global
`randi()`), (c) persists in meta-state (`systems/game_state.gd`), and (d) is
surfaced at the shop. None of that exists.

## How to fit it in
- **Model — mean-reverting random walk.** Per type, store a multiplier `m∈[lo,hi]`
  in meta-state. Each run-end: `m = clamp(m + revert*(1-m) + RNG.randf_range(-v,v), lo, hi)`.
  The `revert` term pulls toward 1.0 so a type can't drift to permanent worthless
  or permanent jackpot — it *cycles*, which is what makes it readable. Roll the
  walk for **all** types from the seeded `RNG` at run-end so the next run's board
  is reproducible from the run seed (debugging + daily-seed safe).
- **Surface it at the shop only.** Show each type's current multiplier and an
  arrow (up/down/flat vs. last run) on the sell/shop screen. Do **not** clutter
  the in-dive HUD — the read happens *before* you dive, not while grabbing. The
  effective payout is `floor(base_sell_value * m)`; F2 already itemizes per type,
  so it just multiplies.
- **Interactions.** Pairs naturally with **m2 demand/orders** (a standing order is
  a *guaranteed* high price that overrides the drift) and **m3 sell-location**
  (different buyers, different multipliers). **p3 familiarity** is the legibility
  lever: an unfamiliar type shows a *fuzzy* multiplier ("≈high") and only reveals
  the exact number once you've sold a few — so reading the market is itself a
  progression.
- **RunConfig knob + telemetry.** Add `price_volatility` (the `v` term; 0.0 = all
  types pinned at 1.0 = today's flat baseline, the permanent control) following
  the established all-off-default pattern (`data/run_config/run_config.gd`). Stamp
  the per-run multiplier table + each sale's `(type, m)` onto telemetry so the
  gate can ask: **did players actually chase high-priced types, or ignore the
  board?** That is the fun/busywork test.

## Research (cited)
- **Moonlighter / Recettear** — selling the same item floods the market and drops
  its value; demand rises and falls over time, so *when* you sell matters. Recettear
  re-rolls market price on High/Low/Crash states. This is the proven
  "price-as-puzzle" loop; my drift is its between-run cousin (less micro, more planning).
- **Escape from Tarkov flea market** — supply/demand swings prices wildly (wipe
  cycle: rare early, cheap once farmed); a quest or meta-shift spikes a single
  item. Validates "a rarity you ignored is suddenly worth hauling," and the
  listing-fee tax warns that frictionless buy-low/sell-high gets gamed — argues
  for mean-reversion + per-sale tax (m1+m3) over a free arbitrage faucet.

## Open questions (Director)
- **Volatility vs. legibility.** Wide swings = exciting but noisy/swingy income;
  tight = readable but maybe pointless. Where's the band that's a *decision*, not
  noise? (Recommend starting narrow, ~[0.7,1.5], and sweeping `price_volatility`.)
- **How surfaced** — exact numbers, or arrows/heat colors only (gated behind p3
  familiarity)? Numbers are gameable; vibes are softer.
- **Can it be gamed / does it crush?** Without a sink, players just hoard until a
  type peaks. Mean-reversion + inventory pressure + the dive timer limit hoarding;
  is that enough, or do prices need a "stale stash decays" rule (overlaps p1)?
- **Fun or busywork?** Does a pre-dive price board add a satisfying read, or one
  more screen to skim? This is the judgment call — recommend shipping it behind
  the RunConfig knob and letting the playtest gate's "did they chase prices"
  telemetry decide.

Sources:
- [Recettear Pricing Mechanics (Fandom)](https://recettear.fandom.com/wiki/Pricing_Mechanics)
- [Selling and Reactions — Moonlighter Wiki](https://moonlighter.fandom.com/wiki/Selling_and_Reactions)
- [Playing with pricing in Moonlighter](https://www.playfulbrandstrategy.com/en/writings/pricing-in-moonlighter)
- [Trading — Escape from Tarkov Wiki](https://escapefromtarkov.fandom.com/wiki/Trading)
- [Master Flea Market Trading in Escape from Tarkov](https://www.ludo.guide/guide/escape-from-tarkov/flea-market-trading)
