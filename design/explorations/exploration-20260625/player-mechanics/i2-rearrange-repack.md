# Rearrange / Repack
**Category:** Inventory as an active system

## The mechanic
You manually tetris your carried junk to open a contiguous slot for something you
want to grab. The big idea: **inventory management becomes real-time pressure, not
a safe menu.** A 3-slot reactor core is on the ground, but your free space is
fragmented; you have to shuffle a battery and a coil aside to make room — and the
Hunter is closing, the clock is ticking. The repack is a *diegetic act under
threat*, the same beat as reloading in cover. The fantasy: a hoarder frantically
re-stacking the trunk while someone bangs on the door.

This only has teeth if (a) the inventory is **spatial** (fragmentation can happen)
and (b) the dive clock / pursuers **keep running** while you repack.

## What exists today
Honest read: **neither precondition is met yet.**

- `systems/inventory/run_inventory.gd` is a **count-based** model — `max_slots: int`,
  items sum `slot_size` against capacity (`used_slots()`/`free_slots()`). The class
  doc is explicit: "the carry-choice tension comes from value-vs-space, **not from
  spatial packing**." There is no grid, no position, no rotation, no contiguity —
  so *fragmentation cannot exist* and there is nothing to rearrange. `JunkItem`
  carries a `grid_footprint: Vector2i` field, but it is flagged "advisory in M1"
  and unused by the model.
- `D2_inventory_ui.md` is a **persistent HUD projection** (cell-per-item + empty
  placeholder cells), rebuilt on `run_inventory_changed`. It even resolved against
  drag/selection: "the chosen drop gesture is a discrete action with no held
  selection, so it does not need diffing." A repack interaction would reintroduce
  exactly the held-drag state it deferred.
- The clock **does** keep running today (`DiveClock` is `_process`-driven), **but**
  it is `PROCESS_MODE_PAUSABLE` — so the moment any overlay calls
  `get_tree().paused = true`, the clock (and the whole dive) freezes "for free,"
  as its own doc notes. The SellScreen already presents over a paused tree.

So: to make repack *real*, the inventory must become spatial (a real D1 rework),
and the repack overlay must **not** pause the tree.

## How to fit it in
**THE PAUSE DECISION is the whole design.** Two opposed builds:

- **Real-time repack (diegetic):** opening the bag does *not* pause. Clock drains,
  Hunter/Thief keep moving while you drag tiles. Fumbling costs you. Maximum
  tension; risk of frustration if the grid is fiddly.
- **Paused puzzle (safe):** opening the bag pauses the dive. Calm optimization, no
  pressure — repack is just admin. Lower stress, lower stakes.

Wiring, real-time variant:
- A repack overlay set to `PROCESS_MODE_ALWAYS` (or simply *don't* pause the tree),
  so `DiveClock`, pursuers, and the Thief tick underneath it. Movement could be
  locked or slowed while repacking — a deliberate sub-knob (you're rooted, head
  down in the trunk).
- **Looting interaction:** a pickup that doesn't fit prompts "repack to fit?"
  rather than a flat reject. The Thief (`6-thief.md`) makes this vicious — it can
  grab loose junk while your hands are full mid-repack. The Hunter
  (`5-the-hunter.md`) makes the *time cost* lethal.
- **Control mapping:** hold a key to enter repack; drag-drop or D-pad/grid-cursor
  to move tiles (controller parity matters per the L6 twin-stick rework).
- **RunConfig knob — a near-perfect A/B:** `repack_pauses_clock: bool` (plus
  `repack_grid_enabled`, `repack_locks_movement`). All-off reproduces today's
  count model exactly (the standing baseline contract). Run the *same* spatial
  build with pause on vs off and compare.
- **Telemetry (config-marked):** repacks/run, seconds in repack overlay, clock lost
  during repack, deaths/thefts *during* a repack, and pickups abandoned because
  repack was too slow. These directly answer "tension or frustration?"

## Research (cited)
Real-time-under-threat inventory is proven tense. **Resident Evil** famously does
*not* pause while you organize, "transforming every second spent organizing items
into calculated risk" — the interface itself becomes a source of vulnerability;
RE Outbreak leaned in further with fewer slots to keep selection fast under live
threat ([pekoeblaze](https://pekoeblaze.wordpress.com/2023/03/12/when-survival-horror-games-dont-pause-the-inventory-screen/),
[iABDI "Menu Anxiety"](https://www.iabdi.com/designblog/2025/5/22/menu-anxiety-how-horror-games-weaponize-interface-design-against-players)).
**Tarkov** is the cautionary tale: its spatial grid is genuinely Tetris — rotate,
stack, compress — and players resent how much time it eats ("stash Tetris instead
of raids"); in-raid it *doesn't* pause, which is exactly our tension but also its
fatigue ([Eye On Annapolis](https://www.eyeonannapolis.net/2025/10/escape-from-tarkov-smart-inventory-management-guide/)).
The lighter end: **Minecraft**'s hotbar and **Don't Starve**'s small slot bar keep
selection fast and forgiving, trading deep packing for low friction
([Don't Starve analysis](https://annamalecki.medium.com/game-design-analysis-dont-starve-50d06561097d)).
Takeaway: real-time repack is tense *if the grid is small and snappy*; a deep grid
turns tension into chore.

## Graybox sketch
Smallest version that proves the beat is fun, not just annoying:
- Convert `RunInventory` to a tiny **spatial grid** (e.g. 4×3) reading
  `JunkItem.grid_footprint`; no rotation yet (defer — it's the Tarkov-fatigue
  amplifier). Keep the count model behind the all-off knob.
- One pickup that *only* fits after a single shuffle, placed where a pursuer must
  be near. Movement locked while the overlay is open.
- Ship `repack_pauses_clock` and play both back-to-back on the same seed. If the
  real-time version reads as "exciting scramble," it's in; if it reads as
  "fighting the cursor," tune grid size/snap before judging the *idea*.

## Open questions
- **[DIRECTOR — central vision/fun call] Does opening the bag pause the dive
  clock?** This is *the* decision; everything else is downstream.
  **Recommendation:** ship spatial inventory with `repack_pauses_clock` and
  playtest **real-time (pause OFF) as the intended target**, pause-ON as the
  control. The diegetic real-time repack is the only version that delivers the
  pitch ("manage inventory while chased"); a paused puzzle is just Tarkov stash
  admin with a worse name. Mitigate the frustration risk with a *small, snappy,
  no-rotation* grid (per the research) rather than by pausing. The Director judges
  the A/B telemetry + feel at the gate.
- **Is the D1 spatial rework worth it?** Spatial packing was *deliberately cut* in
  M1 (D1 Open questions). Repack is the strongest reason to reopen it — but it's a
  real model rework + UI drag-state, not a knob. Scope/date call for the Director.
- **Movement during repack:** rooted (max tension, you're committed) vs walk-while-
  repacking (forgiving, but trivializes the threat). Lean rooted; knob it.
- **Does it overlap the Thief/throw mechanics too much?** Repack, throw-as-bait,
  and drop-to-swap all compete for the "manage the bag under pressure" niche —
  confirm they're complementary, not redundant, before committing build effort.

**Summary:** Repack-under-pressure needs two things the build lacks today — a
*spatial* inventory (the count model can't fragment) and a *non-pausing* overlay
(the clock currently freezes on any pause); ship both behind a `repack_pauses_clock`
A/B knob and let the Director judge real-time-vs-paused at the playtest gate.
