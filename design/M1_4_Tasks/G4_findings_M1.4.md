# G4 Findings — M1.4 re-gate (RG2 analysis + RG3 verdict)

**Status:** RG2 telemetry analysis + playtest-feedback triage assembled by Claude (orchestrator).
**RG3 verdict (go / iterate / pivot): ITERATE → M1.5** (Director, 2026-06-24, post-Wave-5 re-gate — see §RG3 below). Claude assembles + recommends; the Director plays + decides.
**Build played:** `m1-20260621-fc932c4` (RG1 M1.4 fun stack). Telemetry: `user://telemetry/run_log.jsonl`
(local: `…/THE FAR YARD/telemetry/run_log.jsonl`), 14 133 events, 256 runs across all builds; **111 runs** on `fc932c4`.

---

## RG2 — telemetry analysis (fc932c4)

Two sessions on the played build: `s_3841c9` (64 events-of-run-start) and `s_384be7` (47 runs). The headline
finding comes from `s_384be7`, which captures the **run-auto-end bug (feedback #7)** cleanly.

### Run-end arc, session `s_384be7` (in order)

| Runs | Pattern | Read |
|---|---|---|
| 1–2 | death @ depth 2–3, ~12 s | warm-up deaths |
| 3–9 | **extract**, 26–52 s, depth 2–4 | healthy extraction loop |
| 10–18 | death, 32–140 s, **depth 6–16**, lost 92–397 | healthy deep runs — the loop *works* |
| **19–47** | **death @ depth 1, ~0.01 s, lost 0, banked 0** | ← **broken: every run instant-dies, never recovers** |

Once run 19 breaks, **all 29 subsequent runs instant-die identically.** This is the "each run ends
automatically until the quota is missed" report — confirmed and root-caused.

### Root cause of #7 (config-triggered spawn-room kill)

Diffing the `run_config` snapshot of run 18 (last healthy) vs run 19 (first broken):

| knob | run 18 (healthy) | run 19 (broken) |
|---|---|---|
| `hpp_base_count` | **0** | **1** |
| `hspike_base_count` | **0** | **1** |
| `hspike_per_room_cap` | 0 | 1 |
| `cam_visible_world_width` | 1004.1 | 1920.0 |

The Director raised the new-hazard **`base_count` from 0 → 1** between runs (the natural move — see #3, spikes
never appeared). With `base_count ≥ 1`, `_spawn_new_hazards()` (`main_game.gd:371`) places a hazard in **every**
piece **including the depth-0 entry piece**, at a strided floor cell that can be the **entry/spawn cell** — i.e.
on top of the player. Result: instant lethal contact on frame 0 → `run_ended cause=death duration_s≈0.01 depth=1`
(note: **no `hazard_caught`/`hazard_awoke`/`new_hazard_killed` row** precedes these — the kill fires before any
wake). Every run thereafter carries the same config, so every run instant-dies.

`_spawn_new_hazards` has **no spawn-room / entry-cell exclusion** — unlike R1 (`r1_spread_min_depth`,
`r1_depth_threshold`) and exits (`_exit_candidate_cells` excludes `entry_cell` + the spawn-gate cell). The RG1
preset only *avoids* the bug by shipping `base_count = 0` for all three K5 types (`run_config.gd:727/734/741`);
that workaround is also what makes spikes invisible (#3).

### Other telemetry notes

- **`hazard_caught` = 9 560 events** vs 256 runs — dominated by R1's per-frame proximity logging; not a bug
  signature here, but worth a one-shot-per-hazard latch review later (noise in the log).
- Causes overall on `fc932c4`-era: death 145 / extract 90 / timeout 16 — extraction + timeout both reachable
  (the loop is sound when not hitting the spawn-kill).
- No `exposure_*` activity (R2/R3 ship OFF — expected).

---

## RG3 — playtest-feedback triage (Director's 6 items)

| # | Item | Class | Root cause / status | Fix locus |
|---|---|---|---|---|
| 1 | Set camera pixel view to **1000** | tuning | Preset ships `cam_visible_world_width = 576`; Director wants 1000 (was running 1004/1920). | `run_config.gd:691` (preset only) |
| 2 | Ping-pong **sticks on walls/corners** | **bug** | `pingpong_hazard.gd:83-92` reflects the **post-`move_and_slide` (tangential)** velocity, not the incoming heading. In a corner the heading collapses to wall-parallel and grinds to a stop. | `pingpong_hazard.gd` — track heading independently; reflect the *incoming* dir (or `move_and_collide` + `bounce`). |
| 3 | Rotating spikes **never show up** | **bug** (tuning + #7-coupled) | Preset `hspike_base_count=0` + `hspike_count_per_depth=0.1` ⇒ `floor(0.1·depth)=0` until depth 10 → effectively never spawn at playable depths. Raising base to fix it triggers #7. | spawn-room exclusion (with #7) **then** bump spike preset magnitudes. |
| 5 | Exits **don't spawn heading further in** | needs live-verify | Placement code (`_place_gate`/`_exit_placement_positions`) looks correct (pins one at spawn + scatters rest, floored ≥1); runs 3–9 *extracted* with `exit_enabled=true`. Director likely observed this **during the instant-death runs** (#7). Possible real issue: exits are placed once per band across graded pieces — "further in" within the same band shows no *new* gates. | verify first (base_count=0 so runs survive); fix only if reproduced. |
| 6 | Pursuer config: **only active in the room it spawns** | feature | New R1 behaviour knob — pursuer chases only while the player is in its spawn room, else idle/inert. Net-new `RunConfig` field + telemetry mark. | `run_config.gd` (knob) + `hazard_entity.gd` (behaviour) + `config_menu.gd`. |
| 7 | **Runs auto-end → quota missed** | **bug (critical)** | Root-caused above: new hazards spawn on the player in the depth-0 entry piece when `base_count ≥ 1`. | `_spawn_new_hazards` (`main_game.gd:371`) — exclude entry piece + a safe radius around `spawn_pos` (mirror `_exit_candidate_cells`). |

**#3 and #7 share one fix family:** add spawn-room / entry-cell exclusion to `_spawn_new_hazards`. That removes the
spawn-kill (#7) **and** lets `base_count` safely go ≥1 so spikes actually appear at shallow depth (#3).

---

## Recommendation (Claude → Director)

This reads as **ITERATE → M1.5**, not *go* or *pivot*: the core loop is sound (healthy 6–16-depth runs, extract +
timeout both reachable), but RG1 surfaced **3 real bugs (#2, #3, #7)**, a **tuning ask (#1)**, a **verify-first
item (#5)**, and a **net-new feature (#6)**. Two routing calls are the Director's (see the questions surfaced
alongside this doc):

1. **Packaging:** fix the bugs as an **M1.4 bug-wave + re-gate** (fast, no new four-phase authoring), **vs** open a
   full **M1.5 iteration** (four-phase: breakdown → per-task designs → fresh-eyes resolution → lock). #1/#2/#3/#7
   are small and well-understood (recommend a bug-wave); #6 is a genuine design feature that wants a per-task design.
2. **#6 semantics:** confirm the intended "spawn-room-only pursuer" behaviour (chase only while player shares the
   pursuer's spawn room; otherwise fully idle vs slow-patrol vs despawn).

_RG1-F1 (the K5 sweep-start magnitudes) and the GitHub board back-fill remain open for Director disposition (see
STATUS.md)._

---

## RG3 — post-Wave-5 re-gate verdict (Director, 2026-06-24)

The Director playtested the **Wave-5 fixed build** (camera 1000, spikes visible, no instant-death auto-end, ping-pong
unsticks — the BUG7/BUG8/TUNE2/FB5 fixes). The loop now holds; the spawn-kill (#7) is gone. Returning feedback:

| # | Item | Class | Notes |
|---|---|---|---|
| 6 | Spawn-room-only pursuer | feature (carried) | Still pending. Semantics already **LOCKED** (Director): **slow patrol** — keeps patrolling its spawn room, never chases outside it, chases only while the player is in that room. |
| 8 | Run money text hidden behind the bottom-right inventory | **bug** | Move the run-haul readout to sit **below the dive timer** (top-right). |
| 9 | Grab prompt always shows | **bug** | Should be visible **iff** a grabbable interactable is in focus/range. |
| 10 | **Throwing mechanic** (net-new) | **feature** | Inventory item is highlightable; **Q/E** cycle the highlight; **Space** throws the highlighted item in the player's facing direction. Hitting a pursuer **kills the pursuer + destroys the item**; a **miss** (wall / max-range) **re-drops the item as a grabbable pickup**. Controls locked by the Director: **F = grab/interact AND extract/descend**; **Q/E = highlight L/R**; **Space = throw**. |

**Verdict: ITERATE → M1.5.** Rationale: this is past bug-wave territory — #10 is a **net-new mechanic** and #6 is a
**deferred design feature**, both of which want a real per-task design (Phase 2) + fresh-eyes resolution (Phase 3), not a
direct hand-code. The two HUD bugs (#8, #9) ride along inside M1.5. The core loop is sound (Wave-5 confirmed), so this is
*iterate*, not *pivot*. M1.5 is authored via the full four-phase process in `design/M1_5_Tasks/`.

**Scope (Director-confirmed):** throw mechanic (#10) · spawn-room pursuer (#6) · money-text reposition (#8) · grab-prompt
fix (#9).

_Still open for Director disposition before the Phase-2 fan-out (standing deviation-sweep-before-dispatch rule):
Wave-5 deviations (TUNE2 `_driven_default_preset`, stale `.tscn` UID drift), RG1-F1, and the GitHub board back-fill._
