# R4 — Maze / Navigation Risk (M1.1 opposition spec)

**Milestone:** M1.1 — Greybox Cost Axis · **Workstream:** (b) the four oppositions
**Task id:** R4 · **dependsOn:** R0 (run-config), BUG2 (within-band depth), BUG3 (sealed map)
**Assignees:** `general-purpose` (vision/fog node + generator wiring + lost-proxy tracker) · `environment-artist` (branching layout via existing B2 `branch_chance`, greybox fog/vision look) · `game-director-designer` (this spec + config defaults)
**Status:** spec authored (this doc) — implementation pending wave 2
**Companion docs:** `M1.1_Breakdown.md` §2/§4/§6 · `M1_As_Built.md` (proc-gen + telemetry) · `B2_room_graph_generator.md` · `B3_band_depth_structure.md` · `data/run_config/run_config.gd` (R4 knobs already exist)

> **Scope guardrail (Breakdown §2):** R4 is a **THROWAWAY greybox prototype**, *not* the final maze/nav system. It is **NOT** full WFC, **NOT** cyclic-loop generation, **NOT** a navmesh/A\* lost-detector. It is two small configurable levers bolted onto the existing M1.0 spine, plus a proxy metric, that exist only to test whether *navigation friction* makes "one more room" a real gamble. Every knob ships **configurable, not balanced** — acceptance is "the knob exists and takes effect," not "the value is right." If the re-gate (RG3) says "fun," M2/M3 build the real thing; if not, we cut/swap.

---

## 1. Goal & design intent

**The one sentence:** *Deeper = genuinely harder to find the way back, so "one more room" risks getting stuck and burning the clock (and, when stacked, the R3 exposure meter).*

M1.0 proved the loop is engaging but **degenerate**: with a free, legible walk-back on a linear spine, the optimal play is always "push to the end, then stroll home and extract." R4 attacks that from the **navigation** angle: it makes the deep band *spatially confusing* so that retreating is no longer a free, certain action. The intended felt experience:

- Shallow band reads like M1.0 — one obvious spine, full vision, trivial to retrace.
- As the player pushes deep, the layout **branches and dead-ends**, and/or their **vision tightens / fog hides far geometry**, so the way home stops being obvious. The player must *remember* or *re-discover* the route under a draining clock.
- The risk is **opportunity cost, not instant death**: getting turned around wastes seconds against the 60s dive clock (and, if R3 is stacked, lets the exposure meter climb), which can convert a greedy push into a `timeout` loss or a panicked sub-optimal extract.

R4 is the **subtlest** of the four oppositions (R1 kills you, R2 taxes you, R3 meters you; R4 *confuses* you). Its job in the experiment is to add a **cognitive/time** cost to depth that the other three don't, and to widen the outcome distribution toward "got lost, ran out of clock."

**Design boundary — R4 must never make a run *unwinnable*, only *harder*.** Because the map is sealed (BUG3) and the generator stays connected-and-walkable (B2's flood-fill invariant), a route home always exists; R4 only makes it harder to *find* and *see*, never impossible to *traverse*.

---

## 2. The two levers

R4 ships two independent, independently-toggleable levers. Either can run alone; together they compound. Both scale off **live within-band depth** (BUG2's `current_depth`).

### Lever 1 — Branching layout (generator-side)

Feed a **depth-scaled branch chance** into the existing B2 `branch_chance` so deep areas fork and dead-end while shallow areas stay linear.

- B2 already has the hook: `_select_frontier_index(frontier, cfg)` rolls `RNG.randf() < cfg.branch_chance` to grow from a **random** frontier socket (a fork) instead of the deepest (the spine). M1.0 ships `branch_chance = 0.0` (strictly linear). R4 raises it as a function of depth.
- **Effective chance at a given frontier socket:**
  `branch_chance(depth) = r4_branch_chance_base + r4_branch_per_depth * depth`, evaluated only while the socket's depth is `<= r4_max_branch_depth` (above that cap, force linear so the deepest pieces still chain and the band reaches `target_piece_count`). Clamp the result to `[0, 1]`.
- **What it produces:** at low depth, near-0 chance → spine. At high depth (but `<= r4_max_branch_depth`), a real chance to grow from a *non-deepest* socket → side rooms and dead-ends, so the player can take a wrong turn and the way home is no longer a single straight line. B3's `dist_to_gate` is a **true reverse BFS** (already implemented per B3 spec, not the linear shortcut), so return distance stays correct on branched layouts — R2 and the HUD keep working.
- **Determinism is non-negotiable.** The branch decision must stay a pure function of `seed + config` so `band.fingerprint()` is reproducible (Breakdown §6, B2 acceptance). That means:
  - The roll stays on the **`RNG` autoload, on integer math** — implement the depth-scaled chance as a scaled-integer compare (`RNG.randi_range(0, 9999) < int(round(branch_chance(depth) * 10000))`), **not** a new `randf()` comparison and **not** a second RNG stream. The whole layout pass already runs on `RNG`; R4 only changes the *threshold value* fed into the existing roll, not the roll site or order. (See B2's locked rule: every branch-affecting decision on integer math, `M1_As_Built.md` lines 22–23.)
  - **No reordering.** Do not add, remove, or reorder any `RNG` draw outside the existing `_select_frontier_index` site. The fork roll already happens there once per grow step; R4 only makes its threshold depth-dependent.
  - **Config is part of the determinism key (RATIFIED — §10 Q5).** `fingerprint(seed)` was the M1.0 contract; under R4 the **committed M1.1 determinism contract is `fingerprint(seed + config)`** — the active `RunConfig` IS part of the seed key. Same seed **and** same config → identical band; different config legitimately → different band. This holds for **all** config-dependent branching, not just R4's. The branch roll therefore stays on integer `RNG` (above) precisely so (seed + config) reproducibility is exact. The determinism *test* pins the config: the all-off config must still byte-match the M1.0 band; a new test pins an R4-on config and asserts run-to-run stability (see §10 Q5 for the test + `run_id` obligations).

### Lever 2 — Limited vision / fog (runtime, client-side)

Hide far geometry so the player can't see the whole band at once and must navigate by what's near them.

- A **vision radius** `r4_vision_radius` (px) around the player; geometry beyond it is darkened/hidden. `r4_vision_radius = 0` means **full vision** (no limiting — the M1.0 look).
- **Tightens with depth:** `effective_radius(depth) = max(MIN_RADIUS, r4_vision_radius - r4_vision_tighten_per_depth * depth)`. Deeper = smaller visible bubble. `MIN_RADIUS` is a small floor (e.g. ~1.5 cells = 24px) so the player can always see their immediate surroundings — never blind.
- **Fog-of-war** `r4_fog_enabled`: when on, cells once seen stay dimly revealed (explored-but-not-currently-visible), so the player builds a partial mental map but loses live detail of distant areas. When off, only the live radius is lit (harsher — you forget where you've been).
- **Greybox implementation (environment-artist + programmer) — RATIFIED node approach (§10 Q3):** this is a **purely cosmetic/visibility** layer — it changes *what the player can see*, never the collision or the generated geometry. The committed greybox approach is a **`CanvasModulate` dark overlay + a `PointLight2D` on the player** (radius = `effective_radius`), the cheapest Godot-native vignette that reads as "limited vision." Fog-of-war adds a low-res `revealed` mask (per-cell `Dictionary` of seen cells → a faint always-lit tint). **No fragment shader for M1.1** — a smoother shader-based reveal is deferred to the real M-later vision system.
- **Stacking with R3's vision penalty — RATIFIED multiply-don't-add (§10 Q4):** when R3 is also running a `vision` penalty, R4-vision and R3-vision are **stackable, not mutually exclusive**, and they **compose multiplicatively**: R3's penalty applies as a *fraction* of R4's already-computed `effective_radius` (or of full vision when R4 vision is off), then the result is clamped to the same `MIN_RADIUS` floor. So the final radius is `max(MIN_RADIUS, effective_radius(depth) * r3_vision_fraction)` — the two never sum into near-blindness and never reach zero, and RG2 can interpret stacked runs.

> **Run-state only.** The vision/fog node and the lost-proxy tracker live entirely in **run-state** (disposable per dive). They read config + player position + depth; they write nothing to meta-state, nothing to the save schema, nothing to `game_state.gd`.

---

## 3. Lost-proxy design

"Lost" is a mental state — it can't be measured directly. R4 must emit a **proxy** that the RG2 analysis can read as "this run showed navigation friction." We pick **one trustworthy proxy**, with the threshold `r4_lost_proxy_threshold` deciding when a "lost episode" is logged.

### Candidate proxies considered

| Proxy | What it measures | Pros | Cons |
|---|---|---|---|
| **A. Time-without-depth-progress** | Seconds elapsed since `max_depth_reached` last increased *while the player is moving* | Cheap; directly captures "wandering without getting anywhere"; reads off BUG2's `max_depth_reached` + a movement check; no map structures | Also fires during deliberate looting (player parks deep and grabs junk) — needs a "is moving" gate to avoid false positives |
| **B. Backtracking distance** | Cumulative reversals of net depth direction (depth went up, then down, then up…) within a window | Directly captures "turned around"; depth is already tracked | A retreat to extract is *intentional* backtracking, not lost — hard to distinguish goal-directed retreat from confused wandering |
| **C. Revisited cells** | Count of floor cells entered ≥ N times within a window | Most literally "going in circles"; structure-true | Needs a per-cell visit `Dictionary` keyed off player→cell mapping; the most code; on a small greybox band, normal traversal revisits the spine anyway |

### Ratified decision (§10 Q1) — **Proxy A (time-without-depth-progress), gated on movement**

**Proxy A is the committed lost-proxy for M1.1.** It is the cheapest to implement correctly (it reads BUG2's existing live depth + `max_depth_reached` and a velocity check — no new spatial bookkeeping), it most directly expresses the *fun-relevant* failure ("I'm burning clock and not getting anywhere"), and it ties straight to the metric the gate cares about (clock burned vs. depth gained). Its one weakness — firing while the player deliberately loots a deep room — is removed by **only accumulating the timer while the player is actively moving** (velocity above a small threshold): a player parked on a junk pickup isn't "lost," a player wandering the corridors is.

- **Metric:** `seconds_wandering` — time accumulated while `(player.velocity.length() > MOVE_EPS)` **and** `current_depth` has not increased and `max_depth_reached` has not increased since the timer last reset.
- **Reset:** whenever `max_depth_reached` increases (real forward progress) **or** the player reaches the gate / extracts (goal achieved). A deliberate, *successful* retreat to extract therefore does **not** log as lost (it ends at the gate), but a retreat that gets turned around and stalls **does** (the timer keeps running because no progress is made and the gate isn't reached).
- **Threshold:** when `seconds_wandering >= r4_lost_proxy_threshold`, emit one `nav_lost_proxy` row, then **continue accumulating** but **rate-limit** further emissions (e.g. one per additional `r4_lost_proxy_threshold` seconds) so a single long lost-episode logs as escalating events, not a flood.
- **Why a threshold not a continuous stream:** RG2 wants *episodes* ("how many runs had a lost-episode, how long, at what depth"), not a per-frame trace. The threshold turns the continuous `seconds_wandering` signal into discrete, countable lost-events.

> **Coordinate the exact proxy + payload with TEL** (Breakdown §4/§6): TEL owns the `nav_lost_proxy` signal declaration and the JSONL row. The `metric` field carries the **committed** stable proxy id `&"time_no_depth_progress"` (RATIFIED §10 Q1) so that if a later iteration swaps proxies, the analysis can tell them apart. R4's programmer must confirm with the TEL agent that the payload shape below matches the pre-declared signal before building.

---

## 4. Telemetry

R4 emits two pre-declared `EventBus` signals (TEL declared all opposition signals up-front in wave 1 per Breakdown §6 — **R4 only *emits*, never edits `event_bus.gd`**). Both must match TEL's locked arity; coordinate the exact payload with the TEL agent.

### `nav_branch_taken(depth, junction_degree)`
- **When:** the player *moves through a junction* — i.e. enters a piece that has more than one mated socket (a real fork the player could turn at), at depth ≥ the shallowest branch. Emit **once per junction-entry**, not per frame.
- **`depth`** = `current_depth` (BUG2) at the moment of entry.
- **`junction_degree`** = the number of mated/walkable connections of the piece the player entered (2 = pass-through corridor, ≥3 = a real branch/intersection). This lets RG2 distinguish "passed through a forky deep area" from "stayed on a 2-connection spine."
- **Purpose:** quantifies *how branchy* the path the player actually walked was, per config — the evidence that Lever 1 took effect and that deeper runs encountered more forks.

### `nav_lost_proxy(metric, value, depth)`
- **When:** the lost-proxy threshold is crossed (§3), rate-limited.
- **`metric`** = committed stable proxy id `&"time_no_depth_progress"` (RATIFIED §10 Q1).
- **`value`** = the metric value at emission (e.g. `seconds_wandering`, a float).
- **`depth`** = `current_depth` at emission (where the player got stuck).
- **Purpose:** the headline R4 signal — "did the player get lost, how badly, how deep." RG2 reads lost-episode count + depth distribution per config vs. the all-off M1.0 baseline.

**Both ride new rows; neither widens the locked `run_ended(reason, duration_s, depth_reached)` arity.** A lost run that times out still ends as the existing `run_ended.reason = &"timeout"` (R4 supplies *context* via `nav_lost_proxy`, it does not invent a new end-cause string — getting lost expresses itself through the *clock* failing, not a dedicated cause). With R4 disabled, **neither signal ever fires** (acceptance §9).

---

## 5. Pseudocode

> All three blocks are **greybox prototypes**. Types are illustrative; the programmer writes typed GDScript against the real B2/B3/BUG2 APIs (`M1_As_Built.md`).

### (a) Generator branch hook — depth-scaled `branch_chance` (B2 `_select_frontier_index`)

```gdscript
# In the B2 generator (band_generator.gd), the EXISTING fork site.
# R4 changes ONLY the threshold value, not the roll site, order, or RNG source.
# Determinism contract (RATIFIED §10 Q5): integer compare on the RNG autoload;
# fingerprint is keyed on (seed + config) — same seed + same config => identical
# band.fingerprint(). The integer roll is what keeps (seed + config) exactly
# reproducible.
# grow_depth here = the grow-socket's host PLACEMENT index (RATIFIED §10 Q6),
# NOT the post-placement DepthGrader.depth_index (not assigned yet at grow time).

const _BRANCH_SCALE := 10000  # fixed-point precision for the integer compare

func _select_frontier_index(frontier: Array, cfg: BandGenConfig, rc: RunConfig) -> int:
    # Depth of the candidate grow socket = depth_index of its host piece (BFS hops).
    # On the linear spine this is just "how far out we've grown."
    var grow_depth: int = frontier[frontier.size() - 1].host_depth_index

    var chance := cfg.branch_chance  # M1.0 baseline path (0.0 when R4 off)
    if rc != null and rc.r4_enabled and grow_depth <= rc.r4_max_branch_depth:
        chance = rc.r4_branch_chance_base + rc.r4_branch_per_depth * float(grow_depth)
    chance = clampf(chance, 0.0, 1.0)

    # INTEGER roll on the RNG autoload — never randf(), never a second stream.
    # Same draw site/order as M1.0; only the compared threshold changed.
    var threshold := int(round(chance * _BRANCH_SCALE))
    if RNG.randi_range(0, _BRANCH_SCALE - 1) < threshold:
        return RNG.randi_range(0, frontier.size() - 1)   # FORK: grow a random socket
    return frontier.size() - 1                            # SPINE: grow the deepest

# NOTE: when R4 is off (rc.r4_enabled == false), chance stays cfg.branch_chance (0.0),
# threshold == 0, the integer compare is always false => pure linear spine == M1.0.
# The RNG draw still happens (preserving M1.0's draw sequence), it just never forks.
```

> **Determinism caveat to verify in test (RATIFIED §10 Q5):** the determinism contract is `fingerprint(seed + config)`. The M1.0 fingerprint test must keep passing **with R4 off** (the all-off config must byte-match the M1.0 band for a given seed — the permanent control). With R4 on, a new test pins both seed and config and asserts run-to-run stability. Per §10 Q6 the branch hook uses **placement order** (`band.pieces.size()` / the grow-socket's host placement index) as the generation-time depth proxy — *not* `DepthGrader.depth_index`, which isn't assigned until after placement; on the spine the two are equal, and the first fork evaluates on the correct pre-fork order. Confirm the placement-index seam with the generator owner at build time.

### (b) Vision / fog node (runtime, run-state, cosmetic only)

```gdscript
# vision_fog.gd — a run-state node in the dive scene. Reads config + player pos +
# live depth. Writes NOTHING to meta/save/game_state. Cosmetic visibility only.

extends Node2D   # holds a CanvasModulate (dark) + a PointLight2D on the player

const MIN_RADIUS := 24.0   # ~1.5 cells; never fully blind

var _rc: RunConfig
var _player: Node2D
var _revealed: Dictionary = {}   # Vector2i cell -> true (fog-of-war memory)

func _ready() -> void:
    _rc = GameState.active_run_config
    _player = get_tree().get_first_node_in_group("player")  # G3 player group
    var active := _rc != null and _rc.r4_enabled and _rc.r4_vision_radius > 0.0
    visible = active                     # OFF => no overlay at all (full vision == M1.0)
    set_process(active)

func _process(_dt: float) -> void:
    var depth: int = GameState.current_depth        # BUG2 live depth
    var radius := maxf(MIN_RADIUS,
        _rc.r4_vision_radius - _rc.r4_vision_tighten_per_depth * float(depth))
    # RATIFIED §10 Q4: if R3 is running a vision penalty, MULTIPLY it in as a
    # fraction of the already-computed radius, then re-floor — never add, never
    # reach zero. (r3_vision_fraction == 1.0 when R3-vision is off.)
    radius = maxf(MIN_RADIUS, radius * _r3_vision_fraction())
    _light.position = _player.global_position
    _light.texture_scale = radius / _light.base_texture_radius

    if _rc.r4_fog_enabled:
        _remember_visible_cells(_player.global_position, radius)  # mark seen cells
        _apply_fog_mask()   # seen-but-not-current cells get a faint dim tint
    # When fog off: only the live PointLight2D bubble is lit; explored area goes dark again.
```

> The vision node **must not** alter the generated band, collision, or the proc-gen RNG — it is a pure overlay. It reads `GameState.current_depth` (BUG2) and the player position (via the `"player"` group seam noted in `M1_As_Built.md` line 63). Greybox look-and-feel (overlay color, light texture, fog tint) is the **environment-artist's** call.

### (c) Lost-proxy tracker (run-state)

```gdscript
# lost_proxy.gd — a run-state node. Implements Proxy A (time-without-depth-progress,
# gated on movement). Emits the pre-declared nav_lost_proxy signal; never edits EventBus.

extends Node

const MOVE_EPS := 8.0   # px/s; below this the player is "parked" (looting), not wandering
const PROXY_ID := &"time_no_depth_progress"

var _rc: RunConfig
var _player: Node2D
var _seconds_wandering := 0.0
var _last_max_depth := 0
var _emit_floor := 0.0   # next seconds_wandering value at which we may emit again

func _ready() -> void:
    _rc = GameState.active_run_config
    _player = get_tree().get_first_node_in_group("player")
    var active := _rc != null and _rc.r4_enabled and _rc.r4_lost_proxy_threshold > 0.0
    set_process(active)
    _last_max_depth = GameState.max_depth_reached   # BUG2

func _process(dt: float) -> void:
    var max_d: int = GameState.max_depth_reached
    if max_d > _last_max_depth:            # real forward progress => reset
        _last_max_depth = max_d
        _seconds_wandering = 0.0
        _emit_floor = _rc.r4_lost_proxy_threshold
        return

    if _player.velocity.length() > MOVE_EPS:   # only accumulate while actually moving
        _seconds_wandering += dt
        if _seconds_wandering >= _emit_floor:
            EventBus.nav_lost_proxy.emit(PROXY_ID, _seconds_wandering, GameState.current_depth)
            _emit_floor += _rc.r4_lost_proxy_threshold   # rate-limit escalating emissions

# Reaching the gate / extracting also resets (hook GameState's extract/gate-reached
# path, or listen for the existing gate-focused / extract signal) so a successful
# retreat is never logged as lost.
```

> `nav_branch_taken` is emitted from a small junction-detector (either the dive scene's piece-entry tracking or a tiny `Area2D`-per-piece-entry check) when the player enters a piece whose mated-connection count ≥ 2 — coordinate the exact emit site with the programmer building the dive-scene wiring so it reuses existing piece-entry knowledge rather than adding a second spatial system.

---

## 6. Why BUG3 is required (hard dependency)

R4 **cannot ship fair without BUG3** (sealed map). Both levers assume a bounded play space:

- **Branching layout** intentionally creates dead-ends and side rooms. On the M1.0 geometry, zone pieces leave **open sockets into off-map void** (BUG3's defect), so a dead-end branch could end in an **open socket the player walks straight through into the void** — turning a navigation challenge into a fall-off-the-world bug. A branch is only a fair "wrong turn" if it terminates in a *wall*, not in nothing.
- **Limited vision / fog** is *only* a fair challenge inside a bounded space. With unsealed edges, a player who can't see far might wander off the map entirely in the dark — the friction becomes a softlock/exploit, not a designed risk.
- **The proxy depends on a real route home.** Proxy A assumes the player *can* make progress if they navigate correctly; an unsealed map where they leak into void makes "time without progress" meaningless.

BUG3's acceptance ("no open socket leads off-map; the player cannot walk into void on any seed; B2 `fingerprint()` preserved") is therefore a **precondition** for R4's acceptance. R4 must land on a `main` that already has BUG3 (Breakdown §5 dependency map: `R4 ◄── (R0, BUG2, BUG3)`). Additionally, R4's branching exercises the *deep* parts of the map far harder than M1.0's spine ever did, so R4 is the system that will surface any *remaining* BUG3 gap — flag any unsealed dead-end found during R4 work back to the BUG3 owner.

---

## 7. Config defaults recommendation

The `RunConfig` R4 knobs already exist (`data/run_config/run_config.gd` lines 101–117). The **default `.tres` is all-off = M1.0 baseline** (the permanent in-build control RG2 measures against). R4's job is to recommend (a) the all-off defaults (confirm) and (b) a **first sweep set** the Director can load to start finding where the friction lives. None of these are "balanced" — they are starting points for the Director's sweep.

### All-off default (= M1.0: linear spine + full vision)
| Knob | Value | Meaning |
|---|---|---|
| `r4_enabled` | `false` | R4 inert |
| `r4_branch_chance_base` | `0.0` | no forks |
| `r4_branch_per_depth` | `0.0` | no depth scaling |
| `r4_max_branch_depth` | `0` | no branch budget |
| `r4_vision_radius` | `0.0` | full vision (no fog limiting) |
| `r4_vision_tighten_per_depth` | `0.0` | no tightening |
| `r4_fog_enabled` | `false` | no fog |
| `r4_lost_proxy_threshold` | `0.0` | proxy off |

With all of the above, R4 produces the **identical** M1.0 band for a seed (fingerprint byte-match) and the M1.0 full-vision look, and emits no R4 telemetry.

### First sweep set (starting points for the Director — three preset flavors)

**Preset S1 — "Branchy" (Lever 1 only).** Tests whether layout confusion alone shifts behavior.
| Knob | Value |
|---|---|
| `r4_enabled` | `true` |
| `r4_branch_chance_base` | `0.0` |
| `r4_branch_per_depth` | `0.06` (≈ 6%/depth; at depth 5 ≈ 30% fork chance) |
| `r4_max_branch_depth` | `8` (top of the M1 band; keep deepest pieces linear) |
| `r4_vision_radius` | `0.0` (full vision) |
| `r4_lost_proxy_threshold` | `6.0` (s wandering = a lost-episode) |

**Preset S2 — "Foggy" (Lever 2 only).** Tests whether limited vision alone shifts behavior, on the legible linear spine.
| Knob | Value |
|---|---|
| `r4_enabled` | `true` |
| `r4_branch_chance_base` | `0.0` (linear) |
| `r4_vision_radius` | `160.0` (≈ 10 cells — see the whole nearby room, not the band) |
| `r4_vision_tighten_per_depth` | `12.0` (≈ 0.75 cell/depth tighter; floors at MIN_RADIUS deep) |
| `r4_fog_enabled` | `true` (keep a faint explored memory) |
| `r4_lost_proxy_threshold` | `6.0` |

**Preset S3 — "Maze" (both levers, the intended full R4).**
| Knob | Value |
|---|---|
| `r4_enabled` | `true` |
| `r4_branch_chance_base` | `0.0` |
| `r4_branch_per_depth` | `0.05` |
| `r4_max_branch_depth` | `8` |
| `r4_vision_radius` | `192.0` |
| `r4_vision_tighten_per_depth` | `10.0` |
| `r4_fog_enabled` | `false` (harsher — forget where you've been; pairs with branches for max confusion) |
| `r4_lost_proxy_threshold` | `5.0` |

> These sweep presets are a **recommendation for the Director**, who tunes per playtest run via the CFG menu. The first thing to learn from S1 vs S2 is *which lever does the work* (layout vs. vision) before stacking them in S3.

---

## 8. Files to create / touch

**Create (new, run-state / generator-side):**
- `entities/dive/vision_fog.gd` (+ a small `.tscn` holding the `CanvasModulate` + player `PointLight2D`) — Lever 2 node. *(programmer + environment-artist for the greybox look)*
- `entities/dive/lost_proxy.gd` — Proxy A tracker (§5c). *(programmer)*
- `data/run_config/presets/` (optional) — S1/S2/S3 preset `.tres` for quick Director loading, if CFG supports preset loading. *(game-director-designer; nice-to-have, not required for acceptance)*

**Touch (existing generator + dive-scene wiring):**
- The B2 generator (`systems/proc_gen/…/band_generator.gd` or equivalent) — the `_select_frontier_index` depth-scaled threshold (§5a), reading `GameState.active_run_config`. *(environment-artist owns branching layout authoring; programmer wires the config read)*
- The dive-scene assembly (`scenes/game/…` / dive root) — instantiate the vision/fog + lost-proxy nodes, and the junction-entry emit for `nav_branch_taken`. *(programmer)*
- `BandGenConfig`/generator call site — thread the active `RunConfig` (or just the R4 sub-fields) into the generation call so the branch hook can read it. *(programmer)*

**Confirm NOT touched (collision-avoidance, Breakdown §6):**
- **`systems/event_bus.gd` — NOT edited.** TEL pre-declared `nav_branch_taken` and `nav_lost_proxy` in wave 1; R4 only *emits* them.
- **`systems/game_state.gd` — NOT edited.** R4 *reads* `GameState.active_run_config` (R0), `GameState.current_depth` / `GameState.max_depth_reached` (BUG2), and routes any run-end through the existing `fail_run`/clock-`timeout` paths. It adds no run-state field to `game_state.gd`; the vision and lost-proxy state live on their own run-state nodes. **If implementation discovers it *must* touch `game_state.gd`, pull R4 out of the parallel wave-2 set and sequence it — flag at brief time (Breakdown §6).**
- The B2 `fingerprint()` algorithm, the depth model (B3), and the telemetry envelope/schema — unchanged.

---

## 9. Acceptance criteria

Restated from `M1.1_Breakdown.md` §4 (R4 entry), made concrete:

1. **Branching takes effect.** With R4 on and a non-zero branch curve, deep areas of a generated band fork and dead-end (more junctions deeper); with R4 off (or zero curve), the layout is the **linear M1.0 spine**.
2. **Vision/fog takes effect.** With R4 on and `r4_vision_radius > 0`, far geometry is hidden and the visible radius tightens with depth per config (and fog-of-war behaves per `r4_fog_enabled`); with R4 off (or `r4_vision_radius == 0`), **full M1.0 vision**.
3. **Lost-proxy logs.** With R4 on, the chosen lost-proxy (`nav_lost_proxy`) logs when its threshold is crossed; `nav_branch_taken` logs as the player passes junctions. With R4 off, **neither fires**.
4. **Sealed + deterministic (RATIFIED contract — §10 Q5).** The band stays **sealed** (BUG3: no walk-off-void on any seed) and **deterministic** under the committed **`fingerprint(seed + config)`** contract — `band.fingerprint()` is identical for a given **seed + config** and may legitimately differ across configs; branch rolls stay on integer `RNG`; the **all-off config byte-matches the M1.0 band** for a seed (permanent control).
5. **All-off == M1.0.** With R4 off, the loop behaves identically to M1.0 (linear spine, full vision, no R4 telemetry) — the permanent control.
6. **Knobs take effect from the menu.** Every R4 knob set in the CFG menu is reflected in the started run (configurable-not-balanced standard).
7. **No locked-contract widening.** `run_ended` arity is unchanged; `event_bus.gd` and `game_state.gd` are not edited by R4.

---

## 10. Resolved Decisions (Director-ratified 2026-06-19 — apply-all-recommendations)

> The Director ruled on 2026-06-19 to **adopt every recommendation in this section as a ratified decision**. The questions below are now committed design, propagated into the body of this spec (§2, §3, §5). Each entry records the decision and a one-line rationale.

**Q1 — Which lost-proxy is most trustworthy?**
**Decision: Proxy A (time-without-depth-progress, movement-gated)** is the committed lost-proxy for M1.1, emitted with stable id `&"time_no_depth_progress"`.
*Rationale:* cheapest to implement correctly (reads BUG2's live depth + a velocity gate, no new spatial bookkeeping) and the most directly relevant to the gate's clock-vs-depth question; the `metric` id keeps it swappable if RG2 later shows false positives.

**Q2 — Does branching risk *unfair* dead-ends (no junk, no payoff)?**
**Decision: accept empty dead-ends as honest risk for M1.1** — no guaranteed-junk post-pass; "not every corridor pays" is part of the gamble.
*Rationale:* it's a throwaway greybox; "some pushes don't pay" is the very tension R4 is testing — revisit only if RG2 shows dead-ends feel cheap.

**Q3 — Fog as shader vs. node?**
**Decision: node approach** — a `CanvasModulate` dark overlay + a player `PointLight2D` (radius = `effective_radius`), with fog-of-war as a low-res `revealed` cell mask. No fragment shader for M1.1.
*Rationale:* Godot-native, zero shader authoring, cheapest for throwaway code; a smoother shader-based reveal is deferred to the real M-later vision system.

**Q4 — How does fog interact with R3's vision penalty when stacked?**
**Decision: multiply, don't add** — R3's vision penalty applies as a *fraction* of R4's already-computed `effective_radius` (or of full vision when R4 vision is off), clamped to the same `MIN_RADIUS` floor, so stacked vision penalties compose predictably and never reach zero. R3-vision and R4-vision are **stackable, not mutually exclusive**.
*Rationale:* multiplicative composition is monotonic and floor-safe, so RG2 can interpret stacked runs without one penalty silently dominating or the player going fully blind.

**Q5 — Config is part of the determinism / seed key (the determinism contract). [CROSS-CUTTING]**
**Decision: the active `RunConfig` IS part of the determinism / seed key.** The M1.1 determinism contract is **`fingerprint(seed + config)`**: same seed **and** same config → identical band; different config legitimately → different band. This is the canonical contract for *all* config-dependent branching in M1.1, not just R4.
*Rationale:* config is part of the experiment's identity, so reproducibility must be keyed on (seed + config); branch rolls stay on integer `RNG` so this remains exactly reproducible.
- **Test obligation:** the existing M1.0 fingerprint test runs with the **all-off** config and must still byte-match the M1.0 band for a seed (all-off control preserved); a **new** test pins an R4-on config and asserts run-to-run stability for (seed + config).
- **`run_id` / TEL:** because `run_id` is currently `r_<hex(seed)>` (`M1_As_Built.md` line 69), two runs with the **same seed but different config** collide on `run_id`. **Ratified resolution:** fold a short config-hash into the run key so (seed + config) runs are distinguishable — flagged to the TEL agent as the owner of `run_id`; until TEL lands it, RG2 disambiguates via the `run_config` snapshot already carried on `run_started`.

**Q6 — Is `depth_index` available at generation time for the branch hook?**
**Decision: use placement order as the generation-time depth proxy** — the branch hook reads the grow-socket's host placement index (`band.pieces.size()` on the spine) as `grow_depth`, not the post-placement `DepthGrader.depth_index`.
*Rationale:* the M1 order is place → grade, so `depth_index` isn't assigned during growth; on the spine placement order == `depth_index`, and the first fork evaluates its chance on the correct pre-fork order. Confirm with the generator owner at build time; the two-pass (grow → grade → branch) fallback is available but costs more determinism surface, so it is not the chosen path.

---

*Authored by `game-director-designer` as the first step of R4 (Breakdown §4: "Each opposition's internal spec becomes its own task artifact, authored by game-director-designer as the first step of that task"). This doc sets the R4 contract; the programmer + environment-artist build against it. Update alongside `M1_As_Built.md` as R4 resolves.*

---

**Changelog**

- **2026-06-19 — Director ratification (apply-all-recommendations):** §10 renamed to "Resolved Decisions (Director-ratified 2026-06-19 — apply-all-recommendations)"; every open question converted from a recommendation to a committed decision (Q1 Proxy A; Q2 accept empty dead-ends; Q3 node-based fog, no shader; Q4 multiply-don't-add R3/R4 vision stacking; Q5 `fingerprint(seed + config)` is the M1.1 determinism contract; Q6 placement-order gen-time depth). Decisions propagated into §2 (Lever 1 determinism key, Lever 2 fog approach + R3 stacking), §3 (Proxy A committed + metric id), §4 (committed metric id), §5 (gen-time depth proxy + R3 compose in pseudocode), §9 (acceptance criterion 4 restated to the (seed + config) contract). Branch rolls remain on integer `RNG` per the contract.
