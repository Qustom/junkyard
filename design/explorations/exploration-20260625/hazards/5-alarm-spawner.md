# Alarm Spawner
**Category:** Time-pressure / extraction-specific

## The idea
A **per-room dwell timer**: the longer the player stays in a single room, the more an "alarm" fills, and on each threshold it **spawns reinforcements** into that room. Loitering to strip a room clean summons enemies; keep moving and the alarm never trips. It is a *local* clock that pressures *pace within a room*, decoupled from the global dive deadline.

**Behavioral distinctness:** it forces **per-room tempo discipline** — "grab and go, don't camp." The decision is "is this room's remaining loot worth the next wave?" It directly counters the most degenerate extraction habit (parking in a safe room and methodically vacuuming every item) by making *standing still itself* the threat. The skill is reading when a room is "milked enough" and leaving before the alarm pays out, room after room.

## How it fits THE FAR YARD
The ~300s `dive_clock` pressures the *whole dive*; the Alarm pressures *each room*. These are **distinct, complementary clocks**: the global timer is a slow, dive-wide budget; the alarm is a fast, local "don't camp here" pulse that resets when you move on. Together they shape pacing at two scales — exactly the GDD §6 promise that "the longer you linger in a zone… entities multiply." The Alarm is the literal implementation of that line.

It plugs into existing systems cleanly: rooms are already `Vector2i`-cell pieces with world bounds (`_piece_floor_bounds_world`, used by K5/L2 `room_bounds`), and reinforcement spawning can reuse the K5/R1 spawn seam in `main_game.gd`. The spawned reinforcements would be the band's existing hazard roster (ping-pong/bomb/R1), so it adds *pressure*, not a new entity type. It sharpens push-vs-extract (GDD pillar 1) at the granularity of the room, and feeds the "avoid > fight" engineer fantasy (pillar 2): the cheapest answer to the alarm is to *leave*, not to fight the wave.

**Band depth:** first at **Band 1–2** as a gentle "don't dawdle" timer (one slow reinforcement), escalating with `Instability` — deep bands fill the alarm faster and spawn nastier/more reinforcements per trip.

## Graybox sketch
- Per active room: `dwell_t` accumulates while the player's `global_position` is inside that room's `room_bounds` (reuse the L2 `Rect2.has_point` test); resets on leaving.
- At each `alarm_threshold_s` (a `RunConfig` knob, off by default → baseline parity), spawn one reinforcement (an existing hazard) at a room cell away from the player; emit `alarm_triggered(room_id, wave_n, depth)` for telemetry.
- A visible **alarm fill bar/light** on the HUD or in-room tell so dwell is legible — the player must *see* the meter to make the leave-now call.
- No art: a filling bar + a grey square that turns into a hazard. Proves the "camping costs you" loop.

## Synergies & counters
- **Throw verb (L1):** the player can fight the wave (throw to kill reinforcements) — but that costs throwables and time, so leaving is usually better. The tension (clear-the-room reward vs. wave cost) is the design.
- **The Hunter:** alarm reinforcements + a band-wide Hunter is a strong deep-band escalation — the alarm makes you keep moving, the Hunter punishes total dive-time. They pressure different scales without redundancy.
- **Spreading Fire / Rising Tide:** stacking a "don't camp" timer with a "the room is shrinking" hazard double-pressures the same room — probably too much together; pick one per room archetype.
- **Counter:** loot fast, leave before the threshold, never backtrack into a milked room. Inventory-full forces an exit anyway (slot pressure, GDD §6).

## Open questions
- **Does this double up with the countdown?** No — it's *per-room*, the countdown is *per-dive*, and they reset on different events. The genuine risk is doubling up with **the existing R1 pursuer** (`L2`): R1 already makes a room dangerous-to-linger-in. Is "room-bound chaser" + "room-dwell spawner" two solutions to the same problem? Maybe combine — the alarm *is* the R1's escalation. **Director: distinct features or merge into the pursuer's wake logic?**
- Does the alarm reset fully on leaving, or decay slowly (so quick back-and-forth still accrues)? Full reset is more legible; decay punishes yo-yo cheese. **Tuning/feel call.**
- Spawning reinforcements *near* a full-bag player who can't fight could feel like a pure punish. Cap waves per room; never spawn between the player and the only exit. **Safety/scope call.**
- Should the bar be on-screen always (legible, but HUD clutter on the `decision_hud`) or a diegetic in-room light? Recommend a subtle in-room tell + a HUD flash on threshold. **UX call.**
