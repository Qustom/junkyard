# L0 — Foundation: knob + signal pre-declare · Phase-2 Design

**Task:** L0 (M1.5 Wave 1, lands first, alongside L3 + L4). **Role:** general-purpose (programmer).
**Blocks:** L1 (reads throw knobs, emits throw signals), L2 (reads the spawn-room knob, emits a pursuer-state signal), L5 (reads the three `*_kills` knobs).
**BlockedBy:** none.
**Authored:** 2026-06-24, Phase 2 of the four-phase process (`CLAUDE.md`), from `design/M1_5_Tasks/M1.5_Breakdown.md` §3 (L0 row), §6 (carried contracts), §7 (open risks). Mirrors the proven M1.4 K0 prior art (`design/M1_4_Tasks/K0_foundation_knobs_signals.md`).

> **What this doc IS:** the **knob + signal contract** every other M1.5 build design keys off. L0 is the *single-writer pass*
> over the three shared files (`data/run_config/run_config.gd`, `systems/event_bus.gd`, `ui/config/config_menu.gd`) so no two
> Wave-1/Wave-2 tasks ever edit them in parallel (the M1.1 pre-declare rule, Breakdown §6). The knob/signal set below is a
> **provisional union** assembled from the breakdown's L1/L2/L5 task descriptions + open risks. It will be **refined once the L1
> and L2 Phase-2 designs land** (they cite the exact knob names they read); the Open Questions section flags exactly which
> names/types/arities are still soft. L0's job is to land *off/neutral* placeholders so the all-off control stays byte-identical
> and the build waves never touch these three files again.
>
> **What this doc is NOT:** any behaviour. L0 declares fields + signals + the CFG structural rows + bumps the count tests. It
> wires no throw, no projectile, no selector, no pursuer patrol, no `*_kills` branch. Those are L1/L2/L5. (Same contract K0 held
> for M1.4: "K0 declares fields + signals + the CFG structural rows; those are the consuming tasks' behaviour," K0 §intro.)

---

## (a) Research — the as-built surface L0 extends

### A.1 Why L0 exists (single-writer foundation)

M1.5 has three build tasks that each need to **read a new `RunConfig` knob and/or emit a new `EventBus` signal**: L1 (throw),
L2 (spawn-room pursuer), L5 (K5 per-hazard `*_kills`). All three run in **Wave 2 in parallel** (Breakdown §5). If each task added
its own knob to `run_config.gd`, its own signal to `event_bus.gd`, and its own CFG row to `config_menu.gd`, three parallel
worktrees would all edit the same three files → guaranteed merge conflicts and a real risk of a **double-declared signal** (a
GDScript parse error) or a **mismatched knob-count test**. L0 is the M1.5 application of the M1.1/M1.4 pre-declare rule
(Breakdown §6): **one task writes the three shared files up front, off/neutral, for the whole milestone**, so L1/L2/L5 only
*read knobs* and *emit pre-declared signals* — they never touch the three foundation files again. This is exactly the role K0
played for M1.4 (`design/M1_4_Tasks/K0_foundation_knobs_signals.md`).

### A.2 `RunConfig` (`data/run_config/run_config.gd`) — the one run-scoped config object

- **Container shape + the hard contract.** `class_name RunConfig extends Resource` (`run_config.gd:1-2`). The class doc
  (`run_config.gd:17-24`) states the load-bearing invariant L0 must preserve: *"ALL-OFF DEFAULT = M1.0 BASELINE … every
  opposition disabled and every magnitude at zero/neutral, so an unconfigured run reproduces the M1.0 loop EXACTLY."* A
  `RunConfig` is **run-scoped configuration, NEVER persisted to SaveManager** (`run_config.gd:12-15`) — so the throw selector
  state, thrown projectiles, and pursuer patrol state are all pure run-state and **no save-schema change is needed in M1.5**
  (Breakdown §2).

- **The `@export_group` + group-prefix pattern.** Each opposition/feature is a group with a shared prefix the CFG menu keys off:
  `@export_group("R1 Pursuing Hazard", "r1_")` (`run_config.gd:57`), `"lvl_"` (`:192`), and the M1.4 additions `"quota_"`
  (`:238`), `"cam_"` (`:258`), `"timer_"` (`:272`), `"hpp_"` (`:288`), `"hbomb_"` (`:305`), `"hspike_"` (`:327`), `"exit_"`
  (`:347`). **Every field in a group starts with the group's prefix.** New M1.5 groups must follow: a new section ⇒ a new prefix
  ⇒ a new `@export_group(..., "<prefix>")` ⇒ a `SECTIONS` + `MANIFEST` entry in `config_menu.gd`.

- **Field kinds already in use** (L0's new knobs reuse exactly these widget-mapped kinds, no new kind):
  - `bool` master toggle, default `false` — `r1_enabled` (`:59`), `hpp_enabled` (`:290`).
  - `int`, default `0` — `r1_spawn_count = 0` (`:81`).
  - `float`, default `0.0` — `r1_chase_speed = 0.0` (`:65`), `hpp_speed = 0.0` (`:296`).
  - `@export_enum("a","b") var x: int = 0` — `quota_check_timing` (`:248`), rendered as an `OptionButton`.
  - **`bool` defaulting `true`** — there is precedent for an off-the-baseline default: see below on `*_kills` (the L5 toggles
    default `true` = today's lethal behaviour). The existing R1 `r1_catch_kills` knob (`:79`) is a `bool` default **`false`**
    (R1's catch is opt-in lethal), so L5's `true` defaults are the **opposite polarity** — the design reason is that the K5
    hazards are *already lethal today*, so the all-off-equivalent for them is `kills=true` (preserving today's behaviour, not
    introducing a new lever). This is the one place an M1.5 knob defaults non-`false`; it is justified below in A.6 and OQ-3.

- **`r1_catch_kills` — the mirror L5 follows.** `@export var r1_catch_kills: bool = false` (`:79`), consumed at
  `hazard_entity.gd:189` (`if _cfg.r1_catch_kills: GameState.fail_run(&"death") else: _apply_nonfatal_catch()`). The L5 toggles
  `hpp_kills`/`hbomb_kills`/`hspike_kills` mirror this exact "kills vs non-lethal" branch shape for the three K5 hazards — but
  default **`true`** (today the K5 hazards have no such branch; they always kill — `spike_hazard.gd:96` calls
  `GameState.fail_run(&"death")` unconditionally; `bomb_hazard.gd:117`; `pingpong_hazard.gd:137`). So `kills=true` reproduces
  today exactly, `kills=false` is the new non-lethal lever L5 unlocks.

- **`to_flat_dict()` (`run_config.gd:410-510`)** — serializes **every** knob to a flat, JSON-safe `Dictionary` for the
  `run_started` telemetry row (additive `data`, *not* a schema bump). Keys are field names; values are JSON primitives. The new
  M1.5 knobs append into grouped comment blocks at the end (after the `exit_*` block, `:504-509`). All M1.5 knobs are scalar
  primitives (bool/int/float) — **no new `PackedFloat32Array`**, so no new `_packed_to_float_array` helper.

- **`all_oppositions_disabled()` (`:384-385`)** — `return not (r1_enabled or r2_enabled or r3_enabled or r4_enabled)`. The K5
  hazard `enabled` flags were deliberately **NOT** added here in M1.4 (K0 RD/OQ-2: the function means "reproduces the M1.0
  *opposition* baseline"). **L0 follows the same rule: `throw_enabled` and `r1_spawn_room_only` are NOT added to this predicate**
  — they are a player-agency lever and a pursuer-behaviour branch, not new oppositions, and they default off/neutral so a fresh
  `RunConfig.new()` is still all-off on every axis regardless. The `*_kills` toggles default `true`, so they are explicitly
  *not* "off" — another reason to keep them out of this predicate (they describe how an *already-enabled* hazard behaves, not
  whether an opposition is on).

- **`inert_enabled_oppositions()` (`:541-568`)** — the BUG6 config-trap detector. **Not L0's to extend with behaviour** — but
  note: a `throw_enabled` run with `throw_speed = 0` would be a dead lever (a throw that never travels). Whether L0 adds a
  `throw_no_speed` trap line is OQ-6; recommendation: L1 (the consumer) owns that trap, like every other consumer added its own.

- **`make_default_play_preset()` (`:606-781`)** — the named preset the CFG rail + no-CFG fallback boot into. Built on a fresh
  `RunConfig.new()` (`:607`) so it NEVER mutates the all-off control. **This is where the M1.5 fun values land** (throw on,
  spawn-room pursuer on) — but **that is L1/L2's edit, NOT L0's.** L0 only declares the knobs at off/neutral code defaults; the
  consuming tasks layer their fun values into the preset (the load-bearing carried contract, Breakdown §6: "fun values live only
  in `make_default_play_preset()`"). The preset ends with `assert(c.inert_enabled_oppositions().is_empty(), …)` (`:778-780`) —
  any preset value L1/L2 add must keep that assert clear.

### A.3 `EventBus` (`systems/event_bus.gd`) — the signal hub

- **Pure wiring, no state** (`:1-6`). The pre-declare discipline is explicit: M1.4's K0 block is headed *"sole event_bus.gd edit
  this milestone, owner = K0 … Pre-declared up front so K2/K3/K4/K5/K7 only EMIT — they never edit this file"* (`:118-123`).
  **L0 is the M1.5 application of exactly this rule** — L0 adds one new M1.5 block and is the **sole `event_bus.gd` editor this
  milestone**.

- **Telemetry-row signals carry PRIMITIVES ONLY** so `Telemetry` serializes straight to JSONL (`:85-88`, `:53-60`). Gameplay-event
  signals (not telemetry rows) may carry refs — e.g. `junk_dropped(item: JunkItem, world_pos: Vector2)` (`:66`). This split
  matters for L1: a **throw event** that just records "an item was thrown" is a telemetry row (primitives), but the **re-drop**
  reuses the existing `junk_dropped(item, world_pos)` (a ref-carrying gameplay event — Breakdown §6: "a missed throw re-enters
  the world via the existing `EventBus.junk_dropped` → `JunkSpawner` re-spawn path; reuse, don't reinvent").

- **Existing signals L1/L2 sit beside / reuse:**
  - `run_inventory_changed(used_slots, max_slots)` (`:44`) — the selector re-validates on this (Breakdown §3 L1: "re-validates on
    inventory change").
  - `junk_dropped(item: JunkItem, world_pos: Vector2)` (`:66`) — **the miss → re-drop path L1 reuses** (no new drop signal).
  - `new_hazard_killed(kind: StringName, depth: int, run_t_ms: int)` (`:149`) — the M1.4 shared kill-telemetry row. **Candidate
    for the throw-kill of the pursuer** (OQ-4): a throw-kill could reuse `new_hazard_killed(&"pursuer", …)` rather than declare
    its own signal. `Telemetry._on_new_hazard_killed` (`telemetry.gd:220`) already consumes it.
  - `player_died(cause)` (`:22`), `hazard_caught(depth, run_t_ms)` (`:90`) — the R1 pursuer's existing telemetry/death rows.

- **No test asserts a signal count** (`event_bus.gd` has no count test — confirmed: no count assertion anywhere). So adding the
  full M1.5 signal set up front is cheap; an unused declared signal is inert. This is *why* the pre-declare-everything rule is
  free on the EventBus side but needs the count-test bump on the RunConfig/CFG side.

### A.4 The two tests L0 must keep green (the knob-count contract)

- **`tests/test_config_menu.gd`** — the **hard count** lives here: `if exported.size() != 81` (`:49-50`), with the arithmetic
  in the comment (`:44-48`): *"R0: 32 + I2's 1 + I1's 3 + J2's 2 + J3's 6 + J4's 2 = 46; + M1.4's K2 5 + K3 3 + K4 4 + K5a 5 +
  K5b 7 + K5c 6 + K7 5 = 35 → 46 + 35 = 81."* `_exported_fields()` (`:106-114`) reflects RunConfig's stored+editor `@export`
  properties. **L0 must bump `81` → `81 + N_new_knobs`** and extend the comment's arithmetic with the M1.5 additions. The CFG
  menu's own build-time coverage assertion (`config_menu.gd:254` `_assert_full_coverage()`, backed by `has_full_coverage()`)
  cross-checks the bound-control set against the exported field set — so a knob with no MANIFEST entry crashes the menu at
  `_ready`. **L0 owns the CFG structural rows too** (see A.5) so the count stays green and the menu never crashes.

- **`tests/test_run_config.gd`** — `expected_keys` (`:74-111`) is a hand-listed array of **every** `to_flat_dict()` key; Case 5
  (`:112-126`) asserts each is present, the dict is flat, and JSON round-trips. **L0 must add every new knob to this array** in
  matching M1.5 comment blocks, or the test fails on a missing key. (It asserts presence + flatness + round-trip, not an exact
  count — but the count is pinned by `test_config_menu.gd:49`.)

### A.5 The CFG menu is HAND-AUTHORED, not reflection-driven (`ui/config/config_menu.gd`)

`config_menu.gd:77-80`: *"HAND-AUTHORED field manifest (§3.6 — NOT reflection)."* It needs, per new knob:
- a `MANIFEST[prefix]` list entry (`:81-143`);
- per **new section**, a `SECTIONS` entry (`:59-75`, `{prefix, title_key, gloss_key, master, collapsible}`) **+ CSV i18n
  title/gloss keys** in `ui/config/config_strings.csv`;
- per **numeric** knob a `FIELD_RANGE` entry (`:147-216`) and optionally a `FIELD_STEP` (`:221-231`).

The M1.4 K0 pass proved L0's scope decision: **K0 owned the CFG structural rows** (`config_menu.gd:66-74` SECTIONS, `:112-143`
MANIFEST, `:183-216` FIELD_RANGE, `:228-231` FIELD_STEP, all stamped "M1.4 (K0)") so the coverage assertion stayed green between
K0 landing and the per-knob UI tasks landing — exactly the OQ-5/Option-(a) resolution K0 adopted. **L0 adopts the same scope:**
L0 writes the SECTIONS/MANIFEST/FIELD_RANGE/FIELD_STEP rows + stub CSV keys for every M1.5 knob, because those four tables are
*mechanical derivations of the knob set* (one row per knob). The L1 highlight-selector UI (ui-ux) and any later styling tune
ranges/labels, not coverage. **One M1.5 knob lives in the throw group, the spawn-room knobs in the `r1_` group (existing
section — see OQ-1), and the three `*_kills` in the existing `hpp_`/`hbomb_`/`hspike_` sections** — so the only *new* CFG
section L0 creates is the **`throw_` section** (the pursuer + kills knobs slot into existing sections, no new section).

### A.6 The L1/L2/L5 as-built seams L0's knobs key off (verified)

- **Player facing (L1 throw direction).** `player.gd:20-22`: `var facing: Vector2 = Vector2.DOWN` — *"Last non-zero movement
  direction (normalized). Read-only … Defaults to DOWN."* Set at `player.gd:51` (`facing = input_dir.normalized()`). **L1's
  thrown projectile travels in `player.facing`** — the knob L0 declares is only the throw *speed* + *range/lifetime*, not the
  direction (that's read live off the player).

- **Run inventory (L1 remove-on-throw).** `RunInventory` (`systems/inventory/run_inventory.gd`) exposes `var items:
  Array[JunkItem]` (`:25`), `remove_at(index) -> JunkItem` (`:80`), `remove(item) -> bool` (`:93`), and emits
  `run_inventory_changed` via `_emit_changed` (`:33`). **L1's throw removes the highlighted item with `remove_at(idx)`** — no new
  RunInventory API, no new knob for the removal.

- **Spawn-room bounds for the pursuer (L2) — the key reuse.** `_spawn_r1_hazards` (`main_game.gd:507`) calls `hz.setup(rc,
  player)` — a **2-arg** setup; `HazardEntity.setup(cfg, player)` (`hazard_entity.gd:83`) has **no `spawn_ctx` param** today. BUT
  the K5i seam already computes a per-piece world-space room bound: `_piece_floor_bounds_world(cells) -> Rect2`
  (`main_game.gd:487-493`) and threads it to the ping-pong hazard via `spawn_ctx["room_bounds"]`
  (`main_game.gd:469-476`; `pingpong_hazard.gd:67` reads `spawn_ctx.get("room_bounds", Rect2())`). **So the room-bounds machinery
  L2 needs already exists.** L2's two implementation paths (Breakdown §4 "main_game.gd seam"): (a) widen `HazardEntity.setup` to
  the 3-arg family signature `setup(cfg, player, spawn_ctx)` and pass the R1 hazard its `room_bounds` (a `main_game.gd` +
  `hazard_entity.gd` edit) so the entity self-contains the room-bound patrol; or (b) compute bounds inside `hazard_entity.gd`.
  Either way, **L0 only declares the *knobs* L2 reads** (`r1_spawn_room_only` + a patrol-speed knob); the bounds plumbing is L2's.

- **K5 kill sites (L5).** `spike_hazard.gd:91-96`, `bomb_hazard.gd:113-117`, `pingpong_hazard.gd:121-137` each emit
  `new_hazard_killed` then call `GameState.fail_run(&"death")` **unconditionally**. L5 wraps each in `if _cfg.<prefix>_kills:`
  (mirroring `hazard_entity.gd:189`); `kills=false` skips the fatal path (non-lethal — the exact behaviour L5 defines). L0 only
  *declares* the three `bool` knobs at default `true`.

- **`_driven_default_preset()` retirement (L5 carry-in, NOT L0).** `tests/test_rg1_m14_verify.gd:457` defines
  `_driven_default_preset()` (a test-only near-copy of the real preset). Breakdown §3 L5: L5 retires it once `*_kills` exists so
  the verify driver runs the real `make_default_play_preset()` with kills off. **That is L5's edit; L0 does not touch the test
  driver** — L0 only lands the three knobs L5 will toggle.

---

## (b) Pseudocode — the proposed L0 edits (illustrative, against the real APIs)

> All new *lever* knobs default **off/neutral** (bool→`false`, float magnitude→`0.0`); the three `*_kills` knobs default
> **`true`** (= today's lethal K5 behaviour, the all-off-equivalent for an already-lethal hazard — A.6/OQ-3). So a fresh
> `RunConfig.new()` reproduces M1.0/M1.4-baseline byte-for-byte and the all-off fingerprint stays `e943ac9c8bc1` (these are all
> pure run-state knobs — throw, pursuer behaviour, hazard lethality — none feed `fingerprint()`). Names below are the
> **provisional union**; OQ flags the soft ones.

### B.1 New `@export` group + knobs in `run_config.gd` (append after the `exit_` group, `:357`)

**Throw group (L1) — NEW section, prefix `throw_`:**

```gdscript
# =============================================================================
# L1 (M1.5) — Throwing mechanic (highlight an inventory item, Space throws it in
# the player's facing direction; a hit kills the pursuer + destroys the item; a
# miss re-drops it via EventBus.junk_dropped). All-off default = no throwing
# (M1.4 behaviour). Pure run-state (remove from run_inventory + a transient
# projectile) — never feeds fingerprint(), never persists.
# =============================================================================
@export_group("L1 Throwing", "throw_")
## Master toggle. OFF = no highlight selector, no throw (M1.4 behaviour).
@export var throw_enabled: bool = false
## Projectile travel speed (px/s, greybox). Entity-read by the thrown projectile.
@export var throw_speed: float = 0.0
## Max travel distance (px) before the throw MISSES and the item re-drops.
## 0.0 = no distance cap (rely on throw_lifetime_s / a wall hit instead). (OQ-2)
@export var throw_max_range: float = 0.0
## Max airborne time (s) before the throw MISSES and the item re-drops.
## 0.0 = no time cap (rely on throw_max_range / a wall hit instead). (OQ-2)
@export var throw_lifetime_s: float = 0.0
## WHAT a thrown item can kill (OQ-3 scope; Director recommend pursuer-only for RG1):
##   0 = pursuer_only (R1 HazardEntity), 1 = all_hazards (also the 3 K5 types).
@export_enum("pursuer_only", "all_hazards") var throw_kill_scope: int = 0
```

**Spawn-room pursuer group (L2) — knobs go in the EXISTING `r1_` group (OQ-1), declared just after the J3 density block
(`run_config.gd:116`):**

```gdscript
	# L2 (M1.5) — spawn-room-bound pursuer behaviour. When ON, the pursuing HazardEntity
	# patrols within its spawn room and chases ONLY while the player is in that room
	# (Director-locked: SLOW PATROL, not despawn/idle-freeze). OFF = today's chase-
	# everywhere behaviour (M1.4). Pure run-state; never feeds fingerprint().
	## Master-adjacent behaviour toggle (lives under r1_enabled). false = chase-everywhere (M1.4).
	@export var r1_spawn_room_only: bool = false
	## Patrol speed (px/s) while the player is OUTSIDE the spawn room (the slow-patrol pace).
	## 0.0 = stand still when not chasing (a degenerate "idle patrol"); the preset sets a slow walk.
	@export var r1_patrol_speed: float = 0.0
```

**K5 per-hazard `*_kills` toggles (L5) — one bool in EACH existing K5 group, defaulting `true`:**

```gdscript
	# (appended inside @export_group("K5a Ping-Pong Hazard", "hpp_"), after hpp_per_room_cap:)
	## L5 (M1.5): whether a contact KILLS (true = today's lethal behaviour) or is non-lethal.
	## Default true = preserves M1.4; false expresses a non-lethal preset (mirrors r1_catch_kills).
	@export var hpp_kills: bool = true

	# (inside @export_group("K5b Bomb Hazard", "hbomb_"), after hbomb_per_room_cap:)
	## L5 (M1.5): whether a detonation in-radius KILLS (true = M1.4 lethal) or is non-lethal.
	@export var hbomb_kills: bool = true

	# (inside @export_group("K5c Rotating Spikes", "hspike_"), after hspike_per_room_cap:)
	## L5 (M1.5): whether arm contact KILLS (true = M1.4 lethal) or is non-lethal.
	@export var hspike_kills: bool = true
```

### B.2 `to_flat_dict()` additions (append into the grouped return literal, after the `exit_*` block `run_config.gd:509`)

```gdscript
		# L1 (M1.5) — throwing config knobs (additive payload; RG2 segments throw cohorts)
		"throw_enabled": throw_enabled,
		"throw_speed": throw_speed,
		"throw_max_range": throw_max_range,
		"throw_lifetime_s": throw_lifetime_s,
		"throw_kill_scope": throw_kill_scope,
		# L2 (M1.5) — spawn-room pursuer behaviour knobs (additive payload)
		"r1_spawn_room_only": r1_spawn_room_only,
		"r1_patrol_speed": r1_patrol_speed,
		# L5 (M1.5) — per-hazard lethality toggles (default true = M1.4 lethal behaviour)
		"hpp_kills": hpp_kills,
		"hbomb_kills": hbomb_kills,
		"hspike_kills": hspike_kills,
```

All values are JSON primitives (bool/float/int) — flat, no helper needed; the `test_run_config.gd` flatness + round-trip checks
pass unchanged. **Add the same keys to `test_run_config.gd`'s `expected_keys` array** (`:74-111`) under L1/L2/L5 comment blocks.

### B.3 New `EventBus` signals (append a new M1.5 block to `systems/event_bus.gd` after the K7 block, `:155`)

```gdscript
# === M1.5 signals (sole event_bus.gd edit this milestone, owner = L0) =========
# Pre-declared up front so L1/L2/L5 only EMIT — they never edit this file (the
# M1.1 pre-declare rule, M1.5 Breakdown §6). Telemetry-row payloads are PRIMITIVES
# ONLY. Names/signatures are PROVISIONAL — refined when L1/L2's Phase-2 designs land.

# --- L1 Throwing (telemetry rows; the re-drop reuses junk_dropped above) ------
## A throw was launched (telemetry: how often the player uses agency). PRIMITIVES only —
## the JunkItem is NOT carried (the re-drop path that needs the ref uses junk_dropped).
signal item_thrown(item_id: StringName, depth: int, run_t_ms: int)
## A thrown item MISSED (wall / max-range / lifetime) and was re-dropped. Telemetry row;
## the actual re-spawn flows through the existing junk_dropped(item, world_pos). (OQ-5)
signal throw_missed(item_id: StringName, depth: int, run_t_ms: int)
## A thrown item KILLED a hazard. kind = &"pursuer" (R1) or a K5 kind if throw_kill_scope
## allows. SEE OQ-4: this MAY be dropped in favour of reusing new_hazard_killed(&"pursuer").
signal throw_killed_hazard(kind: StringName, depth: int, run_t_ms: int)

# --- L2 Spawn-room pursuer (telemetry row) -----------------------------------
## The pursuer changed chase/patrol state (telemetry: how room-bound the threat reads).
## state = 0 patrol (player outside room), 1 chase (player inside room). (OQ-5 arity)
signal pursuer_state_changed(state: int, depth: int, run_t_ms: int)
```

> **No K5/L5 signal is needed:** the `*_kills` toggles only gate the *existing* `new_hazard_killed` emit + `fail_run` call (a
> non-lethal hazard simply does neither). L5 declares no signal; it reads three knobs L0 lands.

### B.4 CFG structural rows in `config_menu.gd` (L0 owns these — A.5 / OQ scope)

```gdscript
# SECTIONS (config_menu.gd:59-75) — ONE new section (throw_). The pursuer knobs and the
# *_kills toggles join the EXISTING r1_ / hpp_ / hbomb_ / hspike_ sections (no new section).
	{"prefix": "throw_", "title_key": "CFG_SEC_THROW", "gloss_key": "CFG_GLOSS_THROW", "master": "throw_enabled", "collapsible": true},

# MANIFEST (config_menu.gd:81-143):
	"throw_": [
		"throw_enabled", "throw_speed", "throw_max_range", "throw_lifetime_s", "throw_kill_scope",
	],
# ...and APPEND to the existing lists:
	"r1_":     [ ...existing..., "r1_spawn_room_only", "r1_patrol_speed" ],
	"hpp_":    [ ...existing..., "hpp_kills" ],
	"hbomb_":  [ ...existing..., "hbomb_kills" ],
	"hspike_": [ ...existing..., "hspike_kills" ],

# FIELD_RANGE (config_menu.gd:147-216) — numeric scalars only (bools/enums render as their
# own widgets, no range):
	"throw_speed": RANGE_SPEED,            # reuse the existing RANGE_SPEED (0,120) const
	"throw_max_range": RANGE_VIEW,         # px distance — reuse RANGE_VIEW (0,1920) or a new RANGE_DIST
	"throw_lifetime_s": RANGE_SECONDS,     # reuse RANGE_SECONDS (0,30)
	"r1_patrol_speed": RANGE_SPEED,        # px/s patrol pace — reuse RANGE_SPEED
# (throw_kill_scope is an @export_enum → OptionButton; throw_enabled / r1_spawn_room_only /
#  *_kills are bools → CheckButton; none need a FIELD_RANGE.)
# No new FIELD_STEP needed (all default 1.0 step is fine for these).
```

Plus **stub CSV keys** in `ui/config/config_strings.csv` for the new section: `CFG_SEC_THROW`, `CFG_GLOSS_THROW` (and the menu
falls back to the raw key for any unstubbed per-row label, as it does today — the per-knob UI styling pass fills polish).

### B.5 Test updates L0 must make in the same pass

- **`tests/test_run_config.gd`** — append the 10 new keys to `expected_keys` (`:74-111`) under L1/L2/L5 comment blocks.
- **`tests/test_config_menu.gd`** — bump `81` → **`81 + N`** (`:49`) and extend the `:44-48` arithmetic comment with the M1.5
  additions (`+ L1's 5 throw_ + L2's 2 r1_ + L5's 3 *_kills`). **With the provisional set N = 10 → 91.** (OQ-7 may trim this.)

### B.6 The new knob count

| Group | Knobs | Count |
|---|---|---|
| L1 Throwing (`throw_`, new section) | `throw_enabled`, `throw_speed`, `throw_max_range`, `throw_lifetime_s`, `throw_kill_scope` | 5 |
| L2 pursuer (into existing `r1_`) | `r1_spawn_room_only`, `r1_patrol_speed` | 2 |
| L5 lethality (into existing `hpp_`/`hbomb_`/`hspike_`) | `hpp_kills`, `hbomb_kills`, `hspike_kills` | 3 |
| **M1.5 new total** | | **10** |

**Knob count: 81 → 91** (provisional union). OQ-2 (max-range vs lifetime) and OQ-3/OQ-4 may reduce this; the **final count is
frozen in this doc's Resolved Decisions section after Phase 3**, and `test_config_menu.gd:49` is bumped to match.

### B.7 Determinism / all-off-fingerprint note (why off/neutral + `kills=true` defaults are safe)

The fingerprint `e943ac9c8bc1` is computed over the *generated band* for the all-off config. It moves only for knobs that feed
`fingerprint(seed+config)` — i.e. **cell-space / generation** knobs. **None of L0's new knobs feed generation:** throwing is pure
run-state (remove from `run_inventory` + a transient projectile); the pursuer's patrol is a behaviour branch on an
already-placed run-state hazard node (placement is pure run-state, never fed to `fingerprint()` — `_spawn_r1_hazards` is RNG-free
on the graded band, A.6); and the `*_kills` toggles only change a run-time death branch. The `*_kills` defaulting **`true`** is
*especially* safe: it changes nothing about today's behaviour (today the K5 hazards always kill), so a fresh `RunConfig.new()` +
the existing preset produce byte-identical runs. The fun values (throw on, pursuer-room on) live only in
`make_default_play_preset()` — **L1/L2's edit, not L0's** — so the code-level all-off control is never mutated.

---

## (c) Open Questions

**OQ-1 — Pursuer knobs in the existing `r1_` group, or a new `pursuer_`/`r1room_` section? (house style; recommend, Phase-3
confirm).** The spawn-room pursuer *is* the R1 HazardEntity behaving differently — it reads `r1_*` knobs already
(`hazard_entity.gd` snapshots `_cfg.r1_*`). Putting `r1_spawn_room_only` + `r1_patrol_speed` in the **existing `r1_` group/CFG
section** keeps the contiguous-prefix house style (`run_config.gd:32-36`) and groups them with the other R1 knobs the Director
sweeps together — no new CFG section. The alternative (a new `pursuer_` section) would split R1's knobs across two sections.
**Recommendation: existing `r1_` group, `r1_` prefix** (drawn above). Trade-off: it makes the `r1_` section longer; acceptable.

**OQ-2 — Throw miss condition: max-range, lifetime, or BOTH? (load-bearing knob-set + count; recommend, Phase-3/L1 confirm).**
A thrown item must eventually MISS and re-drop if it hits nothing. Three shapes:
- **(a) max-range only** (`throw_max_range`, px) — predictable "it lands N px ahead"; simplest; one knob.
- **(b) lifetime only** (`throw_lifetime_s`, s) — couples range to speed (range = speed × lifetime); one knob.
- **(c) both** (drawn above) — either cap can trip first; most flexible for the Director's sweep; **two knobs**.

  **Recommendation: declare BOTH (c), each default 0.0 = "that cap is off"** so the preset/sweep can use whichever (or both), and
  a wall hit is always a third miss trigger regardless. Cost: one extra knob + one CFG row + one count slot. **If L1's design
  picks one, drop the other here and N drops 10→9.** Flag to L1's Phase-2 / Phase-3.

**OQ-3 — Throw kill scope: a `throw_kill_scope` enum, or pursuer-only hard-coded? (Director fun/scope call).** Breakdown §7
(L1) flags this: the Director feedback names "pursuer" specifically. Two shapes:
- **(a) `throw_kill_scope` enum** (`pursuer_only` default / `all_hazards`) — lets a later sweep extend the throw to the K5
  hazards without re-editing `run_config.gd`; default reproduces the recommended pursuer-only RG1 scope. One enum knob.
- **(b) hard-code pursuer-only** — no knob; if the Director later wants throw-kills-all, that's a new knob then.

  **Recommendation: declare the enum (a), default `pursuer_only`** (matches the Director's named scope for RG1, keeps the sweep
  open, no re-edit later). **NEEDS DIRECTOR REVIEW (scope):** "For RG1, should a thrown item kill ONLY the R1 pursuer, or also
  the ping-pong/bomb/spike hazards? Recommend pursuer-only for the re-gate, others a later sweep." If the Director says
  pursuer-only-forever, drop the enum and N drops by 1.

**OQ-4 — Throw-kill signal: reuse `new_hazard_killed(&"pursuer", …)` or a dedicated `throw_killed_hazard`? (recommend,
Phase-3/L1 confirm).** A throw-kill of the pursuer is a *kill*, and `new_hazard_killed(kind, depth, run_t_ms)` (`event_bus.gd:149`)
is the M1.4 shared kill-telemetry row that `Telemetry` already consumes (`telemetry.gd:220`). Two shapes:
- **(a) reuse `new_hazard_killed(&"pursuer", …)`** — zero new signal; RG2 segments throw-kills by `kind == &"pursuer"`. BUT it
  conflates "a hazard killed the player" (today's meaning of `new_hazard_killed`) with "the player killed a hazard" — the
  *direction of the kill is opposite*, which would corrupt RG2's death-by-hazard counts.
- **(b) dedicated `throw_killed_hazard(kind, depth, run_t_ms)`** (drawn above) — clean separation: `new_hazard_killed` stays
  "hazard killed player," `throw_killed_hazard` is "player killed hazard via throw." One new signal (free — no signal count test).

  **Recommendation: (b) dedicated `throw_killed_hazard`** — the kill direction is semantically opposite, so reusing
  `new_hazard_killed` would poison the existing telemetry metric. The signal is free on the EventBus side. Flag to L1/Phase-3 to
  confirm the arity.

**OQ-5 — Exact new-signal set + arities (recommend, Phase-3/L1+L2 lock).** Provisional set: `item_thrown(item_id, depth,
run_t_ms)`, `throw_missed(item_id, depth, run_t_ms)`, `throw_killed_hazard(kind, depth, run_t_ms)`, `pursuer_state_changed(state,
depth, run_t_ms)`. Soft points: (i) does `throw_missed` need a `world_pos`? — **no**, the re-drop carries it on the existing
`junk_dropped(item, world_pos)`; `throw_missed` is just the telemetry row. (ii) Is `pursuer_state_changed` a telemetry need at
all, or does L2 just flip behaviour silently? — **recommend declaring it** (free; RG2 wants "how room-bound did the threat read"),
but L2's Phase-2 confirms it emits it. (iii) Should `state` be an `int` enum or a `bool is_chasing`? — `int` is more extensible
(future "returning to room" state); recommend `int`. **Lock the final set in Resolved Decisions after L1+L2 Phase-2 cite what
they emit.**

**OQ-6 — Does L0 add a BUG6 `throw_no_speed` inert-config trap? (recommend NO — L1 owns it).** A `throw_enabled` run with
`throw_speed == 0` (and no other cap) is a dead lever. `inert_enabled_oppositions()` (`run_config.gd:541`) is the trap home, but
every M1.4 consumer added its own trap line in its own task (K0 left it for the consumers, K0 OQ). **Recommendation: L0 does NOT
add the trap; L1 adds `throw_no_speed` if it wants it** (it's a one-line append in the consuming task). L0 only leaves the comment
seam. Flag to L1.

**OQ-7 — Final knob count (depends on OQ-2 + OQ-3 resolutions).** The provisional union is **10 new knobs → 81 → 91**. If OQ-2
collapses to one miss-condition knob (−1) and OQ-3 hard-codes pursuer-only (−1), the count drops to **8 → 89**. The count is
**load-bearing** (`test_config_menu.gd:49` asserts it exactly), so it must be **frozen in this doc's Resolved Decisions section
after Phase 3**, and L0's code task bumps the test to the frozen number. **Recommendation: declare the maximal set now (91)** so
L1/L2 never re-edit the three shared files; trim only if Phase 3 / the dependent Phase-2 designs explicitly retire a knob (the
K0 strategy-1 precedent — declare maximal, reconcile in Resolved Decisions before dispatching the code task).

**OQ-8 — `*_kills` default `true` is the one non-`false` M1.5 default — does it violate "new LEVER knobs default off"?
(recommend NO; it is correct).** The carried contract (Breakdown §6) says new *lever* knobs default off so the all-off control
reproduces the baseline. The `*_kills` toggles default `true` because **`true` IS the baseline** for an already-lethal hazard —
defaulting them `false` would *change* today's behaviour for an unconfigured run (the K5 hazards would stop killing), breaking
the all-off-equals-baseline contract. So `kills=true` is the all-off-*equivalent*, not a violation. This is exactly the
breakdown's own instruction ("`*_kills` default `true` = preserves today's behaviour"). **Recommendation: keep `true`; no
Director call needed — it is the contract-preserving default.** (Stated here only because it is the lone non-`false` default and
a fresh-eyes reviewer will flag it.)

---

## Carried contracts (stated, not violated)

- **All-off `RunConfig` default = permanent baseline** (fingerprint `e943ac9c8bc1`): every new M1.5 *lever* knob defaults
  off/neutral; the three `*_kills` default `true` (= today's lethal behaviour, the all-off-equivalent). None feed
  `fingerprint()` (all pure run-state). A fresh `RunConfig.new()` is byte-identical to M1.4-baseline. (B.7)
- **Fun values live only in `make_default_play_preset()`** — L0 does NOT touch the preset; L1/L2 layer throw-on +
  spawn-room-pursuer-on there in Wave 2.
- **Every knob joins `to_flat_dict()` + the CFG coverage rows + the knob-count tests** (B.2, B.4, B.5).
- **New signals are additive**; `run_ended` arity is locked (no M1.5 signal touches it); no save-schema change in M1.5 (throw,
  selector, and pursuer state are all pure run-state).
- **Single-writer:** L0 is the **sole editor of `run_config.gd`, `event_bus.gd`, and the structural rows of `config_menu.gd`**
  this milestone; L1/L2/L5 only read knobs + emit pre-declared signals.

---

## Resolved Decisions (Phase 3)

_Fresh-eyes pass, 2026-06-24. Reviewer is NOT the author of L0/L1/L2/L5. Resolved against the verified as-built code
(`run_config.gd`, `config_menu.gd`, `event_bus.gd`, `tests/test_run_config.gd`, `tests/test_config_menu.gd`,
the three K5 entity scripts, `tests/test_rg1_m14_verify.gd`). Director-judgment calls are flagged under "Needs Director
review" with a recommendation; everything else is resolved on technical/design merit and is now LOCKED for L0's code task._

### RD-0 — The contested knob count, reconciled DEFINITIVELY (the @export-vs-CFG-row confusion)

There is **one count, and it is 81 — there is no second number.** The L1 doc's "72 `@export var` vs the CFG menu's 81 rows"
was a miscount, not a real discrepancy. Verified directly:

- `data/run_config/run_config.gd` declares **81** editor knobs: **72** plain `@export var` **+ 9** `@export_enum` (the 9
  enums, verified: `r1_spawn_distribution`, `r1_density_metric`, `r2_mechanism`, `r2_toll_resource`, `r3_penalty_kind`,
  `quota_check_timing`, `quota_basis`, `cam_zoom_policy`, `timer_warning_channel`). The L1 doc counted only `@export var`
  (72) and silently dropped the 9 `@export_enum` knobs — but an `@export_enum var x: int` **is** a stored+editor property and
  **is** a CFG row (rendered as an `OptionButton`). So `72 + 9 = 81`.
- `RunConfig.to_flat_dict()` returns **81 keys** — one per knob (verified: `grep -cE '^\s*"[a-z0-9_]+":'` on the return
  literal = 81). `tests/test_run_config.gd` `expected_keys` lists all 81 and asserts **presence + flatness + JSON
  round-trip** (NOT an exact count — `Case 5`, `:112-126`).
- `tests/test_config_menu.gd:49` is the **hard exact count**: `if exported.size() != 81`. `_exported_fields()` (`:106-114`)
  reflects every property with `STORAGE|EDITOR` usage (minus `script`/`resource_*`) — i.e. **all 81 `@export`/`@export_enum`
  fields**. The CFG menu's `_assert_full_coverage()` (`config_menu.gd:254`) separately cross-checks that every exported
  field has a bound MANIFEST control (crashes `_ready` if not). So the count and coverage are two distinct guards, both
  keyed to the same 81.

**There is no "@export-row vs CFG-row" gap.** The CFG MANIFEST has exactly one entry per exported field (the coverage
assertion enforces this). `@export var` and `@export_enum var` both count as one knob, one flat-dict key, one MANIFEST row,
one CFG widget. **Authoritative current count = 81.** L0's doc body (81→91) used the right baseline; the L1 doc's "72" is
retired here.

### RD-1 — The frozen M1.5 knob set, names, types, defaults (LOCKED, pending only the OQ-3 Director branch)

L0 declares the following knobs. Contiguous-prefix house style; every new LEVER knob defaults off/neutral; `*_kills` default
`true`. Resolutions of the soft OQs are folded in:

**Throw group (`throw_`) — NEW `@export_group("L1 Throwing", "throw_")`, appended after the `exit_` group:**

| knob | type | default | resolution |
|---|---|---|---|
| `throw_enabled` | `bool` | `false` | master gate; preset sets `true` (L1) |
| `throw_speed` | `float` | `0.0` | px/s; preset value Director-swept |
| `throw_max_range` | `float` | `0.0` | px before a miss → re-drop. **KEEP** (RD-2) |
| ~~`throw_lifetime_s`~~ | — | — | **DROPPED** (RD-2): L1 uses an in-script lifetime fallback constant, not a knob |
| `throw_kill_scope` | `@export_enum("pursuer_only","all_hazards") int` | `0` | **CONDITIONAL on the Director's OQ-3 call** (RD-3 + Needs-Director) |

**Spawn-room pursuer — into the EXISTING `r1_` group/CFG section (OQ-1 resolved: existing `r1_`):**

| knob | type | default | resolution |
|---|---|---|---|
| `r1_spawn_room_only` | `bool` | `false` | master-adjacent behaviour toggle; preset on (L2) |
| `r1_patrol_speed` | `float` | `0.0` | px/s patrol pace; 0 = idle-pivot. preset Director-swept |

L2's OQ-5/OQ-8 optional knobs `r1_patrol_pattern` and `r1_patrol_radius` are **NOT declared** (RD-4): L2's locked design uses
Option A bounds (real room rect from `main_game.gd`) → no `r1_patrol_radius`; and pace-endpoints is the single recommended
pattern → no `r1_patrol_pattern` enum. If the Director's OQ-2 (patrol pattern, fun call) picks a *selectable* pattern, L0
adds `r1_patrol_pattern: int = 0` then (+1 knob) — see Needs-Director. Default scope is the 2-knob minimal set.

**K5 lethality — one `bool` into EACH existing K5 group, default `true`:**

| knob | type | default | group |
|---|---|---|---|
| `hpp_kills` | `bool` | `true` | `hpp_` (after `hpp_per_room_cap`) |
| `hbomb_kills` | `bool` | `true` | `hbomb_` (after `hbomb_per_room_cap`) |
| `hspike_kills` | `bool` | `true` | `hspike_` (after `hspike_per_room_cap`) |

OQ-8 confirmed: `*_kills = true` is the all-off-*equivalent* for an already-lethal hazard (defaulting `false` would change
today's behaviour and break the baseline contract). No Director call needed on the default polarity.

### RD-2 — OQ-2 (throw miss condition): max-range knob ONLY; lifetime is an in-script constant (NOT a knob)

L1's own OQ-4 recommends "max-range as the design rule (`throw_max_range`), plus a hidden generous lifetime fallback
**constant in the script** (not a knob)" — mirroring how `hazard_entity.gd` keeps feel constants in-script. This is the
right resolution and it is **consistent with L1's pseudocode** (`thrown_item.gd` integrates position and calls `_miss()` on
`distance_to(_start) >= _max_range`; the lifetime is a belt-and-braces `SceneTreeTimer`, not a `RunConfig` field). So:
**declare `throw_max_range` only; do NOT declare `throw_lifetime_s`.** This drops L0's provisional `throw_lifetime_s` knob.
Net throw-group count: 4 knobs if OQ-3 keeps the enum, 3 if pursuer-only is hard-coded.

> Note: L0's Phase-2 body (B.1) drew `throw_lifetime_s` as a knob; the L1 design (the consumer that actually reads it) does
> NOT read a lifetime knob. The consumer wins — L0 follows L1. **`throw_lifetime_s` is retired.**

### RD-3 — OQ-4 (throw-kill signal): dedicated `throw_killed_hazard`, do NOT reuse `new_hazard_killed` — RESOLVED on telemetry-cleanliness merit

`new_hazard_killed(kind, depth, run_t_ms)` means **"a hazard killed the player"** — every existing emit (`pingpong_hazard.gd`,
`bomb_hazard.gd`, `spike_hazard.gd`) fires it immediately before `GameState.fail_run(&"death")`, and `Telemetry` consumes it
as a death-cause row. A throw-kill is the **opposite direction** ("the player killed a hazard"). Reusing `new_hazard_killed`
for a throw-kill would inflate the death-by-hazard metric with player-initiated kills and **corrupt RG2's death analysis**.
Therefore: **declare a dedicated signal.** This is L0's OQ-4 recommendation (b) and is now LOCKED.

### RD-4 — OQ-5 (the frozen new-signal set + arities), RECONCILING the L0/L1/L2 naming disagreement

The three Phase-2 docs used **inconsistent signal names** (L0: `item_thrown`/`throw_missed`/`throw_killed_hazard`/
`pursuer_state_changed`; L1: `item_thrown`/`thrown_item_hit`/`thrown_item_missed`; L2: `hazard_pursuer_state`). L0 is the
single-writer and must freeze ONE set. Frozen set, with arities (all telemetry rows → PRIMITIVES ONLY, per `event_bus.gd`
discipline; the re-drop reuses the existing `junk_dropped(item, world_pos)`):

```gdscript
# === M1.5 signals (sole event_bus.gd edit this milestone, owner = L0) ===
# --- L1 Throwing (telemetry rows; the re-drop reuses junk_dropped) ---
signal item_thrown(item_id: StringName, depth: int, run_t_ms: int)
signal throw_missed(item_id: StringName, depth: int, run_t_ms: int)
signal throw_killed_hazard(item_id: StringName, kind: StringName, depth: int, run_t_ms: int)
# --- L2 Spawn-room pursuer (telemetry row, rising-edge) ---
signal hazard_pursuer_state(state: StringName, depth: int, run_t_ms: int)
```

Naming + arity resolutions (the points the docs disagreed on):
- **`item_thrown(item_id, depth, run_t_ms)`** — agreed by both L0 and L1. LOCKED as-is.
- **Miss signal: `throw_missed`** (L0's name), NOT L1's `thrown_item_missed`. Shorter, parallels `item_thrown`. Arity
  `(item_id, depth, run_t_ms)` — no `world_pos` (the re-drop carries position on `junk_dropped`). LOCKED.
- **Kill signal: `throw_killed_hazard`** (L0's name), NOT L1's `thrown_item_hit`. **Arity widened to include `item_id`**:
  `(item_id, kind, depth, run_t_ms)` — L1's pseudocode emits `(_item.id, &"pursuer", …)`, so the item id is available and
  RG2 may want "which items get spent as weapons." `kind` = `&"pursuer"` (R1) or a K5 kind (`&"pingpong"` etc.) if OQ-3
  scopes wider. LOCKED.
- **Pursuer-state: `hazard_pursuer_state(state: StringName, depth, run_t_ms)`** (L2's name + arity), NOT L0's
  `pursuer_state_changed(state: int, …)`. **Resolved to L2's `StringName` state (`&"patrol"`/`&"chase"`)**, not L0's `int`
  enum: L2 is the emitter and its pseudocode emits `&"patrol"`/`&"chase"`; a `StringName` is self-describing in the JSONL
  (RG2 reads `&"chase"` directly, no enum decode), matching the `new_hazard_killed` `kind`-as-StringName house style.
  Rising-edge-latched (no per-frame storm). LOCKED.

No K5/L5 signal: the `*_kills` toggles only gate the *existing* `new_hazard_killed` emit + `fail_run` — see L5's RD.

### RD-5 — OQ-1 (pursuer knobs go in the existing `r1_` group): RESOLVED — existing `r1_` group/section

The spawn-room pursuer IS the R1 HazardEntity; `r1_spawn_room_only` + `r1_patrol_speed` join the existing `@export_group("R1
Pursuing Hazard", "r1_")` and the existing `r1_` CFG section. **No new CFG section for the pursuer.** Confirms L0's OQ-1
recommendation. The only NEW CFG `SECTIONS` entry L0 creates is the **`throw_`** section.

### RD-6 — OQ-6 (BUG6 inert-trap): L0 does NOT add a `throw_no_speed` trap

L0 leaves `inert_enabled_oppositions()` to its consumers, as K0 did. L1 may add `throw_no_speed` as a one-line append in its
own task if it wants the trap; L0 only leaves the comment seam. Confirms L0's OQ-6 recommendation.

### RD-7 — FINAL KNOB COUNT + the exact delta L0 must produce

**Current authoritative count: 81** (RD-0). M1.5 additions:

| group | knobs | count |
|---|---|---|
| L1 `throw_` | `throw_enabled`, `throw_speed`, `throw_max_range` (RD-2 dropped `throw_lifetime_s`) | 3 |
| L1 `throw_` — conditional | `throw_kill_scope` enum | +0 or +1 (OQ-3 Director branch, RD-3/Needs-Director) |
| L2 `r1_` | `r1_spawn_room_only`, `r1_patrol_speed` | 2 |
| L5 `*_kills` | `hpp_kills`, `hbomb_kills`, `hspike_kills` | 3 |

**Two final numbers map directly to the one open Director call (OQ-3 throw kill scope):**
- **If the Director keeps `throw_kill_scope` as an enum** (recommended — see Needs-Director): **8 new → 81 → 89.**
- **If the Director hard-codes pursuer-only** (drop the enum): **7 new → 81 → 88.**

L0's code task **bumps `tests/test_config_menu.gd:49` from `81` to the frozen number (88 or 89)** once the Director picks,
extends the `:44-48` arithmetic comment with `+ L1's 3 (or 4) throw_ + L2's 2 r1_ + L5's 3 *_kills`, and adds the matching
keys to `tests/test_run_config.gd` `expected_keys`. **This is the only count L0 must produce; the 91/89 provisional spread in
L0's body is superseded by 89/88 here** (the difference is RD-2 retiring `throw_lifetime_s`, which the L0 body still counted).

### RD-8 — CFG structural rows (unchanged from L0 body, with RD-2 applied)

- `SECTIONS`: **one** new entry — `{"prefix": "throw_", "title_key": "CFG_SEC_THROW", "gloss_key": "CFG_GLOSS_THROW",
  "master": "throw_enabled", "collapsible": true}`. Pursuer + `*_kills` knobs join existing sections.
- `MANIFEST["throw_"]` = `["throw_enabled", "throw_speed", "throw_max_range"]` (+`"throw_kill_scope"` iff OQ-3 enum). Append
  `r1_spawn_room_only`, `r1_patrol_speed` to `MANIFEST["r1_"]`; append `hpp_kills`/`hbomb_kills`/`hspike_kills` to their
  groups.
- `FIELD_RANGE` (numeric scalars only; verified the consts exist): `"throw_speed": RANGE_SPEED` (`Vector2(0,120)`),
  `"throw_max_range": RANGE_VIEW` (`Vector2(0,1920)`, px distance), `"r1_patrol_speed": RANGE_SPEED`. **`throw_lifetime_s` row
  removed** (RD-2). `throw_kill_scope` (enum → OptionButton), `throw_enabled`/`r1_spawn_room_only`/`*_kills` (bools →
  CheckButton) need no FIELD_RANGE. No new FIELD_STEP.
- Stub CSV keys `CFG_SEC_THROW`, `CFG_GLOSS_THROW` in `ui/config/config_strings.csv` (menu falls back to raw keys for
  per-row labels).

### Needs Director review

- **OQ-3 — Throw kill scope (fun/scope, owned by the agency cluster).** *"For RG1, should a thrown item kill ONLY the R1
  pursuer, or also the ping-pong / bomb / spike K5 hazards?"* The L1 design surfaces a load-bearing **architectural** fact:
  the R1 pursuer **and** the K5 ping-pong are CharacterBody2D bodies on the `hazard` layer (mask-hittable for free), but the
  **K5 bomb and spike are plain Node2D with no physics body** (un-hittable by an overlap projectile without bespoke code).
  So the natural fall lines are:
    - **(a) pursuer-only** — projectile filters `if body is HazardEntity`. **Count: drop `throw_kill_scope` → 81 → 88.**
    - **(b) "any `hazard`-group body" (= pursuer + ping-pong for free; bomb/spike out of scope, no body)** — keep
      `throw_kill_scope` enum (`pursuer_only` default / `all_hazards`). **Count: 81 → 89.**
  **Recommendation: keep the `throw_kill_scope` enum, default `pursuer_only` (→ count 89).** It matches the Director's named
  RG1 scope (pursuer), keeps the sweep open with zero re-edit of the three shared files later, and the enum knob is free on
  the EventBus/test side. The Director's pick maps directly: **pursuer-only-forever → 88; enum (recommended) → 89.** *(This
  is the ONE count-affecting Director call.)*

- **OQ-2 (L2) — Patrol pattern (fun/feel, owned by L2/Director).** L2 recommends pace-between-two-endpoints (with
  `r1_patrol_speed=0` collapsing to idle). If the Director wants a *selectable* pattern (pace vs deterministic
  random-walk vs idle), L0 must add `r1_patrol_pattern: int = 0` (+1 knob → 89/90). **Recommendation: single pace-endpoint
  pattern, NO `r1_patrol_pattern` knob** (best legibility-per-line; `r1_patrol_speed=0` already gives the idle control).
  *Defaults assume this; flag only if the Director wants the selector.*

- **OQ-3 (L2) — Patrol/chase speed values (fun sweep, NOT a count question).** Preset values only (`make_default_play_preset`),
  not a knob/count decision — noted for completeness; the Director sweeps these in RG1.

**Lock status:** the knob *set*, *names*, *types*, *defaults*, *signal set + arities*, and the CFG structural rows are
FROZEN. The single remaining variable is OQ-3 (throw kill scope), which toggles the final count between **88 and 89** and
whether `throw_kill_scope` is declared. L0's code task is dispatched once the Director picks; everything else is locked.
