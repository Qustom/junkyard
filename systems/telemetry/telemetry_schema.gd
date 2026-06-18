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
]

## The envelope keys every row carries (used by tests to assert structure).
const ENVELOPE_KEYS: Array[String] = ["v", "ts", "t_ms", "run_id", "session_id", "type", "data"]

## M1 `run_ended.cause` enum.
const RUN_END_CAUSES: Array[String] = ["extract", "death", "quit", "timeout"]
