extends Node
## Telemetry — opt-in, structured, timestamped JSONL event log (TDD §2; G1).
##
## Listens on EventBus and appends one JSON object per line to
## `user://telemetry/run_log.jsonl` so run-length + economy validation (the M1/M3
## feedback gates) can be computed offline by the QA/G4 analysis layer. Privacy:
## opt-in via the Settings flag (default OFF), no PII — when disabled NOTHING is
## written to disk.
##
## Design seams (per G1 spec + M1_As_Built):
##  * The schema (version + event-type strings) lives in `telemetry_schema.gd`,
##    shared with G2 tests and G4 analysis.
##  * The file I/O lives in `jsonl_writer.gd`, a dumb autoload-free seam G2 unit-
##    tests directly (autoloads don't resolve under `--headless --script`).
##  * This node only: reads the opt-in flag, connects signals, normalizes each
##    event into a schema row (stamping wall-clock + monotonic time + version +
##    ids), and appends via the writer.
##
## Real-signal adaptation (the G1 sketch was idealized; M1_As_Built wins):
##  * The locked lifecycle signals are `run_started(band_id, seed)` and the
##    FIXED-ARITY `run_ended(reason, duration_s, depth_reached)` — they carry NO
##    run_id, tier_label, banked_total or lost_total. So Telemetry mints a stable
##    per-run id from the seed, and reconstructs banked/lost totals from the
##    economy signals it sees during the run (haul_banked + junk_picked_up).
##  * `junk_picked_up(item_id, value, slot_size, world_pos, accepted)` (C2) — has
##    no run_id/depth; we stamp current_depth from GameState and only count value
##    for accepted pickups.
##  * `haul_banked(total_value)` (E1/E3) — the kept/banked amount on BOTH extract
##    and fail; we cache it so run_ended can report banked_total and derive the
##    amount-lost-on-fail (E3's value_lost detail, which the locked run_ended could
##    not carry — G1 owns this dedicated `junk_lost` row).
##  * `currency_changed(kind, delta, source)` — drives currency-in-by-source rows.
##  * `exposure_threshold_crossed(threshold)` — exposure pacing rows.

const Schema := preload("res://systems/telemetry/telemetry_schema.gd")
const JsonlWriterScript := preload("res://systems/telemetry/jsonl_writer.gd")
const SettingsScript := preload("res://systems/settings/settings.gd")
const BuildVersionScript := preload("res://systems/version.gd")  # G3: build-id stamp

var _enabled: bool = false
var _writer: JsonlWriter = null
var _session_id: String = ""
var _run_id: String = ""
var _run_t0_ms: int = 0

# --- Per-run economy bookkeeping (reconstructs the totals the locked run_ended
#     signal cannot carry). Reset every run_started. -----------------------------
var _accepted_value: int = 0   # sum of accepted-pickup values seen this run
var _last_banked: int = 0      # latest haul_banked total (kept on extract OR fail)
var _max_depth: int = 0        # highest depth reached this run


func _ready() -> void:
	# session_id: one stable id for the whole process lifetime (logging infra,
	# not gameplay state — so it lives here, not in GameState).
	_session_id = "s_" + _short_id(Time.get_unix_time_from_system() as int)
	_enabled = SettingsScript.get_telemetry_enabled()

	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.band_entered.connect(_on_band_entered)
	EventBus.junk_picked_up.connect(_on_junk_picked_up)
	EventBus.haul_banked.connect(_on_haul_banked)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.exposure_threshold_crossed.connect(_on_exposure_threshold)

	# M1.1 opposition listeners (TEL spec §5b). Each opposition (R1–R4) emits its
	# own EventBus signal only when its config is enabled, so a disabled opposition
	# writes nothing — _emit_row already short-circuits when telemetry is OFF.
	EventBus.hazard_awoke.connect(_on_hazard_awoke)
	EventBus.hazard_caught.connect(_on_hazard_caught)
	EventBus.return_cost_incurred.connect(_on_return_cost_incurred)
	EventBus.exposure_crossed.connect(_on_exposure_crossed)
	EventBus.exposure_penalty.connect(_on_exposure_penalty)
	EventBus.nav_branch_taken.connect(_on_nav_branch_taken)
	EventBus.nav_lost_proxy.connect(_on_nav_lost_proxy)
	# J4 (M1.3): per-run corridor-time summary (additive row; no schema/arity change).
	EventBus.corridor_time_summary.connect(_on_corridor_time_summary)
	# Debug/dev: the K-key debug_kill emits player_died(&"death"). Log it so a debug
	# kill is self-identifying in the log instead of a bare, reasonless cause=death
	# run_ended (additive row; no schema/arity change). Only fires from debug_kill.
	EventBus.player_died.connect(_on_player_died)


## Public toggle entry point for the settings UI. Persists the flag and applies it
## live. Disabling stops writing immediately but KEEPS rows already on disk
## (consent was in effect when they were captured; G4 keys on complete run pairs).
func set_enabled(value: bool) -> void:
	SettingsScript.set_telemetry_enabled(value)
	_enabled = value
	if not _enabled and _writer != null:
		_writer.close()
		_writer = null


func is_enabled() -> bool:
	return _enabled


# --- Row assembly + write ----------------------------------------------------
func _emit_row(type: String, data: Dictionary) -> void:
	if not _enabled:
		return
	if _writer == null:
		_writer = JsonlWriterScript.new(Schema.LOG_PATH)
		if not _writer.is_open():
			# Open failed (e.g. read-only user dir): drop the writer and bail. Never
			# crash the game over telemetry; we retry the open on the next event.
			_writer = null
			return
	var t_ms: int = Time.get_ticks_msec() - _run_t0_ms
	var row := {
		"v": Schema.SCHEMA_VERSION,
		"ts": Time.get_datetime_string_from_system(true) + "Z",  # UTC ISO-8601
		"t_ms": t_ms,
		"run_id": _run_id,
		"session_id": _session_id,
		"type": type,
		"data": data,
	}
	_writer.append_line(JSON.stringify(row))


# --- Signal handlers ---------------------------------------------------------
func _on_run_started(band_id: StringName, seed: int) -> void:
	_run_t0_ms = Time.get_ticks_msec()
	_run_id = "r_" + _short_id(seed)
	_accepted_value = 0
	_last_banked = 0
	_max_depth = 0
	# G3: stamp the build id on the run_started row so a feedback report + its JSONL
	# tie to one exact build. Extra `data` field only — the schema envelope + every
	# other row are untouched (G2 tests assert envelope keys, not run_started payload).
	# M1.1 (TEL): also snapshot the active RunConfig flat dict under `run_config` so
	# every run is a labelled experiment (additive `data` field — NOT a schema bump).
	# BUG6 (M1.3): also stamp the enabled-but-inert opposition ids so a dead-config
	# run is self-identifying in the log and RG2 can filter it (additive `data` field,
	# [] for the all-off control — same additive pattern, NO schema bump).
	# K2 (M1.4, Q8): also stamp the LIVE quota meta (run_number + quota_target) so RG2
	# can segment in-progress / abandoned runs by quota pressure even without a clean end.
	# Additive `data` keys only — no schema bump, no run_ended arity change. For an all-off
	# run these are the inert defaults (1 / 0), so the row stays self-identifying.
	var quota_meta: Dictionary = _active_quota_meta()
	_emit_row(Schema.RUN_STARTED, {
		"band_id": String(band_id),
		"seed": seed,
		"build": BuildVersionScript.id(),
		"run_config": _active_run_config_dict(),
		"inert_enabled_oppositions": _active_inert_oppositions(),
		"quota_run_number": quota_meta.get("run_number", 1),
		"quota_target": quota_meta.get("quota_target", 0),
	})


func _on_band_entered(band_id: StringName, depth: int) -> void:
	# Fire band_depth_reached once per NEW max depth (the funnel-defining moment).
	if depth > _max_depth:
		_max_depth = depth
		_emit_row(Schema.BAND_DEPTH_REACHED, {"band_id": String(band_id), "depth": depth})
		if _writer != null:
			_writer.flush()  # high-value event → flush for crash safety


func _on_junk_picked_up(item_id: StringName, value: int, slot_size: int, _world_pos: Vector2, accepted: bool) -> void:
	var depth: int = _current_depth()
	if accepted:
		_accepted_value += value
	_emit_row(Schema.JUNK_PICKED_UP, {
		"item_id": String(item_id),
		"value": value,
		"slot_size": slot_size,
		"depth": depth,
		"accepted": accepted,
	})


func _on_haul_banked(total_value: int) -> void:
	# Emitted on BOTH extract and fail (E1/E3). Cache it for run_ended's totals and
	# log a per-bank row (depth-of-bank distribution for G4). Flush: high-value.
	_last_banked = total_value
	_emit_row(Schema.JUNK_BANKED, {"value": total_value, "depth": _current_depth()})
	if _writer != null:
		_writer.flush()


func _on_currency_changed(kind: StringName, delta: int, source: StringName) -> void:
	# Currency-IN only (positive deltas) tagged by source — feeds the currency
	# in-by-source analysis (sell / extract / pockets). Sinks are out of M1 scope.
	if delta <= 0:
		return
	_emit_row(Schema.CURRENCY_IN, {"kind": String(kind), "delta": delta, "source": String(source)})


func _on_exposure_threshold(threshold: int) -> void:
	_emit_row(Schema.EXPOSURE_THRESHOLD, {"threshold": threshold})


# --- M1.1 opposition handlers (TEL spec §5b) ---------------------------------
# Payloads are PRIMITIVES ONLY (JSONL-clean). TEL trusts the emitter's `depth`
# (authoritative at the event moment) and stamps run-elapsed itself where the
# spec calls for it. Opt-in is inherited from _emit_row's short-circuit.

# --- R1 ----------------------------------------------------------------------
func _on_hazard_awoke(depth: int, trigger: StringName) -> void:
	_emit_row(Schema.HAZARD_AWOKE, {"depth": depth, "trigger": String(trigger)})


func _on_hazard_caught(depth: int, _run_t_ms: int) -> void:
	# TEL stamps run-elapsed itself for consistency with the envelope t_ms; the
	# signal's run_t_ms arg is emitter-convenience only (R1 may pass 0).
	_emit_row(Schema.HAZARD_CAUGHT, {"depth": depth, "run_t_ms": _elapsed_ms()})
	if _writer != null:
		_writer.flush()  # high-value: precedes a death run_ended


func _on_player_died(cause: StringName) -> void:
	# Debug-only: player_died is emitted ONLY by the K-key debug_kill action
	# (game_state.gd). Log a self-identifying row so the resulting cause=death
	# run_ended is no longer a reasonless death in the log. Like HAZARD_CAUGHT this
	# precedes the death run_ended and stamps run-elapsed itself; flush for crash safety.
	_emit_row(Schema.DEBUG_KILL, {"cause": String(cause), "depth": _current_depth(), "run_t_ms": _elapsed_ms()})
	if _writer != null:
		_writer.flush()


# --- R2 ----------------------------------------------------------------------
func _on_return_cost_incurred(depth: int, cost_kind: StringName, magnitude: float) -> void:
	_emit_row(Schema.RETURN_COST_INCURRED, {
		"depth": depth,
		"cost_kind": String(cost_kind),
		"magnitude": magnitude,
	})


# --- R3 ----------------------------------------------------------------------
func _on_exposure_crossed(level: int, depth: int, _run_t_ms: int) -> void:
	# TEL stamps run-elapsed itself (see _on_hazard_caught note).
	_emit_row(Schema.EXPOSURE_CROSSED, {"level": level, "depth": depth, "run_t_ms": _elapsed_ms()})
	if _writer != null:
		_writer.flush()  # threshold crossing = funnel-defining


func _on_exposure_penalty(level: int, penalty_kind: StringName) -> void:
	_emit_row(Schema.EXPOSURE_PENALTY, {"level": level, "penalty_kind": String(penalty_kind)})


# --- R4 ----------------------------------------------------------------------
func _on_nav_branch_taken(depth: int, junction_degree: int) -> void:
	_emit_row(Schema.NAV_BRANCH_TAKEN, {"depth": depth, "junction_degree": junction_degree})


func _on_nav_lost_proxy(metric: StringName, value: float, depth: int) -> void:
	_emit_row(Schema.NAV_LOST_PROXY, {"metric": String(metric), "value": value, "depth": depth})


# --- J4 (M1.3): corridor-time summary ----------------------------------------
## One per-run row of seconds-in-corridor vs. seconds-in-room (+ the derived corridor_frac),
## so RG2 can compare "fraction of run spent in corridor" across M1.0–M1.3 on one axis directly
## instead of inferring it. Additive event type (SCHEMA_VERSION stays 1); does NOT touch the
## run_ended row/signal. Emitted by MainGame on run end (extract/death/timeout). corridor_frac is
## 0.0 when the run logged no tracked time (e.g. a frame-0 quit) so the field is always present.
func _on_corridor_time_summary(corridor_s: float, room_s: float) -> void:
	var total := corridor_s + room_s
	_emit_row(Schema.CORRIDOR_SUMMARY, {
		"corridor_s": corridor_s,
		"room_s": room_s,
		"corridor_frac": (corridor_s / total) if total > 0.0 else 0.0,
	})
	if _writer != null:
		_writer.flush()   # end-of-run summary, like run_ended


func _on_run_ended(reason: StringName, duration_s: float, depth_reached: int) -> void:
	var cause := String(reason)
	var banked_total: int = _last_banked
	# Reconstruct lost_total the locked run_ended signature cannot carry:
	#  * extract → the whole carried haul was banked, nothing lost.
	#  * death/timeout (fail) → kept = haul_banked(kept_value); lost = carried - kept.
	#  * quit → treat the whole carried haul as lost (no bank happened).
	var lost_total: int = 0
	match cause:
		"extract":
			lost_total = 0
		"quit":
			lost_total = maxi(_accepted_value, 0)
		_:  # death / timeout — the E3 fail path
			lost_total = maxi(_accepted_value - banked_total, 0)

	# G1-owned dedicated amount-lost-on-fail row (the E3 seam: value_lost could not
	# ride on the fixed-arity run_ended, so it lived only on a debug print).
	if lost_total > 0:
		_emit_row(Schema.JUNK_LOST, {
			"value": lost_total,
			"depth": depth_reached,
			"cause": cause,
		})

	_emit_row(Schema.RUN_ENDED, {
		"cause": cause,
		"duration_s": duration_s,
		"banked_total": banked_total,
		"lost_total": lost_total,
		"max_depth": maxi(_max_depth, depth_reached),
	})
	if _writer != null:
		_writer.flush()


func _exit_tree() -> void:
	if _writer != null:
		_writer.flush()
		_writer.close()
		_writer = null


# --- Helpers -----------------------------------------------------------------
## Resolve current dive depth from GameState if present (autoload may be absent in
## a bare writer unit test; default 0). Looked up via the SceneTree, not the
## compile-time global, so this stays robust under headless scene runs.
func _current_depth() -> int:
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		return gs.current_depth
	return 0


## Resolve the active RunConfig's flat dict from GameState (R0's read surface) for
## the run_started config snapshot. Same /root lookup as _current_depth so it stays
## robust under headless scene runs; empty dict if absent/null so the row never
## crashes and the analysis can detect "config unknown" (TEL spec §2).
func _active_run_config_dict() -> Dictionary:
	var gs := get_node_or_null("/root/GameState")
	if gs != null and gs.active_run_config != null:
		return gs.active_run_config.to_flat_dict()
	return {}


## K2 (M1.4, Q8): the live quota meta (run_number + quota_target) from GameState, via
## the same /root lookup as the other run_started helpers so it stays robust headless.
## Defaults (1 / 0) when GameState is absent so the row never crashes.
func _active_quota_meta() -> Dictionary:
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		return {"run_number": gs.run_number, "quota_target": gs.quota_target}
	return {"run_number": 1, "quota_target": 0}


## BUG6 (M1.3): the enabled-but-inert opposition ids for the active config, as a
## plain Array (JSONL-safe) for the run_started row. Rides the same /root/GameState
## read surface as _active_run_config_dict; [] when no config (clean log) AND [] for
## the all-off control (no master enabled). RG2 filters dead-config runs on this.
func _active_inert_oppositions() -> Array:
	var gs := get_node_or_null("/root/GameState")
	if gs != null and gs.active_run_config != null:
		var out: Array = []
		for id in gs.active_run_config.inert_enabled_oppositions():
			out.append(String(id))
		return out
	return []


## Monotonic run-elapsed milliseconds (same basis as the envelope t_ms). TEL stamps
## this onto hazard_caught / exposure_crossed so their times are authoritative and
## consistent regardless of the emitter's own clock (TEL spec §3 / §5b).
func _elapsed_ms() -> int:
	return Time.get_ticks_msec() - _run_t0_ms


## Short stable hex id from an int (run/session id). Not cryptographic — just a
## compact, reproducible-from-seed handle for correlating rows in one run.
func _short_id(value: int) -> String:
	return "%06x" % (absi(value) % 0x1000000)
