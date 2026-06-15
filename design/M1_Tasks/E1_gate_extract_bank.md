# E1 — Gate Node + Extract-and-Bank

**Summary:** A single greybox gate node placed in the band; interacting with it (via A2's interaction component) ends the run **successfully** and **banks** the run inventory — committing the carried haul from `GameState` run-state into meta-state and the meta save. This is the "cash out" half of the core push-your-luck tension.

- **Parent task:** E1 (M1 greybox prototype — extraction)
- **Dependencies:** A2 (interaction component / `interact` action), D1 (slot inventory data model in run-state).
- **Acceptance criterion:** Using the gate ends the run and transfers carried junk to the banked / meta total; an `EventBus` `run_end{cause: extract}` event fires.

## Assets needed

Scenes & nodes (feature-first layout under `/entities/gate/`):
- `entities/gate/extract_gate.tscn` — root `Area2D` (or `StaticBody2D` + child `Area2D`) named `ExtractGate`.
  - `Sprite` — greybox placeholder: a `ColorRect` or `Polygon2D` "doorway" frame (e.g. 48x64, bright green so it reads as the safe exit). Distinct from junk pickups and player.
  - `InteractionTarget` — A2's interaction component (the Area2D / component A2 defines as "interactable"). The gate registers itself as interactable so the player's interaction probe can select it and the `interact` press routes here. Expose an `interaction_prompt: String = "Extract"` so E2's prompt UI can read it.
  - `CollisionShape2D` — a `RectangleShape2D` sized to the gate footprint. Decide layer/mask so it sits on the interactable layer A2 scans (see A1 open question on collision layers).
  - (Optional) `Marker2D` `PlayerSnapPoint` — where the player stands when extracting, if we stage an animation later.

Data / resources:
- No new `.tres` required for E1 itself. The gate consumes the existing `JunkItem` Resource shape (id, display name, slot flags, base sell value, greybox color/shape) from D1 and the `Money` ledger from F1. E1 should not hard-depend on F1's conversion — bank the *items*, let F1 own the Money math (see Code).

Project / autoload touchpoints:
- `GameState` (autoload) — already holds run-state `run_inventory` (D1) and meta-state. E1 adds/uses a `bank_run_inventory()` flow on it.
- `EventBus` (autoload) — `run_end(cause: StringName, payload: Dictionary)` signal (shared across E1/E3).
- `SaveManager` (autoload) — `save_meta()` to persist the updated meta after banking; atomic write + `.bak` per the decided model.
- `Telemetry` listens to `run_end` already; no direct E1 wiring needed.

## Code to generate

Scripts:
- `entities/gate/extract_gate.gd` (`class_name ExtractGate extends Area2D`) — thin: when A2 fires "interacted", call the banking flow and end the run.
- Additions to `systems/game_state.gd` (the `GameState` autoload) — `bank_run_inventory()` and `end_run(cause, payload)`.
- `EventBus` signal declaration (shared with E3): `signal run_end(cause: StringName, payload: Dictionary)`.

Design notes: E1 is the canonical **run-state → meta-state transfer**. The gate node itself stays dumb — it only knows "the player chose to extract here." `GameState` owns the actual transfer so E3 (death/timeout) and E1 (extract) share one code path for "the run is ending; resolve the haul." Banking moves the *item list* into meta (`banked_junk`); F1 then converts banked items to Money. Keeping the item identities in meta (not just a Money number) lets F2's sell screen itemize the payoff and lets us add per-item sell mechanics later without reworking E1.

```gdscript
# entities/gate/extract_gate.gd
class_name ExtractGate
extends Area2D

@export var interaction_prompt: String = "Extract"

# Called by A2's interaction component when the player presses `interact`
# while this gate is the selected interactable.
func on_interacted(_by: Node) -> void:
    # Hand off entirely to GameState; the gate does not touch save/meta itself.
    GameState.extract_and_end_run()
```

```gdscript
# systems/game_state.gd  (GameState autoload — partial)

# --- run-state (disposable: current dive + unbanked haul) ---
var run_inventory: Array[JunkItem] = []   # owned by D1
var run_depth: int = 0                     # from B3
# ... clock etc. from A3 ...

# --- meta-state (persistent) ---
var banked_junk: Array[JunkItem] = []      # items committed across runs (pre-sell, or post if F2 sells immediately)
# money lives here too once F1 lands: var money: int = 0

func extract_and_end_run() -> void:
    var transferred: Array[JunkItem] = bank_run_inventory()
    var banked_value: int = _sum_values(transferred)

    # F1 converts items -> Money here (or F2 does at sell time). See F1.
    # _credit_money(banked_value)  # enabled once F1 exists

    SaveManager.save_meta()        # atomic write + .bak; meta now durable

    EventBus.run_end.emit(&"extract", {
        "items_banked": transferred.size(),
        "value_banked": banked_value,
        "depth": run_depth,
    })

    _teardown_run_state()          # clear run_inventory, clock, depth, etc.

# Pure transfer: move every run item into meta banked list, empty run inventory.
func bank_run_inventory() -> Array[JunkItem]:
    var moved: Array[JunkItem] = run_inventory.duplicate()
    for item in moved:
        banked_junk.append(item)
    run_inventory.clear()
    return moved

func _sum_values(items: Array[JunkItem]) -> int:
    var total: int = 0
    for item in items:
        total += item.base_sell_value
    return total

func _teardown_run_state() -> void:
    run_inventory.clear()
    run_depth = 0
    # reset clock (A3) and any other disposable run-state here
```

Wiring: A2 dispatches `interact` to the currently-selected interactable. The gate exposes `on_interacted(by)`; A2 calls it (or emits a signal the gate connects to). Either way E1 must not duplicate A2's selection logic — it only implements the response.

## Open questions

- **Is banking instant or staged?** M1 simplest is instant on interact (no hold, no animation). Do we want a short hold-to-extract (controller-friendly, prevents fat-finger) or an "are you sure" confirm? A confirm fights the ~30s tension E2 wants; recommend instant for the feedback gate, revisit if testers extract by accident.
  - **Recommendation:** Instant on a single `interact` press for M1 — no hold, no confirm. Extraction is the *safe* choice in a push-your-luck loop, so the friction belongs on "push deeper," not on cashing out; a confirm dialog would dampen exactly the snap-decision tension E2 is built to measure. Add a 200–300 ms input lockout right after the press to absorb fat-fingers without a visible prompt, and only escalate to hold-to-extract if playtests show accidental extracts.
- **Bank items vs. bank Money directly?** This doc banks *item identities* into `banked_junk` so F2 can itemize. Alternative: convert to Money at the gate (E1 calls F1) and discard items. Decide whether the sell screen (F2) sells from `banked_junk` or whether E1 already turned it into Money. (Recommendation: keep items until F2 sells, so the payoff is visible per-item.)
  - **Recommendation:** Bank item identities into `banked_junk`; defer the Money conversion to F2's `sell_banked_junk()` (F1 Option B). The itemized count-up is the only winning-dopamine beat in M1, and keeping items (not a number) is also forward-compatible with M3's three-currency split and per-item sell rules without reworking E1. E1 must not call F1's credit path — it only moves items.
- **Does extract require a non-empty inventory?** Should the gate allow a zero-haul extract (valid "bail out alive" choice) or block/warn? Bailing empty is a legitimate push-your-luck outcome; recommend allowing it and still firing `run_end{cause: extract}` with value 0.
  - **Recommendation:** Allow zero-haul extract; fire `run_end{cause: extract}` with `value_banked: 0` and let F2 show the empty-list/unchanged-total screen. "Bail out alive with nothing" is a real strategic outcome in extraction design (cutting losses is a valid response to clock pressure), so blocking it would remove a legitimate branch the M1 gate is meant to test. No warning needed.
- **Gate placement / count in M1.** One gate per band for M1 — fixed location or seeded by B3? Its distance from spawn is the "push deeper" axis E2 visualizes, so placement is load-bearing for the test, not cosmetic.
  - **Recommendation:** One gate, placed at a **fixed, hand-authored** location near (but not on) spawn for M1, so the distance/clock trade-off is identical every run and testers' "extract vs. push" decisions are comparable across sessions. Seeded placement adds run-to-run noise that would confound the kill/pivot read; defer randomized gate positions to post-M1 once the tension is proven. Keep the position as one tunable constant so it can be moved between playtest builds.
- **Save timing.** Save meta synchronously on extract (simplest, matches "autosave-on-extract can never corrupt" intent) vs. deferred. Synchronous is fine at M1 data sizes; confirm it doesn't hitch.
  - **Recommendation:** Save synchronously on extract. At M1 data sizes (one int + a handful of `{id, value}` records via `store_var`) the write is sub-millisecond and the dive is already paused on the F2 screen, so a hitch is a non-issue; defer/async only becomes worth its complexity at much larger save payloads. The synchronous atomic write (temp file → fsync → rename, with `.bak`) is exactly what makes "autosave-on-extract can never corrupt" true ([Godot atomic-write sync-before-rename](https://github.com/godotengine/godot/pull/98361)).
- **Collision layer agreement.** The gate's interactable Area must sit on the same layer A2 scans and not collide with player movement — pin this down with A1/A2's layer table.
  - **Recommendation:** Put the gate's interaction Area2D on a dedicated `interactable` physics layer (the same single layer A2's interaction probe has in its mask) and on **no** layer the player's movement body masks, so the player walks through/up to it without physical collision. Reuse the exact layer index junk pickups use for interactables to keep A2's probe logic uniform; record the chosen index in A1/A2's layer table as the single source of truth. The gate's body should never participate in movement collision in M1.
