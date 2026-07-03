# S4 — Generated debug-menu sections from `param_schema` + generalized coverage assertion + sweep hygiene (opposition Phase D)

**Task id:** S4 · **Milestone:** M1.9 · **Wave:** 4 (Surface + content proof) · **blockedBy:** S2, S3
**Assignee roles:** `general-purpose` (implementation, CFG/config-menu house style per the UI playbook)
**Companion docs:** `M1.9_Breakdown.md` §Wave 4 (S4 entry) + §Cross-cutting contracts · `design/explorations/exploration-20260702/hazards/0-scalable-opposition-system.md` v2 §"Debug menu — how the tune-and-sweep surface scales" (the three-part fix + the three-tier live-edit model) · `design/M1_1_Tasks/CFG_config_menu.md` (the original menu design + coverage philosophy) · as-built: `Game/ui/config/config_menu.gd`, `Game/data/run_config/run_config.gd`, `Game/systems/telemetry/telemetry.gd`, `Game/tests/test_config_menu.gd`

> **This is a DESIGN doc** (Phase 2 of the four-phase authoring process). It specifies behaviour, binding, and pseudocode for the implementing agent. It writes no game code. Pseudocode is illustrative against the real as-built APIs, not a drop-in. S0/S2/S3 land before this task; where their outputs are cited (OppositionDef, SpawnService, the RunConfig generic levers), the names are the breakdown's contracts — the implementer reads the actual S0–S3 as-built code first and follows it.

---

## 1. Goal & design intent

**One line:** When an `OppositionDef.tres` is authored, its tuning section **appears in the ConfigMenu automatically** — generated from `param_schema`, guarded by the same fail-loud coverage discipline the 89 hand-authored rows have — and the sweep-hygiene model (config-marked staged overrides vs. `debug_dirty` live tweaks) keeps gate telemetry clean.

This is the surface half of "adding content is data, not engineering" (the one thing M1.9 must prove). S6a's Charger and S6b's Splitter ship as `.tres` + component; if the Director then has to hand-author menu rows to sweep them, the proof fails at the last step. S4 makes the menu **reflect the data layer**: loaded defs → generated collapsible sections → per-param widgets → `RunConfig.param_overrides` staging → config-marked telemetry. The invariant that made the hand-authored menu trustworthy across M1.1–M1.8 — *surface 100% of knobs, fail loudly on drift* — is **extended per-def, never dropped**.

Four deliverables, per the breakdown:
1. **Generated sections** — one collapsible section per loaded `OppositionDef`, widgets dispatched from `param_schema` entries (type → widget, min/max → slider range, gloss → label), reusing the existing row-builder machinery.
2. **Generalized coverage assertion** — per-def `params` ↔ `param_schema` ↔ generated-rows bijection, **plus the legacy 89-row assertion intact**, plus the config-trap detector generalized to defs.
3. **Sweep hygiene** — staged `param_overrides` are config-marked telemetry (stamped on `run_started` like every knob today); a **live** tweak is not a staged config, so it marks the run **`debug_dirty`** and SG2 filters it from the gate cohort.
4. **Live-edit tier v1 only** — *respawn-with-new-params* (`svc.despawn` + `svc.spawn` at the same cell); read-through defs and per-instance `ctx` overrides are explicitly deferred (breakdown open-question 7, exploration recommendation).

Plus one migration item riding along (opposition Phase D): **Telemetry subscribes to the generic `opposition_event` / `opposition_killed_player` signals** (S0 pre-declared them; entities dual-emit since S2) so SG2 can count deaths-by-id generically. Legacy per-type signals and their telemetry rows stay until post-gate retirement.

**Hard constraints (from the breakdown, restated):** all-off fingerprint `e943ac9c8bc1` unmoved (empty `oppositions_enabled` loads no def at run time — the menu *displaying* defs is presentation, not generation); the legacy 89-row assertion stays intact; the menu must build headlessly (tests run as scenes); config-marked telemetry discipline; primitives-only signal payloads.

---

## 2. Research — the as-built surface this generalizes

### 2.1 How the menu builds today (verified against `Game/ui/config/config_menu.gd`, 1294 lines)

The menu is **hand-authored rows over `RunConfig`'s `@export` fields** (ratified M1.1 §3.6), organized as:

- **`MANIFEST`** (`config_menu.gd:84-162`) — the hand-authored per-section ordered field lists (15 prefixes: meta `""`, `r1_`…`r4_`, `lvl_`, `quota_`, `cam_`, `timer_`, `hpp_`, `hbomb_`, `hspike_`, `exit_`, `throw_`).
- **`SECTIONS`** (`:59-78`) — per-section descriptor: prefix, CSV title/gloss keys, master field, collapsible flag.
- **`TABS`** (`:192-205`) — the M1.6 tab taxonomy (RD-2): **8 tabs** (Hazards, Level Gen, Vision, Time/Quota, Exp/Return, Throw/Cam, Player, Meta). Explicitly "PURE PRESENTATION: coverage is keyed off `_rows` + SECTIONS masters, never off this table."
- **`FIELD_RANGE`** (`:209-285`) / **`FIELD_STEP`** (`:290-300`) — per-field slider range/step lookups over shared range constants (`:33-55`); every numeric row is also typeable past the slider via its SpinBox (`allow_greater`, `:967`).
- **`_build_ui()`** (`:460-498`) — builds the docked summary bar + one `ScrollContainer` page per TABS entry, then `_build_section_into(col, section_key)` per section.
- **`_build_section_into()`** (`:540-609`) — header (master `CheckButton` + title + ON/OFF chip + gloss) + a `Body` VBox of `_build_row(body, field)` per MANIFEST field; registers `_section_bodies[prefix]` (dim target) and `_section_chips[prefix]`.
- **`_build_row()`** (`:877-905`) — the **widget dispatch**: `r3_threshold_levels` → list editor; `TYPE_BOOL` → `_build_bool` (CheckButton, `:908`); `TYPE_STRING` → `_build_string` (LineEdit, `:915`); `PROPERTY_HINT_ENUM` (`_is_enum_field`, `:1273`) → `_build_enum` (OptionButton, `:926`); `TYPE_INT`/`TYPE_FLOAT` → `_build_numeric` (HSlider + SpinBox pair, `:939-982`; SpinBox is the canonical `_rows` control) or `_build_unbounded_spin` for `seed_override` (`:987`). Every widget writes through **`_set_field(field, value)`** (`:1087-1091`): `_cfg.set(field, value)` + chip/summary refresh.
- **`_rows: Dictionary`** (`:306`) — `field_name → bound control`. This is the **coverage ledger**: refresh (`_refresh_all`, `:1124`; `_push_value_to_control`, `:1136`) and the assertion both iterate it.

### 2.2 The coverage assertion — the invariant to preserve (`:414-455`)

`has_full_coverage()` (`:414-437`) computes `bound` = `_rows.keys()` ∪ SECTIONS masters, `exported` = `_exported_config_fields()` (`:446-455` — reflection over `_cfg.get_property_list()`, STORAGE+EDITOR usage, minus Resource bookkeeping props), and **fails loudly in both directions**: any exported field with no bound control (`missing` — an unreachable knob), any bound control naming a dead field (`extra` — drift). `_assert_full_coverage()` (`:440`) runs it at `_ready` (`:336`); `tests/test_config_menu.gd:39` re-checks it headlessly and **additionally pins the exported-field count at 89** (`test_config_menu.gd:53-54`, with the full arithmetic audit trail at `:44-52`). This set-equality-plus-count net caught config drift across M1.1–M1.8; the exploration names it the discipline "v2 must preserve, not discard."

**Why `param_schema`-generated sections preserve the invariant** (exploration v2 §data-layer): the legacy net works because `RunConfig`'s `@export` metadata is reflectable — the menu can *enumerate the full knob set* and assert its rows cover it. Once per-type knobs live in an untyped `params: Dictionary`, there is nothing to reflect over — *unless the def carries its own schema*. `param_schema` restores exactly the shape the assertion needs: an enumerable, typed, ranged, glossed knob list **per def**. The generalized assertion is the same statement at def scope: *every `params` key has a schema entry, every schema entry names a real `params` key, and every schema entry has exactly one generated control*. Same fail-loud net, new scope. (The alternative — typed sub-Resources reflected via `get_property_list()` — scatters gloss/range across N component scripts and blurs the single assertion into per-component ones; hand-authoring doesn't survive 40 defs. The exploration's recommendation of `param_schema` stands.)

### 2.3 The Player-tab precedent (M1.7) — how this menu already learned to grow a tab

M1.7 added the VIEW-ONLY debug Player tab, and its pattern is load-bearing for S4:

- **Adding a TABS entry is pure presentation** — coverage is keyed off `_rows` + masters, never tab grouping (`:187-205` comments; proven when M1.6 regrouped 6 sections into tabs with the bound set byte-identical).
- **A pseudo-section key that is NOT a SECTIONS prefix** (`PLAYER_DEBUG_KEY`, `:185`) routes to its own builder in `_build_section_into` (`:544-545`) — the same hook S4 uses for the generated oppositions surface.
- **Controls that are not RunConfig knobs stay OUT of `_rows`** (`:699-701` NOTE; enforced by `test_config_menu.gd:117-121`, which fails if a Player-tab control leaks into `_rows`) — so they can't inflate coverage or move the fingerprint.

S4 inverts the last rule deliberately: unlike the Player tab's view-only widgets, the generated opposition widgets **are** config editors (they stage `oppositions_enabled` / `param_overrides`, which ARE RunConfig fields after S3). So the generated surface must be **visible to coverage** — via the two generic-lever bindings (§3.4) and the new per-def ledger — rather than hidden from it. The Player tab shows how to mount the tab; the R4-Vision pseudo-section (`R4_VISION_KEY`, `:168-177`) shows how a non-SECTIONS body key registers in `_section_bodies` for dimming without disturbing `_prefix_of` routing (`:1260-1269`).

### 2.4 The telemetry-hygiene model (as-built + how it generalizes)

Three existing mechanisms define the "labelled experiment" discipline:

1. **Config-marked runs.** `Telemetry._on_run_started` (`telemetry.gd:129-156`) stamps the full `RunConfig.to_flat_dict()` (`run_config.gd:455-566`) onto the `run_started` row (`:152`) — every run self-describes its knobs; RG analysis segments on them. Additive `data` keys, never a schema bump.
2. **The config-trap detector.** `RunConfig.inert_enabled_oppositions()` (`run_config.gd:597-624`) — one line per known trap ("enabled but the load-bearing magnitude is neutral"), consumed by BOTH the CFG warn line (`_refresh_trap_warning`, `config_menu.gd:1227-1239`, warn-only, never blocks Start) and the `run_started` stamp (`telemetry.gd:153`) so a dead-config run is self-identifying. Born from the M1.2 re-gate invalidation (two enabled-but-inert oppositions ran dead unnoticed).
3. **Debug-action marking.** The K-key `debug_kill` writes a self-identifying `debug_kill` row (`telemetry.gd:82-86, :226-233`) so a debug death is never a reasonless `run_ended`.

S4 extends each: staged `param_overrides` ride mechanism 1 (stamped via `to_flat_dict()` — S3 adds the keys, S4's tests assert them); the trap detector generalizes to defs via a `trap_if_neutral` flag on `param_schema` entries (mechanism 2, same warn-line + stamp); and a **live** mid-run tweak — which by definition cannot be on the `run_started` stamp — rides mechanism 3's pattern, escalated to a run-level flag: an immediate `debug_dirtied` row **plus** `debug_dirty: true` stamped on the `run_ended` row, so SG2 filters the whole run, not just the moment. (Telemetry already keeps per-run bookkeeping vars reset on `run_started` — `_accepted_value`/`_last_banked`/`_max_depth`, `telemetry.gd:46-50` — the `_debug_dirty` flag joins them.)

**Telemetry-subscriber state (for the migration):** `telemetry.gd:59-86` connects the legacy per-type signals — `hazard_awoke`/`hazard_caught` (R1, `event_bus.gd:89-90`), `new_hazard_killed` (K5, `:149`) — to per-type rows (`telemetry_schema.gd:38-39, :57`). `throw_killed_hazard` (`event_bus.gd:175`), `hazard_pursuer_state` (`:181`), `bomb_pulse_started` (`:151`) have **no Telemetry subscriber today** (tests + gameplay only). S0 pre-declared `opposition_event(id, event, depth, run_t_ms)` + `opposition_killed_player(id, depth, run_t_ms)`; S2's components dual-emit. S4 adds the generic Telemetry subscription; SG2's "deaths-by-id" analysis reads the new rows.

### 2.5 What S0–S3 will have landed (contracts this design consumes)

- **S0:** `OppositionDef` Resource (`id`, `display_name`, `host_scene`, spawn-card fields, caps, `params: Dictionary`, `param_schema: Array[Dictionary]`), 4 authored defs for the shipped hazards; `SpawnService` (per-dive node per breakdown open-question 3's recommendation, group-resolved `&"spawn_service"`) with `spawn/despawn/live_count/clear_all`; EventBus pre-declares. **Coordination:** S4 needs one more pre-declared signal — `debug_run_dirtied` (§3.6) — which per the K0 pattern S0 must pre-declare in Wave 1. This doc names it now so S0's design can carry it.
- **S2:** each def's `params` + `param_schema` completed to mirror its current knobs; a params↔schema bijection check exists as a test/lint (S4 folds the same logic into the menu's build-time assertion and extends it to generated rows).
- **S3:** `RunConfig` gains `oppositions_enabled: Array[StringName]` + `param_overrides: Dictionary` (`def_id → {param_key → value}`), all-off = both empty = no def loaded; `EncounterBuilder.populate(...)` consumes them; `to_flat_dict()` stamps them (S3 owns the dict edit; S4 asserts it).
- **Def files:** authored under a single content folder (S0's call; assumed `res://data/oppositions/*.tres` here). S6a/S6b drop `charger.tres` / `splitter.tres` / `splitter_child.tres` into the same folder — S4's acceptance is that their sections **auto-appear with zero menu edits**.

---

## 3. Design

### 3.1 Where the generated sections live — a new **Oppositions** tab

Add **one new TABS entry** — `{"title_key": "CFG_TAB_OPPOSITIONS", "sections": [OPPOSITION_DEFS_KEY]}` — inserted after Throw/Cam and before Player (Meta stays last), making 9 tabs. `OPPOSITION_DEFS_KEY := "opposition_defs_"` is a pseudo-section key exactly like `PLAYER_DEBUG_KEY` (`config_menu.gd:185`): never a SECTIONS prefix, never in `_prefix_of`'s scan list, routed to its own builder in `_build_section_into`.

Why a new tab, not sections under Hazards: (a) the Hazards tab already holds 4 legacy sections (`r1_`, `hpp_`, `hbomb_`, `hspike_`) and will visually double once the same 4 hazards appear as defs during migration — mixing the legacy knob rows and the generated def rows in one scroll invites editing the wrong one; (b) the def surface has different semantics (staging generic levers + a live-respawn action) that deserve one clearly-labelled home; (c) TABS regrouping is proven coverage-neutral (M1.6/M1.7 precedent). The tab renders one **generated collapsible section per loaded def**, sorted by `def.id` (stable order), plus a one-line header note (tr'd) stating the staging rule: *"Sections stage the NEXT run. Empty = baseline (no defs load)."* With zero defs authored/loadable the tab shows a single placeholder label — the menu must never fail to build headlessly on an empty folder.

### 3.2 Def discovery — show ALL authored defs, stage enablement

The menu loads **every authored def**, not just enabled ones (recommendation, per the task brief): the whole point of the surface is *turning things on*; showing only enabled defs would make the empty (all-off) default a dead tab with no way to enable anything. Enablement is **staged** — each generated section's master CheckButton adds/removes the def's id in the working config's `oppositions_enabled` array; nothing spawns until the next run stages the config (§3.5).

Discovery = directory scan of the S0 def folder at menu `_ready` (defs are content, loading a `.tres` for display touches no generation state — the all-off fingerprint is a generation-path property, and `EncounterBuilder`/`SpawnService` still load nothing when `oppositions_enabled` is empty). Use `ResourceLoader.list_directory(DEFS_DIR)` (4.6; handles exported-pack `.remap` indirection that raw `DirAccess` listings trip over), filter `.tres`, load + type-check `as OppositionDef`, skip-with-`push_error` on a bad file (fail loud, don't fail to build). No hand-authored registry list — a registry is one more hand-list that can drift, which is exactly the failure mode this task exists to close.

### 3.3 The generated section (per def)

Mirrors the legacy section anatomy (`_build_section_into`, `:540`) so the Director reads one visual language:

- **Header:** master `CheckButton` (staged enablement, §3.2) + `def.display_name` + the def `id` as tooltip + an **ON/OFF chip** (`ENABLED · 2 overrides` / `OFF`) + a **fold toggle** (`▸`/`▾`). Generated sections are genuinely collapsible (unlike legacy sections, which only dim): 6+ defs on one tab need folding; default = collapsed unless the def is enabled or has overrides.
- **Gloss:** tr'd via the key convention `CFG_GLOSS_DEF_<ID>` when present in `config_strings.csv`; **fallback = empty** (content must not require a CSV edit to appear — see §3.3a).
- **Body:** one generated row per `param_schema` entry, via the same `[label][widget(s)][live value]` row shape, **dimmed when the master is off** (`DIM_ALPHA`, same redundant-cue rules: chip text + checkbox + dim, never colour alone).
- **Live-run row (tier-v1 live edit):** a single button — `Respawn live instances (marks run dirty)` — visible/enabled only when a dive is live AND `svc.live_count(def.id) > 0` (§3.6-§3.7).

**Widget dispatch** reuses `_build_row`'s type→widget model (`:891-905`), driven by the schema entry instead of RunConfig reflection: `type: "bool"` → CheckButton; `"int"`/`"float"` → HSlider+SpinBox pair with `min`/`max` as the slider range (the `FIELD_RANGE` table generalized per-param) and `step` (optional; default 1.0 int / 0.1 float, 0.01 when `max - min <= 1.0` — the existing probability-step rule, `:943-944`); `"enum"` → OptionButton over the entry's `options: Array[String]`. `String`/array params are out of scope for M1.9 schemas (S2 authors none; the builder `push_error`s on an unknown `type` — fail loud, same as `:905`). To share code rather than duplicate it, the existing widget builders are refactored to take a **setter `Callable`** (legacy rows pass `_set_field.bind(field)`-equivalent closures; generated rows pass an override-staging closure, §3.5) — a pure refactor of `_build_bool/_build_numeric/_build_enum` internals; the legacy `_rows` registration, ranges, steps, and behaviour stay byte-equivalent.

**Effective-value display:** each widget shows the *effective* next-run value — `param_overrides[def.id][key]` if staged, else `def.params[key]` — with the row label suffixed `*` (plus tooltip "override staged; Reset clears") when overridden. A per-section `Clear overrides` button and the global Reset both return the widgets to `def.params` defaults.

#### 3.3a Glosses for data-only content

Per-param labels use the CSV key `CFG_DEF_PARAM_<ID>_<KEY>` when authored, **falling back to a humanized `key`** (`charge_speed` → `Charge speed`) when the key is absent — detected by `tr(k) == k`. Rationale: requiring a CSV row per param would make "content is data" quietly false (every new def would need a UI-file edit). The `param_schema` `gloss` field remains the CSV *key* carrier (per the exploration), but it is optional; the `.tres` linter (S2's bijection lint) may WARN on a missing gloss, never fail. All fixed chrome strings (tab title, staging note, chip text, respawn button, override suffix tooltip) are authored in `config_strings.csv` as usual.

### 3.4 Coverage — the generalized assertion (exact logic)

Three layers, all build-time (`_ready`) + re-checked headlessly by the test:

**Layer 1 — legacy, byte-identical in spirit:** `has_full_coverage()` (`:414-437`) runs unchanged. The two S3 generic levers (`oppositions_enabled`, `param_overrides`) are `@export` RunConfig fields, so they appear in `_exported_config_fields()` and **must be bound or the existing assertion fails** — correct behaviour, not a problem to suppress. They are bound by the generated surface itself: `_rows["oppositions_enabled"]` = the Oppositions-tab root container and `_rows["param_overrides"]` = the same root (distinct sentinel sub-nodes so the two entries are distinct controls). `_push_value_to_control` (`:1136`) gains one branch: these two fields trigger `_refresh_def_sections()` (re-project staged state into every generated widget/chip) — which is exactly what Reset needs anyway. **Never** exempt them from the net the way Player-tab controls are exempted — they are real knobs, and punching reflection-holes in `_exported_config_fields()` is the drift vector the net exists to catch.

**Layer 2 — the knob-count pin moves 89 → 91, restructured:** `test_config_menu.gd:53-54`'s `exported.size() != 89` becomes a **two-part model** so the legacy pin survives future def growth untouched:
- assert the *legacy* exported set (total minus the 2 named generic levers) has size **89** — the M1.1–M1.8 hand-authored surface, frozen;
- assert the generic levers are exactly `{oppositions_enabled, param_overrides}` → total exported = **91**.
Per-def knobs never enter this count (they are not RunConfig `@export` fields); their count is asserted per def in Layer 3. New defs therefore change **no** asserted number — the "knob count may grow" guardrail is satisfied structurally.

**Layer 3 — the per-def bijection (the new net):**

```gdscript
## For EVERY loaded def: params ↔ param_schema ↔ generated rows, all three mutually
## complete. Fail-loud per def (push_error names the def id + the exact drift).
func has_full_def_coverage() -> bool:
    var ok := true
    for def in _defs:                                   # every def loaded in §3.2
        var schema_keys := {}
        for entry in def.param_schema:
            if not entry.has("key") or schema_keys.has(entry.key):
                push_error("def '%s': param_schema entry missing/duplicate key: %s" % [def.id, str(entry)]); ok = false
            schema_keys[entry.get("key", "")] = true
        # (a) every params key has a schema entry (no unschema'd param — it would be unsweepable)
        for k in def.params.keys():
            if not schema_keys.has(k):
                push_error("def '%s': param '%s' has NO param_schema entry (unreachable knob)" % [def.id, k]); ok = false
        # (b) every schema entry names a real params key (no orphan schema — it would stage a dead override)
        for k in schema_keys.keys():
            if not def.params.has(k):
                push_error("def '%s': param_schema entry '%s' names a non-existent param" % [def.id, k]); ok = false
        # (c) every schema entry has exactly one generated control, and no extra rows
        var rows: Dictionary = _def_rows.get(def.id, {})
        for k in schema_keys.keys():
            if not rows.has(k):
                push_error("def '%s': schema param '%s' has NO generated control" % [def.id, k]); ok = false
        for k in rows.keys():
            if not schema_keys.has(k):
                push_error("def '%s': generated control '%s' references no schema entry" % [def.id, k]); ok = false
    return ok
```

`_def_rows: Dictionary` (`def_id → {param_key → control}`) is the generated twin of `_rows` — the per-def coverage ledger and refresh index. `_assert_full_coverage()` (`:440`) asserts `has_full_coverage() and has_full_def_coverage()`. Clauses (a)+(b) are the same bijection S2's lint/test asserts at author time; the menu re-asserting them at build time means a def edited after the lint ran still fails loudly at the surface.

**Config-trap detector, generalized:** `param_schema` entries may carry `trap_if_neutral: true` (S2 sets it on each def's load-bearing param — e.g. Charger's `charge_speed`). A new static helper (new file, e.g. `systems/oppositions/opposition_lint.gd`) — kept OUT of `run_config.gd` so the config schema never imports content — computes:

```gdscript
static func inert_enabled_defs(cfg: RunConfig, defs: Array) -> PackedStringArray:
    # for each def whose id ∈ cfg.oppositions_enabled: for each schema entry with
    # trap_if_neutral, effective = cfg.param_overrides.get(id,{}).get(key, def.params[key]);
    # neutral (0 / 0.0 / false) → append "%s:%s" % [id, key]. WARN-ONLY, mirrors
    # inert_enabled_oppositions()'s contract (run_config.gd:597).
```

Consumed by both existing sinks: the CFG warn line (`_refresh_trap_warning`, `:1227` — the def traps join the legacy list, same amber warn-only label) and the `run_started` stamp (additive `inert_enabled_defs` data key beside the legacy `inert_enabled_oppositions`, `telemetry.gd:153`). The legacy detector (`run_config.gd:597`) is untouched.

### 3.5 `param_overrides` staging flow (pre-run, config-marked)

Staging is **pre-run only**, identical in shape to every legacy knob — the working config `_cfg` is mutated live in the menu, and `apply_and_get_config()` (`:405`) hands it to `MainGame.start_new_run()` at the **next** dive (M1.6 RD-4). No new seam.

- **Master toggle** → add/remove `def.id` in `_cfg.oppositions_enabled` (duplicate-then-assign the array so a `.tres`-shared array is never aliased), then chip/summary/dim refresh — the generated `_set_field` analogue.
- **Param widget** → **sparse** override write: if the new value ≠ `def.params[key]` (the authored default), set `_cfg.param_overrides[def.id][key] = value`; if it equals the default, erase the key (and the def's sub-dict when empty). Sparse staging means the `run_started` stamp records only *actual deviations* — a run with an enabled def and no overrides is self-describingly "authored defaults."
- **The def resource is NEVER written.** The menu edits the working RunConfig only; `def.params` is content (the authored baseline). This keeps Reset (`_on_reset_pressed`, `:1117` — reload the all-off default → both levers empty) a complete return to baseline, and keeps the shared def Resource safe from menu aliasing.
- **Merge point:** `EncounterBuilder`/`SpawnService` compute effective params = `def.params` ⊕ `active_run_config.param_overrides[def.id]` at spawn, snapshotted by the entity at `setup()` exactly as today (`hazard_entity.gd:119-128` discipline; S3's contract).
- **Telemetry:** `to_flat_dict()` (S3) stamps `oppositions_enabled` (as `Array[String]`) + `param_overrides` (one additive key holding the sparse `def_id → {param → value}` dict of primitives — JSON-safe; see Open Question 5 on flat-vs-nested). S4's test asserts both keys appear on the `run_started` row and round-trip the staged values.
- **All-off guarantee:** the all-off default has both levers empty → the builder loads no def → nothing new exists at generation or run time → fp `e943ac9c8bc1` byte-identical. The menu *boots into the preset* (`_make_boot_config`, `:389`), which in M1.9 also stages **no defs** (breakdown open-question 5 recommends band-2-exclusive via the deck); Reset returns to all-off as always.

### 3.6 `debug_dirty` — the live-tweak run flag (who sets it, where it lands)

**Signal (S0 pre-declares, Wave 1 — K0 pattern, primitives only):**

```gdscript
## M1.9 (S4): a debug action mutated live run entities mid-run. The run's telemetry
## is experiment-dirty: Telemetry stamps debug_dirty on the run row; SG2 filters it.
signal debug_run_dirtied(source: StringName, run_t_ms: int)   # source e.g. &"respawn_params"
```

**Who sets it:** only the ConfigMenu's live-edit action in M1.9 (§3.7) — emitted once per respawn action. (The existing K-key `debug_kill` keeps its own row and does NOT set `debug_dirty` — it ends the run rather than perturbing its remainder; revisit post-gate if SG2 wants it folded in.)

**Where it lands (Telemetry, additive — no schema bump, no envelope change):**
- a new per-run bookkeeping var `_debug_dirty: bool`, **reset `false` in `_on_run_started`** (`telemetry.gd:129`, beside `_accepted_value` et al.);
- on `debug_run_dirtied`: set `_debug_dirty = true` and `_emit_row(Schema.DEBUG_DIRTIED, {"source": String(source), "depth": _current_depth(), "run_t_ms": _elapsed_ms()})` + flush (the moment is auditable, like `debug_kill`, `:226-233`);
- in `_on_run_ended`: stamp `"debug_dirty": _debug_dirty` onto the `run_ended` row's `data` (additive key — the locked `run_ended` signal arity is untouched; the row, not the signal, carries it). SG2 filters the cohort on `run_ended.data.debug_dirty` (breakdown SG2 line "debug_dirty runs filtered").
- new `telemetry_schema.gd` consts: `DEBUG_DIRTIED := "debug_dirtied"` (+ `ALL_TYPES` append).

A run with **no** live tweak stamps `debug_dirty: false` — every run self-describes, including the clean ones.

### 3.7 Live edit, tier v1 — respawn-with-new-params (the only tier shipped)

Per the exploration's three-tier model, **only the cheapest tier ships**: edit params → despawn → respawn → the new instance snapshots the new values at `setup()`. No component change, no read-through, no per-instance `ctx` override UI (both explicitly deferred — breakdown open-question 7).

Flow, on the per-def `Respawn live instances` button (§3.3):
1. Guard: in-dive (`_pauses_dive()` pattern, `:377`) and `svc != null` (group `&"spawn_service"`) and `svc.live_count(def.id) > 0` — else the button is disabled with a tooltip.
2. For each live instance of `def.id` in the service registry: record its current cell, `svc.despawn(node)`, then `svc.spawn(def, same_cell, ctx)` with effective params = `def.params` ⊕ the menu's *current working* overrides for that def. The service enforces caps/placement as for any client — a refusal (null) is logged to the status line, not fatal.
3. Emit `EventBus.debug_run_dirtied(&"respawn_params", elapsed)` **once** per button press.
4. The staged overrides remain staged — the next run picks them up as a clean config-marked experiment; only *this* run is dirty.

Determinism note (exploration client table, row d): this is a **mid-run, run-state client** — it routes through `spawn()` which touches no layout RNG and never writes back to the generator, so `fingerprint()` is structurally unreachable from this path. The menu overlay pauses the tree in-dive (`_toggle_overlay`, `:361-371`); node freeing/adding while paused is safe (the service is PAUSABLE with the world — instances materialize on unpause).

**Live edits are strictly `debug_dirty`; staging is strictly pre-run.** A param widget edit during a dive changes the *staged next-run* config only (exactly like editing `r1_chase_speed` mid-dive today — read at next `start_new_run`); world mutation happens **only** through the explicit respawn button, which is what dirties the run. This keeps `apply_and_get_config()` semantics (`:403-406`) unchanged and makes the dirty-marking impossible to trigger accidentally.

### 3.8 Telemetry-subscriber migration to `opposition_event` (dual-emit stays)

Add to `Telemetry._ready` (beside the legacy connects, `:59-86`):

```gdscript
EventBus.opposition_event.connect(_on_opposition_event)
EventBus.opposition_killed_player.connect(_on_opposition_killed_player)
```

Handlers write **new row types** (`telemetry_schema.gd` consts `OPPOSITION_EVENT := "opposition_event"`, `OPPOSITION_KILLED_PLAYER := "opposition_killed_player"`, + `ALL_TYPES`): `{id, event, depth, run_t_ms}` (strings + ints — primitives only, TEL stamps `_elapsed_ms()` itself per the `:212` house rule) and `{id, depth, run_t_ms}` + flush (precedes a death `run_ended`, like `HAZARD_CAUGHT`). Legacy subscriptions and rows (`hazard_awoke`/`hazard_caught`/`new_hazard_killed`) **stay untouched** — dual-emit at the entity (S2) produces both a legacy row and a generic row for the same moment during migration. That duplication is deliberate and bounded: legacy rows preserve RG-tooling continuity for cross-version comparison; the generic rows are what SG2's per-id analysis reads; retirement of the legacy pair is post-gate (breakdown contract), at which point the legacy rows stop. Analysis scripts must count deaths from ONE family, never both — SG2's brief says the generic one.

---

## 4. Pseudocode — the generated-section builder

Illustrative; real code follows the as-built S0–S3 APIs and the §3.3 widget-refactor.

```gdscript
# --- config_menu.gd additions (S4) -------------------------------------------
const OPPOSITION_DEFS_KEY := "opposition_defs_"        # pseudo-key, PLAYER_DEBUG_KEY pattern
const DEFS_DIR := "res://data/oppositions/"            # S0's def folder (confirm as-built)

var _defs: Array = []                # loaded OppositionDefs, sorted by id (display order)
var _def_rows: Dictionary = {}       # def_id -> {param_key -> control}   (coverage ledger)
var _def_chips: Dictionary = {}      # def_id -> chip Label
var _def_bodies: Dictionary = {}     # def_id -> body VBox (dim + fold target)

func _load_defs() -> void:           # called from _ready() BEFORE _build_ui()
    for f in ResourceLoader.list_directory(DEFS_DIR):  # export-safe (.remap handled)
        if not f.ends_with(".tres"): continue
        var def := load(DEFS_DIR + f) as OppositionDef
        if def == null or def.id == &"":
            push_error("ConfigMenu: bad OppositionDef at %s" % f); continue
        _defs.append(def)
    _defs.sort_custom(func(a, b): return String(a.id) < String(b.id))

# _build_section_into() gains one branch (beside R4_VISION_KEY / PLAYER_DEBUG_KEY):
#   if section_key == OPPOSITION_DEFS_KEY: _build_opposition_defs_tab(parent); return

func _build_opposition_defs_tab(parent: Control) -> void:
    parent.add_child(_staging_note_label())            # tr("CFG_DEFS_STAGING_NOTE")
    if _defs.is_empty():
        parent.add_child(_placeholder_label())         # menu must build with 0 defs
    for def in _defs:
        _build_def_section(parent, def)
    # Bind the two generic levers into the legacy coverage net (Layer 1, §3.4):
    _rows["oppositions_enabled"] = parent              # sentinel: refresh routes to
    _rows["param_overrides"] = parent                  # _refresh_def_sections()

func _build_def_section(parent: Control, def: OppositionDef) -> void:
    # Header: fold ▸/▾ + master CheckButton + display_name + chip  (legacy anatomy, :559)
    var master := CheckButton.new()
    master.tooltip_text = String(def.id)
    master.toggled.connect(func(on: bool) -> void: _stage_def_enabled(def.id, on))
    ...
    var body := VBoxContainer.new()
    _def_bodies[def.id] = body
    body.visible = _section_expanded(def)              # collapsed unless enabled/overridden
    var rows := {}
    for entry in def.param_schema:                     # one generated row per schema entry
        rows[entry.key] = _build_param_row(body, def, entry)
    _def_rows[def.id] = rows
    _build_respawn_row(body, def)                      # tier-v1 live edit (§3.7); NOT in _def_rows

## Widget dispatch = _build_row's model (:891-905) driven by the schema entry.
## Reuses the refactored setter-Callable widget builders (§3.3) — same widgets,
## same slider+SpinBox pairing, same redundant-readout rules.
func _build_param_row(body: Control, def: OppositionDef, entry: Dictionary) -> Control:
    var setter := func(v) -> void: _stage_override(def, String(entry.key), v)
    match String(entry.type):
        "bool":         return _make_bool_widget(body, _label_for(def, entry), setter)
        "int", "float": return _make_numeric_widget(body, _label_for(def, entry), setter,
                            entry.get("min", 0.0), entry.get("max", 100.0),
                            _step_for(entry), entry.type == "int",
                            _effective_value(def, entry.key))
        "enum":         return _make_enum_widget(body, _label_for(def, entry), setter,
                            entry.get("options", []), _effective_value(def, entry.key))
        _:              push_error("def '%s': no widget for param type '%s'"
                            % [def.id, entry.type]); return null

func _stage_def_enabled(id: StringName, on: bool) -> void:
    var arr := _cfg.oppositions_enabled.duplicate()    # never alias a .tres array
    if on and not arr.has(id): arr.append(id)
    elif not on: arr.erase(id)
    _cfg.oppositions_enabled = arr
    _refresh_def_chip(id); _refresh_summary()

func _stage_override(def: OppositionDef, key: String, value) -> void:   # SPARSE (§3.5)
    var po := _cfg.param_overrides.duplicate(true)
    if _values_equal(value, def.params[key]):
        if po.has(def.id): po[def.id].erase(key)
        if po.get(def.id, {}).is_empty(): po.erase(def.id)
    else:
        po.get_or_add(def.id, {})[key] = value
    _cfg.param_overrides = po
    _refresh_def_chip(def.id)                          # "ENABLED · n overrides"

func _effective_value(def: OppositionDef, key: String):
    return _cfg.param_overrides.get(def.id, {}).get(key, def.params[key])

## Tier-v1 live edit (§3.7): despawn+respawn same cells with effective params; dirty once.
func _on_respawn_pressed(def: OppositionDef) -> void:
    var svc := get_tree().get_first_node_in_group(&"spawn_service")
    if svc == null or svc.live_count(def.id) == 0: return
    for node in svc.live_instances(def.id):            # or registry query per S0 API
        var cell: Vector2i = node.get_meta(&"spawn_cell")   # per S0's registry bookkeeping
        svc.despawn(node)
        svc.spawn(def, cell, _respawn_ctx(def))        # effective params merged in ctx/def path (S3 contract)
    EventBus.debug_run_dirtied.emit(&"respawn_params", Time.get_ticks_msec())
```

Refresh: `_refresh_def_sections()` re-projects `_cfg.oppositions_enabled` / `param_overrides` into every generated master/widget/chip via `set_*_no_signal` (the `_push_value_to_control` discipline, `:1136`) — called from the two sentinel `_rows` branches so `_refresh_all()`/Reset just work.

---

## 5. Files to create / touch

**Touch:**
- `Game/ui/config/config_menu.gd` — the §3/§4 additions: def loading, the Oppositions TABS entry + `OPPOSITION_DEFS_KEY` builder, the setter-Callable widget refactor, `has_full_def_coverage()`, staging, respawn action, generic-lever `_rows` bindings + refresh branches, trap-line extension.
- `Game/ui/config/config_strings.csv` — chrome strings (`CFG_TAB_OPPOSITIONS`, staging note, chip/fold/respawn/override strings) + optional per-def glosses for the 4 migrated defs.
- `Game/systems/telemetry/telemetry.gd` — `opposition_event`/`opposition_killed_player`/`debug_run_dirtied` subscriptions + handlers; `_debug_dirty` bookkeeping; `run_ended` stamp; `inert_enabled_defs` stamp on `run_started`.
- `Game/systems/telemetry/telemetry_schema.gd` — `OPPOSITION_EVENT`, `OPPOSITION_KILLED_PLAYER`, `DEBUG_DIRTIED` consts + `ALL_TYPES`.
- `Game/tests/test_config_menu.gd` — the §3.4 Layer-2 count restructure (89 legacy + 2 levers = 91), per-def coverage checks, staging/reset round-trip, headless-build-with-defs.

**Create:**
- `Game/systems/oppositions/opposition_lint.gd` — the static `inert_enabled_defs()` helper (§3.4), shared by menu + Telemetry.
- `Game/tests/test_def_menu_coverage.gd/.tscn` (or fold into `test_config_menu`) — fixture defs (including a deliberately-broken one asserted to fail) proving the bijection net fires; run **as a scene** (`godot --headless --path Game res://tests/...tscn` — never `--script`, never concurrent).

**Do NOT touch:** `event_bus.gd` (S0 pre-declared everything, including `debug_run_dirtied` — S4 only emits/connects); `run_config.gd` (S3 owns the levers + `to_flat_dict`); `main_game.gd` (S3 is the Wave-3 sole writer; S4 is Wave 4 and file-disjoint from S6a/S6b/S7 per the breakdown); any `OppositionDef.tres` `params`/`param_schema` content (S2/S6 own them — S4 only *reads*; exception: adding `trap_if_neutral` flags is coordinated with S2, see OQ-6); the save schema (nothing here persists).

---

## 6. Definition of done (concrete)

1. **Coverage:** `_ready` asserts legacy `has_full_coverage()` (with the 2 generic levers bound) AND `has_full_def_coverage()` (per-def bijection, §3.4). `test_config_menu` pins legacy = 89 + levers = 2 → 91 exported fields; a fixture def with a params/schema/row mismatch demonstrably fails the net (negative test).
2. **Generated surface:** with the 4 migrated defs loaded, the Oppositions tab renders 4 collapsible sections whose rows exactly mirror each `param_schema`; when S6a/S6b land, `charger`/`splitter`/`splitter_child` sections **auto-appear with zero `config_menu.gd` edits** (the S6 acceptance "menu section auto-appears" is proven against this).
3. **Headless:** the menu scene builds headlessly with 0 defs, with 4 defs, and with 6+ defs (fixture); `test_config_menu.tscn` + the new test scene green; import + smoke green.
4. **Staging + telemetry:** enabling a def + editing a param stages sparse `oppositions_enabled`/`param_overrides` on `apply_and_get_config()`; a started run's `run_started` row carries both (S3's `to_flat_dict`) + `inert_enabled_defs`; Reset returns both levers empty and every generated widget to authored defaults.
5. **Hygiene:** the respawn button (only in-dive, only with live instances) respawns via the service, emits `debug_run_dirtied` once, produces a `debug_dirtied` row, and the run's `run_ended` row stamps `debug_dirty: true`; an untouched run stamps `false`.
6. **Migration:** `opposition_event`/`opposition_killed_player` rows appear in the log alongside the legacy rows (dual-emit); legacy subscriptions/rows byte-identical.
7. **Baseline:** all-off fp `e943ac9c8bc1` byte-identical (empty levers load no def; menu display-loads defs without touching generation); `test_rg1_m1*_verify` + the full suite green.
8. Worklog at `worklogs/<date>-S4-<role>.md` naming the commit SHA(s) + a Design-deviations section.

---

## 7. Open Questions

*(Phase 3 resolvers evaluate these; anything vision/fun/tone/scope-flavoured goes to the Director with the recommendation attached.)*

1. **Where do the generated sections live — new tab vs. sections under existing tabs?** The menu has 8 tabs (7 knob tabs + the M1.7 Player tab; `config_menu.gd:192-205`). §3.1 designs a **new Oppositions tab** (9th). Alternative: append generated sections to the Hazards tab (fewer tabs, but legacy `hpp_`/`hbomb_`/`hspike_` knob sections and the same hazards' def sections would coexist in one scroll — two editable surfaces for one entity during migration is a mis-edit trap). **Recommend: the new tab**, revisit at legacy-knob retirement (post-gate) when the Hazards tab empties naturally.
2. **Defs shown when `oppositions_enabled` is empty — all authored vs. only enabled?** §3.2 recommends **all authored, staging enablement**: an enabled-only view makes the all-off default an un-escapable empty tab, and the Director's primary use is turning defs on. Cost: the menu loads def resources it may never spawn (display-only; negligible at ≤10 defs — revisit alongside OQ-4 at scale).
3. **Does the knob-COUNT assertion change from 89, and to what?** Yes — **91** exported RunConfig fields (89 legacy + `oppositions_enabled` + `param_overrides`), asserted as *89 frozen legacy + exactly-these-2 levers* rather than a bare 91 (§3.4 Layer 2), so future def content changes no asserted number and a third generic lever still fails loudly. Per-def knobs are asserted by bijection per def, never by a global count. *(Depends on S3 landing both levers as `@export` — if S3 makes them non-exported, they vanish from the reflection set and this collapses back to 89 + an explicit binding test; flag at S3 integration.)*
4. **UX at 6+ defs — search/pinning now or deferred?** The exploration sketches search/filter + "recently touched" pinning at 40 defs. M1.9 peaks at ~7 defs (4 migrated + charger + splitter ×2). **Recommend: defer** — collapsible sections, collapsed-by-default-unless-active, sorted by id, is sufficient at this scale; pinning/search is an M2+ follow-up task when the def count earns it.
5. **`param_overrides` on the `run_started` stamp — nested dict vs. flattened keys?** `to_flat_dict()`'s contract says flat primitive values (`run_config.gd:451-455`), but flattening (`po_charger_charge_speed`) creates an unbounded, def-coupled key-space. §3.5 recommends **one additive `param_overrides` key holding the sparse nested dict of primitives** (JSON-safe; sparse = only deviations; analysis segments on it fine). S3 owns the dict — align there; this is a data-shape call, not a Director call.
6. **Where does `trap_if_neutral` metadata live?** §3.4 puts it on `param_schema` entries (S2 authors it per def — one more field in the same table, consistent with "the schema is the knob's full metadata"). Alternative: a hand-list in `opposition_lint.gd` (keeps schemas lean but recreates a hand-authored drift surface). **Recommend: schema flag**; needs a one-line S2 coordination (S2's docs should name which param per def is load-bearing).
7. **Live edits strictly via the explicit respawn button (§3.7), or auto-respawn on any param edit while in-dive?** Auto feels slicker but makes every mid-dive widget touch silently dirty the run and spam despawn/respawn churn. **Recommend: explicit button** — pre-run staging stays pure (consistent with `apply_and_get_config()`'s next-run contract, `:405`), dirtying is deliberate, and the exploration's "covers 90% of does-this-feel-better tuning" claim holds either way.
8. **`oppositions_enabled` vs. `BandProfile.opposition_deck` precedence** *(coordination, S3/S7 — surfaced here because the menu's staging-note copy must state the truth).* If band 2's deck spawns Charger while the cfg lever is empty, "empty = no def loaded" holds for the *baseline band via the default portal* but not globally. Likely resolution (S3's design owns it): the cfg lever gates/augments the **default band-1 populator** (the sweep instrument + the all-off control), while a profile's deck is authoritative per-band content; `param_overrides` applies to both paths (merged at spawn by def id). S4 must echo the ratified semantics in the tab's staging note and in the trap detector's scope (only cfg-enabled defs are trap-checked).
9. **Should a `debug_kill` (K-key) also set `debug_dirty`?** §3.6 says no (it ends the run; its row already self-identifies, `telemetry.gd:226-233`) — but if SG2 prefers one uniform "any debug action dirties the run" rule, it's a two-line change. **Recommend: no for M1.9**; note for SG2's analysis brief.
10. **Respawn-cell bookkeeping.** §4 assumes the service registry can return live instances + their spawn cells (`live_instances(id)` / a `spawn_cell` meta). If S0's as-built registry stores only counts, S4 needs either a registry accessor (tiny S0-API addition — preferred) or a fallback (snap the node's current position to the grid — drifts for movers). **Recommend: registry accessor**; confirm at S0 integration, before Wave 4 dispatch.
