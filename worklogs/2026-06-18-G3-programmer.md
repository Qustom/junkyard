# Worklog — G3 Greybox Playtest Build

- **Date:** 2026-06-18
- **Subagent:** programmer (general-purpose)
- **Milestone:** M1
- **Branch:** worktree branch `worktree-agent-ae8c5901c78482bba` (isolated G3 worktree)
- **Commit:** 9107a2a1392f4318781c400643d654cebf375c50 (`M1-G3: assemble full greybox playtest loop`; this worklog's SHA reference is finalised in the immediately-following bookkeeping commit)

## What changed
Assembled the whole M1 loop — built+tested in isolation through waves 1–4 — into ONE
playable scene (`scenes/game/main_game.tscn`), the project's first `run/main_scene`.
Wired the single `start_new_run()` loop entry (menu Start + `SellScreen.continue_pressed`
both call it; W4-11), the player `"player"` group + the D3 drop-lookup switch (W4-6), a
build-identity stamp emitted into telemetry, file logging for crash capture, the Win64
export preset, and a gated nightly Butler/itch workflow (publish is human-gated). Added
two headless loop-drive verifications.

## Files touched
- `scenes/game/main_game.tscn` + `scenes/game/main_game.gd` — NEW. The assembled loop:
  main menu → `start_new_run()` (generate B2 band → grade B3 → plan B3 → materialise piece
  instances at cell offsets → spawn C2 junk pickups → place E1 gate at `GATE_SPAWN_OFFSET`
  → spawn player at entry, camera follows → `GameState.start_run` + `enter_band`). Subscribes
  `SellScreen.continue_pressed → start_new_run`. Tears down the prior band each run; meta
  persists, run-state resets via `start_run`. K (`debug_kill`) death path works via the
  GameState autoload, confirmed in the assembled scene.
- `project.godot` — set `run/main_scene` to the new scene; enabled `file_logging` →
  `user://logs/godot.log`; added `application/config/build_sha` (dev fallback, baked by CI).
- `systems/version.gd` — NEW `BuildVersion` static helper → `m1-<YYYYMMDD>-<shortsha>`
  (autoload-free, mirrors the Settings pattern; SHA from ProjectSettings or committed fallback).
- `systems/telemetry/telemetry.gd` — stamp `build` onto the `run_started` data dict (extra
  field only; envelope + all other rows untouched, so G2 tests stay green).
- `entities/player/player.tscn` — added the root node to the `"player"` group (W4-6).
- `ui/inventory/inventory_panel.gd` — drop-position lookup switched from the `current_scene`
  tree-walk to `get_tree().get_first_node_in_group(&"player")`; removed the dead `_find_player`
  recursion (W4-6).
- `tests/test_loop_drive.gd` + `.tscn` — NEW. Drives 3 runs in one session through GameState's
  API: extract→sell, fresh-start→death(pockets)→sell, restart-after-fail. Asserts run-state
  reset, meta persistence, pockets ≤ budget, lifecycle fired 3×. Prints `LOOP OK`.
- `tests/test_main_game_loop.gd` + `.tscn` — NEW. Instances the real MainGame, calls
  `start_new_run()`, asserts band/pickups/gate built + player in group, drives a real
  interaction pickup + gate extract (→ run_ended[extract] → SellScreen sells → Money up),
  then restarts clean. Prints `MAIN GAME OK`.
- `tools/playtest/loop_smoke_checklist.md` + `tools/playtest/tester_readme.md` — NEW manual
  pass + tester instructions (controls, telemetry opt-in, `user://` paths per OS, send-back).
- `export_presets.cfg` — NEW canonical `Win64` desktop preset (referenced by name in CI).
- `.github/workflows/nightly.yml` — NEW. `test` gate job (import+smoke+migration+both loop
  drives+GdUnit4) → `export-and-publish` job (`needs: test`) that bakes the SHA, exports Win64,
  uploads the artifact, and pushes to itch via Butler **only when `BUTLER_API_KEY` is set**.

## Checks run
- [x] `godot --headless --import` clean (no parse errors; ignored pre-existing `*.translation` warnings)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK**
- [x] Boot `res://scenes/game/main_game.tscn --quit-after 120` → no error spew to stderr
- [x] `godot --headless res://tests/test_loop_drive.tscn` → **LOOP OK — 3 runs … run_started/run_ended fired 3× each.**
- [x] `godot --headless res://tests/test_main_game_loop.tscn` → **MAIN GAME OK — assembled scene … second run restarted clean.**
- [x] GdUnit4 suite (`tools/run_gdunit.sh`) → **30 test cases | 0 failures | PASSED**
- [x] Legacy ad-hoc suite green: save-migration, telemetry-jsonl (9 rows), decision-hud,
      sell-screen, drop-swap (found player via the new group lookup at (640,360)),
      player-movement, interaction, dive-clock, run-inventory, inventory-ui, money-ledger,
      death-drop, band-depth, bandgen-determinism, junk-pickup — all OK.
- [x] Telemetry `run_started` row carries `"build":"m1-20260618-852b6e2"`; envelope intact.
- [x] `Win64` export preset recognised (Godot parses it, fails only at the missing-templates
      step — the documented human/CI requirement, not a malformed preset).
- [x] **Definition of done:** "A fresh build runs the complete loop with no blockers; multiple
      runs per session are possible." — met: assembled scene boots to a menu, runs the full
      loop, and both drives prove repeat runs in one session.

## Design deviations
1. **No in-build first-run telemetry consent prompt (yet).** The G3 spec recommends an explicit
   in-build opt-in prompt; I shipped the README opt-in instruction + the existing settings toggle
   instead (the settings opt-in panel already exists from G1). The in-build prompt is a UI task
   better suited to `ui-ux-designer`; flagging for the Director — if empty G4 telemetry is a real
   risk, plan it as a small follow-up task. (Recommendation: add the prompt before the G4 cohort.)
2. **Per-run seed policy is local to MainGame** (`time*31 + run_count*const`). There is no meta
   seed/run-counter system in M1; this is a reasonable placeholder that varies layout per run
   while staying reproducible within a process. A real meta layer will own seed policy later.
3. **`enter_band(BAND_ID)` is called once after `start_run`** so the HUD reads "Depth 1" in the
   single M1 band (rather than 0 at the gate). M1 has one band; multi-band descent is post-M1.
These are recorded in `design/DESIGN_DEVIATIONS.md` for the wave-5 close-out.

## Human-gated (cannot be completed without a human) — flagged loudly
- **Butler/itch publish:** `nightly.yml` references `secrets.BUTLER_API_KEY` and a placeholder
  slug `studio/the-far-yard:win-nightly`. A human must (1) create the itch project under the
  STUDIO account (restricted/draft), (2) generate + store the `BUTLER_API_KEY` repo secret,
  (3) set the real channel slug in `ITCH_TARGET`, and confirm once with a manual `butler push`.
  The publish steps are guarded to SKIP (with a warning) when the secret is absent — no fabricated
  key or slug. **No secret or slug was invented.**
- **Windows export templates / shippable `.exe`:** A real `--export-release` needs the Godot
  4.6.3 Windows export templates installed (the headless box here has none). I verified the
  preset is well-formed (Godot reaches the template-lookup step) but did NOT produce a `.exe`.
  CI fetches the templates; locally a human installs them via the editor. No build artifact is
  claimed that was not produced.

## Handoffs / follow-ups
- **G4 (fun-gate playtest) needs:** this build + `tools/playtest/tester_readme.md` (controls,
  telemetry opt-in, `user://telemetry/run_log.jsonl` + `user://logs/` send-back) and
  `tools/playtest/loop_smoke_checklist.md`. Telemetry `build` field ties feedback to a build.
- **Director, wave-5 close-out:** disposition the 3 deviations above (esp. #1, the consent prompt).
- **Producer/human:** provision the itch project + `BUTLER_API_KEY` before the first nightly publish.
