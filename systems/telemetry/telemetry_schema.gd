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

## On-disk log path. One rolling JSONL file for M1 (rotation deferred to G4 if the
## file grows painful). `user://` resolves to the per-OS app-data dir.
const LOG_PATH: String = "user://telemetry/run_log.jsonl"

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
const HAZARD_AWOKE: String = "hazard_awoke"                  # R1: dormant→awake
const HAZARD_CAUGHT: String = "hazard_caught"                # R1: catch-radius reached
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

# --- Debug/dev events --------------------------------------------------------
# The debug-only `debug_kill` action (key K, game_state.gd:_unhandled_input) emits
# player_died(&"death"), which otherwise ends the run as a bare `cause=death` with NO
# preceding hazard row — indistinguishable in the log from a phantom/unexplained death.
# This row makes a K-press kill self-identifying (it precedes the death run_ended, like
# HAZARD_CAUGHT). ADDITIVE event-type string — SCHEMA_VERSION STAYS 1.
const DEBUG_KILL: String = "debug_kill"                      # debug_kill action → player_died

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
	# M1.1 opposition rows
	HAZARD_AWOKE,
	HAZARD_CAUGHT,
	RETURN_COST_INCURRED,
	EXPOSURE_CROSSED,
	EXPOSURE_PENALTY,
	NAV_BRANCH_TAKEN,
	NAV_LOST_PROXY,
	# J4 (M1.3) corridor-time summary row
	CORRIDOR_SUMMARY,
	# Debug/dev rows
	DEBUG_KILL,
]

## The envelope keys every row carries (used by tests to assert structure).
const ENVELOPE_KEYS: Array[String] = ["v", "ts", "t_ms", "run_id", "session_id", "type", "data"]

## M1 `run_ended.cause` enum.
const RUN_END_CAUSES: Array[String] = ["extract", "death", "quit", "timeout"]
