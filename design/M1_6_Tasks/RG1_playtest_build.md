# RG1 — M1.6 Playtest Build (Surface & Staging — the game has a surface: Main Menu, walkable Hub, Shop)

**Task id:** RG1 · **Milestone:** M1.6 (Surface & Staging) · **Workstream:** the re-gate · **Wave:** 4 (sequential, after Waves 1–3 integrate)
**Assignee:** `qa-playtest-coordinator` (build assembly verification — integrated across Waves 1–3) + the verify matrix
**dependsOn:** **M0** (Wave 1) + **M1, M2, M4** (Wave 2) + **M3** (Wave 3) all integrated on `main`
**Companion docs:** `M1.6_Breakdown.md` (§"Phase 3 Dispositions & Phase 4 Lock" — the Director's FINAL decisions + the locked architecture), `M1_5_Tasks/RG1_playtest_build.md` (the template this mirrors), `M1_5_Tasks/G4_findings_M1.5.md` (the prior shipped version, for the changelog delta), `M1_Tasks/M1_As_Built.md` (canonical APIs), `scenes/app/app.gd` (the persistent-root router), `scenes/menu/main_menu.gd` (the app entry), `scenes/hub/hub.gd` (the walkable staging room), the Shop UI (sell+buy), `ui/config/config_menu.gd` (the P-key 7-tab debug menu), `systems/game_state.gd` (the `purchase()`/`owns()`/`owned_items` economy surface + quota-on-return), `systems/save_manager.gd` (`META_SCHEMA_VERSION == 4`).

> **This is the VERIFY + DOCUMENT + PUBLISH task, not new gameplay.** Every M1.6 system (M0 router/economy/signals, M1 menu, M2 hub + dive-only refactor, M3 shop sell+buy + META v3→v4 bump, M4 P-key tabbed debug menu) was built and merged in Waves 1–3. RG1 (a) confirms the **surface loop** boots and runs end-to-end (boot → Main Menu → New/Continue → Hub → portal → dive → auto-return → Shop sell+buy), (b) confirms the **dive preset is UNCHANGED** from M1.5 — the all-off control is still byte-identical (fp `e943ac9c8bc1`) and the M1.5 fun stack still ships, (c) confirms the **89-knob count holds** (M4 regrouped into tabs, added no lever), (d) confirms the **META save schema migrates v1/v2/v3 → v4** without loss (the persistent-purchases bump), and then (e) hands the Director a playable build (published to itch by the orchestrator) + the changelog for the re-gate (RG2/RG3).

---

## 1. Goal & design intent

**Goal:** verify **one runnable M1.6 build** that proves the Surface & Staging iteration runs end-to-end — the game now reads as a **game, not a test bench**. The build boots to a real **Main Menu** (New Game / Continue / Quit / Settings-stub); New/Continue route into a walkable **Hub**; the Hub has a **departure portal** (interactable) that launches a dive and a **Shop** terminal (interactable) that lets you **sell** your banked haul → Money and **buy** persistent upgrades; a dive end (extract / death / timeout) **auto-returns** to the Hub; the **dive clock runs in the dive only** (never in Menu/Hub); and the config/debug menu has moved **off the first screen** to a **P-key 7-tab overlay** (Hazards / Level Generation / Vision / Timer & Quota / Exposure & Return / Throw & Camera / Meta), with the `r4_` vision/fog rows split out of the maze section into their own **Vision** tab.

The loop RG1 must run, unbroken, repeatedly in a session — the **new surface spine**, with the M1.5 dive layered in unchanged:

```
boot → app.tscn (persistent root router; current_state = "menu")
  → Main Menu  (New Game [wipe-with-confirm if a save exists] / Continue [disabled w/o save] / Quit / Settings-stub)
  → Hub  (walkable greybox room: Player + departure-portal interactable + Shop interactable; NO dive clock)
      → Shop  (SELL banked haul → Money  ·  BUY from a 3-item persistent catalog, spending Money [owned across runs])
      → Portal → dive_requested → router swaps StateHost to the dive-only main_game.tscn
          → dive (UNCHANGED M1.5 fun stack: R1 room-bound pursuer + density + maze + K5 hazards + 300s clock
                  + camera + exits + L1 throwing + L3 money-below-timer + L4 grab-prompt)
          → one of: extract | death | timeout
          → QUOTA CHECK on the guaranteed Hub-return beat (cumulative money ≥ target?) — MISS = full roguelite WIPE
          → run_ended → router auto-returns (deferred one frame) to the Hub
  → P (anywhere): the 7-tab debug/config overlay (pauses the dive while open; no-op in Menu/Hub)
```

**Design intent (one line):** *RG1 is the M1.6 integration + verification + publish capstone, not a new system* — it confirms the Wave-1/2/3 surface systems (M0 router + economy + signals + P action, M1 menu, M2 hub + dive-only refactor + run-end→hub routing incl. quota/wipe, M3 shop sell+buy + META v3→v4, M4 P-key 7-tab debug menu + Vision split) compose into the single `app.tscn` root without conflict, and — crucially — that **the structural/UI/meta iteration moved NOTHING in band generation**: the all-off `RunConfig` band fingerprint stays `e943ac9c8bc1`, the 89-knob count holds, and the M1.5 dive preset is byte-for-byte the same dive. RG1 does **not** answer the fun gate — that is RG2 (flow analysis) → RG3 (verdict, `G4_findings_M1.6.md`).

---

## 2. What's already wired (Waves 1–3 — do NOT rebuild)

The M1.6 build assembly was done by the Wave-1/2/3 builders; RG1 inherits it. Key seams (verified present by the integrated test suite — see §4):

- **M0 router** (`scenes/app/app.tscn`+`app.gd`) — the persistent-root `App` node is the new `run/main_scene`. A `StateHost` child swaps the single active state scene (Menu/Hub/Dive) by `queue_free` + instance-by-path; one persistent `DebugOverlay` `CanvasLayer` holds the M4 P-menu (mounted ONCE, available in all three states). The router **observes the locked `run_ended`** (deferred one frame) to auto-return to the Hub — `run_ended` arity is NOT changed. `App.current_state` reads `&"menu"`/`&"hub"`/`&"dive"`.
- **M0 economy surface** (`game_state.gd`) — `purchase(item_id: StringName, price: int) -> bool` (Money debit + `owned_items` append + save; reject paths — negative price / already-owned / can't-afford — emit `purchase_failed`, mutate nothing), `owns(item_id) -> bool`, `owned_items: Array[StringName]` meta (reset on `wipe_meta()`). Quota-eval decoupled to the guaranteed Hub-return beat (closes the "re-dive without selling skips the wipe" hole).
- **M0 EventBus signals (8)** — `dive_requested(band_id)`, `returned_to_hub(reason)`, `hub_entered()`, `shop_opened()`, `shop_closed()`, `item_sold(item_count, total_value, money)`, `item_purchased(item_id, price, money)`, `purchase_failed(item_id, price, money)`. Flow signals carry no `run_t_ms`/`depth` (they fire outside a dive). Additive — `run_ended` arity untouched.
- **M0 `P` action** (`project.godot` `[input]`) — `debug_menu_toggle` = P. `run/main_scene` repointed to `app.tscn`.
- **M1 Main Menu** (`scenes/menu/*`) — New Game (wipe-with-confirm via `ConfirmationDialog` → `GameState.wipe_meta()` if a save exists, else straight route) / Continue (disabled w/o save) / Quit / Settings ("coming soon" placeholder). First-run telemetry-consent (G6) re-homed here. Routes to the Hub.
- **M2 Hub + dive-only refactor** (`scenes/hub/*` + `main_game.*`) — a small walkable greybox room spawning the existing `Player`, with a departure-portal interactable (`dive_requested`) and a Shop-interactable anchor. `main_game.tscn` stripped to dive-only (the config-rail/Start overlay removed; the dive self-starts on `_ready` from the staged config else `make_default_play_preset()`). A dive end routes back to the Hub; the **quota-eval + miss-wipe** fire on the Hub-return beat. **No `DiveClock` in the Hub.**
- **M3 Shop (sell + buy)** (Shop UI + `ShopItem`/`ShopCatalog` `.tres`) — a Shop interactable in the Hub opens a Shop with a **SELL** tab (banked haul → Money, reusing `sell_banked_junk`) and a **BUY** tab (a **3-item persistent catalog**: `scrap_magnet` / `lucky_charm` / `reinforced_bag`, spending Money). **`SellScreen` retired.** **META schema bumped v3 → v4** (+ migration step + `meta_v3.sav` fixture + migration test). Effects may be stubbed (greybox).
- **M4 debug menu (P + 7 tabs)** (`ui/config/config_menu.*` + CSV) — the config menu moved off the first screen, opens with **P** as an overlay in all three states, restructured into a `TabContainer`: **Hazards** (`r1_`/`hpp_`/`hbomb_`/`hspike_`) · **Level Generation** (`lvl_`+`r4_` maze rows) · **Vision** (`r4_vision_` — the fog/vision rows pulled out of the maze section into their own tab) · **Timer & Quota** (`timer_`/`quota_`) · **Exposure & Return** (`r2_`/`r3_`) · **Throw & Camera** (`throw_`/`cam_`/`exit_`) · **Meta** (`""` + the re-homed web "Export telemetry" button). The P-overlay is the lone `PROCESS_MODE_ALWAYS` node; it pauses the dive while open, no-op in Menu/Hub. **89-knob coverage preserved** (pure regroup — Vision split = Option A body-only pseudo-section; no field renamed, no knob added/removed).

**The run/meta boundary stays intact:** Money, banked haul, and `owned_items` (purchases) are **meta**; the in-dive haul is run-state banked at a gate as today. The Hub reads meta only. **No `RunConfig` lever knob added in M1.6** → the 89-knob count holds and the all-off fp stays `e943ac9c8bc1`. The **only** persisted-state change is the META v3→v4 bump for `owned_items` (M3).

---

## 3. RG1 deliverable: the surface loop + the unchanged dive preset

M1.6 is a **structural / meta / UI** iteration. The dive itself — `make_default_play_preset()` — is **identical to M1.5** (the M1.4 fun stack + the three M1.5 levers: `throw_enabled=true`, `r1_spawn_room_only=true`, `r1_patrol_speed=28.0`; with the post-RG3 timer tune to 300s carried from M1.5). RG1 ships the **surface** around that dive:

| Surface system | What ships | Source |
|---|---|---|
| **Main Menu (M1)** | New Game (wipe-with-confirm) / Continue (load save) / Quit / Settings-stub; first-run telemetry consent | Director: real app entry, no config rail on the first screen. |
| **Hub (M2)** | walkable greybox room, departure portal, Shop anchor; NO dive clock | Director-locked: a staging room you return to between runs. |
| **Shop (M3)** | SELL banked haul → Money; BUY 3 persistent upgrades (META v3→v4) | Director: persistent catalog, accept the save bump; effects may be stubbed. |
| **Debug menu (M4)** | P-key 7-tab overlay; Vision split out; telemetry-export re-homed to Meta tab | Director-locked: knob menu out of the player's face; pure regroup. |
| (M1.5 dive) | UNCHANGED — preset = M1.4 stack + throw + room-bound pursuer + the two legibility fixes; 300s clock | unchanged from the M1.5 shipped build. |

**Invariants held:** the all-off `RunConfig.new()` band fingerprint stays `e943ac9c8bc1`; the 89-knob count holds (M4 regroups only — `has_full_coverage()` + both count tests stay 89); `make_default_play_preset()` is the same M1.5 fun stack; the META schema is v4 and v1/v2/v3 fixtures migrate forward without loss; the in-dive haul is run-state, banked at a gate, held until sold at the Shop.

---

## 4. Verify matrix (M1.6)

RG1 is **done** only when this matrix passes. It separates **objective build checks** (headless-automatable, each row naming the exact test/command) from **subjective surface feel** (RG2/RG3 + human — the *felt* menu/hub/shop/P-overlay experience). All commands run with `export PATH="$HOME/.local/bin:$PATH"`, **one godot instance at a time** (import-lock deadlock if concurrent), as a SCENE (`godot --headless tests/<x>.tscn`), not `--script`.

### 4.1 Surface loop + structural integrity (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| **Clean import** | All scripts compile, no parse errors; `.godot` builds | `godot --headless --import` → exit 0 | **PASS** (exit 0) |
| **CI smoke** | M0 architecture spike healthy (autoloads, EventBus, seeded RNG, save stub) boots headless | `godot --headless --script res://tools/ci_smoke_test.gd` → "SMOKE OK", exit 0 | **PASS** ("SMOKE OK — M0 architecture spike healthy", exit 0) |
| **App router / surface flow** | `app.tscn` boots to `&"menu"`; StateHost holds exactly 1 state; persistent DebugOverlay mounted; Menu→Hub (`goto_hub` + `hub_entered`); Hub→Dive (`dive_requested` → `&"dive"`); dive `run_ended` auto-returns to Hub (deferred) + `returned_to_hub` reason rides along; `current_state` correct throughout | `godot --headless tests/test_app_router.tscn` → "ROUTER OK" | **PASS** ("ROUTER OK — App router boots → menu → hub → dive → hub; current_state correct", exit 0) |
| **Dive preset unchanged + fp** | All-off control band fp == `e943ac9c8bc1` (byte-identical to the locked M1.0–M1.5 baseline); `make_default_play_preset()` is the M1.5 fun stack (throw on + room-bound pursuer + 89-knob snapshot); trap-free; no leak into the all-off control; L1 throw seam + L2 pursuer-bounds wire up; extract/timeout reachable | `godot --headless tests/test_rg1_m15_verify.tscn` → "RG1 M1.5 VERIFY OK" (the dive preset is UNCHANGED in M1.6 — this is the canonical dive-still-works + fp guard) | **PASS** (fp=`e943ac9c8bc1`; "RG1 M1.5 VERIFY OK"; 12 rows headless-verified, 7 deferred; exit 0) |
| **Main game loop (dive-only)** | The dive-only `main_game` builds a band (pieces+pickups+gate), pickup + gate-extract drives `run_ended(extract)` with the haul **held-banked (not sold)**, a second run restarts clean | `godot --headless tests/test_main_game_loop.tscn` → "MAIN GAME OK" | **PASS** ("MAIN GAME OK — assembled dive-only scene … haul held-banked (not sold) … second run restarted clean", exit 0) |

### 4.2 Shop economy + persistence (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| **Shop sell + buy + persist** | 3-item persistent catalog (`scrap_magnet`/`lucky_charm`/`reinforced_bag`); `purchase()` debits Money + records `owned_items` + persists; reject paths inert (owned / unaffordable / negative price emit `purchase_failed`, mutate nothing); `wipe_meta()` clears `owned_items`; SELL-tab `sell_banked_junk(&shop)` credits the held haul | `godot --headless tests/test_shop_economy.tscn` → "SHOP ECONOMY OK" | **PASS** ("SHOP ECONOMY OK — 3-item persistent catalog … purchase() debits+records+persists, reject paths inert … wipe clears owned_items, SELL-tab … credits the held haul", exit 0) |
| **META save migration v1/v2/v3 → v4** | v1 → v4 (banked_junk + run_number/quota_target + owned_items defaults added across the chain, existing fields intact, round-trip + `.bak`); v2 → v4 (run_number=1/quota_target=0 + owned_items=[] added, all v2 fields intact); v3 → v4 (owned_items=[] added, all v3 fields intact, owned_items round-trips a save/reload, `.bak` preserved) | `godot --headless tests/test_save_migration.tscn` → 3× "SAVE MIGRATION OK" | **PASS** (v1/v2/v3 all "SAVE MIGRATION OK … to v4 … .bak preserved", exit 0); `META_SCHEMA_VERSION == 4` confirmed in `save_manager.gd` |

### 4.3 Knob coverage + determinism (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| **Config menu 89/89** | All 89 knobs bound + reachable in the (now-tabbed) config menu; master+knob+enum edits flow to the working config; Reset returns the all-off baseline | `godot --headless tests/test_config_menu.tscn` → "CONFIG MENU OK" | **PASS** ("CONFIG MENU OK — CFG verified (89/89 knobs bound + reachable … Reset returns the all-off baseline)", exit 0) |
| **RunConfig 89 + all-off baseline** | `RunConfig.new()` all-off default (M1.0 baseline); `to_flat_dict()` flat+JSON-safe with all 89 knobs; `inert_enabled_oppositions()` trap detection; `make_default_play_preset()` trap-free + does not leak into all-off | `godot --headless tests/test_run_config.tscn` → "R0 OK" | **PASS** ("R0 OK — RunConfig all-off default verified … all 89 knobs … does NOT leak into the all-off control", exit 0) |
| **Determinism fp** | Neutral-default band fp byte-matches the locked baseline `e943ac9c8bc1`; the corridor levers MOVE the band for a fixed seed yet stay deterministic | `godot --headless tests/test_corridor_lever.tscn` → "J4 OK" | **PASS** ("J4 OK — … neutral default fp byte-matches the locked baseline (e943ac9c8bc1) …", exit 0) |

### 4.4 Did RG1 add a new `test_rg1_m16_verify`?

**No — and this is a deliberate QA call.** The M1.6 gate decomposes into four cross-cutting claims, each already fully covered by an existing, file-disjoint, individually-green test:

1. **The surface loop boots end-to-end** (boot → menu → hub → dive → auto-return) → `test_app_router.tscn` (drives the real `app.tscn`, asserts every state transition + the auto-return + `current_state`).
2. **The dive preset is UNCHANGED + fp byte-identical + 89-knob snapshot** → `test_rg1_m15_verify.tscn` (the M1.5 dive verify, which M1.6 did not touch — it is the canonical dive-still-works guard; fp `e943ac9c8bc1` asserted there).
3. **The Shop sell+buy + persistence** → `test_shop_economy.tscn` (+ `test_save_migration.tscn` for the v4 bump).
4. **89-knob coverage held + determinism** → `test_config_menu.tscn` / `test_run_config.tscn` / `test_corridor_lever.tscn`.

A consolidated `test_rg1_m16_verify` would only re-instance the same `app.tscn`/`main_game.tscn`/`GameState` and re-assert the same things across the same scenes — pure duplication with no new coverage, and an extra concurrent-instance risk. The existing suite is the M1.6 gate; RG1 runs all of it green (§4.1–4.3). **No new test added.**

### 4.5 Subjective / felt — HUMAN-DEFERRED to the Director (the playtest checklist)

These are the *felt* surface experience — RG1 only guarantees the build *lets a human experience and the telemetry capture* them. The fun/legibility read is RG3 (Director), backed by RG2's flow analysis:

- **Main Menu (M1):** does the menu read as a real game entry (mouse + keyboard navigable)? New Game over an existing save shows the wipe-confirm; Continue is greyed out with no save; Settings honestly says "coming soon"; the first-run telemetry-consent prompt appears once.
- **Hub (M2):** can you **walk** the greybox room with the Player? Are the portal and Shop interactables discoverable (the grab-prompt reads on approach)? Does the Hub feel like a between-runs staging beat — and is there **no dive clock** ticking in it?
- **Dive launch + return (M2):** does the **portal** cleanly drop you into the dive, and does a dive end (extract/death/timeout) **auto-return** you to the Hub (not a config screen)? Does the quota-miss WIPE fire on return?
- **Shop (M3):** does the SELL tab clearly tally the **held banked haul** → Money? Does the BUY tab let you spend Money on the 3 upgrades, with owned/can't-afford rejections reading correctly? Do purchases **persist** across a quit/relaunch (load via Continue)?
- **Debug menu (M4):** does **P** open/close the overlay from Menu, Hub, AND in-dive? In-dive, does it **pause** the dive (the timer freezes) and resume cleanly? Are the **7 tabs** legible, and is the **Vision** tab now a separate, sensible group (not buried in maze)? Is the **Export telemetry** button reachable on the Meta tab?
- **Whole loop:** boot → menu → hub → shop (sell+buy) → portal → dive → return → repeat — does it read as a *game* now rather than a test bench? (The M1.6 gate question.)

---

## 5. Known watch-items (for the Director + RG2)

- **Shop upgrade effects are STUBBED (greybox).** Per the Director disposition, M1.6 proves the **meta-spend loop** (buy → owned-across-runs → persisted), not balanced effects. `scrap_magnet`/`lucky_charm`/`reinforced_bag` may have no/placeholder in-dive effect yet. **RG2 watch-item;** balanced effects are a later milestone.
- **Settings is a placeholder.** The Main Menu Settings button is an honest "coming soon" for M1.6; the real settings/telemetry-settings home is deferred (M5 territory).
- **`test_rg1_m13_verify` is pre-existing stale (FU3 filed).** It is NOT part of the M1.6 gate and was **excluded** from this verify matrix — its staleness predates M1.6 and is tracked separately under FU3. (Do not read its state as an M1.6 regression.)
- **Headless teardown noise.** Several tests print "ObjectDB instances leaked at exit" / "N resources still in use" / "RIDs … leaked" warnings at exit. These are the standard Godot headless scene-teardown messages, **not test failures** — every test still prints its OK line and exits 0. (Same noise observed in M1.5's RG1.)

---

## 6. Publish + changelog (orchestrator-owned network step)

- **changelog.txt** — updated by RG1 with an **M1.6 — "Surface & Staging"** block documenting the delta from M1.5 (the previous shipped version) as a clean **feature list**: a real Main Menu (New Game / Continue / Quit); a walkable Hub between runs (no dive clock); a Shop (sell your haul + buy persistent upgrades, replacing the old auto-sell screen); the debug menu now opens with **P** and is organized into tabs (Hazards / Level Generation / Vision / Timer & Quota / …). Per the changelog scope rule, intra-M1.6 fixes/tweaks are **not** listed — each feature is described in its final working state. A short "NOT YET IN THIS BUILD" note flags the stubbed shop effects + placeholder settings.
- **Publish to itch** — the orchestrator runs `bash tools/push_itch.sh` (`BUTLER=/mnt/c/wsl-libraries/butler/butler`) to stamp → export the Web preset → `butler push qusto/the-far-yard:html5`. RG1 (this task, in an isolated worktree) does **NOT** perform the network-gated push — it produces the verify doc + the changelog; the orchestrator publishes. Live page: `https://qusto.itch.io/the-far-yard` (Chrome/Edge only — SharedArrayBuffer/COEP). Web telemetry returns via the in-game "Export telemetry" button (now on the P-debug Meta tab).

---

## 7. Config-sweep guidance for the Director (the re-gate experiment plan)

The re-gate question (RG3): **now that the game has a surface — Main Menu, walkable Hub, Shop sell+buy, P-tabbed debug — does the loop read as a game (vs a test bench), and is the surface flow clean?** The dive itself is the M1.5 build; the M1.6 evaluation is mostly **flow + surface UX**, not dive-config sweeping. Suggested playtest:

1. **First boot — the surface, out of the box (`build_tag: m16-default`).** Boot → Main Menu → New Game → Hub → walk to the portal → dive (the M1.5 default preset) → return → walk to the Shop → SELL the haul → BUY an upgrade → dive again. The headline cell: "does the surface loop land?"
2. **Continue / persistence (`build_tag: m16-continue`).** Buy an upgrade, Quit, relaunch, **Continue** — confirm Money + owned upgrades persisted (META v4 round-trip).
3. **New-Game-over-save (`build_tag: m16-wipe`).** With a save present, choose New Game → confirm the wipe-with-confirm dialog → fresh Hub.
4. **Debug overlay (`build_tag: m16-debug`).** Press **P** in Menu, Hub, and in-dive; confirm the in-dive pause; tab through all 7 tabs; confirm Vision is its own tab; use the Meta-tab Export-telemetry button.
5. **The carried M1.5 dive sweeps remain valid** (throw speed/range, pursuer patrol speed, K5 lethality, quota, timer, exits) — set them on the P-debug tabs and dive. See `M1_5_Tasks/RG1_playtest_build.md` §6.
6. **Baseline control (`build_tag: m16-baseline`).** P-debug → **Reset** (all-off, byte-identical band, fp `e943ac9c8bc1`) → dive. The permanent M1.0–M1.5 control RG2 segments against.

**New telemetry RG2 should read:** the 8 new flow signals — `hub_entered` / `dive_requested` / `returned_to_hub(reason)` (boot→menu→hub→dive→return funnel; hub dwell; dive-launch-from-hub rate), `shop_opened`/`shop_closed` (shop visit rate), `item_sold(count,value,money)` / `item_purchased(item_id,price,money)` / `purchase_failed(...)` (sell+buy usage — did the meta-spend loop land?). The full 89-knob `run_config` snapshot on every `run_started` row is still ground truth; `build_tag` (prefix `m16-`) is the human-readable handle RG2 groups on.

---

## 8. Acceptance criteria (M1.6)

1. **A fresh build runs the complete M1.6 surface loop** — boot → Main Menu → New/Continue → Hub → portal → dive → auto-return → Shop sell+buy — end-to-end, no blockers (`test_app_router` "ROUTER OK").
2. **Each surface system takes effect** (M1 menu, M2 hub + dive-only refactor + run-end→hub routing, M3 shop sell+buy + persistence, M4 P-key 7-tab debug menu) — verified headless where possible (router/shop/save/config tests), human-deferred for the felt/rendered surface.
3. **The dive preset is UNCHANGED and the all-off control reproduces the M1.0–M1.5 baseline exactly** (fp `e943ac9c8bc1` unmoved; the M1.5 fun stack still ships; M1.6 touched no generation).
4. **The 89-knob count holds** (M4 regrouped into tabs, added no lever; both count tests + `has_full_coverage()` green).
5. **The META save schema is v4 and migrates v1/v2/v3 forward without loss** (the persistent-purchases bump; `.bak` recovery intact).
6. **Telemetry stays additive** (`run_ended` arity locked; the 8 new flow signals available; no schema bump on telemetry rows).
7. The build + this doc + the updated changelog are **ready for the Director's playtest** (published to itch by the orchestrator; RG2/RG3 follow).

A build that passes the §4 matrix (all §4.1–4.3 rows green + the §4.5 human checklist handed off) and ships the updated changelog satisfies RG1. Done means: the matrix is filled, the worklog names the commit SHA, the surface loop boots + loops, the dive is byte-identically the M1.5 build, the shop sells+buys+persists, the save migrates to v4, and the 89-knob/fp invariants hold.

---

## 9. Resolved Decisions (pointer)

The Director's FINAL dispositions for M1.6 are in `M1.6_Breakdown.md` §"Phase 3 Dispositions & Phase 4 Lock (2026-06-26 — design LOCKED)". RG1 honours them verbatim: persistent 3-item buy catalog (META v3→v4 bump); telemetry-export → P-debug Meta tab; New-Game-over-save = wipe-with-confirm; Settings = "coming soon"; scene router = persistent-root `App` node; 8 new EventBus signals; quota-eval decoupled to the Hub-return beat; M4 = 7 tabs with the `r4_` vision/maze split (Option A, body-only pseudo-section); 89-knob count holds; all-off fp `e943ac9c8bc1` unmoved.
