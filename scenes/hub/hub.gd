class_name Hub
extends Node2D
## Hub (M2, M1.6) — the walkable between-runs surface. The "surface you stand on":
## a small greybox junkyard room you boot into (from the Main Menu) and return to after
## every dive. Reads META ONLY (Money, banked haul); holds NO run-state — it never calls
## GameState.start_run/enter_band/stage_run_config, never instances a DiveClock, never
## builds a RunInventory. Entered via the persistent App router (scenes/app/app.gd), which
## swaps it in and emits hub_entered AFTER this scene is in the tree.
##
## Two jobs on entry (RD-5/RD-6):
##   1. Place the Player at the fixed PlayerSpawn marker (the room is static — no generated
##      entry). The Player scene brings its own InteractionDetector + prompt, so the portal
##      (and M3's shop) work for free off the owner-acts-on-interaction_requested contract.
##   2. The GUARANTEED Hub-return beat: evaluate the dive's quota off the HELD banked haul
##      and, on a MISS, run the roguelite wipe — BEFORE the portal is usable. This runs on
##      EVERY return (the hub's _ready is the guaranteed beat), so re-diving without ever
##      visiting the Shop can NEVER skip the roguelite wipe (the loop-integrity fix). The
##      held haul is held-banked (not auto-sold); M3's Shop converts it to Money later.
##
## The held-haul readout (RD-7) is a THROWAWAY interim: M3's Shop deletes it.

@onready var _player: Player = $Player
@onready var _player_spawn: Marker2D = $PlayerSpawn
@onready var _held_haul_label: Label = $HudLayer/HeldHaul


func _ready() -> void:
	# 1. Place the player at the fixed hub spawn (static room — no generated entry).
	if _player != null and _player_spawn != null:
		_player.global_position = _player_spawn.global_position
		_player.velocity = Vector2.ZERO

	# 2. The guaranteed Hub-return beat: quota eval + roguelite MISS-wipe, BEFORE the
	#    portal is usable. Decoupled from selling (RD-6): evaluate off the HELD banked
	#    haul value, not "what was sold." Inert when the dive had no quota configured
	#    (evaluate_quota_on_return → {"checked": false}) and on a fresh boot (no prior run).
	#    The _quota_evaluated_this_run idempotency guard makes M3's later sell a no-op
	#    re-eval, so a Shop sale can never double-advance the quota.
	_resolve_return_quota()

	# Refresh the throwaway held-haul readout (RD-7) AFTER any wipe, so a MISS shows the
	# wiped (empty) bank. M3's Shop replaces this readout wholesale.
	_refresh_held_haul()

	# NB: the App router emits hub_entered after the swap (app.gd:goto_hub/_return_after_dive);
	# the Hub does NOT re-emit it here (would double-fire). No GameState.start_run, no
	# DiveClock instance, no stage_run_config — the clock cannot tick in the hub because
	# nothing emits run_started here.


## RD-6: the quota outcome + roguelite wipe on the guaranteed return beat. Evaluate the
## quota off the held bank; on a MISS, wipe meta (the roguelite reset) BEFORE the portal
## is usable. In M2's greybox the portal is always usable (no banner gate yet) — the wipe
## simply runs synchronously here, before the first frame the player can walk to it. A
## later iteration can layer a "QUOTA MISSED" banner on top of this same beat (M3's Shop /
## a hub modal); M2 ships the integrity-critical wipe routing.
func _resolve_return_quota() -> void:
	var result: Dictionary = GameState.evaluate_quota_on_return()
	# A MISS is checked == true && met == false. {"checked": false} (no quota / fresh boot)
	# is inert. The wipe is the roguelite reset: back to run 1 / quota_base / cleared meta.
	if bool(result.get("checked", false)) and not bool(result.get("met", true)):
		GameState.wipe_meta()


## RD-7 (THROWAWAY): the interim held-haul readout. Reads the held banked_junk pile (meta)
## as a PURE read — N items + the summed base_sell_value (the same per-item value math
## sell_banked_junk uses, game_state.gd). No mutation. M3's Shop deletes this label + this
## method. Makes the M2 round-trip self-demonstrating (the haul visibly accumulates across
## dives until the Shop sells it).
func _refresh_held_haul() -> void:
	if _held_haul_label == null:
		return
	var count: int = 0
	var value: int = 0
	for item in GameState.banked_junk:
		if item != null:
			count += 1
			value += item.base_sell_value
	_held_haul_label.text = "Held: %d items  ~$%d" % [count, value]
