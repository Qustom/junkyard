# Quota Tiers / Soft vs. Hard
**Category:** Quota system depth

## The mechanic
Split the single quota bar into **two stacked targets per run**: a **soft (hard-consequence) floor** — the minimum you *must* clear or it's a game over / wipe — and a **bonus (stretch) target** above it that, when hit, *unlocks something*. The soft floor keeps the survival stakes K2 already delivers; the bonus tier converts what is currently dead surplus (over-earning past the bar buys you nothing this run) into a positive incentive. Instead of "stop salvaging the moment I've cleared $150," the player has a reason to push for $225 and bag the reward. Overperformance becomes a *choice with upside*, not wasted effort.

## What exists today
K2 (`design/M1_4_Tasks/K2_quota_system.md`) is a **single hard threshold**: one `quota_target` (meta-state, `game_state.gd`), evaluated once per run in `_evaluate_quota()` inside `sell_banked_junk()`. `met = achieved >= quota_target` → either escalate (`run_number += 1; quota_target += quota_step`, fire `quota_advanced`) or, on a miss, route Continue through `wipe_meta()` (full roguelite reset). The knobs in `run_config.gd` are `quota_enabled / quota_base (50) / quota_step (50)`; the EventBus row is `quota_evaluated(run_number, target, achieved, met)`. `run_rules.gd` only governs the *failure* downside (`pockets_fraction`), not the upside.

So the curve is **binary and ceiling-less above the bar**: clear it and any extra is inert (until banking q2 makes the surplus carry); miss it and you're wiped. This mechanic adds a **second tier above the floor**. The change is additive and low-risk: `quota_evaluated` already carries `achieved`, so the bonus test is `achieved >= bonus_target` evaluated in the same place — no new evaluation seam, no `run_ended` arity change. **Missing today:** a `quota_bonus_*` knob band, a `bonus_target` (derived, not stored — `target * bonus_mult` or `target + bonus_step`), a `quota_bonus_hit` signal, the reward payload, and HUD legibility for *two* bars.

## How to fit it in
- **Two thresholds, one evaluation.** Add `quota_bonus_mult: float = 1.5` (bonus target = `quota_target * 1.5`, rounded). Keep it derived so the wipe/escalation logic is untouched — the floor stays the only thing that gates the wipe; the bonus only *grants*.
- **What the bonus unlocks (pick one to ship, knob the rest):**
  - **Money kicker** — a flat or % overtime bonus on the excess (the Lethal Company model). Cleanest, no new system.
  - **Gear discount / unlock token** — feeds the s1 gear-upgrade sink: a bonus-hit drops a discount or a "blueprint" toward a gear track. Strongest motivation (durable progress), but needs s1 to exist.
  - **Intel** — next run's band/hazard telegraph. Couples to procgen; defer.
  - Recommend shipping the **money kicker** first (self-contained) and wiring the **gear token** when s1 lands.
- **Surplus interaction (q2 banking):** the bonus tier and rollover-banking are complementary, not redundant — banking decides *where surplus goes* (carries to next run's floor), the bonus tier decides *whether hitting a higher line this run pays out now*. If both ship, the bonus pays at the moment of hitting it; banking carries whatever's left. Avoid double-dipping by paying the bonus on the *excess above the floor*, then banking the post-bonus balance.
- **RunConfig knob:** `quota_bonus_enabled: bool = false` master (all-off = K2 single-bar baseline, byte-neutral), plus `quota_bonus_mult` and a `quota_bonus_reward` enum. Preset turns it on.
- **Telemetry:** extend with `quota_bonus_hit(run_number, bonus_target, achieved)`, and segment runs into floor-miss / floor-hit / bonus-hit. The gate metric is the **bonus-hit rate** — too high (>~60%) means it's not a stretch; near-zero means it's unreachable.

## Research (cited)
**Lethal Company** is the canonical extraction-quota-with-overtime model: a hard profit quota you *must* meet or you're fired, plus an **overtime bonus** = `(quotaFulfilled − profitQuota)/5 + 15·daysUntilDeadline` — a reward scaled to *both* surplus and efficiency, and **floored at 0** so overperformance is never punitive ([Fandom](https://lethal-company.fandom.com/wiki/Profit_Quota), [dotesports](https://dotesports.com/indies/news/what-is-overtime-bonus-in-lethal-company-answered)). The "excess only" framing (bonus applies to credits *above* the quota) is exactly the floor/bonus split. More broadly, **soft cap vs hard cap** design distinguishes an absolute gate (the floor — miss it, hard consequence) from a diminishing-returns region above it ([Gate glossary](https://www.gate.com/learn/glossary/elden-ring-soft-and-hard-caps), [Games Learning Society](https://www.gameslearningsociety.org/wiki/what-is-the-difference-between-soft-caps-and-hard-caps-in-levels/)); **stretch goals** (Gamefound) model a baseline target plus tiered above-baseline rewards ([Gamefound](https://help.gamefound.com/article/113-stretch-goals)). Roguelike-mastery design warns that flat all-or-nothing failure reads as low-stakes-or-crushing; tiered outcomes give the skilled player a legible "do better" target ([Grid Sage](https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/)).

## Open questions
- **What does the bonus unlock?** Money kicker (self-contained, ships now) vs gear discount/token (stronger, blocked on s1) vs intel (blocked on procgen). **Director call** — depends on what we want overperformance to *feel* like (richer-this-run vs durable-progress).
- **Does a soft floor reduce tension?** With two bars, a player who clears the floor early may coast (floor already safe) rather than push. Counter: the bonus should be *desirable but not free* (mult tuned so ~30–40% of competent runs reach it). **Fun call → playtest.**
- **Tuning two thresholds at once.** `quota_step` (floor escalation) × `bonus_mult` interact — a rising floor with a fixed multiplier means the bonus gets absolutely larger each run. Sweep both; watch for a band where the bonus is trivially hit or permanently out of reach.
- **Does the bonus escalate or reset on wipe?** Presumably derived-from-floor so it resets automatically with the wipe — confirm no independent bonus state is worth persisting.

Sources:
- [Profit Quota — Lethal Company Wiki](https://lethal-company.fandom.com/wiki/Profit_Quota)
- [What is Overtime Bonus in Lethal Company — dotesports](https://dotesports.com/indies/news/what-is-overtime-bonus-in-lethal-company-answered)
- [Soft Cap and Hard Cap — Gate glossary](https://www.gate.com/learn/glossary/elden-ring-soft-and-hard-caps)
- [Soft caps vs hard caps — Games Learning Society](https://www.gameslearningsociety.org/wiki/what-is-the-difference-between-soft-caps-and-hard-caps-in-levels/)
- [Stretch goals — Gamefound](https://help.gamefound.com/article/113-stretch-goals)
- [Designing for Mastery in Roguelikes — Grid Sage Games](https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/)
