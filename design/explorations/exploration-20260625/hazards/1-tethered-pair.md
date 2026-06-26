# Tethered Pair
**Category:** Pursuers & movement enemies

## The idea
**Two** enemies linked by a **damaging beam** — a line of energy strung between them. The bodies
themselves are weak or even harmless; **the threat is the line.** The pair drifts/patrols
semi-independently, and the player's danger is *being caught between them when the beam sweeps
across*. You don't fight the bodies — you read the geometry of the line and stay off it.

The behavioral distinctness: every other pursuer is a *point* threat (a body to flee, dodge, or
hit). The Tethered Pair is a **line/area** threat — the dangerous thing has no body to throw at,
it's the *relationship between two bodies*. The player must track two things at once and reason
about the swept area between them, a spatial skill nothing else in the roster trains. And it
makes the throw verb ask a real question: throwing kills *a body*, which **moves or breaks the
line** — so your offensive verb reshapes the hazard rather than simply removing it.

## How it fits THE FAR YARD
- **Move:** the core read is "don't be on the line, and don't let the line sweep onto you" — a
  positional/timing skill around a moving segment. Reuses movement; the hazard is the beam.
- **Throw:** killing one body *severs or relocates the beam* — a thrown item can **defuse the
  line** (kill a node so the beam drops) rather than the usual "throw to remove a chaser." This
  is a genuinely different use of the throw verb: you target the *configuration*, and you must
  pick *which* node and accept the other one survives.
- **Extract pressure:** a Tethered Pair straddling a corridor *walls it with the beam* — you
  wait for the line to swing clear (dive-clock cost) or spend a throw to break it (item cost).
  A clean push/cash-out micro-bet at a chokepoint.
- **Systems reused:** two `HazardEntity` nodes (each on the `hazard` layer, throw-killable via
  `queue_free`) plus a **beam hazard** = a segment between their positions that does the K5
  *distance-to-segment* test for lethality (extends the bodiless bomb/spike distance-test
  pattern from a point to a line). Killing a node detaches the beam. Knob group `tth_*`
  (`tth_beam_lethal`, `tth_node_speed`, `tth_max_len`, `tth_link_pull`), off by default.
- **First appears:** Band 3 (Lateral) — an "anomalous" paired entity suits the band's wrongness;
  the two-body tracking load is too much for Band 1.

## Graybox sketch
Two circles, each drifting along a short patrol, with a drawn line between them and a lethal
band along that segment (point-to-segment distance < threshold → `fail_run`). Optional: a max
tether length so they can't drift infinitely apart (a soft pull keeps the line taut). Throw-kill
either circle → the line vanishes (or re-anchors). Smallest proof: two drifting circles + a
lethal line in a corridor — does "wait for the line to swing, or throw one node to drop it" feel
like a real choice? The line-as-threat read is the test.

## Synergies & counters
- **+ corridors/chokepoints:** the beam is most threatening spanning a narrow lane — geometry
  sets the danger, and the pair is a natural gate-guard.
- **+ Mirror/Charger:** a Charger that can sever the beam by ploughing a node, or a Mirror you
  steer into the line, are clever-engineer answers.
- **Counters:** read the swing and cross when the line is clear (free, timing); throw a node to
  drop the beam (item cost, leaves one survivor); route around entirely (dive-clock cost).

## Open questions
- After killing one node, does the survivor become a normal pursuer, flee, or go inert? A lone
  survivor turning into a chaser is a nice "the threat changed shape" beat but adds a body to
  deal with. **Recommend survivor goes inert/slow for greybox clarity; flag to Director.**
- Beam always lethal vs. only lethal while "charged"/sweeping (a pulse) — a pulsing beam adds a
  timing layer; an always-on beam is a pure positioning read. **Recommend always-on first; sweep
  to a pulse later.**
- Does the beam collide with / block enemies and thrown items, or only the player? Beam-blocks-
  throws would make defusing it require a clear shot at a node — interesting but fiddly.
  **Recommend beam affects only the player in greybox.**
- Two independently-pathing bodies in procedural rooms risk awkward configurations (line clipping
  through walls, nodes stuck apart). Needs the `tth_max_len` pull + spawn-validity rules.
  **Technical risk; flag scope.**
