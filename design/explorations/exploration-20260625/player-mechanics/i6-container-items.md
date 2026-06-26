# Container Items
**Category:** Inventory as an active system

## The mechanic
A **container** is an item that holds *other* small items, yet itself occupies slots in the bag. A 4-slot tool case might hold 8 slots' worth of small junk — net win — but only if you spend those 4 slots on it. The live decision is **nesting strategy**: carry the container *empty* (4 slots of pure flexibility, fill it with whatever you find deep) or **pre-pack** it before the dive (4 slots already committed to a known-good payload, less reactive room). Containers turn "what's worth a slot" into "what's worth a slot *of structure*."

## What exists today
`run_inventory.gd` is a **flat count-based model**: `items: Array[JunkItem]`, capacity is `sum(slot_size) <= max_slots`. The header is explicit — "Flat top-level slots, no nesting." `can_accept()` already *honors* `ContainmentFlag.PLACEABLE`, and `junk_item.gd` already authors `IS_CONTAINER (1<<1)` and `NO_NEST (1<<2)` flags — so the **data vocabulary for containers exists, the runtime logic does not**.

How big is the change? Moderate, *if* we stay count-based. A container does not need true nested 2D grids: it can be a `JunkItem` that carries its own child `Array[JunkItem]` and its own `inner_max_slots`. `used_slots()` only counts the container's *outer* `slot_size`; the children live "inside" and don't touch the outer budget. That is an additive field + a recursive `can_accept_into(container, item)` and a `NO_NEST`/depth guard — not a model rewrite. A full Tarkov-style nested *spatial* grid (the deferred D1 spatial variant, times N) is the expensive version and is **not** required to make the mechanic interesting.

## How to fit it in
- **Shape system:** under the count model a container is just "a slot bucket with a smaller inner budget." It composes cleanly with sibling `x3` (loadout-vs-cargo): **a container can literally BE the cargo hold** — the cargo region is a single large container item; the loadout is flat top-level slots. That unifies two mechanics into one model.
- **Looting under the ~300s clock (`dive_clock.gd`):** the danger is *fiddle time*. Pre-packing is a **surface (pre-dive) action** with no clock pressure — good. Mid-dive, picking up small junk should **auto-route into a non-full container** (no manual placement), so containers *save* clock time rather than cost it. Manual repack is surface-only.
- **Open-vs-access UX:** under time pressure, do not force a player to open a sub-panel to stuff items. Default: pickups flow into the bag, auto-nesting into eligible containers; the container only "opens" (sub-grid view) on the surface or at the extract gate. RE4's case is calm because it is *paused*; Tarkov's nesting is scary because it is *live* — we want RE4 calm in-dive.
- **RunConfig knob:** `containers_enabled: bool` (off = today's flat baseline) plus `container_auto_nest: bool`. **Telemetry:** per-run `container_carried`, `pre_packed_slots`, `nested_fill_ratio_at_extract`, `empty_container_extracted` (flexibility wasted) — to test whether players actually pre-pack or hoard empties.

## Research (cited)
Tarkov nests backpacks-in-rigs-in-cases for stash efficiency; its **Item case is 8×8 (64) interior for a 16-slot footprint** — a 4× density payoff that motivates carrying structure ([wiki](https://escapefromtarkov.fandom.com/wiki/Item_case), [tarkov.dev](https://tarkov.dev/items/containers)). But live nesting is widely described as "a masochistic mini-game" and Tarkov *tried then reverted* a second-level menu over usability ([UX writeup](https://www.heiolenmarkus.com/blog/escape-from-tarkov-menu-ux-redesign)) — strong evidence to keep in-dive access shallow. RE4's attaché case is the calm counterpoint: same Tetris DNA, but inventory is paused, so packing is satisfying not stressful ([Game8](https://game8.co/games/Resident-Evil-4-Remake/archives/407094), [thegamer](https://www.thegamer.com/best-inventory-systems-horror-games/)). Lesson: **density payoff motivates; UI depth + live access kills it.** Cap nesting at one level and auto-route under the clock.

## Graybox sketch
Add **one** container item: a `tool_case` (`slot_size: 4`, `IS_CONTAINER`, `inner_max_slots: 8`, only accepts items with `slot_size <= 2` and *not* `NO_NEST`). Containers cannot nest in containers (hard depth-1 guard). In-dive, small-junk pickups auto-fill the case until it's full, then overflow to top-level slots. Pre-dive surface screen lets you drag junk into the case to pre-pack. That alone exposes the empty-vs-prepacked choice with zero live sub-menu fiddling.

## Open questions
- **Model cost:** child-array count-model (cheap, recommended) vs true nested spatial grid (expensive, only if `x3`/spatial lands). Confirm we are *not* committing to spatial nesting in M1-era. **(Director call — scope.)**
- **Access-under-pressure:** is auto-nest enough, or do players *want* manual in-dive placement for control? Risk: auto-nest hides where things went. **(playtest — fun.)**
- **Infinite-nesting guard:** lock depth at 1 (containers can't hold containers)? Simplest and dodges recursion/value-density exploits. Recommend yes unless a design reason emerges.
- **Pre-pack vs flexibility balance:** if pre-packing is strictly safer, nobody carries empties. Needs the density payoff *and* deep-band loot that rewards reactive empty space — a tuning question for the economy model. **(Director call — feel.)**
