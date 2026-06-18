class_name RunRules
extends Resource
## RunRules — the data-driven economy knobs for how a FAILED run resolves its
## unbanked haul (E3). Authored as a `.tres` so the most playtest-sensitive
## downside dial (`pockets_fraction`) is tunable without a recompile (TDD §2:
## "Data as Resources").
##
## On death / timeout the player keeps a "pockets" subset of the carried haul and
## loses the rest (Tarkov-style sunk-cost carry penalty). E3 keeps WHOLE items up
## to a value budget = floor(pre_value * pockets_fraction), so F2's sell screen can
## still itemize exactly what survived — you save specific things, not an abstract
## percentage. `pockets_policy` decides which items make the cut.

enum PocketsPolicy { HIGHEST_VALUE, LOWEST_VALUE, RANDOM }

## Fraction of the unbanked haul's *value* the player keeps on a failed run.
## THE headline downside-tuning knob (E3 Open questions) — sweep ~0.15–0.25 at the
## M1 fun gate. 0.20 keeps the sting sharp (lose the clear majority) while leaving
## a small consolation so a death isn't a flat zero.
@export_range(0.0, 1.0, 0.01) var pockets_fraction: float = 0.20

## How whole items are chosen to fill the value budget:
##   HIGHEST_VALUE — save your single best find (kindest, most legible). Default.
##   LOWEST_VALUE  — only keep scraps (harsh).
##   RANDOM        — tense / unfair (uses a seeded local RNG for determinism).
@export var pockets_policy: PocketsPolicy = PocketsPolicy.HIGHEST_VALUE
