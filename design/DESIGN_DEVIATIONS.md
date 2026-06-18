# Design Deviations Log (active working set)

Append-only record of every place the build departed from `Junkyard_GDD.md`,
`Junkyard_Technical_Design.md`, the role playbooks, or the documented setup — with rationale.
The orchestrator and each dispatched subagent append here whenever a task departs from spec.

**Lifecycle (`CLAUDE.md` → "Wave close-out — deviation assessment"):** this file holds
deviations **awaiting the Director's evaluation**. After each wave, the Director dispositions every
entry **Reviewed** or **Addressed** (Claude only recommends — it never self-dispositions). Per the
verdict, Claude reapplies to the design (usually `design/M1_Tasks/M1_As_Built.md` or
`M1_Design_Decisions.md`), then **moves the entry to `DESIGN_DEVIATIONS_HISTORY.md`**. Between
fully-evaluated waves this file is ideally empty.

Format: `[date] <id/area> — what changed vs. the doc · why · Claude's recommendation`

---

## ⏳ Pending Director evaluation

### Wave 4a (E2, E3, D3, G5 — integrated to `main` 2026-06-17; evaluate at wave-4 close-out after 4b F1/F2)

> **E3/pockets-economy** was Director-dispositioned **Addressed** (ratify 0.20 + whole-item) on 2026-06-18
> and archived to `DESIGN_DEVIATIONS_HISTORY.md` (W4-1 → ratified decision #13). The remaining entries
> below are **still pending Director review** ("let me read them first").

- **[2026-06-17] E3/idempotency — added a `_run_ended: bool` guard on `GameState`.** New run-end guard so a same-frame extract+timeout tie can't double-bank or fire `run_ended` twice; extract is wired ahead of timeout so reaching the gate wins. Resets in `start_run()`. · *Why:* E3 Open-question #122; `run_active` alone didn't early-return on an already-inactive run. · **Recommendation: Reviewed** — minimal correct implementation of a behavior the spec called for; no design change.

- **[2026-06-17] E3/telemetry-seam — `value_lost`/`items_kept` not carried on `run_ended`.** `run_ended(reason, duration_s, depth_reached)` is a locked fixed-arity contract, so the failed-run detail rides on `haul_banked(kept_value)` + a debug `print` for now. · *Why:* must not change the locked `run_ended` signature. · **Recommendation: Reviewed** — flag for G1 to add a dedicated telemetry row; signature stays locked.

- **[2026-06-17] E2/signal-reconciliation — built against the real EventBus/GameState contract, not the spec's idealized names.** E2's spec sketched `clock_remaining`/`clock_total`, `inventory_changed(run_value,count)`, `depth_changed`, `gate_in_range/out_of_range`; E2 instead uses the as-built `dive_clock_changed`, `run_inventory_changed`+`run_haul_value()`, `GameState.current_depth`, and A2's `interactable_focused/unfocused` (filtered to `&"gate"`). · *Why:* those idealized signals don't exist; As-Built wins. · **Recommendation: Reviewed (reconciliation, not a design change)** — already canonical; no reapply needed beyond noting E2 consumes the existing contract.

- **[2026-06-17] E2/clock-meter — DecisionHUD drives its own ProgressBar off `dive_clock_changed` rather than embedding `ui/dive_clock_meter`.** The A3 meter is white/red only; E2 needed the full green→amber→red urgency ramp + threshold pulse. The A3 meter node is untouched and still usable standalone. · *Why:* richer urgency cue for the fun gate. · **Recommendation: Reviewed.** Tuning knobs (`urgency_fraction=0.25`, `pulse_speed=6.0`) are `@export`ed for G4.

- **[2026-06-17] D3/closes wave-3 `C2/dropwiring` (Director: Addressed) — drop position resolved to the player's world position.** D2's drop gesture now `EventBus.junk_dropped.emit(removed_item, player_world_pos)` after `RunInventory.remove_at()`; C2's existing spawner re-instantiates the pickup. The panel (a `Control`) finds the player by walking `current_scene` for the `Player` class. · *Why:* the panel has no world transform and the player is in no group. · **Recommendation: Reviewed (closes an already-Addressed deviation).** Optional follow-up surfaced: register the player in a `"player"` group and switch to `get_first_node_in_group("player")` to drop the tree-walk — noted for dive-scene assembly (G3).

- **[2026-06-17] G5/closes wave-3 `E1/schema` (Director: Addressed) — the v1→v2 meta migration fixture now exists.** Committed binary `tests/fixtures/meta_v1.sav` + `tests/test_save_migration.gd` (→ `SAVE MIGRATION OK`), wired into CI. Establishes the per-schema-bump template (one migration step + one binary fixture + one round-trip assert). Added `*.sav -text` to `.gitattributes`. · *Why:* fulfills the TDD "a QA fixture on every schema change" rule the E1 bump skipped. · **Recommendation: Reviewed (closes an already-Addressed deviation).** Reapply note: the "tracked as a follow-up task" line in `M1_As_Built.md` §Save schema (E1) can now be marked closed.

### Wave 4b (F1, F2 — integrated to `main` 2026-06-17)

- **[2026-06-17] F1/scope-reconciliation — F1 shipped smaller than its spec.** The spec assumed F1 must bump the save schema, add a `money` migration step, and introduce a new `credit_money()` + `EventBus.money_changed` signal. The as-built codebase **already** had all of that: `money` exists and persists at schema v2, and `add_currency(&"money", delta, source)` already emits `currency_changed`. So F1 added only the genuinely-new `sell_banked_junk(source) -> Array[Dictionary]` (Option B sell-at-F2). · *Why:* avoid duplicating existing ledger/persistence machinery; one canonical currency mutation path. · **Recommendation: Reviewed (reconciliation, not a design change).** `event_bus.gd` and `save_manager.gd` untouched.

- **[2026-06-17] F2/signal-reconciliation — built against `run_ended`, not the spec's `run_end(cause, payload)`.** F2 listens to the real `run_ended(reason, duration_s, depth_reached)` and switches on `reason`. · **Recommendation: Reviewed (reconciliation).**

- **[2026-06-17] F2/present-on-all-causes — the sell screen presents on extract AND death/timeout.** Title "EXTRACTED" vs "RUN LOST — kept N"; sale tagged `source = &"extract"` vs `&"pockets"`. · *Why:* the ratified E3 + F2 Open-question #1 recommendation — every run ends on the same reward beat, closing the loop symmetrically. · **Recommendation: Reviewed** (implements an already-recommended call; confirm at close-out).

- **[2026-06-17] F2/paused-tween-workaround — count-up uses a manual `_process` lerp on a `PROCESS_MODE_ALWAYS` node, not a `Tween`.** Godot 4 has a standing regression where a tween set to process while paused doesn't reliably tick (godotengine/godot#81994, #67504); the screen pauses the tree, so a manual lerp is used. Behaviourally identical. · **Recommendation: Reviewed** (engine-workaround, no design impact).

- **[2026-06-17] F2/Continue-deferred + `project.godot` string registration.** `SellScreen.Continue` only unpauses, hides, and emits a local `continue_pressed` signal — the actual restart/overworld loop is **deferred to G3** (which subscribes). F2 also appended one line to `project.godot` `locale/translations` registering `ui/sell/sell_strings.en.translation` (same convention D2/E2 used). · **Recommendation: Reviewed** — G3 owns wiring `continue_pressed` to `start_new_run()`; noted as a G3 dependency.

---
*All wave-4 tasks (E2, E3, D3, G5, F1, F2) are integrated + green on `main`. **Awaiting the wave-4 close-out Director disposition** — the one substantive design call is the E3 pockets change (top of this section); the rest are reconciliations or close already-Addressed wave-3 items.*
