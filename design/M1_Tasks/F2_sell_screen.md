# F2 — Placeholder Sell Screen

**Summary:** A minimal post-extraction screen that lists the banked junk and converts it to Money — greybox UI, no art pass. It shows the payoff so the core loop *visibly closes with a reward*: you pushed your luck, you extracted, here is what it was worth, and your running Money total goes up and persists.

- **Parent task:** F2 (M1 greybox prototype — the reward screen)
- **Dependencies:** F1 (Money ledger + `sell_banked_junk()` conversion), D2 (inventory UI, for greybox row/cell conventions to reuse).
- **Acceptance criterion:** After a successful extract the player sees junk tallied into Money; the running total persists across runs.

## Assets needed

Scenes & nodes (feature-first layout under `/ui/sell/`):
- `ui/sell/sell_screen.tscn` — root `CanvasLayer` (or full-screen `Control`) named `SellScreen`. Greybox: default theme, plain containers, no art.
  - `Backdrop` — `ColorRect` dimming the dive behind it (run is over).
  - `Title` (`Label`) — "EXTRACTED" / "RUN LOST" depending on cause (see Open Questions on whether failure shows this screen).
  - `ItemList` — a `VBoxContainer` (or `ItemList`/`Tree`) of rows, one per banked item: name + value. Reuse D2's greybox row/cell look for consistency.
  - `SubtotalLabel` (`Label`) — "Haul value: 240".
  - `MoneyTotalLabel` (`Label`) — "Money: 1,240" — the *persistent* running total after the sale. This is the reward that makes the loop feel like progress.
  - `ContinueButton` (`Button`) — "Continue" → returns to the run-start / overworld stub (G-series), or restarts a dive for M1 testing.
- (Optional) `ui/sell/sell_row.tscn` — a tiny reusable `Control` for one item row, if not reusing D2's.

Greybox juice (cheap, high-leverage — this is the *reward beat*):
- Count-up animation: tally each item into the subtotal one at a time, then roll `MoneyTotalLabel` up to its new value. A `Tween` is enough; AudioDirector "cha-ching" per item if audio is wired (defer if not).
- This is the only place in M1 the player gets dopamine for winning — worth a little polish even in greybox.

Flow / settings:
- The screen is shown by the run-end flow. Listen to `EventBus.run_end` (from E1/E3) and present on `cause == &"extract"` (and possibly `death|timeout` for kept pockets — Open Questions).
- Pause the dive / tree while shown (`get_tree().paused = true`) so nothing ticks behind it.

## Code to generate

Scripts:
- `ui/sell/sell_screen.gd` (`class_name SellScreen extends CanvasLayer`) — listens for `run_end`, requests the sale from F1, renders the breakdown, animates the tally, shows the persistent total.

Design notes: F2 is **presentation over F1's logic**. It does not compute Money or touch saves itself — it calls `GameState.sell_banked_junk()` (F1), which converts banked items → Money, persists via `SaveManager.save_meta()`, and returns the per-item breakdown F2 renders. The "persists across runs" half of the acceptance is satisfied entirely by F1's save; F2 just *displays* the post-sale `GameState.money`. To prove persistence in testing, the running total shown must read live from meta (`GameState.money`), not from a cached run number.

Ordering matters: capture the breakdown from `sell_banked_junk()` (which empties the bank and credits Money), then animate the count-up *toward* the already-updated `GameState.money`. The save has happened before the animation finishes, so quitting mid-animation still keeps the Money.

```gdscript
# ui/sell/sell_screen.gd
class_name SellScreen
extends CanvasLayer

@onready var item_list: VBoxContainer = %ItemList
@onready var subtotal_label: Label = %SubtotalLabel
@onready var money_total_label: Label = %MoneyTotalLabel
@onready var title_label: Label = %Title

func _ready() -> void:
    hide()
    EventBus.run_end.connect(_on_run_end)

func _on_run_end(cause: StringName, payload: Dictionary) -> void:
    # M1: show on successful extract. (Failure-screen policy: see open questions.)
    if cause != &"extract":
        return
    _present(cause, payload)

func _present(cause: StringName, _payload: Dictionary) -> void:
    title_label.text = "EXTRACTED"
    get_tree().paused = true
    show()

    # F1 does the conversion + persistence; returns what was sold.
    var money_before: int = GameState.money            # capture pre-sale for the roll-up
    var breakdown: Array[Dictionary] = GameState.sell_banked_junk()
    # After this call: banked_junk empty, GameState.money already credited & saved.

    _render_rows(breakdown)
    var subtotal: int = GameState.money - money_before
    _animate_tally(breakdown, subtotal, money_before, GameState.money)

func _render_rows(breakdown: Array[Dictionary]) -> void:
    for child in item_list.get_children():
        child.queue_free()
    for entry in breakdown:
        var row := Label.new()
        row.text = "%s    %d" % [entry["name"], entry["value"]]
        item_list.add_child(row)

func _animate_tally(_breakdown: Array, subtotal: int, money_before: int, money_after: int) -> void:
    subtotal_label.text = "Haul value: %d" % subtotal
    # Roll the persistent total up from before -> after. Money is ALREADY saved;
    # this is pure visual flourish.
    var t := create_tween()
    t.tween_method(func(v: int): money_total_label.text = "Money: %d" % v,
        money_before, money_after, 0.6)

func _on_continue_pressed() -> void:
    get_tree().paused = false
    hide()
    # Return to overworld/run-start stub (G-series), or restart a dive for testing.
```

Edge: a zero-haul extract (player bailed empty) still shows the screen with an empty list, subtotal 0, and the unchanged-but-persistent Money total — confirming "extracting alive with nothing" is a real, legible outcome.

## Open questions

- **Does the sell screen appear on failure too?** On death/timeout (E3), the kept pockets are real Money. Show the same screen titled "RUN LOST — kept N" (reinforces what you barely saved) or just a HUD toast (E3) and skip F2? Showing it closes the loop symmetrically; decide with E3.
  - **Recommendation:** Yes — show the same F2 screen on `death`/`timeout`, titled "RUN LOST — kept N," tallying the surviving pockets into Money. Every run ending on the same beat (win or lose) closes the loop symmetrically and makes the cost of pushing tangible far better than a transient toast. Change `_on_run_end` to accept all three causes and set the title by cause; the conversion path is identical (`sell_banked_junk()` over whatever survived). This matches E3's recommendation.
- **Sell timing / animation length.** How long is the count-up before "Continue" is interactable? Too long is annoying on repeat runs (M1 is loop-heavy testing). Recommend a short tally with a skip/click-to-finish, and instant on a held button.
  - **Recommendation:** Keep the full tally under ~0.6–0.8s, and make **any input (click/key) snap it to completion** so repeat-run testers are never gated by animation. Continue becomes interactable the instant the tally finishes (or is skipped). Because F1 already saved Money *before* the animation starts, the count-up is pure flourish — skipping it never risks the persisted total. This respects M1's loop-heavy testing rhythm.
- **Auto-sell-all vs. choose what to sell.** M1 sells the whole bank at once (no keep-for-later, since there are no upgrades to spend on yet). Confirm no "stash vs. sell" choice is needed until M3's economy lands.
  - **Recommendation:** Auto-sell the entire bank in one action for M1 — no per-item stash/sell choice. With no upgrades, crafting, or item-specific uses until M3, a "keep for later" decision is meaningless and would add UI without testing anything the M1 gate cares about. Defer selective selling/stashing to M3 when the three-currency economy and sinks give those choices real stakes.
- **Where does Continue go?** No overworld in M1 greybox. Continue should route to the run-start stub / restart-a-dive flow (G-series). Pin down the M1 testing loop so F2 doesn't dead-end.
  - **Recommendation:** Continue routes straight back to a minimal **run-start stub that immediately starts a fresh dive** (reset run-state, respawn at spawn, reset the A3 clock) — no overworld menu. The M1 testing loop is the tightest possible "dive → decide → extract/fail → see reward → dive again," which maximizes the number of push-your-luck decisions per playtest session. Have F2's Continue call a single G-series `start_new_run()` entry point so the loop is owned in one place and F2 doesn't dead-end.
- **Itemized vs. lump display.** This doc itemizes (name + value per row) because it's a better reward beat and requires F1 to return a breakdown. If F1 ends up converting at bank time (Option A), F2 may only have a number — keep the screen working in that degraded case (single subtotal row).
  - **Recommendation:** Itemize (name + value per row) — F1's confirmed Option B returns the breakdown, so this is the live path and the stronger reward beat. Still guard the render so an empty or breakdown-less payload (zero-haul extract, or a hypothetical Option-A fallback) degrades gracefully to a single subtotal/total row rather than erroring. Driving rows from the returned array (not a separate query) keeps F2 correct in both cases.
- **Persistence proof.** The running total must read live `GameState.money` (saved by F1), not a run-local sum, so that quitting and relaunching shows the same total. Confirm a manual test: extract, note Money, relaunch, verify total — this is the literal acceptance check.
  - **Recommendation:** Bind `MoneyTotalLabel` to live `GameState.money` (post-`sell_banked_junk()` save), never a run-local accumulator, and animate the count-up *toward* that already-saved value. Add the manual acceptance check to the G-series test checklist: extract, note Money, fully quit, relaunch the same slot, confirm the total matches — this is the literal "persists across runs" acceptance. Because F1 saves before the animation runs, quitting mid-animation must still show the correct total on relaunch.
