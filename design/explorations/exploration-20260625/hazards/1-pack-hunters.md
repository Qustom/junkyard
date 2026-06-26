# Pack Hunters
**Category:** Pursuers & movement enemies

## The idea
Individually trivial enemies — slow, low threat, killed by a single thrown item — that become
dangerous **only in numbers (3+)** because they **flank and surround**: instead of all running
straight at you, they spread to approach from different angles and try to *encircle* you so
there's no clean escape lane.

The behavioral distinctness: the R1 pursuer is a one-body footrace solved by distance. Pack
Hunters can't be solved by distance because there's always one *behind* you. They force a
**positional** decision the rest of the roster doesn't: *keep your back to a wall*, fight in a
corner or doorway, and never let yourself get pulled into open floor. They convert the game's
open-room geometry from neutral space into something you actively read for chokepoints. They
make the throw verb a *crowd-control* tool, not a single-target punish.

## How it fits THE FAR YARD
- **Move:** the core skill is denying the encirclement — backing into a corner, fighting
  through a doorway, never standing in the open. This reuses existing movement; the enemies
  do the new thing (flanking).
- **Throw:** one item kills one hunter, but you can't out-throw a swarm with a limited bag —
  so throwing becomes *triage* (kill the one closing the encirclement). It makes inventory
  scarcity bite: do you spend three sale items to break a pack, or run and accept a hit?
- **Extract pressure:** a pack between you and the gate is a *commitment* problem — fight
  through (spend items + time) or find another route (spend more time). Pure push/cash-out.
- **Systems reused:** lightweight `HazardEntity` variants on the `hazard` layer (throw-killable
  via `queue_free`). The pack behaviour is a coordinator: assign each member an *approach
  angle* offset around the player rather than a direct vector — a small steering tweak, no
  navmesh. Knob group `pk_*` (`pk_count`, `pk_flank_spread`, `pk_speed`), off by default.
- **First appears:** Band 1 in pairs (harmless), Band 2+ in real packs of 3–5 — the danger
  scales with the GDD's instability/`I` band ramp (more bodies as a zone destabilises).

## Graybox sketch
A spawner drops N (start 3) slow circles. Each picks an `approach_angle` around the player
(evenly distributed, jittered) and steers toward `player_pos + angle_offset`, so they fan out
and converge. State per member: `APPROACH` → `SURROUND` (hold position around you) → `LUNGE`
(close in). Smallest proof: 3 circles that visibly *fan around* you in open floor but *can't*
get behind you when you back into a corner — does "find the wall" feel like the right answer?

## Synergies & counters
- **+ corridors/chokepoints:** a doorway negates the flank entirely — the level design is the
  counter, which is the point.
- **+ Charger/Leaper:** a pack that herds you toward a Charger's lane or a Leaper is a nasty
  depth combo.
- **Counters:** back to a wall (free, positional skill), throw the encircler (costs items),
  or instability-aware routing to avoid open rooms when packs are active.

## Open questions
- Real coordinated flanking (shared blackboard) vs. cheap per-member angle-offset — the cheap
  version *looks* like flanking without a coordinator. **Recommend cheap version first; only
  build a coordinator if it doesn't read as surrounding.**
- Pack size scaling: fixed `pk_count` vs. tied to instability `I` (packs grow as the zone
  destabilises). **Recommend I-tied at depth — flag to Director for the fun curve.**
- Do hunters retreat/regroup when reduced below a threshold, or fight to the last? Retreat is
  more lifelike but can feel like the kill "didn't count." **Recommend fight-to-last for clarity.**
- Are individual hunters fatal on contact, or chip damage? With no HP system, chip damage
  needs a player-health model we may not have in greybox. **Likely fatal-on-grab; flag scope.**
