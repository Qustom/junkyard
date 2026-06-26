# Extraction Cost / Tax
**Category:** Extraction mechanic depth

## The mechanic
A tax taken **at the gate**, when you cash out — a cut off the value you carry,
scaled by *which* exit you use. The signature shape: the **start/shallow exit is
free but caps the value you can bank through it** (a "pockets-sized" gate); a
**deep exit takes a percentage cut but has no cap** — and you're already deep, so
you paid in risk to even reach it. This turns extraction from a binary ("am I out
yet?") into a *placement* decision: bank early through the cheap-but-capped gate,
or push to a deep gate that skims a slice off an uncapped, fatter haul.

It's distinct from sell-location (`m3`, *where the goods convert to money on the
surface*). The tax bites **at the moment of extraction**, on the run-state haul,
before banking — it shapes the dive's exit decision, not the post-run economy.

## What exists today
**There is already a return-cost system — the tax is its sibling, not its twin.**
- `systems/oppositions/return_cost.gd` (R2) taxes the **journey out**: retreating
  toward the gate past a depth threshold charges a marginal toll per hop into the
  clock / exposure / a debt meter (`r2_cost_per_depth`, `r2_cost_magnitude`). It's
  a cost of *traversing back*, paid in run-survival resources.
- `data/economy/run_rules.gd` (E3) already models a **failure** cut: on death you
  keep `pockets_fraction` (~0.20) of value as whole items.
- `entities/gate/extract_gate.gd` (E1) is deliberately **dumb** — it hands off to
  `GameState.extract_and_end_run()` with **zero value logic**. There is exactly
  one gate per band at a fixed spot.

**Clean separation:** R2 = the *trip* costs more the deeper you are (paid in
clock/exposure). The extraction tax = a *cut of the haul's value* taken **at the
gate on success**, varying **by gate**. Today every successful extract banks 100%
regardless of where the gate is — and there's only one gate, so "where" isn't yet
a choice. **Missing:** multiple gates, per-gate value rules, and any value cut on a
*successful* extract.

## How to fit it in
1. **Data on the exit.** Add a small `ExtractRule` resource (or fields on the
   gate): `tax_fraction` (cut taken), `value_cap` (max bankable, 0 = uncapped),
   and a `depth_tier`/label for HUD. The shallow gate = `{tax: 0.0, cap: N}`; a
   deep gate = `{tax: 0.15, cap: 0}`. This presumes E1's "one gate per band"
   grows to **2+ gates at different depths** (a small placement task).
2. **Apply at the dumb gate's handoff.** `extract_and_end_run()` takes the active
   gate's rule, applies cap then tax to the run-state haul value *before* the
   meta-state transfer (keeps the run/meta boundary clean — the cut happens in the
   run-state resolve). Like E3's pockets, prefer dropping **whole items** to honor
   a cap so F2's sell screen stays itemizable.
3. **Stacks coherently, not confusingly.** R2 has already charged you in
   clock/exposure to *get* to a deep gate; the tax then skims the *reward*. Two
   different currencies (survival vs. value), two different moments (en route vs.
   at gate) — readable if the HUD labels each gate's cut up front.
4. **E2 push decision.** This is the missing third axis of the cash-out call: not
   just "more loot vs. more exposure," but "**a free capped gate now, or a taxed
   uncapped gate deeper.**"
5. **RunConfig knob + telemetry.** Add `extraction_tax_enabled` (default off →
   reproduces today's 100%-bank baseline, per the comparable-experiment rule). On
   each extract emit `extract_taxed(gate_id, depth_tier, pre_value, capped_value,
   tax_paid, banked_value)` so the gate compares exit choice vs. value retained.

## Research (cited)
- **Tarkov flea fee** — a value-scaled cut deducted at the point of transaction,
  used as an economic *control* dial, not flavor; scales sharply with greed. The
  closest analogue to a per-gate `tax_fraction`. ([wiki](https://escapefromtarkov.fandom.com/wiki/Trading), [AltChar](https://www.altchar.com/game-news/escape-from-tarkov-new-flea-market-fee-is-here-to-stay-acdvh5u9BZvx))
- **Hunt: Showdown** — bounty conversion is clean (1:1) on success but **death
  halves** your gain; reward is gated on *successful* extraction. Argues for keeping
  the *success* tax modest and the *failure* cut (E3) the harsh one. ([Hunt wiki](https://huntshowdown.fandom.com/wiki/Extraction))
- **Spelunky shortcuts** — escalating tiered costs to *use a deeper entry/exit*,
  and crucially the paid progress **persists across death**. Prior art for a
  deep-gate being a paid privilege; a caution that gate access can become meta. ([Spelunky wiki](https://spelunky.fandom.com/wiki/Tunnel_Man_(Classic)))

## Open questions
- **Overlap with R2.** Does a value-tax *on top of* R2's clock/exposure toll for
  the same deep gate feel like double-charging? Possible fix: a gate either taxes
  value **or** sits behind R2's toll, never both — needs a Director call on whether
  stacking reads as depth or as punishment.
- **Tax vs. cap framing.** Is the cleanest legible version *cap-only* (free gate
  caps value, deep gate uncapped, **no** percentage at all)? A pure cap may be
  more readable than cap + tax, at the cost of the Tarkov-style "greed scales the
  cut" tension. **Director.**
- **Cap unit.** Cap on **value** (matches E3's budget logic) vs. cap on **item
  count / slots** (more legible at a glance). 
- **Does this make the shallow gate a trap?** If the cap is generous, nobody pushes
  deep; if stingy, the deep tax must be gentle or it never pays. The starve/flood
  point needs the economy sweep before tuning.
- **Meta creep risk (Spelunky lesson):** keep gate access run-state — don't let
  "unlock the cheap deep gate" leak into meta progression unless that's an
  intended track.

---
*Summary: An at-the-gate value cut — free-but-capped shallow exit vs. taxed-but-uncapped deep exit — that makes WHERE you extract a tradeoff, sitting cleanly beside R2's journey-out toll (value-at-gate vs. survival-en-route) and gated behind a RunConfig knob whose off-default reproduces today's 100% bank.*
