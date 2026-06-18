# M1 — Human-Ratified Design Decisions

Decisions made by the human Director on **2026-06-15**, resolving the open design questions
across the M1 task specs. Dispatched agents MUST build to these (they override the per-spec
"Open questions" recommendations where they differ). Cross-ref: each task spec's Open questions.

| # | Decision | Resolution | Affects |
|---|---|---|---|
| 1 | `Item` vs `JunkItem` schema | **Keep `JunkItem`; merge `Item` into it.** `JunkItem` is canonical. Fold `Item`'s useful fields (`description`, `origin_band`) into `JunkItem`, retire `data/item.gd`, migrate/remove `data/items/sample_junk.tres`. | new schema task, C1 data |
| 2 | Dive budget `max_light` | **60s for now** (playtest dial at G4). | A3 (already shipped) |
| 3 | Reward curve shape | **Per rec:** gently-rising near-linear value (≈×1.0→×1.8 over the band) as the default value-axis shape; tier unlocks stepped. Curves are authored `.tres`, retune by feel. | B3 |
| 4 | **Which axes rise with depth** | **All three axes (value, density, tier) are per-axis customizable knobs.** Each has a signed *strength* so an axis can **rise (positive, the default)**, be **flat (0)**, or **decrease (negative)**. Default: all three rise. Implement so a designer can dial each axis independently to 0 / negative / positive without code changes. | B3 (+ C2 reads depth) |
| 5 | Extract: instant vs hold/confirm | **Per rec:** instant on one `interact` press + a 200–300 ms fat-finger input lockout. No confirm dialog. | E1 |
| 6 | Bank items vs Money at gate | **Bank item identities** into meta `banked_junk: Array[JunkItem]`. Defer Money conversion to F2's sell screen (E1 must NOT call F1's credit path). | E1, F1, F2 |
| 7 | Allow zero-haul extract | **Per rec:** allow it; fire the extract run-end with value 0. Bailing out alive is a valid choice. | E1 |
| 8 | Gate placement | **Per rec:** one gate, fixed hand-authored location near (not on) spawn, kept as one tunable constant. No seeded placement in M1. | E1, E2 |
| 9 | Value readout in inventory | **Per rec:** `$value` always-on primary; `$/slot` secondary (on hover/focus). | D2 |
| 10 | Inventory: persistent vs toggled | **Per rec:** persistent compact corner HUD panel (always-on capacity read). | D2 |
| 11 | Drop-to-swap in M1 | **Per rec:** ship it. Deliberate gesture (right-click / hold) → `RunInventory.remove` → C2 re-instantiates the dropped `JunkPickup` at the player. | D1, D2, C2 |
| 12 | Depth/danger spawn gradient in C2 | **Per rec:** C2 uses a flat per-anchor spawn roll; B3's depth curve is the sole depth signal. | C2, B3 |
| 13 | Death/timeout pockets model *(ratified 2026-06-18, wave-4 close-out)* | **Whole-item pockets, fraction `0.20`.** On death/timeout, keep **whole items** up to `floor(total_haul_value × 0.20)` (policy `highest_value`) and bank those *item identities* into `banked_junk` — the SAME run→meta transfer as extract, just a subset (extract and fail converge; F2 itemizes "what you barely saved"). Replaces the prior `0.15` *value-fraction credited straight to Money*. Fraction + policy are data-driven in `data/economy/run_rules.tres` for the G4 sweep (0.15–0.25). **Supersedes the old GDD §6 0.15/value-fraction reading.** | E3, F2, GDD §6 |

## Consequences for the build

- **New schema task (do before B3):** merge `Item` → `JunkItem` (#1) **and** add a `tier: int` field to
  `JunkItem` (required by B3's tier-threshold unlocks, currently absent) + author `tier` (and
  `origin_band`/`description` where sensible) on the 8 junk `.tres`. One `game-director-designer` task.
- **B3 (#3, #4):** `DepthCurve` resource exposes the three axes — value, density, tier — each as an
  authored `Curve` **plus a signed `strength` scalar** (`effect = strength * curve.sample(depth_norm)`,
  applied as `base * (1 + effect)` for value/density and a stepped threshold for tier). Default all
  strengths positive (rising); `0` = flat, negative = decreasing. Document the knobs.
- **E1 (#6):** banks `JunkItem` identities into a new meta-state `banked_junk`; reuses the existing
  `run_ended`/`haul_banked` lifecycle signals (no parallel `run_end` signal) — see E1 brief.
- **Drop-to-swap (#11)** spans D1/D2/C2: `RunInventory.remove` (D1 ✅ has `remove_at`/`remove`),
  D2's drop gesture, and a C2 `spawn_one(item, pos, container)` re-instantiation entry point.
