# S7 — New Band: `band_two.tres` — Expanded Design Spec

**Milestone:** M1.9 (Scalable Opposition + Band Systems) · **Workstream:** band Phase-E proof · **Wave:** 4 (parallel worktree)
**Task id:** S7 · **BlockedBy:** S1 (BandProfile + BandPipeline + `band_greybox.tres`), S5 (`SetPieceInject` + `WearDecay` + connectivity stage), S3 (EncounterBuilder + call-site integration) · deck references S6a/S6b (`&"charger"`/`&"splitter"`) integration-checked at S8/SG1
**Assignees:** game-director-designer (profile / deck / curve — this spec) · environment-artist (palette / tile retone placeholder) · general-purpose (glue: pipeline tileset-assign + profile-load contract test)
**Author:** game-director-designer · **Status:** spec (Phase-2 per-task design; open questions in §7 for Phase-3 fresh-eyes + Director)

> **What this doc is.** Per CLAUDE.md's four-phase authoring, this is S7's Phase-2 design: the premise research (§2), the buildable data spec (§3–§5), and the explicit `Open Questions` (§7) a fresh-eyes resolver + the Director dispose before build. It is **design + data-spec only** — it ships **no game code**; the `data/bands/band_two.tres` value table here is authored as the actual resource during S7's build, and the small pipeline glue (assign the profile's tileset, run the flavors) is the programmer's. S7 is **the band-side proof that "adding a band = data, not engineering"** — the exact mirror of S6a/S6b for oppositions. If band_two ships as *profile + two S5 stages + a palette*, with `band_greybox` byte-identical, S7 succeeds.

---

## 0. Hard constraints (read first)

Straight from the M1.9 breakdown scope guardrails and cross-cutting contracts. The spec must not violate them, and neither may the resource authored from it:

- **`band_greybox` control fingerprint is untouched.** `band_two` is a *new* `BandProfile` `.tres`; authoring it must not edit `band_greybox.tres`, `bandgen_config.tres`, `piece_catalog.tres`/`piece_catalog_ext.tres`, `depth_curve.tres`, or `greybox.tres`. band_two gets its **own** backend_config, its **own** depth_curve (or reuses the shared one by reference — §3.5), and its **own** tileset resource. The empty-flavors socket control stays byte-identical.
- **Socket backend ONLY.** No CaveBackend/ScatterBackend/WFC (breakdown guardrail + exploration recommendation). band_two differentiates via **archetype params (branchy) + two flavor stages + palette + deck** on the existing socket backend. No new placement algorithm.
- **Same-seed determinism.** `BandPipeline.generate(band_two, seed)` twice with the same seed → **byte-identical `Band.fingerprint()`** (`piece_id@offset#mated` sha256, `band.gd:58`). Every layout-affecting choice is baked into the profile data under the `(seed + config)` contract; every off-stream flavor uses a per-stage sub-seed (`seed ⊕ stage.salt`) and never moves the fingerprint. No global-RNG call added at generation time.
- **Connectivity guaranteed through `WearDecay`.** S5's Stage-5 connectivity guarantee (flood-fill from `entry` over FLOOR 4-adjacency, the existing `is_band_connected` check) runs *after* the `WearDecay` flavor, so a decayed corridor can never strand the player. band_two must be authored so this holds on every seed in the determinism matrix.
- **No save-schema change.** Band choice is run-state (S8's portal picks the profile for *this* dive). band_two persists nothing; it is regenerated from its seed like every band.
- **Placeholder art only; PixelLab Director-gated.** The visual identity ships as a **retone/tint placeholder** (§4). Any PixelLab paid generation needs an explicit Director OK (STATUS Blocked table). If any asset originates in `art_workshop/`, **copy, never move** (preserve exploration history). Pixel filter stays OFF.
- **M1 lethality model only.** band_two's deck contains **no M2-dependent hazards** (no HP pool → no Gas/Field). Every deck entry is a `*_kills`-gated, emit-always M1 opposition (the 4 shipped + Charger + Splitter).
- **File-disjoint from S4/S6a/S6b this wave.** S7 owns only its new files: `data/bands/band_two.tres`, its backend_config `.tres`, its tileset resource + png, and its contract test. It references S6a/S6b def ids by string; the physical defs land in their own tasks and are integration-checked at S8/SG1.

---

## 1. Goal & design intent

**One sentence:** *A second, deeper-feeling dive band that exists entirely as data — a branchy socket layout in a new palette, decayed and dotted with a set-piece, stocked with a deck that adds two band-2-exclusive predators — proving a biome is a `.tres`, not a bespoke generator.*

S7 is the band half of M1.9's thesis. S1 built the `BandProfile`/`BandPipeline` machinery and proved the empty-flavor socket profile reproduces today's band byte-for-byte; S5 built the two cheapest flavor stages and the connectivity guarantee. **S7 is where those parts have to earn their keep**: a genuinely different-feeling band assembled from *the same stage list* with *different profile data plus two reused stages and a palette*, and zero new bespoke generation code. The watch-item the re-gate (SG3) will judge is exactly this — *how much bespoke code did S7 actually need beyond the promised profile + stages?* The answer this spec is engineered to deliver is: **one small pipeline line** (assign `profile.tileset` to each instanced piece's Geometry layer at instance time) **and nothing else** — everything else is data.

**Design feel target (for the Director's sweep, not a balance claim):** band_two should read as *"the same yard, but older, more tangled, and it bites harder."* Branchier than greybox's clean spine so navigation is a mild decision; a set-piece landmark deep in the band to give the descent a memorable beat; a wear pass that makes it feel decayed (and forces the connectivity guarantee to prove itself); and an I-scaled deck (+15% budget for `band_depth=2`) plus two new predators so the difficulty step over band 1 is *felt*. Whether that step is right is a playtest call — S7 ships a coherent starting point, not a balanced one.

---

## 2. Research — what a "band-as-biome" is, and what S7 actually needs

### 2.1 What makes a band a distinct biome (per the GDD)

The GDD (§"The Bands" table + §Art) defines a band by **four coherent layers**, not just a different tint:

| Layer | Greybox (band 1 "Near") today | What a distinct biome changes | S7's lever |
|---|---|---|---|
| **Palette / silhouette / lighting** | flat greybox tileset (`greybox.tres`, 2-tile atlas, filter OFF); "familiar grime" | GDD §Art: "depths shift palette by band — familiar grime → desaturated nostalgia → impossible color." Contrast via **palette + silhouette + lighting**, never 3D. | `profile.tileset` = a retoned greybox (§4) + optional `palette_tint` |
| **Ruleset / topology** | linear socket spine (`branch_chance = 0.0`), no flavors | Each band "its own ruleset" (TDD §Procedural band assembly). Branchier topology, decay, set-pieces = a different *shape of play*. | branchy archetype params + `SetPieceInject` + `WearDecay` flavors |
| **Opposition deck** | (M1.4 shipped hazards spawned by the preset globally) | GDD danger column: band 2 "Medium; stranger entities." A band-specific deck with band-gated threats. | `opposition_deck` = 4 shipped + Charger + Splitter at `min_band` gates |
| **Economy / reward** | shared `depth_curve.tres` (value 1.0→1.8, tier 1→4) | GDD loot column: band 2 "Antiques, retro tech, future-alloys"; deeper bands = better tier. Reward scales with band depth. | its own (or a reward-lifted) depth_curve + `band_depth = 2` → I |

The GDD **already names band 2**: *"Band 2 — Temporal: a junkyard from another time (past scrapyards, war surplus, a future e-waste megafill); loot = antiques/retro-tech/future-alloys; danger = medium, stranger entities."* That is the canonical identity S7 should honor unless the Director picks an alternate tone (§3.1 offers alternates as the tone call the breakdown flags). The junk-content half (actual antique JunkItems) is out of M1.9 scope — S7 reuses the shared `junk_catalog.tres` and expresses "band 2 loot is better" purely through the **reward curve + `band_depth`**, not new items (§3.5, OQ4).

### 2.2 What `band_depth = 2` means — the +15%/band budget direction

The TDD locks a single **Instability scalar `I`** that "drives enemy HP/damage, spawn budget, *and* loot tier/value together — `I` grows linearly per second within a band with a **+15% multiplicative kick on band entry** (RoR2 model)." The GDD echoes it: "every zone deeper… raises instability."

For M1.9, per breakdown OQ6, we do **not** build the full `I` system (per-second growth + stat + loot scaling) — that stays M2+. We need only the **budget scalar** the EncounterBuilder spends, and `band_depth` is enough to compute it as a *function, not a system*:

```
I(band_depth) = I_base * 1.15^(band_depth - 1)      # the +15%/band entry kick, RoR2 model
band 1 (greybox, band_depth=1):  I = I_base * 1.15^0 = I_base        (×1.00)
band 2 (band_two,  band_depth=2): I = I_base * 1.15^1 = I_base * 1.15  (×1.15)
```

So band_two's opposition **credit budget is ~15% larger** than band 1's for the same `I_base`, purely from `band_depth = 2`. That is the honest, minimal reading of "+15%/band" and the only difficulty-step lever S7 needs from `I`. Whether 15% is the *right* felt step (or too small to notice a whole band apart) is a Director/playtest call (OQ2). The reward side (loot tier/value scaling with `I`) is expressed in M1.9 only through band_two's **depth_curve reward tier** (§3.5) since the full I→loot coupling is M2.

### 2.3 Honest accounting — what S7 needs *beyond* pure data

The breakdown demands an honest inventory of what S7 requires that isn't a value in a `.tres`. Here it is, exhaustively:

**Reused as-is (zero new code, zero new asset) — inventory of what already exists:**
- **Backend + archetype:** the socket backend + the branchy grow loop already exist and are dormant-ready. `bandgen_config.gd` documents `branch_chance` as "kept as a live field so branching is a config change, not a rewrite," and `band_generator.gd:310` reads `cfg.branch_chance` as the base path when R4 is off. **A branchy band is a config value, already wired.**
- **Piece pool:** `piece_catalog_ext.tres` already holds **10 pieces** (corridor_h/v/l, box_small/large, room_hub, room_xl, corridor_long_h, hall_v, chamber) with authored weights — a rich enough pool to reweight for a denser feel with **no new piece scenes** (see OQ3 for whether band_two wants a bespoke piece).
- **Flavor stages:** `SetPieceInject` + `WearDecay` are built by S5. S7 only *configures* them.
- **Connectivity guarantee:** S5's Stage 5. S7 relies on it; authors nothing.
- **Depth/reward:** `DepthCurve` (`depth_curve.gd`) + `JunkPlacer` are curve-shape-agnostic; a new curve is pure data.
- **Deck consumption:** the EncounterBuilder (S3) spends the deck. S7 authors the deck array.
- **Tile rendering:** each piece `.tscn` embeds `tile_set = greybox.tres` on its `Geometry` TileMapLayer. `ZonePiece` computes footprint from that layer.

**Genuinely needed beyond a value in band_two.tres (the honest "not pure data" list):**
1. **A retoned tileset resource** — `greybox_band_two.tres` (+ its `.png`) — a **placeholder art asset** (environment-artist, §4). This is content, not code, but it *is* a new file, not a field. (Alternatively a zero-asset `palette_tint` modulate — §4/OQ1.)
2. **One small pipeline line to apply the tileset per-band.** Because the palette lives on the profile (`profile.tileset`) but each piece `.tscn` hardcodes `greybox.tres`, the pipeline must, at instance time, do `geo.tile_set = profile.tileset` for the band's pieces (only when the profile carries a tileset; null → pieces keep their embedded greybox, so `band_greybox` is untouched). This is **the one line of glue S7 admits** and the honest answer to SG3's "how much bespoke code did S7 need." It is a pixels-at-instance-time operation → does not touch the integer layout stream → fingerprint-neutral.
3. **A `tileset` (and optional `palette_tint`) field on `BandProfile`.** The exploration's schema already lists `@export var tileset: TileSet`. If S1 shipped it, S7 uses it; if not, adding one export is a trivial schema addition owned by whoever owns `band_profile.gd` (flag at brief — OQ1). No save impact (BandProfile is content, not saved state).
4. **The deck's Charger/Splitter defs** (`&"charger"`, `&"splitter"`) — authored by S6a/S6b, not S7. S7 references ids; integration-checked at S8/SG1.

That's the whole list. **No new generator, no new backend, no new stage, no bespoke band code** — one glue line + one placeholder tileset + (maybe) one export field. This is the proof.

---

## 3. Design spec

### 3.1 Band identity pitches (Director picks — the tone call the breakdown flags)

Three pitches. **Pitch A honors the GDD's canonical band-2 identity**; B and C are alternate tones offered because the breakdown explicitly makes name/fiction a Director call. All three use the *same* mechanical spec (§3.2–§3.6) — only name/fiction/palette/mood differ, so the pick does not gate the build.

| # | Name | One-line fiction | Palette direction (placeholder) | Mood |
|---|---|---|---|---|
| **A ★ (canonical, recommended)** | **The Sump** *(band 2 "Temporal")* | *"A junkyard that fell out of another decade — war-surplus, dead formats, rust that remembers being new."* | **Desaturated sepia-amber**: greybox greys pushed warm-brown, walls darker/oxidized, floor a faded ochre. GDD's "desaturated nostalgia." | Melancholic, decayed, time-lost. The wear + set-piece read as an *old flooded sub-level*. |
| **B** | **The Overflow** | *"Where the yard's runoff pools — everything the surface couldn't keep, sunk and silted over."* | **Cold teal-grey**, greenish floor tint, wet dark walls. | Damp, claustrophobic, drowned. Leans hardest into `WearDecay(flooded)`. |
| **C** | **The Annex** | *"A back lot that shouldn't connect to the main yard but does — someone's private, over-organized hoard."* | **Dim institutional green-grey**, colder and more uniform than greybox. | Uneasy-orderly; the branchy layout reads as deliberate corridors, not decay. Pairs with a lighter `WearDecay`. |

**Recommendation:** **Pitch A "The Sump."** It is the GDD's already-canon band 2, its sepia-amber retone is the clearest one-hue palette shift from greybox (cheap, legible placeholder), and its "old flooded sub-level" fiction motivates *both* chosen flavors (`WearDecay` = the decay/flood, `SetPieceInject` = a landmark like a half-sunk archive/office). B and C are viable if the Director wants a colder tone. **This is a vision/tone call — needs Director review (OQ… flagged in §7).**

### 3.2 `band_two.tres` — the concrete value table

Authored against the `BandProfile` schema (S1). Values chosen for "denser/branchier/deeper-feeling than greybox," explicitly *configurable, not balanced*.

| Field | `band_greybox` (control) | **`band_two` (S7)** | Why |
|---|---|---|---|
| `id` | `&"band_greybox"` | `&"band_two"` | stable id; S8 stamps it on `run_started` telemetry for per-band SG2 comparison. |
| `display_name` | "Greybox" | **"The Sump"** (per Pitch A; Director may swap) | portal prompt / HUD. |
| `backend` | `"socket"` | `"socket"` | guardrail: socket only. |
| `backend_config` | `bandgen_config.tres` | **`bandgen_config_band_two.tres`** (new, §3.3) | its own tuning; the control's config is untouched. |
| `archetype` | `"linear"` | **`"branchy"`** | the branch curve lever (§3.3). |
| `archetype_params` | `{}` | `{}` (branch lives in backend_config for M1.9) | keep params thin; branch_chance is the socket backend's native lever. |
| `piece_pool` | `piece_catalog.tres` (6) | **`piece_catalog_ext.tres` (10)** | denser/varied feel from the existing extended pool — **no new pieces** (OQ3). |
| `tileset` | *(null → pieces keep embedded greybox)* | **`greybox_band_two.tres`** (retone, §4) | the palette identity; pipeline assigns it per-instance. |
| `palette_tint` *(if field exists)* | *(unset)* | optional fallback `Color(0.82, 0.66, 0.42)` sepia if no retoned png ships (§4/OQ1) | zero-asset placeholder path. |
| `principles` | `[]` | `[]` | M1.9 guardrail: no principle stages (those are M2 Phase C). |
| `flavors` | `[]` | **`[SetPieceInject(...), WearDecay(...)]`** (§3.4) | the S5 stages earning their keep. |
| `depth_curve` | `depth_curve.tres` | **`depth_curve_band_two.tres`** (reward-lifted, §3.5) or shared (OQ4) | expresses "band 2 loot is better." |
| `junk_catalog` | `junk_catalog.tres` | `junk_catalog.tres` (shared) | no new junk items in M1.9 scope. |
| `opposition_deck` | `[]` | **6-entry deck** (§3.6) | 4 shipped + Charger + Splitter, `min_band`-gated. |
| `band_depth` | `1` | **`2`** | drives `I = I_base·1.15` → ~+15% credit budget (§2.2). |

### 3.3 `bandgen_config_band_two.tres` — archetype params vs greybox

A **new** `BandGenConfig` (does not touch `bandgen_config.tres`). Only the deltas from greybox matter:

| `BandGenConfig` field | greybox | **band_two** | Rationale |
|---|---|---|---|
| `target_piece_count` | `12` | **`16`** | denser/longer band; still well under the preset's `lvl_room_count=30` so perf headroom holds. |
| `branch_chance` | `0.0` (linear) | **`0.15`** | the branchy identity — forks the spine into side rooms. This is a float on the layout path, so band_two's fingerprint legitimately differs from greybox under the `(seed+config)` contract; greybox stays 0.0 and byte-identical. |
| `max_place_attempts` | `16` | `16` | unchanged. |
| `loop_back_count` | `0` | `0` | no loop pass in M1.9 (reserved). |
| `soft_floor_percent` | `80` | `80` | same undersize-retry discipline. |
| `max_band_attempts` | `8` | `8` | same retry ceiling; branchier bands may need retries — verify the determinism matrix reaches target on all seeds (§6). |

> **Determinism note:** `branch_chance = 0.15 > 0.0` means the branch roll fires on band_two's layout stream — this is the *intended* config-driven fingerprint difference, deterministic per seed. It does **not** affect `band_greybox` (its config is separate, still 0.0). The determinism test drives each profile independently.

### 3.4 Flavor configs — the two S5 stages

Authored as the two entries of `band_two`'s `flavors` array (order matters: inject the set-piece, *then* decay, *then* S5's connectivity guarantee runs last and can breach any decay that stranded a route).

**`SetPieceInject`** (rides existing socket/sealer machinery — the cheapest win):
| Param | Value | Meaning |
|---|---|---|
| `defs` | `[set_piece_sunk_archive]` | the landmark piece(s) to inject. For M1.9, **reuse an existing large piece** (`piece_room_xl` or `piece_chamber`) as the "set-piece" rather than authoring a bespoke scene (OQ3) — the injection *placement rule*, not a new asset, is what proves the stage. |
| `max` | `1` | exactly one landmark per band (a memorable beat, not clutter). |
| `min_depth_norm` | `0.6` | inject only into a piece at `depth_norm ≥ 0.6` — deep, so it's a "reward for pushing" landmark (mirrors the exploration's `archive_room @ deep`). |
| `salt` | unique per-stage constant | sub-seed `seed ⊕ salt`; deterministic pick among eligible deep pieces. |

Placement rule (see §3.7 for the full rule): the stage walks pieces in DepthGrader order, filters to `depth_norm ≥ min_depth_norm`, and deterministically selects up to `max` of them to **swap/mark** as the set-piece (mark for retone + as a preferred set-piece anchor; a swap-in of a bespoke scene is deferred, OQ3). Off-stream if it only *marks* (fingerprint-neutral); layout-affecting only if it *swaps geometry* (then it moves band_two's fingerprint deterministically — acceptable, still not greybox's).

**`WearDecay`** (the decay identity + the reason the connectivity guarantee exists):
| Param | Value | Meaning |
|---|---|---|
| `state` | `&"flooded"` (Pitch A/B) or `&"disused"` (Pitch C) | the decay flavor tag — drives which cells get marked worn/blocked and the retone accent. |
| `intensity` | `0.25` | fraction of eligible (non-critical) floor cells the pass may mark/block. Kept modest so decay *flavors* rather than *shreds* the band. |
| `block_routes` | `true` | may block some non-critical corridor cells (the "decay closes a path" feel) — **the exact case S5's Stage-5 connectivity guarantee must catch.** |
| `open_breaches` | `true` | may open a compensating breach (the exploration's "blocks routes, opens breaches"). |
| `salt` | unique per-stage constant | sub-seed; deterministic decay set. |

> **Connectivity contract (non-negotiable):** because `WearDecay(block_routes=true)` can sever a corridor, S5's Stage-5 guarantee **must run after it** and flood-fill from `entry` over FLOOR 4-adjacency; if any floor is unreachable it carves a minimal connector (socket-backend case: the exploration allows this to be a verify-or-breach). S7's determinism test (§6) asserts `is_band_connected(band) == true` on **every** seed in the matrix — the design's proof that decay never strands the player.

### 3.5 Depth / reward curve + reward tier

band_two should reward the deeper band. Two options (OQ4):

- **Recommended: `depth_curve_band_two.tres`** — a new `DepthCurve` lifting the reward vs greybox's (value 1.0→1.8, tier 1→4):
  | Curve | greybox | **band_two** | Effect |
  |---|---|---|---|
  | `value_curve` | 1.0 → 1.8 | **1.15 → 2.1** | ~+15% shallow floor (matches the I entry-kick) rising steeper deep. |
  | `density_curve` | ~flat 2.0→2.3 | ~flat 2.2→2.6 | slightly more junk per piece (denser band feel), still flat enough that shallow pieces aren't worthless. |
  | `tier_threshold_curve` | stepped 1→4 | stepped **2→5** | band 2 *starts* at min tier 2 and unlocks tier 5 deep — "band 2 loot is better/rarer" from the GDD, expressed via the tier gate on the shared junk pool. |
- **Alternative: reuse `depth_curve.tres`** and express the whole reward step purely through `band_depth`/I later. Cheaper (one fewer file) but band_two's loot then reads identical to band 1 in M1.9 (no felt reward step) — weakens the biome distinction. **Recommend authoring the new curve** (it's pure data and the honest expression of the GDD reward column); **flag as OQ4.**

**Reward tier statement:** band_two is `band_depth = 2` → its *opposition budget* is ~+15% (§2.2) and its *loot tier floor/ceiling* is lifted one step (2→5 vs 1→4). Together that is the M1.9-scoped reading of the TDD's "single I drives enemies + loot together" — without building the full I system.

### 3.6 `opposition_deck` — 6 entries, `min_band`-gated

The deck the EncounterBuilder (S3) draws from, spending the I-scaled credit budget (`I = I_base·1.15` for band_depth 2). Entries with `min_band > profile.band_depth` are filtered out before the draw. Ids for the 4 shipped hazards must be reconciled with the ids S0 authors on the `OppositionDef.tres` set (candidate ids below; **integration-checked at S8/SG1**).

| Deck entry (def id) | `min_band` | Draw `weight` | `credit_cost` | Notes |
|---|---|---|---|---|
| `&"pursuer"` (R1 HazardEntity) | `1` | `3.0` | `3` | the sharp binary predator; present in band 2 too. |
| `&"pingpong"` (K5a) | `1` | `4.0` | `2` | cheap, common attritional hazard. |
| `&"bomb"` (K5b) | `1` | `2.5` | `2` | telegraphed area denial. |
| `&"spike"` (K5c) | `1` | `4.0` | `2` | cheap static hazard, fills rooms. |
| **`&"charger"` (S6a)** | **`2`** | `2.5` | `4` | **band-2-exclusive** (breakdown OQ5 recommends band-2-exclusive for a clean A/B) — the new dash predator; higher cost = rarer, dangerous. |
| **`&"splitter"` (S6b)** | **`2`** | `2.0` | `4` | **band-2-exclusive**; splits on throw-death (mid-run `svc.spawn`); its children are capped by the service registry, not the deck budget. |

**Deck semantics (design intent for the EncounterBuilder contract):**
- **Budget:** total credits ≈ `I_base · 1.15 · scale(depth)` (S3 owns the exact math; S7's contract is "band_depth 2 ⇒ ~15% more than band 1 for the same I_base"). Draw weighted-by-`weight` until the budget can't afford the cheapest remaining eligible def.
- **Gating:** `min_band ≤ band_depth` keeps Charger/Splitter out of band 1 automatically (so if the Director *doesn't* enable them in band 1's preset, the deck alone enforces exclusivity — the clean A/B, breakdown OQ5).
- **Caps vs budget:** deck spends *credits*; the SpawnService hard caps (per-room/per-band/global) still bind independently — Splitter's children count against the registry ceiling but not the deck budget (they're mid-run, run-state). This is the S6b proof S7's deck must not double-count.
- **Determinism:** the builder's draw order is a stable RNG-free (or sub-seeded) walk per S3; S7 authors only the static deck data. Same seed + this deck → same spawn set.

### 3.7 Set-piece placement rules

Where the `SetPieceInject` landmark lands (the design rule the stage encodes):

1. **Eligibility:** after DepthGrader runs, collect pieces with `depth_norm ≥ 0.6` (deep third) that are **rooms, not corridors** (footprint area ≥ a small threshold — reuse the JunkPlacer's room heuristic if S5 exposes it) so the landmark sits in a space, not a hallway.
2. **Deterministic pick:** from the eligible set (in DepthGrader order), pick up to `max=1` using the stage sub-seed (`seed ⊕ salt`) — a stable index draw, never the global RNG.
3. **Never the entry, never the sole exit corridor:** the set-piece must not be the `entry_piece` nor a piece whose removal/reshape would break connectivity (the connectivity guarantee is the backstop, but the placement rule avoids the case up front).
4. **Marking vs swapping:** for M1.9, the stage **marks** the chosen piece as the set-piece anchor (for retone accent + as the deep landmark) rather than swapping in a bespoke scene (OQ3). Marking is off-stream/fingerprint-neutral; a future swap is a deterministic layout-affecting op.
5. **Interaction with WearDecay:** the set-piece's cells are **exempt** from `WearDecay` blocking (a landmark shouldn't be decayed into inaccessibility) — the decay stage reads the set-piece mark and skips those cells.

---

## 4. Placeholder visual treatment spec (environment-artist)

The biome's palette identity as a **placeholder**, pixel rules honored (filter OFF, integer atlas geometry unchanged). Two tiers — ship Tier 1 minimum; Tier 2 if the environment-artist has budget and the Director OKs.

**Inventory of what exists to retone:** `data/tilesets/greybox.tres` is a `TileSet` over `greybox.png` — a tiny atlas with two used tile coords (`0:0` = floor, `1:0` = wall, the wall carrying a 16×16 square physics polygon on `physics_layer_0`, `collision_layer = 2` = world). Cell size 16px. Every piece `.tscn` references `greybox.tres` on its `Geometry` TileMapLayer.

**Tier 1 — zero-asset tint (cheapest, recommended MVP):**
- Add (or reuse) a `palette_tint: Color` on `BandProfile`; band_two sets it to the Pitch's hue (Pitch A sepia `Color(0.82, 0.66, 0.42)`).
- The pipeline applies it as `modulate` on the band root container (a `CanvasModulate` child, or per-piece `modulate`) at instance time — **not** on the layout stream. Fingerprint-neutral.
- Result: greybox geometry rendered in sepia — an unmistakable band-2 read for **no new art file**. `band_greybox` sets no tint → renders identically → control untouched.

**Tier 2 — retoned tileset (richer, still placeholder):**
- **Retone recipe:** copy `greybox.png` → `greybox_band_two.png` (COPY, never move; if sourced from `art_workshop/`, copy out). Apply a **palette shift** per the Pitch (Pitch A "The Sump": floor grey → faded ochre `#B8956A`-range; wall darker oxidized brown `#5C4632`-range; keep the 2-tile atlas layout, same pixel dimensions, no filtering). Optionally add a third "worn/flooded accent" tile at an unused atlas coord for `WearDecay`-marked cells (a darker, cracked variant) — **optional**, and only if the artist wants the decay to read visually; the stage works without it.
- Author `greybox_band_two.tres` = a `TileSet` over the retoned png, **identical geometry + physics** to `greybox.tres` (same `collision_layer = 2`, same square polygon on the wall tile) so collision/socket math is unchanged.
- band_two.tres's `tileset` field → `greybox_band_two.tres`. The pipeline assigns `geo.tile_set = profile.tileset` per instanced piece when the profile carries one (§2.3 item 2). Null on greybox → embedded `greybox.tres` kept → control byte-identical.
- **Constraint:** the retoned tileset's tile **ids/coords must match greybox.tres exactly** (same source index, same atlas coords) so a `tile_set` swap doesn't reindex any placed cell — the `PackedByteArray` tile_map_data in each piece `.tscn` references tile coords, so the swap only re-skins, never re-lays.

**PixelLab:** not needed for either tier (a hue-shift is a palette op, not generation). If the Director later wants bespoke band-2 tiles, that is a Director-gated PixelLab run — **out of S7 scope.**

**Recommendation:** ship **Tier 1 (tint)** as the guaranteed placeholder (zero art risk, proves the data path), and let the environment-artist add **Tier 2 (retone)** in the same wave if budget allows — the two are not mutually exclusive (a retoned tileset *and* a subtle tint can coexist). **Which tier ships is a small Director/asset-budget call — OQ1.**

---

## 5. Files to create / touch

**Create (S7-owned, file-disjoint from S4/S6a/S6b):**
- `data/bands/band_two.tres` — the `BandProfile` (§3.2). Replaces nothing (`data/bands/` holds only `.gitkeep` today).
- `data/bandgen_config_band_two.tres` — the branchy `BandGenConfig` (§3.3).
- `data/tilesets/greybox_band_two.tres` + `data/tilesets/greybox_band_two.png` — the retone placeholder (Tier 2, §4). *(Tier-1-only ships neither; instead band_two.tres carries `palette_tint`.)*
- `systems/depth/depth_curve_band_two.tres` — the reward-lifted `DepthCurve` (§3.5) *(unless OQ4 = reuse shared)*.
- `tests/test_band_two_profile.gd` + `.tscn` — the headless profile-load + determinism + connectivity contract test (§6).

**Touch (glue — the one honest code seam, owned by S7's general-purpose contributor; coordinate with S1/S3's pipeline):**
- The `BandPipeline` (or its piece-instantiation step) — add the `if profile.tileset != null: geo.tile_set = profile.tileset` per-instance assign (and the tint apply for Tier 1). Guarded so null → embedded greybox → control unchanged. **This is the only production-code line S7 adds.**
- `BandProfile` (`band_profile.gd`) — add `tileset: TileSet` and/or `palette_tint: Color` exports **only if S1 didn't already ship them** (schema check at brief). No save impact.

**Must NOT touch (contract):**
- `data/bands/band_greybox.tres`, `data/bandgen_config.tres`, `data/piece_catalog*.tres`, `systems/depth/depth_curve.tres`, `data/tilesets/greybox.tres`/`.png` — the control's resources.
- `systems/bandgen/band_generator.gd`, `band.gd`, `socket_sealer.gd` — no generator change (branchy is a config value already wired).
- `run_config.gd` all-off default (fp `e943ac9c8bc1`) — S7 adds no RunConfig knob.
- `event_bus.gd`, `game_state.gd`, any save code — no signal, no state, no schema.

---

## 6. Definition of done (acceptance)

1. **Deterministic:** `BandPipeline.generate(band_two, seed)` twice with the same seed → **byte-identical `Band.fingerprint()`**, across the full `test_bandgen_determinism` seed matrix. Different seeds → different fingerprints. (band_two's fingerprints differ from greybox's — that's correct; the *contract* is same-seed reproducibility, not equality with greybox.)
2. **Control untouched:** `band_greybox`'s fingerprint is **byte-identical** to its pre-S7 value across the matrix (the profile-load test asserts both profiles); the all-off `RunConfig` fp `e943ac9c8bc1` is unmoved (S7 adds no knob).
3. **Connectivity through decay:** on **every** seed in the matrix, `is_band_connected(band_two_result) == true` — the `WearDecay(block_routes=true)` pass never strands the player (S5's Stage-5 guarantee proven for band_two specifically).
4. **Profile loads + composes:** the headless contract test loads `band_two.tres`, asserts `id == &"band_two"`, `backend == "socket"`, `archetype == "branchy"`, `band_depth == 2`, `flavors.size() == 2` (SetPieceInject + WearDecay), `opposition_deck.size() == 6`, non-null `backend_config`/`depth_curve`, and generates a band reaching `≥ soft_floor` pieces.
5. **Deck spawns within caps:** with the deck active through the EncounterBuilder, the band spawns the deck's oppositions within the SpawnService hard caps; Charger/Splitter appear (band_depth 2 passes their `min_band=2` gate); band 1 (greybox, band_depth 1) filters them out. *(Full A/B is SG2; S7's bar is "the deck draws and the gate filters correctly.")*
6. **Set-piece lands deep:** the injected set-piece anchor is at `depth_norm ≥ 0.6`, is not the entry, and its cells survive the decay pass (connectivity-safe).
7. **Visual identity present:** band_two renders in its palette (Tier 1 tint minimum) and greybox renders unchanged (side-by-side headless render check or a modulate/tileset assertion).
8. **Import + smoke green;** `godot --headless --import` compiles; worklog names the real commit SHA(s) for the game-director-designer + environment-artist + general-purpose contributions + a Design deviations section.

---

## 7. Open Questions (Phase-3 fresh-eyes resolves technical calls; Director rules on vision/tone)

Each states the trade-off. Vision/fun/tone/scope calls are flagged **needs Director review** with a recommendation.

- **OQ1 — Visual tier + the `tileset`/`palette_tint` schema.** *(technical + small asset-budget)* Ship Tier 1 tint only (zero art, guaranteed), or Tier 2 retoned tileset (richer, one placeholder png + tileset), or both? And does `BandProfile` already carry `tileset`/`palette_tint` (S1), or must S7 add the export? **Recommendation:** ship **Tier 1 always** + **Tier 2 if the environment-artist has budget this wave**; confirm the schema fields exist or add them (trivial, no save impact). *Fresh-eyes can resolve the schema question against S1's as-built; the "how much art to spend" sliver is a small Director call.*

- **OQ2 — Difficulty step size (+15% enough?).** *(vision/fun — needs Director review)* `band_depth=2` yields a ~15% opposition budget bump (RoR2 +15%/band). Is a whole band apart *felt* at +15%, or should band 2 use a larger multiplier / a higher `I_base` for a sharper step? Trade-off: fidelity to the TDD's locked +15%/band vs. a more dramatic band-2 identity. **Recommendation:** ship +15% (fidelity to the locked model) and let SG2 telemetry (deaths-by-band, run-length) tell the Director whether to widen it — don't pre-tune. *Director ratifies the multiplier.*

- **OQ3 — Bespoke set-piece / pieces, or reuse the ext pool?** *(scope + fun — needs Director review)* §3.4/§3.7 reuse an existing large piece (room_xl/chamber) as the "set-piece" and reuse `piece_catalog_ext` (10 pieces) rather than authoring a bespoke band-2 landmark scene or new pieces. Trade-off: reuse proves the *stage* with zero new scenes (the honest "content=data" proof); a bespoke landmark reads far more like a distinct biome but is new authored geometry (arguably out of the "data not engineering" thesis for M1.9). **Recommendation:** **reuse for M1.9** (proves the mechanism; keeps S7 pure data), and log "author a bespoke Sump set-piece" as an M1.10/M2 content follow-up. *Director confirms the reuse-vs-bespoke scope.*

- **OQ4 — Own depth_curve or shared?** *(design — recommendation, low-stakes)* §3.5 recommends a new reward-lifted `depth_curve_band_two.tres` (value 1.15→2.1, tier 2→5) so band-2 loot is *felt* as better; the alternative reuses the shared curve (one fewer file, but band-2 loot reads identical to band 1 in M1.9). **Recommendation:** author the new curve (pure data, honest expression of the GDD reward column). *Fresh-eyes can ratify on merit; surface to Director only if they want band-2 loot held flat until the full I→loot coupling (M2).*

- **OQ5 — Band-2-exclusive hazards, or also in band 1's preset?** *(vision/fun — needs Director review; = breakdown OQ5)* §3.6 gates Charger/Splitter at `min_band=2` so they're band-2-exclusive — giving SG2 a clean A/B (band 1 = old hazards, band 2 = old + 2 new). The alternative also enables them in band 1's default play preset now. **Recommendation:** **band-2-exclusive for M1.9** (clean A/B; the gate says "are the new hazards fun?" without confounding band 1's baseline), then let SG3 decide whether they graduate into band 1. *Director ratifies (this is explicitly the breakdown's OQ5).*

- **OQ6 — Longer or shorter than band 1?** *(vision/fun — needs Director review)* §3.3 sets `target_piece_count=16` (vs greybox's 12) so band_two is a bit longer/denser — but band 1's *preset* actually runs 30 rooms (`lvl_room_count=30`), so "16 vs 12" only holds if band_two is played at its profile default, not under the level-scale preset. Should band_two run **longer** (a deeper, more committing second band — matches "deeper = more") or **shorter** (a punchy 15-min band per the GDD's ~15-min band target)? And should the level-scale preset apply to band_two at all? Trade-off: length shapes the whole risk/reward pacing. **Recommendation:** ship `target=16` as a *slightly* longer band and let SG2 run-length telemetry guide it; keep the level-scale preset orthogonal (S8 routing decides whether band_two uses it). *Director ratifies band-2 length/pacing.*

- **OQ7 — Shipped-hazard deck ids.** *(technical — integration)* The deck references `&"pursuer"`/`&"pingpong"`/`&"bomb"`/`&"spike"` for the 4 shipped hazards; the authoritative ids are whatever S0 stamps on the `OppositionDef.tres` set. **Resolution:** reconcile against S0's authored ids at brief time; integration-checked at S8/SG1. *No Director call — a wiring detail.*

---

## Resolved Decisions (Phase 3)

*Fresh-eyes resolution (game-director-designer, NOT the S7 author). Technically-resolvable questions are decided on merit; genuine vision/tone/fun calls are sharpened into one-line Director questions with a recommendation. All as-built numbers this spec cites were re-verified against the real resources under `Game/` — corrections are called out. The orchestrator's fixed cross-contract adjudications are folded in as RESOLVED at the top.*

### R0 — Fixed cross-contract adjudications (folded in as RESOLVED, not open)

These were adjudicated by the orchestrator and are **locked** — the S7 build honors them verbatim:

- **Profile id + file:** `band_two.tres` carries `id = &"band_two"` and lives at `Game/data/bands/band_two.tres`. (Confirms §3.2's `&"band_two"`.)
- **Route key:** the dive-routing key for this band is `&"band_two"` (S8's portal maps to it).
- **Portal 1 unchanged:** the existing (portal 1 / `&"near"`) path keeps mapping to `band_greybox` — byte-identical, per S3 Q2b's `BAND_ID = &"near"` continuity note. band_two is purely additive.
- **Deck defs location:** the deck references `OppositionDef` resources at `Game/data/oppositions/` by the ids below; the physical defs land in S0/S6a/S6b and are integration-checked at S8/SG1. (`Game/data/oppositions/` does not exist yet — M1.9 Wave 1 is unbuilt at authoring time; this is expected, not a defect.)
- **Instability normalization:** `band_depth = 2`, with `instability(1) = 1.0` as the band-1 baseline, so **band 2 receives the first budget lift** → `I(2) = 1.15`. This resolves OQ… and the §2.2 form (see R-Instability below).

### R-Instability — the budget scalar, normalized (RESOLVED, technical + folds the fixed adjudication)

**Decision:** the single budget scalar is `I(band_depth) = 1.0 + 0.15·(band_depth − 1)` — band 1 → **1.00**, band 2 → **1.15**. band_two's deck-lane credit budget is therefore `floor(BASE_CREDITS · 1.15) = floor(24 · 1.15) = floor(27.6) = 27` credits (`BASE_CREDITS = 24` per S3 §3.1).

**Claim corrections this forces:**
1. **§2.2 is right; S3's function must be normalized to match.** S7 §2.2 already uses the band-1 = 1.0 form (`I_base · 1.15^(band_depth−1)`). But S3 §3.1's actual `instability(band_depth) = 1.0 + 0.15·band_depth` gives band 1 = 1.15 / band 2 = 1.30 — it is **not** normalized and **conflicts** with the fixed adjudication. **Cross-task coordination (flag to S3 at brief):** S3's `instability()` must adopt the normalized linear form `1.0 + 0.15·(band_depth − 1)` (band 1 = 1.0). At band 2 the linear and S7's multiplicative forms coincide exactly (both 1.15); they only diverge at band 3+ (which M1.9 never generates), so pick S3's linear function as the single call site and treat §2.2's `1.15^(band_depth−1)` as the illustrative-equivalent.
2. **§3.6 "budget ≈ I_base·1.15·scale(depth)" is wrong — drop the `·scale(depth)`.** S3's deck-lane budget is **flat**: `int(floor(BASE_CREDITS · I))` = 27, computed **once** per band. Depth does **not** scale the budget — it scales per-piece spawn *counts* (`n = base_count + floor(count_per_depth · depth_index)`), a separate lever. Correct §3.6's budget line to "band_depth 2 ⇒ `floor(24·1.15)=27` credits, flat; deeper pieces spend more only because they request more instances."
3. **`band_depth` threading (minor, coordination):** S3 §3.1 reads both `band.band_depth` and `profile.band_depth`. For the gate/budget to work, the pipeline must copy `profile.band_depth` onto the returned `Band` (or the deck lane reads `profile.band_depth` throughout). Not an S7 deliverable — flag to S1/S3 so band_two's `band_depth=2` actually reaches the deck lane.

### R-Deck — the deck is `Array[OppositionDef]`, not per-entry wrappers (RESOLVED, technical — reconciles §3.6 to S3)

**Decision:** `opposition_deck: Array[OppositionDef]` is an **ordered array of def references**. `min_band`, `credit_cost`, `base_count`, `count_per_depth`, and `spawn_weight` are **fields on each `OppositionDef`** (authored by S0 for the 4 shipped, by S6a/S6b for charger/splitter) — **not** columns S7 re-authors on a deck-entry wrapper. S7 authors *the ordered array + the id list*, and confirms the needed field values are set on those defs at S8/SG1 integration. Reconcile §3.6's table to read as "def ids in draw order," with the numeric columns annotated as "authored on the def (verify at integration)."

**Corrections to §3.6 forced by S3:**
- **`spawn_weight` is INERT in M1.9** (S3 Q6-iii resolved: reserved). The draw is a **deterministic walk of the authored array order, id-deduped (first occurrence wins), RNG-free** — the "Draw weight" column documents *future* intent only and does **not** affect any M1.9 draw. Relabel it "weight (reserved — inert in M1.9)."
- **Exclusivity lives on the def, not the deck.** "Charger/Splitter band-2-exclusive" is realized by `min_band = 2` **on `charger.tres`/`splitter.tres`** (S6a/S6b author it); the 4 shipped defs carry `min_band = 1`. The deck lane filters `band.band_depth ≥ def.min_band`, so band_two (2) includes all six and band 1 — which uses the **legacy lane (empty deck)**, never the deck lane — never sees charger/splitter regardless. The clean A/B holds structurally.
- **Draw order = the array order** `[pursuer, pingpong, bomb, spike, charger, splitter]` as authored (this ordering is the band author's priority list, per S3 `_deck_order`).

### R-Flavors — S7's flavor value tables must match S5's ACTUAL config schemas (RESOLVED, technical — this is the biggest correction)

S7 §3.4/§3.7's flavor params were written against a mental model that **does not match S5's as-designed stages**. Reconcile to S5's real schemas (S5 §3.1, §4.1):

**SetPieceInject — S7's `{defs, max, min_depth_norm, salt}` is wrong. Use S5's `SetPieceInjectConfig`:**
```
SetPieceInjectConfig:  entries: Array[SetPieceEntry]   max_total: int   salt: int (0x53455450)
SetPieceEntry:         piece: ZonePieceData   min_depth_norm: float   max_per_band: int   unique: bool
```
- `defs` → **`entries`** (`Array[SetPieceEntry]`); `max` → **`max_total = 1`**; `min_depth_norm = 0.6` lives **on the `SetPieceEntry`**, not the config.
- **Mechanism correction (load-bearing):** S5 does **NOT** "swap" or "mark" an in-spine piece. It **appends a brand-new set-piece as a dead-end room attached to a depth-gated retained open socket** (`band.open_sockets`, filtered to `host.depth_norm ≥ min_depth_norm`, via the untouched grow-loop helpers). So S7 §3.4's "swap/mark," §3.7's "walks pieces … to swap/mark," and the whole "Marking vs swapping" framing (§3.7.4) are **not** how S5 works — delete them. The set-piece is a **real appended room**, `MUTATES_PIECES = true`, and it *does* move band_two's fingerprint deterministically (correct and fine — it's not greybox's fingerprint).
- **§3.7.5 ("set-piece cells exempt from WearDecay") is an invented mechanism** — S5 has no set-piece/decay-exemption hook. **Delete it.** Reachability of the dead-end set-piece is protected by **S5's Stage-5 connectivity guarantee**, not an exemption: a WearDecay block on the set-piece's sole attaching doorway would strand it and is therefore **rejected/reverted** by the connectivity check (and blocks only ever land behind a prior breach on a tree band anyway — see below). No special-casing needed.
- **What S7 actually authors:** one `SetPieceEntry` wrapping an **existing** large piece scene (room_xl or chamber — no bespoke scene, per OQ3 recommendation), `min_depth_norm = 0.6`, `max_per_band = 1`, `unique = true`; `SetPieceInjectConfig.max_total = 1`.

**WearDecay — S7's `{state, intensity, block_routes, open_breaches, salt}` is wrong. Use S5's `WearDecayConfig`:**
```
WearDecayConfig:  state: StringName (&"collapsed"|&"flooded")   decay_level: float
                  breach_budget: int   block_budget: int   depth_bias: float
                  breach_width: int (2)   salt: int (0x57454152)
```
- There is **no** `intensity`, `block_routes`, or `open_breaches` field. Map S7's intent onto the real knobs: "how decayed" → **`decay_level`** (S5 default 0.5); "may block a path" → **`block_budget`**; "may open a shortcut" → **`breach_budget`**. `intensity 0.25` → set `decay_level ≈ 0.3` (modest) instead.
- **Breach-led, not block-led (S5 §4.2 — a structural fact, not a preference):** band_two is a **tree** (linear or branchy — still acyclic; `loop_back_count = 0`, confirmed in `bandgen_config`). On a tree **every doorway is a bridge**, so a block with no prior breach *always* disconnects and is *always* rejected. Blocks land **only** where a breach first created a cycle. **Therefore band_two's decay is breach-led** (secret-shortcut energy) with occasional detour-blocks behind breaches. Authoring consequence: to get *any* blocks, `breach_budget > 0` must lead; a `block_budget > 0, breach_budget = 0` config is a legal no-op (S5 logs a warning). This is exactly the "WearDecay is breach-led on tree bands" reconciliation the brief calls for.
- **`&"disused"` (§3.4, Pitch C) is not a defined S5 state.** S5 defines only `&"collapsed"` (default) and `&"flooded"`. Map Pitch C to `&"collapsed"`; if a distinct "disused" fiction is wanted it needs an S5 state-tag addition (out of S7 scope) — recommend just using `&"collapsed"` for Pitch C.
- **Reconciled band_two WearDecay value table (Pitch A "The Sump" / flooded):** `state = &"flooded"`, `decay_level = 0.3`, `breach_budget = 2`, `block_budget = 1` (breach-led), `depth_bias = 0.0` (uniform; raise later if deep-is-more-ruined is wanted), `breach_width = 2`, `salt = 0x57454152`.
- **Flavor order** `[SetPieceInject, WearDecay]` is correct and matches S5's authored guidance (inject the landmark, then decay can ruin it, then Stage-5 connectivity runs last). Keep it.

### R-OQ1-schema — BandProfile `tileset`/`palette_tint` fields (RESOLVED, technical)

**Decision:** **S7 (or a coordinated S1 addition) must add the `tileset: TileSet` and `palette_tint: Color` exports** — they are **not** guaranteed to exist. **Correction to §2.3/OQ1's "if S1 shipped it":** at authoring time **S1 is unbuilt** (`Game/systems/bandgen/band_profile.gd` and `Game/data/bands/band_greybox.tres` do not exist yet), so nothing can be "checked against S1 as-built." The authoritative reference is the **breakdown's S1 goal field list** (`id, backend, backend_config, archetype+params, piece_pool, principles[], flavors[], depth_curve, junk_catalog, opposition_deck, band_depth`) — which **omits** `tileset` and `palette_tint`. So they must be added. This is a trivial two-export addition with **no save impact** (BandProfile is content, not saved state). Preferred owner: fold into S1's schema at S1-build time (one PR, one schema); fallback: S7 adds them under its glue seam. Field names as written (`tileset`, `palette_tint`) are fine.

### R-OQ4 — own reward curve vs shared (RESOLVED, technical, low-stakes)

**Decision:** **author the own curve `depth_curve_band_two.tres`** (per the spec's recommendation). Verified on merit:
- The shared `depth_curve.tres` greybox values were confirmed exactly as §2.1/§3.5 claim: **value 1.0→1.8, density 2.0→2.3, tier stepped 1→4** (`Game/systems/depth/depth_curve.tres`). So the deltas in §3.5 are honest.
- **Tier 2→5 is content-valid:** the shared junk pool (`Game/data/junk/`) actually stocks items at **tiers 1–5** (tier-5 items exist), so band_two's tier ceiling of 5 resolves to real loot and its floor of 2 legitimately excludes the two tier-1 items — "band 2 loot is better" lands without new items. (Had the pool topped out at tier 4, the tier-5 gate would silently yield nothing; it doesn't — safe.)
- Keep §3.5's numbers (value 1.15→2.1, density 2.2→2.6, tier 2→5). **No Director call needed** unless the Director wants band-2 loot held flat until the full I→loot coupling (M2) — surface that only as an optional note, not a blocker.

### R-OQ7 — shipped-hazard deck ids (RESOLVED, technical)

**Decision:** the 4 shipped-hazard ids are **`&"pursuer"`, `&"pingpong"`, `&"bomb"`, `&"spike"` — confirmed against the legacy telemetry kinds** (`&"pingpong"/&"bomb"/&"spike"` at `main_game.gd:359-363`; `&"pursuer"` documented as the R1 kill kind at `event_bus.gd:171`). Plus `&"charger"`/`&"splitter"` (S6a/S6b). S7's §3.6 ids are correct as written; the only integration step is confirming S0 stamps these exact ids on the `OppositionDef.tres` set (checked at S8/SG1). No Director call.

### Verified-correct claims (no change)

- `bandgen_config.tres` greybox column (target 12, branch 0.0, max_place 16, loop_back 0, soft_floor 80, max_band 8) — **confirmed exact** (`Game/data/bandgen_config.tres`); §3.3's band_two deltas (target 16, branch 0.15) are legitimate config-only changes.
- `piece_catalog_ext.tres` = **10 pieces**, ids exactly the §2.3 list; `piece_catalog.tres` = **6** — **confirmed**.
- `greybox.tres` = 2-tile atlas (0:0 floor, 1:0 wall), wall carries the 16×16 physics polygon on `physics_layer_0`, `collision_layer = 2`, 16px cells — **confirmed**; §4's retone constraints (identical geometry/physics/coords) are sound.
- `band_generator.gd:310` reads `cfg.branch_chance` as the M1 baseline path — **confirmed**; a branchy band is genuinely a config value.

---

## Director review queue (vision / tone / fun — NOT self-resolved)

Sharpened to one-line decisions with a recommendation. None gate the build's *mechanics* (all six share §3.2–§3.6); they shape identity/feel and can be dispositioned at the Wave-4 close-out.

- **D1 — Band identity pick.** Ship **Pitch A "The Sump"** (GDD-canonical band-2 "Temporal," sepia-amber, motivates both flavors), or the colder alternates **B "The Overflow"** (teal, flood-lean) / **C "The Annex"** (institutional green, order-not-decay)? **Rec: A.** *(Pitch C's `&"disused"` decay state would need an S5 state-tag add — see R-Flavors; C maps cleanest to `&"collapsed"`.)*
- **D2 — Difficulty step size (OQ2).** Is a whole band apart *felt* at the locked **+15%** budget bump (`I(2)=1.15`, 27 vs 24 credits), or should band 2 use a sharper multiplier / higher `BASE_CREDITS`? **Rec: ship +15% (fidelity to the TDD's locked +15%/band) and let SG2 deaths-by-band / run-length tell you whether to widen it — don't pre-tune.**
- **D3 — Set-piece: reuse vs bespoke (OQ3).** Prove the stage by **reusing** an existing large piece (room_xl/chamber) as the landmark (pure data, honors "content=data"), or author a **bespoke Sump set-piece** scene (reads far more like a distinct biome, but is new authored geometry — arguably outside M1.9's thesis)? **Rec: reuse for M1.9; log "bespoke Sump set-piece" as an M1.10/M2 content follow-up.**
- **D4 — Hazard exclusivity (OQ5 = breakdown OQ5).** Keep Charger/Splitter **band-2-exclusive** (`min_band=2` on their defs → clean SG2 A/B: band 1 = old, band 2 = old + 2 new), or also enable them in band 1's default preset now? **Rec: band-2-exclusive for M1.9; let SG3 decide whether they graduate into band 1.**
- **D5 — Band length vs band 1 (OQ6).** Run band_two **longer** (`target_piece_count = 16` vs greybox 12 — "deeper = more committing"), or **shorter** (a punchy ~15-min band per the GDD)? And does the level-scale preset (`lvl_room_count=30`) apply to band_two at all (S8 routing decides)? **Rec: ship `target=16` (slightly longer), keep the level-scale preset orthogonal, and let SG2 run-length telemetry guide it.**
- **D6 — Visual tier (OQ1 art sliver).** Ship **Tier 1 tint only** (zero art, guaranteed — `palette_tint` sepia), **Tier 2 retoned tileset** (one placeholder png + `greybox_band_two.tres`, richer), or **both**? **Rec: Tier 1 always (proves the data path with zero art risk) + Tier 2 if the environment-artist has budget this wave — they coexist.** *(The `tileset`/`palette_tint` schema fields themselves are RESOLVED above — must be added regardless of tier.)*

---

*Spec authored by game-director-designer for M1.9 S7. Design + data-spec only — no game code; the `.tres` values here are authored during S7's build. The programmer adds the one tileset-assign glue line; the environment-artist ships the retone/tint placeholder. Deviations from this spec go to `DESIGN_DEVIATIONS.md` for the Wave-4 close-out sweep. Open questions OQ2/OQ3/OQ5/OQ6 (and the OQ1 art-budget sliver) need the Director; OQ1-schema/OQ4/OQ7 are fresh-eyes-resolvable on technical merit.*
</content>
</invoke>
