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
## The SHA is BAKED at build time into a git-ignored generated artifact
## (`systems/build_info_gen.gd`, written by `tools/stamp_build.sh` in CI and locally
## before a playtest build) and read at runtime — so an EXPORTED binary, where `git`
## and `.git` are absent, still knows its exact commit (I5, M1.2). The resolution
## chain (I5 Resolved Q2/Q4):
##   1. baked artifact (`build_info_gen.gd` const SHORT_SHA) — present in any stamped
##      build (CI export, local stamped run); ships inside the export pack.
##   2. editor/dev fallback — read `git rev-parse --short HEAD` live via OS.execute
##      so an un-stamped editor run still shows the true working SHA.
##   3. neutral FALLBACK_SHA sentinel — an UN-stamped, non-editor build reports
##      "0000000" so a stale/un-stamped build is OBVIOUS in the log rather than
##      masquerading as a real commit (the I5 lesson: a quiet plausible SHA masked a
##      stale binary for a whole playtest).
## The date is resolved at boot. Telemetry stamps this string onto the run_started
## row so a feedback report + its JSONL tie to one exact build (G3 + G1 correlation).

## Milestone prefix. Bump per milestone (m1 → m2 …).
const MILESTONE := "m1"

## Neutral "unknown" sentinel — NOT a real old SHA. An un-stamped, non-editor build
## resolves to this, making "this binary was built without the stamp step" legible in
## the telemetry log instead of lying about a commit (I5 Resolved Q4).
const FALLBACK_SHA := "0000000"

## The git-ignored generated artifact `tools/stamp_build.sh` writes the real short
## SHA into (a `const SHORT_SHA` script). Read at runtime; ships inside the export.
const GEN_PATH := "res://systems/build_info_gen.gd"


## The full build id, e.g. "m1-20260619-691d9da" (or "...-691d9da+dirty" off an
## uncommitted tree). Stable within one process.
static func id() -> String:
	return "%s-%s-%s" % [MILESTONE, _date_stamp(), short_sha()]


## The git short SHA, resolved through the I5 chain: baked artifact → editor-git →
## neutral sentinel. Never empty.
static func short_sha() -> String:
	# 1) Stamped build (CI export / local stamped run): the baked artifact ships in
	#    the pack, so no git is needed at runtime.
	if ResourceLoader.exists(GEN_PATH):
		var gen: GDScript = load(GEN_PATH) as GDScript
		if gen != null:
			var consts := gen.get_script_constant_map()
			var baked := String(consts.get("SHORT_SHA", "")).strip_edges()
			if baked != "":
				return baked
	# 2) Editor / dev run with a working tree: read HEAD live (cheap, dev-only).
	#    Gives a true SHA in the editor even without running the stamp step.
	if OS.has_feature("editor"):
		var out: Array = []
		if OS.execute("git", ["rev-parse", "--short", "HEAD"], out) == 0 and not out.is_empty():
			var sha := String(out[0]).strip_edges()
			if sha != "":
				return sha
	# 3) Last resort: neutral sentinel so "I don't know my SHA" is visible in the log.
	return FALLBACK_SHA


## UTC date stamp YYYYMMDD, resolved at call time.
static func _date_stamp() -> String:
	var d := Time.get_datetime_dict_from_system(true)
	return "%04d%02d%02d" % [int(d.year), int(d.month), int(d.day)]
