class_name DeckEntry
extends Resource
## DeckEntry — per-deck-row param override wrapper (M1.9 S9, the D-RAT-2 delivery).
##
## BandProfile.opposition_deck rows are EITHER plain OppositionDefs OR DeckEntry
## wrappers (mixed Array[Resource], back-compat — the 5 non-charger band_two rows
## stay plain refs). The wrapper lets a band author re-tune a def's params FOR
## THIS DECK ONLY, without touching the def's authored defaults — those stay the
## source of truth everywhere else (test_charger pins the D-RAT-2-letter def
## defaults `throwable_while_charging=true` / `wall_crash_recover_mult=1.0`;
## band_two's deck sets `false` / `2.0` through this wrapper).
##
## The EncounterBuilder unwraps `def` for gating/costing/ordering and merges
## `param_overrides` at ctx time with the LOCKED precedence (breakdown
## §Cross-cutting contracts, deck-driven-def conventions):
##     def params  <  deck-entry overrides  <  rc.param_overrides
## A wrapper with EMPTY overrides is byte-identical to the plain ref
## (test_deck_entry pins it).

## The wrapped OppositionDef. Resource-typed to mirror opposition_deck itself
## (the S1 Q5 convention); the builder casts + fail-louds on broken entries.
@export var def: Resource = null

## String param key -> primitive value, overlaid on def.params at ctx-merge
## time. Deck-level tuning ONLY — rc.param_overrides still wins on top (the
## Director's sweep lever stays the outermost layer).
@export var param_overrides: Dictionary = {}
