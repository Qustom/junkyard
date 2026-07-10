# V6 / R7 — `RNG.substream(...)` helper — Phase-2 Design

> **Milestone:** M1.12 (Wave 2, ∥ V2) · **Assignee:** general-purpose · **BlockedBy:** none
> (Wave-1 **V1** migrates junk_placer's weighted *read* first — V6 sees the already-merged
> junk_placer and touches ONLY its sub-stream *derivation*, never its weight read).
>
> **The hard contract (from the breakdown, §Scope guardrails / Determinism):** every migrated
> sub-stream is **byte-identical** to its current derivation. All four control layout fingerprints
> — `e943ac9c8bc1` (all-off), `band_greybox`, `band_two`, `band_three` — stay byte-identical.
> **A fingerprint move is a BUG, not a deviation.** This task is a pure discoverability/DRY win with
> **zero behavioral change**.

---

## (a) Research on the premise

### Why this task

The `RNG` autoload (`Game/systems/rng.gd`) is the single seeded RNG service (TDD §2). But five
production sites deliberately **do NOT** use it: they hand-roll a *local* `RandomNumberGenerator`
seeded from a base seed + a fixed salt, precisely so their rolls never perturb (and are never
perturbed by) the global layout/placement stream that `fingerprint()` pins. That pattern is correct
and load-bearing — but it is currently **copy-pasted in two different idioms across five files**,
and the boost-style hash-combine at its core is written out **verbatim twice**. V6 promotes the
idiom into one discoverable `RNG.substream*` call so there is *one way* to derive a
determinism-preserving sub-stream, without moving a single byte.

### What exists today — `rng.gd` in full

`Game/systems/rng.gd` (36 lines) exposes only `seed_from(value)`, `randi/randi_range/randf/
randf_range/pick`. Its own generator is seeded by **both** `.seed` and `.state`:

```gdscript
# rng.gd:15-18
func seed_from(value: int) -> void:
    seed_value = value
    _rng.seed = value
    _rng.state = value  # reset state too, so the same seed → the same sequence
```

There is **no** `fork()` / `substream()` / `stream()` today — which is exactly why every site
below hand-rolls one. `RNG.substream*` is a new, additive surface; nothing about the existing five
methods changes.

### The five hand-rolled sub-stream sites (verified in-repo 2026-07-10)

`grep -rn "RandomNumberGenerator.new()" Game/ --include=*.gd` returns seven hits. Two are **not**
salted sub-streams and are out of scope: `rng.gd:9` (the autoload's own `_rng`) and
`tests/helpers/test_seeds.gd:35` (a **test-only** factory, no salt — see "Out of scope" below). The
remaining **five are the migration targets**:

#### Site 1 — Pockets random-drop shuffle · `systems/game_state.gd:650-651`
```gdscript
# match run_rules.pockets_policy == RunRules.PocketsPolicy.RANDOM:
var rng := RandomNumberGenerator.new()
rng.seed = run_seed ^ POCKETS_RNG_SALT        # ← .seed ONLY, no .state
# … Fisher–Yates over the inventory copy using rng.randi_range(0, i)
```
- **Base seed:** `run_seed` (GameState field, set at `start_run` :145). Salt: `POCKETS_RNG_SALT =
  0x50434B54` ("PCKT", declared `game_state.gd:16`).
- **Seed math:** `run_seed ^ POCKETS_RNG_SALT` (**XOR**).
- **State protocol:** sets **`.seed` only** — does NOT set `.state`.
- **Consumed by:** Fisher–Yates shuffle (`rng.randi_range`).

#### Site 2 — Exit-gate placement shuffle · `scenes/game/main_game.gd:1178-1179`
```gdscript
var rng := RandomNumberGenerator.new()
rng.seed = GameState.run_seed ^ GameState.EXITS_RNG_SALT   # ← .seed ONLY, no .state
# … Fisher–Yates over the candidate-cell pool copy using rng.randi_range(0, i)
```
- **Base seed:** `GameState.run_seed`. Salt: `EXITS_RNG_SALT = 0x45584954` ("EXIT", declared
  `game_state.gd:22`).
- **Seed math:** `run_seed ^ EXITS_RNG_SALT` (**XOR**).
- **State protocol:** sets **`.seed` only** — does NOT set `.state`.
- **Consumed by:** Fisher–Yates shuffle (`rng.randi_range`).

#### Site 3 — Junk placement plan · `systems/depth/junk_placer.gd:57-59`
```gdscript
var rng := RandomNumberGenerator.new()
rng.seed = _substream_seed(band.resolved_seed)   # hash_combine(resolved_seed, _JUNK_SALT)
rng.state = rng.seed                              # ← .seed AND .state
```
with (`junk_placer.gd:139-143`):
```gdscript
func _substream_seed(band_seed: int) -> int:
    var h := band_seed
    var mixed := (_JUNK_SALT + 0x9E3779B9 + ((h << 6) & 0x7FFFFFFFFFFFFFFF) + (h >> 2))
    h = (h ^ mixed) & 0x7FFFFFFFFFFFFFFF
    return h
```
- **Base seed:** `band.resolved_seed` (**NOT** `run_seed`/`RNG.seed_value` — see the trap below).
  Salt: `_JUNK_SALT = 0x4A554E4B` ("JUNK", declared `junk_placer.gd:26`).
- **Seed math:** a **single** boost hash-combine `mix(band_seed, _JUNK_SALT)`.
- **State protocol:** sets **`.seed` AND `.state = rng.seed`**.
- **Consumed by:** `_seeded_round`, `_weighted_pick` (V1's by-id read), `rng.randi_range` (cell pick).

#### Sites 4 & 5 — Flavor stages · `systems/bandgen/stages/{wear_decay,set_piece_inject}.gd`
The seed is computed **upstream** in the pipeline and passed *in* as an int:
```gdscript
# band_pipeline.gd:130 — the driver
stage.apply(band, profile, _stage_seed(band.resolved_seed, _stage_salt(fcfg), i))

# band_pipeline.gd:174-182 — the derivation (a DOUBLE mix)
static func _stage_seed(resolved_seed: int, salt: int, index: int) -> int:
    var h := _mix(resolved_seed, salt)
    return _mix(h, index)
static func _mix(h: int, v: int) -> int:
    var mixed := (v + 0x9E3779B9 + ((h << 6) & 0x7FFFFFFFFFFFFFFF) + (h >> 2))
    return (h ^ mixed) & 0x7FFFFFFFFFFFFFFF
```
Each stage then builds its local rng identically (`wear_decay.gd:58-60`, `set_piece_inject.gd:49-51`):
```gdscript
var rng := RandomNumberGenerator.new()
rng.seed = stage_seed
rng.state = rng.seed                              # ← .seed AND .state
```
- **Base seed:** `band.resolved_seed`. Salt: **data-driven** — `SetPieceInjectConfig.salt` /
  `WearDecayConfig.salt` (authored on the config `.tres`, read via `_stage_salt`, `band_pipeline.gd:162-167`).
  Index: `i` = the flavors-array index (disambiguates two instances of the same stage).
- **Seed math:** a **double** boost hash-combine `mix(mix(resolved_seed, salt), index)`.
- **State protocol:** sets **`.seed` AND `.state = rng.seed`**.

### The two idioms — mapping table

| # | Site (file:line) | Base seed | Salt (source) | Seed math | State protocol | Consumed |
|---|---|---|---|---|---|---|
| 1 | `game_state.gd:650` (pockets) | `run_seed` | `POCKETS_RNG_SALT` (code const :16) | `base ^ salt` | **`.seed` only** | Fisher–Yates |
| 2 | `main_game.gd:1178` (exits) | `run_seed` | `EXITS_RNG_SALT` (code const :22) | `base ^ salt` | **`.seed` only** | Fisher–Yates |
| 3 | `junk_placer.gd:57` (junk) | `band.resolved_seed` | `_JUNK_SALT` (code const :26) | `mix(base, salt)` (single) | **`.seed` + `.state`** | rounds/weighted/cell |
| 4 | `wear_decay.gd:58` (flavor) | `band.resolved_seed` | `WearDecayConfig.salt` (**data**) | `mix(mix(base, salt), index)` (double) | **`.seed` + `.state`** | decay rolls |
| 5 | `set_piece_inject.gd:49` (flavor) | `band.resolved_seed` | `SetPieceInjectConfig.salt` (**data**) | `mix(mix(base, salt), index)` (double) | **`.seed` + `.state`** | injection rolls |

### THREE load-bearing findings that constrain the helper

**Finding A — the idioms differ on TWO independent axes, not one.** The breakdown names the axis
"XOR vs hash_combine" (seed math). Reading the code reveals a **second, equally byte-affecting
axis: the seed/state protocol.** The XOR sites set **`.seed` only**; the hash_combine sites set
**`.seed` AND `.state = seed`**. In Godot 4 these produce **different streams**: the `.seed` setter
initialises the PCG state via `pcg32_srandom` (state = a hash of the seed), whereas assigning
`.state = seed` forces the raw seed as the PCG state. Setting `.seed` alone ≠ setting `.seed` then
`.state = seed`. **The helper must reproduce each site's exact protocol verbatim** — normalising all
five to one protocol would move the pockets/exits streams (a fingerprint bug). (Whether the two
protocols *always* differ is immaterial to the design: we preserve each verbatim, so we are safe
either way — but they are believed to differ, which is precisely why one canonical form cannot
serve all five. This is the core answer to breakdown OQ8, below.)

**Finding B — the boost hash-combine is duplicated verbatim in TWO files, and the two hash sites use
DIFFERENT depths.** `junk_placer._substream_seed` is exactly `band_pipeline._mix(band_seed,
_JUNK_SALT)` — the identical `v + 0x9E3779B9 + ((h<<6)&MASK) + (h>>2)` expression, written out
twice (`junk_placer.gd:141` and `band_pipeline.gd:181`). But **junk applies a SINGLE mix** (salt
only, no index) while **the flavor stages apply a DOUBLE mix** (salt then index). So the hashed form
of the helper must support *both* "salt only" and "salt + index". Collapsing the two verbatim mix
copies into one definition is the concrete duplication the ledger claims.

**Finding C — the base seed is NOT always `RNG.seed_value`; it must be passed explicitly.** For
pockets/exits the base is `run_seed`; for junk/stages it is `band.resolved_seed`. Critically,
`run_seed != RNG.seed_value` at pockets/exits time: `BandGenerator.generate()` reseeds the global
autoload internally (`RNG.seed_from(seed)` per attempt — documented in
`tests/helpers/test_seeds.gd:14-19`), and `band.resolved_seed` is the pipeline's own per-band seed,
also generally `!= RNG.seed_value`. **Therefore the helper must take `base` as an explicit
parameter** — a convenience form that reads `RNG.seed_value` would silently derive the wrong stream.
This is the single most dangerous trap in V6; the design closes it by never defaulting `base`.

---

## (b) Pseudocode — the helper surface + per-site migration

### The API (two forms — required by Finding A; see OQ8 resolution)

Added to `Game/systems/rng.gd`. Both return a **fully configured** `RandomNumberGenerator` (the
caller just draws from it), collapsing the 3-line build block at every site to a 1-line call.

```gdscript
# --- Deterministic salted sub-streams (V6 / R7) ------------------------------
## Derive a LOCAL RandomNumberGenerator whose stream is a determinism-preserving
## sub-stream of `base`, salted by `salt`. Never touches the global autoload
## generator, so sub-stream rolls neither perturb nor are perturbed by the layout
## stream that fingerprint() pins. THE way to roll salted, reproducible randomness
## off a known base seed without desyncing generation.
##
## `base` is ALWAYS explicit — it is run_seed for pockets/exits and
## band.resolved_seed for placement/flavor, and is generally NOT RNG.seed_value
## (the generator reseeds the autoload mid-run). Never default it.

## XOR form — reproduces pockets & exits BYTE-IDENTICALLY.
## Seed math: base ^ salt.  Protocol: sets .seed ONLY (matches the two XOR sites,
## which never set .state — see V6 design Finding A).
func substream(base: int, salt: int) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = base ^ salt          # .seed only — do NOT set .state here
    return rng

## Boost hash-combine form — reproduces junk (index omitted) & flavor stages
## (index given) BYTE-IDENTICALLY.
## Seed math: index < 0 → mix(base, salt);  index >= 0 → mix(mix(base, salt), index).
## Protocol: sets .seed AND .state (matches junk_placer & both stages).
## Real indices are array indices (>= 0); -1 is the safe "no index mix" sentinel.
func substream_hashed(base: int, salt: int, index: int = -1) -> RandomNumberGenerator:
    var h := _mix(base, salt)
    if index >= 0:
        h = _mix(h, index)
    var rng := RandomNumberGenerator.new()
    rng.seed = h
    rng.state = h                   # .seed AND .state — matches the three hash sites
    return rng

## The boost-style 64-bit hash-combine (formerly duplicated verbatim in
## junk_placer._substream_seed and band_pipeline._mix — Finding B). ONE definition now.
func _mix(h: int, v: int) -> int:
    var mixed := (v + 0x9E3779B9 + ((h << 6) & 0x7FFFFFFFFFFFFFFF) + (h >> 2))
    return (h ^ mixed) & 0x7FFFFFFFFFFFFFFF
```

**Why byte-identity holds by construction:**
- `substream(base, salt)` = `rng.seed = base ^ salt` with no `.state` — *character-for-character*
  what pockets and exits do.
- `substream_hashed(base, salt)` (index defaulted `-1` → skip) = `mix(base, salt)` then `.seed`+
  `.state` — *character-for-character* junk_placer's `_substream_seed` + its 57-59 build.
- `substream_hashed(base, salt, i)` (`i >= 0`) = `mix(mix(base, salt), i)` then `.seed`+`.state` —
  *character-for-character* `_stage_seed` + the stages' build.
- `_mix` is a byte-for-byte transcription of the existing expression (same `0x9E3779B9`, same
  `<<6`/`>>2`, same `0x7FFFFFFFFFFFFFFF` masks). No numeric change.

### Migration — Site 1 (pockets, `game_state.gd:650-651`)
```gdscript
# BEFORE
var rng := RandomNumberGenerator.new()
rng.seed = run_seed ^ POCKETS_RNG_SALT
# AFTER
var rng := RNG.substream(run_seed, POCKETS_RNG_SALT)
```
`POCKETS_RNG_SALT` const stays on `game_state.gd`. Stream identical: `.seed = run_seed ^ salt`,
no `.state`. ✔

### Migration — Site 2 (exits, `main_game.gd:1178-1179`)
```gdscript
# AFTER
var rng := RNG.substream(GameState.run_seed, GameState.EXITS_RNG_SALT)
```
`EXITS_RNG_SALT` const stays on `game_state.gd`. Stream identical. ✔

### Migration — Site 3 (junk, `junk_placer.gd:57-59`)
```gdscript
# AFTER
var rng := RNG.substream_hashed(band.resolved_seed, _JUNK_SALT)   # index omitted → single mix
```
Delete `_substream_seed` (`junk_placer.gd:139-143`). `_JUNK_SALT` const stays on `junk_placer.gd`.
Stream identical: `mix(resolved_seed, _JUNK_SALT)`, `.seed`+`.state`. **V1 already merged the weight
read (`_weighted_pick` now by-id) — V6 does not touch it; only lines 57-59 + `_substream_seed`
move.** ✔

### Migration — Sites 4 & 5 (flavor stages) — recommended seam: pass the configured rng
The pipeline currently computes an int and each stage rebuilds an rng from it. The bigger debt win
is to have the pipeline build the rng via the helper and hand it to `apply()`, deleting the
duplicated build block from **both** stages:
```gdscript
# band_pipeline.gd:130  BEFORE
stage.apply(band, profile, _stage_seed(band.resolved_seed, _stage_salt(fcfg), i))
# band_pipeline.gd:130  AFTER
stage.apply(band, profile, RNG.substream_hashed(band.resolved_seed, _stage_salt(fcfg), i))

# BandFlavorStage.apply signature:  (band, profile, stage_seed: int)
#                            →       (band, profile, rng: RandomNumberGenerator)

# wear_decay.gd / set_piece_inject.gd  BEFORE
func apply(band, _profile, stage_seed: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = stage_seed
    rng.state = rng.seed
    ...
# AFTER
func apply(band, _profile, rng: RandomNumberGenerator) -> void:
    ...   # rng arrives fully configured; the 3-line build block is gone
```
Delete `_stage_seed` and `_mix` from `band_pipeline.gd:174-182` (the second verbatim copy of the
mix — Finding B). Stage salts stay **data-driven** on their config `.tres` (untouched). Stream
identical: `mix(mix(resolved_seed, salt), i)`, `.seed`+`.state`. ✔

> **Minimal-seam fallback** (if changing `apply()`'s signature is judged too invasive at Phase 3):
> keep the int seam and add `RNG.substream_hashed_seed(base, salt, index) -> int` returning just the
> derived int; the pipeline calls it and the stages keep their local build. This removes the
> duplicated *math* but keeps the stages' 3-line build (less DRY). Recommended only if the signature
> change reddens the `BandFlavorStage` interface contract. See OQ.

### Out of scope (documented, not migrated)
- `rng.gd:9` `_rng` — the autoload's own generator, not a sub-stream.
- `tests/helpers/test_seeds.gd:35` `make_rng(seed)` — a **test-only** factory, **no salt**
  (`.seed`+`.state=seed`, generic). Not a production determinism sub-stream. Could optionally be
  re-expressed later, but it takes no salt and is not a `substream` shape; leaving it avoids coupling
  test infra to the new API. Noted, not touched.

---

## (c) Open Questions

**OQ1 — One canonical form vs two (breakdown OQ8). → RESOLVE ON MERIT: two forms are REQUIRED.**
Byte-identity forbids a single `substream(salt)`: the five sites differ on *two* byte-affecting axes
(seed math XOR vs hash-combine **and** state protocol `.seed`-only vs `.seed`+`.state` — Finding A),
and the two hash sites further differ in mix depth (single vs double). Any single canonical form
picks one derivation and thereby moves the other sites' streams = a fingerprint bug. The design ships
**`substream` (XOR / `.seed`-only)** + **`substream_hashed` (hash-combine / `.seed`+`.state`, optional
`index`)** — two forms, each byte-identical to its sites. *Recommendation: two forms as specified.*
(A future, **separately sanctioned**, fingerprint-moving task could unify everything onto one canonical
derivation — but that is explicitly out of V6's zero-behavior-change scope.)

**OQ2 — Should the code-const salts (`POCKETS`/`EXITS`/`JUNK`) be relocated into `RNG`?**
They could be centralised as an `RNG` salt namespace. *Recommendation: NO — leave each salt at its
subsystem site.* The helper is salt-agnostic (salt is a parameter); centralising would couple `RNG`
to gameplay concepts (pockets, exits, junk) and, for the flavor stages, is impossible anyway — those
salts are **data-driven** on the config `.tres` (`SetPieceInjectConfig.salt` / `WearDecayConfig.salt`),
not code constants. Keeping salts in place also makes byte-identity trivially auditable (the value
`0x50434B54` etc. never moves). No numeric change either way; this is a placement-cleanliness call
only. *Resolve on merit; rec: leave in place.*

**OQ3 — Flavor-stage seam: pass the configured rng (change `apply()` signature) vs keep the int seam
(add `substream_hashed_seed(...) -> int`).** Passing the rng deletes the duplicated 3-line build from
**both** stages (bigger debt win) but changes the `BandFlavorStage.apply(band, profile, …)` contract
across the interface + both impls + the pipeline call. *Recommendation: pass the configured rng* —
it is the greater duplication collapse, byte-identical, and all three touch points are in one
subsystem V6 already edits. Fallback (int seam) documented above if Phase 3 rules the signature
change out of scope. *Resolve on merit; rec: rng seam.*

**OQ4 — How is each site's byte-identity PROVEN?** Two complementary layers, recommended together:
1. **Per-site golden equivalence test (the rigorous proof).** *Before* deleting the old code,
   capture the first *K* draws (`randi()` / `randi_range(0, N)`) from each old inline idiom for a
   fixed `(base, salt[, index])` and hard-code them as goldens; assert the new helper reproduces
   them exactly. One `test_rng_substream.gd` covering all five derivations
   (XOR/`.seed`-only ×1, single-mix/`.seed`+`.state` ×1, double-mix/`.seed`+`.state` ×1 — plus a
   guard that `substream` and `substream_hashed` for the same `(base, salt)` **differ**, pinning
   Finding A). This proves the helper *in isolation*, independent of whether any fingerprint happens
   to exercise the path.
2. **Existing fingerprints (the integration proof).** Junk → junk plan fingerprint
   (`junk_placer.plan_fingerprint`); exits → `test_exit_placement` / `test_exit_placement_count`;
   flavor stages → the `band_two`/`band_three` control layout fps (whichever exercise flavor
   profiles); pockets → any pockets-policy determinism test. All four control layout fps must stay
   byte-identical post-merge.
   *Question for Phase 3:* is there a dedicated **pockets-RANDOM** determinism test today, or does
   only the golden layer cover pockets? If none, the per-site golden (layer 1) is the sole guard for
   pockets and MUST be added. *Recommendation: require layer 1 (golden) for all five, treat layer 2
   as corroboration; flag pockets specifically for a dedicated assertion.*

**OQ5 — Do `.seed`-only and `.seed`+`.state=seed` actually diverge in this Godot build (VERIFY item)?**
The design does not *depend* on the answer — it preserves each site's protocol verbatim, so it is
safe whether they diverge or not. But the answer determines whether OQ1's "two forms required"
rests on a real difference. *Recommendation: the golden test in OQ4 (which asserts `substream` ≠
`substream_hashed` for a shared `(base, salt)`) empirically settles it and pins it as a regression
guard.* No Director judgment needed — pure technical verification, handled by the test.

*No vision / fun / tone / scope / date calls surfaced by V6. Every open question resolves on
technical merit; none needs Director review.*

---

## Expected debt ledger (V6)

**Headline: 5 hand-rolled sub-stream sites + 2 idioms → 1 discoverable helper surface (2 forms);
the boost hash-combine, formerly written verbatim in 2 files, is defined ONCE.**

| Debt retired | Before | After |
|---|---|---|
| Sub-stream **call sites** | 5 (pockets, exits, junk, wear_decay, set_piece_inject), 2 idioms | 5 one-line `RNG.substream*` calls, 1 surface |
| Boost hash-combine `_mix` **copies** | 2 verbatim (`junk_placer._substream_seed`, `band_pipeline._mix`) | 1 (`RNG._mix`) |
| rng-construction **3-line build block** | ×5 (two protocol variants) | collapsed to 1-line calls |
| Deleted helpers | `junk_placer._substream_seed`, `band_pipeline._stage_seed` + `_mix` | — |
| Deleted per-stage build | 3-line block ×2 (wear_decay, set_piece_inject) | — (rng passed in) |

**Net LOC:** roughly **neutral to slightly negative** — the helper adds ~18 lines to `rng.gd`
(`substream` + `substream_hashed` + `_mix` + docs) but deletes `_substream_seed` (~6),
`_stage_seed`+`_mix` (~10), and two stage build blocks (~6) plus shrinks five call sites from 2-3
lines to 1. **The win is not raw LOC** — it is: (1) **discoverability** — one documented
`RNG.substream*` is now THE way to derive determinism-preserving randomness (the breakdown's DoD
"the helper is documented as THE way"); (2) **duplication collapse** — the boost hash goes from two
verbatim copies to one; (3) **one-way-to-do-it** — no future contributor re-hand-rolls a sixth
variant. **Determinism unchanged: all four control fps byte-identical; a fingerprint move is a bug.**

---

## Resolved Decisions (Phase 3)

> **Fresh-eyes resolver, 2026-07-10.** I did **not** author this design. I independently
> re-read all five migration sites in-repo, re-derived the byte-identity argument, and
> **empirically verified** the central technical claim in a headless Godot 4.6.3 run. All open
> questions resolve on technical merit; **no Director-level (vision/fun/tone/scope/date) call is
> present** — the author's expectation is confirmed. Byte-identity is preserved at every site by
> construction; the two additions below (OQ3 test re-point, OQ4 pockets golden) are the only
> not-yet-stated obligations the migration carries, and both are byte-safe.

### Verification performed (primary sources, not the design's prose)

- **All five sites re-read and confirmed exactly as the design's mapping table states:**
  pockets `game_state.gd:650-651` (`rng.seed = run_seed ^ POCKETS_RNG_SALT`, **`.seed` only**);
  exits `main_game.gd:1178-1179` (`rng.seed = GameState.run_seed ^ GameState.EXITS_RNG_SALT`,
  **`.seed` only**); junk `junk_placer.gd:57-59` + `_substream_seed:139-143` (**`.seed`+`.state`**,
  single `_mix`); flavor stages `wear_decay.gd:58-60` / `set_piece_inject.gd:49-51` fed by
  `band_pipeline._stage_seed:174-176` = `_mix(_mix(seed,salt),index)` (**`.seed`+`.state`**, double
  `_mix`). The salt consts (`POCKETS_RNG_SALT` :16, `EXITS_RNG_SALT` :22, `_JUNK_SALT` :26) and the
  data-driven stage salts (`_stage_salt` :162-167) are all where the design says.
- **`_substream_seed(band_seed)` IS `_mix(band_seed, _JUNK_SALT)` — checked term-by-term.**
  `_substream_seed`: `mixed = _JUNK_SALT + 0x9E3779B9 + ((h<<6)&MASK) + (h>>2); return (h^mixed)&MASK`
  with `h=band_seed`. `_mix(h,v)`: `mixed = v + 0x9E3779B9 + ((h<<6)&MASK) + (h>>2); return (h^mixed)&MASK`.
  Substituting `h=band_seed, v=_JUNK_SALT` yields the identical expression. Finding B confirmed:
  `junk_placer._substream_seed` and `band_pipeline._mix` are the same boost-mix written twice.
- **The two-axis claim (Finding A) is REAL, and I verified the state axis empirically.** Ran a
  standalone Godot 4.6.3 headless script: for the same seed `h`, `.seed`-only vs `.seed`+`.state=h`
  gave **different** first-5 `randi()` sequences (`DIFFER: true`). The `.seed`-only run left
  `rng.state = -2269738147549299013` (a scrambled hash of `h`, via `pcg32_srandom`), whereas forcing
  `.state = h` makes the first draw tiny (`9`), i.e. the raw seed is loaded as PCG state. **So the
  two protocols genuinely produce different streams in this exact build** — a single canonical form
  cannot serve both the XOR/`.seed`-only sites and the hash/`.seed`+`.state` sites without moving a
  fingerprint. The design does not *depend* on this (it preserves each verbatim), but it is now
  empirically settled, and OQ5's proposed regression guard (assert `substream(b,s) !=
  substream_hashed(b,s)`) is warranted and will hold.

### OQ1 (breakdown OQ8) — one canonical form vs two → **RESOLVED: TWO forms, as the design specifies.**
Confirmed on merit and by the verification above. The five sites differ on **two independent
byte-affecting axes** (seed math XOR vs boost-mix; state protocol `.seed`-only vs `.seed`+`.state`)
*and* the two hash sites differ in mix depth (single vs double via the optional `index`). Any single
`substream(salt)` would pick one derivation and move the others' streams = a fingerprint bug, which
the master contract forbids. Ship **`substream(base, salt)`** (XOR, `.seed`-only) +
**`substream_hashed(base, salt, index := -1)`** (boost-mix, `.seed`+`.state`, `index >= 0` adds the
second mix). The `-1` sentinel is safe: every real `index` is an array index `>= 0`
(`for i in profile.flavors.size()`), so junk (index omitted) can never collide with a legitimate
index. **No Director review.** (A future, separately-sanctioned, fingerprint-moving task could
unify onto one derivation — explicitly out of V6 scope.)

### OQ2 — relocate the code-const salts into `RNG`? → **RESOLVED: NO. Leave each salt at its site.**
On merit: (1) the flavor-stage salts are **data-driven** on `SetPieceInjectConfig.salt` /
`WearDecayConfig.salt` (read via `_stage_salt`), so they *cannot* be centralised into `RNG` code
constants anyway — a partial centralisation (only the three code consts) would be *less* consistent,
not more. (2) The helper is deliberately **salt-agnostic** (salt is a parameter); pulling
`POCKETS`/`EXITS`/`JUNK` into `RNG` would couple the generic RNG service to gameplay concepts.
(3) `EXITS_RNG_SALT` is already referenced cross-file as `GameState.EXITS_RNG_SALT`
(`main_game.gd`, `test_exit_placement*.gd`); moving it would ripple those readers for zero
determinism benefit. Keeping the literals (`0x50434B54`, `0x45584954`, `0x4A554E4B`) exactly where
they are also keeps byte-identity trivially auditable. Placement-only call, zero numeric change.
**No Director review.**

### OQ3 — flavor-stage seam: pass the configured `rng` vs keep the int seam → **RESOLVED: pass the configured `rng` (change `apply()`'s signature).**
Recommended by the design and confirmed on merit: it deletes the duplicated 3-line build from **both**
stages *and* `band_pipeline._stage_seed`+`_mix`, the larger duplication collapse, and every touch
point is inside the bandgen subsystem V6 already edits. **However, the design under-counted the touch
set.** The full, verified touch set is **FIVE** points, not four:
1. `systems/bandgen/stages/band_flavor_stage.gd:40` — the base `apply(_band, _profile, _stage_seed: int)` signature.
2. `systems/bandgen/stages/wear_decay.gd:53` — impl signature + delete its `:58-60` build block.
3. `systems/bandgen/stages/set_piece_inject.gd:43` — impl signature + delete its `:49-51` build block.
4. `systems/bandgen/band_pipeline.gd:130` — the driver call → `RNG.substream_hashed(band.resolved_seed, _stage_salt(fcfg), i)`; then delete `_stage_seed`+`_mix` (`:174-182`) and update the `:18` doc-comment.
5. **`tests/test_band_flavors.gd:346-347`** — calls `stage.apply(direct, control_profile, BandPipeline._stage_seed(direct.resolved_seed, 0x57454152, 0))` **directly**. `_stage_seed` is deleted, so this line **must be re-pointed** to
   `stage.apply(direct, control_profile, RNG.substream_hashed(direct.resolved_seed, 0x57454152, 0))`.
   This is **byte-identical** (`RNG.substream_hashed` with `index=0` = `_mix(_mix(seed, salt), 0)`
   then `.seed`+`.state`, exactly `_stage_seed` + the stage build), so the test's assertions stay
   valid — it doubles as a live equivalence check of the flavor derivation.

   **This test touch is NOT a differentiator between the two OQ3 options** — the minimal-seam fallback
   *also* deletes `band_pipeline._stage_seed` (replacing the math with `RNG.substream_hashed_seed`),
   so `test_band_flavors.gd:347` breaks and must be re-pointed either way. The signature-change
   recommendation therefore stands purely on its DRY merit. The int-seam fallback
   (`RNG.substream_hashed_seed(base, salt, index) -> int`) is **not** adopted; keep it documented only
   as the escape hatch if integration reveals a hidden non-test caller of `apply(…, int)` — grep found
   none beyond the driver and this one test. **No Director review** (the `BandFlavorStage` interface is
   internal to bandgen; no cross-milestone contract crosses it).

### OQ4 — how is each site's byte-identity proven? → **RESOLVED: per-site golden (layer 1) is MANDATORY for all five; existing fps (layer 2) are corroboration. The pockets golden is REQUIRED — no other test covers it.**
Verified: **there is no dedicated pockets-RANDOM determinism test today** (grep for
`PocketsPolicy.RANDOM` / `POCKETS_RNG_SALT` across `tests/` returns nothing). So for the pockets
XOR/`.seed`-only derivation the **golden is the sole guard** and MUST be added. The other four sites
have integration cover — exits: `test_exit_placement.gd` + `test_exit_placement_count.gd` (both use
`GameState.EXITS_RNG_SALT`); junk: `test_band_depth.gd` + `procgen/test_layout_determinism.gd`
(junk plan fp); flavor: `test_band_flavors.gd` (direct `apply` + `band_two`/`band_three` layout fps)
— but the golden proves each derivation **in isolation**, independent of whether a fingerprint
happens to exercise that path. **Binding test plan for `tests/test_rng_substream.gd`:**
- **Capture-before-migrate.** BEFORE deleting any old inline code, capture the first *K* draws
  (`K >= 8`; `randi()` and the `randi_range(0, N)` the site actually uses) from each old idiom for a
  fixed `(base, salt[, index])`, hard-code them as goldens.
- **Assert after.** The new helper reproduces each golden byte-for-byte: `substream` (XOR/`.seed`-only)
  ×1; `substream_hashed` single-mix/`.seed`+`.state` ×1; `substream_hashed` double-mix/`.seed`+`.state`
  ×1. Plus the **cross-guard** (OQ5): for one shared `(base, salt)`, assert
  `substream(b,s).randi() != substream_hashed(b,s).randi()` — pins Finding A as a regression fence.
- **Pockets specifically:** a dedicated golden over the exact `run_seed ^ POCKETS_RNG_SALT`,
  `.seed`-only, `randi_range(0, i)` Fisher–Yates draw sequence — the only guard pockets gets.

Run as a **scene** test (`--headless <tscn>`), per the repo's headless-test convention. **No Director review.**

### OQ5 — do `.seed`-only and `.seed`+`.state=seed` diverge in this Godot build? → **RESOLVED: YES, empirically confirmed (see "Verification performed" above).** The design is safe regardless (each protocol preserved verbatim), and the OQ4 cross-guard test pins the divergence as a permanent regression fence. **No Director review** — pure technical verification, now done.

### Cross-task coordination (confirmed correct)

- **V6 → V4 (Wave 2 → Wave 3, both touch `game_state.gd`).** V6 replaces the pockets 3-line inline
  block (`game_state.gd:650-651`) with a single `RNG.substream(run_seed, POCKETS_RNG_SALT)` and
  **leaves `POCKETS_RNG_SALT`/`EXITS_RNG_SALT` consts in place** (OQ2). A one-line helper call +
  in-place consts is *more* portable than the block it replaces, so when V4 splits the pockets logic
  into the `Economy` sub-object it carries the call **verbatim**; V4 keeps the consts accessible on
  the preserved `GameState` facade (needed anyway: `EXITS_RNG_SALT` is read as
  `GameState.EXITS_RNG_SALT` by `main_game.gd` + the exit tests). V6 introduces **no** new
  cross-object seam for V4 to untangle. Coordination clean.
- **V6 ↔ V1 (Wave 2 after Wave 1, both touch `junk_placer.gd`).** V1 migrates the weighted *read*
  (`_weighted_pick` → by-id). V6 touches **only** the sub-stream *derivation* (`:57-59` +
  `_substream_seed`), never the weight read. Confirmed disjoint — V6 sees V1's already-merged by-id
  read and does not perturb it.

### Binding summary for the builder

Ship exactly the two-form surface (`substream` XOR/`.seed`-only; `substream_hashed` boost-mix/
`.seed`+`.state` with optional `index`) + one `RNG._mix`. Migrate all five sites verbatim-equivalent.
**Delete** `junk_placer._substream_seed`, `band_pipeline._stage_seed`+`_mix`, and the two stage build
blocks (adopt the rng-seam, OQ3). **Re-point** `test_band_flavors.gd:346-347` to
`RNG.substream_hashed(...)` (byte-identical). **Add** `tests/test_rng_substream.gd` with per-site
goldens (mandatory pockets golden + the Finding-A cross-guard). Leave all salt consts in place (OQ2).
**Every fingerprint stays byte-identical; a fingerprint move is a bug, not a deviation.** No item
requires Director review.
