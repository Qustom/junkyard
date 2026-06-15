extends Node
## Telemetry — opt-in, structured, timestamped event log (TDD §2).
##
## Listens on EventBus and appends JSONL events that settle the three open
## design questions (run-length, economy, exposure pacing) with real play data.
## Privacy: opt-in via a settings toggle, no PII. Required for the M1/M3
## telemetry feedback gates. Analysis over this log is the QA subagent's job.

const LOG_PATH := "user://telemetry/events.jsonl"

var enabled: bool = false  # flipped on by the settings toggle (UI subagent, M5)

func _ready() -> void:
	EventBus.run_started.connect(func(band, seed): log_event(&"run_started", {"band": str(band), "seed": seed}))
	EventBus.run_ended.connect(func(reason, dur, depth): log_event(&"run_ended", {"reason": str(reason), "duration_s": dur, "depth": depth}))
	EventBus.currency_changed.connect(func(kind, delta, source): log_event(&"currency", {"kind": str(kind), "delta": delta, "source": str(source)}))
	EventBus.exposure_threshold_crossed.connect(func(t): log_event(&"exposure_threshold", {"threshold": t}))
	EventBus.player_died.connect(func(cause): log_event(&"death", {"cause": str(cause)}))

func log_event(type: StringName, fields: Dictionary) -> void:
	if not enabled:
		return
	DirAccess.make_dir_recursive_absolute(LOG_PATH.get_base_dir())
	var record := {"t": Time.get_unix_time_from_system(), "type": str(type)}
	record.merge(fields)
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(record))
	f.close()
