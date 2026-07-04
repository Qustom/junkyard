# SG1 — M1.9 Playtest Build (Scalable Opposition + Bands — content becomes data, proven in-game)

**Task id:** SG1 · **Milestone:** M1.9 (Scalable Opposition + Band Systems) · **Workstream:** the re-gate · **Wave:** 6 (after S0–S9 integrate)
**Assignee:** `qa-playtest-coordinator` (build assembly + verify matrix + changelog) + the orchestrator-owned itch publish
**dependsOn:** **S0–S8** (the full build phase) all Done + integrated on `main` (build phase close-out `1adeef6`; S8 merge `1c4623b`, S9 merge `d2ec4d5`)
**Companion docs:** `M1.9_Breakdown.md` (the one thing this version proves + the cross-cutting contracts), `M1_8_Tasks/HG1_playtest_build.md` (the template this mirrors), the M1.8 changelog block (the previous shipped version, for the changelog delta), `M1_Tasks/M1_As_Built.md` (canonical APIs), `systems/save_manager.gd` (`META_SCHEMA_VERSION == 4`, `RUN_SCHEMA_VERSION == 1` — **unchanged in M1.9**).

> **This is the VERIFY + PUBLISH capstone of M1.9, not new gameplay.** M1.9 landed two explored
> architectures as working code — a policy-free `SpawnService` + `EncounterBuilder` for oppositions,
> and a `BandProfile`-driven `BandPipeline` for bands — and then *proved* them by shipping **2 new
> hazards (Charger "The Wrecker", Splitter) + 1 new band (The Sump) reachable through a second hub
> portal, almost entirely as `.tres` data*. SG1 (a) confirms every system boots + loads, (b) confirms
> the all-off control is still byte-identical to the locked baseline (fp `e943ac9c8bc1`) through the
> new call sites, (c) confirms the coverage discipline held (**91 knobs** + per-def params↔schema
> bijection), (d) confirms **no save-schema change** (META v4 / RUN v1), (e) confirms **both portals
> route correctly** (band 1 = `band_greybox` byte-identical; band 2 = The Sump), and then hands the
> Director a playable build (published to itch) + the changelog for the re-gate (SG2/SG3).

---

## 1. Goal & design intent

**Goal:** verify **one runnable M1.9 build** that proves *adding content is data, not engineering* —
two new hazards + a second band ship as defs/profiles + small reusable parts, reachable in-game via a
second hub portal, **without moving the all-off control by a single byte**.

**Design intent (one line):** *SG1 is the M1.9 integration + verification + publish capstone* — it
confirms the scalable-opposition + scalable-band architectures compose onto the existing loop, that
the all-off `RunConfig` fingerprint stays `e943ac9c8bc1` through the new `BandPipeline`/`EncounterBuilder`
call sites, that the coverage assertion grew to 91 knobs + per-def bijection (not dropped), that the
save schema did not bump, and that both hub portals route deterministically to their bands (band 1 =
`band_greybox` control, band 2 = The Sump). The *feel* of The Sump — does it read as a band apart, do
the new hazards' telegraph→dodge→punish loops land, is the +15% budget a felt step — is SG2/SG3
(telemetry + Director), rendered-only, correctly human-deferred (§5).

---

## 2. What's already wired (the M1.9 S0–S9 work — do NOT rebuild)

SG1 inherits the integrated build phase. Key seams (verified present by §4):

- **S0 — SpawnService + OppositionDef data layer + EventBus pre-declare.** Mechanism half of the old
  `_spawn_new_hazards` extracted into a policy-free per-dive `SpawnService` (spawn/place/setup/caps/
  registry/`&"spawned"`); the 4 shipped hazards authored as `data/oppositions/*.tres`; all M1.9 signals
  pre-declared (`opposition_event`, `opposition_killed_player`, `debug_run_dirtied`) + the
  `dive_requested(band_id)` reuse + GameState `_pending_dive_band` staging seam.
- **S1 — BandProfile + BandPipeline + `band_greybox.tres`.** `BandProfile` resource + thin
  `BandPipeline.generate(profile, seed, rc)` orchestrator that byte-reproduces today's `BandGenerator`
  for the greybox profile.
- **S2 — Opposition components + `param_schema`.** The 4 entities refactored onto the shared typed
  component set; each def's `params`/`param_schema` completed; BUG6 latch + L5 `*_kills` gate preserved.
- **S3 — EncounterBuilder + RunConfig generic levers + both call-site integrations.** Policy half moved
  to `EncounterBuilder.populate(...)`; `main_game` a thin consumer of `BandPipeline` + the builder;
  `oppositions_enabled`/`param_overrides` levers (`@export_storage` in S3, promoted to 2 bound rows by S4).
- **S4 — Generated debug-menu sections + per-def coverage + hygiene.** The generated Oppositions tab
  (widgets from `param_schema`), generalized coverage assertion (91 legacy rows + per-def bijection),
  dotted `param_overrides` telemetry stamp, `debug_dirty` run flag, respawn-with-new-params live-edit.
- **S5 — Band flavor stages.** `SetPieceInject` + `WearDecay` + the connectivity-guarantee stage
  (flood-fill; WearDecay cannot strand the player).
- **S6a — Charger "The Wrecker"** (`charger.tres` + `ChargeLane` movement component; telegraph → lethal
  dash → recover; dash-invulnerable in The Sump per the deck override; wall-crash bonus-stun).
- **S6b — Splitter** (`splitter.tres` + `splitter_child.tres`; splits into 2 children on throw-death via
  the mid-run `svc.spawn` client; children terminal; capped by the service registry).
- **S7 — `band_two.tres` "The Sump"** (socket backend, branchy archetype, `SetPieceInject`+`WearDecay`
  flavors, deep vault set-piece, opposition deck incl. Charger + Splitter, `band_depth = 2`, sepia-amber
  `palette_tint`).
- **S8 — Second hub portal + band routing + telemetry band-stamp.** `interactable_id=&"portal_band_two"`,
  ember-orange glow `Color(1.0, 0.58, 0.24)`, prompt "Dive — The Sump", routes via `dive_requested(band_id)`;
  the existing portal keeps routing to `band_greybox` byte-identically; `band_id` stamped on `run_started`.
- **S9 — DeckEntry override wrapper.** Deck-level tuning (`def params < deck-entry overrides <
  rc.param_overrides`); The Sump's deck carries the D-RAT-2 Charger values.

**Invariants held:** the all-off `RunConfig.new()` band fingerprint stays `e943ac9c8bc1`; the knob count
grew to **91** (89 frozen legacy + `oppositions_enabled` + `param_overrides`) with the coverage assertion
extended (per-def params↔schema bijection), never dropped; the save schema is **unchanged** (META v4 /
RUN v1 — band choice is run-state, not saved); `make_default_play_preset()` spawns the same cohort
through the new builder.

---

## 3. Verify matrix (M1.9)

SG1 is **done** only when this matrix passes. It separates **objective build checks** (headless-automatable,
each row naming the exact test/command) from **subjective feel read** (SG2/SG3 + human — the rendered Sump
experience). All commands run with `export PATH="$HOME/.local/bin:$PATH"`, **one godot instance at a time**
(import-lock deadlock if concurrent), tests as SCENES (`godot --headless --path Game res://tests/<x>.tscn`).

> **Environment:** godot 4.6.3.stable, headless, no display server — every row about *how The Sump looks
> / how the hazards feel* is Director-manual / render-time (§4/§5). The objective rows below prove the
> build boots, loads both bands + all 7 defs, keeps the control byte-exact, and routes both portals.

### 3.1 Build integrity + all-off determinism (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Clean import | All scripts compile, no parse errors; `.godot` builds (S0–S9 code + defs + profiles) | `godot --headless --path Game --import` → exit 0 | **PASS** (exit 0) |
| CI smoke | M0 architecture spike healthy (autoloads, EventBus, seeded RNG, save stub) boots headless | `… --script res://tools/ci_smoke_test.gd` → "SMOKE OK" | **PASS** ("SMOKE OK — M0 architecture spike healthy", exit 0) |
| All-off fp (RunConfig) | All-off `RunConfig` default = 90-knob flat dict, staged/cleared on run boundary, trap-free, default preset is the F1 fun stack + doesn't leak | `…/test_run_config.tscn` → "R0 OK" | **PASS** ("R0 OK … active_run_config staged/defaulted/cleared … to_flat_dict() … all 90 knobs … BUG6 … J1 make_default_play_preset() is the F1 stack", exit 0) |
| Bandgen determinism | proc-gen reproducible across 9 seeds; sample seed 12345 → 12 pieces, fp `e943ac9c8bc1` | `…/test_bandgen_determinism.tscn` → "BANDGEN OK" | **PASS** ("BANDGEN OK … 9 seeds (sample seed 12345 → 12 pieces, fp=e943ac9c8bc1)", exit 0) |
| Corridor lever | neutral default fp byte-matches baseline; corridor levers move it deterministically | `…/test_corridor_lever.tscn` → "J4 OK" | **PASS** ("J4 OK — … neutral default fp byte-matches the locked baseline (e943ac9c8bc1) …", exit 0) |
| Band pipeline parity | orchestrated `BandPipeline` path fingerprint byte-matches direct `BandGenerator` across 9 seeds | `…/test_band_pipeline_parity.tscn` → "PIPELINE PARITY OK" | **PASS** ("PIPELINE PARITY OK — BandPipeline byte-matches BandGenerator across 9 seeds … fp=e943ac9c8bc1"; the stderr `push_error` lines are the test's own fail-loud null/empty-profile path assertions, exit 0) |

### 3.2 Coverage discipline + save schema (HEADLESS / inspection)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Config menu 91/91 | All 91 `RunConfig` knobs bound + reachable (89 legacy + `oppositions_enabled` + `param_overrides`); Reset returns the all-off baseline | `…/test_config_menu.tscn` → "CONFIG MENU OK" | **PASS** ("CONFIG MENU OK — CFG verified (91/91 knobs bound + reachable … Reset returns the all-off baseline)", exit 0) |
| Per-def coverage bijection | params↔param_schema bijection net fires on drift + duplicate ids; zero-defs headless build green; dotted override stamp + generated rows + debug_dirty hygiene | `…/test_def_menu_coverage.tscn` → "DEF MENU COVERAGE OK" | **PASS** ("DEF MENU COVERAGE OK — bijection net fires on drift + duplicate ids … dotted override stamp … tier-v1 respawn keeps cells, merges params, dirties ONCE", exit 0) |
| Opposition def schema | 7 defs: params↔schema bijection, locked entry shape, mirror-parity vs RunConfig defaults, one trap-if-neutral per def, host contract | `…/test_opposition_def_schema.tscn` → "DEF SCHEMA OK" | **PASS** ("DEF SCHEMA OK — 7 defs: params<->param_schema bijection … host contract …", exit 0) |
| Save schema unchanged | `META_SCHEMA_VERSION == 4`, `RUN_SCHEMA_VERSION == 1` — **no M1.9 bump** (band choice is run-state). No new migration / fixture. | inspect `systems/save_manager.gd` + `git log` | **PASS** (`META_SCHEMA_VERSION := 4`, `RUN_SCHEMA_VERSION := 1`; `save_manager.gd` last touched `1a17442` Jun-27, **before M1.9** — no M1.9 diff, no new migration step) |

### 3.3 Bandgen through the pipeline + The Sump (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Band two profile | "The Sump" loads, generates deterministically, stays connected through WearDecay, injects its vault, gates its deck across 9 seeds | `…/test_band_two_profile.tscn` → "BAND_TWO OK" | **PASS** ("BAND_TWO OK — 'The Sump' profile loads, generates deterministically, stays connected through WearDecay, injects its deep vault, and gates its deck across 9 seeds", exit 0) |
| Band flavors | `SetPieceInject` + `WearDecay` + connectivity guarantee verified across 9 seeds | `…/test_band_flavors.tscn` → "BAND FLAVORS OK" | **PASS** ("BAND FLAVORS OK — SetPieceInject + WearDecay + connectivity guarantee verified across 9 seeds", exit 0) |

### 3.4 Both portals route (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Band routing | staging consume-on-read; `&"near"`/unknown → greybox control; `&"band_two"` → The Sump (deterministic, distinct fp); `run_started band_id == route key` for both; wipe-isolated | `…/test_band_routing.tscn` → "BAND_ROUTING OK" | **PASS** ("BAND_ROUTING OK — … &\"near\"/unknown → greybox control, &\"band_two\" → The Sump (deterministic, distinct fp), run_started band_id == the route key for both routes, wipe-isolated", exit 0) |
| Hub contract | dressed `hub.tscn` resolves paths + 4 walls + ground cells + 3 interactables; portal 1 unchanged (`&"near"`, WHITE); portal 2 routes `&"band_two"` (Sump prompt, ember-orange, in-yard) | `…/test_hub_contract.tscn` → "HUB_CONTRACT OK" | **PASS** ("HUB_CONTRACT OK — paths + 4 walls + 963 ground cells + 3 interactables; portal 1 unchanged (&\"near\", WHITE), portal 2 routes &\"band_two\" (The Sump prompt, ember-orange, (220,-150) in-yard)", exit 0) |
| App router | boots menu → hub → dive → hub; `current_state` correct | `…/test_app_router.tscn` → "ROUTER OK" | **PASS** ("ROUTER OK — App router boots → menu → hub → dive → hub; current_state correct", exit 0) |

### 3.5 Opposition surface — service, builder, deck, components, new hazards (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| SpawnService | spawn/place/setup/`&"spawned"` emit; cap_group + per_band_cap refusal at ceiling; registry counts/instances/cells; clear_all; BUG7 entry-safe refusal; deterministic (no RNG) placement; dive-band staging round-trip | `…/test_spawn_service.tscn` → "S0 OK" | **PASS** (full S0 OK line) |
| EncounterBuilder | all-off inert; preset byte-parity vs pre-S3 mirror; fair-share + starvation; deck budget `floor(24*I)`; min_band gating; deterministic draw; caps respected; all-off fp `e943ac9c8bc1` pinned; instability(1)=1.0/instability(2)=1.15 | `…/test_encounter_builder.tscn` → "S3 OK" | **PASS** (full S3 OK line) |
| DeckEntry | empty-overrides wrapper byte-identical; precedence def < deck-entry < rc.param_overrides; The Sump charger resolves D-RAT-2 (`throwable_while_charging=false`/`wall_crash_recover_mult=2.0`); all-off fp pinned | `…/test_deck_entry.tscn` → "S9 OK" | **PASS** (full S9 OK line) |
| Opposition components | pursuer_chase/pursuer_room/pingpong/bomb 300(/96)-frame byte-identical traces | `…/test_opposition_components.tscn` → "S2 TRACE OK ×N" | **PASS** (all component traces byte-identical, exit 0) |
| Charger (S6a) | def card locked (min_band 2/cost 2/caps 1+4); all-off gate holds (fp unmoved, charger in no default deck); three-beat FSM; dodgeable+lethal-only-while-dashing; L5 gate + BUG6 latch once; wall-stop + bonus-stun; dash-invuln misses a mid-dash throw, recovery throw kills; ChargeLane RNG-free; deterministic placement | `…/test_charger.tscn` → "S6a OK" | **PASS** (full S6a OK line) |
| Splitter (S6b) | split on throw-death only (2 children, parent freed, one `&"split"`); children terminal; per_band_cap=8 + ceiling refusal + freed-parent headroom; all-off fp byte-identical across a forced split (RNG stream untouched); L5 kills gate; child_despawn mercy knob | `…/test_splitter.tscn` → "S6b OK" | **PASS** (full S6b OK line) |
| New-hazard spawn seam | all-off → 0 nodes; depth-scaled per-room count; per-room cap; shared band ceiling (48); deterministic placement; per-kind spawn_ctx | `…/test_new_hazard_spawn.tscn` → "K5i OK" | **PASS** (full K5i OK line) |
| Legacy hazards (4) | pursuing / bomb / pingpong / spike logic unchanged | `…/test_pursuing_hazard.tscn` · `…/test_bomb_hazard.tscn` · `…/test_pingpong_hazard.tscn` · `…/test_spike_hazard.tscn` | **PASS** (each exit 0; "PURSUING HAZARD OK", "BOMB HAZARD OK", "K5a OK", "K5c OK") |

### 3.6 Loop + rg1 verifies (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| Main game loop | dive-only scene builds a band (pieces+pickups+gate), pickup + gate-extract drives `run_ended(extract)` haul held-banked, second run restarts clean | `…/test_main_game_loop.tscn` → "MAIN GAME OK" | **PASS** (full line, exit 0) |
| rg1 loop verify | full loop under all-off; each opposition in isolation; all four stacked; four end-causes; JSONL config/opposition/event rows; carry-forward; reset-to-baseline; no soft-lock | `…/test_rg1_loop_verify.tscn` → "RG1 BUILD VERIFY OK" | **PASS** ("RG1 BUILD VERIFY OK … 16 matrix rows headless-verified; 6 deferred", exit 0) |
| rg1 M1.2 verify | all-off byte-identical (fp `e943ac9c8bc1`); build id real; level scale; depth-scaled catches; R2/R3/nav; exposure toll; sealed high-branch bands | `…/test_rg1_m12_verify.tscn` → "RG1 M1.2 VERIFY OK" | **PASS** (full line, fp=e943ac9c8bc1, exit 0) |
| rg1 M1.3 verify | all-off byte-identical; F1 stack no-leak; even_spread vs single_gate; per-room density; corridor lever; corridor_summary row | `…/test_rg1_m13_verify.tscn` → "RG1 M1.3 VERIFY OK" | **PASS** (fp=e943ac9c8bc1; **PASS on attempt 1** — the known BUG-M13FLAKE headless intermittent did NOT trip this run; no retry needed) |
| rg1 M1.4 verify | all-off byte-identical; M1.4 fun stack (K4 timer + all 3 K5 hazards + K7 exits) trap-free no-leak; K5i spawn helper; end-causes; snapshot | `…/test_rg1_m14_verify.tscn` → "RG1 M1.4 VERIFY OK" | **PASS** (full line, fp=e943ac9c8bc1, exit 0) |
| rg1 M1.5 verify | all-off byte-identical; M1.4 stack + 3 M1.5 levers (throw/room-only/patrol); L1 throw seam; L2 spawn-room bounds; end-causes | `…/test_rg1_m15_verify.tscn` → "RG1 M1.5 VERIFY OK" | **PASS** (full line, fp=e943ac9c8bc1, exit 0) |

### 3.7 Did SG1 add a new `test_sg1_m19_verify`?

**No — and this is a deliberate QA call, consistent with HG1.** M1.9's non-rendered surface is fully
covered by the purpose-built S0–S9 tests: the two architectures each have a parity/fingerprint guard
(`test_band_pipeline_parity`, `test_encounter_builder` — both pin `e943ac9c8bc1`), both new hazards have
dedicated behavior tests (`test_charger`, `test_splitter`), both bands + both routes are asserted
(`test_band_two_profile`, `test_band_routing`, `test_hub_contract`), and the coverage discipline has its
own nets (`test_config_menu` 91/91, `test_def_menu_coverage`, `test_opposition_def_schema` bijection). A
consolidated `test_sg1_m19_verify` would only re-instance the same scenes and re-assert the same
fp/routing/coverage facts those tests already cover — pure duplication with a concurrent-instance risk.
The remaining M1.9 surface is **rendered/felt** (does The Sump read as a band apart, do the telegraphs
land, is the +15% budget a felt step) and headless cannot render or input-drive it — correctly deferred
to §5. **No new test committed.**

---

## 4. Objective result summary

**All §3 rows PASS.** The all-off control is byte-identical (`e943ac9c8bc1`) through the new
`BandPipeline` + `EncounterBuilder` call sites and across every rg1 verify; the knob count is **91/91**
with the per-def params↔schema bijection green for all 7 defs; the save schema is **unchanged** (META v4
/ RUN v1, no new migration); **both portals route deterministically** (band 1 = `band_greybox` control,
band 2 = The Sump with a distinct fp); the two new hazards pass their behavior + cap + determinism tests;
the full legacy loop/dive/shop/hazard suite is green. The known BUG-M13FLAKE did not trip (PASS on
attempt 1). The objective M1.9 gate is met; the feel read is human-deferred (§5).

---

## 5. Director playtest checklist (The Sump — render-time, human only)

Open the published build (Chrome/Edge, password-gated), boot → Main Menu → NEW GAME, stand in the hub. Then:

- **Enter both portals.** Two dive gates now sit in the yard — the original and a new ember-orange one
  prompted "Dive — The Sump". Confirm the original gate still dives into the **same band 1** (control
  feel — nothing about band 1's generation, hazards, or pacing should feel different from M1.8).
- **The Sump reads as a band apart.** Dive The Sump. Does it read as *somewhere worse* — branchier
  layout, flooded/decayed terrain (WearDecay), the sepia-amber tint, the deep VAULT set-piece, and a
  denser opposition presence (+15% budget) than band 1? Is the difference legible, or does it feel like
  band 1 with a colour swap?
- **The Wrecker (Charger) bait → dodge → punish.** Meet the charger. Does the telegraph read? Can you
  bait the dash and side-step the shown lane? Confirm a thrown item **MISSES it mid-dash** in The Sump
  (intended — it's dash-invulnerable there) and that you kill it in the **recovery window** instead.
  Crash it into a wall and confirm the longer bonus-stun opens a bigger punish window.
- **Splitter throw-death split.** Kill a Splitter **with a throw** → confirm it splits into **2**
  children; kill a child → confirm children **don't re-split**. Kill a Splitter by any other means →
  confirm it does NOT split. Does the "throwing at it is a choice" tension land?
- **P-menu Oppositions tab.** Press **P → Oppositions tab**. Confirm every hazard exposes its tuning
  params (generated from `param_schema`). Tune a param (e.g. a charger timing) and **respawn** to feel
  the change live; note the run is now flagged **debug-dirty** (it should be filtered from the honest
  SG2 telemetry cohort).
- **Export telemetry.** After a few dives across both portals, press the in-game **Export telemetry**
  button (P → Meta tab) to download the run log for SG2's per-band analysis (`band_id` is stamped on
  every `run_started` row).
- **Placeholder caveat.** The Sump's identity is a **tint pass** on placeholder tiles + placeholder
  hazard sprites — judge the *layout / hazard fun / difficulty step*, not the pixel-craft.

**Deferred (not in this build):** the new hazards are **Sump-only** (not in band 1's preset — a clean
A/B for SG2); The Sump's look is a **tint**, not a bespoke tileset; the **hub iso props are not yet
re-dressed** around the second portal (a later art-pass watch-item); no save change (band choice is
per-dive, not persisted).

---

## 6. Publish + changelog

- **changelog.txt** — updated by SG1 with an **M1.9 — "The Sump"** block documenting the M1.8→M1.9 delta
  as a clean **feature list**: the second dive portal + The Sump band (branchier, sepia-amber flooded
  decay, vault set-piece, +15% budget), the two Sump-only hazards (The Wrecker charger with its
  bait/dodge/punish + dash-invuln, the throw-death Splitter), and the generated Oppositions debug tab
  (91 knobs). A one-line "under the hood" note flags that hazards/bands are now data. Intra-M1.9 fixes
  are folded into each feature's final-state description, not listed. A "NOT YET IN THIS BUILD" note flags
  the Sump-only hazards, the tint-not-tileset look, the un-re-dressed hub props, and the unchanged save.
- **Publish to itch** — `BUTLER=/mnt/c/wsl-libraries/butler/butler bash Game/tools/push_itch.sh` (stamp →
  export Web preset → `butler push qusto/the-far-yard:html5`). The godot web-export exit-crash after
  "DONE savepack" is HARMLESS (documented in the script); the script gates on artifact existence, not the
  exit code.

### 6.1 Publish record

- **Build id (itch userversion):** `m1-20260704-8412732` (see §7 — the SG1 build commit `8412732`).
- **Build stamp (in-game `BuildVersion.short_sha`):** `8412732` (stamped by `tools/stamp_build.sh` at
  publish time; `build_info_gen.gd` is gitignored).
- **Butler push confirmation:** `pushed qusto/the-far-yard:html5 @ m1-20260704-8412732` (re-used 97.95%,
  build now processing — full log in §7).
- **Live page:** `https://qusto.itch.io/the-far-yard` (Chrome/Edge only — SharedArrayBuffer/COEP;
  password-gated). Web telemetry returns via the in-game "Export telemetry" button.

---

## 7. Publish log

- **SG1 build commit:** `84127328c638c5d10276efd22a82d431ed8acc8b` (short `8412732`) — the verified,
  clean-tree commit the build was stamped + exported from.
- **Build id (itch userversion):** `m1-20260704-8412732` (date is UTC; SHA matches the SG1 commit,
  clean — no `+dirty`).
- **In-game build stamp:** `BuildVersion.short_sha == "8412732"` (stamped by `tools/stamp_build.sh` into
  the gitignored `build_info_gen.gd`).
- **Publish command:** `BUTLER=/mnt/c/wsl-libraries/butler/butler bash Game/tools/push_itch.sh` (from repo
  root). The godot web-export exit-crash after "DONE savepack" did NOT occur this run (clean export);
  artifact-existence gate passed (`index.html` + `index.wasm` + `index.pck`).
- **Butler push confirmation:**
  - `• For channel 'html5': last build is 1765927, downloading its signature`
  - `• Pushing 37.84 MiB (12 files, 0 dirs, 0 symlinks)`
  - `✓ Re-used 97.95% of old, added 794.03 KiB fresh data`
  - `✓ 490.62 KiB patch (98.73% savings)`
  - `• Build is now processing, should be up in a bit.`
  - `pushed qusto/the-far-yard:html5 @ m1-20260704-8412732`
- **Live page:** `https://qusto.itch.io/the-far-yard` (Chrome/Edge only — SharedArrayBuffer/COEP;
  password-gated). Web telemetry returns via the in-game "Export telemetry" button (P → Meta tab).

---

## 8. Acceptance criteria (M1.9 / SG1)

1. **A fresh build boots, reaches the hub with both portals, and the complete loop + both dives run
   end-to-end** — all §3 objective rows green.
2. **The all-off control reproduces the M1.0–M1.8 baseline exactly** (fp `e943ac9c8bc1` unmoved through
   the new `BandPipeline` + `EncounterBuilder` call sites and every rg1 verify).
3. **The coverage discipline held** — 91/91 knobs + per-def params↔schema bijection for all 7 defs (grown,
   not dropped).
4. **No save-schema change** (META v4 / RUN v1; band choice is run-state; existing migrations stand, no
   new fixture).
5. **Both portals route deterministically** (band 1 = `band_greybox` control byte-identical; band 2 = The
   Sump with a distinct fp; `band_id` stamped on runs).
6. **The two new hazards + The Sump pass their behavior/cap/determinism tests**, shipped almost entirely
   as data (the "content = data" proof — SG3 judges the true code cost).
7. The build + this doc + the updated changelog are **ready for the Director's playtest** (published to
   itch), with the Sump *feel* read correctly human-deferred (§5) and telemetry analysis owned by SG2.

A build that passes the §3 matrix (all rows green) + ships the changelog + is published to itch satisfies
SG1. Done means: the matrix is filled, the worklog names the commit SHA(s), the build boots to a hub with
two working portals, the all-off control is byte-identical, the coverage/save invariants hold, and the
itch push is confirmed.
