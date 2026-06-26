# Patroller (Vision Cone)
**Category:** Pursuers & movement enemies

## The idea
An enemy that walks a **fixed route** and only becomes hostile if you enter its **vision cone**
— a forward-facing wedge that sweeps as it turns at each waypoint. Stay out of the cone and it
never notices you; trip the cone and it converts to a chaser (reuse the R1 pursuer behaviour).

The behavioral distinctness: every other pursuer is a *reactive* threat triggered by proximity.
The Patroller is a *predictable* one — its danger is a **legible, learnable pattern in space and
time**. It turns a room into a stealth/timing puzzle: watch the loop, find the gap, cross while
the cone points away. It is the enemy that rewards *patience and observation* over reaction
speed, and it's the natural home for the GDD's "avoidance is always viable / stealth is
first-class" pillar (the breather-rig sound-muffle fiction lives here).

## How it fits THE FAR YARD
- **Move:** the whole interaction is timing your crossing against a known sweep — pure movement
  skill, no new verbs. The player learns the loop, then threads it.
- **Loot:** the best use is *guarding loot* — park a Patroller's route around a high-value
  pickup so grabbing it (press F, takes a beat) means timing the grab inside a safe window.
  This makes the loot verb a *stealth beat*.
- **Extract pressure:** waiting for the cone to point away costs dive-clock seconds; rushing
  trips the cone and starts a chase that costs more. The clock makes patience expensive — a
  clean push/cash-out micro-decision per Patroller.
- **Systems reused:** `HazardEntity` with a waypoint list (patrol) + a cone detector. The cone
  is an `Area2D` wedge child (or a forward raycast fan) that emits on `body_entered` with the
  player; on detect → flip to the existing chase state; lose line-of-sight (the I2 wall-refuge
  already exists) → return to patrol. Knob group `pat_*` (`pat_cone_angle`, `pat_cone_range`,
  `pat_speed`, `pat_aggro_persist_s`), off by default.
- **First appears:** Band 1 as the gentle intro to stealth (slow sweep, narrow cone), Band 2+
  with wider cones, faster sweeps, and overlapping routes.

## Graybox sketch
States: `PATROL` (move along waypoints, cone = a visible debug wedge rotating to face travel
dir) → `ALERT` (player entered cone: brief telegraph) → `CHASE` (reuse R1 chase) → `SEARCH`
(lost the player: return toward last-seen, then back to `PATROL`). Smallest proof: one
Patroller on a 4-point loop with a drawn cone and one guarded pickup — does "watch, wait, grab,
slip out" feel like a satisfying little heist? No art; the cone is a `Polygon2D` wedge.

## Synergies & counters
- **+ throw as distraction:** a thrown item could *draw the cone* (look toward the impact) —
  a stealth use of the throw verb distinct from killing, matching the GDD's "toss a noisy
  part" line. Strong synergy worth prototyping.
- **+ Ambusher/Pack:** a Patroller cone that herds you into an Ambush or a corner-pack is a
  layered depth threat.
- **Counters:** time the crossing (free), break line-of-sight on a wall (existing I2 refuge),
  throw to distract, or — last resort — throw-kill it during a safe window.

## Open questions
- Does the cone see *through* junk/walls, or is it occluded? Occlusion (raycast) is the honest,
  satisfying version but costs per-frame rays; an unoccluded wedge is cheaper but reads as
  "x-ray vision." **Recommend occluded for fairness; flag the cost to Director.**
- Should a thrown item distract the cone (look-at-impact)? Lovely synergy but a new behaviour
  branch. **Recommend prototyping as a stretch — fun/scope call for Director.**
- Aggro persistence: instant-snap back to patrol on LoS loss (forgiving, puzzle-y) vs. a search
  state (tense, can corner you). **Recommend a short search for tension; sweep at the gate.**
- Multiple overlapping patrols turn a room into a hard timing lattice — great or frustrating?
  Depends on the band. **Director tunes per band.**
