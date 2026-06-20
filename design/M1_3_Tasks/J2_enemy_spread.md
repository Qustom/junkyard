# J2 — Enemy Spread Across Depths (Director feedback F2) — Expanded Design Spec

**Milestone:** M1.3 (Legibility & Density) · **Workstream:** density — distribute danger across the new big rooms · **Wave:** 2 (parallel worktree, after Wave 1 on `main`)
**Task id:** J2 · **blockedBy:** J1 (default play-preset + size re-range — tune the spread to the new room scale) · **pairs with:** J3 (per-room density — shared hazard-spawn seam, §A.4) · **fixes:** Director feedback **F2** (`design/M1_2_Tasks/G4_findings_M1.2.md` §3 I2 read + §5 table row 2)
**Assignees:** general-purpose (spawn-distribution code) · game-director-designer (this spec + config-default deltas) · character-animator (only if a new per-depth tell is wanted — default: none)
**Author:** game-director-designer · **Status:** Phase-2 design (per `M1.3_Breakdown.md` §3 + the four-phase process in `CLAUDE.md`). **Design only — no code, no `.tscn`, no Godot, no git.** Open questions in §C are resolved by the Phase-3 fresh-eyes pass + Director.

> **What this doc is.** Phase-2 design for J2 — the change that turns the M1.2 hazard from a **single-gate sprint** ("one predator at one depth threshold, the rest of the level is empty") into a **threat distributed across the depth of the band**, so J1's much-bigger rooms (size ≥4.0, ~19–25 rooms) aren't a single-threat dash. It inherits I2's hazard wholesale (`design/M1_2_Tasks/I2_hazard_fix.md`, Director-LOCKED): shrunk r10 body, anti-wall-stick de-pin, depth-scaled catch, refuge-preserving wall collision. **J2 changes only WHERE the N hazards spawn — the per-hazard behaviour, signals, kill routing, and all-off control are untouched.** It also defines the **single-writer ownership of the hazard-spawn seam** that J2 and J3 share, so the Wave-2 build doesn't collide.

---

## 0. Hard constraints (inherited from I2 §0 / R1 §0 — restated for the builder)

- **THROWAWAY greybox, NOT the M2 enemy-AI slice.** J2 spawns *more of the same* `HazardEntity`. No new AI, no spawner system, no pooling framework, no waves/director. The spread is **placement math in the existing spawn seam**, nothing else.
- **Configurable, not balanced.** Acceptance is "N hazards appear distributed across depth and every distribution knob takes effect," never "the count/curve is right." Ship the §B-recommended defaults but assume the Director sweeps every number — *how many enemies feels right is an RG2 sweep, not a value this spec fixes* (§C-Q-fun).
- **All-off reproduces M1.0/M1.1/M1.2 baseline EXACTLY.** With `r1_enabled == false` (or count resolving to 0) **no hazard node is instantiated**. J2 must keep that byte-for-byte: zero nodes, zero behaviour delta, zero telemetry rows when off. The permanent control (`all_oppositions_disabled()`, fp=`e943ac9c8bc1`) is unchanged.
- **Determinism: the hazard is RUN-STATE, not proc-gen.** Hazards spawn into `_band_container` (freed by `_clear_band()`), are never persisted, and **must NOT feed `fingerprint()`** (`band_generator.gd` / the layout determinism key). J2 reads the *already-graded* band (`depth_index`, `floor_cells`) and places run-state nodes on top of it. The layout fingerprint must byte-match across J2 on/off (a determinism test asserts this — same guarantee `lvl_size_mult` already meets, `run_config.gd:154` "does NOT change fingerprint()").
- **Reads only; does not widen locked contracts.** J2 reads `GameState.active_run_config` (snapshotted at setup) and the generated `Band`. It **must NOT edit `event_bus.gd`** (reuse `hazard_awoke`/`hazard_caught` — §A.5; no new signal unless §C-Q5 is resolved to add one, pre-declared the M1.1 way) and **must NOT edit `game_state.gd`**.
- **Single-writer-per-file in the wave.** J2 owns the hazard-spawn seam in `scenes/game/main_game.gd` (`_spawn_r1_hazards` / `_hazard_spawn_position`). **J3 (per-room density) writes the SAME seam.** §A.4 defines the ownership split so they don't collide (the W1.1-2 / `M1.3_Breakdown.md` §5 single-writer lesson).
- **RunConfig schema:** J1 owns `run_config.gd` in Wave 1. Any new J2 `r1_*` field must land in J1's Wave-1 schema edit (coordinate at brief), or J2 reuses the existing `r1_spawn_count` (§B / §C-Q2). New field defaults must keep all-off == baseline and join `to_flat_dict()` + CFG coverage + the knob-count tests (`tests/test_run_config.gd` / `test_config_menu.gd`).

---

## A. (a) Research — why J2, the current reality, and the J2/J3 seam

### A.1 Goal (one sentence)

*Replace the single-`r1_depth_threshold` spawn — which clumps all N hazards onto one piece — with a distribution that scatters the N hazards across the band's `depth_index` range, so a deep run meets danger at multiple depths rather than sprinting past one gate; reuse the existing hazard, signals, and all-off control unchanged.*

### A.2 The defect, against the real code

The Director's F2 (`G4_findings_M1.2.md` §5 table, row 2): *"Enemies should be spread through the level, not one at a threshold."* The data: `r1_spawn_count` + a **single** `r1_depth_threshold`; the hazard wakes at depth 0–1 then chases. The M1.3 implication is recorded verbatim: *"spawn N hazards across depths instead of one gate."*

I read the actual spawn seam (`scenes/game/main_game.gd`). The clump is exact:

- `_spawn_r1_hazards(rc, band)` (`main_game.gd:276–288`) loops `for i in rc.r1_spawn_count` and places **every** hazard via `_hazard_spawn_position(band, rc.r1_depth_threshold, i)` — the **same `depth_threshold` for all `i`**.
- `_hazard_spawn_position(band, depth_threshold, index)` (`main_game.gd:296–314`):
  1. computes `max_depth` by scanning `band.pieces` (`p.depth_index`),
  2. `target_depth = clampi(depth_threshold, 0, max_depth)` — **one depth for the whole spawn batch**,
  3. collects the `floor_cells` of every piece at exactly `target_depth` (in piece order, for determinism),
  4. picks `cells[index % cells.size()]` so multiple hazards spread *across that one depth's floor cells* — but **never across depths**.

So the current code already "spreads" multiple hazards **within a single depth band** (the `index % cells.size()` wrap), but they all sit at `clampi(r1_depth_threshold)`. With `r1_spawn_count = 1` (the M1.2 default), that is literally one predator on one piece; with `r1_spawn_count = 3` they're three predators on the *same* depth's pieces. **The depth axis is a single point.** That is the defect.

Compounding it on J1's scale: J1 promotes size-4.0 / ~19–25-room runs as the default. On a 19–25-piece spine the `depth_index` range is ~0..18–24; placing all hazards at one `~⅓ max_depth` gate (I2's tuned `~4`) leaves the **deep two-thirds of every big room sequence empty** — exactly the "single-threat sprint" the Director called out.

### A.3 What's available per piece (the inputs J2 already has)

The band is **fully graded** before the spawn seam runs (depth was assigned by `DepthGrader` during generation). Every input J2 needs is already on the `Band`:

| Datum | Where | Type / note |
|---|---|---|
| pieces list | `band.pieces` (`band.gd:14`) | `Array[PlacedPiece]`, **piece order is deterministic** (placement order) |
| per-piece depth | `PlacedPiece.depth_index` (`placed_piece.gd:46`) | `int`, BFS hops from entry (entry=0); on the linear M1 spine == placement index |
| band max depth | `band.max_depth` (`band.gd:39`) | `int`; (J2 can reuse `_hazard_spawn_position`'s own `max_depth` scan or read this — see §B note) |
| normalised depth | `PlacedPiece.depth_norm` (`placed_piece.gd:50`) | `float` in [0,1] = `depth_index / max_depth` — handy if J2 wants a curve over normalised depth |
| walkable cells | `PlacedPiece.floor_cells` (`placed_piece.gd:32`) | band-global `Vector2i` floor cells — already the spawn target |
| cell→world | `Vector2(cell * _band_cell_size_px) + half-cell` | the existing conversion in `_hazard_spawn_position:313` (respects J1's `lvl_size_mult` because `_band_cell_size_px` is the effective cell size) |

J2 needs **no new generator data and no `placed_piece.gd` / `band.gd` change** — it reads what grading already produced. This is the whole reason J2 is cheap: distributing across depth is re-targeting the existing placement loop over `band.pieces` grouped by `depth_index`.

### A.4 The J2/J3 shared-seam ownership (the load-bearing coordination)

`M1.3_Breakdown.md` §4–§5 flags that **J2 (enemy spread) and J3 (per-room density) both populate the band and may share the hazard-spawn seam.** They must be designed as **one seam with a single writer** or the Wave-2 worktrees collide on `main_game.gd`. Proposal:

- **J2 owns `scenes/game/main_game.gd`'s hazard-spawn helpers** (`_spawn_r1_hazards`, `_hazard_spawn_position`, and any new private helper J2 adds). J2 lands first in Wave 2; J3 branches **after J2 is on `main`** (sequence, not parallel, for this file).
- **The seam J2 leaves for J3:** J2 refactors the spawn into a clear **two-step shape** — (1) *decide the depth list* `Array[int]` (which depths get a hazard, the J2 concern), then (2) *place one hazard at a given depth* (`_hazard_spawn_position(band, depth, index)` — the existing per-depth placement, lightly reused). J3's per-room density then becomes a **third, additive populate step** (`_populate_room_density(band, rc)`) that J2's refactor does *not* pre-empt: J3 adds room-fill hazards/interest on top of J2's depth-spread predators, reading its own `r1_density_*` / `j3_*` knobs. The two write **disjoint hunks** of the seam *if J2 lands first and exposes the per-depth placement helper for J3 to call*.
- **Concretely:** J2's new helper signature `_hazard_spawn_position(band, depth, index)` (changing the middle arg from `depth_threshold` → a concrete `depth`) is the **stable internal API J3 reuses** so J3 doesn't re-derive floor-cell selection. If a new EventBus signal is wanted (J3's density may want one; J2 does not — §A.5), it is pre-declared on `main` before Wave 2 the M1.1 way.
- **Fallback if sequencing is rejected:** if the Director/orchestrator wants J2 ∥ J3 truly parallel, split by *file region with explicit markers* and merge J2 first — but the recommendation is **J2 → J3 sequential on `main_game.gd`** (cleanest, matches `M1.3_Breakdown.md` §5 "sequence or co-own"). *This is the seam proposal to confirm at brief time (§C-Q6).*

### A.5 Signals & how J2 pairs with J3 / J4

- **Reuse `hazard_awoke(depth, trigger)` / `hazard_caught(depth, run_t_ms)` unchanged** — each spread hazard is an independent `HazardEntity` that already emits both with **its own depth**. So the spread is *self-describing in telemetry*: RG2 can read the `depth` field on `hazard_awoke`/`hazard_caught` rows to see danger firing at multiple depths instead of one. **No new signal needed for J2** (§C-Q5 keeps it that way unless the Director wants an explicit `hazard_spawned(depth)` placement-time row).
- **J3 (per-room density)** layers on J2: J2 owns *predators distributed by depth*; J3 owns *filling individual big rooms* (loot/interest/extra hazard so a size-40 room isn't empty). Designed together (§A.4) so the band gets both axes of density without seam collision.
- **J4 (hallway length)** is orthogonal: it shortens corridors via the generator/placer, changing the *spacing between* depths. J2 spreads across `depth_index` (a count, not a px distance), so J2 is **invariant to J4** — fewer/shorter halls just compress the same depth spread. J4 touches `band_generator.gd`/`junk_placer.gd`, **not** the hazard seam — no J2/J4 file collision (confirm at brief; `M1.3_Breakdown.md` §5 assigns single-writer per file).

---

## B. (b) Pseudocode — distribute N hazards across `depth_index`

GDScript-flavoured, **illustrative not final**, against the real `main_game.gd` spawn seam read above. Only the changed seam is shown; `HazardEntity`, its `setup()`, signals, and routing are unchanged.

### B.1 The distribution model (recommended: **even-per-depth-band over a configurable depth window**)

The cheapest model that directly answers F2 and stays a count (determinism-safe, J4-invariant): **choose a depth window `[min_depth, max_depth_used]` and spread `N` hazards as evenly as possible across the distinct depths in that window.** A density-*curve* (more hazards deeper) is a strict generalisation flagged in §C-Q1; the even spread is the recommended first ship because it is the most legible "danger at every depth" and the simplest sweep.

Two new `r1_*` knobs (coordinate the schema add with J1's Wave-1 `run_config.gd` edit), both defaulting so **all-off = baseline** and the J1 preset gets sensible spread:

```gdscript
# run_config.gd — NEW J2 fields (land in J1's Wave-1 schema edit), @export_group("R1 ...", "r1_")

## J2 (M1.3): how the r1_spawn_count hazards are distributed over depth.
##   0 = single_gate  → ALL at r1_depth_threshold  (M1.2 behaviour — the all-off-equivalent)
##   1 = even_spread  → spread evenly across [r1_spread_min_depth .. effective max] (F2)
##   2 = curve        → weighted deeper (optional, §C-Q1; default OFF)
@export_enum("single_gate", "even_spread", "curve") var r1_spawn_distribution: int = 0
## J2: shallowest depth that may receive a spread hazard. Clamped to [0, max_depth].
## Below this depth stays safe (the "shallow play is safe, then it stirs" arc, I2 §2.4).
@export var r1_spread_min_depth: int = 0
```

> **Why `r1_spawn_distribution = 0` (single_gate) is the default:** it reproduces M1.2's exact spawn placement, so when J2 ships and the Director hasn't opted into spread, the **all-off control AND the M1.2-comparable cohort are byte-identical** (no node placed differently, no fingerprint touch). The **J1 default play-preset** sets `r1_spawn_distribution = 1` (even_spread) + a higher `r1_spawn_count` (e.g. 4–6) so the *booted* experience has the spread the Director asked for. Permanent control stays reachable via CFG reset (`M1.3_Breakdown.md` §2 contract). *Count and the preset values are §C-Q-fun sweeps.*

### B.2 The spawn seam refactor (`main_game.gd`)

```gdscript
# --- J2 (M1.3): distribute N hazards across depth_index. Replaces the single-gate loop.
#     RUN-STATE placement only — reads the ALREADY-GRADED band; does NOT touch fingerprint().
func _spawn_r1_hazards(rc: RunConfig, band: Band) -> void:
    if rc == null or not rc.r1_enabled or rc.r1_spawn_count <= 0:
        return                                   # all-off / count 0 → no node (baseline intact)
    var hazard_scene := load(HAZARD_SCENE_PATH) as PackedScene
    if hazard_scene == null:
        push_error("MainGame: R1 hazard scene missing at %s." % HAZARD_SCENE_PATH)
        return
    var player := get_tree().get_first_node_in_group(&"player") as Node2D

    # J2 STEP 1 — decide the depth for each of the N hazards (the spread concern).
    var depths: Array[int] = _hazard_spawn_depths(band, rc)   # length == r1_spawn_count

    # J2 STEP 2 — place one hazard at each chosen depth (reuses the per-depth placement;
    #             J3 will ALSO call _hazard_spawn_position(band, depth, idx) — §A.4 seam).
    for i in rc.r1_spawn_count:
        var hz := hazard_scene.instantiate() as HazardEntity
        _band_container.add_child(hz)
        hz.global_position = _hazard_spawn_position(band, depths[i], i)
        hz.setup(rc, player)


## J2: the list of depths (one per hazard). Deterministic: derived only from band
## topology + config, no RNG (so two runs with the same seed+config place identically;
## and so this can NEVER leak into fingerprint — it's downstream, run-state).
func _hazard_spawn_depths(band: Band, rc: RunConfig) -> Array[int]:
    var max_depth := _band_max_depth(band)                    # see note below
    var out: Array[int] = []

    match rc.r1_spawn_distribution:
        0:  # single_gate — M1.2 behaviour: every hazard at the clamped threshold.
            var d: int = clampi(rc.r1_depth_threshold, 0, max_depth)
            for _i in rc.r1_spawn_count:
                out.append(d)

        1:  # even_spread (F2) — spread N across [min .. max] inclusive, as evenly as possible.
            var lo: int = clampi(rc.r1_spread_min_depth, 0, max_depth)
            var hi: int = max_depth
            var span: int = maxi(hi - lo, 0)
            var n: int = rc.r1_spawn_count
            for i in n:
                # even fractional placement across the inclusive [lo,hi] span, rounded.
                var t: float = 0.5 if n == 1 else float(i) / float(n - 1)
                out.append(lo + int(round(t * float(span))))

        2:  # curve (optional, §C-Q1) — bias deeper; default OFF (preset never selects it
            #   unless the Director opts in). Same shape, t passed through an ease(>1) curve.
            var lo2: int = clampi(rc.r1_spread_min_depth, 0, max_depth)
            var span2: int = maxi(max_depth - lo2, 0)
            for i in rc.r1_spawn_count:
                var t2: float = 0.0 if rc.r1_spawn_count <= 1 \
                    else pow(float(i) / float(rc.r1_spawn_count - 1), 1.6)  # >1 → clusters deep
                out.append(lo2 + int(round(t2 * float(span2))))
    return out


## max graded depth in the band. Reuse band.max_depth (band.gd:39) if it is reliably
## set post-grade; else keep the existing local scan (main_game.gd:298-301). Either is
## deterministic — pick ONE and note it (§C-Q3). Shown here as the band field.
func _band_max_depth(band: Band) -> int:
    return band.max_depth
```

`_hazard_spawn_position(band, depth, index)` is the **existing helper, minimally changed**: rename the second arg `depth_threshold → depth` (it already does `clampi(depth, 0, max_depth)`, collects that depth's `floor_cells` in piece order, and wraps `cells[index % cells.size()]`). When two hazards land on the *same* depth (e.g. `even_spread` with N > distinct depths, or `single_gate`), the existing `index % cells.size()` wrap **already spreads them across that depth's floor cells** — so the within-depth spread the M1.2 code had is preserved for free.

### B.3 Determinism note (the must-not-break)

- `_hazard_spawn_depths` uses **no RNG** — it is a pure function of `band` topology (`depth_index`, `max_depth`) + the config. Same seed + same config → identical placement. It must **not** call `RNG.*` (that would couple run-state placement to the proc-gen RNG stream and could perturb downstream draws). If §C-Q4 ever wants *randomised* spread, it must draw from a **separate, run-state RNG seeded off the run seed**, never the generator's stream, and still must not feed `fingerprint()`.
- The hazard nodes are added to `_band_container` (run-state) **after** generation/grading and after `fingerprint()` would have been computed for the layout — so J2 is physically downstream of the determinism key. The all-off (`r1_enabled=false`) and `single_gate` paths place identically to M1.2; a determinism test asserts the **layout** fingerprint byte-matches with J2 on vs off (it must, since J2 never touches the generator).

---

## C. (c) Open Questions (Phase-3 fresh-eyes + Director resolve)

Each flagged **[fun/feel — Director]**, **[design — resolver]**, or **[implementation — programmer picks cheapest]**. The body commits to a recommended default for each so the build is never blocked.

- **Q1 — Distribution model: even-per-depth, density-curve, or per-room?** *[design — resolver; curve shape is fun/Director]*
  Recommendation: **ship `even_spread` (mode 1) as the J1-preset default**, with `single_gate` (mode 0) as the all-off-equivalent and `curve` (mode 2) as an optional deeper-biased generalisation (built but not preset-selected). Even spread is the most legible "danger at every depth" and the simplest sweep; the curve is a one-line `pow()` if the Director wants "deeper = denser." **Per-room** distribution (one-per-room rather than per-depth) is **J3's concern** (per-room density), not J2's — J2 spreads across the *depth axis*, J3 fills *individual rooms*; keeping them separate is what makes the seam split (§A.4) clean. *Resolver: confirm even_spread default; Director picks whether the curve mode ships preset-on.*

- **Q2 — Knob shape: reuse `r1_spawn_count` + 2 new fields, or one richer field?** *[implementation — resolver]*
  Recommendation: **reuse `r1_spawn_count` for N** (already exists, already in `to_flat_dict()`/CFG) and add **two** small fields: `r1_spawn_distribution` (enum) + `r1_spread_min_depth` (int). Two fields keep each knob single-purpose and sweepable, and both default to the M1.2-equivalent (`single_gate`, `0`). Alternative (a `PackedInt32Array r1_spawn_depths` the Director hand-authors) is more flexible but a worse sweep ergonomic and a bigger CFG/UI lift — rejected for greybox. *Resolver confirms the two-field shape; the fields must land in J1's Wave-1 `run_config.gd` edit (coordinate at brief) + the knob-count tests.*

- **Q3 — `max_depth`: reuse `band.max_depth` or keep the local scan?** *[implementation — resolver]*
  The existing helper scans `band.pieces` for max `depth_index` (`main_game.gd:298-301`); `band.max_depth` (`band.gd:39`) should hold the same value post-grade. Recommendation: **use `band.max_depth`** (one source of truth, cheaper) **iff** the resolver verifies it is reliably set after `DepthGrader.grade()` for the configs J2 runs; if there's any doubt it's populated at spawn time, **keep the local scan** (it's already correct and cheap). *Resolver verifies which and picks one — pure correctness, no design.*

- **Q4 — Even-but-deterministic vs jittered placement?** *[fun/feel — Director, default no jitter]*
  Recommendation: **deterministic even spread, no RNG** (§B.3) — same seed+config places identically, which keeps the experiment comparable and the determinism guarantee trivially intact. If playtest finds the even grid feels mechanical, a *seeded* jitter (separate run-state RNG, never the generator stream, never fingerprint) is a small follow-up — **not built in J2** unless the Director asks. *Director confirms no-jitter for the M1.3 gate.*

- **Q5 — New EventBus signal, or reuse the two existing?** *[design — resolver, default reuse]*
  Recommendation: **reuse `hazard_awoke`/`hazard_caught` only** — each spread hazard already emits both with its own `depth`, so RG2 reads the depth distribution of wakes/catches directly; no placement-time row is needed to verify the spread landed (a wake at depth 3 *and* depth 9 in one run is the proof). A `hazard_spawned(depth)` row would make "how many spawned where" explicit but is an `event_bus.gd` edit + a pre-declare; **not justified for J2** given the existing rows already carry depth. *Resolver confirms reuse; if the Director wants explicit spawn-placement telemetry, pre-declare the signal on `main` the M1.1 way before Wave 2.*

- **Q6 — J2/J3 seam ownership.** *[implementation — orchestrator confirms at brief]*
  Recommendation (§A.4): **J2 owns the `main_game.gd` hazard-spawn helpers and lands first in Wave 2; J3 branches after J2 is on `main`** and adds an additive `_populate_room_density` step, reusing J2's `_hazard_spawn_position(band, depth, index)`. Sequence over parallel for this one file. If a J3 density signal is wanted, pre-declare it before Wave 2. *Orchestrator confirms the sequence at the Wave-2 brief; not a design call, recorded here so the brief catches it (the `M1.3_Breakdown.md` §5 single-writer rule).*

- **Q7 — Perf: do multiple simultaneous hazards need consideration?** *[implementation — resolver, default no]*
  Each `HazardEntity` runs a `_physics_process` with one `move_and_slide()` + a few vector ops (`hazard_entity.gd:86-141`). At the spread counts the Director is likely to sweep (single digits — F2 is "a few predators across depth," and J3 separately owns "a hazard per room"), this is negligible. Recommendation: **no perf work in J2**; if the *combined* J2 spread + J3 per-room density pushes simultaneous hazard counts into the dozens on size-40 bands, that is a **J3-era** concern (J3 sets the room-fill magnitude) — flag a soft cap there, not here. *Resolver confirms no J2 perf work; note the combined-count watch for J3.*

- **Q-fun — How many enemies / what preset spread feels right?** *[fun/feel — Director, SWEEP not a fix]*
  ⚠ **NEEDS DIRECTOR REVIEW (fun call).** This spec does **not** fix the count or the preset spread values — "how many enemies feels right" is exactly an RG2 sweep against J1's new room scale (`M1.3_Breakdown.md` §2: "the value is the Director's to sweep, not ours to finalize"). The spec recommends a **starting** J1-preset of `r1_spawn_distribution = even_spread`, `r1_spawn_count ≈ 4–6`, `r1_spread_min_depth ≈ 1–2` (keep depth 0–1 a safe entry, echoing I2's "shallow is safe then it stirs" arc) on a ~19–25-room band — a hazard roughly every ~4–5 depths. The Director sweeps count + min-depth + (optionally) curve mode at the gate. *Recommendation only; Director sets the felt values.*

---

## B'. Config-default deltas (recommendation — Director sweeps from here)

Two sets, per the M1.3 contract (`M1.3_Breakdown.md` §2): the **all-off control stays byte-identical**; the **J1 default play-preset** carries the spread.

| Field | all-off control | M1.2-equiv (single_gate) | **J1 preset (recommended start)** | Why |
|---|---|---|---|---|
| `r1_enabled` | `false` | `true` | `true` | preset boots with the hazard on (F1/J1) |
| `r1_spawn_count` | `0` | `1` | **`~4–6`** | F2 wants several predators across depth (§C-Q-fun, sweep) |
| **`r1_spawn_distribution`** (new) | `0 single_gate` | `0 single_gate` | **`1 even_spread`** | the F2 fix; default 0 = M1.2-identical (control intact) |
| **`r1_spread_min_depth`** (new) | `0` | `0` | **`~1–2`** | keep the entry depths a safe ramp (I2 §2.4 arc) |
| `r1_depth_threshold` | `0` | `~4` | `~4` | still the *wake* threshold per hazard (unchanged meaning); single_gate also uses it as the spawn depth |
| `r1_catch_radius` / `_per_depth` / `r1_chase_speed` / `_speed_per_depth` / `r1_catch_kills` | (I2 values) | (I2 values) | (I2 values) | **J2 changes none of these** — per-hazard behaviour is I2's, untouched |

> The two new fields default to the **M1.2-equivalent placement** so J2 ships without changing the control or the M1.2-comparable cohort; only the J1 preset opts into the spread. All preset magnitudes are **sweep targets, not balanced absolutes** (§C-Q-fun).

---

*Spec authored by game-director-designer for M1.3 J2 (Phase 2). Design-only — no code, no `.tscn`, no Godot, no git. Inherits I2's LOCKED hazard (`design/M1_2_Tasks/I2_hazard_fix.md`) and R1's §0 contract; changes ONLY hazard spawn placement (distribution across `depth_index`). Pairs with J3 on the shared spawn seam (§A.4). The programmer builds against this after Phase-3 resolves §C (Director on Q1-curve / Q4 / Q5 / Q-fun). Deviations go to `DESIGN_DEVIATIONS.md` for the Wave-2 close-out sweep.*

---

## Resolved Decisions (Phase 3 — fresh-eyes, 2026-06-19)

Fresh-eyes reviewer (not the author). I read the target doc, then verified **every** cited file/API/line against real source (`scenes/game/main_game.gd`, `data/run_config/run_config.gd`, `systems/bandgen/band.gd`, `systems/bandgen/placed_piece.gd`, `systems/depth/depth_grader.gd`, `scenes/hazards/hazard_entity.gd`, `tests/test_run_config.gd`) and cross-read the J3 companion (`design/M1_3_Tasks/J3_per_room_density.md`). No game code changed. Verdict: **the spec is sound and buildable; one cross-doc inconsistency on the J2/J3 build-org must be reconciled in J2's favour of "one seam" but J3's favour of "one branch/owner" — resolved below.**

### Citation verification (all confirmed; minor path note)

| Claim in doc | Verified | Note |
|---|---|---|
| `_spawn_r1_hazards(rc, band)` loops `for i in rc.r1_spawn_count`, all at `rc.r1_depth_threshold` | ✅ `main_game.gd:276–288` | Exact. Same `r1_depth_threshold` for every `i` — the defect is real. |
| `_hazard_spawn_position(band, depth_threshold, index)` scans `band.pieces` for max, `clampi`, collects `floor_cells` at one depth, `cells[index % cells.size()]` | ✅ `main_game.gd:296–314` | Local scan is lines 298–301; clamp 302; cell→world 313–314. All as described. |
| `band.pieces : Array[PlacedPiece]`, placement order | ✅ `band.gd:14` | |
| `band.max_depth : int` | ✅ `band.gd:39` | |
| `PlacedPiece.depth_index` / `depth_norm` / `floor_cells` | ✅ `placed_piece.gd:46 / 50 / 32` | Line numbers exact. |
| `band.max_depth` set by `DepthGrader.grade()` post-grade | ✅ `depth_grader.gd:47` (`band.max_depth = max_depth`) | **Settles Q3** — see below. |
| `HazardEntity._physics_process` is one `move_and_slide()` + a few vector ops | ✅ `hazard_entity.gd:86–141` | Doc cited `:86-141`; exact. |
| `fingerprint()` hashes only `piece_id@offset#mated` | ✅ `band.gd:58–62` | Hazards are **not** in the key. |
| `lvl_size_mult` "does NOT change fingerprint()" | ✅ `run_config.gd:154` comment + asserted in `tests/test_level_scale_determinism.gd` | |
| New fields must join `to_flat_dict()` + knob-count test | ✅ `run_config.gd:189–233`, `tests/test_run_config.gd:74–105` (`expected_keys` array) | Both `r1_spawn_distribution` and `r1_spread_min_depth` must be added to `to_flat_dict()` AND `expected_keys`. |
| Reuse `hazard_awoke`/`hazard_caught` (each hazard emits with own depth) | ✅ consistent with `hazard_entity.gd` (catch routes `_on_catch(depth)`, depth from `GameState.current_depth_index:106`) | No new signal needed. |

**Determinism — confirmed downstream of `fingerprint()`.** `fingerprint()` is computed/asserted only in tests and the bandgen path; in `main_game.gd` the band is generated → graded → materialised → `_spawn_r1_hazards` runs last (line 265, after `start_run`/`enter_band`). Hazards add to `_band_container` (freed by `_clear_band()`), never persisted, never hashed. `_hazard_spawn_depths` as specced uses **no RNG**, so it cannot perturb the proc-gen stream. The determinism claim (§0, §B.3) is correct as written; the existing `lvl_size_mult` layout-invariance test is the right precedent for the J2 on/off fingerprint-byte-match test.

**One correction (cosmetic):** §A.2 / §B reference `main_game.gd:298-301` for the local scan and `:313` for cell→world — these are correct against the current file. No line-number drift found. The only file-path nuance: the doc lists `band.gd` / `placed_piece.gd` without a directory; they live at `systems/bandgen/band.gd` and `systems/bandgen/placed_piece.gd` (the builder should use those full paths). Not an error, just a path the builder needs.

### Resolved on merit (resolver authority)

- **Q2 — Knob shape → CONFIRMED: reuse `r1_spawn_count` + add two fields (`r1_spawn_distribution` enum, `r1_spread_min_depth` int).** Two single-purpose, sweepable knobs both defaulting to the M1.2-equivalent (`single_gate`, `0`) is correct. The hand-authored `PackedInt32Array` alternative is rightly rejected (worse sweep ergonomics, bigger CFG lift). **Build requirement:** both new fields must (a) land in J1's Wave-1 `run_config.gd` schema edit under `@export_group("R1 Pursuing Hazard", "r1_")`, (b) be added to `to_flat_dict()` (`run_config.gd:194–203` R1 block), and (c) be added to `tests/test_run_config.gd` `expected_keys` (line 74–86) + the CFG coverage/knob-count tests. Per the J3 doc's §(a) and J1's pre-add precedent (I1 pre-added `lvl_`), **fold the J2 and J3 knobs together into J1's single Wave-1 `run_config.gd`/CFG/`to_flat_dict()` pass** so Wave 2 writes only the spawn seam. *Resolved.*

- **Q3 — `max_depth`: `band.max_depth` vs local scan → USE `band.max_depth`.** Verified: `DepthGrader.grade()` sets `band.max_depth` (`depth_grader.gd:47`) during generation, well before the spawn seam runs (`main_game.gd:265`). It is reliably populated for every config J2 runs (grading is unconditional in the generate path). Both sources are deterministic and identical; `band.max_depth` is the single source of truth and cheaper. **Decision: `_band_max_depth(band)` returns `band.max_depth`.** Keep a one-line defensive note in code that it equals the old local scan. *Resolved (pure correctness, no design).*

- **Q4 — No-jitter even spread → CONFIRMED no RNG / deterministic even spread for M1.3.** Verified both J2 and J3 land on the same RNG-free, index-deterministic placement (J3 doc §(b) determinism note). This keeps the experiment comparable, the fingerprint trivially intact, and matches today's `_hazard_spawn_position`. A seeded jitter (separate run-state stream, never the generator stream, never `fingerprint()`) is a recorded follow-up, not built in J2. *Resolved on merit; the "does the even grid feel mechanical" judgment, if it arises, is a post-gate Director note — not a blocker.*

- **Q6 — J2/J3 seam → RECONCILED: ONE merged spawn-seam rewrite, ONE owner, ONE shared branch (adopt J3's framing; supersede J2's "J2-first-then-J3-branches-after-on-main" sequencing).**
  This is the cross-doc inconsistency the brief asked me to settle. **J2's §A.4/Q6 says "J2 lands first on `main`, J3 branches after (sequence)."** **J3's §(a)/Open-Q-D says "build J2+J3 as one merged spawn rewrite on one shared branch, single owner (budget=J3 → distribution=J2)."** These are NOT equivalent: J2's sequencing has J3 *re-open and re-edit* `_spawn_r1_hazards`/`_hazard_spawn_position` after J2, which is exactly the second-rewrite-clobbers-first risk the Breakdown's single-writer rule (§5/§6) exists to prevent.
  **The J3 framing is the right call and I confirm it:** J2 (which depths) and J3 (how many per room, by size) are *one population system viewed on two axes* — a single function that computes a per-room/per-depth budget then distributes it. Splitting them into two sequential edits of the same two functions doubles the merge surface for no benefit. **Resolution:** the orchestrator assigns **one `general-purpose` builder** to a **single shared Wave-2 branch** that rewrites the hazard-spawn seam once, implementing J2's `even_spread`/`single_gate`/`curve` depth distribution AND J3's per-room size-scaled budget together. J1 pre-declares both tasks' `r1_*` knobs in Wave 1 so the Wave-2 branch touches only `main_game.gd` (+ J3's optional disjoint `junk_placer.gd` loot sub-knob, if it ships). The stable internal helper `_hazard_spawn_position(band, depth, index)` and the `_hazard_spawn_depths(band, rc)` step in this doc remain the correct internal shape — they just live in the one merged rewrite rather than being handed across a branch boundary. **J2's §A.4 "J2 lands first, J3 branches after" should be treated as superseded by this resolution** (flagging it here rather than editing §A.4, per the no-prior-section-rewrite Phase-3 convention; the orchestrator should brief the merged-branch arrangement). *Resolved (build-org); orchestrator confirms the single owner at the Wave-2 brief.*

- **Q7 — Perf → CONFIRMED no J2 perf work.** Verified `HazardEntity._physics_process` (`hazard_entity.gd:86–141`) is one `move_and_slide()` + bounded vector math per hazard. At single-digit spread counts (F2 = "a few predators across depth") this is negligible. **The combined-count watch belongs to J3** (it owns the per-room budget that sets the total) — and since Q6 now merges J2+J3 under one owner, that owner should add the soft cap there if the combined spread + per-room density pushes simultaneous hazards into the dozens on size-40 bands. *Resolved; combined-count watch noted for the merged seam's J3 budget.*

### Needs Director review (flagged with recommendation — NOT self-resolved)

- **Q-fun — How many enemies / preset spread values.** ⚠ **DIRECTOR (fun call — a sweep, not a fix).** Confirmed this is correctly NOT fixed by the spec. Recommended **starting** J1 preset: `r1_spawn_distribution = 1 (even_spread)`, `r1_spawn_count ≈ 4–6`, `r1_spread_min_depth ≈ 1–2` on a ~19–25-room band (a hazard roughly every ~4–5 depths), keeping depth 0–1 a safe entry (the I2 §2.4 "shallow is safe, then it stirs" arc — verified in `I2_hazard_fix.md:106`). The Director sweeps count + min-depth at the RG2/RG3 gate. *Recommendation only; Director sets felt values.*

- **Q1 — Does the deeper-biased `curve` mode (2) ship preset-ON?** ⚠ **DIRECTOR (fun/feel).** Resolver confirms: **build all three modes** (`single_gate`=all-off-equivalent, `even_spread`=F2 fix, `curve`=optional `pow(t,1.6)` deeper-bias) and **default the J1 preset to `even_spread` (1)**. Whether `curve` is *preset-selected* (deeper = denser) vs merely *available for the Director to flip* is a feel call. **Recommendation: ship `curve` BUILT but preset-OFF** — `even_spread` is the most legible "danger at every depth" for the first gate; the curve is a one-line opt-in the Director can sweep if even spread feels flat. *Director picks whether the preset selects curve.*

- **Q5 — Add a `hazard_spawned(depth)` placement-time telemetry signal?** ⚠ **DIRECTOR / qa-coordinator.** Resolver recommendation: **reuse `hazard_awoke`/`hazard_caught` only** (each spread hazard already emits both carrying its own `depth`, so RG2 reads the depth distribution of wakes/catches directly — a wake at depth 3 *and* depth 9 in one run is the proof the spread landed). A `hazard_spawned(depth)` row would make "how many spawned where" explicit but is an `event_bus.gd` edit + an M1.1-style pre-declare on `main` before Wave 2. **Recommendation: do NOT add it for J2** — existing rows carry depth and the Breakdown's "no new signal unless needed" bias applies. *Note: the J3 doc independently flags the same telemetry question (its Open-Q on a realised-count signal) and also defers to qa/RG2 — the two docs agree. If the Director/qa want explicit spawn telemetry, pre-declare ONE signal that covers both J2 spread and J3 budget before Wave 2.*

### Verdict on the J2+J3-as-one-task question (brief's direct ask)

**Confirmed: build J2 + J3 as ONE merged hazard-spawn-seam rewrite, single owner, single shared Wave-2 branch.** J3's recommendation is correct and J2's §A.4 "sequence on `main`" framing should be superseded by it (recorded above, Q6). They are one population system on two axes (J3 budget → J2 distribution); sequencing them as two edits of the same two functions re-creates the multi-writer collision the Breakdown forbids. J1 pre-declares both tasks' `r1_*` knobs in Wave 1 so the merged Wave-2 branch writes only `main_game.gd` (+ an optional disjoint `junk_placer.gd` for J3's loot sub-knob). The two docs are otherwise fully consistent (RNG-free determinism, reuse of existing signals, all-off byte-identical, hazards never in `fingerprint()`).

## Director Disposition (2026-06-19, FINAL — design locked)

- **Distribution:** `even_spread` default; **`curve` mode built but preset-OFF**; deterministic, no jitter (Phase-3 Q1/Q4). Starting sweep points (Director-accepted): count ≈ **4–6**, min-depth ≈ **1–2** (a sweep, not a fix). N reuses `r1_spawn_count` + new `r1_spawn_distribution` / `r1_spread_min_depth` (folded into J1's Wave-1 `run_config.gd` pass).
- **Telemetry:** reuse `hazard_awoke`/`hazard_caught` (carry depth) — **no `hazard_spawned` signal** (Phase-3 Q5).
- **Build structure (J2+J3):** built as **one population system on the shared spawn seam**, single owner — **J2 lands first on `main`, J3 additive/sequential** reusing J2's per-depth helper (`_hazard_spawn_position(band, depth, index)`); J1 pre-declares both tasks' knobs in Wave 1. (Reconciled at Phase 4: the two resolvers' ownership sketches → this single sequence; helper names unified at the Wave-2 brief.)

**Design LOCKED.**

## As-Built Note (Wave-2 close-out, Director-Reviewed 2026-06-20)

⚠ **`curve` mode (2) as-built is SHALLOW-biased, not deeper-biased.** It ships the locked `pow(t, 1.6)`
formula, but for `t ∈ [0,1]` `pow(t,1.6) ≤ t`, so intermediate hazards land *shallower* and density thins
toward the deep end — opposite of the "clusters deep" intent in the Disposition/comment. **Director
disposition: Reviewed (leave as-is).** It changes nothing this gate (`curve` is built but **preset-OFF**;
the booted preset uses `even_spread`). `test_hazard_spread.gd` asserts the real `pow(t,1.6) ≤ even`
behaviour so it can't silently drift. **If `curve` is swept ON at RG2** and "deeper = denser" is wanted,
flip the exponent (`pow(t, e<1)`, e.g. `0.6`, or `1 - pow(1 - t, e)`) and correct the comment then.
