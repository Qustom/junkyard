# TASKS — Completed (THE FAR YARD)

Archive of finished tasks, moved out of `TASKS.md` to keep the active queue readable.
Completion proof (commit SHA, test verdict, worklog) lives in `STATUS.md` §Done and the worklogs.
Newest milestones at the bottom. See `CLAUDE.md` → orchestrator loop for the archiving convention.

---

## M1 — Greybox Core Loop (first "is it fun?" gate)

Prove the push/cash-out tension in 30 seconds of decision-making. Greybox only — placeholders, no
real art. Full milestone breakdown, dependency map, and build order: `design/M1_Tasks/Junkyard_M1_Breakdown.md`.

### Workstream A — Player & movement

### A1 — Player scene with top-down movement
- Milestone: M1   Assignee: general-purpose (+ character-animator: greybox placeholder)   BlockedBy: none
- Spec: design/M1_Tasks/A1_player_movement.md
- Goal: `Player` as a `CharacterBody2D` with smooth 8-direction movement (accel/friction), a greybox sprite, driven entirely by named Input Map actions; keyboard + controller.
- Done when: player moves smoothly in all directions on a test scene; movement reads from named input actions; controller and keyboard both work.

### A2 — Interaction component
- Milestone: M1   Assignee: general-purpose   BlockedBy: A1
- Spec: design/M1_Tasks/A2_interaction_component.md
- Goal: reusable area-based `Interactable` detection so the player can "use" the nearest interactable (junk, gate), surfacing a prompt; composition so it serves both pickup and the gate.
- Done when: walking near an interactable shows a prompt; pressing `interact` fires a signal on `EventBus` naming the target.

### A3 — In-dive clock (light/stamina, minimal)
- Milestone: M1   Assignee: general-purpose (+ ui-ux-designer: meter readout)   BlockedBy: A1
- Spec: design/M1_Tasks/A3_in_dive_clock.md
- Goal: a single depleting in-dive resource that creates time pressure; reaching zero forces a timeout (handled in E3). Minimal — it exists only to give the push/cash-out decision a clock.
- Done when: a visible meter depletes over a run; hitting zero raises a `timeout` event on `EventBus`.

### Workstream B — Greybox band & procedural assembly

### B1 — Zone-piece authoring format
- Milestone: M1   Assignee: general-purpose (+ environment-artist: greybox tiles/pieces)   BlockedBy: none
- Spec: design/M1_Tasks/B1_zone_piece_format.md
- Goal: define the atomic zone-piece as a hand-authored `PackedScene` on `TileMapLayer` with tagged entry/exit sockets; author 4–6 greybox pieces with the built-in TileSet (blockout collision only).
- Done when: 4–6 zone-piece scenes exist with consistently tagged entry/exit sockets; each loads standalone and is walkable.

### B2 — Modular room-graph generator (M1 prototype)
- Milestone: M1   Assignee: general-purpose   BlockedBy: B1
- Spec: design/M1_Tasks/B2_room_graph_generator.md
- Goal: instance zone-piece `PackedScene`s and stitch them via socket-adjacency matching, driven by the seeded `RNG` autoload so layouts are reproducible. Cyclic backbone / WFC seam-matching may be stubbed for M1.
- Done when: given a seed, the generator produces a connected, walkable band; same seed → identical layout (determinism verified by test).

### B3 — Band depth / "push deeper" structure
- Milestone: M1   Assignee: general-purpose (+ game-director-designer: depth value curve)   BlockedBy: B2, C1
- Spec: design/M1_Tasks/B3_band_depth_structure.md
- Goal: make the band express depth so "push deeper" is a real choice — junk value/density rises with depth and distance back to the gate grows. No instability math yet (that's M3).
- Done when: moving deeper into the band visibly increases junk reward and distance back to the gate.

### Workstream C — Junk as data + pickup

### C1 — Junk as Resource
- Milestone: M1   Assignee: game-director-designer   BlockedBy: none
- Spec: design/M1_Tasks/C1_junk_resource.md
- Goal: define `JunkItem` as a custom `.tres` `Resource` (id, display name, slot size/containment, base sell value, greybox color/shape); author ~6–10 items spanning a value range.
- Done when: junk items are authorable as `.tres` with no code change; a value range exists to make "what's worth carrying" a decision.

### C2 — Junk pickup in the band
- Milestone: M1   Assignee: general-purpose   BlockedBy: A2, B2, C1, D1
- Spec: design/M1_Tasks/C2_junk_pickup.md
- Goal: place junk pickups in the generated band (B2/B3, seeded RNG); picking up (via A2) adds to run inventory and fires a telemetry-able `EventBus` event.
- Done when: junk visibly spawns; interacting picks it up, removes it from the world, adds it to run inventory; a pickup event fires on `EventBus`.

### Workstream D — Slot inventory

### D1 — Slot inventory data model
- Milestone: M1   Assignee: general-purpose   BlockedBy: C1
- Spec: design/M1_Tasks/D1_slot_inventory_model.md
- Goal: data-driven slot inventory in `GameState` run-state; items occupy slots by size/containment flags; enforce capacity so the player must choose what to carry.
- Done when: inventory accepts/rejects items by size and capacity; full inventory blocks further pickup; state lives in run-state, not meta.

### D2 — Inventory UI (greybox)
- Milestone: M1   Assignee: ui-ux-designer   BlockedBy: D1
- Spec: design/M1_Tasks/D2_inventory_ui.md
- Goal: a `Control`-based grid showing carried junk and remaining capacity; greybox styling, but readability matters because the player makes the keep/drop decision here.
- Done when: the grid reflects current inventory in real time; capacity/fullness is legible at a glance.

### D3 — Activate drop-to-swap re-spawn (emit `junk_dropped`)
- Milestone: M1   Assignee: ui-ux-designer   BlockedBy: D2, C2
- Spec: design/M1_Tasks/D2_inventory_ui.md (drop affordance) + `M1_As_Built.md` §B3↔C2 seam
- Goal: close the wave-3 `C2/dropwiring` deviation (Director: **Addressed**) — D2's drop gesture must `EventBus.junk_dropped.emit(removed_item, drop_world_pos)` after `RunInventory.remove_at()`, so C2's already-wired `JunkSpawner` (`spawn_one` + `junk_dropped` listener) re-spawns the dropped junk in the world. A one-line emit + the world position to drop at.
- Done when: right-clicking a cell drops that item from the bag AND a re-grabbable `JunkPickup` appears in the world at the player; verified headless (emit fires, spawner re-instantiates).

### Workstream E — The gate: extraction, banking & death-drop

### E1 — Gate node + extract-and-bank
- Milestone: M1   Assignee: general-purpose   BlockedBy: A2, D1
- Spec: design/M1_Tasks/E1_gate_extract_bank.md
- Goal: a single gate node; interacting ends the run successfully and **banks** the run inventory (commit haul from run-state to meta-save). The "cash out" half of the core tension.
- Done when: using the gate ends the run and transfers carried junk to the banked/meta total; a `run_end{cause: extract}` event fires.

### E2 — Push/cash-out decision surface
- Milestone: M1   Assignee: ui-ux-designer (+ general-purpose: wiring)   BlockedBy: E1, B3, D2, A3
- Spec: design/M1_Tasks/E2_push_cashout_decision.md
- Goal: make the push-vs-extract choice explicit and felt — show held value and the cost of pushing deeper (clock from A3, distance from B3). This is the literal thing the feedback gate measures.
- Done when: at/near the gate the player can clearly weigh "extract now with X" vs. "push for more"; the tension is presented within a ~30-second window.

### E3 — Death / timeout drops haul
- Milestone: M1   Assignee: general-purpose   BlockedBy: E1, A3
- Spec: design/M1_Tasks/E3_death_timeout_drop.md
- Goal: on death or clock timeout (A3), drop the unbanked haul minus a "pockets" fraction; the player keeps a small portion, loses the rest. The downside that gives "push deeper" its weight.
- Done when: dying or timing out ends the run, retains only the pockets fraction, discards the rest; a `run_end{cause: death|timeout}` event fires with the amount lost.

### Workstream F — Placeholder sell screen (junk → Money)

### F1 — Single placeholder currency: Money
- Milestone: M1   Assignee: general-purpose (+ game-director-designer: values)   BlockedBy: E1
- Spec: design/M1_Tasks/F1_money_ledger.md
- Goal: add a `Money` ledger to meta-state in `GameState`; banked junk converts to Money at each item's base sell value (full three-currency system is M3).
- Done when: banked junk increases a persistent Money total by the sum of item values.

### F2 — Placeholder sell screen
- Milestone: M1   Assignee: ui-ux-designer   BlockedBy: F1, D2
- Spec: design/M1_Tasks/F2_sell_screen.md
- Goal: a minimal post-extraction screen listing banked junk and converting it to Money; greybox UI; shows the payoff so the push/cash-out loop closes with a visible reward.
- Done when: after a successful extract, the player sees their junk tallied into Money; the running total persists across runs.

### Workstream G — Telemetry, playtest build & the feedback gate

### G1 — Wire M1 telemetry events
- Milestone: M1   Assignee: qa-playtest-coordinator   BlockedBy: E1, E3, C2
- Spec: design/M1_Tasks/G1_telemetry_events.md
- Goal: hook the `Telemetry` autoload to log M1 `EventBus` events to local JSONL — run start/end + duration + cause, junk picked up, junk banked vs. lost, band depth reached.
- Done when: a completed run produces a structured JSONL log with run duration, end cause, depth, and haul banked/lost; the opt-in toggle is respected.

### G2 — Determinism & logic tests (GdUnit4)
- Milestone: M1   Assignee: qa-playtest-coordinator   BlockedBy: B2, D1, E1, E3, F1
- Spec: design/M1_Tasks/G2_tests_gdunit4.md
- Goal: GdUnit4 tests for the pure-logic pieces — proc-gen determinism, inventory capacity rules, banking math, death-drop pockets math — wired into the headless CI smoke test.
- Done when: tests pass in CI headless; determinism and economy/inventory math are covered.

### G5 — Meta save-migration fixture (v1→v2)
- Milestone: M1   Assignee: qa-playtest-coordinator   BlockedBy: E1
- Spec: `M1_As_Built.md` §Save schema (E1) + Technical Design save rules
- Goal: close the wave-3 `E1/schema` deviation (Director: **Addressed**) — the meta `schema_version` bump 1→2 (added `banked_junk`) needs a QA migration fixture, per the TDD rule "a QA fixture on every schema change". Add a v1 `meta.sav` fixture and a test that loads it, runs `_migrate_meta`, and asserts `banked_junk` defaults to `[]` and existing fields survive intact (atomic write + `.bak` preserved).
- Done when: a headless test loads a v1 meta fixture, migrates to v2, and asserts the migrated state; runs green in CI. (Can fold into G2's GdUnit4 suite once the addon is vendored.)

### G3 — Greybox playtest build
- Milestone: M1   Assignee: qa-playtest-coordinator (+ producer: build/distribution)   BlockedBy: A1, A2, A3, B1, B2, B3, C1, C2, D1, D2, E1, E2, E3, F1, F2, G1
- Spec: design/M1_Tasks/G3_playtest_build.md
- Goal: a runnable build (itch.io/Butler nightly) of the full loop — spawn → dive → pick up junk → decide push/extract → bank/lose → sell → repeat.
- Done when: a fresh build runs the complete loop without blockers; multiple runs are possible in one session.

### G6 — In-build telemetry consent prompt
- Milestone: M1   Assignee: ui-ux-designer   BlockedBy: G3
- Spec: `M1_As_Built.md` §Telemetry seam + `systems/settings/` (G1 infra) — wave-5 close-out deviation G3 #1 (Director: **Addressed** 2026-06-18)
- Goal: close the G3 #1 deviation — the G3 build shipped no in-build consent prompt, risking empty G4 telemetry. Add a first-run modal (Enable / Not now) shown once before the player reaches gameplay in `scenes/game/main_game.tscn`, stating plainly what is logged, that there is no PII, and that it stays local until sent back (reuse `TelemetrySettingsPanel.CONSENT_COPY`). Default OFF; only write telemetry after an affirmative Enable. Persist an "asked" flag so it never re-prompts (add a `telemetry.asked` key to `settings.cfg` via `Settings`); wire the choice through `Telemetry.set_enabled()` / `Settings.set_telemetry_enabled()`. The existing settings toggle (G1) remains the way to change the choice later.
- Done when: a fresh profile (no `settings.cfg`) shows the prompt once at launch; choosing Enable makes a subsequent run write `user://telemetry/run_log.jsonl`, choosing Not now writes nothing; the prompt does not reappear after a choice; verified headless (the asked-flag gate + that Enable→writes / Not-now→no-write); existing suite stays green (SMOKE OK, GdUnit4 30/30, telemetry-jsonl check).

### G4 — Run the M1 feedback gate (internal playtest)
- Milestone: M1   Assignee: producer (+ qa-playtest-coordinator: telemetry analysis)   BlockedBy: G3, G6
- Spec: design/M1_Tasks/G4_feedback_gate.md
- Goal: run the internal playtest — *is the push/cash-out tension fun in 30 seconds?* Combine direct feedback with telemetry (run-length histograms, mid-run abandonment, runs/session > 1.5). Record a go/iterate/pivot decision.
- Done when: playtest run with ≥ a few testers; a written verdict backed by telemetry; an explicit go/iterate/pivot call recorded. **Human-run** (dev-machine internal playtest); Claude prepares the loop-smoke checklist + analyzes telemetry and recommends, the Director decides.

---

---

## M1.1 — Greybox Cost Axis · Wave 1 (Foundations) — all done 2026-06-19

### R0 — Run-config data model — **Done** (merged `30e41b9`)
`RunConfig` Resource + `GameState.active_run_config`; all-off default = M1.0 baseline; 32 knobs; `to_flat_dict()`.

### BUG1 — `run_ended.duration_s` always 0 — **Done** (merged `33eb786`, impl `cf7e342`)
`_run_start_ms` + `_elapsed_s()`; real duration on extract/death/timeout, within a frame of a direct clock ref. `tests/test_run_duration.tscn` → RUN DURATION OK.

### BUG2 — within-band depth not tracked — **Done** (merged `33eb786`, impl `cf7e342`)
`current_depth_index`/`max_depth_reached`/`current_dist_to_gate` run-state; `set_current_depth()` edge-emits `depth_changed`; `main_game.gd` cell→depth driver; `run_ended.depth_reached`=max. `tests/test_within_band_depth.tscn` → WITHIN BAND DEPTH OK.

### TEL — Telemetry config-marking + opposition events — **Done** (merged `c940ae4`, impl `66ec131`)
Sole `event_bus.gd` editor: added 11 opposition/penalty signals (not `depth_changed`, already pre-declared). `run_started.data.run_config` snapshot; 7 opposition EventTypes; envelope `v=1` (no bump); `run_ended` arity unchanged. `tests/test_telemetry_config_marking.tscn` → TEL CONFIG MARKING OK.

### BUG3 — open sockets to off-map void — **Done** (merged `c940ae4`, impl `f0baeae`)
New `systems/bandgen/socket_sealer.gd` (RefCounted, zero RNG); 1-line call in `main_game.gd:_materialise_band`; caps unmated sockets with the existing WALL tile; `fingerprint()` byte-identical with/without seal. `tests/test_bandgen_determinism.tscn` → BUG3 SOCKET SEAL OK.

### CFG — Pre-run Config menu — **Done** (merged `62e16b9`, impl `169bf6c`)
`ui/config/config_menu.{tscn,gd}` + `config_strings.csv`, side rail in `main_game.tscn`'s MainMenu; surfaces 100% of `RunConfig`'s 32 knobs + master toggles + "reset to baseline (all off)"; stages working config via `MainGame.start_new_run` (shape a). `tests/test_config_menu.tscn` → CONFIG MENU OK (32/32 knobs reachable).

**Wave 1 close-out (2026-06-19):** 2 orchestrator deviations dispositioned (W1.1-1 Reviewed, W1.1-2 Addressed); archived. Next: Wave 2 (R1–R4).

---

## M1.1 — Greybox Cost Axis · Wave 2 (the four oppositions) — all done 2026-06-19

### R1 — Pursuing / awakening hazard — **Done** (merged `0c80622`, impl `023c346`)
`scenes/hazards/hazard_entity.{tscn,gd}` (CharacterBody2D, `hazard` layer); awaken on depth/linger (no re-sleep), toward-player `move_and_slide` chase, distance catch → `fail_run(&"death")` or non-fatal cost; additive spawn seam in `main_game.gd`. `tests/test_pursuing_hazard.tscn` → PURSUING HAZARD OK.

### R2 — Costlier return trip — **Done** (merged `b0566c2`, impl `5c1f2a9`)
`systems/oppositions/return_cost.gd` run-state node; marginal-per-hop egress toll off live `current_dist_to_gate`; clock/exposure/meter via existing public surfaces; decay_behind behind reachability guard. RG1 wires it. `tests/test_return_cost.tscn` → RETURN COST OK.

### R3 — Rising instability / exposure meter — **Done** (merged `b0566c2`, impl `87d2628`)
`systems/oppositions/exposure_meter.gd`; depth-weighted climb, retreat decay, one-shot crossings, max→`fail_run(&"timeout")`; penalty seams via pre-declared signals (`player.gd` speed-mult, `dive_clock.gd` clock-tax, R4-fog vision-mult); greybox HUD bar in `decision_hud.tscn`. RG1 wires the meter node. `tests/test_exposure_meter.tscn` → EXPOSURE METER OK + EXPOSURE HUD OK.

### R4 — Maze / navigation risk — **Done** (merged `b0566c2`, impl `b810aa0`)
Depth-scaled integer branch roll in `band_generator.gd` (contract `fingerprint(seed+config)`, all-off byte-matches M1.0 `e943ac9c8bc1`); `entities/dive/{vision_fog,lost_proxy}.gd` run-state; `nav_branch_taken`/`nav_lost_proxy`. Flagged **W2-R4-1** (BUG3 seal gap at high branch rates). `tests/test_bandgen_determinism.tscn` → R4 NAV OK.

**Wave 2 close-out:** pending Director disposition of W2-R4-1 (R1/R2/R3 = none). Next: Wave 3 re-gate (RG1→playtest→RG2→RG3).

---

## M1.1 — Greybox Cost Axis · Wave 3 (re-gate) · RG1 — done 2026-06-19

### RG1 — Playtest build (risk active) — **Done** (merged `c4c71b8`, impl `6013c07`)
Assembled the runnable M1.1 loop. Wired R2 `ReturnCost` + R3 `ExposureMeter` as persistent self-gating children of `main_game` (DiveClock injected into ReturnCost in `_ready`); added a "Back to Config" button on the sell screen; CFG config-rebind + R1/R4 spawns inherited (already wired). `tests/test_rg1_loop_verify.tscn` → **RG1 BUILD VERIFY OK** (16/18 matrix rows headless-verified: V1–V4 isolation, V5 stacked, V6/V7 all-off=M1.0, V8–V11 four end-causes, V12–V16/V18 loop+telemetry integrity; 6 rows + subjective deferred to the human checklist). Updated `tools/playtest/{loop_smoke_checklist,tester_readme}.md`. Flagged W3-RG1-1/2 (minor as-built notes).

**RG2 + RG3 are HUMAN-GATED** — require a dev-machine playtest (`godot project.godot` → `main_game.tscn`, sweep configs). Claude assembles + analyzes + recommends; the Director plays + decides go/iterate/pivot.

---

## M1.1 — Greybox Cost Axis · Wave 3 (re-gate) — closed 2026-06-19 (verdict ITERATE → M1.2)

### RG2 — Telemetry analysis + M1.0 comparison — **Done** (`design/M1_1_Tasks/G4_findings_M1.1.md`)
Director playtested the RG1 build (57 M1.1 runs, `playtest_data/M1.1/run_log_2026-06-19.jsonl`). Analysis: cost axis half-landed — R2/R3 produced the 5 `timeout` losses M1.0 never had + shortened runs, but R1 caught 0× (body==hall geometry), levels too small/uniform, R2/R3/R4 fired invisibly. Triaged into I1–I5 + BUG4.

### RG3 — Re-gate verdict — **Done** (verdict: **ITERATE → M1.2**)
Director's verdict on the M1.1 re-gate: ITERATE. Bumped to M1.2 (Legibility & Level Scale), authored via the four-phase process (`design/M1_2_Tasks/`). The cost-axis mechanics stay; M1.2 makes them legible + fair, then re-gates.

**M1.1 fully complete** — Wave 1 (foundations) + Wave 2 (R1–R4 oppositions) + Wave 3 (RG1 build + RG2 analysis + RG3 verdict). All close-outs done (W1.1-1/2, W2-R4-1→BUG4, W3-RG1-1/2). Detailed Done tables + proof: `STATUS_ARCHIVE.md`.

---

## M1.2 — Legibility & Level Scale · Wave 1 (Spatial & data foundation) — done 2026-06-19

All three integrated on `main`, verified (SMOKE + determinism + suite green), pushed, board = Done. All-off default
byte-matches the M1.1 baseline (fp=e943ac9c8bc1). Close-out: 4 deviations, all Director-Reviewed, archived to
`DESIGN_DEVIATIONS_HISTORY.md`.

### I1 — Configurable level scale (room count + size + new larger pieces) — **Done** (merged `e67532c`, impl `e1e313c`)
Shipped all three Director-LOCKED deliverables: `lvl_room_count` override (-1 sentinel = baseline 12) threaded into the
generator grow-loop; `lvl_size_mult` applied at materialisation as one shared integer `cell_size` (layout-invariant — does
not move `fingerprint()`), with the Phase-3 loot seam fixed (same `cell_size` into `JunkPlacer.plan`); 4 new B1-compliant
greybox pieces (`piece_room_xl/chamber/corridor_long_h/hall_v`) behind a config-dependent ext catalog (`data/piece_catalog_ext.tres`)
so the baseline catalog stays byte-identical. CFG 35/35 coverage + `to_flat_dict()` carries the knobs. `tests/test_level_scale_determinism.{gd,tscn}` green. Empirical: linear spine reached requested count up to 60 (no realistic ceiling). Worklog `worklogs/2026-06-19-I1-general-purpose.md`.

### BUG4 — Branch-rate-independent socket seal — **Done** (merged `eee4418`, impl `187f63e`)
Generalised `SocketSealer` from frontier-keyed (`open_sockets`) to geometry-keyed: build one band-global FLOOR set, cap every
floor cell's outward 4-neighbour not in the set (the `floor_set.has(n)` guard protects mated doorways exactly). Deleted the
dead `_opening_lane_cells` helper. High-branch sweep (`branch_per_depth` 0.12–0.20 × 9 seeds): 508 void cells pre-seal → 0
post-seal on every band; `fingerprint()` byte-identical pre/post; connectivity preserved. Worklog `worklogs/2026-06-19-BUG4-general-purpose.md`.

### I5 — Telemetry hygiene (duration regression-lock + real build SHA) — **Done** (merged `1fd657e`, impl `f2a62fb`)
(a) Confirmed `duration_s=0` was a stale pre-fix binary (not a live bug) → added `tests/test_duration_loop_reentry.{gd,tscn}`
that drives 3 sequential `start_run` re-entries (extract→timeout→death) and asserts a real, independent nonzero `duration_s`
each (telemetry off); wired into `ci.yml` + `nightly.yml` as a merge gate. (b) `BuildVersion.short_sha()` now reads a
git-ignored baked `const .gd` artifact (`tools/stamp_build.sh`) → editor-live git → neutral `0000000` sentinel; dropped the
stale `project.godot config/build_sha`; `+dirty` suffix on an uncommitted tree. No `run_ended` arity / schema change. Worklog
`worklogs/2026-06-19-I5-qa-playtest-coordinator.md`.

---

## M1.2 — Legibility & Level Scale · Wave 2 (Oppositions retuned to the new canvas) — done 2026-06-19

All three integrated on `main`, verified (SMOKE + determinism + HUD + suite green), pushed, board = Done. Determinism unmoved
(fp=e943ac9c8bc1); none touched `main_game.gd` (the single-writer concern was moot). Close-out: 0 formal deviations; 1 finding
(R2 exposure-toll no-op) → BUG5 (Director: fix now). Dispatched ownership-split in parallel worktrees.

### I2 — Hazard refuge fix (size, navigation, catch) — **Done** (merged `1966145`, impl `4a02687`)
REFUGE (Director): hazard keeps wall collision; body shrunk r16→r10, anti-wall-stick next-frame tangent steering (`STALL_FRACTION`),
depth-scaled catch `effective = r1_catch_radius + r1_catch_radius_per_depth*depth`. New `r1_catch_radius_per_depth` RunConfig knob
(CFG now 36/36, in `to_flat_dict()`). Catch reachability proven headless (`hazard_caught` → `fail_run(death)`; M1.1 logged 0).
No `main_game.gd`/`event_bus`/`run_ended` change; all-off (r1 off) = M1.0. Worklog `worklogs/2026-06-19-I2-general-purpose.md`.

### I3 — R2/R3 visual cues — **Done** (merged `9b5d75d`, impl `c7a67f1`)
HUD-only projection (no new EventBus signal). R3 = colour-ramped exposure bar + read-only threshold ticks (thin→thick "spent")
+ white cross-flash + penalty banner keyed on `penalty_kind` (`Slowed`/`Sight narrows`/`Light drains`, `none`=nothing, with xN
stacking) + optional small HUD-space shake. R2 = clock-bar hot-amber punch + floating "−N {unit}" on `return_cost_incurred`.
Every cue has a non-colour channel (E2). All-off = M1.0 HUD (ExposureReadout hidden). Surfaced the R2-exposure-toll no-op finding
→ BUG5. Worklog `worklogs/2026-06-19-I3-ui-ux-designer.md`.

### I4 — Vision/fog rework (real occlusion + legible fog/lost) — **Done** (merged `d56674d`, impl `dc4d40d`)
Rework is internal to `entities/dive/vision_fog.gd` (no `main_game.gd` edit needed). Radial-dark world-space sprite (`OCCLUDE_ALPHA=0.94`,
~6% anti-blindness floor) genuinely HIDES geometry beyond the rim (was: dimmed); hole tightens with depth + R3 vision penalty,
floored at `MIN_RADIUS`. Three-state fog (never-seen / cool flat-static remembered ghost / live hole) separated on a non-hue axis.
Lost cue = screen-edge pulse on 1st `nav_lost_proxy`, persistent `"DISORIENTED"` HUD word on escalation, in I4's own CanvasLayer
(not DecisionHUD); no audio. R4-off = byte-identical M1.0. Fingerprint unmoved. Worklog `worklogs/2026-06-19-I4-general-purpose.md`.

### BUG5 — R2 exposure toll now charges R3's meter — **Done** (merged `0196713`, impl `ba9d58c`)
Wave 2 close-out fix (Director: fix now). `ReturnCost`'s `TOLL_EXPOSURE` already called `meter.add(cost)` but `ExposureMeter`
had only read-only getters → silent no-op. Added public `add(amount)` and refactored so `_process()` accrual + `add()` funnel
through one `_mutate_meter(value)` helper (single source of truth: clamp `[0,METER_MAX]`, edge-triggered one-shot
`exposure_crossed`/`exposure_penalty`, `r3_max_forces_loss`, `exposure_meter_changed`). Run-state only; no new signal/knob/schema;
`add()` inert when R3 off. Integration test: real `ReturnCost` + grouped `ExposureMeter`, taxed retreat 4→0 raises the meter by the
toll amount (6.5) end-to-end. Determinism unmoved. Worklog `worklogs/2026-06-19-BUG5-general-purpose.md`.

---

## M1.2 — Legibility & Level Scale · Wave 3 (re-gate) · RG1 — done 2026-06-19

### RG1 — M1.2 playtest build + verify — **Done** (merged `c7e130b`, impl `0669871`)
Assembled + verified the runnable M1.2 playtest build (no `main_game.gd` edit needed — the loop already reaches every fix).
Authored `design/M1_2_Tasks/RG1_playtest_build.md` (M1.2 verify matrix), `tests/test_rg1_m12_verify.{gd,tscn}` (headless driver),
and updated `tools/playtest/{loop_smoke_checklist,tester_readme}.md` with the Director's config-sweep guidance + `m12-` `build_tag`
convention. **`RG1 M1.2 VERIFY OK` — 14/20 rows headless-verified** (all-off fp=e943ac9c8bc1 unmoved; real build SHA; I1 scale; I2
depth-scaled catch→death; I3/I4 cue+nav rows; BUG5 exposure toll moves R3; BUG4 high-branch seal; new `lvl_*`/`r1_catch_radius_per_depth`
snapshot keys; real `duration_s`; carry-forward + no leak across loops; all 4 end-causes). 6 rendering/felt rows deferred to the human
playtest. Worklog `worklogs/2026-06-19-RG1-qa-playtest-coordinator.md`.

**RG2 + RG3 are HUMAN-GATED** — require the Director's dev-machine playtest (sweep configs, drop `.jsonl` in `playtest_data/M1.2/`).
Claude then analyses (RG2) + recommends; the Director plays + decides go/iterate/pivot (RG3).

---

## M1.3 — Legibility & Density · Wave 1 (Foundation & correctness) — done 2026-06-19

All 5 integrated on `main`, verified, pushed, board=Done; all-off fp byte-identical (e943ac9c8bc1). Close-out: 2 Reviewed + 1
Addressed (`DESIGN_DEVIATIONS_HISTORY.md` §"M1.3 Wave 1").

### J5 — Depth-counter HUD fix — **Done** (merged `50d8faf`)
HUD bottom-left now reads `Depth {current_depth_index} / {max_depth_reached}` via `EventBus.depth_changed` (was the static band counter, frozen at 1). HUD-only; determinism untouched. Worklog `worklogs/2026-06-19-J5-ui-ux-designer.md`.

### BUG6 — hazard_caught debounce + config-trap guards — **Done** (merged `ed176bf`, refined `25072f6`)
`_caught_latched` one-shot latch (sustained catch = 1 emit; was up to 2,199/run). `RunConfig.inert_enabled_oppositions()` warn-only config-trap guard + `run_started.data.inert_enabled_oppositions` flag. Trap set refined at close-out to 4 (the two R4 sub-traps merged into a maze-aware `r4_no_effect` so a deliberate maze-only R4 isn't nagged). fp byte-identical; CFG 36/36. Worklog `worklogs/2026-06-19-BUG6-m13-general-purpose.md`.

### DLV2 — In-game telemetry export for web — **Done** (merged `2b00a09`)
"Export telemetry" button on the sell screen, web-guarded (`OS.has_feature("web")`), downloads `user://telemetry/run_log.jsonl` from browser IndexedDB via `JavaScriptBridge.download_buffer` named `run_log_<build-id>.jsonl`. Inert on desktop; no schema/arity change. Worklog `worklogs/2026-06-19-DLV2-general-purpose.md`.

### DLV1 — itch.io HTML5 delivery via butler — **Done** (merged `02ad951`)
Web export preset (threaded, COI), `tools/push_itch.sh` → `qusto/the-far-yard:html5`, web templates installed, `nightly.yml` real slugs (web+Windows), SETUP §1a, tester_readme web/Chromium note. Web export **builds clean** (37 MB WASM). ⚠ **real butler push human-gated** — sandbox can't reach `broth.itch.ovh`; run `tools/push_itch.sh` once on a real network. Worklog `worklogs/2026-06-19-DLV1-producer.md`.

### J1 — Default play-preset + size-slider re-range — **Done** (merged `3159aac`, refined `25072f6`)
`RunConfig.make_default_play_preset()` (the game/CFG boots into it): lvl on, 19 rooms, size 4.0, R1 on (catch radius floored 23.3→24.0), **R4 maze-only / occlusion OFF (match-played, Director close-out)**, R2/R3 off; trap-free. `RANGE_MULT=[4.0,40.0]` (mult-40 headless smoke playable, 640 px/cell exact). All-off `RunConfig.new()` stays the permanent baseline (Reset=all-off); fp byte-identical. CFG warn-line folds BUG6's traps. Worklog `worklogs/2026-06-19-J1-general-purpose.md`.

---

## M1.4 — Stakes, Variety & Legibility — ✓ DONE 2026-06-21..24 (re-gated → ITERATE → M1.5)

All waves built + integrated on `main`, board=Done; all-off fp byte-identical (`e943ac9c8bc1`). Re-gated post-Wave-5 →
**RG3 verdict ITERATE → M1.5** (`design/M1_4_Tasks/G4_findings_M1.4.md` §RG3). Specs: `design/M1_4_Tasks/`. Completion
proof: `STATUS.md` §Done tables + `worklogs/2026-06-21-*` + `2026-06-21-RG1-*`. Tasks (all Done):

- **Wave 1:** K0 (foundation: 46→81 knobs + signals + K1 retune) · K3+K6 (resolution-independent camera + jitter fix) · K4 (configurable timer + near-end warning).
- **Wave 2:** K2 (quota + roguelite wipe, save META v2→v3 + migration + fixture) · K7 (exit placement rework, exits ship OFF).
- **Wave 3:** K5a (ping-pong hazard) · K5b (bomb hazard) · K5c (rotating-spikes hazard) · K5i (new-hazard spawn-seam integration).
- **Wave 4 (RG1):** M1.4 playtest build + verify (`test_rg1_m14_verify`) + itch publish.
- **Wave 5 (RG1-feedback bug-wave):** BUG7 (spawn-room instant-death fix) · BUG8 (ping-pong wall-stick fix) · TUNE2 (camera 1000 + spike spawn) · FB5 (multi-exit regression test; #5 NOT-a-bug). Re-gate after Wave 5 → ITERATE → M1.5.

---

## M1.5 — Agency & Legibility — ✓ DONE 2026-06-24..26 (re-gated → ITERATE → M1.6)

Give the player agency against danger + make the pursuer comprehensible + fix two legibility bugs, then re-gate.
Breakdown + locked decisions: `design/M1_5_Tasks/M1.5_Breakdown.md`. Re-gate verdict + control-rework provenance:
`design/M1_5_Tasks/G4_findings_M1.5.md`. Per-task specs: `design/M1_5_Tasks/L*.md`. All-off fp byte-identical
(e943ac9c8bc1); knob count 81 → 89; throw/highlight/pursuer pure run-state (no save change); input changes global.
- **Wave 1 (Foundation + legibility):** L0 (8 knobs + 4 signals + CFG rows, 81→89) · L3 (money text → below the timer) · L4 (grab-prompt per-frame visibility invariant).
- **Wave 2 (Agency & threat):** L1 (throwing mechanic: highlight selector + `thrown_item` Area2D, kills pursuer/ping-pong, miss re-drops; input remap F/Q-E/Space) · L2 (spawn-room pursuer = room-bound slow patrol) · L5 (K5 `*_kills` toggles + retired `_driven_default_preset()`).
- **Wave 3 (RG1):** M1.5 playtest build + verify + itch publish.
- **Wave 4 (L6 control rework):** mouse-aim throw (point at cursor, LMB throw, wheel cycle) + twin-stick controller (right-stick aim, RT throw, LB/RB cycle); Q/E+Space kept. Post-RG3 tuning (timer 600→300, controller throw press-edge latch, hazard fair-share). Director re-test → **RG3 verdict ITERATE → M1.6**.

---

## M1.6 — Surface & Staging — ✓ BUILD DONE 2026-06-26; RG1 published 2026-06-27 (re-gate RG2/RG3 Director-pending)

Give the game a surface: boot→Main Menu→walkable Hub (sell+buy Shop)⇄Dive via the persistent root `App` router; P-key
7-tab debug menu (Vision split out). Breakdown + locked decisions: `design/M1_6_Tasks/M1.6_Breakdown.md`. Per-task specs:
`design/M1_6_Tasks/M*.md`. All-off fp byte-identical (e943ac9c8bc1); 89-knob count held; save META v3→v4 (`owned_items`)
+ migration + `meta_v3.sav` fixture. Proof: `STATUS.md` §(archived) M1.6 build waves + `worklogs/2026-06-2{5,6,7}-*`.
- **Wave 1 (M0, `52d6e17`):** persistent root `App` router + 8 EventBus signals + neutral GameState economy surface + quota-decouple + staged-config accessor + `debug_menu_toggle`=P + greybox stubs.
- **Wave 2 (M1∥M2∥M4, `40d328d`):** Main Menu · walkable Hub + `main_game` dive-only refactor + hub-return quota/wipe · P-tab debug menu + Vision split (89-coverage byte-identical).
- **Wave 3 (M3, `f47d8fc`):** Hub Shop sell+buy + 3-item persistent catalog + META v3→v4 + SellScreen retired + quota-MISS notice.
- **Wave 4 (RG1, `aea0bb7` + FB1–FB4 `41106de`):** M1.6 build+verify doc + changelog + itch publish; 4 RG1 playtest-feedback fixes (extract-prompt z-order, quota cumulative basis, on-screen controls list). **RG2/RG3 remain Director-gated** (re-test → verdict in `design/M1_6_Tasks/G4_findings_M1.6.md`).
