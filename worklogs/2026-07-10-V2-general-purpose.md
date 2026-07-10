# Worklog — V2 Retire the dual-emit legacy opposition signals

- **Date:** 2026-07-10
- **Subagent:** general-purpose
- **Milestone:** M1.12 (Wave 2)
- **Branch:** feat/V2-retire-dual-emit
- **Commit:** 54131a6ae1268181b988cdcc56c62ab2b502e4a1 (worklog-SHA finalized by a subsequent
  `--amend`; the tree/diff is identical — this is the V2 commit on `feat/V2-retire-dual-emit`)

## What changed
Retired the six legacy per-type opposition signals from `event_bus.gd`
(`hazard_awoke`, `hazard_caught`, `new_hazard_killed`, `bomb_pulse_started`,
`throw_killed_hazard`, `hazard_pursuer_state`) — **EventBus 60 → 54 signals** — plus every
production emit, every consumer read, and the now-dead `_emit_family` plumbing threaded
through 10 hazard-host scenes. The M1.9 generic `opposition_event` / `opposition_killed_player`
family (unchanged) is now the SOLE opposition telemetry family; it already fired at every
retired site (the dual-emit was the proof), so this is a pure deletion of the legacy half.
Telemetry's 3 legacy handlers + their 3 schema row-type constants (`HAZARD_AWOKE` /
`HAZARD_CAUGHT` / `NEW_HAZARD_KILLED` + their `ALL_TYPES` entries) were removed; the generic
`_on_opposition_event` / `_on_opposition_killed_player` handlers already log the same moments.
No `SCHEMA_VERSION` bump (envelope untouched; v stays 1). No save-schema change (meta stays v4).

## Files touched
### Production (17)
- `systems/event_bus.gd` — deleted the 6 legacy signal declarations + their doc blocks;
  rewrote the M1.4/M1.5/M1.9 comment blocks to name the generic family as sole. 60 → 54.
- `scenes/hazards/components/lethal_contact.gd` — deleted `_emit_family` var/read/doc and the
  `if _emit_family == &"hazard_caught"` branch in `_fire()`; the unconditional
  `opposition_event(&"hit_player")` emit (was already present) is now the only contact emit.
- `scenes/hazards/hazard_entity.gd` — dropped the `hazard_awoke` + `hazard_pursuer_state` legacy
  emits (kept the `&"awoke"` / `&"state"` generic twins) + the `emit_family` param.
- `scenes/hazards/bomb_hazard.gd` — dropped the orphan `bomb_pulse_started` emit (kept
  `&"telegraph"`) + the `emit_family` param.
- `entities/thrown_item/thrown_item.gd` — dropped the orphan `throw_killed_hazard` emit (kept
  `&"killed_by_throw"`). `item_id` still rides the local `killer_ctx` (unchanged behavior).
- `scenes/hazards/{ambusher,charger,burrower,lobber,sentry,spike,pingpong,splitter}_hazard.gd`
  (splitter is `splitter.gd`) — removed the dead `emit_family` param entry from each host.
- `systems/telemetry/telemetry.gd` — removed 3 legacy connects + 3 handlers
  (`_on_hazard_awoke` / `_on_hazard_caught` / `_on_new_hazard_killed`); freshened comments.
- `systems/telemetry/telemetry_schema.gd` — removed `HAZARD_AWOKE` / `HAZARD_CAUGHT` /
  `NEW_HAZARD_KILLED` constants + their 3 `ALL_TYPES` entries. No `SCHEMA_VERSION` bump.
- `scenes/hazards/components/depth_linger_trigger.gd`, `data/oppositions/opposition_def.gd` —
  doc-comment-only trims (no signal reference).

### Tests re-pointed (17) + goldens (5)
- Class A (row-assertion): `test_telemetry_jsonl.gd` (NEW_HAZARD_KILLED → OPPOSITION_EVENT
  `event=&"hit_player"`), `test_telemetry_config_marking.gd` (3 sites: field map `:33-34`,
  drives `:87-88`, Criterion-4 list `:170`; "7 opposition types" → "5"),
  `test_def_menu_coverage.gd` (dropped legacy drive + the `NEW_HAZARD_KILLED` list entry `:209`),
  `test_rg1_m12_verify.gd` / `test_rg1_m13_verify.gd` / `test_rg1_loop_verify.gd`
  (`hazard_types` → generic `opposition_event`; m12 keeps awoke/hit_player granularity via an
  added `opposition_event:<event>` collector token).
- Class B (per-hazard component): `test_pursuing_hazard.gd`, `test_opposition_components.gd`
  (golden harness reframed to the generic vocabulary — twin check retired), `test_bomb_hazard.gd`,
  `test_spike_hazard.gd`, `test_pingpong_hazard.gd`,
  `test_{sentry,ambusher,charger,burrower,lobber}.gd` (derive `_killed_kinds`/`_throw_kills`
  from the generic family), `test_throw_mechanic.gd` (item_id sub-assertion dropped — OQ-2).
- `tests/goldens/trace_{pursuer_chase,pursuer_room,pingpong,bomb,spike}.txt` — regenerated:
  ONLY the emit-log column changed (legacy string → `opposition_event(...)`); the
  position/velocity/state/rotation columns are byte-identical (12 lines changed across 5 files).

Every re-point carries an inline equivalence comment (legacy `<signal>` retired → generic
`opposition_event(event=<x>)` fires at the identical site/moment; count/payload preserved).

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] opposition/hazard tests pass: `test_opposition_components` (goldens regenerated + compared
  green), `test_pursuing_hazard`, `test_bomb_hazard`, `test_spike_hazard`, `test_pingpong_hazard`,
  `test_sentry`, `test_ambusher`, `test_charger`, `test_burrower`, `test_lobber`,
  `test_throw_mechanic` — all exit 0
- [x] telemetry tests pass: `test_telemetry_jsonl`, `test_telemetry_config_marking`,
  `test_def_menu_coverage` — all exit 0
- [x] RG verify tests pass: `test_rg1_m12_verify`, `test_rg1_m13_verify`, `test_rg1_loop_verify`
  — all exit 0 (m13 threw one flaky miss on a timing-sensitive r2/r3/r4/timeout run — NOT an
  opposition assertion, and NOT V2-related; green 5/5 on re-runs, and green on the pre-V2 base too)
- [x] **HARD CONTRACT** — `test_band_pipeline_parity` green, `fp=e943ac9c8bc1` (the all-off
  control layout fp), byte-identical before → after. Signals are not on the generation path;
  zero generation code was touched. m12/m13/loop verify each independently re-confirm the all-off
  fp `e943ac9c8bc1`.
- [x] Definition of done: "Remove the six legacy per-type hazard signals + every emit + consumer
  read, leaving only the generic `opposition_event`/`opposition_killed_player` family; behavior-
  preserving; layout fps untouched; no schema bump." Met — EventBus 60→54, all consumers re-pointed
  onto the generic family, parity fp unchanged, no SCHEMA_VERSION bump.

## Debt ledger (paid down)
- **EventBus 60 → 54 signals** — the six legacy per-type opposition signals deleted (the single
  largest signal-count reduction the bus has seen).
- **6 production emit sites removed** (`hazard_entity.gd` ×2, `bomb_hazard.gd`, `thrown_item.gd`,
  `lethal_contact.gd` ×2 collapsed into the one unconditional generic emit).
- **3 telemetry handlers + 3 connects removed** (`_on_hazard_awoke/_caught/_new_hazard_killed`).
- **3 telemetry schema row-type constants + 3 `ALL_TYPES` entries removed** (no SCHEMA_VERSION bump).
- **`_emit_family` fan-out eliminated** — a param threaded through 10 host scenes into one
  component (var + `_configure` read + `_fire` branch + doc), gone: one contact emit,
  `opposition_event(&"hit_player")`, for every hazard, no per-type branching.
- **3 orphan signals deleted** (`bomb_pulse_started`, `throw_killed_hazard`, `hazard_pursuer_state`
  — emitted, read by nothing outside tests) — pure dead-emit removal.
- Telemetry now counts from ONE opposition family structurally (the double-count-avoidance
  discipline becomes an impossibility).

## Design deviations
**D-RAT-7 / NDR-V2-1 — three unconsumed telemetry payload fields dropped (per the V2 Resolved
Decisions, binding; recorded here for the Wave-2 close-out sweep).** Retiring the six legacy
signals drops three payload fields that have **no in-repo consumer** and cannot be preserved
without an `opposition_event` arity change (forbidden — "signal count only shrinks, arity frozen"):
1. `hazard_awoke.trigger` (`&"depth"`/`&"linger"`) — the only field-drop on a still-consumed
   signal; near-constant debug field, no reader (OQ-1, accept).
2. `throw_killed_hazard.item_id` — orphan signal; `item_id` still available locally in
   `thrown_item._hit_hazard`'s `killer_ctx` (OQ-2, accept). `test_throw_mechanic.gd`'s item_id
   sub-assertion (`:66`) deleted, documented.
3. `hazard_pursuer_state.state` (patrol/chase) — orphan signal; the `&"state"` event preserves
   the transition count/timing, only the discriminant drops (OQ-3, accept). In
   `test_pursuing_hazard.gd` the chase/patrol *value* assertions were converted to "a state MARK
   fired" — the chase-vs-patrol behavioral distinction stays covered by the co-located
   motion/catch assertions, so overall coverage is not weakened.

The resolver's recommendation (binding Resolved Decisions) is **accept all three**; any future
need is served by a **new generic `event` string**, never a legacy-signal revival. These are the
only observable telemetry-shape changes in V2 and are surfaced for the Director's formal
disposition at the Wave-2 close-out sweep (must also be appended to `design/DESIGN_DEVIATIONS.md`).

Otherwise: **none** (all OQ-4…OQ-7 resolved on technical/design merit; `opposition_killed_player`
stays as the generic family's death channel per OQ-4).

## Handoffs / follow-ups
- Historical analysis script `Game/tools/playtest/analyze_m1_2.py` (`:145,152-154`) still names the
  `hazard_awoke`/`hazard_caught` row types — left **untouched** on purpose: it reads *historical
  M1.2 logs on disk* that contain those rows; it is not a live consumer. (Per V2 design + resolver
  verification item 5.)
- The three D-RAT-7 field drops need a Director disposition at the Wave-2 close-out sweep
  (recommendation: accept all three) → then archive to `DESIGN_DEVIATIONS_HISTORY.md`.
