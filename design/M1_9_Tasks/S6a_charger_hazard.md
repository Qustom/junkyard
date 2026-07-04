# S6a — New hazard #1: the CHARGER — Expanded Design Spec

**Milestone:** M1.9 (Scalable Opposition + Band Systems) · **Workstream:** oppositions · **Wave:** 4 (parallel worktree)
**Task id:** S6a · **BlockedBy:** S2 (component set + `param_schema`), S3 (EncounterBuilder + generic `RunConfig` levers)
**Assignees:** general-purpose (entity + `ChargeLane` component + def + test) · character-animator (greybox sprite/tell — inline placeholder; PixelLab Director-gated)
**Author:** game-director-designer · **Status:** Phase 2 (per-task design). The `Open Questions` below feed Phase 3 (fresh-eyes resolution + Director ratification).

> **What this doc is.** Per CLAUDE.md's four-phase authoring, this is the S6a per-task design: the M1.9 breakdown's S6a contract expanded into mechanic detail, the `charger.tres` def + `param_schema`, the one-new-component (`ChargeLane`) FSM pseudocode against the real S2 component contract, spawn/placement rules, kill + throw semantics, the placeholder tell spec, telemetry, and the acceptance test names. It is **design only** — it ships **no game code and no `.tres`**. S6a is the **canonical Phase-E proof** of the exploration's headline claim: *adding an opposition is data + one small component, nothing else.* If the Charger needs more than `charger.tres` + a `ChargeLane` component (reusing Telegraph / Lethality / ThrowInteraction / the Actor host verbatim), the proof has failed and that is the SG3 watch-item.

---

## 0. Hard constraints (read first)

Straight from the M1.9 breakdown scope guardrails (§"Scope guardrails") and the cross-cutting contracts (§"Cross-cutting contracts"). The spec must not violate them, and neither may the build:

- **The proof is "def + ONE new component."** The single new engineering artefact is the **`ChargeLane` movement component** (telegraph → straight lethal dash → recover). *Everything else is reused verbatim from the S2 component set*: the **Actor host** (`CharacterBody2D` shell, the `setup(cfg, player, spawn_ctx)` handshake, the config snapshot), the **Telegraph** component (tell color-flip + wind-up flash), the **Lethality** component (L5 `*_kills`-gated `fail_run` + emit-always + the BUG6 one-shot latch), and the **ThrowInteraction** component (`die` — free on throw-kill). If S6a grows a second bespoke script, the Phase-E claim is broken — call it out in the worklog.
- **All-off is byte-identical.** The Charger ships **off by default**: it is not in `RunConfig.oppositions_enabled`, and `band_greybox`'s deck does not list it. With the shipped default, **no `charger.tres` is loaded and no node is instantiated** — the permanent all-off fingerprint **`e943ac9c8bc1`** is untouched, and `band_greybox`'s pipeline fingerprints are untouched. The Charger only becomes reachable via `band_two`'s deck (S7) behind the second hub portal (S8).
- **No HP pool. M1 lethality model only.** The Charger is **not** a damage-sponge — it fits the M1 model exactly: a **lethal contact** routed through the reused Lethality component's `*_kills`-gated `GameState.fail_run(&"death")` with **emit-always** telemetry. No health bar, no chip damage, no M2 Field/HP dependency.
- **Deterministic placement; per-instance variation only from `spawn_ctx` salts.** *Where* Chargers spawn is a pure function of `seed + config` — the builder walks the graded band RNG-free (`main_game.gd:734` stable order) and the service places them; **no global `RNG`** in the generation-time path, so `fingerprint()` never moves. Any per-instance variation the component wants (a dormant idle-pulse phase, a cooldown jitter) is derived from the `spawn_ctx` salt (`phase_salt = depth_index * 131 + k`, `main_game.gd:505`), **never** the global RNG. The Charger's *reactive* behaviour (when it wakes/charges, which way it dashes) is legitimately **run-state** (player-driven, like R1's chase) — reactive run-state never writes back to the layout stream, so it cannot poison determinism.
- **Locked contracts, read-only.** The Charger reads `GameState.active_run_config` (snapshotted at `setup`) and `GameState.current_depth_index`; it routes run-end through the **existing** `GameState.fail_run(&"death")` (no new end-cause). It emits only the **S0-pre-declared** generic signals (`opposition_event`, `opposition_killed_player`) via the reused Lethality/Telegraph components — it does **not** edit `event_bus.gd`, `game_state.gd`, or `run_config.gd`.
- **File-disjoint from S4 / S6b / S7 in Wave 4.** S6a owns **new files only**: `charger.tres`, a `charger.tscn` scene, the `charge_lane.gd` component script, and `tests/test_charger.*`. It does **not** edit `main_game.gd` (S3 already made it a thin consumer), the shared `thrown_item.gd`, or any config-menu file (S4's generated-section net picks the def up automatically from `param_schema`).
- **Placeholder art only; PixelLab is Director-gated.** The tell ships as an **inline greybox** (a directional `Polygon2D` wedge + `Tween` states — the M1 greybox norm). Any PixelLab generation needs an explicit Director OK (STATUS Blocked table).

---

## 1. Research — why the Charger is the proof case

### 1.1 The proof restated as requirements

The M1.9 breakdown (§"The one thing this version must prove") makes S6a the *canonical* demonstration that the S0–S3 architecture pays off: *"the exploration's canonical proof: **Charger = `charger.tres` def + a `ChargeLane`-style movement component** (telegraph → straight lethal dash → recover), everything else reused."* The v2 exploration names it directly — *"New explored ideas ship as `.tres` + component reuse (the 'Charger = def + `ChargeLane` component' proof)"* (Phase E) — and the v1 per-opposition composition table gives the Charger row explicitly:

| Opposition | Archetype | Movement | Trigger | Lethality | Throw | Spawn | Extra |
|---|---|---|---|---|---|---|---|
| **Charger** | Actor | **`ChargeLane`** *(new)* | proximity aggro | lethal | die | — | recover window = free throw target |

So the Charger is chosen not because it is the most interesting hazard, but because it is the **minimal honest test of the composition claim**: it needs exactly one movement idea the four shipped hazards don't have (a committed straight-line dash with a wind-up and a recovery), and *nothing else* — no projectiles (that's S6b/Sentry territory), no mid-run `svc.spawn` (that's S6b/Splitter, the *other* half of the API), no inventory hook, no HP pool. It isolates the "add a movement component" axis cleanly. S6b (Splitter) deliberately exercises the complementary axis (the mid-run multi-client `svc.spawn`), so the pair together prove both halves of the S0/S3 API.

### 1.2 Game-feel reference points (telegraphed dash enemies in top-down roguelites)

The Charger is a well-worn, legible archetype — the design intent is to hit the genre convention players already read fluently:

- **The Binding of Isaac — "Charger" / "Spitty" family.** The literal namesake: an enemy that rushes in a straight cardinal line toward the player, overshoots, and pauses before re-acquiring. The skill is the perpendicular step-off. Our Charger generalizes the line to *any* angle (locked at telegraph).
- **Hyper Light Drifter — the pink dash-hounds.** Rear-back **wind-up flash** → committed straight lunge → brief recovery. The canonical "the telegraph is the contract" feel: once it flashes, the lane is fixed and you side-step it. This is the exact readability target for our telegraph beat.
- **Enter the Gungeon — lunging bullet-kin / certain boss dashes.** A clear tell frame, then a fast straight commit; the punish is landing a shot during the recovery.
- **Nuclear Throne — rushers (e.g. Ballguys).** "Everything is an object," a fast straight rush you dodge laterally — validates the throwaway-node fidelity for a fast top-down game.
- **Hades — Numbskulls / dash-attackers (top-down enough).** Telegraph → dash → the reward is the free hit while they're committed.

**The load-bearing genre convention:** a *three-beat* rhythm — **wind-up (readable telegraph) → committed straight dash (you cannot influence it) → punishable recovery.** Every reference makes the recovery the reward window. Our `ChargeLane` implements exactly this three-beat FSM. Because our verbs are **move (perpendicular dodge)** and **throw (punish the recovery)** — both already in the build — the Charger reuses the player's existing kit with zero new player-side verbs (the v1 Charger sketch: *"Reuses the existing `player.facing`/movement with no new verbs"*).

### 1.3 What is reused vs. the ONE new thing

| Concern | Source | Reused / New |
|---|---|---|
| `CharacterBody2D` Actor host, `hazard` layer / `world` mask, `"hazard"` group, `setup(cfg, player, spawn_ctx)` snapshot | S2 Actor shell (as `hazard_entity.gd`/`pingpong_hazard.gd` today) | **Reused** |
| Tell color-flip + wind-up flash + one-shot juice `Tween` | S2 **Telegraph** component | **Reused** (new color/silhouette *values*, not new code) |
| `*_kills`-gated `fail_run(&"death")` + emit-always + BUG6 rising-edge latch | S2 **Lethality** component | **Reused** |
| Free-on-throw-kill (`queue_free`, item consumed) | S2 **ThrowInteraction** = `die` (+ the existing `thrown_item.gd` `is_in_group("hazard")` path) | **Reused** |
| Proximity aggro (wake when player within `aggro_range`) | folded into `ChargeLane` (a distance check), or the S2 proximity Trigger if one exists | **Reused / trivially in-component** |
| **Telegraph → locked-vector dash → recover FSM + wall-stop** | **`ChargeLane` component** | **NEW — the one new artefact** |
| `charger.tres` def + `param_schema` | data | **Data (the proof's whole point)** |

> **A deliberate scope call on the trigger (see OQ-2).** The v1 sketch's *sightline ray* trigger (charge when the player crosses a straight watched lane) is cooler, but a `SightlineTrigger` is a **second** new component the four shipped hazards never needed — building it would break the "ONE new thing" proof. So for S6a the aggro is a **proximity distance check owned by `ChargeLane`** (wake at `aggro_range`, lock the lane toward the player at telegraph start). The sightline-ray variant is flagged as a richer follow-up that costs a second component (OQ-2).

### 1.4 Fiction / tone fit — what *is* a Charger in the junkyard-multiverse?

The GDD frames threats as **"things that came through"** — *"entities that crawled in from wherever the portals lead. Junk is their habitat, not their body. They get more alien, less physical, and more dread-inducing by band"* (GDD §Threats). A Charger is a **near-band, still-physical** thing — it belongs in `band_two` (Temporal, "a junkyard from another *time*"), the first band where the entities are *"stranger"* but not yet reality-warping. Three flavor pitches for the Director (one-liners; the name/lore is a **tone call**):

1. **The Wrecker (recommended).** A junkyard **auto-crusher / bailing-ram that came through half-alive** — a heavy hydraulic press-head fused to something that wants to move. It sleeps compacted in the scrap; when you get close it winds its ram back (telegraph) and slams forward in a straight line, then has to re-pressurize (recover). *Fiction hook:* it's a machine from a scrapyard that learned to hunt. Reads instantly as "heavy thing that rushes and must reset."
2. **The Tumbler.** A **compacted junk-boulder / debris-comet** — a ball of crushed cars and rebar that a deeper band's gravity spat out. It gathers itself (telegraph shudder) then rolls in a dead-straight line until it hits a wall and has to unwind. Leans into the "bait it into geometry" counter (it *wants* to smash into walls).
3. **The Bull-hulk.** A **big animal-shaped thing** that crawled up from a Temporal band — a scrap-plated beast that lowers its head, paws, and gores in a straight charge, then stands stunned. The most "creature," the most dread; slightly less machine-legible than (1).

**Recommendation:** **(1) The Wrecker** — it's the most legible ("heavy machine that rams and resets"), sits cleanly in `band_two`'s Temporal/industrial-scrap fiction, and its recovery reads honestly as "re-pressurizing." *This is a tone/naming call — Director ratifies* (see OQ-8). For M1.9 greybox the `id` stays the mechanical **`&"charger"`** regardless of the display name, so telemetry/tests are name-stable.

### 1.5 Readability rules (grounded in the real player numbers)

The whole hazard lives or dies on the player being able to **read the telegraph and step out of the lane in time**. The real numbers from the build:

- **Player top speed: `max_speed = 200` px/s** (`data/player/player_movement_stats.gd:11`, authored in `data/player/player_movement.tres`), reached in ~0.1 s (accel 2000 px/s²). This is the anchor for every timing/speed default below.
- **Cell size: 16 px** (`main_game.gd:42`, `DEFAULT_CELL_SIZE_PX`). A room is a handful of cells; a lane a few cells long.
- **Player body radius: 14 px** (`player.tscn` `CircleShape2D`). Existing hazard bodies are r=10; the Charger reads **heavier** at r≈16–18 (see §2.7).
- **Lethal-contact floor:** `player_r + hazard_r` (the R1/K5 convention, `run_config.gd:69-71`) — the kill corridor half-width sits at/above this so "it hit me" reads honestly.

**Derived readability budget (three-beat, tuned against 200 px/s):**

- **Lateral escape geometry.** To clear a `lane_width ≈ 28 px` corridor the player must move ~`lane_width/2 + player_r ≈ 28 px` perpendicular. At 200 px/s that is **~0.14 s of travel** — so the telegraph must be **comfortably longer than 0.14 s** to be *physically* dodgeable, and longer still to be *fairly* dodgeable after human reaction (~0.2–0.25 s).
- **Telegraph (`telegraph_s`) default 0.5 s.** Reaction (~0.22 s) + lateral clear (~0.14 s) + margin. In the HLD/Isaac band. Min 0.2 s (twitchy, near-unfair — sweep floor), max 1.5 s (very telegraphed).
- **Dash speed (`charge_speed`) default 520 px/s ≈ 2.6× player.** Fast enough that a footrace *never* works (you must side-step, not outrun — the whole design), slow enough to stay tunnel-safe: at 520 px/s a physics frame moves ~8.7 px, far under the ~28 px kill corridor, so no pass-through (and §2.4 uses a **swept segment** test so even a maxed `charge_speed=900` — 15 px/frame — cannot tunnel).
- **Recover (`recover_s`) default 1.2 s** — the **core feel knob** (v1: *"too short = unkillable, too long = trivial"*). Long enough to walk up and throw one item as a punish; not so long the room is trivialized. The single most playtest-sensitive value — sweep it hardest at SG2.
- **State budget:** `DORMANT` (visible, inert, learnable) → `TELEGRAPH 0.5 s` (locked lane, escalating flash) → `CHARGE` (until wall or `charge_max_dist ≈ 220 px` travelled — an overshoot *past* the player) → `RECOVER 1.2 s` (stunned, vulnerable) → `DORMANT` after `cooldown_s 0.6 s`. Total worst-case "cycle" ≈ 0.5 + ~0.4 + 1.2 + 0.6 ≈ 2.7 s, a legible rhythm.
- **Tell must encode direction.** Unlike R1 (a symmetric diamond) the Charger's silhouette is **directional** (a wedge/arrow) so during `TELEGRAPH` the player reads *which way the lane points* and steps perpendicular — the telegraph is only fair if the lane is legible (§2.7).

---

## 2. Design spec + pseudocode

### 2.1 `charger.tres` — the `OppositionDef` (data — the proof's payload)

Authored against the S0/S2 `OppositionDef extends Resource` schema (exploration v2 §"Data layer"). All tuning lives in `params` (read by `ChargeLane`) with a mirroring `param_schema` (read by S4's generated menu + the params↔schema lint). Illustrative — S2 owns the exact `class_name`:

```gdscript
# data/oppositions/charger.tres  (illustrative — authored in the inspector)
id             = &"charger"                 # stable; events / telemetry / throw-kind / deck ref
display_name   = "Wrecker"                  # tone/naming — Director ratifies (OQ-8); id stays &"charger"
archetype      = "actor"
host_scene     = preload("res://scenes/hazards/charger.tscn")

# --- Spawn card (read by the EncounterBuilder, NOT the service) ---
credit_cost    = 2        # a strong denial threat — costs more band-budget than a basic pursuer (1)
spawn_weight   = 1.0      # relative draw weight in band_two's deck slot
min_band       = 1        # eligible from band-depth 1; band-2-EXCLUSIVITY comes from DECK membership,
                          #   not this gate (band_greybox's deck omits it) — OQ-6

# --- Hard caps (read by the SpawnService — every client obeys) ---
per_room_cap   = 1        # one Charger owns a room (multiple in one room = unreadable chaos) — OQ-5
per_band_cap   = 4        # 0 would fall back to the global ceiling

# --- Lethality (reused Lethality component, L5 semantics) ---
lethality      = "lethal"
kills          = true     # the L5 *_kills toggle, per-def (false = emits contact but never fail_run)

# --- Component knob bag (read by ChargeLane) + its self-describing schema ---
params = {
    "aggro_range": 160.0, "telegraph_s": 0.5, "charge_speed": 520.0,
    "charge_max_dist": 220.0, "recover_s": 1.2, "cooldown_s": 0.6,
    "lane_width": 28.0, "lock_at_telegraph_start": true,
    "throwable_while_charging": true, "wall_crash_recover_mult": 1.0,
}
param_schema = [ ... ]    # the table below, one row per params key (bijection lint-checked)
```

**`param_schema` table** (defaults tuned against player 200 px/s + 16 px cells; every value is a **sweep start**, not a balance claim):

| key | type | default | min | max | gloss / behaviour it drives |
|---|---|---|---|---|---|
| `aggro_range` | float (px) | **160** | 32 | 400 | Distance at which a `DORMANT` Charger wakes and begins `TELEGRAPH`. 160 px = ~10 cells, so the player sees the sleeper before it aggros (fair). |
| `telegraph_s` | float (s) | **0.5** | 0.2 | 1.5 | Wind-up duration — the readable "lane is now committed" beat. Floor 0.2 borders unfair vs 200 px/s (§1.5); sweep down carefully. |
| `charge_speed` | float (px/s) | **520** | 200 | 900 | Locked-vector dash speed. Default ≈ 2.6× player, so lateral dodge is the only answer (never a footrace). Swept-test keeps even 900 tunnel-safe. |
| `charge_max_dist` | float (px) | **220** | 48 | 600 | How far the dash travels before auto-entering `RECOVER` (the overshoot *past* the player). ≈ 14 cells. Wall-hit ends it early. |
| `recover_s` | float (s) | **1.2** | 0.4 | 3.0 | **The core feel knob.** Stun window after the dash — the throw-punish opportunity. Too short = unkillable, too long = trivial. Sweep hardest. |
| `cooldown_s` | float (s) | **0.6** | 0.0 | 3.0 | Calm window after `RECOVER` before it can re-aggro/charge. Sets the rhythm's breathing room. |
| `lane_width` | float (px) | **28** | 16 | 64 | Lethal corridor half-width during `CHARGE` (swept test) AND the telegraphed visual lane width. Floored at ~`player_r + charger_r`. |
| `lock_at_telegraph_start` | bool | **true** | — | — | `true` = lane locked when the wind-up begins (fair: dodge the shown lane). `false` = lane re-aims at telegraph *end* (harder — tracks you longer). OQ-3. |
| `throwable_while_charging` | bool | **true** | — | — | `true` (simplest proof) = throw-killable in every state. `false` = invulnerable mid-dash, only killable in `TELEGRAPH`/`RECOVER` (the skill loop). OQ-4 — **fun call.** |
| `wall_crash_recover_mult` | float | **1.0** | 1.0 | 4.0 | `RECOVER` duration multiplier when the dash ends by hitting a wall vs. by max-distance. `>1` = "bait it into a wall for a bonus stun." OQ-7 — **fun call.** |

All-off: `charger.tres` is only loaded when `&"charger" ∈ oppositions_enabled` **and** a live deck lists it — the shipped default has neither, so nothing loads (byte-identical baseline). The **params↔schema bijection** (`params.keys() == param_schema` keys) is asserted by S4's per-def coverage net and by the Python `.tres` linter.

### 2.2 The `ChargeLane` component — the ONE new artefact (FSM pseudocode)

`ChargeLane` is a small `class_name`-typed component node (the exploration's Movement slot), mounted on the Actor host, reading its knobs from the def's `params` (snapshotted at `setup`, per the config-snapshot discipline) and driving the host `CharacterBody2D`'s `velocity` + `move_and_slide()`. It owns **only** movement + the three-beat FSM + the swept lethal-contact detection; it **delegates** the actual telegraph visuals to the reused **Telegraph** component and the actual kill (emit-always + `*_kills` gate + BUG6 latch) to the reused **Lethality** component. Illustrative, against the real as-built patterns (`pingpong_hazard.gd` for the snapshot/guard/`move_and_slide` shape; `hazard_entity.gd:319` for the Lethality delegation):

```gdscript
class_name ChargeLane
extends Node2D
## ChargeLane (S6a, M1.9) — the ONE new component: a telegraph → locked-vector lethal
## dash → recover FSM. Mounted on the Actor host (CharacterBody2D). Reuses Telegraph
## (tell states) + Lethality (kill) + ThrowInteraction (die) verbatim. RNG-FREE — any
## per-instance variation comes from spawn_ctx salts, never the global RNG.

enum State { DORMANT, TELEGRAPH, CHARGE, RECOVER }

var _host: CharacterBody2D                 # the Actor shell this component drives
var _player: Node2D                        # resolved at setup via the "player" group
var _telegraph: Telegraph                  # reused S2 component (sibling node)
var _lethality: Lethality                  # reused S2 component (sibling node)

# --- snapshotted knobs (from def.params at setup; NEVER re-read mid-frame) ---
var _aggro_range := 0.0
var _telegraph_s := 0.0
var _charge_speed := 0.0
var _charge_max_dist := 0.0
var _recover_s := 0.0
var _cooldown_s := 0.0
var _lane_width := 0.0
var _lock_at_start := true
var _throwable_while_charging := true
var _wall_crash_mult := 1.0

var _state: int = State.DORMANT
var _t := 0.0                              # time-in-state
var _lane_dir := Vector2.ZERO              # the LOCKED dash heading (source of truth)
var _dist_charged := 0.0
var _prev_pos := Vector2.ZERO              # for the swept lethal segment (tunnel-proof)

## Locked S2 handshake — the host forwards setup(cfg, player, spawn_ctx) to its components.
func setup(host: CharacterBody2D, player: Node2D, params: Dictionary, spawn_ctx: Dictionary) -> void:
    _host = host
    _player = player
    _aggro_range = float(params.get("aggro_range", 0.0))
    _telegraph_s = float(params.get("telegraph_s", 0.0))
    _charge_speed = maxf(float(params.get("charge_speed", 0.0)), 0.0)
    _charge_max_dist = float(params.get("charge_max_dist", 0.0))
    _recover_s = float(params.get("recover_s", 0.0))
    _cooldown_s = float(params.get("cooldown_s", 0.0))
    _lane_width = float(params.get("lane_width", 28.0))
    _lock_at_start = bool(params.get("lock_at_telegraph_start", true))
    _throwable_while_charging = bool(params.get("throwable_while_charging", true))
    _wall_crash_mult = maxf(float(params.get("wall_crash_recover_mult", 1.0)), 1.0)
    _enter(State.DORMANT)                   # tell = dormant (cool, inert)

func _physics_process(delta: float) -> void:
    if _player == null or _host == null or not is_instance_valid(_player):
        return
    _t += delta
    match _state:
        State.DORMANT:
            _host.velocity = Vector2.ZERO
            if _host.global_position.distance_to(_player.global_position) <= _aggro_range:
                _lock_lane()                        # lock at telegraph START (if configured)
                _enter(State.TELEGRAPH)
        State.TELEGRAPH:
            _host.velocity = Vector2.ZERO
            if not _lock_at_start:
                _lock_lane()                        # re-aim each frame → lock at telegraph END
            if _t >= _telegraph_s:
                if not _lock_at_start: _lock_lane() # final aim at the end
                _dist_charged = 0.0
                _prev_pos = _host.global_position
                _set_throwable(false if not _throwable_while_charging else true)
                _enter(State.CHARGE)
                EventBus.opposition_event.emit(&"charger", &"charge", _depth(), _run_t_ms())
        State.CHARGE:
            _prev_pos = _host.global_position
            _host.velocity = _lane_dir * _charge_speed
            _host.move_and_slide()
            _dist_charged += _host.global_position.distance_to(_prev_pos)
            _test_lethal_sweep(_prev_pos, _host.global_position)   # tunnel-proof kill test
            var hit_wall := _host.get_slide_collision_count() > 0
            if hit_wall or _dist_charged >= _charge_max_dist:
                _recover_len = _recover_s * (_wall_crash_mult if hit_wall else 1.0)
                _set_throwable(true)                # ALWAYS vulnerable in recovery
                _enter(State.RECOVER)
        State.RECOVER:
            _host.velocity = Vector2.ZERO
            if _t >= _recover_len:
                _enter(State.RECOVER_COOLDOWN)      # tell back to dormant; cooldown_s before re-arm
        # (RECOVER_COOLDOWN folds into DORMANT with a _t < _cooldown_s guard on re-aggro)

func _lock_lane() -> void:
    var to_p := _player.global_position - _host.global_position
    _lane_dir = to_p.normalized() if to_p.length() > 0.001 else Vector2.RIGHT

## Swept lethal test: perpendicular distance from the player to the segment travelled
## this frame ≤ lane_width/2 + player_r → contact. Delegates the ACTUAL kill to the
## reused Lethality component (emit-always + *_kills gate + BUG6 latch — L5).
func _test_lethal_sweep(a: Vector2, b: Vector2) -> void:
    var d := Geometry2D.get_closest_point_to_segment(_player.global_position, a, b)
    var in_contact := _player.global_position.distance_to(d) <= (_lane_width * 0.5 + PLAYER_R)
    _lethality.register_contact(in_contact)   # reused: emits opposition_killed_player,
                                              # gates fail_run(&"death") on kills, latches once

func _enter(next: int) -> void:
    _state = next; _t = 0.0
    _telegraph.set_state(next)                # reused Telegraph paints the tell for this state
    if next == State.TELEGRAPH:
        EventBus.opposition_event.emit(&"charger", &"telegraph", _depth(), _run_t_ms())
```

Notes for the programmer:
- **`register_contact(bool)` / `set_state(int)` are the reused component seams** S2 defines — `ChargeLane` calls them, it does not re-implement the kill or the tell. If S2's Lethality exposes a different method name, that name wins (flag at brief time); the *semantics* (emit-always, `*_kills`-gated `fail_run`, one BUG6 latch per contact rising edge) are locked and inherited unchanged.
- **`_throwable_while_charging = false`** is implemented by `_set_throwable(false)` doing `_host.remove_from_group(&"hazard")` on `CHARGE` entry and `add_to_group(&"hazard")` on `RECOVER` entry. This makes `thrown_item._on_body_entered`'s `is_in_group(&"hazard")` return `false` during the dash → the item **misses and re-drops** (not consumed) — **no edit to the shared `thrown_item.gd`**. The body stays on `collision_layer = hazard` so it still physically exists; only its *group vulnerability* toggles. (When `true`, it never leaves the group and is throw-killable in every state.)
- **RNG-free.** No global `RNG` call anywhere; the dormant idle-pulse phase (cosmetic) reads `spawn_ctx["phase_salt"]`. The lane direction is a pure function of live player position (run-state) — reactive, never fed to `fingerprint()`.

### 2.3 Spawn / placement rules (builder + service, not the entity)

The Charger is placed by the **default `EncounterBuilder`** (S3) from `band_two`'s deck, through the **`SpawnService`** (S0), exactly like every other opposition — S6a adds **no** placement code:

- **Eligibility:** in the deck iff `band.band_depth >= charger.min_band` (=1). `band_two` (`band_depth=2`) lists it; `band_greybox` does not → band-2-exclusive for M1.9 (breakdown OQ5, SG2 A/B).
- **Budget:** `credit_cost = 2` debited from the builder's `I`-scaled band budget (`BASE * (1 + 0.15 * band_depth)`) — a Charger is "expensive," so a band gets few.
- **Caps (service-enforced, atomic):** `per_room_cap = 1`, `per_band_cap = 4`. The minimum binds; the global registry ceiling is last-resort.
- **Placement bias (builder policy, recommended not required):** prefer **room** cells over tight corridors so the perpendicular-dodge game has space (a Charger in a 1-cell corridor just denies the lane on a rhythm — still valid per the v1 sketch, but the *dodge* read wants a room). Reuses the J3 `rooms_only`-style gate if present. **Not load-bearing for the proof** — if the builder places it anywhere, the proof still holds.
- **Determinism:** placement cell is the builder's stable RNG-free stride (`main_game.gd:473`); the Charger is spawned `DORMANT`. Same seed + config → same Charger cells. `spawn_ctx` carries `phase_salt` (cosmetic idle phase only).

### 2.4 Kill semantics (M1 lethality model — reused Lethality)

- **Dash contact = death.** During `CHARGE`, the swept segment test (§2.2 `_test_lethal_sweep`) detects contact; the reused **Lethality** component then does the L5 pattern verbatim: **emit-always** the death-channel signal, **gate** `GameState.fail_run(&"death")` behind `kills`, de-dupe with the BUG6 one-shot latch. **No new end-cause** — it's a `&"death"`, same as R1/pingpong. `fail_run`'s `_run_ended` guard owns run-end idempotency (a Charger + a same-frame extract/other-hazard cannot double-fire).
- **`kills = false`** (sweep variant): the dash still emits the contact/death-channel row (tagged) but never calls `fail_run` — the run continues, the Charger recovers as normal. Proves the per-def `*_kills` toggle.
- **Only `CHARGE` is lethal.** `DORMANT`/`TELEGRAPH`/`RECOVER` do **not** kill on touch — you can stand next to a stunned Charger to throw it. (Standing in front of a telegraphing Charger is safe *until* the dash — the fairness is that the lethal window is exactly the committed dash, which you were shown.)
- **Tunnel-proof.** The swept segment test (not a point-radius test) means even a maxed `charge_speed` cannot skip past the player between frames.

### 2.5 Throw interaction — punish the recovery (proposal)

The reused **ThrowInteraction = `die`** means a thrown item that hits the Charger `queue_free`s it (item consumed), via the existing `thrown_item._hit_hazard` path — **no shared-file edit**, and the telemetry `kind` self-resolves to **`&"charger"`** because `thrown_item._hazard_kind` falls back to `node.name.to_lower()` and the scene root node is named **`Charger`** (§2.7). Two configurations of *when* it's throwable:

- **`throwable_while_charging = true` (default — simplest proof).** Killable in every state. During the fast dash it's simply a hard target to hit; during `RECOVER` it's a stationary free target. The "recovery = punish window" is *emergent* (easy vs hard to hit), not enforced. This is the cleanest expression of "reuse ThrowInteraction verbatim."
- **`throwable_while_charging = false` (the skill loop — recommended for the `band_two` deck, Director call OQ-4).** Invulnerable mid-dash (group-toggle trick, §2.2), killable only in `TELEGRAPH`/`RECOVER`. This makes the intended loop explicit: *bait the charge → side-step → throw the stun.* A throw during the dash **misses and re-drops** (you keep the item — no punishment for a mistimed toss). This is the v1 sketch's *"during the long recovery window it is a free, stationary target … the cleanest bait → dodge → throw the recovery loop."*

**Recommendation:** ship the def default `true` (proof stays minimal), but have **S7 set `throwable_while_charging = false` for the Charger in `band_two`'s deck via a `param_override`** so playtesters feel the intended skill loop at the gate. *Flag OQ-4 for the Director* — it's the core fun call.

### 2.6 Telemetry

The Charger emits **only** the S0-pre-declared generic signals via its reused components — no charger-specific signal, no `event_bus.gd` edit:

| Signal | Payload | When | Emitter |
|---|---|---|---|
| `opposition_event(&"charger", &"spawned", depth, run_t_ms)` | id/event/depth/ms | on spawn | **SpawnService** (central `&"spawned"`) |
| `opposition_event(&"charger", &"telegraph", depth, run_t_ms)` | " | wind-up begins (lane committed) | `ChargeLane._enter(TELEGRAPH)` |
| `opposition_event(&"charger", &"charge", depth, run_t_ms)` | " | dash begins | `ChargeLane` on `CHARGE` entry |
| `opposition_killed_player(&"charger", depth, run_t_ms)` | id/depth/ms | on a lethal dash contact (emit-always, even if `kills=false`) | reused **Lethality** (BUG6-latched) |
| `throw_killed_hazard(item_id, &"charger", depth, run_t_ms)` | existing arity | on a throw-kill | existing `thrown_item` (kind via name-fallback) |
| `run_ended(reason=&"death", …)` | existing locked arity | on a fatal dash contact | `GameState.fail_run(&"death")` |

`depth` = `GameState.current_depth_index`; `run_t_ms` = the self-timed run clock (the R1/K5 pattern) or the exposed run clock if reachable read-only. `&"telegraph"`/`&"charge"` let SG2 measure telegraph→dodge rates and "did players read the tell." With the Charger off, **none** of these rows appear (no node exists).

### 2.7 Placeholder asset spec (character-animator — inline greybox; PixelLab Director-gated)

Per the M1 greybox norm, the tell is **stubbed inline** (a `Polygon2D` + `Tween` states) — no sprite sheets, no `AnimationTree`, no paid generation without an explicit Director OK. The Charger must read **apart from** R1 (grey-blue/red diamond), pingpong (amber box), spikes (steel-cyan star), and bomb (orange-pulse circle) — by **silhouette** and by **temporal signature** (the three-beat), reinforced by color.

- **Root node name `Charger`** (so throw-kill telemetry self-logs `kind = &"charger"`).
- **Silhouette: a directional WEDGE / arrowhead** `Polygon2D`, pointing along the host's facing (the locked `_lane_dir` during telegraph/charge). Directional shape is non-negotiable — the telegraph is only fair if the player can read *which way the lane points*. ~**32–36 px long, ~28 px wide** (body radius ≈ 16–18 px — visibly **heavier/bigger than the r=14 player** so it reads "heavy thing," and so `lane_width ≈ 28` is legible against it).
- **Per-state tell (colors are a set-level Director/character-animator call, OQ-8 — recommended starting values):**

  | State | Color (recommended) | Motion / juice |
  |---|---|---|
  | `DORMANT` | desaturated **rust-steel** `Color(0.45, 0.40, 0.35)` — inert, "asleep in the scrap," cool and low-contrast so it doesn't false-alarm | still; optional slow idle-pulse (phase from `spawn_ctx` salt) |
  | `TELEGRAPH` | **escalating amber→red** `Color(0.95,0.55,0.15)` ramping to `Color(0.95,0.2,0.2)` over `telegraph_s` | a **rear-back shake** + brightening flash; **draw the committed lane** as a translucent `lane_width`-wide rectangle from the wedge along `_lane_dir` (the "you will be hit here" contract) |
  | `CHARGE` | full **alarm red** `Color(0.95,0.15,0.15)` (shared meaning with R1: "lethal contact now") | a short motion-streak/trail; wedge points along travel |
  | `RECOVER` | desaturated **stunned grey-blue** `Color(0.5,0.55,0.6)` with a dizzy pulse | visibly slumped/flashing "hit me" — the punish tell; a **wall-crash** recovery (OQ-7) flashes harder/longer |

- **Frame budget if PixelLab is later approved (deferred, Director-gated):** dormant (1) · telegraph wind-up (2–3, brightening) · charge (1–2 streak) · recover/stunned (2, dizzy). 8 directions only if directional sprites are wanted — for greybox the single rotated wedge suffices.

The Telegraph component drives all of the above from `set_state(int)`; `ChargeLane` never touches color/shape directly.

---

## 3. Definition of done (concrete — the acceptance bar)

Restated from the breakdown's S6a DoD, with the test names S6a must add (`tests/test_charger.gd` + `.tscn`, run **as a scene** per the headless-test convention):

1. **All-off fp unmoved.** With the shipped default (`&"charger" ∉ oppositions_enabled`, not in `band_greybox`'s deck), **no `charger.tres` loads, no node spawns**, and the all-off fingerprint **`e943ac9c8bc1`** is byte-identical (assert in `test_charger` + the existing all-off fp guard).
2. **`params`↔`param_schema` bijection.** `charger.tres` passes the per-def coverage assertion (S4) and the Python `.tres` linter — every `params` key has exactly one `param_schema` entry and vice-versa, all within declared min/max.
3. **Deterministic placement.** Same seed + config (Charger enabled in a test deck) → byte-identical Charger spawn cells across two runs (extend the bandgen/spawn determinism matrix).
4. **`test_charger` (headless scene) asserts:**
   - **(a) FSM timing:** a Charger with a player placed at `aggro_range` transitions `DORMANT→TELEGRAPH` on aggro, holds `TELEGRAPH` for ~`telegraph_s`, enters `CHARGE`, and reaches `RECOVER` after travelling `charge_max_dist` (or on a wall hit); `RECOVER` lasts ~`recover_s`.
   - **(b) Lane lock:** with `lock_at_telegraph_start = true`, a player who moves perpendicular *after* the telegraph starts is **not** on the locked lane and is **not** hit (the dodge works); a player who stays on the lane **is** hit.
   - **(c) Dash kill gated by `kills`:** with `kills = true`, a player left on the lane ends the run via `fail_run(&"death")` (`GameState.run_active` flips false, cause `&"death"`) and `opposition_killed_player(&"charger", …)` fires **exactly once** (BUG6 latch); with `kills = false`, the same contact emits the row **but the run stays active**.
   - **(d) Wall stop:** a Charger dashed into a `world`-layer wall enters `RECOVER` early (does not pass through), and — with `wall_crash_recover_mult > 1` — its recovery is correspondingly longer.
   - **(e) Non-lethal outside CHARGE:** touching a `DORMANT`/`TELEGRAPH`/`RECOVER` Charger does **not** end the run.
   - **(f) Throw:** with `throwable_while_charging = false`, a thrown item during `CHARGE` **misses/re-drops** (Charger survives, still in no `hazard` group), while a thrown item during `RECOVER` **kills** it (`queue_free`) and logs `throw_killed_hazard(_, &"charger", …)`; with `throwable_while_charging = true`, a `CHARGE`-phase throw kills.
   - **(g) No global RNG:** the `charge_lane.gd` source contains no `RNG.` reference (determinism audit, mirroring the pingpong test's `(e)`).
5. **Menu section auto-appears.** With `&"charger"` loaded, S4's generated debug-menu builds a Charger collapsible section from `param_schema` headlessly (no hand-authored rows).
6. **Process:** a shared S6a worklog names the real commit SHA(s) for the programmer + character-animator contributions; `godot --headless --path Game --import` compiles the new scene/script/tres; the smoke test is green; the worklog's **Design deviations** section records any departure (or "none") for the Wave-4 close-out sweep.

---

## Open Questions

> Each is stated with trade-offs for Phase-3 fresh-eyes resolution. Genuine **fun/tone calls are flagged `**NEEDS DIRECTOR REVIEW**`** with a recommendation — the resolver does not self-decide those.

### OQ-1 — Is "def + one component" *actually* enough, or does the swept lethal test / group-toggle count as bespoke code?
The proof claims one new component. `ChargeLane` also carries a swept-segment lethal *detector* (§2.4) and the group-toggle vulnerability trick (§2.5) — are these "still just the movement component," or hidden extra surface? **Recommendation:** they live **inside `ChargeLane`** and reuse the S2 Lethality/ThrowInteraction *seams* (`register_contact`, group membership) without new shared code, so they count as component-internal — the proof holds. If S2's Lethality can't accept a swept contact (only a point distance), that's a **one-line generalization of the reused component**, not a new component — acceptable, but note it in the worklog as the true cost of the proof. *Technical — resolver decides; the SG3 watch-item is "how much bespoke code did S6a really need."*

### OQ-2 — Trigger: proximity aggro (in-component) vs. a `SightlineTrigger` ray (a second new component)?
§1.3 chose proximity to honor "ONE new thing." The v1 sketch's straight sightline-ray ("charge when the player crosses a watched lane") is a **more distinctive** read (standing still off the lane is safe; crossing it triggers) but needs a **second** new component (`SightlineTrigger`) the four shipped hazards never required. **Recommendation:** **proximity aggro for S6a** (keeps the proof honest at exactly one component). Flag the sightline-ray as a **cheap richer follow-up** (a `band_two`-iteration hazard variant) that would cost a second component — worth it only if proximity aggro reads as "generic pursuer" rather than "Charger" at SG2. *Design — resolver recommends; SG2 evidence decides whether the ray is worth a second component.*

### OQ-3 — Lane lock at telegraph START vs. END (`lock_at_telegraph_start`)?
Lock-at-start (default) is the **fair** design: the telegraph *shows* the committed lane and a perpendicular step beats it — the genre convention. Lock-at-end tracks the player through the whole wind-up (the lane re-aims until the dash), which is **harder and more aggressive** but can feel "unfair" (you dodged and it still hit you). **Recommendation:** default **start** (fair, learnable); expose `false` as a per-band difficulty lever for deeper bands later. Mostly a tuning knob, but the *feel* difference is real → *mild fun call, resolver may set the default and let the Director sweep.*

### OQ-4 — `**NEEDS DIRECTOR REVIEW**` — Is the Charger invulnerable while dashing (`throwable_while_charging`)?
The core fun question. `true` (def default) = simplest proof, killable always, recovery-as-punish is emergent. `false` = the *intended* skill loop is enforced (bait → dodge → throw the stun; a mistimed throw during the dash misses and re-drops, costing nothing). §2.5 recommends **shipping the def `true`** (minimal proof) but **enabling `false` in `band_two`'s deck** so testers feel the loop. This changes the whole skill expression of the hazard — **Director decides** whether `band_two`'s Charger is dash-invulnerable. *Recommendation: `false` in the deck; ratify at Phase 3 / the gate.*

### OQ-5 — `per_room_cap = 1` vs. allowing multiple Chargers per room?
One Charger per room reads cleanly (its lane is the room's puzzle); two crossing lanes could be either "great chaos" or "unreadable." **Recommendation:** **`per_room_cap = 1`** for the first gate (legibility first); the Director can raise it in a sweep if one feels too sparse. *Tuning — resolver sets 1, Director may sweep.*

### OQ-6 — Band gating: does the Charger enter band 1 in M1.9, or stay `band_two`-exclusive?
The breakdown (OQ5) recommends **band-2-exclusive** for a clean A/B at SG2 (band 1 = the M1.4 fun stack unchanged; band 2 = the new content). §2.1 encodes this via **deck membership** (`min_band = 1` but only `band_two`'s deck lists it), so the Charger is trivially promotable to band 1 later by adding it to `band_greybox`'s deck — no def change. **Recommendation:** **band-2-exclusive for M1.9.** *Fun/scope — Director confirms at the gate (also the SG3 watch-item "should the new hazards enter band 1's preset").*

### OQ-7 — `**NEEDS DIRECTOR REVIEW**` (fun) — Can the player bait a Charger into a wall for a bonus stun (`wall_crash_recover_mult`)?
The v1 sketch's best synergy: *"a Charger aimed at a wall self-stuns — the player's job is to be the bait that lines it up."* `wall_crash_recover_mult > 1` rewards baiting it into geometry with a longer punish window (skill expression + emergent level-geometry play). Default `1.0` (no bonus) is the neutral proof. **Recommendation:** ship the knob, **default `1.0`**, and set it to **~2.0 in `band_two`'s deck** so testers discover the bait-into-wall counter — but this is a **fun call** (does the extra stun make it too easy? does it teach the wrong lesson?). *Director decides the deck value.*

### OQ-8 — `**NEEDS DIRECTOR REVIEW**` (tone) — Charger fiction/name + the shared tell palette.
§1.4 pitches three flavors (**The Wrecker** recommended); §2.7 recommends a rust-steel→amber→red→stunned-grey tell on a directional wedge. Both the **name/fiction** (a tone call, `band_two` Temporal-scrap fiction) and the **exact tell palette** (a legibility call that must be chosen as a **set** with R1 + the four shipped hazards + S6b's Splitter, exactly as the K5 trio was ratified together) are **Director + character-animator** calls, not resolver calls. **Recommendation:** Wrecker + the §2.7 palette as the starting set; character-animator finalizes the S6a/S6b tell colors against the existing R1/pingpong/spike/bomb palette; Director ratifies at the gate. The mechanical `id` stays `&"charger"` regardless.

### OQ-9 — Does an overshooting Charger damage *other* hazards it ploughs through?
The v1 sketch flags this as "fun emergent synergy but a scope-creep risk." Today all hazards mask `world` only (never `hazard`), so they pass through each other — a Charger already ignores other hazards for free. Making it *destroy* them on dash-contact is new inter-hazard surface. **Recommendation:** **No** — the Charger does not damage other hazards in M1.9 (keeps the proof minimal, avoids a new hazard-vs-hazard interaction path). Revisit as a `ThrowInteraction`/collision follow-up only if playtest asks for it. *Scope call — resolver recommends "no"; Director may override as a stretch.*

---

*Phase 3 (fresh eyes, NOT this author) resolves the Open Questions into a `Resolved Decisions` section, flagging OQ-4 / OQ-7 / OQ-8 (and confirming OQ-6) for the Director per the orchestrator loop. Design-only — no code, no `.tres`. The programmer + character-animator build against this; deviations from the committed design go to `DESIGN_DEVIATIONS.md` for the Wave-4 close-out sweep.*

---

## Resolved Decisions (Phase 3)

> Fresh-eyes resolution by a **different** game-director-designer agent than the author. Every OQ resolved on technical/design merit (**RESOLVED**) except the genuine fun/tone/scope calls, which stay **NEEDS DIRECTOR REVIEW** with a one-line question + recommendation. **Orchestrator cross-contract adjudications folded in as fixed.** Claim corrections (verified against the real repo) precede the OQ verdicts because two of them change the spec.

### Verified against the build (Phase-3 audit — the tuning/mechanism claims hold)
- **Player top speed `200` px/s** — confirmed (`data/player/player_movement.tres:7`, `player_movement_stats.gd:11`). The whole readability budget (§1.5) anchors correctly; `charge_speed 520` ≈ 2.6× player is right, and a maxed `900` ⇒ 15 px/frame stays under the ~28 px corridor (swept test moots it regardless).
- **Cell size `16` px** — confirmed (`main_game.gd:42`). `aggro_range 160` ≈ 10 cells etc. all check out.
- **Player radius `14.0`** — confirmed (`player.tscn:10` `CircleShape2D`). The swept test's `PLAYER_R = 14` and the `lane_width/2 + PLAYER_R` corridor are correct.
- **Group-toggle dash-invulnerability trick — VERIFIED, no `thrown_item.gd` edit needed.** The kill test really keys off the group: `thrown_item.gd:79` is `if body != null and body.is_in_group(&"hazard"): _hit_hazard(body) else: _miss()`. Removing the host from the `&"hazard"` group during `CHARGE` (keeping `collision_layer = hazard(16)` so `body_entered` still fires against the item's mask 18) makes `is_in_group` return `false` → `_miss()` → the item re-drops via `junk_dropped` (kept, not consumed). Adjudication #4 satisfied: the trick is pure group membership, `thrown_item.gd` untouched. **Confirmed and unchanged.**
- **Swept lethal test determinism — VERIFIED.** `Geometry2D.get_closest_point_to_segment` is a pure function; `_lane_dir`/positions are player-driven **run-state** and never feed `fingerprint()`. `_prev_pos` (pre-move) → `global_position` (post-move) is captured correctly, so the sweep is genuinely tunnel-proof. Determinism preserved.

### Claim corrections (fold into §2.2 / §2.5 / §2.6 at build time)
- **CORRECTION 1 — the `&"charge"` telemetry token does not exist; S0 LOCKS the vocabulary.** S0 (`S0_spawn_service.md:408-412`) locks `opposition_event`'s `event` set to **`&"spawned" / &"awoke" / &"telegraph" / &"hit_player" / &"killed_by_throw" / &"state"`**, and S6a is forbidden from editing `event_bus.gd`. So §2.2 (lines 221, 298) emitting `opposition_event(&"charger", &"charge", …)` is **out of contract**. Fix: the wind-up beat is `&"telegraph"` (already correct); the dash-begin / recover transitions map to the locked **`&"state"`** token (exactly as the pursuer's patrol↔chase flip does — `S0:451`). SG2's "did they read the tell" read is served by `&"telegraph"` (fired) + `&"hit_player"` (contact) + its absence (dodge); a distinct dash marker is not required for M1.9. If SG2 later wants a first-class `&"charge"` token, that is a **one-word addition to S0's locked set** (an `event_bus.gd`/S0 edit, coordinated — never an S6a edit).
- **CORRECTION 2 — `opposition_killed_player` is GATED, not emit-always.** §2.6's table row says `opposition_killed_player(&"charger", …)` fires "emit-always, even if `kills=false`." Per S0 (`:414-419`, `:449`, `:458`) this channel is the **dedicated death channel**, emitted **only when the `*_kills`-gated `fail_run` actually fires**. The **emit-always** contact row is **`opposition_event(&"charger", &"hit_player", …)`**. Fix §2.6: emit-always lethal contact → `opposition_event(&"charger", &"hit_player", …)`; the gated actual kill (`kills=true`, run ended) → `opposition_killed_player(&"charger", …)` — **not** emitted when `kills=false`. This is exactly what the reused S2 Lethality component already does (`S0:449`), so the *component* is right; only the doc's table is wrong. DoD 4(c) is unaffected in substance: the row present in **both** `kills` cases is the `&"hit_player"` `opposition_event`; `opposition_killed_player` distinguishes the fatal case.
- **CORRECTION 3 — the throw-kill `kind` name-fallback is FRAGILE; rely on the def-id generic channel.** §2.5/§2.6 claim the kind "self-resolves to `&"charger"`" because `thrown_item._hazard_kind` (`:117`) returns `node.name.to_lower()`. Verified true for a **single** instance (root named `Charger` → `"charger"`), but Godot auto-suffixes duplicate sibling node names (`Charger`, `Charger2`, …) → `"charger2"` for a second instance under the same container, splitting the legacy series. This is a **pre-existing** limitation shared with spike/bomb (both already hit the name-fallback — only pursuer/pingpong get a typed check at `thrown_item.gd:113-116`), not a charger-specific bug, and `thrown_item.gd` is off-limits to S6a. **Reliable source:** the reused S2 **ThrowInteraction** emits `opposition_event(&"charger", &"killed_by_throw", …)` with the **snapshotted def id** (`S0:450`), which is node-name-independent. Recommendation: SG2 keys throw-kills off the **def-id generic channel**, treating the legacy `throw_killed_hazard` name-fallback as best-effort. No S6a code change; a spec-accuracy correction.
- **Minor pseudocode nits (non-blocking, for the programmer):** the `enum State` (§2.2) omits `RECOVER_COOLDOWN` referenced at line 236 — fold cooldown into `DORMANT` with a `_t < _cooldown_s` re-aggro guard (as the line-237 comment intends) or add the state; and `_recover_len` must be declared alongside the snapshot fields. Illustrative helpers `_depth()`/`_run_t_ms()` are the R1/K5 self-clock pattern.

### OQ verdicts

- **OQ-1 — RESOLVED: the proof holds — "def + ONE new component" — with one honest, recorded cost.** The swept detector and group-toggle live **inside `ChargeLane`** and reuse existing seams, so they are component-internal, not a second script. **But** the swept test cannot use any of S2's three `LethalContact` modes as-is (`radius`/`arm_segments`/`on_command` all compute their *own* contact — none accepts a caller-supplied boolean; `register_contact(bool)` as written in §2.2 does **not** exist in S2's design, `S2:231`). Resolution: `ChargeLane` computes the swept boolean and hands it to the reused `LethalContact` via a **new externally-driven contact seam** (`report_contact(bool)`-style, or a fourth `&"external"` mode) that runs Lethality's existing emit-always + `kills`-gate + BUG6-latch on the supplied edge. That is a **one-line generalization of a reused component**, not a new component — the proof survives. **Coordination requirement:** S6a must confirm at brief-time that S2's `LethalContact` exposes this seam; **if S2 didn't build it, S6a adds it to `lethal_contact.gd` (the reused component), and the worklog records this as the true measured cost of the proof — the SG3 watch-item "how much bespoke code did S6a actually need."** The group-toggle uses only stock `add_to_group`/`remove_from_group` — zero new surface.
- **OQ-2 — RESOLVED: proximity aggro for S6a; prefer reusing S2's `ProximityTrigger` over an in-`ChargeLane` distance check.** Sightline-ray stays a deferred second-component follow-up (SG2 evidence decides if it earns the slot). **Refinement that strengthens the proof:** S2 already extracted a `ProximityTrigger` from the bomb (`S2:103`); the wake condition (rising edge into `aggro_range`) is the same shape, so `ChargeLane` should **subscribe to a reused `ProximityTrigger` for the `DORMANT→TELEGRAPH` wake** rather than re-implementing a distance check — keeping `ChargeLane` purely the three-beat movement FSM (a cleaner "def + one movement component" story). One caveat: the bomb's trigger is one-shot (bomb is terminal); the charger cycles, so the trigger must **re-arm** on return to `DORMANT`. If re-arming `ProximityTrigger` is clean, reuse it; if it forces awkward state back-channel, the trivial in-`ChargeLane` distance check (§2.2) is the acceptable fallback. Either way the aggro adds no new component.
- **OQ-3 — RESOLVED: default `lock_at_telegraph_start = true` (fair/learnable), expose `false` as a per-band lever.** Lock-at-start is the genre contract (the shown lane is beatable by a perpendicular step); lock-at-end is a deeper-band difficulty knob, not the M1.9 default. Resolver sets the default; the Director may sweep the deck value but it is not a blocking call.
- **OQ-4 — NEEDS DIRECTOR REVIEW (fun).** *Director question:* **In `band_two`'s deck, is the Charger invulnerable while dashing (`throwable_while_charging = false`), enforcing the bait→dodge→throw-the-stun skill loop — or throw-killable in every state (`true`, emergent punish)?** *Recommendation:* ship the **def default `true`** (keeps the Phase-E proof minimal) and set **`false` via S7's `param_override` in `band_two`'s deck** so testers feel the intended loop at the gate. Group-toggle mechanism verified free of `thrown_item.gd` edits (above).
- **OQ-5 — RESOLVED: `per_room_cap = 1` for the first gate.** Legibility first (one lane = the room's puzzle; crossing lanes risk unreadable chaos). The Director may raise it in a sweep if a room reads too sparse — a tuning knob, not a design lock.
- **OQ-6 — NEEDS DIRECTOR REVIEW (scope/fun) — mechanism FIXED by adjudication.** *Director question:* **Confirm the Charger stays `band_two`-exclusive for M1.9 (clean A/B at SG2), or promote it into band 1's default preset?** *Recommendation:* **band-2-exclusive.** **Mechanism corrected per fixed adjudication #1: `min_band = 2`** (not the doc's `1`) — a **hard gate**, doubly reinforced by `band_greybox`'s deck omitting it. This corrects §2.1's `min_band = 1` + comment. Trade-off vs. the doc's "trivially promotable by deck edit only" story: with `min_band = 2`, a future band-1 promotion also needs `min_band` lowered to `1` (a one-field def edit) — marginally less trivial, but a cleaner eligibility gate. Ships off-default (`&"charger" ∉ oppositions_enabled`), `.tres` at `Game/data/oppositions/charger.tres`.
- **OQ-7 — NEEDS DIRECTOR REVIEW (fun).** *Director question:* **Should baiting a Charger into a wall grant a bonus stun (`wall_crash_recover_mult > 1`), rewarding geometry play — or keep recovery uniform (`1.0`)?** *Recommendation:* ship the knob, **def default `1.0`** (neutral proof), set **~`2.0` in `band_two`'s deck** so testers discover the bait-into-wall counter. Wall detection via `get_slide_collision_count() > 0` after the CHARGE `move_and_slide()` is sound; watch that a tangential graze doesn't false-trigger a "crash" (tune at SG2 if it does).
- **OQ-8 — NEEDS DIRECTOR REVIEW (tone/legibility).** *Director question:* **Adopt "The Wrecker" (industrial press-head that rams and re-pressurizes) as the Charger's fiction, and the rust-steel→amber→red→stunned-grey directional-wedge tell as the starting palette — with character-animator finalizing the S6a/S6b tell colors as a set against the existing R1/pingpong/spike/bomb palette?** *Recommendation:* yes — Wrecker is the most legible for `band_two`'s Temporal-industrial fiction; palette ratified together (the K5-trio precedent). The mechanical `id` stays `&"charger"` regardless of display name, so telemetry/tests are name-stable.
- **OQ-9 — RESOLVED: NO — an overshooting Charger does not damage other hazards in M1.9.** All hazards mask `world` only and already pass through each other for free; making the dash *destroy* other hazards is net-new inter-hazard interaction surface that the Phase-E "minimal proof" explicitly avoids. Revisit only if playtest asks for it (a `ThrowInteraction`/collision follow-up). Resolver sets "no"; the Director may override as an explicit post-gate stretch.

### Locked cross-contract alignments (adjudications folded in)
- **Def id `&"charger"`; `.tres` at `Game/data/oppositions/charger.tres`; ships off-default; in `band_two`'s deck at `min_band = 2`** (adjudication #1 — corrects §2.1's `min_band`).
- **`ChargeLane` rides S2's base component contract** (`S2_components_param_schema.md §3.1`): a host-mounted child `Node` with **no `_physics_process` of its own** — the Actor host ticks it in fixed order (`_move.tick(delta)` shape). The §2.2 pseudocode's `_physics_process(delta)` on `ChargeLane` must be **re-cast as `tick(delta)` called by the host**, and `setup(...)` re-cast as the base contract's `bind(host, player, params, ctx)` snapshot (`_configure`). Semantics unchanged; this is the S2 alignment (adjudication #2).
- **Telemetry vocabulary = S0's locked generic set only** (adjudication #3): `opposition_event(&"charger", {&"spawned"(service) | &"telegraph" | &"state" | &"hit_player" | &"killed_by_throw"}, …)` + the gated `opposition_killed_player(&"charger", …)`. Emission lives in the reused components (**S2 emits, S4 subscribes**), not in bespoke `ChargeLane` calls to `EventBus` — the §2.2 direct `EventBus.opposition_event.emit` lines should route through the reused Telegraph/Lethality/host emit sites. See Corrections 1 & 2.
- **`thrown_item.gd` untouched by S6a** (adjudication #4): verified — the group-toggle needs no edit; the def-id-stable throw-kill row comes from the reused S2 ThrowInteraction (Correction 3).

---

## Wave-4 close-out amendments (as-built, Director-dispositioned 2026-07-03)

- **Host shell** (Director: **Addressed → post-gate task FU5**) — `charger_hazard.gd` ships as the
  honest per-entity Actor-host cost (ChargeLane = the only new behavior script; zero shared edits).
  FU5 (backlog, post-SG3) funds a shared parameterized host so future defs need zero host files.
- **`kills` lives in params + schema** (Director: **Reviewed**) — STANDING CONVENTION for
  deck-driven defs: the L5 gate is a params row (sweepable, menu-surfaced), typed field kept in
  agreement.
- **Spawn card `base_count=1`/`count_per_depth=0.0` on the def** (Director: **Reviewed**) — the
  deck-lane authoring shape; the authored value IS the live default (def loads only when
  deck/lever-listed; all-off unaffected). §2.1 sketch superseded.
- **Gloss CSV rows** (Director: **Addressed → done at close-out**) — the 13 `CFG_FIELD_CHARGER_*`
  rows landed in `config_strings.csv` at Wave-4 integration.
- **D-RAT-2 deck override** (Director: **Addressed → S9**) — delivered via the `DeckEntry` wrapper
  (M1.9 Wave 5): band_two's deck wraps charger with `throwable_while_charging=false`,
  `wall_crash_recover_mult=2.0`; def defaults stay D-RAT-2-letter (`true`/`1.0`), pinned by
  `test_charger`.
