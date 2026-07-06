# Worklog — U2a New opposition #7: Lobber "The Mortar" (def + one `MortarCycle` component)

- **Date:** 2026-07-06
- **Subagent:** general-purpose (programmer; also covered the character-animator scope — inline greybox body + marker placeholder, no PixelLab)
- **Milestone:** M1.11 (Wave 1)
- **Branch:** worktree-agent-a93b163dfec36a0a5 (isolated worktree branch; orchestrator merges)
- **Commit:** 364ffeadf78c10feea96de65ef0aeda0ddbcd55f

## What changed
Shipped the M1.11 indirect-AoE cost-ledger proof: the Lobber ("The Mortar", `id &"lobber"`), the first opposition whose threat is delivered AWAY from its body on a flight-time telegraph. `lobber.tres` (data) + the ONE new `MortarCycle` component (AIM → IN-FLIGHT → one-frame IMPACT, marker LOCKED at fire time, centre-in-radius blast fed to the reused `LethalContact` `&"external"` seam) + its own Actor-host shell/scene + a 12-case headless test. Built to the `## Resolved Decisions (Phase 3)` binding section of `design/M1_11_Tasks/U2a_lobber.md`: **`per_band_cap 5`** (body's 3 overridden), `credit_cost 2`, `per_room_cap 1`, `min_band 4`, `lead_factor 0` default (D-RAT-3), single shell, no `max_range`, fires without LOS, player-only blast, positional cadence desync **with the `ctx phase_salt` harness-override mirror** (the `burrow_cycle.gd:98-101` idiom, OQ-9 binding amendment). Ships OFF by default — the all-off fingerprint `e943ac9c8bc1` is untouched (re-verified in-test).

## Files touched (ALL NEW — zero shared-file edits)
- `Game/data/oppositions/lobber.tres` — the OppositionDef: card `cost 2 / room 1 / band 5 / min_band 4 / cap_group &"new_hazards"`; 7 `params` keys each with a schema row (bijection; `trap_if_neutral` on `blast_radius`); `display_name` "The Mortar" (OQ-6 recommendation — Director may rename; `id` stays `&"lobber"`).
- `Game/scenes/hazards/components/mortar_cycle.gd` — **the ONE new component** (196 lines incl. doc comments): fire-period FSM + accumulator, fire-time target capture (live player pos + optional velocity lead in px/s × seconds), the frozen world-positioned marker (top_level root; ring sized to exactly `blast_radius` — the honest contract; inner fill grows over the flight), the one-frame marker-vs-player distance test fed to `LethalContact.apply_contact` (`&"external"` — NOT `&"on_command"`, which tests the host's own position), falling-edge re-arm per cycle, positional desync salt + `ctx.get("phase_salt", <positional default>)` override. RNG-free; never moves the host, never toggles collision/group.
- `Game/scenes/hazards/lobber_hazard.gd` — the S2 Actor-host shell (honest per-def cost): component acquisition + fixed tick order, `DEFAULTS` mirroring `lobber.tres` byte-for-byte, `_resolve_params` seam flags (`def_id/emit_family/lethal_mode &"external"/latch_rearm/throw_mode &"die"`), S0-locked telemetry off the phase hook (`&"telegraph"` = shell up, `&"state"` = impact), greybox tells via the reused `TelegraphFSM`.
- `Game/scenes/hazards/lobber.tscn` — CharacterBody2D "Lobber", layer 16 / mask 2 / `hazard` group for its whole life (always throw-killable); greybox turret-silhouette `Body` Polygon2D (squat base + stubby barrel — no shipped hazard shares the silhouette); `MarkerRoot` (top_level) with `Ring` + `Fill` polygons (COLOR_MARKER 0.95/0.35/0.15). Character-animator scope delivered inline as greybox (pixel filter already OFF project-wide; no PixelLab — Director-gated).
- `Game/tests/test_lobber.gd` + `.tscn` — 12 cases (headless SCENE; excluded from the ledger as test code); details in "Checks run".
- Plus the three Godot-generated `.uid` files for the new scripts.

**Files NOT touched (the guardrail):** `lethal_contact.gd`, `throw_interaction.gd`, `telegraph_fsm.gd`, `thrown_item.gd`, `encounter_builder.gd`, `spawn_service.gd`, `event_bus.gd`, `game_state.gd`, `run_config.gd`, `main_game.gd`, any menu file, `ui/config/config_strings.csv`, any sibling task's files.

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **SMOKE OK**
- [x] `res://tests/test_lobber.tscn` → **U2a OK** — all 12 cases: (1) def contract + per-def bijection (count-agnostic — NO global def-count assert; U2b lands 10→11 in the same wave); (2) all-off gate: not in `RunConfig.new().oppositions_enabled` / default play preset / band_greybox / band_two / band_three decks; all-off pipeline fp `e943ac9c8bc1` pinned; **additive-OR lever: `oppositions_enabled=[&"lobber"]` on band_depth 1/2/3 through the REAL builder+service spawns ZERO lobbers** (zero SPAWNS asserted, not zero loads — as-built correction 2); (3) AIM ~`fire_period_s` → IN-FLIGHT ~`arc_time_s` → AIM, exactly one `&"telegraph"` + one `&"state"` per shell, no out-of-vocabulary token; (4) marker locked at the fire-time player pos, world-placed, visible for the full flight, does NOT re-track, stepping > `blast_radius` off the frozen point before IMPACT is a guaranteed dodge (run active, zero `&"hit_player"`), marker hides on impact; (5) kills=true on-marker → `fail_run(&"death")` + `opposition_killed_player`/`new_hazard_killed`/`&"hit_player"` each EXACTLY once (BUG6); kills=false same geometry → contact row only, run survives; (6) a world-layer wall between Lobber and player changes nothing (marker locks through it, blast kills through it — geometry-ignoring identity); (7) ≥2 telegraphs+impacts over a multi-cycle run (the rain continues); (8) a ThrownItem at the body kills it (`throw_killed_hazard &"lobber"`, frees) and NO further telegraphs (the rain stops); (9) params flow `def < DeckEntry < rc.param_overrides` through the REAL `EncounterBuilder` — the ENTITY's effective `fire_period_s` is the deck value (1.7) under a deck-entry override and the rc value (0.7) when rc also names it; (10) same synthetic band-4 band twice → identical spawn cells; **`per_band_cap = 5` binds** (demand 6 → 5 spawned); `min_band = 4` refuses a band-depth-3 profile (zero spawns); (11) two lobbers at different positions fire on different frames (positional salt); same explicit `phase_salt` twice → identical fire frame; (12) `mortar_cycle.gd` + `lobber_hazard.gd` contain no `RNG.` reference.
- [x] `res://tests/test_opposition_def_schema.tscn` → **DEF SCHEMA OK — 10 defs** (dir-scan net extended itself 9→10; bijection, locked entry shape, host contract all green)
- [x] `res://tests/test_burrower.tscn` → **T2b OK** (unregressed)
- [x] `res://tests/test_ambusher.tscn` → **T2a OK** (unregressed)
- [x] `res://tests/test_def_menu_coverage.tscn` → **DEF MENU COVERAGE OK** (the generated Oppositions tab auto-builds the Lobber section from `param_schema` — DoD 3)
- [x] `res://tests/test_config_menu.tscn` → **CONFIG MENU OK** (91/91 legacy knob surface unmoved)
- [x] Definition of done met: "def + ONE new component + host shell + scene + test + CSV gloss rows — and nothing else … all-off fp `e943ac9c8bc1` unmoved … bijection count-agnostic … marker precedes impact by authored arc_time … centre-in-radius kill gated by kills … geometry-ignoring … throw-killable … zero spawns on shallow bands with the def enabled … params flow … deterministic under the seeded harness" — all asserted above. All runs sequential (import-lock discipline).

## Bespoke-code cost ledger (the UG3 scalability evidence)
| Artefact | Kind | Actual | In the "def + one component" budget? |
|---|---|---|---|
| `data/oppositions/lobber.tres` | data | 77 lines (1 resource, 7 params + 7 schema rows) | Yes — the point |
| `scenes/hazards/components/mortar_cycle.gd` | **new component code** | **196 lines** (~110 excluding doc comments/blanks — within the ~90–120 prediction) | **Yes — the ONE new component** |
| `scenes/hazards/lobber_hazard.gd` | host shell code | 175 lines (~95 excluding doc comments/blanks — within the ~120–150 prediction band) | Expected honest per-def cost |
| `scenes/hazards/lobber.tscn` | scene | 31 lines (host + Body + MarkerRoot/Ring+Fill + collision) | Expected |
| `tests/test_lobber.gd` + `.tscn` | test | 824 + 7 lines | Excluded from the ledger (test code) |
| `ui/config/config_strings.csv` gloss rows | data | 7 rows — **orchestrator-applied at the Wave-1 merge** (below) | Yes — data |
| **Edits to shared/reused files** | — | **ZERO** | — |

The §4 risk point (a `legacy_ctx` `&"lobber"` case in `encounter_builder.gd`) was **not needed**, as Phase 3 predicted — the OQ-9 ctx-override amendment cost ~2 lines inside `mortar_cycle.gd` itself. Net: adding this opposition cost one ~110-line component + one host shell + data + a test — matching the Ambusher/Burrower shape on the new indirect-AoE axis.

## CFG_FIELD_LOBBER_* gloss rows for the orchestrator's merge commit (do NOT apply from this worktree)
7 rows for `Game/ui/config/config_strings.csv`, keyed as authored in `lobber.tres` `param_schema` (the `arc_time_s` gloss wording follows Phase-3 as-built correction 4):

| key | gloss text |
|---|---|
| `CFG_FIELD_LOBBER_BASE_COUNT` | Base Mortars per band (builder spawn card). |
| `CFG_FIELD_LOBBER_COUNT_PER_DEPTH` | Extra Mortars per depth index (builder spawn card). |
| `CFG_FIELD_LOBBER_FIRE_PERIOD_S` | Seconds AIMing between shells. Lower = relentless rain; higher = occasional pressure. |
| `CFG_FIELD_LOBBER_ARC_TIME_S` | Shell flight time = the marker-shown dodge window. The fairness line — never lethal inside it. Floor 0.4 is unfair from a stand at most radii. |
| `CFG_FIELD_LOBBER_BLAST_RADIUS` | Marker + kill radius (px); centre-in-radius test, the ring is drawn at exactly this radius. 0 = inert (never kills). |
| `CFG_FIELD_LOBBER_LEAD_FACTOR` | Player-velocity lead in seconds of prediction: landing = player pos + player velocity (px/s) x this. 0 = lands where you stand (fair/readable); >0 leads your movement (the difficulty dial). |
| `CFG_FIELD_LOBBER_KILLS` | Blast lethality toggle. Off = the blast emits contact telemetry but never ends the run. |

## Design deviations
**none.** Built to the Phase-3 Resolved Decisions verbatim: final card `2/1/5/min_band 4` (the body-text `per_band_cap 3` occurrences read 5 per correction 3); `&"external"` lethal seam (never `&"on_command"`); marker locked at fire, no re-track knob; centre-in-radius `<=` at the rim (OQ-3 recommendation, bomb-consistent); single shell (OQ-2); global reach, no `max_range` (OQ-4); fires without LOS (OQ-5); player-only blast (OQ-8); positional desync + ctx `phase_salt` override (OQ-9 amendment); DoD 4(i)'s min_band refusal asserted as zero SPAWNS (as-built correction 2). The Director-queue items (OQ-1 lead, OQ-2 volley, OQ-3 rim semantics, OQ-6 name, OQ-7 exclusivity) ship at the recommended defaults, all revisitable as data/knob changes with no code edit.

## Handoffs / follow-ups
- **Orchestrator @ Wave-1 merge:** apply the 7 `CFG_FIELD_LOBBER_*` CSV rows (table above) in the single integration commit (M1.10 amendment-6 protocol).
- **U3:** re-bases its deck pin on the final card `lobber 2/1/5` (Phase-3 "cross-task amendments" — indicative outcome `lobber 5 / sentry 4 / charger 4 / bomb 8 = 21` at the 34 budget with U2b-as-authored; the bomb-sponge disposition is U3's call).
- **Director queue (at the Wave-1 close-out):** OQ-1 / OQ-2 / OQ-3 / OQ-6 / OQ-7 with the Phase-3 recommendations (already tabulated in `U2a_lobber.md` §NEEDS DIRECTOR REVIEW).
- **PixelLab art pass** for the Mortar body + marker remains Director-gated; the greybox reads distinctly (squat turret silhouette + world-space ground ring) in the meantime.
