# Design Deviations — History (archive)

Resolved design deviations, moved here from `DESIGN_DEVIATIONS.md` during each wave's close-out
assessment (`CLAUDE.md` → "Wave close-out — deviation assessment"). An entry only lands here **after
the Director has dispositioned it** — Claude assembles and recommends, the Director evaluates. Each
entry is tagged with the Director's verdict:

- **Reviewed** — fine as-is; the design needed no change.
- **Addressed** — the design was changed; the "Reapplied to" note says where the now-canonical
  reality was folded back into the design (or names the new task that was planned).

Append-only. Newest wave at the bottom.

---

## M1 waves 1 & 2 — Director-evaluated 2026-06-17

Every entry below was dispositioned by the Director and reapplied to the design. The two recurring
themes — the specs' **idealized API sketches** and the **headless-test autoload constraint** — are
now canonical in `design/M1_Tasks/M1_As_Built.md` (which supersedes the spec sketches on conflict).
No deviation was a revert; all `Addressed` items were reapplied. The Group-B tuning values
(`engine_block.slot_size=6`, `max_light=60`, `base_max_slots=12`) were accepted as playtest dials
(not reverted), to be retuned at the G4 fun gate / economy workbook.

| # | Deviation | Verdict | Reapplied to |
|---|---|---|---|
| W1-1 | A1/B1/C1 greybox placeholders stubbed inline (no asset-role dispatch) | **Addressed** | `M1_As_Built.md` §Greybox asset norm |
| W1-2 | A1 extracted a pure `step_velocity()` helper for headless testability | **Reviewed** | — (structural; behavior byte-identical) |
| W1-3 | B1 fixed spec's `opposite()` sketch + locked collision-layer map (incl. `pawn`=6) | **Addressed** | `M1_As_Built.md` §Collision-layer map, §Procedural geometry |
| W1-4 | C1 `engine_block.slot_size = 6` (spec sketch showed 4) | **Addressed** | `M1_As_Built.md` §Tuning dials (kept as dial; revisit economy workbook / G4) |
| W2-5 | A3 dive clock reuses `run_started`/`run_ended` — no new `dive_started`/`dive_ended` | **Addressed** | `M1_As_Built.md` §EventBus dive lifecycle contract |
| W2-6 | A3 greybox dive-clock meter built inline (no `ui-ux-designer` dispatch) | **Addressed** | `M1_As_Built.md` §Greybox asset norm |
| W2-7 | A3 tuning: `max_light=60`, fuel model via `modify_light`, transient per-dive clock | **Addressed** | `M1_Design_Decisions.md` #2 + `M1_As_Built.md` §Tuning dials |
| W2-8 | Open follow-up: `Item` vs `JunkItem` schema overlap | **Addressed** | Decision #1 (merge); planned as task **C1b** (in progress) |
| W2-9 | Open follow-up: parallel-dispatch `git switch` collisions in a shared checkout | **Addressed** | Process rule in `CLAUDE.md` (worktree isolation + pre-lock signals) |
| W2-10 | B2 RNG API adaptation (`seed_from` + integer weighted pick; spec's `set_seed`/`weighted_pick`/`fork` don't exist) | **Addressed** | `M1_As_Built.md` §RNG |
| W2-11 | B2 flush-edge socket alignment (vs spec's raw seam formula) | **Addressed** | `M1_As_Built.md` §Procedural geometry |
| W2-12 | B2 connectivity = floor-cell adjacency (true walkability) | **Addressed** | `M1_As_Built.md` §Procedural geometry |
| W2-13 | B2 determinism test runs as a headless scene (autoloads don't resolve under `--script`) | **Addressed** | `M1_As_Built.md` §Testing constraints (revisit at G2) |
| W2-14 | D1 integrated with the REAL GameState (not the spec's `banked_money`/`cash_out` excerpt) | **Addressed** | `M1_As_Built.md` §GameState |
| W2-15 | D1 `max_slots` from authored `InventoryConfig.tres` (`base_max_slots=12`) | **Addressed** | `M1_As_Built.md` §Tuning dials (kept as dial) |
| W2-16 | D1 `RunInventory` emits via SceneTree-resolved EventBus lookup (testability) | **Addressed** | `M1_As_Built.md` §Testing constraints (revisit at G2) |
| W2-17 | D1 added index-safe `remove_at(index)` alongside `remove(item)` | **Reviewed** | — (adopts the D1 spec's own recommendation) |

**New tasks from this assessment:** none beyond existing — W2-8 → **C1b** (on the board, in progress); W2-9 → standing worktree process rule; W2-13/16 "revisit" already scoped under **G2** (vendor GdUnit4).

---

## M1 wave 3 (C1b, E1, D2, B3, C2) — Director-evaluated 2026-06-17

Every entry below was dispositioned by the Director on 2026-06-17 (Claude assembled + recommended; the
Director ruled). **21 Reviewed, 3 Addressed.** The recurring themes are unchanged from waves 1 & 2:
the specs' **idealized API sketches** (now `JunkItem`/`base_sell_value`, real `RNG` surface) and the
**headless-test autoload constraint** (tests run as `.tscn`) — both already canonical in
`M1_As_Built.md`. The new structural fact is the **B3↔C2 seam** (B3 plans, C2 spawns), also folded in.
No Reviewed item was a revert; all 3 Addressed items were reapplied (one as a build change, two as new tasks).

| # | Deviation | Verdict | Reapplied to |
|---|---|---|---|
| W3-1 | C1b folded `Item`'s useful fields into `JunkItem`; retired `Item` | **Reviewed** | `M1_As_Built.md` §Junk schema (executes ratified decision #1) |
| W3-2 | C1b deleted `sample_junk.tres` (not converted) | **Reviewed** | — (curated catalog is the real content) |
| W3-3 | C1b repointed the smoke test's load-as-data step to a real catalog `JunkItem` | **Reviewed** | — (CI guarantee preserved) |
| W3-4 | E1 reused `run_ended`+`haul_banked` instead of a new `run_end(cause,payload)` | **Reviewed** | `M1_As_Built.md` §EventBus / §GameState (tracks decision #6) |
| W3-5 | E1 `banked_junk` persists as ids, rehydrated from catalog (objects-OFF save) | **Reviewed** | `M1_As_Built.md` §Save schema |
| W3-6 | E1 real signature `save_meta(slot)`; `extract_and_end_run()` hardcodes slot 0 | **Reviewed** | `M1_As_Built.md` §GameState (slot-routing is a later follow-up) |
| W3-7 | E1 meta schema bump 1→2 with no QA migration fixture yet | **Addressed** | New task **G5** (v1→v2 meta save-migration fixture) + `M1_As_Built.md` §Save schema |
| W3-8 | D2 panel also listens to `run_started`/`run_ended` (start builds / end clears the bag) | **Reviewed** | — (still pure-projection / EventBus-only) |
| W3-9 | D2 drop gesture is right-click only (spec allowed right-click or hold-to-drop) | **Reviewed** | — (deliberate gesture; hold-to-drop deferrable) |
| W3-10 | D2 cell rebuild uses `queue_free()`+hide vs synchronous `free()` | **Reviewed** | — (engine-correctness; rebuild can fire from a cell's own signal) |
| W3-11 | D2 added a "No active dive" idle state for `run_inventory == null` | **Reviewed** | — (additive; needed for an always-on HUD) |
| W3-12 | D2 authored no `theme.tres` (spec marked it optional) | **Reviewed** | — (per-cell overrides sufficed; deferred to human visual pass) |
| W3-13 | D2 committed generated `inventory_strings.en.translation` (binary build product) | **Addressed** | Gitignored `*.translation` + untracked the file; regenerated from `.csv` on import (verified). `.gitignore` updated |
| W3-14 | B3 used a local `RandomNumberGenerator` sub-stream (no `RNG.fork`); autoload RNG untouched | **Reviewed** | `M1_As_Built.md` §RNG (deterministic sub-streams — canonical pattern) |
| W3-15 | B3 consumed `JunkItem`/`base_sell_value` from catalog (no `junk_pool.tres`) | **Reviewed** | `M1_As_Built.md` §Junk schema |
| W3-16 | B3 produces a placement *plan* + debug overlay only; added only `junk_spawned` | **Reviewed** | `M1_As_Built.md` §B3↔C2 seam |
| W3-17 | B3 acceptance test runs as `.tscn` (needs autoloads) | **Reviewed** | `M1_As_Built.md` §Testing constraints (revisit at G2) |
| W3-18 | B3 real reverse-BFS return distance; curves near-linear value / stepped tier / flat density | **Reviewed** | `M1_As_Built.md` §Junk schema (depth axis) |
| W3-19 | C2 `JunkSpawner` is a pure consumer of B3's plan (no own weighting / no `RNG.stream`) | **Reviewed** | `M1_As_Built.md` §B3↔C2 seam |
| W3-20 | C2 spawner invoked directly after generation, not via a signal | **Reviewed** | — (per spec recommendation: hard ordering + data dependency) |
| W3-21 | C2 `junk_picked_up(...,slot_size,...)` + `band_populated` + `junk_dropped` signals | **Reviewed** | `M1_As_Built.md` §EventBus (Telemetry watch-list confirm = G1 scope) |
| W3-22 | C2 `base_sell_value` + reject UX keyed off the same `can_accept()`/`is_full()` D2 reads | **Reviewed** | `M1_As_Built.md` §B3↔C2 seam |
| W3-23 | C2 acceptance test runs as `.tscn` (needs autoloads) | **Reviewed** | `M1_As_Built.md` §Testing constraints (revisit at G2) |
| W3-24 | C2 drop-to-swap re-spawn wired on spawner side but dormant until D2 emits `junk_dropped` | **Addressed** | New task **D3** (D2 emits `junk_dropped` to activate it) |

**New tasks from this assessment:** **G5** (W3-7, meta save-migration fixture) and **D3** (W3-24, activate
drop-to-swap re-spawn) — both added to `TASKS.md` and the GitHub Projects board (Todo). W3-13 was actioned
directly (translation gitignored). W3-6 slot-routing and W3-21 Telemetry watch-list fold into later tasks
(save/slot layer; **G1**).

---

## M1 wave 4 — Director-evaluated (partial: E3 pockets dispositioned 2026-06-18)

The wave-4 close-out is **in progress** — the Director dispositioned the one substantive design call
(E3 pockets) on 2026-06-18; the remaining wave-4 reconciliation-class deviations are still under
Director review in `DESIGN_DEVIATIONS.md` and will be archived here once verdicts land.

| # | Deviation | Verdict | Reapplied to |
|---|---|---|---|
| W4-1 | E3 pockets-on-fail: `0.15` value-fraction-credited-to-Money → **`0.20` whole-items-banked-to `banked_junk`** (death & extract converge on the run→meta transfer; fail keeps a subset). Data-driven in `run_rules.tres`. | **Addressed** | Ratified as **decision #13** (`M1_Design_Decisions.md`); `M1_As_Built.md` §GameState (death/timeout) + §Tuning dials; GDD §6 (whole-item pockets clarified). Old `_on_player_died` value-fraction + `POCKETS_FRACTION=0.15` retired. 0.20 stays a G4 sweep dial (0.15–0.25). |
| W4-2 | E3 added a `_run_ended: bool` idempotency guard (extract wins a same-frame tie) | **Reviewed** | — (minimal correct impl of E3 Open-q #122; `M1_As_Built.md` §GameState notes the guard) |
| W4-3 | E3 failed-run `value_lost`/`items_kept` ride on `haul_banked` + print (not on fixed-arity `run_ended`) | **Reviewed** | `M1_As_Built.md` §Telemetry seam — **G1** adds the dedicated row; `run_ended` signature stays locked |
| W4-4 | E2 built against the real EventBus/GameState contract (not the spec's idealized signal names) | **Reviewed** | `M1_As_Built.md` §UI/HUD (E2 decision HUD) |
| W4-5 | E2 DecisionHUD drives its own clock ProgressBar (green→amber→red) vs embedding A3's white/red meter | **Reviewed** | `M1_As_Built.md` §UI/HUD (dials `urgency_fraction=0.25`, `pulse_speed=6.0` for G4) |
| W4-6 | D3 resolved drop position to the player's `global_position` (panel walks `current_scene` for `Player`) | **Reviewed** (closes already-Addressed W3-24) | `M1_As_Built.md` §UI/HUD (drop-to-swap) — **G3** follow-up: player `"player"` group |
| W4-7 | G5 v1→v2 meta migration fixture + CI; per-bump template; `*.sav -text` | **Reviewed** (closes already-Addressed W3-7) | `M1_As_Built.md` §Save schema (follow-up marked done + template) |
| W4-8 | F1 shipped smaller than spec — schema/migration/`money` already existed; only added `sell_banked_junk` (reused `add_currency`/`currency_changed`, no new signal) | **Reviewed** | `M1_As_Built.md` §GameState (`sell_banked_junk`) |
| W4-9 | F2 listens to real `run_ended` (not spec's `run_end(cause, payload)`) | **Reviewed** | `M1_As_Built.md` §UI/HUD (sell screen) |
| W4-10 | F2 presents on all three run-end causes ("EXTRACTED" / "RUN LOST — kept N"), source-tagged sell vs pockets | **Reviewed** (ratified) | `M1_As_Built.md` §UI/HUD (sell screen) |
| W4-11 | F2 count-up = manual `_process` lerp on `PROCESS_MODE_ALWAYS` (Godot paused-tree tween bug #81994); Continue emits `continue_pressed` only; +1 `project.godot` translation line | **Reviewed** | `M1_As_Built.md` §UI/HUD (`continue_pressed` seam → **G3** wires `start_new_run()`) |

**Wave-4 close-out complete (2026-06-18).** 11 deviations dispositioned: **1 Addressed** (W4-1, E3 pockets → decision #13), **10 Reviewed**. W4-6 and W4-7 also closed the two wave-3 `Addressed` follow-ups (D3↔W3-24, G5↔W3-7). All reapplied to `M1_As_Built.md` (new §UI/HUD & loop wiring) / `M1_Design_Decisions.md` / GDD §6. Carried into the G-series: **G1** telemetry amount-lost row (W4-3); **G3** wires `continue_pressed`→`start_new_run()` and adds the player `"player"` group (W4-6, W4-11).

---

## M1 wave 5 (G-series) — Director-evaluated 2026-06-18

The final M1 build wave: **G1** (telemetry JSONL), **G2** (GdUnit4 vendored + logic tests), **G3** (full-loop
greybox build / first playable assembly), **G6** (in-build first-run telemetry consent prompt, itself the
disposition of G3 #1). 16 deviation entries: **1 Addressed** (G3 #1 → built G6), **15 Reviewed**. The two
recurring themes from earlier waves recur once more — the specs' **idealized API sketches** and the
**headless-test autoload constraint** — both already canonical in `M1_As_Built.md` (which supersedes the spec
sketches on conflict). The new canonical **§Telemetry (G1/G6)** section in `M1_As_Built.md` is the consolidated
reapply target for the telemetry-shape entries.

| # | Deviation | Verdict | Reapplied to |
|---|---|---|---|
| W5-G1-1 | No `Settings` autoload / `telemetry_toggled` signal — opt-in is a static `Settings` (RefCounted) over `ConfigFile`, applied via `Telemetry.set_enabled()` | **Reviewed** | `M1_As_Built.md` §Telemetry (opt-in / consent) |
| W5-G1-2 | Opt-in flag persisted in `user://settings.cfg`, **not** the SaveManager meta schema (acceptance criterion said "via SaveManager") | **Reviewed** (Director call 2026-06-18: keep ConfigFile — a UI consent pref is profile config, not gameplay meta-state; no schema bump) | `M1_As_Built.md` §Telemetry (opt-in / consent) |
| W5-G1-3 | `run_started` row logs `band_id`+`seed`, not `tier_label` (no tier field in M1; tier is a G4 analysis-time bucket from `duration_s`) | **Reviewed** | `M1_As_Built.md` §Telemetry |
| W5-G1-4 | `run_id` derived in Telemetry as `r_<hex(seed)>`, not owned by GameState (brief forbade editing `game_state.gd`) | **Reviewed** (revisit at G4 if seed-reuse collisions matter) | `M1_As_Built.md` §Telemetry |
| W5-G1-5 | Log path is `user://telemetry/run_log.jsonl` (supersedes old `events.jsonl`) | **Reviewed** | `M1_As_Built.md` §Telemetry + **Playbook 07** prose fixed `events.jsonl`→`run_log.jsonl` |
| W5-G2-1 | Tests written against the real as-built surface — the spec's `LayoutGen.generate` / `Inventory.new(cap)` / `Economy.bank/sell/CURRENCY_RATE` / `DeathDrop.resolve` APIs don't exist | **Reviewed** | (no doc change — `M1_As_Built.md` already canonical over spec sketches) |
| W5-G2-2 | Tests assert ratified pockets `0.20` whole-item `HIGHEST_VALUE`, not the spec open-q's stale `0.0` | **Reviewed** | (matches decision #13; no change) |
| W5-G2-3 | `test_jsonl_writer` deferred (G1's `JsonlWriter` was on a parallel branch) | **Reviewed** | Tracked as **FU1** (`TASKS.md` §M1 follow-ups + board): fold a GdUnit4 `test_jsonl_writer` in now that both are on `main` |
| W5-G2-4 | GdUnit4 **v6.1.3** vendored at `addons/gdUnit4/`; headless runner needs `--ignoreHeadlessMode` (in `tools/run_gdunit.sh` + CI) | **Reviewed** | `M1_As_Built.md` §Telemetry note + **Playbook 07** (framework/runner) |
| W5-G2-5 | Economy suites snapshot/restore global meta around each test rather than a pure `EconomyMath` helper (avoided editing `game_state.gd` mid-wave) | **Reviewed** | Tracked as **FU2** (`TASKS.md` §M1 follow-ups + board, optional): static `EconomyMath` helper for autoload-free economy math |
| W5-G3-1 | No in-build first-run telemetry **consent prompt** (G3 shipped README + the G1 settings toggle only) | **Addressed** | **Built G6** (in-build Enable/Not-now first-run modal, default OFF, show-once); `M1_As_Built.md` §Telemetry (opt-in / consent). New task G6 added to `TASKS.md` + board, completed 2026-06-18 |
| W5-G3-2 | Per-run seed minted locally in MainGame (`time*31 + run_count*const`); M1 has no meta seed/run-counter system | **Reviewed** | (M1 scope; a real meta layer owns seed policy post-M1) |
| W5-G3-3 | MainGame calls `enter_band(BAND_ID)` once after `start_run` so the HUD reads "Depth 1" in M1's single band | **Reviewed** | (M1 ships one band; multi-band descent is post-M1) |
| W5-G3-4 | Additive `build` field (`m1-<date>-<sha>`, via new `systems/version.gd`) on the telemetry `run_started` data dict; schema envelope unchanged (not a bump) | **Reviewed** | `M1_As_Built.md` §Telemetry (build field documented) |
| W5-G3-5 | Publish pipeline human-gated (a flag, not a design change): `nightly.yml` scaffolds the Butler/itch publish but can't run until a human provisions `BUTLER_API_KEY` + a studio itch project/slug (publish steps skip when the secret is absent); Win64 export needs templates. Also un-ignored `export_presets.cfg` in `.gitignore` so the preset commits (Godot ignores it by default; no per-machine paths). | **Reviewed** | (correctly human-gated per brief — producer/human action item; preset committed) |
| W5-G6-1 | Consent "asked" flag persisted in `user://settings.cfg` via `Settings` (not SaveManager meta), consistent with the ratified G1 #2 | **Reviewed** | `M1_As_Built.md` §Telemetry (opt-in / consent) |

**Wave-5 close-out complete (2026-06-18).** 16 deviations dispositioned: **1 Addressed** (G3 #1 → built G6,
the in-build consent prompt), **15 Reviewed**. All reapplied to `M1_As_Built.md` (new **§Telemetry (G1/G6)** +
scope line bumped to wave 5) and **Playbook 07** (`events.jsonl`→`run_log.jsonl`, GdUnit4 runner note). Two
optional backlog follow-ups noted (GdUnit4 `test_jsonl_writer`; static `EconomyMath` helper). `DESIGN_DEVIATIONS.md`
is now empty. **All M1 build work is complete (A–G + G6); only G4 — the human fun-gate playtest — remains.**

---

## M1.1 (Greybox Cost Axis) Wave 1 — Director-evaluated 2026-06-19

All six wave-1 task agents (R0, BUG1, BUG2, TEL, BUG3, CFG) reported **"none"** against their ratified specs —
the implementations matched the designs. The two entries below are **orchestrator-level departures from the M1.1
plan docs** (the breakdown's wave structure and TEL's signal-ownership decision), assembled by Claude and
dispositioned by the Director.

| # | Deviation | Verdict | Reapplied to |
|---|---|---|---|
| W1.1-1 | Orchestrator pre-declared `depth_changed` on `main` (`2450cde`) before TEL ran, instead of TEL declaring it (TEL spec §8 Decision 3) — BUG1+BUG2 emit it and landed first, so it had to exist to compile. One declaration, one `event_bus.gd` author, no collision; TEL skipped re-declaring (verified `grep -c` == 1). | **Reviewed** | `TEL_telemetry_config_marking.md` §4 "Ownership of `depth_changed`" — added an as-built note + the standing convention: the orchestrator owns pre-declaring shared *foundation* signals when an emitter must land before the nominal declaring task. |
| W1.1-2 | `M1.1_Breakdown.md` §6 claimed CFG/TEL/BUG3 were file-disjoint (3 parallel worktrees), but CFG and BUG3 both edit `scenes/game/main_game.gd` (CFG's `start_new_run` stage seam; BUG3's `_materialise_band` seal call). Orchestrator ran **TEL ∥ BUG3, then CFG** sequentially — all green. | **Addressed** (doc-only) | `M1.1_Breakdown.md` §6 wave-1 bullet corrected: CFG also edits `main_game.gd:start_new_run`; the single-writer-per-`.gd`-file rule (already enforced for `event_bus.gd`) extends to `main_game.gd`. No code change — execution was correct. |

**Wave 1 close-out complete (2026-06-19).** 2 deviations dispositioned: **1 Addressed** (W1.1-2, breakdown §6 doc
fix), **1 Reviewed** (W1.1-1). Both reapplied as noted. `DESIGN_DEVIATIONS.md` is now empty (between waves).
**M1.1 Wave 1 (Foundations) is complete** — R0 + BUG1 + BUG2 + TEL + BUG3 + CFG on `main`; the `RunConfig` model,
pre-run Config menu, config-marked telemetry + 11 pre-declared opposition signals, real `duration_s` + within-band
depth, and a sealed band are all in place. **Next: Wave 2 — the four oppositions (R1–R4) in parallel worktrees.**

---

## M1.1 (Greybox Cost Axis) Wave 2 — Director-evaluated 2026-06-19

R1, R2, R3 reported **"none"** against their specs. R4 surfaced one residual-gap finding (exactly as R4 §6 predicted),
dispositioned by the Director.

| # | Deviation | Verdict | Reapplied to |
|---|---|---|---|
| W2-R4-1 | R4's deep branching surfaced a residual BUG3 seal gap: at `r4_branch_per_depth ≳ 0.12` some seeds leave 2–6 floor cells facing off-map void after `SocketSealer` (which caps only `band.open_sockets`, missing branchy socket-opening edges). Recommended presets S1/S3 seal cleanly (0 leaks/9 seeds), so the realistic envelope is fine; gap appears past ~2× the recommended branch rate. | **Addressed** | Filed **BUG4** (`TASKS.md` M1.1 follow-ups + board, Todo): cap all outward-facing perimeter floor edges, branch-rate-independent. As-built safe-envelope note + BUG4 ref added to `R4_maze_navigation.md` §6. Non-blocking for Wave 3 (recommended presets clean). |

**Wave 2 close-out complete (2026-06-19).** 1 deviation dispositioned: **1 Addressed** (W2-R4-1 → BUG4 follow-up).
Reapplied to `R4_maze_navigation.md` §6; BUG4 tracked. `DESIGN_DEVIATIONS.md` is now empty (between waves).
**M1.1 Wave 2 (the four oppositions R1–R4) is complete** — the depth-scaled cost axis is built, configurable, and
telemetried. **Next: Wave 3 — re-gate** (RG1 build + wire R2/R3 nodes → human playtest → RG2 analysis → RG3 verdict).

---

## M1.2 Wave 1 (Spatial & data foundation) — Director-evaluated 2026-06-19

I1 surfaced 2 deviations (BUG4 and I5 reported **"none"**). Two M1.1 Wave-3/RG1 entries that had lingered un-dispositioned
in the active file (the M1.1 re-gate went straight to ITERATE → M1.2) were also cleared in this sweep. All four assembled
by Claude, dispositioned by the Director.

| # | Deviation | Verdict | Reapplied to |
|---|---|---|---|
| I1-1 | New larger greybox pieces authored inside the I1 programmer task rather than a separate `environment-artist` dispatch — for worktree atomicity (the pieces feed a determinism-sensitive config-dependent catalog seam). Greybox geometry+sockets only, B1-compliant. | **Reviewed** | Process-only, no design change. One-worklog-per-task contract satisfied (process note in `worklogs/2026-06-19-I1-general-purpose.md`). |
| I1-2 | `piece_hall_v` authored 4 cells wide (interior 2), not the spec's *illustrative* 6×16 — a 6-wide hall's 4-cell N/S perimeter opening exceeds the `width_cells=2` socket and leaks 2 floor cells past the seal (caught by `test_level_scale_determinism` seeds 7 & 1000003). 4-wide gives a true 2-cell opening that seals clean. | **Reviewed** (+ doc note) | Folded the rule **"socket width must equal the perimeter opening width"** into `M1_As_Built.md` §"Procedural geometry (B1 ↔ B2)". |
| W3-RG1-1 | `ReturnCost.dive_clock` injected in `main_game.gd:_ready()` instead of a `.tscn` NodePath export (typed-node export across instanced sub-scenes resolved `null` — known Godot quirk; code-assign is behaviour-identical, the spec's allowed alternative seam). | **Reviewed** | Behaviour-identical idiom; no design change. |
| W3-RG1-2 | `RunConfig.to_flat_dict()` / CFG coverage stated as a magic count ("32 keys") in `RG1`/`CFG` prose; the verify driver asserts the key *set* generically, and I1 raised the count to 35. | **Reviewed** (doc fix) | Corrected the magic-count prose in `RG1_playtest_build.md` (V13 + Decision rationale) and `CFG_config_menu.md` (×2) to set-based language (32→35, count not load-bearing). |

**M1.2 Wave 1 close-out complete (2026-06-19).** 4 deviations dispositioned: **all 4 Reviewed**. 2 reapplied as doc edits
(I1-2 → `M1_As_Built.md`; W3-RG1-2 → `RG1`/`CFG` prose); I1-1 and W3-RG1-1 are process/idiom-only. `DESIGN_DEVIATIONS.md`
is now empty (between waves). **M1.2 Wave 1 (spatial & data foundation) is complete** — configurable level scale (count +
size mult + new larger greybox pieces behind a config-dependent catalog), branch-rate-independent geometry-keyed seal, and
telemetry hygiene (real `duration_s` regression-lock + real build SHA) are on `main`; all-off default still byte-matches the
M1.1 baseline (fp=e943ac9c8bc1). **Next: Wave 2 — oppositions retuned to the new canvas** (I2 hazard ∥ I4 vision ∥ I3
cues; watch the I2/I4 `main_game.gd` single-writer collision).

---

## M1.2 Wave 2 (Oppositions retuned to the new canvas) — Director-evaluated 2026-06-19

I2, I3, I4 all reported **"none"** against their locked specs (built to spec + Director disposition). **0 formal deviations.**
The wave produced **one substantive finding** (not a spec deviation) — assembled by Claude, dispositioned by the Director:

| # | Finding | Verdict | Action |
|---|---|---|---|
| W2.2-F1 | I3's cue work made a latent **R2↔R3 integration gap** visible: `return_cost.gd`'s `TOLL_EXPOSURE` branch calls `meter.call(&"add", cost)`, but `exposure_meter.gd` has only read-only getters (no `add()`), so the `exposure` toll resource fires its cue + `return_cost_incurred` telemetry but **never moves the meter** — a player sees a toll that does nothing. Latent since M1.1 (R2/R3 built in parallel); not a deviation from any M1.2 task's spec. | **Fix now** | New task **BUG5** filed (`TASKS.md` + board, In Progress): add a public `exposure_meter.add(amount)` that routes through the same threshold-crossing/penalty logic as accrual. Spec: `design/M1_2_Tasks/BUG5_exposure_toll_mutator.md`. Land before the Wave 3 re-gate so the exposure-toll sweep is functional. |

**Non-deviation forward notes (recorded, no action):** I2 — a labelled sweep-default `.tres` for first-sweep values is a
later game-director-designer content task (knobs are live + swept from CFG today). I4 — if an *active* hazard telegraph
should read at full contrast at the bubble rim, it sorts `z_index > 100` on the hazard side (no I4 change).

**M1.2 Wave 2 close-out complete (2026-06-19).** 0 deviations; 1 finding → **BUG5** (Director: fix now). `DESIGN_DEVIATIONS.md`
stays empty (the finding is tracked as a task, not a pending deviation). **M1.2 Wave 2 (hazard refuge + vision/fog occlusion +
R2/R3 cues) is complete** on `main`; all-off baseline byte-unchanged (fp=e943ac9c8bc1). **Next: BUG5, then Wave 3 — the
re-gate** (RG1 build + verify → human playtest → RG2 analysis vs M1.0/M1.1 → RG3 verdict).

---

## M1.3 Wave 1 (Foundation & correctness) — Director-evaluated 2026-06-19

All 5 Wave-1 tasks (J5, BUG6, DLV2, DLV1, J1) integrated on `main`, all-off fp byte-identical (e943ac9c8bc1). Close-out sweep:

| # | Item | Verdict | Reapplied to |
|---|---|---|---|
| W1.3-1 | DLV2 used the built-in `JavaScriptBridge.download_buffer` instead of the spec's hand-rolled Blob+`<a>` shim (behaviour-identical, manages JS object lifetime, more robust; still fires from the button user-gesture). | **Reviewed** | No change — DLV2 doc note; the built-in is the better idiom. |
| W1.3-2 | Orchestrator dropped "J1 pre-declares J2/J3 knobs" — the Phase-3 resolvers made Wave 2 **sequential** (J2→J3→J4), so each task adds its own `run_config.gd` knobs (no parallel collision); J1 stayed focused on the preset+slider+CFG warn-line. | **Reviewed** | Build-org refinement; folded into the J2/J3/J4 build briefs (each owns + wires its own knobs into the preset). |
| W1.3-3 | J1's preset turned R4 **vision/fog/lost ON** (literal F1 "vision/maze ON"), but the actual most-fun M1.2 cell had R4 = maze ON, vision/fog/lost **trapped OFF** — i.e. the Director loved the maze *without* real occlusion. | **Addressed** | Director call "match what I played — occlusion off": preset now mirrors the played cell (R4 maze ON, vision/fog/lost OFF, only `r1_catch_radius` floored 23.3→24.0); BUG6's two R4 sub-traps merged into one **maze-aware `r4_no_effect`** (fires only when R4 is fully inert) so the deliberate maze-only default isn't nagged. Reapplied to `run_config.gd` + `test_run_config.gd` + `config_strings.csv` (commit `25072f6`). |

**Non-deviation notes (tracked, not dispositions):** DLV1's real `butler push` is **human-gated** (sandbox can't reach `broth.itch.ovh`) — run `tools/push_itch.sh` once on a real network per `SETUP.md §1a`. J1's **live mult-40 window pass** ("void feel" at 640 px/cell) → on the RG1 playtest checklist (headless smoke passed).

**M1.3 Wave 1 close-out complete (2026-06-19).** 3 items: **2 Reviewed, 1 Addressed** (the preset/trap reapply). `DESIGN_DEVIATIONS.md` empty between waves. **M1.3 Wave 1 (default preset + size slider, depth-counter fix, hazard latch + warn-only traps, itch HTML5 delivery + web telemetry export) is complete** on `main`. **Next: Wave 2 — J2→J3→J4 (density & spatial), then re-gate.**

---

## M1.3 Wave 2 (Density & spatial) — Director-evaluated 2026-06-20

All 3 Wave-2 tasks (J2 enemy spread, J3 per-room density, J4 corridor lever + telemetry) integrated on `main`
(`4140d9f`, `4d54487`, `200f38c`; signal pre-decl `12e8932`); all-off fp byte-identical (e943ac9c8bc1); 46/46 knobs; schema v1. Close-out sweep:

| # | Item | Verdict | Reapplied to |
|---|---|---|---|
| W2.3-1 | J2 `curve` distribution mode (2) ships the locked `pow(t,1.6)`, which is **shallow-biased** (`pow(t,1.6) ≤ t` for t∈[0,1]) — it thins hazards toward the deep end, opposite the "clusters deep" intent. Built but **preset-OFF** (booted preset = `even_spread`), so nothing measured changes this gate; `test_hazard_spread.gd` is locked to the real behaviour. | **Reviewed** | As-built note appended to `J2_enemy_spread.md` (Director-Reviewed: leave as-is; flip the exponent + fix the comment only if `curve` is swept ON at RG2). |

**Non-deviation notes (tracked, not dispositions):**
- **J3 Q-F wake-cadence observation:** density hazards seeded in deep big rooms may wake immediately (per-hazard R1 depth gate) → deep big rooms could read instant-death. Not a J3 change — an **R1 `r1_depth_threshold`/`r1_linger_seconds` preset-tuning** call for the RG1 playtest. On the RG1 checklist.
- **Preset-value fun calls (RG2 sweeps, not deviations):** J2 count(5)/min-depth(1)/curve-on?, J3 density(1.0)/cap(3)/min-area(64)/metric(cell-area)/loot-off, J4 `lvl_corridor_weight_mult`(0.5)/`lvl_short_corridors`(true) — all Director sweeps against the new room scale at RG2, not values this build fixes.

**M1.3 Wave 2 close-out complete (2026-06-20).** 1 deviation: **Reviewed** (J2 curve as-built note). `DESIGN_DEVIATIONS.md` empty between waves. **M1.3 Wave 2 (enemy depth-spread + per-room cell-area density + corridor-rarity generator lever & corridor-time telemetry) is complete** on `main`; baseline byte-unchanged. **Next: Wave 3 — the re-gate** (RG1 build+verify + itch publish → human playtest → RG2 analysis vs M1.0/M1.1/M1.2 → RG3 verdict in `G4_findings_M1.3.md`).

---

## M1.4 Wave 1 close-out (2026-06-21) — Director dispositioned

3 deviations, all dispositioned by the Director at the Wave-1 close-out:

- **K0 — quota-enum knob count (doc vs as-built) → REVIEWED.** The K0 design doc's RD-1/RD-6 dropped the two quota
  behaviour enums (→79); the Breakdown Phase-4 Lock KEPT them (Director wants quota configurable) → as-built **81**.
  Reapply: the canonical count lives in `M1.4_Breakdown.md` §"Phase 3 Dispositions & Phase 4 Lock", which already
  states 81; the K0 doc's internal RD arithmetic is superseded by the Lock. No code change (build is correct).
- **K3/K6 — render-time behaviour not headless-verifiable → REVIEWED.** Jitter-gone + fixed-FOV look can't be proven
  in `--headless`; verified green at the code/determinism level (fp `e943ac9c8bc1`, smoke, `test_camera_view`/
  `test_dive_clock`). Reapply: folded into the M1.4 RG1 verify matrix as an explicit "confirm on a >60Hz monitor/
  browser" item. Not a design change.
- **K3 — resolution-independent camera shipped opt-in → ADDRESSED.** The preset didn't enable the fixed camera, so the
  default playtest wouldn't exercise it. Director: enable it in the preset. Reapply (DONE): `make_default_play_preset()`
  now sets `cam_enabled=true`, `cam_visible_world_width=576.0` (= today's horizontal FOV, now resolution-invariant),
  `cam_zoom_policy=0` (fit_width). Verified: smoke OK, all-off fp `e943ac9c8bc1` unchanged (cam_* never feed fingerprint).

**M1.4 Wave 1 close-out complete.** `DESIGN_DEVIATIONS.md` empty between waves. **Next: Wave 2 — K2 (quota + roguelite
wipe + save-schema v2→v3) → K7 (exit placement),** then Wave 3 (3 new hazards) → Wave 4 (re-gate). *Build PAUSED after
Wave 1 at the Director's request (2026-06-21) — resume by dispatching K2.*

---

## M1.4 Wave 2 close-out (2026-06-21) — Director dispositioned

**0 deviations.** K2 (quota + roguelite wipe, save v2→v3) and K7 (exit placement) both reported "none" — the as-built
K0 API matched each design's Phase-3-reconciled contract (quota signals/knobs and exit knobs/signal all pre-existed
with the locked names). K7's DR-3/DR-4/DR-7 Director flags were settled at the Phase-4 lock (preset ships exits OFF).
Nothing to disposition. `DESIGN_DEVIATIONS.md` empty between waves.

## M1.4 Wave 3 close-out (2026-06-21) — Director dispositioned

1 deviation, dispositioned by the Director:

- **W3-F1 — K5b bomb test `queue_free`-on-freed-instance stderr noise → ADDRESSED.** `tests/test_bomb_hazard.gd`
  (cases 1/2/3) called `bomb.queue_free()` in cleanup, but `BombHazard` self-frees on detonation — so a detonated bomb
  was already freed, emitting 3 non-fatal `SCRIPT ERROR: Cannot call method 'queue_free' on a previously freed instance`
  lines on stderr. The test still passed (`BOMB HAZARD OK`, exit 0); only cleanup was noisy. Risk: a "green" test emitting
  `SCRIPT ERROR` would false-trip a future CI gate that greps stderr for errors (cf. the carried plan to wire test scenes
  into the CI set). Director: **fix now.** Reapply (DONE): guarded all three cleanup frees with
  `if is_instance_valid(bomb): bomb.queue_free()`. Test-only, no production change. Verified: `test_bomb_hazard` now runs
  clean (`BOMB HAZARD OK`, exit 0, **zero SCRIPT ERROR lines**).

**Deferred (NOT deviations — RG1 sweep/Director-taste calls, no action now):** `NEW_HAZARD_BAND_CEILING=48` value;
OQ-4 pure-deterministic vs local-sub-stream hazard striping; K7 preset `exit_keep_one_at_spawn`/`exit_enabled` (ship OFF);
the worst-case ~112-body (R1 64 + new 48) headless tick-time check → RG1 verify checklist.

**M1.4 Waves 2 & 3 close-out complete.** `DESIGN_DEVIATIONS.md` empty between waves. **Next: Wave 4 — the re-gate (RG1
build+verify → Director playtest → RG2 → RG3).** *Build HELD after Wave 3 at the Director's request (2026-06-21) — resume
by dispatching RG1 on the Director's go.*

---

## M1.4 Wave 5 close-out (2026-06-24) — Director dispositioned (at the M1.5 re-gate)

Three items, dispositioned by the Director alongside the RG3 verdict (ITERATE → M1.5):

- **RG1-F1 — K5 hazard sweep-start magnitudes in `make_default_play_preset()` → REVIEWED.** The build agent chose modest
  starts (each `base_count` low, `count_per_depth=0.15`, `per_room_cap=2`) so all three new hazards spawn ≈9/9/9 under the
  shared `NEW_HAZARD_BAND_CEILING=48` rather than letting pingpong starve spikes. The load-bearing constraint ("every
  enabled hazard type must actually spawn in the shipped default") held; all-off fp unmoved (`e943ac9c8bc1`); 81 knobs.
  Director: **Reviewed** — a magnitude call explicitly delegated to RG1; no design-doc change (the breakdown already says
  magnitudes are RG1 sweeps). No reapply needed.

- **TUNE2 `_driven_default_preset()` — verify driver disables the 3 K5 hazards for its scripted end-cause matrix → ADDRESSED.**
  The TUNE2 fix added a driver-only preset variant that turns the K5 hazards off, because shallow spikes kill the
  driven player before the scripted extract/timeout/death matrix can run — there was no per-hazard `*_kills` toggle (R1 has
  `r1_catch_kills`; the K5 family did not). Director: **Addressed** — add `*_kills` toggles to the K5 family so the driver
  can exercise the *real* preset with kills off. Larger than an edit → **planned as a new task: M1.5 `L5` (K5 per-hazard
  `*_kills` toggles)**, with the three knobs (`hpp_kills`, `hbomb_kills`, `hspike_kills`, default `true` = today's lethal
  behaviour) pre-declared in M1.5 `L0`. Reapply lands when L5/L0 build; `_driven_default_preset()` is retired then.

- **Stale `.tscn` UID drift (11 files set aside) → REVIEWED / no action.** Disposition was "drop the stash," but
  `git stash list` is empty in the current clone (the set-aside churn is no longer present) and HEAD builds/tests clean
  (`--import` does not reproduce the UID regen). Nothing to drop; no design impact. Closed.

**Board back-fill (separate from the deviation sweep):** Director: **DO back-fill.** The ~20 missing M1.2–M1.4 GitHub
Project items (never added despite STATUS marking them board=Done) are to be created (marked Done), plus the M1.5 items —
dispatched to `producer`.

**M1.4 Wave 5 close-out complete.** `DESIGN_DEVIATIONS.md` empty between waves. **Next: M1.5 Phase 2 — per-task design
fan-out (L0–L5).**

## M1.5 Wave 1 close-out (2026-06-24) — Director dispositioned

1 deviation, dispositioned by the Director:

- **L0-F1 — M1.5 final knob count is 89, not the breakdown's stated 88 → REVIEWED.** 81 + 8 = 89; the Phase-4 lock's
  "final 88" was an orchestrator arithmetic slip. L0 declared exactly the locked knob SET (names/types/defaults) + all 4
  signals; only the sum digit was wrong. Director: **Reviewed** — a derived-count typo, not a design change. Reapply
  (DONE): corrected 88→89 in the breakdown lock, `TASKS.md`, `STATUS.md`; knob-count tests assert 89 (`test_run_config`
  R0 OK / `test_config_menu` 89/89); all-off fp unmoved (`e943ac9c8bc1`).

**M1.5 Wave 1 close-out complete.** `DESIGN_DEVIATIONS.md` empty between waves. **Next: Wave 2 — L1 → L2 sequenced
(both write `main_game.gd`) + L5 parallel.**

## M1.5 Wave 2 close-out (2026-06-24) — Director dispositioned

1 deviation, dispositioned by the Director:

- **L1-F1 — throw telemetry `run_t_ms` uses `Time.get_ticks_msec()`, not a run-elapsed base → REVIEWED.** The L0/L1
  contract declares the throw signals with a `run_t_ms: int` field; `GameState` exposes no public run-elapsed accessor
  (`_elapsed_s()` is private) and `game_state.gd` was outside L1's single-writer touch set, so L1 stamped
  `item_thrown`/`throw_missed`/`throw_killed_hazard` with the monotonic `Time.get_ticks_msec()` (shared between
  `main_game` and the projectile). RG2's use of these rows is in-run ordering, which a monotonic clock preserves;
  all-off fp unmoved (`e943ac9c8bc1`), tests green. Director: **Reviewed** — low-risk telemetry detail, no contract/arity
  change. No reapply needed (no design change). If a true run-elapsed base is later wanted, file a small follow-up to
  expose `GameState.run_elapsed_ms()` and switch the three stamps.

**M1.5 Wave 2 close-out complete.** `DESIGN_DEVIATIONS.md` empty between waves. **Next: Wave 3 — RG1 build + verify +
itch publish + changelog.**

---

## M1.6 Wave 2 close-out (2026-06-26) — 3 items, all **Reviewed** (Director dispositioned)

- **W2-F1 — `test_rg1_m13_verify` stale/broken (pre-existing).** Fails (exit 1) on M5/all-on opposition-telemetry rows +
  `timeout` end-cause; **verified it fails identically at the pre-Wave-2 commit `536c9ba`** (M0-era, before M2's `main_game`
  refactor), so NOT M1.6 regression. m13 last green at M1.3 (`d9138c7`), not in the CI gate, never maintained through
  M1.4/M1.5. The 4 sibling RG verifies pass with M2's identical staged-config plumbing. Director: **Reviewed** — pre-existing
  tech debt. **Reapply:** filed `FU3` (qa: repair-or-retire m13) in `TASKS.md` backlog. Non-blocking for M1.6.
- **W2-F2 — quota-MISS has no player-facing "QUOTA MISSED" banner yet.** M2 ships the integrity wipe routing (quota eval +
  `wipe_meta()` on the Hub-return beat); the player-facing notice retired with `SellScreen` and its replacement lives in the
  M3 hub-return/shop UI. Director: **Reviewed** — sequencing, not a design change. **Reapply:** folded into the M3 dispatch
  brief (the Shop/hub-return shows a quota-MISS notice).
- **L6-F1 (M1.5 carry-over) — pure-keyboard-no-mouse aim defaults to DOWN.** Mouse + controller (the primary schemes)
  unaffected. Director: **Reviewed.** **Reapply:** filed `FU4` (keyboard fallback tracks movement when no mouse/stick active)
  in `TASKS.md` backlog. Non-blocking.

**M1.6 Wave 2 close-out complete.** `DESIGN_DEVIATIONS.md` empty between waves. **Next: Wave 3 — M3 (Hub shop sell+buy + META v3→v4).**

---

## M1.8 close-out (2026-07-02) — 17 entries dispositioned (Director reviewed in-session): 15 Reviewed + 2 Addressed

Full verdict record: `design/M1_8_Tasks/G4_findings_M1.8.md`. Entries verbatim-summarized from the active log:

- **PLAYERTAB / player_visual.gd timing model** (2026-06-28) — shared `lock_duration_cap_s`/`fixed_lock_s` → per-action
  `pickup_lock_s` (0.25) / `throw_lock_s` (0.30), Director-directed. **Addressed.** **Reapply:** as-built amendment appended to
  `design/M1_7_Tasks/N1_player_visual_state_machine.md` (per-action knobs canonical; CLIP_DRIVEN default byte-unchanged).
- **H1 shack doorway-only** (2026-06-28) — **Reviewed** (superseded by the H2 front-facade entry below; open-roof question retired).
- **H1 HubCamera.zoom 1.2 → 1.05** (2026-06-28) — **Reviewed** (render-time framing; later superseded in practice by H4's painter fill).
- **H1 wall visuals kept as re-tinted ColorRects** (2026-06-28) — **Reviewed** (superseded by the H2 walls-removed entry below).
- **H1 ~15 dressing props (breakdown said ~10–12)** (2026-06-28) — **Reviewed** (moot post-H4 prop removal).
- **H0 asset count — docs said 24 object PNGs, directory has 20** (2026-06-28) — **Reviewed.** **Reapply:** M1.8 breakdown
  source section corrected 24 → 20.
- **H2 ground re-authored — 16 framed tiles → 3 corner-Wang transition tilesets + vertex-map painter (720 cells)**
  (2026-07-01, Director-directed) — **Reviewed.** **Reapply:** as-built block added to
  `art_workshop/map_layouts/staging_area_layout_a_dressed.md` (notes H4 iso now supersedes the *visual*; Wang sets remain the revert path).
- **H2 tile palette gradient-map retoned to Band-0** (2026-07-01) — **Reviewed** (retone script archived with sources).
- **H2 litter fringe — continuous band → sparse hash-scattered patches** (2026-07-01) — **Reviewed** (danger-gradient cue carried
  by the scrap rim; revisit only if a future gate wants it stronger).
- **H2 wall ColorRect masses REMOVED — Wang scrap border IS the wall visual** (2026-07-01; supersedes the H1 walls entry) —
  **Reviewed** (colliders untouched; scrap band covers every collider footprint).
- **H2 shack — doorway-only → full front-facing building sprite 176×144** (2026-07-01, Director-directed; supersedes the H1
  doorway entry) — **Addressed.** **Reapply:** dressed-layout doc updated — front-facade shack folded in, open-roof open question
  RETIRED (Shop remains a separate UI scene; garbled sign = placeholder-grade).
- **H2 south fence line (5 fence_strip sprites on the S collider)** (2026-07-01) — **Reviewed** (H4 later removed it with all
  dressing props; grass surround note in G4 watch-items).
- **H2 object angles — 6 props regenerated; y-sort re-anchored to sprite base** (2026-07-01) — **Reviewed.**
- **H4 hub ground — 45° ISOMETRIC pivot (`hub_ground_iso.tres`, 963-cell zone painter)** (2026-07-02, Director-directed) —
  **Reviewed / iso RETAINED** as the current dressing (the recommendation deferred iso-vs-top-down to HG3; the Director settled it
  by retention at close-out — H2 top-down stays the one-swap revert path; felt read arrives with the M1.9 SG1 build).
- **H4 ALL dressing props removed (shop + dive portal kept)** (2026-07-02, Director-directed) — **Reviewed** (iso prop re-dress
  = follow-up only if iso survives the M1.9 gate — G4 watch-item).
- **H4 grass surround replaces the scrap-wall ring + south street** (2026-07-02) — **Reviewed as-is** (the flagged
  street-entrance-cue / harder-bounds-read question stays a G4 watch-item, no change directed).
- **H4 tooling — brief's edit-image transitions unachievable as specified; shipped per-edge shape-mode batch instead**
  (2026-07-02) — **Reviewed** (evidence archived in `art_workshop/game_art/hub_iso/`; matches the `pixellab-wang-tileset-pipeline`
  memory).

**M1.8 close-out complete.** `DESIGN_DEVIATIONS.md` empty. **Next: M1.9 build Wave 1 (S0 ∥ S1).**

---

## M1.9 Wave-1 close-out (2026-07-02) — 2 entries: 1 Reviewed + 1 Addressed

- **S0/SpawnService — cap-group accounting live-registry-derived, not the §6.1 monotonic
  `{ceiling, count}` counter** (2026-07-02) — **Reviewed.** Freed nodes re-open cap headroom for
  mid-run spawners (S6b+); unobservable in Phase A (fingerprints/positions byte-identical,
  verified). **Reapply:** breakdown §Cross-cutting contracts (cap line) + S0 spec §10 as-built
  amendment — "hard caps bound live nodes" is now canonical.
- **S0/SpawnService — untyped locals in `_compact()`/`clear_all()`** (2026-07-02) — **Addressed.**
  Director required a pattern with no untyped locals; restructured at close-out to test
  `entry["node"]` in place via `is_instance_valid(...)` (no local binding of possibly-freed
  instances). Verified: `test_spawn_service` (incl. free-without-despawn) + golden
  `test_new_hazard_spawn` + fp `e943ac9c8bc1` + smoke all green. Typed-GDScript convention holds
  with zero exceptions; S0 spec §10 records the as-built shape.

**M1.9 Wave-1 close-out complete.** `DESIGN_DEVIATIONS.md` empty. **Next: Wave 2 (S2 ∥ S5).**

---

## M1.9 Wave-2 close-out (2026-07-03) — 8 entries (S2×4 + S5×4): 7 Reviewed + 1 Addressed

- **S2/TelegraphFSM — presentation-only; FSM timing accumulators stay host-side** (2026-07-02) —
  **Reviewed.** Q1 transplant-verbatim tiebreak wins over the §2.2 table. **Reapply:** S2 spec
  §Wave-2 close-out amendments.
- **S2/components — live `current_depth_index` reads stay at legacy sites** (2026-07-02) —
  **Reviewed.** Config-snapshot ban covers CONFIG, not BUG2 live run-state. **Reapply:** S2 spec
  amendments (+ already documented in `opposition_component.gd` contract).
- **S2/base contract — duck-typed `host.call(&"run_clock_ms")` seam** (2026-07-02) — **Addressed.**
  Director required a typed alternative; fixed at close-out with an injected `Callable` bound once
  at `bind()` (`_run_clock = Callable(host, &"run_clock_ms")`), no per-call duck dispatch. Golden
  frame-trace parity + hazard suite + fp + smoke re-verified green. **Reapply:** S2 spec amendments.
- **S2/golden harness — scope strengthenings (second pursuer trace; dual-emit twins refactor-side)**
  (2026-07-02) — **Reviewed** (nothing weakened; goldens legacy-only). **Reapply:** S2 spec amendments.
- **S5/SetPieceInject — attach-at-open-socket, not e4's swap lean** (2026-07-02) — **Reviewed**
  (per §10 Q3; revisit swap only if S7 playtest reads detour-vaults as skippable). **Reapply:** S5
  spec §11.
- **S5/WearDecay — M1.9 decay is breach-led (blocks only behind breaches on tree bands)**
  (2026-07-02, Director-visibility item) — **Reviewed** (accepted per D-RAT-1/§10 Q4;
  `loop_back_count` stays out of scope; band_two tunes breach budgets — width-2 runs scarce,
  0–2/band). **Reapply:** S5 spec §11.
- **S5/BandPipeline — unknown flavor config = fail-loud `null`, not "skip and generate"**
  (2026-07-02) — **Reviewed.** **Reapply:** S5 spec §2.2 amended in place + §11.
- **S5/stage traits — overridable methods, not consts (GDScript can't shadow base consts)**
  (2026-07-02) — **Reviewed.** **Reapply:** S5 spec §11.

**M1.9 Wave-2 close-out complete.** `DESIGN_DEVIATIONS.md` empty. **Next: Wave 3 (S3, sole
`main_game.gd` writer).** Side record: BUG-M13FLAKE filed (pre-existing m13 headless timing flake,
not an M1.9 regression).

---

## M1.9 Wave-3 close-out (2026-07-03) — 5 entries (S3): 4 Reviewed + 1 Addressed

- **S3/bandgen surface — touched per binding §7.2 Q6(iv) despite the brief's reserve line**
  (2026-07-03) — **Reviewed** (spec-over-brief; `piece_pool_ext` + pipeline-owned ext-catalog swap
  had to land with the call-site switch; fp re-verified). **Reapply:** S3 spec close-out amendments.
- **S3/to_flat_dict — one-level nested `param_overrides` stamp** (2026-07-03) — **Addressed.**
  Director required the flatness pin absolute: flattened at close-out to dotted rows
  `param_overrides.<def_id>.<param_key>` → primitive (no base key, zero rows neutral);
  `_param_override_rows()` replaces `_param_overrides_flat()`; `test_run_config` pin restored
  absolute + dotted-row assertions; breakdown amendment 10 updated (S4 asserts the dotted shape).
  Verified: run_config/telemetry-marking/config-menu 89/89/encounter-builder/m12/m14/m15/corridor
  + smoke green. **Reapply:** S3 spec amendments + breakdown amendment 10.
- **S3/spec §3.5 case-7 — enable-alone spawns zero (neutral cards)** (2026-07-03) — **Reviewed**
  (honest behavior asserted; S4 carries the "enabled def, fully-neutral card" trap-warning flag).
  **Reapply:** S3 spec amendments.
- **S3/deck-lane ctx enrichment** (2026-07-03) — **Reviewed** (determinism-neutral; enables S7
  authoring existing hazards into band_two's deck). **Reapply:** S3 spec amendments.
- **S3/`is_inert()` pre-flight** (2026-07-03) — **Reviewed** (preserves S0's all-off
  no-service-node contract). **Reapply:** S3 spec amendments.

**M1.9 Wave-3 close-out complete.** `DESIGN_DEVIATIONS.md` empty. **Next: Wave 4
(S4 ∥ S6a ∥ S6b ∥ S7, file-disjoint parallel worktrees).**

---

## M1.9 Wave-4 close-out (2026-07-03) — 18 entries (S7×2 + S6a×4 + S6b×6 + S4×5 + ORCH×1): 13 Reviewed + 5 Addressed

**Addressed (5):**
- **ORCH — D-RAT-2 charger deck-override had no data mechanism** → **Addressed: S9 deck-entry
  override wrapper** (M1.9 Wave 5, ∥ S8; TASKS §S9 + board). Band_two's charger row gets
  `throwable_while_charging=false` + `wall_crash_recover_mult=2.0` via `DeckEntry`.
- **S6a D1 — per-entity host shell** → **Addressed: FU5 shared Actor-host shell** (post-SG3
  backlog + board). Shell stands for M1.9 as the honest measured cost.
- **S6a D4 + S6b D6 — gloss CSV rows deferred** → **Addressed at close-out:** 23 rows
  (13 charger + 10 splitter) appended to `config_strings.csv`; menu/schema/def tests re-verified.
- **S6b D3 — no trap flag** → **Addressed at close-out:** `trap_if_neutral` added on the parent
  splitter's `catch_radius`; schema tests green.

**Reviewed (13):** S7 deck-ships-4 (completed 4→6 at integration, min_band=2 confirmed) · S7
tint-only audit · S6a kills-in-params (STANDING CONVENTION for deck-driven defs; breakdown
contracts updated) · S6a spawn-card authoring shape · S6b two host scenes (contract-forced) ·
S6b spawn cards · S6b ctx-kills tier · S6b no floor-snapping (SG2-conditional follow-up noted) ·
S4 count-agnostic matrix · S4 raw trap tokens · S4 neutral-card trap YES · S4 fold glyphs ·
S4 tier-v1 respawn ctx.

**Reapply:** Wave-4 close-out amendment sections in S6a/S6b/S4/S7 specs; breakdown §Cross-cutting
contracts (deck-driven def conventions + S9); TASKS §S9 + §FU5; SG1 blockedBy now S0–S9.

**M1.9 Wave-4 close-out complete.** `DESIGN_DEVIATIONS.md` empty. **Next: Wave 5 (S8 ∥ S9).**

---

## M1.9 Wave-5 close-out (2026-07-03) — 1 entry (S8): 1 Reviewed

- **S8/route-key — `_band_route_key` member instead of the §4.1 Dictionary-returning helper**
  (2026-07-03) — **Reviewed** (protects S3's kept-signature golden-harness seam). **Reapply:** S8
  spec §Wave-5 close-out amendment. *(S9 shipped zero deviations.)*

**M1.9 Wave-5 close-out complete — build phase S0–S9 fully swept.** `DESIGN_DEVIATIONS.md` empty.
**Next: Wave 6 re-gate (SG1 build + publish → Director playtest → SG2 → SG3).**

---

## M1.10 Wave-1 close-out (2026-07-05) — 3 entries (T0): 3 Reviewed

Director dispositioned all three **Reviewed** (design fine as-is; no change). T2a/T2b shipped zero
deviations. All three are backend-local as-built facts already captured by the T0 spec's Resolved
Decisions + the cost ledger — no design-doc edit required.

- **T0/cave-backend — grid-level carve = a deterministic *mirror* of the CARVE-mode concept**
  (not literal `ConnectivityGuarantee` reuse; that mode is a journal-LIFO revert, inapplicable in a
  stateless backend). Reuses the stage's real `is_fully_connected` checker via `Mode.ASSERT`. —
  **Reviewed** (Phase-3 Q4 already ratified this reading). **Reapply:** none — canonical in T0 spec
  §10 Resolved Decisions Q4.
- **T0/cave-backend — `cave_backend.gd` ~404 code lines vs the ~255 estimate** (Q8 2×2-open throat
  guarantee heavier than its ~35-line estimate + `_pick_deepest_piece`; downstream reuse still 0 new
  lines). — **Reviewed** (cost-ledger magnitude note, not a design change). **Reapply:** none — the
  number stands in the T0 worklog cost ledger (TG3 evidence).
- **T0/cave-backend — `deepest_piece` chosen by chunk-graph BFS** (replicating DepthGrader) rather
  than spec §3.5's cell-BFS, making C4's `depth_index == max_depth` bar hold by construction (spec
  §3.5 was self-contradictory). — **Reviewed** (keep; validates the spec's own acceptance bar).
  **Reapply:** none — backend-local; the depth contract T1 consumes (`max_depth >= 4`, entry anchor)
  is unchanged.

**M1.10 Wave-1 close-out complete.** `DESIGN_DEVIATIONS.md` empty. **Next: Wave 2 (T1 — cave
materialisation, sole `main_game.gd` writer).**

---

## M1.11 Wave-1 close-out (2026-07-06) — 4 entries (U0): 4 Reviewed

Director dispositioned all four **Reviewed** (design fine as-is). U2a/U2b shipped zero deviations.
One reapply: a clarifying line in the breakdown's entry-anchor contract (see first entry); the
other three are backend-local as-built facts already canonical in the U0 spec's Resolved Decisions.

- **U0/entry-anchor — scatter's anchor tie-break is lane-aligned** (prefers the clear-lane row)
  rather than the cave's pure min-y "west-most" rule; ratified by U0 RD-2 (BINDING), flagged only
  because the breakdown's "Scatter inherits all three bars unchanged" read stricter than the RD. —
  **Reviewed** (RD-2 is the design; "unchanged" binds the bars, tie-break is per-backend).
  **Reapply:** clarifying line added to `M1.11_Breakdown.md` §entry-anchor contract (2026-07-06).
- **U0/no-carve — the scatter backend ships no carve fallback at all**; connectivity + 2×2
  passability hold by construction (RD-6 proof — carve arm dead code at every legal knob value;
  teeth live in the pipeline ASSERT + S-suite). — **Reviewed** (the breakdown's "by construction
  or by deterministic CARVE" clause is satisfied by election of the first arm). **Reapply:** none —
  canonical in U0 spec RD-6.
- **U0/S10-strong-form — `test_scatter_backend` S10 asserts the strong passability form** (EVERY
  floor cell ∈ the 2×2-open set) rather than the spec body's weaker "in or adjacent" bar; the RD-6
  proof yields the strong form for free and U1's M6 asserts the same form. — **Reviewed** (strictly
  tighter, never looser). **Reapply:** none.
- **U0/RD-16-test-comments — comment-only staleness edits** to `test_band_pipeline_parity.gd` (P7)
  + `test_cave_backend.gd` (C8) as their own commit (`d2a8a34`); assertions untouched, suites green
  pre/post, authorized by RD-16. — **Reviewed** (comment hygiene on T0-owned files). **Reapply:** none.

**M1.11 Wave-1 close-out complete.** `DESIGN_DEVIATIONS.md` holds only the M1.10 TG1 entry
(awaiting the TG3 close-out). **Next: Wave 2 (U1 — scatter materialisation, sole `main_game.gd` writer).**

---

## M1.11 Wave-2 close-out (2026-07-08) — 3 entries (U1): 3 Reviewed

Director dispositioned all three **Reviewed** (design fine as-is; all test-only or hygiene-scoping).
No design-doc reapply needed — the first two are test strengthenings in the RDs' own direction; the
third's hygiene-pass routing is already recorded in the U1 worklog's follow-ups.

- **U1/M6-size-belt — M6(b) additionally asserts `|T| == |floor|`** alongside single-component (the
  explicit belt on RD-U1-2's "T == the floor set" claim; zero flakiness cost). — **Reviewed**
  (test-only strengthening). **Reapply:** none.
- **U1/M9-socket-raw-pin — M9(a) also pins the socket arm's RAW-offset return value in-suite**
  (`_pinned_gate_pos == spawn_pos + GATE_SPAWN_OFFSET` on a greybox profile), beyond the spec's cave
  guard-arm check. — **Reviewed** (test-only strengthening). **Reapply:** none.
- **U1/exit-candidate-comment — the `_exit_candidate_cells` "on caves" comment left untouched** (not
  one of RD-U1-4's two listed call-site comments; still literally true, cave-only in phrasing). —
  **Reviewed** (correct RD-U1-4 diff-purity scoping). **Reapply:** none — already on the post-UG3
  hygiene-pass list (U1 worklog follow-ups: with the `_materialise_band`/`_build_synthetic_piece`
  wording + the SocketSealer rename, T1 OQ-7).

**M1.11 Wave-2 close-out complete.** `DESIGN_DEVIATIONS.md` holds only the M1.10 TG1 entry
(awaiting the TG3 close-out). **Next: Wave 3 (U3 — `band_four.tres` "The Far Field", ledger target 0).**

---

## M1.11 Wave-3 close-out (2026-07-08) — 1 entry (U3): 1 Reviewed

- **U3/def-menu-golden — charger's IN-DECK chip golden caught up to band_four deck membership**
  (`"band_two"` → `"band_four, band_two"`; the S4 count-agnostic band-scan surfaced band 4's deck
  with zero menu code — positive N=3 evidence; U3 flagged and touched nothing, the orchestrator
  applied the 2-line golden update + stale comment at integration, `72cf997`). — **Reviewed**
  (test caught up to ratified product behavior; exact TG1-class stale golden). **Reapply:** none —
  the fix is the catch-up; canonical deck already in the U3 spec RD-2/D-RAT-6.

**M1.11 Wave-3 close-out complete.** `DESIGN_DEVIATIONS.md` holds only the M1.10 TG1 entry
(awaiting the TG3 close-out). **Next: Wave 4 (U4 — fourth hub portal + band_four routing + plaza-full pin).**

---

## M1.12 — Scaling Debt Paydown — CLOSED 2026-07-11 (Director dispositioned all)

Behavior-preserving R2–R10 cleanup. Waves 1–4 build phase: 5 deviations total (Waves 1 = 0,
Wave 2 = 1, Wave 3 = 1, Wave 4 = 3). DR-3 (greybox hazard-spawn migration) **signed off** by the
Director on the equivalence evidence (K5 exact 0.0%Δ; pursuer ±15% incl. the +11.1% deep case; all 4
layout fps + both hazard traces byte-identical).

- **[V2] telemetry payload-field drop** — dropped 3 unconsumed fields (`hazard_awoke.trigger`,
  `throw_killed_hazard.item_id`, `hazard_pursuer_state.state`) retiring the 6 dual-emit signals; generic
  `opposition_event` carries every consumed field; no `SCHEMA_VERSION` bump. · **Verdict: Reviewed**
  (pre-ratified via **D-RAT-7** at design lock). No design change.
- **[V4] private `_evaluate_quota` facade delegate** — the GameState split kept a private delegate so
  `test_quota_system`'s 6 white-box sites didn't need editing. · **Verdict: ADDRESSED** — task **V4b**
  (`6e36e57`) rewrote the 6 sites onto `gs.quota_ladder().evaluate(...)` (new public accessors) and
  deleted the delegate. **Reapplied to:** code (delegate gone; the public `quota_ladder()`/
  `held_haul_value()` accessors are now the canonical seam).
- **[V3] per_band_cap = 16 on the K5 defs** — added beyond the design letter to bound each K5 type to
  the fair-share slice (48/3) so all three types always appear on deep bands; makes legacy→deck
  equivalence EXACT (0.0%Δ). Inert for band_two. · **Verdict: Reviewed** — faithful reproduction of the
  retired fair-share slice as data.
- **[V3] rc.param_overrides cross-band leak** — the K5 play magnitudes ride the global
  `rc.param_overrides` (required so all-off = neutral = zero hazards); the def-id-keyed lever applies to
  any band decking pingpong/bomb/spike. Benign in M1 (band_two isn't dived under the play preset;
  band_two profile byte-identical). · **Verdict: Reviewed. FORWARD-FLAG:** any future band sharing K5/
  pursuer def ids inherits the global override — the intended re-tuning surface, but a landmine to note.
- **[V3b] J3 density → even-spread fold** — the R1 pursuer's J3 area-scaled big-room clustering folds to
  the deck lane's even-spread; per-type total preserved ±15% (the +11.1% deep case surfaces this),
  big-room clustering not. · **Verdict: Reviewed** (the licensed **D-RAT-3a** change; **DR-3 signed off**
  on the concrete evidence). **Reapplied to:** the as-built reality is the deck lane's even-spread for all
  greybox hazards; the J2/J3 density machine is retired.

**DR-3 sign-off (2026-07-11):** the greybox hazard-spawn behavioral change + re-pinned goldens ACCEPTED.
band_greybox now spawns all hazards (K5 + pursuer) via the deck lane at `opposition_credits = 58`; "one
way to add an opposition" fully delivered. Layout fps unmoved; only the play-preset hazard-spawn goldens
changed, with proven equivalence. **D-RAT-8:** `opposition_credits` sized to preserve density (58 = K5's
capped 48 + pursuer's ~10), not a hard-48 cap.
