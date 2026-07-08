# Worklog — U4 Fourth hub portal + `band_four` routing

- **Date:** 2026-07-08
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.11 (Wave 4)
- **Branch:** general-purpose/U4
- **Commit:** 0a12c25e7195a6577e14df31a491ee3edb0dc75c (the full U4 change: code + scene + tests + this worklog; a follow-up worklog-only commit records this SHA)

## What changed

The fourth `DeparturePortal` on the hub, routing into U3's `band_four` ("The Far Field",
the open-field scatter band) — the N=3 measurement of the S8 routing seam's marginal cost.
Exactly one `BAND_ROUTES` row in `main_game.gd` (`&"band_four"` → `band_four`), one 9-line
`departure_portal.tscn` instance block in `hub.tscn` at the D-RAT-9 mirror slot `(-110, -20)`
with the D-U4-1 ratified identity (prompt "Dive — The Far Field", indigo glow
`Color(0.15, 0.25, 1.0)`, gate wash `Color(0.55, 0.62, 1.0)`), and the two contract-test
extensions (H8 + the plaza-FULL set-equality pin; C8 + a fourth C5 full-scene drive + a C6
band-4 wipe round). `departure_portal.gd`/`.tscn`, `game_state.gd`, `event_bus.gd`, `app.gd`,
`telemetry.gd`: zero edits — the seam carried the new key through untouched code, third
time running.

## COST LEDGER (the task's headline number — UG3 evidence)

| Bucket | Predicted (spec §4) | Actual |
|---|---|---|
| **Bespoke production code** | **1 line** | **1 line** — the `BAND_ROUTES` row `&"band_four": &"band_four",` (+ inline comment on the same line, uncounted per spec §3.1) |
| Scene data | ~9 lines | 9 lines — the `hub.tscn` instance block (verified: `git diff` shows `+9` on `hub.tscn`, purely additive) |
| Test delta | ~100 lines | ~157 diff lines across the two tests (test_band_routing +83, test_hub_contract +84, incl. 9 replaced-context lines) — the overage is the OQ-4 set-equality pin shipping as its own scan helper (~25 lines) rather than a bare count assert, per the binding Phase-3 verdict |
| Data / systems / save schema | 0 | 0 |

**Trend line (the UG3 claim):** S8 built the seam (~500-line design) → T4 = 1 production
line → **U4 = 1 production line**. Flat at N=3, exactly as predicted.

## Files touched

- `Game/scenes/game/main_game.gd` — +1 `BAND_ROUTES` row (the entire production-code change)
- `Game/scenes/hub/hub.tscn` — +1 `DeparturePortalBandFour` instance block (9 lines, additive; portal 1/2/3 lines byte-untouched — `git diff` shows only the added block)
- `Game/tests/test_hub_contract.gd` — H1/H4 data tables gain the portal-4 entries; new H8 (portal-4 spec: position/id/route-key/prompt pins, `BAND4_GLOW = Color(0.15, 0.25, 1.0)` exact pin + pairwise distinctness vs WHITE/EMBER_ORANGE/CAVE_TEAL, push-down sub-asserts) + the plaza-FULL set-equality scan (recursive `Interactable` scan == exactly the 5 expected ids); OK print updated. H1–H7 assertion lines unmodified.
- `Game/tests/test_band_routing.gd` — new C8 (`&"band_four"` resolves + routes; fp distinct from greybox AND band_two AND band_three for the same seed); fourth C5 drive (full assembled scene: dive_requested(&"band_four") → scatter dispatch (U0) + arena materialise (U1) → `run_started` carries `band_id == &"band_four"` asserted at the signal → unchanged auto-return teardown); C6 band-4 wipe round. C1–C7 + the three existing C5 drives unmodified.
- `worklogs/2026-07-08-U4-general-purpose.md` — this worklog

NOT touched (hard constraints held): `departure_portal.tscn` (zero-byte diff, third version
running), `departure_portal.gd`, `systems/**`, `data/**` (`band_four.tres` read-only, U3's),
no save-schema change, no new RunConfig knob, no new signal.

## Checks run

- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **SMOKE OK**
- [x] `res://tests/test_hub_contract.tscn` → **HUB_CONTRACT OK** — paths + 4 walls + 963 ground cells + **5 interactables (plaza-FULL set pinned)**; portals 1/2/3 pins green unmodified (H5/H6/H7); portal 4 routes `&"band_four"` (The Far Field prompt, indigo, (-110,-20) in-yard) — H8 green
- [x] `res://tests/test_band_routing.tscn` → **BAND_ROUTING OK** — C1–C8 green; `run_started band_id == the route key for all four routes`, wipe-isolated (C6 incl. the band-4 round); the fourth C5 drive lands the full scatter dive end-to-end
- [x] JSONL spot-check (spec DoD 3): one-off throwaway drive with telemetry enabled produced the row `{"data":{"band_id":"band_four","build":"m1-20260708-7e2ce93",...},...}` — `telemetry.gd` stamp verified truly key-generic (mirrors the signal arg; no whitelist). Throwaway files deleted, not committed; setting restored.
- [x] **All FOUR control fingerprints byte-identical:** `test_run_config` (all-off baseline OK) + `test_band_pipeline_parity` → **fp `e943ac9c8bc1`** unmoved; `test_band_two_profile` OK; `test_band_three_profile` OK ("keeps band_greybox AND band_two byte-identical"); `test_band_four_profile` OK ("keeps band_greybox AND band_two AND band_three byte-identical")
- [x] Regression sweep, all green unmodified: `test_app_router` (ROUTER OK), `test_scatter_backend` (fp `44a9a9b3756f`, 9 seeds), `test_scatter_materialise`, `test_cave_materialise`, `test_def_menu_coverage`, `test_opposition_def_schema`
- [x] Definition of done met (spec §5): (1) controls byte-identical + `departure_portal.tscn` zero-byte diff + portal 1/2/3 lines untouched + H5/H6/H7 + C1–C7 green unmodified ✔ (2) `&"portal_band_four"` stages `&"band_four"`, dive generates from `data/bands/band_four.tres`, full-scene headless drive lands + auto-returns ✔ (3) stamp asserted at the signal + JSONL row spot-checked ✔ (4) no schema diff, no persisted key, wipe isolation green ✔ (5) hub contract at 5 interactables with the OQ-4 plaza-FULL set-equality pin ✔ (6) import + smoke + sweep green, this worklog + ledger ✔

## Design deviations

**none** — built exactly to the Phase-3-resolved spec: D-U4-1 ratified values verbatim
(name, glow, gate, prompt, display name, slot), OQ-4's strengthened set-equality shape
(not a bare count), the forcing-function comment verbatim, no depth signposting in the
prompt (OQ-2), slot `(-110, -20)` as reserved (OQ-3).

## Handoffs / follow-ups

- **PLAZA-FULL FLAG — carry to UG3 verbatim (spec §2.4):** "§2.4: no sixth safe slot
  exists — any new hub interactable re-opens the plaza geometry; band 5 requires a
  band-select surface." The threshold is now ALSO a test contract (H8's set-equality pin):
  a band-5 portal (or any new hub interactable) starts red and forces the band-select
  design conversation. Both belt and braces shipped per OQ-4.
- **D-U4-2 — UG1 Director eyeball (fun/feel, post-build):** (a) BOTH transit lanes
  (spawn→shop over portal 4 — the loop's most-walked lane — and spawn→portal-2 over
  portal 3); (b) the four-glow plaza read (a third blue-family glow joins violet + teal).
  Escalation if judged mis-dive-prone: pull the band-select surface forward — never a
  slot shuffle. Mitigations shipped: 90.6 px never-two-in-range gaps, focus hysteresis,
  band-named prompt, fat-finger lockout.
