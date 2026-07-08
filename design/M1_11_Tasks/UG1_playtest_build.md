# UG1 — M1.11 Playtest Build (Third-generation backend + Open-Field band + Ranged oppositions — the seams hold at N = 3, proven in-game)

**Task id:** UG1 · **Milestone:** M1.11 (Third Generation Backend + Open-Field Band + Ranged Oppositions) · **Workstream:** the re-gate · **Wave:** 5 (after U0–U4 integrate)
**Assignee:** `qa-playtest-coordinator` (build assembly + verify matrix + changelog) + the orchestrator-owned itch publish
**dependsOn:** **U0–U4** (the full build phase) all Done + integrated on `main` (Wave-1 integration `fb3435d`/`4ff5c49`/`7cbe50f`; U1 `main` merge, U3 `2e43902`, U4 `0a12c25`; wave close-out record `b149268`)
**Companion docs:** `M1.11_Breakdown.md` (the one thing this version proves — *the seams hold at N = 3, with declining marginal cost* — the cross-cutting contracts + the Director ratifications D-RAT-1…8 + Phase-3 amendments 1–13), `M1_10_Tasks/TG1_playtest_build.md` (the template this mirrors), the M1.10 changelog block (the previous shipped version, for the changelog delta), `M1_Tasks/M1_As_Built.md` (canonical APIs), `systems/save_manager.gd` (`META_SCHEMA_VERSION == 4`, `RUN_SCHEMA_VERSION == 1` — **unchanged in M1.11**).

> **This is the VERIFY + PUBLISH capstone of M1.11, not new gameplay.** M1.10 proved a genuinely
> different generator (`CaveBackend`, cellular-automata caverns) slots in behind the one
> `BandPipeline` interface. M1.11 proves the pattern is now **routine**: backend #3
> (`ScatterBackend` — no pieces, no CA, a poisson-scattered open arena) rides the **already
> backend-agnostic** materialisation path M1.10 built (U1's ride-through cost **1 line**), and
> **two more oppositions** land on a threat axis nothing shipped exercises — **at-range /
> projectile threat** (all 9 prior defs are contact-lethal) — as def + one new component each,
> zero engine rework. UG1 (a) confirms every system boots + loads, (b) confirms the **FOUR**
> permanent controls are still byte-identical (all-off `RunConfig` fp `e943ac9c8bc1`;
> `band_greybox`; `band_two`; and — new this version — `band_three`, M1.10's cave band now
> itself a golden control), (c) confirms the coverage discipline held (**91 knobs** + per-def
> params↔schema bijection now at **11 defs**), (d) confirms **no save-schema change** (META v4 /
> RUN v1), (e) confirms **all FOUR portals** route correctly (band 1 = `band_greybox` control;
> band 2 = The Sump; band 3 = The Warren; band 4 = The Far Field, a distinct scatter fp), and
> then hands the Director a playable build (published to itch) + the changelog for the re-gate
> (UG2/UG3).

---

## 1. Goal & design intent

**Goal:** verify **one runnable M1.11 build** that proves *the M1.9/M1.10 architectures now scale
routinely at N = 3* — a band produced by a third, structurally-different generator
(`ScatterBackend`) and two more oppositions ship almost entirely as data + one small reusable
component each, reachable in-game via a fourth hub portal, **without moving any of the four
permanent controls by a single byte**.

**Design intent (one line):** *UG1 is the M1.11 integration + verification + publish capstone* — it
confirms the scatter backend composes onto the existing pipeline + the backend-agnostic downstream,
that the all-off `RunConfig` fingerprint stays `e943ac9c8bc1` and all three prior-band goldens
(`band_greybox`, `band_two`, `band_three`) stay byte-identical through the new dispatch, that the
coverage assertion grew to 91 knobs + per-def bijection at **11 defs** (not dropped), that the save
schema did not bump, and that all four hub portals route deterministically to their bands. The
*feel* of The Far Field — does the open field read as *tense* or *empty*, does the 1.45 budget step
land, do the Lobber marker + Sentry windup read as fair, is the lane a felt highway, does the
exposed-center loot create a risk/reward pull — is UG2/UG3 (telemetry + Director), rendered-only,
correctly human-deferred (§5).

---

## 2. What's already wired (the M1.11 U0–U4 work — do NOT rebuild)

UG1 inherits the integrated build phase. Key seams (verified present by §3):

- **U0 — ScatterBackend + `ScatterBandConfig` + pipeline backend dispatch.** The third generation
  backend (order-stable poisson/blue-noise cover-stamping on an open arena) behind the one
  `BandPipeline` interface: forced WALL border ring → stratified grid-jitter poisson sampling with
  a fixed-length `1 + 4·S` RNG stream (sorted candidate order, unconditional per-stratum draw) →
  stamp ≤2×2 cover footprints as NON-floor → **connectivity + 2×2 player-scale by construction**
  (Chebyshev `min_cover_spacing >= 3` dilation, `border_margin >= 2`, full-width seed-drawn clear
  lane — **no carve pass, no retry**) → **chunk partition** (content-hashed `scat_` synthetic piece
  ids, reusing the cave chunking idiom so `max_depth >= 4` holds) → lane-aligned entry anchor,
  front-positioned. The pipeline's scatter fail-loud is replaced by real dispatch; `BandProfile.validate()`
  gained the scatter branch (flavors fail-loud). **Cost ledger: ~327 non-comment lines — ~30% LESS
  than the cave backend measured identically.** Touches only `systems/bandgen/` + `data/bands/*.gd`
  schema + its tests — NOT `main_game.gd`.
- **U1 — Scatter materialisation ride-through + downstream verify.** The version's thesis proven:
  the whole cave materialisation path (`_build_synthetic_piece`, the unedited `SocketSealer` capping
  both the arena perimeter AND every cover footprint for free, entry spawn, depth/junk/encounter
  placement, tint, collision) hosted scatter output with **EXACTLY 1 changed production line** —
  the `_pinned_gate_pos` snap guard flipped denylist→allowlist (`main_game.gd:1081`, ratified
  Phase-3 amendment 3) so a scatter band's pinned gate snaps to floor (fixing a latent softlock at
  legal schema corners). `test_scatter_materialise` proves M1–M9 (collision closure via exhaustive
  point queries, fp/floor_fp byte-equal pre/post, snapped-gate reachability, 2×2 spawn→gate cert,
  junk/encounters on floor) across the 9-seed matrix. **U1 cost ledger: 1 line — the version's
  headline evidence.**
- **U2a — Lobber "The Mortar" (`lobber.tres` + ONE `MortarCycle` component).** The stand-still
  punisher: AIM (fire period elapses, reads player pos, `lead_factor 0` = lands where you stood) →
  IN-FLIGHT (ground-circle marker LOCKED at fire time — the fairness contract; `arc_time` flight is
  the dodge window) → IMPACT (centre-in-radius blast, `kills`-gated via the reused `LethalContact
  &"external"` seam) → cycle. **The arc IGNORES geometry** (cover does NOT protect — keep moving
  does). Card `credit_cost 2 · per_room_cap 1 · per_band_cap 5 · min_band 4`. Reuses `TelegraphFSM`,
  `ThrowInteraction` (throw-killable). Off by default; `band_four` deck only.
- **U2b — Sentry (`sentry.tres` + ONE `LaneWatch` component).** The lane-denier: a **stationary**
  emplacement watching one straight lane — IDLE (lane telegraph always-visible, D-RAT-4) → WINDUP
  (player centre crosses the lane: flash, authored lead) → FIRE (fast component-owned bolt down the
  locked lane; wall/cover-blocked, no pierce) → COOLDOWN (the crossable gap) → IDLE. Lane acquired
  on the **SECOND** `tick()` (amendment A1 — a first-tick latch races the just-built broadphase),
  with the derived clear **length latched with the direction**. **A throw KILLS it permanently**
  (`ThrowInteraction &"die"` — "spend an item to open a route forever", D-RAT-4). Card `credit_cost
  2 · per_room_cap 1 · per_band_cap 5 · min_band 4`. Off by default; `band_four` deck only. Proves
  the component model handles **at-range threat + projectile emission** — an axis no shipped def
  exercises.
- **U3 — `band_four.tres` "The Far Field" (scatter profile + deck + curve + tint, as data).**
  `backend = "scatter"`, a tuned `scatter_config_band_four.tres` (64×64 · cover_density_pct 8 ·
  min_cover_spacing 4 · border_margin 2 · cover weights 4/1/1/1 · edge_cover_bias_pct 60 ·
  clear_lane_width 3 · chunk_cells 8 · 16 px — **sparse-deadly**, long sightlines), `band_depth = 4`
  (→ instability 1.45 → 34-credit budget), deck **`[lobber 5 · sentry 5 · charger 4 · bomb 6]`** =
  20 spawns (budget exactly 0, D-RAT-6; 50% ranged, bombs the remainder sponge), reward value
  1.45→2.9 / tier 4→5, junk density 1.0→1.2 (measured band-total ≈ 71 items, value-carried not
  count-carried), cold-indigo `palette_tint Color(0.42, 0.46, 0.62)` ("a wrong, too-open expanse",
  D-RAT-5), `flavors = []` mandatory (validate() fail-louds on scatter flavors). **Authored as pure
  data — 0 production code lines** (the N=3 scalability ledger, flat at zero from backend #2 onward).
- **U4 — Fourth hub portal + `band_four` routing.** `interactable_id = &"portal_band_four"`,
  saturated-indigo glow `Color(0.15, 0.25, 1.0)` (D-RAT-5/amendment-9) at the D-RAT-9 reserved
  mirror slot **(-110, -20)** (opposite portal 3), prompt "Dive — The Far Field", route key
  `&"band_four"` → `band_four` in `BAND_ROUTES`; the three existing portals byte-identical; `band_id`
  stamped on `run_started`. **Bespoke-code ledger = 1 line** (the `BAND_ROUTES` row) + a 9-line
  additive hub scene block. **The plaza is now FULL — the hub contract pins exactly 5 interactable
  ids (set equality), so band 5 deliberately starts red as the band-select forcing function.**

**Invariants held:** the four permanent controls stay byte-identical — all-off `RunConfig.new()`
band fp `e943ac9c8bc1`, `band_greybox` fp, `band_two` fp, `band_three` fp (all through their
untouched paths); the knob count stays **91** (89 frozen legacy + `oppositions_enabled` +
`param_overrides`) with the per-def params↔schema bijection extended to **11 defs** (9 shipped +
Lobber + Sentry), never dropped; the save schema is **unchanged** (META v4 / RUN v1 — band choice is
run-state, not saved); no scatter code on any socket/cave path.

---

## 3. Verify matrix (M1.11)

UG1 is **done** only when this matrix passes. It separates **objective build checks**
(headless-automatable, each row naming the exact test/command) from **subjective feel read** (UG2/UG3
+ human — the rendered Far Field experience). All commands run with
`export PATH="$HOME/.local/bin:$PATH"`, **one godot instance at a time** (import-lock deadlock if
concurrent), tests as SCENES (`godot --headless --path Game res://tests/<x>.tscn`). Run 2026-07-08
against the wave-close-out tree (`b149268`, == this worktree base).

> **Environment:** godot 4.6.3.stable, headless, no display server — every row about *how The Far
> Field looks / how the ranged hazards feel* is Director-manual / render-time (§5). The objective
> rows below prove the build boots, loads all four bands + all 11 defs, keeps the four controls
> byte-exact, and routes all four portals.

### 3.1 Build integrity + all-off determinism (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Clean import | All scripts compile, no parse errors; `.godot` builds (U0–U4 code + defs + profiles) | `godot --headless --path Game --import` → exit 0 | **PASS** (exit 0) |
| CI smoke | M0 architecture spike healthy (autoloads, EventBus, seeded RNG, save stub) boots headless | `… --script res://tools/ci_smoke_test.gd` → "SMOKE OK" | **PASS** ("SMOKE OK — M0 architecture spike healthy", exit 0) |
| All-off fp (RunConfig) | All-off `RunConfig` default = 90-knob flat dict, staged/cleared on run boundary, BUG6 trap-free, default preset is the F1 stack + doesn't leak | `…/test_run_config.tscn` → "R0 OK" | **PASS** ("R0 OK — RunConfig all-off default verified … all 90 knobs … BUG6 detects all 4 traps … J1 make_default_play_preset() is the F1 stack … does NOT leak", exit 0) |
| Bandgen determinism (greybox control) | proc-gen reproducible across 9 seeds; sample seed 12345 → 12 pieces, fp `e943ac9c8bc1`; BUG3 socket-seal + R4 nav | `…/test_bandgen_determinism.tscn` → "BANDGEN OK" | **PASS** ("BANDGEN OK — determinism + connectivity verified across 9 seeds (sample seed 12345 → 12 pieces, fp=e943ac9c8bc1) … BUG3 SOCKET SEAL OK … R4 NAV OK", exit 0) |
| Band pipeline parity (greybox control) | orchestrated `BandPipeline` path fingerprint byte-matches direct `BandGenerator` across 9 seeds; fail-loud null/empty/scatter/cave-config paths (the stderr `push_error` lines are the test's own fail-loud assertions, now incl. the scatter branch) | `…/test_band_pipeline_parity.tscn` → "PIPELINE PARITY OK" | **PASS** ("PIPELINE PARITY OK — BandPipeline byte-matches BandGenerator across 9 seeds (sample seed 12345 → 12 pieces, fp=e943ac9c8bc1)", exit 0) |

### 3.2 Coverage discipline + save schema (HEADLESS / inspection)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Config menu 91/91 | All 91 `RunConfig` knobs bound + reachable (89 legacy + `oppositions_enabled` + `param_overrides`); master/knob/enum edits flow; Reset returns the all-off baseline | `…/test_config_menu.tscn` → "CONFIG MENU OK" | **PASS** ("CONFIG MENU OK — CFG verified (91/91 knobs bound + reachable … Reset returns the all-off baseline)", exit 0) |
| Per-def coverage bijection + FBM19b deck surface | params↔schema bijection net fires on drift + duplicate ids; zero-defs build green; dotted override stamp + generic opposition rows + debug_dirty hygiene; FBM19b IN-DECK chip + tooltip + auto-expand honest; the count-agnostic band-scan picked up `band_four` for free | `…/test_def_menu_coverage.tscn` → "DEF MENU COVERAGE OK" | **PASS** ("DEF MENU COVERAGE OK — bijection net fires … FBM19b deck surface honest …", exit 0) — the U3-flagged charger-golden drift (`IN DECK: band_four, band_two`) is resolved on `main`; green here |
| Opposition def schema — **11 defs** | 11 defs: params↔schema bijection, locked entry shape, mirror-parity vs RunConfig defaults, one trap-if-neutral per def, host contract (scene loads, expected root class_name, 'hazard' group, resolve_throw_death/get_def_id seam, id continuity) | `…/test_opposition_def_schema.tscn` → "DEF SCHEMA OK" | **PASS** ("DEF SCHEMA OK — **11 defs**: params↔param_schema bijection, locked entry shape … mirror-parity vs RunConfig.new() code defaults … one trap_if_neutral per def … host contract", exit 0) |
| Save schema unchanged | `META_SCHEMA_VERSION == 4`, `RUN_SCHEMA_VERSION == 1` — **no M1.11 bump** (band choice is run-state). No new migration / fixture. | inspect `systems/save_manager.gd` + `test_save_migration.tscn` | **PASS** (META v4 / RUN v1; SAVE MIGRATION OK — v1/v2/v3 meta fixtures all migrate to v4 with `.bak` preserved; M1.11 touched no save code — band choice is per-dive run-state via `dive_requested(band_id)` → `GameState` staging) |

### 3.3 Scatter backend + The Far Field, prior-band goldens byte-exact (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Scatter backend determinism + openness | poisson-cover arena reproducible (same seed+profile → same fp twice; diff seed → diff fp); single connected FLOOR component; cover never disconnects across a seed matrix; player-scale 2×2 throat; chunk `max_depth >= 4`; **long-sightline identity bar** (openness percentile calibrated); sample seed 12345 → 35 pieces, max_depth 9, fp `44a9a9b3756f`; validate() clamps (the stderr `push_error` lines are the test's own fail-loud assertions on the degenerate config) | `…/test_scatter_backend.tscn` → "SCATTER BACKEND OK" | **PASS** ("SCATTER BACKEND OK — determinism + connectivity + player-scale + sightline identity verified across 9 seeds (sample seed 12345 → 35 pieces, max_depth=9, fp=44a9a9b3756f)", exit 0) |
| Scatter materialisation | scatter-profile dive runs end-to-end (generate → materialise → junk + gate + spawns on FLOOR); wall collision closes the arena perimeter AND every cover footprint (exhaustive point query, seed[0] closure matrix — U1's rider); snapped gate reachable; strengthened 2×2 cert; tint; **socket materialise byte-identical (zero synthetic hosts, raw pinned offset); cave guard-arm still snaps** | `…/test_scatter_materialise.tscn` → "SCATTER MATERIALISE OK" | **PASS** ("SCATTER MATERIALISE OK — closure + collision (exhaustive cover) + determinism + anchors + snapped gate + strengthened 2×2 certificate + downstream population + tint verified across 9 seeds; socket materialise byte-identical (zero synthetic hosts, raw pinned offset); cave guard-arm still snaps", exit 0) |
| Cave materialisation (control) | cave-profile dive still runs end-to-end unchanged (M1.10's backend #2 — U1's cave equivalence control); socket materialise byte-identical | `…/test_cave_materialise.tscn` → "CAVE MATERIALISE OK" | **PASS** ("CAVE MATERIALISE OK — closure + collision + determinism + anchors + snapped gate + 2×2 throat + downstream population + tint verified across 9 seeds; socket materialise byte-identical (zero synthetic hosts)", exit 0) |
| Band two profile (control) | "The Sump" loads, generates deterministically, stays connected through WearDecay, injects its vault, gates its deck across 9 seeds (the `band_two` golden fp control) | `…/test_band_two_profile.tscn` → "BAND_TWO OK" | **PASS** ("BAND_TWO OK — 'The Sump' profile loads, generates deterministically, stays connected through WearDecay, injects its deep vault, and gates its deck across 9 seeds", exit 0) |
| Band three profile (control) | "The Warren" loads as a cave band, generates deterministically + stays connected across 9 seeds; **keeps `band_greybox` AND `band_two` byte-identical**; deck spawns the D-RAT-6 outcome (ambusher 6 / burrower 3 / splitter 4 / bomb 1 = 14) at the 31-credit budget | `…/test_band_three_profile.tscn` → "BAND_THREE OK" | **PASS** ("BAND_THREE OK — 'The Warren' loads as a cave band, generates deterministically + stays connected … keeps band_greybox AND band_two byte-identical … (ambusher 6 / burrower 3 / splitter 4 / bomb 1 = 14) at the 31-credit budget", exit 0) |
| Band four profile + goldens + deck outcome | "The Far Field" loads as a scatter band, generates deterministically + stays connected + reaches the depth axis + **reads open** across 9 seeds; **keeps `band_greybox` AND `band_two` AND `band_three` byte-identical**; deck spawns the RD-2/D-RAT-6 outcome **(lobber 5 / sentry 5 / charger 4 / bomb 6 = 20) at the 34-credit budget** (spend-to-0) | `…/test_band_four_profile.tscn` → "BAND_FOUR OK" | **PASS** ("BAND_FOUR OK — 'The Far Field' loads as a scatter band, generates deterministically + stays connected + reaches the depth axis + reads open across 9 seeds, keeps band_greybox AND band_two AND band_three byte-identical, and its deck spawns the RD-2 outcome (lobber 5 / sentry 5 / charger 4 / bomb 6 = 20) at the 34-credit budget", exit 0) |

### 3.4 All four portals route (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Band routing — 4 routes | staging consume-on-read; `&"near"`/unknown → greybox control; `&"band_two"` → The Sump; `&"band_three"` → The Warren; `&"band_four"` → The Far Field (**each a distinct fp**); `run_started band_id == route key` for **all four**; wipe-isolated | `…/test_band_routing.tscn` → "BAND_ROUTING OK" | **PASS** ("BAND_ROUTING OK — staging consume-on-read, &\"near\"/unknown → greybox control, &\"band_two\" → The Sump + &\"band_three\" → The Warren + &\"band_four\" → The Far Field (each distinct fp), run_started band_id == the route key for all four routes, wipe-isolated", exit 0) |
| Hub contract — 4 portals / 5 interactables (plaza FULL) | dressed `hub.tscn` resolves paths + 4 walls + ground cells + **exactly 5 interactables (set-equality pin)**; portals 1/2/3 byte-identical (WHITE / ember-orange / cave-teal); **portal 4 routes `&"band_four"` (The Far Field prompt, indigo, (-110,-20))** | `…/test_hub_contract.tscn` → "HUB_CONTRACT OK" | **PASS** ("HUB_CONTRACT OK — paths + 4 walls + 963 ground cells + **5 interactables (plaza-FULL set pinned)**; portal 1 unchanged (&\"near\", WHITE), portal 2 → &\"band_two\" (ember-orange, (220,-150)), portal 3 → &\"band_three\" (cave-teal, (110,-20)), portal 4 routes &\"band_four\" (The Far Field prompt, indigo, (-110,-20) in-yard)", exit 0) |
| App router boot chain | App router boots → menu → hub → dive → hub, `current_state` correct | `…/test_app_router.tscn` → "ROUTER OK" | **PASS** ("ROUTER OK — App router boots → menu → hub → dive → hub; current_state correct", exit 0) |

### 3.5 Opposition surface — the two new at-range natives (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Lobber "The Mortar" (U2a) | def card locked (min_band 4 / cost 2 / caps 1+5, params mirror DEFAULTS); all-off gate holds (fp `e943ac9c8bc1`, lobber in no default lever/preset/bands-1-3 deck, additive-OR lever spawns ZERO on shallow bands); AIM→IN-FLIGHT cycle on S0 vocabulary; **marker LOCKS at fire time + precedes impact by `arc_time` (stepping off the frozen point is a guaranteed dodge)**; centre-in-radius blast `kills`-gated, BUG6 latch fires once; **a wall between Lobber and player changes nothing (geometry-ignoring identity)**; rain continues across cycles + STOPS on throw-kill; params flow def < DeckEntry < rc; deterministic deck placement (`per_band_cap 5` / `min_band 4` enforced by the real service); co-located lobbers desync by position; MortarCycle RNG-free | `…/test_lobber.tscn` → "U2a OK" | **PASS** (full U2a OK line — all clauses above verified) |
| Sentry (U2b) + binding riders | def card locked (min_band 4 / cost 2 / caps 1+5, params mirror DEFAULTS); all-off gate holds (fp `e943ac9c8bc1`, sentry in no default lever/preset/bands-1-3 deck); **lane acquired on the SECOND tick with direction AND effective length latched** (the A1 rider; authored override, longest-sightline derive, fixed tie-break, short-lane honesty); windup lead honored (no bolt, no contact before the flash); bolt kill `kills`-gated, BUG6 latch once; **a world wall stops the bolt (no pierce) + a wall suppresses the windup (LOS gate)**; cooldown gap crossable at authored numbers; **a throw KILLS the always-hazard-group sentry PERMANENTLY** (the D-RAT-4 throw-disable — verified as a permanent kill); body never contact-lethal (`bolt_speed 0` inert); deterministic deck placement; LaneWatch RNG-free, never touches membership/collision | `…/test_sentry.tscn` → "U2b OK" | **PASS** (full U2b OK line — the A1 second-tick rider + the permanent throw-kill verified) |

### 3.6 Preset parity — the rg1 verifies + legacy loop suites (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| rg1 loop verify | full loop under all-off (V6 baseline); each opposition in isolation; all four stacked; four end-causes; JSONL config/opposition/event rows; carry-forward; reset-to-baseline; no soft-lock | `…/test_rg1_loop_verify.tscn` → "RG1 BUILD VERIFY OK" | **PASS** ("RG1 BUILD VERIFY OK … 16 matrix rows headless-verified; 6 deferred", exit 0) |
| rg1 M1.2 verify | all-off byte-identical (fp `e943ac9c8bc1`); build id real; level scale; depth-scaled catches; R2/R3/nav; exposure toll; sealed high-branch bands | `…/test_rg1_m12_verify.tscn` → "RG1 M1.2 VERIFY OK" | **PASS** (fp=e943ac9c8bc1; 14 rows verified; 6 deferred, exit 0) |
| rg1 M1.3 verify | all-off byte-identical; F1 stack no-leak; even_spread vs single_gate; per-room density; corridor lever; corridor_summary row | `…/test_rg1_m13_verify.tscn` → "RG1 M1.3 VERIFY OK" | **PASS** (fp=e943ac9c8bc1; **PASS on attempt 1**; 16 rows verified; 6 deferred, exit 0) — see §3.7 (the known BUG-M13FLAKE tripped on retries; not a product bug) |
| rg1 M1.4 verify | all-off byte-identical; M1.4 fun stack (K4 timer + all 3 K5 hazards + K7 exits) trap-free no-leak; K5i spawn helper; end-causes; snapshot | `…/test_rg1_m14_verify.tscn` → "RG1 M1.4 VERIFY OK" | **PASS** (fp=e943ac9c8bc1; 11 rows verified; 7 deferred, exit 0) |
| rg1 M1.5 verify | all-off byte-identical; M1.4 stack + 3 M1.5 levers (throw/room-only/patrol); L1 throw seam; L2 spawn-room bounds; end-causes | `…/test_rg1_m15_verify.tscn` → "RG1 M1.5 VERIFY OK" | **PASS** (fp=e943ac9c8bc1; 12 rows verified; 7 deferred, exit 0) |
| Shop economy | 3-item persistent catalog; purchase debits+records+persists; reject paths inert; wipe clears; SELL-tab credits held haul | `…/test_shop_economy.tscn` → "SHOP ECONOMY OK" | **PASS** ("SHOP ECONOMY OK — 3-item persistent catalog … purchase() debits+records+persists … SELL-tab sell_banked_junk(&shop) credits the held haul", exit 0) |
| Quota system | met advances+persists; miss → wipe_meta (9-field reset); eval idempotent; on_extract skips non-extract; quota-off inert; Hub-return cumulative basis | `…/test_quota_system.tscn` → "QUOTA OK" | **PASS** ("QUOTA OK — met advances+persists … miss defers to wipe_meta (9-field reset + meta_wiped) … M1.6 Hub-return cumulative basis counts the held unsold haul", exit 0) |
| Main game loop | assembled dive-only scene builds a band + pickups + gate; pickup + gate extract drive run_ended(extract) with haul held-banked; second run restarts clean | `…/test_main_game_loop.tscn` → "MAIN GAME OK" | **PASS** ("MAIN GAME OK — assembled dive-only scene built a band … gate extract drove run_ended(extract) with the haul held-banked … a second run restarted clean", exit 0) |

### 3.7 One intermittent row — `test_rg1_m13_verify` (the known BUG-M13FLAKE, NOT a product bug)

`test_rg1_m13_verify` **PASSED on attempt 1** (exit 0, all-off fp `e943ac9c8bc1` byte-identical, 16
rows verified). On two follow-up re-runs it went RED with the signature symptom:

```
RG1 M1.3 VERIFY FAIL: M5/all-on: config 'rg1-m13-M5-all-on' emitted none of ["return_cost_incurred"] (opposition row missing)
RG1 M1.3 VERIFY FAIL: M1/default-preset-R4: config 'rg1-m13-M1-default-preset' emitted none of ["nav_branch_taken", "nav_lost_proxy"] (opposition row missing)
```

**This is the documented, pre-existing BUG-M13FLAKE** — a headless telemetry-emission-timing flake
(filed in `design/DESIGN_DEVIATIONS_HISTORY.md:485`; symptom described verbatim in
`worklogs/2026-06-26-M2-general-purpose.md:71-73`: "position-driven nav/R2/R3 telemetry rows + the
`timeout` end-cause intermittently don't [emit] within the test window"). The *which* rows go missing
varies run-to-run (nav / return-cost / exposure), the hallmark of a race, not a logic error. It is
unchanged by M1.11 (no M1.11 task touched the m13 harness or the telemetry emit path) and the all-off
fp is byte-identical on the passing run. Handled exactly as SG1/TG1 did — **recorded as PASS on
attempt 1; the retries confirm the known flake, not a regression.** No production code touched by UG1.

### 3.8 Did UG1 add a new `test_ug1_m111_verify`?

**No — consistent with SG1/TG1.** M1.11's non-rendered surface is fully covered by the purpose-built
U0–U4 tests: the scatter backend has its own determinism/connectivity/openness/fp guard
(`test_scatter_backend`) and an end-to-end playability guard (`test_scatter_materialise`, incl. U1's
seed[0] exhaustive-closure matrix); the two new oppositions have dedicated behavior tests
(`test_lobber`, `test_sentry`, incl. the A1 second-tick + permanent-throw-kill riders); all four
bands + all four routes are asserted (`test_band_four_profile` — which also pins the three prior-band
goldens — `test_band_routing`, `test_hub_contract` at 5 interactables); the coverage discipline has
its own nets (`test_config_menu` 91/91, `test_def_menu_coverage`, `test_opposition_def_schema`
bijection at 11 defs); the four permanent controls are pinned across every rg1 verify +
`test_band_four_profile`. A consolidated verify test would only re-instance the same scenes and
re-assert the same facts — pure duplication with a concurrent-instance risk. The remaining M1.11
surface is **rendered/felt** (open-field tense-vs-empty, the 1.45 step, Lobber/Sentry fairness, the
lane-as-highway read, exposed-center loot pull) and headless cannot render or input-drive it —
correctly deferred to §5 + UG2/UG3. **No new verify test committed.**

---

## 4. Objective result summary

**All §3 rows PASS** (the one intermittent row is the documented BUG-M13FLAKE, which passed on
attempt 1 — no product bug). The four permanent controls are byte-identical — the all-off `RunConfig`
fp is `e943ac9c8bc1` through the new scatter dispatch and across every rg1 verify, and the three
prior-band goldens (`band_greybox`, `band_two`, `band_three`) are asserted byte-identical by
`test_band_four_profile`. The scatter backend is deterministic + connected + provably open (sample
seed 12345 → 35 pieces, max_depth 9, fp `44a9a9b3756f`), materialises to a playable end-to-end open
arena on the existing synthetic-piece path (U1's 1-line ride-through), and keeps socket + cave
materialisation byte-identical. The coverage discipline is **91/91 knobs** with the per-def
params↔schema bijection green for all **11 defs**; the save schema is **unchanged** (META v4 / RUN
v1, no new migration — save-migration fixtures v1/v2/v3 → v4 all green); **all four portals route
deterministically** (band 1 = `band_greybox` control, band 2 = The Sump, band 3 = The Warren, band 4
= The Far Field, each a distinct fp with `band_id` stamped on runs); The Far Field's deck spawns the
exact D-RAT-6 outcome (lobber 5 / sentry 5 / charger 4 / bomb 6 = 20) at the 34-credit budget; both
new oppositions pass their behavior + cap + determinism tests including the Sentry A1 second-tick
acquisition rider and the permanent throw-kill. The objective M1.11 gate is met; the feel read is
human-deferred (§5).

---

## 5. Director playtest checklist (The Far Field — render-time, human only)

Open the published build (Chrome/Edge, password-gated), boot → Main Menu → NEW GAME, stand in the
hub. Then:

- **D-U4-2 rider — eyeball BOTH transit lanes + the four-glow plaza (verbatim, U4 §Handoffs):**
  *(a) BOTH transit lanes* — **spawn→portal-2** (which crosses over portal 3) **AND spawn→shop**
  (which crosses over portal 4, **the loop's most-walked lane**): confirm neither crossing
  mis-fires the wrong dive prompt (mitigations shipped: 90.6 px never-two-in-range gaps, focus
  hysteresis, band-named prompt, fat-finger lockout — escalation if judged mis-dive-prone is to pull
  the band-select surface forward, never a slot shuffle). *(b) the four-glow plaza read* — the four
  portal glows now sit together: **white-violet** (band 1), **ember-orange** (The Sump),
  **cave-teal** (The Warren), **indigo** (The Far Field). Does the plaza read as four distinct,
  legible destinations, or do the blue-family glows (teal + indigo + violet) muddy together?
- **Four dive gates now sit in the yard.** Confirm the three original gates still dive into the
  **same band 1**, **The Sump**, and **The Warren** — nothing about their generation, hazards, or
  pacing should feel different from M1.10 (they're the controls). The fourth, indigo gate at the
  west mirror slot (opposite The Warren) is **"Dive — The Far Field"**.
- **The Far Field reads as an open field, not rooms or caves.** Dive The Far Field. Does it read as a
  **vast flat expanse** — one big arena instead of rooms/corridors or cave chambers, **sparse
  rim-biased cover** stamped across it, **long sightlines** where you can see (and be seen) across
  the whole space? This is a *third* generator (scatter), the spatial opposite of both shipped kinds
  (socket = doorway-reading; cave = low-sightline nooks; open field = see-and-be-seen). Is the
  different *kind* of generation legible, or does it just feel like a differently-tinted band?
- **Open field: tense or empty?** The b1 identity is "long sightlines as the play identity — where do
  I stand, and what can see me." Is the openness *tense and interesting* (you pick your line across
  the exposed center, you read threats at range), or does it tip into *empty* (nothing to do, a flat
  walk)? This is the core UG2/UG3 watch-item.
- **The lane as a highway.** The clear lane runs the arena's full width and the spawn sits on it
  (U0 RD-15). Does it read as a **highway** — a fast, safe-ish spine you sprint down — with the cover
  and hazards flanking it? Does that tempt you to leave the lane for the exposed-center loot?
- **Exposed-center loot — the risk/reward pull.** Loot is scattered on the floor including the
  exposed center (cover hugs the rim). Does grabbing center loot feel like a *deliberate exposure
  gamble* against the ranged threats, or is it flat? (The geometry ships; a loot-*value* bias toward
  the exposed center is an M2 candidate, not in this build — UG2 watch.)
- **The Lobber "The Mortar" — keep moving.** A slow/static sheller locks a **ground-marker
  telegraph** at where you stood, then an **arcing shell lands there and IGNORES cover** (standing
  behind a wall does NOT protect you — only moving does). Does the marker read in time to step clear
  (fair), or does it feel like a cheap gotcha? Confirm a thrown item **kills it** (silences the rain).
- **The Sentry — read the lane, or spend an item.** A **stationary** emplacement watches one straight
  lane with an **always-visible** telegraph; cross it and it **flashes (windup)** then fires a **fast
  bolt down the lane** — but a **wall or cover cell STOPS the bolt** (this is why cover matters). Does
  the windup flash give you time to clear the lane (fair)? Confirm you can either route around the
  lane, wait out the cooldown gap, or **throw an item to kill it permanently** ("spend an item to
  open a route forever"). The pair is the band's *cover dialogue*: the Sentry makes cover safety, the
  Lobber punishes camping it.
- **The Charger, alive in the open.** The Wrecker (charger) returns in The Far Field's deck (4 of
  them) — a telegraphed straight dash. Does it read differently in the open (long run-up, more room
  to dodge) than it did in The Sump's rooms?
- **6 mines punctuate the crossing.** Six proximity bombs are the deck's remainder sponge — do they
  space the arena so the crossing has beats, or clump?
- **P-menu Oppositions tab.** Press **P → Oppositions tab**. Confirm every hazard exposes its tuning
  params (generated from `param_schema`) — including the two new natives, marked **IN DECK** for The
  Far Field and pre-expanded. Tune a param (e.g. the Lobber `fire_period_s`/`arc_time_s` or the Sentry
  `windup_s`) and **respawn** to feel it live; the run is flagged **debug-dirty** (filtered from the
  honest UG2 telemetry cohort).
- **Export telemetry.** After a few dives across all four portals, press the in-game **Export
  telemetry** button (P → Meta tab) to download the run log for UG2's four-band analysis (`band_id`
  is stamped on every `run_started` row — `near` / `band_two` / `band_three` / `band_four`).
- **Placeholder caveat.** The Far Field's floor/walls/cover are **greybox geometry + a tint pass**,
  not a bespoke tileset; the hazards (the Mortar turret, its ground ring, the Sentry lane strip + bolt)
  are placeholder greybox. Judge the *layout / openness / hazard fun / difficulty step*, not the
  pixel-craft.

**Deferred (not in this build):** the scatter generator is **The Far Field only** (bands 1–3 are the
unchanged controls — a clean A/B for UG2); Lobber + Sentry are **Far-Field-only**; the open-field look
is **greybox + tint**, not a tileset; loot *value* is uniform (no exposed-center value bias yet —
geometry only); the `lead_factor` difficulty dial is at 0 (the Mortar lands where you stood, not
where you're going); no save change (band choice is per-dive, not persisted); **the plaza is FULL —
band 5 will require a band-select surface (carried to UG3).**

---

## 6. Publish + changelog

- **changelog.txt** — updated by UG1 with an **M1.11 — "The Far Field"** block documenting the
  M1.10→M1.11 delta as a clean **feature list** (per the changelog scope rule — feature list, not a
  fix log, delta from the previous shipped version `m1-20260706-d04bd13`): the fourth dive portal +
  The Far Field band (a NEW open-field generator — one vast flat arena, sparse rim-biased cover, long
  sightlines, a step deeper with a heavier budget), the two Far-Field-only ranged hazards (the Lobber
  "The Mortar" cover-ignoring sheller, the Sentry lane-denier with the permanent throw-disable), and a
  one-line note that the debug Oppositions tab now tunes both. Intra-M1.11 fixes are folded into each
  feature's final-state description, not listed. A "NOT YET IN THIS BUILD" note flags: the scatter
  generator is band-4-only (bands 1–3 unchanged), both hazards Far-Field-only, greybox+tint (no
  bespoke tileset), no exposed-center loot-value bias yet, the plaza-full band-5 forcing function, and
  the unchanged save.
- **Publish to itch** — **orchestrator-owned, run from `main` after this changelog + doc merge** (this
  worktree does NOT hold `APIKEYS.md`, and the build stamp must encode `main`'s post-merge SHA, not
  this branch's — the TG1/SG1 precedent). Command (from repo root):
  `BUTLER=/mnt/c/wsl-libraries/butler/butler bash Game/tools/push_itch.sh` (stamp → export Web preset
  → `butler push qusto/the-far-yard:html5`). The godot web-export exit-crash after "DONE savepack" is
  HARMLESS (the script gates on artifact existence, not the exit code) — judge success by butler's
  build-id output. Live page: `https://qusto.itch.io/the-far-yard` (Chrome/Edge only —
  SharedArrayBuffer/COEP; password-gated). Web telemetry returns via the in-game "Export telemetry"
  button (P → Meta tab).

### 6.1 Publish record

- **PUBLISHED 2026-07-08 (orchestrator, from `main` @ `69446d5` — the UG1 merge commit):**
  `qusto/the-far-yard:html5 @ m1-20260708-69446d5` — butler upload `#18000582`, **build `#1781007`** ✓
  (from `#1775901`, the M1.10 `d04bd13` build; 492 KiB patch). Verified live via
  `butler status qusto/the-far-yard:html5`. Live page: `https://qusto.itch.io/the-far-yard`
  (Chrome/Edge only, password-gated).

---

## 7. Acceptance criteria (M1.11 / UG1)

1. **A fresh build boots, reaches the hub with all four portals, and the complete loop + all four
   dives run end-to-end** — all §3 objective rows green (import, smoke, router, main-game-loop).
2. **The four permanent controls reproduce their baselines exactly** — all-off `RunConfig` fp
   `e943ac9c8bc1` unmoved through the new scatter dispatch and every rg1 verify; `band_greybox`,
   `band_two`, and `band_three` fingerprints byte-identical (asserted by `test_band_four_profile`).
3. **The scatter backend is deterministic, connected, provably open, and playable** —
   `test_scatter_backend` (fp `44a9a9b3756f`, openness bar) + `test_scatter_materialise` (end-to-end,
   exhaustive cover closure, socket + cave materialise byte-identical).
4. **The coverage discipline held** — 91/91 knobs + per-def params↔schema bijection for all **11
   defs** (grown, not dropped).
5. **No save-schema change** (META v4 / RUN v1; band choice is run-state; existing migrations stand,
   v1/v2/v3 → v4 fixtures green, no new fixture).
6. **All four portals route deterministically** (band 1 = `band_greybox` control byte-identical;
   band 2 = The Sump; band 3 = The Warren; band 4 = The Far Field; each a distinct fp; `band_id`
   stamped on runs).
7. **The two new oppositions + The Far Field pass their behavior/cap/determinism tests** (incl. the
   Sentry A1 second-tick acquisition + permanent throw-kill, the Lobber geometry-ignoring blast +
   locked marker, and The Far Field's exact D-RAT-6 deck outcome), shipped almost entirely as data
   (the "content = data at N = 3" proof — U3's marginal cost 0, U4's 1 line; UG3 judges the trend via
   the ledgers).
8. The build + this doc + the updated changelog are **ready for the Director's playtest** (published
   to itch by the orchestrator from `main`), with the Far Field *feel* correctly human-deferred (§5)
   and telemetry analysis owned by UG2.

A build that passes the §3 matrix (all rows green, the one intermittent BUG-M13FLAKE row passing on
attempt 1) + ships the changelog + is published to itch satisfies UG1. Done means: the matrix is
filled, the worklog names the commit SHA, the build boots to a hub with four working portals, the four
controls are byte-identical, the coverage/save invariants hold, and the itch push is confirmed (by the
orchestrator from `main`).
