class_name SetPieceEntry
extends Resource
## SetPieceEntry — one authored set-piece in a SetPieceInjectConfig pool (M1.9 S5).
##
## A set-piece is just a hand-designed B1 zone piece (PackedScene with a
## Geometry TileMapLayer + tagged Marker2D sockets) wrapped with an injection
## policy (e4: depth gating, frequency caps, dedupe). It lives in the stage
## config's OWN pool — never in the base piece_catalog.tres — so the base
## catalog's weight table (and therefore the control fingerprint) is untouched
## by construction (spec §3.1 / §10 Q2).
##
## Forward hook (deferred, §1.6): curated opposition placements for the
## opposition client (c) will grow here in a later milestone — no field ships
## in M1.9 (YAGNI until the client exists).

## The piece to inject. Reuses the B1 format: scene + piece_id + weight
## (weight drives the seeded pick among eligible entries).
@export var piece: ZonePieceData

## Host-socket depth gate: the set-piece only attaches to an open socket whose
## owner piece's provisional depth_norm is >= this (e4: vaults sit deep).
@export var min_depth_norm: float = 0.0

## Frequency cap per band (e4). Ignored when `unique` is true (cap of 1).
@export var max_per_band: int = 1

## Dedupe (e4): at most one instance of this entry per band.
@export var unique: bool = true
