# Worklog — HG1 (M1.8) — Hub Art Dressing playtest build verify + changelog

- **Date:** 2026-06-28
- **Subagent:** qa-playtest-coordinator
- **Milestone:** M1.8 (Hub Art Dressing)
- **Branch:** qa/m1.8-hg1
- **Commit:** 1a551e896fdc6d731262840dbed8b1338b3a71dd (the recorded SHA; a no-op re-amend to
  stamp this exact value would shift it again, so this is the canonical HG1 commit on
  branch `qa/m1.8-hg1` — the worklog content is otherwise final).

## What changed
Authored the HG1 M1.8 build-verify doc (`design/M1_8_Tasks/HG1_playtest_build.md`, from the
M1.7 RG1 template, adapted to the dressed hub), ran the full headless verify matrix green,
and prepended an M1.8 "The Yard Takes Shape" feature block to `changelog.txt` (delta M1.7 →
M1.8). **No game code changed** — this is a verify + document task. M1.8 is an **art-only**
iteration: H0/H1 re-skinned the greybox surface Hub with the Layout-A vertical-spine
placeholder art (tiled-spine ground, `dive_gate`+`portal_glow` portal, `shack_door`+benches
shop, 15 y-sorted dressing props), with **zero** gameplay / save / `RunConfig`-knob change.

## Files touched
- `design/M1_8_Tasks/HG1_playtest_build.md` — the build-verify doc (new).
- `changelog.txt` — prepended the M1.8 block above M1.7 (the dressed-hub feature list).
- `worklogs/2026-06-28-HG1-qa-playtest-coordinator.md` — this worklog.
- (throwaway, created + run + **removed**, not committed) `Game/tests/_tmp_hub_contract.{gd,tscn}` —
  the hub-contract spot-check, run in the real tree (autoloads present) so it had no EventBus
  artifact, then deleted (no persistent value — see HG1 §4.4).

## Checks run — verify matrix (all HEADLESS, one godot instance at a time)
- [x] `godot --headless --path Game --import` → **clean, exit 0** (hub art + `hub_ground.tres`
      TileSet + `hub_ground.gd` paint all compile).
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` →
      **"SMOKE OK — M0 architecture spike healthy", exit 0**.
- [x] **All-off baseline (R0)** — `res://tests/test_run_config.tscn` → **"R0 OK — RunConfig
      all-off default verified … all 89 knobs … J1 make_default_play_preset() is the F1
      stack", exit 0**.
- [x] **Determinism fp (loop unchanged)** — `res://tests/test_rg1_m15_verify.tscn` → **"RG1
      M1.5 VERIFY OK", fp=`e943ac9c8bc1` byte-identical, exit 0** (12 rows verified, 7
      deferred). The M1.8 art-only change did NOT move the all-off fingerprint.
- [x] **Bandgen determinism** — `res://tests/test_bandgen_determinism.tscn` → **"BANDGEN OK —
      determinism + connectivity verified across 9 seeds (sample seed 12345 → 12 pieces,
      fp=e943ac9c8bc1)", exit 0**.
- [x] **Level-scale determinism** — `res://tests/test_level_scale_determinism.tscn` → **"LVL
      OK — count + size + per-catalog determinism verified across 9 seeds", exit 0**.
- [x] **Main game loop** — `res://tests/test_main_game_loop.tscn` → **"MAIN GAME OK", exit 0**.
- [x] **Junk pickup** — `res://tests/test_junk_pickup.tscn` → **"JUNK PICKUP OK", exit 0**.
- [x] **Drop / swap** — `res://tests/test_drop_swap.tscn` → **"DROP SWAP OK", exit 0**.
- [x] **Throw mechanic** — `res://tests/test_throw_mechanic.tscn` → **"L1+L6 OK", exit 0**.
- [x] **Shop economy** — `res://tests/test_shop_economy.tscn` → **"SHOP ECONOMY OK", exit 0**.
- [x] **Quota system** — `res://tests/test_quota_system.tscn` → **"QUOTA OK", exit 0**.
- [x] **App router** — `res://tests/test_app_router.tscn` → **"ROUTER OK — App router boots →
      menu → hub → dive → hub; current_state correct", exit 0** (the hub it routes through is
      now the dressed scene).
- [x] **Hazards (4 types)** — `test_pursuing_hazard` / `test_bomb_hazard` /
      `test_pingpong_hazard` / `test_spike_hazard` → each **exit 0** (e.g. "PURSUING HAZARD
      OK — awakens at depth threshold … room-bound chase … all-off spawns no hazard").
- [x] **Player visual FSM** — `res://tests/test_player_visual.tscn` → **"PLAYER_VISUAL OK",
      exit 0** (the M1.7 opt-in player-art FSM, which renders in the dressed hub too).
- [x] **Config menu 89/89** — `res://tests/test_config_menu.tscn` → **"CONFIG MENU OK — CFG
      verified (89/89 knobs bound + reachable … Reset returns the all-off baseline)", exit 0**.
      M1.8 (art-only) adds no knob.
- [x] **Hub contract spot-check** — throwaway SCENE load of the **dressed** `hub.tscn` (real
      tree, autoloads present) → **"HG1 HUB CONTRACT OK — $Player / $PlayerSpawn /
      $HudLayer/QuotaNotice resolve; DeparturePortal Interactable id=&\"portal\"; HubShop
      Interactable id=&\"shop\"; 4 wall colliders intact; ground TileMapLayer present.",
      exit 0**. Throwaway removed (no committed test — see HG1 §4.4).
- [x] **Save schema unchanged** — inspected `systems/save_manager.gd`: **`META_SCHEMA_VERSION
      == 4`, `RUN_SCHEMA_VERSION == 1` — NO M1.8 bump**. `git diff 50fb401..7df074c` shows
      **no** change to `save_manager.gd` / `tests/fixtures/` / `test_save_migration.gd` →
      no migration, no new fixture. Existing v1/v2/v3→v4 chain stands.
- [x] **Save migration still green** — `res://tests/test_save_migration.tscn` → **"SAVE
      MIGRATION OK — v1 meta fixture migrates to v4 … existing fields intact … .bak
      preserved", exit 0**.

**Matrix result: ALL GREEN.** fp `e943ac9c8bc1` and 89/89 both **unmoved**. Objective M1.8
gate met; the rendered dressed-yard *look* read is correctly human-deferred (HG1 §4.5 + §5).

## New-test decision (QA owns it): NO new `test_hg1_m18_verify`
**Recommend NO** — and that is the call. M1.8 is an art-only/presentation claim whose only
non-rendered surface ("the dressed `hub.tscn` still loads + keeps every functional contract")
is asserted directly by the Hub contract spot-check (node paths, the two Interactable ids,
4 wall colliders, the ground TileMapLayer). The "loop didn't move" claim is covered
byte-for-byte by the fp guard (`test_rg1_m15_verify` → `e943ac9c8bc1`), the bandgen/level-scale
determinism tests, and the full loop/dive/shop/quota/hazard suite — all re-run green here. A
consolidated verify scene would only re-instance the same hub/loop scenes and re-assert the
same contract/fp/loop facts — pure duplication + a concurrent-instance risk. Everything else
M1.8 introduces (the spine reading, the clear lane, prop scale/busyness, golden-hour, framerate
with ~15 props) is **rendered + cannot be asserted headless**. The contract check has no
persistent value (it re-checks node paths H1 already locked), so it ran as a throwaway and was
removed. **No new test committed.**

## Design deviations
**none** (verify + document task — no game code changed). The Wave-1 H0/H1 deviations
(doorway-only shack, camera-zoom 1.2 → 1.05, wall-visual ColorRects kept, 15 props vs. ~10–12)
are already logged in `DESIGN_DEVIATIONS.md` by the H0/H1 worklog and are the Director's to
disposition at the M1.8 wave close-out / HG3 re-gate — HG1 surfaces them in the build-verify
doc (§9) + the Director playtest checklist, it does not re-log or self-disposition them.

## Handoffs / follow-ups
- **Network step (orchestrator-owned):** publish to itch via
  `BUTLER=/mnt/c/wsl-libraries/butler/butler bash Game/tools/push_itch.sh` + the changelog
  hand-off — NOT done here (HG1 produces the verify doc + changelog; the orchestrator publishes).
- **For HG2/HG3 (Director):** the §5 Director playtest checklist (spine reads S→N, central lane
  clear, functional props vs. dressing, prop scale/busyness, golden-hour, loop-identical,
  framerate with ~15 props, player-art-ON y-sorts among props) + the §7 re-gate guidance. HG2
  should confirm no web-build perf regression from the ~15 hub sprites + TileMapLayer (60 FPS /
  ~16 ms budget).
- **Deferred:** the street-exit threshold (H3 PixelLab prop) stays Director-gated; the
  doorway-vs-open-roof shack is a cheap follow-up (plank-floor tiles already imported); the
  dive interiors are still greybox.
