# U3 — New Band: `band_four.tres` (scatter profile + deck + tint + identity) — Expanded Design Spec

**Milestone:** M1.11 (Third-Gen Backend + Open-Field Band + Ranged Oppositions) · **Workstream:** the N=3 scalability *measurement* itself · **Wave:** 3
**Task id:** U3 · **BlockedBy:** U0 (ScatterBackend + `ScatterBandConfig` + pipeline dispatch), U1 (scatter materialisation ride-through), U2a (`lobber.tres` + MortarCycle), U2b (`sentry.tres` + LaneWatch)
**Assignees:** game-director-designer (profile / deck / curve / pitches — this spec) · environment-artist (palette-tint direction) · general-purpose (glue-if-any + contract test)
**Author:** game-director-designer · **Status:** spec (Phase-2 per-task design; `## Open Questions` in §7 for Phase-3 fresh-eyes + Director)

> **What this doc is.** Per CLAUDE.md's four-phase authoring, this is U3's Phase-2 design: the premise research against the real as-built (§2), the buildable data spec (§3), the field-by-field data + test sketch (§4), and the explicit `Open Questions` (§7). It ships **no game code** — the `band_four.tres` value table here is authored as the actual `.tres` during U3's build; the contract test is a near-verbatim clone of the shipped `test_band_three_profile.gd`. **U3 is the headline N=3 scalability measurement of M1.11:** its worklog carries the *marginal* cost ledger — how much bespoke (non-data, non-test) code adding band 4 actually needs, given U0/U1/U2a/U2b landed. Band 2 cost **1 glue line**; band 3 cost **0**. The engineered answer this spec targets is **again zero production-code lines** (§5.2) — pure data (3 `.tres`) + one mirrored test — which, if it holds, is the evidence UG3 judges the "content = data now compounds" claim on for a *third, third-generation* backend.

---

## 0. Hard constraints (read first — straight from the M1.11 breakdown)

The spec must not violate these, and neither may the `.tres` authored from it:

- **FOUR permanent controls stay byte-identical.** Authoring `band_four` must not edit `band_greybox.tres`, `band_two.tres`, `band_three.tres`, their `bandgen_config*`/`cave_config*`/`depth_curve*` resources/tilesets, or any shipped `OppositionDef` default. The all-off `RunConfig` fingerprint **`e943ac9c8bc1`**, `band_greybox`'s fingerprint, `band_two`'s fingerprint (untouched socket path), and — new this version — **`band_three`'s fingerprint** (M1.10's shipped cave band is now itself a permanent control, absolute golden fp pins per the T3 precedent) are all controls (breakdown §Scope guardrails, §Cross-cutting contracts). U3 adds **no** `RunConfig` knob.
- **Scatter code is reachable only through `backend == "scatter"`.** `band_four` is the *first* profile to carry `backend = "scatter"`; every socket and cave band's path is untouched. The scatter backend/materialisation/validate branch are U0/U1 deliverables — U3 only *authors data that selects them*.
- **Determinism (non-negotiable).** `BandPipeline.new().generate(band_four, seed)` twice with the same seed → **byte-identical `Band.fingerprint()` AND `floor_fingerprint()`**; different seeds → variety. All scatter sampling is order-stable (sorted candidates, fixed accept/reject) and connectivity is guaranteed **by construction** (cover never disconnects the floor) or by **deterministic CARVE** — U0's contract, which U3's test re-asserts on the *authored* config.
- **No new opposition machinery.** The deck references `&"lobber"`/`&"sentry"` (U2a/U2b) + shipped def ids by string; U3 authors the ordered array + one `DeckEntry` wrapper only. No `EncounterBuilder` edit.
- **M1 lethality model holds.** Every deck entry is a `kills`-gated, emit-always M1 Actor/fixture. No HP pool, no Field/zone/DoT hazards.
- **No save-schema change; fourth portal is U4, not U3.** `band_four` persists nothing; it is regenerated from its seed. Routing (`BAND_ROUTES` + hub portal) is U4.
- **Flavors ship EMPTY.** As with the cave, `SetPieceInject`/`WearDecay` are socket-coupled — inapplicable to synthetic scatter pieces. The cave's `validate()` fail-loud on non-empty flavors is the pattern U0's scatter branch mirrors (§3.6). The arena *is* the flavor.
- **Placeholder art tint-only** (`palette_tint` tier-1, D-RAT-4/5 precedent). No PixelLab without an explicit Director gate; pixel filter OFF; copy-not-move from `art_workshop/`.

---

## 1. Goal & design intent

**One sentence:** *A fourth, deepest dive band that exists almost entirely as data — a poisson-scattered open-field arena (long sightlines, see-and-be-seen, sparse hard cover in a "too-open expanse") in a cold non-Euclidean-dark tint, `band_depth = 4` (→ 1.45 instability, 34-credit budget), stocked with the two long-sightline ranged natives plus the one melee def the cave had to cut — proving the M1.9/1.10 machinery scales to a **third** generator with, again, ~zero marginal engineering.*

U3 is the payoff of M1.11's thesis. U0 built the third backend; U1 proved a scattered open field is playable on the unchanged synthetic-piece path; U2a/U2b added two oppositions that *need* long sightlines. **U3 is where those parts earn their keep as data**: a band that reads as a different *reality* (per the GDD's Band-4 "Far"), assembled from a `ScatterBandConfig` + a `band_depth` + a deck array + a tint — no new generation code. The watch-item UG3 judges is exactly the **N=3 cost-ledger trend**: band 2 cost 1 glue line, band 3 cost 0 — *did band 4 come in at 0 too, i.e. is "content = data" now compounding?* The answer this spec is engineered to deliver is **yes, 0** (§5.2).

**Design feel target (for the Director's sweep, not a balance claim):** band 4 should read as *"the yard has become a definition — an alien flat with nowhere to hide, watched from every angle."* Long uninterrupted sightlines you cross at a sprint; discrete hard cover you tuck behind for exactly as long as the Lobber lets you; a Sentry lane you must read before you step into it. It is the deliberate **spatial opposite** of band 3's claustrophobic nook-rich cave — the cave hid you in bad sightlines; the far field strips them away. The +45% opposition budget (1.45 vs band 1's 1.00) plus two natives that weaponise the *good* legibility (Sentry denies a lane you can see; Lobber punishes the cover you'd hide in) make the step over band 3 *felt*. Whether that step is *right* — and whether an open field reads *tense* or *empty* at our top-down scale (the b1 fun flag) — is a UG2/UG3 playtest call. U3 ships a coherent starting point, not a tuned one.

---

## 2. Research — what band 4 is, and what U3 actually needs

### 2.1 What the GDD makes band 4 (`band_depth = 4`)

The GDD escalation table (`design/Junkyard_GDD.md:59`) names band 4 canonically:

> **Band 4 — Far** | A junkyard by an *alien or magical* definition | Discarded gods, molted star-husks, a place that eats categories | **Reality-warping treasures, lore cores** | **Severe; the deep things**

And the art pillar (`:185`): *"the depths shift palette by band — familiar grime → desaturated nostalgia → impossible color → **non-Euclidean dark**."* Band 1 (greybox) = familiar grime (neutral white); band 2 ("The Sump") = desaturated nostalgia (sepia-amber `Color(0.82, 0.66, 0.42)`); band 3 ("The Warren") = impossible color (blue-violet `Color(0.62, 0.60, 0.78)`); **band 4 = the "non-Euclidean dark" step** — the darkest, coldest, most alien tint yet, a place that reads as *not a place*.

The open-field exploration (`design/explorations/.../b1-open-field-with-cover.md`) independently offers this archetype's deep read: *"again deep as a wrong, too-open expanse."* **These agree:** the scatter open field (a vast exposed flat, discrete cover, long sightlines) *is* the visual grammar of the GDD's "Far / alien flat." The exploration's dive-clock note (`:25`) sharpens the intent: an open field is *"fast to cross but dangerous to dwell in — perfect for the extract decision"*, with *"high-value junk placed in the exposed center vs. safe behind cover at the edges"* making push-or-cash-out a **spatial** choice. The pitches in §3.1 fuse the GDD's "Far" with the exploration's "too-open expanse."

### 2.2 What `band_depth = 4` means for the budget (as-built, exact — breakdown OQ11)

The single budget scalar is the shipped static `EncounterBuilder.instability(band_depth)` (`systems/spawning/encounter_builder.gd:64`):

```gdscript
static func instability(band_depth: int) -> float:
    return 1.0 + 0.15 * float(band_depth - 1)
```

So `instability(1) = 1.00`, `instability(2) = 1.15`, `instability(3) = 1.30`, **`instability(4) = 1.45`**. The deck-lane credit budget is computed once per band (`_populate_deck`, `:299`):

```gdscript
var budget: int = int(floor(float(BASE_CREDITS) * instability(band_depth)))
# band 2:  floor(24 * 1.15) = floor(27.6) = 27  ✓ (as-built control)
# band 3:  floor(24 * 1.30) = floor(31.2) = 31  ✓ (as-built control)
# band 4:  floor(24 * 1.45) = floor(34.8) = 34      ← U3
```

**Band 4 gets a flat 34-credit deck budget** (`BASE_CREDITS = 24`, `:38`). The rounding rule is `int(floor(...))` — `34.8 → 34`, exactly matching the 27/31 verification the breakdown demanded. This is +45% over band 1, +26% over band 2, and **+9.7% (34 vs 31 credits) over band 3** in raw credits (+11.5% in the multiplier). It is the only difficulty lever `band_depth` pulls in M1.11 — the full I→stats→loot coupling stays M2 (`:59` docstring). Whether +9.7% over band 3 is a *felt* whole-band step is a UG2 telemetry call, not something U3 pre-tunes (OQ4).

### 2.3 How the deck lane actually spends — the load-bearing mechanic (verified against `encounter_builder.gd:297-370`)

The T3 findings hold verbatim on the shipped code; the load-bearing facts for U3's deck:

1. **Draw = authored array order, id-deduped. `spawn_weight` is RESERVED / INERT.** The array order **is** the priority list — the earlier a def sits, the earlier it gets first call on the budget (`:324` `for d in eligible`).
2. **A def only spawns if its effective `base_count`/`count_per_depth` demand is > 0** (`:329-334`). Demand `= Σ over eligible pieces of (base_count + floor(count_per_depth · depth_index))`. If `0`, the def is a *neutral card — skipped, no spend*.
3. **Plan size is bounded by affordability AND the def's own `per_band_cap`** (`:337-340`): `n_plan = mini(demand, budget / credit_cost, per_band_cap)`. **`credit_cost` and `per_band_cap` are TYPED `OppositionDef` fields a `DeckEntry` CANNOT override** — `DeckEntry` merges `params` only (`deck_entry.gd`; precedence `def params < deck-entry < rc.param_overrides`, `:33`). This is load-bearing for band 4's supporting draw (§3.4): a shipped def's cap is *frozen at its def value*, and editing its `.tres` would perturb a control.
4. **`per_band_cap = 0` means UNCAPPED** (`:339` gates on `> 0`); such a def is bounded only by budget/demand — the "remainder-soak" lever (`bomb`, `spike`, `pingpong` all ship `per_band_cap = 0`).
5. **The lever to make a `base_count = 0` shipped hazard live in a deck is a `DeckEntry { "base_count": 1 }` wrapper** — exactly what `band_three`'s bomb row does (`band_three.tres:13-18`). `base_count` is a valid schema key on `bomb` (its `param_schema` lists it), so the params↔schema bijection stays green, and the override touches *only band 4's row*, not `bomb.tres`.

**Consequence for U3:** the two natives (`lobber`/`sentry`) carry their own `base_count > 0` and `credit_cost`/`per_band_cap` on their defs (U2a/U2b author that — §4.3 flags the coordination targets). The supporting `charger` already carries `base_count = 1` (spawns with **no wrapper**). A single `bomb` remainder-mine rides the same `DeckEntry { base_count: 1 }` pattern band 3 proved. **Zero new code** — every lever is shipped machinery.

### 2.4 Which existing defs suit long sightlines — the supporting-draw analysis (the breakdown asks each)

Reasoned from each def's as-built behavior + credit card (`data/oppositions/*.tres`, read fresh):

| Def | as-built card | Open-field fit |
|---|---|---|
| **`charger` ★** | `credit_cost 2, per_band_cap 4, per_room_cap 1, base_count 1, min_band 2` (ChargeLane, `charge_max_dist ≈ 400`) | **The headline supporting pick.** Its identity is a *straight-lane charge* that **T3 EXCLUDED from the cave** ("bad sightlines rarely give it a clean 400px lane"). The open field is the band that *hands it those lanes* — long sightlines = clean charge corridors. The **exact same def, cut from band 3, is the def that shines in band 4**, purely by deck data — the cleanest possible demonstration that band identity is expressed by *which existing defs fit*, not by new code. It is the melee def *most* compatible with the open field (a lane-charger *wants* sightlines like the ranged pair, unlike a vision-cone ambusher). |
| `splitter` | `credit_cost 3, per_band_cap 8, base_count 1, min_band 2` (chase/proximity) | Geometry-agnostic filler; works anywhere. A reasonable **Director alternate** to charger if a lane-charger is judged to over-crowd the ranged showcase, but it adds no open-field *identity* the way charger does. |
| `bomb` | `credit_cost 1, per_band_cap 0 (uncapped), base_count 0, min_band 0` (static proximity mine) | **The remainder-soak + "exposed-center" spice.** A single mine (via the band-3 `DeckEntry` pattern) placed mid-depth reads as a hazard guarding the open center — ties to the exploration's exposed-center risk/reward. Uncapped, so it soaks the last credit cleanly. |
| `pingpong` | `cost 1, uncapped, base_count 0` (StraightBounceMove) | *Better* here than in the cave (long clean walls → predictable bounces vs. the cave's chaotic ricochet), but its chaos still fights the "read the lane" legibility the ranged pair builds. Held as a Director option, not a default. |
| `spike` | `cost 1, uncapped, base_count 0` (rotating fixture) | Geometrically fine in an open chamber, but adds little the natives + charger + bomb don't. Held as a Director "add for density" option. |
| `pursuer` | `cost 1, cap_group &"", per_band_cap 0, no base_count key` | **Exclude** (same as T3): spawns via the retained R1 depth-linger lane, not `base_count`; deck-membership is a semantic mismatch that confounds the clean A/B. |
| `ambusher` / `burrower` | `min_band 3` cave natives | **Exclude** — the low-sightline natives are the *cave's* identity; putting them on the open field neuters their concealment (the exploration's own melee-tension note, `:81`). Keeping them band-3-exclusive preserves the clean four-band A/B. |

### 2.5 What U3 reuses as-is (the marginal-cost inventory)

Everything below is consumed unchanged — this is *why* band 4 is data, not engineering:

| Reused | Where | U3's use |
|---|---|---|
| Scatter backend + `ScatterBandConfig` schema + validate() scatter branch | U0 (`systems/bandgen/`, `band_profile.gd`) | author a *tuned instance* of `ScatterBandConfig` |
| Scatter materialisation + backend-agnostic sealing + `palette_tint` apply | U1 / M1.10 T1 (`main_game.gd`, unchanged) | set `palette_tint`; the pipeline consumes it |
| `Band.fingerprint()`/`floor_fingerprint()` over synthetic pieces | U0 | test asserts determinism on the authored config |
| `DepthGrader` (BFS depth) + `JunkPlacer` (loot on `floor_cells`) | shipped, FLOOR-cell-only | consume scatter floor unchanged |
| `EncounterBuilder` deck lane + budget + `min_band` gate + `DeckEntry` merge | `encounter_builder.gd` | author the deck array + one wrapper |
| `instability()` = 1.45 at depth 4 | `encounter_builder.gd:64` | drives the 34-credit budget from `band_depth = 4` |
| `DepthCurve` + shared `junk_catalog.tres` | shipped | author a reward-lifted `depth_curve_band_four.tres`; reuse the shared catalog |
| `lobber`/`sentry` defs + MortarCycle/LaneWatch | U2a/U2b | reference ids in the deck |
| `charger`/`bomb` defs (frozen) | shipped | reference by id; `bomb` via a `DeckEntry` wrapper |
| S4 generated Oppositions tab + IN-DECK chips | shipped, count-agnostic | pick up band 4's deck with **zero menu code** |

**Genuinely needed beyond a value in a `.tres`:** *predicted **none** in production code* (§5.2). The `palette_tint` field exists; U1 wires the scatter materialisation to consume it (it already hosts cave tint); the deck lane + `DeckEntry` are shipped; the `depth_curve` slot is shipped. U3's whole footprint is **3 `.tres` + 1 mirrored test**.

---

## 3. Design spec

### 3.1 Band identity pitches (Director picks — the tone call, breakdown OQ3)

Three pitches. **Pitch A honors the GDD's canonical Band-4 "Far"**; B and C are alternate tones. **All three share the identical mechanical spec (§3.2–§3.6)** — only name/fiction/palette-tint differ, so the pick does not gate the build. Pitched the way "The Sump"/"The Warren" were.

> **Portal-glow constraint (M1.10 amendment-12, binding — carried into the pitch below, not left to the table).** Portal glow `glow_tint` **MULTIPLIES** over the violet-dominant portal art (dominant opaque pixel `(193, 85, 255) ≈ (0.76, 0.33, 1.0)`; green channel physically caps effective output at ~0.33). **Three hue families are TAKEN:** portal 1 = WHITE-modulate → reads **violet**; portal 2 = **ember-orange** `Color(1.0, 0.58, 0.24)`; portal 3 = **cave-teal** `Color(0.30, 0.90, 0.65)`. The only clean *free* family left is a **deep cold blue** (low red, low-capped green, full blue): e.g. `Color(0.28, 0.42, 1.0)` renders `(0.21, 0.14, 1.0)` — a saturated deep blue, unambiguously distinct from teal's cyan `(0.23, 0.30, 0.65)`. **All three pitches therefore share the deep-cold-blue portal glow family** (band `palette_tint` is a *separate channel* and differs per pitch); U4 owns the final `glow_tint`/`gate_tint` within that family. Magenta/violet glows are forbidden (clone portal 1); ember is forbidden (clone portal 2). This mirrors T3's Phase-3 portal-glow correction exactly.

| # | Name | One-line fiction | Palette direction (tier-1 tint) | Mood |
|---|---|---|---|---|
| **A ★ (canonical "Far", recommended)** | **The Far Field** | *"Past reality's edge the yard stops being a place and becomes a definition — an alien flat where discarded gods and molted star-husks lie scattered under a sky that isn't one: too open, and watched from every angle."* | **Cold non-Euclidean dark** — greybox greys pushed *darker and bluer* than the Warren, a deep desaturated indigo/blue-black (`palette_tint ≈ Color(0.42, 0.46, 0.62)`). The GDD's "non-Euclidean dark" step; clearly deeper than band 3's dim violet. | Vast, exposed, cosmic-cold. The name echoes the game's own title (**THE FAR YARD**) — the deepest band *is* the far field. |
| **B** | **The Reliquary** | *"A drained basin where dead divinities were dumped — molted star-husks and the bones of discarded gods lie half-buried across an exposed flat that still remembers being worshipped."* | **Cold bone-grey** with a faint sickly corpse-light cast (`palette_tint ≈ Color(0.56, 0.58, 0.52)`). | Sepulchral, reverent-wrong, an ossuary in the open. |
| **C** | **The Threshing Floor** | *"A place that eats categories — an endless open floor where everything sorted comes unsorted again; stand still and it starts to count you among the scrap."* | **Stark cold near-monochrome** — very desaturated greyscale with a cold cast (`palette_tint ≈ Color(0.50, 0.52, 0.55)`), a bleached "void" read of "non-Euclidean dark." | Clinical, void, wrong-empty; leans hardest into "an open field can be its own horror." |

**Recommendation: Pitch A "The Far Field."** It is the GDD's already-canon Band-4 "Far" (alien flat = the scatter arena's literal grammar; discarded gods / star-husks = the tier-lifted anomalous loot; "a place that eats categories" = the disorienting too-open expanse), its **cold indigo/blue-black is the clearest "non-Euclidean dark" escalation** past band 3's blue-violet and the *most distinct* deepest-band tint, and the name **resonates with the game's own title** — the final M1 band being "The Far Field" of *THE FAR YARD* is a quiet payoff. **This is a vision/tone call — needs Director review (D1).**

### 3.2 `band_four.tres` — the concrete value table

Authored against the `BandProfile` schema (`data/bands/band_profile.gd`). Values chosen for "a vast, sparse-cover, long-sightline open field, deeper and stranger than band 3," explicitly *configurable, not balanced*. The table mirrors `band_three.tres` field-for-field (the direct template).

| Field | `band_three` (control) | **`band_four` (U3)** | Why |
|---|---|---|---|
| `id` | `&"band_three"` | `&"band_four"` | stable content id; U4 stamps the ROUTE key `&"band_four"` on telemetry. |
| `display_name` | "The Warren" | **"The Far Field"** (Pitch A; Director may swap) | portal prompt / HUD (used by U4). |
| `backend` | `"cave"` | **`"scatter"`** | selects the U0 scatter backend — the whole point. |
| `backend_config` | `cave_config_band_three.tres` | **`scatter_config_band_four.tres`** (new, §3.3) | a `ScatterBandConfig`, not a `CaveBandConfig`. Path follows U0's landed convention (mirror of the cave sibling). |
| `archetype` | `"linear"` (inert for cave) | **`"linear"`** (inert for scatter) | the enum has no scatter value; the scatter `validate()` branch must not read `archetype` (warn-only, like the cave branch — coordination note to U0, §7). Neutral default. |
| `archetype_params` | `{}` | `{}` | unused for scatter. |
| `piece_pool` | `null` | **`null`** | a scattered arena has no authored pieces; the backend emits synthetic `scat_` pieces from `floor_cells`. The scatter `validate()` branch must not require `piece_pool` (coordination note to U0). |
| `piece_pool_ext` | `null` | `null` | socket-only lvl swap; unused. |
| `principles` | `[]` | `[]` | no principle stages (M2). |
| `flavors` | `[]` (EMPTY) | **`[]` (EMPTY)** | §3.6 — socket flavors inapplicable to synthetic scatter pieces; U0's scatter `validate()` fail-louds on non-empty flavors (the cave rule carries). The arena is its own flavor. |
| `depth_curve` | `depth_curve_band_three.tres` | **`depth_curve_band_four.tres`** (reward-lifted past band 3, §3.5) | "band 4 loot is reality-warping / lore cores." |
| `junk_catalog` | `junk_catalog.tres` (shared) | `junk_catalog.tres` (shared) | no new junk items in M1.11 scope (tier-6 "reality-warping treasures / lore cores" is an M2 content follow-up, OQ8). |
| `opposition_deck` | 4-entry (natives + splitter + bomb-DeckEntry) | **4-entry deck** (§3.4) | lobber + sentry + charger + a `DeckEntry`-wrapped bomb. |
| `band_depth` | `3` | **`4`** | → `instability(4) = 1.45` → 34-credit budget (§2.2). |
| `palette_tint` | `Color(0.62, 0.60, 0.78, 1)` | **`Color(0.42, 0.46, 0.62, 1)`** (Pitch A) | the "non-Euclidean dark" identity; the scatter materialisation modulates the band root with it. Environment-artist finalizes the exact value per the ratified pitch. |

### 3.3 `scatter_config_band_four.tres` — the tuned `ScatterBandConfig` (the cover-density point defended, breakdown OQ9)

A **new** `ScatterBandConfig` instance (U0 owns the class/schema/defaults; U3 authors this tuned instance). The breakdown (§U0) names the schema as **integer-only**: *arena extents, `cover_density`, `min_cover_spacing`, `cover_size_mix` weights, `edge_cover_bias`, `clear_lane_width`* + the cave-idiom chunking fields (`chunk_cells`, `min_floor_cells`, `max_attempts`, `cell_size_px`) so the depth axis works. The b1 knob list (`:69-75`) is the design source.

> **The cover-density point — sparse-deadly (recommended), with the fun argument both ways (breakdown OQ9, the band's *feel*).**
>
> - **Sparse-deadly (RECOMMEND).** Band 4 is the deepest, most lethal band ("severe; the deep things"). A sparse, exposed killing-field: (1) **maximizes the "too-open expanse" dread** the b1 doc names and the GDD's "non-Euclidean dark" demands; (2) **maximizes long sightlines** — the identity bar U0's `test_scatter_backend` pins — so the band *provably* reads open; (3) makes the ranged pair maximally dangerous (you can't hide, you must keep moving and use the **throw verb at range**, the verb this archetype exists to showcase); (4) is the **maximal experiential contrast** to band 3's claustrophobic nook-rich cave — directly serving the Director's "as different as possible" directive. Crucially, it keeps *enough* discrete hard cover that the **Sentry's "cover blocks the bolt" lesson still reads** (cover is a scarce, precious option), so the cover *dialogue* (Sentry makes cover safe · Lobber makes camping it deadly) survives — the band's whole thesis.
> - **Dense-stealth (the alternate).** Dense cover makes break-LOS counterplay central, turns the ranged enemies into a *puzzle* rather than a *wall*, and is more forgiving. **But** it (1) reads *less* distinct from the cave (both become "pick through cover"), undercutting "as different as possible"; (2) dulls the ranged showcase (the exploration's own melee/ranged tradeoff, `:81-84`); (3) risks failing U0's long-sightline identity bar. It is the Director's fallback **if UG2 shows the sparse field reads "empty/unfair" rather than "tense"** (the b1 fun flag, `:104`).
>
> **Chosen point: sparse-to-moderate, leaning sparse** — a killing field with *scattered discrete hard cover biased to the rim*, so the center is the exposed high-risk zone and cover is a scarce edge resource. UG2 validates the felt read; the Director ratifies the point.

Proposed starting values (against the breakdown's stated field list; flagged as pending U0's landed schema — §7 OQ5):

| `ScatterBandConfig` field (breakdown-named) | Proposed value | Why (sparse-deadly, long-sightline feel) |
|---|---|---|
| `arena_width` × `arena_height` | **64 × 64 cells** (16px cells) | a large open flat — bigger than the cave's 56² so sightlines run *longer* (arena size = sightline length, b1 `:72`); 64/`chunk_cells 8` = 8×8 = **64 chunk-pieces**, giving the BFS depth axis real range (`max_depth ≥ 4`) and P ≈ 40-60 eligible pieces so deck demand never binds (§4.3). |
| `cover_density` | **~8** (sparse; U0 defines the exact unit — % of floor, or obstacles-per-N-cells) | the single experience dial (b1 `:69`). Low = exposed killing-field (recommended). Tuned so a clear majority of the floor is open sightline — must satisfy U0's long-sightline identity bar (coordination, §7 OQ5). |
| `min_cover_spacing` | **4** (poisson radius, cells) | cover islands well-separated — "guards against accidental mazes" (b1 `:73`); preserves the long sightlines between cover. |
| `cover_size_mix` (small/med/large weights) | **[4, 2, 1]** (biased small) | small "pillar" footprints = discrete tuck-behind cover, not wall segments — keeps sightlines open and the field readable (b1 `:70-71`). Large footprints are rare (occasional wreck to break a lane). |
| `edge_cover_bias` | **~60** (toward the rim; U0 defines the unit) | "push cover to rim → open killing-center" (b1 `:74`). Creates the exposed center where the highest-risk crossing lives — the spatial push-or-cash-out read (§2.1). |
| `clear_lane_width` | **2** | the protected entry→gate corridor (b1 `:75`), matching the cave's `carve_width 2` / socket-doorway player-scale floor — a guaranteed traversable spine so scatter never walls off the extract. |
| `chunk_cells` | **8** (reuse the cave idiom) | content-hashed `scat_` synthetic-piece partition so `max_depth ≥ 4` and the depth/loot economy work (breakdown §U0; the M1.10 amendment-4 lesson — an unchunked arena zeros the depth economy). **Coordination flag: U0 must expose `chunk_cells` on `ScatterBandConfig` (§7 OQ5).** |
| `min_floor_cells` | **500** | retry soft floor; 64² interior at sparse cover clears it comfortably (scaled up from the cave's 300 for the larger arena). |
| `max_attempts` | **8** | the socket/cave retry model default. |
| `cell_size_px` | **16** | must agree with the materialisation cell size + JunkPlacer's instance-null fallback (`junk_placer.gd:201`). |

> **Determinism note:** every value here feeds U0's order-stable poisson sampling + deterministic carve, so `(band_four + seed)` → one `fingerprint()` forever. These values change the *shape*, never the *reproducibility*. Exact shape numbers (`cover_density`/`min_cover_spacing`/`edge_cover_bias`) stay integration-tunable within the "sparse, long-sightline, rim-biased" intent, with **U0's long-sightline bar and U1's 2×2-open throat + `max_depth ≥ 4` bars as the hard floors** — the contract test re-asserts them on the *authored* config (§4.4).

### 3.4 `opposition_deck` — 4 entries, ranged-natives-first (authored order = budget priority)

The deck the `EncounterBuilder` deck lane spends the **34-credit** budget on (§2.2). Draw = **authored array order** (weights inert); `min_band ≤ band_depth(4)` gates; `charger` spawns on its own `base_count = 1`; `bomb` needs a `DeckEntry base_count` override (§2.3). Ranged natives sit first so they get first call on the budget — the band's identity is the ranged pair.

| # | Deck entry | `min_band` | Row type | Effective `base_count` | `credit_cost` · `per_band_cap` | Open-field justification |
|---|---|---|---|---|---|---|
| 1 | `&"lobber"` (U2a) | **4** | plain ref | on def (1) | **target 3 · 5** *(U2a authors)* | **Native marquee.** The camp-punisher: arcs a shot onto your position, *ignoring cover* — the reason you can't just hide behind the scarce cover. First budget priority. |
| 2 | `&"sentry"` (U2b) | **4** | plain ref | on def (1) | **target 2 · 5** *(U2b authors)* | **Native.** The lane-denier: a stationary bolt down one long sightline, *blocked by cover* — the reason cover matters at all. Second priority. Lobber + Sentry = the band's cover dialogue. |
| 3 | `&"charger"` (shipped) | 2 | plain ref | `1` (on def) | `2` · **`4` (FROZEN def field)** | **The cave's cast-off, come alive.** T3 cut it from the cave for lack of lanes; the open field *is* its lanes. `per_band_cap = 4` is a typed def field a `DeckEntry` cannot raise (and `charger.tres` must not change — band-2 control), so it self-limits to 4. |
| 4 | `&"bomb"` (shipped) | 0 | **`DeckEntry` { `base_count`: 1 }** | `1` (via override) | `1` · uncapped | **Exposed-center mine + remainder soak.** A single static proximity mine, placed mid-depth by even-spread — a hazard guarding the open center. Uncapped, so it soaks the last credit to exactly 0. The exact `band_three` `DeckEntry` pattern reused verbatim. |

**Deck exclusivity (breakdown OQ8, mirrors band_two's D-RAT-2 / band_three's D3):** `lobber`/`sentry` are `min_band = 4` on their defs (U2a/U2b), so they are **band-4-exclusive** structurally — bands 1/2/3 (`band_depth < 4`) never see them regardless of lane. This gives UG2 a clean four-band A/B. Recommend **yes, exclusive for M1.11** (D3). `charger` is *shared* (min_band 2 → appears in bands 2 and 4) — a deliberate feature (the "same def, opposite band, opposite outcome" story), not a leak.

### 3.5 `depth_curve_band_four.tres` — reward-lifted PAST band 3 (breakdown: extend the tier/value escalation past 2.5/5)

A **new** `DepthCurve` (`systems/depth/depth_curve.gd`: `value_curve`, `density_curve`, `tier_threshold_curve`), lifting reward over band 3's (value 1.30→2.5, tier floor 3 → ceiling 5, density 1.0→1.3 per-chunk — read from the shipped `depth_curve_band_three.tres`):

| Curve | band 3 | **band 4** | Effect |
|---|---|---|---|
| `value_curve` | 1.30 → 2.5 | **1.45 → 2.9** | shallow floor matches the 1.45 instability kick; ceiling rises past band 3's 2.5 — the value multiplier is *not* pool-gated, so it escalates freely. |
| `tier_threshold_curve` | stepped 3 → 5 | **stepped 4 → 5** | band 4 *starts* at min tier **4** (excludes tiers 1-3 entirely — only the rarest loot from the first chunk) and holds the tier-5 ceiling. "Band 4 loot is the rarest," expressed via the tier gate on the shared pool. |
| `density_curve` | 1.0 → 1.3 (per chunk-piece) | **1.0 → 1.4 (per chunk-piece)** | slightly denser per chunk-piece than band 3, still low — see the re-base note below. |

> **Junk density RE-BASE (breakdown-required; the T3 OQ8 lesson, verified against `junk_placer.gd`).** `JunkPlacer.plan()` rolls `expected_count` **per piece** (flat per-piece count; `loot_density_per_area` ships OFF and is never preset-on). A **chunked scatter arena has ~40-64 floor-bearing pieces** (64×64 / 8² chunks) vs. band 2's ~16 — even more than the cave. Copying band-2-scaled density (2.3→2.8) would flood ~110-180 junk per dive, a 3-4× loot flood that would invert the risk/reward step. **Density is therefore authored at ≈ 1.0 → 1.4 per chunk-piece** (a hair above band 3's 1.0→1.3), targeting a **band-total of ~55-75 items** — the reward escalation is carried by **value (1.45→2.9) and the tier floor (4)**, not raw count. Exact endpoints are integration-tunable against a *measured* plan-size on the seed matrix; **the worklog records the measured band-total** so UG2 reads the four-band loot comparison on band-total *value*, not naive item counts (the TG2 note from T3 carries).

> **Tier-ceiling honesty (T3's R-OQ4 finding, re-verified).** The shared junk pool tops out at **tier 5** (items at tiers 1,1,2,2,3,3,4,5). So band 4's ceiling is 5 (same as band 3), but its *floor* rises to 4 — meaning band 4 draws *only* tier-4/5 items throughout, the rarest slice of the pool. The GDD's literal Band-4 loot ("reality-warping treasures, lore cores") is tier-6+ flavored, which the shared pool has none of. Adding tier-6 items is an **M2 content follow-up**, not M1.11 scope (OQ8, mirrors T3's tier-6 deferral). `JunkPlacer._eligible_indices` has a whole-catalog fallback, so a tier-4 floor can never *empty* a piece.

### 3.6 Flavors EMPTY (breakdown implicit — the cave rule carries, and is *mandatory*)

`band_four.flavors = []`. Per the shipped cave `validate()` (`band_profile.gd:108-109`), a cave profile with non-empty flavors returns a fail-loud problem string. U0's scatter `validate()` branch **must mirror this** (coordination note, §7): `SetPieceInject`/`WearDecay` are socket-coupled (append-to-open-socket / block-doorway-between-mated-pieces) and have no attach point on synthetic scatter pieces — a flavor-bearing scatter profile is an authoring error. **Confirmed: `flavors` ships EMPTY on `band_four`.** The contract test asserts `flavors.size() == 0`, and `validate()` clean depends on U0 fail-louding non-empty scatter flavors (the single-location rule).

### 3.7 Loot-placement bias & depth-signposting — watch-items, not build scope

Two open-field reads the exploration flags that U3 **cannot fully express as data today** — recorded for the gate, not silently absorbed:

- **Exposed-center high-value loot (b1 `:27-28`).** The exploration's richest read — "high-value junk in the exposed center vs. safe behind cover at the edges" — is only *half* expressible today. `edge_cover_bias` (§3.3) puts *cover* on the rim, making the center geometrically exposed; but `JunkPlacer` scatters loot by **depth on `floor_cells` uniformly** — it has no notion of "center vs. edge" and **cannot bias loot *value* toward the exposed center**. So the spatial push-or-cash-out choice is present as *geometry* (open center) but not as *loot-value gradient*. **This is a UG2/UG3 watch-item + a candidate M2 JunkPlacer feature (an `exposure_value_bias`), explicitly out of U3's build scope.** (OQ6.)
- **Depth-signposting.** Like the cave, a scattered arena's depth is less eyeballable than a linear spine (BFS hops are mechanically real; the gate is at the deepest chunk; return distance is computed — but not sighted across the open flat). Ships as-is; a UG2/UG3 watch-item (does the open field disorient *productively* or read as *lost/empty*?), not U3 scope.

---

## 4. Pseudocode / data sketch

### 4.1 `band_four.tres` — field-by-field (the actual resource U3 authors)

```
BandProfile (data/bands/band_four.tres)
  id              = &"band_four"
  display_name    = "The Far Field"                       # Pitch A (Director may swap)
  backend         = "scatter"                             # ← selects the U0 backend
  backend_config  = ExtResource(scatter_config_band_four.tres)  # a ScatterBandConfig
  archetype       = "linear"                              # inert for scatter (warn-only)
  archetype_params= {}
  piece_pool      = null                                  # scatter emits synthetic pieces
  piece_pool_ext  = null
  principles      = []
  flavors         = []                                    # EMPTY (§3.6, validate() fail-louds)
  depth_curve     = ExtResource(depth_curve_band_four.tres)     # reward-lifted past band 3
  junk_catalog    = ExtResource(junk_catalog.tres)        # shared
  opposition_deck = [                                     # ranged-natives-first (§3.4)
      ExtResource(lobber.tres),                           #   [0] native, min_band 4
      ExtResource(sentry.tres),                           #   [1] native, min_band 4
      ExtResource(charger.tres),                          #   [2] base_count 1 on def
      DeckEntry{ def: ExtResource(bomb.tres),             #   [3] wrapper → live single mine
                 param_overrides: { "base_count": 1 } },
  ]
  band_depth      = 4                                     # → instability 1.45 → 34 credits
  palette_tint    = Color(0.42, 0.46, 0.62, 1)            # Pitch A "non-Euclidean dark"
```

The `.tres` structure is a byte-for-byte shape clone of `band_three.tres` (same `deck_entry_bomb` SubResource, same load_steps pattern) — only the resource references, ids, backend string, depth, and tint change. That structural identity **is** the "content = data" evidence.

### 4.2 `scatter_config_band_four.tres` (values from §3.3; U0 owns final field names)

```
ScatterBandConfig (data/bands/scatter_config_band_four.tres)   # path mirrors cave sibling
  arena_width       = 64
  arena_height      = 64
  cover_density     = 8          # sparse (U0 defines exact unit — flag OQ5)
  min_cover_spacing = 4
  cover_size_mix    = [4, 2, 1]  # small/med/large weights (U0's representation — flag OQ5)
  edge_cover_bias   = 60         # rim-biased → exposed center
  clear_lane_width  = 2
  chunk_cells       = 8          # depth-axis partition (MUST exist on U0's schema — OQ5)
  min_floor_cells   = 500
  max_attempts      = 8
  cell_size_px      = 16
```

### 4.3 Deterministic deck outcome at 34 credits (the D-RAT-6-style pin, breakdown OQ11)

Budget = `floor(24 · 1.45) = 34`. On a chunked scatter arena, eligible pieces P ≈ 40-60 (entry + no-cell chunks excluded), so `base_count 1 · P` demand (40-60 per def) never binds — **caps + budget bind**. Walk in authored order, using the **coordination-target native cards** (§7 OQ7): `lobber cost 3 / per_band_cap 5`, `sentry cost 2 / per_band_cap 5`, `charger cost 2 / per_band_cap 4 (frozen)`, `bomb cost 1 / uncapped (base_count 1 via DeckEntry)`:

```
budget 34 → lobber  n=min(P, 34/3=11, 5)=5  (spend 15, budget 19)
          → sentry  n=min(P, 19/2=9,  5)=5  (spend 10, budget  9)
          → charger n=min(P,  9/2=4,  4)=4  (spend  8, budget  1)
          → bomb    n=min(P,  1/1=1,  ∞)=1  (spend  1, budget  0)
          = 5 + 5 + 4 + 1 = 15 spawns, budget spends EXACTLY to 0
```

Credit check: `5·3 + 5·2 + 4·2 + 1·1 = 15 + 10 + 8 + 1 = 34`. **The pinned outcome is `lobber 5 / sentry 5 / charger 4 / bomb 1 = 15`**, ranged-pair-dominant (10 of 15), charger the open-field spice (4), a single mid-depth mine (1). This structurally mirrors band 3's `6/3/4/1 = 14` pin (natives-heavy, mid supporting def, single bomb remainder) — the deck-authoring pattern compounds.

> **Coordination caveat (the pin depends on U2a/U2b's actual cards — the T3 OQ7 situation).** `lobber`/`sentry` do not exist yet (Wave 1). The `5/5/4/1 = 15` pin is computed on the **target cards above**; U2a/U2b own the real `credit_cost`/`per_band_cap`. If they land different values the deck still spends validly (self-limiting) — only the counts shift, a UG2 tuning read. **The contract test's `EXPECT_SPAWNS` constants are finalized against the *shipped* `lobber.tres`/`sentry.tres` at build time**, exactly as `test_band_three_profile.gd`'s `6/3/4/1` was pinned against the shipped ambusher/burrower. §7 OQ7 flags the targets to U2a/U2b.

### 4.4 Contract test plan — `tests/test_band_four_profile.gd` (+ `.tscn`)

A near-verbatim clone of the shipped `test_band_three_profile.gd` (run as a SCENE), retargeted to `band_four` and the scatter backend. Same `SEEDS` matrix, same `FakeSpawnService` recording harness. Checks:

| # | Check | Adapts band_three's |
|---|---|---|
| **C0** | profile-load contract: `id == &"band_four"`, `display_name` (ratified), `backend == "scatter"`, `band_depth == 4`, `validate()` clean, `backend_config` is a `ScatterBandConfig` with the §3.3 values, `piece_pool == null`, `piece_pool_ext == null`, `principles.size() == 0`, `depth_curve` present (value_mult(0)≈1.45, value_mult(1)≈2.9, min_tier(0)==4, min_tier(1)==5), `junk_catalog` non-null, `palette_tint != Color(1,1,1,1)`, **`flavors.size() == 0`**, deck size 4, every id resolves (`lobber`/`sentry`/`charger`/`bomb`), exactly the bomb row is a `DeckEntry { base_count: 1 }`. | `_check_profile_contract` (scatter config field list; value 1.45/2.9, tier 4/5) |
| **C1** | determinism: same seed → same `fingerprint()` AND `floor_fingerprint()` twice; diff seeds → ≥2 distinct fps. Proves U0's order-stable poisson + carve on the *authored* config. | `_check_determinism` (verbatim) |
| **C2** | connectivity: `is_fully_connected` (cell) + `is_band_connected` (piece) on **every** seed — cover never disconnects the floor. | `_check_connectivity` (verbatim) |
| **C3** | soft floor: total floor cells ≥ `min_floor_cells` and `pieces.size() >= 2` on every seed. | `_check_soft_floor` (verbatim; scatter `min_floor_cells 500`) |
| **C4** | depth axis: `band.max_depth >= 4` on the AUTHORED config across the matrix (U1's granularity bar re-pinned on the shipped band); `deepest_piece` graded at `max_depth`; entry anchor present + reachable (gate lands on FLOOR). | `_check_cave_depth` → `_check_scatter_depth` (verbatim) |
| **C5** | **THREE controls untouched:** `band_greybox` pipeline fp == direct `BandGenerator` fp (verbatim); `band_two` pipeline fp == absolute golden pins (verbatim constants); **`band_three` pipeline fp == absolute golden pins** (NEW — capture from `main` before U3's change; band_three is a cave band with no direct-generator path, so pin by captured constants exactly as band_two is). | `_check_controls_untouched` (extend with a band_three golden array) |
| **C6** | deck: `instability(4) == 1.45`; `floor(24·1.45) == 34`; every deck def passes `min_band ≤ 4`; the two natives (`min_band 4`) included; the deck **SPAWNS the deterministic outcome `lobber 5 / sentry 5 / charger 4 / bomb 1 = 15`** through the real `EncounterBuilder` deck lane at the 34-credit budget (budget spends exactly to 0), across the seed matrix, with no unexpected extra ids. *(`EXPECT_SPAWNS` finalized against shipped `lobber`/`sentry` — §4.3 caveat.)* | `_check_deck` (retarget to depth 4, budget 34, the 5/5/4/1 pin) |
| **C10** | player-scale: the 2×2-open throat certificate (T non-empty, single component, contains the entry anchor, covers the floor) on the AUTHORED scatter config across the matrix (U1's throat bar on the shipped band). | `_check_player_scale` (verbatim) |
| **C11** | **long-sightline identity bar (NEW — the scatter identity, breakdown OQ12):** re-assert U0's `test_scatter_backend` sightline property on the *authored* band_four config across the matrix — some row/column of the arena floor has an uninterrupted sightline ≥ N cells (N = U0's ratified threshold). Pins that the *shipped* band provably reads open, not just U0's defaults (the C4/C10 "re-pin on the authored config" discipline extended to the scatter identity). | new (mirror U0's sightline helper) |

Run: `godot --headless --path Game res://tests/test_band_four_profile.tscn` (exit non-zero on any failure).

---

## 5. Files & the cost ledger

### 5.1 Files to create / touch

**Create (U3-owned, file-disjoint):**
- `Game/data/bands/band_four.tres` — the `BandProfile` (§4.1).
- `Game/data/bands/scatter_config_band_four.tres` — the tuned `ScatterBandConfig` (§4.2; final path/name follows U0's landed convention — the cave sibling lives at `data/bands/cave_config_band_three.tres`, so mirror it).
- `Game/systems/depth/depth_curve_band_four.tres` — the reward-lifted `DepthCurve` (§3.5).
- `Game/tests/test_band_four_profile.gd` + `.tscn` — the contract test (§4.4).

**Touch (production code):** *predicted **none*** (§5.2). The `palette_tint` field exists (`band_profile.gd:71`); U1 wires the scatter materialisation to consume it; the deck lane + `DeckEntry` are shipped. If a genuine seam surfaces (U0's scatter `validate()` demands `piece_pool`/`archetype`, or the `ScatterBandConfig` schema lacks a field §3.3 needs), it is a **flagged deviation with a coordination note to U0** (§7), not a silent U3 edit.

**Must NOT touch (contract):** `band_greybox.tres`, `band_two.tres`, `band_three.tres`, `bandgen_config*`, `cave_config_band_three.tres`, `depth_curve.tres`/`_band_two`/`_band_three`, any shipped `OppositionDef` default (incl. `charger.tres` and `bomb.tres` — the base_count lives in the `DeckEntry`, not the def), `run_config.gd` all-off default, `event_bus.gd`/`game_state.gd`/save code.

### 5.2 Cost-ledger prediction (the headline N=3 scalability answer for UG3)

The breakdown makes U3's worklog *the* scalability ledger — the N=3 trend line. The honest framing separates **fixed** from **marginal** cost:

- **Fixed cost (one-time, amortized over every future scatter band):** U0 (ScatterBackend + `ScatterBandConfig` + dispatch), U1 (scatter materialisation ride-through), U2a/U2b (2 defs + 2 components). This is the *third backend* + the *ranged threat axis* — paid once.
- **Marginal cost of band 4 *as a band* (what U3 measures):** **predicted 0 lines of production code** — `3 .tres` files + `1` contract test (a clone of `test_band_three_profile.gd`) + inline `DeckEntry` data.

**The N=3 trend UG3 judges:**

| Band | Backend | Marginal production-code cost | Footprint |
|---|---|---|---|
| band 2 (M1.9 S7) | socket (reused) | **1 glue line** (`geo.tile_set = profile.tileset`) + a `palette_tint` schema field | 3 `.tres` + 1 test |
| band 3 (M1.10 T3) | cave (2nd backend) | **0** | 3 `.tres` + 1 test |
| **band 4 (M1.11 U3)** | **scatter (3rd backend)** | **predicted 0** | **3 `.tres` + 1 test** |

If U3's actual worklog matches (3 `.tres` + 1 test, zero production lines), the thesis — *"once a backend exists, adding a band on it costs the same as any other band: data only; content = data is compounding"* — is proven on evidence across **three generations of generator**. The risk to the prediction is a U0/U1 seam that leaks into U3 (a `ScatterBandConfig` field not yet on the schema, a scatter `validate()` field demand, or the long-sightline bar needing a config knob U3 must add); those are the **coordination notes in §7** precisely so they're caught in U0/U1, not paid by U3.

---

## 6. Definition of done (acceptance)

1. **Deterministic:** `BandPipeline.new().generate(band_four, seed)` twice → byte-identical `fingerprint()` + `floor_fingerprint()` across the matrix; different seeds → variety.
2. **Connectivity + sightline:** `is_fully_connected` on every seed (cover never disconnects); the long-sightline identity bar (C11) green on the authored config.
3. **FOUR controls untouched:** `band_greybox`, `band_two`, AND `band_three` fingerprints byte-identical across the matrix; all-off `RunConfig` fp `e943ac9c8bc1` unmoved (U3 adds no knob).
4. **Profile loads + validates:** C0 passes (id/backend/band_depth/empty-flavors/scatter-config/tint/deck-ids/bomb-wrapper); `validate()` clean on the scatter branch (depends on U0's scatter `validate()`).
5. **Deck spawns the deterministic outcome:** through the `EncounterBuilder` at the 34-credit budget, the deck spends to `lobber/sentry/charger/bomb = 5/5/4/1 = 15` (finalized against shipped `lobber`/`sentry` — §4.3), budget exactly 0; `min_band 4` natives absent from bands 1/2/3.
6. **Visual identity present:** band 4 renders in its `palette_tint` (the scatter materialisation modulate); the three control bands render unchanged.
7. **Import + smoke green;** worklog names the real commit SHA(s) for the game-director-designer + environment-artist + general-purpose contributions, a **Bespoke-code ledger** (the §5.2 measurement — actual lines vs the 0-line prediction, and the measured junk band-total), and a Design deviations section.

---

## 7. Open Questions

Each states the trade-off. Vision/fun/tone/scope calls are flagged **needs Director review** with a recommendation; technical calls are fresh-eyes-resolvable on merit.

- **OQ1 — Band identity pick (= breakdown OQ3).** *(tone — needs Director review, D1)* Ship **Pitch A "The Far Field"** (GDD-canonical "Far," cold non-Euclidean-dark indigo, title-resonant), or the alternates **B "The Reliquary"** (bone-grey ossuary) / **C "The Threshing Floor"** (bleached void near-monochrome)? All three share the mechanical spec, so the pick doesn't gate the build (only `display_name`, `palette_tint`, and U4's portal prompt change). Portal glow is constrained to the deep-cold-blue family regardless of pitch (§3.1). **Rec: A.**

- **OQ2 — Supporting-draw pick (= breakdown OQ2 spillover).** *(fun — needs Director review, D2)* The recommended deck's supporting slot is `charger` (the cave's cast-off, alive in the open field's lanes) + a single `bomb` mine. Is that the right open-field supporting draw, or does the Director prefer `splitter` (geometry-agnostic, avoids a 3rd contact-lethal on top of the ranged pair) — or add `pingpong`/`spike` for density? **Rec: ship `[lobber, sentry, charger, bomb×1]`; the charger "same def, opposite band" story is the strongest identity evidence; swap to `splitter` only if the Director judges a lane-charger over-crowds the ranged showcase.**

- **OQ3 — Deck exclusivity (= breakdown OQ8).** *(design — recommendation, D3)* Keep `lobber`/`sentry` band-4-exclusive (`min_band 4` on their defs → clean four-band A/B)? **Rec: yes, exclusive for M1.11; let UG3 decide whether they graduate into shallower decks (e.g. a sentry in a socket band's corridors — a UG3 watch-item).** *Fresh-eyes-resolvable; surface to Director only if they want the natives shared now.*

- **OQ4 — Difficulty step size (= breakdown OQ11 spillover).** *(fun — needs Director review, D4)* `band_depth 4` yields a flat 34-credit budget (+9.7% credits over band 3). Is a whole band-4 apart *felt* at +9.7% over band 3, or should band 4 use a sharper step? **Rec: ship the locked 1.45 (fidelity to the +15%/band model) and let UG2 deaths-by-band / time-to-gate tell the Director whether to widen — don't pre-tune.**

- **OQ5 — `ScatterBandConfig` schema coordination (= breakdown OQ4/OQ9 technical).** *(technical — fresh-eyes + U0 coordinate)* §3.3/§4.2's field list is written against the breakdown's *stated* schema (arena extents, `cover_density`, `min_cover_spacing`, `cover_size_mix`, `edge_cover_bias`, `clear_lane_width`) + the assumed cave-idiom chunking fields (`chunk_cells`, `min_floor_cells`, `max_attempts`, `cell_size_px`). **This must be re-based onto U0's *landed* schema at build (the exact T3 OQ5 situation — its cave config was re-based onto T0's real field names, `nook_roughness` deleted).** Flags to U0: (a) confirm `ScatterBandConfig` exposes `chunk_cells` (or its equivalent) so the depth axis chunks — an unchunked arena zeros the depth economy; (b) confirm the exact unit/type of `cover_density`, `cover_size_mix`, `edge_cover_bias` so the sparse-leaning values map correctly; (c) confirm the sparse `cover_density 8` satisfies U0's long-sightline identity bar (my sparse choice *supports* it; a dense choice might fail it). **Resolution: U0 sanity-runs the authored value set on the seed matrix and reports region/sightline/`max_depth` so U3's authoring starts from measured shape. Any field U0 does not provide is a flagged coordination item, not a silent U3 add.**

- **OQ6 — Exposed-center loot-value bias — data or watch-item?** *(design — recommendation)* The exploration's exposed-center high-value read (§3.7) is only *half* expressible: `edge_cover_bias` makes the center geometrically exposed, but `JunkPlacer` scatters loot value by depth uniformly and cannot bias *value* to the center. **Rec: ship the geometry (rim-biased cover → exposed center) now; log "JunkPlacer `exposure_value_bias`" as an M2 candidate; carry the felt read as a UG2/UG3 watch-item.** *Fresh-eyes-resolvable; not a build blocker.*

- **OQ7 — Native cost/cap coordination targets (= breakdown OQ11 technical).** *(technical — coordination with U2a/U2b)* §4.3's `5/5/4/1 = 15` pin assumes `lobber credit_cost 3 / per_band_cap 5` and `sentry credit_cost 2 / per_band_cap 5`. U2a/U2b own the real values (their Phase-2 designs — not yet authored). **Resolution: flag these targets at U2a/U2b brief so the 34-credit budget yields the intended ranged-dominant field; the contract test's `EXPECT_SPAWNS` is finalized against the *shipped* defs (the T3 precedent — its `6/3/4/1` was pinned against shipped ambusher/burrower). If they ship different values the deck still spends validly (self-limiting); only the counts + the pin constants shift.** *No Director call.*

- **OQ8 — Reward curve tier ceiling / tier-6 loot (mirrors T3 OQ8).** *(design — recommendation, D5)* §3.5 lifts band 4 to value 1.45→2.9, floor tier **4** / ceiling 5 (the junk pool tops at tier 5), density re-based to ~1.0→1.4 per chunk-piece (band-total ~55-75). The GDD's literal Band-4 loot is "reality-warping treasures / lore cores" (tier-6+ flavored), which the shared pool has none of. **Rec: ship the value 1.45→2.9, tier 4→5 curve now; log "author tier-6 reality-warping / lore-core JunkItems" as an M2 content follow-up.** *Fresh-eyes-resolvable; surface to Director only if they want band-4 loot held flat until the full I→loot coupling.*

- **OQ9 — Does band 4 need its own junk table, or reuse the shared catalog?** *(scope — recommendation)* Band 3 reused `junk_catalog.tres` (only the `depth_curve` is band-specific). **Rec: reuse the shared `junk_catalog.tres` — no new junk items are in M1.11 scope, and the band-4 identity is carried by the reward-lifted `depth_curve_band_four.tres` (value + tier floor), not by a bespoke catalog. A dedicated band-4 catalog is deferred with the tier-6 content (OQ8).** *Confirm; no Director call unless tier-6 content is pulled forward.*

- **OQ10 — Flavors EMPTY confirm (the cave rule carries).** *(scope — confirm)* §3.6 argues `flavors = []` is *mechanically mandatory* — U0's scatter `validate()` must fail-loud on non-empty flavors (mirroring the shipped cave branch, `band_profile.gd:108-109`). **Rec: confirm EMPTY; flag to U0 that the scatter `validate()` branch owns the fail-loud (the single-location rule).** *Confirm + U0 coordination; no Director call.*

---

## Director review queue (vision / tone / fun — NOT self-resolved)

Sharpened to one-line decisions with a recommendation. None gate the build's *mechanics* (all pitches share §3.2–§3.6); they shape identity/feel and can be dispositioned at the Wave-3 close-out.

- **D1 — Band identity pick (OQ1).** Ship **Pitch A "The Far Field"** (GDD-canonical "Far," cold non-Euclidean-dark indigo `Color(0.42, 0.46, 0.62)`, title-resonant, deep-cold-blue portal), or **B "The Reliquary"** / **C "The Threshing Floor"**? **Rec: A.**
- **D2 — Supporting draw (OQ2).** Ship `[lobber, sentry, charger, bomb×1]` → deterministic `5/5/4/1 = 15`, with `charger` (the cave's cast-off) as the open-field spice? Or swap to `splitter`? **Rec: ship charger** (strongest identity story); swap only if a 3rd contact-lethal over-crowds the ranged showcase.
- **D3 — Native exclusivity (OQ3, ratify).** `min_band = 4` keeps lobber/sentry band-4-exclusive (clean four-band A/B). **Rec: yes**; UG3 decides graduation.
- **D4 — Difficulty step (OQ4).** Locked 1.45 → 34 credits (+9.7% credits over band 3). **Rec: ship 1.45**; UG2 evidence drives any widening.
- **D5 — Reward curve (OQ8, confirm).** Value 1.45→2.9, tier floor 4 / ceiling 5, density re-based to ~1.0→1.4 per chunk-piece (band-total ~55-75; prevents the 3-4× loot flood the chunk partition would otherwise cause); tier-6 "reality-warping / lore-core" items logged as M2 content. **Rec: confirm as specified.**

---

*Spec authored by game-director-designer for M1.11 U3. Design + data-spec only — no game code; the `.tres` values here are authored during U3's build. The contract test is a retargeted clone of `test_band_three_profile.gd`. Coordination seams (OQ5 scatter-config schema, OQ7 native costs, OQ10 scatter-validate) are flagged to U0/U2a/U2b so U3's marginal cost stays at the predicted zero production lines — the N=3 headline. Deviations go to `DESIGN_DEVIATIONS.md` for the Wave-3 close-out sweep. OQ1/OQ2/OQ4/OQ8 need the Director; OQ3/OQ5/OQ6/OQ7/OQ9/OQ10 are fresh-eyes/coordination-resolvable.*

---

## Resolved Decisions (Phase 3) — BINDING

> Fresh-eyes resolution, 2026-07-06 (resolver ≠ Phase-2 author), per the four-phase authoring
> process. Every claim below was re-verified against the working tree at resolution time:
> `encounter_builder.gd` (`instability` `:64-65`, budget `:299` = `int(floor(24·instability))`,
> `min_band` filter `:302`, entry-piece exclusion `:313-314`, per-piece demand `:330-334`,
> `n_plan = mini(demand, budget / credit_cost, per_band_cap)` with GDScript **integer** division
> `:336-340`, spend-stop `:355-356` — the def loop `break`s at `budget <= 0` and otherwise simply
> ends, so a **non-zero stranded remainder is legal**), `deck_entry.gd`, `junk_placer.gd`
> (per-piece `expected_count`, `loot_density_per_area` OFF), the shipped `charger.tres`
> (`cost 2 / room 1 / band 4 / base_count 1 / min_band 2`), `splitter.tres` (`cost 3 / room 2 /
> band 8 / base_count 1`), `bomb.tres` (`cost 1 / room 0 / band 0 = uncapped / base_count 0`),
> `band_three.tres` (+ its `deck_entry_bomb` SubResource), `depth_curve_band_three.tres`,
> `cave_config_band_three.tres` (56×56, `chunk_cells 8`), and the three **Wave-A Phase-3
> resolutions that postdate this doc's body and BREAK several of its assumptions**: U0 §10
> (RD-5/8/10/11/12/13), U2a's Resolved Decisions (the credit-cost seam), U2b's Resolved Decisions
> (A4). Where this section contradicts the body above, **this section wins**; the vision/fun/
> tone/scope items carry recommendations and sit in the updated Director queue at the end.

### The re-based deck pin (supersedes §3.4's cards, §4.3's arithmetic, C6, and DoD 5)

**RD-1 — Final native cards (settled upstream; the body's targets are DEAD).** U2a's Phase-3
settled **lobber `credit_cost 2 / per_room_cap 1 / per_band_cap 5`** (cost 3 was rejected on the
roster's threat-per-credit ladder: charger/ambusher/burrower = 2; splitter's 3 buys
self-multiplication; an always-visible, always-throw-killable static sheller sits at 2). U2b's
Phase-3 settled **sentry `credit_cost 2 / per_room_cap 1 / per_band_cap 5`** (cap raised 4→5).
The body's "lobber 3/5" assumption (§3.4, §4.3, OQ7) is overridden. **Cross-doc note:** U2b A4's
closing claim that "the `5/5/4/1 = 15` pin holds exactly" was computed against the pre-U2a
lobber-cost-3 assumption and is superseded; **this section's pin is the canonical deck outcome.**
*Binding.*

**RD-2 — The recomputed deterministic deck pin: `lobber 5 / sentry 5 / charger 4 / bomb 6 = 20`,
spending the 34-credit budget exactly to 0.** Budget: `instability(4) = 1.0 + 0.15·3 = 1.45` →
`int(floor(24 · 1.45)) = int(floor(34.8)) = 34` (re-confirmed against `encounter_builder.gd:64,
:299`; the 27/31 band-2/3 controls verify the same rounding). Eligible pieces on the authored
64×64 / `chunk_cells 8` arena: 8×8 = 64 chunk-pieces, minus the entry piece (`:313-314`) →
**P ≈ 63** (sparse cover ⇒ every chunk holds valid floor; the body's "40-60" and U0-default "~34"
figures both re-based). Demand per def = `base_count 1 · P ≈ 63` — never binds. The walk, in
authored order, against the final cards:

```
budget 34 → lobber  n=min(63, 34/2=17, 5)=5   (spend 10, budget 24)
          → sentry  n=min(63, 24/2=12, 5)=5   (spend 10, budget 14)
          → charger n=min(63, 14/2= 7, 4)=4   (spend  8, budget  6)
          → bomb    n=min(63,  6/1= 6, ∞)=6   (spend  6, budget  0)
          = 5 + 5 + 4 + 6 = 20 spawns, budget spends EXACTLY to 0
```

Credit check: `5·2 + 5·2 + 4·2 + 6·1 = 10 + 10 + 8 + 6 = 34`. Determinism/satisfiability: the
bomb's `DeckEntry{base_count: 1}` demand is per-eligible-piece (Σ = 63 ≥ 6), so **the budget
remainder — not the wrapper — sets the count**: the bomb row is a *remainder sponge* (U2a's
structural fact (i)); with every cost-2 def spending in even increments off an even budget, the
remainder is always even — **no exactly-one-bomb pin is reachable at these cards** (U2a's fact
(ii)). Each capped def's even-spread placements (`round(i/(n−1)·62)` → lobber {0,16,31,47,62},
sentry idem, charger {0,21,41,62}, bomb {0,12,25,37,50,62}) are distinct pieces per def, so
`per_room_cap 1` (per-def, per-chunk) never refuses; `&"new_hazards"` ceiling 48 ≫ 20. The plan
is refusal-free and deterministic on every seed. *Binding.*

**RD-3 — Alternatives worked and rejected (the bomb row STAYS).** The four real options at 34:
- **(a) Keep the bomb row → `5/5/4/6 = 20`, spend-to-0 — CHOSEN.** Six always-visible static
  mines even-spread across ~63 chunks (~1 per 10 chunks) *punctuate* the open crossing without
  adding chase bodies; the exposed-crossing "watch where you step" read (b1) is *served*, not
  crowded; the deck stays a byte-shape clone of `band_three.tres` (natives + supporting def +
  bomb `DeckEntry`) — the compounding pattern §4.1 sells; and the budget spends to exactly 0,
  preserving the D-RAT-6-style pin and the full +45% difficulty step.
- **(b) Drop the bomb row → `5/5/4 = 14`, 6 credits stranded — REJECTED.** Legal (the lane
  tolerates a non-zero remainder; the test would pin 14 spawns + `remaining == 6`), but band 4
  would *spend* 28 credits vs band 3's 31 — the deepest band fielding **less** than band 3,
  inverting the difficulty ladder for nothing.
- **(c) Splitter variants — REJECTED.** Alongside charger (`[lobber, sentry, charger, splitter]`):
  `5/5/4/2 = 16`, spend-to-0 (`10+10+8+6`) — clean, but 2 splitters (→ up to 6 chase bodies on
  death) are geometry-agnostic filler that dilutes the ranged showcase and loses the
  exposed-center mine spice. In place of charger (`[lobber, sentry, splitter, bomb]`):
  `5/5/4/2 = 16` (`10+10+12+2`) — loses the "cave's cast-off, alive in the open field" identity
  story (§2.4), the deck's strongest evidence. No uncapped cost-2 sponge exists in the roster
  (charger/ambusher/burrower are all band-capped), so cost-1 `bomb` remains the only universal
  remainder-soak; these stay Director alternates under D2, not the recommendation.
- **(d) Change the budget — REJECTED STRUCTURALLY.** `band_depth` is locked at 4 by the
  breakdown → 34 is locked; `ScatterBandConfig` does not feed the budget.
**C6 and DoD 5 re-base to `EXPECT_SPAWNS = {lobber: 5, sentry: 5, charger: 4, bomb: 6} = 20`,
budget exactly 0**, finalized (per the §4.3 caveat, unchanged) against the *shipped*
`lobber.tres`/`sentry.tres`. The deck-mix *aesthetics* — ranged dominance now 10/20 = 50% of
spawns (vs the dead pin's 67%), 6 mines on an open field — go to the Director inside the deck
bundle (breakdown OQ11 → D2 below). *Binding arithmetic; composition Director-ratified.*

### The re-based scatter config (supersedes §3.3/§4.2 — U0 RD-11 is the canonical schema)

**RD-4 — `scatter_config_band_four.tres` re-authored on the LANDED schema (OQ5 CLOSED).** U0
RD-11 (binding) renames/retypes the body's assumed fields and **deletes two**; RD-5 drops the
retry scaffold; RD-8 clamps; RD-12 confirms the sparse point. The authored instance:

| Canonical field (U0 RD-11) | Value | Was (§4.2) | Note |
|---|---|---|---|
| `grid_width` | **64** | `arena_width 64` | `chunks_x = ceil(64/8) = 8 ≥ 5` — passes RD-8's depth clamp. |
| `grid_height` | **64** | `arena_height 64` | ≥ 12 ✓. |
| `cover_density_pct` | **8** | `cover_density 8` | integer **percent** per-stratum stamp chance; RD-12 confirms 8 sits in the identity-compatible sparse range `[5, 40]`. |
| `min_cover_spacing` | **4** | 4 | ≥ 3 clamp ✓; Chebyshev; stratum side `s = 6` → cover ≤ 4/36 ≈ 11% of interior by construction (RD-4/RD-6). |
| `border_margin` | **2** | *(absent)* | new mandatory field, at default. |
| `cover_w_1x1 / 2x1 / 1x2 / 2x2` | **4 / 1 / 1 / 1** | `cover_size_mix [4,2,1]` | RD-11's own suggested small-biased mapping of U3's intent (sum 7 ≥ 1); rare 2×2 wrecks vs U0's default 4/2/2/3. |
| `edge_cover_bias_pct` | **60** | `edge_cover_bias 60` | integer percent, positive = rim (RD-17 two-zone) → exposed center. |
| `clear_lane_width` | **3** | 2 | re-pinned to U0's tested default: the lane is the S11(a) identity row-set and the guaranteed crossing; at 16 px cells a 3-wide (48 px) lane honestly clears the 28 px player body + the sentry-corridor read, and buys this at ~zero cover cost (lane rows admit no cover either way). 2 was legal; the body's cave-parity rationale is weaker than staying on the tested point. |
| `chunk_cells` | **8** | 8 | confirmed on the schema (RD-11) — OQ5(a) answered; 8×8 = 64 chunks, `max_depth ≥ chunks_x − 1 = 7 ≥ 4`. |
| `cell_size_px` | **16** | 16 | ✓. |
| ~~`min_floor_cells`~~ | **DROPPED** | 500 | not on the schema (RD-5 — no retry/undershoot mode exists). |
| ~~`max_attempts`~~ | **DROPPED** | 8 | idem. |

U0's standing offer (RD-12) holds: it sanity-runs this authored set on the seed matrix and
reports region/sightline/`max_depth` at U3 build time. Any residual mismatch at build is a
flagged deviation, not a silent U3 edit. *Binding; closes OQ5.*

**RD-5 — Contract-test re-base (C0/C3/C6).** **C0:** the scatter-config field checks assert the
RD-4 table (canonical names; no `min_floor_cells`/`max_attempts`). **C3** ("total floor cells ≥
`min_floor_cells`") is **replaced** per U0 RD-11's instruction: assert the RD-4 integer
cover-budget bound **`cover_cells · (min_cover_spacing + 2)² ≤ 4 · interior_cells`** (⇒ floor ≥
(1 − 4/36) ≈ 89% of the interior at spacing 4 — integer, non-flaky, by-construction) **plus**
`pieces.size() >= 2`; optionally pin the exact per-seed floor count measured at build as golden
constants (RD-11's alternative — programmer's call, both are stable). **C6:** the RD-2/RD-3 pin
(`5/5/4/6 = 20`, budget exactly 0). C1/C2/C4/C5/C10/C11 stand as written (C11's threshold: N is
U0's ratified S11 tiering — assert the S11(a) extents-independent form, some row run
`== grid_width − 2 = 62`). *Binding.*

### Identity, curve, and the remaining OQs

**RD-6 (OQ1/D1) — Identity pitch: NEEDS DIRECTOR REVIEW; recommendation Pitch A "The Far Field",
ENDORSED — with the portal glow PINNED to `Color(0.15, 0.25, 1.0)` (saturated indigo).** The
body's §3.1 glow analysis was directionally right (deep-cold-blue family) but pre-dated U4's
Phase-3 feasible set; per the U4 §2.5 seam (U4 owns the set, U3 picks within it), the pick is
now pinned to **one exact value from U4's two-candidate shortlist**: **`Color(0.15, 0.25, 1.0)`
saturated indigo/ultramarine** (renders ≈ (0.11, 0.08, 1.0) — deepest free render, max
separation from portal 1's violet and portal 3's teal; U4's own recommendation), gate wash ≈
`Color(0.55, 0.62, 1.0)`. §3.1's illustrative `Color(0.28, 0.42, 1.0)` is superseded. The
feasible alternate, if the Director rejects a third blue-family glow, is U4's option 2
**magenta-fuchsia `Color(1.0, 0.0, 0.55)`** (renders (0.76, 0.0, 0.55); riskier — portal 1's hue
neighbor). All three pitches share the pinned glow; the Director eyeballs all four glows together
at UG1 (U4's noted risk). **One bundle to ratify: name + `palette_tint` + this glow.** *Rec: A +
indigo.*

**RD-7 — `palette_tint` stands as authored per pitch:** Pitch A `Color(0.42, 0.46, 0.62, 1)`
(B/C values as tabled). Tint and portal glow are separate channels (the T3 correction-5
precedent); the D1 pick governs `display_name` + `palette_tint` only; U4 stamps the pinned glow.
*Confirmed.*

**RD-8 (OQ2/D2) — Supporting draw: NEEDS DIRECTOR REVIEW; recommendation `[lobber, sentry,
charger, bomb(DeckEntry)]` ENDORSED, now yielding `5/5/4/6 = 20`.** The charger "same def,
opposite band" story survives the recompute untouched (still 4, still the frozen 2/4 card). What
changed and needs the Director's eye inside the OQ11 bundle: the bomb row is now **6 mines, not
1** (RD-2/RD-3) — the "single exposed-center mine" framing in §3.4 becomes "a sparse minefield
punctuating the crossing," and ranged dominance is 50% of spawns (10/20) rather than 67%.
Resolver's read: 6 static, always-visible, cost-1 mines on a 64×64 flat *strengthen* the
open-field "read the ground" identity and are the honest price of the natives' cheaper final
cards; the splitter alternates (RD-3c) remain the swap if the Director judges mines-as-filler
off-tone. *Rec: ship as recomputed.*

**RD-9 (OQ3/D3) — Native exclusivity: RESOLVED-ENDORSED, `min_band = 4` both natives,
band-4-exclusive for M1.11.** Structural (deck filter `:302`), cheap to lift later (one field +
a deck add — U2a OQ-7's verified promotion path). **Disposition jointly with U2a OQ-7 and U2b
OQ-5 — one Director verdict, three docs** (U2b's own request). Surface to the Director only as
that joint ratification; the working assumption for the build is exclusive. *Rec: yes.*

**RD-10 (OQ4/D4) — Difficulty step: NEEDS DIRECTOR REVIEW (ratify); recommendation ENDORSED —
ship the locked 1.45 → 34.** Resolver addition: RD-3(a) is load-bearing here — keeping the bomb
sponge means band 4 actually *spends* all 34 credits (vs 31 in band 3); option (b) would have
quietly shrunk the felt step to below band 3's. UG2 deaths-by-band / time-to-gate is the widening
evidence. *Rec: ship 1.45.*

**RD-11 (OQ8+OQ9/D5) — Reward curve: value 1.45→2.9 and tier floor 4 → ceiling 5 CONFIRMED;
density RE-PINNED to `1.0 → 1.2` per chunk-piece (was 1.0→1.4) on the corrected piece count.**
The body's density arithmetic used "~40-64 pieces"; the authored arena emits **~64 junk-bearing
chunk-pieces** (8×8; sparse cover keeps every chunk floored — vs U0's default-arena ~34 figure,
which corrects the *deck* estimate, not this one). At 1.0→1.4 (mean ≈ 1.2) that is ~77 items —
overshooting the stated ~55-75 band-total and nearly doubling band 3's measured ~45-60 target on
*count*, contradicting the body's own "escalation carried by value + tier floor, not raw count."
**`density_curve = 1.0 → 1.2`** (mean ≈ 1.1 → band-total ≈ 70, inside target). Endpoints stay
integration-tunable against the measured plan-size; the worklog records the measured band-total
(TG2 rule: compare band-total *value*). Tier-6 "reality-warping / lore-core" items stay an M2
content follow-up; the shared `junk_catalog.tres` is reused (OQ9 CONFIRMED — no bespoke catalog).
*Rec to Director: confirm as re-pinned.*

**RD-12 (OQ6) — Exposed-center loot-value bias: RESOLVED as recommended.** Ship the geometry
half (`edge_cover_bias_pct 60` → exposed center); log **"JunkPlacer `exposure_value_bias`" as an
M2 candidate**; carry the felt push-or-cash-out read as a **UG2/UG3 watch-item**. Confirmed
against `junk_placer.gd`: placement is depth-on-`floor_cells` with no center/edge notion —
half-expressibility is real, not a config gap. *Binding (not a build blocker).*

**RD-13 (OQ7) — Native cost/cap coordination: CLOSED, inverted.** The body flagged targets *to*
U2a/U2b; both have since resolved their cards (RD-1) and the dependency now runs the other way —
U3 re-bases (done, RD-2). Nothing remains open; the §4.3 finalize-against-shipped-defs caveat
stands as the build-time safety net. *Closed.*

**RD-14 (OQ10) — Flavors EMPTY: CONFIRMED, mechanically mandatory.** U0 RD-10 (binding) fail-louds
the scatter `validate()` branch on non-empty flavors, does **not** require `piece_pool`, and
warn-ignores `archetype` — all three §3.2 coordination notes answered exactly as the body hoped.
`flavors = []` ships; the test asserts it. *Closed.*

**RD-15 — Cost-ledger prediction unchanged.** Nothing in this resolution adds production code:
every re-base lands in the 3 `.tres` + the mirrored test. The 0-line N=3 prediction (§5.2)
stands. *Confirmed.*

### NEEDS DIRECTOR REVIEW — updated queue (supersedes the body's D1–D5 table)

| # | Question | Recommendation |
|---|---|---|
| D1 | Band identity: **A "The Far Field"** / B "The Reliquary" / C "The Threshing Floor" — one bundle: name + `palette_tint` + **portal glow `Color(0.15, 0.25, 1.0)` indigo** (alternate: magenta `Color(1.0, 0.0, 0.55)`) | **A + indigo**; eyeball all four glows at UG1 |
| D2 | Deck mix at the recomputed pin **`lobber 5 / sentry 5 / charger 4 / bomb 6 = 20`** (spend-to-0; 50% ranged; 6 mines) — or a splitter alternate (RD-3c: `5/5/4/2 = 16` either shape) | **Ship as recomputed** (mines serve the read-the-ground identity; charger story intact) |
| D3 | Natives band-4-exclusive (`min_band 4`) — joint verdict with U2a OQ-7 / U2b OQ-5 | **Yes, exclusive**; UG3 decides graduation |
| D4 | Difficulty step: locked 1.45 → 34 credits, fully spent | **Ship 1.45**; UG2 evidence drives widening |
| D5 | Reward curve: value 1.45→2.9, tier floor 4 / ceiling 5, **density re-pinned 1.0→1.2** (~70 items band-total on ~64 pieces); tier-6 loot = M2 | **Confirm as re-pinned** |

Everything else above is resolved on technical merit and **binding on the Wave-3 build**: the
`5/5/4/6 = 20` spend-to-0 pin (RD-2), the bomb-row keep (RD-3), the RD-11-canonical scatter
config with `clear_lane_width 3` and no retry fields (RD-4), the C0/C3/C6 test re-bases (RD-5),
tint/glow channel split with the pinned indigo glow (RD-6/7), density 1.0→1.2 (RD-11, pending
D5), the OQ6 watch-item (RD-12), and the OQ7/OQ10 closures (RD-13/14).
