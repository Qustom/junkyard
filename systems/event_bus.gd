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
signal light_low()
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
