# The Hunter
**Category:** Time-pressure / extraction-specific

## The idea
A **dormant** entity, seeded into the band at spawn, that does nothing until the **dive clock crosses a threshold** (e.g. the last third of the ~300s timer). At that moment it **activates band-wide and beelines for the player** — not room-bound, not patrolling, a relentless homing predator that exists *specifically to punish overstaying*. It is the clock made flesh: when time runs low, the band itself starts hunting you.

**Behavioral distinctness:** it converts an *abstract* deadline into a *visceral, escalating chase*. The decision it forces is "extract before the Hunter wakes, or commit to outrunning it for one more grab." Unlike the room-bound R1 pursuer (which is a *local, answerable* threat per `L2`), the Hunter is a *global, time-gated* threat whose whole identity is "you stayed too long." It gives the back third of the timer a felt presence instead of a quiet number.

## How it fits THE FAR YARD
The build already has the room-bound R1 pursuer (`hazard_entity.gd`, `L2`: patrols its room, chases only inside it) and a ~300s `dive_clock` (`dive_clock_changed`/`dive_clock_timeout`). The Hunter is **deliberately the inverse of R1**: R1 is *spatial and reasonable* (M1.5's legibility thesis); the Hunter is *temporal and unreasonable*. They are complementary, not redundant — R1 makes a *place* dangerous, the Hunter makes *time* dangerous.

It is the **most clock-coupled** of the four — which is its risk (see open questions). It does NOT add a parallel timer; it *reuses* the existing one as its trigger, so it can't desync from the deadline the player already watches. It strengthens GDD pillar 1 by making the final stretch of a dive a genuine "should I have left already?" panic, and it gives `dive_clock_timeout` (currently a quiet soft-fail) a dramatic escalation *before* the hard cutoff.

**Band depth:** first at **Band 2–3**. Earlier bands keep the timeout gentle; the Hunter is a deep-band "the deep things notice you" beat (GDD §4 Band 3+ "things that came through"). Its speed/wake-threshold scale with `Instability` — deeper bands wake it sooner and run it faster.

## Graybox sketch
- One dormant `HazardEntity`-style body, `DORMANT` until `dive_clock` fraction < `hunter_wake_fraction` (a `RunConfig` knob, default 0 / off → baseline parity), then `AWAKE`.
- On wake: a loud, unmissable **tell** (the GDD's "silence used as a weapon" → a sound, screen vignette, the tell flares) so the player *knows* the rules just changed.
- AWAKE: reuse the existing chase math (`velocity = dir * speed`, `move_and_slide`, walls stop it), but band-wide (no `r1_spawn_room_only` gate). Catch → `fail_run(&"hunted")`, behind an L5-style `*_kills` toggle.
- No art: a black diamond that turns red and chases. Proves the "the clock has teeth now" panic.

## Synergies & counters
- **Throw verb (L1):** essential counter — L1 already lets a thrown item kill a pursuer. The Hunter should be killable/stunnable by a throw, but *costly* (it's fast, hard to line up while fleeing), and maybe **respawns/re-wakes** so killing it only buys time, not safety. This keeps it a deadline, not a boss.
- **Walls (refuge):** like R1 it's stopped by `world`-mask walls, so smart routing through tight geometry is the skill expression.
- **Alarm spawner / Rising Tide:** stacking a band-wide chaser with reinforcements or a shrinking arena is a deep-band nightmare combo — reserve for the deepest content.
- **Counter:** the only real counter is *leave on time*. That is the point.

## Open questions
- **Does this double up with the countdown?** This is the sharp one — the Hunter IS the countdown, dramatized. That can be a feature (it makes the timer *felt*) or a redundancy (two things saying "time's up"). **The key Director fun-call:** does a wake-and-chase at T-100s add panic the bar can't, or is it just the timeout with extra steps? Recommend graybox to feel whether the *escalation moment* lands.
- Wake threshold vs. average dive length: if it wakes too early it dominates the dive; too late it never fires before `dive_clock_timeout`. Needs to wake with enough runway to matter (~last 25–33%). **Sweep value.**
- Is the wake **global** (one Hunter per dive) or **per deep room**? Global is more legible ("the band woke up"); per-room blurs into R1. Recommend global. **Design call.**
- If the player is *already at the gate* when it wakes, the wake is a non-event (they extract). Acceptable — rewards leaving early. But confirm it doesn't feel anticlimactic. **Feel call.**
- Killable-but-respawns vs. truly killable: respawn keeps it a deadline; truly-killable lets a strong player neutralize the whole mechanic. Recommend respawn/re-wake. **Director.**
