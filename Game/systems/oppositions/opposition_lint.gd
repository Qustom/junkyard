class_name OppositionLint
extends RefCounted
## OppositionLint (M1.9 S4) — the config-trap detector GENERALIZED to OppositionDefs
## (S4 §3.4). A static helper kept OUT of run_config.gd so the config schema never
## imports content (defs are data the CONTENT layer owns; RunConfig must stay loadable
## with zero defs on disk). Mirrors inert_enabled_oppositions()'s contract exactly:
## WARN-ONLY, never blocks Start, consumed by BOTH the CFG warn line and the
## run_started telemetry stamp so a dead-config run is self-identifying (BUG6 lineage).
##
## Two trap classes per cfg-ENABLED def id (deck-authored defs are author-owned content
## verified at S7 authoring time — the menu never warns about a band's own deck,
## S4 §8.1 Q8):
##   1. `<id>:<param_key>` — a param_schema entry flagged `trap_if_neutral: true` whose
##      EFFECTIVE value (override ?? authored default) is neutral (0 / 0.0 / false).
##      The flag is S2-authored schema metadata (S4 §8.1 Q6 — no hand-list here).
##   2. `<id>:neutral_card` — the Wave-3 close-out S4 flag (Director Reviewed
##      2026-07-03): S2 authored every spawn card NEUTRAL, so enabling a def id ALONE
##      spawns zero — the deck lane's count is base_count + floor(count_per_depth *
##      depth), and a card whose effective base_count <= 0 AND count_per_depth <= 0
##      can never place an instance at any depth. Enable-without-a-count is the exact
##      "enabled but silently inert" shape BUG6 exists to catch.

const DEF_PATH_FMT := "res://data/oppositions/%s.tres"


## Core check over an explicit def list (the ConfigMenu passes its loaded _defs).
## `defs` entries not named in cfg.oppositions_enabled are ignored; an enabled id with
## NO def in the list is skipped here (the missing-def fail-loud belongs to the
## EncounterBuilder / the menu's own load errors, not the trap line).
static func inert_enabled_defs(cfg: RunConfig, defs: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if cfg == null or cfg.oppositions_enabled.is_empty():
		return out
	var by_id: Dictionary = {}
	for d: Variant in defs:
		var def := d as OppositionDef
		if def != null:
			by_id[String(def.id)] = def
	for id: StringName in cfg.oppositions_enabled:
		var def: OppositionDef = by_id.get(String(id), null)
		if def == null:
			continue
		var ov: Dictionary = _overrides_for(cfg, id)
		# 1. schema-flagged load-bearing params at their neutral value.
		for entry: Dictionary in def.param_schema:
			if not bool(entry.get("trap_if_neutral", false)):
				continue
			var key := String(entry.get("key", ""))
			if key == "":
				continue
			if _is_neutral(ov.get(key, def.params.get(key, null))):
				out.append("%s:%s" % [String(id), key])
		# 2. the fully-neutral spawn card (enable-alone spawns zero — Wave-3 close-out).
		var base := int(ov.get("base_count", def.params.get("base_count", 0)))
		var per_depth := float(ov.get("count_per_depth", def.params.get("count_per_depth", 0.0)))
		if base <= 0 and per_depth <= 0.0:
			out.append("%s:neutral_card" % String(id))
	return out


## Convenience for Telemetry's run_started stamp: lazily load ONLY the enabled ids'
## defs (all-off / empty lever loads NOTHING — the lazy-load discipline holds), then
## run the core check. A missing/mistyped def file is silently skipped here (the
## builder push_errors it at populate time; the trap line reports TRAPS, not typos).
static func inert_enabled_defs_for(cfg: RunConfig) -> PackedStringArray:
	if cfg == null or cfg.oppositions_enabled.is_empty():
		return PackedStringArray()
	var defs: Array = []
	for id: StringName in cfg.oppositions_enabled:
		var path := DEF_PATH_FMT % String(id)
		if ResourceLoader.exists(path):
			var def := load(path) as OppositionDef
			if def != null:
				defs.append(def)
	return inert_enabled_defs(cfg, defs)


## S4 §8.1 Q6: "neutral" = 0 / 0.0 / false for M1.9 (sufficient for every shipped
## param; a per-entry neutral_value field is a future extension, not built now).
static func _is_neutral(v: Variant) -> bool:
	if v is bool:
		return not bool(v)
	if v is int:
		return int(v) == 0
	if v is float:
		return is_equal_approx(float(v), 0.0)
	return false   # non-numeric/absent params have no neutral notion — never a trap


## The def's staged override sub-dict, accepting String or StringName def-id keys
## (mirrors EncounterBuilder._effective_params — the .tres/JSON side authors Strings).
static func _overrides_for(cfg: RunConfig, id: StringName) -> Dictionary:
	var entry: Variant = cfg.param_overrides.get(String(id),
		cfg.param_overrides.get(id, null))
	return entry if entry is Dictionary else {}
