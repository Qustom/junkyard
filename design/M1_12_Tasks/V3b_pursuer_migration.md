# V3b — Migrate the R1 pursuer machine onto the deck lane (Phase-2 design)

> **Task:** M1.12 Wave 4 (solo, sequential AFTER V3's K5 migration). Assignee: general-purpose
> + game-director-designer (band_greybox pursuer DeckEntry authoring). BlockedBy: **V3** (the K5
> lane migration — V3 authors the band_greybox deck + introduces `BandProfile.opposition_credits`;
> V3b **adds the pursuer to that same greybox deck**).
> **The version's single HIGHEST-RISK migration** (the Phase-3 resolver ranked it above V3's K5
> lane). The Director OVERRODE the K5-only recommendation (D-RAT-3, "fold all four") — so retiring
> the R1 pursuer machine is IN-SCOPE for M1.12 as this task. This doc promotes V3's one-paragraph
> "deferred pursuer sketch" (`V3_legacy_lane_migration.md:438-455`) to a full, buildable design.
>
> **This doc is Phase-2 design only — it writes no code and edits no other file.** It surveys the R1
> machine at file:line, enumerates the exact `r1_*` knobs to delete (real count), audits the pursuer
> def form, proves the deck-ctx gap and its minimal fix, sizes the budget/density problem, plans the
> migration + equivalence test + golden re-pin + the golden-capture-before-delete ordering, and ends
> with the projected debt ledger + a RISK ASSESSMENT. Its Open Questions are for Phase-3 fresh eyes
> + the Director.

---

## 0. TL;DR — what V3b is, and the one honest tension it must surface

**V3** (its sibling, lands first) migrates the K5 fair-share lane (pingpong / bomb / spike) onto the
band_greybox deck and deletes 21 `rc.h*_*` knobs. **V3b** does the analogous thing for the **R1
pursuer machine** — the *third*, wholly separate spawn path that lives entirely in
`scenes/game/main_game.gd` (`_spawn_r1_hazards` `:506` + its J2/J3 density stack `:559-789`, called
at `main_game.gd:353`, a sibling of the K5 façade call at `:361`, running **before and independent
of** EncounterBuilder). After V3b the pursuer spawns as a `DeckEntry` in band_greybox's deck, the
`main_game.gd` machine + the `r1_*` spawn knobs are deleted, and "exactly one way to add an
opposition" is **fully** delivered (all three spawn machines → the deck lane).

**The central design problem** (§b.0, Open Question A — the load-bearing one): the deck lane is a
**credit-spender with even-spread placement**. The R1 machine is a **two-budget, multi-mode**
placer: a **J2 spread budget** (`r1_spawn_count` hazards distributed across depth by a
single_gate / even_spread / curve mode) **plus** an additive **J3 per-room area-scaled density
budget** (`floor(r1_per_room_density · area / 96)` per room, its own `R1_DENSITY_BAND_CEILING = 64`).
The deck lane can reproduce the **J2 even_spread** half well (its native even-spread ≈ R1's
even_spread, which the play preset uses). It **cannot** reproduce, without adding code: the
**single_gate / curve** depth modes, and the **J3 area-scaled per-room density** (big rooms get more
bodies). The play preset uses `even_spread` (not single_gate/curve), so dropping those two modes is
behavior-preserving *for the shipped config*; **J3 density is the real fidelity loss** — its bodies
fold into the deck's flat even-spread, preserving the *per-type total* but not the *big-room
clustering*. D-RAT-3a explicitly licenses this ("greybox hazards may spread slightly deeper; deck
even-spread ≠ per-piece formula").

**The one tension V3b must escalate (Open Question A/B):** **D-RAT-3b** says the pursuer's body share
"comes out of the same ~48-credit budget" as the K5 trio; **D-RAT-3a** requires **per-type totals
within ±15%**. These two **cannot both hold literally** for the pursuer, because the pursuer's real
historical footprint (J2 `spawn_count = 5` **plus** J3 density ≈ 10–20 bodies ⇒ **~15–25 pursuer
bodies**) is *additive on top of* the K5 ceiling today — it was never inside the 48. Forcing all four
types to share a single 48-credit pool compresses every per-type total below its historical value and
**busts ±15% for at least the pursuer** (it draws last in deck order → starves first). **This doc
recommends honoring the *harder* gate (per-type ±15%, D-RAT-3a) and reading D-RAT-3b's "~48" as
"preserve density," not "hard-cap at 48"** — i.e. size `band_greybox.opposition_credits` to cover the
**sum** of all four types' historical demand (K5 ~37 + pursuer ~15–25 ≈ **55–65**), or reserve the
pursuer's share with a `per_band_cap` on its DeckEntry. This is a fun/density call the Director owns
(§c Open Question B).

---

## (a) Research on the premise — the R1 machine anatomy

### 1. The whole R1 machine, at file:line (all in `scenes/game/main_game.gd`)

Called once, at `main_game.gd:353` (`_spawn_r1_hazards(run_cfg, band)`), inside the band-build
sequence — **a sibling of** `_spawn_new_hazards(...)` at `:361` (the K5 façade V3 migrates) and
`_spawn_r4_nodes()` at `:343`. `:353` runs on the already-graded band, **before** the K5 façade and
**entirely outside** EncounterBuilder. The full call graph:

| Function | Lines | Role |
|---|---|---|
| `_spawn_r1_hazards(rc, band)` | `:506-546` | **Entry.** Gate (`r1_enabled`, `spawn_count`, `density_on`); loads `HAZARD_SCENE_PATH`; runs the **J2 spread loop** (N = `r1_spawn_count` hazards, one per chosen depth) then calls **J3** density. Each J2 hazard gets `setup(rc, player, {"room_bounds": _piece_bounds_at_world(band, pos)})` (`:545`). |
| `_hazard_spawn_depths(band, rc)` | `:734-757` | **J2 depth planner.** `match rc.r1_spawn_distribution`: **0 = single_gate** (all N at `clampi(r1_depth_threshold,0,max)`), **1 = even_spread** (`lo + round(t·span)`, `t=i/(n-1)`, `lo=r1_spread_min_depth`), **2 = curve** (`pow(t,1.6)` deeper bias). Pure fn of band topology + rc, **no RNG**. |
| `_hazard_spawn_position(band, depth, index)` | `:776-789` | Floor-cell at `depth`, `index % cells.size()` wrap. Entry-fallback if none. **Only R1 uses it.** |
| `_populate_room_density(band, rc, scene, player)` | `:559-578` | **J3 instantiate loop.** Reads the parallel `_density_spawn_positions` + `_density_spawn_bounds` plans; instantiates one HazardEntity per position with `setup(rc, player, {"room_bounds": bounds[i]})`. |
| `_density_spawn_positions(band, rc)` | `:643-681` | **J3 plan (positions).** Per eligible piece: `n = floor(r1_per_room_density · area / R1_DENSITY_AREA_UNIT)`, clamped `r1_density_per_room_cap` then `R1_DENSITY_BAND_CEILING(64) − spawned_total`; strides `n` across that room's own sorted cells. `rooms_only` skips corridors; `min_area` gates. Pure, **no RNG**. |
| `_density_spawn_bounds(band, rc)` | `:588-617` | **J3 plan (room bounds).** Parallel to positions (same order/length); one `_piece_floor_bounds_world` Rect2 per hazard, so `bounds[i]` matches `positions[i]`. Kept separate so the J3 position golden stays byte-frozen. |
| `_density_area(p, rc)` | `:689-694` | `cell_area` (default, size-invariant) or `px_area` (`·lvl_size_mult²`) per `r1_density_metric`. |
| `_piece_bounds_at_world(band, world_pos)` | `:626-633` | **J2 room-bounds resolve** — finds the piece whose `floor_cells` contain the cell under `world_pos`, returns its floor-cell bbox in world (the J2 path discards the chosen cell, so it re-resolves). Empty Rect2 → chase-everywhere fallback. |
| `_piece_floor_bounds_world(cells)` | `:486-492` | Rect2 of a cell list via `_density_cell_to_world`. Used by both J3 bounds + `_piece_bounds_at_world`. |
| `_density_cell_to_world(cell)` | `:723-725` | Band-global cell → centred world px. |
| `_density_pieces_sorted(band)` | `:706-707` | **Forwarder** → `EncounterBuilder.pieces_depth_sorted(band)` (the single copy already lives in the builder). |
| `_density_sorted_cells(p)` | `:714-715` | **Forwarder** → `EncounterBuilder.piece_sorted_cells(p)`. |
| `_is_corridor(id)` | `:698-699` | `piece_corridor*` / `piece_hall_v` test for `rooms_only`. |
| `_band_max_depth(band)` | `:764-765` | **Forwarder** → `band.max_depth`. **SHARED — also used at `:1112,:1116`. KEEP.** |

**Net deletable machine:** `_spawn_r1_hazards`, `_hazard_spawn_depths`, `_hazard_spawn_position`,
`_populate_room_density`, `_density_spawn_positions`, `_density_spawn_bounds`, `_density_area`,
`_piece_bounds_at_world`, `_piece_floor_bounds_world`, `_density_cell_to_world`,
`_density_pieces_sorted`, `_density_sorted_cells`, `_is_corridor` + the `:353` call site =
**~250–290 LOC** (`:486-492` + `:506-757` + `:776-789`, minus `_band_max_depth` which stays). The two
forwarders (`_density_pieces_sorted`, `_density_sorted_cells`) delete cleanly because their real
bodies already live in EncounterBuilder (the deck lane uses them) — **no logic is lost, only the
duplicate forwarder is removed.**

Consts to drop with the machine: `R1_DENSITY_AREA_UNIT = 96` (`run_config.gd:33`),
`R1_DENSITY_BAND_CEILING = 64` (`run_config.gd:37`). `HAZARD_SCENE_PATH` (`main_game.gd:153`) is only
referenced by `_spawn_r1_hazards` — deletes with it (the deck lane loads the host via
`pursuer.tres::host_scene`, `= hazard_entity.tscn`, the same scene).

### 2. The exact `r1_*` knobs — **18 fields** (8 spawn/density + 10 entity), 2 of them enums

`run_config.gd` declares (verified `:57-126`):

| Group | Fields | Count | Read by |
|---|---|---|---|
| **R1 spawn/density (the ~8 D-RAT-3 names)** | `r1_spawn_count` (`:81`), `r1_spawn_distribution` (`:88`, **@export_enum**), `r1_spread_min_depth` (`:92`), `r1_per_room_density` (`:99`), `r1_density_metric` (`:105`, **@export_enum**), `r1_density_rooms_only` (`:108`), `r1_density_min_area` (`:112`), `r1_density_per_room_cap` (`:116`) | **8** | the R1 **machine** (`_spawn_r1_hazards` / `_hazard_spawn_depths` / `_density_*`) — **all deleted** |
| **R1 entity/behavior** | `r1_enabled` (`:59`), `r1_depth_threshold` (`:61`), `r1_linger_seconds` (`:63`), `r1_chase_speed` (`:65`), `r1_speed_per_depth` (`:67`), `r1_catch_radius` (`:72`), `r1_catch_radius_per_depth` (`:77`), `r1_catch_kills` (`:79`), `r1_spawn_room_only` (`:122`), `r1_patrol_speed` (`:126`) | **10** | `hazard_entity.gd::_resolve_params` (`:110-125`) — **rewired to `spawn_ctx["params"]`** |
| | **TOTAL `r1_*`** | **18** | |

**The firm directive (D-RAT-3 / task binding) is the 8 spawn/density knobs** — they drove the deleted
machine and MUST go. **The 10 entity knobs are the recommended full deletion** (the task's "entity
rewire to spawn_ctx params" implies it, and it is what delivers the "one way" thesis the Director
chose over K5-only). This doc designs the **full 18-knob deletion** as the primary path (§b) and flags
the two entanglements that make the entity half non-trivial (Open Question E):

- **`r1_enabled` is load-bearing beyond spawning.** `all_oppositions_disabled()` (`run_config.gd:455-456`)
  returns `not (r1_enabled or r2_enabled or r3_enabled or r4_enabled)` — the M1.0-baseline label used
  by telemetry + 6 tests (`test_run_config`, `test_rg1_m13_verify`, `test_config_menu`). Deleting
  `r1_enabled` changes this predicate's shape.
- **The BUG6 traps** (`run_config.gd:676-685`) read `r1_enabled` / `r1_spawn_count` / `r1_catch_radius`
  (`r1_no_spawn`, `r1_catch_radius_too_small`). These delete or re-express.

Each `r1_*` field also carries plumbing that goes with it:
- **`to_flat_dict()` telemetry rows** — 18 rows (`run_config.gd:491-508` for 16 + `:590-591` for the
  two L2 fields).
- **Config-menu manifest** — the whole `"r1_"` **section** (`config_menu.gd:64` SECTIONS row, `:89-100`
  `_MANIFEST["r1_"]` = all 18 members), the `RANGES` entries (`:246-260,:320`), the Hazards `TAB`'s
  `"r1_"` member (`:220`), the chip-summary block (`:1884-1887`), and the reflection prefix list. **If
  all 18 delete, the entire `r1_` section + the Hazards tab's `r1_` member disappear** (V3 already
  removes the tab's K5 half; V3b removing `r1_` too may empty the Hazards tab — Open Question F).
- **The play-preset block** `make_default_play_preset()` (`run_config.gd:744-782`) — the 18 `c.r1_* = …`
  assignments (spawn 5 / even_spread / density 1.0 / chase 56 / catch 24 / patrol 28 / room_only true /
  …). The **magnitudes** move to the pursuer's DeckEntry `param_overrides` + `rc.param_overrides`
  (§b step 3); the **spawn counts** become the DeckEntry's `base_count`/`count_per_depth` (§b step 1).

### 3. Pursuer def audit — `pursuer.tres` carries the BEHAVIOR params but NOT the spawn counts

`data/oppositions/pursuer.tres` (verified):

- `id = &"pursuer"`, `host_scene = hazard_entity.tscn`, `credit_cost = 1`, `spawn_weight = 1.0`,
  `min_band = 0`, `cap_group = &""` (**no group — not in the K5 `&"new_hazards"` ceiling**),
  `per_room_cap = 0`, `per_band_cap = 0`, top-level `kills = false`.
- `params = { catch_radius, catch_radius_per_depth, chase_speed, depth_threshold, linger_seconds,
  patrol_speed, spawn_room_only, speed_per_depth }` — **all authored NEUTRAL (0 / false)**. It carries
  every **behavior** magnitude the entity reads… **but NOT `base_count` / `count_per_depth`** (unlike
  `charger.tres`, which has `base_count = 1`). So on **band_two** (where pursuer is a plain neutral
  `ExtResource` ref, `band_two.tres:70`) its deck demand is `Σ base_count + … = 0` → **skipped at
  `encounter_builder.gd:333-334` → never spawns.** The pursuer only "lives" through the R1 machine on
  band_greybox.

**Consequences for V3b:**
1. **The pursuer needs spawn counts to spawn via the deck.** These MUST be added on a
   **band_greybox-ONLY `DeckEntry` `param_overrides`** (adding `base_count` / `count_per_depth`), **not**
   on the shared `pursuer.tres` — else band_two's neutral pursuer card starts spawning (a cross-band
   regression, §a.4). This is the `DeckEntry` wrapper pattern V3 already uses for K5; `charger` in
   band_two is the live precedent (`band_two.tres` `deck_entry_charger` SubResource).
2. **The behavior magnitudes already exist as `params` keys** — so no new `.tres` `params` authoring is
   needed for behavior; the play values arrive via `rc.param_overrides["pursuer"]` (the play preset) or
   the DeckEntry overrides (band-baked). But note a **key-name mapping** the rewire must honor: the
   entity's `_resolve_params` output keys differ from the `params` input keys —
   `contact_radius ← catch_radius`, `contact_radius_per_depth ← catch_radius_per_depth`,
   `kills ← catch_kills` (`hazard_entity.gd:116-119`). The rewire (§b step 2) reads the **`params`
   key names** (`catch_radius`, …) and maps them, exactly as the current code maps `cfg.r1_catch_radius`
   → `"contact_radius"`.
3. **`kills` mismatch to flag:** `pursuer.tres` top-level `kills = false`, but the play preset sets
   `r1_catch_kills = true` and `pursuer.tres::params` has **no `catch_kills` key**. The rewired entity
   must source `kills` from `params["catch_kills"]` (with a `DEFAULTS` fallback), and the play preset's
   `param_overrides["pursuer"]` must carry `catch_kills = true`. Do **not** rely on the def top-level
   `kills` (it is `false` and the deck lane does not thread it into `ctx["params"]`).

### 4. The deck-ctx gap — smaller than V3's sketch implied (the room_bounds is ALREADY threaded)

V3's deferred sketch said the deck lane must be taught to "thread `room_bounds` for the `&"pursuer"`
kind." The survey shows **`_populate_deck` ALREADY passes the piece bounds** — the only missing piece
is `legacy_ctx`'s dispatch arm:

- `_populate_deck` computes `piece_bounds[pi] = _floor_bounds_world(cells, svc)` for every eligible
  piece (`encounter_builder.gd:320`) and **passes it as the 5th arg to `legacy_ctx`**:
  `legacy_ctx(d.id, p, k, spawned_total, piece_bounds[pi])` (`:356`). It also threads
  `ctx["params"] = params` (`:367`) and `ctx["room_key"]` (`:366`).
- `legacy_ctx(kind, …, room_bounds)` (`:110-121`) returns `room_bounds` **only for `&"pingpong"`**;
  `&"spike"` returns `phase_salt`; **default (bomb AND `&"pursuer"`) → `{}`** — so the pursuer's
  `room_bounds` is computed, passed, and **discarded**. A pursuer spawned through the deck today would
  get **no `room_bounds`** → `hazard_entity.gd:153` (`if _cfg.r1_spawn_room_only and
  _room_bounds.has_area()`) fails the `has_area()` guard → **the L2 spawn-room patrol silently
  degrades to chase-everywhere** (RD-4 fallback). This is the one concrete behavioral regression the
  migration MUST fix.

**The minimal fix (§b step 4):** add one `match` arm to `legacy_ctx`:
`&"pursuer": return { "room_bounds": room_bounds }`. **No `_populate_deck` change** — the bounds are
already computed + passed. This is materially smaller than V3's sketch (which implied a new deck-lane
thread). One nuance to note (Open Question C): the deck's `piece_bounds[pi]` is computed from
`svc.valid_cells(...)`-filtered cells (BUG7 entry-safe cells removed), whereas the R1 machine's
`_piece_bounds_at_world` uses **all** sorted cells — so the deck-derived room rect can be **very
slightly smaller** for entry-adjacent pieces. For pursuer hosts (deck lane skips `depth_index <= 0`
pieces, `:313`) the filter removes nothing at depth ≥ 1, so the rects match for every real pursuer
host. Low-risk; the equivalence test pins it.

### 5. Distribution: what the deck lane CAN and CANNOT reproduce

| R1 behavior | Deck-lane equivalent? | Disposition |
|---|---|---|
| **J2 even_spread** (mode 1, the **play-preset default**): N across `[spread_min_depth..max]`, `t=i/(n-1)` | **Yes (approx).** Deck lane spreads `n_plan` across the eligible **piece list** (`t=i/(n_plan-1)`, `round(t·(P-1))`, `:349-351`). Distributes by *piece index* not *depth value*, so multi-piece depths spread differently, but **monotonic + spans the range** — satisfies D-RAT-3a's "monotonic distribution proxy + deeper OK." | **Preserved** (the shipped mode). |
| **J2 single_gate** (mode 0): all N at one depth | **No** (deck lane always even-spreads). | **Dropped** — preset uses even_spread, so shipped behavior unaffected. Its golden (`test_hazard_spread (a)`) is deleted with the machine. Flag: any band/preset relying on single_gate? **None** — verified the play preset uses mode 1 (`run_config.gd:759`). |
| **J2 curve** (mode 2): `pow(t,1.6)` deeper bias | **No.** | **Dropped** — "built but preset-OFF" (`test_hazard_spread` docstring `(c)`); no shipped config uses it. |
| **J3 per-room area-scaled density**: `floor(density·area/96)` per room, big rooms get more, own ceiling 64 | **No deck equivalent** — the deck lane has no area-scaled per-room budget. | **Folded into the total** — the density bodies' *count* is absorbed into a higher deck `base_count`/`count_per_depth` (so the per-type **total** matches within ±15%), but the *spatial clustering in big rooms is LOST* (deck even-spreads them). **This is the real, unavoidable fidelity loss** (§0, Open Question D). D-RAT-3a licenses it. |

### 6. The pursuer's own spawn/behavior tests + goldens (the re-pin scope)

| File | What it pins | V3b impact |
|---|---|---|
| `tests/test_hazard_spread.gd` (12 `r1_` refs) | **THE J2 spread golden** — drives `mg._hazard_spawn_depths(band, rc)` directly for single_gate/even_spread/curve, monotonicity, `spread_min_depth`, determinism. | **Deleted with `_hazard_spawn_depths`.** The surviving concern (even-spread across depth, monotonic, deterministic) re-homes into the **equivalence test** against the deck plan. |
| `tests/test_per_room_density.gd` (15 `r1_` refs) | **THE J3 density golden** — drives `mg._density_spawn_positions(band, rc)` for the area formula, per-room cap, band ceiling, corridor exclusion, min-area gate, byte-frozen position list. | **Deleted with `_density_spawn_positions`.** Its concern (per-type total + per-room cap) folds into the equivalence test (as a **total**, not a spatial plan). |
| `tests/test_pursuing_hazard.gd` (**40 `r1_` refs**) | **THE pursuer BEHAVIOR golden** — sets `rc.r1_*` then `hz.setup(rc, player[, ctx])`, asserts awaken/chase/catch/latch/non-fatal/patrol. | **Re-pointed:** pass magnitudes via `spawn_ctx = {"params": {…}, "room_bounds": …}` (the charger unit-test pattern) instead of `rc.r1_*`. Behavior asserted is **unchanged** — this is the value-preserving rewire proof. |
| `tests/goldens/trace_pursuer_room.txt` | **Pursuer patrol BEHAVIOR trace** (per-frame pos/vel/state). | **Byte-identical if the rewire is value-preserving** — same params in → same behavior. A moved byte here = a rewire bug. Its driver test re-points to `spawn_ctx["params"]`. |
| `tests/test_rg1_m12_verify.gd` (18), `test_rg1_m13_verify.gd` (64), `test_rg1_m14_verify.gd` (6), `test_rg1_m15_verify.gd` (29) | Milestone verify matrices asserting `rc.r1_*` preset values / spawn counts. | Re-pointed to the pursuer DeckEntry + `rc.param_overrides` form, or the assertion moved to the def/deck params. `m13` (density) is the heaviest. |
| `tests/test_config_menu.gd` (14) | `legacy_exported.size()` / `exported.size()` counts + bijection. | After V3 (89→68 / 91→70), V3b's 18-field deletion → **68→50 / 70→52**. Re-pin + drop the `r1_` manifest/section/tab entries; `has_full_coverage()` stays green. |
| `tests/test_run_config.gd` (54), `test_opposition_components.gd` (15), `test_opposition_def_schema.gd` (9), `test_telemetry_config_marking.gd` (11), `test_band_two_profile.gd`, `test_throw_mechanic.gd` | Preset/verify/schema/telemetry assertions referencing `r1_*`. | Each re-pointed to the deck/param form or the def params; `test_band_two_profile` must confirm band_two's **neutral pursuer stays skipped** (the cross-band safety). |

### 7. GDD/TDD grounding

Same as V3: "content is data, not code." The R1 pursuer is the **last** hazard whose *spawn* is a
bespoke code machine + a dedicated `RunConfig` knob group (`r1_*`) rather than a def + a deck row. V3
unifies K5 (pingpong/bomb/spike); V3b unifies the pursuer — after which **all three spawn machines
are gone** and every opposition is added exactly one way (a `.tres` def + a deck row). This is the
"exactly one way to add an opposition" the M1.12 breakdown frames as the version's one-thing-to-prove,
which D-RAT-3 chose to fully deliver (over the K5-only recommendation).

---

## (b) Pseudocode / plan

Sequenced so the layout controls never move, the golden ground-truth is captured before any deletion,
and each sub-change is independently greenable. **V3b runs AFTER V3 is merged** (V3 owns the greybox
deck skeleton + `opposition_credits`; V3b appends the pursuer to it).

### Step 0 (FIRST, before any deletion) — capture the pursuer golden fixture

**Non-negotiable ordering (mirrors V3's golden-snapshot rule).** BEFORE deleting `_spawn_r1_hazards`
or any `r1_*` knob, run the **live R1 machine** once against fixed hand-built graded bands (the
`test_per_room_density._make_band` / `test_hazard_spread` band shapes) at the **play-preset `r1_*`
magnitudes**, and record to a committed fixture (`tests/goldens/pursuer_r1_plan.json` or a `.txt`):

- The **J2 depth list** (`_hazard_spawn_depths`) + placed positions (`_hazard_spawn_position`).
- The **J3 position plan** (`_density_spawn_positions`) + the parallel bounds plan.
- The **per-band total** pursuer body count and the **per-depth-bucket** histogram.

This frozen record is the equivalence test's ground truth. Deleting first forfeits it. Commit the
fixture as its own step, THEN proceed.

### Step 1 — Add the pursuer to band_greybox's deck as a `DeckEntry` (game-director-designer)

V3 already gave `band_greybox.tres` an `opposition_deck` (pingpong/bomb/spike DeckEntry rows) +
`opposition_credits`. V3b **appends a fourth row** — a `DeckEntry` wrapping `pursuer.tres` with the
band_greybox-only spawn counts (NOT on the shared def, §a.3):

```
# band_greybox.tres opposition_deck (V3 rows + the V3b pursuer row)
opposition_deck = [
    DeckEntry(def=pingpong.tres, param_overrides={...}),   # V3
    DeckEntry(def=bomb.tres,     param_overrides={...}),   # V3
    DeckEntry(def=spike.tres,    param_overrides={...}),   # V3
    DeckEntry(def=pursuer.tres,  param_overrides={          # V3b — adds spawn counts + behavior
        "base_count": <B>, "count_per_depth": <C>,          # the deck-lane demand (replaces J2+J3 count)
    }),
]
```

- **Deck ORDER matters** — the deck spends the shared budget greedily in eligible order
  (`_populate_deck` loops `for d in eligible`, `:322`). Placing the pursuer where its share survives is
  part of the equivalence tuning (Open Question B). Recommend authoring it so its `per_band_cap` (below)
  reserves its historical count regardless of order.
- **`base_count` / `count_per_depth`** are chosen so the deck plan's pursuer total ≈ the frozen J2+J3
  total (Step 0), within ±15%. These are **tuned against the fixture**, not guessed — the equivalence
  test (Step 5) is the acceptance bar.
- **Reserve the pursuer's share** so K5's greedy spend can't starve it: set `per_band_cap` on the
  **DeckEntry** (or the def if band_two stays neutral-and-skipped, which it does) = the pursuer's
  historical count, and size `band_greybox.opposition_credits` to cover **K5 demand + pursuer demand**
  (Open Question B — the D-RAT-3a/3b tension). Behavior magnitudes (chase_speed, catch_radius, patrol,
  room_only, catch_kills, …) also live in this `param_overrides` bag (or in `rc.param_overrides` for
  the play preset — see Step 3), keyed by the `pursuer.tres::params` key names.
- **All-off holds:** an all-off run has `rc.param_overrides = {}` and the DeckEntry's `base_count`
  makes the card **non-neutral by authored default** — WAIT: that would spawn on all-off. **Resolution:
  bake the spawn counts via `rc.param_overrides` in the play preset, keep the DeckEntry
  `base_count`/`count_per_depth` NEUTRAL (0)** — exactly the V3 pattern (§b step 4 of V3), so the K5
  `_deck_all_neutral` fast-path (V3's OQ-B resolution) also covers the pursuer: neutral card → 0 demand
  → skipped → all-off byte-clean. The DeckEntry then carries only the **behavior** overrides (which are
  inert until a hazard spawns); the **spawn counts** live in the play preset's `rc.param_overrides`.

### Step 2 — Rewire `hazard_entity.gd::_resolve_params` to `spawn_ctx["params"]` (general-purpose)

Change `_resolve_params(cfg: RunConfig)` (`:110-125`) → `_resolve_params(spawn_ctx: Dictionary)`
reading `spawn_ctx.get("params", {})` with a `DEFAULTS` fallback mirroring `pursuer.tres::params`
(neutral), the charger pattern (`charger_hazard.gd:44-54,112`). `setup` (`:90-103`) already receives
`spawn_ctx`; it currently calls `_resolve_params(cfg)` — change to `_resolve_params(spawn_ctx)`. Map
the `params` key names to the entity's output keys (unchanged output contract → behavior byte-identical):

```
# hazard_entity.gd (was: reads cfg.r1_depth_threshold / cfg.r1_chase_speed / cfg.r1_catch_radius / …)
const DEFAULTS := {   # mirror pursuer.tres::params (all neutral) + catch_kills
    "depth_threshold": 0, "linger_seconds": 0.0, "chase_speed": 0.0, "speed_per_depth": 0.0,
    "catch_radius": 0.0, "catch_radius_per_depth": 0.0, "patrol_speed": 0.0,
    "spawn_room_only": false, "catch_kills": false,
}
func _resolve_params(spawn_ctx: Dictionary) -> Dictionary:
    var dp: Dictionary = spawn_ctx.get("params", {})
    return {
        "depth_threshold": int(dp.get("depth_threshold", DEFAULTS.depth_threshold)),
        "linger_seconds":  float(dp.get("linger_seconds", DEFAULTS.linger_seconds)),
        "chase_speed":     float(dp.get("chase_speed", DEFAULTS.chase_speed)),
        "speed_per_depth": float(dp.get("speed_per_depth", DEFAULTS.speed_per_depth)),
        "contact_radius":  float(dp.get("catch_radius", DEFAULTS.catch_radius)),               # key map
        "contact_radius_per_depth": float(dp.get("catch_radius_per_depth", DEFAULTS.catch_radius_per_depth)),
        "patrol_speed":    float(dp.get("patrol_speed", DEFAULTS.patrol_speed)),
        "kills":           bool(dp.get("catch_kills", DEFAULTS.catch_kills)),                   # key map
        "def_id": &"pursuer", "emit_family": &"hazard_caught",
        "lethal_mode": &"radius_gated", "latch_rearm": true, "throw_mode": &"die",
    }
```

**Also rewire the L2 gate read:** `_physics_process` reads `_cfg.r1_spawn_room_only` (`:153`) — replace
with a `spawn_room_only` snapshot taken from `spawn_ctx["params"]` in `setup` (store `_spawn_room_only:
bool` alongside `_room_bounds`), since `cfg.r1_spawn_room_only` no longer exists. `_room_bounds` already
comes from `spawn_ctx["room_bounds"]` (`:95`) — unchanged.

### Step 3 — Move the pursuer magnitudes into the play preset's `rc.param_overrides` (game-director-designer)

Delete the 18 `c.r1_* = …` assignments from `make_default_play_preset()` (`run_config.gd:744-782`).
Add a `param_overrides["pursuer"]` bag carrying the exact play magnitudes + the spawn counts:

```
c.param_overrides["pursuer"] = {
    "base_count": <B>, "count_per_depth": <C>,          # spawn (tuned vs the Step-0 fixture)
    "depth_threshold": 1, "linger_seconds": 8.1, "chase_speed": 56.0, "speed_per_depth": 5.0,
    "catch_radius": 24.0, "catch_radius_per_depth": 1.0, "patrol_speed": 28.0,
    "spawn_room_only": true, "catch_kills": true,
}
```

`_effective_params(pursuer_def, rc, deck_overrides)` (`:437-451`) merges: def params (neutral) <
DeckEntry overrides < `rc.param_overrides["pursuer"]` — so the play values drive **both** the deck-lane
demand (`base_count`/`count_per_depth`) AND the entity behavior (rewired `_resolve_params`) through the
**one** surface. All-off (`rc.param_overrides = {}`) → neutral → skipped → baseline held.

### Step 4 — Add the `&"pursuer"` arm to `legacy_ctx` (general-purpose)

The only deck-lane code change (§a.4):

```
# encounter_builder.gd legacy_ctx() match — ADD:
    &"pursuer":
        return { "room_bounds": room_bounds }   # L2 patrol survives; bounds already passed at :356
```

No `_populate_deck` change (it already computes + passes `piece_bounds[pi]` and threads
`ctx["params"]`). This is band-agnostic but only fires for a **spawning** pursuer — band_two's pursuer
is neutral → skipped → never reaches `legacy_ctx` (§a.3), so bands 2–4 are byte-unchanged. Confirm in
`test_band_two_profile`.

### Step 5 — Delete the R1 machine + the `r1_*` knobs (general-purpose)

- `scenes/game/main_game.gd`: delete the `:353` call + the 13 machine functions (§a.1, ~250–290 LOC) +
  `HAZARD_SCENE_PATH` (`:153`). **Keep** `_band_max_depth` (`:764-765`, shared with `:1112,:1116`).
- `data/run_config/run_config.gd`: delete the 18 `r1_*` `@export`s (`:59-126`), their 18 `to_flat_dict`
  rows (`:491-508,:590-591`), the two density consts (`R1_DENSITY_AREA_UNIT`, `R1_DENSITY_BAND_CEILING`),
  the 18 preset assignments (moved in Step 3), and re-express the two BUG6 traps + `all_oppositions_disabled()`
  (Open Question E — recommend: `all_oppositions_disabled()` drops the `r1_enabled` term and, if a
  baseline label is still wanted, reads deck-neutrality; the `r1_no_spawn` / `r1_catch_radius_too_small`
  traps become pursuer-def param traps or are dropped as no-longer-reachable via the config surface).
- `ui/config/config_menu.gd`: delete the `"r1_"` SECTIONS row (`:64`), the `_MANIFEST["r1_"]` block
  (`:89-100`), the `RANGES` entries (`:246-260,:320`), the chip-summary (`:1884-1887`), the reflection
  prefix, and the Hazards `TAB`'s `"r1_"` member (`:220`) — see Open Question F for the now-possibly-empty
  Hazards tab.

### Step 6 — The equivalence test (qa via general-purpose) — D-RAT-3a/3b proof

Add `tests/test_pursuer_deck_equivalence.gd` (a SCENE test). A/B the **frozen Step-0 pursuer fixture**
against the **post-migration deck plan** (band_greybox deck + play-preset `rc.param_overrides`) on the
SAME fixed graded bands. The bar (D-RAT-3a/3b):

1. **Type coverage (exact/hard):** the deck plan spawns `&"pursuer"` (present before & after).
2. **Per-type total (±15%, D-RAT-3a):** `|deck_pursuer_total − fixture_pursuer_total| ≤
   max(1, ceil(0.15 · fixture_pursuer_total))`, where `fixture_pursuer_total = J2(5) + J3(~10–20)`.
   **This is where the budget must be sized (Open Question B)** — if `opposition_credits` only covers K5,
   the pursuer starves and this FAILS. Confirm the shared budget/`per_band_cap` gives the pursuer its
   ~15–25.
3. **Distribution (monotonic proxy, D-RAT-3a):** per-depth-bucket monotonic non-decreasing for
   `count_per_depth > 0`; deeper-spread accepted. **Document explicitly** that J3's big-room clustering
   is NOT reproduced (folded to even-spread) — this is the licensed fidelity loss (Open Question D).
4. **L2 room-bounds (hard):** a deck-spawned pursuer receives a non-empty `room_bounds`
   (`ctx["room_bounds"].has_area()`), so `r1_spawn_room_only` patrol works (§a.4 regression guard).
5. **Entry safety (hard):** no pursuer at `depth_index <= 0` (deck lane's `:313` skip).
6. **Caps (hard):** total ≤ the sized budget; pursuer per_band_cap honored.
7. **Determinism (hard):** two deck builds → byte-identical position lists (both RNG-free).
8. **Behavior (hard):** `trace_pursuer_room.txt` stays byte-identical after the Step-2 rewire (params
   in → same behavior out).

### Step 7 — Re-pin the goldens (general-purpose) — D-RAT-3 sign-off artifact

- **Delete** `test_hazard_spread.gd` + `test_per_room_density.gd` (their helpers are gone); fold their
  surviving concerns (spread monotonicity, per-type total, per-room cap) into the equivalence test.
- **Re-point** `test_pursuing_hazard.gd` (40 refs) + the `trace_pursuer_room` driver to
  `spawn_ctx = {"params": {…}, "room_bounds": …}`; assert **identical behavior** (this is the
  value-preserving-rewire proof).
- **Re-point** `test_rg1_m12/m13/m14/m15_verify`, `test_run_config`, `test_opposition_components`,
  `test_opposition_def_schema`, `test_telemetry_config_marking` to the deck/param form.
- **Re-pin** `test_config_menu` counts (68→50 / 70→52 after V3's 68/70) + drop the `r1_` manifest;
  `has_full_coverage()` + `has_full_def_coverage()` stay green.
- **D-RAT-3 presentation** at the Wave-4 close-out = the equivalence-test output (pursuer per-type
  total delta + tolerance + the distribution note "J3 density folded to even-spread") + the golden diff
  + confirmation `trace_pursuer_room.txt` is byte-identical. The design does NOT lock until the Director
  signs the re-pin.

---

## (c) Open Questions

**A. The deck lane structurally can't reproduce J3 area-scaled density or single_gate/curve — is even-spread-equivalent TOTAL enough?**
*(Scope/fidelity — D-RAT-3a already licenses this; confirm at the close-out.)* The play preset uses J2
`even_spread` (reproducible) + J3 per-room density (NOT reproducible — folds to even-spread). single_gate
and curve are preset-OFF so dropping them is shipped-behavior-safe. The pursuer's per-type **total** can
match ±15%, but its **spatial distribution** shifts: today big rooms cluster more pursuers (J3 area
scaling); post-migration they even-spread. D-RAT-3a explicitly accepts "deeper spread / deck even-spread
≠ per-piece formula," so this is *within the ratified bar* — but it is the **single largest behavioral
delta in the version** and the Director should see it concretely at the close-out. *Rec: proceed;
document the density-fold in the equivalence proof.*

**B. The D-RAT-3a (±15% per-type) vs D-RAT-3b (shared ~48-credit budget) tension — THE load-bearing call.**
*(Density/fun — needs Director review.)* The pursuer's historical footprint (~15–25 bodies) is
**additive on top of** the K5 ceiling today (its `cap_group = &""`, separate `R1_DENSITY_BAND_CEILING =
64`). D-RAT-3b says its share "comes out of the same ~48 budget." **Both cannot hold:** a single 48-credit
pool for four types compresses every per-type total below its historical value and busts ±15% (pursuer
first, drawing last). **Rec: honor the harder gate (per-type ±15%, D-RAT-3a) — size
`band_greybox.opposition_credits` to cover K5 demand (~37) + pursuer demand (~15–25) ≈ 55–65, and/or
reserve the pursuer's share with a DeckEntry `per_band_cap`; read D-RAT-3b's "~48" as "preserve density,"
not "hard-cap at 48."** The alternative (literal shared 48) is a **visible reduction** in total greybox
hazard density AND a per-type miss — a fun call the Director owns. **Decide before the pursuer's
`base_count`/`opposition_credits` are tuned** (it sets the equivalence-test pass threshold).

**C. `room_bounds` fidelity: deck `piece_bounds` (valid_cells-filtered) vs R1 `_piece_bounds_at_world` (all cells).**
*(Technical — resolve in Phase 3.)* The deck rect is computed from BUG7-filtered cells; the R1 rect uses
all cells. For pursuer hosts (depth ≥ 1, where the filter removes nothing) they match; for the rare
entry-adjacent case the deck rect is slightly smaller. *Rec: accept (pursuer hosts are depth ≥ 1); the
equivalence test pins the L2-patrol-works assertion, not the exact rect.*

**D. Is `legacy_ctx`'s new `&"pursuer"` arm a shared-deck-lane change that risks bands 2–4?**
*(Regression risk — resolve in Phase 3.)* `legacy_ctx` is called by every band's deck lane. The new arm
returns `room_bounds` for `&"pursuer"`. It only fires for a **spawning** pursuer; band_two's pursuer is
neutral → skipped → never reaches it (§a.3). So bands 2–4 are byte-unchanged **as long as no other band
authors a non-neutral pursuer card** — none does today. *Rec: low-risk; add a `test_band_two_profile`
assertion that band_two's pursuer stays skipped, so a future non-neutral pursuer card trips a test, not
a silent behavior change.*

**E. Delete `r1_enabled` (and re-express `all_oppositions_disabled()` + the BUG6 traps), or keep a minimal `r1_*` remnant?**
*(Technical + small scope — resolve in Phase 3.)* `r1_enabled` feeds `all_oppositions_disabled()`
(`:455-456`, the M1.0-baseline label used by 6 tests + telemetry) and the two BUG6 traps (`:676-685`).
Full deletion (the "one way" thesis) requires: (i) `all_oppositions_disabled()` drops the `r1_enabled`
term — recommend it reads deck-neutrality if a baseline label is still wanted, else `r2/r3/r4` only; (ii)
the `r1_no_spawn` / `r1_catch_radius_too_small` traps become pursuer-def param traps (the def already has
`param_schema` with `trap_if_neutral` on `catch_radius`, `pursuer.tres:60`) or are dropped as
no-longer-reachable. *Rec: full 18-knob deletion + re-express the predicate/traps — it is the thesis the
Director chose; the alternative (keep `r1_enabled` as an inert menu master) leaves a dead knob and a
half-migration.*

**F. The Hazards config tab may be empty after V3 (K5 half) + V3b (`r1_` half) both delete their members.**
*(Menu/bijection — resolve in Phase 3.)* The Hazards `TAB` (`config_menu.gd:220`) lists
`["r1_","hpp_","hbomb_","hspike_"]`. V3 removes the three K5 prefixes; V3b removes `r1_` → the tab has
no sections. *Rec: drop the Hazards tab entirely (its content is now data-authored on the deck), or
repurpose it — a menu-structure call. Confirm `has_full_coverage()` recomputes green at 50 legacy + 2
levers = 52; grep `tests/` for any hardcoded `Hazards` tab expectation.*

**G. Save-drop of the 18 `r1_*` `.tres` fields — any migration needed?**
*(Technical — resolve in Phase 3.)* RunConfig is **run-scoped, never persisted** (`run_config.gd:12-15`;
the meta save chain is separate) — dropping `@export`s needs **no meta bump** (stays v4). Godot silently
drops removed `@export`s on `.tres` reload. *Rec (binding build-notes, mirroring V3's OQ-D): (a)
regenerate `data/run_config/run_config.tres` after the deletion; (b) grep `tools/` + `tests/` +
telemetry for each of the 18 `r1_*` key names, confirm none is asserted downstream except the re-pinned
tests (§a.6); (c) the all-off `to_flat_dict` telemetry snapshot shrinks by 18 rows — confirm no analysis
asserts their presence.*

**H. Deck ORDER of the pursuer row vs the K5 rows (greedy budget spend).**
*(Technical — resolve in Phase 3.)* `_populate_deck` spends the shared budget greedily in eligible order
(`:322`); a later card starves if earlier cards exhaust the budget. *Rec: reserve the pursuer's share via
a DeckEntry `per_band_cap` (order-independent) rather than relying on row order; the equivalence test
pins the pursuer total regardless of where the row sits.*

---

## Expected debt ledger (the version's LARGEST single-file deletion)

Quantified for the **full 18-knob** migration (the Director's D-RAT-3 "fold all four" scope). V3b is
**additive to V3's ledger** — together they retire all three spawn machines.

| Deletion | Where | Approx LOC removed |
|---|---|---|
| R1 machine (`_spawn_r1_hazards` + J2/J3 stack + helpers) | `main_game.gd:486-492, 506-757, 776-789` (keep `_band_max_depth`) | **~250–290** |
| `:353` call site + `HAZARD_SCENE_PATH` | `main_game.gd:153, 353` | ~3 |
| **18 `r1_*` field declarations** (8 spawn/density + 10 entity; 2 enums) | `run_config.gd:59-126` | ~68 (declarations + doc comments) |
| 18 `to_flat_dict` telemetry rows | `run_config.gd:491-508, 590-591` | ~18 |
| 2 density consts | `run_config.gd:33, 37` | ~6 |
| 18 preset assignments (→ `param_overrides["pursuer"]`) | `run_config.gd:744-782` | ~40 net (→ ~12 override lines) |
| 2 BUG6 traps re-expressed / dropped | `run_config.gd:676-685` | ~10 |
| Config-menu `r1_` plumbing (SECTIONS, MANIFEST×18, RANGES, chip, TAB member, reflection) | `config_menu.gd:64, 89-100, 220, 246-260, 320, 1884-1887, +reflection` | ~40 |
| J2 + J3 golden tests deleted | `test_hazard_spread.gd`, `test_per_room_density.gd` | ~180 (both files) |
| **Gross deletion** | | **~600–650 LOC** |

| Addition (the cost of one-way) | Approx LOC added |
|---|---|
| band_greybox pursuer `DeckEntry` (data, in `.tres`) | ~6 (data) |
| `hazard_entity._resolve_params(spawn_ctx)` rewire + `DEFAULTS` + L2 `spawn_room_only` snapshot | ~30 |
| `rc.param_overrides["pursuer"]` preset block | ~12 |
| `legacy_ctx` `&"pursuer"` arm | ~3 |
| `all_oppositions_disabled()` + trap re-expression | ~8 |
| Equivalence test (`test_pursuer_deck_equivalence.gd`) + Step-0 fixture | ~110 |
| Behavior/verify golden re-pins (edits, ~net-zero LOC) | ~0 net |
| **Gross addition** | **~170 LOC** (~110 a new *test* + fixture, not product code) |

**Net product-code delta: strongly negative (~−400 to −450 LOC of machine/knob/menu/preset code
removed, ~−180 of J2/J3 golden test), against ~+60 product LOC of deck/entity/field additions + ~+110
of new equivalence test/fixture.** Combined with V3, **all three spawn machines are retired**, the
`RunConfig` surface drops another 18 knobs (V3's 91→70, then V3b's 70→52), the whole `r1_` config
section + (with V3) the Hazards tab disappear, and every opposition is added exactly one way. The
pursuer stops reading `RunConfig` directly — it reads the merged param bag like every modern hazard.
**"Exactly one way to add an opposition" is fully delivered.**

---

## RISK ASSESSMENT — why V3b is the version's highest-risk migration

The Phase-3 resolver ranked the pursuer migration **above** V3's K5 lane as the version's top
regression risk. This design confirms that ranking. In a version whose whole thesis is *"retire debt
WITHOUT moving the game,"* V3b is the one task that **structurally cannot be made byte-identical** —
it is a genuine, if licensed, behavioral change. The risks, and what the equivalence proof must cover:

1. **The deck lane is a strictly less expressive placer than the R1 machine.** It has no J3 area-scaled
   per-room density and no single_gate/curve depth modes. The migration reproduces the pursuer's
   per-type **total** (tunable) but **not** its spatial density structure (big-room clustering → flat
   even-spread). This is the #1 risk: the greybox *feel* of the pursuer shifts. **Mitigation:** the play
   preset uses J2 even_spread (reproducible) not single_gate/curve; D-RAT-3a licenses "deeper/even
   spread." **The proof must show** the per-depth histogram is monotonic + within-total, AND must state
   in writing that J3 clustering is folded (so the Director signs off knowing).

2. **The D-RAT-3a/3b budget tension (Open Question B) can silently starve the pursuer.** If
   `opposition_credits` is sized only for K5 and the pursuer draws last, its total collapses and ±15%
   fails — or worse, passes a mis-tuned threshold. **The proof must show** the pursuer's total is
   independently reserved (DeckEntry `per_band_cap`) and hits ~15–25 regardless of deck order.

3. **The L2 patrol silently degrades to chase-everywhere if the `legacy_ctx` arm is missed** (§a.4) —
   a *behavior* regression that no layout fp catches. **The proof must include a hard assertion** that a
   deck-spawned pursuer receives `room_bounds.has_area() == true`.

4. **The behavior rewire (`cfg.r1_*` → `spawn_ctx["params"]`) must be exactly value-preserving.** Any
   key-name mapping slip (`catch_radius`→`contact_radius`, `catch_kills`→`kills`, the L2
   `spawn_room_only` read) changes pursuer behavior. **The proof is `trace_pursuer_room.txt` staying
   byte-identical** — a moved byte there is a rewire bug, not a sanctioned change.

5. **Cross-band bleed** — the pursuer is a live (neutral) card in band_two's deck (`band_two.tres:70`).
   Adding spawn counts to the **shared def** (instead of the band_greybox DeckEntry) would spawn
   pursuers in band_two. **Mitigation:** counts go on the band_greybox-only DeckEntry / `rc.param_overrides`,
   never the shared def; a `test_band_two_profile` assertion locks band_two's pursuer as skipped.

6. **Layout fingerprints stay byte-identical BY CONSTRUCTION** — `Band.fingerprint()`
   (`systems/bandgen/band.gd:58-62`) hashes only placed pieces; hazards are pure run-state placed after
   grading and never feed it (§a of V3, item 3). A moved layout fp here is a **bug**, not a deviation.
   The ONE sanctioned change is the greybox pursuer-SPAWN golden.

**The equivalence proof (Step 6) is the entire safety case** and MUST cover, as hard gates: type
coverage, L2 room-bounds present, entry safety, caps, determinism, and the `trace_pursuer_room`
byte-identity; and, within ±15% + a documented density-fold note: the pursuer per-type total +
monotonic distribution. **Ordering is non-negotiable: capture the Step-0 pursuer fixture from the LIVE
R1 machine BEFORE deleting anything** — the frozen fixture is the only ground truth, and deleting first
forfeits it.

> **Coordination with V3:** V3b is BlockedBy V3 and shares its worktree conventions. V3 authors the
> band_greybox deck skeleton + `BandProfile.opposition_credits` + the `_deck_all_neutral` `is_inert`
> fast-path; V3b **appends** the pursuer row to that deck, **reuses** the neutral-card/all-off mechanism,
> and **re-sizes** `opposition_credits` per Open Question B. The `opposition_credits` value is set once
> (V3 for K5, re-tuned by V3b to cover K5 + pursuer) — the two tasks must agree on the final number at
> the Wave-4 close-out where both equivalence proofs are presented together for the single D-RAT-3
> sign-off.

---

## Resolved Decisions (Phase 3)

> **Fresh-eyes resolution (2026-07-10).** A resolver who did NOT author this design read it against
> the as-built tree and **verified every load-bearing claim from primary sources** before resolving.
> This section is **binding**: it locks the eight technical Open Questions (A, C, D, E, F, G, H, and
> the golden-capture ordering) into an unambiguous contract for the build agent, and escalates the one
> genuine density/fun call — **OQ-B, the D-RAT-3a/3b reconciliation** — to the Director under **Needs
> Director review** with a firm recommendation. The design's central survey findings are **CONFIRMED**;
> one substantive correction (**`DeckEntry` has no `per_band_cap` field** — the reservation mechanism
> must be re-stated) is folded into OQ-H below.

### Verification log (claims checked against the real tree, 2026-07-10)

Every factual claim the design rests on was re-checked; **all held** (one substantive correction, no
factual error):

1. **18 `r1_*` knobs — CONFIRMED.** Exactly 18 `@export var r1_*` fields in `run_config.gd`
   (`grep -cE '\bvar r1_'` = 18): the 10 entity knobs (`r1_enabled` :59, `r1_depth_threshold` :61,
   `r1_linger_seconds` :63, `r1_chase_speed` :65, `r1_speed_per_depth` :67, `r1_catch_radius` :72,
   `r1_catch_radius_per_depth` :77, `r1_catch_kills` :79, `r1_spawn_room_only` :122, `r1_patrol_speed`
   :126) + the 8 spawn/density knobs (`r1_spawn_count` :81, `r1_spawn_distribution` :88 **@export_enum**,
   `r1_spread_min_depth` :92, `r1_per_room_density` :99, `r1_density_metric` :105 **@export_enum**,
   `r1_density_rooms_only` :108, `r1_density_min_area` :112, `r1_density_per_room_cap` :116). The 19th
   `@export` hit is the `@export_group("R1 Pursuing Hazard", "r1_")` header at :57, not a field. §a.2 is
   exact.
2. **`_populate_deck` already passes `piece_bounds` — CONFIRMED; the only ctx change is one `match` arm.**
   `_populate_deck` computes `piece_bounds[pi] = _floor_bounds_world(cells, svc)` (`:320`) and passes it
   as the 5th arg: `legacy_ctx(d.id, p, k, spawned_total, piece_bounds[pi])` (`:363`); it also threads
   `ctx["params"] = params` (`:367`) and `ctx["room_key"]` (`:366`). `legacy_ctx` (`:110-121`) returns
   `room_bounds` **only** for `&"pingpong"`; `&"spike"` returns `phase_salt`; **default (bomb AND
   `&"pursuer"`) → `{}`** — so the pursuer's computed bounds are **discarded**. The minimal fix is exactly
   one arm: `&"pursuer": return { "room_bounds": room_bounds }`, **no `_populate_deck` change**. §a.4 is
   correct.
3. **kills/catch_kills key mismatch — CONFIRMED.** `pursuer.tres` `params` carries the 8 behavior keys
   (`catch_radius`, `catch_radius_per_depth`, `chase_speed`, `depth_threshold`, `linger_seconds`,
   `patrol_speed`, `spawn_room_only`, `speed_per_depth`) and **no `catch_kills`**; the def **top-level**
   `kills = false` (`:85`). The play preset sets `c.r1_catch_kills = true` (`:751`). The entity's
   `_resolve_params` reads `cfg.r1_catch_kills → "kills"` (`hazard_entity.gd:119`) and
   `cfg.r1_catch_radius → "contact_radius"` (`:116`). §a.3 item 3 is exact — the rewire must source
   `kills` from `params["catch_kills"]` (DEFAULTS fallback `false`), and the play preset's
   `param_overrides["pursuer"]` must carry `catch_kills = true`. Do **not** rely on the def top-level
   `kills`.
4. **Layout fps hazard-free — CONFIRMED.** `Band.fingerprint()` =
   `sha256("piece_id@offset_cell#mated_socket_index" joined)` (`systems/bandgen/band.gd:58-62`). No
   hazard/opposition/count enters it. All four layout fps stay **byte-identical by construction**; a
   moved layout fp here is a **bug**, not a deviation.
5. **Pursuer is ADDITIVE, not inside the 48 — CONFIRMED (the OQ-B premise).** `pursuer.tres`
   `cap_group = &""`, `per_room_cap = 0`, `per_band_cap = 0`. `spawn_service._caps_allow`
   (`:245-258`) skips the group-ceiling tier entirely when `def.cap_group == &""` (`:247`), so the
   pursuer's bodies were **never** counted against the K5 `&"new_hazards"` ceiling of 48
   (`NEW_HAZARD_BAND_CEILING = 48`, `:43`). Its J3 stack had its own separate ceiling
   (`R1_DENSITY_BAND_CEILING = 64`). So today's greybox pursuer count (J2 5 + J3 ~10–20 ≈ **15–25**) sits
   **on top of** the K5 ~37 — the historical greybox total is **~52–62 bodies**, not 48. This is the
   arithmetic that makes D-RAT-3a and a literal D-RAT-3b "~48" mutually exclusive (OQ-B).
6. **`all_oppositions_disabled()` + BUG6 traps — CONFIRMED.** `all_oppositions_disabled()` (`:455-456`)
   = `not (r1_enabled or r2_enabled or r3_enabled or r4_enabled)`. The two BUG6 traps (`:676-685`) read
   `r1_enabled`/`r1_spawn_count` (`r1_no_spawn`) and `r1_enabled`/`r1_spawn_count`/`r1_catch_radius`
   (`r1_catch_radius_too_small`, gated `< 24.0`). §a.2 entanglements are exact.
7. **band_two cross-band coupling — CONFIRMED** (`band_two.tres:70`). Its `opposition_deck` lists the
   four legacy defs as plain `ExtResource` refs (charger is a `deck_entry_charger` `DeckEntry` wrapper).
   The pursuer ref is authored **neutral** (no `base_count`/`count_per_depth`, all params 0) → deck
   demand 0 → skipped at `_populate_deck:333-334` → never spawns. Putting spawn counts on the shared def
   would move band_two; putting them on the band_greybox DeckEntry / `rc.param_overrides` does not.
8. **`DeckEntry` has NO `per_band_cap` field — SUBSTANTIVE CORRECTION to Step 1 / OQ-H.**
   `data/bands/deck_entry.gd` declares **only** `@export var def: Resource` + `@export var
   param_overrides: Dictionary`. `_authored_deck` (`:389-403`) unwraps `raw = entry.def` (the **shared**
   def) and records only `param_overrides` into `deck_overrides`. `_populate_deck` reads `d.per_band_cap`
   (`:339`) and `_caps_allow` reads `def.per_band_cap` (`:246`) **off the shared def object** — neither
   consults `param_overrides`. Therefore "reserve the pursuer's share via a **DeckEntry** `per_band_cap`"
   (Step 1 bullet 3, OQ-H rec) is **not implementable as written**. The corrected mechanism is in OQ-H
   below (size `opposition_credits`; put any `per_band_cap` bound on the **shared `pursuer.tres`** — safe
   because band_two's pursuer is neutral-and-skipped, exactly V3's OQ-F "cap-on-the-shared-def" pattern).
9. **Preset magnitudes — CONFIRMED** (`run_config.gd:744-782`): `depth_threshold 1`, `linger 8.1`,
   `chase_speed 56`, `speed_per_depth 5.0`, `catch_radius 24.0`, `catch_radius_per_depth 1.0`,
   `catch_kills true`, `spawn_count 5`, `distribution 1 (even_spread)`, `spread_min_depth 1`,
   `per_room_density 1.0`, `density_metric 0`, `density_rooms_only false`, `density_min_area 64`,
   `density_per_room_cap 3`, `spawn_room_only true`, `patrol_speed 28.0`. The Step-3 `param_overrides`
   bag matches these exactly.

### OQ-A — Deck lane can't reproduce J3 area-scaled density / single_gate / curve → **RESOLVED: proceed; the density-fold is licensed and MUST be documented in the equivalence proof.**

The play preset uses J2 `even_spread` (mode 1, `:759`) — reproducible by the deck's even-spread — and
`single_gate`/`curve` are preset-OFF (verified `:759`), so dropping them is behavior-preserving for the
shipped config. The one real fidelity loss is **J3 area-scaled per-room density** (big rooms cluster more
pursuers): the deck lane has no area-scaled per-room budget, so those bodies fold into the flat
even-spread — the per-type **total** is preserved but the **big-room spatial clustering is not**.
**D-RAT-3a explicitly licenses this** ("greybox hazards spread slightly deeper; deck even-spread ≠
per-piece formula"). **Binding:** proceed; the equivalence test (Step 6) MUST state in writing that J3
clustering is folded to even-spread, and the per-depth histogram (monotonic + within-total) is the
distribution proof. This is the version's single largest behavioral delta, so it is surfaced concretely
to the Director **as part of the D-RAT-3a close-out sign-off** (not a separate call) — the resolver does
not self-approve the *fun* of the shift, only confirms it is inside the ratified bar.

### OQ-C — `room_bounds` fidelity: deck `piece_bounds` (valid_cells-filtered) vs R1 `_piece_bounds_at_world` (all cells) → **RESOLVED: accept.**

The deck's `piece_bounds[pi]` is computed from `svc.valid_cells(...)`-filtered cells (BUG7 entry-safe
cells removed, `:315`); the R1 machine used all sorted cells. `_populate_deck` skips `depth_index <= 0`
pieces (`:313`), so every real pursuer host is at depth ≥ 1 where the BUG7 filter removes nothing → the
deck rect equals the R1 rect for every host that can actually carry a pursuer. **Binding:** accept; the
equivalence test asserts `ctx["room_bounds"].has_area() == true` (L2 patrol works), **not** the exact
rect — a slightly-smaller rect for a hypothetical entry-adjacent host is out of the host set and immaterial.

### OQ-D — Does the new `legacy_ctx` `&"pursuer"` arm risk bands 2–4? → **RESOLVED: low-risk; add a band_two guard assertion.**

`legacy_ctx` is called by every band's deck lane, but the new arm only returns `room_bounds` for a
kind that **actually reaches it**, and a pursuer reaches it only when its card is **non-neutral**
(demand > 0). band_two's pursuer is a neutral plain ref → skipped at `_populate_deck:333-334` → never
reaches `legacy_ctx`. No other band authors a non-neutral pursuer today (verified: only band_greybox
gets the spawn counts, and only via the band_greybox DeckEntry / `rc.param_overrides`). **Binding:**
add a `test_band_two_profile` assertion that band_two's pursuer stays **skipped** (demand 0, spawns 0)
— so a *future* non-neutral pursuer card trips a test rather than silently changing bands 2–4. With that
guard, bands 2–4 are byte-unchanged.

### OQ-E — Delete `r1_enabled` + re-express `all_oppositions_disabled()` + the BUG6 traps? → **RESOLVED: full 18-knob deletion; re-express the predicate and drop the traps.**

The Director's D-RAT-3 ("fold all four → exactly one way to add an opposition") requires the **full**
18-knob deletion; a retained `r1_enabled` menu-master would leave a dead knob and a half-migration.
**Binding:**
- **`all_oppositions_disabled()`** drops the `r1_enabled` term. The predicate is the M1.0-baseline label
  read by telemetry + 6 tests; keep it well-defined by returning `not (r2_enabled or r3_enabled or
  r4_enabled)` **and** deck-neutrality for the active profile if a baseline label is still wanted. Since
  the pursuer is now a deck card whose all-off state is already covered by the `_deck_all_neutral`
  fast-path (V3's OQ-B resolution, reused here), the `r2/r3/r4`-only predicate is sufficient for the
  telemetry label; re-point the 6 tests (`test_run_config`, `test_rg1_m13_verify`, `test_config_menu`, …)
  to the new shape.
- **BUG6 traps** (`r1_no_spawn`, `r1_catch_radius_too_small`): **drop both.** They are unreachable once
  `r1_enabled`/`r1_spawn_count`/`r1_catch_radius` no longer exist on the config surface. The
  catch-radius-too-small concern is **already covered** by `pursuer.tres`'s `param_schema`
  `trap_if_neutral: true` on `catch_radius` (`pursuer.tres:62`) — the def-schema trap is the modern,
  data-driven equivalent, so no trap logic is lost. (If a build-time check on the play-preset
  `param_overrides["pursuer"]` catch_radius ≥ 24 is later wanted, it belongs in the def/preset verify
  test, not a RunConfig trap.)

### OQ-F — The Hazards config tab may be empty after V3 + V3b → **RESOLVED: drop the Hazards tab; keep the bijection green.**

The Hazards `TAB` (`config_menu.gd:220`) lists `["r1_","hpp_","hbomb_","hspike_"]`. V3 removes the three
K5 prefixes; V3b removes `r1_` → the tab has no sections. **Binding:** drop the Hazards tab entirely (its
content is now data-authored on the deck) rather than ship an empty tab. This is a cosmetic
menu-structure edit with **zero gameplay effect**, so the resolver settles it on merit; the Director may
override the *presentation* at close-out. Confirm `has_full_coverage()` + `has_full_def_coverage()`
recompute green at the reduced surface (V3 68→ then V3b →50 legacy + 2 levers = 52), and
`grep -rn "Hazards" tests/` to catch any hardcoded tab expectation before deleting.

### OQ-G — Save-drop of the 18 `r1_*` `.tres` fields → **RESOLVED: no save bump.**

RunConfig is **run-scoped, never persisted** (`run_config.gd:12-15`; the meta save chain in
`save_manager.gd` is entirely separate) — dropping `@export`s changes no persisted schema and needs no
meta migration (stays v4). Godot silently drops removed `@export`s on `.tres` reload. **Binding
build-notes** (mirroring V3's OQ-D): (a) regenerate `data/run_config/run_config.tres` after the deletion
(re-saves with 18 fewer stored properties); (b) `grep -rn` the 18 `r1_*` key names across `tools/` +
`tests/` + telemetry and confirm none is asserted downstream except the re-pinned tests (§a.6);
(c) the all-off `to_flat_dict` telemetry snapshot shrinks by 18 rows — confirm no analysis asserts their
presence.

### OQ-H — Deck order vs greedy budget spend, and how to reserve the pursuer's share → **RESOLVED (with the DeckEntry correction): size `opposition_credits` to cover BOTH; any `per_band_cap` bound goes on the shared `pursuer.tres`, not the DeckEntry.**

`_populate_deck` spends the shared budget greedily in eligible order (`:324-370`); a later card gets **0**
if earlier cards exhaust the budget. The **correct** reservation mechanism is **budget sizing, not
`per_band_cap`**: if `band_greybox.opposition_credits` is sized to cover the **total** demand (K5 ~37 +
pursuer ~15–25 ≈ **55–65**), then even with the pursuer drawing last the remaining budget = its full
demand → order becomes immaterial. `per_band_cap` only **bounds the max**; it does not guarantee a
minimum, so it cannot by itself make placement order-independent (verification item 8 corrects the
design's OQ-H phrasing).

Two binding consequences of verification item 8:
- **`per_band_cap` (if used as a max-bound) goes on the shared `pursuer.tres`, NOT the DeckEntry** —
  `DeckEntry` has no `per_band_cap` field, and `param_overrides` is not consulted by the cap checks.
  Setting `pursuer.tres.per_band_cap = <historical count>` is **provably inert for band_two** (its
  pursuer is neutral → demand 0 → skipped → the cap never binds), exactly V3's OQ-F "cap-on-the-shared-def
  because band_two's card is neutral" pattern.
- **Spawn counts** (`base_count`/`count_per_depth`) DO flow through `param_overrides` → `_effective_params`
  → the demand math (`:331-332`), so they ride the band_greybox DeckEntry / play-preset
  `rc.param_overrides` correctly (Step 1/Step 3 stand). Keep the DeckEntry counts **neutral (0)** and put
  the play spawn counts in `rc.param_overrides["pursuer"]`, so the `_deck_all_neutral` all-off fast-path
  covers the pursuer (Step 1's all-off resolution is correct and unchanged).

**Binding:** author the pursuer row **last** in the deck (fine, given adequate budget); size
`opposition_credits` per OQ-B (Director) to cover K5 + pursuer; optionally set
`pursuer.tres.per_band_cap` to the pursuer's historical count as a max-bound. The equivalence test pins
the pursuer total regardless of row position.

### Golden-capture-before-delete ordering → **RESOLVED (binding sequence): capture BEFORE delete; two distinct goldens.**

Two separate ground-truth artifacts, both captured/frozen **before** any deletion:
- **The Step-0 pursuer PLAN fixture** (`tests/goldens/pursuer_r1_plan.json` or `.txt`): run the **live R1
  machine** once against the fixed hand-built graded bands at the play-preset `r1_*` magnitudes, record
  the J2 depth list + positions, the J3 position/bounds plans, the per-band total, and the per-depth
  histogram. This is the equivalence test's ground truth; deleting first forfeits it.
- **`tests/goldens/trace_pursuer_room.txt`** (the per-frame patrol BEHAVIOR trace): it already exists;
  it MUST stay **byte-identical** after the Step-2 rewire (`cfg.r1_*` → `spawn_ctx["params"]`), because
  the rewire is value-preserving (same params in → same behavior out). A moved byte there is a rewire
  bug, not a sanctioned change.

**Binding sequence within the V3b worktree:** (1) capture the Step-0 plan fixture from the live R1
machine + commit; (2) author the band_greybox pursuer DeckEntry + the `legacy_ctx` `&"pursuer"` arm +
the `hazard_entity` rewire + `rc.param_overrides["pursuer"]` (green against the still-live machine where
possible); (3) delete the R1 machine + the 18 `r1_*` knobs + the config-menu plumbing; (4) re-pin the
goldens against the frozen fixture (delete `test_hazard_spread` + `test_per_room_density`; re-point
`test_pursuing_hazard` + the `trace_pursuer_room` driver to `spawn_ctx["params"]`; re-pin the verify
matrices + `test_config_menu` counts); (5) full suite green. Ordering is non-negotiable.

### Layout-fingerprint safety → **CONFIRMED byte-identical (all four controls).**

Per verification item 4, `Band.fingerprint()` hashes only placed pieces; hazards are pure run-state
placed after grading and never feed it. The all-off + greybox/two/three layout fps are structurally
invariant to everything V3b does. A layout-fp move is a **bug**. The ONE sanctioned spawn change is the
greybox pursuer-SPAWN golden (re-pinned with the equivalence proof).

### Needs Director review

**NDR-V3b-1 — OQ-B: the D-RAT-3a (±15% per-type) vs D-RAT-3b (~48 shared budget) reconciliation. THE load-bearing call. Recommendation: honor ±15% per-type; size `opposition_credits` to cover K5 + pursuer; read "~48" as "preserve density," not "hard-cap 48."**

The two ratifications **cannot both hold literally** for the pursuer, and the reason is now
**verified from the code** (verification item 5): the pursuer's historical greybox footprint (J2 `spawn_count
= 5` **plus** J3 density ≈ 10–20 ⇒ **~15–25 bodies**) has **always been ADDITIVE on top of** the K5
ceiling — `pursuer.tres` `cap_group = &""` means the 48 `new_hazards` ceiling never counted it
(`spawn_service.gd:247`), and its J3 stack had a **separate** `R1_DENSITY_BAND_CEILING = 64`. So today's
greybox total is **~52–62 bodies (K5 ~37 + pursuer ~15–25)**, not 48. Forcing all four types into a
single literal 48-credit pool compresses every per-type total below its historical value and **busts the
±15% gate for the pursuer** (it draws last → starves first).

- **D-RAT-3a** (breakdown :488-490): exact type coverage + per-type totals within **±15%** + monotonic
  distribution proxy.
- **D-RAT-3b** (breakdown :492-494): "band_greybox keeps its **~48-body budget**… Applies to **both** the
  K5 and pursuer budgets."

The two are reconcilable only by reading D-RAT-3b's "~48" as **"preserve the historical density"** (the
field's stated intent — *content-data preservation*) rather than a hard numeric cap. The resolver
**endorses the design's recommendation on merit**:

1. **Honor the harder, per-type gate (D-RAT-3a, ±15%)** as the equivalence PASS bar for the pursuer.
2. **Size `band_greybox.opposition_credits` to cover the SUM of all four types' historical demand** —
   K5 ~37 + pursuer ~15–25 ≈ **55–65** (exact number set by the Step-0 fixture at Wave-4 tuning). This is
   the mechanism that actually prevents starvation and makes deck order immaterial (OQ-H).
3. **Optionally bound the pursuer with `per_band_cap` on the shared `pursuer.tres`** (NOT the DeckEntry —
   it has no such field; safe for band_two because its pursuer is neutral-and-skipped).

**Why this needs the Director, not the resolver:** reading "~48" as "≈55–65" is the *only* way to keep
the pursuer's historical density AND the ±15% per-type gate — but it means the greybox credit budget
V3 set for K5 is **re-sized upward** by V3b, and the alternative (a literal shared 48) is a **visible
reduction** in total greybox hazard density plus a per-type miss. That is a **fun/density call the
Director owns.** **Decide before the pursuer's `base_count`/`count_per_depth` and the final
`opposition_credits` are tuned** — it sets the equivalence-test PASS threshold and the single
`opposition_credits` number V3 and V3b must agree on at the Wave-4 close-out. The resolver's judgment:
preserving the historical ~52–62-body greybox density with a per-type-honest budget is truer to the
version's "retire debt **without moving the game**" thesis than a literal 48 that visibly thins the
greybox — **recommend option (1)+(2)+(3).**

> **Everything in OQ-A/C/D/E/F/G/H, the golden-capture ordering, and the layout-fp safety is resolved on
> technical merit and needs no Director call.** With **NDR-V3b-1 (the budget reconciliation)**
> dispositioned — and folded into the same single D-RAT-3 sign-off as V3 at the Wave-4 close-out where
> both equivalence proofs are presented together — this design is **locked** for the build agent. The
> four LAYOUT fps stay byte-identical, the full suite must be green, and the pursuer spawn goldens are
> re-pinned with the density-fold equivalence documented.
