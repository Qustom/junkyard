# The Full-Bag Liability
**Category:** Risk/reward dials — SYNTHESIS (inventory × movement × economy)

## The mechanic
A fully packed extraction run is *slow*, so a fat haul is its own jeopardy. The
load→speed coupling (x1) means the richer your bag, the more vulnerable your walk
to the gate — greed becomes a literal physical liability, not just a number
resolved at cash-out. This is the **economic framing** of x1: x1 supplies the
*physics* (more load = less speed), the economy supplies the *stakes* (the value
you're now too slow to protect), and extraction supplies the *test* (the timed
walk back where the slow bites).

The synthesis unifies three systems that today decide greed separately:
- **Inventory** sets load (`RunInventory.used_slots()/max_slots`).
- **Movement** converts load to speed (x1's curve on `_carry_speed_mult`).
- **Economy/extraction** prices the consequence: the slower you are, the more
  *banked value at risk* of E3's death-drop. Holding 240 at half speed near a
  draining clock is a worse position than holding 80 at full speed — and the
  player *feels* the difference in their legs, not in a menu.

## What exists today
Honestly: this is **not a new system** — it is the economic reading of x1. x1 can
ship today as a slot-fill curve reusing the `_exposure_speed_mult` seam in
`player.gd` (a second multiplicative term, no new data). What this doc adds is the
*framing and the legibility* that turn "you move slower" into "your fortune is
exposed":
- **The value at risk already exists.** E2's `DecisionHUD` already sums haul value
  (`base_sell_value`); E3 already drops it on death. The jeopardy is built — the
  full bag just makes the run-to-bank longer.
- **The clock + pursuers already punish slowness.** `DiveClock` drains; R1's
  loaded pursuer chases at 56 px/s vs player 200. x1's curve at high load dips the
  player toward/under that — "I can't outrun it carrying this" is the moment.
- **Missing:** x1 itself (the curve + signal), and making the *coupling* legible —
  the player must read "this is rich AND slow AND far from the gate" at once.

## How to fit it in
- **Build on x1's load→speed curve** (free band ~50%, floor ~0.55×). No new data;
  ships on the existing mult seam.
- **Economic layer = value-at-risk readout.** Extend E2's HUD so the haul-value
  label *and* the speed/load state are co-legible: amber the value when load is
  past the free band ("you're carrying a fortune you can't run with"). Pair haul
  value with the live `_carry_speed_mult` so greed's cost is on one screen.
- **Extraction is where it bites** — timed e2 push windows and any one-way/return
  toll (R2) compound: a heavy late bag spends more clock and more distance.
- **Relief valves (pair deliberately):** deliberate-drop (i3) — shed junk to get
  fast again, a felt "cut losses" lever; and partial-extraction (e4) — bank some
  now, keep diving lighter. Both let the player *trade value for speed* on demand,
  which is exactly the tension stated as a verb.
- **Shared RunConfig knob** with x1 (`carry_speed_enabled` + curve params);
  all-off reproduces baseline. No separate knob — this is x1's framing.
- **Telemetry:** haul-value-at-extract vs. carry-speed-mult-at-extract;
  deaths-while-loaded (load > free-band) and *value lost* in those deaths;
  drops-under-pursuit. The proof is the correlation: do high-value runs die slow?

## Research (cited)
- **Escape from Tarkov** — overweight literally slows escape; community wisdom is
  "greed kills more players than bullets" — the richest raids are the deadliest
  because the loot you can't bear to leave is the loot that slows your extract.
  Direct precedent for value-as-physical-liability.
- **Death Stranding** — cargo weight scales speed and topple risk; a huge stack
  "looks efficient at the terminal" but changes your whole route and recovery.
  Lesson: keep the *management* cheap, let the *movement* carry the tension.
- **Spelunky ghost** — a timer-summoned unkillable threat exists *only* to punish
  greedy loitering: "your reward will be higher, but the risk will be too." Our
  version makes that tradeoff continuous and spatial rather than a hard timeout.

## Open questions
- **Separate mechanic, or just x1's framing?** *Recommendation:* **not a separate
  build** — it is x1 plus an E2-HUD legibility pass (value-at-risk readout) and a
  telemetry pairing. Treat this doc as x1's economic spec; do not double-count the
  curve. **Director call.**
- **How harsh at full *value* (not just full slots)?** Slot-fill ignores value
  density — a bag of one priceless ingot is light but precious. *Recommendation:*
  keep x1's slot-fill curve for the physics, and let the *economic* harshness live
  in the readout (amber/red by value-at-risk), not in a value-weighted speed
  penalty (which would punish lucky finds twice). **Director call.**
- **Which relief valves to pair?** i3 (drop) is the natural partner — same verb,
  immediate. e4 (partial extract) is heavier to build. *Recommendation:* ship i3
  with x1; defer e4 to a later wave. **Director scope call.**
- **Is the slow legible in top-down pixel art?** Inherited from x1 — pair the
  number with a discrete tier cue. Flag for the Director.

Sources:
- [Tarkov risk-reward / greed (lootcalc)](https://lootcalc.com/guides/eft-loot-optimization-guide)
- [Tarkov extraction & overweight (BoostRoom)](https://boostroom.com/blog/escape-from-tarkov-extraction-guide-how-to-find-and-use-extracts)
- [Death Stranding cargo as liability (Game Truth)](https://www.gametruth.com/guides/death-stranding-cargo-management-guide-route-planning-and-weight-balance/)
- [Death Stranding weight & balance (GameSpot)](https://www.gamespot.com/articles/death-stranding-inventory-tips-how-your-inventory-works-and-how-to-best-manage-your-weight/1100-6471199/)
- [Spelunky ghost as greed disincentive (Fandom)](https://spelunky.fandom.com/wiki/Ghost_(2))
