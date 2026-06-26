# Ambusher
**Category:** Pursuers & movement enemies

## The idea
A hazard that is **invisible/buried until you get close**, then **pounces once** — a single
fast lunge from concealment — and is otherwise weak or inert. It hides *in the junk*: a pile,
a wreck, a dark slot of floor that looks like loot or cover. Get within its trigger radius and
it springs.

The behavioral distinctness: every other pursuer in the roster announces itself (a visible
chaser, a patrol route, a telegraphed charge). The Ambusher punishes the player's *default
greedy behaviour* — walking straight up to junk to loot it. It is the only enemy whose threat
is **the act of looting itself**. It teaches caution and turns the inventory grab — the most
repeated verb in the game — into a moment of doubt. It makes the player *read the room before
reaching for the prize.*

## How it fits THE FAR YARD
- **Loot:** this is its whole reason to exist. The GDD's loop is "walk to junk, press F to
  grab" (`JunkPickup`, `interactable_id=&"junk"`). An Ambusher seeded *near or disguised as*
  a high-value pickup makes blind looting cost you. It's the enemy that gives the loot verb
  teeth.
- **Throw:** if you *spot* the tell before triggering, you can throw an item at it to pop it
  pre-emptively (one item spent to disarm a trap) — or you eat the pounce. Risk-reward toss.
- **Extract pressure:** Ambushers reward *slow, careful* dives; the dive-clock rewards *fast*
  ones. That direct tension — "do I have time to be careful?" — is exactly the push/cash-out
  bet, applied to looting.
- **Systems reused:** `HazardEntity` with a hidden visual (greybox sprite hidden until
  `_proximity` fires) and a one-shot lunge instead of a persistent chase. Trigger reuses the
  K5 bomb/spike *distance-test* pattern (bodiless until armed). On pounce-hit → `fail_run`
  or a nonfatal stagger; throw-kill while exposed → `queue_free`. Knob group `amb_*`
  (`amb_trigger_radius`, `amb_lunge_speed`, `amb_lunge_dist`), off by default.
- **First appears:** late Band 1 / Band 2 — once players have learned to grab greedily, so
  the betrayal lands.

## Graybox sketch
States: `HIDDEN` (sprite invisible or styled as junk, a faint tell — a coloured floor decal)
→ `ARMED` (player inside `trigger_radius`: brief tell flash) → `POUNCE` (one fast lunge at
the player's position, ~0.3s) → `EXPOSED` (vulnerable, slow or inert for a few seconds, can
be thrown-killed or walked away from) → optionally re-`HIDDEN`. Smallest proof: one Ambusher
under a juicy pickup, a subtle floor tell, the pounce, and a window to punish — does the
"is this safe to grab?" hesitation feel good?

## Synergies & counters
- **+ high-value junk:** seed Ambushers preferentially near top-tier pickups (depth-scaled
  via the B3 placement curve) so the best loot is the most dangerous to grab.
- **+ Pack hunters / Patroller:** an Ambush that staggers you into a patrol cone is a deadly
  combo at depth.
- **Counters:** learn the tell and route around; throw to pre-pop; or bait the pounce from
  range then loot safely. The breather-rig/anomaly-perception fiction could later reveal them.

## Open questions
- How telegraphed is the tell? Too subtle = feels cheap/unfair; too obvious = trivial. The
  fairness line here is the whole design. **Fun/fairness call — Director.**
- One-shot (dies/spends after pouncing) vs. re-arming? Re-arming denies an area; one-shot is
  a pure punish. **Recommend one-shot for the first build.**
- Is the pounce fatal or a stagger? Fatal is brutal for a "blind loot" punish; a stagger that
  drops you into *other* danger may be the better teacher. **Recommend nonfatal stagger.**
- Disguised-as-junk (mimics a pickup) is the strongest version but risks confusing the loot
  read entirely — possible feel-bad. **Flag to Director.**
