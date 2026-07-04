# S8 — Second Hub Portal + Band Routing + Telemetry Band-Stamp — Expanded Design Spec

**Milestone:** M1.9 (Scalable Opposition + Band Systems) · **Wave:** 5 (alone — hub + app routing)
**Task id:** S8 · **blockedBy:** S3 (BandPipeline call-site in `main_game`), S7 (`band_two.tres` exists), **plus S0's Wave-1 pre-declare of the routing seam this doc resolves**
**Assignee:** general-purpose (programmer) · **Author:** game-director-designer (Phase-2 design)
**Status:** design (Phase 3 resolved — see §Resolved Decisions; OQ-3 [tint + prompt text] awaits the Director's S7 pitch pick)

> **What this doc is.** The Phase-2 design for M1.9's reachability task: a second
> `DeparturePortal` on the hub that routes the dive into `band_two`, while the existing
> portal keeps routing to `band_greybox` **byte-identically**, and the chosen band is
> stamped on `run_started` telemetry so SG2 can compare per-band. It is **design only** —
> no code, no `.tres` ships from this doc. **§3 of this doc is a cross-task contract:**
> it defines the exact routing-seam shape that **S0 pre-declares on `main` in Wave 1**
> (breakdown guardrail "EventBus pre-declare rule" + open question 4). S0 must not
> dispatch until §3's recommendation is ratified in Phase 3.

---

## 0. Hard constraints (read first)

From the M1.9 breakdown (`design/M1_9_Tasks/M1.9_Breakdown.md` §Scope guardrails, §S8) and
the standing M1 contracts:

- **The existing portal's path is byte-identical.** The all-off `RunConfig` fingerprint
  **`e943ac9c8bc1`** stays unmoved (`tests/test_run_config` gate), the `band_greybox`
  fingerprints byte-match through the pipeline (S1/S3's determinism suite), and the hub
  contract check (H4 pattern — see §5.5) stays green. Target: `departure_portal.tscn`
  ships a **zero-byte diff**; portal 1's runtime behaviour is asserted unchanged.
- **No save-schema change.** Band choice is **not persisted** — no `meta.sav`/`run.sav`
  field, no `schema_version` bump, no migration. The second portal is **always present**
  (Director directive: unlock persistence deferred).
- **Primitives-only signal payloads.** Whatever the routing seam is, its payload is a
  `StringName` — never a `BandProfile` resource or Node ref (the K0/TEL rule; JSONL-clean).
- **Locked-arity precedent.** `run_ended(reason, duration_s, depth_reached)` is fixed-arity
  and the App router only *observes* it (`event_bus.gd:189-192`, `app.gd:108`). No M1.9
  work changes any existing signal's arity — §3 honors this by changing **nothing**.
- **M1.8 hub functional contracts invariant.** Interactable ids resolve
  (`&"portal"`, `&"shop"`), node paths (`$Player`, `$PlayerSpawn`, `$HudLayer/QuotaNotice`
  — `hub.gd:24-26`), the 4 wall collision shapes (`hub.tscn:28-46`), the iso ground paint
  (963 cells, `hub_ground.gd`), and the clear spawn→shop→gate lane all hold.
- **Run/meta boundary.** The band choice lives on the run side of `game_state.gd` (a
  *staging* slot, per §2.4) — never meta, never persisted, never surviving into a dive
  that didn't ask for it.
- **Single-writer:** S8 is Wave 5's sole writer of `main_game.gd`, `hub.tscn`,
  `departure_portal.gd`, and (for the reader half, if S0 landed the seam) `game_state.gd`.

---

## 1. Goal & design intent

**One sentence:** *the player stands in the hub and chooses which yard to dive into —
proving that a whole new band is reachable as content, not engineering.*

M1.9's thesis is "adding content is data, not engineering." S7 authors `band_two` as pure
data; S8 is the last mile that makes that data **playable**: a second gate on the surface,
visually distinct, that routes the very same dive flow into the new profile. Everything
between "interact" and "band generated" must be the *existing* machinery with one small,
declared seam — if S8 needs more than a staging field, a mapping table, and a scene
instance, the thesis has failed and that is itself a gate finding.

The second job is measurability: SG2 compares the two bands (run length, depth, end-causes,
deaths-by-id) **keyed on the band stamp in `run_started` rows**. The stamp must be present,
correct, and free for the control path (band-1 rows keep their historical value).

---

## 2. Research — the as-built routing chain (verified 2026-07-02, pre-Wave-1)

### 2.1 The chain today, hop by hop (file:line)

Every hop below was read directly from the working tree at `main` (M1.8 H4 state):

| # | Hop | File:line | What happens |
|---|---|---|---|
| 1 | Player presses `interact` | `Game/components/interaction/interaction_detector.gd:63-69` | `_unhandled_input` → `EventBus.interaction_requested.emit(_current.interactable_id, _current)`. The detector is agnostic — it names the focused `Interactable` and stops. |
| 2 | The portal's marker child | `Game/scenes/hub/departure_portal.tscn:26-32` | Child `Interactable` (Area2D, `collision_layer = 4` = the `interactable` bit) authored with `interactable_id = &"portal"`, `display_name = "Departure Portal"`, `prompt_text = "Dive"`. The floating prompt renders `"[F] Dive"` (`interactable.gd:24`, key hint derived in `ui/interaction_prompt.gd:11-26`). |
| 3 | The portal owner acts | `Game/scenes/hub/departure_portal.gd:41-55` | `_on_interaction_requested(id, target)`: id check (`:42`), focused-target parent check (`:46`), fat-finger lockout (`:48-51`), then **`EventBus.dive_requested.emit(band_id)`** (`:55`). `band_id` is an **existing export** — `@export var band_id: StringName = &"near"` (`:22`). The portal is deliberately dumb: "owns NO run-state … it only announces" (`:10-13`). |
| 4 | The signal | `Game/systems/event_bus.gd:197` | `signal dive_requested(band_id: StringName)` — **the payload already carries a band id** (declared M1.6, final 8-signal router set, `:183-197`). |
| 5 | The App router swaps scenes | `Game/scenes/app/app.gd:55` (connect), `:97-101` (handler) | `_on_dive_requested(_band_id: StringName)` — **the arg is received and DISCARDED** (underscore-prefixed). The router `_goto(DIVE_PATH, &"dive")` by path and holds no state ("owns NO game-state truth", `app.gd:8-10`). |
| 6 | The dive self-starts | `Game/scenes/game/main_game.gd:39` + `:181` | `const BAND_ID := &"near"` (`:39` — "M1 has a single greybox band"). `_ready` → `start_new_run()`; config resolved at `:198` (`GameState.dive_config_or_default()`), band generated at `:208-209` (`BandGenerator.new().generate(seed, _cfg, catalog, run_cfg)` — **the line S3 rewires to `BandPipeline.generate(profile, seed)`**), run started at `:287-289` (`stage_run_config(run_cfg)` → `start_run(BAND_ID, seed)` → `enter_band(BAND_ID)`). |
| 7 | GameState binds the run | `Game/systems/game_state.gd:128-170` | `start_run(band_id, seed)`: `current_band = band_id` (`:134`), config bound (`:145`), `RNG.seed_from(seed)` (`:169`), **`EventBus.run_started.emit(band_id, seed)`** (`:170`). |
| 8 | Telemetry stamps the row | `Game/systems/telemetry/telemetry.gd:129-156` | `_on_run_started(band_id, seed)` assembles the `run_started` row with **`"band_id": String(band_id)`** (`:149`) beside the build id (`:151`), the flat config stamp (`:152`), inert-oppositions (`:153`), and quota meta (`:154-155`). |

### 2.2 The load-bearing finding: the plumbing already exists at both ends

**`dive_requested` already carries `band_id`, and `run_started` already stamps it.** The
portal exports it (hop 3), the signal declares it (hop 4), `start_run` threads it into
`current_band` and `run_started` (hop 7), and Telemetry already writes it on every
`run_started` row (hop 8) — it has said `"near"` on every run since M1.6.

The chain is broken in exactly **one place**: between hop 5 and hop 6. The router
discards the arg *by design* (it owns no truth), and the dive scene self-starts on
`_ready` with a **hardcoded** `BAND_ID := &"near"` — there is no carrier for the choice
across the scene swap. So S8's real deliverable is **one staging slot + one mapping**,
not a new signal. The "telemetry band-stamp" half of the task is **already implemented**
at `telemetry.gd:149`; S8's job is to make the value *real* (and decide its vocabulary —
OQ-2).

### 2.3 The precedent for the carrier: `_dive_config`

The exact problem — "a value chosen in the Hub must survive the router's scene swap and
be read by the dive's self-start" — was solved in M1.6 for the Director's config:

- `game_state.gd:84-91` — `_dive_config: RunConfig`, documented as "NOT run-state (it must
  survive the Menu→Hub→Dive scene swaps) and NOT persisted (a debug director knob)".
- Writer: `stage_dive_config(config)` (`:192-193`); reader: `dive_config_or_default()`
  (`:199-202`), never-null, with a defined default.
- The sibling `_staged_run_config` (`:82-83`) adds the **consume-on-read** discipline:
  "consumed (and cleared) at start_run … so it can't leak into a later run" (`:145-146`).

The band choice gets the same shape: a GameState staging slot, defaulting to the control
band, consumed at dive start. This is the minimal-churn injection point — zero router
changes, zero signal changes, zero portal-scene changes.

### 2.4 Run/meta analysis — what the band choice *is*

| Question | Answer |
|---|---|
| Meta or run? | **Neither persists**: it is a *staging* value (the `_dive_config` class) — set by the hub interaction, consumed by the very next dive start, never written to disk. No `to_meta_dict()` key, no schema bump. |
| Quota MISS-wipe? | `wipe_meta()` (`game_state.gd:507-533`) "touches ONLY meta" — it never sees the staging slot. Irrelevant anyway: by the time the hub-return beat runs (`hub.gd:43` → `evaluate_quota_on_return`), the slot was already **consumed at dive start** (empty). A wipe cannot leak a band choice. |
| Return to hub? | Unchanged: `run_ended` → `app.gd:108-117` auto-return → `hub.gd:_ready` quota beat. All of it is band-agnostic. The "selection" implicitly resets to default because consumption cleared it — the **next** dive requires a fresh portal interact, which stages afresh. |
| A dive started without a portal (verify tests calling `start_new_run()` directly, `test_app_router.gd:68` emitting the signal raw)? | Reader falls back to the default → `band_greybox`. Consume-on-read guarantees a *previous* session's choice can never bleed into such a run. |
| Death in `band_two`? | Identical to death in band 1: `fail_run` → pockets → `run_ended(&"death", …)` → auto-return. No band-specific end path (the "one lifecycle" rule, `game_state.gd:255-256`). |

### 2.5 Hub placement analysis — where portal 2 sits in the iso layout

Current H4 iso hub (`hub.tscn`, worklog `worklogs/2026-07-02-H4-hub-iso-orchestrator.md`):

- **Anchors:** `PlayerSpawn` at `(0, 120)` (`hub.tscn:48-49`), `DeparturePortal` at
  `(0, -150)` (`:54-55`), `HubShop` at `(-220, -150)` (`:57-61`). The **lane** is the
  clear dirt run from the south-center spawn north to the gate, with the shop flanking
  west on the same northern line.
- **Ground zones:** the walled dirt yard is `|x| ≤ 340, |y| ≤ 216` in screen px
  (`hub_ground.gd:44-45`, matching the wall colliders at `±368 / ±232`, `hub.tscn:32-46`).
- **Y-sort:** the Hub root y-sorts children by node origin (`hub.tscn:17`); the portal's
  sprites are authored so the node origin *is* the visual base (`departure_portal.tscn:21-24`
  — DiveGate offset `(-4,-28)` above origin; glow behind at `z_index = -1`).

**Proposed position: `(220, -150)`** — the east mirror of the shop:

- Same `y = -150` as the gate and shop → **same y-sort band**, so all three structures
  sort consistently against the player (in front when south of them, behind when north).
- `|x| = 220 ≤ 340`, `|y| = 150 ≤ 216` → fully inside the packed-dirt yard (no grass/
  transition tiles under the gate), well clear of the E wall collider at `x = 368`.
- 220 px from portal 1 — the `InteractionDetector` reach is ~36 px
  (`interaction_detector.gd:6-8`), so the two portals can **never** be in range
  simultaneously; no focus-hysteresis ambiguity, no prompt flicker.
- Symmetric composition: shop west, band-1 gate center, band-2 gate east — the spawn→
  center lane stays clear and the "choice" reads spatially (left = sell, middle = the
  yard you know, right = the new yard).
- **HG3 hedge (OQ-5):** the position lives *only* in `hub.tscn` as an instance transform
  of the *shared* `departure_portal.tscn`. H4's worklog records the top-down revert as
  "one `tile_set` swap + painter revert away" — `hub.tscn` node positions carry across
  that revert untouched, and any future portal re-dress (iso-angle gate art) automatically
  applies to both portals because they instance one scene.

---

## 3. The routing seam — three options, one recommendation (THE S0 CONTRACT)

The breakdown's open question 4 names three candidate shapes. Analyzed against the as-built
chain (§2.1), the locked-arity precedent, and the pre-declare rule:

### Option A — "extend `dive_requested` with a `band_id: StringName` arg"

**Already true.** `dive_requested(band_id: StringName)` has carried the payload since M1.6
(`event_bus.gd:197`), and the portal already emits its exported `band_id` (`departure_portal.gd:55`).
There is nothing to extend — the option collapses to "use what exists." Cost: zero EventBus
churn, zero arity risk, and `test_app_router.gd:68` (which already emits `&"near"`) stays
valid unmodified. What it does NOT provide is the **carrier across the scene swap**
(§2.2) — a signal is an event, not storage; `main_game._ready` fires after the emission is
history. Someone must hold the value.

### Option B — sibling signal `dive_to_band_requested(band_id: StringName)`

Rejected. It duplicates a payload the existing signal already carries, and it forks the
dive-launch flow into two parallel paths — the exact anti-pattern the run-end side
explicitly refused ("one lifecycle, no parallel run-end path", `game_state.gd:255-256`;
the router's 8-signal set was *frozen* in M1.6, `event_bus.gd:190-192`). Every consumer
(router, GameState, future audio/UI) would have to listen to both or miss dives. Dual-emit
migration machinery for zero benefit.

### Option C — GameState run-state field set before emitting the existing signal

Half right. The *field* is exactly the missing carrier (§2.3's `_dive_config` precedent).
But "the portal sets it before emitting" violates the portal's own contract — it is a
deliberately **dumb** interactable that "owns NO run-state and NO meta truth: it only
announces" (`departure_portal.gd:10-13`, built on the ExtractGate pattern). Giving the
portal a direct `GameState` write couples the hub scene to the state singleton and makes
the signal's payload redundant-but-load-bearing (two sources of truth that can disagree).

### ★ Recommendation — **A+C hybrid: signal unchanged; GameState self-subscribes and stages**

> **THE CONTRACT S0 PRE-DECLARES (Wave 1, on `main`):**
>
> 1. **`event_bus.gd` — NO new signal, NO signature change.** S0 amends
>    `dive_requested`'s doc comment (S0 is the wave-1 owner of this file) to the M1.9
>    semantics: *"`band_id` is the dive routing key. GameState stages it on emission
>    (`_pending_dive_band`); `main_game` resolves it to a `BandProfile` at dive start
>    (unknown/empty → `band_greybox`). Emitters: the hub DeparturePortals (one per band)."*
> 2. **`game_state.gd` — the inert staging seam** (S0 is designated its wave-1 writer;
>    nobody else touches it in Wave 1):
>    - `var _pending_dive_band: StringName = &""` — staging (NOT meta, NOT persisted,
>      survives the router's scene swaps exactly like `_dive_config`, `game_state.gd:84-91`).
>    - `_ready()` gains `EventBus.dive_requested.connect(_on_dive_requested)` (beside the
>      existing `player_died`/`dive_clock_timeout` connects, `:119-121`), whose body is
>      one line: `_pending_dive_band = band_id`.
>    - `func consume_pending_dive_band() -> StringName` — returns the staged key and
>      **clears it** (consume-on-read, mirroring `_staged_run_config`, `:145-146`);
>      returns `&""` when nothing staged (callers treat `&""` as "default").
>    - **Inert until S3**: nothing reads the slot in Waves 1–2, so behaviour and the
>      all-off fingerprint are untouched by the pre-declare itself.
> 3. **Payload stays primitives-only** (`StringName`), per the M1.9 guardrail.
>
> Consumers land later: **S3 (Wave 3)** wires `main_game` to
> `consume_pending_dive_band()` → profile resolution → `BandPipeline.generate(profile,
> seed)` with the default `band_greybox` (its DoD already says "default `band_greybox` —
> S8 wires the portal choice"). **S8 (Wave 5)** adds the second emitter + tests + stamp
> verification.

Why this wins: zero signal churn (the strongest possible reading of the run_ended-arity
precedent — we change *nothing*), the portal stays dumb (EventBus-only, unchanged code),
the router stays truth-free (its `_band_id` stays discarded — no `app.gd` edit at all),
the carrier reuses a proven, documented GameState pattern, and the whole seam is
pre-declarable in Wave 1 as genuinely inert code. Failure modes are covered: a dive
reached without a portal (tests, menu-stub emission) gets the control band; a stale choice
cannot leak (consume-on-read); two portals emitting is impossible to double-stage (one
interaction → one emission → one write, and the lockout + scene swap kill re-presses,
`departure_portal.gd:27-30, 62-68`).

---

## 4. Design — the four deltas

### 4.1 Band-key → profile mapping (`main_game.gd`, S8 finalizes what S3 stubs)

Routing keys are decoupled from profile file names so portal 1 can keep emitting its
historical `&"near"` (scene byte-identical, telemetry vocabulary continuous — OQ-2):

```gdscript
# main_game.gd — S8 (Wave 5). S3 already landed :209 as BandPipeline.generate(profile, seed)
# with a hardcoded band_greybox load; S8 replaces the hardcode with the routing resolution.

const BAND_PROFILE_DIR := "res://data/bands/"
const DEFAULT_BAND_PROFILE := &"band_greybox"
## Routing key (what portals emit / what start_run tags the run with) -> profile id.
## &"near" is the legacy M1.6 key portal 1 has always emitted; it IS the greybox band.
const BAND_ROUTES: Dictionary = {
    &"near": &"band_greybox",
    &"band_two": &"band_two",
}

func _resolve_band() -> Dictionary:
    # Consume the staged choice (clears the slot — a later run can't inherit it).
    var key: StringName = GameState.consume_pending_dive_band()
    if key == &"" or not BAND_ROUTES.has(key):
        key = &"near"                                # no/unknown choice -> the control band
    var profile_id: StringName = BAND_ROUTES[key]
    var profile: BandProfile = load(BAND_PROFILE_DIR + String(profile_id) + ".tres")
    if profile == null:
        push_error("MainGame: band profile %s missing; falling back to %s."
                % [profile_id, DEFAULT_BAND_PROFILE])
        key = &"near"
        profile = load(BAND_PROFILE_DIR + String(DEFAULT_BAND_PROFILE) + ".tres")
    return {"key": key, "profile": profile}

# In start_new_run(), replacing the const BAND_ID uses (:39, :288-289):
    var route := _resolve_band()
    var band_key: StringName = route["key"]
    var profile: BandProfile = route["profile"]
    ...
    var band := BandPipeline.generate(profile, seed)   # S3's call site, main_game.gd:209
    ...
    GameState.stage_run_config(run_cfg)                # :287 unchanged
    GameState.start_run(band_key, seed)                # :288 — was start_run(BAND_ID, seed)
    GameState.enter_band(band_key)                     # :289 — was enter_band(BAND_ID)
```

Control-path proof obligation: with nothing staged, `band_key == &"near"` and
`profile == band_greybox` — `start_run(&"near", seed)` is **byte-for-byte the call made
today**, and the greybox profile through the pipeline byte-matches the direct generator
(S1's parity test). Nothing on this path moves fp `e943ac9c8bc1`.

### 4.2 Portal scene delta (reuse `departure_portal.gd` — root exports pushed down)

`departure_portal.tscn` ships **untouched** (zero-byte diff). The second portal is a new
*instance* in `hub.tscn` with overrides. Today the id/prompt live on the *child*
`Interactable` inside the portal scene (`departure_portal.tscn:26-32`), which a plain
instance override can't reach without editable-children noise — so `departure_portal.gd`
gains root-level exports it pushes down in `_ready`, with **defaults equal to the authored
values** (portal 1 unchanged without touching its scene):

```gdscript
# departure_portal.gd — additive exports (defaults == current authored values):
@export var prompt_text: String = "Dive"          # child Interactable's prompt verb
@export var display_name: String = "Departure Portal"
@export var glow_tint: Color = Color.WHITE        # modulates $PortalGlow (WHITE = as-authored)
@export var gate_tint: Color = Color.WHITE        # modulates $DiveGate  (WHITE = as-authored)

func _ready() -> void:
    EventBus.interaction_requested.connect(_on_interaction_requested)   # existing, :34
    # Push the per-instance identity down to the marker child (single source at root).
    var it: Interactable = $Interactable
    it.interactable_id = interactable_id           # &"portal" default == authored value
    it.prompt_text = prompt_text
    it.display_name = display_name
    $PortalGlow.modulate = glow_tint
    $DiveGate.modulate = gate_tint
```

`_on_interaction_requested` (`:41-55`) is untouched — it already emits the exported
`band_id`. The new `hub.tscn` node:

```
[node name="DeparturePortalBandTwo" parent="." instance=departure_portal.tscn]
position = Vector2(220, -150)          # §2.5 — east mirror of the shop, inside the dirt yard
interactable_id = &"portal_band_two"   # task-locked id
band_id = &"band_two"                  # the routing key (BAND_ROUTES maps it 1:1)
prompt_text = "Dive — Band 2"          # placeholder until S7's name ratifies (OQ-3)
display_name = "Band Two Portal"
glow_tint = Color(1.0, 0.58, 0.24)     # ember-orange proposal (OQ-3); band 1 keeps cold-violet
gate_tint = Color(1.0, 0.78, 0.62)     # lighter warm wash on the gate frame
```

The re-tint is a `modulate` over the existing `portal_glow.png`/`dive_gate.png` — the
"re-tint of existing gate/glow" placeholder the breakdown mandates; **no new art, no
PixelLab** (Director-gated). Portal 1's instance in `hub.tscn` gets **no** new overrides;
its rendering is `Color.WHITE`-modulated = identical output.

Note the two portals coexist safely by construction: distinct `interactable_id`s mean the
id check (`departure_portal.gd:42`) filters cross-fire, and even a same-id collision is
guarded by the focused-target parent check (`:46`). Each instance has an independent
lockout; the scene swap frees both.

### 4.3 Telemetry stamp — verify, don't build

Hop 8 (§2.1) already stamps `"band_id": String(band_id)` on the `run_started` row
(`telemetry.gd:149`), sourced from the `run_started` signal arg. With §4.1 in place the
value becomes the real routing key: `"near"` for portal-1 dives (unchanged vs every row
since M1.6 — the control cohort needs no re-baselining), `"band_two"` for portal-2 dives.
It already sits beside the config stamp (`run_config`, `:152`) and the S4-added
`param_overrides`/`debug_dirty` marks, exactly as the breakdown's cross-cutting contract
asks. **No `telemetry.gd` edit, no schema bump, no new row type.** (Whether to *also*
stamp the resolved profile id as an additive `band_profile` field is OQ-2.)

### 4.4 What is explicitly NOT built

- No `app.gd` change (the router keeps discarding `_band_id` — it owns no truth).
- No `event_bus.gd` change beyond S0's Wave-1 comment (no new signal — §3).
- No save/`schema_version` change; no unlock/gating logic; no HUD band indicator (OQ-4).
- No band-2-specific return flow: extract/death/timeout all auto-return to the hub via
  the existing `run_ended` observation (§2.4, OQ-6).
- No debug-menu band selector: the portals are the only player-facing selector; tests
  stage the key directly on GameState (OQ-7).

---

## 5. Contract tests & verification

### 5.1 Existing-portal byte-identical (the control)

- `tests/test_run_config` gate green: all-off fp **`e943ac9c8bc1`** unmoved.
- `git diff` shows **zero-byte change** to `departure_portal.tscn`.
- Bandgen determinism suite green through the pipeline (`test_bandgen_determinism` +
  S1's `test_band_pipeline_parity` seed matrix, `test_bandgen_determinism.gd:36`).
- `test_app_router` green **unmodified** (it already emits `dive_requested(&"near")`,
  `test_app_router.gd:68` — proving the signal contract didn't move).

### 5.2 New headless routing test — `tests/test_band_routing.gd/.tscn` (run as a SCENE)

```gdscript
# 1. Staging: emit dive_requested(&"band_two") -> GameState._pending_dive_band staged;
#    consume_pending_dive_band() returns &"band_two"; a SECOND consume returns &""
#    (consume-on-read — a stale choice cannot leak).
# 2. Default: with nothing staged, _resolve_band() -> key &"near", profile band_greybox.
# 3. Unknown key: stage &"band_bogus" -> resolves to &"near"/band_greybox (fail-safe).
# 4. Routing lands: stage &"band_two", drive start_new_run() -> BandPipeline ran the
#    band_two profile; band.fingerprint() != the band_greybox fingerprint for the same
#    seed AND == itself across two runs (deterministic, band.gd:56-58).
# 5. Stamp: subscribe to run_started before (4) -> received band_id == &"band_two";
#    repeat unstaged -> band_id == &"near". (The JSONL row mirrors the signal arg
#    verbatim, telemetry.gd:149 — asserting the signal asserts the row's source.)
# 6. Wipe isolation: stage &"band_two", GameState.wipe_meta() -> staged key untouched
#    (wipe is meta-only); then consume -> &"band_two".
```

### 5.3 Hub contract check — extend AND promote

H1/H2/H4 verified the hub with **throwaway** frame-waited SceneTree scripts
(worklogs 2026-06-28-H0H1 `:54-57`, 2026-07-02-H4 `:90-91`). S8 promotes the check to a
checked-in scene test `tests/test_hub_contract.gd/.tscn` (so SG1 and every later hub task
re-runs it for free) asserting the M1.8 invariants **plus** the portal-2 additions:

- Node paths resolve: `$Player`, `$PlayerSpawn`, `$HudLayer/QuotaNotice`, `$HubShop`,
  `$DeparturePortal`, **`$DeparturePortalBandTwo`**; 4 wall shapes; iso ground painted
  (963 cells, `hub_ground.gd`).
- Interactable ids: `&"portal"`, `&"shop"`, **`&"portal_band_two"`** — all `can_interact()`.
- Portal 2: `band_id == &"band_two"`, prompt names the band, position `(220, -150)`
  inside the yard (`|x| ≤ 340, |y| ≤ 216`), `glow_tint != Color.WHITE` (visually distinct).
- Portal 1: `band_id == &"near"`, prompt `"Dive"`, position `(0, -150)`,
  glow/gate modulate `== Color.WHITE` (rendering unchanged).

### 5.4 Standing gates

`godot --headless --path Game --import` clean · smoke test `SMOKE OK` · knob assertion
(legacy count + S4's per-def net) green · never run headless instances concurrently
(import-lock memory).

---

## 6. Files touched (S8, Wave 5)

| File | Change |
|---|---|
| `Game/scenes/hub/departure_portal.gd` | additive exports + `_ready` push-down (§4.2); defaults = authored values |
| `Game/scenes/hub/hub.tscn` | + `DeparturePortalBandTwo` instance at `(220, -150)` with overrides |
| `Game/scenes/game/main_game.gd` | `_resolve_band()` + `BAND_ROUTES`; `:288-289` use the resolved key (§4.1) |
| `Game/systems/game_state.gd` | *(only if S0's Wave-1 pre-declare didn't land it)* the staging seam per §3 |
| `Game/tests/test_band_routing.gd/.tscn` | NEW (§5.2) |
| `Game/tests/test_hub_contract.gd/.tscn` | NEW — the promoted + extended hub contract (§5.3) |

Pre-declared earlier by S0 (Wave 1, per §3): the `dive_requested` doc-comment amendment
(`event_bus.gd`) + the inert GameState staging seam.

---

## 7. Definition of done (concrete)

1. **Control byte-identical:** all-off fp `e943ac9c8bc1` unmoved; `departure_portal.tscn`
   zero-byte diff; `test_app_router` + bandgen determinism suites green unmodified;
   an unstaged dive runs `start_run(&"near", seed)` on the `band_greybox` profile with
   the parity-proven fingerprint.
2. **New portal routes:** interacting `&"portal_band_two"` stages `&"band_two"`, the dive
   generates from `data/bands/band_two.tres` deterministically (same seed → same fp,
   twice), and dies/extracts/times-out back to the hub through the unchanged auto-return.
3. **Stamp:** `run_started` rows carry `band_id` `"near"` / `"band_two"` per the dived
   portal (asserted at the signal per §5.2-5; spot-check one JSONL row of each).
4. **Contract tests:** `test_band_routing` + `test_hub_contract` green headless (as
   scenes); import + smoke green.
5. **No save-schema change** (no `schema_version` diff, no new persisted key); run/meta
   boundary intact (staging slot consumed at dive start; wipe-isolation test green).
6. Worklog at `worklogs/<date>-S8-general-purpose.md` naming the commit SHA(s), checks
   run, and a Design-deviations section; board + STATUS mirrored.

---

## Open Questions

> Phase-3 resolvers: resolve on technical merit where possible; items marked **Director**
> are vision/tone calls — flag with the recommendation, never self-resolve.

1. **★ Signal shape — THE CROSS-TASK CONTRACT FOR S0 (blocking Wave 1).** §3 recommends:
   **no new EventBus signal, no arity change** — reuse `dive_requested(band_id)`'s
   existing payload; S0 pre-declares the seam as (a) the `dive_requested` doc-comment
   amendment in `event_bus.gd` and (b) the inert `_pending_dive_band` +
   `consume_pending_dive_band()` staging seam in `game_state.gd` (S0 designated that
   file's Wave-1 writer), GameState self-subscribing so the portal stays dumb and the
   router stays truth-free. Alternatives analyzed and rejected in §3 (sibling signal =
   parallel launch path; portal-writes-GameState = breaks the dumb-interactable
   pattern). **This must be ratified before S0 dispatches** — it is the one S8 decision
   with a Wave-1 dependency.
2. **Routing-key vocabulary — keep `&"near"` or rename to `&"band_greybox"`?**
   Recommendation: **keep `&"near"`** as portal 1's key, mapped to `band_greybox` via
   `BAND_ROUTES` (§4.1). Pros: `departure_portal.tscn` zero-byte, `test_app_router`
   untouched, telemetry `band_id` continuity with every M1.6–M1.8 row (SG2/longitudinal
   analysis needs no re-keying). Cons: two vocabularies (routing keys vs profile ids)
   with a mapping table to maintain. If the resolver prefers one vocabulary, the additive
   compromise is stamping the *resolved profile id* as a second `run_started` data field
   (`"band_profile"`, additive — no schema bump, same pattern as `build`/`run_config`
   stamps) while `band_id` keeps the legacy key; recommend deferring that field until SG2
   actually wants it.
3. **Prompt text + tint (Director — tone).** Prompt placeholder **"Dive — Band 2"**
   (renders `"[F] Dive — Band 2"`); final text should carry S7's ratified band name
   (S7's design pitches 2–3 names — S8 folds the winner in at integration, a one-line
   `hub.tscn` override). Tint: band 1's glow is cold-violet; propose **ember-orange
   `Color(1.0, 0.58, 0.24)`** for band 2 — maximal hue separation, reads "hotter/deeper,"
   fits rust-and-heat junkyard fiction. Alternate if orange collides with hazard-red
   danger language in-band: acid-green `Color(0.55, 0.95, 0.35)`. Director picks.
4. **Hub label / HUD band indicator?** Does anything beyond the prompt say which band
   you're diving to? Recommendation: **no** for M1.9 — the portal prompt names the band
   at the decision moment, spatial position disambiguates, and `HubLabel`
   (`hub.tscn:77-88`) stays untouched. Optional later polish: the dive HUD could show the
   band name for the first seconds of a run (S7's identity work would drive it). Cheap,
   but scope-guard says defer.
5. **HG3 revert risk (iso vs top-down hub verdict is still pending).** M1.9 opened ahead
   of M1.8's HG3; if the Director reverts to the H2 top-down hub, does portal 2 survive?
   **Yes by construction** (§2.5): the placement is an instance transform in `hub.tscn`
   (the revert is a `tile_set` swap + painter revert per the H4 worklog — node positions
   carry), and both portals share `departure_portal.tscn`, so any gate re-dress applies
   to both. Residual check at integration: `(220, -150)` sits on packed dirt in H2's
   vertex-map paint too (H2 yard bounds match the same wall colliders) — verify visually
   post-revert; worst case is a position nudge, never a routing change.
6. **Return-from-band-2 flow — anything special?** Recommendation: **no** — auto-return
   to the hub, identical to band 1 (§2.4). Band-chaining ("band 2's exit leads deeper")
   is explicitly out of M1.9 scope (`band_depth` drives the credit budget only; full
   instability `I` is M2+, breakdown open question 6).
7. **Do tests/the debug menu need a band selector?** Recommendation: **no menu knob** —
   band choice is not a `RunConfig` field (it must not enter the MANIFEST/coverage set or
   the fingerprint surface); tests stage the key directly
   (`EventBus.dive_requested.emit(&"band_two")` or the GameState seam). If SG2 later
   wants Director band-forcing from the P-menu, that is a debug-tooling signal in the
   `debug_player_art_toggled` class (`event_bus.gd:228-240` pattern) — new task, not S8.
8. **Should `enter_band` / `band_entered` carry the routing key or the profile id?**
   `enter_band(band_key)` keeps `band_entered(band_id, depth)` consistent with
   `run_started`'s vocabulary (both say `"near"`/`"band_two"`). Recommendation: same key
   as `start_run` (§4.1 pseudocode does this); resolver should confirm no consumer
   assumes `current_band == &"near"` anywhere (grep found none — only the emit sites).

---

## Resolved Decisions (Phase 3)

Resolved 2026-07-02 by a fresh-eyes Phase-3 resolver (not the Phase-2 author), with the
orchestrator's cross-task adjudications folded in as ratified. **Q1, Q2, Q4–Q8 are
closed** — the body of this spec (§2–§7) commits to these answers and the implementing
agent reads a single definite spec for them. **Q3 (glow tint + prompt text) is the one
remaining Director call**, coupled to S7's identity-pitch pick.

### Fresh-eyes verification of the load-bearing claims (all re-checked against `main`, 2026-07-02)

The entire §2.1 routing chain was re-read hop-by-hop and **holds**: `dive_requested(band_id:
StringName)` at `event_bus.gd:197`; the portal's `@export var band_id: StringName = &"near"`
(`departure_portal.gd:22`) and `EventBus.dive_requested.emit(band_id)` (`:55`); the router's
discarded `_band_id` (`app.gd:97`); `const BAND_ID := &"near"` (`main_game.gd:39`) and
`start_run(BAND_ID, seed)` / `enter_band(BAND_ID)` (`:288-289`); `run_started.emit(band_id,
seed)` (`game_state.gd:170`); the `_dive_config`/`_staged_run_config` staging precedents
(`game_state.gd:82-91`, consume-on-read at `:145-146`); `test_app_router.gd:68` emitting
`&"near"`. **Corrections (minor, non-structural):**

- **Telemetry stamp is `telemetry.gd:149`, not `:150`** — `:150` is the `"seed"` key; the
  neighbours cited (`build` `:151`, `run_config` `:152`) are correct. §2.1 hop 8, §2.2,
  §4.3, and §5.2-5 should read `:149`. Substance unaffected.
- §2.4's "hub.gd:43 → evaluate_quota_on_return" — `hub.gd:43` is `_resolve_return_quota()`,
  which wraps the `GameState.evaluate_quota_on_return()` call. Substance unaffected.
- `Game/data/bands/` does not exist yet on `main` — expected (S1 creates it in Wave 2,
  S7 authors `band_two.tres` in Wave 4); §4.1's `BAND_PROFILE_DIR` is forward-correct.

**Portal-position check against the CURRENT (H4 iso) hub — `(220, -150)` CONFIRMED clear:**
`hub.tscn` anchors verified (`PlayerSpawn (0,120)` `:48-49`, `DeparturePortal (0,-150)`
`:54-55`, `ShopAnchor`/`HubShop (-220,-150)` `:57-61`, walls `±368/±232` `:32-45`). The iso
dirt yard is `|x| ≤ 340, |y| ≤ 216` (`hub_ground.gd:44-45`, `_is_dirt` `:70`) — `(220,-150)`
is packed dirt with ≥ 96 px of clearance to the grass-transition boundary band, so the gate
never sits on an edge/patchy tile. The hub's east half contains **no other placed node**
(the only structures are the shop west, gate center — the scene tree has nothing at x > 0
besides the center gate), and 220 px of portal-1 separation vs the ~36 px detector reach
(`interaction_detector.gd:6-8`) rules out prompt ambiguity. Same `y = -150` puts it in the
gate/shop y-sort band as designed. The "cold-violet" claim for portal 1's glow was verified
against the actual asset: `portal_glow.png`'s dominant opaque pixel is `(193, 85, 255)` —
violet — so every Q3 tint candidate below has strong hue separation from the control portal.

### The decisions

- **Q1 — Signal shape (THE S0 CROSS-TASK CONTRACT). RESOLVED — ★ RATIFIED (orchestrator
  cross-contract adjudication): §3's A+C hybrid is adopted verbatim as the cross-task
  contract. NO new EventBus signal, NO arity change — reuse `dive_requested(band_id)`.**
  S0's Wave-1 pre-declare is exactly §3's two pieces: (a) the `dive_requested` doc-comment
  amendment in `event_bus.gd`, and (b) the inert GameState staging seam —
  `_pending_dive_band: StringName = &""`, GameState self-subscribing to `dive_requested`
  in `_ready()`, and `consume_pending_dive_band()` with consume-on-read semantics.
  S0's originally-proposed `band_route_selected` signal is **DROPPED** (S0's design doc is
  being reconciled to this contract). *Rationale:* this doc's analysis won on merit — the
  payload already exists at both ends of the chain (§2.2), a sibling signal forks the
  launch flow against the frozen M1.6 8-signal set, and a portal-side GameState write
  breaks the dumb-interactable pattern. S0 may dispatch against this contract.

- **Q2 — Routing-key vocabulary. RESOLVED (ratified): keep `&"near"` as portal 1's key,
  mapped to `band_greybox` via `BAND_ROUTES`; band 2's routing key is `&"band_two"` →
  `Game/data/bands/band_two.tres`.** Exactly §4.1 as written. *Rationale:* telemetry
  `band_id` continuity with every M1.6–M1.8 row (SG2 needs no re-keying of the control
  cohort), `departure_portal.tscn` zero-byte, `test_app_router` untouched. The two-vocabulary
  cost is one 2-row const Dictionary — acceptable. The additive `"band_profile"` stamp on
  `run_started` is **DEFERRED** — do not add it until SG2 demonstrably wants it.

- **Q3 — Prompt text + glow tint. NEEDS DIRECTOR REVIEW (tone — coupled to S7's pitch
  pick).** One-liner: *pick S7's band-2 identity pitch; S8's tint and prompt text follow
  from it mechanically.* The tint pairs to the pitch's palette (verified against S7 §3.1;
  all three separate cleanly from portal 1's verified violet glow):
  - **Pitch A "The Sump"** (sepia-amber, GDD-canonical, S7's recommendation) → **ember-orange
    `Color(1.0, 0.58, 0.24)`** (this doc's §4.2 proposal) — warm gate for the warm band.
  - **Pitch B "The Overflow"** (cold teal-grey) → teal `Color(0.30, 0.85, 0.75)`.
  - **Pitch C "The Annex"** (institutional green-grey) → acid-green `Color(0.55, 0.95, 0.35)`.
  **Recommendation: Pitch A's ember-orange**, matching S7's own recommended pitch. Prompt
  text ships as the `"Dive — Band 2"` placeholder and is replaced by the ratified band name
  (e.g. `"Dive — The Sump"`) at S8 integration — a one-line `hub.tscn` override either way,
  so this call does **not** block S0/S3, only S8's final polish pass.

- **Q4 — Hub label / HUD band indicator. RESOLVED: no — nothing beyond the portal prompt
  in M1.9.** Judged resolvable on scope merit rather than pure UX taste: the prompt names
  the band at the exact decision moment, spatial position (west shop / center control /
  east band 2) disambiguates, `HubLabel` stays untouched, and the addition is purely
  additive later if S7's identity work motivates it. Confirmed by orchestrator adjudication.

- **Q5 — HG3 revert risk. RESOLVED: portal 2 survives an iso→top-down revert by
  construction.** Verified against the real artifacts: the placement is an instance
  transform in `hub.tscn` (H4's worklog records the revert as "one `tile_set` swap +
  painter revert" — node positions carry), both portals instance the one
  `departure_portal.tscn`, and the yard bounds (`YARD_X/Y` = wall colliders) are the same
  rectangle in both dressings, so `(220, -150)` stays interior ground either way. Keep the
  §2.5 residual: one visual spot-check post-revert; worst case is a position nudge.

- **Q6 — Return-from-band-2 flow. RESOLVED (ratified): nothing special — the return flow
  is unchanged.** Extract/death/timeout all auto-return via the existing `run_ended`
  observation, and because the staging slot is **consumed at dive start**, the selection
  implicitly resets to the control band on every return — the next dive requires a fresh
  portal interact. Band-chaining stays out of M1.9 scope. Confirmed by orchestrator
  adjudication.

- **Q7 — Debug-menu band selector. RESOLVED (ratified): no menu knob.** Band choice is
  not a `RunConfig` field and must stay off the MANIFEST/coverage/fingerprint surface;
  tests stage the key directly (`EventBus.dive_requested.emit(&"band_two")` or the
  GameState seam). Director band-forcing from the P-menu, if SG2 ever wants it, is a new
  task in the `debug_player_art_toggled` signal class — not S8. Confirmed by orchestrator
  adjudication.

- **Q8 — `enter_band` vocabulary. RESOLVED: the routing key, same as `start_run`.**
  `enter_band(band_key)` keeps `band_entered(band_id, depth)` consistent with
  `run_started` (both say `"near"`/`"band_two"`). Fresh-eyes re-grep confirms the safety
  premise: **no reader of `GameState.current_band` exists anywhere in `Game/`** — the only
  hits are its declaration (`game_state.gd:61`) and its `start_run` assignment; Telemetry's
  `_on_band_entered` (`telemetry.gd:159-163`) just stringifies the arg. §4.1's pseudocode
  stands as written.

### Integration note — §4.1 aligns to S3's `_resolve_band_profile()` seam (ratified)

S3 (Wave 3) lands the profile-resolution seam **in `main_game.gd`** as a single named
function, per S3's resolved Q2(a) (`design/M1_9_Tasks/S3_encounter_builder_integration.md`
§3.4/§6): `_resolve_band_profile() -> BandProfile` returning `band_greybox.tres` by const
path, called at the pipeline site and at `EncounterBuilder.populate(...)`. **S8's Wave-5
rewire is therefore a rewrite of that one function** — §4.1's `_resolve_band()` logic
(consume the GameState seam → `BAND_ROUTES` lookup → load, with the `&"near"`/
`band_greybox` fail-safe default) moves *inside/alongside* `_resolve_band_profile()`, and
the resolved **key** additionally replaces `BAND_ID` at the `start_run`/`enter_band` call
sites (`main_game.gd:288-289`). Resolve the profile **once per run start** and reuse it for
both the pipeline and the builder call (consume-on-read means a second resolution inside
one run start would fall back to the default — do not call `consume_pending_dive_band()`
twice). S3 also keeps `BAND_ID = &"near"` for the default dive's `start_run` tag in Wave 3
(S3's Q2b), so the telemetry cohort label never forks mid-version; S8 owns the band-stamp
story in Wave 5. Until S8 lands, nothing reads the GameState staging slot except S3's
default-only seam — the pre-declare stays inert exactly as §3 requires.

---

## Wave-5 close-out amendment (as-built, Director-dispositioned 2026-07-03)

- **Route-key handoff = `_band_route_key` member** set inside `_resolve_band_profile()` (Director:
  **Reviewed**) — supersedes the §4.1 Dictionary-returning-helper pseudocode; preserves S3's
  kept-signature seam the golden harness calls. The resolved key drives `start_run`/`enter_band`
  and the `band_id` telemetry stamp (verified on both routes).
