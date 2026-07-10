# V5 — Extract the duplicated interaction-owner boilerplate (R6)

> Phase-2 per-task design. M1.12 Wave 1 (parallel, file-disjoint with V1/V7/V8/V9).
> Source: `design/M1_12_Tasks/M1.12_Breakdown.md` R6/V5 anchor (lines 124-129, task
> card 182-193). Report source: `design/report-09072026.docx` §10.
> **Assignee:** general-purpose. **Behavior-preserving** — no fingerprint, signal,
> or timing change; this is a pure structural refactor.

---

## (a) Research on the premise

### The component split today

`Game/components/interaction/interactable.gd` (`Interactable`, `class_name`,
extends `Area2D`) is the passive marker: `interactable_id`, `display_name`,
`prompt_text`, `enabled`, and a single `can_interact() -> bool` guard
(`interactable.gd:36-37`). Its own docstring is explicit about the boundary this
task must not blur: *"This node is pure data + a can_interact() guard. It never
performs the pickup or opens the gate — that logic lives on the parent/owner...
The detector stays agnostic and only emits the request."* (`interactable.gd:12-15`).

`Game/components/interaction/interaction_detector.gd` (`InteractionDetector`, on
the player) tracks in-range `Interactable`s, resolves nearest-with-hysteresis, and
on the `interact` action emits `EventBus.interaction_requested.emit(_current.interactable_id, _current)`
(`interaction_detector.gd:66`). The signal is declared at
`Game/systems/event_bus.gd:30`: `signal interaction_requested(interactable_id: StringName, target: Node)`.
The detector never knows or cares who's listening — that's the seam this task
extracts on the *owner* side.

### The four owners, quoted verbatim

**`Game/entities/gate/extract_gate.gd`** (lines 22-62) — the reference pattern
every other owner's comments say they copied:

```gdscript
@export var interactable_id: StringName = &"gate"
@export var input_lockout_s: float = 0.25
var _locked: bool = false

func _ready() -> void:
    EventBus.interaction_requested.connect(_on_interaction_requested)

func _on_interaction_requested(id: StringName, target: Node) -> void:
    if id != interactable_id:
        return
    if target != null and target.get_parent() != self:
        return
    if _locked:
        return
    _locked = true
    _start_lockout()
    GameState.extract_and_end_run()

func _start_lockout() -> void:
    var tree := get_tree()
    if tree == null:
        _locked = false
        return
    var timer := tree.create_timer(input_lockout_s)
    timer.timeout.connect(func() -> void: _locked = false)
```

**`Game/scenes/hub/departure_portal.gd`** (lines 43-97) — its own comment admits
the copy: *"Mirrors extract_gate.gd:_on_interaction_requested verbatim, swapping
the action..."* (`departure_portal.gd:68-69`) and *"Copied from
extract_gate.gd:_start_lockout"* (`departure_portal.gd:88`):

```gdscript
@export var input_lockout_s: float = 0.25
var _locked: bool = false

func _on_interaction_requested(id: StringName, target: Node) -> void:
    if id != interactable_id:
        return
    if target != null and target.get_parent() != self:
        return
    if _locked:
        return
    _locked = true
    _start_lockout()
    EventBus.dive_requested.emit(band_id)

func _start_lockout() -> void:
    var tree := get_tree()
    if tree == null:
        _locked = false
        return
    var timer := tree.create_timer(input_lockout_s)
    timer.timeout.connect(func() -> void: _locked = false)
```

**`Game/scenes/hub/shop.gd`** (lines 14-55) — same admission: *"Mirrors
departure_portal.gd:_on_interaction_requested, swapping the dive-launch for
opening the ShopUI"* (`shop.gd:32-33`) and *"Copied from
departure_portal.gd:_start_lockout"* (`shop.gd:47`):

```gdscript
@export var input_lockout_s: float = 0.25
var _locked: bool = false

func _on_interaction_requested(id: StringName, target: Node) -> void:
    if id != interactable_id:
        return
    if target != null and target.get_parent() != self:
        return
    if _locked:
        return
    _locked = true
    _start_lockout()
    if _shop_ui != null:
        _shop_ui.open()

func _start_lockout() -> void:
    var tree := get_tree()
    if tree == null:
        _locked = false
        return
    var timer := tree.create_timer(input_lockout_s)
    timer.timeout.connect(func() -> void: _locked = false)
```

These three are **byte-for-byte identical mechanism** (id-guard → parent-guard →
lockout-guard → arm lockout → do the owner-specific thing), confirmed by diffing
the three blocks above: only the final action line differs.

### The fourth owner is NOT verbatim — it's missing the lockout entirely

**`Game/entities/junk_pickup/junk_pickup.gd`** (lines 63-68), captioned "A2
contract (copied structure from ExtractGate)":

```gdscript
func _on_interaction_requested(id: StringName, target: Node) -> void:
    if id != _interactable_id:
        return
    if target != null and target.get_parent() != self:
        return
    _try_pickup()
```

`JunkPickup` shares only the **id-guard + parent-check half**. It has **no
`_locked` var, no `input_lockout_s` export, no `_start_lockout()`** — confirmed by
grep (`grep -n "_locked\|input_lockout_s\|_start_lockout" junk_pickup.gd` returns
nothing). This is a real, load-bearing divergence, not an oversight to paper
over: a rapid re-interact on a full-bag pickup is *supposed* to be able to
re-flash-reject every time (no debounce needed — `_try_pickup()` is idempotent:
accept frees the node so a second request can't reach it; reject just re-flashes),
and on accept the node `queue_free()`s itself, which is a stronger and immediate
guard than a timed lockout. The breakdown's framing ("duplicated verbatim across
JunkPickup, ExtractGate, DeparturePortal, HubShop") is accurate for the
**id-guard + parent-check** portion (present in all four, worded identically) but
overstates it for the **lockout** portion (present in only three). **The
extraction must preserve this asymmetry, not erase it** — giving JunkPickup a
lockout it never had would be a behavior change, not a refactor.

### No test currently covers the lockout

Grepped `Game/tests/*.gd` for `lockout|_locked|interaction_requested` across the
gate/portal/shop-adjacent suites: `test_exit_placement.gd` exercises
`_test_multi_gate_extract` (4 real `ExtractGate`s, confirms `run_ended` fires
exactly once across a double-interact — line 235-276) but never sets
`input_lockout_s` low and asserts the lockout window itself; `test_extract_bank.gd`
and `test_shop_economy.gd` have zero hits for `lockout`/`_locked`. The
multi-gate test's "exactly once" assertion is actually proven by
`GameState.extract_and_end_run()`'s own idempotency (ending an already-ended run
is a no-op) as much as by the gate's `_locked` flag — so **no test today isolates
the lockout mechanism itself**. This confirms the breakdown's DoD call ("add a
focused interaction-owner unit test if none covers the lockout").

### Confirmed non-risks (checked so the refactor doesn't trip a hidden assumption)

- `Game/tests/test_junk_pickup.gd:83-84,158-162` asserts `container.get_child_count()`
  — but `container` holds the `JunkPickup` **siblings**, not a `JunkPickup`'s own
  children. Adding a runtime-only child to each owner node does not touch this count.
- `Game/tests/test_exit_placement.gd:280-287` (`_interactable_child`) resolves a
  gate's marker child **by name substring `"interactable"`**, falling back to
  `get_child(0)` only if no name matches. The `.tscn`-authored `Interactable` child
  keeps its name and stays discoverable regardless of what other children a
  script adds later at runtime.
- Every owner extends `Area2D`; none currently overrides `_exit_tree()` or manually
  disconnects `EventBus.interaction_requested` — cleanup today relies on Godot's
  standard "signal connections to a freed Object are dropped automatically."

---

## (b) Chosen shape + pseudocode

### Two candidates, evaluated

**(A) `InteractionOwner` — a small helper `Node`, added as a runtime child of the
owner in `_ready()` (no `.tscn` edit).** Owns `_locked` state, the id/parent
guards, and the timer arm; emits a clean `activated(target)` signal the owner
connects once. Freed automatically when the owner frees (it's a real child node),
which reproduces today's "signal auto-disconnects on free" behavior with zero new
cleanup code.

**(B) A method on `Interactable`** that owners route through (e.g.
`Interactable.try_activate(request_id, request_target) -> bool`).

**Recommendation: (A).** `Interactable` is *structurally* the wrong place for
this: it is the **detected** half (sensed by the player's `InteractionDetector`
via `area_entered`/`area_exited`), and today it does not listen to
`EventBus.interaction_requested` at all — only the **owner** does. Routing the
guard/lockout through `Interactable` would require it to gain an EventBus
connection, per-instance lockout timer state, and knowledge of the owner's
policy (three owners want a lockout, one explicitly must not) — exactly the
"detector/marker stays agnostic" contract its own docstring rules out
(`interactable.gd:12-15`: *"This node is pure data + a can_interact() guard... The
detector stays agnostic and only emits the request"* — extending that to *"the
marker also arms a lockout for whoever owns it"* contradicts "pure data"). A
sibling helper on the **owner** side keeps the marker passive and the guard where
the duplicated code already conceptually lives. A third variant — a stateless
`static` guard function owners call inline while each owner keeps its own
`_locked` var and timer-arm code — was considered and rejected: it only
extracts the *check*, not the *mutation* (arming the lockout), so the
lockout half of the duplication survives untouched. That's a partial win, not
the R6 goal.

### `InteractionOwner` (new file, `Game/components/interaction/interaction_owner.gd`)

```gdscript
class_name InteractionOwner
extends Node
## InteractionOwner — extracted id-guard + parent-check + fat-finger-lockout
## mechanism, previously duplicated verbatim across ExtractGate/DeparturePortal/
## HubShop (all three) and partially (id-guard + parent-check only, NO lockout)
## in JunkPickup (M1.12 V5 / report R6).
##
## Not scene-authored: the owner constructs + add_child()s one of these in its
## own _ready(), so no .tscn edits are needed and it is freed automatically when
## the owner frees (a real child node — Godot auto-disconnects its EventBus
## connection on free, same as the owner did for itself before this refactor).
##
## lockout_s == 0.0 disables the lockout arm entirely (JunkPickup's case): every
## request that passes id + parenthood activates immediately, every time, with
## no debounce — reproducing its exact current (lockout-free) behavior.

## Emitted once id + parenthood (+ lockout, if armed) all pass. The owner
## connects this once and does its one piece of owner-specific work.
signal activated(target: Node)

var _owner: Node
var _id: StringName
var _lockout_s: float
var _locked: bool = false


func _init(p_owner: Node = null, p_id: StringName = &"", p_lockout_s: float = 0.0) -> void:
    _owner = p_owner
    _id = p_id
    _lockout_s = p_lockout_s


func _ready() -> void:
    EventBus.interaction_requested.connect(_on_interaction_requested)


func _on_interaction_requested(id: StringName, target: Node) -> void:
    if id != _id:
        return
    if target != null and target.get_parent() != _owner:
        return
    if _lockout_s > 0.0:
        if _locked:
            return
        _locked = true
        _start_lockout()
    activated.emit(target)


func _start_lockout() -> void:
    var tree := get_tree()
    if tree == null:
        _locked = false
        return
    var timer := tree.create_timer(_lockout_s)
    timer.timeout.connect(func() -> void: _locked = false)
```

### The four owners, rewritten

**`extract_gate.gd`** — `interactable_id`/`input_lockout_s` exports stay (owner
authoring surface unchanged); everything below them collapses:

```gdscript
@export var interactable_id: StringName = &"gate"
@export var input_lockout_s: float = 0.25

var _io: InteractionOwner


func _ready() -> void:
    _io = InteractionOwner.new(self, interactable_id, input_lockout_s)
    add_child(_io)
    _io.activated.connect(_on_activated)


func _on_activated(_target: Node) -> void:
    GameState.extract_and_end_run()
```

**`departure_portal.gd`** — the existing id/tint push-down block in `_ready()`
(lines 52-63) is untouched (unrelated to this task); only the
guard/lockout tail is replaced:

```gdscript
var _io: InteractionOwner

func _ready() -> void:
    EventBus.interaction_requested  # (existing connect line removed)
    var it := $Interactable as Interactable
    if it != null:
        it.interactable_id = interactable_id
        it.prompt_text = prompt_text
        it.display_name = display_name
    ($PortalGlow as Sprite2D).modulate = glow_tint
    ($DiveGate as Sprite2D).modulate = gate_tint
    _io = InteractionOwner.new(self, interactable_id, input_lockout_s)
    add_child(_io)
    _io.activated.connect(_on_activated)


func _on_activated(_target: Node) -> void:
    EventBus.dive_requested.emit(band_id)
```

**`shop.gd`**:

```gdscript
var _io: InteractionOwner

func _ready() -> void:
    _io = InteractionOwner.new(self, interactable_id, input_lockout_s)
    add_child(_io)
    _io.activated.connect(_on_activated)


func _on_activated(_target: Node) -> void:
    if _shop_ui != null:
        _shop_ui.open()
```

**`junk_pickup.gd`** — `lockout_s = 0.0` is the explicit, readable marker of "this
owner never debounces," replacing the *absence* of a lockout block with a
*visible* zero, which is easier to audit than "no lockout code here, is that
intentional?":

```gdscript
var _io: InteractionOwner

func _ready() -> void:
    if _interactable != null:
        _interactable_id = _interactable.interactable_id
    _io = InteractionOwner.new(self, _interactable_id, 0.0)
    add_child(_io)
    _io.activated.connect(_on_activated)
    if _greybox != null:
        _greybox.connect("draw", _draw_greybox.bind(_greybox))
        _greybox.queue_redraw()


func _on_activated(_target: Node) -> void:
    _try_pickup()
```

Note `_interactable_id` is read from the child **before** constructing
`InteractionOwner`, preserving the existing "the child's authored id wins if it
differs from the cached default" behavior exactly.

### Test addition

A new headless scene test (or an extension of `test_interaction.gd`, run as a
scene since it needs `get_tree().create_timer`) that:
1. Instantiates a bare `InteractionOwner` with `lockout_s = 0.25`, fires two
   `EventBus.interaction_requested` emits back-to-back with the matching id/parent
   → asserts `activated` fires exactly once, then `await` past the window and
   fires again → asserts a second `activated`.
2. Instantiates one with `lockout_s = 0.0` and fires three back-to-back requests
   → asserts `activated` fires three times (proves JunkPickup's no-debounce
   path survives the extraction).
3. A wrong-id and a wrong-parent request → asserts `activated` does not fire
   (regression coverage the four owners relied on implicitly before).

This can live as `Game/tests/test_interaction_owner.tscn` + `.gd`, sibling to
`test_interaction.gd`, or be folded into it as additional cases — Phase 3 can
pick; either satisfies the DoD ("add a focused interaction-owner unit test if
none covers the lockout").

---

## Open Questions

1. **Component vs method-on-`Interactable` (the breakdown's own open question).**
   Resolved above on merit: **(A) `InteractionOwner` helper Node**, because
   `Interactable` is the detected/passive half and today has no
   `EventBus.interaction_requested` connection at all — routing the guard through
   it would blur its documented "pure data + can_interact() guard" contract and
   force it to carry per-owner lockout policy it currently doesn't know about.
   Low risk to flag further; recommend locking this without Director input (a
   technical/DRY call, not a vision call).

2. **How is JunkPickup's *different* guard semantics (no lockout) preserved
   without regressing to "give everything a lockout for consistency"?** Resolved
   via the `lockout_s: float` parameter with `0.0` as an explicit opt-out, rather
   than a `bool has_lockout` flag or a subclass — keeps one class, one code path,
   and the zero reads as "no debounce" at the call site (`InteractionOwner.new(self,
   _interactable_id, 0.0)`) rather than requiring a reader to know a magic flag's
   meaning. Alternative considered: give `JunkPickup` a lockout too "for free"
   since the helper makes it nearly costless — **rejected**, because that changes
   observable behavior (a full-bag pickup would stop re-flashing on rapid
   re-presses within the window) and the task is explicitly behavior-preserving.
   If the Director *wants* JunkPickup to gain a lockout, that is a new, separate,
   deliberate task — not a side effect of this refactor.

3. **Test strategy for the lockout — new test file or extend `test_interaction.gd`?**
   Either works; recommend a **new sibling file**
   (`test_interaction_owner.gd`/`.tscn`) so it can run standalone and stays
   file-disjoint from `test_interaction.gd` (which asserts detector-side focus/
   hysteresis, a different concern from owner-side activation). Low-stakes,
   resolve in Phase 3 or at implementation time.

4. **Should `input_lockout_s`/`interactable_id` exports move onto the
   `InteractionOwner` node itself (as its own `@export`s, editable if the helper
   were scene-authored) instead of being passed via constructor from code?**
   Recommend **no** — the helper is deliberately *not* `.tscn`-authored (constructed
   in code in `_ready()`), so there is nothing to export in the inspector; the
   owner's existing exports (`interactable_id`, `input_lockout_s`) stay the single
   authoring surface, unchanged from today, just forwarded once. Keeps the
   `.tscn` files themselves at zero-byte diffs (no new scene nodes to author),
   which also sidesteps any risk to `test_hub_contract.gd`'s node-path assertions
   (`$HubShop`, `$DeparturePortal`, etc. — all still resolve to the same owner
   root; the new child is anonymous/internal).

5. **Should the redundant "owner has its own `interactable_id` export *and* the
   child `Interactable` has its own" (already-existing minor duplication, visible
   in `DeparturePortal`'s id-push-down comment at `departure_portal.gd:27-32`) be
   folded in too?** **Out of scope** — the breakdown scopes V5 to "the copy-pasted
   *mechanism* moves; each owner keeps its own id + parenthood guard semantics"
   (`M1.12_Breakdown.md:186-188`). Noted here as a related-but-separate seam for a
   future task, not touched by V5.

---

## Expected debt ledger

Counting the **mechanism block** only (excluding each owner's one action line and
excluding doc-comment trims, which are a bonus on top):

- **3 verbatim copies** of the 22-line id-guard/parent-check/lockout/arm block
  (`ExtractGate`, `DeparturePortal`, `HubShop`) collapse to **one** canonical
  22-line implementation in `InteractionOwner`. Each of the three owners drops
  from ~22 lines of mechanism to ~4 lines of wiring (`_io = InteractionOwner.new(...)`,
  `add_child(_io)`, `_io.activated.connect(...)`, `func _on_activated(...)`) —
  **≈ -18 lines/owner × 3 ≈ -54 lines**.
- **JunkPickup's** narrower 6-line id-guard/parent-check block drops to the same
  ~4-line wiring shape — **≈ -2 lines**.
- **Doc-comment savings**: `DeparturePortal`'s and `HubShop`'s "mirrors X
  verbatim" / "copied from X" comments (2-3 lines each, `departure_portal.gd:68-69,88`,
  `shop.gd:32-33,47`) become unnecessary once there is no copy to explain —
  **≈ -10 lines** across the two files.
- **New file cost**: `interaction_owner.gd` — signal + 3 methods + doc comments
  — **≈ +50 lines**.
- **New test cost**: a focused lockout test — **≈ +60-80 lines** (new coverage,
  not debt, but worth noting it isn't free).

**Net production-code LOC: roughly -66 lines removed, +50 lines added ≈ -16 net**,
alongside the qualitative win the ledger should foreground: **duplicate-copy
count 3 → 1**, one previously-silent divergence (JunkPickup's missing lockout)
made an explicit, self-documenting parameter instead of an unstated omission,
and a **new, previously-nonexistent unit test** covering the lockout window
itself. Exact counts should be confirmed against the real diff at
implementation time (worklog records the actual `git diff --stat`).

---

## Resolved Decisions (Phase 3)

Fresh-eyes pass (not the design's author). Verified every quoted line against
the real files on disk before ratifying anything below —
`Game/components/interaction/interactable.gd`,
`Game/components/interaction/interaction_detector.gd`,
`Game/entities/junk_pickup/junk_pickup.gd:63-68`,
`Game/entities/gate/extract_gate.gd:22-62`,
`Game/scenes/hub/departure_portal.gd:43-97`, `Game/scenes/hub/shop.gd:14-55`,
plus `Game/tests/test_exit_placement.gd`, `test_junk_pickup.gd`,
`test_hub_contract.gd`, `test_interaction.gd`, and the four `.tscn` files. All
quotes in the design's (a)/(b) sections check out verbatim against the
as-built code — no correction needed to the research.

### 1. Component vs method-on-`Interactable` — **RATIFIED: (A) `InteractionOwner` helper Node.**

Confirmed independently, not just accepted on the author's say-so. Grepped
`interactable.gd` and `interaction_detector.gd`: `Interactable` has zero
`EventBus` connections today — only `InteractionDetector` (reads it) and the
four owners (listen to `interaction_requested`) touch the bus. Routing the
guard through `Interactable` would require it to gain a signal connection, a
`_locked` timer-state field, and a `lockout_s` policy value it doesn't
currently have any business knowing — directly contradicting its own
docstring's line "This node is pure data + a can_interact() guard... The
detector stays agnostic and only emits the request" (`interactable.gd:12-15`).
The component shape also composes better with the "not scene-authored, added
as a runtime child in `_ready()`" plan (OQ4) — a bare method on `Interactable`
would still need each owner to write its own `_locked`/timer bookkeeping
around the method call, which extracts less duplication than the ledger
claims. **Locked. No Director input needed** — this is a DRY/architecture call
with a documented, checkable technical reason, not a vision/scope/tone call.

### 2. Preserving differing FINAL ACTION + per-owner guard variance — **RATIFIED as designed, with the variance surface named precisely.**

Diffed all four `_on_interaction_requested` bodies against each other
line-by-line. The **only** variance across all four owners, once the
mechanism is extracted, is:
- **the final action** (one line: `GameState.extract_and_end_run()` /
  `EventBus.dive_requested.emit(band_id)` / `_shop_ui.open()` /
  `_try_pickup()`) — preserved by having each owner supply its own
  `_on_activated(target)` handler connected to `InteractionOwner.activated`;
- **the lockout duration** (`input_lockout_s` — `0.25` for
  ExtractGate/DeparturePortal/HubShop, effectively `0.0`/none for JunkPickup)
  — preserved via the `lockout_s: float` constructor param, `0.0` reproducing
  JunkPickup's verified-absent lockout (grepped `junk_pickup.gd` for
  `_locked|input_lockout_s|_start_lockout`: zero hits, confirming the design's
  claim).

There is **no third axis of variance** — the id-check (`id != _id`) and the
parent-check (`target != null and target.get_parent() != _owner`) are
byte-identical across all four owners today (confirmed by direct comparison
of the four quoted blocks), so `InteractionOwner` centralizing exactly those
two checks changes nothing about any owner's admission criteria. The design's
pseudocode already wires this correctly (`activated.emit(target)` fired once
per owner, each owner's `_on_activated` doing its one action line) — ratified
as-is, no changes needed.

One implementation-order note worth binding here (not previously called out):
`_io.activated.connect(_on_activated)` must run **after** `add_child(_io)` (as
the pseudocode already has it) so the connection exists before `_io._ready()`
wires the `EventBus` listener — in Godot 4, `add_child()` on a node whose
parent is already inside an active `SceneTree` runs the child's `_ready()`
synchronously within that same call (not deferred to next frame), so ordering
`add_child` before `.connect(...)` in the owner's own `_ready()` is safe and
matches the existing codebase's own pattern of instancing-then-immediately-using
a runtime child (see `interaction_detector.gd`'s prompt: instantiate → 
`add_child(_prompt)` → same-frame use). No mid-frame race exists. Confirmed
non-risk; no design change required.

### 3. Lockout unit-test placement — **RATIFIED: new sibling file, NOT an extension of `test_interaction.gd`.**

The design left this as "either works, low-stakes." Resolving decisively:
**new sibling `Game/tests/test_interaction_owner.gd` + `.tscn`**, structured
like `test_exit_placement.gd`/`test_junk_pickup.gd`/`test_hub_contract.gd`
(`extends Node`, run as a **scene** via
`godot --headless Game/tests/test_interaction_owner.tscn`), and explicitly
**not** added to `test_interaction.gd`. Verified `test_interaction.gd`'s own
header comment: `Run: godot --headless --script res://tests/test_interaction.gd`
— it is one of the project's `--script`-mode `SceneTree` harnesses, not a
`.tscn` scene test (63 of the 74 `Game/tests/*.gd` files are the `.tscn`
scene-test style; `test_interaction.gd` is one of the minority `--script`
style). Bolting timer-dependent `await`/`create_timer` assertions onto a
`--script` harness cuts against this project's own standing convention
(memory: "verify/knob tests run as SCENES … never `--script`") even though it
would probably work mechanically. A same-directory sibling `.tscn` avoids that
friction entirely and keeps `test_interaction.gd` scoped to what it already
tests (detector-side focus/hysteresis) per the design's own reasoning.
**Locked**, no Director input needed (test-infra convention, not a design
call). The design's three-case test plan (armed lockout fires-once-then-again;
`lockout_s = 0.0` fires every time; wrong-id/wrong-parent never fires) is
ratified unchanged as the content of that new file.

### 4. `.tscn` zero-byte-diff — **RATIFIED, confirmed by direct inspection (not just DoD-worry-avoidance).**

Read all four `.tscn` files
(`entities/gate/extract_gate.tscn`, `entities/junk_pickup/junk_pickup.tscn`,
`scenes/hub/departure_portal.tscn`, `scenes/hub/shop.tscn`) and grepped every
`Game/tests/*.gd` for `get_child_count` — the only hits are
`test_app_router.gd` (asserts `StateHost`'s child count, an unrelated node)
and two `test_rg1_m1*_verify.gd` hits on unrelated container nodes. **Zero**
test asserts the exact child count of `ExtractGate`, `DeparturePortal`,
`HubShop`, or `JunkPickup` themselves. `test_hub_contract.gd` only resolves
named paths (`.../Interactable`, `.../PortalGlow`, `.../DiveGate`,
`.../ShopUI`) via `get_node_or_null`, which are unaffected by an additional
anonymous runtime child. Constructing `InteractionOwner` in code and
`add_child()`-ing it in each owner's `_ready()` therefore requires **zero**
`.tscn` edits — confirmed, not just assumed. **Locked**, no Director input
needed.

### 5. Additional non-risk confirmed during this pass (not in the original OQ list)

`_interactable_child()` in `test_exit_placement.gd:280-287` and the two
`get_node("Interactable")` call sites in `test_junk_pickup.gd` resolve the
marker child **by authored name** (`"Interactable"`, exact match or
substring), which is unaffected by `InteractionOwner` being appended as a
*later* sibling child at runtime — node-path/name lookups don't depend on
child order or count. Confirms the design's "Confirmed non-risks" section
needed no amendment.

### Director review

**None required for this task.** Every open question resolved above is a
technical/architecture/test-infra call with a checkable, verifiable answer
(grep- and read-confirmed against the real code, not a matter of taste),
consistent with the design's own assessment and M1.12's "behavior-preserving
refactor" scope guardrail. This task carries no fingerprint risk (interaction
mechanism is off the layout path — no control fp touches it) and no
content/tuning change, so it does not meet the bar ("vision / fun / tone /
scope / date call") that would route it to the Director per CLAUDE.md's wave
close-out process. V5 is **locked** as of this Phase-3 pass.
