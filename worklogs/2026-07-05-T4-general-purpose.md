# Worklog — T4 Third hub portal + `band_three` routing

- **Date:** 2026-07-05
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.10 (Wave 4 — reachability)
- **Branch:** general-purpose/T4 (worktree branch `worktree-agent-a47bf5bc48d82f74b`)
- **Commit:** b9e39448dba2c24235fa81816a72685d7cd976a1 (feature); worklog in the follow-up commit

## What changed
Added a third `DeparturePortal` to the hub that routes into `band_three` ("The Warren",
T3's cave band), proving the M1.9 S8 routing seam scales by data, not engineering. The
production-code delta is a single `BAND_ROUTES` row (`&"band_three"` → `band_three`);
everything else is scene data (one `hub.tscn` instance block at (110,-20), cave-teal glow
per D-RAT-5) and test extensions (C7 + C5 drive in `test_band_routing`; H7 + H1/H4 list
entries in `test_hub_contract`). Both existing portals are byte-identical — the hub.tscn
diff is purely additive, `departure_portal.tscn`/`departure_portal.gd` are untouched, and
the H5/H6 + C1–C6 assertions rerun unmodified.

## Files touched
- `Game/scenes/game/main_game.gd` — **+1 code line**: the `&"band_three": &"band_three"`
  `BAND_ROUTES` row (+ inline comment). `_resolve_band_profile`, `_band_route_key`,
  start_run/enter_band tagging, and the fallbacks are all UNTOUCHED.
- `Game/scenes/hub/hub.tscn` — **+9 scene-data lines**: the `DeparturePortalBandThree`
  instance block (position (110,-20); `interactable_id=&"portal_band_three"`;
  `band_id=&"band_three"`; prompt "Dive — The Warren"; `display_name="The Warren Portal"`;
  `glow_tint=Color(0.3,0.9,0.65,1)`; `gate_tint=Color(0.65,0.95,0.82,1)` — a lighter wash of
  the same cave-teal hue, mirroring portal 2's glow/gate relationship). Reuses
  `ExtResource("3")` — no new ext_resource, load_steps header unchanged. Portal 1 & portal 2
  blocks byte-identical.
- `Game/tests/test_band_routing.gd` — **+test**: `BAND_THREE_PATH` const; C7
  (`_check_routing_lands_band_three` — route resolves to band_three, `_band_route_key`
  tagged, pipeline fp distinct from BOTH greybox and band_two for the same seed); a C5
  band-three full-scene drive asserting `run_started` band_id `&"band_three"` +
  `_band_profile.id == band_three`; header + OK-message updates.
- `Game/tests/test_hub_contract.gd` — **+test**: `CAVE_TEAL` const; H1 path-list +
  `DeparturePortalBandThree`; H4 expected-dict + `portal_band_three`; H7
  (`_check_portal_three` — band_id/interactable_id/position (110,-20)/in-yard/prompt names
  The Warren/glow==cave-teal + distinct from WHITE and EMBER_ORANGE/push-down landed);
  OK-message update (now 4 interactables).

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **SMOKE OK**
- [x] `test_run_config.tscn` → **R0 OK** (all-off baseline / 90 knobs intact)
- [x] `test_band_routing.tscn` → **BAND_ROUTING OK** (C1–C7; band_three distinct fp;
      run_started band_id == route key for all three routes)
- [x] `test_hub_contract.tscn` → **HUB_CONTRACT OK** (H1–H7; portal 1 & 2 unchanged;
      portal 3 The Warren / cave-teal / (110,-20) in-yard)
- [x] `test_band_three_profile.tscn` → **BAND_THREE OK** — explicitly asserts
      **band_greybox AND band_two byte-identical** (the control fingerprints unmoved)
- [x] `git diff` on hub.tscn is purely additive (portal 1/2 lines untouched);
      `departure_portal.tscn` + `departure_portal.gd` show **zero-byte diff** (not in diff)
- [x] Definition of done met (see below)

**Definition of done (quoted, spec §5 / breakdown §T4):**
1. *Controls byte-identical* — all-off baseline (R0 OK), band_greybox + band_two fps
   unmoved (BAND_THREE OK asserts both byte-identical; C7 asserts band_three distinct from
   both), departure_portal.tscn zero-byte diff, portal 1/2 hub.tscn lines untouched, H5/H6 +
   C1–C6 green unmodified. ✔
2. *New portal routes* — `&"portal_band_three"` → stages `&"band_three"` → generates from
   `data/bands/band_three.tres` (H7 + C7 + C5 band-three drive green); full-scene headless
   drive lands in the cave band. ✔
3. *Stamp* — `run_started` rows carry `band_id == &"band_three"` (asserted at the signal in
   C5; telemetry mirrors the arg verbatim, `telemetry.gd:167`). ✔
4. *Always present, no save change* — no `schema_version` diff, no persisted key; wipe
   isolation (C6) green. ✔
5. Import + smoke + suite sweep green; this worklog with the ledger + commit SHA. ✔

## Bespoke-code ledger (the task's headline number)

**Bespoke non-data, non-test production code = 1 line** — the single `BAND_ROUTES`
Dictionary row `&"band_three": &"band_three"` (plus an inline comment). Matches the spec's
prediction exactly (§4 "the task's headline number: 1 line").

- **Scene data:** 9 lines (the `hub.tscn` `DeparturePortalBandThree` instance block).
- **Test code:** ~74 lines added in `test_band_routing.gd` + ~49 lines in
  `test_hub_contract.gd` (per `git diff --stat`; includes header/OK-message churn).

**Reused VERBATIM from S8 (zero edits):** the staging seam
(`game_state.gd` `_pending_dive_band` + `consume_pending_dive_band`), the routing
resolution (`main_game._resolve_band_profile` consume-on-read + double-fallback,
`_band_route_key`, start_run/enter_band tagging), the per-instance portal identity exports
+ push-down + id/focus/lockout guards (`departure_portal.gd`/`.tscn` — not opened, not
edited), and the telemetry band_id stamp (`telemetry.gd` — verified generic, not edited).
The route landed the moment `start_run(&"band_three", seed)` ran, exactly as S8 designed.

**Genuinely NEW in T4:** the one `BAND_ROUTES` row, the one scene-instance block, the test
extensions, and the two ratified data values (prompt "Dive — The Warren" per D-RAT-5;
glow `Color(0.30,0.90,0.65)` cave-teal per D-RAT-5). Nothing structural. The scalability
thesis holds: adding a third reachable band cost 1 production-code line + data.

## Design deviations
**none.** Built exactly to the spec's Resolved Decisions (Phase 3) and D-RAT-5/D-RAT-9:
route key = profile id (`band_three`), position (110,-20) forward-staggered second rank,
prompt "Dive — The Warren", glow cave-teal `Color(0.30,0.90,0.65)`, gate a lighter wash of
the same hue. Only the one `BAND_ROUTES` row touches `main_game.gd` (OQ-7 per-wave
single-writer reading confirmed — no overrun, so no scalability finding beyond the
predicted 1 line). No save-schema change; both existing portals byte-identical.

## Handoffs / follow-ups
- **TG1 Director eyeball (OQ-3, from spec):** the plaza-forward composition read
  ("forward = newest" vs the S8 row's "rightmost = deeper") AND the spawn→portal-2 transit
  prompt (Phase-3 correction 3 — the straight walk to The Sump crosses portal 3's rect;
  never simultaneously in range, hysteresis + named prompt mitigate, but a mid-walk F-press
  is a band-3 mis-dive). A position nudge is a one-line hub.tscn override + one H7 constant.
- **TG3 watch-item (OQ-6, confirm not build):** the portal plaza has exactly one safe slot
  left (the west mirror `(-110, -20)`, band 4, shop clears it by ~90.6 px); **band 5 forces
  a band-select surface**. Band 4's mirror slot would visually crowd the shop's SortTable
  sprite (y-sort keeps the portal in front) — re-eyeball at the band-4 task.
- **Art follow-up (OQ-2, deferred):** cave-teal renders as a deep cyan-blue through the
  glow art's violet MULTIPLY (Phase-3 correction 5); a genuinely bright teal read would need
  a PixelLab retone (Director-gated), out of T4 scope. The H7 assert pins the `glow_tint`
  property, so a later retone won't break the contract test.
