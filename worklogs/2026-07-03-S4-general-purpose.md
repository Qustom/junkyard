# Worklog — S4 Generated debug-menu sections + per-def coverage assertion + sweep hygiene

- **Date:** 2026-07-03
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.9 (Wave 4 — opposition Phase D; sole `run_config.gd` writer this wave)
- **Branch:** general-purpose/S4
- **Commit:** e95a892 (implementation; this worklog + deviations are a follow-up commit on the same branch)

## What changed
The surface half of "adding content is data, not engineering", per
`design/M1_9_Tasks/S4_generated_config_menu.md` (§8 Resolved Decisions BINDING, as amended
by the Wave-3 close-out: the `param_overrides` stamp is FLAT DOTTED rows). When an
`OppositionDef.tres` is authored, its tuning section now appears in the ConfigMenu
automatically — generated from `param_schema`, guarded by the same fail-loud coverage
discipline as the 89 hand-authored rows — and the sweep-hygiene model (config-marked staged
overrides vs. `debug_dirty` live tweaks) keeps gate telemetry clean.

- **Generated Oppositions tab (9th, before Player; Meta last)** — `OPPOSITION_DEFS_KEY`
  pseudo-section (PLAYER_DEBUG_KEY mounting pattern): staging-note header (Q8-ratified
  additive-enable semantics), one collapsible section per loaded def (fold ▸/▾ + master
  CheckButton staging enablement + display_name + `ENABLED · n overrides`/`OFF` chip +
  optional `CFG_GLOSS_DEF_<ID>` gloss), body rows dispatched from `param_schema`
  (bool → CheckButton; int/float → HSlider+SpinBox with entry min/max/step, default-step
  rule incl. the ≤1-span 0.01 probability rule; enum → OptionButton; unknown type →
  push_error, no row → per-def net fires). Def discovery: `ResourceLoader.list_directory`,
  filename-sorted scan then id-sorted display (§8.3.1), duplicate ids push_error + fail the
  net (§8.3.2), bad files skip-with-push_error, zero defs → placeholder (menu always builds).
- **Widget-core refactor (§3.3)** — `_make_bool_widget` / `_make_enum_widget` /
  `_make_numeric_widget` take a setter `Callable`; legacy `_build_bool/_build_enum/
  _build_numeric` delegate with `_set_field` closures (ranges/steps/behaviour
  byte-equivalent); generated rows pass override-staging closures.
- **Lever promotion + coverage (§3.4, §8.0.1/§8.1 Q3)** — `run_config.gd`:
  `oppositions_enabled`/`param_overrides` flipped `@export_storage` → plain `@export`
  (the exact two-annotation change, same commit as the bindings so `main` never goes red).
  Bound via two DISTINCT invisible sentinel Controls in `_rows` (§8.0.2);
  `_push_value_to_control` routes both fields to `_refresh_def_sections()` (Reset just
  works). `has_full_def_coverage()`: per-def params ↔ schema ↔ generated-rows bijection,
  fail-loud per def, asserted at `_ready` + headlessly.
- **Staging (§3.5)** — master toggle stages the enable-list (duplicate-then-assign, never
  aliases); param edits stage SPARSE overrides (authored-default-equal erases the key +
  empty sub-dict); per-section `Clear overrides`; effective-value display with `*` label
  marks + tooltip; the def Resource is never written; Reset returns both levers empty.
- **Trap detector generalized** — new `Game/systems/oppositions/opposition_lint.gd`
  (static, content-side — RunConfig never imports defs): schema-flagged `trap_if_neutral`
  params at neutral + the neutral-card trap (Wave-3 close-out flag, resolved YES: enabled
  def with effective base_count≤0 ∧ count_per_depth≤0 spawns zero). Consumed by the CFG
  amber warn line (legacy list + raw def tokens) AND a new additive `inert_enabled_defs`
  `run_started` stamp (lazy def load — empty lever loads nothing). Scope = cfg-enabled ids
  only (deck defs are author-owned, §8.1 Q8).
- **Sweep hygiene (§3.6)** — Telemetry: `_debug_dirty` per-run flag (reset on
  `run_started`), `debug_run_dirtied` → self-identifying `debug_dirtied` row + flush,
  `run_ended` row stamps `debug_dirty` (false on clean runs — every run self-describes).
  No schema bump, no envelope change, locked `run_ended` arity untouched.
- **Live edit tier v1 only (§3.7)** — per-def `Respawn live instances (marks run dirty)`
  button, enabled only in-dive with `svc.live_count(def.id) > 0`: despawn + respawn each
  instance AT ITS REGISTERED CELL (`live_instances`/`spawn_cell_of`) with the merged
  `def.params ⊕ staged overrides` bag in `ctx.params`; refusals warn, never fatal; emits
  `debug_run_dirtied(&"respawn_params", …)` exactly ONCE per press. Staging stays pure
  pre-run; the respawn emit is the menu's one deliberate EventBus exception (§8.2 — header
  comment scoped accordingly). Read-through/per-instance tiers NOT built (deferred).
- **Telemetry migration (§3.8)** — subscribed `opposition_event` /
  `opposition_killed_player` → new row types (`telemetry_schema.gd` consts + ALL_TYPES;
  TEL stamps `run_t_ms` itself); legacy subscriptions/rows byte-identical (dual-emit stays
  until post-gate; SG2 counts from the generic family).

## Files touched
- `Game/ui/config/config_menu.gd` — the S4 surface (tab, builders, coverage, staging,
  respawn, refresh, trap-line extension, widget-core refactor, header-comment scope).
- `Game/data/run_config/run_config.gd` — the two-annotation `@export_storage`→`@export`
  flip + comment (sole Wave-4 writer; NOTHING else changed in the file).
- `Game/systems/oppositions/opposition_lint.gd` (+ `.uid`) — **new**: generalized trap detector.
- `Game/systems/telemetry/telemetry.gd` — generic-signal + `debug_run_dirtied`
  subscriptions/handlers; `_debug_dirty` bookkeeping; `run_ended` stamp; `inert_enabled_defs`
  `run_started` stamp.
- `Game/systems/telemetry/telemetry_schema.gd` — `OPPOSITION_EVENT`,
  `OPPOSITION_KILLED_PLAYER`, `DEBUG_DIRTIED` + ALL_TYPES (SCHEMA_VERSION stays 1).
- `Game/ui/config/config_strings.csv` — tab/staging/chip/respawn/clear/override chrome +
  optional glosses for the 4 migrated defs.
- `Game/tests/test_config_menu.gd` — the §3.4 Layer-2 two-part pin (89 frozen legacy +
  exactly-these-2 levers = 91), per-def bijection green, §8.3.3 order pin, distinct-sentinel
  check, count-agnostic section/row assertions, staging round-trip (sparse write + erase),
  Reset still all-off field-by-field over all 91.
- `Game/tests/test_def_menu_coverage.gd/.tscn` (+ `.uid`) — **new** scene test: negative
  bijection (broken fixture def fails the net, restore goes green), duplicate-id fail,
  zero-defs headless build (fixture dir), dotted `param_overrides.<id>.<key>` stamp shape
  (no base key, flat pin), `inert_enabled_defs` (neutral-card + trap_if_neutral),
  generic rows + legacy dual-emit row, `debug_dirtied` + `run_ended.debug_dirty`
  true/false across two runs, tier-v1 respawn (same cells, merged params, ONE dirty emit).
- `Game/tests/fixtures/oppositions_empty/.gdkeep` — the zero-defs fixture folder.
- `Game/tests/test_run_config.gd` — one stale comment updated (`@export_storage` → plain
  `@export` since S4); zero assertion changes.
- `worklogs/2026-07-03-S4-general-purpose.md`, `design/DESIGN_DEVIATIONS.md` — this record.

**Did NOT touch (per the brief):** `event_bus.gd` (S0 pre-declared `debug_run_dirtied` —
S4 only emits/connects), `main_game.gd`, hazard components/scenes, `data/oppositions/*.tres`,
`data/bands/`, `systems/bandgen/`, `encounter_builder.gd`, `spawn_service.gd`, save schema.

## Checks run
All sequential (never two headless instances), in this worktree, after `--import`:
- [x] `godot --headless --path Game --import` clean (no parse/compile errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] **Coverage:** `test_config_menu` → **91/91 bound + reachable** (89 frozen legacy +
  exactly {oppositions_enabled, param_overrides}; per-def bijection green; section order =
  sorted ids; staging round-trip; Reset all-off) ✓
- [x] **New `test_def_menu_coverage`** ✓ (negative net fires with the two expected
  push_errors; duplicate-id fails; 0-defs builds; dotted stamp asserted — NO base
  `param_overrides` key; `inert_enabled_defs` carries `spike:neutral_card` +
  `spike:arm_length`; `debug_dirtied` row; `run_ended.debug_dirty` true then false;
  respawn keeps cells {(3,4),(9,2)}, merges `speed=99.0` into ctx params, dirties ONCE)
- [x] **All-off fp `e943ac9c8bc1` byte-identical:** `test_bandgen_determinism` ✓ (sample
  fp printed e943ac9c8bc1), `test_corridor_lever` ✓, `test_band_pipeline_parity` ✓
- [x] Suite: `test_run_config` ✓, `test_telemetry_config_marking` ✓, `test_telemetry_jsonl` ✓,
  `test_encounter_builder` ✓, `test_spawn_service` ✓, `test_opposition_components` ✓,
  `test_opposition_def_schema` ✓
- [x] Hazards: `test_pingpong_hazard` ✓, `test_bomb_hazard` ✓, `test_spike_hazard` ✓,
  `test_pursuing_hazard` ✓, `test_per_room_density` ✓, `test_hazard_spread` ✓,
  `test_throw_mechanic` ✓
- [x] RG verifies: `test_rg1_loop_verify` ✓, `test_rg1_m12_verify` ✓,
  `test_rg1_m13_verify` ✓ (**passed on the FIRST attempt — no flake retry consumed**),
  `test_rg1_m14_verify` ✓, `test_rg1_m15_verify` ✓
- [x] Regression extras: `test_new_hazard_spawn` ✓ (golden seam unmodified),
  `test_corridor_summary_row` ✓, `test_main_game_loop` ✓, `test_loop_drive` ✓
- [x] Definition of done met: *"coverage assertions pass (legacy count + per-def); menu
  builds headlessly with however many defs are loaded; staged param_overrides stamp
  run_started (dotted rows); a live tweak marks debug_dirty; all-off fp unmoved; worklog +
  commit SHA"* — all above.

## Design deviations
Five entries appended to `design/DESIGN_DEVIATIONS.md` (all recommended **Reviewed**):
1. §8.3.4's 0/4/6+ def test matrix shipped as 0-defs fixture + count-agnostic assertions
   (no 6-def fixture) — the dispatch brief's explicit instruction; 6-def case proven when
   S6a/S6b land.
2. Def trap tokens render raw (`<id>:<key>`) in the warn line, not per-trap CSV keys — an
   unbounded per-def CSV key-space would defeat "content is data".
3. The Wave-3 close-out "consider a neutral-card trap" flag resolved to YES —
   `<id>:neutral_card` in `OppositionLint` (enable-alone spawns zero on S2's neutral cards).
4. Fold toggles use literal ▸/▾ glyphs, not tr() keys (pictographic state symbols).
5. Tier-v1 respawn ctx carries `{params, depth, run_t_ms}` only — the registry records no
   per-piece legacy ctx (initial_dir/room_bounds/phase_salt/room_key); acceptable for a
   debug action on an already-dirty run; note for post-gate live-edit tiers.

## Handoffs / follow-ups
- **S6a/S6b (parallel, Wave 4):** their `charger`/`splitter`/`splitter_child` sections
  auto-appear on merge with zero `config_menu.gd` edits (acceptance: `test_config_menu`
  + `test_def_menu_coverage` are count-agnostic and stay green at 6-7 defs). If a new def
  authors a `step` or `options` schema field, the generated rows honor it already.
- **SG2:** filter the gate cohort on `run_ended.data.debug_dirty`; count deaths from the
  GENERIC family (`opposition_event`/`opposition_killed_player`), never both families;
  `debug_kill` stays a separate orthogonal filter (§8.1 Q9 — carry into the analysis brief);
  segment def sweeps on `param_overrides.<def_id>.<param_key>` dotted keys +
  `oppositions_enabled` + `inert_enabled_defs`.
- **Post-gate (SG3 watch):** legacy per-type telemetry rows retire with the dual-emit;
  the def trap tokens + respawn-ctx limitation (deviation 5) revisit if live-edit tiers 2/3
  (read-through defs / per-instance ctx) get funded; search/pinning UX deferred to M2+ (Q4).
