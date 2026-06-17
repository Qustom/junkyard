class_name DepthCurve
extends Resource
## DepthCurve — authored risk/reward tuning for the "push deeper" axis (B3).
##
## Three Curves, all sampled at a piece's depth_norm (0 at the entry gate, 1 at
## the deepest piece). Reward shaping lives here as data (TDD §2 "Data as
## Resources") so the JunkPlacer code stays curve-shape-agnostic — designers
## retune the feel by dragging points in the inspector once the debug overlay
## makes the rise visible, with no code change.
##
## M1 recommendations (B3 spec "Open questions", Director-resolved):
##   - value_curve:           gently-rising / near-linear ~1.0 -> 1.8.
##   - density_curve:         held roughly flat (tier + value carry the reward
##                            read; flooding deep rooms with quantity would make
##                            shallow pieces feel worthless).
##   - tier_threshold_curve:  STEPPED minimum tier unlocked with depth, so deep
##                            pieces can roll the rarer high-tier junk.

## Junk per-item VALUE multiplier vs depth_norm (0..1). Monotonic rising for M1
## (~1.0 shallow -> ~1.8 deep). Applied as base_sell_value * sample(depth_norm).
@export var value_curve: Curve

## Expected junk COUNT per piece vs depth_norm. Held near-constant in M1; a real
## probabilistic count is drawn from it (integer floor + seeded fractional part).
@export var density_curve: Curve

## Minimum junk TIER (1..5) unlocked at a given depth_norm, sampled then floored.
## Stepped so the "deeper unlocks rarer junk" gate reads clearly to players.
@export var tier_threshold_curve: Curve


## Value multiplier at a depth (clamped to a sane floor so a missing/zeroed curve
## never wipes value). Returns 1.0 if the curve is unset.
func value_mult(depth_norm: float) -> float:
	if value_curve == null:
		return 1.0
	return maxf(value_curve.sample_baked(depth_norm), 0.01)


## Expected (fractional) junk count at a depth. 0.0 if the curve is unset.
func expected_count(depth_norm: float) -> float:
	if density_curve == null:
		return 0.0
	return maxf(density_curve.sample_baked(depth_norm), 0.0)


## Minimum unlocked tier at a depth, floored to an int and clamped to [1,5].
## Returns 1 if the curve is unset.
func min_tier(depth_norm: float) -> int:
	if tier_threshold_curve == null:
		return 1
	return clampi(int(floor(tier_threshold_curve.sample_baked(depth_norm))), 1, 5)
