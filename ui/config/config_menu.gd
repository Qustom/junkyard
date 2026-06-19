class_name ConfigMenu
extends Control
## ConfigMenu (CFG, M1.1) — the greybox pre-run config panel beside the Start Run
## menu. It owns ONE working RunConfig it mutates as the Director edits the knobs,
## and exposes that working config via apply_and_get_config() so MainGame can stage
## it inside start_new_run() (ratified shape (a), §3.5 — the menu does NOT call
## start_new_run or touch GameState/EventBus itself; it only reads + writes the R0
## RunConfig schema and hands the result to the existing run-entry seam).
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

## Per-section descriptor: prefix (Meta = ""), the CSV title/gloss keys, the master
## field name ("" = none, Meta), whether the section is collapsible.
const SECTIONS := [
	{"prefix": "", "title_key": "CFG_SEC_META", "gloss_key": "", "master": "", "collapsible": false},
	{"prefix": "r1_", "title_key": "CFG_SEC_R1", "gloss_key": "CFG_GLOSS_R1", "master": "r1_enabled", "collapsible": true},
	{"prefix": "r2_", "title_key": "CFG_SEC_R2", "gloss_key": "CFG_GLOSS_R2", "master": "r2_enabled", "collapsible": true},
	{"prefix": "r3_", "title_key": "CFG_SEC_R3", "gloss_key": "CFG_GLOSS_R3", "master": "r3_enabled", "collapsible": true},
	{"prefix": "r4_", "title_key": "CFG_SEC_R4", "gloss_key": "CFG_GLOSS_R4", "master": "r4_enabled", "collapsible": true},
]

## HAND-AUTHORED field manifest (§3.6 — NOT reflection). Each section's ordered field
## list; the master field appears here too (rendered in the header, skipped in the body).
## The build-time coverage assertion checks the flattened set == RunConfig's exported
## field set, so no knob can go unreachable.
const MANIFEST := {
	"": ["seed_override", "build_tag"],
	"r1_": [
		"r1_enabled", "r1_depth_threshold", "r1_linger_seconds", "r1_chase_speed",
		"r1_speed_per_depth", "r1_catch_radius", "r1_catch_kills", "r1_spawn_count",
	],
	"r2_": [
		"r2_enabled", "r2_mechanism", "r2_cost_magnitude", "r2_cost_per_depth",
		"r2_depth_threshold", "r2_toll_resource",
	],
	"r3_": [
		"r3_enabled", "r3_base_climb_rate", "r3_rate_per_depth", "r3_threshold_levels",
		"r3_penalty_kind", "r3_penalty_magnitude", "r3_max_forces_loss", "r3_decay_on_retreat",
	],
	"r4_": [
		"r4_enabled", "r4_branch_chance_base", "r4_branch_per_depth", "r4_max_branch_depth",
		"r4_vision_radius", "r4_vision_tighten_per_depth", "r4_fog_enabled", "r4_lost_proxy_threshold",
	],
}

## Per-field slider range lookup (§3.4a). Only numeric (int/float) scalar fields appear;
## bools/enums/strings/arrays use their own widgets. seed_override is an unbounded SpinBox.
const FIELD_RANGE := {
	"r1_depth_threshold": RANGE_DEPTH,
	"r1_linger_seconds": RANGE_SECONDS,
	"r1_chase_speed": RANGE_SPEED,
	"r1_speed_per_depth": RANGE_MAGNITUDE,
	"r1_catch_radius": RANGE_RADIUS,
	"r1_spawn_count": RANGE_DEPTH,
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
}

# Dimming alpha for a section body whose master is OFF (redundant "inert" cue).
const DIM_ALPHA := 0.45

var _cfg: RunConfig                       # the working config (a duplicate, never the on-disk .tres)
var _rows: Dictionary = {}                # field_name -> the bound control node (for read-back / refresh)
var _section_bodies: Dictionary = {}      # prefix -> the body container (dim target)
var _section_chips: Dictionary = {}       # prefix -> the ON/OFF + summary chip Label
var _summary_label: Label = null

# Built UI roots (created in _build_ui).
var _scroll_vbox: VBoxContainer = null


func _ready() -> void:
	_cfg = _load_default()
	_build_ui()
	_assert_full_coverage()               # build-time: no RunConfig knob left unreachable
	_refresh_all()


# --- Working config -----------------------------------------------------------

## Duplicate the on-disk all-off default so the working config is independent and the
## .tres is never mutated. Falls back to a fresh RunConfig (also all-off) if missing.
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
	# Outer panel fills the rail; a scroll holds summary bar + the five sections.
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.name = "Outer"
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)

	_build_summary_bar(outer)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_scroll_vbox = VBoxContainer.new()
	_scroll_vbox.name = "Sections"
	_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(_scroll_vbox)

	for sec in SECTIONS:
		_build_section(sec)


func _build_summary_bar(parent: Control) -> void:
	var bar := VBoxContainer.new()
	bar.name = "SummaryBar"
	bar.add_theme_constant_override("separation", 6)
	parent.add_child(bar)

	_summary_label = Label.new()
	_summary_label.name = "SummaryLabel"
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(_summary_label)

	# Reset is part of the highest-contrast legibility layer — make it prominent.
	var reset := Button.new()
	reset.name = "ResetButton"
	reset.text = tr("CFG_RESET")
	reset.custom_minimum_size = Vector2(0, 36)
	reset.pressed.connect(_on_reset_pressed)
	bar.add_child(reset)

	bar.add_child(HSeparator.new())


func _build_section(sec: Dictionary) -> void:
	var prefix: String = sec.prefix
	var box := PanelContainer.new()
	box.name = "Section_%s" % (prefix if prefix != "" else "meta")
	_scroll_vbox.add_child(box)

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
	var cb := CheckButton.new()
	cb.toggled.connect(func(on: bool) -> void: _set_field(field, on))
	row.add_child(cb)
	_rows[field] = cb


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
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for opt in _enum_hint_strings(field):
		ob.add_item(tr("CFG_ENUM_PLACEHOLDER").format({"name": opt}))
	ob.item_selected.connect(func(idx: int) -> void: _set_field(field, idx))
	row.add_child(ob)
	_rows[field] = ob


## Numeric scalar (int/float): an HSlider for fast scrub PLUS a SpinBox that is
## type-exact and uncapped beyond the slider range (§3.4a). The two stay in sync;
## the underlying field always holds the SpinBox's (typed) value.
func _build_numeric(row: Control, field: String, is_int: bool) -> void:
	var rng: Vector2 = FIELD_RANGE.get(field, RANGE_MAGNITUDE)
	var step := 1.0 if is_int else 0.1
	# A probability range gets a finer step regardless of int-ness.
	if rng == RANGE_PROB:
		step = 0.01

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
	spin.min_value = rng.x
	# Type-exact escape hatch: allow values beyond the slider cap (and below 0 never,
	# these knobs are all >= 0). Use a generous SpinBox max so typing isn't clamped.
	spin.max_value = max(rng.y * 100.0, 100000.0)
	spin.allow_greater = true
	spin.custom_minimum_size = Vector2(80, 0)
	row.add_child(spin)

	# SpinBox is the source of truth for the field; the slider mirrors/clamps its handle.
	spin.value_changed.connect(func(v: float) -> void:
		slider.set_value_no_signal(clampf(v, slider.min_value, slider.max_value))
		_set_field(field, int(round(v)) if is_int else v)
	)
	slider.value_changed.connect(func(v: float) -> void:
		spin.set_value_no_signal(v)
		_set_field(field, int(round(v)) if is_int else v)
	)
	# Store the SpinBox as the canonical control (it holds the exact typed value);
	# the slider is reached as its sibling for refresh.
	_rows[field] = spin


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
	print("[ConfigMenu] %s = %s" % [field, str(value)])   # local debug only (no EventBus)
	_refresh_section_chip(_prefix_of(field))
	_refresh_summary()


# --- Master toggle ------------------------------------------------------------

func _on_master_toggled(on: bool, master_field: String, prefix: String) -> void:
	_cfg.set(master_field, on)
	_set_body_dimmed(prefix, not on)
	_refresh_section_chip(prefix)
	_refresh_summary()


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
			_set_body_dimmed(sec.prefix, not bool(_cfg.get(sec.master)))
	_refresh_summary()


func _push_value_to_control(field: String) -> void:
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
		"r1_":
			return tr("CFG_CHIP_R1_SUMMARY").format({
				"depth": int(_cfg.get("r1_depth_threshold")),
				"speed": _num(_cfg.get("r1_chase_speed")),
			})
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
	return ""


## The headline scan line — "RUN: R1[x] R2[ ] R3[x] R4[ ] · seed auto".
func _refresh_summary() -> void:
	if _summary_label == null:
		return
	var s := int(_cfg.get("seed_override"))
	var seed_str := (tr("CFG_SEED_AUTO") if s < 0 else str(s))
	_summary_label.text = tr("CFG_RUN_SUMMARY").format({
		"r1": _flag(bool(_cfg.get("r1_enabled"))),
		"r2": _flag(bool(_cfg.get("r2_enabled"))),
		"r3": _flag(bool(_cfg.get("r3_enabled"))),
		"r4": _flag(bool(_cfg.get("r4_enabled"))),
		"seed": seed_str,
	})


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
	for p in ["r1_", "r2_", "r3_", "r4_"]:
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
