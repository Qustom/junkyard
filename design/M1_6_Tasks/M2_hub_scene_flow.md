# M2 — Hub scene + Menu→Hub→Dive→Hub flow · Per-task design (Phase 2)

**Milestone / iteration:** M1.6 (Surface & Staging). **Task id:** M2. **Wave:** 2 (parallel worktree; file-disjoint from M1/M4).
**BlockedBy:** **M0** (the scene/flow router mechanism, the `run/main_scene` swap, the new `EventBus` signals — `dive_requested` / `returned_to_hub` / `hub_entered` — and the `project.godot` input/application edits). **M3 is sequenced AFTER M2** (it mounts the Shop into M2's hub + retires `SellScreen`).
**Role(s):** `general-purpose` (the programmer — owns `scenes/hub/hub.*`, the `main_game.*` dive-only refactor, and the router handoff wiring).
**Author:** general-purpose, Phase-2 fan-out (2026-06-26).
**Status:** Phase 2 draft — Open Questions below await Phase-3 fresh-eyes + Director disposition. **NOT locked.**

> **The one thing M2 must prove:** the game has a *surface you stand on*. You boot (via M1's Main Menu) into a small walkable **Hub** room with your `Player` in it; you walk up to a **departure portal** and press interact; that routes you into a **dive-only** `main_game` (a real dive, the clock running); the dive ends (extract / death / timeout) and routes you **back to the Hub** — clock stopped, haul held in meta. The Hub never runs the `DiveClock`, never holds run-state, and reads **meta only**. The dive scene no longer owns the menu, the Start button, or the config rail.

> **Director-LOCKED semantics (from the breakdown §2 / §4, do NOT re-open):**
> - App flow is **Main Menu → Hub ⇄ Dive** (M1.6 Breakdown §2). `main_game.tscn` becomes **dive-only**; the Hub is the between-runs place.
> - **The `DiveClock` does NOT run in the Menu or the Hub** ("the hub should not run the clock"). The clock lives in the dive scene only.
> - The **Hub reads meta only** — Money, banked haul, owned purchases. It holds **no** run-state.
> - **The Shop sell path replaces the auto-`SellScreen`** (M3 owns the Shop). M2's refactor must **stop the dive scene from auto-presenting `SellScreen`** and route run-end to the Hub instead. M2 inventories every `SellScreen` responsibility so M3 drops nothing.
> - **No gameplay-lever knobs, no generation change** → the all-off fingerprint `e943ac9c8bc1` and the 89-knob count are **unmoved** (the hub touches no generation; this is purely structural).

---

## (a) Research on the premise

### Why a walkable Hub (the playtest finding + the design thesis)

M1.0–M1.5 built a real dive loop, but the player still **boots straight into a debug harness** (M1.6 Breakdown §1): `main_game.tscn` opens with a `MainMenu` `CanvasLayer` whose only between-runs beat is the auto-`SellScreen`, and the config rail (`ConfigMenu`) is bolted onto the first screen. The GDD frames THE FAR YARD as a *roguelite extraction + **life-sim***: the surface — the junkyard you inherited — is where you sell, spend, manage a debt, and *choose* to dive. A walkable Hub is the **physical anchor** for every later meta system (upgrades, NPCs, Cyrus, debt): a place you stand in between runs and *depart from*, rather than a button on a menu. M2 lays that Hub in greybox and proves the **Menu → Hub ⇄ Dive** round-trip, so M3 (Shop) and all later meta work have a room to live in.

### What M2 reuses (cited, real APIs)

M2 invents almost nothing — the Hub is the dive's own building blocks rearranged into a small static room:

- **The `Player`** (`entities/player/player.tscn`): a `CharacterBody2D` in group `"player"`, `collision_layer = 1` (player), `collision_mask = 26` (= `world`(2) | `enemy`(8) | `hazard`(16)). It already carries a child **`InteractionDetector`** (`components/interaction/interaction_detector.tscn`, `prompt_scene = interaction_prompt.tscn`). **Crucial:** the player's whole interactor stack is *self-contained in the scene* — instancing `player.tscn` into the Hub gives the Hub a working interactor for free, with **no** dependency on `main_game`. The player's movement (`player.gd:_physics_process`) and aim (`player.gd:64-90`, mouse/right-stick `resolve_aim`) run purely off `Input` + its own state; nothing the player does requires a live run (it does not read `GameState.run_active`). So the Hub gets a walking, aiming player with zero changes to `player.gd`.

- **The interaction component** (`components/interaction/`): `Interactable` (`interactable.gd`) is "dropped as a CHILD of any entity scene (junk pickup, gate, NPC) to make it usable" — an `Area2D` on the `interactable` layer (bit 3 = `collision_layer=4`), empty mask, with `interactable_id` / `display_name` / `prompt_text` / `enabled` + a `can_interact()` guard. The **detector** (`interaction_detector.gd`) is fully owner-agnostic: it tracks in-range `Interactable`s, picks the nearest with hysteresis, owns + positions the floating prompt, and on the `interact` action emits **`EventBus.interaction_requested(interactable_id, target)`** — "it never performs the pickup, opens the gate, mutates GameState, or frees nodes." **The owner listens for `interaction_requested` and acts.** This is *exactly* the contract the portal reuses: the portal is an entity scene with an `Interactable` child (`interactable_id = &"portal"`), and its owner script listens for `interaction_requested` and, when the id is its own, fires the dive-launch.

- **The gate/extract pattern as the portal's template** (`entities/gate/extract_gate.gd` + `.tscn`): the `ExtractGate` is the canonical "dumb interactable whose owner acts on `interaction_requested`." Its `_on_interaction_requested(id, target)` (`extract_gate.gd:40-51`) is the pattern to copy verbatim for the portal: (1) `if id != interactable_id: return`; (2) the **node-identity guard** `if target != null and target.get_parent() != self: return` (so two same-id interactables don't cross-fire); (3) a short input lockout (`_locked` + a `SceneTree` timer) absorbing fat-finger double-taps; (4) the action — for the gate `GameState.extract_and_end_run()`, **for the portal `EventBus.dive_requested.emit()` → the router loads the dive** (M0 declares `dive_requested`). The gate `.tscn` shape (an `Area2D` root with a `ColorRect` greybox body + a child `Interactable` with its own `CollisionShape2D` on layer 4, `prompt_text`) is the portal's greybox template. The **shop anchor M2 mounts for M3** is the *same* shape (`interactable_id = &"shop"`), placed but inert until M3 wires its owner.

- **The interaction prompt** (`ui/interaction_prompt.tscn` + `.gd`): a `Node2D` floating label the detector instances lazily on first focus and snaps to the focused target's world position. Its key hint reads the first keyboard event of the `interact` action — so the portal's prompt shows the correct key with **no** M2 code (the prompt derives `[F]`/`[E]` from the live input map). The Hub reuses this wholesale via the player's own detector.

- **The M0 router + signals** (M1.6 Breakdown §3/§4/§7): M0 is the single writer of the scene/flow mechanism and pre-declares every new signal. M2 *consumes* the router (to load the dive on `dive_requested`, and to return to the Hub on run-end) and the signals (`dive_requested`, `returned_to_hub`/`hub_entered`). The exact router shape — `change_scene_to_file()` between three top-level scenes vs. a persistent root `App` node swapping children — is M0's call (Breakdown §7); **M2 must build against whichever mechanism M0 ships** and stays agnostic to it behind the router's API (see OQ-2 / OQ-5). M2's design below is written so it works under *either* mechanism by routing every transition through the M0 router rather than calling `get_tree().change_scene_*` itself.

### Full inventory of `main_game`'s current responsibilities — STAYS / MOVES-to-Menu(M1) / MOVES-to-Shop(M3)

`main_game.gd` is 1330 lines and `main_game.tscn` an 11-node scene. M2 must split every responsibility cleanly. The table below is the load-bearing artifact of this design — it is the checklist the refactor follows.

| Responsibility | Where it lives now | Disposition |
|---|---|---|
| **Band generate / grade / plan / materialise** (`_load_fixtures`, `start_new_run` steps 1–3, `_materialise_band`, `BandGenerator`/`DepthGrader`/`JunkPlacer`/`JunkSpawner`, `SocketSealer`) | `main_game.gd:172-187, 208-336, 855-887` | **STAYS in dive.** Core dive build. Untouched (so fp `e943ac9c8bc1` unmoved). |
| **Gate / extract placement** (`_place_gate`, `_spawn_gate_at`, K7 exit logic, `_exit_*`) | `main_game.gd:1074-1182` | **STAYS in dive.** |
| **Hazard spawning** (R1 `_spawn_r1_hazards`, J3 density, K5i `_spawn_new_hazards`, R4 nodes) | `main_game.gd:338-654, 890-905` | **STAYS in dive.** |
| **Player spawn-at-entry + camera rig** (`_entry_spawn_position`, `_camera`/`_camera_rig`, K3/K6) | `main_game.gd:280-296, 972-993, 1063-1071` | **STAYS in dive** (the Hub has its OWN fixed player spawn + a simpler camera — see (b)). |
| **DiveClock** (the K4 timer node + `ReturnCost.dive_clock` injection) | `.tscn` node + `main_game.gd:148-150` | **STAYS in dive — DIVE-ONLY (LOCKED).** The `DiveClock` node lives ONLY in `main_game.tscn`. It is never instanced in the Hub. Proof: it self-starts off `EventBus.run_started` (`dive_clock.gd:_on_run_started`) which only `GameState.start_run` emits — and the Hub never calls `start_run`. |
| **Depth driver / corridor-time / nav telemetry** (`_build_cell_depth_map`, `_resolve_player_depth`, `_accumulate_piece_time`, J4/R4) | `main_game.gd:907-1060` | **STAYS in dive.** |
| **Throw seam** (L1: `_unhandled_input` throw, `_try_throw`, `_spawn_thrown_item`, `_inventory_panel` ref) | `main_game.gd:1196-1271` | **STAYS in dive** (it reads run-state + the dive HUD; gated on `run_active`). |
| **Run lifecycle drive** (`start_new_run`, `_clear_band`, `stage_run_config`, `start_run`, `enter_band`, seeding) | `main_game.gd:208-336, 1185-1194, 1323-1330` | **STAYS in dive** — but its **entry trigger changes**: instead of the Start button calling `start_new_run`, the dive scene starts the run on its own `_ready` (it IS the dive now — entering it == diving). See (b) + OQ-3. |
| **`MainMenu` `CanvasLayer` + Backdrop + Title + Hint + Start button + VersionLabel** | `.tscn:42-101` + `main_game.gd:59-61, 151-152, 166, 1276-1289, 1314-1320` (`_show_menu`/`_hide_menu`/`_on_start_pressed`/`_on_back_to_config`) | **MOVES to Menu (M1).** **M2 STRIPS all of it** from `main_game.*`. The Main Menu (`scenes/menu/main_menu.tscn`, M1) is the new app entry and owns Title/Start("New Game"/"Continue")/Version. |
| **`ConfigMenu` rail** (`%ConfigMenu`, `apply_and_get_config()`) | `.tscn:52` + `main_game.gd:75, 223` | **MOVES OFF the first screen (M4 owns the P-key tabbed reorg).** For M2's dive-only refactor: the dive no longer reads a *menu-embedded* `ConfigMenu`. The dive must still resolve a `RunConfig` — fall back to `RunConfig.make_default_play_preset()` when no config menu is present (the existing null-branch at `main_game.gd:223` already does this). M4 re-homes the debug menu as a P overlay; **M2 only removes the menu-embedded rail dependency**, it does not build M4's overlay (see OQ-3, OQ-9). |
| **First-run telemetry consent** (G6: `ConsentPromptScript`, `_maybe_show_consent_prompt`, `_consent_pending`) | `main_game.gd:38-41, 139-140, 167-169, 1291-1311` | **MOVES to Menu (M1).** The Breakdown §3 M1 row re-homes G6 to the Main Menu. **M2 STRIPS** the consent code from `main_game.*`. |
| **`SellScreen` auto-present on run-end** (`$SellScreen`, `continue_pressed`→`_on_continue_pressed`, `back_to_config_pressed`→`_on_back_to_config`, `_on_run_ended` freeze) | `.tscn:40` + `main_game.gd:62, 153-165, 196-199, 841-853, 1287-1289` | **MOVES to Shop (M3) — but M2 OWNS THE SEAM.** M2 removes the auto-present + the SellScreen-driven restart loop, and instead **routes run-end to the Hub** (the dive ends → return to Hub via the router). M3 then builds the Shop sell. **M2 must NOT drop the responsibilities `SellScreen` carried** — inventory below. |
| **DecisionHUD / InventoryPanel / oppositions** (`$DecisionHUD`, `$ReturnCost`, `$ExposureMeter`) | `.tscn:30-38` | **STAYS in dive.** These are dive-HUD/run-state consumers; they belong with the dive. (M4 may re-home debug UI, not these.) |

### How run-end currently flows, and where it must flow instead

**Today:** a run ends in exactly one place — `GameState.end_run(reason, duration_s)` emits **`EventBus.run_ended(reason, duration_s, depth_reached)`** (`game_state.gd:284-297`). All three causes converge there: extract (`extract_and_end_run`→`end_run(&"extract")`, `game_state.gd:226-259`), death (`fail_run`→`end_run`, `game_state.gd:459+`), timeout (`dive_clock_timeout`→`_on_dive_clock_timeout`→`fail_run`→`end_run`). On `run_ended`, **`SellScreen._on_run_ended`** (`sell_screen.gd:120-124`) auto-pauses the tree, sells the bank, presents the reward beat, and on Continue calls back into `main_game.start_new_run` (the loop). `main_game._on_run_ended` (`main_game.gd:841-853`) just freezes the player + emits the corridor-time summary.

**After M2:** `run_ended` is still the single resolve point (arity LOCKED — Breakdown §6). But:
- The dive scene's `_on_run_ended` no longer relies on `SellScreen` to drive the next step. Instead it **routes back to the Hub** via the M0 router (e.g. `EventBus.returned_to_hub.emit()` → router loads `hub.tscn`, or the dive calls the router's `return_to_hub()`).
- **The haul is held banked, not auto-sold.** `extract_and_end_run` already banks item *identities* into `GameState.banked_junk` (meta) at the gate (`game_state.gd:234-238`) — it does **not** sell. Selling is `SellScreen`'s `GameState.sell_banked_junk(source)` call (`sell_screen.gd:135`). After M2, the bank survives the return to the Hub (it's meta), and **M3's Shop** converts it. Director-confirmed (Breakdown §7): the haul is *held* on hub-return and only converts at the Shop. **For M2's milestone to be self-contained before M3 lands**, see OQ-8 (a stub readout / hold of the bank so the loop is playable between M2 and M3).
- The `DiveClock` stops on `run_ended` already (`dive_clock.gd:_on_run_ended` sets `_active=false`) — and is gone entirely once we're in the Hub (the dive scene is torn down or hidden, depending on the M0 router mechanism).

**The `SellScreen` responsibility inventory (so M3 drops nothing — the riskiest seam, Breakdown §7):**
1. **Sell the banked haul → Money** (`GameState.sell_banked_junk(source)`, the per-item breakdown + the persistent total roll-up) — **moves to the M3 Shop SELL.**
2. **Quota outcome readout** (`_render_quota` off `GameState.last_quota_result()`, the "Quota cleared" / "QUOTA MISSED" line, `sell_screen.gd:162-184`) — **moves to the M3 Shop / Hub-return beat** (Breakdown §3 M3 row: "Quota outcome readout re-homed").
3. **Roguelite wipe routing** (`pending_wipe()` → `main_game._on_continue_pressed` calls `GameState.wipe_meta()` before the next run, `sell_screen.gd:168-188` + `main_game.gd:196-199`) — **moves with the quota readout** (whoever shows the MISS shows/triggers the wipe). M2 must ensure the wipe still happens somewhere before the next dive.
4. **Title by reason** (EXTRACTED / RUN LOST — kept N) — cosmetic; **moves to the Shop/Hub-return beat.**
5. **The "Continue" / "Back to Config" loop entry** — **superseded by the Hub.** "Continue" (loop into a fresh dive) is now "walk to the portal and depart again"; "Back to Config" is now the P-key debug menu (M4). M2 deletes these handlers from `main_game`.
6. **Web "Export telemetry" button** (`_setup_export_control`, `TelemetryExporter`, `sell_screen.gd:88-116`) — **needs a new home** (Breakdown §7: "Shop UI? a Hub terminal? the debug menu?"). M2 flags it (OQ-7); M3/M4 home it. **M2 must not let it vanish** — until re-homed, either keep a `SellScreen`-as-component alive off-screen or note the gap explicitly (OQ-7).

**M2's responsibility re: SellScreen:** M2 *retires `SellScreen` as the auto-present-on-run-end screen* (stops `main_game` from showing it and from looping through its `continue_pressed`). M2 does **not** build the Shop (that's M3). The clean seam: M2 routes run-end → Hub; M3 (sequenced after M2) builds the Shop interactable that does items 1–4 above and re-homes 6. Because M3 is sequenced after M2 on the hub file, the two coordinate directly. See OQ-8 for what M2 ships as the interim so the loop is testable between M2-merge and M3-merge.

### Carried contracts grounding

- **Greybox only** (Breakdown §2): the Hub is a small default-theme top-down room — `StaticBody2D` walls (greybox `ColorRect`/`CollisionShape2D`), the player, a portal interactable, a shop anchor. No authored art, no new band.
- **The Hub holds NO run-state** (Breakdown §2, `game_state.gd` boundary): it never calls `start_run`/`enter_band`/`stage_run_config`; it reads only meta (Money, `banked_junk`) for display. There is no `DiveClock`, no `RunInventory`, no `active_run_config` in the Hub.
- **fp + knob count unmoved:** M2 touches no generation and adds no `RunConfig` knob → `e943ac9c8bc1` byte-identical, 89-knob count holds. The hub is pure new structure.
- **`run_ended` arity locked; telemetry additive** — M2 emits only M0-pre-declared signals (`dive_requested`, `hub_entered`/`returned_to_hub`); it adds none of its own to `event_bus.gd` (M0 is the single writer).
- **`run/main_scene` swap is M0's** (Breakdown §6): M0 repoints the app entry to `main_menu.tscn`. M2 must verify the CI smoke test + RG verify scenes don't hard-assume `main_game` is the entry (see OQ-10 — they `load()` scenes directly, so they're fine, but M2 confirms).

---

## (b) Pseudocode (illustrative, against the real as-built APIs)

> All sketches are illustrative. The load-bearing decisions (router mechanism, exactly where run-end routing + quota + wipe land, the interim sell-hold) are Open Questions below; the pseudocode shows the **recommended** shape and flags branch points inline. The router calls (`AppRouter.*` / `EventBus.dive_requested` etc.) are **M0's API** — M2 uses whatever M0 ships; the names below are placeholders pending M0's lock.

### B0. `scenes/hub/hub.tscn` — node-tree sketch (greybox)

```
Hub (Node2D)                         # hub.gd attached; the scene the router shows between runs
├── Room (Node2D)                    # greybox geometry container (the "junkyard surface" shell)
│   ├── Floor (ColorRect)            # backdrop fill, behind everything (a flat greybox floor)
│   └── Walls (StaticBody2D)         # collision_layer = world(2); 4 wall ColorRects + CollisionShape2Ds
│       ├── WallN/S/E/W (each: ColorRect visual + CollisionShape2D)   # box the player in (BUG3-style closed space)
├── PlayerSpawn (Marker2D)           # fixed hub spawn point (NOT a generated entry — the hub is static)
├── Player (instance of player.tscn) # the SAME player scene the dive uses; brings its InteractionDetector
├── DeparturePortal (instance of departure_portal.tscn)   # greybox Area2D + child Interactable(id=&"portal")
├── ShopAnchor (Marker2D)            # M2 mounts an EMPTY anchor; M3 instances its shop interactable here
└── HubCamera (Camera2D)             # simple fixed/follow camera (NO CameraView config rig — hub is static)
```

`scenes/hub/departure_portal.tscn` (greybox, modeled on `extract_gate.tscn`):

```
DeparturePortal (Area2D)             # departure_portal.gd; collision_layer=0, mask=0 (it detects nothing)
├── Body (ColorRect)                 # greybox portal visual (distinct colour from the green gate)
├── Interactable (Area2D)            # collision_layer = 4 (interactable bit 3), mask = 0
│   │   script = interactable.gd, interactable_id = &"portal",
│   │   display_name = "Departure Portal", prompt_text = "Dive"
│   └── CollisionShape2D (RectangleShape2D)
```

### B1. `hub.gd` — the hub orchestrator (reads meta only; NO run-state, NO clock)

```gdscript
class_name Hub
extends Node2D
## Hub (M2, M1.6) — the walkable between-runs surface. Reads META ONLY (Money,
## banked haul). Holds NO run-state: it never calls GameState.start_run/enter_band,
## never instances a DiveClock, never builds a RunInventory. Entered from the Main
## Menu and returned-to after every dive. The departure portal launches a dive via
## the M0 router; the shop anchor is mounted here for M3 to fill.

@onready var _player: Player = $Player
@onready var _player_spawn: Marker2D = $PlayerSpawn

func _ready() -> void:
    # Place the player at the fixed hub spawn (static room — no generated entry).
    _player.global_position = _player_spawn.global_position
    _player.velocity = Vector2.ZERO
    # The portal owns the dive-launch on its own interaction_requested handler (B2);
    # the hub need not subscribe. We announce arrival for telemetry/audio (M0 signal).
    EventBus.hub_entered.emit()             # M0-declared; additive, primitives-only
    # NB: NO GameState.start_run, NO DiveClock instance, NO stage_run_config here.
    # The clock cannot tick in the hub because nothing emits run_started here.

# Optional: a between-runs camera. The hub is static, so a plain Camera2D centred on
# the room (or a light follow) suffices — NOT the dive's CameraView config rig (which
# reads cam_* run-config knobs that don't exist outside a run).
```

### B2. `departure_portal.gd` — copy the gate's interaction pattern, swap the action

```gdscript
class_name DeparturePortal
extends Area2D
## DeparturePortal (M2) — the "leave the hub, start a dive" interactable. Built on the
## ExtractGate pattern (extract_gate.gd): a dumb interactable whose OWNER acts on
## EventBus.interaction_requested. Where the gate calls GameState.extract_and_end_run,
## the portal asks the M0 router to load the dive (EventBus.dive_requested / AppRouter).

@export var interactable_id: StringName = &"portal"
@export var input_lockout_s: float = 0.25     # fat-finger guard, mirrors extract_gate.gd:35
var _locked: bool = false

func _ready() -> void:
    EventBus.interaction_requested.connect(_on_interaction_requested)

func _on_interaction_requested(id: StringName, target: Node) -> void:
    if id != interactable_id:
        return
    # Node-identity guard (extract_gate.gd:46-47): only act when WE are the focused
    # target, so a same-id interactable can't cross-fire.
    if target != null and target.get_parent() != self:
        return
    if _locked:
        return
    _locked = true
    _start_lockout()                  # SceneTree timer, copied from extract_gate.gd:55-62
    # Launch the dive through the M0 router. The router loads main_game.tscn (the
    # dive-only scene). The dive starts its run on its own _ready (B3) — the portal
    # does NOT call start_run (run-state is the dive's, not the hub's).
    EventBus.dive_requested.emit()    # M0-declared; the M0 router listens + swaps scenes
```

### B3. The dive-only `main_game` after refactor — what's STRIPPED, what STAYS

`main_game.tscn` after M2 (nodes REMOVED struck through; everything else unchanged):

```
MainGame (Node2D)
├── BandContainer        # STAYS
├── Player               # STAYS (spawned at the generated entry; same scene as the hub's)
├── CameraRig/CameraView # STAYS (the dive's config-driven camera)
├── DiveClock            # STAYS — DIVE-ONLY (this is the ONLY place the node exists)
├── ReturnCost           # STAYS
├── ExposureMeter        # STAYS
├── DecisionHUD          # STAYS (the dive HUD + InventoryPanel)
├── ~~SellScreen~~       # REMOVED by M2 (M3 builds the Shop sell). See OQ-8 for the interim.
└── ~~MainMenu~~         # REMOVED by M2 (Backdrop / ConfigMenu / Center/Title/Hint/StartButton / VersionLabel)
                         #   → the Main Menu (M1) + the P-key debug menu (M4) own these now.
```

`main_game.gd` after M2 (the menu/consent/sell-loop surface deleted; the dive build + run-end routing kept):

```gdscript
func _ready() -> void:
    _load_fixtures()
    if _return_cost != null:
        _return_cost.dive_clock = _dive_clock     # STAYS (R2 injection)
    # STRIPPED: _version_label, _start_button.pressed.connect, _show_menu(),
    #           _maybe_show_consent_prompt(), the SellScreen continue/back wiring.
    # _on_run_ended stays connected (it now routes to the hub, not a SellScreen).
    EventBus.run_ended.connect(_on_run_ended)
    # The dive scene IS the dive: entering it == diving. Start the run immediately
    # (was: gated behind the Start button → start_new_run). OQ-3 confirms this is the
    # single dive-entry trigger and how the RunConfig is resolved without the menu rail.
    start_new_run()

func start_new_run() -> void:
    # STRIPPED first line: _hide_menu()  (no menu in the dive scene anymore).
    _clear_band()
    ...                                            # generate/grade/plan/materialise — UNCHANGED
    # Config resolution WITHOUT the embedded ConfigMenu rail (OQ-3):
    #   was: var run_cfg := _config_menu.apply_and_get_config() if _config_menu != null else make_default_play_preset()
    #   now: the _config_menu ref is gone → resolve from GameState's staged config (set by the
    #        M4 P-overlay if open) else make_default_play_preset(). The existing null-branch
    #        (main_game.gd:223) ALREADY falls back to make_default_play_preset(), so removing
    #        the rail just always-takes-the-fallback unless M4's overlay staged one.
    var run_cfg: RunConfig = GameState.consume_staged_config_or_default()   # OQ-3 (exact accessor TBD by M0/M4)
    ...                                            # rest of start_new_run UNCHANGED (steps 1–6 + hazard spawns)

func _on_run_ended(_reason, _duration_s, _depth_reached) -> void:
    EventBus.corridor_time_summary.emit(_corridor_time_s, _room_time_s)   # STAYS (J4)
    if _player != null:
        _player.velocity = Vector2.ZERO                                   # STAYS (freeze)
    # NEW (M2): route back to the hub instead of waiting on SellScreen.continue_pressed.
    # The haul is already banked into meta (extract) or resolved to pockets (death/timeout)
    # by GameState; the hub will read meta. Quota readout + wipe land per OQ-6.
    EventBus.returned_to_hub.emit(_reason)     # M0 router listens → loads hub.tscn
    # (OR: AppRouter.return_to_hub() — whichever M0's mechanism exposes.)

# DELETED entirely: _on_start_pressed, _on_continue_pressed, _on_back_to_config,
#                   _maybe_show_consent_prompt, _on_consent_choice, _show_menu, _hide_menu,
#                   and the @onready refs _menu/_start_button/_version_label/_config_menu/_sell_screen.
```

### B4. The router handoff (Menu → Hub → Dive → Hub) — proof of the round-trip

> The mechanism (`change_scene_to_file` vs. persistent-root `App`) is M0's (OQ-2). Either way the *flow* is:

```
[M1 Main Menu]  --New Game/Continue-->  router.show(hub.tscn)
[Hub]           portal interact → EventBus.dive_requested → router.show(main_game.tscn)
[Dive]          main_game._ready → start_new_run → GameState.start_run → run_started
                  → DiveClock starts (it exists ONLY here)
[Dive]          extract/death/timeout → GameState.end_run → run_ended
                  → DiveClock stops; main_game._on_run_ended → EventBus.returned_to_hub
                  → router.show(hub.tscn)
[Hub]           hub._ready → player at spawn, hub_entered; NO clock, reads meta only
                  → walk to portal → dive again (loop)
```

### B5. Proof the `DiveClock` is dive-only (the LOCKED invariant)

Three independent guarantees, any one of which suffices; M2 relies on all three:

1. **Scene containment.** The `DiveClock` node exists **only** in `main_game.tscn` (`.tscn:5,28` — `ext_resource systems/dive_clock.tscn`). `hub.tscn` (B0) instances **no** `DiveClock`. The hub scene tree literally has no clock node to tick.
2. **Signal containment.** Even if a clock node existed, `dive_clock.gd:_on_run_started` is the *only* thing that arms it (`_active = true`), and it fires off **`EventBus.run_started`**, which **only `GameState.start_run` emits** (`game_state.gd:155`). The Hub **never calls `start_run`** (B1) → `run_started` never fires in the hub → no clock would arm even if present.
3. **Process-mode containment.** Under a `change_scene_to_file` router, the dive scene (and its `DiveClock`) is **freed** on the return to the hub — it cannot tick because it no longer exists. Under a persistent-root `App` router, the dive scene is removed/hidden; the clock is already `_active=false` (set on `run_ended`, `dive_clock.gd:_on_run_ended`) and gets freed/detached with the dive. (OQ-5 confirms which, per M0's mechanism — but **the invariant holds under both**.)

---

## (c) Open Questions

> Each states the trade-off and a recommendation. **Director-judgment items are flagged `[Director]`.** Fresh-eyes (Phase 3) resolve the technical ones; the vision/fun/scope calls go to the Director.

**OQ-1 — Hub room geometry: reuse a greybox band piece vs. a bespoke small room?**
Options: **(a) bespoke static room** — hand-place 4 `StaticBody2D` walls + a floor `ColorRect` in `hub.tscn`, a fixed `PlayerSpawn` marker, no generation. Simple, fully controlled, reads as "a room you stand in," zero coupling to `BandGenerator`/`ZonePieceData`/cell-space math. **(b) reuse a `ZonePieceData` greybox piece** (one of the B1 room pieces, materialised once) — visually consistent with the dive interior, but drags in the whole materialise/cell-size/`SocketSealer` path for a single static room (overkill; couples the hub to generation code we explicitly don't want it touching). **Recommendation: (a) bespoke static room** — the hub is *the surface*, narratively distinct from the dive interior (the GDD's junkyard yard vs. the band depths), so it *should* look different from a band piece; and a bespoke room keeps the hub 100% decoupled from generation (protecting the fp invariant trivially). Sized so the portal + shop anchor + player have comfortable walking room (~one screen). *Resolvable by fresh-eyes (technical); the "should the surface look like the depths or different" tone note is a soft `[Director]` flag.*

**OQ-2 — The M0 router mechanism M2 builds against (`change_scene_to_file` vs. persistent root `App`).** **[blocks M2 build; M0 owns the decision]**
M2 cannot write the portal→dive and dive→hub handoffs until M0 fixes the mechanism (Breakdown §7). `change_scene_to_file` (simplest) tears down each scene on transition — fine for the hub (it holds no run-state; it rebuilds from meta each return, B1) and fine for the dive (run-state is GameState's, reset in `start_run`). The persistent-root `App` keeps a stable autoload-adjacent mount for the P-debug overlay (M4) + a steady camera. **Recommendation: M2 routes EVERY transition through the M0 router API (`EventBus.dive_requested`/`returned_to_hub` or `AppRouter.show()`), never calling `get_tree().change_scene_*` itself**, so M2 is mechanism-agnostic and M0's choice is transparent to it. The portal emits `dive_requested`; the dive emits `returned_to_hub`; M0's router listens and swaps. *M0 ratifies the mechanism; fresh-eyes confirm M2's handoffs are written against the router API, not a hardcoded scene swap.*

**OQ-3 — How does the dive-only `main_game` trigger the run + resolve its `RunConfig` without the embedded menu?** **[partly M4-coupled]**
Today the Start button → `start_new_run`, and the config comes from `%ConfigMenu.apply_and_get_config()` (`main_game.gd:223`). With the menu stripped: **(i) the run trigger** — recommend `main_game._ready()` calls `start_new_run()` directly (entering the dive scene == diving; the portal already gated the choice). **(ii) the config** — the embedded `ConfigMenu` is gone; the dive must resolve a `RunConfig` from somewhere. Recommend: read a config *staged on `GameState`* by M4's P-overlay if the Director set one, else `RunConfig.make_default_play_preset()` (the existing fallback at `main_game.gd:223`). This needs a tiny `GameState` accessor (a staged-config slot M4's overlay writes) — **but that touches `game_state.gd`, which M0 is the single writer of** (Breakdown §4). So M2 must **flag the accessor to M0** (M0 pre-declares it in its single-writer pass), and M2 *reads* it. If M4's overlay isn't ready when M2 builds, the fallback (`make_default_play_preset`) alone makes the dive fully playable. *Fresh-eyes confirm the accessor belongs in M0's pass; M0 declares it; M4 writes it; M2 reads it. Director confirms "entering the dive scene auto-starts the run" is the intended UX (vs. an in-dive "ready?" beat — recommend auto-start).*

**OQ-4 — Does the Hub reuse the dive's interactor wholesale?**
The player scene carries its `InteractionDetector` + `prompt_scene` self-contained, and the `Interactable`/`interaction_requested` contract is owner-agnostic. So instancing `player.tscn` into the hub gives a working interactor with **zero** changes. The only consideration: `interaction_requested` is a **global `EventBus`** signal — every `Interactable` owner in the loaded scene hears it. In the hub the owners are the portal (and M3's shop); in the dive they're junk/gates. Under a `change_scene_to_file` router these never coexist (one scene at a time), so there is no cross-fire. Under a persistent-root `App` router, **only one of {hub, dive} is in the tree at a time**, so still no cross-fire — *provided* the inactive scene's owners are detached/freed (they are, B4). **Recommendation: reuse the player + its detector wholesale, unchanged.** The node-identity guard (`get_parent() != self`, copied into the portal) is the belt-and-braces that makes same-id interactables safe regardless. *Fresh-eyes confirm no cross-scene `interaction_requested` listener survives a transition under M0's chosen mechanism.*

**OQ-5 — How does the Hub "rebuild on each return" given teardown?** **[coupled to OQ-2]**
The Hub holds no run-state, so a full rebuild from scratch on each return is *correct and cheap*: `hub._ready` places the player at the spawn and reads meta for any display (B1). Under `change_scene_to_file`, the hub scene is freed on dive-launch and re-instanced fresh on return — a clean rebuild, no stale state possible. Under persistent-root `App`, the hub node could be *kept* and re-shown (player re-positioned) or *re-instanced*. **Recommendation: re-instance the hub fresh on every entry** (even under a persistent root) — it's stateless, the rebuild is trivial (a static room), and "fresh every time" eliminates any stale-player-position / lingering-node class of bug. The only thing that must persist across the round-trip is **meta** (GameState handles that) — never the hub node itself. *Fresh-eyes confirm the fresh-rebuild is safe under M0's mechanism; trivially true under `change_scene_to_file`.*

**OQ-6 — Exactly where do run-end routing + quota readout + wipe routing land, given `SellScreen` retires?** **[the riskiest seam — partly `[Director]`]**
`SellScreen` currently owns three run-end jobs M2 must re-route (see (a) inventory): the **sell tally** (→ M3 Shop), the **quota readout** (`_render_quota`), and the **wipe routing** (`pending_wipe`→`wipe_meta`). M2 retires the auto-present and routes run-end → Hub (B3). But the **quota MISS → wipe** must still fire before the next dive. Options: **(a)** the **Hub-return beat** shows the quota outcome (a hub banner/modal) and triggers the wipe on a MISS — quota+wipe live in the hub/return; the Shop only sells. **(b)** the **Shop** shows the quota outcome + triggers the wipe when you visit it — but then a player who returns and *immediately re-dives without visiting the shop* skips the wipe (a loop-integrity hole). **Recommendation: (a) the Hub-return beat owns the quota readout + the wipe** (it's guaranteed to run on every return, closing the hole), and the **Shop owns only sell+buy**. Concretely: on `returned_to_hub`, read `GameState.last_quota_result()`; if MISS, show the outcome + `GameState.wipe_meta()` before re-enabling the portal. **Because this logic + `game_state.gd` reads sit at the M2↔M3 boundary and M3 is sequenced after M2, M2 should ship the run-end→Hub routing + a minimal quota/wipe hook, and M3 layers the Shop on top.** *Director ratifies "quota outcome + wipe live in the Hub-return beat, not the Shop"; fresh-eyes confirm the wipe-before-redive integrity.*

**OQ-7 — Where does the web "Export telemetry" button go when `SellScreen` retires?** **[Director — scope]**
`SellScreen._setup_export_control` (`sell_screen.gd:88-116`) is the *only* web-build telemetry-export UI, and it's load-bearing for the playtest gate (RG2 needs web telemetry back). Retiring `SellScreen` orphans it. Breakdown §7 names candidates: Shop UI, a Hub terminal, or the debug menu. **Recommendation: a Hub terminal / button** (or fold it into M4's P-debug overlay, which is available in all three states) — it's a debug/meta affordance, not a between-runs reward beat. **M2's obligation: do NOT silently drop it.** Until it's re-homed (M3 or M4), M2 flags the gap explicitly and the orchestrator assigns the new home. The cheapest M2-interim: a tiny "telemetry" button on the Hub that calls the same `TelemetryExporter.export()` path (web-guarded exactly as `_setup_export_control`). *Director/orchestrator picks the final home (Shop vs Hub vs P-menu); M2 ensures it isn't lost.*

**OQ-8 — What does M2 ship as the interim sell-hold, given M3 lands AFTER M2?** **[scope]**
Between M2-merge and M3-merge, the loop boots Menu→Hub→Dive→Hub, but **nothing sells the banked haul** (the Shop is M3). Options: **(a)** M2 ships a *temporary* hub readout of the held bank (a label: "Held: N items, ~$X" off `GameState.banked_junk` + `run_haul_value`-style sum) so the loop is observable and the haul visibly accumulates — M3 replaces it with the real Shop. **(b)** M2 keeps `SellScreen` alive as a *manual* hub-invoked screen (not auto-present) so selling still works pre-M3 — but that contradicts "retire SellScreen" and risks M3 having to undo it. **(c)** M2 ships the round-trip with the haul simply held + un-sellable until M3 — the milestone isn't player-complete until M3, which is fine since RG1 gates the *whole* M1.6 (Breakdown §5 Wave 3 sequences M3 before RG). **Recommendation: (a)** — a throwaway hub "held haul" readout: makes the M2 round-trip self-demonstrating, drops cleanly when M3's Shop lands, and never resurrects the retired auto-`SellScreen`. *Fresh-eyes/orchestrator confirm the interim readout is acceptable scope for M2; it's deleted by M3.*

**OQ-9 — Does the player's aim/throw do anything in the hub? (movement-only?)**
The player scene brings its full kit: movement, mouse/right-stick **aim** (`player.gd:64-90`), and — in the dive — the **throw** seam. But the throw lives in **`main_game.gd`** (`_try_throw`, gated on `GameState.run_active` and `throw_enabled`), **not** in the player or the hub. So in the hub: **aim updates harmlessly** (the nose rotates toward the cursor — cosmetic, no effect), and **throw is impossible** (no `main_game` throw handler in the hub scene, and `run_active` is false anyway). **Recommendation: movement-only in the hub, by construction — no code needed.** The hub simply doesn't wire a throw handler; the player's aim is left as harmless cosmetic polish (or the nose can be ignored). *Resolvable by fresh-eyes — confirm nothing in `player.gd` requires a run and the throw seam is `main_game`-resident (verified: it is, `main_game.gd:1196-1271`).*

**OQ-10 — Do CI / test scenes that load `main_game` directly break under the dive-only refactor + the `run/main_scene` swap?** **[verify before merge]**
The `run/main_scene` swap is M0's (Menu becomes the entry), but M2's *refactor of `main_game.tscn`* (removing `MainMenu`/`SellScreen`/`ConfigMenu` nodes + the `_config_menu`/`_sell_screen`/`_start_button` refs) can break tests that drive those. Findings: (1) `tools/ci_smoke_test.gd` does **not** load `main_game` (it loads data Resources directly — `grep` shows only `load("res://data/junk/...")`), so the entry swap + refactor don't touch it. (2) The **RG verify tests** (`tests/test_rg1_m1*.gd`, `test_main_game_loop.gd`) **do** `load("res://scenes/game/main_game.tscn")` + `instantiate() as MainGame` and **drive the run via the scene** (`test_rg1_m15_verify.gd:100-104`). These assume the assembled dive auto-starts a run *and/or* drive it through the (now-removed) Start button / `start_new_run`. **M2 must update these tests** to the dive-only entry: they should instance `main_game.tscn`, expect `start_new_run` to fire on `_ready` (OQ-3) or call it directly, and **must NOT reference `$MainMenu`/`$SellScreen`/`%ConfigMenu`/`%StartButton`**. Any test that asserted "SellScreen presents on run_ended" must move that assertion to the hub-return routing (or be retired with `SellScreen`). **This is in-scope for M2** (the refactor owns its test fallout). *Fresh-eyes enumerate every `main_game`-loading test + the exact node refs each uses, so the M2 builder fixes them all in the refactor branch (the qa role may co-own this half).*

---

## Carried contracts (restated for the builder)

- **No run-state in the hub:** `hub.gd` never calls `start_run`/`enter_band`/`stage_run_config`/`bank_haul`, never builds a `RunInventory` or `DiveClock`. It reads meta (`GameState.money`, `banked_junk`) for display only. The dive scene owns all run-state exactly as today.
- **`DiveClock` dive-only:** the node exists ONLY in `main_game.tscn`; it arms only off `run_started` which only `start_run` emits, which the hub never calls (B5). Three independent guarantees.
- **fp + knob count unmoved:** the hub touches no generation and adds no `RunConfig` knob → `e943ac9c8bc1` byte-identical, 89-knob count holds. M2 is pure structure.
- **`run_ended` arity locked; telemetry additive:** M2 emits only M0-pre-declared signals (`dive_requested`, `hub_entered`, `returned_to_hub`); it never writes `event_bus.gd` (M0 is the single writer).
- **Single-writer-per-file in the wave:** M2 owns `scenes/hub/*` + the `main_game.*` refactor (the milestone's main-scene seam). M1 (menu) and M4 (config) do not touch these. M3 is **sequenced after M2** on the hub file (rebase + add the shop interactable into `ShopAnchor`). M2 does **not** write `game_state.gd`/`event_bus.gd`/`project.godot` — those are M0's (M2 flags the staged-config accessor (OQ-3) + any new signal name to M0).
- **`SellScreen` retired by M2 as the auto-present screen; its responsibilities re-homed per the (a) inventory** (sell→M3 Shop, quota+wipe→Hub-return beat (OQ-6), web export→Hub/P-menu (OQ-7)) — M2 drops none of them silently.

---

## Definition of done (for the build task, after lock)

- `scenes/hub/hub.tscn` (+ `hub.gd`) exists: a walkable greybox room, the `Player` instanced + spawned at a fixed marker, a `DeparturePortal` interactable, a mounted-but-inert `ShopAnchor` (Marker2D) for M3, a simple hub camera. **No `DiveClock`, no run-state.**
- `scenes/hub/departure_portal.tscn` (+ `.gd`): a greybox `Area2D` with a child `Interactable(id=&"portal")`, whose owner fires the dive-launch via the M0 router on `interaction_requested` (gate-pattern node-identity guard + lockout copied).
- `main_game.tscn`/`main_game.gd` are **dive-only**: `MainMenu`/`ConfigMenu`/`StartButton`/`VersionLabel`/`SellScreen` nodes + their `@onready` refs + handlers (`_on_start_pressed`/`_on_continue_pressed`/`_on_back_to_config`/`_show_menu`/`_hide_menu`/`_maybe_show_consent_prompt`/`_on_consent_choice`) removed; `start_new_run` no longer calls `_hide_menu`; the dive starts on `_ready` (OQ-3) and resolves `RunConfig` without the embedded rail.
- The round-trip works headlessly + in-editor: Menu→Hub→(portal)→Dive→(run_ended)→Hub, the clock ticking **only** in the dive, the haul held in meta on return.
- Run-end routes to the Hub via the M0 router (`returned_to_hub`); the quota outcome + roguelite wipe fire in the Hub-return beat (OQ-6); the web telemetry-export path is not lost (OQ-7).
- The all-off fp `e943ac9c8bc1` is byte-identical; the 89-knob count holds (no `RunConfig` change).
- The `main_game`-loading tests (RG verify scenes, `test_main_game_loop`) are updated to the dive-only entry; `ci_smoke_test.gd` confirmed unaffected (OQ-10).
- Worklog at `worklogs/<date>-M2-*.md` naming the commit SHA + a "Design deviations" section.

---

## Resolved Decisions (Phase 3)

_(pending — Phase-3 fresh-eyes resolve OQ-1, OQ-4, OQ-5, OQ-9, OQ-10 on technical merit; OQ-2/OQ-3 coordinate with M0's locked router + accessor; OQ-6/OQ-7/OQ-8 carry Director-flagged scope/UX calls. Folded in here as `RD-*` once resolved, mirroring the M1.5 design docs.)_

### Needs Director review (M2)

> Fresh-eyes do NOT self-resolve these — vision/fun/tone/scope calls per the orchestrator loop step 7.

- **DR-M2-1 — Quota outcome + roguelite wipe live in the Hub-return beat, not the Shop (OQ-6).** Recommendation: the Hub-return beat owns the quota readout + the MISS→`wipe_meta` (guaranteed to run on every return, closing the "re-dive without visiting the shop" hole); the Shop owns only sell+buy. *Director ratifies the placement.*
- **DR-M2-2 — The web "Export telemetry" home after `SellScreen` retires (OQ-7).** Recommendation: a Hub terminal/button or fold into M4's P-debug overlay (available in all three states). *Director/orchestrator picks the final home; M2 ensures it isn't lost.*
- **DR-M2-3 — Entering the dive scene auto-starts the run (OQ-3, UX half).** Recommendation: yes — the portal already gated the choice, so the dive scene `_ready` → `start_new_run` (no in-dive "ready?" beat). *Director confirms the UX.*
- **DR-M2-4 (soft) — Should the greybox Hub look distinct from the dive interior (OQ-1 tone note)?** Recommendation: yes, bespoke static room (the surface ≠ the depths, per the GDD). *Director confirms tone.*
