# Gear & Upgrades
**Category:** Money sink / investment loop — THE MISSING LOOP (flagship)

## The mechanic
A surface **shop** where, between runs, you spend banked Money on **permanent gear
and upgrades** that buff the dive: bigger inventory (`i6`/carry), faster move speed
(`m2`), a **dash** (`m1`), extra **quick-throw slots** (`x3`), a **trajectory
preview** (`t3`). Each is a discrete purchasable that maps onto an already-explored
player mechanic — the shop is the *faucet* that turns those verbs on, paid for in
Money.

This is **the missing half of the loop.** Today the chain is *dive → salvage →
extract → sell → Money → (meet quota) → dive again*. Money only ever flows **in**
and out to quota; nothing converts it into *power*. There is no reason to bank a
big haul beyond clearing the bar, so a fat run feels the same as a thin one. Gear &
upgrades closes it: **earn → spend on power → earn more, faster → vs owe quota.**
Every dollar spent on a dash is a dollar not banked against this run's quota — and
that **spend-vs-quota tension is the core between-run decision** the game is
currently missing. Power compounds (a bigger bag + speed earns more next run), so
the player is investing under a rising bar.

## What exists today
Honest read of the real build:
- **Money/Salvage persist.** `game_state.gd:33-34` (`money`, `salvage` are meta;
  Lore/`lore:35` too). They survive runs and are reset only by `wipe_meta()`.
- **Loot → Money exists.** `sell_banked_junk()` (`game_state.gd:324`) converts the
  banked junk pile to Money via `add_currency(&"money", …)` — F1's ledger + F2's
  sell screen are the cash-*in* faucet.
- **The quota exists** (K2, `game_state.gd:144-153`, `_evaluate_quota:363`): a
  rising Money bar each run, a miss = full roguelite wipe. It gives a *reason to
  earn* but **no use for surplus** beyond clearing the next bar.
- **The gear verbs exist as run-state knobs.** `RunConfig` already declares
  `throw_*` (L1), and the explorations spec `dash_*` (`m1`), loadout zones (`x3`),
  bigger-bag (`i6`), speed (`m2`), preview (`t3`). They're toggled by *config*, not
  *bought*.

**What is missing — the entire spend side.** There is **no between-run shop, no
purchasable, no upgrade Resource, no meta field recording what you own**, and no
path that applies an owned upgrade into a run. `game_state.gd` has a money *credit*
mutator but the only *debit* is a wipe. Spending Money is unbuilt. That is the gap.

## How to fit it in
- **A surface shop scene** (between `run_ended`/SellScreen and the next
  `start_run`) listing upgrades; selecting one debits Money via a new
  `add_currency(&"money", -cost, &"shop")` (the ledger already supports negative
  deltas and emits `currency_changed`), guarded by `money >= cost`.
- **Upgrades as data (`.tres`).** A new `Upgrade` Resource (mirrors `JunkItem`'s
  data-as-Resource pattern, `junk_item.gd`): `id`, `display_name`, `cost`,
  `track` (Gear/Tech per GDD), `effect_key` + `magnitude`, and `tier`/`prereq` for
  tiered axes (bag L1→L2→L3). A catalog `.tres` lists them. The
  `game-director-designer` owns this content; new upgrades need no code.
- **A new meta field** `owned_upgrades: Array[StringName]` (or `{id: level}`),
  persisted in `to_meta_dict()`/`from_meta_dict()` (`game_state.gd:547`) under a
  **schema bump** (the standing save rule). This is **meta-state** — purchases
  persist across runs, like Money.
- **Applying upgrades respects the run/meta boundary.** Owned upgrades are meta;
  their *effect on a run* is applied at `start_run` by **deriving the effective
  run knobs from owned upgrades**, NOT by mutating the bought-once data. Concretely,
  `start_run` reads `owned_upgrades` and sets the run's effective `dash_enabled`,
  `RunInventory.max_slots` (today hard-read from `inventory_config.tres` at
  `_make_run_inventory:176`), `max_speed`, loadout slot count, `t3` preview on/off.
  The gear verbs already exist as run-state — the shop just becomes their *source*
  instead of `RunConfig`. The bag-size upgrade overrides `base_max_slots`; speed
  overrides `player_movement_stats.max_speed`; dash/preview flip their bool.
- **The spend-vs-quota trade is the whole point.** Money spent in the shop is Money
  not counted toward quota (under `quota_basis = cumulative_money`,
  `run_config.gd:261`, spending literally lowers your balance against the bar). So
  the shop forces a real bet: *buy the dash now and risk missing this quota, or bank
  it safe and stay weak.* On a wipe, `wipe_meta()` must also clear `owned_upgrades`
  (severity dial — see Open Questions).
- **RunConfig knob + telemetry.** Add `shop_enabled` (default **off** = today's
  no-shop baseline, the permanent control). Telemetry: `upgrade_purchased(id, cost,
  track)`, `money_spent_per_run`, `shop_skip` (banked instead of spent),
  `owned_count` at each `run_started` — so the gate can read spend-rate, which axes
  win, and whether spending correlates with surviving the quota.

## Research (cited)
**Permanent-power vs run-power** is the spine of the genre, and our split maps
cleanly: the *shop/gear* is **permanent meta-power**; the *within-run* loot/throw
economy is **run-power**.

- **Rogue Legacy — castle upgrades.** The closest analogue: *"each time you die…
  you keep all the gold you have earned,"* spent on permanent castle upgrades that
  apply to all future heirs — exactly our **Money → permanent gear** loop. Crucially
  it adds **Labor Costs** (cost inflation after Manor L30) so the sink never
  saturates — a model for keeping our axes from being "fully bought."
- **Hades — Mirror of Night.** Permanent, **respeccable** meta-upgrades (reset for
  a few keys, full Darkness refund). The "accessible + reversible" pole — argues for
  letting the player **rebuy/respec** rather than locking a wrong purchase. Maps to
  the *resettable vs permanent* dial below.
- **Tarkov — hideout + traders.** A *huge* rouble money sink with **chained
  prerequisites** (modules gate modules) and account-wide benefits earned during
  downtime — supports our `tier`/`prereq` field and a tracked, gated upgrade graph
  (the GDD's deeper Gear/Tech tree).
- **Risk of Rain 2 — scrapper/3D-printer & Spelunky shops.** Item-conversion and
  in-run shops show the *other* pole (mostly run-power, little permanent). Useful
  contrast: our shop is deliberately the **permanent** side, because the quota loop
  needs a *durable* reason to keep earning.

## Open questions
- **[DIRECTOR — flagship loop, the key call] Permanent vs resettable upgrades, and
  do they survive a quota wipe?** This ties directly to the **reset-severity dial
  (`p4`)**. Three poses: (a) **fully permanent, wipe-proof** — Money zeroes on a
  wipe but gear survives (gentle, Tarkov-ish; the wipe stings less, power
  compounds across ladders); (b) **wiped with everything** (harsh, pure-roguelite —
  the K2 `wipe_meta()` already nukes all meta, so this is the default unless
  changed); (c) **Hades-style respeccable** (buy permanent, refund/rebuy freely).
  **Recommendation: ship (b) — wipe-proof = false — for the first cut**, because it
  keeps the quota miss genuinely costly (the M1.4 stakes thesis) and is one line in
  `wipe_meta()` (add `owned_upgrades` to the reset). Then A/B (a) if the wipe feels
  too punishing once gear exists — protected gear is the obvious softening lever
  the `p4` dial controls. *Fun/severity call — playtest must validate.*
- **[DIRECTOR — pricing] How is upgrade cost set against the quota?** If the first
  bag upgrade costs less than one quota's surplus, players auto-buy it; if it costs
  several quotas, the spend-vs-quota tension is real but slow. **Recommendation:**
  price the cheapest axis ≈ **1–2 quotas of surplus** so the first purchase is a
  genuine "skip a bar's safety to invest" bet, and tier costs to **rise with the
  quota step** (Rogue Legacy's Labor-Cost lesson) so the sink tracks income. This is
  the seed of the M3 `economy_model.xlsx` Sinks/Upgrade_Tracks tabs — *flag for the
  Director; resolve properly at M3 tuning, sane greybox starts now.*
- **How many upgrade axes for the first build?** Five are mapped (bag, speed, dash,
  quick-slots, preview). **Recommendation:** ship **3** for M2 (bag, speed, dash) —
  the three with the clearest "I earn more / survive more" payoff and the simplest
  apply-at-`start_run` seam — and defer quick-slots (needs `x3` loadout zones first)
  and preview (`t3`, a smaller power delta) to a follow-up. *Scope call — flag for
  the Director.*
- **One-shot vs tiered axes?** Dash/preview are naturally **on/off** (one purchase);
  bag/speed are naturally **tiered** (L1→L2→L3). Recommend supporting both via the
  `tier`/`prereq` fields from day one so the data shape doesn't need reworking when
  the first tiered axis ships. *Technical — resolvable on merit.*

Sources:
- [Hades' Mirror of Night Does Upgrades Right — TheGamer](https://www.thegamer.com/hades-mirror-of-night-roguelite-progression/)
- [Upgrades — Rogue Legacy Wiki (Fandom)](https://rogue-legacy.fandom.com/wiki/Upgrades)
- [Rogue Legacy 2 Castle Upgrades Guide — Gamers Heroes](https://www.gamersheroes.com/game-guides/rogue-legacy-2-castle-upgrades-guide/)
- [Hideout — Official Escape from Tarkov Wiki (Fandom)](https://escapefromtarkov.fandom.com/wiki/Hideout)
- [Escape from Tarkov Hideout Guide — timesaver.gg](https://timesaver.gg/blog/tarkov-hideout)
