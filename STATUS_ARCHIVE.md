# STATUS ARCHIVE — THE FAR YARD

Superseded `STATUS.md` sections, moved here at each version boundary (Phase 4 of "Version breakdown
authoring", `CLAUDE.md`). Append-only, **newest at the bottom**. The live state is in `STATUS.md`; the
completed task list is in `TASKS_COMPLETED.md`; design history is in `design/` + `DESIGN_DEVIATIONS_HISTORY.md`.

---

## Archived 2026-06-19 at the M1.1 → M1.2 boundary

### M1.1 — built, playtested, verdict ITERATE → M1.2 (the playtest gate)

**M1.1 was BUILT.** Wave 1 (foundations) + Wave 2 (the four oppositions R1–R4) + RG1 (playtest build) all merged on
`main` (`c4c71b8`), verified green. The depth-scaled cost axis went live, configurable, config-marked in telemetry;
all-off reproduced the M1.0 baseline exactly. RG1's verify driver passed 16/18 matrix rows headless.

**The Director playtested it (2026-06-19)** — 57 M1.1 runs captured (`playtest_data/M1.1/run_log_2026-06-19.jsonl`).
RG2 analysis + RG3 recommendation: `design/M1_1_Tasks/G4_findings_M1.1.md`. **Verdict: ITERATE → M1.2.** The cost axis
half-landed (R2/R3 produced the timeouts M1.0 never had) but the build wasn't legible/fair: tiny levels, the hazard
never caught (`hazard_caught=0`), R2/R3/R4 fired invisibly. Triaged into I1–I5 + BUG4, which became M1.2.

**M1.1 close-outs (done):** Wave 1 — W1.1-1 Reviewed, W1.1-2 Addressed (breakdown §6 fix). Wave 2 — W2-R4-1 Addressed
(→ BUG4, now an M1.2 task). RG1 — W3-RG1-1/2 logged. All archived to `DESIGN_DEVIATIONS_HISTORY.md`.

### M1.1 shared as-built contract (was briefed to the wave-2 agents)

Specs predated the BUG2 merge; the real names: live depth = `GameState.current_depth_index`; max =
`GameState.max_depth_reached`; dist home = `GameState.current_dist_to_gate` (NOT `current_depth` — the stuck band-entry
counter); `EventBus.depth_changed(depth_index, max_depth)`; player already in the `"player"` group; `RunConfig` enums
are plain `@export_enum` ints (no named consts); `run_t_ms` on hazard_caught/exposure_crossed is TEL-stamped (emit 0);
all opposition/penalty signals pre-declared (emit only, never edit `event_bus.gd`); run-end via existing
`fail_run(&"death"|&"timeout")` (call, never edit `game_state.gd`).

### Done (M1.1 — Greybox Cost Axis)
| Task | Proof |
|---|---|
| RG1 — Playtest build (risk active) | merged `c4c71b8`; `tests/test_rg1_loop_verify.tscn` → **RG1 BUILD VERIFY OK** (16/18 matrix rows headless); R2 `ReturnCost` + R3 `ExposureMeter` wired as persistent self-gating nodes (DiveClock injected); "Back to Config" sell-screen button; worklog `worklogs/2026-06-19-RG1-general-purpose.md` (impl `6013c07`) |
| R1 — Pursuing/awakening hazard | merged `0c80622`; **PURSUING HAZARD OK**; `scenes/hazards/hazard_entity.{tscn,gd}`; worklog `worklogs/2026-06-19-R1-general-purpose.md` (impl `023c346`) |
| R2 — Costlier return trip | merged `b0566c2`; **RETURN COST OK**; `systems/oppositions/return_cost.gd`; worklog `worklogs/2026-06-19-R2-general-purpose.md` (impl `5c1f2a9`) |
| R3 — Exposure meter | merged `b0566c2`; **EXPOSURE METER OK** + **EXPOSURE HUD OK**; `systems/oppositions/exposure_meter.gd` + HUD bar; worklog `worklogs/2026-06-19-R3-general-purpose.md` (impl `87d2628`) |
| R4 — Maze/navigation risk | merged `b0566c2`; **R4 NAV OK** (fingerprint(seed+config); all-off byte-matches `e943ac9c8bc1`); `entities/dive/{vision_fog,lost_proxy}.gd`; flagged W2-R4-1; worklog `worklogs/2026-06-19-R4-general-purpose.md` (impl `b810aa0`) |
| (pre-decl) `depth_changed` | orchestrator pre-declaration `2450cde` (BUG2 §3) |
| R0 — Run-config data model | merged `30e41b9`; `RunConfig` + `GameState.active_run_config`; all-off = M1.0 baseline |
| BUG1 — `run_ended.duration_s` real | merged `33eb786`; **RUN DURATION OK**; worklog `2026-06-19-BUG1-BUG2-*` (impl `cf7e342`) |
| BUG2 — within-band depth tracked | merged `33eb786`; **WITHIN BAND DEPTH OK**; shared worklog w/ BUG1 (impl `cf7e342`) |
| TEL — Telemetry config-marking + signals | merged `c940ae4`; **TEL CONFIG MARKING OK**; sole `event_bus.gd` editor (11 signals); worklog `2026-06-19-TEL-qa` (impl `66ec131`) |
| BUG3 — sealed band | merged `c940ae4`; **BUG3 SOCKET SEAL OK**; `systems/bandgen/socket_sealer.gd`; worklog `2026-06-19-BUG3-*` (impl `f0baeae`) |

### Done (M1 — Greybox Core Loop)
| Task | Proof |
|---|---|
| A1 — Player scene + top-down movement | merged `a6503fc`; **MOVE OK**; worklog `2026-06-15-A1-programmer` (impl `a0a485d`) |
| B1 — Zone-piece authoring format (6 pieces) | merged `2e46681`; **ZONE PIECES OK**; worklog `2026-06-15-B1-programmer` (impl `81057c3`) |
| C1 — `JunkItem` resource + 8-item catalog | integrated `24280f8`; **JUNK CATALOG OK**; worklog `2026-06-15-C1-game-director-designer` (impl `e32e286`) |
| A2 — Interaction component | merged `5f9bbc3`; **INTERACT OK**; worklog `2026-06-15-A2-general-purpose` (impl `b8f60e3`) |
| A3 — In-dive clock + greybox meter | merged `744d6f5`; **DIVE CLOCK OK**; worklog `2026-06-15-A3-general-purpose` (impl `55088e5`) |
| B2 — Seeded room-graph generator | merged `869274b`; **BANDGEN OK**; worklog `2026-06-15-B2-general-purpose` (impl `c060d6b`) |
| D1 — Run-state slot inventory model | merged `b9a50f7`; **INV OK**; worklog `2026-06-15-D1-general-purpose` (impl `987c23f`) |
| C1b — Junk schema consolidation | merged `ce85b55`; **JUNK CATALOG OK**; worklog `2026-06-15-C1b-game-director-designer` (impl `202fb65`) |
| E1 — Gate node + extract-and-bank | merged `ce85b55`; **EXTRACT OK**; schema 1→2 + migration; worklog `2026-06-15-E1-general-purpose` (impl `9b18d83`) |
| D2 — Inventory UI (greybox) | merged `061c6aa`; **INV UI OK**; worklog `2026-06-17-D2-ui-ux-designer` (impl `0681894`) |
| B3 — Band depth / "push deeper" | merged `f78aff7`; **BAND DEPTH OK**; worklog `2026-06-17-B3-general-purpose` (impl `ffbe875`) |
| C2 — Junk pickup in the band | merged `aa9a610`; **JUNK PICKUP OK**; worklog `2026-06-17-C2-general-purpose` (impl `5adacac`) |
| E3 — Death/timeout drops haul | merged `1f18910`; **DEATH DROP OK**; `run_rules.tres`; debug-kill K; worklog `2026-06-17-E3-programmer` (impl `9f23851`) |
| E2 — Push/cash-out decision HUD | merged `43284f5`; **DECISION HUD OK**; worklog `2026-06-17-E2-ui-ux` (impl `7e0eb0a`) |
| D3 — Activate drop-to-swap re-spawn | merged `923a815`; **DROP SWAP OK**; worklog `2026-06-17-D3-ui-ux` (impl `e188a50`) |
| G5 — Meta save-migration fixture (v1→v2) | merged `0d6c484`; **SAVE MIGRATION OK**; CI-wired; worklog `2026-06-17-G5-qa` (impl `8655454`) |
| F1 — Money ledger (`sell_banked_junk`) | merged via F1 branch; **MONEY LEDGER OK**; worklog `2026-06-17-F1-programmer` (impl `54f4f59`) |
| F2 — Placeholder sell screen | merged `ce9f51b`; **SELL SCREEN OK**; worklog `2026-06-17-F2-ui-ux` (impl `ce9f51b`) |
| G1 — Wire M1 telemetry events | merged via `Merge G1`; **TELEMETRY OK**; `systems/telemetry/*` + opt-in `settings.cfg`; worklog `2026-06-18-G1-qa` (impl `c0c2268`) |
| G2 — Determinism & logic tests (GdUnit4) | merged via `Merge G2`; GdUnit4 v6.1.3 vendored; **30 cases · 0 failures**; CI gate wired; worklog `2026-06-18-G2-qa` (impl `3f57f38`) |
| G4 — M1 feedback gate (internal playtest) | run 2026-06-19, 34 runs/3 sessions; verdict **ITERATE** → `design/M1_Tasks/G4_findings.md`; surfaced BUG1–3 |
| G6 — In-build telemetry consent prompt | merged via `Merge G6`; **CONSENT OK**; `systems/settings/telemetry_consent_prompt.gd`; worklog `2026-06-18-G6-ui-ux` (impl `835a97a`) |
| G3 — Greybox playtest build | merged via `Merge G3`; **LOOP OK** + **MAIN GAME OK**; `main_game.tscn` = `run/main_scene`; `systems/version.gd`; `tools/playtest/*`; `export_presets.cfg` + scaffolded `nightly.yml`; worklog `2026-06-18-G3-programmer` (impl `9107a2a`) |

_M1 open test-hygiene nit (QA): B2's determinism scene leaks "2 resources still in use at exit" (un-freed PackedScene instances) — cosmetic, non-failing; port that scene to a GdUnitTestSuite to tidy._

### Done (M0 — Pre-production & Tech Foundations)
| Task | Proof |
|---|---|
| Toolchain installed (Godot 4.6.3, git-lfs 3.7.1, gh 2.94.0, pip/Pillow/numpy, uv) | `~/.local/bin`; `godot --version` |
| Repo scaffolding: LFS, `.gitattributes`, `.gitignore`, folders, `.godot-version` | LFS round-trip smoke passed |
| Godot M0 spike: autoloads + EventBus + RNG + GameState + SaveManager + Telemetry + AudioDirector | `tools/ci_smoke_test.gd` → **SMOKE OK** |
| Data-as-Resources pattern (`data/item.gd` + sample `.tres`) | loads headless |
| 8 role subagents installed + `Role_Playbooks/` authored | cross-ref check: 0 missing |
| MCP servers fal-ai / elevenlabs / pixellab | `claude mcp list` → all ✔ Connected |
| Orchestration system (`STATUS.md`, `TASKS.md`, worklogs, deviations log, CI) | files present |

### Prior next-action history (M1.0 build phase — for the record)

- **M1.0 G4 gate (2026-06-19):** ITERATE verdict (34 runs/3 sessions). Engaging (11 runs/session, ~18s median) but no cost axis → 30 extract / 2 death / 0 timeout. Director chose path A (iterate) → M1.1. Full evidence: `design/M1_Tasks/G4_findings.md`.
- **M1 wave-5 close-out (2026-06-18):** 16 deviations dispositioned (1 Addressed → built G6 consent prompt; 15 Reviewed). Reapplied to `M1_As_Built.md` + Playbook 07; archived. FU1/FU2 tracked as M1 follow-ups.
- **M1 wave 3 close-out (2026-06-17):** 24 deviations (21 Reviewed, 3 Addressed → translation gitignore, G5 save-migration fixture, D3 drop-to-swap). Wave 4 (E2/E3/F1/F2) → wave 5 (G1/G2/G3/G6) → G4.
- **M1 design decisions (2026-06-15):** `design/M1_Tasks/M1_Design_Decisions.md` — `Item`→`JunkItem` merge; `max_light = 60` confirmed.
- **M0 feedback gate:** internal tech review — architecture sound and iterable → human sign-off.
