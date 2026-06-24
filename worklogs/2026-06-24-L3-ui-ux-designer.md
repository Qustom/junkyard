# Worklog — L3 Money-text reposition (#8)

- **Date:** 2026-06-24
- **Subagent:** ui-ux-designer
- **Milestone:** M1.5
- **Branch:** ui-ux-designer/L3
- **Commit:** 468ca78c7ad7317fdbb574c0331bf53c4c09fabf (worklog SHA recorded by a trailing commit; the .tscn change lands in this commit)

## What changed
Repositioned the run-haul money readout (`HaulValueLabel`) in `ui/hud/decision_hud.tscn`
from top-left (where it hid behind / was visually swallowed by the bottom-right inventory
panel) to the top-right band directly **below the dive timer**, right-aligned. Pure
`.tscn` layout edit to a single node, using the FROZEN offsets from the L3 spec's
Resolved Decisions (Phase 3). No `.gd`, string, knob, save, or fingerprint change.

## Files touched
- `ui/hud/decision_hud.tscn` — `HaulValueLabel` re-anchored top-left → top-right under the
  timer band; right-aligned. Theme/font overrides (white / black outline 5 / size 22 — the
  legibility layer) left unchanged.

## Offsets before/after (the only change)
| property | before | after |
|---|---|---|
| `anchors_preset` | `0` (top-left) | `1` (top-right) |
| `anchor_left` | (0.0 implicit) | `1.0` |
| `anchor_right` | (0.0 implicit) | `1.0` |
| `offset_left` | `16.0` | `-228.0` |
| `offset_top` | `16.0` | `70.0` |
| `offset_right` | `256.0` | `-16.0` |
| `offset_bottom` | `44.0` | `98.0` |
| `grow_horizontal` | (2 default) | `0` (grow left) |
| `horizontal_alignment` | (unset → LEFT) | `2` (RIGHT) |
| theme/font overrides | white / black / outline 5 / size 22 | UNCHANGED |

`unique_name_in_owner = true` and node name `HaulValueLabel` preserved so `%HaulValueLabel`
keeps resolving; `decision_hud.gd` (`_refresh_haul()` + `_process` pulse) untouched.

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK (HUD scene loads)
- [x] definition of done met: "the run-haul money readout sits below the dive timer
  (top-right band), right-aligned, legible against the world, and no longer collides with
  the bottom-right inventory panel. `_refresh_haul()` unchanged; smoke test + `--import`
  still pass."

## Design deviations
none — implemented exactly to the FROZEN offsets in the L3 spec's Resolved Decisions
(Phase 3). Layout-only; no logic, string, knob, save, or fingerprint impact.

## Handoffs / follow-ups
- Visual polish (an optional `$`/coin-glyph "money" prefix vs the current `tr("HUD_HOLDING")`
  "Holding: N" text) is deferred out of L3 per Phase-3 "Needs Director review" — a separate
  content/localization taste call, not bundled into this layout fix.
