# V3 / R4 — Migrate the legacy hazard lane onto the deck lane (Phase-2 design)

> **Task:** M1.12 Wave 4 (solo, last). Assignee: general-purpose + game-director-designer
> (band_greybox deck authoring). BlockedBy: V2 (retired dual-emit opposition signals).
> **The version's single highest-risk task + its largest deletion.** The ONE sanctioned
> behavioral change (breakdown DR-3): band_greybox's hazard-SPAWN sequence changes when the
> K5 fair-share machine is replaced by a deck spender. Layout fingerprints stay byte-identical;
> hazard-spawn goldens are re-pinned with a documented equivalence proof + Director sign-off.
>
> **This doc is Phase-2 design only — it writes no code and edits no other file.** It surveys
> both lanes at file:line, enumerates the exact knobs to delete (with a real count), audits the
> def forms, proves the layout fps are safe, plans the migration + equivalence test + golden
> re-pin, and ends with the projected debt ledger. Its Open Questions are for Phase-3 fresh eyes
> + the Director (DR-3).

---

## 0. TL;DR — the scope determination this doc argues for

The survey turned up a fact the breakdown's one-line V3 card blurs: **there is no single
"legacy hazard lane." There are THREE spawn machines**, and only ONE of them is the lane the
task names:

1. **The K5 fair-share lane** — `encounter_builder.gd::_populate_legacy` (`encounter_builder.gd:177-240`)
   + `_legacy_active_specs` (`:248-270`) + `LEGACY_DEF_PATHS` (`:48-52`). Drives **pingpong /
   bomb / spike** off `rc.hpp_*/hbomb_*/hspike_*`. **This IS "the legacy hazard lane."**
2. **The R1 pursuer machine** — a *separate* system living entirely in `main_game.gd`:
   `_spawn_r1_hazards` (`:506-546`), `_hazard_spawn_depths` (`:734-757`), `_populate_room_density`
   (`:559-578`), `_density_spawn_positions` (`:643-681`), `_density_spawn_bounds` (`:588-617`),
   `_density_area` (`:689-694`), `_piece_bounds_at_world` (`:626-633`), `_density_cell_to_world`
   (`:723-725`). Drives the **pursuer** off `rc.r1_*`. Called at `main_game.gd:353`, a sibling of
   the K5 façade call at `:361`, **before and independent of EncounterBuilder**.
3. **The deck lane** — `encounter_builder.gd::_populate_deck` (`:297-371`). Bands 2–4. The target.

**DR-3's own equivalence framing names only machine 1** ("a deck spender draws differently than
the **K5 fair-share machine**") — it never mentions the R1 machine. Yet the V3 card's prose says
"fold the legacy **four** (pursuer / pingpong / bomb / spike)." These two facts are in tension.

**This doc's recommendation (Open Question A, needs-Director-review):**

> **Land V3 as the K5-lane migration now (pingpong / bomb / spike → band_greybox deck; delete
> `_populate_legacy` + the 21 `rc.h*_*` knobs). DEFER the pursuer/R1-machine retirement to a
> scoped follow-up (a new task, e.g. V3b or an M2-adjacent item).**

The K5 lane is a clean, in-scope, high-value deletion whose equivalence is *tractable* (the deck
spender and the fair-share machine share the `count = base + per_depth·depth` + stride-cells +
`spawned_total` fan skeleton). The R1 machine is (a) not "the lane," (b) structurally richer than
the deck lane in ways the deck lane **cannot** reproduce without *adding* code (single_gate/curve
depth modes, per-room area-scaled density, an L2 `room_bounds` ctx thread the deck lane does not
build for the pursuer kind), and (c) coupled to a **cross-band side effect** (its def `pursuer.tres`
is a live neutral card in `band_two`'s deck — see §3.4). Folding it now would turn V3 from "the
version's largest deletion" into a net-*add* of deck-lane placement complexity, at the highest
regression risk in the version, in the same wave. That is the opposite of what M1.12 is for.

The rest of this doc designs the **K5 migration** concretely and sketches the **pursuer**
follow-up so the Director can price the fork.

---

## (a) Research on the premise

### 1. The two lanes, at file:line

**`EncounterBuilder` (`systems/spawning/encounter_builder.gd`, 465 lines)** has ONE public entry,
`populate(band, profile, rc, svc)` (`:145-166`), which dispatches on the profile's
`opposition_deck`:

- **Non-empty deck → the DECK lane** (`_populate_deck`, `:297-371`). Budget =
  `floor(BASE_CREDITS · instability(band_depth))` where `BASE_CREDITS = 24` (`:38`) and
  `instability(d) = 1.0 + 0.15·(d-1)` (`:64-65`). Defs are filtered by `min_band` against
  `band_depth` (`:302`), demand per def is `Σ_pieces (base_count + floor(count_per_depth·depth))`
  read off the **effective** (merged) params (`:329-332`), the plan is bounded up front by
  `budget / credit_cost` and `per_band_cap` (`:336-340`), placements are **even-spread across the
  eligible-piece depth range** (`t = i/(n-1)`, `round(t·(P-1))`, `:347-351`), and a refused spawn
  never spends (`:368-370`). Param precedence: **def params < deck-entry overrides <
  rc.param_overrides** (`_effective_params`, `:437-451`).
- **Empty deck → the LEGACY lane** (`_populate_legacy`, `:177-240`): the **K5 fair-share machine**,
  relocated verbatim from the old `main_game._spawn_new_hazards`. Ceiling =
  `SpawnService.NEW_HAZARD_BAND_CEILING` (48, `:181`); it is split fair-share across the active
  types (`base_share = ceiling / n_active`, remainder to earlier descriptor-order types, `:183-194`);
  per type: `n = base + floor(per_depth·depth)`, clamped `per_room_cap → type_budget → ceiling` in
  that order (`:214-218`); pieces walked shallow-first so truncation starves the deepest first
  (`:204-208`); `spawned_total` is the cross-type accumulator threading the ping-pong golden-angle
  fan (`:228-239`). The active set + descriptor table come from `_legacy_active_specs` (`:248-270`),
  the ONLY place the `rc.hpp_/hbomb_/hspike_` names survive inside the builder, and defs load lazily
  from `LEGACY_DEF_PATHS` (`:48-52`, only pingpong/bomb/spike).

`is_inert(profile, rc)` (`:130-137`): true (→ zero service calls, the all-off guarantee) iff deck
empty **and** `oppositions_enabled` empty **and** `_legacy_active_specs(rc)` empty. **This is the
load-bearing all-off gate that keeps `e943ac9c8bc1` and the "all-off = no hazards" baseline.**

**The façade** `main_game.gd::_spawn_new_hazards` (`:453-468`) resolves the profile, calls
`is_inert` (returns before building the SpawnService when all-off, `:462-463`), arms the service +
the `&"new_hazards"` cap group at ceiling 48 (`:466-467`), and delegates to `builder.populate`. **It
already routes deck-vs-legacy purely off `profile.opposition_deck`** — so **giving band_greybox a
non-empty deck auto-routes it to the deck lane with zero façade edits.**

### 2. The exact `rc.h*_*` knobs to delete — the real count is **21**, not "~30"

`run_config.gd` declares (with line refs):

| Group | Fields | Count |
|---|---|---|
| **K5a `hpp_`** (`:298-312`) | `hpp_enabled`, `hpp_base_count`, `hpp_count_per_depth`, `hpp_speed`, `hpp_per_room_cap`, `hpp_kills` | **6** |
| **K5b `hbomb_`** (`:319-337`) | `hbomb_enabled`, `hbomb_base_count`, `hbomb_count_per_depth`, `hbomb_proximity_radius`, `hbomb_pulse_seconds`, `hbomb_blast_radius`, `hbomb_per_room_cap`, `hbomb_kills` | **8** |
| **K5c `hspike_`** (`:345-361`) | `hspike_enabled`, `hspike_base_count`, `hspike_count_per_depth`, `hspike_rotation_speed`, `hspike_arm_length`, `hspike_per_room_cap`, `hspike_kills` | **7** |
| | **TOTAL `rc.h*_*`** | **21** |

The breakdown's "~30 special-cased `rc.h*_*` knobs" is an over-count of the literal `h*_*` surface.
The "~30" is only reachable by *also* counting the **R1 pursuer SPAWN knobs** (`r1_spawn_count`,
`r1_spawn_distribution`, `r1_spread_min_depth`, `r1_per_room_density`, `r1_density_metric`,
`r1_density_rooms_only`, `r1_density_min_area`, `r1_density_per_room_cap` = **8**), giving
21 + 8 = **29 ≈ ~30**. That arithmetic is itself evidence the breakdown's mental model of V3
included retiring the pursuer machine — **but the K5-only migration deletes exactly 21**, and the
pursuer-inclusive migration deletes 29 (plus optionally the 10 pursuer *entity* knobs, → 39). See
Open Question A for the disposition; the ledger (§end) quantifies both.

Each `rc.h*_*` field also has plumbing that must go with it:
- **Telemetry stamp** rows in `to_flat_dict()` (`run_config.gd:558-578`) — 21 rows, one per field.
- **Config-menu manifest** `_MANIFEST["hpp_"/"hbomb_"/"hspike_"]` (`config_menu.gd:137-156`),
  the `SECTIONS` rows for the three prefixes (`config_menu.gd:74-76`), the Hazards `TAB` entry that
  lists them (`config_menu.gd:220`), the `RANGES` table entries (`config_menu.gd:293-309`), and the
  storage/reflection prefix list (`config_menu.gd:1977`).
- **The play-preset block** `make_default_play_preset()` (`run_config.gd:860-892`, the K5a/b/c
  magnitude assignments) — these move to the deck / `rc.param_overrides` (see §b).

### 3. Def audit — all four legacy hazards ALREADY have `OppositionDef` forms

`data/oppositions/` holds 11 `.tres`. The relevant four:

| Hazard | Def file | `id` | `host_scene` | `cap_group` | params (authored) | In `LEGACY_DEF_PATHS`? | In a band deck today? |
|---|---|---|---|---|---|---|---|
| pingpong | `pingpong.tres` | `&"pingpong"` | `pingpong_hazard.tscn` | `&"new_hazards"` | `base_count`, `count_per_depth`, `speed` (all **0/neutral**) | ✅ (`:49`) | band_two (plain ref) |
| bomb | `bomb.tres` | `&"bomb"` | `bomb_hazard.tscn` | `&"new_hazards"` | `base_count`, `count_per_depth`, `proximity_radius`, `pulse_seconds`, `blast_radius` (**0/neutral**) | ✅ (`:50`) | band_two (plain ref) |
| spike | `spike.tres` | `&"spike"` | `spike_hazard.tscn` | `&"new_hazards"` | `base_count`, `count_per_depth`, `rotation_speed`, `arm_length` (**0/neutral**) | ✅ (`:51`) | band_two (plain ref) |
| pursuer | `pursuer.tres` | `&"pursuer"` | `hazard_entity.tscn` | `&""` (no group) | `depth_threshold`, `linger_seconds`, `chase_speed`, `speed_per_depth`, `catch_radius`, `catch_radius_per_depth`, `spawn_room_only`, `patrol_speed` (**0/neutral**) — **NO `base_count`/`count_per_depth`** | ❌ (not a K5 lane member) | band_two (plain ref) |

So **no new def authoring is required** — the four defs exist. But **all four are authored
NEUTRAL** (every count/magnitude 0), and they are ALSO referenced by `band_two.tres`'s deck
(`band_two.tres:34`: pursuer, pingpong, bomb, spike as plain `ExtResource` refs). This is the
critical cross-band coupling (§3.4).

**Two behavioral gaps between each def form and its legacy code form (Open Question E):**

- **The K5 entities read `rc.h*_*` DIRECTLY, not `OppositionDef.params`.**
  `pingpong_hazard.gd::_resolve_params` (`:77-87`) reads `cfg.hpp_speed`, `cfg.hpp_kills`;
  `bomb_hazard.gd:80-83` reads `cfg.hbomb_proximity_radius/pulse_seconds/blast_radius/kills`;
  `spike_hazard.gd:65,78-82` reads `cfg.hspike_arm_length/rotation_speed/kills`. The docstring
  admits it: *"nothing reads OppositionDef.params at runtime in M1.9's legacy lane"*
  (`pingpong_hazard.gd:76`). **Deleting `rc.h*_*` therefore breaks these three entities' setup**
  unless they are rewired to read `spawn_ctx["params"]` — which is exactly what the **modern**
  def-driven entity already does: `charger_hazard.gd::_resolve_params(spawn_ctx)` reads
  `spawn_ctx.get("params", {})` (`charger_hazard.gd:112-113`), and the deck lane threads it via
  `ctx["params"] = params` (`encounter_builder.gd:367`). So the migration **rewires pingpong/bomb/
  spike `_resolve_params` from `cfg.h*_*` to `spawn_ctx["params"]`, adopting the charger pattern** —
  a small, well-precedented per-entity change, plus code-fallback DEFAULTS mirroring the authored
  `.tres` params (the charger's `DEFAULTS` mirror, `charger_hazard.gd:44-47`).
- **The pursuer def form is a *neutral card that never spawns via the deck*** — `pursuer.tres` has
  no `base_count`/`count_per_depth`, so on band_two its deck demand is 0 → skipped
  (`encounter_builder.gd:333-334`). The pursuer only "lives" through the R1 machine on band_greybox.
  Its entity `hazard_entity.gd::_resolve_params(cfg)` (`:110-119`) reads `cfg.r1_*` directly and
  `setup` reads `spawn_ctx["room_bounds"]` for L2 (`:90-97,153`). Migrating it to the deck would
  require (i) giving it deck counts, (ii) rewiring its `_resolve_params` to `spawn_ctx["params"]`,
  and (iii) making the deck lane thread `room_bounds` for the `&"pursuer"` kind — which today's
  `legacy_ctx` does NOT (see §5). This is the crux of why the pursuer is a bigger job.

### 4. Layout fingerprints are provably hazard-free — the four controls are SAFE

`Band.fingerprint()` (`band.gd:58-62`) hashes **only the placed-piece list**:
`"%s@%s#%d" % [p.piece_id, p.offset_cell, p.mated_socket_index]` joined + sha256. **No hazard, junk,
opposition, or spawn-count enters it.** Hazards are pure run-state placed *after* generation onto the
already-graded band (the builder docstring: *"placement is pure run-state and never feeds
fingerprint()"*, `encounter_builder.gd:5-7`; the R1 machine docstrings echo it, e.g.
`main_game.gd:503`, `:731`). Therefore:

- The all-off `RunConfig` **layout** fp `e943ac9c8bc1`, and the `band_greybox` / `band_two` /
  `band_three` layout fps, are **structurally invariant to anything V3 does** — V3 changes only
  *which hazard nodes* get instantiated, never *which pieces* get placed. **All four stay
  byte-identical by construction, not by luck.**
- The all-off control's *hazard set also* stays empty: `is_inert` returns true for a band_greybox
  run with an all-off `rc` **as long as the deck cards are neutral** (base_count 0) — because
  `is_inert` checks `profile.opposition_deck.is_empty()` at `:133`. **This is the trap** (§b, Open
  Question B): a *non-empty* deck makes `is_inert` return `false`, so `_spawn_new_hazards` will now
  build the SpawnService node even on an all-off run. That does **not** move a layout fp, but it
  **does** change the all-off scene tree (a SpawnService node appears) and could spawn hazards if the
  deck cards carry magnitudes. The design keeps all-off byte-clean by making band_greybox's deck
  cards **neutral by authored default**, so an all-off run's demand is 0 → zero `svc.spawn` calls →
  zero hazard nodes (the SpawnService node itself is empty/harmless, but see Open Question B for
  whether even that empty node is acceptable vs. keeping an `is_inert` fast-path).

### 5. `legacy_ctx` — shared by both lanes, but pursuer-blind

`EncounterBuilder.legacy_ctx(kind, p, k, index, room_bounds)` (`:110-121`) builds the per-kind
entity ctx: `pingpong` → `initial_dir` (golden-angle fan) + `room_bounds`; `spike` → `phase_salt =
depth_index·131 + k`; **default (bomb AND any unlisted kind) → `{}`**. The deck lane calls it
(`:363`) and the legacy lane calls it (`:231`). **For `&"pursuer"` it falls through to `{}` — no
`room_bounds`.** So a pursuer spawned through the deck lane would get **no `room_bounds`**, and
`hazard_entity.gd:153` (`if _cfg.r1_spawn_room_only and _room_bounds.has_area()`) would fail the
`has_area()` guard → **the L2 spawn-room patrol silently degrades to chase-everywhere.** This is a
concrete behavioral regression that any pursuer→deck migration must fix by adding a `room_bounds`
arm for `&"pursuer"` in `legacy_ctx` **and** ensuring the deck lane passes `piece_bounds[pi]` for
it (it already computes `piece_bounds`, `:363`). It is *why* the pursuer migration is real work, not
a data edit.

### 6. The affected tests (the re-pin scope)

Eleven test files reference `rc.h*_*`. The migration's test impact:

- **`tests/test_new_hazard_spawn.gd`** (311 lines) — **THE K5 hazard-spawn golden.** Drives
  `mg._spawn_new_hazards(rc, band)` with `rc.hpp_/hbomb_/hspike_` set directly and asserts: all-off →
  0 nodes (i); base>0 → one per eligible room (ii); depth scaling monotonic (ii); per-room cap (iii);
  shared band ceiling 48 saturates (iv); determinism (v); per-kind ctx (vi); BUG7 entry-safety (vii).
  **This is the golden DR-3 re-pins** — post-migration it must drive the deck (a band_greybox-shaped
  deck profile + `rc.param_overrides`) instead of `rc.h*_*`, and its numeric asserts (e.g. "(iv)
  total == 48", "(ii) 2 nodes", "(iii) 4 nodes") change to the deck spender's equivalent numbers.
  Its ctx assertions (vi) survive unchanged (both lanes call `legacy_ctx`).
- **`tests/test_encounter_builder.gd`** (729 lines) — pins the legacy lane's fair-share plan
  (`_mirror_legacy_plan`, `:525-573`, sets `rc.hpp_/hbomb_/hspike_`) AND the deck-lane budget/
  eligibility/dedup/depth-spread. The **legacy-lane cases (2)/(3) are deleted** with `_populate_legacy`;
  the deck-lane cases stay; a **new band_greybox-deck equivalence case is added** (§b step 5).
- **`tests/test_config_menu.gd`** — asserts `legacy_exported.size() == 89` and `exported.size() == 91`
  (`:67`, `:73`) and full bijection coverage (`:39`, `:152`). After deleting 21 `rc.h*_*` fields:
  **89 → 68 legacy, 91 → 70 total** — these two literals re-pin, the `_MANIFEST`/`SECTIONS`/`TAB`/
  `RANGES` entries are removed, and `has_full_coverage()` must stay green at the reduced set.
- **`tests/test_run_config.gd`, `test_rg1_m14_verify.gd`, `test_rg1_m15_verify.gd`,
  `test_opposition_def_schema.gd`, `test_opposition_components.gd`** — reference `rc.h*_*` for
  preset/verify assertions; each is re-pointed to the deck/`param_overrides` form or the assertion
  moved to the def params.
- **`tests/test_bomb_hazard.gd`, `test_pingpong_hazard.gd`, `test_spike_hazard.gd`** — unit tests
  that set `rc.h*_*` then `entity.setup(rc, ...)`. Because the entities move to `spawn_ctx["params"]`,
  these are re-pointed to pass params via `spawn_ctx={"params": {...}}` (the charger unit-test pattern)
  instead of `rc.h*_*`. Behavior asserted (speed, blast, kills) is unchanged.

### 7. GDD/TDD grounding

"Content is data, not code" (TDD: items/recipes/enemies/bands/upgrades are `.tres` against
`class_name` scripts). The K5 fair-share machine + the `rc.h*_*` special-case are the last hazards
authored as **code + a bespoke RunConfig knob group** rather than **data**; the six newer hazards
(ambusher, burrower, charger, lobber, sentry, splitter) are already pure `OppositionDef` + `DeckEntry`.
V3 makes the **hazard-adding surface uniform**: one way (author a def, add a deck row) instead of two
(a def **or** a `rc.h*_*` group + a fair-share descriptor row + entity `cfg.h*_*` reads + menu
manifest rows). That is the "exactly one way to add an opposition" the breakdown's one-thing-to-prove
frames.

---

## (b) Pseudocode / plan

Ordered so the all-off + layout controls never move mid-step and each sub-change is independently
greenable.

### Step 1 — Author band_greybox's `opposition_deck` (game-director-designer)

Give `data/bands/band_greybox.tres` a K5 deck. **Cards are NEUTRAL by authored default** (so an
all-off run keeps demand 0 → zero hazards → baseline held; §4). The play magnitudes are supplied at
run time by `rc.param_overrides` (see step 4), NOT baked into the band — because baking them into the
band would (a) spawn hazards on an all-off greybox run, breaking "all-off = M1.0 loop," and (b) can't
sit on the shared `.tres` defs without moving band_two (§3.4). **Use `DeckEntry` wrappers** so any
band-only caps/costs ride the deck row, not the shared def.

Proposed `band_greybox.tres` deck (three `DeckEntry` rows, order = pingpong → bomb → spike to
preserve the fair-share remainder-priority + the golden-angle fan threading order):

```
opposition_deck = [
    DeckEntry(def=pingpong.tres, param_overrides={}),   # neutral; magnitudes via rc.param_overrides
    DeckEntry(def=bomb.tres,     param_overrides={}),
    DeckEntry(def=spike.tres,    param_overrides={}),
]
```

`credit_cost`/`per_band_cap`/`cap_group` stay on the **shared defs** at their current values
(cost 1, per_band_cap 0, cap_group `&"new_hazards"`) — unchanged, so band_two is untouched. The
per-room cap that the play preset used (`hpp_per_room_cap=2`, `hspike_per_room_cap=1`) migrates into
the play-preset's `rc.param_overrides` too, expressed as the def param the deck lane reads — see the
cap discussion in Open Question F (the deck lane honors `per_band_cap` on the def + the service
`per_room_cap`, but NOT a per-room cap passed in params today; this is a genuine gap the equivalence
test must confront).

**The budget problem (Open Question G, load-bearing).** band_greybox has `band_depth = 1`
(`band_greybox.tres:25`) → deck budget = `floor(24 · instability(1)) = floor(24·1.0) = 24`. The K5
fair-share machine's effective budget is the **ceiling 48** (`_populate_legacy` spends up to 48). The
play-preset's realistic K5 total was **~37** (the worked estimate in `run_config.gd:846-858`). A
24-credit budget at `credit_cost 1` caps band_greybox at **24 K5 spawns** — starving ~13 vs the
fair-share, roughly **−35%**, almost certainly outside any reasonable equivalence tolerance. Options
(the recommendation is G-i):

- **(G-i, recommended) Add an optional per-profile budget override to `BandProfile`** — e.g.
  `@export var opposition_credits: int = 0` (0 = use `BASE_CREDITS·instability`, the current
  behavior for every other band). Set `band_greybox.opposition_credits = 48` to mirror the fair-share
  ceiling. This is a **band-authoring field, not a RunConfig knob** → it does NOT touch the config
  menu, the bijection, or the 89/91→68/70 counts; it is neutral-by-default so band_two/three/four are
  byte-unchanged; and it never moves a layout fp (budget is hazard-side). `_populate_deck` reads it:
  `var budget = profile.opposition_credits if profile.opposition_credits > 0 else floor(BASE_CREDITS·instability(band_depth))`.
  Note the breakdown's "no new knob" guardrail is about **RunConfig** knobs (the config-menu surface);
  a band-content authoring field is the *content-is-data* direction the version endorses. Flag for
  Director confirmation anyway (it is technically a new field).
- **(G-ii) Bump `credit_cost` semantics / `BASE_CREDITS`** — rejected: `BASE_CREDITS` is shared, so
  bumping it moves band_two/three/four; `credit_cost` is on the shared def, so lowering it moves them
  too.
- **(G-iii) Accept the tighter count** — only if the Director rules ~24 "comparable enough." The
  equivalence test (step 5) would then pin the deck's ~24, not the fair-share's ~37, and DR-3 documents
  the intentional reduction. Lowest-code, but it is a *visible* (if minor) reduction in greybox hazard
  density — a fun-adjacent call the Director owns.

### Step 2 — Delete the fair-share machine (general-purpose)

In `encounter_builder.gd`, delete:
- `_populate_legacy` (`:177-240`), `_legacy_active_specs` (`:248-270`), `LEGACY_DEF_PATHS` (`:48-52`).
- The legacy branch of `populate` (`:160-166`): the `else:` that calls `_populate_legacy`. After
  deletion, `populate` is deck-only:

```
func populate(band, profile, rc, svc):
    if rc == null or band == null or svc == null: return
    var deck_overrides := {}
    var deck := _authored_deck(profile, deck_overrides)      # band_greybox now returns 3 defs
    var extras := _extras_defs(rc, deck)
    var effective := deck.duplicate(); effective.append_array(extras)
    if effective.is_empty(): return                          # deck-less + no extras → nothing
    _populate_deck(band, effective, band_depth, rc, svc, deck_overrides)
```

- `is_inert` (`:130-137`) drops its `_legacy_active_specs` clause → `return profile.opposition_deck.is_empty()
  and rc.oppositions_enabled.is_empty()`. (Open Question B: with band_greybox now carrying a deck,
  `is_inert` is `false` for greybox even all-off; keep the neutral-deck → zero-spawn property, and
  decide whether the empty-SpawnService-node on an all-off greybox run is acceptable or needs a
  "deck all-neutral" fast-path.)
- `legacy_ctx` (`:110-121`), `pieces_depth_sorted`, `piece_sorted_cells`, `instability`,
  `_floor_bounds_world` **STAY** (the deck lane uses them). `GOLDEN_ANGLE` stays.
- `BASE_CREDITS` stays (or is read alongside the new `opposition_credits`, step 1/G-i).

### Step 3 — Rewire the three K5 entities to `spawn_ctx["params"]` (general-purpose)

For `pingpong_hazard.gd`, `bomb_hazard.gd`, `spike_hazard.gd`: change `_resolve_params(cfg)` →
`_resolve_params(spawn_ctx)` reading `spawn_ctx.get("params", {})`, with a code-fallback `DEFAULTS`
mirroring the authored `.tres` params (the charger pattern, `charger_hazard.gd:44-47,112-113`). The
deck lane already threads `ctx["params"] = _effective_params(...)` (`:367`), so pingpong reads
`params["speed"]`, bomb reads `params["proximity_radius"/"pulse_seconds"/"blast_radius"]`, spike reads
`params["rotation_speed"/"arm_length"]`. The `*_kills` lethality: source it from the def's `kills`
field (already `true` on all three defs) or a `params["kills"]` override, replacing `cfg.h*_*_kills`.

```
# pingpong_hazard.gd (was: reads cfg.hpp_speed / cfg.hpp_kills)
const DEFAULTS := { "speed": 0.0, "kills": true }            # mirror pingpong.tres params
func _resolve_params(spawn_ctx: Dictionary) -> Dictionary:
    var dp: Dictionary = spawn_ctx.get("params", {})
    return {
        "speed": maxf(float(dp.get("speed", DEFAULTS.speed)), 0.0),
        "contact_radius": CONTACT_RADIUS,
        "kills": bool(dp.get("kills", DEFAULTS.kills)),
        "def_id": &"pingpong", "emit_family": &"new_hazard_killed",
        "lethal_mode": &"radius", "latch_rearm": true, "throw_mode": &"die",
    }
```

Add `"speed"` (and the bomb/spike magnitude keys, and `"kills"`) to each def's `params` so the deck
lane's `_effective_params` has them to merge — they already carry the count keys; add the entity-read
magnitude keys at neutral 0/true. (pingpong.tres already lists `speed`; bomb/spike already list their
magnitude keys — verify each `.tres` `params` has every key the rewired entity reads, else the code
fallback governs.)

### Step 4 — Move the K5 magnitudes from `rc.h*_*` into the play preset's `rc.param_overrides` (game-director-designer)

Delete the 21 `rc.h*_*` field declarations (`run_config.gd:298-361`), their `to_flat_dict` rows
(`:558-578`), and the K5a/b/c assignment block in `make_default_play_preset()` (`:860-892`). Replace
the preset block with `rc.param_overrides` entries keyed by def id, carrying the exact magnitudes that
were on the `rc.h*_*` fields:

```
c.param_overrides = {
    "pingpong": { "base_count": 0, "count_per_depth": 0.15, "speed": 70.0, "per_room_cap": 2 },
    "bomb":     { "base_count": 0, "count_per_depth": 0.15,
                  "proximity_radius": 64.0, "pulse_seconds": 2.0, "blast_radius": 48.0, "per_room_cap": 2 },
    "spike":    { "base_count": 1, "count_per_depth": 0.1,
                  "rotation_speed": 90.0, "arm_length": 48.0, "per_room_cap": 1 },
}
```

`_effective_params` (`:437-451`) merges these over the neutral def params, and `_populate_deck`'s
demand math + the entity `_resolve_params` both read the merged bag — so the preset's magnitudes drive
counts (deck lane) AND entity behavior (rewired entities) through ONE surface. The all-off default
(`RunConfig.new()`) has `param_overrides = {}` (`:428`) → neutral deck → zero hazards → baseline held.
(Open Question F: `per_room_cap` in params has no deck-lane consumer today; the deck lane uses def
`per_band_cap` + service `per_room_cap`. Either teach `_populate_deck` a per-room clamp from
`params["per_room_cap"]`, or move the cap onto the def's `per_room_cap`/`per_band_cap` — the
equivalence test must confirm the cap behavior matches.)

### Step 5 — The equivalence test (qa via general-purpose) — DR-3's proof

Add `tests/test_greybox_deck_equivalence.gd` (a SCENE test). It A/B's the **pre-migration K5
fair-share plan** against the **post-migration band_greybox deck plan** on the SAME hand-built graded
bands (the `test_new_hazard_spawn._make_band` shape) at the play-preset magnitudes, asserting the
equivalence bar (Open Question C sets the numbers). The bar:

1. **Type coverage (exact).** The set of spawned `def_id`s is identical: `{pingpong, bomb, spike}`
   both before and after. (Hard equality — a missing type fails.)
2. **Count / distribution (within tolerance ±T).** Per type, `|deck_count − fairshare_count| ≤
   max(1, ceil(T · fairshare_count))` on a representative band, AND the per-depth-bucket monotonicity
   the golden already asserts (deeper ≥ shallower for `count_per_depth > 0`) holds. Total across the
   three within ±T of the fair-share total (~37) OR of the accepted reduced total (per Open Question G).
3. **Entry safety (hard).** Zero hazards in the depth-0 entry piece; nearest spawn ≥
   `NEW_HAZARD_SPAWN_SAFE_CELLS · CELL` from entry (the golden's BUG7 case (vii) — the deck lane's
   `p.depth_index <= 0` skip at `:313` preserves it).
4. **Caps preserved (hard).** Total ≤ the `&"new_hazards"` ceiling (48); per-room ≤ the play-preset
   per-room cap (the F resolution).
5. **Determinism (hard).** Two deck builds → byte-identical position lists (both lanes are RNG-free).

The **pre-migration side** is captured as a golden snapshot fixture *before* deleting
`_populate_legacy` (run the old machine once against the fixed bands, record the counts/positions),
so the equivalence test compares the new deck against a *frozen record* of the old machine, not
against live legacy code (which is being deleted).

### Step 6 — Re-pin the goldens (general-purpose) — DR-3 sign-off artifact

- **`test_new_hazard_spawn.gd`**: re-point every `rc.h*_*` driver to a band_greybox-shaped deck
  profile + `rc.param_overrides`; update the numeric asserts (ii)/(iii)/(iv) to the deck spender's
  equivalent values (recorded from the equivalence run); (i) all-off → 0 and (vii) entry-safety and
  (vi) ctx stay as-is (ctx uses the unchanged `legacy_ctx`). Every changed number gets a one-line
  comment citing the equivalence test + DR-3.
- **`test_encounter_builder.gd`**: delete the legacy-lane cases (2)/(3) + `_mirror_legacy_plan`; keep
  the deck cases; add a band_greybox-deck case.
- **`test_config_menu.gd`**: 89 → 68, 91 → 70; drop the `hpp_/hbomb_/hspike_` manifest expectations;
  keep `has_full_coverage()` + `has_full_def_coverage()` green.
- The **DR-3 presentation** to the Director at the Wave-4 close-out = the equivalence-test output
  (type coverage table + per-type count deltas + the tolerance used) + the golden diff. The design
  does NOT lock V3 until the Director signs the re-pin (breakdown DR-3 status line).

### Step 7 — Config-menu + `run_config.gd` cleanup (general-purpose, with the entity/preset edits)

Delete from `config_menu.gd`: the three `SECTIONS` rows (`:74-76`), the three `_MANIFEST` blocks
(`:137-156`), the Hazards `TAB`'s `hpp_/hbomb_/hspike_` entries (`:220` — the tab keeps `r1_` if the
pursuer stays, else the tab is dropped), the `RANGES` entries (`:293-309`), and the reflection prefix
list entries (`:1977`). Confirm `has_full_coverage()` recomputes clean at 68 legacy + 2 levers = 70.
**No save-schema touch** — RunConfig is run-scoped, never persisted (`run_config.gd:12-15`), so
dropping fields needs no meta bump (Open Question D confirms the `.tres` reload behavior).

### (Deferred sketch) The pursuer/R1 follow-up — if the Director folds it into V3

Only if Open Question A resolves "include the pursuer." Additional work, sketched so it can be priced:
- Delete `_spawn_r1_hazards` + the entire J2/J3 density stack in `main_game.gd` (`:506-757`, ~250
  lines) + the `main_game.gd:353` call.
- Add `base_count`/`count_per_depth` to a **band_greybox-only DeckEntry override** for `pursuer.tres`
  (NOT the shared def — else band_two's neutral pursuer starts spawning, §3.4).
- Extend `legacy_ctx` (`:110-121`) with a `&"pursuer"` arm returning `{"room_bounds": room_bounds}`
  so L2 patrol survives (§5), and confirm the deck lane passes `piece_bounds[pi]` for it.
- Rewire `hazard_entity.gd::_resolve_params(cfg)` (`:110-119`) from `cfg.r1_*` to `spawn_ctx["params"]`.
- Accept a **weaker equivalence**: the deck lane has no single_gate/curve depth mode and no
  area-scaled per-room density, so the pursuer's placement WILL differ more than the K5 trio's. The
  play preset uses `even_spread` + `spread_min_depth=1` + `per_room_density=1.0` — the deck lane's
  even-spread approximates the first, drops the density budget entirely. This is a *real* distribution
  change the Director must accept.
- Delete the 8 `r1_spawn_*`/`r1_density_*` knobs (→ ledger 21+8 = 29) and, if the pursuer entity goes
  fully def-driven, the 10 `r1_*` entity knobs too (→ 39), re-pinning `test_per_room_density.gd` +
  the 89/91 counts accordingly.

---

## (c) Open Questions

**A. Scope: K5-only now, or the full "legacy four" (include the pursuer/R1 machine)?**
*(Scope / risk — needs Director review; this is the central call, adjacent to DR-3.)* The task card
says "the legacy four (pursuer/pingpong/bomb/spike)"; DR-3's equivalence framing names only the K5
fair-share machine; the "~30 knobs" count only closes if the R1 spawn knobs are included (§2). The
R1 machine is a *separate*, richer system (§0, §3.3, §5) whose deck migration is a net-add + a weaker
equivalence + a cross-band side effect, in the highest-risk wave. **Rec: land K5-only in V3; spin the
pursuer into a scoped follow-up (V3b).** If the Director wants the full four in V3, the deferred sketch
(§b) prices it. **Decide before dispatch** — it changes the ledger (21 vs 29–39 knobs), the test
re-pin scope, and whether `main_game.gd`'s J2/J3 stack is touched.

**B. All-off band_greybox now builds a (empty) SpawnService node.** A non-empty deck makes
`is_inert` return `false` (`:133`), so `_spawn_new_hazards` builds the service even all-off. With
neutral deck cards the demand is 0 → zero `svc.spawn` calls → zero hazard nodes, so no *hazard*
appears — but an empty `SpawnService` node now exists in the all-off greybox tree where none did
before. Layout fp is unmoved (§4); is the empty node acceptable, or does `is_inert` need a "deck is
all-neutral for this rc" fast-path to preserve the byte-exact all-off scene tree the golden harness
counts? *Technical — resolve in Phase 3; rec: add the fast-path (cheap, and it keeps the "all-off
loads/builds NOTHING" contract literally true).*

**C. Equivalence tolerance bar (DR-3's number).** Type coverage is exact + entry-safety/caps/
determinism are hard (§b step 5). What is ±T for count/distribution — ±10%? ±15%? per-type or total
only? And is a per-depth-bucket monotonicity check enough for "distribution," or does the Director
want a shape comparison? *Scope/risk — DR-3; rec: ±15% per-type total with hard type-coverage +
entry-safety + caps + determinism, monotonicity as the distribution proxy. Director sets the final T.*

**D. Dropping 21 `RunConfig` `.tres` fields without a save bump.** RunConfig is run-scoped, never
persisted (`run_config.gd:12-15`) → no meta-schema change, meta stays v4 (breakdown guardrail). But
`data/run_config/run_config.tres` (the all-off default asset) will have 21 fewer stored properties;
Godot drops unknown/removed `@export`s on reload silently. Confirm the `.tres` re-saves clean and the
all-off telemetry snapshot (`to_flat_dict`) shrinks by 21 rows with no consumer asserting their
presence. *Technical — resolve in Phase 3; rec: regenerate `run_config.tres`, grep telemetry/analysis
for the 21 key names, confirm none are asserted downstream.*

**E. Behavioral gaps between each legacy hazard's def form and its code form (§3.3).** (i) K5 entities
read `cfg.h*_*` directly, not params — the rewire to `spawn_ctx["params"]` (charger pattern) is the
fix; verify each `.tres` `params` carries every entity-read key. (ii) The pursuer def is a neutral,
never-spawning card whose real behavior lives in the R1 machine — only relevant if A includes it. (iii)
`legacy_ctx` is pursuer-blind (no `room_bounds`) → L2 patrol regression if the pursuer moves to the
deck (§5). *Technical — resolve in Phase 3 for the K5 rewire; the pursuer items gate on A.*

**F. Per-room cap on the deck lane.** The K5 fair-share honored `hpp_per_room_cap` etc.; the deck lane
clamps by the def `per_band_cap` + the service `per_room_cap`, and does NOT read a `per_room_cap` from
`params` today. To preserve the play-preset's per-room caps (2/2/1), either (i) teach `_populate_deck`
a per-room clamp from `params["per_room_cap"]`, or (ii) set the caps on the def `per_room_cap`
(service-side) / `per_band_cap` — but those are shared with band_two. *Technical — resolve in Phase 3;
rec: put the cap on the **DeckEntry**'s effect via a small `_populate_deck` per-room clamp keyed off
merged params, so it stays band_greybox-local and the equivalence test can pin it.*

**G. band_greybox deck budget (§b step 1).** `band_depth=1` → deck budget 24, but the fair-share
effective budget is the 48 ceiling and the realistic K5 total is ~37 → a 24-credit budget starves
~−35%, likely outside tolerance. *Design — needs Director confirmation for the new field; rec: G-i,
add an optional `BandProfile.opposition_credits` band-authoring field (0 = current behavior; set
band_greybox to 48). It is not a RunConfig/config-menu knob, is neutral for every other band, and
never moves a layout fp — but it is technically a new field, so confirm against the "no new knob"
guardrail (which targets the config surface, not content authoring).*

**H. Menu/bijection at the reduced knob set.** Deleting 21 fields moves the frozen counts 89→68 and
91→70 and removes three whole config sections + the Hazards tab's K5 half. `has_full_coverage()` +
`has_full_def_coverage()` must stay green; the `test_config_menu` literals re-pin. Confirm no other
test hardcodes 89/91. *Technical — resolve in Phase 3; rec: grep for `89`/`91` across `tests/`,
re-pin all, keep the two coverage assertions as the bijection guarantee at the smaller surface.*

---

## Expected debt ledger (the version's LARGEST deletion)

Net-negative LOC is the headline. Quantified for the recommended **K5-only** scope (Open Question A =
defer pursuer); the pursuer-inclusive figure is given in brackets.

| Deletion | Where | Approx LOC removed |
|---|---|---|
| Fair-share machine `_populate_legacy` | `encounter_builder.gd:177-240` | ~64 |
| Legacy adapter `_legacy_active_specs` | `encounter_builder.gd:248-270` | ~23 |
| `LEGACY_DEF_PATHS` + legacy branch of `populate` + `is_inert` legacy clause | `encounter_builder.gd:48-52,160-166,137` | ~14 |
| **21 `rc.h*_*` field declarations** (6 hpp + 8 hbomb + 7 hspike) | `run_config.gd:298-361` | ~64 (declarations + doc comments) |
| 21 `to_flat_dict` telemetry rows | `run_config.gd:558-578` | ~21 |
| K5a/b/c preset block (moves to `param_overrides`) | `run_config.gd:860-892` | ~33 net (block replaced by ~8 override lines) |
| Config-menu K5 plumbing (SECTIONS×3, MANIFEST×3 blocks, TAB, RANGES×14, reflection list) | `config_menu.gd:74-76,137-156,220,293-309,1977` | ~45 |
| Legacy-lane test cases + `_mirror_legacy_plan` | `test_encounter_builder.gd:~180-224,525-573` | ~90 |
| **Gross deletion** | | **~360–410 LOC** |

| Addition (the cost of one-way) | Approx LOC added |
|---|---|
| band_greybox deck (3 DeckEntry rows in `.tres`) | ~15 (data) |
| 3 K5 entity `_resolve_params(spawn_ctx)` rewires + DEFAULTS mirrors | ~30 |
| `rc.param_overrides` preset block | ~8 |
| `BandProfile.opposition_credits` field + `_populate_deck` read (G-i) | ~6 |
| `_populate_deck` per-room clamp (F) + `is_inert` neutral-deck fast-path (B) | ~12 |
| Equivalence test (`test_greybox_deck_equivalence.gd`) | ~90 |
| Golden re-pins (edits, roughly net-zero LOC — numbers change, not line count) | ~0 net |
| **Gross addition** | **~160 LOC** (~90 of it a new *test*, not product code) |

**Net product-code delta: strongly negative (~−250 to −300 LOC of machine/knob/menu/preset code
removed, ~−90 of legacy test), against ~+70 product LOC of deck/entity/field additions + ~+90 of new
equivalence test.** Duplication/coupling retired: **the second hazard-adding path is gone** (K5 defs
now added the same way as the six modern hazards — one deck row, no `rc.h*_*` group, no fair-share
descriptor, no entity `cfg.h*_*` read); **the config surface shrinks 91→70 knobs** (−21); **three
config sections + the Hazards-tab K5 half disappear**; **the K5 entities stop reading RunConfig
directly** (they read the merged param bag like every modern hazard). The "exactly one way to add an
opposition" invariant is delivered for the K5 trio and asserted by a doc/test note.

**If the Director folds in the pursuer (Open Question A = include):** add ~250 LOC deleted from
`main_game.gd`'s J2/J3 stack + 8 (or 18) more knobs deleted, against the deferred-sketch additions
(pursuer DeckEntry override, `legacy_ctx` pursuer arm, `hazard_entity` rewire, a weaker-equivalence
test) — a substantially larger net-negative but at materially higher regression risk and a weaker
equivalence bar (§b deferred sketch, Open Question A).

---

## Resolved Decisions (Phase 3)

> **Fresh-eyes resolution (2026-07-10).** A resolver who did NOT author this design read it against
> the as-built tree and **verified every load-bearing claim from primary sources** before resolving.
> This section is **binding**: it locks the technical Open Questions (B, C-partial, D, E, F, H, the
> golden-ordering, and the layout-fp safety) into an unambiguous contract for the build agent, and
> escalates the genuine scope/fun calls (OQ-A scope fork, OQ-C tolerance, OQ-G density) to the
> Director under **Needs Director review** with firm recommendations. The design's central survey
> finding — **three spawn machines, not one** — is **CONFIRMED**, and the K5-only recommendation is
> **endorsed on merit** (see NDR-V3-1).

### Verification log (claims checked against the real tree, 2026-07-10)

Every factual claim the design rests on was re-checked; **all held** (three trivial line-ref nits
noted, no substantive error):

1. **THREE spawn machines — CONFIRMED.** (1) `_populate_legacy` (K5 fair-share,
   `encounter_builder.gd:177-240`) + `_legacy_active_specs` (`:248-270`) + `LEGACY_DEF_PATHS`
   (`:48-52`, only pingpong/bomb/spike). (2) The R1 pursuer machine lives entirely in `main_game.gd`
   (`_spawn_r1_hazards` `:506`, called at `:353`), a **sibling of** the K5 façade call
   `_spawn_new_hazards` at `:361` — `:353` runs **before and independent of** EncounterBuilder.
   (3) `_populate_deck` (`:297-371`). `legacy_ctx`'s `default → {}` arm (`:120-121`) is **pursuer-blind**
   (no `room_bounds`) — confirmed. The design's §0 finding is correct.
2. **21 `rc.h*_*` knobs — CONFIRMED** (6 `hpp_` `:298-312`, 8 `hbomb_` `:319-337`, 7 `hspike_`
   `:345-361`). The R1 spawn-knob set (8: `r1_spawn_count/_spawn_distribution/_spread_min_depth/
   _per_room_density/_density_metric/_density_rooms_only/_density_min_area/_density_per_room_cap`) +
   the 10 `r1_*` entity knobs = **18** `r1_*` fields — so 21+8 = 29 ≈ "~30" only closes with the
   pursuer SPAWN knobs, exactly as §2 argues. The breakdown's "~30" over-counts the literal `h*_*`
   surface; **K5-only deletes exactly 21.**
3. **Layout fps hash only placed pieces — CONFIRMED.** `Band.fingerprint()` =
   `sha256("piece_id@offset_cell#mated_socket_index" joined)` (real path
   `systems/bandgen/band.gd:58-62`, **not** the doc's `data/bands/band.gd` — citation nit; claim
   correct). No hazard/opposition/count enters it. **All four layout fps stay byte-identical by
   construction** — V3 changes only which hazard nodes instantiate, never which pieces place.
4. **band_greybox `band_depth=1`, empty `opposition_deck` — CONFIRMED** (`band_greybox.tres:24-25`).
   → deck budget `floor(24·1.0) = 24`. The K5 fair-share effective budget is the 48 ceiling; the
   play-preset realistic total is **~37** (`run_config.gd:853` "Combined ≈ 37"). The budget
   starvation (OQ-G) is real: a 24-credit budget caps greybox at ~24, ≈ −35% vs ~37.
5. **Play-preset K5 magnitudes — CONFIRMED** (`run_config.gd:860-892`): hpp base0/perdepth0.15/
   speed70/cap2; hbomb base0/0.15/prox64/pulse2/blast48/cap2; hspike base1/0.1/rot90/arm48/**cap1**.
   The per-room caps (2/2/1) are **load-bearing for equivalence** — see F.
6. **K5 entities read `cfg.h*_*` directly — CONFIRMED** (pingpong `:77-87`, bomb `:78-88`, spike
   `:65`). The charger reads `spawn_ctx["params"]` + a `DEFAULTS` mirror (`:44-54,:112`). The rewire
   target pattern is real.
7. **band_two cross-band coupling — CONFIRMED** (`band_two.tres:70`, **not** `:34` — citation nit;
   `:34` is a flavor sub-resource). band_two's deck references pursuer/pingpong/bomb/spike as **plain
   `ExtResource` refs** (charger is a `DeckEntry` wrapper), all four defs authored **neutral**.
   Setting magnitudes on the shared defs would move band_two — confirmed the risk §3.4 names.
8. **config-menu counts — CONFIRMED** (`test_config_menu.gd:67` = 89 legacy, `:73` = 91 total). →
   68/70 after deleting 21.
9. **`BandProfile.opposition_credits` does not exist — CONFIRMED** (grep empty) → it is a genuinely
   new field (OQ-G).
10. **SpawnService per-room-cap machinery ALREADY EXISTS — CORRECTS the doc's OQ-F framing.**
    `spawn_service.gd:245-257` enforces `def.per_room_cap > 0` via `ctx["room_key"]`, and
    `_populate_deck` **already threads** `ctx["room_key"] = str(p.offset_cell)` (`:366`). So the deck
    lane is **not** cap-blind — it already honors `def.per_room_cap`. The only genuine gap is a
    `params["per_room_cap"]`, which is unnecessary (see F).

### OQ-B — All-off band_greybox builds an empty SpawnService node → **RESOLVED: add a neutral-deck fast-path to `is_inert` (design's rec).**

With a non-empty deck, `is_inert` returns `false` (`:133`) → the façade builds the SpawnService node
even all-off, which **breaks the literal "all-off loads NOTHING, builds NOTHING" contract** the
`is_inert` docstring states (`:124-129`), even though no layout fp moves and no hazard spawns
(neutral cards → 0 demand). **Fix:** replace the deleted `_legacy_active_specs(rc).is_empty()` clause
with a `_deck_all_neutral(profile, rc)` helper — the exact analog of the retired neutrality test.
It merges each deck card's params with its deck-entry overrides **and `rc.param_overrides`** (reusing
`_effective_params`) and returns `true` iff every card's effective `base_count <= 0` **and**
`count_per_depth <= 0` **and** `rc.oppositions_enabled` is empty:

```
func is_inert(profile, rc) -> bool:
    if rc == null: return true
    if not rc.oppositions_enabled.is_empty(): return false
    if profile == null or profile.opposition_deck.is_empty(): return true
    return _deck_all_neutral(profile, rc)   # NEW: band_greybox all-off → true (no service node)
```

This is band-agnostic and correct for **every** band: band_two's charger/splitter carry real
authored magnitudes → not neutral → `false` (band_two always builds — correct, unchanged); an
all-off greybox run → neutral → `true` (no SpawnService node — byte-exact all-off tree preserved);
the play-preset greybox run → `rc.param_overrides` non-neutral → `false` (builds — correct). It needs
only `(profile, rc)`, not the band, so it stays a cheap pre-flight. **This helper is the natural
replacement for the deleted `_legacy_active_specs` clause, not a bolt-on.**

### OQ-D — Drop 21 `RunConfig` `.tres` fields without a save bump → **RESOLVED: accept, no save bump.**

RunConfig is **run-scoped, never persisted** — the save chain (`META_SCHEMA_VERSION` in
`save_manager.gd`) is entirely separate; dropping `@export`s changes no persisted schema and needs no
meta migration. Godot silently drops removed `@export`s on `.tres` reload. **Binding build-notes:**
(a) regenerate `data/run_config/run_config.tres` after the field deletion (it re-saves with 21 fewer
stored properties); (b) grep `tools/` + `tests/` + telemetry for each of the 21 key names, confirm
none is asserted downstream except the tests already in the re-pin list (§6); (c) the all-off
`to_flat_dict` telemetry snapshot shrinks by 21 rows — confirm no analysis asserts their presence
(only the config-marking/verify tests, all re-pointed).

### OQ-E — def-form vs code-form gaps → **RESOLVED (K5 half): rewire is correct; two precision build-notes.**

The rewire of pingpong/bomb/spike `_resolve_params` from `cfg.h*_*` to `spawn_ctx["params"]` (charger
pattern) is sound and the deck lane already threads `ctx["params"] = _effective_params(...)` (`:367`).
Two binding precisions the build agent MUST honor:

- **The three defs already carry every entity-read MAGNITUDE key in `params`** — verified: pingpong
  `{speed}` ✓; bomb `{proximity_radius, pulse_seconds, blast_radius}` ✓; spike `{rotation_speed,
  arm_length}` ✓ (plus each carries `base_count`/`count_per_depth` for the deck-lane demand math). So
  no `params` authoring is needed for the magnitudes; the play values arrive via `rc.param_overrides`
  (step 4). The `DEFAULTS` fallback mirrors the authored **neutral** `.tres` values (all 0.0), matching
  the charger's `test_charger` "`def.params[k] == DEFAULTS[k]`" no-drift discipline.
- **`kills` is NOT in any def's `params`** — it is the def **top-level** `kills` field (`= true` on all
  three). The deck lane does not thread it into `ctx["params"]`. **Resolution:** the rewired entities
  default `kills` to `true` in their `DEFAULTS` (matching all three defs + the play preset, where every
  `*_kills = true`), and read an optional `params["kills"]` override if present. Do **not** rely on the
  deck lane threading `def.kills` — keep it entity-local via `DEFAULTS`. (If a future non-lethal preset
  is wanted, it sets `param_overrides[<id>]["kills"] = false` — the same one surface.)

The pursuer items (E-ii, E-iii) **gate on OQ-A** and are deferred with it (NDR-V3-1).

### OQ-F — Per-room cap on the deck lane → **RESOLVED: put the caps on the shared defs (simpler than the doc's rec; ZERO new placement code). The `params["per_room_cap"]` "gap" is a non-issue.**

The doc's OQ-F is **over-stated**: it claims "the deck lane does NOT read a `per_room_cap`... a genuine
gap." Verification item 10 corrects this — **the SpawnService already enforces `def.per_room_cap` via
`ctx["room_key"]`, and `_populate_deck` already threads `room_key` (`:366`).** The deck lane is not
cap-blind. The per-room cap (2/2/1) is **load-bearing** for spike equivalence specifically: spike's
fair-share plan is `n = min(1 + floor(0.1·depth), cap=1) = 1 per eligible room ≈ 19 total`; without a
per-room clamp the deck lane's demand (Σ `1 + floor(0.1·depth)`) exceeds 19 and clusters 2 in deep
rooms → materially divergent count **and** distribution.

**Resolution — set `per_room_cap` on the shared defs** (`pingpong.tres` = 2, `bomb.tres` = 2,
`spike.tres` = 1; all currently 0). This is:
- **Zero new code** — the service + the `room_key` thread already do the enforcement.
- **Provably inert for band_two** — band_two's pingpong/bomb/spike cards are authored **neutral**
  (demand 0 → skipped at `:333-334` → never spawn → the cap never binds). No band_two behavioral
  change, no fp move. (Verified: band_two's four legacy cards carry neutral `params`.)
- **Conceptually correct** — `per_room_cap` is documented as a **perf/legibility guard** (a property
  of the hazard type), which is exactly what belongs on the def.

**Trade-off (build agent's discretion, NOT a Director call):** this splits the greybox play authoring
across two surfaces — magnitudes in `rc.param_overrides`, caps on the def. If the design prefers ALL
play magnitudes in one place (`rc.param_overrides`), the alternative is the doc's F-i: a ~4-line
`_populate_deck` per-room clamp reading `params["per_room_cap"]` (redundant with the service's existing
`def.per_room_cap` enforcement, so it must be one or the other, never both). **Rec: shared-def caps**
(minimal code, provably safe); F-i only if the single-surface authoring is judged worth the extra code.
Either way the equivalence test (step 5) **must pin the per-room cap** — it is the spike-equivalence
lynchpin.

### OQ-H — Menu/bijection at the reduced knob set → **RESOLVED: 89→68, 91→70; keep both coverage assertions green.**

Deleting 21 fields moves the frozen `test_config_menu` literals 89→68 (legacy) and 91→70 (total) and
removes the three `hpp_/hbomb_/hspike_` config sections + the K5 half of the Hazards tab.
**Binding build-notes:** (a) `grep -rn "\b89\b\|\b91\b" tests/` and re-pin every hit tied to the
RunConfig field count; (b) delete the K5 `_MANIFEST`/`SECTIONS`/`TAB`/`RANGES`/reflection-prefix
entries in `ui/config/config_menu.gd` (real path — the doc's `config_menu.gd:*` line refs are against
that file); (c) `has_full_coverage()` + `has_full_def_coverage()` MUST recompute green at the reduced
surface — they are the bijection guarantee and are the acceptance bar, not the raw count. If the
pursuer stays (K5-only, per NDR-V3-1), the Hazards tab **keeps its `r1_*` entries** and the tab is NOT
dropped — only its K5 half is removed.

### Golden-snapshot ordering → **RESOLVED (binding sequence): capture BEFORE delete.**

The equivalence test's **pre-migration side MUST be captured as a frozen fixture before
`_populate_legacy` is deleted** — run the old fair-share machine once against the fixed hand-built
graded bands (the `test_new_hazard_spawn._make_band` shape) at the play-preset magnitudes, record the
per-type counts + position lists, commit that fixture, THEN delete the machine. The equivalence test
(step 5) compares the new deck plan against the **frozen record**, never against live legacy code.
This ordering is non-negotiable — deleting first forfeits the only ground truth. Sequence within the
V3 worktree: (1) author the equivalence fixture from the live legacy machine + commit; (2) author the
greybox deck + `opposition_credits` + entity rewires + `param_overrides`; (3) delete `_populate_legacy`
+ the 21 knobs + menu plumbing; (4) re-pin goldens against the fixture; (5) full suite green.

### Layout-fingerprint safety → **CONFIRMED byte-identical (all four controls).**

`Band.fingerprint()` hashes only placed pieces (item 3); hazards are pure run-state placed after
generation and never feed it. The all-off `e943ac9c8bc1` and the greybox/two/three layout fps are
**structurally invariant** to everything V3 does. A layout-fp move here would be a **bug**, not a
sanctioned deviation. (The ONE sanctioned change is the greybox hazard-SPAWN golden — DR-3, below.)

### Needs Director review

**NDR-V3-1 — THE scope fork (OQ-A): land V3 as K5-only now; defer the pursuer/R1-machine retirement to a scoped follow-up. Recommendation: K5-ONLY. (This is the version's primary V3 decision — decide before dispatch.)**

The task card says "fold the legacy **four** (pursuer/pingpong/bomb/spike)"; DR-3's equivalence
framing names **only** the K5 fair-share machine; the "~30 knobs" arithmetic only closes by counting
the R1 spawn knobs (item 2). These are in genuine tension, and the resolver — reading the code fresh —
**agrees with the design's K5-only recommendation on the merits.** The two options, priced:

| | **K5-only now (recommended)** | **Full four (fold the pursuer now)** |
|---|---|---|
| Knobs deleted | 21 (`h*_*`) | 21 + 8 R1-spawn (+ up to 10 R1-entity = 39) |
| Machines retired | K5 fair-share (`_populate_legacy`) | K5 + the R1 machine (~250 LOC `main_game.gd` J2/J3 stack) |
| Equivalence bar | **Tractable** — deck lane & fair-share share the `base + floor(per_depth·depth)` skeleton; same types, comparable totals | **Weaker** — deck lane has no `single_gate`/`curve` depth mode, no area-scaled density; pursuer distribution WILL diverge more (the design admits this) |
| New code required | Small, well-precedented (3 entity rewires + a budget field) | **Net-ADD** — `legacy_ctx` pursuer `room_bounds` arm (§5, else L2 patrol silently degrades to chase-everywhere), deck-lane `room_bounds` thread for `&"pursuer"`, `hazard_entity` rewire, a band_greybox-only pursuer `DeckEntry` override (else band_two's neutral pursuer starts spawning) |
| Cross-band risk | None (K5 defs' band_two cards stay neutral) | Higher — pursuer is a live neutral card in band_two's deck (`:70`) |
| Pursuer regression risk | **ZERO** — R1 machine untouched, pursuer spawns byte-identically via `main_game:353` | The highest-risk placement change in the version |

**Why K5-only is right on merit:** M1.12's thesis is *"retire debt without moving the game,"* with a
hard regression floor. The K5 migration is a clean, in-scope, high-value deletion whose equivalence is
provable. The pursuer migration is the **opposite** — it turns "the version's largest deletion" into a
**net-add of deck-lane placement complexity** (single_gate/curve/density have no deck-lane equivalent
without new code), at the **highest regression risk**, with a **weaker equivalence bar**, in the same
solo wave. Folding it now maximizes the chance of the exact outcome the version exists to avoid.
K5-only also keeps the pursuer **byte-identical** (R1 machine untouched), so the pursuer contributes
zero regression surface to V3.

**The honest cost of deferring:** M1.12 does **not** fully deliver "exactly one way to add an
opposition" — the R1 pursuer machine remains a third, separate spawn path. Two of three machines are
unified (deck + K5→deck); R1 stands. This is a real, partial shortfall against the breakdown's
one-thing-to-prove, and the Director should weigh it. The resolver's judgment: a *partial* thesis
delivered with zero regression beats a *complete* thesis that risks moving the game in the
debt-paydown version — and the pursuer follow-up (V3b or an M2-adjacent task) is cleanly scoped by
the §b deferred sketch. **Recommend: land K5-only in V3; open V3b (pursuer/R1 → deck) as a scoped
follow-up task in `TASKS.md` + the board.** If the Director wants the full four in V3, the deferred
sketch (§b) prices it and the equivalence bar for the pursuer must be explicitly relaxed and signed
off. **This decision sets the ledger (21 vs 29–39 knobs), the test re-pin scope, and whether the
`main_game.gd` J2/J3 stack is touched — it must be dispositioned before dispatch.**

**DR-3 — Accept the sanctioned greybox hazard-SPAWN change + prove equivalence + re-pin the goldens (Director sign-off, held open to the Wave-4 close-out). Recommendation: ACCEPT.**

The breakdown already marks DR-3 as "proceeding on rec, explicit sign-off required at the V3 close-out
where the actual golden re-pin is presented." The resolver confirms the fp-change is **hazard-spawn
goldens only, no layout fp** (item 3), and folds two Director-facing sub-calls into the DR-3 sign-off:

- **DR-3a — Equivalence tolerance (OQ-C).** Type coverage is **exact** (`{pingpong, bomb, spike}`
  present before & after — a missing type fails hard); entry-safety, caps, and determinism are
  **hard** gates. For count/distribution the resolver recommends **±15% per-type total** as the PASS
  threshold, with **per-depth-bucket monotonicity** as the distribution proxy. **Important nuance the
  Director must be told:** the deck lane places by **even-spread across the depth range** (the
  Director-ratified FBM19/FB2 "spread deeper" fix), whereas the K5 fair-share places by the per-piece
  `base + floor(per_depth·depth)` formula. So **per-type totals can match tightly (if OQ-G gives the
  deck the 48 budget), but the greybox hazard DISTRIBUTION will shift slightly DEEPER by construction**
  — same types, comparable totals, deeper spread. This is arguably an *improvement* (greybox inherits
  the deck lane's already-shipped deeper-spread), but it is a real, visible change and part of what the
  Director signs off. If OQ-G is resolved to preserve the 48 budget, expect actual per-type deltas well
  **inside** ±10% — the ±15% is a ceiling, not the expected drift.
- **DR-3b — Density preservation (OQ-G).** Reproducing the fair-share's effective 48-body budget
  (vs the deck's default 24 at `band_depth=1`) requires the new `BandProfile.opposition_credits` field
  (rec below). The choice is: **(preferred) `opposition_credits = 48`** → greybox hazard density
  preserved, tightest equivalence; **vs (G-iii) accept the ~24 budget** → a visible **≈ −35%** greybox
  hazard-density reduction, documented as an intentional M1.12 change. This is a **fun/density call the
  Director owns.** Rec: **preserve density (`opposition_credits = 48`).**

**On the `opposition_credits` field itself (OQ-G) — resolved on merit, NOT a guardrail violation.** The
breakdown's "no new knob / config menu shrinks, never grows" guardrail targets the **RunConfig /
config-menu surface** (the frozen 89/91 bijection). `BandProfile.opposition_credits` is a **band-content
authoring field** — it never touches the config menu, the bijection, or the 89/91→68/70 counts; it is
neutral-by-default (`0` = today's `BASE_CREDITS·instability`, so band_two/three/four are byte-unchanged);
and it never moves a layout fp (budget is hazard-side). It is squarely the *content-is-data* direction
the version endorses. **Re-tuning `band_depth` to raise the budget is REJECTED** — greybox is the
depth-1 baseline band; reaching budget 48 would need `band_depth ≈ 8`, corrupting the band's identity
and every `band_depth`-keyed path (Instability, `min_band` gating). So `opposition_credits` (or accepting
the reduction, DR-3b) are the only real options. The field is sound; only the **density choice** (DR-3b)
needs the Director.

> **Everything else in OQ-B/D/E/F/H, the golden-ordering, and the layout-fp safety is resolved on
> technical merit and needs no Director call.** With NDR-V3-1 (scope), DR-3a (tolerance), and DR-3b
> (density) dispositioned, this design is **locked** for the build agent. Per the breakdown, DR-3's
> golden re-pin sign-off stays formally open until the Wave-4 close-out where the equivalence evidence
> is presented.
