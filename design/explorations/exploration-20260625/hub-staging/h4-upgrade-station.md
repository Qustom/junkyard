# An Upgrade Station
**Category:** The hub as the money sink made physical

## The idea
A **place you walk to** — a workbench / engineering bay tucked in the junkyard hub —
where banked Money becomes *permanent capability*. The defining move: **each purchase
visibly changes the world or your kit, not just a hidden stat.** Buy the bag upgrade
and the actual extraction grid on the wall gains a row of cells you can see. Buy the
**dash module** (`m1`) and a greybox "dash rig" gets bolted to the workbench, then a
device appears on the player sprite next run. Buy **quick-throw slots** (`x3`) and a
new bandolier hook lights up. The station is the **s1 gear-upgrade tree given a
physical body** — you read your progress by looking at the room, not at a number.

This is the literal answer to "what is Money *for*." The vendor sells things you
consume; the station sells things you *become*.

## What exists today
Honest read of the real build:
- **The GDD names "yard upgrades" as canon meta** — a surface progression track. So
  the *concept* is blessed; the *home for it* is not built.
- **s1 (gear-upgrades) is the system this spatializes** — but s1 itself is still an
  exploration spec, not code. There is **no `Upgrade` Resource, no `owned_upgrades`
  meta field, no upgrade UI, no apply-at-`start_run` seam** yet.
- **Money persists.** `game_state.gd:33` (`money`, meta), debited via
  `add_currency(&"money", -cost, …)` (`:300`, negative deltas already supported);
  wiped only by `wipe_meta()` (`:410`).
- **No hub scene exists** — the station is a **NEW scene**, the same greybox room
  that would also host the vendor (h1).
**Missing:** everything between "Money sits in a number" and "Money changed my run."

## How it could fit in
- A **greybox station room** (a `ColorRect` bench + interaction zone) inside the hub
  scene, separate from the vendor stall. Walking up opens an upgrade panel reading the
  **s1 catalog `.tres`**: grid size (`i1`-expand), dash (`m1`), quick slots (`x3`),
  trajectory preview (`t3`). Selecting debits Money and writes `owned_upgrades` (the
  s1 meta field), applied at `start_run` per s1's run/meta-boundary seam.
- **Visible install feedback is the whole identity.** On purchase: the panel item
  flips to "INSTALLED," a greybox module sprite appears on the bench, and the
  hub-side preview of the grid/kit updates immediately — a small Tween/flash sells
  it even at greybox fidelity. The diff from a pure menu is *spatial confirmation*.
- **Differentiate from the vendor (h1).** Vendor = **buy items/consumables** (loot,
  one-shot throwables) that you carry into a run and use up. Station = **buy permanent
  capability** (the grid, the dash, slots) that changes you forever. Vendor inventory
  rotates; station purchases are **one-time, tiered, visible**. Two stalls, two verbs:
  *spend to stock up* vs *spend to grow*.
- **Permanent vs resettable (`p4`).** The station inherits s1's flagship reset-severity
  call: do station purchases survive a quota wipe? Recommend the first cut match s1's
  recommendation (wipe-clears, `owned_upgrades` added to `wipe_meta()`) so the room
  visibly *empties* on a wipe — a powerful, legible stakes signal — then A/B
  wipe-proof gear if it stings too hard. **Director call; flag.**
- **Feature gating.** Wrap behind a `RunConfig`/hub flag (`upgrade_station_enabled`,
  default **off** = today's baseline) so it ships dark and lights up for playtest.

## Research (cited)
Visible capability growth is the genre's proven dopamine lever:
- **Hades — Mirror of Night.** A *physical object in your room* you walk to; spending
  Darkness permanently buffs you, and it's **respeccable for a few keys**. The model
  for "a place, not a menu" and for the resettable pole of `p4`.
- **Tarkov — Hideout stations.** The strongest "purchase changes the *space*" case:
  each module is a **built room you see**, with **chained prerequisites** (modules gate
  modules). Direct support for tiered/prereq station upgrades whose state is read off
  the environment.
- **Dead Cells — the Forge/Blacksmith.** A discrete NPC station you visit to spend
  Cells on *permanent* gear-quality upgrades — vendor-adjacent but firmly on the
  permanent-capability side, like our station vs h1's vendor.
- **Rogue Legacy — castle.** Spend kept gold to **build rooms onto a castle that
  visibly grows** — the cleanest "money sink you can see expand" precedent, and its
  rising Labor Costs are the anti-saturation lesson for station pricing.
- **Subnautica — fabricator/base pieces.** Placed upgrades physically appear in your
  base; capability literally occupies space — the purest "buy = world changes" pole.

## Open questions
- **[DIRECTOR — overlap] Where's the line vs the vendor (h1)?** If both are stalls in
  one room, is "permanent vs consumable" a clear enough split for players, or do we
  risk two confusingly-similar shops? **Recommend** one shared hub room, two visually
  distinct stations, copy that frames them as *stock up* vs *grow*. *Fun/clarity call.*
- **[DIRECTOR — scope] How much visible-change per purchase, vs cost?** Bespoke
  install art for every upgrade is expensive. **Recommend** a cheap shared idiom for
  the first cut (slot-in module silhouettes + a grid that grows) and reserve bespoke
  visuals for the 1–2 flagship buys (dash, grid). *Scope/art-budget call.*
- **[DIRECTOR — `p4` coupling] Does the station empty on a wipe?** The room's
  visible-state makes reset-severity *legible* either way — a powerful but punishing
  signal. Recommend matching s1 (wipe-clears) for the first cut; A/B wipe-proof.
  *Severity/fun call — must playtest.*
- **One-time vs tiered display.** Tiered axes (grid L1→L3) need the room to show
  *which tier* you own. Recommend supporting tier display from day one so the art
  idiom doesn't need reworking. *Technical — resolvable on merit.*

Sources:
- [Mirror of Night — Hades Wiki (Fandom)](https://hades.fandom.com/wiki/Mirror_of_Night)
- [Hades' Mirror of Night Does Upgrades Right — TheGamer](https://www.thegamer.com/hades-mirror-of-night-roguelite-progression/)
- [Hideout — Official Escape from Tarkov Wiki (Fandom)](https://escapefromtarkov.fandom.com/wiki/Hideout)
- [The Blacksmith — Dead Cells Wiki (Fandom)](https://deadcells.fandom.com/wiki/The_Blacksmith)
- [Runes and upgrades — Official Dead Cells Wiki](https://deadcells.wiki.gg/wiki/Runes_and_upgrades)
- [Upgrades — Rogue Legacy Wiki (Fandom)](https://rogue-legacy.fandom.com/wiki/Upgrades)
