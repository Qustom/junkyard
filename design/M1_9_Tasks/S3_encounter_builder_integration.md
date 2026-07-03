# S3 — EncounterBuilder + RunConfig Generic Levers + Both Call-Site Integrations — Expanded Design Spec

**Milestone:** M1.9 (Scalable Opposition + Band Systems) · **Wave:** 3 (S3 ALONE — the sole `main_game.gd` writer)
**Task id:** S3 · **blockedBy:** S0 (SpawnService + defs), S1 (BandProfile + BandPipeline), S2 (components + param_schema)
**Assignee:** general-purpose (programmer) · **Author:** game-director-designer (Phase-2 fan-out)
**Source explorations:** [`0-scalable-opposition-system.md` v2](../explorations/exploration-20260702/hazards/0-scalable-opposition-system.md) (the EncounterBuilder split, the client table, budget-in-builder/caps-in-service) · [`0-scalable-band-generation-system.md`](../explorations/exploration-20260625/procgen-bands/0-scalable-band-generation-system.md) (the handoff-to-oppositions seam, `BandProfile.opposition_deck`)

> **What this doc is.** The Phase-2 design for S3 — opposition migration **Phase C** ("policy out of `main_game`") *plus* the band-side call-site switch (`main_game.gd:209` → `BandPipeline.generate`). This is the only wave that rewires `main_game.gd`; both integrations land here so the file has exactly one writer. It is **design only** — no code, no branch. Pseudocode is illustrative against the real as-built APIs (`main_game.gd` on `main` @ `6fbded1`, pre-S0; where S0/S1/S2 change the substrate, the assumed landed contract is stated explicitly in §2.6 and must be re-verified against their worklogs at brief time).

---

## 0. Hard constraints (read first)

From the M1.9 breakdown's scope guardrails + the S3 task contract. The implementation may not violate any of these:

- **All-off fp `e943ac9c8bc1` byte-identical THROUGH the new call sites.** An all-off `RunConfig` run routed through `BandPipeline.generate(profile, …)` + `EncounterBuilder.populate(…)` must produce the byte-identical band fingerprint AND spawn zero oppositions — the permanent control survives both rewires.
- **Bandgen determinism suite green through the pipeline path.** `tests/test_bandgen_determinism.gd` (and the S1 parity test) must pass with `main_game` on the orchestrated path — same-seed→same-fp, diff-seed→diff-fp, connectivity, seal-invariance, all through `BandPipeline`.
- **Preset parity is an explicit acceptance bar.** `make_default_play_preset()` (`run_config.gd:662-855`) must spawn the **same cohort** after the extraction as before it. §2.3 enumerates the exact math the builder must reproduce; §6 Q1 argues this bar is **byte-exact**, not merely count-exact.
- **Caps stay in the service; budget lives in the builder.** `per_room_cap`/`per_band_cap`/global ceilings are `SpawnService` registry enforcement (every client obeys them); the credit budget and every "what deserves to spawn" decision is `EncounterBuilder` policy. The service never sees credits.
- **Legacy knobs untouched.** The R1/K5 `@export` groups on `RunConfig` (`run_config.gd:57-126`, `:298-361`), their `to_flat_dict()` rows, and their preset values do not change — the migration contract says they stay until post-gate retirement. The new generic levers are **additive**.
- **No save-schema change. Primitives-only signal payloads. Single-writer:** S3 is the only Wave-3 agent and the only writer of `main_game.gd`; it may also touch `run_config.gd`, the new builder file, and tests (file-disjoint from every other M1.9 task's surface this wave).

---

## 1. Goal & design intent

**One sentence:** *pull the "what spawns where" policy out of `main_game` into an `EncounterBuilder` that serves both the legacy-knob preset (byte-exactly) and the deck-driven new band (via credits + Instability), and make `main_game` a thin consumer of the two systems S0–S2 built.*

After S3, `main_game.start_new_run()` reads as: resolve config → resolve band profile → `BandPipeline.generate(...)` → materialise → `builder.populate(...)`. Adding a hazard to a band becomes deck data (S6a/S6b/S7 prove it); adding a band becomes a profile (S7). S3 itself adds **zero observable behavior** — it is the riskiest *plumbing* step of M1.9 precisely because its definition of done is "nothing changed."

---

## 2. Research

### 2.1 Inventory — the policy statements leaving `main_game.gd` (file:line, as-built `main` @ 6fbded1)

S0 (Wave 1) extracts the **mechanism** half of `_spawn_new_hazards` (instantiate / add_child / reset_physics_interpolation / `setup()` handshake / registry / caps / BUG7 cell validation). What remains in `main_game` after S0 — and what S3 moves into `EncounterBuilder` — is the **policy** half:

| # | Policy statement | As-built location | Destination |
|---|---|---|---|
| P1 | Descriptor table: per-type `{kind, path, enabled, base, per_depth, cap}` read off `rc.hpp_*/hbomb_*/hspike_*` | `_new_hazard_descriptors`, `main_game.gd:357-365` | Builder — the **legacy adapter** (§3.2), mapping knob groups → `OppositionDef`s + spawn-card numbers |
| P2 | Active pre-filter: enabled ∧ non-neutral (`base>0 ∨ per_depth>0`) ∧ scene loads | `main_game.gd:409-422` | Builder legacy lane (scene-load check becomes "def resolves + `host_scene` valid") |
| P3 | Fair-share split of the 48 ceiling: `base_share = CEIL / n_active`, `remainder = CEIL % n_active`, earlier descriptor-order types absorb the remainder (the L6 starvation fix) | `main_game.gd:424-426`, `:430-435` | Builder legacy lane — reproduced **verbatim** |
| P4 | Per-type/piece walk order: pieces depth-asc then `(y,x)`; cells `(y,x)` | `_density_pieces_sorted :734-746`, `_density_sorted_cells :751-757` | Shared stable-walk util (builder + the retained R1 lane both call ONE copy — see §2.6.d) |
| P5 | Depth-0 entry-piece skip (BUG7's policy half — "shallow entry is safe") | `main_game.gd:454-455` | Builder legacy lane |
| P6 | Depth-scaled count: `n = base + int(floor(per_depth * float(depth)))` | `main_game.gd:457` | Builder (both lanes) |
| P7 | Per-room-cap / type-budget / ceiling clamps **in that order, pre-stride**: `n = min(n, cap, type_budget − type_spawned, CEIL − spawned_total)` | `main_game.gd:458-461` | Builder legacy lane (the *plan-side* clamp; the service's registry cap stays as the belt-and-braces hard stop — see §2.6.c) |
| P8 | Candidate cells + BUG7 safe-radius filter **before** stride: `cells.filter(dist ≥ NEW_HAZARD_SPAWN_SAFE_CELLS * cell_px)` | `main_game.gd:464-471` (const at `:350`) | Filter predicate is service-owned validation (S0); the builder must apply it **pre-stride** via a queryable API — a load-bearing parity requirement, §2.6.b |
| P9 | Stride cell pick: `stride = max(cells.size()/max(n,1),1)`; `cell = cells[(k*stride) % cells.size()]` | `main_game.gd:473-475` | Builder (both lanes) |
| P10 | Per-instance ctx: golden-angle `initial_dir` fan keyed on the **global cross-type accumulator** `spawned_total`, `phase_salt = depth_index*131 + k`, `room_bounds` = piece floor bbox in world space | `_new_hazard_spawn_ctx :496-507`, golden angle `:341`, `_piece_floor_bounds_world :514-520`, call site `:483` | Builder builds ctx; service projects cells→world (it owns `_band_cell_size_px` post-S0) |
| P11 | The ceiling constant itself, `NEW_HAZARD_BAND_CEILING = 48` | `main_game.gd:337` | Service (it is a hard cap) — the builder *reads* it for the fair-share plan via a svc query (§3.1) |
| P12 | Band-gen call site: rc resolve `:198`, lvl catalog swap `:205-207`, `generator.generate(seed,_cfg,catalog,run_cfg)` `:208-209`, grade + return-distance `:213-215` | `main_game.gd:198-215` | `BandPipeline.generate(profile, seed, rc)` per S1's contract (§2.5) |

**Explicitly NOT moving in S3** (decision, with rationale in §6 Q4): the R1 pursuer lanes — `_spawn_r1_hazards :534-574`, `_populate_room_density :587-606`, `_density_spawn_bounds :616-645`, `_density_spawn_positions :671-709`, `_hazard_spawn_depths :772-795`, `_hazard_spawn_position :814-827`. Their *instantiation* already routes through `svc.spawn` after S0 (mechanism unified); their *plans* (J2 spread / J3 density) stay `main_game` policy this version. `test_per_room_density.gd:116-125` pins `_density_spawn_positions` with a byte-frozen golden and an explicit "MUST NOT refactor" comment — moving it buys no M1.9 capability and risks the golden contract. Post-gate retirement item.

Also **staying**: everything that is orchestration, not opposition policy — depth driver, junction map, corridor time, gates (K7), throw seam, camera, materialise. `main_game` gets *thin about oppositions and band-gen*, not empty.

### 2.2 The preset-parity problem, stated precisely

`make_default_play_preset()` is the fun stack every Director playtest runs. Its K5 cohort today, on the default ~30-room band, is produced by exactly this computation (all of it moving to the builder):

1. **Active set** (P2): hpp (enabled, base 0, per_depth 0.15, cap 2), hbomb (enabled, base 0, per_depth 0.15, cap 2), hspike (enabled, base 1, per_depth 0.1, cap 1) → `n_active = 3`.
2. **Fair-share** (P3): `base_share = 48/3 = 16`, `remainder = 0` → every type's `type_budget = 16`. (With 2 active types it would be 24/24; with a remainder, earlier descriptor-order types — pingpong→bomb→spike — absorb it. That descriptor order is the ONLY thing order decides now.)
3. **Walk** (P4/P5): pieces depth-ascending, `(y,x)` tiebreak; skip `depth <= 0`.
4. **Count** (P6/P7): per piece, `n = base + floor(per_depth * depth)`, clamped by per-room cap, then this type's remaining slice, then the shared remaining ceiling — **in that order** (the clamps feed the stride).
5. **Cells** (P8/P9): the piece's `(y,x)`-sorted floor cells, safe-radius-filtered around the entry spawn **before** stride is computed; `stride = max(filtered.size()/max(n,1),1)`; pick `filtered[(k*stride) % filtered.size()]`.
6. **Ctx** (P10): pingpong gets `initial_dir = Vector2.from_angle(spawned_total * GOLDEN_ANGLE)` — note `spawned_total` is the **global accumulator across all three types**, not a per-type index — plus `room_bounds`; spike gets `phase_salt = depth_index*131 + k`; bomb gets `{}`.
7. **Starvation semantics** (P3/P7): within a type, the deepest pieces are starved first when the slice or ceiling runs out (the walk is shallow-first); across types, no starvation — only remainder priority.

"Same cohort" therefore has to mean: **the identical ordered list of (def/kind, cell, ctx) spawn requests** — because two of these steps are order-coupled (`spawned_total` threads through the ping-pong fan; the ceiling clamp depends on everything spawned before it). Get the *order* wrong and counts stay right while every ping-pong heading silently changes. This is why §6 Q1 argues the bar is byte-exact, and why the existing pins matter: `test_rg1_m14_verify.gd:287-320` **replicates this count math as an independent mirror** and `test_new_hazard_spawn.gd` drives `mg._spawn_new_hazards(...)` directly with position/count asserts — both must stay green **unmodified** (§2.6.e).

The R1 half of the preset (spawn_count 5 / even_spread / min-depth 1 / density 1.0 / cap 3 / min-area 64) is parity-guaranteed by *not moving it* (§2.1) — `test_per_room_density.gd` + `test_hazard_spread.gd` + `test_rg1_m13_verify.gd:311-334` keep pinning it where it lives.

### 2.3 Two lanes in one `populate()` — how deck-driven and knob-driven coexist

The builder is ONE class with ONE public entry point and two internal lanes, dispatched on the band's profile:

- **Legacy lane** (band 1 / any profile with an **empty** `opposition_deck` — `band_greybox.tres` is authored empty): the K5 fair-share machine of §2.2, driven by the untouched `rc.hpp_*/hbomb_*/hspike_*` knobs through the legacy adapter (§3.2). Credits are **not consulted** (§6 Q5). All-off → the adapter's active set is empty → zero spawn calls → baseline holds.
- **Deck lane** (profile with a **non-empty** `opposition_deck` — `band_two.tres`): the exploration's credit machine — budget `BASE_CREDITS * I`, deck filtered by `min_band`, deterministic authored-order draw, per-def spawn-card counts, service caps as the hard stop. Legacy knobs are **not consulted** for the deck band's cohort (its identity is its deck — S7 authors the existing hazards INTO the deck at deck weights, so the fun stack doesn't vanish there; it is re-expressed as data).
- The **generic levers** overlay both lanes: `oppositions_enabled` is an additive def enable-list (a sweep/debug lever — §3.3), `param_overrides` re-tunes any def-driven params. Both default empty = perfectly neutral = the levers cannot move either lane's baseline.

Dispatch rule: `deck non-empty → deck lane; else → legacy lane` — never both, so a preset dive into band 1 is pure legacy (parity) and a band_two dive is pure data (the proof). `oppositions_enabled` extras append through the deck machinery in either case (neutral when empty).

### 2.4 The band-gen call-site switch (`main_game.gd:209`)

Today (`:198-215`): resolve `run_cfg` → pick catalog by `rc.lvl_enabled` (baseline vs `piece_catalog_ext`, the I1 config-dependent swap that protects the all-off fp) → `BandGenerator.new().generate(seed, _cfg, catalog, run_cfg)` → `DepthGrader.grade` + `compute_return_distance`. Note the as-built generator **takes `rc`** — R4 branching (`r4_branch_*`), `lvl_room_count`, and the J4 corridor-weight levers all feed `generate()` through it.

After S3: `var band := BandPipeline.generate(profile, seed, run_cfg)` where `profile` is the resolved `BandProfile` (default `band_greybox.tres`, §6 Q2). Per S1's contract the pipeline owns backend selection + grading; **S3 assumes** (verify at brief time, §2.6.a): (i) the pipeline signature threads `rc` (the legacy levers must keep reaching the socket backend or the preset band *layout* changes — a parity break the fp tests would catch); (ii) the lvl catalog swap lives inside the pipeline (profile carries the baseline pool; the ext-catalog swap is an rc-conditional the pipeline reproduces) — if S1 left the swap at the call site, S3 keeps those 3 lines and passes the picked catalog as an override; (iii) the returned band is graded (grade + return-distance moved in), while `SocketSealer` stays at materialise time (`main_game.gd:881` — it needs parented pieces). Everything downstream of the `band` local (`_build_cell_depth_map`, cell-size, loot plan, materialise, gates, player placement) is **unchanged**.

### 2.5 Prior art / grounding

Carried from the v2 exploration (RoR2 credit directors, L4D pacing — see its Sources): the fair-share ceiling *is* a primitive credit budget; S3 makes the two budgets coexist without letting the new one touch the old one's output. The client table (exploration §"policy clients") fixes S3's scope: S3 ships client **(a)** — the Instability band populator — only; clients (b)/(c)/(d) are S6b/S7/S4's, all already served by S0's `spawn()` boundary.

### 2.6 Integration assumptions + traps found (verify against S0/S1/S2 worklogs at brief time)

- **(a) `BandPipeline` signature.** The breakdown writes `generate(profile, seed)`; the as-built generator needs `rc` (§2.4). S3 assumes `generate(profile, seed, rc)` (or an equivalent rc-threading) landed in S1. If S1 genuinely dropped `rc`, the preset's layout cannot be reproduced and S3 must stop and escalate — this is not adaptable at the call site.
- **(b) The BUG7 filter must be queryable, not refusal-only.** S0 owns cell validation. But `stride` is computed from the **filtered** cell list (`main_game.gd:471-473`) — if the service only *refuses* bad cells inside `spawn()`, the builder would compute stride over the unfiltered list and every subsequent pick shifts: counts survive, cells don't. The service must expose the predicate (e.g. `svc.filter_spawnable_cells(cells)` / `svc.is_cell_spawnable(cell)`) so the builder filters **before** striding. If S0 landed refusal-only, S3 adds the query to the service (an additive mechanism API, within S3's remit since no other Wave-3 writer exists).
- **(c) "Unified ceilings" must stay two budget domains.** Today R1 density is bounded by `R1_DENSITY_BAND_CEILING = 64` (`run_config.gd:37`) and K5 by `48` — **independently** (preset worst case ≈ 64 + 48 coexisting). A naive single registry cap of 48 would clamp the preset's R1 population — a parity break. Through M1.9 the service's registry must keep the two ceilings as separate cap domains (per-def-family or ctx-tagged); true unification is post-gate, with the legacy knobs.
- **(d) One copy of the stable-walk helpers.** `_density_pieces_sorted`/`_density_sorted_cells` are shared by the moving K5 policy AND the staying R1 lane. Duplicating them into the builder invites drift (two sort lambdas that can diverge). S3 hoists them to one static home (`EncounterBuilder` statics, or S0's service if it already hoisted them) and points `main_game`'s R1 lane at that single copy — a pure relocation, pinned by the golden tests.
- **(e) Test bindings that must survive unmodified.** `tests/test_new_hazard_spawn.gd` calls `mg._spawn_new_hazards(rc, band[, spawn_pos])` in 8 places; `tests/test_per_room_density.gd` + `test_rg1_m13_verify.gd` call `mg._density_spawn_positions`; `test_rg1_m14/m15_verify.gd` mirror the count math and pin the all-off fp. S3 keeps `_spawn_new_hazards` **as a thin façade** delegating to the builder (same signature) — those tests then pass unmodified and *are* the parity proof, exactly as S0 used them for the mechanism half.
- **(f) The coverage assertion will fail on naive new `@export`s.** `config_menu.has_full_coverage()` (`config_menu.gd:414-437`) reflects every RunConfig property with `STORAGE|EDITOR` usage (`:446-455`) and asserts the hand-bound 89-row set equals it. Two plain `@export`s added in Wave 3 would break the build **before** S4 (Wave 4) generalizes the menu. Fix (§3.3): declare the levers `@export_storage` — serialized to `.tres`, invisible to the `STORAGE ∧ EDITOR` filter, so the 89-row assertion is untouched; S4 then surfaces them properly. (Alternative — plain `@export` + two hand rows in the `""` meta section, `config_menu.gd:85` — touches a file S4 owns next wave; rejected.)
- **(g) `data/run_config/run_config.tres` must not be re-saved.** New fields with default values don't change the existing `.tres` bytes unless something re-serializes it. Don't open-and-save it in the editor during S3.

---

## 3. Pseudocode

Illustrative, against the S0-landed `SpawnService` API (`spawn(def, cell, ctx) -> Node`, `can_afford`, `live_count`, plus the §2.6.b/§3.1 read-only queries). The programmer owns the real code.

### 3.1 `EncounterBuilder` (new file — `systems/oppositions/encounter_builder.gd`)

```gdscript
class_name EncounterBuilder
extends RefCounted
## Opposition POLICY (exploration v2, Phase C): decides what spawns where, then calls
## SpawnService. Generation-time client (a): RNG-FREE stable walk — placement is pure
## run-state on the graded band, never feeds fingerprint(). Caps are the SERVICE's;
## the credit budget is OURS and only the deck lane spends it.

## TUNABLE (Director sweep; binds only on deck-driven bands — §6 Q5): the credit pool
## a band_depth-1 deck band gets before Instability scaling.
const BASE_CREDITS: int = 24

## Instability I as a named function (§6 Q3): the GDD's +15%/band, nothing more.
## M2+ replaces this with the real I system (stats + loot + budget share one scalar).
static func instability(band_depth: int) -> float:
	return 1.0 + 0.15 * float(band_depth)      # normalization: §6 Q3 note

## THE one public entry point. Dispatch: non-empty deck => deck lane; else legacy lane.
## `extras` from rc.oppositions_enabled ride the deck machinery in either case (§3.3).
func populate(band: Band, profile: BandProfile, rc: RunConfig, svc: SpawnService) -> void:
	var deck: Array[OppositionDef] = profile.opposition_deck if profile != null else []
	if not deck.is_empty():
		_populate_deck(band, deck, instability(profile.band_depth), rc, svc)
	else:
		_populate_legacy(band, rc, svc)          # band 1 / band_greybox: byte-exact parity
	_populate_extras(band, rc, svc)              # oppositions_enabled additions; no-op when empty


# --- Legacy lane: main_game.gd:385-486 relocated VERBATIM (the parity path) ---------

func _populate_legacy(band: Band, rc: RunConfig, svc: SpawnService) -> void:
	if rc == null:
		return
	var active := _legacy_active_specs(rc)       # §3.2 — the adapter (P1/P2)
	if active.is_empty():
		return                                    # all-off: zero calls, baseline holds
	var ceiling: int = svc.legacy_band_ceiling()  # 48 — the cap CONSTANT lives service-side (P11)
	var base_share: int = ceiling / active.size()
	var remainder: int = ceiling % active.size()
	var spawned_total: int = 0                    # the GLOBAL accumulator (threads into ctx! P10)
	var pieces := _pieces_depth_sorted(band)      # P4 — the single shared stable walk
	for ti in active.size():
		if spawned_total >= ceiling: break
		var spec: Dictionary = active[ti]
		var type_budget: int = base_share + (1 if ti < remainder else 0)
		var type_spawned: int = 0
		for p in pieces:
			if spawned_total >= ceiling: break
			if type_spawned >= type_budget: break
			if p.depth_index <= 0: continue      # P5 — entry piece stays safe
			var n: int = spec.base + int(floor(spec.per_depth * float(p.depth_index)))  # P6
			if spec.room_cap > 0: n = mini(n, spec.room_cap)                            # P7,
			n = mini(n, type_budget - type_spawned)                                     #  in
			n = mini(n, ceiling - spawned_total)                                        #  order
			if n <= 0: continue
			# P8: the service's BUG7 predicate applied BEFORE stride (load-bearing — §2.6.b).
			var cells: Array[Vector2i] = svc.filter_spawnable_cells(_cells_sorted(p))
			if cells.is_empty(): continue
			var bounds: Rect2 = svc.floor_bounds_world(cells)
			var stride: int = maxi(cells.size() / maxi(n, 1), 1)                        # P9
			for k in n:
				var cell: Vector2i = cells[(k * stride) % cells.size()]
				var ctx := _legacy_ctx(spec.id, p, k, spawned_total, bounds)            # P10
				if svc.spawn(spec.def, cell, ctx) != null:
					spawned_total += 1
					type_spawned += 1
	# NOTE the spawn-failure asymmetry vs today: the old code incremented unconditionally
	# after add_child; the service can refuse. On the parity path refusal never happens
	# (the plan already honors every cap the service checks), so the counters match —
	# test_encounter_builder asserts a refusal-free preset plan explicitly.


# --- Deck lane: the credit machine (exploration v2 pseudocode, concretized) ---------

func _populate_deck(band: Band, deck: Array[OppositionDef], I: float,
		rc: RunConfig, svc: SpawnService) -> void:
	var budget: int = int(floor(float(BASE_CREDITS) * I))
	var eligible: Array[OppositionDef] = []
	for d in _deck_order(deck):                   # authored order, id-deduped — DETERMINISTIC
		if band.band_depth >= d.min_band:         # min_band gate (band_depth off the profile)
			eligible.append(d)
	if eligible.is_empty():
		return
	for p in _pieces_depth_sorted(band):          # same stable walk as legacy — one discipline
		if budget <= 0: break
		if p.depth_index <= 0: continue           # entry safety holds for deck bands too
		for d in eligible:
			var n: int = d.base_count + int(floor(d.count_per_depth * float(p.depth_index)))
			var cells: Array[Vector2i] = svc.filter_spawnable_cells(_cells_sorted(p))
			if cells.is_empty(): break
			var bounds: Rect2 = svc.floor_bounds_world(cells)
			var stride: int = maxi(cells.size() / maxi(n, 1), 1)
			for k in n:
				if budget < d.credit_cost: break
				var cell: Vector2i = cells[(k * stride) % cells.size()]
				var ctx := _deck_ctx(d, p, k, rc)  # merges rc.param_overrides[d.id] (§3.3)
				if svc.spawn(d, cell, ctx) != null:  # service refuses at per_room/per_band cap
					budget -= d.credit_cost
	# spawn_weight is RESERVED this version (deterministic authored order instead of a
	# weighted draw — a weighted draw needs a seeded sub-stream; deferred, §6 Q6-iii).

## Deterministic deck order: the authored .tres array order IS the draw order (the band
## author's priority list), deduped by id (first occurrence wins). No RNG anywhere.
func _deck_order(deck: Array[OppositionDef]) -> Array[OppositionDef]: ...
```

### 3.2 The legacy adapter — R1/K5 knob groups → builder inputs

The only place the old knob names survive inside the builder. It reproduces P1+P2 exactly, resolving each kind to its S0-authored def (the def's `host_scene` is the same `.tscn` the old table `load()`ed, so P2's "scene loads" check becomes "def loads ∧ host_scene set"):

```gdscript
const LEGACY_DEF_PATHS := {                       # S0's authored defs, loaded LAZILY
	&"pingpong": "res://data/oppositions/pingpong.tres",   # only for ACTIVE types, so
	&"bomb":     "res://data/oppositions/bomb.tres",       # all-off loads NO def —
	&"spike":    "res://data/oppositions/spike.tres",      # the exploration's guarantee
}

## rc knob groups -> ordered active specs (order = remainder priority, as today).
func _legacy_active_specs(rc: RunConfig) -> Array[Dictionary]:
	var table := [
		{ "id": &"pingpong", "enabled": rc.hpp_enabled,    "base": rc.hpp_base_count,
		  "per_depth": rc.hpp_count_per_depth,   "room_cap": rc.hpp_per_room_cap },
		{ "id": &"bomb",     "enabled": rc.hbomb_enabled,  "base": rc.hbomb_base_count,
		  "per_depth": rc.hbomb_count_per_depth, "room_cap": rc.hbomb_per_room_cap },
		{ "id": &"spike",    "enabled": rc.hspike_enabled, "base": rc.hspike_base_count,
		  "per_depth": rc.hspike_count_per_depth,"room_cap": rc.hspike_per_room_cap },
	]
	var out: Array[Dictionary] = []
	for row in table:
		if not row.enabled: continue
		if row.base <= 0 and row.per_depth <= 0.0: continue     # neutral => inert (P2)
		var def := load(LEGACY_DEF_PATHS[row.id]) as OppositionDef
		if def == null or def.host_scene == null:
			push_error(...); continue
		row["def"] = def
		out.append(row)
	return out

## P10 verbatim — including `index` = the cross-type accumulator for the golden-angle fan.
func _legacy_ctx(kind: StringName, p: PlacedPiece, k: int, index: int, bounds: Rect2) -> Dictionary:
	match kind:
		&"pingpong": return { "initial_dir": Vector2.from_angle(float(index) * GOLDEN_ANGLE),
		                      "room_bounds": bounds }
		&"spike":    return { "phase_salt": p.depth_index * 131 + k }
		_:           return {}
```

The legacy R1 group does **not** map through the adapter — its lanes stay in `main_game` (§2.1, §6 Q4). The type-specific entity knobs (`hpp_speed`, `hbomb_blast_radius`, …) keep flowing exactly as today: the entities snapshot `rc` at `setup()` (S2 preserved that discipline), so the adapter never touches them.

### 3.3 `RunConfig` generic levers (additive edit to `run_config.gd`)

```gdscript
# =============================================================================
# S3 (M1.9) — generic opposition levers (exploration v2 "RunConfig integration").
# ADDITIVE + neutral-by-default: empty array/dict = no def loaded, no override
# applied — the all-off control and every legacy preset are untouched. Declared
# @export_storage (serialized, NOT editor-visible) so config_menu's 89-row
# has_full_coverage() reflection (STORAGE && EDITOR) is unaffected in Wave 3;
# S4 surfaces both through the generated per-def sections (Wave 4).
# =============================================================================
@export_storage var oppositions_enabled: Array[StringName] = []
## def_id -> { param_key -> value } sweep overrides, applied to DEF-DRIVEN params
## (deck lane + extras) at ctx-merge time; legacy-knob-driven values stay
## authoritative for the legacy lane in M1.9 (no double-driving — §6 Q6-ii).
@export_storage var param_overrides: Dictionary = {}
```

- **Semantics of `oppositions_enabled` (recommendation; §6 Q6-i):** an **additive enable-list** — each listed def id is loaded and appended to the dive's effective deck (deduped; on a deck-less band it seeds a one-def deck through the deck machinery at the def's authored spawn card). It never *removes* a deck entry — a deck band's content is the band author's, not the sweep's. Empty = neutral = today.
- **`to_flat_dict()` additions** (config-marked telemetry — appended to the existing return, `run_config.gd:455-566`, JSON-safe like `_packed_to_float_array`):

```gdscript
	# S3 (M1.9) — generic opposition levers (additive payload; SG2 segments def sweeps)
	"oppositions_enabled": oppositions_enabled.map(func(s): return String(s)),
	"param_overrides": _param_overrides_flat(),   # String keys, primitive leaves
```

  Additive keys on the `run_started` row are the established pattern (every version since M1.1 added rows); the all-off stamp gains two empty/neutral entries. `all_oppositions_disabled()` (`:429`) is **unchanged** (it defines the R-opposition control; a def-sweep run is a labeled experiment, visible via the new stamped keys). The config-trap generalization ("enabled def with neutral load-bearing param") is S4's, per the breakdown.

### 3.4 The thin `main_game` flow (the S3 rewrite of `start_new_run()`, sketch)

```gdscript
const DEFAULT_BAND_PROFILE_PATH := "res://data/bands/band_greybox.tres"

## S8 rewires this in Wave 5 (the portal-choice seam). Until then: the default profile.
## ONE named function so S8's edit is a one-liner against a pre-agreed seam (§6 Q2).
func _resolve_band_profile() -> BandProfile:
	return load(DEFAULT_BAND_PROFILE_PATH) as BandProfile

func start_new_run() -> void:
	_clear_band()
	_run_count += 1
	var seed: int = _next_seed()
	var run_cfg: RunConfig = GameState.dive_config_or_default()          # unchanged
	var profile: BandProfile = _resolve_band_profile()

	# 1. Generate + grade — THE :209 SWITCH. Pipeline owns backend + catalog swap +
	#    grading (S1 contract, §2.4); rc threads the legacy levers (r4_*, lvl_*).
	var band := BandPipeline.generate(profile, seed, run_cfg)
	if band == null or band.pieces.is_empty(): push_error(...); return

	_build_cell_depth_map(band)                                          # unchanged
	# ... cell_size / loot plan / _materialise_band / spawner / gates /
	#     player + camera placement / stage_run_config / start_run / enter_band /
	#     _spawn_r4_nodes — ALL UNCHANGED (BAND_ID continuity: §6 Q2b) ...

	_spawn_r1_hazards(run_cfg, band)             # legacy R1 lanes: STAY (§6 Q4)
	_spawn_new_hazards(run_cfg, band, spawn_pos) # now a thin façade (below)

## FAÇADE (kept signature — test_new_hazard_spawn.gd drives this in 8 places, §2.6.e):
## delegate the K5 policy to the builder. profile is irrelevant to the legacy lane, so
## the façade calls the legacy path directly; start_new_run's real call goes through
## populate() with the resolved profile.
func _spawn_new_hazards(rc: RunConfig, band: Band, spawn_pos: Vector2 = Vector2.INF) -> void:
	_spawn_service.set_entry_exclusion(band, spawn_pos)   # BUG7 anchor (S0's validation input)
	EncounterBuilder.new().populate(band, _resolve_band_profile(), rc, _spawn_service)
```

Deleted from `main_game`: the P1–P11 bodies (`_new_hazard_descriptors`, the `_spawn_new_hazards` internals, `_new_hazard_spawn_ctx`, the golden-angle const, `NEW_HAZARD_BAND_CEILING` — relocated, not re-typed). Retained: the R1 lanes + the shared-walk call sites now pointing at the hoisted single copy (§2.6.d).

### 3.5 `tests/test_encounter_builder.gd` sketch (headless SCENE, house rules)

A `FakeSpawnService` (records ordered `(def_id, cell, ctx)` requests; configurable refusal; replays the BUG7 predicate) makes every case plan-level and fast — no entity instantiation:

1. **All-off:** `RunConfig.new()` + empty-deck profile → **zero** requests.
2. **Preset byte-parity (THE acceptance bar):** hand-built graded band matrix (reuse `test_new_hazard_spawn`'s `_make_band` shapes) + `make_default_play_preset()` → the builder's ordered request list equals a **verbatim mirror of the old math** (the `test_rg1_m14_verify.gd:287-320` mirror, extended to cells + ctx: same cells, same counts, same `initial_dir` angles, same `phase_salt`s, same order) — and the plan is refusal-free.
3. **Fair-share + starvation:** demand > 48 across 3 types → 16/16/16 slices; deepest pieces starved first within a type; remainder absorbed in descriptor order when `48 % n_active != 0` (2-type case: 24/24).
4. **Budget math:** deck of defs with `credit_cost` 1/2/5 at `I = instability(2)` → spending stops exactly at exhaustion; a refused spawn (fake returns null) does **not** decrement budget.
5. **`min_band` gating:** def with `min_band=2` excluded at `band_depth=1`, included at 2.
6. **Deterministic draw order:** same (band, deck, rc) twice → identical ordered request lists; deck order = authored array order, id-deduped.
7. **Levers:** `oppositions_enabled=[&"spike"]` on an empty-deck all-off config → spike def spawns via its authored card; `param_overrides` reaches the ctx merge; both empty → byte-identical to case 1/2 plans.
8. **Caps-in-service respected:** fake refuses above `per_band_cap` → builder's plan degrades without error and never bypasses the service.

Plus the existing suite as regression: `test_new_hazard_spawn` (through the façade, unmodified), `test_rg1_m14/m15_verify`, `test_per_room_density`, `test_bandgen_determinism` + S1's pipeline parity test (through the new `:209` call site), `test_run_config` (extended with the two new flat-dict keys).

---

## 4. Files to create / touch

**Create:**
- `systems/oppositions/encounter_builder.gd` — `EncounterBuilder` (§3.1/§3.2).
- `tests/test_encounter_builder.gd` + `.tscn` (§3.5, runs as a SCENE).

**Touch:**
- `scenes/game/main_game.gd` — the sole-writer rewrite: `:209` pipeline switch, policy deletion, façade, `_resolve_band_profile()` seam (§3.4).
- `data/run_config/run_config.gd` — the two `@export_storage` levers + `to_flat_dict()` rows (§3.3). Legacy groups byte-untouched.
- `systems/oppositions/spawn_service.gd` (S0's file) — **only if** §2.6.b/§2.6.c require the additive queries (`filter_spawnable_cells`, `floor_bounds_world`, `legacy_band_ceiling`, entry-exclusion setter); no cap-logic change.
- `tests/test_run_config.gd` — assert the two new flat-dict keys + neutrality.

**Must NOT touch:** `ui/config/config_menu.gd` (S4's, Wave 4 — the `@export_storage` trick exists precisely to avoid this), `systems/event_bus.gd` (S0 pre-declared everything), `systems/game_state.gd` (the profile seam stays in `main_game` until S8 — §6 Q2), `data/run_config/run_config.tres` (never re-save — §2.6.g), the R1/J2/J3 plan helpers beyond re-pointing their shared-walk calls, anything in `systems/bandgen/` (S1's).

## 5. Definition of done (restated, concrete)

1. **All-off fp `e943ac9c8bc1` byte-identical through both new call sites** (`test_rg1_m1*_verify` fp pins + `test_corridor_lever` + S1's parity test, all green on the rewired `main_game`).
2. **Preset byte-parity:** `test_encounter_builder` case 2 proves the ordered (def, cell, ctx) plan equals the pre-extraction math; `test_new_hazard_spawn` green **unmodified** through the façade; `test_rg1_m14/m15_verify` green.
3. **Bandgen determinism suite green through the pipeline path** (`test_bandgen_determinism` + every procgen test, with `main_game` on `BandPipeline`).
4. **`test_encounter_builder` green:** budget math, `min_band` gating, deterministic draw order, fair-share/starvation, lever neutrality (§3.5 cases 1–8).
5. **Legacy knobs untouched:** `git diff run_config.gd` shows only the additive S3 block; `to_flat_dict()` legacy rows byte-identical; `has_full_coverage()` still passes with 89 rows (no `config_menu.gd` edit).
6. **R1 lanes pinned in place:** `test_per_room_density` (golden) + `test_hazard_spread` + `test_rg1_m13_verify` green without edits.
7. Import + smoke green; worklog at `worklogs/2026-MM-DD-S3-general-purpose.md` naming the commit SHA(s) + a Design deviations section; board mirrored.

## 6. Open Questions

- **Q1 — Is preset parity byte-exact (same cells, same ctx, same order) or cohort-exact (same counts per kind)? (acceptance-bar definition — resolver, with Director visibility.)** **Recommendation: byte-exact.** Three reasons. (i) *Cohort-exact is a leaky net here:* placement is run-state and invisible to `fingerprint()`, so the fp tests catch nothing about it — counts could match while every cell and every ping-pong heading (`initial_dir` keys on the order-coupled global `spawned_total`, §2.2 step 6) silently drifts, and the Director's "same preset, same feel" comparison across the M1.9 gate would be quietly false. (ii) *Byte-exact is nearly free:* the machine being moved is deterministic and RNG-free, so "same inputs → same ordered outputs" holds by construction if the relocation is faithful — the only real threats are the stride-after-filter ordering trap (§2.6.b) and the clamp order (P7), both of which a plan-equality test catches instantly and a count test never would. (iii) *The pins already exist:* `test_rg1_m14`'s math mirror + `test_new_hazard_spawn`'s position asserts are byte-grade; declaring the bar cohort-exact would mean weakening existing tests. **How:** the FakeSpawnService plan-capture test (§3.5 case 2) asserting ordered `(def_id, cell, ctx)` equality against a verbatim mirror of the old math, plus the unmodified façade-driven suite.
- **Q2 — Where does the dive's active `BandProfile` come from in S3, before S8 wires the portal? (integration seam — resolver; S8 coordination.)** Options: (a) a `main_game`-local `_resolve_band_profile()` returning `band_greybox.tres` by const path — S8 later rewires that one function to read its routing seam; (b) a `GameState` run-state field (`dive_band_profile`) added now, pre-agreeing S8's shape. **Recommendation: (a).** It keeps S3 out of `game_state.gd` (whose seam shape is explicitly S8's resolved design per the breakdown, with S0 having pre-declared only the *signal*), costs S8 a one-line rewire, and leaves no dead run-state field if S8's design lands differently. **(Q2b, same seam:** `run_started`'s band tag — keep `BAND_ID = &"near"` (`main_game.gd:39`) for the default dive in S3 rather than switching to `profile.id`, so the telemetry cohort label doesn't fork mid-version; S8 owns the `band_id` stamping story in Wave 5.)
- **Q3 — Does Instability `I` exist as a named function now, or stay inline `band_depth` math? (scope — resolver; breakdown OQ6 already leans this way.)** **Recommendation: a named static** — `EncounterBuilder.instability(band_depth)` (§3.1) — because S7 authors `band_depth=2` against it, SG2's "is band_two's I-scaled budget sane" question needs one nameable knob, and M2's real I system then has exactly one call site to replace. It is a function, not a system: no stat scaling, no loot coupling in M1.9. *Normalization sub-question:* the exploration writes `1 + 0.15*band_depth` (band 1 → 1.15); a `1 + 0.15*(band_depth−1)` form makes band 1 the 1.0 baseline. Since credits bind only on deck bands (Q5) and the first deck band is band_two, either works — recommend the exploration's form as written, with `BASE_CREDITS` tuned against band_two at SG2, both flagged tunable.
- **Q4 — Do the R1 pursuers join the builder now, or stay a parallel path this version? (scope — resolver.)** **Recommendation: stay parallel in M1.9** (already committed in §2.1; ratify or reverse here). For: the J2/J3 plans are pinned by a byte-frozen golden (`test_per_room_density.gd:116` — "MUST NOT refactor"), their placement policy (depth-spread + area-density) is genuinely different machinery from the fair-share walk, their mechanism half already goes through the service post-S0, and the migration contract keeps the R1 knob group alive regardless — so moving the plans buys zero M1.9 capability at real parity risk in the version's riskiest wave. Against: `main_game` keeps ~200 lines of R1 plan policy, and the pursuer participates in band_two only via its *def* in the deck (deck-lane placement, not J2/J3 spread — an accepted asymmetry: band_two's pursuer distribution is deck policy, band 1's is the pinned legacy plan). Retirement is a named post-gate follow-up alongside legacy-signal retirement (SG3 watch-item).
- **Q5 — Credit budget vs legacy per-type counts — which binds on the parity path? (architecture invariant — resolver.)** **Recommendation (per the task brief): legacy counts bind; credits bind only for deck-driven bands.** The legacy lane never consults `BASE_CREDITS`/`I` — its budget *is* the fair-share ceiling split (P3/P7), byte-for-byte. Running both accountings on band 1 ("credits, but floored to match the preset") cannot be made byte-exact for every knob configuration a sweep can stage and would make the parity bar unprovable. One machine per lane; the ceiling *constant* stays service-side either way (P11); the deck lane's credits meet the service's caps as budget-vs-ceiling, exactly the exploration's split.
- **Q6 — Found during research (each needs a resolver call):**
  - **(i) `oppositions_enabled` semantics** — additive enable-list (recommended, §3.3: sweeps can *add* defs anywhere; band decks are author-owned and never subtracted by config) vs whitelist-filter over decks (gives SG2 a "band_two minus its deck" control cell, but makes empty-vs-nonempty semantics bite band content and risks a config-trap class S4 would then have to detect). If SG2 needs a deck-off control cell, prefer expressing it later as an explicit debug lever, not by overloading this one.
  - **(ii) `param_overrides` reach** — def-driven params only (recommended: legacy lane's entity knobs stay driven by the legacy `rc` fields they snapshot today; overrides double-driving `hpp_speed` through two channels in one run invites divergence) vs also aliasing legacy knobs (more sweep power, S4 can revisit when the generated sections land).
  - **(iii) `spawn_weight`** — inert/reserved this version (recommended: deterministic authored deck order; a weighted draw needs a seeded sub-stream under the `(seed+config)` contract — legal via the `_JUNK_SALT` pattern, but new determinism surface with zero M1.9 content need) vs implement now for S7's deck authoring.
  - **(iv) The `BandPipeline` rc-threading + catalog-swap ownership (§2.6.a)** — assumed landed in S1; if not, S3 escalates before writing code (hard stop, not a workaround).
  - **(v) The BUG7 queryable-predicate requirement (§2.6.b)** and **the two-ceiling cap domains (§2.6.c)** — stated here as S0-contract verifications with S3-side additive fixes if needed; flag any mismatch in the S3 worklog's deviations section.

---

## 7. Resolved Decisions (Phase 3)

**Fresh-eyes resolution, 2026-07-02** — resolver is not the Phase-2 author. Every §6 question is closed below; the orchestrator's cross-contract adjudications (fixed across S0–S8's Phase-3 passes) are folded in as **RESOLVED (adjudicated)**. All load-bearing claims were re-verified against the as-built code (`main` @ `4bffe80`, which is `6fbded1` + the two design-doc commits — code untouched) and against the sibling Phase-2 designs. **Nothing here needs a new Director call** — Q1's acceptance bar and Q4's scope call were the two flagged candidates and the resolver *agrees* with both recommendations (Q4's is additionally orchestrator-adjudicated); they surface to the Director in the normal wave brief, not as open questions. The implementing agent reads §6 recommendations as **committed**, amended by the corrections below.

### 7.1 Verification results — claim corrections (read before building)

Spot-verification outcome: the doc is substantially accurate — every P1–P12 file:line cite checked out against `main_game.gd` as-built (P1 `:357-365`, P2 `:409-422`, P3 `:424-426`/`:430-435`, P5 `:454-455`, P6 `:457`, P7 `:458-461`, P8 `:464-471` + const `:350`, P9 `:473-475`, P10 `:483`/`:496-507`/`:341`/`:514-520`, P11 `:337`, P12 `:198-215`), as did the R1-lane cites (`:534`, `:587`, `:616`, `:671`, `:734`, `:751`, `:772`, `:814`), the `run_config.gd` cites (`:37`, `:57-126`, `:298-361`, `:429`, `:455-566`, `:662-855`), the `test_per_room_density.gd:116-125` byte-frozen golden + "MUST NOT refactor" comment, the `test_rg1_m14_verify.gd:287-320` count-math mirror (`_plan_counts` at `:322`), and `test_new_hazard_spawn.gd`'s 8 `_spawn_new_hazards` call sites. One code-comment trap confirmed in the doc's favor: `main_game.gd:495`'s docstring calls `index` "the global **per-type** spawn index" but the call at `:483` passes the **cross-type** `spawned_total` — §2.2 step 6 reads the code correctly; the docstring is wrong (fix it in passing when the forwarder lands). Four corrections:

- **(C1) The `@export_storage` coverage claim is REAL — empirically verified on the pinned Godot 4.6.3.** A headless probe of a Resource with `@export_storage var x: Array[StringName]` / `@export_storage var y: Dictionary` reports `usage = 4098` (`SCRIPT_VARIABLE | STORAGE`), **`PROPERTY_USAGE_EDITOR` absent** — vs `4102` (EDITOR set) for a plain `@export`. `config_menu._exported_config_fields()` (`config_menu.gd:446-455`) filters `STORAGE && EDITOR`, so both levers are invisible to `has_full_coverage()` (`:414-437`) and the 89-row assertion holds untouched, exactly as §2.6.f claims — including for the typed-Array and Dictionary forms. The menu's two other `get_property_list()` loops (`:1274`, `:1282`) are name-keyed lookups driven only by already-bound MANIFEST fields — no leak path.
- **(C2) §3.4's deletion list is overbroad and would break the "tests green unmodified" DoD — retain three surfaces.** The suite reads `main_game` beyond the `_spawn_new_hazards` façade: `test_new_hazard_spawn.gd:44` reads `mg_script.NEW_HAZARD_BAND_CEILING`, `:172` reads `mg_script.NEW_HAZARD_SPAWN_SAFE_CELLS`, and `:152`/`:158`/`:164` call `mg._new_hazard_spawn_ctx(...)` **directly**; `test_rg1_m14_verify.gd:299` and `:403` read `mg.NEW_HAZARD_BAND_CEILING`. So `main_game` must **keep**: (i) `NEW_HAZARD_BAND_CEILING` and (ii) `NEW_HAZARD_SPAWN_SAFE_CELLS` as re-export consts aliasing the relocated service constants (S0's own design already anticipates exactly this — its caps section says "`main_game.gd` re-exports it or the tests read it off the service script"), and (iii) `_new_hazard_spawn_ctx` as a thin forwarder to the builder's ctx builder (same signature/arity — the three direct calls assert semantic ctx contents and pass green through a forwarder). The golden-angle const CAN move (no test reads it directly — verified by grep). Amended §3.4 ledger: *deleted* = `_new_hazard_descriptors`, the `_spawn_new_hazards` internals, `NEW_HAZARD_GOLDEN_ANGLE`; *retained* = the `_spawn_new_hazards` façade, the `_new_hazard_spawn_ctx` forwarder, the two re-export consts.
- **(C3) S0's landed API names differ from §3.1/§3.4's illustrative names — S0's are contractual.** Per S0's design (its §3.1 service surface): the queryable BUG7 predicate is **`valid_cells(cells: Array[Vector2i]) -> Array[Vector2i]`** (not `filter_spawnable_cells`), exposed precisely so policy can filter-then-stride at the current sequence point — §2.6.b's requirement is **met, not at-risk**; per-band arming is **`begin_band(container, cell_size_px, entry_pos, ...)`** (not `set_entry_exclusion`), and the façade must call it with the recomputed `_entry_spawn_position(band)` when `spawn_pos == Vector2.INF` (test `:184` relies on that recompute); projection is the **public `cell_to_world()`**. And `_piece_floor_bounds_world` **stays policy-side** per S0's line-by-line ledger ("Stays — feeds the ctx, policy-owned") — the builder computes room bounds itself over `svc.cell_to_world()`, there is no `svc.floor_bounds_world()`. S0's design also already handles the bare-instance test harness (service constructible out-of-tree; never parented under `_band_container`, so child-count asserts don't shift) — the façade-keeps-`test_new_hazard_spawn`-green claim is real *given C2*.
- **(C4) Deck-lane pseudocode bug: `band.band_depth` does not exist.** `Band` (`systems/bandgen/band.gd`) carries `max_depth`, not `band_depth` — the band's depth *number* is **`BandProfile.band_depth`** (S1 schema). §3.1's `_populate_deck` must gate `min_band` off the profile's value (thread `profile.band_depth` or the resolved `I`'s input into the lane), same source as `instability()` already uses.

### 7.2 The decisions

- **Q1 — Acceptance bar. RESOLVED: byte-exact (ordered `(def_id, cell, ctx)` plan equality).** The recommendation's three arguments hold on inspection, and the provability question closes affirmatively: the machine being relocated is RNG-free and deterministic (verified — no `RNG` reads anywhere in `main_game.gd:385-507`), and the independent mirror the test extends already exists (`test_rg1_m14_verify.gd:287-322`); extending it from counts to cells+ctx is mechanical. **Two implementation notes for §3.5 case 2:** (i) the FakeSpawnService must satisfy `populate()`'s `svc` parameter type — prefer `extends SpawnService` overriding `spawn()`/`valid_cells()` (GDScript methods are virtual by default; keeps the static type) over loosening the signature; (ii) the fake must be armed (`begin_band`) with the same `entry_pos`/`cell_size_px` the mirror math uses, or the BUG7 filter diverges and the "parity" failure is a harness artifact. Byte-exactness *through the façade* additionally requires the C3 recompute-when-INF behavior.
- **Q2 — Profile seam. RESOLVED: (a)** — `main_game`-local `_resolve_band_profile()` returning `res://data/bands/band_greybox.tres` by const path; **id confirmed `&"band_greybox"`, location confirmed** against S1's §4 (the authored `.tres` sets `id = &"band_greybox"`, `piece_pool` = baseline `piece_catalog.tres`). Aligned with S8's ratified A+C hybrid *(adjudicated)*: **no new signal** — `dive_requested(band_id)` already carries the id (declared M1.6, `event_bus.gd:197`); `GameState` self-subscribes, stages `_pending_dive_band` (run-state, never persisted), and exposes **`consume_pending_dive_band() -> StringName`**. S3 shapes `_resolve_band_profile()` so S8's Wave-5 rewire is confined to that one function body (consume key → key→profile map → `load`; unknown/empty key falls back to the greybox control). **Q2b RESOLVED: keep `BAND_ID := &"near"` in S3** — S8's own design keeps `&"near"` as the greybox band's telemetry vocabulary (its key map reads `&"near" → &"band_greybox"`), so the cohort label stays continuous and S8 owns the stamping story in Wave 5.
- **Q3 — Instability. RESOLVED (adjudicated): named static `EncounterBuilder.instability(band_depth)`, a function not a system — with the normalization PINNED the other way from the §6 lean: band 1 → I = 1.0.** The formula is **`I = 1.0 + 0.15 * (band_depth - 1)`**, *not* the exploration's/§3.1-pseudocode's `1.0 + 0.15 * band_depth` — amend the §3.1 sketch accordingly. Rationale beyond the adjudication: the extras lane (`oppositions_enabled`) rides the deck machinery **on band 1 too**, so `instability(1)` is consulted the moment a sweep stages an extra on the default band — pinning band 1 at exactly `1.0` keeps the parity band the clean baseline (a band-1 extras sweep gets exactly `BASE_CREDITS`) and gives `band_two` (`band_depth = 2`) one clean +15% step (I = 1.15), matching the GDD's "+15%/band" read as *per band descended*. `BASE_CREDITS` stays a Director-sweepable tunable at SG2. M2's real I system replaces the one call site.
- **Q4 — R1 pursuers. RESOLVED (ratified, adjudicated): stay parallel through M1.9.** §2.1's commitment stands as written; the byte-frozen golden (`test_per_room_density.gd:116-125`) and the zero-capability/real-risk trade were re-verified. **Cap domains stay separate through M1.9** *(adjudicated)*: K5's 48 flows through the service as S0's scoped cap group (`set_cap_group(&"new_hazards", 48)`), R1's 64 (`R1_DENSITY_BAND_CEILING`, `run_config.gd:37`) stays loop-side legacy and untouched — §2.6.c is confirmed against S0's design, which explicitly does not touch the 64. True unification + R1-plan retirement is the named post-gate follow-up (SG3 watch-item).
- **Q5 — Which budget binds. RESOLVED (adjudicated): legacy counts bind on the parity path; credits bind only for deck-driven bands** (and the extras lane, which is deck machinery by construction). The legacy lane never consults `BASE_CREDITS`/`I`; one accounting machine per lane; the ceiling constant stays service-side (P11). Confirmed against the exploration's §RunConfig-integration text.
- **Q6(i) — `oppositions_enabled`. RESOLVED (adjudicated): additive enable-list** exactly as §3.3 — appends id-deduped defs through the deck machinery, never subtracts a band author's deck; empty = neutral = byte-identical baseline. A deck-off control cell for SG2, if wanted, is a later explicit debug lever.
- **Q6(ii) — `param_overrides` reach. RESOLVED (adjudicated): def-driven params only** (deck lane + extras, at ctx-merge time). Legacy entity knobs stay driven by the rc fields they snapshot at `setup()` — no double-driving in M1.9. S4 may revisit aliasing when the generated sections land.
- **Q6(iii) — `spawn_weight`. RESOLVED (adjudicated): reserved/inert in M1.9.** Deterministic authored-order draw; consistent with the exploration's own pseudocode, which filters and walks the deck in order with no weighted draw. A weighted draw (seeded sub-stream, `_JUNK_SALT` pattern) is deferred until content needs it.
- **Q6(iv) — `BandPipeline` rc-threading + catalog swap. RESOLVED — verified in S1's design, no escalation needed.** The signature is **`BandPipeline.generate(profile: BandProfile, seed: int, rc: RunConfig = null) -> Band`** (S1 §3.3) — rc threads the r4_*/lvl_*/corridor levers through the generator's existing interior hooks; grading + return-distance are inside the pipeline; `SocketSealer` stays at materialise time. The `lvl_enabled` ext-catalog swap has an **orchestrator-adjudicated answer in S1's doc (its OQ3): an optional `piece_pool_ext: PieceCatalog` profile field lands WITH S3's call-site switch** — the pipeline consults `rc.lvl_enabled` and swaps to `profile.piece_pool_ext` when set (`band_greybox.tres` authors `piece_pool` = baseline). This **supersedes §2.4 assumption (ii)'s fallback** (keeping the 3 swap lines at the call site): S3 adds the profile field + pipeline conditional per S1-OQ3(a), and the preset-parity DoD explicitly includes a `lvl_enabled = true` run through the switch.
- **Q6(v) — BUG7 queryable + two ceilings. RESOLVED — both confirmed against S0's design** (see C3/C4 and Q4): `valid_cells()` exists as a first-class queryable for filter-then-stride (§2.6.b's contingency "S3 adds the query" is not needed); the cap domains are already scoped groups with R1's 64 untouched (§2.6.c's risk is designed out). Standing instruction unchanged: re-verify both against S0's *worklog* at brief time; any drift goes in S3's deviations section.

### 7.3 Cross-contract handoff notes (orchestrator-adjudicated, for the record)

- **RunConfig levers land `@export_storage` in S3/Wave 3** — coverage untouched, the 89-row assertion holds (C1's empirical proof). **S4 owns the Wave-4 surfacing decision + the final knob-count model.** S4's Phase-2 doc assumed plain `@export` levers bound into the legacy coverage net — that assumption is corrected on S4's side; S3 must not pre-empt it (no `config_menu.gd` edit, no coverage-net rows, exactly as §4's must-not-touch list says).
- **Band routing** reuses `dive_requested(band_id)` + the GameState staging seam per S8's resolved design (no new signal, no `game_state.gd` edit in S3) — the `_resolve_band_profile()` seam in Q2 is shaped for S8's one-function rewire.

---

*Spec authored for M1.9 S3 (Phase-2 fan-out). §6's questions are CLOSED by §7 (Phase-3 fresh-eyes resolution, 2026-07-02, with orchestrator cross-contract adjudications folded in): the implementing agent builds against §6's recommendations as committed decisions, amended by §7.1's corrections C1–C4 and §7.2's Q3 normalization + Q6(iv) supersession. Deviations during the build go to `design/DESIGN_DEVIATIONS.md` for the Wave-3 close-out sweep.*

---

## Wave-3 close-out amendments (as-built, Director-dispositioned 2026-07-03)

- **Bandgen surface touched per binding §7.2 Q6(iv)** (Director: **Reviewed**) — `piece_pool_ext`
  profile field + pipeline-owned `lvl_enabled` ext-catalog swap landed with the call-site switch
  (parity test P5/P0 amended to match); swap inert for null `piece_pool_ext`.
- **`param_overrides` telemetry stamp is FLAT dotted rows** (Director: **Addressed** → flattened at
  close-out) — `to_flat_dict()` emits `param_overrides.<def_id>.<param_key>` → primitive (no base
  key; zero rows when neutral); the no-nesting pin is absolute again; breakdown amendment 10 updated;
  **S4 must assert the dotted shape**.
- **§3.5 case-7 corrected** (Director: **Reviewed**) — `oppositions_enabled` alone spawns zero (S2's
  cards are neutral); enabling requires a `param_overrides` count. **S4 flag:** the config-trap
  generalization should consider warning on "enabled def id with a fully-neutral card".
- **Deck-lane ctx enrichment stands** (Director: **Reviewed**) — per-piece cell computation + per-kind
  legacy ctx vocabulary (`initial_dir`/`room_bounds`/`phase_salt`) + `room_key`; determinism-neutral;
  keeps existing hazards authorable into S7's band_two deck on their locked contract.
- **`EncounterBuilder.is_inert(profile, rc)` pre-flight stands** (Director: **Reviewed**) — the
  façade's pre-check is how S0's all-off "no def, no scene, NO service node" contract survives the
  extraction.
