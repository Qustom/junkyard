# Worklog — RG1 — M1.6 build + verify + changelog (Surface & Staging)

- **Date:** 2026-06-26
- **Subagent:** qa-playtest-coordinator
- **Milestone:** M1.6 (Surface & Staging)
- **Branch:** qa-playtest-coordinator/RG1
- **Commit:** 722f10763adcc0c0d3949a3918aa3fc3f79ef290 (this worklog committed via amend onto that SHA; the final branch HEAD after amend is recorded in git log on qa-playtest-coordinator/RG1)

## What changed

RG1 is the M1.6 re-gate build-verify + document task (no gameplay/system code change). I
authored the RG1 build-verify doc (`design/M1_6_Tasks/RG1_playtest_build.md`, mirroring the
M1.5 RG1 template), added the **M1.6 — "Surface & Staging"** block to `changelog.txt` (delta
from M1.5: real Main Menu, walkable Hub, Shop sell+buy, P-key 7-tab debug menu), and ran the
**full headless verify matrix** — all green. The publish-to-itch step is the orchestrator's
network-gated job (not done here, per the task).

**No new `test_rg1_m16_verify`** was added — a deliberate QA call. The four cross-cutting M1.6
gate claims are each already fully covered by an existing, file-disjoint, individually-green
test (`test_app_router` = surface loop; `test_rg1_m15_verify` = the UNCHANGED dive preset + fp;
`test_shop_economy`+`test_save_migration` = shop sell/buy/persist + v4 bump; `test_config_menu`/
`test_run_config`/`test_corridor_lever` = 89 knobs + fp). A consolidated m16 test would only
re-instance the same scenes and re-assert the same things — pure duplication, plus a concurrent-
instance risk. Rationale recorded in the doc §4.4.

## Files touched

- `design/M1_6_Tasks/RG1_playtest_build.md` — NEW. The build-verify doc: the M1.6 surface loop,
  the verify matrix (headless rows + human-deferred rows), the publish/changelog steps, the
  config-sweep guidance, watch-items.
- `changelog.txt` — added the M1.6 "Surface & Staging" feature block above the M1.5 block.
- `worklogs/2026-06-26-RG1-qa-playtest-coordinator.md` — this worklog.

## Checks run — the full M1.6 verify matrix (HEADLESS, one godot instance at a time)

All run with `export PATH="$HOME/.local/bin:$PATH"`, godot 4.6.3-stable, as SCENES (not --script
where applicable). Every command exited 0.

| Command | Result |
|---|---|
| `godot --headless --import` | **PASS** — clean, no parse errors, exit 0 |
| `godot --headless --script res://tools/ci_smoke_test.gd` | **PASS** — "SMOKE OK — M0 architecture spike healthy", exit 0 |
| `godot --headless tests/test_app_router.tscn` | **PASS** — "ROUTER OK — App router boots → menu → hub → dive → hub; current_state correct", exit 0 |
| `godot --headless tests/test_shop_economy.tscn` | **PASS** — "SHOP ECONOMY OK — 3-item persistent catalog … purchase() debits+records+persists, reject paths inert … wipe clears owned_items, SELL-tab … credits the held haul", exit 0 |
| `godot --headless tests/test_save_migration.tscn` | **PASS** — 3× "SAVE MIGRATION OK" (v1→v4, v2→v4, v3→v4; defaults added across the chain, existing fields intact, .bak preserved), exit 0 |
| `godot --headless tests/test_main_game_loop.tscn` | **PASS** — "MAIN GAME OK — assembled dive-only scene … haul held-banked (not sold) … second run restarted clean", exit 0 |
| `godot --headless tests/test_rg1_m15_verify.tscn` | **PASS** — "RG1 M1.5 VERIFY OK"; fp=`e943ac9c8bc1`; 12 rows headless-verified, 7 deferred (the dive preset is UNCHANGED in M1.6), exit 0 |
| `godot --headless tests/test_config_menu.tscn` | **PASS** — "CONFIG MENU OK — CFG verified (89/89 knobs bound + reachable … Reset returns the all-off baseline)", exit 0 |
| `godot --headless tests/test_run_config.tscn` | **PASS** — "R0 OK — RunConfig all-off default … all 89 knobs … does NOT leak into the all-off control", exit 0 |
| `godot --headless tests/test_corridor_lever.tscn` | **PASS** — "J4 OK — … neutral default fp byte-matches the locked baseline (e943ac9c8bc1) …", exit 0 |

**Invariants confirmed:** all-off band fp `e943ac9c8bc1` (unmoved — twice: m15-verify + corridor-lever);
89-knob count holds (config_menu 89/89 + run_config 89); META `SCHEMA_VERSION == 4` (verified in
`systems/save_manager.gd:15`) + v1/v2/v3 migrate forward; surface loop boots end-to-end; shop
sells+buys+persists; `run_ended` arity locked.

**Excluded from the gate:** `test_rg1_m13_verify` — pre-existing stale (FU3 filed), predates M1.6,
not an M1.6 regression. Noted in the doc §5.

**Headless teardown noise:** several tests print "ObjectDB instances leaked at exit" / "N resources
still in use" / "RIDs … leaked" at exit. Standard Godot headless scene-teardown messages, NOT test
failures — every test prints its OK line and exits 0 (same noise as M1.5's RG1).

- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] full M1.6 verify matrix passes (10 commands above, all green)
- [x] definition of done met: "the RG1 build-verify doc exists with a complete verify matrix
  (headless green + human-deferred rows listed); changelog carries a clean M1.6 feature block
  (delta from M1.5); the full headless matrix is green (fp e943ac9c8bc1, 89 knobs, save v4,
  surface loop, shop); worklog names the commit SHA; committed on qa-playtest-coordinator/RG1
  (not merged/pushed)."

## Design deviations

**none.** RG1 is verify + docs only — no gameplay/system code, scene, or `project.godot` change.
The decision to NOT add a `test_rg1_m16_verify` is an explicit QA judgment within the task's
remit ("Optionally a thin test … IF it adds value … If the existing tests already cover it, say
so and DON'T duplicate — your call as QA"), not a design deviation.

## Handoffs / follow-ups

- **Orchestrator:** publish to itch via `bash tools/push_itch.sh` (`BUTLER=/mnt/c/wsl-libraries/
  butler/butler`) — the network-gated step RG1 does not perform. Then Director playtest → RG2 → RG3.
- **Human-deferred playtest rows (Director must check)** — the *felt* surface, listed in the doc §4.5:
  Main Menu navigation + New-Game wipe-confirm + Continue-disabled + Settings-placeholder + the
  first-run consent prompt; walking the Hub + portal/Shop discoverability + no-clock-in-hub; portal→dive
  + auto-return-to-hub + quota-miss wipe-on-return; Shop SELL tally + BUY spend + owned/can't-afford
  rejects + persistence across quit/relaunch; P-overlay open/close in all 3 states + in-dive pause +
  the 7 tabs + the Vision tab split + the Meta-tab Export-telemetry button; and the whole-loop "does it
  read as a game now" gate question.
- **RG2 watch-item:** shop upgrade EFFECTS are stubbed (greybox) — the meta-spend loop is proven, the
  in-dive effects are a later milestone.
- **Pre-existing:** `test_rg1_m13_verify` stale (FU3) — excluded from the M1.6 gate.
