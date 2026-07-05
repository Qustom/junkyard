# T2a — New opposition #1: the AMBUSHER (def + one Concealment component) — Expanded Design Spec

**Milestone:** M1.10 (Second-Gen Backend + Cave Band + Low-Sightline Oppositions) · **Workstream:** oppositions · **Wave:** 1 (parallel worktree, file-disjoint from T0/T2b)
**Task id:** T2a · **BlockedBy:** none (rides the S0/S2/S3 stack shipped in M1.9)
**Assignees:** general-purpose (host shell + `Concealment` component + `ambusher.tres` + test) · character-animator (greybox silhouette + floor tell — inline placeholder; PixelLab Director-gated)
**Author:** game-director-designer · **Status:** Phase 2 (per-task design). The `Open Questions` below feed Phase 3 (fresh-eyes resolution + Director ratification).

> **What this doc is.** Per CLAUDE.md's four-phase authoring, this is the T2a per-task design: the M1.10 breakdown's §T2a contract expanded into mechanic detail, the `ambusher.tres` def + `param_schema`, the ONE new component (`Concealment`) pseudocode against the real S2 base contract, the pounce-engine reuse decision, spawn/placement rules, kill + throw semantics, the placeholder tell spec, telemetry, and the acceptance-test plan. It is **design only** — it ships **no game code and no `.tres`**. T2a is one of M1.10's two *cost-ledger* proofs: adding this opposition must cost **`ambusher.tres` (data) + ONE new component + its own Actor-host shell** (the honest per-def host cost the S6a Wave-4 amendment already ratified) and **nothing else** — no edits to the shared component set, `thrown_item.gd`, `EncounterBuilder`, `SpawnService`, or `event_bus.gd`. If it costs more, that overspend IS the TG3 scalability finding and must be recorded in the worklog's Bespoke-code ledger.

---

## 0. Hard constraints (read first)

Straight from the M1.10 breakdown scope guardrails and cross-cutting contracts. The spec must not violate them, and neither may the build:

- **"No new opposition machinery" (breakdown §Scope guardrails).** The Ambusher rides the S0/S2/S3 stack exactly as shipped: `OppositionDef.tres` + `param_schema`, **ONE new `OppositionComponent`** (`Concealment`), spawned by `EncounterBuilder`/`SpawnService`, surfaced by S4's generated menu + the per-def bijection net. The single new engineering artefact is `concealment.gd`. The pounce FSM is the **reused S6a `ChargeLane`** (verbatim — see §2.2); arm is the reused `ProximityTrigger`; the kill is the reused `LethalContact` (`&"external"` seam); the tells are the reused `TelegraphFSM`; throw-death is the reused `ThrowInteraction`. Any edit to a *shared* host/component file is a **flagged deviation** with a designated single writer, not silent sprawl.
- **M1 lethality model only — `kills`-gated `fail_run`, no HP pool.** The pounce is a lethal contact routed through the reused `LethalContact`'s `kills`-gated `GameState.fail_run(&"death")` with emit-always telemetry (`lethal_contact.gd:143-155`). No health bar, no chip damage, no Field/zone hazard, no damage-over-time (breakdown §Scope guardrails; the exploration's "nonfatal stagger" defers to an HP-bearing milestone — breakdown OQ6).
- **All-off is byte-identical.** The Ambusher ships **off by default**: not in `RunConfig.new().oppositions_enabled`, not in `RunConfig.make_default_play_preset()`, not in `band_greybox`'s nor `band_two`'s deck. With the shipped default **no `ambusher.tres` loads and no node spawns**, so the permanent all-off fingerprint **`e943ac9c8bc1`** and the two socket-band fingerprints are untouched. It becomes reachable only via `band_three`'s deck (T3) behind the third hub portal (T4).
- **91-knob model frozen; per-def net extends itself.** No new hand-authored `RunConfig` levers. The Ambusher appears via the count-agnostic generated Oppositions tab; the per-def `params`↔`param_schema` bijection extends to **8 defs** (7 shipped + Ambusher; Burrower makes 9). Coverage assertions never dropped.
- **Deterministic placement; reactive behaviour is run-state.** *Where* Ambushers spawn is a pure function of `seed + config` — the builder walks the graded band RNG-free and the service places them; **no global `RNG`** in `concealment.gd` or the host. The pounce (when it arms, which way it lunges) is legitimately reactive **run-state** (player-driven, like R1's chase / ChargeLane's lane), never written back to the layout stream, so it cannot poison `fingerprint()`.
- **Locked contracts, read-only.** Reads `GameState.current_depth_index` (live, BUG2); routes run-end through the **existing** `GameState.fail_run(&"death")` (no new end-cause); emits **only** the S0-pre-declared generic signals (`opposition_event`, `opposition_killed_player`) via the reused components — it does **not** edit `event_bus.gd`, `game_state.gd`, or `run_config.gd`.
- **File-disjoint in Wave 1.** T2a owns **new files only**: `data/oppositions/ambusher.tres`, `scenes/hazards/ambusher.tscn`, `scenes/hazards/ambusher_hazard.gd`, `scenes/hazards/components/concealment.gd`, `tests/test_ambusher.gd`/`.tscn`, and the `CFG_FIELD_AMBUSHER_*` gloss rows in `config_strings.csv` (data). It does **not** touch `main_game.gd`, the shared `thrown_item.gd`, any menu file (S4's net picks the def up from `param_schema`), or the reused components. T0 owns `systems/bandgen/` + `band_profile.gd`/`band_pipeline.gd`; T2b owns its own component/def/test.
- **Placeholder art tint-only; PixelLab Director-gated.** The silhouette + floor tell ship as **inline greybox** (`Polygon2D` + `Tween`/modulate — the M1 greybox norm, D-RAT-4 precedent). Pixel filter OFF; copy-not-move from `art_workshop/`; any PixelLab run needs an explicit Director OK.

---

## 1. Research — why the Ambusher, and why it is a clean architecture proof

### 1.1 The idea, restated as requirements

From `design/explorations/exploration-20260625/hazards/1-ambusher.md`: a hazard that is **invisible/buried until you get close, then pounces once** — a single fast lunge from concealment — and is otherwise weak or inert. It hides *in the junk*: a pile, a wreck, a dark slot of floor that looks like loot or cover. Its behavioural distinctness: every other pursuer in the roster **announces itself** (R1's visible chaser, the Charger's telegraphed wind-up from a *visible* dormant body). The Ambusher is the only opposition whose threat is **the act of looting itself** — it punishes the player's default greedy walk-up-and-grab and teaches "read the room before you reach for the prize." That is a state axis nothing shipped exercises: **concealment** (a resting state that is invisible *and* un-hittable *and* non-lethal, with only a faint tell to read), which is exactly why the caverns exploration names it as a low-sightline native (bad sightlines make the concealment *fair* rather than a cheap gotcha — breakdown §Source explorations).

The graybox states the exploration gives are: `HIDDEN` (sprite invisible / styled as junk, a faint coloured floor tell) → `ARMED` (player inside `trigger_radius`: brief tell flash) → `POUNCE` (one fast lunge at the player's position, ~0.3 s) → `EXPOSED` (vulnerable, slow/inert for a few seconds, thrown-killable or walk-away) → optionally re-`HIDDEN`. That is **structurally the Charger's three-beat rhythm** (wind-up → committed straight lunge → punishable recovery) with a **concealment wrapper** on the resting state and a **one-shot terminal** instead of an infinite re-arm cycle. This is the load-bearing observation that makes T2a a `def + ONE new component` proof (§1.3).

### 1.2 What is reused vs. the ONE new thing

| Concern | Source (as-built) | Reused / New |
|---|---|---|
| `CharacterBody2D` Actor host, `hazard` layer(16) / `world` mask(2), `"hazard"` group, `setup(cfg, player, spawn_ctx)` snapshot, self-timed run clock, fixed component tick order | S2 Actor-host family shell (`charger_hazard.gd` shape) | **Host shell — honest per-def cost** (S6a Wave-4 amendment: each def ships its own host until FU5's shared parameterized host) |
| Wake when player within `arm_radius` (rising-edge distance test, 0 = inert) | S2 **`ProximityTrigger`** (`proximity_trigger.gd`) | **Reused verbatim** |
| Telegraph → locked-vector lethal lunge → recover FSM + wall-stop + swept tunnel-proof contact + `move_and_slide` | S6a **`ChargeLane`** (`charge_lane.gd`) | **Reused verbatim** (§2.2 — the pounce *is* a charge) |
| `kills`-gated `fail_run(&"death")` + emit-always `&"hit_player"` + BUG6 one-shot latch, driven by an external swept contact boolean | S2 **`LethalContact`** `&"external"` mode (`lethal_contact.gd:102-108`) | **Reused verbatim** (ChargeLane already drives this seam) |
| Tell colour-flip + wind-up flash juice | S2 **`TelegraphFSM`** (`telegraph_fsm.gd`) | **Reused** (new colour/silhouette *values*, not new code) |
| Free-on-throw-kill while EXPOSED (`queue_free`, item consumed) | S2 **`ThrowInteraction`** `&"die"` + existing `thrown_item.gd` group path | **Reused verbatim** (no shared-file edit) |
| **Concealment: near-invisibility in the resting state, a faint floor tell decal, and `"hazard"`-GROUP membership toggled by reveal state (un-hittable while concealed) + the one-shot spent latch** | **`concealment.gd`** | **NEW — the one new artefact** |
| `ambusher.tres` def + `param_schema` | data | **Data (the proof's whole point)** |

> **Why `Concealment` is genuinely new and small.** No shipped component hides a live entity: `TelegraphFSM` recolours a *visible* tell but never toggles visibility or group membership; `ChargeLane`'s `DORMANT` is explicitly "inert, **visible**, learnable" (`charge_lane.gd:31`). The Ambusher's resting state must be **invisible + un-hittable + non-lethal + tell-legible**, and it must **spend** (one-shot) rather than re-arm. `Concealment` owns exactly that delta and nothing else — it does **not** tick a clock, drive movement, run a kill test, or emit telemetry. It is a pure presentation + membership gate the host drives off `ChargeLane`'s `on_state_changed` hook (§2.3). That keeps `ChargeLane` untouched and the FSM battle-tested.

### 1.3 The pounce engine: reuse `ChargeLane`, don't build a second lunge (OQ-1)

The breakdown offers "`ChargeLane` **or** a trimmed lunge move (pounce)." **Recommendation: reuse `ChargeLane` verbatim.** The mapping is exact:

| Ambusher beat | `ChargeLane.State` | What already happens there |
|---|---|---|
| `HIDDEN` (resting) | `DORMANT` | `velocity = 0`; waits for `prox.player_inside()`; **no lethal test runs** → non-lethal for free (`charge_lane.gd:113-119`) |
| `ARMED` (spring + tell) | `TELEGRAPH` | `velocity = 0` for `telegraph_s`; lane locked toward the player at telegraph **start** (fair) (`:120-127`) |
| `POUNCE` (one lunge) | `CHARGE` | committed dash along the locked lane at `charge_speed` until wall-hit or `charge_max_dist`; **swept tunnel-proof lethal test** feeds `LethalContact` (`:128-140, 178-185`) |
| `EXPOSED` (vulnerable) | `RECOVER` | `velocity = 0` for `recover_s`; always throw-killable (`:141-145`) |

The **only** two behaviours `ChargeLane` does *not* natively give the Ambusher are handled without editing it:

1. **Concealment of the resting state** — layered on by the new `Concealment` component, driven off the `on_state_changed` hook (reveal on `TELEGRAPH`, re-hide on cycle end). `ChargeLane` never touches visibility.
2. **One-shot (spent after pounce) vs. re-arm cycle** — achieved by **host orchestration**, not a `ChargeLane` edit: after a completed cycle (`RECOVER → DORMANT` *following a pounce*), the host stops re-ticking `ChargeLane` and asks `Concealment` to `spend()`. `ChargeLane` is left in `DORMANT`, inert, never re-armed. The re-hide variant (breakdown OQ7 dormant param) simply keeps ticking and lets `ChargeLane`'s existing `cooldown_s`/re-aggro path recycle. This is pure host logic — the host already owns "whether to tick a component this frame" under the S2 contract (`opposition_component.gd:50-52`, "components never self-tick"). **Zero edit to `charge_lane.gd`.**

A *trimmed bespoke lunge* inside `Concealment` was considered and rejected: it would re-derive the wind-up/lock/swept-contact/wall-stop logic `ChargeLane` already proves (`test_charger` gates all of it), inflating the ledger and re-testing solved problems for no design gain. The only argument for it is avoiding the two host-orchestration seams above — but those are cheaper and lower-risk than a second FSM. *(Technical — Phase-3 resolver confirms; see OQ-1.)*

### 1.4 How it fits THE FAR YARD (fiction + loop)

- **Loot is its whole reason to exist.** The loop is "walk to junk, press F to grab" (`JunkPickup`, `interactable_id=&"junk"`). An Ambusher seeded among the cave's scattered junk makes blind looting cost you — the enemy that gives the loot verb teeth. Bad cave sightlines (T0's `CaveBackend`) make the concealment read as *fair environmental caution* rather than a screen-wide cheap shot.
- **Throw is the counter.** Spot the tell (or the reveal on `ARMED`) and throw an item to pop it — one item spent to disarm a trap, or eat the pounce. Risk/reward toss, using the player's existing kit with **zero new player verbs** (`ThrowInteraction`).
- **Extract pressure.** Ambushers reward slow, careful dives; the dive-clock rewards fast ones. "Do I have time to be careful?" is the push/cash-out bet applied to looting.
- **Fiction (band 3 = cave / deeper-alien).** T3 ratifies the band-3 identity; the Ambusher is a **thing that learned to look like the junk it lives in** — a scrap-mimic / burrow-lurker that springs. Two placeholder pitches for T3/Director: *"The Lurker"* (a scrap-mound that unfolds into a striking limb) or *"The Mimic-heap"* (junk that is actually a coiled thing). Tone is a T3/Director call; the mechanical `id` stays `&"ambusher"` regardless, so telemetry/tests are name-stable (the Wrecker precedent).

### 1.5 Readability budget (grounded in the real player numbers)

The hazard lives or dies on the player being able to **read the tell and step out of the lunge lane in time** — and the concealment makes this *tighter* than the Charger because you are, by design, close to it when it arms. Anchors (verified in-repo, S6a Phase-3 audit):

- **Player top speed `200` px/s** (`data/player/player_movement.tres`), reached in ~0.1 s.
- **Cell size `16` px** (`main_game.gd:42`). **Player radius `14` px** (`player.tscn` `CircleShape2D`) — `ChargeLane.PLAYER_R = 14` (`charge_lane.gd:51`).
- **Lethal-contact floor** `player_r + hazard_r` — the swept kill corridor half-width is `lane_width/2 + PLAYER_R` (`charge_lane.gd:184`), so "it hit me" reads honestly.

Derived defaults (every value is a **sweep start**, not a balance claim):

- **`arm_radius` 90 px (~5.6 cells).** Close-range: you have to *approach the loot* to arm it (the whole point), but far enough that the pounce isn't point-blank-unavoidable. Charger's 400 px aggro is a room-spanning bruiser; the Ambusher is an at-the-prize trap.
- **`tell_lead_s` 0.45 s.** Reaction (~0.22 s) + lateral clear of a ~28 px corridor at 200 px/s (~0.14 s) + a thin margin. Shorter than the Charger's 0.5 s only marginally — because you're closer, the lead must stay generous or the pounce is a cheap kill. **This is the fairness line (OQ-4, Director).**
- **`lunge_speed` 600 px/s (~3× player).** Fast enough that a footrace never works (side-step, don't outrun); swept test keeps even a maxed value tunnel-safe (`charge_lane.gd:178-185`).
- **`lunge_dist` 140 px (~9 cells).** Reaches past where the player stood at arm-time, then auto-`EXPOSED`. Wall-hit ends it early.
- **`exposed_window_s` 1.5 s.** The one-shot payoff window — longer than the Charger's cycling 1.2 s recover because a spent Ambusher is a *free* throw target and the punish should feel earned. Sweep hard at TG2.

---

## 2. Design spec + pseudocode

### 2.1 `ambusher.tres` — the `OppositionDef` (data — the proof's payload)

Authored against the S0/S2 `OppositionDef extends Resource` schema (`data/oppositions/opposition_def.gd`). All tuning lives in `params` with a mirroring `param_schema` (read by S4's generated menu + the params↔schema bijection lint). The host **maps** the Ambusher-semantic param keys to `ChargeLane`'s expected keys in `_resolve_params` — the same rename pattern the Charger uses (`charger_hazard.gd:117`, `proximity_radius = aggro_range`). Semantic keys keep the menu legible (OQ-8). Illustrative:

```
# data/oppositions/ambusher.tres  (illustrative — authored in the inspector)
id             = &"ambusher"                # stable; events / telemetry / throw-kind / deck ref
display_name   = "Lurker"                   # tone/naming — T3/Director ratifies; id stays &"ambusher"
archetype      = "actor"
host_scene     = ExtResource("res://scenes/hazards/ambusher.tscn")

# --- Spawn card (read by the EncounterBuilder) ---
credit_cost    = 2        # a strong loot-denial threat; between a basic pursuer (1) and the Charger (2)
spawn_weight   = 1.0
min_band       = 3        # HARD gate to band 3 (the Charger's min_band=2 precedent);
                          #   doubly reinforced by band_greybox/band_two decks omitting it

# --- Hard caps (read by the SpawnService) ---
cap_group      = &"new_hazards"
per_room_cap   = 2        # more permissive than the Charger's 1 — small, static, per-loot traps
per_band_cap   = 6

# --- Lethality (reused LethalContact, L5 semantics) ---
lethality      = "lethal"
kills          = true     # standing convention: kills also lives in params (deck-sweepable), typed field kept in agreement

params = {
    # --- Ambusher-semantic knobs (host maps → ChargeLane keys) ---
    "arm_radius": 90.0,            # → aggro_range / proximity_radius
    "tell_lead_s": 0.45,          # → telegraph_s (the fairness line — OQ-4)
    "lunge_speed": 600.0,         # → charge_speed
    "lunge_dist": 140.0,          # → charge_max_dist
    "exposed_window_s": 1.5,      # → recover_s (the throw-punish window)
    "lunge_width": 28.0,          # → lane_width (swept corridor + visual)
    # --- Concealment knobs (host maps → Concealment) ---
    "concealed_alpha": 0.0,       # body modulate.a while HIDDEN (0 = invisible)
    "tell_alpha": 0.28,           # faint floor-tell decal alpha while HIDDEN (subtlety — OQ-4)
    "re_hide_s": 0.0,             # 0 = ONE-SHOT (spent after pounce); >0 = re-hide + re-arm after N s (ships dormant, OQ7)
    # --- Locked-shape flags (mapped straight through) ---
    "kills": true,
    # --- Spawn-card count knobs (builder-read; never reach the entity) ---
    "base_count": 1,
    "count_per_depth": 0.0,
}
param_schema = [ ... ]    # one row per params key (bijection lint-checked)
```

**`param_schema` table** (defaults tuned against player 200 px/s + 16 px cells; sweep starts, not balance claims):

| key | type | default | min | max | gloss / behaviour it drives |
|---|---|---|---|---|---|
| `arm_radius` | float (px) | **90** | 32 | 400 | Distance at which a `HIDDEN` Ambusher arms (reveals + telegraphs). 0 = permanently inert (the `ProximityTrigger` 0-gate). |
| `tell_lead_s` | float (s) | **0.45** | 0.2 | 1.2 | `ARMED` wind-up before the pounce — the readable "it's about to spring" beat. Floor 0.2 borders unfair at close range (§1.5); sweep down carefully. **Fairness line (OQ-4).** |
| `lunge_speed` | float (px/s) | **600** | 200 | 900 | Locked-vector pounce speed. ~3× player → lateral dodge is the only answer. Swept-test keeps any value tunnel-safe. |
| `lunge_dist` | float (px) | **140** | 48 | 400 | How far the pounce travels before auto-`EXPOSED` (overshoot past the player). Wall-hit ends it early. |
| `exposed_window_s` | float (s) | **1.5** | 0.4 | 3.0 | `EXPOSED` vulnerable window after the pounce — the throw-punish opportunity. Too short = unkillable, too long = trivial. Sweep hardest. |
| `lunge_width` | float (px) | **28** | 16 | 64 | Lethal corridor half-width during `POUNCE` (swept test) AND the visual lunge lane. Floored at ~`player_r + ambusher_r`. |
| `concealed_alpha` | float | **0.0** | 0.0 | 0.5 | Body sprite `modulate.a` while `HIDDEN`. 0 = fully invisible (the faint floor tell carries the read); a small value = a barely-visible lump. **Subtlety knob (OQ-4).** |
| `tell_alpha` | float | **0.28** | 0.0 | 1.0 | Faint floor-tell decal alpha while `HIDDEN`. The "read the room" affordance. Too low = cheap/unfair; too high = trivial. **Subtlety knob (OQ-4).** |
| `re_hide_s` | float (s) | **0.0** | 0.0 | 10.0 | `0.0` = **one-shot** (spent after the pounce, never re-arms). `>0` = after `EXPOSED`, re-hide and re-arm after this delay (area-denial variant; **ships dormant** per breakdown OQ7). |
| `kills` | bool | **true** | — | — | The L5 `*_kills` toggle. `false` = the pounce emits contact but never `fail_run` (per-def gate; deck-sweepable). |

All-off: `ambusher.tres` loads only when `&"ambusher" ∈ oppositions_enabled` **and** a live deck lists it — the shipped default has neither, so nothing loads (byte-identical baseline). The **params↔schema bijection** is asserted by S4's per-def coverage net + the Python `.tres` linter. The two spawn-card keys (`base_count`, `count_per_depth`) also carry schema rows (as `charger.tres` does), for **8 total defs**.

> **Host→ChargeLane fixed flags (not authored knobs — set in `_resolve_params`).** `lock_at_telegraph_start = true` (the pounce lane locks at arm-time — fair, dodge-the-shown-lane), `throwable_while_charging = true` (so `ChargeLane` **never touches the `"hazard"` group**, leaving group membership entirely to `Concealment` — see §2.4/OQ-10), `wall_crash_recover_mult = 1.0` (no bonus stun — an Ambusher pounces a short distance; wall-baiting isn't its game), `cooldown_s = re_hide_s` (folds the re-hide delay into `ChargeLane`'s existing post-cycle re-aggro guard). These are intentionally *not* in `param_schema` — they are structural to "this def is an Ambusher, not a Charger," matching how the Charger fixes `lethal_mode`/`emit_family` internally (`charger_hazard.gd:118-122`).

### 2.2 The pounce engine — reused `ChargeLane` (NO new FSM)

The pounce is `ChargeLane`, wired by the host exactly as `charger_hazard.gd` wires it (`charger_hazard.gd:81-89`): `lane.prox = _prox`, `lane.lethal = _lethal`, `lane.on_state_changed = _on_pounce_state`, and `lane.tick(delta)` called from the host's `_physics_process` (S2 fixed-order tick). The host maps Ambusher params → `ChargeLane` keys and forwards the standard `bind(host, player, p, ctx)` snapshot. **No `charge_lane.gd` change.** The three-beat, the locked-lane fairness, the swept tunnel-proof kill, the wall-stop, and the BUG6-latched `kills` gate are all inherited and already gated by `test_charger`.

### 2.3 The `Concealment` component — the ONE new artefact

`Concealment` is a small `class_name`-typed `OppositionComponent` (rides the S2 base contract, `opposition_component.gd`: host-owned child `Node`, no `_physics_process` of its own — the host calls it). It owns **only**: (a) the `HIDDEN` presentation (body near-invisible + faint floor-tell decal), (b) `"hazard"`-group membership gating (un-hittable while concealed), (c) the reveal/hide/spend transitions the host drives off `ChargeLane.on_state_changed`. It **never** ticks a clock, moves the host, runs a kill test, or emits telemetry. Illustrative, against the real base contract + the `TelegraphFSM.tell` assignment idiom (`telegraph_fsm.gd:21`, `charger_hazard.gd:86`):

```gdscript
class_name Concealment
extends OppositionComponent
## Concealment (S2-family, M1.10) — the ONE new component of the Ambusher proof:
## the HIDDEN-state presentation + hittability gate that no shipped component does.
## Owns near-invisibility of the body, a faint floor-tell decal, and "hazard"-GROUP
## membership toggled by reveal state (un-hittable while concealed), plus the
## one-shot SPENT terminal. Everything else is reused verbatim: pounce = ChargeLane,
## arm = ProximityTrigger, kill = LethalContact(&"external"), tells = TelegraphFSM,
## throw-death = ThrowInteraction.
##
## NOT a ticker: no _physics_process, no clock, no movement, no kill test, no
## EventBus. Pure presentation + group membership, driven by the host's reveal()/
## hide()/spend() calls off ChargeLane.on_state_changed. Headless/paused-safe — the
## visible flag + group membership carry the state; the fade is juice.
## RNG-FREE (no global RNG anywhere).

## Host-assigned nodes (the TelegraphFSM.tell idiom): the body silhouette + the
## faint floor decal. Colours/shapes stay host consts (S2 rule).
var body: Node2D = null          # the Polygon2D silhouette (host's $Body)
var floor_tell: Node2D = null    # the faint floor decal (host's $FloorTell)

var _concealed_alpha := 0.0
var _tell_alpha := 0.28

func _configure(p: Dictionary, _ctx: Dictionary) -> void:
    _concealed_alpha = clampf(float(p.get("concealed_alpha", 0.0)), 0.0, 1.0)
    _tell_alpha = clampf(float(p.get("tell_alpha", 0.28)), 0.0, 1.0)

## HIDDEN: body near-invisible, faint floor tell shown, OUT of the "hazard" group
## (thrown items pass through → un-hittable), non-lethal for free (no ChargeLane
## lethal test runs in DORMANT). The host seats this at setup() and on a re-hide.
func hide_conceal() -> void:
    _set_body_alpha(_concealed_alpha)
    _set_tell_alpha(_tell_alpha)
    _set_hittable(false)

## ARMED: the spring — reveal the body, drop the floor tell, JOIN the "hazard" group
## (now throw-killable). The host calls this on the ChargeLane TELEGRAPH transition.
func reveal() -> void:
    _set_body_alpha(1.0)
    _set_tell_alpha(0.0)
    _set_hittable(true)

## SPENT (one-shot terminal): pounce done, exposed window elapsed, re_hide_s <= 0.
## Leave a visible inert husk that is no longer a threat — OUT of the "hazard" group
## (can't be re-thrown-killed for value), body dimmed. The host stops ticking
## ChargeLane after this, so it never re-arms.
func spend() -> void:
    _set_body_alpha(0.5)     # a dimmed spent husk (readable "it's done")
    _set_tell_alpha(0.0)
    _set_hittable(false)

func is_hittable() -> bool:
    return host.is_in_group(&"hazard")

func _set_body_alpha(a: float) -> void:
    if body != null: body.modulate.a = a

func _set_tell_alpha(a: float) -> void:
    if floor_tell != null: floor_tell.modulate.a = a

## Pure stock group membership — the ChargeLane dash-invulnerability idiom
## (charge_lane.gd:192-199): out of "hazard", ThrownItem resolves _miss() (re-drop,
## item kept); collision_layer stays hazard(16) so body_entered still fires. Zero
## thrown_item.gd edit.
func _set_hittable(on: bool) -> void:
    if host == null: return
    if on and not host.is_in_group(&"hazard"):
        host.add_to_group(&"hazard")
    elif not on and host.is_in_group(&"hazard"):
        host.remove_from_group(&"hazard")
```

**Host wiring + orchestration** (`ambusher_hazard.gd`, mirroring `charger_hazard.gd`; the host is the honest per-def cost, S6a Wave-4 amendment):

```gdscript
class_name AmbusherHazard
extends CharacterBody2D
## AmbusherHazard — the loot-punisher (T2a, M1.10). S2 Actor-host skeleton verbatim;
## the behaviour is the reused component set + the ONE new Concealment:
##   ProximityTrigger(arm) + TelegraphFSM(tell) + LethalContact(&"external") +
##   ThrowInteraction(&"die") + ChargeLane(pounce, REUSED) + Concealment(NEW).
## Collision: layer hazard(16), mask world(2). id &"ambusher". Ships OFF-default.

const DEFAULTS := { "arm_radius": 90.0, "tell_lead_s": 0.45, "lunge_speed": 600.0,
    "lunge_dist": 140.0, "exposed_window_s": 1.5, "lunge_width": 28.0,
    "concealed_alpha": 0.0, "tell_alpha": 0.28, "re_hide_s": 0.0, "kills": true }

var _prox: ProximityTrigger; var _fsm: TelegraphFSM; var _lethal: LethalContact
var _throw: ThrowInteraction; var _lane: ChargeLane; var _conceal: Concealment
var _has_pounced := false        # host-owned one-shot latch (run-state)
var _spent := false
var _re_hide_s := 0.0
@onready var _body: Polygon2D = $Body
@onready var _tell: Polygon2D = $Tell            # the reveal/telegraph tell (TelegraphFSM)
@onready var _floor_tell: Polygon2D = $FloorTell # the faint HIDDEN decal (Concealment)

func _ready() -> void:
    _prox = OppositionComponent.acquire(self, ProximityTrigger)
    _fsm = OppositionComponent.acquire(self, TelegraphFSM)
    _lethal = OppositionComponent.acquire(self, LethalContact)
    _throw = OppositionComponent.acquire(self, ThrowInteraction)
    _lane = OppositionComponent.acquire(self, ChargeLane)
    _conceal = OppositionComponent.acquire(self, Concealment)
    _fsm.tell = _tell
    _conceal.body = _body
    _conceal.floor_tell = _floor_tell
    _lane.prox = _prox
    _lane.lethal = _lethal
    _lane.on_state_changed = _on_pounce_state

func setup(cfg, player, spawn_ctx := {}) -> void:
    var p := _resolve_params(spawn_ctx)          # Ambusher keys → ChargeLane keys (+ fixed flags)
    _re_hide_s = float(p["cooldown_s"])          # == re_hide_s
    _has_pounced = false; _spent = false
    _prox.bind(self, player, p, spawn_ctx)
    _fsm.bind(self, player, p, spawn_ctx)
    _lethal.bind(self, player, p, spawn_ctx)
    _throw.bind(self, player, p, spawn_ctx)
    _lane.bind(self, player, p, spawn_ctx)       # seats DORMANT (no host-hook fire)
    _conceal.bind(self, player, p, spawn_ctx)
    _conceal.hide_conceal()                      # seat HIDDEN (invisible + out of group) LAST

func _physics_process(delta) -> void:
    if player-guard fails: return
    _spawn_time += delta
    if not _spent:
        _lane.tick(delta)                        # the reused pounce FSM
    # Concealment does not tick.

## ChargeLane transition hook — reveal / re-hide / spend + S0-locked telemetry.
func _on_pounce_state(state: int, _wall_crash: bool) -> void:
    match state:
        ChargeLane.State.TELEGRAPH:              # ARMED: spring up
            _conceal.reveal()
            _fsm.set_tell_color(COLOR_ARMED); _fsm.flash_scale(1.4, 0.06, 0.14)
            EventBus.opposition_event.emit(&"ambusher", &"telegraph", _depth(), run_clock_ms())
        ChargeLane.State.CHARGE:                 # POUNCE
            _has_pounced = true
            _fsm.set_tell_color(COLOR_POUNCE)
            EventBus.opposition_event.emit(&"ambusher", &"state", _depth(), run_clock_ms())
        ChargeLane.State.RECOVER:                # EXPOSED
            _fsm.set_tell_color(COLOR_EXPOSED)
            EventBus.opposition_event.emit(&"ambusher", &"state", _depth(), run_clock_ms())
        ChargeLane.State.DORMANT:                # cycle end
            if _has_pounced and _re_hide_s <= 0.0:
                _spent = true                    # ONE-SHOT: stop ticking → never re-arms
                _conceal.spend()
            else:                                # re-hide variant (dormant param) OR initial seat
                _conceal.hide_conceal()
            EventBus.opposition_event.emit(&"ambusher", &"state", _depth(), run_clock_ms())
```

Notes for the programmer:
- **`ChargeLane` untouched.** The one-shot is `_spent` gating the host's `_lane.tick()` call, exactly the host's prerogative under the base contract. If `re_hide_s > 0`, `_spent` never latches, and `ChargeLane`'s existing `cooldown_s` (== `re_hide_s`) re-aggro guard recycles it (`charge_lane.gd:115-117`) — the area-denial variant, shipping dormant.
- **`DORMANT` fires the hook both at cycle-end and never at seat.** `ChargeLane.bind()` seats `DORMANT` *without* firing `on_state_changed` (`charge_lane.gd:96-104` comment), so the host seats HIDDEN itself in `setup()`. `_has_pounced` disambiguates the post-cycle `DORMANT` from any spurious early transition.
- **Telemetry vocabulary is S0's LOCKED set** (`&"spawned"` (service) / `&"telegraph"` / `&"state"` / `&"hit_player"` (LethalContact) / `&"killed_by_throw"` (ThrowInteraction)) + the gated `opposition_killed_player`. No new token, no `event_bus.gd` edit — identical to the Charger's discipline.

### 2.4 Kill + throw semantics (M1 lethality model; reused components)

- **Only `POUNCE` (CHARGE) is lethal.** The swept segment test feeds `LethalContact` `&"external"` (`charge_lane.gd:178-185` → `lethal_contact.gd:102`): emit-always `&"hit_player"`, `kills`-gated `fail_run(&"death")`, BUG6 one-shot latch. `HIDDEN`/`ARMED`/`EXPOSED`/`SPENT` do **not** run a lethal test → **non-lethal on touch for free** (no `ChargeLane` lethal test runs outside `CHARGE`). This *is* the DoD's "hidden = non-lethal."
- **`kills = false`** → the pounce emits `&"hit_player"` but never `fail_run` — proves the per-def toggle (deck-sweepable). No new end-cause.
- **Un-hittable while `HIDDEN` (DoD)** = `Concealment` holding the host **out of the `"hazard"` group** — a thrown item resolves `_miss()` and re-drops (kept), so a concealed Ambusher can't be cheese-killed sight-unseen (`thrown_item.gd` untouched; verified group-path, `charge_lane.gd:192-199` precedent). On `ARMED` reveal, `Concealment.reveal()` joins the group → throw-killable (the "spot the spring, throw to pre-pop" counter, OQ-7). `EXPOSED` stays in-group → the primary throw-punish window (DoD). `SPENT` leaves the group → an inert husk (can't be farmed).
- **Group ownership is `Concealment`'s alone.** By fixing `throwable_while_charging = true`, `ChargeLane` never toggles the group (`charge_lane.gd:126, 192-199` no-op path), so there is no contention between `ChargeLane` and `Concealment` over `"hazard"` membership (OQ-10). Consequence: the fast-moving `POUNCE` is technically throw-killable but is an emergent hard target (fair; matches the Charger default).

### 2.5 Spawn / placement rules (builder + service — no T2a placement code)

Placed by the **default `EncounterBuilder`** from `band_three`'s deck through the **`SpawnService`**, exactly like every opposition — T2a adds **no** placement code:

- **Eligibility:** in the deck iff `band.band_depth >= ambusher.min_band` (=3). `band_three` (`band_depth=3`) lists it; `band_greybox`/`band_two` do not → band-3-native for M1.10 (breakdown OQ9 A/B; OQ-9 here).
- **Budget:** `credit_cost = 2` debited from the builder's `I`-scaled band budget (`instability(3) = 1.30`).
- **Caps (service-enforced):** `per_room_cap = 2`, `per_band_cap = 6`; the minimum binds; global registry ceiling last-resort.
- **Determinism:** placement cell is the builder's stable RNG-free stride; spawned `HIDDEN`. Same seed + config → same Ambusher cells. Reactive behaviour (arm/lunge) is run-state, never fed to `fingerprint()`.
- **Near-loot bias (deferred — OQ-6).** The exploration wants Ambushers *preferentially near high-value junk*. There is **no params-only coupling** between `JunkPlacer` and `EncounterBuilder` today, so a true near-loot bias needs a builder/policy edit — **out of scope** for the "no EncounterBuilder edit" guardrail. **Recommendation: ship with standard placement.** The cave's bad sightlines + scattered junk already deliver "blind approach to a prize" tension; explicit loot-coupling is a flagged follow-up if TG2 asks for it.

### 2.6 Telemetry

Emits **only** S0-pre-declared generic signals via reused components — no ambusher-specific signal, no `event_bus.gd` edit:

| Signal | When | Emitter |
|---|---|---|
| `opposition_event(&"ambusher", &"spawned", …)` | on spawn | **SpawnService** (central) |
| `opposition_event(&"ambusher", &"telegraph", …)` | ARMED (spring/wind-up begins) | host `_on_pounce_state(TELEGRAPH)` |
| `opposition_event(&"ambusher", &"state", …)` | POUNCE / EXPOSED / SPENT/re-hide transitions | host `_on_pounce_state` |
| `opposition_event(&"ambusher", &"hit_player", …)` | lethal pounce contact (emit-always, even if `kills=false`) | reused **LethalContact** (BUG6-latched) |
| `opposition_event(&"ambusher", &"killed_by_throw", …)` | throw-kill (def-id-stable) | reused **ThrowInteraction** |
| `opposition_killed_player(&"ambusher", …)` | gated — only when `kills` fires `fail_run` | reused **LethalContact** |
| `run_ended(reason=&"death", …)` | fatal pounce contact | `GameState.fail_run(&"death")` |

`&"telegraph"` (spring) + `&"hit_player"` (contact) + its absence (dodge) let TG2 measure "did players read the tell" (deaths-per-first-encounter vs Wrecker/Splitter baselines — breakdown TG2). With the Ambusher off, none of these rows appear (no node exists).

### 2.7 Placeholder asset spec (character-animator — inline greybox; PixelLab Director-gated)

Per the M1 greybox norm (D-RAT-4), stubbed inline (`Polygon2D` + `modulate`/`Tween`) — no sprite sheets, no `AnimationTree`, no paid generation without an explicit Director OK. The Ambusher must read **apart from** R1 (grey-blue/red diamond), pingpong (amber box), spike (steel-cyan star), bomb (orange-pulse circle), Charger (rust-steel directional wedge), and Splitter — by **silhouette**, by **its concealment signature** (near-invisible at rest with only a floor tell), and by colour.

- **Root node name `Ambusher`** (throw-kill telemetry self-logs a stable `kind` via `get_def_id()`).
- **Two `Polygon2D` children the host assigns to components:**
  - **`$FloorTell`** (Concealment's `floor_tell`) — a **faint floor decal** visible only while `HIDDEN`: a small dark irregular blotch / seam-in-the-junk, `modulate.a = tell_alpha` (~0.28). This is the *only* thing the player can read before arming — the "read the room" affordance. Its subtlety is the fairness knob (OQ-4).
  - **`$Body`** (Concealment's `body`) — the **silhouette that springs up**: a **coiled/hunched blob** (NOT directional — unlike the Charger wedge; the Ambusher's threat direction is only committed at the pounce, and a compact ambush shape reads "trap," not "chaser"). ~24–28 px across, body radius ≈ 14–16 px (comparable to the player, so it reads "a thing that was hiding," not a bruiser). `modulate.a = concealed_alpha` (0 = invisible) while `HIDDEN`.
  - **`$Tell`** (TelegraphFSM's `tell`) — a small overlay wedge/spike on `$Body` that flashes on the reveal + colours per state (the "spring" tell).
- **Per-state tell (colours are a set-level Director/character-animator call, OQ-4/§tone — recommended starting values):**

  | State | `$Body`.a | Tell colour (recommended) | Motion / juice |
  |---|---|---|---|
  | `HIDDEN` | `concealed_alpha` (0) | — (only `$FloorTell` faintly shown) | still; `$FloorTell` a faint dark seam in the floor |
  | `ARMED` | 1.0 (springs visible) | **hot amber→red** `Color(0.95,0.5,0.15)` | a sharp **reveal pop** (`flash_scale(1.4, 0.06, 0.14)`) + brightening over `tell_lead_s` |
  | `POUNCE` | 1.0 | full **alarm red** `Color(0.95,0.15,0.15)` (shared meaning: "lethal contact now") | short motion-streak along the lunge |
  | `EXPOSED` | 1.0 | desaturated **stunned grey-blue** `Color(0.5,0.55,0.6)` | slumped/flashing "hit me" — the punish tell |
  | `SPENT` | 0.5 (dimmed husk) | dim grey | inert; readable "it's done" |

- **Frame budget if PixelLab is later approved (deferred, Director-gated):** hidden decal (1) · reveal/armed (2–3) · pounce (1–2 streak) · exposed (2) · spent (1). Greybox needs only the modulate flips + one reveal `flash_scale`.

`Concealment` drives visibility/alpha + group membership; `TelegraphFSM` drives the tell colour/flash; `ChargeLane` drives movement. No component touches another's node.

---

## 3. Definition of done (concrete — the acceptance bar)

Restated from the breakdown's §T2a DoD, with the test names T2a adds (`tests/test_ambusher.gd` + `.tscn`, run **as a scene** per the headless-test convention — `godot --headless --path Game res://tests/test_ambusher.tscn`). The shape mirrors `test_charger.gd`.

1. **All-off fp unmoved.** With the shipped default (`&"ambusher" ∉ oppositions_enabled`, not in the default play preset, not in `band_greybox`/`band_two` decks), **no `ambusher.tres` loads, no node spawns**, and the all-off fingerprint **`e943ac9c8bc1`** is byte-identical.
2. **`params`↔`param_schema` bijection (8 defs).** `ambusher.tres` passes the per-def coverage assertion (S4) + the Python `.tres` linter — every `params` key has exactly one `param_schema` entry and vice-versa, all within declared min/max; entity params mirror `AmbusherHazard.DEFAULTS` exactly (no code/data drift).
3. **Menu section auto-appears.** With `&"ambusher"` loaded, S4's generated debug-menu builds an Ambusher collapsible section from `param_schema` headlessly (no hand-authored rows).
4. **`test_ambusher` (headless scene) asserts:**
   - **(a) HIDDEN = non-lethal + un-hittable:** a `HIDDEN` Ambusher with the player standing on it (inside body radius but the concealment hasn't armed — use `arm_radius = 0` for a permanently-inert probe, or place the player just outside `arm_radius`) never ends the run; `is_hittable()` is `false`; a thrown item at it **misses/re-drops** (`throw_missed` + `junk_dropped`, Ambusher survives, no `throw_killed` row); body `modulate.a == concealed_alpha`, `$FloorTell.a > 0`.
   - **(b) Arm radius:** player entering `arm_radius` transitions `HIDDEN → ARMED` (reveal: `$Body.a == 1.0`, in `"hazard"` group); `arm_radius = 0` → permanently inert (the `ProximityTrigger` 0-gate — never arms).
   - **(c) Tell precedes pounce by the authored lead:** `ARMED` (TELEGRAPH) holds ~`tell_lead_s` before `POUNCE` (CHARGE); **exactly one** `&"telegraph"` row.
   - **(d) Lane lock:** with the pounce locked at arm-time, a player who steps perpendicular *after* arming is **not** on the lunge lane and is **not** hit (the dodge works); a player who stays on the lane **is** hit.
   - **(e) Pounce kill gated by `kills`:** `kills=true`, player on the lunge line → `fail_run(&"death")` (`GameState.run_active` false, cause `&"death"`) + `opposition_killed_player(&"ambusher")` **exactly once** (BUG6) + `&"hit_player"`; `kills=false`, same geometry → `&"hit_player"` fires but run stays active, no `opposition_killed_player`.
   - **(f) EXPOSED window throw-killable:** during `EXPOSED` (post-pounce), a thrown item kills the Ambusher (`queue_free`) and logs `throw_killed_hazard`/`&"killed_by_throw"` for `&"ambusher"`.
   - **(g) One-shot:** after a full pounce→exposed cycle with `re_hide_s = 0`, the Ambusher is `SPENT` — re-entering `arm_radius` does **not** re-arm (no second `&"telegraph"` row); `is_hittable()` is `false`. With `re_hide_s > 0`, after `EXPOSED` it re-hides and CAN re-arm on a later entry (assert the param path exists; **default ships one-shot**).
   - **(h) Deterministic placement:** the same synthetic band + deck twice through the REAL `EncounterBuilder` + `SpawnService` yields identical Ambusher spawn cells; `per_band_cap` binds; `min_band = 3` refuses a band-depth-2 profile entirely.
   - **(i) No global RNG:** `concealment.gd` + `ambusher_hazard.gd` sources contain no `RNG.` reference (determinism audit; `charge_lane.gd` already audited by `test_charger`).
   - **(j) Tells render:** `$Body`, `$Tell`, and `$FloorTell` polygons triangulate to >0 triangles (the invisible-blade guard).
5. **Process:** a T2a worklog names the real commit SHA(s) for the programmer + character-animator contributions; `godot --headless --path Game --import` compiles the new scene/script/tres; the smoke test is green; the worklog's **Bespoke-code ledger** records the exact non-data, non-test line counts (see §4) and the **Design deviations** section records any departure (or "none") for the Wave-1 close-out sweep.

---

## 4. Bespoke-code cost-ledger prediction (the TG3 scalability evidence)

The breakdown makes the cost ledger version-defining. **Predicted** T2a spend beyond the promised `def + ONE component`:

| Artefact | Kind | Predicted | In the "def + one component" budget? |
|---|---|---|---|
| `data/oppositions/ambusher.tres` | data | ~1 resource | Yes — the point |
| `scenes/hazards/components/concealment.gd` | **new component code** | **~50–70 lines** | **Yes — the ONE new component** |
| `scenes/hazards/ambusher_hazard.gd` | host shell code | ~120–150 lines | **Expected honest per-def cost** (S6a Wave-4 amendment: each def ships its own Actor host until FU5's shared host; NOT a new *behaviour* script) |
| `scenes/hazards/ambusher.tscn` | scene | 1 | Expected (host + 3 polygons + collision) |
| `tests/test_ambusher.gd` + `.tscn` | test | ~500 lines | Excluded from the ledger (test code) |
| `config_strings.csv` `CFG_FIELD_AMBUSHER_*` rows | data | ~10 rows | Yes — data |

**Predicted edits to shared/reused files: ZERO.** `charge_lane.gd`, `proximity_trigger.gd`, `telegraph_fsm.gd`, `lethal_contact.gd`, `throw_interaction.gd`, `thrown_item.gd`, `encounter_builder.gd`, `spawn_service.gd`, `event_bus.gd` all untouched. **If any is touched, that is the ledger's headline overspend and a flagged deviation** — the two risk points to watch:
- **`ChargeLane` one-shot.** If host-orchestrated `_spent` gating proves insufficient (e.g. `ChargeLane` re-arms before the host can gate it), a one-line `one_shot`/`spent` guard in `ChargeLane` would be needed — a shared-component edit. *Predicted: not needed* (the host owns whether to tick; §2.3).
- **Group-ownership contention.** If fixing `throwable_while_charging = true` does not fully cede the `"hazard"` group to `Concealment`, a seam would be needed. *Predicted: not needed* (`ChargeLane` no-ops the group toggle when `throwable_while_charging = true`, `charge_lane.gd:126,192-199`).

Net predicted honest cost of adding this opposition: **one ~60-line component + one host shell + data + a test** — the S6a shape, plus the new concealment axis, with no engine rework. That is the scalability claim T2a is here to prove.

---

## Open Questions

> Each stated with trade-offs for Phase-3 fresh-eyes resolution. Genuine **fun/fairness/tone/scope calls are flagged `**NEEDS DIRECTOR REVIEW**`** with a recommendation — the resolver does not self-decide those.

### OQ-1 — Pounce engine: reuse `ChargeLane` vs. a trimmed bespoke lunge inside `Concealment`?
§1.3 recommends **reusing `ChargeLane` verbatim** (the pounce *is* a telegraph→locked-lunge→recover), with concealment + one-shot layered on by the host + `Concealment`. The alternative — a trimmed lunge inside `Concealment` — avoids the two host-orchestration seams (reveal-off-`on_state_changed`, `_spent` gating) but re-derives the wind-up/lane-lock/swept-kill/wall-stop logic `ChargeLane` already proves and `test_charger` already gates, inflating the ledger. **Recommendation: reuse `ChargeLane`** — smaller net code, battle-tested FSM, cleaner "def + ONE new (concealment) component" story. *Technical — resolver confirms; the fallback is cheap if reuse proves awkward.*

### OQ-2 — One-shot mechanism: host `_spent` gating (recommended) vs. a `ChargeLane` edit vs. a `Concealment` latch?
§2.3 achieves one-shot by the host **not re-ticking `ChargeLane`** after a completed cycle (`_spent`). Alternatives: a `one_shot`/`spent` field added to `ChargeLane` (a shared-component edit — deviation), or `Concealment` zeroing the `ProximityTrigger` radius after the first pounce (needs a `ProximityTrigger` setter — another edit). **Recommendation: host `_spent` gating** — zero shared-file edits, uses the host's existing prerogative over tick order. *Technical — resolver confirms; if `ChargeLane` re-arms faster than the host can gate, escalate to the one-line `ChargeLane` guard and record it in the ledger.*

### OQ-3 — `**NEEDS DIRECTOR REVIEW**` (fun/fairness) — Is the pounce fatal (`kills`-gated `fail_run`) or a nonfatal stagger?
The exploration recommends a **nonfatal stagger** ("fatal is brutal for a blind-loot punish; a stagger that drops you into other danger is the better teacher"). But **M1 has no HP pool and no stagger primitive** — the only lethality model is `kills`-gated `fail_run(&"death")` (breakdown §Scope guardrails). *Director question:* **Ship the pounce as a `kills`-gated fatal contact with a generous authored tell (the Wrecker fairness precedent), deferring the nonfatal stagger to an HP-bearing milestone?** *Recommendation:* **yes — fatal, `kills`-gated** (this is breakdown OQ6's recommendation; the fairness is bought by `tell_lead_s` + the reveal pop + the dodgeable locked lane). A knockback-style nonfatal branch exists in the codebase (`hazard_entity.gd:226` `nonfatal_handler`) and could later be wired via `LethalContact.nonfatal_handler` if the Director wants a non-lethal Ambusher variant — but that is a design expansion, not the M1.10 default. *Director ratifies.*

### OQ-4 — `**NEEDS DIRECTOR REVIEW**` (fun/fairness) — The tell subtlety: how readable is the HIDDEN tell + the arm lead?
"How telegraphed is the tell? Too subtle = feels cheap/unfair; too obvious = trivial. The fairness line here is the whole design" (exploration). Three knobs set this: `tell_alpha` (floor-decal visibility, default 0.28), `concealed_alpha` (body visibility at rest, default 0.0), and `tell_lead_s` (arm→pounce lead, default 0.45 s). At close range (you're looting) the lead is tighter than the Charger's. *Director question:* **Ratify the starting subtlety (faint-but-present floor tell `tell_alpha≈0.28`, invisible body `concealed_alpha=0`, 0.45 s arm lead) and let TG2 sweep — or start more forgiving (higher `tell_alpha`, longer lead) for the first playtest?** *Recommendation:* ship the defaults, treat `deaths-per-first-encounter` at TG2 as the fairness read (breakdown TG2), and sweep toward forgiving if first-encounter deaths spike. *Director ratifies; TG2 evidence drives the sweep.*

### OQ-5 — `**NEEDS DIRECTOR REVIEW**` (fun/vision) — A disguised-as-junk (mimic a pickup) variant?
"Disguised-as-junk (mimics a pickup) is the strongest version but risks confusing the loot read entirely — possible feel-bad" (exploration). This is a *cooler* Ambusher but would need the concealment to render as a **fake `JunkPickup`** (a second visual mode + possibly a fake interactable), risking the player mistrusting *all* loot. **Recommendation: NOT for M1.10** — ship the "hides among the junk with a faint floor tell" version (an environmental read, not a fake pickup), which keeps the loot verb honest. The mimic variant is a strong post-gate follow-up if TG2 shows players want a harder read. *Director decides whether the mimic is in-scope at all.*

### OQ-6 — Near-loot placement bias: standard builder placement (recommended) vs. a loot-coupled policy?
The exploration wants Ambushers *preferentially near high-value junk*, but there is **no params-only coupling** between `JunkPlacer` and `EncounterBuilder` — a true bias needs a builder/policy edit, which the "no EncounterBuilder edit" guardrail forbids for M1.10. **Recommendation: standard placement** (the cave's bad sightlines + scattered junk already deliver the "blind approach to a prize" tension); flag loot-coupling as a follow-up if TG2 asks. *Scope — resolver sets "standard"; Director may fund the coupling as a later task.*

### OQ-7 — Is `ARMED` throw-killable (pre-pop the spring), or only `EXPOSED`?
The DoD mandates `EXPOSED` throw-killable and `HIDDEN` un-hittable. §2.4 makes `ARMED` **also** throw-killable (it joins the `"hazard"` group on reveal), giving a reaction-throw counter — see the spring, throw before the pounce (the exploration's "spot the tell and throw to pre-pop"). **Recommendation: yes, `ARMED` is throw-killable** — it's the natural consequence of group membership on reveal, it's a fair skill counter, and it rewards attention. The DoD is unaffected (it only *mandates* EXPOSED). *Design — resolver confirms; if the Director wants the pounce unavoidable-once-armed, `Concealment.reveal()` would defer the group-join to EXPOSED (a one-line change).* 

### OQ-8 — Param key naming: Ambusher-semantic keys mapped in the host (recommended) vs. reuse `ChargeLane`'s raw keys?
§2.1 uses Ambusher-semantic keys (`arm_radius`, `tell_lead_s`, `lunge_speed`…) mapped to `ChargeLane`'s keys in `_resolve_params` — the Charger's `proximity_radius = aggro_range` rename precedent (`charger_hazard.gd:117`). The alternative reuses `ChargeLane`'s raw keys (`aggro_range`, `telegraph_s`…) directly, avoiding a mapping layer but making the menu read like a second Charger. **Recommendation: semantic keys** — the generated menu is the designer/Director's tuning surface; "arm_radius / tell_lead_s / exposed_window_s" is far more legible than "aggro_range / telegraph_s / recover_s" for a concealment trap. The mapping is a handful of lines and mirrors the Charger. *Technical — resolver confirms; low-risk either way.*

### OQ-9 — `**NEEDS DIRECTOR REVIEW**` (scope) — Band-3-native exclusivity for M1.10?
The breakdown (OQ9) recommends both new oppositions be **band-3-exclusive** in M1.10 for a clean A/B at TG2 (mirroring D-RAT-2). §2.1 encodes this via `min_band = 3` + deck membership. *Director question:* **Confirm the Ambusher stays band-3-native for M1.10 (clean A/B), or should it also enter band 1/2's decks?** *Recommendation:* **band-3-native** (clean measurement; the caverns are where concealment reads fair). Promotion later is a one-field `min_band` edit + a deck add. *Director confirms at the gate (also the TG3 watch-item "do Ambusher/Burrower enter shallower decks").*

### OQ-10 — Group-ownership: `Concealment` sole owner of `"hazard"` membership (recommended, via `throwable_while_charging = true`)?
For `Concealment` to own un-hittability cleanly, `ChargeLane` must not also toggle the `"hazard"` group. §2.1/§2.4 fix `throwable_while_charging = true` so `ChargeLane` no-ops its group toggle (`charge_lane.gd:126,192-199`), ceding membership entirely to `Concealment`. The trade-off: the fast `POUNCE` is then technically throw-killable (an emergent hard target). **Recommendation: yes** — single-owner group membership avoids two components fighting over `add_to_group`/`remove_from_group`, and the emergent hard-target pounce matches the Charger default. *Technical — resolver confirms; if the Director wants the pounce invulnerable, that reintroduces the contention and would need a coordination seam (a real cost — flag it).*

---

*Phase 3 (fresh eyes, NOT this author) resolves the Open Questions into a `Resolved Decisions` section, flagging OQ-3 / OQ-4 / OQ-5 / OQ-9 (fun/fairness/vision/scope) for the Director per the orchestrator loop, and confirming OQ-10's group-ownership on merit. Design-only — no code, no `.tres`. The programmer + character-animator build against this; deviations from the committed design go to `DESIGN_DEVIATIONS.md` for the Wave-1 close-out sweep, and the worklog carries the Bespoke-code ledger (§4) that TG3 judges.*

---

## Resolved Decisions (Phase 3 — fresh eyes, BINDING)

> Resolver: Phase-3 fresh-eyes agent (NOT the Phase-2 author), 2026-07-04. Every citation below
> re-verified against the working tree at resolution time: `charge_lane.gd`, `lethal_contact.gd`,
> `proximity_trigger.gd`, `throw_interaction.gd`, `thrown_item.gd`, `opposition_component.gd`,
> `charger_hazard.gd`, `charger.tres`, `opposition_def.gd`, `telegraph_fsm.gd`,
> `encounter_builder.gd`, `test_opposition_def_schema.gd`, `player.tscn`, `charger.tscn`,
> plus the T2b and T3 sibling designs (seam check). Verdicts here are **binding on the build**
> unless the Director overrules a flagged item. Fun/fairness/vision/scope calls are NOT
> self-resolved — they carry a recommendation and sit in the Director queue at the bottom.

### Per-OQ verdicts

- **OQ-1 — Pounce engine: RESOLVED — reuse `ChargeLane` verbatim.** The §1.3 state mapping
  verified exact against the real FSM (`charge_lane.gd:46` enum; DORMANT `:113-119`, TELEGRAPH
  `:120-127`, CHARGE + swept test `:128-140` + `:178-185`, RECOVER `:141-145`; `on_state_changed`
  is a host-assigned `Callable` invoked `(state: int, wall_crash: bool)` on every transition,
  `:60`, `:202-206` — the host hook signature in §2.3 matches). `bind()` seats DORMANT without
  firing the hook (`:96-104`), confirming the host-seats-HIDDEN-itself note. A bespoke lunge would
  re-derive proven, `test_charger`-gated logic for zero design gain. **Zero `charge_lane.gd`
  edits.**

- **OQ-2 — One-shot mechanism: RESOLVED — host `_spent` gating, confirmed safe.** The feared
  race does not exist: `_enter(State.DORMANT)` fires `on_state_changed` **synchronously inside
  `tick()`** (`charge_lane.gd:202-206`), so the host latches `_spent` before `tick()` even
  returns; a DORMANT→TELEGRAPH re-arm can only happen inside a *subsequent* `tick()` call, which
  `_spent` now gates. Even `cooldown_s = 0` (the one-shot's `re_hide_s = 0` fold) cannot re-arm
  within the same frame. The escalation path (a `ChargeLane` `one_shot` guard) is **not needed**
  — do not take it speculatively.

- **OQ-3 — Pounce lethality: NEEDS DIRECTOR REVIEW** (fun/fairness). Recommendation confirmed on
  the merits available to a resolver: **fatal, `kills`-gated**, per breakdown OQ6 — M1 has no HP
  pool/stagger primitive, and the fairness spend (locked lane + `tell_lead_s` + reveal pop) is
  the Wrecker precedent. As-built correction to the fallback note: the nonfatal branch is
  `LethalContact.nonfatal_handler` (`lethal_contact.gd:51`, `:154-155`), wired by R1 at
  `scenes/hazards/hazard_entity.gd:83` (commented `:221`) — not `hazard_entity.gd:226`. It exists
  and could carry a nonfatal variant later; not the M1.10 default.

- **OQ-4 — Tell subtlety: NEEDS DIRECTOR REVIEW** (fun/fairness). Ship the proposed defaults
  (`tell_alpha 0.28`, `concealed_alpha 0.0`, `tell_lead_s 0.45`) and let TG2's
  deaths-per-first-encounter drive the sweep. Resolver math check: a player walking straight in
  covers `arm_radius` 90 px in exactly 0.45 s at 200 px/s — the lead is *just* enough to
  lateral-dodge (0.22 s reaction + ~0.14 s clear) but has no slack; if the Director wants a
  forgiving first playtest, raise `tell_lead_s` to 0.6, not `tell_alpha`. One schema fix
  (binding): the `arm_radius` gloss says "0 = permanently inert" while the row's `min` is 32
  (menu can never set 0 — same shape as charger `aggro_range`, `charger.tres:52`). Keep `min 32`;
  move the 0-gate remark out of the gloss into the test-harness notes (tests inject
  `arm_radius: 0` via `spawn_ctx["params"]`, which bypasses schema mins).

- **OQ-5 — Mimic-a-pickup variant: NEEDS DIRECTOR REVIEW** (fun/vision). Recommendation
  confirmed: **NOT for M1.10.** The fake-`JunkPickup` read risks poisoning the loot verb the
  whole game teaches; the floor-tell version keeps the read environmental. Post-gate follow-up
  if TG2 wants a harder read.

- **OQ-6 — Near-loot bias: RESOLVED — standard placement.** Verified: `_populate_deck`
  (`encounter_builder.gd:298-368`) places by even-spread + cell stride with **no coupling to
  `JunkPlacer` output** — a loot bias is structurally impossible without a builder edit, which
  the guardrail forbids. Standard placement ships; loot-coupling is a flagged TG2 follow-up.

- **OQ-7 — ARMED throw-killable: RESOLVED — yes.** Natural consequence of joining the
  `"hazard"` group at reveal (`thrown_item.gd:79-80` group check → `_hit_hazard`), a fair
  reaction-throw counter, DoD unaffected. The one-line deferral (join at EXPOSED instead) stays
  documented as the Director's cheap opt-out.

- **OQ-8 — Param naming: RESOLVED — semantic keys, with the precedent stated honestly.** The
  charger's actual rename layer is **one key** (`proximity_radius = aggro_range`,
  `charger_hazard.gd:117`) — its def otherwise ships `ChargeLane`'s raw keys as the authored
  schema (`charger.tres:18-32`). The Ambusher's full semantic bag goes further than precedent,
  but it is bijection-safe (the schema test checks params↔schema *within the def*,
  `test_opposition_def_schema.gd:138-152`, never cross-def key names), costs a handful of
  `_resolve_params` lines, and the menu-legibility argument stands. Confirmed.

- **OQ-9 — Band-3 exclusivity: NEEDS DIRECTOR REVIEW** (scope). Recommendation confirmed:
  **band-3-native.** Verified the gate is real and cheap to lift later: the deck lane filters
  `band_depth >= d.min_band` (`encounter_builder.gd:303-305`), `band_greybox` runs the legacy
  lane (no deck), `band_two` is `band_depth = 2` — structural exclusivity with `min_band = 3`,
  matching T3's deck design (T3 §3.4 note) and the D-RAT-2 A/B precedent.

- **OQ-10 — Group ownership: RESOLVED — `Concealment` is sole owner, WITH TWO BINDING
  AMENDMENTS.** The direction is right, but two as-built facts change the mechanism:

  1. **"`ChargeLane` never touches the group" is false as stated.** `ChargeLane._configure`
     calls `_set_throwable(true)` **unconditionally at bind** (`charge_lane.gd:104` — "undo a
     mid-dash group toggle from a prior bind"), and `_set_throwable(true)` fires again at
     CHARGE entry/exit (`:126`, `:137`) — with `throwable_while_charging = true` these are
     add-if-absent no-ops **only while the host is already in the group**. The pseudocode's
     `_conceal.hide_conceal()` **LAST in `setup()`** (§2.3) is therefore **load-bearing, not
     hygiene** — it is what neutralizes the bind-time group-add. Binding: keep that order, and
     the build's comment must say why. (The `:126`/`:137` add-backs are harmless in every
     reachable flow: reveal always precedes CHARGE, so the host is in-group by then.)

  2. **Concealment must own `collision_layer` too — HIDDEN is layer 0.** Group-only gating is
     *functionally* sufficient for "can't be killed," but not for "un-hittable," because the
     body stays on layer 16 and two physical facts leak: **(a)** `ThrownItem` (`collision_mask
     18`) still gets `body_entered` off a hidden body and resolves `_miss()` — the item **stops
     mid-air on empty floor and re-drops at the hidden Ambusher's feet** (`thrown_item.gd:76-82`,
     `:114-121`), a free position-reveal that reads as a glitch and trivializes the concealment
     read; **(b)** the **player's body collides with hazard layer 16** (`player.tscn:14`
     `collision_mask = 26` = world 2 + 8 + hazard 16), so a hidden body is an invisible
     obstacle in edge cases (`arm_radius`-0 sweeps, spawn adjacency). T2b independently reached
     layer-clearing for exactly these reasons (`T2b_burrower.md` §1.3) — two Wave-1 oppositions
     must not ship two different un-hittability idioms. **Binding:** `Concealment._set_hittable`
     owns **both** properties on its own host node — HIDDEN: `collision_layer = 0` + out of
     group; ARMED/POUNCE/EXPOSED: `collision_layer = 16` + in group; SPENT: `collision_layer =
     16` (a visible husk is solid debris) + out of group (items re-drop off it, can't be farmed).
     Still a plain own-node property write (the `BurrowCycle` idiom), **zero shared-file edits**,
     ledger impact ~+5 lines in `concealment.gd`. Consequential DoD amendment: **test 4(a)
     changes from "misses/re-drops" to "passes clean through"** — a throw across a HIDDEN
     Ambusher produces **no** `body_entered` against it, no `throw_missed` at its position (the
     item flies on to its own wall/max-range miss elsewhere), and the Ambusher survives.

### As-built corrections (fold into the build; none change the architecture)

1. **`oppositions_enabled` is ADDITIVE, not conjunctive.** §2.1's "loads only when `&"ambusher"
   ∈ oppositions_enabled **and** a live deck lists it" is wrong: the deck lane runs off the
   profile deck alone, and `rc.oppositions_enabled` is an additive extras list appended to it
   (`encounter_builder.gd:27`, `:131-137` `is_inert`, `:407-423`). Correct statement: the
   Ambusher spawns when **either** `band_three`'s deck lists it (T3) **or** the extras lever
   names it. The all-off control is unaffected (the shipped default has neither) — fingerprint
   claim stands.
2. **Scene-declared group + layer are REQUIRED, not optional.** `test_opposition_def_schema.gd`
   scans **all** `.tres` under `data/oppositions/` (count-agnostic — `ambusher.tres` enters
   automatically, no shared-test edit) and bare-instantiates every `host_scene`, requiring the
   root **in the `"hazard"` group** (`:262`) plus `resolve_throw_death`/`get_def_id` with
   `get_def_id() == def.id` (`:264-271`). Binding: `ambusher.tscn` root declares
   `groups=["hazard"]`, `collision_layer = 16`, `collision_mask = 2` at author time (the
   `charger.tscn:8-10` shape); `Concealment.hide_conceal()` at `setup()` then seats layer-0 +
   out-of-group. §2.7's asset spec must add this. (The test's `MIRROR`/`KILLS_MIRROR`/
   `TRAP_FLAG`/`HOST_CLASS` maps are legacy-4-only by design — T2a does **not** edit that test;
   host-class/trap pinning for `&"ambusher"` lives in `test_ambusher`.)
3. **Add exactly one `trap_if_neutral: true` schema row** (S6a convention; the charger carries
   it on `charge_speed`, `charger.tres:67`). Recommend `lunge_speed` — the mechanism-critical
   magnitude, mirroring the charger's choice. The doc's schema table omits this entirely.
4. Minor citation drift, corrected for the programmer: ChargeLane's "inert, **visible**,
   learnable" DORMANT comment is at `charge_lane.gd:22-23` (not `:31`); the charger wiring block
   is `charger_hazard.gd:78-89`; `apply_contact` is `lethal_contact.gd:102-107`; the cell-size
   cite `main_game.gd:42` is stale (that line is now `BAND_ID`) though 16 px cells stand;
   R1's nonfatal wiring is `scenes/hazards/hazard_entity.gd:83`/`:221` (see OQ-3).
5. **Def count check:** `data/oppositions/` holds 7 defs today (incl. `splitter_child`);
   `ambusher.tres` makes the doc's "8 defs" correct as written.
6. Card values verified against T3's assumptions — **no change needed**: `credit_cost 2`,
   `base_count 1` *on the def* (T3 §2.3 requires natives carry their own demand), `per_room_cap
   2`, `per_band_cap 6`, `min_band 3` all sit inside T3's §4.3 budget-sim targets (cost ≈2,
   cap 5-6).

### Cross-task amendments (for orchestrator adjudication before Wave-1 dispatch)

1. **`ui/config/config_strings.csv` is a REAL T2a↔T2b file collision** — the one common file
   the two "file-disjoint" designs both need. T2a lists `CFG_FIELD_AMBUSHER_*` rows explicitly
   (§0, §4); T2b's schema table implies burrower rows (and mis-names them `CFG_GLOSS_BURROWER_*`
   — the shipped convention is `CFG_FIELD_<DEF>_<KEY>`, per `charger.tres`/`config_strings.csv:
   163-170`; T2b must correct its prefix). **Recommended adjudication:** neither branch touches
   the csv; each worklog carries its row block verbatim, and the orchestrator applies both in
   one integration commit at the Wave-1 merge. Safe to defer: no test asserts gloss-key coverage
   against the csv (missing rows only degrade menu labels), and the compiled
   `config_strings.en.translation` is gitignored — no binary conflict.
2. **T2b's `phase_salt` assumption is broken as-built** (flagged here because it threatens a
   *silent shared-file edit* in the same wave): `EncounterBuilder.legacy_ctx` stamps
   `phase_salt` for `&"spike"` **only** — every other kind gets `{}` (`encounter_builder.gd:
   111-121`), so every Burrower would read salt 0 and pop in unison. T2b must either derive its
   desync from ctx it *does* get (`depth`/`room_key`/spawn cell are stamped for all deck spawns)
   or raise an adjudicated one-line `legacy_ctx` request — never a silent edit. No T2a impact
   (the Ambusher is event-driven and needs no salt).
3. **Un-hittability idiom is now UNIFIED across the wave** (per OQ-10 amendment 2): both new
   oppositions gate targetability as *layer 0 + out of group* while untargetable, both as
   own-node writes inside their ONE new component. This is the coherent player-facing rule and
   keeps both cost ledgers at zero shared edits.
4. **T3 seam confirmed from this side:** deck id `&"ambusher"`, def-carried `base_count 1`,
   and the card values above match T3's deck order/budget walk (§3.4/§4.3). No coordination
   change requested.

### Ledger impact of Phase 3

Unchanged in kind: still `def + ONE component + host shell + scene + test`, zero shared-file
edits. `concealment.gd` grows ~5 lines (the `collision_layer` writes). The two §4 risk points
are now **closed** (OQ-2: host gating proven safe; OQ-10: no contention, ownership unified).

### NEEDS DIRECTOR REVIEW (queue for the Wave-1 close-out — recommendations attached)

| # | Call | Recommendation |
|---|---|---|
| OQ-3 | Pounce fatal (`kills`-gated) vs nonfatal stagger | **Fatal, `kills`-gated**; stagger deferred to an HP-bearing milestone |
| OQ-4 | Tell subtlety starting values (`tell_alpha 0.28` / `concealed_alpha 0` / `tell_lead_s 0.45`) | **Ship defaults**, sweep on TG2 first-encounter deaths; if pre-softening, raise `tell_lead_s` → 0.6, not `tell_alpha` |
| OQ-5 | Disguised-as-junk mimic variant | **Not in M1.10**; post-gate follow-up |
| OQ-9 | Band-3-exclusive for M1.10 | **Yes** — clean three-band A/B; promotion later is a `min_band` edit + deck add |
