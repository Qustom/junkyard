# Timed / Arming Extractions
**Category:** Extraction mechanic depth

## The mechanic
Reaching the exit doesn't end the run — it *starts* a **channel**. You stand in
the extraction zone and a timer fills over X seconds; only when it completes are
you (and your haul) pulled out. Crucially, the channel is **interruptible**: a
pursuer entering the zone, or a hit landing on you, **pauses or resets** it. So
the exit stops being a safe full-stop and becomes the run's **final encounter** —
the moment of maximum tension, because the loot is real, the door is *right there*,
and something is closing on it. It converts "touch gate, win" into "hold the door
while the Hunter arrives." The drama is structural: the better your run, the more
you have to lose in those last few seconds, so the channel scales the stakes
automatically.

## What exists today
Honest read: **extraction is instant-on-press.** `extract_gate.gd` is a dumb
`Area2D` — on the `interact` press edge (and a 200–300 ms fat-finger lockout) it
calls `GameState.extract_and_end_run()` *immediately* (decision #5: "extraction is
INSTANT on a single press — no confirm dialog"). There is no channel, no progress
UI, no interrupt concept at the gate. But every ingredient exists: the **dive clock**
(`systems/dive_clock.gd`) already drains in `_process` and exposes `modify_light()`,
so a channel naturally costs clock-time; the **spawn-room pursuer** (`L2`) and the
**Hunter** (`hazards/5-the-hunter.md`) supply the interrupt threat; and the
**search-container** pattern (player-mechanics `e1`) is the *exact same shape* —
press to start, hold/advance, cancel on release/leave/damage, complete on elapsed,
with a progress ring. What's missing: a channel state machine on the gate, the
progress UI, an **interrupt rule** (who/what pauses or resets), and EventBus signals
for channel start/interrupt/complete.

## How to fit it in
Add a **channel timer** to `ExtractGate`: on interact (or simply on entering the
zone), start filling `e2_channel_seconds`. Track it against an **interrupt
predicate** — a pursuer/Hunter inside the gate radius, or a damage event on the
player — which **pauses** (forgiving) or **resets** (harsh) the fill. Leaving the
zone cancels. On completion, hand off to the existing `extract_and_end_run()` — the
gate stays dumb about meta-state, it just *gates* the call behind the channel. Reuse
the search-container progress-ring UI wholesale.

**Final-encounter framing.** This is where pursuers earn their keep: the channel is
a magnet that *invites* the fight. Pair it with `L2`/the Hunter so the last seconds
are a stand. **Pairs with the beacon (`s3`):** the beacon's arm-time *is* this same
channel, just deployed anywhere — unify the two on one timer/state-machine so a
placed beacon and the fixed gate share interrupt rules. **Double pressure:** the dive
clock keeps draining *during* the channel, so a slow extract is also a clock cost —
the two pressures stack without new systems (channel = exposure + ambush window).

**RunConfig + telemetry.** Mirror the `r1_`/`cont_` pattern in
`data/run_config/run_config.gd`: `e2_enabled: bool = false` (all-off default = today's
instant gate, the permanent control), `e2_channel_seconds`, `e2_interrupt_mode`
(`pause`/`reset`), `e2_interrupt_on_hit: bool`. EventBus:
`extract_channel_started`, `extract_channel_interrupted(elapsed, cause)`,
`extract_channel_completed`. Telemetry logs channel count, **interrupted-extraction
rate**, total channel time, and **deaths-at-gate** — the headline number for "did the
exit become a *good* fight or a frustrating wall?"

## Research (cited)
The channeled-exit-as-encounter is genre-standard. **Hunt: Showdown** roots you for
**~30 s** at the extract and **halts the timer if an enemy hunter is in the radius** —
you must clear them first; horses/boats audibly telegraph the approach
([wiki](https://huntshowdown.fandom.com/wiki/Extraction)). **DMZ/Warzone** exfil calls
a chopper on a public timer and "this is where things get harder as you will have to
survive the onslaught of enemies until the Helicopter touches the ground" — the timer
*announces* you to opponents
([Sportskeeda](https://www.sportskeeda.com/esports/how-exfil-easily-warzone-2-dmz)).
**Deep Rock Galactic**'s drop-pod launch window is a defended scramble whose tension
"brings a thrill to the finale of every level" — and the community thread is a warning
that **too short = frustration**
([wiki](https://deeprockgalactic.fandom.com/wiki/Drop_Pod),
[Steam](https://steamcommunity.com/app/2321470/discussions/0/3882723431865425811/)).
**Risk of Rain 2**'s teleporter is the purest analog: stand in a dome **~90 s while a
boss + monsters spawn**; charging only counts while you're inside
([wiki](https://riskofrain2.fandom.com/wiki/Teleporter)). The shared lesson: the
channel makes the exit *the* encounter — but its length is the whole fun/frustration
dial.

## Open questions
- **Channel length.** 30 s (Hunt) feels long for a faster top-down loop; 5–10 s may
  suit our pace. *Director fun call — sweep via `e2_channel_seconds` at the gate.*
- **Pause vs. reset on interrupt.** Pause (Hunt-style, resumes when the zone clears)
  is forgiving and readable; reset is brutal and can feel unfair if a fast pursuer
  loops the zone. Recommend **pause** first. *Director tone call.*
- **What interrupts.** Pursuer-in-radius only, hit-on-player only, or both? Both is
  most tense but most punishing; gate each via config. *Recommend pursuer-in-radius,
  validate at fun gate.*
- **Start on touch vs. start on press.** Press preserves player agency (commit when
  ready); auto-start on zone-entry is more dramatic but removes the "not yet" beat.
  *Recommend press-to-start (reuses A2).* 
- **Double-pressure tuning.** Does channel + dive-clock + ambush stack into *fun
  desperation* or *unfair pile-on*? This is the headline judgment. *Needs the
  playtest fun gate — instrument deaths-at-gate.*

## Sources
- [Hunt: Showdown — Extraction (wiki)](https://huntshowdown.fandom.com/wiki/Extraction)
- [DMZ exfil guide — Sportskeeda](https://www.sportskeeda.com/esports/how-exfil-easily-warzone-2-dmz)
- [Deep Rock Galactic — Drop Pod (wiki)](https://deeprockgalactic.fandom.com/wiki/Drop_Pod)
- [DRG Survivor drop-pod timer debate — Steam](https://steamcommunity.com/app/2321470/discussions/0/3882723431865425811/)
- [Risk of Rain 2 — Teleporter (wiki)](https://riskofrain2.fandom.com/wiki/Teleporter)
