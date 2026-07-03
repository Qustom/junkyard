# Worklog — EXPL-opposition-v2  Scalable Opposition System v2 (architecture exploration)

- **Date:** 2026-07-02
- **Subagent:** game-director-designer
- **Milestone:** M1 (exploration / pre-M2 architecture)
- **Branch:** game-director-designer/expl-20260702-opposition
- **Commit:** 3c7cb0a7780bc67d98aaa7763345dbd7b4bc3f6d (worklog originally stamped the pre-amend SHA db58808; corrected at integration)

## What changed
Authored a REFINED v2 of the Scalable Opposition System architecture exploration,
superseding the 2026-06-25 v1. The refinement makes three Director-requested moves:
(1) splits v1's fused `OppositionDirector` into a policy-free `SpawnService`
(mechanism) + one-or-more `EncounterBuilder`s (policy) with a named boundary
(`spawn(def, cell, ctx)`); (2) makes the spawn API a client-agnostic service and
enumerates its real clients (Instability band populator, death/timer re-entry,
set-piece injector, debug/test harness, scripted beats) with per-client RNG
discipline; (3) answers debug-menu scaling via an `OppositionDef.param_schema`
that generalizes ConfigMenu's hand-authored-rows + build-time coverage assertion
into a per-def "surface 100% + fail-loud-on-drift" net, plus a three-tier
live-tweak seam (respawn / read-through defs / ctx override) reconciled with the
config-snapshot discipline. Exploration only — no production code, no contract
widening. Grounded in the real as-built seams (cited path:line throughout).

## Files touched
- `design/explorations/exploration-20260702/hazards/0-scalable-opposition-system.md` — the v2 doc (~230 lines)
- `design/explorations/exploration-20260702/README.md` — minimal index (refinement-pass note + supersession table)
- `design/explorations/exploration-20260702/hazards/README.md` — minimal per-set index (parity with v1 structure)
- `worklogs/2026-07-02-EXPL-opposition-v2-game-director-designer.md` — this worklog

## Checks run
- [x] Design-doc-only change — no `.gd`/`.tres`/`.tscn` touched, so no import/smoke/test gate applies.
- [x] Citations verified against the real files read this session: `main_game.gd` (`_spawn_new_hazards` :385-486, descriptors :357-365, spawn_ctx :496-507, ceiling :337), `run_config.gd` (all-off :429, preset :662, trap detector :597, to_flat_dict :455), `config_menu.gd` (MANIFEST :84, coverage :414-455, _build_row :877-905), `hazard_entity.gd` (setup/snapshot :119-128, BUG6 latch :236-240, L5 :319-323), `pingpong_hazard.gd` (setup :63-72), `event_bus.gd` (generic-signal/pre-declare house style, throw_killed_hazard :175), `band_generator.gd` (pure generate :46-64).
- [x] Definition of done: mirrors v1's structure + rigor; two-layer split is the headline; budget/cap placement, param-metadata answer, and Instability-as-input all argued with recommendations; v1 non-negotiables carried intact and explicit; header marks Date 2026-07-02 + supersedes-v1 link.

## Design deviations
none — this is an architecture exploration, not a build. It proposes (does not
enact) a structural correction to the v1 exploration; nothing in the shipped build
changes. All recommendations are framed as Director calls in the Open Questions.

## Handoffs / follow-ups
- Director disposition needed on the flagged calls: `SpawnService` autoload-vs-per-dive
  (rec: per-dive node), Instability-as-input-vs-owner (rec: input), one-builder-vs-registry
  (rec: no framework yet), read-through-vs-respawn live tweak (rec: respawn default).
- The `I` ↔ credit-budget mapping is deferred to the M3 economy-model + fun-gate sweep
  (this role's economy workbook).
- A Python `.tres` linter rule is proposed: assert the `params` ↔ `param_schema` bijection
  and warn on `per_band_cap` > global ceiling — folds into the content-data lint workflow.
</content>
