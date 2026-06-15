# Worklog — A2 Reusable Interaction Component

- **Date:** 2026-06-15
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1
- **Branch:** general-purpose/A2-interaction
- **Commit:** b8f60e39466039b2e94d40129ba0bb2e2c8b4c47   (A2 implementation; this worklog is a trailing commit on top)

## What changed
Built the composition-first interaction layer per `design/M1_Tasks/A2_interaction_component.md`:
a player-side `InteractionDetector` Area2D that tracks in-range `Interactable`s, picks the
nearest with hysteresis, owns + positions a floating world-space prompt, and on `interact`
emits `EventBus.interaction_requested(id, target)`. The detector stays agnostic — it never
mutates state or frees nodes; the Interactable's owner consumes the request (A3 / dive-flow).
`Interactable` is a reusable Area2D (data + `can_interact()` guard) dropped as a child of
entity scenes. Wired the detector into `player.tscn` and added a demo + headless test.

## Files touched
- `components/interaction/interactable.gd` (+ `.uid`) — `class_name Interactable extends Area2D`; exported `interactable_id`/`display_name`/`prompt_text`/`enabled` + `can_interact()` guard.
- `components/interaction/interactable.tscn` — Area2D on `interactable` layer (bit 3, `collision_layer=4`), empty mask, 16px CircleShape2D.
- `components/interaction/interaction_detector.gd` (+ `.uid`) — `class_name InteractionDetector extends Area2D`; nearest-by-`distance_squared_to` with hysteresis (`SWITCH_RATIO=0.9`) + stable insertion-order tie-break; emits focus/unfocus on EventBus; owns+positions the prompt directly; `interact` handled in `_unhandled_input` + `set_input_as_handled()`; defensively erases freed targets each refresh.
- `components/interaction/interaction_detector.tscn` — Area2D, empty layer, mask=`interactable` (bit 3, `collision_mask=4`), 36px CircleShape2D, `prompt_scene` export wired to the prompt scene.
- `ui/interaction_prompt.gd` (+ `.uid`) — `class_name InteractionPrompt extends Node2D`; `set_target(it)`, copies `prompt_text` with a key hint derived from `InputMap.action_get_events("interact")`, follows target `global_position + offset` in `_process`.
- `ui/interaction_prompt.tscn` — Node2D + outlined Label greybox.
- `entities/player/player.tscn` — added `InteractionDetector` instance as a child of `Player`, `prompt_scene` pre-wired in the detector scene.
- `components/interaction/interaction_test.tscn` — demo: Player + a "Scrap A" (`&"junk"`) and a "Gate" (`&"gate"`) stub + a listener node that prints focus/unfocus/request events.
- `tests/test_interaction.gd` (+ `.uid`) — headless test (see below).

## Checks run
- [x] `godot --headless --import` clean (no parse errors, no warnings) — `Interactable`, `InteractionDetector`, `InteractionPrompt` registered.
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy`
- [x] `tests/test_interaction.gd` → `INTERACT OK — focus(nearest), interaction_requested(target), hysteresis, and enabled-guard verified`
  - asserts: nearest of two stubs is focused (`interactable_focused` fired naming it) + prompt instanced/visible; a synthetic `interact` `InputEventAction` through `_unhandled_input` fires `interaction_requested` with `id=&"junk"`, target=Near; focus switches when a target becomes clearly closer (clean unfocus/refocus); a near-equal challenger (within `SWITCH_RATIO`) does NOT steal focus (anti-flicker); disabling the focused target moves focus to the remaining valid one.
- [x] regression: `tests/test_player_movement.gd` → `MOVE OK` (player.tscn edit didn't break A1).
- [x] both `interaction_test.tscn` and `player.tscn` load + instantiate cleanly headless.
- [x] definition of done met: "A prompt shows when the player is near an interactable; pressing `interact` fires an EventBus signal naming the target." — prompt is instanced/positioned on focus; the interact path emits `interaction_requested(id, target)` naming the focused Interactable.

## Design deviations
none. All five "Open questions" recommendations were followed exactly:
detector owns+positions the prompt via `set_target` (focus/unfocus still emitted on EventBus
for other consumers, prompt independent of them); `Interactable extends Area2D` as a child
node; pure nearest-by-`distance_squared_to` with hysteresis `new_d < best_d*0.9` + stable
insertion-order tie-break; detector stays agnostic (emit-only, never mutates/frees); static
key hint derived from `InputMap.action_get_events("interact")`; `interact` in the detector's
`_unhandled_input` + `get_viewport().set_input_as_handled()`.

One small robustness addition (not a deviation from intent): the `set_input_as_handled()`
call is guarded behind a null `get_viewport()` check so the handler can be unit-tested
headlessly without a window viewport. Behaviour in-game is unchanged.

## Handoffs / follow-ups
- The `interaction_requested(id, target)` contract is ready for consumers: A3 (junk pickup)
  should listen, branch on `id`, mutate run-state, and free/disable its own target — the
  detector cleans `_in_range` on the resulting `area_exited` (and defensively each refresh).
- `interactable_focused`/`interactable_unfocused` are emitted but currently only consumed by
  the prompt (directly) and the demo listener — available for audio/telemetry later.
- Controller glyph swapping deferred to controller-polish (M1 keeps the static keyboard hint).
