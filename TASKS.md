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

## M1.6 — Surface & Staging (ACTIVE — iterating on the M1.5 ITERATE verdict)

Give the game a **surface**: boot to a real Main Menu, stage between runs in a **walkable greybox Hub** with a **Shop**
that sells your haul AND lets you spend Money on greybox upgrades (replacing the auto-`SellScreen`), and **depart** into
dives from there — and move the debug controls off the first screen into a **P-key tabbed** menu. Breakdown + dependency
map + wave order + locked decisions: `design/M1_6_Tasks/M1.6_Breakdown.md` (§"Phase 3 Dispositions & Phase 4 Lock").
Provenance: `G4_findings_M1.5.md` §RG3. **Design is LOCKED** — every task doc carries a "Resolved Decisions (Phase 3)"
section; Director dispositioned the scope calls (buy = persistent → META v3→v4 save bump; telemetry-export → P-debug Meta
tab; New-Game-over-save = wipe-with-confirm; Settings = placeholder). App flow **Menu → Hub ⇄ Dive** via a persistent root
`App` router; `main_game.tscn` becomes dive-only; the clock is dive-only. All-off `RunConfig` stays the permanent baseline
(fp=e943ac9c8bc1); **89-knob count holds** (no lever knob; M4 regroups only); Money/owned purchases are meta.

### Wave 1 — Foundation  *(M0 solo — single-writer on the shared flow/economy/config files)*

### M0 — Foundation: app-flow router + economy + signals + P action
- Milestone: M1.6 (Wave 1)   Assignee: general-purpose   BlockedBy: none
- Spec: `design/M1_6_Tasks/M0_foundation_router_economy.md`
- Goal: build the persistent root `App` router (`scenes/app/app.*` = new `run/main_scene`; `StateHost` swaps Menu/Hub/Dive; one persistent `DebugOverlay` `CanvasLayer`; auto-returns to Hub by observing the locked `run_ended`); declare the 8 new `EventBus` signals; add the neutral `GameState` economy surface (`purchase(item_id,price)`/`owns()`/`owned_items` + v3→v4 migration skeleton, NO schema bump) + the quota-decouple (`evaluate_quota_on_return()`) + the staged-config accessor + `App.current_state`; add the `debug_menu_toggle`=P input + the `run/main_scene` swap; ship throwaway greybox `main_menu.tscn`/`hub.tscn` STUBS + a router smoke test. Single-writer of `game_state.gd`/`event_bus.gd`/`project.godot`/`app.*`.
- Done when: project imports clean + boots to the `App` router → menu stub; all-off fp byte-identical (e943ac9c8bc1); 89-knob count unchanged; smoke + router smoke test green; all 8 signals declared; economy surface present at neutral defaults (no save bump yet); CI smoke test still boots.

### Wave 2 — Surface scenes  *(M1 ∥ M2 ∥ M4 — file-disjoint, parallel worktrees)*

### M1 — Main menu scene
- Milestone: M1.6 (Wave 2)   Assignee: ui-ux-designer (+ general-purpose)   BlockedBy: M0
- Spec: `design/M1_6_Tasks/M1_main_menu.md`
- Goal: new `scenes/menu/main_menu.tscn`+`.gd` (replaces the M0 stub) as the routed app entry: **New Game** (wipe-with-confirm on an existing save → `wipe_meta` → Hub) / **Continue** (enabled iff `SaveManager.has_save(0)`) / **Quit** (hidden on web) / **Settings** ("coming soon" placeholder); re-home the G6 first-run telemetry-consent here; version label; `menu_strings.csv`; greybox `Control`. Routes to Hub via the M0 router API.
- Done when: boot lands on the Main Menu; New/Continue/Quit/Settings behave as locked; Continue gates on save presence; New Game confirms before wiping; G6 consent fires once on first run; routes into the Hub; greybox, all strings via `tr()`.

### M2 — Hub scene + Menu→Hub→Dive→Hub flow
- Milestone: M1.6 (Wave 2)   Assignee: general-purpose (+ qa-playtest-coordinator: test-fallout)   BlockedBy: M0
- Spec: `design/M1_6_Tasks/M2_hub_scene_flow.md`
- Goal: new walkable greybox `scenes/hub/hub.*` (replaces the M0 stub): bespoke room, Player spawn, a **departure-portal** interactable → `dive_requested` → router loads the dive; a **shop anchor** for M3; an interim "Held: N items ~$X" readout (deleted by M3). **Refactor `main_game.*` to dive-only** (strip the embedded MainMenu/ConfigMenu/Start/SellScreen; dive self-starts in `_ready`→`start_new_run` reading the staged config else preset). Route run-end → **Hub**, firing the **quota-eval + roguelite miss-wipe on the guaranteed hub-return beat** (decoupled from selling, before the portal re-arms). Fix the test fallout (`test_main_game_loop` + the 5 RG verify scenes lose `%ConfigMenu`/`SellScreen`). **No `DiveClock` in the hub.**
- Done when: Menu→Hub→portal→Dive→return→Hub flows; the clock runs only in the dive; quota+wipe fire on hub-return without a shop visit; main_game is dive-only and self-starts; broken tests fixed + green; all-off fp byte-identical; no duplicate G6 consent path.

### M4 — Debug-menu rework (P-key + tabs)
- Milestone: M1.6 (Wave 2)   Assignee: ui-ux-designer (+ general-purpose)   BlockedBy: M0
- Spec: `design/M1_6_Tasks/M4_debug_menu_rework.md`
- Goal: move `config_menu` off the first screen → a **P-toggle overlay** (mounted on the M0 `App.DebugOverlay`, pauses the dive while open, no-op in Menu/Hub); restructure into a **7-tab `TabContainer`** (Hazards / Level Generation / **Vision** / Timer & Quota / Exposure & Return / Throw & Camera / Meta); **split the `r4_` vision/fog rows out of the maze section** via Option A (master-less `r4_vision_` pseudo-section — no field rename, no master) **preserving 89-knob coverage**; add the retiring web "Export telemetry" button to the **Meta tab**; new CSV title keys. Pure `ui/config/config_menu.*` (+ CSV).
- Done when: P opens/closes the tabbed debug menu in all 3 states; Vision is its own tab/section, maze rows stay in Level Gen, no `r4_` field renamed; `has_full_coverage()` + both 89-count tests green; all-off fp byte-identical; telemetry-export works from the Meta tab on web; pause-in-dive doesn't burn the clock.

### Wave 3 — Shop + integrate  *(M3 sequential — mounts into the Wave-2 Hub)*

### M3 — Hub shop (sell + buy)
- Milestone: M1.6 (Wave 3)   Assignee: general-purpose (+ game-director-designer: catalog `.tres`; + ui-ux-designer: shop UI)   BlockedBy: M0, M2
- Spec: `design/M1_6_Tasks/M3_hub_shop_economy.md`
- Goal: a Shop interactable in the Hub opens a Shop UI — **SELL** the banked haul → Money (reuses `sell_banked_junk`) + **BUY** a minimal greybox **persistent** catalog (3 owned-across-runs upgrades, `ShopItem`/`ShopCatalog` `.tres`, effects may stub) via M0's `purchase()`; land the **META save-schema bump v3→v4** (`owned_items`) + migration step + `meta_v3.sav` fixture + migration test; **retire `ui/sell/*`** (sell tally → Shop; quota/wipe already on the M2 hub-return beat; telemetry-export already on the M4 Meta tab). Mount into the Wave-2 Hub.
- Done when: Shop sells the haul + buys persistent upgrades gated by Money; owned upgrades survive a save/load (v1→v4 & v3→v4 migrations green + fixture); SellScreen retired with nothing dropped; quota/wipe still correct; all-off fp byte-identical; 89-knob count unchanged.

### Wave 4 — Re-gate  *(sequential; RG2/RG3 after the human playtest)*

### RG1 — M1.6 playtest build + verify
- Milestone: M1.6 (Wave 4)   Assignee: qa-playtest-coordinator   BlockedBy: M0,M1,M2,M3,M4
- Spec: author from `design/M1_5_Tasks/RG1_playtest_build.md` template
- Goal: assemble + verify the M1.6 loop (boot→Menu→New/Continue→Hub→portal→dive→return→Shop sell+buy; clock dive-only; P-toggle tabbed debug menu; save migration; all-off fp byte-identical; 89-knob coverage); **publish to itch** via `bash tools/push_itch.sh`; update `changelog.txt` (delta from M1.5).
- Done when: a fresh build runs the full surface loop; Continue resumes a save; the shop sell+buy + owned upgrades persist; debug menu opens on P; build live on `qusto/the-far-yard:html5`.

### RG2 — M1.6 telemetry / flow analysis vs M1.0–M1.5
- Milestone: M1.6 (Wave 4)   Assignee: qa-playtest-coordinator   BlockedBy: RG1 + human playtest data
- Spec: template `design/M1_1_Tasks/RG2_telemetry_analysis.md`
- Goal: did the surface loop land — boot-to-menu, hub dwell, sell+buy usage, dive-launch from hub, debug-menu opt-in via P; distributions vs the M1.0–M1.5 baselines where comparable; surface flow dead-ends.
- Done when: an analysis artifact reading the surface-loop adoption + any flow friction, comparable to the prior findings.

### RG3 — M1.6 re-gate verdict (Director decides)
- Milestone: M1.6 (Wave 4)   Assignee: qa-playtest-coordinator (assembles) → Director (decides)   BlockedBy: RG2
- Spec: template `design/M1_1_Tasks/RG3_regate_verdict.md`
- Goal: record go/iterate/pivot in `design/M1_6_Tasks/G4_findings_M1.6.md`. go → M2 (milestone); iterate → M1.7; pivot → design rework.
- Done when: a recorded go/iterate/pivot verdict, comparable to the prior findings.

---

## M1 follow-ups (deferred tech-debt — non-blocking, backlog)

From the M1 wave-5 close-out (`DESIGN_DEVIATIONS_HISTORY.md` §"M1 wave 5"). Neither blocks M1.2; pick up opportunistically.

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
