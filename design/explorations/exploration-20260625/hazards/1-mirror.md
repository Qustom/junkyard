# Mirror
**Category:** Pursuers & movement enemies

## The idea
An enemy that **does not pursue you directly — it copies your movement**, either *inverted*
(you go left, it goes right; you go up, it goes up — a point-reflection or axis-mirror of your
input) or *delayed* (it retraces your exact path a second or two behind). It only threatens you
where its mirrored/echoed path *crosses yours* or where it collides with *you* at a mirror
point. You don't run from it; you **drive it**.

The behavioral distinctness: every other pursuer is something you flee or fight. The Mirror is
something you *puzzle* — the threat is created by your own movement, so the skill is moving in a
way that steers the Mirror **into other hazards** while keeping yourself clear. It's the only
enemy where the player is effectively controlling *two* bodies, and the only one whose answer is
spatial reasoning rather than reaction or timing. It fits the Lateral band's "physics slightly
off / reality instability" flavour perfectly — a thing that *is* you, wrongly.

## How it fits THE FAR YARD
- **Move:** the core verb becomes a tool of misdirection — you walk a deliberate path to park
  the Mirror on a pit, a Charger's lane, a hazard, or a wall. Reuses `player.facing`/movement
  entirely; the Mirror just transforms your velocity each frame.
- **Throw:** a thrown item could be the *finisher* once you've cornered the Mirror against
  geometry — or, more interestingly, the Mirror could **also mirror your throw** (it throws
  when you throw), making the throw verb double-edged near it.
- **Extract pressure:** the Mirror makes you take *longer, deliberate* paths (to steer it),
  which costs dive-clock — patience vs. the timer again.
- **Systems reused:** `HazardEntity` (CharacterBody2D, `hazard` layer, throw-killable). Its
  velocity each frame = a transform of the player's velocity (negate one/both axes for invert,
  or a position-history buffer for delay). On collision with the player → `fail_run`; on
  collision with another hazard/wall → it can die or stun. Knob group `mir_*`
  (`mir_mode` {invert_x, invert_y, point, delay}, `mir_delay_s`, `mir_speed_mult`), off by
  default.
- **First appears:** Band 3 (Lateral) — it *is* the band's "reality is off" idea made into an
  enemy; too conceptually heavy for Band 1.

## Graybox sketch
A circle that starts mirrored across the room's centre. Each frame: read player velocity,
apply the mode transform (e.g. `vel = Vector2(-pv.x, -pv.y)` for point-mirror), `move_and_slide`.
Draw a faint debug line between you and it to make the relationship legible. Smallest proof: one
point-mirrored circle and one pit/wall — can the player *learn to drive it* into the hazard?
The "aha, I control it" moment is the whole test.

## Synergies & counters
- **+ any environmental hazard (Charger lane, pit, Splitter):** the Mirror is a *delivery
  mechanism* — you steer it into the other threat. It's the most synergistic enemy in the
  roster.
- **+ tight symmetric rooms:** a point-mirror in a symmetric room means it's always heading
  for *you* — geometry sets the difficulty.
- **Counters:** steer it into geometry (primary, the intended skill); throw-kill once cornered;
  or break the mirror relationship by reaching a gate (extract ends it — run-state).

## Open questions
- Invert vs. delay are *very* different feels — invert is a spatial-reasoning puzzle, delay is
  a path-memory puzzle. Pick one as the canonical Mirror, or ship both as variants? **Recommend
  prototyping point-invert first (cleanest read); flag to Director.**
- Does the Mirror mirror the *throw* too? Cool and on-theme, but could feel unfair if the
  player's own thrown item kills them via the mirror. **Fun/fairness call — Director.**
- In a non-symmetric procedural room, a strict mirror can spawn the enemy inside a wall or
  make it instantly collide — needs a spawn-validity rule and probably a "soft" mirror that
  clamps to walkable floor. **Technical risk; flag scope.**
- Is it killable at all, or purely a puzzle to evade/route past? Pure-puzzle is more on-theme
  ("deep things can't be killed"). **Recommend evade-primary, throw-kill as a fallback.**
