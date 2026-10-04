# Performance and memory audit — 2026-10-04

**Follow-up:** browser audio retention was identified and fixed after this initial audit. See the [follow-up findings and validation](followup/REPORT.md) for current status.

The initial probes found good frame pacing on the tested Mac and three concrete issues: a helper reference cycle, repeated depth-key calculation, and generated assets entering the game export. The [follow-up](followup/REPORT.md) identifies and fixes a fourth issue, decoded Web audio accumulating across retries, and adds moving-session and crowd-pressure measurements. This document preserves the initial measurements; follow-up results supersede its open browser-memory finding and original test pass count.

## Scope and method

Tested Godot 4.7.2, Compatibility renderer, 1280×720, on an Apple M3 Pro Mac. Native runs use the debug engine; Chrome 153 uses a release Web export. The final runs include the completed rooftop fading changes. JSON files beside this report contain monitor snapshots, distributions and entity counts; the native reports include source hashes. Initial browser reports hash unavailable exported source as an empty string; those hashes cannot establish source identity. The browser builder now embeds hashes from its source snapshot for future runs. Both final browser exports were built from the finished local scripts.

Each level (1, 2, 3, 6, 10) has a stationary spawn probe and a probe near the densest cop cluster: 60 warmup frames, then 240 sampled frames. Ten level-6 build/free cycles follow. The player and dog physics are disabled, and the harness forces active play. This exercises rendering, nearby AI, traffic and hazards, but captures can recur; it is not a representative moving chase or a long play session. Main randomizes its RNG; home seed 731 fixes the neighborhood but does not make every actor/traffic position deterministic.

Browser frame intervals follow requestAnimationFrame/display pacing and are not CPU execution times. Native frame intervals include scheduling/rendering. Godot static allocation and video-memory monitors are not whole-process RSS. Browser static allocation reads zero because this monitor is unavailable in the release build, not because memory use is zero. JS heap readings do not measure all browser/graphics/native allocations. See [Godot Performance](https://docs.godotengine.org/en/4.6/classes/class_performance.html).

## Fixed findings

### Helper ownership cycle

`LevelBuilder` owned `FurnitureBuilder`, whose strong back-reference owned `LevelBuilder`. Both are RefCounted, so freeing the world retained two objects per rebuild. The original ten-cycle probe grew from 1,711 to 1,729 objects. `FurnitureBuilder` now stores a WeakRef to its owner. See [Godot WeakRef](https://docs.godotengine.org/en/4.6/classes/class_weakref.html).

Final native ten-cycle cleanup stayed at **1,637 objects, 51 resources, one root node, zero orphan nodes**. Static allocation changed only 7,404 bytes (about 7.2 KiB); this small change includes probe bookkeeping/allocator behavior and is not proof of zero allocations. Video memory stayed constant. The regression test checks helper WeakRefs directly and also exercises five actual `restart()` reloads; all old scenes and helpers were released.

Very rapid headless shutdown initially reported live audio playbacks. Waiting 400 ms for the audio driver to retire playbacks removed those exit diagnostics. No accumulating native audio leak was established.

### Depth sort repeated expensive work

The topological selection loop repeatedly read the same node depth key. It now computes each key once into a PackedFloat64Array per sort. Selection rules and ties are unchanged. A retained uncached reference implementation compares every actor z-index at four camera positions: all matched.

| Camera position | Uncached median | Cached median | Reduction |
| --- | ---: | ---: | ---: |
| (250.0, 2730.0) | 1.656 ms | 0.799 ms | 52% |
| (1800.0, 1200.0) | 1.269 ms | 0.658 ms | 48% |
| (4200.0, 1700.0) | 1.100 ms | 0.600 ms | 45% |
| (6800.0, 2300.0) | 0.974 ms | 0.520 ms | 47% |

This is a sort microbenchmark improvement, not a claim that whole-game FPS doubled. Pairwise overlap checks and topological selection still scale quadratically with visible items.

### Generated assets in game pack

Godot had imported PNGs under `build/web/assets`, duplicating gallery content inside the game pack. Added `build/.gdignore`, kept it versionable in `.gitignore`, and explicitly excluded `build/*` in the export preset. The clean export log contains no `res://build/` entries. The checked pack fell from **3,812,964 to 3,655,028 bytes**, a reduction of 157,936 bytes (4.1%). This is a measured export comparison, not solely a byte-for-byte attribution to the exclusion, because other asset edits occurred during the audit.

## Final rendered measurements

Native results below were rerun after the full regression suite finished. Another diagnostic export briefly overlapped the end of the run, so treat whole-frame timings as indicative; the paired depth comparison is the stronger evidence for that optimization. All p95 values were below the 16.67 ms budget for 60 FPS, but some isolated frames exceeded it.

| Probe | Native median / p95 | Chrome median / p95 | Native static allocation | Native draws |
| --- | ---: | ---: | ---: | ---: |
| level_1_spawn | 8.76 / 14.74 ms | 8.30 / 8.90 ms | 109.7 MiB | 334 |
| level_1_dense | 8.19 / 9.85 ms | 8.30 / 8.90 ms | 110.2 MiB | 268 |
| level_2_spawn | 8.21 / 9.79 ms | 8.30 / 8.90 ms | 112.8 MiB | 336 |
| level_2_dense | 8.25 / 10.17 ms | 8.30 / 9.00 ms | 113.1 MiB | 199 |
| level_3_spawn | 8.25 / 10.43 ms | 8.30 / 8.80 ms | 113.4 MiB | 379 |
| level_3_dense | 8.23 / 10.31 ms | 8.30 / 8.80 ms | 113.6 MiB | 242 |
| level_6_spawn | 8.30 / 12.15 ms | 8.30 / 8.90 ms | 119.7 MiB | 382 |
| level_6_dense | 8.31 / 11.39 ms | 8.30 / 8.90 ms | 119.9 MiB | 245 |
| level_10_spawn | 6.56 / 8.55 ms | 8.30 / 8.80 ms | 123.7 MiB | 395 |
| level_10_dense | 6.90 / 7.17 ms | 8.30 / 8.80 ms | 123.9 MiB | 395 |

Level-6 spawn microbenchmarks: sort median 0.832 ms / p95 0.964 ms; building/rooftop fading 0.066 / 0.087 ms; activity-gate update 0.270 / 0.364 ms; 32 ray queries together 0.152 / 0.183 ms. These isolated calls omit surrounding gameplay and GPU time. Rooftop fading was included and did not emerge as the dominant CPU cost.

## Open findings and priorities

1. **High priority: browser restart memory.** In the first final release-browser run, ten cleaned-up rebuilds held steady at 1,466 Godot objects, 51 resources, two nodes (the audit root plus window), and zero orphan nodes. Nevertheless Chrome's reported JS heap increased from 276.6 MB to 540.9 MB, and Godot's video-memory monitor from 37.3 MB to 54.1 MB. Chrome displayed a 1.8 GB high-memory-use warning after the full multi-level run. That UI estimate includes more than Godot allocations. These observations warrant browser allocation/graphics/audio teardown profiling; they do not identify a proven JS leak or its owner. The second run (`browser-memory-idle.json`) held WebAssembly capacity steady at **144,703,488 bytes (138 MiB)** throughout all ten rebuilds. JS heap still rose from **267.5 MB to 536.2 MB**, then fell to **475.9 MB after 10 seconds idle**. Video memory plateaued at 54.1 MB in that run. This supports partial garbage collection and a stable WASM high-water mark, but does not establish a stable JS heap. The two extra idle-snapshot objects are consistent with the audit timer/await machinery; no extra orphan nodes appeared. Next isolate audio and rendering in browser allocation snapshots, then repeat real reloads with longer idle intervals.
2. **High priority: test mobile and long sessions before setting a memory budget.** No iPhone/Android device, Safari, prolonged chase, maximum traffic saturation, or 30-minute session was measured. The Mac's frame pacing is not a mobile performance guarantee.
3. **Medium priority: world/node overhead.** A full neighborhood has roughly 9,000 nodes. The existing activity gate suppresses most distant cops, NPCs, cats and fans, but disabled objects still consume memory. Prefer measured world streaming or batching if mobile memory is constrained. Distinguish `can_process` from `is_processing`; steady lamps need not process every frame.
4. **Medium priority: larger visible crowds.** Depth sorting remains O(n²). Avoid increasing visible populations without repeating the sort benchmark. The current key cache is a low-risk improvement; a spatial/overlap acceleration would need broader ordering validation.
5. **Lower priority: web delivery size.** The engine WASM is about 39.5 MB uncompressed; the deployed response already uses gzip and reported about 10.25 MB transferred. Compression is already enabled. Audio loops are mono, 16-bit, 22.05 kHz; the two music files are roughly 1 MB each. No large accidental stereo/high-rate audio payload was found. Source sprite textures are small. Asset changes are less promising than an engine/export-size strategy if first-load time becomes the target.

Existing useful safeguards include the collision grid, near-camera depth filtering, activity hysteresis, bounded procedural puff textures, bounded run-log history and capped traffic. Preserve these when extending the world.

## Validation and reproduction

- The original runner reported **30/30 passed** (`tests.txt`). Follow-up inspection found it missed bare boolean failures and numeric failure totals in older checks. See [corrected validation](followup/REPORT.md#validation-and-session-coverage) for the stricter runner and repaired fixtures. The direct helper-release assertions also passed after extending the lifecycle test to five actual reloads (`restart-test.txt`).
- Cached/reference depth comparison: identical actor order at all four tested positions (`depth-sort-final.json`). This covers those sampled scenes, not every possible crowd arrangement.
- Clean Web export passed; generated build resources were absent from the export log. At this initial measurement stage, the local export was refreshed but not yet committed or deployed.
- Browser diagnostic build completed all scenarios and cleanup cycles. It lives in ignored `build/audit-web`, outside the deployable `build/web` directory. The earlier temporary diagnostic directory under `build/web` was removed.

Run from the project root:

```sh
python3 docs/tools/run_tests.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script docs/tools/audit_depth_comparison.gd
AUDIT_OUT=/tmp/curfew-performance-audit.json /Applications/Godot.app/Contents/MacOS/Godot --rendering-method gl_compatibility --path . --script docs/tools/audit_performance.gd
python3 docs/tools/build_audit_web.py
```

Serve the project root locally, open `build/audit-web/index.html`, keep the tab foregrounded, and download its JSON report. Do not publish the diagnostic build. Run profiling without simultaneous tests/exports for tighter timing comparisons. Before/after headless and provisional desktop evidence is retained alongside final JSON; those early runs occurred while rooftop changes were in progress and must not be interpreted as controlled whole-frame improvement measurements.
