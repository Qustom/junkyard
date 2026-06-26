# A Shop / Vendor (you walk up to)
**Category:** The hub as the money sink made physical

## The idea
A **place** in the hub — a greybox shop stall with a shopkeeper sprite and a
walk-up interactable — that, when you press *interact* in front of it, opens the
buy UI (the gear/consumable spend side of `s1`/`s2`). Functionally it's trivial:
the same purchase menu could live behind a button. The value is **spatial**.
Once buying is a *location*, you can **stagger unlocks**: the hub ships with one
vendor and **new vendors physically appear** (a boarded stall opens, a shade
moves in, a light turns on) as you hit milestones. The hub then **visibly grows
with your success** — empty lot → a couple of stalls → a busy market. That
growth is free narrative payoff for progression you were tracking anyway, and it
makes the GDD's "town heals" tone contrast (against the unsettling yard) into
something the player *watches happen* rather than reads about.

## What exists today
Honest read: **there is no hub scene.** The flow is menu → dive
(`main_game.tscn`) → sell → repeat; the buy side doesn't exist at all yet (see
`s1`: no shop, no `Upgrade` Resource, no `owned_upgrades` meta). But the
*economic* substrate is real and persistent:
- **Money/meta persist** across runs (`game_state.gd:33-35`: `money`, `salvage`,
  `lore`) and survive everything but `wipe_meta()`.
- **A sell screen already exists** (F2) — the cash-*in* seam after a run. The
  vendor is its mirror: the cash-*out* seam, made physical.
- **The run/meta boundary** (`game_state.gd`) is exactly where a hub belongs:
  the hub is **pure meta-state** (you spend banked Money there, between runs).
What's missing: the hub scene itself, the walk-up interactable, the buy UI, and
the unlock-tracking meta that decides which vendors are present.

## How it could fit in
- **A new `hub.tscn` scene** sitting between `run_ended`/SellScreen and the next
  `start_run` — the first non-dive walkable space. Greybox: a `TileMap` room, the
  player controller reused, and `Area2D` interactables.
- **A `Vendor` node**: a sprite + an `Area2D` "prompt zone"; on *interact* it
  opens the gear shop (`s1`) or consumable loadout (`s2`) UI. The vendor is the
  spatial wrapper; the menu is the existing `s1`/`s2` work.
- **Staggered presence, driven by `unlocks` (`p2`'s wipe-protected meta field).**
  Each vendor has an `unlock_id`; on `hub.tscn` `_ready()`, present-or-hidden is
  derived from `GameState.unlocks` (e.g. Gear vendor from run #1; a Tinker/repair
  vendor after banking a band-2 item; a Lore broker after Knowledge tier 2). This
  is `g1` *visible growth* expressed as room state. Milestone-gated, **not**
  cash-gated, so it doesn't compete with the spend-vs-quota tension `s1` owns.
- **Feature gating:** a `RunConfig.hub_enabled` knob, default **off** =
  today's menu→dive baseline (the permanent control). Telemetry:
  `vendor_unlocked(id, run_number)`, `vendor_visited(id)`,
  `hub_dwell_time` — so the gate can read whether the growing hub draws visits.

## Research (cited)
- **Hades — House Contractor + Wells of Charon.** The Contractor is a *walk-up*
  shade in the main hall who sells house furnishings for meta-currency, with
  **prerequisite-gated** purchases that physically populate the hub over time —
  the canonical "hub grows as you spend." The Wells of Charon are the *run-side*
  walk-up vendor (staggered: never on run #1, never first four chambers). Together
  they model both poles; our hub vendor is the **House/meta** pole.
- **Darkest Dungeon — Hamlet.** A hub of *buildings* (stagecoach, sanitarium,
  blacksmith) you walk between and **upgrade with heirlooms**; the hamlet visibly
  improves — the template for "the town heals as you progress."
- **Deep Rock — Space Rig.** Walk-up stations (equipment terminal, perk board,
  resource trade) in a shared physical hub; the spatialized between-mission
  staging space we're approximating in single-player.
- **Tarkov — traders.** Staggered vendor *unlocks* and loyalty tiers gate what
  each trader sells — the chained-prerequisite model for vendor pacing.

## Open questions
- **[DIRECTOR — scope] One vendor or many for the first cut?** A single "general
  store" wrapping `s1`+`s2` is the cheapest greybox; multiple themed vendors
  (Gear / Tinker / Lore) is what makes staggered-unlock *visible*.
  **Recommendation:** ship **one** vendor with `hub.tscn` (prove the walk-up + buy
  seam), then add the 2nd/3rd as the unlock-growth showcase once `s1`/`s2` data
  exists. *Scope call.*
- **[DIRECTOR — fun/pacing] Unlock pacing.** Too fast and the hub fills before the
  growth reads as reward; too slow and it stays barren. Recommend the **first**
  extra vendor on an early reachable milestone (≈ run #3 / first band-2 bank).
  *Tuning — M3 economy model + playtest.*
- **Menu-in-place vs full-screen UI?** A diegetic in-world panel preserves the
  "place" feel but is more layout work; reusing the F2-style full-screen buy UI is
  cheaper and consistent. *Recommendation: full-screen UI for the greybox, revisit
  diegetic later. UX call — defer to `ui-ux-designer`.*
- **Does the hub replace or coexist with the current menu→dive flow?** Adding a
  walkable hub changes the core between-run rhythm — a **vision call** about
  whether the game wants a Hades-style social hub at all. *Flag for the Director.*

Sources:
- [House Contractor — Hades Wiki (Fandom)](https://hades.fandom.com/wiki/House_Contractor)
- [Well of Charon — Hades Wiki (Fandom)](https://hades.fandom.com/wiki/Well_of_Charon)
- [Hamlet — Darkest Dungeon Wiki (Fandom)](https://darkestdungeon.fandom.com/wiki/Hamlet)
- [Space Rig — Deep Rock Galactic Wiki](https://deeprockgalactic.wiki.gg/wiki/Space_Rig)
