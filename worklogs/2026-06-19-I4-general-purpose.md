# Worklog — I4 Vision/fog rework (real occlusion + legible fog/lost)

- **Date:** 2026-06-19
- **Subagent:** general-purpose (programmer). Greybox look/colours (occlusion floor, fog ghost hue, pulse/word styling) authored inline by the programmer per the environment-artist-handoff constants in the spec — no separate asset agent was needed (all greybox is procedural/ColorRect, no art file).
- **Milestone:** M1.2 (Wave 2)
- **Branch:** gp/I4
- **Commit:** dc4d40d4f33d45bb7db861b9295edfef5357ecdd (build commit; this SHA line was finalized
  in a follow-up worklog-only commit, recorded below).

## What changed
Reworked `entities/dive/vision_fog.gd` from the M1.1 "dim-not-hide" approach (CanvasModulate
multiply + additive PointLight2D) into a true OCCLUDER plus a legible three-state fog and an
on-screen lost cue, per the Director-LOCKED design (`design/M1_2_Tasks/I4_vision_rework.md`,
Resolved Decisions Q1–Q8 + Director Disposition FINAL):

- **2.A Occlusion (Q1/Q2):** replaced CanvasModulate+soft-light with a node-based **radial-dark
  `Sprite2D` in world space**, centred on the player and scaled by the effective radius each
  frame. Its procedural texture is the INVERSE of the old light gradient: transparent hole in
  the centre (the live read, with a crisp `EDGE_HARDNESS` rim), near-opaque dark surround
  (`OCCLUDE_ALPHA = 0.94`, ~6% anti-blindness floor — never pure black). The plate (2048px)
  dwarfs the ~661px visible diagonal so no un-darkened gutter shows at the screen edge near a
  band boundary (Resolved Q2 corner case). `z_index = 100` (`z_as_relative = false`) sorts it
  above world geometry / distant pickups / distant I2 hazard (hidden beyond the bubble), while
  the player — always inside the transparent hole — is never occluded (Q6). Beyond the rim the
  geometry is GONE, not faint.
- **2.B/Q5 three-state fog:** remembered cells render as cool, desaturated, **flat/static**
  ghosts (`FOG_TINT = Color(0.34,0.40,0.52,0.85)`) at `z_index = 101` (above the dark plate so
  explored area stays readable), and are hidden where they fall inside the live bubble so the
  bright hole isn't double-tinted. Three states are separable on a NON-hue axis (absent /
  flat-static / lit-live) for colourblind safety; hue is reinforcing only.
- **2.C/Q3/Q4/Q7 lost cue:** added a SELF-CONTAINED `CanvasLayer` (`layer = 60`, NOT DecisionHUD)
  hosting a screen-edge pulse vignette (four anchored edge strips, centre stays clear) + a
  persistent HUD word `"DISORIENTED"` (inline string, NOT hud_strings.csv). A single listener on
  the pre-declared `EventBus.nav_lost_proxy` owns the "am-I-lost" episode state (Q7): it **pulses
  on every emit**, shows the **persistent word only on the 2nd+ emit** (escalation = confidence,
  Q4), and clears on a linger-timeout (proxy stops re-firing on depth progress) + `run_ended`.
  Adds NO signal, NO game state; `lost_proxy.gd` is untouched.
- R3 vision-mult multiply (RATIFIED Q4) and the `MIN_RADIUS` floor are preserved unchanged.

`vision_fog.tscn` unchanged (bare Node2D running the script; all nodes built in `_build_nodes()`
/ `_build_lost_cue()` as M1.1 did — no scene edit needed). `main_game.gd` NOT touched
(`_spawn_r4_nodes()` already instantiates the scene; the rework is internal to the node).

## Files touched
- `entities/dive/vision_fog.gd` — the entire I4 rework (occlusion + fog + lost cue). Sole file changed.

## Checks run
- [x] `godot --headless --import` clean (no parse/compile errors for `vision_fog.gd`; the only
  errors are the pre-existing `.translation` first-pass warnings, unrelated to I4).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK — M0 architecture spike healthy**.
- [x] `tests/test_bandgen_determinism.tscn` → **BANDGEN OK** (9 seeds, sample fp=e943ac9c8bc1) +
  BUG3 SOCKET SEAL OK + **R4 NAV OK** + **BUG4 BRANCH-RATE-INDEPENDENT SEAL OK** — fingerprint
  unmoved (I4 changed nothing the generator reads).
- [x] `tests/test_level_scale_determinism.tscn` → **LVL OK** (9 seeds, ext sample fp=d7c249c3584b)
  — fingerprint unmoved.
- [x] Definition of done met (quote): "Beyond the radius geometry is hidden (not faintly visible)
  via near-opaque radial-dark sprite; fog three states + lost cue legible; R4-off = full M1.0
  vision (node self-disables, no overlay/cue/fog when r4_enabled false or r4_vision_radius==0);
  determinism/seal intact (fingerprint unmoved); the vision knobs (r4_vision_radius /
  tighten_per_depth / fog_enabled / lost_proxy_threshold + the R3 mult) take effect; nodes are
  run-state (built under the VisionFog node which lives under _band_container, freed per dive)."
  Visual behaviour verified by code review + the headless determinism/smoke gates; the on-screen
  look (hard-rim hole, cool ghost, edge pulse, word) needs the human playtest (headless can't render).

## Design deviations
None of substance. Implementation notes (all within the LOCKED design):
- The dark plate is drawn at `z_index = 100` on the VisionFog Node2D (world space) rather than on
  a separate CanvasLayer — this is exactly the Resolved-Q2 "radial-dark sprite in world space, NOT
  a CanvasLayer-ColorRect cut by a light" mechanism, with plain `z_index` sorting (Q6).
- The lost-cue CanvasLayer IS used, but only for the **screen-edge pulse + HUD word** (Q3), which
  are screen-space UI, not the occluder — consistent with the spec (the Q2 prohibition is on the
  *occluder* being a light-cut CanvasLayer, not on screen-space UI overlays).
- Fog ghosts inside the live bubble are HIDDEN (the optional Q5 polish) to avoid double-tinting the
  bright hole — chosen because with a true transparent hole the live geometry must read clean.

## Handoffs / follow-ups
- Visual sign-off pending the human playtest (occlusion darkness 0.94 feel, fog hue/brightness,
  pulse/word timing) — all are sweepable consts per the configurable-not-balanced standard.
- Radius presets (spec §2.D, V-tight/V-mid/V-open in cells) are CFG values, not code — set them in
  the run-config sweep against I1's as-built room scale when the Director tunes Wave 2.
- I2 coordination: the dark plate sorts above distant geometry/hazard; if the I2 owner needs an
  *active* hazard telegraph to read at full contrast at the bubble rim (Q6), that telegraph should
  sort at `z_index > 100` on the hazard side — flagged for the integration merge, no I4 change needed.
