class_name BuildVersion
extends RefCounted
## BuildVersion — the build-identity stamp (G3).
##
## A small, autoload-free static helper (mirrors the Settings pattern: a UI/infra
## concern, NOT gameplay meta-state, so it does not enter the run/meta save schema
## or the autoload list). It produces a single human-readable + reproducible build
## id of the form:
##     m1-<YYYYMMDD>-<gitshortsha>
## per G3's "Build identity" recommendation (date for humans, SHA for exact repro).
##
## The SHA is BAKED at build time into ProjectSettings (the CI/export step writes
## `application/config/build_sha`), with a committed fallback for editor/dev runs
## where that setting is absent. The date is resolved at boot (the day the build
## runs is close enough to the nightly date for tester correlation, and needs no
## CI plumbing). Telemetry stamps this string onto the run_started row so a feedback
## report + its JSONL can be tied to one exact build (G3 + G1 correlation).

## Milestone prefix. Bump per milestone (m1 → m2 …).
const MILESTONE := "m1"

## Committed fallback SHA — overwritten live by ProjectSettings("application/config/build_sha")
## when CI/export bakes the real `git rev-parse --short HEAD` in. Kept current-ish so a
## bare dev run still produces a plausible, non-empty id.
const FALLBACK_SHA := "852b6e2"

## Project-settings key the export/CI step writes the real short SHA into.
const SHA_SETTING := "application/config/build_sha"


## The full build id, e.g. "m1-20260618-852b6e2". Stable within one process.
static func id() -> String:
	return "%s-%s-%s" % [MILESTONE, _date_stamp(), short_sha()]


## The git short SHA: the baked ProjectSettings value if present, else the
## committed fallback. Never empty.
static func short_sha() -> String:
	if ProjectSettings.has_setting(SHA_SETTING):
		var baked := String(ProjectSettings.get_setting(SHA_SETTING, "")).strip_edges()
		if baked != "":
			return baked
	return FALLBACK_SHA


## UTC date stamp YYYYMMDD, resolved at call time.
static func _date_stamp() -> String:
	var d := Time.get_datetime_dict_from_system(true)
	return "%04d%02d%02d" % [int(d.year), int(d.month), int(d.day)]
