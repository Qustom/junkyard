# E2 — Push / Cash-Out Decision Surface

**Summary:** Make the push-vs-extract choice **explicit and felt**. Near the gate, surface what the player is holding (haul value), against the cost of pushing deeper (clock pressure from A3, distance/depth from B3). This is literally what the M1 feedback gate measures, so the investment goes into making the decision *legible* and *tense* inside a ~30-second window.

- **Parent task:** E2 (M1 greybox prototype — the decision surface; the "is it fun" gate)
- **Dependencies:** E1 (gate + extract action), B3 (depth/distance), D2 (inventory UI), A3 (run clock).
- **Acceptance criterion:** Near the gate the player can clearly weigh "extract now with X" vs "push for more" within a ~30s window — the held value, the time remaining, and the depth/distance cost are all readable at the moment of decision.

## Assets needed

This task is mostly **UI composition + signal plumbing**; it builds little new logic, it *frames* E1/A3/B3/D2.

Scenes & nodes (feature-first layout under `/ui/hud/`):
- `ui/hud/decision_hud.tscn` — a `CanvasLayer` (or `Control` root) named `DecisionHUD`, holding the always-visible decision elements:
  - `HaulValueLabel` (`Label`) — current run haul value in Money terms ("Holding: 240"). Reads the sum of `run_inventory` item `base_sell_value` (D1).
  - `ClockReadout` (`Label` + a `ProgressBar`/`TextureProgressBar` ring) — time remaining from A3. Color-shifts toward red as it drains; this is the *cost-of-pushing* made visceral.
  - `DepthReadout` (`Label`) — current depth/distance from B3 ("Depth 2"). Optional small breadcrumb of distance-back-to-gate.
  - `InventoryPanel` — embed or anchor D2's inventory grid so fullness ("you can't carry more anyway") feeds the decision.
- `ui/hud/extract_prompt.tscn` — a small `Control` named `ExtractPrompt` that appears only when the gate is the selected interactable (driven by A2 selection / proximity):
  - `PromptLabel` ("Press E to Extract with 240") — pulls the gate's `interaction_prompt` (E1) and the live haul value.
  - Optional `PushHint` ("...or push deeper for more") to name the alternative explicitly. The whole point is making *both* options present at the decision moment.

Greybox / juice (cheap, high-leverage for "felt"):
- Clock urgency: ProgressBar tint lerp green→amber→red; AudioDirector tick/heartbeat cue under a threshold (defer audio if A-series not ready).
- Near-gate emphasis: when in gate range, briefly pulse the `HaulValueLabel` so "this is what you'd walk away with" lands.

Settings / layout:
- HUD anchored to screen corners (haul + clock top, depth opposite, inventory bottom). Keep it greybox: plain Labels, default theme, no art pass.

## Code to generate

Scripts:
- `ui/hud/decision_hud.gd` (`class_name DecisionHUD extends CanvasLayer`) — subscribes to `EventBus` / polls `GameState` to keep readouts live.
- `ui/hud/extract_prompt.gd` (`class_name ExtractPrompt extends Control`) — shows/hides on gate proximity, displays live haul value.

Design notes: E2 owns **no source of truth** — it reflects A3 (clock), B3 (depth), D1 (haul value), E1 (gate selection). Prefer `EventBus` signals for change events (inventory changed, depth changed, gate entered/left) and fall back to per-frame polling only for the smoothly-draining clock. The "decision is legible in ~30s" acceptance is a *readability* claim: the three quantities (have / time-cost / distance-cost) must be simultaneously on screen and updating when the player stands at the gate.

Recommend these `EventBus` signals (declare where they naturally belong; E2 only consumes):
- `inventory_changed(run_value: int, count: int)` — emitted by D1 on add/remove.
- `depth_changed(depth: int)` — emitted by B3.
- `gate_in_range(gate: Node)` / `gate_out_of_range(gate: Node)` — emitted by A2 selection or the gate's Area2D body_entered/exited.
- (Clock is read directly from A3 / `GameState` each frame for smoothness.)

```gdscript
# ui/hud/decision_hud.gd
class_name DecisionHUD
extends CanvasLayer

@onready var haul_value_label: Label = %HaulValueLabel
@onready var clock_bar: TextureProgressBar = %ClockBar
@onready var clock_label: Label = %ClockReadout
@onready var depth_label: Label = %DepthReadout

func _ready() -> void:
    EventBus.inventory_changed.connect(_on_inventory_changed)
    EventBus.depth_changed.connect(_on_depth_changed)
    _refresh_static()  # initial paint

func _process(_delta: float) -> void:
    # Clock drains smoothly -> poll A3 each frame.
    var remaining: float = GameState.clock_remaining   # seconds (A3)
    var total: float = GameState.clock_total
    clock_bar.value = (remaining / total) * 100.0 if total > 0.0 else 0.0
    clock_label.text = "%0.0fs" % remaining
    clock_bar.tint_progress = _urgency_color(remaining / total)

func _on_inventory_changed(run_value: int, _count: int) -> void:
    haul_value_label.text = "Holding: %d" % run_value

func _on_depth_changed(depth: int) -> void:
    depth_label.text = "Depth %d" % depth

func _urgency_color(frac: float) -> Color:
    # 1.0 -> green, ~0.5 -> amber, 0.0 -> red
    if frac > 0.5:
        return Color.GREEN.lerp(Color.YELLOW, (1.0 - frac) * 2.0)
    return Color.YELLOW.lerp(Color.RED, (0.5 - frac) * 2.0)

func _refresh_static() -> void:
    _on_inventory_changed(GameState.run_haul_value(), GameState.run_inventory.size())
    _on_depth_changed(GameState.run_depth)
```

```gdscript
# ui/hud/extract_prompt.gd
class_name ExtractPrompt
extends Control

var _gate: Node = null

func _ready() -> void:
    visible = false
    EventBus.gate_in_range.connect(_on_gate_in_range)
    EventBus.gate_out_of_range.connect(_on_gate_out_of_range)

func _on_gate_in_range(gate: Node) -> void:
    _gate = gate
    visible = true

func _on_gate_out_of_range(_gate: Node) -> void:
    _gate = null
    visible = false

func _process(_delta: float) -> void:
    if not visible:
        return
    # Make the trade explicit at the decision moment.
    %PromptLabel.text = "Press E to Extract with %d" % GameState.run_haul_value()
    %PushHint.text = "...or push deeper (%0.0fs left)" % GameState.clock_remaining
```

Small helper on `GameState` (run-state side, shared with E1's value sum):

```gdscript
# systems/game_state.gd (partial)
func run_haul_value() -> int:
    var total: int = 0
    for item in run_inventory:
        total += item.base_sell_value
    return total
```

## Open questions

- **Does the prompt show value always, or only at the gate?** Always-on haul value teaches the player what they'd lose on death (feeds E3 weight); gate-only keeps the HUD clean. Recommend always-on haul + gate-only the explicit "press to extract" prompt.
  - **Recommendation:** Always-on haul value in the HUD corner; the explicit "Press E to Extract with N" prompt shows only when the gate is the selected interactable. The constantly-visible number is what makes the E3 downside *felt while you keep diving* — you watch your at-risk total climb in real time, which is the core of the push-your-luck pressure. The gate-only prompt then converts that ambient awareness into the actionable choice at the decision moment.
- **How aggressively do we juice the clock?** Heartbeat audio, screen-edge vignette, slow-mo near zero — these strongly affect whether the 30s feels "tense" vs "stressful/annoying." This is a playtest-tuning question central to the gate; ship minimal, dial up.
  - **Recommendation:** Ship the minimal-but-sufficient set first: green→amber→red bar tint plus a single urgency threshold (e.g. last ~25% of the clock) that adds a soft pulse on the haul value and an audio tick if audio is wired. Hold back vignette/slow-mo/heartbeat as dial-up knobs gated behind playtest feedback — over-juicing reads as "stressful/annoying" and would bias the kill/pivot read toward "not fun" for the wrong reason. Make the urgency threshold a single tunable so it can be tightened build-to-build.
- **What number does "value" show in M1?** Raw summed `base_sell_value` (== future Money) is simplest and honest. Confirm we surface a *single legible number*, not a per-item breakdown, at the decision moment (itemization belongs to F2's sell screen).
  - **Recommendation:** Surface a single summed `base_sell_value` integer ("Holding: 240") at the decision moment — no per-item breakdown in the HUD. The decision is a one-axis "is this number worth more risk?" judgment, and a single legible figure makes the trade instant; itemization is a reward-screen concern (F2), not a decision-surface one. This number is the same quantity that becomes Money, so it stays honest with no conversion needed.
- **Is depth or distance-to-gate the better "cost of pushing" signal?** Depth is abstract; literal distance-back-to-gate is more visceral ("you're 3 rooms deep, clock's at 12s"). B3 decides which it exposes; E2 should display whichever reads faster.
  - **Recommendation:** Display **distance-back-to-gate** as the primary cost signal (with depth as an optional secondary label), because the felt cost of pushing is "can I still make it back before the clock?" — a spatial/time intuition the player can act on, not an abstract depth number. Request that B3 expose a live distance-to-gate value; if B3 only ships depth in M1, fall back to depth but pair it with the clock so the trade still reads. The visceral framing is what makes the downside land in the ~30s window.
- **30s window — enforced or emergent?** Is the ~30s a literal A3 clock length, or just the typical time a player lingers near the gate deciding? If the clock is much longer than 30s, the "decision in 30s" framing needs the prompt/urgency cues to manufacture the moment.
  - **Recommendation:** Make ~30s a **literal A3 run-clock length** for M1, not an emergent lingering time. A short hard clock is the cleanest way to force the push-vs-extract decision repeatedly per session (M1 is loop-heavy testing), and a fixed length keeps playtest runs comparable. Tune the exact value (start at 30s) as a single A3 constant; the urgency cues then sharpen the final moment rather than having to manufacture a window out of a too-long clock.
- **Controller readability.** Prompt button glyph must reflect the active input device (keyboard "E" vs face button). Defer glyph-swapping to post-M1 or hardcode for the playtest cohort?
  - **Recommendation:** Hardcode the keyboard "E" prompt for the M1 playtest cohort and **defer** dynamic device-aware glyph-swapping to post-M1. Glyph-swapping is pure polish that doesn't affect whether the core tension is fun (the M1 question), and a controller-prompt system is non-trivial to do well. If the cohort is known to use controllers, hardcode the matching face-button glyph instead — just don't build the runtime detection now.
