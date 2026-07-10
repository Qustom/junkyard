# V2 / R3 — Retire the dual-emit legacy opposition signals

> **Phase-2 per-task DESIGN doc** (M1.12, Wave 2). Authored per CLAUDE.md "Version breakdown
> authoring — Phase 2". Cites the as-built tree (verified in-repo 2026-07-10). This is a DESIGN
> doc — no code is changed here; it specifies the removal for the build agent.
>
> **Task (breakdown §Wave-2 V2):** Remove the six legacy per-type hazard signals from
> `event_bus.gd` and every emit + consumer read, leaving only the M1.9 generic
> `opposition_event` / `opposition_killed_player` family. **Behavior-preserving:** every consumer
> that read a legacy signal re-points onto the generic family, which already fires at the same
> moment (the dual-emit means the generic path is already live). Layout fps untouched (signals are
> not on the layout path).
>
> **Owner:** general-purpose. **BlockedBy:** none (Wave-1 V7 telemetry rotation merges first —
> sequential wave, no file contention). **Sequences before V3** (Wave 4 builds the hazard deck lane
> on the retired dual-emit — dependency map line `V2 (hazard hosts/signals) ──► V3`).

---

## (a) Research on the premise

### The six legacy signals — identified exactly

`event_bus.gd` self-documents the retirement target. The M1.9 comment block (`event_bus.gd:254-260`)
names the six legacy signals verbatim, declaring them DUAL-EMIT until "post-gate retirement (SG3
watch-item)" — this V2 is that retirement:

> *"Legacy per-type opposition signals above (hazard_awoke, hazard_caught, new_hazard_killed,
> bomb_pulse_started, throw_killed_hazard, hazard_pursuer_state) DUAL-EMIT alongside these
> throughout the migration — retirement is post-gate (SG3 watch-item), never in M1.9."*

| # | Legacy signal | Declared | Signature |
|---|---|---|---|
| 1 | `hazard_awoke` | `event_bus.gd:89` | `(depth: int, trigger: StringName)` |
| 2 | `hazard_caught` | `event_bus.gd:90` | `(depth: int, run_t_ms: int)` |
| 3 | `new_hazard_killed` | `event_bus.gd:149` | `(kind: StringName, depth: int, run_t_ms: int)` |
| 4 | `bomb_pulse_started` | `event_bus.gd:151` | `(depth: int, run_t_ms: int)` |
| 5 | `throw_killed_hazard` | `event_bus.gd:175` | `(item_id: StringName, kind: StringName, depth: int, run_t_ms: int)` |
| 6 | `hazard_pursuer_state` | `event_bus.gd:181` | `(state: StringName, depth: int, run_t_ms: int)` |

**The generic family that STAYS** (M1.9 "S0" set — NOT touched by V2, only widened in coverage):

| Generic signal | Declared | Signature | Event vocabulary (`event_bus.gd:265-266`) |
|---|---|---|---|
| `opposition_event` | `event_bus.gd:269` | `(id: StringName, event: StringName, depth: int, run_t_ms: int)` | `&"spawned"` / `&"awoke"` / `&"telegraph"` / `&"hit_player"` / `&"killed_by_throw"` / `&"state"` |
| `opposition_killed_player` | `event_bus.gd:275` | `(id: StringName, depth: int, run_t_ms: int)` | dedicated death channel (kills-gated) |

> **Disambiguation — do NOT remove the other opposition-adjacent signals.** The R1–R4 telemetry
> signals `return_cost_incurred` (93), `exposure_crossed` (96), `exposure_penalty` (97),
> `nav_branch_taken` (100), `nav_lost_proxy` (101), the R3 penalty/meter signals (113–116), and the
> M1.4 `bomb_pulse_started`'s siblings `quota_*`/`camera_view_set`/`dive_clock_warning`/`exits_placed`
> are **not** the "per-type hazard" family the M1.9 comment enumerates. Only the six named above are
> in scope. `bomb_pulse_started` (#4) IS in scope (it is one of the named six), even though it sits
> in the M1.4 block, because it is a per-type hazard telegraph superseded by `&"telegraph"`.

### The dual-emit pattern (why the generic path is already live)

Every legacy emit is immediately paired with a generic-family emit at the SAME site, SAME timestamp.
The removal is therefore a pure deletion of the legacy half — the generic half already carries the
event. The pairings, at each production emit site:

| # | Legacy emit — file:line | Paired generic emit (already present) — file:line | Same ts? |
|---|---|---|---|
| 1 | `hazard_entity.gd:200` `hazard_awoke.emit(depth, _trigger.pending_trigger)` | `hazard_entity.gd:201` `opposition_event.emit(&"pursuer", &"awoke", depth, run_clock_ms())` | yes |
| 2 | `lethal_contact.gd:147` `hazard_caught.emit(depth, run_t_ms)` (when `_emit_family==&"hazard_caught"`) | `lethal_contact.gd:150` `opposition_event.emit(_def_id, &"hit_player", depth, run_t_ms)` | yes |
| 3 | `lethal_contact.gd:149` `new_hazard_killed.emit(_def_id, depth, run_t_ms)` (else branch) | `lethal_contact.gd:150` `opposition_event.emit(_def_id, &"hit_player", depth, run_t_ms)` | yes |
| 4 | `bomb_hazard.gd:122` `bomb_pulse_started.emit(depth, run_t_ms)` | `bomb_hazard.gd:123` `opposition_event.emit(&"bomb", &"telegraph", depth, run_t_ms)` | yes |
| 5 | `thrown_item.gd:100` `throw_killed_hazard.emit(item_id, kind, _depth, _run_t_ms())` | `thrown_item.gd:101` `opposition_event.emit(kind, &"killed_by_throw", _depth, _run_t_ms())` | yes |
| 6 | `hazard_entity.gd:189` `hazard_pursuer_state.emit(state, depth, run_t_ms)` | `hazard_entity.gd:190` `opposition_event.emit(&"pursuer", &"state", depth, run_t_ms)` | yes |

**Key structural fact:** in `lethal_contact._fire()` (`lethal_contact.gd:143-155`) the legacy #2/#3
are a *branch* on `_emit_family`, but the generic `&"hit_player"` emit (line 150) is
**unconditional** — it fires on every contact regardless of family. So both #2 and #3 collapse into
the single already-present generic emit; the `_emit_family` branch and the whole `_emit_family`
parameter become dead once the two legacy emits are gone (see deletion recipe below).

### Every consumer of the six legacy signals (production, with file:line)

The critical finding: **only three of the six legacy signals have a production consumer at all**
(all three in Telemetry). The other three (`bomb_pulse_started`, `throw_killed_hazard`,
`hazard_pursuer_state`) are **orphan emits** — emitted but read by nothing outside the test tree.
Verified: `grep -rn "<signal>.connect" --include=*.gd | grep -v tests` returns zero for all three.

| # | Legacy signal | Production consumer | What it does | Generic coverage |
|---|---|---|---|---|
| 1 | `hazard_awoke` | `telemetry.gd:74` connect → `_on_hazard_awoke` (`telemetry.gd:227-228`) writes `HAZARD_AWOKE` row `{depth, trigger}` | logs a dormant→awake row | `opposition_event(&"pursuer", &"awoke", …)` → `OPPOSITION_EVENT` row `{id:"pursuer", event:"awoke", depth, run_t_ms}`. **Loses the `trigger` field** — see OQ-1. |
| 2 | `hazard_caught` | `telemetry.gd:75` connect → `_on_hazard_caught` (`telemetry.gd:231-236`) writes `HAZARD_CAUGHT` row `{depth, run_t_ms}` + flush | logs an R1 catch (precedes a death run_ended) | `opposition_event(&"pursuer", &"hit_player", …)` → `OPPOSITION_EVENT` row `{id:"pursuer", event:"hit_player", depth, run_t_ms}`. Superset. |
| 3 | `new_hazard_killed` | `telemetry.gd:86` connect → `_on_new_hazard_killed` (`telemetry.gd:239-244`) writes `NEW_HAZARD_KILLED` row `{kind, depth, run_t_ms}` + flush | logs a K5 fatal contact by kind | `opposition_event(<id>, &"hit_player", …)` → row `{id:<kind>, event:"hit_player", depth, run_t_ms}`. `id == kind` (contract, `event_bus.gd:263-264`). Superset. |
| 4 | `bomb_pulse_started` | **none** (orphan) | — | `opposition_event(&"bomb", &"telegraph", …)` already logs the telegraph row. |
| 5 | `throw_killed_hazard` | **none** (orphan) | — | `opposition_event(<kind>, &"killed_by_throw", …)` already logs the throw-kill. **Loses `item_id`** — see OQ-2 (no production consumer read it). |
| 6 | `hazard_pursuer_state` | **none** (orphan) | — | `opposition_event(&"pursuer", &"state", …)` already logs a state transition. **Loses the `state` value** (patrol/chase) — see OQ-3 (no production consumer read it). |

### The `_emit_family` plumbing that also dies

`_emit_family` exists ONLY to select `hazard_caught` vs `new_hazard_killed` at `lethal_contact.gd:146`.
Once both legacy emits are removed, the parameter is dead. It is threaded from **10 hazard host
scenes** into `LethalContact`:

- `lethal_contact.gd`: var `_emit_family` (46), `_configure` read (66), the `_fire` branch (146-149),
  the doc mentions (34-35).
- Host param-sets (all pass `emit_family`): `hazard_entity.gd:121` (`&"hazard_caught"`),
  `bomb_hazard.gd:85`, `pingpong_hazard.gd:83`, `spike_hazard.gd:84`, `splitter.gd:123`,
  `ambusher_hazard.gd:158`, `charger_hazard.gd:119`, `lobber_hazard.gd:112`, `sentry_hazard.gd:106`,
  `burrower_hazard.gd:107` (all `&"new_hazard_killed"`).

All 10 `emit_family` param-sets + the LethalContact var/read/branch/doc are deletable dead weight
once #2/#3 are retired. This is where most of the V2 line-deletion comes from.

### Telemetry schema surface

`telemetry_schema.gd` declares three constants for the retired rows: `HAZARD_AWOKE` (38),
`HAZARD_CAUGHT` (39), `NEW_HAZARD_KILLED` (57) + their three `ALL_TYPES` entries (92, 93, 102).
Retiring the three legacy Telemetry handlers means these rows stop being written; the constants +
`ALL_TYPES` entries become dead and should be removed (they are used only by the retired handlers and
by tests that assert those rows — see re-point list). **No `SCHEMA_VERSION` bump** — dropping a
never-again-written additive row type does not break the envelope (v stays 1); older logs that
contain the rows still parse (the constants are only needed to *write*/*assert*, not to read
arbitrary JSON). This aligns with the breakdown's "no save/schema change" guardrail — telemetry
schema is not the save schema, and the envelope is unchanged.

### Analysis-script surface (historical, leave as-is)

`Game/tools/playtest/analyze_m1_2.py:145,152-154` references `hazard_awoke`/`hazard_caught` in its
`interesting` list and an "I2: hazard_caught → death linkage" section. **This is a round-specific
analysis of the historical M1.2 telemetry logs**, which already contain those rows on disk — it
reads past data and must keep reading it. It is NOT a live consumer of the signal. **Leave it
untouched** (removing the emit does not remove old logs; the script analyzing an old round still
needs the old row name). Note it in the worklog for traceability. (V7 gives this script an argv input
in Wave 1; V2 does not touch its row vocabulary.)

---

## (b) Migration recipe — per site

The build agent performs these edits on branch `general-purpose/V2-retire-dual-emit`. Order:
emit-sites → orphan cleanup → telemetry consumers → schema → event_bus declarations → tests.

### 1. `event_bus.gd` — delete the six declarations + fix the comment

```gdscript
# DELETE line 89  signal hazard_awoke(...)          (+ its "--- R1 ..." doc line 88)
# DELETE line 90  signal hazard_caught(...)
# DELETE line 149 signal new_hazard_killed(...)     (+ its K5a/b/c doc lines 146-148)
# DELETE line 151 signal bomb_pulse_started(...)    (+ its doc line 150)
# DELETE line 175 signal throw_killed_hazard(...)   (+ its doc lines 171-174)
# DELETE line 181 signal hazard_pursuer_state(...)  (+ its L2 doc lines 177-180)
# EDIT   lines 257-260: rewrite the M1.9 comment — the "Legacy per-type opposition
#        signals above (…) DUAL-EMIT … retirement is post-gate" note is now HISTORY.
#        Replace with a one-line note: "The generic family below is the SOLE opposition
#        signal family (M1.12/V2 retired the six legacy per-type signals — see
#        DESIGN_DEVIATIONS_HISTORY / V2 worklog)."
```

Leave `depth_changed`, the R2/R3/R4 telemetry signals, `quota_*`, and all M1.4+ non-hazard signals
intact. Signal count: 60 → 54.

### 2. `hazard_entity.gd` — drop the two legacy emits, keep the generic twins

```gdscript
# _awaken() (lines 196-201): DELETE line 200 (hazard_awoke.emit).
#   KEEP line 201 opposition_event.emit(&"pursuer", &"awoke", depth, run_clock_ms()).
# _emit_pursuer_state() (lines 183-190): DELETE line 189 (hazard_pursuer_state.emit).
#   KEEP line 190 opposition_event.emit(&"pursuer", &"state", depth, run_t_ms).
# EDIT the doc comments (lines 180-182, 193-195) that describe the "dual-emit" — now single-emit.
# DELETE line 121 the "emit_family": &"hazard_caught" param entry (dead — see step 5).
```

### 3. `bomb_hazard.gd` — drop the orphan telegraph emit

```gdscript
# _arm() (lines 115-123): DELETE line 122 (bomb_pulse_started.emit).
#   KEEP line 123 opposition_event.emit(&"bomb", &"telegraph", depth, run_t_ms).
# EDIT doc (lines 113-114) to drop the "bomb_pulse_started" mention.
# DELETE line 85 the "emit_family": &"new_hazard_killed" param entry (dead — step 5).
```

### 4. `thrown_item.gd` — drop the orphan throw-kill emit

```gdscript
# _hit_hazard() (lines 96-108): DELETE line 100 (throw_killed_hazard.emit).
#   KEEP line 101 opposition_event.emit(kind, &"killed_by_throw", _depth, _run_t_ms()).
# EDIT doc (lines 89-95) that describes throw_killed_hazard "keeps its exact site" — now retired,
#   the &"killed_by_throw" generic emit is authoritative.
# NOTE: item_id is no longer emitted anywhere (OQ-2). It is still used locally as the killer_ctx
#   (line 105) — that stays; only the signal payload drops it.
```

### 5. `lethal_contact.gd` — collapse the `_emit_family` branch, delete the dead param

```gdscript
# _fire() (lines 143-155): REPLACE the branch
#     if _emit_family == &"hazard_caught":
#         EventBus.hazard_caught.emit(depth, run_t_ms)
#     else:
#         EventBus.new_hazard_killed.emit(_def_id, depth, run_t_ms)
#     EventBus.opposition_event.emit(_def_id, &"hit_player", depth, run_t_ms)
#   WITH just the generic emit (drop the whole if/else):
#     EventBus.opposition_event.emit(_def_id, &"hit_player", depth, run_t_ms)
# DELETE var _emit_family (46), the _configure read (66), the doc mentions (34-35).
# The opposition_killed_player emit (line 153) is UNCHANGED — it is the generic death channel.
```

Then delete the now-dead `"emit_family"` param entry from each of the 9 remaining hosts:
`pingpong_hazard.gd:83`, `spike_hazard.gd:84`, `splitter.gd:123`, `ambusher_hazard.gd:158`,
`charger_hazard.gd:119`, `lobber_hazard.gd:112`, `sentry_hazard.gd:106`, `burrower_hazard.gd:107`
(plus `hazard_entity.gd:121` and `bomb_hazard.gd:85` already covered in steps 2/3).

### 6. `telemetry.gd` — drop the three legacy connects + handlers

```gdscript
# DELETE line 74 EventBus.hazard_awoke.connect(_on_hazard_awoke)
# DELETE line 75 EventBus.hazard_caught.connect(_on_hazard_caught)
# DELETE line 86 EventBus.new_hazard_killed.connect(_on_new_hazard_killed)
# DELETE func _on_hazard_awoke      (lines 227-228)
# DELETE func _on_hazard_caught     (lines 231-236)
# DELETE func _on_new_hazard_killed (lines 239-244)
# The generic _on_opposition_event (258-267) + _on_opposition_killed_player (270-279) STAY — they
#   already log the same moments. NO new handler is needed: the generic listeners are already
#   connected (lines 95-96) and already fire (dual-emit).
# EDIT the comment block (lines 71-73, 83-86) to drop the "legacy per-type" framing.
```

**Flush note (behavior check):** `_on_hazard_caught` (236) and `_on_new_hazard_killed` (244) each
`flush()` because they "precede a death run_ended." That crash-safety is preserved: on the death path
`opposition_killed_player` fires and `_on_opposition_killed_player` flushes (`telemetry.gd:278-279`).
On a *non-fatal* contact the legacy flush had no death to precede (wasteful); dropping it is
harmless. The `&"hit_player"` generic row is still written (unflushed, like every other non-terminal
row) — identical to today's generic behavior.

### 7. `telemetry_schema.gd` — drop the three dead row-type constants

```gdscript
# DELETE const HAZARD_AWOKE (38), HAZARD_CAUGHT (39), NEW_HAZARD_KILLED (57) + their doc comments.
# DELETE their three ALL_TYPES entries (92 HAZARD_AWOKE, 93 HAZARD_CAUGHT, 102 NEW_HAZARD_KILLED).
# NO SCHEMA_VERSION bump (envelope unchanged; only three additive row types stop being emitted).
```

### 8. Test re-points (the equivalence-documented ones)

Two classes of test edit. **Class A — production-consumer tests** (assert a telemetry ROW): re-point
the assertion onto the generic `OPPOSITION_EVENT` / `OPPOSITION_KILLED_PLAYER` row. **Class B —
per-hazard component tests** (connect a legacy signal to count emits): drop the legacy-signal
sink/assertion; keep the generic `opposition_event` / `opposition_killed_player` assertion the same
test already makes (every hazard test already connects the generic family — verified: `test_ambusher`,
`test_charger`, `test_burrower`, `test_lobber`, `test_sentry`, `test_splitter` all connect
`opposition_killed_player`; `test_opposition_components` connects both families).

| Test file | Sites | Re-point |
|---|---|---|
| `test_telemetry_jsonl.gd` | `:104-111` asserts a `NEW_HAZARD_KILLED` row; `:153` drives `new_hazard_killed.emit` | Drive `opposition_event.emit(&"spike", &"hit_player", 2, 0)` instead; assert an `OPPOSITION_EVENT` row with `{id:"spike", event:"hit_player"}` (equivalent — same moment, id==kind). |
| `test_telemetry_config_marking.gd` | `:33-34` field map, `:87-88` drive `hazard_awoke`/`hazard_caught`, `:170` iterates the two types | Drive `opposition_event` (`&"awoke"`/`&"hit_player"`) instead; the config-marking mechanism is generic (it stamps every row) so the assertion holds on the generic rows. Update the field-map keys to `opposition_event` fields `{id, event, depth, run_t_ms}`. |
| `test_def_menu_coverage.gd` | `:163` drives `new_hazard_killed.emit(&"spike",…)` (`:162` already drives `opposition_killed_player`) | Delete the legacy drive line; the test's point (a def-menu coverage row lands) is already carried by the generic drives at `:162`. Update the `:14-15` doc note. |
| `test_rg1_m12_verify.gd` | `:551` `hazard_types := ["hazard_awoke","hazard_caught"]`; `:558,564-566` assert them in the assembled loop | Re-point to `opposition_event` rows filtered by `event in {"awoke","hit_player"}` with `id=="pursuer"` (the R1 run's generic rows). The all-off "no opposition rows" negative assertion (`:557-560`) re-points to "no `opposition_event` rows" (stronger + simpler). |
| `test_rg1_m13_verify.gd` | `:701` same `hazard_types` list | Same re-point as m12. |
| `test_rg1_loop_verify.gd` | `:245,412` same | Same re-point; `:245` comment ("emits hazard_awoke") → "emits opposition_event &awoke". |
| `test_pursuing_hazard.gd` | `:38-41` connect `hazard_awoke`/`hazard_caught`/`hazard_pursuer_state`; assertions `:147-165,246,277,387,520-525` | Class B: re-point the sinks onto `opposition_event` filtered by `event` (`&"awoke"` for awoke-count, `&"hit_player"` for catch-count, `&"state"` for pursuer-state). The BUG6 "exactly once" latch assertions (`:277`) hold identically on the `&"hit_player"` generic count (same emit site, same latch). |
| `test_opposition_components.gd` | `:70-74` connect all six legacy; `:317-338` sinks | Class B: this test's PURPOSE (`:12-13` doc) is the dual-emit log — after V2 there is no dual, so re-point the six sinks onto the generic `opposition_event` events (`&"awoke"/&"hit_player"/&"telegraph"/&"killed_by_throw"/&"state"`) it already partially checks. Document the re-point as the equivalence (legacy row N ⇔ generic event with matching `event` string). |
| `test_bomb_hazard.gd` | `:45` connect `bomb_pulse_started`; `:46` connect `new_hazard_killed`; assertions `:137-179` | Class B: re-point `bomb_pulse_started`→`opposition_event event==&"telegraph"`; `new_hazard_killed`→`opposition_event event==&"hit_player"`. Counts identical (same emit sites). |
| `test_spike_hazard.gd` | `:133-176` connect/assert `new_hazard_killed` | `opposition_event event==&"hit_player"` (id=="spike"). |
| `test_pingpong_hazard.gd` | `:96-139` connect/assert `new_hazard_killed` | `opposition_event event==&"hit_player"` (id=="pingpong"). |
| `test_sentry.gd` `test_ambusher.gd` `test_charger.gd` `test_burrower.gd` `test_lobber.gd` | each connects `new_hazard_killed` (+ `throw_killed_hazard`) for kind/count | Class B: re-point `new_hazard_killed`→`opposition_event &"hit_player"`, `throw_killed_hazard`→`opposition_event &"killed_by_throw"`. Each already connects `opposition_killed_player` for the death assertion — that stays. |
| `test_throw_mechanic.gd` | `:45-68` connect/assert `throw_killed_hazard` (item_id, kind, depth) | Re-point to `opposition_event event==&"killed_by_throw"` for kind/depth. **item_id is not on the generic payload (OQ-2)** — if the test asserts `item_id`, drop that sub-assertion and document it (no production consumer needs item_id). |

Every re-point carries a one-line equivalence comment in the test: *"legacy `<signal>` retired
(M1.12/V2) → generic `opposition_event(event=<x>)` fires at the identical site/moment; count and
payload (minus <lost field, if any>) preserved."*

---

## (c) Open Questions

**OQ-1 — `hazard_awoke.trigger` is dropped from telemetry.** The `HAZARD_AWOKE` row carried
`trigger: StringName` (the wake trigger, e.g. `_trigger.pending_trigger` — `hazard_entity.gd:200`).
The generic `opposition_event(&"pursuer", &"awoke", …)` payload has no `trigger` field
(`event_bus.gd:269` — only `id/event/depth/run_t_ms`). This is the ONLY field-level data loss on a
signal that has a live production consumer. Options: **(a)** accept the loss — `trigger` was never
read by any analysis (grep: only the schema/handler/tests reference it; no analysis script consumes
it); the R1 pursuer has effectively one trigger type today, so the field is near-constant. **(b)**
Preserve it by widening the generic event vocabulary to carry an optional detail — but
`opposition_event`'s arity is FROZEN (M1.1 pre-declare rule; adding a param is a bus change V2 must
not make, and the breakdown says "signal count only shrinks, never grows"). **Rec: (a) accept** —
it's a near-constant debug field with no consumer; note the drop in the worklog + DESIGN_DEVIATIONS.
*Flag for fresh-eyes: is `trigger` used by any off-repo analysis the Director cares about? If yes,
this becomes a Needs-Director item.*

**OQ-2 — `throw_killed_hazard.item_id` is dropped.** The legacy signal carried *which thrown item*
killed the hazard; the generic `&"killed_by_throw"` event carries only the hazard `kind` as `id`, not
the throwing item's id (`thrown_item.gd:101`). **No production consumer reads it** (orphan signal —
only `test_throw_mechanic.gd` asserts item_id). **Rec: accept** — the throw-kill *moment* is
preserved; the *projectile identity* was telemetry-only and unconsumed. `item_id` still exists
locally in `_hit_hazard` (used for the `killer_ctx`, `thrown_item.gd:105`) — only the *signal
payload* drops it. Drop the item_id sub-assertion in `test_throw_mechanic`, documented.

**OQ-3 — `hazard_pursuer_state.state` (patrol/chase) is dropped.** The generic `&"state"` event
records that a transition happened but not *to which state* (`hazard_entity.gd:190` emits only
`&"pursuer", &"state"`). Orphan signal — no production consumer; only `test_pursuing_hazard` and
`test_opposition_components` read `state`. **Rec: accept** — the transition *count/timing* is
preserved via the `&"state"` event; the patrol-vs-chase discriminant was unconsumed telemetry. If a
future consumer needs it, that is a generic-vocabulary addition (a new `event` string like
`&"chase"`/`&"patrol"`), not a legacy-signal revival — out of V2 scope. *Fresh-eyes: confirm no gate
analysis segments pursuer runs by patrol/chase ratio.*

**OQ-4 — Does `opposition_killed_player` stay, or fold into `opposition_event`?** The task title asks
"leaving only the generic family," and the breakdown's DoD says *"`opposition_event` remains the
single opposition telemetry source."* But `opposition_killed_player` is **part of the generic
family**, deliberately kept as a *separate* channel (`event_bus.gd:270-275`, S0 §5): kill-direction
must never poison hit/contact counts, exactly as L1 kept `throw_killed_hazard` separate from
`new_hazard_killed`. Folding it into `opposition_event(&"killed_player")` would (a) change the arity
contract of neither signal but (b) merge the death channel into the contact channel, re-introducing
the very count-poisoning S0 designed against, and (c) is a *behavioral* telemetry change beyond
"retire the six legacy signals." **Rec: `opposition_killed_player` STAYS as-is** — it is not one of
the six legacy signals; it is the second half of the generic family the task preserves. V2 removes
six signals (60→54), it does not touch the two generic ones. *This is a definitional clarification,
not a Director call — but flag it so Phase-3 confirms the DoD reading.*

**OQ-5 — Test re-point vs. test deletion for `test_opposition_components.gd`.** That test's entire
stated purpose (`:12-13`) is asserting the *dual-emit* (legacy + generic fire together). After V2
there is no dual. Two options: **(a)** re-point its six legacy sinks onto the generic `event` strings
(the test becomes "the generic family fires the right `event` for each lifecycle moment" — still
valuable coverage), or **(b)** retire the test if `test_pursuing_hazard` + the per-hazard tests
already cover every generic `event`. **Rec: (a) re-point + rename its intent** — keep the coverage,
change the contract from "both families agree" to "the generic family emits the correct `event`
vocabulary." Cheaper than proving redundancy, and preserves a single focused generic-vocabulary test.

**OQ-6 — Telemetry-schema constant removal vs. keep-as-deprecated.** Removing `HAZARD_AWOKE` /
`HAZARD_CAUGHT` / `NEW_HAZARD_KILLED` from `telemetry_schema.gd` + `ALL_TYPES` is the clean debt
paydown. Alternative: keep them (marked deprecated) so historical-log readers/validators still
recognize the strings. **Rec: remove** — `ALL_TYPES` is a *forward* validator ("is this row type one
we currently emit"); a row type we will never write again should not be in it. Historical analysis
(`analyze_m1_2.py`) hardcodes the string literals it needs and does not import `ALL_TYPES`, so removal
doesn't break past-log analysis. Net debt down. *Confirm no test imports `ALL_TYPES` expecting the
three (the config-marking test iterates row types — re-pointed in step 8).*

**OQ-7 — `emit_family` param: fully delete vs. leave inert.** Deleting the param from all 10 hosts +
LethalContact is the full paydown but touches 10 host files (single-writer-per-file is respected —
all in V2's worktree, one wave). Leaving it inert (unused) would minimize the diff but leave a dead
parameter — exactly the debt M1.12 exists to remove. **Rec: fully delete** — it is 100% dead once
#2/#3 retire, and "one way to do each thing" is the version thesis. This is the bulk of V2's LOC
deletion and the clearest debt-ledger line.

---

## Expected debt ledger (net LOC removed)

The version's measure is negative net LOC. Estimate (production code; test churn is roughly
net-neutral — re-points swap one sink for another):

| Surface | Removed |
|---|---|
| `event_bus.gd` — 6 signal declarations + their doc-comment lines | ~6 signals + ~14 doc lines |
| `hazard_entity.gd` — 2 legacy emits (`hazard_awoke`, `hazard_pursuer_state`) + 1 `emit_family` param + doc trims | ~4 |
| `bomb_hazard.gd` — 1 emit (`bomb_pulse_started`) + 1 `emit_family` param + doc | ~3 |
| `thrown_item.gd` — 1 emit (`throw_killed_hazard`) + doc | ~2 |
| `lethal_contact.gd` — the `_emit_family` branch collapse (4 lines → 1) + var + `_configure` read + doc | ~6 |
| 9 hazard hosts — one dead `emit_family` param-set line each | ~9 |
| `telemetry.gd` — 3 connects + 3 handlers (`_on_hazard_awoke/_caught/_new_hazard_killed`) + doc | ~18 |
| `telemetry_schema.gd` — 3 constants + 3 `ALL_TYPES` entries + doc | ~10 |
| **Net production LOC removed** | **≈ 60–75 lines** |

**Coupling/duplication retired (the qualitative ledger):**
- **EventBus shrinks 60 → 54 signals** — the single largest signal-count reduction the bus has seen.
- **The `_emit_family` fan-out dies** — a parameter threaded through 10 host scenes into one
  component, existing solely to pick which of two legacy signals to fire, is gone: **one contact
  emit, `opposition_event(&"hit_player")`, for every hazard**, no per-type branching.
- **Telemetry counts from ONE family, structurally** — the "count from the generic one to avoid
  double-counting" *discipline* (a comment other people had to remember, `telemetry.gd:91-94`) becomes
  an *impossibility* (there is only one family). Ends the double-count-avoidance dance in analysis.
- **Three orphan signals deleted** (`bomb_pulse_started`, `throw_killed_hazard`,
  `hazard_pursuer_state` — emitted, read by nothing) — pure dead-emit removal.

**Regression floor:** all four control layout fps (`e943ac9c8bc1`, band_greybox/two/three) untouched
— signals are not on the layout path (breakdown §Scope). No `SCHEMA_VERSION` bump; no save-schema
change (meta stays v4). Full suite green after re-points. The generic family fires at every moment
the legacy family did (dual-emit is the proof), so **no gameplay or telemetry moment is lost** — only
the three named payload fields (OQ-1/2/3, all unconsumed or near-constant) drop, each documented.

---

## Resolved Decisions (Phase 3)

> **Fresh-eyes resolution (2026-07-10).** A resolver who did NOT author this design read the doc
> against the as-built tree and **verified every load-bearing claim from primary sources** before
> resolving. This section is **binding**: it locks OQ-1…OQ-7 and hands the build agent a corrected,
> unambiguous contract. The three field-drops (OQ-1/2/3) are behavior-preservation calls surfaced to
> the Director as a consolidated FYI under **Needs Director review** (with a firm accept recommendation),
> because they are the only observable telemetry-shape changes in the version and become
> `DESIGN_DEVIATIONS.md` entries at the Wave-2 close-out sweep regardless.

### Verification log (claims checked against the real tree, 2026-07-10)

Every factual claim the design rests on was re-checked; **all held**:

1. **Six legacy signals** declared at `event_bus.gd:89, 90, 149, 151, 175, 181` — confirmed verbatim,
   signatures as tabled. EventBus has **exactly 60** `signal` declarations today (`grep -c "^signal "`);
   60 → 54 after removal.
2. **Consumer census exact.** Only `hazard_awoke` (`telemetry.gd:74`), `hazard_caught` (`:75`),
   `new_hazard_killed` (`:86`) have any production `.connect` — **all three in `telemetry.gd`, none
   elsewhere.** `bomb_pulse_started` / `throw_killed_hazard` / `hazard_pursuer_state` have **zero**
   production `.connect` (only tests) → genuine orphans. Confirmed by
   `grep -rn "<sig>.connect" --include=*.gd`.
3. **Dual-emit pairing exact.** Verified each legacy emit sits beside its generic twin at the same
   site/timestamp: `lethal_contact.gd:146-150` (the `_emit_family` if/else at 146-149 + the
   **unconditional** `opposition_event(&"hit_player")` at 150), `hazard_entity.gd:189-190` &
   `200-201`, `bomb_hazard.gd:122-123`, `thrown_item.gd:100-101`. The design's "collapse the branch to
   the single generic emit" recipe is correct — line 150 already fires on every contact.
4. **`item_id` survives locally.** `thrown_item.gd` still uses `item_id` in the `killer_ctx` dict passed
   to `resolve_throw_death` (`:104-106`) after the signal payload drops it — the OQ-2 "stays locally"
   claim holds; dropping the *signal* arg loses no local behavior.
5. **No analysis script consumes the at-risk fields.** The only Python analysis, `analyze_m1_2.py`,
   references the *row-type names* `hazard_awoke`/`hazard_caught` (`:145, 152-154`) on **historical
   M1.2 logs** and reads **no** `trigger`, `item_id`, `state`, `patrol`, or `chase` sub-field. Leave it
   untouched (historical reader) — confirmed correct.
6. **No `SCHEMA_VERSION` coupling.** `SCHEMA_VERSION` stays 1; `ENVELOPE_KEYS` untouched; the save chain
   (`META_SCHEMA_VERSION = 4` in `save_manager.gd`) is **entirely separate** from telemetry schema. No
   bump, no save-schema change. `test_telemetry_config_marking.gd:59` and the RG verify suite assert
   `v == SCHEMA_VERSION == 1`; nothing here moves it.
7. **No test guards the signal count.** No production/verify test calls `get_signal_list`/asserts a
   signal tally on EventBus (the only `get_signal_list` hits are inside the gdUnit4 addon). 60 → 54 is
   safe.
8. **`ALL_TYPES` removal is safe.** Its only iterators are: `test_telemetry_config_marking.gd` (iterates
   `OPPOSITION_ROW_FIELDS.keys()`, which the test itself edits in step 8 — see the added build-note
   below), `test_telemetry_jsonl.gd:75` and `:113` of config-marking (assert each *written* row's type
   is in `ALL_TYPES` — after re-point, only generic rows are written, all still in `ALL_TYPES`), and
   `test_def_menu_coverage.gd:222-225` (checks the S4 *generic* types are present — untouched by this
   removal). Removing `HAZARD_AWOKE`/`HAZARD_CAUGHT`/`NEW_HAZARD_KILLED` from the constants + `ALL_TYPES`
   reddens nothing that isn't already re-pointed in step 8.

### OQ-1 — `hazard_awoke.trigger` drop → **RESOLVED: accept the drop, document as a deviation.**

`trigger` has **no reader** anywhere in-repo: not `telemetry.gd` beyond writing it, not the analysis
script, and even `test_telemetry_config_marking.gd` asserts only the field's *presence*, never its
value. The generic `opposition_event(id, event, depth, run_t_ms)` arity is **frozen** (M1.1 pre-declare
rule + the breakdown's "signal count only shrinks, arity never grows") so option (b) — widen the payload
— is **out of bounds for V2**. Encoding `trigger` into the `event` string (e.g. `&"awoke:depth"`) would
fork the locked six-value event vocabulary and complicate every downstream `event`-filter for a
near-constant debug field — not worth it. **Decision: accept (design's rec a).** Record the drop in the
V2 worklog + `DESIGN_DEVIATIONS.md`. If a future analysis genuinely needs wake-trigger forensics, the
correct path is a **new `event` string** (a generic-vocabulary addition), never reviving the legacy
signal. Surfaced to the Director in the consolidated FYI below.

### OQ-2 — `throw_killed_hazard.item_id` drop → **RESOLVED: accept the drop, document; drop the item_id sub-assertion in `test_throw_mechanic`.**

Orphan signal (no production consumer). `item_id` on the *signal* is telemetry-only and unread by any
analysis; the throw-kill *moment* (and the hazard `kind`) is preserved on
`opposition_event(kind, &"killed_by_throw", …)`. `item_id` **remains available locally** for the
`killer_ctx` (verified `thrown_item.gd:105`) so no gameplay behavior changes. **Decision: accept.** In
`test_throw_mechanic.gd`, re-point the kill assertion onto `opposition_event event==&"killed_by_throw"`
(kind/depth) and **delete the `item_id` sub-assertion** (`:66`), with the one-line equivalence comment.
Surfaced in the FYI below.

### OQ-3 — `hazard_pursuer_state.state` (patrol/chase) drop → **RESOLVED: accept the drop, document.**

Orphan signal. The generic `&"state"` event preserves the transition's **count + timing** (same
rising-edge latch at `hazard_entity.gd:183-190`); only the patrol-vs-chase *discriminant* drops, and it
is read by **no** production consumer or analysis — verified: no gate/analysis segments pursuer runs by
patrol/chase ratio (`analyze_m1_2.py` has no such section; grep for `patrol`/`chase` in `tools/` is
empty). **Decision: accept.** A future need for the discriminant is a new `event` string
(`&"chase"`/`&"patrol"`), out of V2 scope. Surfaced in the FYI below.

### OQ-4 — Does `opposition_killed_player` stay? → **RESOLVED: YES, it STAYS. The author's reasoning holds.**

Confirmed against the code: `opposition_killed_player` is declared at `event_bus.gd:275` as the **second
half of the M1.9 generic family**, and the kill/contact separation is *load-bearing* at
`lethal_contact.gd:150-153` — `opposition_event(&"hit_player")` fires on **every** contact (line 150)
while `opposition_killed_player` fires **only** when the `_kills` gate actually calls `fail_run` (lines
151-153). Folding the death channel into `opposition_event` would re-introduce exactly the
count-poisoning S0 designed against (kill-direction contaminating hit/contact counts). It is **not** one
of the six legacy signals; V2 removes six (60→54) and touches **neither** generic signal. The
breakdown DoD phrase "`opposition_event` remains the single opposition telemetry source" means "one
family, no legacy per-type siblings," **not** "one signal" — `opposition_killed_player` is part of that
one family. **Decision: keep as-is, unchanged.**

### OQ-5 — Re-point vs. delete `test_opposition_components.gd` → **RESOLVED: re-point (design's rec a).**

The test's stated purpose (`:12-13`) is asserting the dual-emit; after V2 there is no dual. Re-point its
six legacy sinks onto the generic `opposition_event` `event` strings it already partially checks,
reframing its contract from "both families agree" to "the generic family emits the correct `event`
vocabulary (`&"awoke"/&"hit_player"/&"telegraph"/&"killed_by_throw"/&"state"`) at each lifecycle
moment." This preserves a single focused generic-vocabulary test at lower cost than proving redundancy
against `test_pursuing_hazard` + the per-hazard suite. Update the doc header (`:12-13`) to the new
intent.

### OQ-6 — Remove vs. keep-deprecated the three schema constants → **RESOLVED: remove (design's rec).**

`ALL_TYPES` is a **forward** validator ("is this a row type we currently emit"); a type never written
again must leave it. Removal is safe per verification item 8 above — no iterator breaks that step 8 does
not already re-point. Historical-log analysis hardcodes the string literals and does not import
`ALL_TYPES`, so past-log reads are unaffected. Delete `HAZARD_AWOKE` (`:38`), `HAZARD_CAUGHT` (`:39`),
`NEW_HAZARD_KILLED` (`:57`) + their three `ALL_TYPES` entries (`:92, 93, 102`). Net debt down.

### OQ-7 — `emit_family` param: delete vs. leave inert → **RESOLVED: fully delete (design's rec).**

100% dead once #2/#3 retire (its sole purpose is the `lethal_contact.gd:146` branch). All 10 host
param-sets + the `LethalContact` var (`:46`) / `_configure` read (`:66`) / branch (`:146-149`) / doc
(`:34-35`) are in V2's single worktree this wave (single-writer-per-file respected), so full deletion is
clean and is the version thesis ("one way to do each thing"). Confirmed the 10 hosts: `hazard_entity.gd:121`,
`bomb_hazard.gd:85`, `pingpong_hazard.gd:83`, `spike_hazard.gd:84`, `splitter.gd:123`,
`ambusher_hazard.gd:158`, `charger_hazard.gd:119`, `lobber_hazard.gd:112`, `sentry_hazard.gd:106`,
`burrower_hazard.gd:107`.

### Layout-fingerprint safety → **CONFIRMED byte-identical.**

The four control layout fps (`e943ac9c8bc1`, band_greybox/two/three) are placement hashes computed from
band/junk generation; the six signals fire from **runtime hazard gameplay**, and hazards are **OFF** in
the all-off `e943ac9c8bc1` control (the layout fps are hazard-free per breakdown §Scope). Deleting
signal declarations/emits/handlers touches no generation code path. No fp move — a fp move here would be
a bug, not a sanctioned deviation.

### Corrected build-notes (fold into the step-8 recipe — do NOT re-open the design)

These are precision fixes the resolver caught while verifying; they refine, not change, the migration:

- **`test_telemetry_config_marking.gd` has THREE sites, not two, tied to the retired rows.** Step 8's row
  names `:33-34` (field map) and `:87-88` (drives) but the test ALSO iterates
  `["hazard_caught", "exposure_crossed"]` at **`:170`** (Criterion 4 — "TEL stamped run_t_ms itself").
  Re-point that list too: replace `"hazard_caught"` with the driven `opposition_event` row — it **also**
  self-stamps `run_t_ms` via `_elapsed_ms()` (`telemetry.gd:266`), so the equivalence is exact. Remove
  the `hazard_awoke`/`hazard_caught` keys from `OPPOSITION_ROW_FIELDS` (`:33-34`); the remaining five
  R2–R4 rows stay (they are NOT in V2 scope). The "7 opposition types" comment (`:31`, `:63`) becomes
  "5 opposition types."
- **`test_throw_mechanic.gd` item_id sub-assertion is at `:66`** (`throw_killed_hazard item_id = ...`) —
  delete that specific sub-assertion per OQ-2; keep the kind/depth checks re-pointed to
  `opposition_event`.
- **`opposition_def.gd:7`** carries a *doc comment* mentioning "new_hazard_killed / throw_killed_hazard
  vocabulary" — a **comment only**, no signal reference. Optionally freshen it to name the generic
  `event` vocabulary; not required for correctness (leave-or-trim, build agent's discretion; note in
  worklog).
- **`depth_linger_trigger.gd:7`** and the host doc-comments (`hazard_entity.gd:59, 194`;
  `bomb_hazard.gd:114`; `thrown_item.gd:14, 90`) mention the retired signal names in prose — trim to the
  generic framing as the design's per-site recipe already directs; none is a live reference.

### Needs Director review

- **NDR-V2-1 — Three telemetry payload fields drop (OQ-1/2/3), consolidated. Recommendation: ACCEPT all
  three.** V2 removes three signal payload fields with **no in-repo consumer** (verified): `hazard_awoke.trigger`
  (a near-constant debug field on the one still-consumed signal), `throw_killed_hazard.item_id` (orphan
  signal; value still available locally), `hazard_pursuer_state.state` = patrol/chase (orphan signal;
  transition count/timing preserved via the generic `&"state"` event). None can be preserved without an
  `opposition_event` arity change, which the breakdown explicitly forbids ("signal count only shrinks,
  arity frozen"). Any future need is served by a **new generic `event` string**, not a legacy-signal
  revival. **These are the only observable telemetry-shape changes in V2**; they will appear as
  `DESIGN_DEVIATIONS.md` entries at the Wave-2 close-out sweep for the Director's formal disposition.
  The resolver's recommendation is **accept all three** — the debt-paydown value (three orphan/near-dead
  fields gone, single-family telemetry) outweighs preserving unconsumed data. *If the Director wants any
  one field kept, the sanctioned mechanism is a new `event` string in a follow-up task, NOT keeping the
  legacy signal — keeping any single legacy signal would forfeit the version's "one opposition family"
  thesis.*

> **Everything else in OQ-1…OQ-7 is resolved on technical/design merit and requires no Director call.**
> With NDR-V2-1 noted for the close-out sweep, this design is **locked** for the build agent.
