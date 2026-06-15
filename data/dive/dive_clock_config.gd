extends Resource
class_name DiveClockConfig
## DiveClockConfig — tuning for the in-dive clock (A3), authored as data (TDD §2).
##
## "Light" is the single depleting in-dive resource that creates push-your-luck
## time pressure: it drains while a dive is active and raises a timeout when it
## hits zero. Numbers live here, not in code, so the dive budget can be retuned
## without touching DiveClock. M1 ship values (orchestrator-locked 2026-06-15):
## a SHORT 60-unit budget at 1 unit/sec => ~60s dives, for fast playtest loops.
## This is the single most-playtested number in M1 — treat 60 as a dial.

## Maximum light (also the meter's full value). 1 unit/sec => max_light == seconds.
@export var max_light: float = 60.0

## Light to start a dive with. 0 => start full (use max_light). Lets future
## "descending costs light" / partial-budget dives drop in without code changes.
@export var start_light: float = 0.0

## Drain rate in light-units per second while a dive is active.
@export var drain_per_second: float = 1.0
