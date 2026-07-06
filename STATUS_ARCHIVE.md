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

---

## M1.5 — Agency & Legibility — DONE 2026-06-24..26 (re-gated → ITERATE → M1.6)

Superseded `STATUS.md` live sections, moved here at the M1.6 version boundary. Tasks also archived → `TASKS_COMPLETED.md`;
re-gate provenance → `design/M1_5_Tasks/G4_findings_M1.5.md`; build detail → `design/M1_5_Tasks/`.

- **Wave 1 (Foundation + legibility, 2026-06-24):** L0 (8 knobs + 4 signals + CFG rows; as-built count 81→**89**, the
  breakdown's "88" was an arithmetic slip) · L3 (HaulValueLabel → below the timer, pure `.tscn`) · L4 (grab-prompt per-frame
  visibility invariant). Merges `fa7cdb9`/`5c9cd6c`/`b8520be`. All-off fp byte-identical `e943ac9c8bc1`. Close-out: L0-F1
  (88→89) → Director Reviewed.
- **Wave 2 (Agency & threat, 2026-06-24):** L1 (throwing: highlight selector + `thrown_item` Area2D mask world|hazard, kills
  pursuer/ping-pong, miss re-drops; input remap F/Q-E/Space) `873a062` · L5 (K5 `*_kills` toggles + retired
  `_driven_default_preset()`) `a2fe301` · L2 (spawn-room pursuer = room-bound slow patrol, `setup` widened to 3-arg) `1f4f67d`.
  Pushed (origin==local `155b9cf`); board L0–L5+RG1 back-filled. Close-out: L1-F1 (throw monotonic clock) → Reviewed.
- **Wave 4 (L6 control rework, 2026-06-25):** RG3 "controls clunky" → ITERATE-as-wave. L6 `302d2bd`: `resolve_aim()` decouples
  aim from movement (right-stick > deadzone → mouse-after-motion → hold-last → movement); player points at aim; throw on
  LMB/RT; cycle on wheel/LB-RB; Q/E+Space kept. Input-only — fp `e943ac9c8bc1` unmoved, 89 knobs, no save change. Close-out
  L6-F1 (keyboard-only-no-mouse aims DOWN) → carried to M1.6 backlog (mouse + controller unaffected).
- **Post-RG3 tuning (2026-06-25):** dive timer 600→300s · controller throw fires on press edge only (`_throw_held` latch) ·
  hazard fair-share allocation (30-room preset starved spikes → interleave ≈16/16/16). Gate green; fp unmoved. On `main`.
- **▶ (closed) Next action was:** re-publish to itch → Director re-test mouse/controller → RG3 verdict. **DONE → ITERATE → M1.6.**

---

# Archived 2026-07-02 — M1.9 Phase-4 sweep (superseded M1.2–M1.8-era STATUS sections)

## (archived — M1.8 Wave 1 build, on `main`, pushed) H0 + H1

> **M1.8 = Hub Art Dressing** (Director-directed, art-only iteration). Breakdown:
> `design/M1_8_Tasks/M1.8_Breakdown.md`. Source: `art_workshop/map_layouts/staging_area_layout_a_dressed.md`
> + `layout_a_assets/` (16 ground tiles + 24 props; gap analysis = nothing loop-critical missing →
> **no PixelLab run**; the one missing prop, the street threshold `SS`, is deferred (H3, paid/Director-gated)).
> **Contracts:** all-off fp **`e943ac9c8bc1`** + **89/89** held (no knob); **no save change**; portal/shop
> `Interactable` ids + collision + `hub.gd` node paths + wall-bounding are invariant (H1 is a re-skin).
> **Copy, never move** from `art_workshop/`.
>
> **✓ Wave 1 DONE (`main`@`11b8ff4`).** **H0** (`33f67d5`) copied 16 ground tiles + 20 props → `Game/art/hub/`,
> built `Game/data/tilesets/hub_ground.tres`; **H1** (`81a3c13`) re-skinned `hub.tscn` — `HubGround` TileMapLayer
> spine (asphalt S → dirt mid → litter N, scrap-wall border, central lane clean), `dive_gate`+`portal_glow` on
> `DeparturePortal`, `shack_door`+`workbench`+`sort_table` on `HubShop`, 15 dressing props y-sorted, camera 1.2→1.05.
> Visual-only re-skin: portal/shop `Interactable` ids + collision + `hub.gd` node paths + wall-bounding all invariant.
> Gate green: import · smoke · fp **`e943ac9c8bc1`** · **89/89**. Worklog `…-H0H1-hub-dressing-general-purpose.md`.
> Originals intact in `art_workshop/` (copy-not-move verified). **Asset gap:** street-threshold `SS` deferred (H3,
> PixelLab/paid/Director-gated) — not loop-critical.
>
> **▶ Wave 1 close-out (Director dispositions — 5 deviations in `design/DESIGN_DEVIATIONS.md`, all recommend Reviewed):**
> doorway-only shack (vs open-roof) · camera 1.05 · walls kept as re-tinted ColorRects · 15 props (vs ~10–12) · stale
> "24 objects" doc count (actual 20). + the carried PLAYERTAB (M1.7) entry recommends Addressed.
>
> **▶ Wave 2 = re-gate:** **HG1** (qa) verify matrix + `changelog.txt` (M1.7→M1.8: art-dressed hub) + publish to itch →
> **Director playtest** → **HG2** readability → **HG3** verdict in `design/M1_8_Tasks/G4_findings_M1.8.md`.
>
> **⚠ MANUAL (headless can't render here — Godot has no display server in WSL2):** the on-screen read — spine flows
> S→N, central lane clear, functional props (gate/shack) distinguishable from dressing, prop scale/busyness vs the
> player, golden-hour holds — is the core Director item. A compositing preview (`m1_8_hub_preview.png`, faithful coords +
> real assets, not an engine render) approximates it; the true render comes from the HG1 itch build or the editor.

---

## (archived — M1.7 build + fixes, all on `main`, pushed) Wave 1 build + post-build tweaks

> **✓ M1.7 WAVE 1 (BUILD) COMPLETE + VERIFIED ON `main`@`cffb5db` (2026-06-28), pushed.** The greybox player is replaced by
> the animated `player_basic_template` character (8-dir idle/walk + pickup/throw) in **both** Hub and Dive, plus a Meta-tab
> "Player art (debug)" toggle that swaps back to greybox. **Wave-1 close-out: 0 deviations** (`DESIGN_DEVIATIONS.md` empty).
> Integrated gate green: import · smoke · fp **`e943ac9c8bc1`** byte-identical · config **89/89** · `PLAYER_VISUAL OK` ·
> `MOVE OK`. Tasks N0 (`07edb77`) · N1 (`47ab9a8`) · N2 (`cffb5db`) — board=Done. Worklogs `…-N{0,1,2}-general-purpose.md`.
>
> **✓ Two Director-reported visual bugs FIXED + INTEGRATED (2026-06-28), pushed:**
> - **FIXINTERP** (`9e134fd`) — junk/player/hazard "jumps somewhere else for one frame" = `physics_interpolation=true`
>   teleport ghost with no `reset_physics_interpolation()`. Added the reset at 8 world-entity spawn-teleport sites
>   (junk_spawner.spawn_one, thrown-item, player+camera dive-start, hazard spawns, extract-gate). Render-only; fp unmoved;
>   junk/throw/loop tests green. Left the K6 per-tick camera smoothing alone. Worklog `…-FIXINTERP-general-purpose.md`.
> - **FIXEAST** (`a37d106`) — "throw-right character cut in half" = corrupt `throw/east` source (PixelLab neighbor-bleed in
>   all 7 frames; only east). **Regenerated east via PixelLab** (Director-authorized; char `3cb56375`, new anim `b03f703e`,
>   clean 7f), replaced in `Game/` + `art_workshop` source (corrupt originals preserved in git history + GENERATION.md note).
>   Bundled the recurring SpriteFrames uid-drift cleanup (godot-normalized `uid://bd2h7mfhen6uo` + player.tscn hint). Asset-only;
>   fp unmoved; player_visual/config 89 green. Worklog `…-FIXEAST-claude.md`.
> Both still need on-screen confirmation in RG1 (headless can't render the ghost-gone / the clean east throw).
>
> **✓ PLAYERTAB (`bb1976a`, 2026-06-28) — debug menu "Player" tab added, integrated, pushed.** New `CFG_TAB_PLAYER` tab holds
> the **Player art (debug)** toggle (MOVED off Meta) + live pickup/throw animation-lock controls: lock-on-pickup, animate-on-reject,
> lock-mode (Clip-driven/Fixed), and **separate `Pickup lock (s)` / `Throw lock (s)`** (per-action timing — replaced N1's shared
> cap/fixed; see `DESIGN_DEVIATIONS.md`, recommend Addressed). Live via new EventBus `debug_player_anim_config_changed`. Debug-only
> (outside MANIFEST): fp `e943ac9c8bc1` unmoved · **89/89** held · CLIP_DRIVEN default byte-preserved. Worklog `…-PLAYERTAB-general-purpose.md`.
>
> **✓ ART DEFAULT FLIPPED TO OFF (2026-06-28, Director-directed).** The shipped default is now **greybox (art OFF)** — the
> animated character is **opt-in** via the Player-tab toggle; with art off the pickup/throw movement-lock is also off (gated by
> `_art_on`). Changed: `player_visual._art_on=false`, `player.tscn` (AnimatedSprite2D hidden / greybox `Visual`+`Nose` shown),
> the Player-tab art `CheckButton` default unchecked, + the `test_config_menu` assertion. So the **default build == M1.6 look &
> feel**; turning art ON in the Player tab previews the new character. fp `e943ac9c8bc1` unmoved · 89/89 · smoke · player_visual OK.
>
> **▶ Wave 2 = RE-GATE.** **RG1** (qa): author `design/M1_7_Tasks/RG1_playtest_build.md` from the M1.6 template; run the M1.7
> verify matrix (8-way anim + toggle swap headless-provable parts; fp/89/smoke); **update `changelog.txt`** (M1.6→M1.7 delta:
> the player is now an animated character + a debug art toggle); **publish to itch** `BUTLER=/mnt/c/wsl-libraries/butler/butler
> bash Game/tools/push_itch.sh` (Chrome/Edge, password-gated; **network/human-gated**). Then **Director playtest** → **RG2**
> readability/telemetry → **RG3** verdict in `design/M1_7_Tasks/G4_findings_M1.7.md`.
>
> **⚠ MANUAL (headless can't render):** the on-screen confirmation — that idle/walk/pickup/throw read correctly in BOTH Hub
> and Dive, the scale 0.45 / y=-18 seats the character on the r=14 body, the toggle swaps art↔greybox live, and the
> movement-lock doesn't feel sluggish (flip `PlayerVisual.lock_mode=FIXED` in-editor if it does) — is the core RG1 item.

---

## (archived) M1.6 build waves — done (full detail in worklogs + `DESIGN_DEVIATIONS_HISTORY.md`)

- **Wave 1 (M0, `52d6e17`)** — persistent root `App` router (new `run/main_scene`) + 8 EventBus signals + neutral `GameState`
  economy surface + quota-decouple + staged-config accessor + `debug_menu_toggle`=P + greybox stubs. 0 deviations.
- **Wave 2 (M1 ∥ M2 ∥ M4, `40d328d`)** — Main Menu (`bbc61ff`) · walkable Hub + `main_game` dive-only refactor + hub-return
  quota/wipe (`7c5391e`) · P-tab debug menu + Vision split, 89-coverage byte-identical (`1d0c0dc`). Parallel worktrees,
  file-disjoint, conflict-free. Close-out: 3 items all **Reviewed** (W2-F1 m13 stale→FU3, W2-F2 quota banner→M3, L6-F1→FU4).
- **Wave 3 (M3, `f47d8fc`)** — Hub Shop sell+buy + 3-item persistent catalog + META **v3→v4** (migration + `meta_v3.sav`
  fixture) + SellScreen retired + quota-MISS notice. Close-out: 0 deviations.

---

> **Standing contracts (M1.6):** all-off `RunConfig` default = permanent baseline (fp `e943ac9c8bc1`); **89-knob count holds**
> (M1.6 adds no lever knob; M4 regroups only); Money/owned purchases are meta, in-dive haul is run-state; save bump v3→v4 lands
> in M3 (migration + `meta_v3.sav` fixture); `run_ended` arity locked (the router observes it, never changes it); M0 is the sole
> writer of `game_state.gd`/`event_bus.gd`/`project.godot`/`app.*`; clock is dive-only; verify branch topology before every merge
> (qa git-switch leak); push + board mirror after every merge; wave close-out deviation sweep.

## ✓ M1.5 — Agency & Legibility — DONE 2026-06-24..26 (re-gated → ITERATE → M1.6)

All waves built + re-gated (L0–L6 + RG1 + post-RG3 tuning): agency-throw + room-bound pursuer + legibility fixes + the L6
mouse-aim/twin-stick control rework. Director re-test → **RG3 ITERATE → M1.6**. Detailed in-progress notes archived →
`STATUS_ARCHIVE.md`; tasks → `TASKS_COMPLETED.md`; re-gate provenance → `design/M1_5_Tasks/G4_findings_M1.5.md`. **L6-F1**
(keyboard-only-no-mouse aims DOWN) carried to the M1.6 backlog (mouse + controller unaffected; non-blocking).

---

## ✓ Wave 2 (Oppositions retuned to the new canvas) — DONE (2026-06-19)

All three integrated on `main`, verified, pushed, board = Done. Determinism unmoved (fp=e943ac9c8bc1); none touched `main_game.gd`.
- **I2** hazard refuge fix (shrink body r10 + anti-wall-stick + depth-scaled catch + `r1_catch_radius_per_depth` knob, CFG 36/36) — merge `1966145`.
- **I3** R2/R3 cues (exposure ramp+ticks+penalty banner; return-cost pulse+floating −N; optional shake; all-off=M1.0 HUD) — merge `9b5d75d`.
- **I4** vision/fog rework (radial-dark occlusion ~0.94 + 3-state fog + lost edge-pulse/"DISORIENTED"; R4-off=M1.0) — merge `d56674d`.

Close-out: 0 formal deviations; 1 finding (W2.2-F1: R2 `exposure` toll fired its cue but didn't charge R3's meter — no `add()` on `exposure_meter.gd`) → Director: **fix now** → **BUG5** filed + dispatched.

---

## ✓ M1.2 DONE — re-gated, verdict ITERATE (2026-06-19)

Director playtested the RG1 build (33 runs, `ba745e1`). RG2 (`design/M1_2_Tasks/G4_findings_M1.2.md`): run-length ~2×
M1.1 (26.4s median), depth to 17, three-way end-causes (real hazard deaths), `duration_s` clean (I5 works). RG3 verdict:
**ITERATE → M1.3.** Director decisions + new issues (BUG6 hazard-spam, R3/R4 config traps) recorded in §5 of that doc.

## ✓ M1.3 Wave 1 (Foundation & correctness) — DONE (2026-06-19)

All 5 on `main`, verified, pushed, board=Done; all-off fp byte-identical (e943ac9c8bc1). Close-out: 2 Reviewed + 1 Addressed (history).
- **J5** depth counter → `Depth {depth_index} / {max}` via `depth_changed` — `50d8faf`.
- **BUG6** `hazard_caught` one-shot latch + `inert_enabled_oppositions()` warn-only traps — `ed176bf`; refined to maze-aware `r4_no_effect` (`25072f6`).
- **DLV2** in-game `JavaScriptBridge` telemetry-export button on the sell screen (web-guarded) — `2b00a09`.
- **DLV1** itch HTML5 delivery (Web preset + `push_itch.sh` + web templates + nightly slugs) — `02ad951`. ⚠ **real butler push human-gated** (sandbox can't reach `broth.itch.ovh`; run `tools/push_itch.sh` per SETUP §1a).
- **J1** `make_default_play_preset()` (19 rooms, size 4.0, R1 on, **R4 maze-only / occlusion OFF = match-played**, R2/R3 off) + `RANGE_MULT=[4.0,40.0]` — `3159aac` (+ `25072f6`).

## ✓ M1.4 Wave 1 — DONE (2026-06-21)

K0 + K3/K6 + K4 all on `main`, pushed, board=Done; all-off fp byte-identical (`e943ac9c8bc1`); 81 knobs.
- **K0** foundation (`74034bc`+`02b8a00`): 35 new knobs off/neutral + `to_flat_dict()` + 7 new signals + removed dead `light_low()` + CFG rows (46→81) + K1 retune (`r1_speed_per_depth→3.0`, `r1_catch_radius_per_depth→1.0`). Worklog `worklogs/2026-06-21-K0-general-purpose.md`. **Deviation for close-out:** K0 doc RD-1/RD-6 dropped the two quota enums (would be 79) but the Phase-4 Lock KEPT them → 81 as-built (reconcile the doc).
- **K3+K6** camera + jitter (`f3147d2`): `[display]` (canvas_items/integer/expand, base 1152×648) + `[physics]` `physics_interpolation=true`; camera reparented off the player to a level-owned `CameraRig`/`CameraView` (`entities/dive/camera_view.gd`) driving fixed visible-world-width from `cam_*`. Default-off = today's framing byte-for-byte. **Deferred check:** jitter-gone + fixed-FOV *look* are render-time, confirm in RG1 playtest on >60Hz hardware.
- **K4** timer + warning (`878fe1f`): `timer_length_s` override + one-shot `dive_clock_warning` latch + HUD visual cue + gated audio stub. All-off = today's clock.

## ✓ M1.4 Wave 2 (Stakes & spatial) — DONE (2026-06-21)

K2 + K7 both on `main`, pushed, board=Done; all-off fp byte-identical (**e943ac9c8bc1**); 81 knobs (0 new RunConfig fields — K0 pre-declared both groups). Wave-2 close-out: **0 deviations** (swept → `DESIGN_DEVIATIONS.md` empty).
- **K2** quota + roguelite wipe (merge `65a6cdf`): per-run quota (preset $50 +$50/run, every-run-end × cumulative-money, both swept knobs), miss = full **9-field meta wipe**; save META **v2→v3** + migration + `meta_v2.sav` fixture; HUD quota readout + SellScreen "QUOTA MISSED" + MainGame Continue→`wipe_meta()`→fresh start; Q8 `run_started` quota stamp. Verified: v1→v3 & v2→v3 migrations green, `test_quota_system` green. Worklog `worklogs/2026-06-21-K2-general-purpose.md`.
- **K7** exit placement (merge `8d9c884`): single fixed gate → 1..N gates, depth-scaled count, Strategy-A local-sub-stream random placement (`run_seed ^ EXITS_RNG_SALT`), `exit_keep_one_at_spawn` pin. Pure run-state — **no save/schema change**. Default/preset = today's single fixed gate (exits OFF). `test_exit_placement` green. Worklog `worklogs/2026-06-21-K7-general-purpose.md`.
- *qa git-switch leak recurred on BOTH builds; agents self-cleaned; topology verified clean before each merge (qa-agent-git-switch-leak memory holds).* 

## ✓ M1.4 Wave 3 (Danger variety) — DONE (2026-06-21)

K5a + K5b + K5c (parallel) + K5i (integration) all on `main`, pushed, board=Done; all-off fp byte-identical (**e943ac9c8bc1**); each entity RNG-free; node counts bounded by `NEW_HAZARD_BAND_CEILING=48`. All three ran as clean parallel worktrees (zero file overlap). qa git-switch leak recurred on each; agents self-cleaned; topology verified clean before every merge.
- **K5a** ping-pong bouncer (merge in `50ba1a7` chain): `CharacterBody2D`, straight travel + wall-reflect within `room_bounds`, distance kill, amber tell. `res://scenes/hazards/pingpong_hazard.tscn`. Worklog `2026-06-21-K5a-general-purpose.md`.
- **K5b** committed proximity bomb: proximity-arm (no-defuse) → pulse → detonate within `hbomb_blast_radius`; idle/amber/orange-red tells. `res://scenes/hazards/bomb_hazard.tscn`. Worklog `2026-06-21-K5b-general-purpose.md`. *(test emits harmless `queue_free`-on-freed stderr → **W3-F1**, awaiting Director disposition.)*
- **K5c** anchored rotating spikes: 3 arms (const), analytic point-to-segment kill (no CollisionShape2D), deterministic phase from `spawn_ctx.phase_salt`, steel/cyan tell. `res://scenes/hazards/spike_hazard.tscn`. Worklog `2026-06-21-K5c-general-purpose.md`.
- **K5i** spawn-seam integration (merge `91be51f`): `_spawn_new_hazards` sibling of `_spawn_r1_hazards`, descriptor table (pingpong→bomb→spike starvation order), per-room count `base+floor(per_depth*depth)` capped per-room + shared 48 ceiling, per-kind `spawn_ctx`, pure-deterministic; R1's `_density_spawn_positions` untouched (golden-guard added). `test_new_hazard_spawn` green. Worklog `2026-06-21-K5i-general-purpose.md`.

## ✓ M1.4 Wave 4 — RG1 build+verify — DONE (2026-06-21)

RG1 on `main` (merge `0da631f`; build commits `183d19f`/`aa58a99`), pushed, board=Done. **Director lifted the Wave-4 hold → RG1 built + verified + published to itch.**
- **Preset = M1.4 fun stack:** `make_default_play_preset()` now layers **K4** timer (60s dive / 10s near-end warning / visual-only) + **all three K5 hazards** (hpp/hbomb/hspike ON at RG1 sweep-START magnitudes, each with a mandatory `per_room_cap=2`, balanced ~9/9/9 under the 48 ceiling so all three spawn) on top of the M1.3 base + K2 quota + K3 camera. **K7 exits ship OFF** (Phase-3 lock). All-off code defaults untouched.
- **Headless `test_rg1_m14_verify`** (run as a SCENE: `godot --headless res://tests/test_rg1_m14_verify.tscn`) → **`RG1 M1.4 VERIFY OK`, exit 0**: preset shape, all-off fp byte-identical **`e943ac9c8bc1`**, no-leak into the control, `to_flat_dict()` carries all 81 knobs incl. K4/K5/K7, K5i spawn helper spawns ≥1 of each kind bounded by cap + 48 ceiling, extract/timeout end-causes reachable. 11 rows headless / 7 human-deferred.
- Gates re-run by orchestrator: import clean · smoke OK · run_config 81 · config_menu 81/81.
- Verify doc `design/M1_4_Tasks/RG1_playtest_build.md`; `loop_smoke_checklist.md` + `tester_readme.md` updated. Worklog `worklogs/2026-06-21-RG1-general-purpose.md`.
- **itch published:** `qusto/the-far-yard:html5 @ m1-20260621-...` (Chromium-only, password-gated). *(Re-published post-merge so the live build matches final `main`.)*

> **Board drift flagged (2026-06-21):** the GitHub Project only carries items through M1.1 (R0/CFG); the M1.2/M1.3/M1.4 `J*`/`K*` tasks were never added despite STATUS marking them "board=Done." RG1 item created + set Done (`PVTI_lAHOAAXnOs4BasyMzgwZAFk`); back-filling the ~20 missing items is a Director call (surfaced, not silently done).

> **Wave-4 RG1 close-out (2026-06-21):** 1 deviation flagged by the build agent → **RG1-F1** (the K5 sweep-start magnitudes — chose modest base 0 / per_depth 0.15 / cap 2 so all three hazards spawn rather than pingpong starving spikes at the shared 48 ceiling; the load-bearing constraint "every type must spawn in the default" was held; values are an explicit RG1 sweep the Director delegated). **Awaiting Director disposition** (recommend **Reviewed**). `DESIGN_DEVIATIONS.md` carries it.

## ✓ M1.4 Wave 5 (RG1-feedback bug-fixes) — DONE (2026-06-21)

Director playtested the RG1 itch/desktop build → **RG3 verdict = ITERATE, packaged as an M1.4 bug-wave + re-gate**
(not a full M1.5). RG2 telemetry analysis + 6-item triage in `design/M1_4_Tasks/G4_findings_M1.4.md`. Four file-disjoint
tasks ran as parallel worktrees; all merged to `main`, all-off fp **byte-identical e943ac9c8bc1**, board=Done. Full
suite green (import · smoke · run_config 81 · config_menu 81/81 · rg1_m14_verify · new_hazard_spawn · pingpong · spike ·
exit_placement(_count)).
- **BUG7** (`main_game.gd`, merge `5bcc89b`; fix `a5b1b57`) — **feedback #7 (CRITICAL)**: `_spawn_new_hazards` skips the
  depth-0 entry piece + filters cells within `NEW_HAZARD_SPAWN_SAFE_CELLS=2.5` of the entry-spawn (mirrors
  `_exit_candidate_cells`). `base_count ≥ 1` no longer spawn-kills at frame 0. Telemetry root-cause: `s_384be7` runs 19–47.
- **BUG8** (`pingpong_hazard.gd`, merge `8c2f283`; fix `b11571c`) — **feedback #2**: tracks intended heading `_dir` and
  reflects IT (summed normals at corners), so `move_and_slide`'s tangential mutation never feeds the bounce → no wall-stick.
- **TUNE2** (`run_config.gd` preset + `test_rg1_m14_verify.gd`, merge `17b0e72`; fix `7854ddd`) — **#1** cam 576→**1000**;
  **#3** spikes `base 0→1` / `cap 2→1` so a spike reliably spawns at shallow depth (≈37 hazards combined < 48 ceiling, spikes
  not starved). Added `_driven_default_preset()` (K5 off for the driven end-cause matrix only; full preset still shape-checked).
- **FB5** (new `test_exit_placement_count`, merge `73530d5`; `3e1c95b`) — **#5 VERDICT: NOT a bug.** Multi-exit placement is
  correct (depth-scaled distinct gates scattered across pieces); the Director saw it during the #7 instant-death runs that never
  left depth 1. Regression test added. *Note for Director: exits are placed once per band at build time across its pieces — no
  NEW gates appear as you walk deeper within one band (that'd be a net-new "progressive spawn" feature, K7 DR-7 deferred).*

**#6** (spawn-room-only pursuer) is **deferred to M1.5**, semantics LOCKED by the Director: **slow patrol** — the pursuer
keeps patrolling within its spawn room but never chases the player outside it; chases only while the player is in that room.

### ▶ Next action (start here on a cold restart) — re-publish RG1 to itch, then re-gate

1. **Re-publish the fixed build to itch** (standing playtest-gate step): `bash tools/push_itch.sh` with
   `BUTLER=/mnt/c/wsl-libraries/butler/butler` (Chromium-only, password-gated; SETUP §1a). Human-gated on a real network.
2. **Director re-gate playtest** of the Wave-5 build (camera 1000, spikes now visible, no auto-end, ping-pong unsticks);
   export telemetry; record **go → M2 / iterate → M1.5** in `design/M1_4_Tasks/G4_findings_M1.4.md`.
3. **Wave-5 close-out deviation sweep** (below) — Director dispositions before any M1.5 work.

> **Wave-5 close-out — for Director disposition:** (a) **TUNE2 `_driven_default_preset()`** — the verify driver now
> disables the three K5 hazards for its scripted end-cause matrix because shallow spikes kill the driven player (no
> per-hazard `kills` toggle like R1's `r1_catch_kills`); shape-checks + spawn-checks still run the full preset. Recommend
> **Reviewed** (test-harness accommodation, not a design change) — or Addressed if a `*_kills` toggle is wanted on the K5
> family. (b) **Stale `.tscn` UID drift** — 11 scene files showed pre-existing local UID-regen at session start; current
> `--import` does NOT reproduce them and HEAD builds/tests clean, so they were set aside in `git stash@{0}` (not reapplied,
> not dropped). Recommend dropping the stash unless the Director wants those UIDs investigated.

---

## (superseded) ▶ M1.4 RG2/RG3 re-gate — Director played → ITERATE (see Wave 5 above)

RG1 is done + published. The re-gate now hands off to the **Director**:
1. **Director playtest** — play the itch build (and/or a desktop config sweep) across the M1.4 fun stack + variants; export telemetry (in-game "Export telemetry" button on web; `user://telemetry/run_log.jsonl` on desktop).
2. **RG2 (`qa`)** — analyse the returned telemetry: per-config distributions side-by-side across **M1.0/M1.1/M1.2/M1.3/M1.4**; did stakes (quota+wipe), variety (3 new hazards), and the legibility fixes (camera/timer/jitter) land? **OQ-3 carry-forward:** confirm worst-case ~112-body (R1 64 + new 48) tick-time on the web build is acceptable.
3. **RG3 (Director)** — record **go → M2 / iterate → M1.5 / pivot** in `design/M1_4_Tasks/G4_findings_M1.4.md`. Claude assembles + recommends; the human plays + decides.

Also pending the Director: **RG1-F1 disposition** (above) and the **board back-fill** call.

> **Standing contracts (M1.4):** all-off `RunConfig` default = permanent baseline (fp e943ac9c8bc1); fun values only in `make_default_play_preset()`; config-marked telemetry; `run_ended` arity locked; single-writer-per-`.gd`-file per wave; parallel agents `isolation: worktree`; verify branch topology before every merge (qa git-switch leak — memory); push + board mirror after every merge; wave close-out deviation sweep.

> **Wave-1 close-out sweep DONE (2026-06-21).** 3 deviations dispositioned → archived to `DESIGN_DEVIATIONS_HISTORY.md`:
> K0 count (Reviewed, as-built 81 per Lock) · K3/K6 render-time deferred-checks (Reviewed → RG1 matrix) · **camera now
> ENABLED in the preset** (Addressed: `make_default_play_preset()` → `cam_enabled=true`, `cam_visible_world_width=576`,
> `cam_zoom_policy=fit_width`; smoke OK, all-off fp `e943ac9c8bc1` unchanged).

> ⏸ **BUILD PAUSED after Wave 1 at the Director's request (2026-06-21).** Resume by dispatching **K2** (the first Wave-2
> task) per the step above. Design is locked, Wave 1 is integrated + pushed; nothing is mid-flight.

> **Contracts (M1.4):** all-off `RunConfig` default = permanent baseline (fp=e943ac9c8bc1); fun values ship in
> `make_default_play_preset()`; quota = every-run-end × cumulative-money, miss = full wipe (Director FINAL); config-marked
> telemetry (every knob → `to_flat_dict()` + test counts); `run_ended` arity locked; K0 pre-declares ALL new signals up front;
> single-writer-per-`.gd`-file per wave; parallel agents `isolation: worktree`; **verify branch topology before every merge**
> (qa-agent `git switch` leak — memory); push after every merge; board mirror; wave close-out deviation sweep.

> **Carry-over (non-blocking):** wire `tests/test_rg1_m13_verify.tscn` into the CI test set when convenient; butler push
> stays human-gated on a real network (SETUP §1a, Chromium-only) — relevant again at M1.4 RG1.

---

## ✓ M1.3 — Legibility & Density — DONE 2026-06-21 (re-gated → ITERATE → M1.4)

Waves 1/2 (J1·J2·J3·J4·J5·BUG6·DLV1·DLV2) + RG1 all on `main`; all-off fp byte-identical (e943ac9c8bc1). RG1 (`d9138c7`)
verified (`test_rg1_m13_verify` → **RG1 M1.3 VERIFY OK**), published-gate human. Director playtested → **RG3 verdict ITERATE**;
feedback work-order → M1.4 (`design/M1_3_Tasks/G4_findings_M1.3.md`). Detailed Wave-1/2 in-progress notes archived → `STATUS_ARCHIVE.md`.

---

## ✓ Wave 1 (Spatial & data foundation) — DONE (2026-06-19)

All three integrated on `main`, verified, pushed, board = Done. All-off default still byte-matches the M1.1 baseline (fp=e943ac9c8bc1).
- **I1** configurable level scale (count override + size mult + 4 new larger greybox pieces behind a config-dependent ext catalog) — merge `e67532c`. Worklog `worklogs/2026-06-19-I1-general-purpose.md`. *Empirical: linear spine reached requested count up to 60 — no count ceiling in the realistic range; run-time is the binding constraint (RG1/RG2 tuning).*
- **BUG4** geometry-keyed branch-rate-independent seal — merge `eee4418`. 508 void cells → 0 across 36 high-branch bands; fingerprint byte-identical. Worklog `worklogs/2026-06-19-BUG4-general-purpose.md`.
- **I5** telemetry hygiene (duration loop-re-entry regression-lock + real HEAD-SHA bake, `+dirty`) — merge `1fd657e`. Worklog `worklogs/2026-06-19-I5-qa-playtest-coordinator.md`.

Close-out: 4 deviations (I1-1, I1-2, + 2 lingering M1.1 RG1 entries), **all Director-Reviewed**, reapplied (`M1_As_Built.md` socket-width rule; `RG1`/`CFG` magic-count prose) + archived → `DESIGN_DEVIATIONS_HISTORY.md`. `DESIGN_DEVIATIONS.md` empty between waves.

---

## ▶ Next action (start here on a cold restart) — **finish BUG5, then dispatch Wave 3 (RG1)**

Waves 1 & 2 are on `main` (new spatial canvas + clean telemetry + retuned/legible oppositions). **BUG5 is in flight** (the
last build fix before the re-gate — makes R2's `exposure` toll actually charge R3). When BUG5 returns:
1. **Verify + integrate BUG5** (verify topology first — the Wave-1 stray-`git switch` lesson), push, board=Done, run its mini close-out.
2. **Dispatch Wave 3 — RG1** (`general-purpose` + `qa-playtest-coordinator`): author the M1.2 RG1 build+verify doc from the
   `design/M1_1_Tasks/RG1_playtest_build.md` template; assemble the runnable M1.2 loop; verify each fix individually + stacked;
   confirm config-marked telemetry writes; multiple runs/session. **BlockedBy: I1, BUG4, I5, I2, I4, I3 (all done) + BUG5.**
3. **RG2/RG3 are HUMAN-GATED** — RG1 hands off to a **Director playtest** (sweep configs on a dev machine), then `qa` analyses
   the telemetry vs the M1.0 (all-off) + M1.1 baselines (RG2), and the Director records the go/iterate/pivot verdict in
   `design/M1_2_Tasks/G4_findings_M1.2.md` (RG3). Claude assembles + recommends; the human plays + decides.

> **Collision note for Wave 3:** RG1 is largely additive scene-assembly + a verify test; it touches `main_game.gd` (loop
> wiring) + a new RG1 verify test. It's sequential (single task), so no parallel-collision management needed. Confirm no new
> `event_bus.gd` signal is required (the M1.1 RG1 needed none).

> **Standing process (locked):** parallel agents in `isolation: worktree`; pre-declare any new `event_bus.gd` signal on `main` before a parallel wave; single-writer-per-`.gd`-file; push `main` after every merge; mirror task status to the board; run the **wave close-out deviation sweep** after each wave (Director dispositions). See `CLAUDE.md` orchestrator loop.

**Also open (independent, Todo, non-blocking):** FU1 `test_jsonl_writer` · FU2 `EconomyMath`.

---


---

## M1.9 build waves — Done tables (archived 2026-07-05 at the M1.10 version boundary)

Specs also in `TASKS_COMPLETED.md` §M1.9; worklogs under `worklogs/`. SG1 published
`m1-20260704-55ca78f`; SG2/SG3 remain Director-pending (live in `STATUS.md` §M1.9 pointer + `TASKS.md`).

### Wave 5 — Done (2026-07-03)
| Task | Agent | Merged | Proof |
|---|---|---|---|
| S8 — Second hub portal + band routing + telemetry band-stamp | general-purpose | `a357e47` | Portal 2 "Dive — The Sump" ember-orange at (220,-150); `BAND_ROUTES` live; portal 1 tscn zero-byte diff; `band_id` both routes; `test_band_routing`+`test_hub_contract` green. 1 deviation. |
| S9 — DeckEntry override wrapper (D-RAT-2 delivery) | general-purpose | `ac289db` | `test_deck_entry` green (empty-wrapper ≡ plain ref; precedence def<deck-entry<rc; band_two charger gets D-RAT-2 values); charger def-default pin intact; fps unmoved. Deviations: none. |

### Wave 4 — Done (2026-07-03)
| Task | Agent | Merged | Proof |
|---|---|---|---|
| S4 — Generated debug-menu sections + coverage 91 + sweep hygiene | general-purpose | `e95a892` | 91/91 + per-def bijection; count-agnostic Oppositions tab (6 defs post-merge); dotted stamp; neutral-card trap; `debug_dirty` hygiene; tier-v1 respawn. 5 deviations. |
| S6a — Charger "The Wrecker" | general-purpose | `250cee1` | ChargeLane (the ONE new script); `charger.tres` D-RAT-2 letter defaults (test-pinned); `test_charger` 11 groups green; goldens intact. 4 deviations. |
| S6b — Splitter | general-purpose | `5ac1fa7` | `test_splitter` green (throw-death-only split, cap refusal, freed-parent headroom, fp byte-identical across a forced split); 6-def bijection; goldens intact. 6 deviations. |
| S7 — band_two "The Sump" | game-director-designer | `025d37a` | `test_band_two_profile` C0–C6 green 9 seeds; greybox fp untouched; tint `Color(0.82,0.66,0.42)`; deck completed 4→6 at integration. 2 deviations. |

### Wave 3 — Done (2026-07-03)
| Task | Agent | Merged | Proof |
|---|---|---|---|
| S3 — EncounterBuilder + RunConfig generic levers + both call-site integrations | general-purpose | `d9f5377` | Integrated matrix 23 tests + smoke green (incl. m13 first-run); fp `e943ac9c8bc1` through the new call sites; preset cohort byte-parity; 89/89 held; 91 knobs stamped. 5 deviations. |

### Wave 2 — Done (2026-07-03)
| Task | Agent | Merged | Proof |
|---|---|---|---|
| S2 — Opposition component extraction + `param_schema` | general-purpose | `e851a8c` | Golden frame-trace parity byte-identical (5 traces); dual-emit twins 1:1; defs + bijection test; throw seam + LethalContact external seam. 4 deviations. |
| S5 — Band flavor stages + connectivity guarantee | general-purpose | `0aa085c` | `test_band_flavors` F1–F8 green 9 seeds; parity UNMODIFIED green; strand-proof at max decay. 4 deviations. |

### Wave 1 — Done (2026-07-02)
| Task | Agent | Merged | Proof |
|---|---|---|---|
| S0 — SpawnService + OppositionDef data layer + EventBus pre-declare | general-purpose | `84785cf` | Full matrix green incl. golden `test_new_hazard_spawn` unmodified + new `test_spawn_service`. 2 deviations. |
| S1 — BandProfile + BandPipeline + `band_greybox.tres` | general-purpose | `9a8c6fb` | Parity byte-match 9 seeds, purely additive. Deviations: none. |

---

---

# (archived 2026-07-06, at M1.11 open) M1.10 build waves, close-outs + superseded next-action

> Moved out of `STATUS.md` when M1.11's build phase opened. M1.10's build was complete +
> published; only the Director playtest → TG2 → TG3 remained (pointer stays in `STATUS.md`).

## (archived) M1.10 design-locked note

> **M1.10 design LOCKED (2026-07-05):** breakdown + 6 per-task designs each with a BINDING
> `Resolved Decisions (Phase 3)` section; 13 cross-task amendments + Director ratifications
> **D-RAT-1…9** folded into `design/M1_10_Tasks/M1.10_Breakdown.md`. Headlines: Ambusher +
> Burrower "Sinkmaw" (band-3-exclusive, fatal `kills`-gated); band 3 = **"The Warren"**
> (cave/CA backend, blue-violet tint, cave-teal portal glow, deck 6/3/4/1 @ 1.30/31-credit);
> cave gate snaps-to-floor; cave walls = 1-tile sealer shell; portal 3 @ (110,-20). TASKS.md
> §M1.10 + board items T0–TG3 wired (T0/T2a/T2b In Progress).

## (archived) FBM19 / FBM19b feedback-fix notes (M1.9 re-test line)

> **✓ FBM19 feedback fixes LANDED + REPUBLISHED (2026-07-03/04, build `m1-20260704-72fd565`).** Director's 3 playtest
> reports fixed on `main`@`5dec90c`: **FB1** split reliability — shards now bypass the BUG7 entry-safe refusal + per-room
> cap via explicit ctx escapes (`ignore_entry_safety` new on SpawnService; per_band 8 + group 48 ceilings unchanged);
> **FB2** deck lane is def-major with J2-style even-spread over eligible pieces — charger/splitter now reach the deepest
> third (test-proven); **FB3** splitter `aggro_radius=160` latch param (0=legacy; child 0; Oppositions-tab tunable, gloss
> added). Full matrix green; changelog descriptions updated in place. Worklog `…-FBM19-general-purpose.md`. Deviations: none.

> **✓ FBM19b LANDED + REPUBLISHED (2026-07-04, build `m1-20260704-55ca78f`).** Oppositions tab now surfaces
> deck-spawned hazards: charger/splitter chips read "IN DECK: band_two · n tuned" (tooltip names the band; OFF only
> for truly nowhere-spawning defs), their sections open PRE-EXPANDED, and a new end-to-end case stages the Director's
> 4 knobs (aggro_range/charge_speed/aggro_radius/move_speed) through the menu path and proves band_two spawns receive
> them on top of the D-RAT-2 deck layer. 91/91 + fps intact. Worklog `…-FBM19b-general-purpose.md`. Deviations: none.
> Director-flag (worklog): section bodies stay dimmed for not-enabled deck defs (redundant-cue rule) — say the word to undim.

## (archived) M1.9 SG1 Director-playtest checklist (superseded by the M1.10 build `d04bd13` — SG2/SG3 still pending)

> Play **https://qusto.itch.io/the-far-yard** (Chrome/Edge only, password-gated), build **`m1-20260704-55ca78f`** (FBM19b tab-surfacing build; supersedes `72fd565`/`8412732`). Re-check the 3 fixed items: splitter always splits on throw-kill (even at the band entrance / two in one room) · Wrecker+Splitter present deep into The Sump · splitter lurks until ~on-screen range then latches (tune `aggro_radius` in the Oppositions tab if 160 feels wrong).
> Checklist (full version: `SG1_playtest_build.md` §5): both portals from the hub · band 1 = control feel
> (unchanged M1.8) · **The Sump reads as a band apart** (branchy/flooded/vault/sepia tint/denser opposition) ·
> **The Wrecker**: bait → dodge → punish; throws MISS mid-dash (intended); wall-crash = longer stun ·
> **Splitter**: throw-kill splits into 2 (children terminal); non-throw kill doesn't · P-menu **Oppositions tab**:
> tune + respawn (marks the run debug-dirty) · **Export telemetry** (in-game button) when done.
> Then **SG2** (qa telemetry/balance analysis) → **SG3** verdict (go/iterate/pivot) in `G4_findings_M1.9.md`.
> Watch-items for SG3: content=data proof cost (host shell, LethalContact seam) · promote charger/splitter to band 1? ·
> legacy-signal retirement · ceiling numeric merge · CaveBackend/ScatterBackend next? · hub iso prop re-dress.

## (archived) M1.10 Wave 1 — Done + integrated on `main` (2026-07-05)
| Task | Agent(s) | Merged | Proof |
|---|---|---|---|
| T0 — CaveBackend + `CaveBandConfig` + pipeline dispatch | general-purpose | `cfef9f7` (br `…a8c1cc4`) | `test_cave_backend` OK (C1–C10, 9 seeds; sample seed 12345 → 49 pieces, max_depth 12, cave fp `d984fd8913bf`); `test_band_pipeline_parity` + `test_bandgen_determinism` OK, socket-path fp **`e943ac9c8bc1`** byte-identical (greybox + band_two); ~475-line cost ledger, **0 new downstream lines**. Worklog `…-T0-general-purpose.md`. **3 deviations (all rec Reviewed).** |
| T2a — Ambusher (def + `Concealment` component) | general-purpose (+ character-animator) | `3d17bf0` (br `…a19da54`) | `test_ambusher` OK (all cases: HIDDEN pass-through layer 0, arm/tell/pounce, `kills`-gate + BUG6 once, EXPOSED throw-kill, one-shot); all-off fp unmoved; 39-line `Concealment`, **0 shared-file edits**. Worklog `…-T2a-general-purpose.md`. Deviations: none. |
| T2b — Burrower "Sinkmaw" (def + `BurrowCycle` component) | general-purpose (+ character-animator) | `26ef5e9` (br `…a6048d5`) | `test_burrower` OK (11 cases: buried pass-through, dodge frame, wall-clear surface, `kill_radius=34` surfacing-frame kill, positional desync); all-off fp unmoved; 212-line ledger, **0 shared-file edits**. Worklog `…-T2b-general-purpose.md`. Deviations: none. |

> **Integration done (`57f2a81`):** three worktree branches merged (file-disjoint, verified); both
> T2a (12) + T2b (9) `CFG_FIELD_*` gloss rows applied to `config_strings.csv` in one commit (`57f2a81`);
> the def schemas reference those exact keys (verified). Integrated verify ALL GREEN: import · cave ·
> parity · bandgen · ambusher · burrower · **9-def bijection** · socket-path fp `e943ac9c8bc1` · smoke.
> Board T0/T2a/T2b = Done.

> **✓ Wave-1 close-out swept (2026-07-05):** the 3 T0 deviations were Director-**Reviewed** and archived
> → `DESIGN_DEVIATIONS_HISTORY.md` §"M1.10 Wave-1 close-out". T2a/T2b: none.

## (archived) M1.10 Wave 2 — Done + integrated on `main` (2026-07-05)
| Task | Agent(s) | Merged | Proof |
|---|---|---|---|
| T1 — Cave materialisation + backend-agnostic sealing | general-purpose | `8da0b1f` (br `…a8674f3`) | `test_cave_materialise` M1–M9 OK (closure · collision truth via point query · fp+floor_fp pre/post byte-equal · anchors max_depth≥4 · **snapped gate** on floor + reachable · 2×2 throat cert · junk/encounter land on floor at depth>0 · tint; socket control = **0 synthetic hosts**); socket byte-identical (fp `e943ac9c8bc1`; hub/routing/rg1 suites green UNMODIFIED); **39-line `main_game.gd` ledger, 0 socket-path files changed** (SocketSealer now the single wall-writer for both backends). Worklog `…-T1-general-purpose.md`. **Deviations: none.** |

> **✓ Wave-2 close-out (2026-07-05): 0 deviations — clean wave, no Director gate.** Waves 1+2 = the full
> cave stack (backend → materialisation → 2 oppositions), all controls byte-identical. **Cost so far:
> ~765 bespoke lines for a whole new generation backend + 2 oppositions, 0 new downstream lines.**

## (archived) M1.10 Wave 3 — Done + integrated on `main` (2026-07-05)
| Task | Agent(s) | Merged | Proof |
|---|---|---|---|
| T3 — `band_three.tres` "The Warren" (cave band as data) | general-purpose (game-director-designer/environment-artist scope folded in) | `025dfa2` (br `…ac7af44`) | `test_band_three_profile` OK (loads as cave band, deterministic + connected + reaches depth axis 9 seeds; **band_greybox AND band_two byte-identical** — 9 absolute golden fp pins; deck spawns the D-RAT-6 outcome **ambusher 6 / burrower 3 / splitter 4 / bomb 1 = 14** at the 31-credit budget, spends to 0); `max_depth≥4` + 2×2 throat re-asserted on the authored config; all-off fp `e943ac9c8bc1` unmoved; import + smoke green. Files: 3 new `.tres` (77 lines) + 1 test (528). Worklog `…-T3-general-purpose.md`. **Deviations: none.** |

> **✓ Wave-3 close-out (2026-07-05): 0 deviations — clean wave, no Director gate. HEADLINE COST RESULT:
> band 3 = 0 production-code lines** (`git diff --stat` empty; not one existing `.gd`/`.tres` touched) —
> **cheaper than band_two** (M1.9 S7 cost 1 glue line + a schema field). The tint field, cave dispatch,
> and `DeckEntry` lever all shipped earlier; a whole new differently-generated band is now pure `.tres`.
> The "content = data" thesis is proven on evidence for a second, CA-generated backend — the TG3 headline.

## (archived) M1.10 Wave 4 — Done + integrated on `main` (2026-07-05)
| Task | Agent(s) | Merged | Proof |
|---|---|---|---|
| T4 — Third hub portal + `band_three` routing | general-purpose | `b9e3944` (br `…a47bf5b`) | `test_hub_contract` OK (4 interactables; portal 1 `&"near"`/WHITE + portal 2 `&"band_two"`/ember UNCHANGED, portal 3 `&"band_three"`/cave-teal (110,-20)); `test_band_routing` OK (all 3 routes distinct fp, `band_id == route key` for all, wipe-isolated); band_greybox+band_two byte-identical; all-off fp `e943ac9c8bc1` unmoved; no save change. **Cost ledger: exactly 1 bespoke line** (the `BAND_ROUTES` row) + 9-line scene block + tests. Worklog `…-T4-general-purpose.md`. **Deviations: none.** |

> **✓ Wave-4 close-out (2026-07-05): 0 deviations. M1.10 BUILD COMPLETE (T0–T4).** Total marginal cost of
> the whole milestone: CaveBackend ~475 + materialisation 39 + Ambusher ~130 + Burrower 212 + band 3 **0**
> + portal 3 **1** = a second generation backend, two oppositions, a full new band, and its portal, with
> **0 new downstream lines** and every control byte-identical throughout. TG1 next assembles the build.
>
> **TG1 surfaced (Director eyeball at the playtest, not blockers):** plaza-forward portal-3 composition +
> the spawn→portal-2 transit prompt (one-line nudge available); cave-teal renders as deep cyan-blue
> through the glow art's violet multiply (a brighter read needs a Director-gated retone; H7 pins the
> property so a retone won't break the test); plaza has ONE safe portal slot left → band 5 forces a
> band-select surface (TG3 watch-item).

> **M1.9 build-wave Done tables** (S0–S9, all merged 2026-07-02/03) archived → `STATUS_ARCHIVE.md`
> §"M1.9 build waves". SG2/SG3 remain the only open M1.9 surface.

## (archived) ▶ prior next-action (M1.10 — superseded by M1.11's)

> HOLD for the Director playtest of `m1-20260705-3c9644e`. On the Director's return (telemetry +
> felt-loop read) → dispatch TG2 (qa telemetry/balance analysis) → assemble TG3 verdict. Nothing to
> build; M1.10 is build-complete + published.
>
> **M1.10 = the second architectural axis** (Director-directed 2026-07-04; design LOCKED 2026-07-05):
> a **CaveBackend** (cellular-automata caverns — no pieces/sockets) behind the same `BandPipeline`, proven by
> **band 3 "The Warren"** + two low-sightline oppositions (**Ambusher** + **Burrower "Sinkmaw"**) behind a third
> hub portal. Every build worklog carries a **cost ledger** (bespoke lines beyond the promised backend/component
> = TG3's scalability evidence). Breakdown + 13 cross-task amendments + ratifications **D-RAT-1…9**:
> `design/M1_10_Tasks/M1.10_Breakdown.md`. Task queue + DoD: `TASKS.md` §M1.10; board items T0–TG3 created.
> **✓ Wave 1 DISPATCHED → all waves landed (see the archived wave tables above).**
> **✓ M1.9 build DONE + SG1 published** (`m1-20260704-55ca78f`); SG2/SG3 Director-pending, non-blocking.
> **✓ M1.8 CLOSED (2026-07-02).**
