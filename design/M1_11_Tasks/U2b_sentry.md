# U2b — New opposition #2: the SENTRY (def + one lane-watch component) — Expanded Design Spec

**Milestone:** M1.11 (Third-Gen Backend + Open-Field Band + Ranged Oppositions) · **Workstream:** oppositions · **Wave:** 1 (parallel worktree, file-disjoint from U0/U2a)
**Task id:** U2b · **BlockedBy:** none (rides the S0/S2/S3 opposition stack shipped in M1.9, extended by M1.10)
**Assignees:** general-purpose (host shell + `LaneWatch` component + its owned bolt/lane sub-nodes + `sentry.tres` + test) · character-animator (emplacement silhouette + lane strip + bolt greybox — inline placeholder; PixelLab Director-gated)
**Author:** game-director-designer · **Status:** Phase 2 (per-task design). The `Open Questions` below feed Phase 3 (fresh-eyes resolution + Director ratification).

> **What this doc is.** Per CLAUDE.md's four-phase authoring, this is the U2b per-task design: the M1.11 breakdown's §U2b contract expanded into mechanic detail, the `sentry.tres` def + `param_schema`, the ONE new component (`LaneWatch`) and its owned bolt/lane sub-nodes pseudocoded against the real S2 base contract, the **bolt-implementation decision (breakdown OQ10)**, the **lane-acquisition decision** (authored fixed vs. derived longest-sightline), the cover dialogue with the Lobber (U2a), spawn/placement rules, kill + throw semantics, the placeholder art spec, telemetry, and the acceptance-test plan. It ships **no game code and no `.tres`** — the programmer + character-animator build against it in Wave 1. Style/rigor mirror `design/M1_10_Tasks/T2a_ambusher.md` + `T2b_burrower.md` (the immediately-prior "def + one new component" proofs) and the shipped Charger (`charger_hazard.gd` + `charge_lane.gd`), the closest as-built template — **noting the Ambusher was reworked post-doc (FBM-A1 stalker loop); cite the as-built where docs differ.**
>
> U2b is one of M1.11's **cost-ledger proofs**: adding this opposition must cost **`sentry.tres` (data) + ONE new component (`LaneWatch`) + its owned bolt/lane sub-nodes + a thin Actor-host shell** and **nothing else** — no edits to the shared component set, `thrown_item.gd`, `EncounterBuilder`, `SpawnService`, or `event_bus.gd`. If it costs more, that overspend IS the UG3 scalability finding and must be recorded in the worklog's Bespoke-code ledger (§4). Its unique claim: it proves the component model absorbs **at-range threat + projectile emission** — an axis **all 9 shipped defs leave untested** (every shipped def is contact-lethal).

---

## 0. Hard constraints (read first)

Straight from the M1.11 breakdown scope guardrails ("No new opposition machinery", "M1 lethality model holds") and the shipped v2 opposition contract. The spec must not violate these, and neither may the implementation:

- **Content = data + ONE new component + its owned sub-nodes (the Phase-E price).** The Sentry ships as **`sentry.tres` (`OppositionDef`) + one new `OppositionComponent` (`LaneWatch`) + a thin host shell**, reusing `LethalContact` (`&"external"` gated kill), `ThrowInteraction` (`&"die"`), and `TelegraphFSM` (lane flash) unchanged — exactly as the Charger shipped as `charger.tres` + `ChargeLane` + `charger_hazard.gd`. **The bolt and the lane strip are `LaneWatch`-owned sub-nodes inside the Sentry's own scene ownership — they are NOT shared machinery** (breakdown §Scope guardrails). If the Sentry needs a second new component or a shared-file edit, the architecture (or this design) is wrong — surface it, don't paper over it (§4 seam note).
- **All-off is byte-identical.** The Sentry ships **off by default**: not in `RunConfig.new().oppositions_enabled`, not in `RunConfig.make_default_play_preset()`, not in `band_greybox`/`band_two`/`band_three` decks; `min_band = 4`. With the shipped default **no `sentry.tres` loads and no node spawns**, so the permanent all-off fingerprint **`e943ac9c8bc1`** and the three band fingerprints (`band_greybox`, `band_two`, `band_three`) are untouched. It becomes reachable only via `band_four`'s deck (U3) behind the fourth hub portal (U4).
- **M1 lethality model only — `kills`-gated `fail_run`, no HP pool.** The bolt is a lethal contact routed through the reused `LethalContact`'s `kills`-gated `GameState.fail_run(&"death")` with emit-always telemetry (`lethal_contact.gd:143-155`). No health bar, no chip damage, no damage-over-time. The bolt is the fatal contact; the sentry **body** itself is never contact-lethal (you can walk up to it — cover/approach is the whole counter).
- **Knob model frozen; per-def net extends to 11 defs.** No new hand-authored `RunConfig` levers. The Sentry appears via the count-agnostic generated Oppositions tab; the per-def `params`↔`param_schema` bijection extends to **11 defs** (9 shipped + Lobber + Sentry). Coverage assertions never dropped; **no global def-count hard-assert** in the new test (the M1.10 amendment-8 merge lesson).
- **RNG-free + deterministic.** `lane_watch.gd` + `sentry_hazard.gd` reference the global `RNG` autoload **nowhere** (the charger/burrower DoD audit; `test_sentry` greps for `"RNG."`). Generation-time placement is the builder's RNG-free stable stride; **lane acquisition** (the derived-sightline raycast, §1.4) is a pure function of static geometry + spawn position — reactive **run-state** (like R1's chase / ChargeLane's lane), computed once at first tick, never re-derived, and it **never feeds `fingerprint()`**. The FSM + bolt flight are real-time run-state.
- **Locked contracts, read-only.** Reads `GameState.current_depth_index` (live, BUG2); routes run-end through the **existing** `GameState.fail_run(&"death")` (no new end-cause); emits **only** the S0-pre-declared generic signals (`opposition_event`, `opposition_killed_player`) via the reused components — it does **not** edit `event_bus.gd`, `game_state.gd`, or `run_config.gd`.
- **File-disjoint in Wave 1.** U2b owns **new files only**: `data/oppositions/sentry.tres`, `scenes/hazards/sentry.tscn`, `scenes/hazards/sentry_hazard.gd`, `scenes/hazards/components/lane_watch.gd`, `tests/test_sentry.gd`/`.tscn`. The shared `config_strings.csv` `CFG_FIELD_SENTRY_*` gloss rows are **applied by the orchestrator in ONE integration commit at the Wave-1 merge** (the M1.10 amendment-6 protocol) — U2b's design lists them (§2.1) but does not write them. It does **not** touch `main_game.gd`, the shared `thrown_item.gd`, any menu file (the generated net picks the def up from `param_schema`), or the reused components. U0 owns `systems/bandgen/` + `band_profile.gd`/`band_pipeline.gd`; U2a owns its own component/def/test.
- **Placeholder art tint-only; PixelLab Director-gated.** The emplacement silhouette + lane strip + bolt ship as **inline greybox** (`Polygon2D` + `Tween`/modulate — the M1 greybox norm, D-RAT-4 precedent). Pixel filter OFF; copy-not-move from `art_workshop/`; any PixelLab run needs an explicit Director OK.

---

## 1. Research — why the Sentry, and why it is a clean architecture proof

### 1.1 The idea, restated as requirements

From `design/explorations/exploration-20260625/hazards/2-sentry.md`: a **stationary** emplacement that watches one straight lane of clear line-of-sight and fires a fast bolt down it the instant the player crosses into the lane. **It never moves, never chases, and only threatens the column of space directly in front of it.** Its behavioural distinctness is **lane denial**: unlike the pursuer (which turns the whole room into a keep-distance problem) or the Lobber (which punishes standing still), the Sentry makes *a specific line on the floor* lethal while leaving the rest of the room totally safe. The skill it forces is **route reading** — recognise the firing lane, cross it on the gap between shots (or not at all), and decide whether the loot in the lane is worth the timing.

The graybox states the exploration gives: `IDLE` (lane empty; lane telegraph readable) → `WINDUP` (player enters the lane: the lane flashes for `windup_ms ≈ 350`) → `FIRE` (spawn a fast bolt straight down the lane) → `COOLDOWN` (`cooldown_ms ≈ 1200`, can't fire) → `IDLE`. That is **structurally the Charger's three-beat rhythm** (readable wind-up → committed straight projectile → enforced recovery gap) with two inversions that make it a genuinely new axis: **(a) the threat travels — a projectile is emitted down the lane rather than the body lunging**, and **(b) the emplacement is stationary and the lane is fixed**, so the "dodge" is *leave the lane strip*, not *outrun the body*. This is the load-bearing observation that makes U2b a `def + ONE new component` proof (§1.3): the pounce/charge motion is replaced by a script-swept **bolt**, and everything else (wind-up telegraph, committed-lane fairness, swept `kills`-gated contact, enforced cooldown, throw-death) is the shipped stack.

**Why the Sentry is the "at-range / projectile" proof.** Mapping the 9 shipped defs against the projectile-emission axis:

| Shipped def | Threat delivery | At-range? |
|---|---|---|
| pursuer / splitter / splitter_child | body chases → contact | no (contact) |
| pingpong / spike | body moves on a path → contact | no (contact) |
| bomb | body detonates in place → radial blast distance test | *area*, but not emitted / not travelling |
| charger | body dashes a locked lane → swept contact | no (the *body* is the threat) |
| ambusher (FBM-A1 stalker) | hides → pursues → pounces → contact | no (contact) |
| burrower | buried rhythm → surfaces → contact | no (contact) |

**Nothing shipped emits a threat that travels away from the body.** The Sentry (and its partner the Lobber, whose shell travels on an arc) are the first. If the Sentry ships as `sentry.tres` + one `LaneWatch` component (+ its owned bolt sub-node) reusing `LethalContact`/`ThrowInteraction`/`TelegraphFSM` with **zero shared-file edits and all four control fingerprints byte-identical**, the component model is proven to absorb **projectile emission + LOS lane denial** — the last common opposition idiom the shipped set left untested. That is U2b's job, measured by the cost ledger (§4).

### 1.2 What is reused vs. the ONE new thing

| Concern | Source (as-built) | Reused / New |
|---|---|---|
| `CharacterBody2D` Actor host, `hazard` layer(16) / `world` mask(2), `"hazard"` group, `setup(cfg, player, spawn_ctx)` snapshot, self-timed run clock, fixed component tick order | S2 Actor-host family shell (`charger_hazard.gd` shape) | **Host shell — honest per-def cost** (S6a Wave-4 amendment: each def ships its own host until a shared parameterized host) |
| `kills`-gated `fail_run(&"death")` + emit-always `&"hit_player"` + BUG6 one-shot latch, driven by an external swept contact boolean | S2 **`LethalContact`** `&"external"` mode (`lethal_contact.gd:102-108`) | **Reused verbatim** — the bolt sweep feeds `apply_contact`, exactly as ChargeLane's dash sweep does |
| Tell colour-flip + wind-up flash juice on the lane strip | S2 **`TelegraphFSM`** (`telegraph_fsm.gd`) | **Reused** (new colour/shape *values*, not new code) |
| Throw-kill (spend an item to open the lane) | S2 **`ThrowInteraction`** `&"die"` + existing `thrown_item.gd` group path | **Reused verbatim** (no shared-file edit) |
| **LaneWatch: fixed-lane geometry acquisition, LOS/crossing detection, IDLE→WINDUP→FIRE→COOLDOWN FSM, bolt emission (a component-owned driven visual + script-swept lethal test), world-blocking of the bolt, feeding `LethalContact.apply_contact`** | **`lane_watch.gd`** (+ its `$Bolt`/`$Lane` sub-nodes) | **NEW — the one new artefact** |
| `sentry.tres` def + `param_schema` | data | **Data (the proof's whole point)** |

> **Why `LaneWatch` is genuinely new and small.** `ChargeLane` is the closest kin, but it is *the body dashing a lane* — it `move_and_slide()`s the host and computes contact off the host's own travel (`charge_lane.gd:128-133,178-185`). The Sentry's body **never moves**; the threat is a separate **travelling point** (the bolt) that (a) is world-blocked mid-flight (cover matters), and (b) has its own swept lethal test decoupled from any host motion. `LaneWatch` owns exactly that delta: the fixed-lane acquisition (§1.4), the four-phase FSM, and the bolt's driven position + swept `kills`-gated test + world raycast-stop. It does **not** move the host, and (unlike `Concealment`/`BurrowCycle`) it **never touches group membership** — the stationary sentry is *always* throw-killable, so there is no hittability cycle to manage (the simplest possible new-def shape). It reuses `ChargeLane`'s exact swept-test idiom (`Geometry2D.get_closest_point_to_segment` + `lane_width/2 + PLAYER_R`) so the "the bolt hit me" read is byte-honest with the Charger's "the ram hit me."

### 1.3 The bolt engine — a minimal component-owned bolt (NOT `thrown_item` reuse) — **breakdown OQ10**

The breakdown asks Phase 2 to decide the bolt on merit: **reuse `thrown_item.gd`'s flight lifecycle, or build a minimal component-owned bolt.** **Recommendation: a minimal `LaneWatch`-owned bolt — a driven visual sub-node whose lethal + world-block logic is a per-frame script sweep — NOT `thrown_item` reuse.**

**Why `thrown_item` reuse is a hack, not a clean fit.** `ThrownItem` (`entities/thrown_item/thrown_item.gd`) is **player-item-economy machinery**, not a generic projectile:

- It **carries a `JunkItem`** removed from `RunInventory` (`_item`), and on a "miss" it **re-drops that item** as a grabbable pickup via `EventBus.junk_dropped` (`thrown_item.gd:114-121`). An enemy bolt has no item to carry and must not spawn loot where it lands.
- It **targets the `"hazard"` group** and **kills hazards** (`_on_body_entered` → `_hit_hazard`, `thrown_item.gd:76-110`). The Sentry's bolt must do the **opposite**: ignore hazards, be **blocked by walls/cover** (world layer), and **kill the player** — the one thing `ThrownItem` has no concept of (its `collision_layer = 0`, `mask = world|hazard = 18`, it never tests the player).
- Its "miss" fires `throw_missed` telemetry and its kill fires `throw_killed_hazard` — the wrong vocabulary entirely for an enemy shot.

Reusing it would mean forking its collision mask (player, not hazard), stripping the `JunkItem`/re-drop/consume path, replacing `body_entered` hazard-kill with a player-lethal test, and muting its telemetry — i.e. rewriting ~everything it does while inheriting an `Area2D` physics-callback model the opposition stack deliberately **avoids** (`LethalContact` doc: *"the deterministic SCRIPT DISTANCE TESTS (never physics overlap)"*). That is more code, more coupling, and a shared-file edit to `thrown_item.gd`.

**The minimal component-owned bolt is smaller, cleaner, and idiomatic.** `LaneWatch` models the bolt as:
- **A driven visual** (`$Bolt: Polygon2D`, a `LaneWatch`-owned child): on `FIRE`, `LaneWatch` seats it at the muzzle and advances its `global_position` along the locked lane each frame (`pos += lane_dir * bolt_speed * delta`) — no physics body, no `move_and_slide`.
- **A script-swept lethal test** each flight frame: perpendicular distance from the player to the segment the bolt travelled this frame ≤ `lane_width/2 + PLAYER_R` → contact, fed to the reused `LethalContact.apply_contact(hit, true)` (the **exact** `ChargeLane._test_lethal_sweep` idiom, `charge_lane.gd:178-185`, tunnel-proof at any `bolt_speed`).
- **A world raycast stop** each flight frame: an `intersect_ray` against the `world` mask(2) over this frame's travel segment (the shipped `burrow_cycle.gd:185-199` direct-space-query idiom, null/space-less-safe). First world hit → the bolt stops at the hit point, that frame's swept test only covers muzzle→hit, and the bolt goes inert. **This is why cover blocks the bolt and the sentry is counterable.**

This keeps the whole projectile inside the ONE new component's ownership, uses the codebase's deterministic-script-test convention, needs **zero** `thrown_item.gd` edits, and is ~25-40 lines of bolt logic folded into `LaneWatch`. *(Technical — Phase-3 resolver confirms; the fallback (a bare Area2D bolt) is available if the visual-only approach ever proves awkward, but is not recommended.)*

### 1.4 Lane acquisition — **derive the longest clear sightline at setup** (recommended), with an authored override

**The question:** where does the Sentry's fixed lane point? Two options:

- **(A) Authored fixed direction** (`sentry.tres` carries a `lane_dir_deg`). *Trade-off:* in a **poisson-scattered open arena** (U0's `ScatterBackend`), the Sentry is placed by the builder's stable **cell stride** over the arena's floor cells (§2.5) — the band author **cannot know per-seed which cell a sentry lands on**, so a globally-authored direction will, for many seeds, point a sentry straight into a cover footprint or the arena wall 1-2 cells away → a dead, unreadable lane. Fixed authoring only works when placement is hand-controlled (a socket corridor), which scatter is not.
- **(B) Derive the longest clear sightline at setup** (recommended). At its **first physics tick** (when the physics space is guaranteed current — walls/cover are materialised before spawns), `LaneWatch` raycasts a **fixed candidate set** (8 octants: the 4 cardinals + 4 diagonals) from the muzzle out to `lane_length`, measures each ray's clear distance against the `world` mask, and **picks the longest**, tie-broken by a **fixed candidate order** (deterministic). It latches that direction once and never re-derives. *Trade-off:* the lane direction is not author-controlled — but for a **lane-denier dropped into a see-and-be-seen arena that is defined by long sightlines**, "watch the longest open lane you happen to sit on" is exactly the identity, and it makes the Sentry **backend-agnostic and placement-robust for free** (works in scatter, cave, and socket corridors identically), needs **no `EncounterBuilder` edit and no `spawn_ctx` lane hint**, and is fully deterministic (a pure function of static geometry).

**Recommendation: (B) derive longest-sightline at setup, latched once**, with an **optional authored override** `lane_dir_deg` (default `-1.0` = derive; `>= 0` = force that heading). The override lets a *future* socket band pin a corridor-facing sentry with one data field, at zero cost to the scatter default. This mirrors how the codebase already does reactive-but-deterministic geometry: the derived direction is run-state (like ChargeLane's live-player lane), never fed to `fingerprint()`. *(Technical — resolver confirms; see OQ-2.)*

> **Determinism note.** The raycast set + longest-pick + fixed tie-break is a pure function of the static world geometry and the spawn cell — identical across runs of the same `(profile + seed)` because both the geometry and the placement cell are seed-deterministic. It is computed at run-time (first tick), so it is **run-state** and correctly outside `fingerprint()` (generation-time). `test_sentry` asserts the *property* (longest-clear direction chosen), not a hashed schedule.

### 1.5 The cover dialogue with the Lobber (U2a) — the band's cover thesis

The M1.11 breakdown names Lobber + Sentry as `band_four`'s **cover dialogue**, and it is the reason to ship them as a pair:

- **The Sentry is why cover matters.** Its bolt is **world-blocked** (§1.3) — stepping behind a cover stamp *guarantees* safety from the lane. Cover becomes the readable "safe from the sentry" affordance the open arena otherwise lacks.
- **The Lobber is why you can't camp cover.** The Lobber's shell (U2a) **arcs over geometry** (cover does not protect from it) and punishes standing still. So the moment the Sentry pushes you into cover, the Lobber pushes you back out.
- **Together they enforce movement across the open field.** The intended felt loop: cross a sentry lane *on the cooldown gap* (don't camp), duck cover to break LOS, but keep moving so a Lobber marker never resolves under you. This is precisely the b1 open-field identity ("where do I stand, and what can see me") turned into a two-enemy puzzle. U2b's job is the Sentry half; the pairing is validated at UG2 (deaths-per-first-encounter + loiter-vs-sprint reads).

### 1.6 Readability budget (grounded in the real player numbers)

The hazard lives or dies on **the cooldown gap being crossable** and **the wind-up being long enough to step out of the lane**. Anchors (verified in-repo):

- **Player top speed `200` px/s** (`data/player/player_movement.tres` `max_speed = 200.0`), reached in ~0.1 s.
- **Cell size `16` px** (`main_game.gd:62` `DEFAULT_CELL_SIZE_PX`). **Player radius `14` px** → `ChargeLane.PLAYER_R = 14` (`charge_lane.gd:51`); the swept kill corridor half-width is `lane_width/2 + PLAYER_R`, so "the bolt hit me" reads honestly.

Derived defaults (every value is a **sweep start**, not a balance claim):

- **`windup_s` 0.40 s (the fairness line).** Reaction (~0.22 s) + lateral clear of the `lane_width/2 + PLAYER_R = 28` px corridor at 200 px/s (~0.14 s) + a thin margin → ~0.36 s; rounded up to 0.40. Slightly more generous than the exploration's 350 ms because the bolt is fast and the lane does not track — the wind-up is the *only* reaction window when you walk *into* a lane. **The bolt must NEVER fire before `windup_s` elapses (the fairness bar `test_sentry` pins).**
- **`cooldown_s` 1.2 s (the crossable gap).** The guaranteed-crossable bar: the time to carry the player centre from one edge of the danger strip to the other = `(lane_width + 2·PLAYER_R) / player_speed = (28 + 28)/200 = 0.28 s`. `cooldown_s = 1.2 s ≫ 0.28 s` → a huge margin; the lane is trivially crossable on the gap (and the gap is even larger in practice, since a re-fire also needs a fresh `windup_s`). **`test_sentry` computes this bar from the authored params and asserts `cooldown_s ≥ (lane_width + 2·PLAYER_R)/player_speed`.**
- **`bolt_speed` 700 px/s (~3.5× player).** Fast enough that once fired you cannot outrun it laterally *along* the lane — you must be *out of the strip* when it passes; the swept test keeps it tunnel-safe at any value. Matches the Charger's `charge_speed` feel band.
- **`lane_length` 480 px (~30 cells).** Long — the open arena's sightlines are the point; a sentry denies a genuinely long line. Wall/cover ends the bolt early. Sweeps down for tighter bands.
- **`lane_width` 28 px.** Same corridor as the Charger (`lane_width/2 + PLAYER_R = 28` px danger half-width) — a consistent "committed lane" read across the two lane hazards.

---

## 2. Design spec + pseudocode

### 2.1 `sentry.tres` — the `OppositionDef` (data — the proof's payload)

Authored against the S0/S2 `OppositionDef extends Resource` schema (`data/oppositions/opposition_def.gd`). All tuning lives in `params` with a mirroring `param_schema` (read by the generated menu + the params↔schema bijection lint). The host **maps** Sentry-semantic param keys to the reused components' expected keys in `_resolve_params` — the Charger's rename precedent (`charger_hazard.gd:117`, `proximity_radius = aggro_range`). Illustrative (authored in the inspector, mirroring `charger.tres`'s on-disk shape):

```
# data/oppositions/sentry.tres  (illustrative)
id             = &"sentry"                  # stable; events / telemetry / throw-kind / deck ref
display_name   = "Gate-Sentry"              # tone/naming — U3/Director ratifies; id stays &"sentry"
archetype      = "actor"
host_scene     = ExtResource("res://scenes/hazards/sentry.tscn")

# --- Spawn card (read by the EncounterBuilder) ---
credit_cost    = 2        # a lane-denial emplacement; peer to the Charger/Burrower
spawn_weight   = 1.0
min_band       = 4        # HARD gate to band 4 (breakdown OQ8); reinforced by bands 1-3 decks omitting it

# --- Hard caps (read by the SpawnService) ---
cap_group      = &"new_hazards"
per_room_cap   = 1        # one lane per room-chunk — avoid overlapping-lane "marker soup" (OQ-6)
per_band_cap   = 4

# --- Lethality (reused LethalContact, &"external") ---
lethality      = "lethal"
kills          = true     # standing convention: kills also lives in params (deck-sweepable); typed field agrees

params = {
    # --- Sentry-semantic knobs (host maps → component keys) ---
    "windup_s": 0.40,             # → the WINDUP flash lead (fairness line; bolt never fires before this)
    "cooldown_s": 1.2,            # → the crossable gap (IDLE re-fire guard)
    "bolt_speed": 700.0,          # → bolt travel speed down the lane (trap_if_neutral: 0 = no bolt)
    "lane_length": 480.0,         # → lane strip + bolt max travel + sightline-derive cap
    "lane_width": 28.0,           # → swept corridor (lane_width/2 + PLAYER_R) + visual strip width
    "lane_always_visible": true,  # telegraph mode: always-visible route puzzle vs reveal-on-windup (OQ-1)
    "fire_on_body_edge": false,   # crossing test: false = player CENTRE in strip; true = body edge (OQ-3)
    "lane_dir_deg": -1.0,         # lane acquisition: -1 = derive longest sightline; >=0 = authored heading (OQ-2)
    "kills": true,
    # --- Spawn-card count knobs (builder-read; never reach the entity) ---
    "base_count": 1,
    "count_per_depth": 0.0,
}
param_schema = [ ... ]    # one row per params key (bijection lint-checked)
```

**`param_schema` table** (defaults tuned against player 200 px/s + 16 px cells; sweep starts, not balance claims). `CFG_FIELD_SENTRY_*` gloss keys are **orchestrator-applied to `config_strings.csv` at the Wave-1 merge** (§0); U2b only names them:

| key | type | default | min | max | gloss (CSV key) | behaviour it drives |
|---|---|---|---|---|---|---|
| `base_count` | int | **1** | 0 | 10 | `CFG_FIELD_SENTRY_BASE_COUNT` | Builder spawn-card: base spawns per band. |
| `count_per_depth` | float | **0.0** | 0.0 | 5.0 | `CFG_FIELD_SENTRY_COUNT_PER_DEPTH` | Builder spawn-card: +spawns per depth index. |
| `windup_s` | float (s) | **0.40** | 0.15 | 1.5 | `CFG_FIELD_SENTRY_WINDUP_S` | `WINDUP` flash lead before the bolt fires — the readable "it's about to shoot" beat. **The fairness line: the bolt NEVER fires before this elapses.** Floor 0.15 borders unfair (§1.6). |
| `cooldown_s` | float (s) | **1.2** | 0.3 | 4.0 | `CFG_FIELD_SENTRY_COOLDOWN_S` | Post-fire gap where it can't fire — the crossable window. **Must satisfy `cooldown_s ≥ (lane_width + 2·PLAYER_R)/player_speed`** (§1.6; `test_sentry` bar). |
| `bolt_speed` | float (px/s) | **700** | 200 | 1400 | `CFG_FIELD_SENTRY_BOLT_SPEED` | Bolt travel speed down the locked lane. Swept test keeps any value tunnel-safe. `trap_if_neutral` (0 = no threat). |
| `lane_length` | float (px) | **480** | 64 | 960 | `CFG_FIELD_SENTRY_LANE_LENGTH` | Lane strip length = bolt max travel = the sightline-derive cap. Wall/cover ends the bolt early. |
| `lane_width` | float (px) | **28** | 16 | 64 | `CFG_FIELD_SENTRY_LANE_WIDTH` | Lethal corridor (swept half-width `lane_width/2 + PLAYER_R`) AND the visual lane strip width. Floored at ~`player_r + bolt_r`. |
| `lane_always_visible` | bool | **true** | — | — | `CFG_FIELD_SENTRY_LANE_ALWAYS_VISIBLE` | `true` = the lane strip is always drawn (pure route puzzle); `false` = strip only lights on `WINDUP` (learn-the-room surprise). **Vision/tone — OQ-1.** |
| `fire_on_body_edge` | bool | **false** | — | — | `CFG_FIELD_SENTRY_FIRE_ON_BODY_EDGE` | Crossing test: `false` = player **centre** enters the strip (forgiving, readable); `true` = any body edge (`+ PLAYER_R`, meaner). **Fun — OQ-3.** |
| `lane_dir_deg` | float (deg) | **-1.0** | -1.0 | 360.0 | `CFG_FIELD_SENTRY_LANE_DIR_DEG` | `-1` = derive the longest clear sightline at setup (recommended, scatter-robust); `>= 0` = force this heading (authored corridors). **§1.4 / OQ-2.** |
| `kills` | bool | **true** | — | — | `CFG_FIELD_SENTRY_KILLS` | The L5 `*_kills` toggle. `false` = the bolt emits contact but never `fail_run` (per-def gate; deck-sweepable). |

That is **11 keys** (2 spawn-card + 9 entity) — the charger/burrower shape. `bolt_speed` carries `trap_if_neutral: true` (0 = inert, the `charge_speed`/`catch_radius` convention). The host's code `DEFAULTS` mirror must equal these `params` values byte-for-byte (`test_sentry` case (1) pins it — no code/data drift). All-off: `sentry.tres` loads only when `&"sentry" ∈ oppositions_enabled` **and** a live deck lists it — the shipped default has neither, so nothing loads.

> **Host→component fixed flags (not authored knobs — set in `_resolve_params`).** `def_id = &"sentry"`, `emit_family = &"new_hazard_killed"`, `lethal_mode = &"external"`, `latch_rearm = true`, `throw_mode = &"die"`, `pulse_seconds = windup_s` (the `TelegraphFSM` throb basis). These are structural to "this def is a Sentry" — not tuning — matching how the Charger fixes them internally (`charger_hazard.gd:118-122`).

### 2.2 The `LaneWatch` component — the ONE new artefact

`LaneWatch` is a `class_name`-typed `OppositionComponent` (rides the S2 base contract, `opposition_component.gd`: host-owned child `Node`, no `_physics_process` of its own — the host calls `tick`). It owns **only**: (a) the fixed-lane acquisition (§1.4, latched at first tick), (b) the `IDLE→WINDUP→FIRE→COOLDOWN` FSM, (c) LOS/crossing detection, (d) the bolt (driven `$Bolt` visual + swept `kills`-gated test via the reused `LethalContact` + world raycast stop), and (e) driving the `$Lane` strip's geometry/visibility. It **never** moves the host, touches group membership, runs its own physics body, or emits telemetry (the host does, off the `on_state_changed` hook — the `ChargeLane` discipline). Illustrative, against the real base contract + the `ChargeLane` swept-test + the `burrow_cycle.gd` direct-space-query idioms:

```gdscript
class_name LaneWatch
extends OppositionComponent
## LaneWatch (U2b, M1.11) — the ONE new opposition component of the Sentry's
## at-range/projectile proof: a stationary emplacement that watches ONE fixed lane
## (IDLE) → flashes when the player enters it (WINDUP, the authored lead) → fires a
## fast world-blockable BOLT down the lane (FIRE) → can't fire for cooldown_s
## (COOLDOWN) → IDLE. The bolt is a component-owned driven visual with a swept
## kills-gated lethal test (the ChargeLane idiom) + a world raycast STOP (the
## burrow_cycle direct-space idiom) — cover blocks it, which is why the sentry is
## counterable. Everything else is REUSED verbatim: kill = LethalContact(&"external"),
## tells = TelegraphFSM, throw-death = ThrowInteraction(&"die").
##
## NEVER moves the host, NEVER touches group membership (the sentry is always
## throw-killable), NEVER self-ticks, NEVER emits telemetry (host does, off
## on_state_changed). RNG-FREE; the FSM + lane-derive + bolt flight are run-state and
## never feed fingerprint().

enum State { IDLE, WINDUP, FIRE, COOLDOWN }

const PLAYER_R := 14.0          # player.tscn CircleShape2D — the honest-contact floor
const WORLD_MASK := 2           # world collision layer (walls + cover footprints)
# The derive candidate set: 8 octants, FIXED order (deterministic tie-break).
const CANDIDATES := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP,
    Vector2(1,1).normalized(), Vector2(-1,1).normalized(),
    Vector2(-1,-1).normalized(), Vector2(1,-1).normalized()]

## Reused seams (host-assigned at _ready, the ChargeLane.lethal idiom):
var lethal: LethalContact = null
var on_state_changed: Callable = Callable()   # host paints tells + emits S0 rows here
## LaneWatch-owned sub-nodes (host-assigned; live in sentry.tscn):
var bolt: Node2D = null         # the $Bolt driven visual (hidden until FIRE)
var lane_vis: Node2D = null     # the $Lane strip visual (drawn per lane_always_visible)

# --- snapshotted knobs ----------------------------------------------------------
var _windup_s := 0.0
var _cooldown_s := 0.0
var _bolt_speed := 0.0
var _lane_length := 0.0
var _lane_width := 0.0
var _always_visible := true
var _body_edge := false
var _authored_dir_deg := -1.0

# --- run-state ------------------------------------------------------------------
var _state: int = State.IDLE
var _t := 0.0                    # time-in-state
var _lane_dir := Vector2.RIGHT   # the LOCKED lane heading (source of truth)
var _acquired := false           # lane derived+latched at first tick
var _bolt_pos := Vector2.ZERO    # bolt head (run-state)


func _configure(p: Dictionary, _ctx: Dictionary) -> void:
    _windup_s = maxf(float(p.get("windup_s", 0.0)), 0.0)
    _cooldown_s = maxf(float(p.get("cooldown_s", 0.0)), 0.0)
    _bolt_speed = maxf(float(p.get("bolt_speed", 0.0)), 0.0)
    _lane_length = maxf(float(p.get("lane_length", 0.0)), 0.0)
    _lane_width = float(p.get("lane_width", 28.0))
    _always_visible = bool(p.get("lane_always_visible", true))
    _body_edge = bool(p.get("fire_on_body_edge", false))
    _authored_dir_deg = float(p.get("lane_dir_deg", -1.0))
    # Re-setup resets the cycle WITHOUT firing the host hook (the family rule); the
    # host seats its own IDLE tell at setup(). Lane re-derived on the next first tick.
    _state = State.IDLE
    _t = 0.0
    _acquired = false
    if bolt != null: bolt.visible = false


## Called by the HOST each physics frame (fixed order; components never self-tick).
func tick(delta: float) -> void:
    if host == null or player == null:
        return
    if not _acquired:
        _acquire_lane()          # derive+latch ONCE, on the first tick (space is current)
        _acquired = true
    _t += delta
    match _state:
        State.IDLE:
            if _player_in_lane_with_los():
                _enter(State.WINDUP)          # the lane is committed (already fixed)
        State.WINDUP:
            # NON-LETHAL for the whole lead — the bolt is not spawned yet. This is the
            # fairness line: no lethal test runs until FIRE.
            if _t >= _windup_s:
                _bolt_pos = host.global_position          # muzzle
                if bolt != null:
                    bolt.global_position = _bolt_pos
                    bolt.visible = true
                _enter(State.FIRE)
        State.FIRE:
            _advance_bolt(delta)              # move + swept kill + world-block
        State.COOLDOWN:
            if _t >= _cooldown_s:
                _enter(State.IDLE)


func get_state() -> int: return _state
func get_lane_dir() -> Vector2: return _lane_dir


## Derive the LOCKED lane once. Authored override wins; else pick the longest clear
## sightline among the 8 fixed candidates (fixed order = deterministic tie-break).
func _acquire_lane() -> void:
    if _authored_dir_deg >= 0.0:
        _lane_dir = Vector2.RIGHT.rotated(deg_to_rad(_authored_dir_deg))
        return
    var best_dir := Vector2.RIGHT
    var best_clear := -1.0
    for dir: Vector2 in CANDIDATES:
        var clear: float = _clear_distance(dir)      # ray vs world, capped at lane_length
        if clear > best_clear:
            best_clear = clear
            best_dir = dir
    _lane_dir = best_dir


## Ray from the muzzle along `dir`; returns clear distance to the first world hit,
## capped at lane_length. Space-less-safe (a bare harness with no physics returns the
## full length so a test without walls still acquires a lane). The burrow_cycle idiom.
func _clear_distance(dir: Vector2) -> float:
    var origin: Vector2 = host.global_position
    var target: Vector2 = origin + dir * _lane_length
    var world := (host as Node2D).get_world_2d() if host is Node2D else null
    if world == null or world.direct_space_state == null:
        return _lane_length
    var q := PhysicsRayQueryParameters2D.create(origin, target, WORLD_MASK)
    q.collide_with_bodies = true
    var hit: Dictionary = world.direct_space_state.intersect_ray(q)
    if hit.is_empty():
        return _lane_length
    return origin.distance_to(hit["position"])


## Player is inside the lane strip AND the sentry has clear LOS to them. Crossing test
## is CENTRE by default (fire_on_body_edge=false), body-edge (+PLAYER_R) if set.
func _player_in_lane_with_los() -> bool:
    var origin: Vector2 = host.global_position
    var pp: Vector2 = player.global_position
    var along: float = (pp - origin).dot(_lane_dir)
    if along <= 0.0 or along > _lane_length:
        return false                          # behind the muzzle or past the lane end
    var seg_end: Vector2 = origin + _lane_dir * _lane_length
    var closest: Vector2 = Geometry2D.get_closest_point_to_segment(pp, origin, seg_end)
    var half: float = _lane_width * 0.5 + (PLAYER_R if _body_edge else 0.0)
    if pp.distance_to(closest) > half:
        return false                          # not in the strip
    return _los_clear(origin, pp)             # a wall/cover between us suppresses fire


## LOS: no world geometry between the muzzle and the player. Space-less-safe (true).
func _los_clear(a: Vector2, b: Vector2) -> bool:
    var world := (host as Node2D).get_world_2d() if host is Node2D else null
    if world == null or world.direct_space_state == null:
        return true
    var q := PhysicsRayQueryParameters2D.create(a, b, WORLD_MASK)
    return world.direct_space_state.intersect_ray(q).is_empty()


## FIRE: advance the bolt one frame down the locked lane, swept-kill the player, and
## STOP at the first world hit (cover blocks it) or at lane_length. On stop → re-arm
## the BUG6 latch (falling edge) and enter COOLDOWN.
func _advance_bolt(delta: float) -> void:
    var prev: Vector2 = _bolt_pos
    var step: Vector2 = _lane_dir * _bolt_speed * delta
    var next: Vector2 = prev + step
    # World-block: clip the travel segment at the first wall/cover hit.
    var blocked := false
    var world := (host as Node2D).get_world_2d() if host is Node2D else null
    if world != null and world.direct_space_state != null:
        var q := PhysicsRayQueryParameters2D.create(prev, next, WORLD_MASK)
        var hit: Dictionary = world.direct_space_state.intersect_ray(q)
        if not hit.is_empty():
            next = hit["position"]
            blocked = true
    # Swept lethal test over THIS frame's (clipped) travel — the ChargeLane idiom.
    if lethal != null:
        var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
            player.global_position, prev, next)
        var kill: bool = player.global_position.distance_to(closest) \
            <= _lane_width * 0.5 + PLAYER_R
        lethal.apply_contact(kill, true)      # emit-always + L5 kills gate + BUG6 latch
    _bolt_pos = next
    if bolt != null: bolt.global_position = next
    var traveled: float = host.global_position.distance_to(next)
    if blocked or traveled >= _lane_length:
        if bolt != null: bolt.visible = false
        if lethal != null: lethal.apply_contact(false, true)   # falling edge → re-arm
        _enter(State.COOLDOWN)


func _enter(next: int) -> void:
    _state = next
    _t = 0.0
    if on_state_changed.is_valid():
        on_state_changed.call(next)
```

**Host wiring + orchestration** (`sentry_hazard.gd`, mirroring `charger_hazard.gd`; the host is the honest per-def cost):

```gdscript
class_name SentryHazard
extends CharacterBody2D
## SentryHazard — the lane-denier (U2b, M1.11). S2 Actor-host skeleton verbatim; the
## behaviour is the reused component set + the ONE new LaneWatch:
##   LethalContact(&"external", bolt-fed) + TelegraphFSM(lane flash) +
##   ThrowInteraction(&"die", always throw-killable) + LaneWatch(NEW).
## Collision: layer hazard(16), mask world(2). Body NEVER moves, NEVER contact-lethal
## (only the bolt kills). id &"sentry". Ships OFF-default; min_band=4.

const DEFAULTS := { "windup_s": 0.40, "cooldown_s": 1.2, "bolt_speed": 700.0,
    "lane_length": 480.0, "lane_width": 28.0, "lane_always_visible": true,
    "fire_on_body_edge": false, "lane_dir_deg": -1.0, "kills": true }

# Greybox palette (character-animator ratifies at the gate). Distinct from every
# shipped hazard by silhouette (a squat FIXED turret with a drawn lane) + the bolt.
const COLOR_IDLE := Color(0.42, 0.45, 0.5)          # cold steel — watching
const COLOR_WINDUP := Color(0.95, 0.55, 0.15)       # amber flash — locking on
const COLOR_FIRE := Color(0.95, 0.15, 0.15)         # alarm red — firing
const COLOR_LANE := Color(0.9, 0.85, 0.3, 0.14)     # faint yellow sightline strip
const COLOR_LANE_HOT := Color(0.95, 0.2, 0.15, 0.30)# hot strip during windup/fire
const COLOR_BOLT := Color(1.0, 0.9, 0.4)            # bright fast bolt

var _cfg: RunConfig
var _player: Node2D
var _spawn_time := 0.0
var _lethal: LethalContact = null
var _fsm: TelegraphFSM = null
var _throw: ThrowInteraction = null
var _watch: LaneWatch = null
@onready var _body_vis: Polygon2D = $Body     # the turret silhouette (TelegraphFSM tell)
@onready var _lane_vis: Polygon2D = $Lane     # the sightline strip (LaneWatch-owned)
@onready var _bolt_vis: Polygon2D = $Bolt     # the bolt (LaneWatch-owned, hidden at rest)


func _ready() -> void:
    _lethal = OppositionComponent.acquire(self, LethalContact) as LethalContact
    _fsm = OppositionComponent.acquire(self, TelegraphFSM) as TelegraphFSM
    _throw = OppositionComponent.acquire(self, ThrowInteraction) as ThrowInteraction
    _watch = OppositionComponent.acquire(self, LaneWatch) as LaneWatch
    _fsm.tell = _body_vis
    _watch.lethal = _lethal
    _watch.bolt = _bolt_vis
    _watch.lane_vis = _lane_vis
    _watch.on_state_changed = _on_state


func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
    _cfg = cfg
    _player = player
    _spawn_time = 0.0
    var p := _resolve_params(spawn_ctx)
    _lethal.bind(self, player, p, spawn_ctx)   # resets the BUG6 latch (re-setup safe)
    _fsm.bind(self, player, p, spawn_ctx)
    _throw.bind(self, player, p, spawn_ctx)    # &"die": spend an item to open the lane
    _watch.bind(self, player, p, spawn_ctx)    # seats IDLE (lane derived on first tick)
    _seat_idle_visual()                        # + draw the lane strip per lane_always_visible


func _resolve_params(spawn_ctx: Dictionary) -> Dictionary:
    var dp: Dictionary = spawn_ctx.get("params", {})
    var p: Dictionary = {}
    for key: String in DEFAULTS:
        p[key] = dp.get(key, DEFAULTS[key])
    p["def_id"] = &"sentry"
    p["emit_family"] = &"new_hazard_killed"
    p["lethal_mode"] = &"external"
    p["latch_rearm"] = true
    p["throw_mode"] = &"die"
    p["pulse_seconds"] = float(p["windup_s"])
    return p


func _physics_process(delta: float) -> void:
    if _player == null or _cfg == null or not is_instance_valid(_player):
        return                                 # the family guard, verbatim
    _spawn_time += delta
    _watch.tick(delta)                         # the four-phase FSM + bolt
    _update_lane_visual()                      # presentation only (headless-safe)


func run_clock_ms() -> int: return int(_spawn_time * 1000.0)
func get_def_id() -> StringName: return &"sentry"
func resolve_throw_death(killer_ctx: Dictionary) -> bool:
    return _throw.resolve_throw_death(killer_ctx)   # &"die" → false → thrower frees us


## LaneWatch transition hook: hard tell flips + the S0 LOCKED telemetry vocabulary.
func _on_state(next: int) -> void:
    var depth: int = GameState.current_depth_index
    var run_t_ms: int = run_clock_ms()
    match next:
        LaneWatch.State.WINDUP:
            _body_vis.color = COLOR_WINDUP
            _fsm.flash_scale(1.3, 0.05, float(_watch._windup_s))   # amber lock-on ramp
            EventBus.opposition_event.emit(&"sentry", &"telegraph", depth, run_t_ms)
        LaneWatch.State.FIRE:
            _body_vis.color = COLOR_FIRE
            EventBus.opposition_event.emit(&"sentry", &"state", depth, run_t_ms)
        LaneWatch.State.COOLDOWN:
            _body_vis.color = COLOR_IDLE
            EventBus.opposition_event.emit(&"sentry", &"state", depth, run_t_ms)
        LaneWatch.State.IDLE:
            _body_vis.color = COLOR_IDLE
            EventBus.opposition_event.emit(&"sentry", &"state", depth, run_t_ms)
```

Notes for the programmer:
- **Lane derived at first tick, not `_configure`.** The physics space must be current for the raycasts (walls/cover materialised before spawns). Deriving in `_configure`/`setup` risks querying before the space registers the just-added node's neighbours; the first-`tick` derive (guarded by `_acquired`) is safe and latches once. `_clear_distance`/`_los_clear` are space-less-safe (return the full length / `true`) so a bare test harness with no physics space still acquires a lane and can fire.
- **The bolt is a component-owned VISUAL, not an `Area2D`.** No new physics body, no `body_entered`. The kill is `LaneWatch`'s swept script test (the `ChargeLane` idiom); the world-block is an `intersect_ray` (the `burrow_cycle` idiom). Zero `thrown_item.gd` edit (§1.3).
- **The sentry body never moves and is never contact-lethal.** `LethalContact` fires **only** from the bolt sweep during `FIRE`; standing on the emplacement is harmless (you approach to throw). No lethal test runs in IDLE/WINDUP/COOLDOWN → non-lethal for free.
- **Always throw-killable.** The host stays in the `"hazard"` group at all times (no membership cycling), so `ThrownItem` can pop it in any state — the "spend an item to open the lane" counter (OQ-4). Unlike the Ambusher/Burrower there is no hittability phase to manage.
- **Telemetry vocabulary is S0's LOCKED set** (`&"spawned"` (service) / `&"telegraph"` (WINDUP) / `&"state"` (FIRE/COOLDOWN/IDLE) / `&"hit_player"` (LethalContact) / `&"killed_by_throw"` (ThrowInteraction)) + the gated `opposition_killed_player`. No new token, no `event_bus.gd` edit.
- `_watch._windup_s` read in the host hook is illustrative; expose a `LaneWatch.windup_s()` getter if you prefer not to reach a private field.

### 2.3 `sentry.tscn` (mirrors `charger.tscn`)

```
[node name="Sentry" type="CharacterBody2D" groups=["hazard"]]
  collision_layer = 16       # hazard (always — the sentry is always throw-killable)
  collision_mask = 2         # world (never move_and_slide'd; kept for consistency)
  script = sentry_hazard.gd
  [Lane : Polygon2D]  # the sightline strip (LaneWatch-owned; drawn per lane_always_visible)
  [Body : Polygon2D]  # the squat turret silhouette (TelegraphFSM tell)
  [Bolt : Polygon2D]  # the fast bolt (LaneWatch-owned; visible=false at author time)
  [CollisionShape2D : CircleShape2D radius≈14]
```
Node name `"Sentry"` + `get_def_id()` give `ThrownItem._hazard_kind` a stable kind (`thrown_item.gd:135-137`). The `$Lane`/`$Bolt` polygons are the ONE-new-component's owned sub-nodes (breakdown §Scope guardrails: "a projectile/marker sub-node lives inside the component's own scene ownership").

### 2.4 Kill + throw semantics (M1 lethality model; reused components)

- **Only the bolt (in `FIRE`) is lethal.** The bolt's swept segment test feeds `LethalContact` `&"external"` (§2.2 `_advance_bolt` → `lethal_contact.gd:102`): emit-always `&"hit_player"`, `kills`-gated `fail_run(&"death")`, BUG6 one-shot latch. `IDLE`/`WINDUP`/`COOLDOWN` run **no** lethal test → non-lethal for free. The body is **never** contact-lethal in any state — this *is* the DoD's "at-range only" claim and the "you can approach it to throw" counter.
- **`kills = false`** → the bolt emits `&"hit_player"` but never `fail_run` — proves the per-def toggle (deck-sweepable). No new end-cause.
- **The bolt re-arms the latch on stop.** When the bolt hits a wall/cover or reaches `lane_length`, `LaneWatch` calls `apply_contact(false, true)` (falling edge) so the *next* bolt catches cleanly (the `charge_lane.gd:139` idiom). A player standing in the lane across two shots is caught at most once per shot.
- **Always throw-killable (the lane-opening counter).** The host stays in the `"hazard"` group in every state, so a thrown item resolves `_hit_hazard` → `ThrowInteraction` `&"die"` → `false` → the thrower frees it (`thrown_item.gd:96-110`, untouched). Spend a sale-value item to permanently open the lane (OQ-4). The throw-kill fires mid-`FIRE` too (freeing the sentry does not retract an in-flight bolt this frame — an acceptable edge; the bolt is a visual that despawns with the freed host next frame).

### 2.5 Spawn / placement rules (builder + service — no U2b placement code)

Placed by the **default `EncounterBuilder`** from `band_four`'s deck through the **`SpawnService`** (`svc.spawn(d, cell, ctx)` → `hz.global_position = cell_to_world(cell)`, `spawn_service.gd:121`), exactly like every opposition — U2b adds **no** placement code:

- **Eligibility:** in the deck iff `band.band_depth >= sentry.min_band` (=4). `band_four` lists it; bands 1-3 do not → band-4-native for M1.11 (breakdown OQ8; OQ-5 here).
- **Budget:** `credit_cost = 2` debited from the builder's `I`-scaled band budget (`instability(4) = 1.45`).
- **Caps (service-enforced):** `per_room_cap = 1` (one lane per room-chunk — the anti-marker-soup dial, OQ-6), `per_band_cap = 4`.
- **Determinism:** the placement cell is the builder's stable RNG-free stride (`encounter_builder.gd:356-368`). The **lane direction** is then derived by `LaneWatch` at first tick from the static geometry around that cell (§1.4) — deterministic, RNG-free, run-state, never fed to `fingerprint()`.
- **No lane-hint needed.** Because the lane is derived from geometry at setup, the Sentry needs **no `spawn_ctx` hint** and **no `EncounterBuilder` edit** — the crucial "backend-agnostic, placement-robust" property (§1.4). The open arena's long sightlines mean a strided sentry almost always sits on a genuinely long lane; the `per_room_cap = 1` keeps two sentries from stacking overlapping lanes.

### 2.6 Telemetry

Emits **only** S0-pre-declared generic signals via reused components — no sentry-specific signal, no `event_bus.gd` edit:

| Signal / `event` | When | Emitter |
|---|---|---|
| `opposition_event(&"sentry", &"spawned", …)` | on spawn | **SpawnService** (central) |
| `opposition_event(&"sentry", &"telegraph", …)` | WINDUP (lock-on flash begins) | host `_on_state(WINDUP)` |
| `opposition_event(&"sentry", &"state", …)` | FIRE / COOLDOWN / IDLE transitions | host `_on_state` |
| `opposition_event(&"sentry", &"hit_player", …)` | bolt contact (emit-always, even if `kills=false`) | reused **LethalContact** (BUG6-latched) |
| `opposition_event(&"sentry", &"killed_by_throw", …)` | throw-kill (def-id-stable) | reused **ThrownItem**/`ThrowInteraction` |
| `opposition_killed_player(&"sentry", …)` | gated — only when `kills` fires `fail_run` | reused **LethalContact** |
| `run_ended(reason=&"death", …)` | fatal bolt contact | `GameState.fail_run(&"death")` |

`&"telegraph"` (WINDUP) + `&"hit_player"` (contact) + its absence (crossed on the gap) let UG2 measure "did players read the lane" (deaths-per-first-encounter vs Ambusher/Burrower/Wrecker baselines — breakdown UG2). With the Sentry off, none of these rows appear (no node exists).

### 2.7 Placeholder asset spec (character-animator — inline greybox; PixelLab Director-gated)

Per the M1 greybox norm (D-RAT-4), stubbed inline (`Polygon2D` + `modulate`/`Tween`) — no sprite sheets, no `AnimationTree`, no paid generation without an explicit Director OK. The Sentry must read **apart from** every shipped hazard by **silhouette** (a squat, **fixed** turret — it never moves, unlike every chaser), by **its lane** (a drawn sightline strip no other hazard has), and by **its bolt** (the first travelling threat).

- **Root node name `Sentry`** (throw-kill telemetry self-logs a stable `kind` via `get_def_id()`).
- **`$Lane`** (LaneWatch's `lane_vis`) — a long thin translucent strip along the locked lane, `lane_width` wide × `lane_length` long. Drawn faint (`COLOR_LANE`, always) when `lane_always_visible = true`; hidden until WINDUP when `false` (OQ-1). Brightens to `COLOR_LANE_HOT` during WINDUP/FIRE. **This is the route-reading affordance.**
- **`$Body`** (TelegraphFSM's `tell`) — the squat turret silhouette (~24-28 px), `COLOR_IDLE` cold steel at rest, amber `COLOR_WINDUP` on lock-on (a scale-flash over `windup_s`), red `COLOR_FIRE` on the shot. Compact + fixed reads "emplacement," not "chaser."
- **`$Bolt`** (LaneWatch's `bolt`) — a small bright fast projectile (`COLOR_BOLT`, ~8-10 px), `visible=false` until FIRE, streaking down the lane. A short motion-streak sells the speed.

- **Per-state read:**

  | State | `$Body` | `$Lane` | `$Bolt` | juice |
  |---|---|---|---|---|
  | `IDLE` | cold steel | faint (if always-visible) | hidden | still |
  | `WINDUP` | amber, brightening | hot strip | hidden | lock-on scale-flash over `windup_s` |
  | `FIRE` | alarm red | hot strip | streaking bolt | bolt motion-streak |
  | `COOLDOWN` | cold steel | faint | hidden | strip cools (the "safe now" read) |

`LaneWatch` drives the lane strip geometry/visibility + the bolt transform; `TelegraphFSM` drives the body tell colour/flash. No component touches another's node.

---

## 3. Definition of done (concrete — the acceptance bar)

Restated from the breakdown's §U2b DoD, with the test names U2b adds (`tests/test_sentry.gd` + `.tscn`, run **as a scene** per the headless-test convention — `godot --headless --path Game res://tests/test_sentry.tscn`). The shape mirrors `test_charger.gd`/`test_burrower.gd` (stub player, `spawn_ctx["params"]` fast-cycle knobs, real physics frames, signal sinks, StaticBody walls via `_make_wall`).

1. **All-off fp unmoved.** With the shipped default (`&"sentry" ∉ oppositions_enabled`, not in the default play preset, not in bands 1-3 decks), **no `sentry.tres` loads, no node spawns**, and the all-off fingerprint **`e943ac9c8bc1`** is byte-identical (test asserts).
2. **`params`↔`param_schema` bijection (11 defs).** `sentry.tres` passes the per-def coverage assertion + the Python `.tres` linter — every `params` key has exactly one `param_schema` entry and vice-versa, all within declared min/max; entity params mirror `SentryHazard.DEFAULTS` exactly (no code/data drift). **No global def-count hard-assert** (amendment-8).
3. **Menu section auto-appears.** With `&"sentry"` loaded, the generated debug-menu builds a Sentry collapsible section from `param_schema` headlessly (no hand-authored rows).
4. **`test_sentry` (headless scene) asserts:**
   - **(a) Lane geometry from params.** With `lane_dir_deg = 90`, `get_lane_dir()` ≈ `Vector2.DOWN`. With `lane_dir_deg = -1` (derive) and walls arranged so exactly one candidate direction is clear to `lane_length` while the others hit walls close, the derived `get_lane_dir()` equals that clear direction (the longest-sightline pick + fixed tie-break).
   - **(b) Windup lead honored (the fairness line).** Player standing in the lane: `IDLE→WINDUP` fires exactly one `&"telegraph"`; the state holds `WINDUP` for ~`windup_s` (frame tolerance) with **zero** `&"hit_player"` and **no** `$Bolt.visible` before FIRE — **the bolt never fires before the authored flash elapses.**
   - **(c) Bolt kill `kills`-gated.** `kills=true`, player parked on the lane axis within `lane_width/2 + PLAYER_R` at bolt range → after FIRE, `fail_run(&"death")` (`GameState.run_active` false, cause `&"death"`) + `opposition_killed_player(&"sentry")` **exactly once** (BUG6) + one `&"hit_player"`. `kills=false`, same geometry → `&"hit_player"` fires but the run stays active, no `opposition_killed_player`.
   - **(d) Bolt stopped by a wall/cover cell.** A `world`-layer wall placed on the lane axis **between** the muzzle and a player beyond it → after FIRE, the player beyond the wall is **not** killed (`run_active` true, zero `&"hit_player"`), and the bolt's final position is at/before the wall face. Contrast: no wall, same geometry → the player IS killed (case c).
   - **(e) LOS suppresses fire.** A wall between the sentry and a player who is geometrically in the lane strip → `IDLE` does **not** transition to `WINDUP` (no `&"telegraph"`), because `_los_clear` is false. Remove the wall → it winds up.
   - **(f) Cooldown gap crossable (the fairness bar).** Compute `bar = (lane_width + 2·PLAYER_R) / 200.0` from the authored params; assert `cooldown_s >= bar` for the shipped defaults (1.2 ≥ 0.28). Behaviourally: after a FIRE, the sentry holds `COOLDOWN` ~`cooldown_s` and cannot re-fire; a player who enters and exits the strip within that window takes no hit.
   - **(g) Throw-kill disables.** A thrown item at the sentry in any state (`IDLE`/`WINDUP`/`FIRE`/`COOLDOWN`) → `throw_killed_hazard(&"sentry")`/`&"killed_by_throw"`, the sentry is freed (`queue_free`), and no further bolts fire (re-entering the lane produces no new `&"telegraph"`). The sentry is in the `"hazard"` group in every state.
   - **(h) Body is never contact-lethal.** Park the player ON the sentry body (not in the firing lane, or with `bolt_speed=0` `trap_if_neutral`) across a full cycle → `run_active` stays true, zero `&"hit_player"`. Only the bolt kills.
   - **(i) Deterministic placement.** The same synthetic `band_four`-shaped band + deck twice through the REAL `EncounterBuilder` + `SpawnService` yields identical Sentry spawn cells; `per_band_cap` binds; `min_band = 4` refuses a band-depth-3 profile entirely.
   - **(j) No global RNG.** `lane_watch.gd` + `sentry_hazard.gd` sources contain no `"RNG."` substring (determinism audit).
   - **(k) Visuals render.** `$Body`, `$Lane`, and `$Bolt` polygons triangulate to >0 triangles (the invisible-hazard guard).
5. **Process:** a U2b worklog names the real commit SHA(s) for the programmer + character-animator contributions; `godot --headless --path Game --import` compiles the new scene/script/tres; the smoke test is green; the worklog's **Bespoke-code ledger** records the exact non-data, non-test line counts (§4) and the **Design deviations** section records any departure (or "none") for the Wave-1 close-out sweep.

---

## 4. Bespoke-code cost-ledger prediction (the UG3 scalability evidence)

The breakdown makes the cost ledger version-defining (the N=3 trend UG3 judges). **Predicted** U2b spend beyond the promised `def + ONE component`:

| Artefact | Kind | Predicted | In the "def + one component" budget? |
|---|---|---|---|
| `data/oppositions/sentry.tres` | data | ~1 resource | Yes — the point |
| `scenes/hazards/components/lane_watch.gd` | **new component code** | **~120-150 lines** (FSM + lane-derive raycast + LOS/crossing + bolt sweep + world-block) | **Yes — the ONE new component + its owned bolt/lane logic** |
| `scenes/hazards/sentry_hazard.gd` | host shell code | ~110-140 lines | **Expected honest per-def cost** (S6a Wave-4 amendment: each def ships its own Actor host; NOT a new *behaviour* script) |
| `scenes/hazards/sentry.tscn` | scene | 1 | Expected (host + 3 polygons + collision) |
| `tests/test_sentry.gd` + `.tscn` | test | ~450-550 lines | Excluded from the ledger (test code) |
| `config_strings.csv` `CFG_FIELD_SENTRY_*` rows | data | ~11 rows | Yes — data (**orchestrator-applied at merge**, §0) |

**Predicted edits to shared/reused files: ZERO.** `charge_lane.gd`, `lethal_contact.gd`, `throw_interaction.gd`, `telegraph_fsm.gd`, `thrown_item.gd`, `encounter_builder.gd`, `spawn_service.gd`, `event_bus.gd` all untouched. **If any is touched, that is the ledger's headline overspend and a flagged deviation** — the one risk point to watch:
- **The bolt.** The design keeps the bolt entirely inside `LaneWatch` as a driven visual + script sweep + `intersect_ray` block (§1.3) — no `thrown_item.gd` edit, no new `Area2D`. *Predicted: not needed.* If a physics-body bolt is ever chosen instead, it is still a `LaneWatch`-owned sub-node (its own scene ownership), NOT a `thrown_item.gd` fork — a `thrown_item.gd` edit would be the deviation.

`LaneWatch` is the **larger** of the M1.10/M1.11 new components (it folds the projectile logic in), but it is still **one component**, and the shared stack is untouched — the at-range axis costs *one richer component*, not engine rework. That is the scalability claim U2b is here to prove, and the N=3 trend line UG3 reads.

---

## Open Questions

> Each stated with trade-offs for Phase-3 fresh-eyes resolution. Genuine **fun/fairness/tone/scope/vision calls are flagged `**NEEDS DIRECTOR REVIEW**`** with a recommendation — the resolver does not self-decide those.

### OQ-1 — `**NEEDS DIRECTOR REVIEW**` (vision/tone) — Lane telegraph: always-visible (route puzzle) vs. reveal-on-windup? *(breakdown OQ6)*
The exploration leans **always-visible** ("pure route puzzle"); reveal-on-windup is "a learn-the-room surprise that may feel cheap on first death." §2.1 defaults `lane_always_visible = true`. *Director question:* **Ship the always-visible lane (the readable route-reading puzzle), or reveal-on-windup for a tenser learn-the-room read?** *Recommendation:* **always-visible** — the Sentry's whole skill is *reading the safe route before you commit*, which requires seeing the lane; reveal-on-windup converts first encounters into unavoidable deaths (the b1 "empty vs tense" fun flag would read as "cheap"). Keep the knob so UG2 can A/B if the always-visible arena reads *too* safe. *Director ratifies; the default is data-cheap to flip.*

### OQ-2 — Lane acquisition: derive longest-sightline at setup (recommended) vs. authored fixed direction? *(technical — resolve on merit)*
§1.4 recommends **deriving the longest clear sightline** at first tick (scatter-robust, backend-agnostic, no `EncounterBuilder`/`spawn_ctx` edit) with an optional `lane_dir_deg` authored override for hand-placed corridors. The alternative — a globally-authored fixed direction — is fragile under poisson-scatter placement (points into cover/wall for many seeds). **Recommendation: derive + optional override.** *Technical — resolver confirms; the override field costs one schema row and future-proofs socket-corridor sentries. Sub-question the resolver should settle: the candidate set (8 octants recommended for readability + cheap determinism) vs. a finer sweep (more "optimal" lanes but muddier direction reads) — 8 octants recommended.*

### OQ-3 — `**NEEDS DIRECTOR REVIEW**` (fun) — Fire on the player's CENTRE crossing the lane, or any body edge? *(exploration OQ)*
Center-crossing (`fire_on_body_edge = false`, default) is "more forgiving and readable"; body-edge (`+ PLAYER_R`) is "meaner." §2.1/§2.2 default to center. *Director question:* **Ratify center-crossing for the first playtest, or start with body-edge?** *Recommendation:* **center-crossing** — the readable, forgiving default; body-edge makes the safe-strip narrower than the player can visually judge (feel-bad on a lane hazard whose whole point is legibility). UG2's deaths-per-first-encounter drives any tighten. *Director ratifies; TG-style sweep drives it.*

### OQ-4 — `**NEEDS DIRECTOR REVIEW**` (scope/fun) — Throw-disable: permanent kill (recommended) vs. temporary disable? *(breakdown OQ7 — the loot-piñata risk)*
The exploration flags: is permanent throw-disable "too strong — does it make Sentries trivial loot piñatas, or is 'spend an item to open a route' exactly the intended economy?" §2.4 ships **permanent** (reused `ThrowInteraction` `&"die"` → free the host; opens the lane forever). *Director question:* **Permanent disable (spend an item to open the lane forever), or temporary (re-arms after N s)?** *Recommendation:* **permanent** — it is the clean, readable use of the throw verb (every shipped def is `&"die"`), and "spend sale value to open a route" is a real economy choice, not a free win (the item is consumed, and the sentry is stationary so throwing it costs a committed approach into its own lane). Temporary disable needs a self-handled `resolve_throw_death → true` + a re-spawn timer (more machinery, a bigger ledger). The piñata risk is a **UG2 telemetry watch** (throw-kills-per-sentry vs items-spent), not a reason to add machinery pre-gate. *Director ratifies; resolve at the fun gate.*

### OQ-5 — `**NEEDS DIRECTOR REVIEW**` (scope) — Band-4-exclusive for M1.11? *(breakdown OQ8)*
The breakdown recommends both new oppositions be **band-4-exclusive** in M1.11 for a clean A/B at UG2 (the D-RAT-4 precedent). §2.1 encodes `min_band = 4` + deck membership. *Director question:* **Confirm the Sentry stays band-4-native for M1.11, or should it also enter a socket band's corridors (a strong fit for the lane-denier — a UG3 watch-item)?** *Recommendation:* **band-4-native for M1.11** (clean measurement; the open field is where the derived-sightline lane reads best). The socket-corridor promotion is a one-field `min_band` edit + a deck add, and the `lane_dir_deg` override already supports hand-placed corridor sentries — a strong post-gate follow-up (breakdown UG3 explicitly asks "sentry in a socket band's corridors?"). *Director confirms at the gate.*

### OQ-6 — Two sentries crossing lanes (marker soup): `per_room_cap = 1` (recommended) sufficient, or a placement/spacing rule? *(technical — resolve on merit)*
With derived-longest-sightline, two co-located sentries could pick lanes that visually cross, muddying the route read. §2.1 sets `per_room_cap = 1` (one lane per room-chunk). *Recommendation:* **`per_room_cap = 1` is sufficient** — the arena's chunk partition (U0) means one sentry per chunk, so overlapping lanes within eyeshot are rare, and `per_band_cap = 4` caps the total. A true minimum-lane-separation rule would need an `EncounterBuilder`/policy edit (forbidden this wave) — out of scope; flag as a UG2 watch if the open field reads as marker soup. *Resolver sets the cap; UG2 validates the felt read.*

### OQ-7 — Does the bolt pierce or stop on first hit? *(technical — resolve on merit)*
§1.3/§2.2 stop the bolt at the **first world hit** (wall/cover) and it does not "pierce" — there is only one target (the player), and stopping at cover *is* the counter. The only sub-question: a cover footprint that lies within `lane_width` but **not on the lane axis** — the axis-ray `intersect_ray` won't detect it, so the bolt passes such off-axis cover (correct: the bolt is a thin thing down the centre; partial-edge cover doesn't block a centred shot). **Recommendation: stop-on-first-axis-hit, no pierce, off-axis cover does not block.** *Technical — resolver confirms; this keeps the bolt a clean 1-D thing and matches the swept-corridor kill model (the danger is the centre strip, so the block test is the centre ray).*

---

*Phase 3 (fresh eyes, NOT this author) resolves the Open Questions into a `Resolved Decisions` section, flagging OQ-1 / OQ-3 / OQ-4 / OQ-5 (vision/fun/scope) for the Director per the orchestrator loop, and confirming OQ-2 / OQ-6 / OQ-7 on technical merit. Design-only — no code, no `.tres`. The programmer + character-animator build against this; deviations from the committed design go to `DESIGN_DEVIATIONS.md` for the Wave-1 close-out sweep, and the worklog carries the Bespoke-code ledger (§4) that UG3 judges.*

---

## Resolved Decisions (Phase 3) — BINDING

> Fresh-eyes resolution (2026-07-06, Phase-3 resolver — NOT the Phase-2 author), per the four-phase authoring
> process. Every as-built citation below was re-verified against the repo at resolution time. Verdicts on the
> technical OQs are **binding on the build**; the fun/fairness/tone/scope items are recommendations awaiting the
> Director (listed at the end). Where this section contradicts the Phase-2 body above, **this section wins.**

### Re-verification of the body's load-bearing claims (all checked against the repo)

- **ChargeLane swept-test idiom transfers to the bolt.** Verified `charge_lane.gd:178-185`: the sweep is pure
  segment math (`Geometry2D.get_closest_point_to_segment` over *this frame's travel segment* vs the player,
  corridor `lane_width/2 + PLAYER_R`) — it is **body-agnostic**. Nothing in it depends on the segment being the
  host's own `move_and_slide` travel; feeding it the bolt's driven-position segment is the same math, same
  tunnel-proofing, same `LethalContact.apply_contact(hit, true)` sink (`lethal_contact.gd:102-108` confirmed,
  `_fire` emit-always at `:143-155` confirmed). **The borrow is sound.**
- **`thrown_item.gd` rejection reasoning is ACCURATE.** Verified: it is an `Area2D` (`collision_layer 0`,
  `mask 18`), carries a `JunkItem` (`:24`), re-drops it via `junk_dropped` on any miss (`:114-121`), targets and
  kills the `"hazard"` group (`:76-110`), and speaks player-throw telemetry (`throw_killed_hazard`/`throw_missed`).
  Every one of those behaviours is wrong for an enemy bolt and would need forking, and its physics-callback model
  contradicts the opposition stack's locked convention (`lethal_contact.gd` header: "deterministic SCRIPT DISTANCE
  TESTS (never physics overlap)"). **Component-owned bolt HELD (breakdown OQ10 → resolved: minimal owned bolt).**
- **Fairness-bar arithmetic verified.** `PLAYER_R = 14` is real (`player.tscn` `CircleShape2D` `radius = 14.0`;
  matches `charge_lane.gd:51`); player `max_speed = 200.0` (`player_movement.tres:7`); cell 16 px
  (`main_game.gd:62`). Crossable bar `(lane_width + 2·PLAYER_R)/200 = (28+28)/200 = 0.28 s` ≤ `cooldown_s 1.2` ✓.
  The visual/kill honesty also survives the M1.10 kill_radius-34 lesson: the kill corridor half-width
  `lane_width/2 + PLAYER_R = 28` is exactly "your **body** overlaps the drawn 28 px strip" (center distance →
  body overlap conversion), the same read the Charger shipped; and since the sentry **body** is never lethal, the
  player↔hazard physical exclusion (player mask 26 includes hazard 16, sum-of-radii ≈ 28-30 px) creates no
  safe-to-hug paradox here — hugging the body to throw is the intended counter.
- **Collision constants verified.** `project.godot` layer 2 = `world` (mask value 2), layer 5 = `hazard`
  (mask value 16) — §2.3's scene values are correct.
- **One citation correction (non-load-bearing):** `burrow_cycle.gd:185-199` is an **`intersect_point`** query,
  not `intersect_ray`. What U2b borrows from it is the *direct-space-state + null/space-less-safe* pattern
  (`get_world_2d()`/`direct_space_state` null guards), which transfers; the ray form
  (`PhysicsRayQueryParameters2D.create`) is new-but-idiomatic, as pseudocoded in §2.2.

### Binding technical amendments (the derived-lane contract, hardened)

**A1 — Acquisition happens on the SECOND `tick()`, not the first (overrides §1.4/§2.2/§2.5's "first tick" wording).**
The body's claim that the physics space is "guaranteed current" at the first physics tick is **not backed by
anything in-repo**: the only shipped precedent for querying freshly-built static geometry, `BurrowCycle`'s
wall-surfacing guard, is (a) re-checked **every** tick until it passes (self-healing by design — a stale read
merely delays surfacing) and (b) first exercised ~`buried_s` seconds after spawn, long after the space synced.
A one-shot latch has neither safety: band materialisation and hazard spawning happen in the same idle frame, and
Godot's 2D broadphase only reliably reflects bodies added that frame **after the next physics step** — a ray cast
on the very first `tick()` can miss every wall, return all-clear on all 8 candidates, and silently latch
`CANDIDATES[0]` (RIGHT) forever. **Contract:** `LaneWatch` counts ticks; on tick 1 it does nothing (no FSM, no
lane test); on tick 2 it derives + latches (`_ticks >= 2` guard replacing the bare `not _acquired` check), and the
FSM runs from that tick on. One physics frame (~16 ms) of extra IDLE is imperceptible and deterministic. The FSM
must be **gated on `_acquired`** (never enter WINDUP before acquisition). Test rider: `test_sentry`'s derive case
adds walls, then the sentry, then awaits **≥ 2 physics frames** before asserting `get_lane_dir()` (the shipped
idiom — `test_burrower` always `_frames(N)`-waits after `_make_wall`).

**A2 — Latch the derived clear LENGTH with the direction (`_lane_len_eff`), and use it everywhere.**
`_acquire_lane` latches `_lane_dir` **and** `_lane_len_eff = best_clear` (authored-override path latches
`_lane_len_eff` from a single ray along the forced heading; space-less harness → full `lane_length`). The lane
strip visual is drawn at `_lane_len_eff` (a strip drawn through a blocking wall is a readability lie — the strip
is the route-reading affordance and must not overclaim), the crossing test uses `along <= _lane_len_eff`, and
`_advance_bolt`'s travel check compares against `_lane_len_eff`. This also makes the **degenerate dense-cover
pocket** (all 8 rays short) harmless **without any fallback machinery**: latch the longest candidate regardless —
a short lane is strictly *weaker*, never unfair (the bolt dies at the wall; the stub strip reads honestly).
No minimum-length floor, no refusal/inert state, no re-derive. U0's min-spacing + clear-lane construction rules
make the pocket case rare; "sentries latched with `_lane_len_eff` < ~4 cells" is a **UG2 eyeball/telemetry
watch-item**, not code. Cover is static and never destroyed in M1, so a latched length can never go stale.

**A3 — Latch lifecycle: pause / save / re-setup.** Pause halts the host's `_physics_process` → no `tick()` → the
in-memory latch is untouched; correct by construction. M1 has **no mid-run hazard persistence** (run-state is
disposable per the run/meta boundary), so the latch never needs serialising. Re-`setup()` (`_configure`) resets
`_acquired`/`_ticks` → re-derives on its next second tick **from the same static geometry** → identical lane.
Deterministic across engine runs on the same build: with A1 the geometry is fully registered before the query,
ray results are a pure function of the static 16 px-grid geometry (well-separated distances; strict `>` +
fixed candidate order breaks ties — in the all-clear open-arena case every ray returns exactly `lane_length` and
the pick is deterministically `CANDIDATES[0]`), and the lane is run-state that never feeds `fingerprint()` —
the body's determinism note stands, *as amended by A1*.

**A4 — Final spawn card (overrides §2.1's `per_band_cap = 4`): `credit_cost = 2`, `per_room_cap = 1`,
`per_band_cap = 5`, `cap_group = &"new_hazards"`. U3 re-bases its pin on these.**
The cross-task seam, settled on the def side against the as-built cap semantics
(`spawn_service.gd:244-259` — the minimum binds across per_band → cap_group → per_room; `per_room_cap` keys on
`room_key = str(p.offset_cell)`, i.e. **per chunk**; `encounter_builder.gd:336-340` — `n_plan =
min(demand, budget/cost, per_band_cap)`):
- U3's deterministic deck pin (`U3_band_four.md` §4.3: **`lobber 5 / sentry 5 / charger 4 / bomb 1 = 15`**,
  spending the 34-credit budget exactly to 0: `5·3 + 5·2 + 4·2 + 1·1 = 34`) assumes **sentry cost 2 /
  per_band_cap 5**. The Phase-2 body authored `per_band_cap = 4`, which would shift the outcome to
  `5/4/4/3 = 16` (the freed 2 credits soak into extra bombs) — a legal but different band. The pin's composition
  (ranged-pair-dominant, single mine) is the better band *and* the cleaner cross-doc contract: **ship
  `per_band_cap = 5`.**
- **Satisfiability confirmed** on U0's default arena: `grid 56×36`, `chunk_cells 8` → ≤ `7×5 = 35` chunk pieces,
  ~34 eligible after the entry-piece exclusion (`encounter_builder.gd:313-314`). (U3's "P ≈ 40-60" estimate is
  high; the correct default figure is ~34 — still ≫ 5, so nothing changes.) The def-major even-spread assigns the
  5 sentry placements to 5 **distinct** depth-spread chunks (`round(i/4·(P−1))` over P≈34 yields distinct
  indices), so `per_room_cap = 1` never refuses and never silently shrinks the pin. The `&"new_hazards"` group
  ceiling is 48 (`spawn_service.gd:43`, registered at `main_game.gd:466`) — non-binding at band 4's 15 total.
- **U3's contract-test `EXPECT_SPAWNS` is finalized against the shipped `sentry.tres` carrying these values**
  (the stated T3 precedent); with cost 2 / cap 5 the `5/5/4/1 = 15` pin holds exactly. U3's doc is not edited by
  this resolution; this section is the authoritative def-side answer it re-bases on.

### Per-OQ verdicts

- **OQ-1 — Lane telegraph mode.** **NEEDS DIRECTOR REVIEW (vision/tone).** Endorse the Phase-2 recommendation:
  **`lane_always_visible = true`** (the route-reading puzzle IS the def's skill; reveal-on-windup converts first
  contact into an unreadable death and would poison the UG2 "fair?" read). The knob ships either way — data-cheap
  to flip for an A/B.
- **OQ-2 — Lane acquisition.** **RESOLVED: derive longest-clear-sightline + optional `lane_dir_deg` override,
  8-octant candidate set — as recommended, with amendments A1 (second-tick acquisition) and A2 (latched
  effective length) binding.** 8 octants over a finer sweep is confirmed: axis/diagonal lanes read cleanly
  against the 16 px grid and the fixed order gives a trivial deterministic tie-break; a finer sweep buys
  marginally "longer" lanes at the price of muddier direction reads and more float-tie surface. The override
  field stays (one schema row; future socket-corridor sentries). Binding.
- **OQ-3 — Centre vs body-edge crossing trigger.** **NEEDS DIRECTOR REVIEW (fun).** Endorse **centre-crossing**
  (`fire_on_body_edge = false`). Rider from re-verification: the *trigger* half-width (centre, 14 px) is
  narrower than the *kill* corridor (28 px) by design — the §1.6 windup budget already accounts for clearing the
  full kill corridor (0.14 s of the 0.40 s), so a player who triggers and immediately exits is safe under the
  default; body-edge triggering would make the sentry fire at players who brush the strip edge and never enter
  the bolt's honest path. Centre is both the forgiving *and* the more coherent default.
- **OQ-4 — Throw-disable: permanent vs temporary.** **NEEDS DIRECTOR REVIEW (scope/fun).** Endorse
  **permanent** (`ThrowInteraction` `&"die"`, reused verbatim): it is the uniform verb across all 11 defs, the
  "spend sale value to open a route forever" economy is real (the item is consumed and the approach crosses the
  sentry's own lane), and temporary disable costs new machinery (`resolve_throw_death → true` + a re-arm timer)
  against the one-component budget. The loot-piñata risk is a UG2 telemetry watch (throw-kills-per-sentry), not
  pre-gate machinery.
- **OQ-5 — Band-4 exclusivity.** **NEEDS DIRECTOR REVIEW (scope; ratify).** Endorse **band-4-native for M1.11**
  (`min_band = 4` + bands 1-3 decks omit it — structurally exclusive, the clean four-band A/B). The
  socket-corridor promotion is a one-field edit + deck add later, and `lane_dir_deg` already future-proofs
  hand-placed corridor sentries. One Director verdict should disposition this together with U2a's twin and U3's
  OQ3 (same question, three docs).
- **OQ-6 — Marker soup / crossing lanes.** **RESOLVED: `per_room_cap = 1` is sufficient — confirmed with the
  concrete as-built math** (see A4: per-chunk room keys, ~34 eligible chunks, 5 placements even-spread to
  distinct chunks; `per_band_cap = 5` total). A minimum-lane-separation rule would require an
  `EncounterBuilder`/policy edit — forbidden this wave and unnecessary on the evidence. UG2 watch-item if the
  felt read disagrees. Binding.
- **OQ-7 — Bolt pierce/stop.** **RESOLVED: stop-on-first-axis-hit, no pierce; off-axis cover does not block —
  as recommended.** The centre-ray block test matches the swept-corridor kill model (the danger is the centre
  strip) and keeps the bolt 1-D. Rider: with A2, the bolt's max travel compares against `_lane_len_eff`, so a
  bolt can never out-fly its own latched lane even if geometry queries were to disagree frame-to-frame. Binding.

### NEEDS DIRECTOR REVIEW — summary for the Wave-1 close-out sweep

| # | Question | Recommendation |
|---|---|---|
| OQ-1 | Lane always-visible vs reveal-on-windup | **Always-visible** (knob ships for A/B) |
| OQ-3 | Centre vs body-edge crossing trigger | **Centre** (forgiving + coherent with the kill corridor) |
| OQ-4 | Permanent vs temporary throw-disable | **Permanent** (`&"die"` reuse; piñata risk = UG2 watch) |
| OQ-5 | Band-4-exclusive for M1.11 | **Yes, exclusive** (disposition jointly with U2a/U3's twins) |

Everything else in this section is resolved on technical merit and **binding on the Wave-1 build**: second-tick
lane acquisition gated on `_acquired` (A1), latched `_lane_len_eff` driving strip/crossing/bolt-travel (A2),
re-derive-on-re-setup + no-persistence latch lifecycle (A3), the final spawn card `cost 2 / per_room 1 /
per_band 5 / group &"new_hazards"` with U3 re-basing its pin on it (A4), component-owned bolt over
`thrown_item` reuse (OQ10), 8-octant derive + override (OQ-2), `per_room_cap = 1` (OQ-6), and
stop-on-first-axis-hit (OQ-7).
