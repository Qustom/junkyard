# Optional Modifiers
**Category:** Risk/reward dials

## The mechanic
Before a dive, the player can opt into a stack of **harder-run modifiers** —
faster/awakening-sooner hazards, a shorter dive timer, denser spawns, a costlier
return, tighter vision — each of which raises a **run-wide value multiplier** on
everything banked that dive. Difficulty becomes a *money lever the player pulls*:
take a calmer run for a safe baseline payout, or stack pressure for a 1.5–3× haul
and a much higher chance of dying with full pockets. It sharpens the core
extraction gradient (the deeper/longer you push, the more you make and the more
you risk) by letting the player **dial the gradient's steepness up front**, not
just discover it mid-dive.

## What exists today
This is the cheapest big win in this exploration set, because the engine is
**already a modifier engine**. `data/run_config/run_config.gd` is a fully-built,
typed knob bank — `r1_chase_speed`, `r1_linger_seconds`, `r1_spawn_count`,
`r1_per_room_density`, `timer_length_s`, `hpp/hbomb/hspike` counts, `r4_*` vision
— each with an `enabled` master toggle, an all-off baseline default, and
`to_flat_dict()` telemetry serialization. It was built for the M1.1+ A/B sweeps:
the Director already authors "harder run" configs by hand
(`make_default_play_preset()`). **Optional modifiers are simply exposing a
curated, named subset of those same knobs to the *player* and coupling each to a
reward multiplier.** The plumbing (CFG menu → `GameState.active_run_config` →
every system reads it) is done and proven.

What's missing is small: (1) a **player-facing modifier-select** screen (a
friendlier `config_menu`), (2) a **multiplier field** on the config and the
coupling into the F1 money ledger / value-on-bank path, and (3) per-modifier
multiplier weights.

## How to fit it in
- **Data:** add `value_multiplier: float` (and per-modifier weight constants) to a
  thin player-facing preset layer that composes a `RunConfig` from a few **named
  modifier cards** (e.g. "Restless Yard" = lower `r1_linger_seconds` + higher
  `r1_chase_speed`; "Short Fuse" = `timer_length_s` −90s; "Swarm" = +`*_count`).
  Each card carries a `+X%` weight; the run multiplier is the product (or capped
  sum) of selected cards.
- **Economy coupling:** apply the multiplier where junk value is realized — at
  bank/extract in the F1 ledger (`data/economy/run_rules.gd` /
  `F1_money_ledger.md`), *not* per-item, so it reads as one clean payout boost. It
  multiplies banked Money; whether it also boosts Salvage/Lore is an open call.
- **Quota synergy:** a steeper quota (K2, `quota_step`) is the natural pressure a
  multiplier answers — modifiers become the *intended* way to clear a quota you've
  fallen behind on, turning the difficulty curve into player agency.
- **Telemetry:** `to_flat_dict()` already snapshots every knob onto `run_started`;
  add the multiplier + selected-card list so the gate can read **modifier choice
  vs. success-rate vs. banked-value** and find the multiplier that makes hard runs
  +EV-but-riskier rather than dominant or dead.

## Research (cited)
The pattern is well-proven. **Deep Rock Galactic**'s Hazard Bonus is the closest
analogue: credits/minerals/XP scale by a **1.25×–4.00× multiplier** built from
hazard level + warnings + cave complexity/length — exactly a "harder dive = bigger
multiplier on what you extract" mapping, which is this mechanic verbatim.
**Hades**' Pact of Punishment lets you toggle individual Conditions (each adding
"Heat") to unlock Bounty rewards — a *menu of stackable modifiers*, the UX model
to copy for the card list. **Slay the Spire**'s Ascension stacks cumulative
challenge modifiers for a flat **+5%/level score** bonus — the simple, legible
"more difficulty → linear reward" anchor. **Risk of Rain** ties a continuously
rising difficulty clock to better drops, the spiritual root of opt-in difficulty
multipliers. The consistent lesson: keep the reward **legible and bounded**, cap
the stack, and tune so the hardest tier is enticing but not strictly optimal.

## Open questions
- **Which knobs to expose?** Hazards-faster + timer-shorter read cleanly as
  "harder = more money"; vision/maze (`r4_*`) and costlier-return (`r2_*`) are
  more about frustration than thrill — likely cut from the player-facing set even
  though the knobs exist. **Director call.**
- **Multiplier math & degenerate stacking.** Product vs. capped sum; a hard ceiling
  (DRG caps at 4×); whether a single mega-modifier or a 3-card stack is the model.
  Avoid a "stack everything for free money" exploit where skill trivializes the
  added risk.
- **Money only, or all three currencies?** Boosting only Money keeps Salvage/Lore
  as steady non-gambled tracks; boosting all three makes modifiers a global power
  lever. **Director call** (touches the 3-currency identity).
- **Readability.** Does the player feel the multiplier *earned* it (clear "you
  banked 2× because you ran Hard")? Needs the F2 sell screen to show the bonus
  line explicitly.
- **Note:** this is a **cheap win on existing tech** — the riskiest part is tuning,
  not building. Recommend it as a strong M-tier candidate once a quota exists to
  give the multiplier a purpose.

Sources:
- [Deep Rock Galactic — Hazard Bonus (Official Wiki)](https://deeprockgalactic.wiki.gg/wiki/Hazard_Bonus)
- [Deep Rock Galactic — Difficulty Scaling (Wiki)](https://deeprockgalactic.fandom.com/wiki/Difficulty_Scaling)
- [Hades — Pact of Punishment (Fandom Wiki)](https://hades.fandom.com/wiki/Pact_of_Punishment)
- [Hades Pact of Punishment: Heat, modifiers and rewards (RPG Site)](https://www.rpgsite.net/feature/10287-hades-pact-of-punishment-heat-modifiers-and-how-to-maximize-your-rewards)
- [Slay the Spire — Ascension (Fandom Wiki)](https://slay-the-spire.fandom.com/wiki/Ascension)
- [How Modern Roguelikes Are Becoming Approachable (SUPERJUMP / Medium)](https://medium.com/super-jump/how-modern-roguelikes-are-becoming-approachable-63ad844bbc27)
