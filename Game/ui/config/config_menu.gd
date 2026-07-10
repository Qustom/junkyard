class_name ConfigMenu
extends Control
## ConfigMenu (CFG, M1.1) — the greybox pre-run config panel beside the Start Run
## menu. It owns ONE working RunConfig it mutates as the Director edits the knobs,
## and exposes that working config via apply_and_get_config() so MainGame can stage
## it inside start_new_run() (ratified shape (a), §3.5 — the STAGING path does NOT
## call start_new_run or touch GameState/EventBus itself; it only reads + writes the
## RunConfig schema and hands the result to the existing run-entry seam. The ONE
## exception since M1.9/S4 is the deliberate, guarded live-edit respawn action,
## which emits EventBus.debug_run_dirtied so Telemetry marks the run — see
## _on_respawn_pressed).
##
## Design intent (CFG spec §1): the menu surfaces 100% of RunConfig's @export fields
## and nothing else, so each run is a labelled experiment the Director can sweep fast.
## Three redundant readouts (top summary line, per-section ON/OFF chip + key-value
## summary, per-row live value) keep "what will this run do" answerable at a glance.
##
## Readability rules (UI playbook, §2.7):
##   - ON/OFF carried by the CheckButton state AND the ON/OFF text chip AND body
##     dimming — never colour alone (redundant non-colour channels).
##   - Reset + the master toggles are the highest-contrast, band-independent layer.
##   - Every visible string goes through tr() against ui/config/config_strings.csv.
##
## Row construction is HAND-AUTHORED (ratified §3.6) — one explicit row per field —
## with a build-time coverage assertion that the bound-field set equals RunConfig's
## exported field set, so a future R-task adding a knob fails loudly rather than
## silently going unreachable.
##
## Greybox only: default theme, plain Control containers. A human owns the visual pass.

const DEFAULT_CFG_PATH := "res://data/run_config/run_config.tres"

## Slider display ranges by knob category (§3.4a). The schema carries no min/max, so
## the menu defines generous greybox ranges; every numeric row is ALSO typeable to an
## exact value via its SpinBox, so the slider is a fast-scrub convenience, never a cap.
const RANGE_DEPTH := Vector2(0, 10)
const RANGE_SPEED := Vector2(0, 120)
const RANGE_SECONDS := Vector2(0, 30)
const RANGE_PROB := Vector2(0, 1)
const RANGE_RADIUS := Vector2(0, 64)
const RANGE_MAGNITUDE := Vector2(0, 100)
## I1 (M1.2) level-scale ranges (greybox scrub conveniences; SpinBox types past these).
const RANGE_COUNT := Vector2(1, 30)   # lvl_room_count slider span (override is >=1)
const RANGE_MULT := Vector2(4.0, 40.0)   # J1 (M1.3): lvl_size_mult slider re-ranged to the Director's [floor 4.0, max 40.0] (0.25 steps -> integer px/cell; SpinBox still types past via allow_greater)
## J3 (M1.3) per-room density ranges (greybox scrub conveniences; SpinBox types past these).
const RANGE_DENSITY := Vector2(0.0, 4.0)   # r1_per_room_density / lvl_loot_density_per_area (0.25 step)
const RANGE_AREA := Vector2(0, 256)        # r1_density_min_area (floor-cell area gate)
const RANGE_ROOM_CAP := Vector2(0, 16)     # r1_density_per_room_cap (0 = uncapped)
## J4 (M1.3): the corridor-rarity weight multiplier — [0.0, 1.0] (corridors can be dialled to
## 0× their catalog weight, never UP past baseline 1.0). 0.25 step. SpinBox still types past.
const RANGE_CORRIDOR := Vector2(0.0, 1.0)  # lvl_corridor_weight_mult (0.25 step)
## M1.4 (K0) greybox scrub ranges for the new knobs (SpinBox still types past all of these).
const RANGE_COUNT_SMALL := Vector2(0, 10)   # *_base_count hazard/exit spawn counts (0 = none)
const RANGE_PER_DEPTH := Vector2(0.0, 5.0)  # *_count_per_depth additive scaling per depth
const RANGE_MONEY := Vector2(0, 500)        # quota_base / quota_step ($ values; step 10)
const RANGE_TIMER := Vector2(0, 120)        # timer_length_s dive length (s)
const RANGE_VIEW := Vector2(0, 1920)        # cam_visible_world_width (visible world px)
const RANGE_ROTATION := Vector2(-360, 360)  # hspike_rotation_speed (signed deg/s)

## Per-section descriptor: prefix (Meta = ""), the CSV title/gloss keys, the master
## field name ("" = none, Meta), whether the section is collapsible.
const SECTIONS := [
	{"prefix": "", "title_key": "CFG_SEC_META", "gloss_key": "", "master": "", "collapsible": false},
	# V3b (M1.12): the "r1_" section was RETIRED with the 18 r1_* knobs — the pursuer is now a
	# deck card, edited (like every modern hazard) via the generated Oppositions tab, not a knob group.
	{"prefix": "r2_", "title_key": "CFG_SEC_R2", "gloss_key": "CFG_GLOSS_R2", "master": "r2_enabled", "collapsible": true},
	{"prefix": "r3_", "title_key": "CFG_SEC_R3", "gloss_key": "CFG_GLOSS_R3", "master": "r3_enabled", "collapsible": true},
	{"prefix": "r4_", "title_key": "CFG_SEC_R4", "gloss_key": "CFG_GLOSS_R4", "master": "r4_enabled", "collapsible": true},
	{"prefix": "lvl_", "title_key": "CFG_SEC_LVL", "gloss_key": "CFG_GLOSS_LVL", "master": "lvl_enabled", "collapsible": true},
	# M1.4 (K0) — 7 new sections, each with a master *_enabled toggle (structural rows
	# only; the per-knob UI tasks style/range-tune their sections later, not coverage).
	{"prefix": "quota_", "title_key": "CFG_SEC_QUOTA", "gloss_key": "CFG_GLOSS_QUOTA", "master": "quota_enabled", "collapsible": true},
	{"prefix": "cam_", "title_key": "CFG_SEC_CAM", "gloss_key": "CFG_GLOSS_CAM", "master": "cam_enabled", "collapsible": true},
	{"prefix": "timer_", "title_key": "CFG_SEC_TIMER", "gloss_key": "CFG_GLOSS_TIMER", "master": "timer_enabled", "collapsible": true},
	# V3 (M1.12): the hpp_/hbomb_/hspike_ K5 sections were RETIRED with their RunConfig knobs.
	# The ping-pong/bomb/spike hazards now render in the GENERATED Oppositions tab (their defs
	# carry param_schema), exactly like the six modern hazards.
	{"prefix": "exit_", "title_key": "CFG_SEC_EXIT", "gloss_key": "CFG_GLOSS_EXIT", "master": "exit_enabled", "collapsible": true},
	# M1.5 (L0) — ONE new section (throw_). The L2 pursuer knobs + the L5 *_kills
	# toggles join EXISTING sections (r1_ / hpp_ / hbomb_ / hspike_), no new section.
	{"prefix": "throw_", "title_key": "CFG_SEC_THROW", "gloss_key": "CFG_GLOSS_THROW", "master": "throw_enabled", "collapsible": true},
]

## HAND-AUTHORED field manifest (§3.6 — NOT reflection). Each section's ordered field
## list; the master field appears here too (rendered in the header, skipped in the body).
## The build-time coverage assertion checks the flattened set == RunConfig's exported
## field set, so no knob can go unreachable.
const MANIFEST := {
	"": ["seed_override", "build_tag"],
	# V3b (M1.12): the "r1_" manifest block (18 fields) was RETIRED with the knobs.
	"r2_": [
		"r2_enabled", "r2_mechanism", "r2_cost_magnitude", "r2_cost_per_depth",
		"r2_depth_threshold", "r2_toll_resource",
	],
	"r3_": [
		"r3_enabled", "r3_base_climb_rate", "r3_rate_per_depth", "r3_threshold_levels",
		"r3_penalty_kind", "r3_penalty_magnitude", "r3_max_forces_loss", "r3_decay_on_retreat",
	],
	# M4 (M1.6) — r4_ now lists MAZE-branch rows only (master + 3 branch knobs). The 4
	# vision/fog rows split out to R4_VISION_FIELDS (rendered under the Vision tab's
	# master-less "r4_vision_" pseudo-section). NO field renamed — coverage's `bound` set
	# is byte-identical (every r4_* field still gets exactly one _build_row → _rows entry;
	# r4_enabled stays the lone r4 SECTIONS master). See RD-1.
	"r4_": [
		"r4_enabled", "r4_branch_chance_base", "r4_branch_per_depth", "r4_max_branch_depth",
	],
	"lvl_": [
		"lvl_enabled", "lvl_room_count", "lvl_size_mult",
		# J3 (M1.3) — loot-per-area sub-knob (off by default; a swept lever, never preset-on).
		"lvl_loot_density_per_area",
		# J4 (M1.3) — corridor-rarity lever: a float (weight mult, slider+spin) + a bool (drop long).
		"lvl_corridor_weight_mult", "lvl_short_corridors",
	],
	# M1.4 (K0) — 7 new sections (master first; the per-knob UI tasks restyle later).
	"quota_": [
		# K2 — quota gate: master + base/step ($) + the two KEPT behaviour enums.
		"quota_enabled", "quota_base", "quota_step", "quota_check_timing", "quota_basis",
	],
	"cam_": [
		# K3 — resolution-independent camera: master + visible width (float) + zoom enum.
		"cam_enabled", "cam_visible_world_width", "cam_zoom_policy",
	],
	"timer_": [
		# K4 — dive timer + near-end warning: master + length/threshold floats + channel enum.
		"timer_enabled", "timer_length_s", "timer_warning_threshold_s", "timer_warning_channel",
	],
	# V3 (M1.12): the hpp_/hbomb_/hspike_ manifest blocks were RETIRED with their RunConfig knobs
	# (the three hazards are now def-driven data, surfaced by the generated Oppositions tab).
	"exit_": [
		# K7 — exit placement: master + base/per-depth count + keep-at-spawn bool + max cap.
		"exit_enabled", "exit_base_count", "exit_count_per_depth", "exit_keep_one_at_spawn", "exit_max_count",
	],
	# M1.5 (L0) — L1 throwing: master + a speed float + a max-range float.
	"throw_": [
		"throw_enabled", "throw_speed", "throw_max_range",
	],
}

## M4 (M1.6) — the body/dim key for the split-out Vision pseudo-section. NEVER a real
## SECTIONS prefix and NEVER added to _prefix_of's scan list (RD-1): the vision rows
## keep the "r4_" master + ON/OFF chip (their fields begin with "r4_", so _prefix_of
## routes them to "r4_"); this key is used ONLY for the Vision header + body dimming.
const R4_VISION_KEY := "r4_vision_"

## M4 (M1.6) — the 4 vision/fog rows, split OUT of MANIFEST["r4_"] into their own
## Vision tab. NOT renamed: these are the SAME r4_vision_radius / r4_vision_tighten_per_depth
## / r4_fog_enabled / r4_lost_proxy_threshold @export fields, just rendered under a
## master-less Vision header instead of inside the maze section's body. Each still gets
## exactly one _build_row → one _rows entry, so coverage's bound set is byte-identical (RD-1).
const R4_VISION_FIELDS := [
	"r4_vision_radius", "r4_vision_tighten_per_depth", "r4_fog_enabled", "r4_lost_proxy_threshold",
]

## M1.7 (Player tab) — the body/section key for the VIEW-ONLY debug Player tab (mirrors
## R4_VISION_KEY). It is NEVER a real SECTIONS prefix, NEVER added to _prefix_of's scan
## list, and NEVER produces a _rows entry: every control under it (the moved art toggle +
## the 5 anim-lock controls) is built outside MANIFEST, mutates no _cfg field, and is
## invisible to has_full_coverage() — so coverage's 89-field bound set is byte-identical
## and the determinism fingerprint cannot move. These are DEBUG view controls, not knobs.
const PLAYER_DEBUG_KEY := "player_debug_"

## M1.9 (S4) — the pseudo-section key for the GENERATED Oppositions tab (the
## PLAYER_DEBUG_KEY mounting pattern: never a SECTIONS prefix, never in _prefix_of's
## scan list, routed to its own builder in _build_section_into). UNLIKE the Player
## tab, the generated widgets here ARE config editors: they stage the two S3 generic
## levers (oppositions_enabled / param_overrides), which ARE @export RunConfig fields
## after S4's promotion — so the surface is VISIBLE to coverage (the two sentinel
## _rows bindings, §3.4 Layer 1) and each def's rows are asserted by the per-def
## bijection net (has_full_def_coverage), never hidden from it.
const OPPOSITION_DEFS_KEY := "opposition_defs_"

## The canonical S0 def folder (adjudicated: res://data/oppositions). The menu
## display-loads EVERY authored def (enablement is staged, §3.2) — loading a .tres
## for display touches no generation state; the all-off fingerprint is a
## generation-path property (EncounterBuilder/SpawnService load nothing when the
## lever is empty), so fp e943ac9c8bc1 is structurally safe.
const DEFS_DIR := "res://data/oppositions"

## FBM19b — the authored band-profile folder. The menu display-loads every
## BandProfile once at build time to learn DECK MEMBERSHIP (which defs a band's
## opposition_deck spawns without any config enable), so a deck-spawned def's
## chip can say so instead of the misleading "OFF" ("tuning does nothing").
## Display-only, same fingerprint argument as DEFS_DIR above.
const BANDS_DIR := "res://data/bands"

## M4 (M1.6) — tab taxonomy (RD-2, LOCKED). Each tab is a CSV title-key + an ordered
## list of SECTION KEYS to render inside its scroll. A section key is a SECTIONS prefix
## EXCEPT R4_VISION_KEY ("r4_vision_") which is the split-out, master-less Vision
## sub-group. PURE PRESENTATION: coverage is keyed off _rows + SECTIONS masters, never
## off this table — regrouping into tabs cannot change the 89-field bound set.
const TABS := [
	# V3b (M1.12): the Hazards tab was DROPPED — V3 retired its K5 half, V3b its r1_ half, so it
	# held no sections. All hazards (K5 + pursuer) are now edited via the generated Oppositions tab.
	{"title_key": "CFG_TAB_LEVELGEN",  "sections": ["lvl_", "r4_"]},          # r4_ here = MAZE rows only
	{"title_key": "CFG_TAB_VISION",    "sections": [R4_VISION_KEY]},          # the split-out vision rows
	{"title_key": "CFG_TAB_TIMEQUOTA", "sections": ["timer_", "quota_"]},
	{"title_key": "CFG_TAB_EXPRETURN", "sections": ["r2_", "r3_"]},
	{"title_key": "CFG_TAB_THROWCAM",  "sections": ["throw_", "cam_", "exit_"]},
	# M1.9 (S4) — the GENERATED Oppositions tab: one collapsible section per loaded
	# OppositionDef, widgets dispatched from param_schema — a new def's section
	# auto-appears with ZERO menu edits ("adding content is data, not engineering").
	# Tab additions stay PURE PRESENTATION for the legacy net (M1.6/M1.7 precedent);
	# the def surface's own coverage is the per-def bijection + the two lever
	# sentinels. Inserted before Player (Meta stays last) — a NEW tab, not sections
	# under Hazards, so the legacy knob rows and the same hazards' def rows never
	# share one scroll during migration (the mis-edit trap, §8.1 Q1).
	{"title_key": "CFG_TAB_OPPOSITIONS", "sections": [OPPOSITION_DEFS_KEY]},
	# M1.7 — the VIEW-ONLY debug Player tab (art toggle + per-action anim-lock timing).
	# PURE PRESENTATION + debug: PLAYER_DEBUG_KEY is not a SECTIONS prefix and produces no
	# _rows entry, so coverage's 89-field bound set is unchanged. Inserted right before
	# Meta (Meta stays last).
	{"title_key": "CFG_TAB_PLAYER",    "sections": [PLAYER_DEBUG_KEY]},
	{"title_key": "CFG_TAB_META",      "sections": [""]},
]

## Per-field slider range lookup (§3.4a). Only numeric (int/float) scalar fields appear;
## bools/enums/strings/arrays use their own widgets. seed_override is an unbounded SpinBox.
const FIELD_RANGE := {
	# V3b (M1.12): the 10 r1_* numeric ranges were RETIRED with the knobs.
	"r2_cost_magnitude": RANGE_MAGNITUDE,
	"r2_cost_per_depth": RANGE_MAGNITUDE,
	"r2_depth_threshold": RANGE_DEPTH,
	"r3_base_climb_rate": RANGE_MAGNITUDE,
	"r3_rate_per_depth": RANGE_MAGNITUDE,
	"r3_penalty_magnitude": RANGE_MAGNITUDE,
	"r3_decay_on_retreat": RANGE_MAGNITUDE,
	"r4_branch_chance_base": RANGE_PROB,
	"r4_branch_per_depth": RANGE_MAGNITUDE,
	"r4_max_branch_depth": RANGE_DEPTH,
	"r4_vision_radius": RANGE_RADIUS,
	"r4_vision_tighten_per_depth": RANGE_MAGNITUDE,
	"r4_lost_proxy_threshold": RANGE_PROB,
	# I1 (M1.2) level scale.
	"lvl_room_count": RANGE_COUNT,
	"lvl_size_mult": RANGE_MULT,
	# J3 (M1.3) loot-per-area sub-knob.
	"lvl_loot_density_per_area": RANGE_DENSITY,
	# J4 (M1.3) corridor-rarity weight multiplier (lvl_short_corridors is a bool → CheckButton).
	"lvl_corridor_weight_mult": RANGE_CORRIDOR,
	# M1.4 (K0) — numeric scalars only (the *_enabled bools + the *_zoom_policy/check_timing/
	# basis/warning_channel enums + the keep-one-at-spawn bool render as their own widgets, no
	# range). Spans are greybox scrub conveniences; the per-knob UI tasks may tune them.
	# K2 quota.
	"quota_base": RANGE_MONEY,
	"quota_step": RANGE_MONEY,
	# K3 camera.
	"cam_visible_world_width": RANGE_VIEW,
	# K4 timer.
	"timer_length_s": RANGE_TIMER,
	"timer_warning_threshold_s": RANGE_SECONDS,
	# V3 (M1.12): the K5a/K5b/K5c hpp_/hbomb_/hspike_ ranges were RETIRED with their knobs.
	# K7 exits.
	"exit_base_count": RANGE_COUNT_SMALL,
	"exit_count_per_depth": RANGE_PER_DEPTH,
	"exit_max_count": RANGE_ROOM_CAP,
	# M1.5 (L0) — numeric scalars only. throw_enabled renders as a CheckButton, no range.
	# L1 throwing.
	"throw_speed": RANGE_SPEED,        # px/s travel speed
	"throw_max_range": RANGE_VIEW,     # px max travel before a miss → re-drop
	# V3b (M1.12): the L2 r1_patrol_speed range was RETIRED with the r1_* knobs.
}

## I1 (M1.2): per-field SpinBox/slider STEP override. lvl_size_mult is snapped to 0.25
## (16-base -> 4-px increments, every value an exact integer px/cell) so abutting scaled
## pieces never gap and materialise/JunkPlacer share one integer cell size (Resolved F).
const FIELD_STEP := {
	"lvl_size_mult": 0.25,
	# V3b (M1.12): r1_per_room_density's 0.25 step was RETIRED with the r1_* knobs.
	"lvl_loot_density_per_area": 0.25,
	# J4 (M1.3): the corridor weight multiplier scrubs in 0.25 steps over [0, 1].
	"lvl_corridor_weight_mult": 0.25,
	# M1.4 (K0): quota $ values scrub in 10s (Director uses 50s; SpinBox types exact).
	"quota_base": 10.0,
	"quota_step": 10.0,
}

# Dimming alpha for a section body whose master is OFF (redundant "inert" cue).
const DIM_ALPHA := 0.45

var _cfg: RunConfig                       # the working config (a duplicate, never the on-disk .tres)
var _rows: Dictionary = {}                # field_name -> the bound control node (for read-back / refresh)
var _section_bodies: Dictionary = {}      # prefix -> the body container (dim target)
var _section_chips: Dictionary = {}       # prefix -> the ON/OFF + summary chip Label
var _summary_label: Label = null
var _trap_label: Label = null             # J1/BUG6: non-blocking inert-opposition warn line

# Built UI roots (created in _build_ui).
var _tab_container: TabContainer = null   # M4 (M1.6): the 7-tab restructure root

# M4 (M1.6): pause-in-dive bookkeeping (RD-3). Only restore a pause WE set so the
# overlay never stomps a pre-existing pause (e.g. an Esc menu).
var _paused_by_overlay: bool = false

# M1.7 (Player tab): refs to the VIEW-ONLY debug anim-lock widgets so the single
# _emit_player_anim_config() helper can read all of them. NOT in _rows (debug-only,
# invisible to coverage). Defaults MUST mirror player_visual.gd's @export defaults.
var _player_lock_on_pickup_cb: CheckButton = null
var _player_reject_cb: CheckButton = null
var _player_lock_mode_opt: OptionButton = null
var _player_pickup_lock_spin: SpinBox = null
var _player_throw_lock_spin: SpinBox = null

# M1.9 (S4): the generated Oppositions surface state.
var defs_dir: String = DEFS_DIR           # test hook: set BEFORE add_child to aim at a fixture dir
var _defs: Array[OppositionDef] = []      # loaded defs, sorted by String(id) (display + coverage order)
var _def_load_error: bool = false         # duplicate-id drift → has_full_def_coverage() fails (§8.3.2)
var _def_rows: Dictionary = {}            # def_id(String) -> { param_key -> control } — the per-def coverage ledger
var _def_masters: Dictionary = {}         # def_id -> master CheckButton (staged enablement)
var _def_chips: Dictionary = {}           # def_id -> the ENABLED·n-overrides / OFF chip Label
var _def_bodies: Dictionary = {}          # def_id -> body VBox (dim + fold target)
var _def_fold_buttons: Dictionary = {}    # def_id -> the ▸/▾ fold toggle Button
var _def_folded: Dictionary = {}          # def_id -> bool (fold state; default folded unless active)
var _def_respawn_buttons: Dictionary = {} # def_id -> the tier-v1 live-edit (respawn) Button

# FBM19b — deck-membership awareness (Director request post-SG1).
var bands_dir: String = BANDS_DIR         # test hook: set BEFORE add_child to aim at a fixture dir
var _def_deck_bands: Dictionary = {}      # def_id(String) -> Array[Dictionary {id, name}] of bands whose deck lists it


func _ready() -> void:
	# J1 (M1.3): the CFG rail BOOTS INTO the default play-preset (the Director's most-fun
	# M1.2 stack — LVL on/19 rooms/size 4.0, R1 + R4 on, R2/R3 off), NOT the all-off control.
	# Reset (_on_reset_pressed -> _load_default) still returns the all-off baseline, so the
	# permanent control (fp=e943ac9c8bc1) is one click away.
	_cfg = _make_boot_config()
	_load_defs()                          # M1.9 (S4): discover authored defs BEFORE the build
	_load_deck_membership()               # FBM19b: learn which bands' decks spawn each def
	_build_ui()
	_assert_full_coverage()               # build-time: no RunConfig knob left unreachable
	_refresh_all()
	# M4 (M1.6): the rail is no longer the first screen — it is a P-toggle overlay mounted
	# once on App.DebugOverlay (RD-7), hidden until the debug_menu_toggle (P) action. It is
	# the lone PROCESS_MODE_ALWAYS node so P still toggles it while a paused dive freezes
	# behind it (RD-3). apply_and_get_config() is read at the NEXT dive launch (RD-4).
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action(&"debug_menu_toggle"):
		# M0 owns the [input] action; a soft warning makes a mis-merge fail loud, not silent.
		push_warning("ConfigMenu: input action 'debug_menu_toggle' missing — P-toggle inert (M0 owns it).")


## M4 (M1.6): the P-toggle. _unhandled_input so a focused control's keypresses still win;
## ALWAYS process-mode keeps this live while a dive is paused behind the overlay.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_menu_toggle"):
		_toggle_overlay()
		get_viewport().set_input_as_handled()


## Show/hide the overlay. In the dive (App.current_state == &"dive") it pauses the tree so
## the world + the K4 DiveClock freeze behind the menu (the clock is PROCESS_MODE_PAUSABLE,
## so it stops with the tree — debug time does NOT burn the dive timer). No-op in Menu/Hub
## (nothing live to freeze). Restores ONLY a pause the overlay itself set (RD-3).
func _toggle_overlay() -> void:
	visible = not visible
	if visible:
		# M1.9 (S4): the tier-v1 live-edit buttons are enabled only in-dive with live
		# instances — recompute on every open (the service is per-dive, group-resolved).
		_refresh_respawn_buttons()
	if not _pauses_dive():
		return
	if visible:
		if not get_tree().paused:
			get_tree().paused = true
			_paused_by_overlay = true
	elif _paused_by_overlay:
		get_tree().paused = false
		_paused_by_overlay = false


## True iff we are in the live dive (per M0's App router, the single state authority).
## Falls back to checking for a live main_game dive node under StateHost if the router
## doesn't expose current_state (defensive; M0 RD-3 confirms the accessor exists).
func _pauses_dive() -> bool:
	var router := get_tree().get_first_node_in_group(&"app_router")
	if router != null and &"current_state" in router:
		return router.current_state == &"dive"
	return get_tree().get_first_node_in_group(&"dive") != null


# --- Working config -----------------------------------------------------------

## The config the CFG rail OPENS INTO = the default play-preset (J1 / Director F1). The
## factory builds on a fresh all-off RunConfig.new(), so the all-off control is never
## mutated; Reset still reaches it via _load_default().
func _make_boot_config() -> RunConfig:
	return RunConfig.make_default_play_preset()


## Duplicate the on-disk all-off default so the working config is independent and the
## .tres is never mutated. Falls back to a fresh RunConfig (also all-off) if missing.
## This is the ALL-OFF CONTROL — Reset returns here (the permanent baseline), unchanged.
func _load_default() -> RunConfig:
	var base := load(DEFAULT_CFG_PATH) as RunConfig
	if base == null:
		return RunConfig.new()
	return base.duplicate(true) as RunConfig


## The exposed working config. MainGame stages this in start_new_run() (shape (a)).
## Returns the live working instance — the Director's edits ARE this config.
func apply_and_get_config() -> RunConfig:
	return _cfg


# --- Coverage assertion (the "no knob unreachable" net) -----------------------

## Assert the hand-authored bound-field set equals RunConfig's exported field set.
## Fails loudly (push_error) if a future R-task adds an @export knob nobody wired.
## Returns true on full coverage (used by the focused test too).
func has_full_coverage() -> bool:
	var bound := {}
	for f in _rows.keys():
		bound[f] = true
	# Masters live in headers (not _rows) but are bound via the header CheckButton.
	for sec in SECTIONS:
		if sec.master != "":
			bound[sec.master] = true
	var exported := _exported_config_fields()
	var missing: Array = []
	for f in exported:
		if not bound.has(f):
			missing.append(f)
	var extra: Array = []
	for f in bound.keys():
		if not exported.has(f):
			extra.append(f)
	if not missing.is_empty():
		push_error("ConfigMenu: %d RunConfig knob(s) UNREACHABLE (no bound control): %s"
			% [missing.size(), str(missing)])
	if not extra.is_empty():
		push_error("ConfigMenu: %d bound control(s) reference a non-existent field: %s"
			% [extra.size(), str(extra)])
	return missing.is_empty() and extra.is_empty()


func _assert_full_coverage() -> void:
	assert(has_full_coverage(), "ConfigMenu: RunConfig coverage assertion failed (see push_error).")
	# M1.9 (S4): the per-def net — same fail-loud statement at def scope.
	assert(has_full_def_coverage(), "ConfigMenu: per-def coverage assertion failed (see push_error).")


## M1.9 (S4) §3.4 Layer 3 — the per-def bijection net: for EVERY loaded def,
## params ↔ param_schema ↔ generated rows, all three mutually complete. This is the
## legacy has_full_coverage() statement at def scope: every params key has a schema
## entry (no unschema'd param — it would be unsweepable), every schema entry names a
## real params key (no orphan schema — it would stage a dead override), and every
## schema entry has exactly one generated control (no unreachable/extra row).
## Fail-loud per def (push_error names the def id + the exact drift). Duplicate def
## ids recorded at load time (§8.3.2) also fail here — coverage drift, never a
## silent last-write-wins.
func has_full_def_coverage() -> bool:
	var ok := not _def_load_error
	for def: OppositionDef in _defs:
		var schema_keys: Dictionary = {}
		for entry: Dictionary in def.param_schema:
			var key := String(entry.get("key", ""))
			if key == "" or schema_keys.has(key):
				push_error("ConfigMenu: def '%s': param_schema entry missing/duplicate key: %s"
					% [def.id, str(entry)])
				ok = false
				continue
			schema_keys[key] = true
		# (a) every params key has a schema entry.
		for k: Variant in def.params:
			if not schema_keys.has(String(k)):
				push_error("ConfigMenu: def '%s': param '%s' has NO param_schema entry (unreachable knob)"
					% [def.id, String(k)])
				ok = false
		# (b) every schema entry names a real params key.
		for k: String in schema_keys:
			if not def.params.has(k):
				push_error("ConfigMenu: def '%s': param_schema entry '%s' names a non-existent param"
					% [def.id, k])
				ok = false
		# (c) every schema entry has exactly one generated control, and no extra rows.
		var rows: Dictionary = _def_rows.get(String(def.id), {})
		for k: String in schema_keys:
			if not rows.has(k):
				push_error("ConfigMenu: def '%s': schema param '%s' has NO generated control"
					% [def.id, k])
				ok = false
		for k: Variant in rows:
			if not schema_keys.has(String(k)):
				push_error("ConfigMenu: def '%s': generated control '%s' references no schema entry"
					% [def.id, String(k)])
				ok = false
	return ok


## The set of RunConfig @export field names, as a Dictionary (field -> true) for O(1)
## lookup. Source of truth is the Resource's own property list.
func _exported_config_fields() -> Dictionary:
	var out := {}
	for p in _cfg.get_property_list():
		if (int(p.usage) & PROPERTY_USAGE_STORAGE) != 0 and (int(p.usage) & PROPERTY_USAGE_EDITOR) != 0:
			var n: String = p.name
			# Resource bookkeeping props (script/resource_*) are storage but not our knobs.
			if n == "script" or n.begins_with("resource_") or n == "Built-in script":
				continue
			out[n] = true
	return out


# --- UI construction ----------------------------------------------------------

func _build_ui() -> void:
	# Outer panel fills the overlay; the summary bar + Reset stay DOCKED above a 7-tab
	# TabContainer (M4 / RD-2). The summary line + Reset are thus answerable from any tab.
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.name = "Outer"
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)

	_build_summary_bar(outer)

	# M4 (M1.6): one TabContainer replaces the single ScrollContainer. Each tab is its
	# own ScrollContainer (long tabs still scroll). PURE PRESENTATION — coverage is keyed
	# off _rows + SECTIONS masters, not tab grouping, so the 89-field bound set is unchanged.
	var tabs := TabContainer.new()
	tabs.name = "Tabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(tabs)
	_tab_container = tabs

	for tab in TABS:
		var page := ScrollContainer.new()
		page.name = tr(tab.title_key)               # TabContainer uses the child's name as the tab label...
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var col := VBoxContainer.new()
		col.name = "Sections"
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 10)
		page.add_child(col)
		tabs.add_child(page)
		tabs.set_tab_title(tabs.get_tab_count() - 1, tr(tab.title_key))   # ...set the tr() label explicitly
		for section_key in tab.sections:
			_build_section_into(col, section_key)


func _build_summary_bar(parent: Control) -> void:
	var bar := VBoxContainer.new()
	bar.name = "SummaryBar"
	bar.add_theme_constant_override("separation", 6)
	parent.add_child(bar)

	_summary_label = Label.new()
	_summary_label.name = "SummaryLabel"
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(_summary_label)

	# J1 folds BUG6's config-trap guard into CFG: a WARN-ONLY line that lists every
	# enabled-but-inert opposition (RunConfig.inert_enabled_oppositions()). It NEVER
	# blocks Start (a single-axis "branching-only R4" cell is a legitimate experiment) —
	# it only reports, so a dead-config run can't silently invalidate a re-gate again.
	# Hidden when the config is trap-free (the boot preset is, by construction).
	_trap_label = Label.new()
	_trap_label.name = "TrapWarnLabel"
	_trap_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trap_label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.30))  # amber; text "⚠" carries it too (non-colour-only)
	_trap_label.visible = false
	bar.add_child(_trap_label)

	# Reset is part of the highest-contrast legibility layer — make it prominent.
	var reset := Button.new()
	reset.name = "ResetButton"
	reset.text = tr("CFG_RESET")
	reset.custom_minimum_size = Vector2(0, 36)
	reset.pressed.connect(_on_reset_pressed)
	bar.add_child(reset)

	bar.add_child(HSeparator.new())


## M4 (M1.6): render one section into `parent` (a tab's column). A section key is either
## a real SECTIONS prefix (look up the descriptor + MANIFEST[prefix], unchanged header/
## master/body) or R4_VISION_KEY ("r4_vision_") — the master-less Vision pseudo-section
## whose body is R4_VISION_FIELDS (the split-out vision rows, NOT renamed). Factored from
## the old _build_section so the same builder serves both real prefixes and the pseudo-key.
func _build_section_into(parent: Control, section_key: String) -> void:
	if section_key == R4_VISION_KEY:
		_build_vision_pseudo_section(parent)
		return
	if section_key == PLAYER_DEBUG_KEY:
		_build_player_debug_section(parent)
		return
	if section_key == OPPOSITION_DEFS_KEY:
		_build_opposition_defs_tab(parent)
		return

	var sec := _section_descriptor(section_key)
	var prefix: String = sec.prefix
	var box := PanelContainer.new()
	box.name = "Section_%s" % (prefix if prefix != "" else "meta")
	parent.add_child(box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	box.add_child(col)

	# --- Header: master toggle (if any) + title + gloss + ON/OFF state chip -----
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	col.add_child(header)

	if sec.master != "":
		var master := CheckButton.new()
		master.name = "Master"
		master.tooltip_text = sec.master
		master.toggled.connect(_on_master_toggled.bind(sec.master, prefix))
		header.add_child(master)
		_rows[sec.master] = master

	var title := Label.new()
	title.text = tr(sec.title_key)
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)

	var chip := Label.new()
	chip.name = "Chip"
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(chip)
	_section_chips[prefix] = chip

	if sec.gloss_key != "":
		var gloss := Label.new()
		gloss.text = tr(sec.gloss_key)
		gloss.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gloss.modulate = Color(0.72, 0.76, 0.82)
		gloss.add_theme_font_size_override("font_size", 11)
		col.add_child(gloss)

	# --- Body: one row per non-master field in the manifest ---------------------
	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 4)
	col.add_child(body)
	_section_bodies[prefix] = body

	for field in MANIFEST[prefix]:
		if field == sec.master:
			continue
		_build_row(body, field)

	# M4 (M1.6): the Meta tab's telemetry-export button (re-homed from the retiring
	# SellScreen, RD-9 fallback slot). NOT a knob row — it never touches _rows/coverage.
	# M1.7 (Player tab): the debug player-art toggle MOVED to the new Player tab, so Meta
	# now renders only the (web-only) export button.
	if prefix == "":
		_build_meta_export_button(col)


## M4 (M1.6): the master-less Vision pseudo-section (RD-1/RD-5). Renders the Vision header
## (no master CheckButton — R4 is gated by the single r4_enabled master over in Level Gen)
## + a body of R4_VISION_FIELDS. Registers _section_bodies[R4_VISION_KEY] so it dims off the
## SAME r4_enabled master (the dual-dim in _on_master_toggled / _refresh_all). It does NOT
## register a chip and is NOT in _prefix_of — the vision rows' chip/summary route through
## the existing "r4_" prefix, keeping the single R4 ON/OFF chip in Level Gen authoritative.
func _build_vision_pseudo_section(parent: Control) -> void:
	var box := PanelContainer.new()
	box.name = "Section_r4_vision"
	parent.add_child(box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	box.add_child(col)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	col.add_child(header)

	var title := Label.new()
	title.text = tr("CFG_SEC_R4_VISION")
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)

	# Gloss (the section blurb) + a redundant non-colour cross-tab cue: the dim channel
	# alone isn't enough across a tab boundary, so the header states the R4-master gate.
	var gloss := Label.new()
	gloss.text = tr("CFG_GLOSS_R4_VISION")
	gloss.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gloss.modulate = Color(0.72, 0.76, 0.82)
	gloss.add_theme_font_size_override("font_size", 11)
	col.add_child(gloss)

	var gate := Label.new()
	gate.text = tr("CFG_R4_VISION_GATED")
	gate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gate.modulate = Color(0.72, 0.76, 0.82)
	gate.add_theme_font_size_override("font_size", 11)
	col.add_child(gate)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 4)
	col.add_child(body)
	_section_bodies[R4_VISION_KEY] = body

	for field in R4_VISION_FIELDS:
		_build_row(body, field)


## M4 (M1.6): look up the SECTIONS descriptor for a prefix (the TABS table references
## prefixes, not array indices). Pushes an error + returns the Meta descriptor on a miss.
func _section_descriptor(prefix: String) -> Dictionary:
	for sec in SECTIONS:
		if sec.prefix == prefix:
			return sec
	push_error("ConfigMenu: no SECTIONS descriptor for prefix '%s'" % prefix)
	return SECTIONS[0]


## N2 (M1.7): a VIEW-ONLY debug switch that disables the player art (falls back to the
## retained greybox Visual/Nose). It is NOT a RunConfig knob — it is built by its OWN
## method (never _build_row), NEVER writes _rows, and is NOT a SECTIONS master, so
## has_full_coverage()'s 89-field bound set is byte-identical and the determinism
## fingerprint (e943ac9c8bc1) cannot move (it mutates no _cfg field, never calls
## _set_field). On toggle it emits EventBus.debug_player_art_toggled(enabled); the
## PlayerVisual listens and swaps AnimatedSprite2D <-> greybox. Default = art OFF
## (CheckButton UNchecked, matching the player scene's greybox default — the animated
## character is opt-in; no boot emit needed). Session-only: no save write, no
## schema_version bump. Not web-guarded — a
## desktop/dev aid useful in every build. Placed above the (web-only) export button
## per the Director disposition.
func _build_debug_player_art_toggle(parent: Control) -> void:
	parent.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.name = "DebugPlayerArtRow"
	row.add_theme_constant_override("separation", 8)

	var cb := CheckButton.new()
	cb.name = "DebugPlayerArtToggle"
	cb.text = tr("CFG_DEBUG_PLAYER_ART")
	cb.button_pressed = false                 # default = art OFF / greybox (matches player scene default; art is opt-in)
	cb.toggled.connect(_on_debug_player_art_toggled)
	row.add_child(cb)

	parent.add_child(row)
	# NOTE: deliberately NOT _rows["..."] = cb — this control is invisible to coverage,
	# is never reset by _refresh_all()/_on_reset_pressed() (they iterate _rows only), and
	# is never reached by _push_value_to_control (it is not a field).


## N2 (M1.7): the toggle handler — a pure signal emit. Mutates no _cfg field, never
## calls _set_field, so apply_and_get_config()/the determinism fingerprint are unmoved.
func _on_debug_player_art_toggled(enabled: bool) -> void:
	EventBus.debug_player_art_toggled.emit(enabled)


## M1.7 (Player tab): the VIEW-ONLY debug Player section (mirrors the Vision pseudo-
## section pattern). Holds the MOVED player-art toggle + 5 live anim-lock controls. NONE
## of these are RunConfig knobs: nothing here is built via _build_row, nothing writes
## _rows or _cfg, and PLAYER_DEBUG_KEY is not a SECTIONS prefix — so has_full_coverage()'s
## 89-field bound set is byte-identical and the determinism fingerprint cannot move. The
## controls emit EventBus.debug_player_anim_config_changed; PlayerVisual (N1) listens.
## IMPORTANT: every initial widget default below MUST equal player_visual.gd's @export
## defaults (lock_mode = CLIP_DRIVEN, lock_on_pickup = true, play_pickup_on_reject =
## false, pickup_lock_s = 0.25, throw_lock_s = 0.30) — same coupling as the art toggle's
## "default checked = art ON". Greybox build style: default theme, tr() for every string,
## redundant non-colour channels (CheckButton state + label text carry ON/OFF, not colour).
func _build_player_debug_section(parent: Control) -> void:
	var box := PanelContainer.new()
	box.name = "Section_player_debug"
	parent.add_child(box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	box.add_child(col)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	col.add_child(header)

	var title := Label.new()
	title.text = tr("CFG_PLAYER_HEADER")
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)

	# The MOVED art toggle (built by its unchanged method — still outside _rows/coverage).
	_build_debug_player_art_toggle(col)

	# --- Lock on pickup (bool) — default CHECKED (= lock_on_pickup default true) -------
	var lop_row := HBoxContainer.new()
	lop_row.name = "PlayerLockOnPickupRow"
	lop_row.add_theme_constant_override("separation", 8)
	var lop_cb := CheckButton.new()
	lop_cb.name = "PlayerLockOnPickup"
	lop_cb.text = tr("CFG_PLAYER_LOCK_ON_PICKUP")
	lop_cb.button_pressed = true                  # default = lock_on_pickup (true)
	lop_cb.toggled.connect(func(_on: bool) -> void: _emit_player_anim_config())
	lop_row.add_child(lop_cb)
	col.add_child(lop_row)
	_player_lock_on_pickup_cb = lop_cb

	# --- Animate pickup on reject (bool) — default UNCHECKED (= play_pickup_on_reject) -
	var rej_row := HBoxContainer.new()
	rej_row.name = "PlayerPickupOnRejectRow"
	rej_row.add_theme_constant_override("separation", 8)
	var rej_cb := CheckButton.new()
	rej_cb.name = "PlayerPickupOnReject"
	rej_cb.text = tr("CFG_PLAYER_PICKUP_ON_REJECT")
	rej_cb.button_pressed = false                 # default = play_pickup_on_reject (false)
	rej_cb.toggled.connect(func(_on: bool) -> void: _emit_player_anim_config())
	rej_row.add_child(rej_cb)
	col.add_child(rej_row)
	_player_reject_cb = rej_cb

	# --- Lock mode (enum) — OptionButton, default idx 0 = Clip-driven (= CLIP_DRIVEN) -
	var mode_row := HBoxContainer.new()
	mode_row.name = "PlayerLockModeRow"
	mode_row.add_theme_constant_override("separation", 8)
	var mode_label := Label.new()
	mode_label.text = tr("CFG_PLAYER_LOCK_MODE")
	mode_label.custom_minimum_size = Vector2(160, 0)
	mode_row.add_child(mode_label)
	var mode_opt := OptionButton.new()
	mode_opt.name = "PlayerLockMode"
	mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_opt.add_item(tr("CFG_PLAYER_LOCK_MODE_CLIP"), 0)   # idx 0 = CLIP_DRIVEN (default)
	mode_opt.add_item(tr("CFG_PLAYER_LOCK_MODE_FIXED"), 1)  # idx 1 = FIXED
	mode_opt.select(0)
	mode_opt.item_selected.connect(func(_idx: int) -> void: _emit_player_anim_config())
	mode_row.add_child(mode_opt)
	col.add_child(mode_row)
	_player_lock_mode_opt = mode_opt

	# --- Pickup lock (s) — SpinBox, step 0.01, ~0..1, default 0.25 (= pickup_lock_s) --
	_player_pickup_lock_spin = _build_player_lock_spin(col, "PlayerPickupLock",
		"CFG_PLAYER_PICKUP_LOCK_S", 0.25)
	# --- Throw lock (s) — SpinBox, step 0.01, ~0..1, default 0.30 (= throw_lock_s) ----
	_player_throw_lock_spin = _build_player_lock_spin(col, "PlayerThrowLock",
		"CFG_PLAYER_THROW_LOCK_S", 0.30)


## M1.7 (Player tab): a labelled [Label][SpinBox] row for a per-action lock-seconds
## control (step 0.01, range ~0..1). Returns the SpinBox so the caller can store the ref.
## Debug-only: not a knob, never writes _rows/_cfg.
func _build_player_lock_spin(parent: Control, node_name: String, label_key: String, default_val: float) -> SpinBox:
	var row := HBoxContainer.new()
	row.name = "%sRow" % node_name
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = tr(label_key)
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)
	var spin := SpinBox.new()
	spin.name = node_name
	spin.min_value = 0.0
	spin.max_value = 1.0
	spin.step = 0.01
	spin.allow_greater = true                     # type-exact escape hatch past 1.0
	spin.value = default_val
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(func(_v: float) -> void: _emit_player_anim_config())
	row.add_child(spin)
	parent.add_child(row)
	return spin


## M1.7 (Player tab): read ALL the Player-tab anim-lock widgets and emit the live debug
## signal PlayerVisual listens for. Debug tooling — mutates no _cfg field, never calls
## _set_field, so apply_and_get_config()/the determinism fingerprint are unmoved.
func _emit_player_anim_config() -> void:
	if _player_lock_mode_opt == null:
		return   # not built yet (defensive)
	EventBus.debug_player_anim_config_changed.emit(
		_player_lock_mode_opt.get_selected_id(),
		_player_lock_on_pickup_cb.button_pressed,
		_player_reject_cb.button_pressed,
		_player_pickup_lock_spin.value,
		_player_throw_lock_spin.value)


# --- M1.9 (S4): the GENERATED Oppositions surface ------------------------------
# One collapsible section per loaded OppositionDef, widgets dispatched from the
# def's param_schema — the surface half of "adding content is data, not
# engineering". Enablement + param edits STAGE the two S3 generic RunConfig levers
# (next-run semantics identical to every legacy knob); the ONLY world mutation is
# the explicit per-def respawn action (tier-v1 live edit), which emits
# EventBus.debug_run_dirtied so Telemetry marks the run experiment-dirty.

## Def discovery (§3.2 + §8.3 determinism pins): scan the def folder, filename-
## sorted (never rely on listing order), load + type-check each .tres, skip a bad
## file with push_error (fail loud, don't fail to build), record duplicate ids as
## coverage drift (keep the FIRST in filename order), then sort by String(id) —
## the display + coverage-iteration order. ResourceLoader.list_directory handles
## exported-pack .remap indirection that raw DirAccess listings trip over.
func _load_defs() -> void:
	_defs.clear()
	_def_load_error = false
	var names: Array[String] = []
	for f: String in ResourceLoader.list_directory(defs_dir):
		if f.ends_with(".tres"):
			names.append(f)
	names.sort()
	var seen: Dictionary = {}   # id(StringName) -> filename (duplicate detection)
	for f: String in names:
		var def := load(defs_dir.path_join(f)) as OppositionDef
		if def == null or def.id == &"":
			push_error("ConfigMenu: bad OppositionDef at %s (not an OppositionDef or empty id)"
				% defs_dir.path_join(f))
			continue
		if seen.has(def.id):
			push_error("ConfigMenu: duplicate OppositionDef id '%s' (%s and %s) — coverage drift; keeping the first"
				% [def.id, String(seen[def.id]), f])
			_def_load_error = true
			continue
		seen[def.id] = f
		_defs.append(def)
	_defs.sort_custom(func(a: OppositionDef, b: OppositionDef) -> bool:
		return String(a.id) < String(b.id))


## FBM19b — deck-membership scan (build-time, display-only): every BandProfile
## .tres under bands_dir contributes def_id -> {band id, band display name} for
## each opposition_deck row (DeckEntry wrappers unwrapped via entry.def, the S9
## convention). Filename-sorted so the chip's band list is order-stable.
## FAIL-SOFT: a file that doesn't load as a BandProfile is push_warning-skipped —
## a broken band must never take the config menu down with it.
func _load_deck_membership() -> void:
	_def_deck_bands.clear()
	var names: Array[String] = []
	for f: String in ResourceLoader.list_directory(bands_dir):
		if f.ends_with(".tres"):
			names.append(f)
	names.sort()
	for f: String in names:
		var path := bands_dir.path_join(f)
		var profile := load(path) as BandProfile
		if profile == null:
			push_warning("ConfigMenu: %s did not load as a BandProfile — skipped for deck-membership display." % path)
			continue
		var band_id := String(profile.id) if profile.id != &"" else f
		var band_name := profile.display_name if profile.display_name != "" else band_id
		for entry: Resource in profile.opposition_deck:
			var def_res: Resource = entry
			if entry is DeckEntry:
				def_res = (entry as DeckEntry).def
			var def := def_res as OppositionDef
			if def == null or def.id == &"":
				continue   # broken deck rows are the builder's fail-loud, not the menu's
			var key := String(def.id)
			if not _def_deck_bands.has(key):
				_def_deck_bands[key] = []
			var bands: Array = _def_deck_bands[key]
			var already := false
			for b: Variant in bands:
				if String((b as Dictionary).get("id", "")) == band_id:
					already = true
					break
			if not already:
				bands.append({ "id": band_id, "name": band_name })


## The bands whose deck lists this def ([] = nowhere-spawning without an enable).
func _deck_bands_for(def: OppositionDef) -> Array:
	return _def_deck_bands.get(String(def.id), [])


## The Oppositions tab body: staging note + one generated section per def (sorted
## by id) + the TWO DISTINCT lever sentinels (§3.4 Layer 1 / §8.0.2). With zero
## defs the tab shows a placeholder — the menu must never fail to build headlessly
## on an empty folder.
func _build_opposition_defs_tab(parent: Control) -> void:
	var note := Label.new()
	note.name = "DefsStagingNote"
	note.text = tr("CFG_DEFS_STAGING_NOTE")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color(0.72, 0.76, 0.82)
	note.add_theme_font_size_override("font_size", 11)
	parent.add_child(note)

	if _defs.is_empty():
		var placeholder := Label.new()
		placeholder.name = "DefsEmptyPlaceholder"
		placeholder.text = tr("CFG_DEFS_EMPTY")
		parent.add_child(placeholder)
	for def: OppositionDef in _defs:
		_build_def_section(parent, def)

	# Bind the two generic levers into the LEGACY coverage net via two DISTINCT
	# invisible sentinel controls (§8.0.2 — distinctness keeps the leak-test pattern
	# and refresh routing unambiguous). They are real @export knobs after the S4
	# promotion, so they MUST be bound or has_full_coverage() fails — correct
	# behaviour, never suppressed. _push_value_to_control routes both fields to
	# _refresh_def_sections() (which is exactly what Reset needs).
	var enabled_sentinel := Control.new()
	enabled_sentinel.name = "OppositionsEnabledSentinel"
	enabled_sentinel.visible = false
	parent.add_child(enabled_sentinel)
	_rows["oppositions_enabled"] = enabled_sentinel
	var overrides_sentinel := Control.new()
	overrides_sentinel.name = "ParamOverridesSentinel"
	overrides_sentinel.visible = false
	parent.add_child(overrides_sentinel)
	_rows["param_overrides"] = overrides_sentinel


## One generated collapsible section (§3.3): header = fold ▸/▾ + master CheckButton
## (STAGED enablement) + display_name + ENABLED·n-overrides/OFF chip; optional tr'd
## gloss (CFG_GLOSS_DEF_<ID> — fallback empty: content must not require a CSV edit
## to appear); body = one generated row per param_schema entry + the action row
## (Clear overrides + the tier-v1 respawn button). Mirrors the legacy section
## anatomy so the Director reads one visual language; genuinely collapsible
## (6+ defs need folding), default collapsed unless the def is enabled/overridden/
## deck-listed (FBM19b — see _def_section_active).
func _build_def_section(parent: Control, def: OppositionDef) -> void:
	var id := String(def.id)
	var box := PanelContainer.new()
	box.name = "DefSection_%s" % id
	parent.add_child(box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	box.add_child(col)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	col.add_child(header)

	var fold := Button.new()
	fold.name = "Fold"
	fold.flat = true
	fold.focus_mode = Control.FOCUS_NONE
	fold.pressed.connect(_on_def_fold_pressed.bind(id))
	header.add_child(fold)
	_def_fold_buttons[id] = fold

	var master := CheckButton.new()
	master.name = "Master"
	master.tooltip_text = id                     # the def id rides the tooltip
	master.toggled.connect(func(on: bool) -> void: _stage_def_enabled(def, on))
	header.add_child(master)
	_def_masters[id] = master

	var title := Label.new()
	title.text = def.display_name if def.display_name != "" else id
	title.tooltip_text = id
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)

	var chip := Label.new()
	chip.name = "Chip"
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# FBM19b: Labels default to MOUSE_FILTER_IGNORE, which suppresses tooltips —
	# PASS lets the deck-membership tooltip show without eating clicks.
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(chip)
	_def_chips[id] = chip

	# Optional per-def gloss: CSV key convention, EMPTY fallback (§3.3a — a def with
	# no authored gloss still renders; the S2 lint may WARN, the menu never fails).
	var gloss_key := "CFG_GLOSS_DEF_%s" % id.to_upper()
	if tr(gloss_key) != gloss_key:
		var gloss := Label.new()
		gloss.text = tr(gloss_key)
		gloss.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gloss.modulate = Color(0.72, 0.76, 0.82)
		gloss.add_theme_font_size_override("font_size", 11)
		col.add_child(gloss)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 4)
	col.add_child(body)
	_def_bodies[id] = body
	_def_folded[id] = not _def_section_active(def)

	var rows: Dictionary = {}
	for entry: Dictionary in def.param_schema:
		var control: Control = _build_param_row(body, def, entry)
		if control != null:
			rows[String(entry.get("key", ""))] = control
	_def_rows[id] = rows

	# Action row: Clear overrides (back to authored defaults) + the tier-v1 live
	# edit. NEITHER is in _def_rows — they are actions, not param controls, so they
	# can't inflate the per-def coverage ledger (the Player-tab discipline).
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 8)
	body.add_child(actions)
	var clear := Button.new()
	clear.name = "ClearOverrides"
	clear.text = tr("CFG_DEF_CLEAR_OVERRIDES")
	clear.pressed.connect(_on_clear_def_overrides.bind(def))
	actions.add_child(clear)
	var respawn := Button.new()
	respawn.name = "Respawn"
	respawn.text = tr("CFG_DEF_RESPAWN")
	respawn.disabled = true
	respawn.tooltip_text = tr("CFG_DEF_RESPAWN_TIP")
	respawn.pressed.connect(_on_respawn_pressed.bind(def))
	actions.add_child(respawn)
	_def_respawn_buttons[id] = respawn


## Widget dispatch for one param_schema entry — _build_row's type→widget model
## driven by the SCHEMA instead of RunConfig reflection (§3.3): "bool" →
## CheckButton, "int"/"float" → the HSlider+SpinBox pair (entry min/max as the
## slider range, entry step or the default-step rule), "enum" → OptionButton over
## entry options. Unknown type → push_error + NO row (fail loud, same as
## _build_row's fallthrough); the per-def net then reports the schema key with no
## generated control. Returns the canonical control (registered in _def_rows).
func _build_param_row(body: Control, def: OppositionDef, entry: Dictionary) -> Control:
	var key := String(entry.get("key", ""))
	var row := HBoxContainer.new()
	row.name = "DefRow_%s_%s" % [String(def.id), key]
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)

	var label := Label.new()
	var base_text := _def_param_label(def, entry)
	label.text = base_text
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)

	var ptype := String(entry.get("type", ""))
	var control: Control = null
	match ptype:
		"bool":
			control = _make_bool_widget(row,
				func(on: bool) -> void: _stage_override(def, key, on))
		"int", "float":
			var is_int := ptype == "int"
			var rng := Vector2(float(entry.get("min", 0.0)), float(entry.get("max", 100.0)))
			var step := float(entry.get("step", 0.0))
			if step <= 0.0:
				step = 1.0 if is_int else 0.1
				if not is_int and rng.y - rng.x <= 1.0:
					step = 0.01   # the probability-step rule, generalized (§3.3)
			control = _make_numeric_widget(row, rng, step, rng.x,
				maxf(rng.y * 100.0, 100000.0),
				func(v: float) -> void:
					_stage_override(def, key, int(round(v)) if is_int else v))
		"enum":
			var items: Array = entry.get("options", [])
			control = _make_enum_widget(row, items,
				func(idx: int) -> void: _stage_override(def, key, idx))
		_:
			push_error("ConfigMenu: def '%s': no widget for param type '%s' (key '%s')"
				% [def.id, ptype, key])
			return null
	# The row label rides the control as meta so the override '*' mark + tooltip
	# can be refreshed without a parallel label ledger.
	control.set_meta(&"row_label", label)
	control.set_meta(&"label_base", base_text)
	return control


## Per-param label resolution (§3.3a — data-only content needs NO CSV edit):
## 1. the schema entry's `gloss` field as a CSV key (S2 authors the legacy
##    CFG_FIELD_* keys here, so migrated defs reuse the exact legacy label text);
## 2. the CFG_DEF_PARAM_<ID>_<KEY> convention when authored;
## 3. a humanized fallback from the key itself ("charge_speed" → "Charge Speed").
func _def_param_label(def: OppositionDef, entry: Dictionary) -> String:
	var gloss := String(entry.get("gloss", ""))
	if gloss != "" and tr(gloss) != gloss:
		return tr(gloss)
	var key := String(entry.get("key", ""))
	var csv_key := "CFG_DEF_PARAM_%s_%s" % [String(def.id).to_upper(), key.to_upper()]
	if tr(csv_key) != csv_key:
		return tr(csv_key)
	return key.capitalize()


# --- S4 staging (pre-run, config-marked — §3.5) --------------------------------

## Master toggle → add/remove the def id in the working config's enable-list.
## Duplicate-then-assign so a .tres-shared array is never aliased. STAGED: nothing
## spawns until the next run stages the config (apply_and_get_config → start_new_run).
func _stage_def_enabled(def: OppositionDef, on: bool) -> void:
	var arr: Array[StringName] = _cfg.oppositions_enabled.duplicate()
	if on and not arr.has(def.id):
		arr.append(def.id)
	elif not on:
		arr.erase(def.id)
	_cfg.oppositions_enabled = arr
	if on:
		_def_folded[String(def.id)] = false   # enabling auto-expands the section
	_refresh_def_chip(def)
	_set_def_body_state(def)
	_refresh_trap_warning()


## Param widget → SPARSE override write (§3.5): value == the authored default →
## erase the key (and the def's sub-dict when empty); else stage it. Sparse staging
## means the run_started stamp records only ACTUAL deviations — an enabled def with
## no overrides is self-describingly "authored defaults". The def Resource is NEVER
## written (the menu edits the working RunConfig only).
func _stage_override(def: OppositionDef, key: String, value: Variant) -> void:
	var po: Dictionary = _cfg.param_overrides.duplicate(true)
	var id := String(def.id)
	if _param_values_equal(value, def.params.get(key)):
		if po.has(id) and po[id] is Dictionary:
			(po[id] as Dictionary).erase(key)
			if (po[id] as Dictionary).is_empty():
				po.erase(id)
	else:
		if not (po.get(id) is Dictionary):
			po[id] = {}
		(po[id] as Dictionary)[key] = value
	_cfg.param_overrides = po
	_refresh_def_chip(def)
	_refresh_def_row_marks(def)
	_refresh_trap_warning()


## Per-section "back to authored defaults": drop every staged override for this def.
func _on_clear_def_overrides(def: OppositionDef) -> void:
	var po: Dictionary = _cfg.param_overrides.duplicate(true)
	po.erase(String(def.id))
	po.erase(def.id)
	_cfg.param_overrides = po
	_refresh_def_section(def)
	_refresh_trap_warning()


## The def's staged override sub-dict (String or StringName def-id keys accepted —
## mirrors EncounterBuilder._effective_params). {} when none staged.
func _staged_overrides_for(def: OppositionDef) -> Dictionary:
	var entry: Variant = _cfg.param_overrides.get(String(def.id),
		_cfg.param_overrides.get(def.id, null))
	return entry if entry is Dictionary else {}


## The EFFECTIVE next-run value a generated widget shows (§3.3): the staged
## override when present, else the authored def.params default.
func _effective_value(def: OppositionDef, key: String) -> Variant:
	return _staged_overrides_for(def).get(key, def.params.get(key))


## Value equality with float tolerance (a SpinBox hands back floats; an int param's
## authored default must still compare equal after a round-trip).
func _param_values_equal(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return a == b


# --- S4 refresh (model → view for the generated surface) -----------------------

## Re-project the staged levers into EVERY generated master/widget/chip/mark —
## the generated twin of _refresh_all's _rows walk, routed from the two lever
## sentinels' _push_value_to_control branch (so _refresh_all()/Reset just work).
func _refresh_def_sections() -> void:
	for def: OppositionDef in _defs:
		_refresh_def_section(def)
	_refresh_respawn_buttons()


func _refresh_def_section(def: OppositionDef) -> void:
	var id := String(def.id)
	var master: CheckButton = _def_masters.get(id, null)
	if master != null:
		master.set_pressed_no_signal(_cfg.oppositions_enabled.has(def.id))
	var rows: Dictionary = _def_rows.get(id, {})
	for key: Variant in rows:
		_push_def_value_to_control(def, String(key), rows[key])
	_refresh_def_chip(def)
	_refresh_def_row_marks(def)
	_set_def_body_state(def)


## The generated-row _push_value_to_control: writes are no-signal so refresh never
## re-stages (the _push_value_to_control discipline).
func _push_def_value_to_control(def: OppositionDef, key: String, control: Control) -> void:
	var value: Variant = _effective_value(def, key)
	if control is CheckButton:
		(control as CheckButton).set_pressed_no_signal(bool(value))
	elif control is OptionButton:
		(control as OptionButton).select(int(value))
	elif control is SpinBox:
		(control as SpinBox).set_value_no_signal(float(value))
		var slider := (control as SpinBox).get_parent().get_node_or_null("Slider") as HSlider
		if slider != null:
			slider.set_value_no_signal(clampf(float(value), slider.min_value, slider.max_value))


## The ENABLED · n overrides / IN DECK / OFF chip (redundant non-colour state cue,
## like the legacy chips). FBM19b: a def the config leaves off can still spawn
## from a band's opposition_deck — the chip says so honestly ("OFF" read as
## "tuning does nothing"; the staged rc.param_overrides DO reach deck spawns —
## def < deck-entry < rc, the locked precedence). Truly nowhere-spawning defs
## keep the plain OFF chip.
func _refresh_def_chip(def: OppositionDef) -> void:
	var chip: Label = _def_chips.get(String(def.id), null)
	if chip == null:
		return
	if not _cfg.oppositions_enabled.has(def.id):
		var decks: Array = _deck_bands_for(def)
		if decks.is_empty():
			chip.text = tr("CFG_CHIP_OFF")
			chip.tooltip_text = ""
			return
		var band_ids := PackedStringArray()
		var band_names := PackedStringArray()
		for b: Variant in decks:
			band_ids.append(String((b as Dictionary).get("id", "")))
			band_names.append(String((b as Dictionary).get("name", "")))
		chip.text = tr("CFG_DEF_CHIP_DECK").format({
			"bands": ", ".join(band_ids),
			"n": _staged_overrides_for(def).size(),
		})
		chip.tooltip_text = tr("CFG_DEF_CHIP_DECK_TIP").format({ "names": ", ".join(band_names) })
		return
	chip.text = tr("CFG_DEF_CHIP_ON").format({"n": _staged_overrides_for(def).size()})
	chip.tooltip_text = ""


## The override '*' label mark + tooltip (§3.3: the row label suffixes '*' while a
## staged override deviates from the authored default; Reset/Clear removes it).
func _refresh_def_row_marks(def: OppositionDef) -> void:
	var staged: Dictionary = _staged_overrides_for(def)
	var rows: Dictionary = _def_rows.get(String(def.id), {})
	for key: Variant in rows:
		var control: Control = rows[key]
		if control == null or not control.has_meta(&"row_label"):
			continue
		var label := control.get_meta(&"row_label") as Label
		var base := String(control.get_meta(&"label_base"))
		if staged.has(String(key)):
			label.text = base + " *"
			label.tooltip_text = tr("CFG_DEF_OVERRIDE_TIP")
		else:
			label.text = base
			label.tooltip_text = ""


## Fold + dim projection for one generated section: body hidden when folded;
## body dimmed (DIM_ALPHA) when the def is not enabled — chip text + checkbox +
## dim, never colour alone (the redundant-cue rules).
func _set_def_body_state(def: OppositionDef) -> void:
	var id := String(def.id)
	var body: Control = _def_bodies.get(id, null)
	if body == null:
		return
	body.visible = not bool(_def_folded.get(id, true))
	var enabled := _cfg.oppositions_enabled.has(def.id)
	body.modulate = Color(1, 1, 1, 1.0 if enabled else DIM_ALPHA)
	var fold: Button = _def_fold_buttons.get(id, null)
	if fold != null:
		fold.text = "▾" if body.visible else "▸"


func _on_def_fold_pressed(id: String) -> void:
	_def_folded[id] = not bool(_def_folded.get(id, true))
	for def: OppositionDef in _defs:
		if String(def.id) == id:
			_set_def_body_state(def)
			return


## "Active" = worth auto-expanding at build: enabled, carrying staged overrides,
## or deck-listed (FBM19b — a band's deck WILL spawn it, so its knobs must be
## visible the moment the tab opens; folding stays available, only the default
## changed). Truly nowhere-spawning defs still start collapsed.
func _def_section_active(def: OppositionDef) -> bool:
	return _cfg.oppositions_enabled.has(def.id) \
		or not _staged_overrides_for(def).is_empty() \
		or not _deck_bands_for(def).is_empty()


# --- S4 live edit, tier v1 — respawn-with-new-params (§3.7, the ONLY tier) -----

## Enabled only in-dive with live instances of the def (the per-dive SpawnService
## is group-resolved; absent outside a dive or on an all-off run).
func _refresh_respawn_buttons() -> void:
	if not is_inside_tree():
		return
	var svc := _spawn_service()
	var in_dive := _pauses_dive()
	for def: OppositionDef in _defs:
		var btn: Button = _def_respawn_buttons.get(String(def.id), null)
		if btn == null:
			continue
		var live: int = svc.live_count(def.id) if (svc != null and in_dive) else 0
		btn.disabled = live <= 0
		btn.tooltip_text = tr("CFG_DEF_RESPAWN_TIP") if btn.disabled else ""


## The explicit, guarded live-edit action: for each live instance of the def,
## despawn + respawn AT THE SAME CELL with effective params = def.params ⊕ the
## menu's CURRENT working overrides (the entity snapshots them at setup(), exactly
## as any deck-lane spawn). The service enforces caps/placement as for any client —
## a refusal (null) is a warning, not fatal. Emits debug_run_dirtied ONCE per press
## (§3.7 step 3) so Telemetry marks the run; the staged overrides REMAIN staged —
## the next run picks them up as a clean config-marked experiment; only THIS run is
## dirty. Structurally fingerprint-unreachable: spawn() touches no layout RNG.
func _on_respawn_pressed(def: OppositionDef) -> void:
	var svc := _spawn_service()
	if svc == null or svc.live_count(def.id) == 0:
		return
	var params: Dictionary = def.params.duplicate(true)
	var staged: Dictionary = _staged_overrides_for(def)
	for k: Variant in staged:
		params[String(k)] = staged[k]
	var touched := 0
	for node: Node in svc.live_instances(def.id):
		var cell: Vector2i = svc.spawn_cell_of(node)
		if cell == SpawnService.UNREGISTERED_CELL:
			continue
		svc.despawn(node)
		touched += 1
		var ctx: Dictionary = {
			"params": params,               # the ctx-merged def-driven knob bag (S3 contract)
			"depth": _menu_current_depth(),
			"run_t_ms": 0,                  # the service never invents a clock
		}
		if svc.spawn(def, cell, ctx) == null:
			push_warning("ConfigMenu: respawn of '%s' at %s refused by the service (caps/placement)."
				% [def.id, str(cell)])
	if touched > 0:
		# The ONE deliberate EventBus emit in this menu (S4 §8.2): the staging path
		# stays EventBus-free; this guarded debug actor is the exception, and it is
		# what makes the run self-identifyingly dirty.
		EventBus.debug_run_dirtied.emit(&"respawn_params", Time.get_ticks_msec())
	_refresh_respawn_buttons()


func _spawn_service() -> SpawnService:
	return get_tree().get_first_node_in_group(&"spawn_service") as SpawnService


## Current dive depth via the same /root lookup Telemetry uses (headless-safe).
func _menu_current_depth() -> int:
	var gs := get_node_or_null("/root/GameState")
	return int(gs.current_depth) if gs != null else 0


## M4 (M1.6) / RD-9: the web telemetry-export button, re-homed from the retiring
## SellScreen into the Meta tab. Same JSONL export path (TelemetryExporter), web-guarded:
## on desktop the button is hidden (the on-disk retrieval flow is unchanged there). It is
## a docked button below the Meta section, NOT a knob row → never touches _rows/coverage.
func _build_meta_export_button(parent: Control) -> void:
	parent.add_child(HSeparator.new())
	var export_btn := Button.new()
	export_btn.name = "ExportTelemetryButton"
	export_btn.text = tr("CFG_EXPORT_TELEMETRY")
	var status := Label.new()
	status.name = "ExportStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 11)
	status.text = ""
	if not TelemetryExporter.is_supported():
		# Web-only (RD-9): hide the control entirely on desktop, exactly as SellScreen did.
		export_btn.hide()
		status.hide()
	else:
		export_btn.pressed.connect(_on_export_telemetry_pressed.bind(status))
	parent.add_child(export_btn)
	parent.add_child(status)


## M4 (M1.6) / RD-9: the export action (web-only; the signal is connected only there).
## Pure read of the existing JSONL log, handed to the browser as a download — identical
## to SellScreen's path (no schema/arity change). Must run inside the button-press gesture.
func _on_export_telemetry_pressed(status: Label) -> void:
	if not TelemetryExporter.has_log():
		status.text = tr("CFG_EXPORT_EMPTY")
		return
	var filename := TelemetryExporter.download_filename()
	if TelemetryExporter.export():
		status.text = tr("CFG_EXPORT_DONE").format({"name": filename})
	else:
		status.text = tr("CFG_EXPORT_EMPTY")


# --- Per-field rows -----------------------------------------------------------

## A labelled row: [ field label ] [ control(s) ] [ live value ]. The control is the
## typed editor chosen per the field's variant type + export hint (§3.2 table).
func _build_row(parent: Control, field: String) -> void:
	var row := HBoxContainer.new()
	row.name = "Row_%s" % field
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = tr("CFG_FIELD_%s" % field.to_upper())
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)

	var value = _cfg.get(field)
	var type := typeof(value)

	if field == "r3_threshold_levels":
		_build_list_editor(row, field)
	elif type == TYPE_BOOL:
		_build_bool(row, field)
	elif type == TYPE_STRING:
		_build_string(row, field)
	elif _is_enum_field(field):
		_build_enum(row, field)
	elif type == TYPE_INT or type == TYPE_FLOAT:
		if field == "seed_override":
			_build_unbounded_spin(row, field)
		else:
			_build_numeric(row, field, type == TYPE_INT)
	else:
		push_error("ConfigMenu: no widget for field '%s' (type %d)" % [field, type])


func _build_bool(row: Control, field: String) -> void:
	_rows[field] = _make_bool_widget(row,
		func(on: bool) -> void: _set_field(field, on))


func _build_string(row: Control, field: String) -> void:
	var le := LineEdit.new()
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.placeholder_text = "(auto)"
	le.text_changed.connect(func(t: String) -> void: _set_field(field, t))
	row.add_child(le)
	_rows[field] = le


## @export_enum int → OptionButton; items are the schema's own hint strings in declared
## order, tagged "(placeholder)" until R2/R3 finalise (§3.3). Selected index == stored int.
func _build_enum(row: Control, field: String) -> void:
	var items: Array = []
	for opt in _enum_hint_strings(field):
		items.append(tr("CFG_ENUM_PLACEHOLDER").format({"name": opt}))
	_rows[field] = _make_enum_widget(row, items,
		func(idx: int) -> void: _set_field(field, idx))


## Numeric scalar (int/float): an HSlider for fast scrub PLUS a SpinBox that is
## type-exact and uncapped beyond the slider range (§3.4a). The two stay in sync;
## the underlying field always holds the SpinBox's (typed) value.
func _build_numeric(row: Control, field: String, is_int: bool) -> void:
	var rng: Vector2 = FIELD_RANGE.get(field, RANGE_MAGNITUDE)
	var step := 1.0 if is_int else 0.1
	# A probability range gets a finer step regardless of int-ness.
	if rng == RANGE_PROB:
		step = 0.01
	# I1: per-field step override (lvl_size_mult -> 0.25 so px/cell stays integer).
	if FIELD_STEP.has(field):
		step = FIELD_STEP[field]
	# I1: lvl_room_count carries a -1 sentinel ("use baseline") below its slider min of
	# 1, so the SpinBox must allow -1 even though the scrub slider starts at 1.
	var spin_min := -1.0 if field == "lvl_room_count" else rng.x
	# Store the SpinBox as the canonical control (it holds the exact typed value);
	# the slider is reached as its sibling for refresh.
	_rows[field] = _make_numeric_widget(row, rng, step, spin_min,
		max(rng.y * 100.0, 100000.0),
		func(v: float) -> void: _set_field(field, int(round(v)) if is_int else v))


# --- Shared widget cores (S4 §3.3 refactor) -------------------------------------
# The construction internals of the bool/enum/numeric widgets, factored to take a
# SETTER Callable so the legacy rows (setter = a _set_field closure) and the S4
# generated def rows (setter = an override-staging closure) share ONE widget
# implementation. Pure refactor: the legacy _rows registration, ranges, steps and
# behaviour are byte-equivalent to the pre-S4 inline bodies.

func _make_bool_widget(row: Control, setter: Callable) -> CheckButton:
	var cb := CheckButton.new()
	cb.toggled.connect(func(on: bool) -> void: setter.call(on))
	row.add_child(cb)
	return cb


func _make_enum_widget(row: Control, items: Array, setter: Callable) -> OptionButton:
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: Variant in items:
		ob.add_item(str(item))
	ob.item_selected.connect(func(idx: int) -> void: setter.call(idx))
	row.add_child(ob)
	return ob


## The HSlider+SpinBox pair. SpinBox is the source of truth (type-exact, allow_greater
## past the slider cap); the slider mirrors/clamps its handle. Returns the SpinBox
## (the canonical control; the slider is its "Slider"-named sibling for refresh).
func _make_numeric_widget(row: Control, rng: Vector2, step: float, spin_min: float,
		spin_max: float, setter: Callable) -> SpinBox:
	var slider := HSlider.new()
	slider.name = "Slider"
	slider.min_value = rng.x
	slider.max_value = rng.y
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(120, 0)
	row.add_child(slider)

	var spin := SpinBox.new()
	spin.name = "Spin"
	spin.step = step
	spin.min_value = spin_min
	# Type-exact escape hatch: allow values beyond the slider cap. Generous SpinBox
	# max so typing isn't clamped.
	spin.max_value = spin_max
	spin.allow_greater = true
	spin.custom_minimum_size = Vector2(80, 0)
	row.add_child(spin)

	spin.value_changed.connect(func(v: float) -> void:
		slider.set_value_no_signal(clampf(v, slider.min_value, slider.max_value))
		setter.call(v)
	)
	slider.value_changed.connect(func(v: float) -> void:
		spin.set_value_no_signal(v)
		setter.call(v)
	)
	return spin


## seed_override: a plain SpinBox, min -1 (= "auto"), no slider (it's an identity, not
## a magnitude to scrub).
func _build_unbounded_spin(row: Control, field: String) -> void:
	var spin := SpinBox.new()
	spin.min_value = -1
	spin.max_value = 2147483647
	spin.step = 1
	spin.allow_greater = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(func(v: float) -> void: _set_field(field, int(v)))
	row.add_child(spin)
	_rows[field] = spin


## r3_threshold_levels (PackedFloat32Array) — the one non-scalar. A mini list editor:
## rows of [SpinBox][x remove] + an [+ add level] button, kept sorted ascending; empty
## is valid (§3.4). Stored as the VBox container; read/write go through helpers.
func _build_list_editor(row: Control, field: String) -> void:
	var editor := VBoxContainer.new()
	editor.name = "ListEditor"
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_theme_constant_override("separation", 2)
	row.add_child(editor)

	var rows_box := VBoxContainer.new()
	rows_box.name = "Rows"
	rows_box.add_theme_constant_override("separation", 2)
	editor.add_child(rows_box)

	var add := Button.new()
	add.name = "AddButton"
	add.text = tr("CFG_LIST_ADD")
	add.pressed.connect(func() -> void:
		var arr := _list_values_from_editor(editor)
		arr.append(0.0)
		_apply_list(field, editor, arr)
	)
	editor.add_child(add)

	_rows[field] = editor


# --- List-editor helpers ------------------------------------------------------

## Rebuild the list-editor rows from a float array, keep it sorted ascending, and write
## it back to the working config as a PackedFloat32Array.
func _apply_list(field: String, editor: VBoxContainer, values: Array) -> void:
	var floats: Array = []
	for v in values:
		floats.append(float(v))
	floats.sort()
	_rebuild_list_rows(editor, floats)
	var packed := PackedFloat32Array()
	for v in floats:
		packed.append(v)
	_set_field(field, packed)


func _rebuild_list_rows(editor: VBoxContainer, values: Array) -> void:
	var rows_box: VBoxContainer = editor.get_node("Rows")
	for child in rows_box.get_children():
		child.queue_free()
	for i in values.size():
		var lr := HBoxContainer.new()
		lr.add_theme_constant_override("separation", 4)
		var spin := SpinBox.new()
		spin.min_value = 0.0
		spin.max_value = 1.0
		spin.step = 0.01
		spin.allow_greater = true
		spin.value = values[i]
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		var field := editor.get_parent().name.trim_prefix("Row_")
		spin.value_changed.connect(func(_v: float) -> void:
			_apply_list(field, editor, _list_values_from_editor(editor))
		)
		lr.add_child(spin)
		var rm := Button.new()
		rm.text = tr("CFG_LIST_REMOVE")
		rm.pressed.connect(func() -> void:
			var arr := _list_values_from_editor(editor)
			if idx < arr.size():
				arr.remove_at(idx)
			_apply_list(field, editor, arr)
		)
		lr.add_child(rm)
		rows_box.add_child(lr)


func _list_values_from_editor(editor: VBoxContainer) -> Array:
	var out: Array = []
	var rows_box: VBoxContainer = editor.get_node("Rows")
	for lr in rows_box.get_children():
		var spin := lr.get_child(0) as SpinBox
		if spin != null:
			out.append(spin.value)
	return out


# --- Field write (view -> model) ----------------------------------------------

func _set_field(field: String, value) -> void:
	_cfg.set(field, value)
	print("[ConfigMenu] %s = %s" % [field, str(value)])   # local debug only (staging path: no EventBus)
	_refresh_section_chip(_prefix_of(field))
	_refresh_summary()


# --- Master toggle ------------------------------------------------------------

func _on_master_toggled(on: bool, master_field: String, prefix: String) -> void:
	_cfg.set(master_field, on)
	_dim_bodies_for(prefix, not on)
	_refresh_section_chip(prefix)
	_refresh_summary()


## M4 (M1.6) / RD-5: dim a section's body (or BODIES). For "r4_" this dims BOTH the
## maze body ("r4_") and the split-out Vision body (R4_VISION_KEY) off the single
## r4_enabled master — so toggling R4 off in Level Gen visibly dims the Vision tab too.
## Every other prefix has exactly one body.
func _dim_bodies_for(prefix: String, dimmed: bool) -> void:
	_set_body_dimmed(prefix, dimmed)
	if prefix == "r4_":
		_set_body_dimmed(R4_VISION_KEY, dimmed)


# --- Reset --------------------------------------------------------------------

## Reload the script defaults (all-off == M1.0 baseline) and re-project into every
## control + chip + summary. The one-click "give me the control config" action.
func _on_reset_pressed() -> void:
	_cfg = _load_default()
	_refresh_all()


# --- Refresh (model -> view) --------------------------------------------------

func _refresh_all() -> void:
	for field in _rows.keys():
		_push_value_to_control(field)
	for sec in SECTIONS:
		_refresh_section_chip(sec.prefix)
		if sec.master != "":
			# M4 (M1.6) / RD-5: dual-dim so a Reset/boot projects R4's dim onto BOTH the
			# maze body and the split-out Vision body (the "r4_" branch in _dim_bodies_for).
			_dim_bodies_for(sec.prefix, not bool(_cfg.get(sec.master)))
	_refresh_summary()


func _push_value_to_control(field: String) -> void:
	# M1.9 (S4): the two generic-lever fields are bound via sentinel controls; their
	# "refresh" is re-projecting the staged lever state into every generated
	# master/widget/chip — which is exactly what Reset needs (§3.4 Layer 1).
	if field == "oppositions_enabled" or field == "param_overrides":
		_refresh_def_sections()
		return
	var control = _rows[field]
	var value = _cfg.get(field)
	if control is CheckButton:
		(control as CheckButton).set_pressed_no_signal(bool(value))
	elif control is LineEdit:
		(control as LineEdit).text = str(value)
	elif control is OptionButton:
		(control as OptionButton).select(int(value))
	elif control is SpinBox:
		(control as SpinBox).set_value_no_signal(float(value))
		# Mirror into the paired slider if this row has one.
		var slider := (control as SpinBox).get_parent().get_node_or_null("Slider") as HSlider
		if slider != null:
			slider.set_value_no_signal(clampf(float(value), slider.min_value, slider.max_value))
	elif control is VBoxContainer and field == "r3_threshold_levels":
		var arr: Array = []
		for v in (value as PackedFloat32Array):
			arr.append(v)
		_rebuild_list_rows(control, arr)


# --- Chips & summary ----------------------------------------------------------

func _refresh_section_chip(prefix: String) -> void:
	if not _section_chips.has(prefix):
		return
	var chip: Label = _section_chips[prefix]
	if prefix == "":
		# Meta has no master / no ON-OFF; show seed at a glance.
		var s := int(_cfg.get("seed_override"))
		chip.text = (tr("CFG_SEED_AUTO") if s < 0 else str(s))
		return
	var on := bool(_cfg.get("%senabled" % prefix))
	if not on:
		chip.text = tr("CFG_CHIP_OFF")
		return
	chip.text = "%s · %s" % [tr("CFG_CHIP_ON"), _section_summary(prefix)]


## The one-line "most load-bearing values" summary shown on an ON section's chip.
func _section_summary(prefix: String) -> String:
	match prefix:
		# V3b (M1.12): the "r1_" chip summary was RETIRED with the r1_* section.
		"r2_":
			return tr("CFG_CHIP_R2_SUMMARY").format({
				"mechanism": _enum_label("r2_mechanism"),
				"cost": _num(_cfg.get("r2_cost_magnitude")),
			})
		"r3_":
			return tr("CFG_CHIP_R3_SUMMARY").format({
				"rate": _num(_cfg.get("r3_base_climb_rate")),
				"levels": (_cfg.get("r3_threshold_levels") as PackedFloat32Array).size(),
			})
		"r4_":
			return tr("CFG_CHIP_R4_SUMMARY").format({
				"chance": _num(_cfg.get("r4_branch_chance_base")),
				"vision": _num(_cfg.get("r4_vision_radius")),
			})
		"lvl_":
			var c := int(_cfg.get("lvl_room_count"))
			return tr("CFG_CHIP_LVL_SUMMARY").format({
				"count": (tr("CFG_LVL_COUNT_BASE") if c < 1 else str(c)),
				"mult": _num(_cfg.get("lvl_size_mult")),
			})
	return ""


## The headline scan line — "RUN: R1[x] R2[ ] R3[x] R4[ ] · seed auto".
func _refresh_summary() -> void:
	if _summary_label == null:
		return
	var s := int(_cfg.get("seed_override"))
	var seed_str := (tr("CFG_SEED_AUTO") if s < 0 else str(s))
	# V3b (M1.12): the R1 flag dropped from the headline — the pursuer is a deck card now.
	_summary_label.text = tr("CFG_RUN_SUMMARY").format({
		"r2": _flag(bool(_cfg.get("r2_enabled"))),
		"r3": _flag(bool(_cfg.get("r3_enabled"))),
		"r4": _flag(bool(_cfg.get("r4_enabled"))),
		"seed": seed_str,
	})
	_refresh_trap_warning()


## J1/BUG6 config-trap warn line. Lists every enabled-but-inert opposition the working
## config holds (RunConfig.inert_enabled_oppositions()) so the Director sees a dead
## section before committing the run. WARN-ONLY — never blocks Start; hidden when clean.
func _refresh_trap_warning() -> void:
	if _trap_label == null:
		return
	var traps := _cfg.inert_enabled_oppositions()
	# M1.9 (S4): the detector generalized to defs (OppositionLint — schema-flagged
	# trap_if_neutral params + the fully-neutral-card trap). Scope: only ids in
	# cfg.oppositions_enabled are checked (deck-driven defs are author-owned content,
	# §8.1 Q8). Same amber warn-only line; def traps render as raw "<id>:<key>"
	# tokens (an unbounded CSV key-space per def would defeat "content is data").
	var def_traps := OppositionLint.inert_enabled_defs(_cfg, _defs)
	if traps.is_empty() and def_traps.is_empty():
		_trap_label.visible = false
		_trap_label.text = ""
		return
	var parts: PackedStringArray = PackedStringArray()
	for id in traps:
		parts.append(tr("CFG_TRAP_%s" % id.to_upper()))
	for t in def_traps:
		parts.append(t)
	_trap_label.text = tr("CFG_TRAP_WARN").format({"traps": ", ".join(parts)})
	_trap_label.visible = true


func _set_body_dimmed(prefix: String, dimmed: bool) -> void:
	if not _section_bodies.has(prefix):
		return
	var body: Control = _section_bodies[prefix]
	body.modulate = Color(1, 1, 1, DIM_ALPHA if dimmed else 1.0)


# --- Small helpers ------------------------------------------------------------

func _flag(on: bool) -> String:
	return tr("CFG_FLAG_ON") if on else tr("CFG_FLAG_OFF")


func _num(v) -> String:
	var f := float(v)
	return str(int(f)) if is_equal_approx(f, round(f)) else ("%.1f" % f)


func _prefix_of(field: String) -> String:
	for p in ["r2_", "r3_", "r4_", "lvl_",   # V3b (M1.12): r1_ prefix retired with the r1_* knobs
			# M1.4 (K0): the 7 new section prefixes — without these a new knob's live
			# chip/summary refresh would mis-route to the Meta section.
			"quota_", "cam_", "timer_", "exit_",   # V3 (M1.12): hpp_/hbomb_/hspike_ prefixes retired
			# M1.5 (L0): the new throw_ section prefix.
			"throw_"]:
		if field.begins_with(p):
			return p
	return ""


## True iff `field` is an @export_enum int (PROPERTY_HINT_ENUM in the property list).
func _is_enum_field(field: String) -> bool:
	for p in _cfg.get_property_list():
		if p.name == field:
			return int(p.hint) == PROPERTY_HINT_ENUM
	return false


## The enum's hint strings in declared order (e.g. ["lengthen","decay_behind",...]).
func _enum_hint_strings(field: String) -> PackedStringArray:
	for p in _cfg.get_property_list():
		if p.name == field:
			return String(p.hint_string).split(",", false)
	return PackedStringArray()


## The currently-selected enum option's raw name (for chip summaries).
func _enum_label(field: String) -> String:
	var opts := _enum_hint_strings(field)
	var idx := int(_cfg.get(field))
	if idx >= 0 and idx < opts.size():
		return opts[idx]
	return str(idx)
