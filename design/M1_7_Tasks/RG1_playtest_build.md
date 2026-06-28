# RG1 — M1.7 Playtest Build (Player Embodiment — the box becomes a character)

**Task id:** RG1 · **Milestone:** M1.7 (Player Embodiment) · **Workstream:** the re-gate · **Wave:** final (sequential, after the N-tasks integrate)
**Assignee:** `qa-playtest-coordinator` (build assembly verification — integrated across the M1.7 N-tasks) + the verify matrix
**dependsOn:** **N0** (art import → SpriteFrames) + **N1** (player visual state machine) + **N2** (debug Player-art toggle + movement-lock controls) all integrated on `main`
**Companion docs:** `M1.7_Breakdown.md` (the locked architecture + the one thing this version must prove), `N0_art_import_spriteframes.md` / `N1_player_visual_state_machine.md` / `N2_debug_player_art_toggle.md` (the per-task designs + their Resolved Decisions), `M1_6_Tasks/RG1_playtest_build.md` (the template this mirrors), `M1_6_Tasks/G4_findings_M1.6.md` (the prior shipped version, for the changelog delta), `M1_Tasks/M1_As_Built.md` (canonical APIs), `systems/event_bus.gd` (the `debug_player_art_toggled(enabled)` tooling signal), `ui/config/config_menu.gd` (the P-key debug menu + the new **Player** tab), `systems/save_manager.gd` (`META_SCHEMA_VERSION == 4`, `RUN_SCHEMA_VERSION == 1` — **unchanged in M1.7**).

> **This is the VERIFY + DOCUMENT + PUBLISH task, not new gameplay.** Every M1.7 system (N0 art import → 8-direction SpriteFrames, N1 the player visual state machine, N2 the debug Player-tab toggle + movement-lock knobs) was built and merged before RG1. M1.7 is a **visual / tooling** iteration: it gives the player an animated character **as an opt-in**, gated behind a debug toggle, while the build still **boots to the M1.6 greybox** for byte-for-byte parity. RG1 (a) confirms the build **boots greybox = M1.6** and the animated character renders in both Hub and Dive when the toggle is flipped, (b) confirms the **dive is UNCHANGED** — the all-off control is still byte-identical (fp `e943ac9c8bc1`) — (c) confirms the **89-knob count holds** (the Player-tab controls are debug-only, outside the MANIFEST), (d) confirms **no save-schema change** (player art is run-agnostic; nothing persists), and then (e) hands the Director a playable build (published to itch by the orchestrator) + the changelog for the re-gate (RG2/RG3).

---

## 1. Goal & design intent

**Goal:** verify **one runnable M1.7 build** that proves Player Embodiment — the player can now render as a real **8-directional animated character** (the flannel/hoodie "surface" look: idle + walk in 8 directions, plus pickup and throw animations) instead of the greybox box+nose. Crucially, the character is **OFF BY DEFAULT** — the build boots to the **identical M1.6 greybox** (same look & feel, same fp). The animated character is **opt-in**: open the debug menu (**P**) → the new **Player** tab → tick **"Player art (debug)"**. It then renders in **both** the Hub and the Dive. When art is on, pickup/throw briefly **root the player** for the animation; the Player tab exposes live knobs to tune that movement-lock (lock mode Clip-driven / Fixed, separate Pickup-lock and Throw-lock durations, lock-on-pickup, animate-pickup-on-reject).

M1.7 also lands a **polish fix to pre-existing behavior**: a one-frame "jump/ghost" where freshly-spawned or re-dropped junk, thrown items, the player/camera at dive-start, and hazard spawns would flash at a wrong position for a single frame (a physics-interpolation issue present since M1.4) is fixed.

**Design intent (one line):** *RG1 is the M1.7 integration + verification + publish capstone, not a new system* — it confirms the N0/N1/N2 work composes onto the existing scene without disturbing the dive, the band generation, or the save format: the all-off `RunConfig` band fingerprint stays `e943ac9c8bc1`, the 89-knob count holds, the save schema does not bump, and **art OFF == M1.6 byte-for-byte**. The animated-character / movement-lock *feel* read is RG3 (Director), backed by RG2's readability check.

---

## 2. What's already wired (the M1.7 N-tasks — do NOT rebuild)

RG1 inherits the integrated N0/N1/N2 work. Key seams (verified present by the test suite — see §4):

- **N0 — art import → SpriteFrames.** The flannel/hoodie "surface" character art (idle + walk × 8 directions, plus pickup and throw) imported as Godot `SpriteFrames`, texture-filtering OFF (pixel-art), driven by an `AnimatedSprite2D` on the Player. Throw RIGHT/east was regenerated to remove the earlier frame bleed (now a clean single character). Sprite **scale 0.45 / y=-18** seats the 64px-on-124px-canvas character on the r=14 body so the art reads against the existing collision body, not redefining it.
- **N1 — player visual state machine.** A pure-logic FSM picks the rendered state: `quantize_dir` snaps the aim/move vector into 8 sectors (with a ZERO-hold and 10° hysteresis to stop edge-flicker), `select_state` chooses walk/idle (8 px/s threshold) and gives pickup/throw **action priority** (a locked player never walks). This drives the AnimatedSprite2D's clip + flip in both Hub and Dive. The FSM is headless-testable (`test_player_visual.tscn`).
- **N2 — debug Player tab + movement-lock.** A new **Player** tab in the P-menu holding: the **"Player art (debug)"** toggle (moved here from Meta; emits `EventBus.debug_player_art_toggled(enabled)`; **defaults UNCHECKED = art OFF**, matching the player scene default — art is opt-in), plus live controls for the pickup/throw **movement-lock**: lock **mode** (Clip-driven / Fixed), separate **Pickup lock (s)** and **Throw lock (s)** durations, **lock-on-pickup**, and **animate-pickup-on-reject**. These controls are **debug-only tooling** — they are NOT `RunConfig` knobs, are outside the 89-knob MANIFEST, and do not touch determinism or the save.
- **Spawn-interpolation fix.** The one-frame "jump/ghost" on freshly-spawned / re-dropped junk, thrown items, the dive-start player/camera, and hazard spawns is fixed (physics-interpolation reset on spawn), a polish fix to behavior present since M1.4.

**The run/meta boundary stays intact:** player art is **run-agnostic visual state** — it persists nothing. The toggle is a debug-tooling signal, not run- or meta-state. **No `RunConfig` lever knob added in M1.7** → the 89-knob count holds and the all-off fp stays `e943ac9c8bc1`. **No save-schema change** (META stays v4, RUN stays v1).

---

## 3. RG1 deliverable: greybox parity + the opt-in animated character

M1.7 is a **visual / tooling** iteration. The dive itself — `make_default_play_preset()` — and the surface (Main Menu / Hub / Shop / P-tabbed debug) are **identical to M1.6**. RG1 ships the **embodiment layer** around that unchanged loop:

| System | What ships | Source |
|---|---|---|
| **Player art (N0+N1)** | 8-direction idle + walk + pickup + throw animated character; renders in Hub AND Dive; scale 0.45 / y=-18 seats it on the body | Director-locked: a real character that stands in for both surface and dive (dive-gear variants are a later iteration). |
| **Player-art toggle (N2)** | new **Player** tab in the P-menu; **"Player art (debug)"** checkbox, **default OFF**; flips greybox ↔ animated character live | Director-locked: opt-in, off by default → boot reads as M1.6. |
| **Movement-lock knobs (N2)** | live Player-tab controls: lock mode (Clip-driven / Fixed), Pickup lock (s), Throw lock (s), lock-on-pickup, animate-pickup-on-reject | Director-locked: the only feel change, gated ON only when art is ON; tunable live. |
| **Spawn-interp fix** | the one-frame spawn/throw "jump" on junk / thrown items / dive-start player+camera / hazards is gone | polish fix to M1.4-era behavior. |
| (M1.6 surface + M1.5 dive) | UNCHANGED — Main Menu / Hub / Shop / P-tabbed debug; the M1.5 fun-stack dive; 300s clock | unchanged from the M1.6 shipped build. |

**Invariants held:** the all-off `RunConfig.new()` band fingerprint stays `e943ac9c8bc1`; the 89-knob count holds (the Player-tab controls are debug-only, outside the MANIFEST — no knob added/renamed); `make_default_play_preset()` is the same M1.5 fun stack; the save schema is **unchanged** (META v4 / RUN v1 — nothing about player art persists); **art OFF == M1.6 byte-for-byte**.

---

## 4. Verify matrix (M1.7)

RG1 is **done** only when this matrix passes. It separates **objective build checks** (headless-automatable, each row naming the exact test/command) from **subjective embodiment feel** (RG2/RG3 + human — the *felt* character/animation/movement-lock experience). All commands run with `export PATH="$HOME/.local/bin:$PATH"`, **one godot instance at a time** (import-lock deadlock if concurrent), as a SCENE (`godot --headless --path Game res://tests/<x>.tscn`) — except the SceneTree movement test, which runs via `--script`.

### 4.1 Build integrity + determinism + greybox parity (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| **Clean import** | All scripts compile, no parse errors; `.godot` builds (incl. N0 SpriteFrames, N1 FSM, N2 Player tab) | `godot --headless --path Game --import` → exit 0 | **PASS** (exit 0) |
| **CI smoke** | M0 architecture spike healthy (autoloads, EventBus incl. `debug_player_art_toggled`, seeded RNG, save stub) boots headless | `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → "SMOKE OK", exit 0 | **PASS** ("SMOKE OK — M0 architecture spike healthy", exit 0) |
| **Determinism fp (art OFF = M1.6)** | All-off control band fp == `e943ac9c8bc1` (byte-identical to the locked M1.0–M1.6 baseline); `make_default_play_preset()` is the M1.5 fun stack; the M1.7 art/debug changes are visual/tooling only and **must not move the fp** | `godot --headless --path Game res://tests/test_rg1_m15_verify.tscn` → "RG1 M1.5 VERIFY OK" (the dive preset is UNCHANGED in M1.7 — this is the canonical dive-still-works + fp guard) | **PASS** (fp=`e943ac9c8bc1`; "RG1 M1.5 VERIFY OK"; 12 rows headless-verified, 7 deferred; exit 0) |
| **Player visual FSM** | `quantize_dir` (8 sectors + ZERO-hold + 10° hysteresis hold/switch) + `select_state` (walk/idle @ 8 px/s threshold, action priority, locked never walks) — the N1 logic that drives the AnimatedSprite2D | `godot --headless --path Game res://tests/test_player_visual.tscn` → "PLAYER_VISUAL OK" | **PASS** ("PLAYER_VISUAL OK — quantize_dir … select_state … verified", exit 0) |
| **Movement** | 8-direction movement unaffected by the art layer (cardinal/diagonal distance equal, max_speed 200) | `godot --headless --path Game --script res://tests/test_player_movement.gd` → "MOVE OK" (SceneTree test) | **PASS** ("MOVE OK — 8-direction movement verified (cardinal=91.7px diagonal=91.7px over 0.5s, max_speed=200)", exit 0) |

### 4.2 Throw / pickup / loop unaffected (HEADLESS)

The N0/N1/N2 visual layer must not regress the dive's pickup/throw/extract logic.

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| **Junk pickup** | populate-from-plan, accept adds + frees the item, full-bag reject leaves junk in-world, drop re-spawns | `godot --headless --path Game res://tests/test_junk_pickup.tscn` → "JUNK PICKUP OK" | **PASS** ("JUNK PICKUP OK — populated 24 pickups … accept added 'junk_scrap_bolt' … full-bag reject left the junk in-world; drop re-spawned", exit 0) |
| **Drop / swap** | drop gesture removes from bag, emits `junk_dropped(item, player_pos)`, live spawner re-instantiates the grabbable | `godot --headless --path Game res://tests/test_drop_swap.tscn` → "DROP SWAP OK" | **PASS** ("DROP SWAP OK — drop gesture removed the item … emitted junk_dropped … re-instantiated one grabbable JunkPickup", exit 0) |
| **Main game loop** | dive-only scene builds a band (pieces+pickups+gate), pickup + gate-extract drives `run_ended(extract)` haul held-banked, a second run restarts clean | `godot --headless --path Game res://tests/test_main_game_loop.tscn` → "MAIN GAME OK" | **PASS** ("MAIN GAME OK — assembled dive-only scene … haul held-banked (not sold) … second run restarted clean", exit 0) |

### 4.3 Knob coverage + save schema (HEADLESS / inspection)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| **Config menu 89/89** | All 89 `RunConfig` knobs still bound + reachable; the new **Player**-tab controls are debug-only (outside the MANIFEST), and the **"Player art (debug)"** toggle defaults **UNCHECKED** (= art OFF). The 89 count is unchanged by the Player tab. | `godot --headless --path Game res://tests/test_config_menu.tscn` → "CONFIG MENU OK" | **PASS** ("CONFIG MENU OK — 89/89 knobs bound + reachable … Reset returns the all-off baseline"; assertion green, exit 0) |
| **Save schema unchanged** | `META_SCHEMA_VERSION == 4`, `RUN_SCHEMA_VERSION == 1` — **no M1.7 bump** (player art is run-agnostic, persists nothing; the debug toggle is tooling, not state). No new migration / fixture needed. | inspect `systems/save_manager.gd` | **PASS** (`META_SCHEMA_VERSION := 4`, `RUN_SCHEMA_VERSION := 1` confirmed; no schema change in M1.7 → existing v1/v2/v3→v4 migrations + fixtures stand, no new fixture added) |

### 4.4 Did RG1 add a new `test_rg1_m17_verify`?

**No — and this is a deliberate QA call.** The M1.7 gate is a **visual / tooling** claim that decomposes into surfaces each already fully covered by an existing, file-disjoint, individually-green test:

1. **The animated character's logic** (8-direction quantize + state selection + action priority + locked-never-walks) → `test_player_visual.tscn` (the N1 FSM, the only non-rendered surface the character introduces).
2. **The art layer doesn't move the dive** (all-off fp byte-identical; the M1.5 fun stack still ships) → `test_rg1_m15_verify.tscn` (fp `e943ac9c8bc1` asserted there).
3. **Pickup/throw/extract unaffected** → `test_junk_pickup.tscn` / `test_drop_swap.tscn` / `test_main_game_loop.tscn`.
4. **Movement unaffected + 89-knob/save invariants** → `test_player_movement.gd` / `test_config_menu.tscn` / `save_manager.gd` inspection.

The **entire remaining M1.7 surface is rendered + input-driven** — whether the character *reads* in 8 directions, whether throw-east is a clean single sprite, whether the scale/offset seats it, whether the movement-lock *feels* right, and whether the spawn "jump" is gone — and a headless test **cannot render or drive** any of it. A consolidated `test_rg1_m17_verify` would only re-instance the same Player/main_game scenes and re-assert the same FSM/fp/loop facts the four tests above already cover — pure duplication with no new coverage, plus a concurrent-instance risk. The existing suite + `test_player_visual` + the fp/89 guards **are** the M1.7 objective gate; the visual/feel surface is correctly **human-deferred** to §4.5. **No new test added.** *(If one were ever warranted, it would have to assert something headless-observable the suite doesn't — e.g. that toggling `debug_player_art_toggled(true)` swaps the AnimatedSprite2D visible / greybox hidden and `false` restores it; but that visibility flip is trivial wiring already exercised by the rendered human checklist, so it does not justify a new scene.)*

### 4.5 Subjective / felt — HUMAN-DEFERRED to the Director (the playtest checklist)

These are the *felt* embodiment experience — RG1 only guarantees the build *lets a human experience and the telemetry capture* them. Headless cannot render or input-drive any of these. The character/feel read is RG3 (Director), backed by RG2's readability check:

- **Greybox parity on boot:** the build **boots showing the greybox** (the M1.6 box+nose) — identical look & feel to M1.6, no character until you opt in.
- **Opt-in toggle:** open **P** → the new **Player** tab → tick **"Player art (debug)"** → the player becomes the animated character in **BOTH** the Hub and the Dive.
- **8-direction read:** idle and walk read correctly in all 8 directions as you aim/move (test both **mouse + keyboard** and **controller**).
- **Pickup animation:** grabbing junk plays the pickup animation.
- **Throw animation (all 8):** throwing plays the throw animation in all 8 directions — **especially throw RIGHT/east is a clean single character** (the regenerated frames; the old bleed is gone).
- **Spawn-jump fix:** the one-frame spawn/throw "jump" is gone — watch thrown items, re-dropped junk, the dive-start player/camera, and hazard spawns.
- **Scale / seating:** scale 0.45 / y=-18 seats the character on the r=14 body (the art reads against the body, not floating/sinking).
- **Movement-lock feel:** the Player-tab timing knobs change the lock feel — if pickup/throw reads sluggish, try **Fixed** mode + shorter Pickup/Throw durations; confirm the lock-on-pickup + animate-pickup-on-reject toggles behave.
- **Toggle back OFF:** un-ticking "Player art (debug)" restores the greybox cleanly (no stuck character / no residual lock).

---

## 5. Known watch-items (for the Director + RG2)

- **Player art defaults OFF — most testers will see the greybox unless they flip the toggle.** This is **intentional** (opt-in greybox-parity), but it means a tester who never opens **P → Player → "Player art (debug)"** will never see the M1.7 headline. **Call this out to every tester** (the changelog does). RG2 watch-item: how many sessions actually flipped it on.
- **Movement-lock feel during a tense extract.** When art is ON, pickup/throw briefly root the player. During a pressured extract this could read as sluggish/unfair. The lock is **tunable live** on the Player tab (mode + durations) — RG2 should watch whether the default feels right or wants Fixed-mode + shorter windows.
- **8-direction snapping legibility.** The character snaps to 8 sectors (with hysteresis). Watch whether the snapping reads cleanly or feels steppy as you swing the aim, especially near sector boundaries.
- **Dive-gear-vs-surface-look.** The flannel/hoodie "surface" look currently stands in for the **dive** too (there is no dive-specific outfit yet). Dive-gear outfit variants are a **later iteration** — note whether the surface look feels wrong underground.

---

## 6. Publish + changelog (orchestrator-owned network step)

- **changelog.txt** — updated by RG1 with an **M1.7 — "Player Embodiment"** block documenting the delta from M1.6 (the previous shipped version) as a clean **feature list**: the opt-in animated character (8-direction idle/walk + pickup/throw), **how to turn it on** (P → Player tab → "Player art (debug)" — called out explicitly since it's off by default), the new Player tab + movement-lock knobs, and the spawn-"jump" fix. Per the changelog scope rule, intra-M1.7 fixes/tweaks to the *new* art are folded into the feature's final-state description, not listed separately. A short "NOT YET IN THIS BUILD" note flags art-off-by-default and the deferred dive-gear variants.
- **Publish to itch** — the orchestrator runs `bash Game/tools/push_itch.sh` (`BUTLER=/mnt/c/wsl-libraries/butler/butler`) to stamp → export the Web preset → `butler push qusto/the-far-yard:html5`. RG1 (this task, in an isolated worktree) does **NOT** perform the network-gated push — it produces the verify doc + the changelog; the orchestrator publishes. Live page: `https://qusto.itch.io/the-far-yard` (Chrome/Edge only — SharedArrayBuffer/COEP). Web telemetry returns via the in-game "Export telemetry" button (on the P-debug Meta tab).

---

## 7. Config-sweep guidance for the Director (the re-gate experiment plan)

The re-gate question (RG3): **now that the player can be a real animated character, does the embodiment read — does the character feel right in 8 directions, do pickup/throw land, and is the movement-lock feel right (not sluggish)?** The change is visual/tooling, so the M1.7 evaluation is mostly **the Director's eyes**, not dive-config sweeping. Suggested playtest:

1. **Greybox first (`build_tag: m17-greybox`).** Boot, play the loop with the **default greybox** — confirm it reads exactly like M1.6.
2. **Art ON (`build_tag: m17-art`).** P → Player → tick "Player art (debug)" → play the same loop. The headline cell: "does the character land in Hub + Dive?" Swing the aim through all 8 directions; pick up junk; throw in every direction (especially **east**).
3. **Movement-lock sweep (`build_tag: m17-lock`).** On the Player tab, try **Fixed** mode with shorter Pickup/Throw durations vs. the default Clip-driven mode — find the feel that isn't sluggish under a tense extract.
4. **Spawn-jump check (`build_tag: m17-spawn`).** Throw items, re-drop junk, re-enter dives, trigger hazard spawns — confirm the one-frame "jump" is gone.
5. **Baseline control (`build_tag: m17-baseline`).** Art OFF + P-debug → **Reset** (all-off, byte-identical band, fp `e943ac9c8bc1`) → dive. The permanent M1.0–M1.6 control RG2 segments against.

**Telemetry RG2 should read:** M1.7 adds **no new gameplay metric** — telemetry stays comparable to M1.6 (the 89-knob `run_config` snapshot on every `run_started` row is still ground truth; the flow signals are unchanged). RG2's job is (a) confirm **no perf regression** from the sprite on the web build (60 FPS / ~16 ms budget — the AnimatedSprite2D + per-band node caps), and (b) the Director's readability read. `build_tag` (prefix `m17-`) is the human-readable handle RG2 groups on.

---

## 8. Acceptance criteria (M1.7)

1. **A fresh build boots to the M1.6 greybox** (art off by default) and the complete M1.6 surface loop + M1.5 dive still run end-to-end, no blockers.
2. **The animated character renders in both Hub and Dive when opted in** (P → Player tab → "Player art (debug)") — 8-direction idle/walk + pickup + throw — verified for the FSM logic headless (`test_player_visual` "PLAYER_VISUAL OK"), human-deferred for the rendered/felt surface.
3. **The dive is UNCHANGED and the all-off control reproduces the M1.0–M1.6 baseline exactly** (fp `e943ac9c8bc1` unmoved; the M1.5 fun stack still ships; M1.7 touched no generation/RNG/RunConfig/economy).
4. **The 89-knob count holds** (the Player-tab controls are debug-only, outside the MANIFEST; the "Player art (debug)" toggle defaults UNCHECKED; the count test stays 89/89).
5. **No save-schema change** (META v4 / RUN v1 unchanged; player art persists nothing; existing v1/v2/v3→v4 migrations + fixtures stand, no new fixture).
6. **Pickup / throw / extract / movement are unaffected** by the art layer (junk-pickup / drop-swap / main-game-loop / movement tests green).
7. The build + this doc + the updated changelog are **ready for the Director's playtest** (published to itch by the orchestrator; RG2/RG3 follow).

A build that passes the §4 matrix (all §4.1–4.3 rows green + the §4.5 human checklist handed off) and ships the updated changelog satisfies RG1. Done means: the matrix is filled, the worklog names the commit SHA, the build boots greybox = M1.6, the animated character renders in Hub + Dive when opted in, the dive is byte-identically the M1.5/M1.6 dive, the save schema is unchanged, and the 89-knob/fp invariants hold.

---

## 9. Resolved Decisions (pointer)

The Director's FINAL dispositions for M1.7 are in `M1.7_Breakdown.md` (the Phase-3/Phase-4 lock) and the per-task `N0`/`N1`/`N2` design docs' "Resolved Decisions" sections. RG1 honours them verbatim: the animated character is **opt-in, default OFF** (greybox boots = M1.6 byte-for-byte); the toggle lives on a new **Player** tab in the P-menu and emits `debug_player_art_toggled(enabled)`; the **movement-lock is the only feel change, gated ON only when art is ON** and tunable live (mode / Pickup-lock / Throw-lock / lock-on-pickup / animate-pickup-on-reject); sprite **scale 0.45 / y=-18** seats the 64px-on-124px character on the r=14 body; throw-east was regenerated to remove the frame bleed; the spawn-interpolation "jump" (M1.4-era) is fixed; the 89-knob count holds (the Player-tab controls are debug-only, outside the MANIFEST); the all-off fp `e943ac9c8bc1` is unmoved; **no save-schema bump**.

> **As-built note (for the design reapply sweep):** `systems/event_bus.gd` line ~236 carries a stale comment "Default state is art ON." The **as-built** default is art **OFF** — the config toggle (`config_menu.gd:694`, `button_pressed = false`) and the player scene default are both OFF, and `test_config_menu.tscn` passes with art off. The stale comment should be corrected to "Default state is art OFF (opt-in)" during the wave close-out / design reapply. Flagged here so it is not read as a contradiction with this doc's default-OFF invariant.
