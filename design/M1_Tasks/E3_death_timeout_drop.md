# E3 — Death / Timeout Drops Haul

**Summary:** On death or clock timeout (A3), the run ends **unsuccessfully** and the unbanked haul is dropped **minus a "pockets" fraction** — the player keeps a small portion, loses the rest (Tarkov-style sunk-cost carry penalty). This is the downside that gives "push deeper" its weight: every meter past the gate risks the haul.

- **Parent task:** E3 (M1 greybox prototype — the downside)
- **Dependencies:** E1 (gate/extract flow & run-end path), A3 (run clock / timeout, and whatever stands in for "death" in M1).
- **Acceptance criterion:** Dying or timing out ends the run, retains only the pockets fraction, discards the rest; an `EventBus` `run_end{cause: death|timeout}` event fires with the amount lost.

## Assets needed

E3 is almost entirely **logic** — it shares E1's run-end path but resolves the haul differently. Minimal new assets.

Data / resources / settings:
- `data/economy/run_rules.tres` — a small `Resource` (`RunRules`) holding `pockets_fraction: float = 0.20` and the policy for *how* pockets are selected (see Open Questions). Authoring this as a `.tres` keeps the most playtest-sensitive economy knob data-driven and out of code. (Exported var on `GameState` is an acceptable M1 fallback.)
- "Death" trigger source for M1: with no enemies yet, "death" needs a stand-in. Candidates: a debug/test key (`debug_kill`), a hazard tile, or *timeout-only* for the first pass. The clock-timeout path comes from A3 for free; an explicit death path should at least exist behind a debug action so the math is testable.

Autoload touchpoints:
- `GameState` — `fail_run(cause)` resolving the drop math; reuses E1's `_teardown_run_state()`.
- `EventBus` — the shared `run_end(cause, payload)` signal (declared in E1).
- `A3` (clock) — emits a timeout signal E3 listens to (e.g. `EventBus.clock_timed_out`).
- `SaveManager` — `save_meta()` after applying the kept fraction (the kept pockets are real meta gains and must persist).
- `Telemetry` — consumes `run_end` and logs `amount_lost` / cause for the economy feedback gate.

Greybox feedback (cheap):
- A failure flash / "RUN LOST — kept N" toast (a `Label` on the HUD or a tiny `ui/hud/run_failed_toast.tscn`). Shows the sting so the downside is *felt*, mirroring E2's payoff legibility.

## Code to generate

Scripts:
- Additions to `systems/game_state.gd`: `fail_run(cause: StringName)` + `_resolve_pockets()`.
- Wiring: `GameState._ready()` connects to A3's timeout signal; a debug `_input` hook (or A3) calls `fail_run(&"death")`.
- `data/economy/run_rules.gd` defining the `RunRules` resource (optional but recommended).

Design notes: E3 and E1 are the two outcomes of one event — "the run is ending." Both must (a) resolve the haul, (b) `save_meta()`, (c) emit `run_end`, (d) tear down run-state — so they share `_teardown_run_state()` from E1. The only difference is the haul resolution: E1 banks **all**; E3 banks **pockets_fraction**, discards the rest, and reports `amount_lost`. Crucially, the kept fraction still flows through the **same run-state → meta-state transfer** as E1 (it is a real, persistent gain), just on a subset of items/value.

The pockets math has a policy decision baked in (see Open Questions): keep a *value fraction* (round down the summed value) vs. keep a *count fraction* of actual items. The pseudocode below keeps whole items up to the value fraction (so the sell screen can still itemize what survived), which is the more "Tarkov pocket" feel — you save specific items, not an abstract percentage.

```gdscript
# data/economy/run_rules.gd
class_name RunRules
extends Resource

@export_range(0.0, 1.0, 0.01) var pockets_fraction: float = 0.20
# How pockets are chosen when keeping whole items:
@export_enum("highest_value", "lowest_value", "random") var pockets_policy: String = "highest_value"
```

```gdscript
# systems/game_state.gd (partial — death/timeout drop)

@export var run_rules: RunRules   # or load("res://data/economy/run_rules.tres")

func _ready() -> void:
    EventBus.clock_timed_out.connect(func(): fail_run(&"timeout"))

func fail_run(cause: StringName) -> void:
    var pre_value: int = run_haul_value()
    var kept: Array[JunkItem] = _resolve_pockets()
    var kept_value: int = _sum_values(kept)
    var lost_value: int = pre_value - kept_value

    # Same run-state -> meta-state transfer as E1, but only the kept subset.
    for item in kept:
        banked_junk.append(item)
    run_inventory.clear()          # everything else is discarded (lost)

    SaveManager.save_meta()        # kept pockets are persistent — atomic write + .bak

    EventBus.run_end.emit(cause, {            # cause is &"death" or &"timeout"
        "items_kept": kept.size(),
        "value_kept": kept_value,
        "value_lost": lost_value,             # <-- acceptance: amount lost reported
        "depth": run_depth,
    })

    _teardown_run_state()          # shared with E1

# Keep whole items up to pockets_fraction of total value.
func _resolve_pockets() -> Array[JunkItem]:
    if run_inventory.is_empty():
        return []
    var pre_value: int = run_haul_value()
    var budget: int = int(floor(pre_value * run_rules.pockets_fraction))

    var ordered: Array[JunkItem] = run_inventory.duplicate()
    match run_rules.pockets_policy:
        "highest_value":
            ordered.sort_custom(func(a, b): return a.base_sell_value > b.base_sell_value)
        "lowest_value":
            ordered.sort_custom(func(a, b): return a.base_sell_value < b.base_sell_value)
        "random":
            # Use seeded RNG for determinism / testability.
            ordered.shuffle()  # replace with RNG.shuffle(ordered) when RNG exposes it

    var kept: Array[JunkItem] = []
    var spent: int = 0
    for item in ordered:
        if spent + item.base_sell_value <= budget:
            kept.append(item)
            spent += item.base_sell_value
    # Edge: budget>0 but smallest item exceeds it -> kept may be empty.
    return kept
```

`run_haul_value()` and `_sum_values()` / `_teardown_run_state()` are shared with E1/E2 — do not duplicate.

## Open questions

- **Pockets fraction value.** `0.20` is a first guess. This is *the* economy tuning knob for whether "push deeper" feels worth it — too high and there's no downside, too low and players never push. Must be playtested against the M1 feedback gate and likely lives in `run_rules.tres` for fast iteration.
  - **Recommendation:** Ship `pockets_fraction = 0.20` as the starting value in `run_rules.tres`, exposed as the headline tuning knob. 20% keeps the sting sharp (you lose the clear majority of an unbanked haul, matching Tarkov's harsh "death loses your gear except the secure container" baseline) while leaving a small consolation so a death doesn't feel like total zero ([Tarkov item-loss-on-death](https://www.gamepressure.com/escape-from-tarkov/how-do-i-keep-my-items-after-death/zdcfd0)). Treat 0.15–0.25 as the likely playtest sweep range and tune purely from the M1 feedback gate.
- **What does "death" mean in M1 with no enemies?** Options: timeout-only for the first pass (simplest, A3 gives it free), a debug kill key for testing the math, or a single greybox hazard. Recommend timeout-only as the shipped failure plus a `debug_kill` action so E3's math and `cause: death` path are exercised in tests.
  - **Recommendation:** Ship **timeout as the only player-facing failure** in M1 (A3 gives it for free and it's the cleanest single source of clock pressure), plus a `debug_kill` input action that calls `fail_run(&"death")` so the `cause: death` branch and pockets math are exercised in tests and demos. Do not build a hazard tile for M1 — it adds level-design surface area without changing the core decision the gate measures. Both causes share the same drop resolution, so wiring `debug_kill` is near-zero cost.
- **Pockets as value-fraction vs. count-fraction vs. whole-items.** This doc keeps whole items up to a value budget (itemizable, "Tarkov pocket" feel). Alternatives: keep a flat % of summed value (simplest math, but no items to show), or keep N% of item *count*. Decide before F2, since the sell screen displays whatever survived.
  - **Recommendation:** Keep **whole items up to a value budget** (`floor(total_value * pockets_fraction)`), as the doc's pseudocode does. This preserves real item identities so F2 can itemize "what you barely saved" — the symmetric counterpart to the extract reward beat — and matches the Tarkov mental model of saving *specific things*, not an abstract percentage ([Tarkov secure container keeps specific items, not a %](https://escapefromtarkov.fandom.com/wiki/Secure_containers)). It's also forward-compatible with M3 per-item sell rules. Accept the edge case where the smallest item exceeds the budget and pockets comes back empty — that's a legible, fair outcome.
- **Pockets selection policy.** Highest-value (forgiving — you save your best find), lowest-value (harsh — you only keep scraps), or random (tense/unfair). Default `highest_value` is the kindest; the gate may want harsher to make the downside bite. Tunable in `run_rules`.
  - **Recommendation:** Default to `highest_value` for M1. The sting in this design comes overwhelmingly from the *fraction lost* (0.20), not the selection rule, and "you saved your single best find" is the most legible, least feel-bad framing for a greybox playtest — players can reason about what survived. Keep `lowest_value`/`random` as `run_rules` options to A/B later, but start kind so frustration doesn't get mistaken for "the loop isn't fun" at the kill/pivot gate.
- **Do kept pockets sell automatically?** On a *failed* run, do the kept items still go through F2's sell screen, or convert silently to Money with just a toast? Showing a (small) sell screen on death reinforces "this is what you barely saved"; silent + toast is faster. Confirm against F2.
  - **Recommendation:** Route failed runs through the **same F2 sell screen**, titled "RUN LOST — kept N," showing the small surviving haul tallying into Money. Closing the loop symmetrically (every run ends on the same reward beat, win or lose) reinforces "this is what you barely saved" and teaches the cost of pushing better than a transient toast. F2 already listens to `run_end`; just have it present on `death`/`timeout` too. See the matching recommendation in F2.
- **Save-on-fail timing & corruption safety.** Failing must `save_meta()` so kept pockets persist even if the player quits immediately after. Confirm the atomic write + `.bak` path is invoked identically to extract (no half-saved meta on a crash mid-fail).
  - **Recommendation:** `fail_run()` must call the **identical** `SaveManager.save_meta()` atomic path as `extract_and_end_run()` — temp file → fsync → rename, with the prior meta rotated to `.bak` — invoked synchronously before `run_end` fires. There must be exactly one save code path shared by both outcomes so there's no second, less-safe write to maintain. The fsync-before-rename ordering is what guarantees no half-saved meta even on OS crash/power loss ([Godot atomic write sync before rename](https://github.com/godotengine/godot/pull/98361)).
- **Multiple end-causes racing.** If the clock times out on the exact frame the player reaches the gate, which wins — extract or timeout? Need a single "run is ending" guard so `fail_run`/`extract_and_end_run` can't both fire (idempotency flag, e.g. `run_ended: bool`).
  - **Recommendation:** Add a single `run_ended: bool` guard on `GameState`; the first of `extract_and_end_run()`/`fail_run()` to run sets it and any subsequent call early-returns, making run-end idempotent. On a same-frame tie, let **extract win** — the player physically reached the gate and pressed interact, so honoring the successful outcome is the player-friendly, less-feel-bad resolution. Reset `run_ended` in `_teardown_run_state()` so the next run starts clean.
