# Worklog — V9 Housekeeping: dead folders + dead run.sav path

- **Date:** 2026-07-10
- **Subagent:** general-purpose
- **Milestone:** M1.12 (Wave 1)
- **Branch:** feat/V9-housekeeping
- **Commit:** `0af12815309bd110dc81ad0fe59dc75114381ebd`

## What changed
Per `design/M1_12_Tasks/V9_housekeeping.md`'s Resolved Decisions (RD-V9-1..5) and the Director's
D-RAT-6 ratification (`M1.12_Breakdown.md`): (a) deleted all four confirmed-empty placeholder data
folders (`data/items/`, `data/enemies/`, `data/recipes/`, `data/upgrades/` — each held only a
`.gitkeep`, zero references anywhere in the tree). (b) Deleted the dead `run.sav` docstring clause
and the unused `RUN_SCHEMA_VERSION` const from `save_manager.gd`, replacing the docstring with an
honest "declared, never implemented, M2 can re-add" note. (c) Added a one-line `TODO(multi-slot UI,
M1.12 V9)` tracking comment at all 7 bare `SaveManager.save_meta(0)` call sites in `game_state.gd`
(no behavior change; line 387 already had an inline comment, so the marker was appended rather than
duplicated). `test_money_ledger.gd`'s two fixture-code `save_meta(0)`/`load_meta(0)` calls were left
untouched per RD-V9-4.

Pre-deletion verification (per the task's hard-stop instruction): re-ran
`grep -rn "res://data/items\|res://data/enemies\|res://data/recipes\|res://data/upgrades" Game --include=*.gd --include=*.tres --include=*.tscn --include=*.godot`
→ zero hits (exit code 1). Proceeded with deletion of all four (no STOP condition triggered).
Also re-confirmed `run\.sav|run_sav|RUN_SAV|RUN_SCHEMA_VERSION` greps only the two `save_manager.gd`
lines before editing.

## Files touched
- `Game/data/items/.gitkeep` — deleted (folder removed via `git rm -r`)
- `Game/data/enemies/.gitkeep` — deleted (folder removed via `git rm -r`)
- `Game/data/recipes/.gitkeep` — deleted (folder removed via `git rm -r`)
- `Game/data/upgrades/.gitkeep` — deleted (folder removed via `git rm -r`)
- `Game/systems/save_manager.gd` — rewrote docstring line (run.sav clause removed, honest note
  added); deleted unused `const RUN_SCHEMA_VERSION := 1`
- `Game/systems/game_state.gd` — added a one-line tracking comment at each of the 7 bare
  `SaveManager.save_meta(0)` sites (lines ~181, 307, 387, 432, 474, 556, 608); no logic change

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors; re-grepped output for
      error/invalid/missing/fail — none found beyond benign "post-reimport" strings)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0
      architecture spike healthy`
- [x] `godot --headless --path Game res://tests/test_save_migration.tscn` → all three fixtures
      (v1→v4, v2→v4, v3→v4) report `SAVE MIGRATION OK`; meta schema confirmed unchanged at v4
- [x] Definition of done met: "deleted folders/paths confirmed absent; import + smoke green (no
      broken res:// refs); save-migration tests (v1/v2/v3→v4) still green; slot-0 note present" —
      all satisfied. Each headless instance run one at a time (no concurrent godot processes).

## Debt ledger
- **2 additional fossil folders deleted beyond V9's original doc scope** (D-RAT-6 upgraded the
  disposition from "keep recipes/upgrades" to "delete all four"): `data/items/`, `data/enemies/`,
  `data/recipes/`, `data/upgrades/` — 4 empty folders + 4 `.gitkeep` files removed, 0 references
  anywhere, import/res:// resolution unaffected.
- **1 false "resumable dive" infra claim retracted** from the save-architecture docstring
  (`save_manager.gd`) + **1 unread constant deleted** (`RUN_SCHEMA_VERSION`) — 2 lines net removed,
  1 line rewritten to be honest about the feature's actual (non-existent) status.
- **7 undocumented magic-number call sites annotated** (`game_state.gd` bare `save_meta(0)`) — zero
  behavior change, but the multi-slot-UI debt is now discoverable at every site a future task will
  need to touch, and explicitly points at the existing `main_menu.gd` `SAVE_SLOT` precedent + the
  scheduled V4 GameState split as the correct seam to introduce a real constant later (per RD-V9-3,
  no `const SAVE_SLOT` introduced this pass — deliberately deferred to avoid a V4 coordination
  problem).
- **Net:** 4 fossil folders gone, one misleading docstring claim corrected, and 7 sites of
  previously-invisible slot-hardcoding debt made visible — all with zero behavioral/schema change
  (meta stays v4).

## Design deviations
None from the binding Resolved Decisions in `V9_housekeeping.md` / the Director's D-RAT-6. Note for
the record: the Phase-2 doc's own recommendation was "keep `data/recipes/`+`data/upgrades/` for M2,"
but the Director's D-RAT-6 ratification (recorded in `M1.12_Breakdown.md`, dated 2026-07-10)
explicitly overrode that recommendation to "DELETE ALL FOUR" — this worklog implements the
Director's ratified call, not the Phase-2 doc's original recommendation, per the doc's own
Resolved-Decisions framing ("D-RAT-6 ... Director ... chose delete-all — M2 re-creates them when
needed; trivially reversible"). This is not a new deviation — it is the already-dispositioned
Director verdict being carried out.

## Handoffs / follow-ups
- The real `const SAVE_SLOT` (or `SaveManager.DEFAULT_SLOT`) should be introduced only after V4
  (GameState split, Wave 3) lands — per RD-V9-3's reasoning, introducing it now would hand V4 an
  unplanned coordination problem across the post-split Economy/QuotaLadder/core files.
  `main_menu.gd:17`'s `SAVE_SLOT` const remains the only existing precedent in the codebase.
- If M2's crafting/upgrades system ends up wanting dedicated `data/recipes/`/`data/upgrades/`
  Resource folders, they'll need to be recreated (`mkdir` + `.gitkeep` or immediately populated) —
  a trivial cost, as anticipated in the Director's D-RAT-6 rationale.
