# GDScript vs C# Benchmark (for the Proc-Gen Hot Path)

*Research companion to the THE FAR YARD Technical Design Doc §9 (procedural band assembly).*

This study answers one practical question for THE FAR YARD: **when, if ever, should the procedural-generation hot path move off GDScript and into C# (or GDExtension)?** It collects real benchmark numbers, separates the magnitude of the gap from the marketing noise, explains the marshalling boundaries on both sides, covers the export/platform tradeoffs (the web-export caveat in particular), and ends with a concrete decision rule. The short version: the team's GDScript default is correct, typed GDScript closes much of the gap for free, and C# earns its place only on a *measured*, compute-bound bottleneck — which a noise/data-crunching proc-gen pass can genuinely become.

---

## 1. The headline numbers (and how much to trust them)

The honest starting point is that there is **no single definitive GDScript-vs-C# benchmark** for Godot 4.x. The gap depends on (a) the workload, (b) whether the GDScript is statically typed, and (c) debug vs release builds. With each Godot release the gap narrows but does not close. Anyone quoting one universal multiplier is selling something.

That said, the published numbers cluster into a consistent shape:

- **Compute-bound, tight numerical loops:** C# is on the order of **several times faster** than typed GDScript, and **roughly an order of magnitude faster** than untyped GDScript. The most-cited concrete proc-gen data point is an (admittedly old, Godot 3-era 2019) CPU **voxel terrain** benchmark that found GDScript roughly **11× slower than C#** on that workload — exactly the "generate terrain/mesh data on the CPU in a big loop" shape that matters here. The author explicitly noted typed GDScript and its optimizations would narrow that, which is what subsequent Godot 4 work did. ([Royal Donut voxel benchmark](http://www.royaldonut.games/2019/03/29/cpu-voxel-benchmarks-of-most-popular-languages-in-godot/) — domain now expired; summary surfaced via search index.)
- **Grid/data-structure operations:** A GDScript-vs-C# inventory-grid microbenchmark found C# ~**5× faster for a single operation** and ~**20× faster across 100 iterations** of grid manipulation, with one configuration showing up to **~140×** on a pathological 100-iteration case. These are microbenchmarks — useful for the *shape*, not as frame-budget predictions. ([RaidTheory inventory benchmark](https://github.com/RaidTheory/csharp-gd-inventory-test))
- **Everyday game logic:** Effectively a tie at any reasonable scale. The original GDScript author measured 100,000-iteration loops with *function calls* finishing in ~70 ms single-threaded in **debug** mode, and concluded "GDScript is not as slow as some imagine" because most work is delegated to C++ engine internals. ([Godot — Typed instructions report](https://godotengine.org/article/gdscript-progress-report-typed-instructions/))

The reliable takeaway: **C# wins big specifically on CPU-bound script that does its own arithmetic in a loop and rarely touches the engine.** That is precisely the profile of a noise-driven or cellular-automata proc-gen pass — but *not* the profile of room-graph stitching that mostly instances `PackedScene`s and calls engine methods (the front-runner from the §9 proc-gen spike).

---

## 2. Typed GDScript: the free win you take first

Before any C# discussion, the cheapest performance lever in GDScript 4.x is **static typing**. Type annotations let the VM emit specialized "typed instructions" that skip runtime type lookups.

Real measured gains:

- A community loop benchmark on an M2 Max (1,000,000,000 iterations) showed typed vs untyped: integer addition **~34% faster in release** (9,695 ms → 6,372 ms), multiplication **~36% faster**, and **`Vector2` distance ~59% faster in release** (14,728 ms → 6,057 ms). Vector math "screams" when typed. ([beep.blog — static types](https://www.beep.blog/2024-02-14-gdscript-typing/), test project: [cariad/gdscript-typed-performance](https://github.com/cariad/gdscript-typed-performance))
- The engine team's own synthetic numbers for typed instructions: operations **25–50% faster**, built-in-type function calls with pre-validated args **~70% faster**, native-class calls with pre-validated args **120–150% faster**, iteration **10–50% faster**. ([Godot — Typed instructions](https://godotengine.org/article/gdscript-progress-report-typed-instructions/))
- An early engine PR measured typed code **>40% faster on release** (6.41 ms untyped → 3.311 ms typed) on its test. ([godot#70838](https://github.com/godotengine/godot/pull/70838))

**Implication for THE FAR YARD:** every line of the proc-gen path should be statically typed *regardless* of the C# decision. It is the highest return-on-effort change available, it improves the math/vector-heavy parts most, and it makes the eventual "is C# actually worth it?" comparison fair (you must benchmark against *typed* GDScript, not untyped).

---

## 3. What Godot 4.6 actually changed (and what it did not)

THE FAR YARD targets Godot 4.6. Be precise about what 4.6 brought, because there is community misinformation:

- **No JIT.** Despite claims that "4.6 added a GDScript JIT," it **did not**. There is no native code-generation step; GDScript remains bytecode-interpreted. The JIT roadmap issue ([godot#5049](https://github.com/godotengine/godot/issues/5049)) is still open and unimplemented.
- **What 4.6 did add:** bytecode-level optimizations to common operations (array iteration, dictionary access, method-call overhead all measurably faster than 4.5), with gains most pronounced for *typed* GDScript; and **dedicated tracing-profiler integration (Tracy, Perfetto, Instruments)** exposed through the editor — flame-graph-quality profiling that is far better than the old built-in profiler for finding script hotspots. ([Godot 4.6 release notes](https://godotengine.org/releases/4.6/), via [StraySpark 2026 comparison](https://www.strayspark.studio/blog/gdscript-vs-csharp-godot-2026-choosing-scripting-language))

So 4.6 **narrowed** the gap and, more importantly, gave us **good profiling tools** — which directly enables the "profile first" discipline below. It did not eliminate C#'s compute advantage.

---

## 4. The marshalling boundary — the part people get wrong

The most common mistake is treating "C# is faster" as unconditional. Both languages pay a cost at the **script↔engine boundary**, and C#'s cost there is *higher* than GDScript's. Whether C# is a net win depends on the ratio of pure computation to engine calls.

**GDScript↔engine:** GDScript runs inside the engine and shares the `Variant` type system, so crossing into C++ engine code is cheap — there is no separate runtime to marshal across.

**C#↔engine:** C# runs in a separate .NET runtime. Every call into Godot core crosses a managed↔native boundary and may marshal data through `Variant`. Key cost rules ([Godot C# docs / interop discussion](https://github.com/godotengine/godot-docs/pull/6408), [What's new in C# for Godot 4.0](https://godotengine.org/article/whats-new-in-csharp-for-godot-4-0/)):

- **Value types pass cheaply.** `Vector2/3`, and other built-in structs pass by value with no marshalling. `GodotObject` references pass as a native pointer. So vector math in C# is fast on both sides of the boundary.
- **Property access and method calls into Godot objects incur overhead.** Reading/writing properties of `Godot.Object`-derived classes, or repeatedly calling engine methods, pays per-call interop. The official guidance is to **cache** such values in local variables inside loops rather than re-reading them.
- **Collections marshal per-item.** Using Godot collection methods is faster than LINQ because LINQ forces marshalling of every item. Prefer native C# collections for internal work and only convert at the boundary.

**Why this matters for proc-gen specifically:** a proc-gen pass that loops over a million cells doing arithmetic in pure C# arrays/`Span<T>` and only touches the engine to hand back a finished `Image`/`PackedScene`/mesh is the **ideal** C# case — almost no boundary crossings, all raw compute. A proc-gen pass that calls `set_cell` on a `TileMapLayer` per tile, or instances scenes node-by-node, spends most of its time at the boundary, where C#'s interop tax can erase or reverse its compute advantage. **The win comes from batching at the boundary, not from the language alone.**

---

## 5. When the difference actually matters vs. premature optimization

Across every source, the same caveat repeats: **most Godot games are not bottlenecked on script.** Rendering, physics, and draw calls dominate the frame budget. Player controllers, inventory, dialogue, quest logic, and UI run comfortably in either language at any sane scale. ([chickensoft — GDScript vs C#](https://chickensoft.games/blog/gdscript-vs-csharp), [StraySpark 2026](https://www.strayspark.studio/blog/gdscript-vs-csharp-godot-2026-choosing-scripting-language))

The narrow set of cases where language choice *does* move the needle:

- **Procedural generation at runtime** — terrain, dungeons, mesh/voxel data, large noise fields. (This is us, *if* generation is noise/data-heavy and runs during gameplay rather than on a loading screen.)
- **Custom physics / spatial partitioning** done in script.
- **Large-scale agent AI** — hundreds to thousands of complex per-frame updates.
- **Data processing** — parsing/serializing large files, compression, big string/regex work.

For THE FAR YARD's stated proc-gen design (rule-based modular assembly stitching hand-authored `PackedScene` zone-pieces, per the §9 spike), the hot path is **mostly engine-bound instancing and graph logic, not raw arithmetic.** That argues for staying in GDScript. The arithmetic-heavy candidates that *could* justify C# are narrower: large noise sampling for decoration/biome masks, big cellular-automata or BSP grid passes, or any per-cell crunch over a sizable map computed at runtime. Optimizing before you've confirmed one of those is the actual bottleneck is textbook premature optimization — and it costs you the export/tooling/iteration penalties in Section 7 for nothing.

---

## 6. The extreme option: GDExtension / C++ (and Rust)

If, after profiling, neither typed GDScript nor C# is fast enough, the escape hatch is **GDExtension**: write the hot kernel in C++ (or Rust via `gdext`) and expose it to *both* GDScript and C#. This yields near-native performance for the specific algorithm.

Two practical points for THE FAR YARD:

- **Bindings flow one way.** Godot generates bindings so GDScript (and the engine) can call a GDExtension with no glue. But **C# cannot call a GDExtension directly** — Godot does not generate C# bindings for GDExtensions. The workaround is to route through GDScript, paying an extra hop. ([chickensoft — GDScript vs C#](https://chickensoft.games/blog/gdscript-vs-csharp)) This is a subtle reason *not* to commit the codebase to C#: it complicates the very escape hatch you'd want for the most extreme hot paths.
- **Cost is complexity.** A separate build toolchain, platform-by-platform compilation, slower iteration. Only go here after profiling proves the kernel is the bottleneck and C#/typed GDScript both fall short. For a noise-heavy band that genuinely needs it, a small C++/Rust noise kernel callable from GDScript is the cleanest extreme option and sidesteps the C# web-export problem below entirely.

---

## 7. Export & platform tradeoffs of C# (the web caveat)

Choosing C# is not just a perf decision — it changes what you can ship and how fast you iterate.

- **Web (HTML5) export is the big one.** GDScript exports to WebAssembly cleanly. C# web export is **experimental / not production-ready as of 2026.** The technical blocker: .NET expects to be the WASM main entry point and doesn't support the dynamic linking Godot needs, so the .NET WASM runtime can't simply be loaded by Godot. Work is in flight ([godot#106125 — .NET web export](https://github.com/godotengine/godot/pull/106125), [GodotCon web .NET prototype](https://godotengine.org/article/live-from-godotcon-boston-web-dotnet-prototype/), tracking issue [godot#70796](https://github.com/godotengine/godot/issues/70796)), and there's discussion of landing it in 4.6, but **PR #106125 is not merged** and has caveats (globalization in invariant mode only, stubbed JS interop meaning some BCL APIs don't work). **If a web/itch.io build matters for THE FAR YARD, a C#-primary project is a real risk today.**
- **iOS** requires AOT for C#; historically C# couldn't export to iOS/web at all, and platform parity still lags GDScript. ([Current state of C# platform support, 4.2](https://godotengine.org/article/platform-state-in-csharp-for-godot-4-2/))
- **Export size:** C# adds roughly **30–60 MB** of .NET runtime to every build, regardless of how much C# you actually use. Irrelevant on desktop, meaningful for web/mobile.
- **Iteration cost:** GDScript hot-reloads on save with no compile step. C# requires an MSBuild compile before changes take effect, the build system occasionally needs a clean rebuild, and `@tool`/editor scripts are more reliable in GDScript than `[Tool]` in C#. ([StraySpark 2026](https://www.strayspark.studio/blog/gdscript-vs-csharp-godot-2026-choosing-scripting-language))
- **Mixed-language tax:** You *can* run both in one project, but a mixed project requires the .NET build of Godot (so you pay the export-size and web-export penalties **project-wide**), cross-language data must use Godot's own `Collections.Array`/`Dictionary` rather than native `List<T>`, and cross-language signals lose type safety.

The upside of C#, for completeness: the full NuGet ecosystem, superior debugging (conditional breakpoints, watch expressions, Rider/VS), real refactoring tools, and `struct`/`Span<T>`/pooling control over allocations. These are organizational and tooling wins, not frame-rate wins.

---

## 8. Profile first — the discipline that makes the decision for you

Every credible source converges on the same workflow, and 4.6's new tooling finally makes it easy:

1. **Type your GDScript** and re-measure. Often this alone clears the budget, especially for vector/math-heavy code.
2. **Profile with the real workload**, not a microbenchmark. Use the 4.6 Tracy/Perfetto/Instruments integration to get a flame graph and find *where* the proc-gen time actually goes — is it arithmetic, or is it `set_cell`/scene-instancing at the engine boundary?
3. **Attack the algorithm before the language.** Caching engine property reads out of loops, batching boundary calls, threading generation off the main thread, or generating during a loading screen instead of mid-gameplay frequently solves the problem with zero language change.
4. **Only then** consider porting the proven-hot kernel — and port the *kernel*, not the codebase.

A microbenchmark that says "C# is 11× faster" tells you the ceiling on a pure-arithmetic kernel; your profiler tells you whether your proc-gen pass is anywhere near that shape or is dominated by engine calls where the ceiling doesn't apply.

---

## 9. Decision rule for THE FAR YARD's proc-gen hot path

Default: **GDScript, statically typed, generation done off-frame (background thread or loading screen).** Move a specific proc-gen kernel to C# only when **all** of these hold:

1. **It's on the critical path.** Profiling (Tracy/Perfetto in 4.6) shows the proc-gen pass is causing a visible hitch or missing the frame/loading budget — not just "feels slow."
2. **Typed GDScript wasn't enough.** You've already added full static typing and applied algorithmic/threading/batching fixes, and the kernel is *still* over budget.
3. **The bottleneck is compute, not engine calls.** The flame graph shows time dominated by your own arithmetic over arrays/grids/noise — the case where C#'s several-times-to-10× advantage is real — rather than by `set_cell`/scene-instancing/property access, where C# interop overhead would blunt or reverse the win.
4. **The kernel is cleanly extractable.** It can be a self-contained function that takes plain data in and hands a finished artifact (Image, mesh, grid, byte buffer) back across the boundary **once**, so you pay marshalling at the edges, not per-iteration.
5. **Web export isn't blocked by it.** Either THE FAR YARD doesn't ship a web build, or you accept routing the kernel through GDExtension instead so the project stays on the GDScript (non-.NET) Godot build. If web is a hard requirement, **prefer a C++/Rust GDExtension kernel over C#** — same speed, no .NET web-export risk, no project-wide .NET runtime tax.

If 1–4 hold but web is non-negotiable, **skip C# and go straight to a GDExtension kernel.** If none of 1–4 hold, **stay in typed GDScript** — moving to C# would trade fast iteration, smaller builds, and clean web export for a speedup the player will never perceive.

---

## Sources

- [chickensoft.games — GDScript vs C# in Godot 4](https://chickensoft.games/blog/gdscript-vs-csharp) (pros/cons, marshalling penalty, GDExtension-from-C# limitation, web/iOS gaps)
- [StraySpark — GDScript vs C# in Godot 2026 (4.6)](https://www.strayspark.studio/blog/gdscript-vs-csharp-godot-2026-choosing-scripting-language) (what 4.6 actually changed, no-JIT correction, where C# wins, export tradeoffs)
- [beep.blog — Yes, your Godot game runs faster with static types](https://www.beep.blog/2024-02-14-gdscript-typing/) (typed vs untyped loop/vector numbers) + [test project](https://github.com/cariad/gdscript-typed-performance)
- [Godot Engine — GDScript progress report: Typed instructions](https://godotengine.org/article/gdscript-progress-report-typed-instructions/) (per-instruction speedups, "GDScript is not as slow as imagined")
- [Godot Engine — What's new in C# for Godot 4.0](https://godotengine.org/article/whats-new-in-csharp-for-godot-4-0/) (Variant marshalling, value types pass cheaply)
- [godot-docs PR #6408 — avoid expensive Godot C# property access in loops](https://github.com/godotengine/godot-docs/pull/6408) (cache values, interop overhead guidance)
- [RaidTheory — csharp-gd-inventory-test](https://github.com/RaidTheory/csharp-gd-inventory-test) (grid microbenchmark: ~5×/~20×/~140×)
- [Royal Donut — CPU Voxel Benchmarks in Godot](http://www.royaldonut.games/2019/03/29/cpu-voxel-benchmarks-of-most-popular-languages-in-godot/) (~11× on voxel terrain, Godot 3-era; domain now expired)
- [godot#5049 — GDScript JIT proposal](https://github.com/godotengine/godot/issues/5049) (still open/unimplemented)
- [godot#70838 — typed code performance PR](https://github.com/godotengine/godot/pull/70838) (>40% faster on release test)
- [godot#106125 — .NET web export PR](https://github.com/godotengine/godot/pull/106125) and [godot#70796 — re-add web platform for C#](https://github.com/godotengine/godot/issues/70796) (web export status)
- [Godot Engine — Live from GodotCon Boston: Web .NET prototype](https://godotengine.org/article/live-from-godotcon-boston-web-dotnet-prototype/) (web .NET work in progress)
- [Godot Engine — Current state of C# platform support in Godot 4.2](https://godotengine.org/article/platform-state-in-csharp-for-godot-4-2/) (iOS/web limitations)
