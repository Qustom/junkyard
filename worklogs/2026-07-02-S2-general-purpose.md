# Worklog — S2 Opposition component extraction + `param_schema`

- **Date:** 2026-07-02
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.9 (Wave 2)
- **Branch:** general-purpose/S2
- **Commit:** 117d372 (harness + pre-refactor goldens) → e851a8c (the refactor) →
  worklog/deviations commit (this file's SHA, recorded in `git log`)

## What changed
Opposition migration Phase B (zero observable behavior change, golden-gated): the 4
shipped hazard entities' internals were extracted onto the shared 9-component set
(`Game/scenes/hazards/components/` — `OppositionComponent` base + ChaseMove, PatrolMove,
StraightBounceMove, SpinMove, DepthLingerTrigger, ProximityTrigger, TelegraphFSM,
LethalContact, ThrowInteraction), each a verbatim transplant of already-test-covered
code. Hosts keep the per-frame SKELETON line-for-line per the binding Q1 rule (guards,
early returns, mode switches, and every accumulator — `_time_in_band`, `_catch_cooldown`,
`_stun`, `_pulse_t` — stay host-side; the stun/cooldown decrement order is pinned by the
golden's second-catch specimen probe at frame 215). `class_name`s, the LOCKED
`setup(cfg, player, spawn_ctx)` handshake, all 4 `.tscn`s, and every signal payload are
untouched. Entities now dual-emit the S0-pre-declared generic signals
(`opposition_event` twins per the S0 §5 vocabulary + `opposition_killed_player` at the
`*_kills` gates only when `fail_run` actually fires) beside the legacy rows — zero new
telemetry rows until S4 wires subscribers. The `thrown_item.gd` Q5 seam landed
(`resolve_throw_death(killer_ctx) -> bool`, mode-die returns false ⇒ byte-identical
`queue_free`, + the `get_def_id()` kind rider + the `killed_by_throw` twin). All four
`OppositionDef.tres` gained complete `params` + `param_schema` (locked entry shape,
`CFG_FIELD_*` gloss reuse, one `trap_if_neutral` per def on the ratified magnitude)
mirroring `RunConfig.new()` code defaults — legacy knobs remain the sole behavior source
(Q2 option (a)); pursuer `kills` typed field corrected to `false` (mirrors
`r1_catch_kills`).

**Parity proof:** goldens were captured from the UNMODIFIED entities in the branch's
first commit (117d372) — 5 frame-traces (two pursuer modes, pingpong, bomb, spike;
position/velocity/state/rotation/emit-log per frame, full float precision) — and the
refactored entities reproduce all 5 byte-identically.

## Files touched
- `Game/scenes/hazards/components/opposition_component.gd` — **new** base: bind() with
  resolved primitives only (snapshot discipline structural), host-ticked `tick()`, Q4
  order-stable `acquire()` (adopts .tscn-declared children, instances defaults).
- `Game/scenes/hazards/components/{chase_move,patrol_move,straight_bounce_move,spin_move,depth_linger_trigger,proximity_trigger,telegraph_fsm,lethal_contact,throw_interaction}.gd`
  — **new**: the nine blocks (§2.2), consts moved with their blocks (STALL_FRACTION →
  ChaseMove, PATROL_* → PatrolMove; CONTACT_RADIUS/ARM_COUNT/NONFATAL_* stay on their
  hosts, which resolve them into `p`). `LethalContact` carries the three latch flavors,
  emit-always + dual-emit, the L5 gate, the nonfatal handler seam, and the **S6a
  external-contact seam**: `apply_contact(hit: bool, can_catch: bool)` with
  `lethal_mode = &"external"` — ChargeLane's swept test supplies the boolean, the same
  latch/emit/gate machinery resolves it (breakdown amendment 4, recorded as part of the
  proof cost). `ThrowInteraction.death_handler` is S6b's Splitter hook.
- `Game/scenes/hazards/{hazard_entity,pingpong_hazard,bomb_hazard,spike_hazard}.gd` —
  REWRITE to host + composition; skeleton/guards/timers verbatim; `run_clock_ms()` +
  `get_def_id()` + `resolve_throw_death()` host surface added; SpikeHazard keeps the
  `_angle` (read-through property) + `_is_player_on_any_arm()` test surface.
- `Game/scenes/hazards/*.tscn` — **UNTOUCHED** (Q4).
- `Game/entities/thrown_item/thrown_item.gd` — the Q5 locked seam + kind rider +
  `killed_by_throw` dual-emit twin. Sole S2 edit outside `scenes/hazards/` (S2 is
  `thrown_item.gd`'s sole M1.9 writer).
- `Game/data/oppositions/{pursuer,pingpong,bomb,spike}.tres` — params (8/3/5/4) +
  param_schema completed; pursuer `kills=false`. R1's J2/J3 spawn/density policy family
  deliberately unmapped (stays RunConfig-only through M1.9, per Q3 — flagging here as
  the spec requires).
- `Game/tests/test_opposition_components.{gd,tscn}` + `Game/tests/goldens/trace_*.txt`
  — **new** golden harness (first commit) + dual-emit twin assertions (refactor commit).
- `Game/tests/test_opposition_def_schema.{gd,tscn}` — **new**: §3.4 bijection +
  type/range/entry-shape (unknown-field fail-loud) + mirror-parity vs `RunConfig.new()`
  (params AND the typed `kills` field; lives for all of M1.9 per Q2-corrected) +
  trap-flag placement + host contract (class/group/seam/id continuity).
- `Game/tests/test_pingpong_hazard.gd` — ONLY the no-RNG source scan swept over the
  component scripts (the sanctioned S2 test addition; asserts ≥9 component files).
- `*.uid` files for the new scripts (godot-generated).

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] All-off fingerprint **byte-identical**: `test_bandgen_determinism` green
  (fp `e943ac9c8bc1`) + `test_corridor_lever` green (pins `BASELINE_FP`)
- [x] **Golden frame-trace parity green**: all 5 traces byte-identical to the
  pre-refactor goldens (positions, velocities, FSM states, rotations, emit logs — incl.
  the kill/catch frames and the stun/cooldown interleave probe)
- [x] Dual-emit contract green (harness): every legacy emit paired 1:1 in-order with an
  `opposition_event` twin (S0 §5 vocabulary, def ids, same depth + host clock);
  `opposition_killed_player` silent in the kills-off traces
- [x] Full hazard suite green UNEDITED (beyond the sanctioned RNG-sweep addition):
  `test_pursuing_hazard`, `test_pingpong_hazard`, `test_bomb_hazard`,
  `test_spike_hazard`, `test_new_hazard_spawn`, `test_per_room_density`,
  `test_hazard_spread`, `test_throw_mechanic` — run sequentially
- [x] `test_rg1_m12/m13/m14/m15_verify` + `test_rg1_loop_verify` green (m14/m15 re-prove
  the default play preset spawns the same cohort + row kinds — DoD item 7's spot-check)
- [x] `test_spawn_service` green (the S0 seam drives the refactored entities unchanged)
- [x] `test_opposition_def_schema` green (bijection/shape/mirror-parity/host contract)
- [x] `test_config_menu` green (89/89 knob coverage — no knob surface change)
- [x] `git diff` guardrail: **no** `main_game.gd` / `event_bus.gd` / `run_config.gd` /
  `config_menu.gd` / `game_state.gd` / `systems/bandgen/` / `data/bands/` / `.tscn` change
- [x] Definition of done met: *"All-off fp e943ac9c8bc1 byte-identical; full hazard suite
  green; golden frame-trace parity harness green (goldens captured pre-refactor);
  params↔schema bijection check green for all defs; import + smoke green."* — all above.

## Design deviations
Four notes (also appended to `design/DESIGN_DEVIATIONS.md`):

1. **TelegraphFSM is presentation-only; FSM timing accumulators stay host-side.** §2.2's
   component table assigns the bomb's "PULSING→EXPLODED timing" to TelegraphFSM, but the
   binding Q1 rule ("every accumulator increment/decrement site is transplanted
   line-for-line into the host") wins where they conflict — `_pulse_t` and the State
   match stay in `bomb_hazard.gd`; TelegraphFSM owns the tells (color flips, throb,
   flashes; params-read: `pulse_seconds` for the throb period only). S6a's Charger
   composes its telegraph→dash→recover timing host-side/ChargeLane and drives these
   tells. Recommendation: Reviewed (Q1 is explicitly the tiebreak; parity was the point).
2. **Components read `GameState.current_depth_index` live at the legacy sites.** Q1's
   "bind() receives resolved primitives (never a GameState read)" is honored for CONFIG;
   the live within-band depth is run-state the legacy entities deliberately read live
   per-frame (BUG2), so the transplanted blocks keep those reads (LethalContact's `_fire`
   / radius tick; hosts thread depth into `tick_chase`/`test_radius_catch` where the
   original read once per frame). Documented in the base-class contract. Recommendation:
   Reviewed (transplant-verbatim requires it; config discipline intact).
3. **One duck-typed cross-host seam: `run_clock_ms()`.** Hosts share no script base
   (CharacterBody2D vs Node2D roots), so `OppositionComponent._host_run_t_ms()` calls
   `host.call(&"run_clock_ms")` dynamically — the single untyped call in the component
   layer, mirroring the deliberately duck-typed `resolve_throw_death`/`get_def_id` seams
   (Q5). Recommendation: Reviewed.
4. **Harness scope grew slightly beyond the letter of the workflow note:** (a) a second
   pursuer trace (room-bound patrol mode) beyond the "one trace per entity" list, for
   PatrolMove/state-emit coverage; (b) the dual-emit twin assertions were ADDED to the
   harness in the refactor commit (they cannot exist in the pre-refactor commit, which
   must be green with no twins). Both are strengthenings, not edits-to-pass; goldens
   remain legacy-only so the pre-refactor baseline stays the oracle. Recommendation:
   Reviewed.

Spec-flagged non-deviations, recorded as required: R1's J2/J3 spawn/density policy
family stays RunConfig-only and unmapped in `pursuer.tres` (Q3, deliberate); the
`LethalContact` external-contact seam + `thrown_item.gd` edit are part of S2's true
proof cost (breakdown amendment 4); nothing reads `def.params` at runtime in S2 (the
mirror-parity assertion pins the surfaces and lives for all of M1.9 per corrected Q2).

## Handoffs / follow-ups
- **S6a (Charger):** `LethalContact` external seam = set `lethal_mode = &"external"`
  and call `apply_contact(hit, can_catch)` per frame from the swept test;
  `ProximityTrigger`/`DepthLingerTrigger` reusable as arm gates; `TelegraphFSM` renders
  the tells (host owns the phase timing per Q1). `get_def_id()` gives stable telemetry
  kinds through the throw path — implement it on the Charger host.
- **S6b (Splitter):** zero `thrown_item.gd` edits needed — implement
  `resolve_throw_death` on the host (or assign `ThrowInteraction.death_handler`) to
  split + free + return true. `killer_ctx` = {item_id, kind, depth, run_t_ms}.
- **S3:** deck-lane counts read `def.params["base_count"]` / `["count_per_depth"]`
  (breakdown amendment 10 — they are params, not typed fields, so S4's menu reflects
  them).
- **S4:** `param_schema` is complete for all 4 defs (locked entry shape; `gloss` carries
  `CFG_FIELD_*` CSV keys; `trap_if_neutral` on pursuer.catch_radius / pingpong.speed /
  bomb.proximity_radius / spike.arm_length; `step` omitted ⇒ S4's per-type default).
- **SG1:** telemetry-continuity check should confirm zero row-count drift for Waves 2–3
  (dual-emit has no subscriber until S4 — verified zero new rows here).
- **Post-gate (SG3 watch):** the golden harness may be demoted/dropped if it proves
  brittle (one-line deletion); the mirror-parity assertion retires only when defs become
  the behavior source (legacy retirement).
