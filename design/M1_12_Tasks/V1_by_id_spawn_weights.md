# V1 / R2 — Kill the index-aligned spawn weights (Phase-2 design)

> **Milestone:** M1.12 (Wave 1) · **Assignee:** game-director-designer (data/schema) +
> general-purpose (read-site + tests) · **BlockedBy:** none
> **Master contract:** behavior-preserving. The by-id weights MUST resolve to the exact
> current numeric values so junk placement stays byte-identical (junk fingerprint unmoved).
> **DR-2 (ratified rec):** by-**id** `Dictionary` on `JunkCatalog`, NOT weight-on-`JunkItem`.

---

## (a) Research on the premise

### The fragile surface, exactly as built

`JunkCatalog` (`Game/data/junk/junk_catalog.gd`) declares **two parallel `@export`s** that
must stay positionally aligned by hand:

```gdscript
# junk_catalog.gd:13-15
@export var items: Array[JunkItem] = []
# Per-item spawn weight, index-aligned with `items` (higher = more common).
@export var spawn_weights: PackedFloat32Array = PackedFloat32Array()
```

The authored resource (`Game/data/junk/junk_catalog.tres:16-17`) carries 8 items and a
positional weight vector:

```
items = Array[ExtResource("9")]([ExtResource("1"), … ExtResource("8")])
spawn_weights = PackedFloat32Array(40, 30, 18, 14, 4, 8, 5, 2)
```

Resolving `items` → `.tres` → id/tier gives the **canonical order + weight mapping** this task
must preserve to the number (verified in-repo 2026-07-10):

| idx | item `.tres` | `id` | `tier` | `spawn_weights[idx]` |
|----:|--------------|------|:------:|---------------------:|
| 0 | `junk_scrap_bolt.tres`     | `&"junk_scrap_bolt"`     | 1 | 40 |
| 1 | `junk_cable_coil.tres`     | `&"junk_cable_coil"`     | 1 | 30 |
| 2 | `junk_copper_pipe.tres`    | `&"junk_copper_pipe"`    | 2 | 18 |
| 3 | `junk_hubcap.tres`         | `&"junk_hubcap"`         | 2 | 14 |
| 4 | `junk_circuit_board.tres`  | `&"junk_circuit_board"`  | 3 |  4 |
| 5 | `junk_car_battery.tres`    | `&"junk_car_battery"`    | 3 |  8 |
| 6 | `junk_radiator.tres`       | `&"junk_radiator"`       | 4 |  5 |
| 7 | `junk_engine_block.tres`   | `&"junk_engine_block"`   | 5 |  2 |

The failure mode is the classic parallel-array hazard: **inserting/removing/reordering an item
in `items` silently misaligns every weight at or below that index.** A designer duplicating a
`.tres` and dropping it into the middle of `items` (the exact workflow `junk_item.gd:6` invites —
"duplicating a `.tres` and editing fields in the inspector") would shift the weight vector out
from under half the catalog with **no error at load, at import, or in CI** (see the CI gap below).

### The catalog's own docstring already argues the fix

The class docstring is not neutral — it makes the design argument **for a by-id map on the
catalog and against putting the weight on `JunkItem`**:

```gdscript
# junk_catalog.gd:6-10
## … Spawn rarity lives HERE, not on the
## JunkItem — rarity is a property of a spawn context, not of the item's identity,
## so a future second catalog can reweight the shared item set without editing
## every `.tres`.
```

The report's alternate (put a `spawn_weight` field on `JunkItem`) would **contradict this file's
stated design**: it moves rarity onto item identity, so a hypothetical second catalog sharing the
same item set could no longer reweight without editing every item `.tres`. DR-2 therefore keeps
rarity a **catalog-side, spawn-context property** and only changes its *keying* from positional
(index) to nominal (id). The one thing wrong with today's field is the index alignment; DR-2
fixes exactly that and nothing else.

### The single weighted consumer

`spawn_weights` has exactly **one** read site: `JunkPlacer._weighted_pick`
(`Game/systems/depth/junk_placer.gd:166-184`). (Repo-wide grep confirms: the only other
`spawn_weights` hits are the field decl, the `.tres`, two docstring mentions, the CI check, and a
`shop_catalog.gd:8` comment noting the Shop deliberately has none.)

```gdscript
# junk_placer.gd:166-184 — the weighted pick
func _weighted_pick(catalog: JunkCatalog, indices: Array[int],
        rng: RandomNumberGenerator) -> int:
    const SCALE := 1000
    var cum: Array[int] = []
    var running := 0
    for idx in indices:                       # <-- iterates `indices`, catalog order
        var w := 1.0
        if idx < catalog.spawn_weights.size():
            w = maxf(catalog.spawn_weights[idx], 0.0)
        var iw := int(round(w * SCALE))
        if iw <= 0:
            iw = 1
        running += iw
        cum.append(running)
    var roll := rng.randi_range(0, running - 1)
    for k in cum.size():
        if roll < cum[k]:
            return indices[k]
    return indices[indices.size() - 1]        # defensive
```

Three determinism-load-bearing facts this task must not disturb:

1. **`indices` is already in stable catalog order.** It is produced by `_eligible_indices`
   (`junk_placer.gd:154-160`), which iterates `for i in catalog.items.size()` and appends
   ascending — so the cumulative table is built in `items`-array order, not in any hash order.
2. **The whole pick consumes exactly one `rng` draw:** `rng.randi_range(0, running - 1)`
   (`:180`). The RNG sequence is a function of `running` (the integer weight sum) and nothing
   else about representation. If the by-id lookup yields the **same weight per eligible index in
   the same order**, `running`, the `cum` table, `roll`, and the returned index are all
   byte-identical → the plan and its `plan_fingerprint` (`:126-131`) are byte-identical.
3. **The default-and-clamp semantics:** missing weight → `1.0` (the `if idx < size` guard),
   then `maxf(w, 0.0)`, then `int(round(w * SCALE))` with a `>= 1` floor. All three must survive
   verbatim in the by-id form (missing *id* → `1.0`, same clamp, same floor). At `SCALE = 1000`
   the current weights map to integer `iw` of `40000, 30000, 18000, 14000, 4000, 8000, 5000,
   2000` — a `Dictionary`-stored `float` of `40.0` yields `int(round(40.0 * 1000)) = 40000`
   identically, so byte-identity holds.

### The CI validation — and a real gap to close

`Game/tools/check_junk_catalog.gd` is the "C1 headless data check." Its alignment assertion is:

```gdscript
# check_junk_catalog.gd:26-27
if cat.spawn_weights.size() != cat.items.size():
    failures.append("spawn_weights (%d) not index-aligned with items (%d)" % [...])
```

**This check is size-only, and size-only cannot catch the bug it names.** After a mid-list insert
where the designer *also* adds a weight (in the wrong position), `.size()` still equals
`.size()` — the values are silently transposed and CI stays green. The current gate detects a
*count* mismatch, never a *mapping* mismatch. The by-id representation makes the check
**semantic** (id-coverage + no-orphans), which is strictly stronger.

> **Finding (flag to orchestrator):** `check_junk_catalog.gd` is **not actually invoked by
> either CI workflow.** `.github/workflows/ci.yml` and `nightly.yml` run only
> `res://tools/ci_smoke_test.gd` (plus the migration/duration/GdUnit4 steps); neither runs
> `check_junk_catalog.gd`, despite its docstring claiming it "can gate CI alongside
> `ci_smoke_test.gd`." Strengthening a validator that never runs buys nothing. V1 should
> **wire `check_junk_catalog.gd` into `ci.yml`** (a one-line `--script` step) so the new
> id-coverage assertions actually gate merges. See Open Question Q4.

---

## (b) Pseudocode

### 1. New catalog field (`junk_catalog.gd`)

Replace the parallel `PackedFloat32Array` with a typed by-id map. Godot 4.4+ supports typed
`Dictionary`; 4.6 (our pin) honors `Dictionary[StringName, float]` in the inspector and `.tres`.

```gdscript
# junk_catalog.gd (replaces lines 12-15)

# Authored spawn pool. B2 generator + tooling read from here.
@export var items: Array[JunkItem] = []

## Per-item spawn weight, keyed by JunkItem.id (higher = more common). By-id, NOT
## index-aligned: inserting/removing/reordering `items` can never misalign a weight.
## Rarity stays a spawn-context property of THIS catalog (see class docstring), so a
## second catalog can reweight the shared item set by authoring a different map.
## An item with no entry defaults to weight 1.0 at pick time (JunkPlacer).
@export var spawn_weights_by_id: Dictionary[StringName, float] = {}
```

> Field is **renamed** (`spawn_weights` → `spawn_weights_by_id`), not overloaded — a clean break
> so no stale index-array can linger. No compatibility shim: the single consumer + the CI check +
> the one `.tres` are all updated in the same commit (V6 in Wave 2 later touches this same file's
> consumer, sequenced after V1 per the breakdown's cross-wave file-sequencing).

### 2. `.tres` regeneration (`junk_catalog.tres`)

Drop the `spawn_weights` line; add the by-id map. Values are the exact current numbers, so the
resolved per-item weight is unchanged.

```
[resource]
script = ExtResource("0")
items = Array[ExtResource("9")]([ExtResource("1"), ExtResource("2"), ExtResource("3"), ExtResource("4"), ExtResource("5"), ExtResource("6"), ExtResource("7"), ExtResource("8")])
spawn_weights_by_id = {
&"junk_scrap_bolt": 40.0,
&"junk_cable_coil": 30.0,
&"junk_copper_pipe": 18.0,
&"junk_hubcap": 14.0,
&"junk_circuit_board": 4.0,
&"junk_car_battery": 8.0,
&"junk_radiator": 5.0,
&"junk_engine_block": 2.0,
}
```

> Regenerate by editing in the Godot inspector (preferred — guarantees the engine's canonical
> `.tres` serialization + `load_steps` accounting) rather than hand-editing, then confirm the diff
> matches the table above. The `ext_resource` block (the 8 item refs + the two scripts) is
> unchanged; only the `[resource]` body swaps one line for the map. **Verify the exact serialized
> form the editor emits** (inline `{…}` vs. multi-line, key spelling) and pin *that* — see Q1.

### 3. Read-site change (`junk_placer.gd._weighted_pick`)

Only the per-index weight *lookup* changes; the stable-order iteration, the scale, the clamp, the
floor, and the single `randi_range` draw are all preserved verbatim. **Iterate `indices` (catalog
array order) and look up each item's weight by its id** — never iterate the Dictionary's keys
(hash order would reorder the cumulative table and, although `running` would be unchanged, is a
latent footgun; keeping the array-order iteration is what guarantees byte-identity).

```gdscript
func _weighted_pick(catalog: JunkCatalog, indices: Array[int],
        rng: RandomNumberGenerator) -> int:
    const SCALE := 1000
    var cum: Array[int] = []
    var running := 0
    for idx in indices:                        # UNCHANGED: stable catalog order (see _eligible_indices)
        var it: JunkItem = catalog.items[idx]
        var id: StringName = it.id if it != null else &""
        # By-id lookup; missing id -> 1.0 default (== the old `w := 1.0` fallback),
        # same maxf(.,0.0) clamp, same int(round(.*SCALE)) with >=1 floor.
        var w := maxf(float(catalog.spawn_weights_by_id.get(id, 1.0)), 0.0)
        var iw := int(round(w * SCALE))
        if iw <= 0:
            iw = 1
        running += iw
        cum.append(running)
    var roll := rng.randi_range(0, running - 1)  # UNCHANGED: one draw, identical range
    for k in cum.size():
        if roll < cum[k]:
            return indices[k]
    return indices[indices.size() - 1]           # defensive, UNCHANGED
```

Update the two docstring lines that mention "index-aligned `spawn_weights`"
(`junk_placer.gd:163-165`) to describe the by-id lookup.

**Byte-identity argument (why the junk fp does not move):** for any eligible-index list, the
sequence of `w` values is `{scrap_bolt:40, cable_coil:30, …}` keyed by the same ids the old code
reached positionally — identical floats → identical `iw` → identical `running` and `cum` →
identical `roll = randi_range(0, running-1)` (one draw, same bounds) → identical returned index.
No other RNG consumer in `plan()` is touched, so the entire draw sequence and every
`world_pos`/`base_sell_value` in the plan are unchanged. `plan_fingerprint` is byte-identical.

### 4. CI validation (`check_junk_catalog.gd`)

Replace the size-only alignment assertion (`:26-27`) with three semantic assertions:
**id-coverage** (every item has a weight), **no-orphans** (every weight key is a real item id),
**no-duplicate-id** (already present at `:38-39`, keep). Reuse the `seen_ids` walk.

```gdscript
# check_junk_catalog.gd — replace lines 26-27; extend the existing item walk

# (existing loop at :32 already builds seen_ids and checks empty/dup id, value, tier)
# After the loop, validate the by-id weight map against the item id set:

# id-coverage: every item id must have a weight entry.
for it in cat.items:
    if it != null and it.id != &"" and not cat.spawn_weights_by_id.has(it.id):
        failures.append("item '%s' has no spawn_weights_by_id entry" % it.id)

# no-orphans: every weight key must correspond to a catalog item id.
for key in cat.spawn_weights_by_id:
    if not seen_ids.has(key):
        failures.append("spawn_weights_by_id has orphan key with no item: %s" % key)

# non-negative weights (mirrors JunkPlacer's maxf(.,0.0) intent — a negative
# authored weight is an authoring error, not a silent clamp).
for key in cat.spawn_weights_by_id:
    if float(cat.spawn_weights_by_id[key]) < 0.0:
        failures.append("spawn_weights_by_id[%s] is negative: %s" % [key, cat.spawn_weights_by_id[key]])
```

Note: `no-duplicate-id` is already enforced by the existing `seen_ids.has(it.id)` check
(`:38-39`); the by-id map makes duplicate ids *also* a functional collision (last-writer-wins in
the map), so the existing check now guards the weight mapping too — call that out in a comment.
Update the leading docstring (`:2-4`) to say "by-id weights (id-coverage, no orphans)" instead of
"index-aligned weights."

### 5. Regression: mid-list-insert equivalence (new focused test)

The point of the whole task is that a mid-list insert no longer misaligns. A small headless test
demonstrates the *new* invariant holds where the *old* representation would have failed:

```gdscript
# tests/test_junk_catalog_by_id.gd  (SCENE test, self-quitting — per godot-headless memory)
# 1. Load junk_catalog.tres; snapshot resolved weight-per-id for the 8 items.
# 2. Build an in-memory catalog: insert a NEW test JunkItem at index 0 of `items`
#    WITHOUT adding a weight for it. Assert:
#      - every ORIGINAL item still resolves to its original weight (by-id: unaffected
#        by the insert — the whole point). Under the old index model this would have
#        shifted every weight by one; assert it does NOT here.
#      - the inserted item resolves to the 1.0 default at pick time (no map entry).
#      - check_junk_catalog's id-coverage assertion WOULD flag the missing entry
#        (call the validation helper, expect a coverage failure) — proving CI catches
#        the "forgot to add a weight" case the old size-check missed.
```

Keep it a **logic-only** test (build the `JunkCatalog`/`JunkItem` in memory; no band gen, no
scene tree beyond the self-quit) so it is cheap and does not touch the layout stream.

---

## (c) Open Questions

**Q1 — Dictionary vs. typed pair-array for `.tres`-diffability.**
DR-2 says "Dictionary." A `Dictionary[StringName, float]` is the natural fit and honors the
docstring, but its `.tres` serialization is engine-controlled — it may emit inline `{…}` on a
single line or one-key-per-line, and StringName keys serialize as `&"…"`. A single-line inline
map would make future weight tweaks a noisy one-line diff (whole map rewritten). The alternative
is a **typed array of a tiny `SpawnWeight` sub-resource** (`{ id: StringName, weight: float }`),
which diffs one line per entry but adds a class + `load_steps` weight and re-introduces "order in
an array" (though not *alignment* — the id is self-describing).
*Recommendation:* **use `Dictionary[StringName, float]`** (DR-2, minimal, honors the docstring);
during §b.2 regeneration, capture the editor's actual serialized form and, if it emits inline,
accept it (weight edits are rare and the map is 8 lines). Only fall back to the pair-array if the
serialized Dictionary proves unreviewable in diffs. *Technical — resolvable on merit in Phase 3;
byte-identity of the resolved weights is unaffected either way.*

**Q2 — How to guarantee stable pick order.**
The by-id map has hash-ordered keys; the weighted pick must not depend on that order. The design
keeps `_weighted_pick` iterating `indices` (catalog `items` array order via `_eligible_indices`)
and looks up each id in the map — so map hash order is irrelevant to `cum`/`roll`. Should we add a
belt-and-suspenders assertion/comment forbidding any future iteration of
`spawn_weights_by_id.keys()` in a draw path?
*Recommendation:* **keep array-order iteration (already the case), add a one-line code comment**
at the lookup ("iterate `indices`, never the map's keys — determinism") and a test assertion that
two catalogs with identical items+weights but different map *insertion order* produce identical
`plan_fingerprint`s. *Technical — resolve on merit.*

**Q3 — Does the mid-list-insert regression test belong in V1?**
It is the most direct proof the task's value landed (the anti-misalignment invariant), but it is a
*new* test, and M1.12's ethos is "remove debt, don't add surface." Options: (a) a dedicated
`test_junk_catalog_by_id.gd` (§b.5); (b) fold the id-coverage/no-orphan proof into the existing
`check_junk_catalog.gd` run and skip a new scene test; (c) both.
*Recommendation:* **(a) the small dedicated test** — it is the regression floor for the exact bug
class retired, it is logic-only/cheap, and the DoD explicitly asks for "inserting a test item
mid-list does not misalign (regression test)." The CI check proves *authoring* coverage; the unit
test proves *resolution* invariance — different guarantees, both worth pinning. *Scope — recommend
include; Director may trim to (b) if opposed to net new test files.*

**Q4 — Wire `check_junk_catalog.gd` into CI (the gap finding).**
The strengthened id-coverage/no-orphan check only pays off if CI runs it; today neither workflow
does (see Research). Adding a `--script res://tools/check_junk_catalog.gd` step to
`.github/workflows/ci.yml` is a one-line change squarely in V1's spirit (make the validator
real).
*Recommendation:* **add the CI step in V1.** It is behavior-preserving (a green check on green
data), it activates the whole point of strengthening the validator, and it is the smallest
possible surface. *Scope — recommend include; flag to orchestrator since it edits `ci.yml` (a
file outside `Game/`).* If the Director wants V1 to stay data-only, split the CI wire-up into a
one-line follow-up task, but note the strengthened check is inert until then.

**Q5 — Field rename vs. deprecation shim.**
The design renames `spawn_weights` → `spawn_weights_by_id` (clean break). Because the field is a
resource `@export`, any *external* `.tres` still referencing the old field would drop it silently
on load. Repo grep confirms **only one** `.tres` uses it (`junk_catalog.tres`), updated in the
same commit, so a shim is unnecessary.
*Recommendation:* **clean rename, no shim** — a lingering `spawn_weights` field would preserve
exactly the index-aligned footgun this task exists to delete. *Technical — resolve on merit;
low risk given the single authored catalog.*

---

## Expected debt ledger (V1)

**Net LOC:** ~neutral-to-slightly-positive (this is expected and correct for V1 — its value is a
*retired invariant*, not deleted lines; the breakdown itself frames R2 as "net-neutral LOC but
removes a whole class of silent-misalignment bug").

| Surface | Change | LOC delta (approx) |
|---|---|---:|
| `junk_catalog.gd` | swap `PackedFloat32Array` field for typed `Dictionary` map (+ docstring) | +3 |
| `junk_catalog.tres` | 1-line weight array → 8-line by-id map | +7 |
| `junk_placer.gd._weighted_pick` | index lookup → by-id lookup (same line count) + docstring | +1 |
| `check_junk_catalog.gd` | size-only assert → id-coverage + no-orphans + non-negative | +8 |
| `ci.yml` (Q4) | add the `check_junk_catalog` step | +2 |
| `tests/test_junk_catalog_by_id.gd` (Q3) | new focused regression test | +~35 |

**Fragility retired (the real deliverable — quantified):**

- **One positional-coupling invariant deleted.** An 8-element `PackedFloat32Array` was
  hand-bound by index to an 8-element `Array[JunkItem]`; any insert/remove/reorder of `items`
  silently transposed weights. That coupling is gone — weights are now self-describing by id and
  cannot misalign by construction. **Class of bug eliminated, not mitigated.**
- **CI strengthened from count-check to mapping-check.** The old gate (`spawn_weights.size() ==
  items.size()`) was **provably unable to catch the bug it named** — a mis-positioned insert that
  keeps counts equal passes it. The new gate (id-coverage + no-orphans) catches both "forgot a
  weight" and "weight for a deleted/renamed item," and duplicate-id now also guards the weight
  map. **Detection went from ~0% to 100% of the misalignment class.**
- **CI gap closed (Q4):** the validator moves from "written but never run" to "gates every
  merge" — the strengthened check becomes real coverage rather than dormant code.
- **Future R1 de-risked:** the deferred CSV item-catalog importer no longer has to preserve a
  fragile positional weight column; it authors an id→weight map (self-checking), making R1
  "strictly simpler" per the breakdown's scope note.

**Regression floor (must hold):** junk `plan_fingerprint` byte-identical for the same seed
(existing junk/placer/determinism tests — `test_junk_pickup.gd`,
`tests/procgen/test_layout_determinism.gd`, the band-profile suites — all green); the four M1.12
control layout fps unmoved (junk placement feeds none of them differently — layout fp is
pre-junk, and junk is off the layout stream by the `_JUNK_SALT` sub-stream); by-id weights resolve
to `{40,30,18,14,4,8,5,2}` exactly.

---

### Files this task edits (all paths absolute)

- `/mnt/c/source/junkyard/Game/data/junk/junk_catalog.gd` — field swap + docstring
- `/mnt/c/source/junkyard/Game/data/junk/junk_catalog.tres` — regenerate by-id map
- `/mnt/c/source/junkyard/Game/systems/depth/junk_placer.gd` — `_weighted_pick` by-id lookup + docstrings (`:163-184`)
- `/mnt/c/source/junkyard/Game/tools/check_junk_catalog.gd` — id-coverage / no-orphans / non-negative assertions
- `/mnt/c/source/junkyard/Game/tests/test_junk_catalog_by_id.gd` — **new** regression test (Q3)
- `/mnt/c/source/junkyard/.github/workflows/ci.yml` — wire the catalog check into CI (Q4, flagged: outside `Game/`)

---

## Resolved Decisions (Phase 3)

> **Fresh-eyes resolution — 2026-07-10.** A resolver who did NOT author the Phase-2 design read the
> doc against the real code (`junk_catalog.gd`, `junk_catalog.tres`, `junk_placer.gd`,
> `check_junk_catalog.gd`, `.github/workflows/{ci,nightly}.yml`) and verified every load-bearing
> claim. **All checked out**: the two parallel `@export`s (`junk_catalog.gd:13-15`), the `.tres`
> weight vector `(40,30,18,14,4,8,5,2)` (`:16-17`), `_weighted_pick` as the *sole* weighted consumer
> (`junk_placer.gd:166-184`), `_eligible_indices` ascending catalog-order (`:154-160`), the single
> `randi_range(0, running-1)` draw off the `_JUNK_SALT` sub-stream (`:26`, off the layout stream),
> the size-only CI assertion (`check_junk_catalog.gd:26-27`), and — critically — **the CI-wiring gap
> is real**: neither `ci.yml` nor `nightly.yml` invokes `check_junk_catalog.gd`. The grep in §a
> ("only one weighted consumer") reproduces exactly. **The byte-identity argument in §b.3 is sound
> and is the binding constraint on every decision below.**

### DR-2 (weight representation) — CONFIRMED on merit; **Director ratification still required**

DR-2's by-**id** `Dictionary[StringName, float]` on `JunkCatalog` is the correct representation and
is **confirmed on technical merit**. The catalog's own docstring (`junk_catalog.gd:6-10`) explicitly
argues rarity is *"a property of a spawn context, not of the item's identity,"* so a weight-on-
`JunkItem` alternate would contradict the file's stated design and block a future second reweighting
catalog. By-id keying fixes the one real defect (index coupling) and nothing else.

**This is a design/vision call, not a pure-technical one — the resolver does NOT self-ratify it.**
DR-2 is listed under the breakdown's "Needs Director review" and is **not yet marked RATIFIED** (only
DR-1 carries the ✓). See the *Needs Director review* subsection below. Everything else here resolves
on merit and holds regardless of DR-2's disposition, *provided* the Director does not switch to
weight-on-`JunkItem` (which would re-scope the task).

### Q1 — Dictionary vs. typed pair-array → **RESOLVED: `Dictionary[StringName, float]`**

Adopt the typed `Dictionary` (DR-2). Rationale: it is minimal, honors the docstring, and adds no
`class_name`/`load_steps` weight. **Byte-identity of the resolved weights is independent of
representation** (both store the same `float` per id), so this is purely an authoring-diff-ergonomics
call — and the `Dictionary` wins it:

- **Diffability is a non-issue in practice.** Godot's `format=3` text serializer emits a resource-body
  `Dictionary` **multi-line, one entry per line** (exactly the shape shown in §b.2), so a weight tweak
  is a one-line diff. The pair-array sub-resource buys nothing over that while re-introducing "order
  in an array" and a second script.
- **Mandatory implementer step (do not skip):** during §b.2 regeneration, **edit in the Godot
  inspector, then capture the *exact* serialized form the 4.6 editor emits and commit *that* canonical
  form.** Two specifics to verify because they are engine-controlled: (1) inline `{…}` vs. multi-line —
  accept whichever the editor emits (an inline 8-entry map is still acceptable; edits are rare); (2)
  whether 4.6 stamps a **typed-dictionary annotation** into the `.tres` (typed dicts landed in 4.4).
- **Fresh-eyes fallback (technical, pre-authorized):** if the *typed* `Dictionary[StringName, float]`
  annotation proves to round-trip badly in the 4.6 `.tres` text format (e.g. an unreviewable or
  churny serialized prefix), fall back to an **untyped `@export var spawn_weights_by_id: Dictionary`**
  keyed by `StringName`→`float`. This is safe because the strengthened CI check (Q4) already asserts
  the key/value domain (every key is a real item id, values non-negative), so the type discipline is
  enforced at the gate rather than only by the annotation. The pair-array is the *last* resort, only
  if a plain `Dictionary` is somehow unreviewable. Byte-identity is unaffected in every case.

### Q2 — stable pick order → **RESOLVED: iterate `indices` (array order), never the map keys**

Keep `_weighted_pick` iterating `indices` (produced by `_eligible_indices` in **ascending catalog-array
order**) and look up each item's id in the map. **Never iterate `spawn_weights_by_id.keys()` in any
draw path.** This guarantees the `cum` table and the returned `indices[k]` mapping are built in a
fixed order independent of the `Dictionary`'s hash order, so `roll = randi_range(0, running-1)` and the
returned index are byte-identical to today.

- Note for the record: `running` (the integer sum) is *already* order-independent (integer addition
  commutes), so the RNG **range** never depended on iteration order — but the `cum`/`indices[k]`
  **return mapping** does, which is exactly why array-order iteration is load-bearing and map-key
  iteration is forbidden.
- **Include both belt-and-suspenders guards** the design proposes: (1) a one-line comment at the
  lookup — *"iterate `indices` (catalog-array order via `_eligible_indices`), never the map's keys —
  determinism"*; (2) a test assertion that two catalogs with **identical items+weights but different
  map insertion order** produce identical `plan_fingerprint`s. The second is the real proof the
  hash-order footgun is closed and belongs in the Q3 test file.

### Q3 — mid-list-insert regression test → **RESOLVED: include option (a), the dedicated logic-only test**

Include `tests/test_junk_catalog_by_id.gd` as specced in §b.5. This is **not a discretionary scope
add** — the breakdown's V1 Definition of Done explicitly requires *"inserting a test item mid-list does
not misalign (regression test)"*, so the test is contractually mandated and resolves to "include" on
merit. It is logic-only (in-memory `JunkCatalog`/`JunkItem`, self-quitting SCENE per the
`godot-headless-test-invocation` memory), cheap, and touches no layout stream. It pins two distinct
guarantees the other checks do not: the **resolution invariance** under a mid-list insert (unit test)
vs. the **authoring coverage** gate (CI check). Fold Q2's insertion-order-invariance assertion into
this same file. M1.12's "remove debt, don't add surface" ethos is not violated: a regression test that
pins the exact retired bug class is justified surface, not gold-plating.

### Q4 — strengthen the check AND wire it into CI → split resolution

**(a) Strengthen `check_junk_catalog.gd` to semantic assertions — RESOLVED: YES, mandatory in V1.**
This is not optional and not a scope call: once `spawn_weights` becomes a by-id map, the *old
size-only assertion is meaningless* (there are no longer two parallel arrays whose sizes could
mismatch). The check MUST become semantic or it validates nothing. Implement exactly the §b.4 trio —
**id-coverage** (every item id has a weight), **no-orphans** (every weight key is a real item id),
**non-negative** (mirrors `_weighted_pick`'s `maxf(.,0.0)` intent) — and keep the existing duplicate-id
walk (now doubly load-bearing, since a duplicate id also silently collides in the map — call that out
in a comment). Detection of the misalignment class goes from ~0% (size-only) to 100% (mapping-check).

**(b) Wire `check_junk_catalog.gd` into CI — RESOLVED technically; escalated as a small scope item.**
The technical part is settled: the correct wiring is a single step, placed **after the existing
`--import` step** (so `class_name JunkCatalog` resolves), of the form
`~/godot-bin/godot --headless --script res://tools/check_junk_catalog.gd` — the check is
`extends SceneTree` / `_initialize()` and is designed to run via `--script` (per its own header), not
as a scene. Steps run sequentially within the job, so the no-concurrent-headless constraint
(`godot-headless-test-invocation` memory) is not engaged. On today's green data the step passes, so
wiring is behavior-preserving.

- **Fresh-eyes correction to the design:** the doc names only `ci.yml`. For parity, add the same step
  to **`nightly.yml`'s `test` gate** as well (the nightly re-runs the CI gate before publishing; a
  validator that gates PRs but not the publish gate is half-wired). Both edits are one line each.
- **Why it's escalated (not self-resolved):** wiring a previously-dormant validator into CI (i) edits
  files **outside `Game/`** (`.github/workflows/*.yml`) and (ii) creates a **newly-gating merge check**
  — a scope/process call, not pure technical merit. See *Needs Director review* below. **Recommendation:
  include in V1** — it's the smallest possible surface, it's what makes the strengthened check real
  ("a validator that never runs buys nothing"), and it's squarely in V1's spirit. If the Director wants
  V1 to stay data-only, split the two-line CI wire-up into a trivial follow-up, but note the
  strengthened check is inert until then.

### Q5 — field rename vs. shim → **RESOLVED: clean rename `spawn_weights` → `spawn_weights_by_id`, no shim**

Confirmed on merit. The resolver's own repo grep confirms **only `junk_catalog.tres`** references the
old field (plus the code sites, all updated in the same commit) — no external `.tres` would silently
drop it. A retained legacy `spawn_weights` field would preserve exactly the index-aligned footgun this
task exists to delete, so a deprecation shim is a net negative. Low risk given the single authored
catalog.

### Additional fresh-eyes findings (fold into implementation — technical, no Director call)

1. **Null-item guard divergence is unreachable, keep it anyway.** In the new `_weighted_pick`, the
   `it.id if it != null else &""` guard would (for a null item) resolve to the `&""` key → `.get`
   default `1.0`, whereas the *old* code would have indexed `spawn_weights[idx]` for a real weight.
   This divergence is **unreachable** because `_eligible_indices` (`junk_placer.gd:158`) already filters
   `it != null` before any index reaches `_weighted_pick`, so the `indices` list never contains a
   null-item index. The guard is harmless belt-and-suspenders; keep it, but the byte-identity proof
   does **not** rest on it (it rests on the null-filter upstream). No action beyond a one-line comment.
2. **Regression floor is correctly identified.** The design's claim that junk placement does not feed
   any of the four control **layout** fingerprints is consistent with the code: junk draws from the
   `_JUNK_SALT` sub-stream and the layout fp is pre-junk. V1's own proof obligation is the **junk
   `plan_fingerprint`** (same seed → byte-identical plan) via the existing junk/placer/determinism
   suites, plus the new Q2 insertion-order-invariance assertion — not a layout-fp move. This matches
   the breakdown's "Regression floor" and needs no change.

### Needs Director review

Two items are **not** self-resolved; each carries a recommendation for the Director to disposition
(per orchestrator-loop step 7). Everything else above is resolved on technical merit.

- **DR-2 (design/vision) — weight representation.** By-**id** `Dictionary[StringName, float]` on
  `JunkCatalog` vs. the report's weight-on-`JunkItem` alternate. This is a design call (is rarity a
  spawn-context property or an item-identity property?), and DR-2 is still **un-ratified** in the
  breakdown. *Recommendation: RATIFY by-id on the catalog* — it honors the file's own docstring, keeps
  `JunkItem` identity clean, and makes a future second reweighting catalog trivial; the alternate
  contradicts the stated design and blocks that future catalog. The entire V1 design is authored on
  this rec; a switch to weight-on-`JunkItem` re-scopes the task.

- **Q4(b) (scope/process) — wire the dormant catalog check into CI.** Adding
  `check_junk_catalog.gd` to `ci.yml` **and** `nightly.yml`'s test gate edits files **outside `Game/`**
  and introduces a **newly-gating merge check**. *Recommendation: INCLUDE in V1* — two one-line steps,
  behavior-preserving on green data, and it's the step that makes the strengthened validator actually
  gate merges (otherwise Q4(a) strengthens inert code). Fallback if the Director wants V1 data-only:
  carve the CI wire-up into a trivial follow-up task, noting the strengthened check is dormant until
  it lands.
