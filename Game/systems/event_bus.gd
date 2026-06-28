extends Node
## EventBus — the global signal hub (TDD §2: "signal-driven decoupling").
##
## Systems emit and connect to signals here instead of holding hard references
## to each other, so the dive layer, exposure system, UI, audio, and telemetry
## stay independent and testable. Nothing in here holds state — it is pure wiring.

# --- Run lifecycle -----------------------------------------------------------
signal run_started(band_id: StringName, seed: int)
signal run_ended(reason: StringName, duration_s: float, depth_reached: int)
signal band_entered(band_id: StringName, depth: int)

# --- Economy (drives GameState ledger + Telemetry) ---------------------------
signal currency_changed(kind: StringName, delta: int, source: StringName)
signal haul_banked(total_value: int)

# --- Exposure & secrecy ------------------------------------------------------
signal exposure_changed(value: int)
signal exposure_threshold_crossed(threshold: int)

# --- Player / in-dive clock --------------------------------------------------
signal player_died(cause: StringName)
signal stamina_low()

# === M1 wave-2 contract (orchestrator-locked 2026-06-15) =====================
# Signals declared centrally so A2/A3/B2/D1 build against a stable contract and
# never have to edit this file in parallel. Owning task noted per group.

# --- Interaction (A2) --------------------------------------------------------
signal interaction_requested(interactable_id: StringName, target: Node)
signal interactable_focused(target: Node)
signal interactable_unfocused(target: Node)

# --- In-dive clock (A3) — clock resets on run_started, stops on run_ended ----
signal dive_clock_changed(current: float, maximum: float)
signal dive_clock_timeout()

# --- Procedural band assembly (B2) -------------------------------------------
signal band_generation_started(seed: int)
signal band_generated(seed: int, piece_count: int)
signal band_generation_failed(seed: int, reason: StringName)

# --- Slot inventory (D1) -----------------------------------------------------
signal run_inventory_changed(used_slots: int, max_slots: int)

# --- Depth-scaled junk placement (B3) ----------------------------------------
# Emitted by the JunkPlacer when a junk item is PLANNED into a piece (placement /
# telemetry). NOT pickup: the interactive grab + junk_picked_up are C2's.
signal junk_spawned(item_id: StringName, depth: int)

# --- Junk pickup (C2) --------------------------------------------------------
# Fired by a JunkPickup on every interact attempt — accepted OR rejected (full
# bag). Payload is PRIMITIVES ONLY (no JunkItem ref) so Telemetry serializes it
# straight to JSONL. `value` is base_sell_value SNAPSHOT at pickup time (already
# depth-scaled by B3) so later value-tuning never rewrites historical telemetry.
# `slot_size` rides along for capacity-pressure analytics ("value-per-slot taken
# vs left"). `accepted == false` means D1 rejected it (full / no fit) and the
# junk stayed in the world — still logged.
signal junk_picked_up(item_id: StringName, value: int, slot_size: int, world_pos: Vector2, accepted: bool)

# Fired by D2's drop gesture (one-line follow-up in D2, not wired here yet): the
# player dropped a carried item back into the world. The JunkSpawner subscribes
# and re-spawns a re-grabbable JunkPickup via spawn_one() at world_pos, so
# drop-to-swap is reversible. Carries the JunkItem ref (this is an in-engine
# gameplay event, not a telemetry row).
signal junk_dropped(item: JunkItem, world_pos: Vector2)

# Optional Telemetry hook: a band finished being populated with `count` pickups.
signal band_populated(count: int)

# --- Within-band depth (BUG2, M1.1) ------------------------------------------
# Pre-declared on `main` by the orchestrator (BUG2 §3 sequencing: the declaration
# must exist before any emitter ships; TEL adds the opposition signals later and
# must NOT re-declare this). EMITTED by GameState.set_current_depth() — BUG2 only
# emits, never declares. Edge-triggered: fires only when the player crosses into a
# piece of a different depth_index. depth_index = current within-band depth
# (entry == 0); max_depth = deepest reached this run. R1–R4 read
# GameState.current_depth_index / .current_dist_to_gate directly; this signal is
# the event-driven complement + Telemetry's depth row.
signal depth_changed(depth_index: int, max_depth: int)

# === M1.1 opposition signals (sole event_bus.gd edit, wave 1, owner = TEL) ====
# Declared centrally so wave-2 R1–R4 only EMIT — they never edit this file.
# `depth_changed` above is the BUG2 foundation signal (already on main); the
# eleven signals below are TEL's wave-1 add. Telemetry-row payloads are
# PRIMITIVES ONLY so Telemetry serializes straight to JSONL (TEL spec §3/§4).

# --- R1 Pursuing / awakening hazard (telemetry rows) -------------------------
signal hazard_awoke(depth: int, trigger: StringName)
signal hazard_caught(depth: int, run_t_ms: int)

# --- R2 Costlier return trip (telemetry row) ---------------------------------
signal return_cost_incurred(depth: int, cost_kind: StringName, magnitude: float)

# --- R3 Rising instability / exposure meter (telemetry rows) -----------------
signal exposure_crossed(level: int, depth: int, run_t_ms: int)
signal exposure_penalty(level: int, penalty_kind: StringName)

# --- R4 Maze / navigation risk (telemetry rows) ------------------------------
signal nav_branch_taken(depth: int, junction_degree: int)
signal nav_lost_proxy(metric: StringName, value: float, depth: int)

# --- J4 (M1.3) corridor-time summary (telemetry row) -------------------------
# Pre-declared on main before Wave 2's J4 (the M1.1 pre-declare rule). MainGame
# emits this once on run end with the per-run accumulated seconds the player spent
# in corridor vs room pieces; Telemetry folds it into an additive `corridor_summary`
# JSONL row (no schema-version bump, no run_ended arity change). Primitives only.
signal corridor_time_summary(corridor_s: float, room_s: float)

# --- R3 penalty / meter signals (R3 emits; TEL declares; not telemetry rows) --
# These let R3 apply speed/vision/clock penalties + drive the HUD WITHOUT editing
# game_state.gd. Signatures per R3 spec (R3_exposure_meter.md §3.3, §6).
signal exposure_speed_mult_changed(mult: float)   # player multiplies into stats.max_speed
signal exposure_vision_mult_changed(mult: float)  # R4 fog node multiplies into radius (no-op if R4 off)
signal exposure_clock_tax(seconds: float)         # A3 dive-clock subtracts from remaining light
signal exposure_meter_changed(value: float, maximum: float)  # greybox HUD exposure bar reads this

# === M1.4 signals (sole event_bus.gd edit this milestone, owner = K0) =========
# Pre-declared up front so K2/K3/K4/K5/K7 only EMIT — they never edit this file
# (the M1.1 pre-declare rule, M1.4 Breakdown §6/Phase-4 Lock). Telemetry-row
# payloads are PRIMITIVES ONLY (straight to JSONL). Names/signatures are the
# Phase-4-locked set (the dead `light_low()` removed above; its AudioDirector
# connect dropped in the same pass).

# --- K2 Quota (telemetry row + HUD/SellScreen drive) -------------------------
## Quota resolved at a run end (extract/death/timeout per quota_check_timing): the
## single telemetry row RG2 reads (met-rate, achieved-vs-target). Owner: K2.
signal quota_evaluated(run_number: int, target: int, achieved: int, met: bool)
## A met quota advanced the run-number + raised the target (HUD bump + "next quota").
signal quota_advanced(new_run_number: int, new_target: int)
## The roguelite wipe ran (the META fields cleared to defaults). Emitted by K2's
## wipe_meta() AFTER run_ended resolves (no run_ended arity change — separate meta op).
signal meta_wiped(prev_run_number: int)

# --- K3 Camera ---------------------------------------------------------------
## The fixed visible world-units actually applied this run ("how far could I see").
## Approach-agnostic telemetry. Owner: K3.
signal camera_view_set(visible_world_width: float, zoom: float)

# --- K4 Timer warning --------------------------------------------------------
## Fires ONCE when remaining dive time crosses the near-end warning threshold.
## `maximum` rides along for fraction symmetry with dive_clock_changed (line 36).
## (dive_clock_changed/dive_clock_timeout already exist above.) Owner: K4.
signal dive_clock_warning(seconds_remaining: float, maximum: float)

# --- K5a/b/c new hazards (telemetry rows; the kill flows through player_died) --
## A new-hazard kill (kind = &"pingpong"/&"bomb"/&"spike"). The shared kill-telemetry
## row for all three new hazards (parallels hazard_caught). Owners: K5a/K5b/K5c.
signal new_hazard_killed(kind: StringName, depth: int, run_t_ms: int)
## A bomb began its proximity pulse (telemetry: how often bombs are triggered). Owner: K5b.
signal bomb_pulse_started(depth: int, run_t_ms: int)

# --- K7 Exits ----------------------------------------------------------------
## Emitted once per band after exits are placed (telemetry: exit count + depth). Owner: K7.
signal exits_placed(count: int, depth: int)

# === M1.5 signals (sole event_bus.gd edit this milestone, owner = L0) =========
# Pre-declared up front so L1/L2 only EMIT — they never edit this file (the M1.1
# pre-declare rule, M1.5 Breakdown §6/Phase-4 Lock). Telemetry-row payloads are
# PRIMITIVES ONLY (straight to JSONL). The miss re-drop reuses the existing
# junk_dropped(item, world_pos) gameplay event above (the ref-carrying path).
# L5 declares NO signal: a non-lethal K5 hazard still emits new_hazard_killed; only
# the fail_run call is gated by the *_kills knobs.

# --- L1 Throwing (telemetry rows) --------------------------------------------
## A throw was launched (telemetry: how often the player uses agency). Owner: L1.
signal item_thrown(item_id: StringName, depth: int, run_t_ms: int)
## A thrown item MISSED (wall / max-range / lifetime) and was re-dropped. Telemetry
## row; the actual re-spawn flows through junk_dropped(item, world_pos). Owner: L1.
signal throw_missed(item_id: StringName, depth: int, run_t_ms: int)
## A thrown item KILLED a hazard-layer body. kind = &"pursuer" (R1) or a K5 kind
## (e.g. &"pingpong"). DEDICATED (not new_hazard_killed, whose kill direction is the
## OPPOSITE — hazard-kills-player — so reusing it would poison RG2's death counts).
## Owner: L1.
signal throw_killed_hazard(item_id: StringName, kind: StringName, depth: int, run_t_ms: int)

# --- L2 Spawn-room pursuer (telemetry row, rising-edge) ----------------------
## The pursuer changed chase/patrol state. state = &"patrol" (player outside the
## spawn room) or &"chase" (player inside). Rising-edge-latched (no per-frame storm).
## Owner: L2.
signal hazard_pursuer_state(state: StringName, depth: int, run_t_ms: int)

# === M1.6 signals (sole event_bus.gd edit this milestone, owner = M0) =========
# Pre-declared up front so M1/M2/M3/M4 only EMIT/CONNECT — they never edit this
# file (the M1.1 pre-declare rule, M1.6 Breakdown §6/Phase-4 Lock). These are
# FLOW + ECONOMY events that fire OUTSIDE a dive (Menu/Hub), so — unlike the dive
# telemetry rows above — they carry NO run_t_ms/depth (there is no run clock in
# the Menu/Hub). Primitives only (no Node refs — the App router resolves scenes by
# PATH, not reference). run_ended (line 10) is UNCHANGED — the router OBSERVES it
# to auto-return to the Hub, it never alters its arity. Final 8-signal set frozen
# in M0_foundation_router_economy.md RD-2 (the Phase-2 9th, return_to_hub_requested,
# was dropped: M1.6 only ever auto-returns).

# --- App flow / scene router (M2 emits dive_requested; App emits the rest) -----
## The player chose to depart on a dive (Hub departure-portal interact). The App
## router swaps in the dive scene. band_id = which band to dive (M1.6 single &"near").
signal dive_requested(band_id: StringName)
## The Hub scene is now live in the tree (fired by the router AFTER the swap, so
## HUD/audio/Telemetry observers read a settled Hub). Fires on every hub entry (from
## menu OR after a dive). No payload — the Hub reads meta (money/banked_junk/
## owned_items) directly.
signal hub_entered()
## A dive resolved and the player was returned to the Hub. reason = the run_ended
## reason (&"extract"/&"death"/&"timeout") so the Hub-return beat can show the dive-
## outcome readout (the quota line + sell tally re-homed from the retired SellScreen).
## Fires AFTER run_ended settled (router defers one frame). Pairs with hub_entered on
## the dive-return path.
signal returned_to_hub(reason: StringName)

# --- Hub shop (M3 emits; the Shop UI + GameState economy drive these) ---------
## The Shop UI opened (Hub shop-interactable). Telemetry: shop-open rate (RG2). No payload.
signal shop_opened()
## The Shop UI closed (returns control to the Hub). Telemetry: shop dwell (RG2).
signal shop_closed()
## The whole banked-junk pile was sold at the Shop → Money. ROLL-UP (one emit per
## sale, matching the single GameState.sell_banked_junk() call): item_count = how many
## items sold, total_value = their summed base_sell_value, money = the post-sale balance.
## Re-homes the SellScreen tally telemetry. Primitives only. (RD-2/OQ-4: roll-up, NOT per-item.)
signal item_sold(item_count: int, total_value: int, money: int)
## A purchase succeeded: item_id bought for `price`; money = post-debit balance.
## Emitted by GameState.purchase(). RG2 reads buy rate / spend. Primitives only.
signal item_purchased(item_id: StringName, price: int, money: int)
## A purchase was attempted but failed ("can't afford" OR "already owned"). money =
## current balance. Lets the Shop UI show the failure without GameState knowing about
## the UI. Emitted by GameState.purchase() on the reject paths.
signal purchase_failed(item_id: StringName, price: int, money: int)

# === M1.7 signals (sole event_bus.gd edit this milestone, owner = N0) =========
# A SINGLE tooling signal — the M1.7 "disable player art" debug toggle (N2). This
# is NOT a gameplay or telemetry signal and NOT a RunConfig knob: it stays OUTSIDE
# the config_menu MANIFEST / has_full_coverage() set, so the 89-knob count holds
# (breakdown §6.2). Emitted by the Meta-tab CheckButton (N2); the Player listens
# (N1's swap seam) and swaps AnimatedSprite2D <-> greybox + gates the movement-lock.
# `enabled == true` means "player art ON" (AnimatedSprite2D shown, greybox hidden,
# movement-lock active); `enabled == false` → greybox (M1.6 byte-for-byte, lock off).
# Default state is art ON.

# --- N2 debug view toggle (tooling, not gameplay) ----------------------------
signal debug_player_art_toggled(enabled: bool)
