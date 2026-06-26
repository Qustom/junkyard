# Visible Growth
**Category:** The hub as the home of meta-progression

## The idea
The hub **physically upgrades as you progress**: a boarded-up office reopens, a
vendor's stall arrives in an empty corner, a collapsed lean-to is re-roofed, the
weed-choked yard gets a swept path and working lights. Each change is gated on a
**meta-milestone** — money banked, a band reached, an upgrade bought, a run
survived — so the room you walk through between dives is a *readout* of everything
you've accumulated.

This is **soft meta-progression (`p2`) given a body**. `p2` makes a thin slice of
progress survive the wipe as abstract fields (`unlocks`, a +1 slot, a known shop).
Visible Growth is its *front-end*: the cushion you can **see**. A quota miss still
hurts — but you come home to a yard that remembers what you built, and that memory
is the emotional argument for one more run. It also delivers the GDD's "clean it
up" arc literally: Bellweather Salvage going from derelict to thriving is *the*
visible-growth track.

## What exists today
- **The milestones already persist.** `money`, `salvage`, `lore`,
  `knowledge_level`, `unlocked_recipes`, `banked_junk` are durable meta-state
  (`game_state.gd:33-42`, `to_meta_dict()`); deepest band reached and run count are
  trivially derivable. Everything a hub-state would *read* is already saved.
- **The fiction is canon.** The GDD names **yard upgrades** as a persistent surface
  track (line 88), frames the whole game as Cyrus's derelict yard you "clean up"
  (line 37), and makes the warm-thriving-surface the central tone pillar (line 28).
  The arc is blessed; only its home is unbuilt.
- **What's missing:** there is **no hub scene** and **no hub-state→visual mapping**
  — the function that turns "money ≥ X / band ≥ N / owns recipe R" into "this prop
  is enabled, that vendor exists, this area is repaired." That mapping is the whole
  feature.

## How it could fit in
- **A single `hub_state` derivation.** A small pure function reads meta-state and
  emits a set of enabled **growth flags** (`office_open`, `vendor_arrived`,
  `path_cleared`, `lights_on`…). The hub scene toggles greybox props/nodes off those
  flags on load. Derived from meta, never stored as run-state — same boundary `p2`
  and `s1` respect.
- **One state drives both directions.** Visible Growth and **Persistence of Failure
  (`v3`)** are the *same* `hub_state` system read two ways: milestones add growth
  flags; failures/neglect can *remove* or *dim* them (decay). Build the mapping once;
  `v3` is its inverse sign. Co-design so a prop doesn't pop in/out on every wipe.
- **Vendors & station as the headline beats.** A vendor "arriving" is the physical
  unlock of the **shop (`h1`)**; the **upgrade station (`h4`)** *already* changes the
  room per purchase — Visible Growth is the same trick at hub scale (whole structures,
  not just one bench). These are the most legible, highest-value growth events.
- **Feature gating.** `RunConfig`/`run_config.gd` knob `hub_growth_enabled` (default
  **off** = bare baseline hub, the permanent control); telemetry on each flag-flip
  (`hub_flag_unlocked(id, trigger, run_number)`) so the gate can ask whether seeing
  the yard grow correlates with players continuing after a loss.

## Research (cited)
- **Hades — House Contractor.** Spend run-recovered materials to add furnishings to
  the House; the hub visibly accrues décor as meta-progress, and Hades II's
  **Crossroads Renewal Project** tiers decorations 1–5 unlocking as you collect — the
  gold standard for "the hub remembers."
- **Darkest Dungeon — the Hamlet.** Buildings shift "from dark and run down to
  well-lit and welcoming" as you upgrade them — *exactly* our derelict→thriving yard
  arc. **Cautionary note from its community:** the cosmetic change "is never seen when
  the improvement actually happens" — so we should **show the growth beat on the
  triggering return**, not silently between sessions.
- Spiritfarer, Cult of the Lamb base, Animal Crossing, Stardew farm: all make
  abstract progress legible as a place that physically fills in over time.

## Open questions
- **[DIRECTOR — scope/art cost] How many hub states can we afford to author?** Every
  growth flag is greybox→art work, and combinations multiply. **Recommendation:** a
  small set of **independent toggles** (5–8 props/areas) keyed to milestones, not a
  hand-authored full-scene per tier — additive flags keep art cost linear.
- **[DIRECTOR — fun/pacing] When do milestones land?** Too sparse and the yard feels
  static; too dense and growth is noise. **Recommendation:** front-load one *early,
  reachable* beat (vendor arrives after the first survived run) so even the first wipe
  comes home to a changed yard — tune at the fun gate / economy model (M3).
- **[DIRECTOR — vision] Growth vs. decay as one system (`v3`).** Should neglect/failure
  *visibly un-build* the yard, and how reversibly? This is the emotional core of the
  contrast pillar. **Recommendation:** one shared `hub_state`; decay dims/ages props
  rather than deleting growth flags, so loss reads as *worn* not *erased*. Flag for the
  Director — it's a tone call, co-decided with `v3`.

Sources:
- [House Contractor — Hades Wiki](https://hades.fandom.com/wiki/House_Contractor)
- [Crossroads Renewal Project — Hades Wiki](https://hades.fandom.com/wiki/Crossroads_Renewal_Project)
- [Every Decoration For The Crossroads In Hades 2 — TheGamer](https://www.thegamer.com/hades-2-crossroads-decorations-prestige/)
- [Hamlet — Darkest Dungeon Wiki](https://darkestdungeon.fandom.com/wiki/Hamlet)
- [Make Hamlet Cosmetic Progression Apparent — Steam Community](https://steamcommunity.com/app/262060/discussions/2/1727575977589403044/)
