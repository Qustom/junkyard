# J5 — Depth-counter HUD fix (expanded design spec)

**Milestone:** M1.3 — Legibility & Density · **Workstream:** Wave 1 — Foundation & correctness (`M1.3_Breakdown.md` §5)
**Task id:** J5 · **Design author:** ui-ux-designer · **Fresh-eyes resolver (Phase 3):** TBD (NOT this author) · **Builder:** ui-ux-designer · **Status:** DRAFT (Phase 2 — design only; Open Questions await Phase 3 / Director)
**dependsOn:** none — HUD-disjoint; the `depth_changed` signal it subscribes to is already declared **and** already emitted on `main` (`M1.3_Breakdown.md` §4). Wave 1, parallel with J1 / BUG6 / DLV1.
**Companions:** `M1.3_Breakdown.md` (§3 task J5, §5 Wave 1, §7 "Depth reconciliation" open risk) · `design/M1_2_Tasks/G4_findings_M1.2.md` (§3 "Depth counter — CONFIRMED BUGGY", §5 F4 — the premise) · `design/M1_2_Tasks/I3_r2_r3_cues.md` (the M1.2 HUD-doc quality bar + the E2 readability contract) · `ui/hud/decision_hud.gd` / `.tscn`, `ui/hud/hud_strings.csv`, `tests/test_decision_hud.gd` (the surfaces this task edits) · `systems/game_state.gd` / `systems/event_bus.gd` (the depth contract, read-only)

---

## 0. Guardrail header — READ FIRST

This task is a **pure HUD projection fix.** It is **DESIGN ONLY** at Phase 2; the build wave wires it. The hard rules:

- **No game-state change. No new EventBus signal.** The bug is entirely in *which already-existing value the HUD reads* and *which already-existing signal it subscribes to*. `GameState`, the two depth fields, and the `depth_changed` signal are all correct and untouched. J5 only re-points the HUD at the right one. (This is the same "HUD owns no source of truth" contract as E2/I3 — `decision_hud.gd` header.)
- **HUD-only, single-file-ish.** The edits live in `ui/hud/decision_hud.gd` (the `_refresh_depth()` repoint + a new subscription + stale-comment cleanup), `ui/hud/hud_strings.csv` (the `HUD_DEPTH` string, **iff** the wording changes), and `tests/test_decision_hud.gd` (the assertion that hard-codes the wrong field). No `.tscn` structure change — the `%DepthLabel` node already exists and stays where it is.
- **Off = the M1.0 baseline still holds.** This fix is **opposition-agnostic**: the depth readout is part of the band-independent **legibility layer** (player / loot / exits / threats / progress stay highest-contrast and correct regardless of which oppositions or band styling are on). It is shown in *every* run, including the all-off control. Changing *which depth* it shows does not touch determinism (fp=`e943ac9c8bc1`) — the readout is display-only and emits nothing.
- **Honor the E2 readability rules** (`decision_hud.gd` header): the depth readout is a label; its only "channel" is the number itself, so it must be **unambiguous in wording** and stay **highest-contrast** (it lives in the legibility layer, not behind band styling). Strings go through `tr()` against `ui/hud/hud_strings.csv`. No colour is load-bearing here.

---

## 1. Goal & premise research

> **One sentence:** the bottom-left depth readout shows the **band counter** (`GameState.current_depth`, pinned at 1 inside a band) instead of the **room depth** the run actually traverses and the config/design language all key off (`current_depth_index` / `max_depth_reached`), so the player's core progress signal lies — repoint it and subscribe to the `depth_changed` signal that already broadcasts the right value.

### 1.1 Why (the premise — Director feedback F4, confirmed in the data)

`design/M1_2_Tasks/G4_findings_M1.2.md` §3 ("Depth counter — **CONFIRMED BUGGY in the data**"):

> `band_depth_reached.depth` maxes at **1** for M1.2 runs while the same runs report `run_ended.max_depth` of **5 / 7 / 11 / 17**. Two different depth concepts are live: the `band_depth` the bottom-left HUD shows (stuck ~1) vs. the `depth_index` the run actually traverses (and that `run_config` thresholds key off). This is the exact data signature of the Director's "the bottom-left depth counter looks buggy" report. *Triage: sev-med (misleads the player on their core progress signal)... Recommend M1.3: point the HUD at `depth_index` (the value config + extraction logic use), or reconcile the two.*

And the ratified scope, §5 F4:

> **F4 — depth counter.** Fix the HUD to show the room `depth_index` (subscribe to `depth_changed`), not the band counter.

The bug is **already root-caused** — J5 is the implementation design, not a re-investigation. The legibility intent is the load-bearing point: **the player-facing "depth" must be the same "depth" the rest of the game's language uses.** Config knobs (`r1_depth_threshold`, `r3_rate_per_depth`, `r4_*` thresholds) and the gate metric (`max_depth_reached`, reported as `run_ended.depth_reached`) all speak in **room `depth_index`**. The HUD speaking in **band count** means the only number the player sees during a dive disagrees with every number the *design* reasons in — the textbook "core progress signal is wrong" defect.

### 1.2 The two depth concepts (confirmed against `systems/game_state.gd` on `main`)

| Field | Meaning | Mutated by | Range observed | What it's for |
|---|---|---|---|---|
| `current_depth` (`game_state.gd:42`) | **band counter** — how many bands deep you are | `enter_band()` (`:147` `current_depth += 1`); reset to 0 in `start_run` (`:92`), set 0 again on extract (`:210`) | **pinned at 1** inside a band (M1 is a single band; `enter_band` fires once → 1, never again) | the band-traversal counter; carried in some end-path prints, **not** the gate metric |
| `current_depth_index` (`game_state.gd:50`) | **room depth** — depth_index of the piece the player is in NOW (entry == 0) | `set_current_depth(idx, dist_home)` (`:225`), called by the `MainGame` scene driver when it resolves the player's piece | **0 … 17** in M1.2 telemetry | the live room depth; **what `run_config` thresholds key off** |
| `max_depth_reached` (`game_state.gd:51`) | **deepest room reached this run** — `maxi(max, current_depth_index)` | `set_current_depth()` (`:230`); reset to 0 in `start_run` | the running max of the above (0 … 17) | **THE gate metric** — reported as `run_ended(reason, dur, max_depth_reached)` (`:244`) |

The signal that already broadcasts the right values (confirmed `systems/event_bus.gd:81`):

```
signal depth_changed(depth_index: int, max_depth: int)
```

Pre-declared on `main` by the orchestrator (M1.1 BUG2 sequencing — `event_bus.gd:72-81`), **emitted only** by `GameState.set_current_depth()` (`game_state.gd:233`), and **edge-triggered**: it fires only when the player crosses into a piece of a *different* `depth_index` (`game_state.gd:227-229` — same-depth ticks no-op, no signal spam). So subscribing the HUD to it gives a clean, exactly-when-it-changes update with **both** numbers in the payload — no polling, no per-frame work.

### 1.3 The bug in `decision_hud.gd` (confirmed on `main`)

Two co-located defects:

1. **Reads the wrong field.** `_refresh_depth()` (`decision_hud.gd:150-151`):
   ```
   func _refresh_depth() -> void:
       _depth_label.text = tr("HUD_DEPTH").format({"depth": GameState.current_depth})
   ```
   `GameState.current_depth` is the band counter → renders "Depth 1" for the whole dive while the run descends to `depth_index` 17.

2. **Subscribes to the wrong edges + a stale comment.** The HUD never connects `depth_changed`. It refreshes depth on `run_inventory_changed` (`:122-123`), `band_entered` (`:134-135`), and run boundaries (`:138-141`) — none of which fire when the *room* depth changes. The header comment (`:12-13`) and an inline comment (`:120-121`) both assert:
   > Depth ← GameState.current_depth, refreshed on run_inventory_changed / band_entered **(no depth_changed signal exists in M1).**

   That parenthetical was true when E2 was authored; it is **stale** as of M1.1 BUG2 (the signal has existed on `main` since `event_bus.gd:81`). The HUD's depth refresh is currently *coincidental* — it only updates when the player happens to pick something up or cross a band edge, never tied to the value it displays. Even after the field repoint, leaving the inventory/band edges as the refresh trigger would mean the readout lags the actual room depth (e.g. descend three rooms picking nothing up → readout frozen). The subscription must move to `depth_changed`.

### 1.4 The `HUD_DEPTH` string (confirmed `ui/hud/hud_strings.csv:3`)

```
HUD_DEPTH,Depth {depth}
```

A single `{depth}` placeholder. If the readout shows **two** numbers (Q1 below), this string changes (e.g. `Depth {depth} / {max}`); if it shows one, the existing key is reusable as-is and only its *meaning* shifts (band → room). Either way the string stays in the CSV behind `tr()` (externalized for localization — playbook).

---

## 2. Pseudocode (against the real as-built APIs)

> Illustrative, not final. The build wave writes the real GDScript on a `ui-ux-designer/J5` branch. Recommended shape reflects the §3 recommendation (show **current room depth `/` deepest reached**, two numbers); the single-number fallback is noted inline so Phase 3 can flip Q1 cheaply.

### 2.1 `ui/hud/decision_hud.gd`

**(a) Subscribe to `depth_changed` in `_ready()`** (add one line; the existing depth-bearing subscriptions can stay or be trimmed — see (d)):

```gdscript
func _ready() -> void:
    EventBus.run_inventory_changed.connect(_on_run_inventory_changed)
    EventBus.dive_clock_changed.connect(_on_dive_clock_changed)
    EventBus.band_entered.connect(_on_band_entered)
    EventBus.depth_changed.connect(_on_depth_changed)   # J5: the signal that
    #   actually broadcasts room depth (depth_index, max_depth). Edge-triggered in
    #   GameState.set_current_depth — fires exactly when room depth changes.
    EventBus.run_started.connect(_on_run_boundary)
    EventBus.run_ended.connect(_on_run_boundary)
    ...
    _refresh_haul()
    _refresh_depth()   # initial paint: entry == depth 0 (or "—" pre-run, Q-edge)
```

**(b) Handle `depth_changed`** — the payload already carries both numbers, so the handler can paint directly (cheaper than re-reading GameState), but `_refresh_depth()` re-reading GameState keeps one code path. Recommended: thin handler delegating to `_refresh_depth()` so initial paint + signal paint share logic:

```gdscript
## J5: the room depth changed (player crossed into a piece of a new depth_index).
## Pure projection of the already-emitted depth_changed(depth_index, max_depth).
func _on_depth_changed(_depth_index: int, _max_depth: int) -> void:
    _refresh_depth()   # re-reads GameState.current_depth_index / .max_depth_reached
```

**(c) Repoint `_refresh_depth()`** to the room-depth fields:

```gdscript
## J5: project the ROOM depth (depth_index), not the band counter. depth_index is
## the value run_config thresholds + the gate metric (max_depth_reached) all use, so
## the player's progress readout now matches the game's own depth language. HUD-only:
## reads GameState, mutates nothing, emits nothing.
func _refresh_depth() -> void:
    # RECOMMENDED (Q1 = "current / deepest"): two redundant numbers — where you ARE
    # and how deep you've BEEN (the gate metric). max >= current always.
    _depth_label.text = tr("HUD_DEPTH").format({
        "depth": GameState.current_depth_index,
        "max": GameState.max_depth_reached,
    })
    # SINGLE-NUMBER FALLBACK (Q1 = "current only"): keep HUD_DEPTH = "Depth {depth}":
    #   _depth_label.text = tr("HUD_DEPTH").format({"depth": GameState.current_depth_index})
    # DEEPEST-ONLY FALLBACK (Q1 = "max only", matches the gate metric exactly):
    #   _depth_label.text = tr("HUD_DEPTH").format({"depth": GameState.max_depth_reached})
```

**(d) Trim / keep the now-coincidental refresh edges.** `depth_changed` is the correct and sufficient trigger for an *in-band* depth change. The other edges still matter for **boundary** correctness (the value must reset to 0 on `run_started` and re-paint on `run_ended`, because `set_current_depth(0,…)` early-returns when entry is already depth 0 → no `depth_changed` at run start). Recommendation:
- **Keep** `run_started` / `run_ended` (`_on_run_boundary`) refreshing depth — they cover the reset-to-0 / end-of-run paint that `depth_changed` won't emit.
- **Drop** depth from `_on_run_inventory_changed` (`:122-123`) — inventory has nothing to do with depth; it was only there as a stand-in for the missing signal. (Holding still refreshes there; only the `_refresh_depth()` call is removed.)
- **Keep or drop** `_on_band_entered` calling `_refresh_depth()` (`:134-135`): harmless to keep (band entry resets the band counter, not room depth, and `depth_changed` carries room depth). Recommend **dropping** the depth refresh there too for clarity — `_on_band_entered` no longer needs to touch depth once the readout is room-based. (Leave `band_entered` subscribed if anything else needs it; in M1 nothing else does, so the handler may become a no-op or be removed — builder's call, but the *depth* coupling goes.)

**(e) Fix the stale comments** (`:12-13` header + `:120-121` inline). Replace the "(no depth_changed signal exists in M1)" line with the truth:

```
##   - Depth          ← GameState.current_depth_index / .max_depth_reached, refreshed
##                       on EventBus.depth_changed (the BUG2/M1.1 signal, edge-triggered
##                       in GameState.set_current_depth), plus run boundaries for the
##                       reset-to-0 paint depth_changed doesn't emit. (J5, M1.3 — was
##                       wrongly reading the band counter current_depth on inventory/band edges.)
```

### 2.2 `ui/hud/hud_strings.csv`

**Only if Q1 resolves to two numbers** (the recommendation). Change the one row:

```
# before:
HUD_DEPTH,Depth {depth}
# after (recommended — current room / deepest reached):
HUD_DEPTH,Depth {depth} / {max}
```

If Q1 resolves to a single number, **leave the CSV untouched** (`Depth {depth}` already fits; only its meaning shifts to room depth). A wording-only tweak (e.g. "Depth {depth}m", "Floor {depth}") is a Q3 Director call — default is the minimal change.

### 2.3 `tests/test_decision_hud.gd`

The current assertion hard-codes the **wrong** field (`tests/test_decision_hud.gd:97-101`):

```gdscript
# --- Depth projection ---------------------------------------------------------
gs.enter_band(&"near")  # current_depth → 1, emits band_entered
await process_frame
if depth_label.text != tr("HUD_DEPTH").format({"depth": gs.current_depth}):
    failures.append("Depth '%s' != current_depth %d" % [depth_label.text, gs.current_depth])
```

This must be rewritten to drive the **room-depth** path — i.e. call `set_current_depth()` (which emits `depth_changed`) and assert the readout tracks `current_depth_index` / `max_depth_reached`. Recommended replacement (matches the two-number recommendation; collapse to one number if Q1 flips):

```gdscript
# --- Depth projection (J5): HUD tracks ROOM depth via depth_changed ------------
gs.start_run(&"near", 4242)        # entry → depth_index 0 / max 0
await process_frame
# descend: set_current_depth emits depth_changed(idx, max); HUD must follow.
gs.set_current_depth(1, 1)         # room depth 1
await process_frame
gs.set_current_depth(3, 3)         # jump to room depth 3 (max climbs to 3)
await process_frame
var want_depth := tr("HUD_DEPTH").format({
    "depth": gs.current_depth_index,   # 3
    "max": gs.max_depth_reached,        # 3
})
if depth_label.text != want_depth:
    failures.append("Depth '%s' != depth_index/%d max/%d (J5: must track room depth, not band counter)"
        % [depth_label.text, gs.current_depth_index, gs.max_depth_reached])
# regression guard: the BAND counter must NOT be what's shown.
gs.enter_band(&"near")             # current_depth → 1 (band), but room depth unchanged
await process_frame
if depth_label.text != want_depth:  # band entry must not change the room readout
    failures.append("Depth readout moved on band entry — J5 regression (still reading current_depth?)")
```

Also update the test's docstring (`tests/test_decision_hud.gd:9`) — it currently states the intended behaviour as "DepthLabel tracks GameState.current_depth (refreshed on the same edges)"; that line must become "DepthLabel tracks GameState.current_depth_index / max_depth_reached via depth_changed (J5)". And the closing success print (`:140-142`) which says "depth tracks current_depth".

> **Test ordering note:** the existing test seeds the run *after* the depth section in places — the builder should sequence so a `start_run` precedes the depth assertions (the snippet above does). Keep the existing cleanup `gs.end_run(&"abandon", 0.0)` at the tail.

---

## 3. Recommended readout format (the design recommendation J5 carries into Phase 3)

**Recommendation: show two numbers — current room depth `/` deepest reached this run** → `Depth {depth} / {max}` (e.g. "Depth 3 / 7").

Rationale:
- **Current room depth** (`current_depth_index`) is the live "where am I right now" the player navigates by, and it's the value every `run_config` threshold speaks in — so the readout now matches the game's own depth language (the core F4 intent).
- **Deepest reached** (`max_depth_reached`) is **the gate metric** (`run_ended.depth_reached`) — surfacing it tells the player "this run's score so far," which is exactly the push-vs-extract progress signal the DecisionHUD exists to make legible (it pairs naturally with "Holding: N" — *how much* and *how deep*).
- It is a **redundant two-channel** readout in the spirit of the E2 readability rules: even if the current number dips (if a future band ever lets you ascend), the max anchors "you've been here." In M1 the spine is linear so current climbs monotonically and `current == max` almost always — but showing both costs nothing and is correct the moment descent stops being monotonic (R4 branching already exists).

This is a **small UX call**, so it is **flagged for the Director** (Q1 below) with this recommendation; if the Director prefers minimal, the single-number `current_depth_index` is the cheap fallback (no CSV change).

---

## 4. Open Questions

> Phase 3 (fresh eyes, not this author) resolves what it can on design/technical merit; anything that is a genuine **legibility / UX call** is flagged "needs Director review" with a recommendation (per the orchestrator loop). The format is the one real UX call here.

- **Q1 — Readout format: one number or two?** Show **(a)** `current_depth_index` only, **(b)** `current_depth_index / max_depth_reached` (two numbers), or **(c)** `max_depth_reached` only (matches the gate metric exactly)?
  - *Trade-offs:* (a) is the minimal change (no CSV edit), reads as "where you are now," but hides the run's headline progress. (b) surfaces both the live position and the gate metric in one readout, pairs with "Holding: N," costs one CSV-string edit; the two numbers are equal on a monotonic descent so it can look redundant in M1 (but is correct once descent isn't monotonic — R4 already branches). (c) is the truest "score" number and matches `run_ended` exactly, but a number that only ever climbs and never reflects backtracking can feel less like a live position cue.
  - **Recommendation: (b)** — *flagged for Director* as a UX call. Cheap to flip to (a)/(c) if the Director wants minimal (single-number paths are in the pseudocode).

- **Q2 — Show the deepest-reached (gate metric) or the current room?** Sub-question of Q1, isolated because it's the substantive one: the player's "progress" the gate measures **is** `max_depth_reached`, but the *navigational* signal they act on is the current room. (b) above shows both and sidesteps the choice; if Q1 = single-number, this question forces the pick. *Resolvable by Phase 3 on merit if Q1 collapses to one number — recommend currentdepth for navigation if forced to one, since the end screen already reports max.*

- **Q3 — Wording.** Keep "Depth {depth}" / "Depth {depth} / {max}", or change the noun? Options: "Depth", "Floor", "Level", a unit suffix ("Depth 3m"). *Recommendation: keep "Depth"* — it's the GDD/TDD/config word ("depth_index", "depth threshold"), so it keeps the player's vocabulary aligned with the design's. **Flag to Director only if they want a thematic word**; otherwise Phase 3 can close this as "keep Depth."

- **Q4 — Keep the band counter (`current_depth`) shown anywhere?** M1 is a single band, so the band counter is always 1 and carries no player-facing information *this milestone*. Options: **(a)** drop it from the HUD entirely (recommended — it's the source of the bug and shows nothing useful in M1), **(b)** keep it for a future multi-band readout ("Band 1 · Depth 3"). *Recommendation: (a) — drop it from the readout.* `GameState.current_depth` the *field* stays (it's still used in end-path prints and is the future multi-band counter); only the HUD stops *displaying* it. When M2+ introduces real multi-band traversal, a "Band N" readout is a new task, not a J5 concern. *Resolvable by Phase 3 on merit.*

- **Q5 — Pre-run / post-run paint (edge correctness).** Before any run, and on the end screen, what does the readout show? Options: blank, "Depth 0", "Depth —", or hide the label. The pseudocode's `_on_run_boundary` repaints on `run_started` (→ 0) and `run_ended`. *Recommendation: show "Depth 0" at run start (entry is genuinely depth 0) and leave the last value on the end screen until the next `start_run` resets it; hide-on-no-run is a polish call the human visual pass can make.* *Resolvable by Phase 3 on merit; no Director call.*

---

## 5. Definition of done (for the build wave that follows)

- `ui/hud/decision_hud.gd`: `_refresh_depth()` reads `GameState.current_depth_index` (+ `max_depth_reached` per Q1); HUD subscribes to `EventBus.depth_changed`; depth no longer refreshed off `run_inventory_changed`; stale "(no depth_changed signal exists in M1)" comments corrected (header + inline). No new signal, no game-state mutation, no `.tscn` change.
- `ui/hud/hud_strings.csv`: `HUD_DEPTH` updated **iff** Q1 = two numbers; otherwise untouched. String stays behind `tr()`.
- `tests/test_decision_hud.gd`: depth assertion rewritten to drive `set_current_depth()` / `depth_changed` and assert the readout tracks room depth (with a band-entry regression guard); docstring + success print updated.
- Smoke test green; `godot --headless --script res://tests/test_decision_hud.gd` passes; the all-off control run is byte-identical behaviourally (the readout is display-only, emits nothing — determinism fp untouched).
- One worklog per the work-product contract, naming the commit SHA, with a Design deviations section (record any Q resolved differently from the recommendation here).

---

## Resolved Decisions (Phase 3 — fresh-eyes, 2026-06-19)

Fresh-eyes reviewer (NOT the Phase-2 author). Every cited file/API was re-read against `main`. **The doc is technically accurate and build-ready.** Corrections are minor (line-number drift only); the design holds.

### Verification — corrections to the doc's citations

All claims confirmed against source; a few cited line numbers drifted (the *facts* are correct, only the `:NN` anchors moved). Builder should grep by symbol, not line number.

| Doc citation | Reality on `main` | Verdict |
|---|---|---|
| `_refresh_depth()` "(`decision_hud.gd:150-151`)" reads `GameState.current_depth` | **Confirmed** — `decision_hud.gd:150-151`, exactly as quoted: `_depth_label.text = tr("HUD_DEPTH").format({"depth": GameState.current_depth})` | ✅ exact |
| Stale header comment "(no depth_changed signal exists in M1)" at `:12-13` | **Confirmed** at `:12-13` (`## - Depth ← GameState.current_depth, refreshed on run_inventory_changed / band_entered (no depth_changed signal exists in M1).`) | ✅ exact |
| Inline stale comment at `:120-121` | **Confirmed** — `:120-121` inside `_on_run_inventory_changed`, "…stays in sync without a dedicated depth_changed signal." Both stale comments exist as described. | ✅ exact |
| Depth subscriptions: `run_inventory_changed` `:122-123`, `band_entered` `:134-135`, run boundaries `:138-141` | **Confirmed** — `_on_run_inventory_changed` calls `_refresh_depth()` at `:123`; `_on_band_entered` at `:135`; `_on_run_boundary` at `:141`. `depth_changed` is **not** connected (verified `_ready()` `:88-102` — only `run_inventory_changed`, `dive_clock_changed`, `band_entered`, `run_started`, `run_ended`, `return_cost_incurred`, `exposure_penalty`). | ✅ exact |
| `current_depth` (`game_state.gd:42`), band counter, `enter_band` `current_depth += 1`, reset in `start_run`, set 0 on extract | **Confirmed** — field `:42`; `enter_band()` at `:145-148`, `current_depth += 1` at `:147`; `start_run` resets `:92`; extract sets `current_depth = 0` at `:210`. | ✅ exact |
| `current_depth_index` (`:50`), `max_depth_reached` (`:51`), `set_current_depth(idx, dist_home)` (`:225`), `maxi` (`:230`), emits `depth_changed` (`:233`), edge-trigger early-return (`:227-228`) | **Confirmed** — fields `:50`/`:51`; `set_current_depth` `:225-233`; `current_dist_to_gate = dist_home` always (`:226`); `if idx == current_depth_index: return` (`:227-228`); `max_depth_reached = maxi(...)` (`:230`); `EventBus.depth_changed.emit(current_depth_index, max_depth_reached)` (`:233`). | ✅ exact |
| `event_bus.gd` `signal depth_changed(depth_index: int, max_depth: int)` "(`:81`)" | **Confirmed** — `event_bus.gd:81`, signature exact. Pre-declared by orchestrator, emitted only by `set_current_depth`. | ✅ exact |
| `hud_strings.csv:3` `HUD_DEPTH,Depth {depth}` | **Confirmed** — `:3`, single `{depth}` placeholder. | ✅ exact |
| Test assertion `:97-101` hard-codes `gs.current_depth` after `enter_band` | **Confirmed** — `:98` `gs.enter_band(&"near")`, `:100-101` asserts `depth_label.text == tr("HUD_DEPTH").format({"depth": gs.current_depth})`. Docstring `:9` says "DepthLabel tracks GameState.current_depth"; success print `:140-142` says "depth tracks current_depth". All three need updating, exactly as the doc states. | ✅ exact |

**Two small build notes (not corrections — just sharpen the pseudocode):**

1. **The test fetches `depth_label` via `hud.get_node("Root/DepthLabel")` (`:50`), not `%DepthLabel`.** The §2.3 rewrite uses the existing `depth_label` variable, so this is fine — just don't introduce a `%`-unique-name lookup in the test.
2. **`max_depth_reached` and `current_depth_index` are equal at run start (both 0) and `set_current_depth(0, …)` early-returns** (same-depth no-op), so **no `depth_changed` fires at entry**. The initial `_refresh_depth()` in `_ready()` plus the `run_started` boundary paint are what produce the "Depth 0 / 0" at entry — this is exactly why §2.1(d)'s "keep `run_started`/`run_ended`" recommendation is *required*, not optional. Confirmed correct.

### Scope confirmation (the guardrail header holds)

**HUD-only, confirmed.** The fix touches only: `decision_hud.gd` (repoint + subscribe + comment cleanup), `hud_strings.csv` (one row, iff two-number format), `tests/test_decision_hud.gd` (assertion + docstring + print). **No game-state change, no new EventBus signal, no `.tscn` change.** `depth_changed` already exists and is already emitted on `main` — J5 only *subscribes*. The readout is display-only and emits nothing → **determinism untouched** (fp `e943ac9c8bc1` unaffected). The all-off control is behaviourally byte-identical. `dependsOn: none` is correct — the signal it needs is already live.

### Open Questions — resolutions

- **Q1 — Readout format (one number vs two vs deepest-only): RESOLVED-ON-MERIT for the *technical* contract; the *which-format* pick is a small Director UX call (flagged).**
  - *Technical resolution:* all three forms (a/b/c) are equally correct and cheap. The pseudocode already provides all three paths and the test snippet flips trivially. The two-number form is the only one that needs a CSV edit (`Depth {depth} / {max}`); single-number forms reuse the existing key. There is **no technical reason to prefer one** — they are all pure projections of already-live fields. So the engineering is settled; only the UX preference remains.
  - *Recommendation to Director:* **(b) `Depth {depth} / {max}`** (the author's recommendation, and I concur). Rationale that survives fresh-eyes scrutiny: the second number is the **gate metric** (`max_depth_reached` == `run_ended.depth_reached`), so the player sees their actual run "score" live, and it pairs with "Holding: N" as the two-axis push-vs-extract signal the DecisionHUD exists for. The "redundant in M1 because descent is monotonic" objection is real but harmless — both numbers are correct, and R4 branching (already in-build) makes them diverge. **One caveat I'd raise:** if the Director leans minimal, **(a) `current_depth_index` only** is genuinely cleaner *for M1.3 specifically* (the divergence (b) hedges against isn't reachable in the all-off control and most M1.3 configs), and avoids a player wondering "why two numbers that are always equal?" So: **(b) recommended, (a) is the strong minimal fallback.** **→ needs Director review (UX call).**

- **Q2 — Deepest-reached vs current room (the substantive sub-question of Q1): RESOLVED-ON-MERIT, contingent.** If Q1 = (b) two numbers, this is moot (both shown). If the Director collapses to one number, the merit answer is **current room (`current_depth_index`)** — it is the live navigational cue the player acts on, and the end-of-run screen already reports `max` (`run_ended.depth_reached`), so the HUD doesn't need to duplicate the score mid-run. Concur with the author. No separate Director call beyond Q1.

- **Q3 — Wording noun ("Depth" vs "Floor"/"Level"/unit-suffix): RESOLVED-ON-MERIT to "Depth"; a thematic re-word is a small Director call (flagged, low priority).**
  - *Resolution:* **Keep "Depth."** It is the word the entire design language uses — `depth_index`, `max_depth_reached`, `r1_depth_threshold`, `r3_rate_per_depth`, `run_ended.depth_reached`. Aligning the only in-dive number the player sees with the design's own vocabulary is the whole point of F4. Changing the noun would *re-introduce* a vocabulary split (a different one). So Phase 3 closes this as **"keep Depth"** on merit.
  - *Director flag (optional, low priority):* if the Director wants a more thematic/diegetic word ("the player doesn't read the GDD"), that's a pure tone call — but it is **not blocking** and the recommendation is to keep "Depth." **→ Director review only if a thematic word is desired; otherwise closed.**

- **Q4 — Keep the band counter shown anywhere: RESOLVED-ON-MERIT — drop it from the HUD (option (a)).** In M1 the band counter is pinned at 1 and carries zero player-facing information; it is the *source* of the bug. The `GameState.current_depth` **field stays** (still used in end-path prints `:349`/`:206` and is the future multi-band counter) — only the HUD stops *displaying* it. A "Band N · Depth M" readout is an M2+ multi-band task, not J5. Concur with the author. No Director call.

- **Q5 — Pre/post-run paint: RESOLVED-ON-MERIT.** Show **"Depth 0" (or "Depth 0 / 0") at run start** — entry is genuinely depth 0, and the `run_started` boundary paint covers it since `depth_changed` won't fire at entry (verified: `set_current_depth(0,…)` early-returns). **Leave the last value on the end screen** until the next `start_run` resets it. Hide-on-no-run is a polish call deferred to the human visual pass. Concur with the author. No Director call. *(Edge note: before the very first run, `current_depth_index`/`max_depth_reached` default to 0, so the `_ready()` initial paint shows "Depth 0 / 0" — acceptable; the human visual pass may choose to hide the label pre-run.)*

### Summary for the Director

Two small UX calls need a verdict; everything else is resolved on merit:

1. **Q1 — readout format.** Recommendation: **(b) `Depth {depth} / {max}`** (live room depth / deepest reached = the gate metric). Strong minimal fallback: **(a) current depth only** (no CSV change, avoids "two equal numbers" in M1). Both are pure projections; flip is one CSV row + one test line.
2. **Q3 — wording noun.** Recommendation: **keep "Depth"** (matches the design's vocabulary, which is F4's whole intent). Only a flag if the Director wants a thematic word; not blocking.

Q2/Q4/Q5 resolved on merit (current-room if forced to one number; drop the band counter from the HUD but keep the field; "Depth 0" at run start, last-value-on-end-screen). Scope confirmed HUD-only, no new signal, determinism untouched, test-assertion fix correctly identified. **Design LOCKED pending the two Director UX verdicts above.**

## Director Disposition (2026-06-19, FINAL — design locked)

- **Readout format: `Depth {depth} / {max}`** (live room `depth_index` / deepest-reached gate metric) — Director-accepted. **Wording: keep "Depth"** (matches the GDD/config vocabulary).
- HUD-only: repoint `_refresh_depth()` to `current_depth_index`, subscribe to `EventBus.depth_changed`, fix the stale comment, paint "Depth 0 / 0" on the `run_started` boundary (required — `set_current_depth(0,…)` early-returns at entry), update `hud_strings.csv` (`HUD_DEPTH`) + the `tests/test_decision_hud.gd` assertion (3 spots). No game-state change, no new signal, determinism untouched. Drop the band counter from the HUD (keep the `current_depth` field for end-path prints).

**Design LOCKED.**
