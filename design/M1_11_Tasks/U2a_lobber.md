# U2a — New opposition #1: the LOBBER (def + one MortarCycle component) — Expanded Design Spec

**Milestone:** M1.11 (Third-Gen Backend + Open-Field Band + Ranged Oppositions) · **Workstream:** oppositions · **Wave:** 1 (parallel worktree, file-disjoint from U0/U2b)
**Task id:** U2a · **BlockedBy:** none (rides the S0/S2/S3 stack shipped in M1.9, extended by M1.10)
**Assignees:** general-purpose (host shell + `MortarCycle` component + `lobber.tres` + test) · character-animator (greybox body + ground-marker placeholder — inline; PixelLab Director-gated)
**Author:** game-director-designer · **Status:** Phase 2 (per-task design). The `Open Questions` below feed Phase 3 (fresh-eyes resolution + Director ratification).

> **What this doc is.** Per CLAUDE.md's four-phase authoring, this is the U2a per-task design: the M1.11 breakdown's §U2a contract expanded into mechanic detail, the `lobber.tres` def + `param_schema`, the ONE new component (`MortarCycle`) pseudocode against the real S2 base contract, the reuse decisions (bomb blast model, `LethalContact` `&"external"`, `ThrowInteraction`, `TelegraphFSM`), spawn/placement rules, the placeholder marker spec, telemetry, and the acceptance-test plan. It is **design only** — it ships **no game code and no `.tres`**. U2a is one of M1.11's two *cost-ledger* proofs: adding this opposition must cost `lobber.tres` (data) + **ONE new component** (`MortarCycle`) + its own Actor-host shell + a scene + a test + the CSV gloss rows — and **nothing else**. If it costs a shared-file edit, that overspend IS the UG3 scalability finding and must be recorded in the worklog's Bespoke-code ledger.

---

## 0. Hard constraints (read first)

Straight from the M1.11 breakdown scope guardrails and cross-cutting contracts. The spec must not violate them, and neither may the build:

- **"No new opposition machinery" (breakdown §Scope guardrails).** The Lobber rides the S0/S2/S3 stack exactly as shipped: `OppositionDef.tres` + `param_schema`, **ONE new `OppositionComponent`** (`MortarCycle`), spawned by `EncounterBuilder`/`SpawnService`, surfaced by the generated menu + the per-def bijection net. The single new engineering artefact is `mortar_cycle.gd`. The blast telemetry/kill machinery is the **reused `LethalContact` in `&"external"` mode** (`lethal_contact.gd:30-32,102-108` — the same seam `ChargeLane` and `BurrowCycle` drive); the throw-death is the reused `ThrowInteraction` `&"die"` (`throw_interaction.gd:29-32`); the fire tell is the reused `TelegraphFSM` (`telegraph_fsm.gd`). **`LethalContact` stays untouched** — its `&"on_command"` mode tests the *host's own* position (`lethal_contact.gd:113-115`), which is **wrong** for a Lobber whose shell lands *away* from the body, so `MortarCycle` computes the marker-vs-player distance itself and hands the boolean to `apply_contact` (the same pattern `BurrowCycle` uses for its radius test — `burrow_cycle.gd`). Any edit to a *shared* host/component file is a **flagged deviation** with a designated single writer, not silent sprawl.
- **M1 lethality model only — `kills`-gated `fail_run`, no HP pool.** The blast is a lethal contact routed through the reused `LethalContact`'s `kills`-gated `GameState.fail_run(&"death")` with emit-always telemetry (`lethal_contact.gd:143-155`). No health bar, no chip damage, no damage-over-time. **The Lobber body is *not* contact-lethal** — walking into the Lobber never kills; only its shells do (the exploration's "slow, low-threat" body). This is a deliberate identity choice, not an oversight (§2.4).
- **All-off is byte-identical.** The Lobber ships **off by default**: not in `RunConfig.new().oppositions_enabled`, not in `make_default_play_preset()`, not in `band_greybox`/`band_two`/`band_three`'s decks. With the shipped default **no `lobber.tres` loads and no node spawns**, so the permanent all-off fingerprint **`e943ac9c8bc1`** and the three band fingerprints are untouched. It becomes reachable only via `band_four`'s deck (U3) behind the fourth hub portal (U4).
- **Knob model frozen; per-def net extends itself.** No new hand-authored `RunConfig` levers. The Lobber appears via the count-agnostic generated Oppositions tab; the per-def `params`↔`param_schema` bijection extends to **10 defs** (9 shipped + Lobber; Sentry makes 11). **No global def-count hard-assert in `test_lobber`** — the coverage net is dir-scanning + count-agnostic; U2a lands 9→10 and U2b 10→11 in the same wave (the M1.10 amendment-8 lesson: a hard `== N` assert would break the moment the sibling merges).
- **Deterministic placement; reactive behaviour is run-state.** *Where* Lobbers spawn is a pure function of `seed + config` — the builder walks the graded band RNG-free and the service places them; **no global `RNG`** in `mortar_cycle.gd` or the host. The fire cadence + where a shell lands (it reads the *live* player position each fire) is legitimately reactive **run-state** (player-driven, like the pursuer's chase / `BurrowCycle`'s track), never written back to the layout stream, so it cannot poison `fingerprint()`.
- **Locked contracts, read-only.** Reads `GameState.current_depth_index` (live, BUG2); routes run-end through the **existing** `GameState.fail_run(&"death")` (no new end-cause); emits **only** the S0-pre-declared generic signals (`opposition_event`, `opposition_killed_player`) via the reused components — it does **not** edit `event_bus.gd`, `game_state.gd`, or `run_config.gd`.
- **File-disjoint in Wave 1.** U2a owns **new files only**: `data/oppositions/lobber.tres`, `scenes/hazards/lobber.tscn`, `scenes/hazards/lobber_hazard.gd`, `scenes/hazards/components/mortar_cycle.gd`, `tests/test_lobber.gd`/`.tscn`. The `CFG_FIELD_LOBBER_*` gloss rows in `ui/config/config_strings.csv` are **orchestrator-applied at the Wave-1 merge** (the M1.10 amendment-6 protocol — the shared CSV has a single designated writer at integration, not the U2a worktree). U2a does **not** touch `main_game.gd`, `thrown_item.gd`, any menu file, the reused components, `encounter_builder.gd`, or `spawn_service.gd`. U0 owns `systems/bandgen/` + `band_profile.gd`/`band_pipeline.gd`; U2b owns its own component/def/test.
- **Placeholder art tint-only; PixelLab Director-gated.** The body + ground marker ship as **inline greybox** (`Polygon2D` + `modulate`/`Tween` — the M1 greybox norm, D-RAT-4 precedent). Pixel filter OFF; copy-not-move from `art_workshop/`; any PixelLab run needs an explicit Director OK.

---

## 1. Research — why the Lobber, and why it is a clean architecture proof

### 1.1 The idea, restated as requirements

From `design/explorations/exploration-20260625/hazards/2-lobber.md`: a slow/static entity that **arcs a projectile in a high parabola onto a target spot on the ground** — a telegraphed marker where the player *currently is* (optionally led slightly), then detonates after a short flight delay. Its behavioural distinctness: **it punishes standing still.** Every shipped opposition and its M1.10 siblings are **contact-lethal** — the threat is a body you must not touch (the pursuer's chase, the charger's lane, the ambusher's pounce, the burrower's surface, the bomb's proximity ring). The Lobber is the first opposition whose threat is **indirect, player-targeted, area-of-effect, delivered on a flight-time telegraph** — it turns *dwelling in one place* into the mistake, taxing exactly the pause the **loot** verb and the **extract** decision demand (you can't camp a junk pickup or idle at a gate deciding push-vs-cash-out while shells rain). That is a threat axis **nothing shipped exercises**, and the open field (U0's `ScatterBackend`) is where it reads fair — long sightlines mean you can see the marker land and step off it, and the arc's geometry-ignoring reach is *the* answer to "why can't I just duck behind cover and wait." **The Sentry (U2b) makes cover safety; the Lobber makes camping cover fatal** — together they are the open-field band's cover dialogue (breakdown §Source explorations).

**The arc ignores geometry** (breakdown §U2a — *its identity*). Cover does NOT protect you from a shell; *moving* does. This is not a limitation to fix later — it is the whole point, and it falls out of the distance-test blast model **for free** (no line-of-sight, no occlusion, no pathing — the engine has none of those yet, and the Lobber needs none of them).

### 1.2 What is reused vs. the ONE new thing

| Concern | Source (as-built) | Reused / New |
|---|---|---|
| `CharacterBody2D` Actor host, `hazard` layer(16) / `world` mask(2), `"hazard"` group, `setup(cfg, player, spawn_ctx)` snapshot, self-timed run clock, fixed component tick order | S2 Actor-host family shell (`bomb_hazard.gd`/`charger_hazard.gd` shape) | **Host shell — honest per-def cost** (the S6a Wave-4 amendment: each def ships its own host until a future shared parameterized host) |
| Delayed-detonation blast → `kills`-gated `fail_run(&"death")` + emit-always `&"hit_player"` + BUG6 one-shot latch, driven by an externally-computed contact boolean | S2 **`LethalContact`** `&"external"` mode (`lethal_contact.gd:102-108`) — **not** `&"on_command"`, because that tests the host's own position, and the Lobber's blast lands *away* from the body | **Reused verbatim** (`MortarCycle` feeds `apply_contact` a marker-vs-player boolean, exactly as `BurrowCycle` feeds a radius boolean) |
| Fire tell colour-flip / wind-up flash on the Lobber body | S2 **`TelegraphFSM`** (`telegraph_fsm.gd`) | **Reused** (new colour *values*, not new code) |
| Free-on-throw-kill (silence the rain) | S2 **`ThrowInteraction`** `&"die"` + existing `thrown_item.gd` group path | **Reused verbatim** (no shared-file edit) |
| Ground-marker telegraph draw (a ring at the blast radius) | the bomb's idle-ring polygon draw idiom (`bomb_hazard.gd:171-177`, `_draw_idle_ring`) — the *shape*, re-owned inside `MortarCycle` for the **landing marker at a WORLD position away from the host** | pattern reused; the world-positioned marker + its arc-time reveal is **the new bit** |
| **MortarCycle: the fire-period FSM (AIM → IN-FLIGHT → IMPACT → cycle), target selection (live player pos + optional velocity lead), the world-positioned landing marker + its `arc_time` reveal, and the marker-vs-player blast distance test fed to `LethalContact`** | **`mortar_cycle.gd`** | **NEW — the one new artefact** |
| `lobber.tres` def + `param_schema` | data | **Data (the proof's whole point)** |

> **Why `MortarCycle` is genuinely new and small.** No shipped component delivers a threat to a point *away from the emitter* on a flight-time telegraph. The bomb detonates at its own body (`command_hit` tests `host.global_position`); the charger/ambusher/burrower all threaten from their own body. `MortarCycle` owns exactly the delta — *pick a spot on the ground, telegraph it for `arc_time`, then test the blast there* — and nothing else. It does not run a body-contact kill, does not toggle collision layers or group membership (the Lobber is always a valid target — §2.4), does not emit its own telemetry token beyond driving the host's hooks. It is a pure targeting + telegraph + external-contact FSM, structurally a sibling of `BurrowCycle` (same base contract, same `lethal:`/`on_state_changed:` host-assigned seams).

### 1.3 The blast engine: reuse `LethalContact` `&"external"`, don't build a second kill path

The breakdown says "the blast is a distance test in the component, `LethalContact` untouched." The mapping is exact and mirrors `BurrowCycle`:

| Lobber beat | `LethalContact` interaction | What already happens there |
|---|---|---|
| AIM (waiting `fire_period_s`) | `apply_contact(false, true)` (or simply not called) | non-lethal; latch armed |
| IN-FLIGHT (`arc_time_s`, marker shown) | non-lethal — **the dodge window** | latch stays armed; no test runs |
| IMPACT (one frame) | `apply_contact(hit, true)` where `hit = marker_pos.distance_to(player) <= blast_radius` | emit-always `&"hit_player"` + L5 `kills` gate → `fail_run(&"death")` + BUG6 rising-edge latch, **once** |
| cycle back to AIM | `apply_contact(false, true)` | re-arms the falling edge for the next shell (`charge_lane.gd:139` / `burrow_cycle.gd` idiom) |

A **bespoke kill path inside `MortarCycle`** (calling `GameState.fail_run` + emitting the rows itself) was considered and **rejected**: it would re-derive the emit-always telemetry, the L5 `kills` gate, the BUG6 latch, and the `opposition_killed_player`-only-when-fatal distinction that `LethalContact` already proves and `test_charger`/`test_burrower` already gate — inflating the ledger and re-testing solved problems. The `&"external"` seam gives all of it for the cost of computing one boolean. *(Technical — Phase-3 resolver confirms.)*

### 1.4 Fairness — the marker + `arc_time` IS the dodge contract (the fun/fairness line)

The Lobber's failure mode is a **shell that kills you inside the window you were given to dodge** — an un-dodgeable AoE. The M1 lethality bar (Wrecker/Charger/Burrower precedent: a generous, readable telegraph precedes every kill) makes the fairness mechanism non-negotiable. The design guarantees a dodge window through **three** compounding rules, directly transplanting the Burrower's locked-decal precedent (`burrow_cycle.gd` §1.4):

1. **The blast test runs ONLY at IMPACT** — the last frame of IN-FLIGHT, never during it. Standing on the marker for the whole `arc_time` and *then* stepping off one frame before impact is safe; the shell only ever checks the geometry once, at the end.
2. **The marker is shown for the full `arc_time_s`** before impact — the authored dodge window. This is the `telegraph_lead_s` role, transplanted to a projectile: `arc_time` = "shell in flight" = the seconds you have to leave the circle.
3. **The marker LOCKS at fire time.** When AIM elapses, the landing point is captured *once* (`_marker_pos = player.global_position + lead`) and **frozen** for the whole flight — the marker does not chase the player. Stepping `blast_radius` away from the *frozen* point is a guaranteed dodge. (A marker that re-tracked the player through the flight would make "dodge" impossible — that is the unfair variant, not the default; there is no re-track knob in v1.)

**The fairness envelope, in the real player numbers.** Anchors (verified in-repo): player top speed **`200` px/s** (`data/player/player_movement.tres`, `max_speed`), reached in ~0.1 s; cell size **16 px** (`main_game.gd`); player radius **14 px**. To escape a blast, the player must move their *centre* more than `blast_radius` from the frozen marker. Time-to-escape ≈ `reaction (~0.22 s) + blast_radius / 200`. The dodge is fair iff:

> **`arc_time_s`  >  ~0.22 + `blast_radius` / 200**

At the **defaults** (`arc_time_s = 0.9`, `blast_radius = 48`): escape ≈ 0.22 + 0.24 = **0.46 s**, leaving **~0.44 s of slack** inside the 0.9 s window — comfortably fair, and with `lead_factor = 0` (the default) the marker lands where you *were*, so simply continuing to walk clears it. The corner of the sweep space where the invariant *breaks* (tiny `arc_time` + huge `blast_radius` — e.g. `arc_time 0.4` + `blast 96` needs ~0.70 s to clear) is **intentionally reachable** as the Director's difficulty dial (the burrower `lock_surface_at_telegraph = false` precedent — a hard/unfair corner exists for tuning), but the **default ships fair** and `test_lobber` asserts the *default* is dodgeable (§3), not that every param combo is. The exploration's own read: no-lead is "fair and readable but trivially countered by walking"; a small band-scaled lead is the difficulty escalation (OQ-1, Director).

### 1.5 The anti-loot-camping role in the open field

The Lobber is authored *for* U0's open-field arena. In the socket/cave bands the play was "read the doorway / read the low-sightline nook"; the open field's identity is "where do I stand, and what can see me" (breakdown §Source explorations, `b1-open-field-with-cover.md`). The Lobber is the native that makes *standing anywhere too long* the mistake:

- **Loot tax.** `JunkPickup` requires a pause at a pickup (`interactable_id=&"junk"`). A Lobber shelling the arena turns "walk up and grab" into "grab and immediately relocate."
- **Extract-decision tax.** You can't idle near the gate weighing push-vs-cash-out while markers bloom around you — the classic roguelite "greed clock" made spatial.
- **Cover dialogue with the Sentry.** The Sentry (U2b) makes cover *safe* against its lane bolt; the Lobber's geometry-ignoring arc makes *camping that cover* fatal, so the pair denies both "run the open lanes" and "hunker behind a block." The exploration flags **Lobber + Sentry** as "vicious" precisely because the Lobber denies the safe standing spots between the Sentry's lane crossings.

None of this needs new placement logic: the standard `EncounterBuilder` even-spread across the arena chunks (§2.5) already scatters Lobbers through the open floor.

### 1.6 Fiction pitches (2–3 — tone call, Director picks; `id` stays `&"lobber"`)

Band 4 is the **open-field** band (U0/U3, `band_depth = 4`) — long sightlines, "a wrong, too-open expanse" (b1). The exploration's fiction: **old artillery / ordnance half-buried in a war-surplus scrapyard**. Three framings (final name is `display_name`; the stable `id` / telemetry / tests never change with flavour — the Wrecker precedent):

- **(A) "The Mortar" / "Scrap-Battery" (recommended — mechanical-junkyard, open-field-native).** A half-buried automated ordnance piece still running its fire solution: it ranges you, lobs, re-ranges. Ties to THE FAR YARD's "every junkyard is one junkyard" fiction (a buried war-machine, sibling to the Wrecker's crusher and the Burrower's auger). The "shell in flight" telegraph reads instantly as artillery. Cyrus VO hook: *"That's ranging fire. Standing still is how it gets you — keep the feet moving."*
- **(B) "Spitter" / "Bombardier" (creature read).** A slow bloated thing that hawks explosive bile in an arc. Warmer/monster; risks reading as "just a bomb thrower" and is slightly off the melancholy-industrial tone.
- **(C) "The Tithe" / hazard-as-place read.** Not a discrete emitter but the *sky of the too-open expanse* deciding, on a beat, that you've been still too long — the field itself taxing stillness. Most abstract; leans hardest into the b1 "the place is the enemy" identity but is the hardest to read at greybox (where is it? what do I throw at?).

**Recommendation: (A) The Mortar** — tightest coupling to the existing junkyard-machine fiction and the clearest "a machine is aiming at me" telegraph, which directly serves the fairness read (§1.4). (C) is the elegant open-field-identity alternate if the Director wants the band's "too-exposed" theme front-loaded. Needs Director review (OQ-6).

---

## 2. Design spec + pseudocode

### 2.1 `lobber.tres` — the `OppositionDef` (data — the proof's payload)

Authored against the S0/S2 `OppositionDef extends Resource` schema (`data/oppositions/opposition_def.gd`). All tuning lives in `params` with a mirroring `param_schema` (read by the generated menu + the params↔schema bijection lint). The host **maps** Lobber-semantic param keys to the reused components' expected keys in `_resolve_params` (the charger/ambusher/burrower rename pattern). Illustrative (authored in the inspector; mirrors `burrower.tres` structure):

```
# data/oppositions/lobber.tres  (illustrative — authored in the inspector)
id             = &"lobber"                  # stable; events / telemetry / throw-kind / deck ref
display_name   = "The Mortar"               # tone/naming — U3/Director ratifies; id stays &"lobber"
archetype      = "actor"
host_scene     = ExtResource("res://scenes/hazards/lobber.tscn")

# --- Spawn card (read by the EncounterBuilder) ---
credit_cost    = 2        # a pressure/area-denial piece (not a bruiser); burrower's 2 precedent
spawn_weight   = 1.0
min_band       = 4        # HARD gate to band 4 (open-field-exclusive for M1.11, OQ-7);
                          #   doubly reinforced by band 1/2/3 decks omitting it

# --- Hard caps (read by the SpawnService) ---
cap_group      = &"new_hazards"
per_room_cap   = 1        # one sheller per chunk (a rhythm read, not a marker-soup swarm)
per_band_cap   = 3

# --- Lethality (reused LethalContact &"external"; the BLAST is lethal, not the body) ---
lethality      = "lethal"
kills          = true     # standing convention: kills also lives in params (deck-sweepable), typed field kept in agreement

params = {
    # --- Lobber-semantic knobs (host maps → component keys) ---
    "fire_period_s": 2.5,          # AIM duration between shells (the cadence)
    "arc_time_s": 0.9,             # shell flight = the dodge window (the fairness line — OQ-1)
    "blast_radius": 48.0,          # marker/blast radius (px); the marker ring IS this radius
    "lead_factor": 0.0,            # seconds of player-velocity lead (0 = lands where you are)
    "kills": true,
    # --- Spawn-card count knobs (builder-read; never reach the entity) ---
    "base_count": 1,
    "count_per_depth": 0.0,
}
param_schema = [ ... ]    # one row per params key (bijection lint-checked)
```

**`param_schema` table** (defaults tuned against player 200 px/s + 16 px cells; **sweep starts, not balance claims** — UG2 validates):

| key | type | default | min | max | gloss (CSV key) | behaviour it drives |
|---|---|---|---|---|---|---|
| `base_count` | int | **1** | 0 | 10 | `CFG_FIELD_LOBBER_BASE_COUNT` | Builder spawn-card: base Lobbers per band. |
| `count_per_depth` | float | **0.0** | 0.0 | 5.0 | `CFG_FIELD_LOBBER_COUNT_PER_DEPTH` | Builder spawn-card: +Lobbers per depth index. |
| `fire_period_s` | float (s) | **2.5** | 0.8 | 8.0 | `CFG_FIELD_LOBBER_FIRE_PERIOD_S` | Seconds AIMing between shells. Lower = relentless rain; higher = occasional pressure. |
| `arc_time_s` | float (s) | **0.9** | 0.4 | 2.5 | `CFG_FIELD_LOBBER_ARC_TIME_S` | Shell flight = the marker-shown dodge window. **The fairness line** — never lethal inside it; floor 0.4 borders unfair at large `blast_radius` (§1.4). |
| `blast_radius` | float (px) | **48.0** | 16.0 | 96.0 | `CFG_FIELD_LOBBER_BLAST_RADIUS` | Marker + kill radius (centre-in-radius test, the bomb precedent). `0` = inert (never kills — `trap_if_neutral`). The marker ring is drawn at exactly this radius (honest contract). |
| `lead_factor` | float (s) | **0.0** | 0.0 | 1.0 | `CFG_FIELD_LOBBER_LEAD_FACTOR` | Player-velocity lead in seconds of prediction: `landing = player_pos + player_vel * lead_factor`. `0` = lands where you stand (fair/readable); `>0` = leads your movement (the difficulty dial — OQ-1). |
| `kills` | bool | **true** | — | — | `CFG_FIELD_LOBBER_KILLS` | The L5 `*_kills` toggle. `false` = the blast emits contact but never `fail_run` (per-def gate; deck-sweepable). |

That is **7 keys** (2 spawn-card + 5 entity) — the same shape as the charger/splitter/burrower bags. `blast_radius` carries `trap_if_neutral: true` (0 = inert, the splitter `catch_radius` / burrower `kill_radius` convention). The host's code `DEFAULTS` mirror must equal these `params` values byte-for-byte (`test_lobber` pins it, no code/data drift). **`marker_style` and `volley_count` are deliberately NOT shipped as knobs in v1** — see OQ-3 (single honest ring) and OQ-2 (single shell); adding either is a scoped follow-up that expands `MortarCycle`, not a default.

All-off: `lobber.tres` loads only when `&"lobber" ∈ oppositions_enabled` **and** a live deck lists it — the shipped default has neither, so nothing loads (byte-identical baseline). The two spawn-card keys (`base_count`, `count_per_depth`) also carry schema rows (the charger/burrower convention), for **7 total rows** on this def.

> **Host→component fixed flags (not authored knobs — set in `_resolve_params`).** `def_id = &"lobber"`, `emit_family = &"new_hazard_killed"`, `lethal_mode = &"external"`, `latch_rearm = true`, `throw_mode = &"die"`. These are structural to "this def is a Lobber," matching how the bomb/charger fix their seam flags internally (`bomb_hazard.gd:84-88`). `blast_radius` is consumed by `MortarCycle`'s own distance test (NOT `LethalContact`'s — `&"external"` ignores the component's `_blast_radius`), so it maps to `MortarCycle`, not the kill block.

### 2.2 The `MortarCycle` component — the ONE new artefact

`MortarCycle` is a small `class_name`-typed `OppositionComponent` (rides the S2 base contract — host-owned child `Node`, no `_physics_process` of its own; the host calls `tick(delta)` in fixed order). It owns **only**: (a) the fire-period FSM + its accumulator, (b) target selection (live player position + optional velocity lead) at fire time, (c) the world-positioned landing marker (position + `arc_time` reveal/growth), (d) the marker-vs-player blast distance test at IMPACT, fed to the reused `LethalContact` `&"external"` seam. It **never** moves the host (the Lobber is static — §2.6), toggles collision/group membership (the Lobber is always a valid target), runs a body-contact test, or emits telemetry (the host does, off the state hook). Illustrative, against the real base contract + the `BurrowCycle` `lethal:`/`on_state_changed:` idiom:

```gdscript
class_name MortarCycle
extends OppositionComponent
## MortarCycle (U2a, M1.11) — the ONE new component of the Lobber proof: the first
## INDIRECT, player-targeted, area-of-effect threat on a flight-time telegraph (all 9
## shipped defs are contact-lethal). A fire-period FSM that arcs a shell onto the
## player's ground position, IGNORING geometry (cover never protects — moving does):
##   AIM (fire_period_s)  → read live player pos (+ optional velocity lead), LOCK the
##                          landing marker, reveal it
##   IN-FLIGHT (arc_time_s)→ marker shown + frozen (the dodge window); NON-LETHAL
##   IMPACT (one frame)   → hit = marker_pos.distance_to(player) <= blast_radius, fed
##                          to the REUSED LethalContact &"external" (emit-always + L5
##                          kills gate + BUG6 latch); then re-arm and cycle to AIM.
## Everything else is REUSED: kill/telemetry = LethalContact &"external"; fire tell =
## TelegraphFSM; throw death = ThrowInteraction &"die". RNG-FREE; the FSM is run-state
## (delta-driven, reads the live player) and NEVER feeds fingerprint().

enum Phase { AIM, IN_FLIGHT }

## Reused seams, assigned by the HOST at _ready (the BurrowCycle idiom).
var lethal: LethalContact = null            # &"external" gated kill sink
var on_state_changed: Callable = Callable() # host paints tells + emits the S0 rows here
## The world-positioned landing marker root (a top_level Node2D so its transform is
## world-absolute, independent of the host). Assigned by the host from its $MarkerRoot.
var marker_root: Node2D = null
var marker_ring: Polygon2D = null           # the ring drawn at blast_radius (the telegraph)

# --- snapshotted knobs (bound once via _configure; never re-read mid-run) ---------
var _fire_period := 0.0
var _arc_time := 0.0
var _blast_radius := 0.0
var _lead_factor := 0.0

# --- run-state --------------------------------------------------------------------
var _phase: int = Phase.AIM
var _t := 0.0                               # time-in-phase
var _fire_offset := 0.0                     # per-instance cadence desync (deterministic, §5)
var _marker_pos := Vector2.ZERO             # the FROZEN landing point (locked at fire)
var _prev_player_pos := Vector2.ZERO        # for a decoupled finite-difference velocity


func _configure(p: Dictionary, _ctx: Dictionary) -> void:
    _fire_period = maxf(float(p.get("fire_period_s", 0.0)), 0.01)
    _arc_time = maxf(float(p.get("arc_time_s", 0.0)), 0.0)
    _blast_radius = maxf(float(p.get("blast_radius", 0.0)), 0.0)
    _lead_factor = clampf(float(p.get("lead_factor", 0.0)), 0.0, 4.0)
    # Per-instance cadence desync: a PURE function of the host's spawn position (which is
    # a deterministic function of seed+config), NO RNG. Co-located Lobbers never fire in
    # unison. (§5 — zero shared-file edit: does NOT need a legacy_ctx &"lobber" case.)
    var hp := host.global_position
    _fire_offset = fmod(absf(hp.x * 0.6180339887 + hp.y * 0.4142135624), 1.0) * _fire_period
    _phase = Phase.AIM
    _t = _fire_offset
    _prev_player_pos = player.global_position if player != null else Vector2.ZERO
    _size_marker(_blast_radius)
    _hide_marker()


## Called by the HOST each physics frame (fixed order; components never self-tick).
func tick(delta: float) -> void:
    if host == null or player == null:
        return
    _t += delta
    match _phase:
        Phase.AIM:
            if _t >= _fire_period:
                _fire()                          # capture + lock the marker, reveal it
                _enter(Phase.IN_FLIGHT)
        Phase.IN_FLIGHT:
            # Marker is FROZEN (locked at fire). Grow the inner fill toward impact for
            # readability — pure juice; the accumulator drives the actual IMPACT.
            _grow_marker(clampf(_t / maxf(_arc_time, 0.0001), 0.0, 1.0))
            if _t >= _arc_time:
                _impact()                        # the ONE-frame blast distance test
                _hide_marker()
                if lethal != null:
                    lethal.apply_contact(false, true)   # falling edge → re-arm next shell
                _enter(Phase.AIM)
    _prev_player_pos = player.global_position


## AIM→IN-FLIGHT: read the LIVE player pos, optionally lead by measured velocity, LOCK
## the marker at that world point (frozen for the whole flight — the dodge contract).
func _fire() -> void:
    var vel := (player.global_position - _prev_player_pos)   # decoupled finite-difference
    # (frame-normalised lead: velocity/frame → per-second via 1/last_delta is avoidable —
    #  keep lead in the same units the host uses; the programmer picks px/s vs px/frame and
    #  the schema gloss states it. Default lead_factor 0 makes this moot for v1.)
    _marker_pos = player.global_position + vel * _lead_factor
    if marker_root != null:
        marker_root.global_position = _marker_pos            # top_level → world-absolute
    _show_marker()


## IMPACT (one frame): geometry-IGNORING distance test at the frozen marker vs the LIVE
## player. Fed to the reused LethalContact &"external" — emit-always + L5 kills gate +
## BUG6 latch fire exactly once on the rising edge. NO raycast / LOS / occlusion: a wall
## between marker and player changes nothing (the Lobber's identity).
func _impact() -> void:
    if lethal == null or _blast_radius <= 0.0:
        return
    var hit: bool = _marker_pos.distance_to(player.global_position) <= _blast_radius
    lethal.apply_contact(hit, true)


func get_phase() -> int:
    return _phase


func _enter(next: int) -> void:
    _phase = next
    _t = 0.0
    if on_state_changed.is_valid():
        on_state_changed.call(next)

# --- marker presentation (greybox; headless-safe — the accumulator carries the state) --
func _size_marker(r: float) -> void: ...    # draw marker_ring polygon at radius r (bomb idiom)
func _show_marker() -> void: ...            # marker_root.visible = true
func _hide_marker() -> void: ...            # marker_root.visible = false
func _grow_marker(t: float) -> void: ...    # lerp inner-fill alpha/scale 0→1 over the flight
```

**Host wiring + orchestration** (`lobber_hazard.gd`, mirroring `bomb_hazard.gd`/`burrower_hazard.gd`; the host is the honest per-def cost):

```gdscript
class_name LobberHazard
extends CharacterBody2D
## LobberHazard — "The Mortar" (U2a, M1.11). A slow/static sheller that arcs a shell
## onto where you stand: AIM → lock a ground marker at your feet → after arc_time the
## blast tests that spot → cycle. The arc IGNORES geometry (cover never protects — the
## whole point; the Sentry is why cover matters, the Lobber is why you can't camp it).
## S2 Actor-host skeleton verbatim; the behaviour is the reused component set + the ONE
## new MortarCycle:
##   LethalContact(&"external" blast kill) + ThrowInteraction(&"die" — silence the rain)
##   + TelegraphFSM(fire tell) + MortarCycle(target+marker+delayed blast — NEW).
## The BODY is NOT contact-lethal — only shells kill (exploration's low-threat body).
## Collision: layer hazard(16), mask world(2) — ALWAYS a valid throw target (no hiding).
## id &"lobber". Ships OFF-default (min_band=4, in no lever/preset/shallow deck) → this
## scene is NEVER loaded with the shipped default (all-off fp e943ac9c8bc1 holds).
## Never touches the global RNG autoload.

const DEFAULTS := {           # MUST mirror lobber.tres params (test_lobber pins it)
    "fire_period_s": 2.5, "arc_time_s": 0.9, "blast_radius": 48.0,
    "lead_factor": 0.0, "kills": true,
}
const COLOR_IDLE := Color(0.55, 0.5, 0.45)        # dormant sheller
const COLOR_FIRING := Color(0.95, 0.6, 0.2)       # amber — "a shell is up"
const COLOR_MARKER := Color(0.95, 0.35, 0.15, 0.5) # the ground ring / danger zone

var _cfg: RunConfig
var _player: Node2D
var _spawn_time := 0.0
var _lethal: LethalContact = null
var _throw: ThrowInteraction = null
var _fsm: TelegraphFSM = null
var _mortar: MortarCycle = null
@onready var _body: Polygon2D = $Body                 # the sheller silhouette (fire tell)
@onready var _marker_root: Node2D = $MarkerRoot       # top_level = true (world-absolute)
@onready var _marker_ring: Polygon2D = $MarkerRoot/Ring


func _ready() -> void:
    _lethal = OppositionComponent.acquire(self, LethalContact) as LethalContact
    _throw = OppositionComponent.acquire(self, ThrowInteraction) as ThrowInteraction
    _fsm = OppositionComponent.acquire(self, TelegraphFSM) as TelegraphFSM
    _mortar = OppositionComponent.acquire(self, MortarCycle) as MortarCycle
    _fsm.tell = _body                    # the fire-tell colour flip plays on the BODY
    _mortar.lethal = _lethal             # reused &"external"-mode kill machinery
    _mortar.marker_root = _marker_root
    _mortar.marker_ring = _marker_ring
    _mortar.on_state_changed = _on_phase


func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
    _cfg = cfg
    _player = player
    _spawn_time = 0.0
    var p := _resolve_params(spawn_ctx)
    _lethal.bind(self, player, p, spawn_ctx)   # resets the BUG6 latch (re-setup safe)
    _throw.bind(self, player, p, spawn_ctx)
    _fsm.bind(self, player, p, spawn_ctx)
    _mortar.bind(self, player, p, spawn_ctx)   # seats AIM (marker hidden, offset applied)
    _set_tell_idle()


func _resolve_params(spawn_ctx: Dictionary) -> Dictionary:
    var dp: Dictionary = spawn_ctx.get("params", {})
    var p: Dictionary = {}
    for key: String in DEFAULTS:
        p[key] = dp.get(key, DEFAULTS[key])
    # Reused LethalContact / ThrowInteraction seam flags (the bomb resolve shape).
    p["def_id"] = &"lobber"
    p["emit_family"] = &"new_hazard_killed"
    p["lethal_mode"] = &"external"    # NOT &"on_command" — blast lands away from the body
    p["latch_rearm"] = true
    p["throw_mode"] = &"die"
    return p


func _physics_process(delta: float) -> void:
    if _player == null or _cfg == null or not is_instance_valid(_player):
        return                                 # the family guard, verbatim
    _spawn_time += delta
    _mortar.tick(delta)                        # the fire-period FSM (drives the external seam)
    # No body movement (static sheller). MortarCycle owns the marker; the body is inert.


func run_clock_ms() -> int:
    return int(_spawn_time * 1000.0)

func get_def_id() -> StringName:
    return &"lobber"

func resolve_throw_death(killer_ctx: Dictionary) -> bool:
    return _throw.resolve_throw_death(killer_ctx)   # &"die" → false → thrower frees us

func phase() -> int:
    return _mortar.get_phase()


## MortarCycle transition hook: the fire tell + the S0-LOCKED telemetry vocabulary.
## &"telegraph" = a shell is fired (the marker appears — the wind-up); &"state" = impact
## (the cycle beat). The emit-always &"hit_player" + the gated opposition_killed_player
## live in the reused LethalContact; &"spawned" is the service's; &"killed_by_throw" the
## ThrownItem path's. No new EventBus signal, no new end-cause.
func _on_phase(next: int) -> void:
    var depth: int = GameState.current_depth_index    # live within-band depth (BUG2)
    var run_t_ms: int = run_clock_ms()
    match next:
        MortarCycle.Phase.IN_FLIGHT:                  # a shell is up: fire tell + marker shown
            _set_tell_firing()
            EventBus.opposition_event.emit(&"lobber", &"telegraph", depth, run_t_ms)
        MortarCycle.Phase.AIM:                        # impact resolved → back to ranging
            _set_tell_idle()
            EventBus.opposition_event.emit(&"lobber", &"state", depth, run_t_ms)
```

Notes for the programmer:
- **`LethalContact` untouched.** The blast rides `&"external"`: `MortarCycle` computes the marker-vs-player boolean and calls `apply_contact(hit, true)` at IMPACT, then `apply_contact(false, true)` on the cycle to re-arm — the `BurrowCycle`/`ChargeLane` falling-edge idiom. **Do NOT use `&"on_command"`** — its `command_hit()` tests `host.global_position` (`lethal_contact.gd:113-115`), which is the *Lobber body*, not the marker.
- **The marker is `top_level`.** `$MarkerRoot.top_level = true` in the scene, so setting its `global_position` places it at the world landing point regardless of the (static) host transform. It is a child of the host scene, so it frees with the host on run-end / throw-kill (run-state hygiene).
- **Telemetry vocabulary is S0's LOCKED set** (`&"spawned"` (service) / `&"telegraph"` (fire) / `&"state"` (impact) / `&"hit_player"` (LethalContact) / `&"killed_by_throw"` (ThrowInteraction)) + the gated `opposition_killed_player`. No new token, no `event_bus.gd` edit — identical to the burrower's discipline (`test_burrower` pins the vocabulary `[&"telegraph", &"state", &"hit_player"]`).

### 2.3 The fire-period FSM (the two-phase cycle)

Two phases, cycling forever. All timing is a host-driven accumulator inside `MortarCycle` (the `BurrowCycle`/`ChargeLane` pattern — the component owns its FSM clock; `TelegraphFSM` owns only presentation):

| Phase | Duration | Marker | `LethalContact` | Body |
|---|---|---|---|---|
| **AIM** | `fire_period_s` | hidden | `apply_contact(false)` (armed, non-lethal) | idle tell; throw-killable |
| **IN-FLIGHT** | `arc_time_s` | shown + **frozen** at the fire-time landing point; inner fill grows | non-lethal — **the dodge window** | firing tell; throw-killable |
| **IMPACT** | one frame (the last frame of IN-FLIGHT) | blast test at the frozen marker | `apply_contact(hit, true)` — emit-always + L5 gate + BUG6 latch | — |

On the IMPACT→AIM edge the component calls `lethal.apply_contact(false, true)` to re-arm the BUG6 latch on the falling edge (`charge_lane.gd:139` idiom), so the *next* shell can catch cleanly. A throw-kill during either phase frees the host mid-cycle (§2.4) — the rain stops.

### 2.4 Kill + throw semantics (M1 lethality model; reused components)

- **Only the blast is lethal, and only at IMPACT.** The marker-vs-player distance test feeds `LethalContact` `&"external"` at the one IMPACT frame: emit-always `&"hit_player"`, `kills`-gated `fail_run(&"death")`, BUG6 one-shot latch. AIM and IN-FLIGHT run no lethal test. **The Lobber body is never contact-lethal** — walking into the Lobber is safe (the exploration's "slow, low-threat" body). This is deliberate: it makes the Lobber a pure spatial-pressure piece distinct from every contact-lethal sibling, and it means the host needs *no* body-contact `LethalContact` mode at all — the `&"external"` seam is the only lethality.
- **`kills = false`** → the blast emits `&"hit_player"` but never `fail_run` — proves the per-def toggle (deck-sweepable). No new end-cause.
- **Centre-in-radius blast (the bomb precedent).** `hit = marker_pos.distance_to(player.global_position) <= blast_radius` — the player's *centre* must clear the ring, matching `LethalContact.command_hit` (`lethal_contact.gd:114-115`, no player-radius term). The marker ring is drawn at exactly `blast_radius`, so the contract is honest: "get your centre out of the circle." A player whose centre sits exactly on the ring at IMPACT is killed (`<=`) — clear it fully. (Whether to add the player radius for a body-touches-ring test is OQ-3.)
- **Always a valid throw target (silence the rain).** The Lobber stays on `collision_layer 16` + in the `"hazard"` group for its whole life — unlike the ambusher/burrower it never hides — so a thrown item can always reach it. `ThrowInteraction` `&"die"` → `resolve_throw_death` returns `false` → the thrower frees it, ending the rain. Because the Lobber is "slow and low-threat," **spending an item to kill it vs. just moving is a judgment call** (the exploration's design intent — often ignoring it while you keep moving is correct). `thrown_item.gd` untouched.

### 2.5 Spawn / placement rules (builder + service — no U2a placement code)

Placed by the **default `EncounterBuilder`** from `band_four`'s deck through the **`SpawnService`**, exactly like every opposition — U2a adds **no** placement code:

- **Eligibility:** in the deck iff `band.band_depth >= lobber.min_band` (=4). `band_four` (`band_depth=4`) lists it (U3); bands 1–3 do not → open-field-native for M1.11 (breakdown OQ8; OQ-7 here).
- **Budget:** `credit_cost = 2` debited from the builder's `I`-scaled band budget. `instability(4) = 1.0 + 0.15·3 = 1.45`; `floor(BASE_CREDITS(24) · 1.45) = floor(34.8) = ` **34 credits** for band 4 (`encounter_builder.gd:64-65,299` — U3 pins the exact deterministic deck outcome per the D-RAT-6 pattern).
- **Caps (service-enforced):** `per_room_cap = 1`, `per_band_cap = 3`; the minimum binds; global `NEW_HAZARD_BAND_CEILING = 48` last-resort (`spawn_service.gd:43`).
- **Determinism:** placement cell is the builder's stable RNG-free even-spread stride (`encounter_builder.gd:_populate_deck`); the fire cadence + landing point are run-state (delta-driven, live player), never fed to `fingerprint()`. Same seed + config → same Lobber cells; per-instance cadence desync is a pure function of the spawn position (§5).
- **No loot-coupling.** The exploration wants Lobbers to tax the pause at loot, but there is **no params-only coupling** between `JunkPlacer` and `EncounterBuilder` today — a true bias needs a builder edit (forbidden by the "no `EncounterBuilder` edit" guardrail). **Recommendation: standard even-spread placement** — the open arena's long sightlines already deliver "you're exposed wherever you pause"; explicit loot-coupling is a flagged follow-up if UG2 asks (the T2a Burrower OQ-6 precedent).

### 2.6 Movement — static (no movement component)

The Lobber is **static** (the exploration's "static or slow-drifting square"; recommend static for greybox). This is load-bearing for the "ONE component" guardrail: adding drift would need a *second* component (`PatrolMove`/`StraightBounceMove`), breaking the def+one-component proof. A static sheller reads perfectly in the open field (it doesn't need to reposition — its arc reaches everywhere), and "keep the feet moving" is the player's job, not the Lobber's. Optional slow drift is a scoped follow-up (a second component) if UG2 finds static too passive — flag, don't build.

### 2.7 Telemetry

Emits **only** S0-pre-declared generic signals via reused components — no lobber-specific signal, no `event_bus.gd` edit:

| Signal | When | Emitter |
|---|---|---|
| `opposition_event(&"lobber", &"spawned", …)` | on spawn | **SpawnService** (central) |
| `opposition_event(&"lobber", &"telegraph", …)` | a shell is fired (AIM→IN-FLIGHT; marker appears) | host `_on_phase(IN_FLIGHT)` |
| `opposition_event(&"lobber", &"state", …)` | impact resolved (IN-FLIGHT→AIM) | host `_on_phase(AIM)` |
| `opposition_event(&"lobber", &"hit_player", …)` | lethal blast contact (emit-always, even if `kills=false`) | reused **LethalContact** (BUG6-latched) |
| `opposition_event(&"lobber", &"killed_by_throw", …)` | throw-kill (def-id-stable) | reused **ThrowInteraction** / ThrownItem |
| `opposition_killed_player(&"lobber", …)` | gated — only when `kills` fires `fail_run` | reused **LethalContact** |
| `run_ended(reason=&"death", …)` | fatal blast contact | `GameState.fail_run(&"death")` |

`&"telegraph"` (shell fired) + `&"hit_player"` (blast landed on you) + its absence (dodged) let UG2 measure "did players read the marker" — deaths-per-first-encounter vs the Ambusher/Burrower/Wrecker baselines (breakdown UG2). With the Lobber off, none of these rows appear (no node exists).

---

## 3. Definition of done (concrete — the acceptance bar)

Restated from the breakdown's §U2a DoD, with the tests U2a adds (`tests/test_lobber.gd` + `.tscn`, run **as a scene** per the headless-test convention — `godot --headless --path Game res://tests/test_lobber.tscn`). The shape mirrors `test_burrower.gd`.

1. **All-off fp unmoved.** With the shipped default (`&"lobber" ∉ oppositions_enabled`, not in the default play preset, not in band 1/2/3 decks), **no `lobber.tres` loads, no node spawns**, and the all-off fingerprint **`e943ac9c8bc1`** is byte-identical.
2. **`params`↔`param_schema` bijection (count-agnostic).** `lobber.tres` passes the per-def coverage assertion + the Python `.tres` linter — every `params` key has exactly one `param_schema` entry and vice-versa, all within declared min/max; entity params mirror `LobberHazard.DEFAULTS` exactly (no code/data drift). **No global def-count hard-assert** (U2a is 9→10, U2b 10→11 in the same wave — the amendment-8 lesson).
3. **Menu section auto-appears.** With `&"lobber"` loaded, the generated debug-menu builds a Lobber collapsible section from `param_schema` headlessly (no hand-authored rows).
4. **`test_lobber` (headless scene) asserts:**
   - **(a) Def contract.** `lobber.tres` loads as `OppositionDef`; `id == &"lobber"`; card (`min_band=4`, `credit_cost=2`, `cap_group=&"new_hazards"`, `per_room_cap=1`, `per_band_cap=3`, `kills`); `params` mirror `LobberHazard.DEFAULTS` (+ only `base_count`/`count_per_depth` beyond the entity keys); host contract (root `LobberHazard`, `get_def_id()==&"lobber"`, `resolve_throw_death` present, in `&"hazard"` group at author time); `$Body` + `$MarkerRoot/Ring` polygons triangulate to >0 triangles (the invisible-hazard guard).
   - **(b) Cycle timing from params.** With fast-cycle knobs, `phase()` holds AIM ~`fire_period_s`, then IN-FLIGHT ~`arc_time_s`, then AIM again. Telemetry: exactly one `&"telegraph"` per shell + `&"state"` on impact; **no out-of-vocabulary `opposition_event` token** (S0 locked set `[&"telegraph", &"state", &"hit_player"]`).
   - **(c) Marker precedes impact by `arc_time` (the fairness bar).** From the `&"telegraph"` row (shell fired) to the blast test is ~`arc_time_s`; the marker is visible for that whole window; the blast test runs **only** at IMPACT — a player standing on the marker through IN-FLIGHT but who steps `> blast_radius` from the **frozen** marker point *before* the last frame is **not** killed (`run_active` true, no `&"hit_player"`). A player who **stays** on the frozen point through IMPACT **is** killed — the warning was honoured.
   - **(d) Blast kill gated + inside-radius only.** `kills=true`, player centre within `blast_radius` of the marker at IMPACT → `fail_run(&"death")` (`GameState.run_active` false, cause `&"death"`) + `opposition_killed_player(&"lobber")` **exactly once** (BUG6) + one `&"hit_player"`. Player centre **outside** `blast_radius` at IMPACT → no kill, no `&"hit_player"`. `kills=false`, same inside geometry → `&"hit_player"` fires but run stays active, no `opposition_killed_player`.
   - **(e) Geometry-ignoring across a wall.** A `world`-layer wall between the Lobber and the player: the marker still locks onto the player's position and the blast still kills a player standing on it at IMPACT (no LOS/occlusion check) — assert the shell ignores the wall (the Lobber's identity). Contrast the burrower's *wall-crossing* test — here nothing crosses; the *effect* simply doesn't consult geometry.
   - **(f) Fire-period cycle.** After an impact, the Lobber returns to AIM and fires again after ~`fire_period_s`; assert ≥2 `&"telegraph"` rows over a multi-cycle run (the rain continues).
   - **(g) Throw-killable.** A `ThrownItem` at the Lobber body → `throw_killed_hazard(&"lobber")`/`&"killed_by_throw"`, the Lobber `queue_free`s, and no further `&"telegraph"` rows appear (the rain stops).
   - **(h) Params flow def < DeckEntry < rc.param_overrides.** Through the REAL `EncounterBuilder._effective_params`: `lobber.tres` `fire_period_s` is overridden by a `DeckEntry.param_overrides`, which is in turn overridden by `rc.param_overrides[&"lobber"]` — assert the entity's effective `fire_period_s` is the rc value (the locked precedence, `encounter_builder.gd:437-451`).
   - **(i) Deterministic placement + caps.** The same synthetic band + deck twice through the REAL `EncounterBuilder` + `SpawnService` yields identical Lobber spawn cells; `per_band_cap = 3` binds; `min_band = 4` refuses a band-depth-3 profile entirely.
   - **(j) Cadence desync (deterministic).** Two Lobbers at **different** spawn positions fire on **different** frames (positional offset); the same position twice → identical cadence (deterministic, no RNG).
   - **(k) No global RNG.** `mortar_cycle.gd` + `lobber_hazard.gd` sources contain no `RNG.` reference (the determinism audit; `test_burrower` case-9 shape).
5. **Process:** a U2a worklog names the real commit SHA(s) for the programmer + character-animator contributions; `godot --headless --path Game --import` compiles the new scene/script/tres; the smoke test is green; the worklog's **Bespoke-code ledger** records the exact non-data, non-test line counts (§4) and the **Design deviations** section records any departure (or "none") for the Wave-1 close-out sweep.

---

## 4. Bespoke-code cost-ledger prediction (the UG3 scalability evidence)

The breakdown makes the cost ledger version-defining (the N=3 trend). **Predicted** U2a spend beyond the promised `def + ONE component`:

| Artefact | Kind | Predicted | In the "def + one component" budget? |
|---|---|---|---|
| `data/oppositions/lobber.tres` | data | ~1 resource | Yes — the point |
| `scenes/hazards/components/mortar_cycle.gd` | **new component code** | **~90–120 lines** | **Yes — the ONE new component** |
| `scenes/hazards/lobber_hazard.gd` | host shell code | ~120–150 lines | **Expected honest per-def cost** (each def ships its own Actor host; NOT a new *behaviour* script) |
| `scenes/hazards/lobber.tscn` | scene | 1 | Expected (host + body + marker root/ring + collision) |
| `tests/test_lobber.gd` + `.tscn` | test | ~500 lines | Excluded from the ledger (test code) |
| `ui/config/config_strings.csv` `CFG_FIELD_LOBBER_*` rows | data (orchestrator-applied at merge) | ~7 rows | Yes — data |

**Predicted edits to shared/reused files: ZERO.** `lethal_contact.gd`, `throw_interaction.gd`, `telegraph_fsm.gd`, `thrown_item.gd`, `encounter_builder.gd`, `spawn_service.gd`, `event_bus.gd` all untouched. **If any is touched, that is the ledger's headline overspend and a flagged deviation** — the one risk point to watch:
- **Cadence desync source.** §5 derives the per-instance fire offset from the host spawn position (zero shared edit). If that proves insufficient (e.g. two Lobbers on the same cell — impossible under the even-spread stride, but if it ever arose), the alternative is a `&"lobber"` case in `EncounterBuilder.legacy_ctx` stamping a `phase_salt` (the spike/burrower idiom) — a **shared-file edit** to `encounter_builder.gd`. *Predicted: not needed* (position is a deterministic, per-instance-unique key under the stride). If used, record it in the ledger as the overspend.

Net predicted honest cost of adding this opposition: **one ~100-line component + one host shell + data + a test** — the same shape the Ambusher/Burrower proved, now on the *indirect-AoE* axis, with no engine rework. If M1.10's Ambusher/Burrower came in at this shape and the Lobber matches or undercuts it, that IS the "content = data is compounding" evidence UG3 judges.

---

## 5. Determinism / desync notes (RNG-free cadence)

- **Placement** is generation-time, seed-deterministic — `EncounterBuilder._populate_deck` walks pieces in the stable RNG-free even-spread order and strides cells; the Lobber is placed identically to every other new def. It feeds nothing to `fingerprint()`.
- **Fire cadence** must be deterministic-yet-desynced so co-located Lobbers don't all fire in unison (marker-soup). Unlike the spike (which `legacy_ctx` stamps a `phase_salt` for) and the pingpong (which gets `initial_dir`), a `&"lobber"` kind gets the **empty** ctx from `legacy_ctx` (`encounter_builder.gd:120-121`, the default arm). Rather than edit that shared file to add a `&"lobber"` case, `MortarCycle` derives its fire offset from the **host's spawn `global_position`** — a pure irrational-multiplier hash (`fmod(|x·φ⁻¹ + y·√2⁻¹|, 1) · fire_period`), **no `RNG`**. The position is `cell_to_world(cell)` of an integer cell (deterministic exact floats), and the even-spread stride guarantees distinct cells per instance, so two Lobbers desync deterministically; the same seed+config reproduces the same offsets. This is the burrower's positional-desync approach (`test_burrower` case-10), applied without any shared-file edit.
- **The real-time FSM is *not* frame-deterministic across machines** — and that is correct: it's run-state, never hashed. `test_lobber` asserts timing within frame tolerances (the `test_burrower` convention), never exact equality, and asserts *relative* desync (two positions → different fire frames), not an absolute schedule.

---

## Open Questions

> Each stated with trade-offs for Phase-3 fresh-eyes resolution. Genuine **fun/fairness/tone/scope calls are flagged `**NEEDS DIRECTOR REVIEW**`** with a recommendation — the resolver does not self-decide those.

### OQ-1 — `**NEEDS DIRECTOR REVIEW**` (fun/difficulty) — Lead the player or land on current position? (breakdown OQ5)
`lead_factor` defaults to **0.0** (lands where you stand). No-lead is fair and readable but "trivially countered by walking" (exploration); a small lead makes movement-prediction a skill but "can feel unfair when the lead is wrong." *Director question:* **Ship `lead_factor = 0` for the first playtest and let UG2 decide whether to introduce a small band-scaled lead — or start with a small lead now?** *Recommendation:* **ship `lead_factor = 0`** (learn the verb clean; the exploration's explicit "recommend no/small lead first"), treat deaths-per-first-encounter at UG2 as the fairness read, and dial a small lead up if the Lobber reads as trivially walkable. The knob exists (0.0–1.0) for a one-value sweep with no code change. *Director ratifies; UG2 evidence drives the sweep.*

### OQ-2 — `**NEEDS DIRECTOR REVIEW**` (fun/scope) — Single shell or a volley? (exploration "One Lobber or volleys?")
v1 ships a **single shell per cycle**. A 2–3 shell volley with staggered markers is "the real keep-moving pressure but risks marker-soup" (exploration). A volley means `MortarCycle` fires N markers with staggered fire/arc offsets and N blast tests — meaningfully more component code and a `volley_count` param (deliberately **not** in the v1 schema, §2.1). *Director question:* **Single shell for M1.11 (learn the verb), volley deferred to a post-gate follow-up — or is a small volley in scope now?** *Recommendation:* **single shell** — it teaches the verb cleanly, keeps `MortarCycle` minimal (the def+one-component proof), and a co-located pair of single-shell Lobbers already delivers overlapping pressure without one component modelling a barrage. Add `volley_count` as a scoped follow-up if UG2 finds single shells too sparse. *Director decides whether volley is in-scope at all.*

### OQ-3 — `**NEEDS DIRECTOR REVIEW**` (fun/fairness) — Marker readability: exact edge vs soft edge; does standing at the rim kill?
The marker ring is drawn at exactly `blast_radius` and the test is **centre-in-radius** (`<=`, the bomb precedent), so a player whose *centre* is on the ring at IMPACT is killed. Alternatives: (i) draw the ring at `blast_radius` but test `distance <= blast_radius + player_r` (kill if the *body* touches the ring — harsher, but "if the circle touches me I die" is intuitive); (ii) draw the ring slightly *larger* than the lethal radius (a visible safety margin — more forgiving). *Director question:* **Keep the honest centre-in-radius contract (ring == lethal radius, clear your centre) or add a player-radius margin (either direction)?** *Recommendation:* **centre-in-radius, ring == `blast_radius`** — it matches the bomb's shipped semantics (one consistent AoE contract across the game), is more forgiving than a body-touch test, and "get your centre out of the circle" is a clean rule. Revisit at UG2 if players report rim deaths as unfair. *Director ratifies.*

### OQ-4 — Can it target across the whole arena, or is there a max range? (technical/fun)
v1 has **no max range** — a Lobber reads the live player position and lobs, wherever the player is. In the open field this is the identity (it shells you across the whole space; you can't out-distance it, only keep moving). The alternative is a `max_range` knob (the Lobber only fires when the player is within N px), which would create safe "out of artillery range" zones. *Director question (secondary — recommend resolver decides on merit unless the Director wants safe zones):* keep global reach (recommended — it's the open-field anti-camping identity, and the arena isn't large enough for range-management to be interesting), or add `max_range`? *Recommendation:* **global reach, no `max_range`** — the whole point is that there is nowhere still to stand; a range knob re-introduces camping spots. *Technical/fun — resolver sets "global"; Director may fund `max_range` later if the arena grows.*

### OQ-5 — Does it fire while off-screen / far from the player? (technical/fun)
Coupled to OQ-4: with global reach and no LOS, a Lobber keeps its cadence running whether or not the player can see it — so a shell can arrive from an unseen emitter. In the open field the player can almost always *see* the Lobber (long sightlines — the whole reason the pair is authored here), so this is rarely felt; but a Lobber behind a cover block still shells you (geometry-ignoring). *Director question:* is "shelled by a Lobber you can't currently see" acceptable (recommended — the marker still telegraphs fairly at your feet, so the *kill* is always fair even if the *source* is unseen), or should the Lobber only fire with LOS to the player (needs occlusion the engine lacks)? *Recommendation:* **fire regardless of LOS** — the fairness lives in the marker+`arc_time` at the player's feet, not in seeing the emitter; LOS-gating needs occlusion the engine doesn't have and would blunt the geometry-ignoring identity. The open field's sightlines make the source visible in practice anyway. *Fun — resolver recommends; Director may weigh the "shelled from nowhere" feel at UG2.*

### OQ-6 — `**NEEDS DIRECTOR REVIEW**` (tone) — Band-4 fiction/name (2–3 pitches, §1.6)
`display_name` "The Mortar" (A) vs "Spitter"/"Bombardier" (B) vs "The Tithe"/place-read (C). The mechanical `id` stays `&"lobber"` regardless (telemetry/tests name-stable). *Recommendation:* **(A) The Mortar** — tightest to the junkyard-machine fiction and the clearest "a machine is ranging me" telegraph; (C) if the Director wants the open-field "the place is the enemy" theme front-loaded. This dovetails with U3's band-4 identity pitch. *Tone — Director picks (coordinate with U3's band identity + U4's portal hue).*

### OQ-7 — `**NEEDS DIRECTOR REVIEW**` (scope) — Band-4-exclusive for M1.11? (breakdown OQ8)
The breakdown (OQ8) recommends both new oppositions be **band-4-exclusive** in M1.11 for a clean A/B at UG2 (the D-RAT-4 precedent). §2.1 encodes this via `min_band = 4` + deck membership. *Director question:* **Confirm the Lobber stays band-4-native for M1.11, or should it also enter a shallower deck?** *Recommendation:* **band-4-native** (clean measurement; the open field is where the geometry-ignoring arc reads fair). Promotion later is a one-field `min_band` edit + a deck add — a UG3 watch-item ("do Lobber/Sentry enter other decks — a Lobber in a socket band's corridors?"). *Director confirms at the gate.*

### OQ-8 — Blast friendly-fire on other hazards? (technical)
The blast is a distance test **against the player only** — it never tests other opposition nodes, so a shell landing on a Sentry/Burrower/junk does nothing to them. *Recommendation:* **player-only blast** (no hazard-vs-hazard friendly fire) — it matches every shipped hazard (none damage each other), keeps the test cheap and deterministic, and hazard-vs-hazard interactions are an unowned design space (out of scope for a def+one-component proof). *Technical — resolver confirms "player-only"; no Director call needed unless friendly-fire is later wanted as a mechanic.*

### OQ-9 — Cadence desync without a shared-file edit (technical, §5)
§5 derives the fire offset from the host spawn position (zero shared edit) rather than adding a `&"lobber"` case to `EncounterBuilder.legacy_ctx` (which only stamps `phase_salt` for `&"spike"`). *Recommendation:* **position-derived offset** — deterministic, per-instance-unique under the even-spread stride, and keeps `encounter_builder.gd` untouched (the ledger's zero-shared-edit target). If a resolver finds a case where two Lobbers share a cell (shouldn't happen under the stride), escalate to the `legacy_ctx` `phase_salt` route and record the shared edit in the ledger. *Technical — resolver confirms on merit.*

---

*Phase 3 (fresh eyes, NOT this author) resolves the Open Questions into a `Resolved Decisions` section, flagging OQ-1 / OQ-2 / OQ-3 / OQ-6 / OQ-7 (fun/fairness/scope/tone) for the Director per the orchestrator loop, and confirming OQ-4/5/8/9 on merit. Design-only — no code, no `.tres`. The programmer + character-animator build against this; deviations from the committed design go to `DESIGN_DEVIATIONS.md` for the Wave-1 close-out sweep, and the worklog carries the Bespoke-code ledger (§4) that UG3 judges.*
