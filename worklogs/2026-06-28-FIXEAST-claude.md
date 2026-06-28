# Worklog — FIXEAST (M1.7 post-build bug-fix): regenerate corrupt throw/east

- **Task:** Fix the player throw-east visual glitch reported by the Director ("character cut in half / two images far apart when throwing right").
- **Milestone:** M1.7 (Player Embodiment), post-Wave-1 bug-fix.
- **Agent(s):** orchestrator (Claude) directly — used the PixelLab MCP (subagents can't reach it).
- **Date:** 2026-06-28

## Root cause
`throw/east` (only) shipped a PixelLab generation artifact — all 7 east frames contained two ghost copies of adjacent
characters (green sliver left + a second figure right of the real flannel character). The copy into `Game/` was byte-identical
to the `art_workshop` source (`66e759…`), so it was a faithful copy of a corrupt **source asset**, not a code bug. The other 7
throw directions + all move/pickup were clean.

## What changed
- **Regenerated throw/east** via PixelLab MCP off the existing character `3cb56375-df23-4c9f-9aea-bbfe1a737268`:
  `delete_animation(throw-object, east)` → `animate_character(template=throw-object, directions=[east])` → new clean animation
  `b03f703e-93d2-42df-8a2e-c6baca3507e4` (single character, full wind-up→throw→follow-through, 7f @124×124). Verified clean by
  eye (frames 0/3/6).
- Replaced the 7 `throw/east/frame_00{0..6}.png` in **both** `Game/art/player/throw/east/` and the `art_workshop` source
  (new sha `b760b3…`); corrupt originals remain in git history at `07edb77`. Documented the regen in `art_workshop/.../GENERATION.md`.
- **uid-drift cleanup (bundled):** godot's import had normalized the hand-authored `player_frames.tres` uid
  (`uid://dn0player7frames` → `uid://bd2h7mfhen6uo`) and `test_player_visual.tscn` uid on every import (recurring dirty tree).
  Accepted the godot-generated uids and updated `player.tscn`'s stale ext_resource uid hint to match — ending the drift.

## Files touched
- `Game/art/player/throw/east/frame_00{0..6}.png` (clean frames)
- `art_workshop/game_art/player_explorations/20260627/player_basic_template/throw/east/frame_00{0..6}.png` (corrected source)
- `art_workshop/.../player_basic_template/GENERATION.md` (regen provenance note)
- `Game/entities/player/player.tscn` (uid hint → `bd2h7mfhen6uo`)
- `Game/entities/player/player_frames.tres`, `Game/tests/test_player_visual.tscn` (godot uid normalization)

## Checks run (all green)
- `--import` clean; no NEW uid drift after (uids now stable).
- smoke: `SMOKE OK`.
- all-off fp **`e943ac9c8bc1`** byte-identical (asset-only change, no RNG/RunConfig touched).
- `test_player_visual.tscn` → `PLAYER_VISUAL OK`; `test_config_menu.tscn` → 89/89.
- The throw_east clip in `player_frames.tres` still references the same 7 east frame paths (only PNG bytes changed) — clip
  structure unchanged.

## RG1 manual item
The east-throw reading correctly on-screen needs a GUI/web confirm (headless can't render). Throw right; the character should
play a clean single-figure wind-up→throw.

## Design deviations
None. The PixelLab regeneration was Director-authorized (chose "Regenerate via PixelLab"); art was corrected in place with the
corrupt originals preserved in git history + provenance recorded in GENERATION.md (honors the copy-not-move/preserve-history rule).
