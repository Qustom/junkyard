# G2 — Determinism & Logic Tests (GdUnit4)

**Summary:** Add GdUnit4 unit/integration tests for the pure-logic M1 systems — proc-gen determinism, inventory capacity, banking math, and death-drop pocket math — and wire them into a headless CI smoke run.

- **Parent task:** G2 (M1 breakdown)
- **Dependencies:** B2 (proc-gen layout), D1 (inventory), E1 (run lifecycle), E3 (banking/economy), F1 (death + drop)
- **Acceptance criterion:** Tests pass in CI headless; determinism plus economy/inventory math are covered.

---

## Assets needed

GdUnit4 is the standardized test runner (CI support, scene/integration). Feature-first `/tests` mirrors `/systems`.

- GdUnit4 addon installed at `/addons/gdUnit4/` (commit the addon or vendor via the asset library; CI needs it present without an editor step).
- Test suites under `/tests`:
  - `/tests/procgen/test_layout_determinism.gd`
  - `/tests/inventory/test_inventory_capacity.gd`
  - `/tests/economy/test_banking_math.gd`
  - `/tests/economy/test_death_drop_pockets.gd`
  - `/tests/telemetry/test_jsonl_writer.gd` (light coverage of G1's writer seam — parseable rows, field presence)
- `/tests/helpers/test_seeds.gd` — shared const list of canonical seeds and a helper to build a fresh `RNG` instance from a seed without touching the global autoload.
- CI workflow: `.github/workflows/ci.yml` — a `test` job that downloads a pinned Godot 4.6.x headless binary, runs the GdUnit4 CLI runner over `/tests`, and fails the build on any failed/aborted test. A separate `smoke` step does a headless project open to catch load/parse errors.
- `.gdunit4_ci` / runner config: a small config (or inline CLI args) selecting the `/tests` path, report format (JUnit XML for GitHub annotations), and a global timeout.
- Determinism fixtures: golden hashes are computed in-test (not stored as files) for M1, so there is no fixture asset to maintain yet — see open questions.

**Design note for testability:** these tests assume the logic systems accept an injected seed/`RNG` and return plain data structures (layout descriptor, inventory result, banking result). If B2/D1/E3/F1 currently read the global `RNG`/`GameState` autoloads directly, expose a pure function or a constructor that takes the seed so tests stay deterministic and autoload-free.

---

## Code to generate

**Test classes / what each asserts:**

- `test_layout_determinism` — same seed produces byte-identical layout; different seeds differ; layout generation has no hidden dependence on wall-clock or call order.
- `test_inventory_capacity` — add up to capacity succeeds; the over-capacity item is rejected (or partially accepted per the rule); current value/weight totals are correct.
- `test_banking_math` — banking the haul moves the full carried value to the bank and zeroes the carry; sell conversion (junk value -> currency) matches the rate; no rounding drift.
- `test_death_drop_pockets` — on death the player keeps the "pockets" fraction and loses the rest; edge cases at 0 carry and 1 item.
- `test_jsonl_writer` — written lines round-trip through `JSON.parse` and contain the required envelope fields.

**GdUnit4-style pseudocode:**

```gdscript
# /tests/procgen/test_layout_determinism.gd
extends GdUnitTestSuite

const LayoutGen = preload("res://systems/procgen/layout_gen.gd")
const Seeds = preload("res://tests/helpers/test_seeds.gd")

func test_same_seed_same_layout() -> void:
    var a := LayoutGen.generate(Seeds.CANONICAL, 3)   # seed, band_depth
    var b := LayoutGen.generate(Seeds.CANONICAL, 3)
    assert_str(a.fingerprint()).is_equal(b.fingerprint())
    assert_array(a.tiles).is_equal(b.tiles)

func test_different_seed_differs() -> void:
    var a := LayoutGen.generate(Seeds.CANONICAL, 3)
    var b := LayoutGen.generate(Seeds.CANONICAL + 1, 3)
    assert_str(a.fingerprint()).is_not_equal(b.fingerprint())

func test_repeated_generation_is_stable_across_calls() -> void:
    # guards against hidden global-RNG bleed / call-order dependence
    var first := LayoutGen.generate(Seeds.CANONICAL, 5).fingerprint()
    LayoutGen.generate(Seeds.CANONICAL + 99, 2)        # unrelated call in between
    var again := LayoutGen.generate(Seeds.CANONICAL, 5).fingerprint()
    assert_str(first).is_equal(again)
```

```gdscript
# /tests/inventory/test_inventory_capacity.gd
extends GdUnitTestSuite

const Inventory = preload("res://systems/inventory/inventory.gd")

func test_add_within_capacity() -> void:
    var inv := Inventory.new(3)                 # capacity = 3 slots
    assert_bool(inv.try_add({"id":"coil","value":12})).is_true()
    assert_int(inv.count()).is_equal(1)
    assert_int(inv.total_value()).is_equal(12)

func test_reject_over_capacity() -> void:
    var inv := Inventory.new(2)
    inv.try_add({"id":"a","value":5})
    inv.try_add({"id":"b","value":5})
    assert_bool(inv.try_add({"id":"c","value":5})).is_false()
    assert_int(inv.count()).is_equal(2)
    assert_int(inv.total_value()).is_equal(10)
```

```gdscript
# /tests/economy/test_banking_math.gd
extends GdUnitTestSuite

const Economy = preload("res://systems/economy/economy.gd")

func test_bank_moves_full_carry() -> void:
    var carry := 137
    var result := Economy.bank(carry, 0)        # carried, existing_bank
    assert_int(result.banked).is_equal(137)
    assert_int(result.remaining_carry).is_equal(0)
    assert_int(result.bank_total).is_equal(137)

func test_sell_conversion_no_drift() -> void:
    # 1 junk value -> CURRENCY_RATE currency, integer math
    var cur := Economy.sell(100)
    assert_int(cur).is_equal(100 * Economy.CURRENCY_RATE)
```

```gdscript
# /tests/economy/test_death_drop_pockets.gd
extends GdUnitTestSuite

const DeathDrop = preload("res://systems/economy/death_drop.gd")

func test_pockets_kept_rest_lost() -> void:
    # pockets fraction kept on death (e.g. 0.0 in M1 = keep nothing)
    var r := DeathDrop.resolve(80)              # carried value
    assert_int(r.kept + r.lost).is_equal(80)    # conservation
    assert_int(r.kept).is_equal(int(80 * DeathDrop.POCKET_FRACTION))

func test_zero_carry_is_safe() -> void:
    var r := DeathDrop.resolve(0)
    assert_int(r.kept).is_equal(0)
    assert_int(r.lost).is_equal(0)
```

**CI smoke + test job (YAML-ish sketch):**

```yaml
# .github/workflows/ci.yml  (test + smoke jobs)
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Cache Godot
        uses: actions/cache@v4
        with: { path: ~/godot, key: godot-4.6.x }
      - name: Get Godot 4.6.x headless
        run: |
          # download pinned Godot 4.6.x linux headless into ~/godot
      - name: Headless smoke (project loads / no parse errors)
        run: ~/godot/godot --headless --path . --quit-after 2
      - name: Run GdUnit4 tests
        run: |
          ~/godot/godot --headless --path . \
            -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
            -a res://tests --report junit
      - name: Publish results
        if: always()
        uses: dorny/test-reporter@v1
        with: { name: gdunit4, path: 'reports/**/*.xml', reporter: java-junit }
```

The `test` job must exit non-zero on any failed/aborted suite (GdUnit4 CLI returns a non-zero code; confirm the flag/exit behavior for the pinned version). The smoke step catches autoload/parse breakage even when no test targets it.

---

## Open questions

- **Golden hashes vs. in-test recompute:** M1 recomputes determinism in-test (compare two live generations). Do we also want a stored golden fingerprint to catch *intended-but-unnoticed* generation changes across commits? That adds a fixture to update on purpose.
  - **Recommendation:** For M1, in-test recompute only — do not add stored golden fingerprints yet. The live two-generation comparison already proves determinism (same seed -> same output), which is the property M1 needs; greybox generation is still churning, so a golden file would generate constant intentional-update noise without protecting anything stable. Add one golden fingerprint per canonical seed once layout generation is frozen (post-M1), since that is when "did this commit silently change the world?" becomes a real risk worth a deliberate fixture.
- **Pure-function refactor scope:** How much of B2/D1/E3/F1 currently depends on global autoloads (`RNG`, `GameState`)? Test injectability may require small refactors — size that before committing G2.
  - **Recommendation:** Adopt the rule that every system under test exposes a static/pure entry point taking an injected seed or `RandomNumberGenerator` and returning plain data (the design note already mandates this). Budget a small per-system refactor (extract `generate(seed, ...)`, `bank(carry, ...)`, `resolve(carry)` style functions that the autoload then calls) — typically under a day total for four systems if they are not yet deeply autoload-coupled. Do this audit first; if any system reads `RNG`/`GameState` from deep in a call tree, that system's refactor is the real cost driver and should be sized before committing the test work.
- **`POCKET_FRACTION` in M1:** Is the death-drop pocket fraction non-zero in M1, or do you lose everything on death (cleaner push/extract tension)? The test asserts whatever the constant is, but the design value should be decided.
  - **Recommendation:** Set `POCKET_FRACTION = 0.0` for M1 — you lose the entire carried haul on death. The whole gate question is "is push/cash-out tension fun?", and a partial-keep safety net dilutes exactly the stakes you are trying to measure. Keep it as a named constant so a later milestone can soften it if testers find total loss too punishing, but enter the playtest with the sharpest version of the choice.
- **Godot binary in CI:** Pin exact 4.6.x patch and decide download source (official mirror vs. a setup action). Cache to keep CI fast.
  - **Recommendation:** Use the official `gdUnit4-action`, which already installs a pinned Godot via its `godot-version`/`godot-status` inputs, caches the binary across runs (`actions/cache` on the godot install dir), and runs a version-compatibility check against the addon — so you do not hand-roll the download. Pin to the exact 4.6 patch the team develops on (e.g. `godot-version: 4.6.x`, `godot-status: stable`) so editor and CI never drift. ([source](https://github.com/godot-gdunit-labs/gdUnit4-action))
- **GdUnit4 version pinning:** Vendor the addon at a fixed version so CLI flags/exit codes don't drift; confirm it supports the chosen Godot 4.6.x patch.
  - **Recommendation:** Vendor (commit) the gdUnit4 addon at a fixed tag under `/addons/gdUnit4/` and set the action's `version` input to `installed` so CI runs the exact committed copy rather than re-fetching `latest` — this guarantees CLI flags and exit codes never drift mid-milestone. The action performs an explicit Godot/gdUnit4 compatibility check, so pin the addon tag that supports your 4.6.x patch and bump it deliberately. Note the runner returns non-zero on failure (and code 101 for warnings when `warnings-as-errors` is on), which satisfies the "fail the build on any failed/aborted test" requirement. ([source](https://github.com/godot-gdunit-labs/gdUnit4-action/blob/master/action.yml))
- **Smoke depth:** Is "project opens headless and quits" enough for M1, or do we want a scripted 1-frame run of the main scene to catch runtime (not just parse) errors?
  - **Recommendation:** Go one step past a bare project-open: boot the actual main scene headless and run it for a small number of frames (`--headless --quit-after 30` or a tiny test scene that instantiates the main scene and `await`s a few frames), then fail the job on any error printed to stderr. A plain open catches parse/autoload-registration breakage but misses `_ready()`/first-frame runtime crashes, which are exactly the blockers that would waste a nightly playtest build. Keep it lightweight — this is a smoke test, not a play-through.
