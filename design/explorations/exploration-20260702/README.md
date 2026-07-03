# Explorations — 2026-07-02 (refinement pass)

A **targeted refinement** of specific architecture docs from the [2026-06-25 exploration set](../exploration-20260625/README.md), not a new full spread. Each doc here is a v2 that supersedes its 20260625 predecessor, keeping what held up and correcting what the Director flagged.

| Doc | Refines | Key moves in v2 |
|---|---|---|
| [hazards/0-scalable-opposition-system.md](hazards/0-scalable-opposition-system.md) | [20260625 v1](../exploration-20260625/hazards/0-scalable-opposition-system.md) | Splits v1's fused `OppositionDirector` into a policy-free **`SpawnService`** (mechanism) + one-or-more **`EncounterBuilder`s** (policy); makes the spawn API a client-agnostic service (band populator · death/timer re-entry · set-piece injector · debug/test harness · scripted beats); answers debug-menu scaling via a **`param_schema`** on `OppositionDef` with a generalized coverage assertion. |

v1's non-negotiables are carried intact: all-off byte-identical baseline, no global RNG in generation-time placement, the EventBus pre-declare rule, primitives-only telemetry payloads. **Not yet dispositioned by the Director.**
</content>
