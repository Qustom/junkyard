# Hub-Level Quota Pressure (rent / upkeep)
**Category:** The hub as a pressure release / pacing valve

## The idea
A **recurring rent/upkeep charge on the hub itself** — every time you return to the
yard (or every in-game day, or per upgrade you own), a fixed/scaling amount of Money
is deducted just to *keep the lights on*. The safe space is no longer free: even
sitting still costs you. This keeps the squeeze present **without an in-run timer** —
the pressure lives between runs, in the wallet, not in a countdown clock mid-dive.

The pitch is "the exhale with teeth." The hub stays the calm space you return to
(v1's no-timer relief), but hoarding cash and dawdling has a price. It's a
lean-roguelike pressure: spend deliberately, don't sit on a pile, keep diving because
the bill is always coming.

## What exists today
**The GDD premise is already "kill the debt"** (GDD §1, §3, §10 "The Debt Clock"): a
laid-off engineer drowning in student loans inherits the yard and dives to pay them
off. **K2's quota is the greybox first instance of that debt** — a per-run Money bar
(`quota_target`, meta-state, `game_state.gd:47-48`) that rises `+quota_step` each met
run; a miss is a full roguelite wipe (`wipe_meta()`, `game_state.gd:411`). Money lives
in `game_state.gd:33` and is mutated only through `add_currency()` (`:300`).

**Crucially, K2 never *deducts* money.** Meeting the quota only *raises the bar*
(`quota_target += step`, `:383`); surplus banks forward (the pure-rollover default,
per q2-banking). So the squeeze today is **threshold pressure** ("reach $N or wipe"),
not **drain pressure** ("$N leaves your wallet every cycle").

**How rent DIFFERS from the quota:** the quota is a *floor you must clear*; rent is a
*drain that empties you*. They pull opposite directions — the quota rewards
accumulation (a fat balance clears a rising bar), rent punishes it (a fat balance
still pays the same rent, but coasting on it gets you nowhere). **Rent is the
use-it-or-lose-it counterpart to the quota's reach-it-or-wipe** — it's q2-banking's
`deduct`/`expire` mode reframed as a *named, diegetic hub cost* instead of an
invisible economy rule. **What's missing:** any money *outflow* between runs at all;
the hub is currently a free, consequence-free waiting room.

## How it could fit in
**Charge a periodic upkeep on return.** Three cadences, increasingly punishing:
- **Per-run rent** — a flat (or quota-scaled) deduction each time you re-enter the
  hub. Simplest; ties the drain to the dive cadence the player already controls.
- **Per in-game day** — couples to v1's day/night hub rhythm if it lands; rent for
  *time passed*, so dawdling between dives costs more than back-to-back diving.
- **Per upgrade owned** — the Frostpunk model: every yard/gear upgrade adds standing
  upkeep, so a bigger base costs more to run. Makes expansion a *commitment*, not a
  free ratchet — but risks punishing progression (see Open Questions).

**Mechanically** rent is one new deduction in the return path, gated like every K2
feature. Recommended seam: a `_charge_rent()` call when the run resolves into the hub
(alongside or just after `_evaluate_quota`, `game_state.gd:378`), doing
`add_currency(&"money", -rent_amount, &"rent")` — reusing the canonical mutator so the
HUD repaints and telemetry sees it. **Order matters vs the quota:** charge rent
*before* the quota met-test if rent should be able to *push you under* the bar (rent
can cause a wipe — spicy), or *after* if rent is purely a post-clear drain (gentler).
That ordering is the core tension dial.

**Cross-system interactions:**
- **vs the canonical debt (s5).** Rent is *recurring upkeep*; the debt is the *thing
  you're killing*. They're distinct layers: debt = the goal, rent = the cost of
  staying in the game while you chase it. **Risk: double-counting the squeeze** — if
  both the rising quota *and* rent drain you, plus debt service (s5), the loop has
  three money pressures stacked. Recommend rent and the quota be **alternatives** the
  Director A/Bs, not co-shipped, until tuned together.
- **vs quota escalation (q5).** Rent is a *flat-ish drain* against q5's *rising bar*.
  Rent makes the early game (where q5 is gentlest) bite harder — exactly where
  q5-linear is currently toothless. Rent could be the "calm-then-spike" rhythm of
  q5's stepped shape, expressed as a between-runs cost.
- **vs banking (q2).** Rent IS q2's use-it-or-lose-it pressure with a fiction. It
  makes hoarding cost something, pushing money into the gear/yard sinks (s1, h4)
  every cycle rather than letting it pool.
- **TENSION with the calm-space relief (v1).** This is the load-bearing worry. The
  hub's whole job is to be the *exhale* — the no-timer safe space. **Does rent ruin
  the exhale?** A drain you can't escape turns the safe room into another clock, just
  a slower one. Recommendation: keep rent **small relative to a run's haul** (a tax,
  not a tourniquet) and **predictable** (a known number on a board, never a surprise),
  so it nudges spending without making the hub stressful. A *telegraphed, modest,
  diegetic* rent preserves the exhale; an *aggressive, scaling* one destroys it.

**RunConfig knob + telemetry.** Add a `Hub Rent (V2)` `@export_group` mirroring K2:
`rent_enabled` (master, **default off** → byte-identical to the K2 baseline),
`rent_amount`, `rent_cadence` (per_run / per_day / per_upgrade), `rent_can_wipe`
(does rent count toward the quota met-test). Emit `rent_charged(amount, balance_after,
cadence)` and stamp `rent_paid_this_cycle` onto the `quota_evaluated` row so the gate
reads **rent-as-fraction-of-haul**, **how often rent pushed a player under the bar**,
and **whether rent shortened or lengthened the meta-arc** vs the no-rent control.

## Research (cited)
- **Recettear** is the canonical recurring-rent-as-tension model: a debt repaid in
  **escalating weekly installments** (10k → 30k → 80k → 200k → 500k pix), miss a
  deadline → game over. It's *time-boxed* (5 weeks), so it's structurally between
  K2's wipe and a true standing rent — but it proves the loop: a **known, rising,
  recurring bill you must keep feeding** drives all spending decisions and is the
  game's whole tension engine. The lesson for THE FAR YARD: the cadence must be
  **legible and telegraphed** (players plan around the next bill), not a surprise
  drip. [Recettear — Weekly Debt Repayment guide](https://steamcommunity.com/sharedfiles/filedetails/?id=120214098),
  [Recettear — Wikipedia](https://en.wikipedia.org/wiki/Recettear:_An_Item_Shop's_Tale)
- **Lethal Company** uses the *quota* (not rent) but its design note is decisive:
  spending cash never reduces quota progress, so the player is never punished for
  buying gear. If rent stacks on the quota, THE FAR YARD must keep them legibly
  *separate* numbers or the player can't tell what's draining them — the opaque-bar
  trap (q2-banking, s5 HUD note).
- **Frostpunk / base-building upkeep** is the *per-upgrade* model: every building
  adds standing maintenance, so a bigger base costs more to run, making expansion a
  *commitment* rather than a free ratchet. This is the most thematically apt rent
  cadence (a sprawling junkyard *should* cost more to keep) — but it's also the one
  most at risk of **punishing progression**, where buying the upgrade you wanted now
  taxes you forever. [Frostpunk — Buildings (upkeep)](https://frostpunk.fandom.com/wiki/Buildings)
- **Stardew/Animal-Crossing debt-as-soft-goal** is the opposite pole (no recurring
  drain, debt paid from an ever-growing wallet at the player's pace) — the gentlest
  reading, and what the hub-as-exhale (v1) leans toward. Rent moves the game *away*
  from that pole toward the Recettear pole; how far is the tone call below.

## Open questions
- **Does rent undercut the hub's relief? (needs Director review — tone/fun.)** The
  hub's core job is the exhale (v1). A recurring drain you can't escape risks turning
  the safe space into a slow clock — the exact thing "no in-run timer" was meant to
  remove. **Recommendation:** if rent ships at all, make it *modest, predictable, and
  diegetic* (a posted bill, a tax on a haul, never a surprise) so it nudges spending
  without souring the calm. A starve-the-player rent is a different (harsher) game
  than the GDD's soft tone implies — flag the *aggressiveness* as the real call.
- **Is rent the debt, or a new layer? (needs Director review — scope.)** Three
  framings: (a) rent is a *reframing of the existing quota* (the "bill" the quota
  represents, just deducted instead of a threshold); (b) rent is a *new layer on top
  of* the quota + s5 debt; (c) rent *replaces* the quota's reach-or-wipe with a
  drain-or-wipe. **Recommendation: (a) or a knob-gated experiment** — adding a third
  money pressure (quota + rent + s5 debt) over-squeezes a soft-toned life-sim. Prefer
  rent and the quota as **A/B alternatives**, not co-shipped, until co-tuned.
- **Rate / cadence tuning.** Per-run is simplest and least punishing; per-upgrade is
  most thematic but risks taxing progression; per-day couples to a hub rhythm that
  may not exist yet (v1). Unresolved until a playtest with the rent telemetry — ship
  behind the knob, default off, enable in one preset to A/B the rent vs no-rent arc.
- **Can rent cause a wipe?** If rent is charged *before* the quota met-test it can
  push a player under the bar (spicy, swingy); *after* it's a pure post-clear drain
  (gentler). **Recommendation:** ship *after* (rent never directly wipes) for the
  greybox cut; it's the milder, more legible first read, and stacking rent-wipe on
  K2's existing miss-wipe is two punishments at once.
- **Lean-roguelike fit with the GDD's soft tone. (needs Director review.)** Rent is a
  genuinely *harsher* economy than the GDD's "keep Act 1 forgiving" (§10). It fits a
  lean, tense roguelike; it fights a cozy debt-paydown life-sim. Whether THE FAR YARD
  wants teeth in its exhale is a vision call — assemble the rent-arc telemetry and let
  the playtest gate decide, but the Director owns the tone target.
