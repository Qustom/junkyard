# T3 — New Band: `band_three.tres` (cave profile + deck + tint + identity) — Expanded Design Spec

**Milestone:** M1.10 (Second-Gen Backend + Cave Band + Low-Sightline Oppositions) · **Workstream:** the scalability *measurement* itself · **Wave:** 3
**Task id:** T3 · **BlockedBy:** T0 (CaveBackend + `CaveBandConfig` + pipeline dispatch), T1 (cave materialisation + backend-agnostic sealing), T2a (`ambusher.tres` + Concealment), T2b (`burrower.tres` + BurrowCycle)
**Assignees:** game-director-designer (profile / deck / curve / pitches — this spec) · environment-artist (palette tint direction) · general-purpose (glue-if-any + contract test)
**Author:** game-director-designer · **Status:** spec (Phase-2 per-task design; `## Open Questions` in §7 for Phase-3 fresh-eyes + Director)

> **What this doc is.** Per CLAUDE.md's four-phase authoring, this is T3's Phase-2 design: the premise research against the real as-built (§2), the buildable data spec (§3), the field-by-field data + test sketch (§4), and the explicit `Open Questions` (§7). It ships **no game code** — the `band_three.tres` value table here is authored as the actual `.tres` during T3's build; the contract test is a near-verbatim clone of the shipped `test_band_two_profile.gd`. **T3 is the headline scalability measurement of M1.10:** its worklog carries the *marginal* cost ledger — how much bespoke (non-data, non-test) code adding band 3 actually needs, given T0/T1/T2a/T2b landed. The engineered answer this spec targets is **zero production-code lines** (§5.2) — pure data + one mirrored test — which, if it holds, is the evidence TG3 judges the "content = data" claim on for a *second, differently-generated* backend.

---

## 0. Hard constraints (read first — straight from the M1.10 breakdown)

The spec must not violate these, and neither may the `.tres` authored from it:

- **Three permanent controls stay byte-identical.** Authoring `band_three` must not edit `band_greybox.tres`, `band_two.tres`, their `bandgen_config*.tres`/`depth_curve*.tres`/tilesets, or any shipped `OppositionDef` default. The all-off `RunConfig` fingerprint **`e943ac9c8bc1`**, `band_greybox`'s fingerprint, and `band_two`'s fingerprint (both through the untouched socket path) are all controls (breakdown §Scope guardrails, §Cross-cutting contracts). T3 adds **no** `RunConfig` knob.
- **Cave code is reachable only through `backend == "cave"`.** `band_three` is the *first* profile to carry `backend = "cave"`; every socket band's path is untouched. The cave backend/materialisation/validate branch are T0/T1 deliverables — T3 only *authors data that selects them*.
- **Determinism (non-negotiable).** `BandPipeline.new().generate(band_three, seed)` twice with the same seed → **byte-identical `Band.fingerprint()` AND `floor_fingerprint()`**; different seeds → variety. All cave iteration is order-stable (sorted flood regions, fixed cell scan) and connectivity repair is **deterministic CARVE** — T0's contract, which T3's test re-asserts on the *authored* config.
- **No new opposition machinery.** The deck references `&"ambusher"`/`&"burrower"` (T2a/T2b) + shipped def ids by string; T3 authors the ordered array + any `DeckEntry` wrappers only. No `EncounterBuilder` edit.
- **M1 lethality model holds.** Every deck entry is a `kills`-gated, emit-always M1 Actor/fixture. No HP pool, no Field/zone/DoT hazards.
- **No save-schema change; third portal is T4, not T3.** `band_three` persists nothing; it is regenerated from its seed. Routing (`BAND_ROUTES` + hub portal) is T4.
- **Flavors ship EMPTY.** `SetPieceInject`/`WearDecay` are socket-coupled (append-to-open-socket / block-or-breach socket doorways) — inapplicable to synthetic cave pieces (§3.6, OQ-flavors). The cave *is* the flavor.
- **Placeholder art tint-only** (`palette_tint` tier-1, D-RAT-4 precedent). No PixelLab without an explicit Director gate; pixel filter OFF; copy-not-move from `art_workshop/`.

---

## 1. Goal & design intent

**One sentence:** *A third, deeper dive band that exists almost entirely as data — a tuned cellular-automata cavern (nook-rich, bad sightlines, grown-not-built) in a cold "impossible-color" tint, `band_depth = 3` (→ 1.30 instability budget), stocked with the two low-sightline natives plus a small cave-fit supporting draw — proving the M1.9 machinery scales to a genuinely different generator with ~zero marginal engineering.*

T3 is the payoff of M1.10's thesis. T0 built a second backend; T1 made a socketless cave playable; T2a/T2b added two oppositions that *need* bad sightlines. **T3 is where those parts have to earn their keep as data**: a band that reads as a different *reality* (per the GDD's Band-3 "Lateral"), assembled from a `CaveBandConfig` + a `band_depth` + a deck array + a tint — no new generation code. The watch-item TG3 judges is exactly this: *how much bespoke code did T3 actually need beyond T0/T1/T2a/T2b?* The answer this spec is engineered to deliver is **none** (§5.2).

**Design feel target (for the Director's sweep, not a balance claim):** band 3 should read as *"you've left the yard behind — this place grew, and it hides its teeth."* Blobby chambers you can't see across; a dense fringe of nooks that could each hold a pounce; a descent whose "way home" is felt, not sighted, so every chamber is a "sweep it or run?" bet. The +30% opposition budget (1.30 vs band 1's 1.00) plus two natives that weaponise the low legibility make the step over band 2 *felt*. Whether that step is *right* is a TG2/TG3 playtest call — T3 ships a coherent starting point, not a tuned one.

---

## 2. Research — what band 3 is, and what T3 actually needs

### 2.1 What the GDD makes band 3 (`band_depth = 3`)

The GDD escalation table (`design/Junkyard_GDD.md:59`) names band 3 canonically:

> **Band 3 — Lateral** | A junkyard from another *reality* | Physics slightly off, alt-history detritus, things that were never made here | **Anomalous items, paradox parts** | **High; reality instability**

And the art pillar (`:185`): *"the depths shift palette by band — familiar grime → desaturated nostalgia → **impossible color** → non-Euclidean dark."* Band 1 (greybox) = familiar grime (neutral white tint); band 2 ("The Sump") = desaturated nostalgia (sepia-amber `Color(0.82, 0.66, 0.42)`, as shipped in `band_two.tres:72`); **band 3 = the "impossible color" step** — a cold, off-key hue that reads as *another reality*, not another decade.

The organic-caverns exploration (`design/explorations/.../b3-organic-caverns.md`) independently places this archetype at *"a deeper / alien band (Band 2+)… where the fiction has already left the built junkyard behind"* and describes it as *"grown, not built — natural or alien rather than the machined corridors of the surface."* **These agree:** the CA cavern (blobby, no straight lines, grown) *is* the visual grammar of the GDD's "Lateral / another reality." The pitches in §3.1 fuse them.

### 2.2 What `band_depth = 3` means for the budget (as-built, exact)

The single budget scalar is the shipped static `EncounterBuilder.instability(band_depth)` (`systems/spawning/encounter_builder.gd:64`):

```gdscript
static func instability(band_depth: int) -> float:
    return 1.0 + 0.15 * float(band_depth - 1)
```

So `instability(1) = 1.00` (band 1 baseline), `instability(2) = 1.15` (band 2), **`instability(3) = 1.30`** (band 3). The deck-lane credit budget is computed once per band (`_populate_deck`, `:299`):

```gdscript
var budget: int = int(floor(float(BASE_CREDITS) * instability(band_depth)))
# band 3:  floor(24 * 1.30) = floor(31.2) = 31 credits
```

**Band 3 gets a flat 31-credit deck budget** (`BASE_CREDITS = 24`, `:38`). This is +30% over band 1 and +13% over band 2 (27). It is the *only* difficulty lever `band_depth` pulls in M1.10 — the full I→stats→loot coupling stays M2 (the docstring at `:59` says so). Whether +30% is a *felt* whole-band step is a TG2 telemetry call, not something T3 pre-tunes (OQ2).

### 2.3 How the deck lane actually spends — the load-bearing mechanic for the supporting draw

Reading `_populate_deck` (`encounter_builder.gd:297-370`) and the shipped def params (`data/oppositions/*.tres`) surfaces a fact that **governs the whole deck design**:

1. **Draw = authored array order, id-deduped. `spawn_weight` is RESERVED / INERT this version** (`:22`, `:276`). So a "weight" column is *documentary future intent only* — **the array order is the priority list**, and the earlier a def sits, the earlier it gets first call on the budget.
2. **A def only spawns if its effective `base_count`/`count_per_depth` demand is > 0.** Per-def demand is `sum over eligible pieces of (base_count + floor(count_per_depth * depth_index))` (`:331`). If that's `0`, the def is a *neutral card — skipped, no spend* (`:333`).
3. **The 4 shipped hazards all ship `base_count = 0`** (`pingpong.tres`, `bomb.tres`, `spike.tres` params `base_count = 0, count_per_depth = 0`; `pursuer.tres` has no `base_count` key → `.get("base_count", 0) = 0`). **Therefore a shipped hazard placed plainly in a deck spawns NOTHING.** In `band_two`'s deck the only defs that actually spawn are `charger` (`base_count = 1`) and `splitter` (`base_count = 1`); the 4 shipped rows are inert padding that only the *legacy* lane (band 1) drives via `rc.h*_base_count`.
4. **The lever to make a shipped hazard live in a deck is a `DeckEntry` wrapper with a `base_count` override** — exactly what `band_two`'s charger row does for its two params (`band_two.tres:39-46`, `deck_entry.gd`). The override merges at ctx time with precedence `def params < deck-entry < rc.param_overrides` (`encounter_builder.gd:33`), and `base_count` is a valid schema key on `bomb`/`spike` (their `param_schema` lists it), so the params↔schema bijection stays green.

**Consequence for T3:** the two natives (`ambusher`/`burrower`) carry their own `base_count > 0` on their defs (T2a/T2b author that). Any *supporting* shipped hazard T3 wants to actually appear in band 3 must either (a) already carry `base_count > 0` (only `splitter` does, via its own def) or (b) be wrapped in a `DeckEntry` with a `base_count` override. This is a **zero-new-code lever** (S9 machinery, already shipped) — and it keeps the shared def defaults byte-identical, protecting the `band_two` control.

### 2.4 What T3 reuses as-is (the marginal-cost inventory)

Everything below is consumed unchanged — this is *why* band 3 is data, not engineering:

| Reused | Where | T3's use |
|---|---|---|
| Cave backend + `CaveBandConfig` schema + validate() cave branch | T0 (`systems/bandgen/`, `band_profile.gd`) | author a *tuned instance* of `CaveBandConfig` |
| Cave materialisation + socketless sealing + `palette_tint` apply | T1 (`main_game.gd`) | set `palette_tint`; T1 consumes it |
| `Band.fingerprint()`/`floor_fingerprint()` over synthetic pieces | T0 | test asserts determinism on the authored config |
| `DepthGrader` (BFS depth) + `JunkPlacer` (loot on `floor_cells`) | shipped, FLOOR-cell-only | consume cave floor unchanged |
| `EncounterBuilder` deck lane + budget + `min_band` gate + `DeckEntry` merge | `encounter_builder.gd` (S3/S9) | author the deck array + wrappers |
| `instability()` = 1.30 at depth 3 | `encounter_builder.gd:64` | drives the 31-credit budget from `band_depth = 3` |
| `DepthCurve` (value/density/tier curves) + `JunkCatalog` | shipped | author a reward-lifted `depth_curve_band_three.tres`; reuse shared `junk_catalog.tres` |
| `ambusher`/`burrower` defs + Concealment/BurrowCycle | T2a/T2b | reference ids in the deck |
| S4 generated Oppositions tab + IN-DECK chips | shipped, count-agnostic | pick up band 3's deck with **zero menu code** |

**Genuinely needed beyond a value in a `.tres` (the honest "not pure data" list):** *predicted **none** in production code* (§5.2). Contrast band_two (S7), which admitted one glue line (per-instance `geo.tile_set = profile.tileset`) + a `palette_tint` schema field. Band 3 needs neither: the tint field already exists (`band_profile.gd:71`) and T1 already wires the cave materialisation to consume it. T3's whole footprint is **3 `.tres` + 1 mirrored test**.

---

## 3. Design spec

### 3.1 Band identity pitches (Director picks — the tone call, breakdown OQ2)

Three pitches. **Pitch A honors the GDD's canonical Band-3 "Lateral"**; B and C are alternate tones offered because the breakdown makes name/fiction/palette a Director call. **All three share the identical mechanical spec (§3.2–§3.6)** — only name/fiction/palette/portal-glow differ, so the pick does not gate the build. Pitched the way "The Sump" was (one line of fiction + palette direction + portal-glow color).

| # | Name | One-line fiction | Palette direction (tier-1 tint) | Portal glow | Mood |
|---|---|---|---|---|---|
| **A ★ (canonical "Lateral", recommended)** | **The Warren** | *"Past the built yard the scrap stops being stacked and starts being **grown** — a reality a half-degree off true, where discards fused into cavern walls that were never manufactured."* | **Cold desaturated blue-violet** — greybox greys pushed toward a dim off-key violet, an "impossible color" creep (`palette_tint ≈ Color(0.62, 0.60, 0.78)`). GDD's "impossible color" step. | **Violet / magenta** (unmistakably the third, deeper portal vs band-1 neutral, band-2 amber). | Alien-organic, disoriented, wrong-but-quiet. The blobby chambers read as a place that *grew*. |
| **B** | **The Hollow** | *"A hollowed-out reality-pocket where the yard's discards fused into living rock; the walls remember shapes no factory ever pressed."* | **Deep desaturated blue-black** with a faint phosphor-green nook cast (bioluminescent cave). | **Sickly green.** | Cave-dread, bioluminescent, buried. Leans hardest into the "clear before you trust it" tension. |
| **C** | **Paradox Deep** | *"An alt-history stratum where the same object was thrown out a thousand contradictory ways — the cavern is compacted paradox, still warm from decisions that never happened."* | **Hot desaturated rust-ember** — dark walls with a low heat-glow, oxidized red floor. | **Ember-orange.** | Uneasy-warm, paradoxical, kiln-like. The closest tonal cousin to band 2's amber (a risk — see rec). |

**Recommendation: Pitch A "The Warren."** It is the GDD's already-canon Band-3 "Lateral" (grown-not-built = the CA cavern's literal grammar; anomalous/paradox loot = the tier-lifted curve; reality instability = the low-legibility play), its **cold blue-violet is the clearest "impossible color" step** and the *most distinct* from band 2's warm amber (C's ember-red risks reading as "band 2 again"), and its violet portal glow gives T4 an unambiguous third-portal color. **This is a vision/tone call — needs Director review (D1).**

### 3.2 `band_three.tres` — the concrete value table

Authored against the `BandProfile` schema (`data/bands/band_profile.gd`). Values chosen for "a nook-rich, chamber-y, low-sightline cave, deeper and stranger than band 2," explicitly *configurable, not balanced*.

| Field | `band_two` (control) | **`band_three` (T3)** | Why |
|---|---|---|---|
| `id` | `&"band_two"` | `&"band_three"` | stable content id; T4 stamps the ROUTE key `&"band_three"` on telemetry (id ≠ route key by the `band_profile.gd:17` note, but they coincide here). |
| `display_name` | "The Sump" | **"The Warren"** (Pitch A; Director may swap) | portal prompt / HUD (used by T4). |
| `backend` | `"socket"` | **`"cave"`** | selects the T0 CA backend — the whole point. |
| `backend_config` | `bandgen_config_band_two.tres` | **`cave_config_band_three.tres`** (new, §3.3) | a `CaveBandConfig`, not a `BandGenConfig`. |
| `archetype` | `"branchy"` | **`"linear"`** (inert for cave) | the enum has no cave value; `validate()`'s archetype check is socket-only (`band_profile.gd:87`), so this is ignored on a cave band. Set to the neutral default. *(Coordination note to T0: the cave `validate()` branch must not read `archetype`/`piece_pool`.)* |
| `archetype_params` | `{}` | `{}` | unused for cave. |
| `piece_pool` | `piece_catalog_ext.tres` | **`null`** | a cave has no authored pieces; the backend emits synthetic pieces from `floor_cells`. The socket `validate()` branch (which *requires* a non-empty pool) does not run for `backend == "cave"` — T0's cave branch must not require it (coordination note). |
| `piece_pool_ext` | `null` | `null` | the `lvl_enabled` catalog-swap is socket-only. |
| `principles` | `[]` | `[]` | no principle stages (M2). |
| `flavors` | `[SetPieceInject, WearDecay]` | **`[]` (EMPTY)** | §3.6 / OQ-flavors — the socket flavors are inapplicable to synthetic cave pieces; the cave is its own flavor. |
| `depth_curve` | `depth_curve_band_two.tres` | **`depth_curve_band_three.tres`** (reward-lifted, §3.5) | expresses "band 3 loot is anomalous/rarer." |
| `junk_catalog` | `junk_catalog.tres` (shared) | `junk_catalog.tres` (shared) | no new junk items in M1.10 scope (tier-6 "paradox parts" is an M2 content follow-up). |
| `opposition_deck` | 6-entry deck | **4-entry deck** (§3.4) | ambusher + burrower + splitter + a `DeckEntry`-wrapped bomb. |
| `band_depth` | `2` | **`3`** | → `instability(3) = 1.30` → 31-credit budget (§2.2). |
| `palette_tint` | `Color(0.82, 0.66, 0.42, 1)` | **`Color(0.62, 0.60, 0.78, 1)`** (Pitch A) | the "impossible color" identity; T1's cave materialisation modulates the band root with it. Environment-artist finalizes exact value per the ratified pitch. |

### 3.3 `cave_config_band_three.tres` — the tuned `CaveBandConfig` (honoring the b3 feel)

A **new** `CaveBandConfig` instance (T0 owns the class/schema/defaults; T3 authors this tuned instance). The exploration's knob list (`b3-organic-caverns.md:53-60`) maps to T0's `{grid extents, fill_pct, smooth_passes, min_region_cells, nook/roughness}`. Proposed starting values, with the *reason* each honors "chamber-y, nook-rich, bad sightlines, grown-not-built":

| `CaveBandConfig` field (T0-named) | Proposed value | Why (b3 feel) |
|---|---|---|
| `grid_width` × `grid_height` | **56 × 56 cells** (16px cells) | a cavern of comparable playable footprint to band 2's ~16-piece socket band; large enough that a chamber can't be seen across (bad sightlines) and that the BFS depth axis has real range. *T1's min-corridor-width / player-scale check is the hard floor — if 56² throats pinch below player width at this fill%, raise the grid or lower fill (OQ-scale).* |
| `fill_pct` | **45** | the classic CA seed density. 45% yields bulbous chambers joined by pinched throats after smoothing — the exact "grown" silhouette. Higher (48-50) = tighter/more wall/more fragmentation risk; lower (40) = one big open blob (fewer nooks, better sightlines — wrong). |
| `smooth_passes` | **4** | 4 passes of the 4-5 rule rounds the wall fronts into chambers without over-smoothing every nook away. 5 = smoother/fewer islands (loses the fringe); 3 = noisy/islandy (fights connectivity). 4 is the chamber-vs-nook balance. |
| `min_region_cells` | **24** | keep-largest, then deterministically CARVE-connect any secondary region ≥ 24 cells (a real side-chamber worth reaching), discard smaller specks as solid wall. 24 cells ≈ a small room; larger threshold = fewer/bigger satellites, smaller = more carved connectors (busier, more disorienting). |
| `nook_roughness` (the identity knob) | **0.5** | the "leave more fringe pockets" lever (under-smooth / roughness pass). 0.5 keeps the dense alcove fringe that makes the Ambusher's concealment read as *fair* (there are always plausible nooks) without shredding the chambers into noise. **This is band 3's signature knob** — the difference between "cave" and "blobby room." |

> **Determinism note:** every value here feeds T0's order-stable CA + deterministic CARVE, so `(band_three + seed)` → one `fingerprint()` forever. These values change the *shape*, never the *reproducibility*.

### 3.4 `opposition_deck` — 4 entries, natives-first (authored order = budget priority)

The deck the `EncounterBuilder` deck lane spends the **31-credit** budget on (§2.2). Draw = **authored array order** (weights inert, §2.3); `min_band ≤ band_depth(3)` gates; supporting shipped defs need a `DeckEntry` `base_count` override to actually spawn (§2.3). Natives sit first so they get first call on the budget.

| # | Deck entry | `min_band` | Row type | Effective `base_count` | `credit_cost` (assumed) | Cave-fit justification |
|---|---|---|---|---|---|---|
| 1 | `&"ambusher"` (T2a) | **3** | plain ref | on def (>0) | ~2 *(T2a authors)* | **Native.** The nook-hidden loot-punisher; *needs* bad sightlines to be fair. The whole reason the cave exists. First priority. |
| 2 | `&"burrower"` (T2b) | **3** | plain ref | on def (>0) | ~2 *(T2b authors)* | **Native.** Denies a blobby chamber on a timer; the chamber geometry *is* its arena. Second priority. |
| 3 | `&"splitter"` (shipped) | 2 | plain ref | `1` (on def) | 3 | **Chamber infestation.** A slow chase/proximity mover — geometry-agnostic; its throw-death children scattering into cave nooks is thematically perfect ("the chamber breaks apart"). Already `base_count = 1`, so it spawns with **no wrapper**. |
| 4 | `&"bomb"` (shipped) | 0 | **`DeckEntry` { `base_count`: 1 }** | `1` (via override) | 1 | **Hidden nook mines.** A static proximity fixture — placeable anywhere, and the cave's nooks are the ideal place to hide one, sharpening the "clear before you trust it" tension. Needs the `DeckEntry base_count` override to fire (§2.3); the override touches *only band 3's row*, not `bomb.tres`. |

**Excluded from the roster — justified against cave geometry (breakdown asks each):**

| Excluded | Why it's a poor cave fit |
|---|---|
| `&"pingpong"` (StraightBounceMove) | **The breakdown's own example.** Its identity is a *predictable straight bounce* off flat walls. Blobby chambers have no straight walls, so bounces become chaotic ricochets — and in a cramped nook a fast bouncer becomes an *unfair* random hazard, not a dodgeable one. Its whole read degrades in caves. **Exclude** (Director may want it as ambient chaos — D2). |
| `&"charger"` (ChargeLane) | Its identity is a *straight-lane charge* (`charge_max_dist = 400`). Bad sightlines rarely give it a clean 400px lane; it becomes a wall-crashing bull whose corridor-native "lane denial" is lost. It's also band 2's signature (The Wrecker) — keeping it band-2-flavored aids the SG2/TG2 A/B read. **Exclude** (Director could gate it in as shared escalation — D2). |
| `&"spike"` (rotating fixture) | Works *geometrically* (a rotating arm in an open chamber is fine) but adds little the natives + bomb don't already cover, and its "lane sweep" reads best in open rooms. Held as a Director *option* (add a `DeckEntry` row if band 3 feels under-populated) rather than a default. |
| `&"pursuer"` (R1 depth-linger chaser) | *Geometrically* fine (chases around blobs). But it spawns via the retained R1 depth-linger lane, not `base_count`, so making it a deck row is a semantic mismatch that would need a `base_count` override to even fire and would confound the clean cave A/B. **Exclude** for M1.10. |

> **Deck-exclusivity (breakdown OQ9, mirrors band_two's D-RAT-2):** `ambusher`/`burrower` are `min_band = 3` on their defs (T2a/T2b), so they are **band-3-exclusive** structurally — band 1 (legacy lane, empty deck) and band 2 (`band_depth = 2 < 3`) never see them regardless. This gives TG2 a clean three-band A/B. Recommend **yes, exclusive for M1.10** (D3).

### 3.5 `depth_curve_band_three.tres` — reward-lifted for "anomalous / paradox" loot

A **new** `DepthCurve` (`systems/depth/depth_curve.gd`: `value_curve`, `density_curve`, `tier_threshold_curve`), lifting reward over band 2's (value 1.15→2.1, density 2.2→2.6, tier 2→5, from `depth_curve_band_two.tres`):

| Curve | band 2 | **band 3** | Effect |
|---|---|---|---|
| `value_curve` | 1.15 → 2.1 | **1.30 → 2.5** | shallow floor matches the 1.30 instability kick; rises steeper deep. |
| `density_curve` | 2.2 → 2.6 | **2.3 → 2.8** | slightly more junk per piece (a denser, richer-feeling cave), still flat enough that shallow chambers aren't worthless. |
| `tier_threshold_curve` | stepped 2 → 5 | **stepped 3 → 5** | band 3 *starts* at min tier 3 and reaches the tier-5 ceiling faster — "band 3 loot is rarer/anomalous from the first chamber," expressed via the tier gate on the shared junk pool. |

> **Tier-ceiling honesty (per S7's R-OQ4 finding):** the shared junk pool tops out at **tier 5** (`data/junk/`). So band 3's ceiling is 5 (same as band 2), but its *floor* rises to 3 — meaning band 3 excludes tier-1/2 items entirely and skews high-tier throughout. Adding tier-6 **"anomalous items / paradox parts"** (the GDD's literal Band-3 loot) is an **M2 content follow-up**, not M1.10 scope. Flagged, not a blocker (OQ-reward).

### 3.6 Flavors EMPTY (breakdown OQ10 — confirmed and *argued*, not just confirmed)

`band_three.flavors = []`. This is not merely "out of scope" — it is *mechanically correct*:

- **`SetPieceInject` is socket-coupled.** Per S7's R-Flavors finding, it *appends a new set-piece room to a depth-gated retained open socket* (`band.open_sockets`, grow-loop helpers). A synthetic cave `PlacedPiece` has **no sockets and no `open_sockets`** — the stage has nothing to attach to. It would no-op at best, error at worst.
- **`WearDecay` is socket-coupled.** It blocks/breaches *doorway cells between socket-mated pieces* on a tree band. A cave is one flood-connected blob with no doorways/bridges in that sense — the stage's block/breach targets don't exist.
- **Wiring them to caves is new engine work** — explicitly a breakdown scope guardrail ("out of scope unless free"; it is *not* free). And it is *unnecessary*: the b3 exploration's thesis is *"the cave IS the flavor"* — the nook fringe + chamber bulk carry the identity that `SetPieceInject`/`WearDecay` carry for socket bands.

**Confirmed: `flavors` ships EMPTY on `band_three`.** The contract test asserts `flavors.size() == 0`.

### 3.7 Depth-signposting — a watch-item, not build scope

The b3 exploration (`:67`) and the breakdown (§Scope guardrails, TG3 watch-items) both flag: *"a cave's depth is less visually obvious than a linear spine — 'deeper = farther home' still reads mechanically (DepthGrader BFS hops), but not eyeballably."* T3 **ships this as-is**: the depth axis is real (the gate is at the deepest piece; return distance is computed) but the player can't sight it. **This is a TG2/TG3 watch-item** (does the cave disorient *productively* or read as *lost*?), and a candidate future assist is a lighting/cue gradient by depth — **explicitly out of T3's build scope**. Noted here so it's on the record for the gate, not silently absorbed.

---

## 4. Pseudocode / data sketch

### 4.1 `band_three.tres` — field-by-field (the actual resource T3 authors)

```
BandProfile (data/bands/band_three.tres)
  id              = &"band_three"
  display_name    = "The Warren"                       # Pitch A (Director may swap)
  backend         = "cave"                              # ← selects the T0 backend
  backend_config  = ExtResource(cave_config_band_three.tres)   # a CaveBandConfig
  archetype       = "linear"                            # inert for cave
  archetype_params= {}
  piece_pool      = null                                # cave emits synthetic pieces
  piece_pool_ext  = null
  principles      = []
  flavors         = []                                  # EMPTY (§3.6)
  depth_curve     = ExtResource(depth_curve_band_three.tres)   # reward-lifted
  junk_catalog    = ExtResource(junk_catalog.tres)      # shared
  opposition_deck = [                                   # natives-first (§3.4)
      ExtResource(ambusher.tres),                       #   [0] native, min_band 3
      ExtResource(burrower.tres),                       #   [1] native, min_band 3
      ExtResource(splitter.tres),                       #   [2] base_count 1 on def
      DeckEntry{ def: ExtResource(bomb.tres),           #   [3] wrapper → live bomb
                 param_overrides: { "base_count": 1 } },
  ]
  band_depth      = 3                                   # → instability 1.30 → 31 credits
  palette_tint    = Color(0.62, 0.60, 0.78, 1)          # Pitch A "impossible color"
```

### 4.2 `cave_config_band_three.tres` (values from §3.3; T0 owns field names)

```
CaveBandConfig (data/cave_config_band_three.tres)
  grid_width       = 56
  grid_height      = 56
  fill_pct         = 45
  smooth_passes    = 4
  min_region_cells = 24
  nook_roughness   = 0.5
```

### 4.3 Budget sanity-check against 1.30 (illustrative — caps are the real shaping lever)

Budget = `floor(24 * 1.30) = 31`. Assume ~14 eligible pieces (entry + no-cell pieces excluded), and *assumed* T2a/T2b costs/caps (coordination targets, §7 OQ-costs). Walk in authored order:

```
budget = 31
[0] ambusher  cost2 cap~6:  demand14 → n=min(14, 31/2=15, 6)=6 → spend 12 → budget 19
[1] burrower  cost2 cap~4:  demand14 → n=min(14, 19/2=9,  4)=4 → spend  8 → budget 11
[2] splitter  cost3 cap 8:  demand14 → n=min(14, 11/3=3, 8)=3 → spend  9 → budget  2
[3] bomb      cost1 cap~6:  demand14 → n=min(14, 2,      6)=2 → spend  2 → budget  0
  → 6 ambusher + 4 burrower + 3 splitter + 2 bomb = 15 hazards across ~14 chambers
```

The budget spends **coherently to ~0** with natives funded first. The *felt* density (15 hazards, native-dominant) is a plausible starting point; **per_band_cap is the real shaping knob** (T2a/T2b own the native caps). **Coordination targets to flag at T2a/T2b (OQ-costs):** `ambusher credit_cost ≈ 2, per_band_cap ≈ 5-6`; `burrower credit_cost ≈ 2, per_band_cap ≈ 3-4` — so 31 credits yields a sane cave, not a swarm or a ghost town. If the natives ship at higher cost/lower cap, T3's deck still spends validly (the math self-limits); only the *count* shifts, a TG2 tuning call.

### 4.4 Contract test plan — `tests/test_band_three_profile.gd` (+ `.tscn`)

A near-verbatim clone of the shipped `test_band_two_profile.gd` (run as a SCENE, per the headless-test convention), retargeted to `band_three` and the cave backend. Same `SEEDS` matrix. Checks:

| # | Check | Mirrors band_two |
|---|---|---|
| **C0** | profile-load contract: `id == &"band_three"`, `display_name` (ratified), `backend == "cave"`, `band_depth == 3`, `validate()` clean, `backend_config` is a `CaveBandConfig` with the §3.3 values, `piece_pool == null` (cave), `depth_curve`/`junk_catalog` non-null, `palette_tint != Color(1,1,1,1)`, **`flavors.size() == 0`**, deck size 4, every deck id resolves (`ambusher`/`burrower`/`splitter`/`bomb`), the bomb row is a `DeckEntry` carrying `{ base_count: 1 }`. | `_check_profile_contract` (adapted: cave, empty flavors, `piece_pool` null, bomb-wrapper instead of charger-wrapper) |
| **C1** | determinism: same seed → same `fingerprint()` AND `floor_fingerprint()` twice; diff seeds → ≥2 distinct fps. **Cave-specific:** proves T0's sorted-region + deterministic-CARVE order-stability on the *authored* config. | `_check_determinism` (verbatim) |
| **C2** | connectivity: `ConnectivityGuarantee.new().is_fully_connected(band)` on **every** seed — single FLOOR component after keep-largest + CARVE. | `_check_connectivity` (verbatim) |
| **C3** | min-size floor: band yields ≥ a floor cell count / ≥ min graded pieces on every seed (cave analog of `soft_floor`; the exact bar is T0's acceptance metric — coordinate). Optional player-scale assert (min corridor width) if T1 exposes it. | `_check_soft_floor` (adapted to cave sizing) |
| **C4** | *(replaces set-piece check — caves have none)* entry anchor exists + `deepest_piece` graded + reachable (the extraction gate lands on FLOOR). | new (cave-specific; drop the band_two SetPieceInject isolation) |
| **C5** | **controls untouched:** `band_greybox` pipeline fp == direct `BandGenerator` fp (verbatim from band_two) **AND** `band_two` pipeline fp unchanged across the matrix (add the second socket control). | `_check_control_untouched` (extended to assert band_two too) |
| **C6** | deck gating: `instability(3) == 1.30`; `floor(24*1.30) == 31`; every deck def passes `min_band ≤ 3`; `ambusher`/`burrower` (`min_band 3`) included; the bomb `DeckEntry` carries the `base_count` override. | `_check_deck_gating` (retarget to depth 3) |

Run: `godot --headless --path Game res://tests/test_band_three_profile.tscn` (exit non-zero on any failure).

---

## 5. Files & the cost ledger

### 5.1 Files to create / touch

**Create (T3-owned, file-disjoint):**
- `data/bands/band_three.tres` — the `BandProfile` (§4.1).
- `data/cave_config_band_three.tres` — the tuned `CaveBandConfig` (§4.2; final path/name follows T0's `CaveBandConfig` convention).
- `systems/depth/depth_curve_band_three.tres` — the reward-lifted `DepthCurve` (§3.5).
- `tests/test_band_three_profile.gd` + `.tscn` — the contract test (§4.4).

**Touch (production code):** *predicted **none*** (§5.2). The `palette_tint` field exists (`band_profile.gd:71`); T1 wires the cave to consume it; the deck lane + `DeckEntry` are shipped. If a genuine seam surfaces (e.g. T0's cave `validate()` demands `piece_pool`/`archetype`), it is a **flagged deviation with a coordination note to T0**, not a silent T3 edit.

**Must NOT touch (contract):** `band_greybox.tres`, `band_two.tres`, `bandgen_config*.tres`, `depth_curve.tres`/`depth_curve_band_two.tres`, any shipped `OppositionDef` default (incl. `bomb.tres` — the `base_count` lives in the `DeckEntry`, not the def), `run_config.gd` all-off default, `event_bus.gd`/`game_state.gd`/save code.

### 5.2 Cost-ledger prediction (the headline scalability answer for TG3)

The breakdown makes T3's worklog *the* scalability ledger. The honest framing separates **fixed** from **marginal** cost:

- **Fixed cost (one-time, amortized over every future cave band):** T0 (CaveBackend + `CaveBandConfig` + dispatch), T1 (cave materialisation + socketless sealing), T2a/T2b (2 defs + 2 components). This is real engineering — the *second backend* the exploration warned about. It is paid once.
- **Marginal cost of band 3 *as a band* (what T3 measures):** **predicted 0 lines of production code** — `3 .tres` files + `1` contract test (a clone of `test_band_two_profile.gd`) + inline `DeckEntry` data. Compare band_two (S7), whose marginal cost was **1 glue line** (`geo.tile_set = profile.tileset`) + a `palette_tint` schema field. Band 3 is *cheaper still* because those seams already exist.

**The prediction TG3 will judge:** *once the cave machinery exists, adding a cave band costs the same as adding a socket band did — data only.* If T3's actual worklog matches this (3 `.tres` + 1 test, zero production lines), the M1.10 thesis — "a genuinely different generator slots in behind the same interface, and bands stay data" — is proven on evidence. The risk to the prediction is a T0/T1 seam that leaks into T3 (cave `validate()` field demands, or a materialisation hook that needs a per-band value not yet on `BandProfile`); those are the **coordination notes in §7** precisely so they're caught in T0/T1, not paid by T3.

---

## 6. Definition of done (acceptance)

1. **Deterministic:** `BandPipeline.new().generate(band_three, seed)` twice → byte-identical `fingerprint()` + `floor_fingerprint()` across the matrix; different seeds → variety.
2. **Connectivity:** `is_fully_connected` on every seed (single FLOOR component post-CARVE).
3. **Controls untouched:** `band_greybox` AND `band_two` fingerprints byte-identical across the matrix; all-off `RunConfig` fp `e943ac9c8bc1` unmoved (T3 adds no knob).
4. **Profile loads + validates:** the contract test's C0 passes (id/backend/band_depth/empty-flavors/cave-config/tint/deck-ids/bomb-wrapper); `validate()` clean on the cave branch.
5. **Deck spawns within caps:** with the deck live through the `EncounterBuilder` at the 31-credit budget, `ambusher`/`burrower`/`splitter`/`bomb` spawn within the SpawnService hard caps; `min_band 3` natives pass at `band_depth 3` and are absent from band 1/2. *(Full spawn is a TG1/TG2 integration check; T3's bar is "the deck draws and the gate filters correctly.")*
6. **Visual identity present:** band 3 renders in its `palette_tint` (T1's cave modulate); greybox/band_two render unchanged.
7. **Import + smoke green;** worklog names the real commit SHA(s) for the game-director-designer + environment-artist + general-purpose contributions, a **Bespoke-code ledger** (the §5.2 measurement — actual lines vs the 0-line prediction), and a Design deviations section.

---

## 7. Open Questions

Each states the trade-off. Vision/fun/tone/scope calls are flagged **needs Director review** with a recommendation; technical calls are fresh-eyes-resolvable on merit.

- **OQ1 — Band identity pick (= breakdown OQ2).** *(tone — needs Director review)* Ship **Pitch A "The Warren"** (GDD-canonical "Lateral," cold blue-violet "impossible color," violet portal, most distinct from band 2), or the alternates **B "The Hollow"** (blue-black + phosphor green, cave-dread) / **C "Paradox Deep"** (rust-ember — *risk: tonally close to band 2's amber*)? All share the mechanical spec, so the pick doesn't gate the build (only `display_name`, `palette_tint`, and T4's portal glow change). **Rec: A.**

- **OQ2 — Deck roster fun-calls (= breakdown OQ1 spillover).** *(fun — needs Director review)* The recommended deck excludes `pingpong` (chaotic ricochet in curved space), `charger` (corridor-native; band-2 signature), and holds `spike`/`pursuer` as options (§3.4). Is that the right cave roster, or does the Director want `pingpong` as *ambient chaos* / `charger` as a wall-crashing "cave troll" / `spike` added for density? **Rec: ship the 4-entry [ambusher, burrower, splitter, bomb] deck; add `spike` (a `DeckEntry` row) only if TG2 shows band 3 under-populated.**

- **OQ3 — Deck exclusivity (= breakdown OQ9).** *(design — recommendation)* Keep `ambusher`/`burrower` band-3-exclusive (`min_band 3` on their defs → clean three-band A/B), per D-RAT-2 precedent? **Rec: yes, exclusive for M1.10; let TG3 decide whether they graduate into shallower decks.** *Fresh-eyes-resolvable; surface to Director only if they want the natives shared now.*

- **OQ4 — Difficulty step size (= breakdown OQ2 spillover).** *(fun — needs Director review)* `band_depth 3` yields a flat 31-credit budget (+30% over band 1, +13% over band 2). Is a whole band-3 apart *felt* at +13% over band 2, or should band 3 use a sharper `BASE_CREDITS`/multiplier? **Rec: ship the locked 1.30 (fidelity to the +15%/band model) and let TG2 deaths-by-band / time-to-gate tell the Director whether to widen it — don't pre-tune.**

- **OQ5 — CaveBandConfig starting values.** *(technical/feel — fresh-eyes + T0 coordinate)* §3.3 proposes `56×56 / fill 45 / 4 passes / min_region 24 / nook 0.5`. These are honest starting points for "chamber-y + nook-rich," but the *actual* chamber bulk vs nook density is only knowable once T0's CA is running. **Resolution:** T0 sanity-runs these values on the seed matrix; if chambers fragment or throats pinch below player width, adjust fill/smooth/grid within the "bad sightlines + nook-rich" intent. **T1's min-corridor-width check is the hard floor.** Fresh-eyes ratifies the direction; the exact numbers settle at T0/T1 integration.

- **OQ6 — Cave `validate()` must not require socket fields.** *(technical — coordination with T0)* `band_three` sets `piece_pool = null` and a placeholder `archetype`. The socket `validate()` branch (`band_profile.gd:82-95`) *requires* a non-empty `piece_pool` and a socket archetype. **Resolution:** T0's cave `validate()` branch must gate on `backend == "cave"` and **not** read `piece_pool`/`archetype`. Flag to T0 at brief so `band_three.validate()` returns clean. *(No Director call — a T0 seam T3 depends on.)*

- **OQ7 — Native cost/cap coordination targets.** *(technical — coordination with T2a/T2b)* §4.3's budget sanity assumes `ambusher/burrower credit_cost ≈ 2` and `per_band_cap ≈ 5-6 / 3-4`. T2a/T2b own the real values. **Resolution:** flag these targets at T2a/T2b brief so the 31-credit budget yields a sane cave; if they ship different values the deck still spends validly (self-limiting) — only the felt count shifts (a TG2 call). *No Director call.*

- **OQ8 — Reward curve tier ceiling / tier-6 loot.** *(design — recommendation)* §3.5 lifts band 3 to floor tier 3 / ceiling 5 (the junk pool tops at tier 5). The GDD's literal Band-3 loot is "anomalous items / paradox parts" (tier-6-flavored), which the shared pool has none of. **Rec: ship the tier 3→5 curve now; log "author tier-6 anomalous/paradox JunkItems" as an M2 content follow-up.** *Fresh-eyes-resolvable; surface to Director only if they want band-3 loot held flat until the full I→loot coupling.*

- **OQ9 — Flavors EMPTY confirm (= breakdown OQ10).** *(scope — confirm)* §3.6 argues (not just asserts) that `SetPieceInject`/`WearDecay` are socket-coupled and inapplicable to synthetic cave pieces, so `flavors = []` is *mechanically correct*, not just descoped. **Rec: confirm EMPTY.** Wiring flavors to caves is new engine work (breakdown guardrail) and unnecessary (the cave is its own flavor). *Confirm; no Director call unless the Director wants a bespoke cave-flavor stage as a future task.*

---

## Director review queue (vision / tone / fun — NOT self-resolved)

Sharpened to one-line decisions with a recommendation. None gate the build's *mechanics* (all pitches share §3.2–§3.6); they shape identity/feel and can be dispositioned at the Wave-3 close-out.

- **D1 — Band identity pick (OQ1).** Ship **Pitch A "The Warren"** (GDD-canonical "Lateral," cold blue-violet impossible-color, violet portal — most distinct from band 2), or **B "The Hollow"** (blue-black + phosphor green) / **C "Paradox Deep"** (rust-ember — *risk: reads like band 2*)? **Rec: A.**
- **D2 — Cave deck roster (OQ2).** Ship the recommended **[ambusher, burrower, splitter, bomb]** deck (exclude pingpong/charger as poor cave fits; hold spike/pursuer), or add/swap per the Director's read of the fiction? **Rec: ship the 4; add `spike` only if TG2 shows band 3 under-populated.**
- **D3 — Native exclusivity (OQ3).** Keep `ambusher`/`burrower` **band-3-exclusive** (clean three-band A/B), or share into shallower decks now? **Rec: exclusive for M1.10; TG3 decides graduation.**
- **D4 — Difficulty step (OQ4).** Accept the locked **1.30** budget (+13% over band 2), or a sharper band-3 step? **Rec: ship 1.30 (model fidelity); let TG2 tell you whether to widen.**
- **D5 — Tier-6 loot (OQ8).** Ship the **tier 3→5** reward curve now and defer tier-6 "anomalous/paradox" items to M2, or hold band-3 loot flat until the full I→loot coupling? **Rec: ship 3→5; log tier-6 items as M2 content.**

---

*Spec authored by game-director-designer for M1.10 T3. Design + data-spec only — no game code; the `.tres` values here are authored during T3's build. The contract test is a retargeted clone of `test_band_two_profile.gd`. Coordination seams (OQ6 cave-validate, OQ7 native costs) are flagged to T0/T2a/T2b so T3's marginal cost stays at the predicted zero production lines. Deviations go to `DESIGN_DEVIATIONS.md` for the Wave-3 close-out sweep. OQ1/OQ2/OQ4/OQ8 need the Director; OQ3/OQ5/OQ6/OQ7/OQ9 are fresh-eyes/coordination-resolvable.*
