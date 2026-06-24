# L3 — Money-text reposition (#8)

**Milestone:** M1.5 (Agency & Legibility), Wave 1 (Foundation + legibility fixes).
**Role:** ui-ux-designer.
**Type:** Bug-fix / HUD layout change — **NOT knob-gated** (a correctness fix that changes the HUD
for everyone, like Wave-5's BUG7/BUG8). Touches **no generation** → does not move the all-off
fingerprint (`e943ac9c8bc1`).
**BlockedBy:** none (pure HUD layout; file-disjoint from L0's `decision_hud.gd`-untouched files and
from L4's interaction files — see breakdown §4/§5).
**Definition of done:** the run-haul money readout sits **below the dive timer** (top-right band),
right-aligned, legible against the world, and **no longer collides with the bottom-right inventory
panel**. Update logic in `_refresh_haul()` is **unchanged**. The headless smoke test + `--import`
still pass (the scene still loads, `%HaulValueLabel` still resolves).

---

## (a) Research on the premise — the overlap

### Director feedback #8 (the bug)
The run-haul money readout ("Holding: N") is reported as **hidden behind the bottom-right inventory
panel** — illegible during a run. The fix: move it to sit **below the dive timer** (top-right),
right-aligned and legible. This is a layout-only move; the value it shows and how it updates do not
change.

### The node that moves: `HaulValueLabel`
`ui/hud/decision_hud.tscn:20-32` — the readout is a single `Label`, currently anchored **top-left**:

```
[node name="HaulValueLabel" type="Label" parent="Root"]   # decision_hud.tscn:20
unique_name_in_owner = true                                # :21  → resolved as %HaulValueLabel
layout_mode = 1
anchors_preset = 0                                         # :23  TOP_LEFT preset, all anchors = 0.0
offset_left = 16.0                                         # :24  ┐ 16px in from the LEFT edge
offset_top = 16.0                                          # :25  │ 16px down from the TOP edge
offset_right = 256.0                                       # :26  │ extends to x=256 (240px wide box)
offset_bottom = 44.0                                       # :27  ┘ 28px tall
theme_override_colors/font_color = Color(1, 1, 1, 1)       # :28  full-contrast white (legibility layer)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1) # :29 black outline
theme_override_constants/outline_size = 5                  # :30  5px outline (reads over any band)
theme_override_font_sizes/font_size = 22                   # :31  22px — the largest HUD font
text = "Holding: 0"                                        # :32  (live text comes from tr("HUD_HOLDING"))
```

It has **no `horizontal_alignment`** set, so text defaults to left-aligned (`HORIZONTAL_ALIGNMENT_LEFT`).

### The update logic that does NOT change: `_refresh_haul()`
`ui/hud/decision_hud.gd:193-194`:

```gdscript
func _refresh_haul() -> void:
	_haul_value_label.text = tr("HUD_HOLDING").format({"value": GameState.run_haul_value()})
```

Confirmed: `_refresh_haul()` only sets `.text` via `tr("HUD_HOLDING")` (string externalized to
`ui/hud/hud_strings.csv`, untouched). The node is referenced once as `@onready var _haul_value_label:
Label = %HaulValueLabel` (`decision_hud.gd:88`), driven purely by signals
(`_on_run_inventory_changed` → `_refresh_haul`, lines 156-159; also called on `_ready` line 137). The
only other touch is the urgency **pulse** in `_process` (lines 145-151), which writes
`_haul_value_label.modulate` (alpha pulse using `HOLDING_COLOR = Color(1,1,1)`, `decision_hud.gd:76`).
**None of this reads or depends on the node's anchors/offsets** — moving the label in the `.tscn`
requires **zero `.gd` change**. L3 is a pure scene-layout edit; `unique_name_in_owner = true` and the
node name `HaulValueLabel` must be preserved so `%HaulValueLabel` keeps resolving.

### Where "below the dive timer" is — the top-right band
Two nodes establish the top-right timer band the label must tuck under:

1. **`ClockTopRight`** VBox in the HUD itself (`decision_hud.tscn:34-44`) — anchors top-right
   (`anchors_preset = 1`, `anchor_left = anchor_right = 1.0`), `offset_left = -228.0`,
   `offset_top = 16.0`, `offset_right = -16.0`, `offset_bottom = 64.0`. It holds the `ClockBar`
   (`custom_minimum_size = Vector2(0, 22)`, line 48) **and** the `ClockLabel` ("60s",
   `horizontal_alignment = 2` = right, lines 54-62). So inside the HUD the visible clock occupies the
   x-band `[-228, -16]` (212px wide, right-aligned) and runs from y≈16 down to ≈64 (bar + 2px sep +
   16px label).
2. **`ui/dive_clock_meter.tscn:16-27`** — a separate `CanvasLayer` overlay ProgressBar, also top-right
   (`anchors_preset = 1`, `anchor_left = anchor_right = 1.0`), `offset_left = -228.0`,
   `offset_top = 16.0`, `offset_right = -16.0`, `offset_bottom = 40.0` (24px tall). Same x-band
   `[-228, -16]`, same `offset_top = 16`.

**Both** timer surfaces share the exact x-band `offset_left = -228 … offset_right = -16` and start at
`offset_top = 16`. The dive-clock-meter bar ends at y≈40; the in-HUD `ClockTopRight` (bar + numeric
label) ends at y≈64. So **"below the dive timer" = the same `[-228, -16]` x-band, starting just under
y≈64** (clear of both the meter bar and the numeric "Ns" label). There is an existing precedent at
exactly this spot: **`CostIndicatorAnchor`** (`decision_hud.tscn:170-181`) is a zero-height Control in
the **identical** band — `anchors_preset = 1`, `anchor_left = anchor_right = 1.0`,
`offset_left = -228.0`, `offset_top = 70.0`, `offset_right = -16.0`, `offset_bottom = 70.0`. y=70 is
the established "just below the timer" baseline; the R2 floating cost indicator already spawns there.
The haul label should adopt the **same x-band and a `offset_top` ≈ 70** (see Open Question 1 for the
exact gap and the interaction with the cost-indicator anchor).

### The collision being fixed: the bottom-right inventory panel
`ui/inventory/inventory_panel.tscn:6-18` — the InventoryPanel root anchors **bottom-right**
(`anchors_preset = 3`, `anchor_left = anchor_top = anchor_right = anchor_bottom = 1.0`),
`offset_left = -360.0`, `offset_top = -240.0`. It is instanced into the HUD as the last-but-one child
(`decision_hud.tscn:183`), so it draws **on top** of earlier siblings. It is a **360 × 240** opaque-ish
panel (`Background` ColorRect `color = Color(0.07,0.07,0.09,0.78)`, line 28) pinned to the
bottom-right corner: it covers the screen rect `[width-360 … width, height-240 … height]`.

Note on the collision geometry: as authored, `HaulValueLabel` is **top-left** `[16…256, 16…44]` and
the inventory is **bottom-right** `[w-360…w, h-240…h]` — at the project's design resolution those two
rects do not strictly overlap. The Director's "hidden behind the inventory" report is real but the
*mechanism* is one of: (i) at small/scaled or different-aspect viewports (the web build, a smaller
window) the panel's left edge `w-360` and the label's right edge `256` close in and the panel's
**top edge** `h-240` can ride up over a top-left label on a short viewport; (ii) the player simply
reads the bottom-right region as "the inventory area" and a money number there is visually swallowed by
the busy grid; or (iii) the label was perceived in a prior/scaled layout near the inventory. **The fix
moots all three:** moving the readout to the **top-right band under the timer** puts it in an
unambiguously empty, high-real-estate region that no other surface occupies, and that the player
already watches (the timer). This is the safe, intent-faithful resolution and matches the breakdown's
L3 row ("sit below the dive timer (top-right), right-aligned, legible").

### Readability rules that apply (project standard, from `decision_hud.gd` header + research)
- **Legibility layer (band-independent):** the at-risk number "stays high-contrast regardless of band
  styling" (`decision_hud.gd:75`). Preserve the existing `font_color = white`, `outline_color = black`,
  `outline_size = 5`, `font_size = 22` — the largest, highest-contrast HUD treatment — so the readout
  survives any band's lighting. **Do not shrink or recolour it.**
- **Redundant non-colour channels** (`design/research/03_readable_junk_study.md`, and the colour rules
  in the playbook): the haul readout already carries a text label prefix ("Holding:") + the numeral, so
  it is not colour-dependent — keep the textual prefix (Open Question 2).
- **No new strings, no string change:** the text still comes from `tr("HUD_HOLDING")`; localization is
  untouched. (If a prefix/format tweak is wanted — Open Question 2 — that is a CSV edit, flagged, not
  assumed.)

---

## (b) Pseudocode — the exact `.tscn` anchor/offset change for `HaulValueLabel`

Single node edited: `decision_hud.tscn:20-32`. **Re-anchor from top-left to top-right, tuck under the
timer band, right-align the text.** No other node, and no `.gd`, changes.

### BEFORE (`decision_hud.tscn:20-32`, as-is)
```
[node name="HaulValueLabel" type="Label" parent="Root"]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 0          # TOP_LEFT — anchor_left/top/right/bottom all 0.0
offset_left = 16.0          #   ┐ top-left box, 240px wide, 28px tall
offset_top = 16.0           #   │
offset_right = 256.0        #   │
offset_bottom = 44.0        #   ┘
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 5
theme_override_font_sizes/font_size = 22
# (no horizontal_alignment → defaults to LEFT)
text = "Holding: 0"
```

### AFTER (proposed — re-anchored top-right, under the timer, right-aligned)
```
[node name="HaulValueLabel" type="Label" parent="Root"]
unique_name_in_owner = true                 # UNCHANGED — %HaulValueLabel must still resolve
layout_mode = 1
anchors_preset = 1                           # CHANGED 0 → 1 (TOP_RIGHT)
anchor_left = 1.0                            # ADDED  (was implicit 0.0)
anchor_right = 1.0                           # ADDED  (was implicit 0.0)
offset_left = -228.0                         # CHANGED  16.0 → -228.0  (match the timer's x-band left)
offset_top = 70.0                            # CHANGED  16.0 →  70.0   (just below the timer, ≈ CostIndicatorAnchor's y)
offset_right = -16.0                         # CHANGED 256.0 →  -16.0  (match the timer's x-band right)
offset_bottom = 98.0                         # CHANGED  44.0 →  98.0   (70 + 28px tall, preserves height)
grow_horizontal = 0                          # ADDED  (grow LEFT, mirrors ClockTopRight line 43 — box grows away from the right edge)
theme_override_colors/font_color = Color(1, 1, 1, 1)       # UNCHANGED (legibility layer)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1) # UNCHANGED
theme_override_constants/outline_size = 5    # UNCHANGED
theme_override_font_sizes/font_size = 22     # UNCHANGED
horizontal_alignment = 2                     # ADDED  (HORIZONTAL_ALIGNMENT_RIGHT — right-aligned per the L3 spec)
text = "Holding: 0"                          # UNCHANGED (live value still from tr("HUD_HOLDING") in _refresh_haul)
```

### Offset before/after table
| property | before | after | why |
|---|---|---|---|
| `anchors_preset` | `0` (top-left) | `1` (top-right) | dock to the right edge where the timer lives |
| `anchor_left` / `anchor_right` | `0.0` / `0.0` (implicit) | `1.0` / `1.0` | both edges measured from the right viewport edge |
| `offset_left` | `16.0` | `-228.0` | left edge of the timer band (matches `ClockTopRight`/dive-meter `offset_left`) |
| `offset_top` | `16.0` | `70.0` | clear the dive-meter bar (ends y≈40) and the in-HUD clock VBox (ends y≈64); align to the existing y=70 "below-timer" baseline (`CostIndicatorAnchor`) |
| `offset_right` | `256.0` | `-16.0` | right edge of the timer band (matches `ClockTopRight`/dive-meter `offset_right`) |
| `offset_bottom` | `44.0` | `98.0` | `offset_top + 28` — preserves the original 28px row height |
| `grow_horizontal` | (default 2) | `0` | grow leftward from the right edge, mirroring `ClockTopRight` (line 43) |
| `horizontal_alignment` | (unset → LEFT) | `2` (RIGHT) | right-aligned text per spec, mirrors `ClockLabel` (line 62) |

**Result:** the readout occupies the 212px-wide right-edge band `[-228, -16]` directly under the
timer, right-aligned so the number's least-significant digit lines up with the clock's "Ns" readout
and the bar's right edge — a clean vertical stack (timer → time-left → holding) in the corner the
player already watches, and entirely clear of the bottom-right inventory panel.

### Smoke-test / load expectations (no code path changes)
- `%HaulValueLabel` still resolves (node name + `unique_name_in_owner` preserved) → `decision_hud.gd:88`
  `@onready` succeeds, `_refresh_haul()` (line 137 on ready) runs unchanged.
- The `_process` pulse (lines 145-151) writes only `modulate`; re-anchoring does not affect it.
- No new EventBus signal, no `RunConfig` knob, no string, no save field. Fingerprint unaffected.

---

## (c) Open Questions

> Most are low-stakes layout/taste calls. Flagged where Director taste genuinely helps.

1. **Exact vertical gap under the timer (`offset_top`).** Proposed `70.0` to align with the existing
   `CostIndicatorAnchor` (`decision_hud.tscn:176`, y=70) — the established "just below the timer"
   baseline. This sits ~6px under the in-HUD `ClockTopRight` bottom (y≈64) and ~30px under the
   dive-clock-meter bar (y≈40). **Sub-question / mild conflict:** `CostIndicatorAnchor` is where the R2
   floating "-N {unit}" cost indicator spawns. A persistent haul label at the *same* y=70 could
   visually collide with a transient cost indicator that rises from there. **Recommendation
   (low-stakes, ui can self-resolve):** the cost indicator *rises and fades* (it animates upward off
   y=70 quickly, `cost_indicator_seconds` ≈ 1.1), and the haul label is right-edge-docked while the
   cost indicator typically renders near the bar centre — overlap is brief and partial. If testing
   shows a clash, nudge the haul label to `offset_top = 78-84` (one line lower) so the cost indicator
   has clean air above it. Default to `70`; bump if RG1 verify shows a clash. **Not Director-level.**

2. **Label/icon prefix — keep "Holding:", or switch to a money glyph / "$"?** Today the text is
   `tr("HUD_HOLDING")` → "Holding: N" (a textual prefix = the redundant non-colour channel, good for
   colourblind-safety). The breakdown calls it the "money readout." **Recommendation:** keep the
   existing `tr("HUD_HOLDING")` string verbatim for L3 (it is a layout-only bug-fix; changing the
   wording or adding a "$"/coin glyph is a separate content/localization decision and would touch
   `hud_strings.csv`). If the Director wants a "$" or a coin icon prefix to read as *money* specifically
   (vs generic "holding"), that is a **small Director taste call** — flag it, do **not** bundle it into
   the layout fix. **Flag for Director (taste, optional, do-not-assume).**

3. **Does anything else compete for the top-right band below the timer?** Audited
   `decision_hud.tscn`: the only other node anchored top-right is `ClockTopRight` (the timer, y 16-64)
   and the zero-height `CostIndicatorAnchor` (y=70, transient spawns). `QuotaLabel`
   (`decision_hud.tscn:81-101`) is **bottom-right** (`anchors_preset = 3`, y `-44…-16`) — no conflict.
   `DepthLabel` (lines 64-79) is **bottom-left** — no conflict. So at y=70 in the right band the haul
   label is alone (modulo the transient cost indicator, Q1). **Forward-looking:** M1.5's L1 (throw)
   and L2 (pursuer) add no top-right HUD per the breakdown; L1's highlight selector lives on the
   inventory panel. **No competition. Resolvable now.**

4. **Theme / font concern.** The label keeps `font_size = 22`, `outline_size = 5`, white-on-black —
   the largest HUD treatment (the legibility layer). At 22px, "Holding: 99999" right-aligned in a
   212px band: rough width at 22px ≈ 13-15px/char × ~13 chars ≈ 170-195px — fits the 212px band, but
   a very large haul ("Holding: 999999"+) could clip the left. **Recommendation (ui self-resolve):**
   right-alignment + `grow_horizontal = 0` means it grows *leftward* into open screen space, so clipping
   is unlikely at realistic greybox haul values; if RG1 verify shows clipping at extreme values, either
   widen the band (`offset_left = -260`, matching `QuotaLabel`'s -260) or drop to `font_size = 20`
   (still legible, matches `DepthLabel`). Default: keep 22px / -228 band. **Not Director-level unless
   the widened band crowds the timer.**

5. **Should the haul label also be right-aligned to the *same digit column* as the clock's "Ns"?**
   Both end at `offset_right = -16` and both use `horizontal_alignment = 2`, so their right edges align
   by construction. **Resolved by the proposed offsets — no action.**

6. **Does the urgency pulse still read in the new position?** The pulse (`_process`, lines 145-151)
   alpha-pulses the haul label under the urgency clock fraction — placing the label *directly under*
   the clock bar actually *improves* this (the pulsing "what you'd walk away with" number now sits
   right beside the draining timer that triggers it). **Improvement, not a risk. No action.**

---

### Summary of recommendation
A **single-node, layout-only** edit to `HaulValueLabel` in `decision_hud.tscn`: re-anchor top-left →
top-right (`anchors_preset 0→1`, `anchor_left/right = 1.0`), move into the timer's x-band
(`offset_left -228`, `offset_right -16`), tuck under the timer (`offset_top 70`, `offset_bottom 98`),
grow leftward (`grow_horizontal = 0`), right-align text (`horizontal_alignment = 2`). Preserve the
node name, `unique_name_in_owner`, and all theme/font overrides (the legibility layer). **No `.gd`
change, no string change, no knob, no fingerprint impact.** Only items 1 (cost-indicator overlap, ui
self-resolves) and 2 (optional money glyph/"$" prefix — **Director taste**) carry any judgment; the
rest are resolved by the proposed offsets.

---

## Resolved Decisions (Phase 3)

**Resolver:** fresh-eyes pass (NOT the L3 author), 2026-06-24. Verified every offset and competitor
claim against the live `ui/hud/decision_hud.tscn`, `ui/dive_clock_meter.tscn`,
`ui/inventory/inventory_panel.tscn`, and `decision_hud.gd`'s `_refresh_haul()` / `_process` pulse.
All findings confirm the author's design; the offsets are **frozen** as proposed.

### Verification (against real code)
- **`HaulValueLabel` as-built** (`decision_hud.tscn:20-32`): top-left, `anchors_preset = 0`, offsets
  `16 / 16 / 256 / 44`, **no `horizontal_alignment`** → left-aligned. Matches the doc exactly. ✓
- **Timer band x-range** is real and consistent: `ClockTopRight` (`:34-44`) and the `dive_clock_meter`
  ProgressBar (`dive_clock_meter.tscn:16-25`) both occupy `offset_left = -228 … offset_right = -16`,
  both `offset_top = 16`. The meter bar ends y≈40; the in-HUD clock VBox (bar 22px + 2px sep + 16px
  label) ends y≈64. ✓ So "below the timer" = the `[-228, -16]` band at `offset_top ≈ 70`, clear of both.
- **`CostIndicatorAnchor`** (`:170-181`) is the existing y=70 "below-timer" baseline in the identical
  band. ✓ Adopting `offset_top = 70` aligns the haul label to an established anchor.
- **No competitor for the top-right band below the timer** (Open Question 3, confirmed independently):
  - `QuotaLabel` (`:81-101`) is **bottom-right** (`anchors_preset = 3`, y `-44…-16`) — no conflict. ✓
  - `DepthLabel` (`:64-79`) is **bottom-left** — no conflict. ✓
  - `ExposureReadout` (`:103-153`) is **top-LEFT** (`offset_left = 16`, y 52→116) — it does NOT enter
    the right band; no conflict. ✓ (Additional node the author did not individually clear; verified clear.)
  - The only other top-right occupant is the transient `CostIndicatorAnchor` (Open Question 1).
- **`_refresh_haul()` is untouched and must stay untouched** (`decision_hud.gd:193-194`): it sets only
  `.text` via `tr("HUD_HOLDING")`. The `_process` urgency pulse (`:142-151`) writes only `.modulate`.
  Neither reads `anchors`/`offsets`/`horizontal_alignment`. ✓ **CONFIRMED: L3 is a pure `.tscn` edit;
  `_refresh_haul()` and the pulse code stay byte-for-byte unchanged.** `unique_name_in_owner = true` +
  node name `HaulValueLabel` preserved so `%HaulValueLabel` (`:88` `@onready`) keeps resolving.

### Frozen offsets for `HaulValueLabel` (decision_hud.tscn:20-32) — LOCKED
| property | from | **to (frozen)** |
|---|---|---|
| `anchors_preset` | `0` | **`1`** (top-right) |
| `anchor_left` | (0.0 implicit) | **`1.0`** |
| `anchor_right` | (0.0 implicit) | **`1.0`** |
| `offset_left` | `16.0` | **`-228.0`** |
| `offset_top` | `16.0` | **`70.0`** |
| `offset_right` | `256.0` | **`-16.0`** |
| `offset_bottom` | `44.0` | **`98.0`** |
| `grow_horizontal` | (2 default) | **`0`** (grow left) |
| `horizontal_alignment` | (unset → LEFT) | **`2`** (RIGHT) |
| theme/font overrides | white/black/outline 5/size 22 | **UNCHANGED** (legibility layer preserved) |

- **Open Question 1 (cost-indicator overlap at y=70):** RESOLVED — ship `offset_top = 70` as the
  default; the cost indicator rises-and-fades quickly off y=70 and renders near band-centre while the
  haul label is right-edge-docked, so overlap is brief and partial. If RG1 verify shows a clash, nudge
  to `78-84`. Technical/layout call, no Director input needed.
- **Open Questions 3, 4, 5, 6:** RESOLVED on technical merit per the doc (no competitor; 212px band fits
  realistic greybox haul values with leftward growth; right edges align by construction; the pulse reads
  better under the timer). No action.

### Needs Director review
- **Optional money glyph / "$" prefix on the haul label (Open Question 2).** The readout text is
  `tr("HUD_HOLDING")` → "Holding: N". Whether to switch to a "$"/coin-glyph "money" presentation is a
  content/taste call that would touch `ui/hud/hud_strings.csv`. **Recommendation: DEFER out of L3** — L3
  is a layout-only bug-fix; keep the existing `tr("HUD_HOLDING")` string verbatim. Surface the glyph
  decision separately if the Director wants the readout to read as *money* specifically. Do NOT bundle
  it into the reposition.
