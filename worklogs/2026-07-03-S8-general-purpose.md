# Worklog — S8 Second hub portal + band routing + telemetry band-stamp

- **Date:** 2026-07-03
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.9 (Wave 5)
- **Branch:** general-purpose/S8
- **Commit:** <SHA-TO-FILL>

## What changed

The M1.9 reachability last-mile: a second `DeparturePortal` instance on the hub ("The
Sump" gate, ember-orange per D-RAT-1, at `(220, -150)` — the east mirror of the shop)
that routes the dive into `band_two`, while portal 1 keeps routing to `band_greybox`
byte-identically. Routing reuses `dive_requested(band_id)` (NO new signal — S8 §RD Q1):
the portal emits its exported key, GameState's S0 staging seam stages it, and
`main_game._resolve_band_profile()` now consumes it through the new `BAND_ROUTES` table
(`&"near"` → band_greybox, `&"band_two"` → band_two, unknown/empty → greybox control).
The resolved ROUTE key replaces the hardcoded `BAND_ID` at the `start_run`/`enter_band`
call sites, so telemetry's existing `run_started` `band_id` stamp (`telemetry.gd:149` —
verified, not built) becomes real: `"near"` control rows (vocabulary unchanged since
M1.6), `"band_two"` portal-2 rows. No save-schema change (portal always present; the
staging slot is consume-on-read, never persisted).

## Files touched

- `Game/scenes/hub/departure_portal.gd` — additive root exports (`prompt_text`,
  `display_name`, `glow_tint`, `gate_tint`; defaults == authored values) pushed down to
  the child Interactable + sprites in `_ready`, so a hub.tscn instance override can
  re-brand a portal without editable-children noise. Portal 1's push-down is a no-op.
- `Game/scenes/hub/hub.tscn` — + `DeparturePortalBandTwo` instance at `(220, -150)`
  (same y-sort band as gate/shop, packed dirt, 220 px > the ~36 px detector reach so no
  prompt ambiguity): `interactable_id=&"portal_band_two"`, `band_id=&"band_two"`,
  `prompt_text="Dive — The Sump"`, `glow_tint=Color(1, 0.58, 0.24)` (D-RAT-1
  ember-orange), `gate_tint=Color(1, 0.78, 0.62)`. Portal 1's instance: zero new overrides.
- `Game/scenes/game/main_game.gd` — `BAND_PROFILE_DIR` + `BAND_ROUTES` consts;
  `_band_route_key` run-state member (default `BAND_ID`); `_resolve_band_profile()`
  rewired from S3's default-only stub to the real consume → map → load resolution with
  the missing-profile fail-safe; `start_run(_band_route_key, seed)` /
  `enter_band(_band_route_key)` (was `BAND_ID` — byte-identical for unstaged/control dives).
- `Game/tests/test_band_routing.gd/.tscn` — NEW (spec §5.2): staging consume-on-read,
  unstaged default, unknown-key fail-safe, band_two routing (deterministic fp ≠ greybox
  fp same-seed), full-scene `run_started` stamp for both routes (portal-2-style emission
  → `&"band_two"`; unstaged restart → `&"near"`), wipe isolation.
- `Game/tests/test_hub_contract.gd/.tscn` — NEW (spec §5.3): the H1/H2/H4 throwaway hub
  checks promoted to a standing scene test (paths, 4 wall shapes, 963 iso ground cells,
  3 interactable ids) + the portal-2 additions and the portal-1 rendering-unchanged
  assertions (WHITE modulate, "Dive" prompt, `(0, -150)`).

## Checks run

- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `departure_portal.tscn` **zero-byte diff** (`git diff main` empty for it)
- [x] Control byte-identical: `test_run_config` OK · `test_bandgen_determinism` OK
  (fp `e943ac9c8bc1`) · `test_corridor_lever` OK (baseline fp byte-match) ·
  `test_band_pipeline_parity` OK (fp `e943ac9c8bc1`) · `test_app_router` OK **unmodified**
- [x] New: `test_band_routing` OK · `test_hub_contract` OK (both as scenes)
- [x] Band suite: `test_band_two_profile` OK · `test_band_flavors` OK · `test_band_depth` OK
- [x] Integration: `test_encounter_builder` OK · `test_main_game_loop` OK ·
  `test_rg1_loop_verify` OK · `test_rg1_m13_verify` OK (no flake retry needed)
- [x] JSONL spot-check (throwaway driver, deleted before commit): telemetry-on drive of
  one portal-2 dive + one unstaged dive wrote `run_started` rows with
  `band_id` = `["band_two", "near"]` — the stamp mirrors the route key verbatim.
- [x] No save-schema change: no `save_manager.gd`/persistence diff, no `schema_version`
  bump; wipe-isolation test green (staging slot is meta-invisible).
- [x] Definition of done met: "existing portal path byte-identical (fp +
  `test_hub_contract`); `test_band_routing` green (new portal lands in band_two with its
  fp); smoke green; no save change; worklog + commit." — all above.

## Design deviations

1. **Route-key handoff shape: `_band_route_key` member instead of §4.1's
   Dictionary-returning `_resolve_band()`.** The spec's §RD integration note ratified
   folding the routing logic "inside/alongside `_resolve_band_profile()`" (S3's
   single-function seam, kept signature — the golden harness and `_spawn_new_hazards`
   fallback call it). Returning `{key, profile}` would have changed that signature, so
   the resolved key is instead kept on a run-state member (`_band_route_key`, default
   `BAND_ID`) set by the same single resolution call — same consume-once semantics,
   zero churn for the existing callers. Recommendation: **Reviewed** (implementation
   detail inside the ratified seam; behaviour matches §4.1's pseudocode exactly).

Also folded in (ratified, not deviations): D-RAT-1's pick replaces the spec's
placeholder text — `prompt_text` ships `"Dive — The Sump"` (not `"Dive — Band 2"`) and
`display_name` `"The Sump Portal"` (not `"Band Two Portal"`), exactly the "fold the
ratified band name in at S8 integration" step §RD Q3 prescribed.

## Handoffs / follow-ups

- `test_band_two_profile`'s parallel-merge note says the band-2 predators
  (charger/splitter) are "appended + integration-checked at S8/SG1 (deck.size 4 → 6)" —
  `band_two.tres` and `data/oppositions/` are **S9's surfaces this wave** (per the
  Wave-5 single-writer split), so the deck append + the full-populate spawn check
  remain with S9/SG1, not S8.
- OQ-5 residual (spec §RD Q5): if HG3 ever reverts the hub to top-down, one visual
  spot-check that `(220, -150)` reads well on the H2 paint (worst case a position nudge).
