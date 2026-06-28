# Worklog — N1 Player visual state machine (8-way + actions + lock)

- **Date:** 2026-06-27
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.7 (Player Embodiment)
- **Branch:** general-purpose/N1
- **Commit:** see branch HEAD of `general-purpose/N1` (this worklog is part of that single N1 commit; the orchestrator records the final SHA on integration)

## What changed
Added a child `PlayerVisual` node (`player_visual.gd`) to `player.tscn` that drives an
`AnimatedSprite2D` off N0's `player_frames.tres`: 8-way idle/walk from the parent's
already-resolved `velocity`/`facing`, pickup/throw one-shots from
`EventBus.junk_picked_up`/`item_thrown`, with a brief clip-driven movement-lock during
action clips. The lock is implemented by the **one** functional edit to `player.gd`'s
`_physics_process` — zeroing the movement `input_dir` while `_visual.is_locked()` so the
UNCHANGED `step_velocity` friction roots the body. The lock is armed ONLY when art is ON;
art-OFF the gate never triggers and the code path is byte-identical to M1.6. Default = art
ON (sprite shown, greybox `Visual`+`Nose` hidden). The pure helpers `quantize_dir`
(8-sector + 10° angular hysteresis) and `select_state` (walk↔idle @8 px/s, pickup/throw
priority, locked-never-walks) are `static` and headless-unit-tested.

Director-ratified configurability folded in as **visual-controller `@export`s, NOT
`RunConfig` fields** (outside the config_menu MANIFEST, so fp + 89-knob count untouched):
`lock_on_pickup` (default true), `play_pickup_on_reject` (default false), `lock_mode`
(CLIP_DRIVEN|FIXED, default CLIP_DRIVEN), `lock_duration_cap_s` (0.4), `fixed_lock_s`
(0.18). Lock-on-ACCEPTED-pickups-only, no anim on a full-bag reject. A `_ready()`
`has_animation` assert (sampling all 4 states across dirs) fails loudly on any
clip-name/dir-spelling drift with N0.

## Files touched
- `Game/entities/player/player_visual.gd` — NEW. The visual state machine + lock + pure helpers + N2 art-swap listener.
- `Game/entities/player/player.gd` — the single functional edit: `@onready _visual` + the `input_dir`-zeroing lock gate in `_physics_process` (null-guarded; inert under art OFF).
- `Game/entities/player/player.tscn` — ADD `PlayerVisual` + `AnimatedSprite2D` (sprite_frames=player_frames.tres, scale 0.45, position y=-18 to seat feet on the r=14 body, z_index=10 above floor, no y_sort, NEAREST filter); RETAIN `Visual`/`Nose` set `visible=false` (art ON default). Collision shape / layers / masks / movement stats UNCHANGED.
- `Game/tests/test_player_visual.gd` + `.tscn` — NEW headless SCENE test for the pure helpers.

## Checks run
- [x] `godot --headless --path Game --import` clean — IMPORT_EXIT=0, no parse errors.
- [x] new helper test passes — `godot --headless --path Game res://tests/test_player_visual.tscn` → `PLAYER_VISUAL OK — quantize_dir (8 sectors + ZERO-hold + 10° hysteresis hold/switch), select_state (walk/idle @8px/s threshold, action priority, locked never walks) verified.` (exit 0). Covers all 8 sectors, ZERO-facing hold, hysteresis hold-at-24°/switch-at-40°, walk/idle @8 px/s threshold, action priority, locked-never-walks.
- [x] `player.tscn` instantiates headless + `_ready` `has_animation` asserts pass — throwaway instantiation check → `INST OK — player.tscn instantiates, _ready asserts pass, 32 clips resolve, art ON default (sprite shown/greybox hidden/unlocked), collision r=14 + layer1/mask26 intact.` (exit 0; temp files removed).
- [x] M0 smoke green — `res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy` (exit 0).
- [x] all-off determinism fp STILL `e943ac9c8bc1` — `res://tests/test_rg1_m15_verify.tscn` → `RG1 M1.5 VERIFY OK … fp=e943ac9c8bc1` (exit 0).
- [x] config count still **89** — `res://tests/test_config_menu.tscn` → `CONFIG MENU OK — CFG verified (89/89 knobs bound + reachable …)` (exit 0).
- [x] existing player movement test green — `res://tests/test_player_movement.gd` → `MOVE OK — 8-direction movement verified (cardinal=91.7px diagonal=91.7px over 0.5s, max_speed=200)` (exit 0).
- [x] resolve_aim test green — `res://tests/test_resolve_aim.gd` → `RESOLVE_AIM OK …` (exit 0).
- [x] definition of done met: "a visual controller that turns the existing Player into a legible 8-directional animated character — idle/walk from velocity/facing, pickup/throw one-shots from the EventBus signals, with a brief gated movement-lock during the action clips, adding no new gameplay state and touching no collision, movement, or RNG." All provable-headless items verified.

## Hard constraints — honored
- **Art-OFF == M1.6 byte-for-byte.** `is_locked()` returns `_art_on and _lock_remaining > 0.0` → ALWAYS false under art OFF, so the `input_dir` gate never triggers and `_physics_process` runs today's exact lines. The greybox `Visual`/`Nose` are shown under art OFF. No parallel "if off" branch — the OFF feel is the *absence* of the lock state. Default = art ON.
- **Collision + movement UNTOUCHED.** `CircleShape2D` r=14, `collision_layer=1`/`mask=26`, and `player_movement.tres` are byte-unchanged (verified in the instantiation check). The sprite is a visual transform (scale/offset/z_index on the `AnimatedSprite2D` only); the lock gates only the `input_dir` *value* fed to the unchanged `step_velocity` math.
- **fp `e943ac9c8bc1` UNMOVED.** N1 touches no RNG, no `RunConfig` field, no generator; nothing it writes reaches `fingerprint()`. Verified by the fp verify scene (above).
- **Signals:** only N0's `debug_player_art_toggled` is connected (plus listening to the existing `junk_picked_up`/`item_thrown`). **N1 declares NO new signal.**
- **Configurable knobs are visual-controller `@export`s, NOT `RunConfig` fields** — outside the config_menu MANIFEST, so the 89-knob count and the fp are untouched (verified).

## Design deviations
**none.** Implemented exactly per the LOCKED `Director Dispositions (ratified)` section: input-zeroing lock, accepted-only pickup with `lock_on_pickup`/`play_pickup_on_reject` exports, clip-driven lock with `lock_duration_cap_s` ceiling + configurable `lock_mode`/`fixed_lock_s`, 8-way `quantize_dir` with ~10° hysteresis + `select_state` as pure static helpers, both greybox nodes hidden under art ON, fixed `z_index` no y_sort, `_ready()` `has_animation` assert. (Minor unspecified-by-spec call: the `AnimatedSprite2D` starting scale=0.45 / y=-18 is N1's visual-tuning choice within N0's recommended 0.45–0.5 + negative-Y range — flagged as an RG1 visual-tune item below, not a deviation.)

## Handoffs / follow-ups
- **RG1 MANUAL-PLAYTEST ITEM (cannot be confirmed headless):** on-screen animation in BOTH the hub and dive scenes — that the 8-way idle/walk reads, pickup/throw clips fire on the right events, the movement-lock feels right (not sluggish in a tense extract — the breakdown's explicit RG-watch item), and the sprite scale (0.45) + Y-offset (-18) seat the character cleanly on the r=14 body. If the lock reads sluggish, flip `lock_mode=FIXED` / lower `fixed_lock_s` in-editor (no code change). If precise-aim read is lost (8-dir quantized vs. continuous Nose), a dedicated thin aim-reticle is a later separate task — NOT the greybox Nose.
- **N2** consumes the seam N1 established: it emits `EventBus.debug_player_art_toggled` from a debug menu to swap `AnimatedSprite2D`↔greybox at runtime (the `_on_art_toggled` handler is ready).
