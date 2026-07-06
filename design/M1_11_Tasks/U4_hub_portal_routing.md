# U4 — Fourth Hub Portal + `band_four` Routing — Expanded Design Spec

**Milestone:** M1.11 (Wave 4 — reachability, small, sequential)
**Task id:** U4 · **blockedBy:** U3 (`band_four.tres` exists + Director-ratified identity/palette)
**Assignee:** general-purpose (programmer) · **Author:** general-purpose (Phase-2 design)
**Status:** design (Phase 2 — Open Questions pending Phase-3 resolution; identity items blocked on U3 ratification)

> **What this doc is.** The Phase-2 design for M1.11's reachability task: a fourth
> `DeparturePortal` on the hub routing into `band_four` (the U3 open-field band), with all
> three existing portal paths **byte-identical**. It is T4 repeated one band later
> (`design/M1_10_Tasks/T4_hub_portal_routing.md` — the direct template) — and the repetition
> is again the point. S8 built the seam (~500-line design), T4 proved the increment is one
> `BAND_ROUTES` row + one scene block (**1 bespoke production line**, shipped exactly as
> predicted). U4 is the N=3 measurement of that same increment: predicted cost identical —
> **one Dictionary line + one ~9-line scene-instance block + test extensions**. The worklog's
> bespoke-code ledger is part of the evidence UG3 judges the "content = data, compounding"
> claim on.
>
> **U4 also closes a door.** The D-RAT-9 mirror slot `(-110, -20)` is the plaza's **LAST
> safe slot** (§2.4 recomputes and confirms). After U4 the hub is full: **band 5 forces a
> band-select surface** — that threshold is carried forward as a UG3 watch-item (§6, OQ-4
> proposes pinning it as a contract).

---

## 0. Hard constraints (read first)

From the M1.11 breakdown (`design/M1_11_Tasks/M1.11_Breakdown.md` §Scope guardrails, §U4)
and the standing M1 contracts:

- **Four permanent controls, byte-identical:** the all-off `RunConfig` fingerprint
  **`e943ac9c8bc1`**, and the `band_greybox`, `band_two`, **and `band_three`** profile
  fingerprints (M1.10's shipped cave band is now itself a control). U4 touches nothing on
  any generation path — the `BAND_ROUTES` addition is a new key beside untouched keys.
- **All three existing portal paths byte-identical** (breakdown §U4 DoD):
  `departure_portal.tscn` zero-byte diff (third version running); portal 1/2/3's `hub.tscn`
  lines untouched (git diff shows only the added node block); `test_hub_contract` H5/H6/H7
  green unmodified; `test_band_routing` C1–C7 + the existing C5 drives green unmodified;
  `test_app_router` untouched.
- **No save-schema change.** The fourth portal is **always present** (standing Director
  directive — unlock persistence stays deferred). Band choice stays run-state through the
  existing staging seam; no `meta.sav`/`run.sav` field, no `schema_version` bump.
- **Primitives-only signal payloads** — the route key is a `StringName` through the
  existing `dive_requested(band_id)`; no new signal, no arity change. U4 adds an *emitter
  instance*, not a signal (the S8 §RD Q1 contract, held twice already).
- **Single-writer, per-wave:** U4 is Wave 4's sole writer of `main_game.gd` (U1, the
  version's designated writer, is done by Wave 2 — orchestrator confirms at dispatch; the
  per-wave reading was ratified at T4 §RD OQ-7 and the M1.11 breakdown already words it
  per-wave: "U4 writes exactly the one `BAND_ROUTES` row + the hub portal instance in
  Wave 4"), `hub.tscn`, and the two contract tests. `departure_portal.gd` needs **no edit**.
- **Placeholder art tint-only** — the fourth portal is a `modulate` over the existing
  gate/glow art via the S8 `glow_tint`/`gate_tint` exports. No new art, no PixelLab —
  **and the tint must be chosen inside the multiply-math gamut** (§2.5); a hue outside it
  is an art-retone follow-up task, not a U4 tint.

---

## 1. Goal & design intent

**One sentence:** *the player stands in the hub and can now choose among four yards —
the third consecutive proof that the S8 routing seam scales by data, at flat (not rising)
marginal cost.*

M1.11's thesis is "the seams hold at N = 3, with declining marginal cost." For routing the
trend line so far is: S8 (build the seam, ~"a staging field, a mapping table, a scene
instance") → T4 (**1 bespoke line** + 8-line scene block + ~90 test lines, exactly as its
design predicted). U4's prediction is the same shape again: one `BAND_ROUTES` row, one
scene block, two test extensions. If the actual ledger materially exceeds that, the overrun
is itself a UG3 finding.

Second job, unchanged from S8/T4: measurability. UG2 compares **four** bands keyed on the
`band_id` stamp in `run_started` rows — `"near"` / `"band_two"` / `"band_three"` /
`"band_four"` — so the stamp must be *verified* (not built) for the new key; §2.1 row 4
confirms it is truly key-generic.

Third job, new to U4: **record the plaza-full threshold as reality, not prediction.** T4
§RD OQ-6 reserved `(-110, -20)` for band 4 "pending a shop-shape check" (done: 48×64) and
declared band 5 the forcing function for a band-select surface. U4 spends that reservation.
The doc verifies the slot's geometry against the as-built hub (§2.4) and proposes making
"the plaza is full" a *contract* (OQ-4) so band 5 cannot land silently.

---

## 2. Research on the premise — what already exists vs what U4 genuinely adds

All citations verified against the working tree at `main`, 2026-07-06 (post-FBM-A2,
`d04bd13`/`f555f5c`). Art claims pixel-checked with PIL (§2.4/§2.5); geometry recomputed
from the shipped scene files, not inherited from T4's text.

### 2.1 Reused VERBATIM (zero edits — the machinery U4 rides)

| # | Machinery | Where (file:line) | Why U4 needs no change |
|---|---|---|---|
| 1 | **The staging seam.** `dive_requested(band_id: StringName)` → GameState self-subscribes (`game_state.gd:134` connect, `:219-220` `_on_dive_requested`) → stages `_pending_dive_band` (`:100`) → `consume_pending_dive_band()` (`:226-228`, consume-on-read). | `Game/systems/game_state.gd:100, 134, 219-228` | Key-agnostic: it stages whatever `StringName` a portal emits. `&"band_four"` flows through untouched code. |
| 2 | **The routing resolution.** `_resolve_band_profile()` (`main_game.gd:429-441`): consume the staged key → `BAND_ROUTES` lookup (`:55-59`, three rows today) → `load(BAND_PROFILE_DIR + profile_id + ".tres")` → unknown/empty key or missing file fail-safes to the `&"near"`/greybox control → resolved key kept on `_band_route_key` (`:110`) for the `start_run`/`enter_band` tags (`:331-332`). | `Game/scenes/game/main_game.gd:55-59, 110, 331-332, 429-441` | Fully table-driven. A new `BAND_ROUTES` entry is the *entire* code change — function body, fallback, and key-tagging untouched. Proven twice (`&"band_two"`, `&"band_three"`). |
| 3 | **Per-instance portal identity.** `departure_portal.gd` root exports — `interactable_id` (`:19`), `band_id` (`:25`), `prompt_text`/`display_name` (`:33-34`), `glow_tint`/`gate_tint` (`:40-41`) — pushed down to the child `Interactable` + sprites in `_ready` (`:52-63`); id-check + focused-target guard + fat-finger lockout in `_on_interaction_requested` (`:70-84`) make same-scene instances coexist safely by construction. | `Game/scenes/hub/departure_portal.gd` | Portal 4 is a `hub.tscn` node block with 7 property overrides (position + 6 identity values) — exactly the shape portals 2 and 3 shipped as (`hub.tscn:57-64`, `:66-73`). `departure_portal.tscn` ships a zero-byte diff for the third version running. |
| 4 | **The telemetry stamp — verified truly key-generic.** `_on_run_started(band_id, seed)` writes `"band_id": String(band_id)` on every `run_started` row (`telemetry.gd:142` handler, `:167` the stamp); no key whitelist, no per-band branch anywhere in the file — the value is whatever route key `start_run` was tagged with (`main_game.gd:331`). `band_depth_reached` mirrors it (`telemetry.gd:178-182`). | `Game/systems/telemetry/telemetry.gd:142, 167, 178-182` | `"band_four"` lands on run rows the moment `start_run(&"band_four", seed)` runs. **Verify, don't build** — the C5-style stamp drive (§3.4) is the verification. |
| 5 | **The contract tests.** `test_band_routing.gd` (C1–C7 + the three C5 stamp drives: staging consume-on-read, default, unknown-key fail-safe, band-2 routing+determinism, band-3 distinct-fp, full-scene stamps for band_two/near/band_three, wipe isolation) and `test_hub_contract.gd` (H1–H7: paths, 4 walls, 963-cell iso paint, **4 interactable ids**, portal-2/1/3 spec pins incl. exact tint pins `EMBER_ORANGE` `:25` / `CAVE_TEAL` `:26`). | `Game/tests/test_band_routing.gd`, `Game/tests/test_hub_contract.gd` | U4 *extends* both (§3.3/§3.4); the existing checks rerun unmodified and ARE the byte-identical proof for portals 1–3. No other test pins hub interactable counts (grepped: only `test_hub_contract.gd` asserts the portal set). |
| 6 | **Debug-menu deck surface.** The config menu display-loads every `.tres` under `res://data/bands` for count-agnostic deck-membership chips. `band_four.tres` (U3) appears with **zero menu code** — the Lobber/Sentry IN-DECK chips light up automatically. | `Game/ui/config/config_menu.gd` (`BANDS_DIR` scan) | Nothing for U4 to do; noted so the ledger can claim it. |
| 7 | **Router / EventBus / saves.** `app.gd` discards the arg (owns no truth); `event_bus.gd` unchanged; no persistence anywhere near the choice. | — | S8's "explicitly NOT built" list holds for the third time. |

### 2.2 Genuinely NEW in U4 (the whole task)

1. **One `BAND_ROUTES` row** — `&"band_four": &"band_four"` (`main_game.gd:55-59`; route-key
   vocabulary per S8 §RD Q2: new bands use their profile id as the key; only portal 1's
   legacy `&"near"` is decoupled).
2. **One `hub.tscn` instance block** — `DeparturePortalBandFour` at `(-110, -20)` with the
   6 identity overrides (§3.2). Unlike T4, placement is **not** a decision here — D-RAT-9
   already reserved the slot; U4's job is to *verify* the reservation against the as-built
   hub (§2.4) and spend it.
3. **Test extensions** — `test_band_routing` gains C8 (band-4 distinct-fp vs all three
   others) + a fourth C5 stamp drive + a C6 band-4 wipe round; `test_hub_contract` gains H8
   (portal-4 spec) + the H1/H4 list entries → **5 interactables** (§3.3).
4. **Two ratification-bound values** — prompt text (the U3 band name) and glow/gate tints
   (chosen inside §2.5's feasible gamut, paired to the U3 palette pitch). Carried as named
   parameters until the Director ratifies U3's identity — each is a one-line override, so
   ratification blocks only the final value, never the build.

### 2.3 The routing chain for `&"band_four"`, hop by hop (all existing code)

Portal 4's child `Interactable` announces `&"portal_band_four"` → the portal's id-check +
focus guard pass and it emits `EventBus.dive_requested.emit(&"band_four")`
(`departure_portal.gd:70-84`, its exported `band_id`) → GameState stages it
(`game_state.gd:219-220`) → the App router swaps to the dive, discarding the arg (`app.gd`,
unchanged) → `main_game._resolve_band_profile()` consumes the key, finds it in
`BAND_ROUTES`, loads `res://data/bands/band_four.tres` (U3's artifact; the profile's
`backend = "scatter"` is invisible to routing — the pipeline dispatches it, U0's work; the
arena materialises on U1's verified synthetic-piece path) → `_band_route_key = &"band_four"`
tags `start_run`/`enter_band` (`main_game.gd:331-332`) → `run_started.emit(&"band_four",
seed)` → `telemetry.gd:167` stamps the row. Every hop except the two data items already
exists and has already handled `&"band_two"` **and** `&"band_three"`.

### 2.4 Mirror-slot geometry — the D-RAT-9 reservation verified against the as-built hub

**As-built anchors** (`Game/scenes/hub/hub.tscn`, read 2026-07-06): walls at ±368/±232
(`:32-46`); `PlayerSpawn (0, 120)` (`:48-49`); portal 1 `(0, -150)` (`:54-55`); portal 2
`(220, -150)` (`:57-58`); **portal 3 `(110, -20)`** (`:66-67`) — the forward-staggered
second rank shipped exactly as T4 designed; shop `(-220, -150)` (`:75-79`). The portal
`Interactable` collision is a **48×64 rect centered on the node origin**
(`departure_portal.tscn:8-9`); the shop's is **also exactly 48×64** (`shop.tscn:10-11` —
T4 §RD OQ-6's pending check, confirmed); the player's `InteractionDetector` is a **36 px
circle** (`interaction_detector.tscn:7`). Two interactables can be simultaneously in range
iff their rect gap < 2×36 = **72 px**. Dirt yard: `|x| ≤ 340, |y| ≤ 216`
(`hub_ground.gd:44-45`), grass-edge transition tiles at the boundary.

Portal 4 at `(-110, -20)` → interact rect x **[-134, -86]**, y **[-52, 12]**. Verified
point by point:

- **Prompt ambiguity — clean, the exact mirror of portal 3's numbers:** rect gap to
  portal 1 `(0,-150)` = √((110−48)² + (130−64)²) = √(62² + 66²) ≈ **90.6 px**; gap to the
  shop `(-220,-150)` identically ≈ **90.6 px** (the shop rect being 48×64 makes the mirror
  exact); gap to portal 3 `(110,-20)` = 220 − 48 = **172 px**. All ≥ 72 px — never in range
  of two interactables at once.
- **Deep interior dirt:** `|x| = 110 ≤ 340`, `|y| = 20 ≤ 216` — nowhere near the grass
  transition band; no wall interaction (nearest wall collider 234 px away).
- **No physical collision at the slot:** the portal root Area2D is layer/mask 0, the child
  `Interactable` is layer 4 / mask 0 (`departure_portal.tscn:12-13, 27-28`) — the portal
  never blocks movement; no StaticBody near the slot. Nothing to conflict with.
- **Spawn lanes:** the player at spawn `(0, 120)` is ≈ 138 px from portal 4's rect
  (> 36 px — no prompt at spawn). The spawn → portal-1 lane (x = 0 vertical) passes 86 px
  east of the rect — clear, symmetric to portal 3's clear lane.
- **THE TRANSIT-PROMPT CAVEAT MIRRORS — onto the *shop* lane (flag loudly).** T4 §RD
  correction 3 found the spawn → portal-2 diagonal crosses portal 3's rect. The mirror is
  exact and *higher-traffic*: the straight spawn `(0,120)` → shop `(-220,-150)` diagonal
  **passes through portal 4's interact rect** — parametrised P(t) = (−220t, 120−270t), the
  rect's y-band [−52, 12] is t ∈ [0.40, 0.637], where x sweeps −88 → −140; the rect spans
  x [−134, −86], so the line is inside the rect for x ∈ [−134, −88] (e.g. t = 0.45 →
  (−99, −1.5)). A player beelining spawn→shop — **the most-walked lane in the loop (every
  post-run sell trip)** — transits portal 4's prompt zone, and a spammed/early F-press
  mid-walk is a band-4 mis-dive. Checked exhaustively (mirroring T4's check): the 72 px
  ambiguity bar forces any west second-rank slot to |x₀| ∈ [76.8, 143.2] (gap to portal 1:
  √((|x₀|−48)² + 66²) ≥ 72 → |x₀| ≥ 76.8; gap to shop: 220 − |x₀| − 48 ≥ 28.8 → |x₀| ≤
  143.2), and every 48-wide rect centered in that window intersects the diagonal's
  [−140, −88] sweep (miss requires x₀ < −164 or x₀ > −64, both outside the window) — **no
  valid mirror slot avoids the shop diagonal**; it is inherent to the plaza pattern, not a
  defect of `(-110, -20)`. Mitigations already in place (same three as portal 3's, shipped
  and playtested through TG1): never simultaneously in range (the 90.6 px gaps),
  nearest-with-hysteresis focus (`SWITCH_RATIO = 0.9`), and the prompt explicitly names the
  band. Recorded as a **UG1 Director-eyeball item** (OQ-3), not a blocker — and if the
  Director judges the *pair* of transit lanes mis-dive-prone, the answer is the band-select
  surface pulled forward (the plaza is full anyway), never a slot shuffle.
- **Y-sort + art overlap — cleaner than T4 feared (pixel-checked).** T4 §RD OQ-6 warned the
  mirror slot's art "would visually overlap the shop's SortTable sprite … will read
  crowded; the band-4 task should re-eyeball." Re-eyeballed with real opaque bboxes
  (PIL, 2026-07-06): portal 4's glow (`portal_glow.png` 64×64 at node offset (0,−65) →
  opaque world x [−134, −87], y [−111, −59]) vs the SortTable (`sort_table.png` 64×48 at
  shop-relative (92, 42) offset (0,−14) → opaque world x [−157, −100], y [−134, −109])
  overlap in a **~34×3 px sliver** at the glow's top edge; the gate art (`dive_gate.png`
  160×96, opaque world x [−184, −37], y [−92, −31]) clears the SortTable (no y overlap)
  and the shack (opaque x ≤ −148, y ≤ −121 — x-overlap only, vertically clear). Hub-root
  y-sort orders by node origin (portal −20 vs shop −150) so the portal draws in front of
  the whole shop cluster regardless. Portal 1's art (opaque y ≤ −161) is vertically clear
  of portal 4's (y ≥ −111). **Verdict: the slot is visually clean; T4's "crowded" caveat
  is retired to a routine UG1 glance.**
- **Composition read:** the plaza becomes symmetric — back rank = the first two yards,
  forward rank = the two deep yards flanking the walk-in, newest on the west. The
  "forward = newer/deeper" read T4 established now applies to a *pair*; prompt text +
  glow tint carry the identity (as they already do for The Sump / The Warren).

**The plaza is now FULL.** With five 48×64 interactables and the 72 px bar, no sixth slot
exists inside the yard that keeps zero prompt ambiguity and clear lanes (back row full at
three structures — T4 §2.4; second rank full at two — the window computation above admits
exactly one slot per side). **Band 5 forces a band-select surface.** Carry to UG3 verbatim;
OQ-4 proposes pinning it as a test contract.

### 2.5 Glow-hue constraint analysis — the feasible gamut under the multiply (U4 owns the set; U3 picks within it)

**The seam, stated explicitly:** U4 (this doc) derives the *feasible hue space* from the
as-built art math; **U3's identity pitches must pick their portal glow from inside this
set** (or explicitly buy the escape hatch below). This is the same reconciliation the
M1.10 amendment-12 color story enforced for T3↔T4, run proactively this time so the
Director ratifies one coherent identity+glow bundle, once.

**The math (re-verified by pixel count, 2026-07-06):** `portal_glow.png`'s dominant opaque
pixel is exactly **(193, 85, 255)** → normalized **(0.757, 0.333, 1.0)**; alpha-weighted
mean (0.42, 0.17, 0.59) — the art is violet-dominant throughout. `modulate` multiplies
per-channel, so a tint `(t_r, t_g, t_b)` renders the dominant pixel at
`(0.757·t_r, 0.333·t_g, 1.0·t_b)`: **rendered red caps at 0.76, rendered green caps at
0.33, blue is free** (for tints ≤ 1.0 — amendment 12's "green caps at 0.33").

**Taken renders (the three shipped portals + their pins):**

| Portal | `glow_tint` (pinned) | Rendered dominant | Read |
|---|---|---|---|
| 1 (near) | WHITE (identity) | (0.76, 0.33, 1.0) | bright violet — the art's native color |
| 2 (The Sump) | `Color(1.0, 0.58, 0.24)` — `EMBER_ORANGE`, `test_hub_contract.gd:25` | (0.76, 0.19, 0.24) | red-ember |
| 3 (The Warren) | `Color(0.30, 0.90, 0.65)` — `CAVE_TEAL`, `test_hub_contract.gd:26` | (0.23, 0.30, 0.65) | deep cyan-teal |

**Struck outright by the math (do not pitch these):** greens and golds (G caps at 0.33 —
acid-green was already struck at T4 §RD correction 5 as "muddy gray-brown"; any gold/amber
renders as ember-adjacent tan); whites/pales (any near-neutral tint renders violet =
portal 1); pure reds (collide with portal 2's ember render).

**The feasible free hues (the shortlist U3 picks from — OQ-1):**

1. **Saturated indigo/ultramarine — `Color(0.15, 0.25, 1.0)`** → renders ≈ (0.11, 0.08,
   1.0): the deepest, most saturated render still free — max-blue with R and G crushed,
   clearly darker/purer than portal 1's light violet (R 0.76 vs 0.11) and bluer/brighter
   than portal 3's teal (G 0.30/B 0.65 vs G 0.08/B 1.0). Fits a "wrong, too-open expanse /
   deepest band" read (a cold void-blue). Risk: it is the *third* blue-family glow on the
   plaza — hue-wise distinct, but the Director should eyeball all four at once at UG1.
2. **Magenta/fuchsia — `Color(1.0, 0.0, 0.55)`** → renders ≈ (0.76, 0.0, 0.55): hot
   pink-magenta — G = 0 kills the lavender lightness that defines portal 1's violet
   (G 0.33), so it reads punchier and pinker. Risk: it is portal 1's *neighbor* hue;
   weaker separation than option 1 at small glow sizes.

Both candidates pass pairwise distinctness against all three shipped renders; option 1 is
this doc's recommendation on separation grounds. Gate tint = a lighter wash of the same
hue (portal 2/3 precedent — e.g. option 1's wash ≈ `Color(0.55, 0.62, 1.0)`).

**Escape hatches (recorded, NOT recommended for U4):** (a) an **art retone** (PixelLab,
Director-gated, out of U4 scope — the standing amendment-12 note) escapes the multiply
cage entirely if U3's ratified identity demands green/gold/white-hot; the H8 assert pins
the `glow_tint` *property*, so a later retone would not break the contract test. (b) an
**overdriven tint** (Godot modulate accepts channels > 1.0 — e.g. `Color(0.3, 3.0, 0.9)`
lifts the dominant pixel's green to 1.0) can synthesize a green read, but it clips the
art's gradient shading into flat blowout and is untested territory for the pinned-tint
contract pattern; if the Director wants green, retone properly instead.

### 2.6 Run/meta + lifecycle analysis — unchanged for the third time

S8 §2.4 / T4 §2.5 transfer wholesale: the choice is a staging value (never persisted,
consumed at dive start), `wipe_meta()` cannot touch it (C6 proves it stays), return from
band 4 is the same auto-return (`run_ended` → hub → quota beat), a dive started without a
portal falls back to the control band, death in the open field = death anywhere (`fail_run`
→ pockets → auto-return). Nothing new to analyze — which is the measurement.

---

## 3. Pseudocode — the exact deltas

### 3.1 `main_game.gd` — the ONE production-code line

```gdscript
# Game/scenes/game/main_game.gd:55-59 — BAND_ROUTES gains one row. Everything
# else in the file (_resolve_band_profile :429-441, _band_route_key :110,
# start_run/enter_band tags :331-332, fallbacks) is UNTOUCHED.
const BAND_ROUTES: Dictionary = {
	&"near": &"band_greybox",       # (existing, verbatim)
	&"band_two": &"band_two",       # (existing, verbatim)
	&"band_three": &"band_three",   # (existing, verbatim)
	&"band_four": &"band_four",     # U4 (M1.11): the open-field band — U3's profile.
}
```

*(Rendered literally: only the `&"band_four": &"band_four",` line is added; the three
existing rows and the `:49-53` doc comment stay byte-identical — the comment may gain a
one-clause U4 note, comment-only.)*

### 3.2 `hub.tscn` — the new instance block (scene data, ~9 lines)

```
[node name="DeparturePortalBandFour" parent="." instance=ExtResource("3")]
position = Vector2(-110, -20)              # §2.4 — the D-RAT-9 mirror slot, verified
interactable_id = &"portal_band_four"      # task-locked id (breakdown §U4)
band_id = &"band_four"                     # the routing key (BAND_ROUTES maps it 1:1)
prompt_text = "Dive — <BAND4_NAME>"        # U3-ratified band name (OQ-2)
display_name = "<BAND4_NAME> Portal"
glow_tint = <BAND4_GLOW>                   # U3-ratified pick from §2.5's feasible set (OQ-1)
gate_tint = <BAND4_GATE>                   # lighter wash of the same hue
```

`<BAND4_NAME>` / `<BAND4_GLOW>` / `<BAND4_GATE>` are **named parameters** resolved by the
Director's U3 identity ratification — each a one-line override, so ratification blocks only
the final values, not the build. `departure_portal.tscn`, `departure_portal.gd`,
`game_state.gd`, `event_bus.gd`, `app.gd`, `telemetry.gd`: **no edits.** Portals 1–3's
existing `hub.tscn` lines: **no edits** (purely additive diff; insert the block after
`DeparturePortalBandThree` at `hub.tscn:66-73`).

### 3.3 `test_hub_contract.gd` — extend (H1–H7 unmodified; add H8; 4 → 5 interactables)

```gdscript
# H1 path list (:69-71)  += "DeparturePortalBandFour"
# H4 expected dict (:106-111) += "DeparturePortalBandFour": &"portal_band_four"   # → 5 ids
# OK print (:56) reworded: "... + 5 interactables ..." + a portal-4 clause.
const BAND4_GLOW := <ratified color>       # pinned exactly, like EMBER_ORANGE :25 / CAVE_TEAL :26

# --- H8 (new). Portal 4 spec — mirrors H7 (:188-221) exactly -------------------------
func _check_portal_four(hub: Node2D) -> void:
    var portal := hub.get_node_or_null("DeparturePortalBandFour") as DeparturePortal
    assert portal.band_id == &"band_four"
    assert portal.interactable_id == &"portal_band_four"
    assert portal.position == Vector2(-110, -20)
    assert |x| <= YARD_X and |y| <= YARD_Y                     # inside the dirt yard
    assert portal.prompt_text.contains(<BAND4_NAME>)           # prompt names the band
    assert portal.glow_tint.is_equal_approx(BAND4_GLOW)        # exact ratified pin
    assert portal.glow_tint != Color.WHITE                     # distinct vs portal 1
    assert not portal.glow_tint.is_equal_approx(EMBER_ORANGE)  # distinct vs portal 2
    assert not portal.glow_tint.is_equal_approx(CAVE_TEAL)     # distinct vs portal 3
    # push-down landed: child Interactable prompt + PortalGlow/DiveGate modulate
    #   (same three sub-asserts as H7:211-221)

# OQ-4 (if ratified): the plaza-full pin — H4 additionally asserts the hub contains
# EXACTLY the 5 expected Interactable children (count assert over a tree scan), so a
# silently-added 6th interactable fail-louds into the band-select design conversation.

# H5/H6/H7 run UNMODIFIED — they ARE the "existing portals byte-identical" gate
# (portal 3 pinned at (110,-20)/CAVE_TEAL/The Warren; portal 2 (220,-150)/ember/Sump;
#  portal 1 (0,-150)/WHITE/&"near").
```

### 3.4 `test_band_routing.gd` — extend (C1–C7 unmodified; add C8; extend C5 + C6)

```gdscript
const BAND_FOUR_PATH := "res://data/bands/band_four.tres"

# --- C8 (new). Routing lands in band_four, distinct from ALL THREE others ------------
# Mirrors C7 (:143-174) exactly, one band later.
func _check_routing_lands_band_four() -> void:
    EventBus.dive_requested.emit(&"band_four")
    var mg := MainGame.new()
    var profile: BandProfile = mg._resolve_band_profile()
    assert profile.id == &"band_four"                  # the BAND_ROUTES row works
    assert mg._band_route_key == &"band_four"          # the tag start_run will carry
    mg.free()
    # Route distinctness: ONE generate each; b4 fp != greybox, != band_two, != band_three
    # for the same SEED. (Same-seed-twice determinism + connectivity + the sightline bar
    # are U0/U3's tests — one owner per assertion, the T4 §RD OQ-5 split, held again.)
    # Scatter emits synthetic pieces (scat_ ids) with p.instance possibly null —
    # _free_band's null-guard (:259-264) already copes (same note as C7's cave pieces).

# --- C5 (extended). Full-scene stamp: add a FOURTH drive ------------------------------
#  ... after the existing band_two / unstaged-near / band_three drives (:179-241):
    GameState.extract_and_end_run(); await process_frame
    _run_started_band_ids.clear()
    EventBus.dive_requested.emit(&"band_four")
    game.start_new_run()
    await get_tree().process_frame
    assert _run_started_band_ids == [&"band_four"]     # run_started row source ==
    assert game._band_profile.id == &"band_four"       #   the route key (telemetry.gd:167
                                                       #   mirrors it verbatim — §2.1 row 4)

# --- C6 (extended). Wipe isolation: add a band_four round (2 lines) ------------------
    EventBus.dive_requested.emit(&"band_four")
    GameState.wipe_meta()
    assert GameState.consume_pending_dive_band() == &"band_four"
```

C5's fourth drive exercises the **full assembled open-field dive** — pipeline scatter
dispatch (U0) + arena materialisation (U1) headlessly — proving reachability end-to-end,
which is exactly the breakdown's "new portal headless contract check (… routes to
`band_four` with its fp, wipe-isolated)". The existing C1–C7 + three C5 drives rerun
unmodified = the byte-identical proof for the old routes.

### 3.5 Verification runs (standing invocations — never concurrently)

```bash
godot --headless --path Game --import                                 # parse gate
godot --headless --path Game --script res://tools/ci_smoke_test.gd    # SMOKE OK
godot --headless --path Game res://tests/test_run_config.tscn         # all-off fp e943ac9c8bc1
godot --headless --path Game res://tests/test_band_routing.tscn       # C1–C8 + 4 stamp drives
godot --headless --path Game res://tests/test_hub_contract.tscn       # H1–H8, 5 interactables
godot --headless --path Game res://tests/test_scatter_backend.tscn    # U0's (rerun — fp pins)
# + U3's band_four profile-contract test rerun; bandgen determinism suites +
# test_app_router rerun unmodified in the wave's full sweep.
```

---

## 4. Files touched (U4, Wave 4)

| File | Change | Nature |
|---|---|---|
| `Game/scenes/game/main_game.gd` | +1 `BAND_ROUTES` row (§3.1) | **code (1 line)** |
| `Game/scenes/hub/hub.tscn` | +1 instance block, ~9 lines (§3.2) | scene data |
| `Game/tests/test_band_routing.gd` | +C8, C5 fourth drive, C6 round (§3.4), ~55 lines | test |
| `Game/tests/test_hub_contract.gd` | +H8, H1/H4 entries, OK print (§3.3), ~45 lines | test |
| `worklogs/<date>-U4-general-purpose.md` | worklog + **bespoke-code ledger** | meta |

**Cost-ledger prediction (the task's headline number):** bespoke non-data, non-test
production code = **1 line** (the `BAND_ROUTES` entry; plus optional comment). Scene-data
delta ≈ 9 lines. Test delta ≈ 100 lines. T4 shipped exactly this shape; a flat line at
N = 3 IS the UG3 evidence. If the actual ledger materially exceeds this, the overrun is a
deviation AND a UG3 finding.

## 5. Definition of done (concrete — per breakdown §U4)

1. **Controls byte-identical:** all-off fp `e943ac9c8bc1` unmoved; `band_greybox` +
   `band_two` + `band_three` fingerprints unmoved (routing test C4/C7 + bandgen suites
   rerun); `departure_portal.tscn` zero-byte diff; portal 1/2/3 `hub.tscn` lines untouched;
   `test_hub_contract` H5/H6/H7 + `test_band_routing` C1–C7 (incl. all three existing C5
   drives) + `test_app_router` green **unmodified**.
2. **New portal routes:** interacting `&"portal_band_four"` stages `&"band_four"`; the dive
   generates from `data/bands/band_four.tres` (H8 + C8 + the C5 fourth drive green);
   full-scene headless drive lands in the open-field band and returns to the hub through
   the unchanged auto-return.
3. **Stamp:** `run_started` rows carry `band_id == "band_four"` for portal-4 dives
   (asserted at the signal, C5; `telemetry.gd:167` mirrors the arg verbatim — §2.1 row 4);
   spot-check one JSONL row.
4. **Always present, no save change:** no `schema_version` diff, no persisted key; wipe
   isolation (C6 incl. the band-4 round) green.
5. **Hub contract at 5 interactables** (H4 extended; OQ-4's plaza-full pin if ratified).
6. Import + smoke + suite sweep green; worklog with the **bespoke-code ledger**, commit
   SHA, and Design-deviations section; the **plaza-full / band-5-forces-band-select flag
   recorded for UG3** (verbatim from §2.4); board + STATUS mirrored.

---

## Open Questions

> Phase-3 resolvers: resolve on technical merit where possible; items marked **Director**
> or **blocked on U3** are not self-resolvable here.

1. **Glow/gate tint — BLOCKED ON U3 RATIFICATION (Director — tone, coupled to the identity
   pitch).** §2.5 derives the feasible set under the multiply math (violet, ember, and
   cave-teal renders taken; greens/golds/whites/reds struck) and shortlists two candidates:
   **saturated indigo/ultramarine `Color(0.15, 0.25, 1.0)`** (renders ≈ (0.11, 0.08, 1.0) —
   deep void-blue; best pairwise separation; this doc's recommendation, and a natural fit
   for b1's "wrong, too-open expanse") and **magenta/fuchsia `Color(1.0, 0.0, 0.55)`**
   (renders ≈ (0.76, 0, 0.55) — hot pink; weaker separation from portal 1). **The seam: U3's
   identity pitches must pick their portal glow from inside §2.5's set** — attach the
   per-pitch glow to U3's pitch table *from this shortlist* (the amendment-12 protocol, run
   proactively) so the Director ratifies one coherent identity+glow bundle, once. If a
   ratified identity demands a hue outside the gamut, that is an art-retone follow-up task
   (Director-gated), never a U4 tint; the overdrive (>1.0) trick is recorded and
   recommended against. Gate tint = lighter wash of the winning hue.
2. **Prompt text + display name — BLOCKED ON U3 RATIFICATION (Director — tone).** The
   binding *pattern* is already ratified twice (T4 §RD OQ-1): `prompt_text = "Dive —
   <Name>"`, `display_name = "<Name> Portal"`, name only. Sub-question: as the deepest band
   (`band_depth = 4`, 1.45 budget), should the prompt carry any depth/danger signpost?
   *Recommendation: no — pattern consistency; the forward-rank position + tint + Cyrus/lore
   carry escalation, and depth-signposting remains a UG2/UG3 watch-item.* Folding the
   winner in is one `hub.tscn` override + the H8 string pin.
3. **The spawn→shop transit prompt at the mirror slot (Director eyeball at UG1; geometry
   pre-resolved).** §2.4 computes that the spawn→shop diagonal — the loop's most-walked
   lane — crosses portal 4's interact rect, exactly mirroring (and out-trafficking)
   portal 3's spawn→portal-2 caveat, and proves no valid mirror slot avoids it. Mitigations
   (never-two-in-range, focus hysteresis, band-named prompt, fat-finger lockout) are the
   same three that shipped with portal 3 through TG1 without incident. *Recommendation:
   build at `(-110, -20)` as reserved; the UG1 eyeball covers BOTH transit lanes plus the
   four-glow plaza read; if the Director judges the transit pair mis-dive-prone, the fix is
   pulling the band-select surface forward (the plaza is full regardless — OQ-4), never a
   slot shuffle. A nudge is a one-line override + one H8 constant.*
4. **Should the hub contract pin "the plaza is FULL" (assert exactly 5 interactables)?**
   Today H4 asserts the expected ids *exist* but not that no others do. Pinning the count
   (a one-line tree-scan assert over `Interactable` children) turns §2.4's finding — no
   sixth safe slot exists — into a contract: a band-5 portal cannot land silently; adding
   it fail-louds the suite and forces the band-select design conversation the breakdown's
   UG3 watch-item asks for. Cost: one assert; risk: a legitimate future hub interactable
   (an NPC, a stash) also trips it — which is arguably correct behavior (any new
   interactable re-opens the plaza geometry). *Recommendation: YES — pin exactly 5, with a
   comment naming the band-select forcing function; the tripping task consciously updates
   the pin. Resolve on merit (Phase 3), Director veto welcome at UG3.*

---

## Resolved Decisions (Phase 3) — BINDING

> Fresh-eyes resolution, 2026-07-06, against the working tree at `main` (post-FBM-A2,
> `f555f5c`) — a different agent than the Phase-2 author. Every load-bearing §2 claim was
> re-verified against the repo (files read; geometry and color arithmetic independently
> recomputed; the pixel-count claims taken as stated per the Phase-3 brief). Verdicts are
> binding on the U4 build except where marked **NEEDS DIRECTOR REVIEW** / **blocked on U3
> ratification**. Sibling seam checked: `U3_band_four.md` read in full (its own Phase-3
> section has not landed yet — the coupling rule in OQ-1 below is written to be robust to
> that).

### As-built verification (all cites re-checked — no corrections that change a verdict)

1. **Code/scene/test cites verify verbatim.** `BAND_ROUTES` three rows + doc comment
   (`main_game.gd:49-59`); `_band_route_key` (`:110`); `start_run`/`enter_band` tags
   (`:331-332`); `_resolve_band_profile` consume-on-read + double fallback (`:429-441`);
   staging seam (`game_state.gd:100, :134, :219-220, :226-229` — the doc's ":226-228" is
   one line short of the func body, cosmetic only); telemetry stamp truly key-generic —
   `"band_id": String(band_id)` at `telemetry.gd:167` inside `_on_run_started` (`:142`),
   no key whitelist or per-band branch anywhere in the file, `band_depth_reached` mirror
   at `:178-182`; portal exports/push-down/guards (`departure_portal.gd:19, :25, :33-34,
   :40-41, :52-63, :70-84`); 48×64 Interactable rect + root layer/mask 0 + child layer 4
   (`departure_portal.tscn:8-9, :12-13, :27-28`); shop rect exactly 48×64
   (`shop.tscn:10-11`); detector radius 36 (`interaction_detector.tscn:7`); hub anchors —
   walls ±368/±232 (`hub.tscn:32-46`), spawn `(0,120)` (`:48-49`), portal 1 `(0,-150)`
   (`:54-55`), portal 2 `(220,-150)` (`:57-64`), portal 3 `(110,-20)` (`:66-73`), shop
   `(-220,-150)` (`:75-79`); yard 340/216 (`hub_ground.gd:44-45`); `test_hub_contract`
   H1 list `:69-71`, H4 dict `:106-111`, `EMBER_ORANGE` `:25`, `CAVE_TEAL` `:26`, OK
   print `:56`, H7 at `:188-221` (push-down sub-asserts `:211-221`);
   `test_band_routing` C7 `:143-174`, the three C5 drives `:179-240`, `_free_band`
   null-guard `:259-264`. Grep re-run: **only `test_hub_contract.gd` loads `hub.tscn`**
   — the "no other test pins the hub interactable set" claim holds.
2. **Geometry independently recomputed — all correct.** Portal-4 rect x `[-134,-86]`,
   y `[-52,12]`; rect gaps √(62²+66²) ≈ **90.55 px** to portal 1 AND to the shop (the
   mirror is exact — shop rect 48×64 confirmed), **172 px** to portal 3; spawn distance
   ≈ 138 px (> 36, no prompt at spawn); spawn→shop diagonal P(t) = (−220t, 120−270t)
   inside the rect's y-band for t ∈ [0.40, 0.637] (x −88 → −140.1), intersecting the rect
   for x ∈ [−134, −88]; the no-valid-mirror-slot window — 72 px bar forces
   |x₀| ∈ [76.8, 143.2] ((|x₀|−48)² ≥ 72²−66² = 828 → |x₀| ≥ 76.77; 220−|x₀|−48 ≥ 28.77
   → |x₀| ≤ 143.2) while a miss requires x₀ < −164 or x₀ > −64 — recomputes exactly:
   **every admissible west slot intersects the shop diagonal; the transit caveat is
   inherent, not a defect of `(-110, -20)`.**
3. **Glow multiply arithmetic recomputed.** Dominant pixel (193,85,255) → (0.757, 0.333,
   1.0); option 1 `Color(0.15, 0.25, 1.0)` renders (0.114, 0.083, 1.0) ✓; option 2
   `Color(1.0, 0.0, 0.55)` renders (0.757, 0, 0.55) ✓; the three taken renders match the
   shipped pins (`hub.tscn:63, :72`; `test_hub_contract.gd:25-26`). Consistent with
   T4 §RD correction 5 and the amendment-12 story.
4. **The U3 seam is TIGHTER than this doc's shortlist.** `U3_band_four.md` §3.1 (binding
   across ALL THREE identity pitches, not per-pitch): *"All three pitches share the
   deep-cold-blue portal glow family … **Magenta/violet glows are forbidden (clone
   portal 1)**; ember is forbidden … U4 owns the final `glow_tint`/`gate_tint` within
   that family."* U3 also confirms `band_depth = 4` → `floor(24·1.45) = 34` credits and
   "The Far Field" (Pitch A) as its recommended name — consistent with §1/§2.3 here.

### Per-OQ verdicts

- **OQ-1 (glow/gate tint) — RESOLVED to a single candidate; final value rides the U3
  ratification. The coupling rule (BINDING):** *U4 implements the portal glow from the
  Director-ratified U3 identity bundle; prompt text = `"Dive — <ratified name>"`.* The
  intersection of §2.5's feasible set with U3 §3.1's binding all-pitch family constraint
  (deep-cold-blue only; magenta/violet forbidden) is exactly **option 1: glow
  `Color(0.15, 0.25, 1.0)`, gate wash `Color(0.55, 0.62, 1.0)`** — which was also this
  doc's recommendation on separation grounds. **Option 2 (magenta `Color(1.0, 0.0,
  0.55)`) is STRUCK** as a U4 candidate: U3 forbids the family outright, and it had the
  weaker portal-1 separation anyway; it revives only if the Director explicitly
  overrides U3's family pin at ratification — in which case BOTH docs amend together
  (a joint deviation entry), never a silent U4 substitution. U3's illustrative in-family
  value `Color(0.28, 0.42, 1.0)` is superseded by option 1 (deeper, better-separated;
  U3 itself assigns U4 ownership of the final value within the family). H8 pins the
  implemented value exactly (`BAND4_GLOW`), plus the three pairwise-distinctness asserts
  (§3.3). Escape hatches stay recorded-not-recommended: retone is a Director-gated
  follow-up task; the >1.0 overdrive trick is REJECTED for U4 (clips the gradient,
  untested for the pinned-tint pattern). **NEEDS DIRECTOR REVIEW only via the U3
  identity ratification** — the hue family needs no separate Director call (both docs
  derive it independently from the math).
- **OQ-2 (prompt text + display name) — pattern RESOLVED; name blocked on U3
  ratification (Director — tone, via U3's D1).** Binding: `prompt_text = "Dive —
  <ratified name>"`, `display_name = "<ratified name> Portal"`. The depth-signposting
  sub-question is **RESOLVED: NO** on merit AND precedent — T4 §RD OQ-1 already ratified
  "name only, no depth signposting in the prompt" as the standing pattern (twice
  shipped); the forward-rank position + tint + Cyrus/lore carry escalation, and
  depth-signposting stays a UG2/UG3 watch-item. Recommendation to the Director:
  **"Dive — The Far Field"** (U3's Pitch A rec). Folding the winner in is one `hub.tscn`
  override + the H8 string pin — ratification blocks the value, never the build.
- **OQ-3 (mirror slot / spawn→shop transit prompt) — geometry RESOLVED: build at
  `(-110, -20)`; H8 pins it. Transit caveat confirmed and accepted; NEEDS DIRECTOR
  REVIEW only as the UG1 eyeball.** The independent recomputation (verification 2)
  confirms both the crossing and its inherence — no admissible west slot avoids the
  shop diagonal, so a slot shuffle buys nothing. Mitigations are the same three that
  shipped with portal 3 through TG1 without a recorded mis-dive (never-two-in-range at
  90.6 px gaps, `SWITCH_RATIO = 0.9` hysteresis, band-named prompt) plus the 0.25 s
  fat-finger lockout. Binding rider on UG1's checklist: the Director eyeball covers
  **(a) BOTH transit lanes** (spawn→shop over portal 4 — the loop's most-walked lane —
  and spawn→portal-2 over portal 3) **and (b) the four-glow plaza read** (a third
  blue-family glow joins violet + teal). If the Director judges the transit pair
  mis-dive-prone, the fix is pulling the band-select surface forward (OQ-4's forcing
  function), never a slot shuffle. A post-eyeball nudge is a one-line override + one H8
  constant.
- **OQ-4 (pin "the plaza is FULL") — RESOLVED: YES, and strengthen the shape from a bare
  count to SET EQUALITY.** H4's extension asserts that a recursive scan for
  `Interactable`-typed nodes under the hub root yields **exactly the 5 expected ids**
  (`&"portal"`, `&"portal_band_two"`, `&"portal_band_three"`, `&"portal_band_four"`,
  `&"shop"`) — set equality catches both a silently-added sixth interactable AND a
  duplicate id, with a self-explaining failure message a bare `count == 5` can't give.
  On the merits this is sound QA practice, not design pressure baked into a test: **the
  assert pins as-built reality** (the hub HAS exactly these five), with identical
  epistemics to H2's exactly-4 walls and H3's exactly-963 cells — the suite's standing
  exact-pin idiom; the *design* pressure lives in the comment beside it, which MUST name
  the forcing function ("§2.4: no sixth safe slot exists — any new hub interactable
  re-opens the plaza geometry; band 5 requires a band-select surface"). The "band 5
  starts with a red test" property is the point, not a defect — every golden pin in the
  suite (fps, tints, cell counts) makes unplanned drift start red, and today's
  subset-only H4 has a real blind spot: a leaked/extra interactable would pass the whole
  suite silently. A legitimate future interactable (NPC, stash) tripping it is correct
  behavior — that task consciously updates the pin after re-running the §2.4 geometry.
  **Both belt and braces ship:** the test pin (enforcement) AND the UG3 watch-item
  verbatim (the scheduled design conversation) — the pin does not replace the flag.
  Director veto welcome at UG3, as the doc offers; no pre-build Director call needed.

### NEEDS DIRECTOR REVIEW queue (nothing gates the build start)

- **D-U4-1 — Band-4 identity ratification (= U3's D1; tone).** Fixes `<BAND4_NAME>`
  (prompt/display/H8 pin) and confirms the glow bundle. **Rec: Pitch A "The Far Field"
  → `"Dive — The Far Field"` + indigo `Color(0.15, 0.25, 1.0)` / gate
  `Color(0.55, 0.62, 1.0)`.** Each is a one-line override; the build proceeds on the
  named parameters.
- **D-U4-2 — UG1 eyeball (fun/feel, post-build).** Both transit-lane prompt reads + the
  four-glow plaza read (per OQ-3's binding rider). Escalation path if judged
  mis-dive-prone: pull the band-select surface forward — never a slot shuffle.

*Resolved by a Phase-3 fresh-eyes subagent (not the Phase-2 author), 2026-07-06. OQ-1's
final values and OQ-2's name fold in at the U3 ratification; OQ-3 geometry and OQ-4 are
binding now. Deviations during the build go to `design/DESIGN_DEVIATIONS.md` for the
Wave-4 close-out sweep.*
