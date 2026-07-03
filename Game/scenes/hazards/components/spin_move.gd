class_name SpinMove
extends OppositionComponent
## SpinMove (S2) — the K5c spike's constant-angular-velocity rotation + deterministic
## phase seed, transplanted VERBATIM from spike_hazard.gd. The rotation IS the
## telegraph. The per-instance start phase is a pure function of ctx["phase_salt"]
## (the spawn seam derives it deterministically) — never a random draw.
##
## Reused by: spike only. Params read: `rotation_speed_deg` (signed deg/s → signed
## rad/s, direction baked in). Ctx read: `phase_salt`.

var _spin_angle: float = 0.0    # current rotation (radians)
var _omega: float = 0.0         # angular velocity (rad/s), signed → direction


func _configure(p: Dictionary, ctx: Dictionary) -> void:
	_omega = deg_to_rad(float(p.get("rotation_speed_deg", 0.0)))
	# Deterministic per-instance phase (OQ-5): a pure function of the salt —
	# reproducible run-to-run. * 47 spreads adjacent salts around the circle.
	var phase_salt: int = int(ctx.get("phase_salt", 0))
	_spin_angle = deg_to_rad(float(posmod(phase_salt * 47, 360)))
	host.rotation = _spin_angle


func tick(delta: float) -> void:
	_spin_angle = wrapf(_spin_angle + _omega * delta, 0.0, TAU)
	host.rotation = _spin_angle    # spins the Tell Polygon2D with the node


## The live blade angle — read by LethalContact's arm_segments mode (S2 §2.2).
func spin_angle() -> float:
	return _spin_angle
