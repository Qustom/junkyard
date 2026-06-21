# K7 — Exit placement rework (Phase-2 design)

**Milestone:** M1.4 · **Wave:** 2 (Stakes & spatial) · **Role(s):** general-purpose + game-director-designer
**BlockedBy:** K0 (reads the `exit_*` knob group K0 pre-declares). Wave-2 single-writer pairing with K2 on
`main_game.gd` / `game_state.gd` → **sequence K2 → K7** (K2 lands first; K7 then edits the gate-placement seam).
**Director work-order:** *"Change where the exit could be. Have it spawn randomly around the level. Allow for multiple
to spawn. Allow configuring how often and if it changes with depth. Configure if an exit stays at the spawn."*

---

## 0. Intent (one sentence)

Replace the single hand-offset extract gate with **one-to-many gates placed across the band's floor cells**, whose
**count scales with depth**, with a toggle to **keep one gate pinned at the legacy spawn offset** — all driven by the
`exit_*` `RunConfig` group, with the **all-off default reproducing today's exact single fixed gate** (no fingerprint
movement) and any random placement routed through a **local sub-stream**, never the global RNG.

---

## A. Research (premise, prior art, real APIs)

### A.1 What exists today — exactly one gate at a fixed offset

- **The constant.** `systems/game_state.gd:21-24` — `const GATE_SPAWN_OFFSET := Vector2(160.0, 0.0)`. The doc comment
  is explicit: *"one gate per band at a fixed hand-authored offset from spawn … no seeded placement in M1."*
- **The placement seam.** `scenes/game/main_game.gd:746-753` — `_place_gate(spawn_pos)`:

  ```gdscript
  func _place_gate(spawn_pos: Vector2) -> void:
      var gate_scene := load(GATE_SCENE_PATH) as PackedScene   # GATE_SCENE_PATH = res://entities/gate/extract_gate.tscn
      if gate_scene == null:
          push_error("MainGame: gate scene missing at %s." % GATE_SCENE_PATH)
          return
      _gate = gate_scene.instantiate() as ExtractGate
      _band_container.add_child(_gate)
      _gate.global_position = spawn_pos + GameState.GATE_SPAWN_OFFSET
  ```

  It instantiates **one** `ExtractGate` into `_band_container` (the per-band node freed wholesale by `_clear_band()`,
  `main_game.gd:759-763`) and parks it at `spawn_pos + GATE_SPAWN_OFFSET`. The single member is
  `var _gate: ExtractGate = null` (`main_game.gd:78`).
- **The call site.** `main_game.gd:241-243` — step 4 of band build, right after the spawner is populated and before the
  player is placed at `spawn_pos`. `spawn_pos := _entry_spawn_position(band)` (`main_game.gd:735-741`) is the centre of
  the entry piece's first floor cell. **This is run-state placement: it runs at scene-build time, consumes no RNG, and
  never feeds `fingerprint()`** (which is computed over seed+config during *generation*, upstream of materialisation).
- **The gate is interact-based, not touch-based — IMPORTANT correction to the work-order's framing.** The task brief
  says *"the gate that calls `extract_and_end_run()` on touch."* In the as-built code it is **not** touch: `ExtractGate`
  (`entities/gate/extract_gate.gd`) is an `Area2D` that registers an A2 `Interactable` child on the `interactable`
  layer and listens for `EventBus.interaction_requested(id, target)`; when the focused id is its own `interactable_id`
  (`&"gate"`) it calls `GameState.extract_and_end_run()`. So extraction is **walk-up + press `interact`**, gated by a
  per-gate `_locked` fat-finger lockout. This matters for multiplicity (see A.3) — every gate must be independently
  focusable and must not collide on the shared id.

### A.2 The cell→world projection and the topology K7 reads

K7 places gates at floor cells, exactly like the J3 density hazards and the J2 spread hazards. The reusable pieces:

- **Per-piece floor cells.** `band.pieces[i].floor_cells` — band-global walkable `Vector2i` cells (`entities/band/band.gd`,
  `PlacedPiece`). `band.pieces[i].depth_index` is the piece's within-band depth (entry == 0); `band.max_depth`
  (`band.gd:37-39`) is the deepest graded index.
- **Cell → world.** `main_game.gd:448-451` `_density_cell_to_world(cell)` (identical to `_hazard_spawn_position`'s
  projection, `:512-515`):

  ```gdscript
  func _density_cell_to_world(cell: Vector2i) -> Vector2:
      return Vector2(cell * _band_cell_size_px) + Vector2(_band_cell_size_px, _band_cell_size_px) * 0.5
  ```

  `_band_cell_size_px` is the effective px-per-cell set at materialisation (`main_game.gd:234`), so gate positions
  scale correctly with `lvl_size_mult` for free, just like hazards and junk.
- **Stable, deterministic cell/piece ordering** (the J3 pattern K7 reuses for its candidate pool):
  - `_density_pieces_sorted(band)` (`main_game.gd:422-434`) — pieces in `depth_index` ascending, tie-broken by
    `offset_cell.(y,x)`; skips ungraded pieces (`depth_index < 0`).
  - `_density_sorted_cells(p)` (`main_game.gd:439-445`) — a piece's floor cells in stable `(y, x)` order.
  These give a **reproducible candidate list independent of authored array order** — the prerequisite for both
  placement strategies below being deterministic.

### A.3 Multiple gates — is the extract path safe with N gates?

**Yes, with one fix.** `GameState.extract_and_end_run()` (`game_state.gd:177-211`) is **idempotent**: the `_run_ended`
guard (`game_state.gd:64-70, 180-182`) means the *first* gate to resolve wins and any later/second gate call early-
returns. So "any gate touch ends the run" is already safe at the GameState layer — N gates wired to the same
`extract_and_end_run()` cannot double-bank or fire `run_ended` twice.

**The one wrinkle is the shared `interactable_id`.** Every `ExtractGate` ships with `interactable_id = &"gate"`
(`extract_gate.gd:23`), and `_on_interaction_requested` self-filters on `target.get_parent() != self`
(`extract_gate.gd:42-44`) — i.e. it only acts when the focused `Interactable` is *its own child*. The A2 detector passes
the focused target, so **two gates with the same id do NOT cross-fire**: gate B ignores a request focused on gate A's
child (different parent). The id is a *kind* tag, not a unique handle. So N identical gates are safe as-is — each only
responds when the player is focused on it, and whichever resolves first wins via `_run_ended`. **No id uniqueness is
required**; K7 keeps `&"gate"` on every instance. (If a future A2 change keys focus by id rather than node identity this
would break — flagged in OQ-6, but against the current A2 contract it is safe.)

### A.4 Determinism — the load-bearing constraint (Breakdown §6)

The carried contract: **the all-off control's `fingerprint()` must not move** (fp = `e943ac9c8bc1`). Two facts make this
clean for K7:

1. **Gate placement is pure run-state.** It runs in `_build_and_start_band` *after* generation, at materialisation time.
   It does not feed the generator or `fingerprint()` — exactly like the R1/J2/J3 hazards (Breakdown §6: *"New-hazard
   spawn placement (K5) is pure run-state … like the R1 hazards"*). So even a *randomised* gate layout cannot move the
   fingerprint, because the fingerprint is computed before placement ever runs.
2. **The all-off default must be byte-identical to today.** With `exit_enabled = false` (and the whole `exit_*` group at
   its K0 zero/false defaults), `_place_gate` must produce **exactly one gate at `spawn_pos + GATE_SPAWN_OFFSET`** — the
   same instruction as today's line. This is a *behavioural* identity (one gate, same world position), guaranteed by an
   early-return in the reworked seam, not a generator concern.

**Local sub-stream prior art (the B3/E3 pattern) — the determinism-safe way to consume randomness:**

- `game_state.gd:13-16` — `const POCKETS_RNG_SALT := 0x50434B54  # "PCKT"`, with the doc rule: *"combined with run_seed
  to seed a LOCAL RandomNumberGenerator … Never reseed the global RNG autoload mid-run — that would perturb
  layout/placement determinism."*
- `game_state.gd:380-391` (`_resolve_pockets`, the `RANDOM` policy) — the canonical local-RNG usage:

  ```gdscript
  var rng := RandomNumberGenerator.new()
  rng.seed = run_seed ^ POCKETS_RNG_SALT
  for i in range(ordered.size() - 1, 0, -1):
      var j: int = rng.randi_range(0, i)
      # ... Fisher–Yates swap ...
  ```

- `systems/depth/junk_placer.gd:24-26` — `const _JUNK_SALT := 0x4A554E4B  # "JUNK"`, the same `band.resolved_seed`-mixed
  local sub-stream for loot rolls.

K7 follows this verbatim if it goes random: **a local `RandomNumberGenerator` seeded `run_seed ^ EXITS_RNG_SALT`**,
reproducible per run, never the global `RNG` autoload. The alternative is the **J3 deterministic stride** (no RNG at
all) — see OQ-1.

---

## B. Pseudocode (against the real as-built APIs)

> Convention: `exit_*` knobs are the K0-pre-declared group (`run_config.gd`, see §C). `_band_container`,
> `_band_cell_size_px`, `_density_cell_to_world`, `_density_pieces_sorted`, `_density_sorted_cells`,
> `_entry_spawn_position`, `GATE_SCENE_PATH`, `ExtractGate` are all as-built. The single `var _gate` becomes a list.

### B.1 The new salt + the member change

```gdscript
# main_game.gd — replace the single-gate member with a list (multiple gates).
var _gates: Array[ExtractGate] = []          # was: var _gate: ExtractGate = null

# game_state.gd — alongside POCKETS_RNG_SALT (game_state.gd:16). Local sub-stream salt
# for the K7 random exit placement (B3/E3 pattern). "EXIT" = 0x45584954.
const EXITS_RNG_SALT := 0x45584954
```

`_clear_band()` (`main_game.gd:759-763`) frees the whole `_band_container`, so the gates die with the band for free;
just reset the list:

```gdscript
func _clear_band() -> void:
    _gates.clear()                           # was: _gate = null
    _spawner = null
    for child in _band_container.get_children():
        child.queue_free()
```

### B.2 The reworked placement seam (replaces `_place_gate`, `main_game.gd:746-753`)

```gdscript
## K7 (M1.4): place ONE OR MORE extract gates. All-off default (exit_enabled=false) is
## byte-identical to M1.3: a single gate at spawn_pos + GATE_SPAWN_OFFSET. With exit_enabled,
## counts scale with depth and gates are placed across the band's floor cells (run-state, no
## global RNG → fingerprint unaffected). band is needed for the floor-cell candidate pool.
func _place_gate(band: Band, spawn_pos: Vector2) -> void:
    var rc := GameState.active_run_config

    # --- All-off control: exactly today's single fixed gate (no RNG, no candidate pool). ---
    if rc == null or not rc.exit_enabled:
        _spawn_gate_at(spawn_pos + GameState.GATE_SPAWN_OFFSET)
        EventBus.exits_placed.emit(1, _band_max_depth(band))
        return

    # --- exit_enabled: depth-scaled count of gates placed across the level. ---
    var depth: int = _band_max_depth(band)                       # band.max_depth (band.gd:37)
    var count: int = _exit_count_for_depth(rc, depth)            # >= 1 (see B.3)

    var positions: Array[Vector2] = []

    # exit_keep_one_at_spawn: pin ONE gate at the legacy offset, place the rest in the level.
    if rc.exit_keep_one_at_spawn:
        positions.append(spawn_pos + GameState.GATE_SPAWN_OFFSET)

    var remaining: int = count - positions.size()
    if remaining > 0:
        positions.append_array(_exit_placement_positions(band, rc, remaining, spawn_pos))

    for pos in positions:
        _spawn_gate_at(pos)
    EventBus.exits_placed.emit(positions.size(), depth)


## Thin instantiate helper (the body of the old _place_gate). One ExtractGate, into
## _band_container, at a world position. Every gate keeps interactable_id = &"gate" (A.3:
## same-id gates do NOT cross-fire — each acts only when focused on its own child; the
## first to resolve wins via GameState._run_ended). Appended to _gates.
func _spawn_gate_at(world_pos: Vector2) -> void:
    var gate_scene := load(GATE_SCENE_PATH) as PackedScene
    if gate_scene == null:
        push_error("MainGame: gate scene missing at %s." % GATE_SCENE_PATH)
        return
    var gate := gate_scene.instantiate() as ExtractGate
    _band_container.add_child(gate)
    gate.global_position = world_pos
    _gates.append(gate)
```

Call-site change (`main_game.gd:241-243`): pass the band so the seam has the candidate pool.

```gdscript
    # 4. Place the exit gate(s). All-off = today's single fixed gate.
    var spawn_pos := _entry_spawn_position(band)
    _place_gate(band, spawn_pos)
```

### B.3 The depth-scaled count

```gdscript
## K7: how many exits at this band's depth. base + per-depth ramp, floored at 1 (a band
## must ALWAYS have at least one exit — you can never strand the player), capped by
## exit_max_count when > 0. Pure read, no RNG.
func _exit_count_for_depth(rc: RunConfig, depth: int) -> int:
    var base: int = maxi(rc.exit_base_count, 1)                  # 0 base → treat as 1 (never zero exits)
    var raw: int = base + int(floor(rc.exit_count_per_depth * float(depth)))
    raw = maxi(raw, 1)
    if rc.exit_max_count > 0:
        raw = mini(raw, rc.exit_max_count)
    return raw
```

> Note: with `exit_enabled=true` but `exit_base_count=0`, this yields 1 — a single gate, but now placed by the
> *enabled* strategy (random/stride), not the fixed offset. The fixed-offset single gate is reachable two ways:
> `exit_enabled=false` (the all-off control) or `exit_enabled=true, exit_keep_one_at_spawn=true, base_count=1, max=1`.

### B.4 The placement positions — TWO candidate strategies (OQ-1 picks one)

Both consume the **same stable candidate pool** (`_density_pieces_sorted` → `_density_sorted_cells`) so they are
reproducible. Both **exclude the entry cell and the spawn-offset cell** so a gate never lands on the player's start or
overlaps the pinned spawn gate.

**Strategy A — local sub-stream random (B3/E3 pattern). RECOMMENDED.** Honours the work-order's literal *"spawn
randomly around the level."*

```gdscript
## K7 Strategy A: pick `n` distinct floor cells at random via a LOCAL RNG seeded
## run_seed ^ EXITS_RNG_SALT (B3/E3 pattern — game_state.gd:380-391). Reproducible per run,
## NEVER the global RNG autoload (so fingerprint() is untouched). Spreads candidates across
## ALL graded pieces so exits appear "around the level," not clustered.
func _exit_placement_positions(band: Band, rc: RunConfig, n: int, spawn_pos: Vector2) -> Array[Vector2]:
    var pool: Array[Vector2i] = _exit_candidate_cells(band, spawn_pos)   # stable order, entry/spawn excluded
    if pool.is_empty():
        return [spawn_pos + GameState.GATE_SPAWN_OFFSET]                  # degenerate band → fall back to one fixed gate

    var rng := RandomNumberGenerator.new()
    rng.seed = GameState.run_seed ^ GameState.EXITS_RNG_SALT              # local sub-stream, like POCKETS/JUNK
    # Fisher–Yates over a COPY, then take the first n (distinct cells, no global RNG).
    for i in range(pool.size() - 1, 0, -1):
        var j: int = rng.randi_range(0, i)
        var tmp := pool[i]; pool[i] = pool[j]; pool[j] = tmp

    var out: Array[Vector2] = []
    for k in mini(n, pool.size()):
        out.append(_density_cell_to_world(pool[k]))
    return out
```

**Strategy B — deterministic stride (J3 pattern, no RNG at all).** Mirrors `_density_spawn_positions`
(`main_game.gd:359-397`): walk the sorted candidate pool with an even stride. *Not* random in the literal sense, but
spreads exits evenly and uses zero randomness.

```gdscript
## K7 Strategy B: even stride over the sorted candidate pool — deterministic, NO RNG
## (the J3 density pattern, main_game.gd:391-395). Spreads n exits evenly "around the level."
func _exit_placement_positions(band: Band, rc: RunConfig, n: int, spawn_pos: Vector2) -> Array[Vector2]:
    var pool: Array[Vector2i] = _exit_candidate_cells(band, spawn_pos)
    if pool.is_empty():
        return [spawn_pos + GameState.GATE_SPAWN_OFFSET]
    var out: Array[Vector2] = []
    var stride: int = maxi(pool.size() / maxi(n, 1), 1)
    for k in n:
        out.append(_density_cell_to_world(pool[(k * stride) % pool.size()]))
    return out
```

**Shared candidate-pool builder** (used by either strategy):

```gdscript
## K7: the band's floor cells eligible to host an exit, in the J3 stable order (depth asc,
## then (y,x)). Excludes the entry-spawn cell and the spawn-offset cell so a gate never lands
## on the player's start or doubles the pinned spawn gate. Deterministic — pure topology.
func _exit_candidate_cells(band: Band, spawn_pos: Vector2) -> Array[Vector2i]:
    var entry_cell: Vector2i = _world_to_cell(spawn_pos)
    var spawn_gate_cell: Vector2i = _world_to_cell(spawn_pos + GameState.GATE_SPAWN_OFFSET)
    var out: Array[Vector2i] = []
    for p in _density_pieces_sorted(band):                  # main_game.gd:422
        for cell in _density_sorted_cells(p):               # main_game.gd:439
            if cell == entry_cell or cell == spawn_gate_cell:
                continue
            out.append(cell)
    return out

func _world_to_cell(world_pos: Vector2) -> Vector2i:
    return Vector2i((world_pos / float(_band_cell_size_px)).floor())   # inverse of _density_cell_to_world
```

### B.5 The fingerprint stays put (sanity)

Nothing above touches the generator or `RNG` autoload during generation. `exit_*` knobs are **not** read in any
fingerprint path; they are read only here, in `_build_and_start_band`'s materialisation step. The all-off branch
(`not rc.exit_enabled`) is the *only* path that runs for the control, and it emits exactly today's single-gate
instruction. So fp stays `e943ac9c8bc1`. A non-neutral `exit_*` config changes *where gates render* (run-state) but
still never moves fp — consistent with the Breakdown §6 carve-out (placement is run-state, like R1 hazards). This is
*stronger* than the R4/J4 carve-out (which allows fp to move for non-neutral configs): K7 never moves fp **at all**.

---

## C. The knob group (aligns with K0's pre-declaration; this is the locked contract)

K0 already pre-declares the `exit_*` group (`K0_foundation_knobs_signals.md:239-249` + the `to_flat_dict()` block
`:292-297`). K7 **reads** these; it does not edit `run_config.gd` (single-writer: K0 owns that file this milestone).
The group as K0 declares it:

| Knob | Type · default | Meaning |
|---|---|---|
| `exit_enabled` | `bool` · `false` | Master toggle. **OFF = today's single fixed gate at `GATE_SPAWN_OFFSET`** (fp unchanged). The rework toggle. |
| `exit_base_count` | `int` · `0` | Exit count at depth 0. Floored to 1 in `_exit_count_for_depth` (never zero exits). |
| `exit_count_per_depth` | `float` · `0.0` | Additive exits per within-band depth (the "changes with depth" lever). |
| `exit_keep_one_at_spawn` | `bool` · `false` | If true, pin ONE gate at the legacy spawn offset; place the rest across the level. |
| `exit_max_count` | `int` · `0` | Hard cap on total exits per band (perf/legibility guard). 0 = uncapped. |

**On the work-order's "configure how often":** "how often" / "frequency" is expressed as **count-per-band scaled by
depth** (`exit_base_count` + `exit_count_per_depth * depth`), not a per-tick spawn rate or a probability — see OQ-4 for
why count is the right reading and what an optional per-band *chance* knob would add. The provisional group has **no
chance knob**; OQ-4 recommends keeping it count-only for M1.4.

**Default preset (`make_default_play_preset()`, OQ-3):** the preset is a separate artifact and may enable exits. The
recommendation (OQ-3) is to ship the preset with **`exit_enabled=false`** (single fixed gate, matching what the M1.3
playtest used) and let the Director sweep exits on in RG1 — so the re-gate cleanly isolates the *other* M1.4 changes
from the exit change. Director call.

**Telemetry:** the five `exit_*` keys join `to_flat_dict()` (K0 §B.2) and the `exits_placed(count, depth)` signal
(K0 §B.3, `event_bus.gd`) fires once per band with the actual count placed — so RG2 can segment cohorts on exit config
and verify counts.

---

## D. Test hooks (for QA / the build agent)

- **All-off identity:** with `RunConfig.new()` (or `run_config.tres`), assert `_place_gate` produces exactly **one**
  gate at `spawn_pos + GATE_SPAWN_OFFSET` (position + `_gates.size() == 1`). This is the determinism control; pairs with
  the existing `fingerprint()==e943ac9c8bc1` assertion (the seam never touches generation, so fp is automatically safe,
  but assert the single-gate position explicitly).
- **Reproducibility (Strategy A):** same `run_seed` + same `exit_*` config → identical gate positions across two builds
  (the local-sub-stream determinism, like the pockets `RANDOM` test).
- **Depth scaling:** hand-built graded bands at depth 0 / depth N → `_exit_count_for_depth` returns
  `base` / `base + floor(per_depth*N)`, clamped by `exit_max_count`, floored at 1.
- **Keep-at-spawn:** `exit_keep_one_at_spawn=true` → one gate is at the exact spawn offset; the rest are elsewhere
  (none on the entry cell).
- **Multi-gate extract safety:** with N gates, focusing+interacting any one ends the run once (`run_ended` fires
  exactly once; `_run_ended` guard holds) — extends the existing extract test.
- **Knob-count bump:** `tests/test_run_config.gd` / `tests/test_config_menu.gd` knob counts include the 5 `exit_*` keys
  (K0 owns this edit; K7 only verifies it passes).

---

## Open Questions

**OQ-1 — Random sub-stream (Strategy A) vs deterministic stride (Strategy B).**
The work-order says *"spawn randomly around the level,"* which literally favours **Strategy A** (local-RNG random
cells). Strategy B (J3 even stride) is *deterministic-spread*, not random — exits land at evenly-strided cells, the same
every run for a given band shape.
- *Strategy A trade-offs:* honours "random" literally; varied, surprising exit layouts run-to-run; needs the
  `EXITS_RNG_SALT` local sub-stream (one new const) but is **fully determinism-safe** (B3/E3 pattern, fp untouched).
  Slightly less even coverage (random can cluster); mitigated by Fisher–Yates over the whole pool.
- *Strategy B trade-offs:* zero new randomness, maximally even spread, reuses J3 verbatim; but it is the *same* layout
  every run for a fixed band → less "random," and a band that regenerates with the same topology would put exits in the
  same spots.
- **Recommendation:** **Strategy A** — it matches the Director's explicit "randomly," and the determinism cost is nil
  (placement is run-state; the local sub-stream is the established pattern). Strategy B is the fallback if "random" turns
  out to read poorly (clustered exits) in playtest. *(Design recommendation — Director may prefer B for predictability;
  not a vision-critical call, but worth a one-line confirm.)*

**OQ-2 — `exit_keep_one_at_spawn` default.**
Today there is always a gate near spawn; players have learned "home is back where I started." Defaulting
`exit_keep_one_at_spawn=true` (when exits are enabled) preserves that anchor and makes random exits *additive* escape
hatches; defaulting `false` makes the player *find* the exit (higher stakes, more exploration, but can feel like the
exit "moved" unfairly).
- *Trade-offs:* `true` = gentler, keeps the known-safe return; `false` = the work-order's "spawn randomly" taken fully
  (no guaranteed home gate). Note the K0 default for this knob is `false`, and the **all-off control already has its own
  fixed gate** regardless (because `exit_enabled=false` short-circuits before this knob is read) — so this knob only
  matters in the *enabled* path.
- **Recommendation:** in the *named preset* set `exit_keep_one_at_spawn=true` initially (keep the familiar home gate;
  random exits are a bonus), and let RG1 sweep it off. The **code-level default stays `false`** (K0) — irrelevant to the
  control. **Needs Director review** (it shapes how "the exit moved" feels — a fun/tone call).

**OQ-3 — Does the default play-preset enable exits at all?**
The M1.3 re-gate that produced the ITERATE verdict was played with the single fixed gate. If the M1.4 preset turns
exits *on*, the re-gate conflates the exit change with K2/K3/K4/K5 changes.
- *Trade-offs:* preset `exit_enabled=true` showcases the feature in the default playtest (Director sees multi-exit
  immediately) but muddies the A/B against M1.3; preset `exit_enabled=false` keeps the re-gate clean and makes exits a
  deliberate sweep cell.
- **Recommendation:** ship the preset **`exit_enabled=false`** (single fixed gate, == M1.3 spatial behaviour) so the
  re-gate isolates exits, and have RG1 include an `exit_enabled=true` sweep cell. **Needs Director review** (it's a
  re-gate-methodology + showcase call). *(If the Director wants exits front-and-centre in the headline playtest, flip
  it on in the preset — trivial.)*

**OQ-4 — How is "how often / frequency" expressed: count, per-band chance, or per-tick rate?**
The work-order says *"configure how often … exits spawn."* Three readings: (a) **count per band** (the provisional
`exit_base_count` + `exit_count_per_depth`); (b) a **per-band probability** that *any* extra exit appears (a Bernoulli
chance knob); (c) a **per-tick/respawn rate** (exits appear/disappear over the run).
- *Trade-offs:* (a) is simplest, deterministic, matches the J2/J3/K5 count-with-depth idiom already in the codebase, and
  is what the K0 group encodes; (b) adds variance ("sometimes 1, sometimes 3 exits") at the cost of a local-RNG roll;
  (c) is a *moving-exit* mechanic (gates spawning mid-run) — a much larger feature touching the run loop, the interact
  detector, and timing.
- **Recommendation:** read "how often" as **(a) count-with-depth** for M1.4 — it satisfies "how often there are exits"
  and "changes with depth" with the existing greybox-config idiom, and `exit_max_count` bounds it. **Explicitly defer
  (b) and (c)**: a per-band chance knob is a cheap future add (one local-RNG roll, OQ-1's sub-stream already present); a
  per-tick respawn rate is out of M1.4 scope (it's a run-loop mechanic, not placement). **Needs Director confirm** that
  "how often" = count-per-band, not a respawn rate.

**OQ-5 — Min-depth gating: should exits only appear past a certain depth?**
The provisional K0 group has **no `exit_min_depth`** (unlike R1's `r1_spread_min_depth`). The work-order didn't ask for
it, but it's a natural lever ("shallow bands keep one fixed gate; multi-exit only kicks in deep").
- *Trade-offs:* adding `exit_min_depth` lets the Director keep early bands legible (one home gate) and only multiply
  exits in deep/dangerous bands — parallel to `r1_spread_min_depth`'s "shallow is safe" arc. But it's a 6th knob, and
  K0 has **already locked the 5-knob `exit_*` group** (the count-test bump is sized for 5). Adding it now means
  re-opening K0's single-writer pass *before* K7 builds.
- **Recommendation:** **omit `exit_min_depth` for M1.4.** The same intent is already reachable: `exit_keep_one_at_spawn`
  + a small `exit_base_count` (1) + a low `exit_count_per_depth` means shallow bands have ~1 exit and deep bands grow
  more — without a dedicated min-depth knob. If playtest wants a hard shallow floor, add it in a later iteration (it's
  one knob + one `clampi`). **Flag to Director** — if min-depth gating is wanted *in M1.4*, K0 must add the 6th knob
  before K7 builds (re-open K0), so this needs an early decision, not a late one.

**OQ-6 — `interactable_id` uniqueness with N gates (technical, low-risk).**
Per A.3, identical-id gates are safe under the *current* A2 contract (focus is by node identity: a gate only acts when
the focused `Interactable` is its own child). The only failure mode is a hypothetical future A2 change that keys focus
by id rather than node. *Trade-offs:* assigning each gate a unique id (`&"gate_0"`, `&"gate_1"`, …) future-proofs
against that at the cost of the `ExtractGate` no longer shipping a fixed `@export interactable_id` (the child
Interactable's authored id would need to be overwritten at spawn — a small wiring change). **Recommendation:** keep the
shared `&"gate"` id (no change to `ExtractGate`) — it is provably safe against the as-built A2 contract and avoids
touching the gate scene. **No Director input needed** (pure technical call); noted only so the build agent doesn't
"fix" a non-bug by introducing per-gate ids.

---

## Summary of recommendations (for Phase-3 fresh-eyes + Director)

- **Placement strategy:** Strategy A (local-sub-stream random, `run_seed ^ EXITS_RNG_SALT`) — matches "randomly,"
  determinism-safe. (OQ-1)
- **Count model:** `maxi(base,1) + floor(per_depth*depth)`, floored at 1, capped by `exit_max_count`. Never zero exits.
  (OQ-4)
- **All-off control:** `exit_enabled=false` short-circuits to today's single fixed gate at `GATE_SPAWN_OFFSET` —
  byte-identical, fp untouched. (A.4, B.2)
- **Preset:** ship `exit_enabled=false` for a clean re-gate; sweep on in RG1. (OQ-3) — *Director review.*
- **Keep-at-spawn:** preset `true` (familiar home gate), code default `false`. (OQ-2) — *Director review.*
- **No `exit_min_depth`** in M1.4 (5-knob group stays locked); reachable via base/per-depth/keep-at-spawn. (OQ-5) —
  *early Director flag if wanted.*
- **Multi-gate safety:** shared `&"gate"` id is safe (focus by node identity; first resolve wins via `_run_ended`); no
  `ExtractGate` change. (A.3, OQ-6)
- **Save/meta:** **none** — exit placement is pure run-state; no schema bump, no migration (unlike K2). The `_gate`→
  `_gates` member and `EXITS_RNG_SALT` const are the only structural additions.

---

## Resolved Decisions (Phase 3)

*Fresh-eyes resolution, 2026-06-21. Resolver did NOT author this design. Verified against the real
`scenes/game/main_game.gd` (`_place_gate` 746-753, `_entry_spawn_position` 735-741, `_clear_band` 759-763),
`systems/game_state.gd` (`GATE_SPAWN_OFFSET:24`, `_run_ended` guard 64-70/180-182, `POCKETS_RNG_SALT` local sub-stream
16/384-391), `entities/gate/extract_gate.gd`, and `design/M1_4_Tasks/K0_foundation_knobs_signals.md` (the locked 5-knob
`exit_*` group, 239-249/292-297). All HARD constraints in the brief were re-derived from the code below.*

### Code-verification of the HARD constraints (all confirmed)

- **All-off fp = `e943ac9c8bc1` cannot move.** Confirmed: `_place_gate` runs at materialisation (`main_game.gd:241-243`,
  step 4 of band build), strictly *after* generation. The fingerprint is computed over seed+config during generation,
  upstream of this seam — exactly as A.4 states. The all-off branch (`not rc.exit_enabled`) emits today's single
  instruction (`spawn_pos + GATE_SPAWN_OFFSET`), so the control is behaviourally byte-identical and fp is structurally
  untouchable from here. **No further guard needed; this is correct by construction.**
- **Multi-gate extract safety.** Confirmed twice over: (1) `extract_and_end_run()` early-returns on `_run_ended`
  (`game_state.gd:180-182`), so first-to-resolve wins; (2) `extract_gate.gd:40-46` filters on `id != interactable_id`
  (line 41) **then** `target.get_parent() != self` (line 45) — the node-identity guard means gate B ignores a request
  focused on gate A's child even with the same `&"gate"` id. The doc's A.3/OQ-6 analysis is accurate. Note the ordering:
  the id check (41) is necessary but not sufficient for multi-gate; the **node-identity check (45) is the actual
  cross-fire guard**, and it is keyed on node identity, not id. So same-id gates are safe. (Flagged below in DR-6.)
- **Local sub-stream pattern.** Confirmed: `POCKETS_RNG_SALT` (16) + the `run_seed ^ salt` Fisher–Yates at 384-391 is
  the exact prior art K7 Strategy A mirrors. `EXITS_RNG_SALT := 0x45584954` is a clean, collision-free new const
  (distinct from `POCKETS 0x50434B54` and `JUNK 0x4A554E4B`).

---

**DR-1 (OQ-1) — Placement strategy: random local sub-stream (Strategy A). RESOLVED — Strategy A.**
Adopt **Strategy A** (local `RandomNumberGenerator` seeded `run_seed ^ EXITS_RNG_SALT`, Fisher–Yates over the stable
candidate pool, take first `n`). Rationale on merit, not just literalism:
1. The Director's work-order says *"spawn **randomly** around the level"* — Strategy A is the literal reading; B is
   deterministic-spread, which is a different feel (same cells every run for a given band shape).
2. The determinism cost is genuinely **nil**: placement is run-state (verified above), and the local sub-stream is the
   established, fp-safe pattern (`POCKETS`/`JUNK`). It cannot move the all-off control's fp because the control never
   takes this branch (`exit_enabled=false` short-circuits).
3. Strategy A is *still fully reproducible* per run (same seed+config → same layout), so telemetry/repro tests are
   unaffected — it is "random" across seeds, deterministic within a seed. This is the best of both.
Strategy B's only real advantage (perfectly even coverage) is a tuning nicety, not a requirement, and Strategy A's
Fisher–Yates over the *whole* graded pool already spreads exits across all pieces. **Keep B documented as the fallback
if playtest shows clustering reads poorly** — but ship A. This is a technical/design-merit call; **no Director review
needed** (the doc over-flagged it — "randomly" is an explicit Director word in the work-order, so A *honours* the
Director rather than overriding them). One small addition to the pseudocode: if `pool.size() < n`, Strategy A returns
`pool.size()` distinct cells (the `mini(n, pool.size())` already in B.4) — correct; do not re-sample to force `n`
(duplicate cells would stack gates).

**DR-2 (OQ-4) — Count + depth-scaling shape. RESOLVED — count-with-depth (reading (a)), exactly as drawn.**
"How often / frequency" is expressed as **per-band count scaled by within-band depth**:
`count = clamp(maxi(exit_base_count, 1) + floor(exit_count_per_depth * depth), 1, exit_max_count_or_inf)`. This is the
right reading on merit:
- It matches the **established J2/J3/K5 count-with-depth idiom** already in the codebase (`*_base_count` +
  `*_count_per_depth`), so RG2 can segment exits on the same axis as hazards.
- It satisfies both halves of the work-order — *"how often"* (count per band) and *"changes with depth"*
  (`exit_count_per_depth`) — with zero new mechanics.
- The **floor at 1 is load-bearing and correct**: a band must always have a reachable exit, or the player is stranded.
  Keep `maxi(..., 1)` after the cap too, so `exit_max_count` can never clamp below 1 (if a misconfig sets
  `exit_max_count` to a value, `mini(raw, exit_max_count)` then `maxi(_, 1)` guarantees ≥1). **Add this final
  `maxi(_, 1)` to `_exit_count_for_depth` (B.3) — the current pseudocode floors before the cap but not after; a
  `exit_max_count` of, say, 0-is-uncapped is fine, but defensively re-floor after the `mini`.** Sub-decisions:
  - `depth` = `band.max_depth` (the band's deepest graded index), per the doc's `_band_max_depth(band)`. Confirmed
    correct: count is *per band*, scaled by how deep the band goes, not per-piece. This matches "changes with depth"
    (deeper bands → more exits).
  - Defer reading (b) per-band Bernoulli *chance* and (c) per-tick respawn rate. (b) is a cheap future add (the
    sub-stream already exists); (c) is a run-loop mechanic out of M1.4 scope. **This deferral is a scope call →
    flagged in DR-7.**

**DR-3 (OQ-2) — `exit_keep_one_at_spawn` default. RESOLVED at code level; preset value is a Director call.**
- **Code-level default = `false`** (matches K0's locked declaration, `K0:247`). Non-negotiable: it must stay `false` so
  a fresh `RunConfig.new()` is the all-off control. But note this knob is **only read on the `exit_enabled=true` path**
  — when `exit_enabled=false`, the control short-circuits to its own fixed gate before this knob is ever read
  (verified: B.2's early-return is above the `exit_keep_one_at_spawn` check). So the code default is *inert* for the
  control regardless; it only shapes the *enabled* feel.
- **Preset value (`make_default_play_preset`) = recommend `true`, but this is a fun/tone call.** With `true`, the
  familiar home gate at `GATE_SPAWN_OFFSET` is always present and random exits are *additive escape hatches* (gentler,
  preserves the learned "home is where I started" anchor). With `false`, the player must *find* the exit (higher stakes,
  but can feel like the exit "moved unfairly"). **NEEDS DIRECTOR REVIEW** — recommendation: ship the preset with
  `exit_keep_one_at_spawn=true` for the first re-gate (keep the anchor; let random exits be a bonus), then sweep it off
  in an RG1 cell to measure the "find the exit" stakes. This pairs with DR-4 (the preset's `exit_enabled` value) — both
  are Director dispositions on the same preset.

**DR-4 (OQ-3) — Does the preset enable exits, or ship off for a clean re-gate baseline? NEEDS DIRECTOR REVIEW.**
Pure methodology + showcase call; resolver recommends but does not decide. The trade-off is real and unchanged from the
author's framing:
- **Preset `exit_enabled=false`** (recommended) → the M1.4 re-gate's default playtest uses the single fixed gate ==
  M1.3 spatial behaviour, so the A/B isolates the exit change from K2/K3/K4/K5. Exits become a deliberate RG1 sweep cell
  (`exit_enabled=true`, depth-scaled). Cleanest experiment.
- **Preset `exit_enabled=true`** → multi-exit is front-and-centre in the headline playtest (Director sees the feature
  immediately), but conflates the exit change with every other M1.4 change in the default cohort.
**Recommendation: `exit_enabled=false` in the preset, with an `exit_enabled=true` sweep cell in RG1.** This keeps the
re-gate methodology consistent with how M1.1→M1.3 isolated each lever. **NEEDS DIRECTOR REVIEW** — if the Director wants
exits showcased in the default build, flipping the preset bool on is trivial and determinism-safe (run-state, fp
untouched). Note: if the Director chooses `exit_enabled=true`, they must also set non-zero `exit_base_count` /
`exit_count_per_depth` and a `exit_max_count` perf cap, and the preset's end-of-function
`assert(c.inert_enabled_oppositions().is_empty())` must still pass — but `exit_*` is **not** an opposition axis and is
not in `inert_enabled_oppositions()` (K0 OQ-2 leaves that predicate as R1–R4 only), so an enabled-exit preset does
**not** trip that assert. Confirmed safe either way.

**DR-5 (OQ-5) — Min-depth gating (`exit_min_depth`). RESOLVED — OMIT for M1.4. Do not re-open K0.**
Decisive on technical merit: **do not add `exit_min_depth` in M1.4.** Three reasons:
1. **K0's single-writer pass is locked at 5 `exit_*` knobs** (`K0:239-249`, count-test bump sized for 5). Adding a 6th
   knob re-opens K0's `run_config.gd` pass *before K7 builds* and forces a re-bump of the `test_config_menu.gd` exact
   count (`46 + N`) and the `expected_keys` array — churn against a foundation pass whose whole purpose is to land once.
2. **The intent is already reachable** with the locked 5 knobs: `exit_keep_one_at_spawn=true` (one home gate at every
   depth) + a small `exit_base_count` (e.g. 1) + a low `exit_count_per_depth` (e.g. 0.5) yields ~1 exit shallow and
   more deep — a smooth depth ramp without a hard floor. The author's recommendation here is sound and I confirm it.
3. The work-order did **not** ask for min-depth gating (unlike R1's explicit `r1_spread_min_depth`); it is a speculative
   parallel, not a requirement.
**The "should it be in M1.4 at all" question is a scope call → folded into DR-7's deferral flag.** But the *technical*
disposition is firm: M1.4 ships the 5-knob group as-is; min-depth is a one-knob + one-`clampi` future add (e.g. M1.5) if
playtest demands a hard shallow floor. **K0 stays locked — no re-open.**

**DR-6 (OQ-6) — Gate-id uniqueness for multiple gates. RESOLVED — keep shared `&"gate"`, no `ExtractGate` change.**
Verified against the real `extract_gate.gd:40-46`: cross-fire is prevented by the **node-identity guard** (line 45,
`target.get_parent() != self`), not by id uniqueness. The id (`&"gate"`) is a *kind* tag; the detector passes the
focused `Interactable` node, and a gate only acts when that node is its own child. So N identical-id gates are provably
safe under the as-built A2 contract: each responds only to its own focus, and whichever resolves first wins via
`_run_ended` (`game_state.gd:180-182`). **Decision: every gate keeps `interactable_id = &"gate"`; do not introduce
per-gate ids (`&"gate_0"` …).** Per-gate ids would force overwriting the gate scene's authored `@export interactable_id`
at spawn (a wiring change to a shared scene) to guard against a *hypothetical* future A2 change that keys focus by id —
not worth it. Pure technical call; **no Director input needed.** One build-agent note to carry into K7's worklog: *do
not "fix" the shared id — it is not a bug; the node-identity guard at extract_gate.gd:45 is the cross-fire defence.* If
A2 is ever refactored to key focus by id, that refactor (not K7) owns adding per-gate ids.

**DR-7 — Scope deferrals (per-band frequency chance, per-tick moving exits, min-depth). NEEDS DIRECTOR REVIEW (scope).**
Three things are *deliberately deferred out of M1.4* and bundled here for one Director scope disposition:
- **(b) per-band Bernoulli chance** knob ("sometimes 1, sometimes 3 exits") — cheap future add (one local-RNG roll; the
  `EXITS_RNG_SALT` sub-stream from DR-1 is already present). Recommend defer.
- **(c) per-tick / mid-run *moving* exits** (gates that spawn/despawn over the run) — a run-loop + interact-detector +
  timing feature, materially larger than placement. Recommend defer (clearly out of M1.4's "placement rework" scope).
- **`exit_min_depth`** (DR-5) — recommend defer to a later iteration.
**Recommendation: M1.4 ships exits as *placement-at-band-build only*, count-with-depth, no chance/respawn/min-depth.**
This fully satisfies the work-order ("spawn randomly around the level / multiple allowed / configure frequency + depth /
keep one at spawn"). **NEEDS DIRECTOR REVIEW** only to confirm the *scope line* — i.e. that "configure how often" means
count-per-band (DR-2), not a per-band chance or a per-tick respawn rate. If the Director reads "how often" as a
*chance*, (b) is a small in-scope add; if as a *respawn rate*, (c) is a new task, not part of K7.

---

### Locked summary (technical decisions firm; Director flags isolated)

| # | Decision | Disposition |
|---|---|---|
| DR-1 | Strategy A — local sub-stream random (`run_seed ^ EXITS_RNG_SALT`), reproducible per run, fp-safe. | **Locked** (honours Director's "randomly"). |
| DR-2 | Count = `clamp(maxi(base,1) + floor(per_depth*depth), 1, max_or_inf)`; re-floor at 1 after the cap. `depth = band.max_depth`. | **Locked.** |
| DR-3 | `exit_keep_one_at_spawn` code default `false` (K0-locked); preset value recommend `true`. | Code **locked**; preset value **NEEDS DIRECTOR REVIEW** (fun/tone). |
| DR-4 | Preset `exit_enabled` — recommend `false` (clean re-gate baseline) + RG1 sweep-on cell. | **NEEDS DIRECTOR REVIEW** (methodology/showcase). |
| DR-5 | Omit `exit_min_depth` for M1.4; do NOT re-open K0; reachable via base/per-depth/keep-at-spawn. | **Locked** (technical); scope-deferral in DR-7. |
| DR-6 | Keep shared `&"gate"` id on every gate; node-identity guard (extract_gate.gd:45) prevents cross-fire. | **Locked** (no Director input). |
| DR-7 | Defer per-band *chance*, per-tick *moving* exits, and min-depth out of M1.4 (placement-at-build only). | **NEEDS DIRECTOR REVIEW** (scope line). |

**Build-readiness:** with DR-1/2/5/6 locked and DR-3(code)/DR-5 not touching K0, the K7 build is unblocked on the
locked 5-knob `exit_*` group. The three Director flags (DR-3 preset value, DR-4 preset enable, DR-7 scope line) are all
**preset/methodology calls that do not change the code K7 writes** — they only set values in `make_default_play_preset()`
and the RG1 sweep plan. So K7 can build the seam against the locked decisions while the Director dispositions the preset
values in parallel; no code rework results from any Director verdict (each flag is a knob value, not a structural
change).
