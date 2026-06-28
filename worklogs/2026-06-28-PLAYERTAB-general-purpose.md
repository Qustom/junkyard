# Worklog — PLAYERTAB debug Player tab + per-action pickup/throw lock timing

- **Date:** 2026-06-28
- **Subagent:** general-purpose
- **Milestone:** M1.7
- **Branch:** general-purpose/player-tab
- **Commit:** bb1976a059c672ca6f23b4416b720a786d38a335

## What changed
Added a new VIEW-ONLY debug menu tab **"Player"** that holds the player-visual debug
controls: (1) the existing "Player art (debug)" toggle MOVED out of the Meta tab into the
Player tab, and (2) five live anim-lock controls — Lock on pickup, Animate pickup on
reject, Lock mode (Clip-driven/Fixed), Pickup lock (s), Throw lock (s). The controls emit
a new debug-tooling EventBus signal that PlayerVisual applies live. PlayerVisual was
restructured to per-action lock timing: the shared `lock_duration_cap_s` + `fixed_lock_s`
were replaced by per-action `pickup_lock_s` (0.25) + `throw_lock_s` (0.30), each serving
as the FIXED duration in FIXED mode AND the clip-length cap in CLIP_DRIVEN mode — so
pickup vs throw are tunable separately. None of this touches RunConfig/RNG/generators.

## Hard-constraint verification
- **Debug controls, NOT RunConfig fields:** `PLAYER_DEBUG_KEY` is not a SECTIONS prefix,
  not added to `_prefix_of`, and produces no `_rows` entry. None of the 6 Player-tab
  controls are built via `_build_row`, none write `_rows` or `_cfg`. Confirmed by the
  config test's leak-check (no Player control in `_rows`).
- **89-knob coverage stays 89, assertion green:** `CONFIG MENU OK — 89/89 knobs bound`.
- **Determinism fingerprint stays `e943ac9c8bc1`:** RG1 M1.5 VERIFY OK confirms the
  all-off control is byte-identical to the locked baseline (these changes touch no
  RNG/RunConfig/generator — only the visual controller + menu).
- **Shipped default behavior byte-for-byte preserved:** default `lock_mode = CLIP_DRIVEN`;
  pickup clip = 5f@20fps = 0.25 s, capped at `pickup_lock_s=0.25` → 0.25 (unchanged);
  throw clip = 7f@24fps ≈ 0.2917 s, capped at `throw_lock_s=0.30` → 0.2917 (unchanged).
  Art still defaults ON (toggle default checked). The art-OFF guard semantics are intact —
  the lock is still only armed when art is ON.

## Files touched
- `Game/ui/config/config_menu.gd` — added `PLAYER_DEBUG_KEY` sentinel const + a `TABS`
  entry (inserted right before Meta); a `_build_section_into` branch; MOVED the art toggle
  out of the Meta `prefix == ""` block (Meta now builds only the export button); new
  `_build_player_debug_section` + `_build_player_lock_spin` + `_emit_player_anim_config`
  helper + instance refs to the 5 widgets.
- `Game/systems/event_bus.gd` — added one M1.7 debug-tooling signal
  `debug_player_anim_config_changed(lock_mode, lock_on_pickup, play_pickup_on_reject, pickup_lock_s, throw_lock_s)`.
- `Game/entities/player/player_visual.gd` — replaced `lock_duration_cap_s`/`fixed_lock_s`
  with per-action `pickup_lock_s` (0.25) + `throw_lock_s` (0.30); rewrote
  `_lock_duration_for` to pick per-action seconds (cap in CLIP_DRIVEN, fixed in FIXED);
  connected the new signal in `_ready` + added `_on_anim_config_changed`; updated the
  class/enum doc comment block.
- `Game/ui/config/config_strings.csv` — added `CFG_TAB_PLAYER`, `CFG_PLAYER_HEADER`,
  `CFG_PLAYER_LOCK_ON_PICKUP`, `CFG_PLAYER_PICKUP_ON_REJECT`, `CFG_PLAYER_LOCK_MODE`,
  `CFG_PLAYER_LOCK_MODE_CLIP`, `CFG_PLAYER_LOCK_MODE_FIXED`, `CFG_PLAYER_PICKUP_LOCK_S`,
  `CFG_PLAYER_THROW_LOCK_S`. Existing `CFG_DEBUG_PLAYER_ART` row kept.
- `Game/tests/test_config_menu.gd` — updated the N2 regression block: art toggle now
  asserted on the Player tab (under `Section_player_debug`), the 5 timing controls present
  with correct defaults (art ON, lock-on-pickup ON, reject OFF, mode=Clip-driven id 0,
  pickup 0.25, throw 0.30), and NONE of the 6 leak into `_rows`. The 89/89 assertion is
  retained and passes.

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors) — EXIT 0
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK (exit 0)
- [x] `res://tests/test_config_menu.tscn` → CONFIG MENU OK — **89/89** knobs bound, coverage assertion green
- [x] `res://tests/test_rg1_m15_verify.tscn` → RG1 M1.5 VERIFY OK, fingerprint **e943ac9c8bc1**
- [x] `res://tests/test_player_visual.tscn` → PLAYER_VISUAL OK (pure helpers unchanged)
- [x] player.tscn instantiates headless — PlayerVisual `_ready` has_animation asserts + the
      new signal connect resolve clean
- [x] definition of done met: a "Player" debug tab exists holding the moved art toggle +
      pickup/throw durations tunable SEPARATELY; debug-only (outside MANIFEST/`_rows`); 89/89
      + fingerprint + shipped CLIP_DRIVEN behavior preserved.

## Manual / deferred (RG items)
Headless cannot drive the menu UI or render: the live Player tab interaction (clicking the
controls) and the lock-timing actually changing the in-game feel are **RG manual playtest
items**. Verified structurally headless (controls render with correct defaults, the signal
wires PlayerVisual, the timing math preserves shipped behavior).

## Design deviations
N1's shared `lock_duration_cap_s` (0.4) + `fixed_lock_s` (0.18) @export knobs were
REPLACED by per-action `pickup_lock_s` (0.25) + `throw_lock_s` (0.30) per the Director's
M1.7 direction (pickup vs throw must be tunable separately, merging cap+fixed into ONE
value per action). The CLIP_DRIVEN default outcome is byte-identical to N1 (pickup → 0.25,
throw → 0.2917). The FIXED-mode default duration CHANGES from a single 0.18 to per-action
0.25/0.30 — FIXED is a non-default debug mode (default is CLIP_DRIVEN), so no shipped
behavior moves. Should be added to `design/DESIGN_DEVIATIONS.md` for Director disposition.

## Handoffs / follow-ups
- Live Player-tab UI + feel verification is an RG manual playtest item (above).
- Director to disposition the N1 knob restructure deviation at the next wave close-out.
