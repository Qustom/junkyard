# M4 — Debug-menu rework (P-key + tabs)

**Milestone:** M1.6 (Surface & Staging), Wave 2 (Surface scenes — parallel worktrees).
**Role:** ui-ux-designer (UX/IA + in-engine `Control` reorg) · general-purpose (the `_unhandled_input`
P-toggle wiring + mount-point coordination with M0's router).
**Type:** **Pure UI re-organisation** of the existing pre-run config rail (`ui/config/config_menu.*`
+ its CSV) into a tabbed, P-key overlay. **NOT knob-gated, touches no generation, adds/removes/renames
NO knob** → the all-off `RunConfig` fingerprint (`e943ac9c8bc1`) is untouched and the **89-knob
coverage holds** (`has_full_coverage()` + the `test_run_config.gd` / `test_config_menu.gd` count
assertions stay green — this is the load-bearing constraint).
**BlockedBy:** **M0** only (reads the `debug_menu_toggle`=`P` input action M0 declares in
`project.godot` `[input]`, and mounts at the router's all-states overlay seam M0 defines). File-disjoint
from M1 (`scenes/menu/*`), M2 (`scenes/hub/*` + `main_game.*`), M3 (Shop). Runs parallel with M1/M2 in
Wave 2 (breakdown §4/§5).
**Definition of done:** the config/debug menu no longer occupies the first screen; **P** (`debug_menu_toggle`)
shows/hides it as an overlay available in **Menu / Hub / Dive**; its single scroll is restructured into a
**`TabContainer`** grouping sections by theme, with the `r4_` **Vision/fog rows pulled out of the
maze-branch section into their own Vision section** (Director-named requirement) **without renaming any
`r4_` field**; `has_full_coverage()` returns true and both 89-count tests pass; every visible tab/section
string goes through `tr()` against `ui/config/config_strings.csv`. Greybox only (default theme) — a human
owns the visual pass.

---

## (a) Research on the premise

### Why move the debug menu off the first screen, and into a P-key tabbed overlay

Today the config rail **is** the first screen. `scenes/game/main_game.tscn:42-83` mounts a `MainMenu`
`CanvasLayer` whose two visible halves are the greybox title/Start column (`MainMenu/Center/VBox`,
lines 55-83) and the **`ConfigMenu` rail bolted to its left** (`MainMenu/ConfigMenu`, line 52, the
`ui/config/config_menu.tscn` instance, anchored as a 360-px left rail per `config_menu.tscn:5-11`). A
player boots straight into a 47-row debug harness with a Start button — the exact "knob menu in everyone's
face on the first screen" the M1.6 breakdown §1 calls out as the thing this iteration removes.

M1.6's surface re-architecture (breakdown §2/§3) makes `main_game.tscn` **dive-only** (M2 strips the
`MainMenu`/config rail + Start button) and routes the app through **Main Menu → Hub ⇄ Dive** (M1/M2). The
config rail has no first-screen home any more — but the **Director still needs every knob reachable in any
app state** to keep running labelled experiments. M4's answer (breakdown §3 M4 row, §7 last risk): re-home
the rail as a **P-key overlay** mounted where M0's router puts an all-states overlay (a `CanvasLayer` on an
autoload / the persistent root `App` node — M0 resolves the exact mount; breakdown §7 router risk), toggled
by the **`debug_menu_toggle`** action. M0 declares that action (`= P`) and owns the `project.godot`
`[input]` edit for the whole milestone (breakdown §3 M0 row, §4); M4 only **reads** it.

The second half is **readability/IA**: 47 rows across 15 sections in one vertical scroll (`SECTIONS`,
`config_menu.gd:59-78`) is a wall. The Director groups them by *theme* in a `TabContainer` so a sweep
("turn the hazards on") is one tab, not a scroll-hunt. This is the playbook's job — information
architecture, behaviour, readability, flow (Playbook 04 lane) — and a pure reorg: **no knob added,
removed, or renamed**, so the experiment surface is identical, just navigable.

### The current `SECTIONS` / `MANIFEST` structure (the thing being regrouped)

`config_menu.gd` builds the rail from two hand-authored constants, both **keyed by section prefix**:

- **`SECTIONS`** (`config_menu.gd:59-78`) — 15 descriptors, each `{prefix, title_key, gloss_key, master,
  collapsible}`. Prefixes in declared order: `""` (Meta) · `r1_` · `r2_` · `r3_` · `r4_` · `lvl_` ·
  `quota_` · `cam_` · `timer_` · `hpp_` · `hbomb_` · `hspike_` · `exit_` · `throw_`. Each non-Meta section
  carries a master `*_enabled` toggle rendered in its header (`_build_section`, `config_menu.gd:420-474`).
- **`MANIFEST`** (`config_menu.gd:84-158`) — `prefix -> ordered [field names]`. The master field appears
  in the list but is rendered in the header and skipped in the body (`config_menu.gd:471-474`). Each body
  field becomes one bound row via `_build_row` (`config_menu.gd:481-509`) → recorded in `_rows[field]`.

`_build_ui` (`config_menu.gd:356-383`) builds one outer `PanelContainer` → `VBoxContainer` → summary bar
→ a single `ScrollContainer` whose `_scroll_vbox` receives **one `_build_section(sec)` call per entry in
`SECTIONS`**. That `for sec in SECTIONS` loop (line 382-383) is the single seam M4 restructures into tabs.

### The `r4_` maze/vision MIX (the Director-named split)

The `r4_` section is the one section that **mixes two unrelated concerns** in one `MANIFEST` entry
(`config_menu.gd:106-109`):

```gdscript
"r4_": [
    "r4_enabled", "r4_branch_chance_base", "r4_branch_per_depth", "r4_max_branch_depth",     # maze-branch
    "r4_vision_radius", "r4_vision_tighten_per_depth", "r4_fog_enabled", "r4_lost_proxy_threshold",  # vision/fog
],
```

The first four (incl. the master) are **maze-branch layout** knobs; the last four are **vision/fog/lost**
knobs. The Director wants these in **separate tabs/sections** — maze-branch under **Level Generation**, the
vision four pulled into their **own Vision section**. Crucially: the underlying fields keep their `r4_`
names (they are read all over the engine — `vision_fog.tscn`, `LostProxy`, the generator's branch reader;
the all-off control + `make_default_play_preset()` set them by name; `test_run_config.gd:87-88` /
`:152-167` / `:209-215` assert them by name). **Renaming any `r4_` field is out of scope and would break
the determinism baseline + the preset + the trap detector.** M4 splits them **visually only**.

### The 89-knob coverage mechanism M4 MUST preserve

Coverage is keyed off **bound-field names**, not section structure. `has_full_coverage()`
(`config_menu.gd:310-333`) builds a `bound` set = **every key in `_rows`** (one entry per built row,
`config_menu.gd:516`/`525`/`537`/`586`/`600`/`628`) **plus every `SECTIONS[i].master`** (the header
CheckButtons live outside `_rows`, added at line 314-316), and asserts `bound == _exported_config_fields()`
(the 89 RunConfig `@export` fields, derived by property-list reflection at `config_menu.gd:342-351`).
`_assert_full_coverage()` (`:336-338`) fires this at build time (`_ready`, `:276`).

The two count tests:
- `test_config_menu.gd:39-59` — calls `menu.has_full_coverage()`, asserts `exported.size() == 89`
  (`:53`), and checks **every exported field is in `menu._rows.keys()`** (`:56-59`).
- `test_run_config.gd:74-120` — asserts the schema's `to_flat_dict()` contains all 89 named knobs.

**Therefore coverage is invariant to how sections are grouped into tabs.** What it requires is exactly:
1. every one of the 89 `@export` fields still gets a bound control in `_rows` (or is a registered master);
2. every section master still appears in `SECTIONS[*].master` so `has_full_coverage` adds it to `bound`;
3. no `_rows` key references a field that does not exist (the `extra` check, `:330-332`).

A regroup into tabs touches **none** of those three as long as `_build_row` is still called once per field
and `SECTIONS` still lists every master. The split of `r4_` is the only structurally interesting move, and
(b) below shows two ways to do it that keep all three invariants — the recommended one needs **no new
master and no field rename**.

### How the menu is mounted today vs the M0 P-overlay target

| | Today (M1.5) | M1.6 target (M4 + M0) |
|---|---|---|
| Mount | child of `MainMenu` `CanvasLayer` in `main_game.tscn:52`, a 360-px left rail (`config_menu.tscn:5-11`) | overlay on M0's all-states seam (a `CanvasLayer` on an autoload / the persistent root `App`) |
| Visibility | always visible on the first screen | hidden by default; **P** toggles it in Menu/Hub/Dive |
| Entry | `main_game._ready` resolves `%ConfigMenu` (`main_game.gd:75`); `start_new_run` reads `apply_and_get_config()` (`main_game.gd:223`) | M2's dive-only `main_game` reads the overlay's `apply_and_get_config()` at run start (see OQ-5: live vs next-Start) |
| Coverage assert | runs in `_ready` (`config_menu.gd:276`) | unchanged — still runs in `_ready` wherever the overlay is instanced |

M4 does **not** own the router or the mount node (that's M0). M4 owns the `ConfigMenu` `Control`'s internal
reorg + the P-toggle behaviour on the `ConfigMenu` node itself, and **coordinates** with M0 on the seam:
the overlay must be instanced exactly **once** under a persistent node so its `apply_and_get_config()` is a
stable single instance the dive reads (mirrors how `main_game.gd:223` reads one rail today).

---

## (b) Pseudocode

### B1. Proposed tab taxonomy (full table)

Seven tabs. The `r4_` section is split: its **maze-branch** rows join **Level Generation**; its
**vision/fog** rows become a **new Vision section** (Director requirement). No knob moves between *fields*
— only between *visual sections*.

| Tab (CSV title key) | Sections / prefixes it contains | Knobs (rows + masters) | Notes |
|---|---|---|---|
| **Hazards** (`CFG_TAB_HAZARDS`) | `r1_` · `hpp_` · `hbomb_` · `hspike_` | 19 (r1) + 6 (hpp) + 8 (hbomb) + 7 (hspike) | the pursuer + the three M1.4 hazard types, incl. their L5 `*_kills` toggles |
| **Level Generation** (`CFG_TAB_LEVELGEN`) | `lvl_` · **`r4_` maze-branch only** (`r4_enabled`, `r4_branch_chance_base`, `r4_branch_per_depth`, `r4_max_branch_depth`) | 6 (lvl) + 4 (r4 maze incl. master) | the `r4_` **master lives here** (it gates both maze and vision; see OQ-2) |
| **Vision** (`CFG_TAB_VISION`) | **`r4_` vision/fog only** (`r4_vision_radius`, `r4_vision_tighten_per_depth`, `r4_fog_enabled`, `r4_lost_proxy_threshold`) | 4 (no own master — gated by `r4_enabled` in Level Gen) | the Director-named split; **no field rename**, sub-grouped out of the `r4_` MANIFEST entry |
| **Timer & Quota** (`CFG_TAB_TIMEQUOTA`) | `timer_` · `quota_` | 4 (timer) + 5 (quota) | dive length / warning + the per-run money quota |
| **Exposure & Return** (`CFG_TAB_EXPRETURN`) | `r2_` · `r3_` | 6 (r2) + 8 (r3) | the two cost-axis oppositions |
| **Throw & Camera** (`CFG_TAB_THROWCAM`) | `throw_` · `cam_` · `exit_` | 3 (throw) + 3 (cam) + 5 (exit) | player-facing dive tuning that fits no big bucket |
| **Meta** (`CFG_TAB_META`) | `""` (Meta) | 2 (`seed_override`, `build_tag`) | seed/build identity; the summary bar + Reset stay docked above the tabs (see B4) |

Sum check: 19+6+8+7 + 6+4 + 4 + 4+5 + 6+8 + 3+3+5 + 2 = **90 rows incl. all masters**. Masters counted:
r1,hpp,hbomb,hspike,lvl,r4,timer,quota,r2,r3,throw,cam,exit = 13 masters; Meta has none. The 89-field set
= 89 `@export` fields; the +1 here is because `lvl_`/`r4_` etc. each list their master in `MANIFEST` (the
master is one of the 89 fields, rendered in the header — it is **not** double-counted in `_rows`, only in
the per-section field list). The authoritative count stays **89 exported fields → 89 bound** (every field
appears exactly once across the tabs). The split moves **zero** fields out of the 89; it only relocates 4
existing `r4_*` rows from the maze section's body into a Vision section's body.

### B2. The `TABS` descriptor (new) — tab → ordered section keys

Add ONE new constant; leave `SECTIONS` and `MANIFEST` **as-is** except for the `r4_` split (B3). A tab is a
list of *section keys* (a section key is a `SECTIONS` prefix, or the new pseudo-prefix `r4_vision_` for the
split-out Vision rows — see B3):

```gdscript
## M4 (M1.6): tab taxonomy. Each tab is a title-key + an ordered list of SECTION KEYS to
## render inside its scroll. A section key is a SECTIONS prefix, EXCEPT "r4_vision_" which
## is the split-out Vision sub-group (its rows are the r4_ vision/fog fields, NOT renamed).
## Pure presentation: coverage is keyed off _rows/_section masters, never off this table.
const TABS := [
    {"title_key": "CFG_TAB_HAZARDS",   "sections": ["r1_", "hpp_", "hbomb_", "hspike_"]},
    {"title_key": "CFG_TAB_LEVELGEN",  "sections": ["lvl_", "r4_"]},          # r4_ here renders MAZE rows only (B3)
    {"title_key": "CFG_TAB_VISION",    "sections": ["r4_vision_"]},           # split-out vision rows
    {"title_key": "CFG_TAB_TIMEQUOTA", "sections": ["timer_", "quota_"]},
    {"title_key": "CFG_TAB_EXPRETURN", "sections": ["r2_", "r3_"]},
    {"title_key": "CFG_TAB_THROWCAM",  "sections": ["throw_", "cam_", "exit_"]},
    {"title_key": "CFG_TAB_META",      "sections": [""]},
]
```

### B3. The `r4_` split WITHOUT a field rename or a coverage break

The `r4_` MANIFEST entry today is one list of 8 (`config_menu.gd:106-109`). Split the **body field lists**
(not the fields) into maze vs vision. Two viable shapes; **recommend Option A** (a parallel pseudo-section)
as it needs no new master and keeps the master gating both halves:

**Option A (RECOMMENDED) — a render-time sub-list, no new SECTIONS entry, no new master.**
Keep `SECTIONS`'s `r4_` descriptor unchanged (master `r4_enabled`, collapsible). Trim the **`r4_`
MANIFEST entry to the maze rows only**, and add a **separate constant** holding the vision rows:

```gdscript
# MANIFEST (config_menu.gd) — r4_ now lists MAZE rows only (master + 3 branch knobs):
"r4_": ["r4_enabled", "r4_branch_chance_base", "r4_branch_per_depth", "r4_max_branch_depth"],

# NEW constant — the vision/fog rows, split out for the Vision tab. NOT renamed: these are
# the SAME r4_vision_radius / r4_vision_tighten_per_depth / r4_fog_enabled / r4_lost_proxy_threshold
# fields, just rendered under a Vision header instead of inside the maze section's body.
const R4_VISION_FIELDS := [
    "r4_vision_radius", "r4_vision_tighten_per_depth", "r4_fog_enabled", "r4_lost_proxy_threshold",
]
```

`_build_section` is split so a "section key" can be either a real `SECTIONS` prefix or the `"r4_vision_"`
pseudo-key. For the pseudo-key it renders a **header with NO master** (a plain Vision title + gloss) and a
body of `R4_VISION_FIELDS` rows. **Every `r4_*` field still gets exactly one `_build_row` → one `_rows`
entry**, and `r4_enabled` is still a `SECTIONS` master → coverage's `bound` set is byte-identical to today.
The chip/summary/dim plumbing keyed on the `r4_` prefix (`_section_chips`, `_section_bodies`,
`_refresh_section_chip`, `_set_body_dimmed`, `_prefix_of`) stays keyed on `"r4_"`; the Vision sub-group
registers under a distinct body key (`"r4_vision_"`) for its own dimming, but **dims off the same
`r4_enabled` master** (so toggling R4 off in Level Gen dims both the maze body and the Vision body — see
the `_on_master_toggled` note below).

```gdscript
# _build_ui: replace the single ScrollContainer + `for sec in SECTIONS` with a TabContainer.
func _build_ui() -> void:
    var panel := PanelContainer.new(); ...
    var outer := VBoxContainer.new(); ...
    _build_summary_bar(outer)                      # summary line + Reset STAY docked above the tabs (B4)

    var tabs := TabContainer.new()                 # was: a single ScrollContainer
    tabs.name = "Tabs"
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    outer.add_child(tabs)
    _tab_container = tabs

    for tab in TABS:
        var page := ScrollContainer.new()          # one scroll PER tab (long tabs still scroll)
        page.name = tr(tab.title_key)              # TabContainer uses child name as the tab label...
        page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        var col := VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        page.add_child(col); tabs.add_child(page)
        tabs.set_tab_title(tabs.get_tab_count() - 1, tr(tab.title_key))   # ...explicit, tr()-driven label
        for section_key in tab.sections:
            _build_section_into(col, section_key)  # renders a real prefix OR the "r4_vision_" pseudo-section

# _build_section_into(parent, section_key): factored from today's _build_section. For a real
# prefix it looks up the SECTIONS descriptor + MANIFEST[prefix] (unchanged header/master/body).
# For "r4_vision_" it builds a master-less header (title CFG_SEC_R4_VISION, gloss CFG_GLOSS_R4_VISION)
# and a body of R4_VISION_FIELDS, registering _section_bodies["r4_vision_"] for dimming.
```

**Option B (NOT recommended) — a second real `SECTIONS` entry `r4_vision_` with a `master: ""`.** This
would need `_prefix_of` and the chip code to treat `r4_vision_` as a Meta-like master-less section, and
risks the `_exported_config_fields` reflection seeing a prefix with no `*_enabled` field (fine, since
`master: ""` adds nothing to `bound`) — but it muddies `SECTIONS`, which the coverage masters loop iterates
(`config_menu.gd:314-316`). Option A keeps `SECTIONS` semantically "one real opposition section per entry"
and isolates the split to the render layer. **Recommend A; flag B as the fallback if Phase 3 prefers a
single uniform section path.** Either keeps coverage at 89 (the OQ-1 resolution must pick one).

### B4. Summary bar, Reset, and the trap warning stay above the tabs

`_build_summary_bar` (`config_menu.gd:386-417`) — the headline RUN scan line, the BUG6 trap-warn line, and
the **Reset** button (the highest-contrast band-independent legibility layer, playbook rule) — is built
**once, docked above the `TabContainer`** (not inside any tab), so "what will this run do" + Reset are
answerable from any tab. The per-section ON/OFF chips + per-row live values are unchanged inside each tab.
This preserves the "three redundant readouts" contract (`config_menu.gd` header §) across the reorg.

### B5. The P-toggle overlay wiring (on the `ConfigMenu` node)

The `ConfigMenu` `Control` reads the M0 action and shows/hides itself. It is mounted **once** under M0's
all-states overlay seam (M0 owns the mount node; M4 owns this behaviour):

```gdscript
# config_menu.gd additions (M4): the overlay shows/hides on debug_menu_toggle; starts HIDDEN.
func _ready() -> void:
    _cfg = _make_boot_config()
    _build_ui()
    _assert_full_coverage()
    _refresh_all()
    visible = false                                # M4: overlay is hidden until P (was always-on rail)
    process_mode = Node.PROCESS_MODE_ALWAYS        # so P still toggles it while the dive tree is paused

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"debug_menu_toggle"):  # M0's P action
        _toggle_overlay()
        get_viewport().set_input_as_handled()

func _toggle_overlay() -> void:
    visible = not visible
    # OQ-3: pause-in-dive. If the current app state is the dive, pause the tree while open so
    # the world freezes behind the debug menu (mirrors SellScreen's paused-overlay idiom);
    # in Menu/Hub pausing is a no-op (no live world). M0's router exposes the current state.
    if _pauses_dive():
        get_tree().paused = visible
```

`debug_menu_toggle` is declared by M0; M4 asserts its presence (a soft `push_warning` if
`InputMap.has_action(&"debug_menu_toggle")` is false, so a mis-merge fails loud, not silent). When the
overlay is hidden, `apply_and_get_config()` still returns the live working `_cfg` — the dive reads it at run
start exactly as `main_game.gd:223` does today (OQ-5 decides live-apply vs next-Start).

### B6. New CSV title keys (added to `ui/config/config_strings.csv`)

Append the **tab titles** + the **Vision split section title/gloss**. No existing key is changed; no
`CFG_FIELD_*` / `CFG_SEC_*` / `CFG_GLOSS_*` key is removed (the per-field + per-section strings are reused
verbatim — the rows themselves don't change, only their grouping):

```
CFG_TAB_HAZARDS,Hazards
CFG_TAB_LEVELGEN,Level Generation
CFG_TAB_VISION,Vision
CFG_TAB_TIMEQUOTA,Timer & Quota
CFG_TAB_EXPRETURN,Exposure & Return
CFG_TAB_THROWCAM,Throw & Camera
CFG_TAB_META,Meta
CFG_SEC_R4_VISION,R4 · Vision / Fog
CFG_GLOSS_R4_VISION,limited sight + fog + getting-lost proxy (the navigation-pressure half of R4)
```

The existing `CFG_SEC_R4` gloss should be re-narrowed to the maze half only (it currently reads "branching
layout + limited vision; getting lost", `config_strings.csv:17`) → e.g. `branching layout; how the maze
forks with depth` — a one-line **gloss text edit, not a key change** (flagged in OQ-4; trivial, but it is a
string edit so it's called out, not assumed). The `CFG_SEC_R4` **title** ("R4 · Maze / Navigation") may
also want to read "R4 · Maze / Branching" since Vision left it; OQ-4.

---

## (c) Open Questions

> Phase 3 fresh-eyes resolves these. The 89-coverage-preserving ones (OQ-1) are technical and must be
> locked before build; the taxonomy/UX ones (OQ-2, OQ-3, OQ-5, OQ-6) carry mild Director taste.

1. **How to split `r4_` vision from maze without breaking the prefix-keyed `MANIFEST`/coverage —
   Option A (render-time sub-list `R4_VISION_FIELDS` + `"r4_vision_"` pseudo-section, no new master) vs
   Option B (a second real `SECTIONS` entry with `master: ""`)?** Both keep 89 (every `r4_*` field still
   gets one `_rows` row; `r4_enabled` stays the one `SECTIONS` master). **Recommend A** — it isolates the
   split to the render layer, keeps `SECTIONS` "one opposition section per entry", and avoids a master-less
   pseudo-prefix leaking into the `has_full_coverage` masters loop (`config_menu.gd:314-316`). **Decision
   needed before build** (it shapes `_build_section`'s refactor). *Technical — Phase 3 resolves; flag to
   Director only if B is chosen for some UX reason.*

2. **Where does the `r4_enabled` master live, and does dimming follow it across the split?** The single
   `r4_enabled` toggle gates **both** maze and vision in the engine. Proposed: the master + its CheckButton
   render in the **Level Generation** tab (with the maze rows); the **Vision** section is master-less and
   **dims off the same `r4_enabled`** (so turning R4 off in Level Gen visibly dims the Vision tab's body
   too). `_on_master_toggled` (`config_menu.gd:700-705`) must therefore dim **both** `_section_bodies["r4_"]`
   and `_section_bodies["r4_vision_"]` when `prefix == "r4_"`. **Alternative:** show a read-only "R4 is OFF
   — enable it in Level Generation" note in the Vision tab instead of a silent dim. **Recommend: dim both
   bodies off `r4_enabled` + a small "(gated by R4 master, see Level Generation)" gloss line on the Vision
   header**, so the cross-tab dependency is legible (non-colour redundant cue). *UX taste — Phase 3
   recommends, Director may weigh in.*

3. **Does the P-overlay pause the dive while open?** Recommend **yes in-dive, no-op in Menu/Hub** (B5):
   freeze the world behind the debug menu (mirrors `SellScreen`'s paused-overlay idiom; the player isn't
   fighting hazards while tweaking knobs) but pausing is meaningless on the Menu/Hub (no live dive). Needs
   M0's router to expose "am I in the dive" (`_pauses_dive()`). **Sub-question:** if a dive is paused by the
   debug menu, does the `DiveClock` (K4 timer) also pause? It should — `get_tree().paused = true` halts its
   `_process`/timer if it isn't `PROCESS_MODE_ALWAYS`; confirm the clock is pausable so debug-menu time
   doesn't burn the dive timer. *Recommend pause-in-dive; confirm clock pauses with the tree. Phase 3 +
   a quick M0 coordination check.*

4. **Does the `CFG_SEC_R4` title/gloss text get re-narrowed now that Vision left it?** The current title
   "R4 · Maze / Navigation" + gloss "branching layout + limited vision; getting lost"
   (`config_strings.csv:13,17`) both still mention vision, which now lives in its own tab. Recommend a
   one-line gloss edit (maze-only wording) + optionally retitle to "R4 · Maze / Branching". This is a
   **string-only CSV edit** (no key add/remove), so it's flagged not assumed. *Low-stakes; Phase 3 can
   resolve, or leave verbatim if the Director prefers minimal CSV churn.*

5. **Does the overlay apply config live (mid-dive) or only on next Start?** Today the rail is read once at
   `start_new_run` (`main_game.gd:223`) — config changes take effect on the **next** dive. With a P-overlay
   openable **mid-dive**, do edits hot-apply to the running dive (most knobs can't — generation already
   happened) or only stage for the next dive? **Recommend: next-Start semantics unchanged** — the overlay
   mutates `_cfg`; `apply_and_get_config()` is read at the next dive launch (M2's dive-only `main_game`
   reading the overlay instance). A small "changes apply on next dive" note on the overlay avoids confusion.
   Mid-dive live-apply is out of scope (would need per-knob re-application; most knobs are generation-time).
   *Recommend next-Start; mild Director confirm that mid-dive editing without live effect is acceptable for
   a debug tool (it is — it's a debug menu).*

6. **Tab set + section→tab assignment (the exact taxonomy of B1).** Proposed seven tabs (Hazards / Level
   Gen / Vision / Timer & Quota / Exposure & Return / Throw & Camera / Meta). Open sub-calls: (a) is
   **`exit_`** best in "Throw & Camera" or in "Level Generation" (exits are a layout concern too)? (b)
   should **Timer & Quota** and **Exposure & Return** merge into one "Run Rules" tab to cut tab count to 6?
   (c) tab order (recommend most-swept first: Hazards, Level Gen, Vision). Recommend the B1 set as-is for a
   first cut (clean theme buckets, ≤8 tabs, no tab over ~30 rows). *UX taste — Phase 3 recommends; the
   Director can re-bucket since it's pure presentation with zero coverage impact.*

7. **Tab persistence across opens — does the overlay remember the last-viewed tab within a session?**
   Recommend the `TabContainer` keep its `current_tab` across hide/show within one session (don't reset to
   tab 0 on each P-open) — a sweeping Director re-opens to where they were. Persisting it across *app
   restarts* (a `SaveManager` field) is **out of scope** (it's a debug-tool convenience, not meta-state;
   adding a save field would risk a schema touch M1.6 explicitly avoids). *Recommend in-session memory only,
   no save field. Phase 3 resolves; trivial.*

8. **Mount-point coordination with M0 (single instance).** The overlay must be instanced **once** under
   M0's all-states seam so `apply_and_get_config()` is one stable instance the dive reads (today
   `main_game.gd:223` reads one `%ConfigMenu`). If M0's router tears down + rebuilds scenes per transition,
   the overlay must live on the **persistent** side (autoload `CanvasLayer` / root `App`), not inside any
   torn-down scene, or the working `_cfg` resets every transition. **This is an M0/M4 seam contract to
   confirm in Phase 3** (breakdown §7 router risk: "where does the P-key debug overlay live so it's
   available in all three states"). *Coordination call — confirm the overlay is on the persistent mount.*

---

## Resolved Decisions (Phase 3)

*(pending — filled by a fresh-eyes resolver after Phase 2, then Director-ratified per the four-phase
process. The load-bearing item to lock is OQ-1: the `r4_` split shape that keeps `has_full_coverage()` +
both 89-count tests green. OQ-2/3/5/6 carry mild Director taste; OQ-8 is an M0 seam confirmation.)*
