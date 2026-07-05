# T4 — Third Hub Portal + `band_three` Routing — Expanded Design Spec

**Milestone:** M1.10 (Wave 4 — reachability, small, sequential)
**Task id:** T4 · **blockedBy:** T3 (`band_three.tres` exists + Director-ratified identity/palette)
**Assignee:** general-purpose (programmer) · **Author:** game-director-designer (Phase-2 design)
**Status:** design (Phase 2 — Open Questions pending Phase-3 resolution; identity items blocked on T3 ratification)

> **What this doc is.** The Phase-2 design for M1.10's reachability task: a third
> `DeparturePortal` on the hub routing into `band_three` (the T3 cave band), with both
> existing portal paths **byte-identical**. It is the M1.9 S8 task repeated one band later
> (`design/M1_9_Tasks/S8_hub_portal_routing.md`) — and that repetition is the point.
> **S8 built the seam; T4 proves that adding a route to it is near-pure data.** S8's design
> ran ~500 lines because it had to invent the staging slot, the routing table, the
> per-instance portal identity machinery, and two contract tests. T4 invents nothing: its
> production-code delta is predicted at **one Dictionary line** plus **one scene-instance
> block**, and its worklog cost ledger is part of the evidence TG3 judges the scalability
> claim on.

---

## 0. Hard constraints (read first)

From the M1.10 breakdown (`design/M1_10_Tasks/M1.10_Breakdown.md` §Scope guardrails, §T4)
and the standing M1 contracts:

- **Three permanent controls, byte-identical:** the all-off `RunConfig` fingerprint
  **`e943ac9c8bc1`**, the `band_greybox` profile fingerprint, and the `band_two` profile
  fingerprint (M1.9's shipped content is now itself a control). T4 touches nothing on any
  generation path — the `BAND_ROUTES` addition is a new key beside untouched keys.
- **Both existing portal paths byte-identical** (breakdown §T4 DoD): `departure_portal.tscn`
  zero-byte diff (again), portal 1 and portal 2's `hub.tscn` lines untouched (git diff shows
  only the added node block), `test_hub_contract` H5/H6 green unmodified, `test_band_routing`
  C1–C6 green unmodified, `test_app_router` untouched.
- **No save-schema change.** The third portal is **always present** (M1.9 precedent,
  Director's standing directive — unlock persistence stays deferred). Band choice stays
  run-state through the existing staging seam; no `meta.sav`/`run.sav` field, no
  `schema_version` bump.
- **Primitives-only signal payloads** — the route key is a `StringName` through the
  existing `dive_requested(band_id)`; no new signal, no arity change (the S8 §RD Q1
  ratified contract holds — T4 adds an *emitter instance*, not a signal).
- **Single-writer:** T4 is Wave 4's sole writer of `main_game.gd` (T1, the version's
  designated writer, is done by Wave 4 — orchestrator confirms at dispatch), `hub.tscn`,
  and the two contract tests. `departure_portal.gd` should need **no edit at all**.
- **Placeholder art tint-only** — the third portal is a `modulate` over the existing
  gate/glow art via the S8-built `glow_tint`/`gate_tint` exports. No new art, no PixelLab.

---

## 1. Goal & design intent

**One sentence:** *the player stands in the hub and can now choose among three yards —
proving the S8 routing seam scales by data, not engineering.*

M1.10's thesis is "the M1.9 architectures scale along their second axis." For routing,
the second axis is trivial by design — S8 §1 declared the failure condition explicitly:
"if S8 needs more than a staging field, a mapping table, and a scene instance, the thesis
has failed." T4 is the measurement that the *increment* now costs only the last two of
those, both data-shaped: one mapping-table row, one scene instance. The worklog's
bespoke-code ledger (breakdown §Cross-cutting contracts) is the deliverable as much as
the portal is.

Second job, same as S8's: measurability. TG2 compares **three** bands keyed on the
`band_id` stamp in `run_started` rows — `"near"` / `"band_two"` / `"band_three"` — so the
stamp must be verified for the new key (it is already generic; see §2.3).

---

## 2. Research on the premise — what S8 built vs what T4 genuinely adds

All citations re-verified against the working tree at `main`, 2026-07-04 (post-FBM19c).

### 2.1 Reused VERBATIM from S8 (zero edits — the machinery T4 rides)

| # | Machinery | Where (file:line) | Why T4 needs no change |
|---|---|---|---|
| 1 | **The staging seam.** `dive_requested(band_id: StringName)` → GameState self-subscribes (`game_state.gd:219` `_on_dive_requested`) → stages `_pending_dive_band` (`:100`) → `consume_pending_dive_band()` (`:226`, consume-on-read). | `Game/systems/game_state.gd:93-100, 219-226` | Key-agnostic: it stages whatever `StringName` a portal emits. `&"band_three"` flows through untouched code. |
| 2 | **The routing resolution.** `_resolve_band_profile()` (`main_game.gd:414-434`): consume the staged key → `BAND_ROUTES` lookup → `load(BAND_PROFILE_DIR + profile_id + ".tres")` → unknown/empty key or missing file fail-safes to the `&"near"`/greybox control → resolved key kept on `_band_route_key` (`:103`) for the `start_run`/`enter_band` tags (`:324-325`). | `Game/scenes/game/main_game.gd:414-434` | Fully table-driven. A new `BAND_ROUTES` entry is the *entire* code change — the function body, fallback, and key-tagging are untouched. |
| 3 | **Per-instance portal identity.** `departure_portal.gd` root exports — `interactable_id` (`:19`), `band_id` (`:25`), `prompt_text`/`display_name` (`:33-34`), `glow_tint`/`gate_tint` (`:40-41`) — pushed down to the child `Interactable` + sprites in `_ready` (`:52-63`); the id-check + focused-target guard + lockout in `_on_interaction_requested` (`:70-84`) make same-scene instances coexist safely by construction. | `Game/scenes/hub/departure_portal.gd` | S8 built this exactly so later portals are *instance overrides*. Portal 3 is a `hub.tscn` node block with 6 property overrides; `departure_portal.tscn` ships a zero-byte diff for the second version running. |
| 4 | **The telemetry stamp.** `_on_run_started(band_id, seed)` writes `"band_id": String(band_id)` on every `run_started` row (`telemetry.gd:142, :167`); `band_depth_reached` mirrors it (`:182`). The value is the route key `start_run` was tagged with. | `Game/systems/telemetry/telemetry.gd:142-182` | Mirrors the signal arg verbatim — `"band_three"` lands the moment `start_run(&"band_three", seed)` runs. **Verify, don't build** (S8 §4.3, same conclusion). |
| 5 | **The contract tests.** `test_band_routing.gd` (C1–C6: staging consume-on-read, default, unknown-key fail-safe, routing-lands, full-scene stamp, wipe isolation) and `test_hub_contract.gd` (H1–H6: paths, walls, ground paint, interactable ids, portal-2 spec, portal-1 unchanged). | `Game/tests/test_band_routing.gd`, `Game/tests/test_hub_contract.gd` | T4 *extends* both with band-3 cases (§5); the existing checks rerun unmodified and ARE the byte-identical proof for portals 1–2. |
| 6 | **Debug-menu deck surface.** The config menu display-loads **every** `.tres` under `res://data/bands` for deck-membership chips (`config_menu.gd:212` `BANDS_DIR`, `:992` `_load_deck_membership` — `ResourceLoader.list_directory`, count-agnostic). | `Game/ui/config/config_menu.gd:207-212, 987-1003` | `band_three.tres` (T3) appears with **zero menu code** — FBM19b's IN-DECK chips pick up the Ambusher/Burrower deck automatically. Nothing for T4 to do; noted so the ledger can claim it. |
| 7 | **Router / EventBus / saves.** `app.gd` still discards the arg (owns no truth); `event_bus.gd` unchanged; no persistence anywhere near the choice. | — | S8 §4.4's "explicitly NOT built" list holds identically for T4. |

### 2.2 Genuinely NEW in T4 (the whole task)

1. **One `BAND_ROUTES` row** — `&"band_three": &"band_three"` (`main_game.gd:49-52` dict;
   the route-key vocabulary follows S8 §RD Q2: new bands use their profile id as the key;
   only portal 1's legacy `&"near"` is decoupled).
2. **One `hub.tscn` instance block** — `DeparturePortalBandThree` with the 6 identity
   overrides + position (§4.2). Placement is the one real *decision* in this task (§2.4).
3. **Test extensions** — `test_band_routing` gains a band-3 routing/stamp case;
   `test_hub_contract` gains H7 (portal 3 spec) + the H1/H4 list entries (§5).
4. **Two ratification-bound values** — prompt text (the T3 band name) and glow/gate tints
   (the T3 palette direction). Carried as named parameters until the Director ratifies
   T3's identity pitch (§Open Questions).

### 2.3 The routing chain for `&"band_three"`, hop by hop (all existing code)

Portal 3's child `Interactable` announces `&"portal_band_three"` → the portal's id-check
passes and it emits `EventBus.dive_requested.emit(&"band_three")`
(`departure_portal.gd:70-84`, its exported `band_id`) → GameState stages it
(`game_state.gd:219`) → the App router swaps to the dive, discarding the arg (`app.gd`,
unchanged) → `main_game._resolve_band_profile()` consumes the key, finds it in
`BAND_ROUTES`, loads `res://data/bands/band_three.tres` (T3's artifact; the profile's
`backend = "cave"` is invisible to routing — the pipeline dispatches it, T0/T1's work) →
`_band_route_key = &"band_three"` tags `start_run`/`enter_band` (`main_game.gd:324-325`)
→ `run_started.emit(&"band_three", seed)` → `telemetry.gd:167` stamps the row. Every hop
except the two data items already exists and already handled `&"band_two"`.

### 2.4 Hub placement analysis — where portal 3 sits (the one real decision)

**As-built anchors** (`Game/scenes/hub/hub.tscn`): walls at ±368/±232 (`:30-45`);
`PlayerSpawn (0, 120)` (`:48-49`); `DeparturePortal (0, -150)` (`:54-55`);
`DeparturePortalBandTwo (220, -150)` (`:57-64`); `ShopAnchor`/`HubShop (-220, -150)`
(`:67-70`). The **portal row** at `y = -150` is: shop west, band-1 gate center, band-2
gate east — S8 §2.5's "left = sell, middle = the yard you know, right = the new yard."

**The geometry that constrains the choice** (computed from the real shapes, not vibes):

- **Prompt-ambiguity threshold.** The portal's `Interactable` collision is a **48×64
  rect centered on the node origin** (`departure_portal.tscn`, `RectangleShape2D_portal`);
  the player's `InteractionDetector` is a **~36 px circle** (`interaction_detector.gd:6`).
  Two interactables can be in range simultaneously iff the gap between their rects is
  < 2×36 = 72 px. For same-row portals (aligned rects) the gap is `D − 48`, so same-row
  spacing must be **D ≥ 120 px** (S8's 220 px rhythm has 100 px of margin). The detector's
  nearest-with-hysteresis selection would still show ONE stable prompt inside a sliver,
  but a mis-focused portal is a **mis-dive** — a wrong-band run — so T4 holds S8's
  "never simultaneously in range" bar.
- **The dirt yard + transition band.** Interior dirt is `|x| ≤ 340, |y| ≤ 216`
  (`hub_ground.gd:44-46`, `_is_dirt` `:70-72`); boundary dirt cells paint grass-edge
  transition tiles (`:86-99`), whose 64 px diamond faces reach inward to about
  `|x| ≈ 288`. S8 valued ≥ 96 px of clearance so the gate never stands on patchy tiles.

**Why the row cannot simply extend (the scaling finding):** the next east row slot needs
`x ≥ 340` (the 120 px floor from portal 2 at 220) — which is *exactly* the yard bound:
the gate would stand astride the grass transition with its glow 28 px from the east wall
collider. Compressing instead (e.g. `(300, -150)`) leaves a 32 px rect gap — deep inside
the ambiguity threshold. Inserting mid-row (`(110, -150)`) is 10 px inside the threshold
*and* scrambles the depth-order reading (band 3 between bands 1 and 2). **The S8 row is
full at three structures.** This is itself a TG3 data point (breakdown TG3 watch-item:
"hub portal row scaling — when does the hub need a band-select surface?").

**Proposed position: `(110, -20)` — a forward-staggered second rank** (the row becomes a
portal *plaza*):

- **No prompt ambiguity, by the same math:** rect gap to gate 1 = √(62² + 66²) ≈ 90.6 px,
  and to gate 2 identically ≈ 90.6 px (symmetric between them) — both ≥ 72 px with ~18 px
  margin. Never in range with two portals at once.
- **Deep interior dirt:** `|x| = 110 ≤ 340`, `|y| = 20 ≤ 216` — nowhere near the
  transition band (≥ 178 px clearance); no wall interaction.
- **Clear lanes preserved:** the spawn (0, 120) → center-gate lane passes 86 px west of
  portal 3's rect (> the 36 px detector — no drive-by prompt, no collision: the portal
  root is layer/mask 0); the spawn→shop diagonal heads away entirely. The player is not
  in range of anything at spawn (portal 3's rect is 108+ px away).
- **Y-sort correct, no occlusion:** the hub root y-sorts by node origin and the portal's
  origin is its visual base (S8 §2.5). At `x = 110` portal 3's art (rect span x 86–134;
  gate art ~48 px) sits in the horizontal gap between gate 1 (x −24..24) and gate 2
  (x 196..244) — it draws in front (souther) of the back row but overlaps neither gate's
  sprite column, so both stay fully readable behind it.
- **Composition + depth reading:** the three dive gates now form a shallow triangle
  opening toward the spawn — back rank = the known yards (near center, Sump east),
  forward rank = the newest, deepest yard, nearest the player as the novelty. The
  spatial "rightmost = deeper" rule from S8 gives way to "forward = newest"; the prompt
  text carries the actual identity (as it already does for The Sump).
- **Scaling headroom:** the plaza pattern has exactly one more safe slot — the west
  mirror `(-110, -20)` (same 90.6 px gaps to gate 1 and the shop, if the shop's
  interactable is ≤ 48 px wide — verify then) — so **band 4 fits; band 5 forces the
  band-select surface**. That threshold should be recorded in TG3's watch-item.

**Rejected alternates (for the record):** `(340, -150)` row-extension — on the yard
bound/transition band, glow clips the wall margin; `(300, -150)` — 32 px rect gap, deep
ambiguity; `(110, -150)` mid-row insert — 10 px inside the ambiguity threshold + depth-order
scramble; `(220, -16)` column south of the Sump gate — 134 px gap (safe) but occludes the
southern approach to portal 2 and reads as a queue, not a choice.

### 2.5 Run/meta + lifecycle analysis — unchanged from S8

S8 §2.4's table transfers wholesale: the choice is a staging value (never persisted,
consumed at dive start), `wipe_meta()` can't touch it, return-from-band-3 is the same
auto-return (`run_ended` → hub → quota beat), a dive started without a portal falls back
to the control band. Death in the cave band = death anywhere (`fail_run` → pockets →
auto-return; the M1 lethality model per the breakdown). Nothing new to analyze — that is
the point of this task.

---

## 3. Pseudocode — the exact deltas

### 3.1 `main_game.gd` — the ONE production-code line

```gdscript
# Game/scenes/game/main_game.gd:49-52 — BAND_ROUTES gains one row. Everything
# else in the file (_resolve_band_profile :414-434, _band_route_key :103,
# start_run/enter_band :324-325, fallbacks) is UNTOUCHED.
const BAND_ROUTES: Dictionary = {
	&"near": &"band_greybox",
	&"band_two": &"band_two",
	&"band_three": &"band_three",     # T4 (M1.10): the cave band — T3's profile.
}
```

(The doc comment above the dict (`:43-47`) may gain a clause noting the T4 addition —
comment-only, no behavior.)

### 3.2 `hub.tscn` — the new instance block (scene data)

```
[node name="DeparturePortalBandThree" parent="." instance=ExtResource("3")]
position = Vector2(110, -20)               # §2.4 — forward-staggered second rank
interactable_id = &"portal_band_three"     # task-locked id (breakdown §T4)
band_id = &"band_three"                    # the routing key (BAND_ROUTES maps it 1:1)
prompt_text = "Dive — <BAND3_NAME>"        # T3-ratified band name (OQ-1)
display_name = "<BAND3_NAME> Portal"
glow_tint = <BAND3_GLOW>                   # T3-ratified palette direction (OQ-2)
gate_tint = <BAND3_GATE>                   # lighter wash of the same direction
```

`<BAND3_NAME>` / `<BAND3_GLOW>` / `<BAND3_GATE>` are **named parameters** resolved by the
Director's T3 identity ratification (§Open Questions) — each is a one-line override, so
the ratification blocks only the final value, not the build. `departure_portal.tscn`,
`departure_portal.gd`, `game_state.gd`, `event_bus.gd`, `app.gd`, `telemetry.gd`: **no
edits.** Portal 1 and portal 2's existing lines in `hub.tscn`: **no edits** (the diff is
purely additive).

### 3.3 `test_band_routing.gd` — extend (C1–C6 unmodified; add C7, extend C5)

```gdscript
const BAND_THREE_PATH := "res://data/bands/band_three.tres"

# --- C7 (new). Routing lands in band_three, distinct from both controls -------------
func _check_routing_lands_band_three() -> void:
    EventBus.dive_requested.emit(&"band_three")
    var mg := MainGame.new()
    var profile: BandProfile = mg._resolve_band_profile()
    assert profile.id == &"band_three"                 # BAND_ROUTES row works
    assert mg._band_route_key == &"band_three"         # the tag start_run will carry
    mg.free()
    # Route distinctness: one pipeline generate; fp != greybox fp AND != band_two fp
    # for the same SEED. (Same-seed-twice determinism + connectivity are T3's
    # test_band_three_profile — not duplicated here, per OQ-5.)
    var b3 := BandPipeline.new().generate(profile, SEED)
    assert b3.fingerprint() != <greybox same-seed fp>
    assert b3.fingerprint() != <band_two same-seed fp>
    # NOTE: cave bands emit synthetic pieces with p.instance possibly null —
    # _free_band's existing null-guard (test_band_routing.gd:201-206) already copes.

# --- C5 (extended). Full-scene stamp: add a third drive ------------------------------
#  ... after the existing &"band_two" and unstaged-&"near" drives:
    _run_started_band_ids.clear()
    EventBus.dive_requested.emit(&"band_three")
    game.start_new_run()                                # or a fresh scene instance
    await get_tree().process_frame
    assert _run_started_band_ids == [&"band_three"]     # run_started row source ==
    assert game._band_profile.id == &"band_three"       #   the route key (telemetry
                                                        #   mirrors it verbatim, :167)
```

C5's band-3 drive exercises the **full assembled dive** — pipeline cave dispatch (T0) +
cave materialisation (T1) headlessly — proving reachability end-to-end, which is exactly
the breakdown's "new portal headless contract check (… routes to `band_three` with its
fp)". The existing C1–C6 rerun unmodified = the byte-identical proof for the old routes.

### 3.4 `test_hub_contract.gd` — extend (H1–H6 unmodified; add H7)

```gdscript
# H1 path list += "DeparturePortalBandThree"
# H4 expected dict += "DeparturePortalBandThree": &"portal_band_three"
const BAND3_GLOW := <ratified color>        # pinned exactly, like EMBER_ORANGE (:25)

# --- H7 (new). Portal 3 spec — mirrors H5's shape exactly ---------------------------
func _check_portal_three(hub: Node2D) -> void:
    var portal := hub.get_node_or_null("DeparturePortalBandThree") as DeparturePortal
    assert portal.band_id == &"band_three"
    assert portal.interactable_id == &"portal_band_three"
    assert portal.position == Vector2(110, -20)
    assert |x| <= YARD_X and |y| <= YARD_Y                    # inside the dirt yard
    assert portal.prompt_text.contains(<BAND3_NAME>)          # prompt names the band
    assert portal.glow_tint.is_equal_approx(BAND3_GLOW)
    assert portal.glow_tint != Color.WHITE                    # distinct vs portal 1
    assert not portal.glow_tint.is_equal_approx(EMBER_ORANGE) # distinct vs portal 2
    # push-down landed: child Interactable prompt + PortalGlow/DiveGate modulate
    #   (same three sub-asserts as H5:141-151)

# H5 and H6 run UNMODIFIED — they ARE the "existing portals byte-identical" gate
# (portal 2 pinned at (220,-150)/ember-orange/The Sump; portal 1 pinned WHITE/&"near").
```

### 3.5 Verification runs (standing invocations)

```bash
godot --headless --path Game --import                                # parse gate
godot --headless --path Game --script res://tools/ci_smoke_test.gd   # SMOKE OK
godot --headless --path Game res://tests/test_run_config.tscn        # all-off fp e943ac9c8bc1
godot --headless --path Game res://tests/test_band_routing.tscn      # C1–C7
godot --headless --path Game res://tests/test_hub_contract.tscn      # H1–H7
godot --headless --path Game res://tests/test_band_three_profile.tscn  # T3's (rerun)
# never run headless instances concurrently (import-lock); test_app_router + bandgen
# determinism suites rerun unmodified in the wave's full sweep.
```

---

## 4. Files touched (T4, Wave 4)

| File | Change | Nature |
|---|---|---|
| `Game/scenes/game/main_game.gd` | +1 `BAND_ROUTES` row (§3.1) | **code (1 line)** |
| `Game/scenes/hub/hub.tscn` | +1 instance block, ~8 lines (§3.2) | scene data |
| `Game/tests/test_band_routing.gd` | +C7, C5 extension (§3.3), ~50 lines | test |
| `Game/tests/test_hub_contract.gd` | +H7, H1/H4 entries (§3.4), ~40 lines | test |
| `worklogs/<date>-T4-general-purpose.md` | worklog + **bespoke-code ledger** | meta |

**Cost-ledger prediction (the task's headline number):** bespoke non-data, non-test
production code = **1 line** (the `BAND_ROUTES` entry; plus optional comment lines).
Scene-data delta ≈ 8 lines. Test delta ≈ 90 lines. Compare S8, which needed the staging
seam (`game_state.gd`), the resolver + routing table (`main_game.gd`), the portal
identity exports + push-down (`departure_portal.gd`), and both tests from scratch. If the
actual ledger materially exceeds this prediction, that overrun is a TG3 finding in itself.

## 5. Definition of done (concrete — per breakdown §T4)

1. **Controls byte-identical:** all-off fp `e943ac9c8bc1` unmoved; `band_greybox` +
   `band_two` fingerprints unmoved (routing test C4 + bandgen suites rerun);
   `departure_portal.tscn` zero-byte diff; portal 1/portal 2 `hub.tscn` lines untouched;
   `test_hub_contract` H5/H6 + `test_band_routing` C1–C6 + `test_app_router` green
   **unmodified**.
2. **New portal routes:** interacting `&"portal_band_three"` stages `&"band_three"`; the
   dive generates from `data/bands/band_three.tres` (H7 + C7 + C5-extension green);
   full-scene headless drive lands in the cave band and returns to the hub through the
   unchanged auto-return.
3. **Stamp:** `run_started` rows carry `band_id == "band_three"` for portal-3 dives
   (asserted at the signal, C5-extension; telemetry mirrors the arg verbatim,
   `telemetry.gd:167`); spot-check one JSONL row.
4. **Always present, no save change:** no `schema_version` diff, no persisted key; wipe
   isolation (C6) green.
5. Import + smoke + suite sweep green; worklog with the **bespoke-code ledger**, commit
   SHA, and Design-deviations section; board + STATUS mirrored.

---

## Open Questions

> Phase-3 resolvers: resolve on technical merit where possible; items marked **Director**
> or **blocked on T3** are not self-resolvable here.

1. **Prompt text + display name — BLOCKED ON T3 RATIFICATION (Director — tone).** The
   prompt must name the band (breakdown §T4); T3 pitches 2–3 identities and the Director
   picks. T4 carries `<BAND3_NAME>` as a named parameter; folding the winner in is a
   one-line `hub.tscn` override + the H7 string pin (mirrors S8's "Dive — Band 2" →
   "Dive — The Sump" flow). *Recommendation: same pattern as portal 2 — `"Dive — <Name>"`,
   name only, no depth signposting in the prompt (the plaza position + tint carry
   novelty; depth-signposting inside the cave is already a TG2/TG3 watch-item).*
2. **Glow/gate tint — BLOCKED ON T3 RATIFICATION (Director — tone, coupled to the
   palette pitch).** The tint must pair with `band_three.tres`'s `palette_tint`
   direction (T3's deliverable) and separate from BOTH existing portals — portal 1's
   verified violet glow (`(193, 85, 255)` dominant pixel, S8 §RD) and portal 2's
   ember-orange `Color(1.0, 0.58, 0.24)`. The remaining clean hue region is the
   green–teal family; candidates to key to T3's pitches: **bioluminal cave-teal
   `Color(0.30, 0.90, 0.65)`** (cold, deep, alien — fits "deeper band" escalation and
   caves-without-sky) or **acid-green `Color(0.55, 0.95, 0.35)`** (S8's unused alternate;
   hotter, more toxic read). Gate tint = a lighter wash of the same hue (portal 2
   precedent). *Recommendation: cave-teal, unless T3's ratified palette says otherwise —
   the portal should preview the band's own tint language.*
3. **Placement `(110, -20)` — forward-staggered second rank (needs Director eyeball,
   geometry pre-resolved).** The math in §2.4 is checkable (ambiguity threshold 120 px
   same-row / 72 px rect-gap; yard transition band at |x| ≈ 288+): the S8 row is full,
   and `(110, -20)` is the slot that keeps zero prompt ambiguity, deep interior dirt,
   clear lanes, and both back gates unoccluded. What is NOT pure geometry is the
   *composition read* — plaza-forward ("newest yard nearest you") vs the S8 row's
   "rightmost = deeper." *Recommendation: accept `(110, -20)`; the Director sanity-checks
   the read in the TG1 playtest build (a position nudge is a one-line override + one H7
   constant — never a routing change).* Alternates analyzed + rejected in §2.4.
4. **Should H7 pin pairwise tint distinctness?** H5 pins portal 2 to ember-orange
   exactly; H7 as drafted pins portal 3's ratified color AND asserts it differs from
   WHITE and from `EMBER_ORANGE`. *Recommendation: yes, keep both distinctness asserts —
   they encode "visually distinct" (the breakdown's words) as a contract, cheap and
   future-proofing against a careless retint. Resolve on merit.*
5. **Does the routing test duplicate T3's determinism matrix?** C7 as drafted asserts
   route-resolution + fp *distinctness* only (one generate), leaving same-seed-twice
   determinism + connectivity to T3's `test_band_three_profile`. *Recommendation: keep
   that split — one owner per assertion, no double-maintenance; C5's full-scene drive
   already proves the route end-to-end. Resolve on merit.*
6. **Portal-row scaling watch-item wording (scope — confirm, not build).** T4 should
   hand TG3 a concrete threshold: *the plaza has exactly one safe slot left
   (`(-110, -20)`, band 4, pending a shop-shape check); band 5 forces a band-select
   surface* (dialogue/UI at one gate, or a portal-hall scene). Confirm this is recorded
   as a TG3 watch-item line, not designed here. *Recommendation: confirm as stated.*
7. **Wave-4 `main_game.gd` writer handoff (process — orchestrator confirms).** The
   breakdown names T1 the version's sole `main_game.gd` writer ("Wave 2 — nobody else
   ever") yet §T4 requires the `BAND_ROUTES` row in that file. *Recommendation: read the
   single-writer rule as per-wave (its heading says "per wave"): T1 owns Waves 1–3; T4 is
   the designated Wave-4 writer of exactly one line, with T1 long merged. The orchestrator
   confirms no other Wave-4 task touches the file (none exists). Flag in the T4 worklog
   if anything more than the one dict row proves necessary — that would be both a
   deviation and a scalability finding.*

---

*Phase-3 resolution + Director ratification of OQ-1/OQ-2 (via T3's pitch pick) and OQ-3
land here as a `## Resolved Decisions` section before T4 dispatches.*
