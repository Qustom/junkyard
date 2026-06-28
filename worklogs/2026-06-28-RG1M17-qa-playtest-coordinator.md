# Worklog — RG1 (M1.7) — Player Embodiment build-verify doc + changelog

- **Date:** 2026-06-28
- **Subagent:** qa-playtest-coordinator
- **Milestone:** M1.7 (Player Embodiment)
- **Branch:** qa/RG1-m17
- **Commit:** 07e8951b8e891aedca371bb48f0aec5ae28adb18

## What changed
Authored the RG1 M1.7 build-verify doc (`design/M1_7_Tasks/RG1_playtest_build.md`, from
the M1.6 template), ran the full headless verify matrix green, and prepended an
M1.7 "Player Embodiment" feature block to `changelog.txt` (delta M1.6 → M1.7). No code
changed — this is a verify + document task. The M1.7 content is visual/tooling only:
opt-in animated character (default OFF / greybox-parity boot), a new debug Player tab +
movement-lock knobs, and a spawn-interpolation "jump" fix.

## Files touched
- `design/M1_7_Tasks/RG1_playtest_build.md` — the build-verify doc (new).
- `changelog.txt` — prepended the M1.7 block above M1.6 (calls out the character is opt-in via P -> Player tab).
- `worklogs/2026-06-28-RG1M17-qa-playtest-coordinator.md` — this worklog.

## Checks run — verify matrix (all HEADLESS, one godot instance at a time)
- [x] `godot --headless --path Game --import` → **clean, exit 0** (N0 SpriteFrames / N1 FSM / N2 Player tab all compile).
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **"SMOKE OK — M0 architecture spike healthy", exit 0**.
- [x] **Determinism / dive unchanged** — `res://tests/test_rg1_m15_verify.tscn` → **"RG1 M1.5 VERIFY OK", fp=`e943ac9c8bc1` byte-identical, exit 0** (12 rows verified, 7 deferred). The M1.7 art/debug changes did NOT move the all-off fingerprint.
- [x] **Knob coverage** — `res://tests/test_config_menu.tscn` → **"CONFIG MENU OK — 89/89 knobs bound + reachable … Reset returns the all-off baseline", assertion green, exit 0**. Player-tab controls are debug-only (outside MANIFEST); the "Player art (debug)" toggle defaults UNCHECKED.
- [x] **Player visual FSM** — `res://tests/test_player_visual.tscn` → **"PLAYER_VISUAL OK"** (quantize_dir 8 sectors + ZERO-hold + 10° hysteresis; select_state walk/idle @ 8 px/s, action priority, locked-never-walks), exit 0.
- [x] **Movement** — `godot --headless --path Game --script res://tests/test_player_movement.gd` (SceneTree test) → **"MOVE OK — cardinal=91.7px diagonal=91.7px over 0.5s, max_speed=200", exit 0**.
- [x] **Throw/pickup/loop unaffected:**
  - `res://tests/test_junk_pickup.tscn` → **"JUNK PICKUP OK"** (24 pickups, accept/free, full-bag reject, drop re-spawn), exit 0.
  - `res://tests/test_drop_swap.tscn` → **"DROP SWAP OK"** (drop removes from bag, emits junk_dropped, re-instantiates grabbable), exit 0.
  - `res://tests/test_main_game_loop.tscn` → **"MAIN GAME OK"** (band built, pickup + gate-extract → run_ended(extract) haul held-banked, second run clean), exit 0.
- [x] **Save schema** — inspected `systems/save_manager.gd`: **`META_SCHEMA_VERSION == 4`, `RUN_SCHEMA_VERSION == 1` — NO M1.7 bump**. Player art is run-agnostic and persists nothing; the debug toggle is tooling, not state. No new fixture needed; existing v1/v2/v3→v4 migrations + fixtures stand.

**Matrix result: ALL GREEN.** Objective M1.7 gate met; the rendered/felt surface is correctly human-deferred (§4.5 of the doc).

## New-test decision (QA owns it): NO new `test_rg1_m17_verify`
**Recommend NO** — and that is the call. The M1.7 gate is a visual/tooling claim whose only
non-rendered surface (the player visual FSM) is fully covered by `test_player_visual.tscn`;
the "dive unchanged + fp" guard is `test_rg1_m15_verify.tscn`; pickup/throw/extract is covered
by junk-pickup / drop-swap / main-game-loop; movement + 89-knob + save invariants are covered
by their existing tests. Everything else M1.7 introduces — whether the 8-direction character
reads, whether throw-east is a clean single sprite, whether scale/offset seats it, whether the
movement-lock feels right, whether the spawn-jump is gone — is **rendered + input-driven and
cannot be asserted headless**. A consolidated verify scene would only re-instance the same
Player/main_game scenes and re-assert the same FSM/fp/loop facts (pure duplication + a
concurrent-instance risk). If one were ever warranted it would have to assert the toggle's
visibility flip (`debug_player_art_toggled(true)` → AnimatedSprite2D visible / greybox hidden,
`false` → restored), but that trivial wiring is exercised by the rendered human checklist and
does not justify a new scene. **No new test added.**

## Design deviations
- **Stale comment in `systems/event_bus.gd` (~line 236): "Default state is art ON."**
  The as-built default is art **OFF** — the config toggle (`config_menu.gd:694`,
  `button_pressed = false`) and the player scene default are both OFF, and
  `test_config_menu.tscn` passes with art off. This is a stale doc comment, not a behavior
  deviation; the build matches the Director-locked opt-in/default-OFF intent (greybox boot =
  M1.6 byte-for-byte). The M1.7_Breakdown.md Phase-1 draft also said "default = art ON"
  but the build shipped OFF (the locked disposition). Flagged in the RG1 doc §9 as-built note
  for correction during the wave close-out / design reapply. **Needs a one-line doc fix, not
  a code change.** No gameplay/determinism/save deviation.

## Handoffs / follow-ups
- **Wave close-out:** correct the stale `event_bus.gd` "Default state is art ON" comment to
  "Default state is art OFF (opt-in)" during the design reapply sweep (logged above + in RG1 §9).
- **For RG2/RG3 (Director):** the §4.5 human checklist + §5 watch-items — most testers will see
  the greybox unless they flip P → Player → "Player art (debug)"; movement-lock feel under a
  tense extract; 8-direction snapping legibility; dive-gear-vs-surface look. RG2 should also
  confirm no web-build perf regression from the sprite (60 FPS / ~16 ms budget).
- **Network step (orchestrator-owned):** publish to itch + the changelog hand-off — NOT done here.
