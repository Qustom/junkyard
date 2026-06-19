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
