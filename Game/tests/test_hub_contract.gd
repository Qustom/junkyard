extends Node
## S8 — the hub functional contract, PROMOTED to a checked-in scene test (M1.9
## Wave 5, spec §5.3). H1/H2/H4 verified these invariants with throwaway
## frame-waited SceneTree scripts; this makes them a standing gate (SG1 and every
## later hub task re-runs it for free), extended with the S8 portal-2 additions.
##
## Run as a SCENE (not --script) so the autoloads resolve:
##   godot --headless --path Game res://tests/test_hub_contract.tscn
##
##   H1. node paths resolve: $Player, $PlayerSpawn, $HudLayer/QuotaNotice, $HubShop,
##       $DeparturePortal, $DeparturePortalBandTwo, $Room/Floor, $Room/Walls
##   H2. the 4 wall collision shapes hold (M1.8 invariant)
##   H3. the iso ground is painted (963 cells — H4's recorded paint)
##   H4. interactable ids &"portal", &"shop", &"portal_band_two" all can_interact()
##   H5. portal 2: band_id &"band_two", prompt names The Sump, position (220,-150)
##       inside the dirt yard (|x|<=340, |y|<=216), ember-orange glow (D-RAT-1),
##       tints actually applied to the sprites (visually distinct placeholder)
##   H6. portal 1: band_id &"near", prompt "Dive", position (0,-150), glow/gate
##       modulate WHITE (rendering byte-identical to pre-S8)

const HUB_PATH := "res://scenes/hub/hub.tscn"
const HUB_GROUND_CELLS := 963              # H4 iso paint (worklog 2026-07-02-H4)
const YARD_X := 340                        # hub_ground.gd dirt-yard half-extents
const YARD_Y := 216
const EMBER_ORANGE := Color(1.0, 0.58, 0.24)   # D-RAT-1 band-2 glow

var _failures: Array[String] = []


func _ready() -> void:
	get_tree().quit(await _run())


func _run() -> int:
	var scene := load(HUB_PATH) as PackedScene
	if scene == null:
		printerr("HUB_CONTRACT FAIL: could not load ", HUB_PATH)
		return 1
	var hub := scene.instantiate() as Node2D
	add_child(hub)
	await get_tree().process_frame   # _ready: spawn placement, quota beat, ground paint

	_check_node_paths(hub)     # H1
	_check_walls(hub)          # H2
	_check_ground(hub)         # H3
	_check_interactables(hub)  # H4
	_check_portal_two(hub)     # H5
	_check_portal_one(hub)     # H6

	hub.queue_free()
	await get_tree().process_frame

	if _failures.is_empty():
		print("HUB_CONTRACT OK — paths + 4 walls + %d ground cells + 3 interactables; " % HUB_GROUND_CELLS,
				"portal 1 unchanged (&\"near\", WHITE), portal 2 routes &\"band_two\" ",
				"(The Sump prompt, ember-orange, (220,-150) in-yard)")
		return 0
	for f in _failures:
		printerr("HUB_CONTRACT FAIL: ", f)
	return 1


# --- H1. Node paths --------------------------------------------------------------

func _check_node_paths(hub: Node2D) -> void:
	for path in ["Player", "PlayerSpawn", "HudLayer/QuotaNotice", "HubShop",
			"DeparturePortal", "DeparturePortalBandTwo", "Room/Floor", "Room/Walls"]:
		if hub.get_node_or_null(path) == null:
			_failures.append("H1: node path '%s' does not resolve" % path)


# --- H2. Wall shapes ---------------------------------------------------------------

func _check_walls(hub: Node2D) -> void:
	var walls := hub.get_node_or_null("Room/Walls")
	if walls == null:
		return   # already reported by H1
	var shapes: int = 0
	for child in walls.get_children():
		var cs := child as CollisionShape2D
		if cs != null and cs.shape != null:
			shapes += 1
	if shapes != 4:
		_failures.append("H2: %d wall collision shapes, expected 4" % shapes)


# --- H3. Iso ground painted ----------------------------------------------------------

func _check_ground(hub: Node2D) -> void:
	var floor_layer := hub.get_node_or_null("Room/Floor") as TileMapLayer
	if floor_layer == null:
		_failures.append("H3: Room/Floor is not a TileMapLayer")
		return
	var cells: int = floor_layer.get_used_cells().size()
	if cells != HUB_GROUND_CELLS:
		_failures.append("H3: ground painted %d cells, expected %d" % [cells, HUB_GROUND_CELLS])


# --- H4. Interactable ids -------------------------------------------------------------

func _check_interactables(hub: Node2D) -> void:
	var expected := {
		"DeparturePortal": &"portal",
		"DeparturePortalBandTwo": &"portal_band_two",
		"HubShop": &"shop",
	}
	for owner_path in expected:
		var it := hub.get_node_or_null(String(owner_path) + "/Interactable") as Interactable
		if it == null:
			_failures.append("H4: %s has no Interactable child" % owner_path)
			continue
		if it.interactable_id != expected[owner_path]:
			_failures.append("H4: %s id is '%s', expected '%s'"
					% [owner_path, it.interactable_id, expected[owner_path]])
		if not it.can_interact():
			_failures.append("H4: %s cannot interact" % owner_path)


# --- H5. Portal 2 (the S8 additions) ----------------------------------------------------

func _check_portal_two(hub: Node2D) -> void:
	var portal := hub.get_node_or_null("DeparturePortalBandTwo") as DeparturePortal
	if portal == null:
		_failures.append("H5: DeparturePortalBandTwo is not a DeparturePortal")
		return
	if portal.band_id != &"band_two":
		_failures.append("H5: portal-2 band_id is '%s', expected &\"band_two\"" % portal.band_id)
	if portal.interactable_id != &"portal_band_two":
		_failures.append("H5: portal-2 interactable_id is '%s'" % portal.interactable_id)
	if portal.position != Vector2(220, -150):
		_failures.append("H5: portal-2 position %s, expected (220, -150)" % portal.position)
	if absf(portal.position.x) > YARD_X or absf(portal.position.y) > YARD_Y:
		_failures.append("H5: portal-2 position %s outside the dirt yard" % portal.position)
	if not String(portal.prompt_text).contains("The Sump"):
		_failures.append("H5: portal-2 prompt '%s' does not name The Sump" % portal.prompt_text)
	if portal.glow_tint == Color.WHITE:
		_failures.append("H5: portal-2 glow_tint is WHITE — not visually distinct")
	if not portal.glow_tint.is_equal_approx(EMBER_ORANGE):
		_failures.append("H5: portal-2 glow_tint %s != D-RAT-1 ember-orange %s"
				% [portal.glow_tint, EMBER_ORANGE])
	# The _ready push-down actually landed on the child + sprites.
	var it := portal.get_node_or_null("Interactable") as Interactable
	if it != null and not String(it.prompt_text).contains("The Sump"):
		_failures.append("H5: portal-2 child Interactable prompt '%s' not pushed down" % it.prompt_text)
	var glow := portal.get_node_or_null("PortalGlow") as Sprite2D
	if glow == null or not glow.modulate.is_equal_approx(portal.glow_tint):
		_failures.append("H5: portal-2 PortalGlow modulate not tinted (%s)"
				% (glow.modulate if glow != null else Color.BLACK))
	var gate := portal.get_node_or_null("DiveGate") as Sprite2D
	if gate == null or gate.modulate == Color.WHITE:
		_failures.append("H5: portal-2 DiveGate modulate not tinted")


# --- H6. Portal 1 (the control — rendering unchanged) ------------------------------------

func _check_portal_one(hub: Node2D) -> void:
	var portal := hub.get_node_or_null("DeparturePortal") as DeparturePortal
	if portal == null:
		_failures.append("H6: DeparturePortal is not a DeparturePortal")
		return
	if portal.band_id != &"near":
		_failures.append("H6: portal-1 band_id is '%s', expected &\"near\"" % portal.band_id)
	if portal.interactable_id != &"portal":
		_failures.append("H6: portal-1 interactable_id is '%s', expected &\"portal\"" % portal.interactable_id)
	if portal.position != Vector2(0, -150):
		_failures.append("H6: portal-1 position %s, expected (0, -150)" % portal.position)
	if portal.prompt_text != "Dive":
		_failures.append("H6: portal-1 prompt '%s', expected 'Dive'" % portal.prompt_text)
	var glow := portal.get_node_or_null("PortalGlow") as Sprite2D
	var gate := portal.get_node_or_null("DiveGate") as Sprite2D
	if glow == null or glow.modulate != Color.WHITE:
		_failures.append("H6: portal-1 PortalGlow modulate != WHITE (rendering moved)")
	if gate == null or gate.modulate != Color.WHITE:
		_failures.append("H6: portal-1 DiveGate modulate != WHITE (rendering moved)")
	var it := portal.get_node_or_null("Interactable") as Interactable
	if it == null or it.interactable_id != &"portal" or it.prompt_text != "Dive" \
			or it.display_name != "Departure Portal":
		_failures.append("H6: portal-1 child Interactable identity moved (push-down not a no-op)")
