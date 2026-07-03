# Worklog — S6b New hazard #2: the Splitter (the mid-run `svc.spawn` client proof)

- **Date:** 2026-07-03
- **Subagent:** general-purpose (programmer) — **also delivering the character-animator half as
  code-drawn greybox placeholders** per D-RAT-4 (NO PixelLab in M1.9; the §6 asset spec is built
  inline: blob-silhouette continuity parent→child, split-burst flash at the death point, parent
  "unstable shiver" jitter — all presentation-only, filter OFF).
- **Milestone:** M1.9 (Wave 4, parallel worktree)
- **Branch:** `general-purpose/S6b`
- **Commit:** `5ac1fa7dbac309cffc99a5935140888fd8af0bc9` (implementation)
  + the docs commit named below (worklog + deviations).

## What changed
The Splitter ships as the Phase-E ideal: **two `OppositionDef.tres` + a thin component host + the
`_do_split` death hook + one test** — the first mid-run, multi-client proof of `svc.spawn`
(v2 client (b)). A slow ChaseMove pursuer that, on a **throw-death only**, spawns
`child_count = 2` `splitter_child` shards through the same SpawnService boundary the builder uses
(same registry caps, same central `&"spawned"` emit), at **deterministic ring cells** (pure
function of split index — NO RNG anywhere near placement). Children are terminal
(`generations 1 → 0`), faster (`×1.6`), pure cost, `*_kills`-gated, capped by
`per_band_cap = 8` + the `&"new_hazards"` 48 ceiling — refusal is silent-correct
(`&"split_refused"` telemetry row per dropped shard). D-RAT-2 ratified defaults authored
throughout; band-2-exclusive (`min_band = 2`), OFF by default, deck reference id `&"splitter"`
for S7.

## Files touched (all new — file-disjoint from S4/S6a/S7)
- `Game/data/oppositions/splitter.tres` — parent def (spec §2.1 + `cap_group = &"new_hazards"`
  per A4 + the S3 spawn-card keys `base_count`/`count_per_depth`).
- `Game/data/oppositions/splitter_child.tres` — child def (§2.2; `credit_cost 0`, terminal
  `generations 0`, never deck-listed).
- `Game/scenes/hazards/splitter.gd` — `SplitterHazard` host: ChaseMove (slow pursuit) +
  LethalContact (`&"radius"`, BUG6 latch, L5 gate) + ThrowInteraction (`death_handler` →
  split-then-free via `svc.despawn`, return **true**). Consumes S2's seam — `thrown_item.gd`
  untouched. Emits only pre-declared generics (`&"split"` / `&"split_refused"` on
  `opposition_event`); never touches `event_bus.gd`/`game_state.gd`/the layout RNG; resolves the
  service by the `&"spawn_service"` group; uses public `svc.world_to_cell`/`cell_to_world`.
- `Game/scenes/hazards/splitter.tscn` / `splitter_child.tscn` — per-def host scenes (shared
  script; the child scene sets `def_id` + half-scale/brighter greybox — see deviation 1).
- `Game/tests/test_splitter.gd` + `.tscn` — the S6b acceptance test (run as a SCENE).
- `Game/scenes/hazards/splitter.gd.uid`, `Game/tests/test_splitter.gd.uid` — import-generated.
- `design/DESIGN_DEVIATIONS.md` — 6 entries appended (below).
- `worklogs/2026-07-03-S6b-general-purpose.md` — this worklog.

## Checks run (all green, sequential — one godot instance at a time)
- [x] `godot --headless --path Game --import` — clean, no parse errors.
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **SMOKE OK**.
- [x] **`test_splitter`** → S6b OK: defs + cross-def reference + host contract · split on
  throw-death only (2 children at the deterministic ring cells, parent handled + deregistered,
  exactly one `&"split"`, two central `&"spawned"` child rows) · terminal children don't re-split ·
  a plain (non-throw) removal spawns nothing · **cap refusal proven** — per-def `per_band_cap 8`
  (2 `&"split_refused"` rows, ceiling never breached) AND the `&"new_hazards"` group ceiling on a
  live client, **with freed-parent headroom re-open** (the Wave-1 live-registry canon) · **all-off
  fp `e943ac9c8bc1` byte-identical across a forced mid-run split** with the global RNG stream
  provably untouched · L5 kills gate (true → `run_ended &"death"` +
  `opposition_killed_player(&"splitter_child")`; false → `&"hit_player"` only, run survives) ·
  `child_despawn_s` mercy knob (default 0 = off, ratified) · generic vocabulary only.
- [x] `test_opposition_def_schema` → **6 defs** green — params↔schema bijection + locked entry
  shape + host contract for BOTH new defs.
- [x] `test_spawn_service` → S0 OK (untouched, still green).
- [x] `test_opposition_components` → **all 5 golden traces byte-identical** (no existing entity
  touched).
- [x] `test_encounter_builder` → S3 OK (incl. all-off fp pin).
- [x] Hazard suite: `test_new_hazard_spawn`, `test_bomb_hazard`, `test_spike_hazard`,
  `test_pingpong_hazard`, `test_pursuing_hazard`, `test_hazard_spread`, `test_throw_mechanic` —
  all OK.
- [x] Definition of done met: *"All-off fp `e943ac9c8bc1` unmoved; both defs pass the bijection
  check; children respect `per_band_cap`/global ceiling (test proves refusal); generation fp
  unaffected by mid-run splits; `test_splitter` green; full hazard suite + `test_spawn_service` +
  `test_opposition_components` green (golden traces byte-identical); import + smoke green."* —
  every clause proven above.

## Design deviations (all appended to `design/DESIGN_DEVIATIONS.md` with recommendations)
1. **Two host scenes, not one shared scene** — the def-schema bare-instance
   `get_def_id() == def.id` contract forces per-def scene identity; one script, 3-line variant.
   (Rec: Reviewed.)
2. **Spawn-card keys `base_count`/`count_per_depth` added to both defs** — required by S3's deck
   lane (amendment 10) for the parent to spawn from band_two's deck at all. (Rec: Reviewed.)
3. **No `trap_if_neutral` flag** — every zero magnitude is a designed control per the spec's own
   gloss table; the committed test enforces flags only for the legacy four. (Rec: Reviewed.)
4. **`ctx["kills"]` per-instance override tier** on the def-field L5 gate (new defs have no legacy
   `*_kills` knob; the override is how acceptance 5's kills=false case is proven). (Rec: Reviewed.)
5. **No nearest-free-floor-cell snapping for child cells** (Q9 ideal) — the service exposes no
   mid-run floor-cell query; ring cell refused → shard dropped, walled shard possible
   (greybox-acceptable). (Rec: Reviewed + noted SG2-conditional follow-up.)
6. **`CFG_GLOSS_SPLITTER_*` CSV rows not added** — `config_strings.csv` is S4's parallel Wave-4
   surface. (Rec: Reviewed + integration handoff below.)

## Handoffs / follow-ups
- **S7:** deck reference id is exactly `&"splitter"` (the child is NEVER deck-listed). With
  `base_count 1` the deck lane draws ~1 parent per eligible piece at `credit_cost 3` — tune via
  the deck's `param_overrides` if band_two wants fewer.
- **S4/S8 integration:** add the 10 `CFG_GLOSS_SPLITTER_*` strings to
  `Game/ui/config/config_strings.csv` (deviation 6); the generated menu should pick up both defs'
  sections automatically from the schema.
- **SG2 telemetry:** cap-pressure = `&"split_refused"` / (`&"split"` × child_count); restraint
  learning = throw-kills-of-splitter trending down. Both ride the generic channel S4 subscribes.
