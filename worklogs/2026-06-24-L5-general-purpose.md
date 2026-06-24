# Worklog — L5 K5 per-hazard `*_kills` toggles

- **Date:** 2026-06-24
- **Subagent:** general-purpose (the programmer)
- **Milestone:** M1.5 (Wave 2)
- **Branch:** general-purpose/L5
- **Commit:** aa3634cbd72e49b6b41e54e2e388c9942079207e (the code+test+worklog L5 commit; a trailing one-line commit corrects this recorded SHA)

## What changed

Wired the L0-declared `hpp_kills` / `hbomb_kills` / `hspike_kills` knobs (default `true`) into
the three K5 hazard entities so their lethal call is now gated `if _cfg.<prefix>_kills:`,
mirroring R1's `r1_catch_kills` in `hazard_entity.gd`. Each hazard still emits
`new_hazard_killed` **before** the gated `fail_run(&"death")` (emit-always, RD-1) — only the
kill is conditional. Retired the M1.4 verify hack `_driven_default_preset()`: the driven
end-cause matrix now runs the **real** `_default_preset()` (K5 hazards `_enabled = true`,
spawning normally) with the three `*_kills` set `false`, and the shape-check now asserts the
**shipped** preset's three `*_kills` are `true`. Added one kills-off regression case per K5
family proving the toggle (run stays active, emit still fires).

## Files touched
- `scenes/hazards/pingpong_hazard.gd` — guard `_on_contact()` `fail_run` with `if _cfg.hpp_kills:` (emit kept above)
- `scenes/hazards/bomb_hazard.gd` — guard `_detonate()` `if hit:` `fail_run` with `if _cfg.hbomb_kills:` (emit kept above)
- `scenes/hazards/spike_hazard.gd` — guard `_physics_process` `fail_run` with `if _cfg.hspike_kills:` (emit kept above)
- `tests/test_rg1_m14_verify.gd` — delete `_driven_default_preset()` + doc-comment; `_default_preset()` sets the three K5 `*_kills=false`; call site uses `_default_preset()`; `_verify_default_preset_shape()` asserts real preset's three `*_kills==true`
- `tests/test_pingpong_hazard.gd` — added case (g): `hpp_kills=false` → run stays active, emit still fires once
- `tests/test_bomb_hazard.gd` — added case (1b): `hbomb_kills=false` → run stays active, emit still fires
- `tests/test_spike_hazard.gd` — added case (g): `hspike_kills=false` → run stays active, emit still fires once

## Exact guard lines (as-built)
- ping-pong `pingpong_hazard.gd` `_on_contact()`: `if _cfg.hpp_kills:` wraps `GameState.fail_run(&"death")`, emit `new_hazard_killed.emit(&"pingpong", ...)` above it unchanged.
- bomb `bomb_hazard.gd` `_detonate()` (inside `if hit:`): `if _cfg.hbomb_kills:` wraps `GameState.fail_run(&"death")`, emit `new_hazard_killed.emit(&"bomb", ...)` above it unchanged.
- spike `spike_hazard.gd` `_physics_process` (inside `if not _killed_emitted:`): `if _cfg.hspike_kills:` wraps `GameState.fail_run(&"death")`, emit `new_hazard_killed.emit(&"spike", ...)` above it unchanged.

## Checks run
- [x] `godot --headless --import` clean (no parse errors) — IMPORT_EXIT=0
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK (exit 0)
- [x] `test_pingpong_hazard.tscn` → K5a OK
- [x] `test_spike_hazard.tscn` → K5c OK
- [x] `test_bomb_hazard.tscn` → BOMB HAZARD OK
- [x] `test_rg1_m14_verify.tscn` → RG1 M1.4 VERIFY OK with the **real** preset + kills-off driver; all-off control fp = `e943ac9c8bc1`; 81-knob snapshot intact (the harmless headless teardown "resources still in use / RID leaked at exit" lines are pre-existing noise, not failures)
- [x] `test_corridor_lever.tscn` → J4 OK; neutral all-off fp byte-matches `e943ac9c8bc1`
- [x] definition of done met: "Add `hpp_kills`/`hbomb_kills`/`hspike_kills` toggles (default true = today's lethal behaviour) to the three K5 hazard entities, mirroring R1's `r1_catch_kills`, so a non-lethal preset is expressible — then retire `_driven_default_preset()` (the verify driver runs the real preset with the K5 kills off)."

## Design deviations
None. Implemented exactly per the locked contract (L5 Resolved Decisions RD-1…RD-5,
M1.5_Breakdown Phase-3/4 lock): emit-always with only `fail_run` gated (RD-1); non-lethal
hazards keep full motion/tell (RD-2); one-shot latches left as-is (RD-3, noted below as a
deferred follow-up); preset relies on the `true` default + shape-check assertion (RD-4); the
driver retirement is mechanical (RD-5).

## Handoffs / follow-ups
- **RD-3 deferred follow-up:** a non-lethal spike's `_killed_emitted` latches permanently, so a
  `hspike_kills=false` spike emits its telemetry once per entity (never re-fires on a second
  touch). Out of L5 scope — only relevant if a future sweep ships a non-lethal K5 preset for
  telemetry; would need a falling-edge re-arm like ping-pong's. Note, do not build now.
- **OQ-7 / RG1 coordination:** L5 applied the `_driven_default_preset()` retirement directly to
  `test_rg1_m14_verify.gd` (kept runnable as a regression). When RG1 spins `test_rg1_m15_verify.gd`
  from this file as template, it carries the already-cleaned form forward — no further retirement
  needed there.
- **RG2 telemetry note:** on a `*_kills=false` cohort, a `new_hazard_killed` row means a
  "would-have-killed contact," not a death — segment deaths by run-end cause, not by this row.
