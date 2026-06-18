extends RefCounted
## Settings — minimal persisted player-preferences module (G1 scope: telemetry opt-in).
##
## M1 needs exactly one persisted preference: the opt-in `telemetry_enabled` flag
## (default OFF). The G1 spec sketch reaches for a `Settings` autoload + a
## `telemetry_toggled` signal, but the As-Built warns hard against new autoloads /
## editing contention files mid-wave, and against a meta-schema bump (which would
## need a v2->v3 migration + fixture and would touch game_state.gd). So this is a
## lightweight, autoload-free `ConfigFile`-backed store the Telemetry autoload and
## the settings UI both call statically. It is NOT in the run/meta save schema by
## design — a UI preference is process/profile config, not gameplay meta-state.
##
## Persistence: `user://settings.cfg` (Godot ConfigFile, plain ini text). Reading a
## missing/corrupt file yields the safe default (telemetry OFF), so a first launch
## or a wiped profile is privacy-preserving by construction.

class_name Settings

const CONFIG_PATH: String = "user://settings.cfg"
const SECTION: String = "telemetry"
const KEY_ENABLED: String = "enabled"

## Opt-in default: telemetry is OFF until the player explicitly enables it.
const DEFAULT_TELEMETRY_ENABLED: bool = false


## Read the persisted opt-in flag. Any read failure → the safe default (OFF).
static func get_telemetry_enabled() -> bool:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err != OK:
		return DEFAULT_TELEMETRY_ENABLED
	return bool(cfg.get_value(SECTION, KEY_ENABLED, DEFAULT_TELEMETRY_ENABLED))


## Persist the opt-in flag (atomic enough for a one-key ini; ConfigFile.save writes
## the whole file). Returns the Error from the save.
static func set_telemetry_enabled(value: bool) -> int:
	var cfg := ConfigFile.new()
	# Preserve any other keys already in the file.
	cfg.load(CONFIG_PATH)
	cfg.set_value(SECTION, KEY_ENABLED, value)
	return cfg.save(CONFIG_PATH)
