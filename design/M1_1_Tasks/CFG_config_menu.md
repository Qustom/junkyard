# CFG — Pre-run Config menu (M1.1)

**Task id:** CFG · **Milestone:** M1.1 · **Wave:** 1 (Foundations) · **dependsOn:** R0
**Assignee roles:** `ui-ux-designer` (Control layout / readability — this doc) + `general-purpose` (binding to `RunConfig`)
**Companion docs:** `M1.1_Breakdown.md` §3–§4 (CFG entry), §6 (wave order) · `data/run_config/run_config.gd` (the R0 schema this surfaces) · `M1_Tasks/M1_As_Built.md` §"M1 UI / HUD & loop wiring" · `worklogs/2026-06-19-R0-programmer.md` (handoff)

> **This is a DESIGN doc.** It specifies layout, binding, and pseudocode for the implementing agents. It writes no game code, scenes, or `.tres`. The pseudocode is illustrative, not a drop-in.

---

## 1. Goal & design intent

**One line:** A greybox `Control` panel next to the existing Start Run menu that lets the Director toggle and tune **every** R1–R4 opposition knob in `RunConfig` before pressing Start, then hands the built config to the run.

**Expansion.** M1.1's whole premise is that the Director *sweeps* opposition values across playtest runs to find where the push-vs-extract tension lives — the knobs ship **configurable, not balanced** (Breakdown §2). The Config menu is the instrument that makes each run a *labelled experiment*: pick a config, run it, read the telemetry, adjust, repeat. Because the Director tunes here **every single run**, the panel must be fast to read and fast to change:

- **Readability matters** — "which opposition am I looking at," "what is this run going to do," and "what are the current values" must all be answerable at a glance, because this screen is on the critical path of every test run, many times per session.
- **Greybox** — default theme, plain `Control` containers, no authored art (the M1 greybox norm, `M1_As_Built.md`). A human owns any later visual pass; this doc owns UX/IA/behaviour only.
- **One source of truth** — the menu surfaces **100% of `RunConfig`'s `@export` fields and nothing else**. No opposition value is hardcoded or hidden in the menu; the menu only ever reads/writes the R0 schema. When R1–R4 finalise their enum meanings, the menu inherits them for free.
- **It only configures the *next* run.** It does not restart a live dive. The existing Start Run flow (`MainGame.start_new_run`) still owns run start; CFG just changes the config that flow stages.

---

## 2. UX / layout design

### 2.1 Placement

The menu lives **on the existing Main Menu screen**, beside the Start Run controls — it is not a separate scene route. `main_game.tscn` currently centres a `VBox` (title, hint, `StartButton`) inside `MainMenu/Center`. CFG adds a **config panel to the side of that centred column** so the Director sees "title + Start" and "the config for this run" together, and Start is always one click away from the knobs.

Concretely: the `MainMenu` `CanvasLayer` gains a new child — an instance of the new `ConfigMenu` scene — anchored as a **left (or right) side rail** that does not overlap the centred Start column. The greybox layout is an `HSplit`-style arrangement (config rail | existing centred Start column) or a left-anchored `PanelContainer` of fixed width with the Start column keeping the remaining centre. Either reading is fine for greybox; the constraint is **both visible at once, no modal hop to reach the knobs**.

### 2.2 Structure — one collapsible section per opposition

The panel is a vertical scroll of **five sections**: `Meta`, `R1 Pursuing Hazard`, `R2 Costlier Return`, `R3 Exposure Meter`, `R4 Maze / Navigation`. These mirror the `@export_group`s in `run_config.gd` 1:1.

Each **opposition** section is a **collapsible** block whose header carries:
- A **master on/off toggle** (`CheckButton`) bound to the `r<n>_enabled` field. This is the most important control in the section — it gates whether the opposition exists at all.
- A **clear name + role tag** so "which opposition is this" is unambiguous: e.g. `R1 · Pursuing Hazard — a thing that chases you the deeper/longer you go`. The short gloss comes straight from the Breakdown §4 one-liners.
- An **at-a-glance state chip**: `ON` / `OFF`, plus (when ON) a one-line summary of the most load-bearing values (e.g. `ON · awaken@d≥3, speed 40`). This lets the Director scan all four headers without expanding them.
- A **disabled/greyed body when the master is OFF** — the per-knob rows stay visible (so the Director can pre-set values) but are visibly de-emphasised (dimmed) so it's obvious that an OFF opposition does nothing this run. This is the redundant non-colour channel for "this section is inert": dim + the `OFF` chip + the unchecked master, three cues for one state.

The `Meta` section is **not** collapsible and has **no** master toggle (it is always relevant): just `seed_override` and `build_tag`.

### 2.3 Per-knob rows

Inside a section, each knob is a labelled row: **`[ label ] [ control ] [ live value ]`**. The label is the human-readable knob name; the control is the typed editor (see §3 binding table); the live value echoes the current number so sliders are readable without dragging. Rows group visually by purpose where it helps (awaken / chase / catch for R1, etc.), but a flat list per section is acceptable for greybox.

### 2.4 Show current values at a glance

Three redundant readouts, so the Director never has to expand-and-drag to know the state of a run:
1. **Header state chip** per section (`ON/OFF` + key-value summary).
2. **Live value label** on every slider/field row.
3. A **top-of-panel run summary line** — e.g. `RUN: R1✓ R2✗ R3✓ R4✗ · seed auto` — a single scannable string of which oppositions are armed. This is the fastest "what will this run do" read and is the menu's headline.

### 2.5 Reset to M1.0 baseline (all off)

A prominent **`Reset to baseline (all off)`** button at the top of the panel. It restores **every** field to the `RunConfig` script defaults — every master OFF, every magnitude zero/neutral — which by construction reproduces the M1.0 baseline (the permanent in-build control, R0 docstring). After reset the run summary reads `R1✗ R2✗ R3✗ R4✗` and every section chip reads `OFF`. This is the one-click "give me the control config" action the re-gate depends on.

### 2.6 ASCII wireframe

```
 MainMenu (CanvasLayer)
+---------------------------------------------------------------+
| [ Config rail ]                       |                       |
| +-----------------------------------+ |                       |
| | RUN: R1[x] R2[ ] R3[x] R4[ ]      | |     THE FAR YARD      |
| |      seed auto                    | |                       |
| | [ Reset to baseline (all off) ]   | |  WASD move · E inter. |
| +-----------------------------------+ |                       |
| | Meta                              | |   +---------------+   |
| |  seed_override [ -1        ]       | |   |  START RUN     |   |
| |  build_tag     [           ]       | |   +---------------+   |
| +-----------------------------------+ |                       |
| | [x] R1 · Pursuing Hazard   ON  v  | |                       |
| |     awaken@d>=3, speed 40         | |                       |
| |   depth_threshold [---o--] 3      | |                       |
| |   linger_seconds  [-o----] 4.0    | |                       |
| |   chase_speed     [----o-] 40.0   | |                       |
| |   speed_per_depth [-o----] 2.0    | |                       |
| |   catch_radius    [--o---] 12.0   | |                       |
| |   catch_kills     [x]             | |                       |
| |   spawn_count     [--o---] 1      | |                       |
| +-----------------------------------+ |                       |
| | [ ] R2 · Costlier Return   OFF v  | |                       |
| |   mechanism     ( lengthen v )    | |   (section dimmed     |
| |   cost_magnitude[o-----] 0.0      | |    while master OFF)  |
| |   ...                             | |                       |
| +-----------------------------------+ |                       |
| | [ ] R3 · Exposure Meter    OFF v  | |  build m1-dev (corner)|
| | [ ] R4 · Maze / Navigation OFF v  | |                       |
| +-----------------------------------+ |                       |
+---------------------------------------------------------------+
```

### 2.7 Readability rules applied (UI playbook)

- **Back every colour cue with a non-colour channel.** ON/OFF is carried by the checkbox state **and** the `ON`/`OFF` text chip **and** body dimming — never colour alone. Slider state is carried by the numeric label, not just handle position.
- **Highest-contrast for the load-bearing controls.** The master toggles and the `Reset` and `Start` actions stay highest-contrast regardless of section styling — they are the band-independent legibility layer of this screen.
- **Externalise all strings.** Every label, section title, gloss, chip text, and button caption goes through `tr()` against a new `ui/config/config_strings.csv` (same pattern as `ui/hud/hud_strings.csv` / `ui/sell/sell_strings.csv`), so the menu is localisable. Knob *field names* may default to a humanised form of the `RunConfig` field name, but the **section titles and glosses are authored CSV strings**.

---

## 3. Binding design

### 3.1 The menu owns a working `RunConfig` instance

The menu holds **one** `RunConfig` it mutates as the Director edits (the *working config*). On open it is seeded from the all-off default (`res://data/run_config/run_config.tres`, duplicated so the on-disk default is never mutated). Each control writes its bound field on change; the menu reads fields to populate controls and to render the summary/chips. On Start, this working config is handed to the run.

### 3.2 Control → field map (100% coverage of `run_config.gd`)

| Section | `RunConfig` field | Type | Control | Notes |
|---|---|---|---|---|
| Meta | `seed_override` | `int` | `SpinBox` (min -1) | -1 = "auto" (MainGame's own seed policy) |
| Meta | `build_tag` | `String` | `LineEdit` | empty = Telemetry derives the build tag |
| R1 | `r1_enabled` | `bool` | `CheckButton` (master) | gates the section |
| R1 | `r1_depth_threshold` | `int` | `HSlider` + value label | within-band depth |
| R1 | `r1_linger_seconds` | `float` | `HSlider` + value label | seconds |
| R1 | `r1_chase_speed` | `float` | `HSlider` + value label | px/s greybox |
| R1 | `r1_speed_per_depth` | `float` | `HSlider` + value label | additive per depth |
| R1 | `r1_catch_radius` | `float` | `HSlider` + value label | px |
| R1 | `r1_catch_kills` | `bool` | `CheckButton` | kill vs cost |
| R1 | `r1_spawn_count` | `int` | `SpinBox` or `HSlider` | count |
| R2 | `r2_enabled` | `bool` | `CheckButton` (master) | |
| R2 | `r2_mechanism` | `@export_enum` int | **`OptionButton`** | items = `lengthen / decay_behind / egress_toll` |
| R2 | `r2_cost_magnitude` | `float` | `HSlider` + value label | |
| R2 | `r2_cost_per_depth` | `float` | `HSlider` + value label | |
| R2 | `r2_depth_threshold` | `int` | `HSlider` + value label | |
| R2 | `r2_toll_resource` | `@export_enum` int | **`OptionButton`** | items = `clock / exposure / meter` |
| R3 | `r3_enabled` | `bool` | `CheckButton` (master) | |
| R3 | `r3_base_climb_rate` | `float` | `HSlider` + value label | per second |
| R3 | `r3_rate_per_depth` | `float` | `HSlider` + value label | |
| R3 | `r3_threshold_levels` | `PackedFloat32Array` | **list editor** (see §3.4) | ascending levels; may be empty |
| R3 | `r3_penalty_kind` | `@export_enum` int | **`OptionButton`** | items = `none / speed / vision / clock` |
| R3 | `r3_penalty_magnitude` | `float` | `HSlider` + value label | |
| R3 | `r3_max_forces_loss` | `bool` | `CheckButton` | max → `timeout` |
| R3 | `r3_decay_on_retreat` | `float` | `HSlider` + value label | 0 = no decay |
| R4 | `r4_enabled` | `bool` | `CheckButton` (master) | |
| R4 | `r4_branch_chance_base` | `float` | `HSlider` (0–1) + label | probability |
| R4 | `r4_branch_per_depth` | `float` | `HSlider` + value label | |
| R4 | `r4_max_branch_depth` | `int` | `HSlider` + value label | |
| R4 | `r4_vision_radius` | `float` | `HSlider` + value label | 0 = full vision |
| R4 | `r4_vision_tighten_per_depth` | `float` | `HSlider` + value label | |
| R4 | `r4_fog_enabled` | `bool` | `CheckButton` | |
| R4 | `r4_lost_proxy_threshold` | `float` | `HSlider` + value label | telemetry proxy |

That is all 32 fields the R0 test counts (`R0 OK — all 32 knobs`). The implementing agent should **assert at build time that the bound-field set equals `RunConfig`'s exported field set** (see §3.5 reflection) so a future R-task adding a knob can't silently leave it unreachable — that is the CFG acceptance "no opposition knob is unreachable."

### 3.3 Enum-placeholder fields render as `OptionButton`

`r2_mechanism`, `r2_toll_resource`, `r3_penalty_kind` are `@export_enum(...)` **ints**. Each renders as an `OptionButton` whose item list is the enum's hint strings **in declared order**, so the selected `item index == the stored int`. Per Resolved Decision §7-b, the menu shows the **schema's own hint strings verbatim** (e.g. `lengthen / decay_behind / egress_toll`) plus a `(placeholder)` suffix in the CSV until R2/R3 finalise these meanings, at which point the suffix is dropped. No per-option CSV gloss is authored — labelling from the schema's hint strings means the menu can never drift from the schema. The selected index writes straight to the int field; no remapping.

### 3.4 `r3_threshold_levels` (the one array field)

`PackedFloat32Array` is the only non-scalar. Greybox treatment: a tiny **list editor** — a small `VBox` of rows, each `[ SpinBox ] [ x remove ]`, plus an `[ + add level ]` button — that reads/writes the array. The menu keeps it sorted ascending on edit (the field doc says "ascending"). An empty list (the default) is valid = "no levels." This is the only field that needs more than a single control; everything else is a 1:1 widget.

### 3.4a Slider ranges + always type-exact (ratified)

The `RunConfig` schema carries no min/max (only defaults), so the menu defines display ranges. Per Resolved Decision §7-c, every `HSlider` uses the following **generous greybox ranges by type** so the Director can sweep without hitting an artificial cap:

| Knob type | Slider range |
|---|---|
| depth thresholds (`*_depth_threshold`, `r4_max_branch_depth`) | `0–10` |
| speeds (`r1_chase_speed`, etc., px/s) | `0–120` |
| seconds (`r1_linger_seconds`) | `0–30` |
| probabilities (`r4_branch_chance_base`, `r3`/array levels, `r4_lost_proxy_threshold`) | `0–1` |
| radii (`r1_catch_radius`, `r4_vision_radius`, px) | `0–64` |
| magnitudes / per-depth rates (`*_cost_magnitude`, `*_per_depth`, `r3_*_rate`, penalties) | `0–100` |

**Every numeric row is also typeable to an exact value** — each slider row pairs with an editable numeric field (the live-value label is an editable `SpinBox`-style echo, or a `SpinBox` accompanies the slider) so the Director is **never capped by the slider range**: typing a value outside the slider span is accepted and writes to the config (the slider clamps its handle but the underlying field keeps the typed value). This makes the ranges a fast-scrub convenience, not a hard limit. The implementing agent may widen any range if a sweep needs it; these are the defaults.

### 3.5 Hand-off to the run on Start

On Start the menu **stages its working config**, then lets the existing run-start flow proceed:

```
GameState.stage_run_config(working_cfg)   # R0 seam — binds active_run_config for the next run
# then the existing MainGame.start_new_run() runs, which calls GameState.start_run(...)
```

This **replaces** the single line in `MainGame.start_new_run()` that currently stages the all-off default:

```gdscript
# main_game.gd, today (R0):
GameState.stage_run_config(load(RUN_CONFIG_PATH) as RunConfig)
```

The seam is intentionally minimal: CFG does **not** touch `GameState` or `EventBus`. It uses the public `stage_run_config(cfg)` that R0 already added. The integration shape is **fixed (Resolved Decision §7-d): shape (a)** — CFG **provides** the working config to `MainGame`, which stages it inside `start_new_run` (replacing the `load(...)` with the menu's config). This keeps `start_new_run` as the single run-entry seam (it is also called by `SellScreen.continue_pressed`), so *every* run-start path — menu Start **and** sell-screen Continue — stages the same Director-chosen config, not just the first. The menu therefore exposes `apply_and_get_config()` and does **not** call `start_new_run` itself.

### 3.6 Row construction — hand-authored rows + coverage assertion (ratified)

Rows are **hand-authored** — one explicit row per field in §3.2, with the widget and label chosen deliberately per knob (Resolved Decision §7-a). This is the simplest, most layout-controllable greybox path. Reflection over `RunConfig`'s property list is **not** used. The safety net against a future R-task adding a knob that nobody wires up is the **build-time coverage assertion in §3.2**: the implementing agent asserts that the hand-authored bound-field set equals `RunConfig`'s exported field set, so a missed knob fails loudly rather than silently going unreachable. (The §4 pseudocode is written reflection-flavoured only to illustrate the 100%-coverage intent; the implementation hand-authors the rows and keeps the coverage assertion.)

---

## 4. Pseudocode

Illustrative `ConfigMenu` script (`ui/config/config_menu.gd`). The structure below is written generically to show the 100%-coverage path; per ratified §3.6 the implementation **hand-authors** the per-field rows and `_fields_for_prefix` manifest (not reflection), keeping the build-time coverage assertion as the safety net. Not drop-in.

```gdscript
class_name ConfigMenu
extends Control
## Greybox pre-run config panel. Owns ONE working RunConfig it mutates as the
## Director edits; stages it on Start. Touches no GameState/EventBus truth beyond
## the public stage_run_config() seam. All strings via tr() against config_strings.csv.

const DEFAULT_CFG_PATH := "res://data/run_config/run_config.tres"

## Section metadata: which @export_group prefix each opposition uses + its gloss key.
const SECTIONS := [
    {"prefix": "", "title_key": "cfg_sec_meta", "master": "", "collapsible": false},
    {"prefix": "r1_", "title_key": "cfg_sec_r1", "master": "r1_enabled", "collapsible": true},
    {"prefix": "r2_", "title_key": "cfg_sec_r2", "master": "r2_enabled", "collapsible": true},
    {"prefix": "r3_", "title_key": "cfg_sec_r3", "master": "r3_enabled", "collapsible": true},
    {"prefix": "r4_", "title_key": "cfg_sec_r4", "master": "r4_enabled", "collapsible": true},
]

var _cfg: RunConfig                       # the working config (a duplicate, never the on-disk .tres)
var _rows := {}                           # field_name -> the control node, for read-back/refresh

func _ready() -> void:
    _cfg = _load_default()
    _build_ui()
    _refresh_all()                        # push cfg values into controls + chips + summary

func _load_default() -> RunConfig:
    var base := load(DEFAULT_CFG_PATH) as RunConfig
    return base.duplicate(true) if base != null else RunConfig.new()

# --- UI construction -------------------------------------------------------

func _build_ui() -> void:
    _build_summary_bar()                  # RUN: R1.. + Reset button
    for sec in SECTIONS:
        var body := _add_section_header(sec)   # title + gloss + (if master) CheckButton + chip
        for field in _fields_for_prefix(sec.prefix):
            if field == sec.master:
                continue                  # the master lives in the header
            _add_row(body, field)         # label + typed control + live-value label

## Every exported RunConfig var whose name starts with `prefix` (Meta = no prefix,
## i.e. seed_override/build_tag). Ratified §3.6: this returns a HAND-AUTHORED
## manifest of field names per section (not reflection). A build-time assertion
## checks this manifest equals RunConfig's exported field set (coverage net).
func _fields_for_prefix(prefix: String) -> Array: ...

## Pick the widget by the field's variant type + export hint:
##   bool -> CheckButton; int/float -> HSlider(+label) or SpinBox;
##   @export_enum int (hint == PROPERTY_HINT_ENUM) -> OptionButton(hint_string split on ",");
##   PackedFloat32Array -> the §3.4 list editor; String -> LineEdit.
func _add_row(parent: Control, field: String) -> void:
    var control := _make_control_for(field)
    _rows[field] = control
    _wire_change(control, field)          # on value change -> _set_field(field, value) -> _refresh_chip+summary

func _set_field(field: String, value) -> void:
    _cfg.set(field, value)
    _refresh_section_chip(_section_of(field))
    _refresh_summary()

# --- Reset to M1.0 baseline (all off) --------------------------------------

func _on_reset_pressed() -> void:
    _cfg = _load_default()                # script defaults == all-off == M1.0 baseline
    _refresh_all()                        # every master OFF, every magnitude neutral, chips OFF

# --- On Start: write + stage -----------------------------------------------

## Ratified shape (a), §3.5: the menu only EXPOSES its working config. MainGame
## stages it inside start_new_run(), so sell-screen Continue reuses the same
## config too. The menu does NOT call start_new_run or stage the config itself.
func apply_and_get_config() -> RunConfig:
    return _cfg                           # MainGame stages this in start_new_run()

# --- Refresh (cfg -> view) -------------------------------------------------

func _refresh_all() -> void:
    for field in _rows:
        _push_value_to_control(_rows[field], _cfg.get(field))
    for sec in SECTIONS:
        _refresh_section_chip(sec)
        _set_body_dimmed(sec, not _master_on(sec))   # dim body when master OFF (redundant cue)
    _refresh_summary()

func _refresh_summary() -> void:
    # "RUN: R1[x] R2[ ] R3[x] R4[ ] · seed auto"  — the headline scan line.
    ...
```

Key behaviours the pseudocode encodes: **one working config**, **duplicate-on-load** (never mutate the on-disk default), **master-in-header** with **dim-body-when-off** redundancy, **chip + summary refresh on every edit**, **reset == reload defaults**, and **stage-on-Start** through the existing seam.

---

## 5. Files to create / touch

**Create (under `ui/config/`):**
- `ui/config/config_menu.tscn` — the greybox `Control` panel scene (sections, rows, summary bar, Reset). Default theme, plain containers.
- `ui/config/config_menu.gd` — `class_name ConfigMenu`, the script in §4 (build rows, bind to the working `RunConfig`, reset, stage-on-Start).
- `ui/config/config_strings.csv` — externalised strings (section titles, glosses, chip text, button captions), mirroring `ui/hud/hud_strings.csv` / `ui/sell/sell_strings.csv`. (`.csv.import` + `.en.translation` are generated on import.)

**Touch:**
- `scenes/game/main_game.tscn` — add a `ConfigMenu` instance as a child of the `MainMenu` `CanvasLayer`, anchored as the side rail beside `MainMenu/Center` (§2.1).
- `scenes/game/main_game.gd` — the **one seam line** CFG replaces: in `start_new_run()`, the current
  `GameState.stage_run_config(load(RUN_CONFIG_PATH) as RunConfig)`
  becomes a stage of the **menu's working config** (e.g. `GameState.stage_run_config(_config_menu.apply_and_get_config())`), with a fallback to the all-off default if the menu node is missing. `RUN_CONFIG_PATH` stays as that fallback. (Wire `@onready var _config_menu` to the new node; connect Start through the menu per §3.5.)

**Do NOT touch:**
- `systems/event_bus.gd` — CFG declares/uses no signals (CFG's "config applied" debug fire, if added, is local/print-only, **not** a new EventBus signal). This keeps CFG off the wave-1 `event_bus.gd` editor list (TEL owns that file this wave).
- `systems/game_state.gd` — CFG uses only the **public** `stage_run_config(cfg)` R0 already added; it adds no state and edits no GameState code.
- `data/run_config/run_config.gd` / `.tres` — CFG reads the schema and duplicates the default; it never edits R0's files.

---

## 6. Acceptance criteria

Restated from the Breakdown §4 CFG entry (and §7 DoD #2):

1. From `main_game`, the Director can **toggle each opposition on/off** (R1–R4 masters) before pressing Start.
2. The Director can **set every knob** of every opposition before Start (all 32 `RunConfig` fields are reachable and editable — **no opposition knob is unreachable from the menu**).
3. The **started run reflects those values** — the config the menu built is the run's `active_run_config` (verifiable via `GameState.active_run_config` after Start, and downstream via TEL's `run_started` snapshot once TEL lands).
4. **"Reset to baseline" returns all-off** — every master OFF and every magnitude neutral, reproducing the M1.0 baseline control.
5. The menu **surfaces 100% of `RunConfig`'s knobs** with no hidden/hardcoded opposition values; it does **not** restart live dives (it only configures the next run launched from the existing Start Run flow).
6. (Process) Greybox styling; all strings externalised; mockup/layout signed off before heavy engine work (UI playbook DoD); CFG touches neither `event_bus.gd` nor `game_state.gd`.

---

## 7. Resolved Decisions (Director-ratified 2026-06-19 — apply-all-recommendations)

The Director ratified the implementing recommendation for every prior open question. Each is now a committed decision; the body sections above have been updated to read as one definite design.

**a. Row construction (§3.6).** *Question:* reflect over `RunConfig` to auto-generate rows, or hand-author an explicit row per field? **Decision: hand-authored rows, plus a build-time coverage assertion against `RunConfig`'s exported field set.** *Rationale:* simplest, most layout-controllable greybox path while still failing loudly if a future knob is missed — reflection's churn-resilience isn't worth the extra code and array/enum special-casing at greybox.

**b. Enum-placeholder labelling (§3.3).** *Question:* show raw schema hint strings with a `(placeholder)` tag, or author a per-option CSV gloss? **Decision: show the schema's own hint strings verbatim, tagged `(placeholder)` until R2/R3 finalise their meaning, then drop the tag.** *Rationale:* sourcing labels from the schema's hint strings means the menu can never drift from the schema.

**c. Slider ranges (§3.4a).** *Question:* the schema has no min/max — what range per `HSlider`? **Decision: generous per-type greybox ranges (depths 0–10, speeds 0–120 px/s, seconds 0–30, probabilities 0–1, radii 0–64 px, magnitudes/rates 0–100), and every numeric row is also typeable to an exact value so the Director is never capped by the slider.** *Rationale:* wide enough to sweep, with type-exact entry as the escape hatch so the range is a convenience, not a hard limit.

**d. Start-button routing (§3.5).** *Question:* should the menu stage the config and call `start_new_run` (shape b), or expose the config to `MainGame` which stages it inside `start_new_run` (shape a)? **Decision: shape (a) — the menu exposes `apply_and_get_config()`; `MainGame.start_new_run()` stages it.** *Rationale:* keeps `start_new_run` the single run-entry seam, so both menu Start and `SellScreen.continue_pressed` stage the same Director-chosen config — not just the first run of a session.

**e. Session persistence of the working config.** *Question:* does the last-applied config carry across a session's repeated runs, or must every run re-confirm the menu? **Decision: persist within a session (set-once; the menu stays open on the main menu for edits between runs).** *Rationale:* set-once is the faster sweep loop, and shape (a) makes it natural since sell-screen Continue reuses the staged config. This is **session-only** memory — `RunConfig` is run-scoped and is never written to the SaveManager meta schema (R0 run/meta boundary).
