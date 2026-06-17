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
