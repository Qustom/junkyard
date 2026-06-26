# Noise → Aggro
**Category:** Tradeoff systems (extraction-binding) — SHARED SUBSTRATE

## The mechanic
Loud actions make sound; sound wakes enemies. Sprinting, throwing, breaking a
container, and vaulting each emit a **noise event** with a *radius* (or a budget
that fills a local meter). Any enemy with a **hearing** component inside that
radius aggros — flips from dormant/patrol to investigate/chase. Walking is
quiet; sneaking is quieter; standing still is (near) silent. This turns the
run's most automatic input — *how fast and how loud you move* — into a constant
live decision: **move fast and loud** (cover ground, beat the dive clock, but
pull threats onto you) **vs. slow and quiet** (safe, but the clock bleeds out).

Critically this is **not one verb — it's a substrate**. Noise is the *currency*
that several other explored verbs spend: sprint pays in noise (`m2`), sneak
*reduces* the noise it would otherwise emit (`m3`), the sound-aggro zone
(`hazards/4-sound-aggro-zone.md`) is a region that *listens* for it, and throw
(`t*`/L1) doubles as a deliberate noise *lure*. Build it once; many mechanics
plug in.

## What exists today
**Honest read: no noise system, and no enemy hearing, exist.** Nothing in the
build emits a "noise" event or listens for one. `player.gd` is single-gear
movement with no loudness concept; `thrown_item.gd` and the container-search
sibling (`e1`) fire no noise. Enemy perception is absent — the shipped hazards
(`hazard_entity.gd`, the K5 entities) detect the player by a **distance-test +
rising-edge latch** keyed to the player's *position*, never to sound. The
patroller-vision-cone and sound-zone are **explorations, not built**.

`EventBus` is the right home for a noise event (signals are pre-declared
centrally per the milestone rule, lines 25+/157+). The opposition architecture
(`hazards/0-scalable-opposition-system.md`) already names where hearing belongs:
its **component model** lists a `ProximityTrigger` for the sound zone — a
**`HearingTrigger`** is the same shape (a trigger component that arms on a noise
event within range instead of on player proximity).

**Missing:** (1) a noise-emit model (which actions, what radius), and (2) an
enemy hearing component that consumes it.

## How to fit it in
**The noise model.** Each loud action emits `EventBus.noise_emitted(world_pos,
loudness, source)`. Loudness is ordered: `sneak < walk < sprint`, plus discrete
bursts for `throw`, `break_container`, `vault`. A radius = `f(loudness)` (sprint
~2× walk; a broken container a big one-shot). Continuous movement emits a
*throttled* pulse (every N px or M ms), not per-frame.

**Enemy hearing.** A `HearingTrigger` component (per the opposition taxonomy)
subscribes to `noise_emitted`; if `pos.distance_to(self) <= radius` it wakes the
host (flip dormant→chase / patrol→investigate, reusing the existing L2 chase
state). Keep it **distance-test, not physics overlap**, to match the
determinism discipline.

**This UNBLOCKS three dependents.** `m2` sprint-cost's *noise fork* ("sprinting
is louder") needs exactly this contract. `m3` sneak needs a noise value to
*multiply down* (`sneak_noise_mult`). `4-sound-aggro-zone` is the canonical
listener (its `noise` accumulator becomes "sum of `noise_emitted` inside the
zone"). Build noise→aggro and those three become small additions, not new
systems.

**Dive clock.** Noise is the *price of speed*: `dive_clock.gd` drains in real
time regardless of pace, so quiet = slow = clock-expensive. Noise weaponizes the
~300s timer against caution — the central extraction tension.

**RunConfig + telemetry.** A `noise_` group, all-off default (no emission, no
hearing) = byte-identical baseline. Knobs: `noise_enabled`, `noise_walk_radius`,
`noise_sprint_mult`, `noise_throw_burst`, `noise_break_burst`,
`noise_decay_per_s`. Config-marked telemetry: noise events emitted, aggros
*caused by* noise, and death-cause tagged "woke-via-noise" — so RG can ask "did
loudness change time-to-extract and death cause?"

## Research (cited)
- **MGS** treats a sound as a flag broadcast from its origin with a "can you
  hear this from here" radius; a guard inside it enters inspection mode — the
  exact radius-aggro model proposed here. Snake's footfalls are *deliberately*
  loud so the player feels the cost of moving fast.
- **Thief / Splinter Cell** pair a light/visibility gem with a **sound meter**,
  giving the player a legible read of how loud they currently are — argues for a
  greybox noise tell, not invisible state.
- **Invisible Inc** (cited in `m3`): sprinting emits noise into the entered
  tile, heard within a radius; walking is silent and sound is a *throwable
  distraction* — validates both the sprint-noise trade and throw-as-lure.
- **Hunt: Showdown** (cited in `m2`): traversal noise gives away position and
  *triggers* monsters; Crytek tunes "the cost of silence" as a balance lever.
- **Radius vs. propagation:** the cheap model is a flat distance radius
  (deterministic, what we want); true propagation occludes through walls/doors
  (modern AAA, e.g. surface-aware footsteps + occlusion). **Recommend radius
  first**; propagation is an M2+ fidelity upgrade, not the graybox.

## Graybox sketch
Smallest version that proves the live choice:
1. Add `noise_enabled` + emit `noise_emitted(pos, loudness)` from `player.gd`
   on a throttled tick (loudness from current speed) and a one-shot burst from
   `thrown_item.gd` on launch.
2. One dormant enemy (an `hazard_entity` spawned IDLE) with a `HearingTrigger`:
   wakes on any `noise_emitted` within `radius`, then runs its existing chase.
3. Greybox tell: a noise-radius ring drawn at the player that grows with speed
   (sprint = big, sneak = small) + the sleeper's wake-flash — pure visual "you
   were loud."
4. The test: place the sleeper between the player and a pickup. Does "creep past
   it, or sprint and pull it but reach the pickup first" read as a real choice?

## Open questions
- **Radius vs. raycast propagation? (effort — Director.)** Flat radius is
  deterministic and cheap; wall-occluded propagation is richer but heavier and
  fiddlier to keep seed-reproducible. **Recommend radius for graybox/M1.x.**
- **How central is stealth? (vision/scope — Director.)** Noise→aggro is the
  spine of a real stealth pillar (with cones + search states). If stealth is a
  *light option*, a single radius + one hearing enemy may be all we want.
  **Recommend ship the substrate minimally, measure whether testers engage with
  loudness before investing in a full pillar** (mirrors `m3`'s recommendation).
- **Sequencing — this is a FOUNDATIONAL dependency (flag to Director).** `m2`'s
  noise fork, `m3` sneak, and `4-sound-aggro-zone` *all block on this contract*.
  Should noise→aggro be scheduled as a **named substrate task ahead of** those
  three (so they land as small additions), or bundled with the sound-zone as one
  unit? **Recommend building the EventBus noise contract + `HearingTrigger`
  first**, then the three dependents in parallel.
- **Stillness: perfectly safe, or a tiny trickle?** Must match `m3`/`4-*` — a
  small idle trickle keeps the clock biting and discourages camping. *Recommend
  a tiny trickle.*

---
Sources:
- [Metal Gear Solid detection / sound radius (GameDev.net)](https://www.gamedev.net/forums/topic/219243-metal-gear-solid-detection-code/)
- [MGS iconic sound & stealth design (GameRant)](https://gamerant.com/metal-gear-solid-iconic-sound-design-stealth-silence-codec-alerts/)
- [Splinter Cell stealth design — light & sound meters (GamingBolt)](https://gamingbolt.com/the-original-splinter-cell-is-still-a-masterclass-in-stealth-design)
- [Stealth game (Wikipedia) — Thief light gem & sound](https://en.wikipedia.org/wiki/Stealth_game)
- [Invisible Inc — movement & sprint noise (Fandom wiki)](https://invisibleinc.fandom.com/wiki/Movement)
- [Hunt: Showdown — "increase the cost of silence" (PC Gamer)](https://www.pcgamer.com/games/fps/we-want-to-increase-the-cost-of-silence-hunt-showdown-1896s-latest-update-brings-a-new-event-a-massive-list-of-bugfixes-and-a-tougher-challenge-for-stealthy-players/)
