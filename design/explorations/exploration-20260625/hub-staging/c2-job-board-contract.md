# A Job Board / Contract Picker
**Category:** The hub as run-selection / commitment

## The idea
A job board is a physical fixture in the hub — a corkboard, a buyer's terminal, a
clipboard nailed to the handler's shack — that the player walks up to and reads
*before* departing. It is the diegetic front-end for **selecting** the next run's
shape instead of having it rolled at you. At the board you do three things:

1. **Read the quota terms** — what you owe this run (the K2 bar, e.g. "$50 due,
   any run end, cumulative"). The terms are *shown*, not silently enforced.
2. **Pick a modifier-for-multiplier** — accept a harder run for a richer payout
   ("Deep contract: hazards up, value ×1.5"). This is a curated `RunConfig`
   preset, not a random mutator.
3. **Accept a buyer's order** — a demand for a specific salvage type at a premium
   ("Cyrus wants 3 copper coils, ×2 price"), the m2 demand-order layer.

The key shift this room embodies: **run variety becomes a menu, not a dice roll.**
You commit knowingly — you saw the terms and chose them — which makes the
extraction stakes feel *authored by you* rather than imposed.

## What exists today
Honest read: the **commitment seam already exists in code**, headless and faceless.
`GameState.stage_run_config(config)` (`systems/game_state.gd` ~157-175) lets any
caller stage the `RunConfig` the next `start_run()` will adopt; an all-off default
reproduces the M1.0 baseline. `RunConfig` (`data/run_config/run_config.gd`) is
already a rich, fully-typed preset object, and `make_default_play_preset()` proves
a curated "stack of knobs" *is* a sellable, named contract. **K2 quota**
(`design/M1_4_Tasks/K2_quota_system.md`) supplies the terms to display. The
modifier/objective/order economics are designed in the cross-referenced
`r1-optional-modifiers.md` (harder-for-multiplier), `q3-quota-variety.md`
(objectives), and `m2-demand-orders.md` (buyer orders).

What's **missing** is the *diegetic, player-facing front-end*: there is no hub
scene, no interactable board, and the only way to stage a config today is the
out-of-fiction CFG debug menu. The board makes staging a place you *visit*.

## How it could fit in
A greybox `Area2D` board interactable in a new hub scene. Interact → a `Control`
panel listing a small set of contract cards (each card = a pre-authored
`RunConfig` preset + a display string for its quota terms / objective / order +
the value multiplier). Selecting a card calls `GameState.stage_run_config(preset)`
and stamps the chosen objective/order onto run-state. You then walk to the
**departure point** (`c1-departure-point.md`) and step through to begin the run
the board staged. No new commitment plumbing — it dresses the existing seam.

This turns the CFG debug menu's raw-knob staging into **agency**: instead of RNG
deciding your run's flavor, you read the offers and pick your fight. **Feature
gating:** ships behind a config flag, all-off = today's direct-to-dive flow
(board absent, default preset auto-staged), so the M1 baseline is untouched and
the board is measured as an additive cohort.

## Research (cited)
Prior art splits on the **selected vs. rolled** axis this topic turns on:

- **Deep Rock Galactic** is the closest match: the player *chooses* a Hazard
  Level and mission Mutators at a mission-select terminal; the chosen hazard
  feeds a **Hazard Bonus that scales end rewards** — explicit harder-for-more.
  This is exactly the modifier-for-multiplier card.
- **Stardew Valley Special Orders**: a physical *board*, **two offers shown, pick
  one per week**, refreshed Mondays — a tight, low-paralysis menu. Notably the
  community modded in a *reroll button*, signalling players want a touch more
  control than pure refresh.
- **Darkest Dungeon** quest select: weekly randomized quests with finite
  rewards create *urgency* (grab the good trinket now) — a different lever, scarce
  rolled offers rather than chosen modifiers.
- **Hunt: Showdown** bounties are randomized (random map/time/boss), **not**
  player-selected modifiers — the contrast case showing why a *board* reads as
  agency where a matchmaker reads as fate.
- **Monster Hunter / Witcher notice boards**: the genre-standard "wall of jobs"
  fiction that makes selection feel like a working life, grounding the GDD's
  surface-life handler giving out jobs (`design/Junkyard_GDD.md`).

The lesson across all five: **a small curated set read at a place** feels like
agency; a large or hidden roll feels like fate. THE FAR YARD already has the
preset machinery to land on the agency side.

## Open questions
- **How many cards before paralysis?** Stardew's 2 vs. DRG's hazard-ladder + many
  mutators. Recommend starting **2–3 contract cards** (one "standard," one
  "harder-for-more," one buyer order) — *fun/scope call, flag for Director.*
- **Reroll cost?** Do offers refresh free, on a timer, or for a currency sink
  (Money/Salvage)? A paid reroll is an economy lever — cross-ref the economy
  model before committing. *Scope: likely post-M1.*
- **Does selection kill good RNG surprise?** Fully-chosen runs lose the "what will
  I get" thrill. Possible hybrid: *you choose the modifier, but the band layout /
  loot rolls stay seeded-random underneath* — agency over the frame, surprise in
  the content. *Vision call, flag for Director.*
- **Overlap with the intel table (c3)?** A board that *shows quota terms / hazard
  forecasts* risks duplicating an intel/preview fixture. Seam: the board is
  **commit** (pick + accept), the intel table is **inform** (read forecasts). Keep
  them distinct or merge — *Director call once c3 is read.*
- **Run-state vs. meta boundary:** accepted orders/objectives are run-scoped; only
  *completion credit* (quota met, order filled → payout) crosses to meta. Honor
  the hard boundary in `game_state.gd`.

## Sources
- [Difficulty Scaling — Deep Rock Galactic Wiki](https://deeprockgalactic.wiki.gg/wiki/Difficulty_Scaling)
- [Bounty Hunt — Hunt: Showdown 1896 Wiki](https://huntshowdown.wiki.gg/wiki/Game_Modes/Bounty_Hunt)
- [Stardew Valley: Every Special Order & Rewards — TheGamer](https://www.thegamer.com/stardew-valley-every-special-order-rewards/)
- [Choosing a quest — Darkest Dungeon Wiki](https://darkestdungeon.fandom.com/wiki/Choosing_a_quest)
- [Better Special Orders (reroll mod) — Stardew Valley Nexus](https://www.nexusmods.com/stardewvalley/mods/24125)
