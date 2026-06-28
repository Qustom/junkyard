# N2 — Debug "disable player art" toggle (Phase-2 per-task design)

**Milestone:** M1.7 (Player Embodiment) · **Task id:** N2 · **Role(s):** ui-ux-designer (UX/menu half) + general-purpose (player-side handler integration)
**Authored:** 2026-06-27 (Phase 2 fan-out). **Template:** the M1.6 per-task design shape + `design/M1_7_Tasks/M1.7_Breakdown.md` §3 (N2 row), §6 (contracts), §7 (N2 open questions).
**Blocked by:** N0 (pre-declares `EventBus.debug_player_art_toggled(enabled: bool)`), N1 (establishes the `AnimatedSprite2D` ↔ greybox `Visual`/`Nose` swap seam + the movement-lock the toggle gates). N2's *menu-UI half* (the Meta-tab `CheckButton` + CSV string) is file-disjoint from N1 and may be drafted in parallel, but it **integrates after N1** (the player-side handler is the contract). Practical order is strictly sequential: N0 → N1 → N2.

---

## 1. Research on the premise

### 1.1 What this task is — and what it must NOT disturb

M1.7 swaps the player greybox (a teal `ColorRect` `Visual` + a triangle `Nose`) for the first real animated sprite. The Director asked for a **debug switch back to greybox** alongside the art. N2 builds that switch.

The hard constraint that shapes the entire design: this toggle is **NOT a `RunConfig` knob**. The `config_menu` (`Game/ui/config/config_menu.gd`) carries a build-time **coverage assertion** that the set of bound RunConfig fields equals RunConfig's exported `@export` set — a net so a future knob can't silently go unreachable (M1.7 Breakdown §6 contract 2). That set is **89 knobs**, and the all-off RunConfig default produces a locked **determinism fingerprint `e943ac9c8bc1`** (Breakdown §6 contract 1). A view-only debug switch must touch **neither**: it changes no RunConfig field (so the fingerprint cannot move) and lives **outside MANIFEST / `has_full_coverage()`** (so the 89-count holds).

The toggle is therefore a **non-field Meta-tab control** wired to an EventBus signal — exactly parallel to an already-shipped non-field Meta control (the telemetry-export button, see §1.4).

### 1.2 Where the coverage assertion is keyed — confirmed (it is SAFE)

I read `config_menu.gd`. The coverage assertion does **NOT** scan "every child Control" — if it did, a non-field `CheckButton` would trip it. It is keyed off **`_rows` (the bound-field dictionary) + the `SECTIONS` masters**, both of which are populated **only by `_build_row` / the master CheckButton path**. Concretely:

- `has_full_coverage()` (`config_menu.gd:392`) builds its `bound` set from exactly two sources:
  - `for f in _rows.keys(): bound[f] = true` (`:393-395`) — and `_rows[field]` is written **only** inside the per-field builders (`_build_bool :723`, `_build_string :732`, `_build_enum :744`, `_build_numeric :793`, `_build_unbounded_spin :807`, `_build_list_editor :835`) and the master path (`:545`). All are reached only via `_build_row` (`:688`) iterating `MANIFEST[prefix]` (`:574`) or `R4_VISION_FIELDS` (`:632`).
  - `for sec in SECTIONS: if sec.master != "": bound[sec.master] = true` (`:397-399`).
- It then compares `bound` against `_exported_config_fields()` (`:424`, the RunConfig property list) and `push_error`s on any `missing`/`extra` (`:409-414`).

**Therefore: any control NOT added to `_rows` and NOT a `SECTIONS` master is invisible to coverage.** The N2 toggle must (a) be constructed by its **own** builder method (never `_build_row`), (b) **never** write `_rows[...]`, and (c) **not** be a `SECTIONS` master. That is the single rule that keeps the 89-count and the assertion green. (`_assert_full_coverage :418` and the focused `test_config_menu` both call `has_full_coverage()`, so both stay 89.)

This is the same property that lets the telemetry-export button (`:650`) and the `Reset` button (`:503`), the summary/trap labels, the section chips, etc. all coexist as Controls without inflating coverage — none of them touch `_rows`.

### 1.3 The 7-tab taxonomy and the Meta tab — where a non-knob control belongs

`TABS` (`:184-192`) is the M1.6 (M4) 7-tab structure: Hazards, Level Gen, Vision, Time/Quota, Exp/Return, Throw/Cam, and **Meta** (`{"title_key": "CFG_TAB_META", "sections": [""]}`, `:191`). The Meta tab renders the `""`-prefix section (seed_override + build_tag) and is explicitly the home for **tooling controls that are not run knobs** — its section builder already special-cases the prefix to append the export button (`if prefix == "": _build_meta_export_button(col)` at `:581-582`). The Meta tab is the correct, precedented home for the art toggle.

### 1.4 Prior art — the telemetry-export button (the exact pattern to copy)

`_build_meta_export_button(parent)` (`:650-667`) is the canonical "non-field control on the Meta tab" precedent. Read it as the template:

- It is called from `_build_section_into` **only** when `prefix == ""` (`:581`), i.e. appended to the Meta section's column *after* the per-field rows.
- It constructs a `Button` (+ a status `Label`), `tr()`s its text against `config_strings.csv` (`CFG_EXPORT_TELEMETRY`), connects `pressed` to a handler, and adds it to the column — and it **never touches `_rows`** (its own doc-comment says so: "NOT a knob row → never touches `_rows`/coverage", `:649`).
- It is **web-guarded** (hidden on desktop). N2's toggle has the *opposite* availability — it is a **desktop/dev** aid, useful in every build — so N2 does **not** copy the web guard; the toggle is always shown.

N2 follows this pattern exactly, swapping the `Button` for a `CheckButton` and the `pressed`→export handler for a `toggled`→`EventBus.debug_player_art_toggled(on)` emit.

### 1.5 The signal path — CheckButton → EventBus → player handler

N0 pre-declares (sole `event_bus.gd` writer for M1.7) the **one new** signal, a tooling signal, not a gameplay one:

```gdscript
signal debug_player_art_toggled(enabled: bool)
```

This mirrors the established EventBus discipline (`event_bus.gd:1-6`: "pure wiring, holds no state"; primitives-only payloads). The flow:

```
ConfigMenu Meta-tab CheckButton.toggled(on)
        └─> EventBus.debug_player_art_toggled.emit(on)      # ConfigMenu is the only emitter
                └─> Player._on_debug_player_art_toggled(on)  # N1's visual seam listens
                         ├─ AnimatedSprite2D.visible = on  (+ stop/start its process)
                         ├─ greybox Visual.visible = not on  (+ Nose, OQ-3)
                         └─ visual controller: movement-lock ENABLED only when on
```

`enabled == true` ⇒ **art ON** (the default, the new look). `enabled == false` ⇒ **greybox / M1.6 behavior, byte-for-byte** (Breakdown §6 contract 3: greybox retained as fallback, movement-lock inactive when art is off).

The menu side knows **nothing** about the player (no hard reference — EventBus decouples them, TDD §2). The player side knows nothing about the menu. This is the signal-driven seam the architecture mandates; it is also why the toggle works at runtime in both the Hub and the Dive (the player listens wherever it is mounted, and the P-overlay `ConfigMenu` is process-mode-ALWAYS so it can emit while a dive is paused behind it — `config_menu.gd:321`).

### 1.6 Why this keeps determinism + coverage intact (restated as guarantees)

- **Determinism fp `e943ac9c8bc1` unchanged:** the toggle mutates **no** `_cfg` field; `_set_field` is never called; `apply_and_get_config()` (`:383`) returns the same `RunConfig`. The sprite/greybox swap is purely a *render* decision downstream of RNG. The fingerprint is a function of the RunConfig + seed only — neither moves.
- **89-knob coverage holds:** the toggle is not in `MANIFEST`, is not built by `_build_row`, never writes `_rows`, and is not a `SECTIONS` master, so `has_full_coverage()`'s `bound` set is byte-identical. `test_config_menu` / `test_run_config` counts stay 89.

---

## 2. Pseudocode (implementation-ready)

> All against the real as-built APIs in `config_menu.gd` / `event_bus.gd` / the N1 player seam. Illustrative, not final.

### 2.1 Meta-tab `CheckButton` construction (ConfigMenu side)

Hook it into the existing Meta-only branch in `_build_section_into`, **after** the export button, so all non-field Meta controls cluster together (`config_menu.gd:579-582`):

```gdscript
# in _build_section_into(parent, section_key), the existing prefix == "" branch:
if prefix == "":
    _build_meta_export_button(col)      # existing (:582)
    _build_debug_player_art_toggle(col) # N2 — NEW, also non-field
```

The builder — modelled on `_build_meta_export_button` (`:650`), but a `CheckButton` defaulting to **checked = art ON**, and **not** web-guarded:

```gdscript
## N2 (M1.7): a VIEW-ONLY debug switch to disable the player art (fall back to the
## retained greybox). NOT a RunConfig knob — it is NOT added to _rows/MANIFEST and is
## NOT a SECTIONS master, so has_full_coverage()'s 89-field bound set is untouched and
## the determinism fingerprint (e943ac9c8bc1) cannot move (it mutates no _cfg field).
## Emits EventBus.debug_player_art_toggled(enabled); the Player listens and swaps
## AnimatedSprite2D <-> greybox. Session-only (no save write) — see Resolved Decisions.
func _build_debug_player_art_toggle(parent: Control) -> void:
    parent.add_child(HSeparator.new())
    var row := HBoxContainer.new()
    row.name = "DebugPlayerArtRow"
    row.add_theme_constant_override("separation", 8)

    var cb := CheckButton.new()
    cb.name = "DebugPlayerArtToggle"
    cb.text = tr("CFG_DEBUG_PLAYER_ART")     # ONE new CSV label key
    cb.button_pressed = true                  # default = art ON (matches player default)
    cb.toggled.connect(_on_debug_player_art_toggled)
    row.add_child(cb)

    parent.add_child(row)
    # NOTE: deliberately NOT _rows["..."] = cb — this control is invisible to coverage.
    # NOTE: no _refresh_all() / _push_value_to_control path touches it — it is not a field.

## The toggle handler: pure signal emit, no _cfg mutation, no _set_field.
func _on_debug_player_art_toggled(enabled: bool) -> void:
    EventBus.debug_player_art_toggled.emit(enabled)
```

Notes that make it safe + correct:
- **Default checked = art ON** so the control's visible state agrees with the player's default-on art the instant the overlay is first opened. The player does **not** need the menu to be opened to show art (its default is art-on regardless — see OQ-4 / Resolved); the CheckButton merely *reflects and toggles* that state.
- It is **never** reset by `_refresh_all()` / `_on_reset_pressed()` (those iterate `_rows` only, `:936`), so pressing **Reset** (which restores the all-off RunConfig control) does **not** flip the art toggle. That is intentional: Reset is a *run-config* control; the art switch is orthogonal view state. (Cross-check this against OQ-1 — see Open Questions.)

### 2.2 CSV string row (`Game/ui/config/config_strings.csv`)

Add exactly **one** label key (all visible strings go through `tr()`, per the menu's readability rules, `config_menu.gd:19`). Following the existing `CFG_*` convention:

```csv
keys,en
CFG_DEBUG_PLAYER_ART,Disable player art is the inverse — so label it for the ON state:
```

Concretely the label should describe the **control**, not a transient state, since the CheckButton itself carries on/off. Recommended value:

```csv
CFG_DEBUG_PLAYER_ART,Player art (debug)
```

(If a clearer affordance is wanted, `Use player sprite` / `Show player art` — see OQ-1 for the final string call. The key name `CFG_DEBUG_PLAYER_ART` is the stable id regardless of the chosen English text.)

### 2.3 Player-side handler (the N1 visual seam listens)

N1 builds the `AnimatedSprite2D` + retains the greybox `Visual`/`Nose`, and owns the visual controller. N2 adds the **listener** into that seam (N1 has already set up the nodes; N2 wires the connect + handler). The handler flips visibility/process and tells the visual controller to drop the movement-lock when art is off (Breakdown §6 contract 3):

```gdscript
# in the player's _ready() (or the N1 visual controller's _ready):
EventBus.debug_player_art_toggled.connect(_on_debug_player_art_toggled)
# Default already art-ON in the scene; no need to emit on boot. (See OQ-4.)

## N2: swap AnimatedSprite2D <-> greybox at runtime. enabled == art ON.
func _on_debug_player_art_toggled(enabled: bool) -> void:
    # Art (the AnimatedSprite2D built by N1).
    _anim_sprite.visible = enabled
    # Stop the SpriteFrames animation when hidden (no needless per-frame work).
    if enabled:
        _visual_controller.resume()          # re-selects idle/walk from velocity
    else:
        _anim_sprite.stop()
    # Greybox fallback (retained, hidden-by-default when art is on).
    _greybox_visual.visible = not enabled     # the teal ColorRect "Visual"
    _greybox_nose.visible = not enabled        # the triangle "Nose" (OQ-3: recommend yes)
    # Feel parity: the brief pickup/throw movement-lock is gated to art-ON only, so
    # art-OFF == M1.6 byte-for-byte (Breakdown contract 3). The visual controller owns
    # the lock; tell it the art state so it stops arming the lock when art is off.
    _visual_controller.set_movement_lock_enabled(enabled)
```

`set_movement_lock_enabled(false)` makes the controller a pure renderer with the lock disarmed — pickup/throw still *fire* (they're driven by `junk_picked_up`/`item_thrown`), but root no input. With art off, the AnimatedSprite2D is hidden and stopped, so even though those signals arrive, there is no visible clip and no lock — identical to M1.6.

(Exact node names — `_anim_sprite`, `_greybox_visual`, `_greybox_nose`, `_visual_controller` — are N1's; N2 binds to whatever N1 names them. The contract is just: art node toggles `visible`/process, greybox toggles inverse, lock disarms when off.)

### 2.4 What N2 explicitly does NOT do

- Does **not** add a row to `_rows` or an entry to `MANIFEST`.
- Does **not** call `_build_row`, `_set_field`, or `_refresh_*` for this control.
- Does **not** add a `SECTIONS` / `TABS` entry (it lives inside the existing Meta tab/section).
- Does **not** edit `event_bus.gd` (N0 already pre-declared the signal — single writer).
- Does **not** add a save-schema field (session-only; see Resolved Decisions).

---

## 3. Open Questions

**OQ-1 — Exact Meta-tab placement + final label text.**
Placement: append it to the Meta section column **after** the telemetry-export button (clustering the two non-field tooling controls), behind an `HSeparator`. Is that the right spot, or should it sit **above** the export button (more discoverable, since the export button is web-only/often hidden)? And the final English string for `CFG_DEBUG_PLAYER_ART` — `Player art (debug)` vs `Show player art` vs `Use player sprite`. *Recommendation:* place it directly under the Meta section's field rows, **above** the (often-hidden, web-only) export button, so it's the first non-field control a desktop dev sees; label `Player art (debug)`. **Needs a quick Director/UX nod on the string + order only.**

**OQ-2 — Persist as a debug pref, or session-only?**
Should the toggle write to a save/pref so a dev who turns art off stays off across launches, or reset to art-ON every launch? *Recommendation (strong):* **session-only, no save write.** It is a debug aid, not player state; persisting it would require touching the save schema (a `schema_version` bump + a QA migration fixture per the save rules), which violates the M1.7 "no save-schema change" guardrail and risks a fresh launch hiding the very art M1.7 ships. Session-only keeps the default-on art guaranteed on every cold start. *(See Resolved.)*

**OQ-3 — Does the toggle also show/hide the `Nose`?**
When art is on, the triangle `Nose` is greybox-era facing-indicator clutter; the sprite carries its own directional read. *Recommendation:* **yes — hide the `Nose` with the `Visual`** (both are the greybox; toggling art on hides the whole greybox, toggling art off restores the whole greybox = exact M1.6 look). N1's scene retains both; N2's handler flips both together. Confirm N1 keeps `Nose` as a sibling the handler can reach. *(See Resolved.)*

**OQ-4 — Initial state: fresh launch shows ART, headless/test unaffected.**
The art must be **on by default** at a fresh launch (the player scene defaults art-on; the CheckButton defaults `button_pressed = true`), with **no boot-time emit required** — the scene's default already shows art, and the menu only emits when the dev actually toggles. Does any context need a boot emit to *force-sync*? *Recommendation:* **no boot emit.** Player scene default = art on; CheckButton default = checked; they agree without a sync emit. Headless/test contexts never open the P-overlay and never emit, so they are unaffected (and if a test instantiates the player directly, it gets the scene default = art on, which N1's pure-helper unit tests don't depend on anyway). *Risk to confirm with N1:* that the player's scene default truly is art-on and does not require an external "set art" call to render. *(See Resolved.)*

**OQ-5 — Also expose via a hotkey?**
Should there be a dedicated input action (e.g. a function key) to flip art without opening the P-menu? *Recommendation:* **menu-only, no hotkey.** A new InputMap action is M0-owned input surface + a rebinding/conflict concern, and the P-overlay is already one keypress away. Keep the surface minimal; revisit only if RG2 shows devs flip it constantly. *(See Resolved.)*

**OQ-6 — Coverage-assertion safety re-confirmation (for the implementer).**
Confirmed in §1.2: `has_full_coverage()` keys off `_rows` + `SECTIONS` masters, **not** child-Control enumeration, so a non-`_rows` `CheckButton` is invisible to it. The implementer must simply never write `_rows[...]` for this control and never add it to `MANIFEST`. *No open decision — this is a stated invariant the build must hold; flagged here so the implementer verifies `test_config_menu` still reports 89 after the change.*

---

## 4. Hard constraints (must all hold — restated for the build + RG1)

1. **89-knob coverage MUST still pass** — toggle is outside `MANIFEST` / `_rows` / `SECTIONS` masters; `test_config_menu` / `test_run_config` stay 89.
2. **Determinism fingerprint unchanged** — all-off RunConfig fp stays **`e943ac9c8bc1`**; the toggle mutates no `_cfg` field and never calls `_set_field` / changes `apply_and_get_config()`.
3. **View-only, outside MANIFEST** — a separate Meta-tab `CheckButton` wired to `EventBus.debug_player_art_toggled`, never a RunConfig `@export` field.
4. **Default = art ON** — CheckButton defaults checked; player scene defaults art-on; a fresh/headless launch shows art with no boot emit.
5. **No save-schema change** — session-only (recommended + ratified below); no `schema_version` bump, no migration fixture.
6. **One CSV label key** — `CFG_DEBUG_PLAYER_ART` in `Game/ui/config/config_strings.csv`, surfaced via `tr()`.
7. **Art-OFF == M1.6 byte-for-byte** — greybox `Visual` (+ `Nose`) restored, AnimatedSprite2D hidden + stopped, movement-lock disarmed.

---

## 5. Resolved Decisions

> Phase-3 fresh-eyes / Director resolution lands here. Pre-seeded with this author's recommendations; items tagged **[needs Director review]** are vision/UX calls reserved for the human (orchestrator-loop step 7) — do NOT self-disposition those.

- **OQ-2 (persistence):** RESOLVE → **session-only, no save write.** Technical merit is decisive (avoids a save-schema bump that would violate the M1.7 guardrail and could hide default art on a fresh launch). Author-resolvable; not a Director call.
- **OQ-3 (hide Nose):** RESOLVE → **yes, hide `Nose` with `Visual`** (greybox is the whole greybox; art-off restores exact M1.6). Author-resolvable on consistency grounds; depends only on N1 keeping `Nose` reachable.
- **OQ-4 (initial state / headless):** RESOLVE → **default art-ON, no boot emit; headless/test unaffected.** Author-resolvable. *Build dependency:* N1 must make the player scene default render art with no external set call — flag to N1.
- **OQ-5 (hotkey):** RESOLVE → **menu-only, no hotkey.** Author-resolvable (minimal-surface, avoids InputMap/rebinding scope); revisit only on RG2 evidence.
- **OQ-6 (coverage safety):** RESOLVE → invariant confirmed in §1.2 (assertion keys off `_rows` + masters, not children). No decision needed; implementer verifies 89 post-change.
- **OQ-1 (placement + label string):** **[needs Director review]** — a small UX/tone call. *Recommendation:* place the toggle **above** the (web-only/often-hidden) export button in the Meta section; label `Player art (debug)`. The key id `CFG_DEBUG_PLAYER_ART` is stable regardless of the chosen English. Low-stakes; surface with the recommendation, proceed on the recommendation if the Director defers.

---

### Phase-3 fresh-eyes (QA) verification — 2026-06-27

Fresh QA eyes (not the N2 author) re-read `Game/ui/config/config_menu.gd` and `M1.7_Breakdown.md` §6 to verify the author's pre-resolutions hold, with focus on the coverage-safety invariant. Per-OQ verdict:

- **OQ-1 (placement + label):** **CONFIRM — [needs Director review].** Genuinely a UX-string/order call (tone), correctly reserved for the human. The recommendation (above the export button; label `Player art (debug)`; stable key `CFG_DEBUG_PLAYER_ART`) is sound — placing it above the export button is the better call precisely because that button is web-only/hidden on desktop (`config_menu.gd:660-663` hides it on non-web), so on a desktop dev build the toggle would otherwise be the lone visible non-field control sitting under an invisible separator. Proceed on the recommendation if the Director defers.
- **OQ-2 (persistence):** **CONFIRM — session-only, no save write.** Decisive on merit: persisting would force a `schema_version` bump + a QA migration fixture (save rules) and violates the M1.7 "no save-schema change" guardrail (Breakdown §6 contract 5 spirit / §2). Session-only also guarantees default-on art on every cold start. Not a Director call.
- **OQ-3 (hide Nose):** **CONFIRM — yes, hide `Nose` with `Visual`.** "Art-OFF == M1.6 byte-for-byte" (Breakdown §6 contract 3) requires the *whole* greybox restored on OFF and the *whole* greybox hidden on ON; toggling both `Visual` and `Nose` together is the only reading that satisfies it. Build dependency on N1 keeping `Nose` a reachable sibling is correctly flagged.
- **OQ-4 (initial state / headless):** **CONFIRM — default art-ON, no boot emit; headless/test unaffected.** CheckButton `button_pressed = true` agrees with the scene default; no force-sync emit needed. Headless/CI never opens the P-overlay (`config_menu.gd:320` boots `visible = false`, shown only on the `debug_menu_toggle` action), so the smoke test and GdUnit suite never construct or emit through this control — they cannot be perturbed. Build dependency on N1 (scene default truly renders art with no external set call) correctly flagged to N1.
- **OQ-5 (hotkey):** **CONFIRM — menu-only, no hotkey.** A new InputMap action is M0-owned input surface + a rebind/conflict concern for zero gain (the P-overlay is one keypress away). Minimal-surface is right; revisit only on RG2 evidence.
- **OQ-6 (coverage safety):** **CONFIRM — invariant verified independently (see below).** No open decision; it is a build invariant the implementer must hold + regression-check.

**Coverage-safety — independently verified (the key QA claim):** YES, safe. `has_full_coverage()` (`config_menu.gd:392`) assembles its `bound` set from EXACTLY two masters — `_rows.keys()` (`:393-395`) and `SECTIONS[*].master` (`:397-399`) — and compares against `_exported_config_fields()` (`:400`, defined `:424`). It performs **no child-Control / `get_children()` enumeration** at any point. `_rows[field]` is written ONLY by the per-field builders (`_build_bool :723`, `_build_string :732`, `_build_enum :744`, `_build_numeric :793`, `_build_unbounded_spin :807`, `_build_list_editor :835`) and the master path (`:545`), all reached only via `_build_row` (`:688`) over `MANIFEST[prefix]` (`:574`) / `R4_VISION_FIELDS` (`:632`). The shipped precedent `_build_meta_export_button` (`:650`) adds a `Button` + `Label` to the column (`:666-667`) and **never writes `_rows`** — the exact pattern N2 copies. Therefore a Meta-tab `CheckButton` that (a) is built by its own method, (b) never writes `_rows[...]`, and (c) is not a `SECTIONS` master is invisible to coverage; the `bound` set stays byte-identical and the **89-count holds**. The toggle handler emits the EventBus signal and never calls `_set_field` (`:898`), so `_cfg` is never mutated and `apply_and_get_config()` (`:383`) returns an unchanged RunConfig — the **determinism fingerprint cannot move**. The author's §1.2 analysis is accurate as written.

**Mandatory regression check for the implementer (state explicitly):** after wiring N2, run `test_config_menu` (the config-coverage test) and confirm it still reports **89** bound fields with the assertion green, AND confirm the all-off RunConfig determinism fingerprint is still **`e943ac9c8bc1`**. Both must be unchanged; either moving means N2 leaked into `_rows`/`MANIFEST`/a `SECTIONS` master (coverage) or touched a `_cfg` field (fingerprint). Confirmed design properties: the toggle is **session-only (no save-schema touch — no `schema_version` bump, no migration fixture)** and **default = art ON** (CheckButton `button_pressed = true` ⇄ player scene art-on default).

---

## Director Disposition (ratified 2026-06-27)

- **OQ-1 label/placement → RATIFIED on the recommendation:** label **"Player art (debug)"** (CSV key `CFG_DEBUG_PLAYER_ART`),
  placed on the **Meta tab above the web-only telemetry-export button**. Toggle is **session-only** (no save write), **default = art ON**.
  All other N2 Resolved Decisions stand. Implementer must confirm `test_config_menu` still reports **89** + fp `e943ac9c8bc1`.
