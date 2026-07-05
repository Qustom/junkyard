# T2b — New opposition #2: the BURROWER — Expanded Design Spec

**Milestone:** M1.10 (Second-Gen Backend + Cave Band + Low-Sightline Oppositions) · **Wave:** 1 (parallel worktree)
**Task id:** T2b · **BlockedBy:** none (S0/S2/S3 opposition stack shipped in M1.9)
**Assignees:** general-purpose (host + component + defs + test) · character-animator (buried decal + surface-pop greybox)
**Author:** game-director-designer · **Status:** Phase-2 design (Open Questions unresolved — Phase-3 fresh-eyes resolves, Director ratifies fun/fairness calls)

> **What this doc is.** The per-task design for M1.10 §T2b, authored to the four-phase process (CLAUDE.md
> "Version breakdown authoring"). It expands the M1.10 breakdown's one-line T2b contract into (a) research +
> the determinism/fairness argument against the **real as-built S2 component set + S0/S3 spawn stack**, (b) a
> design spec + pseudocode against those APIs, and (c) an explicit `Open Questions` section. It ships **no game
> code and no `.tres` yet** — the programmer + character-animator build against it in Wave 1. Style/rigor mirror
> `design/M1_9_Tasks/S6b_splitter_hazard.md` (the immediately-prior "def + one new component" proof) and the
> shipped Charger (`charger_hazard.gd` + `charge_lane.gd`), which is the closest as-built template.

---

## 0. Hard constraints (read first)

Straight from the M1.10 breakdown scope guardrails ("No new opposition machinery", "M1 lethality model holds")
and the shipped v2 opposition contract. The spec must not violate these, and neither may the implementation:

- **Content = data + ONE new component (the Phase-E price).** The Burrower ships as **`burrower.tres`
  (`OppositionDef`) + one new `OppositionComponent` (working name `BurrowCycle`) + a thin host shell**, reusing
  `LethalContact`, `ThrowInteraction`, and `TelegraphFSM` unchanged — exactly as the Charger shipped as
  `charger.tres` + `ChargeLane` + `charger_hazard.gd`. If the Burrower needs a second new component or a shared-
  file edit, the architecture (or this design) is wrong — surface it, don't paper over it (§9 seam note).
- **The three permanent controls are untouched.** With `oppositions_enabled` empty (the shipped `RunConfig`
  default) and `&"burrower"` in no default preset / no `band_greybox` / no `band_two` deck, no def loads, no node
  instantiates, no telemetry row appears. The all-off fingerprint **`e943ac9c8bc1` stays byte-identical**; the
  `band_greybox` + `band_two` fingerprints stay byte-identical (T2b touches no generation path at all).
- **No player HP pool — binary lethal Actor.** M1 has no health system. The Burrower is a **binary lethal Actor**
  like every shipped hazard: while surfaced, catch → `kills`-gated `fail_run(&"death")`, emit-always. "Phased
  vulnerability" is about the *body's* hittability/lethality cycling on a timer, **never** a player health bar.
- **91-knob model frozen; per-def bijection extends to 9 defs.** The Burrower adds **no** hand-authored
  `RunConfig` lever. Its knobs live in `OppositionDef.params` with a self-describing `param_schema` (the
  `params ↔ param_schema` bijection the linter asserts per-def — the charger/splitter pattern). The generated
  Oppositions menu tab + IN-DECK chips pick it up with **zero menu code** (proven count-agnostic 4→6→7→8; this is
  def #9).
- **RNG-free + deterministic.** `burrow_cycle.gd` + `burrower_hazard.gd` reference the global `RNG` autoload
  **nowhere** (the charger/splitter DoD (9) audit; `test_burrower` greps for `"RNG."`). Generation-time placement
  is the builder's RNG-free stable walk; the cycle's per-instance desync is a pure function of the builder-stamped
  `ctx["phase_salt"]` (§5). The FSM is real-time run-state (like `ChargeLane`) and never feeds `fingerprint()`.
- **Ships OFF; `band_three`-exclusive in M1.10.** Per breakdown OQ9 the new oppositions are band-3-exclusive
  until TG2 says they're fun (clean A/B, mirroring D-RAT-2). Not in band 1 or band 2's deck; `min_band = 3`.
- **Placeholder art tint-only.** Inline flat shapes (buried decal + surface-pop blob), no PixelLab (Director-
  gated), no sprite sheets, no `AnimationTree`. Filter OFF.
- **Single-writer / parallel-wave rule.** T2b (this task) runs in a worktree **file-disjoint from T0/T2a**. It
  **creates** its own def/scene/component/test only and **edits no shared host/component file** — any needed seam
  is an orchestrator-adjudicated request (§9), never a silent edit. Predicted shared edits: **zero** (§8 ledger).

---

## 1. Research — why the Burrower is the phased-vulnerability proof

### 1.1 The architectural axis it exercises (that no shipped def does)

The M1.10 breakdown picks the Burrower to prove the component model handles **phased vulnerability** — an entity
whose *hittability and lethality cycle on a timer*, "a state axis no shipped def exercises." Mapping the seven
shipped defs against that axis:

| Shipped def | State axis it exercises | Vulnerability model |
|---|---|---|
| `pursuer` (R1 `HazardEntity`) | dormant→awake (one-way) | **always** throw-killable + always lethal once awake |
| `pingpong` | none (constant bounce) | always killable + always lethal |
| `spike` | rotating arms (spatial, not vulnerability) | always killable; lethality is *positional* |
| `bomb` | idle→pulse→detonate (one-shot) | always killable until it detonates once |
| `charger` (`ChargeLane`) | dormant→telegraph→charge→recover | lethal **only** in CHARGE; a `throwable_while_charging` GROUP toggle can flip *throwability* per-phase |
| `splitter` (`SplitterHazard`) | idle→aggro latch (one-way) | always killable + always lethal |

The Charger is the closest prior art — it already gates **lethality** to one phase (CHARGE via `LethalContact`
`&"external"`) and can gate **throwability** per-phase (the `_set_throwable` group toggle, `charge_lane.gd:192`).
But the Charger is **always present, always visible, always on the `hazard` collision layer** — the throw is
*always a valid interaction* (it either kills or re-drops). No shipped def makes the body **cease to exist as a
target** for a stretch of every cycle. That is the Burrower's unique claim:

- **The body is un-hittable for most of its cycle** — `collision_layer` cleared while buried, so a thrown item
  **passes clean through** (not even a re-drop miss), and script-lethality is gated off. This inverts the
  throw-kill loop's core assumption that the threat is always a valid target (exploration `1-burrower.md`
  §"The idea"). The skill becomes *reading the rhythm*, not reaction.
- **It ignores world collision while buried** — moving *under* walls, so it denies an *area on a beat* rather
  than chasing through corridors. No shipped def moves through geometry.

If the Burrower ships as **`burrower.tres` + one `BurrowCycle` component**, reusing `LethalContact` (`&"external"`
gated kill), `ThrowInteraction` (`&"die"`), and `TelegraphFSM` (decal pulse) with **zero shared-file edits and
the three control fingerprints byte-identical**, then the component model is proven to absorb *phased
collision-layer + lethality cycling* — the last common opposition idiom the shipped set left untested. That is
T2b's job: a small feature carrying a specific architectural claim, measured by the cost ledger (§8).

### 1.2 As-built anchors T2b builds on (cite these — not the exploration's `bur_*` RunConfig sketch)

The exploration (`1-burrower.md` §"Systems reused") predates M1.9's data-driven opposition stack — it names a
`bur_*` RunConfig knob group, which is **superseded**. New defs carry **unprefixed keys in `OppositionDef.params`**
(charger: `aggro_range`/`telegraph_s`; splitter: `move_speed`/`catch_radius`), reflected by a `param_schema`. The
real anchors:

- **The gated-lethality seam already exists.** `LethalContact` mode **`&"external"`**
  (`lethal_contact.gd:30-32,102-107`): an external mover supplies the contact boolean each frame via
  `apply_contact(hit, can_catch)` — the **emit-always telemetry + L5 `kills` gate + BUG6 rising-edge latch** run
  unchanged, contact math supplied from outside. `ChargeLane._test_lethal_sweep`
  (`charge_lane.gd:178-185`) is the exact template: it computes `hit` only during CHARGE and calls
  `lethal.apply_contact(hit, true)`; on phase exit it calls `lethal.apply_contact(false, true)` to re-arm the
  latch on the falling edge (`charge_lane.gd:139`). **`BurrowCycle` feeds `apply_contact` the same way — `hit`
  computed only in SURFACED, `false` every other phase.** No `LethalContact` edit.
- **The per-phase collision toggle is an established host idiom.** `ChargeLane._set_throwable`
  (`charge_lane.gd:192-199`) toggles the host's **`&"hazard"` GROUP** membership per-phase — pure stock
  membership, "zero `thrown_item.gd` edits." The Burrower extends this idiom by one step: it toggles the host's
  **`collision_layer`** (a plain `CharacterBody2D` property write on its *own* node), because the group toggle
  alone is insufficient for *pass-through* (§1.3). Still zero shared-file edits.
- **The throw-death delegation seam.** `ThrownItem._hit_hazard` (`thrown_item.gd:96-110`) emits
  `throw_killed_hazard` + the `&"killed_by_throw"` twin, then consults `body.resolve_throw_death(killer_ctx)`
  (duck-typed). For the Burrower, `ThrowInteraction` mode `&"die"` (default) returns `false`
  (`throw_interaction.gd:29-32`) → the thrower frees it — **but this path is only *reachable* while surfaced**,
  because while buried the body is off `collision_layer` (§1.3), so `body_entered` never fires against it. No
  split, no self-handling: the Burrower is a plain throw-killable body *when it is a target at all*.
- **The self-timed clock + component tick discipline.** The host is the sole physics ticker; components never
  self-`_process` (`opposition_component.gd:50-52`). The host owns a `run_clock_ms()` accumulator (R1 §4 pattern;
  `charger_hazard.gd:135-137`), bound to components once at `bind()` (`opposition_component.gd:66-72`). The host
  snapshots its knob bag at `setup(cfg, player, spawn_ctx)` from `spawn_ctx["params"]` over a `DEFAULTS` mirror
  (`charger_hazard.gd:48-60,112-123`) — the exact deck-lane resolve order.
- **The builder-stamped ctx.** `EncounterBuilder.populate` stamps each new-def spawn's ctx with `params`,
  `phase_salt` (`legacy_ctx`: `p.depth_index * 131 + k`, `encounter_builder.gd:119`), `depth`, `run_t_ms`,
  `room_key` (`encounter_builder.gd:363-367`). `BurrowCycle` reads `ctx["phase_salt"]` for per-instance desync
  (§5); the host reads `ctx["params"]` for its knobs.
- **Player speed reference.** `data/player/player_movement.tres` `max_speed = 200.0`. The Burrower's
  `track_speed` default must sit well below 200 so a walking player can out-pace it (the exploration's "outwalk
  it while it's buried-and-far" counter) — §3.1 sets `80.0` (0.4× player).
- **The locked telemetry vocabulary.** `test_charger` pins the S0 vocabulary to `[&"telegraph", &"state",
  &"hit_player"]` for `opposition_event` (out-of-vocabulary rows fail, `test_charger.gd:241-243`). The Burrower
  emits **only** those tokens (§6): `&"telegraph"` on the pulse, `&"state"` on surface/bury transitions,
  `&"hit_player"` from `LethalContact`; `&"spawned"` is the service's, `&"killed_by_throw"` the thrower's,
  `opposition_killed_player` the gated player-death channel. **No new `EventBus` signal, no new end-cause.**

### 1.3 Why *pass-through*, not the Charger's *miss* — the collision-layer decision

The Charger's dash-invulnerability keeps the body on `collision_layer 16` and only drops the `&"hazard"` **group**,
so `ThrownItem.body_entered` still fires and resolves as a **miss → re-drop** (`thrown_item.gd:79-82`,
`charge_lane.gd:38`). That is *wrong* for the Burrower: the exploration wants the throw to **pass clean through**
a buried body (the "your throw is useless most of the time — wait for the surface window" lesson), **not**
re-drop your item at the burrower's feet.

`ThrownItem` is an `Area2D` with `collision_mask = world(2) | hazard(16) = 18` (`thrown_item.gd:13-14`).
`body_entered` fires only when the *other* body's `collision_layer` intersects that mask. **Therefore: while
buried, clear the host's `collision_layer` to `0`.** With layer 0, the projectile's mask never intersects the
buried body → `body_entered` never fires against it → the item flies straight over and continues (eventually
missing at `max_range` far away, or hitting a real wall). True pass-through, **zero `thrown_item.gd` edits** — the
seam is entirely the host mutating its own `collision_layer`.

Two riders:
- **Group hygiene.** Also remove the host from the `&"hazard"` group while buried (belt-and-braces), so any
  future group-scan can't treat a buried body as targetable. Restore layer **and** group on surface. (Layer is
  the load-bearing one; group is defensive.)
- **World collision while buried.** The exploration wants the buried body to move *under walls*. The host's
  `collision_mask` is `world(2)`, which only matters if it calls `move_and_slide()`. **Buried movement is a
  direct `global_position` translation toward the player (no `move_and_slide`)**, so it ignores walls *by
  construction* — no mask change needed, and it's deterministic (no physics resolution). When surfaced the body
  is **static** (a "pop", not a lunge — §1.4), so it never moves through a wall either. Clean.

### 1.4 Fairness — the dodge frame is the whole design (the fun/fairness line)

The Burrower's failure mode is a **feel-bad surprise surfacing under the player** — an un-dodgeable kill. The M1
lethality bar (Wrecker/Charger precedent: a generous, readable telegraph precedes every kill) makes the fairness
mechanism non-negotiable. The design guarantees a dodge frame through **three** compounding rules:

1. **Lethality arms only in SURFACED.** During BURIED and TELEGRAPH the body is non-lethal (`apply_contact(false,
   …)`). Surfacing under the player at the *start* of SURFACED can be a catch — but only *after* the telegraph
   window elapsed (rule 2). "Inside the dodge frame" (the DoD phrase) = during TELEGRAPH = **provably
   non-lethal**.
2. **A telegraphed lead `telegraph_lead_s`.** Between BURIED and SURFACED, a TELEGRAPH phase of duration
   `telegraph_lead_s` shows a pulsing decal at the surface point while the body stays buried + non-lethal. This is
   the authored window to walk off — the `ChargeLane` `telegraph_s` role, transplanted.
3. **The surface point LOCKS at telegraph start** (`lock_surface_at_telegraph = true`, the `ChargeLane`
   `lock_at_telegraph_start` idiom, `charge_lane.gd:118`). When TELEGRAPH begins, the tracked point freezes: the
   decal stops following the player, so stepping `kill_radius + player_radius` away *guarantees* safety. Without
   the lock the decal would chase the player through the telegraph and "dodge" would be impossible — that is the
   unfair variant the Director can opt into (`false`), not the default.

The counter-lesson the Burrower teaches — "waiting/patience beats throwing" — only lands if the rhythm is
*legible*. So the telegraph must read clearly (art §7) and `track_speed` must be outwalkable (< player 200). The
exploration flags the **exact-position vs vague-zone decal** as a Director fun/fairness call (`1-burrower.md`
§"Open questions"; breakdown OQ8). This design recommends **exact locked position** (fair + readable; the decal
*is* the "you will be hit here" contract) over a vague rumble zone (tense but feel-bad) — §9 Q4, needs Director
review.

### 1.5 Fiction pitches (2–3 — tone call, Director picks; `id` stays `&"burrower"`)

Band 3 is the **cave** band (M1.10) — bad sightlines, disorientation as identity (`b3-organic-caverns.md`). Three
framings for the thing under the floor (final name is `display_name`; the stable `id` / telemetry / tests never
change with flavor):

- **(A) "Sinkmaw" / "Grinder" (recommended — mechanical-junkyard, cave-native).** A half-buried scrap-auger left
  running in the cave floor: it tracks the vibration of your footsteps, winds up (the floor shivers), then
  *breaches* to snap at the surface before sinking to re-align. Ties to THE FAR YARD's "every junkyard is one
  junkyard" fiction (a buried machine, sibling to the Wrecker's crusher); the shivering-floor telegraph reads as
  a mechanism spinning up. Cyrus VO hook: *"Floor's shivering — that's not settling, that's it lining you up.
  Move."*
- **(B) "Silt-lurker" / "Burrower" (creature read).** A soft cave-organism that swims the loose fill like water,
  cresting to bite. Warmer, more "monster"; risks the well-worn "sandworm" trope and is slightly off the
  melancholy-industrial tone.
- **(C) "Undertow" / "Subsidence" (hazard-as-place read).** Not a creature but the *cave floor itself* going
  unstable in a travelling patch — the ground heaves up where the instability pools, then settles. Most abstract;
  leans hardest into "the ground itself is unsafe on a beat" but is the hardest to read at greybox fidelity (is
  it a body or terrain?).

**Recommendation: (A) Sinkmaw/Grinder** — tightest coupling to the existing junkyard-machine fiction and the
clearest "a mechanism is aiming at me" telegraph read, which directly serves the fairness requirement (§1.4).
(C) is the elegant cave-identity alternate if the Director wants the band's "the place is the enemy" theme
front-loaded. §9 Q1, needs Director review.

---

## 2. Design spec — the def + `BurrowCycle` behaviour

The Burrower is **one `OppositionDef.tres`** (`burrower.tres`) driving one host scene (`burrower.tscn`, an Actor =
`CharacterBody2D`) composed of the reused S2 components + the one new `BurrowCycle`. Unlike the Splitter it needs
**no second def** (no children) — it is the simplest possible "def + one component" proof.

### 2.1 The BurrowCycle FSM

Four phases, cycling forever (the exploration's `BURIED → TELEGRAPH → SURFACED → BURIED`). All timing is a
host-driven accumulator inside the component (the `ChargeLane` pattern — the component owns its own FSM clock;
`TelegraphFSM` owns only presentation, per `telegraph_fsm.gd:7-14`):

| Phase | Duration | Body visible? | `collision_layer` | In `&"hazard"` group? | Lethal? | Throw-killable? | Movement |
|---|---|---|---|---|---|---|---|
| **BURIED** | `buried_s` | no (decal only) | **0** (cleared) | no | no (`apply_contact(false)`) | **no** (throw passes through) | direct-translate toward player at `track_speed`, ignoring walls |
| **TELEGRAPH** | `telegraph_lead_s` | no (decal pulses) | **0** (still cleared) | no | **no** (the dodge window) | no | frozen if `lock_surface_at_telegraph`, else keeps tracking |
| **SURFACED** | `surface_s` | **yes** (pop) | **16** (restored) | yes | **yes** (`apply_contact(hit)`, `kills`-gated) | **yes** (`ThrowInteraction` `&"die"`) | **static** (a pop, not a lunge — §9 Q3) |

Transitions emit the S0-locked vocabulary (§6): `&"telegraph"` on BURIED→TELEGRAPH, `&"state"` on
TELEGRAPH→SURFACED and SURFACED→BURIED. On SURFACED→BURIED the component calls `lethal.apply_contact(false, true)`
to re-arm the BUG6 latch on the falling edge (`charge_lane.gd:139` idiom), so the *next* surface can catch
cleanly.

**What `BurrowCycle` owns** (the ONE new component): the phase FSM + its time-in-phase accumulator; the
collision-layer + group cycling (clear on BURIED entry, restore on SURFACED entry); the underground tracking
(direct-translate movement, wall-ignoring); the locked-surface-point computation + driving the decal's position;
the per-instance phase-salt desync offset (§5); and feeding `LethalContact.apply_contact` the gated `hit`.

**What it reuses unchanged:** `LethalContact` (`&"external"` mode — the gated kill machinery + BUG6 latch + L5
`kills` gate + emit-always telemetry); `ThrowInteraction` (`&"die"` — reachable only while surfaced);
`TelegraphFSM` (the decal pulse throb + hard color flips, driven by the host off the state-change hook, exactly as
the Charger drives it). This is the identical reuse footprint the Charger established.

### 2.2 `burrower.tres` — full params + `param_schema`

Top-level `OppositionDef` fields (the v2 schema, `opposition_def.gd`):

| Field | Value | Note |
|---|---|---|
| `id` | `&"burrower"` | stable — events/telemetry/save/tests; fiction name is `display_name` only |
| `display_name` | `"Sinkmaw"` (per §1.5 pick) | display-only |
| `archetype` | `"actor"` | `CharacterBody2D` |
| `host_scene` | `burrower.tscn` | the new host |
| `credit_cost` | `2` | mid-cost — a Burrower is a lane-denial encounter (builder-read; balance = TG2/M3) |
| `spawn_weight` | `1.0` | deck draw weight (builder-read) |
| `min_band` | `3` | band-3-exclusive gate (breakdown OQ9) — never eligible in bands 1–2 |
| `cap_group` | `&"new_hazards"` | shares the K5/charger/splitter service ceiling pool |
| `per_room_cap` | `1` | at most one Burrower per room (a rhythm read, not a swarm) |
| `per_band_cap` | `3` | band ceiling |
| `lethality` | `"lethal"` | catch = death path (when surfaced) |
| `kills` | `true` | the L5 `*_kills` gate (per-def) |

`params` + `param_schema` (the `BurrowCycle` knob bag + its self-describing schema; the linter asserts the
`params ↔ param_schema` bijection per-def — the 9th def). `base_count`/`count_per_depth` are **builder-read
spawn-card keys** (never reach the entity — the charger/splitter convention); the rest are entity-read:

| `params` key | Type | Default | Min | Max | Gloss (CSV key) | Behaviour it drives |
|---|---|---|---|---|---|---|
| `base_count` | int | `1` | `0` | `10` | `CFG_GLOSS_BURROWER_BASE_COUNT` | Builder spawn-card: base spawns per band. |
| `count_per_depth` | float | `0.0` | `0.0` | `5.0` | `CFG_GLOSS_BURROWER_COUNT_PER_DEPTH` | Builder spawn-card: +spawns per depth index. |
| `buried_s` | float | `3.0` | `0.5` | `12.0` | `CFG_GLOSS_BURROWER_BURIED_S` | Seconds buried per cycle (the "safe to cross" window). Longer = easier turf. |
| `surface_s` | float | `1.2` | `0.3` | `5.0` | `CFG_GLOSS_BURROWER_SURFACE_S` | Seconds surfaced — the lethal + throw-kill window. The committed-punish window (exploration: ~1s). |
| `track_speed` | float | `80.0` | `0.0` | `200.0` | `CFG_GLOSS_BURROWER_TRACK_SPEED` | Underground follow speed (px/s). `< 200` (player) so it's outwalkable. `0` = stationary area-denier (a pure timed obstacle). |
| `telegraph_lead_s` | float | `0.9` | `0.3` | `2.5` | `CFG_GLOSS_BURROWER_TELEGRAPH_LEAD_S` | The dodge window (decal pulses, body still buried + non-lethal). **The fairness line** — never lethal inside it. |
| `kill_radius` | float | `26.0` | `0.0` | `64.0` | `CFG_GLOSS_BURROWER_KILL_RADIUS` | Surfaced lethal catch distance (script distance test + BUG6 latch). `0` = can't catch (a pure area-scare — `trap_if_neutral`). |
| `lock_surface_at_telegraph` | bool | `true` | — | — | `CFG_GLOSS_BURROWER_LOCK_SURFACE` | `true` = surface point freezes at telegraph start (fair — dodgeable). `false` = keeps tracking through telegraph (the unfair/harder variant — §9 Q4). |
| `kills` | bool | `true` | — | — | `CFG_GLOSS_BURROWER_KILLS` | The L5 `kills` gate (mirrors the def's typed field; per-instance/harness override via ctx). |

That is **9 keys** (2 spawn-card + 7 entity) — the same shape as the charger/splitter bags. `kill_radius` carries
`trap_if_neutral: true` (0 = inert, the splitter `catch_radius` convention). The host's code `DEFAULTS` mirror
must equal these `params` values byte-for-byte (`test_burrower` case (1) pins it, no code/data drift).

### 2.3 Underground tracking — deterministic, wall-ignoring

While BURIED, the component translates the host toward the player at `track_speed`, **without** `move_and_slide`:

```
to_player = player.global_position - host.global_position
step = to_player.normalized() * track_speed * delta   (clamped so it never overshoots the player)
host.global_position += step
```

This ignores walls by construction (no physics resolution) — the exploration's "moves under walls." It is a pure
function of the live player position + `delta` (reactive run-state, like R1's chase), touches no `RNG`, and never
feeds `fingerprint()`. When TELEGRAPH begins, the **surface point** is captured (`_surface_point =
host.global_position` if `lock_surface_at_telegraph`, else it keeps tracking and the point is re-read each frame);
the body remains at/around the surface point through SURFACED (static pop). Recommendation: while `track_speed`
would carry the buried body past the player, clamp so it settles *at* the player's last position rather than
oscillating — a slow area-denier that "arrives under you" reads better than one that jitters (§9 Q6, technical).

### 2.4 The collision + lethality cycle (the one genuinely new mechanic)

On **entering BURIED** (and at `_configure`/re-setup): `host.collision_layer = 0`; remove from `&"hazard"` group;
hide the body visual, show the decal; `lethal.apply_contact(false, true)` (non-lethal + re-armed).
On **entering SURFACED**: `host.collision_layer = 16`; add to `&"hazard"` group; show the body visual, settle the
decal. Each SURFACED frame: `hit = host.global_position.distance_to(player.global_position) <= kill_radius`, then
`lethal.apply_contact(hit, true)` — the reused emit-always + L5 gate + BUG6 latch fires exactly once on the rising
edge (`lethal_contact.gd:102-107`). This is the `ChargeLane._test_lethal_sweep` shape with a static radius test
instead of a swept segment.

> **Design note — why `collision_layer` write, not a new `LethalContact` mode.** The gated *lethality* is fully
> covered by the existing `&"external"` seam (contact math supplied from outside). The only *new* behaviour is the
> per-phase `collision_layer`/group cycling for throw pass-through — and that is a plain property write on the
> component's own host, exactly analogous to `ChargeLane._set_throwable`'s group write. So `BurrowCycle` owns it;
> `LethalContact`/`ThrowInteraction`/`ThrownItem` are all untouched (§8 ledger, §9 seam note).

---

## 3. Pseudocode (illustrative — against the real APIs)

GDScript-flavoured pseudocode. **Illustrative, not final** — the programmer owns the real implementation and
composes the S2 components; this shows the *contract usage* against the shipped `ChargeLane`/`charger_hazard.gd`
shapes.

### 3.1 `BurrowCycle` — the ONE new component (`scenes/hazards/components/burrow_cycle.gd`)

```gdscript
class_name BurrowCycle
extends OppositionComponent
## BurrowCycle (T2b, M1.10) — the ONE new opposition component of the Burrower's
## Phase-E proof: a BURIED → TELEGRAPH → SURFACED → BURIED cycle that toggles the
## host's collision_layer + group per-phase (throw pass-through while buried),
## tracks the player underground ignoring walls, and gates LethalContact to the
## SURFACED window. Everything else is REUSED (LethalContact &"external",
## ThrowInteraction &"die", TelegraphFSM pulse). RNG-FREE; the FSM is run-state and
## never feeds fingerprint().

enum Phase { BURIED, TELEGRAPH, SURFACED }

const HAZARD_LAYER := 16   # the shipped hazard collision_layer bit (charger/splitter)

## Reused seams, assigned by the HOST at _ready (the ChargeLane.lethal idiom).
var lethal: LethalContact = null           # &"external" gated kill sink
var on_state_changed: Callable = Callable() # host paints tells + emits S0 rows here

# --- snapshotted knobs (bound once via _configure; never re-read mid-run) --------
var _buried_s := 0.0
var _telegraph_s := 0.0
var _surface_s := 0.0
var _track_speed := 0.0
var _kill_radius := 0.0
var _lock_surface := true

# --- run-state -------------------------------------------------------------------
var _body: CharacterBody2D = null
var _phase: int = Phase.BURIED
var _t := 0.0                     # time-in-phase
var _phase_offset := 0.0          # per-instance desync (from ctx["phase_salt"], §5)
var _surface_point := Vector2.ZERO


func _configure(p: Dictionary, ctx: Dictionary) -> void:
	_buried_s = float(p.get("buried_s", 0.0))
	_telegraph_s = float(p.get("telegraph_lead_s", 0.0))
	_surface_s = float(p.get("surface_s", 0.0))
	_track_speed = maxf(float(p.get("track_speed", 0.0)), 0.0)
	_kill_radius = float(p.get("kill_radius", 0.0))
	_lock_surface = bool(p.get("lock_surface_at_telegraph", true))
	_body = host as CharacterBody2D
	# Per-instance desync: a PURE function of the builder-stamped phase_salt (NO RNG).
	# Offsets the initial buried timer so co-located burrowers never pop in unison (§5).
	var salt := int(ctx.get("phase_salt", 0))
	_phase_offset = fmod(float(salt) * 0.6180339887, 1.0) * maxf(_buried_s, 0.0001)
	# Re-setup starts BURIED (the family re-setup reset) WITHOUT firing the host hook.
	_phase = Phase.BURIED
	_t = _phase_offset
	_enter_buried_state(false)


## Called by the HOST each physics frame (fixed order; components never self-tick).
func tick(delta: float) -> void:
	if _body == null or player == null:
		return
	_t += delta
	match _phase:
		Phase.BURIED:
			_track_underground(delta)          # direct-translate, wall-ignoring
			if _t >= _buried_s:
				_surface_point = _body.global_position   # captured at telegraph START
				_enter(Phase.TELEGRAPH)
		Phase.TELEGRAPH:
			if not _lock_surface:
				_track_underground(delta)        # unfair variant: keeps chasing
				_surface_point = _body.global_position
			# body stays buried + NON-LETHAL for the whole lead (the dodge window)
			if lethal != null:
				lethal.apply_contact(false, true)
			if _t >= _telegraph_s:
				_enter_surfaced_state()
				_enter(Phase.SURFACED)
		Phase.SURFACED:
			_body.velocity = Vector2.ZERO        # static pop (not a lunge — §9 Q3)
			if lethal != null:
				var hit: bool = _body.global_position.distance_to(player.global_position) <= _kill_radius
				lethal.apply_contact(hit, true)  # emit-always + BUG6 latch + L5 gate
			if _t >= _surface_s:
				if lethal != null:
					lethal.apply_contact(false, true)   # falling edge → re-arm
				_enter_buried_state(true)
				_enter(Phase.BURIED)


func get_phase() -> int:
	return _phase


func _track_underground(delta: float) -> void:
	var to_p: Vector2 = player.global_position - _body.global_position
	var d: float = to_p.length()
	if d <= 0.001:
		return
	var step: float = minf(_track_speed * delta, d)   # never overshoot the player
	_body.global_position += to_p / d * step          # NO move_and_slide → ignores walls


## BURIED/TELEGRAPH: off the hazard layer + group so a throw PASSES THROUGH (not a
## re-drop — §1.3) and the body is un-targetable. `visual` toggles the greybox.
func _enter_buried_state(_show_bury_juice: bool) -> void:
	_body.collision_layer = 0
	if _body.is_in_group(&"hazard"):
		_body.remove_from_group(&"hazard")


## SURFACED: restore the layer + group so the throw-kill path + LethalContact work.
func _enter_surfaced_state() -> void:
	_body.collision_layer = HAZARD_LAYER
	if not _body.is_in_group(&"hazard"):
		_body.add_to_group(&"hazard")


func _enter(next: int) -> void:
	_phase = next
	_t = 0.0
	if on_state_changed.is_valid():
		on_state_changed.call(next)
```

### 3.2 `burrower_hazard.gd` — the host shell (composes the S2 set + BurrowCycle)

```gdscript
class_name BurrowerHazard
extends CharacterBody2D
## BurrowerHazard (T2b, M1.10) — "Sinkmaw": the buried rhythm area-denier. The S2
## Actor-host family skeleton (per-frame guard, self-timed clock, fixed component
## tick order, snapshot at setup) — the behaviour lives in the reused component set +
## the ONE new BurrowCycle. Collision: layer cycles 0↔16 per-phase (BurrowCycle owns
## it); mask world(2) but never move_and_slide'd (buried movement is direct-translate).
## ALL-OFF: ships OFF (min_band=3, in no default lever/preset/deck) → never loaded.
## NEVER references the global RNG autoload.

const DEFAULTS := {           # MUST mirror burrower.tres params (test_burrower pins it)
	"buried_s": 3.0, "surface_s": 1.2, "track_speed": 80.0,
	"telegraph_lead_s": 0.9, "kill_radius": 26.0,
	"lock_surface_at_telegraph": true, "kills": true,
}
## Greybox palette (§7 — character-animator ratifies at the gate). Distinct from the
## charger wedge / splitter blob / R1 diamond by silhouette (a FLOOR RING with no body).
const COLOR_DECAL := Color(0.5, 0.35, 0.25, 0.35)   # dusty "disturbed earth" ring
const COLOR_DECAL_TELE := Color(0.95, 0.55, 0.15, 0.6) # amber pulse — "about to pop"
const COLOR_BODY := Color(0.6, 0.42, 0.3)           # earthy mound
const COLOR_BODY_RIM := Color(0.95, 0.25, 0.2)      # hot rim — lethal NOW

var _cfg: RunConfig
var _player: Node2D
var _spawn_time := 0.0

var _lethal: LethalContact = null
var _throw: ThrowInteraction = null
var _fsm: TelegraphFSM = null
var _cycle: BurrowCycle = null

@onready var _decal: Polygon2D = $Decal     # the buried ground ring (always present)
@onready var _bodyvis: Polygon2D = $Body    # the surfaced mound (hidden while buried)


func _ready() -> void:
	_lethal = OppositionComponent.acquire(self, LethalContact) as LethalContact
	_throw = OppositionComponent.acquire(self, ThrowInteraction) as ThrowInteraction
	_fsm = OppositionComponent.acquire(self, TelegraphFSM) as TelegraphFSM
	_cycle = OppositionComponent.acquire(self, BurrowCycle) as BurrowCycle
	_fsm.tell = _decal                 # the pulse throb plays on the DECAL
	_cycle.lethal = _lethal            # reused &"external"-mode kill machinery
	_cycle.on_state_changed = _on_phase


func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_spawn_time = 0.0
	var p := _resolve_params(spawn_ctx)
	_lethal.bind(self, player, p, spawn_ctx)   # resets the BUG6 latch (re-setup safe)
	_throw.bind(self, player, p, spawn_ctx)    # &"die": reachable only while surfaced
	_fsm.bind(self, player, p, spawn_ctx)
	_cycle.bind(self, player, p, spawn_ctx)    # seats BURIED (layer 0, no host-hook fire)
	_seat_buried_visual()


func _resolve_params(spawn_ctx: Dictionary) -> Dictionary:
	var dp: Dictionary = spawn_ctx.get("params", {})
	var p: Dictionary = {}
	for key: String in DEFAULTS:
		p[key] = dp.get(key, DEFAULTS[key])
	# LethalContact &"external" wiring (the ChargeLane resolve shape):
	p["def_id"] = &"burrower"
	p["emit_family"] = &"new_hazard_killed"
	p["lethal_mode"] = &"external"
	p["latch_rearm"] = true
	p["throw_mode"] = &"die"
	p["pulse_seconds"] = float(p["telegraph_lead_s"])   # TelegraphFSM throb basis
	return p


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return
	_spawn_time += delta
	_cycle.tick(delta)      # the four-phase FSM (drives LethalContact's external seam)
	# presentation only (headless/paused-safe — the phase carries the read)


func run_clock_ms() -> int:
	return int(_spawn_time * 1000.0)


func get_def_id() -> StringName:
	return &"burrower"


func resolve_throw_death(killer_ctx: Dictionary) -> bool:
	return _throw.resolve_throw_death(killer_ctx)   # &"die" → false → thrower frees us


## Test/inspection seam: the BurrowCycle phase (BurrowCycle.Phase values).
func phase() -> int:
	return _cycle.get_phase()


## BurrowCycle transition hook: hard tell flips + the S0 LOCKED telemetry vocabulary.
func _on_phase(next: int) -> void:
	var depth: int = GameState.current_depth_index
	var run_t_ms: int = run_clock_ms()
	match next:
		BurrowCycle.Phase.TELEGRAPH:
			_decal.color = COLOR_DECAL_TELE
			_fsm.start_throb()      # the pulse (pure juice)
			EventBus.opposition_event.emit(&"burrower", &"telegraph", depth, run_t_ms)
		BurrowCycle.Phase.SURFACED:
			_fsm.stop_throb()
			_show_surfaced_visual()
			EventBus.opposition_event.emit(&"burrower", &"state", depth, run_t_ms)
		BurrowCycle.Phase.BURIED:
			_seat_buried_visual()
			EventBus.opposition_event.emit(&"burrower", &"state", depth, run_t_ms)
```

### 3.3 `burrower.tscn` (mirrors `charger.tscn`/`splitter.tscn`)

```
[node name="Burrower" type="CharacterBody2D" groups=["hazard"]]   # starts in group;
  collision_layer = 16                                            # BurrowCycle clears
  collision_mask = 2                                              # both on BURIED entry
  script = burrower_hazard.gd
  [Decal : Polygon2D]  # the buried ground ring (a low-alpha annulus)
  [Body  : Polygon2D]  # the surfaced mound (visible=false at author time)
  [CollisionShape2D : CircleShape2D radius≈16]
```
The scene declares layer 16 + group so a *bare* instance (schema harness) reports correctly; `BurrowCycle._configure`
immediately seats BURIED (layer 0, out of group) at `setup`. Node name `"Burrower"` + `get_def_id()` give
`ThrownItem._hazard_kind` a stable kind (`thrown_item.gd:135-137`).

### 3.4 `test_burrower` plan (per the breakdown DoD — runs as a SCENE, `test_burrower.tscn`)

Mirrors `test_charger.gd`'s harness (stub player, `spawn_ctx["params"]` fast-cycle knobs, real physics frames,
signal sinks). Cases:

1. **Def contract.** `burrower.tres` loads as `OppositionDef`; `id == &"burrower"`; card (`min_band=3`,
   `credit_cost=2`, `cap_group=&"new_hazards"`, `per_room_cap=1`, `per_band_cap=3`, `kills`); `params` mirror
   `BurrowerHazard.DEFAULTS` exactly (+ only `base_count`/`count_per_depth` beyond the entity keys); host contract
   (root class `BurrowerHazard`, node name `"Burrower"`, in `&"hazard"` group at author time,
   `get_def_id()==&"burrower"`, `resolve_throw_death` present); `param_schema ↔ params` bijection green (9th def);
   Decal + Body polygons triangulate to >0 triangles (the invisible-hazard guard).
2. **All-off gate.** `&"burrower"` in neither `RunConfig.new().oppositions_enabled` nor
   `make_default_play_preset()` nor `band_greybox`/`band_two` decks; the all-off pipeline fp `== e943ac9c8bc1`
   (control untouched).
3. **Cycle timing from params.** With fast-cycle knobs, `phase()` holds BURIED ~`buried_s`, TELEGRAPH
   ~`telegraph_lead_s`, SURFACED ~`surface_s`, then BURIED again (frame-count tolerances, the `test_charger`
   `_await_state` shape). Telemetry: exactly one `&"telegraph"` per cycle + `&"state"` on surface/bury; no
   out-of-vocabulary `opposition_event` token (S0 locked set `[&"telegraph",&"state",&"hit_player"]`).
4. **Buried = throw passes through (DoD).** During BURIED, `collision_layer == 0` and the host is out of the
   `&"hazard"` group; throw a `ThrownItem` across the buried body → **no** `throw_killed_hazard(&"burrower")`, the
   burrower stays alive, and the projectile is NOT re-dropped at its feet (it flies on to its own max-range miss
   elsewhere). Contrast with a SURFACED throw (case 7) which *does* kill.
5. **Buried = non-lethal contact (DoD).** Park the player on the buried body through a full BURIED+TELEGRAPH
   window → `run_active` stays true, zero `&"hit_player"` rows (lethality armed only in SURFACED). "Surface under
   the player never kills inside the dodge frame": with the player on the locked surface point, assert
   `run_active` at every frame of TELEGRAPH (`telegraph_lead_s`).
6. **Dodge frame honored (DoD — the fairness line).** `lock_surface_at_telegraph=true`: player on the tracked
   point at telegraph start; the decal freezes; the player steps `> kill_radius + player_r` away **during**
   TELEGRAPH → at SURFACED, zero `&"hit_player"`, `run_active` true (a fair dodge). Conversely, a player who
   **stays** on the locked point through surfacing IS caught (case 7) — the warning was honored, so the kill is
   fair.
7. **Surfaced kill is `kills`-gated + throw-killable (DoD).** `kills=true`, player on the surface point through
   SURFACED → `fail_run(&"death")`, `opposition_killed_player(&"burrower")` **exactly once**,
   `new_hazard_killed(&"burrower")` once, one `&"hit_player"` (BUG6 latch). `kills=false`, same geometry → the
   contact rows fire but `run_active` stays true, no `opposition_killed_player` (Correction-2 semantics). A
   `ThrownItem` at a SURFACED body → `throw_killed_hazard(&"burrower")`, burrower freed.
8. **Wall-crossing while buried (DoD).** A `world`-layer wall between the burrower and the player; while BURIED it
   direct-translates *under* the wall (its x crosses the wall face — the exploration's "ignores world collision
   underground"), whereas a `move_and_slide` mover (the charger) would be stopped. Assert the buried burrower's
   position passes the wall toward the player.
9. **RNG-free (DoD (9) audit).** `burrow_cycle.gd` + `burrower_hazard.gd` contain no `"RNG."` substring.
10. **Phase-salt desync (§5).** Two burrowers with **different** `ctx["phase_salt"]` reach SURFACED at
    **different** frames; the **same** `phase_salt` twice → identical phase timeline (deterministic, no RNG).
11. **Deterministic placement through the REAL builder+service.** Same synthetic `band_three`-shaped band + deck
    twice → identical burrower spawn cells; `per_band_cap=3` binds; `min_band=3` refuses a band-depth-2 profile
    (band-3-exclusivity) — the `test_charger` case (10) shape.

---

## 4. Determinism & fairness — the two hard invariants restated as acceptance

1. **Generation-time `fingerprint()` unaffected by the Burrower's cycle.** The FSM is real-time run-state (delta-
   driven, like `ChargeLane`), placement is the builder's RNG-free stable walk, and per-instance desync derives
   from the builder-stamped `phase_salt` — **no global `RNG` anywhere**. The three control fingerprints
   (`e943ac9c8bc1`, `band_greybox`, `band_two`) are byte-identical (T2b adds only data + a component never
   constructed when the def is off; it touches no generation path). `test_burrower` case (2) pins the all-off
   control; the band controls are pinned by T2b touching zero generation code.
2. **The dodge frame is guaranteed.** Lethality arms only in SURFACED (never in BURIED/TELEGRAPH); a
   `telegraph_lead_s` window precedes every surface; the surface point locks at telegraph start
   (`lock_surface_at_telegraph=true`). `test_burrower` cases (5)+(6) prove "surface under the player never kills
   inside the dodge frame" and that stepping off the locked point during the lead is safe.

---

## 5. Determinism / desync notes (the phase-salt discipline)

- **Placement** is generation-time, seed-deterministic — `EncounterBuilder.populate` walks pieces in the stable
  RNG-free order and strides cells (`encounter_builder.gd:347-368`); the Burrower is placed identically to every
  other new def. It feeds nothing to `fingerprint()`.
- **Cycle phase** must be deterministic-yet-desynced so co-located Burrowers don't all pop in unison (a legibility
  disaster). The builder already stamps `ctx["phase_salt"] = depth_index * 131 + k` (`encounter_builder.gd:119`).
  `BurrowCycle._configure` derives `_phase_offset = fmod(phase_salt * φ⁻¹, 1) * buried_s` (a pure irrational-
  multiplier hash, **no `RNG`**), seeding the initial BURIED timer. Two Burrowers with different `k` desync
  deterministically; the same seed+config reproduces the same offsets. This mirrors the spike's
  `phase_salt`-driven per-instance phase (the `legacy_ctx` comment, `encounter_builder.gd:104`).
- **The real-time FSM is *not* frame-deterministic across machines** — and that is correct: it's run-state, never
  hashed. `test_burrower` asserts timing within frame tolerances (the `test_charger` convention), never exact
  equality, and asserts *relative* desync (two salts → different surface frames), not an absolute schedule.

---

## 6. Telemetry — BUG6-latch + vocabulary conformance

The Burrower emits **only** the two generic signals S0 pre-declares (`opposition_event`,
`opposition_killed_player`); it touches neither `event_bus.gd` nor `telemetry/`. Payloads primitives-only. The S0
LOCKED vocabulary (`test_charger.gd:241-243`) is honored exactly:

| Signal / `event` | When | Emitter | Notes |
|---|---|---|---|
| `opposition_event(&"burrower", &"spawned", depth, ms)` | placed by the builder | **SpawnService** (central) | the Burrower writes no `&"spawned"` |
| `opposition_event(&"burrower", &"telegraph", depth, ms)` | BURIED→TELEGRAPH (the pulse) | host `_on_phase` | the shared telegraph token (charger idiom) |
| `opposition_event(&"burrower", &"state", depth, ms)` | TELEGRAPH→SURFACED, SURFACED→BURIED | host `_on_phase` | every non-telegraph transition (the pursuer/charger `&"state"` idiom) |
| `opposition_event(&"burrower", &"hit_player", depth, ms)` | on a SURFACED catch (rising edge) | **LethalContact** (emit-always) | fires fatal or not; the BUG6 latch → exactly once per surface |
| `opposition_killed_player(&"burrower", depth, ms)` | on a **fatal** SURFACED catch only | **LethalContact** (gated) | the L5 `kills` gate; `run_ended.reason=="death"` via `fail_run` |
| `opposition_event(&"burrower", &"killed_by_throw", depth, ms)` | on a SURFACED throw-kill | **ThrownItem** | the migration twin of `throw_killed_hazard` |

**BUG6 conformance:** `LethalContact.apply_contact` fires the catch exactly once on the rising edge into contact
and re-arms only on the falling edge (`lethal_contact.gd:102-107`). The Burrower re-arms explicitly on
SURFACED→BURIED (`apply_contact(false, true)`) so each *surface* is a fresh rising edge — a player standing on a
Burrower across two surfaces is caught at most once per surface, never per-frame. `GameState._run_ended` owns
run-end idempotency (no local guard), so the first fatal surface ends the run and later frames are absorbed.
**No new EventBus signal, no new end-cause** — the whole Burrower rides `fail_run(&"death")`.

---

## 7. Placeholder asset spec (character-animator, inline greybox — no PixelLab)

The readability job: teach "**the ground is unsafe on a beat, but only when it breaches**" — so the Burrower's
identity is a **floor decal that usually has no body**, distinct from every shipped hazard's ever-present body.
Filter OFF; inline `Polygon2D` shapes; the color flip carries the state if a `Tween` is over-scope or headless.

| Phase | Shape | Color | Motion |
|---|---|---|---|
| **BURIED** | a low-alpha **ground ring / annulus** on the floor (the "disturbed earth" tell); **no body** | dusty brown `Color(0.5,0.35,0.25,0.35)` — reads as *ground*, not a creature | the ring slides slowly toward the player (`track_speed`); a faint slow shimmer |
| **TELEGRAPH** | the same ring, now **pulsing** (`TelegraphFSM.start_throb`) and **frozen in place** (locked) | shifts hotter to amber `Color(0.95,0.55,0.15,0.6)` — "about to pop; step off" | the throb tempo IS the lead clock; the freeze is the fairness cue (it stopped following you) |
| **SURFACED** | a solid **mound / breach blob** pops up at the ring centre (~1.2× player), with a **hot rim** | earthy `Color(0.6,0.42,0.3)` body + rim `Color(0.95,0.25,0.2)` — lethal NOW | a quick pop-up `Tween` on entry; **static** while surfaced (no lunge); a quick collapse on re-bury |

**Why this reads fairly:** the ring *freezing* at telegraph is the "you will be hit here" contract — the player
learns "amber-and-still = leave"; the body only exists (and only threatens) during the pop. The silhouette is
deliberately unlike the charger wedge / splitter blob / R1 diamond / spike star / pingpong box / bomb circle: a
**flat floor ring with no body** for most of the cycle is unmistakable. A hard color swap (`COLOR_DECAL` →
`COLOR_DECAL_TELE` → body visible) is an acceptable fallback if even the `Tween` is over-scope (the bomb
`_flash_blast` idiom). No sprite sheets, no `AnimationTree`.

---

## 8. Files + the bespoke-code cost ledger (the version-defining measurement)

**Create (T2b-owned, file-disjoint from T0/T2a):**
- `data/oppositions/burrower.tres` — the def (§2.2). *Data — not bespoke code.*
- `scenes/hazards/burrower.tscn` — the host scene (§3.3). *Scene — not bespoke code.*
- `scenes/hazards/burrower_hazard.gd` — the host shell (§3.2). *Bespoke (host glue).*
- `scenes/hazards/components/burrow_cycle.gd` — **the ONE new component** (§3.1). *Bespoke (the new mechanic).*
- `tests/test_burrower.tscn` + `.gd` — the DoD test (§3.4). *Test — not counted as bespoke.*

**Predicted bespoke-code ledger (the TG3 evidence):**

| File | Kind | Predicted lines | Comparable shipped file |
|---|---|---|---|
| `burrow_cycle.gd` | new component | **~120–150** | `charge_lane.gd` = 207 (Burrower is simpler: static pop, no swept test, no lane geometry) |
| `burrower_hazard.gd` | host shell | **~110–140** | `charger_hazard.gd` = 219, `splitter.gd` = 355 (Burrower has no split logic) |
| **Total non-data, non-test bespoke** | | **~230–290 lines** | Charger ≈ 426; Splitter ≈ 355 |

**Ledger claim:** the Burrower should come in **at or below the Charger's bespoke cost** — one new component +
one host shell, **zero shared-file edits**, def + scene + test as data/scaffolding. The single *genuinely new*
mechanic is the per-phase `collision_layer`/group cycling (≈12 lines in `burrow_cycle.gd`), a one-step extension
of `ChargeLane._set_throwable`'s established per-phase group toggle. If the build needs more than this, the
"phased vulnerability = data + one component" claim is weaker than predicted — the worklog records the actual
numbers for TG3.

**Must NOT touch (contract — the parallel-wave / single-writer rule):** `systems/event_bus.gd` (S0 pre-declares
the generic signals — emit only), `systems/game_state.gd` (`fail_run`/`current_depth_index` read-only),
`scenes/game/main_game.gd` (T1's sole write this version), `systems/spawning/spawn_service.gd`,
`systems/spawning/encounter_builder.gd`, and every shared component (`lethal_contact.gd`, `throw_interaction.gd`,
`telegraph_fsm.gd`, `opposition_component.gd`) + `entities/thrown_item/thrown_item.gd`. **Predicted shared edits:
zero** (§9 seam note). `data/bands/band_three.tres` is **T3's** file — T2b only *provides the id* `&"burrower"`
for T3's deck.

---

## 9. Open Questions (Phase-2 — Phase-3 resolves; fun/fairness flagged "needs Director review")

**Fun / fairness / tone / scope — needs Director review (recommendation attached):**

- **Q1 — Fiction/name + palette direction.** *Tone.* Which of §1.5's three pitches — (A) Sinkmaw/Grinder
  (mechanical, cave-native), (B) Silt-lurker (creature), (C) Undertow/Subsidence (place-as-enemy)? **Recommend
  (A)** for the tightest junkyard-machine fiction coupling and the clearest "a mechanism is aiming at me"
  telegraph (which serves fairness). `id` stays `&"burrower"` regardless. **Director review.**
- **Q2 — Deck exclusivity: `band_three`-only in M1.10?** *Fun/scope.* Breakdown OQ9 recommends yes (clean A/B at
  TG2, D-RAT-2 precedent). **Recommend `min_band=3`, band-3 deck only.** **Director review (ratify).**
- **Q3 — Surface: static pop vs lunge.** *Fun/fairness.* The exploration recommends a **static pop** for greybox
  readability (a lunge is scarier but adds an un-telegraphed vector). **Recommend static pop** — it keeps the
  fairness contract simple (the decal *is* the kill zone) and needs no new movement code; a lunge is a
  post-gate variant if the surface reads as toothless. **Director review.**
- **Q4 — Decal: exact locked position vs vague zone (breakdown OQ8).** *Fun/fairness — the core call.* Exact
  locked position = fair + readable (recommended); a vague rumble zone = tense but risks feel-bad surprise
  surfaces. **Recommend `lock_surface_at_telegraph=true` (exact, locked)** as the shipped default, with the vague/
  tracking variant available via the knob (`false`) for a Director sweep. This is *the* fairness line the
  exploration + breakdown both flag. **Director review.**
- **Q5 — Default `track_speed` and the cycle tempo (`buried_s`/`surface_s`/`telegraph_lead_s`).** *Fun/balance.*
  Proposed 80 px/s (0.4× player), 3.0s buried / 0.9s telegraph / 1.2s surfaced — outwalkable, ~1s punish window
  (exploration). These are first-gate starting values; TG2 tunes them against deaths-per-first-encounter vs the
  Wrecker/Splitter baselines. **Recommend the proposed set; flag as playtest-tunable.** **Director review at the
  gate.**
- **Q6 — "Un-hittable while buried" vs the throw-centric verb set.** *Fun — the deliberate counter-lesson.* The
  exploration warns this could feel like "the throw doesn't work" rather than "wait for the window." **Recommend
  shipping it as designed** (it's the whole point — patience over reaction) **and validating at TG2** that the
  telegraph reads as an *invitation to wait*, not a bug. Mitigations if it feel-bads: shorten `buried_s`, lengthen
  `surface_s`, or brighten the surface tell. **Director validates at the gate.**

**Technical — Phase-3 resolves on merit (no Director needed unless noted):**

- **Q7 — Buried movement: clamp-at-player vs pass-and-return.** *Technical.* A direct-translate mover that
  reaches the player either **clamps** (settles under them — recommended, §2.3) or overshoots and oscillates.
  **Recommend clamp** (reads as "it arrived", no jitter; deterministic). Resolve to clamp.
- **Q8 — Group toggle: needed, or is `collision_layer=0` sufficient?** *Technical.* `collision_layer=0` alone
  gives true throw pass-through (§1.3). The `&"hazard"` group removal is defensive hygiene against a future
  group-scan. **Recommend keeping both** (cheap, belt-and-braces); if any shipped system iterates the group in a
  way the toggle breaks, drop the group toggle and keep only the layer clear. Resolve on merit; **no shared-file
  edit either way.**
- **Q9 — Seam check: does any of this need a shared-file edit?** *Technical (parallel-wave).* Predicted **no** —
  the gated kill is the existing `LethalContact` `&"external"` seam, throw-death is the existing `ThrowInteraction`
  `&"die"` path, and the collision cycling is a property write on the Burrower's own host. **If** the surfaced
  radius test turns out to want a new `LethalContact` mode (it should not — `&"external"` covers it), that is an
  **orchestrator-adjudicated request to the `LethalContact` writer**, raised at brief time, never a silent T2b
  edit. Confirm at brief time; **expected: zero shared edits.**
- **Q10 — Does the Burrower need its own host scene, or can it share one?** *Scope.* Unlike the Splitter (two defs
  sharing `splitter.tscn`), the Burrower is a single def with unique visuals (decal + body). **Recommend a
  dedicated `burrower.tscn` + `burrower_hazard.gd`** (§3.2–3.3). Resolve: dedicated host.
- **Q11 — `param_schema` enum/bool encoding for `lock_surface_at_telegraph`.** *Technical.* Follow the charger
  `throwable_while_charging` bool-schema encoding exactly (`{key, gloss, type:"bool", default}`) so the generated
  menu + bijection linter accept it unchanged. Resolve: mirror the charger bool schema.
