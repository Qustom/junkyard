# Worklog — T2b New opposition #6: the Burrower "Sinkmaw" (def + one BurrowCycle component)

- **Date:** 2026-07-05
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.10 (Wave 1)
- **Branch:** worktree-agent-a6048d5bc628ada38
- **Commit:** 4c0dc64bd9fad0b5312a0efb52c082aa19b8c1cf (worklog amended into this commit; a subsequent no-op amend to record this SHA leaves the in-tree text one hop behind — the code + worklog landed together in this single T2b commit)

## What changed
Built the Burrower opposition — the M1.10 "phased vulnerability" Phase-E proof — as
`burrower.tres` + the ONE new `BurrowCycle` component + a thin host shell, reusing
`LethalContact` (`&"external"`), `ThrowInteraction` (`&"die"`), and `TelegraphFSM`
unchanged (the Charger footprint). BurrowCycle runs a BURIED → TELEGRAPH → SURFACED
cycle that cycles the host's `collision_layer` 0↔16 + `&"hazard"` group per-phase (so
a throw passes clean through a buried body and contact is non-lethal), tracks the
player underground by direct-translate (wall-ignoring), gates the reused kill to the
SURFACED window with the first lethal test on the surfacing frame itself, and holds an
in-component `intersect_point` (world mask 2) guard so it never surfaces inside a wall.
Per-instance phase desync derives positionally (the builder stamps no `phase_salt` for
`&"burrower"`), RNG-free. Ships OFF (`min_band=3`, in no default lever/preset/deck).

## Files touched (all new — zero shared-file edits)
- `Game/scenes/hazards/components/burrow_cycle.gd` — the ONE new component (the FSM +
  collision/lethality cycling + wall-ignoring tracker + wall-surface guard + positional
  desync).
- `Game/scenes/hazards/burrower_hazard.gd` — host shell (S2 Actor-host family skeleton:
  component acquire/bind, self-timed clock, `_on_phase` tells + S0-locked telemetry).
- `Game/scenes/hazards/burrower.tscn` — host scene (Decal ring + Body mound Polygon2Ds,
  CircleShape2D r16, layer 16 / mask 2 / `hazard` group).
- `Game/data/oppositions/burrower.tres` — the def (id `&"burrower"`, `min_band=3`,
  cost 2, caps 1+3, 9 params ↔ 9 schema rows, `kill_radius=34`).
- `Game/tests/test_burrower.gd` + `.tscn` — the 11-case DoD verification.
- (`.gd.uid` sidecars generated on import.)

## Checks run
- [x] `godot --headless --path Game --import` — clean (no parse errors on new files;
  the pre-existing missing `.translation` artifact errors are unrelated to T2b).
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **SMOKE OK**.
- [x] `res://tests/test_opposition_def_schema.tscn` → **DEF SCHEMA OK — 8 defs**
  (dir-scan bijection net picks up burrower; count-agnostic).
- [x] `res://tests/test_burrower.tscn` → **T2b OK** (all 11 cases green).
- [x] Definition of done met: "all-off fp unmoved (case 2 pins `e943ac9c8bc1`);
  bijection green (dir-scan net); `test_burrower` green (buried = throw pass-through +
  non-lethal; dodge frame honored — surface-under-player never kills inside the lead;
  wall-clear surfacing gate; cycle timing from params; surfacing-frame `kill_radius=34`
  lethal test; positional desync — two burrowers don't pop in unison); import clean +
  smoke green."

## Deferred CFG_FIELD_* gloss rows (for the orchestrator's config_strings.csv merge)
Per the parallel-wave / single-writer rule I did NOT edit
`Game/ui/config/config_strings.csv` (CT-1: T2a appends to it in the same wave). Append
these 9 append-only rows (prefix `CFG_FIELD_*`, verbatim, `key,en` format):

```
CFG_FIELD_BURROWER_BASE_COUNT,Base burrowers per band (spawn-card count before the depth ramp)
CFG_FIELD_BURROWER_COUNT_PER_DEPTH,Extra burrowers per within-band depth (spawn-card ramp)
CFG_FIELD_BURROWER_BURIED_S,Seconds buried per cycle (the safe-to-cross window — longer = easier turf)
CFG_FIELD_BURROWER_SURFACE_S,Seconds surfaced (the lethal + throw-kill window)
CFG_FIELD_BURROWER_TRACK_SPEED,Underground follow speed (px/s) — below player 200 so it is outwalkable; 0 = stationary area-denier
CFG_FIELD_BURROWER_TELEGRAPH_LEAD_S,Telegraph lead (s) — the dodge window; the body stays buried + non-lethal while the decal pulses
CFG_FIELD_BURROWER_KILL_RADIUS,Surfaced lethal catch distance (px); 0 = a pure area-scare that never catches
CFG_FIELD_BURROWER_LOCK_SURFACE,Lock the surface point at telegraph start (off = the decal keeps tracking you — the unfair/harder variant)
CFG_FIELD_BURROWER_KILLS,Lethal contact kills (off = harmless surfacing for sweeps)
```

## Bespoke-code ledger (the TG3 measurement)
Beyond the def (`.tres`, data) + scene (`.tscn`) + test (not counted), the non-data /
non-test bespoke code is:

| File | Kind | Total lines | Code lines (non-comment, non-blank) | Predicted |
|---|---|---|---|---|
| `burrow_cycle.gd` | the ONE new component | 227 | **114** | ~120–150 |
| `burrower_hazard.gd` | host shell | 188 | **98** | ~110–140 |
| **Total bespoke** | | 415 | **212** | ~230–290 |

At/below the predicted budget and below the Charger's bespoke cost (ChargeLane 114
code lines vs ChargeLane 206 total; the Burrower is simpler — static pop, static-radius
test, no lane geometry, no split). The single genuinely-new mechanic — per-phase
`collision_layer`/group cycling — is ~14 lines (`_enter_buried_body` +
`_enter_surfaced_body`), a one-step extension of `ChargeLane._set_throwable`'s per-phase
group toggle. Zero shared-file code edits (the phase-salt positional derivation and the
wall-surface guard both live inside `burrow_cycle.gd`, per corrections 1 + 3).

## Design deviations
**none.** Built to the Phase-3 Resolved Decisions verbatim: static pop (Q3), exact
locked decal default (Q4), `kill_radius=34` (Q5 physics correction), positional desync
(correction 1), same-frame first surfacing lethal test (correction 2), in-component
`intersect_point` wall-surface guard (correction 3), `CFG_FIELD_*` gloss keys +
deferred CSV (correction 4 / CT-1), no global def-count assert (correction 5), keep the
mid-flight-surfacing-is-a-hit behaviour (correction 6, unmodified), host-owned visuals /
component owns only layer-group-lethality-movement-FSM (correction 7). `min_band=3`,
credit_cost 2, caps 1+3 as specified. No shared seam required — the predicted-zero
shared-edit ledger held.

## Handoffs / follow-ups
- **CT-1 (orchestrator):** merge the 9 `CFG_FIELD_BURROWER_*` gloss rows above into
  `Game/ui/config/config_strings.csv` alongside T2a's `CFG_FIELD_AMBUSHER_*` rows
  (append-only, disjoint — trivial merge). Until then the generated Oppositions menu
  shows the raw gloss keys for the burrower (no functional impact; the schema-test
  `gloss` field is a String and validates).
- **Director-flagged (unchanged from Phase-3, surfaced for the wave close-out):** Q1
  (fiction/name — shipped `display_name = "Sinkmaw"`, id stable), Q2 (band-3
  exclusivity), Q3/Q4/Q5/Q6 fun-fairness recommendations, and CT-2 (T2a-owned) all
  remain Director calls per the spec's "NEEDS DIRECTOR REVIEW" table.
