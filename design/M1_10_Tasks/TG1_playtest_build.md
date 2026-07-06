# TG1 — M1.10 Playtest Build (Second-generation backend + Cave band + low-sightline oppositions — the architectures scale on their second axis, proven in-game)

**Task id:** TG1 · **Milestone:** M1.10 (Second Generation Backend + Cave Band + Low-Sightline Oppositions) · **Workstream:** the re-gate · **Wave:** 5 (after T0–T4 integrate)
**Assignee:** `qa-playtest-coordinator` (build assembly + verify matrix + changelog) + the orchestrator-owned itch publish
**dependsOn:** **T0–T4** (the full build phase) all Done + integrated on `main` (build-complete close-out `53e4658`; T4 merge `c066e1e`, T3 merge `bd798b6`, T1 merge `8da0b1f`)
**Companion docs:** `M1.10_Breakdown.md` (the one thing this version proves + the cross-cutting contracts + the Director ratifications D-RAT-1…9), `M1_9_Tasks/SG1_playtest_build.md` (the template this mirrors), the M1.9 changelog block (the previous shipped version, for the changelog delta), `M1_Tasks/M1_As_Built.md` (canonical APIs), `systems/save_manager.gd` (`META_SCHEMA_VERSION == 4`, `RUN_SCHEMA_VERSION == 1` — **unchanged in M1.10**).

> **This is the VERIFY + PUBLISH capstone of M1.10, not new gameplay.** M1.9 proved "new content on
> the existing machinery is data" (new defs + a new profile — same socket backend). M1.10 proves the
> harder half of each claim: a band built by a **genuinely different generator** (`CaveBackend`,
> cellular-automata caverns — no pieces, no sockets) slots in behind the same `BandPipeline` interface
> with the entire downstream stack (grade, junk, encounter population, materialisation, telemetry,
> debug menu) **reused unchanged**, and **two more oppositions** land as def + one new component each,
> with zero engine rework. TG1 (a) confirms every system boots + loads, (b) confirms the three permanent
> controls are still byte-identical (all-off `RunConfig` fp `e943ac9c8bc1`; `band_greybox` fp; `band_two`
> fp), (c) confirms the coverage discipline held (**91 knobs** + per-def params↔schema bijection now at
> **9 defs**), (d) confirms **no save-schema change** (META v4 / RUN v1), (e) confirms **all three portals
> route correctly** (band 1 = `band_greybox` control byte-identical; band 2 = The Sump; band 3 = The
> Warren, a distinct cave fp), and then hands the Director a playable build (published to itch) + the
> changelog for the re-gate (TG2/TG3).

---

## 1. Goal & design intent

**Goal:** verify **one runnable M1.10 build** that proves *the M1.9 architectures scale along their
second axis* — a band produced by a second, structurally-different generator (`CaveBackend`) and two
more oppositions ship almost entirely as data + one small reusable part each, reachable in-game via a
third hub portal, **without moving any of the three permanent controls by a single byte**.

**Design intent (one line):** *TG1 is the M1.10 integration + verification + publish capstone* — it
confirms the cave backend composes onto the existing pipeline + downstream, that the all-off `RunConfig`
fingerprint stays `e943ac9c8bc1` and both socket-band goldens (`band_greybox`, `band_two`) stay
byte-identical through the new dispatch, that the coverage assertion grew to 91 knobs + per-def bijection
at **9 defs** (not dropped), that the save schema did not bump, and that all three hub portals route
deterministically to their bands. The *feel* of The Warren — does the cave disorient productively or read
as lost, do the Ambusher tell + Burrower telegraph read as fair, is the 1.30 budget a felt step, does the
cost ledger hold the "content = data" price — is TG2/TG3 (telemetry + Director), rendered-only, correctly
human-deferred (§5).

---

## 2. What's already wired (the M1.10 T0–T4 work — do NOT rebuild)

TG1 inherits the integrated build phase. Key seams (verified present by §3):

- **T0 — CaveBackend + `CaveBandConfig` + pipeline backend dispatch.** The second generation backend
  (cellular-automata caverns) behind the one `BandPipeline` interface: seeded fill → N smoothing passes
  (integer CA) → keep-largest flood region → deterministic CARVE of secondary regions (sorted-region
  order) → entry-anchor selection → emit **synthetic `PlacedPiece`(s)** carrying `floor_cells` so `Band`'s
  data shape (and `fingerprint()`) is backend-agnostic. Chunk-partitioned (content-hashed `cave_` piece
  ids) so the depth economy is non-trivial. The pipeline's cave fail-loud is replaced by `_backend_for`
  dispatch; `BandProfile.validate()` grew a cave branch (the single cave+flavors fail-loud location).
- **T1 — Cave materialisation + backend-agnostic sealing + downstream verify.** `_materialise_band`
  extended so synthetic pieces with no authored scene build **greybox floor visuals + wall collision at
  runtime from `floor_cells`** (tint-ready via `palette_tint`); the **unedited `SocketSealer` is the single
  wall-writer for BOTH backends** — T0 guarantees data enclosure, T1 writes FLOOR tiles only, the sealer
  caps floor-facing void verbatim (byte-identical for socket bands). Gate snaps to nearest floor
  (D-RAT-7); walls are a 1-tile sealer shell over darkness (D-RAT-8). The whole downstream (DepthGrader
  anchors, JunkPlacer scatter, EncounterBuilder placement, camera/player collision, 2×2 throat) verified on
  cave output.
- **T2a — Ambusher (`ambusher.tres` + ONE `Concealment` component).** The loot-punisher: HIDDEN
  (`collision_layer = 0` true pass-through, faint floor tell) → ARMED (player inside trigger radius: tell
  flash) → POUNCE (one fast lunge, `kills`-gated fatal per D-RAT-2, generous authored tell) → EXPOSED
  (throw-killable window) → one-shot spent (dormant `re_hide_s` re-arm). Reuses `ProximityTrigger`,
  `ChargeLane`, `TelegraphFSM`, `LethalContact`, `ThrowInteraction`. Off by default; `band_three` deck only.
- **T2b — Burrower "Sinkmaw" (`burrower.tres` + ONE `BurrowCycle` component).** The rhythm area-denier:
  BURIED (invisible + un-hittable, `collision_layer = 0`; a **locked-at-telegraph** ground decal tracks the
  player at `track_speed`, ignoring walls) → TELEGRAPH (decal pulse, authored lead) → SURFACED (visible,
  lethal, throw-killable, `kill_radius = 34` per D-RAT-3/amendment-10, holds `surface_s`) → BURIED. Static
  pop on surface; BURIED→TELEGRAPH gated by an in-component `intersect_point` wall check so it never
  surfaces inside a wall. Reuses `TelegraphFSM`, `LethalContact`, `ThrowInteraction`. Off by default;
  `band_three` deck only. Proves the component model handles **phased vulnerability**.
- **T3 — `band_three.tres` "The Warren" (cave profile + deck + tint, as data).** `backend = "cave"`, a
  tuned `cave_config_band_three.tres` (56×56 · fill_pct 45 · smooth_passes 4 · wall_threshold 5 ·
  min_region_cells 24), `band_depth = 3` (→ instability 1.30 → 31-credit budget), deck
  **`[ambusher 6 · burrower 3 · splitter 4 · bomb 1]`** = 14 spawns (budget exactly 0, D-RAT-6), reward
  value 1.30→2.5 / tier 3→5, junk density ~1.0→1.3, blue-violet `palette_tint` ("The Warren", D-RAT-5),
  `flavors = []` mandatory (validate() fail-louds on cave flavors). **Authored as pure data — 0 production
  code lines** (the headline scalability ledger).
- **T4 — Third hub portal + `band_three` routing.** `interactable_id = &"portal_band_three"`, cave-teal
  glow `Color(0.30, 0.90, 0.65)` (D-RAT-9 at (110,-20)), prompt "Dive — The Warren", route key
  `&"band_three"` → `band_three` in `BAND_ROUTES`; the two existing portals byte-identical; `band_id`
  stamped on `run_started` (bespoke-code ledger = 1 line).

**Invariants held:** the three permanent controls stay byte-identical — all-off `RunConfig.new()` band fp
`e943ac9c8bc1`, `band_greybox` fp, `band_two` fp (all through the untouched socket path); the knob count
stays **91** (89 frozen legacy + `oppositions_enabled` + `param_overrides`) with the per-def params↔schema
bijection extended to **9 defs** (7 shipped + Ambusher + Burrower), never dropped; the save schema is
**unchanged** (META v4 / RUN v1 — band choice is run-state, not saved); no cave code on any socket path.

---

## 3. Verify matrix (M1.10)

TG1 is **done** only when this matrix passes. It separates **objective build checks**
(headless-automatable, each row naming the exact test/command) from **subjective feel read** (TG2/TG3 +
human — the rendered Warren experience). All commands run with `export PATH="$HOME/.local/bin:$PATH"`,
**one godot instance at a time** (import-lock deadlock if concurrent), tests as SCENES
(`godot --headless --path Game res://tests/<x>.tscn`). Run against the build-complete tree (`53e4658`,
== this worktree base); the one test-fixture correction below (`test_def_menu_coverage`, a stale
expectation) was validated on this worktree.

> **Environment:** godot 4.6.3.stable, headless, no display server — every row about *how The Warren looks
> / how the hazards feel* is Director-manual / render-time (§5). The objective rows below prove the build
> boots, loads all three bands + all 9 defs, keeps the three controls byte-exact, and routes all three
> portals.

### 3.1 Build integrity + all-off determinism (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Clean import | All scripts compile, no parse errors; `.godot` builds (T0–T4 code + defs + profiles) | `godot --headless --path Game --import` → exit 0 | **PASS** (exit 0) |
| CI smoke | M0 architecture spike healthy (autoloads, EventBus, seeded RNG, save stub) boots headless | `… --script res://tools/ci_smoke_test.gd` → "SMOKE OK" | **PASS** ("SMOKE OK — M0 architecture spike healthy", exit 0) |
| All-off fp (RunConfig) | All-off `RunConfig` default = 90-knob flat dict, staged/cleared on run boundary, BUG6 trap-free, default preset is the F1 stack + doesn't leak | `…/test_run_config.tscn` → "R0 OK" | **PASS** ("R0 OK — RunConfig all-off default verified (M1.0 baseline) … all 90 knobs … BUG6 detects all 4 traps … J1 make_default_play_preset() is the F1 stack … does NOT leak", exit 0) |
| Bandgen determinism (greybox control) | proc-gen reproducible across 9 seeds; sample seed 12345 → 12 pieces, fp `e943ac9c8bc1`; BUG3 socket-seal + R4 nav | `…/test_bandgen_determinism.tscn` → "BANDGEN OK" | **PASS** ("BANDGEN OK — determinism + connectivity verified across 9 seeds (sample seed 12345 → 12 pieces, fp=e943ac9c8bc1) … BUG3 SOCKET SEAL OK … R4 NAV OK", exit 0) |
| Band pipeline parity (greybox control) | orchestrated `BandPipeline` path fingerprint byte-matches direct `BandGenerator` across 9 seeds; fail-loud null/empty-profile paths (the stderr `push_error` lines are the test's own fail-loud assertions) | `…/test_band_pipeline_parity.tscn` → "PIPELINE PARITY OK" | **PASS** ("PIPELINE PARITY OK — BandPipeline byte-matches BandGenerator across 9 seeds (sample seed 12345 → 12 pieces, fp=e943ac9c8bc1)", exit 0) |

### 3.2 Coverage discipline + save schema (HEADLESS / inspection)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Config menu 91/91 | All 91 `RunConfig` knobs bound + reachable (89 legacy + `oppositions_enabled` + `param_overrides`); master/knob/enum edits flow; Reset returns the all-off baseline | `…/test_config_menu.tscn` → "CONFIG MENU OK" | **PASS** ("CONFIG MENU OK — CFG verified (91/91 knobs bound + reachable … Reset returns the all-off baseline)", exit 0) |
| Per-def coverage bijection + FBM19b deck surface | params↔schema bijection net fires on drift + duplicate ids; zero-defs build green; dotted override stamp + generic opposition rows + debug_dirty hygiene; FBM19b IN-DECK chip + tooltip + auto-expand honest — **incl. splitter's chip now surfacing BOTH `band_three` + `band_two` decks** | `…/test_def_menu_coverage.tscn` → "DEF MENU COVERAGE OK" | **PASS** ("DEF MENU COVERAGE OK — bijection net fires … FBM19b deck surface honest (IN-DECK chip + tooltip + auto-expand …) and the menu-staged charger/splitter knobs reach band_two's deck lane", exit 0) — **stale expectation corrected, see §3.7** |
| Opposition def schema — **9 defs** | 9 defs: params↔schema bijection, locked entry shape, mirror-parity vs RunConfig defaults, one trap-if-neutral per def, host contract (scene loads, expected root class_name, 'hazard' group, resolve_throw_death/get_def_id seam, id continuity) | `…/test_opposition_def_schema.tscn` → "DEF SCHEMA OK" | **PASS** ("DEF SCHEMA OK — **9 defs**: params↔param_schema bijection, locked entry shape … mirror-parity vs RunConfig.new() code defaults … one trap_if_neutral per def … host contract", exit 0) |
| Save schema unchanged | `META_SCHEMA_VERSION == 4`, `RUN_SCHEMA_VERSION == 1` — **no M1.10 bump** (band choice is run-state). No new migration / fixture. | inspect `systems/save_manager.gd` | **PASS** (META v4 / RUN v1; M1.10 touched no save code — band choice is per-dive run-state via the `dive_requested(band_id)` → `GameState` staging seam) |

### 3.3 Cave backend + The Warren, socket-band goldens byte-exact (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Cave backend determinism | CA caverns reproducible (same seed+profile → same fp twice; diff seed → diff fp); single connected FLOOR component; region-keep + deterministic CARVE across a seed matrix; player-scale (2×2 throat); sample seed 12345 → 49 pieces, max_depth 12, fp `d984fd8913bf` | `…/test_cave_backend.tscn` → "CAVE BACKEND OK" | **PASS** ("CAVE BACKEND OK — determinism + connectivity + player-scale verified across 9 seeds (sample seed 12345 → 49 pieces, max_depth=12, fp=d984fd8913bf)", exit 0) |
| Cave materialisation | cave-profile dive runs end-to-end (generate → materialise → junk + gate + spawns on FLOOR); wall collision closes the play space (no floor-adjacent void gap); snapped gate reachable; 2×2 throat; tint; **socket materialise byte-identical (zero synthetic hosts)** | `…/test_cave_materialise.tscn` → "CAVE MATERIALISE OK" | **PASS** ("CAVE MATERIALISE OK — closure + collision + determinism + anchors + snapped gate + 2×2 throat + downstream population + tint verified across 9 seeds; socket materialise byte-identical (zero synthetic hosts)", exit 0) |
| Band two profile (control) | "The Sump" loads, generates deterministically, stays connected through WearDecay, injects its vault, gates its deck across 9 seeds (the `band_two` golden fp control) | `…/test_band_two_profile.tscn` → "BAND_TWO OK" | **PASS** ("BAND_TWO OK — 'The Sump' profile loads, generates deterministically, stays connected through WearDecay, injects its deep vault, and gates its deck across 9 seeds", exit 0) |
| Band three profile + goldens + deck outcome | "The Warren" loads as a cave band, generates deterministically + stays connected + reaches the depth axis across 9 seeds; **keeps `band_greybox` AND `band_two` byte-identical**; deck spawns the D-RAT-6 outcome **(ambusher 6 / burrower 3 / splitter 4 / bomb 1 = 14) at the 31-credit budget** | `…/test_band_three_profile.tscn` → "BAND_THREE OK" | **PASS** ("BAND_THREE OK — 'The Warren' loads as a cave band, generates deterministically + stays connected + reaches the depth axis across 9 seeds, keeps band_greybox AND band_two byte-identical, and its deck spawns the D-RAT-6 outcome (ambusher 6 / burrower 3 / splitter 4 / bomb 1 = 14) at the 31-credit budget", exit 0) |

### 3.4 All three portals route (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Band routing — 3 routes | staging consume-on-read; `&"near"`/unknown → greybox control; `&"band_two"` → The Sump; `&"band_three"` → The Warren (**each a distinct fp**); `run_started band_id == route key` for **all three**; wipe-isolated | `…/test_band_routing.tscn` → "BAND_ROUTING OK" | **PASS** ("BAND_ROUTING OK — staging consume-on-read, &\"near\"/unknown → greybox control, &\"band_two\" → The Sump + &\"band_three\" → The Warren (each distinct fp), run_started band_id == the route key for all three routes, wipe-isolated", exit 0) |
| Hub contract — 3 portals / 4 interactables | dressed `hub.tscn` resolves paths + 4 walls + ground cells + **4 interactables**; portal 1 unchanged (`&"near"`, WHITE); portal 2 routes `&"band_two"` (Sump prompt, ember-orange); **portal 3 routes `&"band_three"` (The Warren prompt, cave-teal, (110,-20))** | `…/test_hub_contract.tscn` → "HUB_CONTRACT OK" | **PASS** ("HUB_CONTRACT OK — paths + 4 walls + 963 ground cells + **4 interactables**; portal 1 unchanged (&\"near\", WHITE), portal 2 routes &\"band_two\" (The Sump prompt, ember-orange, (220,-150) in-yard), portal 3 routes &\"band_three\" (The Warren prompt, cave-teal, (110,-20) in-yard)", exit 0) |

### 3.5 Opposition surface — the two new low-sightline natives (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Ambusher (T2a) | def card locked (min_band 3 / cost 2 / caps 2+6, params mirror DEFAULTS); all-off gate holds (fp `e943ac9c8bc1`, ambusher in no default lever/deck); HIDDEN non-lethal + un-hittable (layer 0 clean pass-through); arm radius reveals + joins hazard group; tell precedes pounce by the authored lead (exactly 1 telegraph row); locked lunge lane dodgeable; L5 kills gate + BUG6 latch fire once; EXPOSED window throw-killable; pounce ONE-SHOT (re_hide_s re-arms); Concealment RNG-free; deterministic deck placement | `…/test_ambusher.tscn` → "T2a OK" | **PASS** (full T2a OK line — all clauses above verified) |
| Burrower "Sinkmaw" (T2b) + binding riders | def card locked (min_band 3 / cost 2 / caps 1+3, params mirror DEFAULTS **incl `kill_radius 34`**); all-off gate holds (fp `e943ac9c8bc1`, burrower in no default lever/preset/greybox/band_two deck); BURIED→TELEGRAPH→SURFACED cycle on locked telemetry vocabulary; buried body passes a throw clean through + non-lethal; **dodge frame honored (locked decal — stepping off the lead is safe)**; surfaced catch kills-gated + throw-killable, BUG6 latch once (**first lethal test runs on the surfacing frame — the `kill_radius 34` rider**); **buried body crosses under walls + NEVER surfaces inside one (wall-clear surfacing rider)**; BurrowCycle RNG-free; co-located burrowers desync by position; deterministic deck placement | `…/test_burrower.tscn` → "T2b OK" | **PASS** (full T2b OK line — both T2b binding riders verified) |

### 3.6 Preset parity — the rg1 verifies (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| rg1 loop verify | full loop under all-off (V6 baseline); each opposition in isolation; all four stacked; four end-causes; JSONL config/opposition/event rows; carry-forward; reset-to-baseline; no soft-lock | `…/test_rg1_loop_verify.tscn` → "RG1 BUILD VERIFY OK" | **PASS** ("RG1 BUILD VERIFY OK … 16 matrix rows headless-verified; 6 deferred", exit 0) |
| rg1 M1.2 verify | all-off byte-identical (fp `e943ac9c8bc1`); build id real; level scale; depth-scaled catches; R2/R3/nav; exposure toll; sealed high-branch bands | `…/test_rg1_m12_verify.tscn` → "RG1 M1.2 VERIFY OK" | **PASS** (fp=e943ac9c8bc1; 14 rows verified; 6 deferred, exit 0) |
| rg1 M1.3 verify | all-off byte-identical; F1 stack no-leak; even_spread vs single_gate; per-room density; corridor lever; corridor_summary row | `…/test_rg1_m13_verify.tscn` → "RG1 M1.3 VERIFY OK" | **PASS** (fp=e943ac9c8bc1; PASS on attempt 1 — the known BUG-M13FLAKE headless intermittent did NOT trip; 16 rows verified; 6 deferred, exit 0) |
| rg1 M1.4 verify | all-off byte-identical; M1.4 fun stack (K4 timer + all 3 K5 hazards + K7 exits) trap-free no-leak; K5i spawn helper; end-causes; snapshot | `…/test_rg1_m14_verify.tscn` → "RG1 M1.4 VERIFY OK" | **PASS** (fp=e943ac9c8bc1; 11 rows verified; 7 deferred, exit 0) |
| rg1 M1.5 verify | all-off byte-identical; M1.4 stack + 3 M1.5 levers (throw/room-only/patrol); L1 throw seam; L2 spawn-room bounds; end-causes | `…/test_rg1_m15_verify.tscn` → "RG1 M1.5 VERIFY OK" | **PASS** (fp=e943ac9c8bc1; 12 rows verified; 7 deferred, exit 0) |

### 3.7 One red row caught + corrected — `test_def_menu_coverage` (stale test expectation, NOT a product bug)

On the first pass `test_def_menu_coverage` was **RED** (exit 1) with:

```
DEF MENU FAIL: (E) 'splitter' chip 'IN DECK: band_three, band_two · 0 tuned'
                != expected deck chip 'IN DECK: band_two · 0 tuned'
```

**Root cause — a stale test fixture, not a build regression.** This FBM19b deck-membership test
(`test_def_menu_coverage.gd`) hard-coded the expected IN-DECK chip string `IN DECK: band_two · 0 tuned`
for *both* `charger` and `splitter`. That was correct in M1.9, but **T3 correctly added `splitter` to The
Warren's deck** (D-RAT-6: `[ambusher 6 · burrower 3 · splitter 4 · bomb 1]`). The debug menu's IN-DECK
chip therefore now *correctly* surfaces that splitter lives in **both** decks — `IN DECK: band_three,
band_two`. The **product behavior is right**; the T3 wave simply didn't update this test's hard-coded
expectation (charger is band_two-only and still matched, so only splitter tripped).

**Fix (QA lane — test-only, no product change).** Replaced the single shared `want_chip` with a
per-id expectation map: `charger` → `band_two`, `splitter` → `band_three, band_two`. The tooltip and
auto-expand assertions were already passing (the tooltip lists both band display names, so it still
contains "The Sump"). Re-run on this worktree: **DEF MENU COVERAGE OK** (exit 0). Recorded as a design
deviation in the worklog. No production `.gd`/`.tres` was touched by TG1.

### 3.8 Did TG1 add a new `test_tg1_m110_verify`?

**No — consistent with SG1/HG1.** M1.10's non-rendered surface is fully covered by the purpose-built
T0–T4 tests: the cave backend has its own determinism/connectivity/fp guard (`test_cave_backend`) and an
end-to-end playability guard (`test_cave_materialise`); the two new oppositions have dedicated behavior
tests (`test_ambusher`, `test_burrower`, incl. the T2b binding riders); all three bands + all three routes
are asserted (`test_band_three_profile` — which also pins the two socket goldens — `test_band_routing`,
`test_hub_contract`); the coverage discipline has its own nets (`test_config_menu` 91/91,
`test_def_menu_coverage`, `test_opposition_def_schema` bijection at 9 defs); the three permanent controls
are pinned across every rg1 verify + `test_band_three_profile`. A consolidated verify test would only
re-instance the same scenes and re-assert the same facts — pure duplication with a concurrent-instance
risk. The remaining M1.10 surface is **rendered/felt** (does the cave disorient productively, do the
Ambusher/Burrower telegraphs land, is the 1.30 budget a felt step, do the cost ledgers hold the "content =
data" price) and headless cannot render or input-drive it — correctly deferred to §5 + TG2/TG3. **No new
verify test committed; one stale expectation corrected (§3.7).**

---

## 4. Objective result summary

**All §3 rows PASS** (the one initially-red row was a stale test expectation, corrected in §3.7 — no
product bug; product behavior was already correct). The three permanent controls are byte-identical — the
all-off `RunConfig` fp is `e943ac9c8bc1` through the new cave dispatch and across every rg1 verify, and
both socket goldens (`band_greybox`, `band_two`) are asserted byte-identical by `test_band_three_profile`.
The cave backend is deterministic + connected (sample seed 12345 → fp `d984fd8913bf`), materialises to a
playable end-to-end cave, and keeps socket materialisation byte-identical. The coverage discipline is
**91/91 knobs** with the per-def params↔schema bijection green for all **9 defs**; the save schema is
**unchanged** (META v4 / RUN v1, no new migration); **all three portals route deterministically** (band 1
= `band_greybox` control, band 2 = The Sump, band 3 = The Warren, each a distinct fp with `band_id`
stamped on runs); The Warren's deck spawns the exact D-RAT-6 outcome (ambusher 6 / burrower 3 / splitter 4
/ bomb 1 = 14) at the 31-credit budget; both new oppositions pass their behavior + cap + determinism tests
including the T2b `kill_radius 34` surfacing-frame + wall-clear-surfacing riders. The known BUG-M13FLAKE
did not trip (PASS on attempt 1). The objective M1.10 gate is met; the feel read is human-deferred (§5).

---

## 5. Director playtest checklist (The Warren — render-time, human only)

Open the published build (Chrome/Edge, password-gated), boot → Main Menu → NEW GAME, stand in the hub. Then:

- **Three dive gates now sit in the yard.** The original (band 1), the ember-orange "Dive — The Sump", and
  a new cave-teal "Dive — The Warren". Confirm the two original gates still dive into the **same band 1**
  and **The Sump** — nothing about their generation, hazards, or pacing should feel different from M1.9
  (they're the controls). **Portal-3 composition eyeball (D-RAT-9):** portal 3 sits at (110, -20), a
  forward-staggered second rank — judge the plaza composition, and note the spawn→portal-2 transit crosses
  portal 3's interact rect (a known caveat of any second-rank slot).
- **The Warren reads as a cave, not a building.** Dive The Warren. Does it read as *grown, not built* —
  blobby rounded chambers instead of square rooms, winding throats instead of straight halls, bad
  sightlines, nooks and dead-ends to poke into for loot, the blue-violet tint? Is the different *kind* of
  generation legible against band 1 / The Sump, or does it just feel like a differently-tinted socket band?
- **Does the cave disorient productively, or read as lost?** The b3 identity is "bad sightlines as the
  play identity." Is the disorientation *tense and interesting* (you push carefully, you get surprised
  fairly), or does it tip into *frustrating* (you can't find the gate, you feel lost rather than
  pressured)? This is the core TG2/TG3 watch-item — depth signposting in caves is harder than a spine.
- **The Ambusher — greed near a hidden trap.** Loot near a faint floor tell and watch it ARM (tell flash)
  then POUNCE. Does the tell read in time to step clear (fair), or does it feel like a cheap gotcha? Confirm
  it's a **one-shot** (spent after it springs). Confirm a thrown item **kills it in the EXPOSED window**.
- **The Burrower "Sinkmaw" — the rhythm area-denier.** Meet a Burrower. While it's BURIED you can't hit it
  and it can't hit you — it tracks you as a floor decal. Does the TELEGRAPH → locked-spot → SURFACE rhythm
  read as fair (you can always step off the locked spot before it strikes)? Confirm you **can't kill it
  while buried** and that you punish it in the surfaced window (throw or contact-avoid). Does the
  "un-hittable while buried" counter-lesson land, or feel unfair?
- **P-menu Oppositions tab.** Press **P → Oppositions tab**. Confirm every hazard exposes its tuning params
  (generated from `param_schema`) — including the two new natives, marked **IN DECK** for The Warren and
  pre-expanded. Tune a param (e.g. the Burrower tempo or the Ambusher tell lead) and **respawn** to feel it
  live; note the run is flagged **debug-dirty** (filtered from the honest TG2 telemetry cohort).
- **Export telemetry.** After a few dives across all three portals, press the in-game **Export telemetry**
  button (P → Meta tab) to download the run log for TG2's three-band analysis (`band_id` is stamped on
  every `run_started` row — `near` / `band_two` / `band_three`).
- **Placeholder caveat.** The Warren's floor/walls are **greybox geometry + a tint pass**, not a bespoke
  cave tileset; the hazards are placeholder sprites. Judge the *layout / disorientation / hazard fun /
  difficulty step*, not the pixel-craft. The portal-3 glow currently reads a **deeper cyan-blue** than the
  intended cave-teal over the placeholder portal art (a pending retone).

**Deferred (not in this build):** the cave generator is **The Warren only** (bands 1 + The Sump are the
unchanged socket controls — a clean A/B for TG2); the Ambusher + Burrower are **Warren-only**; the cave
look is **greybox + tint**, not a tileset; there's **no higher-tier loot** down there yet; the portal-3
glow **awaits an art retone**; no save change (band choice is per-dive, not persisted).

---

## 6. Publish + changelog

- **changelog.txt** — updated by TG1 with an **M1.10 — "The Warren"** block documenting the M1.9→M1.10
  delta as a clean **feature list** (per the changelog scope rule — feature list, not a fix log, delta from
  the previous shipped version `m1-20260704-55ca78f`): the third dive portal + The Warren band (a NEW
  cavern generator — organic cellular-automata caves, blobby chambers, bad sightlines, nook-rich, a step
  deeper with a heavier budget), the two Warren-only hazards (the Ambusher floor-trap loot-punisher, the
  Burrower "Sinkmaw" underground rhythm area-denier), and a one-line note that the debug Oppositions tab now
  tunes both. Intra-M1.10 fixes are folded into each feature's final-state description, not listed. A "NOT
  YET IN THIS BUILD" note flags: the cave generator is band-3-only (bands 1–2 unchanged), the portal-3
  cave-teal glow reads deep cyan-blue pending an art retone, cave floor/walls are greybox+tint (no bespoke
  tileset), no higher-tier loot yet, both hazards Warren-only, and the unchanged save.
- **Publish to itch** — **orchestrator-owned, run from `main` after this changelog + doc merge** (this
  worktree does NOT hold `APIKEYS.md`). Command:
  `BUTLER=/mnt/c/wsl-libraries/butler/butler bash Game/tools/push_itch.sh` (stamp → export Web preset →
  `butler push qusto/the-far-yard:html5`). The godot web-export exit-crash after "DONE savepack" is
  HARMLESS (the script gates on artifact existence, not the exit code). Live page:
  `https://qusto.itch.io/the-far-yard` (Chrome/Edge only — SharedArrayBuffer/COEP; password-gated). Web
  telemetry returns via the in-game "Export telemetry" button (P → Meta tab).

### 6.1 Publish record

- **PUBLISHED 2026-07-05** (orchestrator-run from `main` after merging this worktree's changelog + doc +
  test-fixture correction; merge `3c9644e`).
  - **userversion:** `m1-20260705-3c9644e` (`BuildVersion.short_sha == 3c9644e`, stamped by `stamp_build.sh`).
  - **butler:** `pushed qusto/the-far-yard:html5 @ m1-20260705-3c9644e` — channel `html5`, upload
    `#18000582`, build **`#1775187`** ✓ processed (from `#1773505`; 98.88% patch savings). One mid-upload
    network flap (10.0.0.1:443 i/o timeout) auto-retried by butler and completed; the initial
    `push_itch.sh` run's wharf POST timed out on the same flaky endpoint, so the upload was re-driven
    directly on the intact export (export is deterministic; same artifacts).
  - **Live page:** https://qusto.itch.io/the-far-yard (password-gated; **Chrome/Edge only** — SharedArrayBuffer COEP).
- **SUPERSEDED 2026-07-06 by FBM-A1** (Ambusher rework — hide-pursue-pounce stalker; Director playtest feedback):
  republished `qusto/the-far-yard:html5 @ m1-20260706-8e3a888`, build **`#1775586`** (from `#1775187`), merge
  `8e3a888`. Same verify matrix (Ambusher rows updated for the stalker behavior; all-off fp `e943ac9c8bc1`,
  9-def bijection, smoke — all green). This is the current playtest build.

---

## 7. Acceptance criteria (M1.10 / TG1)

1. **A fresh build boots, reaches the hub with all three portals, and the complete loop + all three dives
   run end-to-end** — all §3 objective rows green.
2. **The three permanent controls reproduce their baselines exactly** — all-off `RunConfig` fp
   `e943ac9c8bc1` unmoved through the new cave dispatch and every rg1 verify; `band_greybox` and `band_two`
   fingerprints byte-identical (asserted by `test_band_three_profile`).
3. **The cave backend is deterministic, connected, and playable** — `test_cave_backend` (fp
   `d984fd8913bf`) + `test_cave_materialise` (end-to-end, socket materialise byte-identical).
4. **The coverage discipline held** — 91/91 knobs + per-def params↔schema bijection for all **9 defs**
   (grown, not dropped).
5. **No save-schema change** (META v4 / RUN v1; band choice is run-state; existing migrations stand, no new
   fixture).
6. **All three portals route deterministically** (band 1 = `band_greybox` control byte-identical; band 2 =
   The Sump; band 3 = The Warren; each a distinct fp; `band_id` stamped on runs).
7. **The two new oppositions + The Warren pass their behavior/cap/determinism tests** (incl. the T2b
   `kill_radius 34` surfacing-frame + wall-clear-surfacing riders, and The Warren's exact D-RAT-6 deck
   outcome), shipped almost entirely as data (the "content = data on a second axis" proof — TG3 judges the
   true cost via the ledgers).
8. The build + this doc + the updated changelog are **ready for the Director's playtest** (published to
   itch by the orchestrator from `main`), with the Warren *feel* correctly human-deferred (§5) and
   telemetry analysis owned by TG2.

A build that passes the §3 matrix (all rows green, the one stale-expectation row corrected + re-green) +
ships the changelog + is published to itch satisfies TG1. Done means: the matrix is filled, the worklog
names the commit SHA, the build boots to a hub with three working portals, the three controls are
byte-identical, the coverage/save invariants hold, and the itch push is confirmed (by the orchestrator from
`main`).
