extends RefCounted
## Telemetry JSONL schema — the shared contract (G1).
##
## A tiny const/enum module that defines the JSONL schema version and the set of
## event-type strings. Imported by `telemetry.gd` (the writer/listener), reused by
## G2 tests and G4 analysis so producers and consumers share ONE source of truth
## for field names and the version stamp. No behaviour lives here — pure constants.
##
## Bump SCHEMA_VERSION on any breaking change to the row envelope or any payload
## shape, and document the change in the G1 spec's "JSONL event schema" section so
## G4 analysis knows how to read older logs.

class_name TelemetrySchema

## Envelope schema version. v1 = the M1 wave-5 row shape:
##   {v, ts, t_ms, run_id, session_id, type, data:{...}}
const SCHEMA_VERSION: int = 1

## On-disk log path. One rolling JSONL file for M1. `user://` resolves to the
## per-OS app-data dir. Rotation (V7, M1.12): `JsonlWriter` itself size-caps this
## file at `MAX_LOG_BYTES`, rolling the overflow to `LOG_PATH + ".1"` — this
## constant always names the freshest, currently-writable log, rotated or not.
const LOG_PATH: String = "user://telemetry/run_log.jsonl"

## Size cap (bytes) for the active log before `JsonlWriter` rotates the current
## file to a single `.1` generation and starts a fresh one at `LOG_PATH`. File-
## lifecycle only — no row/envelope shape change, no SCHEMA_VERSION bump.
const MAX_LOG_BYTES: int = 2 * 1024 * 1024

# --- Event types (string constants; the `type` field on every row) -----------
# Kept as plain Strings (not an enum) so they serialize directly into JSON and
# read identically in the log, in tests, and in the analysis layer.
const RUN_STARTED: String = "run_started"
const RUN_ENDED: String = "run_ended"
const JUNK_PICKED_UP: String = "junk_picked_up"
const JUNK_BANKED: String = "junk_banked"
const JUNK_LOST: String = "junk_lost"        # amount-lost-on-fail row (E3 seam → G1)
const BAND_DEPTH_REACHED: String = "band_depth_reached"
const CURRENCY_IN: String = "currency_in"    # currency-in tagged by source (sell/extract/pockets)
const EXPOSURE_THRESHOLD: String = "exposure_threshold"

# --- M1.1 opposition event types (TEL spec §3) -------------------------------
# Additive `type` strings + `data` payloads only — NO envelope/schema bump. Each
# maps 1:1 to a pre-declared EventBus signal (TEL spec §4); R1–R4 emit, TEL logs.
# (M1.12/V2: R1's HAZARD_AWOKE / HAZARD_CAUGHT row types were retired with their
# legacy signals — the awoke/hit-player moments now log as OPPOSITION_EVENT rows.)
const RETURN_COST_INCURRED: String = "return_cost_incurred"  # R2: retreat/egress cost applied
const EXPOSURE_CROSSED: String = "exposure_crossed"          # R3: meter crosses a threshold level
const EXPOSURE_PENALTY: String = "exposure_penalty"          # R3: penalty fires at a crossed level
const NAV_BRANCH_TAKEN: String = "nav_branch_taken"          # R4: junction degree > 2 traversed
const NAV_LOST_PROXY: String = "nav_lost_proxy"              # R4: lost-proxy metric crosses threshold

# --- J4 (M1.3) corridor-time summary -----------------------------------------
# One per-run summary row of seconds-in-corridor vs. seconds-in-room (+ the derived
# corridor_frac), so the re-gate measures "time in hallway" directly instead of inferring it.
# ADDITIVE event-type string (like NAV_BRANCH_TAKEN / JUNK_LOST) — SCHEMA_VERSION STAYS 1.
const CORRIDOR_SUMMARY: String = "corridor_summary"          # J4: per-run corridor vs. room time

# --- M1.4 new-hazard kill (K5a/K5b/K5c) --------------------------------------
# (M1.12/V2: the NEW_HAZARD_KILLED row type was retired with its legacy signal — a
# K5 fatal contact now logs as an OPPOSITION_EVENT row with event=&"hit_player" and
# id=<kind>, attributable by kind exactly as before.)

# --- Debug/dev events --------------------------------------------------------
# The debug-only `debug_kill` action (key K, game_state.gd:_unhandled_input) emits
# player_died(&"death"), which otherwise ends the run as a bare `cause=death` with NO
# preceding hazard row — indistinguishable in the log from a phantom/unexplained death.
# This row makes a K-press kill self-identifying (it precedes the death run_ended, like
# HAZARD_CAUGHT). ADDITIVE event-type string — SCHEMA_VERSION STAYS 1.
const DEBUG_KILL: String = "debug_kill"                      # debug_kill action → player_died

# --- M1.9 (S4) generic opposition rows + sweep hygiene ------------------------
# The S0-declared generic signals (opposition_event / opposition_killed_player) get
# Telemetry subscribers in S4 so SG2 can count spawns/hits/deaths BY DEF ID without a
# per-type row per new hazard. Entities DUAL-EMIT the legacy per-type signals alongside
# these until post-gate retirement — analysis must count from ONE family (SG2 reads the
# generic one). ADDITIVE event-type strings — SCHEMA_VERSION STAYS 1.
const OPPOSITION_EVENT: String = "opposition_event"          # any opposition lifecycle moment, by id
const OPPOSITION_KILLED_PLAYER: String = "opposition_killed_player"  # a def ACTUALLY ended the run
# A debug-menu LIVE tweak (respawn-with-new-params) perturbed the active run mid-flight:
# the moment is auditable here, and the run's run_ended row stamps debug_dirty: true so
# SG2 filters the whole run from the gate cohort (S4 §3.6). ADDITIVE — SCHEMA STAYS 1.
const DEBUG_DIRTIED: String = "debug_dirtied"                # debug_run_dirtied → run is experiment-dirty

## Every event-type string, for tests/validators that want to assert a row's
## `type` is known.
const ALL_TYPES: Array[String] = [
	RUN_STARTED,
	RUN_ENDED,
	JUNK_PICKED_UP,
	JUNK_BANKED,
	JUNK_LOST,
	BAND_DEPTH_REACHED,
	CURRENCY_IN,
	EXPOSURE_THRESHOLD,
	# M1.1 opposition rows (V2 retired HAZARD_AWOKE / HAZARD_CAUGHT → OPPOSITION_EVENT)
	RETURN_COST_INCURRED,
	EXPOSURE_CROSSED,
	EXPOSURE_PENALTY,
	NAV_BRANCH_TAKEN,
	NAV_LOST_PROXY,
	# J4 (M1.3) corridor-time summary row
	CORRIDOR_SUMMARY,
	# (V2 retired NEW_HAZARD_KILLED → OPPOSITION_EVENT event=&"hit_player")
	# Debug/dev rows
	DEBUG_KILL,
	# M1.9 (S4) generic opposition rows + sweep hygiene
	OPPOSITION_EVENT,
	OPPOSITION_KILLED_PLAYER,
	DEBUG_DIRTIED,
]

## The envelope keys every row carries (used by tests to assert structure).
const ENVELOPE_KEYS: Array[String] = ["v", "ts", "t_ms", "run_id", "session_id", "type", "data"]

## M1 `run_ended.cause` enum.
const RUN_END_CAUSES: Array[String] = ["extract", "death", "quit", "timeout"]
