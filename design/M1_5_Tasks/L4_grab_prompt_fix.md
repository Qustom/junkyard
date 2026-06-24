# L4 — Grab-prompt visibility fix (#9) · Per-task design (Phase 2)

**Milestone:** M1.5 (Agency & Legibility) · Wave 1 (foundation + legibility fixes)
**Role:** general-purpose (programmer) · **Knob-gated?** NO — correctness bug-fix, behaviour changes for everyone (like Wave-5 BUG7/BUG8).
**BlockedBy:** none (interaction-logic-only; file-disjoint from L0's three shared files and L3's `decision_hud.*`).
**Spec source:** `design/M1_5_Tasks/M1.5_Breakdown.md` (L4 row, §3) · Director feedback #9 (`design/M1_4_Tasks/G4_findings_M1.4.md:103`).

**The bug (Director #9):** *"Grab prompt always shows"* — the floating `[E] Grab` interaction prompt is visible on screen even
when there is no valid grabbable interactable focused / in range. **Desired invariant:** the prompt is visible **iff** there
is a focused interactable that `can_interact()`.

---

## (a) Research on the premise + ROOT-CAUSE diagnosis

### The interaction stack as built (A2, `worklogs/2026-06-15-A2-general-purpose.md`)

Three files compose the interaction layer; I read all three plus both consumers (junk + gate) and the player scene.

- **`components/interaction/interaction_detector.gd`** — `InteractionDetector extends Area2D`, a child of `Player`
  (`entities/player/player.tscn:32`). Radius **36px** (`interaction_detector.tscn:7`), `collision_layer = 0`,
  `collision_mask = 4` (sees only the `interactable` layer, bit 3). It tracks the in-range set and owns the prompt:
  - `_in_range: Array[Interactable]` — appended in `_on_area_entered` (`:47-50`), erased in `_on_area_exited` (`:53-56`).
  - `_current: Interactable` — the focused target, or `null` (`:36`).
  - `_prompt: Node` — **lazily instanced on first focus** and reused (`:39`, `:119-124`).
  - `_process()` calls `_refresh_current()` **every frame** (`:59-60`).
  - `_refresh_current()` (`:73-116`) recomputes the nearest valid target with hysteresis (`SWITCH_RATIO = 0.9`), and on a
    focus *change* emits focus/unfocus and calls `_show_prompt()` / `_hide_prompt()`.
  - `_show_prompt(it)` (`:119-127`): instances the prompt if needed, `set_target(it)`, `_prompt.visible = true`.
  - `_hide_prompt()` (`:130-133`): `set_target(null)`, `_prompt.visible = false`.

- **`components/interaction/interactable.gd`** — `Interactable extends Area2D`, a child of each grabbable entity. Pure data +
  the `can_interact()` guard (`:36-37`) which returns `enabled` (default `true`, `:30`). It sits on the `interactable`
  layer (`collision_layer = 4`) with an empty mask — it is *detected*, it detects nothing.

- **`ui/interaction_prompt.gd`** + **`ui/interaction_prompt.tscn`** — `InteractionPrompt extends Node2D`, a world-space
  Node2D + `Label`. `set_target(it)` stores the target and re-renders; `_render()` (`:44-50`) sets the label to
  `"[E] Grab"` when a target is set, or `""` when the target is null; `_process()` (`:39-41`) snaps `global_position` to
  the target each frame **only while `_target != null`**.

- **Consumers register identically.** `junk_pickup.tscn:19-25` and `extract_gate.tscn:31-37` each drop an `Interactable`
  child on `collision_layer = 4`, `enabled` implicitly `true`, `prompt_text = "Grab"` / `"Extract"`. The detector sees
  them via `area_entered` / `area_exited`. The gate is placed **160px from spawn** (`GameState.GATE_SPAWN_OFFSET =
  Vector2(160, 0)`, `game_state.gd:30`), well outside the 36px detector radius, so the gate is **not** in range at spawn.

### What is NOT the cause (ruled out by reading)

- **There is no second, always-on prompt.** The prompt scene is referenced in exactly one place
  (`interaction_detector.tscn:13`, `prompt_scene` export) and instanced in exactly one place (`interaction_detector.gd:121`).
  `main_game.gd`'s only "prompt" is the unrelated telemetry-consent dialog (`:1108-1119`). So the bug is in the detector's
  own show/hide flow, not a stray HUD node.
- **`.tscn` default-visible is NOT the spawn-time cause.** The prompt is *lazily* instanced **on first focus**
  (`:120-121`) — there is no prompt node in the tree until the player first focuses something, so a fresh run cannot show a
  prompt before any focus. (The scene *does* ship without `visible = false` and with `text = "[E] Grab"` baked
  (`interaction_prompt.tscn:16`) — that is a latent hazard, addressed defensively below, but it is not the first-focus
  trigger.)
- **The normal exit path is logically correct.** When the focused target leaves the 36px radius: `area_exited` erases it
  from `_in_range` (`:56`); next `_refresh_current()` finds `best = null`; the hysteresis re-pin block is **skipped** because
  its guard requires `_in_range.has(_current)` (`:99`) which is now false; `best (null) != _current`, so the early-out
  (`:105`) is not taken; `_hide_prompt()` runs (`:116`). So the *steady-state* logic does hide on a clean range-exit.

### The root cause (ranked, with evidence)

The reported symptom — prompt **persists when nothing valid is focused** — is most defensibly explained by the
**visibility-leak class of bug**: `_prompt.visible` is only ever *changed on a focus transition* (`_refresh_current`'s
"focus changed" branch, `:108-116`), never *asserted as an invariant from `_current`*. The prompt is a reused, persistent
node parented to the moving detector. So any path that leaves `_prompt.visible == true` while `_current` is effectively not a
valid focus leaves the prompt stuck on. Concretely, the load-bearing gaps:

1. **PRIMARY — focus is "lost" without a transition, so `_hide_prompt()` is never called.** `_hide_prompt()` runs **only**
   on the `best != _current` transition at `:105-116`. But `_current` can become a *non-valid focus while staying `==
   _current`*, which trips the `if best == _current: return` early-out (`:105-106`) and skips the hide entirely. The two
   real ways this happens:
   - **Freed-but-not-yet-exited focused target.** When junk is grabbed-and-accepted, `JunkPickup.queue_free()`
     (`junk_pickup.gd:_try_pickup` → `queue_free()`) is **deferred**; `area_exited` fires a frame *later*. In the
     interim frame, the in-range loop drops the now-invalid entry (`:84-86`), so `best` is computed *without* it — but the
     **hysteresis block can re-pin the dying `_current`**: its guard checks `is_instance_valid(_current)` (`:98`) which is
     still true mid-free, and `_in_range.has(_current)` — and `_in_range` was just mutated, ordering-dependent. If
     `_current` survives the guard, `best := _current` (`:103`), `best == _current` → early-out → **prompt stays visible
     pointing at a node that is about to vanish.** The prompt then *freezes in world space* (its `_process` snaps to the
     last `global_position`) and reads as a stuck, "always-on" prompt floating where the junk was.
   - **Focused target disabled in place.** An owner can set `enabled = false` (the documented use, `interactable.gd:28-29`)
     without freeing or moving the node. The in-range loop now skips it (`can_interact()` false, `:87-89`), so `best`
     excludes it — but again the hysteresis block's guard at `:98` *also* re-checks `_current.can_interact()`, so a disabled
     `_current` *should* fall through to the unfocus branch. This path is correct **today**, but it is the same fragile
     "visibility driven by transitions, not by invariant" shape and breaks the moment the guard order changes.

2. **SECONDARY — the prompt ships visible-by-default with baked text.** `interaction_prompt.tscn` has **no `visible =
   false`** and `text = "[E] Grab"` hardcoded (`:16`). The moment the prompt is instanced (first focus) it is already
   `visible = true` before `_show_prompt` even sets it — harmless on the show path, but it means the node's *resting state
   is "on"*. Any future code path that instances the prompt without an immediate, guaranteed `_hide` (or that loses the
   `_current` reference, see #1) leaves a visible `[E] Grab` on screen. This is the latent reason the symptom presents as
   "always shows" rather than "flickers."

3. **TERTIARY (worth a glance, not the likely cause) — `_in_range` accumulation on rapid spawn/free.** At cell size **16px**
   (`main_game.gd:47`) the 36px radius spans ~2.25 cells, so several pickups are routinely in range at once. If any
   `area_exited` is missed for a freed node (the deferred-free window), `_in_range` can briefly hold a stale entry; the
   defensive `is_instance_valid` sweep (`:84-86`) cleans it the next frame, so this is self-healing — but it widens the
   window for #1.

**Why the unit test passed yet the bug ships:** `tests/test_interaction.gd` (per the A2 worklog) asserts the *shown* case
(prompt instanced + visible on focus) and the *focus-switch* case, but **never asserts `_prompt.visible == false` after the
focused target is freed/range-exits**, and never exercises the deferred-`queue_free` → next-frame ordering that #1 hinges on.
The hide invariant is simply untested.

**Conclusion / the real fix (not a band-aid):** stop driving `_prompt.visible` off focus *transitions* and instead make it a
**hard invariant of `_current`** asserted every refresh: `visible == (_current != null && is_instance_valid(_current) &&
_current.can_interact())`, with the prompt defaulting **hidden**. That closes #1 (the early-out can no longer strand a
visible prompt), neutralises #2 (resting state becomes "off"), and is robust to #3.

---

## (b) Pseudocode — proposed fix against the real flow

The fix is small and surgical, in `interaction_detector.gd` + a one-line `.tscn` default flip. **No new knob, no signal
change, no save touch** (correctness fix, per the breakdown).

### 1. Drive visibility from the `_current` invariant, every frame

Replace the transition-only show/hide with: keep emitting focus/unfocus **on transition** (audio/telemetry consumers rely on
the edge), but **assert prompt visibility from `_current` unconditionally at the end of every refresh.**

```gdscript
func _refresh_current() -> void:
    # ... (unchanged: in-range valid-sweep + nearest-with-hysteresis selection) ...

    if best != _current:
        # Focus CHANGED -> emit the edge signals (unchanged contract).
        if _current != null and is_instance_valid(_current):
            EventBus.interactable_unfocused.emit(_current)
        _current = best
        if _current != null:
            EventBus.interactable_focused.emit(_current)

    # INVARIANT (runs EVERY frame, transition or not): the prompt is visible
    # iff there is a valid, interactable focus. This is the load-bearing change —
    # the prompt can never be stranded "on" by an early-out or a deferred free.
    _update_prompt(_current)


## Single owner of prompt state. Visible IFF a valid focus exists.
func _update_prompt(it: Interactable) -> void:
    var valid: bool = it != null and is_instance_valid(it) and it.can_interact()
    if not valid:
        if _prompt != null:
            _prompt.set_target(null)
            _prompt.visible = false
        return
    if _prompt == null and prompt_scene != null:
        _prompt = prompt_scene.instantiate()
        add_child(_prompt)           # world-space child of the detector (unchanged)
    if _prompt != null:
        _prompt.set_target(it)
        _prompt.visible = true
```

Notes on why this is correct and not a band-aid:
- `_update_prompt(_current)` runs **every frame**, so the moment `_current` is null *or* points at a freed/disabled node,
  the prompt is hidden — no reliance on a `best != _current` transition firing. This directly kills root-cause #1: even if
  the hysteresis block re-pins a dying `_current` and the `best == _current` early-out is taken, the next frame's
  `_update_prompt` sees `is_instance_valid` go false (or `area_exited` clears it) and hides.
- `is_instance_valid` is re-checked **inside** `_update_prompt` (belt-and-suspenders against the deferred-free window).
- The `_show_prompt` / `_hide_prompt` pair is **removed** and folded into `_update_prompt` (one writer of `_prompt.visible`)
  — no second source of truth.
- The unfocus emit is guarded with `is_instance_valid(_current)` so a freed `_current` doesn't pass a dangling ref to
  consumers (a small hardening, not a behaviour change).

### 2. Default the prompt scene hidden (neutralise root-cause #2)

In `ui/interaction_prompt.tscn`, set the root node `visible = false` and drop the baked placeholder text (let `_render()`
own it — it already sets `""` for a null target):

```
[node name="InteractionPrompt" type="Node2D"]
script = ExtResource("1")
visible = false              # resting state is OFF; _update_prompt turns it on only on valid focus
# (Label) text = ""          # was "[E] Grab"; _render() drives this from the target
```

Belt-and-suspenders in `interaction_prompt.gd::_ready()` (covers the node even if the scene default is ever lost):

```gdscript
func _ready() -> void:
    _key_hint = _derive_key_hint()
    if _target == null:
        visible = false       # never resting-visible without a target
    _render()
```

### 3. (Optional, behaviour-preserving) hide while a rejected pickup flashes — see Open Questions

If the Director wants the prompt suppressed during the reject-flash, gate it through `can_interact()` rather than a new
visibility hook: a flashing/full pickup could return `false` from an overridden `can_interact()` for the flash duration, and
the existing invariant hides the prompt for free. **Recommend NOT doing this for RG1** (the junk is still grabbable once a
slot frees; hiding the prompt mid-flash would mislead). Flagged below.

---

## (c) Open Questions

1. **Should the prompt hide during a rejected-pickup flash?** When the bag is full, `junk_pickup.gd::_flash_rejected()`
   pulses the junk red but it **stays grabbable** (`can_interact()` still true). Today the prompt stays up — which is
   arguably correct (you *can* still try; it'll reject again). **Recommendation: leave the prompt up during the flash for
   RG1** (don't special-case it). If the Director wants it suppressed, do it via an overridden `can_interact()` returning
   false for the flash window (the invariant then hides it automatically — no new code path). **Needs Director review (tone
   /feel call).**

2. **Multiple overlapping interactables (junk-on-junk, junk-near-gate).** The detector already focuses exactly one
   (nearest + hysteresis) and the invariant binds visibility to that single `_current`, so the prompt shows for *one* thing
   at a time — correct and unchanged. **No open issue**, but the fix must preserve the hysteresis selection verbatim (only
   the visibility *assertion* changes). Flagged for the implementer: do **not** refactor the selection loop.

3. **Gate vs junk — same `prompt_text` machinery.** The gate uses `prompt_text = "Extract"`, junk uses `"Grab"`; both flow
   through the same prompt. With the M1.5 L1 input remap binding **F to both `interact` and `extract`**, the *key hint*
   `_derive_key_hint()` reads `interact`'s binding only. **Does the prompt need to show "[F] Extract" at a gate vs "[F]
   Grab" at junk, and does the hint stay correct after the L1 remap?** The text already comes from the Interactable's
   `prompt_text` (correct per-target), and the hint derives from the `interact` action which L1 rebinds to F — so it should
   read "[F]" automatically post-remap. **Low risk; verify after L1 lands** (cross-wave note for RG1, not a blocker for L4).

4. **Does the `.tscn` default-visible flip need to ship?** Yes — recommend flipping `visible = false` in
   `interaction_prompt.tscn` **and** clearing the baked `text`. It is defensive (the runtime invariant already covers it) but
   it makes the resting state honest and prevents a one-frame flash of `[E] Grab` at the prompt's first instantiation before
   `_update_prompt` runs. **Recommend: ship the flip.** (No Director call needed — pure correctness.)

5. **Key-hint staleness if `interact` is rebound at runtime.** `_derive_key_hint()` runs once in `_ready()`
   (`interaction_prompt.gd:26`). M1.5 doesn't add runtime rebinding, but the L1 remap changes the *project.godot* default —
   confirm a fresh prompt instance (lazy, post-remap) derives "[F]" correctly. **No action for L4**; note for RG1 verify.

6. **Test coverage (definition of done).** The fix is only "done" with a **regression test that asserts the hide
   invariant**: focus a stub → prompt visible; **free / range-exit / disable** the focused target → assert `_prompt.visible
   == false` on the next `_refresh_current()`, including the deferred-`queue_free` next-frame ordering that exposed #1.
   `tests/test_interaction.gd` currently asserts only the *shown* case. **Recommend extending it** (the implementer owns
   this; it's the verifiable proof-of-done). Not a design question — flagged so Phase 4 wires it into the L4 definition of
   done.

---

### Summary for the orchestrator

- **Root cause:** prompt visibility is driven off focus *transitions* (`_refresh_current`'s `best != _current` branch), not
  asserted as an invariant from `_current`. A focused target that is freed (deferred `queue_free` on pickup) or disabled can
  trip the `if best == _current: return` early-out, so `_hide_prompt()` never runs and the reused, world-space prompt is
  stranded visible — compounded by the prompt scene shipping `visible`-by-default with baked `[E] Grab` text. The steady-state
  range-exit path is correct; the *transition-gap* paths are not, and they were never unit-tested.
- **Fix:** make `_prompt.visible` a hard invariant of `_current` (`visible == _current != null && is_instance_valid &&
  can_interact()`) asserted **every frame** via a single `_update_prompt()` writer; default the `.tscn` prompt hidden + drop
  baked text. No knob, no signal/arity/save change. Add a regression test for the hide invariant.
