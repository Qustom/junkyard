# Worklog — L4 Grab-prompt visibility fix (#9)

- **Date:** 2026-06-24
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.5 · Wave 1
- **Branch:** general-purpose/L4
- **Commit:** 50646d842fa441c380cc8b408e8549a7f36398b0

## What changed
Fixed the "grab prompt always shows" bug (Director #9). The interaction prompt's
visibility was driven only on a focus *transition* (`best != _current`), so a focused
target that was freed (deferred `queue_free` on pickup) or disabled could trip the
`if best == _current: return` early-out and strand the reused, world-space prompt
visible. The prompt scene also shipped `visible`-by-default with baked `[E] Grab` text.

Fix (the FROZEN fix from the spec's Resolved Decisions): `_prompt.visible` is now a
**per-frame invariant** of `_current`, asserted every `_refresh_current()` via a single
`_update_prompt()` writer — `visible == (_current != null && is_instance_valid(_current)
&& _current.can_interact())`. The transition branch still emits
`interactable_focused`/`interactable_unfocused` on the edge (unchanged contract; unfocus
emit now guarded by `is_instance_valid`). The `.tscn` defaults hidden with cleared text,
plus a belt-and-suspenders `_ready()` hide. The nearest+hysteresis selection loop was
**not** refactored.

One extra defensive line was required beyond the spec pseudocode: a freed Object reference
compares `!= null` as **false** in Godot 4.6 (verified empirically), so `_current` is
normalized to `null` at the top of `_refresh_current()` via a plain
`if not is_instance_valid(_current): _current = null`. Without this, the deferred-free case
would pass a previously-freed instance into the typed `_update_prompt(it: Interactable)`
parameter and throw "previously freed is not a subclass". This is the realized deferred-
`queue_free` hazard the spec's root-cause #1 predicted; it is part of the visibility
assertion (not a selection-loop change).

## Files touched
- `components/interaction/interaction_detector.gd` — replaced the transition-only
  `_show_prompt`/`_hide_prompt` pair with a single per-frame `_update_prompt(_current)`
  invariant; guarded the unfocus emit with `is_instance_valid`; added the freed-`_current`
  null-normalization at the top of `_refresh_current()`. Selection/hysteresis loop unchanged.
- `ui/interaction_prompt.tscn` — root `InteractionPrompt` defaults `visible = false`;
  removed baked `text = "[E] Grab"` from the Label (`_render()` owns the text).
- `ui/interaction_prompt.gd` — added `if _target == null: visible = false` in `_ready()`
  (belt-and-suspenders resting-state hide).
- `tests/test_interaction.gd` — added three hide-invariant regression cases: (1) disable
  the only valid target → prompt hidden; (2) range-exit the focused target (`area_exited`)
  → prompt hidden; (3) deferred-`queue_free` ordering (focused target freed without
  `area_exited`) → prompt not stranded visible. Updated the OK message.

## Checks run
- [x] `godot --headless --import` clean (no parse errors) → IMPORT_EXIT=0
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy`
- [x] `godot --headless --script res://tests/test_interaction.gd` → `INTERACT OK — focus(nearest),
  interaction_requested(target), hysteresis, enabled-guard, and prompt hide-invariant
  (disable/range-exit/deferred-free) verified` (exit 0). NOTE: `test_interaction` is a
  `SceneTree` `_initialize()` script with NO `.tscn` (run via `--script` per its own file
  header), unlike the `.tscn`-backed tests — so it is invoked as `--script`, not as a scene.
- [x] definition of done met: prompt visible iff a focused interactable `can_interact()`;
  hidden after the focused target is freed / disabled / range-exits, including the
  deferred-`queue_free` next-frame ordering. Regression test asserts the hide invariant.

## Design deviations
none. Pure correctness bug-fix as specified: no new knob, no EventBus signal, no
arity change, no save-schema change, no generation/fingerprint change. The freed-object
null-normalization is an implementation detail of the frozen "per-frame invariant" fix
(required because Godot 4.6's `freed != null == false` would otherwise crash the typed
`_update_prompt` boundary in the deferred-free case the spec called out), not a design
departure.

## Handoffs / follow-ups
- Cross-wave note from the spec (NOT acted on in L4): after L1 rebinds `interact` to **F**,
  the prompt key-hint should read "[F]" automatically (derived live from InputMap; the
  baked-text removal here helps). Verify in RG1 after L1 lands.
- Open Question 1 (suppress prompt during rejected-pickup flash) remains a Director
  tone/feel call — left up per the spec recommendation; not implemented.
