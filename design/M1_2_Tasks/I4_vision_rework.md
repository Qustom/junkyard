# I4 — Vision/Fog Rework (real occlusion + legible fog/lost)

**Milestone:** M1.2 — Greybox Cost Axis, Iteration 2 (Legibility & Level Scale) · **Workstream:** (b) Wave 2 — oppositions retuned to the new canvas
**Task id:** I4 · **dependsOn:** I1 (radius vs new room scale) · **pairs with:** BUG4 (branch-rate-independent sealed map)
**Phase:** 2 (per-task design) — this doc. Phase 3 (fresh-eyes open-question resolution) follows.
**Design author:** `game-director-designer` (this doc) · **Build:** `general-purpose` (+ `environment-artist` for the greybox look)
**Companion docs:** `M1.2_Breakdown.md` §I4 (§3/§4/§5) · `G4_findings_M1.1.md` §2 (I4 row) · `R4_maze_navigation.md` (the M1.1 spec this reworks — §2 Lever 2, §3 lost-proxy, §10 ratified decisions) · `M1_As_Built.md` (canonical APIs) · `data/run_config/run_config.gd` (R4 vision knobs)

> **Scope guardrail (Breakdown §2).** I4 is **not** a new mechanic and **not** the final vision system. It **reworks the *presentation* of R4's existing Lever 2 (vision/fog) and the lost-proxy** so the M1.1 illegibility (dims-but-doesn't-hide; fog + lost-proxy invisible) is fixed for a fair re-gate. Still **greybox** (colored rects/shapes, node-based, no shader unless §10 reopens R4 Q3), still **cosmetic/visibility-only** — it never alters generated geometry, collision, or the proc-gen RNG. Every change ships **configurable, not balanced**: acceptance is "the dark actually hides, fog/lost read on-screen," not "the radius value is right." The all-off config still reproduces the M1.1/M1.0 baseline (full vision, no overlay, no R4 telemetry) as the permanent control.

---

## 1. Goal & premise research

**The one sentence:** *Beyond the vision radius the band is genuinely **hidden** (not just dimmer), explored area reads clearly as "seen but not live," and when the player is actually lost the game **tells them so** — so limited vision becomes a legible navigation cost instead of an unreadable tint.*

### 1.1 What the Director said (G4_findings_M1.1.md §2, I4 row — size **M**)

> **I4 — "Vision still shows darkened areas; fog + lost_proxy unclear."** Greybox `CanvasModulate` + `PointLight2D` only *dims* (doesn't occlude); fog-of-war + `nav_lost_proxy` have no on-screen meaning. **Recommended fix:** strengthen occlusion (hide, not dim, beyond radius); make fog memory + a "lost" cue visible; document/telegraph `lost_proxy_threshold`.

`M1.2_Breakdown.md` §I4 restates the acceptance: *"beyond the vision radius geometry is hidden (not faintly visible); fog memory + a lost cue are legible; off = full M1.0 vision; determinism/seal intact (pairs with BUG4); knobs take effect."* And §I4's headline: *the dark must actually hide.*

So I4 has **three distinct defects to fix**, not one:

1. **Vision dims but doesn't occlude** — beyond the lit bubble, geometry is still visible (just darker). The player can read the whole band, so limited vision adds no real navigation friction.
2. **Fog-of-war has no on-screen meaning** — once-seen cells get a faint tint, but it doesn't read as a distinct "explored memory" state; the player can't tell live-vision from remembered from never-seen.
3. **The lost-proxy is invisible** — `nav_lost_proxy` / `r4_lost_proxy_threshold` are pure telemetry. The player never learns they're "lost," so the mechanic the gate measures has no felt presence; the Director couldn't tell what the threshold *does*.

### 1.2 Why M1.1 dims-but-doesn't-occlude — the real code (root cause)

The committed M1.1 greybox approach (RATIFIED R4 §10 Q3, node-not-shader) is in `entities/dive/vision_fog.gd` + `vision_fog.tscn`. The `.tscn` is a bare `Node2D` running the script (`uid://br4visionfog001`); the script builds its children at runtime in `_build_nodes()`:

- A **`CanvasModulate`** (`OVERLAY_COLOR = Color(0.06, 0.06, 0.08, 1.0)`, near-black, **alpha 1.0**) — `vision_fog.gd:28,68-70`.
- A **`PointLight2D`** on the player (`energy = 1.2`, a procedural radial white→transparent gradient texture, `_LIGHT_BASE_RADIUS = 256`), `texture_scale = effective_radius / _LIGHT_BASE_RADIUS` so the lit bubble follows the player and tightens with depth — `vision_fog.gd:76-82, 100-111`.
- `effective_radius` = `maxf(MIN_RADIUS, r4_vision_radius − r4_vision_tighten_per_depth * current_depth_index)`, then **multiplied by the R3 vision fraction** (`exposure_vision_mult_changed`, RATIFIED Q4) and re-floored at `MIN_RADIUS = 24.0` (~1.5 cells at 16px) — `vision_fog.gd:103-108, 146-148`.

**The mechanism of the defect:** `CanvasModulate` is a **multiply tint over the whole canvas**, and a `PointLight2D` **adds light back** inside its radius. Two consequences make it "dim, not hide":

1. **The overlay is not opaque to vision — it's a multiply.** `Color(0.06,0.06,0.08,1.0)` darkens everything to ~6% brightness, but 6% of a colored greybox tile is **still a visible silhouette** on most monitors. There is no point at which geometry becomes *gone*; it only asymptotes toward dark. A `CanvasModulate` cannot reach "black = hidden" without also blacking out the lit bubble (it modulates the whole canvas uniformly).
2. **The light's falloff is gradual** (`a = (1−d)²` over a 256px-radius gradient, `vision_fog.gd:93-96`), so the edge of the bubble fades smoothly into the dim overlay — there is **no hard cutoff** where "lit" becomes "hidden." The transition is a soft vignette, which reads as "the far stuff is darker," exactly the Director's complaint.

In short: **CanvasModulate darkens uniformly and the light only *brightens a radius* — distant geometry is dim-but-visible, never occluded.** The R4 spec (§2 Lever 2) literally describes the intent as "geometry beyond it is darkened/hidden" — the build delivered *darkened*, not *hidden*. The node approach was the right call for a greybox (R4 §10 Q3), but a multiply-overlay + additive-light is structurally a *dimmer*, not an *occluder*.

### 1.3 Why fog memory is illegible — the real code

Fog-of-war (`r4_fog_enabled`) is `_remember_visible_cells()` + `_mark_revealed()` (`vision_fog.gd:113-143`): each newly-seen 16px fog-cell gets a `ColorRect` of `FOG_TINT = Color(0.22,0.22,0.26,1.0)` at `z_index = -1`. Problems:

- The remembered tint (`~0.22` grey) sits **on top of the same near-black CanvasModulate**, so "remembered" reads as *slightly less black* — not as a distinct, legible "I've been here" state. With no live geometry showing through occlusion, the player can't visually distinguish **never-seen** (black) from **remembered** (slightly-less-black) from **live** (the bright bubble) — three states that should be three clearly different reads.
- `z_index = -1` puts the fog tint *behind* live geometry but it's a flat fill, so it doesn't communicate *shape* (which corridors I've explored), only a vague brightness.

### 1.4 Why the lost-proxy is invisible — the real code

`entities/dive/lost_proxy.gd` implements **Proxy A** (time-without-depth-progress, movement-gated — RATIFIED R4 §10 Q1). It accumulates `_seconds_wandering` while the player moves (`velocity.length() > MOVE_EPS = 8.0`) but `max_depth_reached` hasn't increased; at `>= r4_lost_proxy_threshold` it emits `EventBus.nav_lost_proxy(PROXY_ID=&"time_no_depth_progress", value, current_depth_index)` (rate-limited, escalating), resetting on real depth progress or `run_ended` (`lost_proxy.gd:52-77`). **This is correct and stays.** But it is **purely a telemetry emitter** — nothing in the game surfaces "you are lost" to the player. The threshold the Director couldn't interpret is exactly the moment Proxy A decides a lost-episode happened; I4 makes that moment **visible**.

### 1.5 Seams I4 reuses (canonical, `M1_As_Built.md` wins)

| Seam | Source of truth | Used for |
|---|---|---|
| Player node | `&"player"` group; `get_tree().get_first_node_in_group(&"player")` (`player.tscn:10`, used in `vision_fog.gd:54`, `lost_proxy.gd:39`) | bubble follows player; movement gate |
| Live within-band depth | `GameState.current_depth_index` (`game_state.gd:50`) | `effective_radius` tightening; lost-proxy `depth` |
| Deepest reached | `GameState.max_depth_reached` (`game_state.gd:51`) | lost-proxy reset on progress |
| Active config | `GameState.active_run_config` (`game_state.gd:59`) — R4 vision knobs at `run_config.gd:110-116` | all radius/fog/lost params |
| R3 vision stacking | `EventBus.exposure_vision_mult_changed(mult)` (`event_bus.gd:108`) — already consumed `vision_fog.gd:64,146` | multiply into radius (RATIFIED Q4) |
| Lost telemetry | `EventBus.nav_lost_proxy(metric, value, depth)` (`event_bus.gd:102`) — **emit only** | drives the lost cue (I4 listens, does not re-emit) |
| Instantiation | `main_game._spawn_r4_nodes()` (`main_game.gd:322-328`): loads `vision_fog.tscn`, `LostProxy.new()`, both parented under `_band_container` (run-state, torn down per dive) | where any new node is added |
| HUD host | `DecisionHUD` (`ui/hud/decision_hud.gd`), a `CanvasLayer`, **pure projection of state, owns no source of truth** | candidate home for a HUD lost cue (see §3 / §4 Open Q) |

**Hard boundaries (Breakdown §6 / R4 §8):** I4 **must NOT edit** `systems/event_bus.gd` (signals pre-declared) or `systems/game_state.gd`. It reads `current_depth_index` / `max_depth_reached` / `active_run_config` and consumes/listens to pre-declared signals only. Vision/fog/lost nodes stay **run-state** (under `_band_container`, freed per dive; nothing to meta/save). **Cosmetic-only:** never touches generated geometry, collision, or the proc-gen RNG — the band `fingerprint(seed + config)` is unaffected because I4 changes nothing the generator reads (it pairs with BUG4, which owns the *seal*; I4 owns only what the player *sees*).

---

## 2. Design / approach + pseudocode

I4 has three independent sub-fixes. Each is a recommended approach with greybox alternatives surfaced in §3 (Open Questions). All three live in `vision_fog.gd`/`.tscn` (+ an optional small HUD node for the lost cue); `lost_proxy.gd` is unchanged except it already emits the signal the lost cue listens to.

### 2.A — Make vision actually OCCLUDE (hide beyond the radius)

**Recommended approach: a full-screen "dark plate" with a punched-out vision hole, replacing the additive-light vignette.** Instead of darkening the world and adding light back (a dimmer), draw an **opaque dark layer *over* the world** and **cut a hole** in it where the player can see (an occluder). Beyond the hole, the plate is fully opaque → geometry is *gone*, not dim. This stays node-based (no fragment shader, honoring R4 §10 Q3) by using Godot's **light-mask / `LightOccluder`-free** trick: a `CanvasModulate`-style dark overlay on its **own `CanvasLayer` above the world**, modulated to near/full opacity, with the player's vision rendered as a **hard-edged hole** via a `PointLight2D` whose texture has a **sharp falloff and whose blend cuts the overlay** (light mask), or — simpler and more controllable — a **`Polygon2D`/sprite dark plate** with the lit region subtracted.

Two concrete greybox realizations (pick at build; recommend the first):

1. **Overlay `CanvasLayer` + hard-edged light hole (recommended).**
   - Move the darkness off `CanvasModulate` (which tints the *whole* canvas including the lit bubble and can't reach opaque) onto a dedicated **`CanvasLayer` drawn above the world** holding a full-rect dark `ColorRect` at **high opacity** (e.g. alpha `0.92–1.0`, an `OCCLUDE_ALPHA` knob/const).
   - Keep the `PointLight2D` on the player **but** give its texture a **hard edge** (steep falloff: `a = step/smoothstep near d≈1` instead of `(1−d)²`) so the lit hole has a crisp boundary, and set the overlay `ColorRect` to be **cut by the light** (CanvasItem light mask / `light_mask` so the lit region is excluded from the dark plate). Beyond the crisp edge → full plate → hidden.
   - Net read: a bright, well-defined bubble around the player; a **hard rim**; pure black (or near-black) beyond. The "darkened-but-visible" middle band is gone.

2. **Tune the existing nodes toward opacity (fallback, smallest diff).** Keep `CanvasModulate` + `PointLight2D` but (a) drive `OVERLAY_COLOR` to **true black** `Color(0,0,0,1)`, (b) **steepen the light falloff** to a hard edge, and (c) raise light `energy` so the bubble reads full-bright. This narrows the dim-but-visible band but a multiply-overlay still can't truly *occlude* (6%→0% is the same asymptote problem) — acceptable only if §3 Q1 resolves to "near-black silhouette is fine."

> **Why not `LightOccluder2D`?** `LightOccluder2D` casts **shadows from geometry** (walls block light) — it would make corners and walls cast shadow, which is a *richer* occlusion (you can't see around corners). But it requires occluder polygons authored from the band's wall geometry (reading collision/geometry shape), which (a) is more code than a greybox warrants, (b) risks coupling vision to geometry the spec forbids touching, and (c) is the kind of thing the *real* M-later vision system should own. **Recommend deferring `LightOccluder2D` to the real vision system** (flag as §3 Q2) and shipping the radius-hole occlusion for M1.2. A simple radius-hole (you see a circle around you, regardless of walls) is enough to make "the dark hides the far band" legible for the re-gate.

```gdscript
# vision_fog.gd — occlusion rework (greybox, node-based, COSMETIC ONLY).
# Replaces the "dim" CanvasModulate+soft-light with a high-opacity dark plate on its
# own CanvasLayer, cut by a hard-edged player light hole. Beyond the hole => hidden.

const MIN_RADIUS := 24.0                 # ~1.5 cells @16px — never fully blind (unchanged)
const OCCLUDE_ALPHA := 0.96              # dark-plate opacity; near-opaque => "hidden" (§3 Q1)
const EDGE_HARDNESS := 0.12              # width (0..1 of radius) of the lit→hidden rim; small = crisp

func _build_nodes() -> void:
    _dark_layer = CanvasLayer.new()       # ABOVE the world so it occludes, not tints
    _dark_layer.layer = 50
    _dark_plate = ColorRect.new()         # full-viewport opaque dark plate
    _dark_plate.color = Color(0, 0, 0, OCCLUDE_ALPHA)
    _dark_plate.anchors_preset = Control.PRESET_FULL_RECT
    _dark_layer.add_child(_dark_plate)
    add_child(_dark_layer)

    _light = PointLight2D.new()
    _light.texture = _make_light_texture()    # HARD-edged falloff (see below)
    _light.energy = 1.4
    # The dark plate is on a light_mask layer the player light CLEARS, so the lit
    # bubble subtracts from the plate => a true hole, not an additive brighten.
    add_child(_light)

func _make_light_texture() -> Texture2D:
    # HARD edge: full inside, crisp ring, zero outside — so the hole has a definite
    # boundary (vs M1.1's soft (1-d)^2 vignette that faded into the dim).
    #   a = 1.0                      for d < 1 - EDGE_HARDNESS
    #   a = smoothstep(1, 1-EDGE_HARDNESS, d)   in the rim
    #   a = 0.0                      for d >= 1
    ...

func _process(_dt: float) -> void:
    var depth: int = GameState.current_depth_index
    var radius := maxf(MIN_RADIUS,
        _rc.r4_vision_radius - _rc.r4_vision_tighten_per_depth * float(depth))
    radius = maxf(MIN_RADIUS, radius * _r3_vision_fraction)   # RATIFIED Q4 (unchanged)
    _light.global_position = _player.global_position
    _light.texture_scale = radius / _LIGHT_BASE_RADIUS
    if _rc.r4_fog_enabled:
        _remember_visible_cells(_player.global_position, radius)
        _refresh_fog_visibility(radius)                       # see §2.B
```

### 2.B — Make fog-of-war memory LEGIBLE (three distinct reads)

Goal: the player can always tell **live** (bright bubble) vs **explored/remembered** (a clearly different "ghost" state) vs **never-seen** (hidden/black). Keep the existing low-res per-cell `_revealed` dict (cheap, greybox) but change what a remembered cell *looks like* so it reads as a deliberate map state, not "slightly less black."

**Recommended:** remembered cells are rendered as a **distinct desaturated/tinted ghost of the geometry** at a **fixed mid-low brightness** that is *clearly above black and clearly below the live bubble* — e.g. a cool blue-grey fill (`FOG_TINT`), drawn **under the dark plate's cut** so it shows wherever the plate would otherwise hide, but **dimmer and color-shifted** vs live. The three-state ladder:

- **Never-seen:** full dark plate → hidden (§2.A).
- **Remembered:** a faint, color-shifted ghost (e.g. `Color(0.22,0.22,0.30)`-ish, **distinctly blue/cool** so it doesn't read as "just dimmer") — *shape visible, clearly not live.*
- **Live:** the bright punched hole (§2.A).

Implementation note: the M1.1 `_mark_revealed()` already drops a `ColorRect` per seen cell. I4 keeps that but (a) gives it a **clearly distinct color** from both black and the live bubble, and (b) ensures it is **not** simply re-occluded by the new opaque plate — the remembered ghosts must render **above** the dark plate (or punch through it) so explored area stays readable while live geometry beyond the bubble is hidden. The exact "how faint / what color" is a Director feel call (§3 Q5).

```gdscript
const FOG_TINT := Color(0.20, 0.22, 0.34, 0.85)   # cool, distinct from black & from live (§3 Q5)

func _mark_revealed(cell: Vector2i) -> void:
    var ghost := ColorRect.new()
    ghost.color = FOG_TINT
    ghost.size = Vector2(_FOG_CELL_PX, _FOG_CELL_PX)
    ghost.position = Vector2(cell * _FOG_CELL_PX)
    _fog_layer.add_child(ghost)        # _fog_layer rendered ABOVE the dark plate so it stays visible
    _revealed[cell] = ghost

func _refresh_fog_visibility(_radius: float) -> void:
    # Cells inside the live bubble are shown by the light hole (live read); remembered
    # ghosts elsewhere stay at FOG_TINT. (Optional: hide the ghost where it overlaps the
    # live hole so the bright bubble isn't double-tinted — a polish call, §3 Q5.)
    ...
```

### 2.C — A LEGIBLE "lost" cue tied to `lost_proxy_threshold`

Goal: when Proxy A decides the player is lost (the moment `nav_lost_proxy` fires, i.e. `seconds_wandering >= r4_lost_proxy_threshold`), the player **sees a cue** so the threshold has on-screen meaning. **I4 does not change `lost_proxy.gd`'s detection or telemetry** — it adds a *listener* that renders a cue when the existing signal fires.

**Recommended: a screen-edge "disoriented" vignette pulse + a small HUD line.** When `nav_lost_proxy` fires:
- A brief **screen-edge cool pulse** (a `ColorRect` vignette on the vision `CanvasLayer` fading in/out over ~1–1.5s) — a felt, peripheral "you're turned around" cue that doesn't block the view. Greybox: a border `ColorRect` with a Tween on alpha.
- Optionally a **HUD text line** ("Lost?" / "Disoriented") in `DecisionHUD` that shows while `seconds_wandering` is over threshold and clears on depth progress. (Whether the cue is screen-effect, HUD text, or audio is a Director feel call — §3 Q3.)

This makes the *escalation* legible too: because `lost_proxy` rate-limits and **re-emits every additional threshold** of continued wandering (`lost_proxy.gd:71`), repeated pulses communicate "still lost, getting worse," and the cue stops the instant the player makes real depth progress (the signal stops firing; the cue's "clear on progress" hook listens to the same reset condition or simply times out).

Because the lost cue is a pure **listener on a pre-declared signal**, it can live **either** on the vision `CanvasLayer` (screen-edge effect, run-state, freed per dive) **or** as a tiny projection in `DecisionHUD` (HUD text) — both are allowed; recommend the screen-edge effect as primary (felt, not just informational) with a HUD line as optional reinforcement. It adds **no** new EventBus signal and **no** game state.

```gdscript
# Lost cue — a listener (run-state). Lives on the vision CanvasLayer (screen-edge
# pulse) and/or DecisionHUD (text). Listens to the EXISTING nav_lost_proxy signal;
# adds NO signal, NO state, never edits lost_proxy.gd / event_bus / game_state.
func _ready() -> void:
    EventBus.nav_lost_proxy.connect(_on_lost)
    EventBus.run_ended.connect(func(_r,_d,_dp): _clear_lost())   # safety clear on run end

func _on_lost(_metric: StringName, _value: float, _depth: int) -> void:
    _pulse_disoriented_vignette()    # cool screen-edge pulse, ~1.2s Tween in/out
    # optional: show HUD "Lost?" line; auto-clear after a short window since the
    # signal rate-limits — re-firing keeps it alive while still wandering.

# No active-detection here: lost_proxy.gd already gates on movement + depth and
# resets on progress, so the cue simply mirrors when the signal fires.
```

### 2.D — Tune radius against I1's new room scale (dependsOn I1)

I4 `dependsOn I1` because **the radius must be re-tuned to I1's larger rooms** — a 192px bubble that hid the far band on M1.1's 128×64px pieces will behave differently once I1 scales room count/size. I4 does **not** invent its own scale; it re-recommends `r4_vision_radius` / `r4_vision_tighten_per_depth` **presets against I1's as-built room dimensions** once I1 lands. Until I1's final cell-scale is known, the recommended starting presets below are expressed in **cells** (one M1.1 cell = 16px) so they re-derive automatically against I1's cell size.

**Recommended starting presets (re-derive in px from I1's final cell size; configurable-not-balanced):**

| Preset | `r4_vision_radius` | `r4_vision_tighten_per_depth` | `r4_fog_enabled` | Read |
|---|---|---|---|---|
| **V-tight** | ~6 cells | ~0.5 cell/depth | `true` | claustrophobic; lean on fog memory to navigate |
| **V-mid** (recommend default sweep) | ~10 cells | ~0.5 cell/depth | `true` | see the current room, not the band; explored memory builds a map |
| **V-open** | ~14 cells | ~0.35 cell/depth | `false` | generous; forces re-discovery (no memory) deep |

`MIN_RADIUS` stays ~1.5 cells (the never-blind floor). If I1 makes rooms much larger, scale `r4_vision_radius` so the bubble shows roughly **one room, not the whole band** — that's the felt target the Director should tune toward.

---

## 3. Open Questions (Phase-3 fresh-eyes + Director feel/fun calls)

> Several of these are **Director feel/fun calls** — *what the dark/fog should do* is partly a design-vision question, not a pure-implementation one. Flagged **[Director]** where the call is feel, **[Build]** where a programmer/artist can resolve at build time.

1. **How dark is "occluded" — full black or a faint silhouette? [Director]** §2.A `OCCLUDE_ALPHA`. Full `1.0` = geometry truly *gone* (most legible "hidden," but can feel harsh/blind and may hide that a wall is even there). `~0.92–0.96` = a barely-there silhouette (softer, hints there's *something* out there). The Director's I4 complaint reads as "I want it to *hide*," which argues for near/full opacity — but confirm the felt target (mystery vs. blindness). *Recommendation: ~0.96, sweepable; revisit at playtest.*

2. **Occlude via opaque overlay vs `LightOccluder2D` vs shader — is R4 §10 Q3 (node-not-shader) still right? [Director/Build]** §2.A recommends the **opaque-plate + hard-light-hole** (node, no shader, no geometry coupling). `LightOccluder2D` (walls cast shadow, can't-see-around-corners) is richer but couples vision to wall geometry and is more code — **recommend deferring to the real M-later vision system.** A fragment shader (smooth radial reveal) was **ruled out for M1.1** (R4 §10 Q3) as throwaway-greybox overkill; I4 is still greybox, so the recommendation is to **keep the node approach**. *Should Phase 3 reopen the shader option now that occlusion (not just dimming) is the bar?* Recommend **no** for M1.2 (node hard-edge hole is enough); flag for the real vision system.

3. **Should "lost" be a HUD cue, a screen-edge effect, or audio? [Director]** §2.C recommends a **screen-edge disoriented vignette pulse** (felt, peripheral) + optional HUD text. Alternatives: HUD-only text (informational, less felt — but cheapest and clearest), or an audio sting (needs `audio-designer-composer` + an `AudioDirector` cue — out of I4's greybox scope unless the Director wants it). *Recommendation: screen-edge pulse primary, HUD line optional; no audio for M1.2.* Confirm the Director's preferred channel.

4. **Is the lost-proxy even the right thing to surface to the player, or is it just telemetry? [Director]** Proxy A is movement-gated time-without-depth-progress — a *measurement*, not a ground truth of "lost." Surfacing it risks **false-positive cues** (the player is deliberately exploring a side room for junk and gets told "Lost?"). Options: (a) surface it as designed (accept occasional false "lost" as honest greybox feedback — matches R4 §10 Q2's "accept empty dead-ends as honest risk" stance); (b) surface only on the **second+ escalation** emit (rate-limited re-fire = "still stuck," fewer false positives); (c) keep it telemetry-only and instead give the player a **different, truer "lost" affordance** (e.g. the fog memory itself IS the navigation aid, no explicit cue). *Recommendation: (b) — cue on the escalating re-fires, not the first emit, so a brief stall doesn't nag; revisit if playtest shows it still false-fires.* This is the deepest design-vision call in I4.

5. **Fog memory: how faint, and what color? [Director]** §2.B `FOG_TINT`. The three-state ladder (never-seen / remembered / live) only works if "remembered" is **clearly distinct from both** — recommend a **cool color-shift** (blue-grey), not just "dimmer grey," so it doesn't collapse back into the M1.1 "slightly-less-black" problem. *How bright should remembered geometry be — readable-but-clearly-stale, or just a faint ghost outline?* Director feel call; recommend "clearly readable shape, obviously not live."

6. **[Build] Does the opaque-plate light-hole interact correctly with the player sprite, pickups, and the hazard (I2)?** The dark plate is on a `CanvasLayer` above the world — confirm the **player, pickups, gate, and the I2 hazard** render correctly relative to it (the player should be in the lit hole; do distant pickups/hazard need to be hidden *with* the geometry, or always visible as gameplay-critical?). Likely the hazard should be **hidden until it's in the bubble** (that's the *point* of limited vision — you don't see it coming), which pairs intentionally with I2. Confirm the layer ordering + light-mask seam with the I2 owner (Breakdown §6 flags the `main_game.gd` collision between I2 and I4).

7. **[Build] One node or two for the cue?** The lost cue can live on the vision `CanvasLayer` (screen-edge, run-state, auto-freed) or in `DecisionHUD`. If both (vignette + HUD text), keep a single owner of the "am I lost" listener to avoid double-clearing. Recommend the screen-edge effect own it; HUD text (if used) reads a shared flag.

8. **[Build] `current_depth` vs `current_depth_index`.** The R4 pseudocode in the *spec* said `GameState.current_depth`; the **as-built code uses `current_depth_index`** (`game_state.gd:50`, `vision_fog.gd:103`, `lost_proxy.gd:68`). I4 follows the as-built (`current_depth_index`). No change — flagged so the builder doesn't reintroduce the spec's older name.

---

## Resolved Decisions (Phase 3 — fresh-eyes, 2026-06-19)

> Independent UI/UX-readability resolution of §3 by `ui-ux-designer` (did not author §1–§2). I applied the project readability rules: **back every colour cue with a redundant non-colour channel; never rely on darkness/colour alone; keep player/loot/exits/threats on a band-independent legibility layer.** All eight questions are **CLOSED** below. Four are confirmed as genuine **⚠ NEEDS DIRECTOR REVIEW** feel calls (Q1, Q3, Q4, Q5) — each carries a concrete default the build ships *now* so it is not blocked waiting on the verdict (configurable-not-balanced). I also raise **one new finding (Q2)** that materially changes the recommended occlusion mechanism — read it before build.
>
> **Verdict on the occlusion approach (short form):** the *intent* — opaque dark plate that truly hides, hard-edged hole, no shader — is **right and correct for the re-gate**. But the *mechanism* in §2.A ("ColorRect on a CanvasLayer, cut by a PointLight2D light-mask") is **not how Godot 4 2D lighting composites** and will not produce a reliable hole. I substitute a mechanism that does (Q2). With that substitution the approach is **APPROVED**.

### Q2 (taken first — it gates the others) — Occlusion *mechanism*: keep node-based, but NOT a CanvasLayer-ColorRect cut by a light. CLOSED · **[Build]**, with a ⚠ corner-case flag.

**Decision: keep the node-based, no-shader direction (R4 §10 Q3 stays right for M1.2), but build the occluder as a `Sprite2D`/`Polygon2D` dark plate *in world space* (not on a CanvasLayer) whose alpha is driven by a `PointLight2D` operating in `LIGHT_MASK`/shadow role — OR, the simpler and more robust greybox: an `Light2D`-driven dark plate using a `CanvasItemMaterial` set to the light-only/`LIGHT_MODE_*` path. If neither composites cleanly in a 30-minute spike, fall back to a *single hand-rolled radial dark texture* that is itself the occluder (a big `Sprite2D` centred on the player: opaque ring/black outer, transparent centre), moved every frame — no light node at all.**

**Rationale (the fresh-eyes catch):** §2.A proposes a full-rect `ColorRect` on a `CanvasLayer` *above the world*, "cut" by the player `PointLight2D` via `light_mask`. Two problems make this unreliable:
1. **CanvasLayer items do not participate in the world's 2D light pass the way the §2.A text assumes.** A `PointLight2D` lights/darkens `CanvasItem`s that share its `light_mask`, but a `ColorRect` parked on a separate `CanvasLayer` above the world is a different compositing context; "the light subtracts from the plate to make a hole" is not a first-class Godot 4 operation for a Control on an overlay layer. The author's own fallback (§2.A.2, "tune the existing CanvasModulate toward black") is honest that a multiply-overlay *cannot* reach true occlusion — and the recommended path inherits the same uncertainty in a different costume.
2. **The robust, genuinely node-based way to get a *hole that hides* is to make the dark plate itself a lit `CanvasItem` in the world and let the player light *subtract* from it (negative-energy / mask light), or to skip lights entirely and just draw a player-centred radial dark sprite (opaque outside the bubble radius, transparent inside).** The radial-dark-sprite path is the most predictable for greybox: it is literally "draw black everywhere except a circle around the player," needs no light compositing, has a guaranteed hard edge (you author the texture's alpha ramp), and follows the player by setting `global_position`. It is also the closest thing to what the M1.1 `_make_light_texture()` already builds — invert it (transparent centre → opaque rim) and you have the occluder.

This keeps every guardrail: node-based, no fragment shader, no geometry/collision/RNG coupling, cosmetic-only, run-state. **Do NOT reopen the shader** — confirming R4 §10 Q3 stands for M1.2. (A shader is the right tool for the *real* vision system later, where a soft analytic falloff + per-wall occlusion is wanted; here a hard-edged radial sprite is enough and cheaper.) **⚠ build-time corner case:** verify the radial-dark sprite covers the *whole viewport at all zoom levels* (size it to viewport diagonal × a margin, or anchor it to the camera) so no un-darkened gutter shows at the screen edge when the player is near a band boundary — this pairs with Q6's camera-framing concern (use Phantom Camera's framing if the camera can outrun the plate).

### Q1 — How dark is "occluded": near-opaque, NOT pure black. CLOSED · ⚠ NEEDS DIRECTOR REVIEW (feel) — ships with a default.

**Decision: `OCCLUDE_ALPHA = 0.94` (near-opaque), NOT `1.0`. Sweepable. Ship 0.94 now.**

**Rationale (readability rule — never rely on darkness alone):** the readability ruleset says the legibility layer (player, loot, exits, threats) must hold *regardless* of band styling, and that we must not lean on pure darkness as the only channel. Pure `1.0` black is the most "hidden," but it is also a **navigation trap**: at full black the player cannot tell a wall-you-could-hug from an open void, and on OLED / dark-room setups it reads as "the game broke / my screen is off." `0.94` keeps geometry genuinely *hidden as information* (you cannot read the far band's layout — the Director's complaint is satisfied: 6% silhouettes are gone because this plate is opaque, not a multiply) while leaving a ~6% floor that reassures "the world is still there, you just can't see it." That floor is **non-load-bearing** — it must never be the channel the player navigates by; it is purely an anti-blindness comfort margin. The redundant non-colour channel here is the **hard rim of the bubble itself** (a crisp edge = "this is the limit of sight," a spatial/shape cue, not a brightness cue). *Director, confirm the felt target: 0.94 (mystery, "something's out there") vs 1.0 (stark, "the dark is a wall"). I recommend 0.94; it is the colorblind- and panel-safe choice and still hides.*

### Q3 — Lost cue channel: screen-edge pulse + a redundant HUD text line, BOTH, not either/or. CLOSED · ⚠ NEEDS DIRECTOR REVIEW (feel) — ships with a default.

**Decision: ship BOTH a screen-edge "disoriented" pulse AND a short HUD text line (`"DISORIENTED"` / localized), driven from one listener. No audio for M1.2. The screen-edge pulse owns the timing; the HUD line is the redundant non-colour/non-motion channel.**

**Rationale (readability rule — back every cue with a redundant channel; legibility on the critical path):** the author framed these as alternatives ("primary + optional"). From the UI/UX lens they are **not** alternatives — a screen-edge vignette pulse alone fails the redundancy rule. A colour-shifted peripheral pulse is invisible to a player with reduced peripheral attention, easy to miss mid-combat, and (if the pulse is a cool hue) collapses toward the same colour space as the fog/occlusion, so it must not be *colour-coded* to read. So: the pulse carries **motion + position** (it animates, it's at the screen edge), the HUD line carries **language** (an explicit word) — two orthogonal channels for the same event, which is exactly the rule. The HUD line lives in `DecisionHUD` as a pure projection of a shared "am-I-lost" flag (Q7), reads from `hud_strings.csv` (externalized for localization), and respects the accessibility text-size setting. **No audio** for M1.2 (keeps I4 in its greybox lane; audio sting is a clean M-later add via `AudioDirector` if the Director wants a third channel). *Director, confirm you want the HUD word visible (clearest, least "felt") vs pulse-only (more diegetic, less accessible). I recommend both; the HUD line is the accessibility floor.*

### Q4 — Surface the proxy on the **escalating re-fire**, not the first emit; and gate the HUD word, not the pulse. CLOSED · ⚠ NEEDS DIRECTOR REVIEW (feel) — ships with a default.

**Decision: adopt the author's option (b) with a refinement. The screen-edge *pulse* may fire on every `nav_lost_proxy` emit (cheap, brief, non-blocking — a stall deserves a peripheral nudge). The persistent *HUD word* only appears on the **second** emit onward (i.e. after ~2× threshold of continuous no-progress wandering), and clears the instant the signal stops re-firing (depth progress resets `lost_proxy`, so the emits stop and the word times out within one threshold window).**

**Rationale (readability rule — don't nag on a false positive; the legibility layer stays trustworthy):** Proxy A is a *measurement*, not ground truth — surfacing it verbatim risks crying "lost" at a player who is deliberately looting a side room. The author's option (b) is right (escalation = "still stuck" = higher confidence), but a single brief pulse on the *first* emit is acceptable feedback ("hey, you've been here a while") **as long as the louder, persistent claim — the HUD word — waits for confirmation**. Splitting the two cue intensities across the two emit-tiers gives a clean ramp: nudge first, *name it* only once the proxy is confident. This keeps the legibility layer honest (the explicit "DISORIENTED" word never lies on a single brief stall) without making the first stall silent. It also makes the *threshold the Director couldn't interpret* directly legible: first pulse = one threshold of wandering; HUD word = two; that on-screen ramp IS the visualization of `r4_lost_proxy_threshold`. **⚠ this is the deepest vision call in I4** — *Director, confirm: pulse-on-first / word-on-second (my recommendation), vs word-on-first (louder, more false positives), vs telemetry-only-no-cue (author option c — but then the gate-measured mechanic stays invisible, defeating I4's purpose). I recommend pulse-first/word-second.* Option (c) is **rejected**: a re-gate that measures lost-friction needs the friction to be *felt*, or the gate is testing something the player can't perceive.

### Q5 — Fog memory: a cool, desaturated ghost with a redundant non-colour marker; readable shape, obviously stale. CLOSED · ⚠ NEEDS DIRECTOR REVIEW (feel) — ships with a default.

**Decision: remembered cells render at `FOG_TINT = Color(0.34, 0.40, 0.52, 0.85)` — a cool desaturated blue-grey, clearly above the occlusion floor (≈6% from Q1) and clearly below the live bubble — AND carry a redundant non-colour channel: remembered geometry is drawn at a **fixed flat brightness with a subtle dither/hatch or reduced fill (e.g. ~85% alpha, no live highlight)** so it reads as "flat map memory" even in greyscale. Ship this; the exact hue is the art-handoff knob.**

**Rationale (readability rule — colorblind-safe, three states must be *separable without hue*):** the M1.1 failure was three states collapsing into one brightness ramp (black / less-black / bright). Fixing it with *hue alone* (blue-grey "remembered") repeats the mistake for colourblind players — blue-grey vs neutral-grey is exactly a confusable pair under several CVD types. So the three states must separate on a **non-hue axis too**:
- **Never-seen** = near-opaque dark (Q1) — *no texture, no shape* (the absence of information is itself the channel).
- **Remembered** = flat, evenly-lit, desaturated, **no specular/no live shimmer**, at a fixed mid brightness — *shape present but visibly "frozen / printed."* The "it's a memory" read comes from **flatness + lack of live motion/lighting**, not from the blue.
- **Live** = the bright hole, full-contrast, *moving lighting* as the player moves — *the only state that animates.*

So the load-bearing separators are **presence-of-shape** (never-seen vs the other two) and **flat-vs-live-lit / static-vs-animated** (remembered vs live); the cool hue is a *reinforcing* third cue, not the primary one. This survives greyscale and all CVD types. **⚠** *Director feel call: how bright is "remembered" — I recommend "clearly readable shape, obviously not live" (you can plan a route through explored area), not a faint outline (which would force re-exploration and partly defeat fog-memory's navigation purpose). Confirm brightness target; hue handed to the environment-artist.*

> **Cross-cut note for Q1/Q5 (one shared source of truth, per the readability playbook):** the occlusion floor (Q1), the remembered-ghost level (Q5), and the live-bubble brightness must be defined as **three named constants in ONE place** (`vision_fog.gd` consts, mirrored in the art-handoff palette doc) and verified to be monotonically separated (`occlude_floor < remembered < live`) AND separated on the non-hue axis (absent / flat-static / lit-animated). Art may retune the hues but must not collapse the ladder. This is the "one shared source of truth shared with art" the readability rules require.

### Q6 — Layer ordering / gameplay-critical visibility: hazard hidden until in-bubble (intentional); player + active threat-on-contact never occluded. CLOSED · **[Build]**, coordinate with I2.

**Decision: the I2 hazard is hidden until it enters the vision bubble — that is the *point* of limited vision and the intended I2↔I4 pairing (you don't see it coming). BUT the band-independent legibility layer rule applies: the *player* is always in the lit hole (never occluded), and once the hazard is *in contact range / actively threatening* its telegraph must read at full contrast even at the bubble rim — i.e. occlusion may hide a *distant* hazard, but must never hide a hazard that is currently a threat to the player. Pickups/gate: occluded with the geometry (hidden until seen) is correct and desirable (it's what makes fog-memory valuable). Build the dark plate / radial sprite at a z/layer *below* the player and active-threat telegraphs, *above* world geometry + distant pickups + distant hazard.**

**Rationale:** the readability ruleset mandates a *band-independent legibility layer* for player/loot/exits/threats. "Threats" there means *active* threats on the critical path — not "every enemy on the map is always visible," which would gut limited vision. The clean reconciliation: occlusion hides *information you haven't earned* (distant layout, distant hazard, unseen loot), but never hides *the consequence you're currently inside* (the player avatar, an attack that is about to land). Concretely, the I2 hazard sprite sorts *under* the plate when distant (hidden) but its *active telegraph* (the moment it's a live threat) sorts *over* the plate. Coordinate the exact z/CanvasLayer ordering with the I2 owner at the shared `main_game.gd` seam (Breakdown §6); if the radial-dark-sprite path (Q2) is used, ordering is plain `z_index`/`y_sort` and the CanvasLayer collision largely evaporates — another reason to prefer it.

### Q7 — One listener owns the "am-I-lost" flag; both cues are pure projections of it. CLOSED · **[Build]**.

**Decision: a single run-state listener (on the vision node) connects to `nav_lost_proxy` + `run_ended`, owns the boolean/episode state, drives its own screen-edge pulse directly, and sets a shared flag the `DecisionHUD` line *reads* (HUD owns no source of truth — per `DecisionHUD`'s rule). One owner, one clear, no double-state. The HUD line is signal-driven projection, not polling.**

**Rationale:** matches the project's signal-driven / single-source-of-truth architecture and `DecisionHUD`'s "pure projection, owns no source of truth" contract. The vision node is the natural owner (it already exists per dive, is run-state, freed with the band). The HUD line subscribes to a tiny "lost state changed" notification (a local signal from the vision node, or reads the shared flag each HUD refresh tick — prefer the former, no polling). Avoids the double-clearing the author worried about.

### Q8 — Use `current_depth_index` (as-built). CLOSED · **[Build]**, no change.

**Decision: confirmed — use `GameState.current_depth_index` throughout (as-built `game_state.gd:50`). Do not reintroduce the spec's older `current_depth`.** Pure as-built reconciliation, no design content.

---

### Summary for the Director (4 feel calls to disposition; each already has a shipping default so build is NOT blocked)

| # | Question | Shipped default (build proceeds) | Director may override |
|---|---|---|---|
| Q1 | Occlusion darkness | `OCCLUDE_ALPHA = 0.94` (near-opaque, anti-blindness floor) | → `1.0` for stark/void feel |
| Q3 | Lost-cue channel | screen-edge pulse **+** redundant HUD word, no audio | → pulse-only, or add audio sting (M-later) |
| Q4 | When to surface the proxy | pulse on 1st emit, persistent HUD word on 2nd+ | → word-on-first (louder), or telemetry-only (rejected by me) |
| Q5 | Fog-memory look | cool desat ghost, flat/static, readable shape | → fainter outline (forces re-exploration) |

**Non-feel resolutions (no Director needed):** Q2 (occlusion *mechanism* — substitute radial-dark-sprite / world-space mask for the CanvasLayer-cut; node-based, no shader, **flag the viewport-coverage corner case to build**), Q6 (hazard hidden-until-seen but active threat + player stay on the legibility layer; coordinate z-order with I2), Q7 (one listener owns the lost flag; HUD projects it), Q8 (use `current_depth_index`).

*Resolved by `ui-ux-designer` (Phase 3, fresh-eyes, 2026-06-19). Occlusion approach APPROVED with the Q2 mechanism substitution. All 8 Open Questions CLOSED; 4 flagged ⚠ NEEDS DIRECTOR REVIEW with shipping defaults so build is unblocked.*

## 4. Acceptance criteria (restated concrete, from Breakdown §I4)

1. **Occlusion, not dimming.** With R4 vision on (`r4_vision_radius > 0`), geometry **beyond the radius is hidden** (not faintly visible) — a clear bright bubble, a hard-ish rim, hidden beyond. The M1.1 "darkened-but-readable far band" is gone.
2. **Fog memory legible.** With `r4_fog_enabled`, explored area reads as a **distinct third state** (clearly not never-seen-black, clearly not live-bright). Three reads are visually separable.
3. **Lost cue legible.** When `nav_lost_proxy` fires (Proxy A crosses `r4_lost_proxy_threshold`), a **visible cue** appears (per §3 Q3/Q4 resolution); it clears on real depth progress / run end. The player can tell they're "lost."
4. **Radius tuned to I1.** Vision radius/tightening presets are re-expressed against I1's as-built room scale (one bubble ≈ one room, not the band).
5. **Off = full M1.0/M1.1 vision.** With R4 off or `r4_vision_radius == 0`: **no overlay, no occlusion, no cue, no fog** — the baseline control, byte-identical behavior to M1.1 all-off.
6. **Cosmetic/visibility-only; determinism + seal intact.** I4 changes nothing the generator reads: `band.fingerprint(seed + config)` is unchanged; the band stays sealed (pairs with BUG4); no collision/geometry/RNG change. No new EventBus signal; `event_bus.gd` and `game_state.gd` not edited; `lost_proxy.gd` detection/telemetry unchanged (I4 only *listens*).
7. **Knobs take effect.** Every R4 vision/fog/lost knob set in CFG is reflected on screen (configurable-not-balanced standard).

---

## 5. Files to create / touch

**Touch (rework):**
- `entities/dive/vision_fog.gd` — replace dim-overlay with the occluding dark-plate + hard-light-hole (§2.A); legible three-state fog (§2.B); host/own the lost cue's screen-edge vignette + listen to `nav_lost_proxy` (§2.C). *(programmer + environment-artist for the greybox look/colors)*
- `entities/dive/vision_fog.tscn` — if the dark plate / `CanvasLayer` / cue vignette are authored as scene nodes rather than built in `_build_nodes()` (builder's call; M1.1 built them in code). *(programmer)*

**Possibly touch (only if the lost cue uses a HUD line, §3 Q3):**
- `ui/hud/decision_hud.gd` (+ `.tscn`, `hud_strings.csv` for a localized "Lost?" string) — a pure-projection HUD line reading a shared lost flag. *(ui-ux adjacent; keep `DecisionHUD`'s "owns no source of truth" rule)*

**Confirm NOT touched:**
- `systems/event_bus.gd` — **not edited** (`nav_lost_proxy` pre-declared; I4 listens only).
- `systems/game_state.gd` — **not edited** (reads `current_depth_index` / `max_depth_reached` / `active_run_config`).
- `entities/dive/lost_proxy.gd` — **detection + telemetry unchanged** (I4 only listens to the signal it emits).
- The B2/B3 generator, `socket_sealer.gd` (BUG4 owns the seal), collision, and the proc-gen RNG — unchanged (cosmetic-only).
- `scenes/game/main_game.gd` — ideally untouched (`_spawn_r4_nodes()` already instantiates `vision_fog.tscn` + `LostProxy`). **Watch the I2↔I4 `main_game.gd` collision** (Breakdown §6): if I4 must touch `main_game.gd` (e.g. layer ordering for the hazard vs. dark plate, §3 Q6), coordinate the seam with the I2 owner or sequence the merges.

---

*Authored by `game-director-designer` as Phase 2 of M1.2's three-phase process (Breakdown §4). This doc reworks the vision/fog/lost-proxy *presentation* from `R4_maze_navigation.md` §2 (Lever 2) / §3; it does not change R4's mechanics or determinism contract. Phase 3 (fresh-eyes) resolves §3; Director-flagged feel calls (§3 Q1, Q3, Q4, Q5) await the Director's verdict before build. Update alongside `M1_As_Built.md` as I4 resolves.*

---

**Changelog**
- **2026-06-19 — Phase-3 fresh-eyes (ui-ux-designer).** Independent UI/readability resolution of all 8 Open Questions (added §"Resolved Decisions (Phase 3)"). Occlusion approach APPROVED but with a **mechanism substitution (Q2)**: the §2.A "ColorRect-on-CanvasLayer cut by a PointLight2D light-mask" does not composite reliably in Godot 4; substitute a player-centred **radial-dark sprite / world-space mask** (still node-based, no shader, no geometry coupling) — flagged a viewport-coverage build corner case. Resolved Q1 (`OCCLUDE_ALPHA 0.94`, anti-blindness floor), Q3 (pulse **+** redundant HUD word — redundancy rule, not either/or; no audio), Q4 (pulse-on-1st / HUD-word-on-2nd emit; rejected telemetry-only), Q5 (cool desat ghost separated on a **non-hue** axis — flat/static vs lit/animated — for colourblind safety; one shared brightness-ladder source-of-truth with art), Q6 (hazard hidden-until-seen but player + active threat stay on the band-independent legibility layer; coordinate z-order with I2), Q7 (one listener owns the lost flag, HUD projects it, no polling), Q8 (`current_depth_index`). 4 confirmed ⚠ NEEDS DIRECTOR REVIEW feel calls (Q1/Q3/Q4/Q5), each shipping a default so build is unblocked.
- **2026-06-19 — Phase-2 authored.** Premise research (root-caused the M1.1 dim-not-occlude defect to CanvasModulate-multiply + additive-soft-light; fog illegibility to same-overlay tint; lost-proxy invisibility to telemetry-only emit). Recommended occlusion approach: opaque dark-plate `CanvasLayer` + hard-edged player light-hole (node-based, no shader, no geometry coupling; `LightOccluder2D`/shader deferred to the real vision system). Three-state legible fog (never-seen/remembered/live, cool color-shift). Lost cue = screen-edge disoriented pulse listening to the existing `nav_lost_proxy` (no new signal/state; `lost_proxy.gd` unchanged). Radius re-tuned against I1 (expressed in cells). 8 Open Questions (4 Director feel/fun calls flagged).
