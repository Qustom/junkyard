# Conveyor / Wind Tile
**Category:** Static & environmental traps

## The idea
A floor region that **continuously pushes everything on it in a fixed direction** — the player, thrown items, and enemies alike. Distinctness: it is not lethal on its own; it **alters momentum and changes the meaning of every other verb**. It is a *force field*, not a kill-tile. The decision it forces is **factoring drift into movement, aim, and routing**: walking across a conveyor means compensating; throwing across one means leading the shot; standing on one means being carried toward (or away from) whatever's downstream. Its danger is entirely *relational* — a conveyor that pushes you toward a flame vent or off a ledge is the threat; a conveyor pushing you *toward* loot is a gift. It is the system's first "physics modifier" tile and the connective tissue that makes other traps lethal.

## How it fits THE FAR YARD
A placed run-state region in the fair-share system (an `Area2D` rather than a kill entity). It snapshots `RunConfig` at `setup(...)`, reads `_cfg.hcv_*` (direction `hcv_dir`, strength `hcv_force`), and each `_physics_process` adds `hcv_force * hcv_dir` to the velocity of any body overlapping it — applied in the player's `step_velocity` (the existing pure movement helper, `player.gd`) so it stays unit-testable, and to the L1 thrown-projectile's integration, and to the R1 pursuer's `move_and_slide`. **It is never lethal**, so it has no `*_kills` knob; it does not touch `new_hazard_killed`. Crucially it **does not affect generation** — it is pure run-state force, leaving the all-off fingerprint untouched (like every other M1.5 lever it defaults `hcv_enabled=false`).

It is a force-multiplier on the whole hazard family and the throw verb, which is exactly its value: it makes existing traps deeper without new lethal entities. It fits the "junkyard" fiction cheaply — a still-running conveyor belt from a breaker's yard, a wind tunnel where a wall is missing. It supports the GDD's "traverse hazardous terrain" and turns the L6 aim verb into a lead-the-shot skill.

First appearance: **Band 1 (Near)** as a gentle, *helpful-or-harmless* belt (a tutorial in "the floor can push you"), turning hostile in Band 2+ when paired with lethal hazards downstream.

## Graybox sketch
A translucent `ColorRect` `Area2D` with arrows (or a scrolling stripe) showing `hcv_dir`. On `body_entered`/overlap, accumulate the force into that body's per-frame velocity; remove on exit. No state machine — it's always on. Knobs: direction (4- or 8-way), `hcv_force`. No art: a tinted rectangle with a drawn arrow. Tune force so it's *felt* but never fully overrides player input (you can always walk against it, just slower/skewed) — full-override-toward-a-hazard is a deep-band-only setting.

## Synergies & counters
- **With throw (L6):** **this is the headline synergy** — a thrown item crossing a conveyor *drifts*, so you must lead the throw (aim upwind). A conveyor between you and a pursuer turns every throw into a wind-adjusted shot. Equally, a belt can *carry* a thrown bomb-able item toward a target.
- **With flame vent / spikes / crusher:** a belt feeding the player *into* a lethal phase is the canonical deep trap; a belt feeding *enemies* into one is a player tool.
- **With ice tile:** conveyor + ice compounds loss-of-control terrifyingly.
- **Counter:** walk against the drift (slower), or use it — ride it toward loot/the gate, or let it carry an enemy into a hazard. Routing is the answer, not avoidance.

## Open questions
- **Does it push *thrown items*?** Strongly recommend **yes** — that's the most distinct, throw-verb-rich behavior and the reason this tile earns its place over a plain damage tile. Confirm it's worth the projectile-integration work. *Recommend yes; flag the effort to the Director.*
- **Can force fully override input (carry you helplessly), or only skew it?** Full override is a stronger trap but can feel like lost agency (anti-pillar). *Recommend skew-only by default, full-override as an explicit deep-band knob.*
- **Push enemies too?** Pushing the R1 pursuer is a great toy but changes pursuer balance/pathing. *Recommend yes for the player's benefit; verify it doesn't break pursuit at the fun gate.*
- **Wind (gusty, intermittent) vs. conveyor (constant)?** A timed/gusting variant adds a rhythm layer like the other traps. *Constant for graybox; gusting as a later variant.*
