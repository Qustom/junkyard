class_name Hub
extends Node2D
## Hub (M2, M1.6) — the walkable between-runs surface. The "surface you stand on":
## a small greybox junkyard room you boot into (from the Main Menu) and return to after
## every dive. Reads META ONLY (Money, banked haul, owned_items); holds NO run-state — it
## never calls GameState.start_run/enter_band/stage_run_config, never instances a DiveClock,
## never builds a RunInventory. Entered via the persistent App router (scenes/app/app.gd),
## which swaps it in and emits hub_entered AFTER this scene is in the tree.
##
## Two jobs on entry (RD-5/RD-6):
##   1. Place the Player at the fixed PlayerSpawn marker (the room is static — no generated
##      entry). The Player scene brings its own InteractionDetector + prompt, so the portal
##      and the M3 shop work for free off the owner-acts-on-interaction_requested contract.
##   2. The GUARANTEED Hub-return beat: evaluate the dive's quota off the HELD banked haul
##      and, on a MISS, run the roguelite wipe — BEFORE the portal is usable. This runs on
##      EVERY return (the hub's _ready is the guaranteed beat), so re-diving without ever
##      visiting the Shop can NEVER skip the roguelite wipe (the loop-integrity fix). The
##      held haul is held-banked (not auto-sold); M3's Shop converts it to Money.
##
## M3 (M1.6): the interim held-haul readout (the old RD-7 throwaway) is RETIRED — the Shop's
## SELL tab is now the haul readout. A player-facing "QUOTA MISSED — progress wiped" banner
## (W2-F2) surfaces the roguelite wipe that fires on this return beat.

@onready var _player: Player = $Player
@onready var _player_spawn: Marker2D = $PlayerSpawn
@onready var _quota_notice: Label = $HudLayer/QuotaNotice


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
	#    re-eval, so a Shop sale can never double-advance the quota. A MISS also raises the
	#    player-facing W2-F2 banner (set BEFORE the wipe clears the bank, read from the
	#    cached quota result which wipe_meta does not touch).
	_resolve_return_quota()

	# NB: the App router emits hub_entered after the swap (app.gd:goto_hub/_return_after_dive);
	# the Hub does NOT re-emit it here (would double-fire). No GameState.start_run, no
	# DiveClock instance, no stage_run_config — the clock cannot tick in the hub because
	# nothing emits run_started here.


## RD-6 + W2-F2: the quota outcome + roguelite wipe on the guaranteed return beat. Evaluate
## the quota off the held bank; on a MISS, surface the player-facing "QUOTA MISSED — progress
## wiped" banner AND run the roguelite wipe (the reset: run 1 / quota_base / cleared meta).
## The wipe is the integrity-critical routing M2 shipped; M3 layers the banner on the same beat.
func _resolve_return_quota() -> void:
	var result: Dictionary = GameState.evaluate_quota_on_return()
	# A MISS is checked == true && met == false. {"checked": false} (no quota / fresh boot)
	# is inert → the banner stays hidden.
	var missed: bool = bool(result.get("checked", false)) and not bool(result.get("met", true))
	if _quota_notice != null:
		_quota_notice.visible = missed
	if missed:
		GameState.wipe_meta()
