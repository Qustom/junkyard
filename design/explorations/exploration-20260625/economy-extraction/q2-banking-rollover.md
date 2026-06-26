# Banking / Rollover
**Category:** Quota system depth

## The mechanic
When a run ends and the haul is sold, **what happens to money above the quota bar?** Two answers, two different games:

- **Rollover (savings).** Surplus banks into a persistent balance that carries forward. The quota is a *floor you must clear*; everything over it is yours to hoard toward big purchases. Play pattern: over-deliver on good runs, build a buffer, save for the expensive gear/yard upgrade. The economy is **accumulative** — wealth is a stock that grows.
- **Use-it-or-lose-it (churn).** Each quota period resets your spendable money; anything not spent before the deadline evaporates (or is consumed by the quota itself). The quota is a *recurring drain you must keep feeding*. Play pattern: spend everything every cycle, no hoarding possible. The economy is **tight** — money is a flow you must constantly route into sinks.

These are not a knob tweak; they are the *shape of the whole economy*. Rollover makes the gear sink (s1) a long-term savings goal; use-it-or-lose-it makes it a forced per-cycle purchase. Pick deliberately.

## What exists today
**Meta-money already persists and already rolls over.** `game_state.gd:33` `var money: int` is meta-state, serialized via `to_meta_dict()` (`:547`), and is *never* reset between runs — only `wipe_meta()` (`:410`, a quota *miss*) zeroes it. So **rollover is the current default.** Use-it-or-lose-it would be the *deliberate restriction*, not the addition.

K2's quota interacts with surplus exactly as Lethal Company does (and as `K2_quota_system.md` Q2 resolved): the quota is checked against **cumulative `money`** (`_evaluate_quota`, `game_state.gd:377` `achieved := money`), and meeting it **only raises the bar** (`quota_target += step`, `:383`) — it does **not** deduct or consume money. Surplus simply stays in the balance and counts toward the *next, higher* bar. That is pure rollover: a fat run buffers a thin one (the Act-1-forgiving reading, GDD §10).

**What's missing:** surplus-handling is *implicit and hard-coded to rollover*. There is no rule that *spends down* or *expires* money against the quota, no `quota_basis = this_run_banked` path wired as a live experiment (the knob exists in `RunConfig` but the cumulative default makes surplus permanent), and **no telemetry distinguishing banked-vs-spent-vs-expired** surplus. Use-it-or-lose-it isn't a missing feature so much as an un-built *alternative economy*.

## How to fit it in
Make surplus-handling an **explicit, named rule** rather than an emergent property of "money never resets." Add a `RunConfig` knob (per the K0 pattern, `run_config.gd:54` `@export_group`):

```gdscript
@export_group("Quota Surplus (Q2-banking)", "surplus_")
## ROLLOVER (default) = money over quota banks forward (current behaviour, M1.4 baseline).
## DEDUCT = meeting the quota SUBTRACTS quota_target from money (use-it-or-lose-it via the bar).
## EXPIRE = unspent money zeroes at each quota period (hard use-it-or-lose-it).
@export var surplus_mode: int = 0   # 0=rollover, 1=deduct, 2=expire
```

- **Rollover (mode 0):** the current `_evaluate_quota` path, unchanged — the **permanent all-off control** (byte-identical to M1.4, the standing baseline contract).
- **Deduct (mode 1):** on a met quota, `money -= quota_target` *before* raising the bar. The quota becomes a recurring *cost*, not just a threshold — you pay the rent each cycle. Softer than full expiry: a buffer still carries, but the bar eats into it.
- **Expire (mode 2):** on each quota period boundary, `money = 0` (after the sink window). The harshest tight economy — forces spending into the gear/consumable sinks (s1, s2) every single cycle.

**Cross-system interactions:**
- **Gear sink (s1):** rollover lets you *save for* the expensive tier (a $500 upgrade is a multi-run goal); use-it-or-lose-it *forces churn* through cheaper, per-cycle purchases — it makes s1's pricing curve mean entirely different things. Pick the surplus mode *with* s1's pricing, not separately.
- **Persistent stash (p1):** rollover money is exactly the "where banked surplus lives" question p1 owns — under expire, the stash is the *only* way to carry value across a cycle (you bank goods, not cash), making p1 load-bearing instead of optional.
- **Quota tiers (q1):** under rollover the rising bar (`quota_step`) lags a healthy balance (the bar bites only intermittently); under deduct/expire each tier bites *every* cycle. q1's tier curve and this surplus mode must be tuned together.
- **Debt (s5):** if debt service is the real money sink, rollover-with-debt is "save to pay down principal"; expire-with-debt is "the cycle eats everything, debt never shrinks" — potentially a death spiral. Flag for joint tuning with s5.

**Telemetry:** stamp on `quota_evaluated` (or a sibling row) the **surplus disposition**: `banked` (carried), `spent` (into sinks since last cycle), `expired/deducted` (lost to the rule). This is the A/B the gate needs — does rollover let players *coast* (surplus accumulates, stakes evaporate), or does use-it-or-lose-it feel *punishing* (every cycle a scramble)?

## Research (cited)
**Lethal Company** is the canonical *partial* model: it deliberately **separates quota progress from spendable money** — selling scrap counts toward quota, but spending your cash does **not** reduce quota progress, so you're never punished for buying gear. Crucially it is **not** pure use-it-or-lose-it: over-delivering grants an **overtime bonus** `(scrap sold − quota) / 5`, and a known "pro strat" is to *not* sell everything when ahead, banking scrap as a reserve against a future bad run. So even the genre's poster-child for tight quota economies builds in a *rollover-of-reserves* escape valve — pure expire-every-cycle is rare because it feels punishing.

**Roguelite meta-currency** norms (Hades darkness/gems, Rogue Legacy gold) overwhelmingly favor **persistence**: meta-currency carries between runs and is spent on permanent upgrades — rollover *is* the genre default, and run-only currency (Hades' boons, which vanish on death) is reserved for *within-run* power, not the savings layer. The standard tension is *run-currency (ephemeral, tactical) vs meta-currency (persistent, strategic)* — and THE FAR YARD already sits firmly on the persistent side (`money` is meta).

**Animal Crossing**-style savings (debt paid down from an ever-accumulating wallet) is the gentlest rollover: no expiry, no pressure to spend, debt as a soft goal — the opposite pole from Lethal Company's deadline drain.

Sources:
- [Profit Quota — Lethal Company Wiki](https://lethal-company.fandom.com/wiki/Profit_Quota)
- [quota progress vs spendable currency — Steam Discussions](https://steamcommunity.com/app/1966720/discussions/0/4141689926404774409/)
- [How To Meet Quota & Maximize Profits — GameRant](https://gamerant.com/lethal-company-how-meet-quota-maximize-profits-sell-scrap/)
- [Roguelite Games With The Best Progression Systems — GameRant](https://gamerant.com/roguelite-games-with-best-progression-systems/)
- [On Roguelikes and Progression Systems — Indiecator](https://indiecator.org/2022/03/30/on-roguelikes-and-progression-systems/)

## Open questions
- **The fork itself (needs Director review).** Which economy fits THE FAR YARD's tone and length? The fiction is a debt-drowning engineer (GDD §3) — that *reads* as use-it-or-lose-it pressure (the cycle eats your money, debt looms). But the loop is a *life-sim* with long-horizon gear/yard/relationship tracks (GDD), which *reads* as rollover-savings. **Recommendation: keep rollover as the shipped default (it's the built reality, the genre norm, and the Act-1-forgiving call K2 already ratified), but build `surplus_mode = deduct` as a tunable knob and A/B it in a re-gate.** The Lethal Company lesson is decisive: even tight-quota games soften pure expiry with reserve-banking, so *deduct* (the bar eats your balance) is the more defensible "tight" pole than *expire* (hard wipe). Ship rollover, prototype deduct, let wipe-rate + surplus-disposition telemetry tell the Director whether the loop *coasts*.
- **Does lose-it feel punishing?** Untested. Pure expire stacked on the existing quota-miss *full wipe* (`wipe_meta`) is two punishments at once — likely too crushing. Deduct is gentler. Resolve only after a playtest with the surplus telemetry.
- **Interaction with debt (s5).** If s5 lands, surplus mode and debt-service must be co-tuned — expire + debt risks a death spiral where the cycle drain prevents ever paying principal. Joint call with s5, not independently.
- **Does rollover make the quota toothless mid-game?** K2's Q2 already flagged that cumulative-money rollover means the bar "stops biting for several runs" once you're ahead. If telemetry shows long coasting stretches, *deduct* is the targeted fix (re-introduces per-cycle bite without a full-wipe punishment) — a one-knob remedy rather than a redesign.
