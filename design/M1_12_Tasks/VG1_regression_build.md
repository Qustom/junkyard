# VG1 — M1.12 Regression Build Verify (no publish this cycle)

**Date:** 2026-07-11
**Branch:** `feat/VG1-regression-verify` (worktree, off `main`@`dc0f763`)
**Assignee:** qa-playtest-coordinator
**Context:** M1.12 is a NO-PLAYER-FACING-CHANGE regression/debt-paydown version (R2–R10 of
`design/report-09072026.docx` §10, minus deferred R1). Its gate (per DR-1, Director-ratified
"regression gate, playtest optional") is: is the game provably byte-unchanged where a fingerprint
pins it, and is the debt provably down? This doc is that proof.

**Director directive for this cycle: NO itch publish** (CI/CD stopped — GitHub LFS bandwidth
limit exhausted). Verify + docs only; no production code touched; no `butler`/`push_itch.sh`
invoked.

---

## 0. The trap this run guarded against

A prior VG1 pass found that a GDScript `SCRIPT ERROR` mid-assertion does **not** stop a
self-quitting headless test scene from exiting 0 — the scene's own auto-quit still fires after
the error, so a broken assertion can print a stale "OK" line and look green. Two tests
(`test_new_hazard_spawn`, `test_rg1_m13_verify`) were caught doing exactly this after V3b deleted
the APIs they still called. Task **VG1-fix** (`81f92b3`, merged as `81f92b3`→`9655901`→`5323b44`
→`dc0f763`) scrubbed both, test-only, no production code touched.

**This run's verification method:** every test below was run as its own headless Godot process,
**full stdout+stderr captured**, and grepped for `SCRIPT ERROR|Invalid call|Nonexistent function
|Invalid access` (case-insensitive). A test is only recorded PASS if BOTH the process exit code is
0 AND that grep found zero hits. The printed "OK"/summary line is corroborating evidence, never
the sole signal.

---

## 1. Full regression verify matrix — ALL GREEN (67/67 scene tests + import + smoke + catalog)

Run one Godot headless instance at a time (no concurrency — the documented no-concurrent-headless
deadlock constraint), `godot --headless --path Game res://tests/<name>.tscn` (or `--script` for the
two tool checks). PASS = exit 0 AND zero `SCRIPT ERROR`/`Invalid call`/`Nonexistent function`/
`Invalid access` hits in the full captured stderr.

### Pre-flight

| Check | Result | Stderr-clean |
|---|---|---|
| `godot --headless --path Game --import` | 0 script/parse errors across the whole project | YES |
| `godot --headless --path Game --script res://tools/ci_smoke_test.gd` | `SMOKE OK — M0 architecture spike healthy` | YES |
| `godot --headless --path Game --script res://tools/check_junk_catalog.gd` | `JUNK CATALOG OK` | YES |

### The 4 permanent controls (byte-identical — the master regression contract)

| Control | Test | Result | Stderr-clean |
|---|---|---|---|
| All-off `RunConfig` layout fp | `test_band_pipeline_parity` | `PIPELINE PARITY OK — BandPipeline byte-matches BandGenerator across 9 seeds (sample seed 12345 -> 12 pieces, **fp=e943ac9c8bc1**)` — **UNMOVED**, matches the pinned M1.9–M1.11 value | YES |
| `band_greybox` | `test_run_config` (R0, all-off default) + cited byte-identical by `test_band_two_profile`/`test_band_three_profile`/`test_encounter_builder` ("all-off fp e943ac9c8bc1 pinned") | `R0 OK — RunConfig all-off default verified (M1.0 baseline)…, all 51 knobs…` | YES |
| `band_two` (The Sump) | `test_band_two_profile` | `BAND_TWO OK — … generates deterministically, stays connected through WearDecay, injects its deep vault, and gates its deck across 9 seeds` | YES |
| `band_three` (The Warren) | `test_band_three_profile` | `BAND_THREE OK — … keeps band_greybox AND band_two byte-identical …` | YES |

`test_band_four_profile` (The Far Field, added in M1.11 — not one of the frozen 4 but a useful
extra corroboration) also passed clean: `BAND_FOUR OK — … keeps band_greybox AND band_two AND
band_three byte-identical …`.

**Confirmation: all four control fingerprints are byte-identical to their pre-M1.12 (M1.11)
values.** The `e943ac9c8bc1` layout fingerprint — pinned since the M1.0 baseline and re-confirmed
at every milestone gate since — is reproduced explicitly by `test_band_pipeline_parity` and
re-affirmed by name inside `test_encounter_builder`'s own assertion string. No task in the M1.12
queue moved it.

### The two just-fixed tests (VG1-fix, `81f92b3`) — re-confirmed clean

| Test | Result | SCRIPT ERROR hits |
|---|---|---|
| `test_new_hazard_spawn` | `K5i OK — new-hazard spawn seam verified: all-off → 0 nodes (M1.3 control), depth-scaled per-room count, per-room cap honoured, shared band ceiling (48) bounds K5a+K5b+K5c combined, placement deterministic (no RNG), and the per-kind spawn_ctx … is built correctly.` | **0** |
| `test_rg1_m13_verify` | `RG1 M1.3 VERIFY OK -- assembled M1.3 build runs the full loop. All-off control is byte-identical to the locked baseline (fp=e943ac9c8bc1); … 14 rows headless-verified; 6 deferred.` | **0** (clean on the FIRST run — no BUG-M13FLAKE hit this pass, no re-run needed) |

Both tests' real assertion functions execute past the line that used to `SCRIPT ERROR` — confirmed
by reading the full captured log for each, not just the trailing summary line.

### Per-task verifications (V1–V9, V3b, V4b)

| Test | Result | Stderr-clean |
|---|---|---|
| `test_junk_catalog_by_id` (V1) | `JUNK BY-ID OK — mid-list insert leaves all 8 weights unshifted; inserted item -> 1.0 default; id-coverage flags it; plan_fingerprint invariant to map hash order.` | YES |
| `test_interaction_owner` (V5) | `INTERACTION_OWNER OK — lockout_s=0.25 debounces then re-arms after the window, lockout_s=0.0 (JunkPickup's case) never debounces, and wrong-id/wrong-parent requests never activate.` | YES |
| `test_jsonl_writer_rotation` (V7) | `JSONL ROTATION OK — a single overflow rotates to one '.1' generation with nothing lost; sustained overflow keeps ring depth at 1 (bounded, not chained); reopening at the same path re-reads the true on-disk length.` | YES |
| `test_rng_substream` (V6) | `RNG SUBSTREAM: ALL GOLDENS PASS (5 derivations byte-identical + Finding-A cross-guard)` | YES |
| `test_greybox_deck_equivalence` (V3 K5) | `V3 EQUIV OK — the band_greybox deck reproduces the pre-migration K5 fair-share plan (exact type coverage, per-type totals within ±15%, entry-safe, caps honoured, deterministic, distribution reaches ≥ as deep) across 3 fixed bands.` — table shows Δ%=+0.0 on every band/type row | YES |
| `test_pursuer_deck_equivalence` (V3b R1) | `V3b EQUIV OK — the band_greybox deck reproduces the pre-migration R1 pursuer per-type TOTAL within ±15% …` — table shows +0.0/+0.0/+11.1 (all within tolerance) | YES |
| `test_config_menu` | `CONFIG MENU OK — CFG verified (52/52 knobs bound + reachable, master+knob+enum edits flow to working config, Reset returns the all-off baseline).` (2 benign `push_warning`s for band_three/band_four `.tres` not resolving as `BandProfile` in the deck-membership display path — pre-existing display-only cosmetic, not a `SCRIPT ERROR`/regression, out of VG1's verify-only scope) | YES |
| `test_save_migration` (V9/no schema bump) | `SAVE MIGRATION OK` ×3 (v1→v4, v2→v4, v3→v4 — all three historical fixtures migrate clean, `.bak` preserved, meta stays v4) | YES |
| `test_quota_system` (V4/V4b) | `QUOTA OK — met advances+persists …, this_run_banked reads sold_total, quota-off fully inert, M1.6 Hub-return cumulative basis counts the held unsold haul.` (exercises the V4b public `quota_ladder().evaluate(...)` seam, private delegate confirmed gone) | YES |
| `test_opposition_components` (V4 facade / S2 goldens) | `S2 GOLDEN PARITY OK — all 5 entity frame-traces byte-identical to the pre-refactor goldens (position/velocity/state/rotation/emit-log).` | YES |
| `test_def_menu_coverage` | `DEF MENU COVERAGE OK — bijection net fires on drift + duplicate ids; zero-defs headless build green; … generic opposition rows (dual-emit intact) …` | YES |
| `test_encounter_builder` (V3 deck lane) | `S3 OK — EncounterBuilder verified: all-off inert (zero requests), the migrated K5 greybox deck routes on the real profile (all three kinds, caps + ceiling held, deterministic — full legacy equivalence in test_greybox_deck_equivalence), … pipeline lvl ext-swap byte-exact + all-off fp e943ac9c8bc1 pinned …` | YES |

### Broad sweep — the remaining `Game/tests/*.tscn` (67 total scene tests, full list)

All 67 scene tests ran; **all 67 PASS, 0 exit-code failures, 0 SCRIPT ERROR/Invalid call/
Nonexistent function/Invalid access hits anywhere in any captured log** (confirmed both per-test
via the matrix runner and via a final `grep -lriE` sweep across the entire `testlogs/` directory,
which returned zero matches):

```
test_ambusher                    PASS   test_junk_pickup                 PASS
test_app_router                  PASS   test_level_scale_determinism     PASS
test_band_depth                  PASS   test_lobber                      PASS
test_band_flavors                PASS   test_loop_drive                  PASS
test_band_four_profile           PASS   test_main_game_loop              PASS
test_band_pipeline_parity        PASS   test_new_hazard_spawn            PASS
test_band_routing                PASS   test_opposition_components       PASS
test_band_three_profile          PASS   test_opposition_def_schema       PASS
test_band_two_profile            PASS   test_pingpong_hazard             PASS
test_bandgen_determinism         PASS   test_player_visual               PASS
test_bomb_hazard                 PASS   test_pursuer_deck_equivalence    PASS
test_burrower                    PASS   test_pursuing_hazard             PASS
test_camera_view                 PASS   test_quota_system                PASS
test_cave_backend                PASS   test_return_cost                 PASS
test_cave_materialise            PASS   test_rg1_loop_verify             PASS
test_charger                     PASS   test_rg1_m12_verify              PASS
test_config_menu                 PASS   test_rg1_m13_verify              PASS
test_corridor_lever              PASS   test_rg1_m14_verify              PASS
test_corridor_summary_row        PASS   test_rg1_m15_verify              PASS
test_deck_entry                  PASS   test_rng_substream               PASS
test_def_menu_coverage           PASS   test_run_config                  PASS
test_drop_swap                   PASS   test_run_duration                PASS
test_duration_loop_reentry       PASS   test_save_migration              PASS
test_encounter_builder           PASS   test_scatter_backend             PASS
test_exit_placement              PASS   test_scatter_materialise         PASS
test_exit_placement_count        PASS   test_sentry                      PASS
test_exposure_meter               PASS  test_shop_economy                PASS
test_greybox_deck_equivalence    PASS   test_spawn_service               PASS
test_hub_contract                PASS   test_spike_hazard                PASS
test_interaction_owner           PASS   test_splitter                    PASS
test_jsonl_writer_rotation       PASS   test_telemetry_config_marking    PASS
test_junk_catalog_by_id          PASS   test_telemetry_consent           PASS
                                        test_telemetry_jsonl             PASS
                                        test_throw_mechanic              PASS
                                        test_within_band_depth           PASS
```

(Recurring benign noise across many logs — `ERROR: N resources/RIDs still in use at exit` /
`ObjectDB instances leaked at exit` — is Godot's own headless-scene-teardown chatter on
`get_tree().quit()`, present across the whole suite pre-M1.12 too; it does not match the
SCRIPT-ERROR grep and is not a regression signal.)

**Minor non-blocking note:** `test_run_config` reports "51 knobs" via `to_flat_dict()` while
`test_config_menu` reports "52/52" bound in the UI — the two tests count slightly different
surfaces (flat-dict serialization vs. UI-reachable knobs) and were both authored/updated together
during V3/V3b; this is not a contradiction requiring a fix under VG1's verify-only contract, just
flagged for whoever next touches `RunConfig`/`ConfigMenu` to reconcile the count in a comment.

---

## 2. Debt ledger — the version's headline measure (net LOC OUT, duplication/coupling retired)

Per the M1.12 breakdown's contract ("not how few lines does new content cost, but how much debt
comes OUT"), consolidated from every task worklog (all commits below are on `main` via
`dc0f763` and its ancestors):

| Task | Commit | Debt retired |
|---|---|---|
| **V1** — by-id spawn weights (R2) | `17d35d2` | Killed the index-aligned `PackedFloat32Array` (fragile positional coupling — any insert/remove/reorder silently misaligned weights) → self-describing `spawn_weights_by_id: Dictionary`. CI misalignment-detection: ~0% → 100%. Net LOC +206 (mostly new regression test coverage, not itself a deletion — the win is eliminating a class of bug, not shrinking a file). |
| **V2** — retire dual-emit legacy signals (R3) | `54131a6` | **EventBus: 60 → 54 signals** (six legacy per-type opposition signals deleted — the largest single signal-count reduction the bus has seen). 6 production emit sites removed. 3 telemetry handlers + 3 connects removed. 3 telemetry schema row-type constants removed (no SCHEMA_VERSION bump). Ends the double-count-avoidance dance in analysis — `opposition_event` is now the single opposition telemetry source. |
| **V3** — migrate K5 (pingpong/bomb/spike) legacy lane → deck (R4) | `6e6c956` | Removed the K5 fair-share machine (`_populate_legacy` ~64 LOC + `_legacy_active_specs` ~23 + `LEGACY_DEF_PATHS` ~8) + 21 `rc.hpp_/hbomb_/hspike_` knobs + their 21 telemetry stamp rows + the config-menu K5 plumbing (3 sections + 3 manifest blocks + Hazards-tab K5 half + 14 ranges) + K5 entities' direct `cfg.h*_*` reads + the `test_encounter_builder` legacy mirror (~85 LOC). **Config surface: 91 → 70 knobs (−21).** Net production-code LOC ≈ **−201**. |
| **V3b** — migrate R1 (pursuer) legacy lane → deck (D-RAT-3, Director-directed full unification) | `f4dddff` | Removed the R1 pursuer machine (~291 net LOC in `main_game.gd`) + 18 `rc.r1_*` knobs (+18 telemetry rows, 2 density consts, 2 BUG6 traps, the `r1_` config-menu section + Hazards tab) + deleted J2/J3 golden tests (419 LOC). **Config surface: 70 → 52 knobs (−18).** Combined with V3: **all three greybox spawn machines retired — every opposition is now added exactly one way.** |
| **V4** — split GameState god-object (R5) | `f8a2adf` | `game_state.gd`: **752 → 467 lines** (lifecycle/facade/serialization dispatch only); new `systems/economy.gd` **251 lines** (currencies/buy/sell/banked-junk/pockets); new `systems/quota_ladder.gd` **96 lines** (K2 ladder + eval + begin_run). Facade preserved — the ~38 dependent files (`main_game.gd`, `decision_hud.gd`, `shop_ui.gd`, …) needed **zero edits**. Meta save bytes byte-identical; v1/v2/v3→v4 migrations unaffected. |
| **V4b** — address the V4 private-quota-delegate deviation (Director: Addressed) | `6e36e57` | Removed the private white-box `GameState._evaluate_quota(sold_total)` delegate; added 2 one-line public accessors (`quota_ladder()`, `held_haul_value()`); rewrote `test_quota_system`'s 6 white-box call sites onto the public `QuotaLadder.evaluate(...)` seam. Byte-for-byte identical behavior; closes the last V4 deviation. |
| **V5** — collapse interaction-owner boilerplate (R6) | `fef4042` | Duplicate-copy count: **4 → 1** (the id-guard + parent-check + fat-finger-lockout block, verbatim across `JunkPickup`/`ExtractGate`/`DeparturePortal`/`HubShop`, now one canonical `InteractionOwner`). Owner files: net **−55** LOC; new helper **+58** LOC (net ≈ +3, but a previously *silent* missing lockout on `JunkPickup` is now an explicit, self-documenting `0.0` parameter). New test coverage +132 LOC (previously zero coverage on the lockout window). |
| **V6** — `RNG.substream(salt)` helper (R7) | `a6d8086` | Sub-stream call sites: **5 (pockets, exits, junk, wear_decay, set_piece_inject) collapsed from 2 hand-rolled idioms → 1 discoverable surface** (2 helper forms preserving both). Duplicate hash-combine `_mix` copies: **2 → 1**. Deleted `junk_placer._substream_seed`, `band_pipeline._stage_seed` + `_mix`. Net LOC ≈ neutral (+42 rng.gd incl. docs, −52 across 5 call sites) — the win is discoverability + one-way-to-do-it, with every migrated sub-stream proven byte-identical (all 4 control fps unmoved). |
| **V7** — telemetry log rotation + analysis argv (R8) | `9ac91e5` | Bounded a previously **unbounded** resource: `run_log.jsonl` (the writer's own docstring admitted "never truncat[ed]") now hard-caps at ~2 MB active + one rolled `.1` generation (~4 MB worst case total) regardless of session count/length. `analyze_m1_2.py`-family scripts parameterized to `argv[1]` (default preserved) — no more source edit per playtest round. |
| **V8** — CI wall-clock instrumentation (R9, cheap-now) | `c4d9c9c` | Instrumentation only, as scoped (DR-5: record now, defer sharding). No runner restructuring, no behavior change to which tests run. Suite boot-cost trend now visible in every CI job's summary/log before the deferred-sharding follow-up is needed. |
| **V9** — housekeeping: dead folders + dead run.sav (R10, D-RAT-6 upgraded to delete-all) | `0af1281` | **4 empty fossil folders deleted** (`data/items/`, `data/enemies/`, `data/recipes/`, `data/upgrades/` — Director chose delete-all over keep-recipes/upgrades, reversible when M2 needs them) + 4 `.gitkeep` files. 1 false "resumable dive" infra claim retracted from `save_manager.gd`'s docstring + 1 unread `RUN_SCHEMA_VERSION` constant deleted. Meta stays v4; no `res://` refs broken (confirmed by clean import). |
| **VG1-fix** — scrub 2 stale silent-pass tests | `81f92b3` | Test-only (no production code): restored real coverage in `test_new_hazard_spawn` (local `_floor_bounds_world` helper replacing the deleted `MainGame._piece_floor_bounds_world` call) and `test_rg1_m13_verify` (`param_overrides["pursuer"]` check replacing the deleted `RunConfig.r1_enabled` read). Both now execute their real assertions and print zero `SCRIPT ERROR`. |

**Consolidated totals (the debt ledger's bottom line):**
- **EventBus: 60 → 54 signals** (−6, the six legacy per-type opposition signals — largest single reduction the bus has ever seen).
- **RNG sub-stream idiom: 5 hand-rolled call sites, 2 duplicated derivations → 1 discoverable `RNG.substream()` surface** (byte-identical at every site).
- **GameState: 752 monolithic lines → 467 (facade/lifecycle) + 251 (`Economy`) + 96 (`QuotaLadder`)** — decomposed along real seams, facade preserved, zero caller edits across ~38 dependent files.
- **Config/knob surface: 91 → 52 knobs** (−39 total across V3's −21 and V3b's −18) — every deletion was a special-cased legacy knob group superseded by the generic deck/def system; the menu shrank, it never grew.
- **All three legacy hazard-spawn machines (K5 fair-share + R1 pursuer + the config plumbing around both) retired → exactly ONE way to add an opposition** (the deck lane, data-only `OppositionDef` + `DeckEntry`) — the version's single largest deletion (~201 + ~291 LOC of machine code alone, plus ~40 knobs and their menu/telemetry scaffolding).
- **4 duplicate interaction-boilerplate copies → 1** (`InteractionOwner`).
- **4 dead empty data folders + 1 dead save-path declaration + 1 unread constant** deleted.
- **1 previously-unbounded telemetry log → hard-capped** (2 MB + 1 rolled generation).
- Net effect across R2–R10: a substantial **negative net-LOC total** in production machine/knob/menu code (V2 + V3 + V3b alone remove on the order of several hundred lines of duplicated/superseded machinery), traded for a small, deliberate, and welcome increase in test coverage (V1, V5) and documentation/helper surface (V6, V7) — exactly the shape the breakdown asked for: "how much debt comes OUT," not "how few lines does new content cost."

---

## 3. The V3/V3b sanctioned behavioral change (DR-3) — equivalence re-confirmed

Per the breakdown's ONE sanctioned exception: band_greybox's hazard-**spawn sequence** changed
(deck spender ≠ old fair-share/R1 machines) — but no **layout** fingerprint moved. Both
equivalence golden tests re-ran clean this cycle:
- `test_greybox_deck_equivalence` (K5: pingpong/bomb/spike) — every band/type row shows **Δ% =
  +0.0** against the frozen pre-migration plan (exact match, well inside the ±15% D-RAT-3a bar).
- `test_pursuer_deck_equivalence` (R1: pursuer) — Δ% = +0.0 / +0.0 / +11.1 across the 3 fixed
  bands, all within the ±15% bar, L2 room-bounds present, entry-safe, deterministic.

Both are Director-signed per DR-3/D-RAT-3/D-RAT-3a/D-RAT-3b/D-RAT-8 (already ratified in the
breakdown at Wave-4 close-out, prior to this gate) — VG1 re-confirms the goldens still hold, it
does not re-litigate the sign-off.

---

## 4. Publish status

**PUBLISH: SKIPPED per Director directive** (CI/CD stopped — GitHub LFS bandwidth limit —
2026-07-09/10). No `bash Game/tools/push_itch.sh`, no `butler`, no network publish step was run
or attempted this cycle. The build is **verified-green locally** (67/67 scene tests + import +
smoke + catalog, all four control fps byte-identical, both equivalence goldens re-confirmed) but
**NOT published to itch.io this cycle**. The itch.io page (`https://qusto.itch.io/the-far-yard`)
still serves the last-published M1.11 build (`m1-20260708-69446d5`, per `STATUS.md`) until CI/CD
resumes and a publish is explicitly authorized.

---

## 5. Summary for VG2/VG3

- All 67 `Game/tests/*.tscn` scene tests + import + `ci_smoke_test.gd` + `check_junk_catalog.gd`
  are green, with full-stderr SCRIPT-ERROR verification (not exit-code-only).
- The 4 permanent control fingerprints (all-off `e943ac9c8bc1`, band_greybox, band_two, band_three)
  are byte-identical to M1.11.
- The two VG1-fix-scrubbed tests (`test_new_hazard_spawn`, `test_rg1_m13_verify`) are confirmed
  clean — zero `SCRIPT ERROR` — and print their real assertion lines.
- The V3/V3b hazard-spawn equivalence goldens hold within the Director-ratified ±15% tolerance.
- The debt ledger (§2) shows the version's headline: EventBus −6 signals, GameState split along
  seams with zero caller churn, config surface 91→52, all three legacy spawn machines retired to
  one deck lane, plus smaller wins (RNG substream, interaction-owner dedup, telemetry log bound,
  dead-code removal).
- No production code changed in this VG1 pass — only `changelog.txt` and this doc.
- No itch publish this cycle, per explicit Director directive.

This evidence is what VG2 (regression/equivalence analysis) and VG3 (Director go/iterate/pivot
verdict) work from. The natural verdict this evidence supports is the one anticipated at
breakdown-authoring time: **go → M2** — the debt is retired, the seams are demonstrably clean, and
nothing the player can see or feel moved.
