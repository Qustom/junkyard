# TASKS — THE FAR YARD

The orchestrator's task queue (mirror of GitHub Projects). The orchestrator consumes the
top *unblocked* task, dispatches the assigned subagent(s), and moves it through `STATUS.md`.
Each task carries: **id · milestone · assignee subagent · spec · definition of done · blockedBy**.
Finished tasks move to `TASKS_COMPLETED.md` (this file holds only **active + backlog**).

Format:
```
### <ID> — <title>
- Milestone: M<n>   Assignee: <subagent(s)>   BlockedBy: <ids|none>
- Spec: <path to the design doc>
- Goal: <one sentence>
- Done when: <verifiable acceptance criteria>
```

> A single task may span a programmer + an asset role (see `CLAUDE.md` → Dispatch). The
> primary assignee is listed first; a `(+ role: scope)` note marks the secondary agent.

---

## M1.2 — Legibility & Level Scale — ✓ **DONE 2026-06-19** (re-gated → ITERATE → M1.3)

All built + re-gated: Waves 1/2 + BUG5 + RG1 → Director playtest → RG2 → **RG3 verdict ITERATE**. Findings + Director
decisions: `design/M1_2_Tasks/G4_findings_M1.2.md`. All tasks archived → `TASKS_COMPLETED.md`.

---

## M1.3 — Legibility & Density — ✓ **DONE 2026-06-21** (re-gated → ITERATE → M1.4)

All built + re-gated: Waves 1/2 (J1·J2·J3·J4·J5·BUG6·DLV1·DLV2) + RG1 → Director playtest → **RG3 verdict ITERATE**.
Findings + the Director feedback work-order: `design/M1_3_Tasks/G4_findings_M1.3.md`. Tasks archived → `TASKS_COMPLETED.md`.

---

## M1.4 — Stakes, Variety & Legibility — ✓ **DONE 2026-06-21..24** (re-gated → ITERATE → M1.5)

All waves built + re-gated: Waves 1–3 (K0–K7, K5a/b/c/i) + RG1 + Wave-5 bug-wave (BUG7/BUG8/TUNE2/FB5) → Director
playtest → **RG3 verdict ITERATE → M1.5** (`design/M1_4_Tasks/G4_findings_M1.4.md` §RG3). Tasks archived →
`TASKS_COMPLETED.md`.

---

## M1.5 — Agency & Legibility — ✓ **DONE 2026-06-24..26** (re-gated → ITERATE → M1.6)

All waves built + re-gated: Waves 1–3 (L0–L5 + RG1) + Wave 4 (L6 control rework) + post-RG3 tuning → Director re-test →
**RG3 verdict ITERATE → M1.6** (`design/M1_5_Tasks/G4_findings_M1.5.md` §"RG3 re-test verdict"). Tasks archived →
`TASKS_COMPLETED.md`.

---

## M1.6 — Surface & Staging — ✓ BUILD DONE; RG1 published; RG2/RG3 Director-pending

Build (M0·M1·M2·M4·M3) + RG1 (itch published `m1-20260627-41106de` + FB1–FB4) all on `main`, archived →
`TASKS_COMPLETED.md`. **Open (Director-gated, non-blocking M1.7):** **RG2** (telemetry/flow analysis) + **RG3** verdict
(go/iterate/pivot) in `design/M1_6_Tasks/G4_findings_M1.6.md` — these await the Director's re-test. M1.7 below is
**Director-directed content** opened ahead of that formal verdict.

---

## M1.9 — Scalable Opposition + Band Systems (ACTIVE — Director-directed; design LOCKED 2026-07-02)

Implement the two explored scalable architectures — the **SpawnService/EncounterBuilder** split
(opposition v2) and the **BandProfile/BandPipeline** (bands) — then prove them with **2 new hazards
(Charger "The Wrecker" + Splitter) and 1 new band ("The Sump", `band_two`)** behind a second hub portal.
Breakdown + cross-task amendments + Director ratifications: `design/M1_9_Tasks/M1.9_Breakdown.md`.
Every task doc carries a BINDING `Resolved Decisions (Phase 3)` section. **Contracts:** all-off fp
`e943ac9c8bc1` byte-identical at every wave boundary; bandgen determinism byte-matches through the
pipeline; knob model 89 (frozen legacy) → 91 at S4; no save-schema change; legacy R1/K5 knobs + signals
stay (dual-emit) through the gate; single-writer-per-file per wave (`main_game.gd`: S0 → S3 only;
`run_config.gd` Wave-4 writer = S4); parallel agents in worktrees; no PixelLab (D-RAT-4).

### Wave 1 — Foundations  *(S0 ∥ S1, parallel worktrees)*

### S0 — SpawnService + OppositionDef data layer + EventBus pre-declare
- Milestone: M1.9 (Wave 1)   Assignee: general-purpose   BlockedBy: none
- Spec: `design/M1_9_Tasks/S0_spawn_service.md` (body + §Resolved Decisions)
- Goal: extract the mechanism half of `_spawn_new_hazards` into a policy-free per-dive `SpawnService`; author the 4 shipped hazards as `OppositionDef.tres` (`Game/data/oppositions/`); pre-declare `opposition_event` / `opposition_killed_player` (silent until S2) / `debug_run_dirtied` + the `dive_requested` doc-amendment + inert GameState staging seam. Sole writer of `main_game.gd`, `event_bus.gd`, `game_state.gd` this wave.
- Done when: all-off fp `e943ac9c8bc1` byte-identical; every `test_rg1_m1*` + `test_new_hazard_spawn` green UNMODIFIED (forwarding consts + ctx forwarder); preset cohort unchanged; new `test_spawn_service` green (caps/registry/valid_cells/clear_all/staging round-trip); import + smoke green; worklog + commit.

### S1 — BandProfile + BandPipeline + `band_greybox.tres`
- Milestone: M1.9 (Wave 1)   Assignee: general-purpose   BlockedBy: none
- Spec: `design/M1_9_Tasks/S1_band_profile_pipeline.md` (body + §10 Resolved Decisions)
- Goal: `BandProfile` resource (incl. `palette_tint`) + `BandPipeline.generate(profile, seed, rc)` delegating to today's `BandGenerator` (seal stays at materialisation; marked `# STAGE HOOK (S5)` slot) + `data/bands/band_greybox.tres`. Touches ONLY `systems/bandgen/` + `data/bands/` + new tests.
- Done when: `test_band_pipeline_parity` byte-matches fingerprints vs the direct path across the 9-seed matrix (+ grading/rc-pass-through/purity guards); existing bandgen suite green; all-off fp unmoved; worklog + commit.

### Wave 2 — Internals  *(S2 ∥ S5, parallel worktrees)*

### S2 — Opposition component extraction + `param_schema`
- Milestone: M1.9 (Wave 2)   Assignee: general-purpose   BlockedBy: S0
- Spec: `design/M1_9_Tasks/S2_components_param_schema.md` (body + §Resolved Decisions)
- Goal: refactor the 4 shipped entities onto the 9-component set (host-ticked child Nodes, resolved primitives; guards/timers transplant line-for-line into hosts); complete per-def `params`+`param_schema` (incl. `trap_if_neutral`); land the `thrown_item.gd` seam `resolve_throw_death(killer_ctx) -> bool` + the `LethalContact` external-contact seam; dual-emit generic signals from components.
- Done when: all-off fp byte-identical; full hazard suite green; golden frame-trace parity harness green (goldens captured pre-refactor); params↔schema bijection check green; worklog + commit.

### S5 — Band flavor stages: SetPieceInject + WearDecay + connectivity guarantee
- Milestone: M1.9 (Wave 2)   Assignee: general-purpose   BlockedBy: S1
- Spec: `design/M1_9_Tasks/S5_flavor_stages_connectivity.md` (body + §10 Resolved Decisions)
- Goal: the two flavor stages (attach-at-socket set-pieces via `SetPieceEntry` pools; breach-led WearDecay) + the ASSERT/CARVE connectivity stage, in S1's stage hook, per-stage sub-seeds, off by default.
- Done when: empty-flavors control fingerprint unmoved; per-stage double-run determinism green; strand-proof test green at max decay across the seed matrix; `floor_fingerprint()` guardrails in place; worklog + commit.

### Wave 3 — Integration  *(S3 alone — sole `main_game.gd` writer)*

### S3 — EncounterBuilder + RunConfig levers + both call-site integrations
- Milestone: M1.9 (Wave 3)   Assignee: general-purpose   BlockedBy: S0, S1, S2
- Spec: `design/M1_9_Tasks/S3_encounter_builder_integration.md` (body + §7 Resolved Decisions)
- Goal: policy out of `main_game` into `EncounterBuilder.populate(band, deck, I, svc)` (legacy lane = byte-exact parity; deck lane = credit budget, `instability(d)=1.0+0.15*(d-1)`); levers `oppositions_enabled`/`param_overrides` as `@export_storage`; `main_game` → `BandPipeline.generate` + `_resolve_band_profile()` (default `band_greybox`) + `piece_pool_ext` field.
- Done when: all-off fp byte-identical THROUGH the new call sites; byte-exact preset parity (plan-capture vs FakeSpawnService); bandgen determinism green through the pipeline; `test_encounter_builder` (8 cases) green; suite green unmodified; worklog + commit.

### Wave 4 — Surface + content proof  *(S4 ∥ S6a ∥ S6b ∥ S7, parallel worktrees)*

### S4 — Generated debug-menu sections + coverage 91 + sweep hygiene
- Milestone: M1.9 (Wave 4)   Assignee: general-purpose   BlockedBy: S2, S3
- Spec: `design/M1_9_Tasks/S4_generated_config_menu.md` (body + §8 Resolved Decisions)
- Goal: 9th "Oppositions" tab generated from `param_schema` (all authored defs, sorted ids); promote the two levers to `@export` + bound rows (count model 89 frozen legacy + 2 = **91**); per-def bijection assertion; sparse `param_overrides` staging stamped on `run_started`; explicit respawn-with-new-params button emitting `debug_run_dirtied`; Telemetry subscribes to the generic signals. Sole Wave-4 writer of `run_config.gd`.
- Done when: two-part coverage pin green (89 legacy + named levers = 91); per-def bijection green; headless menu matrix (0/4/6 defs) green as scenes; `debug_dirty` lands on run rows; all-off fp unmoved; worklog + commit.

### S6a — New hazard #1: Charger ("The Wrecker")
- Milestone: M1.9 (Wave 4)   Assignee: general-purpose (+ character-animator: placeholder sprite/tell)   BlockedBy: S2, S3
- Spec: `design/M1_9_Tasks/S6a_charger_hazard.md` (body + §Resolved Decisions; D-RAT-2)
- Goal: `charger.tres` (min_band=2) + the ONE new `ChargeLane` component (host-ticked; DORMANT→TELEGRAPH→CHARGE→RECOVER; swept-segment lethal via the LethalContact external seam; `lock_at_telegraph_start=true`; wall-crash stun knob; group-toggle dash-invuln — deck override per D-RAT-2); `ProximityTrigger` wake; greybox directional-wedge tell.
- Done when: all-off fp unmoved; `test_charger` green (telegraph timing, kill gating, wall stop, cap=1/room, events); params↔schema green; deterministic placement; worklog + commit.

### S6b — New hazard #2: Splitter
- Milestone: M1.9 (Wave 4)   Assignee: general-purpose (+ character-animator: placeholder sprites)   BlockedBy: S2, S3
- Spec: `design/M1_9_Tasks/S6b_splitter_hazard.md` (body + §Resolved Decisions; D-RAT-2)
- Goal: `splitter.tres` + `splitter_child.tres` (min_band=2, `cap_group=&"new_hazards"`, per_band_cap=8) + the throw-death split hook (client (b): `svc.spawn` mid-run at adjacent `valid_cells`, deterministic-per-split from parent, ctx carries depth/run_t_ms); slow `ChaseMove` pursuer; children half-scale, pure cost, gen 1; `&"split"`/`&"split_refused"` events.
- Done when: all-off fp unmoved; generation fingerprint unaffected by splits; cap-refusal test green; `test_splitter` green; params↔schema green (both defs); worklog + commit.

### S7 — New band: `band_two.tres` ("The Sump")
- Milestone: M1.9 (Wave 4)   Assignee: game-director-designer (+ environment-artist: tint pass, general-purpose: glue)   BlockedBy: S1, S5, S3
- Spec: `design/M1_9_Tasks/S7_band_two.md` (body + §Resolved Decisions; D-RAT-1/3/4)
- Goal: author The Sump as data — socket/branchy (target 16, branch 0.15), `band_depth=2`, flavors `SetPieceInject` (reused large piece) + `WearDecay(&"flooded")` per S5's real schemas, 6-entry deck (4 legacy + charger/splitter, authored order), `depth_curve_band_two.tres` (1.15→2.1, tier 2→5), sepia-amber `palette_tint` (tint-only).
- Done when: `band_two` deterministic (same seed → same fp ×2; connectivity through decay green); deck spawns within caps via the builder; `band_greybox` control untouched; headless profile-load contract test green; worklog + commit.

### Wave 5 — Reachability

### S8 — Second hub portal + band routing + telemetry stamp
- Milestone: M1.9 (Wave 5)   Assignee: general-purpose   BlockedBy: S3, S7
- Spec: `design/M1_9_Tasks/S8_hub_portal_routing.md` (body + §Resolved Decisions; D-RAT-1)
- Goal: second `departure_portal.tscn` instance at (220,-150) (`interactable_id=&"portal_band_two"`, route key `&"band_two"`, ember-orange glow, Sump prompt); rewrite `_resolve_band_profile()` off `consume_pending_dive_band()`; portal 1 (`&"near"`→band_greybox) byte-identical; `band_id` already stamps run rows (verify).
- Done when: existing portal path byte-identical (fp + `test_hub_contract`); `test_band_routing` green (new portal lands in band_two with its fp); smoke green; no save change; worklog + commit.

### S9 — Deck-entry override wrapper (D-RAT-2 delivery) *(Wave-4 close-out, Director Addressed 2026-07-03)*
- Milestone: M1.9 (Wave 5, ∥ S8)   Assignee: general-purpose   BlockedBy: S3, S6a, S7
- Spec: none (close-out-planned task) — contract in this entry + `DESIGN_DEVIATIONS_HISTORY.md` §M1.9 Wave-4 (ORCH entry). Origin: D-RAT-2's Charger "deck `param_override → false`" had no data mechanism (deck = plain def refs per S7 §RD).
- Goal: a `DeckEntry` Resource (`def: OppositionDef` + `param_overrides: Dictionary`) accepted in `BandProfile.opposition_deck` MIXED with plain defs (back-compat); the EncounterBuilder deck lane merges overrides at ctx time with precedence def params < deck-entry overrides < `rc.param_overrides`; rewrap band_two's charger row with the D-RAT-2 values (`throwable_while_charging=false`, `wall_crash_recover_mult=2.0`); tests (mixed-deck parity: a wrapper with empty overrides ≡ plain ref, byte-identical; precedence; band_two charger receives the D-RAT-2 values).
- Done when: all-off + greybox fps byte-identical; `test_band_two_profile`/`test_encounter_builder`/`test_charger` green (charger def defaults still D-RAT-2-letter — the test pins them); new `test_deck_entry` green; worklog + commit.

### Wave 6 — Re-gate  *(standing playtest-gate steps)*

### SG1 — M1.9 playtest build + verify + changelog + itch publish
- Milestone: M1.9 (Wave 6)   Assignee: qa-playtest-coordinator   BlockedBy: S0–S9 all Done
- Spec: breakdown §SG1; template `design/M1_8_Tasks/HG1_playtest_build.md`
- Goal: full M1.9 verify matrix (fp `e943ac9c8bc1` · 91-knob model · bandgen determinism · preset parity · both portals · suite); `changelog.txt` M1.8→M1.9 feature delta; publish to itch (`BUTLER=/mnt/c/wsl-libraries/butler/butler bash Game/tools/push_itch.sh`, human/network-gated).
- Done when: verify matrix green; changelog committed; build live on `qusto/the-far-yard:html5`.

### SG2 — M1.9 telemetry / balance analysis
- Milestone: M1.9 (Wave 6)   Assignee: qa-playtest-coordinator   BlockedBy: SG1 + Director playtest
- Goal: per-band comparison off `band_id`; new-hazard readability + fairness (via `opposition_event`); The Sump's +15% step felt?; `debug_dirty` runs filtered; web perf with the deck live.
- Done when: analysis doc assembled for SG3.

### SG3 — M1.9 re-gate verdict (Director decides)
- Milestone: M1.9 (Wave 6)   Assignee: qa (assembles) → Director (decides)   BlockedBy: SG2
- Goal: go/iterate/pivot in `design/M1_9_Tasks/G4_findings_M1.9.md`. Watch-items: did "content = data" hold (true proof cost incl. the LethalContact seam); promote charger/splitter to band 1?; legacy-signal retirement; ceiling numeric merge; CaveBackend/ScatterBackend next?
- Done when: recorded verdict.

---

## M1.8 — Hub Art Dressing — ✓ CLOSED 2026-07-02 (Director)

Build + HG1 published (final `m1-20260702-3faeed0`, 45° iso hub retained; H2 top-down = revert path). HG2
short-circuited by direct Director review; verdict + watch-items: `design/M1_8_Tasks/G4_findings_M1.8.md`.
17 deviations dispositioned (15 Reviewed + 2 Addressed) + archived. Tasks archived → `TASKS_COMPLETED.md`.
H3 (street-threshold prop) carried to the follow-ups section below.

---

## M1.7 — Player Embodiment (build DONE; RG2/RG3 Director-pending, non-blocking)

Replace the greybox player (teal `ColorRect`+`Nose`) with the **first real character sprite** — the
`player_basic_template` (flannel/hoodie, 8-directional: walk · pickup · throw · idle-from-rotations) — in **both** the Hub
and the Dive, driven entirely off the existing `facing`/`aim`/`velocity`/`junk_picked_up`/`item_thrown` seams; plus a
**debug toggle** to disable the art (fall back to greybox). Breakdown + dependency map + wave order + locked decisions:
`design/M1_7_Tasks/M1.7_Breakdown.md`. **Design is LOCKED** — every task doc carries a `Resolved Decisions` + a
`Director Disposition` section. Director calls: art in BOTH hub+dive (one shared `player.tscn`); pickup/throw use a **brief
movement-lock** (lock on **accepted** pickups only; **clip-driven** duration) — **both exposed as `@export` knobs** on the
visual controller (NOT `RunConfig` fields). **Invariants:** all-off `RunConfig` fp stays `e943ac9c8bc1`; **89-knob count
holds** (the debug art toggle is a view-only switch OUTSIDE the `config_menu` MANIFEST/coverage); **art-OFF = M1.6
byte-for-byte** (greybox retained, no lock); collision r=14 + `player_movement.tres` untouched; frames **COPIED** (never
moved) from `art_workshop/` into `Game/`, filter-off, LFS. Sequential single wave: N0 → N1 → N2.

**Build tasks all DONE + archived → `TASKS_COMPLETED.md`** (N0 `07edb77` · N1 `47ab9a8` · N2 `cffb5db` ·
RG1 published `m1-20260628-867410f` + FIXINTERP/FIXEAST/PLAYERTAB/art-default-OFF follow-ups).
Open here: RG2/RG3 (Director-pending, non-blocking).

### RG2 — M1.7 readability / telemetry check
- Milestone: M1.7 (Wave 2)   Assignee: qa-playtest-coordinator   BlockedBy: RG1 + human playtest data
- Spec: template `design/M1_1_Tasks/RG2_telemetry_analysis.md`
- Goal: light pass (visual change) — confirm no perf regression from the sprite on the web build; telemetry comparable to M1.6; surface any readability friction (8-dir snapping, movement-lock feel) the Director flags.
- Done when: a short analysis artifact + the Director's readability notes assembled for RG3.

### RG3 — M1.7 re-gate verdict (Director decides)
- Milestone: M1.7 (Wave 2)   Assignee: qa-playtest-coordinator (assembles) → Director (decides)   BlockedBy: RG2
- Spec: template `design/M1_1_Tasks/RG3_regate_verdict.md`
- Goal: record go/iterate/pivot in `design/M1_7_Tasks/G4_findings_M1.7.md`. Watch-items: movement-lock feel; 8-direction legibility; the dive-gear-vs-surface-look question.
- Done when: a recorded go/iterate/pivot verdict.

---

## M1 follow-ups (deferred tech-debt — non-blocking, backlog)

From the M1 wave-5 close-out (`DESIGN_DEVIATIONS_HISTORY.md` §"M1 wave 5"). Neither blocks M1.2; pick up opportunistically.

### H3 — Street-exit threshold prop (PixelLab) — **DEFERRED (Director-gated, paid credits)** *(carried from M1.8, closed 2026-07-02)*
- Milestone: M1.8 (follow-up)   Assignee: environment-artist   BlockedBy: Director OK
- The one missing Layout-A spec prop (`SS`); not loop-critical (no functional street exit yet). Generate only on explicit Director go. Watch-item context: `design/M1_8_Tasks/G4_findings_M1.8.md`.

### FU5 — Shared Actor-host shell (zero per-def host files) *(post-gate; Wave-4 close-out, Director Addressed 2026-07-03)*
- Milestone: backlog (post-M1.9-gate)   Assignee: general-purpose   BlockedBy: M1.9 SG3 verdict
- Origin: S6a dev 1 (`charger_hazard.gd` host shell was needed beyond "def + one component"). Director directed a shared host scene/script so a new def needs ZERO new host files — the per-entity shell (family guard, run clock, component acquire/tick order, emit sites, seams) becomes one generic parameterized host. Constraint: the def-schema host contract (bare instance reports `get_def_id()==def.id`) must survive, and golden frame-trace parity for all shipped hazards must hold.

### BUG-M13FLAKE — `test_rg1_m13_verify` intermittently misses telemetry rows headless
- Milestone: backlog (QA)   Assignee: qa-playtest-coordinator   BlockedBy: none
- Pre-existing timing flake (confirmed on pre-Wave-2 `main` 9cc00c1, ~40% failure rate across repeated headless runs, 2026-07-03): m13 intermittently reports missing nav/exposure/timeout telemetry rows ("emitted none of […]"), passes on retry. NOT an M1.9 regression. Diagnose the timed-segment race and stabilize (deterministic clock or generous margins). Board item created 2026-07-03.

### FU1 — GdUnit4 `test_jsonl_writer`
- Milestone: M1 (follow-up)   Assignee: qa-playtest-coordinator   BlockedBy: none
- Spec: `M1_As_Built.md` §Telemetry + `systems/telemetry/jsonl_writer.gd`
- Goal: add the GdUnit4 `test_jsonl_writer` suite G2 deferred — exercise the writer seam (write rows, read back, assert parseable JSON + envelope fields `v, ts, t_ms, run_id, session_id, type, data`).
- Done when: a GdUnit4 suite under `tests/telemetry/` covers `JsonlWriter` round-trip + envelope fields; green headless; test count rises.

### FU2 — Static `EconomyMath` helper
- Milestone: M1 (follow-up)   Assignee: general-purpose   BlockedBy: none
- Spec: `systems/game_state.gd` (`_resolve_pockets`/`_sum_values`/`run_haul_value`)
- Goal: lift the pure economy math out of `GameState` into a static `EconomyMath` helper so it's testable without snapshotting global meta; `GameState` delegates; no behavior change.
- Done when: a static `EconomyMath` owns pockets/sum/haul; `GameState` delegates; G2 economy suites call it directly (no meta snapshot); suite green.

### FU3 — Repair-or-retire `test_rg1_m13_verify` *(M1.6 W2-F1 — Reviewed)*
- Milestone: M1.6 (follow-up)   Assignee: qa-playtest-coordinator   BlockedBy: none
- Spec: `tests/test_rg1_m13_verify.gd` + `design/DESIGN_DEVIATIONS_HISTORY.md` §"M1.6 Wave 2 close-out"
- Goal: the M1.3 RG-verify scene is stale (fails on M5/all-on opposition-telemetry rows + `timeout` end-cause; verified pre-existing at `536c9ba`, not in the CI gate, last green at M1.3). Either align its preset/telemetry expectations to the current build or retire it in favour of the maintained `m14`/`m15` verifies; if kept, wire it into the standing CI set.
- Done when: m13 either passes green deterministically (and is in the CI gate) or is retired with a one-line rationale; no other RG verify regresses.

### FU4 — Keyboard-only aim tracks movement *(M1.5 L6-F1 — Reviewed)*
- Milestone: M1.6 (follow-up)   Assignee: general-purpose   BlockedBy: none
- Spec: `player.gd` `resolve_aim()` + `design/M1_5_Tasks/L6_control_rework.md`
- Goal: when neither mouse (`_mouse_active`) nor right-stick is active, let the pure-keyboard fallback aim track the movement direction instead of holding the DOWN default, without destabilising controller stick-release or letting a stale cursor hijack aim. Mouse + controller (primary) behaviour unchanged.
- Done when: a keyboard-only player's aim follows movement; controller/mouse aim unchanged; throw tests green; all-off fp `e943ac9c8bc1` unmoved.

---

## Backlog (M2+)
Pulled forward when M1.x passes its gate. See TDD §7: M2 (vertical slice: full day loop, recipe repair, first enemy, real art for one band), M3 (bands 1–3, currencies/tracks, exposure crises), M4 (Act 3 + endings), M5 (polish/ship). The **economy workbook** `design/economy_model.xlsx` (game-director-designer) is due **before M3**.
