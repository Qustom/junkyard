# TEL — Telemetry: config marking + per-opposition events

**Milestone:** M1.1 — Greybox Cost Axis
**Task id:** TEL
**Assignee role:** `qa-playtest-coordinator` (telemetry contract owner)
**dependsOn:** R0 (`RunConfig` + `GameState.active_run_config`); **coordinates with** R1–R4 for their event payloads
**Touch flags:** **[EB]** — TEL is the **sole `event_bus.gd` editor for the whole M1.1 milestone** (see §4)
**Companion docs:** `M1.1_Breakdown.md` (§4 TEL, §6 wave order), `M1_Tasks/M1_As_Built.md` (§Telemetry G1/G6 — canonical), `data/run_config/run_config.gd` (`to_flat_dict()`)

> This is a **design spec**, not implementation. It defines the exact rows, signals, and pseudocode the wave-1 TEL build follows, and the contract wave-2 R1–R4 emit against.

---

## 1. Goal & design intent

M1.1 must produce telemetry that lets the re-gate (RG2/RG3) answer one question: **did the depth-scaled cost axis turn "push vs. extract" into a real, spread-out decision?** Two telemetry capabilities make that answerable and make M1.0 vs M1.1 (vs future M1.x) **directly comparable**:

1. **Config-marking — make every run a labelled experiment.** Each run records *exactly which `RunConfig` produced it* by snapshotting the flat config dict onto the `run_started` row. The all-off config reproduces M1.0 exactly, so it is the permanent in-build **control**; every opposition-on run is read against it on the same metrics. Without this, the analysis cannot attribute an outcome shift to a specific opposition or knob value.

2. **Cost-axis behavior — capture what the oppositions actually did.** Each of the four oppositions (R1–R4) emits its own event rows (awoke / caught / return-cost / exposure-crossing / penalty / branch-taken / lost-proxy) so RG2 can build per-opposition frequency funnels and correlate them with end-cause / run-length / depth distributions.

**Non-goals (hard guardrails baked into this design):**
- **Do NOT widen the locked `run_ended(reason, duration_s, depth_reached)` arity.** New dimensions ride **new rows**, never a fifth `run_ended` argument (`M1_As_Built.md` §Telemetry; `M1.1_Breakdown.md` §2).
- **The config snapshot is an additive `data` payload field — NOT a schema bump** (it rides like the existing `build` tag).
- **New end-causes (`timeout`, hazard-`death`, lost-`death`) reuse the existing `run_ended.reason` string** — no new end-cause plumbing in TEL.

---

## 2. Config-marking design

### What is added
On `run_started`, snapshot the active run's `RunConfig` flat dict onto the row's `data` under a new key `run_config`:

```
run_started.data = {
    "band_id": <String>,
    "seed":    <int>,
    "build":   <String>,                       # existing (G3)
    "run_config": active_run_config.to_flat_dict()   # NEW — additive
}
```

`RunConfig.to_flat_dict()` already exists (`data/run_config/run_config.gd`, lines 130–169) and returns a flat, JSON-safe `Dictionary` (keys = field names; values = int/float/bool/String/Array-of-float). TEL only **wires the call** — it does not author the serializer (R0 owns that).

### Why this is additive (no schema bump)
- The row **envelope** is unchanged: still `{v, ts, t_ms, run_id, session_id, type, data}` (`ENVELOPE_KEYS` untouched). The snapshot lives *inside* `data`, exactly like the existing `build` field (`M1_As_Built.md` §69: "additive payload field, **not** a schema bump; envelope unchanged").
- `SCHEMA_VERSION` (`telemetry_schema.gd`, `SCHEMA_VERSION = 1`) is the **envelope** version. Adding a `data` key on one row type does not break any consumer that reads by envelope keys (the G2 tests assert envelope structure, not `run_started` payload shape).
- **Therefore `TELEMETRY_SCHEMA_VERSION` stays at `1`** for config-marking. It is bumped **only** if a new envelope key is ever required — and **no M1.1 row requires one** (RATIFIED, §8): every new dimension across all seven opposition rows fits inside the existing `data` payload, so the envelope `{v, ts, t_ms, run_id, session_id, type, data}` carries every M1.1 row type unchanged. The bump stays reserved for a true envelope change.

### Sourcing the config
TEL reads the active config from the existing autoload surface R0 wired: `GameState.active_run_config` (confirmed present, `systems/game_state.gd` line 50, populated at `start_run`). To stay robust under headless scene runs (the same pattern `_current_depth()` already uses), resolve via `/root/GameState` and guard null — if absent or null, snapshot an **empty dict** (`{}`) so the row never crashes and the analysis can detect "config unknown."

---

## 3. New EventType constants + JSONL row schemas

Seven new opposition event types are added to `telemetry_schema.gd` (string constants, appended to `ALL_TYPES`). Each maps 1:1 to a pre-declared EventBus signal (§4). Payloads coordinate **exactly** with R1–R4's `Telemetry:` lines in `M1.1_Breakdown.md` §4.

| EventType constant | `type` string | Opposition | When emitted | `data` payload fields (type) |
|---|---|---|---|---|
| `HAZARD_AWOKE` | `hazard_awoke` | R1 | Hazard transitions dormant→awake (depth threshold reached or linger exceeded) | `depth` (int), `trigger` (String: `"depth"` \| `"linger"`) |
| `HAZARD_CAUGHT` | `hazard_caught` | R1 | Hazard reaches catch radius of player | `depth` (int), `run_t_ms` (int) |
| `RETURN_COST_INCURRED` | `return_cost_incurred` | R2 | A retreat/egress cost is applied | `depth` (int), `cost_kind` (String: `"lengthen"` \| `"decay_behind"` \| `"egress_toll"`), `magnitude` (float) |
| `EXPOSURE_CROSSED` | `exposure_crossed` | R3 | Exposure meter crosses a configured threshold level (ascending) | `level` (int), `depth` (int), `run_t_ms` (int) |
| `EXPOSURE_PENALTY` | `exposure_penalty` | R3 | A penalty fires at a crossed level | `level` (int), `penalty_kind` (String: `"speed"` \| `"vision"` \| `"clock"` \| `"none"`) |
| `NAV_BRANCH_TAKEN` | `nav_branch_taken` | R4 | Player traverses a junction with degree > 2 (a real branch choice) | `depth` (int), `junction_degree` (int) |
| `NAV_LOST_PROXY` | `nav_lost_proxy` | R4 | The chosen lost-proxy metric crosses its threshold (backtrack / no-depth-progress / revisited-cell) | `metric` (String: which proxy), `value` (float), `depth` (int) |

### Coordination notes (TEL ↔ R-tasks)
- **R1** (`M1.1_Breakdown.md` §R1 *Telemetry*): `hazard_awoke(depth, trigger)`; `hazard_caught(depth, run_t_ms)`; catch routes through existing `fail_run(&"death")` → `run_ended.reason = "death"` (no TEL change for the death itself; it rides the existing `run_ended` handler).
- **R2** (§R2): `return_cost_incurred(depth, cost_kind, magnitude)` — `cost_kind` mirrors the `r2_mechanism` enum label, **stringified**, so the log is human-readable and decoupled from the enum's int value.
- **R3** (§R3): `exposure_crossed(level, depth, run_t_ms)`; `exposure_penalty(level, penalty_kind)`; max-meter → existing `fail_run(&"timeout")` → `run_ended.reason = "timeout"` (no TEL change for the loss itself).
- **R4** (§R4): `nav_branch_taken(depth, junction_degree)`; `nav_lost_proxy(metric, value, depth)`. **RATIFIED proxy + string (§8):** R4 ships **Proxy A — time-without-depth-progress (gated on movement)**, and the `metric` string is the stable id **`"time_no_depth_progress"`** (R4 emits `StringName &"time_no_depth_progress"`; TEL stringifies to `"time_no_depth_progress"` in the row). TEL still logs it generically as `metric` + `value` (a stable id keeps the analysis robust if a later iteration swaps proxies), but for M1.1 the value is locked, so RG2 keys on a known string. `value` = `seconds_wandering` (float) at emission.

### Convention alignment with existing rows
- Payloads are **primitives only** (int/float/bool/String) so they serialize straight to JSONL — same rule as the existing `junk_picked_up` row (no node refs, no Resources).
- `depth` is stamped from the live within-band depth that **BUG2** makes real (`GameState.current_depth` / max-depth tracking). Emitters that already know the depth pass it in the signal; TEL trusts the payload value (it is the authoritative depth at the event moment).
- `run_t_ms` on `hazard_caught` / `exposure_crossed` is the **monotonic run-elapsed** value. **RATIFIED (§8): TEL stamps `run_t_ms` itself** (`Time.get_ticks_msec() - _run_t0_ms`, via `_elapsed_ms()`) for these two rows, keeping it consistent with the envelope `t_ms`. The signal still carries a `run_t_ms` arg for emitter convenience, but **TEL's value wins** — so R1/R3 may pass `0` (or any value) and the logged time is still correct. This is documented so R1/R3 don't over-engineer their timestamping.

---

## 4. EventBus signal pre-declaration (TEL is the sole `event_bus.gd` editor)

Per `M1.1_Breakdown.md` §6, **TEL pre-declares ALL opposition event signals on `main` in wave 1** as the single `event_bus.gd` edit for the whole milestone. Then wave-2 R1–R4 each only **emit** these existing signals and **never touch `event_bus.gd`** — maximum parallelism, zero collision.

### Signals TEL declares (the complete, authoritative pre-declared list)

TEL is the **sole `event_bus.gd` editor for all of M1.1**, so this is the **authoritative** list of every new signal added to `event_bus.gd` this milestone. Wave-2 agents (R1–R4) and BUG2 only **emit** these — they never edit `event_bus.gd`. The list now covers **three families**: the seven opposition telemetry signals, BUG2's `depth_changed` foundation signal, and R3's penalty-multiplier / meter signals.

```gdscript
# === M1.1 pre-declared signals (sole event_bus.gd edit, wave 1, owner = TEL) ===
# Declared centrally so wave-2 R1–R4 + BUG2 only EMIT — they never edit this file.
# Telemetry-row payloads are PRIMITIVES ONLY so Telemetry serializes straight to JSONL.

# --- R1 Pursuing / awakening hazard (telemetry rows) -------------------------
signal hazard_awoke(depth: int, trigger: StringName)
signal hazard_caught(depth: int, run_t_ms: int)

# --- R2 Costlier return trip (telemetry row) ---------------------------------
signal return_cost_incurred(depth: int, cost_kind: StringName, magnitude: float)

# --- R3 Rising instability / exposure meter (telemetry rows) -----------------
signal exposure_crossed(level: int, depth: int, run_t_ms: int)
signal exposure_penalty(level: int, penalty_kind: StringName)

# --- R4 Maze / navigation risk (telemetry rows) ------------------------------
signal nav_branch_taken(depth: int, junction_degree: int)
signal nav_lost_proxy(metric: StringName, value: float, depth: int)

# --- Within-band depth (BUG2 emits from GameState; TEL declares here) ---------
# Edge-triggered: GameState emits only when the player crosses into a piece of a
# different depth_index. depth_index = current within-band depth (entry == 0);
# max_depth = deepest reached this run. Both ints (JSONL-clean).
signal depth_changed(depth_index: int, max_depth: int)

# --- R3 penalty / meter signals (R3 emits; TEL declares; not telemetry rows) --
# These let R3 apply speed/vision/clock penalties + drive the HUD WITHOUT editing
# game_state.gd. Signatures per R3 spec (R3_exposure_meter.md §3.3, §6).
signal exposure_speed_mult_changed(mult: float)   # player multiplies into stats.max_speed
signal exposure_vision_mult_changed(mult: float)  # R4 fog node multiplies into radius (no-op if R4 off)
signal exposure_clock_tax(seconds: float)         # A3 dive-clock subtracts from remaining light
signal exposure_meter_changed(value: float, maximum: float)  # greybox HUD exposure bar reads this
```

### Ownership of `depth_changed` — RATIFIED: TEL declares, BUG2 emits
**Decision (Director-ratified 2026-06-19):** `depth_changed(depth_index, max_depth)` is **declared by TEL** in its single wave-1 `event_bus.gd` pass and **emitted by BUG2** from `game_state.gd`. This makes `event_bus.gd` have **exactly one author** across all of M1.1 — no sequencing constraint between the BUG1+BUG2 `game_state.gd` pass and TEL's `event_bus.gd` pass, and zero collision with the wave-2 fan-out. BUG1/BUG2 still own their `game_state.gd` changes; they only *emit* the already-declared signal. (Confirms BUG2 spec §3 / Open question #3 and R3 spec's subscribe contract.)

### Pre-declared-signal table — exact signatures + which task emits each

| Signal (on `EventBus`) | Exact signature | Emitted by | Consumed by | Kind |
|---|---|---|---|---|
| `hazard_awoke` | `(depth: int, trigger: StringName)` | **R1** | TEL row `hazard_awoke` | telemetry |
| `hazard_caught` | `(depth: int, run_t_ms: int)` | **R1** | TEL row `hazard_caught` | telemetry |
| `return_cost_incurred` | `(depth: int, cost_kind: StringName, magnitude: float)` | **R2** | TEL row `return_cost_incurred` | telemetry |
| `exposure_crossed` | `(level: int, depth: int, run_t_ms: int)` | **R3** | TEL row `exposure_crossed` | telemetry |
| `exposure_penalty` | `(level: int, penalty_kind: StringName)` | **R3** | TEL row `exposure_penalty` | telemetry |
| `nav_branch_taken` | `(depth: int, junction_degree: int)` | **R4** | TEL row `nav_branch_taken` | telemetry |
| `nav_lost_proxy` | `(metric: StringName, value: float, depth: int)` | **R4** | TEL row `nav_lost_proxy` | telemetry |
| `depth_changed` | `(depth_index: int, max_depth: int)` | **BUG2** (`GameState.set_current_depth_index`) | R1–R4 (push), HUD; **not** a TEL row (see below) | foundation |
| `exposure_speed_mult_changed` | `(mult: float)` | **R3** | player (`entities/player/player.gd` multiplies `stats.max_speed`) | penalty |
| `exposure_vision_mult_changed` | `(mult: float)` | **R3** | R4 fog node (no-op if R4 off) | penalty |
| `exposure_clock_tax` | `(seconds: float)` | **R3** | A3 dive-clock system | penalty |
| `exposure_meter_changed` | `(value: float, maximum: float)` | **R3** | greybox exposure-bar HUD (ui-ux) | HUD projection |

> **Signature note (R3 cross-reference).** The penalty/meter signatures above are taken verbatim from `R3_exposure_meter.md` (§3.3 seams + §6 pseudocode): `exposure_speed_mult_changed(mult)`, `exposure_vision_mult_changed(mult)`, `exposure_clock_tax(seconds)`, `exposure_meter_changed(value, maximum)`. R3's doc and this doc name them identically — no aliasing needed. If R3's implementation diverges at brief time, **this table is authoritative** (TEL owns `event_bus.gd`); reconcile by updating R3, not by editing `event_bus.gd` twice.

### TEL listener for `depth_changed` — RATIFIED: no dedicated per-change row
**Decision (Director-ratified 2026-06-19):** TEL does **not** add a `depth_changed` listener that writes a dedicated per-depth-change row. Rationale: the existing `band_depth_reached` (new-max-depth) row already captures the funnel-defining moments the M1.1 depth analysis needs, and a per-change row would be noisy (every spine-piece crossing). TEL stamps `depth` onto opposition rows from their payloads, and BUG2 already feeds the honest max into `run_ended.depth_reached`, so the depth funnel is covered without a new row.

> **Cross-reference (BUG2 §6 / Q5):** BUG2's spec floats an optional `DEPTH_CHANGED` row + switching TEL's `_current_depth()` to `current_depth_index`. The first (the new row) is **declined** by this decision. The second (depth-tagging accuracy on existing pickup/bank rows) is a separate flagged follow-up tracked under BUG2's Q5, not part of this TEL spec.

---

## 5. Pseudocode

### 5a. Config snapshot on `run_started` (edit existing `_on_run_started`)

```gdscript
func _on_run_started(band_id: StringName, seed: int) -> void:
    _run_t0_ms = Time.get_ticks_msec()
    _run_id = "r_" + _short_id(seed)
    _accepted_value = 0
    _last_banked = 0
    _max_depth = 0
    _emit_row(Schema.RUN_STARTED, {
        "band_id": String(band_id),
        "seed": seed,
        "build": BuildVersionScript.id(),
        "run_config": _active_run_config_dict(),   # NEW — additive, no schema bump
    })


# Resolve the active RunConfig's flat dict from GameState (R0's read surface).
# Robust under headless scene runs (same /root lookup pattern as _current_depth);
# empty dict if absent so the row never crashes and "config unknown" is detectable.
func _active_run_config_dict() -> Dictionary:
    var gs := get_node_or_null("/root/GameState")
    if gs != null and gs.active_run_config != null:
        return gs.active_run_config.to_flat_dict()
    return {}
```

### 5b. Opposition listeners (new constants + handlers; subscribe in `_ready`)

```gdscript
# --- add to _ready(), after the existing connects -----------------------------
EventBus.hazard_awoke.connect(_on_hazard_awoke)
EventBus.hazard_caught.connect(_on_hazard_caught)
EventBus.return_cost_incurred.connect(_on_return_cost_incurred)
EventBus.exposure_crossed.connect(_on_exposure_crossed)
EventBus.exposure_penalty.connect(_on_exposure_penalty)
EventBus.nav_branch_taken.connect(_on_nav_branch_taken)
EventBus.nav_lost_proxy.connect(_on_nav_lost_proxy)


# --- R1 ----------------------------------------------------------------------
func _on_hazard_awoke(depth: int, trigger: StringName) -> void:
    _emit_row(Schema.HAZARD_AWOKE, {"depth": depth, "trigger": String(trigger)})

func _on_hazard_caught(depth: int, _run_t_ms: int) -> void:
    # TEL stamps run-elapsed itself for consistency with envelope t_ms.
    _emit_row(Schema.HAZARD_CAUGHT, {"depth": depth, "run_t_ms": _elapsed_ms()})
    if _writer != null: _writer.flush()   # high-value: precedes a death run_ended

# --- R2 ----------------------------------------------------------------------
func _on_return_cost_incurred(depth: int, cost_kind: StringName, magnitude: float) -> void:
    _emit_row(Schema.RETURN_COST_INCURRED,
        {"depth": depth, "cost_kind": String(cost_kind), "magnitude": magnitude})

# --- R3 ----------------------------------------------------------------------
func _on_exposure_crossed(level: int, depth: int, _run_t_ms: int) -> void:
    _emit_row(Schema.EXPOSURE_CROSSED, {"level": level, "depth": depth, "run_t_ms": _elapsed_ms()})
    if _writer != null: _writer.flush()   # threshold crossing = funnel-defining

func _on_exposure_penalty(level: int, penalty_kind: StringName) -> void:
    _emit_row(Schema.EXPOSURE_PENALTY, {"level": level, "penalty_kind": String(penalty_kind)})

# --- R4 ----------------------------------------------------------------------
func _on_nav_branch_taken(depth: int, junction_degree: int) -> void:
    _emit_row(Schema.NAV_BRANCH_TAKEN, {"depth": depth, "junction_degree": junction_degree})

func _on_nav_lost_proxy(metric: StringName, value: float, depth: int) -> void:
    _emit_row(Schema.NAV_LOST_PROXY, {"metric": String(metric), "value": value, "depth": depth})


# small helper (run-elapsed ms, same basis as envelope t_ms)
func _elapsed_ms() -> int:
    return Time.get_ticks_msec() - _run_t0_ms
```

**Opt-in is unchanged.** Every row goes through the existing `_emit_row`, which short-circuits when `_enabled` is false (`telemetry.gd` line 85). So "opposition disabled → no rows" falls out naturally: a disabled opposition (`rN_enabled = false`) never *emits* its signal, so TEL writes nothing for it — no special-casing in TEL. With telemetry consent OFF, nothing writes at all.

**Log-verbosity — RATIFIED (§8): log every event, no per-opposition sampling for M1.1.** TEL writes one row per emitted signal with **no throttle/sampling toggle**. Per-run event volume is tiny (tens-to-low-hundreds of lines), flushes are effectively free, and RG2 wants **complete** funnels to build per-opposition frequency curves. R4's own `nav_lost_proxy` is already rate-limited at the *emitter* (§3 / R4 spec: one row per `r4_lost_proxy_threshold` seconds of a lost-episode), so the highest-frequency stream is bounded at source without a TEL-side sampler. Sampling is **deferred** to a later milestone if a log ever grows painful; it is explicitly **not** built now.

---

## 6. Files to touch

| File | Change | Owner |
|---|---|---|
| `systems/event_bus.gd` | **Add all twelve M1.1 signals** (§4) in one block (the milestone's single `event_bus.gd` edit): the **seven opposition telemetry signals** + **`depth_changed`** (BUG2 emits) + R3's **four penalty/meter signals** (`exposure_speed_mult_changed`, `exposure_vision_mult_changed`, `exposure_clock_tax`, `exposure_meter_changed`). No other agent touches this file all milestone. | TEL (wave 1) |
| `systems/telemetry/telemetry_schema.gd` | Add seven `EventType` string constants (`HAZARD_AWOKE` … `NAV_LOST_PROXY`); append them to `ALL_TYPES`. **No** `SCHEMA_VERSION` bump. **No** `ENVELOPE_KEYS` change. (Optionally extend `RUN_END_CAUSES` doc-comment to note `timeout`/`death` reuse for new opposition causes — `RUN_END_CAUSES` already lists both, so no code change needed.) | TEL |
| `systems/telemetry/telemetry.gd` | Wire `run_config` snapshot into `_on_run_started`; add `_active_run_config_dict()` + `_elapsed_ms()` helpers; connect + handle the seven new signals (§5). | TEL |
| `tests/test_telemetry_config_marking.gd` (new) | GdUnit4 (or headless-script) test: assert `run_started` row carries `data.run_config` with the expected flat keys; assert each opposition row type is in `ALL_TYPES`, has the envelope keys, and a parseable payload; assert envelope `v == 1` (no bump) and `ENVELOPE_KEYS` unchanged. Use the autoload-free `JsonlWriter` seam where possible (autoloads don't resolve under `--headless --script`; `M1_As_Built.md` testing constraint). | TEL |
| `tools/ci_smoke_test.gd` | No change required, but verify it still boots green after the `event_bus.gd` + schema additions (parse-error gate). | TEL (verify) |

**Files TEL does NOT touch:** `game_state.gd` (R0's `active_run_config` + BUG2's depth are the read surface; TEL only reads), and any opposition system (R1–R4 emit; TEL listens).

---

## 7. Acceptance criteria

Restated from `M1.1_Breakdown.md` §4 (TEL), made checkable:

1. A completed run's JSONL **`run_started` row carries the full config snapshot** under `data.run_config` (all `RunConfig.to_flat_dict()` keys present, values correct for the run's config).
2. **With an opposition enabled**, its event rows appear in the log (e.g. R1 on → `hazard_awoke` / `hazard_caught` rows present); **with it disabled, they do not** (no row for a disabled opposition's events).
3. **`run_ended` arity is unchanged** — still `(reason, duration_s, depth_reached)`; no fifth argument; the row's `data` shape is the M1.0 one. New end-causes (`timeout`, hazard-`death`, lost-`death`) appear as the existing `run_ended.reason` string, not new plumbing.
4. **Schema version handled correctly:** envelope `v` stays `1`; `ENVELOPE_KEYS` unchanged; the config snapshot and opposition rows are additive (`data` payloads + new `type` strings), proving config-marking required no envelope bump.
5. **Opt-in unchanged:** consent OFF → nothing written (including all new rows); the consent flow is untouched.
6. A test (§6) verifies the `run_started.run_config` snapshot and the seven new row types/envelopes; the headless CI smoke test stays green after the `event_bus.gd`/schema additions.

---

## 8. Resolved Decisions (Director-ratified 2026-06-19 — apply-all-recommendations)

The Director ruled: **adopt every recommendation in the former "Open questions" section as a ratified decision.** Each below is now committed and propagated into the body (§2–§6). These are no longer open.

1. **`depth_changed` declaration ownership.** **Decision: TEL declares `depth_changed(depth_index, max_depth)`** in its single wave-1 `event_bus.gd` pass; BUG2 only emits it from `game_state.gd`. *Rationale:* makes `event_bus.gd` a single-author file across all of M1.1 — no sequencing constraint, zero collision with the wave-2 fan-out. (Propagated: §4 signal list + table; §6 files-to-touch.)
2. **TEL listener for `depth_changed`.** **Decision: do NOT add a dedicated per-depth-change row;** reuse the existing `band_depth_reached` (new-max-depth) row. *Rationale:* the existing row already captures the funnel-defining new-max moments; a per-change row is noisy. (Propagated: §4 "TEL listener" subsection. BUG2's optional `DEPTH_CHANGED` row is thereby declined; its separate `_current_depth()` accuracy follow-up stays under BUG2 Q5.)
3. **R4 lost-proxy metric string.** **Decision: Proxy A (time-without-depth-progress, movement-gated), metric id `"time_no_depth_progress"`.** *Rationale:* cheapest correct proxy, ties straight to the gate metric (clock burned vs. depth gained); a stable string id lets RG2 key on a known value and survives a future proxy swap. (Propagated: §3 coordination notes.)
4. **Per-opposition log-verbosity flag.** **Decision: log every event for M1.1 — no sampling/throttle toggle in TEL.** *Rationale:* per-run volume is tiny, flushes are free, RG2 wants complete funnels; R4's high-frequency stream is already rate-limited at the emitter. Sampling deferred. (Propagated: §5 opt-in subsection.)
5. **Envelope key / schema bump.** **Decision: no new ENVELOPE key, `TELEMETRY_SCHEMA_VERSION` stays `1`.** *Rationale:* every new dimension fits inside the existing `data` payload; the envelope carries all M1.1 row types unchanged; the bump stays reserved for a true envelope change. (Propagated: §2 "Why this is additive".)
6. **`run_t_ms` authority on `hazard_caught` / `exposure_crossed`.** **Decision: TEL stamps `run_t_ms` itself** (`_elapsed_ms()`, consistent with envelope `t_ms`); the signal's `run_t_ms` arg is emitter-convenience only and TEL's value wins (R1/R3 may pass `0`). *Rationale:* one authoritative time basis, no emitter timestamp coupling. (Propagated: §3 convention note; §5 handlers already implement it.)
