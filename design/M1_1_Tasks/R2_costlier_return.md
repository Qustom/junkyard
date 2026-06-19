# R2 — Costlier Return Trip (expanded design spec)

**Milestone:** M1.1 (Greybox Cost Axis) · **Workstream:** (b) the four opposition systems · **Wave:** 2 (parallel worktree)
**Author role:** game-director-designer · **Builder role:** general-purpose (the programmer)
**Status:** spec — ready for dispatch · **all §9 design decisions Director-ratified 2026-06-19** (the programmer builds against this; this doc sets the contract, not the internals)
**dependsOn:** `R0` (RunConfig), `BUG2` (live within-band depth), `TEL` (pre-declared `return_cost_incurred` signal)
**Companions:** `M1.1_Breakdown.md` §2/§4/§6 · `M1_As_Built.md` (canonical APIs) · `B3_band_depth_structure.md` (depth geometry) · `data/run_config/run_config.gd` (the R2 knobs, already authored)

> **Greybox / configurable-not-balanced (M1.1 §2):** R2 is a throwaway-grade prototype to test whether *the way back having a price* makes "one more room?" a real gamble. Acceptance is **"the knob exists and takes effect,"** not "the value is right." All numbers below are starting points the Director sweeps in the Config menu, not balance claims.

---

## 1. Goal & design intent

**Intent (one sentence):** *deeper pushes cost more to undo* — kill the free "fill inventory then stroll to the gate" by putting a depth-scaled price on the return trip.

M1.0's degeneracy (`G4 = ITERATE`): with a reward axis (B3: deeper = better junk) and **no cost axis**, the dominant strategy is "push to the end, then walk back and extract" — there is no decision because retreat is free. R2 is the most *literal* counter: it makes the retreat itself scale with how far you went. The deeper you are, the more it costs (in time, exposure, or a dedicated meter) to get home, so the marginal "one more room" now trades a known extra reward against a known extra exit-cost, and "I should turn back now" becomes a felt moment instead of a non-choice.

R2 is the **economic/clock-pressure** sibling of R1 (a chaser, spatial threat) and R3 (a lingering meter): R1 punishes *being deep* with a pursuer, R3 punishes *lingering* with a rising meter, R2 punishes *the act of having gone deep and now needing to come back*. It is the only opposition whose cost is incurred specifically **on retreat**, which is what makes the last-room decision sharp.

**What R2 must NOT be:** not a soft-lock generator (the player must always be able to reach the gate; see §9), not a second exposure system (it may *tax* R3-style resources but owns no meter of its own unless `meter` is selected), not a balance pass.

---

## 2. Mechanism design — the three `r2_mechanism` options

`r2_mechanism` is an enum already authored in `RunConfig`: `0 = lengthen`, `1 = decay_behind`, `2 = egress_toll`. Exactly **one** mechanism is active per run (the Director picks it in the Config menu). All three read B3's real `dist_to_gate` (reverse-BFS on `PlacedPiece`, survives branching — `M1_As_Built.md`) as the "how deep to undo" measure, and gate on `r2_depth_threshold`.

> **Ratified (Director 2026-06-19, §9 Decision 1):** **`egress_toll` is the primary, fully-built mechanism.** `decay_behind` ships as a secondary behind the reachability guard; `lengthen` ships as an alias into the `egress_toll` cost path. All three share **one** cost engine. The decision detail and rationale live in §9; the subsections below build to it.

### Mechanism 0 — `lengthen` (the return path gets longer)

**Concept:** the trip home is physically longer than the trip in, scaling with the deepest point reached. Conceptually "the yard rearranges behind you."

**Greybox realization (recommended, cheapest):** R2 does **not** regenerate geometry mid-run (that would fight B2/B3 determinism and risk soft-locks). Instead, `lengthen` is modeled as a **return-distance multiplier applied to the egress-toll path length** — i.e. it is a *degenerate parameterization of `egress_toll`* where the taxed quantity is "extra distance" expressed as the same clock/exposure/meter tax, but the per-depth curve is interpreted as "the path felt `k×` longer." In greybox we cannot cheaply make the player physically walk farther without regenerating the band, so `lengthen` resolves to: **on retreat, charge a toll equal to the cost of the *extra* simulated distance** (`(multiplier − 1) × dist_to_gate × per-depth cost`). 

> **Ratified (§9 Decision 1):** `lengthen` is **the lowest-priority mechanism for the prototype** and ships as an **alias that routes into the `egress_toll` cost path** with a distance-multiplier framing. A truthful "the path is physically longer" requires either a mid-run generator mutation (soft-lock risk, determinism cost, out of greybox scope) or a fake indistinguishable from `egress_toll` with a steeper curve, so a *true* path-lengthening is deferred to **M2+** as a generator feature, not an M1.1 greybox prototype.

### Mechanism 1 — `decay_behind` (links past a depth collapse behind you)

**Concept:** once you push past `r2_depth_threshold`, the connections you came through start to **decay** — the path behind you collapses, so you cannot simply reverse your steps; you may have to find a *different* (longer, or branch) route back, or you lose the cheapest route home. This is the "burning bridges" push-your-luck flavor: going deep is a one-way-ish commitment.

**Greybox realization:** R2 marks the **mated socket links** the player has traversed past the threshold as "decaying," and after a delay (or immediately on leaving the piece) flips them to **one-way** (passable inbound-deeper, blocked outbound-shallow) or removes them. The player's walkable graph back toward the gate loses those edges; `dist_to_gate` for the player's current piece is **recomputed** against the surviving graph, so the return distance can jump up (and the egress cost with it, if combined) or force a detour.

**Hard constraint (ratified, non-negotiable — §9 Decision 2):** **the gate must remain reachable from every piece the player can occupy.** This is a **required** mandatory gate-reachability/soft-lock guard, not an option. `decay_behind` may only collapse a link if, *after* collapse, a path to `band.entry_piece` still exists from the player's current piece. This is a reachability check (reverse-BFS from gate over the surviving graph) run **before** committing any collapse; if collapsing would orphan the player, the collapse is **skipped** (downgraded to a toll). On the **linear M1.0 spine** (`branch_chance = 0.0`) there is only one path home, so `decay_behind` would *always* orphan the player — therefore **`decay_behind` requires R4's branching to be meaningful** (multiple routes home). With R4 off / linear, `decay_behind` self-downgrades to a no-op-collapse + `egress_toll` (charge the cost, but never actually sever the only path). This dependency is called out in §7 and §9.

> **Ratified (§9 Decision 1 + 2):** `decay_behind` is the most *thematically* on-point ("deeper = harder to undo, literally") but the most coupled (needs R4 branching to not be a pure toll). It **ships behind the required reachability guard and the linear-spine self-downgrade**, and is the *second* mechanism the Director sweeps after `egress_toll` proves the axis.

### Mechanism 2 — `egress_toll` (per-depth cost on retreat) — RECOMMENDED PRIMARY

**Concept:** retreating *charges a resource cost that scales with `dist_to_gate`*. No geometry changes, no soft-lock surface, fully deterministic, reads B3's existing distance directly. This is the cleanest expression of "deeper costs more to undo" and the one that most directly tests the design hypothesis.

**What it taxes — `r2_toll_resource` (enum already authored: `0 = clock`, `1 = exposure`, `2 = meter`):**

- **`0 = clock` — the ratified default `r2_toll_resource` (§9 Decision 3).** The toll drains the **dive clock** (the `DiveClock` "light" resource, A3). Retreating from deep burns light, so a deep grab can *time you out on the way home* (`run_ended.reason = timeout` via the existing `dive_clock_timeout` → `fail_run(&"timeout")` path). This is the most legible: the clock is already on-screen (E2 HUD), already the run's master pressure, and the player already reads "running out of light = bad." Routes through the **existing public surface `DiveClock.modify_light(-cost)`** (the A3 method is explicitly "left wired but unused by M1 gameplay so descending-costs-light / extract-refuels can drop in later without touching the core loop" — R2 is exactly that drop-in). **No `event_bus.gd` / `game_state.gd` edit needed.**

- **`1 = exposure`** — the toll raises **exposure**. **Ratified (§9 Decision 4 + 5):** selecting `exposure` **requires R3 enabled**, and the toll **adds to R3's run-state meter** (a shared pool — pushing R3 toward its next threshold/penalty, a deliberate compounding the re-gate observes). R2 does **NOT** write meta `GameState.add_exposure()` for this throwaway per-run prototype (meta exposure persists and would contaminate the comparable-baseline control). If `exposure` is selected with R3 disabled, that is a misconfiguration: the build requires R3 enabled rather than falling back to meta.

- **`2 = meter`** — the toll fills a **dedicated R2-owned run-state "egress debt" meter** that R2 creates and owns (disposable per dive). When the meter crosses a cap, R2 inflicts its own loss (`fail_run(&"timeout")`, reusing the existing end-cause vocabulary). This is the most self-contained (no dependency on R3 or the clock) but adds a HUD readout R2 must stub. **Ratified:** `meter` is the **isolated-study fallback** the Director uses to study R2 apart from clock/exposure; the default is `clock`.

> **Ratified (which ships — §9 Decisions 1 + 3):** **`egress_toll` is the primary, fully-built mechanism, with `clock` as the default toll resource.** It is deterministic, soft-lock-free, reads B3's `dist_to_gate` directly, taxes a resource the player already watches, and routes entirely through existing public surfaces (`DiveClock.modify_light`). `decay_behind` ships as a secondary behind the required reachability guard (most thematic, needs R4). `lengthen` ships as an alias into the `egress_toll` cost path (a steeper-curve framing); true path-lengthening is deferred to M2+. This gives the Director three selectable behaviors with **one** robust cost engine underneath, matching the "configurable, not balanced" guardrail.

---

## 3. Depth-scaling — the cost curve

The cost incurred on a retreat event is a function of the player's current return distance and the configured curve. Let:

- `d` = `dist_to_gate` of the **piece the player is currently in** (B3, reverse-BFS, integer hops; survives branching). This is "how deep to undo" — it shrinks as the player approaches the gate.
- `thr` = `r2_depth_threshold` (below this depth, retreat is free — early rooms stay cheap so shallow runs feel like M1.0).
- `mag` = `r2_cost_magnitude` (flat component once past threshold).
- `per` = `r2_cost_per_depth` (additive cost per hop of return distance).

**Core cost formula (the taxable quantity for `egress_toll` / `lengthen`):**

```
effective_depth = max(0, d - thr)          # only depth beyond the threshold is taxed
cost(d) = (mag + per * effective_depth)     if d > thr
        = 0                                  otherwise
```

So at `d == thr+1` the cost is `mag + per`; at the deepest point it is `mag + per*(d-thr)`. Retreating from depth `d` is strictly more expensive than retreating from depth `1` (for `1 ≤ thr < d`), satisfying acceptance. With `thr = 0`, every retreat hop past the gate is taxed.

**How the cost is *metered out* — ratified marginal-per-hop (§9 Decision 6):** R2 charges **incrementally, once per depth-decrease event** (each time the player's `dist_to_gate` drops by 1 — i.e. each hop closer to home), charging `marginal_cost = per` for that hop plus `mag` once on the first taxed retreat of the run. This makes the *total* paid over a full retreat ≈ `mag + per * (d_max_reached - thr)` — proportional to how deep they went — while keeping each event small and telemetered, and **felt as the player walks home** (the clock visibly bleeding on the way back is the tension, and can time the player out mid-retreat). There is **no** lump-at-gate charge (a gate-lump would be a surprise tax that cannot inform the mid-retreat decision). (Charging the whole `cost(d)` lump every hop would over-charge quadratically; charge the **marginal** `per` per hop, `mag` once.) See the pseudocode in §5 for the exact accounting.

**`decay_behind` scaling:** the curve instead governs *how many links past the threshold decay* and/or *after what delay*. Greybox mapping: `effective_depth` links behind the player (the ones at `dist_to_gate > thr`) become decay candidates; `mag`/`per` tune the decay delay (higher = faster collapse). When a decay forces a longer route, `dist_to_gate` is recomputed and — if `decay_behind` is combined with a toll — the new larger `d` feeds `cost(d)` naturally.

> All four scalars are `RunConfig` `@export`s the Config menu surfaces; the curve is **linear** for the prototype (slope `per`, intercept `mag`). A `Curve`-resource shape (à la B3's `DepthCurve`) is deliberately **out of scope** for M1.1 — linear-with-threshold is enough to find starve/flood points; promote to a `Curve` only if the re-gate says the axis works and needs shaping.

---

## 4. Telemetry

R2 emits **`return_cost_incurred(depth, cost_kind, magnitude)`** on each retreat-cost event. This signal is **pre-declared on `event_bus.gd` by TEL in wave 1** (M1.1 §6) — **R2 only emits it; R2 must NOT edit `event_bus.gd`.** Match TEL's declared arity exactly.

| Param | Type | Meaning |
|---|---|---|
| `depth` | `int` | the player's `dist_to_gate` at the moment of the charge (the "how deep to undo" value `d`) |
| `cost_kind` | `StringName` | which resource was taxed / which mechanism fired: `&"clock"`, `&"exposure"`, `&"meter"`, or `&"decay"` (for a `decay_behind` link collapse) |
| `magnitude` | `float` | the amount charged this event (the marginal cost, or for `decay` the number of links collapsed / `1.0` per collapse) |

**Emission points:**
- `egress_toll` / `lengthen`: one row per depth-decrease event that incurs a charge (i.e. `cost > 0` and `d` decreased). `cost_kind` = the selected toll resource.
- `decay_behind`: one row per link-collapse with `cost_kind = &"decay"`, `magnitude = links_collapsed`; if combined with a toll, the toll rows fire separately as above.
- **No row when R2 is off, below threshold, or when no charge applies** — so `return_cost_incurred` presence in the JSONL is itself a clean per-config signal (RG2 reads it to confirm the axis fired).

This rides a **new `EventType` row** (TEL adds the constant); it does **not** widen the locked `run_ended(reason, duration_s, depth_reached)` arity. When R2 ends a run (toll-induced timeout, or `meter` cap), it routes through the **existing** `fail_run(&"timeout")` so the end-cause uses the existing `run_ended.reason` vocabulary — no new end-cause string needed.

**Suggested analysis hooks for RG2 (not required of R2):** total `return_cost_incurred.magnitude` per run vs `depth_reached`; fraction of runs that timed out *during retreat* (clock toll); correlation of toll resource with end-cause distribution.

---

## 5. Pseudocode

A small **run-state** system, `systems/oppositions/return_cost.gd` (`class_name ReturnCost extends Node`), created per dive (like `DiveClock`), reset by `run_started`, torn down by `run_ended`. It reads `GameState.active_run_config` (R0), the live within-band depth surface (BUG2), and B3's `dist_to_gate`. It writes only through **existing public surfaces** (`DiveClock.modify_light`, R3's run-state meter API, or its own dedicated meter) and emits the pre-declared signal. Per §9 Decision 4, the `exposure` toll uses R3's shared run-state meter and **never** writes meta `GameState.exposure`.

```gdscript
class_name ReturnCost
extends Node
## R2 — Costlier return trip. RUN-STATE node (TDD §2), created/destroyed per dive.
## Reads RunConfig (R0) + live depth (BUG2) + dist_to_gate (B3). Edits NO autoload
## source files: routes cost through existing public surfaces, emits pre-declared
## EventBus.return_cost_incurred (declared by TEL). PROCESS_MODE_PAUSABLE so it
## freezes with the tree like DiveClock.

@export var dive_clock: DiveClock        # injected by the dive scene for the `clock` toll

var _cfg: RunConfig
var _active := false
var _charged_flat := false               # `mag` is charged once per run, on first taxed retreat
var _last_d := -1                        # last observed dist_to_gate (to detect retreat = d decreasing)
var _deepest_taxed := 0                  # bookkeeping for analysis
var _meter := 0.0                        # only used when toll_resource == meter
var _meter_cap := 100.0                  # greybox cap for the dedicated meter

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE
    EventBus.run_started.connect(_on_run_started)
    EventBus.run_ended.connect(_on_run_ended)
    # BUG2 supplies live depth via EventBus.depth_changed(depth_index, max_depth);
    # but R2 keys off dist_to_gate (return distance), read from the player's piece.
    EventBus.depth_changed.connect(_on_depth_changed)

func _on_run_started(_band_id := &"", _seed := 0) -> void:
    _cfg = GameState.active_run_config
    _active = _cfg != null and _cfg.r2_enabled
    _charged_flat = false
    _last_d = -1
    _deepest_taxed = 0
    _meter = 0.0

func _on_run_ended(_reason := &"", _duration_s := 0.0, _depth_reached := 0) -> void:
    _active = false

## Driven by BUG2's depth_changed. We translate the player's current piece into a
## return distance d via B3's dist_to_gate, then detect retreat (d decreased).
func _on_depth_changed(_depth_index: int, _max_depth: int) -> void:
    if not _active:
        return
    var d := _current_dist_to_gate()      # B3 reverse-BFS value of the player's piece
    if _last_d < 0:
        _last_d = d
        return
    if d < _last_d:                        # RETREAT: moved one (or more) hops toward the gate
        var hops := _last_d - d
        _apply_retreat_cost(d, hops)
    elif d > _last_d and _cfg.r2_mechanism == RunConfig.R2_DECAY_BEHIND:
        _maybe_decay_links_behind(_last_d)  # pushed deeper past threshold → arm decay
    _last_d = d

func _apply_retreat_cost(d: int, hops: int) -> void:
    var thr := _cfg.r2_depth_threshold
    # Only depth beyond the threshold is taxed. We charge per-hop marginal `per`,
    # for hops that were above the threshold, plus `mag` once.
    var taxed_hops := 0
    for step in range(hops):
        var hop_d := d + hops - step       # the dist_to_gate the hop departed from
        if hop_d > thr:
            taxed_hops += 1
    if taxed_hops == 0:
        return
    var cost := _cfg.r2_cost_per_depth * float(taxed_hops)
    if not _charged_flat:
        cost += _cfg.r2_cost_magnitude
        _charged_flat = true
    if cost <= 0.0:
        return
    _deepest_taxed = max(_deepest_taxed, d + hops)
    _charge(d, cost)

## Route the charge through the selected resource — ALL via existing public surfaces.
func _charge(d: int, cost: float) -> void:
    match _cfg.r2_toll_resource:
        RunConfig.R2_TOLL_CLOCK:
            if dive_clock != null:
                dive_clock.modify_light(-cost)   # A3's public mutator; may trigger timeout
            EventBus.return_cost_incurred.emit(d, &"clock", cost)
        RunConfig.R2_TOLL_EXPOSURE:
            # Ratified (§9 Decisions 4+5): `exposure` REQUIRES R3 enabled and adds to
            # R3's SHARED run-state meter. NO meta GameState.add_exposure() fallback
            # (meta persists and would contaminate the comparable baseline). If R3 is
            # absent here, that is a misconfiguration — the build gates `exposure` on R3.
            if _r3_meter() != null:
                _r3_meter().add(cost)
            EventBus.return_cost_incurred.emit(d, &"exposure", cost)
        RunConfig.R2_TOLL_METER:
            _meter += cost
            EventBus.return_cost_incurred.emit(d, &"meter", cost)
            if _meter >= _meter_cap:
                GameState.fail_run(&"timeout")   # existing end-cause vocabulary

## decay_behind: collapse traversed links past the threshold, but ONLY if the gate
## stays reachable from the player's current piece afterward (no soft-lock).
func _maybe_decay_links_behind(prev_d: int) -> void:
    if prev_d <= _cfg.r2_depth_threshold:
        return
    var link := _link_player_just_crossed()
    if link == null:
        return
    if _gate_reachable_without(link):        # reverse-BFS from gate over surviving graph
        _collapse_link(link)                 # flip to one-way / remove; recompute dist_to_gate
        EventBus.return_cost_incurred.emit(prev_d, &"decay", 1.0)
    # else: skip the collapse (linear spine self-downgrade) — never orphan the player.
```

**Key detection note:** "retreating" = the player's `dist_to_gate` **decreasing**. We deliberately key off **`dist_to_gate` (return distance)**, not raw `depth_index`, because on a branching layout (R4) a player can decrease `depth_index` while *increasing* return distance (wrong branch) — `dist_to_gate` is the true "am I getting closer to home" measure and is exactly B3's reverse-BFS value. BUG2's `depth_changed` is the *trigger* (the player entered a new piece); R2 re-reads `dist_to_gate` of the new piece to decide if that was a retreat. (If BUG2's surface exposes `dist_to_gate` directly per-change, R2 reads it from there; otherwise it reads the player's current `PlacedPiece.dist_to_gate`. Coordinate the exact read with BUG2 at build time — see §7.)

---

## 6. Config defaults recommendation

**All-off default (`RunConfig.new()` / the default `.tres`) — already correct in R0:**
```
r2_enabled        = false   # → walk-back is free; loop == M1.0 baseline
r2_mechanism      = 0 (lengthen)   # inert while disabled
r2_cost_magnitude = 0.0
r2_cost_per_depth = 0.0
r2_depth_threshold= 0
r2_toll_resource  = 0 (clock)
```

**Suggested first sweep set (Director tunes these in the Config menu; starting points, not balance):**

| Sweep | mechanism | toll_resource | magnitude | per_depth | threshold | Tests |
|---|---|---|---|---|---|---|
| **S1 — clock toll, gentle** | `egress_toll` | `clock` | 2.0 | 1.5 | 1 | Does a depth-scaled clock burn create retreat tension? (clock `max_light=60`, so a deep retreat from `d≈8` costs ≈ `2 + 1.5*7 = 12.5` light ≈ 21% of the bar.) |
| **S2 — clock toll, biting** | `egress_toll` | `clock` | 4.0 | 3.0 | 1 | Push toward "deep retreats can time you out on the way home." Deep retreat ≈ `4 + 3*7 = 25` light ≈ 42% of the bar. |
| **S3 — high threshold** | `egress_toll` | `clock` | 3.0 | 2.5 | 4 | Shallow rooms free; only *committed* deep dives pay. Does a free shallow zone keep early game feeling M1.0 while deep dives bite? |
| **S4 — dedicated meter** | `egress_toll` | `meter` | 5.0 | 4.0 | 1 | Study R2 in isolation from the clock; meter cap → `timeout`. |
| **S5 — decay (needs R4)** | `decay_behind` | `clock` | 2.0 | 2.0 | 3 | With R4 branching on: does burning bridges force costly detours? (linear-spine self-downgrades to toll.) |

> **Ratified starting values + sweep order (§9 Decisions 1 + 3):** these are the committed starting points (not balance claims). Start sweeps with **S1** (`egress_toll`/`clock`, the ratified primary + default), then **S2** if S1 is too weak, then **S3** to test whether a free shallow zone preserves the M1.0 feel for low-risk runs. Hold `decay_behind` (S5) until R4 branching is confirmed on `main`, since on the linear spine it self-downgrades to a plain toll. These pair naturally with R3 OFF first (isolate R2's axis), then R2+R3 stacked once each is understood (the R2↔R3 shared-meter compounding of §9 Decision 5).

---

## 7. Files to create / touch

**Create:**
- `systems/oppositions/return_cost.gd` — the `ReturnCost` run-state node (the §5 pseudocode). New directory `systems/oppositions/` (R1/R3/R4 siblings land here too; first creator makes it).
- `systems/oppositions/return_cost.tscn` *(optional)* — a trivial scene wrapper if the dive scene instantiates R2 as a packed scene like `DiveClock`'s `dive_clock.tscn`; otherwise the dive-scene assembly (RG1) adds a `ReturnCost` node and injects the `DiveClock` reference. **Coordinate the instantiation seam with RG1** (RG1 owns dive-scene assembly).
- *(only if `meter` toll ships a HUD readout)* a greybox "egress debt" bar — **stub inline** per the M1 greybox asset norm (a `ColorRect`/`ProgressBar`); do **not** dispatch an asset agent. Lowest priority; `clock` is the default and needs no new HUD (the clock bar already exists, E2).

**Touch (read-only / inject, no source edits to autoloads):**
- Reads `GameState.active_run_config` (R0) — read-only.
- Reads BUG2's live depth surface (`EventBus.depth_changed` + the player's current `PlacedPiece.dist_to_gate`) — **coordinate the exact read with BUG2's as-built surface at build time** (BUG2 lands in wave 1; R2 must read whatever depth/dist field BUG2 exposes on run-state or `PlacedPiece`).
- Calls `DiveClock.modify_light(-cost)` (existing public A3 method) for the `clock` toll — injected node reference, no source edit.
- Calls `GameState.fail_run(&"timeout")` (existing public method) — call site only, **no `game_state.gd` edit**. (Per §9 Decision 4, R2 does **not** call `GameState.add_exposure()`; the `exposure` toll routes to R3's run-state meter instead.)
- Emits `EventBus.return_cost_incurred` (pre-declared by TEL in wave 1) — **no `event_bus.gd` edit**.

**Generator hook (only for `decay_behind`):** flipping/removing a mated socket link mid-run touches the band's runtime graph (B2/B3 `Band`/`PlacedPiece` socket data). This is the one place R2 mutates generated structure. **Flag to R4/BUG3:** R4 owns `branch_chance` (the multiple-routes-home that makes `decay_behind` non-degenerate) and BUG3 seals the map; a collapsed link must not re-open a void socket (BUG3) and must keep `band.fingerprint()` semantics sane (the collapse is a *runtime* graph edit, not a generation-time change, so it does not alter the deterministic seed→layout — but it does alter the live walkable graph). If `decay_behind` proves to need generation-time cooperation, **pull it out of the parallel wave-2 set and sequence it after R4** (flag at brief time per M1.1 §6). For the prototype, prefer the runtime-only collapse + reachability guard and keep `decay_behind` greybox.

**Confirmed: NO `event_bus.gd` and NO `game_state.gd` source edits.** Every clock/exposure/end-run effect routes through an existing public surface:
- clock → `DiveClock.modify_light()` (public, designed for exactly this)
- exposure → R3's run-state meter API (the only exposure path; requires R3 enabled — §9 Decision 4. **No meta `GameState.add_exposure()`.**)
- run-loss → `GameState.fail_run(&"timeout")` (existing public)
- telemetry → `EventBus.return_cost_incurred` (TEL pre-declared)

---

## 8. Acceptance criteria

Restated from `M1.1_Breakdown.md` §4 (R2) and aligned to this spec:

1. **R2 on, `egress_toll`/`clock`:** retreating from depth `d` costs **measurably more** than retreating from depth `1` (for `1 ≤ thr < d`), observable both **in-game** (the dive clock visibly drops faster on a deep retreat) and **in telemetry** (`return_cost_incurred` rows with larger `magnitude` / higher cumulative cost for deeper retreats), scaling with the configured `mag`/`per`/`thr` curve.
2. **R2 off (all-off default):** walk-back is **free** — no `return_cost_incurred` rows, no clock/exposure/meter charge; the loop behaves **identically to M1.0** (the permanent control).
3. **Knobs take effect from the Config menu:** changing `r2_mechanism`, `r2_cost_magnitude`, `r2_cost_per_depth`, `r2_depth_threshold`, `r2_toll_resource` each produces a corresponding, observable change in the charged cost / which resource is taxed / where the cost starts.
4. **Threshold honored:** with `r2_depth_threshold = k`, retreats while `dist_to_gate ≤ k` incur **zero** cost; only depth beyond `k` is taxed.
5. **Telemetry contract:** `return_cost_incurred(depth, cost_kind, magnitude)` fires on each charge with correct `cost_kind`; **`run_ended` arity is unchanged**; an R2-induced run loss uses the **existing** `run_ended.reason = "timeout"`.
6. **No soft-lock (`decay_behind`):** on any seed in a determinism sweep, the gate remains reachable from every piece the player can occupy; on the linear M1.0 spine, `decay_behind` self-downgrades (never severs the only path home).
7. **Determinism preserved:** R2 introduces no new RNG and (runtime-only `decay_behind` graph edits aside) does not alter the seed→layout mapping; `band.fingerprint()` is unchanged for a given seed+config at generation time.

---

## 9. Resolved Decisions (Director-ratified 2026-06-19 — apply-all-recommendations)

The Director adopted **every** recommendation in this section as a ratified decision. The body of this spec (above) is written to these decisions; an implementing agent reads one definite design.

1. **Primary mechanism. Decision: `egress_toll` is the ratified primary, fully-built mechanism.** Ship all three enum values: `egress_toll` (the robust cost engine), `decay_behind` (secondary, behind the reachability guard + linear-spine self-downgrade), and `lengthen` (an alias routing into the `egress_toll` cost path with a distance-multiplier framing). *Rationale:* `egress_toll` is deterministic, soft-lock-free, reads B3's `dist_to_gate` directly, and routes entirely through existing public surfaces — the cleanest test of the design hypothesis, with one cost engine serving all three behaviors. True path-lengthening is flagged as an M2+ generator feature, not M1.1 greybox.

2. **Soft-lock guarantee. Decision: "the gate must always remain reachable from every piece the player can occupy" is a HARD, non-negotiable rule.** `decay_behind` may only collapse a link if a pre-collapse reachability check (reverse-BFS from gate over the surviving graph) confirms the player still has a path home; otherwise the collapse is skipped, and on the linear spine `decay_behind` self-downgrades to a toll (never severs the sole path). *Rationale:* a silent navigation trap is not a fair stake for a greybox gate; any genuine "committed too deep" death must be an explicit R1-style death, not a soft-lock.

3. **Default toll resource. Decision: `clock` is the ratified default `r2_toll_resource`.** *Rationale:* the clock is the run's master pressure, already on-screen (E2 HUD), and a clock-out on retreat reads naturally as `run_ended.reason = timeout`; it routes through the existing `DiveClock.modify_light(-cost)` surface with no autoload edit. `meter` remains the isolated-study fallback; `exposure` remains the deliberate R2↔R3 coupling option.

4. **Exposure toll source. Decision: when `r2_toll_resource == exposure`, R3 must be enabled and the toll adds to R3's run-state meter; R2 does NOT write meta `GameState.exposure` for this throwaway per-run prototype.** *Rationale:* meta exposure persists across runs and would contaminate the comparable-baseline control; selecting `exposure` toll therefore requires R3 enabled (no meta fallback).

5. **R2↔R3 coupling (stacking). Decision: R2's `exposure` toll SHARES R3's run-state meter** — retreating from deep pushes R3's meter toward its thresholds, a deliberate compounding. *Rationale:* the compounding is the emergent behavior the re-gate wants to observe; RG2 disentangles the two oppositions via the per-opposition telemetry (`return_cost_incurred` vs `exposure_crossed`).

6. **Cost-accounting timing. Decision: marginal-per-hop — charge `per` per retreat hop above the threshold, plus `mag` once on the first taxed retreat of the run.** No lump-at-gate. *Rationale:* the cost is felt *as the player walks home* (the clock visibly bleeding is the tension and can time them out mid-retreat), where a gate-lump would be a surprise tax that can't inform the mid-retreat decision.

---

*Living spec. Update alongside `M1_As_Built.md` as R2 builds; record any departure from this contract in `DESIGN_DEVIATIONS.md` for the wave-2 close-out sweep.*
